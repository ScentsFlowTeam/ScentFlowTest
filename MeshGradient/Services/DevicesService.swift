//
//  DevicesService.swift
//  MeshGradient
//
//  Created by Dajun Xian on 10/10/25.
//
//  Owns devices in memory, selection, and simple actions.
//

import SwiftUI
import Foundation
import Combine

@MainActor
final class DevicesService: ObservableObject {
    @Published private(set) var devices: [Device] = []
    @Published var selectedID: UUID?

    private let local: DevicesRepository
    // Optional future dependencies
    var remote: RemoteAPI?

    init(local: DevicesRepository) {
        self.local = local
    }

    /// Loads devices + selection from local storage into memory.
    func load() async {
        let loaded = await local.loadAll()
        devices = loaded.devices
        selectedID = loaded.selectedID ?? devices.first?.id

        if devices.isEmpty {
            seedMockIfNeeded()
            persist()
        }
    }

    /// The currently selected device, if any.
    var selected: Device? {
        guard let id = selectedID else { return nil }
        return devices.first(where: { $0.id == id })
    }

    /// Selects a device by ID and persists selection.
    func select(_ id: UUID) {
        guard devices.contains(where: { $0.id == id }) else { return }
        selectedID = id
        persist()
    }

    /// Inserts or updates a device and persists.
    func upsert(_ d: Device) {
        if let i = devices.firstIndex(where: { $0.id == d.id }) { devices[i] = d }
        else { devices.append(d) }
        if selectedID == nil { selectedID = d.id }
        persist()
    }

    /// Removes a device and keeps selection sensible.
    func remove(_ id: UUID) {
        devices.removeAll { $0.id == id }
        if selectedID == id { selectedID = devices.first?.id }
        persist()
    }

    /// Saves an opaque settings snapshot on the selected device.
    func saveSettingsBlobForSelected(_ data: Data) {
        guard let id = selectedID, let i = devices.firstIndex(where: { $0.id == id }) else { return }
        var updated = devices
        updated[i].savedSettingsBlob = data
        devices = updated
        persist()
    }

    /// Writes devices + selection to local storage.
    private func persist() {
        let snapshotDevices = devices
        let snapshotSelected = selectedID
        Task.detached(priority: .utility) {
            await self.local.saveAll(devices: snapshotDevices, selectedID: snapshotSelected)
        }
    }

    /// Seeds two mock devices for first launch.
    private func seedMockIfNeeded() {
        guard devices.isEmpty else { return }

        let pods: [ScentPod] = [
            ScentPod(name: "Pepper",     color: .red,    level: .normal),
            ScentPod(name: "Orange",     color: .orange, level: .low),
            ScentPod(name: "Lemon",      color: .yellow, level: .normal),
            ScentPod(name: "Mint",       color: .green,  level: .empty),
            ScentPod(name: "Ocean",      color: .cyan,   level: .normal),
            ScentPod(name: "Bluebell",   color: .blue,   level: .low),
            ScentPod(name: "Sandalwood", color: .purple, level: .normal),
        ]

        let a = Device(name: "Living Room", insertedPods: pods, isMock: true)
        let b = Device(name: "Bedroom", insertedPods: pods, isMock: true)

        devices = [a, b]
        selectedID = a.id
    }
}
