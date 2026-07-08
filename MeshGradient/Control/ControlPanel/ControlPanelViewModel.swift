import Foundation
import SwiftUI
import Combine

@MainActor
final class ControlPanelViewModel: ObservableObject {
    @Published var showingCreateAlert = false
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

    func templateMode(
        runtime: DeviceRuntime,
        templatesService: TemplatesService
    ) -> TemplateMode {
        if let activeTemplate = activeTemplate(runtime: runtime, templatesService: templatesService) {
            return .saved(activeTemplate)
        }

        if let sourceTemplate = sourceTemplate(runtime: runtime, templatesService: templatesService) {
            return .modified(sourceTemplate)
        }

        return .unsaved
    }

    func sourceTemplate(
        runtime: DeviceRuntime,
        templatesService: TemplatesService
    ) -> ScentsTemplate? {
        guard let sourceTemplateID = runtime.sourceTemplateID else { return nil }
        return templatesService.templates.first(where: { $0.id == sourceTemplateID })
    }

    /// A new template can be created whenever there is a non-empty mix.
    func canCreateTemplate(runtime: DeviceRuntime) -> Bool {
        !orderedIncludedPods(runtime: runtime).isEmpty
    }

    /// The save button is enabled only when the current mix has unsaved edits
    /// relative to the template it came from (i.e. the `.modified` state).
    func hasUnsavedEdits(
        runtime: DeviceRuntime,
        templatesService: TemplatesService
    ) -> Bool {
        if case .modified = templateMode(runtime: runtime, templatesService: templatesService) {
            return true
        }
        return false
    }

    func saveActionTitle(
        runtime: DeviceRuntime,
        templatesService: TemplatesService
    ) -> String {
        sourceTemplate(runtime: runtime, templatesService: templatesService) == nil ? "New Template" : "Save Template"
    }

    func saveSystemName() -> String {
        "square.and.arrow.down.fill"
    }

    func playerDisplayState(
        runtime: DeviceRuntime,
        templatesService: TemplatesService
    ) -> RetroPlayerDisplay.DisplayState {
        guard runtime.isPowerOn else {
            return .deviceOff(
                title: displayTemplateTitle(runtime: runtime, templatesService: templatesService)
            )
        }

        let currentTemplate = currentTemplate(runtime: runtime, templatesService: templatesService)
        let position = currentTemplate.flatMap { template in
            templatesService.templates.firstIndex(where: { $0.id == template.id }).map { $0 + 1 }
        }

        return .playing(
            title: displayTemplateTitle(runtime: runtime, templatesService: templatesService),
            modeText: displayModeText(runtime: runtime, templatesService: templatesService),
            bodyText: activePodsIntensityText(runtime: runtime),
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

    /// Saves the current edits directly back onto the template being edited.
    /// No prompt: only reachable when there are unsaved edits (a source exists).
    func handleSave(
        runtime: DeviceRuntime,
        templatesService: TemplatesService
    ) {
        guard let source = sourceTemplate(runtime: runtime, templatesService: templatesService) else { return }
        updateTemplate(source, runtime: runtime, templatesService: templatesService)
    }

    /// Opens the create-new-template alert prefilled with the next "Mix N" name.
    func beginCreateTemplate(templatesService: TemplatesService) {
        newTemplateName = "Mix \(templatesService.templates.count + 1)"
        showingCreateAlert = true
    }

    func saveCurrentTemplate(
        named name: String,
        runtime: DeviceRuntime,
        templatesService: TemplatesService
    ) {
        let orderedIncluded = orderedIncludedPods(runtime: runtime)
        guard !orderedIncluded.isEmpty else { return }

        let new = ScentsTemplate(
            name: name,
            scentPodNames: orderedIncluded.map(\.name),
            duration: currentTemplateDuration(runtime: runtime)
        )
        templatesService.add(new)
        templatesService.setActiveTemplateID(new.id)
        runtime.setCurrentTemplateID(new.id)
        newTemplateName = ""

        bounceTemplateListButton()
    }

    func updateTemplate(
        _ template: ScentsTemplate,
        runtime: DeviceRuntime,
        templatesService: TemplatesService
    ) {
        let orderedIncluded = orderedIncludedPods(runtime: runtime)
        guard !orderedIncluded.isEmpty else { return }

        var updated = template
        updated.scentPodNames = orderedIncluded.map(\.name)
        updated.duration = currentTemplateDuration(runtime: runtime)
        templatesService.update(updated)
        templatesService.setActiveTemplateID(updated.id)
        runtime.setCurrentTemplateID(updated.id)

        bounceTemplateListButton()
    }

    /// Writes the length to the wheel VM (the single source of truth). The bound
    /// TemplateLengthController projects the live clock from it automatically.
    func setTemplateLength(
        _ duration: TimeInterval,
        runtime: DeviceRuntime
    ) {
        runtime.setTemplateLengthDuration(duration, startDate: Date())
        runtime.markCurrentTemplateModified()
    }

    func clearTemplateLength(runtime: DeviceRuntime) {
        runtime.setTemplateLengthDuration(nil, startDate: nil)
        runtime.markCurrentTemplateModified()
    }

    private func activeTemplate(
        runtime: DeviceRuntime,
        templatesService: TemplatesService
    ) -> ScentsTemplate? {
        guard let id = runtime.currentTemplateID else { return nil }
        return templatesService.templates.first(where: { $0.id == id })
    }

    private func currentTemplate(
        runtime: DeviceRuntime,
        templatesService: TemplatesService
    ) -> ScentsTemplate? {
        switch templateMode(runtime: runtime, templatesService: templatesService) {
        case .unsaved:
            return nil
        case .saved(let template), .modified(let template):
            return template
        }
    }

    private func displayTemplateTitle(
        runtime: DeviceRuntime,
        templatesService: TemplatesService
    ) -> String {
        switch templateMode(runtime: runtime, templatesService: templatesService) {
        case .unsaved:
            return "New Template"
        case .saved(let template), .modified(let template):
            return template.name
        }
    }

    private func displayModeText(
        runtime: DeviceRuntime,
        templatesService: TemplatesService
    ) -> String? {
        switch templateMode(runtime: runtime, templatesService: templatesService) {
        case .unsaved:
            return nil
        case .saved:
            return nil
        case .modified:
            return "Unsaved"
        }
    }

    private func activePodsIntensityText(runtime: DeviceRuntime) -> String {
        if let adjustingPodText {
            return adjustingPodText
        }

        let activePods = runtime.pods.filter { runtime.included.contains($0.id) }
        guard !activePods.isEmpty else { return "No active pods" }

        return activePods
            .map { pod in intensityText(for: pod, value: runtime.opacities[pod.id] ?? 0) }
            .joined(separator: "  ")
    }

    private func intensityText(for pod: ScentPod, value: Double) -> String {
        let maxIntensity = max(0.0001, AppConfig.maxIntensity)
        let clamped = min(max(value, 0), maxIntensity)
        let percent = Int((clamped / maxIntensity * 100).rounded())
        return "\(pod.name): \(percent)%"
    }

    private func currentTemplateDuration(runtime: DeviceRuntime) -> TimeInterval? {
        runtime.templateLengthDuration
    }

    private func orderedIncludedPods(runtime: DeviceRuntime) -> ArraySlice<ScentPod> {
        runtime.pods.filter { runtime.included.contains($0.id) }.prefix(6)
    }

    private func bounceTemplateListButton() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) {
            listButtonBounceToken += 1
        }
    }
}
