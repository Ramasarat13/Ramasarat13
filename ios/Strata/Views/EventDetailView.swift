import SwiftUI

/// Everything about one event, with the way into editing and deleting it.
struct EventDetailView: View {
    @Environment(CalendarStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let event: CalendarEvent

    @State private var editing: EventDraft?
    @State private var pendingDelete: CalendarEvent?
    @State private var errorMessage: String?

    private var calendar: CalendarInfo? { store.calendarsByID[event.calendarID] }
    private var color: Color { (calendar?.color ?? .gray).color }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    fields
                    if event.isEditable {
                        Button(role: .destructive) {
                            pendingDelete = event
                        } label: {
                            Text("Delete Event")
                                .frame(maxWidth: .infinity, minHeight: 28)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                if event.isEditable {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Edit") {
                            editing = EventDraft(editing: event)
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .sheet(item: $editing) { draft in
            // Once the edit is saved this sheet shows a stale event, so close it too.
            EventEditorView(draft: draft) {
                dismiss()
            }
        }
        .deleteEventDialog($pendingDelete) { target, span in
            Task {
                do {
                    try await store.delete(target, span: span)
                    dismiss()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
        .errorAlert($errorMessage)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(event.displayTitle)
                .font(.title2.bold())
                .fixedSize(horizontal: false, vertical: true)
            if store.calendar.isDate(event.start, inSameDayAs: event.end) {
                Text(event.start, format: .dateTime.weekday(.wide).day().month(.wide))
            }
            Text(Formatting.span(of: event, calendar: store.calendar))
                .foregroundStyle(.secondary)
        }
        .padding(.leading, 14)
        .overlay(alignment: .leading) {
            Capsule()
                .fill(color)
                .frame(width: 4)
        }
    }

    @ViewBuilder
    private var fields: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let calendar {
                DetailRow(icon: "calendar") {
                    Text("\(calendar.title) · \(calendar.accountName)")
                }
            }
            if event.isRecurring {
                DetailRow(icon: "repeat") {
                    Text(event.recurrence == .custom ? "Repeats" : "Repeats \(event.recurrence.label.lowercased())")
                }
            }
            if event.alert != .none {
                DetailRow(icon: "bell") {
                    Text(event.alert.label)
                }
            }
            if let location = event.location {
                DetailRow(icon: "mappin.and.ellipse") {
                    Button {
                        openInMaps(location)
                    } label: {
                        Text(location)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
            if let url = event.url {
                DetailRow(icon: "link") {
                    Link(url.host() ?? url.absoluteString, destination: url)
                }
            }
            if !event.attendees.isEmpty {
                DetailRow(icon: "person.2") {
                    Text(event.attendees.formatted(.list(type: .and)))
                }
            }
            if let notes = event.notes {
                DetailRow(icon: "text.alignleft") {
                    Text(notes)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private func openInMaps(_ location: String) {
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = [URLQueryItem(name: "q", value: location)]
        if let url = components?.url {
            openURL(url)
        }
    }
}

private struct DetailRow<Content: View>: View {
    let icon: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 22)
                .accessibilityHidden(true)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview("Event") {
    let store = CalendarStore.demo()
    return EventDetailView(
        event: CalendarEvent(
            id: "preview",
            providerID: "demo",
            eventIdentifier: "preview",
            calendarID: "demo:work",
            title: "Design review",
            start: .now,
            end: .now.addingTimeInterval(2700),
            isAllDay: false,
            location: "Studio, Room 2",
            notes: "Walk through the onboarding flow."
        )
    )
    .environment(store)
    .task { await store.reload() }
}
