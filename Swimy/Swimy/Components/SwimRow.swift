import SwiftUI

/// Swim icon, distance (bold) + type, date, optional chevron.
struct SwimRow: View {
    let swim: Swim
    /// Lists add their own chevron; cards built from stacks need this one.
    var showsChevron = false

    @Environment(SettingsStore.self) private var settings

    var body: some View {
        HStack(spacing: Spacing.small) {
            Image(systemName: swim.locationType.symbolName)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: minimumTapTarget, height: minimumTapTarget)
                .background(Color.poolTile.gradient, in: RoundedRectangle(cornerRadius: Radius.icon, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(distance)
                    .font(.headline)
                    .monospacedDigit()
                Text("\(swim.locationType.title) · \(SwimFormatter.swimDate(swim.startDate))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)

            Spacer(minLength: 0)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(swim.locationType.title), \(distance), \(SwimFormatter.swimDate(swim.startDate))")
    }

    private var distance: String {
        SwimFormatter.swimDistance(swim, distanceUnit: settings.distanceUnit)
    }
}

#Preview {
    let store = SwimStore.preview()
    return List(store.swims.prefix(4)) { swim in
        SwimRow(swim: swim)
    }
    .environment(SettingsStore())
}
