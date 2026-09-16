import Foundation

/// A nonempty selection in source seconds. Shared by pointer and keyboard editing.
public struct TrimRange: Equatable, Sendable {
    public let duration: Double
    public private(set) var start: Double
    public private(set) var end: Double
    public var minimumLength: Double { min(0.01, duration) }

    public init(duration: Double, start: Double, end: Double) {
        self.duration = duration.isFinite ? max(0, duration) : 0
        let gap = min(0.01, self.duration)
        self.start = min(max(0, start.isFinite ? start : 0), max(0, self.duration - gap))
        self.end = min(self.duration, max(self.start + gap, end.isFinite ? end : self.duration))
    }

    public mutating func moveStart(to value: Double) {
        guard value.isFinite else { return }
        start = min(max(0, value), max(0, end - minimumLength))
    }

    public mutating func moveEnd(to value: Double) {
        guard value.isFinite else { return }
        end = min(duration, max(start + minimumLength, value))
    }
}
