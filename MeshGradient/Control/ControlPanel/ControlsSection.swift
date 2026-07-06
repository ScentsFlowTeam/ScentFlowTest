import SwiftUI

struct ControlsSection: View {
    @EnvironmentObject private var app: AppModel
    @ObservedObject var vm: GradientWheelViewModel
    let device: Device
    @Binding var isExpanded: Bool

    @State private var showingSaveAlert = false
    @State private var newTemplateName: String = ""
    @State private var showingTemplatesPage = false
    @State private var showingTemplateExplorePage = false
    @StateObject private var turnOffTimer = TurnOffTimerController()
    @State private var listButtonBounceToken = 0
    @State private var adjustingPodText: String?
    @State private var adjustingPodTask: Task<Void, Never>?

    private enum UI {
        static let sectionSpacing: CGFloat = 12
        static let horizontalBleed: CGFloat = 16
        static let expansionDragThreshold: CGFloat = 28
    }

    var body: some View {
        VStack(spacing: UI.sectionSpacing) {
            ControlScreenView(
                state: playerDisplayState,
                turnOffTimer: turnOffTimer,
                canSave: !vm.included.isEmpty,
                listButtonBounceToken: listButtonBounceToken,
                onExplore: { showingTemplateExplorePage = true },
                onShare: {},
                onSave: beginSaveTemplate,
                onOpenList: { showingTemplatesPage = true }
            )
            .padding(.horizontal, -UI.horizontalBleed)
            .zIndex(1)

            PodsControlView(
                vm: vm,
                isExpanded: $isExpanded,
                onPodIntensityChanged: showAdjustingPod,
                onPodSelected: showAdjustingPod
            )

            ControlPowerSection(
                vm: vm,
                templatesService: app.templatesService,
                turnOffTimer: turnOffTimer,
                onPreviousTemplate: {
                    app.applyPreviousTemplate(to: vm, on: device)
                },
                onNextTemplate: {
                    app.applyNextTemplate(to: vm, on: device)
                }
            )
            .padding(.horizontal, -UI.horizontalBleed)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .contentShape(Rectangle())
        .simultaneousGesture(expansionDragGesture)
        .alert("Save Template", isPresented: $showingSaveAlert) {
            TextField("Template name", text: $newTemplateName)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)

            Button("Save") {
                let name = newTemplateName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                saveCurrentTemplate(named: name)
                newTemplateName = ""
            }

            Button("Cancel", role: .cancel) {
                newTemplateName = ""
            }
        } message: {
            Text("Enter a name for this scent mix.")
        }
        .navigationDestination(isPresented: $showingTemplatesPage) {
            TemplatesPage(
                templatesService: app.templatesService,
                vm: vm,
                device: device
            )
        }
        .navigationDestination(isPresented: $showingTemplateExplorePage) {
            TemplateExplorePage()
        }
        .onDisappear {
            adjustingPodTask?.cancel()
        }
    }

    private var expansionDragGesture: some Gesture {
        DragGesture(minimumDistance: 18)
            .onEnded { value in
                guard vm.isPowerOn, vm.pods.count > 1 else { return }

                let translation = value.translation
                guard abs(translation.height) > abs(translation.width),
                      abs(translation.height) >= UI.expansionDragThreshold
                else { return }

                setExpanded(translation.height < 0)
            }
    }

    private func setExpanded(_ expanded: Bool) {
        guard isExpanded != expanded else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            isExpanded = expanded
        }
    }

    private var currentTemplate: ScentsTemplate? {
        guard vm.isUsingTemplate,
              let id = vm.currentTemplateID
        else { return nil }

        return app.templatesService.templates.first(where: { $0.id == id })
    }

    private var playerDisplayState: RetroPlayerDisplay.DisplayState {
        guard vm.isPowerOn else { return .deviceOff }

        let title = currentTemplate?.name ?? "Unsaved Template"
        let position = currentTemplate.flatMap { template in
            app.templatesService.templates.firstIndex(where: { $0.id == template.id }).map { $0 + 1 }
        }

        return .playing(
            title: title,
            bodyText: activePodsIntensityText,
            position: position,
            total: app.templatesService.templates.count
        )
    }

    private var activePodsIntensityText: String {
        if let adjustingPodText {
            return adjustingPodText
        }

        let activePods = vm.pods.filter { vm.included.contains($0.id) }
        guard !activePods.isEmpty else { return "No active pods" }

        return activePods
            .map { pod in intensityText(for: pod, value: vm.opacities[pod.id] ?? 0) }
            .joined(separator: "  ")
    }

    private func intensityText(for pod: ScentPod, value: Double) -> String {
        let maxIntensity = max(0.0001, AppConfig.maxIntensity)
        let clamped = min(max(value, 0), maxIntensity)
        let percent = Int((clamped / maxIntensity * 100).rounded())
        return "\(pod.name): \(percent)%"
    }

    private func showAdjustingPod(for pod: ScentPod, value: Double) {
        adjustingPodText = intensityText(for: pod, value: value)
        adjustingPodTask?.cancel()
        adjustingPodTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            adjustingPodText = nil
        }
    }

    private func beginSaveTemplate() {
        newTemplateName = "Mix \(app.templatesService.templates.count + 1)"
        showingSaveAlert = true
    }

    private func saveCurrentTemplate(named name: String) {
        let orderedIncluded = vm.pods.filter { vm.included.contains($0.id) }.prefix(6)
        guard !orderedIncluded.isEmpty else { return }

        let new = ScentsTemplate(name: name, scentPodNames: orderedIncluded.map(\.name))
        app.templatesService.add(new)
        app.templatesService.setActiveTemplateID(new.id)
        vm.setCurrentTemplateID(new.id)

        withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) {
            listButtonBounceToken += 1
        }
    }
}
