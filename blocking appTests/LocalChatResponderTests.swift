import XCTest
@testable import blocking_app

final class LocalChatResponderTests: XCTestCase {
    private let responder = LocalChatResponder()

    // MARK: - Arabic

    func testArabicFocusKeywordReturnsLifeOrganization() {
        let reply = responder.reply(to: "كيف أرتب حياتي؟", isArabic: true)
        XCTAssertTrue(reply.contains("ترتيب حياتك"), "Reply: \(reply)")
    }

    func testArabicAddictionKeywordReturnsHarms() {
        let reply = responder.reply(to: "عندي إدمان ريلز", isArabic: true)
        XCTAssertTrue(reply.contains("إدمان") || reply.contains("ريلز"), "Reply: \(reply)")
    }

    func testArabicGamingKeyword() {
        let reply = responder.reply(to: "أبغى أقلل الألعاب", isArabic: true)
        XCTAssertTrue(reply.contains("الألعاب"), "Reply: \(reply)")
    }

    func testArabicUnknownInputReturnsDefault() {
        let reply = responder.reply(to: "بلابلابلا", isArabic: true)
        XCTAssertTrue(reply.contains("هنا لمساعدتك"), "Reply: \(reply)")
    }

    // MARK: - English

    func testEnglishOrganizeKeyword() {
        let reply = responder.reply(to: "Help me organize my life", isArabic: false)
        XCTAssertTrue(reply.contains("organize your life"), "Reply: \(reply)")
    }

    func testEnglishReelsKeyword() {
        let reply = responder.reply(to: "What are reels addiction harms", isArabic: false)
        XCTAssertTrue(reply.contains("Reels addiction"), "Reply: \(reply)")
    }

    func testEnglishUnknownReturnsDefault() {
        let reply = responder.reply(to: "xyz random", isArabic: false)
        XCTAssertTrue(reply.contains("help your focus"), "Reply: \(reply)")
    }

    // MARK: - Edge cases

    func testEmptyMessage() {
        let reply = responder.reply(to: "", isArabic: true)
        XCTAssertFalse(reply.isEmpty, "Default reply must always be returned")
    }

    func testCaseInsensitive() {
        let lower = responder.reply(to: "organize", isArabic: false)
        let upper = responder.reply(to: "ORGANIZE", isArabic: false)
        XCTAssertEqual(lower, upper, "Matching must be case-insensitive")
    }
}
