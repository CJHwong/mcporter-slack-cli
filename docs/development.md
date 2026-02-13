# Development

## Building from Source

### Regenerating the Bundle

The CLI bundle (`src/slack-cli-bundle.js`) is pre-generated and committed to the repo. It contains the embedded tool schemas from slack-mcp-server. You only need to regenerate it when the pinned upstream commit changes.

Requires: `bun`, `npx` (with mcporter), `go`, and a valid `SLACK_MCP_XOXP_TOKEN` (the server validates auth during introspection).

```bash
SLACK_MCP_XOXP_TOKEN="xoxp-..." ./generate.sh
git add src/slack-cli-bundle.js && git commit -m "chore: regenerate bundle"
```

### Compiling Binaries

Requires: `bun`, `go`

```bash
# Build for one platform
./build.sh darwin-arm64

# Build for all platforms (cross-compile via bun + go)
./build.sh all
```

Tarballs are written to `dist/`.

## Releasing a New Version

This project uses [CalVer](https://calver.org/) (`YYYY.M.patch`, e.g. `v2026.2.0`) and pins a specific commit from [korotovsky/slack-mcp-server](https://github.com/korotovsky/slack-mcp-server) via `SLACK_MCP_COMMIT` in `generate.sh` and `build.sh`.

### 1. Update the Commit Pin (if pulling upstream changes)

Find the desired commit on [korotovsky/slack-mcp-server](https://github.com/korotovsky/slack-mcp-server/commits/master) and update `SLACK_MCP_COMMIT` in both `generate.sh` and `build.sh`:

```bash
# In both generate.sh and build.sh, change:
SLACK_MCP_COMMIT="<new-commit-sha>"
```

Skip this step if you're releasing a CLI-only change (docs, wrapper, etc.).

### 2. Regenerate the Bundle (if upstream commit changed)

```bash
SLACK_MCP_XOXP_TOKEN="xoxp-..." ./generate.sh
```

### 3. Commit, Tag, and Push

```bash
git add -A && git commit -m "feat: bump upstream to <short-sha>, add new tools"
git tag v2026.2.0
git push origin main v2026.2.0
```

Pushing the tag triggers the [GitHub Actions release workflow](.github/workflows/release.yml), which builds Go + Bun binaries for all platforms and creates a GitHub Release with the tarballs attached.