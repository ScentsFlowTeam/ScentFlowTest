import Foundation
import SwiftUI
import Combine

@MainActor
final class ControlPanelViewModel: ObservableObject {
    @Published var showingSaveAlert = false
    @Published var showingSaveOptions = false
    @Published var newTemplateName = ""
    @Published var showingTemplatesPage = false
    @Published var listButtonBounceToken = 0

    private var adjustingPodText: String?
    private var adjustingPodTask: Task<Void, Never>?

    deinit {
        adjustingPodTask?.cancel()
    }

    enum TemplateMode {
        case unsaved
        case saved(ScentsTemplate)
        case modified(ScentsTemplate)
    }

    func onAppear(
        gradientVM: GradientWheelViewModel,
        templatesService: TemplatesService,
        templateLength: TemplateLengthController
    ) {
        syncTemplateLength(gradientVM: gradientVM, templateLength: templateLength)
    }

    func templateIDChanged(
        to id: UUID?,
        gradientVM: GradientWheelViewModel,
        templatesService: TemplatesService,
        templateLength: TemplateLengthController
    ) {
        guard id != nil else { return }
        syncTemplateLength(gradientVM: gradientVM, templateLength: templateLength)
    }

    /// Drives the live countdown controller from the persisted per-session length
    /// on the wheel VM (the single source of truth), resuming from the stored
    /// start date so elapsed progress is preserved across navigation.
    func syncTemplateLength(
        gradientVM: GradientWheelViewModel,
        templateLength: TemplateLengthController
    ) {
        templateLength.setLength(
            gradientVM.templateLengthDuration,
            startedAt: gradientVM.templateLengthStartDate ?? Date()
        )
    }

    func powerChanged(isOn: Bool, templateLength: TemplateLengthController) {
        if !isOn {
            templateLength.clear()
        }
    }

    func templateMode(
        gradientVM: GradientWheelViewModel,
        templatesService: TemplatesService
    ) -> TemplateMode {
        if let activeTemplate = activeTemplate(gradientVM: gradientVM, templatesService: templatesService) {
            return .saved(activeTemplate)
        }

        if let sourceTemplate = sourceTemplate(gradientVM: gradientVM, templatesService: templatesService) {
            return .modified(sourceTemplate)
        }

        return .unsaved
    }

    func sourceTemplate(
        gradientVM: GradientWheelViewModel,
        templatesService: TemplatesService
    ) -> ScentsTemplate? {
        guard let sourceTemplateID = gradientVM.sourceTemplateID else { return nil }
        return templatesService.templates.first(where: { $0.id == sourceTemplateID })
    }

    func canSaveTemplate(gradientVM: GradientWheelViewModel) -> Bool {
        !orderedIncludedPods(gradientVM: gradientVM).isEmpty
    }

    func saveActionTitle(
        gradientVM: GradientWheelViewModel,
        templatesService: TemplatesService
    ) -> String {
        sourceTemplate(gradientVM: gradientVM, templatesService: templatesService) == nil ? "New Template" : "Save Template"
    }

    func saveSystemName() -> String {
        "square.and.arrow.down.fill"
    }

    func playerDisplayState(
        gradientVM: GradientWheelViewModel,
        templatesService: TemplatesService
    ) -> RetroPlayerDisplay.DisplayState {
        guard gradientVM.isPowerOn else {
            return .deviceOff(
                title: displayTemplateTitle(gradientVM: gradientVM, templatesService: templatesService)
            )
        }

        let currentTemplate = currentTemplate(gradientVM: gradientVM, templatesService: templatesService)
        let position = currentTemplate.flatMap { template in
            templatesService.templates.firstIndex(where: { $0.id == template.id }).map { $0 + 1 }
        }

        return .playing(
            title: displayTemplateTitle(gradientVM: gradientVM, templatesService: templatesService),
            modeText: displayModeText(gradientVM: gradientVM, templatesService: templatesService),
            bodyText: activePodsIntensityText(gradientVM: gradientVM),
            position: position,
            total: templatesService.templates.count
        )
    }

    func showAdjustingPod(for pod: ScentPod, value: Double) {
        adjustingPodText = intensityText(for: pod, value: value)
        objectWillChange.send()

        adjustingPodTask?.cancel()
        adjustingPodTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            adjustingPodText = nil
            objectWillChange.send()
        }
    }

    func handleSave(
        gradientVM: GradientWheelViewModel,
        templatesService: TemplatesService
    ) {
        if sourceTemplate(gradientVM: gradientVM, templatesService: templatesService) != nil {
            showingSaveOptions = true
        } else {
            beginSaveTemplate(prefilledName: "Mix \(templatesService.templates.count + 1)")
        }
    }

    func beginSaveTemplate(prefilledName: String) {
        newTemplateName = prefilledName
        showingSaveAlert = true
    }

    func saveCurrentTemplate(
        named name: String,
        gradientVM: GradientWheelViewModel,
        templatesService: TemplatesService,
        templateLength: TemplateLengthController
    ) {
        let orderedIncluded = orderedIncludedPods(gradientVM: gradientVM)
        guard !orderedIncluded.isEmpty else { return }

        let new = ScentsTemplate(
            name: name,
            scentPodNames: orderedIncluded.map(\.name),
            duration: currentTemplateDuration(templateLength: templateLength)
        )
        templatesService.add(new)
        templatesService.setActiveTemplateID(new.id)
        gradientVM.setCurrentTemplateID(new.id)
        newTemplateName = ""

        bounceTemplateListButton()
    }

    func updateTemplate(
        _ template: ScentsTemplate,
        gradientVM: GradientWheelViewModel,
        templatesService: TemplatesService,
        templateLength: TemplateLengthController
    ) {
        let orderedIncluded = orderedIncludedPods(gradientVM: gradientVM)
        guard !orderedIncluded.isEmpty else { return }

        var updated = template
        updated.scentPodNames = orderedIncluded.map(\.name)
        updated.duration = currentTemplateDuration(templateLength: templateLength)
        templatesService.update(updated)
        templatesService.setActiveTemplateID(updated.id)
        gradientVM.setCurrentTemplateID(updated.id)

        bounceTemplateListButton()
    }

    func setTemplateLength(
        _ duration: TimeInterval,
        gradientVM: GradientWheelViewModel,
        templateLength: TemplateLengthController
    ) {
        let startedAt = Date()
        gradientVM.setTemplateLengthDuration(duration, startDate: startedAt)
        templateLength.setLength(duration, startedAt: startedAt)
    }

    func clearTemplateLength(
        gradientVM: GradientWheelViewModel,
        templateLength: TemplateLengthController
    ) {
        gradientVM.setTemplateLengthDuration(nil, startDate: nil)
        templateLength.clear()
    }

    private func activeTemplate(
        gradientVM: GradientWheelViewModel,
        templatesService: TemplatesService
    ) -> ScentsTemplate? {
        guard let id = gradientVM.currentTemplateID else { return nil }
        return templatesService.templates.first(where: { $0.id == id })
    }

    private func currentTemplate(
        gradientVM: GradientWheelViewModel,
        templatesService: TemplatesService
    ) -> ScentsTemplate? {
        switch templateMode(gradientVM: gradientVM, templatesService: templatesService) {
        case .unsaved:
            return nil
        case .saved(let template), .modified(let template):
            return template
        }
    }

    private func displayTemplateTitle(
        gradientVM: GradientWheelViewModel,
        templatesService: TemplatesService
    ) -> String {
        switch templateMode(gradientVM: gradientVM, templatesService: templatesService) {
        case .unsaved:
            return "New Template"
        case .saved(let template), .modified(let template):
            return template.name
        }
    }

    private func displayModeText(
        gradientVM: GradientWheelViewModel,
        templatesService: TemplatesService
    ) -> String? {
        switch templateMode(gradientVM: gradientVM, templatesService: templatesService) {
        case .unsaved:
            return nil
        case .saved:
            return nil
        case .modified:
            return "Unsaved"
        }
    }

    private func activePodsIntensityText(gradientVM: GradientWheelViewModel) -> String {
        if let adjustingPodText {
            return adjustingPodText
        }

        let activePods = gradientVM.pods.filter { gradientVM.included.contains($0.id) }
        guard !activePods.isEmpty else { return "No active pods" }

        return activePods
            .map { pod in intensityText(for: pod, value: gradientVM.opacities[pod.id] ?? 0) }
            .joined(separator: "  ")
    }

    private func intensityText(for pod: ScentPod, value: Double) -> String {
        let maxIntensity = max(0.0001, AppConfig.maxIntensity)
        let clamped = min(max(value, 0), maxIntensity)
        let percent = Int((clamped / maxIntensity * 100).rounded())
        return "\(pod.name): \(percent)%"
    }

    private func currentTemplateDuration(templateLength: TemplateLengthController) -> TimeInterval? {
        templateLength.totalDuration > 0 ? templateLength.totalDuration : nil
    }

    private func orderedIncludedPods(gradientVM: GradientWheelViewModel) -> ArraySlice<ScentPod> {
        gradientVM.pods.filter { gradientVM.included.contains($0.id) }.prefix(6)
    }

    private func bounceTemplateListButton() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) {
            listButtonBounceToken += 1
        }
    }
}
