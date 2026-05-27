import SwiftUI

/// NoNet AI chat surface — Premium-gated. Standard chat UI layout:
///   ┌──────────────────────────────────┐
///   │ Header (sticky)                   │  ← brand + clear button
///   ├──────────────────────────────────┤
///   │                                   │
///   │   Messages (scrollable area)      │  ← auto-scroll to bottom
///   │   • user bubbles: accent + white  │
///   │   • AI bubbles:   surface + text  │
///   │   • typing indicator: 3 dots      │
///   │                                   │
///   ├──────────────────────────────────┤
///   │ [💡]  Type a message  [→]         │  ← sticky input bar
///   └──────────────────────────────────┘
///
/// Layout decisions
/// • Header sits OUTSIDE the ScrollView so it doesn't scroll away.
/// • Input bar sits OUTSIDE the ScrollView with its own surface bg so
///   typing always has a stable anchor.
/// • RTL handled by SwiftUI's layoutDirection environment — no
///   duplicated branches per language (the previous version had ~70
///   lines of mirrored if-Arabic-else code for the same input bar).
/// • Messages are styled iOS Messages–style: user bubbles use the
///   accent fill with white text, AI bubbles use uiSurface with
///   textPrimary. Different visual weight makes the conversation
///   easy to skim.
struct ChatBotView: View {
    @EnvironmentObject var lang: LanguageManager
    @AppStorage(AppStorageKeys.isPremium) private var isPremium: Bool = false
    @AppStorage(AppStorageKeys.selectedTab) private var selectedTab: Int = 0
    /// Free-tier daily message budget. Resets at midnight per-device. We
    /// store the count + last-used date as separate AppStorage keys so the
    /// rollover logic stays simple (compare day-component only).
    @AppStorage(AppStorageKeys.chatFreeMessagesUsedToday) private var freeMessagesUsedToday: Int = 0
    @AppStorage(AppStorageKeys.chatFreeMessagesLastDayKey) private var freeMessagesLastDayKey: String = ""

    /// How many free messages a non-premium user gets per day. Picked as
    /// "enough to evaluate the assistant" without giving away the premium
    /// experience. Tune via experiment if conversion data warrants it.
    static let freeDailyMessageBudget: Int = 3

    /// Hard cap on persisted messages — UserDefaults isn't meant for
    /// unbounded payloads, and a 50-message window covers ~a week of
    /// casual use without bloating launch-time JSON decode.
    static let maxPersistedMessages: Int = 50

    private let responder: ChatResponder = LocalChatResponder()

    struct ChatMessage: Identifiable, Codable {
        var id: UUID
        let isUser: Bool
        let text: String
        let timestamp: Date

        init(isUser: Bool, text: String, timestamp: Date) {
            self.id = UUID()
            self.isUser = isUser
            self.text = text
            self.timestamp = timestamp
        }
    }

    /// Tiny Identifiable wrapper so a single shared String can drive
    /// `.sheet(item:)` for the system Share Sheet.
    struct ShareableText: Identifiable {
        let id = UUID()
        let text: String
    }

    /// Persistence-backing for the conversation. We store JSON in AppStorage
    /// rather than holding `[ChatMessage]` as a pseudo-property because
    /// AppStorage demands a `RawRepresentable` value. The computed `messages`
    /// var keeps the rest of the view talking about an array.
    @AppStorage(AppStorageKeys.chatMessagesJSON) private var messagesJSON: String = "[]"
    @State private var inputText: String = ""
    @State private var showSuggestions = false
    @State private var isTyping: Bool = false
    @State private var showFreeLimitReached: Bool = false
    /// Drives the destructive confirmation dialog before wiping the
    /// conversation. Necessary now that persistence keeps up to 50 messages —
    /// a single mis-tap could discard a week of saved AI plans.
    @State private var showClearConfirm: Bool = false
    /// Backing for the `ShareLink` invoked from a bubble's contextMenu.
    /// Non-nil = sheet visible. Wrapping a String in Identifiable lets us
    /// drive `.sheet(item:)` directly.
    @State private var shareItem: ShareableText?

    /// In-memory mirror of `messagesJSON`. Reading parses JSON; writing
    /// re-encodes back to `messagesJSON` so AppStorage persists across
    /// launches. Capped at `maxPersistedMessages` on write so UserDefaults
    /// stays small.
    private var messages: [ChatMessage] {
        get {
            guard let data = messagesJSON.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([ChatMessage].self, from: data)) ?? []
        }
        nonmutating set {
            let bounded = newValue.suffix(Self.maxPersistedMessages)
            guard let data = try? JSONEncoder().encode(Array(bounded)),
                  let str = String(data: data, encoding: .utf8) else { return }
            messagesJSON = str
        }
    }

    /// Day-stable key (YYYY-MM-DD) used to detect when to reset the daily
    /// free-message counter. Computed every access — cheap, no caching.
    private var todayKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: Date())
    }

    /// Free messages remaining today, after auto-resetting at midnight.
    /// Premium users always see Int.max conceptually (we don't gate them).
    private var freeRemainingToday: Int {
        if freeMessagesLastDayKey != todayKey { return Self.freeDailyMessageBudget }
        return max(0, Self.freeDailyMessageBudget - freeMessagesUsedToday)
    }

    /// True when a non-premium user has hit their daily free-message limit.
    /// Used to gate the send button and surface the upgrade prompt.
    private var freeBudgetExhausted: Bool {
        !isPremium && freeRemainingToday <= 0
    }

    // ─── Suggestion sources ───────────────────────────────────────
    // Three categories shown in the suggestions sheet. Each list is
    // language-aware. The first three of `orgCategory` also serve as
    // inline "starter chips" in the empty state.

    private var orgCategory: [String] {
        if lang.isArabicEffective {
            return [
                "ساعدني أرتب حياتي",
                "أعطني خطة تركيز لمدة 7 أيام",
                "اقترح جدول حجب 60 دقيقة",
                "روتين صباحي للتركيز",
                "نصائح لإدارة الوقت"
            ]
        } else {
            return [
                "Help me organize my life",
                "Give me a 7-day focus plan",
                "Suggest a 60-minute block schedule",
                "Morning routine for focus",
                "Time management tips"
            ]
        }
    }

    private var addictionCategory: [String] {
        if lang.isArabicEffective {
            return [
                "ما مضار إدمان الريلز؟",
                "كيف أقلل وقت الألعاب؟",
                "كيف أتخلص من عادة السوشيال؟",
                "بدائل صحية للهاتف",
                "تقنيات مقاومة الإغراء"
            ]
        } else {
            return [
                "What are the harms of Reels addiction?",
                "How to reduce gaming time?",
                "How to quit social media habit?",
                "Healthy alternatives to phone use",
                "Techniques to resist temptation"
            ]
        }
    }

    private var plansCategory: [String] {
        if lang.isArabicEffective {
            return [
                "خطة حجب الإباحية للأبد",
                "خطة التخلص من القمار للأبد",
                "خطة نوم صحي (حجب النت ليلاً)",
                "خطة التقليل من إدمان السوشيال",
                "خطة التقليل من الريلز",
                "خطة التقليل من الألعاب"
            ]
        } else {
            return [
                "Lifelong porn-block plan",
                "Quit gambling forever plan",
                "Healthy sleep (night internet off)",
                "Reduce social media addiction",
                "Reduce Reels use",
                "Reduce gaming time"
            ]
        }
    }

    // ─── Body ─────────────────────────────────────────────────────

    var body: some View {
        NavigationStack {
            chatSurface
                .navigationTitle("")
                .toolbar(.hidden, for: .navigationBar)
                .background(AppColors.uiBackground)
        }
        .sheet(isPresented: $showSuggestions) {
            SuggestionsSheet(org: orgCategory, add: addictionCategory, plans: plansCategory) { chosen in
                inputText = chosen
                showSuggestions = false
            }
            .environmentObject(lang)
            .presentationDetents([.medium, .large])
        }
        .alert(
            lang.isArabicEffective ? "انتهى رصيد اليوم المجاني" : "Daily free messages used up",
            isPresented: $showFreeLimitReached
        ) {
            Button(lang.isArabicEffective ? "اشترك في Premium" : "Subscribe to Premium") {
                selectedTab = 2
            }
            Button(lang.isArabicEffective ? "لاحقاً" : "Later", role: .cancel) {}
        } message: {
            Text(lang.isArabicEffective
                 ? "استخدمت \(Self.freeDailyMessageBudget) رسائل مجانية اليوم. سيتجدّد الرصيد منتصف الليل، أو اشترك في Premium لرسائل غير محدودة."
                 : "You've used your \(Self.freeDailyMessageBudget) free messages for today. Your quota resets at midnight, or subscribe to Premium for unlimited messages.")
        }
        .confirmationDialog(
            lang.isArabicEffective ? "احذف كل المحادثة؟" : "Clear conversation?",
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button(lang.isArabicEffective ? "احذف المحادثة" : "Delete conversation", role: .destructive) {
                clearChat()
            }
            Button(lang.isArabicEffective ? "إلغاء" : "Cancel", role: .cancel) {}
        } message: {
            Text(lang.isArabicEffective
                 ? "سيتم حذف كل الرسائل المحفوظة (حتى \(Self.maxPersistedMessages) رسالة). لا يمكن التراجع."
                 : "All saved messages (up to \(Self.maxPersistedMessages)) will be removed. This can't be undone.")
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(text: item.text)
        }
    }

    // ─── Chat surface (header + messages + input) ─────────────────

    @ViewBuilder
    private var chatSurface: some View {
        VStack(spacing: 0) {
            chatHeader
            Divider().background(AppColors.uiBorder.opacity(0.6))
            messagesArea
            inputBar
        }
    }

    @ViewBuilder
    private var chatHeader: some View {
        HStack(spacing: NNSpacing.xs) {
            Image(systemName: "sparkles")
                .foregroundColor(AppColors.accent)
            Text("NoNet AI")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)
            // Small Premium tag next to the title so gating is visible up
            // front. The daily-limit chip below it already implies premium
            // gating, but a labelled badge is the convention used on
            // paywalls / Settings, so showing it here makes the screen
            // legible to a user landing on it cold.
            Text(lang.isArabicEffective ? "Premium" : "Premium")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, NNSpacing.xs - 2)
                .padding(.vertical, 2)
                .background(AppColors.accent.opacity(0.12))
                .foregroundColor(AppColors.accent)
                .clipShape(Capsule())
            // Free-tier counter chip — gives non-premium users visibility
            // into how many messages they have left today + a tap-target
            // that jumps to the upgrade tab. Hidden for premium.
            if !isPremium {
                Button(action: { selectedTab = 2 }) {
                    HStack(spacing: NNSpacing.xxs) {
                        Image(systemName: "sparkle")
                            .font(.caption2)
                        Text(lang.isArabicEffective
                             ? "\(freeRemainingToday)/\(Self.freeDailyMessageBudget) مجانية"
                             : "\(freeRemainingToday)/\(Self.freeDailyMessageBudget) free")
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                    }
                    .foregroundColor(freeRemainingToday > 0 ? AppColors.accent : AppColors.alertRed)
                    .padding(.vertical, NNSpacing.xxs)
                    .padding(.horizontal, NNSpacing.xs)
                    .background((freeRemainingToday > 0 ? AppColors.accent : AppColors.alertRed).opacity(0.10))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(lang.isArabicEffective ? "تبقّى \(freeRemainingToday) من \(Self.freeDailyMessageBudget)" : "\(freeRemainingToday) of \(Self.freeDailyMessageBudget) remaining")
            }
            Spacer()
            if !messages.isEmpty {
                // `trash` reads as "delete" semantically — counter-clockwise
                // is "undo" in iOS convention. Combined with the confirmation
                // dialog below, mis-taps no longer wipe the conversation.
                Button(action: { showClearConfirm = true }) {
                    Image(systemName: "trash")
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: NNHitTarget.minimum, height: NNHitTarget.minimum)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(lang.isArabicEffective ? "مسح المحادثة" : "Clear conversation")
                .accessibilityHint(lang.isArabicEffective ? "يحذف كل الرسائل بعد التأكيد" : "Deletes every message after confirmation")
            }
        }
        .padding(.horizontal, NNSpacing.md)
        .frame(height: 56)
        .background(AppColors.uiSurface)
    }

    @ViewBuilder
    private var messagesArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.sm) {
                    if messages.isEmpty {
                        emptyStateChips
                            .padding(.top, NNSpacing.xxl)
                    }
                    // Render with day separators interleaved when consecutive
                    // messages cross a calendar day boundary — without these,
                    // persisted conversations from earlier days look like
                    // they all happened "now."
                    ForEach(Array(messages.enumerated()), id: \.element.id) { idx, msg in
                        if shouldShowDaySeparator(at: idx, messages: messages) {
                            daySeparator(for: msg.timestamp)
                                .id("sep-\(msg.id)")
                        }
                        messageRow(msg)
                            .id(msg.id)
                    }
                    if isTyping {
                        HStack(alignment: .bottom, spacing: NNSpacing.xs) {
                            typingIndicator
                            Text(lang.isArabicEffective ? "NoNet يكتب…" : "NoNet is typing…")
                                .font(.caption2)
                                .foregroundColor(AppColors.textSecondary)
                                .padding(.bottom, NNSpacing.xxs)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, NNSpacing.md)
                        .id("typing")
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(lang.isArabicEffective ? "NoNet يكتب رداً" : "NoNet is typing a reply")
                    }
                }
                .padding(.vertical, NNSpacing.md)
            }
            .background(AppColors.uiBackground)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages.count) { _ in
                scrollToLatest(proxy: proxy)
            }
            .onChange(of: isTyping) { typing in
                if typing { withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("typing", anchor: .bottom) } }
            }
            .onAppear {
                seedIfFirstTime()
                scrollToLatest(proxy: proxy)
            }
        }
    }

    @ViewBuilder
    private var emptyStateChips: some View {
        VStack(spacing: NNSpacing.md) {
            Image(systemName: "sparkles")
                .font(.largeTitle)
                .foregroundColor(AppColors.accent)
            Text(lang.isArabicEffective ? "كيف أقدر أساعدك اليوم؟" : "How can I help today?")
                .font(.title3.weight(.semibold))
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
            VStack(spacing: NNSpacing.xs) {
                ForEach(orgCategory.prefix(3), id: \.self) { starter in
                    Button(action: {
                        inputText = starter
                        send()
                    }) {
                        Text(starter)
                            .font(.subheadline)
                            .foregroundColor(AppColors.accent)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, NNSpacing.md)
                            .frame(minHeight: NNHitTarget.minimum)
                            .frame(maxWidth: .infinity)
                            .background(AppColors.infoBg)
                            .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
                    }
                    .buttonStyle(.plain)
                }
                // Surface the full suggestion sheet right next to the starters
                // so users discover the 16-prompt catalog without hunting for
                // the lightbulb icon down at the input bar.
                Button(action: { showSuggestions = true }) {
                    HStack(spacing: NNSpacing.xxs) {
                        Image(systemName: "lightbulb")
                            .font(.caption)
                        Text(lang.isArabicEffective ? "اقتراحات أكثر" : "More suggestions")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundColor(AppColors.textSecondary)
                    .frame(minHeight: NNHitTarget.minimum - 8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, NNSpacing.lg)
    }

    /// True when the message at `idx` is on a different calendar day than
    /// the message before it (or when it's the first message). Used to
    /// decide whether to insert a day separator above it.
    private func shouldShowDaySeparator(at idx: Int, messages: [ChatMessage]) -> Bool {
        guard idx > 0 else { return true } // first message always gets a header
        let cal = Calendar.current
        return !cal.isDate(messages[idx].timestamp, inSameDayAs: messages[idx - 1].timestamp)
    }

    /// "Today" / "Yesterday" / formatted weekday + date — a single quiet
    /// centered chip between messages from different days.
    @ViewBuilder
    private func daySeparator(for date: Date) -> some View {
        HStack {
            Spacer(minLength: 0)
            Text(formattedSeparator(for: date))
                .font(.caption2.weight(.semibold))
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, NNSpacing.sm)
                .padding(.vertical, NNSpacing.xxs)
                .background(AppColors.uiSurface)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(AppColors.uiBorder.opacity(0.6), lineWidth: NNBorder.hairline)
                )
            Spacer(minLength: 0)
        }
        .padding(.vertical, NNSpacing.xs)
        .accessibilityElement()
        .accessibilityLabel(formattedSeparator(for: date))
    }

    /// Localized "today" / "yesterday" / "EEEE، d MMM" — Calendar-based so
    /// timezone changes don't shift the label.
    private func formattedSeparator(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            return lang.isArabicEffective ? "اليوم" : "Today"
        }
        if cal.isDateInYesterday(date) {
            return lang.isArabicEffective ? "أمس" : "Yesterday"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: lang.isArabicEffective ? "ar" : "en_US")
        formatter.dateFormat = lang.isArabicEffective ? "EEEE، d MMMM" : "EEEE, MMM d"
        return formatter.string(from: date)
    }

    @ViewBuilder
    private func messageRow(_ msg: ChatMessage) -> some View {
        HStack {
            if msg.isUser { Spacer(minLength: 40) }
            bubble(for: msg)
            if !msg.isUser { Spacer(minLength: 40) }
        }
        .padding(.horizontal, NNSpacing.md)
    }

    /// Slightly larger bubble radius (NNRadius.card + 2 = 18) than the standard
    /// card corner; bubbles read more "speech-like" when their corners are
    /// rounder than surrounding cards. Kept consistent with typingIndicator.
    private static let bubbleRadius: CGFloat = NNRadius.card + 2

    @ViewBuilder
    private func bubble(for msg: ChatMessage) -> some View {
        let bg = msg.isUser ? AppColors.accent : AppColors.uiSurface
        let fg = msg.isUser ? Color.white : AppColors.textPrimary
        Text(msg.text)
            .font(.body)
            .foregroundColor(fg)
            .padding(.horizontal, NNSpacing.sm + 2)
            .padding(.vertical, NNSpacing.sm - 2)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: Self.bubbleRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Self.bubbleRadius)
                    .stroke(msg.isUser ? Color.clear : AppColors.uiBorder, lineWidth: NNBorder.hairline)
            )
            .textSelection(.enabled)
            // Long-press menu so users can pull AI plans (7-day focus, etc.)
            // into other apps without manual highlight-and-copy.
            .contextMenu {
                Button {
                    UIPasteboard.general.string = msg.text
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } label: {
                    Label(lang.isArabicEffective ? "نسخ" : "Copy", systemImage: "doc.on.doc")
                }
                Button {
                    shareItem = ShareableText(text: msg.text)
                } label: {
                    Label(lang.isArabicEffective ? "مشاركة" : "Share", systemImage: "square.and.arrow.up")
                }
            }
    }

    /// Three-dot indicator with a staggered bounce — actually communicates
    /// "the AI is typing", unlike the previous static capsule.
    @ViewBuilder
    private var typingIndicator: some View {
        HStack(spacing: NNSpacing.xxs) {
            ForEach(0..<3, id: \.self) { idx in
                TypingDot(delay: Double(idx) * 0.18)
            }
        }
        .padding(.horizontal, NNSpacing.sm + 2)
        .padding(.vertical, NNSpacing.sm - 2)
        .background(AppColors.uiSurface)
        .clipShape(RoundedRectangle(cornerRadius: Self.bubbleRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Self.bubbleRadius)
                .stroke(AppColors.uiBorder, lineWidth: NNBorder.hairline)
        )
    }

    @ViewBuilder
    private var inputBar: some View {
        HStack(spacing: NNSpacing.xs) {
            // Suggestions launcher — light secondary action
            Button(action: { showSuggestions = true }) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(AppColors.accent)
                    .frame(width: NNHitTarget.minimum, height: NNHitTarget.minimum)
                    .background(AppColors.infoBg)
                    .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(lang.isArabicEffective ? "اقتراحات" : "Suggestions")

            // Text input — grows as the user types (up to 4 lines)
            HStack {
                TextField(lang.isArabicEffective ? "اكتب رسالتك..." : "Type your message...", text: $inputText, axis: .vertical)
                    .lineLimit(1...4)
                    .textInputAutocapitalization(.sentences)
                    .disableAutocorrection(false)
                    .onSubmit(send)
            }
            .padding(.horizontal, NNSpacing.sm + 2)
            .padding(.vertical, NNSpacing.xs + 2)
            .background(AppColors.uiBackground)
            .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
            .overlay(
                RoundedRectangle(cornerRadius: NNRadius.control)
                    .stroke(AppColors.uiBorder, lineWidth: NNBorder.hairline)
            )

            // Send — primary action; visually disabled when empty
            Button(action: send) {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(.white)
                    .frame(width: NNHitTarget.minimum, height: NNHitTarget.minimum)
                    .background(canSend ? AppColors.accent : AppColors.textDisabled)
                    .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .accessibilityLabel(lang.isArabicEffective ? "إرسال" : "Send")
        }
        .padding(.horizontal, NNSpacing.md)
        .padding(.vertical, NNSpacing.sm)
        .background(
            AppColors.uiSurface
                .shadow(color: Color.black.opacity(0.04), radius: 4, y: -1)
        )
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // ─── Behaviour ────────────────────────────────────────────────

    private func send() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // Free-tier gating: refuse with an upgrade prompt once the daily
        // budget is gone. Premium skips this branch entirely.
        if !isPremium {
            if freeRemainingToday <= 0 {
                showFreeLimitReached = true
                return
            }
            // Roll over the counter if this is the first message of a new day.
            if freeMessagesLastDayKey != todayKey {
                freeMessagesLastDayKey = todayKey
                freeMessagesUsedToday = 0
            }
            freeMessagesUsedToday += 1
        }
        messages.append(ChatMessage(isUser: true, text: trimmed, timestamp: Date()))
        inputText = ""
        isTyping = true
        // Simulated thinking delay — Task.sleep cooperates with task
        // cancellation (if the view disappears mid-typing, the reply
        // append is skipped instead of mutating after dismiss).
        let isArabicNow = lang.isArabicEffective
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            let reply = responder.reply(to: trimmed, isArabic: isArabicNow)
            messages.append(ChatMessage(isUser: false, text: reply, timestamp: Date()))
            isTyping = false
        }
    }

    private func clearChat() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeOut(duration: 0.2)) {
            messages.removeAll()
            isTyping = false
        }
        // Re-seed the welcome message immediately so the surface doesn't
        // flash empty in the milliseconds after clearing.
        seedIfFirstTime()
    }

    private func seedIfFirstTime() {
        guard messages.isEmpty && isPremium else { return }
        // Empty state now shows starter chips instead of an automatic
        // welcome message — keeps the surface looking inviting without
        // forcing the user to read a greeting first.
    }

    private func scrollToLatest(proxy: ScrollViewProxy) {
        guard let last = messages.last else { return }
        withAnimation(.easeOut(duration: 0.25)) {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }
}

// MARK: - TypingDot

/// One of three dots in the typing indicator. Each receives a staggered
/// `delay` so the three dots bounce in a wave.
private struct TypingDot: View {
    let delay: Double
    @State private var bouncing = false

    var body: some View {
        Circle()
            // accent at 60% lifts the indicator above AA contrast on the
            // surface bg (where textSecondary @ 60% sat at ~2.1:1, failing).
            .fill(AppColors.accent.opacity(0.6))
            .frame(width: 7, height: 7)
            .offset(y: bouncing ? -3 : 0)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 0.45)
                        .repeatForever(autoreverses: true)
                        .delay(delay)
                ) {
                    bouncing = true
                }
            }
    }
}

// MARK: - SuggestionsSheet

/// Bottom sheet that surfaces categorized starter prompts. Tapping a
/// row prefills the input field (does NOT auto-send) so the user can
/// review or edit before sending.
struct SuggestionsSheet: View {
    let org: [String]
    let add: [String]
    let plans: [String]
    let onPick: (String) -> Void
    @EnvironmentObject var lang: LanguageManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.lg) {
                    section(
                        title: lang.isArabicEffective ? "التنظيم والتركيز" : "Organization & Focus",
                        icon: "calendar",
                        items: org
                    )
                    section(
                        title: lang.isArabicEffective ? "الإدمان والبدائل" : "Addiction & Alternatives",
                        icon: "leaf.fill",
                        items: add
                    )
                    section(
                        title: lang.isArabicEffective ? "خطط جاهزة" : "Ready Plans",
                        icon: "list.bullet.rectangle",
                        items: plans
                    )
                }
                .padding(.horizontal, NNSpacing.xl)
                .padding(.vertical, NNSpacing.md)
            }
            .background(AppColors.uiBackground)
            .navigationTitle(lang.isArabicEffective ? "اقتراحات" : "Suggestions")
            .navigationBarTitleDisplayMode(.inline)
        }
        .environment(\.layoutDirection, lang.isArabicEffective ? .rightToLeft : .leftToRight)
    }

    @ViewBuilder
    private func section(title: String, icon: String, items: [String]) -> some View {
        VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.sm) {
            HStack(spacing: NNSpacing.xs) {
                Image(systemName: icon)
                    .foregroundColor(AppColors.accent)
                    .font(.subheadline)
                Text(title)
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
            }
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element) { idx, item in
                    Button(action: { onPick(item) }) {
                        HStack {
                            Text(item)
                                .font(.subheadline)
                                .foregroundColor(AppColors.textPrimary)
                                .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)
                                .frame(maxWidth: .infinity, alignment: lang.isArabicEffective ? .trailing : .leading)
                            Image(systemName: lang.isArabicEffective ? "chevron.left" : "chevron.right")
                                .foregroundColor(AppColors.textSecondary)
                                .font(.caption)
                        }
                        .padding(.horizontal, NNSpacing.md)
                        .frame(minHeight: NNHitTarget.minimum + 4)
                    }
                    .buttonStyle(.plain)
                    if idx < items.count - 1 {
                        Divider()
                            .background(AppColors.uiBorder.opacity(0.4))
                            .padding(.horizontal, NNSpacing.md)
                    }
                }
            }
            .background(AppColors.uiSurface)
            .clipShape(RoundedRectangle(cornerRadius: NNRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: NNRadius.card)
                    .stroke(AppColors.uiBorder, lineWidth: NNBorder.hairline)
            )
        }
    }
}

#Preview {
    ChatBotView().environmentObject(LanguageManager.shared)
}

// MARK: - ShareSheet

/// UIActivityViewController wrapper for SwiftUI. Used by the bubble
/// contextMenu's Share action so the user can pipe an AI reply into
/// Messages / Notes / WhatsApp / etc. without leaving the app.
private struct ShareSheet: UIViewControllerRepresentable {
    let text: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
