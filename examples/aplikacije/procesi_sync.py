#!/usr/bin/env python3
"""Povezivanje lokacija sa središnjom bazom (SQLite, samo standardna biblioteka).

Svaka lokacija ima svoju bazu (lokalno radi bez središta). Središnja baza je ista aplikacija (isti procesi.opis) koja skuplja sve lokacije.

  GORE (lokacija -> središte)   zapisi lokacije; id svakog zapisa i svi njegovi vanjski ključevi pomiču se za  broj_lokacije * 1.000.000.000,
                                pa se zapisi različitih lokacija ne sudaraju (središnji id / 1e9 = broj lokacije).
                                ocitanja se šalju samo novija od zadnje poslanih; ostale tablice se šalju cijele (male su) uz brisanje
                                središnjih zapisa te lokacije kojih lokalno više nema. Ponovno slanje je bezopasno (zamjena po id-u).
  DOLJE (središte -> lokacija)  zajednički šifrarnici i predlošci rasporeda; lokalne kopije se zamjenjuju. Uređuju se SAMO u središtu.

  procesi_sync.py sinkroniziraj --local Lok.db --site 2 --central Sredina.db [--interval 300]
  procesi_sync.py gore   --local Lok.db --site 2 (--central Sredina.db | --paket gore.json.gz) [--sve]
  procesi_sync.py dolje  --central Sredina.db (--local Lok.db | --paket dolje.json.gz)
  procesi_sync.py uvezi-gore  --central Sredina.db --paket gore.json.gz        (paket stigao drugim putem: rsync, scp, USB)
  procesi_sync.py uvezi-dolje --local Lok.db --paket dolje.json.gz
Paket je JSON sažet gzipom, pa putuje bilo kojim prijenosom."""
import argparse, gzip, json, sqlite3, sys, time
from datetime import datetime

OFF = 1_000_000_000
UP_FULL = ["lokacije", "pogoni", "uredjaji", "rasporedi", "rasporedi_stavke", "pravila", "artikli", "dobavljaci", "serije", "radnje",
           "radnje_potrosnja", "mjerenja", "prinosi", "primke", "primke_stavke", "naredbe", "alarmi"]
UP_APPEND = ["ocitanja"]
DOWN = ["vrste_uredjaja", "tehnologije", "grupe_artikala", "vrste_radnji", "vrste_proizvoda", "faze", "predlosci_rasporeda", "predlosci_stavke"]
UP = UP_FULL + UP_APPEND

def now(): return datetime.now().strftime("%Y-%m-%d %H:%M:%S")

def tables(c): return {r[0] for r in c.execute("select name from sqlite_master where type='table'")}
def cols(c, t): return [r[1] for r in c.execute('pragma table_info("%s")' % t)]
def fks(c, t): return {r[3]: r[2] for r in c.execute('pragma foreign_key_list("%s")' % t)}

def ensure_state(c):
    c.execute("create table if not exists sync_stanje (id integer primary key autoincrement, tablica text, zadnji_id integer default 0)")

def watermark(c, t):
    r = c.execute("select zadnji_id from sync_stanje where tablica=?", (t,)).fetchone()
    return r[0] if r and r[0] else 0

def set_watermark(c, t, v):
    if c.execute("select 1 from sync_stanje where tablica=?", (t,)).fetchone():
        c.execute("update sync_stanje set zadnji_id=? where tablica=?", (v, t))
    else:
        c.execute("insert into sync_stanje(tablica, zadnji_id) values(?,?)", (t, v))

# ---------- paketi ----------
def write_pkg(path, pkg):
    with gzip.open(path, "wt", encoding="utf-8") as f: json.dump(pkg, f)

def read_pkg(path):
    with gzip.open(path, "rt", encoding="utf-8") as f: return json.load(f)

# ---------- gore ----------
def export_up(local, site, full=False):
    c = sqlite3.connect(local)
    ensure_state(c)
    have = tables(c)
    off = site * OFF
    up_set = set(UP)
    pkg = {"verzija": 1, "smjer": "gore", "site": site, "vrijeme": now(), "tablice": {}}
    marks = {}
    for t in UP:
        if t not in have: continue
        cl = cols(c, t)
        fk = fks(c, t)
        mode = "dodaj" if t in UP_APPEND else "puni"
        sql = 'select %s from "%s"' % (", ".join('"%s"' % x for x in cl), t)
        if mode == "dodaj" and not full:
            sql += " where id > %d" % watermark(c, t)
        rows = []
        for r in c.execute(sql + " order by id"):
            out = []
            for name, v in zip(cl, r):
                if v is not None and (name == "id" or (name in fk and fk[name] in up_set)):
                    v = int(v) + off
                if t == "lokacije" and name == "broj": v = site
                out.append(v)
            rows.append(out)
        if mode == "dodaj" and rows:
            marks[t] = max(r[cl.index("id")] for r in rows) - off
        pkg["tablice"][t] = {"nacin": mode, "stupci": cl, "redci": rows}
    return pkg, marks, c

def import_up(central, pkg):
    c = sqlite3.connect(central)
    c.execute("pragma foreign_keys=off")
    site = pkg["site"]
    lo, hi = site * OFF, (site + 1) * OFF
    have = tables(c)
    total = 0
    for t, d in pkg["tablice"].items():
        if t not in have:
            print("preskačem", t, "(nema u središtu)"); continue
        cc = cols(c, t)
        use = [x for x in d["stupci"] if x in cc]
        idx = [d["stupci"].index(x) for x in use]
        ph = ",".join("?" * len(use))
        sql = 'insert or replace into "%s" (%s) values (%s)' % (t, ",".join('"%s"' % x for x in use), ph)
        ids = []
        for r in d["redci"]:
            c.execute(sql, [r[i] for i in idx])
            ids.append(r[d["stupci"].index("id")])
        total += len(d["redci"])
        if d["nacin"] == "puni":
            keep = set(ids)
            for (i,) in c.execute('select id from "%s" where id >= ? and id < ?' % t, (lo, hi)).fetchall():
                if i not in keep: c.execute('delete from "%s" where id=?' % t, (i,))
    if "sinkronizacije" in have:
        c.execute("insert into sinkronizacije(lokacija, vrijeme, smjer, redaka) values(?,?,?,?)", (site, now(), "gore", total))
    c.commit()
    c.close()
    return total

def cmd_gore(a):
    pkg, marks, lc = export_up(a.local, a.site, a.sve)
    if a.paket:
        write_pkg(a.paket, pkg)
        n = sum(len(d["redci"]) for d in pkg["tablice"].values())
    else:
        n = import_up(a.central, pkg)
    for t, v in marks.items(): set_watermark(lc, t, v)
    lc.commit(); lc.close()
    print("gore: %d redaka" % n)
    return n

def cmd_uvezi_gore(a):
    n = import_up(a.central, read_pkg(a.paket))
    print("uvezeno gore: %d redaka" % n)

# ---------- dolje ----------
def export_down(central):
    c = sqlite3.connect(central)
    have = tables(c)
    pkg = {"verzija": 1, "smjer": "dolje", "vrijeme": now(), "tablice": {}}
    for t in DOWN:
        if t not in have: continue
        cl = cols(c, t)
        rows = [list(r) for r in c.execute('select %s from "%s" order by id' % (", ".join('"%s"' % x for x in cl), t))]
        pkg["tablice"][t] = {"nacin": "puni", "stupci": cl, "redci": rows}
    c.close()
    return pkg

def import_down(local, pkg):
    c = sqlite3.connect(local)
    c.execute("pragma foreign_keys=off")
    have = tables(c)
    total = 0
    for t, d in pkg["tablice"].items():
        if t not in have: continue
        cc = cols(c, t)
        use = [x for x in d["stupci"] if x in cc]
        idx = [d["stupci"].index(x) for x in use]
        sql = 'insert or replace into "%s" (%s) values (%s)' % (t, ",".join('"%s"' % x for x in use), ",".join("?" * len(use)))
        ids = set()
        for r in d["redci"]:
            c.execute(sql, [r[i] for i in idx])
            ids.add(r[d["stupci"].index("id")])
        for (i,) in c.execute('select id from "%s"' % t).fetchall():
            if i not in ids: c.execute('delete from "%s" where id=?' % t, (i,))
        total += len(d["redci"])
    c.commit()
    c.close()
    return total

def cmd_dolje(a):
    pkg = export_down(a.central)
    if a.paket:
        write_pkg(a.paket, pkg); n = sum(len(d["redci"]) for d in pkg["tablice"].values())
    else:
        n = import_down(a.local, pkg)
    print("dolje: %d redaka" % n)

def cmd_uvezi_dolje(a):
    print("uvezeno dolje: %d redaka" % import_down(a.local, read_pkg(a.paket)))

def cmd_sinkroniziraj(a):
    while True:
        try:
            cmd_dolje(argparse.Namespace(central=a.central, local=a.local, paket=None))
            cmd_gore(argparse.Namespace(local=a.local, site=a.site, central=a.central, paket=None, sve=False))
        except sqlite3.Error as e:
            print("pogreška:", e, file=sys.stderr)
            if not a.interval: raise
        if not a.interval: break
        time.sleep(a.interval)

if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sp = ap.add_subparsers(dest="cmd", required=True)
    for name, fn in (("sinkroniziraj", cmd_sinkroniziraj), ("gore", cmd_gore), ("dolje", cmd_dolje), ("uvezi-gore", cmd_uvezi_gore), ("uvezi-dolje", cmd_uvezi_dolje)):
        p = sp.add_parser(name)
        p.add_argument("--local"); p.add_argument("--central"); p.add_argument("--paket")
        p.add_argument("--site", type=int); p.add_argument("--sve", action="store_true"); p.add_argument("--interval", type=int, default=0)
        p.set_defaults(fn=fn)
    a = ap.parse_args()
    if a.cmd in ("sinkroniziraj", "gore") and not a.site: ap.error("--site je obavezan")
    a.fn(a)
