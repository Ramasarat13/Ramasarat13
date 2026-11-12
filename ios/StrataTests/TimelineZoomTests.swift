import XCTest
@testable import Strata

final class TimelineZoomTests: XCTestCase {
    func testWholeNumbersMapToLevels() {
        XCTAssertEqual(TimelineZoom.level(for: 0), .titles)
        XCTAssertEqual(TimelineZoom.level(for: 1.4), .times)
        XCTAssertEqual(TimelineZoom.level(for: 1.6), .details)
        XCTAssertEqual(TimelineZoom.level(for: 3), .notes)
        XCTAssertEqual(TimelineZoom.level(for: -2), .titles)
        XCTAssertEqual(TimelineZoom.level(for: 9), .notes)
    }

    func testSpreadingByOneStepMovesOneLevel() {
        let zoomed = TimelineZoom.value(base: 1, magnification: TimelineZoom.magnificationPerLevel)
        XCTAssertEqual(zoomed, 2, accuracy: 0.0001)
        let back = TimelineZoom.value(base: 2, magnification: 1 / TimelineZoom.magnificationPerLevel)
        XCTAssertEqual(back, 1, accuracy: 0.0001)
    }

    func testPinchResistsPastEitherEnd() {
        let far = TimelineZoom.value(base: 3, magnification: 50)
        XCTAssertGreaterThan(far, TimelineZoom.maximum)
        XCTAssertLessThanOrEqual(far, TimelineZoom.maximum + TimelineZoom.overscroll)
        let near = TimelineZoom.value(base: 0, magnification: 0.02)
        XCTAssertLessThan(near, TimelineZoom.minimum)
        XCTAssertGreaterThanOrEqual(near, TimelineZoom.minimum - TimelineZoom.overscroll)
    }

    func testQuickPinchCarriesToTheNextLevel() {
        XCTAssertEqual(TimelineZoom.settledLevel(for: 2.3, velocity: 0), .details)
        XCTAssertEqual(TimelineZoom.settledLevel(for: 2.3, velocity: 3), .notes)
        XCTAssertEqual(TimelineZoom.settledLevel(for: 1.7, velocity: -3), .times)
    }

    func testEachLevelRevealsOneMoreLayer() {
        let titles = TimelineMetrics(zoom: 0)
        XCTAssertEqual([titles.timeReveal, titles.detailReveal, titles.notesReveal], [0, 0, 0])
        XCTAssertEqual(titles.timeColumnWidth, 0)

        let times = TimelineMetrics(zoom: 1)
        XCTAssertEqual([times.timeReveal, times.detailReveal, times.notesReveal], [1, 0, 0])

        let halfway = TimelineMetrics(zoom: 1.5)
        XCTAssertEqual([halfway.timeReveal, halfway.detailReveal, halfway.notesReveal], [1, 0.5, 0])

        let notes = TimelineMetrics(zoom: 3)
        XCTAssertEqual([notes.timeReveal, notes.detailReveal, notes.notesReveal], [1, 1, 1])
    }

    func testTextSizeFollowsDynamicTypeNotZoom() {
        XCTAssertEqual(TimelineMetrics(zoom: 0).titleSize, TimelineMetrics(zoom: 3).titleSize)
        XCTAssertEqual(TimelineMetrics(zoom: 2, typeScale: 1.5).titleSize, 25.5)
    }

    func testWordsArriveOneAtATime() {
        let runs = [
            RevealRun(text: "· Studio, Room 2", role: .secondary),
            RevealRun(text: "Work", role: .calendar),
        ]
        XCTAssertTrue(WordReveal.pieces(for: runs, fraction: 0).isEmpty)

        // Five words in all; halfway, two have arrived and the third is half in.
        let partial = WordReveal.pieces(for: runs, fraction: 0.5)
        XCTAssertEqual(partial.map(\.text), ["· Studio,", "Room"])
        XCTAssertEqual(partial[0].opacity, 1)
        XCTAssertEqual(partial[1].opacity, 0.5, accuracy: 0.0001)

        // Past the first run, the second starts arriving in its own color.
        let crossing = WordReveal.pieces(for: runs, fraction: 0.9)
        XCTAssertEqual(crossing.map(\.text), ["· Studio, Room 2", "Work"])
        XCTAssertEqual(crossing.map(\.role), [.secondary, .calendar])
        XCTAssertEqual(crossing[1].opacity, 0.5, accuracy: 0.0001)

        let full = WordReveal.pieces(for: runs, fraction: 1)
        XCTAssertEqual(full.map(\.text), ["· Studio, Room 2", "Work"])
        XCTAssertEqual(full.map(\.opacity), [1, 1])
    }
}
