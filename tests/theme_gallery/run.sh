#!/bin/bash
# Prevodi i pokrece galeriju teme (offscreen); uspjeh = sve snimke spremljene i nisu prazne.
set -e
cd "$(dirname "$0")"
TB="${CODETYPHON_DIR:-/usr/local/codetyphon}/typhon/bin64/typhonbuild"
"$TB" --pcp="${TYPHON_PCP:-$HOME/.typhon64}" --ws=qt6 theme_gallery.ctpr 2>&1 | grep -E "Error|Fatal" && exit 1 || true
rm -rf out
DBUS_SESSION_BUS_ADDRESS=disabled: QT_QPA_PLATFORM=offscreen ./theme_gallery out 2>&1 | grep snimki
test "$(ls out/*.png | wc -l)" = 36
for f in out/*.png; do test "$(stat -c %s "$f")" -gt 5000 || { echo "premala snimka: $f"; exit 1; }; done
echo "galerija: 36 snimki, sve ispravne"
