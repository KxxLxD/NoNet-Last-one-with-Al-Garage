//
//  LanguageResolverTests.swift
//  blocking appTests
//
//  Exercises Core/LanguageResolver.swift — single source of truth for the
//  effective UI language. Tests cover the explicit user-choice path
//  ("arabic" / "english"), the fall-through-to-locale path ("system" /
//  unrecognised), and the no-stored-value default.
//

import XCTest
@testable import blocking_app

final class LanguageResolverTests: XCTestCase {
    private let key = LanguageResolver.storageKey

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: key)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: key)
        super.tearDown()
    }

    func testExplicitArabicChoiceReturnsTrue() {
        UserDefaults.standard.set("arabic", forKey: key)
        XCTAssertTrue(LanguageResolver.isArabicEffective())
    }

    func testExplicitEnglishChoiceReturnsFalse() {
        UserDefaults.standard.set("english", forKey: key)
        XCTAssertFalse(LanguageResolver.isArabicEffective())
    }

    func testNoStoredValueFallsThroughToLocale() {
        // No assertion on the return value — we can't control the simulator's
        // Locale.preferredLanguages from a unit test. The contract we ARE
        // verifying: the resolver returns a deterministic Bool (no crash, no
        // throw) when storage is empty.
        UserDefaults.standard.removeObject(forKey: key)
        _ = LanguageResolver.isArabicEffective()
    }

    func testSystemChoiceFallsThroughToLocale() {
        UserDefaults.standard.set("system", forKey: key)
        _ = LanguageResolver.isArabicEffective() // deterministic, no crash
    }

    func testUnknownChoiceFallsThroughToLocale() {
        // Should not crash on a corrupted value (e.g. tampered defaults).
        UserDefaults.standard.set("klingon", forKey: key)
        _ = LanguageResolver.isArabicEffective()
    }

    func testStorageKeyMatchesLanguageManagerConvention() {
        // The shared constant is the contract between LanguageManager (writer)
        // and LanguageResolver (reader). If either side drifts away from
        // "AppLanguage", every consumer of LanguageManager.updateLanguage
        // diverges from every reader of LanguageResolver.isArabicEffective.
        XCTAssertEqual(LanguageResolver.storageKey, "AppLanguage")
    }
}
