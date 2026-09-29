import SwiftUI

/// "▲ 6% vs usual". Green only for an improvement; neutral grey otherwise.
/// Colour is never the only signal: there's always an arrow and words.
struct ComparisonChip: View {
    let comparison: Comparison

    var body: some View {
        HStack(spacing: Spacing.xxSmall) {
            Image(systemName: comparison.symbolName)
                .imageScale(.small)
            Text(comparison.chipText)
                .monospacedDigit()
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, Spacing.xSmall)
        .padding(.vertical, Spacing.xxSmall)
        .background(tint.opacity(0.12), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(comparison.spokenText)
    }

    private var tint: Color {
        comparison.isImprovement ? .improve : .secondary
    }
}

#Preview {
    VStack(spacing: 12) {
        ComparisonChip(comparison: Comparison(metric: .pace, value: 141, usual: 150, change: -0.06))
        ComparisonChip(comparison: Comparison(metric: .pace, value: 159, usual: 150, change: 0.06))
        ComparisonChip(comparison: Comparison(metric: .heartRate, value: 131, usual: 130, change: 0.01))
    }
    .padding()
}
