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

// MARK: - Synthesis

/// A single soft knock: damped low tone (with a tiny initial pitch drop, the
/// way struck objects behave) plus a lowpassed noise transient for the snap.
/// `click` scales the transient; `brightness` (0–1) is the noise lowpass —
/// lower is duller.
func thock(frequency: Double, tau: Double, click: Double, brightness: Double,
           duration: Double) -> [Double] {
    let n = Int(duration * sampleRate)
    var out = [Double](repeating: 0, count: n)
    var lowpass = 0.0
    var phase = 0.0
    for i in 0..<n {
        let t = Double(i) / sampleRate
        let f = frequency * (1 + 0.05 * exp(-t / 0.012))
        phase += 2 * .pi * f / sampleRate
        let body = (sin(phase) + 0.30 * sin(2 * phase)) * exp(-t / tau)
        lowpass += (Double.random(in: -1...1) - lowpass) * brightness
        let transient = lowpass * exp(-t / 0.004) * click
        out[i] = body + transient
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
    // Fn down — a crisp felt thock. "Go."
    ("start", normalized(
        thock(frequency: 210, tau: 0.030, click: 1.0, brightness: 0.22, duration: 0.07),
        peak: 0.42
    )),
    // Fn up — darker, softer. "Done talking."
    ("stop", normalized(
        thock(frequency: 160, tau: 0.035, click: 0.65, brightness: 0.16, duration: 0.08),
        peak: 0.38
    )),
    // Text inserted — quiet low "du-dum", rising. Barely there.
    ("success", normalized(
        mix([
            (0.00, thock(frequency: 240, tau: 0.028, click: 0.35, brightness: 0.15, duration: 0.08)),
            (0.07, thock(frequency: 320, tau: 0.035, click: 0.35, brightness: 0.15, duration: 0.09)),
        ], duration: 0.17),
        peak: 0.32
    )),
    // Something failed — low double knock, falling.
    ("error", normalized(
        mix([
            (0.00, thock(frequency: 150, tau: 0.045, click: 0.5, brightness: 0.12, duration: 0.10)),
            (0.09, thock(frequency: 118, tau: 0.050, click: 0.5, brightness: 0.12, duration: 0.11)),
        ], duration: 0.21),
        peak: 0.40
    )),
]

for sound in palette {
    let url = outputDir.appendingPathComponent("\(sound.name).wav")
    try writeWav(sound.samples, to: url)
    print("wrote \(url.path) (\(sound.samples.count) samples)")
}
