# Talkie verification

## Automated checks

Run from `talkie/` on macOS:

```sh
swift test
swift format lint --strict --recursive Sources Tests Resources/GenerateIcon.swift Package.swift
bash run.sh --build-only
```

The unit tests cover allowed URL schemes, sensitive controls, terminal input, Return-key approval, text extraction, candidate uniqueness, editable-control focus, model persistence, screen geometry, and missing credentials.

The live suite is opt-in:

```sh
TALKIE_LIVE_TESTS=1 swift test --filter LiveServiceTests
```

It requires `TYPESAFE_API_KEY` (or `JEV_API_KEY`) and, for the optional provider tests, `OPENAI_API_KEY`. It exercises six routing intents, installed-app selection, literal typing selection, screen-aware conversation, and web research with citations. No external messages are sent or account data modified.

## Native UI acceptance

Use an unsaved TextEdit document and Calculator as local fixtures.

1. Build and launch with default preferences; verify no full window, Dock icon, or idle companion appears. Click the menu-bar waveform to open the compact command panel. Open History & activity and Settings explicitly, then close the full window and reopen the compact panel.
2. Configure credentials; grant Accessibility using macOS Settings. Do not modify the TCC database.
3. Ask to open Calculator and verify the actual app opens.
4. Ask to type a literal sentence into the unsaved document; verify exact text and no repetition.
5. Ask where a visible control is; verify the target outline.
6. Ask about the screen, then run a web research request and open its source link.
7. Cancel a task and reject a pending sensitive action in the compact panel; verify no later action executes and the full window stays closed. Successful actions briefly show a completion indicator, then leave the screen clear.
8. Toggle conversation persistence, restart, and verify history; turn it off and verify the file is removed.
9. Exercise microphone permission, press/release the global shortcut, dictated words, spoken responses, and imported audio review.
10. Verify compact replies, source links, errors, audio import, and approvals fit without clipping. Toggle the optional idle companion, then turn it off; progress must still appear during a task. Repeat the history/settings flows at the minimum window size.

Microphone hardware, Apple speech-model availability, and macOS privacy permission limitations must be reported separately. Provider tests establish API behavior, not end-to-end speech or Accessibility behavior.

## Current evidence

Verification used macOS ARM64 with Xcode 26.6 / Swift 6.3.3:

- Release bundle built and ad-hoc signed.
- 19 deterministic unit tests and 8 opt-in live service tests passed, including all six route cases, arithmetic continuation, literal replacement and completion.
- Native UI acceptance verified exact lowercase and single/curly-quoted TextEdit selection replacement; repeated clean Calculator runs reached 576 for 48 × 12.
- Verified visible-control highlighting, screen explanation, real cited research/source navigation, imported-audio review and explicit execution, cancellation without late actions, rejected Delete preserving text, and opt-in history restoration/deletion.
- Compact native acceptance verified quiet startup, menu-bar invocation, exact TextEdit typing and Dictate mode, cited replies/source navigation, Escape cancellation, missing-microphone notice, and both approval cancellation and an approved synthetic Delete without opening the full window.
- Imported-audio acceptance verified native chooser keyboard focus after it rendered, file selection and cancellation without leaking text into the external app, compact transcript review, and explicit Send opening Calculator.
- History and Settings open explicitly; closing them returns to quiet idle. Menu/application reopen uses the compact panel, and the optional idle companion preserves on/off choices across quit/relaunch.
- The full history/settings window remains readable at minimum and maximized size; the companion hides when it would overlap that window.
- Jev route fixture samples were approximately 73–173 ms in recent runs; these are observed samples, not a latency guarantee.
- Live microphone capture, spoken dictation and audible output remain **unverified**: the test VM exposes no audio devices. Missing-device handling was verified.
- Recordings and screenshots are linked in the PR evidence. Earlier runs exposed and drove fixes for repeated focus, quote delimiters, autocapitalization, and completion checks.
