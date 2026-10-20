import Foundation

public enum SessionState: String, Codable {
    case recording, recorded, transcribed, done
}

public struct SessionStatus: Codable, Equatable {
    public var state: SessionState
    public var attempts: Int
    public var lastError: String?
    public var start: Date
    public var end: Date?
    public init(state: SessionState, attempts: Int, lastError: String?, start: Date, end: Date?) {
        fatalError("not implemented (T3)")
    }
}

public struct Session {
    public let dir: URL
    public var name: String { fatalError("not implemented (T3)") }
    public var micURL: URL { fatalError("not implemented (T3)") }
    public var callURL: URL { fatalError("not implemented (T3)") }
    public var transcriptURL: URL { fatalError("not implemented (T3)") }
    public var summaryURL: URL { fatalError("not implemented (T3)") }
    public var chunksDir: URL { fatalError("not implemented (T3)") }
    public init(dir: URL) {
        fatalError("not implemented (T3)")
    }
    public func readStatus() throws -> SessionStatus {
        fatalError("not implemented (T3)")
    }
    public func write(_ s: SessionStatus) throws {
        fatalError("not implemented (T3)")
    }
}

public struct SessionStore {
    public let root: URL
    public init(root: URL) {
        fatalError("not implemented (T3)")
    }
    public func create(start: Date) throws -> Session {
        fatalError("not implemented (T3)")
    }
    public func all() -> [Session] {
        fatalError("not implemented (T3)")
    }
    public func pending() -> [Session] {
        fatalError("not implemented (T3)")
    }
}
