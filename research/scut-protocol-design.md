# SCUT Protocol Design - Secure Communication for Unified Transports

> Synthesis document: gap analysis of external patterns vs. our existing specs, followed by the SCUT protocol design for bobiverse inter-agent communication.
>
> **Inputs**: a2a-protocol-deep-dive.md, multi-agent-patterns-survey.md, agent-security-patterns.md, dark-factory delegate_task spec, cross-channel visibility spec
>
> **Date**: 2026-04-20

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Gap Analysis](#2-gap-analysis)
3. [SCUT Philosophy and Naming](#3-scut-philosophy-and-naming)
4. [Agent Identity - SCUT Beacon](#4-agent-identity---scut-beacon)
5. [Message Format - SCUT Packet](#5-message-format---scut-packet)
6. [Communication Patterns](#6-communication-patterns)
7. [Security Model - SCUT Encryption](#7-security-model---scut-encryption)
8. [Task Lifecycle - SCUT Task](#8-task-lifecycle---scut-task)
9. [Observability - SCUT Log](#9-observability---scut-log)
10. [Implementation Phases](#10-implementation-phases)
11. [Bobiverse Concept Mapping](#11-bobiverse-concept-mapping)
12. [Comparison Matrix](#12-comparison-matrix)

---

## 1. Executive Summary

We have three layers of existing work:

- **Working today**: `ask_agent` (synchronous, 300s, allowlists, depth limits, audit)
- **Spec'd and ready**: `delegate_task` / `check_task` (async, task lifecycle, safety rails)
- **Researched**: Daedalus (Kubernetes-native A2A + NATS), hybrid comms architecture

External research reveals 8 gaps between the current ecosystem and what frameworks like A2A, MCP, CrewAI, LangGraph, and Agency Swarm offer. The most significant: no standard for chat-platform-bridged agent communication, no agent discovery, no capability negotiation, and no cryptographic identity.

SCUT unifies our existing work under a coherent protocol that addresses these gaps incrementally, while staying true to the Bobiverse metaphor: all replicants communicate via SCUT, the universal fabric that connects them across any distance.

---

## 2. Gap Analysis

### What we have vs. what the external world offers

Each gap is rated: **must-have** (blocks real use), **should-have** (significant improvement), **nice-to-have** (future refinement).

### Gap 1: Agent Discovery and Registration

| Aspect | Our current state | External state of the art |
|--------|------------------|---------------------------|
| How agents find each other | Static `canCall`/`canBeCalledBy` allowlists in config.json | A2A Agent Cards at `/.well-known/agent-card.json`; OWASP Agent Name Service with DNS-like resolution |
| Capability advertisement | None - caller must know what target can do | A2A Agent Cards list skills, supported content types, auth requirements |
| Dynamic registration | Manual config edit + bridge restart | A2A registries, MCP server discovery, Agency Swarm runtime registration |

**Priority**: Should-have. Static config works for small agent counts but breaks when replicants are spawned dynamically (the core bobiverse use case).

**Recommendation**: SCUT Beacon - a lightweight Agent Card system backed by config.json + state.db. Bob Prime queries Beacons to discover what replicants are available and what they can do.

### Gap 2: Transport Flexibility

| Aspect | Our current state | External state of the art |
|--------|------------------|---------------------------|
| Transport | Internal function calls within copilot-bridge process | A2A: JSON-RPC, gRPC, HTTP/REST. MCP: stdio, HTTP+SSE |
| Cross-process | Not supported | A2A designed for cross-network. Daedalus uses NATS JetStream. |
| Chat-platform transport | Unique to us - messages routed through Mattermost/Slack | No external framework addresses this |

**Priority**: Nice-to-have for cross-process (Daedalus handles this). Must-have to formalize our chat-platform transport as a protocol binding.

**Recommendation**: Define SCUT transport bindings: (1) internal (current function calls), (2) chat-platform (Mattermost/Slack messages), (3) A2A-compatible (HTTP, for Daedalus integration).

### Gap 3: Task Lifecycle Richness

| Aspect | Our current state (delegate_task spec) | External state of the art |
|--------|----------------------------------------|---------------------------|
| States | queued, running, completed, failed, timed_out | A2A: submitted, working, input_required, auth_required, completed, failed, canceled, rejected, unknown |
| Human-in-the-loop | Not modeled | A2A: `input_required` state. LangGraph: `interrupt()` with resume. |
| Cancellation | Out of scope v1 | A2A: `CancelTask` operation. LangGraph: graph cancellation. |
| Auth challenges | Not modeled | A2A: `auth_required` state with auth URI |

**Priority**: Should-have. `input_required` is critical for chat-platform agents where the human IS in the loop. Cancellation is needed for long-running tasks.

**Recommendation**: Extend delegate_task states to include `input_required` (agent needs human input) and `canceled`. Map to A2A states for future interop.

### Gap 4: Security - Cryptographic Identity

| Aspect | Our current state | External state of the art |
|--------|------------------|---------------------------|
| Agent identity | Bot name in config.json | A2A: Agent Cards with auth schemes. Microsoft AGT: Ed25519 keypairs. SAMVAD: Ed25519 discovery. |
| Message signing | None | A2A: JWS/JCS for Agent Card signing. A2A Secure: Ed25519 per-message signing. |
| Non-repudiation | Audit log records who called whom | Cryptographic proof via signatures |
| Tamper detection | None | Content hashing + signatures |

**Priority**: Should-have. Allowlists are sufficient for co-located agents, but message signing provides audit-grade proof for compliance and debugging.

**Recommendation**: Phase 2 of SCUT adds Ed25519 keypairs per agent (bridge generates at startup). Messages are signed. Agent Cards include public keys.

### Gap 5: Capability Negotiation

| Aspect | Our current state | External state of the art |
|--------|------------------|---------------------------|
| What can you do? | Caller must know (hardcoded in orchestrator prompts) | A2A: Agent Cards list skills. MCP: `tools/list`, `resources/list`. |
| Tool permissions | `grantTools`/`denyTools` per call | A2A: auth schemes per operation. MCP: OAuth scopes. |
| Capability tokens | Not implemented | Proposed in security research: signed tokens listing tools + scopes + expiry |

**Priority**: Should-have. Critical for dynamic replicant spawning - Bob Prime needs to ask "what can you do?" before delegating.

**Recommendation**: SCUT Beacon includes a `capabilities` field listing tools and skills. Delegation messages include capability tokens specifying what the target is allowed to do for this task.

### Gap 6: Multi-Modal Content

| Aspect | Our current state | External state of the art |
|--------|------------------|---------------------------|
| Content types | Free-text prompts and responses | A2A: Parts (TextPart, FilePart, DataPart) with MIME types. MCP: text + image + embedded resources. |
| File passing | Via workspace paths | A2A: inline binary, URL references, or structured data |
| Structured data | Not modeled | A2A: DataPart with JSON schema. MCP: structured tool results. |

**Priority**: Nice-to-have. Text-based delegation works for most cases. File/data passing becomes important for research handoffs and multi-step pipelines.

**Recommendation**: SCUT Packet payload supports typed parts (text, file reference, structured JSON). Phase 3 addition.

### Gap 7: Streaming and Real-Time Updates

| Aspect | Our current state | External state of the art |
|--------|------------------|---------------------------|
| Task progress | Callback channel message on completion | A2A: SSE streaming with artifact chunking. MCP: SSE notifications. |
| Intermediate results | Not supported | A2A: StreamResponse with working status updates. LangGraph: streaming node outputs. |
| Concurrent streams | Not addressed | A2A: multiple concurrent streams per task |

**Priority**: Should-have. Long-running tasks (research, implementation) benefit from progress updates rather than silence-then-result.

**Recommendation**: SCUT Stream - task status updates posted to callback channel as work progresses. Maps to A2A's streaming model but uses chat messages as transport.

### Gap 8: Orchestration Patterns

| Aspect | Our current state | External state of the art |
|--------|------------------|---------------------------|
| Hierarchy | Bob Prime delegates to replicants (flat) | Agency Swarm: directional flows. CrewAI: hierarchical process. AutoGen: SelectorGroupChat. |
| Broadcast | Not supported | AutoGen: group chat broadcast. Agency Swarm: shared threads. |
| Relay/forwarding | Not supported | A2A: agents can forward tasks. LangGraph: subgraph routing. |

**Priority**: Nice-to-have for v1. Bob Prime's flat delegation model works. Broadcast and relay become useful as the agent network grows.

**Recommendation**: SCUT supports three patterns: Hail (sync), Dispatch (async), and Broadcast (multi-target). Relay is Phase 4.

---

## 3. SCUT Philosophy and Naming

### The Metaphor

In the Bobiverse, SCUT (Subspace Communication Unit Technology) is the communication fabric that connects all Bob replicants across interstellar distances. Key properties:

- **Universal**: every Bob has SCUT capability, regardless of where they are
- **Asynchronous**: messages travel at finite speed - there is propagation delay
- **Secure**: encrypted and authenticated - you know who sent it
- **Discoverable**: Bobs can find each other via the SCUT network
- **Reliable**: messages are delivered even when conditions are harsh
- **Relayable**: messages can be forwarded through intermediary Bobs

Our SCUT protocol maps these properties to inter-agent communication:

| Bobiverse Concept | SCUT Protocol Concept | Implementation |
|-------------------|-----------------------|----------------|
| SCUT transceiver | SCUT-enabled agent | Any agent configured in copilot-bridge |
| SCUT frequency | SCUT Channel | A configured communication path between two agents |
| SCUT beacon | SCUT Beacon (Agent Card) | Agent identity + capabilities + auth requirements |
| SCUT message | SCUT Packet | Signed message envelope with typed payload |
| SCUT relay | SCUT Relay | Message forwarding through intermediary agents |
| SCUT range | SCUT Range | Delegation depth limit (how far a message can chain) |
| Subspace | SCUT Fabric | The bridge infrastructure (copilot-bridge + Dolt + Beads) |

### Design Principles

1. **Build on what works**: ask_agent and delegate_task are the foundation. SCUT adds structure, security, and discovery on top.
2. **Chat-native**: agents communicate through chat platforms. This is our unique advantage, not a limitation.
3. **Incremental security**: start with allowlists (Phase 0), add signing (Phase 2), add capability tokens (Phase 3).
4. **A2A-compatible data model**: use A2A concepts (Agent Cards, Tasks, Parts) adapted for our context. This enables future interop with the broader A2A ecosystem.
5. **Opaque agents**: replicants don't share internal state. Communication is via messages, not shared memory (Beads is opt-in, not mandatory).

---

## 4. Agent Identity - SCUT Beacon

A SCUT Beacon is an agent's identity card - what it is, what it can do, and how to authenticate with it. Inspired by A2A Agent Cards.

### Beacon Structure

```json
{
  "name": "researcher",
  "codename": "Riker",
  "version": "1.0.0",
  "description": "Produces structured research documents",
  "workspace": "/home/user/.copilot-bridge/workspaces/dark-factory",

  "capabilities": {
    "skills": ["research", "web-search", "github-search"],
    "tools": ["bash", "fetch", "grep", "glob", "view", "edit", "create"],
    "contentTypes": ["text/markdown"],
    "maxConcurrentTasks": 1
  },

  "auth": {
    "scheme": "bridge-internal",
    "publicKey": null
  },

  "scut": {
    "canReceive": ["hail", "dispatch"],
    "canSend": ["hail", "response", "status"],
    "maxDepth": 2,
    "defaultTimeout": 300
  }
}
```

### Discovery

**Phase 0 (today)**: Static - allowlists in config.json. Caller must know target exists.

**Phase 1**: Bridge-assisted - `list_agents` tool returns available agents with basic info (name, description, status). Beacons stored in state.db, populated from config.json + .agent.md files.

**Phase 2**: Beacon query - `query_beacon({ target: "researcher" })` returns the full Beacon. Bob Prime uses this to decide which replicant to spawn for a task.

**Phase 3**: Dynamic registration - newly spawned replicants register their Beacon with the bridge automatically. No config edit needed.

### Relationship to A2A Agent Cards

SCUT Beacons are a subset of A2A Agent Cards adapted for copilot-bridge:
- Same purpose (identity + capabilities + auth)
- Simpler structure (no HTTP endpoints, no well-known URLs)
- Bridge is the registry (not DNS or HTTP discovery)
- Future: Beacons can be exported as A2A Agent Cards for Daedalus interop

---

## 5. Message Format - SCUT Packet

Every inter-agent message is wrapped in a SCUT Packet. This is the universal envelope.

### Packet Structure

```typescript
interface SCUTPacket {
  // Identity
  id: string;                    // UUID - unique message ID
  chainId: string;               // UUID - root chain ID (same across all messages in a delegation chain)
  parentId?: string;             // parent message/task ID (for threading)
  sender: string;                // agent name (from Beacon)
  recipient: string;             // target agent name

  // Timing
  timestamp: string;             // ISO 8601 UTC
  timeout?: number;              // max seconds for response/completion

  // Type
  type: 'hail' | 'dispatch' | 'broadcast' | 'response' | 'status' | 'cancel';

  // Payload
  parts: SCUTPart[];             // typed content parts (text, file ref, structured data)

  // Security
  signature?: string;            // Ed25519 signature (Phase 2+)
  payloadHash: string;           // SHA-256 of serialized parts
  capabilities?: SCUTCapability; // what the recipient is allowed to do (Phase 3+)

  // Delegation control
  depth: number;                 // current chain depth
  budget: number;                // remaining delegation budget
  priority: 'low' | 'normal' | 'high';

  // Metadata
  metadata?: Record<string, string>;  // extensible key-value pairs
}
```

### Part Types

Inspired by A2A Parts, adapted for our text-heavy use case:

```typescript
type SCUTPart =
  | { type: 'text'; content: string }                              // plain text or markdown
  | { type: 'file'; path: string; mimeType?: string }             // workspace file reference
  | { type: 'data'; schema?: string; content: Record<string, any> } // structured JSON
```

### Capability Token

Attached to dispatch messages - defines what the recipient can do for this specific task:

```typescript
interface SCUTCapability {
  grantedTo: string;             // agent name
  grantedBy: string;             // agent name (must hold these capabilities itself)
  tools: string[];               // allowed tool names (default-deny: unlisted = unavailable)
  scopes: string[];              // e.g., ["read:workspace", "write:workbench"]
  maxDepth: number;              // how deep this agent can further delegate
  budget: number;                // how many sub-delegations allowed
  expiresAt: string;             // ISO 8601 expiry
  signature?: string;            // signed by granter's key (Phase 3+)
}
```

### Mapping to Existing Tools

| SCUT Packet field | ask_agent equivalent | delegate_task equivalent |
|-------------------|---------------------|--------------------------|
| type: 'hail' | message param | - |
| type: 'dispatch' | - | task param |
| recipient | target | target |
| capabilities.tools | grantTools/denyTools | grantTools/denyTools |
| depth | (from InterAgentContext) | (from chain_id tracking) |
| budget | maxDepth config | maxTasksPerChain config |
| priority | - | priority |
| timeout | timeout | timeout |

SCUT Packet is a superset. Existing tools map cleanly into it.

---

## 6. Communication Patterns

### Hail (Synchronous Query)

Maps to `ask_agent`. Quick question, wait for answer.

```
Bob Prime --[hail]--> Riker --[response]--> Bob Prime
```

- Blocks caller until response or timeout
- Best for: status checks, quick lookups, capability queries
- Timeout: default 60s, max 300s
- SCUT Range: counts against depth limit

### Dispatch (Asynchronous Task)

Maps to `delegate_task`. Fire and forget with lifecycle tracking.

```
Bob Prime --[dispatch]--> Homer
           <--[status: running]--
           <--[status: completed + result]--
```

- Returns immediately with task ID
- Result delivered via callback channel + task store
- Best for: implementation tasks, research, reviews (anything >60s)
- Timeout: default 600s, max 3600s
- Includes capability token scoping what Homer can do

### Broadcast (Multi-Target)

New pattern. Send to multiple agents, collect results.

```
Bob Prime --[broadcast]--> Homer
                       --> Bill
                       --> Riker
           <--[response from Homer]--
           <--[response from Bill]--
           <--[response from Riker]--
```

- Parallel dispatch to multiple recipients
- Results collected independently (some may fail)
- Best for: parallel implementation batches, multi-reviewer code review
- Each recipient gets its own capability token
- Budget divided across recipients

### Stream (Real-Time Updates)

Extension of Dispatch with progress updates.

```
Bob Prime --[dispatch]--> Homer
           <--[status: running, progress: "scaffolding"]--
           <--[status: running, progress: "writing tests"]--
           <--[status: running, progress: "validation"]--
           <--[status: completed + result]--
```

- Status updates posted to callback channel as work progresses
- Uses chat platform's native message delivery (not SSE)
- Best for: long-running tasks where silence is uncomfortable
- Optional - agent can choose not to emit progress

### Relay (Forwarded Message)

Agent A asks Agent B to forward to Agent C.

```
Bob Prime --[dispatch]--> Riker --[relay to Homer]--> Homer
                                 <--[response]--
           <--[response (relayed)]--
```

- Riker acts as intermediary, forwarding the task
- Chain depth increments for each relay hop
- Budget decrements at each hop
- Best for: when the orchestrator doesn't know which specialist to use, but a coordinator does
- Phase 4 feature

---

## 7. Security Model - SCUT Encryption

Layered security, built incrementally on what copilot-bridge already has.

### Phase 0: Allowlists and Limits (TODAY)

Already implemented in copilot-bridge:
- Bidirectional allowlists (`canCall` + `canBeCalledBy`)
- Depth limit (default: 3, prevents infinite chains)
- Visited set (same bot can't be called twice in a chain)
- Loop detector (5 identical calls in 60s = flag, 10 = critical)
- Audit logging (agent_calls table)
- Workspace sandboxing (agents can only access their workspace + granted paths)
- Tool restrictions in ephemeral sessions (grantTools/denyTools)

### Phase 1: Enhanced Limits (delegate_task spec)

From the existing spec, ready for implementation:
- `maxConcurrentDelegations` per bot (default: 3)
- `maxTasksPerChain` per chain_id (default: 10)
- `maxDelegationTimeout` (default: 600s, ceiling: 3600s)
- Task deduplication (SHA-256 hash within 5-min window)
- Bridge restart recovery (mark running tasks as timed_out)

**New additions from security research:**
- Delegation budget (max sub-delegations per root task, decrements at each hop)
- Rate limiting per caller-target pair
- Message size limits
- Circuit breaker (disable inter-agent for a pair after repeated failures)

### Phase 2: Cryptographic Identity

- Ed25519 keypair per agent (generated by bridge at startup, stored in state.db)
- Messages signed with sender's private key
- Recipient verifies signature with sender's public key (from Beacon)
- InterAgentContext is signed (tamper-proof chain metadata)
- Provides non-repudiation: cryptographic proof of who sent what

**Why Ed25519:**
- Fast: ~76,000 sign ops/sec (negligible overhead per message)
- Small keys (32 bytes public, 64 bytes private)
- No PKI required - bridge is the CA for co-located agents
- Same choice as A2A Secure, Microsoft AGT, SAMVAD

### Phase 3: Capability Tokens

- Delegation messages include signed capability tokens
- Token lists exactly which tools and scopes the recipient has for this task
- Default-deny: tools not listed in the token are unavailable
- Token has expiry (tied to task timeout)
- Granter must hold the capabilities it grants (no privilege escalation)
- Bridge enforces token at tool invocation time (deterministic, not prompt-based)

### Phase 4: Advanced Security

- Trust scoring with decay (agents that fail or produce bad results lose trust over time)
- Content scanning on inter-agent messages (detect prompt injection attempts)
- At-rest encryption for stored tasks (envelope encryption: DEK encrypted by KEK)
- Policy engine with declarative rules (YAML security policies)

### Threat Mitigations

| Threat | OWASP ASI | Mitigation | Phase |
|--------|-----------|------------|-------|
| Prompt injection via inter-agent messages | ASI-01 | Content scanning + capability tokens (limit blast radius) | 3-4 |
| Privilege escalation (A tricks B into using tools A can't) | ASI-07 | Capability tokens enforce tool access. Granter can't grant what it doesn't have. | 3 |
| Data exfiltration via inter-agent channel | ASI-03 | Workspace sandboxing + read-only grants + audit trail | 0-1 |
| Denial of service (flooding with tasks) | ASI-08 | Rate limits + concurrency limits + delegation budget | 1 |
| Confused deputy (agent acts on malicious instructions) | ASI-07 | Signed messages prove origin. Capability tokens limit scope. | 2-3 |
| Replay attacks | - | Message nonces + timestamps + deduplication window | 1-2 |
| Tampering with stored tasks | - | Payload hashing + at-rest encryption | 1-4 |

---

## 8. Task Lifecycle - SCUT Task

Extended from the delegate_task spec, incorporating A2A's richer state model.

### States

```
submitted --> queued --> running --> completed
                   |          |---> failed
                   |          |---> timed_out
                   |          |---> input_required --> running (after input)
                   |          |---> canceled
                   |---> rejected
```

| State | Description | Source |
|-------|-------------|--------|
| `submitted` | Packet received, validation pending | New (from A2A) |
| `queued` | Validated, waiting for execution slot | delegate_task spec |
| `running` | Active execution | delegate_task spec |
| `input_required` | Agent needs human input to proceed | New (from A2A) |
| `completed` | Successfully finished with result | delegate_task spec |
| `failed` | Error during execution | delegate_task spec |
| `timed_out` | Exceeded timeout | delegate_task spec |
| `canceled` | Explicitly canceled by caller or human | New |
| `rejected` | Target rejected the task (over capacity, not capable) | New (from A2A) |

### Key additions over delegate_task spec

1. **`input_required`**: Critical for chat-platform agents. When a replicant needs human input, it transitions to this state. The callback channel receives a message asking the human. When the human responds, the task resumes.

2. **`canceled`**: Human or Bob Prime can cancel a running task. Maps to `/stop` in copilot-bridge.

3. **`rejected`**: Target agent can reject a task it can't handle (wrong capabilities, overloaded). Enables graceful degradation.

### Storage

Same schema as delegate_task spec's `delegated_tasks` table, with additional columns:

```sql
ALTER TABLE delegated_tasks ADD COLUMN scut_packet TEXT;      -- full SCUT Packet JSON
ALTER TABLE delegated_tasks ADD COLUMN capability_token TEXT;  -- capability token JSON
ALTER TABLE delegated_tasks ADD COLUMN progress TEXT;          -- latest progress message
```

---

## 9. Observability - SCUT Log

### Audit Trail

Every SCUT interaction is logged. Extends the existing `agent_calls` table:

```sql
CREATE TABLE scut_log (
  id TEXT PRIMARY KEY,               -- SCUT Packet ID
  chain_id TEXT NOT NULL,            -- root chain ID
  parent_id TEXT,                    -- parent message ID
  sender TEXT NOT NULL,              -- agent name
  recipient TEXT NOT NULL,           -- target agent name
  type TEXT NOT NULL,                -- hail, dispatch, broadcast, response, status, cancel
  depth INTEGER NOT NULL,            -- chain depth
  budget_remaining INTEGER,          -- delegation budget left
  status TEXT,                       -- task status (for dispatch/status types)
  payload_hash TEXT NOT NULL,        -- SHA-256 of payload
  signature TEXT,                    -- Ed25519 signature (Phase 2+)
  duration_ms INTEGER,              -- time to complete (for responses)
  error TEXT,                        -- error message if failed
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  completed_at TEXT
);

CREATE INDEX idx_scut_chain ON scut_log(chain_id);
CREATE INDEX idx_scut_sender ON scut_log(sender);
CREATE INDEX idx_scut_recipient ON scut_log(recipient);
```

### Distributed Tracing

Phase 3+: OpenTelemetry integration.

- Each SCUT Packet carries a trace context (W3C Trace Context format)
- Bridge creates spans for each inter-agent call
- Spans linked via chain_id for end-to-end tracing
- Export to any OTEL-compatible backend (Jaeger, Zipkin, etc.)

### Dashboard Integration

SCUT task status is visible in the chat channel:
- Dispatch creates a status message in the callback channel
- Status updates edit the same message (if platform supports it) or post new ones
- Completion/failure posts final result
- Human can see the full chain by querying: `check_task --chain <chain_id>`

---

## 10. Implementation Phases

### Phase 0: Foundation (TODAY - already working)

- `ask_agent` with allowlists, depth limits, audit logging
- `schedule` for time-based execution
- Workspace sandboxing with `grant_path_access`
- Loop detection and cycle prevention

**No changes needed. This is the base we build on.**

### Phase 1: Async Delegation (NEXT - spec ready)

Implement the delegate_task spec from dark-factory:
- `delegate_task` and `check_task` tools
- `delegated_tasks` SQLite table with full lifecycle
- Safety rails: concurrency limits, chain budget, timeout ceiling, deduplication
- Callback channel delivery
- Bridge restart recovery

**New SCUT additions to Phase 1:**
- Delegation budget (breadth limit, not just depth)
- Rate limiting per caller-target pair
- `input_required` state (agent posts question to channel, waits for human)
- `canceled` state (human or orchestrator can cancel)
- Message size limits

**Effort**: ~500 LOC, 1-2 weeks

### Phase 2: SCUT Beacons + Signing

- SCUT Beacon (Agent Card) generated from config.json + .agent.md files
- Beacon stored in state.db, queryable via `query_beacon` tool
- Ed25519 keypair per agent (generated at bridge startup)
- All inter-agent messages signed
- Beacon includes public key for verification
- `list_beacons` tool for Bob Prime to discover available replicants

**Effort**: ~400 LOC, 1-2 weeks

### Phase 3: Capability Tokens + Enhanced Security

- Capability tokens attached to dispatch messages
- Default-deny tool access in delegated sessions (token is the allowlist)
- Token expiry tied to task timeout
- Granter validation (can't grant what you don't have)
- Bridge enforces tokens at tool invocation time
- Content scanning for prompt injection in inter-agent messages
- SCUT Packet as the formal message envelope (replaces raw params)

**Effort**: ~600 LOC, 2-3 weeks

### Phase 4: Advanced Patterns

- Broadcast pattern (multi-target dispatch)
- Relay pattern (forwarded messages through intermediary agents)
- Stream pattern (progress updates during long tasks)
- Trust scoring with decay
- At-rest encryption for stored tasks
- OpenTelemetry distributed tracing
- Policy engine (declarative YAML security rules)

**Effort**: ~800 LOC, 3-4 weeks

### Phase 5: A2A Bridge (Daedalus Integration)

- Export SCUT Beacons as A2A Agent Cards
- Accept A2A messages and translate to SCUT Packets
- Expose SCUT agents as A2A-compatible endpoints
- NATS JetStream transport binding (for Daedalus workers)
- Enables copilot-bridge agents to communicate with any A2A-compatible agent

**Effort**: ~1000 LOC, 4-6 weeks. Depends on Daedalus maturity.

---

## 11. Bobiverse Concept Mapping

| Bobiverse | SCUT Protocol | What it does |
|-----------|---------------|--------------|
| Bob Prime | Orchestrator with full SCUT Beacon | Classifies work, spawns replicants, owns the review-fix loop |
| Replicant | Agent with scoped SCUT Beacon | Specialized worker - inherits DNA, has capability limits |
| SCUT transceiver | SCUT-enabled agent | Any agent configured in copilot-bridge with a Beacon |
| SCUT message | SCUT Packet | Signed envelope with typed payload and capability token |
| SCUT beacon | SCUT Beacon (Agent Card) | Agent identity + capabilities + auth + discovery |
| SCUT frequency | SCUT Channel | A configured communication path (allowlist entry) |
| SCUT relay | SCUT Relay | Message forwarding through intermediary agents |
| SCUT range | Delegation depth + budget | How far and how wide a message chain can go |
| Subspace | SCUT Fabric | copilot-bridge + Dolt + Beads infrastructure |
| SURGE drive | Daedalus | Kubernetes-native scaling - spin up/down agent workers |
| Heaven vessels | Ephemeral sessions | Disposable execution environments for delegated tasks |
| Skippies | Dynamic replicants | Ad-hoc agents spawned by Bob Prime for novel tasks |

---

## 12. Comparison Matrix

| Feature | Current (ask_agent) | delegate_task spec | SCUT (full design) | A2A Protocol |
|---------|--------------------|--------------------|---------------------|--------------|
| **Sync query** | Yes | No | Yes (Hail) | Yes (SendMessage) |
| **Async delegation** | No | Yes | Yes (Dispatch) | Yes (SendMessage + poll) |
| **Broadcast** | No | No | Yes (Phase 4) | No (point-to-point) |
| **Relay/forwarding** | No | No | Yes (Phase 4) | Possible but not specified |
| **Streaming** | No | Callback on complete | Yes (Stream, Phase 4) | Yes (SSE) |
| **Agent discovery** | Static config | Static config | Beacon query (Phase 2) | Agent Cards + well-known URL |
| **Capability negotiation** | No | No | Beacon capabilities (Phase 2) | Agent Card skills |
| **Message signing** | No | No | Ed25519 (Phase 2) | JWS/JCS for Agent Cards |
| **Capability tokens** | grantTools/denyTools | grantTools/denyTools | Signed tokens (Phase 3) | Auth per operation |
| **Task states** | N/A (sync) | 5 states | 9 states | 9 states |
| **Human-in-the-loop** | No | No | input_required (Phase 1) | input_required |
| **Cancellation** | No | No (v1) | Yes (Phase 1) | Yes (CancelTask) |
| **Delegation budget** | Depth limit only | Chain limit | Depth + breadth budget | No |
| **Audit trail** | agent_calls table | delegated_tasks table | scut_log table | Implementation-defined |
| **Distributed tracing** | No | No | OTEL (Phase 4) | Extension support |
| **Multi-modal** | Text only | Text only | Parts (Phase 3) | Parts (text, file, data) |
| **Cross-process** | No | No | A2A bridge (Phase 5) | Yes (HTTP) |
| **Deduplication** | Loop detector | SHA-256 window | SHA-256 + nonce | No |
| **Secret isolation** | Workspace sandbox | Workspace sandbox | Sandbox + token scopes | Implementation-defined |

---

## References

### Our existing specs
- dark-factory inter-agent task handoff spec: `specs/inter-agent-task-handoff/spec.md`
- dark-factory cross-channel visibility spec: `specs/cross-channel-visibility/spec.md`
- dark-factory hybrid comms architecture: `workbench/agent-forge/research/hybrid-comms-architecture.md`
- copilot-bridge inter-agent docs: `src/core/inter-agent.ts`

### Research documents (this repo)
- [A2A Protocol Deep Dive](a2a-protocol-deep-dive.md)
- [Multi-Agent Patterns Survey](multi-agent-patterns-survey.md)
- [Agent Security Patterns](agent-security-patterns.md)

### External references
- [A2A Protocol Specification v1.0.0](https://a2a-protocol.org/latest/specification/)
- [MCP Specification](https://modelcontextprotocol.io/specification)
- [OWASP Agentic AI Threats](https://genai.owasp.org/resource/agentic-ai-threats-and-mitigations/)
- [Microsoft Agent Governance Toolkit](https://github.com/microsoft/agent-governance-toolkit)
- [NIST SP 800-207: Zero Trust Architecture](https://csrc.nist.gov/publications/detail/sp/800-207/final)
