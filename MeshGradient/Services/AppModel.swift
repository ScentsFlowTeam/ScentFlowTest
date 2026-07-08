//
//  AppModel.swift
//  High-level app state & wiring: exposes session/devices/templates to SwiftUI,
//  and coordinates simple cross-service reactions.
//

import Foundation
import Combine

@MainActor
final class AppModel: ObservableObject {
    // The single account/session for the app. Owned here so account-scoped
    // loading can hang off it later; injected into the environment as-is.
    let authSession: AuthSession
    let templatesService: TemplatesService
    let devicesService: DevicesService
    let deviceNotificationsService: DeviceNotificationsService
    let controlService: ControlService

    // Subscriptions
    private var bag = Set<AnyCancellable>()

    // Designated initializer: caller provides services (no default args → no cross-actor calls).
    init(
        authSession: AuthSession,
        templatesService: TemplatesService,
        devicesService: DevicesService,
        deviceNotificationsService: DeviceNotificationsService,
        controlService: ControlService
    ) {
        self.authSession = authSession
        self.templatesService = templatesService
        self.devicesService = devicesService
        self.deviceNotificationsService = deviceNotificationsService
        self.controlService = controlService

        // Load local cache immediately
        Task { await templatesService.load() }
        Task { await devicesService.load() }

        devicesService.$devices
            .sink { [weak self] devices in
                self?.deviceNotificationsService.refresh(from: devices)
            }
            .store(in: &bag)
    }

    // Convenience initializer: constructs default services on the main actor.
    convenience init() {
        self.init(
            authSession: AuthSession(),
            templatesService: TemplatesService(local: LocalTemplatesRepository()),
            devicesService: DevicesService(local: LocalDevicesRepository()),
            deviceNotificationsService: DeviceNotificationsService(),
            controlService: ControlService()
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
    
    func applyPreviousTemplate(to runtime: DeviceRuntime, on device: Device) {
        guard runtime.isUsingTemplate,
              let template = templatesService.previousTemplate()
        else { return }

        runtime.applyTemplate(template, on: device)
    }

    func applyNextTemplate(to runtime: DeviceRuntime, on device: Device) {
        guard runtime.isUsingTemplate,
              let template = templatesService.nextTemplate()
        else { return }

        runtime.applyTemplate(template, on: device)
    }

    /// Auto-advances when the current template's length ends. Unlike the manual
    /// next button, this loops back to the first after the last so playback keeps
    /// going, and a template without its own length inherits the just-finished
    /// length so the playlist keeps cycling on a steady cadence.
    func playNextTemplateOnFinish(to runtime: DeviceRuntime, on device: Device) {
        let templates = templatesService.templates
        guard runtime.isUsingTemplate,
              !templates.isEmpty,
              let currentID = runtime.currentTemplateID,
              let index = templates.firstIndex(where: { $0.id == currentID })
        else { return }

        let carriedLength = runtime.templateLengthDuration
        let next = templates[(index + 1) % templates.count]

        templatesService.setActiveTemplateID(next.id)
        runtime.applyTemplate(next, on: device)

        // Keep cycling even if the next template has no length of its own.
        if runtime.templateLengthDuration == nil, let carriedLength {
            runtime.setTemplateLengthDuration(carriedLength, startDate: Date())
        }
    }
}
