---
name: smart-commit
description: "Create an AI-assisted git commit only when explicitly asked to commit or push: inspect status/diffs, generate a structured commit message, stage changes, commit via heredoc, optionally push if requested, and report the result."
---

# Smart Commit

Use only when the user explicitly asks to commit, smart-commit, or commit-and-push.

## Workflow

1. Inspect changes with `git status`, `git diff`, and `git diff --cached` when staged changes exist.
2. Identify the user-visible outcome, change type, and important technical details.
3. If on a default branch and a branch is needed for the user's request, ask before branching unless the user already authorized it.
4. Stage the intended changes with `git add -A` only after confirming the full diff is appropriate.
5. Commit with a heredoc message:

```text
<type>: <short imperative summary>

<brief explanation of what changed and why>

- Key change 1
- Key change 2

Co-Authored-By: Claude <noreply@anthropic.com>
```

6. Push only if the user explicitly asked to push. If push fails due to missing upstream, show the suggested upstream command instead of guessing.
7. Report commit hash, files changed, checks considered/run, and push status.

Do not deploy, publish, or mutate external systems unless explicitly requested.
