import CoreGraphics
import Foundation

/// The four depths of the timeline. Pinching moves between them.
enum ZoomLevel: Int, CaseIterable, Comparable, Sendable {
    /// One line per day: the date and a dot per event.
    case glance
    /// One line per day with the event titles.
    case titles
    /// One line per event with its start time.
    case schedule
    /// Every event with its end time, duration, place and notes.
    case details

    static func < (lhs: ZoomLevel, rhs: ZoomLevel) -> Bool { lhs.rawValue < rhs.rawValue }

    var label: String {
        switch self {
        case .glance: "Glance"
        case .titles: "Titles"
        case .schedule: "Schedule"
        case .details: "Details"
        }
    }

    var lessDetail: ZoomLevel? { ZoomLevel(rawValue: rawValue - 1) }
    var moreDetail: ZoomLevel? { ZoomLevel(rawValue: rawValue + 1) }
}

/// Maps a pinch onto a continuous zoom value, where each whole number is a level.
enum TimelineZoom {
    static let minimum = Double(ZoomLevel.glance.rawValue)
    static let maximum = Double(ZoomLevel.details.rawValue)
    /// How far past either end a pinch can pull before it stops, like a photo at its limits.
    static let overscroll = 0.35
    /// Spreading two fingers to this multiple of their starting distance moves one level.
    static let magnificationPerLevel = 1.6

    static func value(base: Double, magnification: Double) -> Double {
        let steps = log(max(magnification, 0.01)) / log(magnificationPerLevel)
        return rubberBand(base + steps)
    }

    static func rubberBand(_ raw: Double) -> Double {
        if raw > maximum {
            return maximum + overscroll * (1 - exp(-(raw - maximum) / overscroll))
        }
        if raw < minimum {
            return minimum - overscroll * (1 - exp(-(minimum - raw) / overscroll))
        }
        return raw
    }

    static func level(for zoom: Double) -> ZoomLevel {
        let clamped = min(max(zoom, minimum), maximum)
        return ZoomLevel(rawValue: Int(clamped.rounded())) ?? .schedule
    }

    /// The level a pinch settles on when released. A quick pinch carries a little further.
    static func settledLevel(for zoom: Double, velocity: Double) -> ZoomLevel {
        let carry = min(max(velocity * 0.12, -0.4), 0.4)
        return level(for: zoom + carry)
    }
}

/// Every size the timeline draws with, derived from the continuous zoom so text
/// grows and shrinks under the fingers instead of jumping between levels.
struct TimelineMetrics: Equatable {
    let zoom: Double
    let typeScale: CGFloat
    let level: ZoomLevel

    init(zoom: Double, typeScale: CGFloat = 1) {
        self.zoom = zoom
        self.typeScale = typeScale
        self.level = TimelineZoom.level(for: zoom)
    }

    /// Interpolates between one value per level, continuing the slope past either end.
    private func value(_ glance: CGFloat, _ titles: CGFloat, _ schedule: CGFloat, _ details: CGFloat) -> CGFloat {
        let stops = [glance, titles, schedule, details]
        let clamped = min(max(zoom, TimelineZoom.minimum), TimelineZoom.maximum)
        let lower = min(Int(clamped.rounded(.down)), stops.count - 2)
        let fraction = CGFloat(zoom) - CGFloat(lower)
        return stops[lower] + (stops[lower + 1] - stops[lower]) * fraction
    }

    var titleSize: CGFloat { value(12, 15, 17, 20) * typeScale }
    var metaSize: CGFloat { value(11, 12, 13, 14) * typeScale }
    var dateSize: CGFloat { value(12, 15, 17, 20) * typeScale }
    var monthSize: CGFloat { value(11, 12, 13, 14) * typeScale }
    var dotSize: CGFloat { value(6, 7, 8, 8) * typeScale }
    var dateColumnWidth: CGFloat { value(52, 60, 68, 78) * typeScale }
    var timeColumnWidth: CGFloat { value(52, 56, 62, 68) * typeScale }
    var gutter: CGFloat { value(8, 10, 12, 14) }
    var dayPadding: CGFloat { value(4, 8, 12, 18) }
    var eventSpacing: CGFloat { value(4, 6, 9, 16) }
    var monthTopPadding: CGFloat { value(14, 20, 28, 34) }

    /// Fades a level's content out as the zoom nears a level that is laid out
    /// differently, so the swap between layouts is never seen.
    var contentOpacity: Double {
        let distance = abs(zoom - Double(level.rawValue))
        // Schedule and Details share a layout, so nothing fades between them.
        if level == .details || (level == .schedule && zoom > Double(level.rawValue)) { return 1 }
        let progress = min(max((distance - 0.25) / 0.25, 0), 1)
        return 1 - progress * progress * (3 - 2 * progress)
    }

    /// 0 when the extra lines of the Details level first appear, 1 once fully there.
    var detailReveal: Double {
        min(max((zoom - 2.5) / 0.5, 0), 1)
    }
}
