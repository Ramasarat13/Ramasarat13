import SwiftUI

/// Animation tokens (spec: Motion).
enum Motion {
    /// Layout changes: cards appearing, sections expanding.
    static var layout: Animation { .smooth }

    /// Taps and small state changes.
    static var tap: Animation { .snappy }

    /// Only for celebrations: a personal best or a milestone.
    static var celebrate: Animation { .bouncy }

    /// With Reduce Motion on, movement becomes a short cross-fade.
    static func adaptive(_ animation: Animation, reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : animation
    }
}
