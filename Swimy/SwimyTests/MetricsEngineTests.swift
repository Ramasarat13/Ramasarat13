import Foundation
import Testing
@testable import Swimy

struct MetricsEngineTests {
    // MARK: - Your usual (spec F6)

    @Test func usualIsTheMeanOfThePreviousFiveSwimsOfTheSameType() throws {
        let current = Swim.fixture(daysAgo: 0)
        let history = [
            current,
            Swim.fixture(daysAgo: 0.5, location: .openWater, activeSeconds: 5000), // other type: ignored
            Swim.fixture(daysAgo: 1, activeSeconds: 1500),
            Swim.fixture(daysAgo: 2, activeSeconds: 1600),
            Swim.fixture(daysAgo: 3, activeSeconds: 1400),
            Swim.fixture(daysAgo: 4, activeSeconds: 1500),
            Swim.fixture(daysAgo: 5, activeSeconds: 1500),
            Swim.fixture(daysAgo: 6, activeSeconds: 3000), // 6th previous: outside the window
        ]
        let usual = try #require(MetricsEngine.usual(of: .pace, before: current, in: history))
        #expect(abs(usual - 150) < 0.0001)
    }

    @Test func comparisonIsHiddenWithFewerThanTwoPreviousSwims() {
        let current = Swim.fixture(daysAgo: 0)
        let history = [current, Swim.fixture(daysAgo: 1)]
        #expect(MetricsEngine.comparison(of: .pace, for: current, in: history) == nil)
    }

    @Test func laterSwimsNeverCountTowardsUsual() {
        let current = Swim.fixture(daysAgo: 3)
        let history = [current, Swim.fixture(daysAgo: 1), Swim.fixture(daysAgo: 2)]
        #expect(MetricsEngine.usual(of: .pace, before: current, in: history) == nil)
    }

    @Test func changesUnderThreePercentReadAsAboutUsual() throws {
        let current = Swim.fixture(daysAgo: 0, activeSeconds: 1470) // 2% faster
        let history = [current, Swim.fixture(daysAgo: 1), Swim.fixture(daysAgo: 2)]
        let comparison = try #require(MetricsEngine.comparison(of: .pace, for: current, in: history))
        #expect(comparison.direction == .aboutUsual)
        #expect(comparison.isImprovement == false)
        #expect(comparison.chipText == "About your usual")
    }

    @Test func fasterPaceIsAnImprovement() throws {
        let current = Swim.fixture(daysAgo: 0, activeSeconds: 1440) // 4% faster
        let history = [current, Swim.fixture(daysAgo: 1), Swim.fixture(daysAgo: 2)]
        let comparison = try #require(MetricsEngine.comparison(of: .pace, for: current, in: history))
        #expect(comparison.direction == .lower)
        #expect(comparison.isImprovement)
        #expect(comparison.percent == 4)
        #expect(comparison.chipText == "4% vs usual")
        #expect(comparison.spokenText == "4 percent faster than usual")
    }

    @Test func slowerPaceIsNeutralNotBad() throws {
        let current = Swim.fixture(daysAgo: 0, activeSeconds: 1590) // 6% slower
        let history = [current, Swim.fixture(daysAgo: 1), Swim.fixture(daysAgo: 2)]
        let comparison = try #require(MetricsEngine.comparison(of: .pace, for: current, in: history))
        #expect(comparison.direction == .higher)
        #expect(comparison.isImprovement == false)
        #expect(comparison.spokenText == "6 percent slower than usual")
    }

    @Test func longerDistanceIsAnImprovement() throws {
        let current = Swim.fixture(daysAgo: 0, distance: 1200)
        let history = [current, Swim.fixture(daysAgo: 1), Swim.fixture(daysAgo: 2)]
        let comparison = try #require(MetricsEngine.comparison(of: .distance, for: current, in: history))
        #expect(comparison.isImprovement)
        #expect(comparison.spokenText == "20 percent farther than usual")
    }

    @Test(arguments: [110.0, 150.0])
    func heartRateIsNeverGreenOrRed(bpm: Double) throws {
        let current = Swim.fixture(daysAgo: 0, heartRate: bpm)
        let history = [current, Swim.fixture(daysAgo: 1), Swim.fixture(daysAgo: 2)]
        let comparison = try #require(MetricsEngine.comparison(of: .heartRate, for: current, in: history))
        #expect(comparison.isImprovement == false)
    }

    @Test func swolfOnlyComparesSwimsInTheSamePoolLength() throws {
        let current = Swim.fixture(daysAgo: 0, poolLengthMeters: 25, swolf: 48)
        var history = [
            current,
            Swim.fixture(daysAgo: 1, poolLengthMeters: 50, swolf: 80),
            Swim.fixture(daysAgo: 2, poolLengthMeters: 50, swolf: 80),
            Swim.fixture(daysAgo: 3, poolLengthMeters: 25, swolf: 50),
        ]
        #expect(MetricsEngine.usual(of: .swolf, before: current, in: history) == nil)

        history.append(Swim.fixture(daysAgo: 4, poolLengthMeters: 25, swolf: 50))
        let usual = try #require(MetricsEngine.usual(of: .swolf, before: current, in: history))
        #expect(usual == 50)
    }

    @Test func veryShortSwimsAreLeftOutOfAverages() throws {
        let current = Swim.fixture(daysAgo: 0)
        let history = [
            current,
            Swim.fixture(daysAgo: 1),
            Swim.fixture(daysAgo: 2, distance: 50, activeSeconds: 20, totalSeconds: 90), // too short
            Swim.fixture(daysAgo: 3),
        ]
        let usual = try #require(MetricsEngine.usual(of: .pace, before: current, in: history))
        #expect(abs(usual - 150) < 0.0001)

        let short = Swim.fixture(daysAgo: 0, distance: 50, totalSeconds: 90)
        #expect(MetricsEngine.comparison(of: .pace, for: short, in: history + [short]) == nil)
    }

    @Test func poolLengthAndLengthsAreNeverCompared() {
        let current = Swim.fixture(daysAgo: 0)
        let history = [current, Swim.fixture(daysAgo: 1), Swim.fixture(daysAgo: 2)]
        #expect(MetricsEngine.comparison(of: .poolLength, for: current, in: history) == nil)
        #expect(MetricsEngine.comparison(of: .lengths, for: current, in: history) == nil)
    }

    // MARK: - Summaries

    @Test(arguments: [
        (50.0, 120.0, true),
        (50.0, 119.0, false),
        (49.0, 600.0, false),
    ])
    func countableSwims(distance: Double, seconds: Double, expected: Bool) {
        let swim = Swim.fixture(daysAgo: 0, distance: distance, totalSeconds: seconds)
        #expect(MetricsEngine.isCountable(swim) == expected)
    }

    @Test func strokeMixAndSwolfComeFromLengths() throws {
        let start = TestClock.now
        let lengths = [
            SwimLength(index: 0, start: start, durationSec: 30, distanceMeters: 25, strokes: 20, strokeStyle: .freestyle),
            SwimLength(index: 1, start: start, durationSec: 30, distanceMeters: 25, strokes: 20, strokeStyle: .freestyle),
            SwimLength(index: 2, start: start, durationSec: 34, distanceMeters: 25, strokes: 20, strokeStyle: .freestyle),
            SwimLength(index: 3, start: start, durationSec: 50, distanceMeters: 25, strokes: nil, strokeStyle: .kickboard),
        ]
        let mix = MetricsEngine.strokeMix(of: lengths)
        #expect(mix[.freestyle] == 0.75)
        #expect(mix[.kickboard] == 0.25)

        // Kickboard has no stroke count, so it has no SWOLF: (50 + 50 + 54) / 3
        let swolf = try #require(MetricsEngine.averageSwolf(of: lengths))
        #expect(abs(swolf - 154.0 / 3) < 0.0001)
        #expect(MetricsEngine.averageSwolf(of: []) == nil)
    }

    // MARK: - Mini charts

    @Test func bucketingAveragesNeighbours() {
        let values = (0..<60).map(Double.init)
        let buckets = MiniChartData.bucketed(values, maxCount: 20)
        #expect(buckets.count == 20)
        #expect(buckets.first == 1)
        #expect(buckets.last == 58)
        #expect(MiniChartData.bucketed([1, 2, 3], maxCount: 20) == [1, 2, 3])
    }
}
