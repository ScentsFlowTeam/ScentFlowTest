import SwiftUI

struct DeviceCard: View {
    let device: Device
    let status: DeviceRunStatus

    private var statusTint: Color {
        switch status {
        case .running: return .green
        case .idle: return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            Image("device")
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: 100, height: 100)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(device.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if device.isMock {
                        Text("Mock")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .frame(height: 20)
                            .background(Color.white.opacity(0.08), in: Capsule())
                    }
                }

                HStack(spacing: 8) {
                    Circle()
                        .fill(statusTint)
                        .frame(width: 8, height: 8)
                        .shadow(color: statusTint.opacity(status == .running ? 0.8 : 0), radius: 5)

                    Text(status.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(statusTint)
                }

                Text("\(device.insertedPods.count) pods available")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveGlassBackground(RoundedRectangle(cornerRadius: 20, style: .continuous))
//        .overlay {
//            RoundedRectangle(cornerRadius: 20, style: .continuous)
//                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
//        }
//        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(device.name), \(status.title), \(device.insertedPods.count) pods")
    }
}
