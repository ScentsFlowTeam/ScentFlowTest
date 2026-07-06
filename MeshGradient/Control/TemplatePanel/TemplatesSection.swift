// TemplatesSection.swift — refactored to ScentsTemplate + VM + Device

import SwiftUI

struct TemplatesSection: View {
    @ObservedObject var templatesService: TemplatesService
    @ObservedObject var vm: GradientWheelViewModel
    let device: Device

    @State private var showingNameAlert = false
    @State private var newTemplateName: String = ""

    var body: some View {
        VStack(spacing: 12) {

            if templatesService.templates.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        SaveTemplateCard(
                            title: "Save"
                        ) {
                            newTemplateName = "Mix \(templatesService.templates.count + 1)"
                            showingNameAlert = true
                        }
                    }
                }
            } else {
                TemplatesGallery(
                    device: device,
                    templates: templatesService.templates,
                    onTapTemplate: { t in
                        // Apply to wheel (intersects with device pods and rebuilds)
                        vm.applyTemplate(t, on: device)
                        // Persist as active via the store API
                        templatesService.setActiveTemplateID(t.id)
                    },
                    onDeleteTemplate: deleteTemplate
                )
            }

            Spacer()

            HStack {
                Spacer()
                Button {
                    newTemplateName = "Mix \(templatesService.templates.count + 1)"
                    showingNameAlert = true
                } label: {
                    Label("Save", systemImage: "plus.circle.fill").labelStyle(.titleAndIcon)
                }
                .buttonStyle(.glass)
                .controlSize(.large)
                Spacer()
            }
            .padding(.bottom, 16)
        }
        .alert("Save Template", isPresented: $showingNameAlert) {
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
    }

    private func deleteTemplate(_ template: ScentsTemplate) {
        templatesService.remove(id: template.id)

        if vm.currentTemplateID == template.id {
            vm.setCurrentTemplateID(nil)
        }
    }

    private func saveCurrentTemplate(named name: String) {
        // Preserve a stable, user-visible order: the device’s pod order filtered by inclusion
        let orderedIncluded = vm.pods.filter { vm.included.contains($0.id) }.prefix(6)
        guard !orderedIncluded.isEmpty else { return }

        let new = ScentsTemplate(name: name, scentPodNames: orderedIncluded.map(\.name))
        templatesService.add(new)                     // persists
//        templatesService.setActiveTemplateID(new.id)  // publishes + persists
    }
}
