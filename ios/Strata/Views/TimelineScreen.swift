import Combine
import SwiftUI

/// The home tab: the hero card, then one continuous timeline of every visible calendar.
/// Spreading two fingers makes every event say more; pinching makes it say less.
struct TimelineScreen: View {
    @Environment(CalendarStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var typeScale: CGFloat = 1

    @Binding var sheet: SheetRoute?
    /// Goes up each time the Home tab is tapped while already showing, to return to the top.
    let homeTaps: Int

    /// Continuous zoom; whole numbers are the four levels.
    @State private var zoom = TimelineScreen.storedZoom()
    @State private var pinchBase: Double?
    @State private var pinchVelocity: Double = 0
    @GestureState private var isPinching = false
    /// The day held at the top of the screen while the zoom changes.
    @State private var anchorDay: Date?
    @State private var topDay: Date?
    @State private var scrollRequest: ScrollRequest?
    @State private var pendingDelete: CalendarEvent?
    @State private var errorMessage: String?

    private static let zoomKey = "zoomLevel"
    private static let heroID = "hero"

    private var level: ZoomLevel { TimelineZoom.level(for: zoom) }

    var body: some View {
        Group {
            if store.hasLoaded {
                ZoomDriven(zoom: zoom) { animatedZoom in
                    SwiftUI.TimelineView(.everyMinute) { context in
                        timeline(zoom: animatedZoom, now: context.date)
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        // On the whole screen, so a pinch counts wherever the fingers land.
        .simultaneousGesture(magnifyGesture)
        .deleteEventDialog($pendingDelete) { event, span in
            Task {
                do {
                    try await store.delete(event, span: span)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
        .errorAlert($errorMessage)
        .sensoryFeedback(.selection, trigger: level)
        .task { await store.reload() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await store.reload() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged).receive(on: DispatchQueue.main)) { _ in
            Task { await store.reload() }
        }
        .onChange(of: isPinching) { _, pinching in
            if !pinching { finishPinch() }
        }
        .onChange(of: homeTaps) { _, _ in
            scrollRequest = ScrollRequest(target: .top)
        }
    }

    // MARK: Timeline

    private func timeline(zoom animatedZoom: Double, now: Date) -> some View {
        let metrics = TimelineMetrics(zoom: animatedZoom, typeScale: typeScale)
        let actions = TimelineActions(
            open: { sheet = .detail($0) },
            edit: { sheet = .editor(EventDraft(editing: $0)) },
            delete: { pendingDelete = $0 },
            newEvent: { startNewEvent(on: $0) }
        )
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    HeroCard(
                        now: now,
                        week: week(from: now),
                        level: level,
                        onSelectDay: { jump(toDayOnOrAfter: $0) },
                        onLevel: { setLevel($0) },
                        onEarlier: { loadEarlier() }
                    )
                    .padding(.top, 4)
                    .padding(.bottom, 6)
                    .id(Self.heroID)

                    ForEach(store.days) { day in
                        DayRowView(
                            day: day,
                            metrics: metrics,
                            now: now,
                            today: store.today,
                            calendars: store.calendarsByID,
                            actions: actions
                        )
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 12)
                .padding(.bottom, 24)
                // Lines pushed down by arriving words glide instead of jumping.
                .animation(reduceMotion ? nil : .snappy(duration: 0.22), value: metrics.step)
            }
            .scrollPosition(id: $topDay, anchor: .top)
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("timeline")
            .accessibilityValue(level.label)
            .accessibilityZoomAction { action in
                switch action.direction {
                case .zoomIn:
                    if let next = level.moreDetail { setLevel(next) }
                case .zoomOut:
                    if let next = level.lessDetail { setLevel(next) }
                @unknown default:
                    break
                }
            }
            .onChange(of: animatedZoom) { _, _ in
                // Rows change height as they fill; keep the same day under the top edge.
                if let anchorDay {
                    proxy.scrollTo(anchorDay, anchor: .top)
                }
            }
            .onChange(of: scrollRequest) { _, request in
                guard let request else { return }
                perform(request, with: proxy)
                // A lazy list only estimates where far-off rows are, so the first jump can
                // land short. Once it has laid out the rows around the target, go again.
                Task { @MainActor in
                    for _ in 0..<3 {
                        try? await Task.sleep(for: .milliseconds(60))
                        guard scrollRequest == request else { return }
                        perform(request, with: proxy)
                    }
                    if case .day(let day) = request.target, request.anchor == .top {
                        topDay = day
                    }
                }
            }
        }
    }

    private func perform(_ request: ScrollRequest, with proxy: ScrollViewProxy) {
        switch request.target {
        case .top: proxy.scrollTo(Self.heroID, anchor: .top)
        case .day(let day): proxy.scrollTo(day, anchor: request.anchor)
        }
    }

    /// Today and the six days after it, for the hero card's strip.
    private func week(from now: Date) -> [HeroDay] {
        let start = store.calendar.startOfDay(for: now)
        return (0..<7).compactMap { offset in
            guard let date = store.calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return HeroDay(date: date, hasEvents: store.daysWithEvents.contains(date))
        }
    }

    // MARK: Zoom

    private var magnifyGesture: some Gesture {
        MagnifyGesture(minimumScaleDelta: 0.01)
            .updating($isPinching) { _, state, _ in
                state = true
            }
            .onChanged { value in
                if pinchBase == nil {
                    pinchBase = zoom
                    // With the hero at the top there is no day to hold; the list just grows downward.
                    anchorDay = topDay
                }
                pinchVelocity = Double(value.velocity)
                zoom = TimelineZoom.value(base: pinchBase ?? zoom, magnification: Double(value.magnification))
            }
    }

    /// Runs when the fingers lift, and also when the system cancels the gesture.
    private func finishPinch() {
        guard pinchBase != nil else { return }
        pinchBase = nil
        settle(on: TimelineZoom.settledLevel(for: zoom, velocity: pinchVelocity))
    }

    private func setLevel(_ target: ZoomLevel) {
        anchorDay = topDay
        settle(on: target)
    }

    private func settle(on target: ZoomLevel) {
        UserDefaults.standard.set(target.rawValue, forKey: Self.zoomKey)
        withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.86)) {
            zoom = Double(target.rawValue)
        }
    }

    private static func storedZoom() -> Double {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: zoomKey) != nil else { return TimelineZoom.minimum }
        return Double(TimelineZoom.level(for: Double(defaults.integer(forKey: zoomKey))).rawValue)
    }

    // MARK: Actions

    private func startNewEvent(on day: Date?) {
        do {
            sheet = .editor(try store.newDraft(on: day))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Scrolls to the given day, or to the next day that has events if it has none.
    private func jump(toDayOnOrAfter date: Date) {
        guard let target = store.days.first(where: { $0.date >= date }) else { return }
        scrollRequest = ScrollRequest(target: target.date == store.today ? .top : .day(target.date))
    }

    private func loadEarlier() {
        let firstDay = store.days.first?.date
        Task {
            await store.loadEarlier()
            // Earlier days were added above. Keep the day that was first in the middle
            // of the screen, so the newly loaded days show just above it.
            if let firstDay {
                scrollRequest = ScrollRequest(target: .day(firstDay), anchor: .center)
            }
        }
    }
}

/// Re-renders its content on every frame of a zoom animation, so words arrive and
/// leave gradually on the way to the settled level instead of all at once.
struct ZoomDriven<Content: View>: View, Animatable {
    var zoom: Double
    let content: (Double) -> Content

    init(zoom: Double, @ViewBuilder content: @escaping (Double) -> Content) {
        self.zoom = zoom
        self.content = content
    }

    var animatableData: Double {
        get { zoom }
        set { zoom = newValue }
    }

    var body: some View {
        content(zoom)
    }
}

struct ScrollRequest: Equatable {
    enum Target: Equatable {
        /// The hero card, with today right below it.
        case top
        case day(Date)
    }

    let id = UUID()
    let target: Target
    var anchor: UnitPoint = .top
}

enum SheetRoute: Identifiable {
    case detail(CalendarEvent)
    case editor(EventDraft)

    var id: String {
        switch self {
        case .detail(let event): "detail-\(event.id)"
        case .editor(let draft): "editor-\(draft.id)"
        }
    }
}

#Preview("Timeline") {
    TimelineScreen(sheet: .constant(nil), homeTaps: 0)
        .environment(CalendarStore.demo())
}
