//
//  ControlPageSegmentPanel.swift
//  Bottom panel that toggles between Controls and Templates sections.
//  Reads state from services (TemplatesService, DevicesService) instead of old Stores.
//

import SwiftUI

struct ControlPageSegmentPanel: View {
    @ObservedObject var vm: GradientWheelViewModel
    @ObservedObject var templatesService: TemplatesService
    @ObservedObject var devicesService: DevicesService

    @Binding var segment: ControlPage.Segment
    @Binding var controlsExpanded: Bool

    let collapsedHeight: CGFloat

    private var shouldAutoSize: Bool { segment == .controls && controlsExpanded }
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
                            vm: vm,
                            device: device,
                            isExpanded: $controlsExpanded
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
                            vm: vm,
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
        .padding(.horizontal, 12)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.gray.opacity(0.15), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .frame(height: shouldAutoSize ? nil : collapsedHeight, alignment: .bottom)
        .animation(.bouncy, value: shouldAutoSize)
    }
}
