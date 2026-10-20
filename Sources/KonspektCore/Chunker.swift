import Foundation

public enum Chunker {
    public static func ranges(samples: [Float], rate: Int, maxSec: Double = 120, searchSec: Double = 20) -> [Range<Int>] {
        let n = samples.count
        let maxLen = Int(maxSec * Double(rate))
        guard n > 0, maxLen > 0 else { return [] }
        let win = max(1, rate / 2)
        let step = max(1, rate / 10)
        let searchLen = Int(searchSec * Double(rate))

        var out: [Range<Int>] = []
        var start = 0
        while n - start > maxLen {
            let lo = start + max(0, maxLen - searchLen)
            let hi = start + maxLen
            var bestCut = hi
            var best = Double.infinity
            // local prefix sums over the search region only
            var prefix = [Double](repeating: 0, count: hi - lo + 1)
            for i in lo..<hi { prefix[i - lo + 1] = prefix[i - lo] + Double(samples[i]) * Double(samples[i]) }
            var w = lo
            while w + win <= hi {
                let e = prefix[w + win - lo] - prefix[w - lo]
                if e < best { best = e; bestCut = w + win / 2 }
                w += step
            }
            if bestCut <= start { bestCut = hi }
            out.append(start..<bestCut)
            start = bestCut
        }
        out.append(start..<n)
        return out
    }
}
