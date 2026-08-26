# home/agents-notify.nix
# ============================================================
# AGENT NOTIFICATIONS IN TMUX
#
# "Is the agent done? Is it stuck waiting for me?" — you shouldn't
# have to poll panes to find out. This module wires all three coding
# CLIs (Claude Code, OpenCode, GitHub Copilot CLI) into tmux so that
# every agent event shows up as:
#
#   - a bell on the agent's pane  -> window gets flagged (!) and your
#     terminal beeps / flashes its taskbar entry
#   - a transient status-line message ("✓ opencode finished — dotfiles")
#
# ...unless you are already looking at that exact pane, in which case
# it stays quiet. All the actual behaviour lives in one small script,
# home/files/tmux-agent-notify.sh — this module only deploys it and
# points each agent's native hook system at it.
#
# HOW EACH AGENT CALLS US
#   Claude Code  ~/.claude/settings.json        hooks: Stop, Notification
#   OpenCode     ~/.config/opencode/plugins/    events: session.idle,
#                (auto-loaded JS plugin)                permission.asked,
#                                                       session.error
#   Copilot CLI  ~/.copilot/hooks/*.json        events: agentStop,
#                                                       notification,
#                                                       errorOccurred
#
# PLUS: rickstaa/tmux-notify (not packaged in nixpkgs, so built here)
# gives prefix+m to arm completion notifications for ANY pane — long
# builds, test runs, remote shells. It detects "finished" heuristically
# (pane bottom line ends with a shell-prompt suffix), and we point its
# @tnotify-custom-cmd back at our script so generic commands produce
# the same bell + status message as agents do.
# ============================================================
{ pkgs, ... }:
let
  # The shared notifier script, deployed into the nix store.
  agentNotify = pkgs.writeShellScriptBin "tmux-agent-notify"
    (builtins.readFile ./files/tmux-agent-notify.sh);
  notifyCmd = "${agentNotify}/bin/tmux-agent-notify";

  # rickstaa/tmux-notify v1.6.0 — upstream ships TPM-style layout with
  # an entry file (tnotify.tmux) that resolves its own directory via
  # BASH_SOURCE, so it works unpatched straight from the store.
  tmux-notify = pkgs.tmuxPlugins.mkTmuxPlugin {
    pluginName = "tmux-notify";
    # Upstream names its entry file tnotify.tmux; home-manager would
    # otherwise look for tmux_notify.tmux and never load the plugin.
    rtpFilePath = "tnotify.tmux";
    version = "1.6.0";
    src = pkgs.fetchFromGitHub {
      owner = "rickstaa";
      repo = "tmux-notify";
      rev = "86982232675550416e3986516014b3f150abfc1d"; # tag: v1.6.0
      hash = "sha256-J7RNQEfeEtWFe9AJ4dHN2d/sZvs0EtPwPG7f5DZg+tA=";
    };
  };
in
{

  # ============================================================
  # TMUX PLUGIN: prefix+m monitor / M cancel
  # ============================================================
  programs.tmux.plugins = [
    {
      plugin = tmux-notify;
      extraConfig = ''
        # Show "(session, window:pane)" detail instead of a bare message.
        set -g @tnotify-verbose 'on'
        # Poll every 5s instead of 10s for snappier completion notices.
        set -g @tnotify-sleep-duration '5'
        # Prompt suffixes that mean "shell is idle again". Defaults are
        # $/#/%; we add ☽ because starship draws that as our prompt char.
        set -g @tnotify-prompt-suffixes '$,#,%,☽'
        # Upstream defaults this to a demo script on someone's Desktop;
        # override so completions reuse OUR notifier (bell + status line).
        set -g @tnotify-custom-cmd '${notifyCmd} shell done'
      '';
    }
  ];

  # ============================================================
  # CLAUDE CODE — ~/.claude/settings.json
  # ============================================================
  # Now fully managed here. Note: if Claude Code ever rewrites this
  # file itself (e.g. installing plugins via /plugin), it replaces the
  # symlink with a plain file; the next `home-manager switch` restores
  # ours. The very first switch will find the existing plain file in
  # the way — pass `-b pre-hm` so it gets moved aside automatically:
  #   home-manager switch --flake .#personal --impure -b pre-hm
  home.file.".claude/settings.json".text = ''
    {
      "tui": "fullscreen",
      "agentPushNotifEnabled": true,
      "enabledPlugins": {
        "frontend-design@claude-plugins-official": true
      },
      "hooks": {
        "Stop": [
          {
            "hooks": [
              { "type": "command", "command": "${notifyCmd} claude done" }
            ]
          }
        ],
        "Notification": [
          {
            "hooks": [
              { "type": "command", "command": "${notifyCmd} claude attention" }
            ]
          }
        ]
      }
    }
  '';

  # ============================================================
  # OPENCODE — ~/.config/opencode/plugins/tmux-notify.js
  # ============================================================
  # Global plugin; OpenCode auto-loads everything in this directory.
  # Bun's `$` shell interpolates safely, `.nothrow()` keeps a failed
  # call from throwing inside the event loop.
  xdg.configFile."opencode/plugins/tmux-notify.js".text = ''
    export const TmuxNotify = async ({ $ }) => {
      const send = async (kind) => {
        await $`${notifyCmd} opencode ''${kind}`.nothrow();
      };
      return {
        event: async ({ event }) => {
          if (event.type === "session.idle") {
            await send("done");
          } else if (event.type === "permission.asked") {
            await send("attention");
          } else if (event.type === "session.error") {
            await send("error");
          }
        },
      };
    };
  '';

  # ============================================================
  # COPILOT CLI — ~/.copilot/hooks/notification-hooks.json
  # ============================================================
  # User-level hook file (loaded automatically). Payload arrives as
  # JSON on stdin; our script just drains it.
  home.file.".copilot/hooks/notification-hooks.json".text = ''
    {
      "version": 1,
      "hooks": {
        "agentStop": [
          {
            "type": "command",
            "bash": "${notifyCmd} copilot done",
            "timeoutSec": 5
          }
        ],
        "notification": [
          {
            "type": "command",
            "bash": "${notifyCmd} copilot attention",
            "timeoutSec": 5
          }
        ],
        "errorOccurred": [
          {
            "type": "command",
            "bash": "${notifyCmd} copilot error",
            "timeoutSec": 5
          }
        ]
      }
    }
  '';
}
