import SwiftUI

struct ControlPowerSection: View {
    @ObservedObject var vm: GradientWheelViewModel
    @ObservedObject var templatesService: TemplatesService

    let turnOffTimer: TurnOffTimerController
    let onPreviousTemplate: () -> Void
    let onNextTemplate: () -> Void

    var body: some View {
        PowerButtonRow(
            isOn: vm.isPowerOn,
            onToggle: togglePower,
            showsTemplateTransport: !templatesService.templates.isEmpty,
            canGoPrevious: vm.isUsingTemplate && templatesService.canGoPrevious,
            canGoNext: vm.isUsingTemplate && templatesService.canGoNext,
            onPrevious: onPreviousTemplate,
            onNext: onNextTemplate,
            turnOffTimer: turnOffTimer,
            onStartTurnOffTimer: startTurnOffTimer,
            onCancelTurnOffTimer: turnOffTimer.clear
        )
        .onChange(of: vm.isPowerOn) { _, isOn in
            if !isOn {
                turnOffTimer.clear()
            }
        }
    }

    private func togglePower() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            vm.togglePower()
        }
    }

    private func startTurnOffTimer(duration: TimeInterval) {
        turnOffTimer.start(duration: duration) {
            if vm.isPowerOn {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                    vm.setPower(false)
                }
            }
        }
    }
}
