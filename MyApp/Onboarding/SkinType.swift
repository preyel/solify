import SwiftUI

/// The 6 Fitzpatrick skin types. `id` (1–6) is what gets saved.
struct SkinType: Identifiable {
    let id: Int
    let numeral: String
    let color: Color
    let shade: String
    let traits: String

    static let all: [SkinType] = [
        SkinType(id: 1, numeral: "I", color: Color(red: 0.99, green: 0.90, blue: 0.85),
                 shade: "Ivory", traits: "Always freckles, always burns or peels, never tans"),
        SkinType(id: 2, numeral: "II", color: Color(red: 0.94, green: 0.82, blue: 0.66),
                 shade: "Pale or fair", traits: "Usually freckles, often burns or peels, rarely tans"),
        SkinType(id: 3, numeral: "III", color: Color(red: 0.84, green: 0.66, blue: 0.49),
                 shade: "Fair to beige", traits: "Might freckle, burns on occasion, sometimes tans"),
        SkinType(id: 4, numeral: "IV", color: Color(red: 0.69, green: 0.45, blue: 0.35),
                 shade: "Olive or light brown", traits: "Doesn’t really freckle, rarely burns, often tans"),
        SkinType(id: 5, numeral: "V", color: Color(red: 0.43, green: 0.24, blue: 0.18),
                 shade: "Dark brown", traits: "Rarely freckles, almost never burns, always tans"),
        SkinType(id: 6, numeral: "VI", color: Color(red: 0.24, green: 0.14, blue: 0.09),
                 shade: "Deeply pigmented dark brown to darkest brown", traits: "Never freckles, never burns, always tans"),
    ]
}
