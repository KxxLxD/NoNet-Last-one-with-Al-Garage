//
//  PartnerInviteView.swift
//  blocking app
//
//  Two-step partner invitation flow:
//    1. NAME COLLECTION — user enters their own display name (how the partner
//       will see them) plus a suggested nickname for the partner (which the
//       partner can override at accept time). Both are saved to the Partnership
//       CKRecord.
//    2. APPLE SHARE SHEET — wraps UICloudSharingController for delivery via
//       iMessage / Mail / WhatsApp / AirDrop / copy-link.
//
//  Lifecycle: parent presents this as a .sheet. The user either completes the
//  share or backs out — either way `onCompletion` fires so the parent can
//  refresh state and dismiss.
//

import SwiftUI
import CloudKit
import UIKit

struct PartnerInviteView: View {
    let listID: UUID
    let listName: String
    let onCompletion: () -> Void

    @EnvironmentObject var lang: LanguageManager
    @Environment(\.dismiss) private var dismiss

    @State private var ownerDisplayName: String = ""
    @State private var proposedPartnerName: String = ""
    @State private var phase: Phase = .form
    @State private var share: CKShare?
    @State private var errorMessage: String?

    private enum Phase {
        case form        // user filling names
        case creating    // createPartnership in flight
        case sharing     // UICloudSharingController presented
    }

    private var isFormValid: Bool {
        !ownerDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.uiBackground.ignoresSafeArea()
                switch phase {
                case .form:    nameForm
                case .creating: creatingView
                case .sharing:  Color.clear  // share sheet covers this via fullScreenCover
                }
            }
            .navigationTitle(lang.isArabicEffective ? "دعوة شريك" : "Invite Partner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(lang.isArabicEffective ? "إلغاء" : "Cancel") {
                        finish()
                    }
                }
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { phase == .sharing && share != nil },
            set: { if !$0 { finish() } }
        )) {
            if let share = share {
                PartnerShareSheet(
                    share: share,
                    container: CloudKitPartnerStore.shared.container,
                    isArabic: lang.isArabicEffective,
                    onCompletion: { finish() }
                )
                .ignoresSafeArea()
            }
        }
        .alert(
            lang.isArabicEffective ? "تعذّر إنشاء الدعوة" : "Couldn't create invitation",
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button(lang.isArabicEffective ? "حسناً" : "OK", role: .cancel) {
                errorMessage = nil
                phase = .form
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Phase: name form

    private var nameForm: some View {
        ScrollView {
            VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.lg) {
                introBlock

                fieldBlock(
                    title: lang.isArabicEffective ? "اسمك كما تريد ظهوره عند الشريك" : "Your name as the partner will see it",
                    placeholder: lang.isArabicEffective ? "مثال: خالد" : "e.g. Khalid",
                    text: $ownerDisplayName,
                    required: true,
                    helper: lang.isArabicEffective
                        ? "سيظهر هذا الاسم في إشعار كل طلب يستلمه شريكك."
                        : "Shown in every notification your partner receives from you."
                )

                fieldBlock(
                    title: lang.isArabicEffective ? "كيف تريد أن تخاطب شريكك في طلباتك؟" : "How would you like to address your partner?",
                    placeholder: lang.isArabicEffective ? "مثال: أبو محمد" : "e.g. Abu Mohammed",
                    text: $proposedPartnerName,
                    required: false,
                    helper: lang.isArabicEffective
                        ? "اقتراح فقط — يستطيع شريكك تعديله عند القبول."
                        : "Just a suggestion — your partner can edit it on accept."
                )

                Button(action: createInvitation) {
                    Text(lang.isArabicEffective ? "أرسل الدعوة" : "Send invitation")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: NNHitTarget.minimum + 4)
                        .background(isFormValid ? AppColors.accent : AppColors.textDisabled)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
                }
                .buttonStyle(.plain)
                .disabled(!isFormValid)

                Spacer()
            }
            .padding(NNSpacing.lg)
        }
    }

    private var introBlock: some View {
        VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.xs) {
            Image(systemName: "person.2.fill")
                .font(.title)
                .foregroundColor(AppColors.accent)
            Text(lang.isArabicEffective ? "ادعُ شريك تعافي" : "Invite a recovery partner")
                .font(.nnCardTitle)
                .foregroundColor(AppColors.textPrimary)
            Text(lang.isArabicEffective
                 ? "الشريك يستلم رابطاً عبر iMessage أو غيره. عند القبول، يصبح الحارس على هذه القائمة."
                 : "The partner gets a link via iMessage or similar. Once accepted, they become the gatekeeper for this list.")
                .font(.footnote)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)
        }
        .frame(maxWidth: .infinity, alignment: lang.isArabicEffective ? .trailing : .leading)
    }

    @ViewBuilder
    private func fieldBlock(title: String, placeholder: String, text: Binding<String>, required: Bool, helper: String? = nil) -> some View {
        VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.xs) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(AppColors.textPrimary)
                if required {
                    Text("*").foregroundColor(AppColors.alertRed)
                }
            }
            TextField(placeholder, text: text)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled(false)
                .padding(NNSpacing.sm)
                .background(AppColors.uiSurface)
                .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
                .overlay(
                    RoundedRectangle(cornerRadius: NNRadius.control)
                        .stroke(AppColors.uiBorder, lineWidth: NNBorder.input)
                )
                .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)
            if let helper = helper {
                Text(helper)
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: lang.isArabicEffective ? .trailing : .leading)
    }

    // MARK: - Phase: creating

    private var creatingView: some View {
        VStack(spacing: NNSpacing.md) {
            ProgressView()
                .scaleEffect(1.4)
            Text(lang.isArabicEffective ? "جاري إنشاء الدعوة..." : "Creating invitation…")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func createInvitation() {
        let trimmedOwner = ownerDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedProposed = proposedPartnerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedOwner.isEmpty else { return }
        phase = .creating
        Task {
            do {
                let (createdShare, _) = try await CloudKitPartnerStore.shared.createPartnership(
                    ownerDisplayName: trimmedOwner,
                    proposedPartnerName: trimmedProposed.isEmpty ? nil : trimmedProposed,
                    associatedListID: listID
                )
                await MainActor.run {
                    self.share = createdShare
                    self.phase = .sharing
                }
            } catch {
                await MainActor.run {
                    // Roll the phase back immediately so the user sees their
                    // own name form (with values preserved) behind the alert
                    // instead of a stuck spinner. The alert's "OK" button
                    // also flips phase → .form, but only fires after dismiss;
                    // resetting here removes the visual stall.
                    self.phase = .form
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func finish() {
        // Run the parent's callback first so it can read state / refresh, then
        // dismiss this view.
        onCompletion()
        dismiss()
    }
}

/// UIViewControllerRepresentable wrapper around UICloudSharingController.
/// Presented inside PartnerInviteView's fullScreenCover once the CKShare is
/// ready. Previously the top-level `PartnerInviteView` — renamed for clarity
/// when the name-collection step landed in front of it.
struct PartnerShareSheet: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer
    let isArabic: Bool
    let onCompletion: () -> Void

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.delegate = context.coordinator
        controller.availablePermissions = [.allowReadWrite, .allowPrivate]
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(isArabic: isArabic, onCompletion: onCompletion)
    }

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        let isArabic: Bool
        let onCompletion: () -> Void

        init(isArabic: Bool, onCompletion: @escaping () -> Void) {
            self.isArabic = isArabic
            self.onCompletion = onCompletion
        }

        func itemTitle(for csc: UICloudSharingController) -> String? {
            isArabic ? "شريك تعافي NoNet" : "NoNet Recovery Partner"
        }

        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            onCompletion()
        }

        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            onCompletion()
        }

        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            onCompletion()
        }
    }
}
