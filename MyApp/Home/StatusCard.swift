import SwiftUI

/// Shows whether you're protected right now, with a ring counting down to the next reapply.
struct StatusCard: View {
    let appliedAt: Date?
    /// When the next reminder goes off, and why.
    let plan: ReapplyPlan?
    let now: Date

    private var remaining: TimeInterval {
        guard let appliedAt else { return 0 }
        return max(0, appliedAt.addingTimeInterval(Reminders.reapplyInterval).timeIntervalSince(now))
    }

    private var isProtected: Bool { remaining > 0 }

    private var progress: Double { remaining / Reminders.reapplyInterval }

    private var remainingText: String {
        let totalMinutes = Int((remaining / 60).rounded(.up))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    private var subtitle: String {
        if let appliedAt, isProtected {
            let why = plan?.shortReason.map { " (\($0))" } ?? ""
            if let plan, plan.isPostponed { return "Next reminder: tomorrow morning\(why)" }
            let reminder = plan?.fireDate ?? appliedAt.addingTimeInterval(Reminders.reapplyInterval)
            return "Next reminder: \(reminder.formatted(date: .omitted, time: .shortened))\(why)"
        }
        return appliedAt == nil ? "Apply sunscreen to start your timer." : "Time to reapply!"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Status")
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Image(systemName: isProtected ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                    .font(.largeTitle)
                    .foregroundStyle(isProtected ? Color.teal : Color.red)
                    .contentTransition(.symbolEffect(.replace))

                VStack(alignment: .leading, spacing: 2) {
                    Text(isProtected ? "Protected" : "Not protected")
                        .font(.title2.bold())
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 16)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(progress < 0.15 ? Color.orange : Color.teal,
                            style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text(remainingText)
                        .font(.title.bold())
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("remaining")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 150, height: 150)
            .frame(maxWidth: .infinity)
            .animation(.smooth, value: progress)
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    StatusCard(
        appliedAt: .now.addingTimeInterval(-40 * 60),
        plan: ReapplyPlan(appliedAt: .now.addingTimeInterval(-40 * 60), fireDate: .now.addingTimeInterval(3600), change: .afterIndoors("School")),
        now: .now
    )
        .padding()
}
