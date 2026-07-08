//
//  WheelRenderModel.swift
//  MeshGradient
//
//  The wheel's view concern: turns a DeviceRuntime's active pods + intensities
//  into animated gradient color stops. It observes the runtime (the source of
//  truth) and never owns device state itself.
//

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
final class WheelRenderModel: ObservableObject {
    /// Weighted color stops the wheel renders.
    @Published private(set) var colors: [Color] = []
    /// Fade opacity for the mesh (drives power-on/off transitions).
    @Published private(set) var wheelOpacity: Double = 0.0

    private let builder = GradientWheelBuilder()
    private var rebuildTask: Task<Void, Never>?
    private var clearTask: Task<Void, Never>?
    private var bag = Set<AnyCancellable>()

    /// Weakly held so the render model reacts to the current runtime's changes.
    private weak var runtime: DeviceRuntime?
    private var didInitialRender = false

    deinit {
        rebuildTask?.cancel()
        clearTask?.cancel()
    }

    /// Binds to a runtime: rebuilds when the mix changes (while on) and fades in/out
    /// on power. The first emission renders the loaded state without animation.
    func bind(to runtime: DeviceRuntime) {
        self.runtime = runtime
        didInitialRender = false
        bag.removeAll()
        rebuildTask?.cancel()
        clearTask?.cancel()

        // Mix changes → rebuild (only visible while powered on).
        //
        // `.receive(on:)` is important: @Published emits during the source's
        // `willSet`, so reacting synchronously would (a) read pre-mutation state
        // and (b) run `withAnimation`/mutate this model *inside* the runtime's
        // update cycle — a re-entrancy that can drop sibling view updates (e.g.
        // the power button). Hopping to the next main-queue tick lets the runtime
        // mutation commit and SwiftUI finish its pass first.
        Publishers.MergeMany(
            runtime.$pods.map { _ in () }.eraseToAnyPublisher(),
            runtime.$included.map { _ in () }.eraseToAnyPublisher(),
            runtime.$opacities.map { _ in () }.eraseToAnyPublisher()
        )
        .dropFirst()
        .receive(on: DispatchQueue.main)
        .sink { [weak self] in
            guard let self, let runtime = self.runtime, runtime.isPowerOn else { return }
            self.scheduleRebuild(animated: true)
        }
        .store(in: &bag)

        // Power drives fade + initial render.
        runtime.$isPowerOn
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isOn in
                self?.applyPower(isOn)
            }
            .store(in: &bag)
    }

    private func applyPower(_ isOn: Bool) {
        let animated = didInitialRender
        didInitialRender = true

        if isOn {
            clearTask?.cancel(); clearTask = nil
            scheduleRebuild(animated: animated)
            setOpacity(1.0, animated: animated)
        } else {
            setOpacity(0.0, animated: animated)
            rebuildTask?.cancel()
            clearTask?.cancel()
            if animated {
                let fade: Double = 1.0
                clearTask = Task { [weak self] in
                    try? await Task.sleep(nanoseconds: UInt64(fade * 1_000_000_000))
                    if Task.isCancelled { return }
                    self?.colors = []
                }
            } else {
                colors = []
            }
        }
    }

    private func setOpacity(_ value: Double, animated: Bool) {
        if animated {
            withAnimation(.easeInOut(duration: 1.0)) { wheelOpacity = value }
        } else {
            wheelOpacity = value
        }
    }

    private func scheduleRebuild(animated: Bool) {
        rebuildTask?.cancel(); clearTask?.cancel()

        rebuildTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 80_000_000)
            if Task.isCancelled { return }
            guard let self, let runtime = self.runtime else { return }

            // Read the runtime state HERE (after the sleep) rather than when the
            // triggering @Published fires. @Published emits during `willSet`, so a
            // synchronous read would see the pre-mutation value; deferring to this
            // task lets the mutation commit first, so the snapshot is current.
            let snap = GradientWheelBuilder.Snapshot(
                orderedPodIDs: runtime.orderedPodIDs,
                colorsByPodID: Dictionary(uniqueKeysWithValues: runtime.pods.map { ($0.id, $0.color.color) }),
                included: runtime.included,
                opacities: runtime.opacities,
                maxIntensity: AppConfig.maxIntensity
            )

            let stops = await self.builder.makeStops(from: snap)
            if Task.isCancelled { return }
            if animated {
                withAnimation(.easeInOut(duration: 1.0)) { self.colors = stops }
            } else {
                self.colors = stops
            }
        }
    }
}
