import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var defaultDuration: UnlockDuration

    init() {
        _defaultDuration = State(initialValue: SharedDefaults.shared.defaultUnlockDuration)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Default Unlock Duration", selection: $defaultDuration) {
                        ForEach(UnlockDuration.allCases) { duration in
                            Text(duration.displayName).tag(duration)
                        }
                    }
                    .onChange(of: defaultDuration) { newValue in
                        SharedDefaults.shared.defaultUnlockDuration = newValue
                    }
                } header: {
                    Text("Defaults")
                } footer: {
                    Text("New apps will use this duration unless you override it per-app.")
                }

                Section {
                    Button("Re-lock All Apps Now", role: .destructive) {
                        let manager = AppBlockManager.shared
                        for app in manager.blockedApps where app.isUnlocked {
                            manager.relockApp(id: app.id)
                        }
                    }
                } footer: {
                    Text("Immediately re-locks all currently unlocked apps.")
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("How it works") {
                        Text("VoiceGate uses Screen Time to block apps. To unlock, say the phrase you set to your camera.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
