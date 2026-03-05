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
AVIATOR_TOKEN_FILE="$HOME/.config/aviator/token"
touch "$STATE_FILE"

# Column widths (content only, excluding border chars and padding)
W_PR=8
W_TITLE=64
W_CI=12
W_REV=23

# Build border strings from column widths
border_seg() { printf '─%.0s' $(seq 1 $(($1 + 2))); }
SEG_PR=$(border_seg $W_PR)
SEG_TITLE=$(border_seg $W_TITLE)
SEG_CI=$(border_seg $W_CI)
SEG_REV=$(border_seg $W_REV)

TOP="┌${SEG_PR}┬${SEG_TITLE}┬${SEG_CI}┬${SEG_REV}┐"
MID="├${SEG_PR}┼${SEG_TITLE}┼${SEG_CI}┼${SEG_REV}┤"
BOT="└${SEG_PR}┴${SEG_TITLE}┴${SEG_CI}┴${SEG_REV}┘"
ROW_FMT="│ %-${W_PR}s │ %-${W_TITLE}s │ %-${W_CI}s │ %-${W_REV}s │\n"

echo "Starting PR monitor..." > "$STATUS_FILE"

while true; do
  prs=$(gh pr list --author @me --repo figma/figma --json number,title,reviewDecision,mergeStateStatus,labels,state,isDraft --limit 20 2>&1)
  prs=$(echo "$prs" | jq '[.[] | select(.isDraft == false)]')
  count=$(echo "$prs" | jq 'length')

  # Build table header
  output="${TOP}\n"
  output+="$(printf "$ROW_FMT" 'PR' 'Title' 'CI' 'Review')\n"
  output+="${MID}\n"

  if [ "$count" = "0" ]; then
    output+="$(printf "$ROW_FMT" '' 'No open PRs' '' '')\n"
    output+="${BOT}\n"
    echo -e "$output" > "$STATUS_FILE"
    sleep 120
    continue
  fi

  # Fetch Aviator merge queue (one call per cycle)
  # Pre-extract into a lookup file: "pr_number position total" per line
  QUEUE_FILE="/tmp/pr_monitor_queue"
  > "$QUEUE_FILE"
  if [ -f "$AVIATOR_TOKEN_FILE" ]; then
    aviator_token=$(cat "$AVIATOR_TOKEN_FILE")
    curl -s -H "Authorization: Bearer $aviator_token" \
      "https://api.aviator.co/api/v1/pull_request/queued?org=figma&repo=figma" 2>/dev/null | \
      jq -r '(.pull_requests | length) as $total | .pull_requests | to_entries[] | "\(.value.number) \(.key + 1) \($total)"' \
      > "$QUEUE_FILE" 2>/dev/null
  fi

  echo "$prs" | jq -r '.[].number' | while read pr_num; do
    title=$(echo "$prs" | jq -r ".[] | select(.number == $pr_num) | .title")
    review=$(echo "$prs" | jq -r ".[] | select(.number == $pr_num) | .reviewDecision")
    merge_state=$(echo "$prs" | jq -r ".[] | select(.number == $pr_num) | .mergeStateStatus")
    has_rtm=$(echo "$prs" | jq -r ".[] | select(.number == $pr_num) | [.labels[].name] | index(\"ready-to-merge\") // empty")
    has_blocked=$(echo "$prs" | jq -r ".[] | select(.number == $pr_num) | [.labels[].name] | index(\"blocked\") // empty")
    state=$(echo "$prs" | jq -r ".[] | select(.number == $pr_num) | .state")

    # CI status
    if [ -n "$has_blocked" ]; then
      ci="BLOCKED"
    else
      checks_output=$(gh pr checks "$pr_num" --repo figma/figma 2>/dev/null)
      fails=$(echo "$checks_output" | grep -E "^\S+\tfail\t" | grep -v "notify-failure" | wc -l | tr -d ' ')
      pending=$(echo "$checks_output" | grep -E "pending|running" | wc -l | tr -d ' ')

      if [ "$fails" -gt 0 ]; then
        ci="FAILED"
      elif [ "$pending" -gt 0 ]; then
        ci="pending ($pending)"
      else
        ci="passed"
      fi
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

    # Queue position (replaces rtm label when in queue)
    q_line=$(grep "^$pr_num " "$QUEUE_FILE" 2>/dev/null)
    if [ -n "$q_line" ]; then
      q_pos=$(echo "$q_line" | cut -d' ' -f2)
      q_total=$(echo "$q_line" | cut -d' ' -f3)
      rev="queued #${q_pos}/${q_total}"
    elif [ -n "$has_rtm" ]; then
      rev="$rev [rtm]"
    fi

    # Truncate title (ASCII only to avoid multi-byte printf issues)
    if [ ${#title} -gt $W_TITLE ]; then
      short_title="${title:0:$((W_TITLE - 2))}.."
    else
      short_title="$title"
    fi

    # Truncate review
    if [ ${#rev} -gt $W_REV ]; then
      short_rev="${rev:0:$((W_REV - 2))}.."
    else
      short_rev="$rev"
    fi

    printf "$ROW_FMT" "#$pr_num" "$short_title" "$ci" "$short_rev"

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
  TABLE="$output$(cat /tmp/pr_table_rows.txt)\n${BOT}"

  # Countdown loop
  for ((i=120; i>=0; i--)); do
    mins=$((i / 60))
    secs=$((i % 60))
    echo -e "$TABLE\nNext check in ${mins}m $(printf '%02d' $secs)s" > "${STATUS_FILE}.tmp" && mv "${STATUS_FILE}.tmp" "$STATUS_FILE"
    sleep 1
  done
done
