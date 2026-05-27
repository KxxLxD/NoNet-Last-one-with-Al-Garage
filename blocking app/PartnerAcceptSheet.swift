//
//  PartnerAcceptSheet.swift
//  blocking app
//
//  Shown to the invitee right after they tap a CloudKit share invitation link.
//  The Scene delegate stashes the CKShare.Metadata into
//  CloudKitPartnerStore.pendingShareMetadata; ContentView observes that and
//  presents this sheet. The user picks how they want their name to appear to
//  the inviter, then approves or rejects.
//
//  The actual CloudKit container.accept(_:) call deferred until the user taps
//  "Accept" here — so a tap-on-link doesn't silently auto-accept.
//

import SwiftUI
import CloudKit

struct PartnerAcceptSheet: View {
    let metadata: CKShare.Metadata
    let onFinished: () -> Void

    @EnvironmentObject var lang: LanguageManager
    @Environment(\.dismiss) private var dismiss

    @State private var partnerDisplayName: String = ""
    @State private var inviterName: String = ""
    @State private var isProcessing: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.lg) {
                    headerBlock

                    nameField

                    explanationBlock

                    actionButtons

                    Spacer()
                }
                .padding(NNSpacing.lg)
            }
            .background(AppColors.uiBackground)
            .navigationTitle(lang.isArabicEffective ? "دعوة شريك" : "Partner invitation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    // "Close" reads more honestly than "Later" — closing this
                    // sheet without picking accept/decline doesn't queue
                    // anything; the inviter has to re-send the link.
                    Button(lang.isArabicEffective ? "إغلاق" : "Close") { finish() }
                        .disabled(isProcessing)
                }
            }
        }
        .onAppear(perform: prefillFromMetadata)
        .alert(
            lang.isArabicEffective ? "تعذّر معالجة الدعوة" : "Couldn't process invitation",
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button(lang.isArabicEffective ? "حسناً" : "OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .interactiveDismissDisabled(isProcessing)
    }

    // MARK: - View components

    private var headerBlock: some View {
        VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.xs) {
            Image(systemName: "person.2.badge.gearshape.fill")
                .font(.title)
                .foregroundColor(AppColors.accent)

            Text(inviterName.isEmpty
                 ? (lang.isArabicEffective ? "دعوة شريك تعافي" : "Recovery partner invitation")
                 : (lang.isArabicEffective ? "\(inviterName) يطلبك تكون شريك تعافي له" : "\(inviterName) is asking you to be their recovery partner"))
                .font(.nnCardTitle)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)
                .frame(maxWidth: .infinity, alignment: lang.isArabicEffective ? .trailing : .leading)

            // Safety net: CKShare links can be forwarded. If the recipient
            // doesn't recognize the inviter, they should not accept blindly.
            if !inviterName.isEmpty {
                HStack(alignment: .top, spacing: NNSpacing.xs) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                    Text(lang.isArabicEffective
                         ? "إن لم تكن تعرف \(inviterName)، ارفض الدعوة."
                         : "If you don't know \(inviterName), decline the invitation.")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)
                }
                .frame(maxWidth: .infinity, alignment: lang.isArabicEffective ? .trailing : .leading)
            }
        }
    }

    private var nameField: some View {
        VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.xs) {
            Text(lang.isArabicEffective
                 ? "اسمك كما تريد أن يراك"
                 : "Your name as you want them to see it")
                .font(.footnote.weight(.semibold))
                .foregroundColor(AppColors.textPrimary)

            TextField(
                lang.isArabicEffective ? "اكتب اسمك" : "Enter your name",
                text: $partnerDisplayName
            )
            .textInputAutocapitalization(.words)
            .padding(NNSpacing.sm)
            .background(AppColors.uiSurface)
            .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
            .overlay(
                RoundedRectangle(cornerRadius: NNRadius.control)
                    .stroke(AppColors.uiBorder, lineWidth: NNBorder.input)
            )
            .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)

            if !proposedName.isEmpty {
                Text(lang.isArabicEffective
                     ? "اقترح \(inviterName.isEmpty ? "المُرسل" : inviterName) أن يسميك: «\(proposedName)»"
                     : "\(inviterName.isEmpty ? "The sender" : inviterName) suggested: \"\(proposedName)\"")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: lang.isArabicEffective ? .trailing : .leading)
    }

    private var explanationBlock: some View {
        VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.xs) {
            Label(
                lang.isArabicEffective ? "كشريك تعافٍ ستتلقى:" : "As a recovery partner you'll:",
                systemImage: "info.circle.fill"
            )
            .font(.subheadline.weight(.semibold))
            .foregroundColor(AppColors.accent)

            bullet(lang.isArabicEffective
                   ? "إشعاراً عند كل محاولة حذف أو تعديل لقائمة الحجب."
                   : "Get a push when they try to delete or modify a blocking list.")
            bullet(lang.isArabicEffective
                   ? "زرّي «موافق» / «رفض» لكل طلب — أنت من يقرّر."
                   : "See Approve / Deny buttons for each request — you decide.")
            bullet(lang.isArabicEffective
                   ? "تستطيع الانسحاب من الشراكة لاحقاً متى شئت."
                   : "You can leave the partnership at any time.")
        }
        .padding(NNSpacing.md)
        .background(AppColors.infoBg)
        .clipShape(RoundedRectangle(cornerRadius: NNRadius.card))
    }

    @ViewBuilder
    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: NNSpacing.xs) {
            Image(systemName: "checkmark.circle.fill")
                .font(.footnote)
                .foregroundColor(AppColors.accent)
            Text(text)
                .font(.footnote)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)
                .frame(maxWidth: .infinity, alignment: lang.isArabicEffective ? .trailing : .leading)
        }
    }

    private var actionButtons: some View {
        VStack(spacing: NNSpacing.sm) {
            Button(action: accept) {
                Group {
                    if isProcessing {
                        ProgressView().tint(.white)
                    } else {
                        Text(lang.isArabicEffective ? "أوافق وأكون شريكاً" : "Accept & become partner")
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: NNHitTarget.minimum + 4)
                .background(canAccept ? AppColors.accent : AppColors.textDisabled)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
            }
            .buttonStyle(.plain)
            .disabled(!canAccept || isProcessing)

            Button(action: reject) {
                Text(lang.isArabicEffective ? "أرفض الدعوة" : "Decline invitation")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: NNHitTarget.minimum + 4)
                    .background(Color.clear)
                    .foregroundColor(AppColors.alertRed)
                    .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
                    .overlay(
                        RoundedRectangle(cornerRadius: NNRadius.control)
                            .stroke(AppColors.alertRed.opacity(0.4), lineWidth: NNBorder.input)
                    )
            }
            .buttonStyle(.plain)
            .disabled(isProcessing)
        }
    }

    // MARK: - Derived state

    private var canAccept: Bool {
        !partnerDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Proposed name the inviter set (may be empty if the inviter didn't fill
    /// the optional nickname field, or if CloudKit hasn't prefetched the
    /// rootRecord yet).
    private var proposedName: String {
        (metadata.rootRecord?["proposedPartnerName"] as? String) ?? ""
    }

    /// Inviter's display name — read from the rootRecord if CloudKit prefetched
    /// it. May be empty when the share metadata arrives before record fetch
    /// completes; in that case the sheet title falls back to the generic copy.
    private var prefilledInviterName: String {
        (metadata.rootRecord?["ownerDisplayName"] as? String) ?? ""
    }

    // MARK: - Actions

    private func prefillFromMetadata() {
        applyMetadataValues()
        // If CloudKit hadn't prefetched the rootRecord by the time the sheet
        // appeared, both name fields land empty. Retry once after a short
        // delay — by then the record has usually been pulled in by the
        // delivery side-effect, so the user sees the real inviter name
        // instead of a generic "Partner" fallback.
        if prefilledInviterName.isEmpty {
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s
                await MainActor.run { applyMetadataValues() }
            }
        }
    }

    /// Pull whatever the rootRecord currently has into the displayed fields.
    /// Idempotent and safe to re-run after the metadata arrives late.
    private func applyMetadataValues() {
        if inviterName.isEmpty {
            inviterName = prefilledInviterName
        }
        if partnerDisplayName.isEmpty {
            partnerDisplayName = proposedName
        }
    }

    private func accept() {
        let trimmed = partnerDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isProcessing = true
        Task {
            let failureReason = await CloudKitPartnerStore.shared.acceptInvitation(
                metadata: metadata,
                partnerDisplayName: trimmed
            )
            await MainActor.run {
                if let reason = failureReason {
                    // Stay on the sheet so the user sees the error and can
                    // retry. pendingShareMetadata is left intact so a
                    // background recovery (re-tap link, account recovers)
                    // can re-attempt.
                    isProcessing = false
                    errorMessage = reason
                } else {
                    finish()
                }
            }
        }
    }

    private func reject() {
        isProcessing = true
        Task {
            let failureReason = await CloudKitPartnerStore.shared.rejectInvitation(metadata: metadata)
            await MainActor.run {
                if let reason = failureReason {
                    isProcessing = false
                    errorMessage = reason
                } else {
                    finish()
                }
            }
        }
    }

    private func finish() {
        isProcessing = false
        CloudKitPartnerStore.shared.pendingShareMetadata = nil
        onFinished()
        dismiss()
    }
}
