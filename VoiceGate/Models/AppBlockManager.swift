import Foundation
import ManagedSettings
import FamilyControls
import Combine

/// Manages shielding and unshielding apps via the Screen Time API.
@MainActor
final class AppBlockManager: ObservableObject {
    static let shared = AppBlockManager()

    private let store = ManagedSettingsStore(named: .init("VoiceGateMain"))
    private let center = AuthorizationCenter.shared

    @Published var isAuthorized = false
    @Published var blockedApps: [BlockedAppConfig] = []

    private var relockTimers: [UUID: Task<Void, Never>] = [:]

    private init() {
        blockedApps = SharedDefaults.shared.blockedApps
        isAuthorized = center.authorizationStatus == .approved
    }

    // MARK: - Authorization

    func requestAuthorization() async throws {
        try await center.requestAuthorization(for: .individual)
        isAuthorized = center.authorizationStatus == .approved
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
        save()
        applyShields()

        // Schedule automatic re-lock
        scheduleRelock(id: id, at: expiresAt)
    }

    /// Manually re-lock an app before its timer expires.
    func relockApp(id: UUID) {
        relockTimers[id]?.cancel()
        relockTimers.removeValue(forKey: id)

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
}
