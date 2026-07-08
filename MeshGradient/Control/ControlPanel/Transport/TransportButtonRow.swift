import SwiftUI

struct TransportButtonRow: View {
    let isOn: Bool
    let onToggle: () -> Void

    let showsTemplateTransport: Bool
    let canGoPrevious: Bool
    let canGoNext: Bool
    let listButtonBounceToken: Int
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onOpenTemplateList: () -> Void

    init(
        isOn: Bool,
        onToggle: @escaping () -> Void,
        showsTemplateTransport: Bool = false,
        canGoPrevious: Bool = false,
        canGoNext: Bool = false,
        listButtonBounceToken: Int = 0,
        onPrevious: @escaping () -> Void = {},
        onNext: @escaping () -> Void = {},
        onOpenTemplateList: @escaping () -> Void = {}
    ) {
        self.isOn = isOn
        self.onToggle = onToggle
        self.showsTemplateTransport = showsTemplateTransport
        self.canGoPrevious = canGoPrevious
        self.canGoNext = canGoNext
        self.listButtonBounceToken = listButtonBounceToken
        self.onPrevious = onPrevious
        self.onNext = onNext
        self.onOpenTemplateList = onOpenTemplateList
    }

    var body: some View {
        HStack(spacing: 8) {
            ControlButton(
                systemName: "shuffle",
                accessibilityLabel: "Random template",
                isEnabled: true,
                action: {}
            )

            Spacer(minLength: 4)

            if showsTemplateTransport {
                ControlButton(
                    systemName: "backward.fill",
                    accessibilityLabel: "Previous template",
                    isEnabled: canGoPrevious,
                    action: onPrevious
                )
            }

            GuidedPowerButton(
                isOn: isOn,
                action: onToggle
            )

            if showsTemplateTransport {
                ControlButton(
                    systemName: "forward.fill",
                    accessibilityLabel: "Next template",
                    isEnabled: canGoNext,
                    action: onNext
                )
            }

            Spacer(minLength: 4)

            ControlButton(
                systemName: "list.bullet",
                accessibilityLabel: "Template list",
                isEnabled: true,
                action: onOpenTemplateList,
                bounceToken: listButtonBounceToken
            )
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .center)
        .frame(height: 72)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.35), radius: 14, x: 0, y: -8)
        .accessibilityElement(children: .contain)
    }
}

private struct ControlButton: View {
    let systemName: String
    let accessibilityLabel: String
    let isEnabled: Bool
    let action: () -> Void
    let bounceToken: Int

    private let shape = Capsule()
    private let size: CGFloat = 44

    init(
        systemName: String,
        accessibilityLabel: String,
        isEnabled: Bool,
        action: @escaping () -> Void,
        bounceToken: Int = 0
    ) {
        self.systemName = systemName
        self.accessibilityLabel = accessibilityLabel
        self.isEnabled = isEnabled
        self.action = action
        self.bounceToken = bounceToken
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isEnabled ? .primary : .secondary)
                .frame(width: size, height: size)
//                .background(.thickMaterial, in: shape)
//                .contentShape(shape)
                .opacity(isEnabled ? 1.0 : 0.45)
                .symbolEffect(.bounce, value: bounceToken)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct GuidedPowerButton: View {
    let isOn: Bool
    let action: () -> Void

    @State private var rotation: Double = 0
    @State private var ringToken = UUID()
    @State private var showRing = false
    @State private var revealTask: Task<Void, Never>? = nil

    private let shape = Capsule()
    private let buttonWidth: CGFloat = 60
    private let buttonHeight: CGFloat = 60

    var body: some View {
        Button(action: action) {
            Group {
                if isOn {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 24, weight: .semibold))
                } else {
                    Image(systemName: "play.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .offset(x: 1)
                }
            }
            .foregroundStyle(.primary)
            .frame(width: buttonWidth, height: buttonHeight)
//            .background(.thickMaterial, in: shape)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .overlay {
//            if showRing && !isOn {
//                spinningRing
//                    .id(ringToken)
//                    .padding(-4)
//                    .allowsHitTesting(false)
//                    .onAppear { startSpin() }
//                    .transition(.opacity)
//            }
        }
        .onAppear { updateRingVisibility(for: isOn) }
        .onChange(of: isOn) { _, newValue in
            updateRingVisibility(for: newValue)
        }
        .onDisappear {
            revealTask?.cancel()
        }
        .accessibilityLabel(isOn ? "Turn device off" : "Turn device on")
        .accessibilityValue(isOn ? "On" : "Off")
    }

    private var spinningRing: some View {
        shape
            .strokeBorder(
                AngularGradient(
                    gradient: Gradient(colors: [
                        .red, .orange, .yellow, .green, .cyan, .blue, .purple, .red
                    ]),
                    center: .center,
                    angle: .degrees(rotation)
                ),
                lineWidth: 2.5
            )
            .frame(width: buttonWidth + 8, height: buttonHeight + 8)
    }

    private func updateRingVisibility(for isOn: Bool) {
        revealTask?.cancel()

        if isOn {
            showRing = false
            stopSpin()
            return
        }

        showRing = false
        stopSpin()

        revealTask = Task { @MainActor in
            guard !Task.isCancelled else { return }
            guard !self.isOn else { return }

            ringToken = UUID()
            withAnimation(.easeInOut(duration: 1)) {
                showRing = true
            }
        }
    }

    private func startSpin() {
        rotation = 0
        withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
            rotation = 360
        }
    }

    private func stopSpin() {
        rotation = 0
    }
}
