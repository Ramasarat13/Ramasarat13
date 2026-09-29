import SwiftUI

/// The tab bar (Liquid Glass on iOS 26) with Summary, Activity and Insights.
/// Profile opens as a sheet from the button on every tab.
struct RootView: View {
    @Environment(AppRouter.self) private var router
    @Environment(SwimStore.self) private var store

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.selectedTab) {
            Tab("Summary", systemImage: "figure.pool.swim", value: AppTab.summary) {
                SummaryView()
            }
            Tab("Activity", systemImage: "calendar", value: AppTab.activity) {
                ActivityView()
            }
            Tab("Insights", systemImage: "chart.line.uptrend.xyaxis", value: AppTab.insights) {
                InsightsView()
            }
        }
        .sheet(isPresented: $router.isProfilePresented) {
            ProfileView()
        }
        .swimyHaptic(.selection, trigger: router.selectedTab)
        .task {
            if store.status == .idle {
                await store.refresh()
            }
        }
    }
}

#Preview {
    RootView()
        .previewEnvironment()
}
