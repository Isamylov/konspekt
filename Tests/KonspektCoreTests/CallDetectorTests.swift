import Testing
import Foundation
@testable import KonspektCore

@Suite struct CallDetectorTests {
    let t0 = Date(timeIntervalSince1970: 1_000_000)
    let on = AudioState(running: true, input: true, output: true)
    let off = AudioState(running: true, input: false, output: false)
    let quit = AudioState(running: false, input: false, output: false)

    @Test func test_starts_on_active() {
        var d = CallDetector(grace: 8)
        #expect(d.feed(on, at: t0) == .started(t0))
    }

    @Test func test_flap_resets_grace() {
        var d = CallDetector(grace: 8)
        _ = d.feed(on, at: t0)
        #expect(d.feed(off, at: t0 + 10) == nil)
        #expect(d.feed(on, at: t0 + 15) == nil)
        #expect(d.feed(off, at: t0 + 20) == nil)
        #expect(d.feed(off, at: t0 + 27) == nil)
        #expect(d.feed(off, at: t0 + 28) == .ended(t0 + 20))
    }

    @Test func test_no_double_start() {
        var d = CallDetector(grace: 8)
        #expect(d.feed(on, at: t0) == .started(t0))
        #expect(d.feed(on, at: t0 + 1) == nil)
    }

    @Test func test_input_only_counts() {
        var d = CallDetector(grace: 8)
        let s = AudioState(running: true, input: true, output: false)
        #expect(d.feed(s, at: t0) == .started(t0))
    }

    @Test func test_idle_running_never_starts() {
        var d = CallDetector(grace: 8)
        #expect(d.feed(off, at: t0) == nil)
        #expect(d.feed(off, at: t0 + 30) == nil)
    }

    @Test func test_grace_end() {
        var d = CallDetector(grace: 8)
        _ = d.feed(on, at: t0)
        #expect(d.feed(off, at: t0 + 10) == nil)
        #expect(d.feed(off, at: t0 + 18) == .ended(t0 + 10))
        #expect(d.feed(off, at: t0 + 19) == nil)
    }

    @Test func test_quit_ends_immediately() {
        var d = CallDetector(grace: 8)
        _ = d.feed(on, at: t0)
        #expect(d.feed(quit, at: t0 + 5) == .ended(t0 + 5))
    }
}
