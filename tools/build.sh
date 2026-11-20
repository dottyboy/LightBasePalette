#!/bin/bash
# Build TyphAccess with CodeTyphon's typhonbuild (Qt6). Output: bin/TyphAccess
set -e
cd "$(dirname "$0")/.."
python3 tools/gen_catalog.py
python3 tools/gen_showcase.py
python3 tools/gen_icons.py || echo "ikone: pycairo nije dostupan, ostaje postojeci ta_iconsdata.pas"
[ -f docs/manual/html/prirucnik.html ] && python3 tools/gen_manual.py
export DBUS_SESSION_BUS_ADDRESS=disabled:
CT=${CODETYPHON_DIR:-/usr/local/codetyphon}
"$CT/typhon/bin64/typhonbuild" --pcp="${TYPHON_PCP:-$HOME/.typhon64}" --ws=qt6 "$@" TyphAccess.ctpr
