//
//  ControlPage.swift
//

import SwiftUI

struct ControlPage: View {

    private enum UI {
        static let wheelPadding: CGFloat = 80
        static let baseVPadding: CGFloat = 24
        static let expandedScale: CGFloat = 0.85
        static let collapsedScale: CGFloat = 1.00
        static let cardHPad: CGFloat = 16
        static let cardBottomPad: CGFloat = 16
        static let smallCardHeight: CGFloat = 280
        static let collapsedCardHeight: CGFloat = 380
    }

    @EnvironmentObject private var app: AppModel

    // Source of truth for the device's running state; the wheel and the control
    // panel both bind to `runtime`. `render` is the wheel's view-only projection.
    @StateObject private var runtime = DeviceRuntime()
    @StateObject private var render = WheelRenderModel()

    @State private var controlsSize: PodsControlSize = .small
    @State private var didInitialLoad = false
    @State private var isHydratingVM = false
    @State private var allowsCirclePowerTransition = false

    enum Segment: Int, Hashable { case controls = 0, templates = 1 }
    @State private var segment: Segment = .controls

    private var wheelScale: CGFloat {
        controlsSize == .large ? UI.expandedScale : UI.collapsedScale
    }

    private var selectedDevice: Device? {
        app.devicesService.selected ?? app.devicesService.devices.first
    }

    private var navigationDeviceName: String {
        selectedDevice?.name ?? "Device"
    }

    private func persist(_ state: DeviceRuntimeState) {
        guard let id = app.devicesService.selectedID else { return }
        app.devicesService.setRuntime(state, for: id)
    }

    private func loadDeviceIntoVM(_ device: Device) {
        isHydratingVM = true
        allowsCirclePowerTransition = false

        runtime.updateDevicePods(device.insertedPods)
        runtime.apply(app.devicesService.runtime(for: device.id) ?? DeviceRuntimeState())

        // Rebind the render model so this device's loaded state renders without
        // a fade animation (rebinding resets the "initial render" flag).
        render.bind(to: runtime)

        // Let all @Published updates settle before re-enabling persistence
        DispatchQueue.main.async {
            isHydratingVM = false
            allowsCirclePowerTransition = true
            // Persist any load-time normalization (e.g. an anchored timer start
            // date) so timer progress survives future navigation.
            persist(runtime.state)
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                GradientContainerCircle(
                    colors: render.colors,
                    animate: runtime.isPowerOn,
                    meshOpacity: render.wheelOpacity,
                    animatePowerTransition: allowsCirclePowerTransition,
                    isOn: runtime.isPowerOn,
                    onToggle: { runtime.togglePower() }
                )
                .aspectRatio(1, contentMode: .fit)
                .padding(.horizontal, UI.wheelPadding)
                .scaleEffect(wheelScale, anchor: .center)
                .animation(.spring(response: 0.45, dampingFraction: 0.85), value: wheelScale)
                .padding(.top, UI.baseVPadding)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            VStack {
                Spacer().frame(minHeight: 30)

                ControlPanel(
                    runtime: runtime,
                    templatesService: app.templatesService,
                    devicesService: app.devicesService,
                    segment: $segment,
                    controlsSize: $controlsSize,
                    collapsedHeight: UI.collapsedCardHeight,
                    smallHeight: UI.smallCardHeight
                )
//                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .containerShape(.rect(cornerRadius: ControlCornerStyle.radius, style: .continuous))
                .padding(.horizontal, UI.cardHPad)
                .padding(.bottom, UI.cardBottomPad)
//                .shadow(radius: 6)
            }
        }

        .navigationTitle(navigationDeviceName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let selectedDevice {
                    NavigationLink {
                        DeviceInfoPage(device: selectedDevice)
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onReceive(runtime.statePublisher) { state in
            guard !isHydratingVM else { return }
            persist(state)
        }
        .onDisappear {
            // Flush immediately on leave so a change made inside the debounce
            // window (e.g. selecting a template then navigating away) isn't lost.
            guard !isHydratingVM else { return }
            persist(runtime.state)
        }
        .onChange(of: runtime.isPowerOn) { _, _ in
            guard !isHydratingVM else { return }
            persist(runtime.state)
        }
        .task {
            guard !didInitialLoad else { return }
            didInitialLoad = true

            await app.templatesService.load()
            await app.devicesService.load()

            if let current = app.devicesService.selected ?? app.devicesService.devices.first {
                if app.devicesService.selectedID != current.id {
                    app.devicesService.select(current.id)
                }
                loadDeviceIntoVM(current)
            }
        }
        .onChange(of: app.devicesService.selectedID) { _, _ in
            guard let current = app.devicesService.selected else { return }
            loadDeviceIntoVM(current)
        }
    }
}
