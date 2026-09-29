import SwiftUI

// MARK: - Colour tokens
//
// Brand colours live in Resources/Assets.xcassets as colour sets, each with a light
// and a dark variant. Edit them there with Xcode's colour picker. Xcode turns each
// colour set into a Swift name automatically:
//
//   MetricPace     → Color.metricPace       Pace values, charts, icons
//   MetricHeart    → Color.metricHeart      Heart rate
//   MetricSwolf    → Color.metricSwolf      SWOLF
//   MetricDistance → Color.metricDistance   Distance, lengths
//   PoolTile       → Color.poolTile         Lifetime tile, share cards
//   PoolTileGrout  → Color.poolTileGrout    Tile lines
//   PoolTileDeep   → Color.poolTileDeep     Deep water, behind white text
//   Improve        → Color.improve          "Better than usual" chip
//
// The four metric colours were checked for colour-blind separation and 3:1 contrast
// against cards in both light and dark mode. `Improve` is darker than system green
// in light mode so chip text reaches 4.5:1.

extension Color {
    /// Metric cards and other raised surfaces.
    static var cardBackground: Color { Color(uiColor: .secondarySystemGroupedBackground) }

    /// Screen background behind cards.
    static var screenBackground: Color { Color(uiColor: .systemGroupedBackground) }
}

extension SwimMetric {
    /// The colour for this metric's icon and charts. Text stays in primary/secondary.
    var tint: Color {
        switch self {
        case .pace, .time: .metricPace
        case .heartRate, .calories: .metricHeart
        case .swolf: .metricSwolf
        case .distance, .lengths, .poolLength: .metricDistance
        }
    }

    var symbolName: String {
        switch self {
        case .time: "stopwatch"
        case .distance: "arrow.left.and.right"
        case .pace: "speedometer"
        case .heartRate: "heart.fill"
        case .swolf: "water.waves"
        case .poolLength: "ruler"
        case .lengths: "arrow.left.arrow.right"
        case .calories: "flame.fill"
        }
    }
}
