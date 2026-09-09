import SwiftUI

/// Five-step first-run flow: welcome → microphone → accessibility → fn key →
/// first dictation. Permissions are detected live; steps celebrate and
/// auto-advance when they're satisfied.
struct OnboardingView: View {
    @Environment(AppController.self) private var app
    var onFinished: () -> Void

    enum Step: Int, CaseIterable {
        case welcome, microphone, accessibility, fnKey, tryIt
    }

    @State private var step: Step = .welcome
    @State private var testText = ""
    @State private var dictationBaseline = 0
    @State private var celebrated: Set<Int> = []

    private let poll = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            header
            Spacer(minLength: 0)
            content
                .id(step)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            Spacer(minLength: 0)
            footer
        }
        .padding(28)
        .frame(width: 620, height: 560)
        .background(Theme.ground)
        .animation(Theme.spring, value: step)
        .onAppear {
            app.permissions.refresh()
            dictationBaseline = Store.shared.records.count
        }
        .onReceive(poll) { _ in
            let hadAccessibility = app.permissions.accessibilityGranted
            app.permissions.refresh()
            if !hadAccessibility && app.permissions.accessibilityGranted {
                app.restartHotkey()
            }
            celebrateIfSatisfied()
        }
    }

    // MARK: Chrome

    private var header: some View {
        HStack {
            Wordmark(size: 16)
            Spacer()
            if step != .welcome {
                Button("Skip setup") { onFinished() }
                    .buttonStyle(LinkButtonStyle())
            }
        }
    }

    private var footer: some View {
        HStack {
            StepDots(count: Step.allCases.count, current: step.rawValue)
            Spacer()
            if step.rawValue > 0 {
                Button("Back") { move(to: step.rawValue - 1) }
                    .buttonStyle(GhostButtonStyle())
            }
            if step == .fnKey && !app.permissions.fnKeyConfigured {
                Button("Continue anyway") { move(to: step.rawValue + 1) }
                    .buttonStyle(GhostButtonStyle())
            }
            Button(step == .tryIt ? "Start dictating" : continueLabel) {
                if step == .tryIt {
                    onFinished()
                } else {
                    move(to: step.rawValue + 1)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!stepSatisfied)
            .opacity(stepSatisfied ? 1 : 0.35)
        }
    }

    private var continueLabel: String {
        step == .welcome ? "Set up in 60 seconds" : "Continue"
    }

    // MARK: Steps

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome: welcome
        case .microphone: microphone
        case .accessibility: accessibility
        case .fnKey: fnKey
        case .tryIt: tryIt
        }
    }

    private var welcome: some View {
        VStack(spacing: 22) {
            WaveMark(height: 64, animated: true)
            VStack(spacing: 10) {
                Text("Hold a key. Speak.\nIt's typed.")
                    .font(Theme.display(30))
                    .tracking(-0.8)
                    .foregroundStyle(Theme.text)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                Text("Fast, private dictation for your Mac.\nEverything runs on-device — nothing ever leaves it.")
                    .font(Theme.body(13.5))
                    .foregroundStyle(Theme.textDim)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
    }

    private var microphone: some View {
        StepLayout(
            icon: "mic.fill",
            title: "Let SayIt hear you",
            subtitle: "Audio is transcribed by Apple's on-device speech engine. No cloud, no accounts, no audio stored.",
            granted: app.permissions.microphoneGranted,
            grantedLabel: "Microphone ready"
        ) {
            Button("Allow microphone") {
                app.permissions.requestMicrophone()
            }
            .buttonStyle(GhostButtonStyle())
        }
    }

    private var accessibility: some View {
        StepLayout(
            icon: "keyboard.badge.waveform.fill",
            title: "Let SayIt type for you",
            subtitle: "Accessibility access lets SayIt notice the fn key anywhere and place finished text at your cursor. Toggle SayIt on in the list, then come back — this step completes itself.",
            granted: app.permissions.accessibilityGranted,
            grantedLabel: "Accessibility granted"
        ) {
            Button("Open Accessibility settings") {
                app.permissions.promptAccessibility()
                app.permissions.openAccessibilitySettings()
            }
            .buttonStyle(GhostButtonStyle())
        }
    }

    private var fnKey: some View {
        StepLayout(
            icon: "",
            title: "Give SayIt the fn key",
            subtitle: "In System Settings → Keyboard, set “Press 🌐 key to” to Do Nothing so the emoji picker and Apple dictation stay out of the way.",
            granted: app.permissions.fnKeyConfigured,
            grantedLabel: "The fn key is yours",
            customIcon: { KeyCap(size: 54) }
        ) {
            Button("Open Keyboard settings") {
                app.permissions.openKeyboardSettings()
            }
            .buttonStyle(GhostButtonStyle())
        }
    }

    private var tryIt: some View {
        VStack(spacing: 16) {
            Text("Say hello")
                .font(Theme.display(24))
                .tracking(-0.5)
                .foregroundStyle(Theme.text)
            HStack(spacing: 8) {
                Text("Click the field, hold")
                    .foregroundStyle(Theme.textDim)
                KeyCap(size: 30)
                Text("and speak. Release when done.")
                    .foregroundStyle(Theme.textDim)
            }
            .font(Theme.body(13))

            TextEditor(text: $testText)
                .font(.system(size: 14))
                .foregroundStyle(Theme.text)
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(width: 420, height: 90)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.well, style: .continuous)
                        .fill(Theme.sunken)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.well, style: .continuous)
                        .strokeBorder(
                            hasDictated ? Theme.accent.opacity(0.6) : Theme.hairline,
                            lineWidth: 1
                        )
                )

            if hasDictated {
                Label("That's it — you're set.", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(Theme.spring, value: hasDictated)
    }

    // MARK: Logic

    private var hasDictated: Bool {
        Store.shared.records.count > dictationBaseline || !testText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var stepSatisfied: Bool {
        switch step {
        case .welcome: return true
        case .microphone: return app.permissions.microphoneGranted
        case .accessibility: return app.permissions.accessibilityGranted
        case .fnKey: return app.permissions.fnKeyConfigured
        case .tryIt: return hasDictated
        }
    }

    private func move(to raw: Int) {
        guard let next = Step(rawValue: raw) else { return }
        step = next
    }

    private func celebrateIfSatisfied() {
        guard step != .welcome, step != .tryIt, stepSatisfied,
              !celebrated.contains(step.rawValue) else { return }
        celebrated.insert(step.rawValue)
        SoundPlayer.shared.play(.success)
    }
}

// MARK: - Step layout

private struct StepLayout<Action: View>: View {
    var icon: String
    var title: String
    var subtitle: String
    var granted: Bool
    var grantedLabel: String
    var customIcon: (() -> KeyCap)?
    @ViewBuilder var action: Action

    init(
        icon: String,
        title: String,
        subtitle: String,
        granted: Bool,
        grantedLabel: String,
        customIcon: (() -> KeyCap)? = nil,
        @ViewBuilder action: () -> Action
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.granted = granted
        self.grantedLabel = grantedLabel
        self.customIcon = customIcon
        self.action = action()
    }

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(granted ? 0.16 : 0.08))
                    .frame(width: 84, height: 84)
                if let customIcon {
                    customIcon()
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(granted ? Theme.accent : Theme.text)
                }
            }
            .animation(Theme.spring, value: granted)

            VStack(spacing: 8) {
                Text(title)
                    .font(Theme.display(24))
                    .tracking(-0.5)
                    .foregroundStyle(Theme.text)
                Text(subtitle)
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.textDim)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: 420)
            }

            if granted {
                Label(grantedLabel, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .transition(.scale.combined(with: .opacity))
            } else {
                action
            }
        }
        .animation(Theme.spring, value: granted)
    }
}
