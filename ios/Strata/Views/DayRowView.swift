import SwiftUI

/// What rows can ask the screen to do.
struct TimelineActions {
    var zoomInto: (Date) -> Void
    var open: (CalendarEvent) -> Void
    var edit: (CalendarEvent) -> Void
    var delete: (CalendarEvent) -> Void
    var newEvent: (Date) -> Void
}

enum EventPhase {
    case past, current, upcoming
}

/// One day of the timeline. The same view draws all four levels; what it shows
/// and how large depends on `metrics`, which follows the pinch continuously.
struct DayRowView: View {
    let day: TimelineDay
    let metrics: TimelineMetrics
    let now: Date
    let today: Date
    let calendars: [String: CalendarInfo]
    let actions: TimelineActions

    private static let maxDots = 9
    private static let maxTitles = 5

    private var isToday: Bool { day.date == today }
    private var isPast: Bool { day.date < today }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if day.startsMonth {
                MonthLabel(date: day.date, metrics: metrics)
            }
            HStack(alignment: .firstTextBaseline, spacing: metrics.gutter) {
                dateLabel
                    .frame(width: metrics.dateColumnWidth, alignment: .leading)
                content
                    .opacity(metrics.contentOpacity)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, metrics.dayPadding)
            .contentShape(Rectangle())
            .onTapGesture {
                // At the two compact levels a tap opens the day; deeper down, events take the taps.
                if metrics.level < .schedule {
                    actions.zoomInto(day.date)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(isToday ? "day-today" : "day-\(day.date.formatted(.iso8601.year().month().day()))")
    }

    // MARK: Date

    private var dateLabel: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(day.date, format: .dateTime.day())
                .font(.system(size: metrics.dateSize, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(isToday ? Color.accentColor : (isPast ? Color.secondary : Color.primary))
            Text(day.date, format: .dateTime.weekday(.abbreviated))
                .font(.system(size: metrics.metaSize, weight: isToday ? .semibold : .regular))
                .foregroundStyle(isToday ? Color.accentColor : Color.secondary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(dateAccessibilityLabel)
        .contextMenu {
            Button {
                actions.newEvent(day.date)
            } label: {
                Label("New Event", systemImage: "plus")
            }
        }
    }

    private var dateAccessibilityLabel: String {
        let date = day.date.formatted(.dateTime.weekday(.wide).month(.wide).day())
        return isToday ? "Today, \(date)" : date
    }

    // MARK: Content per level

    @ViewBuilder
    private var content: some View {
        switch metrics.level {
        case .glance: glance
        case .titles: titles
        case .schedule, .details: schedule
        }
    }

    private var glance: some View {
        let shown = Array(day.events.prefix(Self.maxDots))
        let extra = day.events.count - shown.count
        return HStack(spacing: metrics.dotSize * 0.6) {
            ForEach(Array(shown.enumerated()), id: \.offset) { _, event in
                Circle()
                    .fill(color(for: event))
                    .frame(width: metrics.dotSize, height: metrics.dotSize)
            }
            if extra > 0 {
                Text(verbatim: "+\(extra)")
                    .font(.system(size: metrics.metaSize))
                    .foregroundStyle(.secondary)
            }
            if day.events.isEmpty {
                emptyLabel
            }
        }
        .opacity(isPast ? 0.45 : 1)
        // Dots have no baseline of their own; sit them at the middle of the date's digits.
        .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + metrics.dateSize * 0.33 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(day.events.count == 1 ? "1 event" : "\(day.events.count) events")
    }

    @ViewBuilder
    private var titles: some View {
        if day.events.isEmpty {
            emptyLabel
        } else {
            titlesText
                .font(.system(size: metrics.titleSize))
                .lineLimit(2)
        }
    }

    /// The day's titles as one flowing line, each led by a dot in its calendar's color.
    private var titlesText: Text {
        let shown = day.events.prefix(Self.maxTitles)
        var line = Text(verbatim: "")
        for (index, event) in shown.enumerated() {
            let separator = Text(verbatim: index == 0 ? "" : "   ")
            let dot = Text(verbatim: "●")
                .font(.system(size: metrics.titleSize * 0.5))
                .foregroundStyle(color(for: event))
                .baselineOffset(metrics.titleSize * 0.18)
            let title = Text(verbatim: event.displayTitle)
                .foregroundStyle(phase(of: event) == .past ? Color.secondary : Color.primary)
            // A no-break space keeps a dot from being left behind at the end of a line.
            line = Text("\(line)\(separator)\(dot)\u{00A0}\(title)")
        }
        let extra = day.events.count - shown.count
        if extra > 0 {
            let more = Text(verbatim: "+\(extra)").foregroundStyle(Color.secondary)
            line = Text("\(line)   \(more)")
        }
        return line
    }

    private var schedule: some View {
        let nowIndex: Int? = isToday ? day.nowIndex(at: now) : nil
        return VStack(alignment: .leading, spacing: metrics.eventSpacing) {
            ForEach(Array(day.events.enumerated()), id: \.element.id) { index, event in
                if index == nowIndex {
                    NowMarker(now: now, metrics: metrics)
                }
                EventRowView(
                    event: event,
                    placement: day.placement(of: event),
                    metrics: metrics,
                    calendar: calendars[event.calendarID],
                    phase: phase(of: event),
                    isNext: index == nowIndex,
                    actions: actions
                )
            }
            if nowIndex == day.events.count {
                NowMarker(now: now, metrics: metrics)
            }
            if day.events.isEmpty {
                emptyLabel
            }
        }
    }

    private var emptyLabel: some View {
        Text("No events")
            .font(.system(size: metrics.metaSize))
            .foregroundStyle(.tertiary)
    }

    // MARK: Helpers

    private func color(for event: CalendarEvent) -> Color {
        (calendars[event.calendarID]?.color ?? .gray).color
    }

    private func phase(of event: CalendarEvent) -> EventPhase {
        if isPast { return .past }
        guard isToday else { return .upcoming }
        if day.placement(of: event) == .allDay { return .upcoming }
        if event.end <= now { return .past }
        return event.start <= now ? .current : .upcoming
    }
}

/// A quiet label where one month ends and the next begins.
struct MonthLabel: View {
    let date: Date
    let metrics: TimelineMetrics

    var body: some View {
        Text(date, format: .dateTime.month(.wide).year())
            .font(.system(size: metrics.monthSize, weight: .semibold))
            .tracking(0.8)
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
            .padding(.top, metrics.monthTopPadding)
            .padding(.bottom, 6)
            .accessibilityAddTraits(.isHeader)
    }
}

/// The current time, drawn between what has started and what is still to come.
struct NowMarker: View {
    let now: Date
    let metrics: TimelineMetrics

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 7, height: 7)
            Text(Formatting.time(now))
                .font(.system(size: metrics.metaSize, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Color.accentColor)
            Rectangle()
                .fill(Color.accentColor.opacity(0.35))
                .frame(height: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Now, \(Formatting.time(now))")
    }
}
