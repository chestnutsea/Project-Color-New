import Foundation

final class ProgressThrottler {
    private let interval: TimeInterval
    private var lastEmission: Date = .distantPast
    private let syncQueue = DispatchQueue(label: "progress.throttler.queue")
    
    init(interval: TimeInterval) {
        self.interval = interval
    }
    
    func reset() {
        syncQueue.sync {
            lastEmission = .distantPast
        }
    }
    
    func shouldEmit(force: Bool = false) -> Bool {
        if force { return true }
        var should = false
        let now = Date()
        syncQueue.sync {
            if now.timeIntervalSince(lastEmission) >= interval {
                lastEmission = now
                should = true
            }
        }
        return should
    }
}
