import Foundation

/// Curated tips shown in Settings › Tips, grouped by topic.
enum FocusTips {
    struct Topic: Identifiable {
        let id: String
        let title: LocalizedStringResource
        let systemImage: String
        let tips: [String]
    }

    static var topics: [Topic] {
        [
            Topic(id: "sleep", title: "Sleep", systemImage: "moon.zzz.fill", tips: [
                String(localized: "😴 For healthier sleep:\n• Create a scheduled list from 10 PM to 7 AM\n• Keep your phone out of the bedroom\n• Replace late scrolling with reading or a short walk"),
            ]),
            Topic(id: "focus", title: "Focus", systemImage: "scope", tips: [
                String(localized: "🎯 To organize your life:\n• Start by blocking your main distractions (TikTok, Instagram) for 1 hour\n• Set 3 clear daily goals\n• Choose a fixed time for an evening review"),
                String(localized: "📅 7-day focus plan:\n\nDays 1–2: block for 30 minutes each morning\nDays 3–4: block for a full hour\nDays 5–7: block for 2–3 hours with short breaks\n\n🎯 Goal: build a sustainable habit gradually"),
                String(localized: "⏰ Suggested 60-minute block schedule:\n• 9–10 AM: deep work\n• 2–3 PM: important tasks\n• 8–9 PM: family time or reading\n\nPick the time that fits your routine best!"),
            ]),
            Topic(id: "habits", title: "Habits", systemImage: "arrow.triangle.2.circlepath", tips: [
                String(localized: "⚠️ Harms of Reels addiction:\n• Fragmented attention and weaker focus\n• Harmful social comparisons\n• Hours of precious time lost\n\n💡 Solution: start with a 30-minute daily block and increase gradually"),
                String(localized: "🎮 To reduce gaming time:\n• Limit games to 1 hour a day\n• Block gaming apps outside that window\n• Replace games with exercise or reading"),
                String(localized: "📱 To quit the social media habit:\n• Remove the apps from your home screen\n• Keep only essential notifications\n• Set specific browsing windows (e.g. 7–8 PM)"),
                String(localized: "🧠 To resist the urge to scroll:\n• Wait 10 minutes before opening the app\n• Name the feeling behind the urge (boredom, stress)\n• Put the phone in another room for focused work"),
                String(localized: "🛡️ To quit adult content for good:\n• Turn on \"Adult Websites\" in What to block, in a Hard Mode list\n• Block the apps and browsers you relapse on\n• Talk to someone you trust and track your streak"),
                String(localized: "🎲 To stop gambling:\n• Block betting apps and websites in a Hard Mode list\n• Remove saved payment cards from those services\n• Seek support from a professional or a support group"),
            ]),
            Topic(id: "alternatives", title: "Healthy Alternatives", systemImage: "leaf.fill", tips: [
                String(localized: "🌱 Healthy alternatives to your phone:\n• Read a paper book\n• Walk outside or exercise\n• Learn a new skill (cooking, drawing, music)\n• Spend time with friends and family"),
            ]),
        ]
    }
}
