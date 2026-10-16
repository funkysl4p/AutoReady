#!/usr/bin/env bash
# Installs UT99 GOTY + the given OldUnreal patch into DEST using the official
# OldUnreal installer (downloads the game ISO from OldUnreal mirrors).
# Usage: scripts/setup-ut.sh <patch-tag> <dest>
set -euo pipefail
TAG="${1:?patch tag}"; DEST="${2:?destination}"
WORK="$(mktemp -d)"
curl -fsSL https://raw.githubusercontent.com/OldUnreal/FullGameInstallers/master/Linux/install-ut99.sh -o "$WORK/install-ut99.sh"
# The installer always takes ".../releases/latest" (no release candidates):
# pin it to the requested tag instead.
sed -i "s#UnrealTournamentPatches/releases/latest#UnrealTournamentPatches/releases/tags/${TAG}#" "$WORK/install-ut99.sh"
grep -q "releases/tags/${TAG}" "$WORK/install-ut99.sh" || { echo "Could not pin patch tag in installer" >&2; exit 1; }
chmod +x "$WORK/install-ut99.sh"
mkdir -p "$DEST"
# The installer asks to accept the Epic Games Terms of Service
# (https://legal.epicgames.com/en-US/epicgames/tos) on stdin. Unattended runs
# must opt in explicitly with UT_ACCEPT_EPIC_TOS=1.
if [[ "${UT_ACCEPT_EPIC_TOS:-0}" != "1" ]]; then
  echo "Set UT_ACCEPT_EPIC_TOS=1 to accept the Epic Games Terms of Service" >&2; exit 1
fi
"$WORK/install-ut99.sh" --destination "$DEST" --ui-mode=none \
  --application-entry=skip --desktop-shortcut=skip --no-unrealed < <(yes y)
echo "$TAG" > "$DEST/.ut-patch"
# Content not needed to compile a mutator (keeps the cache small).
rm -rf "$DEST/Maps" "$DEST/Music" "$DEST/Help" "$DEST/Web" "$DEST/Logs"
rm -rf "$WORK"
