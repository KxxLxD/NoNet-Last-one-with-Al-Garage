import SwiftUI

struct FAQView: View {
    private struct Item: Identifiable {
        let id: Int
        let question: LocalizedStringKey
        let answer: LocalizedStringKey
    }

    private let items: [Item] = [
        Item(id: 1, question: "What is Samla?",
             answer: "Samla helps you block distracting apps and websites, protect yourself from harmful content, and build healthy focus habits."),
        Item(id: 2, question: "Why can't I delete the app?",
             answer: "A list in Hard Mode or protected by your partner is active, or Block Forever is on. Hard Mode ends when the list ends. Block Forever ends 360 days after you request an unlock, or sooner with your partner's PIN."),
        Item(id: 3, question: "What is Block Forever?",
             answer: "A free, permanent filter for porn, gambling and dating websites. You can also lock every 17+ app. To turn it off you request an unlock and wait 360 days, or your partner enters their PIN."),
        Item(id: 4, question: "I forgot my partner's PIN. What now?",
             answer: "Open Settings › Accountability Partner and tap Forgot PIN. Your partner is removed after 7 days. Block Forever isn't affected and keeps its 360-day wait."),
        Item(id: 5, question: "Blocking isn't working?",
             answer: "Make sure Screen Time access is allowed. If Home shows a missing-permissions banner, tap Fix and allow access. Blocking only works on a real iPhone."),
        Item(id: 6, question: "Where does my data go?",
             answer: "Everything stays on your device. Samla has no servers, collects no data and never sells anything. Apple's Screen Time keeps the apps you choose private, even from Samla."),
        Item(id: 7, question: "Are breaks allowed?",
             answer: "Yes, except in Hard Mode. Under Extra Options choose how many breaks you get per 24 hours and how long each lasts. Start a break from the list's page or the block screen."),
        Item(id: 8, question: "How do scheduled lists work?",
             answer: "Choose Schedule under When, then add days and times. Blocking starts and stops automatically, even when Samla is closed."),
        Item(id: 9, question: "How many lists can I create?",
             answer: "The free version holds 3 lists. Premium, coming soon, will remove the limit. Block Forever stays free forever."),
        Item(id: 10, question: "Can I block AI apps like ChatGPT?",
             answer: "Yes. In What to block, tick AI Tools to block their websites, and choose the apps themselves under Apps. Apple doesn't let Samla pick apps for you."),
        Item(id: 11, question: "What is No Internet Mode?",
             answer: "It blocks every app and website while the list is active, except the apps you allow. Apple doesn't let any app turn off Wi-Fi itself, and phone calls always work."),
    ]

    var body: some View {
        List(items) { item in
            DisclosureGroup {
                Text(item.answer)
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.vertical, Spacing.xs)
            } label: {
                Text(item.question)
                    .font(.headline)
                    .foregroundStyle(AppColors.text)
            }
        }
        .navigationTitle("FAQ")
        .navigationBarTitleDisplayMode(.inline)
    }
}
