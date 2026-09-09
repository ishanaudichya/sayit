import SwiftUI
import ServiceManagement

/// Settings — lives as a page in the app shell and as the standalone
/// Settings window.
struct SettingsPage: View {
    @Environment(AppController.self) private var app
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @AppStorage("appearance") private var appearanceRaw = "system"
    @AppStorage("punctuationMode") private var punctuationRaw = "auto"
    @AppStorage("matchToneEnabled") private var matchToneEnabled = true
    @AppStorage("soundsEnabled") private var soundsEnabled = true
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("smartFormattingEnabled") private var smartFormattingEnabled = true
    @AppStorage("onboardingComplete") private var onboardingComplete = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Settings")
                    .font(Theme.display(24))
                    .tracking(-0.6)
                    .foregroundStyle(Theme.text)
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "Appearance")
                    HStack(spacing: 6) {
                        ForEach(Appearance.allCases) { option in
                            Button(option.label) {
                                appearanceRaw = option.rawValue
                                option.apply()
                            }
                            .buttonStyle(ChipStyle(selected: appearanceRaw == option.rawValue))
                        }
                        Spacer()
                    }
                }
                .card(padding: 16)

                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "Punctuation")
                    HStack(spacing: 6) {
                        ForEach(PunctuationMode.allCases) { mode in
                            Button(mode.label) {
                                punctuationRaw = mode.rawValue
                            }
                            .buttonStyle(ChipStyle(selected: punctuationRaw == mode.rawValue))
                        }
                        Spacer()
                    }
                    Text((PunctuationMode(rawValue: punctuationRaw) ?? .auto).caption)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.textFaint)
                        .animation(nil, value: punctuationRaw)
                }
                .card(padding: 16)

                VStack(spacing: 12) {
                    Toggle("Launch at login", isOn: $launchAtLogin)
                        .toggleStyle(ThemeToggleStyle())
                        .onChange(of: launchAtLogin) { _, enabled in
                            do {
                                if enabled {
                                    try SMAppService.mainApp.register()
                                } else {
                                    try SMAppService.mainApp.unregister()
                                }
                            } catch {
                                launchAtLogin = SMAppService.mainApp.status == .enabled
                            }
                        }
                    divider
                    Toggle("Sounds", isOn: $soundsEnabled)
                        .toggleStyle(ThemeToggleStyle())
                        .onChange(of: soundsEnabled) { _, enabled in
                            if enabled { SoundPlayer.shared.play(.start) }
                        }
                    divider
                    Toggle("Trackpad haptics", isOn: $hapticsEnabled)
                        .toggleStyle(ThemeToggleStyle())
                        .onChange(of: hapticsEnabled) { _, enabled in
                            if enabled { SoundPlayer.shared.haptic() }
                        }
                    divider
                    VStack(alignment: .leading, spacing: 5) {
                        Toggle("Smart formatting", isOn: $smartFormattingEnabled)
                            .toggleStyle(ThemeToggleStyle())
                            .disabled(!SmartFormatter.shared.isAvailable)
                        Text(SmartFormatter.shared.unavailabilityNote
                             ?? "Removes filler words, applies corrections, “new line” commands — on-device.")
                            .font(.system(size: 10.5))
                            .foregroundStyle(Theme.textFaint)
                    }
                    divider
                    VStack(alignment: .leading, spacing: 5) {
                        Toggle("Match tone to app", isOn: $matchToneEnabled)
                            .toggleStyle(ThemeToggleStyle())
                            .disabled(!SmartFormatter.shared.isAvailable || !smartFormattingEnabled)
                        Text("Relaxed in chat apps, professional in mail — based on where you're dictating.")
                            .font(.system(size: 10.5))
                            .foregroundStyle(Theme.textFaint)
                    }
                    divider
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Dictation key")
                                .font(Theme.body())
                                .foregroundStyle(Theme.text)
                            Text("Hold to talk · double-tap to lock hands-free · Esc cancels")
                                .font(.system(size: 10.5))
                                .foregroundStyle(Theme.textFaint)
                        }
                        Spacer()
                        KeyCap(size: 30)
                    }
                }
                .card(padding: 16)

                HStack(spacing: 10) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.accent)
                    Text("Transcription runs entirely on this Mac.\nNo audio or text ever leaves it.")
                        .font(Theme.body(12))
                        .foregroundStyle(Theme.textDim)
                        .lineSpacing(2)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .card(padding: 14)

                HStack {
                    Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")")
                        .font(Theme.mono(11, weight: .regular))
                        .foregroundStyle(Theme.textFaint)
                    Spacer()
                    Button("Run setup again") { onboardingComplete = false }
                        .buttonStyle(LinkButtonStyle())
                }
            }
            .padding(22)
        }
        .background(Theme.ground)
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(height: 1)
    }
}

private struct ChipStyle: ButtonStyle {
    var selected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(selected ? Theme.onCitron : Theme.textDim)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Capsule().fill(selected ? Theme.citron : Theme.fillFaint))
            .overlay(Capsule().strokeBorder(selected ? Color.clear : Theme.hairline, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(Theme.springFast, value: configuration.isPressed)
            .animation(Theme.springFast, value: selected)
    }
}
