---
name: claudex-routing
description: "Reference the Claudex-equivalent routing policy for Codex/Orca: root coordination, Luna/Sol/Sol Review/Frontend roles, review gates, and session-supervision boundaries. Use when deciding delegation or reviewing agent configuration."
---

# Claudex Routing Reference

- Root thread remains coordinator, ordinary implementer, final integrator, and verification synthesizer.
- `claudex-luna`: wide read-only inventories, maps, structured data analysis, validation anomalies, naming/log/test/diff classification.
- `claudex-sol`: read-only architecture alternatives, risk triage, plan feedback, consequential ambiguity.
- `claudex-sol-review`: read-only PASS / CHANGES_REQUIRED / BLOCKED gate for consequential or substantial/sensitive work.
- `claudex-frontend`: bounded frontend-only implementation, styling, accessibility, responsive behavior, visual checks, frontend tests.
- One subagent by default; at most three concurrently; no nested delegation.
- Consequential work needs Sol Review before implementation/plan approval and again before completion/merge-ready.
- Do not infer session lifecycle from quiet agents, hooks, process state, or local agent views. Do not add monitoring/resume/restart machinery without a separate reviewed design.
