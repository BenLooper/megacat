# Drive Mode — Plan

## What It Is

A pi extension that replaces the chat interaction model entirely. Instead of typing
and reading prose, you navigate a list of 10 options with keyboard shortcuts. The
agent never outputs text — it always responds by calling a structured tool that
updates the option list. You are always choosing what happens next.

---

## Core Design Decisions

### 1. Use a `present_options` tool, not prose parsing

The agent is forced to call `present_options({ options: string[] })` after every
action. This is reliable — no parsing, no prompt-hacking. The tool call IS the UI
update. The system prompt enforces this constraint.

### 2. Full UI takeover via `ctx.ui.custom()`

The entire terminal becomes the drive UI. No chat scroll, no editor, no footer.
Just the list and the keyboard. This replaces pi's interactive mode visually while
keeping all the agent machinery running underneath.

### 3. The agent still has all its tools

Read, write, edit, bash — all still available. The only thing that changes is how
the agent communicates back to the user: always via `present_options`.

---

## Keyboard Map

| Key    | Action                                          |
|--------|-------------------------------------------------|
| j / ↓  | Move cursor down                                |
| k / ↑  | Move cursor up                                  |
| enter  | Select option → send to agent as next prompt    |
| t      | Open text input (type anything freely)          |
| r      | Reroll hovered option (similar but different)   |
| R      | Reroll all 10 options                           |
| esc    | Cancel text input / back to list                |

---

## UI States

```
loading      → spinner + "thinking..." (agent is working)
selecting    → the 10-option list with cursor
typing       → text input field (t was pressed)
```

Transitions:
- `selecting` → enter/t/r/R → `loading` → `selecting`
- `selecting` → t → `typing` → enter → `loading`
- `typing` → esc → `selecting`

---

## File Structure

```
home/pi/agent/extensions/drive/
├── PLAN.md          ← this file
├── index.ts         ← extension entry point
└── ui.ts            ← DriveComponent (the full-screen UI)
```

Lives in the dotfiles repo, symlinked into `~/.pi/agent/extensions/drive/` via the
existing `~/.pi/agent → ~/dotfiles/home/pi/agent` symlink. No nix changes needed.

---

## System Prompt (injected via `before_agent_start`)

```
You are running in drive mode. You NEVER respond with prose.

After every completed action — and at the very start of the session — you MUST
call the present_options tool with exactly 10 options. Each option should be a
short, specific, immediately actionable thing the user could do next given the
current context. No vague options like "explore the codebase". Be concrete.

If the user selects an option, execute it fully, then call present_options again.
If the user types something free-form, treat it as a direct instruction, execute
it, then call present_options again.
```

---

## `present_options` Tool

```typescript
pi.registerTool({
  name: "present_options",
  description: "Present the user with 10 options for what to do next. Call this after every completed action.",
  parameters: Type.Object({
    options: Type.Array(Type.String(), { minItems: 10, maxItems: 10 }),
  }),
  async execute(_id, params, _signal, _onUpdate, _ctx) {
    setOptions(params.options);   // updates UI state
    requestRender();
    // block until user makes a selection (returned via a promise that resolves on selection)
    const selection = await waitForSelection();
    return {
      content: [{ type: "text", text: selection }],
      details: {},
    };
  },
});
```

The key insight: `execute` blocks until the user picks. The agent calls
`present_options`, pi shows the list, the user picks, `execute` returns the
selection as the tool result, and the agent continues from there. The whole
loop is driven by this one blocking tool call.

---

## Initial Options

On `session_start`, gather context via bash:
```bash
pwd
git -C . rev-parse --abbrev-ref HEAD 2>/dev/null
git -C . status --short 2>/dev/null | head -10
ls -1 2>/dev/null | head -20
```

Inject this into the first system prompt turn so the agent's initial 10 options
are grounded in the actual state of the machine, not generic suggestions.

The `before_agent_start` handler fires before the agent loop starts. We use it to:
1. Append the drive mode system prompt
2. Inject the gathered context as additional system context

---

## Reroll Mechanics

**Reroll one (r):** Send a steering message — "Replace option [N] ('[text]') with
something different but similar in scope" — then wait for a new `present_options`
call. The agent updates just that slot conceptually but will return a full new list
(which is fine — we just replace all 10).

**Reroll all (R):** Send "Reroll all options — give me 10 completely different
suggestions." Same flow.

Both transitions go through `loading` state while the agent works.

---

## Build Phases

### Phase 1 — Skeleton (get the loop working)
- [ ] `index.ts` with `present_options` tool registered
- [ ] System prompt injection via `before_agent_start`
- [ ] `ui.ts` with basic list render + cursor (j/k/enter)
- [ ] Loading spinner state
- [ ] Session start context gathering
- [ ] Verify the blocking tool / selection promise pattern works

### Phase 2 — Full controls
- [ ] `t` → text input mode → sends typed text to agent
- [ ] `r` → reroll hovered option
- [ ] `R` → reroll all
- [ ] `esc` to cancel typing

### Phase 3 — Polish
- [ ] Theming (use pi theme colors throughout)
- [ ] Better context gathering (recent git commits, open PRs, etc.)
- [ ] Option to launch as `pi -e ~/dotfiles/home/pi/agent/extensions/drive`
- [ ] Shell alias `drive` in shell.nix

---

## Open Questions

- **Does the blocking tool pattern work cleanly?** The `execute` function needs to
  return a Promise that resolves when the user selects. This should work since
  tool execute functions are async, but needs verification with a minimal spike
  before building the full UI.

- **What happens if the user quits mid-selection?** Need to handle `session_shutdown`
  to resolve the pending promise cleanly.

- **Should tool output be visible at all?** In drive mode you don't want to see
  bash output scrolling — the agent does work silently and then presents options.
  Could suppress tool rendering entirely via `renderCall`/`renderResult` returning
  empty components, or show a minimal "working..." indicator.
