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
    @StateObject private var turnOffTimer = TurnOffTimerController()
    @State private var listButtonBounceToken = 0
    @State private var temporaryPodDisplay: String?
    @State private var temporaryPodDisplayTask: Task<Void, Never>?

    private enum UI {
        static let sectionSpacing: CGFloat = 16
        static let horizontalBleed: CGFloat = 16
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
        let shape = RoundedRectangle(cornerRadius: 32, style: .continuous)

        return ZStack(alignment: .topTrailing) {
            RetroPlayerDisplay(state: playerDisplayState)
                .padding(16)

//            saveTemplateButton
        }
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

        temporaryPodDisplay = "\(pod.name.uppercased()): \(percent)%"
        temporaryPodDisplayTask?.cancel()
        temporaryPodDisplayTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            temporaryPodDisplay = nil
        }
    }

    private var saveTemplateButton: some View {
        HStack {
            Spacer()

            Button {
                newTemplateName = "Mix \(app.templatesService.templates.count + 1)"
                showingSaveAlert = true
            } label: {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(vm.included.isEmpty ? .secondary : .primary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(vm.included.isEmpty)
            .opacity(vm.included.isEmpty ? 0.45 : 1.0)
        }
    }

    private func saveCurrentTemplate(named name: String) {
        let orderedIncluded = vm.pods.map(\.id).filter { vm.included.contains($0) }.prefix(6)
        guard !orderedIncluded.isEmpty else { return }

        let new = ScentsTemplate(name: name, scentPodIDs: Array(orderedIncluded))
        app.templatesService.add(new)
        app.templatesService.setActiveTemplateID(new.id)
        vm.setCurrentTemplateID(new.id)

        withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) {
            listButtonBounceToken += 1
        }
    }
}
