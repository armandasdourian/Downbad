import SwiftUI
import FamilyControls

// MARK: - HomeView
//
// The dashboard. Lists every blocked app with its lock state + countdown.
// Empty state shows the judge napping in a letterhead document.
//
// Translation of design_handoff_downbad/app/Home.jsx.

struct HomeView: View {
    @StateObject private var blockManager = AppBlockManager.shared
    @State private var showAddApp = false
    @State private var showSettings = false
    @State private var unlockingApp: BlockedAppConfig?
    @State private var emptyMoodPhase = 0

    /// Drives the live countdown — re-renders the `unlocks for {time}` strings.
    @State private var now = Date()
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.cream.ignoresSafeArea()

                Group {
                    if !blockManager.isAuthorized {
                        // Edge case: user revoked Screen Time post-onboarding. Show a recovery screen.
                        recoveryView
                    } else if blockManager.blockedApps.isEmpty {
                        emptyView
                    } else {
                        listView
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("downbad")
                        .font(.serifItalic(28))
                        .tracking(-0.56)
                        .foregroundStyle(Theme.ink)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 18))
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
            }
            .toolbarBackground(Theme.cream, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(isPresented: $showAddApp) {
                AddAppView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .fullScreenCover(item: $unlockingApp) { app in
                UnlockView(appConfig: app) { unlockingApp = nil }
            }
            .onReceive(tick) { now = $0 }
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

    // MARK: - Empty state

    private var emptyView: some View {
        VStack(spacing: 24) {
            Spacer()

            Mascot(mood: emptyMood,
                   size: 150,
                   variant: .letterhead,
                   caption: "docket empty")
                .onReceive(Timer.publish(every: 2.2, on: .main, in: .common).autoconnect()) { _ in
                    withAnimation(.easeInOut(duration: 0.4)) {
                        emptyMoodPhase = (emptyMoodPhase + 1) % 4
                    }
                }

            VStack(spacing: 12) {
                Text("nothing to judge.")
                    .font(.serifItalic(36))
                    .tracking(-0.72)
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(0)

                Text("the judge is napping.\ngive them something to do.")
                    .font(.sans(15))
                    .foregroundStyle(Theme.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            Spacer()

            PrimaryButton(title: "+ block an app") { showAddApp = true }
                .frame(maxWidth: 280)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 24)
    }

    private var emptyMood: MascotMood {
        [.sleepy, .idle, .sleepy, .idle][emptyMoodPhase]
    }

    // MARK: - Populated list

    private var listView: some View {
        VStack(spacing: 0) {
            // Subhead
            HStack {
                Text(subheadText)
                    .captionMono()
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 4)
            .padding(.bottom, 16)

            ScrollView {
                LazyVStack(spacing: Theme.cardGap) {
                    ForEach(blockManager.blockedApps) { app in
                        AppRow(app: app, now: now,
                               onUnlock: { unlockingApp = app },
                               onRelock: { blockManager.relockApp(id: app.id) })
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }

            PrimaryButton(title: "+ block another") { showAddApp = true }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
        }
    }

    private var subheadText: String {
        let n = blockManager.blockedApps.count
        let unlockedCount = blockManager.blockedApps.filter { $0.isUnlocked }.count
        let status: String
        if unlockedCount == 0 {
            status = "the judge is watching"
        } else if unlockedCount == n {
            status = "all unlocked. enjoy."
        } else {
            status = "\(unlockedCount) unlocked"
        }
        return "\(n) blocked · \(status)"
    }

    // MARK: - Recovery (Screen Time access revoked)

    private var recoveryView: some View {
        VStack(spacing: 24) {
            Spacer()
            Mascot(mood: .disappointed, size: 150, variant: .letterhead,
                   caption: "access revoked")
            VStack(spacing: 12) {
                Text("we lost screen time access.")
                    .font(.serifItalic(32))
                    .tracking(-0.64)
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                Text("turn it back on so we can keep blocking apps.")
                    .font(.sans(15))
                    .foregroundStyle(Theme.inkMuted)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            PrimaryButton(title: "grant access") {
                Task { try? await blockManager.requestAuthorization() }
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 32)
    }

    // MARK: - Pending unlock from shield notification

    private func checkPendingUnlock() {
        guard let pendingID = SharedDefaults.shared.pendingUnlockAppID,
              let uuid = UUID(uuidString: pendingID),
              let app = blockManager.blockedApps.first(where: { $0.id == uuid }) else { return }
        SharedDefaults.shared.pendingUnlockAppID = nil
        unlockingApp = app
    }
}

// MARK: - AppRow

struct AppRow: View {
    let app: BlockedAppConfig
    let now: Date
    let onUnlock: () -> Void
    let onRelock: () -> Void

    var body: some View {
        Button(action: { if !app.isUnlocked { onUnlock() } }) {
            HStack(spacing: 14) {
                AppIconView(name: app.displayName, size: 48, radius: 13)

                VStack(alignment: .leading, spacing: 2) {
                    Text(app.displayName)
                        .font(.sans(16, weight: .semibold))
                        .tracking(-0.16)
                        .foregroundStyle(Theme.ink)

                    Text(subtitle)
                        .font(app.isUnlocked ? .sans(12) : .serifItalic(13))
                        .foregroundStyle(Theme.inkMuted)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if app.isUnlocked {
                    Button(action: onRelock) {
                        Text("re-lock")
                            .font(.sans(12, weight: .semibold))
                            .foregroundStyle(Theme.cream)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Theme.ink)
                            .clipShape(Capsule(style: .continuous))
                    }
                    .buttonStyle(PressScale())
                } else {
                    Pill(text: "locked", tone: .locked, systemImage: "lock.fill")
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(app.isUnlocked ? Theme.sage.opacity(0.45) : Theme.creamSoft)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(app.isUnlocked ? Theme.sageDeep.opacity(0.4) : Theme.creamDeep, lineWidth: 1)
            )
        }
        .buttonStyle(PressScale())
        .disabled(app.isUnlocked)
    }

    private var subtitle: String {
        if app.isUnlocked, let expiry = app.unlockExpiresAt {
            return "unlocks for \(Self.formatRemaining(expiry.timeIntervalSince(now)))"
        }
        // Quote preview, truncated to ~40 chars to match design.
        let phrase = app.unlockPhrase
        let trimmed = phrase.count > 40 ? "\(phrase.prefix(40))…" : phrase
        return "\u{201C}\(trimmed)\u{201D}"
    }

    private static func formatRemaining(_ seconds: TimeInterval) -> String {
        let secs = max(0, Int(seconds))
        let m = secs / 60
        let s = secs % 60
        return m > 0 ? "\(m)m \(s)s" : "\(s)s"
    }
}

#if DEBUG
#Preview("Home — populated") { HomeView() }
#endif
