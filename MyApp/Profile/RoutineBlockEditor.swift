import SwiftUI

/// Sheet for adding or editing a school / work / outdoor time.
struct RoutineBlockEditor: View {
    @State private var block: RoutineBlock
    let isNew: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var isConfirmingDelete = false

    init(block: RoutineBlock, isNew: Bool) {
        _block = State(initialValue: block)
        self.isNew = isNew
    }

    private var problem: String? {
        if block.weekdays.isEmpty { return "Pick at least one day." }
        if block.endMinutes <= block.startMinutes { return "The end time needs to be after the start time." }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $block.kind) {
                        ForEach(RoutineBlock.Kind.allCases) { kind in
                            Label(kind.name, systemImage: kind.symbol).tag(kind)
                        }
                    }
                    TextField(namePlaceholder, text: $block.name)
                        .textInputAutocapitalization(.words)
                } footer: {
                    Text(block.kind.isIndoors
                         ? "Reminders wait until this ends if your sunscreen runs out while you’re here."
                         : "You’ll get a heads-up 15 minutes before, with the UV for that time.")
                }

                Section("Days") {
                    WeekdayPicker(selection: $block.weekdays)
                        .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                }

                Section {
                    DatePicker("Starts", selection: $block.startMinutes.asTime, displayedComponents: .hourAndMinute)
                    DatePicker("Ends", selection: $block.endMinutes.asTime, displayedComponents: .hourAndMinute)
                } footer: {
                    if let problem {
                        Label(problem, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }

                if !isNew {
                    Section {
                        Button("Delete", role: .destructive) { isConfirmingDelete = true }
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(isNew ? "Add \(block.kind.isIndoors ? "Time" : "Activity")" : block.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark") {
                        RoutineStore.shared.save(block)
                        dismiss()
                    }
                    .disabled(problem != nil)
                }
            }
            .confirmationDialog("Delete \(block.displayName)?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    RoutineStore.shared.delete(block)
                    dismiss()
                }
            }
            .sensoryFeedback(.selection, trigger: block.weekdays)
        }
    }

    private var namePlaceholder: String {
        switch block.kind {
        case .school: "Name (like “School”)"
        case .work: "Name (like “Work”)"
        case .outdoor: "Name (like “Soccer Practice”)"
        case .otherIndoor: "Name (like “Gym”)"
        }
    }
}

/// Seven round day buttons (S M T W T F S) that turn orange when picked.
private struct WeekdayPicker: View {
    @Binding var selection: Set<Int>

    var body: some View {
        let calendar = Calendar.current
        let letters = calendar.veryShortWeekdaySymbols
        let names = calendar.weekdaySymbols
        // Start the week on the phone's first weekday (Sunday in the US).
        let order = (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }

        HStack(spacing: 0) {
            ForEach(order, id: \.self) { day in
                let isOn = selection.contains(day)
                Button {
                    if isOn { selection.remove(day) } else { selection.insert(day) }
                } label: {
                    Text(letters[day - 1])
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isOn ? Color.white : Color.primary)
                        .frame(width: 40, height: 40)
                        .background(isOn ? AnyShapeStyle(.solifyOrange) : AnyShapeStyle(Color(.systemGray5)), in: .circle)
                        .frame(maxWidth: .infinity)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(names[day - 1])
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }
}

#Preview {
    RoutineBlockEditor(block: RoutineBlock(kind: .school, name: "", weekdays: [2, 3, 4, 5, 6], startMinutes: 480, endMinutes: 900), isNew: true)
        .tint(.orange)
}
