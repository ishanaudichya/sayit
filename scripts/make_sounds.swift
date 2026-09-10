#!/usr/bin/env swift
// Generates SayIt's UI sound palette into Sources/SayIt/Resources/Sounds/*.wav.
// Run from the repo root:
//   swift scripts/make_sounds.swift
//
// Design: low, percussive "thocks" — a damped low tone plus a few
// milliseconds of soft noise transient. Snappy like a good keyboard, never
// chirpy. All sounds are original synthesis; nothing licensed.

import Foundation

let sampleRate = 44100.0

// MARK: - WAV writer (16-bit mono PCM)

func writeWav(_ samples: [Double], to url: URL) throws {
    var data = Data()
    let pcm: [Int16] = samples.map { Int16(max(-1, min(1, $0)) * 32767) }
    let byteCount = pcm.count * 2
    func ascii(_ s: String) { data.append(s.data(using: .ascii)!) }
    func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }
    func u16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }
    ascii("RIFF"); u32(UInt32(36 + byteCount)); ascii("WAVE")
    ascii("fmt "); u32(16); u16(1); u16(1)
    u32(UInt32(sampleRate)); u32(UInt32(sampleRate) * 2); u16(2); u16(16)
    ascii("data"); u32(UInt32(byteCount))
    for s in pcm { withUnsafeBytes(of: s.littleEndian) { data.append(contentsOf: $0) } }
    try data.write(to: url)
}

func fadeTail(_ samples: inout [Double], over count: Int = 96) {
    let n = samples.count
    for i in 0..<min(count, n) {
        samples[n - 1 - i] *= Double(i) / Double(count)
    }
}

// MARK: - Synthesis (modal: taps on a small dense object)

/// Two-pole resonator: rings at `frequency`, decaying with time constant `tau`.
struct Resonator {
    private let c1: Double
    private let c2: Double
    private var y1 = 0.0
    private var y2 = 0.0
    let amplitude: Double

    init(frequency: Double, tau: Double, amplitude: Double) {
        let r = exp(-1.0 / (tau * sampleRate))
        c1 = 2 * r * cos(2 * .pi * frequency / sampleRate)
        c2 = -r * r
        self.amplitude = amplitude
    }

    mutating func process(_ x: Double) -> Double {
        let y = x + c1 * y1 + c2 * y2
        y2 = y1
        y1 = y
        return y * amplitude
    }
}

/// A physical-sounding tap: ~2ms of noise exciting a handful of damped
/// resonant modes — the acoustics of striking a small object, not a tone.
func tap(modes: [(frequency: Double, tau: Double, amplitude: Double)],
         duration: Double) -> [Double] {
    var resonators = modes.map {
        Resonator(frequency: $0.frequency, tau: $0.tau, amplitude: $0.amplitude)
    }
    let excitation = 0.002
    let n = Int(duration * sampleRate)
    var out = [Double](repeating: 0, count: n)
    for i in 0..<n {
        let t = Double(i) / sampleRate
        let input = t < excitation ? Double.random(in: -1...1) * (1 - t / excitation) : 0
        var sample = 0.0
        for k in resonators.indices {
            sample += resonators[k].process(input)
        }
        out[i] = sample
    }
    fadeTail(&out)
    return out
}

/// Overlay parts at offsets into one buffer.
func mix(_ parts: [(start: Double, samples: [Double])], duration: Double) -> [Double] {
    let n = Int(duration * sampleRate)
    var out = [Double](repeating: 0, count: n)
    for part in parts {
        let offset = Int(part.start * sampleRate)
        for (i, sample) in part.samples.enumerated() where offset + i < n {
            out[offset + i] += sample
        }
    }
    fadeTail(&out)
    return out
}

func normalized(_ samples: [Double], peak: Double) -> [Double] {
    let maxAmp = samples.map(abs).max() ?? 1
    guard maxAmp > 0 else { return samples }
    return samples.map { $0 * peak / maxAmp }
}

// MARK: - The palette

let outputDir = URL(fileURLWithPath: "Sources/SayIt/Resources/Sounds")
try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

let palette: [(name: String, samples: [Double])] = [
    // Fn down — a crisp tick with a little body: fingernail on dense wood.
    ("start", normalized(
        tap(modes: [
            (frequency: 1700, tau: 0.008, amplitude: 1.0),
            (frequency: 720, tau: 0.014, amplitude: 0.8),
            (frequency: 3300, tau: 0.004, amplitude: 0.3),
        ], duration: 0.06),
        peak: 0.40
    )),
    // Fn up — the same object, tapped softer and deeper.
    ("stop", normalized(
        tap(modes: [
            (frequency: 1150, tau: 0.009, amplitude: 1.0),
            (frequency: 500, tau: 0.016, amplitude: 0.9),
        ], duration: 0.07),
        peak: 0.36
    )),
    // Text inserted — two quick taps, second slightly brighter. Barely there.
    ("success", normalized(
        mix([
            (0.00, tap(modes: [
                (frequency: 900, tau: 0.010, amplitude: 1.0),
                (frequency: 450, tau: 0.018, amplitude: 0.7),
            ], duration: 0.08)),
            (0.07, tap(modes: [
                (frequency: 1250, tau: 0.010, amplitude: 1.0),
                (frequency: 600, tau: 0.016, amplitude: 0.7),
            ], duration: 0.09)),
        ], duration: 0.16),
        peak: 0.30
    )),
    // Something failed — dull knock-knock, falling.
    ("error", normalized(
        mix([
            (0.00, tap(modes: [
                (frequency: 380, tau: 0.020, amplitude: 1.0),
                (frequency: 180, tau: 0.035, amplitude: 0.9),
            ], duration: 0.11)),
            (0.09, tap(modes: [
                (frequency: 300, tau: 0.022, amplitude: 1.0),
                (frequency: 150, tau: 0.040, amplitude: 0.9),
            ], duration: 0.12)),
        ], duration: 0.22),
        peak: 0.38
    )),
]

for sound in palette {
    let url = outputDir.appendingPathComponent("\(sound.name).wav")
    try writeWav(sound.samples, to: url)
    print("wrote \(url.path) (\(sound.samples.count) samples)")
}
