import SwiftUI

/// Every swim, grouped by month, newest first.
///
/// Phase 4 adds the calendar view (pool tiles shaded by distance), month totals
/// header and the All / Pool / Open water filter.
struct ActivityView: View {
    @Environment(SwimStore.self) private var store
    @Environment(SettingsStore.self) private var settings
    @Namespace private var zoom

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Activity")
                .profileToolbar()
                .navigationDestination(for: Swim.self) { swim in
                    SwimDetailView(swim: swim)
                        .navigationTransition(.zoom(sourceID: swim.id, in: zoom))
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !store.swims.isEmpty {
            List {
                ForEach(monthGroups) { group in
                    Section {
                        ForEach(group.swims) { swim in
                            NavigationLink(value: swim) {
                                SwimRow(swim: swim)
                            }
                            .matchedTransitionSource(id: swim.id, in: zoom)
                        }
                    } header: {
                        monthHeader(group)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .refreshable { await store.refresh() }
        } else if store.status == .idle || store.status == .loading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.screenBackground)
        } else {
            NoSwimsView()
                .refreshable { await store.refresh() }
        }
    }

    private func monthHeader(_ group: MonthGroup) -> some View {
        let total = SwimFormatter.totalDistance(meters: group.distanceMeters, unit: settings.distanceUnit)
        return HStack(alignment: .firstTextBaseline) {
            Text(group.month.formatted(.dateTime.month(.wide).year()))
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer()
            Text("\(SwimFormatter.swimCount(group.swims.count)) · \(total.value) \(total.unit)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .textCase(nil)
    }

    private var monthGroups: [MonthGroup] {
        let calendar = Calendar.current
        var groups: [MonthGroup] = []
        for swim in store.swims {
            let month = calendar.dateInterval(of: .month, for: swim.startDate)?.start ?? swim.startDate
            if let last = groups.last, last.month == month {
                groups[groups.count - 1].swims.append(swim)
            } else {
                groups.append(MonthGroup(month: month, swims: [swim]))
            }
        }
        return groups
    }
}

/// Swims from one calendar month, newest first.
struct MonthGroup: Identifiable {
    let month: Date
    var swims: [Swim]

    var id: Date { month }

    var distanceMeters: Double {
        swims.reduce(0) { $0 + $1.totalDistanceMeters }
    }
}

#Preview {
    ActivityView()
        .previewEnvironment()
}
