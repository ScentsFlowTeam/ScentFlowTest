import SwiftUI

struct PowerButtonRow: View {
    let isOn: Bool
    let speed: Double
    let onToggle: () -> Void
    let onChangeSpeed: (Double) -> Void

    let showsTemplateTransport: Bool
    let canGoPrevious: Bool
    let canGoNext: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onOpenTemplates: () -> Void

    let turnOffTimer: TurnOffTimerController
    let onStartTurnOffTimer: (TimeInterval) -> Void
    let onCancelTurnOffTimer: () -> Void
    let listButtonBounceToken: Int

    init(
        isOn: Bool,
        speed: Double,
        onToggle: @escaping () -> Void,
        onChangeSpeed: @escaping (Double) -> Void,
        showsTemplateTransport: Bool = false,
        canGoPrevious: Bool = false,
        canGoNext: Bool = false,
        onPrevious: @escaping () -> Void = {},
        onNext: @escaping () -> Void = {},
        onOpenTemplates: @escaping () -> Void = {},
        turnOffTimer: TurnOffTimerController,
        onStartTurnOffTimer: @escaping (TimeInterval) -> Void,
        onCancelTurnOffTimer: @escaping () -> Void,
        listButtonBounceToken: Int = 0
    ) {
        self.isOn = isOn
        self.speed = speed
        self.onToggle = onToggle
        self.onChangeSpeed = onChangeSpeed
        self.showsTemplateTransport = showsTemplateTransport
        self.canGoPrevious = canGoPrevious
        self.canGoNext = canGoNext
        self.onPrevious = onPrevious
        self.onNext = onNext
        self.onOpenTemplates = onOpenTemplates
        self.turnOffTimer = turnOffTimer
        self.onStartTurnOffTimer = onStartTurnOffTimer
        self.onCancelTurnOffTimer = onCancelTurnOffTimer
        self.listButtonBounceToken = listButtonBounceToken
    }

    var body: some View {
        HStack  {
            TurnOffTimerButton(
                isDeviceOn: isOn,
                controller: turnOffTimer,
                onStart: onStartTurnOffTimer,
                onCancel: onCancelTurnOffTimer
            )
            .padding(.leading, 16)

            Spacer()
            
            if showsTemplateTransport {
                ControlButton(
                    systemName: "backward.fill",
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
                    isEnabled: canGoNext,
                    action: onNext
                )
            }

            Spacer()
            
            ControlButton(
                systemName: "list.bullet",
                isEnabled: true,
                action: onOpenTemplates,
                bounceToken: listButtonBounceToken
            )
            .padding(.trailing, 16)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .frame(maxHeight: 72)
        .background(.red, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .accessibilityElement(children: .contain)
        
    }
}

private struct ControlButton: View {
    let systemName: String
    let isEnabled: Bool
    let action: () -> Void
    let bounceToken: Int

    private let shape = Capsule()
    private let size: CGFloat = 44

    init(
        systemName: String,
        isEnabled: Bool,
        action: @escaping () -> Void,
        bounceToken: Int = 0
    ) {
        self.systemName = systemName
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
                .background(.thickMaterial, in: shape)
                .contentShape(shape)
                .opacity(isEnabled ? 1.0 : 0.45)
                .symbolEffect(.bounce, value: bounceToken)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
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
            .background(.thickMaterial, in: shape)
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
