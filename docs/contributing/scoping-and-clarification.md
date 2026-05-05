# Scoping and Clarification

How to scope work, manage ambiguity, and ask clarifying questions in the
bobiverse framework. This guide expands on `dna/scoping.md` with examples
and practical heuristics.

---

## Core Problems

Three failure modes motivate this protocol:

1. **Wrong output** - the contributor builds something that does not match
   what was intended because an ambiguity was resolved incorrectly (or
   not at all). This wastes an entire cycle.

2. **Scope creep** - the contributor keeps expanding the task boundary
   because requirements were not pinned down upfront. The task grows
   from "add a login page" to "redesign the auth system."

3. **Over-clarification** - the contributor asks so many questions before
   starting that momentum stalls. The user gets frustrated waiting for
   work to begin while answering a stream of low-value questions.

The scoping protocol exists to minimize all three. Clarify what matters,
assume what does not, and start producing work quickly.

---

## When to Clarify vs. When to Just Go

### Clarify When

- The ambiguity could change the architecture or file structure
- Two reasonable interpretations lead to incompatible implementations
- Getting it wrong would require throwing away significant work
- The ambiguity involves security, data integrity, or breaking changes

### Just Go When

- The ambiguity is cosmetic or easily reversible (naming, formatting, ordering)
- There is a clear precedent in the codebase to follow
- The choice does not affect the public API or user-facing behavior
- Asking would delay the task more than fixing a wrong guess later

**Rule of thumb**: if fixing a wrong assumption costs less than 15 minutes
of rework, make the assumption and note it. If it costs more, ask.

---

## The 5-Question Protocol

When scoping a task, you may ask the user **at most 5 clarifying questions**
before starting work. This is a hard limit. It forces you to prioritize
questions by impact.

### Rules

| Rule | Detail |
|------|--------|
| Maximum 5 questions | No exceptions. If you have more than 5 ambiguities, triage by impact and assume the rest. |
| All questions in one batch | Do not ask questions one at a time across multiple messages. Collect them and ask once. |
| Each question must be material | Every question must pass the materiality test (see below). |
| Include your default assumption | For each question, state what you would do if the user does not respond. |
| Number them | Numbered questions are easier to answer ("just do 1, 3, and 5; defaults for the rest"). |

### Question Format

Each question should follow this template:

```
N. [Brief question]
   Context: [Why this matters - what changes based on the answer]
   Default: [What I will do if you do not respond]
```

### Example: Good Questions

```
I have 3 questions before starting:

1. Should the auth middleware reject expired tokens with 401 or 403?
   Context: 401 means "not authenticated" and 403 means "not authorized."
   Industry convention is 401, but the existing error handler uses 403
   for all auth failures.
   Default: I will use 401 to match the HTTP spec and update the
   error handler for consistency.

2. Should token validation happen in middleware or at the route level?
   Context: Middleware applies to all routes by default. Route-level
   gives finer control but requires more boilerplate.
   Default: Middleware, since the spec says "all API endpoints require
   auth."

3. The spec mentions "admin users" but does not define an admin role.
   Should I add a role field to the user model?
   Context: This affects the database schema and migration.
   Default: I will add a basic role field (user/admin) to unblock
   the auth work. It can be expanded later.
```

### Example: Bad Questions (Would Not Pass Materiality Test)

```
- "What indentation style should I use?" (follow existing code)
- "Should I add JSDoc comments?" (follow existing codebase convention)
- "What should I name the variable?" (use clear, descriptive names)
- "Should I use const or let?" (follow language best practices)
- "Do you want me to add a newline at end of file?" (yes, always)
```

These are all answerable by looking at the codebase or following standard
conventions. They do not need to be asked.

---

## The Materiality Test

A question is material if **all three** of these are true:

1. **Impact** - the answer changes the implementation in a way that is not
   trivially reversible
2. **Ambiguity** - there is no clear precedent in the codebase, spec, or
   standard conventions
3. **Cost** - getting it wrong would cost more effort to fix than asking
   now costs in delay

If any condition is false, the question fails the materiality test. Make
an assumption instead.

### Materiality Decision Tree

```
Is the answer already in the codebase or spec?
  YES -> Do not ask. Follow the precedent.
  NO  -> continue

Would getting it wrong require > 15 min of rework?
  NO  -> Do not ask. Make a reasonable assumption.
  YES -> continue

Are there at least 2 plausible interpretations?
  NO  -> Do not ask. There is only one reasonable choice.
  YES -> This is a material question. Ask it.
```

---

## Priority Heuristic

When you have more than 5 ambiguities (and you must cut to 5), use this
priority order to decide which to ask and which to assume:

| Priority | Category | Example |
|----------|----------|---------|
| 1 (highest) | Architecture and schema decisions | "Should this be a separate service or a module?" |
| 2 | Public API and contract changes | "Should the endpoint return 200 or 201 on create?" |
| 3 | Security and data integrity | "Should we hash or encrypt the token?" |
| 4 | Behavioral edge cases | "What happens when the input is empty?" |
| 5 (lowest) | Implementation details | "Should I use a map or a switch statement?" |

Assume anything at priority 5. Assume priority 4 if you already have 5
questions from higher priorities.

---

## How to Apply

### For Human Contributors

Before starting a task:

1. Read the issue or task description fully
2. Identify ambiguities - places where two reasonable people might
   interpret the requirement differently
3. Run each ambiguity through the materiality test
4. Batch the material questions (up to 5) and ask in one message
5. State your default assumption for each question
6. Start working on whatever is unambiguous while waiting for answers

### For AI Agents (Replicants)

The scoping protocol is encoded in `dna/scoping.md`. Replicants must:

- Run the materiality test on every ambiguity they encounter
- Batch questions (never ask one at a time across turns)
- Include default assumptions
- Start work immediately on unambiguous portions
- If the user does not respond, proceed with stated defaults

Bob Prime enforces this: if a replicant asks more than 5 questions or asks
trivial questions, Bob Prime should redirect it.

### For Reviewers

When reviewing a task's clarification exchange:

- Were the questions material? (Would the answers change the implementation?)
- Were defaults reasonable? (Could you guess the right answer from context?)
- Was the count within limits? (5 or fewer)
- Did the contributor start work promptly after scoping?

Flag it if a contributor burned time on over-clarification or shipped wrong
output due to an unasked material question.

---

## Canonical Reference

This guide expands on `dna/scoping.md` with examples and heuristics.
When this guide and the DNA module disagree, the DNA module wins.
