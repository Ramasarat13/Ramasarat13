import SwiftUI

/// One event at the Schedule and Details levels. Details adds the end time,
/// duration, calendar, place and notes, which fade in as the pinch arrives.
struct EventRowView: View {
    let event: CalendarEvent
    let placement: TimelineDay.Placement
    let metrics: TimelineMetrics
    let calendar: CalendarInfo?
    let phase: EventPhase
    /// True for the first event still to come today, which shows how soon it starts.
    let isNext: Bool
    let actions: TimelineActions

    private var color: Color { (calendar?.color ?? .gray).color }

    var body: some View {
        Button {
            actions.open(event)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: metrics.gutter) {
                timeColumn
                    .frame(width: metrics.timeColumnWidth, alignment: .leading)
                textColumn
                    .padding(.leading, 10)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(color)
                            .frame(width: 3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(phase == .past ? 0.45 : 1)
        .contextMenu {
            Button {
                actions.open(event)
            } label: {
                Label("Details", systemImage: "info.circle")
            }
            if event.isEditable {
                Button {
                    actions.edit(event)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    actions.delete(event)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private var timeColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(startLabel)
                .foregroundStyle(phase == .current ? Color.accentColor : Color.secondary)
            if metrics.level == .details, let endLabel {
                Text(endLabel)
                    .foregroundStyle(.tertiary)
                    .opacity(metrics.detailReveal)
            }
        }
        .font(.system(size: metrics.metaSize))
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }

    private var textColumn: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(event.displayTitle)
                    .font(.system(size: metrics.titleSize, weight: .medium))
                    .lineLimit(metrics.level == .details ? 3 : 1)
                if let badge {
                    Text(badge)
                        .font(.system(size: metrics.metaSize, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            if metrics.level == .details {
                VStack(alignment: .leading, spacing: 3) {
                    if !metaLine.isEmpty {
                        Text(metaLine)
                            .foregroundStyle(.secondary)
                    }
                    if let location = event.location {
                        Text("\(Image(systemName: "mappin.and.ellipse")) \(location)")
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    if let notes = event.notes {
                        Text(notes)
                            .foregroundStyle(.tertiary)
                            .lineLimit(3)
                    }
                }
                .font(.system(size: metrics.metaSize))
                .multilineTextAlignment(.leading)
                .opacity(metrics.detailReveal)
            }
        }
    }

    // MARK: Labels

    private var startLabel: String {
        switch placement {
        case .allDay: "all-day"
        case .within, .startsToday: Formatting.time(event.start)
        case .endsToday: "→ \(Formatting.time(event.end))"
        }
    }

    private var endLabel: String? {
        guard placement == .within, event.end > event.start else { return nil }
        return Formatting.time(event.end)
    }

    private var badge: String? {
        switch phase {
        case .current:
            return "Now"
        case .upcoming where isNext && event.start.timeIntervalSinceNow < 12 * 3600:
            return Formatting.relative(event.start)
        default:
            return nil
        }
    }

    private var metaLine: String {
        var parts: [String] = []
        if placement == .within, event.end > event.start {
            parts.append(Formatting.duration(from: event.start, to: event.end))
        }
        if let calendar {
            parts.append(calendar.title)
        }
        if event.isRecurring {
            parts.append("Repeats")
        }
        return parts.joined(separator: " · ")
    }
}
