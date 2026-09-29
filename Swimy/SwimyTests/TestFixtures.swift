import Foundation
@testable import Swimy

/// A fixed clock so tests give the same result on any day, in any time zone.
enum TestClock {
    static let now = Date(timeIntervalSince1970: 1_790_000_000)

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }
}

extension Swim {
    /// A hand-made swim. Pace per 100 m = activeSeconds / distance × 100.
    static func fixture(
        daysAgo: Double,
        location: LocationType = .pool,
        poolLengthMeters: Double = 25,
        poolUnit: PoolUnit = .meters,
        distance: Double = 1000,
        activeSeconds: Double = 1500,
        totalSeconds: Double = 1800,
        heartRate: Double? = 130,
        swolf: Double? = 55,
        calories: Double? = 250
    ) -> Swim {
        let start = TestClock.now.addingTimeInterval(-daysAgo * 86_400)
        let isPool = location == .pool
        return Swim(
            id: UUID(),
            startDate: start,
            endDate: start.addingTimeInterval(totalSeconds),
            locationType: location,
            poolLengthMeters: isPool ? poolLengthMeters : nil,
            poolUnit: poolUnit,
            totalDistanceMeters: distance,
            activeDurationSec: activeSeconds,
            totalStrokes: nil,
            avgHeartRate: heartRate,
            maxHeartRate: heartRate.map { $0 + 20 },
            activeCalories: calories,
            lengthCount: isPool ? Int((distance / poolLengthMeters).rounded()) : nil,
            avgSwolf: isPool ? swolf : nil,
            strokeMix: [:],
            waterTemperatureCelsius: nil,
            deviceName: nil,
            sourceName: "Test"
        )
    }
}
