> **ARHIVA:** objedinjeno u [../PLAN.md](../PLAN.md) (2026-11-07). Vrijedi samo taj plan.

# Plan: paleta TyphAccess za CodeTyphon/Lazarus i vizualno programiranje 4GL-a

Verzija plana: 2026-11-07. Stanje koda na koje se plan oslanja: TyphAccess commit `96c970a`.

Ovaj dokument opisuje što gradimo, u kojem redoslijedu, kako provjeravamo da radi i što još treba odlučiti.
Namijenjen je onome tko razvija TyphAccess (ti, ja, kasnije suradnici). Ne objašnjava osnove 4GL-a ni izraza; za to vidi `docs/manual/`.

---

## 0. Sažetak u deset rečenica

1. Postoje **dva načina rada** s istim komponentama: **puni CodeTyphon** (paleta u Lazarus/CodeTyphon IDE-u) i **TyphAccess "light"** (naš vlastiti dizajner i runtime, bez IDE-a).
2. Komponente se **ponašaju i izgledaju identično** u oba. To jamči **jedan zajednički kod** (paket `typhaccess_core`), a ne dvije paralelne izvedbe.
3. Sve što se u jednom okruženju može napraviti **klikom, čarobnjakom ili dijalogom**, mora se moći i u drugom. Zato se dijalozi pišu **jednom** (sloj `editori`) i spajaju na dva mjesta: kao *property editori* u IDE-u i kao dijalozi u dizajneru TyphAccessa.
4. **Izvor podataka** svake kontrole (polje, popis, mreža, grafikon, izvješće) može biti: tablica, SQL, izraz, popis vrijednosti ili **rezultat 4GL programa**. Isti zapis, isto ponašanje u oba okruženja.
5. 4GL dobiva dvije nove sposobnosti: **vraća retke** (da bude izvor podataka) i **vraća jednu vrijednost** (da bude izračun polja).
6. Uvodimo **kosture** (`.4glt`): 4GL s tipiziranim utorima koji se sami popune podacima iz baze.
7. Dva ulaza: **od kostura** (biraš kostur, utori se popune iz baze) i **od podataka** (biraš tablicu, nudi se što joj odgovara).
8. 4GL se uređuje i **vizualno** (postojeći blokovski uređivač), s padajućim popisima iz baze.
9. Izrada je u **fazama koje su svaka sama korisna**; prva faza (4GL kosturi i čarobnjak) daje vidljiv rezultat za nekoliko dana.
10. Svaka faza ima **mjerljiv kriterij prihvaćanja** i testove (paritet, offscreen snimke zaslona, smoke test).

---

## 1. Ciljevi i ograničenja

### 1.1 Što korisnik treba moći

| # | Zahtjev | Posljedica za izvedbu |
|---|---|---|
| Z1 | Ista komponenta u CodeTyphonu i u TyphAccessu: isti izgled, isto ponašanje | jedan kod (`typhaccess_core`), paritetni testovi |
| Z2 | Isti dijalozi i čarobnjaci u oba okruženja | sloj `editori` neovisan o IDE-u |
| Z3 | Kontrola koja može koristiti 4GL, neka ga koristi | 4GL kao izvor podataka, izračun, radnja, pravilo |
| Z4 | Izvor polja može biti SQL, a isto tako i rezultat 4GL-a | jedinstveni opis izvora (`TaSourceDef`) |
| Z5 | Vizualno programiranje: kosturi koji se prilagode podacima | biblioteka kostura, punjenje iz metapodataka |
| Z6 | Dva ulaza: od kostura ili od podataka | dva čarobnjaka nad istim kosturima |
| Z7 | Korisnik smije koristiti samo "light" (TyphAccess), bez punog CodeTyphona | TyphAccess ne smije ovisiti o IDE-u; paleta ovisi o TyphAccessu, ne obrnuto |
| Z8 | Za sada nije potrebno seliti formu između okruženja | prenosivost forme (JSON ↔ `.lfm`) je kasnija faza, ali ne smijemo je onemogućiti |

### 1.2 Ograničenja

- **Qt6 widgetset** je ciljna platforma (CodeTyphon, `--ws=qt6`).
- **Ovisnosti runtimea** ostaju male: Zeos, PascalScript, fpspreadsheet, RichMemo, Image32. **JVCL i RX nisu obavezni** za TyphAccess runtime (vidi 4.4).
- Nijedna nova mogućnost ne smije slomiti postojeće aplikacije (SmartBetTA, `Trgovina Jadran`, katalog). Svaka promjena formata je **unatrag kompatibilna**.
- **Smoke test** (trenutno oko 1700 provjera) mora i dalje prolaziti bez ijedne greške nakon svake faze.

---

## 2. Arhitektura: tri sloja, jedan izvor istine

```
┌──────────────────────────────────────────────────────────────────────────┐
│  Sloj C: sučelja prema korisniku                                          │
│  ┌─────────────────────────────┐    ┌──────────────────────────────────┐  │
│  │ CodeTyphon / Lazarus IDE    │    │ TyphAccess "light"               │  │
│  │ paleta, property editori,   │    │ dizajner formi, izvješća, 4GL,   │  │
│  │ component editori           │    │ runtime                          │  │
│  └──────────────┬──────────────┘    └──────────────┬───────────────────┘  │
├─────────────────┼──────────────────────────────────┼─────────────────────┤
│  Sloj B: editori (dijalozi i čarobnjaci, napisani JEDNOM)                │
│  EditAction, EditSource, EditFormat, EditCondFormat, EditRule,           │
│  PickTable/Column, SkeletonWizard, BlockEditor, ProgramEditor            │
├──────────────────────────────────────────────────────────────────────────┤
│  Sloj A: jezgra (typhaccess_core)                                        │
│  TaDatabase, izrazi, 4GL (interpreter + kosturi), izvori podataka        │
│  (TaSourceDef), mehanizam ponašanja (TaBindingEngine), izvješća,         │
│  kontrole (TaTextBox, TaComboBox, TaChart, ...)                          │
└──────────────────────────────────────────────────────────────────────────┘
```

**Pravila ovisnosti** (smjer strelica = "ovisi o"):

- A ne ovisi ni o čemu iznad sebe.
- B ovisi samo o A i o LCL-u (dijalozi su LCL forme).
- C ovisi o B i A. TyphAccess runtime koristi A i B; IDE paket koristi A i B plus `bs_IDEIntf`.
- Zbog toga "light" varijanta ne treba CodeTyphon: sve što joj treba je A + B + vlastiti dizajner.

**Posljedica za Z1/Z2:** jer su kontrole, ponašanje i dijalozi u A i B, a C ih samo "stavlja na mjesto", razlika između okruženja ne može nastati u logici, samo u načinu pozivanja (property editor ili dijalog dizajnera).

### 2.1 Paketi i izvorne mape

| Paket / mapa | Sadržaj | Ovisi o |
|---|---|---|
| `typhaccess_core` (`src/core`, dio `src/gui`) | sloj A | Zeos, PascalScript, fpspreadsheet, RichMemo, Image32, LCL |
| `typhaccess_editors` (`src/editors`, novo) | sloj B | `typhaccess_core`, LCL |
| `typhaccess_dsgn` (`lazarus/`) | paleta, registracija, property i component editori | `typhaccess_core`, `typhaccess_editors`, `bs_IDEIntf` |
| `typhaccess_ext` (`lazarus/ext`, novo, neobavezno) | proširenja nad JVCL i RX | `typhaccess_dsgn`, `pl_JVCL`, `pl_RX` |
| aplikacija `TyphAccess` | dizajner + runtime ("light") | `typhaccess_core`, `typhaccess_editors` |

Danas je `typhaccess_dsgn` jedini paket i uključuje izvore iz `src/core` i `src/gui` putem putanje. Faza 0 (vidi 6.0) razdvaja to na gornje pakete bez promjene ponašanja.

---

## 3. Jedinstveni opis izvora podataka (`TaSourceDef`)

Ovo je **ključna odluka** za Z3 i Z4. Danas kontrole imaju `RowSource` (tekst: naziv tablice ili SQL) i `ControlSource` (naziv polja ili izraz). Uvodimo jedan zapis koji pokriva sve vrste izvora, uz **potpunu unatrag kompatibilnost**.

### 3.1 Zapis

Izvor je jedan tekst. **Bez prefiksa znači isto što i danas** (naziv tablice, SELECT, ime upita). S prefiksom:

| Prefiks | Značenje | Primjer |
|---|---|---|
| *(nema)* | tablica, upit iz baze ili SELECT, kao do sada | `partneri`, `SELECT id, naziv FROM partneri` |
| `sql:` | izričito SQL (korisno kad naziv liči na prefiks) | `sql:SELECT 1` |
| `expr:` | izraz jezika izraza koji vraća jednu vrijednost | `expr:Zaokruzi([kolicina]*[cijena], 2)` |
| `list:` | fiksni popis, vrijednosti odvojene `;` | `list:Novo;U tijeku;Završeno` |
| `fgl:` | **4GL program ili funkcija**, uz parametre | `fgl:PopisPartnera(grad=[grad], aktivan=1)` |
| `fglv:` | 4GL program koji vraća **jednu vrijednost** | `fglv:Popust([partner_id], [iznos])` |

Zašto jedan tekst, a ne više svojstava: tako se postojeći JSON definicija (`TaControlDef.RowSource`/`ControlSource`) ne mijenja, a prefiks se razumije svugdje gdje se danas razumije SQL.

### 3.2 Što koja kontrola radi s kojom vrstom izvora

| Kontrola | tablica / SQL | izraz | popis | `fgl:` (retci) | `fglv:` (vrijednost) |
|---|---|---|---|---|---|
| TextBox, MemoBox, Label | `ControlSource` = polje | izračunato polje | – | – | izračunato polje iz 4GL-a |
| ComboBox, ListBox | `RowSource` = popis redaka | – | da | **da** (1–3 stupca) | – |
| OptionGroup | – | – | da | da (oznaka, vrijednost) | – |
| Subform / mreža | zapisi | – | – | **da** (bilo koji stupci, samo čitanje) | – |
| Chart | 2 stupca (oznaka, vrijednost) | – | – | **da** (2 stupca) | – |
| Image | – | – | – | – | da (put do slike ili bajtovi) |
| Izvješće (`RecordSource`) | tablica / SQL | – | – | **da** | – |

### 3.3 4GL kao izvor redaka (`fgl:`)

4GL danas ispisuje (`DISPLAY`) i piše u bazu, ali **ne vraća retke** kontroli. Dodajemo dvije nove naredbe:

```4gl
-- program PopisPartnera: izvor podataka za padajući popis
FUNCTION PopisPartnera(grad TEXT, aktivan INTEGER)
  COLUMNS id INTEGER, naziv TEXT
  DEFINE r RECORD id INTEGER, naziv TEXT END RECORD
  DECLARE c CURSOR FOR
    SELECT id, naziv FROM partneri WHERE grad = $grad AND aktivan = $aktivan ORDER BY naziv
  FOREACH c INTO r.*
    EMIT r.id, r.naziv                       -- jedan redak rezultata
  END FOREACH
END FUNCTION
```

- `COLUMNS` imenuje i tipizira izlazne stupce (potrebno da kontrola zna naslove i tipove prije prvog retka).
- `EMIT` dodaje jedan redak u rezultat. Program se izvršava do kraja; rezultat je `TaFglDataSet` (potomak `TDataSet`, u memoriji), kojeg kontrole vide kao svaki drugi skup podataka.
- Parametri ide iz imenovanih argumenata u izvoru (`grad=[grad]`): izrazi se računaju nad **zapisom forme**, kao i danas za `LinkMaster`.
- **Osvježavanje (requery):** kad se promijeni polje koje se spominje u parametrima, izvor se ponovno izvrši. Kontrola ne mora ništa posebno raditi.
- **Samo za čitanje** je osnovno. Za uređivanje 4GL može definirati `ON SAVE` blok (faza 4); do tada je mreža iz `fgl:` samo prikaz.
- Ograničenja: vrijeme izvršavanja po pozivu (zadano 5 s, postavka), broj redaka (zadano 100.000), zabrana `INPUT`/dijaloga unutar izvora (izvor je bez sučelja; pokušaj je greška s jasnom porukom).

### 3.4 4GL kao izračun (`fglv:` i funkcija `Fgl()`)

Za jednu vrijednost: `RETURN vrijednost` iz funkcije. U jeziku izraza dodajemo funkciju:

```
Fgl("Popust", [partner_id], [iznos])        -- vraća vrijednost 4GL funkcije Popust
```

To je isto što i `fglv:`, samo u obliku koji se može upisati u bilo koji izraz (pravilo, zadana vrijednost, uvjetno oblikovanje, izračunato polje).

### 3.5 Praktični primjer (što korisnik složi mišem)

*Padajući popis partnera na formi računa, ali samo aktivni iz grada koji je odabran na formi.*

1. Dvoklik na `RowSource` → dijalog **Izvor podataka** → kartica *4GL program* → odabere `PopisPartnera` iz popisa programa u bazi (ili *Novi iz kostura…*).
2. Dijalog sam prepozna parametre funkcije i ponudi vezu na polja forme (`grad` → `[grad]`).
3. Gotovo. Isto u CodeTyphonu (Inspektor objekata) i u dizajneru TyphAccessa.

---

## 4. Identičnost komponenti (Z1) i zajednička svojstva

### 4.1 Ugovor o svojstvima

Za svaku kontrolu postoji **jedan popis svojstava** (u `docs/` kao tablica, u kodu kao opis klase). Svojstvo ima isti naziv, isti tip i isto značenje u oba okruženja. Danas su ta svojstva dijelom polja `TaControlDef`, a dijelom ključevi u `Extra` (`visibleIf`, `enabledIf`, `condFormat`, `autofill`, `calcrules`, `locked`, `chartType`, `barType`, ...).

| Skupina | Svojstva (zajednička većini kontrola) |
|---|---|
| Podaci | `ControlSource`, `RowSource` (vidi 3), `Format`, `DefaultValue`, `Locked` |
| Ponašanje | `VisibleIf`, `EnabledIf`, `Rule`, `RuleMessage`, `AutoFill`, `CalcRules` |
| Izgled | `CondFormat`, `Caption`, `Tip`, boje i font, `Anchors`, `Dock` |
| Radnje | `OnClick`, `OnChange`, `OnDblClick` (vrijednost je **radnja**, vidi 5.3) |

U Lazarusu ta svojstva postaju **objavljena (published) svojstva** komponente. U TyphAccessu ostaju polja definicije. **Preslikavanje je tablica u kodu** (`TaPropMap`), ne ručni kod po svojstvu: jedan redak po svojstvu govori kako se vrijednost iz definicije upisuje u komponentu i obrnuto. Nova svojstva se dodaju jednim retkom.

### 4.2 Zajednički stroj ponašanja (`TaBindingEngine`)

**Problem koji rješava:** ponašanje (izrazi, pravila, uvjetno oblikovanje, vidljivost, omogućenost, zadane vrijednosti, izračuni, AutoFill) danas postoji **dvaput**: u `TaFormRunner` (TyphAccess) i u `TaFormBinder` (CodeTyphon paleta). Dok je tako, ponašanje se može razići.

**Rješenje:** izdvojiti stroj u nevizualnu klasu u sloju A. Ulaz: skup podataka, popis vezanja, domaćin izraza. Izlaz: vrijednosti, boje, stanja, odbijanje spremanja. `TaFormRunner` i `TaFormBinder` postaju **tanki adapteri** koji samo prenose događaje (promjena zapisa, `BeforePost`) u stroj i primjenjuju rezultate na stvarne kontrole.

Sučelje (skica):

```pascal
TaBindingEngine = class
  procedure SetDataSet(ADataSet: TDataSet);
  procedure Add(const ABinding: TaBindingDef);        // definicija, ne kontrola
  procedure Refresh;                                  // izračuna sve, vrati promjene
  function Validate(AErrors: TStrings): Boolean;
  property OnApply: TaApplyEvent;                     // (vezanje, što: vrijednost/boja/vidljivost/omogućenost)
end;
```

Primjena rezultata na kontrolu je jedina funkcija koju adapter radi. Tako je ponašanje isto, a razlika među okruženjima ostaje u rukama kojom se kontrola dohvaća.

### 4.3 Izgled

- Kontrole se crtaju istim klasama (LCL). Razlike u izgledu mogu nastati samo od teme, fonta i `LC_NUMERIC`.
- **Hrvatski oblici:** `ApplyCroatianLocale` u oba okruženja; pokretači postavljaju `LC_NUMERIC=hr_HR.UTF-8` jer Qt spin čita okolinu procesa (već u pokretačima deploya).
- **Provjera:** isti obrazac (forma s istim kontrolama i podacima) renderiran u offscreen načinu u oba okruženja daje **PNG snimke koje se uspoređuju** (piksel po piksel s tolerancijom ili po regijama). To je kriterij za Z1.

### 4.4 Kanonske kontrole i JVCL/RX

- **Kanonske kontrole** (u sloju A) su naše klase na čistom LCL-u. Pokrivaju sve što TyphAccess danas koristi: polje s formatom, datum kao polje s kalendarom, padajući popis s traženjem, mreža, grafikon, izbornik.
- **JVCL i RX** ostaju za **neobavezno proširenje** (`typhaccess_ext`): npr. `TaDateEdit` na `TRxDBDateEdit`, `TaCurrencyEdit` na `TJvxCurrencyEdit`, `TaLookup` na `TRxDBLookupCombo`. Imaju isto svojstveno sučelje kao kanonske (`ControlSource`, `Format`, `Rule`...).
- **Zašto ne uzeti JVCL/RX kao osnovu svega:** runtime "light" bi tada ovisio o dva velika paketa (veličina programa, rizik na Qt6, dvostruke postavke oblika). Spike (23 kontrole) pokazao je da rade, pa je to **opcija**, ne uvjet.
- **Pravilo zamjene:** ako korisnik u CodeTyphonu umjesto `TaTextBox` baci `TRxDBCurrEdit`, `TaFormBinder` mu i dalje daje isto ponašanje (RTTI vezanje, već izrađeno).

---

## 5. Isti dijalozi i čarobnjaci u oba okruženja (Z2)

### 5.1 Načelo

Svaki dijalog je **funkcija** u sloju B koja prima **kontekst** i **trenutnu vrijednost**, a vraća novu vrijednost ili odustajanje. Ne zna ni za Inspektor objekata ni za dizajner.

```pascal
type
  TaEditContext = class       // što dijalogu treba znati
    Database: TaDatabase;     // za popise tablica, stupaca, programa, izvješća, formi
    FormFields: TStrings;     // polja forme (za parametre i izraze)
    Owner: TComponent;        // za položaj prozora
  end;

function EditSource(ACtx: TaEditContext; var AValue: string): Boolean;      // vidi 3.1
function EditAction(ACtx: TaEditContext; var AValue: string): Boolean;      // vidi 5.3
function EditFormat(ACtx: TaEditContext; var AValue: string; AKind: TFieldKind): Boolean;
function EditCondFormat(ACtx: TaEditContext; var AValue: string): Boolean;
function EditRule(ACtx: TaEditContext; var AValue, AMessage: string): Boolean;
function EditExpression(ACtx: TaEditContext; var AValue: string): Boolean;  // graditelj izraza
function EditSkeleton(ACtx: TaEditContext; var AProgramText: string): Boolean;   // čarobnjak kostura
function EditProgramBlocks(ACtx: TaEditContext; var AProgramText: string): Boolean;
```

### 5.2 Dva mjesta spajanja

| Okruženje | Kako se dijalog pozove |
|---|---|
| CodeTyphon / Lazarus | `TPropertyEditor` (tipka `…` kod svojstva) i `TComponentEditor` (dvoklik, desni klik): tanki omot koji gradi kontekst iz `TaDatabase` na formi i zove funkciju iz sloja B |
| TyphAccess dizajner | postojeći stupac svojstava (`ta_propedit`, `ta_propdlgs`) zove **iste funkcije**. Dijalozi koji danas žive u `ta_propdlgs` seli se u sloj B (bez promjene izgleda) |

**Posljedica:** dodamo li dijalog ili ga poboljšamo, popravlja se u oba okruženja istodobno. Z2 je ispunjen po konstrukciji.

### 5.3 Radnje (`Action`)

Svojstvo radnje (gumb, stavka izbornika, `TaSideMenu`, događaji) danas je tekst `vrsta:argument`. Popis vrsta je dovršen:

| Radnja | Oblik | Što radi |
|---|---|---|
| forma | `openform:Naziv` | otvori formu (po želji s filtrom) |
| izvješće | `openreport:Naziv` | pregled izvješća |
| izvoz | `exportpdf:Naziv>datoteka.pdf`, `exporthtml:...` | izvoz izvješća |
| makro | `macro:Naziv` | makro |
| procedura modula | `run:Naziv` | PascalScript |
| **4GL program** | `fgl:Naziv` | pokrene 4GL program iz baze |
| SQL | `sql:...` | izravna naredba |
| poruka, zatvori, idi na kontrolu | `msg:`, `close`, `goto:` | pomoćne |

Dijalog `EditAction` prikazuje **izbornik vrsta s popisima iz baze** (forme, izvješća, programi, makroi), da korisnik ne tipka nazive. Za 4GL radnju dodatno nudi: *Uredi program…* i *Novi iz kostura…*.

---

## 6. Faze razvoja

Svaka faza ima: cilj, popis posla, **kriterij prihvaćanja** (što se mora moći pokazati) i procjenu. Procjene su u radnim danima jednog programera uz postojeće znanje; nisu obećanje.

### Faza 0: priprema (1 dan)

**Cilj:** razdvojiti pakete bez promjene ponašanja, da kasnije faze nemaju zavade u ovisnostima.

- Napraviti `typhaccess_core` i `typhaccess_editors` kao `.ctpkg`/`.lpk`; `typhaccess_dsgn` ih traži.
- Premjestiti dijaloge iz `ta_propdlgs`, `ta_fglgui` i sličnih u sloj B tamo gdje je dijalog logički neovisan o dizajneru.
- Uvesti `TaPropMap` (tablica svojstava) uz postojeći kod, još bez promjene izvođenja.

**Prihvaćanje:** smoke test 0 grešaka; `typhaccess_dsgn` se prevodi iz novih paketa; TyphAccess se prevodi i radi isto.

### Faza 1: 4GL kao izvor podataka (2–3 dana)

**Cilj:** Z3 i Z4. Kontrola može koristiti 4GL umjesto SQL-a.

1. **Jezik:** naredbe `COLUMNS` i `EMIT`, `RETURN` s vrijednošću iz funkcije; provjera programa (`--check`) zna za njih.
2. **`TaFglDataSet`** (memorijski `TDataSet`): puni se iz izvršenja funkcije, ima tipove stupaca, ograničenja (vrijeme, broj redaka).
3. **`TaSourceDef`** (3.1): parser prefiksa, jedinstvena funkcija `OpenSource(ADb, ASource, AParams): TDataSet`. Zamjenjuje razasuto otvaranje upita u `ta_formrun`, `ta_reportengine`, `ta_controls` jednim mjestom.
4. **Parametri iz forme** i **requery** pri promjeni polja iz parametara.
5. **Funkcija `Fgl()`** u jeziku izraza; `fglv:` izvor.
6. **Kontrole:** ComboBox, ListBox, OptionGroup, mreža (podforma), Chart i `RecordSource` izvješća prihvaćaju `fgl:`.
7. U Lazarusu: `TaDatabase`-ovisan izvor u `TaFormBinder` (polje i izračunato polje).

**Prihvaćanje:**
- Test: padajući popis puni 4GL funkcija s parametrom iz drugog polja; promjena polja osvježi popis.
- Test: mreža i grafikon iz `fgl:`; izvješće s `RecordSource = fgl:...` daje isti PDF kao ekvivalentni SQL.
- Test: `Fgl()` kao pravilo i kao izračunato polje.
- Test: prekoračenje vremena i broja redaka daje jasnu poruku, ne zamrzava program.
- Paritet: isti izvor u TyphAccess formi i u formi s `TaFormBinder` daje iste retke.

### Faza 2: kosturi (`.4glt`) i punjenje iz baze (2–3 dana)

**Cilj:** Z5. Biblioteka kostura koji se sami popune podacima.

**Format kostura** (tekstualna datoteka, mapa `skeletons/`, korisnik smije dodavati svoje):

```
@kostur  Popis s filtrom
@opis    Prikaz tablice u mreži s filtriranjem po bilo kojem polju (CONSTRUCT).
@kategorija  Popisi
@utor   tablica   : tablica                           "Koja tablica?"
@utor   stupci    : stupci(tablica)  zadano=sviOsimId "Koji stupci se prikazuju?"
@utor   naslov    : tekst            zadano={tablica} "Naslov prozora"
@preduvjet  tablica ima barem 2 stupca
@predlazi   tablica ima stupac tipa datum  =>  preporuči "Po razdobljima"
---
MAIN
  DEFINE kriterij TEXT
  CONSTRUCT kriterij ON {stupci} FROM {tablica}
  ...
  SELECT {stupci:lista} FROM {tablica} WHERE $kriterij
  ...
END MAIN
```

**Utori** imaju vrstu koja određuje i kako se pitaju i kako se pune:

| Vrsta utora | Punjenje iz baze | Primjer pitanja |
|---|---|---|
| `tablica` | popis korisničkih tablica | "Koja tablica?" |
| `stupac(tablica)` | stupci te tablice | "Po kojem stupcu grupirati?" |
| `stupci(tablica)` | višestruki izbor stupaca | "Koje stupce prikazati?" |
| `stupac:broj(t)`, `stupac:datum(t)`, `stupac:tekst(t)` | samo stupci tog tipa | "Koji iznos zbrajati?" |
| `veza(tablica)` | strani ključ i njegova ciljna tablica | "Koji je detalj ovog zapisa?" |
| `program`, `izvjesce`, `forma` | objekti iz baze | "Koje izvješće otvoriti?" |
| `tekst`, `broj`, `da/ne`, `izbor(a;b;c)` | slobodan unos | "Naslov prozora" |

**Prilagođavanje podacima:** engine kostura (`ta_skeleton`) čita metapodatke (`TableInfo`, `ForeignKeys`, tipovi), predloži zadane vrijednosti utora (sva polja osim `id`, prvi datum, prvi iznos), zamijeni `{utor}` u tekstu, i izgradi **pregled generiranog 4GL-a**. Generirani program je običan 4GL (nema skrivenih ovisnosti o kosturu).

**Početna biblioteka (12 kostura)**, iz postojećih recepata i SmartBet programa:

| Kostur | Utori | Temelji se na |
|---|---|---|
| Popis s filtrom | tablica, stupci | recept 2 |
| Unos i izmjena zapisa | tablica, stupci | `INPUT` |
| Master-detail | glavna tablica, detalj, veza | `veza(tablica)` |
| Zbroj po grupi | tablica, grupa, iznos | recept 9 |
| Zbroj po razdoblju | tablica, datum, iznos, razdoblje | recept 13 |
| Masovna izmjena s brojačem | tablica, stupac, izraz | recept 4 |
| Sljedeći broj dokumenta | tablica, stupac | recept 5 |
| Arhiviranje (kopiraj, obriši) | tablica, uvjet | recept 14 |
| Izvoz izvješća u PDF | izvješće, datoteka | `exportpdf` |
| Uvoz iz CSV | tablica, datoteka, preslikavanje stupaca | import |
| Poravnanje stavki | tablica stavki, izvor rezultata | SmartBet `poravnanje.4gl` |
| Izbornik programa | popis programa | recept 11 |

**Prihvaćanje:**
- Svaki kostur, primijenjen na barem 2 različite tablice, daje program koji **prođe `--check` i izvršava se** bez greške (automatski test).
- Generirani program daje isti rezultat kao rukom pisan ekvivalent iz recepta (paritet na zadanim bazama).
- Korisnik doda novi `.4glt` u mapu i on se pojavi u popisu bez ponovnog prevođenja.

### Faza 3: dva ulaza i čarobnjak (2 dana)

**Cilj:** Z6. Isti tok iz dva smjera, u oba okruženja.

- **Od kostura:** *Novi program iz kostura…* otvara popis po kategorijama; odabir pokreće pitanja utora s popisima iz baze; prikazuje se **pregled 4GL-a**; *Spremi* upisuje u bazu (`_sys_programs`) i/ili datoteku (vidi 8, odluka 2).
- **Od podataka:** na `TaDatabase` (desni klik) i u TyphAccess izborniku: *Predloži programe…*. Engine kostura pregleda tablicu i **rangira** kosture po prikladnosti, npr.:
  - tablica ima stupac datuma i iznosa → *Zbroj po razdoblju*;
  - ima strani ključ → *Master-detail*;
  - ima stupce `status` i datum → *Arhiviranje*;
  - ima pravilo ili izračun u metapodacima → *Provjera i ispravak*.
  Jednim klikom kostur se **sam popuni** (zadani utori), a korisnik samo potvrdi ili promijeni u pregledu.
- **Kontekstni prikaz:** ako je forma otvorena i u njoj odabrana kontrola, čarobnjak predlaže kosture koji joj odgovaraju (npr. za gumb: radnje; za padajući popis: izvor retka).

**Prihvaćanje:** od prazne SQLite baze s 3 tablice do 5 radnih programa (popis, unos, zbroj, izvoz, arhiva) **u najviše 15 klikova**, bez tipkanja 4GL-a (provjera snimkama zaslona i brojanjem koraka u testu).

### Faza 4: vizualno programiranje (blokovi) (3 dana)

**Cilj:** programiranje uglavnom mišem. Temelji se na postojećem blokovskom uređivaču (`ta_blockedit`, `ta_blocks`, `ta_fglblocks`).

- **Paleta blokova** uz kosture: *Otvori tablicu*, *Za svaki redak*, *Ako*, *Postavi varijablu*, *Upiši u tablicu*, *Pitaj korisnika*, *Prikaži*, *Pokreni izvješće*, *Izvezi PDF*, *Pozovi program*, *Otvori formu*, *Vrati redak (EMIT)*, *Vrati vrijednost*.
- **Polja blokova su padajući popisi iz baze:** tablica, stupac (samo tipa koji blok traži), program, izvješće, forma, varijabla.
- **Dvosmjerno:** blokovi ↔ 4GL tekst (već provjereno za podskup; širimo na sve nove naredbe i na `COLUMNS`/`EMIT`).
- **Kostur se otvara u blokovima:** nakon čarobnjaka korisnik može izravno prilagoditi (dodati blok, maknuti uvjet).
- **Pogreške pokazuju na blok** (ne samo na redak teksta).
- `ON SAVE` blok za izvore koji se mogu uređivati (mreža iz `fgl:` s izmjenom).

**Prihvaćanje:** zadatak "popis partnera s filtrom po gradu, s gumbom koji izvozi PDF" složen **samo blokovima i izborima iz baze**, bez tipkanja riječi 4GL-a; isti program otvoren kao tekst daje ispravan 4GL.

### Faza 5: dijalozi u oba okruženja (3 dana)

**Cilj:** Z2. Svi dijalozi iz poglavlja 5 postoje i rade na dva mjesta.

- `EditSource`, `EditAction`, `EditFormat`, `EditCondFormat`, `EditRule`, `EditExpression` u sloju B.
- Property editori i component editori u `typhaccess_dsgn`.
- Dizajner TyphAccessa prelazi na iste funkcije (zamjena postojećih dijaloga bez promjene izgleda).
- Dvoklik na `TaProgram` → uređivač (tekst / blokovi / kosturi); dvoklik na `TaReport` → izbor izvješća i parametri; dvoklik na `TaDatabase` → test veze i *Predloži programe…*.

**Prihvaćanje:** isti niz radnji (npr. *postavi izvor padajućeg popisa na 4GL funkciju*, *postavi radnju gumba*, *postavi uvjetno oblikovanje*) proveden u IDE-u i u dizajneru daje **identičnu vrijednost svojstva** (provjera usporedbom zapisa).

### Faza 6: zajednički stroj ponašanja i paritet (4–5 dana)

**Cilj:** Z1. Ponašanje identično jer je isti kod.

- Izdvojiti `TaBindingEngine` iz `TaFormRunner`; `TaFormBinder` i `TaFormRunner` postaju adapteri.
- Svojstva po ugovoru (4.1), `TaPropMap`, svojstva objavljena na osnovnim kontrolama.
- **Paritetni test-skup:** definicije formi (po 20) izvršene preko runnera i preko binder-a nad istim podacima; uspoređuje se skup (vrijednost, boja, vidljivost, omogućenost, odbijen Post, poruka). Razlika = neuspjeh.
- Usporedba offscreen snimaka za reprezentativne forme (4.3).

**Prihvaćanje:** 0 razlika u paritetnom skupu; smoke test 0 grešaka; sve postojeće aplikacije rade isto.

### Faza 7: ostale kontrole i proširenja (5+ dana)

- Preostale kontrole na kanonski način: Chart, Barcode, TabControl, Subform (s izvorom iz `fgl:`).
- `typhaccess_ext`: kontrole nad JVCL/RX s istim sučeljem.
- Kasnije (nije u opsegu sada): prenosivost forme JSON ↔ `.lfm`; čarobnjak *Nova TyphAccess aplikacija* i *Nova forma nad tablicom* za IDE; bazna forma `TaDataForm`.

---

## 7. Provjera i kontrola kvalitete

| Vrsta | Kako | Gdje |
|---|---|---|
| Smoke test | postojeći `tools/smoke.sh`, svaka faza dodaje provjere | `tests/smoke.pas` |
| Kosturi | automatski: svaki kostur × barem 2 tablice → `--check` i izvršenje | `tests/skeletons/` |
| Izvori podataka | usporedba `fgl:` rezultata s ekvivalentnim SQL-om | smoke |
| Paritet ponašanja | ista definicija kroz runner i binder (6.6) | `tests/parity/` |
| Izgled | offscreen PNG usporedba reprezentativnih formi | `tests/shots/` |
| Dijalozi | niz radnji u oba okruženja → isti zapis svojstva | smoke + skripta |
| Unatrag kompatibilnost | postojeće aplikacije (SmartBetTA, Trgovina Jadran) prolaze nepromijenjene | smoke + deploy skripta |
| Deploy | `izradi_deploy.sh` i `--run` programa iz baze nakon svake faze | `SmartBetTA/` |

---

## 8. Odluke koje treba donijeti

| # | Pitanje | Moja preporuka | Posljedica |
|---|---|---|---|
| 1 | Kosturi: kod ili datoteke? | **datoteke** `.4glt` u mapi, uz ugrađeni zadani skup | korisnik dodaje svoje bez prevođenja |
| 2 | Gdje se sprema generirani 4GL? | **baza** (`_sys_programs`), uz izbor *i u datoteku* | TyphAccess ga već čita iz baze; u CodeTyphonu datoteka uz projekt |
| 3 | JVCL/RX u runtimeu? | **ne**, samo u neobaveznom `typhaccess_ext` | "light" ostaje malen |
| 4 | Uređivanje iz `fgl:` izvora | **samo čitanje** u prvoj fazi, `ON SAVE` u fazi 4 | manji rizik |
| 5 | Redoslijed: 4GL prvo ili stroj prvo? | **4GL prvo** (faze 1–5), stroj ponašanja nakon (faza 6) | brži vidljivi rezultat; stroj je veća preinaka. Ako je identičnost važnija, zamijeniti redoslijed 5 i 6 |
| 6 | Ime formata kostura i mape | `.4glt`, mapa `skeletons/` uz program i uz bazu | jedinstveno, lako se otkriva |
| 7 | Ograničenja izvora (vrijeme, redci) | 5 s, 100 000 redaka, postavke | zaštita sučelja |

---

## 9. Rizici

| Rizik | Vjerojatnost | Ublažavanje |
|---|---|---|
| Izdvajanje stroja iz `TaFormRunner` (3171 redak) može razbiti postojeće forme | srednja | paritetni testovi **prije** preinake (snimiti sadašnje ponašanje), postupno prebacivanje po svojstvu |
| `fgl:` izvori usporavaju formu (izvršenje pri svakom pomaku zapisa) | srednja | predmemorija po parametrima, requery samo kad se parametar promijeni, ograničenje vremena |
| Dijalozi u IDE-u i u dizajneru se razlikuju zbog drukčijeg konteksta | niska | sučelje `TaEditContext`, isti dijalog iz sloja B |
| JVCL/RX kontrole na Qt6 se ponašaju drukčije od LCL | srednja | samo u neobaveznom paketu, posebni testovi (spike postoji) |
| Format kostura prerano zamrznut | srednja | verzija formata u zaglavlju (`@format 1`); parser tolerantan na nepoznate direktive |
| Opseg: lako je podcijeniti | visoka | faze su samostalne; nakon svake demo i odluka o nastavku |

---

## 10. Pregled po danima (prvi krug)

| Dan | Posao | Rezultat koji se može pokazati |
|---|---|---|
| 1 | Faza 0: razdvajanje paketa; počinje faza 1 (`COLUMNS`/`EMIT`) | paketi se prevode; prvi program koji vraća retke |
| 2 | Faza 1: `TaFglDataSet`, `OpenSource`, parametri | padajući popis iz 4GL funkcije |
| 3 | Faza 1: `Fgl()`, mreža i grafikon iz `fgl:`, izvješće | testovi izvora zeleni |
| 4 | Faza 2: format kostura, engine, prvih 6 kostura | kostur → program koji radi |
| 5 | Faza 2: preostalih 6 kostura, testovi nad 2 tablice | automatski test svih kostura |
| 6 | Faza 3: ulaz od kostura i od podataka, pregled | iz prazne baze do 5 programa u 15 klikova |
| 7 | Faza 4: blokovi s popisima iz baze | program sastavljen samo mišem |
| 8–9 | Faza 4: `ON SAVE`, pogreške na blokovima; Faza 5: `EditSource`, `EditAction` | isti dijalozi u IDE-u i dizajneru |
| 10–11 | Faza 5: ostali dijalozi, component editori | usporedba zapisa svojstava u oba okruženja |
| 12–16 | Faza 6: zajednički stroj i paritet | 0 razlika u paritetnom skupu |
| 17+ | Faza 7 | ostale kontrole, `typhaccess_ext` |

Prvi pogled "radi" (`fgl:` izvor, kosturi, čarobnjak) je oko **dana 6**; potpuna identičnost komponenti (faza 6) je realno tjedan do dva poslije toga.

---

## 11. Rječnik

| Pojam | Značenje |
|---|---|
| **Kostur** | `.4glt`: 4GL s tipiziranim utorima koji se pune iz baze |
| **Utor** | mjesto u kosturu koje se popunjava (tablica, stupac, izraz, program...) |
| **Izvor** (`TaSourceDef`) | tekst koji kaže odakle kontrola uzima podatke: tablica, SQL, izraz, popis ili 4GL |
| **`fgl:`** | izvor koji pokreće 4GL program i uzima njegove retke |
| **`fglv:` / `Fgl()`** | 4GL funkcija koja vraća jednu vrijednost |
| **Sloj A / B / C** | jezgra / dijalozi i čarobnjaci / sučelja (IDE i dizajner) |
| **Light** | TyphAccess dizajner i runtime bez CodeTyphona |
| **`TaBindingEngine`** | zajednički stroj ponašanja (izrazi, pravila, boje, vidljivost) |

---

## 12. Primjer koji ilustrira načelo: uređivač sidrenja (već izrađen)

Lazarusov *Anchor Editor* je primjer dijaloga koji u IDE-u postoji, a u TyphAccessu nije postojao (sidra uz susjede i razmaci tipkali su se kao tekst `Naziv:strana`). Izrađen je kao dijalog sloja B (`src/gui/ta_anchoreditor.pas`, commit `7d0a99a`):

- jedna funkcija `RunLayoutDialog(vlasnik, definicija forme, definicija kontrole, vrijednosti)` uređuje `Anchors`, `Dock`, `BorderSpacing` i sidra `AnchorLeft/Top/Right/Bottom`;
- zapis u definiciji je isti kao prije, pa stare forme rade nepromijenjene;
- dizajner TyphAccessa ga zove s gumba **…** na tim svojstvima; u CodeTyphonu isti dijalog se spaja kao `TPropertyEditor` bez izmjena (načelo iz poglavlja 5);
- ima probne testove bez prozora (čitanje, izmjena, obrasci, razmaci, Dock, crtanje pregleda).

Svaki sljedeći dijalog (`EditSource`, `EditAction`, `EditFormat`...) slijedi isti uzorak.

---

## 13. Dopuna: mala paleta univerzalnih kontrola

Odluka korisnika (2026-11-07): umjesto velikog broja kontrola iz JVCL/RX/KControls/BGRA, paleta ima **10 do 20 obitelji kontrola**, a ostalo su **varijante** koje se biraju padajućim izbornikom (npr. polje postaje padajući popis, jedan gumb s opcijama). Plan je u `PLAN-univerzalne-kontrole.md`. Ovo mijenja poglavlje 4.4: JVCL/RX nisu zasebna stranica palete, nego neobavezni pokretači varijanti.
