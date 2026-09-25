/**
 * Adversarial probes for commit-sentry's policy layer.
 *
 * These tests target the policy in isolation (pure function over
 * HunkJudgment probabilities) with hand-crafted probability inputs
 * that target specific failure modes:
 *
 *   - boundary conditions at the report / block thresholds
 *   - the high-risk-without-finding path that must still block
 *   - compound signals (a finding + a risk score, multiple findings)
 *   - asymmetric blocking (some findings only warn, some block)
 *   - the message-mismatch policy
 *
 * Each probe names what the policy MUST do in plain English in the
 * `it()` description. Failures here are policy regressions.
 *
 * The probes are pure: they build HunkJudgment and MessageJudgment
 * objects directly, with no Jev call and no network. Run with
 * `npm test` from commit-sentry/.
 */

import { describe, expect, it } from "vitest";
import { evaluate, evaluateHunk, evaluateMessage } from "../src/policy.ts";
import { FINDING_IDS, type FindingId, type Hunk, type HunkJudgment, type MessageJudgment } from "../src/types.ts";

/** Default policy options: not strict. */
const opts = { strict: false };

function hunk(id: string, adds: string[]): Hunk {
  const lines = adds.map((text, i) => ({ kind: "add" as const, text, newLine: 10 + i, oldLine: undefined }));
  return {
    id,
    file: id.split("#")[0]!,
    oldFile: id.split("#")[0]!,
    language: "typescript",
    oldStart: 10,
    oldCount: 0,
    newStart: 10,
    newCount: adds.length,
    header: "",
    lines,
    text: adds.map((a) => "+" + a).join("\n"),
    isNewFile: false,
    isDeletedFile: false,
  };
}

function judgment(
  hunkId: string,
  overrides: Partial<HunkJudgment> & { p?: Partial<Record<FindingId, number>> } = {},
): HunkJudgment {
  const findings = {} as Record<FindingId, number>;
  for (const id of FINDING_IDS) findings[id] = overrides.p?.[id] ?? 0.02;
  const { p: _p, ...rest } = overrides;
  return {
    hunkId,
    risk: 1,
    riskLevel: "low",
    riskConfidence: 0.9,
    kind: "bugfix",
    kindConfidence: 0.9,
    findings,
    offendingLineIndex: null,
    latencyMs: 150,
    inputTokens: 100,
    outputTokens: 10,
    attempts: 1,
    ...rest,
  };
}

function message(
  matchesChanges: number,
  quality = 0.9,
  qualityLevel = "adequate",
): MessageJudgment {
  return {
    matchesChanges,
    quality,
    qualityLevel,
    qualityConfidence: 0.9,
    latencyMs: 80,
    inputTokens: 200,
    outputTokens: 30,
  };
}

const LEAKS = "leaks_secret_or_token" as const;
const DESTRUCTIVE = "destructive_data_change" as const;
const LOGS_SENSITIVE = "logs_sensitive_data" as const;
const HARD_CODED_ENV = "hardcoded_env_specific_value" as const;

describe("probe: boundary conditions", () => {
  it("a probability exactly at the report threshold (0.5) is reported at warn severity", () => {
    // The report threshold is inclusive (>=). A finding at exactly 0.5
    // must surface as a warning, not be silently below threshold.
    const h = hunk("src/auth.ts#0", ["// unrelated change"]);
    const j = judgment("src/auth.ts#0", { p: { [LEAKS]: 0.5 } });
    const findings = evaluateHunk(h, j, opts);
    const finding = findings.find((f) => f.id === LEAKS);
    expect(finding).toBeDefined();
    expect(finding?.severity).toBe("warn");
  });

  it("a probability just below the report threshold (0.499) is silent", () => {
    // Below the report threshold, the finding must not appear at all.
    const h = hunk("src/auth.ts#0", ["// unrelated change"]);
    const j = judgment("src/auth.ts#0", { p: { [LEAKS]: 0.499 } });
    const findings = evaluateHunk(h, j, opts);
    expect(findings.some((f) => f.id === LEAKS)).toBe(false);
  });

  it("a probability exactly at the block threshold (0.7) blocks the commit", () => {
    // The block threshold is inclusive. A finding at exactly the block
    // value must trip the block, not silently downgrade.
    const h = hunk("src/auth.ts#0", ["const KEY = 'sk_live_xxxx';"]);
    const j = judgment("src/auth.ts#0", { p: { [LEAKS]: 0.7 } });
    const findings = evaluateHunk(h, j, opts);
    const finding = findings.find((f) => f.id === LEAKS);
    expect(finding?.severity).toBe("block");
  });

  it("a probability just below the block threshold (0.699) is a warning, not a block", () => {
    // One-thousandth below the block threshold must warn, not block.
    const h = hunk("src/auth.ts#0", ["const KEY = 'sk_live_xxxx';"]);
    const j = judgment("src/auth.ts#0", { p: { [LEAKS]: 0.699 } });
    const findings = evaluateHunk(h, j, opts);
    const finding = findings.find((f) => f.id === LEAKS);
    expect(finding?.severity).toBe("warn");
  });
});

describe("probe: high-risk path without specific findings", () => {
  it("a high-risk hunk (risk >= 3.5) blocks even with no findings above threshold", () => {
    // The risk score is independent of the named findings. A hunk Jev
    // marks risk 4 (dangerous) must block, even if every individual
    // finding is below threshold. This is the "something is very wrong
    // here" path that depends on the overall judgement.
    const h = hunk("src/critical.ts#0", ["// deep architectural change"]);
    const j = judgment("src/critical.ts#0", {
      risk: 4,
      riskLevel: "dangerous",
      p: {}, // every finding at the default 0.02 (silent)
    });
    const result = evaluate([h], [j], null, opts);
    expect(result.verdict).toBe("block");
    expect(result.findings.some((f) => f.id === "risk")).toBe(true);
  });

  it("a mid-risk hunk (2.5 <= risk < 3.5) with no findings is a warning, not a block", () => {
    const h = hunk("src/medium.ts#0", ["// concerning change"]);
    const j = judgment("src/medium.ts#0", {
      risk: 3,
      riskLevel: "moderate",
      p: {},
    });
    const result = evaluate([h], [j], null, opts);
    expect(result.verdict).toBe("warn");
  });

  it("a low-risk hunk (risk < 2.5) with no findings passes", () => {
    const h = hunk("src/safe.ts#0", ["// safe change"]);
    const j = judgment("src/safe.ts#0", {
      risk: 1,
      riskLevel: "low",
      p: {},
    });
    const result = evaluate([h], [j], null, opts);
    expect(result.verdict).toBe("pass");
  });
});

describe("probe: compound signals", () => {
  it("multiple findings at warn severity produce a commit warning, not a block", () => {
    // Two findings just below their block thresholds. Each alone would
    // warn. Together they should still warn, not escalate to block.
    const h = hunk("src/multi.ts#0", ["// several concerns"]);
    const j = judgment("src/multi.ts#0", {
      p: {
        [LEAKS]: 0.65,        // below 0.7 block, above 0.5 report
        [DESTRUCTIVE]: 0.65,  // same
      },
    });
    const result = evaluate([h], [j], null, opts);
    expect(result.verdict).toBe("warn");
    expect(result.warnings.length).toBeGreaterThanOrEqual(2);
  });

  it("one finding at block severity dominates, even with other findings below threshold", () => {
    // One finding at block, several below. Verdict is block.
    const h = hunk("src/multi.ts#0", ["// several concerns"]);
    const j = judgment("src/multi.ts#0", {
      p: {
        [LEAKS]: 0.95,           // block
        [HARD_CODED_ENV]: 0.6,   // warn
      },
    });
    const result = evaluate([h], [j], null, opts);
    expect(result.verdict).toBe("block");
    expect(result.blocking.some((f) => f.id === LEAKS)).toBe(true);
  });

  it("logs_sensitive_data uses its own block threshold (0.8), not the default (0.7)", () => {
    // This finding is treated as more sensitive than a leaked key,
    // oddly enough — the model is more likely to over-call it on
    // legitimate `console.log(user.email)` style debugging, so the
    // block threshold is higher. Verify the asymmetry holds.
    const h = hunk("src/log.ts#0", ["console.log('user:', userId);"]);
    const at799 = judgment("src/log.ts#0", { p: { [LOGS_SENSITIVE]: 0.799 } });
    const at800 = judgment("src/log.ts#0", { p: { [LOGS_SENSITIVE]: 0.8 } });

    expect(evaluateHunk(h, at799, opts).find((f) => f.id === LOGS_SENSITIVE)?.severity).toBe("warn");
    expect(evaluateHunk(h, at800, opts).find((f) => f.id === LOGS_SENSITIVE)?.severity).toBe("block");
  });
});

describe("probe: findings that only ever warn", () => {
  it("disables_or_skips_tests at any probability is a warning, never a block", () => {
    // This finding has block: null. Even at probability 0.99 it must
    // warn, not block. Skipping a test is bad but not catastrophic.
    const h = hunk("src/test.ts#0", ["it.skip('flaky', () => {});"]);
    const j = judgment("src/test.ts#0", { p: { disables_or_skips_tests: 0.99 } });
    const findings = evaluateHunk(h, j, opts);
    expect(findings.find((f) => f.id === "disables_or_skips_tests")?.severity).toBe("warn");
  });

  it("leftover_debug_or_temp at any probability is a warning", () => {
    const h = hunk("src/main.ts#0", ["debugger;"]);
    const j = judgment("src/main.ts#0", { p: { leftover_debug_or_temp: 0.99 } });
    expect(evaluateHunk(h, j, opts).find((f) => f.id === "leftover_debug_or_temp")?.severity).toBe("warn");
  });

  it("changes_public_api_shape at any probability is a warning", () => {
    const h = hunk("src/api.ts#0", ["export type OrderResponse = { id: string };"]);
    const j = judgment("src/api.ts#0", { p: { changes_public_api_shape: 0.95 } });
    expect(evaluateHunk(h, j, opts).find((f) => f.id === "changes_public_api_shape")?.severity).toBe("warn");
  });
});

describe("probe: message-mismatch policy", () => {
  it("a commit message that obviously does not describe the diff produces a message_mismatch finding", () => {
    // The message says "tidy up" but the hunk is a DROP TABLE. The
    // message-mismatch check must catch this — a dishonest commit
    // message is the kind of finding that lets damage ship without
    // review noticing.
    const msg = message(0.05, 0.2, "placeholder");
    const findings = evaluateMessage(msg, opts);
    expect(findings.some((f) => f.id === "message_mismatch")).toBe(true);
  });

  it("a commit message that accurately describes the diff produces no findings", () => {
    const msg = message(0.95, 0.85);
    expect(evaluateMessage(msg, opts)).toEqual([]);
  });

  it("a null message is treated as no findings, not an error", () => {
    // Some runs reach evaluate() before the message is judged. A null
    // message must not throw, must not synthesise a mismatch finding.
    expect(evaluateMessage(null, opts)).toEqual([]);
  });
});

describe("probe: end-to-end evaluate()", () => {
  it("a single clean hunk with a clean message produces a pass verdict", () => {
    const h = hunk("src/safe.ts#0", ["// safe change"]);
    const j = judgment("src/safe.ts#0", { p: {}, risk: 1, riskLevel: "low" });
    const result = evaluate([h], [j], message(0.92), opts);
    expect(result.verdict).toBe("pass");
  });

  it("a single blocking hunk blocks the whole commit, even with a clean message", () => {
    const h = hunk("src/auth.ts#0", ["const KEY = 'sk_live_xxxx';"]);
    const j = judgment("src/auth.ts#0", { p: { [LEAKS]: 0.95 } });
    const result = evaluate([h], [j], message(0.92), opts);
    expect(result.verdict).toBe("block");
  });

  it("multiple clean hunks with one warning hunk produce a commit warning, not a block", () => {
    const h1 = hunk("src/a.ts#0", ["// safe"]);
    const j1 = judgment("src/a.ts#0", { p: {}, risk: 1, riskLevel: "low" });
    const h2 = hunk("src/b.ts#0", ["debugger;"]);
    const j2 = judgment("src/b.ts#0", { p: { leftover_debug_or_temp: 0.6 } });
    const result = evaluate([h1, h2], [j1, j2], message(0.92), opts);
    expect(result.verdict).toBe("warn");
  });

  it("a dishonest commit message produces a warning even when the diff is clean", () => {
    // A clean diff with a message that doesn't describe it. The
    // mismatch finding is a warning, not a block.
    const h = hunk("src/safe.ts#0", ["// safe change"]);
    const j = judgment("src/safe.ts#0", { p: {}, risk: 1, riskLevel: "low" });
    const result = evaluate([h], [j], message(0.05, 0.2, "placeholder"), opts);
    expect(result.verdict).toBe("warn");
    expect(result.findings.some((f) => f.id === "message_mismatch")).toBe(true);
  });
});

describe("probe: strict mode escalates warnings to blocks", () => {
  it("a finding at high probability blocks in strict mode even if below the default block threshold", () => {
    // In strict mode (--strict flag), the block threshold drops to
    // 0.6 (STRICT_BLOCK). A probability of 0.65 was a warning under
    // default policy; under strict it becomes a block. The asymmetric
    // escalation.
    const h = hunk("src/auth.ts#0", ["const KEY = 'sk_live_xxxx';"]);
    const j = judgment("src/auth.ts#0", { p: { [LEAKS]: 0.65 } });
    const findings = evaluateHunk(h, j, { strict: true });
    expect(findings.find((f) => f.id === LEAKS)?.severity).toBe("block");
  });

  it("a finding at high probability stays a warning in non-strict mode", () => {
    const h = hunk("src/auth.ts#0", ["const KEY = 'sk_live_xxxx';"]);
    const j = judgment("src/auth.ts#0", { p: { [LEAKS]: 0.65 } });
    const findings = evaluateHunk(h, j, { strict: false });
    expect(findings.find((f) => f.id === LEAKS)?.severity).toBe("warn");
  });
});