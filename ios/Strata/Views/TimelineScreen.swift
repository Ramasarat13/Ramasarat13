import Combine
import SwiftUI

/// The main screen: one continuous, pinchable timeline of every visible calendar.
struct TimelineScreen: View {
    @Environment(CalendarStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var typeScale: CGFloat = 1

    /// Continuous zoom; whole numbers are the four levels.
    @State private var zoom = TimelineScreen.storedZoom()
    @State private var pinchBase: Double?
    @State private var pinchVelocity: Double = 0
    @GestureState private var isPinching = false
    /// The day held at the top of the screen while the zoom changes.
    @State private var anchorDay: Date?
    @State private var topDay: Date?
    @State private var scrollRequest: ScrollRequest?
    @State private var sheet: SheetRoute?
    @State private var pendingDelete: CalendarEvent?
    @State private var errorMessage: String?

    private static let zoomKey = "zoomLevel"

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
        .safeAreaInset(edge: .top, spacing: 0) {
            TimelineHeader(date: topDay ?? store.today, isDemo: store.isDemo) {
                sheet = .calendars
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            TimelineToolbar(
                level: level,
                onToday: { scrollRequest = ScrollRequest(day: store.today, animated: !reduceMotion) },
                onLevel: { setLevel($0) },
                onAdd: { startNewEvent(on: nil) }
            )
        }
        // On the whole screen, not just the list, so a pinch still counts when a
        // finger lands on the header or the toolbar.
        .simultaneousGesture(magnifyGesture)
        .sheet(item: $sheet) { route in
            switch route {
            case .detail(let event): EventDetailView(event: event)
            case .editor(let draft): EventEditorView(draft: draft)
            case .calendars: CalendarListView()
            }
        }
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
    }

    // MARK: Timeline

    private func timeline(zoom animatedZoom: Double, now: Date) -> some View {
        let metrics = TimelineMetrics(zoom: animatedZoom, typeScale: typeScale)
        let actions = TimelineActions(
            zoomInto: { setLevel(.schedule, anchor: $0) },
            open: { sheet = .detail($0) },
            edit: { sheet = .editor(EventDraft(editing: $0)) },
            delete: { pendingDelete = $0 },
            newEvent: { startNewEvent(on: $0) }
        )
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    Button {
                        loadEarlier()
                    } label: {
                        Label("Earlier events", systemImage: "chevron.up")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

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
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                // Lines that only exist at some levels slide into place when the level flips.
                .animation(reduceMotion ? nil : .snappy(duration: 0.28), value: metrics.level)
            }
            .scrollPosition(id: $topDay, anchor: .top)
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("timeline")
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
                // Rows change height as they scale; keep the same day under the top edge.
                if let anchorDay {
                    proxy.scrollTo(anchorDay, anchor: .top)
                }
            }
            .onChange(of: scrollRequest) { _, request in
                guard let request else { return }
                if request.animated {
                    withAnimation(.snappy) {
                        proxy.scrollTo(request.day, anchor: request.anchor)
                    }
                } else {
                    proxy.scrollTo(request.day, anchor: request.anchor)
                }
                // A lazy list only estimates where far-off rows are, so the first jump can
                // land short. Once it has laid out the rows around the target, go again.
                Task { @MainActor in
                    for _ in 0..<2 {
                        try? await Task.sleep(for: .milliseconds(request.animated ? 400 : 60))
                        guard scrollRequest == request else { return }
                        proxy.scrollTo(request.day, anchor: request.anchor)
                    }
                }
            }
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
                    anchorDay = topDay ?? store.today
                }
                pinchVelocity = Double(value.velocity)
                zoom = TimelineZoom.value(base: pinchBase ?? zoom, magnification: Double(value.magnification))
            }
    }

    /// Runs when the fingers lift, and also when the system cancels the gesture.
    private func finishPinch() {
        guard pinchBase != nil else { return }
        pinchBase = nil
        setLevel(TimelineZoom.settledLevel(for: zoom, velocity: pinchVelocity), anchor: anchorDay)
    }

    private func setLevel(_ target: ZoomLevel, anchor: Date? = nil) {
        anchorDay = anchor ?? topDay ?? store.today
        UserDefaults.standard.set(target.rawValue, forKey: Self.zoomKey)
        withAnimation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.84)) {
            zoom = Double(target.rawValue)
        }
    }

    private static func storedZoom() -> Double {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: zoomKey) != nil else { return Double(ZoomLevel.schedule.rawValue) }
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

    private func loadEarlier() {
        let firstDay = store.days.first?.date
        Task {
            await store.loadEarlier()
            // Earlier days were added above. Keep the day that was first in the middle
            // of the screen, so the newly loaded days show just above it.
            if let firstDay {
                scrollRequest = ScrollRequest(day: firstDay, animated: false, anchor: .center)
            }
        }
    }
}

/// Re-renders its content on every frame of a zoom animation, so text sizes glide
/// to the settled level instead of jumping there.
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
    let id = UUID()
    let day: Date
    let animated: Bool
    var anchor: UnitPoint = .top
}

enum SheetRoute: Identifiable {
    case detail(CalendarEvent)
    case editor(EventDraft)
    case calendars

    var id: String {
        switch self {
        case .detail(let event): "detail-\(event.id)"
        case .editor(let draft): "editor-\(draft.id)"
        case .calendars: "calendars"
        }
    }
}

#Preview("Timeline") {
    TimelineScreen()
        .environment(CalendarStore.demo())
}
