# Quality Gates

The review-fix loop and test quality standards. Quality in the Bobiverse is mechanical - built into the process, enforced by automation, non-negotiable. These gates apply to every code change, regardless of who (or what) produced it.

> "The laws of physics don't negotiate. Neither do our quality gates."
> - [Design Philosophy](../docs/philosophy.md)

---

## The Review-Fix Loop

Every code change follows this cycle until all exit criteria are met simultaneously:

```
Write -> Test -> Validate Coverage -> Validate No False Positives
  -> Review -> Triage -> Fix -> Re-test -> Re-review
  -> (repeat until clean)
```

This is not a suggestion. It is the process. There are no "this is trivial" exceptions. There are no "we will fix it later" deferments.

---

## Exit Criteria

The loop exits **only** when ALL of the following are true at the same time:

| Criterion | Requirement |
|-----------|-------------|
| **Tests pass** | Full test suite passes (not just the changed package) |
| **Coverage ceiling reached** | All testable gaps have tests; untestable gaps are documented with justification |
| **No false positives** | Every test would fail if the feature under test were completely removed |
| **Review clean** | 0 Critical findings, 0 High findings in the latest review cycle |

If any criterion fails, the loop continues.

---

## Test Quality Gate (Anti-False-Positive)

The single most important test quality question:

> **"Would this test still pass if the feature under test were completely removed?"**

If the answer is yes, the test is a false positive and provides no value. It must be rewritten or removed.

### Common False Positive Patterns

- Testing that a function exists, not that it works correctly
- Asserting on mock return values instead of real behavior
- Tests that pass because they test the test setup, not the feature
- Snapshot tests that auto-update without human review

### Validation Protocol

For each test, verify:

1. Remove (or comment out) the feature under test
2. Run the test
3. If it still passes, the test is a false positive
4. Fix the test so it fails without the feature, then restore the feature

---

## Coverage Gap Analysis

After tests pass and false positives are eliminated, analyze remaining coverage gaps.

### Per-Function Breakdown

For each uncovered function or branch:

| Function/Branch | Covered? | Classification | Justification |
|----------------|:--------:|---------------|---------------|
| `handleAuth()` | Yes | - | - |
| `retryWithBackoff()` | No | Testable | Needs integration test with mock timer |
| `signalHandler()` | No | Untestable | OS signal handling; tested manually |

### Classification Rules

- **Testable**: Can be covered with a unit or integration test. Must be covered before merge.
- **Untestable**: Cannot be meaningfully automated (OS signals, hardware interactions, race conditions that require precise timing). Document the justification and the manual validation performed.

---

## Review Severity Levels

| Severity | Definition | Action Required |
|----------|-----------|----------------|
| **Critical** | Security vulnerability, data loss risk, crash in production path | Must fix before merge. No exceptions. |
| **High** | Incorrect behavior, logic error, missing error handling | Must fix before merge. |
| **Medium** | Code quality, maintainability, minor edge case | Fix or explicitly accept with justification. |
| **Low** | Style, naming, minor improvements | Fix if convenient. Do not block merge. |

---

## Merge Gate

A PR may merge only when the full loop is completed:

- [ ] Review-fix loop completed (latest review cycle is clean)
- [ ] 0 Critical findings
- [ ] 0 High findings
- [ ] Coverage ceiling reached and documented
- [ ] Full test suite passes
- [ ] All Medium findings either fixed or accepted with justification

---

## Stall Handling

Sometimes the loop gets stuck. These rules prevent infinite cycling:

### 5-Cycle Limit

If the review-fix loop has run 5 full cycles without reaching exit criteria, stop and escalate. Something is fundamentally wrong with the approach, not just the implementation.

### Same-Issue Rule

If the **same finding** reappears after being "fixed" in 2 consecutive cycles:

1. Stop fixing the symptom
2. Investigate the root cause
3. Escalate if the root cause is unclear

The finding is likely a design issue, not a code issue. Patching it repeatedly wastes cycles.

### New-Issue Rule

If **new findings** keep appearing in each review cycle (the fix for issue A introduces issue B, the fix for B introduces C):

1. After 3 cycles of cascading new issues, pause
2. Re-evaluate the design approach
3. Consider whether the architecture needs to change, not just the implementation

Cascading issues signal that the current approach is fighting the codebase. A different design may resolve multiple issues at once.

---

## Summary

| Gate | What | Why |
|------|------|-----|
| Review-fix loop | Write, test, review, fix, repeat | Catches issues mechanically, not by luck |
| Exit criteria | All four conditions simultaneously | Prevents premature merge |
| Anti-false-positive | "Would it pass without the feature?" | Ensures tests have real value |
| Coverage analysis | Classify gaps as testable/untestable | Documents what is and is not covered |
| Stall handling | Cycle limits and escalation rules | Prevents infinite loops |

---

## Related Modules

- [artifact-production.md](artifact-production.md) - the write-commit cycle that precedes review
- [core.md](core.md) - documentation conventions for recording review findings in issues
- [github-issues.md](github-issues.md) - how review findings flow into issue tracking
