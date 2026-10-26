import Foundation
import Observation

/// A regular part of the week, like "School, Mon–Fri, 8 AM – 3 PM" or "Soccer, Tue & Thu, 4–6 PM".
struct RoutineBlock: Codable, Identifiable, Hashable {
    enum Kind: String, Codable, CaseIterable, Identifiable {
        case school, work, outdoor, otherIndoor

        var id: Self { self }

        var name: String {
            switch self {
            case .school: "School"
            case .work: "Work"
            case .outdoor: "Outdoor Activity"
            case .otherIndoor: "Other (Indoors)"
            }
        }

        var symbol: String {
            switch self {
            case .school: "graduationcap.fill"
            case .work: "briefcase.fill"
            case .outdoor: "figure.run"
            case .otherIndoor: "house.fill"
            }
        }

        var isIndoors: Bool { self != .outdoor }
    }

    var id = UUID()
    var kind: Kind
    var name: String
    /// 1 = Sunday … 7 = Saturday (same numbering as `Calendar`).
    var weekdays: Set<Int>
    /// Minutes after midnight, like 8 × 60 = 480 for 8:00 AM.
    var startMinutes: Int
    var endMinutes: Int

    /// What to call it in messages: the name the user typed, or the kind.
    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.first else { return kind.name }
        // Capitalized, since it can start a sentence ("Tennis starts at 4:15 PM").
        return first.uppercased() + trimmed.dropFirst()
    }

    /// Like "Mon–Fri", "Weekends", "Tue, Thu".
    var daysText: String {
        let sorted = weekdays.sorted()
        if sorted == [2, 3, 4, 5, 6] { return "Weekdays" }
        if sorted == [1, 7] { return "Weekends" }
        if sorted.count == 7 { return "Every day" }
        let symbols = Calendar.current.shortWeekdaySymbols
        // Days in a row (like Mon, Tue, Wed, Thu) read better as "Mon–Thu".
        if sorted.count >= 3, sorted.last! - sorted.first! == sorted.count - 1 {
            return "\(symbols[sorted.first! - 1])–\(symbols[sorted.last! - 1])"
        }
        return sorted.map { symbols[$0 - 1] }.joined(separator: ", ")
    }

    /// Like "8:00 AM – 3:00 PM".
    var timeText: String {
        "\(Routine.timeText(startMinutes)) – \(Routine.timeText(endMinutes))"
    }

    /// This block's start and end on the given day, if it happens that day.
    func occurrence(on day: Date, calendar: Calendar = .current) -> DateInterval? {
        guard weekdays.contains(calendar.component(.weekday, from: day)) else { return nil }
        let midnight = calendar.startOfDay(for: day)
        guard let start = calendar.date(byAdding: .minute, value: startMinutes, to: midnight),
              let end = calendar.date(byAdding: .minute, value: endMinutes, to: midnight),
              end > start
        else { return nil }
        return DateInterval(start: start, end: end)
    }
}

/// A snapshot of the user's day: when they sleep, and when they're inside or outside.
/// The reminder rules use this to decide when to send things.
struct Routine {
    var wakeMinutes: Int
    var bedtimeMinutes: Int
    var blocks: [RoutineBlock]

    /// What's saved on the phone right now.
    static var current: Routine {
        let defaults = UserDefaults.standard
        return Routine(
            wakeMinutes: defaults.object(forKey: StorageKey.wakeUpMinutes) as? Int ?? 7 * 60,
            bedtimeMinutes: defaults.object(forKey: StorageKey.bedtimeMinutes) as? Int ?? 22 * 60,
            blocks: RoutineStore.loadBlocks()
        )
    }

    static func timeText(_ minutes: Int) -> String {
        let date = Calendar.current.date(bySettingHour: minutes / 60 % 24, minute: minutes % 60, second: 0, of: .now) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }

    func isAwake(at date: Date, calendar: Calendar = .current) -> Bool {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let minutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        if bedtimeMinutes > wakeMinutes {
            return minutes >= wakeMinutes && minutes < bedtimeMinutes
        }
        // Bedtime is after midnight (like 1 AM).
        return minutes >= wakeMinutes || minutes < bedtimeMinutes
    }

    /// The wake-up time on the given day.
    func wakeTime(on day: Date, calendar: Calendar = .current) -> Date? {
        calendar.date(byAdding: .minute, value: wakeMinutes, to: calendar.startOfDay(for: day))
    }

    /// If `date` falls in a school / work / other indoor block, that block and when the user
    /// will finally be free (back-to-back indoor blocks are joined together).
    func indoorStretch(containing date: Date, calendar: Calendar = .current) -> (block: RoutineBlock, end: Date)? {
        func indoorBlock(at time: Date) -> (RoutineBlock, DateInterval)? {
            for block in blocks where block.kind.isIndoors {
                if let interval = block.occurrence(on: time, calendar: calendar),
                   time >= interval.start, time < interval.end {
                    return (block, interval)
                }
            }
            return nil
        }

        guard let (first, interval) = indoorBlock(at: date) else { return nil }
        var end = interval.end
        while let (_, next) = indoorBlock(at: end) { end = next.end }
        return (first, end)
    }

    /// The outdoor activity happening at `date`, if any, and when it ends.
    func outdoorActivity(containing date: Date, calendar: Calendar = .current) -> (block: RoutineBlock, end: Date)? {
        outdoorActivities(on: date, calendar: calendar)
            .first { date >= $0.interval.start && date < $0.interval.end }
            .map { ($0.block, $0.interval.end) }
    }

    func isIndoors(at date: Date) -> Bool {
        indoorStretch(containing: date) != nil
    }

    /// The outdoor activities on the given day, with their start and end times.
    func outdoorActivities(on day: Date, calendar: Calendar = .current) -> [(block: RoutineBlock, interval: DateInterval)] {
        blocks
            .filter { !$0.kind.isIndoors }
            .compactMap { block in block.occurrence(on: day, calendar: calendar).map { (block, $0) } }
            .sorted { $0.interval.start < $1.interval.start }
    }
}

/// Keeps the routine blocks for the Profile screen and saves them on the phone.
@Observable
final class RoutineStore {
    static let shared = RoutineStore()

    var blocks: [RoutineBlock] {
        didSet {
            UserDefaults.standard.set(try? JSONEncoder().encode(blocks), forKey: StorageKey.routineBlocks)
            // The reminders plan around these, so line them up again.
            Task { await Reminders.refreshAll() }
        }
    }

    private init() {
        blocks = Self.loadBlocks()
    }

    static func loadBlocks() -> [RoutineBlock] {
        guard let data = UserDefaults.standard.data(forKey: StorageKey.routineBlocks) else { return [] }
        return (try? JSONDecoder().decode([RoutineBlock].self, from: data)) ?? []
    }

    func save(_ block: RoutineBlock) {
        var updated = blocks
        if let index = updated.firstIndex(where: { $0.id == block.id }) {
            updated[index] = block
        } else {
            updated.append(block)
        }
        blocks = updated.sorted { $0.startMinutes < $1.startMinutes }
    }

    func delete(_ block: RoutineBlock) {
        blocks.removeAll { $0.id == block.id }
    }
}
