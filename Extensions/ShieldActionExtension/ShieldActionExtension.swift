import ManagedSettings
import UserNotifications

/// Handles button taps on the shield overlay.
/// When the user taps "Unlock with Voice", we schedule a notification
/// that opens the main app to the unlock flow.
class ShieldActionExtension: ShieldActionDelegate {

    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        switch action {
        case .primaryButtonPressed:
            // Find the matching app config and store its ID for the main app to read
            if let tokenData = try? JSONEncoder().encode(application),
               let appConfig = SharedDefaults.shared.findApp(byTokenData: tokenData) {
                SharedDefaults.shared.pendingUnlockAppID = appConfig.id.uuidString
            }

            // Schedule an immediate notification to open the main app
            scheduleUnlockNotification()

            // Close the shielded app so the notification is visible
            completionHandler(.close)

        case .secondaryButtonPressed:
            completionHandler(.close)

        @unknown default:
            completionHandler(.close)
        }
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        switch action {
        case .primaryButtonPressed:
            scheduleUnlockNotification()
            completionHandler(.close)
        case .secondaryButtonPressed:
            completionHandler(.close)
        @unknown default:
            completionHandler(.close)
        }
    }

    // MARK: - Notification

    private func scheduleUnlockNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Downbad"
        content.body = "Tap here to unlock with your voice"
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "downbad-unlock-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }
}
