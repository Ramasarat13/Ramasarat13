import Foundation

/// A source of calendars and events.
///
/// Apple Calendar (EventKit) is the first one. Google Calendar is added by writing
/// another type that conforms to this protocol and passing it to `CalendarStore`;
/// the timeline, editor and calendar list only ever see the models in
/// `CalendarModels.swift`.
protocol CalendarProvider: AnyObject {
    /// Stable identifier, used as the prefix of every calendar and event id.
    var id: String { get }
    var displayName: String { get }
    var access: CalendarAccess { get }

    /// Called on the main thread whenever the provider's data changes underneath the app.
    var onChange: (() -> Void)? { get set }

    func requestAccess() async -> CalendarAccess
    func calendars() async throws -> [CalendarInfo]
    /// The calendar new events should go to unless the user picks another.
    func defaultCalendarID() -> String?
    func events(in interval: DateInterval) async throws -> [CalendarEvent]
    /// Creates the event when `draft.existing` is nil, otherwise updates it.
    func save(_ draft: EventDraft, span: EditSpan) async throws
    func delete(_ event: CalendarEvent, span: EditSpan) async throws
}
