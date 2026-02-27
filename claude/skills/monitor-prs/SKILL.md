---
name: monitor-prs
description: "Monitor all open PRs, showing CI and review status in a tmux dashboard. Automatically fixes CI failures and restacks branches."
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

## Restacking after fixes

If a CI fix is pushed to a parent branch in a stack, the child PRs may need restacking:

1. Check out the child branch in a slot.
2. Run `gt restack` to rebase it onto the updated parent.
3. Push with `gt submit --stack --no-interactive`.
4. Detach and repeat for any further children in the stack.
