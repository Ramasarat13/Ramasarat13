import SwiftUI

/// Recaps, plain-language insights, trends, personal bests and milestones.
/// Built in Phase 5; for now it explains what's coming.
struct InsightsView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Insights are on the way", systemImage: "chart.line.uptrend.xyaxis")
            } description: {
                Text("Weekly recaps, trends, personal bests and milestones will live here, all compared with your own swims.")
            }
            .background(Color.screenBackground)
            .navigationTitle("Insights")
            .profileToolbar()
        }
    }
}

#Preview {
    InsightsView()
        .previewEnvironment()
}
