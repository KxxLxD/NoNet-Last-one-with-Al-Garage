import Foundation
import Observation

/// App-side state for Block Forever. Every change is saved to the App Group and then
/// `onChange` re-applies Screen Time settings (wired to `ListsModel.refreshSystemState`).
@Observable
final class ForeverStore {
    private(set) var block: ForeverBlock
    private let onChange: () -> Void

    init(onChange: @escaping () -> Void = {}) {
        self.onChange = onChange
        block = ForeverBlockRepository.load()
    }

    func isActive(at date: Date = .now) -> Bool {
        block.isActive(at: date)
    }

    var isUnlockRequested: Bool { block.unlockRequestedAt != nil }

    /// Whole days left until an unlock request completes (rounded up).
    func daysUntilUnlock(now: Date = .now) -> Int? {
        guard let unlockDate = block.unlockDate else { return nil }
        return max(0, Int((unlockDate.timeIntervalSince(now) / 86_400).rounded(.up)))
    }

    func enable(blocksMatureApps: Bool, now: Date = .now) {
        block = ForeverBlock(isEnabled: true, enabledAt: now, blocksMatureApps: blocksMatureApps, unlockRequestedAt: nil)
        commit()
    }

    /// Starts the 360-day wait. Protection stays fully on until it ends.
    func requestUnlock(now: Date = .now) {
        guard block.isEnabled, block.unlockRequestedAt == nil else { return }
        block.unlockRequestedAt = now
        commit()
    }

    func cancelUnlockRequest() {
        block.unlockRequestedAt = nil
        commit()
    }

    /// Turns protection off right away. Only after the partner entered their PIN.
    func disable() {
        block = ForeverBlock()
        commit()
    }

    /// Clears the block once the 360-day wait has passed. Call whenever the app becomes active.
    func refresh(now: Date = .now) {
        block = ForeverBlockRepository.load()
        if block.isEnabled, !block.isActive(at: now) {
            disable()
        }
    }

    private func commit() {
        ForeverBlockRepository.save(block)
        onChange()
    }
}
