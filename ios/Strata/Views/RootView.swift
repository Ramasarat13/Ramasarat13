import SwiftUI

struct RootView: View {
    @Environment(CalendarStore.self) private var store

    var body: some View {
        Group {
            if store.access == .granted {
                MainView()
            } else {
                AccessView()
            }
        }
        .animation(.default, value: store.access)
    }
}

/// Shown until the app may read calendars. Explains why, and offers a way to look
/// around with sample data first.
struct AccessView: View {
    @Environment(CalendarStore.self) private var store
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    private var canAsk: Bool { store.access == .notDetermined }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            Image(systemName: "calendar.day.timeline.left")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .padding(.bottom, 24)
                .accessibilityHidden(true)

            Text("Your calendar, at any depth")
                .font(.largeTitle.bold())
                .padding(.bottom, 12)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
            Spacer()

            VStack(spacing: 12) {
                Button {
                    if canAsk {
                        Task { await store.requestAccess() }
                    } else if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                } label: {
                    Text(canAsk ? "Connect Apple Calendar" : "Open Settings")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 28)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Try with sample events") {
                    store.useSampleData()
                }
                .font(.subheadline.weight(.medium))
                .frame(minHeight: 44)
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 16)
        .onChange(of: scenePhase) { _, phase in
            // Coming back from Settings: pick up a permission the user just granted.
            if phase == .active {
                Task { await store.reload() }
            }
        }
    }

    private var message: String {
        switch store.access {
        case .notDetermined, .granted:
            "Strata draws your events as one continuous timeline. Spread two fingers and every event says more: its time, its place, its notes. Your events stay on this iPhone."
        case .writeOnly:
            "Strata can add events but can't read them yet. To show your timeline, allow full access in Settings, under Privacy & Security, Calendars."
        case .denied, .restricted:
            "Strata doesn't have access to your calendars. To show your timeline, allow full access in Settings, under Privacy & Security, Calendars."
        }
    }
}

#Preview("Access") {
    AccessView()
        .environment(CalendarStore.demo())
}
