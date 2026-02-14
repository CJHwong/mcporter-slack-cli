/**
 * Token Efficiency Benchmark: slack-cli Skill vs Direct MCP
 *
 * Compares two approaches for Slack integration with Claude:
 *   Config A (skill): Claude Code skill + Bash (progressive disclosure)
 *   Config B (mcp):   Direct MCP server connection (tool schemas auto-injected)
 *
 * Both use the same claude_code system prompt preset and the same underlying
 * slack-mcp-server. The only difference is how Slack tools are exposed.
 *
 * Setup:
 *   cp .env.example .env   # then fill in credentials and config
 *   npm install && npm run benchmark
 *
 * See .env.example for all configuration options.
 */

import { query } from "@anthropic-ai/claude-agent-sdk";
import type { SDKMessage } from "@anthropic-ai/claude-agent-sdk";
import { execSync } from "child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "fs";
import { dirname, resolve, join } from "path";
import { fileURLToPath } from "url";
import { getScenarios, type Scenario } from "./scenarios.js";
// --- Paths ---
const __dirname = dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = resolve(__dirname, "../..");
const RESULTS_DIR = join(__dirname, "results");

// --- Load .env ---

function loadEnvFile(path: string): void {
  if (!existsSync(path)) return;
  for (const line of readFileSync(path, "utf-8").split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const eqIdx = trimmed.indexOf("=");
    if (eqIdx === -1) continue;
    const key = trimmed.slice(0, eqIdx).replace(/^export\s+/, "");
    const value = trimmed.slice(eqIdx + 1).replace(/^["']|["']$/g, "");
    if (!process.env[key]) process.env[key] = value;
  }
}

loadEnvFile(join(__dirname, ".env"));

const HAS_AWS_CREDS = !!(process.env.AWS_ACCESS_KEY_ID && process.env.AWS_SECRET_ACCESS_KEY);
const HAS_BEARER_TOKEN = !!process.env.AWS_BEARER_TOKEN_BEDROCK;
const USE_BEDROCK = !process.env.ANTHROPIC_API_KEY && (HAS_AWS_CREDS || HAS_BEARER_TOKEN);

// --- Config ---
const MODEL = process.env.BENCHMARK_MODEL;
const SMALL_MODEL = process.env.BENCHMARK_SMALL_MODEL;
const MAX_TURNS = 15;
const CHANNEL = process.env.BENCHMARK_CHANNEL;
const VERBOSE = process.env.VERBOSE === "1";
const ONLY_SCENARIO = process.env.BENCHMARK_SCENARIO;
const ONLY_CONFIG = process.env.BENCHMARK_CONFIG as "skill" | "mcp" | undefined;

type SessionMode = "isolated" | "single";
const SESSION_MODE: SessionMode =
  (process.env.BENCHMARK_SESSION_MODE as SessionMode) || "isolated";

const SCENARIOS = getScenarios(CHANNEL!);

// --- Types ---
type ConfigType = "skill" | "mcp";

interface RunResult {
  config: ConfigType;
  scenario: string;
  scenarioName: string;
  inputTokens: number;
  outputTokens: number;
  cacheReadTokens: number;
  cacheCreationTokens: number;
  totalCostUsd: number;
  numTurns: number;
  durationMs: number;
  durationApiMs: number;
  resultText: string;
  isError: boolean;
  sessionId: string;
}

// --- Helpers ---

function validateEnv(): void {
  const missing: string[] = [];
  if (!CHANNEL) missing.push("BENCHMARK_CHANNEL");
  if (!MODEL) missing.push("BENCHMARK_MODEL");
  if (!process.env.SLACK_MCP_XOXP_TOKEN) missing.push("SLACK_MCP_XOXP_TOKEN");
  if (!process.env.ANTHROPIC_API_KEY && !HAS_AWS_CREDS && !HAS_BEARER_TOKEN) {
    missing.push("ANTHROPIC_API_KEY or AWS_ACCESS_KEY_ID+AWS_SECRET_ACCESS_KEY or AWS_BEARER_TOKEN_BEDROCK");
  }
  if (missing.length > 0) {
    console.error(`Missing required config: ${missing.join(", ")}`);
    console.error("Hint: cp .env.example .env and fill in your values");
    process.exit(1);
  }
}

function ensureDaemon(): void {
  console.log("Ensuring slack-cli daemon is running...");
  try {
    execSync("slack-cli server start", {
      env: buildEnv(),
      timeout: 60_000,
      stdio: "pipe",
    });
    console.log("  Daemon ready.\n");
  } catch {
    // May already be running
    console.log("  Daemon may already be running, continuing.\n");
  }
}

function buildEnv(): Record<string, string> {
  const env: Record<string, string> = {};
  for (const [key, value] of Object.entries(process.env)) {
    if (value !== undefined) env[key] = value;
  }
  // Model config — SDK reads these env vars internally
  if (MODEL) env.ANTHROPIC_MODEL = MODEL;
  if (SMALL_MODEL) env.ANTHROPIC_SMALL_FAST_MODEL = SMALL_MODEL;
  if (USE_BEDROCK) {
    env.CLAUDE_CODE_USE_BEDROCK = "1";
    env.AWS_REGION = env.AWS_REGION ?? "us-west-2";
  }
  // Enable write tools for S5 (daemon auto-restarts on SLACK_MCP_* env change)
  env.SLACK_MCP_ADD_MESSAGE_TOOL = "true";
  return env;
}

function logToolUse(message: SDKMessage): void {
  if (!VERBOSE) return;
  if (message.type !== "assistant") return;
  const content = (message as any).message?.content;
  if (!Array.isArray(content)) return;
  for (const block of content) {
    if (block.type === "tool_use") {
      console.log(`    → ${block.name}(${JSON.stringify(block.input).slice(0, 80)}...)`);
    }
  }
}

function extractResult(message: SDKMessage, config: ConfigType, scenario: Scenario): RunResult {
  if (message.type !== "result") throw new Error("Not a result message");
  const m = message as any;
  return {
    config,
    scenario: scenario.id,
    scenarioName: scenario.name,
    inputTokens: m.usage?.input_tokens ?? 0,
    outputTokens: m.usage?.output_tokens ?? 0,
    cacheReadTokens: m.usage?.cache_read_input_tokens ?? 0,
    cacheCreationTokens: m.usage?.cache_creation_input_tokens ?? 0,
    totalCostUsd: m.total_cost_usd ?? 0,
    numTurns: m.num_turns ?? 0,
    durationMs: m.duration_ms ?? 0,
    durationApiMs: m.duration_api_ms ?? 0,
    resultText: m.subtype === "success" ? (m.result ?? "") : (m.errors?.join("\n") ?? ""),
    isError: m.is_error ?? false,
    sessionId: m.session_id ?? "",
  };
}

// --- Runners ---

async function runSkill(scenario: Scenario, resumeSessionId?: string): Promise<RunResult> {
  for await (const message of query({
    prompt: scenario.prompt,
    options: {
      systemPrompt: { type: "preset", preset: "claude_code" },
      settingSources: ["project"],
      model: MODEL,
      maxTurns: MAX_TURNS,
      disallowedTools: ["TodoWrite", "TaskCreate", "TaskUpdate", "TaskList", "TaskGet"],
      permissionMode: "bypassPermissions",
      allowDangerouslySkipPermissions: true,
      cwd: PROJECT_ROOT,
      env: buildEnv(),
      ...(resumeSessionId ? { resume: resumeSessionId } : {}),
    },
  })) {
    logToolUse(message);
    if (message.type === "result") {
      return extractResult(message, "skill", scenario);
    }
  }
  throw new Error(`No result for skill/${scenario.id}`);
}

async function runMcp(scenario: Scenario, resumeSessionId?: string): Promise<RunResult> {
  for await (const message of query({
    prompt: scenario.prompt,
    options: {
      systemPrompt: { type: "preset", preset: "claude_code" },
      settingSources: [],
      model: MODEL,
      maxTurns: MAX_TURNS,
      mcpServers: {
        slack: {
          type: "sse" as const,
          url: "http://127.0.0.1:13080/sse",
        },
      },
      disallowedTools: ["TodoWrite", "TaskCreate", "TaskUpdate", "TaskList", "TaskGet"],
      permissionMode: "bypassPermissions",
      allowDangerouslySkipPermissions: true,
      cwd: PROJECT_ROOT,
      env: buildEnv(),
      ...(resumeSessionId ? { resume: resumeSessionId } : {}),
    },
  })) {
    logToolUse(message);
    if (message.type === "result") {
      return extractResult(message, "mcp", scenario);
    }
  }
  throw new Error(`No result for mcp/${scenario.id}`);
}

// --- Output ---

function wordCount(text: string): number {
  return text.trim().split(/\s+/).filter(Boolean).length;
}

function formatRow(r: RunResult): string {
  return [
    r.scenarioName.padEnd(22),
    r.config.padEnd(6),
    String(r.inputTokens).padStart(8),
    String(r.outputTokens).padStart(8),
    String(r.cacheReadTokens).padStart(10),
    String(r.cacheCreationTokens).padStart(12),
    `$${r.totalCostUsd.toFixed(6)}`,
    String(r.numTurns).padStart(5),
    `${(r.durationApiMs / 1000).toFixed(1)}s`.padStart(7),
    String(wordCount(r.resultText)).padStart(5),
    r.isError ? "ERR" : "OK",
  ].join(" | ");
}

function printSummary(results: RunResult[]): void {
  const header = [
    "Scenario".padEnd(22),
    "Config".padEnd(6),
    "Input".padStart(8),
    "Output".padStart(8),
    "CacheRead".padStart(10),
    "CacheCreate".padStart(12),
    "Cost (USD) ",
    "Turns".padStart(5),
    "API".padStart(7),
    "Words".padStart(5),
    "Status",
  ].join(" | ");

  console.log(`\n\n=== RESULTS (session: ${SESSION_MODE}) ===\n`);
  console.log(header);
  console.log("-".repeat(header.length));

  // Group by scenario for side-by-side comparison
  const scenarioIds = [...new Set(results.map((r) => r.scenario))];
  for (const sid of scenarioIds) {
    const group = results.filter((r) => r.scenario === sid);
    for (const r of group) {
      console.log(formatRow(r));
    }
    // Print delta mcp vs skill
    const skill = group.find((r) => r.config === "skill");
    const mcp = group.find((r) => r.config === "mcp");
    if (skill && mcp) {
      const costDelta = pctDiff(mcp.totalCostUsd, skill.totalCostUsd);
      const turnDelta = pctDiff(mcp.numTurns, skill.numTurns);
      console.log(
        `  Δ mcp vs skill`.padEnd(33) +
        `| cost: ${deltaStr(costDelta).padStart(7)} | turns: ${deltaStr(turnDelta).padStart(7)} |`
      );
    }
    console.log("");
  }

  // Totals
  const sumField = (arr: RunResult[], key: keyof RunResult) =>
    arr.reduce((s, r) => s + (r[key] as number), 0);

  const skillRows = results.filter((r) => r.config === "skill");
  const mcpRows = results.filter((r) => r.config === "mcp");

  if (skillRows.length > 0 && mcpRows.length > 0) {
    console.log("=== TOTALS ===\n");
    for (const [label, rows] of [["skill", skillRows], ["mcp", mcpRows]] as const) {
      const input = sumField(rows, "inputTokens");
      const output = sumField(rows, "outputTokens");
      const cost = sumField(rows, "totalCostUsd");
      const turns = sumField(rows, "numTurns");
      console.log(`  ${label.padEnd(6)}  ${input} input, ${output} output, ${turns} turns, $${cost.toFixed(6)}`);
    }
    const skillCost = sumField(skillRows, "totalCostUsd");
    const mcpCost = sumField(mcpRows, "totalCostUsd");
    const skillTurns = sumField(skillRows, "numTurns");
    const mcpTurns = sumField(mcpRows, "numTurns");
    console.log(
      `  Δ mcp vs skill: ${deltaStr(pctDiff(mcpCost, skillCost))} cost, ${deltaStr(pctDiff(mcpTurns, skillTurns))} turns`
    );
  }

  // Result quality comparison
  if (skillRows.length > 0 && mcpRows.length > 0) {
    console.log("\n=== RESULT QUALITY ===\n");
    for (const sid of scenarioIds) {
      const group = results.filter((r) => r.scenario === sid);
      const name = group[0]?.scenarioName ?? sid;
      console.log(`  ${name}:`);
      for (const r of group) {
        const words = wordCount(r.resultText);
        const preview = r.resultText.replace(/\n/g, " ").slice(0, 120);
        console.log(`    [${r.config.padEnd(6)}] ${words} words | ${preview}${r.resultText.length > 120 ? "..." : ""}`);
      }
      console.log("");
    }
  }
}

function pctDiff(a: number, b: number): number {
  return b === 0 ? 0 : ((a - b) / b) * 100;
}

function deltaStr(pct: number): string {
  const sign = pct >= 0 ? "+" : "";
  return `${sign}${pct.toFixed(1)}%`;
}

// --- Main ---

async function main(): Promise<void> {
  validateEnv();
  mkdirSync(RESULTS_DIR, { recursive: true });

  console.log("=== Slack CLI vs MCP: Token Efficiency Benchmark ===\n");
  console.log(`  Provider:   ${USE_BEDROCK ? "AWS Bedrock" : "Anthropic API"}`);
  console.log(`  Model:      ${MODEL}`);
  if (SMALL_MODEL) console.log(`  Fast model: ${SMALL_MODEL}`);
  console.log(`  Channel:    ${CHANNEL}`);
  console.log(`  Max turns:  ${MAX_TURNS}`);
  console.log(`  Verbose:    ${VERBOSE}`);

  const scenarios = ONLY_SCENARIO
    ? SCENARIOS.filter((s) => s.id === ONLY_SCENARIO)
    : SCENARIOS;

  if (scenarios.length === 0) {
    console.error(`Unknown scenario: ${ONLY_SCENARIO}`);
    console.error(`Available: ${SCENARIOS.map((s) => s.id).join(", ")}`);
    process.exit(1);
  }

  const configs: ConfigType[] = ONLY_CONFIG ? [ONLY_CONFIG] : ["skill", "mcp"];
  console.log(`  Scenarios:  ${scenarios.map((s) => s.id).join(", ")}`);
  console.log(`  Configs:    ${configs.join(", ")}`);
  console.log(`  Session:    ${SESSION_MODE}`);

  // Ensure the daemon is running (needed for both configs)
  ensureDaemon();

  const results: RunResult[] = [];

  if (SESSION_MODE === "single") {
    // Single-session: config outer loop, scenarios inner loop, chaining session_id
    for (const config of configs) {
      console.log(`\n=== Config: ${config} (single session) ===`);
      let sessionId: string | undefined;

      for (const scenario of scenarios) {
        const label = `[${config}]`.padEnd(8);
        console.log(`\n--- ${scenario.name} (${scenario.id}) ---`);
        console.log(`  ${label} Running...${sessionId ? ` (resuming ${sessionId.slice(0, 8)}...)` : ""}`);

        try {
          const runner = config === "skill" ? runSkill : runMcp;
          const result = await runner(scenario, sessionId);
          results.push(result);
          sessionId = result.sessionId;

          console.log(
            `  ${label} Input: ${result.inputTokens} | Output: ${result.outputTokens} | ` +
            `Cost: $${result.totalCostUsd.toFixed(6)} | Turns: ${result.numTurns} | ` +
            `API: ${(result.durationApiMs / 1000).toFixed(1)}s` +
            (result.isError ? " | ERROR" : "")
          );
        } catch (e: unknown) {
          const msg = e instanceof Error ? e.message : String(e);
          console.error(`  ${label} FAILED: ${msg}`);
          // Break the chain — can't resume a failed session
          break;
        }
      }
    }
  } else {
    // Isolated: scenario outer loop, config inner loop (original behavior)
    for (const scenario of scenarios) {
      console.log(`\n--- ${scenario.name} (${scenario.id}) ---`);

      for (const config of configs) {
        const label = `[${config}]`.padEnd(8);
        console.log(`  ${label} Running...`);

        try {
          const runner = config === "skill" ? runSkill : runMcp;
          const result = await runner(scenario);
          results.push(result);

          console.log(
            `  ${label} Input: ${result.inputTokens} | Output: ${result.outputTokens} | ` +
            `Cost: $${result.totalCostUsd.toFixed(6)} | Turns: ${result.numTurns} | ` +
            `API: ${(result.durationApiMs / 1000).toFixed(1)}s` +
            (result.isError ? " | ERROR" : "")
          );
        } catch (e: unknown) {
          const msg = e instanceof Error ? e.message : String(e);
          console.error(`  ${label} FAILED: ${msg}`);
        }
      }
    }
  }

  if (results.length === 0) {
    console.error("\nNo results collected. Check errors above.");
    process.exit(1);
  }

  printSummary(results);

  // Save raw results
  const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
  const outPath = join(RESULTS_DIR, `${timestamp}.json`);
  const output = {
    meta: { provider: USE_BEDROCK ? "bedrock" : "anthropic", model: MODEL, channel: CHANNEL, maxTurns: MAX_TURNS, sessionMode: SESSION_MODE, timestamp: new Date().toISOString() },
    results,
  };
  writeFileSync(outPath, JSON.stringify(output, null, 2));
  console.log(`\nResults saved to ${outPath}`);
}

main().catch((e) => {
  console.error("Fatal:", e);
  process.exit(1);
});
