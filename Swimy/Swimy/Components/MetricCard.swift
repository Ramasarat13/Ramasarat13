import SwiftUI

/// Icon + label, value + unit, optional comparison chip, optional mini chart, ⓘ button.
struct MetricCard: View {
    let metric: SwimMetric
    let value: FormattedValue
    var comparison: Comparison?
    var chart: MiniChartData?
    var onInfo: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            label
            valueText
            if let comparison {
                ComparisonChip(comparison: comparison)
            }
            if let chart {
                Spacer(minLength: Spacing.xxSmall)
                MiniChart(data: chart, tint: metric.tint)
                    .frame(height: 40)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(Spacing.medium)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if let onInfo {
                infoButton(action: onInfo)
            }
        }
    }

    private var label: some View {
        HStack(spacing: 6) {
            Image(systemName: metric.symbolName)
                .foregroundStyle(metric.tint)
            Text(metric.title.uppercased())
                .foregroundStyle(.secondary)
        }
        .font(.metricLabel)
        .lineLimit(1)
        .padding(.trailing, onInfo == nil ? 0 : 32)
    }

    private var valueText: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xxSmall) {
            Text(value.value)
                .font(.metricValue)
                .contentTransition(.numericText())
            if !value.unit.isEmpty {
                Text(value.unit)
                    .font(.metricUnit)
                    .foregroundStyle(.secondary)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }

    private func infoButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "info.circle")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: minimumTapTarget, height: minimumTapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(Spacing.xxSmall)
        .accessibilityLabel("About \(metric.title)")
    }

    /// e.g. "Pace, 2 minutes, 21 seconds per 100 metres, 6 percent faster than usual"
    private var accessibilityText: String {
        var text = "\(metric.title), \(value.spoken)"
        if let comparison {
            text += ", \(comparison.spokenText)"
        }
        return text
    }
}

/// Lays cards out in two equal-height columns, or one column at accessibility text sizes.
struct MetricGrid<Item, Cell: View>: View {
    let items: [Item]
    @ViewBuilder let cell: (Item) -> Cell

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let columns = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        let rowCount = (items.count + columns - 1) / columns
        VStack(spacing: Spacing.small) {
            ForEach(0..<rowCount, id: \.self) { row in
                let indices = Array(row * columns ..< min((row + 1) * columns, items.count))
                HStack(alignment: .top, spacing: Spacing.small) {
                    ForEach(indices, id: \.self) { index in
                        cell(items[index])
                            .frame(maxHeight: .infinity)
                    }
                    // Keep a lone last card at half width.
                    ForEach(0..<(columns - indices.count), id: \.self) { _ in
                        Color.clear
                            .frame(height: 0)
                            .frame(maxWidth: .infinity)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    let store = SwimStore.preview()
    let swim = store.swims[0]
    let metrics: [SwimMetric] = [.pace, .heartRate, .swolf, .distance]
    return ScrollView {
        MetricGrid(items: metrics) { metric in
            if let value = SwimFormatter.format(metric, for: swim, distanceUnit: .kilometers) {
                MetricCard(
                    metric: metric,
                    value: value,
                    comparison: store.comparison(of: metric, for: swim),
                    chart: MiniChartData.make(for: metric, swim: swim, detail: store.detail(for: swim)),
                    onInfo: {}
                )
            }
        }
        .padding()
    }
    .background(Color.screenBackground)
}
