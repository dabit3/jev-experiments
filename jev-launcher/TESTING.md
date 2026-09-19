# Testing Launcher

## Setup

Use macOS 14+, Xcode 16+ and the `jev-experiments/jev-launcher` directory. The Xcode project is committed. After adding or removing Swift files, regenerate it with XcodeGen:

```sh
brew install xcodegen
xcodegen generate
```

## Automated checks

```sh
xcrun swift-format lint --strict --recursive Sources Tests

xcodebuild -project JevLauncher.xcodeproj -scheme JevLauncher -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath build CODE_SIGNING_ALLOWED=NO build

xcodebuild -project JevLauncher.xcodeproj -scheme JevLauncher -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath build CODE_SIGNING_ALLOWED=NO test
```

The default suite is offline. Both live test classes skip unless `JEV_LIVE=1` and a TypeSafe API key reach the test runner. Xcode type-checks the application and tests as part of the build. The test host can emit `com.apple.linkd.autoShortcut` warnings on the VM.

### Coverage

| File | Coverage |
|---|---|
| `CalculatorTests.swift` | Arithmetic, precedence, percentages, invalid inputs and formatting |
| `RankingTests.swift` | Fuzzy matching, bounded prefilter, local fallback and Jev ranking |
| `JevQuestionsTests.swift` | Typed question schema, bounded state, ID mapping and tolerant response parsing |
| `SetsAndHistoryTests.swift` | Copied Chrome SQLite data, visit timestamps, local time windows, group membership and placement |
| `StatsAndIndexTests.swift` | Token/cost statistics, file candidates, recency wording and Wi-Fi device parsing |
| `LauncherExperienceTests.swift` | Opened/added/modified evidence, scopes, bounded personal boosts, Spotlight path filtering, execution validation, copy formatting, persistent pins/workspaces, group editing, stale replies, manual selection, local-only mode, cooldowns and Empty Trash confirmation |
| `LiveExperienceTests.swift` | Live Jev judgments over fixed candidate fixtures for last-opened PDFs, named workspaces and recently used file groups |
| `LiveJevTests.swift` | Live API against the machine's real local index and browsing fixtures |

Model tests inject a request function and use isolated `UserDefaults` suites. Executor unit tests validate routing inputs without running system commands. The confirmation test checks only the first Enter; it never empties Trash.

## Live Jev checks

The fixed-candidate probes require no disk or browser seeding and open nothing. Keep the key in the environment rather than source or command output:

```sh
TEST_RUNNER_JEV_LIVE=1 TEST_RUNNER_TYPESAFE_API_KEY="$TYPESAFE_API_KEY" \
  xcodebuild -project JevLauncher.xcodeproj -scheme JevLauncher -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath build CODE_SIGNING_ALLOWED=NO \
  -only-testing:JevLauncherTests/LiveExperienceTests test
```

These probes print the query, selected result, round-trip latency and input-token count. They validate live typed judgments but not retrieval or OS action execution.

`LiveJevTests` additionally depends on a real index containing three recent Ambassador history entries, a TypeSafe docs visit, unrelated pages, PDFs of different ages and at least two recently added files. Use a disposable macOS account and fresh valid documents. Do not overwrite personal Chrome history. Visit pages normally or seed a dedicated test profile. Results depending on a "last hour" window expire, so recreate their fixtures before running that class.

## Desktop acceptance checklist

This is a checklist for a UI pass, not a claim that every interaction has been exercised on the current revision. Run `./run.sh --show` with the key exported, or enable local-only mode in Settings.

The built product is `build/Build/Products/Debug/Launcher.app`, with executable `Contents/MacOS/Launcher`. Verify the menu bar, Quit item and macOS permission copy use Launcher.

### Search and recency

1. Verify ⌥Space opens a compact HUD and Escape dismisses it. The footer contains only latency and price.
2. Search `dark`, `wifi off`, `15% of 240` and `the pdf I just downloaded`. Local rows should appear before any Jev response.
3. Put a valid PDF several folders deep in a non-hidden home directory. Wait for Spotlight to index it, then find it by part of its filename and by file type.
4. Use `mdls -name kMDItemLastUsedDate -name kMDItemDateAdded -name kMDItemFSContentChangeDate <file>` to inspect actual evidence. Test a recently opened but old-modified PDF against a recently edited but old-opened PDF. The opened query should prefer the first.
5. A file with no last-used metadata and no launcher history should not appear as an opened-file match. Successful launcher opens should establish local evidence for subsequent queries.
6. Cycle All, Files, Apps, Links and Workspaces with Tab and Shift-Tab. Results should stay inside the chosen scope. Only All has a calculator fallback; All and Links can offer web search.

### Personal library and actions

1. Pin an app or file with ⌘P. Clear the query and confirm it appears on the home screen; restart and verify persistence.
2. Launch a file, reopen the panel, and confirm it appears among recent items.
3. Open ⌘K, navigate with arrows, and press Enter on an action. The selected candidate must remain stable if Jev replies while the menu is open.
4. Use ⌘Y on a valid PDF or image. Confirm the Quick Look window displays it. Use ⌘R and confirm Finder reveals the selected file.
5. Use ⇧⌘C and inspect the clipboard: a file path, URL, calculation result, or one value per line for a group.
6. Settings → Clear launch history must remove usage and aliases while preserving pins and saved workspaces.

### Groups and workspaces

1. Search for a set of recent files or links. A clear set intent should offer an `Open all` row, with individual results still selectable.
2. Uncheck a member while a judgment is in flight. It must remain excluded when the reply arrives.
3. Build a manual group using member actions or checkboxes. ⌘Space is also available when the system Spotlight shortcut does not intercept it.
4. Save two or more members as `Research`. Search that name in Workspaces, restart the app, and search again.
5. Open the workspace's Actions menu → Review and edit items. Remove one member and check that the group count and primary action reflect the edited selection. Save as a new workspace if desired.
6. Enter on a member opens one item; Enter on the group opens its selected members. Nothing opens from a Jev response alone.
7. Delete the workspace through Actions and verify it no longer appears.

### Failure and rapid-input behavior

1. Type a query, move down to another result, and wait for Jev. Selection should follow the same candidate identity rather than jump to index zero.
2. Rapidly replace queries and change scopes. Replies and Spotlight callbacks for old generations must not replace current results.
3. Switch to local-only mode and reopen the launcher. Search, pins, preview, workspaces, arithmetic and manual groups should remain available with no Jev requests.
4. Use an invalid API key in a separate launch or disconnect networking. Verify local results remain usable and the header warning explains the failure.
5. Remove a disposable file after retrieving it, then try to open it. An error should be shown and no successful launch should be recorded.
6. Search Empty Trash and press Enter once. A separate confirmation should appear. Press Escape to cancel. Do not confirm in an account with personal Trash contents.
7. Start a slow action, then enter another query. The old completion must not dismiss that new search.

## OS permissions and gaps

File access follows macOS folder permissions and Spotlight indexing. Dark Mode, Sleep and Empty Trash can require Automation permission. Wi-Fi behavior depends on macOS and local administrator policy. Quick Look, Finder reveal, global shortcuts and permission dialogs require a desktop pass; unit tests cannot establish their rendered behavior.

Do not execute Sleep, Lock Screen, Wi-Fi off or Empty Trash on a remote machine unless those effects are explicitly intended and recoverable. For grouped opens, a failure after some members have opened cannot roll those members back.
