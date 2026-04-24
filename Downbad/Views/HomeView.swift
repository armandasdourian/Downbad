import SwiftUI
import FamilyControls

struct HomeView: View {
    @StateObject private var blockManager = AppBlockManager.shared
    @State private var showAddApp = false
    @State private var showSettings = false
    @State private var unlockingApp: BlockedAppConfig?

    var body: some View {
        NavigationStack {
            Group {
                if !blockManager.isAuthorized {
                    authorizationView
                } else if blockManager.blockedApps.isEmpty {
                    emptyStateView
                } else {
                    appListView
                }
            }
            .navigationTitle("Downbad")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
                if blockManager.isAuthorized {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showAddApp = true } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddApp) {
                AddAppView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .fullScreenCover(item: $unlockingApp) { app in
                UnlockView(appConfig: app) {
                    unlockingApp = nil
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                blockManager.relockExpiredApps()
                checkPendingUnlock()
            }
            .onAppear {
                blockManager.relockExpiredApps()
                checkPendingUnlock()
            }
        }
    }

    // MARK: - Sub-views

    private var authorizationView: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.shield")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            Text("Downbad needs Screen Time access to block apps.")
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("Grant Access") {
                Task {
                    try? await blockManager.requestAuthorization()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "app.badge.checkmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No apps blocked yet")
                .font(.title3)
                .foregroundStyle(.secondary)

            Button("Add Your First App") {
                showAddApp = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var appListView: some View {
        List {
            ForEach(blockManager.blockedApps) { app in
                AppRowView(app: app) {
                    unlockingApp = app
                } onRelock: {
                    blockManager.relockApp(id: app.id)
                }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    blockManager.removeBlockedApp(id: blockManager.blockedApps[index].id)
                }
            }
        }
    }

    // MARK: - Pending Unlock

    /// Check if the user arrived here from a shield notification.
    private func checkPendingUnlock() {
        guard let pendingID = SharedDefaults.shared.pendingUnlockAppID,
              let uuid = UUID(uuidString: pendingID),
              let app = blockManager.blockedApps.first(where: { $0.id == uuid }) else { return }

        SharedDefaults.shared.pendingUnlockAppID = nil
        unlockingApp = app
    }
}

// MARK: - App Row

struct AppRowView: View {
    let app: BlockedAppConfig
    let onUnlock: () -> Void
    let onRelock: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(app.displayName)
                    .font(.headline)

                Text(app.unlockPhrase)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if app.isUnlocked, let expires = app.unlockExpiresAt {
                    Text("Unlocked until \(expires.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
            }

            Spacer()

            if app.isUnlocked {
                Button("Re-lock") { onRelock() }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .controlSize(.small)
            } else {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.red)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !app.isUnlocked {
                onUnlock()
            }
        }
    }
}
