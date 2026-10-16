import Foundation

/// Rotating encouragement shown on the block screen and in the daily reminder:
/// a mix of Quran verses, hadith and sayings.
enum MotivationalQuotes {
    static var all: [String] {
        [
            String(localized: "“Tell the believing men to lower their gaze.” — An-Nur 24:30"),
            String(localized: "“As for those who strive for Us, We will surely guide them to Our ways.” — Al-Ankabut 29:69"),
            String(localized: "“Allah does not change the condition of a people until they change what is in themselves.” — Ar-Ra’d 13:11"),
            String(localized: "“By time, indeed mankind is in loss.” — Al-Asr 103:1–2"),
            String(localized: "“There are two blessings many people are cheated of: health and free time.” — Al-Bukhari"),
            String(localized: "“Strive for what benefits you, seek Allah’s help, and don’t give up.” — Muslim"),
            String(localized: "“Part of a person’s good Islam is leaving what doesn’t concern him.” — At-Tirmidhi"),
            String(localized: "Time is like a sword: if you don’t cut it, it cuts you."),
            String(localized: "Whoever knows what they seek finds the effort easy."),
            String(localized: "Discipline is choosing what you want most over what you want now."),
        ]
    }

    static func random() -> String {
        all.randomElement() ?? ""
    }
}
