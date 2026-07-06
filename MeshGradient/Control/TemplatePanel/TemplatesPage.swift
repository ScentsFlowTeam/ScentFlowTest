//
//  TemplatesPage.swift
//  MeshGradient
//
//  Created by Dajun Xian on 3/19/26.
//

import SwiftUI

struct TemplatesPage: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var templatesService: TemplatesService
    @ObservedObject var vm: GradientWheelViewModel
    let device: Device

    @State private var displayMode: DisplayMode = .list

    private let galleryColumns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        Group {
            if templatesService.templates.isEmpty {
                emptyStateView
            } else {
                switch displayMode {
                case .gallery:
                    galleryView
                case .list:
                    listView
                        
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
//        .navigationTitle("Templates")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        displayMode = .list
                    }
                } label: {
                    Image(systemName: "list.bullet")
                        .foregroundStyle(displayMode == .list ? .primary : .secondary)
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        displayMode = .gallery
                    }
                } label: {
                    Image(systemName: "square.grid.2x2")
                        .foregroundStyle(displayMode == .gallery ? .primary : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var galleryView: some View {
        ScrollView {
            LazyVGrid(columns: galleryColumns, spacing: 14) {
                ForEach(templatesService.templates) { template in
                    Button {
                        apply(template)
                    } label: {
                        ZStack(alignment: .topLeading) {
                            HStack {
                                Spacer(minLength: 0)
                                TemplatePreviewCard(template: template, device: device)
                                Spacer(minLength: 0)
                            }

                            if isPlaying(template) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.green)
                                    .padding(8)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
    }

    private var listView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("My Templates")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 16)

            List {
                ForEach(templatesService.templates) { template in
                    TemplateListRow(
                        template: template,
                        device: device,
                        isPlaying: isPlaying(template)
                    )
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        apply(template)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            delete(template)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.black)
            
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.stack.3d.up")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("No templates yet")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func apply(_ template: ScentsTemplate) {
        vm.applyTemplate(template, on: device)
        templatesService.setActiveTemplateID(template.id)
        dismiss()
    }

    private func delete(_ template: ScentsTemplate) {
        templatesService.remove(id: template.id)

        if vm.currentTemplateID == template.id {
            vm.setCurrentTemplateID(nil)
        }
    }

    private func isPlaying(_ template: ScentsTemplate) -> Bool {
        vm.isUsingTemplate && vm.currentTemplateID == template.id
    }
}

private extension TemplatesPage {
    enum DisplayMode: Hashable {
        case gallery
        case list
    }
}

private struct TemplateListRow: View {
    let template: ScentsTemplate
    let device: Device
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 14) {
            TemplateListPreview(template: template, device: device)

            VStack(alignment: .leading, spacing: 4) {
                Text(template.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(podNamesText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Text(templateLengthText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if isPlaying {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.green)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var podNamesText: String {
        let names = template.matchingPods(in: device).map(\.name)

        if names.isEmpty {
            return "No matching inserted pods"
        }
        return names.joined(separator: " · ")
    }

    private var templateLengthText: String {
        guard let duration = template.duration, duration > 0 else { return "Length: ∞" }

        let totalSeconds = Int(duration.rounded(.down))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "Length: %02d:%02d", minutes, seconds)
    }
}

private struct TemplateListPreview: View {
    let template: ScentsTemplate
    let device: Device

    var body: some View {
        let palette = paletteForPreview(template: template, device: device)

        return ZStack {
            if palette.isEmpty {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
            } else {
                GradientContainerCircle(colors: palette, animate: false, isTemplate: true)
            }
        }
        .frame(width: 48, height: 48)
    }

    private func paletteForPreview(template: ScentsTemplate, device: Device) -> [Color] {
        let podsInDevice = template.matchingPods(in: device)

        let base = podsInDevice.map { $0.color.color.opacity(0.6) }

        switch base.count {
        case 0: return []
        case 1: return [base[0], base[0].opacity(0.5), base[0]]
        case 2: return [base[0], base[1], base[0].opacity(0.5)]
        default: return base
        }
    }
}
