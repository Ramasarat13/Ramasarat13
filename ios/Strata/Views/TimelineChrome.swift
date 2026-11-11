import SwiftUI

/// The month the top of the timeline is in, and the way into the calendar list.
struct TimelineHeader: View {
    let date: Date
    let isDemo: Bool
    var onCalendars: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(date, format: .dateTime.month(.wide))
                .font(.largeTitle.bold())
                .accessibilityIdentifier("headerMonth")
            Text(date, format: .dateTime.year())
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            if isDemo {
                Text("Sample")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
            }
            Spacer(minLength: 8)
            Button(action: onCalendars) {
                Image(systemName: "calendar")
                    .font(.title3.weight(.medium))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Calendars")
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .contentTransition(.opacity)
        .animation(.snappy, value: date.formatted(.dateTime.month().year()))
        .padding(.leading, 20)
        .padding(.trailing, 8)
        .padding(.top, 4)
        .padding(.bottom, 6)
        .background(.bar)
    }
}

/// Floating controls: jump to today, step the detail level without pinching, add an event.
struct TimelineToolbar: View {
    let level: ZoomLevel
    var onToday: () -> Void
    var onLevel: (ZoomLevel) -> Void
    var onAdd: () -> Void

    @ScaledMetric(relativeTo: .subheadline) private var levelLabelWidth: CGFloat = 80

    var body: some View {
        ZStack {
            levelStepper
            HStack {
                Button(action: onToday) {
                    Text("Today")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .background(.regularMaterial, in: Capsule())
                        .overlay(Capsule().strokeBorder(.separator, lineWidth: 0.5))
                }
                Spacer()
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.accentColor, in: Circle())
                        .shadow(color: Color.accentColor.opacity(0.3), radius: 8, y: 4)
                }
                .accessibilityLabel("New Event")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 32)
        .padding(.bottom, 8)
        .background {
            // Fades the timeline out before it reaches the controls, so nothing shows through them.
            LinearGradient(
                stops: [
                    .init(color: Color(.systemBackground).opacity(0), location: 0),
                    .init(color: Color(.systemBackground), location: 0.38),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }

    private var levelStepper: some View {
        HStack(spacing: 0) {
            Button {
                if let next = level.lessDetail { onLevel(next) }
            } label: {
                Image(systemName: "minus")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .disabled(level.lessDetail == nil)
            .accessibilityLabel("Less detail")

            Text(level.label)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: levelLabelWidth)
                .contentTransition(.opacity)
                .animation(.snappy, value: level)
                .accessibilityIdentifier("zoomLevelLabel")

            Button {
                if let next = level.moreDetail { onLevel(next) }
            } label: {
                Image(systemName: "plus")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .disabled(level.moreDetail == nil)
            .accessibilityLabel("More detail")
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.primary)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.separator, lineWidth: 0.5))
    }
}

// MARK: Shared dialogs

extension View {
    /// Asks before deleting, offering "this one" or "all future" for repeating events.
    func deleteEventDialog(
        _ event: Binding<CalendarEvent?>,
        onDelete: @escaping (CalendarEvent, EditSpan) -> Void
    ) -> some View {
        confirmationDialog(
            event.wrappedValue.map { "Delete “\($0.displayTitle)”?" } ?? "Delete event?",
            isPresented: Binding(
                get: { event.wrappedValue != nil },
                set: { if !$0 { event.wrappedValue = nil } }
            ),
            titleVisibility: .visible,
            presenting: event.wrappedValue
        ) { target in
            if target.isRecurring {
                Button("Delete This Event Only", role: .destructive) { onDelete(target, .thisEvent) }
                Button("Delete All Future Events", role: .destructive) { onDelete(target, .futureEvents) }
            } else {
                Button("Delete Event", role: .destructive) { onDelete(target, .thisEvent) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { target in
            Text(target.isRecurring ? "This is a repeating event." : "This can't be undone.")
        }
    }

    func errorAlert(_ message: Binding<String?>) -> some View {
        alert(
            "Something went wrong",
            isPresented: Binding(
                get: { message.wrappedValue != nil },
                set: { if !$0 { message.wrappedValue = nil } }
            ),
            presenting: message.wrappedValue
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { text in
            Text(text)
        }
    }
}
