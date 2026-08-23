---
name: supabase-sql
description: "Run a Supabase/Postgres SQL query only when explicitly authorized; prefer project environment variables or existing project config over hardcoded credentials."
---

# Supabase SQL

Use only for explicitly requested database inspection or mutation.

Prefer project `.env` variables, Supabase CLI configuration, or approved MCP/database tools. For read-only questions, run read-only SQL. For schema/data mutations, confirm authorization and explain the intended effect first unless already explicit.

Report query results concisely and include errors verbatim.
