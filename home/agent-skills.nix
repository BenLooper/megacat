# home/agent-skills.nix
# ============================================================
# AGENT SKILLS — the shared, non-personal set
#
# Skills follow the Agent Skills format (SKILL.md + frontmatter),
# which both OpenCode (~/.config/opencode/skills/) and Claude Code
# (~/.claude/skills/) load. Deployed to ALL profiles: nothing here
# may reference personal data or the vault (the vault-wired skill
# set lives in home/vault.nix, personal profile only).
#
#   dojo  coach mode: keyboard split + explain-back gate, so agent
#         velocity doesn't cost the human their own skill. Based on
#         the interaction patterns that preserved mastery in the
#         Anthropic RCT (Jan 2026).
#
# Adding a skill: drop home/files/skills/<name>/SKILL.md and register
# it in BOTH blocks below.
# ============================================================
{ ... }:
{

  # ── OpenCode ───────────────────────────────────────────────
  xdg.configFile."opencode/skills/dojo/SKILL.md".source =
    ./files/skills/dojo/SKILL.md;

  # ── Claude Code ────────────────────────────────────────────
  home.file.".claude/skills/dojo/SKILL.md".source =
    ./files/skills/dojo/SKILL.md;
}
