# Daemon & Advanced

Daemon management, pagination, output formats, and global flags.

## Daemon Management

The CLI runs a background MCP server daemon. Auto-starts on first command, auto-shuts down after 30 minutes of inactivity.

```bash
slack-cli server status   # check if daemon is running
slack-cli server stop     # stop daemon manually
slack-cli server start    # pre-start daemon (e.g. in shell profile)
```

Environment variable changes (`SLACK_MCP_*`) trigger automatic daemon restart.

## Pagination

All list/search commands support cursor-based pagination. The last row's `Cursor` column contains the next-page token.

```bash
slack-cli channels-list --channel-types public_channel --limit 10
# Use Cursor value from output:
slack-cli channels-list --channel-types public_channel --limit 10 --cursor '<cursor>'
```

## Output Formats

Default output is CSV. Only `-o raw` differs (returns MCP JSON envelope). `-o json` and `-o markdown` produce identical CSV.

```bash
slack-cli channels-list --channel-types public_channel -o raw    # MCP JSON envelope
slack-cli channels-list --channel-types public_channel -o text   # CSV (default)
slack-cli channels-list --channel-types public_channel -o json   # CSV (same as text)
slack-cli channels-list --channel-types public_channel -o markdown # CSV (same as text)
```

## Global Flags

| Flag | Description |
|------|-------------|
| `-o, --output` | Output format: `text` (default CSV), `json`, `markdown`, `raw` (MCP JSON) |
| `-t, --timeout` | Call timeout in ms (default: 30000) |

Note: `-o json`, `-o markdown`, and `-o text` all produce CSV output. Only `-o raw` returns the MCP JSON envelope.

## attachment-get-data

Download attachment content by file ID. Requires `SLACK_MCP_ATTACHMENT_TOOL` env var. 5MB file size limit.

```bash
slack-cli attachment-get-data --file-id <id>
```

Text files return content as-is; binary files return base64.

**Limitation:** Only works with files uploaded directly to Slack. Externally hosted files (Google Docs, Dropbox, OneDrive, etc.) shared as links will return a 401 error because they lack a Slack-hosted download URL. Use the link from `conversations-history` output to access those files directly instead.
