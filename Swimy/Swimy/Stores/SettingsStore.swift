import Foundation
import Observation

/// User settings, saved on this iPhone.
///
/// Phase 1 keeps them in `UserDefaults`. The spec's syncable `UserSettings`
/// SwiftData model (iCloud, P1) can replace the storage later without changing screens.
@MainActor
@Observable
final class SettingsStore {
    var distanceUnit: DistanceUnit {
        didSet { defaults.set(distanceUnit.rawValue, forKey: Key.distanceUnit) }
    }

    var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: Key.hapticsEnabled) }
    }

    var appearance: Appearance {
        didSet { defaults.set(appearance.rawValue, forKey: Key.appearance) }
    }

    /// Which mock data set to show. Debug builds only change this, from Profile → Developer.
    var mockScenario: MockSwimProvider.Scenario {
        didSet { defaults.set(mockScenario.rawValue, forKey: Key.mockScenario) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        distanceUnit = DistanceUnit(rawValue: defaults.string(forKey: Key.distanceUnit) ?? "") ?? .kilometers
        hapticsEnabled = defaults.object(forKey: Key.hapticsEnabled) as? Bool ?? true
        appearance = Appearance(rawValue: defaults.string(forKey: Key.appearance) ?? "") ?? .system
        mockScenario = MockSwimProvider.Scenario(rawValue: defaults.string(forKey: Key.mockScenario) ?? "") ?? .sampleSwims
    }

    private enum Key {
        static let distanceUnit = "settings.distanceUnit"
        static let hapticsEnabled = "settings.hapticsEnabled"
        static let appearance = "settings.appearance"
        static let mockScenario = "debug.mockScenario"
    }
}
