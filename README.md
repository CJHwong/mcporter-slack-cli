# mcporter-slack-cli

A portable, zero-dependency Slack CLI. No Go, Node, Bun, or other runtime needed — just a single binary.

Built with [mcporter](https://github.com/steipete/mcporter) wrapping [korotovsky/slack-mcp-server](https://github.com/korotovsky/slack-mcp-server).

## Prerequisites

You need a **Slack User OAuth Token** (`xoxp-...`) before using the CLI. See the [Setup Guide](docs/setup.md) for instructions.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/CJHwong/mcporter-slack-cli/main/install.sh | sh
```

Or download a tarball from [Releases](https://github.com/CJHwong/mcporter-slack-cli/releases), extract, and add to your PATH.

## Quick Start

```bash
# List channels
slack-cli channels-list --channel-types public_channel

# Read recent messages
slack-cli conversations-history --channel-id '#general' --limit 1d

# Search messages
slack-cli conversations-search-messages --search-query "deploy"
```

## Available Commands

| Command                         | Description                                                |
| ------------------------------- | ---------------------------------------------------------- |
| `channels-list`                 | List channels (public, private, DM, group DM)              |
| `conversations-history`         | Get messages from a channel or DM                          |
| `conversations-replies`         | Get thread replies                                         |
| `conversations-search-messages` | Search messages with filters                               |
| `conversations-add-message`     | Post a message (requires `SLACK_MCP_ADD_MESSAGE_TOOL`)     |
| `users-search`                  | Search users by name, email, or display name               |
| `usergroups-list`               | List user groups (@-mention groups)                        |
| `usergroups-me`                 | List/join/leave user groups for current user               |
| `usergroups-create`             | Create a new user group                                    |
| `usergroups-update`             | Update user group metadata                                 |
| `usergroups-users-update`       | Replace all members of a user group                        |
| `reactions-add`                 | Add emoji reaction (requires `SLACK_MCP_REACTION_TOOL`)    |
| `reactions-remove`              | Remove emoji reaction (requires `SLACK_MCP_REACTION_TOOL`) |
| `attachment-get-data`           | Download attachment (requires `SLACK_MCP_ATTACHMENT_TOOL`) |

## How It Works

The CLI ships three files: `slack-cli` (wrapper), `slack-cli-bin` (compiled CLI), and `slack-mcp-server` (MCP server wrapping the Slack API). No external dependencies needed.

On your **first command**, the wrapper automatically starts `slack-mcp-server` as a background daemon in SSE mode on `localhost:13080`. It waits for the server to sync its cache (~1-10s depending on workspace size), then runs your command. **Subsequent commands** find the daemon already running and execute in ~1s.

The daemon **auto-shuts down after 30 minutes of inactivity** to avoid wasting memory (~28MB RSS). It restarts automatically on the next CLI call.

### Daemon Management

```bash
slack-cli server status    # check if daemon is running
slack-cli server stop      # stop the daemon manually
slack-cli server start     # pre-start the daemon (e.g. in shell profile)
```

## Claude Code Integration: Skill vs MCP

This CLI can be used with Claude Code in two ways:

- **Skill** — A Claude Code skill (`.claude/skills/slack-cli/SKILL.md`) that calls `slack-cli` via Bash. Zero setup for anyone who clones the repo.
- **MCP** — Connect Claude Code directly to the `slack-mcp-server` daemon via SSE. Structured tool calls with no shell layer.

Both use the same underlying server. MCP is more efficient for simple, isolated operations (fewer turns per task). Skill is cheaper for complex multi-step workflows and long-running sessions — the skill doc guides the agent and prevents over-exploration, while MCP's verbose tool responses accumulate into heavier context over time.

**Use Skill** for portability, complex tasks, and long sessions. **Use MCP** for simple one-shot operations or non-Claude Code clients. See [benchmarks/token-efficiency](benchmarks/token-efficiency/) for details.

## Documentation

- [Setup Guide](docs/setup.md) — Slack App configuration and environment variables
- [Usage Guide](docs/usage.md) — Flags, formats, and detailed examples
- [Development](docs/development.md) — Building from source and releasing

## License

MIT