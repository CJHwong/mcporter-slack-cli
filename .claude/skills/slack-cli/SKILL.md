---
name: slack-cli
description: Use this skill when the user wants to interact with Slack from the command line. Covers listing channels, reading messages, reading threads, searching messages, and posting messages using the slack-cli binary. Trigger when the user mentions Slack channels, Slack messages, Slack threads, or wants to search/post in Slack.
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
