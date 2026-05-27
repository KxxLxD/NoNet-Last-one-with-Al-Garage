//
//  RequestActionSheet.swift
//  blocking app
//
//  Shown when the user attempts to delete / disable / modify a Hard-Mode
//  list whose `gatekeeperType` is "partner". The action is gated on a human
//  Recovery Partner — this sheet collects the reason and creates a pending
//  BreakAttempt record in CloudKit. The partner sees it on their device's
//  HomeView (as an approval banner) and decides.
//

import SwiftUI

struct RequestActionSheet: View {
    let listID: UUID
    let listName: String
    let action: GatekeeperAction
    let partnership: Partnership
    /// Called once the request is enqueued in CloudKit. The caller may use
    /// this to refresh "pending partner approval" badges on the list card.
    let onRequestSent: () -> Void

    @EnvironmentObject var lang: LanguageManager
    @Environment(\.dismiss) private var dismiss

    @State private var reason: String = ""
    @State private var isSending: Bool = false
    @State private var errorMessage: String?

    /// Resolved partner display name, falling back to the inviter's proposed
    /// nickname (or a generic label) when the partner hasn't accepted yet.
    private var partnerName: String {
        partnership.partnerDisplayName
            ?? partnership.proposedPartnerName
            ?? (lang.isArabicEffective ? "شريكك" : "your partner")
    }

    private var actionVerbAr: String {
        switch action {
        case .delete:  return "حذف"
        case .disable: return "إيقاف"
        case .modify:  return "تعديل"
        }
    }

    private var actionVerbEn: String {
        switch action {
        case .delete:  return "delete"
        case .disable: return "pause"
        case .modify:  return "modify"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.lg) {
                    headerBlock
                    reasonField
                    sendButton
                    Spacer()
                }
                .padding(NNSpacing.lg)
            }
            .background(AppColors.uiBackground)
            .navigationTitle(action.title(isArabic: lang.isArabicEffective))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(lang.isArabicEffective ? "إلغاء" : "Cancel") { dismiss() }
                        .disabled(isSending)
                }
            }
        }
        .alert(
            lang.isArabicEffective ? "تعذّر إرسال الطلب" : "Couldn't send request",
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button(lang.isArabicEffective ? "حسناً" : "OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .interactiveDismissDisabled(isSending)
    }

    private var headerBlock: some View {
        VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.xs) {
            Image(systemName: "paperplane.fill")
                .font(.title)
                .foregroundColor(AppColors.accent)

            Text(lang.isArabicEffective
                 ? "سيُرسل الطلب لـ \(partnerName)"
                 : "Request will be sent to \(partnerName)")
                .font(.nnCardTitle)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)

            Text(lang.isArabicEffective
                 ? "هذه قائمة في الوضع الصارم. يحتاج \(partnerName) إلى الموافقة قبل تنفيذ \(actionVerbAr) القائمة «\(listName)»."
                 : "This list is in Hard Mode. \(partnerName) must approve before we can \(actionVerbEn) the list \"\(listName)\".")
                .font(.footnote)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)
        }
        .frame(maxWidth: .infinity, alignment: lang.isArabicEffective ? .trailing : .leading)
    }

    private var reasonField: some View {
        VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.xs) {
            // Reframe from "optional" to "important" — most partners need
            // context to make a real call; "optional" framing invites lazy
            // empty submissions that get auto-denied.
            Text(lang.isArabicEffective
                 ? "السبب (مهم لقرار شريكك)"
                 : "Reason (important for your partner's decision)")
                .font(.footnote.weight(.semibold))
                .foregroundColor(AppColors.textPrimary)

            ZStack(alignment: lang.isArabicEffective ? .topTrailing : .topLeading) {
                TextEditor(text: $reason)
                    .frame(minHeight: 120)
                    .padding(NNSpacing.xs)
                    .background(AppColors.uiSurface)
                    .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
                    .overlay(
                        RoundedRectangle(cornerRadius: NNRadius.control)
                            .stroke(AppColors.uiBorder, lineWidth: NNBorder.input)
                    )
                    .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)

                // SwiftUI TextEditor doesn't support a native placeholder;
                // overlay a faded Text and hide it once the user types.
                if reason.isEmpty {
                    Text(lang.isArabicEffective
                         ? "مثال: أحتاج التواصل مع شخص للعمل…"
                         : "Example: I need to contact someone for work…")
                        .font(.body)
                        .foregroundColor(AppColors.textDisabled)
                        .padding(.horizontal, NNSpacing.sm)
                        .padding(.top, NNSpacing.sm + 4)
                        .allowsHitTesting(false)
                }
            }

            Text(lang.isArabicEffective
                 ? "كلما كان السبب أوضح، كان قرار شريكك أسرع وأعدل."
                 : "Clearer reasons get faster, fairer decisions from your partner.")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)
        }
        .frame(maxWidth: .infinity, alignment: lang.isArabicEffective ? .trailing : .leading)
    }

    private var sendButton: some View {
        Button(action: sendRequest) {
            Group {
                if isSending {
                    ProgressView().tint(.white)
                } else {
                    Text(lang.isArabicEffective ? "أرسل الطلب" : "Send request")
                        .font(.subheadline.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: NNHitTarget.minimum + 4)
            .background(AppColors.accent)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
        }
        .buttonStyle(.plain)
        .disabled(isSending)
    }

    private func sendRequest() {
        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        // Capture connectivity BEFORE the await so a state flip mid-call
        // doesn't change which UX branch runs. createActionRequest now queues
        // when offline (returns non-nil so the caller can treat it as success);
        // we still want to know whether the actual CloudKit write happened so
        // the user isn't surprised when the partner notification is delayed.
        let wasOffline = !CloudKitPartnerStore.shared.isAccountAvailable
        isSending = true
        Task {
            let breakType: BreakAttemptType
            switch action {
            case .delete:  breakType = .delete
            case .disable: breakType = .disable
            case .modify:  breakType = .modify
            }
            let id = await CloudKitPartnerStore.shared.createActionRequest(
                partnershipID: partnership.id,
                listID: listID,
                listName: listName,
                type: breakType,
                reason: trimmed.isEmpty ? nil : trimmed
            )
            await MainActor.run {
                isSending = false
                // Non-nil = either sent live or enqueued for later flush via
                // PendingBreakAttemptQueue (handled by createActionRequest
                // itself). A nil return is reserved for pre-flight failures
                // we can't recover from (malformed args, etc.) — surface those.
                guard id != nil else {
                    errorMessage = CloudKitPartnerStore.shared.lastError
                        ?? (lang.isArabicEffective ? "تعذّر الإرسال" : "Send failed")
                    return
                }
                if wasOffline {
                    // The request is in the local queue; flushPendingBreakAttempts
                    // replays it on the next CKAccountChanged / foreground tick.
                    // Tell the parent to surface a "queued" indicator if it wants
                    // to — for now we just dismiss with the same callback as the
                    // online path so the badge updates immediately and the user
                    // sees their request appear in "awaiting partner".
                    onRequestSent()
                    dismiss()
                } else {
                    onRequestSent()
                    dismiss()
                }
            }
        }
    }
}
