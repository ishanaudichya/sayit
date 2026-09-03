import SwiftUI

/// The app's home window: permission setup, a place to test dictation, and a
/// live status readout. Closing it never stops SayIt — the menu bar agent
/// keeps listening for Fn.
struct MainWindowView: View {
    @Environment(AppController.self) private var app
    @State private var testText = ""

    private let refreshTimer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            if !app.permissions.allGranted || !app.permissions.fnKeyConfigured {
                setupSection
            }

            trySection

            footer
        }
        .padding(24)
        .frame(width: 460)
        .onAppear { app.permissions.refresh() }
        .onReceive(refreshTimer) { _ in
            let hadAccessibility = app.permissions.accessibilityGranted
            app.permissions.refresh()
            if !hadAccessibility && app.permissions.accessibilityGranted {
                app.restartHotkey()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("SayIt")
                    .font(.title2.bold())
                Text("Hold Fn, speak, release. Your words land at the cursor.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var setupSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Setup")
                .font(.headline)

            PermissionRow(
                title: "Microphone",
                detail: "Needed to hear you. Audio never leaves this Mac.",
                granted: app.permissions.microphoneGranted,
                actionTitle: "Allow"
            ) {
                app.permissions.requestMicrophone()
            }

            PermissionRow(
                title: "Accessibility",
                detail: "Needed to detect the Fn key and type text for you.",
                granted: app.permissions.accessibilityGranted,
                actionTitle: "Open Settings"
            ) {
                app.permissions.promptAccessibility()
                app.permissions.openAccessibilitySettings()
            }

            PermissionRow(
                title: "Fn key does nothing",
                detail: "In System Settings → Keyboard, set “Press 🌐 key to” → Do Nothing so SayIt owns the key.",
                granted: app.permissions.fnKeyConfigured,
                actionTitle: "Open Keyboard Settings"
            ) {
                app.permissions.openKeyboardSettings()
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }

    private var trySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Try it")
                .font(.headline)
            Text("Click into the field below (or any app), hold **Fn**, and talk.")
                .font(.callout)
                .foregroundStyle(.secondary)
            TextEditor(text: $testText)
                .font(.body)
                .frame(height: 72)
                .padding(6)
                .background(.background, in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.separator, lineWidth: 1)
                )
        }
    }

    private var footer: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Text("You can close this window — SayIt keeps running in the menu bar.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 180)
        }
    }

    private var statusColor: Color {
        switch app.status {
        case .idle: return app.permissions.allGranted ? .green : .orange
        case .recording: return .red
        case .finishing: return .yellow
        case .inserted: return .green
        case .error: return .red
        }
    }

    private var statusText: String {
        switch app.status {
        case .idle: return app.permissions.allGranted ? "Ready — hold Fn to dictate" : "Waiting for permissions"
        case .recording: return "Listening…"
        case .finishing: return "Finishing…"
        case .inserted: return "Inserted"
        case .error(let message): return message
        }
    }
}

private struct PermissionRow: View {
    let title: String
    let detail: String
    let granted: Bool
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundStyle(granted ? .green : .secondary)
                .font(.system(size: 16))
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if !granted {
                Button(actionTitle, action: action)
                    .controlSize(.small)
            }
        }
    }
}
