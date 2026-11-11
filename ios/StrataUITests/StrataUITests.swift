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
    private var timeline: XCUIElement { app.scrollViews["timeline"] }

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

    func testPinchMovesBetweenLevels() {
        XCTAssertEqual(levelLabel.label, "Schedule")

        timeline.pinch(withScale: 3, velocity: 2)
        XCTAssertTrue(waitForLevel("Details"), "Pinching out should reach Details, found \(levelLabel.label)")
        attachScreenshot("pinched-out")

        // Pinch in until the timeline bottoms out at the most compact level.
        var seen: [String] = []
        for _ in 0..<5 where levelLabel.label != "Glance" {
            timeline.pinch(withScale: 0.4, velocity: -2)
            _ = waitForLevel("Glance", timeout: 1.5)
            seen.append(levelLabel.label)
        }
        XCTAssertEqual(levelLabel.label, "Glance", "Levels seen while pinching in: \(seen)")
        attachScreenshot("pinched-in")

        timeline.pinch(withScale: 1.5, velocity: 1)
        _ = waitForLevel("Titles", timeout: 2)
        XCTAssertNotEqual(levelLabel.label, "Glance", "Pinching out should leave Glance")
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
