//
//  ExplorePage.swift
//  MeshGradient
//
//  Created by Dajun Xian on 9/11/25.
//

import SwiftUI

struct ExplorePage: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                NavigationLink {
                    MixingScreen()
                        .navigationTitle("Customize Pod")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar(.hidden, for: .tabBar)
                } label: {
                    CardWithShadowContainer(
                        title: "Customize Pod",
                        height: 120,
                        background: {
                            Image("colorInk2")
                                .resizable()
                                .scaledToFill()
                                .frame(height: 180)   // force consistent height
                                .clipped()
                        },
                        label: { Text("Unique scent make by you").font(.subheadline) }
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    TemplateExplorePage()
                        .toolbar(.hidden, for: .tabBar)
                } label: {
                    CardWithShadowContainer(
                        title: "Official Templates",
                        height: 120,
                        background: {
                            Image("mesh")
                                .resizable()
                                .scaledToFill()
                                .frame(height: 180)   // force consistent height
                                .clipped()
                                .opacity(0.7)
                        },
                        label: { Text("Browse and download scent mixes").font(.subheadline) }
                    )
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
            .padding(16)
        }
        .scrollDisabled(true)

    }
}
