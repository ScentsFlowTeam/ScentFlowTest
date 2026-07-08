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

    static func status(runtime: DeviceRuntimeState?) -> DeviceRunStatus {
        (runtime?.isPowerOn ?? false) ? .running : .idle
    }
}
