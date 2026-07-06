//
//  ScentsTemplate.swift
//  MeshGradient
//
//  Created by Dajun Xian on 9/26/25.
//

import Foundation

/// Template references pods by scent names so templates can be shared across devices.
public struct ScentsTemplate: Identifiable, Codable, Hashable {
    public let id: UUID
    public var name: String
    public var scentPodNames: [String]   // ordered
    public var duration: TimeInterval?

    public init(
        id: UUID = .init(),
        name: String,
        scentPodNames: [String],
        duration: TimeInterval? = nil
    ) {
        self.id = id
        self.name = name
        self.scentPodNames = scentPodNames
        self.duration = duration
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case scentPodNames
        case scentPodIDs
        case duration
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        scentPodNames = try container.decodeIfPresent([String].self, forKey: .scentPodNames) ?? []
        duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(scentPodNames, forKey: .scentPodNames)
        try container.encodeIfPresent(duration, forKey: .duration)
    }
}

extension ScentsTemplate {
    func matchingPods(in device: Device) -> [ScentPod] {
        let podsByName = Dictionary(
            grouping: device.insertedPods,
            by: { Self.normalizedPodName($0.name) }
        )

        return scentPodNames.compactMap { name in
            podsByName[Self.normalizedPodName(name)]?.first
        }
    }

    static func normalizedPodName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    }
}
