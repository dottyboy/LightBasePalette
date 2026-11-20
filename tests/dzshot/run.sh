#!/bin/bash
# Snimka dizajnera formi s kontrolama obitelji: run.sh [izlaz.png]  (projekt se izvodi iz tests/Smoke.ctpr kao u tests/ext)
set -e
cd "$(dirname "$0")"
SM=../../../TyphAccess/tests/Smoke.ctpr
[ -f "$SM" ] || { echo "Prvo pokreni TyphAccess/tools/smoke.sh (stvara Smoke.ctpr)"; exit 1; }
python3 - "$SM" <<'PY'
import sys
t = open(sys.argv[1]).read()
t = t.replace('<Filename Value="smoke"/>', '<Filename Value="dzshot"/>').replace('<Filename Value="smoke.pas"/>', '<Filename Value="dzshot.pas"/>')
t = t.replace('../src/core;../src/gui;../src/editors', '../../src/core;../../src/gui;../../src/editors')
open('Dzshot.ctpr', 'w').write(t)
PY
mkdir -p lib
/usr/local/codetyphon/typhon/bin64/typhonbuild --pcp="${TYPHON_PCP:-$HOME/.typhon64}" --ws=qt6 Dzshot.ctpr 2>&1 | grep -E "Error|Fatal" || true
DBUS_SESSION_BUS_ADDRESS=disabled: QT_QPA_PLATFORM=offscreen timeout 60 ./dzshot "${1:-/tmp/dzshot.png}" 2>&1 | grep -v "QThreadStorage\|does not support"
echo "snimka: ${1:-/tmp/dzshot.png}"
