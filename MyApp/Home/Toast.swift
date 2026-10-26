import SwiftUI

/// A small message card that pops up above the tab bar, then goes away by itself.
struct Toast: Identifiable, Equatable {
    let id = UUID()
    let systemImage: String
    let title: String
    let message: String

    static let applied = Toast(
        systemImage: "checkmark.shield.fill",
        title: "Sunscreen applied!",
        message: "Your protection timer has started."
    )

    /// After applying: when the reminder is, and why it moved (if it did).
    static func reminderSet(plan: ReapplyPlan, notificationsOn: Bool) -> Toast {
        guard notificationsOn else {
            let time = plan.wearsOffAt.formatted(date: .omitted, time: .shortened)
            return Toast(systemImage: "timer", title: "Timer restarted!", message: "Reapply by \(time).")
        }
        let time = plan.fireDate?.formatted(date: .omitted, time: .shortened)
        switch plan.change {
        case .none:
            return Toast(systemImage: "alarm.fill", title: "Reminder set!", message: "We’ll notify you at \(time ?? "").")
        case .postponedLowUV, .postponedNoUV, .postponedBedtime:
            return Toast(systemImage: plan.symbol, title: "Reminder moved to tomorrow", message: plan.reason ?? "")
        default:
            return Toast(
                systemImage: plan.symbol,
                title: "Reminder moved to \(time ?? "")",
                message: plan.reason ?? ""
            )
        }
    }

    static let sunscreenUpdated = Toast(
        systemImage: "drop.fill",
        title: "Sunscreen updated!",
        message: "Your new sunscreen is saved."
    )

    static let notificationsOn = Toast(
        systemImage: "bell.fill",
        title: "Notifications on!",
        message: "You’ll get reminders when needed."
    )

    static let notificationsOff = Toast(
        systemImage: "bell.slash.fill",
        title: "Notifications off",
        message: "You won’t get reminders until you turn them back on."
    )

    static let notificationsBlocked = Toast(
        systemImage: "bell.slash.fill",
        title: "Notifications are blocked",
        message: "Turn them on in Settings › Notifications › Solify."
    )
}

struct ToastView: View {
    let toast: Toast
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: toast.systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.teal.gradient, in: .circle)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(toast.title)
                    .font(.headline)
                Text(toast.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button("Dismiss", systemImage: "xmark", action: onDismiss)
                .labelStyle(.iconOnly)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
        }
        .padding(.leading, 12)
        .padding(.vertical, 10)
        .background(Color(.systemBackground), in: .rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.primary.opacity(0.06))
        }
        .shadow(color: .black.opacity(0.15), radius: 16, y: 6)
        // Swipe down to get rid of it early.
        .gesture(
            DragGesture(minimumDistance: 10).onEnded { value in
                if value.translation.height > 20 { onDismiss() }
            }
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }
}

extension View {
    /// Shows `toast` above the bottom of the screen and hides it again after a few seconds.
    func toast(_ toast: Binding<Toast?>) -> some View {
        overlay(alignment: .bottom) {
            if let current = toast.wrappedValue {
                ToastView(toast: current) {
                    withAnimation(.snappy) { toast.wrappedValue = nil }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task(id: current.id) {
                    try? await Task.sleep(for: .seconds(3.5))
                    guard !Task.isCancelled else { return }
                    withAnimation(.snappy) { toast.wrappedValue = nil }
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        ToastView(toast: .applied) {}
        ToastView(toast: .reminderSet(plan: ReapplyPlan(appliedAt: .now, fireDate: .now, change: .afterIndoors("School")), notificationsOn: true)) {}
        ToastView(toast: .sunscreenUpdated) {}
        ToastView(toast: .notificationsOn) {}
    }
    .padding()
}
