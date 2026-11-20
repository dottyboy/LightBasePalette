import sys, os, json, glob
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mkcatalog4 import *   # helperi + prethodne domene (zapisuje ih ponovno, isti sadrzaj)

def vrijeme(name, cap, descr, **kw):
    return F(name, cap, 'time', 'vrijeme', descr, **kw)

# ---------------------------------------------------------------- udruga
D('udruga', 'Udruga: članovi i članarine',
  'Mala udruga ili klub: popis članova, članarine po godinama, sastanci i prisutnost.',
  'zajednica,udruga,clanstvo', [
  T('clan_udruge', 'Članovi', 'Osobe koje su članovi udruge.', [
    PK('Šifra člana.'), ime(), prezime(), oib(), email(), telefon(),
    dt('datum_uclanjenja', 'Učlanjen', 'Kada je osoba postala član.', default='Date()'),
    kategorija_x('status_clanstva', 'Status', 'Aktivan,Pasivan,Istupio', 'Je li član aktivan; istupili članovi ostaju radi povijesti.', 'Aktivan'),
    kategorija_x('vrsta_clana', 'Vrsta člana', 'Redovni,Počasni,Mladi,Umirovljenik', 'Vrsta članstva; može određivati iznos članarine.', 'Redovni')],
   [[1, 'Ana', 'Kovač', '12345678903', 'ana.kovac@mail.hr', '091 111 2233', '2022-01-15', 'Aktivan', 'Redovni'],
    [2, 'Marko', 'Perić', '98765432109', 'marko.peric@mail.hr', '098 333 4455', '2023-03-10', 'Aktivan', 'Mladi'],
    [3, 'Ivo', 'Babić', '45678912305', None, '095 555 6677', '2019-09-01', 'Pasivan', 'Počasni']]),
  T('clanarina_udruge', 'Članarine', 'Uplaćene članarine po godinama.', [
    PK('Šifra uplate.'), REF('clan_id', 'Član', 'clan_udruge.sifra', 'Član koji je platio.', required=True, on_delete='cascade'),
    godina(), iznos('Uplaćeni iznos članarine.'), datum('Datum uplate.'),
    kategorija_x('nacin_placanja', 'Način plaćanja', 'Gotovina,Uplatnica,Kartica', 'Kako je članarina plaćena.', 'Uplatnica')],
   [[1, 1, 2026, 20, '2026-01-20', 'Uplatnica'], [2, 2, 2026, 10, '2026-02-05', 'Gotovina'], [3, 1, 2025, 20, '2025-01-18', 'Uplatnica']],
   report=('godina', 'datum')),
  T('sastanak', 'Sastanci', 'Skupštine i sastanci udruge sa zaključcima.', [
    PK('Šifra sastanka.'), datum('Datum sastanka.'), naziv('Naziv sastanka (npr. Redovna skupština).'),
    txt('mjesto_sastanka', 'Mjesto', 'adresa', 'Gdje je sastanak održan.'), opis('Dnevni red i zaključci.')],
   [[1, '2026-02-12', 'Redovna skupština', 'Dom kulture', 'Izvješće o radu i financijsko izvješće.'], [2, '2026-04-20', 'Sastanak odbora', 'Online', 'Priprema ljetnog izleta.']]),
  T('prisutnost', 'Prisutnost', 'Tko je bio na kojem sastanku.', [
    PK('Šifra zapisa.'), REF('sastanak_id', 'Sastanak', 'sastanak.sifra', 'Sastanak.', required=True, on_delete='cascade'),
    REF('clan_id', 'Član', 'clan_udruge.sifra', 'Član.', required=True, on_delete='cascade'),
    flag('prisutan', 'Prisutan', 'Označi ako je član bio na sastanku.', default='True')],
   [[1, 1, 1, 1], [2, 1, 2, 1], [3, 1, 3, 0], [4, 2, 1, 1]]),
])

# ---------------------------------------------------------------- stambena_zgrada
D('stambena_zgrada', 'Stambena zgrada: stanovi i pričuva',
  'Upravljanje zgradom: stanovi i suvlasnički udjeli, mjesečna pričuva, uplate i prijavljeni kvarovi.',
  'dom,zgrada,pricuva', [
  T('stan', 'Stanovi', 'Posebni dijelovi zgrade i njihovi vlasnici.', [
    PK('Šifra stana.'), txt('broj_stana', 'Broj stana', 'identifikator', 'Oznaka stana na vratima ili u zemljišnoj knjizi.', required=True, width=90),
    whole('kat', 'Kat', 'kolicina', 'Kat na kojem je stan (0 = prizemlje).'),
    dec('povrsina', 'Površina (m²)', 'kolicina', 'Neto korisna površina stana.', decimals=2, **gtz('Površina mora biti veća od nule.')),
    txt('vlasnik', 'Vlasnik', 'naziv', 'Ime i prezime vlasnika, ili naziv tvrtke.', required=True), email(), telefon(),
    cur('mjesecna_pricuva', 'Mjesečna pričuva', 'iznos', 'Iznos pričuve koji se plaća svaki mjesec.', **pos('Iznos ne može biti negativan.'))],
   [[1, '1', 0, 54.5, 'Ivana Marić', 'ivana.maric@mail.hr', '091 100 2000', 38.15], [2, '2', 1, 62, 'Petar Jurić', None, '098 200 3000', 43.4],
    [3, '3', 1, 48.3, 'Tomić d.o.o.', 'info@tomic.hr', '01 400 5000', 33.81]]),
  T('uplata_pricuve', 'Uplate pričuve', 'Što je koji stan uplatio i za koji mjesec.', [
    PK('Šifra uplate.'), REF('stan_id', 'Stan', 'stan.sifra', 'Stan koji je uplatio.', required=True), godina(), mjesec(),
    iznos('Uplaćeni iznos.'), datum('Datum uplate.')],
   [[1, 1, 2026, 1, 38.15, '2026-01-05'], [2, 2, 2026, 1, 43.4, '2026-01-07'], [3, 1, 2026, 2, 38.15, '2026-02-04']],
   report=('mjesec', 'datum')),
  T('kvar', 'Kvarovi i radovi', 'Prijavljeni kvarovi na zajedničkim dijelovima i njihovo rješavanje.', [
    PK('Šifra prijave.'), datum('Datum prijave.'), REF('stan_id', 'Prijavio stan', 'stan.sifra', 'Stan iz kojeg je kvar prijavljen.'),
    opis('Što je pokvareno i gdje.'), kategorija_x('status_kvara', 'Status', 'Prijavljen,U radu,Riješen', 'Stanje rješavanja.', 'Prijavljen'),
    cur('trosak_popravka', 'Trošak', 'iznos', 'Trošak popravka kad je poznat.', **pos('Trošak ne može biti negativan.'))],
   [[1, '2026-02-10', 2, 'Ne radi svjetlo na stubištu, 1. kat', 'Riješen', 35], [2, '2026-03-01', 3, 'Curi oluk na sjevernoj strani', 'U radu', 0]]),
])

# ---------------------------------------------------------------- veterina
D('veterina', 'Veterinarska ambulanta',
  'Vlasnici i ljubimci, pregledi s dijagnozom i terapijom te cijepljenja s podsjetnikom.',
  'zdravlje,ljubimci,ambulanta', [
  T('vlasnik_ljubimca', 'Vlasnici', 'Osobe čiji su ljubimci u ambulanti.', [
    PK('Šifra vlasnika.'), ime(), prezime(), telefon(), email(), adresa(), mjesto()],
   [[1, 'Luka', 'Novak', '091 777 8888', 'luka.novak@mail.hr', 'Savska 10', 'Zagreb'], [2, 'Maja', 'Vuković', '098 123 4567', None, 'Vukovarska 3', 'Zagreb']]),
  T('ljubimac', 'Ljubimci', 'Životinje koje se liječe.', [
    PK('Šifra ljubimca.'), REF('vlasnik_id', 'Vlasnik', 'vlasnik_ljubimca.sifra', 'Vlasnik životinje.', required=True),
    naziv('Ime ljubimca.'), kategorija_x('vrsta_zivotinje', 'Vrsta', 'Pas,Mačka,Ptica,Glodavac,Gmaz,Drugo', 'Vrsta životinje.', 'Pas'),
    txt('pasmina', 'Pasmina', 'kategorija', 'Pasmina ili opis (npr. križanac).'), datum_rodjenja(),
    txt('cip', 'Broj čipa', 'identifikator', 'Broj mikročipa, 15 znamenki.', width=150), aktivan()],
   [[1, 1, 'Rex', 'Pas', 'Njemački ovčar', '2019-05-02', '191000123456789', 1], [2, 1, 'Mica', 'Mačka', 'Domaća', '2021-08-15', None, 1], [3, 2, 'Bubi', 'Glodavac', 'Zlatni hrčak', '2025-10-01', None, 1]]),
  T('veterinarski_pregled', 'Pregledi', 'Posjeti ambulanti s dijagnozom i terapijom.', [
    PK('Šifra pregleda.'), REF('ljubimac_id', 'Ljubimac', 'ljubimac.sifra', 'Životinja na pregledu.', required=True, on_delete='cascade'),
    datum('Datum pregleda.'), txt('dijagnoza', 'Dijagnoza', 'opis', 'Utvrđena dijagnoza.', width=200), opis('Terapija i upute vlasniku.'),
    cur('cijena_pregleda', 'Cijena', 'cijena', 'Naplaćeni iznos.', **pos('Cijena ne može biti negativna.'))],
   [[1, 1, '2026-01-10', 'Upala uha', 'Kapi 7 dana, kontrola.', 35], [2, 2, '2026-02-03', 'Kontrola', 'Bez nalaza.', 20]]),
  T('cijepljenje', 'Cijepljenja', 'Cjepiva i datum sljedećeg cijepljenja.', [
    PK('Šifra cijepljenja.'), REF('ljubimac_id', 'Ljubimac', 'ljubimac.sifra', 'Životinja.', required=True, on_delete='cascade'),
    txt('cjepivo', 'Cjepivo', 'naziv', 'Naziv cjepiva (npr. bjesnoća).', required=True), datum('Datum cijepljenja.'),
    dt('sljedece_cijepljenje', 'Sljedeće', 'Kada je potrebno ponovno cijepiti.')],
   [[1, 1, 'Bjesnoća', '2025-05-10', '2026-05-10'], [2, 2, 'Trovalentno', '2025-09-01', '2026-09-01']]),
])

# ---------------------------------------------------------------- salon
D('salon', 'Frizerski ili kozmetički salon',
  'Cjenik usluga, klijenti i raspored termina s ukupnim prometom.',
  'usluge,salon,termini', [
  T('usluga_salona', 'Usluge', 'Što salon nudi, koliko traje i košta.', [
    PK('Šifra usluge.'), naziv('Naziv usluge.'),
    whole('trajanje_min', 'Trajanje (min)', 'kolicina', 'Koliko usluga traje u minutama.', default='30', **gtz('Trajanje mora biti veće od nule.')),
    cur('cijena_usluge', 'Cijena', 'cijena', 'Cijena usluge.', **pos('Cijena ne može biti negativna.')), aktivan()],
   [[1, 'Žensko šišanje', 45, 25, 1], [2, 'Muško šišanje', 30, 12, 1], [3, 'Bojanje kose', 90, 45, 1], [4, 'Manikura', 60, 20, 1]]),
  T('klijent_salona', 'Klijenti', 'Redoviti klijenti.', [
    PK('Šifra klijenta.'), ime(), prezime(), telefon(), email(), napomena('Alergije, preferencije, omiljeni frizer.')],
   [[1, 'Lana', 'Radić', '091 555 1212', 'lana.radic@mail.hr', 'Alergija na amonijak.'], [2, 'Ivan', 'Šarić', '098 777 3434', None, None]]),
  T('termin_salona', 'Termini', 'Rezervirani i odrađeni termini.', [
    PK('Šifra termina.'), REF('klijent_id', 'Klijent', 'klijent_salona.sifra', 'Klijent.', required=True),
    REF('usluga_id', 'Usluga', 'usluga_salona.sifra', 'Rezervirana usluga.', required=True), datum('Datum termina.'),
    vrijeme('sat_termina', 'Vrijeme', 'Sat početka termina.'),
    txt('status_termina', 'Status', 'status', 'Stanje termina.', **ch('Rezerviran,Odrađen,Otkazan,Nije došao', 'Rezerviran'))],
   [[1, 1, 3, '2026-03-12', '10:00', 'Odrađen'], [2, 2, 2, '2026-03-12', '11:30', 'Odrađen'], [3, 1, 4, '2026-03-20', '16:00', 'Rezerviran']],
   report=('status_termina', 'datum')),
])

# ---------------------------------------------------------------- nekretnine
D('nekretnine', 'Agencija za nekretnine',
  'Ponuda nekretnina, zainteresirani kupci i zakazana razgledavanja.',
  'posao,nekretnine,prodaja', [
  T('ponuda_nekretnina', 'Nekretnine u ponudi', 'Stanovi, kuće i poslovni prostori u ponudi.', [
    PK('Šifra nekretnine.'), naziv('Kratki naslov oglasa.'),
    kategorija_x('vrsta_nekretnine', 'Vrsta', 'Stan,Kuća,Zemljište,Poslovni prostor', 'Vrsta nekretnine.', 'Stan'),
    adresa(), mjesto(), dec('povrsina', 'Površina (m²)', 'kolicina', 'Površina nekretnine.', decimals=2, **gtz('Površina mora biti veća od nule.')),
    whole('broj_soba', 'Broj soba', 'kolicina', 'Broj soba (bez kuhinje i kupaonice).', **pos('Broj soba ne može biti negativan.')),
    cur('trazena_cijena', 'Tražena cijena', 'cijena', 'Cijena iz oglasa.', **pos('Cijena ne može biti negativna.')),
    kategorija_x('status_ponude', 'Status', 'Na prodaju,Rezervirano,Prodano,Iznajmljeno', 'Stanje ponude.', 'Na prodaju')],
   [[1, 'Trosoban stan, Trešnjevka', 'Stan', 'Tratinska 20', 'Zagreb', 68, 3, 165000, 'Na prodaju'],
    [2, 'Kuća s vrtom', 'Kuća', 'Lipa 4', 'Samobor', 140, 5, 289000, 'Rezervirano'],
    [3, 'Ured u centru', 'Poslovni prostor', 'Gundulićeva 8', 'Zagreb', 45, 2, 98000, 'Prodano']]),
  T('zainteresirani', 'Zainteresirani kupci', 'Osobe koje traže nekretninu.', [
    PK('Šifra zainteresiranog.'), ime(), prezime(), telefon(), email(),
    cur('budzet', 'Budžet', 'iznos', 'Koliko kupac može potrošiti.', **pos('Budžet ne može biti negativan.'))],
   [[1, 'Davor', 'Lukić', '091 321 6540', 'davor.lukic@mail.hr', 180000], [2, 'Sanja', 'Bašić', '098 654 0321', None, 300000]]),
  T('razgledavanje', 'Razgledavanja', 'Dogovorena razgledavanja nekretnina.', [
    PK('Šifra razgledavanja.'), REF('nekretnina_id', 'Nekretnina', 'ponuda_nekretnina.sifra', 'Nekretnina koja se razgledava.', required=True),
    REF('zainteresirani_id', 'Kupac', 'zainteresirani.sifra', 'Tko razgleda.', required=True), datum('Datum razgledavanja.'),
    napomena('Dojam kupca, dogovorene daljnje korake.')],
   [[1, 1, 1, '2026-03-05', 'Sviđa mu se, traži sniženje.'], [2, 2, 2, '2026-03-06', 'Dolazi ponovno s obitelji.']]),
])

# ---------------------------------------------------------------- opg
D('opg', 'OPG: parcele, radovi i prinos',
  'Poljoprivredno gospodarstvo: parcele s kulturama, evidencija radova i troškova te prinos po godinama.',
  'poljoprivreda,opg,hrvatska', [
  T('parcela', 'Parcele', 'Katastarske čestice koje se obrađuju.', [
    PK('Šifra parcele.'), naziv('Naziv parcele (npr. Livada iza kuće).'),
    txt('katastarska_cestica', 'Katastarska čestica', 'identifikator', 'Broj katastarske čestice i općina.', width=150),
    dec('povrsina_ha', 'Površina (ha)', 'kolicina', 'Površina u hektarima.', decimals=2, **gtz('Površina mora biti veća od nule.')),
    txt('kultura', 'Kultura', 'kategorija', 'Što se trenutno uzgaja (pšenica, kukuruz, vinova loza...).')],
   [[1, 'Njiva uz put', '1234/5, k.o. Sesvete', 2.5, 'Pšenica'], [2, 'Vinograd', '987/1, k.o. Plešivica', 0.8, 'Vinova loza'], [3, 'Livada', '55/2, k.o. Sesvete', 1.2, 'Sijeno']]),
  T('rad_na_parceli', 'Radovi', 'Obavljeni radovi s materijalom i troškom.', [
    PK('Šifra rada.'), REF('parcela_id', 'Parcela', 'parcela.sifra', 'Parcela na kojoj je rad obavljen.', required=True, on_delete='cascade'), datum('Datum rada.'),
    kategorija_x('vrsta_rada', 'Vrsta rada', 'Oranje,Sjetva,Gnojidba,Zaštita,Košnja,Berba,Rezidba,Drugo', 'Koji je rad obavljen.', 'Oranje'),
    txt('materijal', 'Materijal', 'opis', 'Sjeme, gnojivo ili sredstvo koje je korišteno.'),
    cur('trosak_rada', 'Trošak', 'iznos', 'Trošak rada i materijala.', **pos('Trošak ne može biti negativan.'))],
   [[1, 1, '2025-10-12', 'Sjetva', 'Pšenica sorta Srpanjka, 250 kg', 180], [2, 2, '2026-03-05', 'Rezidba', None, 0], [3, 2, '2026-05-20', 'Zaštita', 'Bakar, 2 kg', 35]],
   report=('vrsta_rada', 'datum')),
  T('prinos', 'Prinos', 'Koliko je ubrano i po kojoj cijeni prodano.', [
    PK('Šifra prinosa.'), REF('parcela_id', 'Parcela', 'parcela.sifra', 'Parcela.', required=True, on_delete='cascade'), godina(),
    dec('kolicina_kg', 'Količina (kg)', 'kolicina', 'Ukupno ubrano u kilogramima.', decimals=0, **pos('Količina ne može biti negativna.')),
    cur('cijena_po_kg', 'Cijena po kg', 'cijena', 'Prodajna cijena po kilogramu.', **pos('Cijena ne može biti negativna.'))],
   [[1, 1, 2025, 11500, 0.22], [2, 2, 2025, 3200, 1.1]]),
])

# ---------------------------------------------------------------- turnir
D('turnir', 'Turnir ili liga',
  'Mala liga ili turnir: timovi, utakmice s rezultatima i izvješće po kolima (tablicu bodova dobiješ upitom).',
  'sport,liga,natjecanje', [
  T('tim', 'Timovi', 'Ekipe koje sudjeluju.', [
    PK('Šifra tima.'), naziv('Naziv tima.'), txt('grad', 'Grad', 'adresa', 'Iz kojeg je mjesta tim.'), txt('trener', 'Trener', 'naziv', 'Ime trenera ili voditelja.')],
   [[1, 'Dinamo mladi', 'Zagreb', 'Pero Perić'], [2, 'Rudar', 'Labin', 'Ivo Ivić'], [3, 'Zagorac', 'Krapina', 'Ana Anić'], [4, 'Primorac', 'Rijeka', 'Luka Lukić']]),
  T('utakmica', 'Utakmice', 'Odigrane i najavljene utakmice.', [
    PK('Šifra utakmice.'), whole('kolo', 'Kolo', 'redoslijed', 'Redni broj kola.', required=True, **gtz('Kolo mora biti veće od nule.')), datum('Datum utakmice.'),
    REF('domaci_id', 'Domaćin', 'tim.sifra', 'Tim domaćin.', required=True), REF('gost_id', 'Gost', 'tim.sifra', 'Gostujući tim.', required=True),
    whole('golovi_domaci', 'Golovi domaćin', 'rezultat', 'Golovi domaćina; prazno dok se ne odigra.', **pos('Golovi ne mogu biti negativni.')),
    whole('golovi_gost', 'Golovi gost', 'rezultat', 'Golovi gosta; prazno dok se ne odigra.', **pos('Golovi ne mogu biti negativni.'))],
   [[1, 1, '2026-03-07', 1, 2, 3, 1], [2, 1, '2026-03-07', 3, 4, 0, 0], [3, 2, '2026-03-14', 2, 3, 2, 2], [4, 2, '2026-03-14', 4, 1, None, None]],
   report=('kolo', 'datum')),
])

# ---------------------------------------------------------------- zdravlje_dnevnik
D('zdravlje_dnevnik', 'Dnevnik zdravlja',
  'Osobni dnevnik: težina, tlak i puls te popis lijekova i evidencija uzimanja. Ne zamjenjuje liječnika.',
  'zdravlje,dnevnik,osobno', [
  T('mjerenje', 'Mjerenja', 'Težina, krvni tlak i puls kroz vrijeme.', [
    PK('Šifra mjerenja.'), datum('Datum mjerenja.'), vrijeme('vrijeme_mjerenja', 'Vrijeme', 'Sat mjerenja.'),
    dec('tezina_kg', 'Težina (kg)', 'kolicina', 'Tjelesna težina.', decimals=1, **gtz('Težina mora biti veća od nule.')),
    whole('tlak_gornji', 'Gornji tlak', 'rezultat', 'Sistolički tlak (mmHg).', **gtz('Tlak mora biti veći od nule.')),
    whole('tlak_donji', 'Donji tlak', 'rezultat', 'Dijastolički tlak (mmHg).', **gtz('Tlak mora biti veći od nule.')),
    whole('puls', 'Puls', 'rezultat', 'Otkucaji u minuti.', **gtz('Puls mora biti veći od nule.')), napomena('Kako ste se osjećali, što je prethodilo mjerenju.')],
   [[1, '2026-03-01', '08:00', 82.4, 128, 82, 68, None], [2, '2026-03-08', '08:10', 81.9, 125, 80, 66, 'Nakon šetnje'], [3, '2026-03-15', '07:50', 81.5, 131, 85, 72, None]],
   report=('datum', 'datum')),
  T('lijek_dnevnik', 'Lijekovi', 'Lijekovi i dodaci koje uzimate.', [
    PK('Šifra lijeka.'), naziv('Naziv lijeka ili dodatka.'), txt('doza', 'Doza', 'mjera', 'Količina po uzimanju (npr. 1 tableta, 10 ml).'),
    txt('ucestalost', 'Učestalost', 'opis', 'Koliko često (npr. ujutro i navečer).'), aktivan()],
   [[1, 'Vitamin D', '1 kapsula', 'Ujutro', 1], [2, 'Lijek za tlak', '1 tableta', 'Ujutro', 1]]),
  T('uzimanje_lijeka', 'Uzimanje lijekova', 'Evidencija je li lijek uzet.', [
    PK('Šifra zapisa.'), REF('lijek_id', 'Lijek', 'lijek_dnevnik.sifra', 'Lijek.', required=True, on_delete='cascade'), datum('Datum uzimanja.'),
    flag('uzeto', 'Uzeto', 'Označi kad je lijek uzet.', default='True')],
   [[1, 1, '2026-03-01', 1], [2, 2, '2026-03-01', 1], [3, 2, '2026-03-02', 0]]),
])

# ponovna provjera dosljednosti nakon novih domena
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
print('UKUPNO5', len(glob.glob(OUT + '/*.json')), 'domena,', len(tables), 'tablica,', len(seen), 'koncepata')
