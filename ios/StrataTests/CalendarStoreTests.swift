import XCTest
@testable import Strata

@MainActor
final class CalendarStoreTests: XCTestCase {
    private func makeStore() async -> CalendarStore {
        let store = CalendarStore(providers: [DemoCalendarProvider()], isDemo: true)
        await store.reload()
        return store
    }

    func testLoadsCalendarsFromSeveralAccounts() async {
        let store = await makeStore()
        XCTAssertEqual(store.access, .granted)
        XCTAssertEqual(store.calendars.count, 4)
        XCTAssertGreaterThan(store.calendarGroups.count, 1)
        XCTAssertTrue(store.days.contains { $0.date == store.today })
        XCTAssertGreaterThan(store.days.count, 30)
    }

    func testHidingACalendarRemovesItsEvents() async throws {
        let store = await makeStore()
        XCTAssertTrue(store.days.contains { $0.events.contains { $0.calendarID == "demo:work" } })
        store.setVisible(false, calendarID: "demo:work")
        try await waitUntil { !store.days.contains { $0.events.contains { $0.calendarID == "demo:work" } } }
        XCTAssertTrue(store.days.contains { $0.events.contains { $0.calendarID == "demo:personal" } })
    }

    func testAddEditAndDeleteAnEvent() async throws {
        let store = await makeStore()
        var draft = try store.newDraft(on: store.calendar.date(byAdding: .day, value: 200, to: store.today))
        draft.title = "Offsite"
        draft.location = "Goa"
        try await store.save(draft)

        func offsite() -> CalendarEvent? {
            store.days.flatMap(\.events).first { $0.title.hasPrefix("Offsite") }
        }
        let saved = try XCTUnwrap(offsite())
        XCTAssertEqual(saved.location, "Goa")
        XCTAssertEqual(store.calendar.component(.hour, from: saved.start), 9)

        var edit = EventDraft(editing: saved)
        edit.title = "Offsite (moved)"
        edit.calendarID = "demo:work"
        try await store.save(edit)
        let edited = try XCTUnwrap(offsite())
        XCTAssertEqual(edited.title, "Offsite (moved)")
        XCTAssertEqual(edited.calendarID, "demo:work")
        XCTAssertEqual(store.days.flatMap(\.events).filter { $0.title.hasPrefix("Offsite") }.count, 1)

        try await store.delete(edited)
        XCTAssertNil(offsite())
    }

    func testNewEventsAvoidReadOnlyCalendars() async throws {
        let store = await makeStore()
        let draft = try store.newDraft()
        XCTAssertEqual(store.calendarsByID[draft.calendarID]?.isEditable, true)
    }

    private func waitUntil(_ condition: @MainActor () -> Bool) async throws {
        for _ in 0..<200 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Condition was not met in time")
    }
}
