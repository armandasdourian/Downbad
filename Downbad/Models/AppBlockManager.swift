import Foundation
import ManagedSettings
import FamilyControls
import DeviceActivity
import Combine

/// Manages shielding and unshielding apps via the Screen Time API.
@MainActor
final class AppBlockManager: ObservableObject {
    static let shared = AppBlockManager()

    private let store = ManagedSettingsStore(named: .init("DownbadMain"))
    private let center = AuthorizationCenter.shared
    private let activityCenter = DeviceActivityCenter()

    @Published var isAuthorized: Bool
    @Published var blockedApps: [BlockedAppConfig] = []

    private var relockTimers: [UUID: Task<Void, Never>] = [:]
    private var cancellables = Set<AnyCancellable>()

    private init() {
        blockedApps = SharedDefaults.shared.blockedApps

        // FamilyControls' authorizationStatus loads asynchronously after a cold
        // launch and reads .notDetermined for a beat even when access is granted.
        // Trust the last observed state until the daemon settles so we don't
        // flash the "we lost screen time access" recovery screen on every launch.
        isAuthorized = SharedDefaults.shared.lastKnownAuthorized
            || center.authorizationStatus == .approved

        // Track the real status as it settles / changes (including genuine
        // revocation in Settings → Screen Time).
        center.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self else { return }
                let approved = status == .approved
                if approved != self.isAuthorized {
                    self.isAuthorized = approved
                }
                SharedDefaults.shared.lastKnownAuthorized = approved
            }
            .store(in: &cancellables)

        // Known FamilyControls quirk: after relaunch, authorizationStatus can
        // stay .notDetermined until requestAuthorization is called. When we
        // KNOW the user previously granted access, a silent re-request settles
        // it without showing any UI (the system only prompts when access was
        // genuinely never granted or was revoked).
        if SharedDefaults.shared.lastKnownAuthorized {
            Task { [weak self] in
                try? await self?.center.requestAuthorization(for: .individual)
            }
        }
    }

    // MARK: - Authorization

    func requestAuthorization() async throws {
        try await center.requestAuthorization(for: .individual)
        isAuthorized = center.authorizationStatus == .approved
        SharedDefaults.shared.lastKnownAuthorized = isAuthorized
    }

    // MARK: - Shielding

    /// Rebuild the shield from the current blocked apps list.
    /// Only shields apps that are NOT currently unlocked.
    func applyShields() {
        let tokens: Set<ApplicationToken> = Set(
            blockedApps
                .filter { !$0.isUnlocked }
                .compactMap { $0.applicationToken }
        )

        if tokens.isEmpty {
            store.shield.applications = nil
        } else {
            store.shield.applications = tokens
        }
    }

    /// Add a new app to the block list and shield it immediately.
    func addBlockedApp(displayName: String, unlockPhrase: String, unlockDuration: UnlockDuration, token: ApplicationToken) {
        guard let tokenData = BlockedAppConfig.encodeToken(token) else { return }

        let config = BlockedAppConfig(
            displayName: displayName,
            unlockPhrase: unlockPhrase,
            unlockDuration: unlockDuration,
            tokenData: tokenData
        )

        blockedApps.append(config)
        save()
        applyShields()
    }

    /// Remove an app from the block list entirely.
    func removeBlockedApp(id: UUID) {
        relockTimers[id]?.cancel()
        relockTimers.removeValue(forKey: id)
        cancelRelockActivity(id: id)
        blockedApps.removeAll { $0.id == id }
        save()
        applyShields()
    }

    /// Update the phrase for a blocked app.
    func updatePhrase(id: UUID, newPhrase: String) {
        guard let index = blockedApps.firstIndex(where: { $0.id == id }) else { return }
        blockedApps[index].unlockPhrase = newPhrase
        save()
    }

    /// Update the unlock duration for a blocked app.
    func updateDuration(id: UUID, newDuration: UnlockDuration) {
        guard let index = blockedApps.firstIndex(where: { $0.id == id }) else { return }
        blockedApps[index].unlockDurationMinutes = newDuration.rawValue
        save()
    }

    // MARK: - Unlock / Relock

    /// Temporarily unshield an app after successful phrase verification.
    func unlockApp(id: UUID) {
        guard let index = blockedApps.firstIndex(where: { $0.id == id }) else { return }

        let duration = blockedApps[index].unlockDuration
        let expiresAt = duration.expirationDate()

        blockedApps[index].isUnlocked = true
        blockedApps[index].unlockExpiresAt = expiresAt

        // The judge remembers: record this unlock, keep a rolling 24h window
        // (capped) so the mirror ritual can escalate on repeat visits.
        var history = blockedApps[index].unlockHistory ?? []
        history.append(.now)
        let cutoff = Date().addingTimeInterval(-24 * 3600)
        blockedApps[index].unlockHistory = Array(history.filter { $0 > cutoff }.suffix(20))

        save()
        applyShields()

        // In-process timer: instant re-lock if Downbad happens to be running
        // at expiry. Dies when iOS suspends the app, hence the backstop below.
        scheduleRelock(id: id, at: expiresAt)

        // Out-of-process backstop: a DeviceActivity interval that STARTS at
        // expiry wakes DeviceActivityMonitorExtension (which survives app
        // suspension) so the shield comes back even while the user is inside
        // the unlocked app. This is the fix for inconsistent re-locking.
        scheduleRelockActivity(id: id, at: expiresAt)
    }

    /// Manually re-lock an app before its timer expires.
    func relockApp(id: UUID) {
        relockTimers[id]?.cancel()
        relockTimers.removeValue(forKey: id)
        cancelRelockActivity(id: id)

        guard let index = blockedApps.firstIndex(where: { $0.id == id }) else { return }
        blockedApps[index].isUnlocked = false
        blockedApps[index].unlockExpiresAt = nil
        save()
        applyShields()
    }

    /// Check for and re-lock any apps whose unlock has expired.
    /// Call this on app launch and when returning to foreground.
    func relockExpiredApps() {
        let relocked = SharedDefaults.shared.relockExpiredApps()
        if !relocked.isEmpty {
            blockedApps = SharedDefaults.shared.blockedApps
            applyShields()
            for id in relocked {
                cancelRelockActivity(id: id)
            }
        }
    }

    // MARK: - Private

    private func save() {
        SharedDefaults.shared.blockedApps = blockedApps
    }

    private func scheduleRelock(id: UUID, at date: Date) {
        relockTimers[id]?.cancel()

        let delay = max(date.timeIntervalSinceNow, 0)
        relockTimers[id] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            await self?.relockApp(id: id)
        }
    }

    // MARK: - DeviceActivity relock backstop

    private func relockActivityName(for id: UUID) -> DeviceActivityName {
        DeviceActivityName("Downbad.Relock.\(id.uuidString)")
    }

    /// Schedule a one-shot DeviceActivity interval beginning exactly at
    /// `expiry`. DeviceActivity requires intervals to be at least 15 minutes
    /// LONG, but we only care about the interval's START — the extension's
    /// intervalDidStart fires at expiry and re-applies shields.
    private func scheduleRelockActivity(id: UUID, at expiry: Date) {
        // intervalStart must be in the future; give sub-minute expiries a beat.
        let start = max(expiry, Date().addingTimeInterval(60))
        let end = start.addingTimeInterval(16 * 60)

        let components: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(
            intervalStart: Calendar.current.dateComponents(components, from: start),
            intervalEnd: Calendar.current.dateComponents(components, from: end),
            repeats: false
        )

        do {
            try activityCenter.startMonitoring(relockActivityName(for: id), during: schedule)
        } catch {
            // Backstop failed to schedule — the foreground paths still work.
            print("Downbad: failed to schedule relock activity: \(error)")
        }
    }

    private func cancelRelockActivity(id: UUID) {
        activityCenter.stopMonitoring([relockActivityName(for: id)])
    }
}
