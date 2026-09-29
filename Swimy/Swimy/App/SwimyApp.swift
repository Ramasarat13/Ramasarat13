import SwiftUI

@main
struct SwimyApp: App {
    @State private var settings: SettingsStore
    @State private var swimStore: SwimStore
    @State private var router = AppRouter()

    init() {
        let settings = SettingsStore()
        _settings = State(initialValue: settings)
        _swimStore = State(initialValue: SwimStore(provider: Self.makeProvider(settings: settings)))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(swimStore)
                .environment(router)
                .preferredColorScheme(settings.appearance.colorScheme)
        }
    }

    /// Phase 1 runs on mock data everywhere. Phase 2 adds `HealthKitSwimProvider`
    /// for real devices and keeps the mock for the Simulator and tests.
    private static func makeProvider(settings: SettingsStore) -> any SwimDataProvider {
        MockSwimProvider(scenario: settings.mockScenario)
    }
}

extension Appearance {
    /// `nil` follows the system setting.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
