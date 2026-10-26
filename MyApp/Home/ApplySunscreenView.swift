import SwiftUI

/// Opened from "Apply Sunscreen". Starts out with the saved default sunscreen picked.
/// Picking a different one only applies this once and doesn't change the default.
struct ApplySunscreenView: View {
    @AppStorage(StorageKey.spf) private var savedSPF = SPFLevel.veryHigh
    @AppStorage(StorageKey.waterResistance) private var savedWaterResistance = WaterResistance.minutes80
    @Environment(\.dismiss) private var dismiss

    /// Called after tapping "I've Applied", with when the reminder will go off.
    var onApplied: (ReapplyPlan) -> Void = { _ in }

    @State private var spf = SPFLevel.veryHigh
    @State private var waterResistance = WaterResistance.minutes80
    @State private var hasApplied = false
    @State private var isShowingInfo = false

    var body: some View {
        NavigationStack {
            Group {
                if hasApplied {
                    ProtectedView()
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                } else {
                    form
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
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

    private var form: some View {
        ScrollView {
            SunscreenForm(prompt: "Select the sunscreen you’re using", spf: $spf, waterResistance: $waterResistance)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 4) {
                SheetButtons(title: "I’ve Applied", action: apply, cancel: { dismiss() })

                HStack {
                    Text("Applying now will start your protection timer.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("About the timer", systemImage: "info.circle") {
                        isShowingInfo = true
                    }
                    .labelStyle(.iconOnly)
                    .font(.title3)
                    .popover(isPresented: $isShowingInfo) {
                        Text("Dermatologists recommend reapplying sunscreen at least every 2 hours, and right after swimming or sweating.")
                            .font(.subheadline)
                            .padding()
                            .frame(width: 280)
                            .presentationCompactAdaptation(.popover)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
            .background(.background)
        }
        .navigationTitle("Apply Sunscreen")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func apply() {
        // Only counts for this application; the default changes only from "Change Sunscreen".
        let plan = SunscreenLog.recordApplication(spf: spf, waterResistance: waterResistance)
        onApplied(plan)
        withAnimation(.smooth) { hasApplied = true }
    }
}

#Preview {
    ApplySunscreenView()
        .tint(.orange)
}
