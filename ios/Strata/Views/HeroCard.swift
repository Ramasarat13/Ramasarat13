import SwiftUI

/// One day of the hero card's week strip.
struct HeroDay: Identifiable, Equatable {
    let date: Date
    let hasEvents: Bool
    var id: Date { date }
}

/// The card at the top of the timeline: today's date over a sky that follows the
/// time of day, the week ahead as dots, and the view options.
struct HeroCard: View {
    let now: Date
    let week: [HeroDay]
    let level: ZoomLevel
    var onSelectDay: (Date) -> Void
    var onLevel: (ZoomLevel) -> Void
    var onEarlier: () -> Void

    var body: some View {
        SkyArtwork(date: now)
            .frame(height: 290)
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(alignment: .topLeading) {
                Text(now, format: .dateTime.day().month(.wide).year())
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 6, y: 1)
                    .padding(.leading, 22)
                    .padding(.top, 26)
                    .accessibilityHidden(true)
            }
            .overlay(alignment: .topTrailing) {
                optionsMenu
                    .padding(14)
            }
            .overlay(alignment: .bottomLeading) {
                Text(now, format: .dateTime.weekday(.abbreviated).day())
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.leading, 22)
                    .padding(.bottom, 18)
                    .accessibilityLabel(Text(now, format: .dateTime.weekday(.wide).day().month(.wide).year()))
                    .accessibilityAddTraits(.isHeader)
            }
            .overlay(alignment: .bottomTrailing) {
                weekStrip
                    .padding(.trailing, 14)
                    .padding(.bottom, 12)
            }
    }

    private var optionsMenu: some View {
        Menu {
            Picker("Detail", selection: Binding(get: { level }, set: { onLevel($0) })) {
                ForEach(ZoomLevel.allCases, id: \.self) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.inline)

            Button {
                onEarlier()
            } label: {
                Label("Load Earlier Events", systemImage: "clock.arrow.circlepath")
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.body.weight(.medium))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .glassSurface(in: Circle())
        }
        .accessibilityLabel("View options")
    }

    /// Today and the six days after it. A filled dot means the day has events.
    private var weekStrip: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(week) { day in
                Button {
                    onSelectDay(day.date)
                } label: {
                    VStack(spacing: 6) {
                        Circle()
                            .fill(day.hasEvents ? Color.white : Color.clear)
                            .overlay(Circle().strokeBorder(Color.white, lineWidth: 1.2))
                            .frame(width: 6, height: 6)
                        Text(day.date, format: .dateTime.day())
                            .font(.caption2.weight(.semibold))
                            .monospacedDigit()
                    }
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 44, alignment: .bottom)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(day.date, format: .dateTime.weekday(.wide).day().month(.wide)))
                .accessibilityValue(day.hasEvents ? "Has events" : "No events")
            }
        }
    }
}

/// A drawn landscape: sky, a sun or moon, and two hills. Its colors follow the hour.
struct SkyArtwork: View {
    let date: Date

    var body: some View {
        let palette = SkyPalette.at(hour: Calendar.current.component(.hour, from: date))
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                LinearGradient(colors: palette.sky, startPoint: .top, endPoint: .bottom)

                Circle()
                    .fill(LinearGradient(colors: palette.disc, startPoint: .top, endPoint: .bottom))
                    .frame(width: size.height * palette.discScale, height: size.height * palette.discScale)
                    .position(x: size.width * 0.5, y: size.height * 0.48)

                HillShape(leftHeight: 0.40, rightHeight: 0.26, crest: CGPoint(x: 0.30, y: 0.50))
                    .fill(palette.farHill)
                HillShape(leftHeight: 0.22, rightHeight: 0.30, crest: CGPoint(x: 0.62, y: 0.42))
                    .fill(LinearGradient(colors: palette.nearHill, startPoint: .top, endPoint: .bottom))

                // Keeps the white text readable at the top of the card.
                LinearGradient(colors: [.black.opacity(0.22), .clear], startPoint: .top, endPoint: .center)
            }
        }
        .accessibilityHidden(true)
    }
}

/// A hill rising from the bottom edge. Heights are fractions of the card's height.
private struct HillShape: Shape {
    let leftHeight: CGFloat
    let rightHeight: CGFloat
    /// The curve's control point: x across the card, y as a height from the bottom.
    let crest: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY - rect.height * leftHeight))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY - rect.height * rightHeight),
            control: CGPoint(x: rect.minX + rect.width * crest.x, y: rect.maxY - rect.height * crest.y)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct SkyPalette {
    let sky: [Color]
    let disc: [Color]
    let discScale: CGFloat
    let farHill: Color
    let nearHill: [Color]

    static func at(hour: Int) -> SkyPalette {
        switch hour {
        case 5..<8: dawn
        case 8..<17: day
        case 17..<20: dusk
        default: night
        }
    }

    static let dawn = SkyPalette(
        sky: [Color(hex: 0x6F83C2), Color(hex: 0xE2B4B2), Color(hex: 0xF7DEC8)],
        disc: [Color(hex: 0xFFE0C2), Color(hex: 0xF6B08C)],
        discScale: 0.62,
        farHill: Color(hex: 0x6F7B74),
        nearHill: [Color(hex: 0x3B463C), Color(hex: 0x222A24)]
    )

    static let day = SkyPalette(
        sky: [Color(hex: 0x5F86C8), Color(hex: 0xA9C0E4), Color(hex: 0xEFE2DA)],
        disc: [Color(hex: 0xF8C7AC), Color(hex: 0xF0A58A)],
        discScale: 0.62,
        farHill: Color(hex: 0x76856B),
        nearHill: [Color(hex: 0x3D4A36), Color(hex: 0x232B20)]
    )

    static let dusk = SkyPalette(
        sky: [Color(hex: 0x44528F), Color(hex: 0xC27C88), Color(hex: 0xF4B88F)],
        disc: [Color(hex: 0xFFC690), Color(hex: 0xF08A66)],
        discScale: 0.62,
        farHill: Color(hex: 0x5B4F63),
        nearHill: [Color(hex: 0x30293A), Color(hex: 0x1B1722)]
    )

    static let night = SkyPalette(
        sky: [Color(hex: 0x121830), Color(hex: 0x25305A), Color(hex: 0x4A4F7C)],
        disc: [Color(hex: 0xF4F1E6), Color(hex: 0xD6D2C4)],
        discScale: 0.40,
        farHill: Color(hex: 0x232B45),
        nearHill: [Color(hex: 0x161C2C), Color(hex: 0x0C1019)]
    )
}

#Preview("Hero") {
    HeroCard(
        now: .now,
        week: (0..<7).map { HeroDay(date: Date.now.addingTimeInterval(Double($0) * 86_400), hasEvents: $0 % 3 != 1) },
        level: .titles,
        onSelectDay: { _ in },
        onLevel: { _ in },
        onEarlier: {}
    )
    .padding(12)
}
