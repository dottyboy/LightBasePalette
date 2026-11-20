#!/bin/bash
# Pokrece CodeTyphon sa "Light profilom": u paleti samo osnovne stranice i TyphAccess.
# Puni IDE i dalje radi s uobicajenim postavkama (~/.typhon64); ovo ih ne mijenja.
DIR="$(cd "$(dirname "$0")" && pwd)"
PROFILE="${TYPHON_LIGHT_PCP:-$HOME/.typhon-light}"
IDE="${CODETYPHON_DIR:-/usr/local/codetyphon}/typhon/bin64/typhon"
# IDE s ugradenim TyphAccess paketima (izradi ga install_in_ide.sh); inace obicni IDE (paleta bez nasih stranica)
[ -x "$PROFILE/bin/typhon-light" ] && IDE="$PROFILE/bin/typhon-light"
[ -f "$PROFILE/environmentoptions.xml" ] || python3 "$DIR/make_light_profile.py" "${TYPHON_PCP:-$HOME/.typhon64}" "$PROFILE" || exit 1
export DBUS_SESSION_BUS_ADDRESS=${DBUS_SESSION_BUS_ADDRESS:-disabled:}
export LC_NUMERIC=hr_HR.UTF-8
exec "$IDE" --pcp="$PROFILE" "$@"
