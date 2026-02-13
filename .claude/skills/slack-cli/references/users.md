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
slack-cli usergroups-list [--include-users true] [--include-count true] [--include-disabled true]
```

```bash
slack-cli usergroups-list
slack-cli usergroups-list --include-users true --include-disabled true
```

Output columns: `id,name,handle,description,user_count,is_external,date_create,date_update`

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
