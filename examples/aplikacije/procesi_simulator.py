#!/usr/bin/env python3
"""Simulator pogona za primjer procesi.opis (bez hardvera).

  procesi_simulator.py seed  Procesi.db      katalog vrsta uređaja, sustavi proizvodnje, 3 pogona s uređajima, zaliha
  procesi_simulator.py run   Procesi.db [N]  N koraka (zadano 1): upisuje očitanja svih senzora; pH pravilo dozira regulator
  procesi_simulator.py mqtt  Procesi.db [N] [port]  N krugova: umjesto u bazu objavljuje na MQTT (kao pravi ESP32); most upisuje i dozira

Radi samo s tablicama aplikacije (SQLite). Isti zapisi nastaju kad ih upisuje pravi most s MQTT-a (ESP32 -> baza)."""
import json, math, random, re, sqlite3, sys, time, unicodedata
from datetime import datetime

SUSTAVI = ["Polje", "Staklenik", "Tunel", "Hala", "Podloga"]
# naziv, uloga, jedinica, min, max
VRSTE = [
    ("Temperatura zraka", "senzor", "°C", 18, 28), ("Temperatura tla", "senzor", "°C", 15, 26),
    ("Temperatura vode", "senzor", "°C", 16, 24), ("Vlaga zraka", "senzor", "%", 50, 75),
    ("Vlaga tla", "senzor", "%", 40, 70), ("pH", "senzor", "pH", 5.5, 6.5),
    ("EC", "senzor", "mS/cm", 1.2, 2.4), ("Razina vode", "senzor", "%", 30, 100),
    ("Osvijetljenost", "senzor", "lux", None, None), ("CO2", "senzor", "ppm", 400, 1200),
    ("Rasvjeta", "izvrsni", "", None, None), ("Pumpa navodnjavanja", "izvrsni", "", None, None),
    ("Ventilator", "izvrsni", "", None, None), ("Grijač", "izvrsni", "", None, None),
    ("Prozor (otvaranje)", "izvrsni", "%", 0, 100), ("Dozator", "izvrsni", "ml", None, None),
    ("Zračna pumpa", "izvrsni", "", None, None), ("Cirkulacijska pumpa", "izvrsni", "", None, None),
]
# pogon, sustav, [(vrsta, naziv, tema, min, max)]
KONT = [
    ("Pogon 1 (staklenik)", "Staklenik", ["Temperatura zraka", "Vlaga zraka", "Temperatura vode", "pH", "EC", "Razina vode",
        "Rasvjeta", "Cirkulacijska pumpa", "Ventilator", "Dozator", "Dozator"]),
    ("Pogon 2 (polje)", "Polje", ["Temperatura zraka", "Vlaga zraka", "Temperatura tla", "Vlaga tla", "Rasvjeta",
        "Pumpa navodnjavanja", "Prozor (otvaranje)"]),
    ("Pogon 3 (tunel)", "Tunel", ["Temperatura zraka", "Temperatura vode", "pH", "Razina vode", "Zračna pumpa",
        "Cirkulacijska pumpa"]),
]

def seed(c):
    q = c.execute
    if q("select count(*) from vrste_uredjaja").fetchone()[0]:
        print("katalog već postoji"); return
    q("insert into lokacije(naziv) values('Uzgajalište 1')")
    for s in SUSTAVI: q("insert into tehnologije(naziv) values(?)", (s,))
    for v in VRSTE: q("insert into vrste_uredjaja(naziv,uloga,jedinica,min_zadano,max_zadano) values(?,?,?,?,?)", v)
    q("insert into grupe_artikala(naziv) values('Gnojivo'),('Regulator pH'),('Zaštita'),('Sjeme'),('Supstrat')")
    q("insert into artikli(sifra,naziv,grupa_id,jmj,min_zaliha) values('G-A','Dodatak A',1,'ml',2000),('G-B','Dodatak B',1,'ml',2000),('PH-','Regulator pH',2,'ml',500)")
    q("insert into dobavljaci(naziv) values('Agro d.o.o.')")
    q("insert into primke(broj,datum,dobavljac_id) values('1','2026-01-01',1)")
    q("insert into primke_stavke(primka_id,artikl_id,kolicina,cijena,iznos) values(1,1,5000,0.004,20),(1,2,5000,0.004,20),(1,3,1000,0.006,6)")
    for i, (kn, sn, uredj) in enumerate(KONT, 1):
        sid = q("select id from tehnologije where naziv=?", (sn,)).fetchone()[0]
        pid = q("insert into pogoni(naziv,tip,lokacija_id,tehnologija_id,tema) values(?,?,1,?,?)", (kn, "pogon", sid, "procesi/p1/pogon%d" % i)).lastrowid
        n = {}
        for vn in uredj:
            vr = q("select id,min_zadano,max_zadano from vrste_uredjaja where naziv=?", (vn,)).fetchone()
            n[vn] = n.get(vn, 0) + 1
            nm = vn if n[vn] == 1 else "%s %d" % (vn, n[vn])
            art = None
            mlmin = None
            if vn == "Dozator":
                art = 3 if n[vn] == 1 and sn == "Staklenik" and False else (1 if n[vn] == 1 else 3)
                mlmin = 60
            tema = re.sub(r"[^a-z0-9_]", "", unicodedata.normalize("NFKD", nm.lower().replace(" ", "_")).encode("ascii", "ignore").decode())
            q("insert into uredjaji(pogon_id,vrsta_id,naziv,tema,min,max,ml_po_min,artikl_id,najdulje_s) values(?,?,?,?,?,?,?,?,?)",
              (pid, vr[0], nm, tema, vr[1], vr[2], mlmin, art, 120 if vn == "Dozator" else 0))
    # priključci za ESPHome generator
    hw = {1: {"Temperatura zraka": ("dht22", "4"), "Vlaga zraka": ("dht22", "4"), "Temperatura vode": ("ds18b20", "25"), "pH": ("adc", "34", 3.5, 0),
              "EC": ("adc", "35", 1.5, 0), "Razina vode": ("adc", "32", 30.0, 0), "Rasvjeta": ("rele", "16", None, None, True),
              "Cirkulacijska pumpa": ("rele", "17", None, None, True), "Ventilator": ("rele", "18", None, None, True),
              "Dozator": ("dozator", "19", None, None, True), "Dozator 2": ("dozator", "23", None, None, True)},
          2: {"Temperatura zraka": ("dht22", "4"), "Vlaga zraka": ("dht22", "4"), "Temperatura tla": ("ds18b20", "25"), "Vlaga tla": ("adc", "34", 40.0, 0),
              "Rasvjeta": ("rele", "16", None, None, True), "Pumpa navodnjavanja": ("rele", "17", None, None, True),
              "Prozor (otvaranje)": ("prozor", "18", None, None, True, "19")},
          3: {"Temperatura zraka": ("sht3x", None, None, None, False, None, "0x44"), "Temperatura vode": ("ds18b20", "25"), "pH": ("adc", "34", 3.5, 0),
              "Razina vode": ("adc", "32", 30.0, 0), "Zračna pumpa": ("rele", "16", None, None, True), "Cirkulacijska pumpa": ("rele", "17", None, None, True)}}
    for pr, m in hw.items():
        for nm, h in m.items():
            model, pin = h[0], h[1]
            ka = h[2] if len(h) > 2 else None
            kb = h[3] if len(h) > 3 else None
            inv = 1 if len(h) > 4 and h[4] else 0
            pin2 = h[5] if len(h) > 5 else None
            adr = h[6] if len(h) > 6 else None
            q("update uredjaji set model=?, pin=?, pin2=?, adresa=?, invertirano=?, kal_a=?, kal_b=? where pogon_id=? and naziv=?", (model, pin, pin2, adr, inv, ka, kb, pr, nm))
    q("update uredjaji set najdulje_s=30 where naziv like 'Prozor%'")
    q("update uredjaji set najdulje_s=7200 where naziv='Pumpa navodnjavanja'")
    # pravilo: pH iznad granice -> dozator 2 doze Regulator pH (u pogonu 1)
    ph = q("select u.id from uredjaji u join vrste_uredjaja v on v.id=u.vrsta_id where u.pogon_id=1 and v.naziv='pH'").fetchone()[0]
    dz = q("select u.id from uredjaji u where u.pogon_id=1 and u.naziv='Dozator 2'").fetchone()[0]
    q("insert into pravila(naziv,senzor_id,operator,prag,izvrsni_id,akcija,kolicina,min_razmak_min,max_dnevno) values('pH previsok: dodaj Regulator pH',?,'>',6.5,?,'doziraj',10,60,6)", (ph, dz))
    # rasporedi: svjetlo 06-22 h, pumpa navodnjavanja svakih 3 h po 2 min, cirkulacija stalno
    def uid(prostor, naziv):
        r = q("select id from uredjaji where pogon_id=? and naziv=?", (prostor, naziv)).fetchone()
        return r[0] if r else None
    plan = [(1, "Rasvjeta", "Rasvjeta 06-22", [("1234567", "06:00", "22:00", 0, 0)]),
            (1, "Cirkulacijska pumpa", "Cirkulacija", [("1234567", "00:00", "24:00", 0, 0)]),
            (2, "Rasvjeta", "Rasvjeta 05-23", [("1234567", "05:00", "23:00", 0, 0)]),
            (2, "Pumpa navodnjavanja", "Zalijevanje", [("1234567", None, None, 180, 120)])]
    for pr, naz, rn, st in plan:
        u = uid(pr, naz)
        if not u: continue
        rid = q("insert into rasporedi(uredjaj_id,naziv,aktivan,izvor) values(?,?,1,'lokalno')", (u, rn)).lastrowid
        for d, od, do, sv, tr in st:
            q("insert into rasporedi_stavke(raspored_id,dani,od,do,svakih_min,trajanje_s) values(?,?,?,?,?,?)", (rid, d, od, do, sv, tr))
    print("seed gotov")

def run(c, steps):
    q = c.execute
    senz = q("select u.id,u.pogon_id,v.naziv,u.min,u.max from uredjaji u join vrste_uredjaja v on v.id=u.vrsta_id where v.uloga='senzor'").fetchall()
    base = {"Temperatura zraka": 24, "Temperatura tla": 20, "Temperatura vode": 20, "Vlaga zraka": 62, "Vlaga tla": 55, "pH": 6.2,
            "EC": 1.8, "Razina vode": 80, "Osvijetljenost": 12000, "CO2": 600}
    for k in range(steps):
        now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        t = time.time() / 3600.0
        for uid, pid, nm, mn, mx in senz:
            v = base.get(nm, 0) + math.sin(t + uid) * (base.get(nm, 0) * 0.05) + random.uniform(-0.1, 0.1) * max(1, base.get(nm, 0)) * 0.05
            if nm == "pH":
                last = q("select vrijednost from ocitanja where uredjaj_id=? order by vrijeme desc, id desc limit 1", (uid,)).fetchone()
                v = (last[0] if last else 6.2) + random.uniform(-0.02, 0.06)
            q("insert into ocitanja(uredjaj_id,vrijeme,vrijednost) values(?,?,?)", (uid, now, round(v, 3)))
            q("update pogoni set zadnji_signal=? where id=?", (now, pid))
        # pravila automatike
        for pid_, naz, sid, op, prag, iz, akc, kol, razmak, maxd in q("select id,naziv,senzor_id,operator,prag,izvrsni_id,akcija,kolicina,min_razmak_min,max_dnevno from pravila where coalesce(aktivan,1)=1").fetchall():
            v = q("select vrijednost from ocitanja where uredjaj_id=? order by vrijeme desc, id desc limit 1", (sid,)).fetchone()
            if not v: continue
            ok = v[0] > prag if op == ">" else v[0] < prag
            if not ok: continue
            zadnja = q("select vrijeme from naredbe where uredjaj_id=? and izvor='pravilo' order by vrijeme desc, id desc limit 1", (iz,)).fetchone()
            if zadnja and (datetime.now() - datetime.strptime(zadnja[0], "%Y-%m-%d %H:%M:%S")).total_seconds() < razmak * 60: continue
            danas = q("select count(*) from naredbe where uredjaj_id=? and izvor='pravilo' and date(vrijeme)=date('now','localtime')", (iz,)).fetchone()[0]
            if maxd and danas >= maxd:
                q("insert into alarmi(uredjaj_id,vrijeme,vrsta,poruka) values(?,?,'doziranje','Dosegnut dnevni najviše: '||?)", (iz, now, naz)); continue
            art = q("select artikl_id from uredjaji where id=?", (iz,)).fetchone()[0]
            q("insert into naredbe(uredjaj_id,vrijeme,akcija,artikl_id,kolicina,izvor,stanje) values(?,?,?,?,?,'pravilo','izvrseno')", (iz, now, akc, art, kol))
            q("insert into ocitanja(uredjaj_id,vrijeme,vrijednost) values(?,?,?)", (sid, now, round(v[0] - 0.4, 3)))   # doza spusti pH
        # alarmi izvan granica
        for uid, pid, nm, mn, mx in senz:
            v = q("select vrijednost from ocitanja where uredjaj_id=? order by vrijeme desc, id desc limit 1", (uid,)).fetchone()[0]
            if (mn is not None and v < mn) or (mx is not None and v > mx):
                if not q("select 1 from alarmi where uredjaj_id=? and coalesce(potvrdjeno,0)=0 and vrsta='granica'", (uid,)).fetchone():
                    q("insert into alarmi(uredjaj_id,pogon_id,vrijeme,vrsta,poruka) values(?,?,?,'granica',?)", (uid, pid, now, "%s izvan granica: %.2f" % (nm, v)))
        if steps > 1: time.sleep(0.05)
    print("upisano koraka:", steps)

def on_now(stavke, when=None):
    """Je li izlaz po rasporedu sada uključen (od-do, ponoćni prijelaz, ponavljanje svakih N min po M s)."""
    when = when or datetime.now()
    dan = str(when.isoweekday())
    mins = when.hour * 60 + when.minute
    secs = mins * 60 + when.second
    for e in stavke:
        sv = e.get("svakih_min") or 0
        if dan not in e.get("dani", "1234567") and not (e.get("od") and e.get("do") and e["od"] > e["do"]): continue
        if sv:
            if secs % (sv * 60) < (e.get("trajanje_s") or 0): return True
            continue
        od = e.get("od"); do = e.get("do")
        if not od or not do: continue
        a = int(od[:2]) * 60 + int(od[3:5]); b = int(do[:2]) * 60 + int(do[3:5])
        jucer = str(7 if when.isoweekday() == 1 else when.isoweekday() - 1)
        if a <= b and a <= mins < b: return True
        if a > b and mins >= a: return True
        if a > b and mins < b and jucer in e.get("dani", "1234567"): return True
    return False

def mqtt(c, steps, port):
    """Objavljuje vrijednosti senzora na MQTT kao ESP32; sluša naredbe (doza Regulator pH spusti pH)."""
    import subprocess, threading
    q = c.execute
    dev = q("select u.id,p.tema,u.tema,v.naziv,v.uloga from uredjaji u join pogoni p on p.id=u.pogon_id "
            "join vrste_uredjaja v on v.id=u.vrsta_id where u.tema is not null").fetchall()
    base = {"Temperatura zraka": 24, "Temperatura tla": 20, "Temperatura vode": 20, "Vlaga zraka": 62, "Vlaga tla": 55, "pH": 6.2,
            "EC": 1.8, "Razina vode": 80, "Osvijetljenost": 12000, "CO2": 600}
    ph = {}
    def pub(t, m):
        subprocess.run(["mosquitto_pub", "-p", str(port), "-t", t, "-m", str(m)], check=False)
    sched = {}
    override = {}
    no_ack = bool(__import__('os').environ.get('SIM_NO_ACK'))
    holder = []
    def listen():
        p = subprocess.Popen(["mosquitto_sub", "-p", str(port), "-v", "-t", "procesi/+/+/+/set", "-t", "procesi/+/+/+/raspored", "-F", "%t\t%p"], stdout=subprocess.PIPE, text=True)
        holder.append(p)
        for line in p.stdout:
            t, m = line.rstrip("\n").split("\t", 1)
            if t.endswith("/raspored"):
                try: sched[t[:-len("/raspored")]] = json.loads(m)["stavke"] if m else []
                except ValueError: pass
                print("raspored", t, m[:80])
                continue
            print("naredba", t, m)
            try:
                cmd = json.loads(m)
            except ValueError:
                cmd = {}
            dev_key = t[:-len("/set")]
            if cmd.get("akcija") in ("ukljuci", "iskljuci"):
                override[dev_key] = ("ON" if cmd["akcija"] == "ukljuci" else "OFF", time.time() + 20)
            if cmd.get("id") is not None and not no_ack:
                pub(dev_key + "/ack", json.dumps({"id": cmd["id"]}))
            for pre, ut, nm in [(d[1], d[2], d[3]) for d in dev]:
                if nm == "Dozator" and t.startswith(pre + "/"):
                    for k in ph:
                        if k[0] == pre: ph[k] -= 0.4
    threading.Thread(target=listen, daemon=True).start()
    time.sleep(0.5)
    for _ in range(steps):
        for uid, pre, ut, nm, uloga in dev:
            if uloga != "senzor": continue
            if nm == "pH":
                ph[(pre, ut)] = ph.get((pre, ut), 6.2) + random.uniform(-0.02, 0.08)
                v = ph[(pre, ut)]
            else:
                v = base.get(nm, 0) * (1 + random.uniform(-0.03, 0.03))
            pub("%s/%s/stanje" % (pre, ut), round(v, 3))
        # izvrsni uredjaji: stanje prema primljenom rasporedu
        for uid, pre, ut, nm, uloga in dev:
            k = "%s/%s" % (pre, ut)
            if uloga == "izvrsni" and k in override and override[k][1] > time.time():
                pub(k + "/stanje", override[k][0])
            elif uloga == "izvrsni" and k in sched:
                pub(k + "/stanje", "ON" if on_now(sched[k]) else "OFF")
        time.sleep(0.2)
    time.sleep(1)
    for p in holder: p.kill()

if __name__ == "__main__":
    if len(sys.argv) < 3 or sys.argv[1] not in ("seed", "run", "mqtt"):
        print(__doc__); sys.exit(1)
    c = sqlite3.connect(sys.argv[2])
    c.execute("pragma foreign_keys=on")
    if sys.argv[1] == "seed": seed(c)
    elif sys.argv[1] == "mqtt": mqtt(c, int(sys.argv[3]) if len(sys.argv) > 3 else 1, int(sys.argv[4]) if len(sys.argv) > 4 else 1883)
    else: run(c, int(sys.argv[3]) if len(sys.argv) > 3 else 1)
    c.commit()
