//
//  ScannerSheet.swift
//  MeshGradient
//
//  Updated: Rectangle with outside label + flashlight button below it
//

import SwiftUI
import AVFoundation

struct ScannerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = ScannerViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                if vm.authorization == .authorized {
                    CameraPreview(session: vm.session)
                        .ignoresSafeArea(edges: .bottom)
                        .overlay {
                            ReticleOverlay(
                                instruction: "Align the code inside the frame",
                                isTorchOn: vm.isTorchOn,
                                onToggleTorch: { vm.toggleTorch() }
                            )
                        }
                        .onAppear { vm.startIfNeeded() }
                        .onDisappear { vm.stop() }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 60, weight: .regular))
                            .symbolRenderingMode(.hierarchical)

                        Text(titleForStatus(vm.authorization))
                            .font(.title3).bold()

                        Text(messageForStatus(vm.authorization))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)

                        if vm.authorization == .denied || vm.authorization == .restricted {
                            Button {
                                vm.openSettings()
                            } label: {
                                Label("Open Settings", systemImage: "gearshape.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .padding(.top, 8)
                        }
                    }
                    .padding(24)
                }

                if let code = vm.lastScannedCode, vm.showBanner {
                    ScannedBanner(code: code)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(1)
                }
            }
            .background(Color.black.opacity(0.95).ignoresSafeArea())
//            .navigationTitle("Scan Code")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                await vm.requestPermissionAndConfigure()
            }
            .alert("Camera Unavailable", isPresented: $vm.showErrorAlert, actions: {
                Button("OK", role: .cancel) { }
            }, message: {
                Text(vm.errorMessage ?? "Something went wrong while accessing the camera.")
            })
        }
    }

    private func titleForStatus(_ status: AVAuthorizationStatus) -> String {
        switch status {
        case .authorized: return "Ready to Scan"
        case .denied, .restricted: return "Camera Access Needed"
        case .notDetermined: return "Allow Camera Access"
        @unknown default: return "Camera Access"
        }
    }

    private func messageForStatus(_ status: AVAuthorizationStatus) -> String {
        switch status {
        case .authorized:
            return "Point your camera at a QR code or barcode."
        case .denied, .restricted:
            return "To scan, enable camera access in Settings > Privacy > Camera."
        case .notDetermined:
            return "We’ll ask for permission to use the camera for scanning."
        @unknown default:
            return "We’ll ask for permission to use the camera for scanning."
        }
    }
}
