//
//  DeviceRuntime.swift
//  MeshGradient
//
//  The live, editable running state of the selected device. Both the wheel
//  (via WheelRenderModel) and the control panel bind to this one object — it is
//  the source of truth. Pure state + mutators; no rendering concerns live here.
//

import SwiftUI
import Combine

@MainActor
final class DeviceRuntime: ObservableObject {
    // MARK: - Device pods (mirror of the selected device's inserted pods)
    @Published private(set) var pods: [ScentPod] = []

    // MARK: - Power & fan
    @Published private(set) var isPowerOn: Bool = false
    @Published var fanSpeed: Double = 0.5

    // MARK: - Selection & per-pod intensity
    @Published private(set) var included: Set<UUID> = []
    @Published private(set) var opacities: [UUID: Double] = [:]
    @Published private(set) var focusedPodID: UUID?

    // MARK: - Template lineage
    @Published private(set) var currentTemplateID: UUID?
    @Published private(set) var sourceTemplateID: UUID?

    // MARK: - Template length
    @Published private(set) var templateLengthDuration: TimeInterval?
    @Published private(set) var templateLengthStartDate: Date?

    // MARK: - Pod edit history
    @Published private(set) var canUndoEdit = false
    @Published private(set) var canRedoEdit = false

    private struct PodEditSnapshot: Equatable {
        let included: Set<UUID>
        let opacities: [UUID: Double]
        let focusedPodID: UUID?
        let currentTemplateID: UUID?
    }

    private var undoStack: [PodEditSnapshot] = []
    private var redoStack: [PodEditSnapshot] = []
    private let maxEditHistoryCount = 40

    // MARK: - Derived
    var orderedPodIDs: [UUID] { pods.map(\.id) }
    var isUsingTemplate: Bool { currentTemplateID != nil }
    var canSelectMore: Bool { included.count < 6 }

    // MARK: - Device pods
    func updateDevicePods(_ pods: [ScentPod]) {
        self.pods = pods
        ensureFocusedPodIsValid()
        clearEditHistory()
    }

    // MARK: - Power & fan
    func setPower(_ on: Bool) {
        guard on != isPowerOn else { return }
        isPowerOn = on
    }

    func togglePower() { setPower(!isPowerOn) }
    func setFanSpeed(_ v: Double) { fanSpeed = max(0, min(1, v)) }

    // MARK: - Template lineage
    func setCurrentTemplateID(_ id: UUID?) {
        currentTemplateID = id
        sourceTemplateID = id
        clearEditHistory()
    }

    func markCurrentTemplateModified() {
        guard currentTemplateID != nil else { return }
        currentTemplateID = nil
    }

    // MARK: - Template length
    func setTemplateLengthDuration(_ duration: TimeInterval?, startDate: Date? = nil) {
        let normalized = (duration ?? 0) > 0 ? duration : nil
        templateLengthDuration = normalized
        templateLengthStartDate = normalized == nil ? nil : (startDate ?? Date())
    }

    // MARK: - Apply a template
    func applyTemplate(_ template: ScentsTemplate?, on device: Device) {
        guard let template else {
            included = []
            opacities = [:]
            focusedPodID = nil
            currentTemplateID = nil
            sourceTemplateID = nil
            templateLengthDuration = nil
            templateLengthStartDate = nil
            fanSpeed = 0.5
            isPowerOn = false
            clearEditHistory()
            return
        }

        let ordered = template.matchingPods(in: device).prefix(6).map(\.id)
        included = Set(ordered)

        var newOpacities = opacities
        for id in ordered where newOpacities[id] == nil {
            newOpacities[id] = AppConfig.maxIntensity * 0.5
        }
        opacities = newOpacities.filter { included.contains($0.key) }

        focusedPodID = ordered.first
        currentTemplateID = template.id
        sourceTemplateID = template.id

        let templateDuration = (template.duration ?? 0) > 0 ? template.duration : nil
        templateLengthDuration = templateDuration
        templateLengthStartDate = templateDuration == nil ? nil : Date()

        ensureFocusedPodIsValid()
        clearEditHistory()
    }

    // MARK: - Pod selection / intensity
    func toggle(_ podID: UUID) {
        let oldIncluded = included

        if included.contains(podID) {
            recordEditSnapshot()
            if focusedPodID == podID {
                included.remove(podID)
                opacities[podID] = nil
            } else {
                focusedPodID = podID
            }
        } else {
            guard canSelectMore else { return }
            recordEditSnapshot()
            included.insert(podID)
            focusedPodID = podID
            opacities[podID] = opacities[podID] ?? (AppConfig.maxIntensity * 0.5)
        }

        if included != oldIncluded { currentTemplateID = nil }
        ensureFocusedPodIsValid()
    }

    func setPod(_ podID: UUID, isIncluded shouldInclude: Bool, initialOpacity: Double? = nil) {
        let oldIncluded = included
        let clampedInitialOpacity = initialOpacity.map { max(0.0, min(AppConfig.maxIntensity, $0)) }

        if shouldInclude {
            guard !included.contains(podID), canSelectMore else { return }
            recordEditSnapshot()
            included.insert(podID)
            focusedPodID = podID
            opacities[podID] = clampedInitialOpacity ?? opacities[podID] ?? (AppConfig.maxIntensity * 0.5)
        } else {
            guard included.contains(podID) else { return }
            recordEditSnapshot()
            included.remove(podID)
            opacities[podID] = nil
        }

        if included != oldIncluded { currentTemplateID = nil }
        ensureFocusedPodIsValid()
    }

    func setOpacity(_ value: Double, for podID: UUID) {
        let clamped = max(0.0, min(AppConfig.maxIntensity, value))
        let oldValue = opacities[podID] ?? 0
        guard abs(oldValue - clamped) > 0.0001 else { return }

        recordEditSnapshot()
        currentTemplateID = nil
        opacities[podID] = clamped
    }

    func undoEdit() {
        guard let snapshot = undoStack.popLast() else { return }
        redoStack.append(currentEditSnapshot)
        restoreEditSnapshot(snapshot)
        updateEditHistoryAvailability()
    }

    func redoEdit() {
        guard let snapshot = redoStack.popLast() else { return }
        undoStack.append(currentEditSnapshot)
        restoreEditSnapshot(snapshot)
        updateEditHistoryAvailability()
    }

    private var currentEditSnapshot: PodEditSnapshot {
        PodEditSnapshot(
            included: included,
            opacities: opacities,
            focusedPodID: focusedPodID,
            currentTemplateID: currentTemplateID
        )
    }

    private func recordEditSnapshot() {
        let snapshot = currentEditSnapshot
        guard undoStack.last != snapshot else { return }

        undoStack.append(snapshot)
        if undoStack.count > maxEditHistoryCount {
            undoStack.removeFirst(undoStack.count - maxEditHistoryCount)
        }
        redoStack.removeAll()
        updateEditHistoryAvailability()
    }

    private func restoreEditSnapshot(_ snapshot: PodEditSnapshot) {
        included = snapshot.included
        opacities = snapshot.opacities.filter { included.contains($0.key) }
        focusedPodID = snapshot.focusedPodID
        currentTemplateID = snapshot.currentTemplateID
        ensureFocusedPodIsValid()
    }

    private func clearEditHistory() {
        undoStack.removeAll()
        redoStack.removeAll()
        updateEditHistoryAvailability()
    }

    private func updateEditHistoryAvailability() {
        canUndoEdit = !undoStack.isEmpty
        canRedoEdit = !redoStack.isEmpty
    }

    private func ensureFocusedPodIsValid() {
        guard !included.isEmpty else {
            focusedPodID = nil
            return
        }
        if let focusedPodID, included.contains(focusedPodID) { return }
        focusedPodID = orderedPodIDs.first(where: { included.contains($0) })
    }

    // MARK: - Persistence snapshot
    var state: DeviceRuntimeState {
        DeviceRuntimeState(
            isPowerOn: isPowerOn,
            fanSpeed: fanSpeed,
            included: included,
            opacities: opacities,
            focusedPodID: focusedPodID,
            currentTemplateID: currentTemplateID,
            sourceTemplateID: sourceTemplateID,
            templateLengthDuration: templateLengthDuration,
            templateLengthStartDate: templateLengthStartDate
        )
    }

    /// Debounced, deduplicated snapshot emitted whenever any user-facing state
    /// changes. ControlPage subscribes to persist it into DevicesService.
    ///
    /// Stored (lazy) rather than computed on purpose: `.onReceive` must keep a
    /// SINGLE subscription across ControlPage re-renders. A fresh computed
    /// publisher each render would cancel/re-subscribe (with `.dropFirst()`),
    /// resetting the debounce and silently dropping the pending persist.
    private(set) lazy var statePublisher: AnyPublisher<DeviceRuntimeState, Never> = {
        let signals: [AnyPublisher<Void, Never>] = [
            $isPowerOn.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $fanSpeed.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $included.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $opacities.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $focusedPodID.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $currentTemplateID.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $sourceTemplateID.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $templateLengthDuration.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $templateLengthStartDate.dropFirst().map { _ in () }.eraseToAnyPublisher()
        ]

        return Publishers.MergeMany(signals)
            .map { [unowned self] in self.state }
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }()

    /// Hydrates from a persisted snapshot. Anchors a missing start date at load so
    /// a timed template's countdown has a stable reference point.
    func apply(_ s: DeviceRuntimeState) {
        included = s.included
        opacities = s.opacities
        focusedPodID = s.focusedPodID
        currentTemplateID = s.currentTemplateID
        sourceTemplateID = s.sourceTemplateID
        templateLengthDuration = s.templateLengthDuration
        templateLengthStartDate = (s.templateLengthDuration != nil && s.templateLengthStartDate == nil)
            ? Date()
            : s.templateLengthStartDate
        isPowerOn = s.isPowerOn
        setFanSpeed(s.fanSpeed)
        ensureFocusedPodIsValid()
        clearEditHistory()
    }
}

