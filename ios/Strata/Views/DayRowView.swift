import SwiftUI

/// What rows can ask the screen to do.
struct TimelineActions {
    var open: (CalendarEvent) -> Void
    var edit: (CalendarEvent) -> Void
    var delete: (CalendarEvent) -> Void
    var newEvent: (Date) -> Void
}

enum EventPhase {
    case past, current, upcoming
}

/// One day of the timeline: its date, then its events as lines of text that say
/// more the further the timeline is zoomed.
struct DayRowView: View {
    let day: TimelineDay
    let metrics: TimelineMetrics
    let now: Date
    let today: Date
    let calendars: [String: CalendarInfo]
    let actions: TimelineActions

    private var isToday: Bool { day.date == today }
    private var isPast: Bool { day.date < today }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                header
                events
            }
            .padding(.vertical, metrics.dayPadding)
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
                .opacity(0.55)
        }
        .padding(.horizontal, 16)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(isToday ? "day-today" : "day-\(day.date.formatted(.iso8601.year().month().day()))")
    }

    // MARK: Heading

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 9) {
            Text(dateText)
                .font(.system(size: metrics.headerSize, weight: .medium))
                .foregroundStyle(isPast ? Color.secondary : Color.primary)
            Text(verbatim: "·")
                .font(.system(size: metrics.headerSize, weight: .medium))
                .foregroundStyle(.quaternary)
            Text(isToday ? "Today" : day.date.formatted(.dateTime.weekday(.wide)))
                .font(.system(size: metrics.headerSize))
                .foregroundStyle(isToday ? Color.live : Color.secondary.opacity(0.65))
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(headerAccessibilityLabel)
        .accessibilityAddTraits(.isHeader)
        .contextMenu {
            Button {
                actions.newEvent(day.date)
            } label: {
                Label("New Event", systemImage: "plus")
            }
        }
    }

    /// "22 September", with the year added once the timeline leaves the current one.
    private var dateText: String {
        let sameYear = Calendar.current.isDate(day.date, equalTo: today, toGranularity: .year)
        let style = Date.FormatStyle.dateTime.day().month(.wide)
        return day.date.formatted(sameYear ? style : style.year())
    }

    private var headerAccessibilityLabel: String {
        let date = day.date.formatted(.dateTime.weekday(.wide).day().month(.wide))
        return isToday ? "Today, \(date)" : date
    }

    // MARK: Events

    private var events: some View {
        // The live marker joins the list once start times are showing.
        let upcomingIndex: Int? = isToday ? day.nowIndex(at: now) : nil
        let markerIndex: Int? = metrics.level >= .times ? upcomingIndex : nil
        return VStack(alignment: .leading, spacing: metrics.rowSpacing) {
            ForEach(Array(day.events.enumerated()), id: \.element.id) { index, event in
                if index == markerIndex {
                    NowMarker(now: now, metrics: metrics)
                }
                EventRowView(
                    event: event,
                    placement: day.placement(of: event),
                    metrics: metrics,
                    calendar: calendars[event.calendarID],
                    phase: phase(of: event),
                    isNext: index == upcomingIndex,
                    actions: actions
                )
            }
            if markerIndex == day.events.count, !day.events.isEmpty {
                NowMarker(now: now, metrics: metrics)
            }
            if day.events.isEmpty {
                Text("Nothing planned")
                    .font(.system(size: metrics.titleSize, weight: .light))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func phase(of event: CalendarEvent) -> EventPhase {
        if isPast { return .past }
        guard isToday else { return .upcoming }
        if day.placement(of: event) == .allDay { return .upcoming }
        if event.end <= now { return .past }
        return event.start <= now ? .current : .upcoming
    }
}

/// The current time, drawn between what has started and what is still to come.
struct NowMarker: View {
    let now: Date
    let metrics: TimelineMetrics

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.live)
                .frame(width: 6, height: 6)
            Text(Formatting.time(now))
                .font(.system(size: metrics.timeSize, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Color.live)
            Rectangle()
                .fill(Color.live.opacity(0.3))
                .frame(height: 1)
        }
        .opacity(metrics.timeReveal)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Now, \(Formatting.time(now))")
    }
}
