import SwiftUI

/// Home tab: the latest swim's key metrics, then the swims before it.
///
/// Phase 3 adds the "Latest swim ⌄" range menu (Last 3 / Last 7), the personal best
/// banner and This week. The header already opens the latest swim's detail.
struct SummaryView: View {
    @Environment(SwimStore.self) private var store
    @Environment(SettingsStore.self) private var settings
    @Environment(AppRouter.self) private var router

    @Namespace private var zoom
    @State private var infoMetric: SwimMetric?

    private let summaryMetrics: [SwimMetric] = [.pace, .heartRate, .swolf, .distance]

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Summary")
                .profileToolbar()
                .navigationDestination(for: Swim.self) { swim in
                    SwimDetailView(swim: swim)
                        .navigationTransition(.zoom(sourceID: swim.id, in: zoom))
                }
                .sheet(item: $infoMetric) { metric in
                    InfoSheet(metric: metric)
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let latest = store.latestSwim {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.large) {
                    latestSwimHeader(latest)
                    metricCards(for: latest)
                    pastSwimsSection
                }
                .padding(.horizontal, Spacing.medium)
                .padding(.bottom, Spacing.large)
            }
            .background { WaterHeaderBackground() }
            .refreshable { await store.refresh() }
        } else if store.status == .idle || store.status == .loading {
            ProgressView("Finding your swims…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.screenBackground)
        } else {
            NoSwimsView()
                .refreshable { await store.refresh() }
        }
    }

    // MARK: - Sections

    /// Tapping the header opens the latest swim.
    private func latestSwimHeader(_ swim: Swim) -> some View {
        NavigationLink(value: swim) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Spacing.xxSmall) {
                    Text("Latest swim")
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                Text("\(swim.locationType.title) · \(SwimFormatter.swimDate(swim.startDate))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .matchedTransitionSource(id: swim.id, in: zoom)
        .accessibilityHint("Opens the swim details")
    }

    private func metricCards(for swim: Swim) -> some View {
        let detail = store.detail(for: swim)
        let metrics = summaryMetrics.filter {
            SwimFormatter.format($0, for: swim, distanceUnit: settings.distanceUnit) != nil
        }
        return MetricGrid(items: metrics) { metric in
            if let value = SwimFormatter.format(metric, for: swim, distanceUnit: settings.distanceUnit) {
                MetricCard(
                    metric: metric,
                    value: value,
                    comparison: store.comparison(of: metric, for: swim),
                    chart: MiniChartData.make(for: metric, swim: swim, detail: detail),
                    onInfo: { infoMetric = metric }
                )
            }
        }
    }

    @ViewBuilder
    private var pastSwimsSection: some View {
        let pastSwims = Array(store.swims.dropFirst().prefix(3))
        if !pastSwims.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.small) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Past swims")
                        .font(.sectionTitle)
                    Spacer()
                    Button("See all") {
                        router.selectedTab = .activity
                    }
                    .font(.subheadline.weight(.semibold))
                }

                VStack(spacing: 0) {
                    ForEach(pastSwims) { swim in
                        NavigationLink(value: swim) {
                            SwimRow(swim: swim, showsChevron: true)
                                .padding(.horizontal, Spacing.medium)
                                .padding(.vertical, Spacing.small)
                        }
                        .buttonStyle(.plain)
                        .matchedTransitionSource(id: swim.id, in: zoom)

                        if swim.id != pastSwims.last?.id {
                            Divider()
                                .padding(.leading, Spacing.medium + minimumTapTarget + Spacing.small)
                        }
                    }
                }
                .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            }
        }
    }
}

#Preview("30 swims") {
    SummaryView()
        .previewEnvironment()
}

#Preview("No swims") {
    SummaryView()
        .previewEnvironment(.noSwims)
}
