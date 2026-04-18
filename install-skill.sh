#!/bin/sh
set -eu

# install-skill.sh — Install the slack-cli Agent skill
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/CJHwong/mcporter-slack-cli/main/install-skill.sh | sh
#
# Env vars (optional):
#   SKILL_DIR  — target directory (default: .agents/skills)
#   REF        — git ref to pull from (default: main)

REPO="CJHwong/mcporter-slack-cli"
SKILL_DIR="${SKILL_DIR:-.agents/skills}"
REF="${REF:-main}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Fetching skill from $REPO@$REF..."
curl -fsSL "https://github.com/$REPO/archive/$REF.tar.gz" -o "$TMP_DIR/src.tgz"

mkdir -p "$SKILL_DIR"
rm -rf "$SKILL_DIR/slack-cli"
tar -xzf "$TMP_DIR/src.tgz" -C "$SKILL_DIR" --strip-components=3 \
  "mcporter-slack-cli-$REF/.claude/skills/slack-cli"

echo "Installed to $SKILL_DIR/slack-cli"
