import SwiftUI

struct DevicesPage: View {
    @EnvironmentObject private var app: AppModel

    @State private var isLoading = true
    @State private var showingScanner = false
    @State private var showingControlPage = false
    @State private var didLoad = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isLoading {
                loadingView
            } else {
                DevicesContentView(
                    devicesService: app.devicesService,
                    onOpen: open,
                    onAddDevice: { showingScanner = true },
                    onReload: reloadDevices
                )
            }
        }
        .navigationDestination(isPresented: $showingControlPage) {
            ControlPage()
                .toolbar(.hidden, for: .tabBar)
                .toolbar(.visible, for: .navigationBar)
        }
        .sheet(isPresented: $showingScanner) {
            ScannerSheet()
        }
        .task {
            await loadDevicesIfNeeded()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)

            Text("Loading devices")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func open(_ device: Device) {
        app.devicesService.select(device.id)
        showingControlPage = true
    } 

    private func loadDevicesIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true
        await reloadDevices()
    }

    private func reloadDevices() async {
        isLoading = true
        async let load: Void = app.devicesService.load()
        async let delay: Void = simulatedNetworkDelay()
        _ = await (load, delay)
        isLoading = false
    }

    private func simulatedNetworkDelay() async {
        try? await Task.sleep(nanoseconds: 850_000_000)
    }
}

private struct DevicesContentView: View {
    @ObservedObject var devicesService: DevicesService

    let onOpen: (Device) -> Void
    let onAddDevice: () -> Void
    let onReload: () async -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
//                headerView

                if devicesService.devices.isEmpty {
                    emptyStateView
                } else {
                    VStack(spacing: 14) {
                        ForEach(devicesService.devices) { device in
                            Button {
                                onOpen(device)
                            } label: {
                                DeviceCard(
                                    device: device,
                                    status: DeviceRunStatus.status(for: device)
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        addDeviceButton
                            .padding(.top, 6)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .refreshable {
            await onReload()
        }
    }

//    private var headerView: some View {
//        Text("Choose a diffuser to control")
//            .font(.subheadline)
//            .foregroundStyle(.secondary)
//    }

    private var addDeviceButton: some View {
        Button(action: onAddDevice) {
            Label("Add device", systemImage: "qrcode.viewfinder")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
        }
        .buttonStyle(.glass)
        .accessibilityLabel("Add device")
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image("device")
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: 120, height: 120)
                .opacity(0.8)
            

            Text("No devices available")
                .font(.headline)

            Button(action: onAddDevice) {
                Label("Add device", systemImage: "qrcode.viewfinder")
                    .font(.headline)
            }
            .buttonStyle(.glass)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .adaptiveGlassBackground(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        DevicesPage()
            .customTopBar("Devices")
    }
    .environmentObject(AppModel())
    .preferredColorScheme(.dark)
}
