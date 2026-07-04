import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct DeviceNotificationsButton: View {
    let notifications: [DeviceNotification]
    let devices: [Device]

    @State private var showingNotifications = false

    private var hasNotifications: Bool {
        !notifications.isEmpty
    }

    var body: some View {
        Button {
            showingNotifications = true
        } label: {
            Image(systemName: hasNotifications ? "bell.badge.fill" : "bell")
                .symbolRenderingMode(hasNotifications ? .multicolor : .monochrome)


        }
//        .buttonStyle(.glass)
        .accessibilityLabel("Notifications")
        .accessibilityValue(hasNotifications ? "\(notifications.count) notifications" : "No notifications")
        .sheet(isPresented: $showingNotifications) {
            DeviceNotificationsSheet(notifications: notifications, devices: devices)
        }
    }

}

private struct NotificationSection: Identifiable {
    let title: String
    let notifications: [DeviceNotification]

    var id: String { title }
}

private struct DeviceNotificationsSheet: View {
    let notifications: [DeviceNotification]
    let devices: [Device]

    @Environment(\.dismiss) private var dismiss

    private var sections: [NotificationSection] {
        let deviceNamesByID = Dictionary(uniqueKeysWithValues: devices.map { ($0.id, $0.name) })
        let grouped = Dictionary(grouping: notifications) { notification in
            notification.deviceID.flatMap { deviceNamesByID[$0] } ?? "Other"
        }

        return grouped
            .map { title, notifications in
                NotificationSection(title: title, notifications: notifications)
            }
            .sorted { lhs, rhs in
                if lhs.title == "Other" { return false }
                if rhs.title == "Other" { return true }
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
    }

    var body: some View {
        NavigationStack {
            Group {
                if notifications.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            ForEach(sections) { section in
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(section.title)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                        .padding(.horizontal, 2)

                                    VStack(spacing: 12) {
                                        ForEach(section.notifications) { notification in
                                            notificationRow(notification)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("No notifications")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func notificationRow(_ notification: DeviceNotification) -> some View {
        HStack(alignment: .center, spacing: 14) {
            notificationImage(for: notification)

            VStack(alignment: .leading, spacing: 5) {
                Text(notification.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(notification.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .adaptiveGlassBackground(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func podImageName(for notification: DeviceNotification) -> String {
        guard let pod = pod(for: notification) else { return "pod" }

        let imageName = "pods_\(podColorName(for: pod))"
        return existingImageName(imageName, fallback: "pod")
    }

    private func pod(for notification: DeviceNotification) -> ScentPod? {
        guard
            let deviceID = notification.deviceID,
            let podID = notification.podID,
            let device = devices.first(where: { $0.id == deviceID })
        else { return nil }

        return device.insertedPods.first { $0.id == podID }
    }

    private func podColorName(for pod: ScentPod) -> String {
        let color = pod.color
        let candidates: [(name: String, r: Double, g: Double, b: Double)] = [
            ("red", 1.0, 0.0, 0.0),
            ("orange", 1.0, 0.5, 0.0),
            ("yellow", 1.0, 1.0, 0.0),
            ("green", 0.0, 1.0, 0.0),
            ("cyan", 0.0, 1.0, 1.0),
            ("blue", 0.0, 0.0, 1.0),
            ("purple", 0.5, 0.0, 0.5),
        ]

        return candidates.min { lhs, rhs in
            colorDistance(color, lhs) < colorDistance(color, rhs)
        }?.name ?? ""
    }

    private func colorDistance(_ color: RGBAColor, _ candidate: (name: String, r: Double, g: Double, b: Double)) -> Double {
        let red = color.r - candidate.r
        let green = color.g - candidate.g
        let blue = color.b - candidate.b
        return red * red + green * green + blue * blue
    }

    private func existingImageName(_ imageName: String, fallback: String) -> String {
        #if canImport(UIKit)
        UIImage(named: imageName) == nil ? fallback : imageName
        #else
        imageName
        #endif
    }

    @ViewBuilder
    private func notificationImage(for notification: DeviceNotification) -> some View {
        switch notification.kind {
        case .podLow, .podEmpty:
            Image(podImageName(for: notification))
                .resizable()
                .renderingMode(.original)
                .scaledToFill()
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                }
        case .remote:
            Image(systemName: "bell.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 52, height: 52)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}
