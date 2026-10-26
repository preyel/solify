import Foundation

enum Temperature {
    /// Like "104°F" or "40°C", depending on the phone's region.
    static func text(celsius: Double) -> String {
        Measurement(value: celsius, unit: UnitTemperature.celsius)
            .formatted(.measurement(width: .abbreviated, usage: .weather, numberFormatStyle: .number.precision(.fractionLength(0))))
    }
}
