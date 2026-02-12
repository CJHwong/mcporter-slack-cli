#!/usr/bin/env bash
set -euo pipefail

# generate.sh — Generate the slack-cli bundle via mcporter introspection
#
# This is a ONE-TIME script (or run when slack-mcp-server tools change).
# Requires a real SLACK_MCP_XOXP_TOKEN because the server validates auth on startup.
#
# Usage:
#   SLACK_MCP_XOXP_TOKEN="xoxp-..." ./generate.sh
#
# Output: src/slack-cli-bundle.js (committed to repo)
#
# Prerequisites: bun, npx (with mcporter), gh (GitHub CLI)

SLACK_MCP_REPO="korotovsky/slack-mcp-server"
SLACK_MCP_VERSION="v1.1.28"
MCPORTER_VERSION="0.7.3"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$SCRIPT_DIR/src"
BUNDLE_OUT="$SRC_DIR/slack-cli-bundle.js"
SSE_PORT=13080

die() { echo "ERROR: $*" >&2; exit 1; }

cleanup() {
  if [[ -n "${SERVER_PID:-}" ]]; then
    kill "$SERVER_PID" 2>/dev/null
    # Wait up to 5 seconds for graceful shutdown, then force kill
    for _i in 1 2 3 4 5; do
      kill -0 "$SERVER_PID" 2>/dev/null || break
      sleep 1
    done
    kill -9 "$SERVER_PID" 2>/dev/null
    wait "$SERVER_PID" 2>/dev/null
  fi
  if [[ -n "${WORK_DIR:-}" && -d "${WORK_DIR:-}" ]]; then
    rm -rf "$WORK_DIR"
  fi
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Validate
# ---------------------------------------------------------------------------

[[ -n "${SLACK_MCP_XOXP_TOKEN:-}" ]] || die "SLACK_MCP_XOXP_TOKEN is required. Set it to a valid xoxp-... token."
command -v bun >/dev/null 2>&1 || die "bun is required"
command -v npx >/dev/null 2>&1 || die "npx is required"
command -v gh  >/dev/null 2>&1 || die "gh is required"

# ---------------------------------------------------------------------------
# Detect host platform and download server binary
# ---------------------------------------------------------------------------

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"
case "$OS" in darwin) OS="darwin" ;; linux) OS="linux" ;; *) die "Unsupported OS" ;; esac
case "$ARCH" in x86_64|amd64) ARCH="amd64" ;; arm64|aarch64) ARCH="arm64" ;; *) die "Unsupported arch" ;; esac
HOST_PLATFORM="${OS}-${ARCH}"

WORK_DIR="$(mktemp -d)"
BIN_DIR="$WORK_DIR/bin"
mkdir -p "$BIN_DIR" "$SRC_DIR"

ASSET="slack-mcp-server-${HOST_PLATFORM}"
echo "==> Downloading $ASSET for introspection..."
gh release download "$SLACK_MCP_VERSION" \
  --repo "$SLACK_MCP_REPO" \
  --pattern "$ASSET" \
  --dir "$BIN_DIR" \
  --clobber
chmod +x "$BIN_DIR/$ASSET"
mv "$BIN_DIR/$ASSET" "$BIN_DIR/slack-mcp-server"

# ---------------------------------------------------------------------------
# Start server in SSE mode for introspection
# ---------------------------------------------------------------------------

echo "==> Starting slack-mcp-server in SSE mode for introspection..."
SERVER_LOG="$WORK_DIR/server.log"
"$BIN_DIR/slack-mcp-server" -transport sse > "$SERVER_LOG" 2>&1 &
SERVER_PID=$!

# Wait for server to be ready
for i in $(seq 1 60); do
  if grep -q "fully ready" "$SERVER_LOG" 2>/dev/null; then
    echo "    Server ready (${i}s)"
    break
  fi
  if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    echo "==> Server exited unexpectedly. Log:"
    cat "$SERVER_LOG"
    die "Server failed to start"
  fi
  sleep 1
done

grep -q "fully ready" "$SERVER_LOG" || die "Server did not become ready within 60s"

# ---------------------------------------------------------------------------
# Run mcporter to generate the bundle (connecting via SSE)
# ---------------------------------------------------------------------------

echo "==> Running mcporter generate-cli --bundle..."
echo "    (introspecting via http://127.0.0.1:${SSE_PORT}/sse)"

(
  cd /tmp
  npx mcporter@"$MCPORTER_VERSION" generate-cli \
    --command "http://127.0.0.1:${SSE_PORT}/sse" \
    --name slack-cli \
    --runtime bun \
    --bundle "$BUNDLE_OUT"
)

[[ -f "$BUNDLE_OUT" ]] || die "Bundle generation failed"

echo ""
echo "==> Generated: $BUNDLE_OUT"
echo "    Commit this file to the repo."
echo ""
echo "    git add src/slack-cli-bundle.js && git commit -m 'chore: regenerate slack-cli bundle'"
