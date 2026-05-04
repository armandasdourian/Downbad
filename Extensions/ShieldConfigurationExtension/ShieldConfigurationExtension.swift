import ManagedSettingsUI
import ManagedSettings
import UIKit

// MARK: - ShieldConfigurationExtension
//
// Customizes the cream-paper shield overlay shown when a blocked app is
// opened from the iOS home screen. Apple's API only exposes
// icon / title / subtitle / two buttons — no custom views — so we map the
// design's cream-paper look as closely as the API allows.
//
// In a real device build, you can also display a custom UIImage as the icon
// (e.g. a rendered judge face). Here we use SF Symbol "lock.fill" so there's
// no asset bundle dependency from this extension target.

class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    private let cream = UIColor(red: 0.961, green: 0.941, blue: 0.910, alpha: 1)
    private let ink   = UIColor(red: 0.102, green: 0.094, blue: 0.078, alpha: 1)
    private let inkMuted = UIColor(red: 0.420, green: 0.392, blue: 0.353, alpha: 1)
    private let clay  = UIColor(red: 0.776, green: 0.502, blue: 0.341, alpha: 1)

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        SharedDefaults.shared.recordShieldConfig()
        let appName = application.localizedDisplayName ?? "this app"

        return ShieldConfiguration(
            backgroundBlurStyle: .systemThickMaterialDark,
            backgroundColor: ink.withAlphaComponent(0.92),
            icon: UIImage(systemName: "lock.fill"),
            title: ShieldConfiguration.Label(
                text: "\(appName) is locked",
                color: cream
            ),
            subtitle: ShieldConfiguration.Label(
                text: "tap unlock to say your phrase to the judge.",
                color: cream.withAlphaComponent(0.7)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "unlock with voice",
                color: ink
            ),
            primaryButtonBackgroundColor: cream,
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: "stay focused",
                color: cream.withAlphaComponent(0.6)
            )
        )
    }

    override func configuration(shielding application: Application,
                                in category: ActivityCategory) -> ShieldConfiguration {
        configuration(shielding: application)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        SharedDefaults.shared.recordShieldConfig()
        return ShieldConfiguration(
            backgroundBlurStyle: .systemThickMaterialDark,
            backgroundColor: ink.withAlphaComponent(0.92),
            icon: UIImage(systemName: "lock.fill"),
            title: ShieldConfiguration.Label(text: "this site is locked", color: cream),
            subtitle: ShieldConfiguration.Label(
                text: "tap unlock to say your phrase to the judge.",
                color: cream.withAlphaComponent(0.7)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(text: "unlock with voice", color: ink),
            primaryButtonBackgroundColor: cream,
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: "stay focused", color: cream.withAlphaComponent(0.6)
            )
        )
    }

    override func configuration(shielding webDomain: WebDomain,
                                in category: ActivityCategory) -> ShieldConfiguration {
        configuration(shielding: webDomain)
    }
}
