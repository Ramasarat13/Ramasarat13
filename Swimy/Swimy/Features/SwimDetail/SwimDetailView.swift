import SwiftUI

/// One swim in detail. Phase 1 shows the overview grid and recording details.
///
/// Phase 3 adds: How you swam (stroke breakdown), Sets and rest, Analytics charts
/// with splits and scrubbing, and Heart rate zones. Phase 6 adds the Share button.
struct SwimDetailView: View {
    let swim: Swim

    @Environment(SwimStore.self) private var store
    @Environment(SettingsStore.self) private var settings
    @State private var infoMetric: SwimMetric?

    private let overviewMetrics: [SwimMetric] = [
        .time, .distance, .pace, .heartRate, .swolf, .poolLength, .lengths, .calories,
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                Text(swim.startDate.formatted(date: .complete, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                overview
                recordingDetails
            }
            .padding(.horizontal, Spacing.medium)
            .padding(.bottom, Spacing.large)
        }
        .background(Color.screenBackground)
        .navigationTitle(swim.locationType.title)
        .sheet(item: $infoMetric) { metric in
            InfoSheet(metric: metric)
        }
        .task {
            await store.loadDetail(for: swim)
        }
    }

    // MARK: - Overview

    /// Metrics the swim doesn't have are hidden, never shown as 0 or "--".
    private var overview: some View {
        let metrics = overviewMetrics.filter {
            SwimFormatter.format($0, for: swim, distanceUnit: settings.distanceUnit) != nil
        }
        return MetricGrid(items: metrics) { metric in
            if let value = SwimFormatter.format(metric, for: swim, distanceUnit: settings.distanceUnit) {
                MetricCard(
                    metric: metric,
                    value: value,
                    comparison: store.comparison(of: metric, for: swim),
                    onInfo: { infoMetric = metric }
                )
            }
        }
    }

    // MARK: - Recording details

    private var recordingDetails: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("Recording details")
                .font(.sectionTitle)

            VStack(spacing: 0) {
                let rows = detailRows
                ForEach(rows) { row in
                    LabeledContent(row.label, value: row.value)
                        .font(.subheadline)
                        .padding(.horizontal, Spacing.medium)
                        .padding(.vertical, Spacing.small)
                    if row.id != rows.last?.id {
                        Divider()
                            .padding(.leading, Spacing.medium)
                    }
                }
            }
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        }
    }

    private var detailRows: [DetailRow] {
        var rows: [DetailRow] = []
        if let device = swim.deviceName {
            rows.append(DetailRow(label: "Device", value: device))
        }
        rows.append(DetailRow(label: "Source", value: swim.sourceName))
        let start = swim.startDate.formatted(date: .omitted, time: .shortened)
        let end = swim.endDate.formatted(date: .omitted, time: .shortened)
        rows.append(DetailRow(label: "Time", value: "\(start) – \(end)"))
        rows.append(DetailRow(label: "Location", value: swim.locationType == .openWater ? "Open water" : "Pool"))
        if let length = SwimFormatter.format(.poolLength, for: swim, distanceUnit: settings.distanceUnit) {
            rows.append(DetailRow(label: "Pool length", value: "\(length.value) \(length.unit)"))
        }
        if let celsius = swim.waterTemperatureCelsius {
            let temperature = Measurement(value: celsius, unit: UnitTemperature.celsius)
            let text = temperature.formatted(.measurement(width: .abbreviated, usage: .weather))
            rows.append(DetailRow(label: "Water temperature", value: text))
        }
        return rows
    }
}

private struct DetailRow: Identifiable {
    let label: String
    let value: String

    var id: String { label }
}

#Preview {
    let store = SwimStore.preview()
    return NavigationStack {
        SwimDetailView(swim: store.swims[0])
    }
    .environment(store)
    .environment(SettingsStore())
    .environment(AppRouter())
}
