//
//  ControlPageSegmentPanel.swift
//  Bottom panel that toggles between Controls and Templates sections.
//  Reads state from services (TemplatesService, DevicesService) instead of old Stores.
//

import SwiftUI

struct ControlPanel: View {
    @ObservedObject var runtime: DeviceRuntime
    @ObservedObject var templatesService: TemplatesService
    @ObservedObject var devicesService: DevicesService

    @Binding var segment: ControlPage.Segment
    @Binding var controlsSize: PodsControlSize
    @Binding var isNamingTemplate: Bool

    let collapsedHeight: CGFloat
    let smallHeight: CGFloat

    /// Resolved panel height: `nil` (auto-size) only for the large controls size.
    private var resolvedHeight: CGFloat? {
        guard segment == .controls else { return collapsedHeight }
        switch controlsSize {
        case .small: return smallHeight
        case .medium: return collapsedHeight
        case .large: return nil
        }
    }

    private var currentDevice: Device? {
        devicesService.selected ?? devicesService.devices.first
    }

    var body: some View {
//        ZStack {
//
//        }
        VStack {
//                Picker("", selection: $segment) {
//                    Text("Controls").tag(ControlPage.Segment.controls)
//                    Text("Templates").tag(ControlPage.Segment.templates)
//                }
//                .pickerStyle(.segmented)
//                .padding(.vertical, 16)

            Group {
                switch segment {
                case .controls:
                    if let device = currentDevice {
                        ControlsSection(
                            runtime: runtime,
                            device: device,
                            size: $controlsSize,
                            isNamingTemplate: $isNamingTemplate
                        )
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "macmini")
                            Text("No devices available")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 180)
                    }

                case .templates:
                    if let device = currentDevice {
                        TemplatesSection(
                            templatesService: templatesService,
                            runtime: runtime,
                            device: device
                        )
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "macmini")
                            Text("No devices available")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 180)
                    }
                }
            }
            .id(segment)
        }
//        .padding(.horizontal, 12)
        // While naming a template the panel hugs its content (screen + Cancel/Create)
        // so the card sits directly above the keyboard with no empty space.
        .frame(maxHeight: isNamingTemplate ? nil : .infinity, alignment: .top)
//        .background(.gray.opacity(0.15), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
//        .background(.red, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .frame(height: isNamingTemplate ? nil : resolvedHeight, alignment: .bottom)

        .animation(.bouncy, value: controlsSize)
    }
}
