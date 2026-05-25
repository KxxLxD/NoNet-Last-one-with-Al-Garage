//
//  ApprovalExecutor.swift
//  blocking app
//
//  Acts on partner approvals once they arrive. AppDelegate's CloudKit push
//  handler invokes this on every remote-notification delivery — it scans
//  myOutgoingRequests for any that flipped from .pending to .approved and
//  performs the corresponding local action (delete / disable / modify), then
//  marks the request .completed so we don't re-run it on the next push.
//
//  Lives outside the View layer so the same code path runs whether the user
//  has the app open, has it in the background, or relaunches after the push.
//

import Foundation
import CoreData
import os

private let log = Logger(subsystem: "app.nonet.blocking", category: "ApprovalExecutor")

@MainActor
enum ApprovalExecutor {
    /// Refresh outgoing requests from CloudKit, then run any .approved actions.
    /// Idempotent: requests already executed have status == .completed and are
    /// skipped on subsequent calls.
    static func executePendingApprovals() async {
        let store = CloudKitPartnerStore.shared
        await store.fetchMyOutgoingRequests()
        for request in store.myOutgoingRequests where request.status == .approved {
            execute(request: request)
            await store.markRequestCompleted(request.id)
        }
    }

    private static func execute(request: BreakAttempt) {
        let context = CoreDataStack.shared.viewContext
        let fetch: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        fetch.predicate = NSPredicate(format: "id == %@", request.listID as CVarArg)
        fetch.fetchLimit = 1
        guard let entity = (try? context.fetch(fetch))?.first else {
            log.error("execute: list \(request.listID, privacy: .public) not found locally; skipping")
            return
        }
        switch request.type {
        case .delete:
            BlockingEngine.shared.purge(listId: entity.id)
            context.delete(entity)
            _ = context.saveIfNeeded()
            BreaksStore.clear(for: entity.id)
            ManualStateStore.clear(for: entity.id)
            EmergencyUnlockStore.clear(for: entity.id)
            log.notice("executed .delete for \(request.listID, privacy: .public)")
        case .disable:
            _ = BlockingEngine.shared.deactivate(list: entity, force: true)
            ManualStateStore.clear(for: entity.id)
            log.notice("executed .disable for \(request.listID, privacy: .public)")
        case .modify:
            // .modify just opens the editor — there's no automatic mutation
            // we can perform. The user is expected to open the list and edit
            // the items themselves; marking the request completed clears
            // the "pending partner approval" badge.
            log.notice("approved .modify for \(request.listID, privacy: .public) — user can now open editor")
        case .uninstallAttempt:
            // Not auto-actionable — log only.
            log.notice("approved .uninstallAttempt for \(request.listID, privacy: .public) — no-op")
        }
    }
}
