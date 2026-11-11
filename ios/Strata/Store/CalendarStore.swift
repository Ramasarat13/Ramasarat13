import Foundation
import Observation

/// The app's single source of truth: which calendars exist, which are shown, and
/// the timeline built from their events. Views read it; providers feed it.
@MainActor
@Observable
final class CalendarStore {
    private(set) var access: CalendarAccess
    private(set) var calendars: [CalendarInfo] = []
    private(set) var calendarsByID: [String: CalendarInfo] = [:]
    private(set) var hiddenCalendarIDs: Set<String> = []
    private(set) var days: [TimelineDay] = []
    /// Midnight at the start of the current day, as of the last build.
    private(set) var today: Date
    private(set) var hasLoaded = false
    private(set) var isDemo: Bool

    let calendar: Calendar

    @ObservationIgnored private var providers: [any CalendarProvider]
    @ObservationIgnored private var allEvents: [CalendarEvent] = []
    @ObservationIgnored private var range: DateInterval
    @ObservationIgnored private var loadGeneration = 0
    @ObservationIgnored private var buildGeneration = 0
    @ObservationIgnored private let defaults: UserDefaults

    private static let hiddenKey = "calendars.hidden"

    init(
        providers: [any CalendarProvider],
        isDemo: Bool = false,
        defaults: UserDefaults = .standard,
        calendar: Calendar = .autoupdatingCurrent,
        now: Date = .now
    ) {
        self.providers = providers
        self.isDemo = isDemo
        self.defaults = defaults
        self.calendar = calendar
        self.today = calendar.startOfDay(for: now)
        self.range = Self.initialRange(around: now, calendar: calendar)
        self.access = Self.combinedAccess(of: providers)
        if !isDemo {
            self.hiddenCalendarIDs = Set(defaults.stringArray(forKey: Self.hiddenKey) ?? [])
        }
        attachProviders()
    }

    static func live() -> CalendarStore {
        CalendarStore(providers: [AppleCalendarProvider()])
    }

    static func demo() -> CalendarStore {
        CalendarStore(providers: [DemoCalendarProvider()], isDemo: true)
    }

    // MARK: Access

    func refreshAccess() {
        access = Self.combinedAccess(of: providers)
    }

    func requestAccess() async {
        for provider in providers where provider.access == .notDetermined {
            _ = await provider.requestAccess()
        }
        refreshAccess()
        await reload()
    }

    /// Swaps the real calendars for sample data, for trying the app without granting access.
    func useSampleData() {
        providers = [DemoCalendarProvider()]
        isDemo = true
        hiddenCalendarIDs = []
        resetTimeline()
        attachProviders()
        refreshAccess()
    }

    func useAppleCalendar() {
        providers = [AppleCalendarProvider()]
        isDemo = false
        hiddenCalendarIDs = Set(defaults.stringArray(forKey: Self.hiddenKey) ?? [])
        resetTimeline()
        attachProviders()
        refreshAccess()
    }

    // MARK: Loading

    func reload() async {
        refreshAccess()
        guard access == .granted else { return }
        loadGeneration += 1
        let generation = loadGeneration
        let range = self.range
        do {
            var loadedCalendars: [CalendarInfo] = []
            var loadedEvents: [CalendarEvent] = []
            for provider in providers where provider.access == .granted {
                loadedCalendars += try await provider.calendars()
                loadedEvents += try await provider.events(in: range)
            }
            // A newer reload started while this one was waiting; let it win.
            guard generation == loadGeneration else { return }
            calendars = loadedCalendars.sorted {
                if $0.accountName != $1.accountName {
                    return $0.accountName.localizedStandardCompare($1.accountName) == .orderedAscending
                }
                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
            calendarsByID = Dictionary(calendars.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            allEvents = loadedEvents
            await rebuild()
        } catch {
            // Keep showing what was already loaded; the next change notification retries.
            hasLoaded = true
        }
    }

    /// Adds three more months of history above the current timeline.
    func loadEarlier() async {
        let start = calendar.date(byAdding: .month, value: -3, to: range.start) ?? range.start
        range = DateInterval(start: start, end: range.end)
        await reload()
    }

    private func rebuild() async {
        buildGeneration += 1
        let generation = buildGeneration
        let hidden = hiddenCalendarIDs
        let events = allEvents
        let calendar = self.calendar
        let range = self.range
        let now = Date.now
        let built = await Task.detached(priority: .userInitiated) {
            TimelineBuilder.days(
                from: hidden.isEmpty ? events : events.filter { !hidden.contains($0.calendarID) },
                calendar: calendar,
                today: now,
                range: range
            )
        }.value
        guard generation == buildGeneration else { return }
        today = calendar.startOfDay(for: now)
        days = built
        hasLoaded = true
    }

    private func resetTimeline() {
        loadGeneration += 1
        buildGeneration += 1
        calendars = []
        calendarsByID = [:]
        allEvents = []
        days = []
        hasLoaded = false
    }

    private func attachProviders() {
        for provider in providers {
            provider.onChange = { [weak self] in
                Task { @MainActor [weak self] in
                    await self?.reload()
                }
            }
        }
    }

    // MARK: Calendars

    var calendarGroups: [CalendarGroup] {
        let grouped = Dictionary(grouping: calendars) { "\($0.providerID)|\($0.accountName)" }
        return grouped
            .map { key, members in
                CalendarGroup(id: key, name: members.first?.accountName ?? "", calendars: members)
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var editableCalendars: [CalendarInfo] {
        calendars.filter(\.isEditable)
    }

    func isVisible(_ calendarID: String) -> Bool {
        !hiddenCalendarIDs.contains(calendarID)
    }

    func setVisible(_ visible: Bool, calendarID: String) {
        if visible {
            hiddenCalendarIDs.remove(calendarID)
        } else {
            hiddenCalendarIDs.insert(calendarID)
        }
        visibilityChanged()
    }

    func setAllVisible(_ visible: Bool) {
        hiddenCalendarIDs = visible ? [] : Set(calendars.map(\.id))
        visibilityChanged()
    }

    private func visibilityChanged() {
        if !isDemo {
            defaults.set(Array(hiddenCalendarIDs).sorted(), forKey: Self.hiddenKey)
        }
        Task { await rebuild() }
    }

    // MARK: Editing

    /// A new event on the given day at 9:00, or in the next full hour when the day is today.
    func newDraft(on day: Date? = nil, now: Date = .now) throws -> EventDraft {
        guard let calendarID = defaultCalendarID() else { throw CalendarError.noEditableCalendar }
        let target = calendar.startOfDay(for: day ?? now)
        let start: Date
        if calendar.isDate(target, inSameDayAs: now) {
            let hour = calendar.dateInterval(of: .hour, for: now)?.end ?? now
            start = hour
        } else {
            start = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: target) ?? target
        }
        return EventDraft(calendarID: calendarID, start: start, end: start.addingTimeInterval(3600))
    }

    private func defaultCalendarID() -> String? {
        let editable = editableCalendars
        for provider in providers {
            if let id = provider.defaultCalendarID(), editable.contains(where: { $0.id == id }) {
                return id
            }
        }
        return (editable.first { isVisible($0.id) } ?? editable.first)?.id
    }

    func save(_ draft: EventDraft, span: EditSpan = .thisEvent) async throws {
        let draft = draft.normalized(calendar: calendar)
        guard
            let target = calendarsByID[draft.calendarID],
            let provider = provider(target.providerID)
        else {
            throw CalendarError.calendarNotFound
        }

        if let existing = draft.existing, existing.providerID != target.providerID {
            // Moving between accounts of different providers: create the copy, then remove the original.
            var copy = draft
            copy.existing = nil
            try await provider.save(copy, span: .thisEvent)
            try await self.provider(existing.providerID)?.delete(existing, span: span)
        } else {
            try await provider.save(draft, span: span)
        }
        await reload()
    }

    func delete(_ event: CalendarEvent, span: EditSpan = .thisEvent) async throws {
        guard let provider = provider(event.providerID) else { throw CalendarError.eventNotFound }
        try await provider.delete(event, span: span)
        await reload()
    }

    private func provider(_ id: String) -> (any CalendarProvider)? {
        providers.first { $0.id == id }
    }

    // MARK: Helpers

    private static func combinedAccess(of providers: [any CalendarProvider]) -> CalendarAccess {
        let all = providers.map(\.access)
        if all.contains(.granted) { return .granted }
        return all.first ?? .notDetermined
    }

    /// From today to two years ahead. The timeline opens on today as its first row,
    /// so it never has to jump into the middle of a long list; `loadEarlier()` adds the past.
    private static func initialRange(around now: Date, calendar: Calendar) -> DateInterval {
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .month, value: 24, to: start) ?? start.addingTimeInterval(86_400 * 730)
        return DateInterval(start: start, end: end)
    }
}
