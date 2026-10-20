import Foundation

public struct AudioState: Equatable {
    public var running, input, output: Bool
    public init(running: Bool, input: Bool, output: Bool) {
        self.running = running; self.input = input; self.output = output
    }
}

public enum CallEvent: Equatable {
    case started(Date), ended(Date)
}

public struct CallDetector {
    private let grace: TimeInterval
    private var inCall = false
    private var inactiveSince: Date?

    public init(grace: TimeInterval = 8) {
        self.grace = grace
    }

    public mutating func feed(_ s: AudioState, at t: Date) -> CallEvent? {
        let active = s.running && (s.input || s.output)
        if !inCall {
            guard active else { return nil }
            inCall = true
            inactiveSince = nil
            return .started(t)
        }
        if active {
            inactiveSince = nil
            return nil
        }
        let since = inactiveSince ?? t
        inactiveSince = since
        if !s.running {
            inCall = false
            inactiveSince = nil
            return .ended(t)
        }
        if t.timeIntervalSince(since) >= grace {
            inCall = false
            inactiveSince = nil
            return .ended(since)
        }
        return nil
    }
}
