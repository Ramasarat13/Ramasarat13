import Foundation
import Testing
@testable import Swimy

struct SwimFormatterTests {
    @Test(arguments: [
        (168.0, "2′48″"),
        (140.4, "2′20″"),
        (59.6, "1′00″"),
    ])
    func pace(seconds: Double, expected: String) {
        #expect(SwimFormatter.pace(seconds) == expected)
    }

    @Test(arguments: [
        (2535.0, "42:15"),
        (3730.0, "1:02:10"),
        (59.0, "0:59"),
    ])
    func duration(seconds: Double, expected: String) {
        #expect(SwimFormatter.duration(seconds) == expected)
    }

    @Test func numbersUseTheLocale() {
        #expect(SwimFormatter.number(1500, locale: Locale(identifier: "en_US")) == "1,500")
        #expect(SwimFormatter.number(37.46, fractionDigits: 1, locale: Locale(identifier: "en_US")) == "37.5")
    }

    // MARK: - Units (spec F8)

    @Test func yardPoolShowsPaceAndDistanceInYardsEvenWithKilometres() throws {
        // 1,000 yd in 25 minutes of swimming → 2′30″ per 100 yd
        let swim = Swim.fixture(daysAgo: 0, poolLengthMeters: 22.86, poolUnit: .yards, distance: 914.4, activeSeconds: 1500)
        let pace = try #require(SwimFormatter.format(.pace, for: swim, distanceUnit: .kilometers))
        #expect(pace.value == "2′30″")
        #expect(pace.unit == "/100 yd")

        let distance = try #require(SwimFormatter.format(.distance, for: swim, distanceUnit: .kilometers))
        #expect(distance.unit == "yd")

        let poolLength = try #require(SwimFormatter.format(.poolLength, for: swim, distanceUnit: .kilometers))
        #expect(poolLength.unit == "yd")
    }

    @Test func openWaterFollowsTheDistanceSetting() throws {
        let swim = Swim.fixture(daysAgo: 0, location: .openWater, distance: 1000)
        let metric = try #require(SwimFormatter.format(.distance, for: swim, distanceUnit: .kilometers))
        let imperial = try #require(SwimFormatter.format(.distance, for: swim, distanceUnit: .miles))
        #expect(metric.unit == "m")
        #expect(imperial.unit == "yd")
    }

    @Test func totalsUseTheDistanceSetting() {
        #expect(SwimFormatter.totalDistance(meters: 37_450, unit: .kilometers).unit == "km")
        #expect(SwimFormatter.totalDistance(meters: 37_450, unit: .miles).unit == "mi")
        #expect(abs(DistanceUnit.miles.fromMeters(1609.344) - 1) < 0.000_001)
        #expect(abs(PoolUnit.yards.fromMeters(22.86) - 25) < 0.000_001)
    }

    // MARK: - Missing data (spec F4)

    @Test func missingMetricsAreHiddenNotZero() {
        let noHeartRate = Swim.fixture(daysAgo: 0, heartRate: nil, calories: nil)
        #expect(SwimFormatter.format(.heartRate, for: noHeartRate, distanceUnit: .kilometers) == nil)
        #expect(SwimFormatter.format(.calories, for: noHeartRate, distanceUnit: .kilometers) == nil)

        let openWater = Swim.fixture(daysAgo: 0, location: .openWater)
        #expect(SwimFormatter.format(.swolf, for: openWater, distanceUnit: .kilometers) == nil)
        #expect(SwimFormatter.format(.lengths, for: openWater, distanceUnit: .kilometers) == nil)
        #expect(SwimFormatter.format(.poolLength, for: openWater, distanceUnit: .kilometers) == nil)
    }

    // MARK: - Dates

    @Test func friendlyDates() {
        let now = TestClock.now
        let calendar = TestClock.calendar
        let today = now.addingTimeInterval(-60)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        #expect(SwimFormatter.swimDate(today, now: now, calendar: calendar).hasPrefix("Today, "))
        #expect(SwimFormatter.swimDate(yesterday, now: now, calendar: calendar).hasPrefix("Yesterday, "))
    }
}
