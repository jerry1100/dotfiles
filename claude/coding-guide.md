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

### 4. Submit PR

Use the `/submit-pr` skill to push the branch and create a PR.

## Style guide

### 1. Use early returns over nested if statements

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

### 2. Always use curly braces for if statements

```ts
// Bad
if (condition) doSomething();

// Good
if (condition) {
  doSomething();
}
```

### 3. Inline short objects

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

### 4. Don't export functions unnecessarily

Only add `export` when the function is actually used outside the file.

```ts
// Bad — exported but only used locally
export function helperFn() { ... }

// Good
function helperFn() { ... }
```

### 5. SNAKE_CASE for consts and magic numbers

Place them near the top of the file, below imports.

```ts
import { something } from './module';

const MAX_RETRIES = 3;
const DEFAULT_TIMEOUT_MS = 5000;

function fetchData() {
  // use MAX_RETRIES, DEFAULT_TIMEOUT_MS here
}
```

### 6. Extract component props into a named type

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
