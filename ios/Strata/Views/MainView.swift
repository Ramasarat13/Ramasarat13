import SwiftUI

enum AppTab: Hashable {
    case home, calendars
}

/// The app once it can read calendars: two tabs under a floating bar, and the
/// sheets for viewing and editing events.
struct MainView: View {
    @Environment(CalendarStore.self) private var store

    @State private var tab: AppTab = .home
    @State private var homeTaps = 0
    @State private var sheet: SheetRoute?
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            // The timeline stays alive behind the calendars tab so it keeps its place.
            TimelineScreen(sheet: $sheet, homeTaps: homeTaps)
                .opacity(tab == .home ? 1 : 0)
                .allowsHitTesting(tab == .home)
                .accessibilityHidden(tab != .home)

            if tab == .calendars {
                CalendarsScreen()
                    .transition(.opacity)
            }
        }
        .animation(.snappy(duration: 0.2), value: tab)
        .safeAreaInset(edge: .top, spacing: 0) {
            // Nothing to show here; it only gives the status bar a backing as content scrolls under it.
            Color.clear
                .frame(height: 0)
                .background(Color(.systemBackground))
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomBar(
                tab: tab,
                onSelect: { selected in
                    if selected == tab, selected == .home {
                        homeTaps += 1
                    }
                    tab = selected
                },
                onAdd: {
                    do {
                        sheet = .editor(try store.newDraft())
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            )
        }
        .sheet(item: $sheet) { route in
            switch route {
            case .detail(let event): EventDetailView(event: event)
            case .editor(let draft): EventEditorView(draft: draft)
            }
        }
        .errorAlert($errorMessage)
    }
}

/// The floating controls: a glass pill holding the two tabs, and a round add button.
struct BottomBar: View {
    let tab: AppTab
    var onSelect: (AppTab) -> Void
    var onAdd: () -> Void

    var body: some View {
        HStack {
            HStack(spacing: 2) {
                tabButton(.home, icon: "house", label: "Timeline")
                tabButton(.calendars, icon: "square.3.layers.3d", label: "Calendars")
            }
            .padding(5)
            .glassSurface(in: Capsule())

            Spacer()

            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.title3.weight(.regular))
                    .foregroundStyle(Color.ink)
                    .frame(width: 58, height: 58)
                    .contentShape(Circle())
                    .glassSurface(in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("New Event")
        }
        .padding(.horizontal, 22)
        .padding(.top, 28)
        .padding(.bottom, 6)
        .background {
            // Fades the page out before it reaches the controls, so nothing shows through them.
            LinearGradient(
                stops: [
                    .init(color: Color(.systemBackground).opacity(0), location: 0),
                    .init(color: Color(.systemBackground).opacity(0.97), location: 0.5),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }

    private func tabButton(_ target: AppTab, icon: String, label: String) -> some View {
        let selected = tab == target
        return Button {
            onSelect(target)
        } label: {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .regular))
                .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                .frame(width: 70, height: 48)
                .background(selected ? Color.accentColor.opacity(0.12) : Color.clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? AccessibilityTraits.isSelected : AccessibilityTraits())
    }
}

// MARK: Shared dialogs

extension View {
    /// Asks before deleting, offering "this one" or "all future" for repeating events.
    func deleteEventDialog(
        _ event: Binding<CalendarEvent?>,
        onDelete: @escaping (CalendarEvent, EditSpan) -> Void
    ) -> some View {
        confirmationDialog(
            event.wrappedValue.map { "Delete “\($0.displayTitle)”?" } ?? "Delete event?",
            isPresented: Binding(
                get: { event.wrappedValue != nil },
                set: { if !$0 { event.wrappedValue = nil } }
            ),
            titleVisibility: .visible,
            presenting: event.wrappedValue
        ) { target in
            if target.isRecurring {
                Button("Delete This Event Only", role: .destructive) { onDelete(target, .thisEvent) }
                Button("Delete All Future Events", role: .destructive) { onDelete(target, .futureEvents) }
            } else {
                Button("Delete Event", role: .destructive) { onDelete(target, .thisEvent) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { target in
            Text(target.isRecurring ? "This is a repeating event." : "This can't be undone.")
        }
    }

    func errorAlert(_ message: Binding<String?>) -> some View {
        alert(
            "Something went wrong",
            isPresented: Binding(
                get: { message.wrappedValue != nil },
                set: { if !$0 { message.wrappedValue = nil } }
            ),
            presenting: message.wrappedValue
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { text in
            Text(text)
        }
    }
}
