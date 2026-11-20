#!/bin/bash
# Ispitivanje neobaveznog paketa typhaccess_ext (TAChart, TRxDBGrid). Projekt se izvodi iz tests/Smoke.ctpr (smoke.sh ga stvara).
set -e
cd "$(dirname "$0")"
SM=../../../TyphAccess/tests/Smoke.ctpr
[ -f "$SM" ] || { echo "Prvo pokreni TyphAccess/tools/smoke.sh (stvara Smoke.ctpr)"; exit 1; }
python3 - "$SM" <<'PY'
import sys, re
t = open(sys.argv[1]).read()
t = t.replace('<Filename Value="smoke"/>', '<Filename Value="exttest"/>').replace('<Filename Value="smoke.pas"/>', '<Filename Value="ext_test.pas"/>')
t = t.replace('../src/core;../src/gui;../src/editors', '../../src/core;../../src/gui;../../src/ext')
t = re.sub(r'\.\./src/', '../../src/', t) if '../../src' not in t else t
t = t.replace('</RequiredPackages>', '<Item><PackageName Value="lz_taChart"/></Item><Item><PackageName Value="pl_RX"/></Item></RequiredPackages>', 1)
open('Ext.ctpr', 'w').write(t)
PY
mkdir -p lib
/usr/local/codetyphon/typhon/bin64/typhonbuild --pcp="${TYPHON_PCP:-$HOME/.typhon64}" --ws=qt6 Ext.ctpr 2>&1 | grep -E "Error|Fatal" || true
DBUS_SESSION_BUS_ADDRESS=disabled: QT_QPA_PLATFORM=offscreen timeout 300 ./exttest 2>&1 | grep -E "^(ok|FAIL|fails)|rror|xception"
