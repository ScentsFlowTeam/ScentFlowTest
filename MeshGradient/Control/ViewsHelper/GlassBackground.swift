//
//  GlassBackground.swift
//  MeshGradient
//
//  Created by Dajun Xian on 9/9/25.
//

import SwiftUI

enum ControlCornerStyle {
    static let radius: CGFloat = 32

    static var fallbackShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }
}

/// Glass/material background helper that prefers iOS 26 Liquid Glass,
/// and falls back to material on earlier systems.
struct AdaptiveGlassBackground<FallbackShape: Shape>: ViewModifier {
    let fallbackShape: FallbackShape
    let useConcentricOnIOS26: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            if useConcentricOnIOS26 {
                content.glassEffect(.regular, in: ConcentricRectangle())
            } else {
                content.glassEffect(.regular, in: fallbackShape)
            }
        } else {
            content.background(.ultraThinMaterial, in: fallbackShape)
        }
        #else
        content.background(.ultraThinMaterial, in: fallbackShape)
        #endif
    }
}

private struct ControlConcentricGlassBackground: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            content
                .containerShape(ControlCornerStyle.fallbackShape)
                .glassEffect(.regular, in: ConcentricRectangle())
        } else {
            content.background(.ultraThinMaterial, in: ControlCornerStyle.fallbackShape)
        }
        #else
        content.background(.ultraThinMaterial, in: ControlCornerStyle.fallbackShape)
        #endif
    }
}

private struct ControlConcentricFilledBackground: ViewModifier {
    let fill: Color
    let stroke: Color?

    @ViewBuilder
    func body(content: Content) -> some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            content
                .containerShape(ControlCornerStyle.fallbackShape)
                .background(fill, in: ConcentricRectangle())
                .overlay {
                    if let stroke {
                        ConcentricRectangle()
                            .stroke(stroke, lineWidth: 1)
                    }
                }
        } else {
            content
                .background(fill, in: ControlCornerStyle.fallbackShape)
                .overlay {
                    if let stroke {
                        ControlCornerStyle.fallbackShape
                            .strokeBorder(stroke, lineWidth: 1)
                    }
                }
        }
        #else
        content
            .background(fill, in: ControlCornerStyle.fallbackShape)
            .overlay {
                if let stroke {
                    ControlCornerStyle.fallbackShape
                        .strokeBorder(stroke, lineWidth: 1)
                }
            }
        #endif
    }
}

extension View {
    /// Apply a glassy background clipped to `shape`, using the best API available.
    ///
    /// - Parameters:
    ///   - shape: Fallback shape for pre-iOS 26 systems, or the explicit iOS 26 shape when
    ///            `useConcentricOnIOS26` is false.
    ///   - useConcentricOnIOS26: Uses `ConcentricRectangle()` on iOS 26+.
    func adaptiveGlassBackground<S: Shape>(
        _ shape: S,
        useConcentricOnIOS26: Bool = false
    ) -> some View {
        modifier(
            AdaptiveGlassBackground(
                fallbackShape: shape,
                useConcentricOnIOS26: useConcentricOnIOS26
            )
        )
    }

    func controlConcentricGlassBackground() -> some View {
        modifier(ControlConcentricGlassBackground())
    }

    func controlConcentricFilledBackground(_ fill: Color, stroke: Color? = nil) -> some View {
        modifier(ControlConcentricFilledBackground(fill: fill, stroke: stroke))
    }
}
