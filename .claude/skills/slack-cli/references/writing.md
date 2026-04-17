# Writing Data

Commands for posting messages, reactions, and user groups.

## conversations-add-message

Post a message.

```bash
slack-cli conversations-add-message --channel-id <id> [--text <text>] [--thread-ts <ts>] [--content-type <type>]
```

- `--content-type`: `text/markdown` (default) or `text/plain`
- `--thread-ts`: reply to a thread instead of posting top-level

```bash
# Top-level message
slack-cli conversations-add-message --channel-id '#my-channel' --text "Hello"

# Thread reply
slack-cli conversations-add-message --channel-id '#my-channel' --thread-ts 1234567890.123456 --text "Thread reply"
```

### Formatting (Slack mrkdwn)

Pass Slack mrkdwn in `--text`. Inline tokens work on one line; block-level tokens must sit on their own lines.

| Token | Works | Notes |
|-------|-------|-------|
| `*bold*` `_italic_` `~strike~` `` `code` `` | inline | Slack mrkdwn only — not `**bold**` / `[text](url)` |
| `<@U0123ABCD>` | inline | User mention. Get the ID from `users-search`. |
| `<#C0123ABCD>` | inline | Channel mention. |
| `<https://example.com\|label>` | inline | Link with label. Pipe-separated. |
| `:rocket:` | inline | Emoji shortcode. |
| `> quote` | block | Must be on its own line. |
| ` ``` ... ``` ` | block | Fenced code — opening fence, content, closing fence each on their own line. |
| `- item` / `* item` | block | Bullet list — each item on its own line. |

Use `\n` in `--text` (or a heredoc) to insert real newlines for block-level tokens.

**CSV echo lies.** The `-o raw` response from `conversations-add-message` and the `Text` column from `conversations-history` both pass the stored text through a CSV representation that swaps `*bold*` → `_bold_`, drops `<@UID>` angle brackets, and strips `<url|label>` link syntax. That's a display artifact — the actual Slack message renders correctly. Trust the Slack UI, not the CSV.

## reactions-add

Add an emoji reaction to a message.
```bash
slack-cli reactions-add --channel-id <id> --timestamp <ts> --emoji <emoji>
```

`--emoji`: emoji name without colons (e.g. `thumbsup`, `rocket`, `white_check_mark`).

```bash
slack-cli reactions-add --channel-id '#general' --timestamp 1234567890.123456 --emoji thumbsup
```

## reactions-remove

Remove an emoji reaction from a message.
```bash
slack-cli reactions-remove --channel-id <id> --timestamp <ts> --emoji <emoji>
```

```bash
slack-cli reactions-remove --channel-id '#general' --timestamp 1234567890.123456 --emoji thumbsup
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
