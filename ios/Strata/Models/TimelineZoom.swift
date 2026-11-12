import CoreGraphics
import Foundation

/// How much each event says. Spreading two fingers moves up a level, pinching moves down.
/// The text never changes size: every level adds words to the one before.
enum ZoomLevel: Int, CaseIterable, Comparable, Hashable, Sendable {
    /// Event titles only.
    case titles
    /// Titles with their start times.
    case times
    /// Adds the end time, place and calendar.
    case details
    /// Adds the event's notes.
    case notes

    static func < (lhs: ZoomLevel, rhs: ZoomLevel) -> Bool { lhs.rawValue < rhs.rawValue }

    var label: String {
        switch self {
        case .titles: "Titles"
        case .times: "Times"
        case .details: "Details"
        case .notes: "Notes"
        }
    }

    var lessDetail: ZoomLevel? { ZoomLevel(rawValue: rawValue - 1) }
    var moreDetail: ZoomLevel? { ZoomLevel(rawValue: rawValue + 1) }
}

/// Maps a pinch onto a continuous zoom value, where each whole number is a level.
enum TimelineZoom {
    static let minimum = Double(ZoomLevel.titles.rawValue)
    static let maximum = Double(ZoomLevel.notes.rawValue)
    /// How far past either end a pinch can pull before it stops, like a photo at its limits.
    static let overscroll = 0.3
    /// Spreading two fingers to this multiple of their starting distance moves one level,
    /// so one comfortable pinch travels from titles to full notes.
    static let magnificationPerLevel = 1.35

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
        return ZoomLevel(rawValue: Int(clamped.rounded())) ?? .titles
    }

    /// The level a pinch settles on when released. A quick pinch carries a little further.
    static func settledLevel(for zoom: Double, velocity: Double) -> ZoomLevel {
        let carry = min(max(velocity * 0.12, -0.4), 0.4)
        return level(for: zoom + carry)
    }
}

/// What the timeline shows at a given zoom. Everything is derived from the continuous
/// value, so details arrive gradually under the fingers instead of popping in per level.
struct TimelineMetrics: Equatable {
    let zoom: Double
    /// Dynamic Type multiplier.
    let typeScale: CGFloat
    let level: ZoomLevel

    init(zoom: Double, typeScale: CGFloat = 1) {
        self.zoom = zoom
        self.typeScale = typeScale
        self.level = TimelineZoom.level(for: zoom)
    }

    var headerSize: CGFloat { 17 * typeScale }
    var titleSize: CGFloat { 17 * typeScale }
    var timeSize: CGFloat { 14 * typeScale }
    var dotSize: CGFloat { 5 * typeScale }

    private static func unit(_ value: Double) -> Double { min(max(value, 0), 1) }

    /// 0 at Titles, 1 at Times: how far the start times have slid in.
    var timeReveal: Double { Self.unit(zoom) }
    /// 0 at Times, 1 at Details: how much of the place and calendar is written out.
    var detailReveal: Double { Self.unit(zoom - 1) }
    /// 0 at Details, 1 at Notes: how much of the notes is written out.
    var notesReveal: Double { Self.unit(zoom - 2) }

    var timeColumnWidth: CGFloat { 76 * typeScale * CGFloat(timeReveal) }

    /// Rows breathe a little more as they fill with text.
    var rowSpacing: CGFloat { 13 + 7 * CGFloat(Self.unit(zoom / TimelineZoom.maximum)) }
    var dayPadding: CGFloat { 22 + 4 * CGFloat(Self.unit(zoom / TimelineZoom.maximum)) }

    /// Changes several times per level. Layout shifts are animated whenever it does,
    /// so lines pushed down by arriving words glide instead of jumping.
    var step: Int { Int((zoom * 14).rounded(.down)) }
}

/// A stretch of text in one color, revealed word by word.
struct RevealRun: Equatable {
    let text: String
    /// Marks which color the view should draw the run in.
    let role: Role

    enum Role: Equatable {
        case secondary, calendar, notes
    }
}

/// Works out which words of a set of runs are showing at a given fraction.
enum WordReveal {
    struct Piece: Equatable {
        let text: String
        let role: RevealRun.Role
        /// 1 for words that have fully arrived; less for the word arriving now.
        let opacity: Double
    }

    /// The runs' words up to `fraction` of the total, with the newest word partly faded.
    static func pieces(for runs: [RevealRun], fraction: Double) -> [Piece] {
        guard fraction > 0 else { return [] }
        if fraction >= 1 {
            return runs.filter { !$0.text.isEmpty }.map { Piece(text: $0.text, role: $0.role, opacity: 1) }
        }
        let words = runs.map { $0.text.split(whereSeparator: \.isWhitespace) }
        let total = words.reduce(0) { $0 + $1.count }
        guard total > 0 else { return [] }

        var budget = fraction * Double(total)
        var result: [Piece] = []
        for (run, runWords) in zip(runs, words) where budget > 0 {
            let whole = min(Int(budget.rounded(.down)), runWords.count)
            if whole > 0 {
                result.append(Piece(text: runWords.prefix(whole).joined(separator: " "), role: run.role, opacity: 1))
            }
            budget -= Double(whole)
            if whole < runWords.count {
                if budget > 0 {
                    result.append(Piece(text: String(runWords[whole]), role: run.role, opacity: budget))
                }
                budget = 0
            }
        }
        return result
    }
}
