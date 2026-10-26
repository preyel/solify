import BackgroundTasks
import SwiftUI
import UserNotifications

@main struct MyApp: App {
    @AppStorage(StorageKey.hasSeenWelcome) private var hasSeenWelcome = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var router = AppRouter.shared

    /// Must match `BGTaskSchedulerPermittedIdentifiers` in Info.plist.
    nonisolated static let backgroundRefreshID = "com.prek.Solify.refresh"

    init() {
        #if DEBUG
        DebugScenarios.runIfRequested()
        #endif
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasSeenWelcome {
                    ContentView()
                } else {
                    WelcomeView()
                }
            }
            .tint(.orange)
            .environment(WeatherStore.shared)
            // Tapping a weather notification opens its Weather Update screen.
            .sheet(item: $router.weatherUpdate) { update in
                WeatherUpdateView(update: update)
                    .tint(.orange)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard hasSeenWelcome else { return }
            switch phase {
            case .active:
                // Get a fresh forecast if it's old, and line up the notifications again.
                Task {
                    await WeatherStore.shared.refreshIfNeeded()
                    await Reminders.refreshAll()
                }
            case .background:
                Task { await Self.scheduleBackgroundRefresh() }
            default:
                break
            }
        }
        // While the app is closed, iOS wakes it up now and then (when it decides it's a good
        // time, often about once an hour) to get new weather and move the reminders if needed.
        .backgroundTask(.appRefresh(Self.backgroundRefreshID)) {
            await Self.scheduleBackgroundRefresh()
            await WeatherStore.shared.refresh(updateLocation: false)
        }
    }

    nonisolated static func scheduleBackgroundRefresh() async {
        let request = BGAppRefreshTaskRequest(identifier: backgroundRefreshID)
        request.earliestBeginDate = .now.addingTimeInterval(60 * 60)
        try? await BGTaskScheduler.shared.submitTaskRequest(request)
    }
}
