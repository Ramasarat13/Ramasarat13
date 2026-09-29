import Foundation

/// One swim workout, summarised. This is what lists, cards and comparisons use.
/// Per-length and heart-rate data lives in `SwimDetail` and loads only when needed.
struct Swim: Identifiable, Hashable, Sendable {
    /// The Apple Health workout UUID.
    let id: UUID
    let startDate: Date
    let endDate: Date
    let locationType: LocationType
    /// Pool length in metres. `nil` for open water.
    let poolLengthMeters: Double?
    let poolUnit: PoolUnit
    let totalDistanceMeters: Double
    /// Time spent swimming, rests excluded.
    let activeDurationSec: Double
    let totalStrokes: Int?
    let avgHeartRate: Double?
    let maxHeartRate: Double?
    let activeCalories: Double?
    let lengthCount: Int?
    /// Mean SWOLF over all lengths that have a stroke count.
    let avgSwolf: Double?
    /// Share of lengths per stroke style, 0...1. Empty when the swim has no per-length data.
    let strokeMix: [SwimStroke: Double]
    let waterTemperatureCelsius: Double?
    /// e.g. "Apple Watch Series 10". `nil` when the source doesn't say.
    let deviceName: String?
    /// The app that wrote the workout to Health, e.g. "Workout".
    let sourceName: String

    /// Elapsed time, rests included.
    var totalDurationSec: Double {
        endDate.timeIntervalSince(startDate)
    }

    /// Pool length in the pool's own unit (25 for a 25 yd pool).
    var poolLength: Double? {
        poolLengthMeters.map { poolUnit.fromMeters($0) }
    }

    /// Seconds per 100 m, used when comparing swims from pools with different units.
    /// For display, `SwimFormatter` shows pace per 100 of the pool's own unit.
    var pacePer100Meters: Double? {
        guard totalDistanceMeters > 0, activeDurationSec > 0 else { return nil }
        return activeDurationSec / totalDistanceMeters * 100
    }

    /// Strokes per length, when both are known.
    var strokesPerLength: Double? {
        guard let totalStrokes, let lengthCount, lengthCount > 0 else { return nil }
        return Double(totalStrokes) / Double(lengthCount)
    }
}

/// One length of the pool.
struct SwimLength: Identifiable, Hashable, Sendable {
    let index: Int
    let start: Date
    let durationSec: Double
    let distanceMeters: Double
    let strokes: Int?
    let strokeStyle: SwimStroke

    var id: Int { index }

    var end: Date {
        start.addingTimeInterval(durationSec)
    }

    /// Seconds + strokes for this length. Lower means smoother, more efficient swimming.
    var swolf: Double? {
        strokes.map { durationSec + Double($0) }
    }
}

/// A heart-rate sample taken during a swim.
struct HRPoint: Hashable, Sendable {
    let date: Date
    let bpm: Double
}

/// Per-length and heart-rate data for one swim. Loaded lazily when a swim is shown.
struct SwimDetail: Hashable, Sendable {
    let swimID: UUID
    let lengths: [SwimLength]
    let heartRate: [HRPoint]

    static func empty(for swimID: UUID) -> SwimDetail {
        SwimDetail(swimID: swimID, lengths: [], heartRate: [])
    }
}
