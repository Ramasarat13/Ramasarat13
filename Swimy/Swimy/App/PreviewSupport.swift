import SwiftUI

extension View {
    /// Injects stores filled with mock swims, for SwiftUI previews.
    func previewEnvironment(_ scenario: MockSwimProvider.Scenario = .sampleSwims) -> some View {
        self
            .environment(SwimStore.preview(scenario))
            .environment(SettingsStore())
            .environment(AppRouter())
    }
}
