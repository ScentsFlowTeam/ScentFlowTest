//
//  TemplateLengthController.swift
//  MeshGradient
//
//  Created by Dajun Xian on 3/19/26.
//

import Foundation
import Combine
import SwiftUI

/// Shared formatting for the playback clock so every page renders it identically.
enum PlaybackTimeFormat {
    static func clock(_ duration: TimeInterval) -> String {
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

    /// "mm:ss/mm:ss" when timed, or "mm:ss/∞" (bold ∞) when there's no timer.
    static func text(elapsed: TimeInterval, duration: TimeInterval?) -> Text {
        let elapsedText = Text(clock(elapsed))
        if let duration, duration > 0 {
            return elapsedText + Text("/\(clock(duration))")
        } else {
            return elapsedText + Text("/") + Text("∞").fontWeight(.bold)
        }
    }
}

@MainActor
final class TemplateLengthController: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var totalDuration: TimeInterval = 0
    @Published private(set) var elapsedDuration: TimeInterval = 0

    private var playbackTask: Task<Void, Never>?
    private var bag = Set<AnyCancellable>()

    /// Called when the countdown reaches its end (not called for ∞ / no length).
    var onFinished: (@MainActor () -> Void)?

    deinit {
        playbackTask?.cancel()
    }

    /// Binds this controller to a wheel VM so the live clock is always a pure
    /// projection of the VM's persisted length + power state (the single source
    /// of truth). Callers never poke the clock directly — they mutate the VM and
    /// the clock follows. Safe to call repeatedly (re-subscribes idempotently).
    func bind(to runtime: DeviceRuntime) {
        bag.removeAll()

        Publishers.CombineLatest3(
            runtime.$isPowerOn,
            runtime.$templateLengthDuration,
            runtime.$templateLengthStartDate
        )
        .sink { [weak self] isOn, duration, startDate in
            guard let self else { return }
            // Powered off → idle clock. Powered on → run/resume from the stored
            // start date (∞ counts up when there's no duration).
            self.setLength(isOn ? duration : nil,
                           startedAt: isOn ? (startDate ?? Date()) : nil)
        }
        .store(in: &bag)
    }

    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return min(1, max(0, elapsedDuration / totalDuration))
    }

    var playbackText: String {
        "\(PlaybackTimeFormat.clock(elapsedDuration))/\(durationText)"
    }

    var durationText: String {
        guard totalDuration > 0 else { return "∞" }
        return PlaybackTimeFormat.clock(totalDuration)
    }

    /// Drives the playback clock:
    /// - `startedAt == nil` stops the clock (idle / powered off).
    /// - `duration == nil` (with a start date) counts up indefinitely (∞).
    /// - `duration > 0` runs a bounded countdown that fires `onFinished`.
    /// A past `startedAt` resumes at the correct position, like a music player.
    private func setLength(_ duration: TimeInterval?, startedAt: Date?) {
        playbackTask?.cancel()
        playbackTask = nil

        totalDuration = max(0, duration ?? 0)
        isActive = totalDuration > 0   // a real timer is set

        guard let startedAt else {
            elapsedDuration = 0
            return
        }

        // Seed synchronously so restored/opened views render immediately.
        elapsedDuration = clampedElapsed(since: startedAt)

        playbackTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                let elapsed = max(0, Date().timeIntervalSince(startedAt))

                await MainActor.run {
                    self.elapsedDuration = self.totalDuration > 0 ? min(elapsed, self.totalDuration) : elapsed
                }

                if self.totalDuration > 0, elapsed >= self.totalDuration {
                    await MainActor.run { self.onFinished?() }
                    return
                }

                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }
    }

    private func clampedElapsed(since startedAt: Date) -> TimeInterval {
        let elapsed = max(0, Date().timeIntervalSince(startedAt))
        return totalDuration > 0 ? min(elapsed, totalDuration) : elapsed
    }

    func clear() {
        setLength(nil, startedAt: nil)
    }
}
