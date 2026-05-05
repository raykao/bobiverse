# Multi-Agent Communication Patterns Survey

> Research document for identifying gaps in inter-agent communication specs.
> Last updated: 2025-07-25

---

## Table of Contents

1. [MCP (Model Context Protocol)](#1-mcp-model-context-protocol)
2. [CrewAI Communication Patterns](#2-crewai-communication-patterns)
3. [LangGraph Multi-Agent Patterns](#3-langgraph-multi-agent-patterns)
4. [Agency Swarm Directional Messaging](#4-agency-swarm-directional-messaging)
5. [Microsoft AutoGen / Agent Framework](#5-microsoft-autogen--agent-framework)
6. [Google A2A (Agent2Agent) Protocol](#6-google-a2a-agent2agent-protocol)
7. [Emerging Standards](#7-emerging-standards)
8. [Comparative Analysis](#8-comparative-analysis)
9. [Identified Gaps for copilot-bridge](#9-identified-gaps-for-copilot-bridge)

---

## 1. MCP (Model Context Protocol)

**Repository**: [modelcontextprotocol/specification](https://github.com/modelcontextprotocol/specification) (MIT license)
**Spec version**: 2025-11-25
**Website**: https://modelcontextprotocol.io

### Overview

MCP is an open protocol that standardizes how AI applications (hosts/clients) connect to external data sources and tools (servers). It draws inspiration from the Language Server Protocol (LSP) - where LSP standardizes programming language support across editors, MCP standardizes how AI applications integrate with external context and capabilities.

The protocol uses JSON-RPC 2.0 messages and defines three participant roles:

- **Hosts**: LLM applications that initiate connections (e.g., Claude Desktop, VS Code)
- **Clients**: Connectors within the host application that manage individual server connections
- **Servers**: Services that provide context, tools, and capabilities

### Agent-to-Tool Communication

MCP is fundamentally a **client-server** protocol for connecting AI hosts to tool/data providers. Communication is structured around three server-provided feature categories:

| Feature | Direction | Purpose |
|---------|-----------|---------|
| **Resources** | Server -> Client | Contextual data (files, DB schemas, app state) exposed via URIs |
| **Prompts** | Server -> Client | Templated messages and workflows for users |
| **Tools** | Server -> Client | Functions the AI model can invoke |

Tools are **model-controlled**: the LLM discovers available tools via `tools/list` and invokes them via `tools/call`. Tool definitions include JSON Schema for both input and output, enabling structured content exchange. Tools can return text, images, audio, resource links, or embedded resources.

### Security Model

MCP's security model is principle-based rather than enforcement-based:

- **User consent and control**: Users must explicitly consent to data access and tool invocation
- **Data privacy**: Hosts must get explicit consent before exposing user data to servers
- **Tool safety**: Tool descriptions/annotations are considered untrusted unless from a trusted server
- **Transport security**: Streamable HTTP requires Origin header validation (DNS rebinding protection), localhost binding for local servers, and proper authentication
- **Session management**: Sessions use cryptographically secure IDs (UUIDs, JWTs, or hashes). Clients must handle session IDs securely to prevent session hijacking
- **OAuth**: The spec references authentication but delegates specifics to implementation

### Can MCP Be Used for Agent-to-Agent Communication?

MCP was **not designed for agent-to-agent communication**. It is a client-server protocol where:

- Clients connect to servers (one-directional initiation)
- Servers expose capabilities; clients consume them
- There is no peer-to-peer messaging or agent discovery

However, MCP can be "bent" toward agent-to-agent patterns in two ways:

1. **MCP servers as agent proxies**: An agent can expose itself as an MCP server, allowing other agents (via MCP clients) to invoke its tools. This is effectively tool-based delegation - not conversational agent interaction.

2. **Sampling feature** (see below): Servers can request LLM completions from the client, creating a limited bidirectional flow. But this is server-to-host, not agent-to-agent.

The A2A protocol (Section 6) was created specifically to fill this gap.

### Resource Discovery and Capability Negotiation

MCP has a rigorous lifecycle for capability negotiation:

1. **Initialization**: Client sends `initialize` with its protocol version and capabilities. Server responds with its own capabilities. Client confirms with `initialized` notification.
2. **Version negotiation**: Client proposes a version; server responds with a compatible version or its latest. Mismatch causes disconnection.
3. **Capability negotiation**: Both sides declare optional features:
   - Client capabilities: `roots` (filesystem boundaries), `sampling` (LLM access), `elicitation` (user prompts), `tasks`
   - Server capabilities: `prompts`, `resources`, `tools`, `logging`, `completions`, `tasks`
   - Sub-capabilities like `listChanged` (dynamic list updates) and `subscribe` (resource change notifications)

Resource discovery is dynamic: servers can emit `notifications/tools/list_changed` when available tools change, and `notifications/resources/list_changed` for resource changes. Clients can subscribe to individual resources for update notifications.

### Notification and Subscription Model

MCP supports several notification patterns:

- **List change notifications**: Servers notify clients when the set of available tools, resources, or prompts changes
- **Resource subscriptions**: Clients can subscribe to specific resources by URI and receive `notifications/resources/updated` when content changes
- **Progress tracking**: Long-running operations can send progress notifications
- **Logging**: Servers can emit structured log messages to clients
- **Cancellation**: Either side can send cancellation notifications for pending requests

### Sampling Feature

Sampling is MCP's most "agentic" capability. It allows **servers to request LLM completions from the client**:

- Server sends `sampling/createMessage` with messages, model preferences, and optional tools
- Client routes the request to an LLM and returns the completion
- Server can specify model preferences using hints (model names) and priority weights (intelligence vs. speed)
- Supports multi-turn tool loops: the server can execute tool calls from the LLM response and send follow-up sampling requests
- The client maintains full control over model selection, prompt visibility, and whether sampling occurs at all

This enables nested agentic behaviors where an MCP server can leverage the host's LLM to perform reasoning within its own tool execution flow.

### MCP vs A2A

MCP and A2A are **complementary, not competing**:

| Dimension | MCP | A2A |
|-----------|-----|-----|
| Purpose | Connect AI apps to tools/data | Connect agents to agents |
| Relationship | Client-server (asymmetric) | Peer-to-peer (opaque agents) |
| State exposure | Servers expose resources, tools | Agents are opaque black boxes |
| Discovery | Capability negotiation at init | Agent Cards with skill descriptions |
| Communication | JSON-RPC 2.0 | JSON-RPC 2.0 over HTTP(S) |
| Transport | stdio, Streamable HTTP | HTTP(S) with SSE |

A typical architecture uses MCP for an agent's internal tool access and A2A for inter-agent collaboration.

### Transport Mechanisms

1. **stdio**: Client launches server as subprocess; messages via stdin/stdout. Simplest, most widely supported.
2. **Streamable HTTP**: Server as independent process over HTTP POST/GET with optional SSE streaming. Supports session management, resumability, and multiple concurrent connections.
3. **Custom transports**: Protocol is transport-agnostic; any bidirectional channel works.

---

## 2. CrewAI Communication Patterns

**Repository**: [crewAIInc/crewAI](https://github.com/crewAIInc/crewAI) - 49,300+ stars
**License**: MIT
**Website**: https://docs.crewai.com

### Overview

CrewAI is a Python framework for orchestrating role-playing, autonomous AI agents. It is built entirely from scratch (independent of LangChain) and provides two complementary abstractions:

- **Crews**: Teams of autonomous agents that collaborate through role-based task execution
- **Flows**: Event-driven workflows for production-grade, fine-grained control over execution

### How Agents Communicate

CrewAI agents communicate through **two primary mechanisms**:

#### 1. Task Context Chaining

Tasks can reference other tasks via the `context` parameter. When Task B lists Task A in its context, Task B's agent receives the output of Task A as input:

```python
writing_task = Task(
    description="Write article based on research",
    agent=writer,
    context=[research_task],  # Gets research output automatically
)
```

This is the primary communication channel - structured, deterministic, and unidirectional (producer -> consumer).

#### 2. Delegation Tools (Agent Collaboration)

When `allow_delegation=True`, agents gain two built-in tools:

- **Delegate Work Tool**: `delegate_work(task, context, coworker)` - assigns work to another agent
- **Ask Question Tool**: `ask_question(question, context, coworker)` - queries another agent for information

These tools enable runtime, LLM-driven collaboration. The agent autonomously decides when to delegate or ask questions based on its understanding of the task and team composition.

### Role-Based Agent Definition

Agents are defined with:
- `role`: Job title / specialty (e.g., "Research Specialist")
- `goal`: What the agent is trying to achieve
- `backstory`: Context and expertise description
- `tools`: Available tool functions
- `allow_delegation`: Whether the agent can interact with peers
- `memory`: Whether the agent retains past interaction context

### Task Execution Modes

| Mode | Description |
|------|-------------|
| **Sequential** (`Process.sequential`) | Tasks execute in order; output of each feeds into the next |
| **Hierarchical** (`Process.hierarchical`) | A manager agent coordinates and delegates to specialist agents |
| **Parallel** (via Flows) | Multiple tasks/crews run concurrently within a Flow |

### Memory Sharing

- **Short-term memory**: Active during a crew's execution; agents share context via task outputs
- **Long-term memory**: Persisted across executions using embeddings; agents learn from past runs
- **Entity memory**: Tracks entities (people, concepts) across interactions
- **User memory**: Stores user-specific preferences and context

Memory is shared at the crew level - all agents in a crew can access the shared memory store.

### Limitations for Cross-Process/Cross-Network Scenarios

CrewAI has significant limitations for distributed scenarios:

- **Single-process only**: Crews run in a single Python process. There is no built-in mechanism for agents to communicate across processes or machines.
- **No network protocol**: No HTTP/gRPC/WebSocket transport for agent communication.
- **No agent discovery**: Agents are defined in code and wired together statically.
- **No authentication/authorization**: Trust is implicit within the process boundary.
- **State is in-memory**: Unless explicitly persisted via memory backends, state is lost on crash.
- **No streaming of intermediate results**: Task outputs are delivered as complete units.

CrewAI Enterprise (the commercial offering) adds deployment, monitoring, and scaling - but the fundamental communication model remains in-process.

---

## 3. LangGraph Multi-Agent Patterns

**Repository**: [langchain-ai/langgraph](https://github.com/langchain-ai/langgraph)
**License**: MIT
**Inspiration**: Google Pregel, Apache Beam, NetworkX
**Website**: https://docs.langchain.com/oss/python/langgraph/overview

### Overview

LangGraph is a low-level orchestration framework for building stateful, long-running agents. Unlike higher-level agent frameworks, LangGraph does not abstract prompts or architecture - it provides the infrastructure for state management, durable execution, and human-in-the-loop workflows.

### Graph-Based Agent Orchestration

LangGraph models agent workflows as **directed graphs**:

- **Nodes**: Functions that perform work (LLM calls, tool invocations, computations)
- **Edges**: Define transitions between nodes (static, conditional, or dynamic)
- **State**: A typed dictionary (TypedDict or Pydantic model) that flows through the graph
- **START/END**: Special nodes marking entry and exit points

```python
graph = StateGraph(MessagesState)
graph.add_node("agent", call_llm)
graph.add_node("tools", execute_tools)
graph.add_edge(START, "agent")
graph.add_conditional_edges("agent", should_use_tool, {"yes": "tools", "no": END})
graph.add_edge("tools", "agent")
```

### How State Flows Between Nodes

State management is LangGraph's core differentiator:

1. **Shared state object**: All nodes read from and write to a single state dictionary
2. **Reducer functions**: When multiple nodes write to the same state key, reducer functions (e.g., `operator.add` for lists) merge the values
3. **Immutable snapshots**: Each node receives an immutable snapshot; mutations return a new partial state that gets merged
4. **MessagesState**: A built-in state schema optimized for chat-style message lists

State updates follow a functional pattern: nodes return partial dictionaries that get merged into the full state.

### Checkpointing and Recovery

LangGraph provides **durable execution** with three durability modes:

| Mode | Behavior | Use Case |
|------|----------|----------|
| `"exit"` | Persist only on graph exit (success, error, or interrupt) | Best performance for long-running graphs |
| `"async"` | Persist asynchronously while next step runs | Good balance of performance and durability |
| `"sync"` | Persist synchronously before each step | Maximum durability, slight overhead |

Checkpointer backends include in-memory (development), SQLite, PostgreSQL, and custom implementations. Each execution is tracked by a `thread_id`, enabling:

- **Resume after failure**: Re-invoke with the same thread_id and `None` input
- **Resume after interrupt**: Re-invoke with a `Command(resume=value)` to continue from the interrupt point
- **Time-travel**: Roll back to any previous checkpoint

### Human-in-the-Loop Patterns

LangGraph's `interrupt()` function enables rich HITL workflows:

- **Approval gates**: Pause before critical actions, resume with approve/reject
- **Review and edit**: Surface generated content for human review, resume with edits
- **Tool call interception**: Pause before tool execution, let humans modify tool arguments
- **Input validation**: Pause to collect and validate human input before proceeding
- **Multiple simultaneous interrupts**: Fan-out to parallel nodes that each interrupt, then resume all at once using interrupt IDs

Interrupts are dynamic (can be conditional) and work at any point in the graph, including inside tools.

### Subgraph Composition

LangGraph supports **agents as subgraphs**:

- A node in a parent graph can itself be a compiled graph (subgraph)
- Subgraphs have their own state schemas; data passes through input/output mappings
- Checkpointing extends into subgraphs - if a subgraph interrupts, the parent graph's state is preserved
- Resuming a parent graph resumes into the correct subgraph node automatically

This enables hierarchical agent architectures: a supervisor graph orchestrates specialist subgraphs, each with their own state and logic.

### Limitations

- **Single-runtime assumption**: While LangGraph Platform (commercial) supports distributed deployment, the open-source library assumes a single Python runtime
- **No native agent discovery**: Agents (subgraphs) are composed in code, not discovered at runtime
- **No inter-process protocol**: Communication between graphs requires shared memory or external coordination
- **Vendor coupling for production**: Full production features (deployment, scaling, observability) require LangSmith/LangGraph Platform

---

## 4. Agency Swarm Directional Messaging

**Repository**: [VRSEN/agency-swarm](https://github.com/VRSEN/agency-swarm) - 4,200+ stars
**License**: MIT
**Built on**: OpenAI Agents SDK
**Website**: https://agency-swarm.ai

### Overview

Agency Swarm models multi-agent systems after **real-world organizational structures**. Its core innovation is explicit, directional communication flows between agents with defined hierarchical roles.

### Directional Communication Flows

Communication flows are defined using tuples or the `>` operator:

```python
agency = Agency(
    ceo,  # Entry point for user communication
    communication_flows=[
        ceo > dev,    # CEO can initiate with Developer
        ceo > va,     # CEO can initiate with Virtual Assistant
        dev > va,     # Developer can initiate with VA
    ],
    shared_instructions='agency_manifesto.md',
)
```

Key properties:
- **Directional**: `ceo > dev` means the CEO can message the Developer, but not the reverse (unless explicitly defined)
- **Entry points**: The first argument(s) to `Agency()` are agents that can communicate directly with users
- **Manifesto**: `shared_instructions` provides organizational context to all agents

### The `SendMessage` Tool Pattern

Under the hood, Agency Swarm implements inter-agent communication via a `SendMessage` tool that is automatically added to agents based on their defined communication flows. When Agent A can message Agent B:

1. Agent A's LLM decides it needs to communicate with Agent B
2. It calls the `SendMessage` tool with a message and the target agent
3. Agent B processes the message and returns a response
4. Agent A receives the response as the tool call result

This is elegant because it leverages existing LLM tool-calling capabilities for agent routing - no custom routing logic needed.

### Orchestration Patterns

Agency Swarm supports two primary patterns:

#### Handoff Pattern
Control transfers completely to another agent. The receiving agent gets full conversation history and takes over user interaction. Control does **not** return to the sender.

```python
communication_flows=[
    (triage_agent, billing_specialist, Handoff),
    (triage_agent, technical_specialist, Handoff),
]
```

- Very high reliability (tight feedback loop with user)
- Lower autonomy (sequential, user-driven)
- Lower cost (fewer LLM calls)

#### Orchestrator-Worker Pattern
One agent delegates tasks and compiles results. Control always returns to the orchestrator.

```python
communication_flows=[
    (portfolio_manager, risk_analyst),
    (portfolio_manager, report_generator),
]
```

- Lower reliability (mitigated with guardrails)
- Very high autonomy (parallel, independent work)
- Higher cost (multiple concurrent LLM calls)

### Communication Graph Definition

The communication graph is a **directed acyclic graph** (in practice) defined at Agency construction time:

- Nodes: Agent instances
- Edges: Allowed message directions with optional Handoff annotation
- Entry points: Agents accessible to external users
- Shared context: Agency manifesto applied to all agents

### How Roles/Hierarchy Affect Message Routing

- Higher-level agents (CEO, Manager) are typically entry points and orchestrators
- Lower-level agents (Developer, Analyst) are specialists that receive delegated work
- The communication graph enforces organizational hierarchy - a Developer cannot message the CEO unless explicitly allowed
- Each agent has `name`, `description`, `instructions`, and `tools` that define its role

### Limitations

- **OpenAI dependency**: Built on OpenAI Agents SDK (supports other providers via LiteLLM)
- **Single-process**: No native cross-process or cross-network communication
- **No dynamic agent discovery**: Communication flows are static, defined at initialization
- **No persistent message queues**: Messages are synchronous tool calls; no async messaging
- **Thread-based state**: Conversation state is per-thread, managed via callbacks

---

## 5. Microsoft AutoGen / Agent Framework

**Repository**: [microsoft/autogen](https://github.com/microsoft/autogen) (maintenance mode)
**Successor**: [microsoft/agent-framework](https://github.com/microsoft/agent-framework) (production-ready)
**License**: MIT

### Overview

AutoGen pioneered many multi-agent patterns that are now standard in the ecosystem. It is now in **maintenance mode**, with Microsoft recommending migration to the **Microsoft Agent Framework (MAF)** for new projects. MAF is the enterprise-grade successor with A2A and MCP support built in.

AutoGen uses a layered architecture:
- **Core API**: Message passing, event-driven agents, local and distributed runtime (.NET and Python)
- **AgentChat API**: High-level API for rapid prototyping (group chats, teams)
- **Extensions API**: Pluggable LLM clients, tools, and capabilities

### Conversational Agent Patterns

AutoGen agents communicate through **message broadcasting within teams**:

1. **AssistantAgent**: LLM-powered agent with tools, system messages, and handoff capabilities
2. **UserProxyAgent**: Represents a human user in the conversation
3. **AgentTool**: Wraps an agent as a tool, enabling agent-as-tool delegation

The simplest multi-agent pattern uses `AgentTool`:

```python
math_agent_tool = AgentTool(math_agent, return_value_as_last_message=True)
agent = AssistantAgent(
    "assistant",
    tools=[math_agent_tool, chemistry_agent_tool],
)
```

This creates a hierarchical pattern where a coordinator agent invokes specialist agents as tools.

### Group Chat Orchestration

AutoGen provides several group chat implementations:

#### SelectorGroupChat
- An LLM selects the next speaker based on conversation context and agent descriptions
- All agents share the same message context (broadcast)
- Supports custom selection prompts and functions
- Can prevent consecutive turns by the same speaker
- Uses agent `name` and `description` for routing decisions

#### Swarm
- Agents hand off to each other using `HandoffMessage`
- Speaker selection based on the most recent handoff message (not LLM-selected)
- Agents make local decisions about who to hand off to
- Supports handoff to `"user"` for human-in-the-loop
- Modeled after OpenAI's Swarm pattern

#### RoundRobinGroupChat
- Agents take turns in a fixed order
- Simplest pattern; useful for structured pipelines

#### GraphFlow
- Multi-agent workflows via a directed graph of agents
- Similar to LangGraph's approach but integrated into AutoGen's team abstraction

### Agent Negotiation and Collaboration

- **Shared message context**: All agents in a team see the full conversation history
- **Termination conditions**: Composable conditions (text mention, max messages, handoff detection) control when teams stop
- **Reflection**: Agents can reflect on tool outputs before responding (`reflect_on_tool_use=True`)
- **Memory**: Pluggable memory systems for cross-session context

### Tool Use Delegation

AutoGen supports multiple delegation patterns:

1. **AgentTool**: Wrap any agent as a callable tool
2. **Handoffs**: Agents transfer control via tool calls that generate `HandoffMessage`
3. **MCP Integration**: `McpWorkbench` connects agents to MCP servers for tool access
4. **Custom tools**: Function-based tools with automatic schema generation

### Microsoft Agent Framework (MAF) - The Successor

MAF brings enterprise-grade capabilities:

- **Graph-based workflows**: Agents and deterministic functions connected via data flows
- **A2A and MCP support**: Native interoperability via open standards
- **Cross-runtime**: Python and .NET with consistent APIs
- **Durable agents and workflows**: Persistent execution with checkpointing
- **OpenTelemetry**: Built-in distributed tracing
- **Middleware**: Flexible request/response pipelines

---

## 6. Google A2A (Agent2Agent) Protocol

**Repository**: [a2aproject/A2A](https://github.com/google-a2a/A2A) (Apache 2.0, Linux Foundation)
**Website**: https://a2a-protocol.org
**SDKs**: Python, Go, JavaScript, Java, .NET

### Overview

A2A is an open protocol designed specifically for **agent-to-agent communication**. It addresses the gap that MCP does not fill: enabling agents built on different frameworks, by different companies, running on separate servers, to communicate as peers (not as tools).

### Key Design Principles

- **Standardized communication**: JSON-RPC 2.0 over HTTP(S)
- **Agent discovery**: "Agent Cards" describe capabilities and connection details
- **Opacity**: Agents collaborate without exposing internal state, memory, or tools
- **Flexible interaction**: Synchronous request/response, SSE streaming, and async push notifications
- **Rich data exchange**: Text, files, and structured JSON
- **Enterprise-ready**: Authentication, authorization, and observability by design

### Core Concepts

#### Agent Cards
JSON documents that describe an agent's capabilities, supported interaction modalities, and connection info. Analogous to OpenAPI specs but for agents.

#### Task Lifecycle
A2A models interactions as **tasks** with a defined lifecycle:
- Tasks can be created, updated, queried, and cancelled
- Long-running tasks support streaming updates via SSE
- Push notifications enable fully asynchronous collaboration

#### Modality Negotiation
Agents can negotiate interaction formats (text, forms, media) at runtime, enabling rich multi-modal collaboration.

### A2A vs MCP (Complementary)

| Aspect | MCP | A2A |
|--------|-----|-----|
| Use case | Agent-to-tool (vertical integration) | Agent-to-agent (horizontal collaboration) |
| Agent role | Server exposes tools; client consumes | Agents are opaque peers |
| Internal state | Shared (resources, tools visible) | Hidden (agents are black boxes) |
| Typical deployment | Same machine or localhost | Cross-network, cross-organization |
| Framework coupling | Tight (host embeds client) | Loose (HTTP-based, framework-agnostic) |

The recommended architecture: use MCP for an agent's internal tooling, A2A for cross-agent collaboration.

### Current Status and Roadmap

- Production SDKs in 5 languages
- Planned: dynamic skill querying, in-task UX negotiation, client-initiated methods, improved streaming

---

## 7. Emerging Standards

### Agent Communication Protocol (ACP)

- Several implementations exist bridging ACP agents with MCP clients
- [GongRzhe/ACP-MCP-Server](https://github.com/GongRzhe/ACP-MCP-Server) bridges ACP and MCP
- IBM has contributed to ACP research
- Less mature than A2A; smaller community adoption

### Universal Agent Messaging (UAM)

- [YouAM-Network/uam](https://github.com/YouAM-Network/uam) - encrypted agent-to-agent communication
- Focus on encryption and security for agent messaging
- Early stage, small community

### FIPA-ACL (Legacy)

- Foundation for Intelligent Physical Agents - Agent Communication Language
- Academic standard from the early 2000s
- Defined performatives (inform, request, propose, accept, reject)
- Largely superseded by modern protocols but its concepts (speech acts, ontologies, interaction protocols) influence current designs

### OpenAI Swarm Pattern

- Not a protocol but an influential design pattern
- Agents hand off via tool calls; shared conversation context
- Adopted by AutoGen (Swarm team) and Agency Swarm
- No formal spec; implementation-defined

### Agent Protocol (agent-protocol)

- Various implementations attempting to standardize agent HTTP APIs
- No dominant standard has emerged
- Most are thin REST wrappers around agent invocation

---

## 8. Comparative Analysis

### Communication Model Comparison

| Framework | Communication Model | Agent Discovery | State Sharing | Cross-Process | Transport |
|-----------|-------------------|-----------------|---------------|---------------|-----------|
| **MCP** | Client-server (tool calls) | Capability negotiation | Resources + tools | Yes (HTTP) | stdio, HTTP+SSE |
| **A2A** | Peer-to-peer (tasks) | Agent Cards | Opaque (by design) | Yes (HTTP) | HTTP(S)+SSE |
| **CrewAI** | Task context + delegation tools | Static (code-defined) | Shared memory store | No | In-process |
| **LangGraph** | Shared state graph | Static (code-defined) | Typed state dict | No (OSS) | In-process |
| **Agency Swarm** | SendMessage tool (directional) | Static (code-defined) | Thread-based | No | In-process |
| **AutoGen** | Broadcast + handoffs | Static (code-defined) | Shared message context | Partial (Core API) | In-process + distributed runtime |

### Orchestration Pattern Comparison

| Pattern | Used By | Description |
|---------|---------|-------------|
| **Sequential pipeline** | CrewAI, LangGraph | Tasks/nodes execute in order; output flows forward |
| **Hierarchical delegation** | CrewAI, Agency Swarm, AutoGen | Manager agent delegates to specialists |
| **Selector group chat** | AutoGen | LLM picks next speaker from shared context |
| **Swarm/handoff** | AutoGen, Agency Swarm | Agents transfer control via tool calls |
| **Graph-based routing** | LangGraph, AutoGen GraphFlow, MAF | Conditional edges route between nodes/agents |
| **Fan-out/fan-in** | LangGraph | Parallel execution with state merging |

### Human-in-the-Loop Comparison

| Framework | HITL Support | Mechanism |
|-----------|-------------|-----------|
| **MCP** | Elicitation (server requests user input) | Server -> Client -> User -> Client -> Server |
| **LangGraph** | Deep (`interrupt()` at any point) | Checkpointed pause/resume with typed commands |
| **AutoGen** | Handoff to "user" | HandoffMessage + HandoffTermination |
| **Agency Swarm** | Entry point agents | User interacts with top-level agents only |
| **CrewAI** | Limited (via input tasks) | Human provides input at task boundaries |
| **A2A** | Modality negotiation | Form/text input within task lifecycle |

### Durability and Recovery

| Framework | Checkpointing | Failure Recovery | Long-Running Support |
|-----------|--------------|-----------------|---------------------|
| **LangGraph** | Full (3 durability modes) | Resume from last checkpoint | Yes (durable execution) |
| **MCP** | Session management | Session reconnection + SSE resumability | Yes (Streamable HTTP) |
| **A2A** | Task lifecycle | Task status polling | Yes (async tasks + push) |
| **AutoGen/MAF** | MAF: durable workflows | MAF: checkpoint-based | MAF: yes |
| **CrewAI** | None (OSS) | None | No |
| **Agency Swarm** | Thread callbacks | Manual restore | No |

---

## 9. Identified Gaps for copilot-bridge

Based on this survey, the following gaps exist between established patterns and what copilot-bridge's inter-agent communication might need:

### Gap 1: No Standard for Chat-Platform-Bridged Agent Communication

MCP handles agent-to-tool. A2A handles agent-to-agent over HTTP. Neither addresses the specific pattern of agents communicating **through a chat platform** (Mattermost, Slack) as the transport layer.

copilot-bridge occupies a unique position: agents live in chat channels and communicate via messages routed by the bridge. This is closer to Agency Swarm's directional messaging but with the chat platform as the message bus.

**Implication**: copilot-bridge needs its own inter-agent message format and routing spec, potentially as a profile/extension of A2A adapted for chat-platform transport.

### Gap 2: Agent Discovery in Chat Contexts

All frameworks use static, code-defined agent registration. A2A has Agent Cards but assumes HTTP-based discovery. None address discovering agents that are **present in a chat channel** or **available on a chat platform**.

**Implication**: copilot-bridge needs a discovery mechanism - perhaps Agent Cards adapted for chat contexts, or a registry accessible via the bridge API.

### Gap 3: Conversational Context vs. Task Context

- CrewAI and LangGraph pass structured state between agents
- AutoGen broadcasts full conversation history
- A2A treats agents as opaque, passing task-level context only

Chat-platform agents have a unique challenge: the conversation history IS the shared context, but it mixes user messages, agent responses, and inter-agent communication. No framework cleanly separates these concerns.

**Implication**: copilot-bridge needs a clear model for what context is shared between agents: full thread history? Summarized context? Structured handoff payloads?

### Gap 4: Human-in-the-Loop Is Native but Unstructured

In a chat platform, human-in-the-loop is inherent - the human is always in the chat. But current frameworks model HITL as an explicit pause/resume cycle (LangGraph interrupts, AutoGen handoffs).

copilot-bridge's challenge is the opposite: how do agents distinguish human messages meant for them vs. inter-agent messages vs. ambient conversation?

**Implication**: Need clear conventions for message routing, @-mention semantics, and thread-based isolation.

### Gap 5: No Standard for Agent Hierarchy in Chat

Agency Swarm's directional flows and CrewAI's hierarchical process are defined in code. For chat-platform agents, the hierarchy needs to be:
- Configurable without code changes
- Discoverable by agents at runtime
- Enforced by the bridge (not just by agent instructions)

**Implication**: copilot-bridge's `communication_flows` equivalent needs to be a first-class config concept.

### Gap 6: Durability Across Chat Sessions

LangGraph's checkpointing and A2A's task lifecycle address durability for HTTP-based agents. Chat platform agents face additional challenges:
- Conversations span hours/days
- Users go offline and return
- Agents may restart mid-conversation
- Chat history is owned by the platform, not the agent

**Implication**: copilot-bridge needs to reconcile agent state (in its state.db) with platform conversation state (in Mattermost/Slack).

### Gap 7: Security Model for Multi-Agent Chat

MCP's security model assumes a single user consenting to tool use. A2A assumes enterprise auth between services. Neither addresses:
- Multiple users in a channel with different permission levels
- Agents acting on behalf of different users
- Cross-channel agent communication with different trust levels
- Preventing agents from accessing channels they should not see

**Implication**: copilot-bridge needs a permission model that maps chat platform roles/channels to agent capabilities.

### Gap 8: Streaming and Real-Time Interaction

LangGraph and MCP support streaming (SSE). A2A supports streaming and push notifications. But chat platforms have their own real-time model (WebSocket-based message delivery).

copilot-bridge already handles this via its streaming integration, but the inter-agent spec should address how streaming works when Agent A's output is being streamed to a user while Agent B needs that output to proceed.

**Implication**: Inter-agent communication spec needs to handle streaming-aware handoffs and concurrent agent outputs.

---

## Sources

- MCP Specification (2025-11-25): https://modelcontextprotocol.io/specification
- MCP GitHub: https://github.com/modelcontextprotocol/specification
- CrewAI GitHub: https://github.com/crewAIInc/crewAI
- CrewAI Docs - Collaboration: https://docs.crewai.com/concepts/collaboration
- LangGraph GitHub: https://github.com/langchain-ai/langgraph
- LangGraph Docs: https://docs.langchain.com/oss/python/langgraph/overview
- Agency Swarm GitHub: https://github.com/VRSEN/agency-swarm
- Agency Swarm Docs - Communication Flows: https://agency-swarm.ai/core-framework/agencies/communication-flows
- Microsoft AutoGen GitHub: https://github.com/microsoft/autogen
- Microsoft Agent Framework GitHub: https://github.com/microsoft/agent-framework
- AutoGen Docs - AgentChat: https://microsoft.github.io/autogen/stable/user-guide/agentchat-user-guide/index.html
- Google A2A GitHub: https://github.com/a2aproject/A2A
