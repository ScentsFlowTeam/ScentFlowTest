//
//  NewTemplateDialog.swift
//  MeshGradient
//
//  A custom "New Template" naming dialog that matches the app's dark control
//  aesthetic (thickMaterial + white-on-dark), forced to a dark appearance so it
//  doesn't follow the system Light/Dark mode like the default `.alert` does.
//

import SwiftUI

struct NewTemplateDialog: View {
    @Binding var isPresented: Bool
    @Binding var name: String
    let onCreate: (String) -> Void

    @FocusState private var fieldFocused: Bool

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ZStack {
            // Dimmed scrim; tap outside to dismiss.
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { dismiss() }

            card
                .padding(.horizontal, 32)
        }
        .environment(\.colorScheme, .dark)
        .onAppear { fieldFocused = true }
    }

    private var card: some View {
        VStack(spacing: 18) {
            VStack(spacing: 4) {
                Text("New Template")
                    .font(.headline)
                Text("Name your scent mix.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            TextField("Template name", text: $name)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
                .focused($fieldFocused)
                .submitLabel(.done)
                .onSubmit(create)
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.10))
                )

            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.10))
                    )
                    .foregroundStyle(.white)

                Button("Create", action: create)
                    .disabled(trimmedName.isEmpty)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(trimmedName.isEmpty ? 0.05 : 0.18))
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(.white.opacity(trimmedName.isEmpty ? 0.15 : 0.85), lineWidth: 1)
                    }
                    .foregroundStyle(.white)
                    .opacity(trimmedName.isEmpty ? 0.5 : 1)
            }
            .font(.body.weight(.semibold))
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(maxWidth: 340)
        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
    }

    private func create() {
        guard !trimmedName.isEmpty else { return }
        onCreate(trimmedName)
        dismiss()
    }

    private func dismiss() {
        fieldFocused = false
        isPresented = false
    }
}
