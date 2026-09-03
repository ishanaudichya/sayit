import AppKit
import AVFoundation
import ApplicationServices
import Observation

@MainActor
@Observable
final class PermissionsModel {
    var microphoneGranted = false
    var accessibilityGranted = false
    /// System Settings → Keyboard → "Press 🌐 key to". 0 = Do Nothing (what we
    /// want). nil = unknown/not yet set explicitly.
    var fnKeyUsage: Int?

    var fnKeyConfigured: Bool { fnKeyUsage == 0 }
    var allGranted: Bool { microphoneGranted && accessibilityGranted }

    func refresh() {
        // Only assign on change — @Observable notifies on every set, and this
        // runs on a poll timer, so unconditional writes cause needless redraws.
        let microphone = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        if microphone != microphoneGranted { microphoneGranted = microphone }

        let accessibility = AXIsProcessTrusted()
        if accessibility != accessibilityGranted { accessibilityGranted = accessibility }

        var usage: Int?
        if let defaults = UserDefaults(suiteName: "com.apple.HIToolbox"),
           defaults.object(forKey: "AppleFnUsageType") != nil {
            usage = defaults.integer(forKey: "AppleFnUsageType")
        }
        if usage != fnKeyUsage { fnKeyUsage = usage }
    }

    func requestMicrophone() {
        AVCaptureDevice.requestAccess(for: .audio) { _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
    }

    func promptAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func openKeyboardSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}
