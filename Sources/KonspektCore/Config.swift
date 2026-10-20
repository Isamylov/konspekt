import Foundation

public struct Config: Equatable {
    public var baseURL: URL
    public var apiKey: String
    public var asrModel: String
    public var summaryModel: String
    public var outputDir: URL
    public init(baseURL: URL, apiKey: String, asrModel: String, summaryModel: String, outputDir: URL) {
        fatalError("not implemented (T3)")
    }
    public static func load(envFile: URL) throws -> Config {
        fatalError("not implemented (T3)")
    }
}

public enum ConfigError: Error, Equatable {
    case missing(String), unreadable(String)
}
