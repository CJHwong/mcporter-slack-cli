---
name: slack-cli
description: Use this skill when the user wants to interact with Slack from the command line. Covers listing channels, reading messages, reading threads, searching messages, and posting messages using the slack-cli binary. Trigger when the user mentions Slack channels, Slack messages, Slack threads, or wants to search/post in Slack.
---

# Slack CLI

## Overview

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
| Post message | `slack-cli conversations-add-message --channel-id '#channel' --payload "text"` |

## Listing Channels

Find channel IDs and names. `--channel-types` is required.

```bash
slack-cli channels-list --channel-types public_channel
slack-cli channels-list --channel-types "public_channel,private_channel"
slack-cli channels-list --channel-types im      # DMs
slack-cli channels-list --channel-types mpim    # group DMs
```

Channel type values: `public_channel`, `private_channel`, `im`, `mpim`. Comma-separate for multiple.

## Reading Messages

`--channel-id` accepts: `#channel-name`, `C0123456789`, `D0123456789`, `@username`.

`--limit` accepts time ranges (`1d`, `7d`, `30d`, `1w`) or message counts (`3`, `50`). Default: `1d`.

```bash
slack-cli conversations-history --channel-id '#general' --limit 7d
slack-cli conversations-history --channel-id C0123456789 --limit 50
slack-cli conversations-history --channel-id '@john.doe' --limit 1d
```

Output includes `MsgID`, `ThreadTs`, `UserName`, `Text`, `Time`, `Reactions`.

## Reading Threads

Both `--channel-id` and `--thread-ts` are required. Get `ThreadTs` from conversations-history output.

`--limit` accepts time ranges (`1d`, `7d`, `30d`, `1w`) or message counts (`3`, `50`). Default: `1d`. **Important:** the default `1d` only returns replies from the last 24 hours (the parent message is always included). For older threads, you must pass a larger limit or you'll silently miss replies.

```bash
slack-cli conversations-replies --channel-id '#channel' --thread-ts 1234567890.123456 --limit 50
slack-cli conversations-replies --channel-id '#channel' --thread-ts 1234567890.123456 --limit 30d
```

## Searching Messages

Either `--search-query` or at least one filter is required.

```bash
slack-cli conversations-search-messages --search-query "deploy issue"
slack-cli conversations-search-messages --search-query "bug" --filter-in-channel '#engineering'
slack-cli conversations-search-messages --filter-users-from '@hoss' --filter-date-after '2026-01-01'
```

Available filters: `--filter-in-channel`, `--filter-in-im-or-mpim`, `--filter-users-from`, `--filter-users-with`, `--filter-date-after`, `--filter-date-before`, `--filter-date-on`, `--filter-date-during`, `--filter-threads-only`.

**Caveat:** `--filter-date-during` only accepts `Yesterday` or `Today` — month names don't work despite server docs.

**Caveat:** `slack-cli --help` truncates the flag list for this command. See `references/commands.md` for the full set.

## Posting Messages

Requires `SLACK_MCP_ADD_MESSAGE_TOOL=true` (or comma-separated channel IDs). Daemon must be restarted after setting this.

```bash
# Top-level message
slack-cli conversations-add-message --channel-id '#my-channel' --payload "Hello"

# Thread reply (thread-ts from conversations-history output)
slack-cli conversations-add-message --channel-id '#my-channel' --thread-ts 1234567890.123456 --payload "Reply"
```

Content type defaults to `text/markdown`. Use `--content-type text/plain` for plain text.

## Pagination

All list/search commands support cursor-based pagination. The last row's `Cursor` column contains the next-page token.

```bash
slack-cli channels-list --channel-types public_channel --limit 10
# Use Cursor value from output:
slack-cli channels-list --channel-types public_channel --limit 10 --cursor '<cursor>'
```

## Daemon Management

```bash
slack-cli server status   # check if running
slack-cli server stop     # manual stop
slack-cli server start    # pre-start
```

Auto-starts on first command. Auto-shuts down after 30 minutes of inactivity. Auto-restarts when `SLACK_MCP_*` env vars change.

## Output Formats

Default output is CSV. Only `-o raw` differs (returns MCP JSON envelope). `-o json` and `-o markdown` produce identical CSV.

```bash
slack-cli channels-list --channel-types public_channel -o raw
```

## Resources

See `references/commands.md` for the complete command reference with all flags, output columns, and edge cases.
