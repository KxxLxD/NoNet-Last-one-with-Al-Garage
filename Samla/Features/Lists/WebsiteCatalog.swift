import SwiftUI

/// Popular websites grouped by what pulls people in, for one-tap blocking: a whole category or
/// just some of its sites. Websites only — Apple doesn't let apps pre-select other apps, so apps
/// are chosen in Apple's own list.
struct WebsiteCategory: Identifiable {
    enum Kind {
        /// Time-wasters, blocked by schedule or on demand.
        case distraction
        /// Porn, gambling and dating: Block Forever covers these around the clock.
        case harmful
    }

    struct Site: Identifiable, Hashable {
        let title: String
        let domain: String
        var id: String { domain }
    }

    let id: String
    let title: LocalizedStringKey
    let systemImage: String
    let kind: Kind
    let sites: [Site]
    /// Shown under the expanded sites, e.g. what can't be blocked on its own.
    var note: LocalizedStringKey?
    /// Block Forever already blocks every site in this category when it's on.
    var coveredByForever = false

    static let distractions = all.filter { $0.kind == .distraction }
    static let harmful = all.filter { $0.kind == .harmful }
    static let allDomains = Set(all.flatMap { $0.sites.map(\.domain) })

    static let all: [WebsiteCategory] = [
        WebsiteCategory(id: "social", title: "Social Media", systemImage: "bubble.left.and.bubble.right.fill", kind: .distraction, sites: [
            Site(title: "Instagram", domain: "instagram.com"),
            Site(title: "Snapchat", domain: "snapchat.com"),
            Site(title: "X", domain: "x.com"),
            Site(title: "Facebook", domain: "facebook.com"),
            Site(title: "Threads", domain: "threads.net"),
            Site(title: "Reddit", domain: "reddit.com"),
            Site(title: "Pinterest", domain: "pinterest.com"),
        ]),
        WebsiteCategory(id: "short-video", title: "Short Videos", systemImage: "play.square.stack.fill", kind: .distraction, sites: [
            Site(title: "TikTok", domain: "tiktok.com"),
            Site(title: "Likee", domain: "likee.video"),
            Site(title: "Kwai", domain: "kwai.com"),
            Site(title: "Triller", domain: "triller.co"),
        ], note: "Reels and Shorts can't be blocked on their own — block Instagram or YouTube instead."),
        WebsiteCategory(id: "video", title: "Video & Streaming", systemImage: "play.rectangle.fill", kind: .distraction, sites: [
            Site(title: "YouTube", domain: "youtube.com"),
            Site(title: "Netflix", domain: "netflix.com"),
            Site(title: "Shahid", domain: "shahid.mbc.net"),
            Site(title: "OSN+", domain: "osnplus.com"),
            Site(title: "Prime Video", domain: "primevideo.com"),
            Site(title: "Disney+", domain: "disneyplus.com"),
            Site(title: "Twitch", domain: "twitch.tv"),
            Site(title: "Kick", domain: "kick.com"),
        ]),
        WebsiteCategory(id: "games", title: "Games", systemImage: "gamecontroller.fill", kind: .distraction, sites: [
            Site(title: "Roblox", domain: "roblox.com"),
            Site(title: "Steam", domain: "steampowered.com"),
            Site(title: "Epic Games", domain: "epicgames.com"),
            Site(title: "Chess.com", domain: "chess.com"),
            Site(title: "Poki", domain: "poki.com"),
            Site(title: "CrazyGames", domain: "crazygames.com"),
            Site(title: "Miniclip", domain: "miniclip.com"),
        ]),
        WebsiteCategory(id: "ai", title: "AI Tools", systemImage: "sparkles", kind: .distraction, sites: [
            Site(title: "ChatGPT", domain: "chatgpt.com"),
            Site(title: "OpenAI", domain: "openai.com"),
            Site(title: "Gemini", domain: "gemini.google.com"),
            Site(title: "Claude", domain: "claude.ai"),
            Site(title: "Copilot", domain: "copilot.microsoft.com"),
            Site(title: "Perplexity", domain: "perplexity.ai"),
            Site(title: "Grok", domain: "grok.com"),
            Site(title: "DeepSeek", domain: "deepseek.com"),
            Site(title: "Character.AI", domain: "character.ai"),
            Site(title: "Poe", domain: "poe.com"),
        ], note: "To block an AI app too, choose it in Apps."),
        WebsiteCategory(id: "shopping", title: "Shopping", systemImage: "bag.fill", kind: .distraction, sites: [
            Site(title: "Amazon", domain: "amazon.sa"),
            Site(title: "noon", domain: "noon.com"),
            Site(title: "SHEIN", domain: "shein.com"),
            Site(title: "AliExpress", domain: "aliexpress.com"),
            Site(title: "Temu", domain: "temu.com"),
            Site(title: "Namshi", domain: "namshi.com"),
            Site(title: "Trendyol", domain: "trendyol.com"),
        ]),
        WebsiteCategory(id: "news", title: "News", systemImage: "newspaper.fill", kind: .distraction, sites: [
            Site(title: "Al Jazeera", domain: "aljazeera.net"),
            Site(title: "Al Arabiya", domain: "alarabiya.net"),
            Site(title: "Sky News Arabia", domain: "skynewsarabia.com"),
            Site(title: "Sabq", domain: "sabq.org"),
            Site(title: "BBC", domain: "bbc.com"),
            Site(title: "CNN", domain: "cnn.com"),
        ]),
        WebsiteCategory(id: "crypto", title: "Crypto & Trading", systemImage: "chart.line.uptrend.xyaxis", kind: .distraction, sites: [
            Site(title: "Binance", domain: "binance.com"),
            Site(title: "Coinbase", domain: "coinbase.com"),
            Site(title: "Bybit", domain: "bybit.com"),
            Site(title: "OKX", domain: "okx.com"),
            Site(title: "KuCoin", domain: "kucoin.com"),
            Site(title: "eToro", domain: "etoro.com"),
            Site(title: "TradingView", domain: "tradingview.com"),
        ]),
        WebsiteCategory(id: "gambling", title: "Gambling", systemImage: "suit.club.fill", kind: .harmful,
                        sites: ForeverBlock.gamblingDomains.map { Site(title: displayName($0), domain: $0) },
                        coveredByForever: true),
        WebsiteCategory(id: "dating", title: "Dating", systemImage: "heart.slash.fill", kind: .harmful,
                        sites: ForeverBlock.datingDomains.map { Site(title: displayName($0), domain: $0) },
                        coveredByForever: true),
    ]

    private static let displayNames = [
        "bet365.com": "bet365", "1xbet.com": "1xBet", "stake.com": "Stake", "betway.com": "Betway",
        "williamhill.com": "William Hill", "pokerstars.com": "PokerStars", "draftkings.com": "DraftKings",
        "fanduel.com": "FanDuel", "betfair.com": "Betfair", "melbet.com": "Melbet", "parimatch.com": "Parimatch",
        "888casino.com": "888casino", "tinder.com": "Tinder", "bumble.com": "Bumble", "badoo.com": "Badoo",
        "hinge.co": "Hinge", "okcupid.com": "OkCupid", "match.com": "Match", "pof.com": "POF", "grindr.com": "Grindr",
        "happn.com": "happn", "muzz.com": "Muzz", "eharmony.com": "eharmony", "ashleymadison.com": "Ashley Madison",
        "adultfriendfinder.com": "AdultFriendFinder",
    ]

    private static func displayName(_ domain: String) -> String {
        displayNames[domain] ?? domain
    }
}
