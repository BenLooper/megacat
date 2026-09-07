# AGENTS.md — vault schema

This repo is a personal knowledge vault. You (the agent) are its librarian.

Two jobs, in order of frequency:

1. **READ** — when a task touches another project, a past decision, or
   "what do we know about X": start at `wiki/index.md` and route yourself
   from there. Do not scan `raw/` unless the wiki is insufficient — the
   wiki is the distillation; raw is the archive.
2. **WRITE** — when a session produces durable knowledge, compile it back
   into the wiki (see rules below). Ephemeral session detail does NOT get
   written; only what a future session — yours or another agent's — would
   want to know.

## Hard rules

- `raw/` is **immutable**. Never modify, rename, or delete anything in it.
- `wiki/` is agent-maintained. Update pages in place, keep them current.
  Stale information is worse than missing information — if you know a page
  is out of date, fix it or flag it (`> [STALE]` note at the top).
- One page per project in `wiki/projects/`, one per topic in
  `wiki/topics/`. Link liberally with relative markdown links. Keep
  `wiki/index.md` listing every page (it is the only entry point).
- **Provenance**: every compiled claim carries a source —
  `Source: raw/2026-09-04-....md`, a repo path, or `session <date>`.
  Unsourced assertions don't belong in the wiki.
- New project pages start from `wiki/projects/_template.md`.
- **Privacy**: this vault is private. Never copy its contents into other
  repositories, never push it anywhere but its own private remote, never
  quote it into commit messages or public channels.

## Private twins (`*.private.md`)

Any page or raw doc may have a **private twin**: the same name plus
`.private.md` (`job-search.md` / `job-search.private.md`). Twins are
machine-local: gitignored, never committed, never pushed, never quoted
into pushed pages.

- Before writing to a project/topic page, check for its twin. Sensitive
  facts — career, employer opinions, network topology, anything the
  owner would wince at a stranger reading — go to the TWIN, not the
  public page.
- A public page must stand alone as safe: status and public-safe
  decisions only. It may note "twin exists (not synced)".
- `wiki/index.md` lists public pages only.
- A twin referenced but missing on this machine is expected — clones
  carry only public pages — not an error. Never "helpfully" recreate a
  missing twin's content on another machine.

## Page conventions

- Title, one-line status, `Updated: <date>` at the top.
- `Status:` is one of: `active`, `paused`, `done`, `stub` (a stub means
  "this page exists to be filled in — the facts below are incomplete").
- For stubs, list what's missing under `Open questions:` — the owner or a
  future session fills them in.

## When to compile (write triggers)

After a session, write back if any of these happened:

- a decision was made or reversed (and why)
- a project's state changed (phase, blocker, milestone)
- a lesson was learned the hard way (a fix, a gotcha, a "never again")
- research was done that a future session shouldn't have to repeat

Write the *distilled* version into the project/topic page, not the
transcript. If nothing durable happened, write nothing.
