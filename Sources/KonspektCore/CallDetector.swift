import Foundation

public struct AudioState: Equatable {
    public var running, input, output: Bool
    public init(running: Bool, input: Bool, output: Bool) {
        fatalError("not implemented (T1)")
    }
}

public enum CallEvent: Equatable {
    case started(Date), ended(Date)
}

public struct CallDetector {
    public init(grace: TimeInterval = 8) {
        fatalError("not implemented (T1)")
    }
    public mutating func feed(_ s: AudioState, at t: Date) -> CallEvent? {
        fatalError("not implemented (T1)")
    }
}
