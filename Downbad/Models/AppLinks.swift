import Foundation

// MARK: - AppLinks
//
// URL schemes for popular apps so we can deep-link the user back into the
// app they just unlocked. Matching mirrors AppIconView's palette lookup:
// case-insensitive contains on the display name (exact-match for "x").
//
// If an app isn't in the map we return nil and the success screen simply
// dismisses like before — never a wrong-app launch.

enum AppLinks {

    static func url(for displayName: String) -> URL? {
        let key = displayName.lowercased().trimmingCharacters(in: .whitespaces)

        // "X" needs an exact match — a contains-check on one letter would
        // false-positive on almost anything.
        if key == "x" { return URL(string: "twitter://timeline") }

        let map: [(needle: String, scheme: String)] = [
            ("instagram",  "instagram://app"),
            ("tiktok",     "tiktok://"),
            ("twitter",    "twitter://timeline"),
            ("youtube",    "youtube://"),
            ("reddit",     "reddit://"),
            ("snapchat",   "snapchat://"),
            ("facebook",   "fb://feed"),
            ("messenger",  "fb-messenger://"),
            ("discord",    "discord://"),
            ("pinterest",  "pinterest://"),
            ("linkedin",   "linkedin://"),
            ("twitch",     "twitch://"),
            ("netflix",    "nflx://"),
            ("spotify",    "spotify://"),
            ("whatsapp",   "whatsapp://"),
            ("telegram",   "tg://"),
            ("tumblr",     "tumblr://"),
        ]

        for entry in map where key.contains(entry.needle) {
            return URL(string: entry.scheme)
        }
        return nil
    }
}
