# Google A2A (Agent-to-Agent) Protocol - Deep Dive

> Research document for comparing external multi-agent communication patterns to existing specs.
>
> **Protocol Version**: 1.0.0 (latest released)
> **Spec URL**: https://a2a-protocol.org/latest/specification/
> **Repo**: https://github.com/a2aproject/A2A (formerly google/A2A)
> **License**: Apache 2.0, under the Linux Foundation
> **Date researched**: 2025-07-17

---

## Table of Contents

1. [Overview and Positioning](#1-overview-and-positioning)
2. [Data Model](#2-data-model)
3. [Transport Bindings](#3-transport-bindings)
4. [Security Model](#4-security-model)
5. [Agent Discovery](#5-agent-discovery)
6. [Task Lifecycle](#6-task-lifecycle)
7. [Streaming](#7-streaming)
8. [Error Handling](#8-error-handling)
9. [Multi-Modal Support](#9-multi-modal-support)
10. [Push Notifications](#10-push-notifications)
11. [Extensions](#11-extensions)
12. [Ecosystem and Adoption](#12-ecosystem-and-adoption)
13. [Limitations and Gaps](#13-limitations-and-gaps)
14. [A2A vs MCP Comparison](#14-a2a-vs-mcp-comparison)

---

## 1. Overview and Positioning

A2A is an **open protocol for communication between opaque agentic applications**. It was contributed by Google and now lives under the Linux Foundation.

### Core Problem

AI agents built on diverse frameworks (ADK, LangGraph, CrewAI, etc.) by different companies running on separate servers need a way to communicate as **peers** - not just as tools. Without A2A, each agent integration requires custom point-to-point solutions.

### Key Principles

- **Simple**: Reuses HTTP, JSON-RPC 2.0, SSE - no novel transports
- **Enterprise Ready**: Auth, authz, security, privacy, tracing, monitoring baked into design
- **Async First**: Designed for long-running tasks and human-in-the-loop
- **Modality Agnostic**: Text, files (images/video/audio via references), structured data, forms
- **Opaque Execution**: Agents collaborate without exposing internal state, memory, or tools

### Architecture (Three Layers)

```
Layer 1: Canonical Data Model (Protocol Buffers)
  - Task, Message, AgentCard, Part, Artifact, Extension

Layer 2: Abstract Operations (binding-independent)
  - SendMessage, StreamMessage, GetTask, ListTasks, CancelTask, etc.

Layer 3: Protocol Bindings (concrete implementations)
  - JSON-RPC, gRPC, HTTP+JSON/REST, Custom Bindings
```

The normative source is `spec/a2a.proto` (Protocol Buffer definition). All SDKs and schemas are generated from it.

---

## 2. Data Model

The canonical data model is defined in Protocol Buffers. All bindings must provide functionally equivalent representations.

### 2.1 Core Actors

| Actor | Role |
|-------|------|
| **User** | Human or automated service that initiates requests |
| **A2A Client** | Application/agent that initiates requests on behalf of a user |
| **A2A Server (Remote Agent)** | Agent exposing an A2A-compliant endpoint - operates as an opaque black box |

### 2.2 Agent Card

The "digital business card" for an agent. A JSON document providing:

```json
{
  "name": "GeoSpatial Route Planner Agent",
  "description": "Provides route planning and traffic analysis...",
  "supportedInterfaces": [
    {
      "url": "https://georoute-agent.example.com/a2a/v1",
      "protocolBinding": "JSONRPC",
      "protocolVersion": "1.0"
    },
    {
      "url": "https://georoute-agent.example.com/a2a/grpc",
      "protocolBinding": "GRPC",
      "protocolVersion": "1.0"
    },
    {
      "url": "https://georoute-agent.example.com/a2a/json",
      "protocolBinding": "HTTP+JSON",
      "protocolVersion": "1.0"
    }
  ],
  "provider": {
    "organization": "Example Geo Services Inc.",
    "url": "https://www.examplegeoservices.com"
  },
  "version": "1.2.0",
  "capabilities": {
    "streaming": true,
    "pushNotifications": true,
    "extendedAgentCard": true
  },
  "securitySchemes": {
    "google": {
      "openIdConnectSecurityScheme": {
        "openIdConnectUrl": "https://accounts.google.com/.well-known/openid-configuration"
      }
    }
  },
  "security": [{ "google": ["openid", "profile", "email"] }],
  "defaultInputModes": ["application/json", "text/plain"],
  "defaultOutputModes": ["application/json", "image/png"],
  "skills": [
    {
      "id": "route-optimizer-traffic",
      "name": "Traffic-Aware Route Optimizer",
      "description": "Calculates optimal driving route...",
      "tags": ["maps", "routing", "navigation"],
      "examples": [
        "Plan a route from Mountain View to SFO avoiding tolls."
      ],
      "inputModes": ["application/json", "text/plain"],
      "outputModes": ["application/json", "application/vnd.geo+json"]
    }
  ]
}
```

**Key AgentCard fields:**

| Field | Description |
|-------|-------------|
| `name`, `description` | Identity (required) |
| `supportedInterfaces` | Ordered list of protocol bindings (URL + binding type + version) |
| `provider` | Organization name and URL |
| `version` | Agent version string |
| `capabilities` | Boolean flags: `streaming`, `pushNotifications`, `extendedAgentCard` |
| `securitySchemes` | Auth mechanism definitions (OpenAPI-compatible) |
| `securityRequirements` | Which schemes are required |
| `defaultInputModes` / `defaultOutputModes` | MIME types accepted/produced |
| `skills` | Array of AgentSkill objects |
| `signatures` | Optional JWS signatures for integrity verification |

Agent Cards can be **digitally signed** using JWS (RFC 7515) with JCS canonicalization (RFC 8785).

### 2.3 Task

The fundamental unit of work. Stateful with a defined lifecycle.

```
Field          Type              Required   Description
id             string            Yes        UUID, server-generated
contextId      string            No         Groups related tasks/messages
status         TaskStatus        Yes        Current state + optional message
artifacts      Artifact[]        No         Output artifacts
history        Message[]         No         Interaction history
metadata       object            No         Custom key/value metadata
```

### 2.4 Message

A single communication turn. Contains the actual content.

```
Field            Type          Required   Description
messageId        string        Yes        UUID, created by sender
contextId        string        No         Associates with context
taskId           string        No         Associates with existing task
role             Role          Yes        ROLE_USER or ROLE_AGENT
parts            Part[]        Yes        Content containers
metadata         object        No         Arbitrary metadata
extensions       string[]      No         URIs of active extensions
referenceTaskIds string[]      No         Task IDs for additional context
```

### 2.5 Part

The smallest unit of content. A Part holds exactly one of:

| Type | Field | Description |
|------|-------|-------------|
| **Text** | `text` | Plain string content |
| **Raw bytes** | `raw` | Inline binary data (base64 in JSON) |
| **URL reference** | `url` | URI pointing to external file content |
| **Structured data** | `data` | Arbitrary JSON value (object, array, etc.) |

Every Part can also include:
- `mediaType` - MIME type (e.g., `"text/plain"`, `"image/png"`)
- `filename` - Optional filename
- `metadata` - Key/value map

### 2.6 Artifact

A tangible output generated by the agent. Unlike messages (communication), artifacts are deliverables.

```
Field          Type          Required   Description
artifactId     string        Yes        UUID, unique within task
name           string        No         Human-readable name
description    string        No         Description
parts          Part[]        Yes        Content (at least one part)
metadata       object        No         Metadata
extensions     string[]      No         Extension URIs
```

### 2.7 Relationship Diagram

```
AgentCard
  |-- describes --> A2A Server (Remote Agent)
  |-- lists --> AgentSkill[]
  |-- declares --> AgentCapabilities
  |-- specifies --> SecurityScheme[]
  |-- exposes --> AgentInterface[] (URL + binding + version)

Client sends --> Message (role=user, parts=[Part...])
  |
  v
Server creates --> Task
  |-- status --> TaskStatus (state + message + timestamp)
  |-- artifacts --> Artifact[] (each with Part[])
  |-- history --> Message[] (conversation turns)
  |
  v
Task produces --> TaskStatusUpdateEvent, TaskArtifactUpdateEvent
  (delivered via streaming or push notifications)
```

---

## 3. Transport Bindings

A2A supports three official protocol bindings. When an agent supports multiple, all must provide identical functionality and consistent behavior.

### 3.1 JSON-RPC Binding

- **Protocol**: JSON-RPC 2.0 over HTTP(S)
- **Content-Type**: `application/json`
- **Method names**: PascalCase (`SendMessage`, `GetTask`, etc.)
- **Streaming**: Server-Sent Events (`text/event-stream`)
- **All requests go to a single endpoint** (e.g., `POST /rpc`)

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "SendMessage",
  "params": {
    "message": {
      "role": "ROLE_USER",
      "parts": [{"text": "What is the weather?"}],
      "messageId": "msg-uuid"
    }
  }
}
```

SSE streaming wraps each event in a JSON-RPC response:
```
data: {"jsonrpc": "2.0", "id": 1, "result": {"task": {...}}}
data: {"jsonrpc": "2.0", "id": 1, "result": {"statusUpdate": {...}}}
```

### 3.2 gRPC Binding

- **Protocol**: gRPC over HTTP/2 with TLS
- **Definition**: Uses normative `a2a.proto`
- **Serialization**: Protocol Buffers v3
- **Service**: `A2AService` with streaming RPCs
- **Service parameters**: Transmitted via gRPC metadata headers

Key RPCs:
```
SendMessage(SendMessageRequest) -> SendMessageResponse
SendStreamingMessage(SendMessageRequest) -> stream StreamResponse
GetTask(GetTaskRequest) -> Task
ListTasks(ListTasksRequest) -> ListTasksResponse
CancelTask(CancelTaskRequest) -> Task
SubscribeToTask(SubscribeToTaskRequest) -> stream StreamResponse
```

### 3.3 HTTP+JSON/REST Binding

- **Protocol**: HTTP(S) with JSON payloads
- **Content-Type**: `application/json`
- **Methods**: Standard HTTP verbs (GET, POST, DELETE)
- **URL Patterns**: RESTful resource-based

| Operation | Method | URL Pattern |
|-----------|--------|-------------|
| Send message | POST | `/message:send` |
| Stream message | POST | `/message:stream` |
| Get task | GET | `/tasks/{id}` |
| List tasks | GET | `/tasks` |
| Cancel task | POST | `/tasks/{id}:cancel` |
| Subscribe to task | POST | `/tasks/{id}:subscribe` |
| Create push config | POST | `/tasks/{id}/pushNotificationConfigs` |
| Get push config | GET | `/tasks/{id}/pushNotificationConfigs/{configId}` |
| List push configs | GET | `/tasks/{id}/pushNotificationConfigs` |
| Delete push config | DELETE | `/tasks/{id}/pushNotificationConfigs/{configId}` |
| Extended Agent Card | GET | `/extendedAgentCard` |

### 3.4 Custom Bindings

Custom bindings are supported and identified by URI:
```json
{
  "supportedInterfaces": [
    {
      "url": "wss://agent.example.com/a2a/websocket",
      "protocolBinding": "https://example.com/bindings/websocket/v1",
      "protocolVersion": "1.0"
    }
  ]
}
```

Custom bindings MUST implement all core operations, preserve the data model, map all error types, and document the binding completely.

### 3.5 Which to Use?

| Binding | Best For |
|---------|----------|
| **JSON-RPC** | Simple HTTP integrations, browser clients, existing JSON-RPC infrastructure |
| **gRPC** | High-performance server-to-server, strongly-typed, bidirectional streaming |
| **HTTP+JSON/REST** | RESTful APIs, standard web tooling, API gateways |

All three are functionally equivalent. The Agent Card declares which are available in preference order.

---

## 4. Security Model

A2A treats agents as standard enterprise applications and delegates to established web security practices. Identity is handled at the transport/HTTP layer, never inside A2A payloads.

### 4.1 Transport Security

- **HTTPS mandatory** in production
- TLS 1.2+ recommended, TLS 1.3+ preferred
- HSTS headers should be enforced
- Server identity verification via TLS certificate validation

### 4.2 Authentication Schemes

The AgentCard declares supported auth schemes using an OpenAPI 3.2-compatible format:

| Scheme | Object | Description |
|--------|--------|-------------|
| **API Key** | `APIKeySecurityScheme` | Key in header, query, or cookie |
| **HTTP Auth** | `HTTPAuthSecurityScheme` | Bearer, Basic, etc. (IANA registry) |
| **OAuth 2.0** | `OAuth2SecurityScheme` | Authorization Code, Client Credentials, Device Code flows |
| **OpenID Connect** | `OpenIdConnectSecurityScheme` | OIDC discovery URL |
| **Mutual TLS** | `MutualTlsSecurityScheme` | Client certificate auth |

OAuth 2.0 supports these flows:

| Flow | Description | Use Case |
|------|-------------|----------|
| `authorizationCode` | Standard OAuth with optional PKCE | Web apps, interactive |
| `clientCredentials` | Machine-to-machine | Server-to-server |
| `deviceCode` | RFC 8628 | IoT, CLI tools |
| `implicit` | **Deprecated** | Use authorizationCode + PKCE |
| `password` | **Deprecated** | Use authorizationCode + PKCE or deviceCode |

### 4.3 Authentication Flow

```
1. Client fetches AgentCard (e.g., GET /.well-known/agent-card.json)
2. Client parses securitySchemes to determine required auth
3. Client obtains credentials OUT-OF-BAND (OAuth flow, API key distribution, etc.)
4. Client includes credentials in HTTP headers for every request
   (e.g., Authorization: Bearer <TOKEN>)
5. Server validates credentials on every request
6. 401 if missing/invalid, 403 if insufficient permissions
```

### 4.4 Authorization

Authorization is implementation-specific. Agents enforce:
- **Skill-based auth**: Different OAuth scopes for different skills
- **Data/action-level auth**: Backend system access controls
- **Principle of least privilege**: Minimum permissions for each operation

### 4.5 In-Task Authorization (TASK_STATE_AUTH_REQUIRED)

When an agent needs additional credentials mid-task (e.g., to call a third-party API on the user's behalf):

1. Agent transitions task to `TASK_STATE_AUTH_REQUIRED`
2. Agent includes a status message explaining what is needed
3. Client obtains credentials out-of-band
4. Credentials are provided back via secure channel
5. Agent resumes task processing

This supports chaining - a client agent can propagate `AUTH_REQUIRED` up its own task chain.

### 4.6 Agent Card Signing

Agent Cards can be signed with JWS (RFC 7515):
- Protected header includes `alg`, `typ`, `kid`, optional `jku` (JWKS URL)
- Payload is canonicalized via RFC 8785 (JCS) before signing
- Multiple signatures supported for key rotation
- Verification: fetch public key via `kid`/`jku`, verify against canonical payload

### 4.7 Extended Agent Card

Agents can serve a richer Agent Card to authenticated clients:
- Public card at `/.well-known/agent-card.json` (basic info)
- Authenticated card at `GET /extendedAgentCard` (additional skills, detailed capabilities)
- Declared via `capabilities.extendedAgentCard: true`

---

## 5. Agent Discovery

### 5.1 Well-Known URI (Primary)

Standardized path following RFC 8615:

```
GET https://{agent-server-domain}/.well-known/agent-card.json
```

Best for: Public agents, broad discovery within a domain.

### 5.2 Curated Registries (Catalog-Based)

Central registries maintain collections of Agent Cards. Clients query by criteria (skills, tags, provider).

- Supports access controls and trust frameworks
- No standard registry API yet (not prescribed by A2A)
- Applicable in enterprise and public marketplaces

### 5.3 Direct Configuration

Hardcoded or config-file-based Agent Card URLs. Best for development, tightly coupled systems, or private agents.

### 5.4 Caching

- Servers SHOULD include `Cache-Control`, `ETag`, `Last-Modified` headers
- Clients SHOULD honor HTTP caching semantics (RFC 9111)
- Use conditional requests (`If-None-Match`, `If-Modified-Since`) when cached cards expire
- Extended Agent Cards cached for the authenticated session duration

---

## 6. Task Lifecycle

### 6.1 Task States

| State | Type | Description |
|-------|------|-------------|
| `TASK_STATE_SUBMITTED` | Initial | Task acknowledged by server |
| `TASK_STATE_WORKING` | Active | Being processed |
| `TASK_STATE_INPUT_REQUIRED` | Interrupted | Agent needs more user input |
| `TASK_STATE_AUTH_REQUIRED` | Interrupted | Agent needs authorization credentials |
| `TASK_STATE_COMPLETED` | Terminal | Finished successfully |
| `TASK_STATE_FAILED` | Terminal | Finished with error |
| `TASK_STATE_CANCELED` | Terminal | Canceled before completion |
| `TASK_STATE_REJECTED` | Terminal | Agent declined to perform the task |
| `TASK_STATE_UNSPECIFIED` | - | Unknown/indeterminate state |

### 6.2 State Flow

```
                   SendMessage
                       |
                       v
              TASK_STATE_SUBMITTED
                       |
                       v
              TASK_STATE_WORKING
              /    |    |    \
             v     v    v     v
    COMPLETED  FAILED  CANCELED  REJECTED
             \         /
              v       v
        INPUT_REQUIRED / AUTH_REQUIRED
              |
              v (client provides input/auth)
        TASK_STATE_WORKING
              |
              v
         (continues...)
```

### 6.3 Long-Running Task Handling

A2A provides three mechanisms:

1. **Polling**: Client calls `GetTask(taskId)` periodically
2. **Streaming**: Client opens SSE stream via `SendStreamingMessage` or `SubscribeToTask`
3. **Push Notifications**: Client registers a webhook; server POSTs updates

The `returnImmediately` flag in `SendMessageConfiguration` controls blocking behavior:
- `false` (default): Server waits until terminal/interrupted state before responding
- `true`: Server returns immediately with current task state; client must poll/stream/webhook

### 6.4 Multi-Turn Interactions

**Context continuity** via `contextId`:
- Server generates `contextId` to group related tasks/messages
- Client reuses it for subsequent messages in the same conversation
- Agent MAY use it to maintain internal state across interactions

**Task continuation** via `taskId`:
- Client sends new message with same `taskId` to continue a task
- Used after `INPUT_REQUIRED` - agent asked for clarification, client responds

**Example flow:**
```
Client -> SendMessage("Book me a flight") -> Task(state=INPUT_REQUIRED, "Where from/to?")
Client -> SendMessage(taskId=same, "SFO to NYC") -> Task(state=COMPLETED, artifacts=[...])
```

### 6.5 Task Management

- `GetTask`: Retrieve current state, optionally with history
- `ListTasks`: Filter by contextId, status, timestamp; cursor-based pagination
- `CancelTask`: Request cancellation (idempotent, not guaranteed to succeed)
- `SubscribeToTask`: Open a stream for an existing non-terminal task

---

## 7. Streaming

### 7.1 Server-Sent Events (SSE)

A2A uses SSE for real-time streaming. Requires `capabilities.streaming: true` in Agent Card.

**Initiating**: `POST /message:stream` (HTTP+JSON) or `SendStreamingMessage` (JSON-RPC/gRPC)

**Response flow:**
```
HTTP/1.1 200 OK
Content-Type: text/event-stream

data: {"task": {"id": "task-uuid", "status": {"state": "TASK_STATE_WORKING"}}}

data: {"artifactUpdate": {"taskId": "task-uuid", "artifact": {"parts": [{"text": "chunk 1"}]}, "append": true}}

data: {"artifactUpdate": {"taskId": "task-uuid", "artifact": {"parts": [{"text": "chunk 2"}]}, "append": true, "lastChunk": true}}

data: {"statusUpdate": {"taskId": "task-uuid", "status": {"state": "TASK_STATE_COMPLETED"}}}
```

### 7.2 Stream Event Types

Each SSE `data` field contains a `StreamResponse` - exactly one of:

| Type | Description |
|------|-------------|
| `task` | Initial task state (always first in stream) |
| `message` | Direct message response (if no task tracking needed) |
| `statusUpdate` | `TaskStatusUpdateEvent` - state change notification |
| `artifactUpdate` | `TaskArtifactUpdateEvent` - artifact chunk delivery |

### 7.3 Artifact Streaming

Artifacts can be streamed incrementally:

| Field | Purpose |
|-------|---------|
| `append: true` | Content should be appended to previous artifact with same ID |
| `lastChunk: true` | This is the final chunk of the artifact |

### 7.4 Stream Patterns

1. **Message-only stream**: Single `Message` object, stream closes immediately
2. **Task lifecycle stream**: `Task` -> zero or more `StatusUpdate`/`ArtifactUpdate` events -> closes on terminal state

### 7.5 Resubscription

If SSE connection breaks, client can reconnect via `SubscribeToTask`:
- Returns current `Task` as first event (prevents information loss)
- Then continues streaming updates
- Only works for non-terminal tasks

### 7.6 Multiple Concurrent Streams

An agent MAY serve multiple concurrent streams to multiple clients for the same task:
- Events broadcast to all active streams
- Same events in same order per stream
- Closing one stream does not affect others

### 7.7 gRPC Streaming

Uses server streaming RPCs. Same `StreamResponse` union type. Native HTTP/2 framing rather than SSE.

---

## 8. Error Handling

### 8.1 Error Categories

| Category | Description | HTTP | gRPC | JSON-RPC |
|----------|-------------|------|------|----------|
| Authentication | Invalid/missing credentials | 401 | UNAUTHENTICATED | Custom |
| Authorization | Insufficient permissions | 403 | PERMISSION_DENIED | Custom |
| Validation | Invalid parameters | 400 | INVALID_ARGUMENT | -32602 |
| Resource | Not found / inaccessible | 404 | NOT_FOUND | -32001 |
| System | Internal failures | 500/503 | INTERNAL/UNAVAILABLE | -32603 |

### 8.2 A2A-Specific Error Types

| Error | JSON-RPC Code | gRPC Status | HTTP Status |
|-------|---------------|-------------|-------------|
| `TaskNotFoundError` | -32001 | NOT_FOUND | 404 |
| `TaskNotCancelableError` | -32002 | FAILED_PRECONDITION | 400 |
| `PushNotificationNotSupportedError` | -32003 | FAILED_PRECONDITION | 400 |
| `UnsupportedOperationError` | -32004 | FAILED_PRECONDITION | 400 |
| `ContentTypeNotSupportedError` | -32005 | INVALID_ARGUMENT | 400 |
| `InvalidAgentResponseError` | -32006 | INTERNAL | 500 |
| `ExtendedAgentCardNotConfiguredError` | -32007 | FAILED_PRECONDITION | 400 |
| `ExtensionSupportRequiredError` | -32008 | FAILED_PRECONDITION | 400 |
| `VersionNotSupportedError` | -32009 | FAILED_PRECONDITION | 400 |

### 8.3 Error Payload Structure

All errors carry:
1. **Error Code** - machine-readable identifier
2. **Error Message** - human-readable description
3. **Error Details** (optional) - array of structured objects with `@type` key

HTTP+JSON/REST example:
```json
{
  "error": {
    "code": 404,
    "status": "NOT_FOUND",
    "message": "The specified task ID does not exist or is not accessible",
    "details": [
      {
        "@type": "type.googleapis.com/google.rpc.ErrorInfo",
        "reason": "TASK_NOT_FOUND",
        "domain": "a2a-protocol.org",
        "metadata": {
          "taskId": "task-123",
          "timestamp": "2025-11-09T10:30:00.000Z"
        }
      }
    ]
  }
}
```

JSON-RPC example:
```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "error": {
    "code": -32001,
    "message": "Task not found",
    "data": [
      {
        "@type": "type.googleapis.com/google.rpc.ErrorInfo",
        "reason": "TASK_NOT_FOUND",
        "domain": "a2a-protocol.org"
      }
    ]
  }
}
```

### 8.4 Security Error Behavior

- Servers MUST NOT distinguish "does not exist" from "not authorized" (prevents information leakage)
- Servers MUST NOT reveal existence of resources the client cannot access

---

## 9. Multi-Modal Support

A2A is designed to be modality-agnostic through the `Part` system.

### 9.1 Content Types via Parts

| Part Type | Field | Example Use |
|-----------|-------|-------------|
| **Text** | `text` | Natural language, code, markdown |
| **Raw binary** | `raw` | Inline images, PDFs (base64 in JSON) |
| **URL reference** | `url` | Links to hosted files, images, videos |
| **Structured data** | `data` | JSON objects/arrays for machine-readable content |

Every Part can carry `mediaType` (MIME) and `filename`.

### 9.2 Input/Output Mode Negotiation

- Agent declares `defaultInputModes` and `defaultOutputModes` in AgentCard
- Each skill can override with `inputModes`/`outputModes`
- Client can specify `acceptedOutputModes` in `SendMessageConfiguration`
- Agent SHOULD tailor output to match client preferences

### 9.3 File Exchange Example

**Uploading (inline base64):**
```json
{
  "parts": [
    {"text": "Analyze this image"},
    {
      "raw": "iVBORw0KGgoAAAANSUhEUgAAAAUA...",
      "filename": "input_image.png",
      "mediaType": "image/png"
    }
  ]
}
```

**Downloading (URL reference):**
```json
{
  "artifacts": [{
    "parts": [{
      "url": "https://storage.example.com/output.png?token=xyz",
      "filename": "output.png",
      "mediaType": "image/png"
    }]
  }]
}
```

### 9.4 Structured Data Exchange

Client requests and receives JSON:
```json
{
  "artifacts": [{
    "parts": [{
      "data": [
        {"ticketNumber": "REQ12312", "description": "request for VPN access"},
        {"ticketNumber": "REQ23422", "description": "Add to DL"}
      ],
      "mediaType": "application/json"
    }]
  }]
}
```

---

## 10. Push Notifications

For very long-running tasks (minutes, hours, days) or disconnected clients.

### 10.1 Configuration

Client provides a `PushNotificationConfig` either:
- In the initial `SendMessage` request via `configuration.pushNotificationConfig`
- Separately via `CreateTaskPushNotificationConfig` for an existing task

Config includes:
- `url` - HTTPS webhook endpoint
- `token` - Client-side validation token
- `authentication` - How server should authenticate to webhook (scheme + credentials)

### 10.2 Notification Delivery

Server sends HTTP POST to webhook URL with `StreamResponse` payload:

```
POST /webhook/a2a-notifications HTTP/1.1
Host: client.example.com
Authorization: Bearer server-generated-jwt
Content-Type: application/a2a+json
X-A2A-Notification-Token: secure-client-token

{
  "statusUpdate": {
    "taskId": "task-uuid",
    "contextId": "context-uuid",
    "status": {
      "state": "TASK_STATE_COMPLETED",
      "timestamp": "2024-03-15T18:30:00Z"
    }
  }
}
```

### 10.3 Security Requirements

**Server (sender) MUST:**
- Include auth credentials per `PushNotificationConfig.authentication`
- Validate webhook URLs to prevent SSRF (reject private IPs, localhost)
- Implement retry with exponential backoff
- Timeout in 10-30 seconds

**Client (receiver) MUST:**
- Validate webhook authenticity (verify JWT signatures, HMAC, etc.)
- Verify task ID matches expected task
- Respond with HTTP 2xx to acknowledge
- Process idempotently (duplicates may occur)
- Implement rate limiting

### 10.4 Push Notification Lifecycle

```
Client -> SendMessage(config: {pushNotificationConfig: {...}})
Server -> Task(state=SUBMITTED)
  ... server processes ...
Server -> POST webhook: {statusUpdate: {state: WORKING}}
  ... server processes ...
Server -> POST webhook: {statusUpdate: {state: COMPLETED}}
Client -> GetTask(taskId) to retrieve full results
```

---

## 11. Extensions

A2A supports extensions to add capabilities without fragmenting the core protocol.

### 11.1 Extension Types

| Type | Description | Example |
|------|-------------|---------|
| **Data-only** | New structured info in AgentCard | GDPR compliance data |
| **Profile** | Additional constraints on requests/responses | Require specific schemas |
| **Method** (Extended Skills) | New RPC methods | `tasks/search` for history |
| **State Machine** | New states or transitions | Custom sub-states |

### 11.2 Extension Activation

1. Client sends `A2A-Extensions` header with comma-separated URIs
2. Server identifies supported extensions and activates them
3. Response includes `A2A-Extensions` header listing activated extensions

### 11.3 Extension Points

Extensions can augment:
- **Messages** - via `extensions` array and `metadata` map
- **Artifacts** - via `extensions` array and `metadata` map
- **AgentCard** - via `capabilities.extensions` array

### 11.4 Limitations

Extensions CANNOT:
- Change definitions of core data structures (use `metadata` instead)
- Add new enum values (annotate in `metadata`)

### 11.5 Example Extensions

| Extension | Description |
|-----------|-------------|
| Secure Passport | Trusted contextual personalization layer |
| Timestamp | Adds timestamps to Message/Artifact metadata |
| Traceability | Distributed tracing support |
| Agent Gateway Protocol (AGP) | Autonomous Squads routing |

---

## 12. Ecosystem and Adoption

### 12.1 Official SDKs

| Language | Package | Install |
|----------|---------|---------|
| Python | `a2a-sdk` | `pip install a2a-sdk` |
| Go | `a2a-go` | `go get github.com/a2aproject/a2a-go` |
| JavaScript | `@a2a-js/sdk` | `npm install @a2a-js/sdk` |
| Java | `a2a-java` | Maven |
| .NET | `A2A` | `dotnet add package A2A` |
| C++ | `a2a-cpp-sdk` | Community |

### 12.2 Notable Ecosystem Projects

| Project | Stars | Description |
|---------|-------|-------------|
| **casibase/casibase** | ~4,500 | AI Cloud OS with A2A + MCP management |
| **ai-boost/awesome-a2a** | ~560 | Curated list of A2A agents, tools, servers |
| **a2aproject/a2a-inspector** | ~400 | Validation tools for A2A agents |
| **win4r/openclaw-a2a-gateway** | ~450 | Bidirectional A2A gateway |
| **GongRzhe/A2A-MCP-Server** | ~147 | Bridge MCP to A2A |
| **cisco-ai-defense/a2a-scanner** | ~141 | Security scanning for A2A agents |
| **sigstore/sigstore-a2a** | ~20 | Agent signing with Sigstore |

### 12.3 Framework Support

A2A has been adopted or demonstrated with:
- Google ADK (Agent Development Kit)
- LangGraph
- CrewAI
- BeeAI / IBM Research Agent Stack
- Various custom frameworks

### 12.4 Governance

- Now under the **Linux Foundation** (not just Google)
- Apache 2.0 license
- Community-driven via GitHub Discussions and Issues
- Extension governance framework with tiered system (experimental -> official)
- DeepLearning.AI course available

---

## 13. Limitations and Gaps

### 13.1 What A2A Does NOT Cover

| Gap | Description |
|-----|-------------|
| **No agent registry standard** | Discovery via registries is mentioned but no API is standardized |
| **No internal agent communication** | A2A is for inter-agent (between orgs); does not replace intra-agent communication |
| **No tool protocol** | A2A is NOT a replacement for MCP; agents use MCP for tools, A2A for peer agents |
| **No orchestration logic** | A2A defines communication, not how to coordinate multi-agent workflows |
| **No memory sharing** | By design, agents are opaque - no shared memory protocol |
| **No payment/billing** | No built-in mechanism for agent service billing (community extension exists: a2a-x402) |
| **No content negotiation protocol** | `acceptedOutputModes` is a hint, not a contract |
| **No rate limiting protocol** | Rate limits are implementation-specific, no standard headers |
| **No agent lifecycle management** | No protocol for deploying, starting, stopping, or monitoring agent processes |
| **No real-time bidirectional streaming** | SSE is server-to-client only; no built-in WebSocket support (possible via custom binding) |
| **No message delivery guarantees** | Messages in streaming may be lost on disconnect; not a reliable delivery mechanism |

### 13.2 Implementation Decisions Left to the Developer

- Task persistence and storage strategy
- History retention policies
- Authorization logic and access control models
- Context expiration and cleanup
- Rate limiting and quota management
- Multi-tenancy implementation
- Observability and monitoring instrumentation
- Agent Card registry and catalog APIs
- Webhook validation and SSRF prevention strategies

### 13.3 Evolving Areas (from Roadmap)

- Formalizing auth scheme inclusion in AgentCards
- `QuerySkill()` method for dynamic capability checking
- Dynamic UX negotiation within tasks (adding audio/video mid-conversation)
- Client-initiated methods beyond task management
- Streaming reliability improvements

### 13.4 Maturity Considerations

- Protocol is at v1.0.0 (first stable release)
- Previously at v0.3.0, v0.2.6, v0.1.0
- Breaking changes handled via deprecation lifecycle
- Still evolving with community input

---

## 14. A2A vs MCP Comparison

| Dimension | A2A | MCP |
|-----------|-----|-----|
| **Purpose** | Agent-to-agent collaboration | Agent-to-tool/resource connection |
| **Interaction model** | Multi-turn, stateful, conversational | Stateless function calls |
| **Participants** | Autonomous agents as peers | Agent calling structured tools |
| **State management** | Tasks with full lifecycle | Typically stateless |
| **Complexity** | Complex negotiations, long-running | Simple request/response |
| **Opacity** | Agents are black boxes | Tools expose clear interfaces |
| **Transport** | JSON-RPC, gRPC, HTTP/REST | JSON-RPC over stdio/HTTP |
| **Discovery** | Agent Cards with skills | Tool descriptions |
| **Streaming** | SSE + push notifications | SSE |
| **Auth** | Full OAuth/OIDC/mTLS/API Key | Simpler auth model |

**They are complementary**: A2A handles agent-to-agent communication (the "mechanic" agents coordinating). MCP handles tool usage (agent calling a database query, API, or function).

A typical system uses both:
```
User -> A2A -> Shop Manager Agent
                |-> A2A -> Mechanic Agent
                |            |-> MCP -> Diagnostic Scanner Tool
                |            |-> MCP -> Repair Manual Database
                |-> A2A -> Parts Supplier Agent
```

---

## Appendix: Key Specification References

| Resource | URL |
|----------|-----|
| Main documentation | https://a2a-protocol.org |
| Full specification | https://a2a-protocol.org/latest/specification/ |
| GitHub repo | https://github.com/a2aproject/A2A |
| Python SDK | https://github.com/a2aproject/a2a-python |
| Go SDK | https://github.com/a2aproject/a2a-go |
| JS SDK | https://github.com/a2aproject/a2a-js |
| Java SDK | https://github.com/a2aproject/a2a-java |
| .NET SDK | https://github.com/a2aproject/a2a-dotnet |
| Samples | https://github.com/a2aproject/a2a-samples |
| DeepLearning.AI Course | https://goo.gle/dlai-a2a |

---

*This document was compiled from primary sources: the A2A v1.0.0 specification, official documentation at a2a-protocol.org, the GitHub repository README, and ecosystem analysis.*
