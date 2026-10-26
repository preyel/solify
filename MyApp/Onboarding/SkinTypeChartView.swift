import SwiftUI

/// The chart that slides up from "Fitzpatrick Skin Type".
/// Tapping a card picks that skin type and closes the chart.
struct SkinTypeChartView: View {
    @Binding var selection: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                    GridRow { cards(for: SkinType.all[0..<3]) }
                    GridRow { cards(for: SkinType.all[3..<6]) }
                }
                .padding()

                Text("Tap a type to choose it.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.bottom)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Fitzpatrick Skin Types")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
        }
    }

    private func cards(for types: ArraySlice<SkinType>) -> some View {
        ForEach(types) { type in
            Button {
                selection = type.id
                dismiss()
            } label: {
                card(for: type)
            }
            .buttonStyle(.plain)
        }
    }

    private func card(for type: SkinType) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(type.color)
                .frame(height: 70)

            VStack(spacing: 8) {
                Text("Type \(type.numeral)")
                    .font(.headline)
                Text(type.shade)
                    .font(.caption.weight(.semibold))
                Divider()
                Text(type.traits)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .padding(10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.orange, lineWidth: type.id == selection ? 3 : 0)
        }
    }
}

#Preview {
    SkinTypeChartView(selection: .constant(3))
}
