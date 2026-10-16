import Foundation

/// External links used across the app. Community links show as "coming soon" until real URLs are set.
enum AppLinks {
    static let supportEmail = "support@nonet.app"
    static let supportMail = URL(string: "mailto:\(supportEmail)")
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
