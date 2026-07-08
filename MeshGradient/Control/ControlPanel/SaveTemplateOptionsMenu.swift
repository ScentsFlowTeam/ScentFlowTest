import SwiftUI

struct SaveTemplateOptionsMenu: View {
    let sourceTemplate: ScentsTemplate
    let onUpdate: () -> Void
    let onSaveAsNew: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            saveOptionButton("Update \(sourceTemplate.name)", action: onUpdate)
            saveOptionButton("Save as New Template", action: onSaveAsNew)
        }
        .buttonStyle(.plain)
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private func saveOptionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
        }
    }
}
