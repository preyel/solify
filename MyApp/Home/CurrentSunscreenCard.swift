import SwiftUI

struct CurrentSunscreenCard: View {
    let spf: SPFLevel
    let appliedAt: Date?

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "drop.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(Color.orange.gradient, in: .rect(cornerRadius: 12))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Current Sunscreen")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("SPF \(spf.rawValue)")
                    .font(.headline)
                Text(appliedText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
    }

    private var appliedText: String {
        guard let appliedAt else { return "Not applied yet today" }
        return "Applied at \(appliedAt.formatted(date: .omitted, time: .shortened))"
    }
}

#Preview {
    CurrentSunscreenCard(spf: .veryHigh, appliedAt: .now)
        .padding()
}
