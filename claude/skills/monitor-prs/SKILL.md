---
name: monitor-prs
description: "Monitor all open PRs, showing CI and review status in a tmux dashboard. Automatically fixes CI failures, addresses review feedback, and restacks branches."
---

# Monitor PRs

Monitor all of the user's open PRs. This runs as a separate agent process from the one authoring features.

## Dashboard script

A standalone dashboard script lives at `~/.claude/skills/monitor-prs/pr-monitor.sh`. It handles:
- Polling `gh pr list --author @me` every minute (draft PRs are excluded)
- Writing a formatted status table to `/tmp/pr_status.txt`
- Sending macOS notifications on state changes (CI pass/fail, review approved/changes requested)
- Auto-labeling `ready-to-merge` when CI passes and PR is approved

### Starting the dashboard

Start the monitor script in the background, then display the live table in tmux.

**Important:** Do not create a new tmux session if one already exists. Instead, join the existing session and create a split pane.

```bash
~/.claude/skills/monitor-prs/pr-monitor.sh &disown

# If a tmux session exists, add a split pane; otherwise create a new session
if tmux list-sessions 2>/dev/null | head -1; then
  SESSION=$(tmux list-sessions -F '#{session_name}' 2>/dev/null | head -1)
  tmux split-window -t "$SESSION" 'while true; do clear; cat /tmp/pr_status.txt 2>/dev/null || echo "Waiting for data..."; sleep 1; done'
  tmux rename-window -t "$SESSION" "Monitor PRs"
else
  tmux new-session -d -s monitor 'while true; do clear; cat /tmp/pr_status.txt 2>/dev/null || echo "Waiting for data..."; sleep 1; done'
  tmux rename-window -t monitor "Monitor PRs"
fi
```

## CI failure watcher

After starting the dashboard, run a background watcher that triggers automatically when CI fails:

```bash
~/.claude/skills/monitor-prs/ci-watcher.sh
```

The watcher blocks on `/tmp/pr_monitor_trigger` (written by `pr-monitor.sh` when it detects a confirmed CI failure — requires two consecutive poll cycles showing failure). When triggered, the watcher batches all new failures over 15s, outputs them all, and exits.

Run this with `run_in_background: true`. When it completes, **immediately restart the watcher first**, then start diagnosing. This minimizes the gap where failures could be missed. After handling, the watcher is already running — no need to restart again.

## Fixing CI failures and blocked PRs

`FAILED` and `BLOCKED` PRs are treated the same way — both trigger automatic diagnosis and fix.

### Finding the failure

- **`FAILED` PRs**: Use `gh pr checks <number>` to find the failed check, then inspect Buildkite logs.
- **`BLOCKED` PRs**: The `blocked` label is added by Aviator when CI fails while the PR is in the merge queue. The failure may not show up in `gh pr checks` on the PR's own branch — it happened on Aviator's merge validation build. To find it:
  1. Fetch the latest Aviator bot comment: `gh pr view <number> --json comments --jq '[.comments[] | select(.author.login == "aviator-app")] | last | .body'`
  2. The comment contains a link to the failed CI job and a reason (e.g. "CI timed out", specific check failure). Use that to diagnose.

### Triage

Before spinning up a subagent, determine if the failure is infrastructure or code:

**Infrastructure/flaky failures** (no code fix needed):
- "CI timed out"
- AWS spot termination (`spot_termination` in logs)
- "Max flaky retries reached" with no PR-related cause
- Any failure where the retry service says the failure is NOT PR-related
- Known flaky tests (marked "flaky, suppressed" in annotations)

Before declaring a failure as flaky and retriggering:
1. Search Slack for the test name: `mcp__slack__search` with the test name or service
2. Show the user the relevant Slack threads confirming it's a known flaky
3. Then automatically retrigger CI

For retriggering: push an empty commit from a worktree slot, remove `blocked` label if present, and restart the watcher.

For `BLOCKED` PRs: `gh api repos/{owner}/{repo}/issues/{number}/labels/blocked -X DELETE`
For `FAILED` PRs: push an empty commit to retrigger: `cd <worktree> && git commit --allow-empty -m "retrigger CI" && gt submit --stack --no-interactive`

**Code failures** (retry service says PR-related, or actual test/build errors): Proceed to the fixing steps below.

### Fixing

1. Find an available worktree slot by running `slots` (slots showing "available (detached)" are free).
2. Spin up a subagent (Task tool) in that slot to check out the branch and diagnose the failure.
3. If the fix is straightforward and you're confident, push directly without asking.
4. If the fix is complex or ambiguous, present the diagnosis and proposed fix to the user and wait for approval.
5. Push with `gt submit --stack --no-interactive` from the slot.
6. If the PR had the `blocked` label, remove it: `gh api repos/{owner}/{repo}/issues/{number}/labels/blocked -X DELETE`
7. Aviator will auto-re-queue since the PR has the `ready-to-merge` label.
8. Detach HEAD: `git -C ~/figma/slotN checkout --detach`
9. Restart the CI failure watcher.

Note: Use `gh api` to remove labels — `gh pr edit --remove-label` fails due to a GitHub Projects Classic deprecation error.

If no slots are available, inform the user and wait.

## Addressing review feedback

When a new review comment comes in on a PR:

1. Fetch the PR's inline comments: `gh api repos/{owner}/{repo}/pulls/{number}/comments`
2. Track which comments you've already seen in `/tmp/pr_monitor_comments`. Skip any comment IDs already recorded.
3. For each new comment, determine if it's **actionable** (requests a code change) or **informational** (praise, acknowledgement, question that doesn't need a code change). Skip non-actionable comments.
4. For actionable comments:
   a. Read the relevant file and surrounding code to gather context.
   b. Present your analysis to the user: what the reviewer is asking for, whether you agree, and what the fix would look like.
   c. Send a macOS notification so the user knows to check the terminal: `osascript -e 'display notification "Review comment on #NNN" with title "PR Monitor" subtitle "..."'`
   d. **Wait for user approval** before making any changes.
5. If the user approves the fix:
   a. Find an available worktree slot by running `slots` (slots showing "available (detached)" are free).
   b. Spin up a subagent (Task tool) in that slot to check out the branch, apply the fix, and commit.
   c. **Do not push yet.** The subagent should stop after committing.
   d. Tell the user what was changed and send another notification.
   e. **Wait for user approval** before pushing.
6. If the user approves the push:
   a. Push with `gt submit --stack --no-interactive` from the slot.
   b. Detach HEAD: `git -C ~/figma/slotN checkout --detach`
   c. Record the comment ID in `/tmp/pr_monitor_comments` so it's not processed again.

**Important:** Never push review feedback fixes without two explicit approvals from the user — one to make the change, one to push it.

## Restacking after fixes

If a CI fix is pushed to a parent branch in a stack, the child PRs may need restacking:

1. Check out the child branch in a slot.
2. Run `gt restack` to rebase it onto the updated parent.
3. Push with `gt submit --stack --no-interactive`.
4. Detach and repeat for any further children in the stack.
