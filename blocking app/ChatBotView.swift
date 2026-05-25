import SwiftUI

struct ChatBotView: View {
    @EnvironmentObject var lang: LanguageManager
    @AppStorage(AppStorageKeys.isPremium) private var isPremium: Bool = false
    @AppStorage(AppStorageKeys.selectedTab) private var selectedTab: Int = 0
    private let responder: ChatResponder = LocalChatResponder()

    struct ChatMessage: Identifiable {
        let id = UUID()
        let isUser: Bool
        let text: String
        let timestamp: Date
    }

    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var showUpgradeAlert = false
    @State private var showSuggestions = false
    @State private var isTyping: Bool = false
    
    private var suggestions: [String] {
        if lang.isArabicEffective {
            return [
                "ساعدني أرتب حياتي",
                "ما مضار إدمان الريلز؟",
                "كيف أقلل وقت الألعاب؟",
                "أعطني خطة تركيز لمدة 7 أيام",
                "كيف أتخلص من عادة السوشيال؟",
                "اقترح جدول حظر 60 دقيقة",
                "بدائل صحية للهاتف"
            ]
        } else {
            return [
                "Help me organize my life",
                "What are the harms of Reels addiction?",
                "How to reduce gaming time?",
                "Give me a 7‑day focus plan",
                "How to quit social media habit?",
                "Suggest a 60‑minute block schedule",
                "Healthy alternatives to phone use"
            ]
        }
    }

    private var orgCategory: [String] {
        if lang.isArabicEffective {
            return [
                "ساعدني أرتب حياتي",
                "أعطني خطة تركيز لمدة 7 أيام",
                "اقترح جدول حظر 60 دقيقة",
                "روتين صباحي للتركيز",
                "نصائح لإدارة الوقت"
            ]
        } else {
            return [
                "Help me organize my life",
                "Give me a 7‑day focus plan",
                "Suggest a 60‑minute block schedule",
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
                "خطة حظر الإباحية للأبد",
                "خطة التخلص من القمار للأبد",
                "خطة نوم صحي (حظر النت ليلًا)",
                "خطة التقليل من إدمان السوشيال",
                "خطة التقليل من الريلز",
                "خطة التقليل من الألعاب"
            ]
        } else {
            return [
                "Lifelong porn‑block plan",
                "Quit gambling forever plan",
                "Healthy sleep (night internet off)",
                "Reduce social media addiction",
                "Reduce Reels use",
                "Reduce gaming time"
            ]
        }
    }

    var body: some View {
        NavigationView {
            Group {
                if !isPremium {
                    VStack(spacing: 16) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 48))  /* TODO: icon — consider Image scale */
                            .foregroundColor(AppColors.accent)
                        Text(lang.isArabicEffective ? "الشات بوت متاح فقط للمستخدمين المميزين" : "Chat Bot is available for Premium users")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        Button(action: { selectedTab = 2 }) {
                            Text(lang.isArabicEffective ? "اشترك الآن / Upgrade Now" : "Upgrade Now")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(AppColors.accent)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                } else {
                    VStack(spacing: 0) {
                        ScrollView {
                            VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 16) {
                                // Header
                                HStack(spacing: 8) {
                                    Image(systemName: "sparkles").foregroundColor(AppColors.accent)
                                    Text("NoNet AI")
                                        .font(.nnSectionTitle)
                                        .foregroundColor(AppColors.textPrimary)
                                    Spacer()
                                }
                                .padding(.top, 24)

                            LazyVStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 12) {
                                    ForEach(Array(messages.enumerated()), id: \.element.id) { idx, msg in
                                        if idx > 0 && messages[idx-1].isUser != msg.isUser {
                                            SoftDivider(width: 120, opacity: 0.45)
                                        }
                                    HStack {
                                        if msg.isUser {
                                            Spacer()
                                            bubble(text: msg.text, isUser: true)
                                        } else {
                                            bubble(text: msg.text, isUser: false)
                                            Spacer()
                                        }
                                    }
                                }
                                    if isTyping {
                                        HStack {
                                            typingIndicator()
                                            Spacer()
                                        }
                                    }
                                }
                                .padding(.bottom, 8)
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                        }
                        .padding(.bottom, 72)
                        HStack(spacing: 8) {
                            if lang.isArabicEffective {
                                Button(action: { showSuggestions = true }) {
                                    Image(systemName: "sparkles")
                                        .foregroundColor(AppColors.accent)
                                        .font(.title3)
                                        .frame(width: 44, height: 44)
                                        .background(AppColors.uiSurface)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(AppColors.uiBorder, lineWidth: 0.5)
                                        )
                                }
                                Button(action: send) {
                                    Image(systemName: "paperplane.fill")
                                        .foregroundColor(.white)
                                        .frame(width: 44, height: 44)
                                        .background(AppColors.accent)
                                        .cornerRadius(12)
                                }
                                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                HStack {
                                    TextField(lang.isArabicEffective ? "اكتب رسالتك" : "Type your message", text: $inputText)
                                        .multilineTextAlignment(.trailing)
                                        .textInputAutocapitalization(.sentences)
                                        .disableAutocorrection(false)
                                }
                                .padding(.horizontal, 12)
                                .frame(height: 44)
                                .background(AppColors.uiSurface)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(AppColors.uiBorder, lineWidth: 0.5)
                                )
                            } else {
                                HStack {
                                    TextField(lang.isArabicEffective ? "اكتب رسالتك" : "Type your message", text: $inputText)
                                        .multilineTextAlignment(.leading)
                                        .textInputAutocapitalization(.sentences)
                                        .disableAutocorrection(false)
                                }
                                .padding(.horizontal, 12)
                                .frame(height: 44)
                                .background(AppColors.uiSurface)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(AppColors.uiBorder, lineWidth: 0.5)
                                )
                                Button(action: { showSuggestions = true }) {
                                    Image(systemName: "sparkles")
                                        .foregroundColor(AppColors.accent)
                                        .font(.title3)
                                        .frame(width: 44, height: 44)
                                        .background(AppColors.uiSurface)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(AppColors.uiBorder, lineWidth: 0.5)
                                        )
                                }
                                Button(action: send) {
                                    Image(systemName: "paperplane.fill")
                                        .foregroundColor(.white)
                                        .frame(width: 44, height: 44)
                                        .background(AppColors.accent)
                                        .cornerRadius(12)
                                }
                                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .padding(.bottom, 12)
                        .background(AppColors.uiBackground)
                    }
                }
            }
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
            .background(AppColors.uiBackground)
            .onAppear(perform: seedIfFirstTime)
            .sheet(isPresented: $showSuggestions) {
                SuggestionsSheet(org: orgCategory, add: addictionCategory, plans: plansCategory) { chosen in
                    inputText = chosen
                    showSuggestions = false
                }
                .presentationDetents([.medium, .large])
                .background(AppColors.uiBackground)
            }
        }
    }

    private func bubble(text: String, isUser: Bool) -> some View {
        Text(text)
            .font(.body)
            .foregroundColor(AppColors.textPrimary)
            .padding(12)
            .background(AppColors.uiSurface)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(AppColors.uiBorder, lineWidth: 0.5)
            )
            .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: isUser ? .trailing : .leading)
    }

    private func typingIndicator() -> some View {
        Capsule()
            .fill(AppColors.infoBg)
            .frame(width: 36, height: 8)
            .padding(.vertical, 6)
    }

    private func send() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        messages.append(ChatMessage(isUser: true, text: trimmed, timestamp: Date()))
        inputText = ""
        isTyping = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            let reply = responder.reply(to: trimmed, isArabic: lang.isArabicEffective)
            messages.append(ChatMessage(isUser: false, text: reply, timestamp: Date()))
            isTyping = false
        }
    }

    private func selectSuggestion(_ text: String) { inputText = text }

    private func seedIfFirstTime() {
        if messages.isEmpty && isPremium {
            let welcome = lang.isArabicEffective ? "مرحبًا! أنا رفيق NoNet الذكي. كيف أساعدك اليوم؟" : "Hi! I'm your NoNet assistant. How can I help today?"
            messages.append(ChatMessage(isUser: false, text: welcome, timestamp: Date()))
        }
    }
}

private struct SoftDivider: View {
    let width: CGFloat
    let opacity: Double
    var body: some View {
        HStack {
            Spacer()
            Rectangle()
                .fill(AppColors.uiBorder.opacity(opacity))
                .frame(width: width, height: 1)
            Spacer()
        }
        .padding(.vertical, 6)
    }
}

struct SuggestionsSheet: View {
    let org: [String]
    let add: [String]
    let plans: [String]
    let onPick: (String) -> Void
    @EnvironmentObject var lang: LanguageManager

    private var columns: [GridItem] { [GridItem(.flexible())] }
    
    var body: some View {
        ZStack {
            AppColors.uiBackground.ignoresSafeArea()
        ScrollView {
            VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 24) {
                    HStack(spacing: 8) {
                        if lang.isArabicEffective { Spacer() }
                        Image(systemName: "sparkles")
                            .foregroundColor(AppColors.accent)
                            .font(.nnSubheader.weight(.semibold))
                Text(lang.isArabicEffective ? "اقتراحات" : "Suggestions")
                            .font(.nnSectionTitle)
                            .foregroundColor(AppColors.textPrimary)
                        if !lang.isArabicEffective { Spacer() }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)

                    VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 24) {
                        section(title: lang.isArabicEffective ? "التنظيم والتركيز" : "Organization & Focus", items: org)
                            .padding(16)
                            .background(AppColors.uiSurface)
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(AppColors.uiBorder, lineWidth: 0.5)
                            )
                        SoftDivider(width: 300, opacity: 0.70)
                        section(title: lang.isArabicEffective ? "الإدمان والبدائل" : "Addiction & Alternatives", items: add)
                            .padding(16)
                            .background(AppColors.uiSurface)
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(AppColors.uiBorder, lineWidth: 0.5)
                            )
                        SoftDivider(width: 300, opacity: 0.70)
                        section(title: lang.isArabicEffective ? "أفكار وخطط جبارة" : "Powerful Plans", items: plans)
                            .padding(16)
                            .background(AppColors.uiSurface)
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(AppColors.uiBorder, lineWidth: 0.5)
                            )
                        }
                    }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }
        }
    }

    private func section(title: String, items: [String]) -> some View {
        VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: lang.isArabicEffective ? .trailing : .leading)
            LazyVGrid(columns: columns, alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 12) {
                ForEach(items, id: \.self) { item in
                            Button(action: { onPick(item) }) {
                                    Text(item)
                            .font(.subheadline)
                            .foregroundColor(AppColors.textPrimary)
                                        .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: lang.isArabicEffective ? .trailing : .leading)
                            }
                            .buttonStyle(.plain)
                    .background(AppColors.uiSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.uiBorder, lineWidth: 0.5)
                            )
                    .contentShape(RoundedRectangle(cornerRadius: 12))
                    .cornerRadius(12)
                }
            }
        }
    }
}

#Preview {
    ChatBotView().environmentObject(LanguageManager.shared)
} 