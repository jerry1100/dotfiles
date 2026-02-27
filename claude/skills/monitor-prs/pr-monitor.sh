#!/bin/bash
# PR Monitor — polls every 2 min, writes table to /tmp/pr_status.txt
# Also sends macOS notifications on state changes and auto-labels ready-to-merge
#
# Usage:
#   pr-monitor.sh              # run in foreground
#   pr-monitor.sh &disown      # run in background
#
# View the dashboard in another terminal:
#   watch -n1 cat /tmp/pr_status.txt

STATUS_FILE="/tmp/pr_status.txt"
STATE_FILE="/tmp/pr_monitor_state"
touch "$STATE_FILE"

echo "Starting PR monitor..." > "$STATUS_FILE"

while true; do
  prs=$(gh pr list --author @me --json number,title,reviewDecision,mergeStateStatus,labels,state --limit 20 2>&1)
  count=$(echo "$prs" | jq 'length')

  # Build table header
  output="┌──────────┬────────────────────────────────────────────────────┬──────────────┬─────────────────────────┐\n"
  output+="$(printf '│ %-8s │ %-50s │ %-12s │ %-23s │\n' 'PR' 'Title' 'CI' 'Review')\n"
  output+="├──────────┼────────────────────────────────────────────────────┼──────────────┼─────────────────────────┤\n"

  if [ "$count" = "0" ]; then
    output+="│ No open PRs                                                                      │\n"
    output+="└──────────┴────────────────────────────────────────┴──────────────┴──────────────┘\n"
    echo -e "$output" > "$STATUS_FILE"
    sleep 120
    continue
  fi

  echo "$prs" | jq -r '.[].number' | while read pr_num; do
    title=$(echo "$prs" | jq -r ".[] | select(.number == $pr_num) | .title")
    review=$(echo "$prs" | jq -r ".[] | select(.number == $pr_num) | .reviewDecision")
    merge_state=$(echo "$prs" | jq -r ".[] | select(.number == $pr_num) | .mergeStateStatus")
    has_rtm=$(echo "$prs" | jq -r ".[] | select(.number == $pr_num) | [.labels[].name] | index(\"ready-to-merge\") // empty")
    state=$(echo "$prs" | jq -r ".[] | select(.number == $pr_num) | .state")

    fails=$(gh pr checks "$pr_num" 2>&1 | grep -E "^\S+\tfail\t" | grep -v "notify-failure" | wc -l | tr -d ' ')
    pending=$(gh pr checks "$pr_num" 2>&1 | grep -E "pending|running" | wc -l | tr -d ' ')

    # CI status
    if [ "$fails" -gt 0 ]; then
      ci="FAILED"
    elif [ "$pending" -gt 0 ]; then
      ci="pending ($pending)"
    else
      ci="passed"
    fi

    # Review status
    case "$review" in
      APPROVED) rev="approved" ;;
      CHANGES_REQUESTED) rev="changes req" ;;
      REVIEW_REQUIRED) rev="needs review" ;;
      *) rev="$review" ;;
    esac

    # Merge conflict indicator
    if [ "$merge_state" = "DIRTY" ]; then
      rev="$rev [conflict]"
    fi

    # Label indicator
    if [ -n "$has_rtm" ]; then
      rev="$rev [rtm]"
    fi

    # Truncate title
    short_title=$(echo "$title" | cut -c1-49)
    [ ${#title} -gt 49 ] && short_title="${short_title}…"

    # Truncate review to column width
    short_rev=$(echo "$rev" | cut -c1-23)

    printf '│ %-8s │ %-50s │ %-12s │ %-23s │\n' "#$pr_num" "$short_title" "$ci" "$short_rev"

    # State tracking for notifications
    line="$pr_num|$ci|$review|$merge_state"
    prev=$(grep "^$pr_num|" "$STATE_FILE" 2>/dev/null || true)

    if [ -n "$prev" ] && [ "$prev" != "$line" ]; then
      prev_ci=$(echo "$prev" | cut -d'|' -f2)
      prev_review=$(echo "$prev" | cut -d'|' -f3)

      [ "$ci" = "FAILED" ] && [ "$prev_ci" != "FAILED" ] && \
        osascript -e "display notification \"CI failed on #$pr_num\" with title \"PR Monitor\" subtitle \"$title\"" 2>/dev/null
      [ "$ci" = "passed" ] && [ "$prev_ci" != "passed" ] && \
        osascript -e "display notification \"CI passed on #$pr_num\" with title \"PR Monitor\" subtitle \"$title\"" 2>/dev/null
      [ "$review" = "APPROVED" ] && [ "$prev_review" != "APPROVED" ] && \
        osascript -e "display notification \"PR #$pr_num approved!\" with title \"PR Monitor\" subtitle \"$title\"" 2>/dev/null
      [ "$review" = "CHANGES_REQUESTED" ] && [ "$prev_review" != "CHANGES_REQUESTED" ] && \
        osascript -e "display notification \"Changes requested on #$pr_num\" with title \"PR Monitor\" subtitle \"$title\"" 2>/dev/null
    fi

    # Auto-label ready-to-merge
    if [ "$ci" = "passed" ] && [ "$review" = "APPROVED" ] && [ -z "$has_rtm" ]; then
      gh api "repos/figma/figma/issues/$pr_num/labels" -f "labels[]=ready-to-merge" >/dev/null 2>&1
      osascript -e "display notification \"Added ready-to-merge to #$pr_num\" with title \"PR Monitor\" subtitle \"$title\"" 2>/dev/null
    fi

    # Update state
    grep -v "^$pr_num|" "$STATE_FILE" > "${STATE_FILE}.tmp" 2>/dev/null || true
    echo "$line" >> "${STATE_FILE}.tmp"
    mv "${STATE_FILE}.tmp" "$STATE_FILE"
  done > /tmp/pr_table_rows.txt

  # Write table (without countdown — that gets appended by the countdown loop)
  TABLE="$output$(cat /tmp/pr_table_rows.txt)\n└──────────┴────────────────────────────────────────────────────┴──────────────┴─────────────────────────┘"

  # Countdown loop
  for ((i=120; i>=0; i--)); do
    mins=$((i / 60))
    secs=$((i % 60))
    echo -e "$TABLE\nNext check in ${mins}m $(printf '%02d' $secs)s" > "$STATUS_FILE"
    sleep 1
  done
done
