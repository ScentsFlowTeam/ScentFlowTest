//
//  LocalDevicesRepository.swift
//
//  Created by Dajun Xian on 10/10/25.
//

import Foundation

protocol DevicesRepository {
    func loadAll() async -> (devices: [Device], selectedID: UUID?, runtimes: [UUID: DeviceRuntimeState])
    func saveAll(devices: [Device], selectedID: UUID?, runtimes: [UUID: DeviceRuntimeState]) async
}

// LocalDevicesRepository.swift
struct LocalDevicesRepository: DevicesRepository {
    private let devicesKey = "devices_v3"
    private let selectedKey = "devices_selected_id_v3"
    private let runtimesKey = "devices_runtimes_v3"

    func loadAll() async -> (devices: [Device], selectedID: UUID?, runtimes: [UUID: DeviceRuntimeState]) {
        await Task.detached(priority: .utility) {
            let devices: [Device] = {
                guard let data = UserDefaults.standard.data(forKey: devicesKey) else { return [] }
                return (try? JSONDecoder().decode([Device].self, from: data)) ?? []
            }()
            let selectedID = UserDefaults.standard
                .string(forKey: selectedKey)
                .flatMap(UUID.init(uuidString:))
            let runtimes: [UUID: DeviceRuntimeState] = {
                guard let data = UserDefaults.standard.data(forKey: runtimesKey) else { return [:] }
                return (try? JSONDecoder().decode([UUID: DeviceRuntimeState].self, from: data)) ?? [:]
            }()
            return (devices, selectedID, runtimes)
        }.value
    }

    func saveAll(devices: [Device], selectedID: UUID?, runtimes: [UUID: DeviceRuntimeState]) async {
        await Task.detached(priority: .utility) {
            let enc = JSONEncoder()
            UserDefaults.standard.set(try? enc.encode(devices), forKey: devicesKey)
            UserDefaults.standard.set(selectedID?.uuidString, forKey: selectedKey)
            UserDefaults.standard.set(try? enc.encode(runtimes), forKey: runtimesKey)
        }.value
    }
}
