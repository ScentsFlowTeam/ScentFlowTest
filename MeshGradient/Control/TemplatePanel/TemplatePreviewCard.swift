// TemplatePreviewCard.swift — optional: log + gentle fallback message if empty

import SwiftUI

struct TemplatePreviewCard: View {
    let template: ScentsTemplate
    let device: Device

    var body: some View {
        let palette = paletteForPreview(template: template, device: device)

        return VStack(spacing: 8) {
            if palette.isEmpty {
                ZStack {
                    GradientContainerCircle(colors: [], animate: false, isTemplate: true)
                        .frame(width: 80, height: 80)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .opacity(0.6)
                }
                .help("No matching pods currently inserted.")
            } else {
                GradientContainerCircle(colors: palette, animate: false, isTemplate: true)
                    .frame(width: 80, height: 80)
            }

            Text(template.name)
                .font(.footnote)
                .lineLimit(1)
                .frame(width: 90)
                .multilineTextAlignment(.center)
                .opacity(0.9)
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        )
    }

    /// Build a simple static palette for preview purposes.
    private func paletteForPreview(template: ScentsTemplate, device: Device) -> [Color] {
        let podsInDevice = template.matchingPods(in: device)

        let base = podsInDevice.map { $0.color.color.opacity(0.6) }
        // debug
        // print("Template \(template.name) → matched \(base.count) pods")

        switch base.count {
        case 0: return []
        case 1: return [base[0], base[0].opacity(0.5), base[0]]
        case 2: return [base[0], base[1], base[0].opacity(0.5)]
        default: return base
        }
    }
}
