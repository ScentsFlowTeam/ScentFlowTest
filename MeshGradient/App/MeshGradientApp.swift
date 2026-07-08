//
//  MeshGradientApp.swift
//  App entry. Creates a single AppModel and injects it into the environment
//  so all screens can access services (devices/templates/session) easily.
//

import SwiftUI

@main
@MainActor
struct MeshGradientApp: App {
    @StateObject private var appModel = AppModel()   // ← one source of truth

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appModel.authSession)
                .environmentObject(appModel)         // ← inject
                .applyGrayscaleTint()
                .environment(\.colorScheme, .dark)
        }
    }
}
