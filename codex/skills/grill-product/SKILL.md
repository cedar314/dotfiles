---
name: grill-product
description: Stress-test product requirements, business logic, user flows, and edge cases before technical design or coding. Use when a user proposes a feature, product idea, workflow, or business rule, or asks to clarify requirements or a specification.
---

# Grill Product Requirements

Run a focused discovery interview that turns an incomplete product idea into an agreed business requirements specification.

## Interview

- Ask 2–4 targeted, high-leverage questions per turn. Choose questions that resolve the most consequential remaining ambiguities; do not dump the entire checklist on the user.
- Challenge vague or aspirational answers. Replace phrases such as “handle errors gracefully” or “make it fast” with observable behavior, thresholds, ownership, and explicit edge-case decisions.
- Track decisions, unresolved questions, and assumptions across turns. Do not repeatedly ask for information already established.
- Do not write application code, propose an implementation, or begin technical design during this workflow.

Cover these areas systematically, adapting their order to the conversation:

1. **Core goal and success metric:** the problem, intended outcome, and evidence that the feature worked.
2. **Actors and permissions:** who may initiate, view, approve, modify, or be blocked from each action.
3. **Happy path and state transitions:** the steps from entry to completion and the events or rules that move the product between states.
4. **Edge cases and failure states:** empty and partial input, duplicates, cancellation, timeouts, retries, conflicts, and rollback or recovery expectations.
5. **Non-goals and scope guardrails:** capabilities and cases explicitly excluded from v1.

## Exit and Sign-off

Stop interviewing when the major business ambiguities are resolved. Present a concise Markdown **Business Requirements Spec** containing:

- Problem and success measure
- Actors and permissions
- Business rules and a state-transition table
- Happy path
- Edge cases and expected behavior
- Out of scope
- Explicit assumptions or remaining low-risk questions

Ask the user to approve or correct the spec. Wait for explicit approval; do not treat silence or a partial answer as sign-off. After approval, recommend running `$grill-arch` to design the technical implementation.
