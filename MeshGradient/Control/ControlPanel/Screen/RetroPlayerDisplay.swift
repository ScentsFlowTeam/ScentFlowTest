import SwiftUI

struct RetroPlayerDisplay: View {
    struct PodBodyItem: Equatable, Identifiable {
        let id: UUID
        let name: String
        let percentText: String
    }

    enum BodyContent: Equatable {
        case text(String)
        case expandedText(String)
        case pods([PodBodyItem])
    }

    enum DisplayState: Equatable {
        case deviceOff(title: String)
        case playing(title: String, modeText: String?, body: BodyContent, position: Int?, total: Int)

        var headerTitle: String {
            switch self {
            case .deviceOff(let title):
                return title
            case .playing(let title, _, _, _, _):
                return title
            }
        }

        var modeText: String? {
            switch self {
            case .deviceOff:
                return nil
            case .playing(_, let modeText, _, _, _):
                return modeText
            }
        }

        var body: BodyContent {
            switch self {
            case .deviceOff:
                return .text("Device Off")
            case .playing(_, _, let body, _, _):
                return body
            }
        }

        var counterText: String? {
            switch self {
            case .deviceOff:
                return nil
            case .playing(_, _, _, let position, let total):
                guard let position, total > 0 else { return nil }
                return "\(position)/\(total)"
            }
        }
    }

    let state: DisplayState
    @ObservedObject var templateLength: TemplateLengthController

    private enum UI {
        static let separatorHeight: CGFloat = 1
        static let timerDotSize: CGFloat = 6
        static let compactDisplayHeight: CGFloat = 96
        static let expandedDisplayHeight: CGFloat = 116
        static let podRowCount = 3
        static let maxPodCount = 6
        static let podRowHeight: CGFloat = 16
        static let podPercentWidth: CGFloat = 38
    }

    private var displayHeight: CGFloat {
        switch state.body {
        case .text:
            return UI.compactDisplayHeight
        case .expandedText, .pods:
            return UI.expandedDisplayHeight
        }
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
                .frame(height: 18)
        }
        .frame(maxWidth: .infinity, minHeight: displayHeight, maxHeight: displayHeight, alignment: .center)
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
        ZStack {
            HStack(spacing: 8) {
                if let modeText = state.modeText {
                    Text(modeText)
                        .font(.system(.caption2, design: .monospaced).weight(.semibold))
                        .foregroundStyle(headerColor.opacity(0.85))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if let counterText = state.counterText {
                    Text(counterText)
                        .font(.system(.caption2, design: .monospaced).weight(.semibold))
                        .foregroundStyle(headerColor.opacity(0.9))
                        .lineLimit(1)
                        .monospacedDigit()
                }
            }

            if !state.headerTitle.isEmpty {
                Text(state.headerTitle)
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .foregroundStyle(headerColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 58)
            }
        }
        .frame(maxWidth: .infinity)
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

                if templateLength.totalDuration > 0 {
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

    @ViewBuilder
    private var mainContent: some View {
        switch state.body {
        case .text(let text), .expandedText(let text):
            Text(text)
                .font(.system(.callout, design: .monospaced).weight(.semibold))
                .foregroundStyle(primaryDisplayColor)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .opacity(bodyTextOpacity)
                .padding(.horizontal, 2)
        case .pods(let items):
            podGrid(items)
        }
    }

    private func podGrid(_ items: [PodBodyItem]) -> some View {
        VStack(spacing: 2) {
            ForEach(0..<UI.podRowCount, id: \.self) { rowIndex in
                HStack(spacing: 8) {
                    podCell(podItem(in: items, at: rowIndex * 2))

                    Text("||")
                        .font(.system(.caption2, design: .monospaced).weight(.semibold))
                        .foregroundStyle(headerColor.opacity(0.72))
                        .frame(width: 18)

                    podCell(podItem(in: items, at: rowIndex * 2 + 1))
                }
                .frame(height: UI.podRowHeight)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 2)
    }

    private func podCell(_ item: PodBodyItem?) -> some View {
        HStack(spacing: 5) {
            Text(item?.name ?? "")
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("|")
                .foregroundStyle(headerColor.opacity(0.65))

            Text(item?.percentText ?? "")
                .lineLimit(1)
                .monospacedDigit()
                .frame(width: UI.podPercentWidth, alignment: .trailing)
        }
        .font(.system(.caption, design: .monospaced).weight(.semibold))
        .foregroundStyle(primaryDisplayColor)
        .opacity(item == nil ? 0 : 1)
        .frame(maxWidth: .infinity)
    }

    private func podItem(in items: [PodBodyItem], at index: Int) -> PodBodyItem? {
        guard index < min(items.count, UI.maxPodCount) else { return nil }
        return items[index]
    }

    private var footer: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)

            playbackFooterText
        }
    }

    private var playbackFooterText: some View {
        HStack(alignment: .center, spacing: 0) {
            Text(PlaybackTimeFormat.clock(templateLength.elapsedDuration))
                .font(.system(.footnote, design: .monospaced).weight(.semibold))
                .monospacedDigit()

            Text("/")
                .font(.system(.footnote, design: .monospaced).weight(.semibold))

            if templateLength.totalDuration > 0 {
                Text(PlaybackTimeFormat.clock(templateLength.totalDuration))
                    .font(.system(.footnote, design: .monospaced).weight(.semibold))
                    .monospacedDigit()
            } else {
                Image(systemName: "infinity")
                    .font(.system(size: 14, weight: .bold))
            }
        }
        .foregroundStyle(headerColor.opacity(0.95))
        .lineLimit(1)
    }

    private func timerDotOffset(width: CGFloat) -> CGFloat {
        let travel = max(0, width - UI.timerDotSize)
        return travel * min(1, max(0, templateLength.progress))
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
        switch state.body {
        case .text("No active pods"):
            return 0.72
        case .text, .expandedText, .pods:
            return 1.0
        }
    }
}
