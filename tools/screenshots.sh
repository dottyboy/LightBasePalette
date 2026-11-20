#!/bin/bash
# Slike zaslona za priručnik: izradi demo bazu iz kataloga (kućni budžet) i snimi prozore
# (offscreen, uvijek iste veličine) u docs/manual/slike. Poslije: python3 tools/manual_src/build_manual.py
cd "$(dirname "$0")/.."
export DBUS_SESSION_BUS_ADDRESS=disabled: QT_QPA_PLATFORM=offscreen
# bez korisnikovog qt6ct/qt5ct fonta: slike uvijek izgledaju isto (zadani sans font)
unset QT_QPA_PLATFORMTHEME
DB=${TMPDIR:-/tmp}/ta_screens_demo.db
rm -f "$DB"
timeout 60 bin/TyphAccess --make-domain=budzet "$DB" > /dev/null 2>&1
rm -f docs/manual/slike/*.png
timeout 180 bin/TyphAccess "$DB" --screenshots=docs/manual/slike 2>&1 | grep -E "snimljeno|GREŠKA"
