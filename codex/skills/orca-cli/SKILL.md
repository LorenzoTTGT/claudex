---
name: orca-cli
description: "Work with Orca CLI/runtime configuration and hooks only when explicitly asked; preserve Orca-managed files and avoid session supervision or restart machinery."
---

# Orca CLI

When inspecting or updating Orca-related config, prefer read-only inspection first, preserve Orca-managed hooks/runtime files unless the user explicitly asks for a configuration change, and do not implement session monitoring, automatic resume, restart, steering, or lifecycle inference from hooks or local process state.

For Codex-in-Orca alignment, keep user/global routing, agent definitions, and skills synchronized with the Claudex-equivalent policy while respecting Orca-managed runtime ownership.
