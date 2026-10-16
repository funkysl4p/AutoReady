#!/usr/bin/env bash
# Prints the OldUnreal patch tag selected in ut-patch.conf.
set -euo pipefail
cd "$(dirname "$0")/.."
. ./ut-patch.conf
API=https://api.github.com/repos/OldUnreal/UnrealTournamentPatches/releases
AUTH=(); [[ -n "${GITHUB_TOKEN:-}" ]] && AUTH=(-H "Authorization: Bearer $GITHUB_TOKEN")
case "$UT_PATCH" in
  newest) curl -fsSL "${AUTH[@]}" "$API?per_page=20" | jq -r '[.[] | select(.draft|not)][0].tag_name' ;;
  stable) curl -fsSL "${AUTH[@]}" "$API/latest" | jq -r .tag_name ;;
  *)      echo "$UT_PATCH" ;;
esac
