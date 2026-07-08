import SwiftUI

struct TemplateLengthButton: View {
    let isDeviceOn: Bool
    @ObservedObject var controller: TemplateLengthController
    let onStart: (TimeInterval) -> Void
    let onCancel: () -> Void

    @State private var showingSheet = false
    @State private var selectedHours = 0
    @State private var selectedMinutes = 5

    var body: some View {
        Button {
            guard isDeviceOn || controller.isActive else { return }
            showingSheet = true
        } label: {
            buttonLabel
                .foregroundStyle(timerForeground)
                .frame(width: 64, height: 44)
                .background(timerBackground, in: Capsule())
                .contentShape(Capsule())
                .opacity((isDeviceOn || controller.isActive) ? 1.0 : 0.45)

//            Progress ring moved to RetroPlayerDisplay timeline.
//            ZStack {
//                Circle()
//                    .fill(.thickMaterial)
//
//                if controller.isActive {
//                    Circle()
//                        .stroke(Color.white.opacity(0.12), lineWidth: 2)
//
//                    Circle()
//                        .trim(from: 0, to: remainingRingFraction)
//                        .stroke(
//                            Color.white.opacity(0.6),
//                            style: StrokeStyle(lineWidth: 2, lineCap: .round)
//                        )
//                        .rotationEffect(.degrees(-90))
//
//                    Image(systemName: "timer")
//                        .font(.system(size: 16, weight: .semibold))
//                        .foregroundStyle(.primary)
//                } else {
//                    Image(systemName: "timer")
//                        .font(.system(size: 16, weight: .semibold))
//                        .foregroundStyle(isDeviceOn ? .primary : .secondary)
//                }
//            }
//            .frame(width: 44, height: 44)
//            .opacity((isDeviceOn || controller.isActive) ? 1.0 : 0.45)
        }
        .buttonStyle(.plain)
        .disabled(!isDeviceOn && !controller.isActive)
        .sheet(isPresented: $showingSheet) {
            timerSheet
                .presentationDetents([.height(controller.isActive ? 280 : 360)])
                .presentationDragIndicator(.visible)
        }
    }

//    private var remainingRingFraction: Double {
//        guard controller.totalDuration > 0 else { return 0 }
//        return max(0, min(1, controller.remainingDuration / controller.totalDuration))
//    }

    private var timerSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if controller.isActive {
                    VStack(spacing: 10) {
                        Text("Template Length")
                            .font(.headline)

                        Text(controller.playbackText)
                            .font(.system(size: 34, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.primary)

                        Text("The screen timeline uses this length for template playback.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)

                    Spacer()

                    HStack(spacing: 12) {
                        Button("Close") {
                            showingSheet = false
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )

                        Button("Clear Length") {
                            onCancel()
                            showingSheet = false
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.12))
                        )
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                } else {
                    VStack(spacing: 14) {
                        Text("Template Length")
                            .font(.headline)

                        HStack(spacing: 0) {
                            Picker("Hours", selection: $selectedHours) {
                                ForEach(0..<24, id: \.self) { hour in
                                    Text("\(hour) h").tag(hour)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(maxWidth: .infinity)

                            Picker("Minutes", selection: $selectedMinutes) {
                                ForEach(0..<60, id: \.self) { minute in
                                    Text("\(minute) m").tag(minute)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(maxWidth: .infinity)
                        }
                        .frame(height: 160)
                    }

                    Spacer()

                    HStack(spacing: 12) {
                        Button("Cancel") {
                            showingSheet = false
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )

                        Button("Set") {
                            onStart(selectedDuration)
                            showingSheet = false
                        }
                        .disabled(selectedDuration <= 0)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(selectedDuration > 0 ? Color.white.opacity(0.08) : Color.white.opacity(0.04))
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.white, lineWidth: 1)
                        }
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .background(Color.black.ignoresSafeArea())
            .preferredColorScheme(.dark)
        }
    }

    private var selectedDuration: TimeInterval {
        TimeInterval((selectedHours * 3600) + (selectedMinutes * 60))
    }

    @ViewBuilder
    private var buttonLabel: some View {
        if controller.totalDuration > 0 {
            Text(compactClock(controller.totalDuration))
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .monospacedDigit()
        } else {
            Image(systemName: "infinity")
                .font(.system(size: 17, weight: .semibold))
        }
    }

    private func compactClock(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded(.down)))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    // Accent-tinted while a length is running, neutral material otherwise.
    private var timerBackground: AnyShapeStyle {
        controller.isActive
            ? AnyShapeStyle(Color.accentColor.opacity(0.25))
            : AnyShapeStyle(.thickMaterial)
    }

    private var timerForeground: Color {
        if controller.isActive { return .accentColor }
        return (isDeviceOn || controller.isActive) ? .primary : .secondary
    }
}
