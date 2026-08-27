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
}

@Test func keychainAccessDeniedRecognizesAuthFailedAndCancel() {
    #expect(KeychainStore.Error.isAccessDenied(errSecAuthFailed))
    #expect(KeychainStore.Error.isAccessDenied(errSecUserCanceled))
    #expect(!KeychainStore.Error.isAccessDenied(errSecItemNotFound))

    let denied = KeychainStore.Error.unexpectedStatus(errSecUserCanceled)
    #expect(denied.isAccessDenied)
    #expect(denied.localizedDescription.contains("Always Allow"))
}
