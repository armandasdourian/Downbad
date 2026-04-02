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
