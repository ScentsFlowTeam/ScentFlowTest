import Foundation
import Combine

struct DeviceNotification: Identifiable, Equatable {
    enum Kind: Equatable {
        case podLow
        case podEmpty
        case remote(String)
    }

    enum Severity: Int, Equatable {
        case info
        case warning
        case critical
    }

    let id: String
    let kind: Kind
    let severity: Severity
    let deviceID: UUID?
    let podID: UUID?
    let title: String
    let message: String
    let createdAt: Date
}

@MainActor
final class DeviceNotificationsService: ObservableObject {
    @Published private(set) var notifications: [DeviceNotification] = []

    private var remoteNotifications: [DeviceNotification] = []

    var unreadCount: Int {
        notifications.count
    }

    func refresh(from devices: [Device]) {
        let podNotifications = makePodNotifications(from: devices)
        notifications = (podNotifications + remoteNotifications)
            .sorted { lhs, rhs in
                if lhs.severity.rawValue != rhs.severity.rawValue {
                    return lhs.severity.rawValue > rhs.severity.rawValue
                }
                return lhs.createdAt > rhs.createdAt
            }
    }

    func refreshRemoteNotifications() async {
        // Future network/push bridge: fetch remote notification records here,
        // then assign remoteNotifications and call refresh(from:) with current devices.
    }

    func applyRemoteNotifications(_ notifications: [DeviceNotification], devices: [Device]) {
        remoteNotifications = notifications
        refresh(from: devices)
    }

    private func makePodNotifications(from devices: [Device]) -> [DeviceNotification] {
        devices.flatMap { device in
            device.insertedPods.compactMap { pod in
                switch pod.level {
                case .normal:
                    return nil
                case .low:
                    return DeviceNotification(
                        id: "pod-low-\(device.id.uuidString)-\(pod.id.uuidString)",
                        kind: .podLow,
                        severity: .warning,
                        deviceID: device.id,
                        podID: pod.id,
                        title: "Pod running low",
                        message: "\(pod.name) in \(device.name) is low.",
                        createdAt: Date()
                    )
                case .empty:
                    return DeviceNotification(
                        id: "pod-empty-\(device.id.uuidString)-\(pod.id.uuidString)",
                        kind: .podEmpty,
                        severity: .critical,
                        deviceID: device.id,
                        podID: pod.id,
                        title: "Pod empty",
                        message: "\(pod.name) in \(device.name) is empty.",
                        createdAt: Date()
                    )
                }
            }
        }
    }
}
