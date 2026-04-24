import SwiftUI
import UserNotifications
import DeviceActivity

@main
struct DownbadApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Request notification permissions
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }

        // Start daily device activity monitoring so the extension can re-shield
        // apps even if the main app is killed.
        startDailyMonitoring()

        // Re-lock any expired apps on launch
        AppBlockManager.shared.relockExpiredApps()

        return true
    }

    // MARK: - Notification Handling

    /// Show notifications even when the app is in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    /// Handle notification taps — the app is already open, HomeView will check pendingUnlockAppID.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // HomeView checks pendingUnlockAppID on foreground entry, so we just need
        // to post a notification to trigger the check immediately.
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        completionHandler()
    }

    // MARK: - Device Activity Monitoring

    /// Schedule a daily repeating activity so the DeviceActivityMonitorExtension
    /// runs and can re-apply shields after reboots, app kills, etc.
    private func startDailyMonitoring() {
        let center = DeviceActivityCenter()

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )

        do {
            try center.startMonitoring(
                DeviceActivityName("Downbad.Daily"),
                during: schedule
            )
        } catch {
            print("Downbad: Failed to start device activity monitoring: \(error)")
        }
    }
}
