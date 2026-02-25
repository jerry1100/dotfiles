# Coding style guide for AI agents

## 1. Use early returns over nested if statements

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

## 2. Always use curly braces for if statements

```ts
// Bad
if (condition) doSomething();

// Good
if (condition) {
  doSomething();
}
```

## 3. Inline short objects

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

## 4. Don't export functions unnecessarily

Only add `export` when the function is actually used outside the file.

```ts
// Bad — exported but only used locally
export function helperFn() { ... }

// Good
function helperFn() { ... }
```

## 5. SNAKE_CASE for consts and magic numbers

Place them near the top of the file, below imports.

```ts
import { something } from './module';

const MAX_RETRIES = 3;
const DEFAULT_TIMEOUT_MS = 5000;

function fetchData() {
  // use MAX_RETRIES, DEFAULT_TIMEOUT_MS here
}
```

## 6. Extract component props into a named type

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
