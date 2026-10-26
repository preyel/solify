import Foundation

/// Names for everything the app saves on the phone with @AppStorage.
/// Using these instead of typing the strings avoids typos.
enum StorageKey {
    static let hasSeenWelcome = "hasSeenWelcome"
    static let skinType = "skinType"
    static let spf = "spf"
    static let waterResistance = "waterResistance"
    static let wakeUpMinutes = "wakeUpMinutes"
    static let bedtimeMinutes = "bedtimeMinutes"
    /// The school / work / outdoor times from Profile (JSON).
    static let routineBlocks = "routineBlocks"
    /// When the next reapply reminder will go off, and why (JSON).
    static let reapplyPlan = "reapplyPlan"
    static let hoursOutdoors = "hoursOutdoors"
    static let notificationsEnabled = "notificationsEnabled"
    static let lastAppliedAt = "lastAppliedAt"
    /// The sunscreen used at `lastAppliedAt`. Can differ from the saved default (`spf` / `waterResistance`).
    static let appliedSPF = "appliedSPF"
    static let appliedWaterResistance = "appliedWaterResistance"
    static let userName = "userName"
    /// Settings.
    static let strictProtection = "strictProtection"
    static let pauseDuringActivities = "pauseDuringActivities"
    static let morningBriefingEnabled = "morningBriefingEnabled"
    static let weatherAlertsEnabled = "weatherAlertsEnabled"
}
