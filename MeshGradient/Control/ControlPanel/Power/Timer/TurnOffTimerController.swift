//
//  TurnOffTimerController.swift
//  MeshGradient
//
//  Created by Dajun Xian on 3/19/26.
//


import Foundation
import Combine

@MainActor
final class TurnOffTimerController: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var totalDuration: TimeInterval = 0
    @Published private(set) var remainingDuration: TimeInterval = 0

    private var countdownTask: Task<Void, Never>?

    deinit {
        countdownTask?.cancel()
    }

    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return min(1, max(0, 1 - (remainingDuration / totalDuration)))
    }

    var remainingText: String {
        let totalSeconds = max(0, Int(remainingDuration.rounded(.up)))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    func start(duration: TimeInterval, onElapsed: @escaping @MainActor () -> Void) {
        clear()

        guard duration > 0 else { return }

        isActive = true
        totalDuration = duration
        remainingDuration = duration

        countdownTask = Task { [weak self] in
            guard let self else { return }

            let deadline = Date().addingTimeInterval(duration)

            while !Task.isCancelled {
                let remaining = max(0, deadline.timeIntervalSinceNow)

                await MainActor.run {
                    self.remainingDuration = remaining
                }

                if remaining <= 0 {
                    await MainActor.run {
                        self.clear()
                        onElapsed()
                    }
                    return
                }

                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }
    }

    func clear() {
        countdownTask?.cancel()
        countdownTask = nil
        isActive = false
        totalDuration = 0
        remainingDuration = 0
    }
}
