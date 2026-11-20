#!/bin/bash
# Ugradi pakete TyphAccess palete u zaseban IDE za Light profil (~/.typhon-light/bin/typhon-light).
# Obicni IDE (bin64/typhon) se NE dira. Traje desetak minuta (prevodi cijeli IDE s statickim paketima).
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
PROFILE="${TYPHON_LIGHT_PCP:-$HOME/.typhon-light}"
CT="${CODETYPHON_DIR:-/usr/local/codetyphon}"
[ -f "$PROFILE/environmentoptions.xml" ] || python3 "$DIR/make_light_profile.py" "${TYPHON_PCP:-$HOME/.typhon64}" "$PROFILE"
cp -n "${TYPHON_PCP:-$HOME/.typhon64}/miscellaneousoptions.xml" "$PROFILE/" 2>/dev/null || true
mkdir -p "$PROFILE/bin" "$PROFILE/units"
# ikone palete: LIGHT_ICONS=dark za tamnu temu IDE-a (zadano svijetle); u repozitoriju ostaju svijetle
python3 "$DIR/../lazarus/make_icons_res.py" "${LIGHT_ICONS:-light}" >/dev/null
# LIGHT_EXT=1 ugraduje i paket typhaccess_ext (TAChart, TRxDBGrid); odabir: TYPHACCESS_PROVIDER=tachart|rx pri pokretanju
PKGS="typhaccess_core typhaccess_editors typhaccess_dsgn"
[ "${LIGHT_EXT:-0}" = "0" ] || PKGS="$PKGS typhaccess_ext"
for p in $PKGS; do
  "$CT/typhon/bin64/typhonbuild" --pcp="$PROFILE" --ws=qt6 "$DIR/../lazarus/$p.ctpkg" >/dev/null
done
nice -n 10 "$CT/typhon/bin64/typhonbuild" --pcp="$PROFILE" --ws=qt6 --add-package \
  --build-ide="-FE$PROFILE/bin -FU$PROFILE/units -otyphon-light" "$DIR/../lazarus/typhaccess_dsgn.ctpkg"
if [ "${LIGHT_EXT:-0}" != "0" ]; then
  nice -n 10 "$CT/typhon/bin64/typhonbuild" --pcp="$PROFILE" --ws=qt6 --add-package \
    --build-ide="-FE$PROFILE/bin -FU$PROFILE/units -otyphon-light" "$DIR/../lazarus/typhaccess_ext.ctpkg"
fi
echo "Gotovo: $PROFILE/bin/typhon-light (pokreni light/typhon-light.sh)"
[ "${LIGHT_ICONS:-light}" = "light" ] || python3 "$DIR/../lazarus/make_icons_res.py" light >/dev/null
