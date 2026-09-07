import SwiftUI

@main
struct SayItApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
                .environment(AppController.shared)
        } label: {
            Image(systemName: "waveform.circle.fill")
        }

        Window("SayIt", id: WindowID.main) {
            MainWindowView()
                .environment(AppController.shared)
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .defaultLaunchBehavior(.presented)

        Settings {
            SettingsView()
                .environment(AppController.shared)
        }
    }
}

enum WindowID {
    static let main = "main"
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            AppController.shared.start()
        }
    }
}

struct MenuContent: View {
    @Environment(AppController.self) private var app
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open SayIt") {
            openWindow(id: WindowID.main)
            NSApp.activate(ignoringOtherApps: true)
        }
        SettingsLink {
            Text("Settings…")
        }
        Divider()
        Button("Quit SayIt") {
            NSApp.terminate(nil)
        }
    }
}
