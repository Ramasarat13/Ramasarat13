import SwiftUI

extension View {
    /// Plays `feedback` when `trigger` changes, unless Haptics is off in Profile.
    ///
    /// Spec haptics table: `.selection` for tab and segment changes, `.success` when
    /// an import finishes or a card is saved, `.error` when a sync fails.
    func swimyHaptic<Trigger: Equatable>(_ feedback: SensoryFeedback, trigger: Trigger) -> some View {
        modifier(SwimyHapticModifier(feedback: feedback, trigger: trigger))
    }
}

private struct SwimyHapticModifier<Trigger: Equatable>: ViewModifier {
    @Environment(SettingsStore.self) private var settings
    let feedback: SensoryFeedback
    let trigger: Trigger

    func body(content: Content) -> some View {
        let isEnabled = settings.hapticsEnabled
        content.sensoryFeedback(feedback, trigger: trigger) { _, _ in isEnabled }
    }
}
