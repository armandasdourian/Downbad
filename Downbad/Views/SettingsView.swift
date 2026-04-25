import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var defaultDuration: UnlockDuration
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var diagRefreshTick = 0

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

                Section {
                    HStack {
                        Image(systemName: notificationStatus == .authorized ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(notificationStatus == .authorized ? .green : .orange)
                        Text(notificationStatusText)
                    }
                    if notificationStatus != .authorized {
                        Button("Open iOS Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Required so the shield's “Unlock with Voice” button can open Downbad. Without this, tapping the button does nothing visible.")
                }

                Section {
                    let _ = diagRefreshTick // re-evaluates body when refreshed
                    LabeledContent("Shield UI shown") {
                        Text("\(SharedDefaults.shared.shieldConfigInvocations)x")
                            .monospacedDigit()
                    }
                    if let last = SharedDefaults.shared.shieldConfigLastAt {
                        LabeledContent("Last shown") {
                            Text(last, style: .relative)
                        }
                    }
                    LabeledContent("Unlock button tapped") {
                        Text("\(SharedDefaults.shared.shieldButtonTaps)x")
                            .monospacedDigit()
                    }
                    if let last = SharedDefaults.shared.shieldButtonLastAt {
                        LabeledContent("Last tap") {
                            Text(last, style: .relative)
                        }
                    }
                    Button("Refresh") {
                        diagRefreshTick += 1
                    }
                } header: {
                    Text("Diagnostics")
                } footer: {
                    Text("If 'Shield UI shown' stays 0 after opening a blocked app, iOS isn't loading the custom shield — try fully deleting Downbad, rebooting the iPhone, and reinstalling.")
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("How it works") {
                        Text("Downbad uses Screen Time to block apps. To unlock, say the phrase you set to your camera.")
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
            .task { await refreshNotificationStatus() }
        }
    }

    private var notificationStatusText: String {
        switch notificationStatus {
        case .authorized: return "Notifications allowed"
        case .denied: return "Notifications denied — fix in iOS Settings"
        case .notDetermined: return "Permission not yet requested"
        case .provisional: return "Provisional notifications only"
        case .ephemeral: return "Ephemeral notifications only"
        @unknown default: return "Unknown notification state"
        }
    }

    private func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run { notificationStatus = settings.authorizationStatus }
    }
}
