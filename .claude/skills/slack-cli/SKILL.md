---
name: slack-cli
description: >
  Use this skill for Slack operations: listing channels, reading messages/threads,
  searching, posting messages, adding/removing reactions, managing user groups,
  or downloading attachments via the slack-cli binary. Trigger when the user wants
  to perform an action in Slack — "post to #channel," "react with thumbsup,"
  "list channels," "who's in @backend," "download that file" — or retrieve raw
  Slack data. Do NOT use for answering questions about past Slack conversations
  (use gf-slack:slack-search instead).
---

# Slack CLI

Run Slack operations via `slack-cli`.

If any command fails (not found, auth error, etc.), see `references/troubleshooting.md`.

## Quick Reference

| Task | Command |
|------|---------|
| List channels | `slack-cli channels-list --channel-types public_channel` |
| Read messages | `slack-cli conversations-history --channel-id '#channel' --limit 7d` |
| Read thread | `slack-cli conversations-replies --channel-id '#channel' --thread-ts <ts> --limit 50` |
| Search | `slack-cli conversations-search-messages --search-query "text"` |
| Post message | `slack-cli conversations-add-message --channel-id '#channel' --text "text"` |
| React | `slack-cli reactions-add --channel-id <id> --timestamp <ts> --emoji thumbsup` |
| Download file | `slack-cli attachment-get-data --file-id <id> -o raw \| jq -r '.raw.content[0].text' \| base64 -d > out.bin` |

## Task Guides

### Reading Data
For channels, messages, threads, and search → see `references/reading.md`

### Writing Data
For posting messages, reactions, and user groups → see `references/writing.md`

### Managing Users
For searching users and user groups → see `references/users.md`

### Daemon & Advanced
For server management, pagination, output formats, and global flags → see `references/daemon.md`

## Gotchas

- `--limit` on `conversations-replies` silently drops replies older than the time range — only the parent message is guaranteed. Use a message count (e.g. `--limit 100`) to get the full thread.
- `usergroups-list --include-users true` is a no-op — the upstream CSV formatter drops the users array. To list group members, see `references/users.md` (direct Slack API call via `$SLACK_MCP_XOXP_TOKEN`).
- `usergroups-users-update` **replaces** the entire member list. Fetch current members via the API recipe in `references/users.md`, merge, then update.
- To find messages with file attachments, don't rely on `has:file` in search — it doesn't filter through the MCP layer. Scan `conversations-history` and look for rows where `FileCount > 0` / `AttachmentIDs` is non-empty.
- Attachment downloads only work for Slack-hosted files. External links (Google Docs, Dropbox) return 401 — use the URL from message output instead.
- `-o json` and `-o markdown` produce CSV identical to default. Only `-o raw` returns MCP JSON envelope.
