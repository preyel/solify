import SwiftUI

/// A UV index reading, like 8, plus which danger level that is.
nonisolated struct UVReading {
    let index: Int

    init(index: Int) {
        self.index = index
    }

    /// Weather data gives UV with decimals (like 7.85); people see it rounded.
    init(uv: Double) {
        self.index = Int(uv.rounded())
    }

    var level: Level {
        switch index {
        case ..<3: .low
        case 3..<6: .moderate
        case 6..<8: .high
        case 8..<11: .veryHigh
        default: .extreme
        }
    }

    /// The standard UV levels and their usual colors.
    enum Level: CaseIterable, Identifiable {
        case low, moderate, high, veryHigh, extreme

        var id: Self { self }

        var name: String {
            switch self {
            case .low: "Low"
            case .moderate: "Moderate"
            case .high: "High"
            case .veryHigh: "Very High"
            case .extreme: "Extreme"
            }
        }

        /// Like "3–5", for the UV Index Guide.
        var rangeLabel: String {
            switch self {
            case .low: "0–2"
            case .moderate: "3–5"
            case .high: "6–7"
            case .veryHigh: "8–10"
            case .extreme: "11+"
            }
        }

        /// Where this level's colored band starts and ends on the charts.
        var chartBounds: (lower: Double, upper: Double) {
            switch self {
            case .low: (0, 2.5)
            case .moderate: (2.5, 5.5)
            case .high: (5.5, 7.5)
            case .veryHigh: (7.5, 10.5)
            case .extreme: (10.5, 30)
            }
        }

        var color: Color {
            switch self {
            case .low: Color(red: 0.2, green: 0.6, blue: 0.3)
            case .moderate: Color(red: 1.0, green: 0.8, blue: 0.0)
            case .high: .orange
            case .veryHigh: .red
            case .extreme: .purple
            }
        }

        /// A darker version for big numbers, so they're easy to read on the light cards.
        /// Yellow gets a golden amber instead of just darkening, which would turn it brown.
        var textColor: Color {
            switch self {
            case .moderate: Color(red: 0.95, green: 0.6, blue: 0.0)
            default: color.mix(with: .black, by: 0.25)
            }
        }
    }
}
