# Agent & MCP Design Specification

*Last updated: 2025-06-12*

---

## 1. Purpose

Provide a robust framework that allows a **LangChain-based LLM agent** to manipulate
external systems through an **MCP (Model Context Protocol) server**.  
This design balances *modularity*, *security*, and *observability* so the same
blueprint can be reused for other domains (e‑g. CRM, Docs, IoT devices).

---

## 2. High‑Level Architecture

```mermaid
graph TD
    subgraph Client
        A[User prompt<br/>("予定入れて")]
    end
    subgraph Agent Layer
        B[LangChain Agent<br/>ReAct loop]
        C[langchain‑mcp‑adapters]<br/>Tool wrappers
    end
    subgraph Control Plane
        D[MCP Client SDK]
    end
    subgraph Data Plane
        E[HTTPS JSON RPC]
    end
    subgraph Server Layer
        F[MCP Server<br/>FastAPI]
        G[Google Calendar API]
        H[Vector DB / SQL / S3]
    end

    A --> B
    B --> C
    C --> D
    D -.tools.-> F
    B -->|function call| E
    E --> F
    F -->|OAuth2| G
    F -->|storage| H
    F -->|JSON result| E
    E --> B
```

---

## 3. MCP Server Design

| Topic | Guideline |
|-------|-----------|
| **Framework** | `mcp` SDK + FastAPI auto‑exposes OpenAPI/JSONSchema. |
| **Resources** | `gcal://events/{id}` (CalendarEvent).  Add `@resource` annotation. |
| **Tools** | CRUD verbs (`create_event`, `read_event`, `update_event`, `delete_event`, `list_events`). Use Pydantic models for IO. |
| **Auth** | Service Account w/ domain‑wide delegation (Workspace) **or** Installed‑App OAuth (personal). |
| **Storage** | Stateless for Calendar; for docs use S3 + FAISS + pgvector combo. |
| **Rate‑limit** | `events().list()` cached 30 s per user. 429 surfaced to client as MCP error. |
| **Versioning** | SemVer in `MCPServer(version="1.2.0")` & `x‑mcp‑version` header. |
| **Observability** | Middleware logs: {timestamp, user, tool, status, latency}. Export to Cloud Logging. |
| **Error model** | HTTP 4xx ↔ user/validation errors; 5xx ↔ infrastructure. Return `error.type`, `error.message`. |

### Tool Definition Example
```python
@tool(
    name="create_event",
    description="Create a calendar event",
    input_model=CreateReq,
    output_model=CalendarEvent,
)
def create_event(req: CreateReq) -> CalendarEvent: ...
```

---

## 4. Agent Design

| Layer | Implementation | Notes |
|-------|----------------|-------|
| **LLM** | `ChatOpenAI(model="gpt‑4o‑mini")` | Replaceable (Anthropic, Azure‑OpenAI). |
| **Memory** | No long‑term memory; rely on MCP for source of truth. |
| **Reasoning Loop** | ReAct via `langgraph.prebuilt.create_react_agent`. |
| **Tool Loading** | `MultiServerMCPClient(base_urls=[...]).load_tools()` dynamically discovers tools at runtime. |
| **Prompt System** | *System*: "You are a calendar assistant.  Use the provided tools…" <br/> *Examples*: 2‑3 few‑shot pairs for robustness. |
| **Safety** | Max 3 consecutive tool calls, 8k token cap, stop if tool error ≥2. |
| **Retries** | Exponential backoff on 5xx; LLM re‑prompt on validation errors. |
| **Evaluation** | Synthetic eval: feed scripted tasks, assert Calendar state. |

---

## 5. Interaction Flow (Sequence)

1. **User Prompt** – Natural language request.  
2. **Agent Think** – Internal chain‑of‑thought (hidden).  
3. **Tool Selection** – Agent emits `create_event` function call with arguments.  
4. **MCP Client** – Sends JSON to `POST /create_event`.  
5. **MCP Server** – Validates, hits Google Calendar API, returns `CalendarEvent`.  
6. **Agent Final** – Confirms booking to user.

Edge cases:
* Double booking → agent checks availability via `list_events`.
* OAuth token expiry → MCP returns 401; agent instructs user to re‑auth.

---

## 6. Security Considerations

* **Principle of Least Privilege** – SA limited to scope `calendar`.  
* **Network** – Serve over HTTPS; mTLS for internal traffic.  
* **Secrets** – Store JSON key in Secret Manager; inject via runtime env var.  
* **Quota Abuse** – Per‑IP & per‑user rate limits in API Gateway.  
* **Data Residency** – Calendar data stays within Google; logs pseudonymised.

---

## 7. Extensibility

* Add additional MCP servers (Docs, Tasks, CRM) — the same agent can orchestrate multi‑system workflows.  
* Swap vector backend to `pgvector` without changing agent.  
* Multi‑tenant: prepend `{tenant}/` to resource URIs and enforce ACL in middleware.

---

## 8. Future Enhancements

| Idea | Impact |
|------|--------|
| Structured memory in agent to recall prior meetings across sessions | Better continuity |
| Streaming tools (`tool_stream=True`) | Lower latency for read‑heavy tasks |
| Graph‑based planning (LangGraph custom nodes) | Complex multi‑step automations |
| Fine‑tune small model for tool‑calling | Reduced token cost |

---

*End of document.*
