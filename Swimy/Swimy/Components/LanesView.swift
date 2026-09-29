import SwiftUI

/// A swim's lengths drawn as rows of pool tiles, one tile per length.
/// Alternate rows are lighter, like swimming up and back down the lane.
struct LanesView: View {
    let lengths: Int
    let tint: Color

    var body: some View {
        Canvas { context, size in
            let count = max(lengths, 1)
            let gap: CGFloat = 2
            let aspect = Double(size.width / max(size.height, 1))
            let columns = max(1, Int((Double(count) * aspect).squareRoot().rounded(.up)))
            let rows = Int((Double(count) / Double(columns)).rounded(.up))
            let tileWidth = (size.width + gap) / CGFloat(columns) - gap
            let tileHeight = (size.height + gap) / CGFloat(rows) - gap
            let tile = max(1, min(tileWidth, tileHeight))

            for index in 0..<count {
                let row = index / columns
                let column = index % columns
                let rect = CGRect(
                    x: CGFloat(column) * (tile + gap),
                    y: CGFloat(row) * (tile + gap),
                    width: tile,
                    height: tile
                )
                let shade = row.isMultiple(of: 2) ? 1.0 : 0.65
                context.fill(
                    Path(roundedRect: rect, cornerRadius: min(Radius.tile, tile / 4)),
                    with: .color(tint.opacity(shade))
                )
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    LanesView(lengths: 60, tint: .metricDistance)
        .frame(width: 150, height: 40)
        .padding()
}
