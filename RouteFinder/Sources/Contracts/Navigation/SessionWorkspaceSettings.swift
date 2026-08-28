import Foundation

/// Persists macOS session convenience preferences.
public enum SessionWorkspaceSettings {
    private static let lastUserIDKey = "RouteFinder.session.lastUserID"
    private static let lastEmailKey = "RouteFinder.session.lastEmail"
    private static let requireLoginEachLaunchKey = "RouteFinder.session.requireLoginEachLaunch"

    /// Last authenticated local user identifier.
    public static func loadLastUserID(defaults: UserDefaults = .standard) -> String? {
        defaults.string(forKey: lastUserIDKey)
    }

    /// Persists the last authenticated local user identifier.
    public static func saveLastUserID(_ userID: String, defaults: UserDefaults = .standard) {
        defaults.set(userID, forKey: lastUserIDKey)
    }

    /// Last authenticated email for login pre-fill.
    public static func loadLastEmail(defaults: UserDefaults = .standard) -> String? {
        defaults.string(forKey: lastEmailKey)
    }

    /// Persists the last authenticated email.
    public static func saveLastEmail(_ email: String, defaults: UserDefaults = .standard) {
        defaults.set(email, forKey: lastEmailKey)
    }

    /// When true, skip Touch ID / device auto-unlock on launch.
    public static func loadRequireLoginEachLaunch(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: requireLoginEachLaunchKey)
    }

    /// Persists whether login is required on every launch.
    public static func saveRequireLoginEachLaunch(_ required: Bool, defaults: UserDefaults = .standard) {
        defaults.set(required, forKey: requireLoginEachLaunchKey)
    }

    /// Clears remembered session metadata (not the account itself).
    public static func clearRememberedSession(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: lastUserIDKey)
        defaults.removeObject(forKey: lastEmailKey)
    }
}
