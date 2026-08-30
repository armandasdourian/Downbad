import DeviceActivity
import ManagedSettings
import Foundation

/// Monitors device activity schedules and re-applies shields when needed.
/// This extension runs as a separate process and survives app termination.
///
/// Activities it receives:
/// - "Downbad.Daily"           — the repeating daily interval (midnight sweep).
/// - "Downbad.Relock.<uuid>"   — one-shot intervals that START at a timer
///                               unlock's expiry (re-lock while app suspended).
/// - "Downbad.Bank.<uuid>"     — usage-threshold monitoring for time-bank
///                               unlocks; the "cutoff" event fires when the
///                               user has spent the banked minutes inside the
///                               app, and intervalDidEnd is the midnight
///                               backstop for unspent banks.
class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    private let store = ManagedSettingsStore(named: .init("DownbadMain"))

    private static let bankPrefix = "Downbad.Bank."

    /// Called when a monitored activity interval begins.
    override func intervalDidStart(for activity: DeviceActivityName) {
        // Note: a bank activity's interval starts at unlock time — the generic
        // sweep below only re-locks apps whose wall-clock expiry passed, so a
        // freshly opened bank is untouched.
        relockAndApplyShields()
    }

    /// Called when a monitored activity interval ends.
    override func intervalDidEnd(for activity: DeviceActivityName) {
        // Midnight backstop: an unspent time bank expires with its interval.
        forceRelockIfBankActivity(activity)
        relockAndApplyShields()
    }

    /// Called at threshold events during a monitored interval — for bank
    /// activities this means the user has spent their banked minutes.
    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        forceRelockIfBankActivity(activity)
        relockAndApplyShields()
    }

    // MARK: - Bank handling

    private func forceRelockIfBankActivity(_ activity: DeviceActivityName) {
        guard activity.rawValue.hasPrefix(Self.bankPrefix),
              let id = UUID(uuidString: String(activity.rawValue.dropFirst(Self.bankPrefix.count)))
        else { return }
        SharedDefaults.shared.forceRelock(id: id)
    }

    // MARK: - Shield Logic

    private func relockAndApplyShields() {
        // Re-lock any expired timer-mode apps
        _ = SharedDefaults.shared.relockExpiredApps()

        // Rebuild shields from current state
        let apps = SharedDefaults.shared.blockedApps
        let tokens: Set<ApplicationToken> = Set(
            apps
                .filter { !$0.isUnlocked }
                .compactMap { $0.applicationToken }
        )

        if tokens.isEmpty {
            store.shield.applications = nil
        } else {
            store.shield.applications = tokens
        }
    }
}
