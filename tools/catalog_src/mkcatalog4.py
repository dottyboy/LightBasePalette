import sys, os, json, glob
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mkcatalog3 import *   # helperi i prethodne domene

NOTE = 'Primjer za učenje i polaznu točku; stope, konta i obrasce uskladi s važećim propisima i svojim računovođom.'

def broj_racuna():
    return txt('broj_racuna', 'Broj računa', 'identifikator', 'Broj računa za knjigovodstvo.')
def broj_dokumenta():
    return txt('broj_dokumenta', 'Dokument', 'identifikator', 'Broj primke, izdatnice ili računa na koji se kretanje odnosi.')
def placeno():
    return flag('placeno', 'Plaćeno', 'Označi kad je uplata evidentirana.', default='False')
def pdv_stopa():
    return F('pdv_stopa', 'PDV (%)', 'decimal', 'postotak', 'Stopa PDV-a u postocima (0, 5, 13 ili 25).', decimals=0, default='25',
             validation='[value] In (0, 5, 13, 25)', validation_msg='Dopuštene stope PDV-a: 0, 5, 13, 25.')
def osnovica():
    return F('osnovica', 'Osnovica', 'currency', 'iznos', 'Zbroj stavki bez PDV-a.', decimals=2)
def pdv_iznos():
    return F('pdv_iznos', 'PDV', 'currency', 'iznos', 'Obračunani PDV.', decimals=2)
def partner():
    return txt('partner', 'Partner', 'naziv', 'S kim je razmjena obavljena.')
def svrha():
    return txt('svrha', 'Svrha', 'opis', 'Kratki opis (npr. Konzum, kirija ožujak).', width=220)
def bruto():
    return cur('bruto', 'Bruto', 'iznos', 'Bruto plaća za mjesec.')
def pocetno_stanje():
    return F('pocetno_stanje', 'Početno stanje', 'currency', 'iznos', 'Stanje na dan početka vođenja; trenutno stanje = početno + promet.', decimals=2, default='0')

# ---------------------------------------------------------------- racunovodstvo
D('racunovodstvo', 'Računovodstvo: kontni plan i glavna knjiga',
  'Dvojno knjigovodstvo za mali subjekt: kontni plan, nalozi za knjiženje i stavke duguje/potražuje. ' + NOTE,
  'hrvatska,racunovodstvo,knjigovodstvo', [
  T('konto', 'Kontni plan', 'Konta po kojima se knjiži. Broj konta je razrada razreda 0-9 po uobičajenom hrvatskom kontnom planu.', [
    PK('Šifra konta.'), txt('broj_konta', 'Broj konta', 'identifikator', 'Brojčana oznaka konta (npr. 1200).', required=True, width=100), naziv('Naziv konta.'),
    whole('razred', 'Razred', 'oznaka', 'Prva znamenka broja konta, razred 0-9.', validation='[value] >= 0 And [value] <= 9', validation_msg='Razred je od 0 do 9.'),
    kategorija_x('vrsta_konta', 'Vrsta', 'Imovina,Obveze,Kapital,Prihod,Rashod', 'Gdje konto ulazi u bilancu ili račun dobiti i gubitka.', 'Imovina'), aktivan()],
   [[1, '1000', 'Žiro račun', 1, 'Imovina', 1], [2, '1200', 'Kupci u zemlji', 1, 'Imovina', 1], [3, '1400', 'Pretporez', 1, 'Imovina', 1],
    [4, '2200', 'Dobavljači u zemlji', 2, 'Obveze', 1], [5, '2400', 'Obveza za PDV', 2, 'Obveze', 1], [6, '4000', 'Troškovi materijala', 4, 'Rashod', 1], [7, '7600', 'Prihodi od prodaje', 7, 'Prihod', 1]]),
  T('nalog_knjizenja', 'Nalozi za knjiženje', 'Zaglavlje temeljnice: datum, vrsta i opis; zbroj duguje mora biti jednak zbroju potražuje.', [
    PK('Šifra naloga.'), broj(), datum('Datum knjiženja.'),
    kategorija_x('vrsta_naloga', 'Vrsta', 'Temeljnica,Izvod,Blagajna,Ulazni račun,Izlazni račun,Obračun plaće', 'Iz kojeg dokumenta nalog nastaje.', 'Temeljnica'),
    opis('Opis knjiženja.'), flag('knjizen', 'Proknjižen', 'Označi kad je nalog proknjižen i više se ne mijenja.', default='False')],
   [[1, '2026-N001', '2026-03-02', 'Ulazni račun', 'Račun dobavljača za materijal', 1], [2, '2026-N002', '2026-03-03', 'Izlazni račun', 'Račun 2026-0003 Adria promet', 1], [3, '2026-N003', '2026-03-10', 'Izvod', 'Uplata kupca po izvodu', 0]],
   report=('vrsta_naloga', 'datum')),
  T('stavka_knjizenja', 'Stavke knjiženja', 'Pojedinačna knjiženja na konta, na stranu duguje ili potražuje.', [
    PK('Šifra stavke.'), REF('nalog_id', 'Nalog', 'nalog_knjizenja.sifra', 'Nalog kojem stavka pripada.', required=True, on_delete='cascade'),
    REF('konto_id', 'Konto', 'konto.sifra', 'Konto na koji se knjiži.', required=True), opis('Opis stavke.'),
    cur('duguje', 'Duguje', 'iznos', 'Iznos na dugovnoj strani konta.', default='0', **pos('Iznos ne može biti negativan.')),
    cur('potrazuje', 'Potražuje', 'iznos', 'Iznos na potražnoj strani konta.', default='0', **pos('Iznos ne može biti negativan.'))],
   [[1, 1, 6, 'Materijal', 100, 0], [2, 1, 3, 'Pretporez 25 %', 25, 0], [3, 1, 4, 'Obveza prema dobavljaču', 0, 125],
    [4, 2, 2, 'Potraživanje od kupca', 1062.5, 0], [5, 2, 7, 'Prihod od prodaje', 0, 850], [6, 2, 5, 'Obveza za PDV 25 %', 0, 212.5],
    [7, 3, 1, 'Uplata na žiro račun', 1250, 0], [8, 3, 2, 'Zatvaranje potraživanja', 0, 1250]]),
])

# ---------------------------------------------------------------- pdv_knjige
D('pdv_knjige', 'PDV: knjiga ulaznih i izlaznih računa',
  'Evidencija računa za PDV: knjiga ulaznih računa (URA), knjiga izlaznih računa (IRA) s fiskalizacijom (ZKI/JIR) i PDV prijava po razdoblju. ' + NOTE,
  'hrvatska,racunovodstvo,pdv', [
  T('ura_racun', 'Knjiga ulaznih računa (URA)', 'Računi dobavljača s osnovicom, PDV-om i pravom na pretporez.', [
    PK('Šifra zapisa.'), whole('redni_broj', 'Redni broj', 'redoslijed', 'Redni broj u knjizi unutar godine.', required=True, **gtz('Redni broj mora biti veći od nule.')),
    datum('Datum računa.'), dt('datum_primitka', 'Datum primitka', 'Kada je račun primljen.'),
    txt('dobavljac_naziv', 'Dobavljač', 'naziv', 'Naziv dobavljača s računa.', required=True), oib(), broj_racuna(),
    osnovica(), pdv_stopa(), pdv_iznos(), cur('ukupno', 'Ukupno', 'iznos', 'Iznos za platiti (osnovica + PDV).'),
    flag('pravo_na_odbitak', 'Pravo na odbitak', 'Je li pretporez s računa moguće odbiti.', default='True'),
    F('datum_dospijeca', 'Dospijeće', 'date', 'datum', 'Do kada kupac treba platiti.'), placeno()],
   [[1, 1, '2026-01-12', '2026-01-14', 'Tehno-trgovina d.o.o.', '23456789012', 'R-2026-118', 200, 25, 50, 250, 1, '2026-02-11', 1],
    [2, 2, '2026-02-03', '2026-02-05', 'Papir i ured d.o.o.', '34567890123', 'R-77/26', 80, 25, 20, 100, 1, '2026-03-05', 1],
    [3, 3, '2026-03-02', '2026-03-04', 'Elektro Veleprodaja', '45678901234', '0319/1/1', 100, 25, 25, 125, 1, '2026-04-01', 0]],
   report=('placeno', 'datum')),
  T('ira_racun', 'Knjiga izlaznih računa (IRA)', 'Izdani računi s PDV-om i podacima o fiskalizaciji.', [
    PK('Šifra zapisa.'), whole('redni_broj', 'Redni broj', 'redoslijed', 'Redni broj u knjizi unutar godine.', required=True, **gtz('Redni broj mora biti veći od nule.')),
    datum('Datum računa.'), txt('kupac_naziv', 'Kupac', 'naziv', 'Naziv kupca s računa.', required=True), oib(), broj_racuna(),
    osnovica(), pdv_stopa(), pdv_iznos(), cur('ukupno', 'Ukupno', 'iznos', 'Iznos za platiti (osnovica + PDV).'),
    flag('fiskaliziran', 'Fiskaliziran', 'Je li račun fiskaliziran (gotovinski i kartični računi).', default='False'),
    txt('zki', 'ZKI', 'identifikator', 'Zaštitni kod izdavatelja, 32 znaka heksadecimalno.', validation='Len([value]) = 32', validation_msg='ZKI ima 32 znaka.', width=250),
    txt('jir', 'JIR', 'identifikator', 'Jedinstveni identifikator računa dobiven od Porezne uprave (UUID).', validation='Len([value]) = 36', validation_msg='JIR ima 36 znakova.', width=290),
    placeno()],
   [[1, 1, '2026-01-15', 'Kvaka d.o.o.', '12345678903', '2026-0001', 1000, 25, 250, 1250, 0, None, None, 1],
    [2, 2, '2026-02-03', 'Marija Horvat', '98765432109', '2026-0002', 120, 25, 30, 150, 1, '0123456789abcdef0123456789abcdef', '11111111-2222-3333-4444-555555555555', 1],
    [3, 3, '2026-03-10', 'Adria promet d.d.', '45678912305', '2026-0003', 850, 25, 212.5, 1062.5, 0, None, None, 0]],
   report=('placeno', 'datum')),
  T('pdv_prijava', 'PDV prijave', 'Obračun PDV-a po razdoblju: obveza iz izlaznih računa minus pretporez iz ulaznih.', [
    PK('Šifra prijave.'), godina(), mjesec(),
    kategorija_x('pdv_razdoblje', 'Razdoblje', 'Mjesečno,Tromjesečno', 'Koliko često se podnosi prijava.', 'Mjesečno'),
    cur('pdv_obveza', 'PDV obveza', 'iznos', 'PDV obračunan na izlaznim računima.', **pos('Iznos ne može biti negativan.')),
    cur('pretporez', 'Pretporez', 'iznos', 'PDV s ulaznih računa koji se odbija.', **pos('Iznos ne može biti negativan.')),
    cur('pdv_za_uplatu', 'Za uplatu', 'iznos', 'Obveza minus pretporez; negativno znači povrat.'),
    dt('datum_predaje', 'Predano', 'Kada je prijava predana Poreznoj upravi.'),
    kategorija_x('status_prijave', 'Status', 'Priprema,Predano,Plaćeno', 'Stanje prijave.', 'Priprema')],
   [[1, 2026, 1, 'Mjesečno', 250, 50, 200, '2026-02-20', 'Plaćeno'], [2, 2026, 2, 'Mjesečno', 30, 20, 10, '2026-03-20', 'Predano'], [3, 2026, 3, 'Mjesečno', 212.5, 25, 187.5, None, 'Priprema']],
   report=('status_prijave', 'mjesec')),
])

# ---------------------------------------------------------------- place_hr
D('place_hr', 'Obračun plaće (Hrvatska)',
  'Obračun plaće po uobičajenom hrvatskom postupku: bruto, doprinosi iz plaće (MIO I. i II. stup), dohodak, osobni odbitak, porez i prirez, neto i trošak poslodavca; tablica stopa i JOPPD izvješća. ' + NOTE,
  'hrvatska,racunovodstvo,place', [
  T('porezna_stopa', 'Stope doprinosa i poreza', 'Stope za obračun s datumom važenja; mijenjaju se zakonom pa se čuvaju kao podaci, ne u formulama.', [
    PK('Šifra stope.'), kategorija_x('vrsta_davanja', 'Vrsta', 'MIO I. stup,MIO II. stup,Zdravstveno,Porez 20 %,Porez 30 %,Prirez', 'Na što se stopa odnosi.', 'MIO I. stup'),
    dec('stopa', 'Stopa (%)', 'postotak', 'Postotak koji se primjenjuje.', decimals=2, required=True, validation='[value] >= 0 And [value] <= 100', validation_msg='Stopa je između 0 i 100.'),
    dt('vrijedi_od', 'Vrijedi od', 'Od kada se stopa primjenjuje.'), dt('vrijedi_do', 'Vrijedi do', 'Do kada vrijedi; prazno ako je još na snazi.'), napomena('Izvor stope (zakon, članak).')],
   [[1, 'MIO I. stup', 15, '2019-01-01', None, 'Doprinos iz plaće'], [2, 'MIO II. stup', 5, '2019-01-01', None, 'Doprinos iz plaće'], [3, 'Zdravstveno', 16.5, '2019-01-01', None, 'Doprinos na plaću, tereti poslodavca'],
    [4, 'Porez 20 %', 20, '2024-01-01', None, 'Niža stopa, ovisi o gradu ili općini'], [5, 'Porez 30 %', 30, '2024-01-01', None, 'Viša stopa na dio osnovice']]),
  T('radnik', 'Radnici', 'Osobni podaci potrebni za obračun plaće.', [
    PK('Šifra radnika.'), ime(), prezime(), oib(), iban(),
    dec('osobni_odbitak_faktor', 'Faktor osobnog odbitka', 'postotak', 'Faktor osobnog odbitka (1 = osnovni; veći s uzdržavanom djecom).', decimals=2, default='1', **pos('Faktor ne može biti negativan.')),
    dec('prirez_stopa', 'Prirez (%)', 'postotak', 'Stopa prireza mjesta prebivališta.', decimals=2, default='0', **pos('Stopa ne može biti negativna.')), aktivan()],
   [[1, 'Marta', 'Novak', '22222222226', 'HR4423600001101234565', 1.5, 0, 1], [2, 'Petra', 'Kovač', '33333333333', 'HR7624020061100000001', 1, 10, 1]]),
  T('obracun_place', 'Obračuni plaće', 'Mjesečni obračun po radniku. Iznosi kao u primjeru: bruto 1500, MIO 20 %, osobni odbitak 560, porez 20 %.', [
    PK('Šifra obračuna.'), REF('radnik_id', 'Radnik', 'radnik.sifra', 'Za koga je obračun.', required=True), godina(), mjesec(),
    bruto(), cur('mio_1_stup', 'MIO I. stup', 'iznos', 'Doprinos za mirovinsko osiguranje na temelju generacijske solidarnosti.'),
    cur('mio_2_stup', 'MIO II. stup', 'iznos', 'Doprinos za mirovinsko osiguranje na temelju individualne kapitalizirane štednje.'),
    cur('dohodak', 'Dohodak', 'iznos', 'Bruto minus doprinosi iz plaće.'), cur('osobni_odbitak', 'Osobni odbitak', 'iznos', 'Iznos osobnog odbitka za mjesec.', **pos('Iznos ne može biti negativan.')),
    cur('porezna_osnovica', 'Porezna osnovica', 'iznos', 'Dohodak minus osobni odbitak (najmanje nula).'), cur('porez', 'Porez', 'iznos', 'Porez i prirez na dohodak.'),
    cur('neto', 'Neto', 'iznos', 'Iznos za isplatu na račun.'), cur('zdravstveno', 'Zdravstveno (poslodavac)', 'iznos', 'Doprinos za zdravstveno osiguranje na plaću.'),
    cur('trosak_poslodavca', 'Trošak poslodavca', 'iznos', 'Bruto plaća uvećana za doprinose na plaću.'), dt('datum_isplate', 'Datum isplate', 'Kada je novac isplaćen.')],
   [[1, 1, 2026, 2, 1500, 225, 75, 1200, 840, 360, 72, 1128, 247.5, 1747.5, '2026-03-05'], [2, 2, 2026, 2, 1500, 225, 75, 1200, 560, 640, 140.8, 1059.2, 247.5, 1747.5, '2026-03-05']],
   report=('radnik_id', 'mjesec')),
  T('joppd_obrazac', 'JOPPD izvješća', 'Evidencija predanih JOPPD obrazaca (izvješće o primicima, porezu i doprinosima).', [
    PK('Šifra izvješća.'), txt('oznaka_izvjesca', 'Oznaka izvješća', 'identifikator', 'Oznaka izvješća u JOPPD obrascu.'), godina(), mjesec(), dt('datum_podnosenja', 'Podneseno', 'Kada je JOPPD predan.'),
    kategorija_x('status_joppd', 'Status', 'Priprema,Predano,Odbijeno', 'Stanje predaje.', 'Priprema'), napomena()],
   [[1, '202602-1', 2026, 2, '2026-03-05', 'Predano', None], [2, '202603-1', 2026, 3, None, 'Priprema', None]]),
])

# ---------------------------------------------------------------- osnovna_sredstva
D('osnovna_sredstva', 'Dugotrajna imovina i amortizacija',
  'Evidencija osnovnih sredstava: skupine sa stopama amortizacije, imovina s nabavnom vrijednošću i godišnji obračun amortizacije. ' + NOTE,
  'hrvatska,racunovodstvo,imovina', [
  T('skupina_imovine', 'Skupine imovine', 'Vrste imovine s godišnjom stopom amortizacije.', [
    PK('Šifra skupine.'), naziv('Naziv skupine imovine.'),
    dec('stopa_amortizacije', 'Stopa amortizacije (%)', 'postotak', 'Godišnja stopa linearne amortizacije.', decimals=2, required=True, validation='[value] > 0 And [value] <= 100', validation_msg='Stopa je između 0 i 100.'),
    whole('vijek_godina', 'Vijek trajanja (god.)', 'kolicina', 'Procijenjeni vijek trajanja.', **gtz('Vijek mora biti veći od nule.')), opis('Što spada u skupinu.')],
   [[1, 'Građevinski objekti', 5, 20, 'Zgrade i poslovni prostori'], [2, 'Osobni automobili', 20, 5, None], [3, 'Računala i oprema', 50, 2, 'Računala, serveri, mobiteli'], [4, 'Uredski namještaj', 20, 5, None]]),
  T('imovina', 'Imovina', 'Pojedinačna sredstva s nabavnom vrijednošću i stanjem.', [
    PK('Šifra sredstva.'), txt('inventarni_broj', 'Inventarni broj', 'identifikator', 'Jedinstveni broj sredstva u knjizi imovine.', required=True), naziv('Naziv sredstva.'),
    REF('skupina_id', 'Skupina', 'skupina_imovine.sifra', 'Skupina za amortizaciju.', required=True), dt('datum_nabave', 'Nabavljeno', 'Datum nabave prema računu.'),
    dt('datum_upotrebe', 'U upotrebi od', 'Od kada se amortizira.'), cur('nabavna_vrijednost', 'Nabavna vrijednost', 'iznos', 'Nabavna vrijednost bez pretporeza.', **pos('Vrijednost ne može biti negativna.')),
    mjesto_pohrane(), kategorija_x('status_imovine', 'Status', 'U upotrebi,Otpisana,Prodana,Rashodovana', 'Stanje sredstva.', 'U upotrebi'), aktivan(), napomena()],
   [[1, 'OS-0001', 'Prijenosno računalo ThinkPad', 3, '2025-01-15', '2025-01-20', 1200, 'Ured', 'U upotrebi', 1, None],
    [2, 'OS-0002', 'Škoda Octavia', 2, '2021-06-01', '2021-06-05', 22000, 'Garaža', 'U upotrebi', 1, None], [3, 'OS-0003', 'Uredski stol i stolica', 4, '2023-03-10', '2023-03-12', 640, 'Ured', 'U upotrebi', 1, None]],
   report=('skupina_id', 'inventarni_broj')),
  T('amortizacija', 'Amortizacija', 'Godišnji obračun amortizacije po sredstvu.', [
    PK('Šifra obračuna.'), REF('imovina_id', 'Sredstvo', 'imovina.sifra', 'Sredstvo koje se amortizira.', required=True), godina(),
    cur('amortizacija_godina', 'Amortizacija godine', 'iznos', 'Trošak amortizacije za godinu.', **pos('Iznos ne može biti negativan.')),
    cur('ispravak_vrijednosti', 'Ispravak vrijednosti', 'iznos', 'Zbroj dosadašnje amortizacije.', **pos('Iznos ne može biti negativan.')),
    cur('sadasnja_vrijednost', 'Sadašnja vrijednost', 'iznos', 'Nabavna vrijednost minus ispravak vrijednosti.')],
   [[1, 1, 2025, 550, 550, 650], [2, 1, 2026, 600, 1150, 50], [3, 2, 2025, 4400, 17600, 4400], [4, 3, 2025, 128, 304, 336]]),
])

# ---------------------------------------------------------------- blagajna
D('blagajna', 'Blagajnički dnevnik',
  'Gotovinsko poslovanje: blagajnički nalozi (uplatnice i isplatnice) i dnevni izvještaji sa stanjem blagajne. ' + NOTE,
  'hrvatska,racunovodstvo,gotovina', [
  T('blagajna_nalog', 'Blagajnički nalozi', 'Uplatnice i isplatnice s rednim brojem i opisom.', [
    PK('Šifra naloga.'), broj(), datum('Datum naloga.'), kategorija_x('vrsta_blag_naloga', 'Vrsta', 'Uplatnica,Isplatnica', 'Uplata u blagajnu ili isplata iz nje.', 'Uplatnica'),
    partner(), svrha(), iznos('Iznos naloga.'), broj_dokumenta(), napomena()],
   [[1, 'U-2026-001', '2026-03-02', 'Uplatnica', 'Marija Horvat', 'Gotovinsko plaćanje računa 2026-0002', 150, '2026-0002', None], [2, 'I-2026-001', '2026-03-03', 'Isplatnica', 'Papir i ured d.o.o.', 'Uredski materijal', 45.5, 'R-77/26', None],
    [3, 'I-2026-002', '2026-03-05', 'Isplatnica', 'HAK', 'Cestarina', 18.6, None, None]],
   report=('vrsta_blag_naloga', 'datum')),
  T('blagajna_izvjestaj', 'Dnevni izvještaji', 'Stanje blagajne na kraju dana: početno stanje + uplate - isplate = završno stanje.', [
    PK('Šifra izvještaja.'), datum('Dan izvještaja.'), pocetno_stanje(), cur('ukupne_uplate', 'Uplate', 'iznos', 'Zbroj uplatnica u danu.', **pos('Iznos ne može biti negativan.')),
    cur('ukupne_isplate', 'Isplate', 'iznos', 'Zbroj isplatnica u danu.', **pos('Iznos ne može biti negativan.')), cur('zavrsno_stanje', 'Završno stanje', 'iznos', 'Stanje blagajne na kraju dana.'), txt('blagajnik', 'Blagajnik', 'naziv', 'Tko vodi blagajnu.')],
   [[1, '2026-03-02', 200, 150, 0, 350, 'Ivan Horvat'], [2, '2026-03-03', 350, 0, 45.5, 304.5, 'Ivan Horvat'], [3, '2026-03-05', 304.5, 0, 18.6, 285.9, 'Ivan Horvat']]),
])

# ---------------------------------------------------------------- obrt
D('obrt', 'Obrt: knjiga prometa i godišnji obračun',
  'Obrtnik ili freelancer: evidencija primitaka i izdataka kroz godinu i godišnji sažetak dohotka, doprinosa i poreza. ' + NOTE,
  'hrvatska,racunovodstvo,obrt', [
  T('promet_obrta', 'Knjiga primitaka i izdataka', 'Svaki primitak i izdatak s dokumentom, svrhom i načinom plaćanja.', [
    PK('Šifra zapisa.'), whole('redni_broj', 'Redni broj', 'redoslijed', 'Redni broj u knjizi unutar godine.', required=True, **gtz('Redni broj mora biti veći od nule.')), datum('Datum prometa.'),
    broj_dokumenta(), svrha(), kategorija_x('vrsta_prometa', 'Vrsta', 'Primitak,Izdatak', 'Je li novac primljen ili isplaćen.', 'Primitak'),
    kategorija_x('kategorija_izdatka', 'Kategorija', 'Roba i materijal,Usluge,Najam,Gorivo i prijevoz,Telekomunikacije,Osiguranje,Doprinosi,Ostalo', 'Za izdatke: o čemu je riječ.', 'Ostalo'),
    iznos('Iznos prometa.'), txt('nacin_placanja', 'Način plaćanja', 'kategorija', 'Kako kupac plaća.', **ch('Virman,Gotovina,Kartica,Pouzeće', 'Virman')), napomena()],
   [[1, 1, '2026-01-15', '2026-0001', 'Račun Kvaka d.o.o.', 'Primitak', None, 1250, 'Virman', None], [2, 2, '2026-01-20', 'R-2026-118', 'Alati i materijal', 'Izdatak', 'Roba i materijal', 250, 'Kartica', None],
    [3, 3, '2026-02-03', '2026-0002', 'Račun Marija Horvat', 'Primitak', None, 150, 'Gotovina', None], [4, 4, '2026-02-10', 'HZZO-2', 'Doprinos za zdravstveno', 'Izdatak', 'Doprinosi', 120, 'Virman', None]],
   report=('vrsta_prometa', 'datum')),
  T('obracun_obrta', 'Godišnji obračun', 'Sažetak godine: primici minus izdaci, doprinosi i porez.', [
    PK('Šifra obračuna.'), godina(), cur('ukupni_primici', 'Primici', 'iznos', 'Zbroj primitaka u godini.', **pos('Iznos ne može biti negativan.')),
    cur('ukupni_izdaci', 'Izdaci', 'iznos', 'Zbroj izdataka u godini.', **pos('Iznos ne može biti negativan.')), cur('dohodak', 'Dohodak', 'iznos', 'Bruto minus doprinosi iz plaće.'),
    cur('doprinosi', 'Doprinosi', 'iznos', 'Doprinosi iz plaće.'), cur('porez', 'Porez', 'iznos', 'Porez i prirez na dohodak.'), napomena()],
   [[1, 2025, 28000, 11500, 16500, 4200, 1700, 'Predano u veljači 2026.']]),
])

# ---------------------------------------------------------------- bankovni_izvodi
D('bankovni_izvodi', 'Bankovni računi i izvodi',
  'Računi u banci, izvodi i stavke izvoda s pozivom na broj; osnova za uparivanje uplata s računima. ' + NOTE,
  'hrvatska,racunovodstvo,banka', [
  T('bankovni_racun', 'Računi u banci', 'Poslovni i privatni računi.', [
    PK('Šifra računa.'), naziv('Naziv računa (npr. Poslovni račun).'), iban(), txt('banka', 'Banka', 'naziv', 'Naziv banke.'), valuta(), aktivan()],
   [[1, 'Poslovni račun', 'HR1210010051863000160', 'Privredna banka Zagreb', 'EUR', 1], [2, 'Devizni račun', 'HR4423600001101234565', 'Zagrebačka banka', 'EUR', 1]]),
  T('izvod', 'Izvodi', 'Dnevni ili mjesečni izvodi s početnim i završnim stanjem.', [
    PK('Šifra izvoda.'), REF('racun_id', 'Račun', 'bankovni_racun.sifra', 'Račun na koji se izvod odnosi.', required=True),
    txt('broj_izvoda', 'Broj izvoda', 'identifikator', 'Broj izvoda iz banke.', required=True), datum('Datum izvoda.'), pocetno_stanje(),
    cur('zavrsno_stanje', 'Završno stanje', 'iznos', 'Stanje na kraju izvoda.')],
   [[1, 1, '12/2026', '2026-03-02', 5000, 6250], [2, 1, '13/2026', '2026-03-03', 6250, 6064.7]]),
  T('stavka_izvoda', 'Stavke izvoda', 'Pojedinačne uplate i isplate na izvodu.', [
    PK('Šifra stavke.'), REF('izvod_id', 'Izvod', 'izvod.sifra', 'Izvod.', required=True, on_delete='cascade'), datum('Datum knjiženja u banci.'), partner(),
    iban(), txt('poziv_na_broj', 'Poziv na broj', 'identifikator', 'Poziv na broj iz uplatnice; služi za automatsko spajanje uplate s računom.'), svrha(),
    iznos('Pozitivan iznos za priljev, negativan za odljev.'), flag('knjizeno', 'Proknjiženo', 'Označi kad je stavka proknjižena u glavnoj knjizi.', default='False')],
   [[1, 1, '2026-03-02', 'Kvaka d.o.o.', 'HR9423400091110123456', '2026-0001', 'Plaćanje računa 2026-0001', 1250, 1], [2, 2, '2026-03-03', 'Tehno-trgovina d.o.o.', 'HR7123600001101234567', 'R-2026-118', 'Plaćanje računa R-2026-118', -250, 1],
    [3, 2, '2026-03-03', 'Porezna uprava', 'HR1210010051863000160', 'HR68 1234-56', 'PDV za veljaču', -10, 0]]),
])

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
