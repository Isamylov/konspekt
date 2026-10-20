import Foundation

public struct Config: Equatable {
    public var baseURL: URL
    public var apiKey: String
    public var asrModel: String
    public var summaryModel: String
    public var outputDir: URL
    public init(baseURL: URL, apiKey: String, asrModel: String, summaryModel: String, outputDir: URL) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.asrModel = asrModel
        self.summaryModel = summaryModel
        self.outputDir = outputDir
    }

    public static func load(envFile: URL) throws -> Config {
        guard let text = try? String(contentsOf: envFile, encoding: .utf8) else {
            throw ConfigError.unreadable(envFile.path)
        }
        var env: [String: String] = [:]
        for raw in text.components(separatedBy: .newlines) {
            var line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            if line.hasPrefix("export ") { line = String(line.dropFirst(7)) }
            guard let eq = line.firstIndex(of: "=") else { continue }
            let key = line[..<eq].trimmingCharacters(in: .whitespaces)
            var value = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
            if value.count >= 2, let f = value.first, f == value.last, f == "\"" || f == "'" {
                value = String(value.dropFirst().dropLast())
            }
            env[key] = value
        }
        func need(_ k: String) throws -> String {
            guard let v = env[k], !v.isEmpty else { throw ConfigError.missing(k) }
            return v
        }
        let base = try need("OPENAI_BASE_URL")
        let key = try need("OPENAI_API_KEY")
        let asr = try need("OPENAI_MODEL_NAME")
        guard let url = URL(string: base) else { throw ConfigError.missing("OPENAI_BASE_URL") }
        let home = FileManager.default.homeDirectoryForCurrentUser
        var out = home.appendingPathComponent("Documents/Konspekt")
        if let d = env["KONSPEKT_DIR"], !d.isEmpty {
            if d == "~" { out = home }
            else if d.hasPrefix("~/") { out = home.appendingPathComponent(String(d.dropFirst(2))) }
            else { out = URL(fileURLWithPath: d) }
        }
        let sm = env["SUMMARY_MODEL_NAME"].flatMap { $0.isEmpty ? nil : $0 } ?? "qwen-3.8-27b"
        return Config(baseURL: url, apiKey: key, asrModel: asr, summaryModel: sm, outputDir: out)
    }
}

public enum ConfigError: Error, Equatable {
    case missing(String), unreadable(String)
}
