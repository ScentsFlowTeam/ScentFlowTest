import SwiftUI

struct PodIntensitySlider: View {
    @Binding var value: Double          // 0...1
    let color: Color
    var isDimmed: Bool = false
    var isEnabled: Bool = true

    private let trackHeight: CGFloat = 8
    private let thumbSize: CGFloat = 18
    private let activeThumbSize: CGFloat = 22

    @GestureState private var isDragging = false

    private var clampedValue: Double {
        min(1, max(0, value))
    }

    private var effectiveThumbSize: CGFloat {
        isDragging ? activeThumbSize : thumbSize
    }

    private var effectiveColor: Color {
        isDimmed ? .secondary.opacity(0.4) : color
    }

    var body: some View {
        GeometryReader { geo in
            let width = max(1, geo.size.width)
            let travel = max(0, width - effectiveThumbSize)
            let thumbX = CGFloat(clampedValue) * travel

            ZStack(alignment: .leading) {
                trackBackground
                trackFill(width: width)

                thumb
                    .offset(x: thumbX)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .gesture(dragGesture(width: width))
            .opacity(isEnabled ? 1.0 : 0.5)
            .animation(.spring(response: 0.22, dampingFraction: 0.82), value: isDragging)
            .animation(.easeInOut(duration: 0.12), value: clampedValue)
        }
        .frame(height: activeThumbSize)
    }

    private var trackBackground: some View {
        Capsule()
            .fill(Color.secondary.opacity(isDimmed ? 0.14 : 0.2))
            .frame(height: trackHeight)
    }

    private func trackFill(width: CGFloat) -> some View {
        let fillWidth = max(effectiveThumbSize * 0.55, CGFloat(clampedValue) * width)

        return Capsule()
            .fill(effectiveColor.opacity(isDimmed ? 0.5 : 1.0))
            .frame(width: fillWidth, height: trackHeight)
    }

    @ViewBuilder
    private var thumb: some View {
        if isDragging {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay {
                    Circle()
                        .fill(effectiveColor.opacity(0.18))
                }
                .frame(width: effectiveThumbSize, height: effectiveThumbSize)
                .scaleEffect(1.03)
        } else {
            Circle()
                .fill(effectiveColor.opacity(isDimmed ? 0.75 : 1.0))
                .frame(width: effectiveThumbSize, height: effectiveThumbSize)
        }
    }

    private func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($isDragging) { _, state, _ in
                state = true
            }
            .onChanged { gesture in
                guard isEnabled else { return }
                let x = min(max(0, gesture.location.x), width)
                value = x / width
            }
    }
}
