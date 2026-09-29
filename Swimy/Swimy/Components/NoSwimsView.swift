import SwiftUI

/// Shown when Health returns no swims. HealthKit never says whether access was
/// denied, so this explains both likely causes, each with simple steps.
struct NoSwimsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.large) {
                PoolTileView(tileSize: 24)
                    .frame(width: 112, height: 112)
                    .overlay {
                        Image(systemName: "figure.pool.swim")
                            .font(.largeTitle.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .accessibilityHidden(true)

                VStack(spacing: Spacing.xSmall) {
                    Text("No swims yet")
                        .font(.title2.bold())
                    Text("Swimy shows the swims your Apple Watch saves to Apple Health. If you've swum before, one of these will help.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: Spacing.small) {
                    HelpCard(
                        title: "Record a swim on Apple Watch",
                        symbolName: "applewatch",
                        steps: [
                            "Open the Workout app on your Apple Watch.",
                            "Choose Pool Swim or Open Water Swim.",
                            "For a pool, set the pool length, then start.",
                            "When you finish, your swim appears here after your iPhone syncs.",
                        ]
                    )
                    HelpCard(
                        title: "Check Health access",
                        symbolName: "heart.text.square",
                        steps: [
                            "Open the Health app on your iPhone.",
                            "Tap your picture at the top right.",
                            "Under Privacy, tap Apps, then Swimy.",
                            "Turn on all categories, then come back here.",
                        ]
                    )
                }
            }
            .padding(Spacing.medium)
            .padding(.top, Spacing.large)
        }
        .background(Color.screenBackground)
    }
}

/// A card that expands to show numbered steps.
struct HelpCard: View {
    let title: String
    let symbolName: String
    let steps: [String]

    @State private var isExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Button {
                withAnimation(Motion.adaptive(Motion.layout, reduceMotion: reduceMotion)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: Spacing.small) {
                    Image(systemName: symbolName)
                        .font(.title3)
                        .foregroundStyle(Color.poolTile)
                        .frame(width: 28)
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .frame(minHeight: minimumTapTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")

            if isExpanded {
                VStack(alignment: .leading, spacing: Spacing.xSmall) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                            Text("\(index + 1)")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Color.poolTile)
                                .frame(minWidth: 20)
                            Text(step)
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.small)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }
}

#Preview {
    NoSwimsView()
}
