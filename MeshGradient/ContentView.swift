//
//  ContentView.swift
//  Top-level tabs. Reads the shared AppModel from the environment instead of
//  creating view-scoped stores. Keeps your existing tab structure.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var app: AppModel     //   read the shared model

    var body: some View {
        TabView {
            Tab("Device", systemImage: "circle.hexagonpath.fill") {
                NavigationStack {
                    DevicesPage()
                }
            }

            Tab("Explore", systemImage: "sparkles") {
                NavigationStack {
                    ExplorePage()
                        .customTopBar("Explore")
                }
            }

            Tab("User", systemImage: "person.fill") {
                NavigationStack {
                    UserPage()
                }
            }
        }
        .tabBarMinimizeBehavior(.automatic)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppModel())
        .environmentObject(AuthSession())
        .preferredColorScheme(.dark)
}
