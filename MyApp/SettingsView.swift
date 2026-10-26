import SwiftUI

struct SettingsView: View {
    @AppStorage(StorageKey.notificationsEnabled) private var notificationsEnabled = true
    @AppStorage(StorageKey.strictProtection) private var strictProtection = false
    @AppStorage(StorageKey.pauseDuringActivities) private var pauseDuringActivities = false
    @AppStorage(StorageKey.morningBriefingEnabled) private var morningBriefing = true
    @AppStorage(StorageKey.weatherAlertsEnabled) private var weatherAlerts = true
    @AppStorage(StorageKey.spf) private var spf = SPFLevel.veryHigh
    @AppStorage(StorageKey.waterResistance) private var waterResistance = WaterResistance.minutes80
    @AppStorage(StorageKey.hasSeenWelcome) private var hasSeenWelcome = true

    @Environment(WeatherStore.self) private var weather
    @State private var isShowingStrictInfo = false
    @State private var isShowingPauseInfo = false
    @State private var isChangingSunscreen = false
    @State private var isPickingLocation = false
    @State private var isConfirmingRedoSetup = false

    private static let openMeteoURL = URL(string: "https://open-meteo.com")!

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle(isOn: $notificationsEnabled) {
                        rowLabel("Notifications", systemImage: "bell.fill", color: .orange)
                    }
                    Toggle(isOn: $morningBriefing) {
                        rowLabel("Morning Briefing", systemImage: "sunrise.fill", color: .orange)
                    }
                    .disabled(!notificationsEnabled)
                    Toggle(isOn: $weatherAlerts) {
                        rowLabel("Weather Alerts", systemImage: "cloud.sun.fill", color: .blue)
                    }
                    .disabled(!notificationsEnabled)
                } header: {
                    Text("Reminders")
                } footer: {
                    Text("Weather alerts let you know when skies clear, UV jumps, it gets very hot, or rain moves in.")
                }

                Section {
                    infoToggleRow("Strict Protection", systemImage: "shield.lefthalf.filled", color: .teal,
                                  isOn: $strictProtection, isShowingInfo: $isShowingStrictInfo) { strictInfo }
                    infoToggleRow("Pause During Activities", systemImage: "pause.circle.fill", color: .orange,
                                  isOn: $pauseDuringActivities, isShowingInfo: $isShowingPauseInfo) { pauseInfo }
                } header: {
                    Text("Reminder Timing")
                } footer: {
                    Text(timingFooter)
                }

                Section {
                    Button { isChangingSunscreen = true } label: {
                        valueRow("Sunscreen", systemImage: "drop.fill", color: .orange,
                                 value: "\(spf.shortName) · \(waterResistance == .none ? "No water res." : waterResistance.rawValue)")
                    }
                    .tint(.primary)
                    Button { isPickingLocation = true } label: {
                        valueRow("Forecast Location", systemImage: weather.location?.isCurrent == true ? "location.fill" : "mappin.and.ellipse",
                                 color: .blue, value: weather.location?.name ?? "Not set")
                    }
                    .tint(.primary)
                } header: {
                    Text("Sunscreen & Location")
                } footer: {
                    Text("Your default sunscreen is used for Reapplied Now and your reminders.")
                }

                Section {
                    Button("Redo Setup", systemImage: "arrow.counterclockwise") {
                        isConfirmingRedoSetup = true
                    }
                } footer: {
                    Text("Goes through the welcome steps again. Your profile and reminders stay the same.")
                }

                Section("About") {
                    Link(destination: Self.openMeteoURL) {
                        valueRow("Weather Data", systemImage: "cloud.fill", color: .gray, value: "Open-Meteo.com")
                    }
                    .tint(.primary)
                    LabeledContent {
                        Text(appVersion)
                    } label: {
                        rowLabel("Version", systemImage: "info.circle.fill", color: .gray)
                    }
                }

                #if DEBUG
                // Only shows up when running from Xcode, never in the App Store version.
                Section {
                    Button("Send Test Notifications", systemImage: "bell.badge") {
                        Task { await Reminders.sendTestNotifications() }
                    }
                    NavigationLink {
                        ScheduledNotificationsView()
                    } label: {
                        Label("Scheduled Notifications", systemImage: "list.bullet.clipboard")
                    }
                } header: {
                    Text("Developer")
                } footer: {
                    Text("Sends your morning briefing, outdoor-activity heads-up, reapply reminder and a weather alert, 8 seconds apart, using your real routine, sunscreen and forecast. Tap any of them to open its screen in the app. Lock the phone (⌘L in the Simulator) to see them on the Lock Screen.")
                }
                #endif
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $isChangingSunscreen) { ChangeSunscreenView() }
            .sheet(isPresented: $isPickingLocation) { LocationPicker() }
            .confirmationDialog("Redo setup?", isPresented: $isConfirmingRedoSetup, titleVisibility: .visible) {
                Button("Redo Setup") { withAnimation { hasSeenWelcome = false } }
            }
            .onChange(of: notificationsEnabled) { _, isOn in
                Task {
                    if isOn { notificationsEnabled = await Reminders.requestPermission() }
                    await Reminders.refreshAll()
                }
            }
            .onChange(of: strictProtection) { Task { await Reminders.refreshAll() } }
            .onChange(of: pauseDuringActivities) { Task { await Reminders.refreshAll() } }
            .onChange(of: morningBriefing) { Task { await Reminders.refreshAll() } }
            .onChange(of: weatherAlerts) { Task { await Reminders.refreshAll() } }
            .sensoryFeedback(.selection, trigger: strictProtection)
        }
    }

    /// The little explanation that pops up from the ⓘ next to Strict Protection.
    private var strictInfo: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Strict Protection", systemImage: "shield.lefthalf.filled")
                .font(.headline)
                .foregroundStyle(.teal)
            Text("Normally, if UV stays low (3 or below) near sunset, your reminder moves to tomorrow.")
            Text("With Strict Protection on, it only moves once UV is 0 for the rest of the day.")
            Text("Why? The UV index mostly measures UVB, which causes sunburn. UVA rays are there whenever it’s light out, even when the UV index is low, and they can cause dark spots (hyperpigmentation) and early skin aging.")
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
        .fixedSize(horizontal: false, vertical: true)
        .padding()
        .frame(width: 300)
    }

    /// The little explanation that pops up from the ⓘ next to Pause During Activities.
    private var pauseInfo: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Pause During Activities", systemImage: "pause.circle.fill")
                .font(.headline)
                .foregroundStyle(.orange)
            Text("If a reminder would go off in the middle of an outdoor activity (like tennis practice), it waits until the activity ends, the same way it waits for school or work.")
            Text("If the activity ends near sunset and UV is low, the reminder moves to tomorrow instead, unless Strict Protection is on.")
            Text("Tip: you’re in the sun the whole time, so it’s best to put on water-resistant sunscreen before you start.")
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
        .fixedSize(horizontal: false, vertical: true)
        .padding()
        .frame(width: 300)
    }

    private var timingFooter: String {
        let strict = strictProtection
            ? "Strict Protection is on: reminders only move to tomorrow once UV reaches 0."
            : "Reminders can move to tomorrow near sunset when UV is 3 or below."
        let pause = pauseDuringActivities
            ? " Reminders wait until outdoor activities end."
            : ""
        return strict + pause
    }

    /// A switch with an ⓘ next to its name that opens a little explanation.
    private func infoToggleRow<Info: View>(
        _ title: String, systemImage: String, color: Color,
        isOn: Binding<Bool>, isShowingInfo: Binding<Bool>,
        @ViewBuilder info: () -> Info
    ) -> some View {
        let infoView = info()
        return HStack(spacing: 6) {
            rowLabel(title, systemImage: systemImage, color: color)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Button("About \(title)", systemImage: "info.circle") {
                isShowingInfo.wrappedValue = true
            }
            .labelStyle(.iconOnly)
            .foregroundStyle(.orange)
            .buttonStyle(.borderless)
            .popover(isPresented: isShowingInfo) {
                infoView
                    .presentationCompactAdaptation(.popover)
            }
            Spacer()
            Toggle(title, isOn: isOn)
                .labelsHidden()
                .tint(.teal)
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private func rowLabel(_ title: String, systemImage: String, color: Color) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(color.gradient, in: .rect(cornerRadius: 7))
        }
    }

    private func valueRow(_ title: String, systemImage: String, color: Color, value: String) -> some View {
        HStack {
            rowLabel(title, systemImage: systemImage, color: color)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .layoutPriority(1)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }
}

#Preview {
    SettingsView()
        .environment(WeatherStore.shared)
        .tint(.orange)
}
