import SwiftUI

/// Chooses which calendars appear on the timeline, grouped by account.
struct CalendarListView: View {
    @Environment(CalendarStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private var allVisible: Bool { store.hiddenCalendarIDs.isEmpty }

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.calendarGroups) { group in
                    Section(group.name) {
                        ForEach(group.calendars) { calendar in
                            row(for: calendar)
                        }
                    }
                }

                if store.isDemo {
                    Section {
                        Button("Connect Apple Calendar") {
                            store.useAppleCalendar()
                            dismiss()
                        }
                    } footer: {
                        Text("You're looking at sample events. Connect Apple Calendar to see your own.")
                    }
                }
            }
            .navigationTitle("Calendars")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(allVisible ? "Hide All" : "Show All") {
                        store.setAllVisible(!allVisible)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func row(for calendar: CalendarInfo) -> some View {
        let visible = store.isVisible(calendar.id)
        return Button {
            store.setVisible(!visible, calendarID: calendar.id)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: visible ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(calendar.color.color)
                Text(calendar.title)
                    .foregroundStyle(.primary)
                Spacer()
                if !calendar.isEditable {
                    Text("Read-only")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(visible ? "Shown" : "Hidden")
    }
}

#Preview("Calendars") {
    let store = CalendarStore.demo()
    return CalendarListView()
        .environment(store)
        .task { await store.reload() }
}
