import SwiftUI

/// Step 2: "What's your skin type?"
struct SkinTypeStep: View {
    @AppStorage(StorageKey.skinType) private var skinType = 0
    @State private var isShowingChart = false

    private var selectedType: SkinType? {
        SkinType.all.first { $0.id == skinType }
    }

    var body: some View {
        VStack(spacing: 16) {
            StepTitle("What’s your skin type?")

            Button("Fitzpatrick Skin Type", systemImage: "info.circle") {
                isShowingChart = true
            }
            .font(.subheadline.weight(.medium))

            HStack(spacing: 10) {
                ForEach(SkinType.all) { type in
                    swatch(for: type)
                }
            }
            .padding(.top, 24)

            if let selectedType {
                VStack(spacing: 4) {
                    Text("Type \(selectedType.numeral) · \(selectedType.shade)")
                        .font(.headline)
                    Text(selectedType.traits)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .padding(.top, 8)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 32)
        .sensoryFeedback(.selection, trigger: skinType)
        .sheet(isPresented: $isShowingChart) {
            SkinTypeChartView(selection: $skinType)
        }
    }

    private func swatch(for type: SkinType) -> some View {
        let isSelected = type.id == skinType

        return Button {
            withAnimation(.snappy) { skinType = type.id }
        } label: {
            Circle()
                .fill(type.color.gradient)
                .overlay(Circle().strokeBorder(.black.opacity(0.1)))
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.headline.bold())
                            .foregroundStyle(type.id <= 3 ? Color.black : Color.white)
                    }
                }
                .padding(3)
                .overlay(Circle().strokeBorder(Color.orange, lineWidth: isSelected ? 3 : 0))
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Type \(type.numeral), \(type.shade)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    SkinTypeStep()
}
