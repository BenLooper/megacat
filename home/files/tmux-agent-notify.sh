#!/usr/bin/env bash
# ============================================================
# tmux-agent-notify — surface AI-agent activity inside tmux.
#
# One tiny script shared by all three coding agents (Claude Code,
# OpenCode, GitHub Copilot CLI). Their hook systems call it when a
# turn finishes, an error occurs, or input is needed, and it:
#
#   1. Skips silently if you are already looking at that exact pane.
#   2. Prints a short status-line message on every attached client.
#
# Usage: tmux-agent-notify <agent> <kind>
#   agent: claude | opencode | copilot | shell (any label, really)
#   kind:  done | attention | error (anything else shows verbatim)
#
# Agents pipe a JSON event payload to stdin; we don't parse it yet,
# but we drain it so the writer never blocks on a full pipe.
# ============================================================
set -u

AGENT="${1:-agent}"
KIND="${2:-done}"

# Not inside tmux (or tmux unavailable) -> nothing to do.
[ -n "${TMUX:-}" ] || exit 0
PANE="${TMUX_PANE:-}"
[ -n "$PANE" ] || exit 0
command -v tmux >/dev/null 2>&1 || exit 0

# Drain the JSON payload from stdin, but only when stdin is a pipe
# (a manual run from an interactive shell would otherwise block).
[ -t 0 ] || cat >/dev/null 2>&1

# Skip when some attached client is already focused on this pane —
# no point notifying someone who is watching it already.
while IFS= read -r client; do
    [ -n "$client" ] || continue
    active_pane="$(tmux display-message -p -t "$client" '#{pane_id}' 2>/dev/null)" || continue
    if [ "$active_pane" = "$PANE" ]; then
        exit 0
    fi
done < <(tmux list-clients -F '#{client_name}' 2>/dev/null)

case "$KIND" in
done) icon="✓"; verb="finished" ;;
attention) icon="?"; verb="needs input" ;;
error) icon="✗"; verb="errored" ;;
*) icon="•"; verb="$KIND" ;;
esac

label="$(basename "${PWD}")"

# Mark the tmux window without changing its name more than once per event.
# The marker remains visible until the window is renamed manually.
window_name="$(tmux display-message -p -t "$PANE" '#{window_name}' 2>/dev/null)"
if [ -n "$window_name" ] && [[ "$window_name" != "[!] "* ]]; then
    tmux rename-window -t "$PANE" "[!] $window_name" 2>/dev/null || true
fi

# Show a transient message in every attached client's status bar.
while IFS= read -r client; do
    [ -n "$client" ] || continue
    tmux display-message -t "$client" -d 3000 \
        "$icon $AGENT $verb — $label" 2>/dev/null
done < <(tmux list-clients -F '#{client_name}' 2>/dev/null)

exit 0
