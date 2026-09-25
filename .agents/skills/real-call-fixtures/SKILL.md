---
name: real-call-fixtures
license: MIT
description: >
  Capture real wire bodies from production runs before writing parser
  fixtures. Use when integrating any model API, LLM provider, or HTTP
  service whose response shape is documented by example rather than by
  schema. The shape your tests check must come from the wire, not from
  the author's imagination of what the response looks like. Every demo in
  this repo follows this discipline; the same shape failures
  (null-padded members, alternate finish reasons, content-filter branches,
  `usage` blocks the docs didn't mention) recur against every provider.
---

# Real-call fixtures

When you integrate a model API, your parser passes its own tests and
fails on the first live call. The failure is always a shape your
fixtures didn't include: a `reasoning: null` member the provider pads
every real reply with, an `annotations` block the docs didn't list, a
`finish_reason: "tool_calls"` branch your author never saw, a content-
filter path that only triggers on certain content.

The cure is to capture real wire bodies **before** writing the parser
or any fixtures. The shape your tests check then comes from the
provider, not from the shape the integration's author imagined.

## When this applies

- Adding a model adapter for any provider (chat completions, typed-
  judgment APIs, embeddings, anything with a non-trivial response).
- Adding an HTTP client to a service whose response includes
  provider-specific padding (`usage`, `x-request-id`, custom headers).
- Maintaining an adapter whose parser has been "fixed" twice this
  month and you suspect will be fixed again.

## The rule

Before writing the parser:

1. Make **at least six live calls** against the real API under realistic
   conditions — different content, different lengths, edge cases your
   code will eventually face. Capture the **raw response body** of each
   one, unparsed, unmodified.
2. Save them as fixtures under a `fixtures/recorded/` (or equivalent)
   directory. One file per recorded call. Content-free fixtures (test
   inputs only, no PII, no real user data) — redact or replace as
   needed.
3. Write the parser. Each branch in the parser must trace to at least
   one recorded fixture that exercises it.
4. Write tests that **replay the recorded fixtures** through the
   parser. The fixtures are the test cases.
5. New fixtures get added every time a new shape failure surfaces in
   production. The fixture directory grows monotonically.

When the parser changes: the recorded fixtures are the contract. If a
change to the parser would break a recorded fixture, the change is
wrong, not the fixture.

## Why

Hand-written fixtures encode the author's imagination of what the
response looks like. The author's imagination is informed by the
docs. The docs describe the **happy path** and the **documented error
shapes**. Real traffic also includes:

- **Padding members** the provider adds to every response (`reasoning:
  null`, empty `annotations`, `usage: null`).
- **Alternate finish reasons** that only fire on certain content
  (`content_filter`, `tool_calls`, `length`, `max_tokens`).
- **Error shapes** the docs list one of, but traffic produces four of.
- **Streaming vs non-streaming divergence** — what comes back in one
  mode is not what comes back in the other.

A parser whose test suite is hand-written fixtures is, by construction,
a parser that has never been tested against the wire. Every parser
fails its first live call.

## What good looks like

A `fixtures/recorded/` directory with one JSON file per captured call.
A test runner that replays each fixture through the parser and asserts
the expected structured output. A coverage map that says "every
parser branch is exercised by fixture N." When a new shape fails in
production, the production body is saved to the fixtures directory,
the parser is fixed, and a test is added that locks it in.

Every demo in this repo's `src/` follows this shape. `commit-sentry`,
`agent-assist`, `modstream`, `log-sentinel`, `send-guard` and the
others all keep a `shared/` or `server/` directory with fixtures
captured from live runs, not shapes imagined by the author.

## What bad looks like

A `fixtures/` directory full of JSON files that mirror the parser's
own expectations. A test suite that passes because the fixtures were
written to match the parser. A parser that ships, then breaks the
first time traffic differs from the docs.

The signal is symmetry: if the fixtures and the parser were written
in the same commit, by the same author, against the same
documentation, they are testing each other, not the wire.

## Counter-example: the failure this prevents

> The adapter's closed response shape credited an absent or null
> `finish_reason` as a stop, so a real `{choices:[{message:{content:
> "ALLOW"}}]}` was treated as authorisation. The first six live calls
> all held, and the parser passed its own fixtures, because every
> fixture encoded the shape its author imagined. The defect was
> latent: it surfaced only on the first live contact, and only because
> the integration logged what it actually received.

That failure mode — *a parser that passes its own fixtures and fails
its first live call* — is what real-call fixtures prevent.

## How to apply this in this repo

The demos' shared fixture directories are the canonical examples.
Open any of them when adding a new adapter for a new demo:

- `agent-assist/src/lib/` — judgment-shape fixtures
- `commit-sentry/test/` — recorded responses per finding category
- `modstream/shared/` — judgment fixtures, both real and `MOCK=1`
- `log-sentinel/server/` — log-line fixtures across seven services
- `send-guard/src/lib/` — judgment fixtures by channel audience

Each follows the same shape: directory of recorded bodies, tests that
replay them, and a `MOCK=1` mode that uses canned answers **labelled in
the UI** when it fires.

## Boundaries

- For a service with a strict, versioned schema (e.g. an internal
  JSON-RPC API), generated types are a substitute for fixtures. The
  rule still applies when the schema has undocumented padding or
  non-error failure modes.
- For a model with a typed-judgment API (e.g. TypeSafe Jev), the
  schema is the contract. Real-call fixtures are still required for
  the **failure shapes** (429, 529, content-filter, malformed payload).
- For an LLM prompt-and-parse API, real-call fixtures are doubly
  important: the response shape varies by content, by length, and by
  the model's own tendency to wrap answers in prose.

The rule is "capture the wire before you write the parser." The rest
is mechanism.