// ScentPodsRow.swift

import SwiftUI

struct ScentPodsRow: View {
    let pods: [ScentPod]
    let includedIDs: Set<UUID>
    let focusedID: UUID?
    let canSelectMore: Bool
    let isPowerOn: Bool
    let onTap: (UUID) -> Void

    private let diameter: CGFloat = 28
    private let ringWidth: CGFloat = 3
    private let focusScale: CGFloat = 1.1

    @State private var animationStartTime: TimeInterval?

    private var shouldAnimateEmptyState: Bool {
        isPowerOn && includedIDs.isEmpty
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate

            GeometryReader { geo in
                let count = pods.count
                let totalChipWidth = CGFloat(count) * diameter
                let spacing = count > 1
                    ? (geo.size.width - totalChipWidth) / CGFloat(max(1, count - 1))
                    : 0

                HStack(spacing: spacing) {
                    ForEach(Array(pods.enumerated()), id: \.element.id) { index, pod in
                        chip(for: pod, index: index, time: t)
                            .frame(width: diameter, height: diameter)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
            }
            .frame(maxWidth: .infinity, minHeight: diameter, idealHeight: diameter)
            .padding(.vertical, 6)
            .accessibilityElement(children: .contain)
        }
        .onAppear {
            if shouldAnimateEmptyState {
                animationStartTime = Date.timeIntervalSinceReferenceDate
            }
        }
        .onChange(of: shouldAnimateEmptyState) { _, isActive in
            if isActive {
                animationStartTime = Date.timeIntervalSinceReferenceDate
            } else {
                animationStartTime = nil
            }
        }
    }

    @ViewBuilder
    private func chip(for pod: ScentPod, index: Int, time: TimeInterval) -> some View {
        let color = pod.color.color
        let isAdded = includedIDs.contains(pod.id)
        let isFocused = (focusedID == pod.id)

        // Easier tuning knobs
        let baseOpacity = 0.6
        let peakOpacity = 1.0
        let baseScale = 1.0
        let peakScale = 1.03

        let baseGlowOpacity = 0.0
        let peakGlowOpacity = 0.45
        let baseGlowBlur = 0.0
        let peakGlowBlur = 2.5
        let baseGlowRadius = 0.0
        let peakGlowRadius = 4.0

        // Timing
        let perPodDuration = 0.65
        let stagger = 0.18
        let restDuration = 1.6

        let podCount = max(1, pods.count)
        let cascadeDuration = Double(podCount - 1) * stagger + perPodDuration
        let totalDuration = cascadeDuration + restDuration

        let relativeTime = max(0, time - (animationStartTime ?? time))
        let timeInLoop = relativeTime.truncatingRemainder(dividingBy: totalDuration)
        let startTime = Double(index) * stagger
        let localTime = timeInLoop - startTime

        let wave: Double = {
            guard shouldAnimateEmptyState,
                  localTime >= 0,
                  localTime <= perPodDuration
            else { return 0 }

            let progress = localTime / perPodDuration
            return sin(progress * .pi)
        }()

        let animatedOpacity = baseOpacity + (peakOpacity - baseOpacity) * wave
        let animatedScale = baseScale + (peakScale - baseScale) * wave

        let glowOpacity = baseGlowOpacity + (peakGlowOpacity - baseGlowOpacity) * wave
        let glowBlur = baseGlowBlur + (peakGlowBlur - baseGlowBlur) * wave
        let glowRadius = baseGlowRadius + (peakGlowRadius - baseGlowRadius) * wave

        Button { onTap(pod.id) } label: {
            ZStack {
                if isAdded {
                    Circle()
                        .fill(color)
                        .overlay(
                            Circle()
                                .stroke(
                                    isFocused ? color.opacity(0.75) : color.opacity(0.25),
                                    lineWidth: isFocused ? 3 : 1
                                )
                        )
                } else {
                    ZStack {
                        if shouldAnimateEmptyState && glowOpacity > 0.001 {
                            Circle()
                                .stroke(color.opacity(glowOpacity), lineWidth: ringWidth + 1)
                                .scaleEffect(animatedScale)
                                .blur(radius: glowBlur)
                                .shadow(color: color.opacity(glowOpacity), radius: glowRadius)
                        }

                        Circle()
                            .stroke(
                                color.opacity(shouldAnimateEmptyState ? animatedOpacity : baseOpacity),
                                lineWidth: ringWidth
                            )
                            .scaleEffect(shouldAnimateEmptyState ? animatedScale : 1.0)

                        Circle()
                            .stroke(.white.opacity(0.12), lineWidth: 1)
                            .blendMode(.overlay)
                    }

                    if !canSelectMore {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }

                if isFocused {
                    Circle()
                        .fill(Color.white)
                        .frame(width: diameter * 0.25, height: diameter * 0.25)
                        .shadow(color: Color.white, radius: 1, x: 0, y: 0)
                }
            }
            .scaleEffect(isFocused ? focusScale : 1.0)
            .animation(.spring(response: 0.7, dampingFraction: 0.5), value: isFocused)
            .opacity(isAdded || canSelectMore ? 1 : 0.85)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(pod.name) \(isAdded ? "added" : "not added")"))
        .accessibilityHint(Text(isAdded ? "Tap to focus, tap again to remove" : "Tap to add"))
    }
}
