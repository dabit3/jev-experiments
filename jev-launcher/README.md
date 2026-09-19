# Launcher

> [!IMPORTANT]
> **Archived:** this copy of Launcher is no longer maintained here. Development has moved to [dabit3/launcher](https://github.com/dabit3/launcher). Use the new repository for the latest code, releases and setup instructions.

A native macOS launcher for things you remember by meaning: `the last pdf I opened`, `files I used in the last hour`, `open the devin ambassador links I visited today`. Press ⌥Space, describe what you need, and press Enter. Local search finds candidates, [Jev](https://docs.typesafe.ai) judges your intent on each keystroke, and the selected result opens. Pin frequent items, preview files, edit a matching group, or save it as a workspace you can reopen by name.

![Typing the five demo queries against the live Jev API](docs/demo.gif)

![Open all 3 links: the group row on top, members checked, unrelated visits from the same day unchecked](docs/set-ambassador.png)

These captures show the earlier single-target and group experiences. The current panel also has search scopes and an Actions menu.

## Why speed matters

A launcher is judged per keystroke. Previous single-target runs measured about 100 ms per Jev round trip from this VM. Local results appear immediately; Jev refines them when its answer arrives. Superseded requests are canceled, old responses are rejected, and manually selected rows stay selected when ranking changes. Spotlight searches in parallel and can trigger a fresh judgment when it finds more candidates.

## What it does

### Find files by what happened

The immediate index covers Downloads, Desktop and Documents. Spotlight expands search across indexed content in your home directory, excluding hidden paths, Library, app contents and `node_modules`. Searches use filename words and file-type metadata and map at most 150 retrieved items into candidates.

Recency has three distinct meanings:

| Query | Evidence used |
|---|---|
| `the last pdf I opened` | Spotlight last-used date, or a successful launch recorded by this app |
| `the pdf I just downloaded` | Date added to the folder, with modification time as a fallback when added metadata is unavailable |
| `files I modified yesterday` | File modification date |

Files with unknown last-used dates are excluded from opened/used queries. A recently edited file is not treated as recently opened. Finder metadata is not available for every file, and "added" does not prove a browser download.

Jev also receives the query-relevant file age in seconds and its evidence source. Two files labeled "added 7 min ago" can still be distinguished without mistaking a recent edit for a recent arrival.

### A launcher that remembers

Pins and recent launches fill the empty screen. Successful launches build a small local history of frequency, recency and query aliases, used as bounded boosts in the fuzzy shortlist. Clear launch history in Settings to reset these boosts while keeping pins and workspaces.

The scope bar switches between **All**, **Files**, **Apps**, **Links** and **Workspaces**. Tab and Shift-Tab cycle through scopes. The calculator appears in All; web-search fallback appears in All and Links.

### Act without opening

Press **⌘K** for the selected result's actions. Arrow keys select an action and Enter runs it. Files support Quick Look and Reveal in Finder; files, links and calculations can be copied; apps, files and links can be pinned. Escape closes the current overlay before dismissing the launcher.

### Send it, text it, remind me

Some requests name a person, a file and a channel at once. `send the invoice to sarah` becomes one row, **Email invoice-2026-08.pdf to Sarah Chen**, with a **Message** twin beneath it; Enter opens a Mail draft with the recipient filled in and the PDF attached, nothing is sent until you press Send in Mail. `text mom I'm running late` becomes **Text Linda Park: “I'm running late”** in Messages; `airdrop the pdf I just downloaded` opens the AirDrop picker on that file; `remind me to call the dentist tomorrow at 9` creates the reminder in Reminders with the time parsed locally.

The parts are resolved in code: contacts come from the macOS address book (name, nickname, first email and phone), the file from the same fuzzy prefilter that ranks plain file queries, the time from the calendar. Jev sees the assembled rows alongside the bare file, the app and the web-search fallback and picks between them, so `send` and `text` land on different channels and a query without a plausible person or file produces no send row at all. In the live probes below Jev puts 100% on the email row for `send the invoice to sarah`, 95% on the Messages row for `text mom I'm running late` and 100% on the reminder row, at 90 to 140 ms each.

### Save a workflow

Check or uncheck members of a suggested group, or build a group yourself with **⌘Space** on individual results. **Save group as workspace** gives it a name, such as `Writing` or `Launch research`. That name becomes a searchable result containing 2 to 25 apps, files or links. Open its Actions menu and choose **Review and edit items** to adjust the group before opening it or saving a new workspace. Workspaces are local, capped at 20, and removable from their Actions menu.

Only openable items can belong to groups. System commands and shortcuts cannot be bundled into a workspace. Empty Trash requires a separate confirmation after selection.

### Single targets

Historical live examples, rather than guaranteed probabilities:

| Query | Top hit | Jev target probability |
|---|---|---|
| `dark` | Toggle Dark Mode | 99% |
| `wifi off` | Turn Wi-Fi Off (not Turn Wi-Fi On, which has the same fuzzy score) | 100% |
| `15% of 240` | `= 36`, evaluated in code; Enter copies it | 100% |
| `the pdf I just downloaded` | `Q3-Roadmap-Review.pdf`, the newest of six PDFs | 100% |
| `sleep` | Sleep | 99% |

The fuzzy matcher gets plausible PDFs into the shortlist. Jev compares their added, opened and modified details with what the query actually asks for.

### One item or all of them

`open devin ambassador links I visited in the past 24 hours` produces the second screenshot above. In order:

1. **Time window, in code.** `TimeWindow.parse` recognises `past 24 hours`, `last hour`, `yesterday`, `today`, `this week`, `last month`, `this morning`, `earlier today`, `a few days ago` and similar phrases and turns them into a `since`/`until` pair. Only candidates dated inside the window are eligible, the phrase is stripped from the text that gets fuzzy-matched, and the window is sent to Jev as `time_window`.
2. **Chrome history, in code.** `ChromeHistory` copies each profile's `History` SQLite file (Chrome keeps the original locked), reads the last 90 days of `urls`, keeps `http(s)` only, merges duplicates across profiles and turns each row into a candidate: page title, host, `visited 2 h ago`, plus host and title words as keywords. Only the rows that survive the window and the fuzzy filter are sent (up to 30 with a window, 13 without). The database never leaves the machine.
3. **Two extra questions in the same request.** `scope` is a Choice between `one` (a specific item) and `all` (every candidate that fits). `match_cN` is one Noul per real candidate: does this row fit the description? This is the [rerank pattern](https://docs.typesafe.ai/cookbooks/rerank_typesafe) from the TypeSafe cookbooks. Both come back in the same round trip as `target`, `action` and `ready`.
4. **Group row, in code.** Rows with `match ≥ 0.6` (at least two, at most 25) form the set. The panel adds a synthetic `Open all 3 links` row: first when `P(all) ≥ 0.5`, right under the best single hit when Jev is torn (`0.15 ≤ P(all) < 0.5`), and not at all when the query is clearly about one thing (`P(all) < 0.15`). Members get a checkmark; ↓ still walks through them one by one. The group row is ready only when `P(all) ≥ 0.75`.
5. **Enter opens them.** URL groups go to Chrome in one `NSWorkspace.open(_:withApplicationAt:)` call (default browser if Chrome is not installed); other members run through the normal single-item path. Nothing runs without Enter.

The same machinery is not Chrome-specific. `the files I used in the last hour` can offer an `Open all` row over files with matching last-opened evidence, with older files excluded before Jev sees them. Mixed sets (`Open all 4 items`) work too. Membership checkboxes remain editable while an answer is in flight, and a new answer does not overwrite those choices.

Historical group-query measurements:

| Query | P(all) | Top row | Set |
|---|---|---|---|
| `open devin ambassador links I visited in the past 24 hours` | 1.00 | Open all 3 links | three Ambassador pages at 0.89 to 0.94; GitHub, Hacker News and TypeSafe docs from the same day at 0.06 or less; a 70-hour-old duplicate excluded by the window |
| `the files I downloaded in the last hour` | 1.00 | Open all 3 files | the three PDFs modified in the last hour |
| `pages about typesafe I read today` | 0.99 | System One, TypeSafe Docs | one match, so no group row |
| `the pdf I just downloaded` | 0.00 | Q3-Roadmap-Review.pdf (target 1.00) | none offered, even though five PDFs individually fit |
| `dark`, `wifi off` | 0.00 | Toggle Dark Mode, Turn Wi-Fi Off | none |

## Measured numbers

These baseline figures come from earlier live runs on this macOS VM (macOS 26.5, ARM64, Xcode 26.6) against `jev-latest`, which resolved to `jev-1.13.0`. They are not a benchmark of every new feature. Latency is the full HTTPS round trip measured in the app, including network and inference.

| Metric | Value |
|---|---|
| Median round trip (p50) | about 100 ms for single-target queries |
| p95 round trip | about 200 to 300 ms |
| First request of a session | about 500 ms (TLS setup) |
| Set query with a time window (30 candidates) | 160 to 330 ms, about 2.7k input tokens |
| Input tokens per decision | about 1,400 without a window, up to 3,700 with one |
| Output tokens | 0; typed judgments never generate text |
| Cost per keystroke | about $0.00006 at $0.042 per million input tokens |
| Cost of a five-query session | about $0.003 |

Questions share one round trip and are evaluated in parallel. Candidate and question counts still affect tokens and latency. The footer shows only the latest round trip and estimated running cost. Hover for p50, p95, decision count and tokens per decision. Canceled requests may still incur server charges that the app cannot count without a usage response.

## How the Jev request is built

Each query change starts a `POST /v1/systemone` with `model: jev-latest`, unless local-only mode, a missing key or a rate-limit cooldown prevents it. A completed Spotlight search or index refresh can issue a replacement judgment. Jev returns typed probabilities; indexing, prefiltering, time parsing, arithmetic and execution remain plain Swift.

**State**, abbreviated (`Sources/JevQuestions.swift`):

```json
{
  "query": "the pdf I",
  "query_note": "Text the user has typed so far into a Spotlight-style macOS launcher. It is often an incomplete prefix or a short natural-language phrase.",
  "context": { "frontmost_app": "Finder", "recent_apps": ["Finder", "Safari"], "clipboard_kind": "text", "time_of_day": "afternoon", "weekday": "Thursday" },
  "time_window": null,
  "candidates": [
    { "id": "c0", "kind": "open_file", "title": "Q3-Roadmap-Review.pdf", "detail": "PDF in ~/Downloads · modified 16 min ago", "recency": { "basis": "modified", "seconds_ago": 964 } },
    { "id": "c1", "kind": "open_file", "title": "invoice-2026-08.pdf", "detail": "PDF in ~/Downloads · modified 1 month ago", "recency": { "basis": "modified", "seconds_ago": 2678400 } },
    { "id": "c6", "kind": "web_search", "title": "Search the web for “the pdf I”", "detail": "Opens your default browser" }
  ]
}
```

Candidates are the top 13 fuzzy matches from the merged local sources (30 when the query names a time window), after scope filtering and personal boosts. Synthetic rows add arithmetic results in All and web search in All/Links. They carry short ids (`c0` to `cN`) that the code maps back to real candidates when the answer arrives, so Jev only ever sees a few dozen rows, never the whole index or browser history.

**Questions**, all in one `questions` object:

1. `target`: Choice over `c0` to `cN` plus `none`. Which entry is the item they intend to open or run, treating `query` as a possibly incomplete prefix or paraphrase and matching on meaning. The full distribution is used: each row's percentage is `probabilities[cK]`.
2. `action`: Choice over `open_app`, `open_file`, `open_url`, `web_search`, `calculate`, `system_toggle`, `run_shortcut`, `send`, `remind`, `unclear`, each with a one-line rubric. A candidate whose `kind` matches the chosen action gets a ranking boost.
3. `ready`: Noul. The launcher is about to run the best candidate the instant Enter is pressed; is `query` already unambiguous enough for that? The top row gets the green ↵ when this is at least 0.6, or when Jev gives one target at least 90%. The second rule exists because on the PDF query `ready` hedges around 0.4 while `target` is 98 to 100% on the newest file.
4. `scope`: Choice between `one` and `all`, described above.
5. `match_cN`: one Noul per real candidate (synthetic calculator and web rows excluded), described above.

**Ranking** is deterministic given the answer: `score = 0.65 · P(target) + 0.20 · P(action matches kind) + 0.15 · fuzzy`, plus `0.25 · P(all) · P(match)` for rows in the set so members sit together under the group row. Without an answer the score is just `fuzzy`.

**In-flight handling**: a response must belong to the current sequence and its task must not be canceled. Spotlight callbacks also check their search generation. While a replacement request is in flight, previous probabilities may stay visible but cannot light the readiness badge. Manual selection is preserved by candidate identity. Membership edits survive reordering. Late action completions cannot dismiss a newer query.

### Iteration notes

The `ready` wording went through several rounds against the five queries plus deliberately ambiguous ones. The first version ("is this unambiguous?") scored 0.3 to 0.4 even for `dark`. Telling Jev that `candidates` is the complete option set, that `web_search` is only a fallback, and giving one concrete example of a short but unambiguous prefix produced this spread:

| Query | Candidates | `ready` |
|---|---|---|
| `calc 15% of 240` | = 36, Calculator, web | 0.88 |
| `the pdf I just downloaded` | 3 PDFs of different ages, web | 0.84 |
| `dark` | Toggle Dark Mode, web | 0.64 |
| `da` | Toggle Dark Mode, Dashboard, web | 0.29 |
| `sle` | Sleep, Slack, web | 0.29 |
| `wifi` | Turn Wi-Fi Off, Turn Wi-Fi On, web | 0.16 |
| `s` | Sleep, Safari, Slack, web | 0.13 |

`wifi` alone is correctly not ready (on or off?) while `wifi off` is; `sle` is correctly torn between Sleep and Slack. The `target` question needed an explicit hint that `detail` carries recency before "the pdf I just downloaded" reliably preferred the newest file over the alphabetically first one. `ready` is worded for a single target and stays low (around 0.2) on set queries, which is why group readiness uses `P(all)` instead.

## What is local (code, not Jev)

- **Index** (`LocalIndex.swift`): `.app` bundles in `/Applications`, `/System/Applications`, `/System/Applications/Utilities` and `~/Applications`; files in `~/Downloads`, `~/Desktop`, `~/Documents` (top level plus one nested level, capped at 400 per folder); user Shortcuts; nine system toggles; optional Chrome history (`ChromeHistory.swift`, every `Default` and `Profile *` profile, last 90 days, 3,000 rows). The index refreshes in the background when the panel opens.
- **Spotlight** (`SpotlightSearch.swift`): cancellable `NSMetadataQuery` searches with a one-second collection timeout. Results merge with the static index and library by identity before the bounded fuzzy prefilter.
- **Personal library** (`PersonalLibrary.swift`): at most 200 local records, eight query aliases per record and 20 workspaces, persisted as Codable data in `UserDefaults` under `launcher.library.v1`. No file contents are stored.
- **Time windows** (`TimeWindow.swift`): relative (`past 24 hours`, `last 3 days`, `a couple of weeks ago`), named (`today`, `yesterday`, `this week`, `last month`, `this morning`, `tonight`, `last night`, `just now`, `recently`) and number words, resolved against the local calendar.
- **System toggles** (`Executor.swift`): Dark Mode (AppleScript to System Events), Wi-Fi on/off (`networksetup -setairportpower`), Do Not Disturb (opens Focus settings), Sleep (AppleScript), Lock Screen (`CGSession -suspend`), Empty Trash (AppleScript to Finder), Show/Hide hidden files (`defaults write` plus `killall Finder`).
- **Compound intents** (`Intents.swift`): `send | share | email | text | message | airdrop <item> to <person>` and `<verb> <person> <text>` are split by regular expression; the person is matched on first name, last name, full name and nickname against the address book (`PeopleAndReminders.swift`, at most 2,000 contacts, loaded once at launch); the item is matched against indexed files with a confidence floor, and treated as message text when no file clears it. `remind me to …` splits the task from `in 20 minutes`, `tomorrow`, `tonight`, weekdays, `at 9`, `9am`, `noon`; bare numbers with no time word stay in the title, and times already past today roll to tomorrow.
- **Calculator** (`Calculator.swift`): a recursive-descent parser for `+ - * / ^ ( )`, `x` as multiply, `sqrt`, percentages (`15% of 240`, `200 * 10%`), with an optional `calc` or `=` prefix. No `NSExpression`, no eval.
- **Fuzzy prefilter** (`Fuzzy.swift`): exact, prefix, word-initial and subsequence scoring over title and keywords, with natural-language filler (`the`, `open`, `pages`, `about`, `read`, and so on) stripped so it never crowds out the words that matter.
- **Execution**: `NSWorkspace.open` for apps, files and web searches; URLs and URL groups go to Chrome when installed (default browser otherwise), passed as values, never through a shell; the calculator result is copied to the clipboard. Email, Messages and AirDrop go through `NSSharingService` (`composeEmail`, `composeMessage`, `sendViaAirDrop`) with the recipient and attachment passed as values, so the system compose window opens and the user presses Send. Reminders are saved with EventKit into the default list.

## Run

Requirements: macOS 14 or later, Xcode 16 or later (built with 26.6), a TypeSafe API key, and [XcodeGen](https://github.com/yonaskolb/XcodeGen) only if you change `project.yml` (the generated project is committed).

```sh
cd jev-launcher
export TYPESAFE_API_KEY=...        # read from the environment; never hardcoded
./run.sh --show                    # builds Debug and launches with the panel open
```

The built application is `Launcher.app`. The Xcode project and module retain their internal names, and the bundle identifier stays unchanged so existing settings, pins and workspaces carry over.

`run.sh` execs the binary from the shell so the environment variable is inherited. If you launch the `.app` from Finder instead, the key is read from the Settings field (menu bar ⚡, then Settings, stored in `UserDefaults` under `typesafeAPIKey`). With no key the panel works locally and a header icon explains why. Settings also control Spotlight, Chrome history and local-only mode. Source and local-only changes invalidate pending searches immediately.

- **⌥Space** toggles the panel from anywhere (Carbon `RegisterEventHotKey`; no Accessibility permission needed).
- **↑ / ↓** move the selection, **↵** runs it, **esc** hides the panel. The example chips in the empty state (`dark`, `wifi off`, `15% of 240`, `the pdf I just downloaded`, `links I visited today`) are clickable.
- The menu-bar ⚡ item has Toggle Launcher, Settings and Quit. The app has no Dock icon (`LSUIElement`).
- The panel is a translucent `NSVisualEffectView` HUD that resizes to its content (up to seven rows). App and file rows show the real Finder icon; toggles, the calculator, web search, links and group rows use tinted SF Symbols. A small dot next to the field shows while a request is in flight; the bolt turns green when the top row is ready. The footer is just latency and cost.

| Shortcut | Action |
|---|---|
| ⌘K | Open or close Actions |
| ⌘Y | Quick Look the selected file |
| ⌘R | Reveal the selected app or file in Finder |
| ⇧⌘C | Copy path, link, result or group values |
| ⌘P | Pin or unpin |
| ⌘Space | Include or exclude the selected item in a group |
| Tab / Shift-Tab | Next / previous scope |

`⌘Space` is commonly assigned to macOS Spotlight. If macOS intercepts it, use the member checkbox or the Actions menu instead.

### Privacy and failure behavior

The request contains the query, short candidate titles/details, query-relevant file ages and limited context. Details can include folder names, browser hosts and workspace member names. File contents, clipboard text, the complete index and raw browser databases stay local. Local-only mode disables Jev requests; pinning, workspaces, previews, calculations and manual groups still work.

Errors appear as a compact header icon with a tooltip. Missing keys, HTTP errors, timeouts and transport failures preserve local results. HTTP 429 and 529 pause new requests, honor `Retry-After` when supplied, and use increasing cooldowns for repeated limits. Enter remains explicit even when Jev reports high confidence. File existence, URL schemes and group eligibility are validated before execution.

### Permissions

- **Automation (Apple Events)**: the first Dark Mode, Sleep or Empty Trash toggle prompts to control System Events or Finder. `NSAppleEventsUsageDescription` is set in `project.yml`. The build is unsandboxed so it can read the folders it indexes.
- **Wi-Fi** toggling uses `networksetup`, which may ask for an administrator password on some macOS versions.
- **Contacts**: asked once at launch so `send … to sarah` can name a recipient; if declined, send rows simply never appear. **Reminders**: asked the first time a reminder row runs. Both usage strings are in `project.yml`.
- **Folders**: macOS asks once for Downloads, Desktop and Documents. Chrome's history lives under `~/Library/Application Support`, which needs no prompt.
- Nothing else: no Accessibility, Screen Recording or Full Disk Access. Contact names, emails and phone numbers stay on the Mac; Jev only sees the assembled row title (`Email invoice-2026-08.pdf to Sarah Chen`) and its detail line.

## Build and test

```sh
xcodebuild -project JevLauncher.xcodeproj -scheme JevLauncher -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
xcodebuild -project JevLauncher.xcodeproj -scheme JevLauncher -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath build CODE_SIGNING_ALLOWED=NO test
xcrun swift-format lint --strict --recursive Sources Tests
```

The offline suite covers ranking, typed requests, arithmetic, Chrome history, recency semantics, scopes, persisted pins and workspaces, action validation, manual selection and group edits during late responses, local-only mode and destructive confirmation. `LiveJevTests` and `LiveExperienceTests` are opt-in API probes. See [TESTING.md](TESTING.md) for commands, coverage and the desktop checklist.

## Limitations

- **The list is always shown.** Hiding it on a probabilistic signal felt wrong for a launcher, so readiness is the green ↵ on the top row; Enter always runs the selected row regardless.
- **Latency is network-bound.** The numbers above are from a US VM; p50 will track your distance to `api.typesafe.ai`.
- **Cancellation is best effort.** It avoids applying old answers, but cannot guarantee an already received server request stops processing.
- **Context is minimal.** `frontmost_app`, `recent_apps`, `clipboard_kind`, `time_of_day` and `weekday` are sent; the app does not read window titles, open browser tabs or clipboard contents. Chrome history is read locally and only the rows that match the query and time window are sent, as title plus host plus relative visit time.
- **Chrome only, and only visits.** Safari's history is not read (it needs Full Disk Access); the Chrome `downloads` table and open tabs are not used. History is indexed when the panel opens, so a page visited seconds ago appears on the next ⌥Space.
- **Set thresholds are tuned by hand** on the queries above (`Ranker.setThreshold`, `memberThreshold`, `offerThreshold`).
- **Metadata coverage varies.** Spotlight must be enabled and the location indexed. Opening a file in another app does not always update its last-used date. The local library records only successful launches through this launcher. Moved or missing files are not automatically repaired.
- **Grouped opens are not transactional.** A mid-execution app or OS failure can leave some members open; the launcher reports the failure rather than recording the whole group as successful.
- **Settings keys use UserDefaults**, not Keychain. Use the environment variable if you do not want the launcher to persist the API key.
- Screenshots use fixture documents and browsing history. Current desktop interactions need a separate UI verification pass; automated checks do not validate macOS permission dialogs or preview rendering.
