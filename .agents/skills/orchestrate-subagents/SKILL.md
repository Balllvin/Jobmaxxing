---
name: orchestrate-subagents
description: Proactively coordinate sub-agents across repository tasks. Use when a task has meaningful parallelizable work across exploration, implementation, review, repair, validation, documentation, or cross-surface checks; when an implementation can be split into isolated ownership areas; when a focused critic or specialist pass could improve quality; or when multiple agents can shorten the path to a more complete result. Skip only for tiny deterministic edits, one-line fixes, simple command answers, or git/release steps that must stay single-owner.
---

# Orchestrate Subagents

Honor the nearest repo instructions first, especially `AGENTS.md`, `README.md`, `lessons.md`, UI architect files, validation rules, and branch/worktree policy. This skill changes the delegation default: use sub-agents proactively for meaningful repo work while keeping one parent agent responsible for orchestration, integration, verification, git, and the final answer.

## Operating Model

1. Start as the parent/orchestrator.
2. Decide whether the task is too small for delegation. If it is not, split it into independent work packages.
3. Send sub-agents to explore, implement, review, repair, verify, or document in parallel where that improves completeness or speed.
4. Keep file ownership explicit. Assign only one writer to a file or checkout at a time.
5. Pull results back, inspect the diffs or findings yourself, integrate the work, run validation, and iterate with more agents when the next best step is independent.
6. Own the final state: correctness, tests, docs, branch hygiene, commit, push, and PR remain the parent agent's responsibility.

## When To Delegate

Use sub-agents for any non-trivial task where they can materially help:

- map unfamiliar code paths, contracts, tests, or sibling surfaces
- implement isolated portions of a multi-file or multi-surface change
- compare frontend, backend, PWA, Smaug, notebook, or QuantLab contracts
- run targeted review for correctness, accessibility, data fidelity, security, performance, or missing tests
- attempt a focused repair after a review finding or failing validation
- verify docs, provider behavior, framework rules, or recurring lessons
- audit near-duplicate surfaces so the fix lands everywhere it should

Skip delegation for:

- one-line or single-symbol edits
- small deterministic documentation tweaks
- command-output requests that are faster to answer directly
- git bootstrap, rebase, push, or branch-management flows
- migrations or release sequencing where parallel mutation raises risk
- formatter-only or linter-only mechanical changes

## Agent Mix

Choose the smallest useful team, not the largest possible one.

- `explorer`: read-heavy mapping, evidence gathering, affected-file inventories, contract diffs, docs lookup
- `worker`: isolated implementation or repair in a clearly assigned file set
- `critic`: skeptical review for bugs, regressions, missing tests, maintainability, UI quality, data contracts, accessibility, security, or performance
- `verifier`: run focused checks, inspect failures, and identify the smallest repair path

For a moderate feature, a good default is one explorer, one worker for each independent implementation area, and one critic after the first integration. For a one-page UI change, consider one worker plus one UI/contract critic. For high-risk backend or provider work, add a verifier or security/data-contract critic.

## Delegation Prompt Template

Every sub-agent prompt must define ownership and output. Use this shape and fill it with real paths:

```text
Task in /absolute/path/to/worktree.
Role: explorer | worker | critic | verifier.
Goal: <specific deliverable>.
Scope: <subsystem, route, component, service, or concern>.
Allowed files: <exact files/directories the agent may inspect or edit>.
Forbidden files: <files/directories the agent must not touch>.
Write mode: read-only | isolated-write.
Boundaries: Do not create branches, worktrees, commits, pushes, or PRs. Do not touch files outside the allowed scope.
Verification: <tests/checks/evidence to gather or run>.
Expected output: <findings, patch summary, changed files, tests run, risks, next repair recommendation>.
Ownership: Parent agent owns integration, conflict resolution, final verification, git, and PR.
```

Use `read-only` for mapping or critique. Use `isolated-write` when the sub-agent has one disjoint implementation or repair scope. A critic can be given `isolated-write` only when the parent explicitly asks it to fix a narrow issue it found.

## Write Safety

- Keep sub-agents inside the parent task worktree unless the parent provisions a separate worktree.
- Never let two agents write the same file, directory, generated artifact, package lock, migration chain, or test fixture at the same time.
- Do not let sub-agents create ad hoc branches, worktrees, commits, pushes, PRs, stash entries, or index changes.
- Give shared control surfaces one writer at most: `AGENTS.md`, `README.md`, `lessons.md`, `.agents`, `.codex`, `.cursor`, `.claude`, migrations, CI, release scripts, package manifests, lockfiles, and provider-routing controls.
- Review every sub-agent diff or finding before accepting it. The parent can reject, revise, or reassign work.

## Iteration Loop

Use sub-agents throughout the work, not only at the end:

1. Explore: send agents to map different surfaces when the file graph is unclear.
2. Implement: assign isolated workers to independent parts.
3. Integrate: parent reconciles overlapping assumptions and runs focused checks.
4. Review: send one or more critics against the integrated diff.
5. Repair: either fix locally or assign a narrow worker/critic repair task.
6. Verify: run tests and, when useful, assign a verifier to inspect failures or coverage gaps.
7. Repeat until the task is genuinely complete.

Stop delegating when the remaining work is a single blocking path, the agents would fight over the same files, or local execution is clearly faster.

## Output Discipline

Ask sub-agents for compact, actionable output:

- changed files and why
- tests or commands run, with pass/fail
- exact findings with file paths and symbols
- unresolved risks or follow-up repair tasks

Do not accept broad prose as completion. If a child result is vague, either ask for a narrower pass or inspect the work yourself.
