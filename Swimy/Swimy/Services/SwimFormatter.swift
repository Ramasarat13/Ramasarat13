import Foundation

/// A value split into number and unit, so cards can style them separately ("500" + "m").
struct FormattedValue: Equatable, Sendable {
    let value: String
    let unit: String
    /// What VoiceOver reads, e.g. "2 minutes, 48 seconds per 100 metres".
    let spoken: String
}

/// Turns raw swim numbers into display text.
///
/// Unit rules (spec F8):
/// - Pool metrics (pace, SWOLF, lengths, a pool swim's distance) use the pool's own unit.
/// - A single open-water swim uses metres with the km setting, yards with miles.
/// - Totals (several swims, months, lifetime) use the chosen distance unit.
enum SwimFormatter {
    // MARK: - Metric values

    /// `nil` when the swim doesn't have this metric, so the card is hidden instead of showing "--".
    static func format(_ metric: SwimMetric, for swim: Swim, distanceUnit: DistanceUnit) -> FormattedValue? {
        switch metric {
        case .time:
            let seconds = swim.totalDurationSec
            return FormattedValue(value: duration(seconds), unit: "", spoken: spokenDuration(seconds))

        case .distance:
            let unit = displayUnit(for: swim, distanceUnit: distanceUnit)
            let amount = unit.fromMeters(swim.totalDistanceMeters)
            return FormattedValue(
                value: number(amount),
                unit: unit.symbol,
                spoken: "\(number(amount)) \(unit.spokenName)"
            )

        case .pace:
            let unit = displayUnit(for: swim, distanceUnit: distanceUnit)
            guard let seconds = pacePer100(swim, in: unit) else { return nil }
            return FormattedValue(
                value: pace(seconds),
                unit: "/100 \(unit.symbol)",
                spoken: "\(spokenDuration(seconds)) per 100 \(unit.spokenName)"
            )

        case .heartRate:
            guard let bpm = swim.avgHeartRate else { return nil }
            return FormattedValue(value: number(bpm), unit: "bpm", spoken: "\(number(bpm)) beats per minute")

        case .swolf:
            guard let swolf = swim.avgSwolf else { return nil }
            return FormattedValue(value: number(swolf), unit: "", spoken: number(swolf))

        case .poolLength:
            guard let length = swim.poolLength else { return nil }
            return FormattedValue(
                value: number(length),
                unit: swim.poolUnit.symbol,
                spoken: "\(number(length)) \(swim.poolUnit.spokenName)"
            )

        case .lengths:
            guard let count = swim.lengthCount else { return nil }
            return FormattedValue(value: "\(count)", unit: "", spoken: count == 1 ? "1 length" : "\(count) lengths")

        case .calories:
            guard let kcal = swim.activeCalories else { return nil }
            return FormattedValue(value: number(kcal), unit: "kcal", spoken: "\(number(kcal)) kilocalories")
        }
    }

    /// The unit a single swim's distance and pace are shown in.
    static func displayUnit(for swim: Swim, distanceUnit: DistanceUnit) -> PoolUnit {
        swim.locationType == .pool ? swim.poolUnit : distanceUnit.shortUnit
    }

    /// Seconds per 100 of `unit`, rests excluded.
    static func pacePer100(_ swim: Swim, in unit: PoolUnit) -> Double? {
        guard swim.totalDistanceMeters > 0, swim.activeDurationSec > 0 else { return nil }
        return swim.activeDurationSec / unit.fromMeters(swim.totalDistanceMeters) * 100
    }

    /// A total over several swims, e.g. "37.4" + "km".
    static func totalDistance(meters: Double, unit: DistanceUnit) -> FormattedValue {
        let amount = number(unit.fromMeters(meters), fractionDigits: 1)
        return FormattedValue(value: amount, unit: unit.symbol, spoken: "\(amount) \(unit.spokenName)")
    }

    /// A single swim's distance as one string, e.g. "1,500 m".
    static func swimDistance(_ swim: Swim, distanceUnit: DistanceUnit) -> String {
        let unit = displayUnit(for: swim, distanceUnit: distanceUnit)
        return "\(number(unit.fromMeters(swim.totalDistanceMeters))) \(unit.symbol)"
    }

    // MARK: - Building blocks

    /// Pace as minutes and seconds with prime marks: 168 → "2′48″".
    static func pace(_ secondsPer100: Double) -> String {
        let total = Int(secondsPer100.rounded())
        return "\(total / 60)′\(twoDigits(total % 60))″"
    }

    /// Elapsed time: 2535 → "42:15", 3730 → "1:02:10".
    static func duration(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return "\(hours):\(twoDigits(minutes)):\(twoDigits(secs))"
        }
        return "\(minutes):\(twoDigits(secs))"
    }

    /// "42 minutes, 15 seconds"
    static func spokenDuration(_ seconds: Double) -> String {
        Duration.seconds(Int(seconds.rounded()))
            .formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide))
    }

    /// Locale-aware number, e.g. "1,500".
    static func number(_ value: Double, fractionDigits: Int = 0, locale: Locale = .autoupdatingCurrent) -> String {
        value.formatted(.number.precision(.fractionLength(fractionDigits)).locale(locale))
    }

    static func swimCount(_ count: Int) -> String {
        count == 1 ? "1 swim" : "\(count) swims"
    }

    // MARK: - Dates

    /// Friendly swim date: "Today, 7:05 AM", "Yesterday, 6:40 PM", "Monday, 7:10 AM", "22 Sep".
    static func swimDate(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        let time = date.formatted(date: .omitted, time: .shortened)
        if calendar.isDate(date, inSameDayAs: now) {
            return "Today, \(time)"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "Yesterday, \(time)"
        }
        let startOfToday = calendar.startOfDay(for: now)
        if let weekAgo = calendar.date(byAdding: .day, value: -6, to: startOfToday), date >= weekAgo {
            return "\(date.formatted(.dateTime.weekday(.wide))), \(time)"
        }
        if calendar.isDate(date, equalTo: now, toGranularity: .year) {
            return date.formatted(.dateTime.day().month(.abbreviated))
        }
        return date.formatted(.dateTime.day().month(.abbreviated).year())
    }

    private static func twoDigits(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}
