import SwiftUI

struct ControlsSection: View {
    @EnvironmentObject private var app: AppModel
    @ObservedObject var vm: GradientWheelViewModel
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
                    gradientVM: vm,
                    templatesService: app.templatesService
                ),
                templateLength: templateLength
            )
            .padding(.horizontal, -UI.horizontalBleed)
            .zIndex(1)

            PodsControlView(
                vm: vm,
                templateLength: templateLength,
                size: $size,
                canSaveTemplate: vm.isPowerOn && panel.canSaveTemplate(gradientVM: vm),
                saveActionTitle: panel.saveActionTitle(gradientVM: vm, templatesService: app.templatesService),
                saveSystemName: panel.saveSystemName(),
                onSaveTemplate: { panel.handleSave(gradientVM: vm, templatesService: app.templatesService) },
                onStartTemplateLength: { panel.setTemplateLength($0, gradientVM: vm, templateLength: templateLength) },
                onClearTemplateLength: { panel.clearTemplateLength(gradientVM: vm, templateLength: templateLength) },
                onPodIntensityChanged: panel.showAdjustingPod,
                onPodSelected: panel.showAdjustingPod
            )

            ControlTransportSection(
                vm: vm,
                templatesService: app.templatesService,
                listButtonBounceToken: panel.listButtonBounceToken,
                onPreviousTemplate: {
                    app.applyPreviousTemplate(to: vm, on: device)
                },
                onNextTemplate: {
                    app.applyNextTemplate(to: vm, on: device)
                },
                onOpenTemplateList: { panel.showingTemplatesPage = true }
            )
            .padding(.horizontal, -UI.horizontalBleed)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .contentShape(Rectangle())
        .simultaneousGesture(expansionDragGesture)
        .confirmationDialog("", isPresented: $panel.showingSaveOptions, titleVisibility: .hidden) {
            if let sourceTemplate = panel.sourceTemplate(gradientVM: vm, templatesService: app.templatesService) {
                Button("Update \(sourceTemplate.name)") {
                    panel.updateTemplate(
                        sourceTemplate,
                        gradientVM: vm,
                        templatesService: app.templatesService,
                        templateLength: templateLength
                    )
                }

                Button("Save as New Template") {
                    panel.beginSaveTemplate(prefilledName: "\(sourceTemplate.name) Copy")
                }
            }
        }
        .alert("New Template", isPresented: $panel.showingSaveAlert) {
            TextField("Template name", text: $panel.newTemplateName)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)

            Button("Save") {
                let name = panel.newTemplateName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                panel.saveCurrentTemplate(
                    named: name,
                    gradientVM: vm,
                    templatesService: app.templatesService,
                    templateLength: templateLength
                )
            }

            Button("Cancel", role: .cancel) {
                panel.newTemplateName = ""
            }
        } message: {
            Text("Enter a name for this scent mix.")
        }
        .navigationDestination(isPresented: $panel.showingTemplatesPage) {
            TemplatesPage(
                templatesService: app.templatesService,
                vm: vm,
                device: device
            )
        }
        .onAppear {
            panel.onAppear(
                gradientVM: vm,
                templatesService: app.templatesService,
                templateLength: templateLength
            )
            // When the length elapses, advance to the next template in the list.
            templateLength.onFinished = {
                app.applyNextTemplate(to: vm, on: device)
            }
        }
        .onChange(of: vm.currentTemplateID) { _, id in
            panel.templateIDChanged(
                to: id,
                gradientVM: vm,
                templatesService: app.templatesService,
                templateLength: templateLength
            )
        }
        .onChange(of: vm.isPowerOn) { _, isOn in
            panel.powerChanged(isOn: isOn, templateLength: templateLength)
        }
        .onChange(of: vm.templateLengthDuration) { _, _ in
            panel.syncTemplateLength(gradientVM: vm, templateLength: templateLength)
        }
        .onChange(of: vm.templateLengthStartDate) { _, _ in
            panel.syncTemplateLength(gradientVM: vm, templateLength: templateLength)
        }
    }

    private var expansionDragGesture: some Gesture {
        DragGesture(minimumDistance: 18)
            .onEnded { value in
                guard vm.isPowerOn else { return }

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
                if target == .large, vm.pods.count <= 1 {
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
