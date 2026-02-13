---
name: slack-cli
description: Use this skill when the user wants to interact with Slack from the command line. Covers listing channels, reading messages, reading threads, searching messages, and posting messages using the slack-cli binary. Trigger when the user mentions Slack channels, Slack messages, Slack threads, or wants to search/post in Slack.
---

# Slack CLI

Run Slack operations from the terminal using `slack-cli` — a portable, zero-dependency binary. No runtime needed. Requires `SLACK_MCP_XOXP_TOKEN` set in the environment.

## Before Any Command — Preflight Checks (MANDATORY)

**You MUST run these checks before executing any `slack-cli` command.** Do not skip them.

### 1. Check slack-cli is installed

```bash
command -v slack-cli >/dev/null 2>&1 && echo "installed" || echo "not installed"
```

**If "not installed"**, STOP. Tell the user to install it first:

```bash
curl -fsSL https://raw.githubusercontent.com/CJHwong/mcporter-slack-cli/main/install.sh | sh
```

Or download a tarball from the [Releases page](https://github.com/CJHwong/mcporter-slack-cli/releases), extract, and add to PATH.

Re-check after they confirm installation, then continue to step 2.

### 2. Check Slack token is configured

```bash
[ -n "$SLACK_MCP_XOXP_TOKEN" ] && echo "configured" || echo "not set"
```

**If the output is "not set"**, STOP. Do not run any slack-cli command. Instead:

1. Tell the user: "Your Slack token is not configured. `slack-cli` requires a `SLACK_MCP_XOXP_TOKEN` environment variable."
2. Walk them through setup:
   - Go to [api.slack.com/apps](https://api.slack.com/apps) and create a Slack App (or use an existing one)
   - Add required OAuth scopes: `channels:read`, `channels:history`, `groups:read`, `groups:history`, `im:read`, `im:history`, `mpim:read`, `mpim:history`, `users:read`, `search:read`, `chat:write`
   - Install the app to their workspace
   - Copy the **User OAuth Token** (`xoxp-...`) from **OAuth & Permissions**
   - Export it: `export SLACK_MCP_XOXP_TOKEN="xoxp-..."` and add to shell profile (`~/.bashrc`, `~/.zshrc`)
3. Re-check the token after they confirm it's set, then proceed.

**If the user wants to post messages**, also verify:

```bash
[ -n "$SLACK_MCP_ADD_MESSAGE_TOOL" ] && echo "configured" || echo "not set"
```

If not set, tell the user to `export SLACK_MCP_ADD_MESSAGE_TOOL=true` before posting. The daemon auto-restarts when `SLACK_MCP_*` env vars change.

## Quick Reference

| Task | Command |
|------|---------|
| List channels | `slack-cli channels-list --channel-types public_channel` |
| Read messages | `slack-cli conversations-history --channel-id '#channel' --limit 7d` |
| Read thread | `slack-cli conversations-replies --channel-id '#channel' --thread-ts <ts> --limit 50` |
| Search | `slack-cli conversations-search-messages --search-query "text"` |
| Post message | `slack-cli conversations-add-message --channel-id '#channel' --text "text"` |

## Task Guides

### Reading Data
For channels, messages, threads, and search → see `references/reading.md`

### Writing Data
For posting messages, reactions, and user groups → see `references/writing.md`

### Managing Users
For searching users and user groups → see `references/users.md`

### Daemon & Advanced
For server management, pagination, output formats, and global flags → see `references/daemon.md`

## Output Formats

Default output is CSV. Only `-o raw` returns MCP JSON envelope. `-o json` and `-o markdown` produce identical CSV.

```bash
slack-cli channels-list --channel-types public_channel -o raw
```
