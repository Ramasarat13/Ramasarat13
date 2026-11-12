import SwiftUI

/// One event, written as a line of text that grows with the zoom: first the title,
/// then its time sliding in beside it, then its place and calendar, then its notes,
/// each arriving word by word.
struct EventRowView: View {
    let event: CalendarEvent
    let placement: TimelineDay.Placement
    let metrics: TimelineMetrics
    let calendar: CalendarInfo?
    let phase: EventPhase
    /// True for the first event still to come today, which shows how soon it starts.
    let isNext: Bool
    let actions: TimelineActions

    /// Notes can run long; the timeline shows their opening and the detail sheet the rest.
    private static let maxNoteWords = 45

    private var calendarColor: Color { (calendar?.color ?? .gray).color }

    var body: some View {
        Button {
            actions.open(event)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                timeColumn
                Circle()
                    .fill(calendarColor)
                    .frame(width: metrics.dotSize, height: metrics.dotSize)
                    // A dot has no baseline; sit it at the middle of the title's letters.
                    .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + metrics.titleSize * 0.31 }
                    .padding(.trailing, 10)
                    .accessibilityHidden(true)
                paragraph
                    .font(.system(size: metrics.titleSize, weight: .light))
                    .lineSpacing(5)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(phase == .past ? 0.45 : 1)
        .accessibilityLabel(accessibilityText)
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

    // MARK: Time

    /// Slides in from nothing between Titles and Times, pushing the text aside.
    private var timeColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(startLabel)
                .foregroundStyle(phase == .current ? Color.live : Color.secondary)
            if let endLabel, metrics.detailReveal > 0 {
                Text(endLabel)
                    .foregroundStyle(.tertiary)
                    .opacity(metrics.detailReveal)
            }
        }
        .font(.system(size: metrics.timeSize))
        .monospacedDigit()
        .lineLimit(1)
        .fixedSize()
        .frame(width: metrics.timeColumnWidth, alignment: .leading)
        .clipped()
        .opacity(metrics.timeReveal)
        .accessibilityHidden(true)
    }

    private var startLabel: String {
        switch placement {
        case .allDay: "All day"
        case .within, .startsToday: Formatting.time(event.start)
        case .endsToday: "Until"
        }
    }

    private var endLabel: String? {
        switch placement {
        case .within: event.end > event.start ? Formatting.time(event.end) : nil
        case .endsToday: Formatting.time(event.end)
        case .allDay, .startsToday: nil
        }
    }

    // MARK: Text

    private var paragraph: Text {
        var text = Text(verbatim: event.displayTitle).foregroundStyle(Color.ink)

        if let badge {
            let label = Text(verbatim: badge)
                .font(.system(size: metrics.timeSize, weight: .medium))
                .foregroundStyle(Color.live)
            text = Text("\(text)\u{00A0}\u{00A0}\(label)")
        }

        for piece in WordReveal.pieces(for: detailRuns, fraction: metrics.detailReveal) {
            text = Text("\(text) \(styled(piece))")
        }

        let notes = WordReveal.pieces(for: noteRuns, fraction: metrics.notesReveal)
        for (index, piece) in notes.enumerated() {
            // Notes start on a line of their own.
            text = Text("\(text)\(Text(verbatim: index == 0 ? "\n" : " "))\(styled(piece))")
        }
        return text
    }

    private func styled(_ piece: WordReveal.Piece) -> Text {
        let color: Color = switch piece.role {
        case .secondary: .secondary
        case .calendar: calendarColor
        case .notes: .secondary
        }
        return Text(verbatim: piece.text).foregroundStyle(color.opacity(piece.opacity))
    }

    /// Place and calendar, e.g. "· Studio, Room 2 · Work".
    private var detailRuns: [RevealRun] {
        var runs: [RevealRun] = []
        if let location = event.location {
            runs.append(RevealRun(text: "· \(location)", role: .secondary))
        }
        if event.isRecurring {
            runs.append(RevealRun(text: "· Repeats", role: .secondary))
        }
        if let calendar {
            runs.append(RevealRun(text: "·", role: .secondary))
            runs.append(RevealRun(text: calendar.title, role: .calendar))
        }
        return runs
    }

    private var noteRuns: [RevealRun] {
        guard let notes = event.notes else { return [] }
        let words = notes.split(whereSeparator: \.isWhitespace)
        guard words.count > Self.maxNoteWords else {
            return [RevealRun(text: words.joined(separator: " "), role: .notes)]
        }
        return [RevealRun(text: words.prefix(Self.maxNoteWords).joined(separator: " ") + "…", role: .notes)]
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

    /// What VoiceOver reads: everything the row currently shows, in order.
    private var accessibilityText: String {
        var parts: [String] = [event.displayTitle]
        if let badge { parts.append(badge) }
        if metrics.level >= .times {
            parts.append(placement == .allDay ? "All day" : Formatting.time(event.start))
        }
        if metrics.level >= .details {
            if let endLabel { parts.append("until \(endLabel)") }
            if let location = event.location { parts.append(location) }
            if let calendar { parts.append("\(calendar.title) calendar") }
        }
        if metrics.level >= .notes, let notes = event.notes {
            parts.append(notes)
        }
        return parts.joined(separator: ", ")
    }
}
