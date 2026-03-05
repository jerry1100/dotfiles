---
name: build-weave-app
description: "Build and configure Weave apps on app.weavy.ai using Playwright browser automation."
argument-hint: "[app description]"
---

# Build Weave App

Build Weave apps on app.weavy.ai using the Playwright MCP server. Requires the Playwright MCP tools to be available.

## Workflow

1. **Create file**: Navigate to `https://app.weavy.ai`, click "Create New File", skip tutorial, double-click title to rename
2. **Add nodes**: Right-click empty canvas → search in context menu → click to place
3. **Connect nodes**: Drag between React Flow handles (see connection technique below)
4. **Add Output node**: Toolbox sidebar → Helpers → drag Output to canvas → connect model result to it
5. **Configure App view**: Toggle to App, add brief input descriptions (noun phrases, not questions), set default values
6. **Set cover**: Canvas view → right-click generated image → "Set as cover"
7. **Share**: Share button → change to "Anyone with a link can view"
8. **Publish**: Click Publish in the "Ready to release?" banner

## Common nodes

- **Prompt**: Text input node (right-click → "Prompt")
- **Nano Banana**: Image generation/editing model (right-click → search "nano banana")
- **Output**: App output endpoint (Toolbox sidebar → Helpers → Output)

## Connecting nodes (critical technique)

Weavy uses React Flow. Nodes often spawn close together with overlapping handles. ALWAYS follow this process:

### Step 1: Get handle positions
```js
await page.evaluate(() => {
  const handles = document.querySelectorAll('.react-flow__handle');
  return Array.from(handles).map(h => {
    const rect = h.getBoundingClientRect();
    return {
      id: h.getAttribute('data-handleid'),
      type: h.classList.contains('source') ? 'source' : 'target',
      x: Math.round(rect.x + rect.width/2),
      y: Math.round(rect.y + rect.height/2),
      width: Math.round(rect.width),
      height: Math.round(rect.height)
    };
  });
});
```

Handle IDs: `{nodeId}-output-{name}` (source), `{nodeId}-input-{name}` (target).

### Step 2: Zoom in if handles are small
If handle width < 30px, zoom in with Ctrl+wheel:
```js
await page.mouse.move(handleX, handleY);
await page.keyboard.down('Control');
for (let i = 0; i < 15; i++) {
  await page.mouse.wheel(0, -200);
  await page.waitForTimeout(100);
}
await page.keyboard.up('Control');
```
Then re-query handle positions.

### Step 3: Multi-step drag
```js
const sx = sourceHandle.x, sy = sourceHandle.y;
const tx = targetHandle.x, ty = targetHandle.y;
await page.mouse.move(sx, sy);
await page.waitForTimeout(200);
await page.mouse.down();
await page.waitForTimeout(100);
for (let i = 1; i <= 20; i++) {
  await page.mouse.move(sx + (tx-sx)*(i/20), sy + (ty-sy)*(i/20));
  await page.waitForTimeout(30);
}
await page.waitForTimeout(200);
await page.mouse.up();
```

### Step 4: Verify and zoom back
```js
const edgeCount = await page.evaluate(() =>
  document.querySelectorAll('.react-flow__edge').length
);
```
Then use "Zoom to fit" from the zoom % dropdown.

## Dragging sidebar items to canvas

To drag nodes from the Toolbox sidebar:
1. Find the element's center coordinates via `getBoundingClientRect()`
2. Use the same multi-step drag technique from sidebar position to canvas position

## Gotchas

- **Intercepted clicks**: React Flow panels block clicks — use `{ force: true }` on Playwright locators
- **Snapshot often empty**: Wait 2-3s after navigation/state changes before snapshotting
- **Synthetic DOM events don't work** for node connections — must use Playwright's real mouse
- **Right-click**: Use `page.mouse.click(x, y, { button: 'right' })` on empty canvas area (not on nodes)
- **Multiple textareas**: Canvas nodes and App view have separate text fields. Update the correct one for the active view.
- **No keyboard shortcuts** exist for connecting React Flow nodes
