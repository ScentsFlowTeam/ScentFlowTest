import SwiftUI

struct RetroPlayerDisplay: View {
    enum DisplayState: Equatable {
        case deviceOff
        case playing(title: String, bodyText: String, position: Int?, total: Int)

        var headerTitle: String {
            switch self {
            case .deviceOff:
                return "Device Off"
            case .playing(let title, _, _, _):
                return title
            }
        }

        var bodyText: String {
            switch self {
            case .deviceOff:
                return "Device Off"
            case .playing(_, let bodyText, _, _):
                return bodyText
            }
        }

        var counterText: String? {
            switch self {
            case .deviceOff:
                return nil
            case .playing(_, _, let position, let total):
                guard let position, total > 0 else { return nil }
                return "\(position)/\(total)"
            }
        }
    }

    let state: DisplayState
    @ObservedObject var turnOffTimer: TurnOffTimerController

    private enum UI {
        static let separatorHeight: CGFloat = 1
        static let timerDotSize: CGFloat = 6
        static let displayHeight: CGFloat = 96
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .frame(height: 18)

            separator

            mainContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            timelineSeparator

            footer
                .frame(height: 14)
        }
        .frame(maxWidth: .infinity, minHeight: UI.displayHeight, maxHeight: UI.displayHeight, alignment: .center)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            if #available(iOS 26.0, *) {
                ConcentricRectangle(corners: .concentric(minimum: 16), isUniform: true)
                    .fill(Color.black.opacity(0.85))
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.85))
            }
        }
    }

    private var header: some View {
        ZStack(alignment: .trailing) {
            Text(state.headerTitle)
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .foregroundStyle(headerColor)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 44)

            if let counterText = state.counterText {
                Text(counterText)
                    .font(.system(.caption2, design: .monospaced).weight(.semibold))
                    .foregroundStyle(headerColor.opacity(0.9))
                    .lineLimit(1)
                    .monospacedDigit()
            }
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(height: UI.separatorHeight)
    }

    private var timelineSeparator: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                separator

                if turnOffTimer.isActive {
                    Circle()
                        .fill(primaryDisplayColor)
                        .frame(width: UI.timerDotSize, height: UI.timerDotSize)
                        .offset(x: timerDotOffset(width: proxy.size.width))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(height: UI.timerDotSize)
    }

    private var mainContent: some View {
        Text(state.bodyText)
            .font(.system(.callout, design: .monospaced).weight(.semibold))
            .foregroundStyle(primaryDisplayColor)
            .lineLimit(1)
            .minimumScaleFactor(0.62)
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
            .opacity(bodyTextOpacity)
            .padding(.horizontal, 2)
    }

    private var footer: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)

            if turnOffTimer.isActive {
                Text(turnOffTimer.remainingText)
                    .font(.system(.footnote, design: .monospaced).weight(.semibold))
                    .foregroundStyle(headerColor.opacity(0.95))
                    .lineLimit(1)
                    .monospacedDigit()
            }
        }
    }

    private func timerDotOffset(width: CGFloat) -> CGFloat {
        let travel = max(0, width - UI.timerDotSize)
        return travel * min(1, max(0, turnOffTimer.progress))
    }

    private var headerColor: Color {
        switch state {
        case .deviceOff:
            return .white.opacity(0.42)
        case .playing:
            return .white.opacity(0.58)
        }
    }

    private var primaryDisplayColor: Color {
        switch state {
        case .deviceOff:
            return .white.opacity(0.58)
        case .playing:
            return .white.opacity(0.82)
        }
    }

    private var bodyTextOpacity: Double {
        switch state {
        case .deviceOff:
            return 1.0
        case .playing(_, let bodyText, _, _) where bodyText == "No active pods":
            return 0.72
        case .playing:
            return 1.0
        }
    }
}
