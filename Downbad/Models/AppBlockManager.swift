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
    func addBlockedApp(displayName: String, unlockPhrase: String, unlockDuration: UnlockDuration, mode: UnlockMode = .timer, token: ApplicationToken) {
        guard let tokenData = BlockedAppConfig.encodeToken(token) else { return }

        let config = BlockedAppConfig(
            displayName: displayName,
            unlockPhrase: unlockPhrase,
            unlockDuration: unlockDuration,
            mode: mode,
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
        cancelBankActivity(id: id)
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
        let mode = blockedApps[index].unlockMode

        blockedApps[index].isUnlocked = true

        // The judge remembers: record this unlock, keep a rolling 24h window
        // (capped) so the mirror ritual can escalate on repeat visits.
        var history = blockedApps[index].unlockHistory ?? []
        history.append(.now)
        let cutoff = Date().addingTimeInterval(-24 * 3600)
        blockedApps[index].unlockHistory = Array(history.filter { $0 > cutoff }.suffix(20))

        switch mode {
        case .timer:
            let expiresAt = duration.expirationDate()
            blockedApps[index].unlockExpiresAt = expiresAt
            save()
            applyShields()

            // In-process timer: instant re-lock if Downbad happens to be running
            // at expiry. Dies when iOS suspends the app, hence the backstop below.
            scheduleRelock(id: id, at: expiresAt)

            // Out-of-process backstop: a DeviceActivity interval that STARTS at
            // expiry wakes DeviceActivityMonitorExtension (which survives app
            // suspension) so the shield comes back even while the user is inside
            // the unlocked app.
            scheduleRelockActivity(id: id, at: expiresAt)

        case .bank:
            // Time bank: no wall-clock expiry. A DeviceActivity usage-threshold
            // event meters ACTUAL time spent in the app and fires the monitor
            // extension when the bank is spent. The monitoring interval runs to
            // end of day, so an unspent bank naturally expires at midnight.
            blockedApps[index].unlockExpiresAt = nil
            save()
            applyShields()

            if let token = blockedApps[index].applicationToken {
                scheduleBankActivity(id: id, minutes: max(1, duration.rawValue), token: token)
            }
        }
    }

    /// Manually re-lock an app before its timer expires.
    func relockApp(id: UUID) {
        relockTimers[id]?.cancel()
        relockTimers.removeValue(forKey: id)
        cancelRelockActivity(id: id)
        cancelBankActivity(id: id)

        guard let index = blockedApps.firstIndex(where: { $0.id == id }) else { return }
        blockedApps[index].isUnlocked = false
        blockedApps[index].unlockExpiresAt = nil
        save()
        applyShields()
    }

    /// Check for and re-lock any apps whose unlock has expired, and re-sync
    /// state written by the monitor extension (e.g. spent time banks).
    /// Call this on app launch and when returning to foreground.
    func relockExpiredApps() {
        let relocked = SharedDefaults.shared.relockExpiredApps()
        // Always re-read: the extension force-relocks bank apps out-of-process,
        // and our in-memory copy has no other way to learn about it.
        blockedApps = SharedDefaults.shared.blockedApps
        applyShields()
        for id in relocked {
            cancelRelockActivity(id: id)
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

    // MARK: - Time-bank activities

    private func bankActivityName(for id: UUID) -> DeviceActivityName {
        DeviceActivityName("Downbad.Bank.\(id.uuidString)")
    }

    /// Meter actual usage of the app: an event with a usage threshold fires
    /// the monitor extension once the user has ACCUMULATED `minutes` of real
    /// time inside the app (across any number of visits). Interval runs to end
    /// of day so an unspent bank expires at midnight.
    private func scheduleBankActivity(id: UUID, minutes: Int, token: ApplicationToken) {
        let name = bankActivityName(for: id)
        activityCenter.stopMonitoring([name])

        let now = Date()
        let cal = Calendar.current
        let endOfDay = cal.startOfDay(for: now).addingTimeInterval(24 * 3600 - 60)
        // DeviceActivity requires intervals ≥ 15 minutes — pad past midnight
        // if the bank was opened in the day's final minutes.
        let end = max(endOfDay, now.addingTimeInterval(16 * 60))

        let comps: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(
            intervalStart: cal.dateComponents(comps, from: now),
            intervalEnd: cal.dateComponents(comps, from: end),
            repeats: false
        )
        let event = DeviceActivityEvent(
            applications: [token],
            threshold: DateComponents(minute: minutes)
        )

        do {
            try activityCenter.startMonitoring(
                name,
                during: schedule,
                events: [DeviceActivityEvent.Name("cutoff"): event]
            )
        } catch {
            print("Downbad: failed to schedule bank activity: \(error)")
        }
    }

    private func cancelBankActivity(id: UUID) {
        activityCenter.stopMonitoring([bankActivityName(for: id)])
    }
}
