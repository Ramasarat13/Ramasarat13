import Observation

enum AppTab: Hashable {
    case summary
    case activity
    case insights
}

/// App-wide navigation: the selected tab and the Profile sheet.
@MainActor
@Observable
final class AppRouter {
    var selectedTab: AppTab = .summary
    var isProfilePresented = false
}
