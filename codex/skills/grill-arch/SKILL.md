---
name: grill-arch
description: Stress-test technical architecture, data models, interfaces, and codebase integration before implementation. Use after requirements are defined when a user wants schemas, APIs, service boundaries, performance trade-offs, or an implementation plan grounded in an existing repository.
---

# Grill Technical Architecture

Run a repository-grounded architecture interview that turns approved requirements into an agreed technical design without writing application code.

## Ground the Interview

Before asking questions, inspect the current repository structure and the relevant configuration, modules, data-access code, interfaces, tests, and architectural documentation. Identify established patterns and likely ownership boundaries. If no repository or requirements are available, ask for the missing context instead of inventing it.

Summarize only the codebase observations needed to frame the first questions. Distinguish observed facts from assumptions.

## Interview

- Ask 2–4 targeted, high-leverage questions per turn. Prioritize decisions with broad architectural consequences; do not dump the entire checklist on the user.
- Ground questions in observed repository patterns and approved product requirements.
- Challenge vague goals such as “scalable,” “reliable,” or “fast.” Elicit workloads, latency or availability targets, consistency needs, ownership, recovery behavior, and acceptable trade-offs.
- Track decisions, unresolved questions, and assumptions across turns. Do not repeatedly ask for information already established.
- Do not write application code or begin implementation during this workflow.

Cover these areas systematically, adapting their order to the design:

1. **Codebase fit and boundaries:** existing owners, new responsibilities, dependencies, and service or module boundaries.
2. **Data model and migrations:** schema changes, indexes, integrity constraints, lifecycle and retention, migration sequencing, and backward compatibility.
3. **API and contract design:** synchronous versus asynchronous execution, request and response or event shapes, validation, idempotency, compatibility, and versioning.
4. **Failure modes and concurrency:** races, atomicity, retries, deduplication, dead-letter handling, rate limits, backpressure, and third-party outages.
5. **Verification and rollout:** unit, integration, and end-to-end coverage; migration verification; feature flags; staged rollout and rollback; logs, metrics, traces, and alerts.

## Exit and Sign-off

Stop interviewing when the major architectural ambiguities are resolved. Present a concise Markdown **Technical Design Doc (TDD)** containing:

- Requirements and constraints
- Architecture summary and codebase ownership
- Data model and migration plan
- API or event contracts
- Failure, retry, and concurrency handling
- Security, performance, and operational considerations where relevant
- Verification, observability, rollout, and rollback strategy
- Step-by-step implementation plan
- Explicit assumptions, trade-offs, and remaining low-risk questions

Ask the user to approve or correct the TDD. Wait for explicit approval; do not treat silence or a partial answer as sign-off. Only after approval may a separate implementation task begin.
