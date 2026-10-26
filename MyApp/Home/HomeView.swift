import SwiftUI

struct HomeView: View {
    @AppStorage(StorageKey.lastAppliedAt) private var lastAppliedAt: Double = 0
    @AppStorage(StorageKey.spf) private var defaultSPF = SPFLevel.veryHigh
    @AppStorage(StorageKey.waterResistance) private var defaultWaterResistance = WaterResistance.minutes80
    @AppStorage(StorageKey.appliedSPF) private var appliedSPF = SPFLevel.veryHigh
    @AppStorage(StorageKey.appliedWaterResistance) private var appliedWaterResistance = WaterResistance.minutes80
    @AppStorage(StorageKey.notificationsEnabled) private var notificationsEnabled = true
    @AppStorage(StorageKey.reapplyPlan) private var planData: Data?
    @AppStorage(StorageKey.userName) private var userName = ""

    @State private var openSheet: HomeSheet?
    @State private var toast: Toast?
    /// A toast to show once the open sheet closes.
    @State private var pendingToast: Toast?

    /// The screens that slide up from the 3 orange buttons.
    private enum HomeSheet: Identifiable {
        case apply, reapplied, change
        var id: Self { self }
    }

    @Environment(WeatherStore.self) private var weather

    /// When sunscreen was last put on today, or nil if it hasn't been yet.
    private var appliedAt: Date? {
        guard lastAppliedAt > 0 else { return nil }
        let date = Date(timeIntervalSince1970: lastAppliedAt)
        return Calendar.current.isDateInToday(date) ? date : nil
    }

    /// When the next reminder goes off and why (only for sunscreen put on today).
    private var plan: ReapplyPlan? {
        guard let plan = ReapplyPlan.decode(planData), let appliedAt, plan.isFor(appliedAt: appliedAt) else { return nil }
        return plan
    }

    // The sunscreen on your skin right now: whatever was used last today, otherwise your default.
    private var currentSPF: SPFLevel { appliedAt == nil ? defaultSPF : appliedSPF }
    private var currentWaterResistance: WaterResistance { appliedAt == nil ? defaultWaterResistance : appliedWaterResistance }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    header
                    // Redraws once a minute so the UV and countdown stay current.
                    TimelineView(.everyMinute) { _ in
                        HomeUVCard()
                        StatusCard(appliedAt: appliedAt, plan: plan, now: .now)
                    }
                    CurrentSunscreenCard(spf: currentSPF, appliedAt: appliedAt)
                    actionButtons
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .toolbarVisibility(.hidden, for: .navigationBar)
            .task { await weather.refreshIfNeeded() }
            .toast($toast)
            .sheet(item: $openSheet, onDismiss: showPendingToast) { sheet in
                switch sheet {
                case .apply:
                    ApplySunscreenView(onApplied: { plan in
                        pendingToast = plan.change == .none ? .applied : .reminderSet(plan: plan, notificationsOn: notificationsEnabled)
                    })
                case .reapplied:
                    NavigationStack {
                        ProtectedView()
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Close", systemImage: "xmark") { openSheet = nil }
                                }
                            }
                    }
                case .change:
                    ChangeSunscreenView(onSaved: { pendingToast = .sunscreenUpdated })
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "sun.max.fill")
                .font(.title)
                .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom))
                .accessibilityHidden(true)

            Text(greeting)
                .font(.title2.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer()

            Button(action: toggleReminders) {
                Image(systemName: notificationsEnabled ? "bell.fill" : "bell.slash")
                    .font(.title3)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(notificationsEnabled ? "Turn off reminders" : "Turn on reminders")
        }

    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let timeOfDay = switch hour {
        case 5..<12: "Good Morning"
        case 12..<17: "Good Afternoon"
        default: "Good Evening"
        }
        return userName.isEmpty ? "\(timeOfDay)!" : "\(timeOfDay), \(userName)!"
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            HomeActionButton(title: "Apply Sunscreen", systemImage: "sun.max") {
                openSheet = .apply
            }
            HomeActionButton(title: "Reapplied Now", systemImage: "checkmark.circle") {
                // Skip the form and restart the timer with the default sunscreen.
                let plan = SunscreenLog.recordApplication(spf: defaultSPF, waterResistance: defaultWaterResistance)
                pendingToast = .reminderSet(plan: plan, notificationsOn: notificationsEnabled)
                openSheet = .reapplied
            }
            HomeActionButton(title: "Change Sunscreen", systemImage: "arrow.triangle.2.circlepath") {
                openSheet = .change
            }
        }
    }

    private func showToast(_ newToast: Toast) {
        withAnimation(.snappy) { toast = newToast }
    }

    private func showPendingToast() {
        guard let pendingToast else { return }
        self.pendingToast = nil
        showToast(pendingToast)
    }

    private func toggleReminders() {
        if notificationsEnabled {
            notificationsEnabled = false
            Task { await Reminders.cancelAll() }
            showToast(.notificationsOff)
        } else {
            Task {
                let granted = await Reminders.requestPermission()
                notificationsEnabled = granted
                guard granted else {
                    showToast(.notificationsBlocked)
                    return
                }
                await Reminders.refreshAll()
                showToast(.notificationsOn)
            }
        }
    }
}

#Preview {
    HomeView()
        .tint(.orange)
}
