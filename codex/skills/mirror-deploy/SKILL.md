---
name: mirror-deploy
description: "Deploy via Vercel mirror repo (shpdrdlabel/deardogs-label-website): check for changes, optionally commit with a smart message, push to origin main, run ./scripts/mirror-push.sh, and confirm both repos are synced. Use when asked to mirror-deploy or push via the deployment mirror."
---

# Mirror Deploy

## Overview

Deploy to Vercel through the mirror repo workflow, including optional commit and mirror push.

## Required Workflow

1. Check for uncommitted changes:
   - `git status`
   - If no changes, skip to step 4.
1. If there are changes, analyze them:
   - `git diff`
   - Understand what changed (feat/fix/refactor/etc.).
1. Commit changes with a smart message:
   - `git add -A`
   - Commit message format:

```
<type>: <short summary in imperative mood>

Co-Authored-By: Claude <noreply@anthropic.com>
```

   - Commit types: `feat`, `fix`, `refactor`, `docs`, `style`, `perf`, `test`, `chore`
   - Use heredoc format.
1. Push to origin:

```bash
git push origin main
```

1. Mirror to deployment repo:

```bash
./scripts/mirror-push.sh
```

1. Confirm success:
   - Show commit hash.
   - Confirm both repos are synced.

## Output Expectations

- Report whether changes were found.
- If a commit was created, show the hash and summary.
- Confirm `origin/main` push and mirror push completed.
