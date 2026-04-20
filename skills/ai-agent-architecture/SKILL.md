---
name: ai-agent-architecture
description: Design AI agent systems — ReAct reasoning, tool use, planning strategies, memory, multi-agent orchestration, and evaluation
metadata:
  version: 2.1
  argument-hint: "agent pattern (ReAct/Plan-Execute/Multi-Agent), task type (reasoning/tool-use/long-horizon), memory requirement (short-term/long-term/episodic), tools/integrations needed"
---

Design AI agent system for $ARGUMENTS.


## Agent Patterns

**ReAct (Reason + Act):** Observe → Think (chain-of-thought) → Act (tool call or final answer) → repeat until answer or max iterations. Most common for tool-using agents. Weak at long-horizon planning (degrades after 5-10 tool calls).

**Plan-and-Execute:** LLM generates multi-step plan → execute each step → optionally replan after each step based on results. Better for 5+ step tasks with dependencies. Use cheaper models for execution steps. Replanning adds robustness but increases token cost.

**Multi-Agent Orchestration:** Orchestrator routes tasks to focused agents (Researcher, Analyst, Writer, Critic) each with specific tools and system prompts; aggregates results via shared state or message passing. Use when single-agent complexity exceeds reliable performance.

**Reflexion / Self-Critique:** agent produces output → critic evaluates (separate prompt or model) → agent revises with feedback → repeat until quality threshold or max revisions (2-3). Use for high-stakes outputs. Limit revisions to bound cost and latency.

## Tool Design

Tool definition: `{ name, description, parameters (JSONSchema/Zod), execute: (params) => Promise<ToolResult> }`. `ToolResult`: `{ success, data?, error?, metadata?: { latency_ms, tokens_used?, source? } }`.

Tool description rules: describe WHEN to use it, not just what it does; include parameter constraints; mention what it does NOT do (prevents misuse); keep under 200 tokens.

Good description example: "Search the internal knowledge base for company products, policies, and procedures. Use when the user asks about company-specific topics. Returns top 5 most relevant passages. Does NOT search the internet or external sources."

Tool execution safety pattern:
```typescript
// 1. Validate parameters with Zod safeParse
// 2. Execute with AbortController timeout (30s)
// 3. Truncate large results >50K chars to prevent context overflow
// 4. Return structured errors (not stack traces — LLMs reason better on structured errors)
// 5. Log every tool call with params, result, and latency
```

## Memory Systems

**Short-term (conversation context):** message array `[{ role: 'user'|'assistant'|'tool', content }]`; manage via sliding window, summarization, or token-based truncation. Always keep system prompt; drop oldest messages first; summarize dropped history into "conversation summary" message when context is critical.

**Long-term (persistent):** vector store or key-value store for summaries/facts/preferences across sessions; memory types: `fact`, `preference`, `summary`, `episode` with `importance` (0-1) and `embedding`; retrieve relevant memories at turn start; update after significant interactions.

**Episodic (task history):** store summaries of previous tasks, outcomes, and lessons learned; retrieve when facing similar task (enables learning without fine-tuning).

**Memory retrieval scoring:** `alpha * relevance + beta * recency + gamma * importance` (recency via time decay, relevance via embedding similarity, importance via explicit scoring).

## State Machine Design

```typescript
type AgentState =
  | { status: 'idle' }
  | { status: 'thinking'; turn: number }
  | { status: 'calling_tool'; tool: string; params: unknown }
  | { status: 'waiting_for_tool'; tool: string; started_at: number }
  | { status: 'waiting_for_human'; question: string }
  | { status: 'completed'; result: string }
  | { status: 'error'; error: string; recoverable: boolean }
  | { status: 'budget_exceeded'; tokens_used: number; limit: number };
```

Transitions: idle → thinking (user input) → calling_tool (LLM selects tool) or completed (final answer) or waiting_for_human | calling_tool → waiting_for_tool → thinking (result received) or error (timeout) | error → thinking (retry with error context) or completed (unrecoverable) | any → budget_exceeded.

## Token Budget Management

```typescript
interface TokenBudget {
  total: number;              // max tokens for entire run
  per_turn_input: number;
  per_turn_output: number;
  per_tool_result: number;    // max tokens from single tool result
  reserved_for_answer: number; // tokens reserved for final answer
  used: number;
}
```

Rules: hard total budget per run (e.g., 100K tokens); reserve 2-4K for final answer; truncate tool results exceeding per-tool budget; track cumulative usage across turns; terminate gracefully at 80% consumed — produce best available answer; log token usage per turn for cost monitoring.

## Error Recovery

Retry strategy: `while (retries < maxRetries)` — execute turn → if completed, return → if unrecoverable error, throw → if recoverable, set `lastError`, increment retries → after max retries, return graceful termination message with last error.

| Error | Recovery |
|-------|----------|
| Invalid tool parameters | Re-prompt with parameter schema and error |
| Tool execution timeout | Retry once, then skip tool and inform LLM |
| Tool returns error | Pass error to LLM for alternative approach |
| LLM produces unparseable output | Re-prompt with stricter format instructions |
| Token budget exceeded | Produce best available answer |
| LLM hallucinated non-existent tool | List available tools and re-prompt |
| Infinite loop (same tool call repeated) | Detect repetition, force alternative action |

## Human-in-the-Loop

Approval gates: `{ tool: string, condition?: (params) => boolean, timeout_ms: number, fallback: 'skip' | 'deny' | 'ask_llm' }`. Examples: `delete_record` (always approve, timeout 5min, deny on timeout) | `send_email` (approve if recipients >10) | `execute_query` (approve if query contains DELETE).

Escalation patterns: confidence threshold (escalate when LLM confidence is low) | sensitive topics (predefined topics always route to human) | repeated failures (3 failed tool calls → escalate) | cost threshold (pause before expensive operations).

## Safety Guardrails

Input: sanitize user input (prevent prompt injection); validate tool parameters against strict schemas; reject inputs attempting to override system prompts.

Output: check agent responses against content policies; validate tool calls are within allowed scope; monitor for information leakage (PII, credentials, internal data).

Execution boundaries:
```typescript
interface AgentGuardrails {
  max_iterations: number;        // 10-50 depending on complexity
  max_tokens: number;
  max_wall_time_ms: number;      // 5-10 minutes for complex tasks
  allowed_tools: string[];       // whitelist — agent cannot call unlisted tools
  blocked_patterns: RegExp[];
  require_approval: string[];    // tools requiring human approval
}
```

## Framework Integration

**LangGraph:** state graph with typed `TypedDict` state; nodes: LLM calls, tool executions, conditional routing, human review; checkpointing with SqliteSaver/PostgresSaver; `interrupt()` for human-in-the-loop (pause + resume); subgraphs for modular composition; `Command(goto="node_name")` for dynamic routing; streaming via `astream_events`/`astream`.

```python
graph = StateGraph(AgentState)
graph.add_node("planner", plan_node); graph.add_node("executor", execute_node); graph.add_node("tools", ToolNode(tools))
graph.add_edge(START, "planner")
graph.add_conditional_edges("executor", should_use_tool, {"tool": "tools", "done": END})
graph.add_edge("tools", "executor")
agent = graph.compile(checkpointer=memory)
```

**Vercel AI SDK:** `generateText` with `tools` for single-turn; `streamText` with `maxSteps` for multi-turn loops; `onStepFinish` for observability; tool results automatically fed back.

**Anthropic SDK:** `stop_reason: 'tool_use'` → execute tools → resume with tool results; parallel tool calls in single turn; extended thinking (`thinking` blocks); computer use tools for browser automation.

```typescript
// Core loop pattern:
// while(true) → client.messages.create({ tools, messages }) → if end_turn: break
// → filter tool_use blocks → execute in parallel → push tool_results back to messages
```

**Zod + zodToJsonSchema:** validate LLM-generated params before execution with `Schema.safeParse(llmParams)`.

**Custom agent loop:** `while (iterations < max)` → check wall time and budget → call LLM with tools → if `end_turn`, return answer → if `tool_use`, validate against allowlist, execute safely, append result → increment iteration → on budget exhaustion, prompt for best answer → on max iterations, return graceful termination.

## Observability

Tracing: trace every run — input, each turn (LLM call + tool calls), output; include token counts, latency, tool results, error states per turn. Tools: LangSmith, Braintrust, OpenTelemetry with custom spans, Helicone.

| Metric | Target |
|--------|--------|
| Task completion rate | >90% |
| Average turns per task | <8 for most tasks |
| Tool call accuracy (valid params) | >95% |
| Error rate (unrecoverable) | <5% |
| Average latency | <30s simple, <120s complex |
| Human escalation rate | <10% |

## Reflection and Self-Critique

Reflection loop: agent produces output → separate reflection prompt evaluates (accuracy/completeness/tool usage quality) → if issues found, agent revises with explicit feedback → max 2-3 cycles (diminishing returns after).

Evaluation-driven agents: define success criteria as executable checks (not just LLM judgment); run checks after each major step (fail fast); structured rubrics: `{ accuracy: 0-1, completeness: 0-1, relevance: 0-1 }`.

## Multi-Agent Communication Patterns

**Shared state (blackboard):** all agents read/write shared state; tightly coupled, pipeline patterns; risk: state conflicts (use versioned state or merge strategies).

**Message passing:** agents communicate via typed messages through orchestrator; loosely coupled, fan-out/fan-in patterns; orchestrator controls routing, prevents infinite loops.

**Hierarchical delegation:** manager agent delegates, reviews results, decides next steps; workers have narrow scope and limited tools; manager has broader context but doesn't execute directly.

## Anti-Patterns

No iteration limit or token budget (loops forever, costs spiral) | trusting LLM tool parameters without validation | giant tool results without truncation (overflows context) | too many tools >20 (LLM struggles to select) | no error context in retry (LLM repeats same failing action) | no human escalation path | agents that can call themselves recursively without depth limits | sharing full conversation history between agents (token explosion — share summaries instead).

## Implementation Workflow

1. Define agent purpose, available tools, and success criteria
2. Design tool manifest with clear descriptions and schemas
3. Choose agent pattern (ReAct, Plan-and-Execute, Multi-Agent)
4. Implement agent loop with state management
5. Add guardrails: iteration limits, token budget, timeouts, tool allowlist
6. Implement error recovery for common failure modes
7. Add human-in-the-loop gates for sensitive operations
8. Set up tracing and metrics collection
9. Build evaluation dataset of representative tasks
10. Test edge cases: tool failures, budget exhaustion, ambiguous inputs

## Output Format

```
Agent Pattern:     [ReAct / Plan-and-Execute / Multi-Agent / Reflexion]
Tools:             [list with brief descriptions]
State Management:  [state machine / LangGraph / custom loop]
Memory:            [short-term / long-term / episodic]
Budget:            [max tokens, max iterations, max wall time]
Guardrails:        [tool allowlist, approval gates, content filters]
Error Recovery:    [retry strategy, human escalation]
Observability:     [tracing tool, metrics tracked]
Framework:         [LangGraph / Vercel AI SDK / custom]
```

## Done Criteria

- Agent completes representative tasks within budget and time limits
- Tool calls have valid parameters (validated before execution)
- Tool results truncated to fit context window
