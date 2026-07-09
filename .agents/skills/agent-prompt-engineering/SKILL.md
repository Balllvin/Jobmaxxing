---
name: agent-prompt-engineering
description: >
  Help write, optimize, design, and iterate on prompts, skills, rules, and architectures for LLM agents and agentic systems.
  Use when the user is designing agents, writing agent prompts, creating SKILL.md or rules for agents, architecting workflows, or needs checklists/templates for effective agent prompt engineering.
  Draws from Anthropic (building effective agents, context engineering, tool design), Cursor (agent best practices, plans/rules/skills distinction, TDD, context management), and popular creators/repositories (Lilian Weng, dair-ai/Prompt-Engineering-Guide, etc.).
---

# Agent Prompt Engineering

Use this skill whenever designing or refining prompts for agents. It consolidates proven patterns and techniques into actionable guidance for creating high-quality agent prompts, skills, and workflows.

## Core Principles (Anthropic + General)

- **Start simple, add complexity only when needed.** Prefer single augmented LLM calls or simple workflows before full agents. Agents trade latency/cost for flexibility.
- **Distinguish workflows vs agents**: Workflows = predefined code paths (predictable). Agents = LLM dynamically directs its own process and tool use based on feedback.
- **Simplicity, transparency, well-documented ACI**: Keep design simple. Make planning visible. Thoroughly document and test tools (the agent-computer interface).
- **Context is finite**: Treat tokens as a scarce resource with diminishing returns (context rot). Curate the smallest high-signal set.
- **Eval-driven iteration**: Measure performance. Iterate based on failures. Use explicit criteria.
- **Right altitude in instructions**: Specific enough to guide, flexible enough for heuristics. Avoid brittle if-else hardcoding and vague "do the right thing" assumptions.

## Anthropic Building Effective Agents Patterns

Reference: https://www.anthropic.com/research/building-effective-agents

### Building Block: Augmented LLM
Enhance with retrieval, tools, memory. Provide easy, well-documented interfaces (consider MCP).

### Workflows (composable patterns)

1. **Prompt Chaining**: Decompose into sequence of LLM calls. Add programmatic gates/checks. Use when task cleanly decomposes into fixed subtasks. Trades latency for accuracy.
   - Example: outline -> verify criteria -> write doc.

2. **Routing**: Classify input, dispatch to specialized prompts/tools/models. Use for distinct categories.
   - Example: customer queries by type; easy vs hard routed to different models.

3. **Parallelization**:
   - Sectioning: independent subtasks in parallel.
   - Voting: multiple runs, aggregate.
   - Good for speed or confidence via multiple perspectives.

4. **Orchestrator-Workers**: Central LLM dynamically breaks down task, delegates to workers, synthesizes. Use when subtasks unpredictable (e.g., multi-file code changes).
   - Key: orchestrator decides sub-tasks on the fly.

5. **Evaluator-Optimizer**: Generator + evaluator loop. Use when clear eval criteria exist and iterative refinement helps (e.g., translation, search).

### Agents (autonomous)
LLM uses tools in a loop, plans, recovers from errors, uses environmental feedback ("ground truth").
- Use for open-ended tasks where steps can't be predicted.
- Include stopping conditions, human checkpoints.
- Sandbox + guardrails essential.
- High cost risk, compounding errors.

## Context Engineering (from Anthropic)

Reference: https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents

Context engineering > prompt engineering for agents: curate/maintain optimal tokens across inference turns (prompts + history + tool results + state).

Key strategies (write, select, compress, isolate):
- **Write**: Store externally (files, scratchpads, memory tools). Use compaction: summarize history.
- **Select / Just-in-Time (JIT)**: Maintain lightweight refs (paths, queries). Load on demand via tools (grep, read specific). Progressive disclosure. Use metadata signals (naming, folders, timestamps).
- **Compress**: Trim irrelevant (old tool results, thinking). Summarize. Compaction + memory.
- **Isolate**: Separate concerns; avoid stuffing everything.

**System prompts**:
- Clear, direct, simple language.
- Organize with sections (e.g. `<background>`, `## Instructions`, `## Tool guidance`, `## Output format`).
- Use XML/Markdown headers.
- Start minimal, add examples based on observed failures.
- Provide canonical diverse few-shot examples (not exhaustive edge cases).

**Tools**:
- Minimal viable set; clear, non-overlapping responsibilities.
- Prompt-engineer descriptions and specs carefully (see Anthropic tool writing post).
- Return token-efficient, relevant context.
- Self-contained, robust, descriptive params.

**Message history / state**: Prune, summarize, reference past selectively. Use external memory for persistence.

Hybrid: pre-load key statics, JIT the rest.

## Grounded Communication Drafting

Use these rules when an agent drafts replies, emails, chat messages, outreach, or summaries from user-owned conversations or records.

- **Read every relevant source before asserting facts.** If a draft depends on what a person said, what another chat said, an attachment, a CRM note, or a prior message, load those sources first. Do not infer that "a colleague mentioned..." from "as a colleague may have mentioned" unless the colleague's chat or source record was actually checked.
- **Separate source facts from inference.** Phrase unverified context neutrally: "I understand there may be an opportunity..." instead of claiming someone said something.
- **When the user asks "what was the message?", answer that first.** Relay the relevant message content or a faithful summary before drafting a response. Do not skip the direct answer and jump straight to a suggested reply.
- **Cover every explicit ask from the source message.** Extract the requested actions, timing, names, role/company, and open questions, then make sure the draft addresses each one.
- **Use the correct salutation and named recipient.** If the sender signs with a name or the user says the name is in the message, use it. Match the time-sensitive greeting only when appropriate to the user's request.
- **Do not mirror the other person's sign-off by default.** Choose a distinct, natural closing such as "Kind regards" when the incoming message uses "Best" or when the user asks for a different ending.
- **Do not send or submit unless explicitly asked and permitted.** For communication tools, draft first, show the draft, and only send after the required approval.
- **If privacy constraints change, adapt explicitly.** If the user first says not to read message bodies and later asks what the message said, the later request authorizes reading the relevant message. Keep the access narrow.

## Cursor Agent Best Practices

Reference: https://cursor.com/blog/agent-best-practices

### Plans First
- Use Plan Mode (Shift+Tab): agent researches, asks questions, produces detailed plan in Markdown before coding.
- Edit the plan, save to .cursor/plans/ for team/reuse.
- When agent output wrong: revert, refine plan, re-run. Faster than patching.

### Context Management
- Let the agent find context (it has grep/semantic search). Only explicitly tag known files.
- Start fresh conversation for new logical tasks/features; continue only for iteration/debug.
- Long convs accumulate noise. Use @Past Chats or @Branch to reference selectively without full paste.
- Avoid over-tagging irrelevant files.

### Extending the Agent: Rules vs Skills
- **Rules** (static context): Always included. Put in `.cursor/rules/` (or equivalent). Essentials only: commands, code style pointers to canonical files, workflow. Keep short, check into git. Update on repeated mistakes.
  - Avoid: full style guides (use linter), every edge case.
- **Skills** (dynamic): SKILL.md files. Agent decides relevance from description (keep specific and trigger-oriented). Package workflows, domain knowledge, how-tos. Keeps context clean.
  - Skills for portable/reusable "how" ; Rules for always-on "what".

### TDD / Iteration Workflows
- Explicitly do TDD: ask agent to write tests first (fail), commit, then implement to pass tests, iterate until green.
- For long-running: use hooks (e.g. stop hook to continue until tests pass or "DONE" in scratchpad). Max iterations guard.
- Commit often.

### Other
- Images: paste screenshots/designs for visual work.
- MCP for external tools (Slack, DBs, etc.).
- Commands: reusable in .cursor/commands/.

## Techniques from Popular Creators & Repositories

- **Lilian Weng (LLM Powered Autonomous Agents)**: https://lilianweng.github.io/posts/2023-06-23-agent/
  - Agent = LLM (brain) + Planning + Memory + Tool use.
  - Planning: Chain-of-Thought (CoT: "think step by step"), Tree of Thoughts (explore multiple paths, BFS/DFS + eval), ReAct (Reason + Act interleaved: Thought/Action/Observation loop), Reflexion (self-reflection on failures + dynamic memory), LLM+P (external planner).
  - Memory: Short-term = in-context; Long-term = vector store + retrieval. Sensory embeddings.
  - Tool use: Extend capabilities via APIs, code exec, etc.

- **dair-ai / Prompt-Engineering-Guide** (https://github.com/dair-ai/Prompt-Engineering-Guide , https://www.promptingguide.ai/):
  - Core: zero/few-shot, instruction tuning, CoT, self-consistency, ReAct, automatic prompt engineering.
  - Agents section: planning, tool integration, RAG + agents, evaluation.
  - Emphasize clear structure, examples, constraints, output formats.

- Additional distilled (Karpathy-style, OpenAI cookbook patterns, community):
  - Role + constraints + examples + format + verification loop.
  - Structured outputs (JSON, XML, sections).
  - Self-critique / critique-then-revise.
  - Compaction / summarization checkpoints.
  - Explicit stopping conditions and success criteria.

## Checklists & Templates for Agent Prompt / Skill Design

### When Writing an Agent Prompt or SKILL.md
1. Define trigger: specific description field that tells when to activate.
2. State goal + success criteria explicitly.
3. Decompose: use one of the patterns above (or hybrid).
4. Provide: role, background (minimal), step-by-step instructions or workflow, tool usage rules, output format/schema.
5. Include 1-3 high-quality canonical examples (few-shot).
6. Add guardrails, error recovery, reflection steps if agentic.
7. Specify context strategy: what to keep in prompt vs JIT/load vs summarize.
8. Add a source-grounding rule: list which records/chats/files must be checked before making claims, and require the agent to say when something was not checked.
9. For communication agents, add a response-quality gate: answer direct questions first, cover every source-message ask, avoid unverified attribution, and vary salutation/sign-off from the other person's wording when appropriate.
10. For long-running: include iteration loop + exit conditions.
11. Test mentally: what would cause wrong path? Add prevention or detection.

### Minimal SKILL.md / Agent Prompt Template
```
---
name: your-agent-skill
description: Use when ... (specific triggers, e.g. "designing multi-file code changes" or "the user asks to build an agent for X").
---

# Role
You are ...

# Goal & Success Criteria
...

# Available Tools / Context Strategy
...

# Workflow / Pattern
Use [orchestrator-workers | ReAct | TDD loop | ...]

Step 1: ...
...

# Output Format
Use this structure:
## Plan
...
## Changes
...

# Examples
(1-2 canonical)
```

### Evaluation Prompts
- "Does this output meet <criteria>? If not, why and how to fix?"
- After task: "Reflect on what worked / failed. Update approach."

## Anti-Patterns to Avoid
- Overstuffing context with everything "just in case" (causes rot, distraction).
- Vague high-level instructions without concrete signals or examples.
- Brittle hardcoded logic in prompts instead of model-driven + feedback.
- No eval / no iteration loop — ship untested agent behavior.
- Treating rules and skills interchangeably (static always vs dynamic load).
- Ignoring cost/latency: full agents for simple decomposable tasks.
- Forgetting stopping conditions or human-in-loop checkpoints.
- Copying entire files into context instead of refs + search tools.
- Poor tool descriptions (ambiguous, overlapping, undocumented).
- Continuing noisy long sessions instead of fresh context.
- Drafting from a single visible snippet when the user asked about the full message or referenced another conversation.
- Converting uncertain source language into a verified claim.
- Reusing the incoming sender's closing or phrasing when the user wants a distinct reply voice.
- Failing to provide requested source content before offering the rewritten draft.

## How to Use This Skill
- Invoke explicitly or let auto-match on agent design tasks.
- Reference specific sections when prompting.
- Combine with /create-skill when building new agent skills.

## References & Further Reading
- Anthropic: Building effective agents (Dec 2024), Effective context engineering for AI agents (2025), Writing effective tools for agents.
- Cursor: Best practices for coding with agents (2026), docs on Rules, Skills, Plans, Hooks.
- Lilian Weng: LLM Powered Autonomous Agents (2023).
- dair-ai Prompt Engineering Guide (github + site) — techniques + agents chapters.
- OpenAI cookbook / prompting resources and community patterns (ReAct, Reflexion, etc.).

Distill, test, measure, iterate. Keep prompts and context lean and purposeful.
