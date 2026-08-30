import ManagedSettingsUI
import ManagedSettings
import UIKit

// MARK: - ShieldConfigurationExtension
//
// Customizes the cream-paper shield overlay shown when a blocked app is
// opened from the iOS home screen. Apple's API only exposes
// icon / title / subtitle / two buttons — no custom views — so we push the
// brand as far as that allows:
// - the icon is THE JUDGE (face PNG composited onto a cream card at runtime,
//   since the ink brushwork would vanish against the dark shield backdrop)
// - the judge's mood and the subtitle escalate with the app's unlock history,
//   same 12-hour window as the in-app mirror ritual.

class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    private static let cream = UIColor(red: 0.961, green: 0.941, blue: 0.910, alpha: 1)
    private static let ink   = UIColor(red: 0.102, green: 0.094, blue: 0.078, alpha: 1)

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        SharedDefaults.shared.recordShieldConfig()
        let appName = application.localizedDisplayName ?? "this app"

        // Escalation tier from unlock history when the token matches a config.
        var tier = 0
        if let token = application.token,
           let tokenData = try? JSONEncoder().encode(token),
           let config = SharedDefaults.shared.findApp(byTokenData: tokenData) {
            tier = min(config.recentUnlockCount(withinHours: 12), 2)
        }

        let face: String
        let subtitle: String
        switch tier {
        case 0:
            face = "judging"
            subtitle = "tap unlock to say your phrase to the judge."
        case 1:
            face = "unimpressed"
            subtitle = "back already. the judge is ready."
        default:
            face = "disappointed"
            subtitle = "again. the judge sighs. say your phrase."
        }

        return shieldConfig(title: "\(appName) is locked", subtitle: subtitle, face: face)
    }

    override func configuration(shielding application: Application,
                                in category: ActivityCategory) -> ShieldConfiguration {
        configuration(shielding: application)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        SharedDefaults.shared.recordShieldConfig()
        return shieldConfig(title: "this site is locked",
                            subtitle: "tap unlock to say your phrase to the judge.",
                            face: "judging")
    }

    override func configuration(shielding webDomain: WebDomain,
                                in category: ActivityCategory) -> ShieldConfiguration {
        configuration(shielding: webDomain)
    }

    // MARK: - Shared config

    private func shieldConfig(title: String, subtitle: String, face: String) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemThickMaterialDark,
            backgroundColor: Self.ink.withAlphaComponent(0.92),
            icon: Self.judgeIcon(named: face),
            title: ShieldConfiguration.Label(text: title, color: Self.cream),
            subtitle: ShieldConfiguration.Label(text: subtitle, color: Self.cream.withAlphaComponent(0.7)),
            primaryButtonLabel: ShieldConfiguration.Label(text: "unlock with voice", color: Self.ink),
            primaryButtonBackgroundColor: Self.cream,
            secondaryButtonLabel: ShieldConfiguration.Label(text: "stay focused", color: Self.cream.withAlphaComponent(0.6))
        )
    }

    // MARK: - Judge icon
    //
    // Face PNGs (bundled in Faces/) are 400×500, ink-on-transparent, content
    // centered at 56% of the shorter side. Composite onto a rounded cream card
    // so the brushwork reads against the dark shield.

    private static var iconCache: [String: UIImage] = [:]

    private static func judgeIcon(named face: String) -> UIImage? {
        if let cached = iconCache[face] { return cached }
        guard let faceImage = UIImage(named: face) else {
            return UIImage(systemName: "lock.fill")
        }

        let size = CGSize(width: 120, height: 120)
        let rendered = UIGraphicsImageRenderer(size: size).image { _ in
            cream.setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 24).fill()

            // Aspect-fit the 400×500 canvas into the card, then scale up so the
            // brushwork (56% of canvas) fills ~78% of the card.
            let ar = faceImage.size.width / max(faceImage.size.height, 1)
            var fit = CGRect(origin: .zero, size: size)
            if fit.width / fit.height > ar {
                fit.size.width = fit.height * ar
            } else {
                fit.size.height = fit.width / ar
            }
            let scale: CGFloat = 0.78 / 0.56
            let w = fit.width * scale
            let h = fit.height * scale
            faceImage.draw(in: CGRect(x: (size.width - w) / 2,
                                      y: (size.height - h) / 2,
                                      width: w, height: h))
        }
        iconCache[face] = rendered
        return rendered
    }
}
