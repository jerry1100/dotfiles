#!/bin/bash
# CI Watcher — watches /tmp/pr_status.txt for new FAILED or BLOCKED PRs
# Exits when a new failure is detected (skips already-handled ones)
# Used as a background task by the monitor-prs skill

HANDLED_FILE="/tmp/pr_monitor_handled"
touch "$HANDLED_FILE"

while true; do
  new=$(grep -E "FAILED|BLOCKED" /tmp/pr_status.txt 2>/dev/null | grep "^│" | grep -vFf "$HANDLED_FILE" 2>/dev/null || true)
  if [ -n "$new" ]; then
    echo "$new"
    exit 0
  fi
  sleep 30
done
