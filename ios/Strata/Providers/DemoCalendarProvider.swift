import Foundation

/// An in-memory provider with made-up events. It backs the "sample data" mode,
/// Xcode previews and UI tests, and shows that the app runs on any `CalendarProvider`.
final class DemoCalendarProvider: CalendarProvider {
    static let providerID = "demo"

    let id = DemoCalendarProvider.providerID
    let displayName = "Sample Calendars"
    let access: CalendarAccess = .granted
    var onChange: (() -> Void)?

    private let demoCalendars: [CalendarInfo]
    private var demoEvents: [CalendarEvent]

    init(now: Date = .now, calendar: Calendar = .current) {
        demoCalendars = Self.makeCalendars()
        demoEvents = Self.makeEvents(now: now, calendar: calendar)
    }

    func requestAccess() async -> CalendarAccess { .granted }

    func calendars() async throws -> [CalendarInfo] { demoCalendars }

    func defaultCalendarID() -> String? { Self.personal }

    func events(in interval: DateInterval) async throws -> [CalendarEvent] {
        demoEvents.filter { $0.end >= interval.start && $0.start < interval.end }
    }

    func save(_ draft: EventDraft, span: EditSpan) async throws {
        guard demoCalendars.contains(where: { $0.id == draft.calendarID && $0.isEditable }) else {
            throw CalendarError.readOnlyCalendar
        }
        if let existing = draft.existing {
            demoEvents.removeAll { $0.id == existing.id }
        }
        let identifier = draft.existing?.eventIdentifier ?? UUID().uuidString
        demoEvents.append(
            CalendarEvent(
                id: "\(Self.providerID):\(identifier)|\(Int(draft.start.timeIntervalSinceReferenceDate))",
                providerID: Self.providerID,
                eventIdentifier: identifier,
                calendarID: draft.calendarID,
                title: draft.title.trimmed,
                start: draft.start,
                end: draft.end,
                isAllDay: draft.isAllDay,
                location: draft.location.nilIfBlank,
                notes: draft.notes.nilIfBlank,
                url: draft.url,
                recurrence: .never,
                alert: draft.alert
            )
        )
    }

    func delete(_ event: CalendarEvent, span: EditSpan) async throws {
        demoEvents.removeAll { $0.id == event.id }
    }

    // MARK: Sample data

    private static let work = "demo:work"
    private static let personal = "demo:personal"
    private static let family = "demo:family"
    private static let holidays = "demo:holidays"

    private static func makeCalendars() -> [CalendarInfo] {
        [
            CalendarInfo(id: work, providerID: providerID, title: "Work", accountName: "Studio",
                         color: RGBAColor(red: 0.20, green: 0.47, blue: 0.96), isEditable: true),
            CalendarInfo(id: personal, providerID: providerID, title: "Personal", accountName: "iCloud",
                         color: RGBAColor(red: 0.20, green: 0.72, blue: 0.45), isEditable: true),
            CalendarInfo(id: family, providerID: providerID, title: "Family", accountName: "iCloud",
                         color: RGBAColor(red: 0.96, green: 0.58, blue: 0.11), isEditable: true),
            CalendarInfo(id: holidays, providerID: providerID, title: "Holidays", accountName: "Subscribed",
                         color: RGBAColor(red: 0.69, green: 0.32, blue: 0.87), isEditable: false),
        ]
    }

    private struct Template {
        let title: String
        let calendarID: String
        let minutes: Int
        var location: String? = nil
        var notes: String? = nil
    }

    private static let workPool: [Template] = [
        Template(title: "Design review", calendarID: work, minutes: 60, location: "Studio, Room 2",
                 notes: "Walk through the onboarding flow. Bring the two open questions on empty states."),
        Template(title: "Client call", calendarID: work, minutes: 45, location: "Video call",
                 notes: "Agenda: timeline, handoff dates, feedback on the second round."),
        Template(title: "Prototype testing", calendarID: work, minutes: 90, location: "Studio, Lab"),
        Template(title: "1:1 with Meera", calendarID: work, minutes: 30),
        Template(title: "Sprint planning", calendarID: work, minutes: 60, notes: "Estimate the settings work."),
        Template(title: "Portfolio critique", calendarID: work, minutes: 45),
        Template(title: "Focus time", calendarID: work, minutes: 120),
    ]

    private static let lifePool: [Template] = [
        Template(title: "Gym", calendarID: personal, minutes: 60, location: "Cult, Indiranagar"),
        Template(title: "Dinner with Anika", calendarID: personal, minutes: 120, location: "Toit"),
        Template(title: "Haircut", calendarID: personal, minutes: 45),
        Template(title: "Call parents", calendarID: family, minutes: 30),
        Template(title: "School pickup", calendarID: family, minutes: 30, location: "Main gate"),
        Template(title: "Groceries", calendarID: family, minutes: 45),
        Template(title: "Long run", calendarID: personal, minutes: 75, location: "Cubbon Park"),
        Template(title: "Movie night", calendarID: family, minutes: 150),
    ]

    private static func makeEvents(now: Date, calendar: Calendar) -> [CalendarEvent] {
        var generator = SplitMix64(seed: 2026)
        var events: [CalendarEvent] = []
        let today = calendar.startOfDay(for: now)

        func add(_ template: Template, start: Date, allDayThrough lastDay: Date? = nil) {
            let identifier = "sample-\(events.count)"
            let isAllDay = lastDay != nil
            let end: Date
            if let lastDay {
                let dayAfter = calendar.date(byAdding: .day, value: 1, to: lastDay) ?? lastDay
                end = dayAfter.addingTimeInterval(-1)
            } else {
                end = start.addingTimeInterval(TimeInterval(template.minutes * 60))
            }
            events.append(
                CalendarEvent(
                    id: "\(providerID):\(identifier)",
                    providerID: providerID,
                    eventIdentifier: identifier,
                    calendarID: template.calendarID,
                    title: template.title,
                    start: start,
                    end: end,
                    isAllDay: isAllDay,
                    location: template.location,
                    notes: template.notes,
                    isEditable: template.calendarID != holidays
                )
            )
        }

        func day(_ offset: Int) -> Date {
            calendar.date(byAdding: .day, value: offset, to: today) ?? today
        }

        func time(_ offset: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day(offset)) ?? day(offset)
        }

        for offset in -60...150 where offset != 0 {
            let weekday = calendar.component(.weekday, from: day(offset))
            let isWeekend = weekday == 1 || weekday == 7
            if isWeekend {
                let count = Int.random(in: 0...2, using: &generator)
                for slot in 0..<count {
                    let template = lifePool.randomElement(using: &generator) ?? lifePool[0]
                    add(template, start: time(offset, 9 + slot * 5 + Int.random(in: 0...2, using: &generator)))
                }
            } else {
                // Leave about one weekday in six empty so the timeline shows gaps.
                guard Int.random(in: 0..<6, using: &generator) != 0 else { continue }
                add(Template(title: "Standup", calendarID: work, minutes: 15), start: time(offset, 9, 30))
                let count = Int.random(in: 0...2, using: &generator)
                for slot in 0..<count {
                    let template = workPool.randomElement(using: &generator) ?? workPool[0]
                    add(template, start: time(offset, 11 + slot * 3, Bool.random(using: &generator) ? 0 : 30))
                }
                if Int.random(in: 0..<3, using: &generator) == 0 {
                    let template = lifePool.randomElement(using: &generator) ?? lifePool[0]
                    add(template, start: time(offset, 18 + Int.random(in: 0...2, using: &generator)))
                }
            }
        }

        // Today is built around the current time so the live marker has something to sit between.
        add(Template(title: "Standup", calendarID: work, minutes: 15), start: time(0, 9, 30))
        add(Template(title: "Design review", calendarID: work, minutes: 45, location: "Studio, Room 2",
                     notes: "Walk through the onboarding flow. Bring the two open questions on empty states."),
            start: now.addingTimeInterval(-20 * 60))
        add(Template(title: "Client call", calendarID: work, minutes: 30, location: "Video call",
                     notes: "Agenda: timeline, handoff dates, feedback on the second round."),
            start: now.addingTimeInterval(50 * 60))
        add(Template(title: "Dinner with Anika", calendarID: personal, minutes: 120, location: "Toit"),
            start: now.addingTimeInterval(4 * 3600))

        add(Template(title: "Amma's birthday", calendarID: family, minutes: 0), start: day(3), allDayThrough: day(3))
        add(Template(title: "Lisbon trip", calendarID: personal, minutes: 0, location: "Lisbon, Portugal",
                     notes: "Flight leaves 06:40. Passport, adapters, the good camera."),
            start: day(9), allDayThrough: day(13))
        add(Template(title: "Public holiday", calendarID: holidays, minutes: 0), start: day(20), allDayThrough: day(20))
        add(Template(title: "Design conference", calendarID: work, minutes: 0, location: "Bengaluru"),
            start: day(34), allDayThrough: day(35))

        return events
    }
}

/// A small seeded generator so the sample timeline looks the same on every launch.
private struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}
