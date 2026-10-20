import Testing
import Foundation
@testable import KonspektCore

final class FakeTransport: HTTPTransport, @unchecked Sendable {
    var requests: [URLRequest] = []
    var result: Result<(Data, Int), Error>
    init(_ body: String, _ status: Int = 200) { result = .success((Data(body.utf8), status)) }
    init(error: Error) { result = .failure(error) }
    func send(_ r: URLRequest) async throws -> (Data, Int) {
        requests.append(r)
        return try result.get()
    }
}

func makeClient(_ t: FakeTransport) -> APIClient {
    let cfg = Config(baseURL: URL(string: "https://h/v1")!, apiKey: "k", asrModel: "asr",
                     summaryModel: "sum", outputDir: URL(fileURLWithPath: "/tmp/x"))
    return APIClient(config: cfg, transport: t)
}

@Suite struct APIClientTests {
    @Test func test_transcribe_cyrillic() async throws {
        let t = FakeTransport(#"{"text":"привет","usage":{}}"#)
        #expect(try await makeClient(t).transcribe(wav: Data([1])) == "привет")
    }

    @Test func test_multipart_shape() async throws {
        let t = FakeTransport(#"{"text":"x"}"#)
        _ = try await makeClient(t).transcribe(wav: Data([1, 2, 3]))
        let r = t.requests[0]
        #expect(r.url?.absoluteString == "https://h/v1/audio/transcriptions")
        #expect(r.httpMethod == "POST")
        #expect(r.value(forHTTPHeaderField: "Authorization") == "Bearer k")
        let ct = r.value(forHTTPHeaderField: "Content-Type") ?? ""
        #expect(ct.hasPrefix("multipart/form-data; boundary="))
        let body = String(decoding: r.httpBody ?? Data(), as: UTF8.self)
        #expect(body.contains("name=\"model\"\r\n\r\nasr\r\n"))
        #expect(body.contains("name=\"file\"; filename=\"audio.wav\""))
        #expect(body.contains("Content-Type: audio/wav"))
        let boundary = String(ct.dropFirst("multipart/form-data; boundary=".count))
        #expect(body.hasSuffix("--\(boundary)--\r\n"))
    }

    @Test func test_summarize_cyrillic() async throws {
        let t = FakeTransport(##"{"choices":[{"message":{"content":"# Итоги","reasoning_content":"r"}}]}"##)
        #expect(try await makeClient(t).summarize(transcript: "т") == "# Итоги")
    }

    @Test func test_chat_body() async throws {
        let t = FakeTransport(#"{"choices":[{"message":{"content":"ok"}}]}"#)
        _ = try await makeClient(t).summarize(transcript: "Привет, мир")
        let r = t.requests[0]
        #expect(r.url?.absoluteString == "https://h/v1/chat/completions")
        #expect(r.value(forHTTPHeaderField: "Authorization") == "Bearer k")
        #expect(r.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let j = try #require(JSONSerialization.jsonObject(with: r.httpBody!) as? [String: Any])
        #expect(j["model"] as? String == "sum")
        #expect(j["max_tokens"] as? Int == 4000)
        #expect(j["temperature"] as? Double == 0.3)
        let msgs = try #require(j["messages"] as? [[String: String]])
        #expect(msgs[0]["role"] == "system")
        for s in ["Кратко", "Решения", "Задачи", "Открытые вопросы"] {
            #expect(msgs[0]["content"]!.contains(s))
        }
        #expect(msgs[1]["role"] == "user")
        #expect(msgs[1]["content"] == "Привет, мир")
    }

    @Test func test_missing_text_field() async {
        let t = FakeTransport("{}")
        await #expect(throws: APIError.badResponse) { try await makeClient(t).transcribe(wav: Data()) }
        let t2 = FakeTransport(#"{"choices":[]}"#)
        await #expect(throws: APIError.badResponse) { try await makeClient(t2).summarize(transcript: "a") }
    }

    @Test func test_http_error() async {
        let t = FakeTransport("bad gateway", 502)
        await #expect(throws: APIError.http(502, "bad gateway")) { try await makeClient(t).transcribe(wav: Data()) }
    }

    @Test func test_http_error_truncated() async {
        let t = FakeTransport(String(repeating: "я", count: 600), 500)
        do { _ = try await makeClient(t).summarize(transcript: "a"); Issue.record("no throw") }
        catch APIError.http(let c, let m) { #expect(c == 500); #expect(m.count == 500) }
        catch { Issue.record("wrong error") }
    }

    @Test func test_transport_error_wrapped() async {
        let t = FakeTransport(error: URLError(.notConnectedToInternet))
        do { _ = try await makeClient(t).transcribe(wav: Data()); Issue.record("no throw") }
        catch APIError.transport(let m) { #expect(!m.contains("k\"")) }
        catch { Issue.record("wrong error \(error)") }
    }
}

@Suite struct APIKeyRedactionTests {
    @Test func test_key_redacted_in_http_error() async {
        let t = FakeTransport("Incorrect API key: secret-key-123", 401)
        let cfg = Config(baseURL: URL(string: "https://h/v1")!, apiKey: "secret-key-123", asrModel: "a",
                         summaryModel: "s", outputDir: URL(fileURLWithPath: "/tmp/x"))
        do { _ = try await APIClient(config: cfg, transport: t).transcribe(wav: Data()); Issue.record("no throw") }
        catch APIError.http(_, let m) { #expect(!m.contains("secret-key-123")) }
        catch { Issue.record("wrong error") }
    }
}
