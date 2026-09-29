import Foundation
import Observation

/// The app's swims, shared by every screen through the SwiftUI environment.
@MainActor
@Observable
final class SwimStore {
    enum Status: Equatable {
        case idle
        case loading
        case loaded
        /// The last sync failed. Cached swims stay on screen.
        case failed
    }

    /// All swims, newest first.
    private(set) var swims: [Swim] = []
    private(set) var status: Status = .idle
    private var details: [UUID: SwimDetail] = [:]
    private var provider: any SwimDataProvider

    init(provider: any SwimDataProvider) {
        self.provider = provider
    }

    var latestSwim: Swim? {
        swims.first
    }

    /// Sum of every swim, including very short ones.
    var lifetimeDistanceMeters: Double {
        swims.reduce(0) { $0 + $1.totalDistanceMeters }
    }

    // MARK: - Loading

    /// Fetches swims from the provider. Swims deleted at the source disappear.
    func refresh() async {
        guard status != .loading else { return }
        status = .loading
        do {
            let fetched = try await provider.fetchSwims()
            swims = fetched.sorted { $0.startDate > $1.startDate }
            let ids = Set(swims.map(\.id))
            details = details.filter { ids.contains($0.key) }
            status = .loaded
            if let latest = swims.first {
                await loadDetail(for: latest)
            }
        } catch {
            status = .failed
        }
    }

    func detail(for swim: Swim) -> SwimDetail? {
        details[swim.id]
    }

    /// Loads per-length and heart-rate data once, then keeps it.
    func loadDetail(for swim: Swim) async {
        guard details[swim.id] == nil else { return }
        if let detail = try? await provider.fetchDetail(for: swim.id) {
            details[swim.id] = detail
        }
    }

    /// Swaps the data source (debug menu) and reloads.
    func use(_ newProvider: any SwimDataProvider) async {
        provider = newProvider
        swims = []
        details = [:]
        status = .idle
        await refresh()
    }

    // MARK: - Comparisons

    func comparison(of metric: SwimMetric, for swim: Swim) -> Comparison? {
        MetricsEngine.comparison(of: metric, for: swim, in: swims)
    }
}

// MARK: - Previews

extension SwimStore {
    /// A store already filled with mock swims, for SwiftUI previews.
    static func preview(_ scenario: MockSwimProvider.Scenario = .sampleSwims) -> SwimStore {
        let mock = MockSwimProvider(scenario: scenario, latency: .zero)
        let store = SwimStore(provider: mock)
        store.swims = mock.swims
        for swim in mock.swims {
            store.details[swim.id] = mock.detail(for: swim.id)
        }
        store.status = .loaded
        return store
    }
}
