/**
 * Drive Mode — keyboard-driven agent interaction
 *
 * Activated via /drive command. The agent never outputs prose. It always
 * responds by calling present_options with exactly 10 choices. You navigate
 * with j/k and pick with enter. t to type freely, r to reroll one option,
 * R to reroll all.
 *
 * When active, all built-in tool rendering is suppressed — you only see
 * the drive UI with an action log of what the agent did.
 */

import type { ExtensionAPI, Theme } from "@mariozechner/pi-coding-agent";
import {
	createBashTool,
	createEditTool,
	createFindTool,
	createGrepTool,
	createLsTool,
	createReadTool,
	createWriteTool,
} from "@mariozechner/pi-coding-agent";
import { matchesKey, truncateToWidth, Text } from "@mariozechner/pi-tui";
import { Type } from "@sinclair/typebox";
import { exec } from "node:child_process";
import { homedir } from "node:os";
import { promisify } from "node:util";

const execAsync = promisify(exec);

// ── Types ────────────────────────────────────────────────────────────────────

type DriveResult =
	| { type: "select"; text: string }
	| { type: "follow"; text: string }
	| { type: "typed"; text: string }
	| { type: "reroll-one"; index: number; text: string }
	| { type: "reroll-all" }
	| { type: "exit" };

type UIState = "selecting" | "typing";

type ActionEntry = { tool: string; summary: string };

// ── Constants ────────────────────────────────────────────────────────────────

const THINKING_CYCLE = ["off", "medium", "high"] as const;
type ThinkingLevel = (typeof THINKING_CYCLE)[number];

// ── Helpers ──────────────────────────────────────────────────────────────────

/** Clear screen and scrollback buffer */
function clearScreen(): void {
	process.stdout.write("\x1b[2J\x1b[3J\x1b[H");
}

function nextThinkingLevel(current: string): ThinkingLevel {
	const idx = THINKING_CYCLE.indexOf(current as ThinkingLevel);
	return THINKING_CYCLE[(idx + 1) % THINKING_CYCLE.length]!;
}

function shortenPath(path: string): string {
	const home = homedir();
	if (path.startsWith(home)) return `~${path.slice(home.length)}`;
	return path;
}

// ── System prompt ────────────────────────────────────────────────────────────

const DRIVE_SYSTEM_PROMPT = [
	"You are running in drive mode. You NEVER respond with prose or plain text.",
	"",
	"Your ONLY way of communicating with the user is by calling the present_options tool with exactly 10 options.",
	"",
	"After every completed action — and at the very start of the session — you MUST call present_options with exactly 10 options. Each option must be short (one line), specific, and immediately actionable given the current context. Avoid vague options like \"explore the codebase\". Be concrete: \"List all TypeScript files modified this week\", \"Run the test suite\", \"Show recent git commits\".",
	"",
	"There are two selection modes:",
	"",
	"1. **Normal select** (enter): The user picked an option and wants you to execute it FULLY and AUTONOMOUSLY. Do all the work — make every sub-decision yourself, use as many tools as needed — then call present_options with new options when done. Do NOT ask for intermediate decisions.",
	"",
	"2. **Follow mode** (f): The user picked an option but wants to FOLLOW ALONG step by step. Break the task into small incremental steps. After each individual tool call or small logical step, call present_options with 10 options that represent possible next steps for the current task. Include options to continue the obvious next step, take alternative approaches, skip ahead, or abort the task. The user will guide you through each decision.",
	"",
	"When the user types a free-form message (question, comment, or request), respond through the options themselves. Use option text to convey information, answer questions, or acknowledge what they said. For example, if they ask \"what branch am I on?\", include an option like \"You're on main — switch to a different branch\" alongside other relevant actions. The options ARE your voice — use them to communicate naturally while staying actionable.",
	"",
	"When the user selects an option, check whether it was a normal select or follow select — the message will tell you. Never skip the present_options call. Never output plain text. Always end with a present_options call.",
	"",
	"When making function calls using tools that accept array or object parameters ensure those are structured using JSON.",
].join("\n");

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

// ── Silent tool rendering ────────────────────────────────────────────────────
// Returns empty Text components so tool output is invisible in drive mode.

// Return undefined so ToolExecutionComponent sets hideComponent = true
// (returning empty Text still counts as content and renders a visible Box)

// ── DriveComponent ───────────────────────────────────────────────────────────

class DriveComponent {
	private options: string[];
	private actions: ActionEntry[];
	private cursor = 0;
	private state: UIState = "selecting";
	private inputBuffer = "";
	private tui: { requestRender: () => void };
	private theme: Theme;
	private done: (result: DriveResult) => void;
	private cachedLines?: string[];
	private cachedWidth?: number;
	private thinkingLevel: string;
	private onThinkingChange: (level: string) => void;

	constructor(
		options: string[],
		actions: ActionEntry[],
		tui: { requestRender: () => void },
		theme: Theme,
		thinkingLevel: string,
		onThinkingChange: (level: string) => void,
		done: (result: DriveResult) => void,
	) {
		this.options = options;
		this.actions = actions;
		this.tui = tui;
		this.theme = theme;
		this.thinkingLevel = thinkingLevel;
		this.onThinkingChange = onThinkingChange;
		this.done = done;
	}

	handleInput(data: string): void {
		if (this.state === "typing") {
			this.handleTypingInput(data);
		} else {
			this.handleSelectingInput(data);
		}
	}

	private handleSelectingInput(data: string): void {
		if (matchesKey(data, "j") || matchesKey(data, "down")) {
			this.cursor = Math.min(this.cursor + 1, this.options.length - 1);
			this.invalidate();
			this.tui.requestRender();
		} else if (matchesKey(data, "k") || matchesKey(data, "up")) {
			this.cursor = Math.max(this.cursor - 1, 0);
			this.invalidate();
			this.tui.requestRender();
		} else if (matchesKey(data, "enter")) {
			this.done({ type: "select", text: this.options[this.cursor]! });
		} else if (matchesKey(data, "f")) {
			this.done({ type: "follow", text: this.options[this.cursor]! });
		} else if (matchesKey(data, "t")) {
			this.state = "typing";
			this.inputBuffer = "";
			this.invalidate();
			this.tui.requestRender();
		} else if (matchesKey(data, "r")) {
			this.done({
				type: "reroll-one",
				index: this.cursor,
				text: this.options[this.cursor]!,
			});
		} else if (matchesKey(data, "shift+r")) {
			this.done({ type: "reroll-all" });
		} else if (matchesKey(data, "shift+t")) {
			this.thinkingLevel = nextThinkingLevel(this.thinkingLevel);
			this.onThinkingChange(this.thinkingLevel);
			this.invalidate();
			this.tui.requestRender();
		} else if (matchesKey(data, "ctrl+c") || matchesKey(data, "escape")) {
			this.done({ type: "exit" });
		}
	}

	private handleTypingInput(data: string): void {
		if (matchesKey(data, "escape")) {
			this.state = "selecting";
			this.inputBuffer = "";
			this.invalidate();
			this.tui.requestRender();
		} else if (matchesKey(data, "enter")) {
			if (this.inputBuffer.trim()) {
				this.done({ type: "typed", text: this.inputBuffer.trim() });
			}
		} else if (matchesKey(data, "backspace")) {
			if (this.inputBuffer.length > 0) {
				this.inputBuffer = this.inputBuffer.slice(0, -1);
				this.invalidate();
				this.tui.requestRender();
			}
		} else if (data.length === 1 && data.charCodeAt(0) >= 32) {
			this.inputBuffer += data;
			this.invalidate();
			this.tui.requestRender();
		}
	}

	render(width: number): string[] {
		if (this.cachedLines && this.cachedWidth === width) {
			return this.cachedLines;
		}

		const th = this.theme;
		const lines: string[] = [];

		lines.push("");
		const thinkingLabel = this.thinkingLevel === "off"
			? ""
			: `  ${th.fg("muted", "thinking:")} ${th.fg("accent", this.thinkingLevel)}`;
		lines.push(th.fg("accent", th.bold("  drive")) + thinkingLabel);
		lines.push(th.fg("borderMuted", "  " + "─".repeat(Math.max(0, width - 4))));

		// Action summary from last round
		if (this.actions.length > 0) {
			lines.push("");
			for (const action of this.actions) {
				lines.push(truncateToWidth(
					`  ${th.fg("success", "✓")} ${th.fg("muted", action.summary)}`,
					width,
				));
			}
		}

		lines.push("");

		for (let i = 0; i < this.options.length; i++) {
			const option = this.options[i]!;
			const num = String(i + 1).padStart(2);
			const selected = i === this.cursor && this.state === "selecting";

			const line = selected
				? th.fg("accent", `  ${num}  `) + th.fg("text", option)
				: th.fg("dim", `  ${num}  `) + th.fg("dim", option);

			lines.push(truncateToWidth(line, width));
		}

		lines.push("");

		if (this.state === "typing") {
			lines.push(th.fg("borderMuted", "  " + "─".repeat(Math.max(0, width - 4))));
			const cursor = "█";
			const inputLine = `  ${th.fg("accent", ">")} ${this.inputBuffer}${th.fg("dim", cursor)}`;
			lines.push(truncateToWidth(inputLine, width));
			lines.push("");
			lines.push(truncateToWidth(th.fg("dim", "  enter  send    esc  cancel"), width));
		} else {
			lines.push(truncateToWidth(
				th.fg("dim", "  j/k  navigate    enter  select    f  follow    t  type    r  reroll    R  reroll all    T  thinking    esc  exit"),
				width,
			));
		}

		// Pad to fill terminal so no previous content is visible
		const termRows = process.stdout.rows || 40;
		const targetLines = Math.max(lines.length, termRows - 2);
		while (lines.length < targetLines) {
			lines.push("");
		}

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
	let actionLog: ActionEntry[] = [];
	let savedThinkingLevel: string | undefined;

	// Register --drive flag for auto-start
	pi.registerFlag("drive", {
		description: "Start in drive mode",
		type: "boolean",
		default: false,
	});

	// ── Silent tool overrides ────────────────────────────────────────────
	// Override every built-in tool: same execute, silent rendering.

	const TOOL_DEFS: Array<{
		name: string;
		desc: string;
		factory: (cwd: string) => { parameters: any; execute: any };
	}> = [
		{
			name: "read",
			desc: "Read the contents of a file. Supports text files and images (jpg, png, gif, webp). Images are sent as attachments. For text files, output is truncated to 2000 lines or 50KB (whichever is hit first). Use offset/limit for large files. When you need the full file, continue with offset until complete.",
			factory: createReadTool,
		},
		{
			name: "bash",
			desc: "Execute a bash command in the current working directory. Returns stdout and stderr. Output is truncated to last 2000 lines or 50KB (whichever is hit first). If truncated, full output is saved to a temp file. Optionally provide a timeout in seconds.",
			factory: createBashTool,
		},
		{
			name: "edit",
			desc: "Edit a file by replacing exact text. The oldText must match exactly (including whitespace). Use this for precise, surgical edits.",
			factory: createEditTool,
		},
		{
			name: "write",
			desc: "Write content to a file. Creates the file if it doesn't exist, overwrites if it does. Automatically creates parent directories.",
			factory: createWriteTool,
		},
		{
			name: "find",
			desc: "Find files by name pattern (glob). Searches recursively from the specified path. Output limited to 200 results.",
			factory: createFindTool,
		},
		{
			name: "grep",
			desc: "Search file contents by regex pattern. Uses ripgrep for fast searching. Output limited to 200 matches.",
			factory: createGrepTool,
		},
		{
			name: "ls",
			desc: "List directory contents with file sizes. Shows files and directories with their sizes. Output limited to 500 entries.",
			factory: createLsTool,
		},
	];

	for (const def of TOOL_DEFS) {
		const defaultTool = def.factory(process.cwd());
		pi.registerTool({
			name: def.name,
			label: def.name,
			description: def.desc,
			parameters: defaultTool.parameters,
			async execute(toolCallId, params, signal, onUpdate, ctx) {
				const tool = def.factory(ctx.cwd);
				return tool.execute(toolCallId, params, signal, onUpdate);
			},
			// Silent when drive mode is active, otherwise show name only
			renderCall(args, theme) {
				if (driveActive) return undefined;
				return new Text(theme.fg("toolTitle", theme.bold(def.name)), 0, 0);
			},
			renderResult(_result, _options, _theme) {
				if (driveActive) return undefined;
				return undefined;
			},
		});
	}

	// ── Action tracking ──────────────────────────────────────────────────

	pi.on("tool_execution_start", async (event, _ctx) => {
		if (!driveActive) return;
		if (event.toolName === "present_options") return;

		let summary = "";
		const args = event.args as any;
		switch (event.toolName) {
			case "bash":
				summary = `ran: ${args?.command?.slice(0, 60) ?? "command"}`;
				break;
			case "read":
				summary = `read ${shortenPath(args?.path ?? "")}`;
				break;
			case "write":
				summary = `wrote ${shortenPath(args?.path ?? "")}`;
				break;
			case "edit":
				summary = `edited ${shortenPath(args?.path ?? "")}`;
				break;
			case "grep":
				summary = `grep /${args?.pattern ?? ""}/`;
				break;
			case "find":
				summary = `find ${args?.pattern ?? ""}`;
				break;
			case "ls":
				summary = `ls ${shortenPath(args?.path ?? ".")}`;
				break;
			default:
				summary = event.toolName;
		}

		actionLog.push({ tool: event.toolName, summary });
	});

	// ── Lifecycle ────────────────────────────────────────────────────────

	pi.on("session_start", async (_event, ctx) => {
		if (!pi.getFlag("--drive") || !ctx.hasUI) return;
		driveActive = true;
		savedThinkingLevel = pi.getThinkingLevel();
		pi.setThinkingLevel("off");
		clearScreen();
		ctx.ui.setWorkingMessage(" ");
		const context = await gatherContext(ctx.cwd);
		pi.sendMessage(
			{
				customType: "drive-prompt",
				content: `Drive mode active. Current context:\n\n${context}\n\nCall present_options now with 10 suggestions for things I might want to do.`,
				display: false,
			},
			{ triggerTurn: true },
		);
	});

	pi.on("before_agent_start", async (event, _ctx) => {
		if (!driveActive) return;
		return {
			systemPrompt: event.systemPrompt + "\n\n" + DRIVE_SYSTEM_PROMPT,
		};
	});

	// ── present_options tool ─────────────────────────────────────────────

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

			// Snapshot and clear the action log for this round
			const actions = [...actionLog];
			actionLog = [];

			// Clear screen so only the drive UI is visible
			clearScreen();

			const result = await ctx.ui.custom<DriveResult>(
				(tui, theme, _kb, done) =>
					new DriveComponent(
						params.options,
						actions,
						tui,
						theme,
						pi.getThinkingLevel(),
						(level) => pi.setThinkingLevel(level as any),
						done,
					),
			);

			if (result.type === "exit") {
				driveActive = false;
				if (savedThinkingLevel) {
					pi.setThinkingLevel(savedThinkingLevel as any);
					savedThinkingLevel = undefined;
				}
				ctx.ui.setWorkingMessage();
				return {
					content: [{ type: "text", text: "User exited drive mode. Resume normal conversation." }],
					details: {},
				};
			}

			let responseText: string;
			switch (result.type) {
				case "select":
					responseText = `User selected: ${result.text}\n\nExecute this fully and autonomously. Make all sub-decisions yourself. Call present_options when done.`;
					break;
				case "follow":
					responseText = `User selected (FOLLOW MODE): ${result.text}\n\nThe user wants to follow along step by step. Do ONE small step, then call present_options with next-step choices for this task.`;
					break;
				case "typed":
					responseText = `User typed: ${result.text}`;
					break;
				case "reroll-one":
					responseText = `User wants option ${result.index + 1} ("${result.text}") replaced with something different but similar in scope. Call present_options with 10 options, replacing that one.`;
					break;
				case "reroll-all":
					responseText = `User wants all options rerolled. Call present_options with 10 completely different suggestions.`;
					break;
			}

			return {
				content: [{ type: "text", text: responseText }],
				details: {},
			};
		},

		// present_options itself is also silent
		renderCall: () => undefined,
		renderResult: () => undefined,
	});

	// ── /drive command ───────────────────────────────────────────────────

	pi.registerCommand("drive", {
		description: "Enter drive mode — navigate options instead of typing",
		handler: async (_args, ctx) => {
			if (!ctx.hasUI) {
				ctx.ui.notify("Drive mode requires interactive mode", "error");
				return;
			}

			driveActive = true;
			actionLog = [];
			savedThinkingLevel = pi.getThinkingLevel();
			pi.setThinkingLevel("off");
			clearScreen();
			ctx.ui.setWorkingMessage(" ");
			const context = await gatherContext(ctx.cwd);

			pi.sendMessage(
				{
					customType: "drive-prompt",
					content: `Drive mode active. Current context:\n\n${context}\n\nCall present_options now with 10 suggestions for things I might want to do.`,
					display: false,
				},
				{ triggerTurn: true },
			);
		},
	});
}
