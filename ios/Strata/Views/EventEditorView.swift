import SwiftUI

/// The form for adding a new event or changing an existing one.
struct EventEditorView: View {
    @Environment(CalendarStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var draft: EventDraft
    @State private var isSaving = false
    @State private var askingSpan = false
    @State private var pendingDelete: CalendarEvent?
    @State private var errorMessage: String?
    @FocusState private var titleFocused: Bool

    private let recurrenceOptions: [Recurrence]
    private let alertOptions: [EventAlert]
    private let onFinish: () -> Void

    /// - Parameter onFinish: Called after the event was saved or deleted, before the form closes.
    init(draft: EventDraft, onFinish: @escaping () -> Void = {}) {
        _draft = State(initialValue: draft)
        self.onFinish = onFinish
        // Keep whatever the event already has selectable, even if this app can't create it.
        recurrenceOptions = Recurrence.selectable + (draft.recurrence == .custom ? [.custom] : [])
        alertOptions = EventAlert.presets + (EventAlert.presets.contains(draft.alert) ? [] : [draft.alert])
    }

    private var canSave: Bool {
        !draft.title.trimmed.isEmpty && !isSaving
    }

    private var dateComponents: DatePickerComponents {
        draft.isAllDay ? .date : [.date, .hourAndMinute]
    }

    private var editableGroups: [CalendarGroup] {
        store.calendarGroups.compactMap { group in
            let editable = group.calendars.filter(\.isEditable)
            return editable.isEmpty ? nil : CalendarGroup(id: group.id, name: group.name, calendars: editable)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $draft.title)
                        .font(.title3.weight(.semibold))
                        .focused($titleFocused)
                        .submitLabel(.done)
                    TextField("Location", text: $draft.location)
                        .textContentType(.fullStreetAddress)
                }

                Section {
                    Toggle("All-day", isOn: $draft.isAllDay)
                    DatePicker("Starts", selection: $draft.start, displayedComponents: dateComponents)
                    DatePicker("Ends", selection: $draft.end, in: draft.start..., displayedComponents: dateComponents)
                    Picker("Repeat", selection: $draft.recurrence) {
                        ForEach(recurrenceOptions, id: \.self) { option in
                            Text(option.label).tag(option)
                        }
                    }
                }

                Section {
                    Picker("Calendar", selection: $draft.calendarID) {
                        ForEach(editableGroups) { group in
                            Section(group.name) {
                                ForEach(group.calendars) { calendar in
                                    Label {
                                        Text(calendar.title)
                                    } icon: {
                                        Image(systemName: "circle.fill")
                                            .foregroundStyle(calendar.color.color)
                                    }
                                    .tag(calendar.id)
                                }
                            }
                        }
                    }
                    .pickerStyle(.navigationLink)

                    Picker("Alert", selection: $draft.alert) {
                        ForEach(alertOptions, id: \.self) { option in
                            Text(option.label).tag(option)
                        }
                    }
                }

                Section {
                    TextField("URL", text: $draft.urlString)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Notes", text: $draft.notes, axis: .vertical)
                        .lineLimit(3...8)
                }

                if let existing = draft.existing {
                    Section {
                        Button("Delete Event", role: .destructive) {
                            pendingDelete = existing
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(draft.isNew ? "New Event" : "Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(draft.isNew ? "Add" : "Save") {
                        attemptSave()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .onAppear {
            if draft.isNew { titleFocused = true }
        }
        .onChange(of: draft.start) { oldStart, newStart in
            // Moving the start keeps the event the same length.
            draft.end = draft.end.addingTimeInterval(newStart.timeIntervalSince(oldStart))
        }
        .confirmationDialog("This is a repeating event.", isPresented: $askingSpan, titleVisibility: .visible) {
            Button("Save for This Event Only") { save(span: .thisEvent) }
            Button("Save for Future Events") { save(span: .futureEvents) }
            Button("Cancel", role: .cancel) {}
        }
        .deleteEventDialog($pendingDelete) { target, span in
            finish { try await store.delete(target, span: span) }
        }
        .errorAlert($errorMessage)
        .interactiveDismissDisabled(isSaving)
    }

    private func attemptSave() {
        if draft.existing?.isRecurring == true {
            askingSpan = true
        } else {
            save(span: .thisEvent)
        }
    }

    private func save(span: EditSpan) {
        let draft = self.draft
        finish { try await store.save(draft, span: span) }
    }

    private func finish(_ work: @escaping () async throws -> Void) {
        isSaving = true
        Task {
            do {
                try await work()
                onFinish()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
}

#Preview("New event") {
    let store = CalendarStore.demo()
    return EventEditorView(draft: EventDraft(calendarID: "demo:personal", start: .now, end: .now.addingTimeInterval(3600)))
        .environment(store)
        .task { await store.reload() }
}
