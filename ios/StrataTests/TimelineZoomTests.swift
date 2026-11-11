import XCTest
@testable import Strata

final class TimelineZoomTests: XCTestCase {
    func testWholeNumbersMapToLevels() {
        XCTAssertEqual(TimelineZoom.level(for: 0), .glance)
        XCTAssertEqual(TimelineZoom.level(for: 1.4), .titles)
        XCTAssertEqual(TimelineZoom.level(for: 1.6), .schedule)
        XCTAssertEqual(TimelineZoom.level(for: 3), .details)
        XCTAssertEqual(TimelineZoom.level(for: -2), .glance)
        XCTAssertEqual(TimelineZoom.level(for: 9), .details)
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
        XCTAssertEqual(TimelineZoom.settledLevel(for: 2.3, velocity: 0), .schedule)
        XCTAssertEqual(TimelineZoom.settledLevel(for: 2.3, velocity: 3), .details)
        XCTAssertEqual(TimelineZoom.settledLevel(for: 1.7, velocity: -3), .titles)
    }

    func testTextSizeGrowsContinuouslyWithZoom() {
        let sizes = stride(from: -0.3, through: 3.3, by: 0.1).map { TimelineMetrics(zoom: $0).titleSize }
        XCTAssertEqual(sizes, sizes.sorted())
        XCTAssertEqual(TimelineMetrics(zoom: 2).titleSize, 17)
        XCTAssertEqual(TimelineMetrics(zoom: 2, typeScale: 1.5).titleSize, 25.5)
    }

    func testContentIsInvisibleAtTheMomentLayoutsSwap() {
        XCTAssertEqual(TimelineMetrics(zoom: 1).contentOpacity, 1)
        XCTAssertEqual(TimelineMetrics(zoom: 1.49).contentOpacity, 0, accuracy: 0.01)
        XCTAssertEqual(TimelineMetrics(zoom: 1.51).contentOpacity, 0, accuracy: 0.01)
        // Schedule and Details share a layout, so nothing fades between them.
        XCTAssertEqual(TimelineMetrics(zoom: 2.5).contentOpacity, 1)
        XCTAssertEqual(TimelineMetrics(zoom: 2.4).detailReveal, 0)
        XCTAssertEqual(TimelineMetrics(zoom: 3).detailReveal, 1)
    }
}
