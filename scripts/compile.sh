#!/usr/bin/env bash
# Compiles AutoReady.u against a UT99 installation.
# Usage: scripts/compile.sh <ut-dir> [out-dir]
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
UT="$(cd "${1:?UT99 directory}" && pwd)"; OUT="${2:-$REPO/build}"
SYS="$UT/System"; [[ -x "$SYS/ucc-bin-amd64" ]] || SYS="$UT/System64"
mkdir -p "$OUT"; OUT="$(cd "$OUT" && pwd)"   # absolute: the script cd's into System later

# LD_PRELOAD shim for the "Analyzing..." loop of ucc make on Linux (harmless if fixed).
gcc -shared -fPIC -o "$OUT/nodots.so" "$REPO/tools/nodots.c" -ldl

# Sources: only .uc files in Classes/.
rm -rf "$UT/AutoReady"; mkdir -p "$UT/AutoReady/Classes"
cp "$REPO"/AutoReady/Classes/*.uc "$UT/AutoReady/Classes/"

# Build.ini: Default.ini with only the EditPackages AutoReady needs.
python3 - "$SYS/Default.ini" "$SYS/Build.ini" <<'PY'
import sys
pk = "Core Engine Editor UWindow Fire IpDrv UWeb UBrowser UnrealShare UnrealI UMenu Botpack AutoReady".split()
out, sec, done = [], "", False
for l in open(sys.argv[1], encoding="latin-1").read().splitlines():
    s = l.strip()
    if s.startswith("["): sec = s
    if sec == "[Editor.EditorEngine]" and s.startswith("EditPackages="):
        if not done: out += ["EditPackages=" + p for p in pk]; done = True
        continue
    out.append(l)
if not done: sys.exit("EditPackages not found in Default.ini")
open(sys.argv[2], "w", encoding="latin-1").write("\r\n".join(out) + "\r\n")
PY

cd "$SYS"
rm -f AutoReady.u
LD_PRELOAD="$OUT/nodots.so" timeout 600 ./ucc-bin-amd64 make ini=Build.ini -nohomedir 2>&1 | tee "$OUT/ucc-make.log"
grep -q "Success - 0 error(s)" "$OUT/ucc-make.log" || { echo "Build failed" >&2; exit 1; }
cp AutoReady.u "$OUT/"
cd "$OUT" && md5sum AutoReady.u > AutoReady.u.md5 && ls -la AutoReady.u && cat AutoReady.u.md5
