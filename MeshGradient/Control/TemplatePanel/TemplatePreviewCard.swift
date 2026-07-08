// TemplatePreviewCard.swift — optional: log + gentle fallback message if empty

import SwiftUI

struct TemplatePreviewCard: View {
    let template: ScentsTemplate
    let device: Device

    var body: some View {
        let palette = template.previewPalette(in: device)

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

            VStack(spacing: 2) {
                Text(template.name)
                    .font(.footnote)
                    .lineLimit(1)

                Text(templateLengthText)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
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

    private var templateLengthText: String {
        guard let duration = template.duration, duration > 0 else { return "∞" }

        let totalSeconds = Int(duration.rounded(.down))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

}
