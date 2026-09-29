import SwiftUI

/// Profile sheet: the Lifetime pool tile, settings and privacy.
///
/// Phase 4 adds the Journey milestone, lifetime stats, weekly goal, Health access
/// help, About (with onboarding replay) and Reset app data.
struct ProfileView: View {
    @Environment(SwimStore.self) private var store
    @Environment(SettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            List {
                Section {
                    LifetimeTile(
                        distance: SwimFormatter.totalDistance(
                            meters: store.lifetimeDistanceMeters,
                            unit: settings.distanceUnit
                        ),
                        swimCount: store.swims.count
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section("Settings") {
                    Picker(selection: $settings.distanceUnit) {
                        ForEach(DistanceUnit.allCases) { unit in
                            Text(unit.title).tag(unit)
                        }
                    } label: {
                        Label("Distance unit", systemImage: "ruler")
                    }

                    Toggle(isOn: $settings.hapticsEnabled) {
                        Label("Haptics", systemImage: "iphone.radiowaves.left.and.right")
                    }

                    Picker(selection: $settings.appearance) {
                        ForEach(Appearance.allCases) { appearance in
                            Text(appearance.title).tag(appearance)
                        }
                    } label: {
                        Label("Appearance", systemImage: "circle.lefthalf.filled")
                    }
                }

                Section {
                    Label {
                        Text("Your swims never leave this iPhone. No account, no servers, no ads and no tracking.")
                    } icon: {
                        Image(systemName: "lock.shield")
                    }
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("Pool pace, SWOLF and lengths always follow your pool: metres or yards.")
                }

                #if DEBUG
                Section {
                    Picker(selection: $settings.mockScenario) {
                        ForEach(MockSwimProvider.Scenario.allCases) { scenario in
                            Text(scenario.title).tag(scenario)
                        }
                    } label: {
                        Label("Mock data", systemImage: "hammer")
                    }
                } header: {
                    Text("Developer")
                } footer: {
                    Text("Debug builds only. Phase 2 adds real swims from Apple Health.")
                }
                #endif

                Section {
                    LabeledContent("Version", value: appVersion)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Close", systemImage: "xmark")
                    }
                }
            }
            .swimyHaptic(.selection, trigger: settings.distanceUnit)
            .onChange(of: settings.mockScenario) { _, scenario in
                Task {
                    await store.use(MockSwimProvider(scenario: scenario))
                }
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–"
        return "\(version) (\(build))"
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            ProfileView()
        }
        .previewEnvironment()
}
