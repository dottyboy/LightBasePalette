#!/usr/bin/env python3
"""Most MQTT <-> baza za primjer procesi.opis (samo standardna biblioteka; treba mosquitto_sub i mosquitto_pub).

  procesi_most.py Procesi.db [--host localhost] [--port 1883] [--user U --password P]

Teme (prefiks pogona je pogoni.tema, npr. procesi/p1/pogon1; naziv uređaja je uredjaji.tema):
  <prefiks>/<uređaj>/stanje   (ESP32 -> most)  broj ili ON/OFF; upisuje se u ocitanja
  <prefiks>/status            (ESP32 -> most)  online / offline (last will); ažurira zadnji signal, offline daje alarm
  <prefiks>/<uređaj>/set      (most -> ESP32)  JSON {"id","akcija","vrijednost","kolicina","trajanje_s"} za svaku naredbu sa stanjem "cekanje" (stanje postaje "poslano")
  <prefiks>/<uređaj>/ack      (ESP32 -> most)  JSON {"id": N}: uređaj je naredbu izvršio ("izvrseno"); bez potvrde u 30 s je "pogreska" i alarm
  <prefiks>/<uređaj>/raspored (most -> ESP32, retained) JSON {"verzija","izvor","stavke":[{"dani","od","do","svakih_min","trajanje_s"}]}
  <prefiks>/<uređaj>/raspored/lokalno (ESP32 -> most) isti oblik bez verzije: raspored složen na licu mjesta; most ga upisuje u bazu (izvor "lokalno")
Pravila automatike (tablica pravila) izvršava most: nastaje naredba, ona se objavi na set, a doziranje ulazi u zalihu."""
import argparse, hashlib, json, queue, sqlite3, subprocess, threading, time
from datetime import datetime

def now():
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")

class Most:
    def __init__(self, db, host, port, user, password):
        self.db, self.host, self.port, self.user, self.password = db, host, port, user, password
        self.c = sqlite3.connect(db, check_same_thread=False)
        self.lock = threading.Lock()
        self.q = queue.Queue()
        self.stop = False
        self.sched_hash = {}
        self.bad = {}            # uredjaj_id -> uzastopna ocitanja izvan granica
        self.ack_wait = 30
        self.silent_min = 5
        self.reload()

    def reload(self):
        with self.lock:
            self.dev = {}   # (prefiks, tema uređaja) -> (uredjaj_id, pogon_id, uloga)
            self.pre = {}   # prefiks -> pogon_id
            for pid, tema in self.c.execute("select id, tema from pogoni where tema is not null and tema <> ''"):
                self.pre[tema] = pid
            for uid, pid, tema, uloga, ptema in self.c.execute(
                    "select u.id,u.pogon_id,u.tema,v.uloga,p.tema from uredjaji u join vrste_uredjaja v on v.id=u.vrsta_id "
                    "join pogoni p on p.id=u.pogon_id where u.tema is not null and u.tema <> ''"):
                self.dev[(ptema, tema)] = (uid, pid, uloga)

    def auth(self):
        a = ["-h", self.host, "-p", str(self.port)]
        if self.user: a += ["-u", self.user, "-P", self.password or ""]
        return a

    def publish(self, topic, payload, retain=False):
        subprocess.run(["mosquitto_pub"] + self.auth() + (["-r"] if retain else []) + ["-t", topic, "-m", payload], check=False, timeout=10)

    # ---------- MQTT -> baza ----------
    def listen(self):
        while not self.stop:
            p = subprocess.Popen(["mosquitto_sub"] + self.auth() + ["-v", "-t", "procesi/#", "-F", "%t\t%p"],
                                 stdout=subprocess.PIPE, text=True)
            for line in p.stdout:
                self.q.put(line.rstrip("\n"))
                if self.stop: break
            p.kill()
            time.sleep(2)

    def handle(self, line):
        if "\t" not in line: return
        topic, payload = line.split("\t", 1)
        parts = topic.split("/")
        if parts[-1] == "status":
            pid = self.pre.get("/".join(parts[:-1]))
            if pid is None: return
            with self.lock:
                if payload.strip().lower() == "online":
                    self.c.execute("update pogoni set zadnji_signal=? where id=?", (now(), pid))
                    self.c.execute("update alarmi set zatvoreno=? where pogon_id=? and vrsta='veza' and zatvoreno is null", (now(), pid))
                else:
                    self.open_alarm(None, pid, "veza", "Pogon nije dostupan")
                self.c.commit()
            return
        if parts[-1] == "ack" and len(parts) >= 3:
            try:
                nid = int(json.loads(payload).get("id"))
            except (ValueError, TypeError, AttributeError):
                return
            with self.lock:
                self.c.execute("update naredbe set stanje='izvrseno' where id=? and stanje='poslano'", (nid,))
                self.c.commit()
            return
        if len(parts) >= 4 and parts[-1] == "lokalno" and parts[-2] == "raspored":
            self.ingest_local("/".join(parts[:-3]), parts[-3], payload)
            return
        if parts[-1] != "stanje" or len(parts) < 3: return
        key = ("/".join(parts[:-2]), parts[-2])
        d = self.dev.get(key)
        if not d: return
        uid, pid, uloga = d
        p = payload.strip()
        try:
            v = float(p)
        except ValueError:
            v = 1.0 if p.upper() in ("ON", "TRUE", "1") else 0.0
        with self.lock:
            self.c.execute("insert into ocitanja(uredjaj_id,vrijeme,vrijednost) values(?,?,?)", (uid, now(), v))
            self.c.execute("update pogoni set zadnji_signal=? where id=?", (now(), pid))
            self.alarm_limits(uid, pid, v)
            if uloga == "senzor": self.rules(uid, v)
            self.c.commit()

    def open_alarm(self, uid, pid, vrsta, poruka):
        """Novi alarm samo ako za isti uređaj/pogon i vrstu već nema otvorenog."""
        if uid is not None:
            ex = self.c.execute("select 1 from alarmi where uredjaj_id=? and vrsta=? and zatvoreno is null", (uid, vrsta)).fetchone()
        else:
            ex = self.c.execute("select 1 from alarmi where pogon_id=? and uredjaj_id is null and vrsta=? and zatvoreno is null", (pid, vrsta)).fetchone()
        if not ex:
            self.c.execute("insert into alarmi(uredjaj_id,pogon_id,vrijeme,vrsta,poruka) values(?,?,?,?,?)", (uid, pid, now(), vrsta, poruka))

    def alarm_limits(self, uid, pid, v):
        mn, mx, nm = self.c.execute("select min,max,naziv from uredjaji where id=?", (uid,)).fetchone()
        out = (mn is not None and v < mn) or (mx is not None and v > mx)
        if out:
            self.bad[uid] = self.bad.get(uid, 0) + 1
            if self.bad[uid] >= 2:      # dva uzastopna očitanja izvan granica (jedan šum ne diže alarm)
                self.open_alarm(uid, pid, "granica", "%s izvan granica: %.2f" % (nm, v))
        else:
            self.bad[uid] = 0
            self.c.execute("update alarmi set zatvoreno=? where uredjaj_id=? and vrsta='granica' and zatvoreno is null", (now(), uid))

    # ---------- pravila automatike ----------
    def rules(self, sensor_id, v):
        for rid, naz, op, prag, iz, akc, kol, razmak, maxd in self.c.execute(
                "select id,naziv,operator,prag,izvrsni_id,akcija,kolicina,min_razmak_min,max_dnevno from pravila "
                "where senzor_id=? and coalesce(aktivan,1)=1", (sensor_id,)).fetchall():
            if not (v > prag if op == ">" else v < prag): continue
            zadnja = self.c.execute("select vrijeme from naredbe where uredjaj_id=? and izvor='pravilo' order by vrijeme desc, id desc limit 1", (iz,)).fetchone()
            if zadnja and (datetime.now() - datetime.strptime(zadnja[0], "%Y-%m-%d %H:%M:%S")).total_seconds() < (razmak or 0) * 60: continue
            danas = self.c.execute("select count(*) from naredbe where uredjaj_id=? and izvor='pravilo' and date(vrijeme)=date('now','localtime')", (iz,)).fetchone()[0]
            if maxd and danas >= maxd:
                self.open_alarm(iz, None, "doziranje", "Dosegnut dnevni najviše: " + naz)
                continue
            art = self.c.execute("select artikl_id from uredjaji where id=?", (iz,)).fetchone()[0]
            self.c.execute("insert into naredbe(uredjaj_id,vrijeme,akcija,artikl_id,kolicina,izvor,stanje) values(?,?,?,?,?,'pravilo','cekanje')",
                           (iz, now(), akc, art if akc == "doziraj" else None, kol if akc == "doziraj" else 0))

    # ---------- rasporedi ----------
    def schedule_json(self, uid):
        """Svi aktivni rasporedi uređaja spojeni u jedan JSON (None ako ih nema)."""
        rs = self.c.execute("select id, izvor from rasporedi where uredjaj_id=? and coalesce(aktivan,1)=1 order by id", (uid,)).fetchall()
        if not rs: return None
        st = []
        for rid, _ in rs:
            for dani, od, do, sv, tr in self.c.execute("select dani,od,do,svakih_min,trajanje_s from rasporedi_stavke where raspored_id=? order by id", (rid,)):
                e = {"dani": dani or "1234567"}
                if sv: e.update({"svakih_min": sv, "trajanje_s": tr or 0})
                if od: e["od"] = od
                if do: e["do"] = do
                st.append(e)
        return {"izvor": rs[0][1] or "lokalno", "stavke": st}

    def sync_schedules(self):
        with self.lock:
            for (pre, tema), (uid, pid, uloga) in self.dev.items():
                if uloga != "izvrsni": continue
                js = self.schedule_json(uid)
                if js is None:
                    if uid in self.sched_hash:       # raspored je uklonjen: ocisti zadržanu poruku
                        self.publish("%s/%s/raspored" % (pre, tema), "", retain=True)
                        del self.sched_hash[uid]
                    continue
                h = json.dumps(js, sort_keys=True)
                if self.sched_hash.get(uid) == h: continue
                js["verzija"] = str(abs(hash(h)) % 10**8)
                self.publish("%s/%s/raspored" % (pre, tema), json.dumps(js), retain=True)
                self.sched_hash[uid] = h

    def ingest_local(self, pre, tema, payload):
        d = self.dev.get((pre, tema))
        if not d: return
        try:
            js = json.loads(payload)
        except ValueError:
            return
        uid = d[0]
        with self.lock:
            r = self.c.execute("select id from rasporedi where uredjaj_id=? and coalesce(aktivan,1)=1 order by id limit 1", (uid,)).fetchone()
            if r: rid = r[0]
            else: rid = self.c.execute("insert into rasporedi(uredjaj_id,naziv,aktivan,izvor) values(?,?,1,'lokalno')", (uid, "Lokalni raspored")).lastrowid
            self.c.execute("delete from rasporedi_stavke where raspored_id=?", (rid,))
            for e in js.get("stavke", []):
                self.c.execute("insert into rasporedi_stavke(raspored_id,dani,od,do,svakih_min,trajanje_s) values(?,?,?,?,?,?)",
                               (rid, e.get("dani", "1234567"), e.get("od"), e.get("do"), e.get("svakih_min", 0), e.get("trajanje_s", 0)))
            self.c.execute("update rasporedi set izvor='lokalno', predlozak_id=NULL where id=?", (rid,))   # izmjena na uređaju odvaja raspored od predloška
            self.c.execute("insert into alarmi(uredjaj_id,vrijeme,vrsta,poruka,potvrdjeno) values(?,?,'raspored','Raspored promijenjen na uređaju',1)", (uid, now()))
            self.c.commit()

    # ---------- predlošci rasporeda ----------
    def templates(self):
        """Verzija predloška raste kad se promijene njegove stavke (otisak); rasporedi koji ga prate i imaju 'automatski' dobivaju nove stavke."""
        with self.lock:
            tabs = {r[0] for r in self.c.execute("select name from sqlite_master where type='table'")}
            if "predlosci_rasporeda" not in tabs: return 0
            for pid, ots, ver in self.c.execute("select id, otisak, verzija from predlosci_rasporeda").fetchall():
                items = self.c.execute("select dani,od,do,svakih_min,trajanje_s from predlosci_stavke where predlozak_id=? order by id", (pid,)).fetchall()
                h = hashlib.sha1(json.dumps(items).encode()).hexdigest()[:12]
                if h != ots:
                    self.c.execute("update predlosci_rasporeda set otisak=?, verzija=? where id=?", (h, (ver or 1) + (1 if ots else 0), pid))
            n = 0
            for rid, pid, naz, ver in self.c.execute(
                    "select r.id, r.predlozak_id, p.naziv, p.verzija from rasporedi r join predlosci_rasporeda p on p.id = r.predlozak_id "
                    "where coalesce(r.automatski,1)=1 and coalesce(r.predlozak_verzija,0) < coalesce(p.verzija,1)").fetchall():
                self.c.execute("delete from rasporedi_stavke where raspored_id=?", (rid,))
                self.c.execute("insert into rasporedi_stavke(raspored_id,dani,od,do,svakih_min,trajanje_s) "
                               "select ?,dani,od,do,svakih_min,trajanje_s from predlosci_stavke where predlozak_id=? order by id", (rid, pid))
                self.c.execute("update rasporedi set predlozak_verzija=?, izvor=? where id=?", (ver or 1, "predlozak: %s v%s" % (naz, ver or 1), rid))
                n += 1
            self.c.commit()
            return n

    # ---------- baza -> MQTT ----------
    def send_pending(self):
        with self.lock:
            rows = self.c.execute(
                "select n.id,n.akcija,n.vrijednost,n.kolicina,u.tema,p.tema,u.ml_po_min,u.najdulje_s from naredbe n "
                "join uredjaji u on u.id=n.uredjaj_id join pogoni p on p.id=u.pogon_id where n.stanje='cekanje'").fetchall()
            for nid, akc, vr, kol, ut, pt, mlmin, maxs in rows:
                if not ut or not pt:
                    self.c.execute("update naredbe set stanje='pogreska' where id=?", (nid,)); continue
                msg = {"id": nid, "akcija": akc, "vrijednost": vr, "kolicina": kol}
                if akc == "doziraj" and mlmin:
                    msg["trajanje_s"] = min(round(float(kol or 0) / float(mlmin) * 60, 1), float(maxs) if maxs else 1e9)
                self.publish("%s/%s/set" % (pt, ut), json.dumps(msg))
                self.c.execute("update naredbe set stanje='poslano', vrijeme=coalesce(vrijeme, ?) where id=?", (now(), nid))
            self.c.commit()

    def check_acks_and_signal(self):
        """Naredba bez potvrde u ack_wait sekundi je pogreška; pogon bez signala dulje od silent_min minuta daje alarm."""
        with self.lock:
            lim = datetime.now().timestamp() - self.ack_wait
            for nid, uid, vr in self.c.execute("select id, uredjaj_id, vrijeme from naredbe where stanje='poslano'").fetchall():
                try:
                    t = datetime.strptime(vr, "%Y-%m-%d %H:%M:%S").timestamp()
                except (ValueError, TypeError):
                    continue
                if t < lim:
                    self.c.execute("update naredbe set stanje='pogreska' where id=?", (nid,))
                    self.open_alarm(uid, None, "naredba", "Naredba nije potvrđena (%d)" % nid)
            lim2 = datetime.now().timestamp() - self.silent_min * 60
            for pid, zs in self.c.execute("select id, zadnji_signal from pogoni where tema is not null and tema <> '' and zadnji_signal is not null").fetchall():
                try:
                    t = datetime.strptime(zs, "%Y-%m-%d %H:%M:%S").timestamp()
                except ValueError:
                    continue
                if t < lim2:
                    self.open_alarm(None, pid, "veza", "Nema signala više od %d min" % self.silent_min)
            self.c.commit()

    def run(self):
        threading.Thread(target=self.listen, daemon=True).start()
        last_reload = time.time()
        last_check = 0
        while True:
            t0 = time.time()
            try:
                self.handle(self.q.get(timeout=0.5))
                while time.time() - t0 < 0.5:      # obradi što stigne, ali najviše pola sekunde pa na periodične poslove
                    self.handle(self.q.get_nowait())
            except queue.Empty:
                pass
            self.send_pending()
            self.templates()
            self.sync_schedules()
            if time.time() - last_check > 5:
                self.check_acks_and_signal(); last_check = time.time()
            if time.time() - last_reload > 30:
                self.reload(); last_reload = time.time()

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("db")
    ap.add_argument("--host", default="localhost")
    ap.add_argument("--port", type=int, default=1883)
    ap.add_argument("--user")
    ap.add_argument("--password")
    ap.add_argument("--ack-wait", type=int, default=30, help="sekunde do greške ako uređaj ne potvrdi naredbu")
    ap.add_argument("--silent-min", type=int, default=5, help="minute bez signala do alarma veze")
    a = ap.parse_args()
    m = Most(a.db, a.host, a.port, a.user, a.password)
    m.ack_wait, m.silent_min = a.ack_wait, a.silent_min
    m.run()
