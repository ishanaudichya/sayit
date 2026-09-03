import AVFoundation
import Speech

/// Streaming on-device speech-to-text built on the macOS 26 SpeechAnalyzer API —
/// the same engine behind system dictation. Transcribes live while the user
/// holds Fn, so the final text is ready almost immediately on release.
final class DictationTranscriber: @unchecked Sendable {
    private var analyzer: SpeechAnalyzer?
    private var transcriber: SpeechTranscriber?
    private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?
    private let converter = BufferConverter()
    private var analyzerFormat: AVAudioFormat?

    private let lock = NSLock()
    private var finalizedText = ""
    private var volatileText = ""
    private var pendingBuffers: [AVAudioPCMBuffer] = []

    /// Kick off the (one-time) model download at app launch so the first
    /// dictation never waits on it.
    static func preloadAssets() async {
        do {
            let transcriber = SpeechTranscriber(
                locale: Locale.current,
                transcriptionOptions: [],
                reportingOptions: [.volatileResults],
                attributeOptions: []
            )
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                try await request.downloadAndInstall()
            }
        } catch {
            NSLog("SayIt: speech asset preload failed: \(error)")
        }
    }

    func start(onUpdate: @escaping @Sendable (String) -> Void) async throws {
        let locale = Locale.current
        let supported = await SpeechTranscriber.supportedLocales
        guard supported.contains(where: {
            $0.identifier(.bcp47) == locale.identifier(.bcp47)
        }) else {
            throw SayItError.localeUnsupported
        }

        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: []
        )
        self.transcriber = transcriber

        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        self.analyzer = analyzer

        let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])

        let (stream, builder) = AsyncStream<AnalyzerInput>.makeStream()
        inputBuilder = builder

        resultsTask = Task { [weak self] in
            do {
                for try await result in transcriber.results {
                    guard let self else { return }
                    let text = String(result.text.characters)
                    let current: String = self.lock.withLock {
                        if result.isFinal {
                            self.finalizedText += text
                            self.volatileText = ""
                        } else {
                            self.volatileText = text
                        }
                        return self.finalizedText + self.volatileText
                    }
                    onUpdate(current)
                }
            } catch {
                NSLog("SayIt: transcription results stream ended: \(error)")
            }
        }

        try await analyzer.start(inputSequence: stream)

        // Publish the format last, then flush any audio captured while the
        // analyzer was starting up so the first word isn't clipped.
        let pending: [AVAudioPCMBuffer] = lock.withLock {
            analyzerFormat = format
            let buffered = pendingBuffers
            pendingBuffers = []
            return buffered
        }
        for buffer in pending {
            feed(buffer, format: format)
        }
    }

    /// Called from the audio tap thread.
    func enqueue(_ buffer: AVAudioPCMBuffer) {
        let format: AVAudioFormat? = lock.withLock {
            if analyzerFormat == nil {
                pendingBuffers.append(buffer)
            }
            return analyzerFormat
        }
        guard let format else { return }
        feed(buffer, format: format)
    }

    private func feed(_ buffer: AVAudioPCMBuffer, format: AVAudioFormat?) {
        guard let format,
              let converted = try? converter.convert(buffer, to: format) else { return }
        inputBuilder?.yield(AnalyzerInput(buffer: converted))
    }

    func finish() async throws -> String {
        inputBuilder?.finish()
        try await analyzer?.finalizeAndFinishThroughEndOfInput()
        resultsTask?.cancel()
        return lock.withLock { finalizedText + volatileText }
    }

    /// Abandon the session without waiting for finalization.
    func cancel() {
        inputBuilder?.finish()
        resultsTask?.cancel()
        let analyzer = self.analyzer
        self.analyzer = nil
        Task.detached {
            await analyzer?.cancelAndFinishNow()
        }
    }
}

/// Converts mic-format buffers to the analyzer's preferred format.
final class BufferConverter {
    private var converter: AVAudioConverter?

    func convert(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) throws -> AVAudioPCMBuffer {
        if buffer.format == format {
            return buffer
        }
        if converter == nil || converter?.outputFormat != format || converter?.inputFormat != buffer.format {
            converter = AVAudioConverter(from: buffer.format, to: format)
        }
        guard let converter else {
            throw NSError(domain: "SayIt", code: 1, userInfo: [NSLocalizedDescriptionKey: "Audio conversion unavailable"])
        }
        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 16
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
            throw NSError(domain: "SayIt", code: 2, userInfo: [NSLocalizedDescriptionKey: "Couldn't allocate audio buffer"])
        }
        var consumed = false
        var conversionError: NSError?
        converter.convert(to: output, error: &conversionError) { _, statusPointer in
            if consumed {
                statusPointer.pointee = .noDataNow
                return nil
            }
            consumed = true
            statusPointer.pointee = .haveData
            return buffer
        }
        if let conversionError {
            throw conversionError
        }
        return output
    }
}
