---
name: clickup-wip
description: "Mark a ClickUp task as in progress only when explicitly asked or when starting user-authorized task work that requires remote task status updates."
---

# ClickUp WIP

Mark the specified ClickUp task as in progress and update the relevant local tracker if one exists.

Before mutating ClickUp, confirm the user authorized task-status updates in this request or workflow.

After implementation, summarize what changed and give manual test instructions. Do not call `clickup-done` yourself; remind the user to run it after they verify the fix.
