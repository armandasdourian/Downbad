import ManagedSettingsUI
import ManagedSettings
import UIKit

/// Customizes the shield overlay that appears when a blocked app is opened.
class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        let appName = application.localizedDisplayName ?? "This app"

        return ShieldConfiguration(
            backgroundBlurStyle: .systemThickMaterialDark,
            backgroundColor: UIColor.black.withAlphaComponent(0.85),
            icon: UIImage(systemName: "lock.fill"),
            title: ShieldConfiguration.Label(
                text: "\(appName) is locked",
                color: .white
            ),
            subtitle: ShieldConfiguration.Label(
                text: "Open VoiceGate to say your unlock phrase",
                color: .lightGray
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Unlock with Voice",
                color: .white
            ),
            primaryButtonBackgroundColor: UIColor.systemBlue,
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: "Stay Focused",
                color: .lightGray
            )
        )
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        configuration(shielding: application)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemThickMaterialDark,
            backgroundColor: UIColor.black.withAlphaComponent(0.85),
            icon: UIImage(systemName: "lock.fill"),
            title: ShieldConfiguration.Label(
                text: "This site is locked",
                color: .white
            ),
            subtitle: ShieldConfiguration.Label(
                text: "Open VoiceGate to say your unlock phrase",
                color: .lightGray
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Unlock with Voice",
                color: .white
            ),
            primaryButtonBackgroundColor: UIColor.systemBlue,
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: "Stay Focused",
                color: .lightGray
            )
        )
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        configuration(shielding: webDomain)
    }
}
