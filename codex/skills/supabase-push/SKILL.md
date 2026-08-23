---
name: supabase-push
description: "Push pending Supabase migrations only when explicitly asked, using project environment/configuration and reporting applied migrations or errors."
---

# Supabase Push

Use only when the user explicitly asks to push Supabase migrations.

Run the project's configured Supabase migration command using environment variables/config files already present in the project. If the push fails, report DNS/connection/SQL errors clearly and retry only when appropriate. Do not invent credentials or target projects.
