# vault-template

Source template for the **personal knowledge vault** (`~/vault`) — a private,
git-tracked markdown repo that every coding agent reads from and writes back to.

This template lives in megacat because the *system* is dotfiles (public); the
*content* is personal (private repo). `scripts/bootstrap.sh` instantiates
`~/vault` from this directory on a fresh machine — or clones it from the
private remote if one has been set up.

**The vault repo itself must only ever be pushed to a PRIVATE remote.** It
contains career notes, project state, and personal writing. Never push it to
megacat, never copy its contents into other repos.

## Layout

```
AGENTS.md          schema: how agents use this vault (read it, it's short)
README.md          this file — human-facing orientation
wiki/
  index.md         the hub — every session starts here
  projects/        one page per project (megacat, homelab, job-search, …)
  topics/          cross-project knowledge (patterns, research, decisions)
  projects/_template.md   stub for new project pages
raw/               immutable inbox: source documents land here and are
                   never edited again, by anyone
```

## The pattern (why it's shaped like this)

"Compile, not retrieve" — [Karpathy, April 2026](
https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f).
Instead of an ever-growing pile of documents agents *hope* to make sense of
at query time, agents **compile** durable knowledge into a small, curated,
cross-linked wiki and keep it current. `raw/` preserves the sources
verbatim; `wiki/` is the distillation. The wiki is small enough for an agent
to read the index and route itself; humans read it like any wiki.
