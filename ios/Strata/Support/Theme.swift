import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    /// Marks what is happening right now: today, the current time, the event in progress.
    static let live = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.00, green: 0.58, blue: 0.42, alpha: 1)
            : UIColor(red: 0.88, green: 0.38, blue: 0.22, alpha: 1)
    })

    /// Body text of the timeline: softer than pure black, as in a printed page.
    static let ink = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.92, alpha: 1)
            : UIColor(white: 0.20, alpha: 1)
    })
}

extension View {
    /// The floating-control surface: Liquid Glass where the system has it, a material elsewhere.
    @ViewBuilder
    func glassSurface<S: Shape>(in shape: S) -> some View {
        // Liquid Glass arrived with the iOS 26 SDK (Swift 6.2). Older Xcodes build the fallback only.
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            glassEffect(.regular.interactive(), in: shape)
        } else {
            materialSurface(in: shape)
        }
        #else
        materialSurface(in: shape)
        #endif
    }

    private func materialSurface<S: Shape>(in shape: S) -> some View {
        background(.regularMaterial, in: shape)
            .overlay(shape.stroke(.separator, lineWidth: 0.5))
    }
}
