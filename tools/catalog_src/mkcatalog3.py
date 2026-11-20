import sys, os, json, glob
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mkcatalog2 import *   # helperi + prethodne domene (zapisuje ih ponovno, isti sadrzaj)

# zajednicka polja (jedna definicija = isti koncept)
def jedinica_mjere():
    return txt('jedinica_mjere', 'Jedinica', 'mjera', 'Jedinica u kojoj se roba vodi na zalihi.', **ch('kom,kg,l,m,pak,pal', 'kom'))
def nabavna_cijena():
    return cur('nabavna_cijena', 'Nabavna cijena', 'cijena', 'Zadnja nabavna cijena po jedinici.', **pos('Cijena ne može biti negativna.'))
def marka():
    return txt('marka', 'Marka', 'kategorija', 'Proizvođač.')
def model():
    return txt('model', 'Model', 'naziv', 'Naziv modela.')
def serijski():
    return txt('serijski_broj', 'Serijski broj', 'identifikator', 'Broj s naljepnice uređaja; potreban za jamstvo i servis.')
def godina_izdanja():
    return F('godina_izdanja', 'Godina izdanja', 'integer', 'datum', 'Godina izdanja ovog primjerka.', validation='[value] >= 1400 And [value] <= 2100', validation_msg='Unesi ispravnu godinu.')
def datum_kupnje():
    return F('datum_kupnje', 'Kupljeno', 'date', 'datum', 'Kada je kupljena.', default='Date()')
def sljedeci_servis():
    return dt('sljedeci_servis', 'Sljedeći servis', 'Kada treba ponovno na servis.')
def mjesto_pohrane():
    return txt('mjesto_pohrane', 'Mjesto pohrane', 'opis', 'Gdje se predmet drži (ormar, polica, kutija).')
def procijenjena_vrijednost():
    return cur('procijenjena_vrijednost', 'Procijenjena vrijednost', 'iznos', 'Trenutna procjena vrijednosti.', **pos('Vrijednost ne može biti negativna.'))
def razdoblje_naplate():
    return txt('razdoblje_naplate', 'Naplata', 'kategorija', 'Koliko se često naplaćuje.', **ch('Mjesečno,Tromjesečno,Godišnje', 'Mjesečno'))
def servisna_radionica():
    return txt('servisna_radionica', 'Radionica', 'naziv', 'Gdje je servis obavljen.')
def broj():
    return F('broj', 'Broj', 'text', 'identifikator', 'Službeni broj dokumenta u obliku godina-redni broj (npr. 2026-0001).', required=True, width=110)
def kategorija_x(name, cap, opts, descr, default):
    return txt(name, cap, 'kategorija', descr, **ch(opts, default))
def web():
    return txt('web', 'Web', 'kontakt', 'Adresa web stranice.', width=180)
def valuta():
    return txt('valuta', 'Valuta', 'oznaka', 'Oznaka valute (npr. EUR).', default='"EUR"')

D('kolekcije', 'Zbirke i kolekcije',
  'Osobne zbirke (marke, novčići, vinili, igračke): što se posjeduje, u kakvom stanju, koliko vrijedi i što je razmijenjeno.',
  'osobno,hobi,zbirke', [
  T('zbirka', 'Zbirke', 'Skupine predmeta koje se skupljaju.', [
    PK('Šifra zbirke.'), naziv('Naziv zbirke.'), kategorija_x('vrsta_zbirke', 'Vrsta', 'Marke,Novčići,Vinili,Igračke,Umjetnine,Ostalo', 'Što se skuplja.', 'Ostalo'), opis('O čemu je zbirka.')],
   [[1, 'Hrvatske marke', 'Marke', 'Marke od 1991.'], [2, 'Jugoslavenski novčići', 'Novčići', None], [3, 'Vinili 70-ih', 'Vinili', 'Rock i pop albumi']]),
  T('predmet_zbirke', 'Predmeti', 'Pojedini predmeti u zbirci s godinom, stanjem i vrijednošću.', [
    PK('Šifra predmeta.'), REF('zbirka_id', 'Zbirka', 'zbirka.sifra', 'U kojoj je zbirci.', required=True), naziv('Naziv predmeta.'), godina_izdanja(),
    kategorija_x('stanje', 'Stanje', 'Odlično,Dobro,Zadovoljavajuće,Oštećeno', 'Očuvanost predmeta.', 'Dobro'),
    nabavna_cijena(), procijenjena_vrijednost(), datum_kupnje(), txt('izvor_nabave', 'Izvor', 'opis', 'Odakle potječe (buvljak, aukcija, poklon).'), mjesto_pohrane(), napomena()],
   [[1, 1, 'Dan državnosti 1992.', 1992, 'Odlično', 0.5, 4, '2024-05-01', 'Pošta', 'Album 1', None], [2, 2, '50 dinara 1981.', 1981, 'Dobro', 1, 3, '2023-07-10', 'Buvljak', 'Kutija', None],
    [3, 3, 'Pink Floyd - The Wall', 1979, 'Dobro', 30, 60, '2025-02-14', 'Aukcija', 'Polica A', 'Dvostruki album']]),
  T('razmjena', 'Razmjene', 'Kupnje, prodaje i zamjene predmeta.', [
    PK('Šifra razmjene.'), REF('predmet_id', 'Predmet', 'predmet_zbirke.sifra', 'Što je razmijenjeno.', required=True), datum('Datum razmjene.'),
    txt('partner', 'Partner', 'naziv', 'S kim je razmjena obavljena.'), kategorija_x('vrsta_razmjene', 'Vrsta', 'Kupnja,Prodaja,Zamjena,Poklon', 'Što se dogodilo.', 'Kupnja'), iznos('Iznos razmjene.')],
   [[1, 3, '2025-02-14', 'Aukcija Zagreb', 'Kupnja', 30], [2, 2, '2025-06-01', 'Ivo (kolekcionar)', 'Zamjena', 0]]),
])

D('alati', 'Alati i oprema',
  'Popis alata i opreme: stanje, mjesto pohrane, posudbe prijateljima ili kolegama i održavanje.',
  'osobno,alati,oprema', [
  T('alat', 'Alati', 'Alati i oprema s osnovnim podacima.', [
    PK('Šifra alata.'), naziv('Naziv alata.'), marka(), model(), serijski(), datum_kupnje(), nabavna_cijena(),
    kategorija_x('stanje_alata', 'Stanje', 'Ispravan,Za servis,Neispravan,Otpisan', 'Je li alat upotrebljiv.', 'Ispravan'), mjesto_pohrane(), aktivan(), napomena()],
   [[1, 'Bušilica', 'Bosch', 'GSB 18V', 'BSH-0012345', '2023-03-12', 140, 'Ispravan', 'Garaža, polica 2', 1, None], [2, 'Kutna brusilica', 'Makita', 'GA5030', 'MKT-998877', '2022-10-01', 70, 'Ispravan', 'Garaža, polica 2', 1, None],
    [3, 'Ljestve 3 m', 'Hailo', 'L80', None, '2020-05-05', 85, 'Za servis', 'Podrum', 1, 'Labava stepenica']]),
  T('posudba_alata', 'Posudbe alata', 'Tko je posudio koji alat i do kada.', [
    PK('Šifra posudbe.'), REF('alat_id', 'Alat', 'alat.sifra', 'Posuđeni alat.', required=True), txt('posudio', 'Posudio', 'naziv', 'Tko je posudio.', required=True),
    F('datum_posudbe', 'Posuđeno', 'date', 'datum', 'Dan posudbe.', default='Date()'), F('rok_vracanja', 'Rok vraćanja', 'date', 'datum', 'Do kada treba vratiti.'),
    F('datum_vracanja', 'Vraćeno', 'date', 'datum', 'Dan stvarnog vraćanja; prazno dok je još posuđeno.'), napomena()],
   [[1, 1, 'Marko (susjed)', '2026-02-20', '2026-03-05', None, None], [2, 2, 'Ivan', '2026-01-10', '2026-01-20', '2026-01-18', None]]),
  T('odrzavanje_alata', 'Održavanje alata', 'Servisiranje, oštrenje i popravci alata.', [
    PK('Šifra zapisa.'), REF('alat_id', 'Alat', 'alat.sifra', 'Alat.', required=True), datum('Datum održavanja.'), opis('Što je napravljeno.'), iznos('Trošak održavanja.'), sljedeci_servis()],
   [[1, 3, '2026-02-01', 'Pregledana i učvršćena stepenica, čeka zamjenu.', 0, '2026-04-01'], [2, 1, '2025-11-15', 'Zamijenjene ugljene četkice.', 12, None]]),
])

D('putni_troskovi', 'Putni troškovi',
  'Službena putovanja: odredište, akontacija, troškovi po vrsti i dnevnice za obračun putnog naloga.',
  'posao,putovanja,troskovi', [
  T('putovanje', 'Putovanja', 'Službena putovanja za obračun.', [
    PK('Šifra putovanja.'), naziv('Kratki naziv putovanja.'), txt('odrediste', 'Odredište', 'adresa', 'Grad ili država.'),
    F('pocetak', 'Početak', 'date', 'datum', 'Prvi dan.'), F('kraj', 'Kraj', 'date', 'datum', 'Zadnji dan.'),
    txt('svrha', 'Svrha', 'opis', 'Kratki opis (npr. Konzum, kirija ožujak).', width=220),
    kategorija_x('status_putovanja', 'Status', 'Planirano,U tijeku,Završeno,Obračunano', 'Stanje obračuna.', 'Planirano'),
    cur('akontacija', 'Akontacija', 'iznos', 'Unaprijed isplaćen iznos.', **pos('Akontacija ne može biti negativna.'))],
   [[1, 'Sajam u Münchenu', 'München, Njemačka', '2026-04-20', '2026-04-23', 'Sajam opreme', 'Planirano', 400], [2, 'Sastanak u Splitu', 'Split', '2026-02-10', '2026-02-11', 'Sastanak s klijentom', 'Obračunano', 100]]),
  T('trosak_putovanja', 'Troškovi putovanja', 'Pojedinačni troškovi s računima.', [
    PK('Šifra troška.'), REF('putovanje_id', 'Putovanje', 'putovanje.sifra', 'Putovanje.', required=True, on_delete='cascade'), datum('Datum troška.'),
    kategorija_x('vrsta_putnog_troska', 'Vrsta', 'Prijevoz,Smještaj,Prehrana,Gorivo,Cestarina,Parking,Ostalo', 'Što je plaćeno.', 'Prijevoz'), iznos('Iznos troška.'), valuta(),
    txt('nacin_placanja', 'Način plaćanja', 'kategorija', 'Kako kupac plaća.', **ch('Virman,Gotovina,Kartica,Pouzeće', 'Kartica')), txt('broj_racuna', 'Broj računa', 'identifikator', 'Broj računa za knjigovodstvo.'), napomena()],
   [[1, 2, '2026-02-10', 'Gorivo', 42, 'EUR', 'Kartica', 'R-4411', None], [2, 2, '2026-02-10', 'Cestarina', 18.6, 'EUR', 'Gotovina', None, None], [3, 2, '2026-02-11', 'Prehrana', 21, 'EUR', 'Kartica', 'R-4420', 'Ručak s klijentom'],
    [4, 1, '2026-04-15', 'Smještaj', 320, 'EUR', 'Kartica', 'HT-8812', 'Rezervirano unaprijed']]),
  T('dnevnica', 'Dnevnice', 'Dnevnice za dane provedene na putu.', [
    PK('Šifra dnevnice.'), REF('putovanje_id', 'Putovanje', 'putovanje.sifra', 'Putovanje.', required=True, on_delete='cascade'), datum('Dan za koji se obračunava.'),
    dec('sati', 'Sati', 'kolicina', 'Utrošeni sati (do 24).', decimals=2, required=True, validation='[value] > 0 And [value] <= 24', validation_msg='Sati su između 0 i 24.'), iznos('Iznos dnevnice.')],
   [[1, 2, '2026-02-10', 12, 26.54], [2, 2, '2026-02-11', 8, 13.27]]),
])

D('servisni_nalozi', 'Servisni nalozi',
  'Servis uređaja: klijenti, uređaji s jamstvom, nalozi s kvarom i dijagnozom te ugrađeni dijelovi.',
  'posao,servis,popravci', [
  T('klijent_servisa', 'Klijenti', 'Osobe i tvrtke koje donose uređaje na servis.', [
    PK('Šifra klijenta.'), naziv('Ime i prezime ili naziv tvrtke.'), telefon(), email(), adresa(), mjesto()],
   [[1, 'Marija Horvat', '091 222 3344', 'marija.horvat@mail.hr', 'Trg bana Jelačića 3', 'Zagreb'], [2, 'Adria promet d.d.', '021 330 440', 'servis@adria-promet.hr', 'Riva 7', 'Split']]),
  T('uredjaj', 'Uređaji', 'Uređaji klijenata s podacima za jamstvo.', [
    PK('Šifra uređaja.'), REF('klijent_id', 'Klijent', 'klijent_servisa.sifra', 'Vlasnik.', required=True),
    kategorija_x('vrsta_uredjaja', 'Vrsta', 'Računalo,Printer,Mobitel,Perilica,Klima,Ostalo', 'Vrsta uređaja.', 'Računalo'), marka(), model(), serijski(), dt('jamstvo_do', 'Jamstvo do', 'Do kada vrijedi jamstvo.')],
   [[1, 1, 'Računalo', 'Lenovo', 'ThinkPad T14', 'PF2X1234', '2026-12-31'], [2, 2, 'Printer', 'HP', 'LaserJet M404', 'VNB8K12345', '2025-06-30'], [3, 1, 'Mobitel', 'Samsung', 'Galaxy A54', 'RZ8T123ABC', '2026-05-15']]),
  T('servisni_nalog', 'Servisni nalozi', 'Zaprimanje, popravak i preuzimanje uređaja.', [
    PK('Šifra naloga.'), broj(), REF('uredjaj_id', 'Uređaj', 'uredjaj.sifra', 'Uređaj na servisu.', required=True), datum('Datum zaprimanja.'),
    F('opis_kvara', 'Opis kvara', 'memo', 'opis', 'Što klijent prijavljuje.'), txt('dijagnoza', 'Dijagnoza', 'opis', 'Utvrđeni uzrok.'),
    kategorija_x('status_naloga', 'Status', 'Zaprimljeno,U radu,Čeka dijelove,Gotovo,Preuzeto,Odbijeno', 'Napredak popravka.', 'Zaprimljeno'),
    txt('tehnicar', 'Tehničar', 'naziv', 'Tko popravlja.'), dt('datum_zavrsetka', 'Završeno', 'Kada je popravak gotov.'),
    cur('cijena_rada', 'Cijena rada', 'cijena', 'Naplaćeni rad.', **pos('Cijena ne može biti negativna.')), cur('cijena_dijelova', 'Cijena dijelova', 'cijena', 'Naplaćeni dijelovi.', **pos('Cijena ne može biti negativna.')),
    cur('ukupno', 'Ukupno', 'iznos', 'Iznos za platiti (osnovica + PDV).')],
   [[1, '2026-0001', 1, '2026-02-03', 'Ne uključuje se, nema slike.', 'Pokvaren ekran', 'Preuzeto', 'Tomo', '2026-02-10', 45, 120, 165], [2, '2026-0002', 2, '2026-02-18', 'Zaglavljuje papir.', 'Istrošeni valjci', 'Čeka dijelove', 'Tomo', None, 0, 0, 0],
    [3, '2026-0003', 3, '2026-03-05', 'Baterija se brzo prazni.', None, 'U radu', 'Luka', None, 0, 0, 0]],
   report=('status_naloga', 'datum')),
  T('ugradjeni_dio', 'Ugrađeni dijelovi', 'Dijelovi ugrađeni po nalogu.', [
    PK('Šifra dijela.'), REF('nalog_id', 'Nalog', 'servisni_nalog.sifra', 'Nalog.', required=True, on_delete='cascade'), naziv('Naziv dijela.'),
    dec('kolicina', 'Količina', 'kolicina', 'Količina.', decimals=2, default='1', **gtz('Količina mora biti veća od nule.')), cur('cijena', 'Cijena', 'cijena', 'Cijena po jedinici.', **pos('Cijena ne može biti negativna.'))],
   [[1, 1, 'LCD ekran 14"', 1, 120], [2, 2, 'Set valjaka', 1, 38]]),
])

D('webshop', 'Web trgovina',
  'Mala internetska trgovina: kupci, proizvodi sa zalihom, narudžbe sa statusom isporuke i stavke narudžbe.',
  'prodaja,webshop,narudzbe', [
  T('kupac_shopa', 'Kupci', 'Registrirani kupci trgovine.', [
    PK('Šifra kupca.'), ime(), prezime(), email(), telefon(), adresa(), postanski(), mjesto(), drzava(),
    dt('datum_registracije', 'Registriran', 'Kada se kupac registrirao.', default='Date()'), aktivan()],
   [[1, 'Ana', 'Kovač', 'ana.kovac@mail.hr', '091 111 2222', 'Vukovarska 5', '10000', 'Zagreb', 'Hrvatska', '2025-10-01', 1], [2, 'Tomislav', 'Šarić', 'tomislav.saric@mail.hr', '098 333 4444', 'Obala 3', '21000', 'Split', 'Hrvatska', '2025-12-12', 1]]),
  T('proizvod_shopa', 'Proizvodi', 'Artikli u ponudi trgovine.', [
    PK('Šifra proizvoda.'), F('kod', 'Kod', 'text', 'identifikator', 'Vlastita ili tvornička oznaka artikla (npr. barkod).', width=120), naziv('Naziv proizvoda.'), opis('Opis za web stranicu.'),
    F('cijena', 'Cijena', 'currency', 'cijena', 'Jedinična cijena bez PDV-a.', decimals=2, validation='[value] >= 0', validation_msg='Cijena ne može biti negativna.'),
    F('pdv_stopa', 'PDV (%)', 'decimal', 'postotak', 'Stopa PDV-a u postocima (0, 5, 13 ili 25).', decimals=0, default='25', validation='[value] In (0, 5, 13, 25)', validation_msg='Dopuštene stope PDV-a: 0, 5, 13, 25.'),
    dec('na_zalihi', 'Na zalihi', 'kolicina', 'Količina dostupna za prodaju.', decimals=0, default='0', **pos('Zaliha ne može biti negativna.')),
    F('slika', 'Slika', 'picture', 'slika', 'Fotografija proizvoda.'), aktivan('Isključi da se proizvod ne prikazuje u trgovini.')],
   [[1, 'MAJ-M', 'Majica pamučna M', 'Crna majica, 100% pamuk', 15, 25, 40, None, 1], [2, 'KAP-01', 'Kapa zimska', 'Pletena kapa', 12, 25, 25, None, 1], [3, 'CAS-01', 'Šalica s logom', 'Keramička šalica 3 dl', 6.5, 25, 80, None, 1]]),
  T('narudzba_shopa', 'Narudžbe', 'Narudžbe kupaca s plaćanjem i isporukom.', [
    PK('Šifra narudžbe.'), REF('kupac_id', 'Kupac', 'kupac_shopa.sifra', 'Tko je naručio.', required=True), datum('Datum narudžbe.'),
    kategorija_x('status_narudzbe_shopa', 'Status', 'Nova,Plaćena,Poslana,Isporučena,Vraćena,Otkazana', 'Napredak narudžbe.', 'Nova'),
    txt('nacin_placanja', 'Način plaćanja', 'kategorija', 'Kako kupac plaća.', **ch('Virman,Gotovina,Kartica,Pouzeće', 'Kartica')),
    cur('trosak_dostave', 'Dostava', 'iznos', 'Trošak dostave.', **pos('Trošak ne može biti negativan.')), cur('ukupno', 'Ukupno', 'iznos', 'Iznos za platiti (osnovica + PDV).'),
    txt('broj_za_pracenje', 'Broj za praćenje', 'identifikator', 'Broj pošiljke kod dostavne službe.'), napomena()],
   [[1, 1, '2026-03-01', 'Isporučena', 'Kartica', 3, 40.75, 'HP123456789HR', None], [2, 2, '2026-03-10', 'Poslana', 'Pouzeće', 4, 24.5, 'HP987654321HR', None], [3, 1, '2026-03-14', 'Nova', 'Kartica', 3, 9.5, None, 'Pokloni upakirati']],
   report=('status_narudzbe_shopa', 'datum')),
  T('stavka_narudzbe_shopa', 'Stavke narudžbe', 'Što je naručeno.', [
    PK('Šifra stavke.'), REF('narudzba_id', 'Narudžba', 'narudzba_shopa.sifra', 'Narudžba.', required=True, on_delete='cascade'), REF('proizvod_id', 'Proizvod', 'proizvod_shopa.sifra', 'Proizvod.', required=True),
    dec('kolicina', 'Količina', 'kolicina', 'Količina.', decimals=2, default='1', **gtz('Količina mora biti veća od nule.')), cur('cijena', 'Cijena', 'cijena', 'Cijena po jedinici.', **pos('Cijena ne može biti negativna.')), iznos('Iznos stavke.')],
   [[1, 1, 1, 2, 15, 30], [2, 1, 3, 1, 6.5, 6.5], [3, 2, 2, 2, 12, 24], [4, 3, 3, 1, 6.5, 6.5]]),
])

D('pretplate', 'Pretplate i ponavljajuća plaćanja',
  'Pregled mjesečnih i godišnjih pretplata: što se plaća, koliko, kada je sljedeća naplata i što je naplaćeno.',
  'osobno,financije,pretplate', [
  T('usluga_pretplate', 'Usluge', 'Pružatelji usluga na pretplatu.', [
    PK('Šifra usluge.'), naziv('Naziv usluge.'), txt('pruzatelj', 'Pružatelj', 'naziv', 'Tvrtka koja pruža uslugu.'),
    kategorija_x('kategorija_pretplate', 'Kategorija', 'Streaming,Softver,Mobilne usluge,Osiguranje,Teretana,Ostalo', 'Vrsta usluge.', 'Ostalo'), web()],
   [[1, 'Glazba', 'Streaming d.o.o.', 'Streaming', 'www.streaming.example'], [2, 'Mobitel', 'Telekom', 'Mobilne usluge', 'www.telekom.example'], [3, 'Teretana', 'Fit klub', 'Teretana', None]]),
  T('pretplata', 'Pretplate', 'Aktivne pretplate s iznosom i sljedećom naplatom.', [
    PK('Šifra pretplate.'), REF('usluga_id', 'Usluga', 'usluga_pretplate.sifra', 'Usluga.', required=True), iznos('Iznos po razdoblju.'), razdoblje_naplate(),
    dt('pocetak', 'Početak', 'Kada je pretplata počela.'), dt('sljedeca_naplata', 'Sljedeća naplata', 'Kada se naplaćuje sljedeći put.'),
    txt('nacin_placanja', 'Način plaćanja', 'kategorija', 'Kako kupac plaća.', **ch('Virman,Gotovina,Kartica,Pouzeće', 'Kartica')), flag('otkazano', 'Otkazano', 'Označi kad je pretplata otkazana.', default='False'), napomena()],
   [[1, 1, 9.99, 'Mjesečno', '2024-01-05', '2026-04-05', 'Kartica', 0, None], [2, 2, 25, 'Mjesečno', '2023-06-01', '2026-04-01', 'Virman', 0, 'Paket s mobitelom'], [3, 3, 320, 'Godišnje', '2025-09-01', '2026-09-01', 'Kartica', 0, None]]),
  T('naplata_pretplate', 'Naplate', 'Provedene naplate.', [
    PK('Šifra naplate.'), REF('pretplata_id', 'Pretplata', 'pretplata.sifra', 'Pretplata.', required=True), datum('Datum naplate.'), iznos('Naplaćeni iznos.')],
   [[1, 1, '2026-03-05', 9.99], [2, 2, '2026-03-01', 25], [3, 3, '2025-09-01', 320]]),
])

D('proizvodnja', 'Proizvodnja i sastavnice',
  'Mala proizvodnja: sirovine na zalihi, gotovi proizvodi, sastavnice (što ulazi u proizvod) i radni nalozi.',
  'posao,proizvodnja,zalihe', [
  T('sirovina', 'Sirovine', 'Materijali koji ulaze u proizvodnju.', [
    PK('Šifra sirovine.'), F('kod', 'Kod', 'text', 'identifikator', 'Vlastita ili tvornička oznaka artikla (npr. barkod).', width=120), naziv('Naziv sirovine.'), jedinica_mjere(), nabavna_cijena(),
    dec('trenutna_zaliha', 'Zaliha', 'kolicina', 'Količina na skladištu; zbroj svih ulaza i izlaza.', decimals=2, default='0'), aktivan()],
   [[1, 'DRV-HR', 'Hrastova daska', 'm', 18, 40, 1], [2, 'LAK-01', 'Lak za drvo', 'l', 14, 12, 1], [3, 'VIJ-50', 'Vijci 50 mm', 'kom', 0.05, 800, 1]]),
  T('gotov_proizvod', 'Gotovi proizvodi', 'Što se proizvodi i prodaje.', [
    PK('Šifra proizvoda.'), F('kod', 'Kod', 'text', 'identifikator', 'Vlastita ili tvornička oznaka artikla (npr. barkod).', width=120), naziv('Naziv proizvoda.'), opis('Opis proizvoda.'),
    cur('prodajna_cijena', 'Prodajna cijena', 'cijena', 'Cijena po kojoj se prodaje.', **pos('Cijena ne može biti negativna.')), aktivan()],
   [[1, 'STO-01', 'Stol od hrasta', 'Blagovaonski stol 160x80', 380, 1], [2, 'POL-01', 'Polica za knjige', 'Zidna polica 100 cm', 85, 1]]),
  T('sastavnica', 'Sastavnice', 'Koliko koje sirovine treba za jedan proizvod.', [
    PK('Šifra stavke.'), REF('proizvod_id', 'Proizvod', 'gotov_proizvod.sifra', 'Proizvod.', required=True, on_delete='cascade'), REF('sirovina_id', 'Sirovina', 'sirovina.sifra', 'Sirovina.', required=True),
    dec('kolicina', 'Količina', 'kolicina', 'Količina po jednom proizvodu.', decimals=3, required=True, **gtz('Količina mora biti veća od nule.')), napomena()],
   [[1, 1, 1, 5.5, None], [2, 1, 2, 0.4, 'Dva sloja'], [3, 1, 3, 24, None], [4, 2, 1, 1.2, None], [5, 2, 2, 0.1, None]]),
  T('radni_nalog', 'Radni nalozi', 'Nalozi za proizvodnju količine proizvoda.', [
    PK('Šifra naloga.'), broj(), REF('proizvod_id', 'Proizvod', 'gotov_proizvod.sifra', 'Što se proizvodi.', required=True),
    dec('kolicina', 'Količina', 'kolicina', 'Količina za proizvodnju.', decimals=2, default='1', **gtz('Količina mora biti veća od nule.')), datum('Datum izdavanja.'), dt('rok', 'Rok', 'Do kada nalog mora biti gotov.'),
    kategorija_x('status_radnog_naloga', 'Status', 'Planiran,U proizvodnji,Završen,Otkazan', 'Napredak naloga.', 'Planiran'), napomena()],
   [[1, 'RN-2026-001', 1, 4, '2026-03-01', '2026-03-20', 'U proizvodnji', None], [2, 'RN-2026-002', 2, 10, '2026-03-05', '2026-03-30', 'Planiran', 'Za kupca Kvaka']]),
])

D('vrtlarstvo', 'Vrt i biljke',
  'Kućni vrt: katalog biljaka, gredice, sadnje s datumima berbe i dnevnik radova (zalijevanje, prihrana, rezidba).',
  'osobno,vrt,biljke', [
  T('biljka', 'Biljke', 'Katalog biljaka koje se uzgajaju.', [
    PK('Šifra biljke.'), naziv('Uobičajeni naziv.'), txt('latinski_naziv', 'Latinski naziv', 'naziv', 'Znanstveni naziv.'),
    kategorija_x('vrsta_biljke', 'Vrsta', 'Povrće,Voće,Cvijeće,Začinsko bilje,Drvo,Grm', 'Skupina biljke.', 'Povrće'),
    kategorija_x('potreba_za_suncem', 'Svjetlo', 'Sunce,Polusjena,Sjena', 'Koliko svjetla traži.', 'Sunce'),
    whole('zalijevanje_dana', 'Zalijevanje svakih (dana)', 'kolicina', 'Razmak između zalijevanja.', **gtz('Razmak mora biti veći od nule.')), opis('Savjeti za uzgoj.')],
   [[1, 'Rajčica', 'Solanum lycopersicum', 'Povrće', 'Sunce', 2, 'Veže se uz štap, prihranjivati svaka 2 tjedna.'], [2, 'Bosiljak', 'Ocimum basilicum', 'Začinsko bilje', 'Sunce', 2, None], [3, 'Jagoda', 'Fragaria x ananassa', 'Voće', 'Polusjena', 3, None]]),
  T('gredica', 'Gredice', 'Mjesta za sadnju u vrtu.', [
    PK('Šifra gredice.'), naziv('Naziv ili oznaka gredice.'), dec('povrsina_m2', 'Površina (m²)', 'kolicina', 'Korisna površina.', decimals=1, **gtz('Površina mora biti veća od nule.')), txt('polozaj', 'Položaj', 'opis', 'Gdje se nalazi u vrtu.')],
   [[1, 'Gredica A', 4, 'Uz ogradu, jug'], [2, 'Gredica B', 6, 'Uz kuću, sjeverozapad'], [3, 'Plastenik', 12, 'Iza garaže']]),
  T('sadnja', 'Sadnje', 'Što je posađeno kada i kada se očekuje berba.', [
    PK('Šifra sadnje.'), REF('biljka_id', 'Biljka', 'biljka.sifra', 'Što je posađeno.', required=True), REF('gredica_id', 'Gredica', 'gredica.sifra', 'Gdje.', required=True),
    dt('datum_sadnje', 'Posađeno', 'Dan sadnje.', default='Date()'), dec('kolicina', 'Količina', 'kolicina', 'Broj sadnica.', decimals=0, default='1', **gtz('Količina mora biti veća od nule.')),
    dt('ocekivana_berba', 'Očekivana berba', 'Kada se očekuje berba.'), kategorija_x('status_sadnje', 'Status', 'Posađeno,Raste,Ubrano,Propalo', 'Stanje sadnje.', 'Posađeno'), napomena()],
   [[1, 1, 3, '2026-04-20', 8, '2026-07-15', 'Posađeno', None], [2, 2, 3, '2026-04-25', 12, '2026-06-20', 'Posađeno', None], [3, 3, 1, '2025-09-15', 20, '2026-06-01', 'Raste', 'Nova sadnica sorte Albion']]),
  T('radnja_u_vrtu', 'Dnevnik radova', 'Što je obavljeno u vrtu.', [
    PK('Šifra zapisa.'), REF('gredica_id', 'Gredica', 'gredica.sifra', 'Gdje je rađeno.', required=True), datum('Dan rada.'),
    kategorija_x('vrsta_radnje', 'Radnja', 'Zalijevanje,Prihrana,Prskanje,Okopavanje,Rezidba,Berba', 'Što je napravljeno.', 'Zalijevanje'), opis('Pojedinosti (sredstvo, količina).')],
   [[1, 3, '2026-04-21', 'Zalijevanje', None], [2, 1, '2026-03-10', 'Prihrana', 'Organsko gnojivo 50 g/m²'], [3, 1, '2026-03-12', 'Okopavanje', None]]),
])

D('kucni_inventar', 'Kućni inventar',
  'Popis imovine u kući: prostorije, predmeti s jamstvom i vrijednošću te popravci; korisno za osiguranje i selidbu.',
  'osobno,kuca,imovina', [
  T('prostorija', 'Prostorije', 'Prostori u kući ili stanu.', [PK('Šifra prostorije.'), naziv('Naziv prostorije.'), whole('kat', 'Kat', 'kolicina', 'Kat na kojem je prostor.'), opis('Opis prostorije.')],
   [[1, 'Dnevni boravak', 0, None], [2, 'Kuhinja', 0, None], [3, 'Radna soba', 1, 'Pisaći stol i računalo'], [4, 'Garaža', -1, None]]),
  T('predmet_inventara', 'Predmeti', 'Vrijedniji predmeti s jamstvom i vrijednošću.', [
    PK('Šifra predmeta.'), naziv('Naziv predmeta.'), REF('prostorija_id', 'Prostorija', 'prostorija.sifra', 'Gdje se nalazi.'),
    kategorija_x('kategorija_predmeta', 'Kategorija', 'Namještaj,Elektronika,Aparati,Odjeća,Alati,Dokumenti,Ostalo', 'Vrsta predmeta.', 'Ostalo'), marka(), model(), serijski(), datum_kupnje(), nabavna_cijena(), procijenjena_vrijednost(),
    dt('jamstvo_do', 'Jamstvo do', 'Do kada vrijedi jamstvo.'), napomena()],
   [[1, 'Televizor 55"', 1, 'Elektronika', 'Samsung', 'QE55Q60', 'SN-TV-9981', '2023-11-24', 650, 400, '2025-11-24', None], [2, 'Perilica rublja', 4, 'Aparati', 'Bosch', 'WAN28', 'SN-PR-1177', '2021-05-10', 520, 250, '2023-05-10', 'Servis 2024.'],
    [3, 'Prijenosno računalo', 3, 'Elektronika', 'Lenovo', 'ThinkPad T14', 'PF2X1234', '2025-01-15', 1200, 1000, '2027-01-15', None]]),
  T('popravak_predmeta', 'Popravci', 'Popravci i servisi predmeta.', [
    PK('Šifra popravka.'), REF('predmet_id', 'Predmet', 'predmet_inventara.sifra', 'Predmet.', required=True), datum('Datum popravka.'), opis('Što je popravljeno.'), iznos('Trošak popravka.'), servisna_radionica()],
   [[1, 2, '2024-03-18', 'Zamijenjena pumpa.', 95, 'Servis Bosch Zagreb'], [2, 1, '2025-02-02', 'Ažuriranje softvera.', 0, 'Samsung servis']]),
])

D('osiguranja', 'Osiguranja i police',
  'Evidencija osiguravajućih polica: osiguravatelji, police s premijom i rokovima, uplate premije i prijave šteta.',
  'osobno,financije,osiguranje', [
  T('osiguravatelj', 'Osiguravatelji', 'Osiguravajuća društva.', [PK('Šifra osiguravatelja.'), naziv('Naziv društva.'), txt('kontakt_osoba', 'Kontakt osoba', 'naziv', 'Zastupnik ili agent.'), telefon(), email(), web()],
   [[1, 'Sigurnost d.d.', 'Petra Marić', '01 600 7000', 'agent@sigurnost.example', 'www.sigurnost.example'], [2, 'Croatia polica', 'Ivo Jurić', '01 499 2000', 'ivo.juric@polica.example', None]]),
  T('polica', 'Police', 'Police osiguranja s trajanjem i premijom.', [
    PK('Šifra police.'), txt('broj_police', 'Broj police', 'identifikator', 'Broj s police.', required=True), REF('osiguravatelj_id', 'Osiguravatelj', 'osiguravatelj.sifra', 'Kod koga je osigurano.', required=True),
    kategorija_x('vrsta_osiguranja', 'Vrsta', 'Auto,Kuća,Život,Zdravlje,Putno,Imovina,Odgovornost', 'Što se osigurava.', 'Auto'), txt('predmet_osiguranja', 'Predmet', 'opis', 'Što je osigurano (vozilo, nekretnina, osoba).'),
    dt('pocetak', 'Početak', 'Prvi dan osiguranja.'), dt('kraj', 'Kraj', 'Zadnji dan osiguranja.'), cur('premija', 'Premija', 'iznos', 'Iznos premije po razdoblju.', **pos('Premija ne može biti negativna.')), razdoblje_naplate(),
    cur('osigurana_svota', 'Osigurana svota', 'iznos', 'Najveći iznos koji osiguravatelj isplaćuje.', **pos('Svota ne može biti negativna.')),
    kategorija_x('status_police', 'Status', 'Aktivna,Istekla,Otkazana', 'Je li polica na snazi.', 'Aktivna')],
   [[1, 'AO-2025-4411', 1, 'Auto', 'Škoda Octavia ZG1234AB', '2025-12-01', '2026-11-30', 420, 'Godišnje', 30000, 'Aktivna'], [2, 'KU-2024-0192', 2, 'Kuća', 'Obiteljska kuća, Zagreb', '2024-06-01', '2026-05-31', 25, 'Mjesečno', 150000, 'Aktivna'],
    [3, 'ZD-2023-7731', 1, 'Zdravlje', 'Dopunsko osiguranje', '2023-01-01', '2024-12-31', 9, 'Mjesečno', 0, 'Istekla']],
   report=('status_police', 'kraj')),
  T('placanje_premije', 'Plaćanje premije', 'Uplate premije po polici.', [
    PK('Šifra uplate.'), REF('polica_id', 'Polica', 'polica.sifra', 'Polica.', required=True), datum('Datum uplate.'), iznos('Uplaćena premija.'),
    txt('nacin_placanja', 'Način plaćanja', 'kategorija', 'Kako kupac plaća.', **ch('Virman,Gotovina,Kartica,Pouzeće', 'Kartica'))],
   [[1, 1, '2025-11-28', 420, 'Virman'], [2, 2, '2026-03-01', 25, 'Kartica'], [3, 2, '2026-02-01', 25, 'Kartica']]),
  T('steta', 'Štete', 'Prijavljene štete i isplate.', [
    PK('Šifra štete.'), REF('polica_id', 'Polica', 'polica.sifra', 'Polica po kojoj je prijavljeno.', required=True), datum('Datum štete.'), opis('Što se dogodilo.'),
    cur('iznos_stete', 'Procijenjena šteta', 'iznos', 'Procjena štete.', **pos('Iznos ne može biti negativan.')), cur('isplaceno', 'Isplaćeno', 'iznos', 'Iznos koji je isplatio osiguravatelj.', **pos('Iznos ne može biti negativan.')),
    kategorija_x('status_stete', 'Status', 'Prijavljena,U obradi,Isplaćena,Odbijena', 'Napredak obrade.', 'Prijavljena')],
   [[1, 1, '2026-01-14', 'Oštećen odbojnik pri parkiranju.', 650, 520, 'Isplaćena'], [2, 2, '2026-02-20', 'Oluja oštetila crijep na krovu.', 1800, 0, 'U obradi']]),
])

# konacna provjera dosljednosti
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
print('UKUPNO', len(glob.glob(OUT + '/*.json')), 'domena,', len(tables), 'tablica,', len(seen), 'koncepata')
