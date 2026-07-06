import SwiftUI
import Combine

actor GradientWheelBuilder {
    struct Snapshot {
        let orderedPodIDs: [UUID]
        let colorsByPodID: [UUID: Color]
        let included: Set<UUID>
        let opacities: [UUID: Double]
        let maxIntensity: Double
    }
    
    func makeStops(from s: Snapshot) -> [Color] {
        let maxI = max(0.0001, s.maxIntensity)
        let ids = s.orderedPodIDs.filter { s.included.contains($0) }
        var stops: [Color] = ids.compactMap { id in
            guard let base = s.colorsByPodID[id] else { return nil }
            let a = min(s.maxIntensity, max(0, s.opacities[id] ?? 0))
            return a < 0.01 ? nil : base.opacity(a / maxI)
        }
        if stops.count == 1 { stops.append(contentsOf: [stops[0], stops[0].opacity(0.5)]) }
        else if stops.count == 2 { stops.append(stops[0].opacity(0.5)) }
        return stops
    }
}

@MainActor
final class GradientWheelViewModel: ObservableObject {

    // MARK: - For template player tracking
    @Published private(set) var currentTemplateID: UUID?

    var isUsingTemplate: Bool {
        currentTemplateID != nil
    }
    
    // MARK: - External, live inputs (device pods + power)
    @Published private(set) var orderedPodIDs: [UUID] = []
    private var colorsByPodID: [UUID: Color] = [:]
    @Published private(set) var pods: [ScentPod] = []

    /// Power state the UI binds to
    @Published private(set) var isPowerOn: Bool = false
    @Published var wheelOpacity: Double = 1.0

    @Published var fanSpeed: Double = 0.5

    // MARK: - Selection & per-pod intensity
    @Published private(set) var included: Set<UUID> = []
    @Published private(set) var opacities: [UUID: Double] = [:]
    @Published private(set) var focusedPodID: UUID?
    var canSelectMore: Bool { included.count < 6 }

    // MARK: - Output
    @Published private(set) var selectedColorsWeighted: [Color] = []

    // MARK: - Async machinery
    private var rebuildTask: Task<Void, Never>?
    private var clearTask: Task<Void, Never>?
    private let builder = GradientWheelBuilder()

    deinit { rebuildTask?.cancel(); clearTask?.cancel() }

    // MARK: - Public API
    func updateDevicePods(_ pods: [ScentPod]) {
        self.pods = pods
        orderedPodIDs = pods.map(\.id)
        colorsByPodID = Dictionary(uniqueKeysWithValues: pods.map { ($0.id, $0.color.color) })

        ensureFocusedPodIsValid()

        if isPowerOn { scheduleWheelRebuild() }
    }

    func setPower(_ on: Bool) {
        guard on != isPowerOn else { return }
        isPowerOn = on
        if on {
            clearTask?.cancel(); clearTask = nil
            scheduleWheelRebuild()
            withAnimation(.easeInOut(duration: 1.0)) { wheelOpacity = 1.0 }
        } else {
            let fade: Double = 1.0
            withAnimation(.easeInOut(duration: fade)) { wheelOpacity = 0.0 }
            clearTask?.cancel()
            clearTask = Task { [weak self] in
                guard let self else { return }
                try? await Task.sleep(nanoseconds: UInt64(fade * 1_000_000_000))
                if Task.isCancelled { return }
                await MainActor.run { self.selectedColorsWeighted = [] }
            }
        }
    }

    func togglePower() { setPower(!isPowerOn) }
    func setFanSpeed(_ v: Double) { fanSpeed = max(0, min(1, v)) }


    func setCurrentTemplateID(_ id: UUID?) {
        currentTemplateID = id
    }
    
    func applyTemplate(_ template: ScentsTemplate?, on device: Device) {

        guard let template else {
            rebuildTask?.cancel()
            clearTask?.cancel()

            included = []
            opacities = [:]
            focusedPodID = nil
            currentTemplateID = nil

            fanSpeed = 0.5
            isPowerOn = false
            wheelOpacity = 0.0
            selectedColorsWeighted = []

            return
        }

        let ordered = template.matchingPods(in: device).prefix(6).map(\.id)

        included = Set(ordered)

        var newOpacities = opacities
        for id in ordered where newOpacities[id] == nil {
            newOpacities[id] = AppConfig.maxIntensity * 0.5
        }
        newOpacities = newOpacities.filter { included.contains($0.key) }
        opacities = newOpacities

        focusedPodID = ordered.first
        currentTemplateID = template.id
        ensureFocusedPodIsValid()

        if isPowerOn { scheduleWheelRebuild() }
    }
    

    func toggle(_ podID: UUID) {
        let oldIncluded = included

        if included.contains(podID) {
            if focusedPodID == podID {
                included.remove(podID)
                opacities[podID] = nil
            } else {
                focusedPodID = podID
            }
        } else {
            guard canSelectMore else { return }
            included.insert(podID)
            focusedPodID = podID
            opacities[podID] = opacities[podID] ?? (AppConfig.maxIntensity * 0.5)
        }

        if included != oldIncluded {
            currentTemplateID = nil
        }

        ensureFocusedPodIsValid()

        if isPowerOn { scheduleWheelRebuild() }
    }

    func setOpacity(_ value: Double, for podID: UUID) {
        let clamped = max(0.0, min(AppConfig.maxIntensity, value))
        let oldValue = opacities[podID] ?? 0

        if abs(oldValue - clamped) > 0.0001 {
            currentTemplateID = nil
        }

        opacities[podID] = clamped
        if isPowerOn { scheduleWheelRebuild() }
    }
    
    private func ensureFocusedPodIsValid() {
        // No included pod -> no focused pod
        guard !included.isEmpty else {
            focusedPodID = nil
            return
        }

        // Keep current focus if it is still valid
        if let focusedPodID, included.contains(focusedPodID) {
            return
        }

        // Otherwise fallback to the first included pod in device order
        focusedPodID = orderedPodIDs.first(where: { included.contains($0) })
    }

    // MARK: - Debounced rebuild
    func scheduleWheelRebuild(animated: Bool = true) {
        rebuildTask?.cancel(); clearTask?.cancel()
        let snap = GradientWheelBuilder.Snapshot(
            orderedPodIDs: orderedPodIDs,
            colorsByPodID: colorsByPodID,
            included: included,
            opacities: opacities,
            maxIntensity: AppConfig.maxIntensity
        )
        rebuildTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 80_000_000)
            let stops = await self?.builder.makeStops(from: snap) ?? []
            if Task.isCancelled { return }
            await MainActor.run {
                guard let self else { return }
                if animated {
                    withAnimation(.easeInOut(duration: 1.0)) {
                        self.selectedColorsWeighted = stops
                    }
                } else {
                    self.selectedColorsWeighted = stops
                }
            }
        }
    }


    // MARK: - Snapshot I/O (bind to your CurrentSettings if desired)
    struct WheelSnapshot: Codable, Equatable {
        var included: Set<UUID>
        var opacities: [UUID: Double]
        var focusedPodID: UUID?
    }

    func snapshot() -> WheelSnapshot {
        WheelSnapshot(included: included, opacities: opacities, focusedPodID: focusedPodID)
    }

    func load(from s: WheelSettings) {
        included = s.wheel.included
        opacities = s.wheel.opacities
        focusedPodID = s.wheel.focusedPodID
        currentTemplateID = nil
        
        ensureFocusedPodIsValid()

        isPowerOn = s.isPowerOn
        setFanSpeed(s.fanSpeed)

        if !s.isPowerOn || included.isEmpty {
            selectedColorsWeighted = []
            wheelOpacity = s.isPowerOn ? 1.0 : 0.0
            rebuildTask?.cancel()
            clearTask?.cancel()
        } else {
            wheelOpacity = 1.0
            scheduleWheelRebuild(animated: false)
        }
    }
}


extension GradientWheelViewModel {
    struct WheelSettings: Codable, Equatable {
        var isPowerOn: Bool
        var fanSpeed: Double
        var wheel: WheelSnapshot
    }
}


extension GradientWheelViewModel {
    func exportSettings() -> WheelSettings {
        WheelSettings(isPowerOn: isPowerOn,
                      fanSpeed: fanSpeed,
                      wheel: snapshot())
    }

}

extension GradientWheelViewModel {
    /// Emits a debounced, deduplicated snapshot of user-facing settings
    /// whenever isPowerOn / fanSpeed / included / opacities / focusedPodID change.
    var settingsPublisher: AnyPublisher<WheelSettings, Never> {
        // Turn each published property into a Void signal upon change (skip initial)
        let p1 = $isPowerOn.dropFirst().map { _ in () }.eraseToAnyPublisher()
        let p2 = $fanSpeed.dropFirst().map { _ in () }.eraseToAnyPublisher()
        let p3 = $included.dropFirst().map { _ in () }.eraseToAnyPublisher()
        let p4 = $opacities.dropFirst().map { _ in () }.eraseToAnyPublisher()
        let p5 = $focusedPodID.dropFirst().map { _ in () }.eraseToAnyPublisher()

        return Publishers.MergeMany(p1, p2, p3, p4, p5)
            //.debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .map { [unowned self] in self.exportSettings() }
            .removeDuplicates() // WheelSettings: Equatable
            .eraseToAnyPublisher()
    }
}
