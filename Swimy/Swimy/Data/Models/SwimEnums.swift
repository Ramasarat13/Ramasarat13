import Foundation

/// Where a swim happened. Read from `HKMetadataKeySwimmingLocationType`.
enum LocationType: String, Codable, Sendable, CaseIterable {
    case pool
    case openWater
    case unknown

    var title: String {
        switch self {
        case .pool: "Pool Swim"
        case .openWater: "Open Water Swim"
        case .unknown: "Swim"
        }
    }

    var symbolName: String {
        switch self {
        case .pool, .unknown: "figure.pool.swim"
        case .openWater: "figure.open.water.swim"
        }
    }
}

/// The unit a pool was set up in on the Watch (a 25 m pool vs a 25 yd pool).
/// Pool metrics (pace per 100, SWOLF, lengths) always use this unit.
enum PoolUnit: String, Codable, Sendable, CaseIterable {
    case meters
    case yards

    var metersPerUnit: Double {
        switch self {
        case .meters: 1.0
        case .yards: 0.9144
        }
    }

    /// Short symbol shown after values, e.g. "500 m".
    var symbol: String {
        switch self {
        case .meters: "m"
        case .yards: "yd"
        }
    }

    /// Full name used by VoiceOver.
    var spokenName: String {
        switch self {
        case .meters: "metres"
        case .yards: "yards"
        }
    }

    func fromMeters(_ meters: Double) -> Double {
        meters / metersPerUnit
    }
}

/// Stroke style recorded per length by Apple Watch.
enum SwimStroke: String, Codable, Sendable, CaseIterable {
    case freestyle
    case backstroke
    case breaststroke
    case butterfly
    case mixed
    case kickboard
    case unknown

    var title: String {
        switch self {
        case .freestyle: "Freestyle"
        case .backstroke: "Backstroke"
        case .breaststroke: "Breaststroke"
        case .butterfly: "Butterfly"
        case .mixed: "Mixed"
        case .kickboard: "Kickboard"
        case .unknown: "Unknown"
        }
    }
}

/// The unit for totals (month, lifetime, multi-swim ranges). Chosen in onboarding and Profile.
enum DistanceUnit: String, Codable, Sendable, CaseIterable, Identifiable {
    case kilometers
    case miles

    var id: String { rawValue }

    var title: String {
        switch self {
        case .kilometers: "Kilometres"
        case .miles: "Miles"
        }
    }

    var symbol: String {
        switch self {
        case .kilometers: "km"
        case .miles: "mi"
        }
    }

    var spokenName: String {
        switch self {
        case .kilometers: "kilometres"
        case .miles: "miles"
        }
    }

    var metersPerUnit: Double {
        switch self {
        case .kilometers: 1000.0
        case .miles: 1609.344
        }
    }

    /// Unit for a single open-water swim, which has no pool: metres with km, yards with miles.
    var shortUnit: PoolUnit {
        switch self {
        case .kilometers: .meters
        case .miles: .yards
        }
    }

    func fromMeters(_ meters: Double) -> Double {
        meters / metersPerUnit
    }
}

/// Light / dark mode override from Profile → Appearance.
enum Appearance: String, Codable, Sendable, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}
