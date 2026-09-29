import Foundation

/// Pure swim maths: summaries, "your usual" and comparisons.
/// No UI and no HealthKit here, so every rule is easy to unit test.
enum MetricsEngine {
    /// "Usual" is the mean of this many previous swims.
    static let usualWindow = 5
    /// Comparisons are hidden until there are at least this many previous swims.
    static let minimumPreviousSwims = 2
    /// Changes smaller than this (3%) read as "About your usual".
    static let aboutUsualThreshold = 0.03
    /// Swims shorter than 50 m or 2 minutes stay in lists but are left out of averages and bests.
    static let minimumCountableDistanceMeters = 50.0
    static let minimumCountableDurationSec = 120.0

    // MARK: - Summaries

    static func isCountable(_ swim: Swim) -> Bool {
        swim.totalDistanceMeters >= minimumCountableDistanceMeters
            && swim.totalDurationSec >= minimumCountableDurationSec
    }

    /// Share of lengths per stroke style (0...1).
    static func strokeMix(of lengths: [SwimLength]) -> [SwimStroke: Double] {
        guard !lengths.isEmpty else { return [:] }
        var counts: [SwimStroke: Int] = [:]
        for length in lengths {
            counts[length.strokeStyle, default: 0] += 1
        }
        return counts.mapValues { Double($0) / Double(lengths.count) }
    }

    /// Mean SWOLF over the lengths that have a stroke count. `nil` if none do.
    static func averageSwolf(of lengths: [SwimLength]) -> Double? {
        let values = lengths.compactMap { $0.swolf }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    // MARK: - Comparison to your usual

    /// The number used to compare a metric between swims.
    /// Pace is in seconds per 100 m so 25 m and 25 yd pools compare fairly.
    static func comparableValue(of metric: SwimMetric, for swim: Swim) -> Double? {
        switch metric {
        case .time: return swim.totalDurationSec
        case .distance: return swim.totalDistanceMeters
        case .pace: return swim.pacePer100Meters
        case .heartRate: return swim.avgHeartRate
        case .swolf: return swim.avgSwolf
        case .calories: return swim.activeCalories
        case .poolLength, .lengths: return nil
        }
    }

    /// Your usual: the mean of the previous 5 countable swims of the same location
    /// type (pool or open water) that have this metric. For SWOLF, only swims in the
    /// same pool length count. `nil` when fewer than 2 such swims exist.
    static func usual(of metric: SwimMetric, before swim: Swim, in history: [Swim]) -> Double? {
        let values = history
            .filter { other in
                other.id != swim.id
                    && other.startDate < swim.startDate
                    && other.locationType == swim.locationType
                    && isCountable(other)
                    && (metric != .swolf || samePoolLength(other, swim))
            }
            .sorted { $0.startDate > $1.startDate }
            .compactMap { comparableValue(of: metric, for: $0) }
            .prefix(usualWindow)
        guard values.count >= minimumPreviousSwims else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    /// How this swim compares with your usual. `nil` when there isn't enough history,
    /// the swim is too short to count, or the metric isn't comparable.
    static func comparison(of metric: SwimMetric, for swim: Swim, in history: [Swim]) -> Comparison? {
        guard metric.isComparable,
              isCountable(swim),
              let value = comparableValue(of: metric, for: swim),
              let baseline = usual(of: metric, before: swim, in: history),
              baseline > 0
        else { return nil }
        return Comparison(metric: metric, value: value, usual: baseline, change: (value - baseline) / baseline)
    }

    static func samePoolLength(_ a: Swim, _ b: Swim) -> Bool {
        guard let first = a.poolLengthMeters, let second = b.poolLengthMeters else { return false }
        return abs(first - second) < 0.01
    }
}
