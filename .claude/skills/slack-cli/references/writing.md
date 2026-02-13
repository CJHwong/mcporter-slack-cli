# Writing Data

Commands for posting messages, reactions, and user groups.

## conversations-add-message

Post a message. Requires `SLACK_MCP_ADD_MESSAGE_TOOL` env var to be set.

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

## reactions-add

Add an emoji reaction to a message. Requires `SLACK_MCP_REACTION_TOOL` env var.

```bash
slack-cli reactions-add --channel-id <id> --timestamp <ts> --emoji <emoji>
```

`--emoji`: emoji name without colons (e.g. `thumbsup`, `rocket`, `white_check_mark`).

```bash
slack-cli reactions-add --channel-id '#general' --timestamp 1234567890.123456 --emoji thumbsup
```

## reactions-remove

Remove an emoji reaction from a message. Requires `SLACK_MCP_REACTION_TOOL` env var.

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
