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

1. Build and launch the app; inspect the welcome screen, resized window, settings, menu-bar reopening, and floating companion.
2. Configure credentials; grant Accessibility using macOS Settings. Do not modify the TCC database.
3. Ask to open Calculator and verify the actual app opens.
4. Ask to type a literal sentence into the unsaved document; verify exact text and no repetition.
5. Ask where a visible control is; verify the target outline.
6. Ask about the screen, then run a web research request and open its source link.
7. Cancel a task and reject a pending sensitive action; verify no later action executes.
8. Toggle conversation persistence, restart, and verify history; turn it off and verify the file is removed.
9. Exercise microphone permission, press/release the global shortcut, dictated words, spoken responses, and imported audio review.
10. Repeat the main flows at the minimum window size.

Microphone hardware, Apple speech-model availability, and macOS privacy permission limitations must be reported separately. Provider tests establish API behavior, not end-to-end speech or Accessibility behavior.

## Current evidence

The first verification pass used macOS ARM64 with Xcode 26.6 / Swift 6.3.3:

- Release bundle built and ad-hoc signed.
- 14 deterministic unit tests passed.
- All five opt-in live service tests passed, including all six route cases.
- Warm Jev decisions measured approximately 83–176 ms in the route fixture; app selection's first request took 872 ms. These are observed samples, not a latency guarantee.
- Native UI acceptance is performed separately and recorded in the PR evidence.
