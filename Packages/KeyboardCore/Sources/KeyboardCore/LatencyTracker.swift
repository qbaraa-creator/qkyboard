import Foundation

/// Rolling window of key → insertion latencies, for the TS-01 target of P95 ≤ 50 ms (PRD §38).
public struct LatencyTracker: Sendable {
    public private(set) var samples: [Double] = []
    public let capacity: Int
    private var next = 0
    public private(set) var totalCount = 0

    public init(capacity: Int = 300) {
        self.capacity = capacity
        samples.reserveCapacity(capacity)
    }

    public mutating func record(milliseconds: Double) {
        guard milliseconds.isFinite, milliseconds >= 0 else { return }
        if samples.count < capacity {
            samples.append(milliseconds)
        } else {
            samples[next] = milliseconds
        }
        next = (next + 1) % capacity
        totalCount += 1
    }

    /// Nearest-rank percentile, `p` in 0...100.
    public func percentile(_ p: Double) -> Double? {
        guard !samples.isEmpty else { return nil }
        let sorted = samples.sorted()
        let rank = Int((p / 100 * Double(sorted.count)).rounded(.up))
        return sorted[min(max(rank, 1), sorted.count) - 1]
    }
}
