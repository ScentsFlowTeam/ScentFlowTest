import SwiftUI

struct RetroPlayerDisplay: View {
    enum DisplayState: Equatable {
        case deviceOff
        case playing(title: String, position: Int?, total: Int)

        var statusText: String {
            switch self {
            case .deviceOff:
                return "Device Off"
            case .playing:
                return "Device On"
            }
        }

        var detailText: String {
            switch self {
            case .deviceOff:
                return "Standby"
            case .playing(let title, _, _):
                return "Now Playing - \(title)"
            }
        }

        var counterText: String? {
            switch self {
            case .deviceOff:
                return nil
            case .playing(_, let position, let total):
                guard let position, total > 0 else { return nil }
                return "\(position)/\(total)"
            }
        }
    }

    let state: DisplayState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(state.statusText)
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(primaryDisplayColor)

                Spacer(minLength: 12)

                if let counterText = state.counterText {
                    Text(counterText)
                        .font(.system(.caption, design: .monospaced).weight(.semibold))
                        .foregroundStyle(primaryDisplayColor.opacity(0.9))
                }
            }

            Text(state.detailText)
                .font(.system(.subheadline, design: .monospaced).weight(.medium))
                .foregroundStyle(primaryDisplayColor)
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            displayMeter
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .controlConcentricFilledBackground(.black)
    }

    private var primaryDisplayColor: Color {
        switch state {
        case .deviceOff:
            return .white.opacity(0.58)
        case .playing:
            return .white
        }
    }

    private var displayMeter: some View {
        HStack(spacing: 4) {
            ForEach(0..<18, id: \.self) { index in
                Capsule()
                    .fill(meterColor(for: index))
                    .frame(width: 3.5, height: meterHeight(for: index))
            }

            Spacer(minLength: 0)
        }
        .frame(height: 14, alignment: .bottom)
        .opacity(state == .deviceOff ? 0.35 : 1.0)
    }

    private func meterColor(for index: Int) -> Color {
        switch state {
        case .deviceOff:
            return .white.opacity(0.22)
        case .playing:
            return index.isMultiple(of: 5) ? .white : .white.opacity(0.78)
        }
    }

    private func meterHeight(for index: Int) -> CGFloat {
        let pattern: [CGFloat] = [4, 7, 11, 6, 13, 8]
        return pattern[index % pattern.count]
    }
}
