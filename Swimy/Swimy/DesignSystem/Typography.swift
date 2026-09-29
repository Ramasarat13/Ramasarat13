import SwiftUI

/// Text styles. Always system text styles (never fixed sizes) so Dynamic Type works.
extension Font {
    /// Metric values: numbers don't jiggle when they count up.
    static var metricValue: Font { .title.weight(.semibold).monospacedDigit() }

    /// Metric labels, shown uppercase next to a small icon.
    static var metricLabel: Font { .caption.weight(.semibold) }

    /// Units after a value, e.g. the "m" in "500 m".
    static var metricUnit: Font { .subheadline }

    /// The big number on the Lifetime pool tile.
    static var lifetimeNumber: Font { .largeTitle.weight(.bold).monospacedDigit() }

    /// Section titles such as "Past swims".
    static var sectionTitle: Font { .title3.weight(.bold) }
}
