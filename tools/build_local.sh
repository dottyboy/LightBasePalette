#!/bin/bash
# Lokalna izgradnja S modulom fiskalizacije (LightPalette/modules/fiskalizacija, nije dio objave): bin/TyphAccess-fiskal.
# Objavljena izgradnja (TyphAccess.ctpr) modula nema.
set -e
cd "$(dirname "$0")/.."
MOD=../LightPalette/modules/fiskalizacija/src
[ -d "$MOD" ] || { echo "nema modula fiskalizacije ($MOD)"; exit 1; }
CT=${CODETYPHON_DIR:-/usr/local/codetyphon}
mkdir -p lib/local
sed -e 's#<Filename Value="bin/TyphAccess"/>#<Filename Value="bin/TyphAccess-fiskal"/>#' \
    -e 's#<Filename Value="TyphAccess.ppr"/>#<Filename Value="TyphAccessFiskal.ppr"/>#' \
    -e "s#<OtherUnitFiles Value=\"src/core;src/gui;src/editors\"/>#<OtherUnitFiles Value=\"src/core;src/gui;src/editors;$MOD\"/>#" \
    -e 's#lib/\$(TargetCPU)-\$(TargetOS)#lib/local#' \
    -e 's#</SearchPaths>#</SearchPaths><Other><CustomOptions Value="-dTA_FISCAL"/></Other>#' TyphAccess.ctpr > TyphAccessFiskal.ctpr
sed -e 's#Interfaces, Forms,#Interfaces, Forms, ta_fiscalreg,#' TyphAccess.ppr | sed -e 's#program TyphAccess;#program TyphAccessFiskal;#' > TyphAccessFiskal.ppr
"$CT/typhon/bin64/typhonbuild" --pcp="${TYPHON_PCP:-$HOME/.typhon64}" --ws=qt6 TyphAccessFiskal.ctpr 2>&1 | grep -E "Error|Fatal" || echo "gotovo: bin/TyphAccess-fiskal"
