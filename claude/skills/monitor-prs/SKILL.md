---
name: monitor-prs
description: "Monitor all open PRs, showing CI and review status in a tmux dashboard. Automatically fixes CI failures, addresses review feedback, and restacks branches."
---

# Monitor PRs

Monitor all of the user's open PRs. This runs as a separate agent process from the one authoring features.

## Dashboard script

A standalone dashboard script lives at `~/.claude/skills/monitor-prs/pr-monitor.sh`. It handles:
- Polling `gh pr list --author @me` every 2 minutes
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

## Fixing CI failures

When CI fails on a PR:

1. Find an available worktree slot by checking which of `~/figma/slot{1,2,3}` has a detached HEAD.
2. Check out the PR branch in that slot: `git -C ~/figma/slotN checkout <branch>`
3. Use the `/monitor-ci` skill to diagnose and fix the failure.
4. Push the fix using `gt submit --stack --no-interactive`.
5. Detach from the branch: `git -C ~/figma/slotN checkout --detach`
6. Resume monitoring all PRs.

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
   a. Find an available worktree slot (detached HEAD in `~/figma/slot{1,2,3}`).
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
