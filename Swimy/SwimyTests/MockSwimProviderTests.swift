import Foundation
import Testing
@testable import Swimy

struct MockSwimProviderTests {
    let provider = MockSwimProvider(
        scenario: .sampleSwims,
        now: TestClock.now,
        calendar: TestClock.calendar,
        latency: .zero
    )

    @Test func hasThirtySwimsNewestFirst() {
        let swims = provider.swims
        #expect(swims.count == 30)
        #expect(zip(swims, swims.dropFirst()).allSatisfy { $0.startDate > $1.startDate })
    }

    @Test func coversEveryEdgeCaseInTheSpec() {
        let swims = provider.swims
        #expect(swims.contains { $0.locationType == .openWater })
        #expect(swims.contains { $0.poolUnit == .yards })
        #expect(swims.contains { $0.poolLengthMeters == 50 })
        #expect(swims.contains { $0.locationType == .pool && $0.avgHeartRate == nil && $0.totalStrokes != nil })
        #expect(swims.contains { $0.locationType == .pool && $0.avgHeartRate == nil && $0.totalStrokes == nil })
        #expect(swims.contains { !MetricsEngine.isCountable($0) })
    }

    @Test func isTheSameEveryTime() {
        let again = MockSwimProvider(scenario: .sampleSwims, now: TestClock.now, calendar: TestClock.calendar, latency: .zero)
        #expect(again.swims == provider.swims)
    }

    @Test func everySwimIsInThePast() {
        #expect(provider.swims.allSatisfy { $0.endDate < TestClock.now })
    }

    @Test func latestSwimIsTodayWithFullData() throws {
        let latest = try #require(provider.swims.first)
        #expect(TestClock.calendar.isDate(latest.startDate, inSameDayAs: TestClock.now))
        #expect(latest.locationType == .pool)
        #expect(latest.avgHeartRate != nil)
        #expect(latest.avgSwolf != nil)
        #expect(MetricsEngine.comparison(of: .pace, for: latest, in: provider.swims) != nil)
    }

    @Test func poolSummariesMatchTheirLengths() async throws {
        for swim in provider.swims where swim.locationType == .pool {
            let detail = try await provider.fetchDetail(for: swim.id)
            guard !detail.lengths.isEmpty else { continue } // third-party swim: summary only
            #expect(detail.lengths.count == swim.lengthCount)

            let distance = detail.lengths.reduce(0) { $0 + $1.distanceMeters }
            #expect(abs(distance - swim.totalDistanceMeters) < 0.001)

            let active = detail.lengths.reduce(0) { $0 + $1.durationSec }
            #expect(abs(active - swim.activeDurationSec) < 0.001)
            #expect(swim.activeDurationSec < swim.totalDurationSec)

            for (previous, next) in zip(detail.lengths, detail.lengths.dropFirst()) {
                #expect(next.start >= previous.end)
            }
        }
    }

    @Test func openWaterSwimsHaveNoPoolData() async throws {
        let openWater = provider.swims.filter { $0.locationType == .openWater }
        #expect(!openWater.isEmpty)
        for swim in openWater {
            #expect(swim.poolLengthMeters == nil)
            #expect(swim.lengthCount == nil)
            #expect(swim.avgSwolf == nil)
            #expect(swim.waterTemperatureCelsius != nil)
            let detail = try await provider.fetchDetail(for: swim.id)
            #expect(detail.lengths.isEmpty)
        }
    }

    @Test(arguments: [
        (MockSwimProvider.Scenario.sampleSwims, 30),
        (MockSwimProvider.Scenario.singleSwim, 1),
        (MockSwimProvider.Scenario.noSwims, 0),
    ])
    func scenarios(scenario: MockSwimProvider.Scenario, count: Int) async throws {
        let provider = MockSwimProvider(scenario: scenario, now: TestClock.now, calendar: TestClock.calendar, latency: .zero)
        let swims = try await provider.fetchSwims()
        #expect(swims.count == count)
    }
}
