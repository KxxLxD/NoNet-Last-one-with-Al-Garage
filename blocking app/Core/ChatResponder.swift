//
//  ChatResponder.swift
//  blocking app
//
//  Abstraction over the in-app assistant so the local keyword engine can be swapped for a
//  remote LLM later without changing ChatBotView. Whatever responder is plugged in, the
//  view stays the same.
//
//  Today: `LocalChatResponder` — bilingual keyword-based replies. Honest about being local.
//  Later: swap in a `RemoteChatResponder` calling Claude/OpenAI. The view only sees this protocol.
//

import Foundation

protocol ChatResponder {
    /// Generate a reply for a user message in the given language.
    func reply(to message: String, isArabic: Bool) -> String
}

/// Default, on-device responder. No network calls.
struct LocalChatResponder: ChatResponder {
    func reply(to message: String, isArabic: Bool) -> String {
        let lowercased = message.lowercased()
        return isArabic ? arabicReply(lowercased) : englishReply(lowercased)
    }

    private func arabicReply(_ lowercased: String) -> String {
        if matches(lowercased, ["أرتب", "تنظيم", "حياتي"]) {
            return "🎯 لترتيب حياتك:\n• ابدأ بحجب المشتتات الأساسية (تيك توك، إنستغرام) لمدة ساعة\n• حدد 3 أهداف يومية واضحة\n• اختر وقت ثابت للمراجعة كل مساء"
        }
        if matches(lowercased, ["ريلز", "إدمان", "مضار"]) {
            return "⚠️ مضار إدمان الريلز:\n• تشتت الانتباه وضعف التركيز\n• مقارنات اجتماعية مؤذية\n• إضاعة ساعات ثمينة\n\n💡 الحل: ابدأ بحجب 30 دقيقة يومياً وزِد تدريجيًا"
        }
        if matches(lowercased, ["ألعاب", "قيمز", "gaming"]) {
            return "🎮 لتقليل وقت الألعاب:\n• حدد ساعة واحدة يومياً للألعاب\n• احجب التطبيقات خارج هذا الوقت\n• استبدل الألعاب بأنشطة حركية أو قراءة"
        }
        if matches(lowercased, ["سوشيال", "تواصل", "فيسبوك"]) {
            return "📱 للتخلص من عادة السوشيال:\n• احذف التطبيقات من الشاشة الرئيسية\n• فعّل إشعارات محدودة فقط\n• خصص أوقات معينة للتصفح (مثل 7-8 مساء)"
        }
        if matches(lowercased, ["خطة", "7 أيام", "تركيز"]) {
            return "📅 خطة التركيز 7 أيام:\n\nاليوم 1-2: حجب 30 دقيقة صباحًا\nاليوم 3-4: حجب ساعة كاملة\nاليوم 5-7: حجب 2-3 ساعات مع فترات راحة\n\n🎯 الهدف: بناء عادة تدريجية مستدامة"
        }
        if matches(lowercased, ["جدول", "60", "حظر"]) {
            return "⏰ جدول حظر 60 دقيقة مقترح:\n• 9-10 صباحًا: تركيز عمل عميق\n• 2-3 ظهرًا: مهام مهمة\n• 8-9 مساء: وقت عائلي أو قراءة\n\nاختر الوقت الأنسب لك!"
        }
        if matches(lowercased, ["بدائل", "صحية", "هاتف"]) {
            return "🌱 بدائل صحية للهاتف:\n• اقرأ كتابًا ورقيًا\n• امشِ في الطبيعة أو مارس الرياضة\n• تعلم مهارة جديدة (طبخ، رسم، موسيقى)\n• اقض وقتًا مع الأصدقاء والعائلة"
        }
        return "💡 أنا هنا لمساعدتك في رحلة التركيز! جرب الضغط على زر اللمبة 💡 لاقتراحات سريعة، أو اسأل عن:\n• ترتيب الحياة\n• مضار الإدمان الرقمي\n• خطط التركيز\n• بدائل صحية"
    }

    private func englishReply(_ lowercased: String) -> String {
        if matches(lowercased, ["organize", "life", "help me"]) {
            return "🎯 To organize your life:\n• Start by blocking main distractions (TikTok, Instagram) for 1 hour\n• Set 3 clear daily goals\n• Choose a fixed time for evening review"
        }
        if matches(lowercased, ["reels", "addiction", "harms"]) {
            return "⚠️ Harms of Reels addiction:\n• Attention fragmentation & poor focus\n• Harmful social comparisons\n• Wasted precious hours\n\n💡 Solution: Start with 30-min daily blocks, increase gradually"
        }
        if matches(lowercased, ["gaming", "games", "reduce"]) {
            return "🎮 To reduce gaming time:\n• Limit to 1 hour daily\n• Block gaming apps outside this window\n• Replace with physical activities or reading"
        }
        if matches(lowercased, ["social", "media", "quit"]) {
            return "📱 To quit social media habit:\n• Remove apps from home screen\n• Enable limited notifications only\n• Set specific browsing windows (e.g., 7-8 PM)"
        }
        if matches(lowercased, ["plan", "7", "focus"]) {
            return "📅 7-day Focus Plan:\n\nDay 1-2: Block 30 min in morning\nDay 3-4: Block 1 full hour\nDay 5-7: Block 2-3 hours with breaks\n\n🎯 Goal: Build sustainable habit gradually"
        }
        if matches(lowercased, ["schedule", "60", "suggest"]) {
            return "⏰ Suggested 60-min block schedule:\n• 9-10 AM: Deep work focus\n• 2-3 PM: Important tasks\n• 8-9 PM: Family time or reading\n\nChoose what fits your routine best!"
        }
        if matches(lowercased, ["alternatives", "healthy", "phone"]) {
            return "🌱 Healthy phone alternatives:\n• Read a physical book\n• Walk in nature or exercise\n• Learn new skills (cooking, art, music)\n• Spend quality time with friends/family"
        }
        return "💡 I'm here to help your focus journey! Try the bulb button 💡 for quick suggestions, or ask about:\n• Life organization\n• Digital addiction harms\n• Focus plans\n• Healthy alternatives"
    }

    /// Token-aware keyword match. Splits the user message on whitespace +
    /// punctuation, then checks each keyword in three passes:
    ///
    ///   1. Multi-word keywords (e.g. "help me", "7 أيام") — fall back to
    ///      a literal substring match so the phrase still triggers.
    ///   2. Exact token equality for single-word keywords — `"plan"` against
    ///      "plan today" hits, "planning" doesn't (unlike the old contains).
    ///   3. Prefix match for stems ≥4 chars — "addict" matches "addiction"
    ///      and "addictive" but not "ad" or "ditch".
    ///
    /// This replaces a naive `text.contains(keyword)` which gave false
    /// positives ("organizations" matched the stem "organization") and
    /// false negatives ("organizing" never matched "organize"). Still
    /// rule-based — not real morphology — but enough to stop the two
    /// foot-guns the previous version had.
    private func matches(_ text: String, _ keywords: [String]) -> Bool {
        let separators = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
        let tokens = text
            .components(separatedBy: separators)
            .filter { !$0.isEmpty }
        let tokenSet = Set(tokens)

        for keyword in keywords {
            if keyword.contains(" ") {
                if text.contains(keyword) { return true }
                continue
            }
            if tokenSet.contains(keyword) { return true }
            if keyword.count >= 4 {
                for token in tokens where token.count >= keyword.count && token.hasPrefix(keyword) {
                    return true
                }
            }
        }
        return false
    }
}
