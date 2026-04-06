---
name: rfc-impl
description: Create new branches for a given RFC or feature request and implement.
license: MIT
compatibility: opencode
---

## What I do

- Create a new branch using Git.
- Implement the RFC in that new branch based on workspace context.
- Commit each stages' file changes.

## When to use me

Use this when you are proposed with a fully documented feature request.

## Detailed Workflow

1. Create a new Git branch based on the RFC. The name should be in this format: `feat/foo-bar`.
2. Draft a plan to implement the feature request.
3. Implement the plan based on user input and workspace context.
   - For **each** stage, you should collect the files and commit them.
   - Your commit message should follow the "conventional commit".
   - You **should not** create commits containing complex works. Split them up.
4. After your implementation, pose a short conclusion on your changes.
   - The conclusion **must** contain your **unimplemented** aspects.
   - The conclusion **must** contain your behavior choices that's not specified in the initial user input.
   - The conclusion **should** contain what your changes might impact beyond the feature request.
