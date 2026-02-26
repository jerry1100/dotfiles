# Monitor PRs

Monitor all of the user's open PRs. This runs as a separate agent process from the one authoring features.

## Fetching PRs

Use `gh pr list --author @me` to get all open PRs authored by the user.

## Status loop

Poll each PR periodically and display a summary table with two columns:

**CI status** (one of):
- `waiting on CI` — checks are still running
- `CI passed` — all checks green
- `fixing CI` — you are actively pushing a fix for a failed check
- `in queue` — PR is in the merge queue
- `merged` — PR has been merged

**Review status** (one of):
- `approved` — at least one approving review, no outstanding requests for changes
- `has feedback` — there are review comments but no explicit approval or rejection
- `changes requested` — a reviewer has requested changes

## Auto-labeling

If a PR meets **all** of the following conditions, add the `ready-to-merge` label:

1. CI has passed
2. The PR is approved (no outstanding change requests)
3. There are no unresolved review comments that raise concerns

## Fixing CI failures

When CI fails on a PR:

1. Find an available worktree slot by checking which of `~/figma/slot{1,2,3}` has a detached HEAD.
2. Check out the PR branch in that slot: `git -C ~/figma/slotN checkout <branch>`
3. Use the `/monitor-ci` skill to diagnose and fix the failure.
4. Push the fix using `gt submit --stack --no-interactive`.
5. Detach from the branch: `git -C ~/figma/slotN checkout --detach`
6. Resume monitoring all PRs.

If no slots are available, inform the user and wait.

## Restacking after fixes

If a CI fix is pushed to a parent branch in a stack, the child PRs may need restacking:

1. Check out the child branch in a slot.
2. Run `gt restack` to rebase it onto the updated parent.
3. Push with `gt submit --stack --no-interactive`.
4. Detach and repeat for any further children in the stack.
