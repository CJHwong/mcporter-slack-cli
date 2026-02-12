#!/bin/sh
set -eu

# install.sh — Install the portable Slack CLI
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/CJHwong/mcporter-slack-cli/main/install.sh | sh
#
# Env vars (optional):
#   SLACK_CLI_VERSION  — specific release tag (default: latest)
#   INSTALL_DIR        — install location (default: ~/.local/bin)

REPO="CJHwong/mcporter-slack-cli"
BASE_URL="https://github.com/$REPO/releases"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

die() { echo "ERROR: $*" >&2; exit 1; }

detect_platform() {
  OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
  ARCH="$(uname -m)"

  case "$OS" in
    darwin) OS="darwin" ;;
    linux)  OS="linux"  ;;
    *)      die "Unsupported OS: $OS" ;;
  esac

  case "$ARCH" in
    x86_64|amd64)  ARCH="amd64"  ;;
    arm64|aarch64)  ARCH="arm64"  ;;
    *)              die "Unsupported architecture: $ARCH" ;;
  esac

  echo "${OS}-${ARCH}"
}

fetch_url() {
  _url="$1"
  _out="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fSL "$_url" -o "$_out"
  elif command -v wget >/dev/null 2>&1; then
    wget --no-verbose -O "$_out" "$_url" || {
      rm -f "$_out"
      return 1
    }
    # wget doesn't fail on HTTP errors by default; verify we got a real file
    if [ ! -s "$_out" ]; then
      rm -f "$_out"
      return 1
    fi
  else
    die "Neither curl nor wget found. Install one and retry."
  fi
}

verify_checksum() {
  _file="$1"
  _expected="$2"
  if command -v sha256sum >/dev/null 2>&1; then
    _actual="$(sha256sum "$_file" | cut -d' ' -f1)"
  elif command -v shasum >/dev/null 2>&1; then
    _actual="$(shasum -a 256 "$_file" | cut -d' ' -f1)"
  else
    echo "WARNING: No sha256sum or shasum found. Skipping checksum verification." >&2
    return 0
  fi
  if [ "$_actual" != "$_expected" ]; then
    die "Checksum mismatch! Expected: $_expected  Got: $_actual"
  fi
}

# ---------------------------------------------------------------------------
# Detect platform
# ---------------------------------------------------------------------------

PLATFORM="$(detect_platform)"
echo "Detected platform: $PLATFORM"

# ---------------------------------------------------------------------------
# Resolve version
# ---------------------------------------------------------------------------

ASSET_NAME="slack-cli-${PLATFORM}.tar.gz"
CHECKSUM_NAME="slack-cli-${PLATFORM}.tar.gz.sha256"

if [ -n "${SLACK_CLI_VERSION:-}" ]; then
  VERSION="$SLACK_CLI_VERSION"
  DOWNLOAD_URL="$BASE_URL/download/$VERSION/$ASSET_NAME"
  CHECKSUM_URL="$BASE_URL/download/$VERSION/$CHECKSUM_NAME"
else
  VERSION="latest"
  DOWNLOAD_URL="$BASE_URL/latest/download/$ASSET_NAME"
  CHECKSUM_URL="$BASE_URL/latest/download/$CHECKSUM_NAME"
fi

echo "Version: $VERSION"

# ---------------------------------------------------------------------------
# Determine install directory
# ---------------------------------------------------------------------------

if [ -n "${INSTALL_DIR:-}" ]; then
  BIN_DIR="$INSTALL_DIR"
elif [ -d "$HOME/.local/bin" ] || mkdir -p "$HOME/.local/bin" 2>/dev/null; then
  BIN_DIR="$HOME/.local/bin"
elif [ -w "/usr/local/bin" ]; then
  BIN_DIR="/usr/local/bin"
else
  die "Cannot find a writable install directory. Set INSTALL_DIR explicitly."
fi

echo "Install directory: $BIN_DIR"

# ---------------------------------------------------------------------------
# Download and verify
# ---------------------------------------------------------------------------

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Downloading $ASSET_NAME..."
fetch_url "$DOWNLOAD_URL" "$TMP_DIR/slack-cli.tar.gz"

echo "Downloading checksum..."
if fetch_url "$CHECKSUM_URL" "$TMP_DIR/checksum" 2>/dev/null; then
  EXPECTED_SHA="$(cut -d' ' -f1 < "$TMP_DIR/checksum")"
  echo "Verifying checksum..."
  verify_checksum "$TMP_DIR/slack-cli.tar.gz" "$EXPECTED_SHA"
  echo "Checksum OK"
else
  echo "WARNING: Checksum file not available for this release. Skipping verification." >&2
fi

echo "Extracting..."
tar -xzf "$TMP_DIR/slack-cli.tar.gz" -C "$TMP_DIR"

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------

mkdir -p "$BIN_DIR"
cp "$TMP_DIR/slack-cli"         "$BIN_DIR/slack-cli"
cp "$TMP_DIR/slack-cli-bin"     "$BIN_DIR/slack-cli-bin"
cp "$TMP_DIR/slack-mcp-server"  "$BIN_DIR/slack-mcp-server"
chmod +x "$BIN_DIR/slack-cli" "$BIN_DIR/slack-cli-bin" "$BIN_DIR/slack-mcp-server"

# ---------------------------------------------------------------------------
# Verify — use slack-cli-bin directly to avoid daemon startup
# ---------------------------------------------------------------------------

if "$BIN_DIR/slack-cli-bin" --help >/dev/null 2>&1; then
  echo ""
  echo "slack-cli installed successfully to $BIN_DIR"
else
  die "Installation verification failed. The binary may not be compatible with your system."
fi

# ---------------------------------------------------------------------------
# PATH check
# ---------------------------------------------------------------------------

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *)
    echo ""
    echo "WARNING: $BIN_DIR is not in your PATH."
    echo "Add it by running:"
    echo ""
    echo "  export PATH=\"$BIN_DIR:\$PATH\""
    echo ""
    echo "Or add that line to your shell profile (~/.bashrc, ~/.zshrc, etc.)"
    ;;
esac

# ---------------------------------------------------------------------------
# Next steps
# ---------------------------------------------------------------------------

echo ""
echo "=== Setup ==="
echo ""
echo "1. Create a Slack App with the required scopes (see README for manifest)"
echo "2. Install the app to your workspace"
echo "3. Copy the User OAuth Token (xoxp-...)"
echo "4. Export it:"
echo ""
echo "   export SLACK_MCP_XOXP_TOKEN=\"xoxp-your-token-here\""
echo ""
echo "5. Try it out:"
echo ""
echo "   slack-cli channels-list"
echo ""
