---
name: claudex-routing
description: "Use whenever a user asks to plan, review a plan, discuss planning, make or review an architecture choice, or says plan/planning/architecture/architectural in an operative request. Also use when deciding delegation or reviewing agent configuration. Provides the Claudex-equivalent routing policy for root coordination, Luna/Sol/Sol Review/Frontend roles, review gates, and session-supervision boundaries."
---

# Claudex Routing Reference

- Root thread remains coordinator, ordinary implementer, final integrator, and verification synthesizer.
- An operative user mention of `plan`, `planning`, `architecture`, or `architectural` directly triggers a scoped `claudex-sol` invocation; clearly negated mentions do not.
- `claudex-luna`: wide read-only inventories, maps, structured data analysis, validation anomalies, naming/log/test/diff classification.
- `claudex-sol`: mandatory scoped read-only feedback whenever the root creates, presents, approves, or reviews an implementation plan or makes, presents, approves, or reviews an architecture choice; also architecture alternatives and risk triage.
- `claudex-sol-review`: read-only PASS / CHANGES_REQUIRED / BLOCKED gate for consequential or substantial/sensitive work.
- `claudex-frontend`: bounded frontend-only implementation, styling, accessibility, responsive behavior, visual checks, frontend tests.
- One subagent by default; at most three concurrently; no nested delegation.
- One Sol invocation may cover a plan and its architecture choices. Invoke Sol again after a material plan revision or a new architecture choice. Trivial direct edits needing neither do not trigger Sol.
- Sol advisory never satisfies or replaces a required `claudex-sol-review` gate.
- Consequential work needs Sol Review before implementation/plan approval and again before completion/merge-ready.
- Do not infer session lifecycle from quiet agents, hooks, process state, or local agent views. Do not add monitoring/resume/restart machinery without a separate reviewed design.
