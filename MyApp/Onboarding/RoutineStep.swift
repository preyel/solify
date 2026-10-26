import SwiftUI

/// Step 4: "Your routine"
struct RoutineStep: View {
    /// Saved as minutes after midnight, so 7:00 AM is 7 × 60 = 420.
    @AppStorage(StorageKey.wakeUpMinutes) private var wakeUpMinutes = 7 * 60
    @AppStorage(StorageKey.hoursOutdoors) private var hoursOutdoors = 2
    @AppStorage(StorageKey.notificationsEnabled) private var notificationsEnabled = true

    @State private var isPickingTime = false

    /// Turns the saved minutes into a Date the time picker understands, and back.
    private var wakeUpTime: Binding<Date> {
        Binding {
            Calendar.current.date(bySettingHour: wakeUpMinutes / 60, minute: wakeUpMinutes % 60, second: 0, of: .now) ?? .now
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            wakeUpMinutes = (parts.hour ?? 7) * 60 + (parts.minute ?? 0)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                StepTitle("Your routine")

                wakeUpField

                VStack(alignment: .leading, spacing: 8) {
                    Text("Hours spent outdoors")
                        .font(.headline)
                    Stepper(value: $hoursOutdoors, in: 0...16) {
                        Text(hoursOutdoors == 1 ? "1 hour" : "\(hoursOutdoors) hours")
                            .contentTransition(.numericText())
                            .animation(.snappy, value: hoursOutdoors)
                    }
                    .fieldStyle()
                }

                Toggle(isOn: $notificationsEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable notifications")
                            .font(.headline)
                        Text("We’ll remind you when it’s time to apply or reapply!")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(.green)
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .padding(.bottom, 16)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var wakeUpField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Wake-up time")
                    .font(.headline)
                Spacer()
                if isPickingTime {
                    Button("Done", systemImage: "checkmark.square.fill") {
                        withAnimation(.snappy) { isPickingTime = false }
                    }
                    .labelStyle(.iconOnly)
                    .font(.title2)
                }
            }
            .frame(minHeight: 28)

            if isPickingTime {
                DatePicker("Wake-up time", selection: wakeUpTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .transition(.opacity)
            } else {
                Button {
                    withAnimation(.snappy) { isPickingTime = true }
                } label: {
                    HStack {
                        Text(wakeUpTime.wrappedValue, format: .dateTime.hour().minute())
                        Spacer()
                        Image(systemName: "clock")
                            .foregroundStyle(.orange)
                    }
                    .foregroundStyle(.primary)
                    .fieldStyle()
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens a time picker")
                .transition(.opacity)
            }
        }
    }
}

#Preview {
    RoutineStep()
}
