---
name: submit-pr
description: "Push branch and create a PR via Graphite with proper title, description, reviewers, and worktree cleanup."
argument-hint: "[--follow-up] [--skip-review]"
---

# Submit PR

Push the current branch and create a GitHub PR using Graphite.

## Arguments

- **--follow-up**: This is a follow-up commit to an existing PR (skips review and PR creation, just pushes).
- **--skip-review**: Skip the self-review step (for trivial changes).

## Step 1: Self-review the diff

Skip this step if `--follow-up` or `--skip-review` was passed.

Launch a subagent (via the Task tool, subagent_type "general-purpose") to review the diff against the style guide. The subagent prompt should be:

```
Review the git diff and fix any violations of the style rules below. Only check code that was added or modified in the diff — do not touch unrelated code. Make at most one pass of fixes, then stop.

Run `git diff main...HEAD` to get the diff.

**Style rules — fix any violations you find:**

1. ALWAYS use early returns over nested if statements
2. ALWAYS use curly braces for if statements (never `if (x) doThing()`)
3. ALWAYS inline short objects (use one line for simple 1-3 field objects)
4. NEVER export functions that are only used within the same file
5. ALWAYS use SNAKE_CASE for consts and magic numbers
6. ALWAYS group related statements with a blank line and a short comment header
7. NEVER use non-null assertions (`!` postfix) — use null checks or early returns
8. ALWAYS add a brief comment above useEffect explaining its purpose
9. ALWAYS extract component props into a named `{Component}Props` type

If you find violations, fix them directly in the files and stage the changes with `git add`. Report what you fixed. If the diff is clean, report "No style violations found."
```

If the subagent made fixes, stage them into the current commit:

```bash
git add -u && git commit --amend --no-edit
```

## Step 2: Push the branch

```bash
gt submit --stack --no-interactive
```

Always use `gt` — never fall back to raw `git push`.

### If `gt submit` fails because a parent branch was merged

Run `gt sync` then `gt restack` to rebase onto trunk, then retry `gt submit --stack --no-interactive`. Never use raw `git rebase` — always use Graphite commands to keep stack metadata in sync.

## Step 3: Handle follow-up commits

If `--follow-up` was passed, stop here — the push is done.

For follow-up commits in general: use `gt commit create -m "..."` to add a new commit, then `gt submit --stack --no-interactive`. Do **not** use `gt modify` — it amends the previous commit and requires force-push, which is blocked by branch protection.

## Step 4: Set PR title and description

`gt submit` creates PRs in draft with no description. Always update both:

```bash
gh api repos/{owner}/{repo}/pulls/{number} --method PATCH -f title="..." -f body="..."
```

Use `gh api` — the `gh pr edit` command may silently fail.

### Title format

`{area}: {brief user-facing title}`

- Area is determined by which directories/files the change touches:
  - `fullscreen` — changes in `fullscreen/`
  - `web` — changes in `web/`
  - `sinatra` — changes in `sinatra/`
  - `cortex` — changes in `cortex/`
  - `config` — feature flag changes, `.yml` or `.json` config files
- Multiple areas: join with `/` (e.g., `fullscreen/web: ...`)
- Keep the title brief (~6 words)
- **Write titles from the user's perspective**, not the implementation. Describe the *behavior change*, not the code change.
- Examples:
  - Bad: `fullscreen/web: Add HDR video tone-mapping shader` (implementation detail)
  - Good: `fullscreen/web: improve in-canvas HDR video playback` (user-facing)
  - Bad: `web: Add clientside validation to form inputs` (implementation)
  - Good: `web: validate required inputs before submit` (user-facing)
  - `config: remove aip_magnolia flag`
  - `sinatra: add rate limiting to export endpoint`

### Description

Write the description in this structure:

1. **Summary** (1-3 sentences): High-level *what* and *why*. If gated behind a feature flag, link to it in the Statsig console: `[flag_name](https://console.statsig.com/5ETXMP5xDW3P7AMyQ14tey/gates/flag_name)`. If you explored alternative approaches and rejected them, briefly explain why.
2. **`Fixes:` line**: Always include an Asana link if the user mentioned one, or write `Fixes: ASANA_LINK_HERE` as a placeholder for the user to fill in.
3. **`## Test plan` section**: Always include this. Prefill with: `1. Open commit preview` then add 1-2 steps specific to what was changed.

Example:

```
Better color support for in-canvas HDR videos, gated behind the [video_hdr_in_canvas](https://console.statsig.com/5ETXMP5xDW3P7AMyQ14tey/gates/video_hdr_in_canvas) flag. Uses a custom shader to map the HDR color space to SDR.

Also explored upgrading from 8-bit to 16-bit colors but that severely degraded performance. With a shader, we keep the same fast RGBA8 upload path, meaning no performance hit.

Fixes: ASANA_LINK_HERE

## Test plan
1. Open commit preview
2. Upload an HDR video and verify colors look correct
```

## Step 5: Mark ready for review

```bash
gh pr ready
```

## Step 6: Request reviewers

Look at recent trunk PRs (especially from the same stack or area of the codebase) to find relevant reviewers:

```bash
gh pr edit --add-reviewer <user1>,<user2>
```

## Step 7: Clean the worktree

Detach HEAD so the monitoring agent can check out the branch in a slot if needed:

```bash
git checkout --detach
```
