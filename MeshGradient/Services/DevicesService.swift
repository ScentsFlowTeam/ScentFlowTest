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
    /// Per-device running state (which pods active, power, template, length…).
    /// The single source of truth that the wheel and control panel render from.
    @Published private(set) var runtimes: [UUID: DeviceRuntimeState] = [:]

    private let local: DevicesRepository
    // Optional future dependencies
    var remote: RemoteAPI?

    init(local: DevicesRepository) {
        self.local = local
    }

    /// Loads devices + selection + runtime state from local storage into memory.
    func load() async {
        let loaded = await local.loadAll()
        devices = loaded.devices
        runtimes = loaded.runtimes

        if let currentID = selectedID,
           devices.contains(where: { $0.id == currentID }) {
            selectedID = currentID
        } else {
            selectedID = loaded.selectedID ?? devices.first?.id
        }

        if devices.isEmpty {
            seedMockIfNeeded()
            persist()
        }
    }

    /// The persisted running state for a device, if any.
    func runtime(for id: UUID) -> DeviceRuntimeState? {
        runtimes[id]
    }

    /// Stores the running state for a device and persists.
    func setRuntime(_ state: DeviceRuntimeState, for id: UUID) {
        runtimes[id] = state
        persist()
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
        runtimes[id] = nil
        if selectedID == id { selectedID = devices.first?.id }
        persist()
    }

    /// Writes devices + selection + runtime state to local storage.
    private func persist() {
        let snapshotDevices = devices
        let snapshotSelected = selectedID
        let snapshotRuntimes = runtimes
        Task.detached(priority: .utility) {
            await self.local.saveAll(
                devices: snapshotDevices,
                selectedID: snapshotSelected,
                runtimes: snapshotRuntimes
            )
        }
    }

    /// Seeds two mock devices for first launch.
    private func seedMockIfNeeded() {
        guard devices.isEmpty else { return }

        let livingRoomPods: [ScentPod] = [
            ScentPod(name: "Pepper",     color: .red,    level: .normal),
            ScentPod(name: "Orange",     color: .orange, level: .low),
            ScentPod(name: "Lemon",      color: .yellow, level: .normal),
            ScentPod(name: "Mint",       color: .green,  level: .empty),
            ScentPod(name: "Ocean",      color: .cyan,   level: .normal),
            ScentPod(name: "Bluebell",   color: .blue,   level: .low),
            ScentPod(name: "Sandalwood", color: .purple, level: .normal),
        ]

        let bedroomPods: [ScentPod] = [
            ScentPod(name: "Pepper",     color: .red,    level: .low),
            ScentPod(name: "Orange",     color: .orange, level: .normal),
            ScentPod(name: "Lemon",      color: .yellow, level: .low),
            ScentPod(name: "Mint",       color: .green,  level: .normal),
            ScentPod(name: "Ocean",      color: .cyan,   level: .empty),
            ScentPod(name: "Bluebell",   color: .blue,   level: .normal),
            ScentPod(name: "Sandalwood", color: .purple, level: .low),
        ]

        let a = Device(name: "Living Room", insertedPods: livingRoomPods, isMock: true)
        let b = Device(name: "Bedroom", insertedPods: bedroomPods, isMock: true)

        devices = [a, b]
        selectedID = a.id
    }
}
