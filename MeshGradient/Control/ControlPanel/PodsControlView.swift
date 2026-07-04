//
//  PodsControlView.swift
//  MeshGradient
//
//  Created by Dajun Xian on 3/19/26.
//

import SwiftUI

struct PodsControlView: View {
    @ObservedObject var vm: GradientWheelViewModel
    @Binding var isExpanded: Bool

    private enum UI {
        static let opacityRowHeight: CGFloat = 24
    }

    var body: some View {
        VStack(spacing: 12) {
            header

            if !isExpanded {
                ScentPodsRow(
                    pods: vm.pods,
                    includedIDs: vm.included,
                    focusedID: vm.focusedPodID,
                    canSelectMore: vm.canSelectMore,
                    isPowerOn: vm.isPowerOn,
                    onTap: { vm.toggle($0) }
                )
            }

            if !isExpanded {
                collapsedContent
            }

            if isExpanded {
                expandedContent
            }
            
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .disabled(!vm.isPowerOn)
        .opacity(vm.isPowerOn ? 1.0 : 0.45)
        .animation(.easeInOut(duration: 0.2), value: vm.isPowerOn)
        .onChange(of: vm.isPowerOn) { _, isOn in
            if !isOn && isExpanded {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                    isExpanded = false
                }
            }
        }
        .onChange(of: vm.included.count) { _, newCount in
            guard isExpanded, newCount <= 1 else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                isExpanded = false
            }
        }
    }

    private var header: some View {
        HStack {
//            Text("Pods")
//                .font(.subheadline.bold())

            Spacer()

            if vm.pods.count > 1 {
                Label(
                    isExpanded ? "Collapse" : "Expand",
                    systemImage: isExpanded ? "chevron.up" : "chevron.down"
                )
                .labelStyle(.iconOnly)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard vm.isPowerOn, vm.pods.count > 1 else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                isExpanded.toggle()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Pods")
        .accessibilityAddTraits(vm.isPowerOn && vm.pods.count > 1 ? .isButton : [])
    }

    @ViewBuilder
    private var collapsedContent: some View {
        if vm.included.isEmpty {
            Text("No active pods. Tap a pod to add.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(minHeight: UI.opacityRowHeight, alignment: .center)
                .accessibilityLabel("No scents added. Tap a pod to add a scent.")
        } else if let fid = vm.focusedPodID,
                  let pod = vm.pods.first(where: { $0.id == fid }) {
            ScentControllerStepper(
                focused: pod,
                value: bindingForCollapsedStepper(podID: fid)
            )
            .frame(minHeight: UI.opacityRowHeight, alignment: .center)
        } else {
            Spacer()
                .frame(minHeight: UI.opacityRowHeight)
        }
    }

    private var expandedContent: some View {
        VStack(spacing: 10) {
            ForEach(vm.pods, id: \.id) { pod in
                let isIncluded = vm.included.contains(pod.id)
                let displayed = displayedValue(for: pod.id)

                ScentControllerSlider(
                    name: pod.name,
                    color: isIncluded ? pod.color.color : .secondary.opacity(0.35),
                    displayed: displayed,
                    onChangeDisplayed: { newDisplayed in
                        applyExpandedSliderChange(newDisplayed, for: pod.id)
                    },
                    onFocusOrToggle: nil,
                    onRemove: nil,
                    showsPercentage: true,
                    isDimmed: !isIncluded
                )
            }
        }
    }

    private func bindingForCollapsedStepper(podID: UUID) -> Binding<Double> {
        Binding(
            get: { vm.opacities[podID] ?? 0 },
            set: { vm.setOpacity($0, for: podID) }
        )
    }

    private func displayedValue(for podID: UUID) -> Double {
        let effective = vm.opacities[podID] ?? 0
        let maxI = max(0.0001, AppConfig.maxIntensity)
        return min(1.0, max(0.0, effective / maxI))
    }

    private func applyExpandedSliderChange(_ displayed: Double, for podID: UUID) {
        let effective = max(0, min(1, displayed)) * AppConfig.maxIntensity
        let wasIncluded = vm.included.contains(podID)

        if effective <= 0.0001 {
            if wasIncluded {
                vm.toggle(podID)
            } else {
                vm.setOpacity(0, for: podID)
            }
            return
        }

        if !wasIncluded {
            vm.toggle(podID)
        }

        vm.setOpacity(effective, for: podID)
    }
}
