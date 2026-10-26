import SwiftUI

struct ProfileView: View {
    @AppStorage(StorageKey.userName) private var userName = ""
    @AppStorage(StorageKey.wakeUpMinutes) private var wakeUpMinutes = 7 * 60
    @AppStorage(StorageKey.bedtimeMinutes) private var bedtimeMinutes = 22 * 60
    @AppStorage(StorageKey.skinType) private var skinType = 0

    @State private var store = RoutineStore.shared
    @State private var editingBlock: RoutineBlock?
    @State private var isEditingName = false
    @State private var draftName = ""
    @FocusState private var isNameFocused: Bool
    @State private var isShowingHowItWorks = false

    private var indoorBlocks: [RoutineBlock] { store.blocks.filter { $0.kind.isIndoors } }
    private var outdoorBlocks: [RoutineBlock] { store.blocks.filter { !$0.kind.isIndoors } }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    header
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                Section {
                    DatePicker(selection: $wakeUpMinutes.asTime, displayedComponents: .hourAndMinute) {
                        rowLabel("Wake Up", systemImage: "sunrise.fill")
                    }
                    DatePicker(selection: $bedtimeMinutes.asTime, displayedComponents: .hourAndMinute) {
                        rowLabel("Bedtime", systemImage: "moon.fill")
                    }
                } header: {
                    Text("Sleep")
                } footer: {
                    Text("Your morning UV briefing comes at wake-up, and you won’t get reminders after bedtime.")
                }

                blockSection(
                    title: "School, Work & Indoors",
                    blocks: indoorBlocks,
                    addTitle: "Add School, Work or Other",
                    newKind: .school,
                    footer: "If your sunscreen runs out while you’re here, we’ll hold the reminder until you head outside."
                )

                blockSection(
                    title: "Outdoor Activities",
                    blocks: outdoorBlocks,
                    addTitle: "Add Outdoor Activity",
                    newKind: .outdoor,
                    footer: "We’ll remind you 15 minutes before, with the UV for that time, even when UV is low, since long stretches outside add up."
                )

                Section {
                    Button {
                        isShowingHowItWorks = true
                    } label: {
                        Label("How do reminders work?", systemImage: "info.circle")
                            .font(.subheadline.weight(.medium))
                            .underline()
                            .frame(maxWidth: .infinity)
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $isShowingHowItWorks) { HowRemindersWorkView() }
            .sheet(item: $editingBlock) { block in
                RoutineBlockEditor(block: block, isNew: !store.blocks.contains { $0.id == block.id })
            }
            .onChange(of: wakeUpMinutes) { Task { await Reminders.refreshAll() } }
            .onChange(of: bedtimeMinutes) { Task { await Reminders.refreshAll() } }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "person.fill")
                .font(.title)
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(.solifyOrange, in: .circle)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                nameRow
                if let type = SkinType.all.first(where: { $0.id == skinType }) {
                    Label("Skin Type \(type.numeral) · \(type.shade)", systemImage: "circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .labelStyle(SwatchLabelStyle(color: type.color))
                        .lineLimit(1)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1), in: .rect(cornerRadius: 20))
    }

    /// The name, with a pencil to edit it and a checkmark to save.
    @ViewBuilder
    private var nameRow: some View {
        if isEditingName {
            HStack(spacing: 8) {
                TextField("Your Name", text: $draftName)
                    .font(.title2.bold())
                    .textContentType(.givenName)
                    .submitLabel(.done)
                    .focused($isNameFocused)
                    .onSubmit(saveName)
                Button("Save Name", systemImage: "checkmark.circle.fill", action: saveName)
                    .labelStyle(.iconOnly)
                    .font(.title)
                    .foregroundStyle(.orange)
            }
        } else {
            HStack(spacing: 8) {
                Text(userName.isEmpty ? "Add Your Name" : userName)
                    .font(.title2.bold())
                    .foregroundStyle(userName.isEmpty ? .secondary : .primary)
                    .lineLimit(1)
                Button("Edit Name", systemImage: "pencil.circle.fill") {
                    draftName = userName
                    isEditingName = true
                    isNameFocused = true
                }
                .labelStyle(.iconOnly)
                .font(.title2)
                .foregroundStyle(.orange)
            }
        }
    }

    private func saveName() {
        userName = draftName.trimmingCharacters(in: .whitespaces)
        isNameFocused = false
        isEditingName = false
    }

    private func blockSection(title: String, blocks: [RoutineBlock], addTitle: String, newKind: RoutineBlock.Kind, footer: String) -> some View {
        Section {
            ForEach(blocks) { block in
                Button {
                    editingBlock = block
                } label: {
                    BlockRow(block: block)
                }
                .foregroundStyle(.primary)
                .swipeActions {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        withAnimation { store.delete(block) }
                    }
                    .tint(.red)
                }
            }
            Button(addTitle, systemImage: "plus.circle.fill") {
                editingBlock = RoutineBlock(
                    kind: newKind, name: "",
                    weekdays: newKind == .outdoor ? [] : [2, 3, 4, 5, 6],
                    startMinutes: newKind == .outdoor ? 16 * 60 : 8 * 60,
                    endMinutes: newKind == .outdoor ? 18 * 60 : 15 * 60
                )
            }
            .fontWeight(.semibold)
        } header: {
            Text(title)
        } footer: {
            Text(footer)
        }
    }

    private func rowLabel(_ title: String, systemImage: String) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage).foregroundStyle(.orange)
        }
    }
}

/// The sheet from "How do reminders work?": the rules for when reminders move.
private struct HowRemindersWorkView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ruleRow("figure.walk.departure", .teal, "At school or work", "If your sunscreen runs out while you’re there, the reminder waits until you head out.")
                    ruleRow("sun.max.fill", .orange, "UV near its peak while you’re out", "Your reminder comes 30 minutes sooner.")
                    ruleRow("thermometer.sun.fill", .red, "Very hot (95°F+)", "Your reminder comes 30 minutes sooner, since sweat wears sunscreen off.")
                    ruleRow("sun.horizon.fill", .indigo, "Near sunset with low UV", "Within 2 hours of sunset, if UV stays at 3 or below and you have no outdoor activities before sunset, your reminder moves to tomorrow morning.")
                    ruleRow("moon.zzz.fill", .indigo, "Past bedtime", "Your reminder moves to tomorrow morning.")
                    ruleRow("figure.run", .orange, "Outdoor activities", "You get a heads-up 15 minutes before, even when UV is low. If you’re at school or work until it starts, it comes right when that ends.")
                    ruleRow("pause.circle.fill", .orange, "Pause During Activities (in Settings)", "If it’s on, a reminder that would go off mid-activity waits until the activity ends.")
                } footer: {
                    Text("Whenever a reminder moves, Solify tells you why. With Strict Protection on (in Settings), reminders only move to tomorrow once there’s no UV left at all.")
                }
            }
            .navigationTitle("How Reminders Work")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Color(.systemGroupedBackground))
    }

    private func ruleRow(_ symbol: String, _ color: Color, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(color.gradient, in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// One school / work / outdoor row: icon, name, days and times.
private struct BlockRow: View {
    let block: RoutineBlock

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: block.kind.symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background((block.kind.isIndoors ? Color.teal : Color.orange).gradient, in: .rect(cornerRadius: 10))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(block.displayName)
                    .font(.body.weight(.semibold))
                Text("\(block.daysText) · \(block.timeText)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A label whose icon is a small colored dot (for the skin type swatch).
private struct SwatchLabelStyle: LabelStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).overlay(Circle().strokeBorder(.black.opacity(0.1))).frame(width: 12, height: 12)
            configuration.title
        }
    }
}

extension Binding where Value == Int {
    /// Turns saved "minutes after midnight" into a Date for time pickers, and back.
    var asTime: Binding<Date> {
        Binding<Date> {
            Calendar.current.date(bySettingHour: wrappedValue / 60 % 24, minute: wrappedValue % 60, second: 0, of: .now) ?? .now
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            wrappedValue = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        }
    }
}

#Preview {
    ProfileView()
        .tint(.orange)
}
