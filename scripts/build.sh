#!/usr/bin/env bash
# Copy sources to the server and compile AutoReady.u
# Usage: scripts/build.sh user@host
set -euo pipefail
HOST="${1:?usage: $0 user@host}"
UT=/opt/ut99-server
rsync -av --delete AutoReady/ "$HOST:$UT/AutoReady/"
ssh "$HOST" "cd $UT/System && rm -f AutoReady.u && ./ucc-bin-amd64 make -nohomedir"
