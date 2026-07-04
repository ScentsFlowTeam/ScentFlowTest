import SwiftUI

struct RetroPlayerDisplay: View {
    enum DisplayState: Equatable {
        case deviceOff
        case playing(title: String, position: Int?, total: Int)
        case podChange(message: String)

        var statusText: String {
            switch self {
            case .deviceOff:
                return "Device Off"
            case .playing:
                return "Device On"
            case .podChange:
                return ""
            }
        }

        var detailText: String {
            switch self {
            case .deviceOff:
                return "Standby"
            case .playing(let title, _, _):
                return title
            case .podChange(let message):
                return message
            }
        }

        var counterText: String? {
            switch self {
            case .deviceOff:
                return nil
            case .playing(_, let position, let total):
                guard let position, total > 0 else { return nil }
                return "\(position)/\(total)"
            case .podChange:
                return nil
            }
        }
    }

    let state: DisplayState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch state {
            case .podChange(let message):
                Text(message)
                    .font(.system(.title3, design: .monospaced).weight(.semibold))
                    .foregroundStyle(primaryDisplayColor)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)

            case .deviceOff, .playing:
                ZStack(alignment: .trailing) {
                    Text(state.detailText)
                        .font(.system(.title3, design: .monospaced).weight(.semibold))
                        .foregroundStyle(primaryDisplayColor)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)

                    if let counterText = state.counterText {
                        Text(counterText)
                            .font(.system(.caption, design: .monospaced).weight(.semibold))
                            .foregroundStyle(primaryDisplayColor.opacity(0.9))
                            .lineLimit(1)
                    }
                }
//
//              displayMeter
            }
        }
        .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .center)
        .background {
            if #available(iOS 26.0, *) {
                ConcentricRectangle(corners: .concentric(minimum: 16), isUniform: true)
                    .fill(Color.black.opacity(0.8))
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.8))
            }
        }
    }

    private var primaryDisplayColor: Color {
        switch state {
        case .deviceOff:
            return .white.opacity(0.58)
        case .playing, .podChange:
            return .white.opacity(0.8)
        }
    }
//
//    private var displayMeter: some View {
//        HStack(spacing: 4) {
//            ForEach(0..<18, id: \.self) { index in
//                Capsule()
//                    .fill(meterColor(for: index))
//                    .frame(width: 3.5, height: meterHeight(for: index))
//            }
//
//            Spacer(minLength: 0)
//        }
//        .frame(height: 14, alignment: .bottom)
//        .opacity(state == .deviceOff ? 0.35 : 1.0)
//    }
//
//    private func meterColor(for index: Int) -> Color {
//        switch state {
//        case .deviceOff:
//            return .white.opacity(0.22)
//        case .playing:
//            return index.isMultiple(of: 5) ? .white : .white.opacity(0.78)
//        }
//    }
//
//    private func meterHeight(for index: Int) -> CGFloat {
//        let pattern: [CGFloat] = [4, 7, 11, 6, 13, 8]
//        return pattern[index % pattern.count]
//    }
}
