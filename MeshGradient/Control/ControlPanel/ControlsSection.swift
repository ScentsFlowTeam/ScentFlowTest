// ControlsSection.swift  — FIXED call to ScentControllerStepper + ID-centric

//
//  ControlsSection.swift
//
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
    @State private var temporaryPodDisplay: String?
    @State private var temporaryPodDisplayTask: Task<Void, Never>?

    private enum UI {
        static let sectionSpacing: CGFloat = 12
        static let horizontalBleed: CGFloat = 16
        static let screenPartRadius = ControlCornerStyle.radius
        static let screenPartInset: CGFloat = 16
    }

    var body: some View {
        VStack(spacing: UI.sectionSpacing) {
            screenPart
                .padding(.horizontal, -UI.horizontalBleed)
                .zIndex(1)

            PodsControlView(
                vm: vm,
                isExpanded: $isExpanded,
                onPodIntensityChanged: { pod, value in
                    showTemporaryPodDisplay(for: pod, value: value)
                },
                onPodSelected: { pod, value in
                    showTemporaryPodDisplay(for: pod, value: value)
                }
            )

            powerButtonRow
                .padding(.horizontal, -UI.horizontalBleed)
        }
        .frame(maxWidth: .infinity, alignment: .top)
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
        .onChange(of: vm.isPowerOn) { _, isOn in
            if !isOn {
                turnOffTimer.clear()
            }
        }
        .onDisappear {
            temporaryPodDisplayTask?.cancel()
        }
    }

    private var powerButtonRow: some View {
        PowerButtonRow(
            isOn: vm.isPowerOn,
            speed: vm.fanSpeed,
            onToggle: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                    vm.togglePower()
                }
            },
            onChangeSpeed: { vm.setFanSpeed($0) },
            showsTemplateTransport: !app.templatesService.templates.isEmpty,
            canGoPrevious: vm.isUsingTemplate && app.templatesService.canGoPrevious,
            canGoNext: vm.isUsingTemplate && app.templatesService.canGoNext,
            onPrevious: {
                app.applyPreviousTemplate(to: vm, on: device)
            },
            onNext: {
                app.applyNextTemplate(to: vm, on: device)
            },
            onOpenTemplates: {
                showingTemplatesPage = true
            },
            turnOffTimer: turnOffTimer,
            onStartTurnOffTimer: { duration in
                turnOffTimer.start(duration: duration) {
                    if vm.isPowerOn {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                            vm.setPower(false)
                        }
                    }
                }
            },
            onCancelTurnOffTimer: {
                turnOffTimer.clear()
            },
            listButtonBounceToken: listButtonBounceToken
        )
    }

    private var screenPart: some View {
        let shape = RoundedRectangle(cornerRadius: UI.screenPartRadius, style: .continuous)

        return VStack(spacing: 10) {
            RetroPlayerDisplay(state: playerDisplayState)

            templateActionRow
        }
        .padding(UI.screenPartInset)
        .frame(maxWidth: .infinity)
        .containerShape(shape)
        .background(.ultraThickMaterial, in: shape)
        .overlay {
            shape
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.35), radius: 14, x: 0, y: 8)
    }

    private var currentTemplate: ScentsTemplate? {
        guard vm.isUsingTemplate,
              let id = vm.currentTemplateID
        else { return nil }

        return app.templatesService.templates.first(where: { $0.id == id })
    }

    private var playerDisplayState: RetroPlayerDisplay.DisplayState {
        if let temporaryPodDisplay {
            return .podChange(message: temporaryPodDisplay)
        }

        guard vm.isPowerOn else { return .deviceOff }

        let title = currentTemplate?.name ?? "Unsaved Template"
        let position = currentTemplate.flatMap { template in
            app.templatesService.templates.firstIndex(where: { $0.id == template.id }).map { $0 + 1 }
        }

        return .playing(
            title: title,
            position: position,
            total: app.templatesService.templates.count
        )
    }

    private func showTemporaryPodDisplay(for pod: ScentPod, value: Double) {
        let maxIntensity = max(0.0001, AppConfig.maxIntensity)
        let clamped = min(max(value, 0), maxIntensity)
        let percent = Int((clamped / maxIntensity * 100).rounded())

        temporaryPodDisplay = "\(pod.name): \(percent)%"
        temporaryPodDisplayTask?.cancel()
        temporaryPodDisplayTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            temporaryPodDisplay = nil
        }
    }

    private var templateActionRow: some View {
        HStack(spacing: 8) {
            templateActionButton(
                title: "Explore",
                systemName: "sparkles",
                action: {
                    showingTemplateExplorePage = true
                }
            )
            .frame(maxWidth: .infinity)

            templateActionButton(
                title: "Share",
                systemName: "square.and.arrow.up",
                action: {}
            )
            .frame(maxWidth: .infinity)

            templateActionButton(
                title: "Save",
                systemName: "square.and.arrow.down",
                isEnabled: !vm.included.isEmpty,
                action: {
                    newTemplateName = "Mix \(app.templatesService.templates.count + 1)"
                    showingSaveAlert = true
                }
            )
            .frame(maxWidth: .infinity)

            templateActionButton(
                title: "List",
                systemName: "list.bullet",
                action: {
                    showingTemplatesPage = true
                },
                bounceToken: listButtonBounceToken
            )
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }

    private func templateActionButton(
        title: String,
        systemName: String,
        isEnabled: Bool = true,
        action: @escaping () -> Void,
        bounceToken: Int = 0
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isEnabled ? .primary : .secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(.thickMaterial, in: Capsule())
                .contentShape(Capsule())
                .opacity(isEnabled ? 1.0 : 0.45)
                .symbolEffect(.bounce, value: bounceToken)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(title)
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
