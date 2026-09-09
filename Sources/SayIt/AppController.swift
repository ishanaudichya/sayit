import AppKit
import Observation

/// Central state machine: idle → recording (Fn down) → finishing (Fn up) → inserted → idle.
@MainActor
@Observable
final class AppController {
    static let shared = AppController()

    enum Status: Equatable {
        case idle
        case recording
        case finishing
        case inserted
        case error(String)
    }

    var status: Status = .idle
    var audioLevel: Float = 0
    var liveTranscript: String = ""
    /// Double-tap Fn locks recording on until the next Fn tap.
    private(set) var handsFree = false
    let permissions = PermissionsModel()

    private let hotkey = HotkeyMonitor()
    private let audio = AudioEngineController()
    private let inserter = TextInserter()
    private let bubble = BubbleWindowController()
    private var transcriber: DictationTranscriber?
    private var setupTask: Task<Void, Never>?
    private var recordingStartedAt: Date?
    private var watchdog: Timer?
    private var lastFnDown: Date?
    private var targetApp: String?
    private var escMonitors: [Any] = []

    /// Hard cap so a stuck session can never hold the mic open indefinitely.
    private static let maxRecordingSeconds: TimeInterval = 120

    func start() {
        UserDefaults.standard.register(defaults: [
            "soundsEnabled": true,
            "hapticsEnabled": true,
            "smartFormattingEnabled": true,
            "matchToneEnabled": true,
            "punctuationMode": "auto",
        ])
        Appearance.applyStored()
        _ = Store.shared // load history + dictionary
        _ = SoundPlayer.shared // preload sound buffers before the first Fn press
        SmartFormatter.shared.prewarm()
        permissions.refresh()
        Task.detached(priority: .utility) {
            await DictationTranscriber.preloadAssets()
        }
        audio.onLevel = { [weak self] level in
            Task { @MainActor in self?.audioLevel = level }
        }
        hotkey.onFnDown = { [weak self] in self?.fnDown() }
        hotkey.onFnUp = { [weak self] in self?.fnUp() }
        hotkey.start()
    }

    private func fnDown() {
        if case .recording = status {
            // In hands-free mode, a tap ends the dictation.
            if handsFree { endDictation() }
            return
        }
        let now = Date()
        if let last = lastFnDown, now.timeIntervalSince(last) < 0.4 {
            handsFree = true
        }
        lastFnDown = now
        beginDictation()
    }

    private func fnUp() {
        guard !handsFree else { return }
        endDictation()
    }

    /// Re-arm the global event monitor (used after Accessibility is granted).
    func restartHotkey() {
        hotkey.start()
    }

    private func beginDictation() {
        guard case .idle = status else { return }
        status = .recording
        liveTranscript = ""
        audioLevel = 0
        recordingStartedAt = Date()
        targetApp = NSWorkspace.shared.frontmostApplication?.localizedName
        // Feedback first — the flick must land the instant the key goes down.
        SoundPlayer.shared.play(.start)
        SoundPlayer.shared.haptic(.generic)
        bubble.show()
        startWatchdog()
        installEscMonitor()

        let transcriber = DictationTranscriber()
        self.transcriber = transcriber
        setupTask = Task { [weak self] in
            do {
                try await transcriber.start { text in
                    Task { @MainActor [weak self] in
                        self?.liveTranscript = text
                    }
                }
                guard let self, case .recording = self.status else { return }
                try self.audio.start { buffer in
                    transcriber.enqueue(buffer)
                }
            } catch {
                self?.failDictation("Couldn't start dictation")
                NSLog("SayIt: dictation setup failed: \(error)")
            }
        }
    }

    /// Esc while recording throws the dictation away — nothing is pasted.
    private func cancelDictation() {
        guard case .recording = status else { return }
        stopWatchdog()
        removeEscMonitor()
        handsFree = false
        audio.stop()
        setupTask?.cancel()
        transcriber?.cancel()
        transcriber = nil
        SoundPlayer.shared.play(.stop)
        status = .idle
        bubble.hide()
    }

    private func endDictation() {
        guard case .recording = status else { return }
        status = .finishing
        stopWatchdog()
        removeEscMonitor()
        handsFree = false
        SoundPlayer.shared.play(.stop)
        SoundPlayer.shared.haptic(.levelChange)
        audio.stop()

        let transcriber = self.transcriber
        let setupTask = self.setupTask
        let startedAt = self.recordingStartedAt
        let bestEffort = liveTranscript
        Task { @MainActor [weak self] in
            // Bounded waits everywhere: a hung analyzer must never wedge the
            // app in "finishing" with the UI animating forever.
            var text = bestEffort
            let setupSettled = await withTimeout(seconds: 2.5) {
                await setupTask?.value
                return true
            } ?? false
            if setupSettled {
                let finalized = await withTimeout(seconds: 3.0) { () -> String in
                    (try? await transcriber?.finish()) ?? bestEffort
                }
                if let finalized {
                    text = finalized
                } else {
                    NSLog("SayIt: finalize timed out, using live transcript")
                    transcriber?.cancel()
                }
            } else {
                NSLog("SayIt: setup never settled, abandoning session")
                setupTask?.cancel()
                transcriber?.cancel()
            }
            guard let self else { return }
            self.transcriber = nil

            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let tooShort = startedAt.map { Date().timeIntervalSince($0) < 0.3 } ?? false
            if trimmed.isEmpty || tooShort {
                self.bubble.hide()
                self.status = .idle
                return
            }

            // Deterministic rules first (spoken punctuation, dictionary
            // replacements), then smart formatting inside a bounded time
            // slice — raw text pastes if the model is slow or unavailable.
            var processed = trimmed
            if PunctuationMode.current == .spoken {
                processed = TextRules.applySpokenPunctuation(processed)
            }
            processed = Store.shared.applyReplacements(to: processed)
            var finalText = processed
            let budget = min(1.2 + Double(processed.split { $0.isWhitespace }.count) * 0.03, 2.5)
            let toneApp = UserDefaults.standard.bool(forKey: "matchToneEnabled") ? self.targetApp : nil
            if let cleaned = await SmartFormatter.shared.clean(processed, timeout: budget, appName: toneApp) {
                finalText = cleaned
            }

            do {
                try self.inserter.insert(finalText)
                self.status = .inserted
                Store.shared.addRecord(
                    raw: trimmed,
                    text: finalText,
                    duration: startedAt.map { Date().timeIntervalSince($0) } ?? 0
                )
                SoundPlayer.shared.play(.success)
                self.bubble.hide(after: 0.45)
            } catch TextInserter.InsertError.secureInput {
                self.status = .error("Secure field — copied to clipboard")
                SoundPlayer.shared.play(.error)
                self.bubble.hide(after: 1.6)
            } catch {
                self.status = .error("Couldn't insert text")
                SoundPlayer.shared.play(.error)
                self.bubble.hide(after: 1.6)
            }
            try? await Task.sleep(for: .seconds(1.8))
            if case .idle = self.status {} else { self.status = .idle }
        }
    }

    private func startWatchdog() {
        stopWatchdog()
        watchdog = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.watchdogTick()
            }
        }
    }

    private func stopWatchdog() {
        watchdog?.invalidate()
        watchdog = nil
    }

    /// Recovers from a missed Fn-release event or a runaway session.
    private func watchdogTick() {
        guard case .recording = status else {
            stopWatchdog()
            return
        }
        let missedRelease = !handsFree && !NSEvent.modifierFlags.contains(.function)
        let tooLong = recordingStartedAt.map {
            Date().timeIntervalSince($0) > Self.maxRecordingSeconds
        } ?? false
        if missedRelease || tooLong {
            NSLog("SayIt: watchdog ended dictation (missedRelease=\(missedRelease), tooLong=\(tooLong))")
            endDictation()
        }
    }

    private func installEscMonitor() {
        removeEscMonitor()
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            guard event.keyCode == 53 else { return }
            self?.cancelDictation()
        }) {
            escMonitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            guard event.keyCode == 53, case .recording = self?.status else { return event }
            self?.cancelDictation()
            return nil
        }) {
            escMonitors.append(local)
        }
    }

    private func removeEscMonitor() {
        for monitor in escMonitors {
            NSEvent.removeMonitor(monitor)
        }
        escMonitors.removeAll()
    }

    private func failDictation(_ message: String) {
        stopWatchdog()
        removeEscMonitor()
        handsFree = false
        audio.stop()
        transcriber?.cancel()
        transcriber = nil
        SoundPlayer.shared.play(.error)
        status = .error(message)
        bubble.hide(after: 1.6)
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1.8))
            if let self, case .error = self.status { self.status = .idle }
        }
    }
}

/// Runs `operation`, returning nil if it doesn't complete within `seconds`.
func withTimeout<T: Sendable>(
    seconds: Double,
    _ operation: @escaping @Sendable () async -> T
) async -> T? {
    await withTaskGroup(of: T?.self) { group in
        group.addTask {
            await operation()
        }
        group.addTask {
            try? await Task.sleep(for: .seconds(seconds))
            return nil
        }
        let first = await group.next() ?? nil
        group.cancelAll()
        return first
    }
}
