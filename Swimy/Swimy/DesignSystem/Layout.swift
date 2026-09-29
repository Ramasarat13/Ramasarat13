import SwiftUI

/// Spacing scale, in points.
enum Spacing {
    static let xxSmall: CGFloat = 4
    static let xSmall: CGFloat = 8
    static let small: CGFloat = 12
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
    static let xLarge: CGFloat = 32
}

/// Corner radii, in points. Always drawn with continuous (squircle) corners.
enum Radius {
    static let card: CGFloat = 24
    static let icon: CGFloat = 12
    static let tile: CGFloat = 4
}

/// Minimum tap target from Apple's Human Interface Guidelines.
let minimumTapTarget: CGFloat = 44

extension View {
    /// The standard card: padding plus a rounded, grouped background.
    func cardStyle(padding: CGFloat = Spacing.medium) -> some View {
        self
            .padding(padding)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }
}
