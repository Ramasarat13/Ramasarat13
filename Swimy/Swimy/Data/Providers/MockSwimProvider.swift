import Foundation

/// Realistic fake swims for the Simulator, SwiftUI previews and tests.
///
/// The same 30 swims are generated on every launch (seeded random numbers), with
/// dates relative to "now" so the latest swim is always from today. Over 14 weeks
/// the swimmer gets steadily faster and swims further, so comparisons have
/// something to show.
///
/// Edge cases covered:
/// - 25 m and 50 m pools, plus a holiday in a 25 yd pool
/// - open water swims (no lengths, splits or SWOLF; water temperature)
/// - an Apple Watch swim with no heart rate
/// - a third-party app swim with no heart rate, strokes or per-length data
/// - a very short swim (excluded from averages)
struct MockSwimProvider: SwimDataProvider {
    enum Scenario: String, CaseIterable, Identifiable, Sendable {
        case sampleSwims
        case singleSwim
        case noSwims

        var id: String { rawValue }

        var title: String {
            switch self {
            case .sampleSwims: "30 sample swims"
            case .singleSwim: "Only 1 swim"
            case .noSwims: "No swims"
            }
        }
    }

    let scenario: Scenario
    /// Newest first.
    let swims: [Swim]
    private let details: [UUID: SwimDetail]
    private let latency: Duration

    init(
        scenario: Scenario = .sampleSwims,
        now: Date = .now,
        calendar: Calendar = .current,
        latency: Duration = .milliseconds(300)
    ) {
        var factory = MockSwimFactory(now: now, calendar: calendar)
        let generated = factory.makeSwims()
        let kept: [MockSwimFactory.Generated]
        switch scenario {
        case .sampleSwims: kept = generated
        case .singleSwim: kept = Array(generated.prefix(1))
        case .noSwims: kept = []
        }
        self.scenario = scenario
        self.swims = kept.map { $0.swim }
        self.details = Dictionary(uniqueKeysWithValues: kept.map { ($0.swim.id, $0.detail) })
        self.latency = latency
    }

    func fetchSwims() async throws -> [Swim] {
        // A short pause so loading states can be seen, like a real sync.
        try await Task.sleep(for: latency)
        return swims
    }

    func fetchDetail(for swimID: UUID) async throws -> SwimDetail {
        details[swimID] ?? .empty(for: swimID)
    }

    /// Synchronous access for previews and tests.
    func detail(for swimID: UUID) -> SwimDetail? {
        details[swimID]
    }
}

// MARK: - Generation

private struct MockSwimFactory {
    struct Generated {
        let swim: Swim
        let detail: SwimDetail
    }

    enum Setup {
        case pool(lengthMeters: Double, unit: PoolUnit)
        case openWater(meters: Double)

        static var pool25m: Setup { .pool(lengthMeters: 25, unit: .meters) }
        static var pool50m: Setup { .pool(lengthMeters: 50, unit: .meters) }
        static var pool25yd: Setup { .pool(lengthMeters: 22.86, unit: .yards) }
    }

    enum Recorder {
        case watch
        case watchUltra
        case thirdPartyApp

        var deviceName: String? {
            switch self {
            case .watch: "Apple Watch Series 10"
            case .watchUltra: "Apple Watch Ultra 2"
            case .thirdPartyApp: nil
            }
        }

        var sourceName: String {
            switch self {
            case .watch, .watchUltra: "Workout"
            case .thirdPartyApp: "Lap Counter"
            }
        }
    }

    struct Plan {
        let daysAgo: Int
        let hour: Int
        let minute: Int
        let setup: Setup
        var lengths: Int = 0
        var hasHeartRate: Bool = true
        var recorder: Recorder = .watch
    }

    /// A stretch of continuous swimming, used to shape the heart-rate curve.
    struct SwimBlock {
        let start: Date
        let end: Date
        let intensity: Double
    }

    /// Oldest first. The last swim is always "today".
    static var plans: [Plan] {
        [
            Plan(daysAgo: 98, hour: 7, minute: 10, setup: .pool25m, lengths: 24),
            Plan(daysAgo: 95, hour: 18, minute: 30, setup: .pool25m, lengths: 20),
            Plan(daysAgo: 91, hour: 7, minute: 5, setup: .pool25m, lengths: 28),
            Plan(daysAgo: 88, hour: 7, minute: 20, setup: .pool25m, lengths: 1), // very short: 25 m
            Plan(daysAgo: 87, hour: 7, minute: 15, setup: .pool25m, lengths: 28),
            Plan(daysAgo: 84, hour: 18, minute: 40, setup: .pool25m, lengths: 32, recorder: .thirdPartyApp),
            Plan(daysAgo: 80, hour: 7, minute: 0, setup: .pool25m, lengths: 32),
            Plan(daysAgo: 77, hour: 9, minute: 30, setup: .openWater(meters: 750), recorder: .watchUltra),
            Plan(daysAgo: 73, hour: 7, minute: 10, setup: .pool25m, lengths: 36),
            Plan(daysAgo: 70, hour: 7, minute: 5, setup: .pool50m, lengths: 18),
            Plan(daysAgo: 66, hour: 18, minute: 20, setup: .pool25m, lengths: 36),
            Plan(daysAgo: 63, hour: 8, minute: 45, setup: .openWater(meters: 1000), recorder: .watchUltra),
            Plan(daysAgo: 59, hour: 7, minute: 15, setup: .pool25m, lengths: 40),
            Plan(daysAgo: 56, hour: 7, minute: 0, setup: .pool25yd, lengths: 40), // holiday in a US yard pool
            Plan(daysAgo: 54, hour: 7, minute: 30, setup: .pool25yd, lengths: 44),
            Plan(daysAgo: 52, hour: 7, minute: 10, setup: .pool25yd, lengths: 40),
            Plan(daysAgo: 49, hour: 7, minute: 5, setup: .pool25m, lengths: 40, hasHeartRate: false),
            Plan(daysAgo: 45, hour: 18, minute: 30, setup: .pool25m, lengths: 44),
            Plan(daysAgo: 42, hour: 9, minute: 0, setup: .openWater(meters: 1200), recorder: .watchUltra),
            Plan(daysAgo: 38, hour: 7, minute: 10, setup: .pool50m, lengths: 22),
            Plan(daysAgo: 35, hour: 7, minute: 5, setup: .pool25m, lengths: 48),
            Plan(daysAgo: 31, hour: 18, minute: 45, setup: .pool25m, lengths: 44),
            Plan(daysAgo: 28, hour: 7, minute: 0, setup: .pool50m, lengths: 24),
            Plan(daysAgo: 24, hour: 7, minute: 10, setup: .pool25m, lengths: 48),
            Plan(daysAgo: 21, hour: 18, minute: 30, setup: .pool25m, lengths: 52),
            Plan(daysAgo: 17, hour: 7, minute: 5, setup: .pool25m, lengths: 48),
            Plan(daysAgo: 14, hour: 7, minute: 15, setup: .pool50m, lengths: 26),
            Plan(daysAgo: 10, hour: 7, minute: 0, setup: .pool25m, lengths: 52),
            Plan(daysAgo: 5, hour: 18, minute: 40, setup: .pool25m, lengths: 56),
            Plan(daysAgo: 0, hour: 0, minute: 0, setup: .pool25m, lengths: 60),
        ]
    }

    let now: Date
    let calendar: Calendar
    private var rng = SeededGenerator(seed: 0x5717_1D0C_2026)

    init(now: Date, calendar: Calendar) {
        self.now = now
        self.calendar = calendar
    }

    /// Newest first.
    mutating func makeSwims() -> [Generated] {
        let plans = Self.plans
        var result: [Generated] = []
        for (index, plan) in plans.enumerated() {
            let progress = Double(index) / Double(max(plans.count - 1, 1))
            let isLatest = index == plans.count - 1
            let start = startDate(for: plan, isLatest: isLatest)
            let id = makeUUID()
            switch plan.setup {
            case let .pool(lengthMeters, unit):
                result.append(makePoolSwim(
                    id: id, plan: plan, start: start, lengthMeters: lengthMeters,
                    unit: unit, progress: progress, isLatest: isLatest
                ))
            case let .openWater(meters):
                result.append(makeOpenWaterSwim(id: id, meters: meters, start: start, progress: progress))
            }
        }
        return Array(result.reversed())
    }

    private func startDate(for plan: Plan, isLatest: Bool) -> Date {
        if isLatest {
            // About two and a half hours ago, on a round five minutes.
            let earlier = now.addingTimeInterval(-2.5 * 3600)
            let minute = calendar.component(.minute, from: earlier)
            let second = calendar.component(.second, from: earlier)
            return earlier.addingTimeInterval(-Double((minute % 5) * 60 + second))
        }
        let fallback = now.addingTimeInterval(Double(-plan.daysAgo) * 86_400)
        let day = calendar.date(byAdding: .day, value: -plan.daysAgo, to: now) ?? fallback
        return calendar.date(bySettingHour: plan.hour, minute: plan.minute, second: 0, of: day) ?? day
    }

    private mutating func makePoolSwim(
        id: UUID,
        plan: Plan,
        start: Date,
        lengthMeters: Double,
        unit: PoolUnit,
        progress: Double,
        isLatest: Bool
    ) -> Generated {
        let isVeryShort = plan.lengths <= 2
        // Seconds per 100 m of freestyle: about 2′50″ at first, 2′20″ by the end.
        var basePace = 170 - 30 * progress + random(-3...3)
        if isLatest { basePace *= 0.95 } // a good day, so the comparison chip has something to say
        let restBase = max(15, 55 - 25 * progress)
        let sizeScale = lengthMeters / 25

        var lengths: [SwimLength] = []
        var blocks: [SwimBlock] = []
        var cursor = start.addingTimeInterval(isVeryShort ? 10 : 25)
        var remaining = plan.lengths

        while remaining > 0 {
            let setSize = min(remaining, pickSetSize(poolLengthMeters: lengthMeters))
            let style = pickStroke(progress: progress)
            let blockStart = cursor
            for position in 0..<setSize {
                let fatigue = 1 + 0.05 * Double(position) / Double(setSize)
                let noise = 1 + random(-0.04...0.04)
                let duration = basePace * lengthMeters / 100 * style.paceFactor * fatigue * noise
                let strokes = strokeCount(for: style, progress: progress, sizeScale: sizeScale)
                let length = SwimLength(
                    index: lengths.count,
                    start: cursor,
                    durationSec: duration,
                    distanceMeters: lengthMeters,
                    strokes: strokes,
                    strokeStyle: style
                )
                lengths.append(length)
                cursor = cursor.addingTimeInterval(duration + random(0...2))
            }
            blocks.append(SwimBlock(start: blockStart, end: cursor, intensity: style.intensity))
            remaining -= setSize
            if remaining > 0 {
                cursor = cursor.addingTimeInterval(max(12, restBase + random(-12...12)))
            }
        }
        let end = cursor.addingTimeInterval(isVeryShort ? 5 : 30)

        let isThirdParty = plan.recorder == .thirdPartyApp
        let heartRate = plan.hasHeartRate && !isThirdParty
            ? makeHeartRate(from: start, to: end, blocks: blocks, fitness: progress)
            : []
        let bpms = heartRate.map { $0.bpm }
        let strokes = lengths.compactMap { $0.strokes }
        let minutes = end.timeIntervalSince(start) / 60

        let swim = Swim(
            id: id,
            startDate: start,
            endDate: end,
            locationType: .pool,
            poolLengthMeters: lengthMeters,
            poolUnit: unit,
            totalDistanceMeters: Double(plan.lengths) * lengthMeters,
            activeDurationSec: lengths.reduce(0) { $0 + $1.durationSec },
            totalStrokes: isThirdParty || strokes.isEmpty ? nil : strokes.reduce(0, +),
            avgHeartRate: bpms.isEmpty ? nil : bpms.reduce(0, +) / Double(bpms.count),
            maxHeartRate: bpms.max(),
            activeCalories: isThirdParty ? nil : (minutes * (6.5 + 2 * progress)).rounded(),
            lengthCount: plan.lengths,
            avgSwolf: isThirdParty ? nil : MetricsEngine.averageSwolf(of: lengths),
            strokeMix: isThirdParty ? [:] : MetricsEngine.strokeMix(of: lengths),
            waterTemperatureCelsius: nil,
            deviceName: plan.recorder.deviceName,
            sourceName: plan.recorder.sourceName
        )
        let detail = SwimDetail(swimID: id, lengths: isThirdParty ? [] : lengths, heartRate: heartRate)
        return Generated(swim: swim, detail: detail)
    }

    private mutating func makeOpenWaterSwim(id: UUID, meters: Double, start: Date, progress: Double) -> Generated {
        // Open water is a little slower than the pool: no walls to push off.
        let pace = (170 - 30 * progress) * 1.08 + random(-4...4)
        let active = meters / 100 * pace
        let swimStart = start.addingTimeInterval(60)
        let swimEnd = swimStart.addingTimeInterval(active)
        let end = swimEnd.addingTimeInterval(45)
        let block = SwimBlock(start: swimStart, end: swimEnd, intensity: 0.8)
        let heartRate = makeHeartRate(from: start, to: end, blocks: [block], fitness: progress)
        let bpms = heartRate.map { $0.bpm }
        let temperature = ((18 + random(0...3.5)) * 10).rounded() / 10
        let minutes = end.timeIntervalSince(start) / 60

        let swim = Swim(
            id: id,
            startDate: start,
            endDate: end,
            locationType: .openWater,
            poolLengthMeters: nil,
            poolUnit: .meters,
            totalDistanceMeters: meters,
            activeDurationSec: active,
            totalStrokes: Int((meters / 100 * (80 - 10 * progress)).rounded()),
            avgHeartRate: bpms.isEmpty ? nil : bpms.reduce(0, +) / Double(bpms.count),
            maxHeartRate: bpms.max(),
            activeCalories: (minutes * (7 + 2 * progress)).rounded(),
            lengthCount: nil,
            avgSwolf: nil,
            strokeMix: [:],
            waterTemperatureCelsius: temperature,
            deviceName: Recorder.watchUltra.deviceName,
            sourceName: Recorder.watchUltra.sourceName
        )
        return Generated(swim: swim, detail: SwimDetail(swimID: id, lengths: [], heartRate: heartRate))
    }

    /// One reading every 10 seconds. Rises while swimming, eases off while resting.
    private mutating func makeHeartRate(from start: Date, to end: Date, blocks: [SwimBlock], fitness: Double) -> [HRPoint] {
        var points: [HRPoint] = []
        var bpm = 92.0
        var time = start
        var blockIndex = 0
        while time <= end {
            while blockIndex < blocks.count && blocks[blockIndex].end < time {
                blockIndex += 1
            }
            let isSwimming = blockIndex < blocks.count && blocks[blockIndex].start <= time
            let target = isSwimming ? 118 + 42 * blocks[blockIndex].intensity - 8 * fitness : 102
            bpm += (target - bpm) * 0.22 + random(-2...2)
            points.append(HRPoint(date: time, bpm: bpm.rounded()))
            time = time.addingTimeInterval(10)
        }
        return points
    }

    private mutating func pickSetSize(poolLengthMeters: Double) -> Int {
        let options = poolLengthMeters >= 50 ? [1, 2, 2, 4] : [2, 4, 4, 6, 8]
        return options[Int.random(in: 0..<options.count, using: &rng)]
    }

    /// Early swims mix in breaststroke and kickboard; later ones are mostly freestyle.
    private mutating func pickStroke(progress: Double) -> SwimStroke {
        let weights: [(style: SwimStroke, weight: Double)] = [
            (.freestyle, 0.45 + 0.35 * progress),
            (.breaststroke, 0.30 - 0.15 * progress),
            (.backstroke, 0.12),
            (.kickboard, 0.13 - 0.08 * progress),
            (.butterfly, 0.03 * progress),
        ]
        let total = weights.reduce(0) { $0 + $1.weight }
        var pick = random(0...total)
        for entry in weights {
            if pick < entry.weight { return entry.style }
            pick -= entry.weight
        }
        return .freestyle
    }

    private mutating func strokeCount(for style: SwimStroke, progress: Double, sizeScale: Double) -> Int? {
        let perLength: Double
        switch style {
        case .freestyle: perLength = 22 - 4 * progress
        case .backstroke: perLength = 23 - 3 * progress
        case .breaststroke: perLength = 12 - 2 * progress
        case .butterfly: perLength = 17 - 2 * progress
        case .mixed: perLength = 18
        case .kickboard, .unknown: return nil
        }
        return Int((perLength * sizeScale + random(-1.5...1.5)).rounded())
    }

    private mutating func random(_ range: ClosedRange<Double>) -> Double {
        Double.random(in: range, using: &rng)
    }

    private mutating func makeUUID() -> UUID {
        let halves = (rng.next(), rng.next())
        return withUnsafeBytes(of: halves) { UUID(uuid: $0.load(as: uuid_t.self)) }
    }
}

private extension SwimStroke {
    /// How much slower than freestyle a length of this stroke is.
    var paceFactor: Double {
        switch self {
        case .freestyle: 1.0
        case .backstroke: 1.1
        case .breaststroke: 1.18
        case .butterfly: 1.05
        case .mixed: 1.1
        case .kickboard: 1.45
        case .unknown: 1.1
        }
    }

    /// How hard the stroke works the heart, 0...1.
    var intensity: Double {
        switch self {
        case .freestyle: 0.75
        case .backstroke: 0.65
        case .breaststroke: 0.6
        case .butterfly: 0.95
        case .mixed: 0.7
        case .kickboard: 0.55
        case .unknown: 0.65
        }
    }
}

/// Small, fast, repeatable random numbers (SplitMix64), so mock data is the same every launch.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
