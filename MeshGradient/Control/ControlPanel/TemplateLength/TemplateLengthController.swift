//
//  TemplateLengthController.swift
//  MeshGradient
//
//  Created by Dajun Xian on 3/19/26.
//

import Foundation
import Combine

@MainActor
final class TemplateLengthController: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var totalDuration: TimeInterval = 0
    @Published private(set) var elapsedDuration: TimeInterval = 0

    private var playbackTask: Task<Void, Never>?

    /// Called when the countdown reaches its end (not called for ∞ / no length).
    var onFinished: (@MainActor () -> Void)?

    deinit {
        playbackTask?.cancel()
    }

    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return min(1, max(0, elapsedDuration / totalDuration))
    }

    var playbackText: String {
        "\(Self.clockText(elapsedDuration))/\(durationText)"
    }

    var durationText: String {
        guard totalDuration > 0 else { return "∞" }
        return Self.clockText(totalDuration)
    }

    var remainingText: String {
        playbackText
    }

    func start(duration: TimeInterval, onElapsed: @escaping @MainActor () -> Void = {}) {
        setLength(duration)
    }

    /// Sets the length and runs the countdown from `startedAt` (defaults to now).
    /// Passing a past `startedAt` resumes the timer at the correct elapsed
    /// position, so progress survives navigation like a music player.
    func setLength(_ duration: TimeInterval?, startedAt: Date = Date()) {
        playbackTask?.cancel()
        playbackTask = nil

        totalDuration = max(0, duration ?? 0)
        isActive = totalDuration > 0

        guard isActive else {
            elapsedDuration = 0
            return
        }

        // Seed the current elapsed synchronously so restored timers render at the
        // right position immediately.
        elapsedDuration = min(max(0, Date().timeIntervalSince(startedAt)), totalDuration)

        playbackTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                let elapsed = max(0, Date().timeIntervalSince(startedAt))

                await MainActor.run {
                    self.elapsedDuration = min(elapsed, self.totalDuration)
                }

                if elapsed >= totalDuration {
                    await MainActor.run { self.onFinished?() }
                    return
                }

                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }
    }

    func clear() {
        setLength(nil)
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
