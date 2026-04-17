# Users

Commands for searching users and managing user groups.

## users-search

Search users by name, email, or display name.

```bash
slack-cli users-search --query <query>
```

```bash
slack-cli users-search --query "john"
slack-cli users-search --query "john.doe@company.com"
```

Output columns: `UserID,UserName,RealName,DisplayName,Email,Title,DMChannelID`

## usergroups-list

List all user groups (@-mention groups like @engineering).

```bash
slack-cli usergroups-list [--include-count true] [--include-disabled true]
```

```bash
slack-cli usergroups-list
slack-cli usergroups-list --include-disabled true
```

Output columns: `id,name,handle,description,user_count,is_external,date_create,date_update`

> `--include-users true` is accepted but is a no-op — the upstream MCP server's CSV marshaller drops the users array. To list members of a specific group, see the next section.

## Listing members of a user group

Not supported by `slack-cli` directly. Call the Slack Web API with the token already in your env:

```bash
# Step 1: get member user IDs
curl -sG https://slack.com/api/usergroups.users.list \
  -H "Authorization: Bearer $SLACK_MCP_XOXP_TOKEN" \
  --data-urlencode "usergroup=S04207PNJS0" | jq -r '.users[]'

# Step 2: resolve each ID to a name (repeat per user)
curl -sG https://slack.com/api/users.info \
  -H "Authorization: Bearer $SLACK_MCP_XOXP_TOKEN" \
  --data-urlencode "user=U02H1CAGLLC" | jq -r '.user | "\(.id)\t\(.profile.real_name)"'
```

`$SLACK_MCP_XOXP_TOKEN` is already exported when `slack-cli` works. Get the group ID from `slack-cli usergroups-list`.

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
slack-cli usergroups-me --action leave --usergroup-id S0123456789
```
