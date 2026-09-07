#!/usr/bin/env swift
// Generates SayIt's UI sound palette — tiny synthesized "flicks" — into
// Sources/SayIt/Resources/Sounds/*.wav. Run from the repo root:
//   swift scripts/make_sounds.swift
// All sounds are original synthesis (sine sweeps + noise transients), so the
// app ships nothing with licensing strings attached.

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

// MARK: - Synthesis

/// A pitch-swept tick with an exponential decay and a tiny noise transient —
/// the "flick". Sweeping up feels like engaging; down feels like releasing.
func flick(duration: Double, from f0: Double, to f1: Double, tau: Double,
           gain: Double, transient: Double, secondHarmonic: Double = 0.18) -> [Double] {
    let n = Int(duration * sampleRate)
    var out = [Double](repeating: 0, count: n)
    var phase = 0.0
    for i in 0..<n {
        let t = Double(i) / sampleRate
        let f = f0 + (f1 - f0) * (t / duration)
        phase += 2 * .pi * f / sampleRate
        let envelope = exp(-t / tau)
        var v = (sin(phase) + secondHarmonic * sin(2 * phase)) * envelope
        if t < 0.003, transient > 0 {
            v += transient * Double.random(in: -1...1) * exp(-t / 0.0015)
        }
        out[i] = v * gain
    }
    fadeTail(&out)
    return out
}

/// A short melodic blip built from fixed-pitch partials with soft attacks.
func blip(notes: [(start: Double, freq: Double, tau: Double, gain: Double)],
          duration: Double) -> [Double] {
    let n = Int(duration * sampleRate)
    var out = [Double](repeating: 0, count: n)
    for note in notes {
        let startIndex = Int(note.start * sampleRate)
        guard startIndex < n else { continue }
        for i in startIndex..<n {
            let t = Double(i - startIndex) / sampleRate
            let envelope = exp(-t / note.tau) * min(1, t / 0.002)
            let v = sin(2 * .pi * note.freq * t) + 0.25 * sin(4 * .pi * note.freq * t)
            out[i] += v * envelope * note.gain
        }
    }
    fadeTail(&out)
    return out
}

// MARK: - The palette

let outputDir = URL(fileURLWithPath: "Sources/SayIt/Resources/Sounds")
try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

let palette: [(name: String, samples: [Double])] = [
    // Fn down — bright flick up, crisp transient. "Go."
    ("start", flick(duration: 0.07, from: 850, to: 1500, tau: 0.022, gain: 0.32, transient: 0.25)),
    // Fn up — mirrored flick down, softer. "Done talking."
    ("stop", flick(duration: 0.09, from: 1250, to: 620, tau: 0.030, gain: 0.30, transient: 0.15)),
    // Text inserted — quiet two-note blip (E6 → A6), barely there.
    ("success", blip(notes: [(0, 1318.5, 0.045, 0.20), (0.055, 1760, 0.060, 0.20)], duration: 0.18)),
    // Something failed — low double knock.
    ("error", blip(notes: [(0, 196, 0.040, 0.32), (0.085, 165, 0.050, 0.32)], duration: 0.20)),
]

for sound in palette {
    let url = outputDir.appendingPathComponent("\(sound.name).wav")
    try writeWav(sound.samples, to: url)
    print("wrote \(url.path) (\(sound.samples.count) samples)")
}
