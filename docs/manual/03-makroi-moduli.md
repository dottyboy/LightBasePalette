# Makroi, događaji i moduli

## Makro

Makro je tekst u kojem je svaki redak jedna naredba. Pravila:

* prazni retci i retci koji počinju s `#` ili `//` su komentari;
* naredba ima oblik `verb: argument` (npr. `msg: Gotovo!`) ili samo `verb`;
* uvjetni redak: `if izraz then naredba` — izraz je izraz iz poglavlja „Izrazi” nad trenutnim zapisom;
* `stop` prekida makro;
* varijable, uvjeti s „inače” i petlje: vidi *Varijable, uvjeti i petlje* niže;
* makro može pozvati drugi makro (`macro: ime`), do dubine 8.

```
# unos nove transakcije
if IsNull([iznos]) then msg: Upiši iznos
if IsNull([iznos]) then stop
if [iznos] > 1000 then msg: Velika transakcija, provjeri račun!
sql: UPDATE statistika SET broj = broj + 1
requery
```

Makroi se pokreću iz izbornika (*Skripta → Pokreni makro*), s gumba na formi (`OnClick` = `macro:ime` ili izravno naredba), iz događaja forme ili iz izbornika aplikacije.

### Varijable, uvjeti i petlje

Makro može imati varijable i strukture. Sve je i dalje redak po redak; strukture se zatvaraju vlastitim retkom.

```
let n = 0
let zbroj = 0
while [n] < 5
  let n = [n] + 1
  let zbroj = [zbroj] + [n]
end while
if [zbroj] > 10
  msg: Zbroj je {zbroj}
else
  msg: Premalo
end if
repeat 3
  sql: INSERT INTO dnevnik (poruka) VALUES ('probni redak')
end repeat
```

| Redak | Značenje |
|---|---|
| `let ime = izraz` | Varijabla; u izrazima se piše `[ime]`, u tekstu naredbe `{ime}`. Vrijedi dok se makro izvodi. |
| `if uvjet` … `else` … `end if` | Uvjet u više redaka; dio `else` nije obavezan. Jednoredni oblik `if uvjet then naredba` i dalje vrijedi. |
| `while uvjet` … `end while` | Ponavlja dok je uvjet istinit. |
| `repeat n` … `end repeat` | Ponavlja n puta. |

Makro odmah ima ugrađene varijable `[korisnik]` (prijavljeni korisnik), `[datum]` (današnji, `gggg-mm-dd`) i `[vrijeme]` (`hh:mm`), npr. `sql: INSERT INTO dnevnik (kad, tko) VALUES ({datum}, {korisnik})`.

U naredbi `sql:` oznaka `{ime}` ubacuje vrijednost kao SQL: broj bez navodnika, tekst u navodnicima (apostrof se sam udvostruči), pa unos kao `O'Brien` ne kvari upit.
Petlja koja se izvodi preko 100.000 koraka prekida se porukom. Strukture se mogu ugnijezditi; neuparen `if`, `while` ili `repeat` javlja se prije izvođenja.

### Makro blokovima

U uređivaču makroa gumb **Blokovi** prebacuje isti makro iz teksta u blokove (a **Tekst** natrag). Ništa se ne pretvara u nešto drugo: svaki redak makroa je jedan blok,
pa se tekst koji nisi dirao vraća točno onakav kakav je bio.

* **Lijevo** je popis naredbi, grupiran po namjeni: *Tijek i poruke*, *Baza*, *Forma*, *Izvješće*, *Ostalo*. Dvoklik (ili **Dodaj naredbu**) dodaje blok iza označenog. Ispod popisa su gumbi za **uvjet (ako … inače)**, **petlju (dok vrijedi / ponovi n puta)**, **varijablu**, **kratki uvjet**, **komentar** i **stop**. Uvjet i petlja dodaju se zajedno sa svojim završnim blokom; brisanje početka briše i završni blok, a sadržaj ostaje. Blokovi unutar uvjeta i petlji su uvučeni.
* **Desno** su blokovi, jedan ispod drugog: naredba s poljem argumenta (za forme, izvješća i makroe nudi se popis postojećih), uvjet s poljem izraza i gumbom **ƒx** (graditelj izraza), komentar i stop.
* Redoslijed se mijenja strelicama **↑ ↓** ili povlačenjem ručke **☰** na drugi blok; **✕** briše blok.
* **Provjeri** i **Spremi** rade nad tekstom nastalim iz blokova, pa vrijede ista pravila (nepoznata naredba, uvjet bez `then`…).

**Događaji i gumbi:** u dizajneru forme, u popisu svojstava događaja (`OnOpen`, `BeforeUpdate`…) odaberi **<novi makro blokovima…>**: program napravi makro s nazivom `Forma_Događaj`, postavi ga kao vrijednost (`macro:Naziv`) i odmah ga otvori u uređivaču blokova. Kod svojstva `OnClick` gumb **…** pita želiš li složiti makro blokovima ili upotrijebiti graditelj akcija (jedna naredba); ako je već postavljen `macro:Naziv`, otvara se taj makro. *Novi makro* na kartici Makroi također se otvara u prikazu blokova.

Blokovi su samo drugi prikaz istog makra; makro koji napišeš tekstom možeš dalje slagati blokovima i obrnuto.

### Primjer aplikacije složene blokovima: mali obrt

*Baza → Nova: primjer s blokovima (mali obrt)…* (ili `typhaccess --make-blocks-demo MaliObrt.db`) izrađuje cijelu malu aplikaciju. Tablice, forme i ispisi dolaze iz poslovnog predloška
*Dokument sa stavkama* (računi, partneri, artikli), a **sve što aplikacija „radi” složeno je blokovima**. Otvori karticu *Makroi*, odaberi makro, *Uredi makro* i gumb **Blokovi**.

| Makro | Što radi | Pokazuje |
|---|---|---|
| `Oznaci placenim` | gumb na formi *Računi*: pita, pa upiše `placeno = 1` i spremi | `ask`, uvjet s *inače*, `set`, `save` |
| `Sazetak neplacenih` | javlja broj neplaćenih računa i osnovicu duga | `fetch` upita u varijable, `{varijabla}` u poruci |
| `Povecaj cijene` | pita za postotak, provjeri raspon, poveća cijene u cjeniku | `input`, `let`, uvjet, `sql` s `{varijabla}` |
| `Cjenik u PDF` | izvješće *Cjenik* u PDF na putanju koju upišeš | `input`, `exportpdf` |
| `Kopija baze` | sigurnosna kopija cijele baze na putanju koju upišeš | `input`, `backup` |

Glavni izbornik (*Izbornik*, početna forma) ima gumbe za forme i za svaki makro. Svaki se makro može mijenjati blokovima ili tekstom; promjena je odmah
vidljiva u drugom prikazu. Primjer se provjerava u testu: svaki makro se izvodi i daje navedeni rezultat (npr. „Neplaćenih računa: 1, osnovica ukupno 124 EUR.”).

### Naredbe

| Naredba | Radi |
|---|---|
| `msg: tekst` | Prikazuje poruku. |
| `sql: naredba` | Izvodi SQL naredbu (INSERT, UPDATE, DELETE…); u formi nakon toga osvježi podatke. |
| `run: procedura` | Poziva proceduru iz modula. |
| `fgl: program` | Pokreće 4GL program spremljen u bazi (izbornik: `program Naziv`). |
| `macro: ime` | Pokreće drugi makro. |
| `close` | Zatvara formu. |
| `goto: kontrola` | Premješta fokus na kontrolu forme. |
| `openform: ime` | Otvara formu (uz provjeru prava). |
| `openreport: ime`, `openreport: ime@izraz`, `openreport: ime#poredak=Naziv` | Otvara izvješće; ono iza `@` je izraz koji daje SQL uvjet, npr. `openreport: Račun@"id = " & [id]`; `#poredak=` otvara ga u jednom od ponuđenih poredaka izvješća (svojstvo `SortOptions`). |
| `export` ili `export: datoteka.csv` | Izvozi prikaz forme u CSV. |
| `filter: uvjet` / `nofilter` | Postavlja / ukida filter forme (SQL uvjet). |
| `clearfilter`, `clearfilters` | Isto što i `nofilter`: ukida filter forme. |
| `query` | Upitni način forme: u polja se upisuju uzorci za traženje. |
| `execquery`, `cancelquery` | Izvodi upit upisan u upitnom načinu (F8) ili ga otkazuje (Esc). |
| `clearquery` | Briše uzorke po stupcima i ponovo čita podatke. |
| `savequery: ime`, `loadquery: ime`, `deletequery: ime` | Sprema izvedeno traženje pod imenom, primjenjuje ga ili ga briše. |
| `esphome:` | Izrađuje ESPHome konfiguracije za sve pogone s MQTT temom u odabranu mapu (primjer „Proizvodni procesi”). |
| `requery` (`refresh`) | Ponovo čita podatke. |
| `save` | Sprema trenutni zapis. |
| `undo` | Poništava nespremljene promjene. |
| `find: polje = izraz` | Postavlja se na prvi zapis u kojem polje ima tu vrijednost; ako ga nema, javlja poruku. |
| `gotorecord: izraz` | Ide na zapis s tim rednim brojem (1 = prvi); izvan raspona ide na najbliži. |
| `sort: polje [DESC]` | Poredak prikaza po jednom ili više polja (`cijena DESC, naziv`); prazno vraća prirodni poredak. |
| `set: polje = izraz` | Upisuje vrijednost izraza u polje forme. |
| `visible: kontrola = izraz`, `enabled: kontrola = izraz` | Prikazuje/skriva ili omogućuje/onemogućuje kontrolu (izraz je istinit = da). |
| `caption: kontrola = izraz` | Mijenja natpis kontrole. |
| `ask: pitanje` | Pita Da/Ne; odgovor je u varijabli `[odgovor]` (1 = Da, 0 = Ne). |
| `input: pitanje` | Pita za unos; tekst je u varijabli `[unos]`. |
| `beep` | Zvučni signal. |
| `fetch: ime = SELECT …` | Prvo polje prvog retka upita postaje varijabla `ime` (prazno = prazna vrijednost); `{varijabla}` u upitu ubacuje se kao SQL vrijednost. |
| `run4gl: Naziv programa` | Pokreće 4GL program spremljen u bazi (izbornik *Skripta*, kartica *4GL*). Izlazni kod ostaje u varijabli `izlaz4gl`. Program s `DISPLAY` otvara prozor s ispisom, pa je prikladan za gumbe i izbornike. |
| `copyrows: izvor WHERE uvjet -> cilj : polje = izraz, …` | **Dokument iz dokumenta:** za svaki redak izvora koji zadovoljava uvjet (uvjet je nepovinan) upiše redak u ciljnu tablicu. Desna strana svakog `polje = izraz` je SQL izraz nad poljima izvora (`id`, `naziv * 2`, `'Dodatno: ' || naziv`, `date('now')`) ili `{varijabla}`. Poslije su u varijablama `kopirano` (broj redaka) i `novi` (najveći `id` u cilju, tj. zadnji upisani). Tako se ponuda pretvara u ugovor, a stavke ponude u stavke ugovora: `copyrows: ponude WHERE id = {pid} -> ugovori : ponuda_id = id, naziv = naziv` pa `copyrows: ponude_stavke WHERE ponuda_id = {pid} -> ugovor_stavke : ugovor_id = {novi}, opis = opis`. Nazivi tablica i polja smiju imati samo slova, brojke i podvlaku. |
| `importtable: tablica < datoteka` | Uvozi retke iz CSV ili XLSX datoteke u **postojeću** tablicu; prvi redak su nazivi polja koja se pridružuju poljima tablice. Poslije su u varijablama `uvezeno` i `preskoceno`. |
| `copyfile: izvor > odredište` | Kopira datoteku (mape se prave po potrebi, postojeća se prepisuje). |
| `mailto: adresa ; predmet ; tekst` | Otvara novu poruku u programu za e-poštu (predmet i tekst nisu obavezni). Privitak se ne može dodati; PDF prvo spremi naredbom `exportpdf` pa ga priloži ručno. |
| `backup: datoteka.db` | Sigurnosna kopija otvorene baze u datoteku (ne smije biti sama otvorena baza). |
| `exporttable: izvor > datoteka` | Izvozi tablicu ili spremljeni upit; vrsta datoteke po nastavku: `.csv` (razdjelnik `;`), `.xlsx` ili `.json`. |
| `compact` | Provjerava i sažima bazu; ishod se javlja porukom. |
| `wait: sekunde` | Pričeka (najviše 60 s), npr. između dvije obrade. |
| `openletter: Dopis` ili `openletter: Dopis@ključ` | Pregled dopisa (svi primatelji, ili jedan: ključ je vrijednost prvog polja izvora primatelja). |
| `exportletter: Dopis > datoteka.docx` | Dopis u datoteku: `.docx` (Word), `.pdf` ili `.html`; `Dopis@ključ` za jednog primatelja. |
| `exporthtml: Izvješće > datoteka.html` | Izvješće u HTML, bez pregleda; naziv smije imati `#poredak=Naziv`. |
| `exportpdf: Izvješće > datoteka.pdf` | Izvješće u PDF, bez pregleda; naziv smije imati `#poredak=Naziv`. |
| `openurl: adresa` | Otvara adresu ili datoteku u zadanom programu. |
| `first`, `prev` (`prior`), `next`, `last` | Kretanje po zapisima. |
| `new` | Novi zapis. |
| `duplicate` | Kopira trenutni zapis. |
| `delete` | Briše trenutni zapis. |
| `audit` | Otvara povijest promjena trenutnog zapisa (samo administrator). |

Naredbe forme (`close`, `goto`, `new`, `save`…) rade samo kad se makro pokreće iz forme; iz izbornika aplikacije rade `msg`, `sql`, `run`, `fgl`, `macro`, `openform` i `openreport`.

## Događaji

Forme imaju događaje koji pozivaju proceduru modula ili makro (`macro:ime`):

| Događaj | Kada |
|---|---|
| `OnOpen` | forma se otvara |
| `OnCurrent` | promijenio se trenutni zapis |
| `BeforeUpdate` | prije spremanja zapisa — procedura može pozvati `CancelEvent` pa se spremanje otkazuje |
| `AfterUpdate` | nakon spremanja |
| `BeforeDelete` | prije brisanja; `CancelEvent` otkazuje brisanje |
| `OnClose` | forma se zatvara |

Kontrole imaju `OnClick`, `OnDblClick`, `OnChange` (tekst, popisi, kvačice).

## Moduli (PascalScript)

Modul je programski kod u jeziku PascalScript: *Skripta → Novi modul…*. U modulu se pišu samo procedure i funkcije (program sam dodaje završni `begin end.`). Svi moduli se prevode zajedno pa se mogu pozivati međusobno. Funkcije se mogu pozvati i iz izraza (`=Dvaput([iznos])`).

```pascal
function Dvaput(x: Double): Double;
begin
  Result := x * 2;
end;

procedure ProvjeriIznos;
begin
  if GetNumber('iznos') > 1000 then
  begin
    ShowMessage('Velika transakcija!');
    CancelEvent;     // u BeforeUpdate otkazuje spremanje
  end;
end;
```

### Ugrađene funkcije i procedure

| Poziv | Opis |
|---|---|
| `ShowMessage(S)`, `Msg(S)` | Poruka. |
| `Confirm(S): Boolean` | Pita Da/Ne. |
| `InputBox(Naslov, Pitanje, Zadano): string` | Traži unos teksta. |
| `GetValue(ime): string`, `GetNumber(ime): Double` | Vrijednost kontrole/polja u formi. |
| `SetValue(ime, tekst)`, `SetNumber(ime, broj)` | Upisuje vrijednost. |
| `Eval(izraz): string`, `EvalNumber(izraz): Double` | Izračunava izraz. |
| `DoAction(naredba)` | Izvodi naredbu makroa (npr. `'openform:Računi'`). |
| `SetVisible(ime, Boolean)`, `SetEnabled(ime, Boolean)`, `SetCaption(ime, tekst)`, `FocusControl(ime)` | Upravljanje kontrolama. |
| `CancelEvent` | Otkazuje događaj (`BeforeUpdate`, `BeforeDelete`). |
| `DLookup(izraz, tablica, uvjet)`, `DCount(tablica, uvjet)`, `DSum(izraz, tablica, uvjet)` | Zbrojevi nad tablicom. |
| `SqlExec(SQL): Boolean`, `SqlValue(SQL): string` | SQL naredba / prva vrijednost upita. |
| `Today: string`, `NowStr: string` | Datum i vrijeme kao tekst. |
| `FormatVal(vrijednost, oblik): string` | Isto kao `Format`. |
| `NumToStr(Double): string`, `StrToNum(string): Double` | Pretvorbe. |

Korak-po-korak vodič s primjerima (petlje, tekst, čitanje baze, događaji u formi) je u poglavlju *Vodič kroz module*.

Pogreške prevođenja javljaju se pri spremanju modula s retkom i stupcem; gumb **Provjeri** u uređivaču prevodi bez spremanja.

## Kad makro nije dovoljan

* Za zbrojeve i uvjete dovoljni su **izrazi**.
* Za nekoliko koraka bez petlji: **makro**.
* Za petlje, varijable i složenu logiku: **modul** ili cijeli programski jezik **4GL** (zasebno poglavlje), koji ima ugrađen SQL, kursore, zaslone i izvješća.


## Događaj OnError

Forma može imati događaj `OnError`: poziva se kad spremanje ili izvođenje javi pogrešku baze. U skripti je tekst poruke u varijabli `eventMessage`; `CancelEvent` utišava poruku, a promjena `eventMessage` zamjenjuje je prijateljskijom.
