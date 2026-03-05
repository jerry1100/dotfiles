# Coding guide for AI agents

## Coding workflow

Follow these steps when implementing a feature or fix:

### 1. Branch setup

Ask the user:
- What is the feature/fix for?
- What trunk branch to base off of — `master` or a previous branch in a stack?

Then create a new branch with an appropriate name using `gt create` (graphite-cli). Branch names should be 3 words max, joined with hyphens (e.g., `weave-input-validation`).

When basing off a non-master trunk branch, first check it out with `gt checkout <branch>`, then use `gt create` to stack on top of it. Never fall back to raw `git branch` or `git checkout -b` — always use Graphite for branch management.

### 2. Plan

Gather context by reading relevant files and understanding the codebase. Ask clarifying questions if anything is ambiguous. Devise a plan and share it before writing code.

### 3. Implement

Write the code following the style guide below. Keep changes focused and minimal.

**CRITICAL: NEVER run `rm -rf` on the project root or any parent directory.** Only delete specific files or subdirectories you created. If you need to clean up, delete individual files by name — never use broad `rm -rf` on directories like `~/figma/figma`, `.`, or `..`.

### 4. Submit PR

**Do not** submit the PR until the user explicitly asks. Wait for the user to say "submit", "send it", "create the PR", etc.

When ready, **always** use the `/submit-pr` skill to push the branch and create a PR. Never manually run `gt submit`, `gh pr edit`, or `gh api` — the skill handles all steps (push, title, description, mark ready, reviewers, detach HEAD).

## Style guide

**These rules are mandatory. Follow them exactly in all code you write or modify.**

### 1. ALWAYS use early returns over nested if statements

```ts
// Bad
function process(item: Item) {
  if (item.isValid) {
    if (item.hasData) {
      doWork(item);
    }
  }
}

// Good
function process(item: Item) {
  if (!item.isValid) {
    return;
  }

  if (!item.hasData) {
    return;
  }

  doWork(item);
}
```

### 2. ALWAYS use curly braces for if statements

```ts
// Bad
if (condition) doSomething();

// Good
if (condition) {
  doSomething();
}
```

### 3. ALWAYS inline short objects

```ts
// Bad
doWork({
  id: 1,
  name: 'foo',
});

// Good
doWork({ id: 1, name: 'foo' });
```

Split across lines only when the object is complex or has many fields.

### 4. NEVER export functions unnecessarily

Only add `export` when the function is actually used outside the file.

```ts
// Bad — exported but only used locally
export function helperFn() { ... }

// Good
function helperFn() { ... }
```

### 5. ALWAYS use SNAKE_CASE for consts and magic numbers

Place them near the top of the file, below imports.

```ts
import { something } from './module';

const MAX_RETRIES = 3;
const DEFAULT_TIMEOUT_MS = 5000;

function fetchData() {
  // use MAX_RETRIES, DEFAULT_TIMEOUT_MS here
}
```

### 6. ALWAYS group related statements with a comment header

When a function has distinct logical sections (e.g., configuring a node, then adding children), separate them with a blank line and a short comment describing the group.

```ts
// Bad — wall of undifferentiated assignments
const frame = createFrame()
frame.width = 200
frame.height = 100
frame.layoutMode = 'VERTICAL'
frame.primaryAxisAlignItems = 'CENTER'
const text = createText()
text.fontSize = 14
text.characters = 'Hello'
frame.appendChild(text)

// Good — grouped by concern with comment headers
const frame = createFrame()
frame.width = 200
frame.height = 100

// Center children with autolayout
frame.layoutMode = 'VERTICAL'
frame.primaryAxisAlignItems = 'CENTER'

// Add label
const text = createText()
text.fontSize = 14
text.characters = 'Hello'
frame.appendChild(text)
```

### 7. NEVER use non-null assertions

Use proper null checks or early returns instead of `!` postfix assertions.

```ts
// Bad
const name = user!.name
const el = document.getElementById('root')!

// Good
if (!user) {
  return;
}
const name = user.name
```

### 8. ALWAYS add a brief comment above useEffect explaining its purpose

```ts
// Bad
useEffect(() => {
  fetchData()
}, [id])

// Good
// Refetch data when the selected item changes
useEffect(() => {
  fetchData()
}, [id])
```

### 9. ALWAYS order functions top-down like a newspaper

High-level functions go first, helpers go below. A caller should appear above the callee so the file reads top-down from intent to implementation.

```ts
// Bad — have to scroll past helpers to find the main logic
function formatName(user: User) {
  return `${user.first} ${user.last}`
}

function validateUser(user: User) {
  return user.email.includes('@')
}

function processUser(user: User) {
  if (!validateUser(user)) {
    return
  }
  return formatName(user)
}

// Good — main function first, helpers below
function processUser(user: User) {
  if (!validateUser(user)) {
    return
  }
  return formatName(user)
}

function validateUser(user: User) {
  return user.email.includes('@')
}

function formatName(user: User) {
  return `${user.first} ${user.last}`
}
```

### 10. ALWAYS extract component props into a named type

Name the type `{Component}Props` and place it directly above the component definition.

```tsx
// Bad
export function UserCard({ name, avatar }: { name: string; avatar: string }) {
  ...
}

// Good
type UserCardProps = {
  name: string
  avatar: string
}

export function UserCard({ name, avatar }: UserCardProps) {
  ...
}
```

### 11. ALWAYS prefer `const` over `let`

Only use `let` when reassignment is actually needed.

```ts
// Bad
let name = user.first + ' ' + user.last
let items = getItems()

// Good
const name = user.first + ' ' + user.last
const items = getItems()
```
