import DataLayer
import Foundation
import Security
import Testing

@Test func keychainBaseQueryIncludesDataProtectionFlag() {
    let query = KeychainStore.baseQuery(
        service: "com.routefinder.test",
        account: "ors",
        useDataProtection: true
    )
    #expect(query[kSecClass as String] as? String == kSecClassGenericPassword as String)
    #expect(query[kSecAttrService as String] as? String == "com.routefinder.test")
    #expect(query[kSecAttrAccount as String] as? String == "ors")
    #expect(query[kSecUseDataProtectionKeychain as String] as? Bool == true)
}

@Test func keychainBaseQueryOmitsDataProtectionForLegacy() {
    let query = KeychainStore.baseQuery(
        service: "com.routefinder.test",
        account: nil,
        useDataProtection: false
    )
    #expect(query[kSecAttrAccount as String] == nil)
    #expect(query[kSecUseDataProtectionKeychain as String] == nil)
    #expect(query[kSecAttrAccessGroup as String] == nil)
}

@Test func keychainAccessDeniedRecognizesAuthFailedAndCancel() {
    #expect(KeychainStore.Error.isAccessDenied(errSecAuthFailed))
    #expect(KeychainStore.Error.isAccessDenied(errSecUserCanceled))
    #expect(!KeychainStore.Error.isAccessDenied(errSecItemNotFound))

    let denied = KeychainStore.Error.unexpectedStatus(errSecUserCanceled)
    #expect(denied.isAccessDenied)
    #expect(denied.localizedDescription.contains("Always Allow"))
}

@Test func keychainLegacyFallbackAllowedOutsideAppBundle() {
    // `swift test` host is not a .app — legacy fallback must remain for CI Keychain I/O.
    #expect(!KeychainStore.isAppBundleHost)
    #expect(KeychainStore.allowsLegacyKeychainFallback)
    #expect(KeychainStore.keychainAccessGroup == nil)

    let missing = KeychainStore.Error.unexpectedStatus(-34018)
    #expect(missing.localizedDescription.contains("RouteFinderMac"))
}

@Test func keychainBaseQueryOmitsAccessGroupOutsideAppBundle() {
    let query = KeychainStore.baseQuery(
        service: "com.routefinder.test",
        account: "ors",
        useDataProtection: true
    )
    // Test host has no keychain-access-groups entitlement.
    #expect(query[kSecAttrAccessGroup as String] == nil)
}

@Test func apiKeyVaultMigrationFlagSkipsRepeatLegacyWork() throws {
    let suiteName = "RouteFinderTests-vault-migrate-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let vault = APIKeyVault(userID: "test-user-id")
    try vault.migrateLegacyKeychainIfNeeded(defaults: defaults)
    #expect(defaults.bool(forKey: "RouteFinder.legacyVaultMigrated.test-user-id"))

    // Second call is a no-op (flag already set).
    try vault.migrateLegacyKeychainIfNeeded(defaults: defaults)
    #expect(defaults.bool(forKey: "RouteFinder.legacyVaultMigrated.test-user-id"))
}
