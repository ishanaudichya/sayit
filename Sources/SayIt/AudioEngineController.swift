import AVFoundation

/// Captures microphone audio and reports a smoothed level for the waveform.
final class AudioEngineController {
    var onLevel: ((Float) -> Void)?

    private let engine = AVAudioEngine()
    private var isRunning = false
    private var smoothedLevel: Float = 0
    private var lastPublishedLevel: Float = -1

    func start(onBuffer: @escaping (AVAudioPCMBuffer) -> Void) throws {
        guard !isRunning else { return }
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.channelCount > 0, format.sampleRate > 0 else {
            throw SayItError.noMicrophone
        }
        input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
            onBuffer(buffer)
            self?.publishLevel(from: buffer)
        }
        engine.prepare()
        try engine.start()
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        engine.reset()
        isRunning = false
        smoothedLevel = 0
        lastPublishedLevel = -1
        onLevel?(0)
    }

    private func publishLevel(from buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData?[0] else { return }
        let n = Int(buffer.frameLength)
        guard n > 0 else { return }
        var sum: Float = 0
        for i in 0..<n {
            sum += data[i] * data[i]
        }
        let rms = sqrt(sum / Float(n))
        let level = min(1, rms * 18)
        // Fast attack, slow decay — feels responsive without flickering.
        smoothedLevel = max(level, smoothedLevel * 0.82)
        // Quantize so we only publish (and re-render) on meaningful change.
        let quantized = (smoothedLevel * 64).rounded() / 64
        guard quantized != lastPublishedLevel else { return }
        lastPublishedLevel = quantized
        onLevel?(quantized)
    }
}

enum SayItError: LocalizedError {
    case noMicrophone
    case localeUnsupported

    var errorDescription: String? {
        switch self {
        case .noMicrophone: return "No microphone available"
        case .localeUnsupported: return "This language isn't supported for on-device dictation yet"
        }
    }
}
