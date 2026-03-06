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

# Column widths (shared by both tables, 112 total width)
W1=64
W2=16
W3=24

# Review queue file
REVIEW_QUEUE="/tmp/pr_review_queue"

border_seg() { printf '─%.0s' $(seq 1 $(($1 + 2))); }
SEG1=$(border_seg $W1)
SEG2=$(border_seg $W2)
SEG3=$(border_seg $W3)
TOP="┌${SEG1}┬${SEG2}┬${SEG3}┐"
MID="├${SEG1}┼${SEG2}┼${SEG3}┤"
BOT="└${SEG1}┴${SEG2}┴${SEG3}┘"
ROW_FMT="│ %-${W1}s │ %-${W2}s │ %-${W3}s │\n"


echo "Starting PR monitor..." > "$STATUS_FILE"

while true; do
  # --- Needs my review section ---
  week_ago=$(date -v-7d +%Y-%m-%dT%H:%M:%S 2>/dev/null || date -d '7 days ago' +%Y-%m-%dT%H:%M:%S)

  search_query() {
    gh api "search/issues?q=$1&per_page=30&sort=updated&order=desc" --jq '.items[] | {number, title, author: .user.login, updatedAt: .updated_at}' 2>/dev/null | jq -s '.'
  }

  # Run 4 search queries in parallel
  search_query "is:pr+is:open+repo:figma/figma+review-requested:figmajerry+draft:false" > /tmp/pr_search_1 &
  search_query "is:pr+is:open+repo:figma/figma+assignee:figmajerry+draft:false" > /tmp/pr_search_2 &
  search_query "is:pr+is:open+repo:figma/figma+team-review-requested:figma/expressive-ai+-author:figmajerry+draft:false" > /tmp/pr_search_3 &
  search_query "is:pr+is:open+repo:figma/figma+reviewed-by:figmajerry+-author:figmajerry+draft:false" > /tmp/pr_search_4 &
  wait

  review_prs_all=$(cat /tmp/pr_search_{1,2,3,4} | jq -s --arg since "$week_ago" '
    add | unique_by(.number) |
    [.[] | select(.updatedAt >= $since)] |
    sort_by(.updatedAt) | reverse')

  REVIEW_SEEN="$HOME/.claude/pr_review_seen"
  touch "$REVIEW_SEEN"

  now_epoch=$(date +%s)
  review_rows=""
  review_num=0
  > "$REVIEW_QUEUE"
  review_count=$(echo "$review_prs_all" | jq 'length')
  for ((idx=0; idx<review_count; idx++)); do
    rnum=$(echo "$review_prs_all" | jq -r ".[$idx].number")
    rtitle=$(echo "$review_prs_all" | jq -r ".[$idx].title")

    # Get PR details (head SHA, line stats, updated time)
    pr_data=$(gh api "repos/figma/figma/pulls/$rnum" --jq '{head_sha: .head.sha, additions, deletions, updated_at}' 2>/dev/null)
    head_sha=$(echo "$pr_data" | jq -r '.head_sha')
    additions=$(echo "$pr_data" | jq '.additions')
    deletions=$(echo "$pr_data" | jq '.deletions')
    updated_at=$(echo "$pr_data" | jq -r '.updated_at')
    changed=$((additions + deletions))

    # Skip if I've reviewed this exact SHA already
    seen_sha=$(grep "^$rnum|" "$REVIEW_SEEN" 2>/dev/null | cut -d'|' -f2)
    if [ "$head_sha" = "$seen_sha" ]; then
      continue
    fi

    # Auto-record SHA if I approved after the latest commit
    my_approval=$(gh api "repos/figma/figma/pulls/$rnum/reviews" --jq '[.[] | select(.user.login == "figmajerry" and .state == "APPROVED")] | last | .submitted_at // empty' 2>/dev/null)
    if [ -n "$my_approval" ]; then
      latest_commit_date=$(gh api "repos/figma/figma/pulls/$rnum/commits" --jq 'last | .commit.committer.date' 2>/dev/null)
      if [[ "$my_approval" > "$latest_commit_date" ]]; then
        grep -v "^$rnum|" "$REVIEW_SEEN" > "${REVIEW_SEEN}.tmp" 2>/dev/null || true
        echo "$rnum|$head_sha" >> "${REVIEW_SEEN}.tmp"
        mv "${REVIEW_SEEN}.tmp" "$REVIEW_SEEN"
        continue
      fi
    fi

    # Updated column: human-readable time ago
    upd_epoch=$(date -u -jf "%Y-%m-%dT%H:%M:%SZ" "$updated_at" +%s 2>/dev/null || date -u -d "$updated_at" +%s 2>/dev/null)
    diff_secs=$((now_epoch - upd_epoch))
    if [ "$diff_secs" -lt 3600 ]; then
      upd_str="$((diff_secs / 60))m ago"
    elif [ "$diff_secs" -lt 86400 ]; then
      upd_str="$((diff_secs / 3600))h ago"
    else
      upd_str="$((diff_secs / 86400))d ago"
    fi

    review_num=$((review_num + 1))
    echo "$review_num|$rnum|$rtitle|$head_sha|$changed" >> "$REVIEW_QUEUE"

    # Truncate title (leave room for number prefix)
    num_prefix="$review_num. "
    max_title=$((W1 - ${#num_prefix}))
    if [ ${#rtitle} -gt $max_title ]; then
      short_rtitle="${rtitle:0:$((max_title - 2))}.."
    else
      short_rtitle="$rtitle"
    fi

    review_rows+="$(printf "$ROW_FMT" "${num_prefix}${short_rtitle}" "${changed} lines" "$upd_str")\n"
  done

  review_section=""
  if [ -n "$review_rows" ]; then
    review_section="${TOP}\n$(printf "$ROW_FMT" 'Needs my review' 'Diff' 'Updated')\n${MID}\n${review_rows}${BOT}\n\n"
  fi

  # --- My PRs section ---
  prs=$(gh pr list --author @me --repo figma/figma --json number,title,reviewDecision,mergeStateStatus,labels,state,isDraft --limit 20 2>&1)
  prs=$(echo "$prs" | jq '[.[] | select(.isDraft == false)]')
  count=$(echo "$prs" | jq 'length')

  # Build table header
  output="${TOP}\n"
  output+="$(printf "$ROW_FMT" 'My PRs' 'CI' 'Review')\n"
  output+="${MID}\n"

  if [ "$count" = "0" ]; then
    output+="$(printf "$ROW_FMT" 'No open PRs' '' '')\n"
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

  # Pre-fetch all gh pr checks in parallel
  CHECKS_DIR="/tmp/pr_checks"
  mkdir -p "$CHECKS_DIR"
  pr_nums=($(echo "$prs" | jq -r '.[].number'))
  for pr_num in "${pr_nums[@]}"; do
    has_blocked=$(echo "$prs" | jq -r ".[] | select(.number == $pr_num) | [.labels[].name] | index(\"blocked\") // empty")
    if [ -z "$has_blocked" ]; then
      gh pr checks "$pr_num" --repo figma/figma > "$CHECKS_DIR/$pr_num" 2>/dev/null &
    fi
  done
  wait

  echo "$prs" | jq -r '.[].number' | while read pr_num; do
    title=$(echo "$prs" | jq -r ".[] | select(.number == $pr_num) | .title")
    review=$(echo "$prs" | jq -r ".[] | select(.number == $pr_num) | .reviewDecision")
    merge_state=$(echo "$prs" | jq -r ".[] | select(.number == $pr_num) | .mergeStateStatus")
    has_rtm=$(echo "$prs" | jq -r ".[] | select(.number == $pr_num) | [.labels[].name] | index(\"ready-to-merge\") // empty")
    has_blocked=$(echo "$prs" | jq -r ".[] | select(.number == $pr_num) | [.labels[].name] | index(\"blocked\") // empty")
    state=$(echo "$prs" | jq -r ".[] | select(.number == $pr_num) | .state")

    # CI status (checks pre-fetched in parallel)
    if [ -n "$has_blocked" ]; then
      ci="BLOCKED"
    else
      checks_output=$(cat "$CHECKS_DIR/$pr_num" 2>/dev/null)
      fails=$(echo "$checks_output" | grep -E "^\S+\tfail\t" | grep -v "notify-failure" | wc -l | tr -d ' ')
      pending=$(echo "$checks_output" | grep -E "pending|running" | wc -l | tr -d ' ')

      if [ "$fails" -gt 0 ]; then
        # Only report FAILED if also failed on previous poll (grace period for auto-retries)
        prev_ci=$(grep "^$pr_num|" "$STATE_FILE" 2>/dev/null | cut -d'|' -f2)
        if [ "$prev_ci" = "FAILED" ]; then
          ci="FAILED"
        else
          ci="failing ($fails)"
        fi
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
      *) rev="needs review" ;;
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
    if [ ${#title} -gt $W1 ]; then
      short_title="${title:0:$((W1 - 2))}.."
    else
      short_title="$title"
    fi

    # Truncate review
    if [ ${#rev} -gt $W3 ]; then
      short_rev="${rev:0:$((W3 - 2))}.."
    else
      short_rev="$rev"
    fi

    printf "$ROW_FMT" "$short_title" "$ci" "$short_rev"

    # State tracking for notifications
    line="$pr_num|$ci|$review|$merge_state"
    prev=$(grep "^$pr_num|" "$STATE_FILE" 2>/dev/null || true)

    if [ "$prev" != "$line" ]; then
      prev_ci=$(echo "$prev" | cut -d'|' -f2)
      prev_review=$(echo "$prev" | cut -d'|' -f3)

      if [ "$ci" = "FAILED" ] && [ "$prev_ci" != "FAILED" ]; then
        osascript -e "display alert \"CI failed\" message \"$title\"" >/dev/null 2>&1 &
        echo "$pr_num|$title|FAILED" >> /tmp/pr_monitor_trigger
      fi
      if [ "$ci" = "BLOCKED" ] && [ "$prev_ci" != "BLOCKED" ]; then
        osascript -e "display alert \"CI blocked\" message \"$title\"" >/dev/null 2>&1 &
        echo "$pr_num|$title|BLOCKED" >> /tmp/pr_monitor_trigger
      fi
      if [ "$ci" = "passed" ] && [ "$prev_ci" != "passed" ]; then
        osascript -e "display alert \"CI passed\" message \"$title\"" >/dev/null 2>&1 &
      fi
      if [ "$review" = "APPROVED" ] && [ "$prev_review" != "APPROVED" ]; then
        osascript -e "display alert \"Approved\" message \"$title\"" >/dev/null 2>&1 &
      fi
      if [ "$review" = "CHANGES_REQUESTED" ] && [ "$prev_review" != "CHANGES_REQUESTED" ]; then
        osascript -e "display alert \"Changes requested\" message \"$title\"" >/dev/null 2>&1 &
      fi
    fi

    # Auto-label ready-to-merge
    if [ "$ci" = "passed" ] && [ "$review" = "APPROVED" ] && [ -z "$has_rtm" ]; then
      gh api "repos/figma/figma/issues/$pr_num/labels" -f "labels[]=ready-to-merge" >/dev/null 2>&1
      osascript -e "display alert \"Added ready-to-merge\" message \"$title\"" >/dev/null 2>&1 &
    fi

    # Update state
    grep -v "^$pr_num|" "$STATE_FILE" > "${STATE_FILE}.tmp" 2>/dev/null || true
    echo "$line" >> "${STATE_FILE}.tmp"
    mv "${STATE_FILE}.tmp" "$STATE_FILE"
  done > /tmp/pr_table_rows.txt

  # --- Auto-rebase conflicts and restack children ---
  RESTACK_STATE="/tmp/pr_restack_state"
  touch "$RESTACK_STATE"

  # Find an available worktree slot
  find_slot() {
    for slot in ~/figma/slot{1,2,3}; do
      if ! git -C "$slot" symbolic-ref HEAD 2>/dev/null >/dev/null; then
        echo "$slot"
        return 0
      fi
    done
    return 1
  }

  echo "$prs" | jq -r '.[].number' | while read pr_num; do
    merge_state=$(echo "$prs" | jq -r ".[] | select(.number == $pr_num) | .mergeStateStatus")
    title=$(echo "$prs" | jq -r ".[] | select(.number == $pr_num) | .title")

    # Auto-rebase conflicts
    if [ "$merge_state" = "DIRTY" ]; then
      already_rebased=$(grep "^rebase|$pr_num$" "$RESTACK_STATE" 2>/dev/null)
      if [ -z "$already_rebased" ]; then
        slot=$(find_slot)
        if [ -n "$slot" ]; then
          branch=$(gh api "repos/figma/figma/pulls/$pr_num" --jq '.head.ref' 2>/dev/null)
          if [ -n "$branch" ]; then
            (cd "$slot" && gt checkout "$branch" && gt restack && gt submit --stack --no-interactive && git checkout --detach) >/dev/null 2>&1
            echo "rebase|$pr_num" >> "$RESTACK_STATE"
          fi
        fi
      fi
    else
      # Clear rebase state when conflict is resolved
      grep -v "^rebase|$pr_num$" "$RESTACK_STATE" > "${RESTACK_STATE}.tmp" 2>/dev/null || true
      mv "${RESTACK_STATE}.tmp" "$RESTACK_STATE"
    fi
  done

  # Auto-restack: check if any PR's parent branch got new commits
  echo "$prs" | jq -r '.[].number' | while read pr_num; do
    branch=$(gh api "repos/figma/figma/pulls/$pr_num" --jq '.head.ref' 2>/dev/null)
    base_branch=$(gh api "repos/figma/figma/pulls/$pr_num" --jq '.base.ref' 2>/dev/null)

    # Skip if base is master (nothing to restack onto)
    if [ "$base_branch" = "master" ]; then
      continue
    fi

    # Get parent's current head SHA
    parent_sha=$(gh api "repos/figma/figma/git/ref/heads/$base_branch" --jq '.object.sha' 2>/dev/null)
    prev_parent_sha=$(grep "^parent|$pr_num|" "$RESTACK_STATE" 2>/dev/null | cut -d'|' -f3)

    if [ -n "$parent_sha" ] && [ "$parent_sha" != "$prev_parent_sha" ] && [ -n "$prev_parent_sha" ]; then
      # Parent changed — restack
      slot=$(find_slot)
      if [ -n "$slot" ]; then
        (cd "$slot" && gt checkout "$branch" && gt restack && gt submit --stack --no-interactive && git checkout --detach) >/dev/null 2>&1
      fi
    fi

    # Record current parent SHA
    grep -v "^parent|$pr_num|" "$RESTACK_STATE" > "${RESTACK_STATE}.tmp" 2>/dev/null || true
    echo "parent|$pr_num|$parent_sha" >> "${RESTACK_STATE}.tmp"
    mv "${RESTACK_STATE}.tmp" "$RESTACK_STATE"
  done

  # Merged PRs this week
  week_start=$(date -v-monday -v0H -v0M -v0S +%Y-%m-%dT%H:%M:%S 2>/dev/null || date -d 'last monday' +%Y-%m-%dT%H:%M:%S)
  merged=$(gh pr list --author @me --repo figma/figma --state merged --json number,title,mergedAt --limit 50 2>/dev/null | \
    jq -r --arg since "$week_start" '[.[] | select(.mergedAt >= $since)] | sort_by(.mergedAt) | reverse | .[] | "\(.mergedAt)\t\(.title)"' 2>/dev/null)
  merged_section=""
  if [ -n "$merged" ]; then
    merged_section="\n\n Merged this week:\n"
    while IFS=$'\t' read -r mdate mtitle; do
      day=$(date -jf "%Y-%m-%dT%H:%M:%SZ" "$mdate" "+%a" 2>/dev/null || date -d "$mdate" "+%a" 2>/dev/null)
      merged_section+="  ✓ ($day) $mtitle\n"
    done <<< "$merged"
  fi

  # Write table (without countdown — that gets appended by the countdown loop)
  TABLE="${review_section}$output$(cat /tmp/pr_table_rows.txt)\n${BOT}${merged_section}"

  # Countdown loop
  for ((i=60; i>=0; i--)); do
    mins=$((i / 60))
    secs=$((i % 60))
    echo -e "$TABLE\nNext check in ${mins}m $(printf '%02d' $secs)s" > "${STATUS_FILE}.tmp" && mv "${STATUS_FILE}.tmp" "$STATUS_FILE"
    sleep 1
  done

  # Show updating status while polling
  echo -e "$TABLE\nUpdating..." > "${STATUS_FILE}.tmp" && mv "${STATUS_FILE}.tmp" "$STATUS_FILE"
done
