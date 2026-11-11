import SwiftUI

@main
struct StrataApp: App {
    @State private var store: CalendarStore

    init() {
        // `-demoData` runs the app on sample events, for previews, screenshots and UI tests.
        let useDemo = ProcessInfo.processInfo.arguments.contains("-demoData")
        _store = State(initialValue: useDemo ? CalendarStore.demo() : CalendarStore.live())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
        }
    }
}
