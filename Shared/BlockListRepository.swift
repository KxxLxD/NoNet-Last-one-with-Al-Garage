import Foundation
import os

/// Reads and writes block lists as a single JSON file in the App Group container.
enum BlockListRepository {
    private static let logger = Logger(subsystem: "com.databox.nonet", category: "Repository")

    static var fileURL: URL {
        AppGroup.containerURL.appendingPathComponent("block-lists.json")
    }

    static func load() -> [BlockList] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        do {
            return try JSONDecoder().decode([BlockList].self, from: data)
        } catch {
            logger.error("Failed to decode block lists: \(error.localizedDescription)")
            return []
        }
    }

    static func save(_ lists: [BlockList]) {
        do {
            let data = try JSONEncoder().encode(lists)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            logger.error("Failed to save block lists: \(error.localizedDescription)")
        }
    }

    static func deleteAll() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
