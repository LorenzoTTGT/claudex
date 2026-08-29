---
name: claudex-routing
description: "Use whenever a user asks to plan, review a plan, discuss planning, make or review an architecture choice, or says plan/planning/architecture/architectural in an operative request. Also use when deciding delegation or reviewing agent configuration. Provides the Claudex-equivalent routing policy for root coordination, Luna/Sol/Sol Review/Frontend roles, review gates, and session-supervision boundaries."
---

# Claudex Routing Reference

- Root thread remains coordinator, small-edit executor, final integrator, and verification synthesizer; substantial bounded non-frontend implementation can route to the GPT-5.6 Sol-backed implementer.
- An operative user mention of `plan`, `planning`, `architecture`, or `architectural` directly triggers a scoped `claudex-sol` invocation for non-trivial plans; clearly negated mentions do not, and tiny direct edits should not be planned solely to trigger Sol.
- `claudex-luna`: wide read-only inventories, maps, structured data analysis, validation anomalies, naming/log/test/diff classification.
- `claudex-sol`: scoped read-only feedback for non-trivial implementation plans or architecture choices; also architecture alternatives and risk triage. Reserve high-effort Sol passes for major planning, security-sensitive architecture, migrations, public contracts, release blockers, or unresolved disagreement.
- `claudex-sol-review`: read-only PASS / CHANGES_REQUIRED / BLOCKED gate for consequential, release-critical, experimental/non-primary implementation, or substantial/sensitive work; not for tiny, bounded, reversible, non-sensitive edits.
- `claudex-frontend`: bounded frontend-only implementation, styling, accessibility, responsive behavior, visual checks, frontend tests.
- One subagent by default; at most three concurrently; no nested delegation.
- One Sol invocation may cover a plan and its architecture choices. Invoke Sol again after a material plan revision or a new architecture choice. Trivial direct edits needing neither do not trigger Sol.
- Sol advisory and GPT-5.6 Sol-backed implementation never satisfy or replace a required `claudex-sol-review` gate.
- Consequential work needs Sol Review before implementation/plan approval and again before completion/merge-ready, regardless of which model implemented it. Prefer risk-based review triggers over model identity; routine low-risk GPT-5.6 Sol implementation does not by itself require Sol Review.
- Do not infer session lifecycle from quiet agents, hooks, process state, or local agent views. Do not add monitoring/resume/restart machinery without a separate reviewed design.
