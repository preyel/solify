import SwiftUI

/// The big bold title at the top of each setup step.
struct StepTitle: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.largeTitle.bold())
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
    }
}

/// The row of dots at the top that shows which step you're on.
struct ProgressDots: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<total, id: \.self) { index in
                if index > 0 {
                    Rectangle()
                        .fill(index <= current ? Color.orange : Color(.systemGray5))
                        .frame(width: 28, height: 2)
                }
                Circle()
                    .fill(index <= current ? Color.orange : Color(.systemGray5))
                    .frame(width: 12, height: 12)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Step \(current + 1) of \(total)")
    }
}

/// A labeled dropdown, like the SPF and Water Resistance fields.
struct MenuField<Option>: View where Option: CaseIterable & Hashable & RawRepresentable, Option.RawValue == String {
    let title: String
    @Binding var selection: Option

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            Menu {
                Picker(title, selection: $selection) {
                    ForEach(Array(Option.allCases), id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
            } label: {
                HStack {
                    Text(selection.rawValue)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .fieldStyle()
            }
            .tint(.primary)
            .sensoryFeedback(.selection, trigger: selection)
        }
    }
}

extension View {
    /// The rounded, lightly orange box used behind the setup fields.
    func fieldStyle() -> some View {
        padding(.horizontal, 16)
            .frame(minHeight: 52)
            .background(Color.orange.opacity(0.08), in: .rect(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.orange.opacity(0.25))
            }
            .contentShape(.rect)
    }
}
