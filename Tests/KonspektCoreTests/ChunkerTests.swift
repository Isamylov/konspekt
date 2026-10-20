import Testing
@testable import KonspektCore

struct LCG {
    var s: UInt64
    mutating func next() -> Float {
        s = s &* 6364136223846793005 &+ 1442695040888963407
        return Float(Int64(bitPattern: s >> 11) % 2001) / 1000.0 - 1.0
    }
}

@Suite struct ChunkerTests {
    let rate = 16000

    @Test func test_empty() {
        #expect(Chunker.ranges(samples: [], rate: rate).isEmpty)
    }

    @Test func test_short_single() {
        let r = Chunker.ranges(samples: [Float](repeating: 0, count: 100 * rate), rate: rate)
        #expect(r == [0..<1_600_000])
    }

    @Test func test_tail_exactly_max() {
        let r = Chunker.ranges(samples: [Float](repeating: 0, count: 120 * rate), rate: rate)
        #expect(r == [0..<1_920_000])
    }

    @Test func test_300s_zeros() {
        let r = Chunker.ranges(samples: [Float](repeating: 0, count: 300 * rate), rate: rate)
        #expect(r.count == 3)
        #expect(r.first!.lowerBound == 0 && r.last!.upperBound == 4_800_000)
        #expect(r.allSatisfy { $0.count <= 1_920_000 })
        for i in 1..<r.count { #expect(r[i].lowerBound == r[i - 1].upperBound) }
    }

    @Test func test_cut_at_quiet_window() {
        var g = LCG(s: 1)
        var s = (0..<(130 * rate)).map { _ in g.next() >= 0 ? Float(0.5) : Float(-0.5) }
        for i in (110 * rate)..<(110 * rate + rate / 2) { s[i] = 0 }
        let r = Chunker.ranges(samples: s, rate: rate)
        #expect(r.count == 2)
        #expect(abs(r[0].upperBound - Int(110.25 * Double(rate))) <= 8000)
    }

    @Test func test_contiguous_no_gaps() {
        var g = LCG(s: 42)
        let s = (0..<(1000 * rate)).map { _ in g.next() }
        let r = Chunker.ranges(samples: s, rate: rate)
        #expect(r.first!.lowerBound == 0)
        #expect(r.last!.upperBound == s.count)
        #expect(r.allSatisfy { $0.count <= 120 * rate && $0.count > 0 })
        for i in 1..<r.count { #expect(r[i].lowerBound == r[i - 1].upperBound) }
    }
}
