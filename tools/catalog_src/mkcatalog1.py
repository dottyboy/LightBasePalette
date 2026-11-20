import json, os
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), 'catalog')
os.makedirs(OUT, exist_ok=True)

def F(name, caption, typ, role, descr, **kw):
    d = {'name': name, 'caption': caption, 'type': typ, 'role': role, 'descr': descr}
    for k, v in kw.items():
        d[k.replace('_ref', 'ref') if k == 'ref_' else k] = v
    return d

def PK(descr='Šifra retka, dodjeljuje se automatski.'):
    return {'name': 'sifra', 'caption': 'Šifra', 'type': 'autonumber', 'role': 'kljuc', 'descr': descr, 'pk': True}

def REF(name, caption, ref, descr, required=False, on_delete=None):
    d = {'name': name, 'caption': caption, 'type': 'integer', 'role': 'veza', 'descr': descr, 'ref': ref}
    if required: d['required'] = True
    if on_delete: d['on_delete'] = on_delete
    return d

def T(name, caption, descr, fields, sample=None, report=None):
    d = {'name': name, 'caption': caption, 'descr': descr, 'fields': fields}
    if sample: d['sample'] = sample
    if report: d.update({'report': True, 'report_group': report[0], 'report_sort': report[1]})
    return d

def write(dom):
    path = os.path.join(OUT, dom['id'] + '.json')
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(dom, f, ensure_ascii=False, indent=1)
        f.write('\n')

# ---- zajednicka polja (isti koncept = ista definicija u svim domenama) ----
def naziv(descr='Naziv koji se prikazuje u popisima i padajućim izbornicima.', **kw):
    return F('naziv', 'Naziv', 'text', 'naziv', descr, required=True, **kw)
def opis(descr='Dulji slobodan opis.'):
    return F('opis', 'Opis', 'memo', 'opis', descr)
def napomena(descr='Slobodna bilješka koja se ne koristi u izračunima.'):
    return F('napomena', 'Napomena', 'memo', 'biljeska', descr)
def aktivan(descr='Isključi umjesto brisanja kad se redak više ne koristi, da stara povijest ostane čitljiva.'):
    return F('aktivan', 'Aktivan', 'yesno', 'oznaka', descr, default='True')
def email():
    return F('email', 'E-pošta', 'text', 'kontakt', 'Adresa elektroničke pošte; provjerava se oblik a@b.c.',
             validation='[value] Like "*@*.*"', validation_msg='Unesi ispravnu adresu e-pošte (npr. ime@tvrtka.hr).', width=200)
def telefon():
    return F('telefon', 'Telefon', 'text', 'kontakt', 'Broj telefona ili mobitela, slobodnog oblika.')
def adresa():
    return F('adresa', 'Adresa', 'text', 'adresa', 'Ulica i kućni broj.', width=200)
def postanski():
    return F('postanski_broj', 'Poštanski broj', 'text', 'adresa', 'Poštanski broj mjesta.')
def mjesto():
    return F('mjesto', 'Mjesto', 'text', 'adresa', 'Grad ili naselje.')
def drzava():
    return F('drzava', 'Država', 'text', 'adresa', 'Država; zadano Hrvatska.', default='"Hrvatska"')
def oib():
    return F('oib', 'OIB', 'text', 'identifikator', 'Osobni identifikacijski broj, 11 znamenki (kod tvrtke ili osobe).',
             validation='Len([value]) = 11 And IsNumeric([value])', validation_msg='OIB mora imati točno 11 znamenki.')
def iban():
    return F('iban', 'IBAN', 'text', 'identifikator', 'Međunarodni broj računa, npr. HR12 3456 7890 1234 5678 9.',
             validation='Len([value]) >= 15', validation_msg='IBAN je prekratak.', width=220)
def datum(descr='Datum događaja.'):
    return F('datum', 'Datum', 'date', 'datum', descr, default='Date()')
def ime():
    return F('ime', 'Ime', 'text', 'naziv', 'Osobno ime.', required=True)
def prezime():
    return F('prezime', 'Prezime', 'text', 'naziv', 'Prezime.', required=True)
def iznos(descr='Novčani iznos u eurima.'):
    return F('iznos', 'Iznos', 'currency', 'iznos', descr, decimals=2)
def porcije():
    return F('porcije', 'Porcije', 'integer', 'kolicina', 'Za koliko osoba je recept ili obrok.', default='4',
             validation='[value] > 0', validation_msg='Broj porcija mora biti veći od nule.')

# =========================== RACUNI ===========================
racuni = {
 'id': 'racuni', 'title': 'Računi i fakturiranje',
 'descr': 'Mali obrt ili tvrtka: kupci, artikli i usluge, izdani računi sa stavkama i evidencija plaćanja.',
 'tags': 'posao,financije,prodaja',
 'tables': [
  T('kupac', 'Kupci', 'Tvrtke i osobe kojima se ispostavljaju računi.', [
    PK('Interna šifra kupca.'),
    naziv('Naziv tvrtke ili ime i prezime kupca kako se ispisuje na računu.'),
    oib(), adresa(), postanski(), mjesto(), drzava(), email(), telefon(),
    F('rok_placanja', 'Rok plaćanja (dana)', 'integer', 'kolicina', 'Koliko dana nakon računa kupac plaća; koristi se za datum dospijeća.', default='15',
      validation='[value] >= 0', validation_msg='Rok ne može biti negativan.'),
    aktivan(), napomena()],
   [[1, 'Kvaka d.o.o.', '12345678903', 'Ilica 12', '10000', 'Zagreb', 'Hrvatska', 'racuni@kvaka.hr', '01 555 1234', 30, 1, None],
    [2, 'Marija Horvat', '98765432109', 'Trg bana Jelačića 3', '10000', 'Zagreb', 'Hrvatska', 'marija.horvat@mail.hr', '091 222 3344', 8, 1, None],
    [3, 'Adria promet d.d.', '45678912305', 'Riva 7', '21000', 'Split', 'Hrvatska', 'uprava@adria-promet.hr', '021 330 440', 15, 1, 'Plaća uvijek na zadnji dan'],
    [4, 'Alpenhof GmbH', '11223344556', 'Hauptstrasse 5', '8010', 'Graz', 'Austrija', 'office@alpenhof.at', '+43 316 123456', 30, 1, 'Račun bez PDV-a (EU isporuka)']]),
  T('artikl', 'Artikli i usluge', 'Što se prodaje: roba i usluge s cijenom, jedinicom mjere i stopom PDV-a.', [
    PK('Interna šifra artikla.'),
    F('kod', 'Kod', 'text', 'identifikator', 'Vlastita ili tvornička oznaka artikla (npr. barkod).', width=120),
    naziv('Naziv artikla ili usluge kako se ispisuje na računu.'),
    opis('Opis artikla, uvjeti, napomene o isporuci.'),
    F('jedinica', 'Jedinica', 'text', 'mjera', 'Jedinica mjere za količinu na stavci.', choices='kom,kg,l,m,sat,usluga', default='"kom"'),
    F('cijena', 'Cijena', 'currency', 'cijena', 'Jedinična cijena bez PDV-a.', decimals=2, validation='[value] >= 0', validation_msg='Cijena ne može biti negativna.'),
    F('pdv_stopa', 'PDV (%)', 'decimal', 'postotak', 'Stopa PDV-a u postocima (0, 5, 13 ili 25).', decimals=0, default='25',
      validation='[value] In (0, 5, 13, 25)', validation_msg='Dopuštene stope PDV-a: 0, 5, 13, 25.'),
    aktivan()],
   [[1, 'KON-60', 'Konzultacije', 'Savjetovanje po satu', 'sat', 60.0, 25, 1],
    [2, 'WEB-01', 'Izrada web stranice', 'Paket do 5 podstranica', 'usluga', 850.0, 25, 1],
    [3, 'HST-12', 'Hosting 12 mjeseci', 'Godišnji najam poslužitelja', 'usluga', 120.0, 25, 1],
    [4, 'KNJ-01', 'Stručna knjiga', 'Tiskano izdanje', 'kom', 24.5, 5, 1],
    [5, 'DOS-10', 'Dostava', 'Dostava paketa na adresu', 'kom', 5.0, 25, 1]]),
  T('racun', 'Računi', 'Izdani računi. Iznosi se zbrajaju iz stavki; status prati naplatu.', [
    PK('Interna šifra računa.'),
    F('broj', 'Broj računa', 'text', 'identifikator', 'Službeni broj računa u obliku godina-redni broj (npr. 2026-0001).', required=True, width=110),
    REF('kupac_id', 'Kupac', 'kupac.sifra', 'Kome je račun ispostavljen.', required=True),
    datum('Datum izdavanja računa.'),
    F('datum_dospijeca', 'Dospijeće', 'date', 'datum', 'Do kada kupac treba platiti.'),
    F('status_racuna', 'Status', 'text', 'status', 'Naplata računa: otvoren, djelomično plaćen, plaćen ili storniran.',
      choices='Otvoren,Djelomično plaćen,Plaćen,Storniran', default='"Otvoren"'),
    F('nacin_placanja', 'Način plaćanja', 'text', 'kategorija', 'Kako kupac plaća.', choices='Virman,Gotovina,Kartica,Pouzeće', default='"Virman"'),
    F('osnovica', 'Osnovica', 'currency', 'iznos', 'Zbroj stavki bez PDV-a.', decimals=2),
    F('pdv_iznos', 'PDV', 'currency', 'iznos', 'Obračunani PDV.', decimals=2),
    F('ukupno', 'Ukupno', 'currency', 'iznos', 'Iznos za platiti (osnovica + PDV).', decimals=2),
    napomena('Tekst koji se ispisuje na računu (npr. poziv na broj, uputa za plaćanje).')],
   [[1, '2026-0001', 1, '2026-01-15', '2026-02-14', 'Plaćen', 'Virman', 1000.0, 250.0, 1250.0, None],
    [2, '2026-0002', 2, '2026-02-03', '2026-02-11', 'Plaćen', 'Gotovina', 120.0, 30.0, 150.0, None],
    [3, '2026-0003', 3, '2026-03-10', '2026-03-25', 'Otvoren', 'Virman', 850.0, 212.5, 1062.5, 'Poziv na broj 2026-0003'],
    [4, '2026-0004', 1, '2026-03-20', '2026-04-19', 'Djelomično plaćen', 'Virman', 175.0, 43.75, 218.75, None]],
   report=('status_racuna', 'datum')),
  T('stavka_racuna', 'Stavke računa', 'Redci računa: što je prodano, u kojoj količini i po kojoj cijeni.', [
    PK('Interna šifra stavke.'),
    REF('racun_id', 'Račun', 'racun.sifra', 'Račun kojem stavka pripada; brisanjem računa brišu se i stavke.', required=True, on_delete='cascade'),
    REF('artikl_id', 'Artikl', 'artikl.sifra', 'Prodani artikl ili usluga.'),
    F('naziv_stavke', 'Naziv stavke', 'text', 'naziv', 'Tekst na računu; zadano naziv artikla, može se prepraviti.', width=220),
    F('kolicina', 'Količina', 'decimal', 'kolicina', 'Prodana količina.', decimals=2, default='1',
      validation='[value] > 0', validation_msg='Količina mora biti veća od nule.'),
    F('cijena', 'Cijena', 'currency', 'cijena', 'Jedinična cijena bez PDV-a.', decimals=2, validation='[value] >= 0', validation_msg='Cijena ne može biti negativna.'),
    F('rabat', 'Rabat (%)', 'decimal', 'postotak', 'Popust na stavku u postocima.', decimals=1, default='0',
      validation='[value] >= 0 And [value] <= 100', validation_msg='Rabat mora biti između 0 i 100.'),
    F('pdv_stopa', 'PDV (%)', 'decimal', 'postotak', 'Stopa PDV-a u postocima (0, 5, 13 ili 25).', decimals=0, default='25',
      validation='[value] In (0, 5, 13, 25)', validation_msg='Dopuštene stope PDV-a: 0, 5, 13, 25.'),
    F('iznos', 'Iznos', 'currency', 'iznos', 'Iznos stavke bez PDV-a: količina × cijena − rabat.', decimals=2)],
   [[1, 1, 1, 'Konzultacije', 10, 60.0, 0, 25, 600.0],
    [2, 1, 2, 'Izrada web stranice', 1, 850.0, 52.9, 25, 400.0],
    [3, 2, 3, 'Hosting 12 mjeseci', 1, 120.0, 0, 25, 120.0],
    [4, 3, 2, 'Izrada web stranice', 1, 850.0, 0, 25, 850.0],
    [5, 4, 4, 'Stručna knjiga', 5, 24.5, 0, 5, 122.5],
    [6, 4, 5, 'Dostava', 1, 5.0, 0, 25, 5.0],
    [7, 4, 1, 'Konzultacije', 1, 60.0, 0, 25, 47.5]]),
  T('placanje', 'Plaćanja', 'Uplate po računima; zbroj uplata uspoređuje se s iznosom računa.', [
    PK('Interna šifra uplate.'),
    REF('racun_id', 'Račun', 'racun.sifra', 'Račun na koji se uplata odnosi.', required=True),
    datum('Datum uplate.'),
    iznos('Uplaćeni iznos u eurima.'),
    F('nacin_placanja', 'Način plaćanja', 'text', 'kategorija', 'Kako kupac plaća.', choices='Virman,Gotovina,Kartica,Pouzeće', default='"Virman"'),
    F('poziv_na_broj', 'Poziv na broj', 'text', 'identifikator', 'Poziv na broj iz uplatnice; služi za automatsko spajanje uplate s računom.'),
    napomena()],
   [[1, 1, '2026-02-10', 1250.0, 'Virman', '2026-0001', None],
    [2, 2, '2026-02-03', 150.0, 'Gotovina', None, 'Plaćeno pri preuzimanju'],
    [3, 4, '2026-04-02', 100.0, 'Virman', '2026-0004', 'Prva rata']]),
 ]}
write(racuni)

# =========================== RECEPTI ===========================
recepti = {
 'id': 'recepti', 'title': 'Kuharski recepti',
 'descr': 'Zbirka recepata s namirnicama i količinama, kategorijama, ocjenama i tjednim planom obroka.',
 'tags': 'osobno,kuhinja,hrana',
 'tables': [
  T('kategorija_recepta', 'Kategorije recepata', 'Skupine jela po kojima se recepti razvrstavaju.', [
    PK('Šifra kategorije.'), naziv('Naziv kategorije (npr. Juhe, Deserti).'), opis('Što spada u kategoriju.')],
   [[1, 'Juhe i variva', 'Juhe, čorbe i variva'], [2, 'Glavna jela', 'Mesna, riblja i vegetarijanska jela'],
    [3, 'Prilozi i salate', 'Prilozi uz glavno jelo'], [4, 'Deserti', 'Kolači, torte i slatka jela']]),
  T('namirnica', 'Namirnice', 'Sastojci koji se koriste u receptima, s mjernom jedinicom i energetskom vrijednošću.', [
    PK('Šifra namirnice.'), naziv('Naziv namirnice.'),
    F('skupina', 'Skupina', 'text', 'kategorija', 'Vrsta namirnice za razvrstavanje popisa za kupnju.',
      choices='Povrće,Voće,Meso,Riba,Mliječni proizvodi,Žitarice,Začini,Ostalo', default='"Ostalo"'),
    F('mjerna_jedinica', 'Jedinica', 'text', 'mjera', 'Uobičajena jedinica u kojoj se namirnica mjeri u receptima.',
      choices='g,kg,ml,dl,l,kom,žlica,žličica,prstohvat', default='"g"'),
    F('kcal_100', 'kcal na 100 g', 'integer', 'kolicina', 'Energetska vrijednost na 100 grama ili 100 ml.', validation='[value] >= 0', validation_msg='Vrijednost ne može biti negativna.'),
    aktivan()],
   [[1, 'Brašno', 'Žitarice', 'g', 364, 1], [2, 'Jaja', 'Ostalo', 'kom', 143, 1], [3, 'Mlijeko', 'Mliječni proizvodi', 'dl', 64, 1],
    [4, 'Šećer', 'Ostalo', 'g', 400, 1], [5, 'Mrkva', 'Povrće', 'g', 41, 1], [6, 'Krumpir', 'Povrće', 'g', 77, 1],
    [7, 'Piletina (prsa)', 'Meso', 'g', 165, 1], [8, 'Maslinovo ulje', 'Ostalo', 'žlica', 884, 1]]),
  T('recept', 'Recepti', 'Recepti s vremenom pripreme, težinom, ocjenom i uputama.', [
    PK('Šifra recepta.'),
    naziv('Naziv jela.'),
    REF('kategorija_id', 'Kategorija', 'kategorija_recepta.sifra', 'Kategorija jela.'),
    porcije(),
    F('priprema_min', 'Priprema (min)', 'integer', 'kolicina', 'Vrijeme pripreme sastojaka u minutama.', validation='[value] >= 0', validation_msg='Vrijeme ne može biti negativno.'),
    F('kuhanje_min', 'Kuhanje (min)', 'integer', 'kolicina', 'Vrijeme kuhanja ili pečenja u minutama.', validation='[value] >= 0', validation_msg='Vrijeme ne može biti negativno.'),
    F('tezina', 'Težina', 'text', 'kategorija', 'Koliko je recept zahtjevan.', choices='Lagano,Srednje,Teško', default='"Srednje"'),
    F('upute', 'Upute', 'memo', 'opis', 'Postupak pripreme korak po korak.'),
    F('ocjena', 'Ocjena', 'integer', 'rezultat', 'Osobna ocjena od 1 do 5.', validation='[value] >= 1 And [value] <= 5', validation_msg='Ocjena je od 1 do 5.'),
    F('omiljeno', 'Omiljeno', 'yesno', 'oznaka', 'Označi recepte koje često radiš.', default='False'),
    F('datum_dodavanja', 'Dodano', 'date', 'datum', 'Kada je recept unesen.', default='Date()')],
   [[1, 'Palačinke', 4, 4, 10, 20, 'Lagano', 'Umutiti jaja, mlijeko i brašno. Peći tanke palačinke na zagrijanoj tavi.', 5, 1, '2026-01-10'],
    [2, 'Pileća juha', 1, 6, 20, 90, 'Srednje', 'Kuhati piletinu s mrkvom 1,5 sat. Procijediti i dodati rezance.', 4, 0, '2026-01-12'],
    [3, 'Pečeni krumpir s piletinom', 2, 4, 15, 50, 'Lagano', 'Poredati u lim, preliti uljem, peći na 200 °C.', 4, 1, '2026-02-01']],
   report=('kategorija_id', 'naziv')),
  T('recept_namirnica', 'Sastojci recepta', 'Koja namirnica i u kojoj količini ulazi u koji recept.', [
    PK('Šifra retka.'),
    REF('recept_id', 'Recept', 'recept.sifra', 'Recept kojem sastojak pripada.', required=True, on_delete='cascade'),
    REF('namirnica_id', 'Namirnica', 'namirnica.sifra', 'Sastojak.', required=True),
    F('kolicina', 'Količina', 'decimal', 'kolicina', 'Količina sastojka za zadani broj porcija.', decimals=2, required=True,
      validation='[value] > 0', validation_msg='Količina mora biti veća od nule.'),
    F('mjerna_jedinica', 'Jedinica', 'text', 'mjera', 'Uobičajena jedinica u kojoj se namirnica mjeri u receptima.',
      choices='g,kg,ml,dl,l,kom,žlica,žličica,prstohvat', default='"g"'),
    F('bilješka_sastojka'.replace('š', 's'), 'Bilješka', 'text', 'biljeska', 'Način pripreme sastojka (npr. sitno nasjeckano).')],
   [[1, 1, 1, 250, 'g', None], [2, 1, 2, 2, 'kom', None], [3, 1, 3, 5, 'dl', 'mlako'], [4, 1, 4, 20, 'g', None],
    [5, 2, 7, 600, 'g', 'cijela prsa'], [6, 2, 5, 200, 'g', 'narezana'],
    [7, 3, 6, 800, 'g', 'narezan na kriške'], [8, 3, 7, 500, 'g', None], [9, 3, 8, 3, 'žlica', None]]),
  T('plan_obroka', 'Plan obroka', 'Što se kuha kojeg dana; osnova za popis namirnica za kupnju.', [
    PK('Šifra stavke plana.'),
    datum('Dan na koji je obrok planiran.'),
    F('obrok', 'Obrok', 'text', 'kategorija', 'Doba dana.', choices='Doručak,Ručak,Užina,Večera', default='"Ručak"'),
    REF('recept_id', 'Recept', 'recept.sifra', 'Što se kuha.', required=True),
    porcije(), napomena()],
   [[1, '2026-03-02', 'Ručak', 2, 6, None], [2, '2026-03-02', 'Večera', 3, 4, 'Ostaje za sutra'], [3, '2026-03-03', 'Užina', 1, 4, 'Za goste']]),
 ]}
write(recepti)

# =========================== BUDZET ===========================
budzet = {
 'id': 'budzet', 'title': 'Kućni budžet',
 'descr': 'Praćenje osobnih ili obiteljskih financija: računi i novčanici, prihodi i rashodi po kategorijama, mjesečni proračun i ciljevi štednje.',
 'tags': 'osobno,financije,stednja',
 'tables': [
  T('novcanik', 'Računi i novčanici', 'Gdje se drži novac: tekući i štedni račun, gotovina, kartice.', [
    PK('Šifra računa.'), naziv('Naziv računa (npr. Tekući PBZ, Gotovina).'),
    F('vrsta_racuna', 'Vrsta', 'text', 'kategorija', 'Vrsta računa za razvrstavanje.', choices='Tekući račun,Štedni račun,Gotovina,Kartica,Investicije', default='"Tekući račun"'),
    iban(),
    F('pocetno_stanje', 'Početno stanje', 'currency', 'iznos', 'Stanje na dan početka vođenja; trenutno stanje = početno + promet.', decimals=2, default='0'),
    aktivan()],
   [[1, 'Tekući račun', 'Tekući račun', 'HR1210010051863000160', 1250.0, 1], [2, 'Gotovina', 'Gotovina', None, 150.0, 1],
    [3, 'Štednja', 'Štedni račun', 'HR4423600001101234565', 5000.0, 1]]),
  T('kategorija_troska', 'Kategorije', 'Vrste prihoda i rashoda; mogu se grupirati pod nadkategoriju.', [
    PK('Šifra kategorije.'), naziv('Naziv kategorije (npr. Plaća, Hrana, Režije).'),
    F('vrsta_toka', 'Vrsta', 'text', 'kategorija', 'Je li kategorija prihod ili rashod.', choices='Prihod,Rashod', default='"Rashod"'),
    REF('nadkategorija_id', 'Nadkategorija', 'kategorija_troska.sifra', 'Kategorija višeg reda za izvješća po skupinama.')],
   [[1, 'Plaća', 'Prihod', None], [2, 'Ostali prihodi', 'Prihod', None], [3, 'Stanovanje', 'Rashod', None],
    [4, 'Režije', 'Rashod', 3], [5, 'Hrana', 'Rashod', None], [6, 'Prijevoz', 'Rashod', None], [7, 'Zabava', 'Rashod', None]]),
  T('transakcija', 'Transakcije', 'Svaki prihod i rashod: kada, na kojem računu, u kojoj kategoriji i koliko.', [
    PK('Šifra transakcije.'),
    datum('Datum transakcije.'),
    REF('novcanik_id', 'Račun', 'novcanik.sifra', 'S kojeg ili na koji račun je promet.', required=True),
    REF('kategorija_id', 'Kategorija', 'kategorija_troska.sifra', 'Vrsta prihoda ili rashoda.', required=True),
    iznos('Pozitivan iznos za prihod, negativan za rashod.'),
    F('svrha', 'Svrha', 'text', 'opis', 'Kratki opis (npr. Konzum, kirija ožujak).', width=220),
    F('primatelj', 'Primatelj', 'text', 'naziv', 'Kome je plaćeno ili od koga je novac stigao.'),
    F('ponavljajuce', 'Ponavlja se', 'yesno', 'oznaka', 'Označi stalne mjesečne stavke (kirija, pretplate).', default='False'),
    napomena()],
   [[1, '2026-03-01', 1, 1, 1450.0, 'Plaća ožujak', 'Poslodavac d.o.o.', 1, None],
    [2, '2026-03-02', 1, 3, -520.0, 'Kirija ožujak', 'Vlasnik stana', 1, None],
    [3, '2026-03-04', 2, 5, -43.7, 'Tjedna kupnja', 'Konzum', 0, None],
    [4, '2026-03-06', 1, 4, -85.3, 'Struja i voda', 'HEP, Vodovod', 1, None],
    [5, '2026-03-08', 2, 6, -30.0, 'Gorivo', 'INA', 0, None],
    [6, '2026-03-12', 1, 7, -24.0, 'Kino', 'Cinestar', 0, 'S prijateljima'],
    [7, '2026-03-15', 1, 2, 80.0, 'Honorar', 'Klijent', 0, None]],
   report=('kategorija_id', 'datum')),
  T('proracun', 'Mjesečni proračun', 'Koliko se planira potrošiti po kategoriji u mjesecu; uspoređuje se s transakcijama.', [
    PK('Šifra retka proračuna.'),
    REF('kategorija_id', 'Kategorija', 'kategorija_troska.sifra', 'Za koju kategoriju vrijedi limit.', required=True),
    F('godina', 'Godina', 'integer', 'datum', 'Godina na koju se proračun odnosi.', required=True, validation='[value] >= 2000 And [value] <= 2100', validation_msg='Unesi godinu između 2000 i 2100.'),
    F('mjesec', 'Mjesec', 'integer', 'datum', 'Mjesec (1-12).', required=True, validation='[value] >= 1 And [value] <= 12', validation_msg='Mjesec je od 1 do 12.'),
    F('planirano', 'Planirano', 'currency', 'iznos', 'Planirani iznos za mjesec.', decimals=2, required=True, validation='[value] >= 0', validation_msg='Plan ne može biti negativan.')],
   [[1, 5, 2026, 3, 300.0], [2, 6, 2026, 3, 80.0], [3, 7, 2026, 3, 50.0], [4, 4, 2026, 3, 120.0]]),
  T('cilj_stednje', 'Ciljevi štednje', 'Veći ciljevi za koje se skuplja novac, s rokom i napretkom.', [
    PK('Šifra cilja.'), naziv('Što se kupuje ili za što se štedi.'),
    F('ciljani_iznos', 'Ciljani iznos', 'currency', 'iznos', 'Koliko je ukupno potrebno.', decimals=2, required=True, validation='[value] > 0', validation_msg='Cilj mora biti veći od nule.'),
    F('ustedjeno', 'Ušteđeno', 'currency', 'iznos', 'Koliko je do sada skupljeno.', decimals=2, default='0'),
    F('rok', 'Rok', 'date', 'datum', 'Do kada se želi ostvariti cilj.'),
    F('status_cilja', 'Status', 'text', 'status', 'Napredak cilja.', choices='Aktivan,Ostvaren,Odgođen', default='"Aktivan"'),
    napomena()],
   [[1, 'Ljetovanje', 2000.0, 650.0, '2026-06-30', 'Aktivan', None], [2, 'Nova perilica', 600.0, 600.0, '2026-02-28', 'Ostvaren', None],
    [3, 'Zimnica za auto', 900.0, 0.0, '2026-10-31', 'Odgođen', 'Čeka povećanje']]),
 ]}
write(budzet)

# =========================== KNJIZNICA ===========================
knjiznica = {
 'id': 'knjiznica', 'title': 'Knjižnica',
 'descr': 'Školska ili kućna knjižnica: autori, knjige s brojem primjeraka, članovi i posudbe s rokom vraćanja i zakasninom.',
 'tags': 'obrazovanje,knjige,evidencija',
 'tables': [
  T('autor', 'Autori', 'Pisci čije su knjige u fondu.', [
    PK('Šifra autora.'), ime(), prezime(), drzava(),
    F('godina_rodjenja', 'Godina rođenja', 'integer', 'datum', 'Godina rođenja autora.', validation='[value] >= 1000 And [value] <= 2100', validation_msg='Unesi ispravnu godinu.'),
    F('biografija', 'Biografija', 'memo', 'opis', 'Kratak životopis autora.')],
   [[1, 'Ivana', 'Brlić-Mažuranić', 'Hrvatska', 1874, 'Hrvatska književnica, autorica Priča iz davnine.'],
    [2, 'August', 'Šenoa', 'Hrvatska', 1838, 'Hrvatski romanopisac, autor Zlatareva zlata.'],
    [3, 'Miroslav', 'Krleža', 'Hrvatska', 1893, None], [4, 'Astrid', 'Lindgren', 'Švedska', 1907, 'Autorica Pipi Duge Čarape.']]),
  T('knjiga', 'Knjige', 'Naslovi u fondu, s brojem primjeraka koji se mogu posuditi.', [
    PK('Šifra naslova.'),
    F('naslov', 'Naslov', 'text', 'naziv', 'Naslov knjige.', required=True, width=240),
    REF('autor_id', 'Autor', 'autor.sifra', 'Autor knjige.', required=True),
    F('isbn', 'ISBN', 'text', 'identifikator', 'Međunarodni broj knjige (10 ili 13 znamenki).', validation='Len([value]) = 10 Or Len([value]) = 13', validation_msg='ISBN ima 10 ili 13 znamenki.'),
    F('godina_izdanja', 'Godina izdanja', 'integer', 'datum', 'Godina izdanja ovog primjerka.', validation='[value] >= 1400 And [value] <= 2100', validation_msg='Unesi ispravnu godinu.'),
    F('izdavac', 'Izdavač', 'text', 'naziv', 'Nakladnik.'),
    F('zanr', 'Žanr', 'text', 'kategorija', 'Vrsta knjige.', choices='Roman,Poezija,Krimić,Znanost,Povijest,Za djecu,Ostalo', default='"Roman"'),
    F('jezik', 'Jezik', 'text', 'oznaka', 'Jezik izdanja.', default='"hrvatski"'),
    F('broj_stranica', 'Stranica', 'integer', 'kolicina', 'Broj stranica.', validation='[value] > 0', validation_msg='Broj stranica mora biti veći od nule.'),
    F('primjeraka', 'Primjeraka', 'integer', 'kolicina', 'Koliko primjeraka knjižnica ima.', default='1', validation='[value] >= 0', validation_msg='Broj primjeraka ne može biti negativan.'),
    aktivan('Isključi kad se knjiga otpiše, da stare posudbe ostanu u evidenciji.')],
   [[1, 'Priče iz davnine', 1, '9789531234567', 2018, 'Mozaik knjiga', 'Za djecu', 'hrvatski', 176, 3, 1],
    [2, 'Zlatarovo zlato', 2, '9789531111112', 2015, 'Školska knjiga', 'Roman', 'hrvatski', 320, 2, 1],
    [3, 'Povratak Filipa Latinovicza', 3, '9789533332222', 2010, 'Mozaik knjiga', 'Roman', 'hrvatski', 280, 1, 1],
    [4, 'Pipi Duga Čarapa', 4, '9789531445566', 2019, 'Mozaik knjiga', 'Za djecu', 'hrvatski', 160, 2, 1]]),
  T('clan', 'Članovi', 'Osobe koje posuđuju knjige.', [
    PK('Broj članske iskaznice.'), ime(), prezime(), email(), telefon(), adresa(),
    F('datum_uclanjenja', 'Član od', 'date', 'datum', 'Kada je osoba postala član.', default='Date()'),
    F('clanarina_do', 'Članarina do', 'date', 'datum', 'Do kada je članarina plaćena.'),
    aktivan()],
   [[1, 'Ana', 'Kovač', 'ana.kovac@mail.hr', '091 111 2222', 'Vukovarska 5, Zagreb', '2025-09-01', '2026-08-31', 1],
    [2, 'Petar', 'Marić', 'petar.maric@mail.hr', '098 333 4444', 'Ulica kralja Zvonimira 9, Zagreb', '2024-02-15', '2026-02-14', 1],
    [3, 'Lucija', 'Babić', None, '095 555 6666', 'Savska 20, Zagreb', '2026-01-10', '2026-12-31', 1]]),
  T('posudba', 'Posudbe', 'Tko je posudio koju knjigu, do kada je mora vratiti i kada ju je vratio.', [
    PK('Šifra posudbe.'),
    REF('knjiga_id', 'Knjiga', 'knjiga.sifra', 'Posuđena knjiga.', required=True),
    REF('clan_id', 'Član', 'clan.sifra', 'Tko je posudio.', required=True),
    F('datum_posudbe', 'Posuđeno', 'date', 'datum', 'Dan posudbe.', default='Date()'),
    F('rok_vracanja', 'Rok vraćanja', 'date', 'datum', 'Do kada treba vratiti.'),
    F('datum_vracanja', 'Vraćeno', 'date', 'datum', 'Dan stvarnog vraćanja; prazno dok je još posuđeno.'),
    F('status_posudbe', 'Status', 'text', 'status', 'Je li knjiga vraćena, još posuđena ili kasni.', choices='Posuđeno,Vraćeno,Kasni', default='"Posuđeno"'),
    F('zakasnina', 'Zakasnina', 'currency', 'iznos', 'Naplaćena zakasnina u eurima.', decimals=2, default='0', validation='[value] >= 0', validation_msg='Zakasnina ne može biti negativna.')],
   [[1, 1, 1, '2026-02-02', '2026-02-23', '2026-02-20', 'Vraćeno', 0],
    [2, 2, 2, '2026-02-10', '2026-03-03', None, 'Kasni', 0],
    [3, 4, 3, '2026-03-05', '2026-03-26', None, 'Posuđeno', 0],
    [4, 3, 1, '2026-01-12', '2026-02-02', '2026-02-12', 'Vraćeno', 1.0]],
   report=('status_posudbe', 'datum_posudbe')),
 ]}
write(knjiznica)
print('napisano')
