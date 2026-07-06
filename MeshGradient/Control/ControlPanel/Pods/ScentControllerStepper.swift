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
            }

            Spacer()

            // Custom stepper — kept for reference, using the default `Stepper` instead.
//            InlineStepper(
//                value: $value,
//                range: AppConfig.minIntensity ... AppConfig.maxIntensity,
//                step: AppConfig.maxIntensity * 0.25,
//                format: { v in
//                    // Show a clear, bold percentage
//                    "\(Int((v / AppConfig.maxIntensity) * 100))%"
//                }
//            )
//            .padding(.leading, 12)
//            .disabled(focused == nil)
//            .opacity(focused == nil ? 0.45 : 1.0)

            Stepper(
                value: $value,
                in: AppConfig.minIntensity ... AppConfig.maxIntensity,
                step: AppConfig.maxIntensity * 0.25
            ) {
                Text("\(Int((value / AppConfig.maxIntensity) * 100))%")
                    .font(.subheadline)
                    .monospacedDigit()
            }
            .fixedSize()
            .padding(.leading, 12)
            .disabled(focused == nil)
            .opacity(focused == nil ? 0 : 1.0)
        }
        

    }
}
