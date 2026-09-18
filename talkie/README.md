# Talkie

A little voice. A lot less clicking.

Talkie is a native macOS companion built with SwiftUI, AppKit, and **Jev**. Hold **Control–Option–Space**, ask for something, and release. Talkie can operate accessible Mac apps, point to controls, explain the current screen, dictate into a focused field, and research the web with citations.

## Run

Requires macOS 14 or newer, Xcode 15.3+ or its matching Swift toolchain, and a [TypeSafe API key](https://typesafe.ai/).

```sh
cd talkie
bash run.sh
```

The script builds `build/Talkie.app`, generates its icon, signs it for local development, and starts it. `bash run.sh --build-only` produces the bundle without launching. Copy the app to Applications to launch from Finder.

In **Settings**, add your Jev key. Add an optional OpenAI key for conversation, web search, generated drafts, and imported audio transcription. Keys are stored in macOS Keychain, never the conversation file.

Developers can instead export `TYPESAFE_API_KEY` and `OPENAI_API_KEY` before running the script. `JEV_API_KEY` is also accepted when `TYPESAFE_API_KEY` is absent. Environment credentials take precedence over Keychain and are only inherited when launching from that shell.

### Connect your Mac

- **Accessibility** permits reading controls and taking actions. Use the Allow button in Talkie Settings, enable Talkie in macOS Privacy & Security, then refresh permissions.
- **Microphone and Speech Recognition** are requested the first time you speak. Live recognition runs on-device. Enable macOS Dictation for your language if Apple has not downloaded its speech models.
- **Screen Recording** is optional, for local OCR when an application exposes little accessibility text. macOS may request an app restart after granting permission.

Ad-hoc signing is for development: this build is not notarized for public distribution. Rebuilding can require granting privacy permissions again. Use a Developer ID certificate and notarization before distributing publicly.

## Try it

| Say or type | What happens |
| --- | --- |
| “Open Calculator” | Jev chooses an installed app and verifies it opened. |
| “Type ‘Hello from Talkie’ in this document” | Jev focuses a visible editor and types the supplied words. |
| “Where is the new tab button?” | An orange outline points to a visible control. |
| “Explain what’s on my screen” | A concise answer using current Accessibility text or local OCR. |
| “Research Apple's latest accessibility features” | Web research with clickable sources. |
| Select **Dictate**, then speak | Your exact words go into the previously focused app. |
| Import a short audio file | OpenAI transcribes it into the composer for review before sending. |

Auto mode lets Jev choose the route. Talk, Act, Research, and Dictate let you choose explicitly. Closing the window keeps the menu-bar app and companion running. Click the waveform in the menu bar to reopen it. **Escape** or **Stop** cancels current work; **Command–N** starts a new conversation; **Command–comma** opens Settings.

## How Jev controls the Mac

```text
speech / typed request
  → Jev route + draft-needed judgments
  → snapshot active app's Accessibility tree
  → generate a closed set of available actions in Swift
  → Jev chooses one typed action ID
  → validate, optionally ask for approval, execute
  → read the screen again; finish only with visible evidence
```

Jev uses the TypeSafe `/v1/systemone` API with `jev-latest`. It never generates shell commands or executable scripts. Actions include opening installed apps and URLs, pressing/focusing accessible controls, typing candidate text, scrolling, and named keyboard shortcuts. OpenAI supplies optional prose; Jev owns the route and action decisions.

The loop stops on cancellation, a changed foreground app, an unavailable control, repeated non-progress, low decision probability, or 24 steps. Destructive controls, sending/submitting, Terminal input, and selected shortcuts require approval. Password fields are excluded. A stop prevents future actions; it does not undo actions already completed.

## Privacy and limitations

- No always-on listening or continuous screen recording.
- Live audio is processed on-device. Imported audio is explicitly uploaded to OpenAI.
- On-screen text is sent to Jev for actions/pointing and OpenAI for conversation only when requested. Screen images stay in memory and are not uploaded or saved.
- Conversation history is off by default. Enabling it stores a local JSON file in `~/Library/Application Support/Talkie`; turning it off deletes that file.
- Actions run in the foreground and should not be combined with simultaneous manual input.
- Apps must expose usable Accessibility controls. OCR helps explain a screen but does not invent clickable coordinates.
- Gmail, Calendar, and Notion are operated through their visible app/browser interfaces; there are no dedicated OAuth connectors.
- On-device speech depends on microphone hardware, Apple speech-model availability, and the selected system language.

Inspired by [HeyClicky](https://www.heyclicky.com/). This is an original native design, with no copied private source or assets. See [research and evidence limits](docs/RESEARCH.md) and [testing](TESTING.md).

## Development

There are no third-party Swift dependencies.

```sh
swift build
swift test
swift format lint --strict --recursive Sources Tests Resources/GenerateIcon.swift Package.swift
TALKIE_LIVE_TESTS=1 swift test --filter LiveServiceTests
```

`TalkieCore` holds provider clients and pure action policy. The executable holds the native UI, permissions, speech pipeline, Keychain, Accessibility executor, and task state machine. Live tests are opt-in and use real provider credentials.
