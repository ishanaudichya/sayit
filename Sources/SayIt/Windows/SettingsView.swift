import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @Environment(AppController.self) private var app
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @AppStorage("soundsEnabled") private var soundsEnabled = true
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("smartFormattingEnabled") private var smartFormattingEnabled = true
    @AppStorage("onboardingComplete") private var onboardingComplete = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Wordmark(size: 15)
                Spacer()
                Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1")")
                    .font(Theme.mono(11, weight: .regular))
                    .foregroundStyle(Theme.boneFaint)
            }
            .padding(.top, 4)

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
                        .foregroundStyle(Theme.boneFaint)
                }
                divider
                HStack {
                    Text("Dictation key")
                        .font(Theme.body())
                        .foregroundStyle(Theme.bone)
                    Spacer()
                    KeyCap(size: 30)
                }
            }
            .card(padding: 16)

            HStack(spacing: 10) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.citron)
                Text("Transcription runs entirely on this Mac.\nNo audio or text ever leaves it.")
                    .font(Theme.body(12))
                    .foregroundStyle(Theme.boneDim)
                    .lineSpacing(2)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .card(padding: 14)

            HStack {
                Text("Punctuation style · Custom dictionary — coming next")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.boneFaint)
                Spacer()
                Button("Run setup again") { onboardingComplete = false }
                    .buttonStyle(LinkButtonStyle())
            }
        }
        .padding(20)
        .frame(width: 420)
        .background(Theme.ink)
        .containerBackground(Theme.ink, for: .window)
        .preferredColorScheme(.dark)
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(height: 1)
    }
}
