# mcporter-slack-cli

A portable, zero-dependency Slack CLI. No Go, Node, Bun, or other runtime needed — just a single binary.

Built with [mcporter](https://github.com/steipete/mcporter) wrapping [korotovsky/slack-mcp-server](https://github.com/korotovsky/slack-mcp-server).

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/CJHwong/mcporter-slack-cli/main/install.sh | sh
```

Or download a tarball from [Releases](https://github.com/CJHwong/mcporter-slack-cli/releases), extract, and add to your PATH.

## Slack App Setup (one-time)

You need a **User OAuth Token** (`xoxp-...`) from a Slack App with the right scopes.

### Quick setup via App Manifest

1. Go to [api.slack.com/apps](https://api.slack.com/apps)
2. Click **Create New App** → **From a manifest**
3. Select your workspace
4. Paste this manifest (switch to JSON tab):

```json
{
  "display_information": {
    "name": "Slack CLI"
  },
  "oauth_config": {
    "scopes": {
      "user": [
        "channels:history",
        "channels:read",
        "groups:history",
        "groups:read",
        "im:history",
        "im:read",
        "im:write",
        "mpim:history",
        "mpim:read",
        "mpim:write",
        "users:read",
        "chat:write",
        "search:read",
        "usergroups:read",
        "usergroups:write"
      ]
    }
  },
  "settings": {
    "org_deploy_enabled": false,
    "socket_mode_enabled": false,
    "token_rotation_enabled": false
  }
}
```

5. Click **Create** to create the app
6. In the app sidebar, click **Install App** → **Install to Workspace** → **Allow**
7. Copy the **User OAuth Token** from the **OAuth & Permissions** page

### Set your token

```bash
export SLACK_MCP_XOXP_TOKEN="xoxp-your-token-here"
```

Add this to your shell profile (`~/.bashrc`, `~/.zshrc`, etc.) to persist it.

## Usage

```bash
# List public channels (find channel IDs and names here)
slack-cli channels-list --channel-types public_channel

# List multiple channel types at once
slack-cli channels-list --channel-types "public_channel,private_channel"

# List DMs and group DMs
slack-cli channels-list --channel-types im
slack-cli channels-list --channel-types mpim

# Read recent messages — by channel name, channel ID, or DM
slack-cli conversations-history --channel-id '#my-channel' --limit 7d
slack-cli conversations-history --channel-id C0123456789 --limit 3
slack-cli conversations-history --channel-id '@username' --limit 1d

# Read a thread (thread-ts comes from conversations-history output)
slack-cli conversations-replies --channel-id '#my-channel' --thread-ts 1234567890.123456 --limit 50

# Search messages
slack-cli conversations-search-messages --search-query "deploy issue"
slack-cli conversations-search-messages --search-query "bug" --filter-in-channel '#my-channel'
slack-cli conversations-search-messages --filter-users-from '@hoss' --filter-date-after '2026-01-01'

# Post a message (requires SLACK_MCP_ADD_MESSAGE_TOOL=true)
slack-cli conversations-add-message --channel-id '#my-channel' --payload "Hello from CLI"

# Reply to a thread (thread-ts from conversations-history output)
slack-cli conversations-add-message --channel-id '#my-channel' --thread-ts 1234567890.123456 --payload "Thread reply"

# Paginate results using the Cursor column from previous output
slack-cli channels-list --channel-types public_channel --limit 10 --cursor 'abc123def456'

# Get raw MCP JSON envelope
slack-cli channels-list --channel-types public_channel -o raw

# See all available commands
slack-cli --help
```

### Channel ID formats

The `--channel-id` flag accepts multiple formats:

| Format  | Example       | Description                               |
| ------- | ------------- | ----------------------------------------- |
| `#name` | `#general`    | Channel by name (must exist in workspace) |
| `C...`  | `C0123456789` | Public/private channel by ID              |
| `D...`  | `D0123456789` | DM by channel ID                          |
| `@user` | `@john.doe`   | DM by username                            |

Use `channels-list` to find channel IDs and names.

### The `--limit` flag

For `conversations-history` and `conversations-replies`, `--limit` accepts two formats:

- **Time range**: `1d` (1 day), `7d` (7 days), `30d` (30 days), `1w` (1 week)
- **Message count**: `3`, `50`, `100`

Default: `1d`. For threads, this means replies older than 24 hours are silently excluded (the parent message is always included). Use a larger limit for older threads.

### Search filters

`conversations-search-messages` supports many filters beyond `--search-query`. Note: `slack-cli --help` truncates the flag list for this command — the full set is documented here.

| Flag                     | Description                                                                                                   |
| ------------------------ | ------------------------------------------------------------------------------------------------------------- |
| `--search-query`         | Text query or full Slack message URL                                                                          |
| `--filter-in-channel`    | Filter to a channel (`#name` or `C...` ID)                                                                    |
| `--filter-in-im-or-mpim` | Filter to a DM (`@user` or `D...` ID)                                                                         |
| `--filter-users-from`    | Messages sent by a user (`@user` or `U...` ID)                                                                |
| `--filter-users-with`    | Messages in threads/DMs with a user                                                                           |
| `--filter-date-after`    | Messages after date (`YYYY-MM-DD`)                                                                            |
| `--filter-date-before`   | Messages before date (`YYYY-MM-DD`)                                                                           |
| `--filter-date-on`       | Messages on exact date (`YYYY-MM-DD`)                                                                         |
| `--filter-date-during`   | Messages during a period (`Yesterday`, `Today` only — month names like `July` don't work despite server docs) |
| `--filter-threads-only`  | Only thread messages (`true`/`false`)                                                                         |
| `--limit`                | Max results, 1–100 (default: 20)                                                                              |

Either `--search-query` or at least one filter is required.

### Output and global flags

| Flag                 | Description                                                       |
| -------------------- | ----------------------------------------------------------------- |
| `-o raw`             | Raw MCP JSON envelope (the only format that differs from default) |
| `-t, --timeout <ms>` | Call timeout in milliseconds (default: 30000)                     |

> **Note:** `-o json` and `-o markdown` currently produce the same CSV output as the default `-o text`, because the MCP server returns pre-formatted text. Use `-o raw` if you need structured JSON.

## Available Commands

| Command                         | Description                                            |
| ------------------------------- | ------------------------------------------------------ |
| `channels-list`                 | List channels (public, private, DM, group DM)          |
| `conversations-history`         | Get messages from a channel or DM                      |
| `conversations-replies`         | Get thread replies                                     |
| `conversations-search-messages` | Search messages with filters                           |
| `conversations-add-message`     | Post a message (requires `SLACK_MCP_ADD_MESSAGE_TOOL`) |

More tools (users_search, usergroups, reactions) will be available when [slack-mcp-server](https://github.com/korotovsky/slack-mcp-server) releases them. Run `generate.sh` to pick up new tools.

## How It Works

The CLI ships three files: `slack-cli` (wrapper), `slack-cli-bin` (compiled CLI), and `slack-mcp-server` (MCP server wrapping the Slack API). No external dependencies needed.

On your **first command**, the wrapper automatically starts `slack-mcp-server` as a background daemon in SSE mode on `localhost:13080`. It waits for the server to sync its cache (~1-10s depending on workspace size), then runs your command. **Subsequent commands** find the daemon already running and execute in ~1s.

The daemon **auto-shuts down after 30 minutes of inactivity** to avoid wasting memory (~28MB RSS). It restarts automatically on the next CLI call.

### Daemon management

```bash
slack-cli server status    # check if daemon is running
slack-cli server stop      # stop the daemon manually
slack-cli server start     # pre-start the daemon (e.g. in shell profile)
```

## Environment Variables

The CLI passes through all `SLACK_MCP_*` environment variables to the underlying server:

| Variable                     | Description                                                                           |
| ---------------------------- | ------------------------------------------------------------------------------------- |
| `SLACK_MCP_XOXP_TOKEN`       | **Required.** User OAuth token (`xoxp-...`)                                           |
| `SLACK_MCP_ADD_MESSAGE_TOOL` | Enable message posting (`true` or comma-separated channel IDs)                        |
| `SLACK_MCP_LOG_LEVEL`        | Log level: `debug`, `info`, `warn`, `error` (default: `info`)                         |
| `SLACK_MCP_PROXY`            | Proxy URL for outgoing requests                                                       |
| `SLACK_CLI_WARMUP_TIMEOUT`   | Max seconds to wait for daemon startup (default: `60`)                                |
| `SLACK_CLI_IDLE_TIMEOUT`     | Seconds of inactivity before daemon auto-shuts down (default: `1800`, `0` to disable) |

See the [slack-mcp-server docs](https://github.com/korotovsky/slack-mcp-server#environment-variables-quick-reference) for the full list.

## Building from Source

### Regenerating the bundle

The CLI bundle (`src/slack-cli-bundle.js`) is pre-generated and committed to the repo. It contains the embedded tool schemas from slack-mcp-server. You only need to regenerate it when slack-mcp-server adds/changes tools.

Requires: `bun`, `npx` (with mcporter), `gh`, and a valid `SLACK_MCP_XOXP_TOKEN` (the server validates auth during introspection).

```bash
SLACK_MCP_XOXP_TOKEN="xoxp-..." ./generate.sh
git add src/slack-cli-bundle.js && git commit -m "chore: regenerate bundle"
```

### Compiling binaries

Requires: `bun`, `gh`

```bash
# Build for one platform
./build.sh darwin-arm64

# Build for all platforms (cross-compile via bun)
./build.sh all
```

Tarballs are written to `dist/`.

## Releasing a New Version

This project's version tracks [korotovsky/slack-mcp-server](https://github.com/korotovsky/slack-mcp-server) releases. To release a new version:

### 1. Update the version pin

Edit `SLACK_MCP_VERSION` in both `generate.sh` and `build.sh` to the new version:

```bash
# In both generate.sh and build.sh, change:
SLACK_MCP_VERSION="v1.1.29"  # ← new version
```

### 2. Regenerate the bundle (if tools changed)

If the new slack-mcp-server version adds or modifies tools, regenerate the CLI bundle:

```bash
SLACK_MCP_XOXP_TOKEN="xoxp-..." ./generate.sh
```

Skip this step if the release is only bug fixes with no tool schema changes.

### 3. Commit, tag, and push

```bash
git add -A && git commit -m "chore: bump slack-mcp-server to v1.1.29"
git tag v1.1.29
git push origin main v1.1.29
```

Pushing the tag triggers the [GitHub Actions release workflow](.github/workflows/release.yml), which cross-compiles binaries for all platforms and creates a GitHub Release with the tarballs attached.

## License

MIT
