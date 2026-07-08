import SwiftUI

struct ControlTransportSection: View {
    @ObservedObject var runtime: DeviceRuntime
    @ObservedObject var templatesService: TemplatesService

    let listButtonBounceToken: Int
    let onPreviousTemplate: () -> Void
    let onNextTemplate: () -> Void
    let onOpenTemplateList: () -> Void

    var body: some View {
        TransportButtonRow(
            isOn: runtime.isPowerOn,
            onToggle: togglePower,
            showsTemplateTransport: !templatesService.templates.isEmpty,
            canGoPrevious: runtime.isUsingTemplate && templatesService.canGoPrevious,
            canGoNext: runtime.isUsingTemplate && templatesService.canGoNext,
            listButtonBounceToken: listButtonBounceToken,
            onPrevious: onPreviousTemplate,
            onNext: onNextTemplate,
            onOpenTemplateList: onOpenTemplateList
        )
    }

    private func togglePower() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            runtime.togglePower()
        }
    }
}
