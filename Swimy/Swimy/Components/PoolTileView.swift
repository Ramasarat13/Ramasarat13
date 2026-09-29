import SwiftUI

/// The signature pool-tile surface: blue water, grout lines and soft caustic light.
///
/// Reused by the Lifetime card, empty states and the Summary header. Phase 4 swaps
/// the still caustics for a slow Metal shader loop (paused with Reduce Motion).
struct PoolTileView: View {
    var tileSize: CGFloat = 32
    var showsCaustics = true

    var body: some View {
        Canvas { context, size in
            let bounds = CGRect(origin: .zero, size: size)
            context.fill(
                Path(bounds),
                with: .linearGradient(
                    Gradient(colors: [.poolTile, .poolTileDeep]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: 0, y: size.height)
                )
            )

            if showsCaustics {
                drawCaustics(in: &context, size: size)
            }

            var grout = Path()
            var x = tileSize
            while x < size.width {
                grout.addRect(CGRect(x: x - 0.75, y: 0, width: 1.5, height: size.height))
                x += tileSize
            }
            var y = tileSize
            while y < size.height {
                grout.addRect(CGRect(x: 0, y: y - 0.75, width: size.width, height: 1.5))
                y += tileSize
            }
            context.fill(grout, with: .color(.poolTileGrout.opacity(0.8)))
        }
        .accessibilityHidden(true)
    }

    /// Wavy bands of soft light, like sun through water.
    private func drawCaustics(in context: inout GraphicsContext, size: CGSize) {
        let spacing = tileSize * 1.6
        let tile = tileSize
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: tile / 5))
            let bands = Int(size.height / spacing) + 2
            for band in 0..<bands {
                let baseY = CGFloat(band) * spacing
                let phase = CGFloat(band) * 1.3
                var path = Path()
                var x: CGFloat = -10
                path.move(to: CGPoint(x: x, y: baseY))
                while x <= size.width + 10 {
                    let wave = sin(x / 38 + phase) * tile * 0.28 + sin(x / 13 + phase) * tile * 0.08
                    path.addLine(to: CGPoint(x: x, y: baseY + wave))
                    x += 6
                }
                layer.stroke(path, with: .color(.white.opacity(0.16)), lineWidth: max(2, tile / 10))
            }
        }
    }
}

#Preview {
    PoolTileView()
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .padding()
}
