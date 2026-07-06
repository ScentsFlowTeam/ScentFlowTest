import SwiftUI

struct ControlScreenView: View {
    let state: RetroPlayerDisplay.DisplayState
    @ObservedObject var turnOffTimer: TurnOffTimerController
    let canSave: Bool
    let listButtonBounceToken: Int
    let onExplore: () -> Void
    let onShare: () -> Void
    let onSave: () -> Void
    let onOpenList: () -> Void

    private enum UI {
        static let radius = ControlCornerStyle.radius
        static let inset: CGFloat = 16
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: UI.radius, style: .continuous)

        VStack(spacing: 10) {
            RetroPlayerDisplay(state: state, turnOffTimer: turnOffTimer)
            templateActionRow
        }
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

    private var templateActionRow: some View {
        HStack(spacing: 8) {
            templateActionButton(
                title: "Explore",
                systemName: "sparkles",
                action: onExplore
            )
            .frame(maxWidth: .infinity)

            templateActionButton(
                title: "Share",
                systemName: "square.and.arrow.up",
                action: onShare
            )
            .frame(maxWidth: .infinity)

            templateActionButton(
                title: "Save",
                systemName: "square.and.arrow.down",
                isEnabled: canSave,
                action: onSave
            )
            .frame(maxWidth: .infinity)

            templateActionButton(
                title: "List",
                systemName: "list.bullet",
                action: onOpenList,
                bounceToken: listButtonBounceToken
            )
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }

    private func templateActionButton(
        title: String,
        systemName: String,
        isEnabled: Bool = true,
        action: @escaping () -> Void,
        bounceToken: Int = 0
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isEnabled ? .primary : .secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(.thickMaterial, in: Capsule())
                .contentShape(Capsule())
                .opacity(isEnabled ? 1.0 : 0.45)
                .symbolEffect(.bounce, value: bounceToken)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(title)
    }
}
