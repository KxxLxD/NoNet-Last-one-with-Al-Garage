//
//  CoreDataExtensions.swift
//  blocking app
//
//  Centralized Core Data save error handling.
//

import CoreData
import os

private let coreDataLog = Logger(subsystem: "app.nonet.blocking", category: "CoreData")

extension NSManagedObjectContext {
    /// Save the context if it has changes, returning a Result so callers can surface errors.
    /// - Returns: `.success` when nothing to save or save succeeded; `.failure` with the underlying error otherwise.
    @discardableResult
    func saveIfNeeded(file: String = #fileID, line: Int = #line) -> Result<Void, Error> {
        guard hasChanges else { return .success(()) }
        do {
            try save()
            return .success(())
        } catch {
            coreDataLog.error("Core Data save failed at \(file, privacy: .public):\(line) — \(error.localizedDescription, privacy: .public)")
            return .failure(error)
        }
    }
}
