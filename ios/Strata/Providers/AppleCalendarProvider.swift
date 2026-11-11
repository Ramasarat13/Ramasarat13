import EventKit
import Foundation

/// Reads and writes the calendars set up on the device (iCloud, Exchange, and any
/// Google account added in iOS Settings) through EventKit.
final class AppleCalendarProvider: CalendarProvider {
    static let providerID = "apple"

    let id = AppleCalendarProvider.providerID
    let displayName = "Apple Calendar"
    var onChange: (() -> Void)?

    private let store = EKEventStore()
    private var observer: NSObjectProtocol?

    init() {
        observer = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: .main
        ) { [weak self] _ in
            self?.onChange?()
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: Access

    var access: CalendarAccess {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        case .writeOnly: return .writeOnly
        case .fullAccess: return .granted
        default: return .denied
        }
    }

    func requestAccess() async -> CalendarAccess {
        _ = try? await store.requestFullAccessToEvents()
        return access
    }

    // MARK: Reading

    func calendars() async throws -> [CalendarInfo] {
        store.calendars(for: .event).map(Self.info(from:))
    }

    func defaultCalendarID() -> String? {
        store.defaultCalendarForNewEvents.map { Self.scopedID($0.calendarIdentifier) }
    }

    func events(in interval: DateInterval) async throws -> [CalendarEvent] {
        let store = self.store
        return await Task.detached(priority: .userInitiated) {
            // EventKit only searches up to four years at a time, so read a year per pass.
            var result: [CalendarEvent] = []
            var seen = Set<String>()
            let calendar = Calendar.current
            var chunkStart = interval.start
            while chunkStart < interval.end {
                let nextYear = calendar.date(byAdding: .year, value: 1, to: chunkStart) ?? interval.end
                let chunkEnd = min(nextYear, interval.end)
                let predicate = store.predicateForEvents(withStart: chunkStart, end: chunkEnd, calendars: nil)
                for ekEvent in store.events(matching: predicate) {
                    let event = AppleCalendarProvider.event(from: ekEvent)
                    if seen.insert(event.id).inserted {
                        result.append(event)
                    }
                }
                chunkStart = chunkEnd
            }
            return result
        }.value
    }

    // MARK: Writing

    func save(_ draft: EventDraft, span: EditSpan) async throws {
        let ekEvent: EKEvent
        if let existing = draft.existing {
            guard let found = findEKEvent(for: existing) else { throw CalendarError.eventNotFound }
            ekEvent = found
        } else {
            ekEvent = EKEvent(eventStore: store)
        }

        guard let calendar = store.calendar(withIdentifier: Self.nativeID(draft.calendarID)) else {
            throw CalendarError.calendarNotFound
        }
        guard calendar.allowsContentModifications else { throw CalendarError.readOnlyCalendar }

        ekEvent.calendar = calendar
        ekEvent.title = draft.title.trimmed
        ekEvent.isAllDay = draft.isAllDay
        ekEvent.startDate = draft.start
        ekEvent.endDate = draft.end
        ekEvent.location = draft.location.nilIfBlank
        ekEvent.notes = draft.notes.nilIfBlank
        ekEvent.url = draft.url

        var span = span
        let previousRecurrence = draft.existing?.recurrence ?? .never
        if draft.recurrence != .custom, draft.recurrence != previousRecurrence {
            ekEvent.recurrenceRules = Self.rule(for: draft.recurrence).map { [$0] }
            // A new repeat pattern only makes sense for the series from here on.
            if draft.existing != nil { span = .futureEvents }
        }

        let previousAlert = draft.existing?.alert ?? EventAlert.none
        if draft.alert != previousAlert {
            switch draft.alert {
            case .none:
                ekEvent.alarms = nil
            case .before(let seconds):
                ekEvent.alarms = [EKAlarm(relativeOffset: -seconds)]
            }
        }

        try store.save(ekEvent, span: Self.ekSpan(span), commit: true)
    }

    func delete(_ event: CalendarEvent, span: EditSpan) async throws {
        guard let ekEvent = findEKEvent(for: event) else { throw CalendarError.eventNotFound }
        try store.remove(ekEvent, span: Self.ekSpan(span), commit: true)
    }

    /// Finds the EventKit object for one occurrence. `event(withIdentifier:)` alone
    /// returns the first occurrence of a repeating event, so search by date first.
    private func findEKEvent(for event: CalendarEvent) -> EKEvent? {
        let predicate = store.predicateForEvents(
            withStart: event.start.addingTimeInterval(-1),
            end: max(event.end, event.start).addingTimeInterval(1),
            calendars: nil
        )
        let match = store.events(matching: predicate).first { candidate in
            candidate.eventIdentifier == event.eventIdentifier
                && abs(candidate.startDate.timeIntervalSince(event.start)) < 1
        }
        if let match { return match }
        return event.isRecurring ? nil : store.event(withIdentifier: event.eventIdentifier)
    }

    // MARK: Mapping

    static func scopedID(_ nativeID: String) -> String {
        "\(providerID):\(nativeID)"
    }

    static func nativeID(_ scopedID: String) -> String {
        let prefix = "\(providerID):"
        return scopedID.hasPrefix(prefix) ? String(scopedID.dropFirst(prefix.count)) : scopedID
    }

    private static func ekSpan(_ span: EditSpan) -> EKSpan {
        switch span {
        case .thisEvent: .thisEvent
        case .futureEvents: .futureEvents
        }
    }

    private static func info(from calendar: EKCalendar) -> CalendarInfo {
        CalendarInfo(
            id: scopedID(calendar.calendarIdentifier),
            providerID: providerID,
            title: calendar.title,
            accountName: accountName(for: calendar.source),
            color: RGBAColor(cgColor: calendar.cgColor),
            isEditable: calendar.allowsContentModifications
        )
    }

    private static func accountName(for source: EKSource?) -> String {
        guard let source else { return "Other" }
        switch source.sourceType {
        case .local: return "On My iPhone"
        case .birthdays: return "Other"
        case .subscribed: return "Subscribed"
        default: return source.title.isEmpty ? "Other" : source.title
        }
    }

    private static func event(from ekEvent: EKEvent) -> CalendarEvent {
        let identifier: String = ekEvent.eventIdentifier ?? UUID().uuidString
        let start: Date = ekEvent.startDate ?? .now
        let end: Date = ekEvent.endDate ?? start
        let calendar: EKCalendar? = ekEvent.calendar
        return CalendarEvent(
            id: "\(providerID):\(identifier)|\(Int(start.timeIntervalSinceReferenceDate))",
            providerID: providerID,
            eventIdentifier: identifier,
            calendarID: scopedID(calendar?.calendarIdentifier ?? ""),
            title: ekEvent.title ?? "",
            start: start,
            end: end,
            isAllDay: ekEvent.isAllDay,
            location: ekEvent.location?.nilIfBlank,
            notes: ekEvent.notes?.nilIfBlank,
            url: ekEvent.url,
            recurrence: recurrence(from: ekEvent),
            alert: alert(from: ekEvent, start: start),
            attendees: (ekEvent.attendees ?? []).compactMap(\.name),
            isEditable: calendar?.allowsContentModifications ?? false
        )
    }

    private static func recurrence(from ekEvent: EKEvent) -> Recurrence {
        guard ekEvent.hasRecurrenceRules, let rule = ekEvent.recurrenceRules?.first else { return .never }
        let isPlain = (rule.daysOfTheWeek?.count ?? 0) <= 1
            && (rule.daysOfTheMonth?.count ?? 0) <= 1
            && (rule.monthsOfTheYear?.count ?? 0) <= 1
            && (rule.setPositions?.isEmpty ?? true)
        guard isPlain else { return .custom }
        switch (rule.frequency, rule.interval) {
        case (.daily, 1): return .daily
        case (.weekly, 1): return .weekly
        case (.weekly, 2): return .biweekly
        case (.monthly, 1): return .monthly
        case (.yearly, 1): return .yearly
        default: return .custom
        }
    }

    private static func rule(for recurrence: Recurrence) -> EKRecurrenceRule? {
        switch recurrence {
        case .never, .custom: nil
        case .daily: EKRecurrenceRule(recurrenceWith: .daily, interval: 1, end: nil)
        case .weekly: EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, end: nil)
        case .biweekly: EKRecurrenceRule(recurrenceWith: .weekly, interval: 2, end: nil)
        case .monthly: EKRecurrenceRule(recurrenceWith: .monthly, interval: 1, end: nil)
        case .yearly: EKRecurrenceRule(recurrenceWith: .yearly, interval: 1, end: nil)
        }
    }

    private static func alert(from ekEvent: EKEvent, start: Date) -> EventAlert {
        guard let alarm = ekEvent.alarms?.first else { return .none }
        if let absolute = alarm.absoluteDate {
            return .before(max(0, start.timeIntervalSince(absolute)))
        }
        return .before(max(0, -alarm.relativeOffset))
    }
}
