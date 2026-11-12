import SwiftUI

/// The second tab: which calendars are layered onto the timeline, grouped by account.
struct CalendarsScreen: View {
    @Environment(CalendarStore.self) private var store

    private var allVisible: Bool { store.hiddenCalendarIDs.isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Calendars")
                        .font(.largeTitle.weight(.semibold))
                    Spacer()
                    Button(allVisible ? "Hide All" : "Show All") {
                        store.setAllVisible(!allVisible)
                    }
                    .font(.subheadline.weight(.medium))
                    .frame(minHeight: 44)
                }
                .padding(.top, 20)

                Text("Choose what appears on your timeline.")
                    .font(.system(size: 17, weight: .light))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                    .padding(.bottom, 12)

                ForEach(store.calendarGroups) { group in
                    Text(group.name)
                        .font(.system(size: 17, weight: .medium))
                        .padding(.top, 26)
                        .padding(.bottom, 6)
                        .accessibilityAddTraits(.isHeader)

                    ForEach(group.calendars) { calendar in
                        row(for: calendar)
                        Divider()
                            .opacity(0.55)
                    }
                }

                if store.isDemo {
                    Text("These are sample events. Connect Apple Calendar to see your own.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 32)
                    Button("Connect Apple Calendar") {
                        store.useAppleCalendar()
                    }
                    .font(.body.weight(.medium))
                    .frame(minHeight: 44)
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.systemBackground))
    }

    private func row(for calendar: CalendarInfo) -> some View {
        let visible = store.isVisible(calendar.id)
        return Button {
            store.setVisible(!visible, calendarID: calendar.id)
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(calendar.color.color)
                    .frame(width: 9, height: 9)
                Text(calendar.title)
                    .font(.system(size: 17, weight: .light))
                    .foregroundStyle(visible ? Color.ink : Color.secondary)
                if !calendar.isEditable {
                    Text("Read-only")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Image(systemName: visible ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(visible ? calendar.color.color : Color.secondary.opacity(0.5))
            }
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(visible ? "Shown" : "Hidden")
    }
}

#Preview("Calendars") {
    let store = CalendarStore.demo()
    return CalendarsScreen()
        .environment(store)
        .task { await store.reload() }
}
