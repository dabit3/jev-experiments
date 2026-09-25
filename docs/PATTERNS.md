# Patterns

A pattern map for the 22 demos in this repo. Each demo is a working app; the
*patterns* are the cross-cutting design moves that show up in more than one of
them. The demos are the evidence; this document is the index.

If you are new here, read **Reading order** at the bottom. If you are adding a
new demo, this is the checklist your app should fit into.

## The shape every demo shares

Every demo has the same skeleton:

```
real state (typed)  +  small set of typed questions  +  one round trip
  -> probabilities back  ->  policy in code decides what to do
```

Code owns the workflow. The model supplies semantic understanding. Both halves
are separately testable: the policy layer is pure; the API layer has a `MOCK=1`
fallback that is visibly labelled in the UI.

The patterns below are the *specific* ways that skeleton shows up.

---

## 1. Latency-bound UI

The judgment lands before the user's next action: every keystroke, every
utterance, every chat message.

| demo | trigger | budget |
| --- | --- | --- |
| `jev-instant-search` | keystroke (250 ms debounce) | ~150 ms |
| `jev-lint` | edit (60 ms throttle, never longer) | ~108 ms |
| `nl-palette` | keystroke (100 ms debounce) | ~150 ms |
| `jev-voice-turn` | partial transcript update | ~108 ms |
| `say` | held-key release | ~120 ms |
| `agent-assist` | incoming chat message | ~93 ms |
| `send-guard` | typing pause (120 ms debounce) | ~100 ms |

The recipe is the same in all of them: a debounce that fires one request,
stale-request drop with a sequence number, a paint that holds the previous
ranking until a newer answer arrives.

## 2. Fan-out over shared state

Multiple independent questions about the same state in one round trip.
Judgments are independent, so they fan out for free; the cost is one
request, not N.

| demo | questions per call | shared state |
| --- | --- | --- |
| `agent-assist` | 9 (1 choice + 1 score + 7 noul) | last 6 messages + customer context |
| `commit-sentry` | 10 per hunk | file, language, change_type, hunk, added_lines |
| `inbox-blitz` | 7 per email | from, subject, body |
| `modstream` | 7 per message | stream, message, recent_duplicates |
| `log-sentinel` | 4 per event batched up to 16 | service, line |
| `nl-palette` | 6 per query | query + live editor state |

The reason this is a pattern, not a coincidence: when the policy needs N
judgments about one state, the round trip is the same. Speculative answers
on the losing options are essentially free.

## 3. Observable policy in code

Thresholds, weights, and rules live in pure functions over stored
probabilities. Drag a slider, the last 500 messages re-decide **with no new
inference**.

| demo | what a slider does |
| --- | --- |
| `modstream` | `harassment ≥ τ` re-sorts the mod queue |
| `send-guard` | `tone_score ≥ τ` re-paints the send button |
| `log-sentinel` | `P(actionable) ≥ τ` recolors the firehose |
| `agent-assist` | `best_macro ≥ τ` toggles between auto-fill and top-3 |
| `turbo-rerank` | relevance weight slider re-orders candidates locally |
| `judge-sheets` | inferred sort gates re-apply without re-asking |

The pattern: the model is asked once, the *answers* are stored, the policy
is a function over those answers. Changing the policy is editing a
function, not running a job.

## 4. Real-call fixtures, not hand-written shapes

Every demo has a `MOCK=1` mode that is **visibly labelled in the UI** (a
yellow badge, a header pill, a CLI flag), and a parallel set of fixtures
that are *real wire bodies* — captured from a live run, frozen, and
replayed on every test run.

The reason: the shape the model actually returns is rarely the shape the
parser author imagined. Padding members (`reasoning: null`), `usage`
blocks, alternate finish reasons, content-filter branches — every one of
these is a defect that only shows up against a real body. Hand-written
fixtures encode the author's imagination; the parser passes its own
tests and fails on the first live call.

| demo | where the real fixtures live |
| --- | --- |
| `agent-assist`, `modstream`, `log-sentinel` | `shared/` or `server/` |
| `commit-sentry` | `test/` (recorded responses per finding) |
| `send-guard` | `src/lib/` (judgment shapes) |
| `inbox-blitz` | `scripts/probe-intent.ts` CLI |

The discipline: capture wire bodies **before** writing the parser, and
before writing the next demo.

## 5. Deterministic fallback

Every demo that hits the network has a deterministic fallback. The
fallback is labelled in the UI when it fires, the `MOCK=1` mode is the
fallback taken to its logical end, and a failed request never leaves the
UI blank.

| demo | fallback shape |
| --- | --- |
| `modstream` | regex lexicon for obvious scam/harassment |
| `log-sentinel` | `ERROR\|FATAL\|panic\|OOM\|…` + HTTP 5xx + k8s `Warning` |
| `agent-assist` | keyword rule for refund eligibility |
| `inbox-blitz` | token-overlap stub |
| `commit-sentry` | heuristic flag (visible in request log) |
| `jev-ax-pilot` | press the best goal-matching element on 429/timeout |

The rule: the fallback must be **visibly different** from a real
judgment. A fallback is not a hidden path; it is a labelled degradation.

## 6. Bounded in-flight concurrency

Every high-throughput demo has a bounded FIFO, not a free-for-all.

| demo | in flight | reason |
| --- | --- | --- |
| `jev-firehose` | 96 | 300 msg/s judged with backlog 0 |
| `modstream` | 16 (adjustable) | 45 msg/s sustained |
| `log-sentinel` | 8 | 150 lines/s, batched 8 events/request |
| `commit-sentry` | 16 | 58 hunks/s |
| `agent-assist` | per-chat 1, global 8 | 8 concurrent chats |
| `jev-swarm` | batch (4–8 agents/request) | 65 decisions/s |

A bounded pool with a measured ceiling is what lets the throughput number
on the HUD be honest. Unbounded fan-out is a rate-limit and a quota
crash, not a benchmark.

## 7. Ground-truth seeded generators

Every demo that has a benchmark has a *seeded* generator that produces
known-labelled inputs. The seed is in the README. Two runs with the same
seed produce identical streams, so accuracy numbers are reproducible
across machines.

| demo | seed | size | labels per item |
| --- | --- | --- | --- |
| `inbox-blitz` | (per-run, deterministic) | 500 | category + 6 judgments |
| `modstream` | (per-run, mulberry32) | 1,000 users | action + 6 signals |
| `log-sentinel` | (per-run) | 7 services | severity + category + security |
| `jev-dispatch` | 20260917 | 275 reports | category + severity + units + dup |
| `jev-tower` | 7 (default) | 15–40 aircraft | phase + conflict |
| `agent-assist` | (per-run) | 8 chats × 5 | macro + 9 judgments |
| `turbo-rerank` | 40 hand-labelled queries | 598 passages | relevance 0–3 |

The seed is the reproducibility contract. A benchmark that depends on a
secret or an RNG is not a benchmark.

## 8. The "simulated slow LLM" baseline

Every latency-critical demo has a toggle that adds a 2–3 s synthetic
delay to a real answer. The number on the screen is the *real* number;
the toggle is the *visible* demonstration of why latency matters.

| demo | simulated delay |
| --- | --- |
| `agent-assist` | 4 s (LLM copilot baseline) |
| `send-guard` | implicit (no toggle, but the published "LLM check on Send: 2-4 s" is the contrast) |
| `log-sentinel` | 1.5 s |
| `modstream` | 2 s |
| `jev-firehose` | 2 s |
| `jev-tower` | 2.5 s (slow LLM mode) |
| `jev-swarm` | 2.5 s |
| `jev-instant-search` | 2.5 s |
| `agent-assist` (LLM toggle) | 4 s |

The pattern: the baseline is not a competitor's product. It is the
*status quo the user is comparing against* — a fixed-silence timeout, a
post-meeting summary timer, a 2-3 s prompt-and-parse LLM step. The
toggle makes the comparison falsifiable on screen.

## 9. Decoupled concerns

The state, the questions, the answer parser, the policy, the renderer,
and the network transport are separate modules. The transport can be
swapped (real API / mock / recorded) without touching the policy. The
policy can be edited without touching the renderer. The renderer can
be themed without touching the model call.

The shape shows up in every demo's `src/` layout:

```
shared/        types, questions, policy, fixture (pure)
server/        the network call (only module that touches the API)
src/           renderer + UI state
```

`server/jev.ts` is the only module that imports the SDK. `shared/policy.ts`
is the only module that turns probabilities into verdicts. The test suite
verifies the second by feeding it hand-built answers; it verifies the
first with a fake transport.

## 10. Per-app, per-port, per-readme, per-test-doc

The repo is a portfolio. There is no monorepo build; each app is its own
Node (or Swift) project with its own:

- `README.md` — the problem, the pattern, the measured numbers
- `TESTING.md` — clean install, automated coverage, deterministic
  verification, live measurement, golden path, how the screenshots were
  made
- `screenshots/` (or `docs/`) — the running app, the live metric
- `npm run dev` (or `bash run.sh`) — one command to start
- `MOCK=1 npm run dev` — one command to start offline
- port number — usually `:5173` (Vite) plus `:8787` (Node proxy)

The shape means a new demo can land without changing anything else, and
a broken demo cannot break the others. It is the same discipline as
keeping test fixtures per-file: the failure is local.

---

## What the demos deliberately avoid

- **No "smart search" feature flag.** There is no mode where the demo
  pretends to be a normal app that occasionally calls a model. Every
  demo **is** the latency-bound experience.
- **No prompt-and-parse LLM steps.** A demo that needed a chat model
  would still be a demo of "this is what 3 s feels like" — the
  contrast is the point.
- **No durable store.** Each app keeps state in memory or in a local
  file. None of them have a database. None of them need one.
- **No central config.** The TypeSafe API key is read from the shell
  per-app. There is no shared `.env` at the repo root.

If you are adding a new demo, the absence of these is a constraint, not
an oversight.

---

## Reading order for newcomers

1. `inbox-blitz` — the cleanest "ask N questions about N items"
   shape. See the latency, see the policy, see the fallback.
2. `modstream` — the latency critical case (must hold before publish).
   See the threshold slider re-decide the last 500 messages.
3. `agent-assist` — the multi-question fan-out case (9 judgments,
   8 concurrent chats, all in ~100 ms).
4. `turbo-rerank` — the cheapest re-rank in the world (one request,
   50 candidates, top-1 50% → 100%).
5. `send-guard` and `commit-sentry` — the "user takes an action, the
   policy decides whether to let them" pair.
6. `jev-voice-turn` — the voice case. Endpointing is the
   highest-value latency win in voice UX.
7. `jev-ax-pilot` — the most aggressive use of Jev in the loop
   (every UI step is a judgment).
8. `log-sentinel`, `jev-firehose` — the streaming cases. The
   through-the-line measurements.
9. `jev-tower`, `jev-dispatch`, `jev-swarm` — the simulation cases.
   The latency is in the control loop, not the front end.
10. `say` and the Swift apps — the native macOS surface, where the
    decision is "should this fire now" rather than "what should this say."

---

## How to use this document

- Adding a demo? Run it through the patterns checklist. If it doesn't
  match 1–9, write down *why* — the deviation is either a mistake or a
  pattern we don't have yet.
- Reviewing a demo? Use §10 as the test doc spec.
- Picking a demo to read? The reading order above.
- Picking a pattern to steal? Each section's `recipe` paragraph.
