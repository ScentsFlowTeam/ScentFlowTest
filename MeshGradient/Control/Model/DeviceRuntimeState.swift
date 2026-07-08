//
//  DeviceRuntimeState.swift
//  MeshGradient
//
//  The persisted "running status" of a single device: which pods are active,
//  their intensities, power/fan, the current/source template, and the template
//  length. This is the single source of truth that both the wheel animation and
//  the control panel render from. Owned by DevicesService, keyed by device id.
//

import Foundation

struct DeviceRuntimeState: Codable, Equatable {
    var isPowerOn: Bool = false
    var fanSpeed: Double = 0.5

    var included: Set<UUID> = []
    var opacities: [UUID: Double] = [:]
    var focusedPodID: UUID? = nil

    // Template lineage: `currentTemplateID` clears when the mix is edited;
    // `sourceTemplateID` survives edits so a "modified" template can be restored.
    var currentTemplateID: UUID? = nil
    var sourceTemplateID: UUID? = nil

    // Per-session template length (nil = ∞). `startDate` anchors the countdown so
    // it resumes at the correct elapsed position across navigation, like a player.
    var templateLengthDuration: TimeInterval? = nil
    var templateLengthStartDate: Date? = nil
}
