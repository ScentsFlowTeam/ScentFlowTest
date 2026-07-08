import SwiftUI

struct ControlsSection: View {
    @EnvironmentObject private var app: AppModel
    @ObservedObject var runtime: DeviceRuntime
    let device: Device
    @Binding var size: PodsControlSize

    @StateObject private var panel = ControlPanelViewModel()
    @StateObject private var templateLength = TemplateLengthController()

    private enum UI {
        static let sectionSpacing: CGFloat = 12
        static let horizontalBleed: CGFloat = 16
        // Minimum vertical drag to step one size; a larger drag jumps two sizes.
        static let expansionDragThreshold: CGFloat = 28
        static let bigDragThreshold: CGFloat = 120
    }

    var body: some View {
        VStack(spacing: UI.sectionSpacing) {
            ControlScreenView(
                state: panel.playerDisplayState(
                    runtime: runtime,
                    templatesService: app.templatesService
                ),
                templateLength: templateLength
            )
            .padding(.horizontal, -UI.horizontalBleed)
            .zIndex(1)

            PodsControlView(
                runtime: runtime,
                templateLength: templateLength,
                size: $size,
                canSaveTemplate: runtime.isPowerOn && panel.hasUnsavedEdits(runtime: runtime, templatesService: app.templatesService),
                saveActionTitle: "Save Template",
                saveSystemName: panel.saveSystemName(),
                canCreateTemplate: runtime.isPowerOn && panel.canCreateTemplate(runtime: runtime),
                onSaveTemplate: { panel.handleSave(runtime: runtime, templatesService: app.templatesService) },
                onCreateTemplate: { panel.beginCreateTemplate(templatesService: app.templatesService) },
                onStartTemplateLength: { panel.setTemplateLength($0, runtime: runtime) },
                onClearTemplateLength: { panel.clearTemplateLength(runtime: runtime) },
                onPodIntensityChanged: panel.showAdjustingPod,
                onPodSelected: panel.showAdjustingPod
            )

            ControlTransportSection(
                runtime: runtime,
                templatesService: app.templatesService,
                listButtonBounceToken: panel.listButtonBounceToken,
                onPreviousTemplate: {
                    app.applyPreviousTemplate(to: runtime, on: device)
                },
                onNextTemplate: {
                    app.applyNextTemplate(to: runtime, on: device)
                },
                onOpenTemplateList: { panel.showingTemplatesPage = true }
            )
            .padding(.horizontal, -UI.horizontalBleed)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .contentShape(Rectangle())
        .simultaneousGesture(expansionDragGesture)
        .alert("New Template", isPresented: $panel.showingCreateAlert) {
            TextField("Template name", text: $panel.newTemplateName)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)

            Button("Create") {
                let name = panel.newTemplateName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                panel.saveCurrentTemplate(
                    named: name,
                    runtime: runtime,
                    templatesService: app.templatesService
                )
            }

            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Name your scent mix.")
        }
        .navigationDestination(isPresented: $panel.showingTemplatesPage) {
            TemplatesPage(
                templatesService: app.templatesService,
                runtime: runtime,
                device: device
            )
        }
        .onAppear {
            // The live clock projects itself from the wheel VM's persisted length
            // + power state; no manual per-change syncing needed.
            templateLength.bind(to: runtime)
            // When the length elapses, advance to the next template (looping),
            // carrying the cadence so playback keeps going.
            templateLength.onFinished = {
                app.playNextTemplateOnFinish(to: runtime, on: device)
            }
        }
    }

    private var expansionDragGesture: some Gesture {
        DragGesture(minimumDistance: 18)
            .onEnded { value in
                guard runtime.isPowerOn else { return }

                let translation = value.translation
                guard abs(translation.height) > abs(translation.width),
                      abs(translation.height) >= UI.expansionDragThreshold
                else { return }

                let swipingUp = translation.height < 0
                let bigSwipe = abs(translation.height) >= UI.bigDragThreshold

                var target: PodsControlSize = swipingUp
                    ? (bigSwipe ? .large : size.larger)
                    : (bigSwipe ? .small : size.smaller)

                // The per-pod sliders (large) need more than one pod to be useful.
                if target == .large, runtime.pods.count <= 1 {
                    target = .medium
                }

                setSize(target)
            }
    }

    private func setSize(_ newSize: PodsControlSize) {
        guard size != newSize else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            size = newSize
        }
    }
}
