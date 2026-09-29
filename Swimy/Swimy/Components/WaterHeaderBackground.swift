import SwiftUI

/// A light pool-tile wash behind the top of a screen, fading into the background.
struct WaterHeaderBackground: View {
    var height: CGFloat = 340

    var body: some View {
        ZStack(alignment: .top) {
            Color.screenBackground
            PoolTileView(tileSize: 34)
                .frame(height: height)
                .opacity(0.3)
                .mask {
                    LinearGradient(
                        colors: [.black, .black.opacity(0.5), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

#Preview {
    WaterHeaderBackground()
}
