import Foundation

public protocol Transcriber {
    func transcribe(wav: Data) async throws -> String
}

public protocol Summarizer {
    func summarize(transcript: String) async throws -> String
}

public protocol HTTPTransport {
    func send(_ r: URLRequest) async throws -> (Data, Int)
}

public enum APIError: Error, Equatable {
    case http(Int, String), transport(String), badResponse
}

public struct URLSessionTransport: HTTPTransport {
    public init(timeout: TimeInterval) {
        fatalError("not implemented (T4)")
    }
    public func send(_ r: URLRequest) async throws -> (Data, Int) {
        fatalError("not implemented (T4)")
    }
}

public struct APIClient: Transcriber, Summarizer {
    public init(config: Config, transport: HTTPTransport) {
        fatalError("not implemented (T4)")
    }
    public static func live(config: Config) -> APIClient {
        fatalError("not implemented (T4)")
    }
    public func transcribe(wav: Data) async throws -> String {
        fatalError("not implemented (T4)")
    }
    public func summarize(transcript: String) async throws -> String {
        fatalError("not implemented (T4)")
    }
}
