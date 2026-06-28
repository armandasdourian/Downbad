import SwiftUI
import UserNotifications
import DeviceActivity

@main
struct DownbadApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var hasOnboarded: Bool

    init() {
        var onboarded = SharedDefaults.shared.hasOnboarded
        #if DEBUG
        // CI / preview launch arguments — let the screenshot workflow force a state.
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-previewSkipOnboarding")  { onboarded = true }
        if args.contains("-previewForceOnboarding") { onboarded = false }
        #endif
        _hasOnboarded = State(initialValue: onboarded)
    }

    var body: some Scene {
        WindowGroup {
            rootView
                .preferredColorScheme(.light) // cream paper aesthetic — keep light
        }
    }

    // MARK: - Root routing

    @ViewBuilder
    private var rootView: some View {
        #if DEBUG
        if let screen = ProcessInfo.processInfo.environment["DOWNBAD_PREVIEW_SCREEN"] {
            previewScreen(screen)
        } else {
            normalRoot
        }
        #else
        normalRoot
        #endif
    }

    @ViewBuilder
    private var normalRoot: some View {
        if hasOnboarded {
            HomeView()
        } else {
            OnboardingView {
                // SharedDefaults.shared.hasOnboarded is set by onboarding itself.
                withAnimation(.easeInOut(duration: 0.4)) {
                    hasOnboarded = true
                }
            }
        }
    }

    #if DEBUG
    /// Deterministic screen routing for the CI screenshot workflow.
    /// Triggered via env var DOWNBAD_PREVIEW_SCREEN (set by `SIMCTL_CHILD_...`).
    /// Only compiled into DEBUG builds; never reachable in a Release/App Store build.
    @ViewBuilder
    private func previewScreen(_ name: String) -> some View {
        switch name {
        case "onboarding": OnboardingView(onComplete: {})
        case "settings":   SettingsView()
        case "addapp":     AddAppView()
        case "permission": PermissionDeniedView(kind: .screentime, onOpenSettings: {}, onSkip: {})
        default:           normalRoot
        }
    }
    #endif
}

// MARK: - App Delegate

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self

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
