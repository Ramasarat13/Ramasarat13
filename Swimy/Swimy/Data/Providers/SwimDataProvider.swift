import Foundation

/// Where swims come from.
///
/// Stores only talk to this protocol, never to HealthKit directly. That keeps the
/// mock provider swappable for Simulator work and tests. `HealthKitSwimProvider`
/// arrives in Phase 2.
protocol SwimDataProvider: Sendable {
    /// Every swim workout, in any order. Summaries only.
    func fetchSwims() async throws -> [Swim]

    /// Per-length and heart-rate data for one swim.
    func fetchDetail(for swimID: UUID) async throws -> SwimDetail
}
