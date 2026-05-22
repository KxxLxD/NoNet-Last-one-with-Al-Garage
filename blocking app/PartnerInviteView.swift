//
//  PartnerInviteView.swift
//  blocking app
//
//  SwiftUI wrapper around UICloudSharingController. The controller is Apple's
//  out-of-the-box share sheet for CKShare: it gives the user iMessage, Mail,
//  AirDrop, and "copy link" options for delivering the invitation.
//
//  Lifecycle: the parent presents this as a .sheet. Tapping any send option
//  (or dismissing) triggers onCompletion so the parent can refresh state.
//

import SwiftUI
import CloudKit
import UIKit

struct PartnerInviteView: UIViewControllerRepresentable {
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

        // Shown in the recipient's invitation as the share title.
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
