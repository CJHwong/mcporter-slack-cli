# Slack App Setup

You need a **User OAuth Token** (`xoxp-...`) from a Slack App with the right scopes. Without it, the CLI cannot authenticate with Slack's API.

## Quick Setup via App Manifest

1. Go to [api.slack.com/apps](https://api.slack.com/apps)
2. Click **Create New App** → **From a manifest**
3. Select your workspace
4. Paste this manifest (switch to JSON tab):

```json
{
  "display_information": {
    "name": "Slack CLI"
  },
  "oauth_config": {
    "scopes": {
      "user": [
        "channels:history",
        "channels:read",
        "files:read",
        "groups:history",
        "groups:read",
        "im:history",
        "im:read",
        "im:write",
        "mpim:history",
        "mpim:read",
        "mpim:write",
        "reactions:write",
        "users:read",
        "chat:write",
        "search:read",
        "usergroups:read",
        "usergroups:write"
      ]
    }
  },
  "settings": {
    "org_deploy_enabled": false,
    "socket_mode_enabled": false,
    "token_rotation_enabled": false
  }
}
```

5. Click **Create**
6. In the sidebar, click **Install App** → **Install to Workspace** → **Allow**
7. Copy the **User OAuth Token** from **OAuth & Permissions**

## Set Your Token

```bash
export SLACK_MCP_XOXP_TOKEN="xoxp-your-token-here"
```

Add this to your shell profile (`~/.bashrc`, `~/.zshrc`, etc.) to persist it.

## Environment Variables

The CLI passes through all `SLACK_MCP_*` environment variables to the underlying server:

| Variable                     | Description                                                                           |
| ---------------------------- | ------------------------------------------------------------------------------------- |
| `SLACK_MCP_XOXP_TOKEN`       | **Required.** User OAuth token (`xoxp-...`)                                           |
| `SLACK_MCP_ADD_MESSAGE_TOOL` | Enable message posting (`true` or comma-separated channel IDs)                        |
| `SLACK_MCP_REACTION_TOOL`    | Enable reactions (`true` or comma-separated channel IDs)                              |
| `SLACK_MCP_ATTACHMENT_TOOL`  | Enable attachment downloads (`true` or comma-separated channel IDs)                   |
| `SLACK_MCP_LOG_LEVEL`        | Log level: `debug`, `info`, `warn`, `error` (default: `info`)                         |
| `SLACK_MCP_PROXY`            | Proxy URL for outgoing requests                                                       |
| `SLACK_CLI_WARMUP_TIMEOUT`   | Max seconds to wait for daemon startup (default: `60`)                                |
| `SLACK_CLI_IDLE_TIMEOUT`     | Seconds of inactivity before daemon auto-shuts down (default: `1800`, `0` to disable) |

See the [slack-mcp-server docs](https://github.com/korotovsky/slack-mcp-server#environment-variables-quick-reference) for the full list.

## Verifying It Works

```bash
slack-cli channels-list --channel-types public_channel
```

If configured correctly, this lists your public channels. If you see an authentication error, verify your token starts with `xoxp-` and has the required scopes.