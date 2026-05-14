/**
 * Drive Mode — keyboard-driven agent interaction
 *
 * Activated via /drive command. The agent never outputs prose. It always
 * responds by calling present_options with exactly 10 choices. You navigate
 * with j/k and pick with enter. The tool blocks until you choose, then
 * returns your selection as the tool result and the agent continues.
 *
 * Phase 1: prove the loop works.
 */

import type { ExtensionAPI, Theme } from "@mariozechner/pi-coding-agent";
import { matchesKey, truncateToWidth } from "@mariozechner/pi-tui";
import { Type } from "@sinclair/typebox";
import { exec } from "node:child_process";
import { promisify } from "node:util";

const execAsync = promisify(exec);

// ── System prompt ────────────────────────────────────────────────────────────

const DRIVE_SYSTEM_PROMPT = `
You are running in drive mode. You NEVER respond with prose or plain text.

Your ONLY way of communicating with the user is by calling the present_options tool with exactly 10 options.

After every completed action — and at the very start of the session — you MUST call present_options with exactly 10 options. Each option must be short (one line), specific, and immediately actionable given the current context. Avoid vague options like "explore the codebase". Be concrete: "List all TypeScript files modified this week", "Run the test suite", "Show recent git commits".

When the user selects an option, execute it fully using your tools, then call present_options again. Never skip this step. Never output plain text. Always end with a present_options call.
`.trim();

// ── Context gathering ────────────────────────────────────────────────────────

async function gatherContext(cwd: string): Promise<string> {
	const run = async (cmd: string) => {
		try {
			const { stdout } = await execAsync(cmd, { cwd, timeout: 5000 });
			return stdout.trim();
		} catch {
			return "";
		}
	};

	const [pwd, branch, status, files] = await Promise.all([
		run("pwd"),
		run("git rev-parse --abbrev-ref HEAD 2>/dev/null"),
		run("git status --short 2>/dev/null | head -10"),
		run("ls -1 2>/dev/null | head -20"),
	]);

	const parts: string[] = [`Working directory: ${pwd}`];
	if (branch) parts.push(`Git branch: ${branch}`);
	if (status) parts.push(`Git status:\n${status}`);
	if (files) parts.push(`Directory contents:\n${files}`);

	return parts.join("\n\n");
}

// ── DriveComponent ───────────────────────────────────────────────────────────

class DriveComponent {
	private options: string[];
	private cursor = 0;
	private tui: { requestRender: () => void };
	private theme: Theme;
	private done: (selection: string) => void;
	private cachedLines?: string[];
	private cachedWidth?: number;

	constructor(
		options: string[],
		tui: { requestRender: () => void },
		theme: Theme,
		done: (selection: string) => void,
	) {
		this.options = options;
		this.tui = tui;
		this.theme = theme;
		this.done = done;
	}

	handleInput(data: string): void {
		if (matchesKey(data, "j") || matchesKey(data, "down")) {
			this.cursor = Math.min(this.cursor + 1, this.options.length - 1);
			this.invalidate();
			this.tui.requestRender();
		} else if (matchesKey(data, "k") || matchesKey(data, "up")) {
			this.cursor = Math.max(this.cursor - 1, 0);
			this.invalidate();
			this.tui.requestRender();
		} else if (matchesKey(data, "enter")) {
			this.done(this.options[this.cursor]!);
		}
	}

	render(width: number): string[] {
		if (this.cachedLines && this.cachedWidth === width) {
			return this.cachedLines;
		}

		const th = this.theme;
		const lines: string[] = [];

		lines.push("");
		lines.push(th.fg("accent", th.bold("  drive")));
		lines.push(th.fg("borderMuted", "  " + "─".repeat(Math.max(0, width - 4))));
		lines.push("");

		for (let i = 0; i < this.options.length; i++) {
			const option = this.options[i]!;
			const num = String(i + 1).padStart(2);
			const selected = i === this.cursor;

			const line = selected
				? th.fg("accent", `  ${num}  `) + th.fg("text", option)
				: th.fg("dim", `  ${num}  `) + th.fg("dim", option);

			lines.push(truncateToWidth(line, width));
		}

		lines.push("");
		lines.push(truncateToWidth(th.fg("dim", "  j/k  navigate    enter  select"), width));

		this.cachedLines = lines;
		this.cachedWidth = width;
		return lines;
	}

	invalidate(): void {
		this.cachedLines = undefined;
		this.cachedWidth = undefined;
	}
}

// ── Extension ────────────────────────────────────────────────────────────────

export default function (pi: ExtensionAPI) {
	let driveActive = false;

	// Only inject the drive system prompt when drive mode is active
	pi.on("before_agent_start", async (event, _ctx) => {
		if (!driveActive) return;
		return {
			systemPrompt: event.systemPrompt + "\n\n" + DRIVE_SYSTEM_PROMPT,
		};
	});

	// The core: present_options blocks until the user selects
	pi.registerTool({
		name: "present_options",
		label: "Options",
		description:
			"Present the user with exactly 10 options for what to do next. You MUST call this after every completed action. Returns the user's selection.",
		parameters: Type.Object({
			options: Type.Array(Type.String(), {
				minItems: 10,
				maxItems: 10,
				description: "Exactly 10 short, specific, actionable options",
			}),
		}),

		async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
			if (!ctx.hasUI) {
				return {
					content: [{ type: "text", text: params.options[0] ?? "continue" }],
					details: {},
				};
			}

			const selection = await ctx.ui.custom<string>(
				(tui, theme, _kb, done) => new DriveComponent(params.options, tui, theme, done),
			);

			return {
				content: [{ type: "text", text: `User selected: ${selection}` }],
				details: {},
			};
		},
	});

	// /drive command activates drive mode
	pi.registerCommand("drive", {
		description: "Enter drive mode — navigate options instead of typing",
		handler: async (_args, ctx) => {
			if (!ctx.hasUI) {
				ctx.ui.notify("Drive mode requires interactive mode", "error");
				return;
			}

			driveActive = true;
			const context = await gatherContext(ctx.cwd);

			pi.sendUserMessage(
				`Drive mode active. Current context:\n\n${context}\n\nCall present_options now with 10 suggestions for things I might want to do.`,
			);
		},
	});
}
