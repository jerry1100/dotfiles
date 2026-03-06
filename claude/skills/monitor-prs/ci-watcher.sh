#!/bin/bash
# CI Watcher — blocks until pr-monitor.sh signals new FAILED or BLOCKED PRs
# Waits for triggers, batches them over 15s, then outputs all new lines and exits
# Used as a background task by the monitor-prs skill

TRIGGER_FILE="/tmp/pr_monitor_trigger"
PIDFILE="/tmp/ci_watcher.pid"

# Kill previous watcher instance
if [ -f "$PIDFILE" ]; then
  kill "$(cat "$PIDFILE")" 2>/dev/null
fi
echo $$ > "$PIDFILE"

LAST_COUNT=$(wc -l < "$TRIGGER_FILE" 2>/dev/null || echo 0)

while true; do
  sleep 5
  CURR_COUNT=$(wc -l < "$TRIGGER_FILE" 2>/dev/null || echo 0)
  if [ "$CURR_COUNT" -gt "$LAST_COUNT" ]; then
    # Wait 15s to batch multiple failures from the same poll cycle
    sleep 15
    FINAL_COUNT=$(wc -l < "$TRIGGER_FILE" 2>/dev/null || echo 0)
    NEW_LINES=$((FINAL_COUNT - LAST_COUNT))
    tail -"$NEW_LINES" "$TRIGGER_FILE"
    exit 0
  fi
done
