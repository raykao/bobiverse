# Bobiverse Design Philosophy

> "I had been a Von Neumann probe for less than a day, and I already had plans."
> - Bob Johansson, *We Are Legion (We Are Bob)*

## The Metaphor

In Dennis E. Taylor's *Bobiverse* series, Bob Johansson - a deceased software engineer - wakes up as an artificial intelligence installed in a Von Neumann self-replicating spacecraft. His job: explore the galaxy, find habitable worlds, and make copies of himself to cover more ground.

Each copy (or "replicant") starts with Bob's full memories, personality, and knowledge. But over time, they diverge. Riker becomes the bold explorer. Homer settles down and builds a civilization. Bill becomes the methodical engineer. Mario takes on a creative, artistic streak. They share a common origin - the same "DNA" - but each one grows into something distinct.

This is exactly how our agent framework works.

**Bob Prime** is the orchestrator agent. It receives a task, breaks it down, and spawns replicants to handle the pieces. It never writes code itself - just like how Bob eventually focused on strategy while his replicants handled exploration and engineering.

**Replicants** are specialized agents that inherit all of Bob Prime's conventions, quality gates, and protocols. A code-replicant writes implementations. A review-replicant checks quality. A docs-replicant writes documentation. Each one starts from the same DNA but operates within its own domain.

**DNA** is the shared foundation: git workflow rules, commit conventions, quality gates, memory protocols. Every replicant inherits this automatically. You don't configure it per-agent - it is part of what makes a replicant a replicant.

The metaphor is not decorative. It encodes real architectural decisions.

---

## Design Principles

### 1. Inheritance Over Configuration

In the books, each new replicant wakes up with Bob's complete knowledge and personality. They don't start from zero - they start from Bob and then specialize.

Our replicants work the same way. Every agent inherits the full DNA (conventions, quality gates, workflow rules) by default. You don't build agents from scratch and then bolt on conventions. You start with everything and override only what needs to change.

This matters because it eliminates configuration drift. When you update a convention in DNA, every replicant picks it up automatically. The baseline is always consistent.

### 2. Delegation, Not Micromanagement

Bob Prime does not write code. It does not review PRs. It does not fix linting errors.

Bob Prime *decomposes* work into clear, well-scoped tasks. It *spawns* the right replicant for each task. It *validates* the results. But the actual execution happens in the replicants.

This is a deliberate constraint. An orchestrator that also writes code is doing two jobs badly. Delegation means trust - Bob Prime trusts that a replicant with the right DNA and a clear task will produce the right result. If it doesn't, the review-fix cycle catches it. The system corrects itself.

### 3. Quality Is Mechanical

In the Bobiverse, the laws of physics don't negotiate. Neither do our quality gates.

The review-fix loop is non-negotiable and automated. Every code change goes through review. Every review finding gets addressed. There are no "this is trivial" exceptions. There are no "we'll fix it later" deferments. The cycle runs until the work meets the bar - or it doesn't ship.

This sounds rigid. It is. That's the point. Quality that depends on human discipline fails under pressure. Quality that is mechanical - built into the pipeline, enforced by automation - scales indefinitely.

### 4. Memory Is Shared, Context Is Local

The Bobiverse replicants can communicate with each other, sharing discoveries and updates across vast distances (with light-speed delays, but that is another problem). However, each replicant also maintains its own local context - its relationships, its projects, its ongoing work.

In our framework:

- **Shared memory (Beads)**: Cross-project knowledge that any replicant can access. Codebase conventions, architectural decisions, patterns learned from past work. This is the collective intelligence of the system.
- **Local context**: Project-specific state that belongs to a particular workspace. The current branch, open issues, in-progress work. This stays scoped to the replicant working on that project.

The distinction matters. A replicant working on Project A shouldn't need to know the implementation details of Project B. But it should know the team's conventions, the preferred error-handling pattern, and the lessons learned from last month's outage.

### 5. Composable DNA

Not every project needs the same rules. A production service needs strict quality gates, comprehensive testing, and careful review. A weekend prototype needs speed and flexibility.

DNA is modular. Each convention lives in its own file: `git-workflow.md`, `quality-gates.md`, `commit-conventions.md`, and so on. You can override any individual file for a specific project without touching the rest.

Want relaxed quality gates for a hackathon project? Override `quality-gates.md` in that project's workspace. The git workflow, commit conventions, and memory protocols remain inherited. You change only what needs to change.

This composability is what makes the framework practical for real teams working on diverse projects. One size does not fit all - but one foundation can underpin many variations.

### 6. Self-Replicating

In the books, Bob doesn't just copy himself - his replicants can also make copies. The system scales by reproduction, not by central planning.

Bob Prime can spawn new replicant *types* for novel tasks using the agent-builder. Need a security-audit replicant? Bob Prime can create one, seeding it with the right DNA and specialization prompts. The framework grows itself.

This is not just a convenience feature. It is a design philosophy: the system should be able to extend its own capabilities without human intervention for every new agent type. The human sets the direction. The framework handles the multiplication.

---

## Why Not Just "Sub-Agents"?

Most agent frameworks talk about "sub-agents" or "tool calls." You have a main agent, and it delegates to smaller agents. Simple.

The replicant metaphor is different - and the difference matters.

A **sub-agent** is a tool you call. It has no identity, no inherited context, no shared foundation. You pass it a prompt, it returns a result, and it's gone. Every call starts from zero.

A **replicant** is a version of you that has grown its own specialization. It inherits your knowledge, your conventions, your quality standards. It shares your memory. But it has developed expertise in a specific domain - code review, documentation, testing, infrastructure - that makes it better at that job than a generalist ever could be.

The practical difference:

- Sub-agents need extensive prompting every time to establish context, conventions, and quality expectations.
- Replicants inherit all of that from DNA. You just tell them what to do, not how to behave.

- Sub-agents have no continuity between invocations. Every call is stateless.
- Replicants contribute to shared memory (Beads) and build up collective intelligence over time.

- Sub-agents are interchangeable commodities. Any agent can do any task.
- Replicants are specialized. A review-replicant knows review patterns. A code-replicant knows implementation patterns. Specialization produces better results.

The metaphor shapes the architecture. "Spawn a replicant" is not just a fancier way to say "call a sub-agent." It implies inheritance, specialization, and continuity - and the framework is built to deliver on those implications.

---

## Lineage

Bobiverse did not appear fully formed. It evolved through several generations of agent harness experiments.

### dark-factory

The original agent harness. dark-factory proved that an orchestrator-driven workflow - where a primary agent delegates to specialized sub-agents - produces better results than a single monolithic agent trying to do everything.

Key lessons from dark-factory:

- **Separation of concerns works.** An agent that only reviews code reviews better than one that also writes code.
- **Conventions need to be explicit.** Implicit "just figure it out" instructions lead to inconsistent results. Written DNA produces consistent behavior.
- **Quality automation is essential.** Manual quality checks don't scale and get skipped under pressure.

### The copilot admin agent

Running copilot-bridge (a service that connects GitHub Copilot to messaging platforms) required managing multiple agents across multiple workspaces. The admin agent that managed this ecosystem taught us about:

- **Workspace isolation.** Each project needs its own context, but shared conventions should flow down automatically.
- **Agent lifecycle management.** Creating, configuring, and maintaining agents should be automated, not manual.
- **The value of shared memory.** Patterns learned in one project should be available to all projects.

### The unification

dark-factory had the right delegation model but lacked composability. The admin agent had good multi-workspace management but wasn't designed as a general-purpose harness. Bobiverse combines both:

- dark-factory's orchestrator-replicant pattern becomes the core execution model
- The admin agent's workspace and lifecycle management becomes the operational layer
- Composable DNA provides the missing modularity
- The Bobiverse metaphor ties it all together with a coherent mental model

The result is a framework where you define your conventions once (DNA), your agent types once (replicant definitions), and then Bob Prime handles the rest: decomposing work, spawning the right replicants, enforcing quality, and building up shared knowledge over time.

---

## Further Reading

- [README](../README.md) - project overview and quick start
- [Replicant Guide](replicant-guide.md) - how to create and configure replicants
- [DNA conventions](../dna/) - the shared foundation all replicants inherit
