import XCTest

/// Drives the app on sample data (`-demoData`), so no calendar permission is involved.
final class StrataUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-demoData", "-zoomLevel", "0"]
        app.launch()
        XCTAssertTrue(timeline.waitForExistence(timeout: 20))
        XCTAssertTrue(today.waitForExistence(timeout: 10))
    }

    private var timeline: XCUIElement { app.scrollViews["timeline"] }

    /// Today's row. Pinching it keeps both fingers inside the list, clear of the
    /// screen edges where the system has gestures of its own.
    private var today: XCUIElement { app.otherElements["day-today"] }

    private var level: String { timeline.value as? String ?? "" }

    private func element(containing text: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", text))
            .firstMatch
    }

    @discardableResult
    private func waitForLevel(_ name: String, timeout: TimeInterval = 5) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", name),
            object: timeline
        )
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    private func waitForLevel(otherThan name: String, timeout: TimeInterval = 5) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value != %@", name),
            object: timeline
        )
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    private func chooseLevel(_ name: String) {
        app.buttons["View options"].tap()
        let option = app.buttons[name]
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        option.tap()
        XCTAssertTrue(waitForLevel(name), "Expected \(name), found \(level)")
    }

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testOpensOnTodayUnderTheHero() {
        XCTAssertEqual(level, "Titles")
        XCTAssertTrue(app.buttons["View options"].isHittable)
        let screen = app.windows.firstMatch.frame
        XCTAssertLessThan(today.frame.minY, screen.height * 0.6, "Today should follow the hero card")
        XCTAssertTrue(element(containing: "Client call").exists)
    }

    func testSpreadingRevealsMoreAndPinchingLess() {
        XCTAssertEqual(level, "Titles")

        // A small spread adds a level or two. Today's row still fits on screen, so
        // the pinch back can keep both fingers inside it.
        today.pinch(withScale: 1.5, velocity: 1)
        XCTAssertTrue(waitForLevel(otherThan: "Titles"), "Spreading should leave Titles")
        attachScreenshot("spread-a-little")

        today.pinch(withScale: 0.4, velocity: -2)
        XCTAssertTrue(waitForLevel("Titles"), "Pinching should return to Titles, found \(level)")

        // A wide spread goes all the way: the row now spells out the place and the notes.
        today.pinch(withScale: 3, velocity: 2)
        XCTAssertTrue(waitForLevel("Notes"), "Spreading wide should reach Notes, found \(level)")
        XCTAssertTrue(element(containing: "Video call").exists)
        attachScreenshot("spread-wide")
    }

    func testViewOptionsStepThroughEveryLevel() {
        attachScreenshot("level-0-titles")
        chooseLevel("Times")
        attachScreenshot("level-1-times")
        chooseLevel("Details")
        attachScreenshot("level-2-details")
        chooseLevel("Notes")
        attachScreenshot("level-3-notes")
        chooseLevel("Titles")
    }

    func testAddingAnEventShowsItOnTheTimeline() {
        app.buttons["New Event"].tap()

        let title = app.textFields["Title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("Pottery class")
        attachScreenshot("editor")
        app.buttons["Add"].tap()

        XCTAssertTrue(element(containing: "Pottery class").waitForExistence(timeout: 5))
        attachScreenshot("after-add")
    }

    func testOpeningAnEventShowsItsDetails() {
        element(containing: "Client call").tap()
        XCTAssertTrue(app.buttons["Edit"].waitForExistence(timeout: 5))
        XCTAssertTrue(element(containing: "Video call").exists)
        attachScreenshot("event-detail")
        app.buttons["Close"].tap()
    }

    func testCalendarsTabListsEveryCalendar() {
        app.buttons["Calendars"].tap()
        XCTAssertTrue(element(containing: "Personal").waitForExistence(timeout: 5))
        XCTAssertTrue(element(containing: "Holidays").exists)
        attachScreenshot("calendars")

        app.buttons["Timeline"].tap()
        XCTAssertTrue(today.waitForExistence(timeout: 5))
    }

    func testHomeTabReturnsToTheTop() {
        for _ in 0..<5 {
            timeline.swipeUp(velocity: .fast)
        }
        let options = app.buttons["View options"]
        XCTAssertFalse(options.exists && options.isHittable, "The hero should have scrolled away")
        attachScreenshot("scrolled-ahead")

        app.buttons["Timeline"].tap()
        XCTAssertTrue(options.waitForExistence(timeout: 5))
        XCTAssertTrue(today.waitForExistence(timeout: 5))
        XCTAssertTrue(options.isHittable)
    }

    func testEarlierEventsLoadAboveToday() {
        app.buttons["View options"].tap()
        let earlier = app.buttons["Load Earlier Events"]
        XCTAssertTrue(earlier.waitForExistence(timeout: 5))
        earlier.tap()
        // Today stays in view, with the newly loaded days above it.
        sleep(2)
        XCTAssertTrue(today.exists)
        let screen = app.windows.firstMatch.frame
        XCTAssertGreaterThan(today.frame.minY, screen.height * 0.1)
        XCTAssertLessThan(today.frame.minY, screen.height * 0.85)
        attachScreenshot("earlier-loaded")
    }
}
