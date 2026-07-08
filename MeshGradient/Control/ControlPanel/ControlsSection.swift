import SwiftUI

struct ControlsSection: View {
    @EnvironmentObject private var app: AppModel
    @ObservedObject var runtime: DeviceRuntime
    let device: Device
    @Binding var size: PodsControlSize
    @Binding var isNamingTemplate: Bool

    @StateObject private var panel = ControlPanelViewModel()
    @StateObject private var templateLength = TemplateLengthController()

    private var trimmedNewName: String {
        panel.newTemplateName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

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
                    templateLength: templateLength,
                    isNaming: panel.showingCreateAlert,
                    name: $panel.newTemplateName,
                    onSubmitName: createTemplate
                )
                .padding(.horizontal, -UI.horizontalBleed)
//                .zIndex(1)

                // While naming a new template, the screen becomes the input and
                // only the Cancel/Create actions show — the pods and transport are
                // hidden so the dialog sits directly above the keyboard.
                if panel.showingCreateAlert {
                    newTemplateActions
                        .transition(.opacity)
                } else {
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
            }
//            
            .background(.thinMaterial)
        }
//
//        .frame(maxWidth: .infinity, alignment: .top)
//        .contentShape(Rectangle())
//        .background(.red)
        
        .simultaneousGesture(expansionDragGesture)
        .onChange(of: panel.showingCreateAlert) { _, naming in
            // Let the enclosing panel hug its content while naming (see ControlPanel).
            isNamingTemplate = naming
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

    private var newTemplateActions: some View {
        HStack(spacing: 12) {
            Button("Cancel") { cancelNaming() }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(.thickMaterial, in: Capsule())
                .foregroundStyle(.primary)

            Button("Create") { createTemplate() }
                .disabled(trimmedNewName.isEmpty)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(.thickMaterial, in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(.white.opacity(trimmedNewName.isEmpty ? 0.15 : 0.85), lineWidth: 1)
                }
                .foregroundStyle(.primary)
                .opacity(trimmedNewName.isEmpty ? 0.5 : 1)
        }
        .font(.system(size: 15, weight: .semibold))
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }

    private func createTemplate() {
        let name = trimmedNewName
        guard !name.isEmpty else { return }
        panel.saveCurrentTemplate(
            named: name,
            runtime: runtime,
            templatesService: app.templatesService
        )
        withAnimation(.easeInOut(duration: 0.2)) {
            panel.showingCreateAlert = false
        }
    }

    private func cancelNaming() {
        panel.newTemplateName = ""
        withAnimation(.easeInOut(duration: 0.2)) {
            panel.showingCreateAlert = false
        }
    }

    private var floatingCreateTemplateButton: some View {
        Button {
            guard canCreateTemplate else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                panel.beginCreateTemplate(templatesService: app.templatesService)
            }
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
