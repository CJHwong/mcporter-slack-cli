# Benchmark Results

Tested with `us.anthropic.claude-sonnet-4-20250514-v1:0` on AWS Bedrock, 5 scenarios × 2 configs.

Both configs have identical tool access. The only difference is how Slack operations are invoked: Skill uses `slack-cli` via Bash, MCP uses structured tool calls via SSE.

## Summary

| Mode | Skill | MCP | Cost Δ | Turn Δ |
|---|---|---|---|---|
| Isolated | $0.76, 32 turns | $0.80, 26 turns | +4.1% | -18.8% |
| Single | $0.76, 21 turns | $1.01, 21 turns | +32.8% | +0% |

- **MCP wins on simple isolated tasks** (S1–S3, S5): -6% to -36% cost, -33% to -57% turns
- **Skill wins on complex research** (S4): MCP over-explores without skill doc guidance (+71% cost)
- **Single-session amplifies MCP's disadvantage**: MCP's verbose history inflates context; loses 4/5 scenarios

## Isolated mode

Each scenario runs as a fresh session with no shared conversation history.

| Scenario | Config | Cost | Turns | Input | Output | Cache Read | Cache Create | API Time |
|---|---|---|---|---|---|---|---|---|
| S1: List + Read | Skill | $0.272 | 5 | 18 | 889 | 36,903 | 37,188 | 48.1s |
| | MCP | $0.256 | 3 | 15 | 501 | 20,768 | 39,925 | 44.3s |
| | **Δ** | **-5.9%** | **-40%** | | | | | |
| S2: List + Read + Thread | Skill | $0.103 | 6 | 24 | 1,082 | 86,743 | 8,664 | 71.6s |
| | MCP | $0.068 | 4 | 16 | 945 | 58,171 | 4,157 | 50.0s |
| | **Δ** | **-33.8%** | **-33%** | | | | | |
| S3: Search + Thread | Skill | $0.148 | 7 | 30 | 1,322 | 120,035 | 15,746 | 92.6s |
| | MCP | $0.135 | 3 | 15 | 942 | 60,463 | 8,821 | 65.3s |
| | **Δ** | **-9.2%** | **-57%** | | | | | |
| S4: Full Research | Skill | $0.171 | 9 | 43 | 1,525 | 170,136 | 16,818 | 87.5s |
| | MCP | $0.292 | 13 | 74 | 4,758 | 301,663 | 17,715 | 175.3s |
| | **Δ** | **+70.8%** | **+44%** | | | | | |
| S5: Read + Write | Skill | $0.070 | 5 | 18 | 480 | 64,600 | 5,910 | 42.7s |
| | MCP | $0.045 | 3 | 15 | 418 | 55,582 | 1,376 | 32.4s |
| | **Δ** | **-36.1%** | **-40%** | | | | | |

**Totals:** Skill $0.76, 32 turns | MCP $0.80, 26 turns | **Δ +4.1% cost, -18.8% turns**

## Single-session mode

All 5 scenarios chain within one continuous session per config. S1 starts fresh, S2–S5 resume the same session. Each scenario's cost includes re-sending prior history as cached context.

| Scenario | Config | Cost | Turns | Input | Output | Cache Read | Cache Create | API Time |
|---|---|---|---|---|---|---|---|---|
| S1: List + Read | Skill | $0.270 | 5 | 18 | 682 | 36,885 | 37,047 | 47.1s |
| | MCP | $0.236 | 3 | 15 | 496 | 20,765 | 39,862 | 37.8s |
| | **Δ** | **-12.3%** | **-40%** | | | | | |
| S2: List + Read + Thread | Skill | $0.088 | 4 | 16 | 929 | 61,216 | 8,322 | 52.0s |
| | MCP | $0.143 | 4 | 16 | 743 | 65,071 | 7,590 | 82.1s |
| | **Δ** | **+62.0%** | **+0%** | | | | | |
| S3: Search + Thread | Skill | $0.115 | 4 | 21 | 863 | 99,429 | 13,479 | 52.2s |
| | MCP | $0.160 | 5 | 27 | 1,001 | 154,944 | 21,577 | 82.1s |
| | **Δ** | **+38.3%** | **+25%** | | | | | |
| S4: Full Research | Skill | $0.164 | 5 | 22 | 1,120 | 136,462 | 20,032 | 65.9s |
| | MCP | $0.264 | 6 | 28 | 1,213 | 241,373 | 38,995 | 68.2s |
| | **Δ** | **+61.6%** | **+20%** | | | | | |
| S5: Read + Write | Skill | $0.128 | 3 | 15 | 322 | 105,056 | 18,836 | 36.1s |
| | MCP | $0.212 | 3 | 15 | 374 | 143,747 | 39,533 | 35.1s |
| | **Δ** | **+65.9%** | **+0%** | | | | | |

**Totals:** Skill $0.76, 21 turns | MCP $1.01, 21 turns | **Δ +32.8% cost, +0% turns**

## Isolated vs single-session comparison

| Metric | Isolated | Single |
|---|---|---|
| Skill total cost | $0.76 | $0.76 |
| MCP total cost | $0.80 | $1.01 |
| Skill total turns | 32 | 21 |
| MCP total turns | 26 | 21 |

Single-session mode cuts turns for both configs, but MCP's cost increases 27% while Skill stays flat. MCP's verbose tool responses accumulate into heavier conversation history, inflating each subsequent turn's cache cost.

## Analysis

### MCP wins on simple isolated tasks

For fresh-session scenarios with 1–3 Slack operations (S1–S3, S5), MCP uses fewer turns (-33% to -57%) and costs less (-6% to -36%). The structured tool interface eliminates Bash overhead — no shell metadata, no CSV parsing, no stdout formatting.

### Skill wins on complex research (S4)

S4 asks the agent to list channels, search messages, and read the most relevant thread — a multi-step task requiring judgment. The MCP agent used 13 turns (vs skill's 9) and produced 4,758 output tokens (vs 1,525). Without a skill doc to guide strategy, it over-explored: more searches, more threads, more verbose output.

The skill's quick-reference table acts as implicit strategy guidance, steering the agent toward efficient tool sequences for multi-step workflows.

### Single-session erases MCP's turn advantage

In single-session mode, both configs converge to 21 turns. Skill benefits more from context reuse — it already has channel lists, search results, etc. from prior scenarios. MCP's heavier conversation history makes each turn more expensive. Compare S5:

| Mode | Config | Cost | Turns | Cache Read | Cache Create |
|---|---|---|---|---|---|
| Isolated | MCP | $0.045 | 3 | 55,582 | 1,376 |
| Single | MCP | $0.212 | 3 | 143,747 | 39,533 |

Same 3 turns, but single-session MCP re-sends 88K more cached tokens — the accumulated history from S1–S4. MCP's S5 cost jumps 4.7× while Skill's only jumps 1.8×.

### Cache economics

S1 always pays the cold-start cache creation cost:

- **Skill**: ~37K tokens (system prompt + skill doc + Bash schema)
- **MCP**: ~40K tokens (system prompt + MCP tool schemas + Bash schema)

After S1, cache read dominates. MCP's per-scenario advantage in isolated mode comes from fewer turns (fewer context re-sends). In single-session mode, this advantage disappears as accumulated history grows.

### Result quality

Both configs produced adequate summaries across all scenarios. S4 MCP was the weakest in isolated mode — it failed to locate the target channel despite it being in the prompt. All other scenarios had comparable quality.
