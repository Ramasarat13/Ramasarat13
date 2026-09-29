import Foundation

/// Every number the app shows for a swim, with its plain-English explainer.
enum SwimMetric: String, CaseIterable, Identifiable, Sendable {
    case time
    case distance
    case pace
    case heartRate
    case swolf
    case poolLength
    case lengths
    case calories

    var id: String { rawValue }

    /// Which way is "better" when comparing with your usual.
    enum BetterDirection: Sendable {
        case lower
        case higher
        /// Neither direction is better (e.g. heart rate): shown in neutral grey.
        case neither
    }

    var title: String {
        switch self {
        case .time: "Time"
        case .distance: "Distance"
        case .pace: "Pace"
        case .heartRate: "Heart rate"
        case .swolf: "SWOLF"
        case .poolLength: "Pool length"
        case .lengths: "Lengths"
        case .calories: "Active calories"
        }
    }

    var betterDirection: BetterDirection {
        switch self {
        case .pace, .swolf: .lower
        case .distance: .higher
        case .time, .heartRate, .calories, .poolLength, .lengths: .neither
        }
    }

    /// Whether a "vs usual" chip makes sense for this metric.
    /// Pool length and lengths depend on the pool, so they aren't compared.
    var isComparable: Bool {
        switch self {
        case .poolLength, .lengths: false
        default: true
        }
    }

    // MARK: Explainer copy (ⓘ sheet). Phase 3 moves this into MetricExplainers.json.

    /// What it is, in one sentence.
    var explainer: String {
        switch self {
        case .time: "How long your swim lasted, rests included."
        case .distance: "How far you swam."
        case .pace: "How long it takes you to swim 100 m. Lower is faster."
        case .heartRate: "How hard your heart worked."
        case .swolf: "Your swimming efficiency score. Lower means you swam more smoothly."
        case .poolLength: "The length of the pool, as you set it on your Apple Watch."
        case .lengths: "How many times you swam from one end of the pool to the other."
        case .calories: "The extra energy your body used because you were swimming."
        }
    }

    /// How it's worked out, in plain words.
    var howItWorks: String {
        switch self {
        case .time:
            "Counted from the moment you started the workout to the moment you ended it."
        case .distance:
            "Your Apple Watch adds up every length. In open water it uses GPS."
        case .pace:
            "Your swimming time, with rests left out, shared out over every 100 m you swam. In a yard pool it's per 100 yards."
        case .heartRate:
            "The average of all the heart-rate readings your Apple Watch took during the swim."
        case .swolf:
            "For each length, add the seconds it took to the number of strokes you took. Your swim's SWOLF is the average of all your lengths."
        case .poolLength:
            "You pick it on your Apple Watch before a pool swim. Pace and SWOLF use its unit: metres or yards."
        case .lengths:
            "Your Apple Watch counts one each time you push off the wall."
        case .calories:
            "Your Apple Watch estimates it from your movement and heart rate."
        }
    }

    /// An extra tip shown in a callout, when there is one.
    var note: String? {
        switch self {
        case .swolf:
            "SWOLF depends on pool length, so Swimy only compares it between swims in the same size of pool."
        case .pace:
            "Swimy compares your pace with your own usual, never with other people."
        default:
            nil
        }
    }
}
