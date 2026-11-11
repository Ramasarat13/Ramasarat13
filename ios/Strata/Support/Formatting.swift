import Foundation

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var nilIfBlank: String? {
        let text = trimmed
        return text.isEmpty ? nil : text
    }
}

enum Formatting {
    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    /// "45m", "1h 30m", "2d".
    static func duration(from start: Date, to end: Date) -> String {
        let seconds = max(0, end.timeIntervalSince(start))
        let rounded = (seconds / 60).rounded() * 60
        return Duration.seconds(rounded).formatted(
            .units(allowed: [.days, .hours, .minutes], width: .narrow)
        )
    }

    /// "in 25 min", "in 2 hr".
    static func relative(_ date: Date) -> String {
        let text = date.formatted(.relative(presentation: .numeric, unitsStyle: .abbreviated))
        return text.hasSuffix(".") ? String(text.dropLast()) : text
    }

    /// The date and time line of an event, e.g. "9:30 – 10:00 AM" or "Nov 11 – 13, 2026".
    static func span(of event: CalendarEvent, calendar: Calendar) -> String {
        let sameDay = calendar.isDate(event.start, inSameDayAs: event.end)
        if event.isAllDay {
            if sameDay { return "All day" }
            return (event.start..<event.end).formatted(date: .abbreviated, time: .omitted)
        }
        if event.end <= event.start { return time(event.start) }
        return (event.start..<event.end).formatted(date: sameDay ? .omitted : .abbreviated, time: .shortened)
    }
}
