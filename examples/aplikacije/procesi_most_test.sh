#!/bin/bash
# Ispitivanje mosta s pravim brokerom (treba mosquitto, mosquitto_pub/sub i python3). Radi na kopiji baze:
#   procesi_most_test.sh Procesi.db     (baza mora imati seed iz procesi_simulator.py seed)
set -u
SRC="${1:?baza}"
D=$(mktemp -d)
cp "$SRC" "$D/t.db"
E="$(cd "$(dirname "$0")" && pwd)"
P=$((18000 + RANDOM % 1000))
fail=0
ok()  { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }
q()   { python3 - "$D/t.db" "$1" <<'PY'
import sqlite3, sys
c = sqlite3.connect(sys.argv[1])
r = c.execute(sys.argv[2]).fetchone()
print("" if r is None or r[0] is None else r[0])
PY
}
mosquitto -p $P >"$D/mq.log" 2>&1 & MQ=$!
sleep 1
python3 "$E/procesi_most.py" "$D/t.db" --port $P --ack-wait 4 >"$D/most.log" 2>&1 & MO=$!
sleep 2
PUMP=$(q "select u.id from uredjaji u where u.pogon_id=2 and u.naziv='Pumpa navodnjavanja'")
TEMP=$(q "select u.id from uredjaji u where u.pogon_id=1 and u.naziv='Temperatura zraka'")
# 1. ručna naredba s potvrdom uređaja
timeout 20 python3 "$E/procesi_simulator.py" mqtt "$D/t.db" 25 $P >"$D/sim1.log" 2>&1 &
SIM=$!
sleep 2
python3 - "$D/t.db" "$PUMP" <<'PY'
import sqlite3, sys
c = sqlite3.connect(sys.argv[1])
c.execute("insert into naredbe(uredjaj_id,vrijeme,akcija,izvor,stanje) values(?,datetime('now','localtime'),'ukljuci','korisnik','cekanje')", (sys.argv[2],))
c.commit()
PY
sleep 5
[ "$(q "select stanje from naredbe where uredjaj_id=$PUMP order by id desc limit 1")" = "izvrseno" ] && ok "naredba je poslana i uređaj ju je potvrdio" || bad "naredba nije potvrđena: $(q "select stanje from naredbe where uredjaj_id=$PUMP order by id desc limit 1")"
[ "$(q "select vrijednost from ocitanja where uredjaj_id=$PUMP order by id desc limit 1")" = "1.0" ] && ok "stanje izlaza je uključeno" || bad "stanje izlaza nije uključeno"
wait $SIM 2>/dev/null
# 2. naredba bez potvrde
python3 - "$D/t.db" "$PUMP" <<'PY'
import sqlite3, sys
c = sqlite3.connect(sys.argv[1])
c.execute("insert into naredbe(uredjaj_id,vrijeme,akcija,izvor,stanje) values(?,datetime('now','localtime'),'iskljuci','korisnik','cekanje')", (sys.argv[2],))
c.commit()
PY
sleep 14
[ "$(q "select stanje from naredbe where uredjaj_id=$PUMP order by id desc limit 1")" = "pogreska" ] && ok "naredba bez potvrde postaje pogreška" || bad "naredba bez potvrde: $(q "select stanje from naredbe where uredjaj_id=$PUMP order by id desc limit 1")"
[ "$(q "select count(*) from alarmi where uredjaj_id=$PUMP and vrsta='naredba' and zatvoreno is null")" = "1" ] && ok "alarm o nepotvrđenoj naredbi" || bad "nema alarma o nepotvrđenoj naredbi"
# 3. granice: jedno očitanje ne diže alarm, dva uzastopna da, povratak u granice ga zatvara
T=$(q "select tema from pogoni where id=1"); TT=$(q "select tema from uredjaji where id=$TEMP")
mosquitto_pub -p $P -t "$T/$TT/stanje" -m 40; sleep 1
[ "$(q "select count(*) from alarmi where uredjaj_id=$TEMP and vrsta='granica'")" = "0" ] && ok "jedno očitanje izvan granica ne diže alarm" || bad "alarm nakon jednog očitanja"
mosquitto_pub -p $P -t "$T/$TT/stanje" -m 41; sleep 1
[ "$(q "select count(*) from alarmi where uredjaj_id=$TEMP and vrsta='granica' and zatvoreno is null")" = "1" ] && ok "dva uzastopna očitanja izvan granica dižu alarm" || bad "nema alarma za granicu"
mosquitto_pub -p $P -t "$T/$TT/stanje" -m 41; sleep 1
[ "$(q "select count(*) from alarmi where uredjaj_id=$TEMP and vrsta='granica'")" = "1" ] && ok "alarm se ne udvostručuje" || bad "udvostručen alarm"
mosquitto_pub -p $P -t "$T/$TT/stanje" -m 22; sleep 1
[ "$(q "select count(*) from alarmi where uredjaj_id=$TEMP and vrsta='granica' and zatvoreno is null")" = "0" ] && ok "povratak u granice zatvara alarm" || bad "alarm nije zatvoren"
# 4. gubitak veze
mosquitto_pub -p $P -t "$T/status" -m offline; sleep 1
[ "$(q "select count(*) from alarmi where pogon_id=1 and vrsta='veza' and zatvoreno is null")" = "1" ] && ok "offline daje alarm veze" || bad "nema alarma veze"
mosquitto_pub -p $P -t "$T/status" -m online; sleep 1
[ "$(q "select count(*) from alarmi where pogon_id=1 and vrsta='veza' and zatvoreno is null")" = "0" ] && ok "online zatvara alarm veze" || bad "alarm veze nije zatvoren"
kill $MO $MQ 2>/dev/null
pkill -x mosquitto_sub 2>/dev/null
rm -rf "$D"
[ $fail = 0 ] && echo "svi pokusi su prošli" || echo "ima pogrešaka"
exit $fail
