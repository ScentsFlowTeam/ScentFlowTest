import SwiftUI

struct ControlScreenView: View {
    let state: RetroPlayerDisplay.DisplayState
    @ObservedObject var templateLength: TemplateLengthController

    private enum UI {
        static let radius = ControlCornerStyle.radius
        static let inset: CGFloat = 16
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: UI.radius, style: .continuous)

        RetroPlayerDisplay(state: state, templateLength: templateLength)
            .padding(UI.inset)
            .frame(maxWidth: .infinity)
            .containerShape(shape)
            .background(.ultraThickMaterial, in: shape)
            .overlay {
                shape
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            }
            .overlay(alignment: .top) {
                dragHandle
                    .padding(.top, 6)
            }
            .shadow(color: Color.black.opacity(0.35), radius: 14, x: 0, y: 8)
    }

    private var dragHandle: some View {
        Capsule()
            .fill(Color.secondary.opacity(0.55))
            .frame(width: 44, height: 5)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
