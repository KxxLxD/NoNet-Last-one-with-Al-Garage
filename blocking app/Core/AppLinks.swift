import Foundation

/// External links used across the app. Community links show as "coming soon" until real URLs are set.
enum AppLinks {
    /// No official email yet: every support row and link stays hidden while this is nil.
    static let supportEmail: String? = nil
    static let supportMail = supportEmail.flatMap { URL(string: "mailto:\($0)") }
    /// Apple's standard Licensed Application End User License Agreement.
    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
    /// Hosted privacy policy (required in App Store Connect). Set once docs/privacy-policy.md is published.
    static let privacyPolicy: URL? = nil
    static let whatsAppCommunity: URL? = nil
    static let telegramChannel: URL? = nil

    /// Opens WhatsApp with a ready message; the user picks the chat.
    static func whatsApp(message: String) -> URL? {
        var components = URLComponents(string: "https://wa.me/")
        components?.queryItems = [URLQueryItem(name: "text", value: message)]
        return components?.url
    }
}
