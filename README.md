# SayIt

Hold **Fn**, speak, release — your words land at the cursor in whatever app you're using. A Wispr Flow-style dictation app for macOS, fully on-device.

- **STT:** Apple's `SpeechAnalyzer` / `SpeechTranscriber` (macOS 26+) — the engine behind system dictation. Streams partial results *while you hold the key*, so text appears almost instantly on release.
- **Insertion:** clipboard swap + synthesized ⌘V (previous clipboard is restored).
- **UI:** menu bar agent + a floating non-activating black pill with a live waveform. Close the window anytime — dictation keeps working.

## Requirements

- macOS 26 (Tahoe) or later, Apple Silicon
- Xcode 26+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Build & run

```sh
xcodegen generate
xcodebuild -project SayIt.xcodeproj -scheme SayIt -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/SayIt.app
```

Or open `SayIt.xcodeproj` in Xcode and hit Run.

## First-run setup (the app walks you through this)

1. **Microphone** — allow when prompted.
2. **Accessibility** — System Settings → Privacy & Security → Accessibility → enable SayIt. Needed to detect the Fn key globally and to type text for you.
3. **Free up the Fn key** — System Settings → Keyboard → “Press 🌐 key to” → **Do Nothing**, so macOS's own dictation/emoji picker doesn't fight SayIt.

Then click into any text field, hold **Fn**, talk, release.

## Dev notes

- The project is ad-hoc signed (`CODE_SIGN_IDENTITY=-`). macOS ties Accessibility permission to the binary's signature, so **after each rebuild you may need to re-toggle SayIt in the Accessibility list**. Signing with a real Apple Development certificate (set your team in Xcode) makes the grant stick.
- Not sandboxed by design — synthetic keystrokes and global event monitors are incompatible with the App Store sandbox. Distribution will be notarized direct download.
- Roadmap: history + WPM analytics → punctuation & custom dictionary settings → on-device AI smart formatting (Apple Foundation Models).
