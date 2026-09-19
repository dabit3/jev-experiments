<p align="center">
  <img src="Resources/SayBanner.png" alt="Say. A voice companion for your Mac." width="960" />
</p>

<p align="center">
  macOS 14+ &nbsp; · &nbsp; Native Swift &nbsp; · &nbsp; Bring your own API keys
</p>

Say lives in your menu bar. Hold <kbd>Control</kbd> + <kbd>Option</kbd> + <kbd>Space</kbd>, speak, and release.

Ask it to open Calculator, type into a document, explain your screen, or look something up with sources. Choose Dictate to put your words into the app you are using. Press <kbd>Escape</kbd> to cancel.

## Get started

Open the DMG and drag Say into Applications. Eject the disk image, then open Say from Applications. To make a DMG from this source, use the build command below.

1. Open Say to see Settings, or choose Settings from its menu-bar icon.
2. In Connections, use Add Key to save a [TypeSafe](https://typesafe.ai/) key and an OpenAI key with `gpt-live-transcribe` access.
3. Allow Microphone access when you first record, and enable Accessibility so Say can operate your apps.

Opening Say never starts recording. Hold the shortcut, or choose Open Listener from the menu bar and click its microphone. Try saying “Open Calculator.”

Close the listener with its × button or Escape. Quit Say from the menu bar, the Settings footer, or Command-Q when Say is active.

Keys stay in macOS Keychain. Screen Recording permission is optional, for reading text in apps that expose few controls. This local build is signed but not Apple-notarized. If macOS blocks it, use System Settings → Privacy & Security → Open Anyway.

## What leaves your Mac

While you record, audio streams to OpenAI for transcription. Jev chooses Mac actions, and OpenAI handles conversation, web research, and drafts. Both services require internet access and bill your API usage.

On-screen text goes to those services when needed for your request. Screenshots stay on your Mac, and Say does not save audio. Conversation history is off by default.

Say asks before sensitive actions such as sending or deleting. Cancellation stops further work, but cannot undo completed actions or recall audio already sent. App control depends on the controls that macOS exposes.

## Build it

Install Xcode 15.3 or newer and Python 3.10+, then run this from the repository root:

```sh
cd say
bash run.sh --dmg
```

The installer appears in `build/`. The script installs pinned DMG tools into `.build/dmg-tools` on the first run. Run `bash run.sh` to build and launch, or `bash run.sh --build-only` for just the app. There are no third-party Swift dependencies.

The script signs with your Developer ID Application or Apple Development certificate when one is in your Keychain, so macOS remembers permissions across rebuilds. Set `SAY_SIGNING_IDENTITY` to choose a certificate. Without one, builds use an ad-hoc signature and macOS asks for permissions after every rebuild. Run one copy of Say at a time, and install from the DMG rather than launching it from the mounted disk image.

```sh
swift test
swift format lint --strict --recursive Sources Tests Resources/GenerateIcon.swift Package.swift
```

See [testing](TESTING.md) for live checks and permission setup, or [design notes](docs/RESEARCH.md) for the original references.
