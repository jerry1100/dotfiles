# Creating Skills

## When to create a skill

- **Procedural workflows** invoked on demand (e.g., "monitor my PRs", "submit this PR")
- If the instructions are only needed sometimes, they belong in a skill — not in CLAUDE.md

Rules and conventions that should always be in context belong in CLAUDE.md, not a skill.

## File structure

Skills live in `~/me/dotfiles/claude/skills/`. Each skill is a directory with a `SKILL.md` file:

```
~/me/dotfiles/claude/skills/
├── submit-pr/
│   └── SKILL.md
├── monitor-prs/
│   └── SKILL.md
└── new-skill/
    └── SKILL.md        # required, must be uppercase
```

The directory name becomes the invocation name (`/new-skill`).

## SKILL.md format

```markdown
---
name: skill-name
description: "Short description shown in /help."
argument-hint: "[optional args hint]"
---

# Skill Title

Instructions go here.
```

- `name` must match the directory name
- `description` is a single sentence
- `argument-hint` is optional — include it if the skill accepts arguments

## Making skills available

Personal skills are symlinked into `~/.claude/skills/` so Claude Code discovers them across all projects:

```bash
# Create the skill
mkdir -p ~/me/dotfiles/claude/skills/my-skill
# ... write SKILL.md ...

# Symlink into Claude Code's personal skills directory
ln -s ~/me/dotfiles/claude/skills/my-skill ~/.claude/skills/my-skill
```

Do **not** symlink into a project's `.claude/skills/` — that puts personal skills in the repo's git tree. Use `~/.claude/skills/` for personal skills.

## Checklist

1. Create `~/me/dotfiles/claude/skills/<name>/SKILL.md`
2. Symlink to `~/.claude/skills/<name>`
3. If the skill was previously an `@` reference in `~/.claude/CLAUDE.md`, remove that reference
4. Verify the skill appears in `/help`
