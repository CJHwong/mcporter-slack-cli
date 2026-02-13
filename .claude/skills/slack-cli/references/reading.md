# Reading Data

Commands for reading channels, messages, threads, and search.

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

Output columns: `MsgID,UserID,UserName,RealName,Channel,ThreadTs,Text,Time,Reactions,BotName,FileCount,AttachmentIDs,HasMedia,Cursor`

## conversations-replies

Read thread replies. Both `--channel-id` and `--thread-ts` are required.

```bash
slack-cli conversations-replies --channel-id <id> --thread-ts <ts> [--limit <limit>] [--cursor <cursor>]
```

`--thread-ts` is the `ThreadTs` or `MsgID` value from conversations-history output.

`--limit` accepts time ranges (`1d`, `7d`, `30d`, `1w`) or message counts (`3`, `50`). Default: `1d`. The parent message is always included regardless of limit, but replies older than the time range are silently excluded.

```bash
slack-cli conversations-replies --channel-id '#channel' --thread-ts 1234567890.123456 --limit 50
slack-cli conversations-replies --channel-id '#channel' --thread-ts 1234567890.123456 --limit 30d
```

Output columns: `MsgID,UserID,UserName,RealName,Channel,ThreadTs,Text,Time,Reactions,BotName,FileCount,AttachmentIDs,HasMedia,Cursor`

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
