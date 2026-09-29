import SwiftUI

/// The Profile hero: LIFETIME + total distance on the pool tile.
///
/// Text sits on a dark scrim so white reaches 4.5:1 contrast (the light-blue
/// "LIFETIME" label in the mockup fell short). Phase 4 adds the tap-to-flip
/// (total swims and time) and animated caustics.
struct LifetimeTile: View {
    let distance: FormattedValue
    let swimCount: Int

    var body: some View {
        PoolTileView()
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                    Text("LIFETIME")
                        .font(.caption.weight(.bold))
                        .tracking(1.2)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(distance.value)
                            .font(.lifetimeNumber)
                            .contentTransition(.numericText())
                        Text(distance.unit)
                            .font(.title3.weight(.semibold))
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    Text(SwimFormatter.swimCount(swimCount))
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(.white)
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                .padding(Spacing.large)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    LinearGradient(
                        colors: [.black.opacity(0), .black.opacity(0.35)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
            .frame(height: 210)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Lifetime distance, \(distance.spoken), \(SwimFormatter.swimCount(swimCount))")
    }
}

#Preview {
    LifetimeTile(
        distance: SwimFormatter.totalDistance(meters: 31_450, unit: .kilometers),
        swimCount: 30
    )
    .padding()
}
