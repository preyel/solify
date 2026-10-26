import SwiftUI

/// "Nice! You're protected." Shown right after applying or reapplying.
struct ProtectedView: View {
    @AppStorage(StorageKey.lastAppliedAt) private var lastAppliedAt: Double = 0
    @AppStorage(StorageKey.notificationsEnabled) private var notificationsEnabled = true
    @AppStorage(StorageKey.reapplyPlan) private var planData: Data?
    @Environment(\.dismiss) private var dismiss

    @State private var hasAppeared = false

    private static let sunSafetyURL = URL(string: "https://www.aad.org/public/everyday-care/sun-protection")!

    var body: some View {
        TimelineView(.everyMinute) { _ in
            let wearsOff = Date(timeIntervalSince1970: lastAppliedAt).addingTimeInterval(Reminders.reapplyInterval)
            let plan = ReapplyPlan.decode(planData).flatMap { $0.isFor(appliedAt: Date(timeIntervalSince1970: lastAppliedAt)) ? $0 : nil }

            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 110, weight: .light))
                        .foregroundStyle(.green)
                        .symbolEffect(.bounce, value: hasAppeared)
                        .accessibilityHidden(true)

                    Text("Nice! You’re protected.")
                        .font(.title2.bold())

                    InfoTile(title: "Protection Remaining", value: remainingText(until: wearsOff))
                    if notificationsEnabled, let plan {
                        InfoTile(title: "Next Reminder",
                                 value: plan.fireDate?.formatted(date: .omitted, time: .shortened) ?? "Tomorrow")
                        if let reason = plan.reason {
                            Label {
                                Text(reason)
                                    .font(.subheadline)
                                    .fixedSize(horizontal: false, vertical: true)
                            } icon: {
                                Image(systemName: plan.symbol)
                                    .foregroundStyle(.teal)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        InfoTile(title: "Reapply By", value: wearsOff.formatted(date: .omitted, time: .shortened))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                Button {
                    dismiss()
                } label: {
                    Text("Great!")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 16))
                .controlSize(.extraLarge)
                .tint(.green)

                Link("Learn more about sun safety", destination: Self.sunSafetyURL)
                    .foregroundStyle(.primary)
                    .frame(minHeight: 44)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
        .sensoryFeedback(.success, trigger: hasAppeared)
        .onAppear { hasAppeared = true }
    }

    /// Like "2h 00m".
    private func remainingText(until date: Date) -> String {
        let totalMinutes = Int((max(0, date.timeIntervalSinceNow) / 60).rounded(.up))
        return String(format: "%dh %02dm", totalMinutes / 60, totalMinutes % 60)
    }
}

/// A light teal box with a small label and a big number.
private struct InfoTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 48, weight: .semibold, design: .rounded))
                .foregroundStyle(.teal)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.teal.opacity(0.12), in: .rect(cornerRadius: 18))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        ProtectedView()
    }
}
