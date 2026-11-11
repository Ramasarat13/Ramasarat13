import SwiftUI

// Provider-agnostic calendar models. Nothing in this file knows about EventKit,
// so a second backend (Google Calendar) can produce the same values.

struct RGBAColor: Hashable, Sendable {
    var red: Double
    var green: Double
    var blue: Double
    var opacity: Double = 1

    static let gray = RGBAColor(red: 0.56, green: 0.56, blue: 0.58)

    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}

extension RGBAColor {
    init(cgColor: CGColor?) {
        guard
            let cgColor,
            let space = CGColorSpace(name: CGColorSpace.sRGB),
            let converted = cgColor.converted(to: space, intent: .defaultIntent, options: nil),
            let parts = converted.components,
            parts.count >= 3
        else {
            self = .gray
            return
        }
        self.init(
            red: Double(parts[0]),
            green: Double(parts[1]),
            blue: Double(parts[2]),
            opacity: parts.count > 3 ? Double(parts[3]) : 1
        )
    }
}

struct CalendarInfo: Identifiable, Hashable, Sendable {
    /// Unique across providers: "<providerID>:<native identifier>".
    let id: String
    let providerID: String
    let title: String
    /// The account the calendar lives in, e.g. "iCloud" or "Gmail".
    let accountName: String
    let color: RGBAColor
    let isEditable: Bool
}

struct CalendarGroup: Identifiable, Hashable {
    let id: String
    let name: String
    let calendars: [CalendarInfo]
}

enum Recurrence: Hashable, Sendable {
    case never, daily, weekly, biweekly, monthly, yearly
    /// A rule this app can't express. It is shown, and kept untouched on save.
    case custom

    static let selectable: [Recurrence] = [.never, .daily, .weekly, .biweekly, .monthly, .yearly]

    var label: String {
        switch self {
        case .never: "Never"
        case .daily: "Every day"
        case .weekly: "Every week"
        case .biweekly: "Every 2 weeks"
        case .monthly: "Every month"
        case .yearly: "Every year"
        case .custom: "Custom"
        }
    }
}

enum EventAlert: Hashable, Sendable {
    case none
    /// Seconds before the event starts. Zero means at the start time.
    case before(TimeInterval)

    static let presets: [EventAlert] = [
        .none, .before(0), .before(5 * 60), .before(10 * 60), .before(15 * 60), .before(30 * 60),
        .before(3600), .before(2 * 3600), .before(86_400), .before(2 * 86_400), .before(7 * 86_400),
    ]

    var label: String {
        switch self {
        case .none:
            return "None"
        case .before(let seconds) where seconds <= 0:
            return "At time of event"
        case .before(let seconds):
            let amount = Duration.seconds(seconds).formatted(
                .units(allowed: [.weeks, .days, .hours, .minutes], width: .wide)
            )
            return "\(amount) before"
        }
    }
}

struct CalendarEvent: Identifiable, Hashable, Sendable {
    /// Unique per occurrence, so every instance of a repeating event has its own id.
    let id: String
    let providerID: String
    /// The provider's own identifier, shared by all occurrences of a repeating event.
    let eventIdentifier: String
    var calendarID: String
    var title: String
    var start: Date
    var end: Date
    var isAllDay: Bool
    var location: String? = nil
    var notes: String? = nil
    var url: URL? = nil
    var recurrence: Recurrence = .never
    var alert: EventAlert = .none
    var attendees: [String] = []
    var isEditable: Bool = true

    var displayTitle: String {
        title.trimmed.isEmpty ? "Untitled" : title
    }

    var isRecurring: Bool { recurrence != .never }
}

/// Which occurrences a change to a repeating event applies to.
enum EditSpan: Sendable {
    case thisEvent, futureEvents
}

/// The editable form of an event, used for both new and existing events.
struct EventDraft: Identifiable, Sendable {
    let id = UUID()
    var existing: CalendarEvent?
    var title: String
    var calendarID: String
    var start: Date
    var end: Date
    var isAllDay: Bool
    var location: String
    var notes: String
    var urlString: String
    var recurrence: Recurrence
    var alert: EventAlert

    init(calendarID: String, start: Date, end: Date) {
        self.existing = nil
        self.title = ""
        self.calendarID = calendarID
        self.start = start
        self.end = end
        self.isAllDay = false
        self.location = ""
        self.notes = ""
        self.urlString = ""
        self.recurrence = .never
        self.alert = .none
    }

    init(editing event: CalendarEvent) {
        self.existing = event
        self.title = event.title
        self.calendarID = event.calendarID
        self.start = event.start
        self.end = event.end
        self.isAllDay = event.isAllDay
        self.location = event.location ?? ""
        self.notes = event.notes ?? ""
        self.urlString = event.url?.absoluteString ?? ""
        self.recurrence = event.recurrence
        self.alert = event.alert
    }

    var isNew: Bool { existing == nil }

    var url: URL? {
        let text = urlString.trimmed
        guard !text.isEmpty else { return nil }
        return URL(string: text.contains("://") ? text : "https://\(text)")
    }

    /// The draft with its dates made consistent: all-day events cover whole days and
    /// an event never ends before it starts.
    func normalized(calendar: Calendar) -> EventDraft {
        var copy = self
        if copy.end < copy.start { copy.end = copy.start }
        if copy.isAllDay {
            let firstDay = calendar.startOfDay(for: copy.start)
            let lastDay = calendar.startOfDay(for: copy.end)
            let dayAfter = calendar.date(byAdding: .day, value: 1, to: lastDay) ?? lastDay.addingTimeInterval(86_400)
            copy.start = firstDay
            copy.end = dayAfter.addingTimeInterval(-1)
        }
        return copy
    }
}

enum CalendarAccess: Sendable {
    case notDetermined, denied, restricted, writeOnly, granted
}

enum CalendarError: LocalizedError {
    case eventNotFound, calendarNotFound, readOnlyCalendar, noEditableCalendar

    var errorDescription: String? {
        switch self {
        case .eventNotFound: "This event no longer exists. It may have been changed on another device."
        case .calendarNotFound: "That calendar is no longer available."
        case .readOnlyCalendar: "This calendar is read-only. Choose another calendar."
        case .noEditableCalendar: "None of your calendars can be edited."
        }
    }
}
