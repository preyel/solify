import SwiftUI

/// The colorful card with a big UV number, like "Current UV Index 8 Very High".
struct UVIndexCard: View {
    let title: String
    let reading: UVReading
    /// Small gray line under the number, like the city name.
    var caption: String? = nil

    var body: some View {
        let level = reading.level

        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)

                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("\(reading.index)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(level.textColor)
                        .contentTransition(.numericText())
                    Text(level.name)
                        .font(.title3.weight(.semibold))
                }

                if let caption {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "sun.max")
                .font(.system(size: 52))
                .foregroundStyle(Color.orange.mix(with: .red, by: 0.15))
                .accessibilityHidden(true)
        }
        .cardStyle(LinearGradient(
            colors: [level.color.opacity(0.45), Color.orange.opacity(0.3)],
            startPoint: .leading,
            endPoint: .trailing
        ))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    UVIndexCard(title: "Current UV Index", reading: UVReading(index: 8), caption: "Chandler, AZ")
        .padding()
}
