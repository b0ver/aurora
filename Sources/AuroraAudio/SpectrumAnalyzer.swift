import Foundation
import Accelerate

/// Real-FFT magnitude spectrum + log-spaced band grouping, via vDSP.
/// Pure and deterministic — testable with a synthetic signal.
public final class SpectrumAnalyzer {
    private let n: Int
    private let halfN: Int
    private let log2n: vDSP_Length
    private let fftSetup: FFTSetup
    private var window: [Float]

    public init(size: Int = 1024) {
        precondition(size > 0 && (size & (size - 1)) == 0, "FFT size must be a power of two")
        self.n = size
        self.halfN = size / 2
        self.log2n = vDSP_Length(log2(Double(size)))
        self.fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
        self.window = [Float](repeating: 0, count: size)
        vDSP_hann_window(&window, vDSP_Length(size), Int32(vDSP_HANN_NORM))
    }

    deinit { vDSP_destroy_fftsetup(fftSetup) }

    /// Magnitude spectrum (`halfN` bins) for up to `n` samples (windowed).
    public func magnitudes(_ samples: [Float]) -> [Float] {
        var input = [Float](repeating: 0, count: n)
        let count = min(samples.count, n)
        if count > 0 { input.replaceSubrange(0..<count, with: samples[0..<count]) }

        var windowed = [Float](repeating: 0, count: n)
        vDSP_vmul(input, 1, window, 1, &windowed, 1, vDSP_Length(n))

        var realp = [Float](repeating: 0, count: halfN)
        var imagp = [Float](repeating: 0, count: halfN)
        var mags = [Float](repeating: 0, count: halfN)

        realp.withUnsafeMutableBufferPointer { rp in
            imagp.withUnsafeMutableBufferPointer { ip in
                var split = DSPSplitComplex(realp: rp.baseAddress!, imagp: ip.baseAddress!)
                windowed.withUnsafeBufferPointer { wp in
                    wp.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfN) { cplx in
                        vDSP_ctoz(cplx, 2, &split, 1, vDSP_Length(halfN))
                    }
                }
                vDSP_fft_zrip(fftSetup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                vDSP_zvmags(&split, 1, &mags, 1, vDSP_Length(halfN))
            }
        }

        var result = [Float](repeating: 0, count: halfN)
        var c = Int32(halfN)
        vvsqrtf(&result, mags, &c)
        // vDSP_fft_zrip is unnormalized; scale roughly to [0, ~1] for typical signals.
        var scale = Float(1.0 / Float(n))
        vDSP_vsmul(result, 1, &scale, &result, 1, vDSP_Length(halfN))
        return result
    }

    /// Group a magnitude spectrum into `count` log-spaced bands (averaged).
    public func bands(_ magnitudes: [Float], count bandCount: Int) -> [Float] {
        guard magnitudes.count > 2, bandCount > 0 else { return [Float](repeating: 0, count: bandCount) }
        let minBin = 1
        let maxBin = magnitudes.count - 1
        var bands = [Float](repeating: 0, count: bandCount)
        for b in 0..<bandCount {
            let lo = logBin(b, bandCount, minBin, maxBin)
            let hi = max(lo + 1, logBin(b + 1, bandCount, minBin, maxBin))
            var sum: Float = 0, c: Float = 0
            for bin in lo..<min(hi, magnitudes.count) { sum += magnitudes[bin]; c += 1 }
            bands[b] = c > 0 ? sum / c : 0
        }
        return bands
    }

    private func logBin(_ i: Int, _ count: Int, _ minBin: Int, _ maxBin: Int) -> Int {
        let frac = Double(i) / Double(count)
        let v = Double(minBin) * pow(Double(maxBin) / Double(minBin), frac)
        return min(maxBin, max(minBin, Int(v.rounded())))
    }
}
