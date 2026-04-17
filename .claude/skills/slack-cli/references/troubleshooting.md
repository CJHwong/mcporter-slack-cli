# Troubleshooting

Consult this guide when a `slack-cli` command fails.

## "command not found"

`slack-cli` is not installed or not in PATH.

Install:

```bash
curl -fsSL https://raw.githubusercontent.com/CJHwong/mcporter-slack-cli/main/install.sh | sh
```

Or download a tarball from the [Releases page](https://github.com/CJHwong/mcporter-slack-cli/releases), extract, and add to PATH.

Verify after install:

```bash
command -v slack-cli >/dev/null 2>&1 && echo "installed" || echo "not installed"
```

## Auth / token errors

`slack-cli` requires a `SLACK_MCP_XOXP_TOKEN` environment variable.

Check:

```bash
[ -n "$SLACK_MCP_XOXP_TOKEN" ] && echo "configured" || echo "not set"
```

If not set, walk the user through setup:

1. Go to [api.slack.com/apps](https://api.slack.com/apps) and create a Slack App (or use an existing one)
2. Add required OAuth scopes: `channels:read`, `channels:history`, `groups:read`, `groups:history`, `im:read`, `im:history`, `mpim:read`, `mpim:history`, `users:read`, `search:read`, `chat:write`
3. Install the app to their workspace
4. Copy the **User OAuth Token** (`xoxp-...`) from **OAuth & Permissions**
5. Export it: `export SLACK_MCP_XOXP_TOKEN="xoxp-..."` and add to shell profile (`~/.bashrc`, `~/.zshrc`)

The daemon auto-restarts when `SLACK_MCP_*` env vars change.

## Write tools

`conversations-add-message`, `reactions-add/remove`, and `attachment-get-data` are enabled by default — the wrapper exports `SLACK_MCP_ADD_MESSAGE_TOOL`, `SLACK_MCP_REACTION_TOOL`, and `SLACK_MCP_ATTACHMENT_TOOL` to `true` on invocation if they're unset. To disable one, set it explicitly to a non-true value before calling `slack-cli`.

## Daemon issues

```bash
slack-cli server status   # check daemon
slack-cli server stop     # stop and let it auto-restart on next command
```
