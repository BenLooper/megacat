# home/vault.nix
# ============================================================
# THE VAULT — personal knowledge base for coding agents
#
# The vault is a compile-not-retrieve wiki (Karpathy, Apr 2026) living
# at ~/vault: a PRIVATE git repo of markdown that every coding agent
# reads from and writes back to. It exists to kill the three Claude
# Projects gripes:
#
#   1. Agents can't mutate documents   → on the filesystem they can
#   2. Cross-project context sync      → one repo, read at query time
#   3. Project → work context friction → the local agent IS in the
#                                         project (the project is
#                                         just a directory)
#
# WHAT THIS MODULE DEPLOYS (personal profile only — see below):
#   OpenCode    ~/.config/opencode/AGENTS.md        global instructions
#              ~/.config/opencode/skills/librarian/ the skill
#   Claude Code ~/.claude/CLAUDE.md                 global memory
#              ~/.claude/skills/librarian/          the skill
#
# The vault ITSELF is not deployed from here — it's instantiated from
# vault-template/ by scripts/bootstrap.sh (or cloned from its private
# remote) and then maintained by agents. The template lives in this
# repo because the system is dotfiles (public); the content is not.
#
# PERSONAL PROFILE ONLY: the vault contains career notes and project
# state that must never land on employer hardware. The dojo skill (the
# coach-mode counterpart, which contains nothing personal) is deployed
# to all profiles by home/agent-skills.nix instead.
# ============================================================
{ ... }:
let
  # One source of truth for the pointer text; both agents' global
  # instruction files are byte-identical copies of it.
  vaultPointer = builtins.readFile ./files/vault-pointer.md;
in
{

  # ── OpenCode ───────────────────────────────────────────────
  xdg.configFile."opencode/AGENTS.md".text = vaultPointer;
  xdg.configFile."opencode/skills/librarian/SKILL.md".source =
    ./files/skills/librarian/SKILL.md;

  # ── Claude Code ────────────────────────────────────────────
  home.file.".claude/CLAUDE.md".text = vaultPointer;
  home.file.".claude/skills/librarian/SKILL.md".source =
    ./files/skills/librarian/SKILL.md;
}
