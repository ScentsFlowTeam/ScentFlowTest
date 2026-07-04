//
//  SaveTemplateCard.swift
//  MeshGradient
//
//  Created by Dajun Xian on 9/25/25.
//


import SwiftUI

struct SaveTemplateCard: View {
    var title: String = "Save"
    var subtitle: String = "Capture current mix"
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Art area – sized like TemplatePreviewCard's 80×80 render
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)

                    Image(systemName: "plus")
                        .font(.system(size: 36, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .opacity(0.95)
                }
                .frame(width: 80, height: 80)

                Text(title)
                    .font(.footnote)
                    .lineLimit(1)
                    .frame(width: 90)
                    .multilineTextAlignment(.center)
                    .opacity(1)
            }
            .padding(10)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        )
    }
}
