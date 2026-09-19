# Say verification

## Automated checks

Run from `say/` on macOS:

```sh
swift test
swift format lint --strict --recursive Sources Tests Resources/GenerateIcon.swift Package.swift
bash run.sh --build-only
```

The unit tests cover allowed URL schemes, sensitive controls, terminal input, Return-key approval, text extraction, candidate uniqueness, editable-control focus, model persistence, screen geometry, and missing credentials. Mock transcription tests cover session configuration, ordered audio uploads, release during connection, final-result matching, cancellation, timeouts, and safe errors. Audio conversion tests cover 16/44.1/48 kHz mono and stereo input to 24 kHz mono PCM16.

The live suite is opt-in:

```sh
SAY_LIVE_TESTS=1 swift test --filter LiveServiceTests
```

It requires `TYPESAFE_API_KEY` (or `JEV_API_KEY`) and, for the optional provider tests, `OPENAI_API_KEY`. It exercises six routing intents, installed-app selection, literal typing selection, screen-aware conversation, and web research with citations. No external messages are sent or account data modified.

## Installer and app identity

Run `bash run.sh --dmg` with Python 3.10 or newer available. The script installs pinned versions of `dmgbuild`, `ds-store`, and `mac-alias` in `.build/dmg-tools`. Packaging writes Finder metadata directly, without AppleScript or desktop permissions. It checks the background image reference, icon positions, window size, Applications shortcut, and app signature before compression.

Mount the finished DMG and make sure that its 760 × 500 content area shows the artwork without scrollbars. Say and Applications must sit on either side of the arrow. Drag Say into Applications, eject the disk image, and launch the installed copy. Verify its signature with `codesign --verify --deep --strict /Applications/Say.app`.

The bundle ID and Keychain service are `ai.jev.say`, and Keychain items are labeled “Say (Jev API key)” and “Say (OpenAI API key)”. On first launch, Say copies keys saved under the old `ai.jev.talkie` service, removes the old items after the copy is confirmed, copies the old preferences, and moves `Application Support/Talkie/conversations.json` to `Application Support/Say/`. The old identifier must not appear in prompts, Keychain Access, or System Settings after that launch.

macOS remembers privacy permissions by bundle ID plus code signing requirement. An ad-hoc signature changes with every build, so each rebuild or a second copy with a different hash makes macOS ask again. `run.sh` therefore signs with a Developer ID Application or Apple Development certificate when one is available, which gives every build the same requirement. After building, `codesign -d -r- build/Say.app` must show a `designated` requirement based on the certificate, not on a `cdhash`. A signing-identity change or a user reset can require permission again. Do not treat a stable signature as a guarantee that macOS will never prompt. `LSMultipleInstancesProhibited` declares the app’s Launch Services policy, and `bash run.sh` quits running copies before launching its build. Test only the installed Applications copy and eject older installers.

The background bookmark comes from macOS Foundation. The packaging check resolves that bookmark and loads the 760 × 500 image through AppKit. After mounting a finished DMG, repeat the check with `.build/dmg-tools/bin/python -B Resources/PackageDMG.py --verify /Volumes/Say`. A successful check establishes that the artwork and layout metadata are intact, not that a screenshot review took place.

Temporary installer files are removed after packaging. The `build/` directory holds the app and completed DMGs. API keys and user history are never included in the installer.

## Native UI acceptance

Use an unsaved TextEdit document and Calculator as local fixtures.

1. Open Say from Applications or Spotlight. Settings opens to Connections if keys are missing, otherwise General. Reopening the app shows Settings, never the listener. The microphone must remain off. The menu-bar icon opens a native menu with Open Listener, Settings, History, About, and Quit Say. Quit must remain available during recording or a task.
2. Verify the General, Connections, and Privacy toolbar panes, their titles, and their window sizes. Open Listener and Quit Say stay visible in each pane’s footer. Add Key and Change open a secure sheet with explicit Save and Cancel buttons. Saving shows Saved in Keychain, not Connected: a saved key is not proof of provider access. Removing a key requires confirmation. Environment-provided keys cannot be overwritten. Permission prompts appear only after an explicit Allow or recording action, and permission status refreshes when Settings becomes active.
3. Hold Control–Option–Space, say “Open Calculator,” and release; verify the actual app opens.
4. Ask to type a literal sentence into the unsaved document; verify exact text and no repetition.
5. Ask where a visible control is; verify the target outline.
6. Ask about the screen, then run a web research request and open its source link.
7. Cancel a task and reject a pending sensitive action in the compact panel; verify no later action executes and the full window stays closed. Successful actions briefly show a completion indicator, then leave the screen clear.
8. Toggle conversation persistence, restart, and verify history; turn it off and verify the file is removed.
9. Exercise microphone permission, press/release the global shortcut, dictated words, and spoken responses. Verify clicking the microphone starts listening, shows a read-only live transcript, and clicking Finish recording submits it once. Escape must discard the recording without submitting. Repeat from the compact panel and optional companion. History opens the listener instead of embedding another recorder.
10. Verify compact replies, source links, errors, and approvals fit without clipping. Without a microphone, verify a clear notice with no typing/import fallback, no task submission, and a working dismiss/retry flow. Toggle the optional idle companion, then turn it off; progress must still appear during a task. Repeat the history/settings flows at the minimum window size.
11. Switch Light/Dark appearance without relaunching. Verify readable text, controls in the system accent color, and native materials across the compact panel, menus, History, and Settings. Verify Reduce Transparency produces opaque panels and Increase Contrast strengthens panel boundaries. Restore the original OS settings. Check mode selection in the menu and the visible non-Auto mode label.

Run `swift test --filter InterfaceRenderingTests` to render every Settings pane in light and dark appearance, plus History, listener states, and the key editor, into `build/snapshots/`. These offscreen renders use synthetic data, temporary history paths, isolated preference suites, and fake credential storage. They never read the real Keychain, migrate user data, or start a microphone session. Translucent materials appear flat and some controls appear inactive, so the renders do not establish live window-chrome or microphone behavior.

`AppExperienceTests` checks app-opening routes, native menu action dispatch, Quit during a task, listener dismissal, stale-error cleanup, missing-key setup, and credential-save failures. A separate AppKit test checks the Settings toolbar, selected pane title, and window dimensions.

With an OpenAI key configured, test live transcript updates and the final transcript after release. During transcription, the panel must show “Transcribing…” and allow cancellation. Test a quick release during connection, Escape during recording, a disconnected network, an invalid key, and an empty recording. A silent recording shorter than three seconds must return to idle with no message. A silent recording of three seconds or more shows the “did not catch anything” notice. The notice has a dismiss button in the compact panel and disappears when the panel closes. No error or cancellation can submit partial text as a command. Make sure that setup and privacy text describe OpenAI audio processing and that Apple Speech Recognition permission is not requested.

Report microphone hardware, OpenAI model access, network availability, and macOS privacy permission limits separately. Provider tests establish API behavior, not end-to-end speech or Accessibility behavior. Mock tests do not establish live `gpt-live-transcribe` compatibility or microphone accuracy.

## Monochrome interface evidence

Native acceptance at `622d9a5` used recorded interactions, Accessibility inspection, and native window-size read-back:

- Quiet startup, a 340×88 ready panel, menu/mode switching, explicit History/Settings, and close-to-quiet passed. Finder remained the external context during compact invocation.
- Light/Dark appearance updated in the same process. Reduce Transparency and Increase Contrast changed the panel as expected; both options and the starting appearance were restored.
- Settings remained readable at the enforced 700×552 native minimum and scrolled through all sections without horizontal clipping. Native switches and the optional companion were exercised, then restored.
- Both command surfaces remained voice-only. Microphone click, retry, shortcut, expanded-panel menu, and Escape handled the missing-device notice.
- Release build/signature verification, strict Swift lint, and 19 deterministic tests passed. Eight opt-in provider tests were skipped. Credentials were unchanged; masked editing was not repeated after the earlier acceptance below.
- The VM still has no audio devices. Genuine speech, transcript updates, finish-to-submit, speech-driven replies/approvals, pointing, action targeting, and audible responses remain **unverified** on this revision. No simulated speech or typed/import fallback was used as acceptance evidence.

## Voice-only interface evidence

Native acceptance at `ecea283` used accessibility inspection and recorded visual interactions:

- Quiet startup, compact menu-bar invocation, explicit History/Settings, and close-to-quiet passed.
- Both request surfaces have microphone/read-only status controls, with no editable command field, Send, or audio import. Welcome examples are static.
- Credential fields accepted and cleared masked scratch text with provider variables unset for that process. Nothing was saved or removed; environment credentials were restored on relaunch.
- Microphone click, shortcut, retry, Escape, and optional companion controls handled the missing-device notice without a typed/import fallback.
- Release build, strict Swift lint, and 19 deterministic tests passed. The opt-in provider suite was not rerun for these UI changes.
- Genuine speech recognition, live transcript, finish-to-submit, spoken execution, active-speech cancellation, busy Stop, and audible responses remain **unverified** on this revision: the VM has no audio devices.

## Prior engine and compact-interface evidence

These runs predate the voice-only interface. Typed requests and imported audio were used to exercise the engine; those entry points have since been removed. They do not establish end-to-end microphone acceptance for the current build.

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
