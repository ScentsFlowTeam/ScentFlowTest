import SwiftUI

/// A snapshot of a device's current playback, derived from its saved settings
/// blob so the device list can mirror the control screen's title/timeline.
struct DevicePlayback {
    var title: String
    var startDate: Date?
    var duration: TimeInterval?   // nil or <= 0 means no timed length (∞)
    var previewColors: [Color]

    var hasTimeline: Bool { (duration ?? 0) > 0 }

    static func make(runtime: DeviceRuntimeState?, templates: [ScentsTemplate], device: Device) -> DevicePlayback? {
        guard let runtime else { return nil }

        let templateID = runtime.currentTemplateID ?? runtime.sourceTemplateID
        let template = templateID.flatMap { id in templates.first(where: { $0.id == id }) }

        return DevicePlayback(
            title: template?.name ?? "New Template",
            startDate: runtime.templateLengthStartDate,
            duration: runtime.templateLengthDuration,
            previewColors: template?.previewPalette(in: device) ?? []
        )
    }
}

struct DeviceCard: View {
    let device: Device
    let status: DeviceRunStatus
    let playback: DevicePlayback?

    private var statusTint: Color {
        switch status {
        case .running: return .green
        case .idle: return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            deviceThumbnail
                
//                .background(.red)

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

                if let playback {
                    playbackSection(playback)
                }
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
        .accessibilityLabel("\(device.name), \(status.title)\(playback.map { ", \($0.title)" } ?? "")")
    }

    private var deviceThumbnail: some View {
        ZStack {
            if status == .running, let playback, !playback.previewColors.isEmpty {
                GradientContainerCircle(
                    colors: playback.previewColors,
                    animate: true,
                    isTemplate: true
                )
                .frame(width: 36, height: 36)
//                    .shadow(color: .white, radius: 5)
            }

            Image("device_black")
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: 100, height: 100)
        }
        .frame(width: 100, height: 100)
    }

    // MARK: - Playback (title + progress timeline, mirroring the control screen)

    @ViewBuilder
    private func playbackSection(_ playback: DevicePlayback) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(playback.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            if playback.hasTimeline, let duration = playback.duration {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    let elapsed = min(max(0, Date().timeIntervalSince(playback.startDate ?? Date())), duration)
                    let progress = duration > 0 ? elapsed / duration : 0

                    VStack(alignment: .leading, spacing: 4) {
                        progressTrack(progress: progress)

                        Text("\(Self.clockText(elapsed))/\(Self.clockText(duration))")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func progressTrack(progress: Double) -> some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let dotSize: CGFloat = 6
            let travel = max(0, width - dotSize)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.15))
                    .frame(height: 2)

                Capsule()
                    .fill(Color.primary.opacity(0.55))
                    .frame(width: max(0, travel * progress) + dotSize, height: 2)

                Circle()
                    .fill(Color.primary)
                    .frame(width: dotSize, height: dotSize)
                    .offset(x: travel * min(1, max(0, progress)))
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .frame(height: 6)
    }

    private static func clockText(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded(.down)))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}
