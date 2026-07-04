//
//  AppModel.swift
//  High-level app state & wiring: exposes session/devices/templates to SwiftUI,
//  starts sync (future), and coordinates simple cross-service reactions.
//

import Foundation
import Combine

@MainActor
final class AppModel: ObservableObject {
    // Services
    let sessionService: SessionService
    let templatesService: TemplatesService
    let devicesService: DevicesService
    let deviceNotificationsService: DeviceNotificationsService
    let controlService: ControlService
    let syncEngine: SyncEngine

    // Subscriptions
    private var bag = Set<AnyCancellable>()

    // Designated initializer: caller provides services (no default args → no cross-actor calls).
    init(
        sessionService: SessionService,
        templatesService: TemplatesService,
        devicesService: DevicesService,
        deviceNotificationsService: DeviceNotificationsService,
        controlService: ControlService,
        syncEngine: SyncEngine
    ) {
        self.sessionService = sessionService
        self.templatesService = templatesService
        self.devicesService = devicesService
        self.deviceNotificationsService = deviceNotificationsService
        self.controlService = controlService
        self.syncEngine = syncEngine

        // Load local cache immediately
        Task { await templatesService.load() }
        Task { await devicesService.load() }

        devicesService.$devices
            .sink { [weak self] devices in
                self?.deviceNotificationsService.refresh(from: devices)
            }
            .store(in: &bag)

        // Start/stop sync based on session state (safe no-op for now)
        sessionService.$state
            .sink { [weak self] state in
                guard let self else { return }
                switch state {
                case .guest:
                    self.syncEngine.stop()
                case .signedIn(let user):
                    self.syncEngine.start(
                        user: user,
                        templates: self.templatesService,
                        devices: self.devicesService
                    )
                }
            }
            .store(in: &bag)
    }

    // Convenience initializer: constructs default services on the main actor.
    convenience init() {
        self.init(
            sessionService: SessionService(),
            templatesService: TemplatesService(local: LocalTemplatesRepository()),
            devicesService: DevicesService(local: LocalDevicesRepository()),
            deviceNotificationsService: DeviceNotificationsService(),
            controlService: ControlService(),
            syncEngine: SyncEngine()
        )
    }

    /// Applies the active template to the selected device via ControlService.
    func applyActiveTemplateToSelectedDevice() {
        guard
            let device = devicesService.selected,
            let template = templatesService.activeTemplate
        else { return }
        controlService.send(.applyTemplate(templateID: template.id), to: device)
        templatesService.setActiveTemplateID(template.id)
    }
    
    func applyPreviousTemplate(to vm: GradientWheelViewModel, on device: Device) {
        guard vm.isUsingTemplate,
              let template = templatesService.previousTemplate()
        else { return }

        vm.applyTemplate(template, on: device)
    }

    func applyNextTemplate(to vm: GradientWheelViewModel, on device: Device) {
        guard vm.isUsingTemplate,
              let template = templatesService.nextTemplate()
        else { return }

        vm.applyTemplate(template, on: device)
    }
}
