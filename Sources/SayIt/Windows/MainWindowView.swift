import SwiftUI

/// The app window. Runs onboarding on first launch, then becomes the full
/// app shell. Closing it never stops SayIt — the menu bar agent keeps going.
struct MainWindowView: View {
    @AppStorage("onboardingComplete") private var onboardingComplete = false

    var body: some View {
        ZStack {
            if onboardingComplete {
                AppShell()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                OnboardingView {
                    onboardingComplete = true
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
            }
        }
        .animation(Theme.spring, value: onboardingComplete)
        .background(Theme.ground)
        .containerBackground(Theme.ground, for: .window)
    }
}

// MARK: - Shell

struct AppShell: View {
    @Environment(AppController.self) private var app
    @State private var page: Page = .home
    @Namespace private var selectionNamespace

    enum Page: String, CaseIterable, Identifiable {
        case home, history, dictionary, tryIt, settings

        var id: String { rawValue }

        var title: String {
            switch self {
            case .home: return "Home"
            case .history: return "History"
            case .dictionary: return "Dictionary"
            case .tryIt: return "Try it"
            case .settings: return "Settings"
            }
        }

        var icon: String {
            switch self {
            case .home: return "waveform"
            case .history: return "clock.arrow.circlepath"
            case .dictionary: return "character.book.closed.fill"
            case .tryIt: return "hand.tap.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }

    private let poll = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle()
                .fill(Theme.hairline)
                .frame(width: 1)
            ZStack {
                content
                    .id(page)
                    .transition(.opacity.combined(with: .offset(y: 10)))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(Theme.spring, value: page)
        }
        .background(Theme.ground)
        .onAppear { app.permissions.refresh() }
        .onReceive(poll) { _ in
            let hadAccessibility = app.permissions.accessibilityGranted
            app.permissions.refresh()
            if !hadAccessibility && app.permissions.accessibilityGranted {
                app.restartHotkey()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch page {
        case .home: HomeView(page: $page)
        case .history: HistoryView()
        case .dictionary: DictionaryView()
        case .tryIt: TryItView()
        case .settings: SettingsPage()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 3) {
            Wordmark(size: 16)
                .padding(.horizontal, 12)
                .padding(.top, 40) // clears the traffic lights
                .padding(.bottom, 14)

            ForEach(Page.allCases) { item in
                SidebarItem(page: item, selection: $page, namespace: selectionNamespace)
            }

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                Text(statusLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textDim)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 14)
        }
        .padding(.horizontal, 8)
        .frame(width: 184)
    }

    private var statusLabel: String {
        switch app.status {
        case .idle: return app.permissions.allGranted ? "Ready" : "Setup needed"
        case .recording: return "Listening"
        case .finishing: return "Finishing"
        case .inserted: return "Inserted"
        case .error: return "Error"
        }
    }

    private var statusColor: Color {
        switch app.status {
        case .idle: return app.permissions.allGranted ? Theme.accent : Theme.coral
        case .recording, .inserted: return Theme.accent
        case .finishing: return Theme.textFaint
        case .error: return Theme.coral
        }
    }
}

private struct SidebarItem: View {
    let page: AppShell.Page
    @Binding var selection: AppShell.Page
    var namespace: Namespace.ID
    @State private var hovering = false

    var body: some View {
        Button {
            withAnimation(Theme.spring) { selection = page }
        } label: {
            HStack(spacing: 9) {
                Image(systemName: page.icon)
                    .font(.system(size: 12.5, weight: .medium))
                    .frame(width: 18)
                    .foregroundStyle(selection == page ? Theme.accent : Theme.textDim)
                Text(page.title)
                    .font(.system(size: 12.5, weight: selection == page ? .semibold : .medium))
                    .foregroundStyle(selection == page ? Theme.text : Theme.textDim)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background {
                if selection == page {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Theme.fillSoft)
                        .matchedGeometryEffect(id: "sidebar.selection", in: namespace)
                } else if hovering {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Theme.fillFaint)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

// MARK: - Home

private struct HomeView: View {
    @Environment(AppController.self) private var app
    @Binding var page: AppShell.Page

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(greeting)
                        .font(Theme.display(24))
                        .tracking(-0.6)
                        .foregroundStyle(Theme.text)
                    Text("Hold fn anywhere you can type — release and it's written.")
                        .font(Theme.body(12.5))
                        .foregroundStyle(Theme.textDim)
                }
                .padding(.top, 8)

                hero

                HStack(spacing: 12) {
                    StatTile(value: Store.shared.lifetimeWords, label: "words dictated")
                    StatTile(value: Store.shared.lifetimeDictations, label: "dictations")
                    StatTile(value: Store.shared.averageWPM, label: "avg words/min")
                }

                if !app.permissions.allGranted || !app.permissions.fnKeyConfigured {
                    healthStrip
                }

                recent
            }
            .padding(22)
        }
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: return "Good morning."
        case 12..<18: return "Good afternoon."
        default: return "Good evening."
        }
    }

    private var hero: some View {
        HStack(spacing: 18) {
            KeyCap(size: 52)
            VStack(alignment: .leading, spacing: 4) {
                Text(app.status == .recording ? "Listening…" : "Hold fn. Start talking.")
                    .font(Theme.title(16))
                    .foregroundStyle(Theme.text)
                    .contentTransition(.opacity)
                Text(app.status == .recording
                     ? "Release the key when you're done."
                     : "Works in every app — mail, notes, chat, code.")
                    .font(Theme.body(12))
                    .foregroundStyle(Theme.textDim)
            }
            Spacer()
            WaveMark(height: 26, animated: app.status == .recording)
        }
        .card(padding: 20)
        .animation(Theme.spring, value: app.status)
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
                .foregroundStyle(Theme.text)
            Spacer()
            Button(actionTitle, action: action)
                .buttonStyle(GhostButtonStyle())
        }
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionHeader(title: "Recent")
                Spacer()
                if !Store.shared.records.isEmpty {
                    Button("See all →") {
                        withAnimation(Theme.spring) { page = .history }
                    }
                    .buttonStyle(LinkButtonStyle())
                }
            }
            if Store.shared.records.isEmpty {
                HStack(spacing: 10) {
                    WaveMark(height: 16, color: Theme.textFaint)
                    Text("Your dictations will appear here.")
                        .font(Theme.body(12))
                        .foregroundStyle(Theme.textFaint)
                }
                .padding(.vertical, 6)
            } else {
                ForEach(Store.shared.records.prefix(3)) { record in
                    HStack(spacing: 10) {
                        Text(record.text)
                            .font(Theme.body(12.5))
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)
                        Spacer()
                        Text(record.date.formatted(.relative(presentation: .named)))
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textFaint)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 16)
    }
}

private struct StatTile: View {
    var value: Int
    var label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(value)")
                .font(Theme.mono(21))
                .foregroundStyle(Theme.accent)
                .contentTransition(.numericText())
                .animation(Theme.spring, value: value)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textDim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 14)
    }
}
