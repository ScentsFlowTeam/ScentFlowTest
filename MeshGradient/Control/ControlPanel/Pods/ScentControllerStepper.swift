//
//  ScentControllerStepper.swift
//  MeshGradient
//
//  Created by Dajun Xian on 9/25/25.
//


import SwiftUI

struct ScentControllerStepper: View {
    let focused: ScentPod?
    @Binding var value: Double
    
    var body: some View {
        HStack(spacing: 0) {
            if let focused {
                Text("\(focused.name)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                InlineStepper(
                    value: $value,
                    range: AppConfig.minIntensity ... AppConfig.maxIntensity,
                    step: AppConfig.maxIntensity * 0.25,
                    format: { v in
                        // Show a clear, bold percentage
                        "\(Int((v / AppConfig.maxIntensity) * 100))%"
                    }
                )
                .padding(.leading, 12)
            } else {
                Text("Select a scent to adjust intensity")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        

    }
}
