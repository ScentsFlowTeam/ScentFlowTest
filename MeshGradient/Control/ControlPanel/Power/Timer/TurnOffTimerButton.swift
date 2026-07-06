import SwiftUI

struct TurnOffTimerButton: View {
    let isDeviceOn: Bool
    @ObservedObject var controller: TurnOffTimerController
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
            ZStack {
                Circle()
                    .fill(.thickMaterial)

                if controller.isActive {
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 2)

                    Circle()
                        .trim(from: 0, to: remainingRingFraction)
                        .stroke(
                            Color.white.opacity(0.6),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    Image(systemName: "timer")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                } else {
                    Image(systemName: "timer")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isDeviceOn ? .primary : .secondary)
                }
            }
            .frame(width: 44, height: 44)
            .opacity((isDeviceOn || controller.isActive) ? 1.0 : 0.45)
        }
        .buttonStyle(.plain)
        .disabled(!isDeviceOn && !controller.isActive)
        .sheet(isPresented: $showingSheet) {
            timerSheet
                .presentationDetents([.height(controller.isActive ? 280 : 360)])
                .presentationDragIndicator(.visible)
        }
    }

    private var remainingRingFraction: Double {
        guard controller.totalDuration > 0 else { return 0 }
        return max(0, min(1, controller.remainingDuration / controller.totalDuration))
    }

    private var timerSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if controller.isActive {
                    VStack(spacing: 10) {
                        Text("Scheduled Turn Off")
                            .font(.headline)

                        Text(controller.remainingText)
                            .font(.system(size: 34, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.primary)

                        Text("The device will turn off automatically when the countdown ends.")
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

                        Button("Cancel Timer") {
                            onCancel()
                            showingSheet = false
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.accentColor)
                        )
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                } else {
                    VStack(spacing: 14) {
                        Text("Scheduled Turn Off")
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

                        Button("Start") {
                            onStart(selectedDuration)
                            showingSheet = false
                        }
                        .disabled(selectedDuration <= 0)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(selectedDuration > 0 ? Color.accentColor : Color.gray.opacity(0.45))
                        )
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
}
