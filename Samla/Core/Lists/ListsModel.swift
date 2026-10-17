import Foundation
import Observation

/// Single source of truth for block lists. Every mutation is persisted to the App Group
/// and immediately pushed to Screen Time, the wake scheduler and notifications.
@Observable
final class ListsModel {
    static let freeListLimit = 3
    /// Longest "Block Now" duration per protection level.
    static let maxHardModeDays = 30
    static let maxDays = 360

    private(set) var lists: [BlockList]
    /// The list the big Home button starts.
    private(set) var lastUsedListID: UUID?

    private let notifications: NotificationService
    private let defaults: UserDefaults
    private enum Key {
        static let lastUsedList = "home.lastUsedListID"
    }

    init(notifications: NotificationService, defaults: UserDefaults = .standard) {
        self.notifications = notifications
        self.defaults = defaults
        lists = BlockListRepository.load()
        lastUsedListID = defaults.string(forKey: Key.lastUsedList).flatMap(UUID.init(uuidString:))
    }

    func list(withID id: UUID) -> BlockList? {
        lists.first { $0.id == id }
    }

    /// Protected lists first, then newest first.
    func sorted(_ items: [BlockList]) -> [BlockList] {
        items.sorted { lhs, rhs in
            let lhsProtected = lhs.protection != .none
            let rhsProtected = rhs.protection != .none
            if lhsProtected != rhsProtected { return lhsProtected }
            return lhs.createdAt > rhs.createdAt
        }
    }

    /// "Block Now" lists the big Home button can start.
    var startableLists: [BlockList] {
        sorted(lists.filter { $0.kind == .now })
    }

    /// The list the big Home button starts: last used, otherwise the newest startable one.
    var quickStartList: BlockList? {
        if let id = lastUsedListID, let list = list(withID: id), list.kind == .now { return list }
        return startableLists.first
    }

    func setQuickStartList(_ id: UUID) {
        lastUsedListID = id
        defaults.set(id.uuidString, forKey: Key.lastUsedList)
    }

    static func maxDays(for protection: ProtectionMode) -> Int {
        protection == .hard ? maxHardModeDays : maxDays
    }

    // MARK: - Limits

    /// The free version holds 3 lists; a 4th opens the "Premium coming soon" page.
    func canCreateList(isPremium: Bool) -> Bool {
        isPremium || lists.count < Self.freeListLimit
    }

    /// Appends " (2)", " (3)"… when another list already uses the name.
    func uniqueName(for base: String, excluding id: UUID? = nil) -> String {
        let trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? String(localized: "New List") : trimmed
        func taken(_ candidate: String) -> Bool {
            lists.contains { $0.id != id && $0.name.caseInsensitiveCompare(candidate) == .orderedSame }
        }
        guard taken(name) else { return name }
        var index = 2
        while taken("\(name) (\(index))") { index += 1 }
        return "\(name) (\(index))"
    }

    // MARK: - Permissions

    /// Whether a list may be stopped, edited or deleted right now.
    /// Partner-protected lists need `partnerApproved` (the partner entered their PIN).
    func canModify(_ list: BlockList, partnerApproved: Bool = false, now: Date = .now) -> Bool {
        guard list.isActive(at: now) else { return true }
        switch list.protection {
        case .none: return true
        case .hard: return false
        case .partner: return partnerApproved
        }
    }

    // MARK: - CRUD

    func create(_ list: BlockList, startNow: Bool, now: Date = .now) {
        var list = sanitized(list)
        list.name = uniqueName(for: list.name)
        list.createdAt = now
        list.updatedAt = now
        // Protected "Block Now" lists always start right away: that's the commitment.
        if list.kind == .now && (startNow || list.protection != .none) {
            let session = DateInterval(start: now, duration: TimeInterval(list.durationSeconds))
            list.session = session
        }
        if list.kind == .now { setQuickStartList(list.id) }
        lists.append(list)
        commit()
    }

    func update(_ list: BlockList, partnerApproved: Bool = false, now: Date = .now) {
        guard let index = lists.firstIndex(where: { $0.id == list.id }),
              canModify(lists[index], partnerApproved: partnerApproved, now: now) else { return }
        let edited = sanitized(list)
        // Copy only the configuration; runtime state (session, breaks) may have changed
        // while the editor was open and must not be overwritten with a stale copy.
        var updated = lists[index]
        updated.name = uniqueName(for: edited.name, excluding: edited.id)
        updated.protection = edited.protection
        updated.kind = edited.kind
        updated.durationSeconds = edited.durationSeconds
        updated.slots = edited.slots
        updated.websites = edited.websites
        updated.selection = edited.selection
        updated.blockAdultContent = edited.blockAdultContent
        updated.blocksEverything = edited.blocksEverything
        updated.allowedSelection = edited.allowedSelection
        updated.breaks = edited.breaks
        updated.updatedAt = now
        if updated.kind == .scheduled { updated.session = nil }
        lists[index] = updated
        commit()
    }

    func delete(_ id: UUID, partnerApproved: Bool = false, now: Date = .now) {
        guard let list = list(withID: id), canModify(list, partnerApproved: partnerApproved, now: now) else { return }
        lists.removeAll { $0.id == id }
        if lastUsedListID == id {
            lastUsedListID = nil
            defaults.removeObject(forKey: Key.lastUsedList)
        }
        commit()
    }

    /// Removes every list that isn't currently locked.
    func deleteAllUnlocked(now: Date = .now) {
        lists.removeAll { !$0.isLocked(at: now) }
        commit()
    }

    // MARK: - Sessions & breaks

    func start(_ id: UUID, now: Date = .now) {
        setQuickStartList(id)
        mutate(id) { list in
            guard list.kind == .now, !list.isActive(at: now) else { return }
            list.session = DateInterval(start: now, duration: TimeInterval(list.durationSeconds))
            list.breakUntil = nil
        }
    }

    func stop(_ id: UUID, partnerApproved: Bool = false, now: Date = .now) {
        guard let current = list(withID: id), canModify(current, partnerApproved: partnerApproved, now: now) else { return }
        mutate(id) { list in
            guard list.kind == .now, list.session != nil else { return }
            list.session = nil
            list.breakUntil = nil
        }
    }

    func takeBreak(_ id: UUID, now: Date = .now) {
        mutate(id) { list in
            guard list.isActive(at: now), !list.isOnBreak(at: now), list.breaksRemaining(at: now) > 0 else { return }
            list.breakUntil = now.addingTimeInterval(TimeInterval(list.breaks.minutes * 60))
            list.breakStarts.append(now)
        }
    }

    func endBreak(_ id: UUID) {
        mutate(id) { $0.breakUntil = nil }
    }

    /// "Skip Today": turns an unprotected scheduled list off until its current window ends.
    func skipToday(_ id: UUID, now: Date = .now) {
        mutate(id) { list in
            guard list.kind == .scheduled, list.protection == .none, let end = list.activeUntil(at: now) else { return }
            list.skippedUntil = end
            list.breakUntil = nil
        }
    }

    func resumeSchedule(_ id: UUID) {
        mutate(id) { $0.skippedUntil = nil }
    }

    // MARK: - System sync

    /// Re-applies shields and schedules. Call on launch and whenever the app becomes active.
    /// Picks up breaks started from the block screen by the shield-action extension.
    func reloadFromDisk() {
        lists = BlockListRepository.load()
    }

    func refreshSystemState(now: Date = .now) {
        let forever = ForeverBlockRepository.load()
        ShieldEngine.apply(lists, forever: forever, at: now)
        WakeScheduler.reschedule(lists, forever: forever, now: now)
        notifications.reschedule(for: lists, now: now)
    }

    /// Enforces protection-specific rules regardless of what the editor sent.
    private func sanitized(_ list: BlockList) -> BlockList {
        var list = list
        let maxSeconds = Self.maxDays(for: list.protection) * 86_400
        list.durationSeconds = min(list.durationSeconds, maxSeconds)
        if list.isHard { list.breaks.count = 0 }
        return list
    }

    private func mutate(_ id: UUID, _ change: (inout BlockList) -> Void) {
        guard let index = lists.firstIndex(where: { $0.id == id }) else { return }
        change(&lists[index])
        commit()
    }

    private func commit() {
        BlockListRepository.save(lists)
        refreshSystemState()
    }
}
