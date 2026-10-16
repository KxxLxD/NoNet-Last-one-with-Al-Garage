import DeviceActivity
import Foundation

/// Woken by the system at schedule boundaries (scheduled slots, session ends, break ends).
/// Each wake simply re-evaluates every list against the current time, so the result is
/// always correct regardless of which boundary triggered it.
final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        ShieldEngine.apply(BlockListRepository.load())
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        ShieldEngine.apply(BlockListRepository.load())
    }
}
