import SwiftUI

struct ControlScreenView: View {
    let state: RetroPlayerDisplay.DisplayState
    @ObservedObject var templateLength: TemplateLengthController

    /// When naming a new template the screen shows an inline text field instead
    /// of the retro playback display, keeping the input above the keyboard.
    var isNaming: Bool = false
    var name: Binding<String> = .constant("")
    var onSubmitName: () -> Void = {}

    @FocusState private var nameFieldFocused: Bool

    private enum UI {
        static let radius = ControlCornerStyle.radius
        static let inset: CGFloat = 16
        static let displayHeight: CGFloat = 96
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: UI.radius, style: .continuous)

        screenContent
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
            .onChange(of: isNaming) { _, naming in
                nameFieldFocused = naming
            }
            .onAppear {
                if isNaming { nameFieldFocused = true }
            }
    }

    @ViewBuilder
    private var screenContent: some View {
        if isNaming {
            namingField
        } else {
            RetroPlayerDisplay(state: state, templateLength: templateLength)
        }
    }

    /// Dark LCD-styled naming field that reuses `RetroPlayerDisplay`'s header /
    /// separator / body / footer rhythm, with "New Template" as the header and the
    /// editable "Mix N" name in the body.
    private var namingField: some View {
        VStack(spacing: 0) {
            header
                .frame(height: 18)

            separator

            nameEntry
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            separator

            footer
                .frame(height: 18)
        }
        .frame(maxWidth: .infinity, minHeight: UI.displayHeight, maxHeight: UI.displayHeight, alignment: .center)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            if #available(iOS 26.0, *) {
                ConcentricRectangle(corners: .concentric(minimum: 16), isUniform: true)
                    .fill(Color.black.opacity(0.85))
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.85))
            }
        }
    }

    private var header: some View {
        Text("New Template")
            .font(.system(.caption, design: .monospaced).weight(.semibold))
            .foregroundStyle(.white.opacity(0.58))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var nameEntry: some View {
        TextField(
            "",
            text: name,
            prompt: Text("Mix")
                .foregroundColor(.white.opacity(0.3))
        )
        .textFieldStyle(.plain)
        .font(.system(.callout, design: .monospaced).weight(.semibold))
        .foregroundStyle(.white.opacity(0.82))
        .tint(.white)
        .multilineTextAlignment(.center)
        .lineLimit(1)
        .minimumScaleFactor(0.62)
        .textInputAutocapitalization(.words)
        .disableAutocorrection(true)
        .submitLabel(.done)
        .focused($nameFieldFocused)
        .onSubmit(onSubmitName)
        .frame(maxWidth: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)

            Text(" ")
                .font(.system(.footnote, design: .monospaced).weight(.semibold))
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(height: 1)
    }

    private var dragHandle: some View {
        Capsule()
            .fill(Color.secondary.opacity(0.55))
            .frame(width: 44, height: 5)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
