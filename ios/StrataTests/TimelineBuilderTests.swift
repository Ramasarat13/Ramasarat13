import XCTest
@testable import Strata

final class TimelineBuilderTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func event(
        _ title: String,
        from start: Date,
        to end: Date,
        allDay: Bool = false
    ) -> CalendarEvent {
        CalendarEvent(
            id: title,
            providerID: "test",
            eventIdentifier: title,
            calendarID: "test:calendar",
            title: title,
            start: start,
            end: end,
            isAllDay: allDay
        )
    }

    private var range: DateInterval {
        DateInterval(start: date(2026, 1, 1), end: date(2027, 1, 1))
    }

    private func build(_ events: [CalendarEvent], today: Date? = nil) -> [TimelineDay] {
        TimelineBuilder.days(from: events, calendar: calendar, today: today ?? date(2026, 11, 11, 15), range: range)
    }

    func testTodayIsListedEvenWithoutEvents() {
        let days = build([])
        XCTAssertEqual(days.map(\.date), [date(2026, 11, 11)])
        XCTAssertTrue(days[0].events.isEmpty)
    }

    func testOnlyDaysWithEventsAreListed() {
        let days = build([
            event("A", from: date(2026, 11, 9, 10), to: date(2026, 11, 9, 11)),
            event("B", from: date(2026, 11, 14, 10), to: date(2026, 11, 14, 11)),
        ])
        XCTAssertEqual(days.map(\.date), [date(2026, 11, 9), date(2026, 11, 11), date(2026, 11, 14)])
    }

    func testMultiDayEventAppearsOnEveryDayItCovers() {
        let trip = event("Trip", from: date(2026, 11, 20), to: date(2026, 11, 23).addingTimeInterval(-1), allDay: true)
        let days = build([trip]).filter { $0.events.contains(trip) }
        XCTAssertEqual(days.map(\.date), [date(2026, 11, 20), date(2026, 11, 21), date(2026, 11, 22)])
    }

    func testEventEndingAtMidnightStaysOnItsOwnDay() {
        let late = event("Late", from: date(2026, 11, 20, 22), to: date(2026, 11, 21))
        let days = build([late]).filter { $0.events.contains(late) }
        XCTAssertEqual(days.map(\.date), [date(2026, 11, 20)])
        XCTAssertEqual(days[0].placement(of: late), .within)
    }

    func testOvernightEventIsPlacedDifferentlyOnEachDay() {
        let flight = event("Flight", from: date(2026, 11, 20, 23), to: date(2026, 11, 21, 6))
        let days = build([flight]).filter { $0.events.contains(flight) }
        XCTAssertEqual(days.count, 2)
        XCTAssertEqual(days[0].placement(of: flight), .startsToday)
        XCTAssertEqual(days[1].placement(of: flight), .endsToday)
    }

    func testAllDayEventsSortFirstThenByStartTime() {
        let days = build([
            event("Lunch", from: date(2026, 11, 20, 13), to: date(2026, 11, 20, 14)),
            event("Standup", from: date(2026, 11, 20, 9, 30), to: date(2026, 11, 20, 9, 45)),
            event("Birthday", from: date(2026, 11, 20), to: date(2026, 11, 21).addingTimeInterval(-1), allDay: true),
        ])
        let day = days.first { $0.date == date(2026, 11, 20) }
        XCTAssertEqual(day?.events.map(\.title), ["Birthday", "Standup", "Lunch"])
    }

    func testEventsOutsideTheLoadedRangeAreClipped() {
        let old = event("Old", from: date(2025, 6, 1, 10), to: date(2025, 6, 1, 11))
        let spanning = event("Spanning", from: date(2025, 12, 30), to: date(2026, 1, 3).addingTimeInterval(-1), allDay: true)
        let days = build([old, spanning])
        XCTAssertFalse(days.contains { $0.events.contains(old) })
        XCTAssertEqual(days.filter { $0.events.contains(spanning) }.map(\.date), [date(2026, 1, 1), date(2026, 1, 2)])
    }

    func testNowMarkerSitsBeforeTheNextTimedEvent() {
        let now = date(2026, 11, 11, 15)
        let days = build([
            event("Holiday", from: date(2026, 11, 11), to: date(2026, 11, 12).addingTimeInterval(-1), allDay: true),
            event("Morning", from: date(2026, 11, 11, 9), to: date(2026, 11, 11, 10)),
            event("Ongoing", from: date(2026, 11, 11, 14, 30), to: date(2026, 11, 11, 15, 30)),
            event("Evening", from: date(2026, 11, 11, 19), to: date(2026, 11, 11, 20)),
        ], today: now)
        XCTAssertEqual(days[0].events.map(\.title), ["Holiday", "Morning", "Ongoing", "Evening"])
        XCTAssertEqual(days[0].nowIndex(at: now), 3)
        XCTAssertEqual(days[0].nowIndex(at: date(2026, 11, 11, 23)), 4)
    }

    func testAllDayDraftIsNormalizedToWholeDays() {
        var draft = EventDraft(calendarID: "test:calendar", start: date(2026, 11, 20, 14), end: date(2026, 11, 21, 9))
        draft.isAllDay = true
        let normalized = draft.normalized(calendar: calendar)
        XCTAssertEqual(normalized.start, date(2026, 11, 20))
        XCTAssertEqual(normalized.end, date(2026, 11, 22).addingTimeInterval(-1))
    }
}
