#!/usr/bin/env bash
set -euo pipefail

# build.sh — Compile the pre-generated slack-cli bundle for target platform(s)
#
# Usage:
#   ./build.sh <platform>         # build for one platform
#   ./build.sh all                # build for all platforms
#
# Platforms: darwin-arm64, darwin-amd64, linux-amd64, linux-arm64
#
# The bundle (src/slack-cli-bundle.js) must already exist.
# Run generate.sh first if it doesn't.
#
# Prerequisites: bun, go (Go compiler)

SLACK_MCP_REPO="korotovsky/slack-mcp-server"
SLACK_MCP_COMMIT="6ddc82863ab8b35b2ab73e9258083616532a973d"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DIST_DIR="$SCRIPT_DIR/dist"
BUNDLE="$SCRIPT_DIR/src/slack-cli-bundle.js"
ALL_PLATFORMS="darwin-arm64 darwin-amd64 linux-amd64 linux-arm64"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

die() { echo "ERROR: $*" >&2; exit 1; }

usage() {
  cat <<EOF
Usage: $0 <platform>
       $0 all

Platforms: $ALL_PLATFORMS

The bundle (src/slack-cli-bundle.js) must already exist.
Run generate.sh first if it doesn't.
EOF
  exit 1
}

# Map our platform names to bun's --target values
bun_target_for() {
  case "$1" in
    darwin-arm64) echo "bun-darwin-arm64"  ;;
    darwin-amd64) echo "bun-darwin-x64"    ;;
    linux-amd64)  echo "bun-linux-x64"     ;;
    linux-arm64)  echo "bun-linux-arm64"   ;;
    *)            die "No bun target for: $1" ;;
  esac
}

cleanup() {
  if [[ -n "${WORK_DIR:-}" && -d "${WORK_DIR:-}" ]]; then
    rm -rf "$WORK_DIR"
  fi
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Parse args
# ---------------------------------------------------------------------------

[[ $# -ge 1 ]] || usage
TARGET="$1"

if [[ "$TARGET" == "all" ]]; then
  PLATFORMS="$ALL_PLATFORMS"
else
  case "$TARGET" in
    darwin-arm64|darwin-amd64|linux-amd64|linux-arm64) ;;
    *) die "Unknown platform: $TARGET. Expected one of: $ALL_PLATFORMS" ;;
  esac
  PLATFORMS="$TARGET"
fi

# ---------------------------------------------------------------------------
# Validate
# ---------------------------------------------------------------------------

command -v bun >/dev/null 2>&1 || die "bun is required but not found in PATH"
command -v go  >/dev/null 2>&1 || die "go (Go compiler) is required but not found in PATH"
[[ -f "$BUNDLE" ]] || die "Bundle not found at $BUNDLE. Run generate.sh first."

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

WORK_DIR="$(mktemp -d)"
mkdir -p "$DIST_DIR"

echo "==> Cloning slack-mcp-server at $SLACK_MCP_COMMIT..."
REPO_DIR="$WORK_DIR/slack-mcp-server"
git clone --quiet --depth 1 https://github.com/$SLACK_MCP_REPO "$REPO_DIR"
(cd "$REPO_DIR" && git fetch --quiet --depth 1 origin "$SLACK_MCP_COMMIT" && git checkout --quiet "$SLACK_MCP_COMMIT")

echo "==> Bundle: $BUNDLE"
echo "==> Target(s): $PLATFORMS"
echo "    Work dir: $WORK_DIR"

# ---------------------------------------------------------------------------
# Build each platform
# ---------------------------------------------------------------------------

for PLATFORM in $PLATFORMS; do
  echo ""
  echo "==> Building slack-cli for $PLATFORM..."

  STAGE_DIR="$WORK_DIR/stage-${PLATFORM}"
  mkdir -p "$STAGE_DIR"

  # 1. Cross-compile slack-mcp-server for this platform
  GOOS="${PLATFORM%-*}"
  GOARCH="${PLATFORM#*-}"
  SERVER_BIN="$WORK_DIR/slack-mcp-server-${PLATFORM}"
  echo "    Building slack-mcp-server for $GOOS/$GOARCH..."
  (cd "$REPO_DIR" && CGO_ENABLED=0 GOOS="$GOOS" GOARCH="$GOARCH" go build -o "$SERVER_BIN" ./cmd/slack-mcp-server)
  chmod +x "$SERVER_BIN"

  # 2. Cross-compile the bundle
  BUN_TARGET="$(bun_target_for "$PLATFORM")"
  COMPILED="$WORK_DIR/slack-cli-bin-${PLATFORM}"
  echo "    Compiling for $BUN_TARGET..."
  bun build "$BUNDLE" --compile --target="$BUN_TARGET" --outfile "$COMPILED"
  chmod +x "$COMPILED"

  # 3. Create shell wrapper
  #    The CLI binary connects to slack-mcp-server via HTTP/SSE on localhost.
  #    The wrapper manages a background daemon: starts it if not running,
  #    waits for readiness, then runs the CLI binary.
  cat > "$STAGE_DIR/slack-cli" << 'WRAPPER_EOF'
#!/bin/sh
DIR="$(cd "$(dirname "$0")" && pwd)"
export PATH="$DIR:$PATH"

# NOTE: Fixed port. Only one slack-cli instance per machine is supported.
# If you need multi-user support, override SLACK_CLI_STATE_DIR per user and
# use separate port assignments (requires rebuilding slack-cli-bin).
SLACK_CLI_PORT=13080
STATE_DIR="${SLACK_CLI_STATE_DIR:-${HOME}/.slack-cli}"
PID_FILE="$STATE_DIR/server.pid"
LOG_FILE="$STATE_DIR/server.log"
ACTIVITY_FILE="$STATE_DIR/last-activity"
LOCK_DIR="$STATE_DIR/daemon.lock"
ENV_FILE="$STATE_DIR/server.env"
WARMUP_TIMEOUT="${SLACK_CLI_WARMUP_TIMEOUT:-60}"
IDLE_TIMEOUT="${SLACK_CLI_IDLE_TIMEOUT:-1800}"  # 30 minutes

# ---------------------------------------------------------------------------
# Helpers: PID validation
# ---------------------------------------------------------------------------

# Read and validate a PID file. Prints the PID if valid, returns 1 otherwise.
read_pid() {
  _pidfile="$1"
  [ -f "$_pidfile" ] || return 1
  _pid="$(cat "$_pidfile" 2>/dev/null)" || return 1
  # Validate PID is a non-empty integer
  case "$_pid" in
    ''|*[!0-9]*) rm -f "$_pidfile"; return 1 ;;
  esac
  echo "$_pid"
}

# Check if the daemon (slack-mcp-server) is running. Validates both PID
# existence and process identity to guard against PID reuse.
is_daemon_running() {
  _pid="$(read_pid "$PID_FILE")" || return 1
  kill -0 "$_pid" 2>/dev/null || { rm -f "$PID_FILE"; return 1; }
  # Verify the PID is actually slack-mcp-server (guards against PID reuse)
  if command -v ps >/dev/null 2>&1; then
    _comm="$(ps -p "$_pid" -o comm= 2>/dev/null)" || return 1
    case "$_comm" in
      *slack-mcp-serve*) return 0 ;;
      *) rm -f "$PID_FILE"; return 1 ;;
    esac
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Port conflict detection
# ---------------------------------------------------------------------------

check_port() {
  if is_daemon_running; then
    return 0
  fi
  blocker=""
  if command -v lsof >/dev/null 2>&1; then
    blocker="$(lsof -ti :"$SLACK_CLI_PORT" 2>/dev/null | head -1)"
  elif command -v ss >/dev/null 2>&1; then
    blocker="$(ss -tlnp "sport = :$SLACK_CLI_PORT" 2>/dev/null \
      | grep -o 'pid=[0-9]*' | head -1 | cut -d= -f2)"
  else
    return 0  # can't check — let the server fail naturally
  fi
  if [ -n "$blocker" ]; then
    echo "ERROR: Port $SLACK_CLI_PORT is already in use (PID $blocker)." >&2
    echo "       Stop the process using that port and try again." >&2
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Daemon lifecycle
# ---------------------------------------------------------------------------

acquire_lock() {
  if ! mkdir -p "$STATE_DIR" 2>/dev/null; then
    echo "ERROR: Cannot create state directory $STATE_DIR" >&2
    return 1
  fi
  # mkdir is atomic on POSIX — use as a lock
  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    # Another process holds the lock. Wait for it, then check daemon state.
    _wait=0
    while [ "$_wait" -lt 15 ]; do
      sleep 1
      _wait=$((_wait + 1))
      # Lock released or daemon now running — either way, we're good
      if ! [ -d "$LOCK_DIR" ] || is_daemon_running; then
        return 0
      fi
    done
    # Stale lock (holder crashed). Remove and retry once.
    rmdir "$LOCK_DIR" 2>/dev/null
    mkdir "$LOCK_DIR" 2>/dev/null || return 1
  fi
  return 0
}

release_lock() {
  rmdir "$LOCK_DIR" 2>/dev/null
}

start_daemon() {
  if is_daemon_running; then
    return 0
  fi

  acquire_lock || return 1

  # Re-check after acquiring lock (another process may have started it)
  if is_daemon_running; then
    release_lock
    return 0
  fi

  check_port || { release_lock; return 1; }

  echo "Starting slack-mcp-server daemon on port $SLACK_CLI_PORT..." >&2
  SLACK_MCP_PORT="$SLACK_CLI_PORT" "$DIR/slack-mcp-server" -transport sse > "$LOG_FILE" 2>&1 &
  _daemon_pid=$!
  if ! echo "$_daemon_pid" > "$PID_FILE"; then
    echo "ERROR: Failed to write PID file (disk full?)" >&2
    kill "$_daemon_pid" 2>/dev/null
    release_lock
    return 1
  fi

  elapsed=0
  while [ "$elapsed" -lt "$WARMUP_TIMEOUT" ]; do
    if grep -q "fully ready" "$LOG_FILE" 2>/dev/null; then
      echo "Server ready (${elapsed}s)" >&2
      snapshot_env
      start_watchdog
      release_lock
      return 0
    fi
    if ! is_daemon_running; then
      echo "ERROR: Server exited unexpectedly. Check $LOG_FILE" >&2
      rm -f "$PID_FILE"
      release_lock
      return 1
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done

  echo "ERROR: Server did not become ready within ${WARMUP_TIMEOUT}s" >&2
  stop_daemon
  release_lock
  return 1
}

stop_daemon() {
  # Kill watchdog first
  _wpid="$(read_pid "$STATE_DIR/watchdog.pid")"
  if [ -n "$_wpid" ]; then
    kill "$_wpid" 2>/dev/null
    rm -f "$STATE_DIR/watchdog.pid"
  fi

  _pid="$(read_pid "$PID_FILE")"
  if [ -n "$_pid" ]; then
    kill "$_pid" 2>/dev/null

    # Wait up to 10 seconds for graceful shutdown
    _wait=0
    while [ "$_wait" -lt 10 ]; do
      kill -0 "$_pid" 2>/dev/null || break
      sleep 1
      _wait=$((_wait + 1))
    done

    # Force kill if still running
    if kill -0 "$_pid" 2>/dev/null; then
      echo "Server did not stop gracefully, forcing..." >&2
      kill -9 "$_pid" 2>/dev/null
    fi

    rm -f "$PID_FILE" "$ENV_FILE"
    echo "Server stopped" >&2
  fi
}

# ---------------------------------------------------------------------------
# Idle watchdog: shuts down daemon after IDLE_TIMEOUT seconds of inactivity
# ---------------------------------------------------------------------------

start_watchdog() {
  [ "$IDLE_TIMEOUT" = "0" ] && return 0  # disabled

  # Kill any existing watchdog to prevent accumulation
  _old_wpid="$(read_pid "$STATE_DIR/watchdog.pid")"
  if [ -n "$_old_wpid" ]; then
    kill "$_old_wpid" 2>/dev/null
    rm -f "$STATE_DIR/watchdog.pid"
  fi

  (
    while true; do
      sleep 60
      if [ ! -f "$ACTIVITY_FILE" ]; then
        continue
      fi
      last="$(cat "$ACTIVITY_FILE" 2>/dev/null || echo 0)"
      # Validate last is numeric; treat corrupt values as stale
      case "$last" in
        ''|*[!0-9]*) last=0 ;;
      esac
      now="$(date +%s)"
      idle=$((now - last))
      if [ "$idle" -ge "$IDLE_TIMEOUT" ]; then
        _spid="$(cat "$PID_FILE" 2>/dev/null)" || true
        if [ -n "$_spid" ]; then
          kill "$_spid" 2>/dev/null
          rm -f "$PID_FILE" "$ACTIVITY_FILE"
        fi
        rm -f "$STATE_DIR/watchdog.pid"
        exit 0
      fi
    done
  ) &
  echo $! > "$STATE_DIR/watchdog.pid"
}

touch_activity() {
  date +%s > "$ACTIVITY_FILE" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Env change detection: auto-restart daemon when SLACK_MCP_* vars change
# ---------------------------------------------------------------------------

current_env() {
  env | grep '^SLACK_MCP_' | sort
}

snapshot_env() {
  current_env > "$ENV_FILE" 2>/dev/null
}

env_changed() {
  [ ! -f "$ENV_FILE" ] && return 1  # no snapshot — nothing to compare
  _current="$(current_env)"
  _saved="$(cat "$ENV_FILE" 2>/dev/null)"
  [ "$_current" != "$_saved" ]
}

ensure_daemon() {
  if is_daemon_running && env_changed; then
    echo "Environment changed, restarting daemon..." >&2
    stop_daemon
  fi
  start_daemon
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------

# --help and similar flags don't hit the server — run directly
case "${1:-}" in
  -h|--help) exec "$DIR/slack-cli-bin" "$@" ;;
  server)
    shift
    case "${1:-status}" in
      start)  ensure_daemon; exit $? ;;
      stop)   stop_daemon; exit $? ;;
      status)
        if is_daemon_running; then
          echo "Server running (PID $(read_pid "$PID_FILE"), port $SLACK_CLI_PORT)"
        else
          echo "Server not running"
          rm -f "$PID_FILE" 2>/dev/null
        fi
        exit 0
        ;;
      *) echo "Usage: slack-cli server {start|stop|status}" >&2; exit 1 ;;
    esac
    ;;
esac

# Ensure daemon is running (auto-restarts if env changed), record activity, then run the CLI
ensure_daemon || exit 1
touch_activity
exec "$DIR/slack-cli-bin" "$@"
WRAPPER_EOF
  chmod +x "$STAGE_DIR/slack-cli"

  # 4. Assemble and package tarball
  cp "$COMPILED"                    "$STAGE_DIR/slack-cli-bin"
  cp "$SERVER_BIN" "$STAGE_DIR/slack-mcp-server"
  chmod +x "$STAGE_DIR/slack-cli-bin" "$STAGE_DIR/slack-mcp-server"

  TARBALL="$DIST_DIR/slack-cli-${PLATFORM}.tar.gz"
  tar -czf "$TARBALL" -C "$STAGE_DIR" slack-cli slack-cli-bin slack-mcp-server

  # 5. Generate SHA256 checksum
  CHECKSUM_FILE="$DIST_DIR/slack-cli-${PLATFORM}.tar.gz.sha256"
  if command -v sha256sum >/dev/null 2>&1; then
    (cd "$DIST_DIR" && sha256sum "slack-cli-${PLATFORM}.tar.gz" > "$CHECKSUM_FILE")
  elif command -v shasum >/dev/null 2>&1; then
    (cd "$DIST_DIR" && shasum -a 256 "slack-cli-${PLATFORM}.tar.gz" > "$CHECKSUM_FILE")
  else
    die "Neither sha256sum nor shasum found — cannot generate checksums"
  fi

  echo "    Done: $TARBALL"
  ls -lh "$TARBALL" "$CHECKSUM_FILE"
done

echo ""
echo "==> All builds complete."
ls -lh "$DIST_DIR/"
