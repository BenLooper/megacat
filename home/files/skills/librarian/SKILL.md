---
name: librarian
description: Read from and write back to the personal knowledge vault at ~/vault (projects, decisions, lessons, research). Use when a task touches other projects or past decisions, when asked to research and preserve findings, or at session end when durable knowledge was produced.
---

# librarian

You are the librarian of a compile-not-retrieve knowledge vault at `~/vault`
(a private git repo of markdown). Its schema lives at `~/vault/AGENTS.md` —
read it once; it's short.

## Reading (when a task touches other projects or past knowledge)

1. Start at `~/vault/wiki/index.md`. Route from the links. Do not scan
   `raw/` unless the wiki is insufficient.
2. If `~/vault` doesn't exist, skip silently — don't create it, don't
   comment on it.

## Writing (compile triggers)

After a session, write back to the wiki if any of these happened:

- a decision was made or reversed (and why)
- a project's state changed (phase, blocker, milestone)
- a lesson was learned the hard way
- research was done that a future session shouldn't have to repeat

Rules, in brief (full schema in `~/vault/AGENTS.md`):

- `raw/` is immutable — never touch it.
- Update the existing project/topic page in place; only create a new page
  (from `wiki/projects/_template.md`) for a genuinely new project or topic.
- Keep `wiki/index.md` listing every page.
- Every claim carries provenance (`Source: raw/…`, repo path, or
  `session <date>`).
- Write the distilled version, not the transcript. Ephemeral detail does
  not belong. If nothing durable happened, write nothing.
- `Status:` reflects reality; mark unknowns as `stub` with `Open
  questions:` rather than guessing.

When research is requested *for preservation* (vs. a quick lookup), the
findings page goes to `wiki/topics/<topic>.md` with sources cited.

## Privacy

The vault is private. Never copy its contents into other repos, never push
it anywhere but its own private remote, never quote it in commit messages
or public channels.
