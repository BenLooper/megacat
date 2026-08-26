// Agent → Windows notifications for OpenCode (twin of the tmux plugin
// home-manager deploys on the Linux side). OpenCode auto-loads every
// file in ~/.config/opencode/plugins/.
//
// Claude Code and Copilot CLI get the same treatment through their
// JSON hook configs (~/.claude/settings.json, ~/.copilot/hooks/);
// everything funnels into agent-notify.ps1, which bell-flags the
// tab, flashes the taskbar, and fires a toast.
export const AgentNotify = async ({ $ }) => {
  const send = async (kind) => {
    const script = `${process.env.USERPROFILE}\\.local\\scripts\\agent-notify.ps1`;
    // powershell.exe (5.1) on purpose: WinRT toasts only project there.
    await $`powershell.exe -NoProfile -ExecutionPolicy Bypass -File ${script} opencode ${kind}`.nothrow();
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
