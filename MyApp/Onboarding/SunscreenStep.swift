import SwiftUI

enum SPFLevel: String, CaseIterable {
    case low = "6–14 (Low)"
    case medium = "15–29 (Medium)"
    case high = "30–49 (High)"
    case veryHigh = "50+ (Very High)"

    /// Short form for sentences, like "SPF 50+".
    var shortName: String {
        switch self {
        case .low: "SPF 6–14"
        case .medium: "SPF 15–29"
        case .high: "SPF 30–49"
        case .veryHigh: "SPF 50+"
        }
    }
}

enum WaterResistance: String, CaseIterable {
    case none = "None"
    case minutes40 = "40 mins"
    case minutes80 = "80 mins"
}

/// Step 3: "Your sunscreen"
struct SunscreenStep: View {
    @AppStorage(StorageKey.spf) private var spf = SPFLevel.veryHigh
    @AppStorage(StorageKey.waterResistance) private var waterResistance = WaterResistance.minutes80

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            StepTitle("Your sunscreen")

            MenuField(title: "SPF", selection: $spf)
            MenuField(title: "Water Resistance", selection: $waterResistance)
        }
        .padding(.horizontal, 24)
        .padding(.top, 32)
    }
}

#Preview {
    SunscreenStep()
}
