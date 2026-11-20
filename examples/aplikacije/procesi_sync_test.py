#!/usr/bin/env python3
"""Ispitivanje povezivanja lokacija (procesi_sync.py) i predložaka rasporeda (procesi_most.py). Ne treba MQTT broker.
   TYPHACCESS=putanja/do/TyphAccess python3 procesi_sync_test.py"""
import os, re, shutil, sqlite3, subprocess, sys, tempfile
E = os.path.dirname(os.path.abspath(__file__))
BIN = os.environ.get("TYPHACCESS", os.path.join(E, "..", "..", "bin", "TyphAccess"))
fails = 0
def check(c, msg):
    global fails
    print(("ok   " if c else "FAIL ") + msg)
    if not c: fails += 1
def py(*a): return subprocess.run([sys.executable, *a], capture_output=True, text=True)
def one(db, sql, *p):
    c = sqlite3.connect(db); r = c.execute(sql, p).fetchone(); c.close(); return r[0] if r else None
D = tempfile.mkdtemp()
env = dict(os.environ, DISPLAY=os.environ.get("DISPLAY", ":99"), QT_QPA_PLATFORM=os.environ.get("QT_QPA_PLATFORM", "xcb"), DBUS_SESSION_BUS_ADDRESS="disabled:")
def make(name):
    p = os.path.join(D, name)
    subprocess.run([BIN, "--make-app=" + os.path.join(E, "procesi.opis"), p], env=env, capture_output=True, timeout=120)
    return p
central, s1, s2 = make("sredina.db"), make("lok1.db"), make("lok2.db")
for db in (central, s1, s2):
    check(py(os.path.join(E, "procesi_simulator.py"), "seed", db).returncode == 0, "seed " + os.path.basename(db))
for db in (s1, s2): py(os.path.join(E, "procesi_simulator.py"), "run", db, "10")
SY = os.path.join(E, "procesi_sync.py")
n1, n2 = one(s1, "select count(*) from ocitanja"), one(s2, "select count(*) from ocitanja")
own = one(central, "select count(*) from ocitanja")
check(one(s1, "select min(id) from ocitanja") == one(s2, "select min(id) from ocitanja"), "obje lokacije imaju iste lokalne id-eve (sudar bez pomaka)")
r = py(SY, "sinkroniziraj", "--local", s1, "--site", "1", "--central", central); check(r.returncode == 0, "lokacija 1 sinkronizirana: " + r.stdout.strip().replace("\n", " ") + r.stderr[-200:])
r = py(SY, "sinkroniziraj", "--local", s2, "--site", "2", "--central", central); check(r.returncode == 0, "lokacija 2 sinkronizirana")
check(one(central, "select count(*) from ocitanja") == own + n1 + n2, "središte ima očitanja obje lokacije (%d + %d + %d)" % (own, n1, n2))
check(one(central, "select count(*) from ocitanja where id >= 1000000000 and id < 2000000000") == n1, "očitanja lokacije 1 su u svom rasponu id-eva")
check(one(central, "select count(*) from ocitanja where id >= 2000000000 and id < 3000000000") == n2, "očitanja lokacije 2 su u svom rasponu id-eva")
check(one(central, "select count(*) from ocitanja o left join uredjaji u on u.id = o.uredjaj_id where u.id is null") == 0, "svako središnje očitanje ima svoj uređaj (vanjski ključevi su pomaknuti)")
check(one(central, "select count(*) from uredjaji u left join pogoni p on p.id = u.pogon_id where p.id is null") == 0, "svaki uređaj ima svoj pogon")
check(one(central, "select count(*) from uredjaji u join vrste_uredjaja v on v.id = u.vrsta_id") == one(central, "select count(*) from uredjaji"), "šifrarnik vrsta uređaja ostaje zajednički (bez pomaka)")
check(one(central, "select count(distinct broj) from lokacije where broj in (1,2)") == 2, "lokacije su u središtu s brojevima 1 i 2")
check(one(central, "select count(*) from sinkronizacije where smjer='gore'") == 2, "središte bilježi sinkronizacije")
# ponovno: idempotentno
c0 = one(central, "select count(*) from ocitanja")
py(SY, "sinkroniziraj", "--local", s1, "--site", "1", "--central", central)
check(one(central, "select count(*) from ocitanja") == c0, "ponovna sinkronizacija ne udvostručuje zapise")
# nova očitanja idu inkrementalno
c = sqlite3.connect(s1)
for i in range(5): c.execute("insert into ocitanja(uredjaj_id,vrijeme,vrijednost) values(1,datetime('now','localtime'),?)", (20.0 + i,))
c.commit(); c.close()
r = py(SY, "gore", "--local", s1, "--site", "1", "--central", central)
check(one(central, "select count(*) from ocitanja") == c0 + 5, "nova očitanja stižu u središte (%s)" % r.stdout.strip().replace("\n", " "))
# brisanje lokalno -> briše se u središtu (samo te lokacije)
pr1 = one(s1, "select count(*) from pravila")
c = sqlite3.connect(s1); c.execute("delete from pravila"); c.commit(); c.close()
py(SY, "gore", "--local", s1, "--site", "1", "--central", central)
check(one(central, "select count(*) from pravila where id >= 1000000000 and id < 2000000000") == 0, "obrisano pravilo lokacije 1 nestaje i u središtu")
check(one(central, "select count(*) from pravila where id >= 2000000000 and id < 3000000000") == pr1, "pravila lokacije 2 ostaju")
# paket (prijenos datotekom)
pk = os.path.join(D, "gore.json.gz")
c = sqlite3.connect(s2); c.execute("insert into ocitanja(uredjaj_id,vrijeme,vrijednost) values(1,datetime('now','localtime'),99)"); c.commit(); c.close()
check(py(SY, "gore", "--local", s2, "--site", "2", "--paket", pk).returncode == 0 and os.path.getsize(pk) > 100, "izvoz u paket")
c1 = one(central, "select count(*) from ocitanja")
check(py(SY, "uvezi-gore", "--central", central, "--paket", pk).returncode == 0 and one(central, "select count(*) from ocitanja") == c1 + 1, "uvoz paketa u središte")
# dolje: predložak iz središta stiže u lokaciju i rasporedi ga slijede
c = sqlite3.connect(central)
vid = c.execute("select id from vrste_uredjaja where naziv like 'Rasvjeta%' limit 1").fetchone()[0]
c.execute("insert into predlosci_rasporeda(naziv, vrsta_id) values('Rast 18 h', ?)", (vid,))
pid = c.execute("select max(id) from predlosci_rasporeda").fetchone()[0]
c.execute("insert into predlosci_stavke(predlozak_id,dani,od,do,svakih_min,trajanje_s) values(?,'1234567','06:00','24:00',0,0)", (pid,))
c.commit(); c.close()
sys.path.insert(0, E)
import procesi_most
mc = procesi_most.Most(central, "localhost", 1, None, None)
mc.templates()
check(one(central, "select verzija from predlosci_rasporeda where id=?", pid) == 1 and one(central, "select otisak from predlosci_rasporeda where id=?", pid), "novi predložak dobiva verziju 1 i otisak")
r = py(SY, "dolje", "--central", central, "--local", s1); check(r.returncode == 0 and one(s1, "select count(*) from predlosci_rasporeda where id=?", pid) == 1, "predložak stiže u lokaciju")
c = sqlite3.connect(s1)
dev = c.execute("select id from uredjaji where naziv like 'Rasvjeta%' limit 1").fetchone()[0]
rid = c.execute("select id from rasporedi where uredjaj_id=?", (dev,)).fetchone()[0]
c.execute("update rasporedi set predlozak_id=?, automatski=1 where id=?", (pid, rid)); c.commit(); c.close()
ml = procesi_most.Most(s1, "localhost", 1, None, None)
check(ml.templates() == 1, "raspored koji prati predložak ga primjenjuje")
check(one(s1, "select od||'-'||do from rasporedi_stavke where raspored_id=?", rid) == "06:00-24:00" and one(s1, "select predlozak_verzija from rasporedi where id=?", rid) == 1, "stavke i verzija su preuzete")
check(ml.templates() == 0, "bez nove verzije nema ponovne primjene")
# nova verzija u središtu
c = sqlite3.connect(central); c.execute("insert into predlosci_stavke(predlozak_id,dani,od,do,svakih_min,trajanje_s) values(?,'67','00:00','03:00',0,0)", (pid,)); c.commit(); c.close()
mc.templates()
check(one(central, "select verzija from predlosci_rasporeda where id=?", pid) == 2, "izmjena stavki diže verziju predloška na 2")
py(SY, "dolje", "--central", central, "--local", s1)
check(ml.templates() == 1 and one(s1, "select count(*) from rasporedi_stavke where raspored_id=?", rid) == 2 and one(s1, "select predlozak_verzija from rasporedi where id=?", rid) == 2, "nova verzija stiže i primjenjuje se")
# automatski = 0: samo se prijavi
c = sqlite3.connect(s1); c.execute("update rasporedi set automatski=0 where id=?", (rid,)); c.commit(); c.close()
c = sqlite3.connect(central); c.execute("insert into predlosci_stavke(predlozak_id,dani,od,do,svakih_min,trajanje_s) values(?,'1','12:00','13:00',0,0)", (pid,)); c.commit(); c.close()
mc.templates(); py(SY, "dolje", "--central", central, "--local", s1)
check(ml.templates() == 0 and one(s1, "select predlozak_verzija from rasporedi where id=?", rid) == 2, "bez 'automatski' raspored ostaje na staroj verziji")
src = open(os.path.join(E, "procesi.opis"), encoding="utf-8").read()
m = re.search(r'upit "Rasporedi zastarjeli"\n(.*?)\n\n', src, re.S)
zast = sqlite3.connect(s1).execute("\n".join(l[2:] for l in m.group(1).split("\n"))).fetchall()
check(len(zast) == 1 and zast[0][3] == 2 and zast[0][4] == 3, "izvješće 'Rasporedi zastarjeli' ga navodi: %s" % (zast,))
# lokalna izmjena odvaja od predloška
ml.dev = {}
check(one(s1, "select predlozak_id from rasporedi where id=?", rid) == pid, "prije lokalne izmjene raspored prati predložak")
shutil.rmtree(D)
print("svi pokusi su prošli" if not fails else "ima pogrešaka")
sys.exit(1 if fails else 0)
