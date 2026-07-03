import Foundation

enum DeviceRunStatus: Equatable {
    case running
    case idle

    var title: String {
        switch self {
        case .running: return "Running"
        case .idle: return "Idle"
        }
    }

    static func status(for device: Device) -> DeviceRunStatus {
        guard let blob = device.savedSettingsBlob,
              let settings = try? JSONDecoder().decode(GradientWheelViewModel.WheelSettings.self, from: blob)
        else {
            return .idle
        }

        return settings.isPowerOn ? .running : .idle
    }
}
