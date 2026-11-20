#!/bin/bash
# Packs the built program into dist/TyphAccess-<date>.tar.gz (stripped binary + launcher + readme).
set -e
cd "$(dirname "$0")/.."
[ -x bin/TyphAccess ] || ./tools/build.sh
NAME="TyphAccess-$(date +%Y%m%d)"
OUT="dist/$NAME"
rm -rf "$OUT"; mkdir -p "$OUT"
cp bin/TyphAccess "$OUT/TyphAccess"
strip "$OUT/TyphAccess"
cat > "$OUT/typhaccess.sh" <<'LAUNCH'
#!/bin/sh
cd "$(dirname "$0")"
export DBUS_SESSION_BUS_ADDRESS=disabled:
exec ./TyphAccess "$@"
LAUNCH
chmod +x "$OUT/typhaccess.sh" "$OUT/TyphAccess"
cat > "$OUT/README.txt" <<'TXT'
TyphAccess - graditelj poslovnih aplikacija (SQLite + Qt6)

Pokretanje:   ./typhaccess.sh                 (dizajn)
              ./typhaccess.sh baza.db          (otvori bazu)
              ./typhaccess.sh --runtime baza.db  (samo korištenje, bez dizajnera)
              ./typhaccess.sh --design baza.db   (dizajn i kad je baza u runtime načinu)

Potrebno na računalu: libQt6Pas.so.1 (Qt6), libsqlite3 (3.35+).
Gotova aplikacija: Aplikacija -> Postavke i izvoz aplikacije.
TXT
tar -C dist -czf "dist/$NAME.tar.gz" "$NAME"
ls -l "$OUT/TyphAccess" "dist/$NAME.tar.gz"
