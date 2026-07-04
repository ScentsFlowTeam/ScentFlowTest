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
        static let collapsedCardHeight: CGFloat = 334
    }

    @EnvironmentObject private var app: AppModel

    @StateObject private var vm = GradientWheelViewModel()

    @State private var controlsExpanded = false
    @State private var didInitialLoad = false
    @State private var isHydratingVM = false

    enum Segment: Int, Hashable { case controls = 0, templates = 1 }
    @State private var segment: Segment = .controls

    private var wheelScale: CGFloat {
        controlsExpanded ? UI.expandedScale : UI.collapsedScale
    }

    private var selectedDevice: Device? {
        app.devicesService.selected ?? app.devicesService.devices.first
    }

    private var navigationDeviceName: String {
        selectedDevice?.name ?? "Device"
    }

    private func persist(_ settings: GradientWheelViewModel.WheelSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            app.devicesService.saveSettingsBlobForSelected(data)
        }
    }

    private func loadDeviceIntoVM(_ device: Device) {
        isHydratingVM = true

        vm.updateDevicePods(device.insertedPods)

        if let blob = device.savedSettingsBlob,
           let decoded = try? JSONDecoder().decode(GradientWheelViewModel.WheelSettings.self, from: blob) {
            vm.load(from: decoded)
        } else {
            // First-time / no-blob fallback:
            // build a default state for THIS device, but do not let hydration save loop fire
            let empty = GradientWheelViewModel.WheelSettings(
                isPowerOn: false,
                fanSpeed: 0.5,
                wheel: .init(
                    included: [],
                    opacities: [:],
                    focusedPodID: nil
                )
            )
            vm.load(from: empty)
        }

        // Let all @Published updates settle before re-enabling persistence
        DispatchQueue.main.async {
            isHydratingVM = false
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                GradientContainerCircle(
                    colors: vm.selectedColorsWeighted,
                    animate: vm.isPowerOn,
                    meshOpacity: vm.wheelOpacity,
                    isOn: vm.isPowerOn,
                    onToggle: { vm.togglePower() }
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
                    vm: vm,
                    templatesService: app.templatesService,
                    devicesService: app.devicesService,
                    segment: $segment,
                    controlsExpanded: $controlsExpanded,
                    collapsedHeight: UI.collapsedCardHeight
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
        .onReceive(vm.settingsPublisher) { settings in
            guard !isHydratingVM else { return }
            persist(settings)
        }
        .onChange(of: vm.isPowerOn) { _, _ in
            guard !isHydratingVM else { return }
            persist(vm.exportSettings())
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
