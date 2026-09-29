import Foundation
import Testing
@testable import Swimy

@MainActor
struct StoreTests {
    @Test func refreshLoadsSwimsNewestFirstWithLatestDetail() async throws {
        let store = SwimStore(provider: MockSwimProvider(latency: .zero))
        await store.refresh()

        #expect(store.status == .loaded)
        #expect(store.swims.count == 30)
        let latest = try #require(store.latestSwim)
        #expect(store.detail(for: latest)?.lengths.isEmpty == false)
    }

    @Test func switchingProviderReplacesSwims() async {
        let store = SwimStore(provider: MockSwimProvider(latency: .zero))
        await store.refresh()
        await store.use(MockSwimProvider(scenario: .noSwims, latency: .zero))

        #expect(store.swims.isEmpty)
        #expect(store.latestSwim == nil)
        #expect(store.lifetimeDistanceMeters == 0)
    }

    @Test func settingsPersistBetweenLaunches() throws {
        let suite = "SwimyTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let first = SettingsStore(defaults: defaults)
        #expect(first.distanceUnit == .kilometers)
        #expect(first.hapticsEnabled)
        first.distanceUnit = .miles
        first.hapticsEnabled = false
        first.appearance = .dark

        let second = SettingsStore(defaults: defaults)
        #expect(second.distanceUnit == .miles)
        #expect(second.hapticsEnabled == false)
        #expect(second.appearance == .dark)
    }
}
