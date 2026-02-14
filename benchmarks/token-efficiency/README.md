# Token Efficiency Benchmark: Skill vs MCP

Compares two approaches for integrating Slack with Claude Code:

- **Skill** — [Agent Skill](https://agentskills.io) (`SKILL.md`) + Bash tool. Agent loads the skill, then shells out to `slack-cli` for each operation.
- **MCP** — Direct MCP server connection via SSE. Agent calls structured Slack tools (e.g. `mcp__slack__channels_list`) with no shell layer.

Both use the same underlying `slack-mcp-server` daemon on `localhost:13080`. Both have access to the same tools (including Bash).

## Results

Skill is cheaper or equivalent across both session modes.

| Mode | Skill | MCP | Cost Δ | Turn Δ |
|---|---|---|---|---|
| Isolated | $0.76, 32 turns | $0.80, 26 turns | +4.1% | -18.8% |
| Single | $0.76, 21 turns | $1.01, 21 turns | +32.8% | +0% |

* **MCP wins on simple isolated tasks** (S1–S3, S5).
* **Skill wins on complex research** (S4): MCP over-explores without skill doc guidance.
* **Single-session amplifies MCP's disadvantage**: MCP's verbose history inflates context for later scenarios.

See [RESULTS.md](RESULTS.md) for per-scenario breakdowns and analysis.

## When to choose which

### Choose MCP when

- **Simple, isolated operations** — List channels, read messages, post a message. MCP uses fewer turns and costs less for straightforward tasks.
- **Non-Agent Skill-compatible clients** — MCP works with most clients. Requires configuring the server endpoint per client.

### Choose Skill + CLI when

- **Portability** — The skill ships in `.claude/skills/` with the repo. Anyone who clones it gets the Slack integration with zero setup. MCP requires per-client server configuration.
- **Complex multi-step tasks** — The skill doc guides the agent and prevents aimless exploration.
- **Long-running sessions** — MCP's verbose tool responses accumulate into heavier conversation history. In single-session mode, MCP costs 33% more with no turn advantage.
- **Customizable workflows** — Edit `SKILL.md` to add project-specific instructions, channel conventions, or response formats. MCP tool schemas are fixed by the server.

Skill support is expanding across clients beyond Claude Code.

> **Note:** MCP and Skill can be combined — use the skill to guide the agent while MCP provides the tools. However, this incurs the overhead of both: skill loading cost plus full MCP tool schema injection.

### Default recommendation

Start with **Skill + CLI**. It's cheaper overall, zero-config to distribute, and steers the agent better on complex tasks. Use **MCP** for simple one-shot operations or non-Claude Code clients.

## Running the benchmark

```bash
cd benchmarks/token-efficiency
cp .env.example .env   # fill in credentials, model IDs, and channel
npm install
npm run benchmark
```

See [`.env.example`](.env.example) for all configuration options.

### Session modes

The benchmark supports two session modes controlled by `BENCHMARK_SESSION_MODE`:

- **`isolated`** (default) — Each scenario runs in a fresh session. Every scenario pays its own cache creation cost with no conversation history from previous scenarios.
- **`single`** — All scenarios run in one continuous session per config, chaining via the SDK's `resume` option. S1 starts fresh, then S2–S5 resume the same session. Each scenario's metrics are reported individually but include the cost of re-sending prior conversation history as cached context.

```bash
# Isolated sessions (default)
npm run benchmark

# Single continuous session
BENCHMARK_SESSION_MODE=single npm run benchmark
```

### Other overrides

```bash
# Run only S1 with skill config
BENCHMARK_SCENARIO=s1-list-read BENCHMARK_CONFIG=skill npm run benchmark

# Verbose output showing every tool call
VERBOSE=1 npm run benchmark
```

Results are saved as JSON in `results/` with timestamps.
