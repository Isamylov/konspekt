import Foundation

public struct Pipeline {
    let transcriber: Transcriber
    let summarizer: Summarizer

    public init(transcriber: Transcriber, summarizer: Summarizer) {
        self.transcriber = transcriber
        self.summarizer = summarizer
    }

    public func process(_ s: Session) async -> SessionStatus {
        var status: SessionStatus
        do { status = try s.readStatus() } catch {
            return SessionStatus(state: .recording, attempts: 0, lastError: "\(error)", start: Date(), end: nil)
        }
        do {
            if status.state == .recorded {
                try await transcribe(s)
                status.state = .transcribed
                status.lastError = nil
                try s.write(status)
            }
            if status.state == .transcribed {
                try await summarize(s, status)
                status.state = .done
                status.lastError = nil
                try s.write(status)
            }
        } catch {
            status.attempts += 1
            status.lastError = "\(error)"
            try? s.write(status)
        }
        return status
    }

    private func transcribe(_ s: Session) async throws {
        let rate = 16000
        let samples = try AudioMixer.mixToMono16k([s.micURL, s.callURL])
        let fm = FileManager.default
        try fm.createDirectory(at: s.chunksDir, withIntermediateDirectories: true)
        var out = ""
        for (i, r) in Chunker.ranges(samples: samples, rate: rate).enumerated() {
            let file = s.chunksDir.appendingPathComponent(String(format: "%03d.txt", i))
            let text: String
            if let cached = try? String(contentsOf: file, encoding: .utf8) {
                text = cached
            } else {
                text = try await transcriber.transcribe(wav: AudioMixer.wav16k(samples[r]))
                try text.write(to: file, atomically: true, encoding: .utf8)
            }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                out += "## [\(stamp(r.lowerBound / rate))]\n\n\(trimmed)\n\n"
            }
        }
        try out.write(to: s.transcriptURL, atomically: true, encoding: .utf8)
    }

    private func summarize(_ s: Session, _ status: SessionStatus) async throws {
        let transcript = try String(contentsOf: s.transcriptURL, encoding: .utf8)
        if transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            try "Речь не распознана".write(to: s.summaryURL, atomically: true, encoding: .utf8)
            return
        }
        let body = try await summarizer.summarize(transcript: transcript)
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm"
        var out = "# Конспект звонка \(f.string(from: status.start))\n"
        if let end = status.end {
            out += "Длительность: \(max(1, Int((end.timeIntervalSince(status.start) / 60).rounded()))) мин\n"
        } else {
            out += "Длительность: неизвестна\n"
        }
        out += "\n\(body)\n"
        try out.write(to: s.summaryURL, atomically: true, encoding: .utf8)
    }

    private func stamp(_ sec: Int) -> String {
        sec >= 3600
            ? String(format: "%02d:%02d:%02d", sec / 3600, sec % 3600 / 60, sec % 60)
            : String(format: "%02d:%02d", sec / 60, sec % 60)
    }
}
