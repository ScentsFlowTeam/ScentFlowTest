import SwiftUI

struct ControlsSection: View {
    @EnvironmentObject private var app: AppModel
    @ObservedObject var runtime: DeviceRuntime
    let device: Device
    @Binding var size: PodsControlSize
    @ObservedObject var panel: ControlPanelViewModel

    @StateObject private var templateLength = TemplateLengthController()

    private enum UI {
        static let sectionSpacing: CGFloat = 12
        static let horizontalBleed: CGFloat = 16
        // Minimum vertical drag to step one size; a larger drag jumps two sizes.
        static let expansionDragThreshold: CGFloat = 28
        static let bigDragThreshold: CGFloat = 120
        static let floatingCreateButtonSize: CGFloat = 58
    }

    private var canCreateTemplate: Bool {
        runtime.isPowerOn
            && panel.canCreateTemplate(runtime: runtime)
            && !panel.hasUnsavedEdits(runtime: runtime, templatesService: app.templatesService)
    }

    var body: some View {
        VStack {
            // Button
            HStack {
                Spacer(minLength: 0)
                floatingCreateTemplateButton
            }
            .padding(.horizontal, -UI.horizontalBleed)
            
            // Screen + Pods + ControlTransport
            VStack(spacing: 0) {
                ControlScreenView(
                    state: panel.playerDisplayState(
                        runtime: runtime,
                        templatesService: app.templatesService
                    ),
                    templateLength: templateLength
                )
                .padding(.horizontal, -UI.horizontalBleed)
//                .zIndex(1)

                PodsControlView(
                    runtime: runtime,
                    templateLength: templateLength,
                    size: $size,
                    canSaveTemplate: runtime.isPowerOn && panel.hasUnsavedEdits(runtime: runtime, templatesService: app.templatesService),
                    saveActionTitle: "Save Template",
                    saveSystemName: panel.saveSystemName(),
                    onSaveTemplate: { panel.handleSave(runtime: runtime, templatesService: app.templatesService) },
                    onRevertChanges: { panel.handleRevert(runtime: runtime, templatesService: app.templatesService, device: device) },
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
//            
            .background(.regularMaterial)
        }
//
//        .frame(maxWidth: .infinity, alignment: .top)
//        .contentShape(Rectangle())
//        .background(.red)
        
        .simultaneousGesture(expansionDragGesture)
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

    private var floatingCreateTemplateButton: some View {
        Button {
            guard canCreateTemplate else { return }
            panel.beginCreateTemplate(templatesService: app.templatesService)
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(canCreateTemplate ? .primary : .secondary)
                .frame(
                    width: UI.floatingCreateButtonSize,
                    height: UI.floatingCreateButtonSize
                )
                .background(.thickMaterial, in: Circle())
                .contentShape(Circle())
                .opacity(canCreateTemplate ? 1.0 : 0.45)
        }
        .buttonStyle(.plain)
        .disabled(!canCreateTemplate)
        .accessibilityLabel("New template")
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
