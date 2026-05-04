import Foundation
import FamilyControls
import ManagedSettings

// MARK: - App Group

let appGroupID = "group.com.voicegate.app"

// MARK: - Storage Keys

enum StorageKeys {
    static let blockedApps = "blockedApps"
    static let defaultUnlockDuration = "defaultUnlockDuration"
    static let pendingUnlockAppID = "pendingUnlockAppID"
    static let hasOnboarded = "hasOnboarded"
    static let shieldConfigInvocations = "diag.shieldConfigInvocations"
    static let shieldConfigLastAt = "diag.shieldConfigLastAt"
    static let shieldButtonTaps = "diag.shieldButtonTaps"
    static let shieldButtonLastAt = "diag.shieldButtonLastAt"
}

// MARK: - Unlock Duration

enum UnlockDuration: Int, Codable, CaseIterable, Identifiable {
    case fiveMinutes = 5
    case fifteenMinutes = 15
    case thirtyMinutes = 30
    case oneHour = 60
    case twoHours = 120
    case fourHours = 240
    case restOfDay = -1

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .fiveMinutes: return "5 minutes"
        case .fifteenMinutes: return "15 minutes"
        case .thirtyMinutes: return "30 minutes"
        case .oneHour: return "1 hour"
        case .twoHours: return "2 hours"
        case .fourHours: return "4 hours"
        case .restOfDay: return "Rest of day"
        }
    }

    /// Returns the unlock expiration date from now, or end of today for `.restOfDay`.
    func expirationDate(from date: Date = .now) -> Date {
        if self == .restOfDay {
            return Calendar.current.startOfDay(for: date).addingTimeInterval(24 * 60 * 60)
        }
        return date.addingTimeInterval(TimeInterval(rawValue * 60))
    }
}

// MARK: - Phrase Preset

enum PhrasePreset: String, Codable, CaseIterable, Identifiable {
    case pleadingShort
    case pleadingLong
    case embarrassingAdmit
    case beggingRepeat
    case desperateConfession
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pleadingShort: return "Pleading (short)"
        case .pleadingLong: return "Pleading (long)"
        case .embarrassingAdmit: return "Embarrassing admission"
        case .beggingRepeat: return "Begging repeat"
        case .desperateConfession: return "Desperate confession"
        case .custom: return "Custom phrase"
        }
    }

    var template: String? {
        switch self {
        case .pleadingShort: return "please unlock {app} i really need it please"
        case .pleadingLong: return "please unlock {app}, i really really need it, i promise i'll be quick, please please please"
        case .embarrassingAdmit: return "i have no self control and i need {app} right now"
        case .beggingRepeat: return "please please please please unlock {app}"
        case .desperateConfession: return "i am so sorry for wanting {app} again, please unlock it, i'll hate myself later"
        case .custom: return nil
        }
    }

    func render(for appName: String) -> String? {
        let trimmed = appName.trimmingCharacters(in: .whitespaces)
        let name = trimmed.isEmpty ? "this app" : trimmed.lowercased()
        return template?.replacingOccurrences(of: "{app}", with: name)
    }
}

// MARK: - Blocked App Config

struct BlockedAppConfig: Codable, Identifiable {
    let id: UUID
    var displayName: String
    var unlockPhrase: String
    var unlockDurationMinutes: Int
    var tokenData: Data
    var isUnlocked: Bool
    var unlockExpiresAt: Date?

    init(displayName: String, unlockPhrase: String, unlockDuration: UnlockDuration, tokenData: Data) {
        self.id = UUID()
        self.displayName = displayName
        self.unlockPhrase = unlockPhrase
        self.unlockDurationMinutes = unlockDuration.rawValue
        self.tokenData = tokenData
        self.isUnlocked = false
        self.unlockExpiresAt = nil
    }

    var unlockDuration: UnlockDuration {
        UnlockDuration(rawValue: unlockDurationMinutes) ?? .thirtyMinutes
    }

    // MARK: Token Encoding

    static func encodeToken(_ token: ApplicationToken) -> Data? {
        try? JSONEncoder().encode(token)
    }

    static func decodeToken(from data: Data) -> ApplicationToken? {
        try? JSONDecoder().decode(ApplicationToken.self, from: data)
    }

    var applicationToken: ApplicationToken? {
        Self.decodeToken(from: tokenData)
    }
}

// MARK: - Shared UserDefaults

final class SharedDefaults {
    static let shared = SharedDefaults()

    let defaults: UserDefaults

    private init() {
        defaults = UserDefaults(suiteName: appGroupID) ?? .standard
    }

    var blockedApps: [BlockedAppConfig] {
        get {
            guard let data = defaults.data(forKey: StorageKeys.blockedApps),
                  let apps = try? JSONDecoder().decode([BlockedAppConfig].self, from: data) else {
                return []
            }
            return apps
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: StorageKeys.blockedApps)
            }
        }
    }

    var defaultUnlockDuration: UnlockDuration {
        get {
            let raw = defaults.integer(forKey: StorageKeys.defaultUnlockDuration)
            return UnlockDuration(rawValue: raw) ?? .thirtyMinutes
        }
        set {
            defaults.set(newValue.rawValue, forKey: StorageKeys.defaultUnlockDuration)
        }
    }

    /// The ID of the app the user is trying to unlock (set by shield action, read by main app).
    var pendingUnlockAppID: String? {
        get { defaults.string(forKey: StorageKeys.pendingUnlockAppID) }
        set { defaults.set(newValue, forKey: StorageKeys.pendingUnlockAppID) }
    }

    /// Whether the user has completed onboarding. Reset by the "reset onboarding" action in Settings.
    var hasOnboarded: Bool {
        get { defaults.bool(forKey: StorageKeys.hasOnboarded) }
        set { defaults.set(newValue, forKey: StorageKeys.hasOnboarded) }
    }

    // MARK: Helpers

    func updateApp(id: UUID, mutate: (inout BlockedAppConfig) -> Void) {
        var apps = blockedApps
        guard let index = apps.firstIndex(where: { $0.id == id }) else { return }
        mutate(&apps[index])
        blockedApps = apps
    }

    func findApp(byTokenData data: Data) -> BlockedAppConfig? {
        blockedApps.first { $0.tokenData == data }
    }

    // MARK: Diagnostics

    var shieldConfigInvocations: Int {
        get { defaults.integer(forKey: StorageKeys.shieldConfigInvocations) }
        set { defaults.set(newValue, forKey: StorageKeys.shieldConfigInvocations) }
    }

    var shieldConfigLastAt: Date? {
        get { defaults.object(forKey: StorageKeys.shieldConfigLastAt) as? Date }
        set { defaults.set(newValue, forKey: StorageKeys.shieldConfigLastAt) }
    }

    var shieldButtonTaps: Int {
        get { defaults.integer(forKey: StorageKeys.shieldButtonTaps) }
        set { defaults.set(newValue, forKey: StorageKeys.shieldButtonTaps) }
    }

    var shieldButtonLastAt: Date? {
        get { defaults.object(forKey: StorageKeys.shieldButtonLastAt) as? Date }
        set { defaults.set(newValue, forKey: StorageKeys.shieldButtonLastAt) }
    }

    func recordShieldConfig() {
        shieldConfigInvocations += 1
        shieldConfigLastAt = .now
    }

    func recordShieldButtonTap() {
        shieldButtonTaps += 1
        shieldButtonLastAt = .now
    }

    /// Re-lock any apps whose unlock has expired.
    func relockExpiredApps() -> [UUID] {
        var apps = blockedApps
        var relocked: [UUID] = []
        let now = Date.now
        for i in apps.indices where apps[i].isUnlocked {
            if let expiry = apps[i].unlockExpiresAt, expiry <= now {
                apps[i].isUnlocked = false
                apps[i].unlockExpiresAt = nil
                relocked.append(apps[i].id)
            }
        }
        if !relocked.isEmpty {
            blockedApps = apps
        }
        return relocked
    }
}
