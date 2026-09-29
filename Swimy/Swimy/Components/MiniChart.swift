import Charts
import SwiftUI

/// The data behind a metric card's small chart.
enum MiniChartData: Hashable, Sendable {
    /// One bar per length (or group of lengths), oldest to newest.
    case bars([Double])
    /// A continuous line, e.g. heart rate over the swim.
    case line([Double])
    /// The lengths drawn as pool tiles.
    case lanes(Int)

    /// Latest-swim mini charts: per-length pace, heart rate over time, SWOLF per length,
    /// and the lengths drawing. `nil` when the swim doesn't have the data.
    static func make(for metric: SwimMetric, swim: Swim, detail: SwimDetail?) -> MiniChartData? {
        if metric == .distance {
            guard let count = swim.lengthCount, count > 0 else { return nil }
            return .lanes(count)
        }
        guard let detail else { return nil }
        switch metric {
        case .pace:
            let values = detail.lengths.map { $0.durationSec / swim.poolUnit.fromMeters($0.distanceMeters) * 100 }
            return values.count >= 2 ? .bars(bucketed(values)) : nil
        case .swolf:
            let values = detail.lengths.compactMap { $0.swolf }
            return values.count >= 2 ? .bars(bucketed(values)) : nil
        case .heartRate:
            let values = detail.heartRate.map { $0.bpm }
            return values.count >= 2 ? .line(bucketed(values, maxCount: 40)) : nil
        default:
            return nil
        }
    }

    /// Averages neighbouring values so a small chart never has more than `maxCount` marks.
    static func bucketed(_ values: [Double], maxCount: Int = 20) -> [Double] {
        guard values.count > maxCount, maxCount > 0 else { return values }
        let size = Double(values.count) / Double(maxCount)
        return (0..<maxCount).map { bucket in
            let lower = Int((Double(bucket) * size).rounded(.down))
            let upper = min(values.count, max(lower + 1, Int((Double(bucket + 1) * size).rounded(.down))))
            let slice = values[lower..<upper]
            return slice.reduce(0, +) / Double(slice.count)
        }
    }
}

/// A small, decorative chart for a metric card. No axes; the card's value carries the number.
struct MiniChart: View {
    let data: MiniChartData
    let tint: Color

    var body: some View {
        switch data {
        case .bars(let values):
            Chart(points(values)) { point in
                BarMark(
                    x: .value("Part", point.label),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(tint)
                .cornerRadius(2)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)

        case .line(let values):
            let low = (values.min() ?? 0) - 5
            let high = (values.max() ?? 0) + 5
            Chart(points(values)) { point in
                AreaMark(
                    x: .value("Time", point.index),
                    yStart: .value("Low", low),
                    yEnd: .value("Value", point.value)
                )
                .foregroundStyle(
                    LinearGradient(colors: [tint.opacity(0.25), tint.opacity(0)], startPoint: .top, endPoint: .bottom)
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Time", point.index),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(tint)
                .lineStyle(.init(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)
            }
            .chartYScale(domain: low...high)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)

        case .lanes(let count):
            LanesView(lengths: count, tint: tint)
        }
    }

    private func points(_ values: [Double]) -> [ChartPoint] {
        values.enumerated().map { ChartPoint(index: $0.offset, value: $0.element) }
    }
}

private struct ChartPoint: Identifiable {
    let index: Int
    let value: Double

    var id: Int { index }
    var label: String { "\(index)" }
}
