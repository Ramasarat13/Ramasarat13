import SwiftUI

extension View {
    /// Adds the Profile button (top right) that every tab shares.
    func profileToolbar() -> some View {
        modifier(ProfileToolbarModifier())
    }
}

private struct ProfileToolbarModifier: ViewModifier {
    @Environment(AppRouter.self) private var router

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.isProfilePresented = true
                } label: {
                    Label("Profile", systemImage: "person.crop.circle")
                }
            }
        }
    }
}
