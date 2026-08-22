import Foundation
import Testing
@testable import RouteController

struct RegistrationNormalizerTests {
    @Test func normalize_stripsSpacesAndHyphens() {
        #expect(RegistrationNormalizer.normalize("AU14 TWZ") == "AU14TWZ")
        #expect(RegistrationNormalizer.normalize("au14 twz") == "AU14TWZ")
        #expect(RegistrationNormalizer.normalize("ab-12-cde") == "AB12CDE")
        #expect(RegistrationNormalizer.normalize("VC7607") == "VC7607")
    }

    @Test func normalize_removesPunctuation() {
        #expect(RegistrationNormalizer.normalize(" ab 12 cde! ") == "AB12CDE")
        #expect(RegistrationNormalizer.normalize("") == "")
        #expect(RegistrationNormalizer.normalize("   ") == "")
    }

    @Test func formatForDisplay_appliesUKPattern() {
        #expect(RegistrationNormalizer.formatForDisplay("AU14 TWZ") == "AU14 TWZ")
        #expect(RegistrationNormalizer.formatForDisplay("au14 twz") == "AU14 TWZ")
        #expect(RegistrationNormalizer.formatForDisplay("ab-12-cde") == "AB12 CDE")
    }

    @Test func formatForDisplay_leavesNonUKPlatesUnchanged() {
        #expect(RegistrationNormalizer.formatForDisplay("VC7607") == "VC7607")
        #expect(RegistrationNormalizer.formatForDisplay("OLD123") == "OLD123")
    }
}
