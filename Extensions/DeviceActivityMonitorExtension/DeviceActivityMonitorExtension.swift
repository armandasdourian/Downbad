import DeviceActivity
import ManagedSettings
import Foundation

/// Monitors device activity schedules and re-applies shields when needed.
/// This extension runs as a separate process and survives app termination.
class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    private let store = ManagedSettingsStore(named: .init("DownbadMain"))

    /// Called when a monitored activity interval begins.
    /// We use this to re-apply shields (e.g., at the start of each day).
    override func intervalDidStart(for activity: DeviceActivityName) {
        relockAndApplyShields()
    }

    /// Called when a monitored activity interval ends.
    override func intervalDidEnd(for activity: DeviceActivityName) {
        relockAndApplyShields()
    }

    /// Called at threshold events during a monitored interval.
    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        relockAndApplyShields()
    }

    // MARK: - Shield Logic

    private func relockAndApplyShields() {
        // Re-lock any expired apps
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
