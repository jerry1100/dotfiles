---
name: submit-pr
description: "Push branch and create a PR via Graphite with proper title, description, reviewers, and worktree cleanup."
argument-hint: "[--follow-up]"
---

# Submit PR

Push the current branch and create a GitHub PR using Graphite.

## Arguments

- **--follow-up**: This is a follow-up commit to an existing PR (skips PR creation, just pushes).

## Step 1: Push the branch

```bash
gt submit --stack --no-interactive
```

Always use `gt` — never fall back to raw `git push`.

### If `gt submit` fails because a parent branch was merged

Run `gt sync` then `gt restack` to rebase onto trunk, then retry `gt submit --stack --no-interactive`. Never use raw `git rebase` — always use Graphite commands to keep stack metadata in sync.

## Step 2: Handle follow-up commits

If `--follow-up` was passed, stop here — the push is done.

For follow-up commits in general: use `gt commit create -m "..."` to add a new commit, then `gt submit --stack --no-interactive`. Do **not** use `gt modify` — it amends the previous commit and requires force-push, which is blocked by branch protection.

## Step 3: Set PR title and description

`gt submit` creates PRs in draft with no description. Always update both:

```bash
gh api repos/{owner}/{repo}/pulls/{number} --method PATCH -f title="..." -f body="..."
```

Use `gh api` — the `gh pr edit` command may silently fail.

### Title format

`{area}: {brief title}`

- Area is determined by which directories/files the change touches:
  - `fullscreen` — changes in `fullscreen/`
  - `web` — changes in `web/`
  - `sinatra` — changes in `sinatra/`
  - `cortex` — changes in `cortex/`
  - `config` — feature flag changes, `.yml` or `.json` config files
- Multiple areas: join with `/` (e.g., `fullscreen/web: ...`)
- Keep the title brief (~6 words)
- Examples:
  - `config: remove aip_magnolia flag`
  - `fullscreen/web: support image references in weave apps`
  - `sinatra: add rate limiting to export endpoint`

### Description

1-2 short sentences. Focus on the high-level *what* and *why* — don't restate implementation details the diff already shows.

- Bad: "Adds client-side validation to the Weave App dialog form. When the user clicks Generate without filling in all required inputs, the empty fields are highlighted with a red outline and a 'Field is required' message appears below each one."
- Good: "Adds basic clientside validation to ensure all inputs are filled out before the user submits."

## Step 4: Mark ready for review

```bash
gh pr ready
```

## Step 5: Request reviewers

Look at recent trunk PRs (especially from the same stack or area of the codebase) to find relevant reviewers:

```bash
gh pr edit --add-reviewer <user1>,<user2>
```

## Step 6: Clean the worktree

Detach HEAD so the monitoring agent can check out the branch in a slot if needed:

```bash
git checkout --detach
```
