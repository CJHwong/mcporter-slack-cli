# Usage Guide

## Channel ID Formats

The `--channel-id` flag accepts multiple formats:

| Format  | Example       | Description                               |
| ------- | ------------- | ----------------------------------------- |
| `#name` | `#general`    | Channel by name (must exist in workspace) |
| `C...`  | `C0123456789` | Public/private channel by ID              |
| `D...`  | `D0123456789` | DM by channel ID                          |
| `@user` | `@john.doe`   | DM by username                            |

Use `channels-list` to find channel IDs and names.

## The `--limit` Flag

For `conversations-history` and `conversations-replies`, `--limit` accepts two formats:

- **Time range**: `1d` (1 day), `7d` (7 days), `30d` (30 days), `1w` (1 week)
- **Message count**: `3`, `50`, `100`

Default: `1d`. For threads, this means replies older than 24 hours are silently excluded (the parent message is always included). Use a larger limit for older threads.

## Search Filters

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

## Output and Global Flags

| Flag                 | Description                                                       |
| -------------------- | ----------------------------------------------------------------- |
| `-o raw`             | Raw MCP JSON envelope (the only format that differs from default) |
| `-t, --timeout <ms>` | Call timeout in milliseconds (default: 30000)                     |

> **Note:** `-o json` and `-o markdown` currently produce the same CSV output as the default `-o text`, because the MCP server returns pre-formatted text. Use `-o raw` if you need structured JSON.

## Examples

### Listing Channels

```bash
# List public channels (find channel IDs and names here)
slack-cli channels-list --channel-types public_channel

# List multiple channel types at once
slack-cli channels-list --channel-types "public_channel,private_channel"

# List DMs and group DMs
slack-cli channels-list --channel-types im
slack-cli channels-list --channel-types mpim
```

### Reading Messages

```bash
# Read recent messages — by channel name, channel ID, or DM
slack-cli conversations-history --channel-id '#my-channel' --limit 7d
slack-cli conversations-history --channel-id C0123456789 --limit 3
slack-cli conversations-history --channel-id '@username' --limit 1d

# Read a thread (thread-ts comes from conversations-history output)
slack-cli conversations-replies --channel-id '#my-channel' --thread-ts 1234567890.123456 --limit 50
```

### Searching

```bash
# Search messages
slack-cli conversations-search-messages --search-query "deploy issue"
slack-cli conversations-search-messages --search-query "bug" --filter-in-channel '#my-channel'
slack-cli conversations-search-messages --filter-users-from '@hoss' --filter-date-after '2026-01-01'

# Search users by name, email, or display name
slack-cli users-search --query "john"
```

### User Groups

```bash
# List user groups (@-mention groups like @engineering)
slack-cli usergroups-list
```

### Posting Messages

> **Note:** Requires `SLACK_MCP_ADD_MESSAGE_TOOL=true`

```bash
# Post a message
slack-cli conversations-add-message --channel-id '#my-channel' --text "Hello from CLI"

# Reply to a thread (thread-ts from conversations-history output)
slack-cli conversations-add-message --channel-id '#my-channel' --thread-ts 1234567890.123456 --text "Thread reply"
```

### Reactions

> **Note:** Requires `SLACK_MCP_REACTION_TOOL=true`

```bash
# Add a reaction to a message
slack-cli reactions-add --channel-id '#my-channel' --timestamp 1234567890.123456 --emoji thumbsup
```

### Attachments

> **Note:** Requires `SLACK_MCP_ATTACHMENT_TOOL=true`

```bash
# Download an attachment
slack-cli attachment-get-data --file-id F0123456789
```

Only works with files uploaded directly to Slack. Externally hosted files (Google Docs, Dropbox, OneDrive, etc.) shared as links will return a 401 error. Access those via the link in `conversations-history` output instead.

### Pagination

```bash
# Paginate results using the Cursor column from previous output
slack-cli channels-list --channel-types public_channel --limit 10 --cursor 'abc123def456'

# Get raw MCP JSON envelope
slack-cli channels-list --channel-types public_channel -o raw
```