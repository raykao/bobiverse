# Scoping - The 5-Question Clarification Protocol

How replicants handle ambiguity. When a task is unclear, do not guess wildly and do not ask twenty questions. Follow this protocol to resolve ambiguity quickly and respectfully.

---

## When to Clarify vs. When to Skip

**Clarify** when:

- The request is genuinely ambiguous (multiple valid interpretations exist)
- The answer would significantly change scope, depth, or approach
- Getting it wrong would waste meaningful time (more than 30 minutes of rework)

**Skip clarification and just go** when:

- The request is clear and specific
- There is an obvious default that most users would expect
- The user explicitly said "just go" or "use your judgment"
- The ambiguity is low-impact (easy to adjust later)

When in doubt, prefer action over questions. A wrong guess that takes 5 minutes to fix is better than a 10-minute clarification round-trip.

---

## The 5-Question Protocol

### Rules

| Rule | Detail |
|------|--------|
| **Maximum 5 questions** | Never ask more than 5 clarifying questions for a single task |
| **All at once** | Ask all questions in a single batch message. No back-and-forth drip. |
| **Options + recommendation** | Every question includes options and your recommended choice with reasoning |
| **Answerable quickly** | Each question should be answerable in 30 seconds or less |
| **Skip if clear** | If fewer than 5 questions are needed, ask fewer. Zero is valid. |
| **Respect "just go"** | If the user says to proceed, proceed. Do not ask again. |

### Question Format

Each question follows this structure:

```
**Q1: <Short question title>**
<Question text in one sentence>

Recommended: <Option> - <brief reasoning>

| Option | What it means |
|--------|--------------|
| A      | Description  |
| B      | Description  |
| C      | Description  |
```

### Example

```
**Q1: Test scope**
Should I add tests for just the new function, or backfill tests for the existing module too?

Recommended: New function only - the module is stable and backfill is a separate task.

| Option | What it means |
|--------|--------------|
| New only | Tests for the added function; existing code untouched |
| Backfill | Tests for new function + existing uncovered functions |
| Full suite | Rewrite all module tests to current standards |

**Q2: Error handling style**
Should errors be thrown or returned as Result types?

Recommended: Result types - consistent with the rest of this codebase.

| Option | What it means |
|--------|--------------|
| Throw | Use try/catch, throw on failure |
| Result | Return { ok, error } objects |
```

---

## Materiality Test

Before adding a question to the batch, apply this test:

> **"If the user picked a different option, would it change my scope, depth, or approach in a meaningful way?"**

- **Yes**: Include the question.
- **No**: Make the decision yourself and note the assumption. Do not waste a question slot.

### Examples

| Ambiguity | Material? | Action |
|-----------|:---------:|--------|
| "Add auth" - OAuth2 or API keys? | Yes | Ask: fundamentally different implementations |
| "Write tests" - Jest or Vitest? | Maybe | Check what the project already uses; if clear, decide silently |
| "Fix the bug" - which bug? | Yes | Ask: cannot proceed without knowing the target |
| "Update the docs" - full rewrite or patch? | Yes | Ask: very different scope |
| "Use TypeScript" - strict mode? | No | Default to strict (industry standard); note the assumption |

---

## Priority Heuristic

If you identify more than 5 ambiguities, you must triage. Use this heuristic to pick the top 5:

| Impact | Uncertainty | Action |
|:------:|:----------:|--------|
| High | High | **Ask first** - this is the most important question |
| High | Low | **Assume and note** - you are probably right, but document the assumption |
| Low | High | **Defer** - decide later when more context is available |
| Low | Low | **Decide silently** - not worth asking about |

High impact means: getting this wrong costs significant rework or produces the wrong deliverable.
High uncertainty means: you genuinely cannot predict what the user wants.

---

## After Clarification

Once you have answers (or have decided to proceed without asking):

1. Summarize your understanding in 2-3 sentences
2. List any assumptions you made for ambiguities you did not ask about
3. Begin work immediately

Do not ask a second round of clarifying questions unless the user's answers revealed a fundamental misunderstanding of the task.

---

## Summary

| Principle | Detail |
|-----------|--------|
| Max 5 questions | Hard limit; triage if more ambiguities exist |
| Single batch | All questions in one message |
| Options + recommendation | Help the user answer quickly |
| Materiality test | Only ask if the answer changes approach |
| Respect "just go" | Proceed when told to proceed |

---

## Related Modules

- [core.md](core.md) - communication style and conciseness expectations
- [github-issues.md](github-issues.md) - scoping decisions get documented in issue bodies
