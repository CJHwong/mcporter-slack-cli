# slack-cli Command Reference

## channels-list

List channels by type.

```bash
slack-cli channels-list --channel-types <types> [--limit <n>] [--sort popularity] [--cursor <cursor>]
```

`--channel-types` (required): comma-separated. Values: `public_channel`, `private_channel`, `im`, `mpim`.

```bash
slack-cli channels-list --channel-types public_channel
slack-cli channels-list --channel-types "public_channel,private_channel"
slack-cli channels-list --channel-types im    # DMs
slack-cli channels-list --channel-types mpim  # group DMs
```

Output columns: `ID,Name,Topic,Purpose,MemberCount,Cursor`

## conversations-history

Read messages from a channel or DM.

```bash
slack-cli conversations-history --channel-id <id> [--limit <limit>] [--cursor <cursor>] [--include-activity-messages true]
```

`--channel-id` formats: `#channel-name`, `C0123456789`, `D0123456789`, `@username`

`--limit` accepts time ranges (`1d`, `7d`, `30d`, `1w`) or message counts (`3`, `50`). Default: `1d`.

```bash
slack-cli conversations-history --channel-id '#general' --limit 7d
slack-cli conversations-history --channel-id C0123456789 --limit 50
slack-cli conversations-history --channel-id '@john.doe' --limit 1d
```

Output columns: `MsgID,UserID,UserName,RealName,Channel,ThreadTs,Text,Time,Reactions,Cursor`

## conversations-replies

Read thread replies. Both `--channel-id` and `--thread-ts` are required.

```bash
slack-cli conversations-replies --channel-id <id> --thread-ts <ts> [--limit <limit>] [--cursor <cursor>]
```

`--thread-ts` is the `ThreadTs` or `MsgID` value from conversations-history output.

`--limit` accepts time ranges (`1d`, `7d`, `30d`, `1w`) or message counts (`3`, `50`). Default: `1d`. The parent message is always included regardless of limit, but replies older than the time range are silently excluded.

## conversations-search-messages

Search messages. Either `--search-query` or at least one filter is required.

```bash
slack-cli conversations-search-messages [--search-query <q>] [filters...] [--limit <n>] [--cursor <cursor>]
```

Filters:
- `--filter-in-channel '#name'` or `C...` ID
- `--filter-in-im-or-mpim '@user'` or `D...` ID
- `--filter-users-from '@user'` or `U...` ID
- `--filter-users-with '@user'` or `U...` ID
- `--filter-date-after 'YYYY-MM-DD'`
- `--filter-date-before 'YYYY-MM-DD'`
- `--filter-date-on 'YYYY-MM-DD'`
- `--filter-date-during 'Yesterday'` or `'Today'` (month names don't work)
- `--filter-threads-only true`

`--limit`: 1-100, default 20.

```bash
slack-cli conversations-search-messages --search-query "deploy issue"
slack-cli conversations-search-messages --filter-users-from '@hoss' --filter-date-after '2026-01-01'
slack-cli conversations-search-messages --search-query "bug" --filter-in-channel '#engineering'
```

Note: `slack-cli --help` truncates the flag list for this command.

## conversations-add-message

Post a message. Requires `SLACK_MCP_ADD_MESSAGE_TOOL` env var to be set.

```bash
slack-cli conversations-add-message --channel-id <id> [--payload <text>] [--thread-ts <ts>] [--content-type <type>]
```

- `--content-type`: `text/markdown` (default) or `text/plain`
- `--thread-ts`: reply to a thread instead of posting top-level

```bash
slack-cli conversations-add-message --channel-id '#my-channel' --payload "Hello"
slack-cli conversations-add-message --channel-id '#my-channel' --thread-ts 1234567890.123456 --payload "Thread reply"
```

## users-search

Search users by name, email, or display name.

```bash
slack-cli users-search --pattern <query>
```

```bash
slack-cli users-search --pattern "john"
slack-cli users-search --pattern "john.doe@company.com"
```

## usergroups-list

List all user groups (@-mention groups like @engineering).

```bash
slack-cli usergroups-list [--include-users true] [--include-count true] [--include-disabled true]
```

```bash
slack-cli usergroups-list
slack-cli usergroups-list --include-users true --include-disabled true
```

## usergroups-me

List, join, or leave user groups for the current user.

```bash
slack-cli usergroups-me --action <list|join|leave> [--usergroup-id <id>]
```

- `--action list`: list groups you belong to (no `--usergroup-id` needed)
- `--action join`: join a group (requires `--usergroup-id`)
- `--action leave`: leave a group (requires `--usergroup-id`)

```bash
slack-cli usergroups-me --action list
slack-cli usergroups-me --action join --usergroup-id S0123456789
```

## usergroups-create

Create a new user group. Requires `usergroups:write` scope.

```bash
slack-cli usergroups-create --name <name> --handle <handle> [--description <desc>] [--channels <channel-ids>]
```

```bash
slack-cli usergroups-create --name "Backend Team" --handle "backend"
```

## usergroups-update

Update user group metadata (name, handle, description). Requires `usergroups:write` scope.

```bash
slack-cli usergroups-update --usergroup-id <id> [--name <name>] [--handle <handle>] [--description <desc>] [--channels <channel-ids>]
```

At least one field besides `--usergroup-id` is required.

## usergroups-users-update

Replace all members of a user group. **Warning: completely replaces the member list.** Requires `usergroups:write` scope.

```bash
slack-cli usergroups-users-update --usergroup-id <id> --users <user-ids>
```

`--users`: comma-separated user IDs.

## reactions-add

Add an emoji reaction to a message. Requires `SLACK_MCP_REACTION_TOOL` env var.

```bash
slack-cli reactions-add --channel-id <id> --timestamp <ts> --reaction <emoji>
```

`--reaction`: emoji name without colons (e.g. `thumbsup`, `rocket`, `white_check_mark`).

```bash
slack-cli reactions-add --channel-id '#general' --timestamp 1234567890.123456 --reaction thumbsup
```

## reactions-remove

Remove an emoji reaction from a message. Requires `SLACK_MCP_REACTION_TOOL` env var.

```bash
slack-cli reactions-remove --channel-id <id> --timestamp <ts> --reaction <emoji>
```

```bash
slack-cli reactions-remove --channel-id '#general' --timestamp 1234567890.123456 --reaction thumbsup
```

## attachment-get-data

Download attachment content by file ID. Requires `SLACK_MCP_ATTACHMENT_TOOL` env var. 5MB file size limit. Text files return content as-is; binary files return base64.

```bash
slack-cli attachment-get-data --file-id <id>
```

```bash
slack-cli attachment-get-data --file-id F0123456789
```

## Global Flags

- `-o raw`: raw MCP JSON envelope (only format that differs from default CSV)
- `-t, --timeout <ms>`: call timeout (default: 30000)

Note: `-o json` and `-o markdown` produce the same CSV as default `-o text`.

## Pagination

All list/search commands support cursor-based pagination. The last row's `Cursor` column contains the next page token.

```bash
slack-cli channels-list --channel-types public_channel --limit 10
# ... output includes Cursor value ...
slack-cli channels-list --channel-types public_channel --limit 10 --cursor '<cursor-value>'
```

## Daemon Management

```bash
slack-cli server status   # check if running
slack-cli server stop     # manual stop
slack-cli server start    # pre-start
```

The daemon auto-starts on first command and auto-shuts down after 30 minutes of inactivity. Environment variable changes (`SLACK_MCP_*`) trigger automatic daemon restart.
