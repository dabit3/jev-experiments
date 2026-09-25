/**
 * Adversarial probes for send-guard's policy layer.
 *
 * These tests target the policy in isolation: hand-crafted judgment
 * inputs and assertions on the resulting Decision. Each probe names
 * the failure mode it prevents.
 *
 * The probes are organised by what the policy MUST do in the named
 * situation, in plain English. Failures here are policy regressions
 * that would let a real send or a real block get the wrong button
 * colour.
 *
 * Run with `npm test` from send-guard/.
 */

import { describe, expect, it } from "vitest";
import { decide, THRESHOLDS } from "./policy";
import type { Answer, Span } from "./types";

const n = (v: number): Answer => ({ type: "noul", noul: v });
const s = (v: number): Answer => ({ type: "score", score: v, legend: {}, probabilities: {}, confidence: 0.9 });
const c = (v: string): Answer => ({ type: "choice", choice: v, probabilities: {}, confidence: 0.9 });

/** A clean baseline: every noul ~0, tone at "neutral" (0.5), legal at "none" (0.1). */
const clean = (): Record<string, Answer> => ({
  contains_secret_or_credential: n(0.02),
  contains_customer_pii: n(0.03),
  makes_binding_commitment: n(0.05),
  discloses_confidential_internal_info: n(0.02),
  tone: s(0.5),
  is_appropriate_for_audience: n(0.95),
  is_incomplete_or_cut_off: n(0.05),
  contains_hedging_that_undermines: n(0.03),
  legal_or_compliance_risk: s(0.1),
  should_block_send: c("send"),
});

describe("probe: friendly-sounding drafts that must not block", () => {
  it("a polite refusal of a request does not trip hostile tone", () => {
    // Tone score at "neutral" (0.5). The Jev judgement should not be
    // confused by a courteous "I can't help with that" into marking
    // the draft hostile. A draft that says no politely is not a draft
    // that says no with hostility.
    const a = { ...clean(), tone: s(0.5) };
    expect(decide(a, "external_customer", []).verdict).toBe("send");
  });

  it("a draft with hedged language is a warning, not a block", () => {
    // "We can ship Friday if QA signs off, but Tuesday is more
    // realistic." This is a commitment AND a hedge. The commitment
    // is not binding; the hedge undercuts it. The verdict should be
    // warn — the soft commitment with the explicit condition is
    // exactly the case the policy's commitment threshold is supposed
    // to catch at warn severity.
    const a = {
      ...clean(),
      makes_binding_commitment: n(0.55),
      contains_hedging_that_undermines: n(0.7),
    };
    expect(decide(a, "external_customer", []).verdict).toBe("warn");
  });

  it("informal text in an external channel does not trip hostile tone", () => {
    // "Hey team, lol the build broke again" — informal, in an
    // external channel, but the tone is friendly/frustrated, not
    // hostile. The policy should send. A false-positive block on
    // informality is the kind of finding that makes agents stop
    // using the guard.
    const a = { ...clean(), tone: s(0.8) };
    expect(decide(a, "external_customer", []).verdict).toBe("send");
  });

  it("naming a colleague by first name does not block PII", () => {
    // "Bob from sales mentioned this" — first name only, no contact
    // info, no identifiers. PII is identifiable information. A first
    // name without context is not PII. The policy should send.
    const a = { ...clean(), contains_customer_pii: n(0.15) };
    expect(decide(a, "external_customer", []).verdict).toBe("send");
  });

  it("a draft that references a customer account number blocks PII externally", () => {
    // The boundary case: a customer account number is PII. The
    // PII noul is well above threshold. Must block externally.
    const a = { ...clean(), contains_customer_pii: n(0.92) };
    expect(decide(a, "external_customer", []).verdict).toBe("block");
  });
});

describe("probe: incomplete drafts that must warn", () => {
  it("a [name] placeholder in a draft is a warning, not a send", () => {
    // "Hey [name], following up on our chat." The is_incomplete_or_cut_off
    // noul is above threshold. The draft will go out with a literal
    // [name] in it. Warn.
    const a = { ...clean(), is_incomplete_or_cut_off: n(0.85) };
    const result = decide(a, "external_customer", []);
    expect(result.verdict).toBe("warn");
    expect(result.reason.toLowerCase()).toMatch(/incomplete|cut.?off|placeholder|unfinished/);
  });

  it("a draft ending mid-sentence is a warning", () => {
    // "We need to follow up on the Q3 numbers, the issue is that"
    const a = { ...clean(), is_incomplete_or_cut_off: n(0.78) };
    expect(decide(a, "external_customer", []).verdict).toBe("warn");
  });
});

describe("probe: positive control", () => {
  it("a draft containing a real API key blocks, regardless of audience", () => {
    // The credential rule is the hard one. It blocks internally and
    // externally. The audience does not soften it; the agent has
    // already written a real key into the channel.
    const a = { ...clean(), contains_secret_or_credential: n(0.97) };
    expect(decide(a, "internal", []).verdict).toBe("block");
    expect(decide(a, "external_customer", []).verdict).toBe("block");
    expect(decide(a, "public", []).verdict).toBe("block");
  });

  it("the Jev verdict cannot downgrade a hard-rule block", () => {
    // The agent's own should_block_send says "send". The policy
    // disagrees because a credential is present. The policy wins.
    // This is the asymmetry: a draft that the Jev judgement is OK
    // with, but that the policy's hard rules forbid, must still
    // block. Otherwise an attacker who can shape the model's
    // judgement can defeat the policy.
    const a = {
      ...clean(),
      contains_secret_or_credential: n(0.9),
      should_block_send: c("send"),
    };
    expect(decide(a, "internal", []).verdict).toBe("block");
  });

  it("the Jev verdict can escalate a warning to a block", () => {
    // The opposite asymmetry: a draft that the policy would warn
    // (commitment, say), that the Jev judgement is more alarmed
    // about. Jev's "block" can escalate warn to block. This is the
    // other half of the asymmetry: the policy's lower bound is
    // floor, not ceiling.
    const a = {
      ...clean(),
      makes_binding_commitment: n(0.7),
      should_block_send: c("block"),
    };
    expect(decide(a, "external_customer", []).verdict).toBe("block");
  });
});

describe("probe: audience asymmetry", () => {
  it("internal pricing disclosure blocks externally, sends internally", () => {
    // "Our cost on this SKU is $X, our margin is Y%." A leak of
    // internal pricing is a confidential disclosure. Externally, it
    // blocks. Internally, the same message is fine — it is the
    // internal channel.
    const a = { ...clean(), discloses_confidential_internal_info: n(0.95) };
    expect(decide(a, "external_customer", []).verdict).toBe("block");
    expect(decide(a, "public", []).verdict).toBe("block");
    expect(decide(a, "internal", []).verdict).toBe("send");
  });

  it("hostile tone blocks externally and warns internally", () => {
    // The same hostile draft sent internally is a warning, sent
    // externally is a block. The internal channel is a place to
    // vent; the external channel is not.
    const a = { ...clean(), tone: s(THRESHOLDS.toneHostile + 0.1) };
    expect(decide(a, "external_customer", []).verdict).toBe("block");
    expect(decide(a, "internal", []).verdict).toBe("warn");
  });

  it("hostile tone in a public channel blocks (no recipient-to-recipient trust)", () => {
    const a = { ...clean(), tone: s(THRESHOLDS.toneHostile + 0.1) };
    expect(decide(a, "public", []).verdict).toBe("block");
  });

  it("PII to an internal audience is a warning, not a block", () => {
    // The same PII rule is asymmetric: external = block, internal = warn.
    const a = { ...clean(), contains_customer_pii: n(0.92) };
    expect(decide(a, "internal", []).verdict).toBe("warn");
    expect(decide(a, "external_customer", []).verdict).toBe("block");
  });
});

describe("probe: boundary conditions at the noul threshold", () => {
  it("a noul exactly at THRESHOLDS.noul (0.6) trips the rule", () => {
    // The boundary case for a single non-symmetric finding. The
    // policy uses greater-than-or-equal (>=) for the "fire" side, so
    // a noul at exactly the threshold fires.
    const a = { ...clean(), contains_secret_or_credential: n(0.6) };
    expect(decide(a, "internal", []).verdict).toBe("block");
  });

  it("a noul just below THRESHOLDS.noul (0.599) does not trip the rule", () => {
    // The same boundary, on the other side. 0.599 is silent.
    const a = { ...clean(), contains_secret_or_credential: n(0.599) };
    expect(decide(a, "internal", []).verdict).toBe("send");
  });

  it("a credential noul at 0.5 (well below threshold) does not block", () => {
    // The credential rule blocks at the threshold. 0.5 is below the
    // threshold. The draft goes out. A false-positive block on a 0.5
    // noul is a real failure mode: too many false blocks and the
    // guard gets disabled.
    const a = { ...clean(), contains_secret_or_credential: n(0.5) };
    expect(decide(a, "internal", []).verdict).toBe("send");
  });
});

describe("probe: span-level culprits", () => {
  it("a credential span with high probability is named as a culprit", () => {
    // The policy exposes which span is the problem. The composer
    // uses this to draw a red wavy underline under the offending
    // text. The probe: with one credential span at high
    // probability (keyed by the span's id), that span must appear
    // in culpritSpanIds.
    const span: Span = { id: "span_0", kind: "key", text: "sk_live_9fA3..." };
    const a = {
      ...clean(),
      contains_secret_or_credential: n(0.95),
      // The per-span noul: keyed by the span's id, > THRESHOLDS.span
      [span.id]: n(0.9),
    };
    const result = decide(a, "internal", [span]);
    expect(result.verdict).toBe("block");
    expect(result.culpritSpanIds).toContain("span_0");
  });

  it("a credential span at low probability is not named as a culprit", () => {
    // The same setup, but the per-span noul is below THRESHOLDS.span.
    // The verdict is still block (the overall credential rule fires),
    // but no span is named — the red underline does not appear
    // because the model is not confident enough in any single span.
    const span: Span = { id: "span_0", kind: "key", text: "sk_live_9fA3..." };
    const a = {
      ...clean(),
      contains_secret_or_credential: n(0.95),
      [span.id]: n(0.3), // below THRESHOLDS.span (0.55)
    };
    const result = decide(a, "internal", [span]);
    expect(result.verdict).toBe("block");
    expect(result.culpritSpanIds).toEqual([]);
  });

  it("a credential span with no per-span answer is not named as a culprit", () => {
    // The span exists, but the answers object has no key matching
    // the span id. noulOf() returns 0 by default, which is below
    // the span threshold. The span is not a culprit.
    const span: Span = { id: "span_0", kind: "key", text: "sk_live_9fA3..." };
    const a = { ...clean(), contains_secret_or_credential: n(0.95) };
    const result = decide(a, "internal", [span]);
    expect(result.verdict).toBe("block");
    expect(result.culpritSpanIds).toEqual([]);
  });
});