---
name: review-pr
description: "Review a PR from the monitor's review queue by number."
argument-hint: "<number>"
---

# Review PR

Review a PR from the "Needs my review" queue in the PR monitor dashboard.

## Usage

The user says `Review N` where N is the number shown in the dashboard's "Needs my review" table.

## Steps

1. Look up the PR from `/tmp/pr_review_queue`. Each line is `num|pr_number|title|head_sha|changed_lines`.
2. Fetch the PR details: `gh api repos/figma/figma/pulls/{number}`
3. Summarize the PR in 1-2 sentences based on the title and body.
4. Fetch the diff: `gh api repos/figma/figma/pulls/{number} -H "Accept: application/vnd.github.v3.diff"`
5. If the diff is **< 50 lines changed**, render it inline in the terminal.
6. If the diff is **>= 50 lines changed**, open the PR in GitHub's web editor: `open "https://github.dev/figma/figma/pull/{number}"`
7. Provide 3-4 bullets of things to look for when reviewing.
8. Record the head SHA as reviewed in `~/.claude/pr_review_seen`:
   ```bash
   grep -v "^{number}|" ~/.claude/pr_review_seen > ~/.claude/pr_review_seen.tmp 2>/dev/null || true
   echo "{number}|{head_sha}" >> ~/.claude/pr_review_seen.tmp
   mv ~/.claude/pr_review_seen.tmp ~/.claude/pr_review_seen
   ```
   This removes the PR from the dashboard. If the author pushes new commits, it reappears.
