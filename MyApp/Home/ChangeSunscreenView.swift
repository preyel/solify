import SwiftUI

/// Opened from "Change Sunscreen". "Confirm" makes the picks the new saved sunscreen.
struct ChangeSunscreenView: View {
    @AppStorage(StorageKey.spf) private var savedSPF = SPFLevel.veryHigh
    @AppStorage(StorageKey.waterResistance) private var savedWaterResistance = WaterResistance.minutes80
    @Environment(\.dismiss) private var dismiss

    /// Called after tapping "Confirm".
    var onSaved: () -> Void = {}

    @State private var spf = SPFLevel.veryHigh
    @State private var waterResistance = WaterResistance.minutes80

    var body: some View {
        NavigationStack {
            ScrollView {
                SunscreenForm(prompt: "Select the settings of your new sunscreen", spf: $spf, waterResistance: $waterResistance)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .bottom) {
                SheetButtons(title: "Confirm", action: confirm, cancel: { dismiss() })
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
                    .background(.background)
            }
            .navigationTitle("Change Sunscreen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .onAppear {
            spf = savedSPF
            waterResistance = savedWaterResistance
        }
    }

    private func confirm() {
        savedSPF = spf
        savedWaterResistance = waterResistance
        // The morning briefings mention your SPF, so update them.
        Task { await Reminders.refreshAll() }
        onSaved()
        dismiss()
    }
}

#Preview {
    ChangeSunscreenView()
        .tint(.orange)
}
