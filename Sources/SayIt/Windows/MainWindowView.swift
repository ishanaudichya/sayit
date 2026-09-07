import SwiftUI

/// The app window. Runs onboarding on first launch, then becomes the home
/// dashboard. Closing it never stops SayIt — the menu bar agent keeps going.
struct MainWindowView: View {
    @Environment(AppController.self) private var app
    @AppStorage("onboardingComplete") private var onboardingComplete = false

    var body: some View {
        ZStack {
            if onboardingComplete {
                DashboardView()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                OnboardingView {
                    onboardingComplete = true
                }
                .transition(.opacity)
            }
        }
        .animation(Theme.spring, value: onboardingComplete)
        .background(Theme.ink)
        .containerBackground(Theme.ink, for: .window)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Dashboard

private struct DashboardView: View {
    @Environment(AppController.self) private var app
    @AppStorage("onboardingComplete") private var onboardingComplete = true
    @State private var testText = ""

    private let poll = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Wordmark(size: 17)
                Spacer()
                StatusChip(label: statusLabel, color: statusColor)
            }
            .padding(.top, 6)

            hero

            HStack(spacing: 14) {
                StatTile(value: app.totalWords, label: "words dictated")
                StatTile(value: app.totalDictations, label: "dictations")
            }

            if !app.permissions.allGranted || !app.permissions.fnKeyConfigured {
                healthStrip
            }

            testCard

            HStack {
                Text("Lives in your menu bar — close this window anytime.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.boneFaint)
                Spacer()
                Button("Run setup again") { onboardingComplete = false }
                    .buttonStyle(LinkButtonStyle())
            }
        }
        .padding(24)
        .frame(width: 520)
        .onAppear { app.permissions.refresh() }
        .onReceive(poll) { _ in
            let hadAccessibility = app.permissions.accessibilityGranted
            app.permissions.refresh()
            if !hadAccessibility && app.permissions.accessibilityGranted {
                app.restartHotkey()
            }
        }
    }

    private var hero: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Hold fn.\nStart talking.")
                    .font(Theme.display(26))
                    .tracking(-0.7)
                    .foregroundStyle(Theme.bone)
                    .lineSpacing(2)
                Text("Anywhere you can type — release and it's written.")
                    .font(Theme.body(12.5))
                    .foregroundStyle(Theme.boneDim)
            }
            Spacer()
            VStack(spacing: 10) {
                KeyCap(size: 52)
                WaveMark(height: 18, animated: app.status == .recording)
            }
        }
        .card(padding: 22)
    }

    private var healthStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Needs attention", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.coral)
            if !app.permissions.microphoneGranted {
                healthRow("Microphone access", "Allow") {
                    app.permissions.requestMicrophone()
                }
            }
            if !app.permissions.accessibilityGranted {
                healthRow("Accessibility access", "Open Settings") {
                    app.permissions.promptAccessibility()
                    app.permissions.openAccessibilitySettings()
                }
            }
            if !app.permissions.fnKeyConfigured {
                healthRow("Set “Press 🌐 key to” → Do Nothing", "Open Keyboard") {
                    app.permissions.openKeyboardSettings()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 16)
    }

    private func healthRow(_ title: String, _ actionTitle: String, action: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(Theme.body(12.5))
                .foregroundStyle(Theme.bone)
            Spacer()
            Button(actionTitle, action: action)
                .buttonStyle(GhostButtonStyle())
        }
    }

    private var testCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SCRATCHPAD")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.boneFaint)
            TextEditor(text: $testText)
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.bone)
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(height: 64)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.well, style: .continuous)
                        .fill(Theme.inkSunken)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.well, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                )
        }
        .card(padding: 16)
    }

    private var statusLabel: String {
        switch app.status {
        case .idle: return app.permissions.allGranted ? "Ready" : "Setup needed"
        case .recording: return "Listening"
        case .finishing: return "Finishing"
        case .inserted: return "Inserted"
        case .error(let message): return message
        }
    }

    private var statusColor: Color {
        switch app.status {
        case .idle: return app.permissions.allGranted ? Theme.citron : Theme.coral
        case .recording: return Theme.citron
        case .finishing: return Theme.boneDim
        case .inserted: return Theme.citron
        case .error: return Theme.coral
        }
    }
}

private struct StatTile: View {
    var value: Int
    var label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(value)")
                .font(Theme.mono(22))
                .foregroundStyle(Theme.citron)
                .contentTransition(.numericText())
                .animation(Theme.spring, value: value)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Theme.boneDim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 14)
    }
}
