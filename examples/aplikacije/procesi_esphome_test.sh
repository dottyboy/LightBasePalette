#!/bin/bash
# Provjera generiranih ESPHome konfiguracija pravim ESPHomeom (shema, a uz --compile i prevodjenje u firmware).
#   procesi_esphome_test.sh Procesi.db [--compile]
# Treba: typhaccess binarku, python3 i ESPHome (npr. python3 -m venv v && v/bin/pip install esphome; zatim ESPHOME=v/bin/esphome).
set -u
DB="${1:?baza}"; MODE="${2:-}"
E="$(cd "$(dirname "$0")" && pwd)"
BIN="${TYPHACCESS:-$E/../../bin/TyphAccess}"
ESP="${ESPHOME:-esphome}"
D=$(mktemp -d)
"$BIN" "$DB" --esphome="$D" | grep -a "^OK"
cat > "$D/secrets.yaml" <<'S'
wifi_ssid: "x"
wifi_password: "yyyyyyyyyy"
mqtt_broker: "192.168.1.10"
mqtt_user: "u"
mqtt_password: "p"
ota_password: "o"
S
fail=0
for f in "$D"/*.yaml; do
  n=$(basename "$f"); [ "$n" = secrets.yaml ] && continue
  if (cd "$D" && "$ESP" config "$n" >/dev/null 2>&1); then echo "ok   $n: konfiguracija je ispravna"; else echo "FAIL $n: konfiguracija"; fail=1; fi
  if [ "$MODE" = "--compile" ]; then
    if (cd "$D" && "$ESP" compile "$n" >/dev/null 2>&1); then echo "ok   $n: prevodi se u firmware"; else echo "FAIL $n: prevodjenje"; fail=1; fi
  fi
done
rm -rf "$D"
exit $fail
