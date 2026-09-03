import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @Environment(AppController.self) private var app
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
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
                LabeledContent("Dictation key", value: "Hold Fn (🌐)")
            }

            Section("Privacy") {
                Label {
                    Text("Transcription runs entirely on this Mac. No audio or text is ever uploaded.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(.green)
                }
            }

            Section("Coming soon") {
                Text("Punctuation style · Custom dictionary · AI smart formatting · History & analytics")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize()
    }
}
