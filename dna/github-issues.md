# GitHub Issues - Issue Workflow and Tracking

How the Bobiverse uses GitHub Issues alongside agent-native tooling for task tracking, coordination, and visibility. GitHub Issues serve as the **human dashboard** - the place where humans (and replicants) can see the big picture at a glance.

---

## Hybrid Tracking Model

The Bobiverse uses three complementary systems:

| System | Audience | Purpose |
|--------|----------|---------|
| **GitHub Issues** | Humans + replicants | Dashboard, epics, task decomposition, acceptance criteria |
| **Beads** (`bd remember`) | Replicants | Quick-recall memory for decisions, gotchas, facts |
| **Git history** | Everyone | Artifact provenance, checkpoint recovery |

GitHub Issues are the source of truth for *what work exists and its status*. Beads are the source of truth for *what we learned along the way*. Git history is the source of truth for *what was actually built*.

---

## Epic Issues

Epics are large bodies of work decomposed into smaller tasks.

### Title Format

```
[EPIC] <description>
```

### Body Structure

```markdown
## Overview

<1-2 paragraph description of the epic's goal and scope>

## Tasks

- [ ] #12 - Implement auth module
- [ ] #13 - Add auth tests
- [ ] #14 - Update API docs for auth
- [ ] Research: evaluate OAuth providers (no issue yet)

## Acceptance Criteria

- [ ] All task issues closed
- [ ] Integration tests pass end-to-end
- [ ] Documentation updated
- [ ] Reviewed and approved by <owner>
```

### Rules

- Each checkbox links to a sub-issue where possible
- Update the epic body as tasks are added, completed, or removed
- The epic is closed only when all acceptance criteria are met

---

## Dashboard Issue

A single issue titled `[DASHBOARD] Active Work Streams` provides a live overview of all in-progress work.

### Body Structure

```markdown
## Active Work Streams

| Branch | Issue | Owner | Status | PR |
|--------|-------|-------|--------|----|
| `feat/auth-module` | #12 | code-replicant | In progress | - |
| `fix/login-timeout` | #15 | code-replicant | Review | #16 |
| `research/caching` | #18 | research-replicant | Complete | - |

## Recently Completed

| Branch | Issue | PR | Merged |
|--------|-------|----|--------|
| `feat/api-v2` | #10 | #11 | 2025-01-15 |
```

### Required Dashboard Actions

| Event | Action |
|-------|--------|
| New branch created for a task | Add a row to Active Work Streams |
| PR opened | Update the row with PR link and status "Review" |
| PR merged | Move row from Active to Recently Completed |
| Branch abandoned | Remove row; note in the issue comment why |

### Dashboard Update Protocol

**CRITICAL**: The dashboard is a shared resource. Multiple replicants may update it. Follow this protocol to prevent data loss:

1. **Always read the current body first** - `GET` the issue body before editing
2. **Parse existing rows** - do not assume you know what is there
3. **Only modify what changed** - add your row, update your row, or move your row
4. **Never build from scratch** - never replace the entire body with a freshly generated version
5. **If parse fails, stop** - do not write if you cannot parse the current state; flag for human review

This protocol prevents the most common failure mode: two replicants read the dashboard at nearly the same time, both generate a new body, and the second write overwrites the first's changes.

---

## Sync Protocol

Replicants must keep GitHub Issues in sync with their actual work:

### Before Claiming a Task

1. Read the epic issue to confirm the task is available (not already claimed)
2. Assign yourself to the task issue
3. Update the dashboard with a new row

### After Completing a Task

1. Close the task issue with a comment summarizing what was done
2. Update the epic issue body (check off the completed task)
3. Update the dashboard (move to Recently Completed or update status)

### On Session Start (Resuming Work)

1. Check the dashboard for your active rows
2. Read the relevant task issues for current state
3. Check git log in the worktree for the last checkpoint
4. Resume from the last committed state

---

## Label Strategy

Labels provide quick filtering and triage. Use these categories:

### Type Labels

| Label | Use For |
|-------|---------|
| `epic` | Epic issues that decompose into sub-tasks |
| `feature` | New functionality |
| `bug` | Something broken |
| `task` | A unit of work (not a feature or bug) |
| `research` | Investigation or analysis work |

### Priority Labels

| Label | Meaning |
|-------|---------|
| `P0` | Drop everything; fix now |
| `P1` | Must complete this sprint/cycle |
| `P2` | Should complete soon; not urgent |
| `P3` | Nice to have; do when time permits |
| `P4` | Backlog; may never be done |

### Ownership Labels

| Label | Meaning |
|-------|---------|
| `owner:agent` | Assigned to a replicant |
| `owner:human` | Requires human action or decision |

### Status Labels (Optional)

Use these only if GitHub project boards are not available:

| Label | Meaning |
|-------|---------|
| `status:blocked` | Cannot proceed; dependency or decision needed |
| `status:in-progress` | Actively being worked on |
| `status:review` | Waiting for review |

---

## Issue Templates

### Standard Task Issue

```markdown
## Problem

<What needs to be done and why>

## Approach

<Proposed solution or approach>

## Acceptance Criteria

- [ ] <Measurable criterion 1>
- [ ] <Measurable criterion 2>

## Context

- Epic: #<epic-number>
- Related: #<related-issues>
```

### Bug Issue

```markdown
## Bug Description

<What is broken>

## Reproduction Steps

1. <Step 1>
2. <Step 2>

## Expected Behavior

<What should happen>

## Actual Behavior

<What actually happens>

## Context

- Environment: <details>
- First observed: <when>
```

---

## Summary

| Concept | What | Why |
|---------|------|-----|
| Hybrid tracking | Issues + Beads + Git | Each system does what it does best |
| Epic issues | `[EPIC]` title, task checkboxes, acceptance criteria | Decomposes large work into trackable pieces |
| Dashboard issue | `[DASHBOARD]` with active work table | Single source of truth for current status |
| Update protocol | Read first, modify only your row, never rebuild | Prevents concurrent update data loss |
| Sync protocol | Check before claiming, update after completing | Keeps issues in sync with reality |
| Label strategy | Type, priority, ownership | Enables quick filtering and triage |

---

## Related Modules

- [core.md](core.md) - documentation conventions for issue and PR bodies
- [quality-gates.md](quality-gates.md) - review findings flow into issue tracking
- [memory.md](memory.md) - Beads complement issues for quick-recall facts
- [scoping.md](scoping.md) - scoping decisions get documented in issue bodies
