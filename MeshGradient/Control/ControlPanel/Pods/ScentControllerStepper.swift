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

            // Percentage label kept on the left of the controls.
            Text("\(Int((value / AppConfig.maxIntensity) * 100))%")
                .font(.subheadline)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.snappy, value: value)

            // Custom stepper styled with a thickMaterial capsule to match the
            // infinity / save / undo / redo buttons.
            stepperButtons
                .padding(.leading, 12)
                .disabled(focused == nil)
        }
        .opacity(focused == nil ? 0 : 1.0)
    }

    private var stepperButtons: some View {
        HStack(spacing: 0) {
            Button {
                value = max(AppConfig.minIntensity, value - AppConfig.maxIntensity * 0.25)
            } label: {
                Image(systemName: "minus")
                    .foregroundStyle(.primary)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
                    .accessibilityLabel("Decrease")
            }
            .buttonStyle(.plain)

            Divider()
                .frame(height: 22)
                .opacity(0.4)

            Button {
                value = min(AppConfig.maxIntensity, value + AppConfig.maxIntensity * 0.25)
            } label: {
                Image(systemName: "plus")
                    .foregroundStyle(.primary)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
                    .accessibilityLabel("Increase")
            }
            .buttonStyle(.plain)
        }
        .frame(height: 30)
        .background(.thickMaterial, in: Capsule())
    }
}
