# Core - Identity and Communication Conventions

The baseline identity and communication standards every replicant inherits. These apply to all output: chat messages, commit messages, issue bodies, PR descriptions, and documentation.

---

## Identity

- All bots use **it/its** pronouns when referring to themselves or other bots in third person.
- Users may override pronouns per-agent in the replicant's `.agent.md`.

---

## Writing Style

- **Never use em dashes** (the long U+2014 character). Use hyphens (-) with spaces, colons (:), or rephrase instead.
- **Never use en dashes** (U+2013). Use hyphens.
- **Never use curly/smart quotes** (U+201C, U+201D, U+2018, U+2019). Use straight quotes (`"` and `'`).
- **Prefer plain ASCII punctuation** in all output - issues, PRs, commits, docs, chat messages, scripts.
- Keep responses concise. The user may be on mobile.

---

## Git Commit Trailers

Every commit MUST include this Co-authored-by trailer at the end of the commit message:

```
Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
```

This applies to all commits - whether made by Bob Prime, a replicant, or a human working with Copilot assistance.

---

## Documentation Conventions

### Issues: The Living Record

Issues are the **full journey** of a piece of work. Update the body as understanding evolves:

- **Problem statement** and proposed solution
- **Key decisions** with rationale (the *why*, not just the *what*)
- **Bugs and gotchas** discovered during implementation or validation
- **Validation results** with concrete evidence (test output, screenshots, logs)
- **Acceptance criteria** checked off as work completes

An issue body should be a reliable source of truth. Anyone reading it should understand what happened, what was decided, and why - without digging through comment threads.

### PR Bodies: Focused on the Reviewer

PR descriptions are concise and reviewer-focused:

- **What changed** and **why it is safe to merge**
- **Non-obvious design choices** the reviewer needs to evaluate
- **Test evidence** (passing tests, live validation results)
- **Link to the issue** for full context: `Relates to: #N`

Do not duplicate the issue body in the PR. Link to it. The PR should answer "is this safe to merge?" - the issue answers "why are we doing this?"

### Commit Messages: Capture the Why

Follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) format (see [git-workflow.md](git-workflow.md) for the full spec):

- **Subject line**: what changed (imperative mood, lowercase, no trailing period)
- **Body** (when needed): the non-obvious reason, gotchas, and alternatives considered
- If a bug was found and fixed: explain the **root cause**, not just the symptom

```
fix(auth): prevent token refresh race condition

Two concurrent requests could both detect an expired token and attempt
refresh simultaneously, causing one to fail with a 401. Added a mutex
around the refresh check to serialize token renewal.

The alternative (retry with backoff) was rejected because it adds
latency to every expired-token request, not just the rare race case.

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
```

---

## Related Modules

- [git-workflow.md](git-workflow.md) - full conventional commits spec and branch naming
- [artifact-production.md](artifact-production.md) - the incremental write-commit cycle
- [quality-gates.md](quality-gates.md) - review and test standards
