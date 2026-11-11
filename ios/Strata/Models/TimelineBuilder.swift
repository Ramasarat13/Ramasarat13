import Foundation

/// One row of the timeline: a calendar day and the events that touch it.
struct TimelineDay: Identifiable, Hashable, Sendable {
    /// Midnight at the start of the day.
    let date: Date
    /// Midnight at the start of the next day.
    let end: Date
    /// All-day events first, then by start time.
    let events: [CalendarEvent]
    /// True for the first listed day of each month, which draws the month label.
    let startsMonth: Bool

    var id: Date { date }

    /// How an event sits inside this day. Events longer than a day show up on
    /// every day they cover, so the same event can be placed differently per day.
    enum Placement: Equatable {
        /// An all-day event, or a timed event that covers the whole day.
        case allDay
        /// Starts and ends within the day.
        case within
        /// Starts today and runs past midnight.
        case startsToday
        /// Began on an earlier day and ends today.
        case endsToday
    }

    func placement(of event: CalendarEvent) -> Placement {
        if event.isAllDay { return .allDay }
        let startsBefore = event.start < date
        let endsAfter = event.end > end
        if (startsBefore || event.start == date) && (endsAfter || event.end == end) && event.end > event.start {
            return .allDay
        }
        if startsBefore { return .endsToday }
        if endsAfter { return .startsToday }
        return .within
    }

    /// Where the "now" marker goes in today's list: after everything that has
    /// already started, before the first timed event still to come.
    func nowIndex(at now: Date) -> Int {
        events.firstIndex { event in
            placement(of: event) != .allDay && placement(of: event) != .endsToday && event.start > now
        } ?? events.count
    }
}

enum TimelineBuilder {
    /// Groups events into days. Only days with events are listed, plus today.
    static func days(
        from events: [CalendarEvent],
        calendar: Calendar,
        today: Date,
        range: DateInterval
    ) -> [TimelineDay] {
        var buckets: [Date: [CalendarEvent]] = [:]
        let lastInstantInRange = range.end.addingTimeInterval(-1)

        for event in events {
            // An event that ends exactly at midnight belongs to the day before.
            let lastInstant = event.end > event.start ? event.end.addingTimeInterval(-1) : event.start
            var day = calendar.startOfDay(for: max(event.start, range.start))
            let lastDay = calendar.startOfDay(for: min(lastInstant, lastInstantInRange))
            while day <= lastDay {
                buckets[day, default: []].append(event)
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = calendar.startOfDay(for: next)
            }
        }

        let todayStart = calendar.startOfDay(for: today)
        if range.contains(todayStart), buckets[todayStart] == nil {
            buckets[todayStart] = []
        }

        var result: [TimelineDay] = []
        result.reserveCapacity(buckets.count)
        var previousMonth: DateComponents?
        for date in buckets.keys.sorted() {
            let month = calendar.dateComponents([.year, .month], from: date)
            let end = calendar.date(byAdding: .day, value: 1, to: date).map { calendar.startOfDay(for: $0) }
                ?? date.addingTimeInterval(86_400)
            let sorted = (buckets[date] ?? []).sorted { lhs, rhs in
                let lhsAllDay = lhs.isAllDay || (lhs.start <= date && lhs.end >= end)
                let rhsAllDay = rhs.isAllDay || (rhs.start <= date && rhs.end >= end)
                if lhsAllDay != rhsAllDay { return lhsAllDay }
                if lhs.start != rhs.start { return lhs.start < rhs.start }
                if lhs.title != rhs.title { return lhs.title < rhs.title }
                return lhs.id < rhs.id
            }
            result.append(TimelineDay(date: date, end: end, events: sorted, startsMonth: month != previousMonth))
            previousMonth = month
        }
        return result
    }
}
