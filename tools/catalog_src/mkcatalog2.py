import sys, os, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mkcatalog1 import *   # pomocne funkcije (ponovno zapisuje cetiri prve domene)

def check(dom):
    pks = {}
    for t in dom['tables']:
        pk = [f['name'] for f in t['fields'] if f.get('pk')][0]
        idx = [f['name'] for f in t['fields']].index(pk)
        pks[t['name']] = {r[idx] for r in t.get('sample', [])}
    for t in dom['tables']:
        names = [f['name'] for f in t['fields']]
        for r in t.get('sample', []):
            assert len(r) == len(names), (dom['id'], t['name'], len(r), len(names), r)
            for i, f in enumerate(t['fields']):
                if 'ref' in f and r[i] is not None:
                    rt = f['ref'].split('.')[0]
                    assert r[i] in pks[rt], (dom['id'], t['name'], f['name'], r[i])

def D(id_, title, descr, tags, tables):
    dom = {'id': id_, 'title': title, 'descr': descr, 'tags': tags, 'tables': tables}
    check(dom)
    write(dom)

def txt(name, cap, role, descr, **kw):
    return F(name, cap, 'text', role, descr, **kw)
def whole(name, cap, role, descr, **kw):
    return F(name, cap, 'integer', role, descr, **kw)
def dec(name, cap, role, descr, **kw):
    return F(name, cap, 'decimal', role, descr, **kw)
def cur(name, cap, role, descr, **kw):
    return F(name, cap, 'currency', role, descr, decimals=2, **kw)
def dt(name, cap, descr, **kw):
    return F(name, cap, 'date', 'datum', descr, **kw)
def flag(name, cap, descr, **kw):
    return F(name, cap, 'yesno', 'oznaka', descr, **kw)
def pos(msg='Vrijednost ne može biti negativna.'):
    return dict(validation='[value] >= 0', validation_msg=msg)
def gtz(msg='Vrijednost mora biti veća od nule.'):
    return dict(validation='[value] > 0', validation_msg=msg)
def ch(opts, default=None):
    d = {'choices': opts}
    if default: d['default'] = '"%s"' % default
    return d
def datum_rodjenja():
    return dt('datum_rodjenja', 'Datum rođenja', 'Datum rođenja osobe.')
def godina():
    return F('godina', 'Godina', 'integer', 'datum', 'Godina na koju se podatak odnosi.', required=True,
             validation='[value] >= 2000 And [value] <= 2100', validation_msg='Unesi godinu između 2000 i 2100.')
def mjesec():
    return F('mjesec', 'Mjesec', 'integer', 'datum', 'Mjesec (1-12).', required=True,
             validation='[value] >= 1 And [value] <= 12', validation_msg='Mjesec je od 1 do 12.')

# ========================= PAKET 1 =========================
D('skladiste', 'Skladište i zalihe',
  'Evidencija proizvoda na zalihi: dobavljači, lokacije u skladištu, ulazi i izlazi robe te narudžbe dobavljačima.',
  'posao,skladiste,nabava', [
  T('dobavljac', 'Dobavljači', 'Tvrtke od kojih se nabavlja roba.', [
    PK('Šifra dobavljača.'), naziv('Naziv tvrtke dobavljača.'), oib(), adresa(), postanski(), mjesto(), drzava(), email(), telefon(),
    whole('rok_isporuke', 'Rok isporuke (dana)', 'kolicina', 'Uobičajeno vrijeme od narudžbe do isporuke u danima.', default='7', **pos('Rok ne može biti negativan.')),
    aktivan()],
   [[1, 'Tehno-trgovina d.o.o.', '23456789012', 'Industrijska 4', '10020', 'Zagreb', 'Hrvatska', 'nabava@tehno-trgovina.hr', '01 600 1100', 5, 1],
    [2, 'Papir i ured d.o.o.', '34567890123', 'Slavonska 18', '31000', 'Osijek', 'Hrvatska', 'prodaja@papir-ured.hr', '031 250 300', 3, 1],
    [3, 'Elektro Veleprodaja', '45678901234', 'Obala 9', '51000', 'Rijeka', 'Hrvatska', 'info@elektro-vp.hr', '051 410 520', 10, 1]]),
  T('lokacija', 'Lokacije u skladištu', 'Police i prostori na kojima se roba drži.', [
    PK('Šifra lokacije.'), txt('oznaka_lokacije', 'Oznaka', 'identifikator', 'Kratka oznaka police (npr. A-01-3).', required=True, width=110),
    naziv('Naziv ili opis prostora.'), aktivan()],
   [[1, 'A-01', 'Hodnik A, polica 1', 1], [2, 'A-02', 'Hodnik A, polica 2', 1], [3, 'B-01', 'Hodnik B, police za sitnu robu', 1]]),
  T('proizvod', 'Proizvodi', 'Roba na zalihi s nabavnom i prodajnom cijenom te minimalnom zalihom.', [
    PK('Interna šifra proizvoda.'),
    F('kod', 'Kod', 'text', 'identifikator', 'Vlastita ili tvornička oznaka artikla (npr. barkod).', width=120),
    naziv('Naziv proizvoda.'), opis('Opis proizvoda.'),
    txt('jedinica_mjere', 'Jedinica', 'mjera', 'Jedinica u kojoj se roba vodi na zalihi.', **ch('kom,kg,l,m,pak,pal', 'kom')),
    REF('dobavljac_id', 'Dobavljač', 'dobavljac.sifra', 'Glavni dobavljač proizvoda.'),
    REF('lokacija_id', 'Lokacija', 'lokacija.sifra', 'Gdje se proizvod drži u skladištu.'),
    cur('nabavna_cijena', 'Nabavna cijena', 'cijena', 'Zadnja nabavna cijena po jedinici.', **pos('Cijena ne može biti negativna.')),
    cur('prodajna_cijena', 'Prodajna cijena', 'cijena', 'Cijena po kojoj se prodaje.', **pos('Cijena ne može biti negativna.')),
    dec('trenutna_zaliha', 'Zaliha', 'kolicina', 'Količina na skladištu; zbroj svih ulaza i izlaza.', decimals=2, default='0'),
    dec('min_zaliha', 'Minimalna zaliha', 'kolicina', 'Ispod ove količine treba naručiti.', decimals=2, default='0', **pos('Zaliha ne može biti negativna.')),
    aktivan()],
   [[1, 'VIJ-M6', 'Vijak M6x30', 'Pocinčani vijak', 'kom', 1, 1, 0.08, 0.15, 480, 200, 1],
    [2, 'PAP-A4', 'Papir A4 80g', 'Ris od 500 listova', 'pak', 2, 3, 3.2, 4.9, 35, 20, 1],
    [3, 'KAB-25', 'Kabel 3x2,5 mm²', 'Kabel za instalacije, po metru', 'm', 3, 2, 1.1, 1.9, 600, 150, 1],
    [4, 'ZAR-LED', 'LED žarulja E27', 'Žarulja 10 W, topla bijela', 'kom', 3, 2, 1.8, 3.5, 12, 30, 1]],
   report=('lokacija_id', 'naziv')),
  T('kretanje_zalihe', 'Kretanje zaliha', 'Svaki ulaz i izlaz robe; trenutna zaliha je njihov zbroj.', [
    PK('Šifra kretanja.'), REF('proizvod_id', 'Proizvod', 'proizvod.sifra', 'Koji proizvod se kretao.', required=True),
    datum('Datum kretanja.'),
    txt('vrsta_kretanja', 'Vrsta', 'kategorija', 'Primka povećava, izdatnica smanjuje zalihu; inventura i otpis ispravljaju stanje.', **ch('Primka,Izdatnica,Inventura,Otpis', 'Primka')),
    dec('kolicina', 'Količina', 'kolicina', 'Količina; pozitivna za ulaz, negativna za izlaz.', decimals=2, required=True, validation='[value] <> 0', validation_msg='Količina ne smije biti nula.'),
    cur('cijena', 'Cijena', 'cijena', 'Jedinična cijena u trenutku kretanja.', **pos('Cijena ne može biti negativna.')),
    txt('broj_dokumenta', 'Dokument', 'identifikator', 'Broj primke, izdatnice ili računa na koji se kretanje odnosi.'),
    napomena()],
   [[1, 1, '2026-01-05', 'Primka', 1000, 0.08, 'PR-001', None], [2, 1, '2026-02-10', 'Izdatnica', -520, 0.08, 'IZ-014', None],
    [3, 2, '2026-01-12', 'Primka', 60, 3.2, 'PR-002', None], [4, 2, '2026-02-02', 'Izdatnica', -25, 3.2, 'IZ-009', 'Ured'],
    [5, 3, '2026-01-20', 'Primka', 800, 1.1, 'PR-003', None], [6, 3, '2026-03-01', 'Izdatnica', -200, 1.1, 'IZ-021', None],
    [7, 4, '2026-01-25', 'Primka', 50, 1.8, 'PR-004', None], [8, 4, '2026-03-05', 'Izdatnica', -38, 1.8, 'IZ-025', 'Akcija']]),
  T('narudzba_dobavljacu', 'Narudžbe dobavljačima', 'Što je naručeno od kojeg dobavljača i u kojem je stanju isporuka.', [
    PK('Šifra narudžbe.'), REF('dobavljac_id', 'Dobavljač', 'dobavljac.sifra', 'Kome je narudžba poslana.', required=True),
    datum('Datum narudžbe.'), dt('ocekivana_isporuka', 'Očekivana isporuka', 'Do kada se očekuje roba.'),
    txt('status_narudzbe', 'Status', 'status', 'Napredak narudžbe.', **ch('Nacrt,Poslano,Primljeno djelomično,Primljeno,Otkazano', 'Nacrt')),
    cur('ukupno', 'Ukupno', 'iznos', 'Iznos za platiti (osnovica + PDV).'), napomena()],
   [[1, 2, '2026-03-02', '2026-03-05', 'Primljeno', 160.0, None], [2, 3, '2026-03-08', '2026-03-18', 'Poslano', 510.0, 'Hitno']]),
  T('stavka_nabave', 'Stavke narudžbe', 'Proizvodi i količine na pojedinoj narudžbi dobavljaču.', [
    PK('Šifra stavke.'), REF('narudzba_id', 'Narudžba', 'narudzba_dobavljacu.sifra', 'Narudžba kojoj stavka pripada.', required=True, on_delete='cascade'),
    REF('proizvod_id', 'Proizvod', 'proizvod.sifra', 'Naručeni proizvod.', required=True),
    dec('kolicina', 'Količina', 'kolicina', 'Naručena količina.', decimals=2, default='1', **gtz('Količina mora biti veća od nule.')),
    cur('cijena', 'Cijena', 'cijena', 'Dogovorena jedinična cijena.', **pos('Cijena ne može biti negativna.')),
    dec('primljeno', 'Primljeno', 'kolicina', 'Dosad primljena količina.', decimals=2, default='0', **pos('Količina ne može biti negativna.'))],
   [[1, 1, 2, 50, 3.2, 50], [2, 2, 3, 300, 1.1, 0], [3, 2, 4, 100, 1.8, 0]]),
])

D('zaposlenici', 'Zaposlenici i plaće',
  'Kadrovska evidencija: odjeli, radna mjesta, zaposlenici s nadređenima, godišnji odmori i mjesečne isplate plaća.',
  'posao,kadrovi,place', [
  T('odjel', 'Odjeli', 'Organizacijske jedinice tvrtke.', [
    PK('Šifra odjela.'), naziv('Naziv odjela.'), REF('voditelj_id', 'Voditelj', 'zaposlenik.sifra', 'Zaposlenik koji vodi odjel.'), opis('Čime se odjel bavi.')],
   [[1, 'Uprava', None, 'Vodstvo tvrtke'], [2, 'Prodaja', None, 'Prodaja i podrška kupcima'], [3, 'Financije', None, 'Računovodstvo i financije']]),
  T('radno_mjesto', 'Radna mjesta', 'Opisi poslova s rasponom plaće.', [
    PK('Šifra radnog mjesta.'), naziv('Naziv radnog mjesta.'), opis('Opis poslova i zahtjevi.'),
    cur('raspon_od', 'Plaća od', 'iznos', 'Donja granica bruto plaće.', **pos('Iznos ne može biti negativan.')),
    cur('raspon_do', 'Plaća do', 'iznos', 'Gornja granica bruto plaće.', **pos('Iznos ne može biti negativan.'))],
   [[1, 'Direktor', 'Vodi tvrtku', 3000, 5000], [2, 'Prodajni predstavnik', 'Rad s kupcima i ponudama', 1300, 2200], [3, 'Računovođa', 'Knjiženje i obračuni', 1400, 2400]]),
  T('zaposlenik', 'Zaposlenici', 'Osobni i radni podaci zaposlenika.', [
    PK('Matični broj zaposlenika.'), ime(), prezime(), oib(), email(), telefon(), adresa(), postanski(), mjesto(),
    REF('odjel_id', 'Odjel', 'odjel.sifra', 'Odjel u kojem radi.'), REF('radno_mjesto_id', 'Radno mjesto', 'radno_mjesto.sifra', 'Posao koji obavlja.'),
    REF('nadredeni_id', 'Nadređeni', 'zaposlenik.sifra', 'Izravni nadređeni.'),
    dt('datum_zaposlenja', 'Zaposlen od', 'Prvi radni dan.'), datum_rodjenja(),
    cur('bruto_placa', 'Bruto plaća', 'iznos', 'Ugovorena mjesečna bruto plaća.', **pos('Plaća ne može biti negativna.')),
    iban(), aktivan('Isključi kad zaposlenik napusti tvrtku, da povijest isplata ostane.'), napomena()],
   [[1, 'Ivan', 'Horvat', '11111111119', 'ivan.horvat@firma.hr', '091 100 2000', 'Ilica 100', '10000', 'Zagreb', 1, 1, None, '2018-03-01', '1975-05-12', 4200, 'HR1210010051863000160', 1, None],
    [2, 'Marta', 'Novak', '22222222226', 'marta.novak@firma.hr', '091 100 2001', 'Savska 55', '10000', 'Zagreb', 2, 2, 1, '2020-09-15', '1990-11-03', 1700, 'HR4423600001101234565', 1, None],
    [3, 'Petra', 'Kovač', '33333333333', 'petra.kovac@firma.hr', '091 100 2002', 'Vukovarska 21', '10000', 'Zagreb', 3, 3, 1, '2021-02-01', '1988-07-25', 1850, 'HR7624020061100000001', 1, 'Pola radnog vremena ljeti']]),
  T('godisnji_odmor', 'Godišnji odmori', 'Zahtjevi i korištenje godišnjeg odmora.', [
    PK('Šifra zahtjeva.'), REF('zaposlenik_id', 'Zaposlenik', 'zaposlenik.sifra', 'Tko traži odmor.', required=True),
    dt('pocetak', 'Početak', 'Prvi dan odmora.'), dt('kraj', 'Kraj', 'Zadnji dan odmora.'),
    whole('dana', 'Dana', 'kolicina', 'Broj radnih dana odmora.', **gtz('Broj dana mora biti veći od nule.')),
    txt('status_odmora', 'Status', 'status', 'Odobravanje zahtjeva.', **ch('Zatraženo,Odobreno,Odbijeno,Iskorišteno', 'Zatraženo')), napomena()],
   [[1, 2, '2026-07-06', '2026-07-17', 10, 'Odobreno', None], [2, 3, '2026-08-03', '2026-08-14', 10, 'Zatraženo', None], [3, 1, '2026-01-02', '2026-01-06', 3, 'Iskorišteno', None]]),
  T('isplata_place', 'Isplate plaća', 'Mjesečni obračun po zaposleniku: bruto, doprinosi, porez i neto.', [
    PK('Šifra isplate.'), REF('zaposlenik_id', 'Zaposlenik', 'zaposlenik.sifra', 'Kome je plaća isplaćena.', required=True),
    godina(), mjesec(),
    cur('bruto', 'Bruto', 'iznos', 'Bruto plaća za mjesec.'), cur('doprinosi', 'Doprinosi', 'iznos', 'Doprinosi iz plaće.'),
    cur('porez', 'Porez', 'iznos', 'Porez i prirez na dohodak.'), cur('neto', 'Neto', 'iznos', 'Iznos za isplatu na račun.'),
    dt('datum_isplate', 'Datum isplate', 'Kada je novac isplaćen.')],
   [[1, 2, 2026, 2, 1700, 340, 163.2, 1196.8, '2026-03-05'], [2, 3, 2026, 2, 1850, 370, 177.6, 1302.4, '2026-03-05'], [3, 1, 2026, 2, 4200, 840, 403.2, 2956.8, '2026-03-05']]),
])

D('crm', 'Kupci, kontakti i prodajne prilike',
  'Prodajni lijevak: tvrtke, kontakti, prilike po fazama i evidencija poziva, sastanaka i ponuda.',
  'posao,prodaja,kupci', [
  T('tvrtka', 'Tvrtke', 'Tvrtke koje su kupci ili potencijalni kupci.', [
    PK('Šifra tvrtke.'), naziv('Naziv tvrtke.'), oib(),
    txt('djelatnost', 'Djelatnost', 'kategorija', 'Čime se tvrtka bavi.', **ch('Proizvodnja,Trgovina,Usluge,Turizam,Javni sektor,IT,Ostalo', 'Usluge')),
    adresa(), postanski(), mjesto(), drzava(), email(), telefon(), txt('web', 'Web', 'kontakt', 'Adresa web stranice.', width=180), napomena()],
   [[1, 'Kvaka d.o.o.', '12345678903', 'Trgovina', 'Ilica 12', '10000', 'Zagreb', 'Hrvatska', 'info@kvaka.hr', '01 555 1234', 'www.kvaka.hr', None],
    [2, 'Adria promet d.d.', '45678912305', 'Usluge', 'Riva 7', '21000', 'Split', 'Hrvatska', 'uprava@adria-promet.hr', '021 330 440', 'www.adria-promet.hr', None],
    [3, 'Tehno Plus d.o.o.', '56789123406', 'IT', 'Zagrebačka 3', '42000', 'Varaždin', 'Hrvatska', 'kontakt@tehnoplus.hr', '042 200 300', 'www.tehnoplus.hr', 'Preporuka kolege']]),
  T('kontakt', 'Kontakti', 'Osobe u tvrtkama s kojima se komunicira.', [
    PK('Šifra kontakta.'), REF('tvrtka_id', 'Tvrtka', 'tvrtka.sifra', 'Gdje osoba radi.', required=True), ime(), prezime(),
    txt('funkcija', 'Funkcija', 'opis', 'Radno mjesto ili uloga u tvrtki.'), email(), telefon(), aktivan()],
   [[1, 1, 'Davor', 'Perić', 'Direktor nabave', 'davor.peric@kvaka.hr', '091 500 6000', 1],
    [2, 2, 'Sanja', 'Jurić', 'Voditeljica financija', 'sanja.juric@adria-promet.hr', '091 600 7000', 1],
    [3, 3, 'Goran', 'Matić', 'Tehnički direktor', 'goran.matic@tehnoplus.hr', '098 800 9000', 1]]),
  T('prilika', 'Prodajne prilike', 'Mogući poslovi s procjenom vrijednosti i vjerojatnosti.', [
    PK('Šifra prilike.'), naziv('Kratak naziv posla.'), REF('tvrtka_id', 'Tvrtka', 'tvrtka.sifra', 'Kupac.', required=True),
    REF('kontakt_id', 'Kontakt', 'kontakt.sifra', 'S kim se pregovara.'),
    txt('faza_prodaje', 'Faza', 'status', 'U kojoj je fazi prodajnog lijevka prilika.', **ch('Upit,Ponuda,Pregovori,Dobiveno,Izgubljeno', 'Upit')),
    cur('vrijednost', 'Vrijednost', 'iznos', 'Procijenjena vrijednost posla.', **pos('Vrijednost ne može biti negativna.')),
    whole('vjerojatnost', 'Vjerojatnost (%)', 'postotak', 'Procijenjena vjerojatnost uspjeha, 0-100.', default='50',
          validation='[value] >= 0 And [value] <= 100', validation_msg='Vjerojatnost je od 0 do 100.'),
    dt('ocekivano_zatvaranje', 'Očekivano zatvaranje', 'Kada se očekuje odluka kupca.'),
    dt('datum_otvaranja', 'Otvoreno', 'Kada je prilika otvorena.', default='Date()')],
   [[1, 'Novi web portal', 1, 1, 'Pregovori', 12000, 60, '2026-04-30', '2026-01-20'],
    [2, 'Godišnje održavanje', 2, 2, 'Ponuda', 4800, 40, '2026-05-15', '2026-02-10'],
    [3, 'Integracija sustava', 3, 3, 'Dobiveno', 9500, 100, '2026-03-01', '2025-12-05']],
   report=('faza_prodaje', 'ocekivano_zatvaranje')),
  T('aktivnost', 'Aktivnosti', 'Pozivi, sastanci i ponude vezani uz prilike.', [
    PK('Šifra aktivnosti.'), REF('prilika_id', 'Prilika', 'prilika.sifra', 'Uz koju priliku.', required=True, on_delete='cascade'),
    REF('kontakt_id', 'Kontakt', 'kontakt.sifra', 'S kim je aktivnost.'),
    F('vrijeme_aktivnosti', 'Vrijeme', 'datetime', 'datum', 'Kada je aktivnost održana ili je zakazana.', default='Now()'),
    txt('vrsta_aktivnosti', 'Vrsta', 'kategorija', 'Što je napravljeno.', **ch('Poziv,Sastanak,E-pošta,Ponuda,Zadatak', 'Poziv')),
    opis('Što je dogovoreno.'), flag('obavljeno', 'Obavljeno', 'Označi kad je aktivnost gotova.', default='False')],
   [[1, 1, 1, '2026-02-12 10:00:00', 'Sastanak', 'Predstavljen prijedlog portala.', 1], [2, 1, 1, '2026-03-02 14:30:00', 'Ponuda', 'Poslana revidirana ponuda.', 1],
    [3, 2, 2, '2026-03-20 09:00:00', 'Poziv', 'Dogovoren sastanak za sljedeći tjedan.', 0]]),
])

D('projekti', 'Projekti i zadaci',
  'Vođenje projekata: projekt s rokom i proračunom, zadaci po osobama, utrošeni sati i ključni događaji.',
  'posao,projekti,planiranje', [
  T('projekt', 'Projekti', 'Poslovi koji se vode kroz rokove, zadatke i sate.', [
    PK('Šifra projekta.'), naziv('Naziv projekta.'), opis('Cilj i opseg projekta.'),
    txt('klijent', 'Klijent', 'naziv', 'Za koga se projekt radi.'), txt('voditelj', 'Voditelj', 'naziv', 'Tko vodi projekt.'),
    dt('pocetak', 'Početak', 'Planirani ili stvarni početak.'), dt('rok', 'Rok', 'Do kada projekt mora biti gotov.'),
    txt('status_projekta', 'Status', 'status', 'Stanje projekta.', **ch('Planiran,U tijeku,Na čekanju,Završen,Otkazan', 'Planiran')),
    dec('proracun_sati', 'Proračun (sati)', 'kolicina', 'Planirani broj sati.', decimals=1, **pos('Sati ne mogu biti negativni.')),
    cur('budzet_projekta', 'Budžet', 'iznos', 'Odobreni novčani okvir.', **pos('Budžet ne može biti negativan.'))],
   [[1, 'Web portal za kupce', 'Novi portal s prijavom i narudžbama.', 'Kvaka d.o.o.', 'Marta Novak', '2026-01-15', '2026-06-30', 'U tijeku', 400, 24000],
    [2, 'Preseljenje poslužitelja', 'Prebacivanje sustava u oblak.', 'Adria promet d.d.', 'Ivan Horvat', '2026-03-01', '2026-04-15', 'Planiran', 120, 6500]],
   report=('status_projekta', 'rok')),
  T('zadatak', 'Zadaci', 'Pojedinačni poslovi unutar projekta.', [
    PK('Šifra zadatka.'), REF('projekt_id', 'Projekt', 'projekt.sifra', 'Projekt kojem zadatak pripada.', required=True, on_delete='cascade'),
    naziv('Što treba napraviti.'), opis('Detalji i kriteriji gotovosti.'), txt('zaduzeni', 'Zaduženi', 'naziv', 'Osoba koja radi zadatak.'),
    txt('prioritet', 'Prioritet', 'kategorija', 'Hitnost zadatka.', **ch('Nizak,Srednji,Visok,Hitno', 'Srednji')),
    txt('status_zadatka', 'Status', 'status', 'Napredak zadatka.', **ch('Za napraviti,U tijeku,Provjera,Gotovo', 'Za napraviti')),
    dt('rok', 'Rok', 'Do kada zadatak mora biti gotov.'), dec('procjena_sati', 'Procjena (sati)', 'kolicina', 'Procijenjeno trajanje.', decimals=1, **pos('Procjena ne može biti negativna.')), napomena()],
   [[1, 1, 'Dizajn sučelja', 'Skice i prototip svih ekrana.', 'Ana Kovač', 'Visok', 'Gotovo', '2026-02-15', 40, None],
    [2, 1, 'Prijava korisnika', 'Prijava, registracija, zaboravljena lozinka.', 'Petar Marić', 'Visok', 'U tijeku', '2026-03-31', 60, None],
    [3, 1, 'Narudžbe', 'Košarica i povijest narudžbi.', 'Petar Marić', 'Srednji', 'Za napraviti', '2026-05-15', 90, 'Ovisi o prijavi'],
    [4, 2, 'Popis sustava za selidbu', 'Inventura aplikacija i baza.', 'Ivan Horvat', 'Srednji', 'U tijeku', '2026-03-20', 16, None]]),
  T('evidencija_rada', 'Evidencija rada', 'Sati utrošeni na zadatke; osnova za obračun i praćenje proračuna.', [
    PK('Šifra unosa.'), REF('zadatak_id', 'Zadatak', 'zadatak.sifra', 'Na kojem zadatku je radio.', required=True),
    datum('Dan rada.'), txt('zaduzeni', 'Zaduženi', 'naziv', 'Osoba koja radi zadatak.'),
    dec('sati', 'Sati', 'kolicina', 'Utrošeni sati (do 24).', decimals=2, required=True, validation='[value] > 0 And [value] <= 24', validation_msg='Sati su između 0 i 24.'),
    opis('Što je napravljeno.')],
   [[1, 1, '2026-02-03', 'Ana Kovač', 6.5, 'Skice početne stranice.'], [2, 1, '2026-02-10', 'Ana Kovač', 8, 'Prototip u alatu.'],
    [3, 2, '2026-03-04', 'Petar Marić', 7, 'Obrazac za prijavu.'], [4, 4, '2026-03-09', 'Ivan Horvat', 4, 'Popis baza.']]),
  T('kljucni_dogadjaj', 'Ključni događaji', 'Važne točke projekta (isporuke, odobrenja).', [
    PK('Šifra događaja.'), REF('projekt_id', 'Projekt', 'projekt.sifra', 'Projekt.', required=True, on_delete='cascade'),
    naziv('Naziv događaja (npr. Prva isporuka).'), dt('rok', 'Rok', 'Do kada se događaj mora dogoditi.'),
    flag('ostvareno', 'Ostvareno', 'Označi kad je događaj ostvaren.', default='False')],
   [[1, 1, 'Prototip odobren', '2026-02-20', 1], [2, 1, 'Prva isporuka', '2026-04-30', 0], [3, 2, 'Prebacivanje završeno', '2026-04-15', 0]]),
])

# ========================= PAKET 2 =========================
D('najam', 'Nekretnine i najam',
  'Najam stanova i poslovnih prostora: nekretnine, najmoprimci, ugovori, mjesečne uplate i troškovi održavanja.',
  'nekretnine,najam,financije', [
  T('nekretnina', 'Nekretnine', 'Stanovi, kuće i prostori koji se iznajmljuju.', [
    PK('Šifra nekretnine.'), naziv('Kratak naziv (npr. Stan Savska 12).'),
    txt('vrsta_nekretnine', 'Vrsta', 'kategorija', 'Vrsta nekretnine.', **ch('Stan,Kuća,Poslovni prostor,Garaža,Zemljište', 'Stan')),
    adresa(), postanski(), mjesto(), dec('povrsina_m2', 'Površina (m²)', 'kolicina', 'Korisna površina.', decimals=1, **gtz('Površina mora biti veća od nule.')),
    whole('broj_soba', 'Broj soba', 'kolicina', 'Broj soba bez kuhinje i kupaonice.', **pos('Broj soba ne može biti negativan.')),
    cur('mjesecna_najamnina', 'Najamnina (mjesečno)', 'iznos', 'Tražena mjesečna najamnina.', **pos('Najamnina ne može biti negativna.')),
    opis('Opis, oprema, napomene.'), aktivan()],
   [[1, 'Stan Savska 12', 'Stan', 'Savska cesta 12', '10000', 'Zagreb', 62.5, 2, 650, 'Dvosoban stan, 3. kat, lift.', 1],
    [2, 'Ured Ilica 5', 'Poslovni prostor', 'Ilica 5', '10000', 'Zagreb', 48, 2, 900, 'Ured u centru, klima.', 1],
    [3, 'Garaža Vrbik', 'Garaža', 'Vrbik 3', '10000', 'Zagreb', 15, 0, 90, None, 1]]),
  T('najmoprimac', 'Najmoprimci', 'Osobe i tvrtke koje iznajmljuju.', [
    PK('Šifra najmoprimca.'), ime(), prezime(), oib(), email(), telefon(), iban(), napomena()],
   [[1, 'Luka', 'Vidović', '44444444441', 'luka.vidovic@mail.hr', '091 700 8000', 'HR1210010051863000160', None],
    [2, 'Dino', 'Šarić', '55555555558', 'dino.saric@dsdizajn.hr', '098 400 5000', 'HR4423600001101234565', 'Plaća preko tvrtke DS dizajn']]),
  T('ugovor_o_najmu', 'Ugovori o najmu', 'Tko iznajmljuje što, od kada do kada i uz koju najamninu i polog.', [
    PK('Šifra ugovora.'), REF('nekretnina_id', 'Nekretnina', 'nekretnina.sifra', 'Iznajmljena nekretnina.', required=True),
    REF('najmoprimac_id', 'Najmoprimac', 'najmoprimac.sifra', 'Tko iznajmljuje.', required=True),
    dt('pocetak', 'Početak', 'Prvi dan najma.'), dt('kraj', 'Kraj', 'Zadnji dan najma.'),
    cur('mjesecna_najamnina', 'Najamnina (mjesečno)', 'iznos', 'Tražena mjesečna najamnina.', **pos('Najamnina ne može biti negativna.')),
    cur('polog', 'Polog', 'iznos', 'Jamčevina koja se vraća na kraju najma.', **pos('Polog ne može biti negativan.')),
    txt('status_ugovora', 'Status', 'status', 'Je li ugovor na snazi.', **ch('Aktivan,Istekao,Raskinut', 'Aktivan')), napomena()],
   [[1, 1, 1, '2025-09-01', '2026-08-31', 650, 1300, 'Aktivan', None], [2, 2, 2, '2025-01-01', '2026-12-31', 900, 1800, 'Aktivan', 'Uključene režije']],
   report=('status_ugovora', 'pocetak')),
  T('uplata_najma', 'Uplate najamnine', 'Mjesečne uplate po ugovoru.', [
    PK('Šifra uplate.'), REF('ugovor_id', 'Ugovor', 'ugovor_o_najmu.sifra', 'Ugovor na koji se uplata odnosi.', required=True),
    godina(), mjesec(), datum('Datum uplate.'), iznos('Uplaćeni iznos.'),
    txt('nacin_placanja', 'Način plaćanja', 'kategorija', 'Kako kupac plaća.', **ch('Virman,Gotovina,Kartica,Pouzeće', 'Virman')), napomena()],
   [[1, 1, 2026, 1, '2026-01-03', 650, 'Virman', None], [2, 1, 2026, 2, '2026-02-02', 650, 'Virman', None], [3, 2, 2026, 2, '2026-02-05', 900, 'Virman', None]]),
  T('trosak_nekretnine', 'Troškovi nekretnina', 'Održavanje, pričuva, porezi i osiguranje po nekretnini.', [
    PK('Šifra troška.'), REF('nekretnina_id', 'Nekretnina', 'nekretnina.sifra', 'Na koju se trošak odnosi.', required=True), datum('Datum troška.'),
    txt('vrsta_troska', 'Vrsta', 'kategorija', 'Vrsta troška.', **ch('Održavanje,Pričuva,Porez,Osiguranje,Režije,Ostalo', 'Održavanje')),
    iznos('Iznos troška.'), txt('svrha', 'Svrha', 'opis', 'Kratki opis (npr. Konzum, kirija ožujak).', width=220), napomena()],
   [[1, 1, '2026-01-15', 'Pričuva', 45, 'Pričuva siječanj', None], [2, 2, '2026-02-12', 'Održavanje', 180, 'Popravak klime', None], [3, 1, '2026-03-01', 'Osiguranje', 120, 'Godišnja polica', None]]),
])

D('vozni_park', 'Vozni park',
  'Službena ili obiteljska vozila: vozila, vozači, tankanja, servisi, registracije i putni nalozi.',
  'posao,vozila,troskovi', [
  T('vozilo', 'Vozila', 'Vozila s osnovnim podacima i rokom registracije.', [
    PK('Šifra vozila.'), txt('registracija', 'Registracija', 'identifikator', 'Registarska oznaka.', required=True, width=110),
    txt('marka', 'Marka', 'kategorija', 'Proizvođač vozila.'), txt('model', 'Model', 'naziv', 'Naziv modela.'),
    whole('godina_proizvodnje', 'Godina proizvodnje', 'datum', 'Godina proizvodnje vozila.', validation='[value] >= 1950 And [value] <= 2100', validation_msg='Unesi ispravnu godinu.'),
    txt('vrsta_goriva', 'Gorivo', 'kategorija', 'Pogonsko gorivo.', **ch('Benzin,Dizel,Hibrid,Električno,Plin', 'Dizel')),
    txt('vin', 'VIN', 'identifikator', 'Broj šasije od 17 znakova.', validation='Len([value]) = 17', validation_msg='VIN ima 17 znakova.', width=180),
    whole('kilometraza', 'Kilometraža', 'kolicina', 'Trenutno stanje kilometara.', **pos('Kilometraža ne može biti negativna.')),
    dt('registracija_do', 'Registracija do', 'Do kada vrijedi registracija.'), aktivan(), napomena()],
   [[1, 'ZG1234AB', 'Škoda', 'Octavia', 2021, 'Dizel', 'TMBJJ7NE0M0123456', 84500, '2026-11-30', 1, None],
    [2, 'ZG5678CD', 'Renault', 'Zoe', 2022, 'Električno', 'VF1AG000X66543210', 31200, '2026-06-15', 1, 'Gradska vožnja'],
    [3, 'ST9012EF', 'Fiat', 'Doblo', 2019, 'Dizel', 'ZFA26300006789012', 142300, '2026-04-10', 1, 'Dostava']]),
  T('vozac', 'Vozači', 'Osobe koje voze vozila.', [
    PK('Šifra vozača.'), ime(), prezime(), telefon(),
    txt('broj_vozacke', 'Broj vozačke', 'identifikator', 'Broj vozačke dozvole.'), dt('vozacka_vrijedi_do', 'Vozačka vrijedi do', 'Do kada vrijedi vozačka.'), aktivan()],
   [[1, 'Marko', 'Tomić', '091 300 4000', '12345678', '2031-05-20', 1], [2, 'Ines', 'Bašić', '098 500 6000', '23456789', '2028-09-01', 1]]),
  T('tankanje', 'Tankanja', 'Količina i cijena goriva po tankanju; osnova za potrošnju.', [
    PK('Šifra tankanja.'), REF('vozilo_id', 'Vozilo', 'vozilo.sifra', 'Što je natankano.', required=True), REF('vozac_id', 'Vozač', 'vozac.sifra', 'Tko je tankao.'),
    datum('Datum tankanja.'), dec('litara', 'Litara', 'kolicina', 'Natočena količina.', decimals=2, **gtz('Količina mora biti veća od nule.')),
    cur('cijena_litre', 'Cijena litre', 'cijena', 'Cijena po litri.', **pos('Cijena ne može biti negativna.')),
    iznos('Ukupni iznos računa.'), whole('kilometraza', 'Kilometraža', 'kolicina', 'Trenutno stanje kilometara.', **pos('Kilometraža ne može biti negativna.'))],
   [[1, 1, 1, '2026-02-05', 42.5, 1.52, 64.6, 84100], [2, 1, 1, '2026-03-01', 40.1, 1.55, 62.16, 84500], [3, 3, 2, '2026-02-20', 55.0, 1.52, 83.6, 142000]]),
  T('servis_vozila', 'Servisi', 'Redoviti i izvanredni servisi s troškom i sljedećim rokom.', [
    PK('Šifra servisa.'), REF('vozilo_id', 'Vozilo', 'vozilo.sifra', 'Servisirano vozilo.', required=True), datum('Datum servisa.'),
    txt('vrsta_servisa', 'Vrsta', 'kategorija', 'Što je rađeno.', **ch('Redovni,Gume,Kvar,Tehnički pregled,Limarija', 'Redovni')),
    whole('kilometraza', 'Kilometraža', 'kolicina', 'Trenutno stanje kilometara.', **pos('Kilometraža ne može biti negativna.')),
    iznos('Ukupni trošak servisa.'), txt('servisna_radionica', 'Radionica', 'naziv', 'Gdje je servis obavljen.'),
    opis('Opis radova.'), dt('sljedeci_servis', 'Sljedeći servis', 'Kada treba ponovno na servis.')],
   [[1, 1, '2025-11-10', 'Redovni', 80000, 285, 'Auto centar Zagreb', 'Ulje, filteri, kočnice.', '2026-11-10'],
    [2, 2, '2026-01-25', 'Gume', 30000, 120, 'Gumarija Marić', 'Zamjena na zimske gume.', None],
    [3, 3, '2026-02-15', 'Tehnički pregled', 141000, 65, 'Stanica Split', None, '2027-02-15']]),
  T('putni_nalog', 'Putni nalozi', 'Službena putovanja vozilom s prijeđenim kilometrima.', [
    PK('Šifra naloga.'), REF('vozilo_id', 'Vozilo', 'vozilo.sifra', 'Korišteno vozilo.', required=True), REF('vozac_id', 'Vozač', 'vozac.sifra', 'Tko je vozio.', required=True),
    datum('Dan putovanja.'), txt('relacija', 'Relacija', 'opis', 'Polazište i odredište.', width=200),
    whole('km_pocetak', 'Km na početku', 'kolicina', 'Stanje brojila na polasku.', **pos('Kilometraža ne može biti negativna.')),
    whole('km_kraj', 'Km na kraju', 'kolicina', 'Stanje brojila na dolasku.', **pos('Kilometraža ne može biti negativna.')),
    txt('svrha', 'Svrha', 'opis', 'Kratki opis (npr. Konzum, kirija ožujak).', width=220), napomena()],
   [[1, 1, 1, '2026-03-02', 'Zagreb - Varaždin', 84240, 84330, 'Sastanak s klijentom', None], [2, 3, 2, '2026-03-04', 'Split - Zadar', 142100, 142260, 'Dostava robe', None]]),
])

D('hotel', 'Hotel i smještaj',
  'Mali hotel ili apartmani: sobe, gosti, rezervacije s datumima i cijenom te dodatne usluge.',
  'turizam,smjestaj,rezervacije', [
  T('soba', 'Sobe', 'Smještajne jedinice s kapacitetom i cijenom noćenja.', [
    PK('Šifra sobe.'), txt('broj_sobe', 'Broj sobe', 'identifikator', 'Broj ili oznaka na vratima.', required=True, width=90),
    txt('vrsta_sobe', 'Vrsta', 'kategorija', 'Tip smještaja.', **ch('Jednokrevetna,Dvokrevetna,Apartman,Obiteljska', 'Dvokrevetna')),
    whole('kat', 'Kat', 'kolicina', 'Kat na kojem je soba.'), whole('kapacitet', 'Kapacitet', 'kolicina', 'Najveći broj gostiju.', default='2', **gtz('Kapacitet mora biti veći od nule.')),
    cur('cijena_noci', 'Cijena noćenja', 'cijena', 'Cijena po noći za cijelu sobu.', **pos('Cijena ne može biti negativna.')), opis('Oprema, pogled, napomene.'), aktivan()],
   [[1, '101', 'Jednokrevetna', 1, 1, 55, 'Pogled na vrt.', 1], [2, '102', 'Dvokrevetna', 1, 2, 80, 'Francuski ležaj.', 1],
    [3, '201', 'Apartman', 2, 4, 140, 'Dnevni boravak i terasa.', 1], [4, '202', 'Obiteljska', 2, 4, 120, 'Dva odvojena ležaja i sofa.', 1]]),
  T('gost', 'Gosti', 'Osobe koje borave u hotelu.', [
    PK('Šifra gosta.'), ime(), prezime(), email(), telefon(), drzava(), txt('broj_isprave', 'Broj isprave', 'identifikator', 'Putovnica ili osobna iskaznica.'), napomena()],
   [[1, 'Hans', 'Müller', 'hans.mueller@mail.de', '+49 170 1234567', 'Njemačka', 'C01X00T47', None], [2, 'Ana', 'Perić', 'ana.peric@mail.hr', '091 222 3333', 'Hrvatska', '123456789', 'Stalna gošća'],
    [3, 'Anna', 'Rossi', 'anna.rossi@mail.it', '+39 333 4445556', 'Italija', 'YA1234567', None]]),
  T('rezervacija', 'Rezervacije', 'Tko je rezervirao koju sobu, od kada do kada i po kojoj ukupnoj cijeni.', [
    PK('Šifra rezervacije.'), REF('gost_id', 'Gost', 'gost.sifra', 'Nositelj rezervacije.', required=True), REF('soba_id', 'Soba', 'soba.sifra', 'Rezervirana soba.', required=True),
    dt('dolazak', 'Dolazak', 'Prvi dan boravka.'), dt('odlazak', 'Odlazak', 'Dan odlaska.'),
    whole('broj_gostiju', 'Gostiju', 'kolicina', 'Broj osoba.', default='2', **gtz('Broj gostiju mora biti veći od nule.')),
    txt('status_rezervacije', 'Status', 'status', 'Stanje rezervacije.', **ch('Upit,Potvrđeno,Prijavljen,Odjavljen,Otkazano', 'Potvrđeno')),
    txt('nacin_placanja', 'Način plaćanja', 'kategorija', 'Kako kupac plaća.', **ch('Virman,Gotovina,Kartica,Pouzeće', 'Virman')),
    cur('ukupno', 'Ukupno', 'iznos', 'Iznos za platiti (osnovica + PDV).'), napomena()],
   [[1, 1, 2, '2026-03-10', '2026-03-14', 2, 'Odjavljen', 'Kartica', 320, None], [2, 2, 3, '2026-04-02', '2026-04-05', 3, 'Potvrđeno', 'Gotovina', 420, 'Rođendan'],
    [3, 3, 1, '2026-05-20', '2026-05-22', 1, 'Upit', 'Kartica', 110, None]],
   report=('status_rezervacije', 'dolazak')),
  T('usluga_hotela', 'Usluge', 'Dodatne usluge koje se naplaćuju (doručak, parking, wellness).', [
    PK('Šifra usluge.'), naziv('Naziv usluge.'), cur('cijena', 'Cijena', 'cijena', 'Cijena usluge po jedinici.', **pos('Cijena ne može biti negativna.')), aktivan()],
   [[1, 'Doručak', 12, 1], [2, 'Parking', 8, 1], [3, 'Wellness', 20, 1]]),
  T('naplata_usluge', 'Naplaćene usluge', 'Usluge dodane na rezervaciju.', [
    PK('Šifra stavke.'), REF('rezervacija_id', 'Rezervacija', 'rezervacija.sifra', 'Uz koju rezervaciju.', required=True, on_delete='cascade'),
    REF('usluga_id', 'Usluga', 'usluga_hotela.sifra', 'Koja usluga.', required=True), datum('Datum usluge.'),
    dec('kolicina', 'Količina', 'kolicina', 'Količina.', decimals=2, default='1', **gtz('Količina mora biti veća od nule.')),
    cur('cijena', 'Cijena', 'cijena', 'Cijena po jedinici.', **pos('Cijena ne može biti negativna.')), iznos('Iznos stavke.')],
   [[1, 1, 1, '2026-03-11', 2, 12, 24], [2, 1, 3, '2026-03-12', 2, 20, 40], [3, 2, 2, '2026-04-02', 1, 8, 8]]),
])

D('restoran', 'Restoran i narudžbe',
  'Ugostiteljski lokal: stolovi, jelovnik, narudžbe po stolu sa stavkama i naplata.',
  'ugostiteljstvo,narudzbe,prodaja', [
  T('stol', 'Stolovi', 'Stolovi u lokalu s brojem mjesta i zonom.', [
    PK('Šifra stola.'), txt('oznaka_stola', 'Oznaka', 'identifikator', 'Broj ili naziv stola.', required=True, width=90),
    whole('broj_mjesta', 'Mjesta', 'kolicina', 'Broj mjesta za sjedenje.', default='4', **gtz('Broj mjesta mora biti veći od nule.')),
    txt('zona', 'Zona', 'kategorija', 'Gdje se stol nalazi.', **ch('Unutra,Terasa,Šank,Separe', 'Unutra')), aktivan()],
   [[1, 'S1', 2, 'Unutra', 1], [2, 'S2', 4, 'Unutra', 1], [3, 'T1', 6, 'Terasa', 1], [4, 'Š1', 2, 'Šank', 1]]),
  T('jelo', 'Jelovnik', 'Jela i pića s cijenama.', [
    PK('Šifra jela.'), naziv('Naziv jela ili pića.'), opis('Sastojci, alergeni.'),
    txt('kategorija_jela', 'Kategorija', 'kategorija', 'Dio jelovnika.', **ch('Predjelo,Glavno jelo,Prilog,Desert,Piće', 'Glavno jelo')),
    cur('cijena', 'Cijena', 'cijena', 'Cijena po porciji.', **pos('Cijena ne može biti negativna.')), aktivan()],
   [[1, 'Pršut i sir', 'Pršut, paški sir, masline', 'Predjelo', 11.5, 1], [2, 'Biftek s umakom', 'Goveđi file, krumpir', 'Glavno jelo', 24, 1],
    [3, 'Rižoto od lignji', 'Lignje, riža, bijelo vino', 'Glavno jelo', 16, 1], [4, 'Palačinke', 'S marmeladom i orasima', 'Desert', 6, 1], [5, 'Gazirani sok 0,3 l', None, 'Piće', 3, 1]]),
  T('narudzba_stola', 'Narudžbe', 'Račun po stolu; ukupni iznos je zbroj stavki.', [
    PK('Šifra narudžbe.'), REF('stol_id', 'Stol', 'stol.sifra', 'Za koji stol.', required=True),
    F('vrijeme_narudzbe', 'Vrijeme', 'datetime', 'datum', 'Kada je narudžba otvorena.', default='Now()'),
    txt('konobar', 'Konobar', 'naziv', 'Tko poslužuje.'),
    txt('status_narudzbe_stola', 'Status', 'status', 'Stanje narudžbe.', **ch('Otvorena,Poslužena,Plaćena,Stornirana', 'Otvorena')),
    txt('nacin_placanja', 'Način plaćanja', 'kategorija', 'Kako kupac plaća.', **ch('Virman,Gotovina,Kartica,Pouzeće', 'Virman')),
    cur('ukupno', 'Ukupno', 'iznos', 'Iznos za platiti (osnovica + PDV).'), napomena()],
   [[1, 2, '2026-03-14 13:05:00', 'Iva', 'Plaćena', 'Kartica', 59.5, None], [2, 3, '2026-03-14 20:10:00', 'Iva', 'Poslužena', 'Gotovina', 87, 'Rođendan'], [3, 4, '2026-03-15 09:30:00', 'Marin', 'Otvorena', 'Gotovina', 6, None]],
   report=('status_narudzbe_stola', 'vrijeme_narudzbe')),
  T('stavka_narudzbe_stola', 'Stavke narudžbe', 'Što je naručeno na narudžbi.', [
    PK('Šifra stavke.'), REF('narudzba_id', 'Narudžba', 'narudzba_stola.sifra', 'Narudžba.', required=True, on_delete='cascade'),
    REF('jelo_id', 'Jelo', 'jelo.sifra', 'Naručeno jelo ili piće.', required=True),
    dec('kolicina', 'Količina', 'kolicina', 'Količina.', decimals=2, default='1', **gtz('Količina mora biti veća od nule.')),
    cur('cijena', 'Cijena', 'cijena', 'Cijena po jedinici.', **pos('Cijena ne može biti negativna.')), iznos('Iznos stavke.'), napomena('Posebni zahtjevi (npr. bez luka).')],
   [[1, 1, 1, 1, 11.5, 11.5, None], [2, 1, 2, 1, 24, 24, 'Srednje pečeno'], [3, 1, 3, 1, 16, 16, None], [4, 1, 5, 3, 3, 9, None],
    [5, 2, 2, 3, 24, 72, None], [6, 2, 4, 2, 6, 12, None], [7, 3, 4, 1, 6, 6, None]]),
])

# ========================= PAKET 3 =========================
D('skola', 'Škola i ocjene',
  'Razredna evidencija: razredi, učenici, predmeti, ocjene po provjerama i izostanci.',
  'obrazovanje,skola,evidencija', [
  T('razred', 'Razredi', 'Razredni odjeli u školskoj godini.', [
    PK('Šifra razreda.'), naziv('Oznaka razreda (npr. 5.b).'), txt('skolska_godina', 'Školska godina', 'oznaka', 'Npr. 2025./2026.'), txt('razrednik', 'Razrednik', 'naziv', 'Nastavnik razrednik.')],
   [[1, '5.a', '2025./2026.', 'Ivana Barić'], [2, '5.b', '2025./2026.', 'Tomislav Jurić']]),
  T('ucenik', 'Učenici', 'Učenici upisani u razrede.', [
    PK('Šifra učenika.'), ime(), prezime(), oib(), datum_rodjenja(), REF('razred_id', 'Razred', 'razred.sifra', 'Razred u koji je učenik upisan.'),
    adresa(), txt('kontakt_roditelja', 'Kontakt roditelja', 'kontakt', 'Telefon ili e-pošta roditelja.'), aktivan(), napomena()],
   [[1, 'Luka', 'Marić', '66666666666', '2014-04-12', 1, 'Zagrebačka 5, Zagreb', 'roditelj.maric@mail.hr', 1, None],
    [2, 'Mia', 'Knežević', '77777777773', '2014-09-30', 1, 'Savska 18, Zagreb', '091 800 9000', 1, 'Alergija na orašaste plodove'],
    [3, 'Filip', 'Božić', '88888888880', '2014-01-22', 2, 'Ulica grada Vukovara 7, Zagreb', 'bozic.roditelji@mail.hr', 1, None]]),
  T('predmet', 'Predmeti', 'Nastavni predmeti i nastavnici.', [
    PK('Šifra predmeta.'), naziv('Naziv predmeta.'), txt('nastavnik', 'Nastavnik', 'naziv', 'Tko predaje.'), whole('tjedni_sati', 'Sati tjedno', 'kolicina', 'Broj sati tjedno.', **gtz('Broj sati mora biti veći od nule.'))],
   [[1, 'Hrvatski jezik', 'Ivana Barić', 5], [2, 'Matematika', 'Tomislav Jurić', 4], [3, 'Priroda i društvo', 'Nikola Vuković', 2]]),
  T('ocjena_ucenika', 'Ocjene', 'Ocjene po predmetu i vrsti provjere.', [
    PK('Šifra ocjene.'), REF('ucenik_id', 'Učenik', 'ucenik.sifra', 'Kome je ocjena upisana.', required=True), REF('predmet_id', 'Predmet', 'predmet.sifra', 'Iz kojeg predmeta.', required=True),
    datum('Datum ocjenjivanja.'), F('ocjena', 'Ocjena', 'integer', 'rezultat', 'Osobna ocjena od 1 do 5.', validation='[value] >= 1 And [value] <= 5', validation_msg='Ocjena je od 1 do 5.'),
    txt('vrsta_provjere', 'Vrsta provjere', 'kategorija', 'Kako je znanje provjereno.', **ch('Usmeno,Pisano,Kontrolni,Projekt', 'Pisano')), napomena()],
   [[1, 1, 1, '2026-02-10', 5, 'Pisano', None], [2, 1, 2, '2026-02-17', 4, 'Kontrolni', None], [3, 2, 1, '2026-02-10', 5, 'Pisano', None],
    [4, 2, 3, '2026-03-02', 3, 'Usmeno', 'Treba više vježbati'], [5, 3, 2, '2026-02-17', 2, 'Kontrolni', 'Popravni u ožujku']],
   report=('predmet_id', 'datum')),
  T('izostanak', 'Izostanci', 'Izostanci s nastave i je li opravdan.', [
    PK('Šifra izostanka.'), REF('ucenik_id', 'Učenik', 'ucenik.sifra', 'Tko je izostao.', required=True), datum('Dan izostanka.'),
    whole('sati_izostanka', 'Sati', 'kolicina', 'Broj sati izostanka.', default='1', **gtz('Broj sati mora biti veći od nule.')),
    flag('opravdano', 'Opravdano', 'Označi kad je izostanak opravdan.', default='False'), txt('razlog', 'Razlog', 'opis', 'Zašto je izostao.')],
   [[1, 1, '2026-02-20', 6, 1, 'Bolest'], [2, 3, '2026-03-03', 2, 0, None], [3, 2, '2026-03-05', 6, 1, 'Liječnički pregled']]),
])

D('ordinacija', 'Ordinacija i pacijenti',
  'Mala ordinacija: pacijenti, zakazani termini, pregledi s dijagnozom te propisani lijekovi.',
  'zdravlje,ordinacija,evidencija', [
  T('pacijent', 'Pacijenti', 'Osobe koje se liječe u ordinaciji.', [
    PK('Šifra pacijenta.'), ime(), prezime(), oib(), datum_rodjenja(), txt('spol', 'Spol', 'kategorija', 'Spol.', **ch('M,Ž,Drugo')),
    txt('mbo', 'MBO', 'identifikator', 'Matični broj osiguranika (9 znamenki).', validation='Len([value]) = 9 And IsNumeric([value])', validation_msg='MBO ima 9 znamenki.'),
    telefon(), email(), adresa(), F('alergije', 'Alergije', 'memo', 'biljeska', 'Poznate alergije i nepodnošenje lijekova.'), aktivan()],
   [[1, 'Ivana', 'Šimić', '99999999990', '1985-06-14', 'Ž', '123456789', '091 111 3333', 'ivana.simic@mail.hr', 'Gundulićeva 3, Zagreb', 'Penicilin', 1],
    [2, 'Josip', 'Barišić', '10101010107', '1962-12-02', 'M', '234567890', '098 222 4444', None, 'Kralja Tomislava 10, Zagreb', None, 1]]),
  T('termin', 'Termini', 'Zakazani dolasci pacijenata.', [
    PK('Šifra termina.'), REF('pacijent_id', 'Pacijent', 'pacijent.sifra', 'Tko dolazi.', required=True),
    F('vrijeme_termina', 'Termin', 'datetime', 'datum', 'Datum i sat termina.', required=True),
    whole('trajanje_min', 'Trajanje (min)', 'kolicina', 'Planirano trajanje u minutama.', default='20', **gtz('Trajanje mora biti veće od nule.')),
    txt('status_termina', 'Status', 'status', 'Je li pacijent došao.', **ch('Zakazan,Došao,Nije došao,Otkazan', 'Zakazan')), napomena()],
   [[1, 1, '2026-03-16 09:00:00', 20, 'Zakazan', None], [2, 2, '2026-03-16 09:30:00', 30, 'Zakazan', 'Kontrola tlaka'], [3, 1, '2026-02-10 10:00:00', 20, 'Došao', None]]),
  T('pregled', 'Pregledi', 'Obavljeni pregledi s razlogom dolaska, dijagnozom i nalazom.', [
    PK('Šifra pregleda.'), REF('pacijent_id', 'Pacijent', 'pacijent.sifra', 'Tko je pregledan.', required=True), datum('Datum pregleda.'),
    txt('razlog', 'Razlog', 'opis', 'Zašto dolazi.'), txt('dijagnoza', 'Dijagnoza', 'opis', 'Dijagnoza (tekst ili šifra MKB).'),
    F('nalaz', 'Nalaz', 'memo', 'opis', 'Nalaz i opis pregleda.'), F('terapija', 'Terapija', 'memo', 'opis', 'Preporučena terapija.'),
    dt('datum_kontrole', 'Kontrola', 'Kada se pacijent treba vratiti.')],
   [[1, 1, '2026-02-10', 'Kašalj i temperatura', 'J20 Akutni bronhitis', 'Hripanje desno, temperatura 38,1.', 'Mirovanje, tekućina, antibiotik.', '2026-02-17'],
    [2, 2, '2026-01-22', 'Kontrola tlaka', 'I10 Hipertenzija', 'Tlak 150/95.', 'Prilagodba terapije.', '2026-03-16']]),
  T('lijek', 'Lijekovi', 'Popis lijekova koji se propisuju.', [
    PK('Šifra lijeka.'), naziv('Zaštićeni naziv lijeka.'), txt('djelatna_tvar', 'Djelatna tvar', 'opis', 'Aktivna tvar.'),
    txt('oblik', 'Oblik', 'kategorija', 'Farmaceutski oblik.', **ch('Tableta,Kapsula,Sirup,Mast,Kapi,Injekcija', 'Tableta')), txt('jacina', 'Jačina', 'oznaka', 'Npr. 500 mg.')],
   [[1, 'Amoksiklav', 'Amoksicilin/klavulanska kiselina', 'Tableta', '625 mg'], [2, 'Lizinopril', 'Lizinopril', 'Tableta', '10 mg'], [3, 'Paracetamol', 'Paracetamol', 'Tableta', '500 mg']]),
  T('propisani_lijek', 'Propisani lijekovi', 'Što je propisano na pregledu.', [
    PK('Šifra stavke.'), REF('pregled_id', 'Pregled', 'pregled.sifra', 'Pregled na kojem je propisano.', required=True, on_delete='cascade'),
    REF('lijek_id', 'Lijek', 'lijek.sifra', 'Propisani lijek.', required=True), txt('doziranje', 'Doziranje', 'opis', 'Npr. 2 puta dnevno po 1 tableta.'),
    whole('trajanje_dana', 'Trajanje (dana)', 'kolicina', 'Koliko dana traje terapija.', **gtz('Trajanje mora biti veće od nule.'))],
   [[1, 1, 1, '2 puta dnevno po 1 tableta', 7], [2, 1, 3, 'Po potrebi do 3 puta dnevno', 5], [3, 2, 2, '1 puta dnevno ujutro', 30]]),
])

D('dogadjanja', 'Događanja i ulaznice',
  'Organizacija događanja: događaj s kapacitetom i cijenom, sudionici, prodane ulaznice i program po terminima.',
  'dogadjaji,ulaznice,organizacija', [
  T('dogadjaj', 'Događaji', 'Konferencije, koncerti, radionice.', [
    PK('Šifra događaja.'), naziv('Naziv događaja.'), opis('Opis i program.'),
    F('pocetak_dogadjaja', 'Početak', 'datetime', 'datum', 'Datum i sat početka.'),
    txt('lokacija_dogadjaja', 'Lokacija', 'adresa', 'Gdje se događaj održava.', width=200),
    whole('kapacitet', 'Kapacitet', 'kolicina', 'Najveći broj sudionika.', **gtz('Kapacitet mora biti veći od nule.')),
    cur('cijena_ulaznice', 'Cijena ulaznice', 'cijena', 'Osnovna cijena ulaznice.', **pos('Cijena ne može biti negativna.')),
    txt('status_dogadjaja', 'Status', 'status', 'Stanje događaja.', **ch('Planiran,Otvorena prodaja,Rasprodano,Održan,Otkazan', 'Planiran'))],
   [[1, 'Konferencija o digitalizaciji', 'Jednodnevna konferencija s radionicama.', '2026-05-14 09:00:00', 'Kongresni centar, Zagreb', 300, 80, 'Otvorena prodaja'],
    [2, 'Ljetni koncert', 'Koncert na otvorenom.', '2026-07-18 21:00:00', 'Park Maksimir, Zagreb', 1500, 25, 'Planiran']],
   report=('status_dogadjaja', 'pocetak_dogadjaja')),
  T('sudionik', 'Sudionici', 'Posjetitelji i kupci ulaznica.', [
    PK('Šifra sudionika.'), ime(), prezime(), email(), telefon(), txt('organizacija', 'Organizacija', 'naziv', 'Tvrtka ili udruga.')],
   [[1, 'Nikola', 'Kralj', 'nikola.kralj@mail.hr', '091 123 4567', 'Tehno Plus d.o.o.'], [2, 'Lana', 'Horvat', 'lana.horvat@mail.hr', '098 987 6543', None], [3, 'Tin', 'Babić', 'tin.babic@mail.hr', None, 'Kvaka d.o.o.']]),
  T('ulaznica', 'Ulaznice', 'Prodane ulaznice s cijenom, plaćanjem i prijavom na ulazu.', [
    PK('Šifra ulaznice.'), REF('dogadjaj_id', 'Događaj', 'dogadjaj.sifra', 'Za koji događaj.', required=True), REF('sudionik_id', 'Sudionik', 'sudionik.sifra', 'Tko je kupio.', required=True),
    txt('broj_ulaznice', 'Broj ulaznice', 'identifikator', 'Jedinstveni broj za provjeru na ulazu.', required=True),
    txt('vrsta_ulaznice', 'Vrsta', 'kategorija', 'Vrsta ulaznice.', **ch('Standard,VIP,Student,Besplatna', 'Standard')),
    cur('cijena', 'Cijena', 'cijena', 'Plaćena cijena.', **pos('Cijena ne može biti negativna.')), dt('datum_kupnje', 'Kupljeno', 'Kada je kupljena.', default='Date()'),
    flag('placeno', 'Plaćeno', 'Označi kad je uplata evidentirana.', default='False'), flag('prijavljen', 'Prijavljen', 'Označi kad se osoba prijavila na ulazu.', default='False')],
   [[1, 1, 1, 'K26-0001', 'Standard', 80, '2026-03-01', 1, 0], [2, 1, 2, 'K26-0002', 'Student', 40, '2026-03-02', 1, 0], [3, 1, 3, 'K26-0003', 'VIP', 150, '2026-03-05', 0, 0], [4, 2, 2, 'L26-0001', 'Standard', 25, '2026-03-10', 1, 0]]),
  T('program_dogadjaja', 'Program', 'Termini i izvođači na događaju.', [
    PK('Šifra stavke programa.'), REF('dogadjaj_id', 'Događaj', 'dogadjaj.sifra', 'Događaj.', required=True, on_delete='cascade'),
    F('pocetak_nastupa', 'Početak', 'datetime', 'datum', 'Datum i sat početka.'), F('naslov', 'Naslov', 'text', 'naziv', 'Naslov.', required=True),
    txt('izvodjac', 'Izvođač', 'naziv', 'Govornik ili izvođač.'), txt('dvorana', 'Dvorana', 'adresa', 'Gdje se održava.')],
   [[1, 1, '2026-05-14 09:30:00', 'Otvorenje', 'Marta Novak', 'Velika dvorana'], [2, 1, '2026-05-14 11:00:00', 'Radionica: Digitalni procesi', 'Goran Matić', 'Dvorana 2'], [3, 2, '2026-07-18 21:00:00', 'Glavni nastup', 'Bend Sjever', 'Pozornica']]),
])

D('teretana', 'Teretana i članstvo',
  'Fitness klub: članovi, paketi članarine, članarine s rokom, dolasci i grupni treninzi.',
  'sport,clanstvo,usluge', [
  T('polaznik', 'Članovi', 'Osobe koje treniraju u klubu.', [
    PK('Šifra člana.'), ime(), prezime(), email(), telefon(), datum_rodjenja(),
    F('datum_uclanjenja', 'Član od', 'date', 'datum', 'Kada je osoba postala član.', default='Date()'), aktivan(), napomena()],
   [[1, 'Ante', 'Radić', 'ante.radic@mail.hr', '091 444 5555', '1990-03-15', '2025-01-10', 1, None], [2, 'Maja', 'Lukić', 'maja.lukic@mail.hr', '098 666 7777', '1995-08-21', '2025-09-01', 1, 'Trenira uz trenera'],
    [3, 'Karlo', 'Vuković', 'karlo.vukovic@mail.hr', None, '2001-11-05', '2026-01-15', 1, None]]),
  T('paket_clanarine', 'Paketi članarine', 'Vrste članarina i njihove cijene.', [
    PK('Šifra paketa.'), naziv('Naziv paketa (npr. Mjesečna).'), whole('trajanje_dana', 'Trajanje (dana)', 'kolicina', 'Koliko dana članarina vrijedi.', **gtz('Trajanje mora biti veće od nule.')),
    cur('cijena', 'Cijena', 'cijena', 'Cijena paketa.', **pos('Cijena ne može biti negativna.')), opis('Što paket uključuje.'), aktivan()],
   [[1, 'Mjesečna', 30, 35, 'Neograničen ulazak u teretanu.', 1], [2, 'Tromjesečna', 90, 90, 'Uključuje 2 grupna treninga tjedno.', 1], [3, 'Godišnja', 365, 320, 'Najpovoljnije, uključuje ručnik i ormarić.', 1]]),
  T('clanarina', 'Članarine', 'Plaćene članarine s početkom i krajem.', [
    PK('Šifra članarine.'), REF('polaznik_id', 'Član', 'polaznik.sifra', 'Tko je platio.', required=True), REF('paket_id', 'Paket', 'paket_clanarine.sifra', 'Koji paket.', required=True),
    dt('pocetak', 'Početak', 'Prvi dan članarine.'), dt('kraj', 'Kraj', 'Zadnji dan članarine.'), iznos('Plaćeni iznos.'),
    txt('nacin_placanja', 'Način plaćanja', 'kategorija', 'Kako kupac plaća.', **ch('Virman,Gotovina,Kartica,Pouzeće', 'Kartica'))],
   [[1, 1, 3, '2026-01-10', '2027-01-09', 320, 'Kartica'], [2, 2, 2, '2026-02-01', '2026-05-01', 90, 'Gotovina'], [3, 3, 1, '2026-03-01', '2026-03-30', 35, 'Kartica']]),
  T('dolazak', 'Dolasci', 'Evidencija ulazaka u klub.', [
    PK('Šifra dolaska.'), REF('polaznik_id', 'Član', 'polaznik.sifra', 'Tko je došao.', required=True),
    F('vrijeme_dolaska', 'Dolazak', 'datetime', 'datum', 'Kada je član ušao.', default='Now()')],
   [[1, 1, '2026-03-02 07:15:00'], [2, 2, '2026-03-02 18:30:00'], [3, 1, '2026-03-04 07:20:00'], [4, 3, '2026-03-04 19:00:00']]),
  T('grupni_trening', 'Grupni treninzi', 'Tjedni raspored grupnih treninga.', [
    PK('Šifra treninga.'), naziv('Naziv treninga (npr. Pilates).'), txt('trener', 'Trener', 'naziv', 'Tko vodi trening.'),
    txt('dan_u_tjednu', 'Dan', 'kategorija', 'Dan održavanja.', **ch('Ponedjeljak,Utorak,Srijeda,Četvrtak,Petak,Subota,Nedjelja', 'Ponedjeljak')),
    F('vrijeme_pocetka', 'Početak', 'time', 'vrijeme', 'Sat početka treninga.'), whole('kapacitet', 'Kapacitet', 'kolicina', 'Najveći broj sudionika.', **gtz('Kapacitet mora biti veći od nule.')), aktivan()],
   [[1, 'Pilates', 'Dora Matić', 'Ponedjeljak', '18:00', 12, 1], [2, 'Spinning', 'Ivo Perić', 'Srijeda', '19:00', 16, 1], [3, 'Funkcionalni trening', 'Ivo Perić', 'Petak', '17:30', 14, 1]]),
])

D('trening_dnevnik', 'Dnevnik treninga',
  'Osobni dnevnik vježbanja: vježbe, treninzi sa serijama (ponavljanja i težina) i tjelesne mjere kroz vrijeme.',
  'osobno,sport,zdravlje', [
  T('vjezba', 'Vježbe', 'Popis vježbi s mišićnom skupinom.', [
    PK('Šifra vježbe.'), naziv('Naziv vježbe.'),
    txt('misicna_skupina', 'Mišićna skupina', 'kategorija', 'Glavna skupina koja radi.', **ch('Prsa,Leđa,Noge,Ramena,Ruke,Trbuh,Kardio', 'Prsa')), opis('Kako se izvodi i na što paziti.')],
   [[1, 'Potisak s klupe', 'Prsa', 'Šipka, ležeći na klupi.'], [2, 'Čučanj', 'Noge', 'Šipka na ramenima, koljena u liniji s prstima.'], [3, 'Zgibovi', 'Leđa', None], [4, 'Trčanje', 'Kardio', 'Staza ili traka.']]),
  T('trening', 'Treninzi', 'Jedan trening: datum, trajanje i osjećaj.', [
    PK('Šifra treninga.'), datum('Dan treninga.'), naziv('Naziv treninga (npr. Gornji dio tijela).'),
    whole('trajanje_min', 'Trajanje (min)', 'kolicina', 'Planirano trajanje u minutama.', **gtz('Trajanje mora biti veće od nule.')),
    F('osjecaj', 'Osjećaj', 'integer', 'rezultat', 'Kako je trening prošao, 1-5.', validation='[value] >= 1 And [value] <= 5', validation_msg='Osjećaj je od 1 do 5.'), napomena()],
   [[1, '2026-03-02', 'Gornji dio tijela', 65, 4, None], [2, '2026-03-04', 'Noge', 70, 5, 'Novi rekord u čučnju'], [3, '2026-03-06', 'Trčanje', 40, 3, 'Umor']]),
  T('serija_vjezbe', 'Serije', 'Serije pojedine vježbe unutar treninga.', [
    PK('Šifra serije.'), REF('trening_id', 'Trening', 'trening.sifra', 'Trening.', required=True, on_delete='cascade'), REF('vjezba_id', 'Vježba', 'vjezba.sifra', 'Vježba.', required=True),
    whole('redni_broj', 'Serija', 'redoslijed', 'Redni broj serije.'), whole('ponavljanja', 'Ponavljanja', 'kolicina', 'Broj ponavljanja.', **gtz('Broj ponavljanja mora biti veći od nule.')),
    dec('tezina_kg', 'Težina (kg)', 'kolicina', 'Težina utega.', decimals=1, **pos('Težina ne može biti negativna.')), napomena()],
   [[1, 1, 1, 1, 8, 70, None], [2, 1, 1, 2, 8, 70, None], [3, 1, 1, 3, 6, 75, 'Teško'], [4, 1, 3, 1, 8, 0, None], [5, 2, 2, 1, 5, 100, None], [6, 2, 2, 2, 5, 105, 'Rekord']]),
  T('tjelesna_mjera', 'Tjelesne mjere', 'Težina i opsezi kroz vrijeme za praćenje napretka.', [
    PK('Šifra mjerenja.'), datum('Dan mjerenja.'), dec('tezina_kg', 'Težina (kg)', 'kolicina', 'Težina utega.', decimals=1, **pos('Težina ne može biti negativna.')),
    dec('postotak_masti', 'Postotak masti', 'postotak', 'Udio masnog tkiva u postocima.', decimals=1, validation='[value] >= 0 And [value] <= 100', validation_msg='Postotak je od 0 do 100.'),
    dec('opseg_struka_cm', 'Opseg struka (cm)', 'kolicina', 'Opseg struka u centimetrima.', decimals=1, **pos('Opseg ne može biti negativan.')), napomena()],
   [[1, '2026-01-04', 82.5, 20.1, 88, None], [2, '2026-02-01', 81.2, 19.4, 86.5, None], [3, '2026-03-01', 80.4, 18.8, 85, 'Nakon dva mjeseca treninga']]),
])
print('paketi 1-3 napisani')

# ---- brza provjera dosljednosti svih domena (isto sto radi ValidateCatalog u Pascalu) ----
import glob
seen = {}; tables = {}
for p in sorted(glob.glob(OUT + '/*.json')):
    dom = json.load(open(p, encoding='utf-8'))
    for t in dom['tables']:
        assert t['name'] not in tables, ('tablica se ponavlja', t['name'], dom['id'], tables[t['name']])
        tables[t['name']] = dom['id']
        for f in t['fields']:
            if f.get('pk') or 'ref' in f: continue
            key = f.get('concept', f['name'])
            sig = (f['type'], f['role'])
            if key in seen and seen[key][0] != sig:
                print('KONFLIKT', key, seen[key], (sig, dom['id'], t['name']))
            seen.setdefault(key, (sig, dom['id'], t['name']))
print(len(tables), 'tablica,', len(seen), 'koncepata')
