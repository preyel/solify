import SwiftUI

/// What a weather or reminder-change notification is about. It rides along inside the
/// notification, so tapping it can open the "Weather Update" screen with the full story.
struct WeatherUpdate: Codable, Identifiable, Equatable {
    enum Kind: String, Codable {
        case uvRising, skiesCleared, heat, rain, reminderEarlier, reminderLater, outdoorSoon, morning, reapply

        /// The title at the top of the screen.
        var screenTitle: String {
            switch self {
            case .morning: "Morning Briefing"
            case .reapply: "Time to Reapply"
            case .outdoorSoon: "Heads-Up"
            case .reminderEarlier, .reminderLater: "Reminder Update"
            default: "Weather Update"
            }
        }
    }

    /// A button the screen can offer besides "Got it!".
    enum Action: String, Codable {
        /// "I've Reapplied": restarts the protection timer.
        case reapply
    }

    var id = UUID()
    let kind: Kind
    /// Notification title, like "Skies just cleared."
    let title: String
    /// Notification text, like "UV is now Very High. Apply sunscreen before going outside."
    let body: String
    /// Big line on the Weather Update screen, like "UV is now 9 (Very High)".
    let headline: String
    /// Smaller line under it, like "Skies just cleared up in Chandler, AZ."
    let subtitle: String
    let why: String
    let whatToDo: String
    /// For coloring the icon by UV level.
    var uv: Int? = nil
    var action: Action? = nil

    var symbol: String {
        switch kind {
        case .uvRising: "sun.max.trianglebadge.exclamationmark.fill"
        case .skiesCleared: "sun.max.fill"
        case .heat: "thermometer.sun.fill"
        case .rain: "cloud.rain.fill"
        case .reminderEarlier: "alarm.fill"
        case .reminderLater: "clock.arrow.circlepath"
        case .outdoorSoon: "figure.run"
        case .morning: "sunrise.fill"
        case .reapply: "drop.fill"
        }
    }

    var color: Color {
        switch kind {
        case .uvRising, .skiesCleared, .morning, .reapply: uv.map { UVReading(index: $0).level.color } ?? .orange
        case .heat: .red
        case .rain: .blue
        case .reminderEarlier, .reminderLater, .outdoorSoon: .teal
        }
    }

    // Packing into / unpacking from a notification.

    nonisolated static let userInfoKey = "weatherUpdate"

    var userInfo: [AnyHashable: Any] {
        guard let data = try? JSONEncoder().encode(self), let json = String(data: data, encoding: .utf8) else { return [:] }
        return [Self.userInfoKey: json]
    }

    static func from(json: String?) -> WeatherUpdate? {
        guard let data = json?.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(WeatherUpdate.self, from: data)
    }
}

/// Remembers which Weather Update to show after tapping a notification.
@Observable
final class AppRouter {
    static let shared = AppRouter()
    var weatherUpdate: WeatherUpdate?
    private init() {}
}

/// The "Weather Update" screen that opens when a weather notification is tapped.
struct WeatherUpdateView: View {
    let update: WeatherUpdate
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: update.symbol)
                        .font(.system(size: 56, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 120, height: 120)
                        .background(update.color.gradient, in: .circle)
                        .symbolEffect(.bounce, options: .nonRepeating)
                        .accessibilityHidden(true)
                        .padding(.top, 8)

                    VStack(spacing: 6) {
                        Text(update.headline)
                            .font(.title2.bold())
                        Text(update.subtitle)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.center)

                    VStack(alignment: .leading, spacing: 16) {
                        section("Why you’re seeing this", systemImage: "info.circle.fill", text: update.why)
                        Divider()
                        section("What to do", systemImage: "checkmark.circle.fill", text: update.whatToDo)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.1), in: .rect(cornerRadius: 20))
                }
                .padding(.horizontal, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    if update.action == .reapply {
                        Button("I’ve Reapplied", systemImage: "checkmark.circle.fill", action: reapply)
                            .buttonStyle(OrangeButtonStyle())
                        Button("Not Now") { dismiss() }
                            .foregroundStyle(.primary)
                            .frame(minHeight: 44)
                    } else {
                        Button("Got it!") { dismiss() }
                            .buttonStyle(OrangeButtonStyle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            }
            .navigationTitle(update.kind.screenTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
        }
    }

    /// Same as "Reapplied Now" on Home: restarts the timer with the default sunscreen.
    private func reapply() {
        let defaults = UserDefaults.standard
        SunscreenLog.recordApplication(
            spf: defaults.string(forKey: StorageKey.spf).flatMap(SPFLevel.init) ?? .veryHigh,
            waterResistance: defaults.string(forKey: StorageKey.waterResistance).flatMap(WaterResistance.init) ?? .minutes80
        )
        dismiss()
    }

    private func section(_ title: String, systemImage: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
            Text(text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    WeatherUpdateView(update: WeatherUpdate(
        kind: .skiesCleared,
        title: "Skies just cleared.",
        body: "UV is now Very High. Apply sunscreen before going outside.",
        headline: "UV is now 9 (Very High)",
        subtitle: "Skies just cleared up in Chandler, AZ.",
        why: "Cloud cover has decreased, causing UV levels to rise quickly.",
        whatToDo: "Reapply sunscreen before spending time outdoors.",
        uv: 9
    ))
    .tint(.orange)
}
