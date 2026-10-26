#if DEBUG
import SwiftUI
import UserNotifications

/// Developer screen: every notification Solify has lined up, in time order.
struct ScheduledNotificationsView: View {
    private struct Item: Identifiable {
        let id: String
        let date: Date?
        let title: String
        let body: String
    }

    @State private var items: [Item] = []

    var body: some View {
        List {
            if items.isEmpty {
                ContentUnavailableView("Nothing Scheduled", systemImage: "bell.slash")
            }
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.date?.formatted(.dateTime.weekday(.abbreviated).hour().minute()) ?? "—")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                    Text(item.title).font(.subheadline.weight(.semibold))
                    Text(item.body).font(.caption).foregroundStyle(.secondary)
                    Text(item.id).font(.caption2).foregroundStyle(.tertiary)
                }
            }
        }
        .navigationTitle("Scheduled")
        .refreshable { await load() }
        .task { await load() }
    }

    private func load() async {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        items = requests.map { request in
            let date = (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()
                ?? (request.trigger as? UNTimeIntervalNotificationTrigger)?.nextTriggerDate()
            return Item(id: request.identifier, date: date, title: request.content.title, body: request.content.body)
        }
        .sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
    }
}
#endif
