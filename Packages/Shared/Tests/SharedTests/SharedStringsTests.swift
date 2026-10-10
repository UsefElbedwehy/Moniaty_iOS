import Testing
import Foundation
@testable import Shared

@Suite("SharedStrings / localization resources")
struct SharedStringsTests {
    @Test("SharedStrings accessors resolve to non-empty strings")
    func accessorsResolveToNonEmptyStrings() {
        let values = [
            SharedStrings.retry, SharedStrings.cancel, SharedStrings.save,
            SharedStrings.edit, SharedStrings.continue, SharedStrings.submit,
            SharedStrings.done, SharedStrings.back, SharedStrings.loading,
            SharedStrings.tryAgain, SharedStrings.viewAll, SharedStrings.seeMore
        ]

        for value in values {
            #expect(!value.isEmpty)
        }
    }

    @Test("en.lproj Localizable.strings ships in the module bundle and parses")
    func englishStringsFileShips() throws {
        let path = try #require(
            Bundle.module.path(forResource: "Localizable", ofType: "strings", inDirectory: "en.lproj")
        )
        let dictionary = try #require(NSDictionary(contentsOfFile: path) as? [String: String])

        #expect(dictionary["common.retry"] == "Retry")
        #expect(dictionary["common.cancel"] == "Cancel")
        #expect(!(dictionary["common.loading"] ?? "").isEmpty)
    }

    @Test("ar.lproj Localizable.strings ships in the module bundle, parses, and is not a transliteration placeholder")
    func arabicStringsFileShips() throws {
        let path = try #require(
            Bundle.module.path(forResource: "Localizable", ofType: "strings", inDirectory: "ar.lproj")
        )
        let dictionary = try #require(NSDictionary(contentsOfFile: path) as? [String: String])

        #expect(dictionary["common.retry"] == "إعادة المحاولة")
        #expect(dictionary["common.cancel"] == "إلغاء")
        #expect(!(dictionary["common.loading"] ?? "").isEmpty)

        // Every value should actually contain Arabic script, not be left in English.
        for (key, value) in dictionary {
            let containsArabic = value.unicodeScalars.contains { scalar in
                (0x0600...0x06FF).contains(scalar.value) || (0x0750...0x077F).contains(scalar.value)
            }
            #expect(containsArabic, "Expected Arabic text for key \(key), got: \(value)")
        }
    }

    @Test("en and ar resources define the same set of keys")
    func localizationKeysAreInSync() throws {
        let enPath = try #require(
            Bundle.module.path(forResource: "Localizable", ofType: "strings", inDirectory: "en.lproj")
        )
        let arPath = try #require(
            Bundle.module.path(forResource: "Localizable", ofType: "strings", inDirectory: "ar.lproj")
        )
        let enDict = try #require(NSDictionary(contentsOfFile: enPath) as? [String: String])
        let arDict = try #require(NSDictionary(contentsOfFile: arPath) as? [String: String])

        #expect(Set(enDict.keys) == Set(arDict.keys))
    }
}
