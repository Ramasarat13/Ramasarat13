import XCTest

/// Drives the app on sample data (`-demoData`), so no calendar permission is involved.
final class StrataUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-demoData", "-zoomLevel", "2"]
        app.launch()
        XCTAssertTrue(levelLabel.waitForExistence(timeout: 20))
    }

    private var levelLabel: XCUIElement { app.staticTexts["zoomLevelLabel"] }
    /// Today's row. Pinching it keeps both fingers inside the list, clear of the
    /// screen edges where the system has gestures of its own.
    private var today: XCUIElement { app.otherElements["day-today"] }

    private func element(containing text: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", text))
            .firstMatch
    }

    @discardableResult
    private func waitForLevel(_ name: String, timeout: TimeInterval = 5) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", name),
            object: levelLabel
        )
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testOpensOnToday() {
        XCTAssertTrue(today.waitForExistence(timeout: 5))
        let screen = app.windows.firstMatch.frame
        XCTAssertLessThan(today.frame.minY, screen.height * 0.3, "Today should be the first thing on screen")
        XCTAssertTrue(element(containing: "Client call").exists)
    }

    func testHeaderFollowsTheScrollPosition() {
        let month = app.staticTexts["headerMonth"]
        XCTAssertTrue(month.waitForExistence(timeout: 5))
        let startingMonth = month.label
        for _ in 0..<6 {
            app.scrollViews["timeline"].swipeUp(velocity: .fast)
        }
        attachScreenshot("scrolled-ahead")
        XCTAssertNotEqual(month.label, startingMonth, "The header should name the month scrolled to")

        app.buttons["Today"].tap()
        sleep(1)
        attachScreenshot("back-to-today")
        let back = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", startingMonth),
            object: month
        )
        XCTAssertEqual(XCTWaiter().wait(for: [back], timeout: 5), .completed)
        XCTAssertTrue(today.waitForExistence(timeout: 5))
    }

    func testEarlierEventsLoadAboveToday() {
        XCTAssertTrue(today.waitForExistence(timeout: 5))
        app.buttons["Earlier events"].tap()
        // Today stays in view, with the newly loaded days above it.
        sleep(2)
        XCTAssertTrue(today.exists)
        let screen = app.windows.firstMatch.frame
        XCTAssertGreaterThan(today.frame.minY, screen.height * 0.15)
        XCTAssertLessThan(today.frame.minY, screen.height * 0.85)
        attachScreenshot("earlier-loaded")
    }

    func testPinchMovesBetweenLevels() {
        XCTAssertEqual(levelLabel.label, "Schedule")
        XCTAssertTrue(today.waitForExistence(timeout: 5))

        today.pinch(withScale: 3, velocity: 2)
        XCTAssertTrue(waitForLevel("Details"), "Pinching out should reach Details, found \(levelLabel.label)")
        attachScreenshot("pinched-out")

        // Pinch in while today's row is still tall enough to hold two fingers.
        today.pinch(withScale: 0.4, velocity: -2)
        let left = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label != %@", "Details"),
            object: levelLabel
        )
        XCTAssertEqual(XCTWaiter().wait(for: [left], timeout: 5), .completed, "Pinching in should leave Details")
        let compact = levelLabel.label
        attachScreenshot("pinched-in")

        today.pinch(withScale: 3, velocity: 2)
        let grown = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label != %@", compact),
            object: levelLabel
        )
        XCTAssertEqual(XCTWaiter().wait(for: [grown], timeout: 5), .completed, "Pinching out should leave \(compact)")
    }

    func testLevelButtonsStepThroughEveryLevel() {
        attachScreenshot("level-2-schedule")

        app.buttons["More detail"].tap()
        XCTAssertTrue(waitForLevel("Details"))
        XCTAssertFalse(app.buttons["More detail"].isEnabled)
        attachScreenshot("level-3-details")

        app.buttons["Less detail"].tap()
        XCTAssertTrue(waitForLevel("Schedule"))
        app.buttons["Less detail"].tap()
        XCTAssertTrue(waitForLevel("Titles"))
        attachScreenshot("level-1-titles")

        app.buttons["Less detail"].tap()
        XCTAssertTrue(waitForLevel("Glance"))
        XCTAssertFalse(app.buttons["Less detail"].isEnabled)
        attachScreenshot("level-0-glance")
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

    func testCalendarListShowsEveryCalendar() {
        app.buttons["Calendars"].tap()
        XCTAssertTrue(element(containing: "Personal").waitForExistence(timeout: 5))
        XCTAssertTrue(element(containing: "Holidays").exists)
        attachScreenshot("calendars")
        app.buttons["Done"].tap()
    }
}
