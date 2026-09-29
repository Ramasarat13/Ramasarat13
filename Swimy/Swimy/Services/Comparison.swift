import Foundation

/// A swim's value compared with the swimmer's usual.
struct Comparison: Equatable, Sendable {
    enum Direction: Equatable, Sendable {
        case aboutUsual
        case higher
        case lower
    }

    let metric: SwimMetric
    let value: Double
    let usual: Double
    /// Signed change vs usual: -0.06 means 6% lower.
    let change: Double

    var direction: Direction {
        if abs(change) < MetricsEngine.aboutUsualThreshold { return .aboutUsual }
        return change > 0 ? .higher : .lower
    }

    /// Green only for a real improvement. Everything else stays neutral:
    /// encourage, never judge.
    var isImprovement: Bool {
        switch (metric.betterDirection, direction) {
        case (.lower, .lower), (.higher, .higher): true
        default: false
        }
    }

    /// Whole percent, e.g. 6 for a 6% change.
    var percent: Int {
        Int((abs(change) * 100).rounded())
    }

    /// The arrow shows which way the number moved. Colour and VoiceOver say whether that's good.
    var symbolName: String {
        switch direction {
        case .aboutUsual: "equal"
        case .higher: "arrowtriangle.up.fill"
        case .lower: "arrowtriangle.down.fill"
        }
    }

    /// Chip text, e.g. "6% vs usual".
    var chipText: String {
        direction == .aboutUsual ? "About your usual" : "\(percent)% vs usual"
    }

    /// What VoiceOver reads, e.g. "6 percent faster than usual".
    var spokenText: String {
        guard direction != .aboutUsual else { return "About your usual" }
        return "\(percent) percent \(changeWord) than usual"
    }

    private var changeWord: String {
        let isHigher = direction == .higher
        switch metric {
        case .pace: return isHigher ? "slower" : "faster"
        case .distance: return isHigher ? "farther" : "shorter"
        case .time: return isHigher ? "longer" : "shorter"
        default: return isHigher ? "higher" : "lower"
        }
    }
}
