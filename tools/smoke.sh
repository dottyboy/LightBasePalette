#!/bin/bash
# Headless smoke test of the data layer + form runtime (Qt offscreen).
set -e
cd "$(dirname "$0")/.."
python3 tools/gen_catalog.py
python3 tools/gen_showcase.py
python3 tools/gen_icons.py || echo "ikone: pycairo nije dostupan, ostaje postojeci ta_iconsdata.pas"
export DBUS_SESSION_BUS_ADDRESS=disabled:
CT=${CODETYPHON_DIR:-/usr/local/codetyphon}
mkdir -p tests/lib
sed -e 's#<Filename Value="bin/TyphAccess"/>#<Filename Value="smoke"/>#' \
    -e 's#<Filename Value="TyphAccess.ppr"/>#<Filename Value="smoke.pas"/>#' \
    -e 's#src/core#../src/core#g; s#src/gui#../src/gui#g; s#src/editors#../src/editors#g' \
    -e 's#lib/\$(TargetCPU)-\$(TargetOS)#lib#' TyphAccess.ctpr > tests/Smoke.ctpr
if [ -n "${FISCAL:-}" ]; then   # uz lokalni modul fiskalizacije
  sed -i -e 's#<OtherUnitFiles Value="\(.*\)"/>#<OtherUnitFiles Value="\1;../../LightPalette/modules/fiskalizacija/src"/>#' -e 's#</SearchPaths>#</SearchPaths><Other><CustomOptions Value="-dTA_FISCAL"/></Other>#' tests/Smoke.ctpr
fi
"$CT/typhon/bin64/typhonbuild" --pcp="${TYPHON_PCP:-$HOME/.typhon64}" --ws=qt6 tests/Smoke.ctpr 2>&1 | grep -E "Error|Fatal" || true
QT_QPA_PLATFORM=offscreen timeout 900 ./tests/smoke 2>&1 | grep -E "^(ok|FAIL|fails)|rror|xception"
