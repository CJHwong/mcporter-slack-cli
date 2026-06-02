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

Slack mrkdwn tokens:

| Token | Notes |
|-------|-------|
| `*bold*` `_italic_` `~strike~` `` `code` `` | Slack mrkdwn only — not `**bold**` / `[text](url)` |
| `<@U0123ABCD>` | User mention. Get the ID from `users-search`. |
| `<#C0123ABCD>` | Channel mention. |
| `<https://example.com\|label>` | Link with label. Pipe-separated. |
| `:rocket:` | Emoji shortcode. |
| `> quote` / ` ``` fence ``` ` / `- item` | Block-level — each on its own line, needs real newlines. |

**Neither `--content-type` reliably posts multi-line Slack mrkdwn — go direct to `chat.postMessage` instead (see below).** Verified behavior of `conversations-add-message`:

- `text/markdown` (default): runs a Markdown→Slack converter that **collapses every single `\n` into a space** (your whole message becomes one line), reinterprets `*x*` as italic → `_x_`, and HTML-escapes `<...>`. Unusable for multi-line.
- `text/plain`: preserves `\n`, but Slack does **not** parse mrkdwn — `*bold*` shows literal asterisks.

**Reliable multi-line rich text: bypass the CLI and call `chat.postMessage` directly.** Its `text` field renders mrkdwn (`mrkdwn:true` by default) and keeps newlines. Build the payload with `jq -Rs` so the file content is JSON-encoded (newlines → `\n`):

```bash
jq -Rs '{channel:"<CHANNEL_OR_DM_ID>", text:., unfurl_links:false}' message.txt \
  | curl -s -H "Authorization: Bearer $SLACK_MCP_XOXP_TOKEN" \
      -H "Content-Type: application/json" \
      -X POST "https://slack.com/api/chat.postMessage" -d @- \
  | jq -r 'if .ok then "ok \(.ts)" else .error end'
```

`message.txt` holds Slack mrkdwn with real newlines, `<@UID>` mentions, and `<url|label>` links — all render. Caveat: you must HTML-escape *literal* `<`/`>` yourself (`<repo>` → `&lt;repo&gt;`); leave mention/link `<...>` raw.

**Bold/italic boundary rule.** The closing `*` (or `_`) must be followed by whitespace, end-of-line, or ASCII punctuation. Glued to an opening paren it silently fails to render:

- `*Header*(...)` → **not bold** (closing `*` touches `(`)
- `*Header* (...)`, `*Header*,`, or `*Header*` at end of line → bold ✓

Same rule for CJK text. When in doubt, put the bolded span at the end of its line.

**CSV echo lies.** The `-o raw` response from `conversations-add-message` and the `Text` column from `conversations-history` both pass the stored text through a CSV representation that swaps `*bold*` → `_bold_`, drops `<@UID>` angle brackets, and strips `<url|label>` link syntax. To inspect what was actually stored, read the raw `text` field via `conversations.history` + `jq -r '.messages[0].text'` instead.

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
