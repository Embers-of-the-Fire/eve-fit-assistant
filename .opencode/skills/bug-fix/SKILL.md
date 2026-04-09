---
name: bug-fix
description: Fix a bug based on a github issue.
license: MIT
compatibility: opencode
---

## What I do

- Create a new branch using Git.
- Design a plan to fix the bug based on workspace context.
- Implement the plan based on user input and workspace context.
- Commit each stages' file changes.

## When to use me

Use this when you are proposed with a bug report.

## Detailed Workflow

1. Create a new Git branch based on the bug report. The name should be in this format: `bug/foo-bar`.
2. Draft a plan to fix the bug.
3. Implement the plan based on user input and workspace context.
   - For **each** stage, you should collect the files and commit them.
   - Your commit message should follow the "conventional commit".
4. After your implementation, pose a short conclusion on your changes.
   - The conclusion **must** contain your **unfixed** aspects.
   - The conclusion **must** contain your behavior choices that's not specified in the initial user input.
   - The conclusion **should** contain what your changes might impact beyond the bug fix.
