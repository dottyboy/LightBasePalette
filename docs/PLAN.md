# TyphAccess: jedinstveni plan palete, teme, 4GL-a i Light IDE-a

Verzija: 2026-11-07. **Ovo je jedini plan.** Zamjenjuje četiri ranija dokumenta, koji su premješteni u `docs/arhiva/` (vidi poglavlje 18). Popis komponenti i usporedba s Typhon bibliotekama ostaje u `POPIS-KOMPONENTI.md` (inventar, ne plan).

Stanje koda na koje se plan oslanja: TyphAccess commit `96c970a` i kasniji (palete: `TaSideMenu`, `TaDatabase`, `TaExpression`, `TaReport`, `TaProgram`, `TaFormBinder`, uređivač sidrenja `ta_anchoreditor`). Razvoj je namjerno odgođen; plan se izvodi tek kad korisnik kaže.

---

## 0. Sažetak

1. **Dva načina rada, ista paleta:** puni **CodeTyphon/Lazarus** (paleta u IDE-u) i **TyphAccess "light"** (naš dizajner i runtime). Komponente izgledaju i ponašaju se **identično** jer je kod jedan (`typhaccess_core`).
2. **Mala paleta:** **17 obitelji kontrola** (umjesto stotina iz LCL/JVCL/RX/KControls/BGRA) s padajućim izbornikom **varijante**, plus **7 nevizualnih komponenti**, na 4 stranice palete.
3. **Pokretači:** svaka obitelj ima zadani pokretač nad LCL-om; **`TRxDBGrid`**, **`TAChart`** i **SynEdit** su zadani pokretači Grida, Charta i Editora. Ostale biblioteke su neobavezni pokretači ili odbijene.
4. **Jedna tema:** tokeni (boje, oblik, razmaci, font) u JSON-u; cijela tema se izvodi iz **jednog naglaska**; zadani stil **`rounded`**, font **JetBrains Mono**; svijetla i tamna varijanta.
5. **Izvor podataka** svake kontrole može biti tablica, SQL, izraz, popis ili **rezultat 4GL programa** (`TaSourceDef`).
6. **4GL** dobiva naredbe `COLUMNS`/`EMIT`, vraćanje vrijednosti i funkciju `Fgl()`.
7. **Kosturi** (`.4glt`): 4GL s tipiziranim utorima koji se sami popune podacima iz baze; **dva ulaza** (od kostura, od podataka) i **vizualno programiranje** blokovima.
8. **Isti dijalozi i čarobnjaci u oba okruženja** (sloj `editori`, pisan jednom).
9. **Light IDE** ("Typhon Light"): stupanj 1 je profil CodeTyphona samo s našom paletom; ostali stupnjevi tek kad se pokaže potreba.
10. Rad ide u **etapama koje su svaka sama korisna**; ukupno oko **60 radnih dana** (12 tjedana), prvi vidljivi rezultat u prvom tjednu.

### 0.1 Odluke korisnika (zatvorene)

| # | Odluka |
|---|---|
| 1 | **17 obitelji** potvrđeno |
| 2 | **Grid = `TRxDBGrid`** (zadani): bojanje redova i ćelija, unos podataka izravno u mrežu (npr. stavke računa) |
| 3 | **Chart = `TAChart`** (zadani); vlastito crtanje samo za izvješća, PDF i HTML |
| 4 | **`TPageControl`** ostaje pokretač Pages; **gumbi i tabovi se prilagođavaju** (oblik) |
| 5 | Zadani stil oblika **`rounded`**; **`pill`** kasnije kao opcija; `square` uz `rounded` u prvoj fazi |
| 6 | Boja teme prati dijelove kontrola (zelena tema: zeleni gumb na Combo-u; crvena: crveni) |
| 7 | **Tema kao JSON** (korisnik dodaje vlastitu) |
| 8 | **Font: samo JetBrains Mono** za sada |
| 9 | **Gustoća** (kompaktno/normalno/prostrano): kasnije |
| 10 | **SynEdit** se koristi (obitelj Editor) |
| 11 | **Oracle Forms / Developer 2000 kao inspiracija** (poglavlje 19): blok, događaji i procedure, upit po formi, `lov`, klase svojstava, biblioteka objekata, tipkovnički standard; hrvatska imena procedura uz engleske sinonime |

### 0.2 Odluke iz poglavlja 17

Sve odluke iz poglavlja 17 su zatvorene (kosturi kao datoteke; generirani 4GL i u bazi i u datoteci; forma i JSON i `.lfm`; Light IDE stupanj 1).

---

## 1. Ciljevi i ograničenja

### 1.1 Što korisnik treba moći

| # | Zahtjev | Posljedica za izvedbu |
|---|---|---|
| Z1 | Ista komponenta u CodeTyphonu i u TyphAccessu: isti izgled, isto ponašanje | jedan kod (`typhaccess_core`), paritetni testovi |
| Z2 | Isti dijalozi, čarobnjaci i klik-uređivanja u oba okruženja | sloj `editori` neovisan o IDE-u |
| Z3 | Kontrola koja može koristiti 4GL, neka ga koristi | 4GL kao izvor podataka, izračun, radnja, pravilo |
| Z4 | Izvor polja može biti SQL, a isto tako i rezultat 4GL-a | `TaSourceDef` |
| Z5 | Vizualno programiranje: kosturi koji se prilagode podacima | biblioteka kostura, punjenje iz metapodataka |
| Z6 | Dva ulaza: od kostura ili od podataka | dva čarobnjaka nad istim kosturima |
| Z7 | Korisnik smije koristiti samo "light" (TyphAccess) ili samo naš lagani IDE, bez punog CodeTyphona | TyphAccess ne ovisi o IDE-u; paleta ovisi o TyphAccessu, ne obrnuto |
| Z8 | Mala paleta umjesto tisuću kontrola; sve funkcije punog sustava kroz varijante | obitelji + pokretači |
| Z9 | Sve kontrole izgledaju skladno | jedinstvena tema (poglavlje 6) |
| Z10 | Forma se može spremiti i kao JSON (baza) i kao `.lfm` | dvosmjerna pretvorba (poglavlje 17.1) |

### 1.2 Ograničenja

- **Qt6** je ciljni widgetset (CodeTyphon, `--ws=qt6`).
- Ovisnosti runtimea ostaju male: Zeos, PascalScript, fpspreadsheet, RichMemo, Image32; uz odluke iz 0.1 u runtime ulaze i **RX (`TRxDBGrid`)**, **TAChart** i **SynEdit**. Veličinu binarne datoteke treba izmjeriti (cilj: porast manji od 3 MB za SynEdit).
- Nijedna promjena ne smije slomiti postojeće aplikacije (SmartBetTA, `Trgovina Jadran`, katalog). Svaka promjena formata je **unatrag kompatibilna**.
- **Smoke test** (oko 1700 provjera) mora prolaziti bez ijedne greške nakon svake etape.

---

## 2. Arhitektura: tri sloja, jedan izvor istine

```
┌──────────────────────────────────────────────────────────────────────────┐
│  Sloj C: sučelja prema korisniku                                          │
│  ┌─────────────────────────────┐    ┌──────────────────────────────────┐  │
│  │ CodeTyphon / Lazarus IDE    │    │ TyphAccess "light"               │  │
│  │ (ili Light IDE)             │    │ dizajner formi, izvješća, 4GL,   │  │
│  │ paleta, property editori,   │    │ runtime                          │  │
│  │ component editori           │    │                                  │  │
│  └──────────────┬──────────────┘    └──────────────┬───────────────────┘  │
├─────────────────┼──────────────────────────────────┼─────────────────────┤
│  Sloj B: editori (dijalozi i čarobnjaci, napisani JEDNOM)                │
│  EditAction, EditSource, EditFormat, EditCondFormat, EditRule,           │
│  PickTable/Column, SkeletonWizard, BlockEditor, ProgramEditor, Theme     │
├──────────────────────────────────────────────────────────────────────────┤
│  Sloj A: jezgra (typhaccess_core)                                        │
│  TaDatabase, izrazi, 4GL (interpreter + kosturi), izvori (TaSourceDef),  │
│  stroj ponašanja (TaBindingEngine), tema (TaTheme), izvješća,            │
│  obitelji kontrola i njihovi pokretači                                   │
└──────────────────────────────────────────────────────────────────────────┘
```

**Pravila ovisnosti:** A ne ovisi ni o čemu iznad sebe. B ovisi o A i LCL-u. C ovisi o B i A (IDE paket dodatno o `bs_IDEIntf`). "Light" varijanta treba samo A + B + vlastiti dizajner. **Posljedica za Z1/Z2:** logika i dijalozi su u A i B, a C ih samo stavlja na mjesto, pa se okruženja ne mogu razići u ponašanju, samo u načinu pozivanja.

### 2.1 Paketi i izvorne mape

| Paket / mapa | Sadržaj | Ovisi o |
|---|---|---|
| `typhaccess_core` (`src/core`, dio `src/gui`) | sloj A | Zeos, PascalScript, fpspreadsheet, RichMemo, Image32, SynEdit, TAChart, RX, LCL |
| `typhaccess_editors` (`src/editors`, novo) | sloj B | `typhaccess_core`, LCL |
| `typhaccess_dsgn` (`lazarus/`) | paleta, registracija, property i component editori | `typhaccess_core`, `typhaccess_editors`, `bs_IDEIntf` |
| `typhaccess_ext` (`lazarus/ext`, novo, neobavezno) | neobavezni pokretači (JVCL, VirtualTrees, HtmlViewer, KControls, ECControls, Ribbon) | `typhaccess_dsgn` i dotični paketi |
| aplikacija `TyphAccess` | dizajner + runtime ("light") | `typhaccess_core`, `typhaccess_editors` |

Danas je `typhaccess_dsgn` jedini paket i uključuje izvore putanjom; etapa 0 to razdvaja bez promjene ponašanja.

---

## 3. Paleta: 17 obitelji, varijante, pokretači

### 3.1 Načelo obitelji i varijante

**Obitelj** je jedna kontrola u paleti s više **varijanti**. Varijanta mijenja ponašanje i izgled, a zajednička svojstva (izvor podataka, pravila, uvjetno oblikovanje, radnje, oblik) ostaju ista kroz sve varijante i rade preko istog stroja ponašanja. Tekstno polje postaje padajući popis kad mu se postavi `Variant = combo`; jedan gumb s opcijama zamjenjuje pedeset vrsta gumba. Pravilo: **nova varijanta samo ako se razlikuje po ponašanju**, a razlika samo u izgledu ide u temu.

Prednosti: korisnik uči jednu kontrolu po obitelji; promjena ideje je promjena jednog svojstva uz zadržane veze, pravila i događaje; ista sučelja u CodeTyphonu i u TyphAccessu.

### 3.2 Konačna paleta (4 stranice)

**Skupina "Podaci"** (od 2026-11-11 sve skupine su na jednoj stranici palete *TyphAccess*)

| Obitelj | Varijante | Zadani pokretač | Neobavezni |
|---|---|---|---|
| **Edit** | text, password, mask, spin, date, time, currency, search, combo, droplist, lookup | `TEdit`, `TMaskEdit`, `TFloatSpinEdit`, `TDateEdit`, `TComboBox` | RX (`TRxDBCurrEdit`, `TRxDBDateEdit`, `TRxDBLookupCombo`), JVCL (`TJvxCurrencyEdit`, `TJvCalcEdit`) |
| **Memo** | plain, rich, markdown | `TMemo`; rich: `TRichMemo` | `TKMemo` (KControls) |
| **Check** | checkbox, switch, radio, tri-state | `TCheckBox`, `TRadioButton`; switch vlastito crtanje | — |
| **Choice** | radio group, check group, segmented | `TRadioGroup`, `TCheckGroup`; segmented vlastito | — |
| **List** | list, checklist, icon list, tree | `TListBox`, `TCheckListBox`, `TListView`, `TTreeView` | `TVirtualStringTree` za velike popise |
| **Grid** | read-only, editable, datasheet, footer-sum, filter row, **entry** | **`TRxDBGrid`** | `TDBGrid` samo kao rezervni pokretač |
| **Calendar** | month, range, agenda | `TCalendar`, `TDateTimePicker` (`lz_DateTimeCtrls`) | — |

**Skupina "Prikaz"**

| Obitelj | Varijante | Zadani pokretač | Neobavezni |
|---|---|---|---|
| **Label** | text, hyperlink, html, badge | `TLabel`; html: naš podskup (`ta_richtext`) | `THtmlViewer` |
| **Image** | picture, shape, gradient, svg/icon | `TImage`, `TShape`; SVG preko Image32 | — |
| **Chart** | bar, line, pie, gauge, area, scatter | **`TAChart`** | vlastito crtanje (`TaChart`) samo za izvješća, PDF, HTML |
| **Barcode** | code128, ean13/8, code39, itf, qr, pdf417, HUB-3 | vlastito (`ta_barcode`, `ta_pdf417`, FCL `fpbarcode`/`fpqrcodegen`) | — |
| **Progress** | bar, ring, led, busy | `TProgressBar`; ring i led vlastito | `TECProgressBar` |

**Skupina "Raspored i navigacija"**

| Obitelj | Varijante | Zadani pokretač | Neobavezni |
|---|---|---|---|
| **Button** | standard, flat, toggle, image, link, menu, split, default, cancel | `TBitBtn`, `TSpeedButton`, `TToggleBox` + stil oblika | — |
| **Panel** | plain, group, card, scroll, expander, splitter | `TPanel`, `TGroupBox`, `TScrollBox`, `TSplitter`; card/expander vlastito | `TECAccordion` |
| **Pages** | tabs, page list, steps, accordion | **`TPageControl`** + stil oblika; radni prostor `TaTabBar` | — |
| **Menu** | side menu, toolbar, tree menu | **`TaSideMenu`** (naš, po uzoru na TJvXPBar), `TToolBar`, `TMainMenu` | `TSpkToolbar` (Ribbon) |

**Skupina "Logika i uređivači"**

| Komponenta | Vrsta | Što radi |
|---|---|---|
| **Editor** | vizualna obitelj | uređivač koda: `4gl`, `sql`, `expression`, `pascal`, `json`, `text`; pokretač **SynEdit** (poglavlje 5) |
| `TaDatabase` | nevizualna | baza (SQLite/PostgreSQL/MariaDB), objekti aplikacije, postavke |
| `TaExpression` | nevizualna | računanje izraza |
| `TaFormBinder` | nevizualna | izračun, pravila, boje, vidljivost na bilo kojoj kontroli |
| `TaReport` | nevizualna | izvješće: pregled, PDF, HTML |
| `TaProgram` | nevizualna | 4GL program iz baze ili teksta |
| `TaSource` | nevizualna, **nova** | izvor podataka (tablica, SQL, izraz, popis, 4GL) daje `TDataSet` svim obiteljima |
| `TaTheme` | nevizualna, **nova** | tema aplikacije: svijetla/tamna, naglasak, oblik, prebojavanje |

**Ukupno:** 17 vizualnih obitelji (7 + 5 + 4 + Editor) i 7 nevizualnih komponenti (`TaDatabase`, `TaExpression`, `TaFormBinder`, `TaReport`, `TaProgram`, `TaSource`, `TaTheme`). Zbog Editora, stari broj "16 obitelji" više ne vrijedi; stari "Code" (barkod) preimenovan je u **Barcode**, a varijanta Memo `code` zamijenjena je obitelji Editor.

### 3.3 Odabir varijante

- **CodeTyphon/Lazarus:** objavljeno svojstvo `Variant` (padajući popis); kontekstni izbornik "Prikaži kao ▸". Svojstva koja ovise o varijanti dolaze u **podobjektu `Options`** čija klasa ovisi o varijanti (`TaComboOptions`, `TaDateOptions`...), pa Inspektor pokazuje samo ono što varijanta ima.
- **Dizajner TyphAccessa:** isti padajući popis na vrhu popisa svojstava i isti kontekstni izbornik.
- **Promjena varijante čuva** zajednička svojstva i vrijednosti; svojstva koja nova varijanta nema ostaju zapamćena u definiciji.

### 3.4 Izvedba: obitelj nad pokretačem (host)

```
TaEdit (TWinControl)                     ← klasa obitelji, objavljena svojstva, zajednički API
   └─ FEngine: IaEngine                  ← pokretač varijante (zamjenjiv)
        ├─ TaLclEditEngine   (TEdit / TComboBox / TSpinEdit ...)   ← uvijek dostupan
        ├─ TaRxEditEngine    (TRxDBDateEdit, TRxDBLookupCombo ...) ← RX
        └─ TaJvclEditEngine  (TJvCalcEdit, TJvxCurrencyEdit ...)   ← neobavezni paket
```

- Obitelj je **domaćin**: drži stvarnu kontrolu kao dijete i prosljeđuje fokus, Tab, Anchors, Font, Color i događaje. Pri promjeni varijante pokretač se zamijeni.
- **Registar** `TaEngineRegistry` zna koji pokretači postoje; za varijantu bira prvi dostupan (zadano LCL; po želji RX/JVCL). Program bez neobaveznih paketa radi s LCL pokretačima bez ikakve promjene definicije.
- **Sučelje pokretača** `IaEngine`: `Value` (Variant), `Text`, `ReadOnly`, `SetItems`, `SetFormat`, `OnChange`, `DataBind(DataSource, Field)`. Zbog toga `TaBindingEngine` radi isto bez obzira na pokretač.
- **Podaci:** obitelj prihvaća `TaSourceDef` (poglavlje 7).
- Alternativa ako domaćin zapne (fokus, dizajnerske ručke, tabulatori): jedna klasa nad `TCustomComboBox` s prepravljenim stilovima. **Prototip Edit odlučuje.**

### 3.5 Veza s postojećim TyphAccessom

- `TaControlDef.Kind` ostaje (npr. `ComboBox`) kao **alias** za `Edit` + varijanta `combo`; novi zapisi pišu `Kind = Edit`, `variant = combo`. Postojeće aplikacije učitavaju se nepromijenjene.
- Dizajner: na paleti ostaje 17 obitelji; izbor varijante je u popisu svojstava. `TaFormRunner` stvara obitelj i postavlja varijantu, pa ponašanje ide kroz isti stroj kao u IDE-u.

### 3.6 Grid: `TRxDBGrid` kao zadani pokretač

Napredniji od `TDBGrid`: podnožje sa zbrojevima, filtri u zaglavlju, izvoz u PDF/tablicu, ispis. Obavezno:

1. **Bojanje redova i ćelija** po pravilu (`CondFormat` iz `TaFormBinder`, semantičke boje iz teme, naizmjenični redovi).
2. **Unos izravno u mrežu** (varijanta `entry`), npr. **forma računa za unos stavki**: novi red na dnu, Tab/Enter na iduću ćeliju, padajući izbor artikla (lookup), automatski izračun iznosa retka i zbroj u podnožju, brisanje retka, pravila po ćeliji. Veza glavna/detalj ostaje svojstvo (zamjenjuje `TaSubform`).
3. Izvor retka: tablica, SQL ili `fgl:` (samo čitanje u prvoj fazi, `ON SAVE` kasnije).

### 3.7 Gumbi i kartice: prilagodba oblika

`TBitBtn`/`TSpeedButton` i `TPageControl` ostaju pokretači (ponašanje, tipkovnica, dizajner), a izgled preuzima QSS ili tanki `TaButtonPainter`/`TaTabPainter` ako QSS nije dovoljan (npr. oblik pilule s ikonom i znakom zatvaranja). Oblik određuje token `shape` (poglavlje 6.5).

---

## 4. Izbor biblioteka

### 4.1 Mjerila (kontrola ulazi samo ako ispuni sva)

| # | Mjerilo | Provjera |
|---|---|---|
| M1 | Radi na Qt6 | probni projekt (kao `tests/jvspike`): stvaranje, veza na bazu, crtanje, unos, zatvaranje bez pada |
| M2 | Uklapa se u temu | boje i fontove prima iz QSS-a ili tokena; snimka u svijetloj i tamnoj temi izgleda kao ostatak programa |
| M3 | Veže se na podatke | ima `DataSource`/`DataField` ili je `TaFormBinder` može vezati (RTTI) |
| M4 | Ne udvostručuje | ne dodaje drugo ime za istu funkciju |
| M5 | Licenca i održavanje | licenca dopušta uporabu; paket je u CodeTyphonu i prevodi se bez zakrpa |

Nove biblioteke: prvo M1 probnim projektom, zatim M2 snimkom u obje teme, tek onda u tablicu odluka.

### 4.2 Odluke

| Biblioteka (paket) | Odluka | Što uzimamo / zašto ne |
|---|---|---|
| **LCL** (`adLCL`) | **Zadano** | osnova svih obitelji; QSS stilizira sve što crta Qt |
| **SynEdit** (`BaseSynedit`, `lz_SynEditExtra`, `lz_SynUni`) | **Zadano** (Editor) | bojenje, brojevi redaka, sklapanje, dopuna; nema ekvivalenta u LCL-u |
| **Zeos** (`pl_ZeosDBO`) | **Zadano** | baza |
| **RX** (`pl_RX`) | **Zadano za Grid** (`TRxDBGrid`); neobavezno za Edit | podnožje, filtri, izvoz; testirano na Qt6 |
| **TAChart** (`lz_taChart`) | **Zadano** (Chart) | bogatiji od našeg; adapter preslikava tokene u boje, osi, font |
| **JVCL** (`pl_JVCL`) | **Neobavezno, usko** | samo `TJvxCurrencyEdit`/`TJvCalcEdit` ako RX nije dovoljan; ostalo odbijeno (udvostručuje, XP izgled) |
| **KControls** (`pl_KControls`) | **Neobavezno, usko** | `TKMemo` kao bogati urednik; `KGrid`, `KHexEditor` odbijeno |
| **ECControls** (`pl_ECControls`) | **Neobavezno, usko** | `TECProgressBar`, `TECAccordion`; ostalo duplira LCL |
| **VirtualTrees** (`pl_VirtualTrees`) | **Neobavezno** (List "veliki popis") | brzo crtanje stotina tisuća redaka |
| **HtmlViewer** (`pl_HtmlViewer`) | **Neobavezno** (Label html) | puni HTML; zadano je naš podskup |
| **SpkToolBar** (Ribbon) | **Neobavezno** | samo za Office izgled; mijenja izgled pa nije zadano |
| **BGRAControls** | **Odbijeno** | vlastiti iscrtani izgled ne prati QSS (moglo bi samo kroz `TBCDefaultThemeManager`, zaseban posao) |
| **ExtTabCtrl** | **Odbijeno** | imamo `TaTabBar` (Qt6 ne crta tipke zatvaranja na karticama) |
| **LazReport, FpReport, FortesReport** | **Odbijeno** | vlastiti motor izvješća (isti izlaz za pregled, PDF, HTML) |
| **pl_Barcodes, ZXing, QRCodeGen** | **Odbijeno** za crtanje | vlastito i FCL kodiranje; ZXing zanimljiv kasnije za *čitanje* |
| **LuiControls, MiniControls, Orpheus, UserControl** | **Odbijeno** | nema jasne koristi |
| **Indy, Synapse, mORMot, WebUI, CEF** | **Odbijeno** | izvan opsega palete |

**Zašto ne uzeti JVCL/RX/KControls/BGRA kao osnovu svega:** iste ideje u različitim imenima i s različitim greškama; ne rade sve ispravno na Qt6; nema jedinstvenog svojstvenog sučelja; runtime "light" ovisio bi o velikim paketima. Ako korisnik u CodeTyphonu ipak baci čistu JVCL/RX kontrolu, `TaFormBinder` radi s njom (već izrađeno).

---

## 5. Obitelj Editor (SynEdit)

### 5.1 Zašto

Uređivači 4GL-a, SQL-a, izraza i PascalScript modula danas su `TMemo`. SynEdit daje: bojenje sintakse, brojeve redaka, **sklapanje blokova** (`MAIN`…`END MAIN`, `IF`…`END IF`), **dopunu koda iz baze** (tablice, stupci, funkcije, programi), **oznake grešaka u rubu** (`redak:stupac` iz parsera, valovita crta i ikona), pretragu s regularnim izrazima, višestruke kursore, komentiranje bloka i **predloške** (kosturi `.4glt` kao snippeti).

### 5.2 Varijante i bojenje

| Varijanta | Bojenje | Dopuna koda |
|---|---|---|
| `4gl` | **novo**: `TSynCustomHighlighter` nad ključnim riječima iz `ta_fgl` | tablice i stupci, funkcije izraza, nazivi programa i izvješća, varijable programa; sklapanje po `MAIN`/`FUNCTION`/`IF`/`WHILE`/`FOR` |
| `sql` | gotovo (`SynHighlighterSQL`) uz naše funkcije | tablice, stupci, `[?Parametar]` |
| `expression` | **novo**: polja `[ime]`, funkcije, nizovi | polja izvora, funkcije jezika izraza; jednoredni način za svojstva |
| `pascal` | gotovo (`SynHighlighterPas`) | procedure modula |
| `json`, `text` | gotovo | — |

### 5.3 Veza s ostatkom plana

- Blokovski uređivač ostaje kao drugi prikaz istog programa (prekidač **Blokovi / Tekst**); tekstni prikaz postaje Editor.
- Greške parsera (`datoteka:redak:stupac: poruka`) postaju oznake u rubu; klik skače na redak.
- Kosturi `.4glt` dolaze kao predlošci dopune (`rec` + Tab).
- Svojstva s izrazima (`VisibleIf`, `Rule`, `CondFormat`) otvaraju jednoredni Editor varijante `expression`.

### 5.4 Rizici

Binarna datoteka raste (mjeriti prije odluke); boje bojenja i oznaka moraju slijediti temu (adapter iz tokena, tamna varijanta). SynEdit ima vlastite atribute pa ih treba preslikati.

---

## 6. Jedinstvena grafička tema

### 6.1 Stanje danas

`ta_theme.pas` primjenjuje **Qt stilsku tablicu (QSS)** s devet vrijednosti (`Bg`, `Fg`, `Border`, `Soft`, `Accent`, `AccentSoft`, `Header`, `Input`, `Tip`) za svijetlu (`thModern`) i tamnu (`thModernDark`) varijantu, a `RecolorForm` prebojava što Qt ne crta. `TaSideMenu` ima vlastitu paletu istog naglaska (`#2563EB`), `TaChart` vlastitih 8 boja serija, ikone su zaseban skup (`ikone/`, svijetle i tamne). Izgled je skladan, ali **tokeni su razbacani** u tri jedinice; plan ih skuplja na jedno mjesto.

### 6.2 Tokeni (verzija 1)

| Token | Svijetla | Tamna | Značenje |
|---|---|---|---|
| `bg` | `#F1F5F9` | `#0F172A` | pozadina prozora |
| `surface` (`Input`) | `#FFFFFF` | `#111827` | polja, popisi, kartice |
| `soft` | `#F8FAFC` | `#1E293B` | sporedne plohe |
| `header` | `#E2E8F0` | `#1E293B` | zaglavlja tablica i skupina |
| `border` | `#CBD5E1` | `#334155` | obrubi |
| `text` | `#0F172A` | `#E2E8F0` | tekst |
| `text-soft` | `#64748B` | `#94A3B8` | sporedni tekst, onemogućeno |
| `accent` | `#2563EB` | `#60A5FA` | naglasak, fokus, odabir |
| `accent-soft` | `#DBEAFE` | `#1E3A5F` | odabir i prelazak mišem |
| `on-accent` | iz kontrasta | iz kontrasta | tekst na naglasku (≥ 4.5:1) |
| `tip` | `#1E293B` | `#334155` | oblačići |
| `success` | `#16A34A` | `#4ADE80` | uspjeh |
| `warning` | `#D97706` | `#FBBF24` | upozorenje |
| `danger` | `#DC2626` | `#F87171` | greška (zamjenjuje `#C00000`) |
| `danger-soft` | `#FEE2E2` | `#4C1D1D` | pozadina greške (zamjenjuje `#FFE9E9`, `RuleBad`) |
| `shape` | `rounded` | isto | `square` / `rounded` / `pill` (6.5) |
| `radius` | 6 px gumbi, 5 px polja, 8 px kartice | isto | iz `shape` |
| `space` | 4, 8, 12, 16 px | isto | razmaci |
| `control-height` | 28 px | isto | jednoredna kontrola |
| `font` | **JetBrains Mono**, 10 pt | isto | naslovi 12 i 16 pt podebljano |
| `focus` | 1 px `accent` | isto | obrub fokusa |
| `chart[0..7]` | `#2563EB`, `#F97316`, `#16A34A`, `#DC2626`, `#9333EA`, `#0891B2`, `#CA8A04`, `#DB2777` | svjetlije | serije grafikona; prva je `accent` |
| `density` | *kasnije* | | kompaktno / normalno / prostrano |

### 6.3 Kako tema dolazi do kontrola

| Vrsta kontrole | Izgled |
|---|---|
| LCL na Qt6 (polja, gumbi, popisi, kartice) | QSS iz tokena (`ThemeSheet`) |
| LCL koje Qt ne crta (`TDBGrid`, `TStringGrid`, dijelovi `TListView`) | `RecolorForm` iz tokena |
| Vlastite iscrtane (`TaSideMenu`, `TaTabBar`, switch, ring, led, card) | čitaju `TaTheme.Tokens` i **crtaju se ponovno pri promjeni teme** (`ThemeChanged`) |
| RX (`TRxDBGrid`) | QSS + `RecolorForm`; boje redaka iz tokena |
| TAChart, SynEdit | **adapter**: tokeni u njihove atribute (serije i osi; boje bojenja sintakse) |
| Ikone | grupa svijetla/tamna po tokenu `icon-set` |
| Izvješća, PDF, HTML | zasebna **tema ispisa** (svijetla); ista paleta grafikona |

Sučelje: `TaTheme.Apply(ATheme)`, `TaTheme.Tokens`, `TaTheme.OnChange`, `LoadFromFile/SaveToFile`.

### 6.4 Pravila izgleda

1. **Jedan naglasak** (`accent`); drugih boja za označavanje nema osim semantičkih (`success`, `warning`, `danger`).
2. **Jedna visina i zaobljenje** za sve jednoredne kontrole (polje, padajući popis, gumb, spin): 28 px.
3. **Ista stanja svugdje:** normalno, prelazak mišem (`accent-soft`), fokus (obrub `accent`), onemogućeno (`text-soft` na `soft`), greška (`danger` na `danger-soft`).
4. Razmaci su višekratnici od 4 px.
5. Ikone iz zalihe (`ikone/`), jedna debljina crte, 16 i 24 px.
6. **Tipografija:** JetBrains Mono, tri veličine (tekst, podnaslov, naslov).
7. Brojke u tablicama desno poravnate, hrvatski oblik (`1.234,50`).

### 6.5 Stil oblika (`shape`)

| Kontrola | `square` | `rounded` (**zadano**) | `pill` (*kasnije*) |
|---|---|---|---|
| Button (svi tipovi) | 2 px | 6 px | pola visine |
| Edit, Spin, Date, Search, Combo | 2 px | 5 px | pola visine, veći unutarnji razmak (12 px) |
| Tabovi (Pages, `TaTabBar`) | pravokutni | zaobljeni gornji kutovi | pilule (aktivna puna `accent`, ostale `soft`) |
| Značke, Segmented | 2 px | 6 px | pilula |
| Kartice, paneli, mreža | 2 px | 8 px | **ostaju 8 px** |
| Check, Radio | kvadrat / krug | zaobljeni kvadrat / krug | nepromijenjeno |

Pravila: stil se bira **jednom, na temi**, uz nadjačavanje po kontroli; kontrola s drukčijim oblikom od ostalih u istoj formi ne prolazi galeriju; ako je stil `pill`, **cijela obitelj polja** postaje pilule. `border-radius` ide iz tokena u QSS (`QPushButton`, `QTabBar::tab`, polja); gdje Qt ne crta (RX mreža, SynEdit), oblik se ne mijenja. Prva faza gradi `rounded` i `square`; `pill` kasnije (uključujući pilula-filtre u zaglavlju mreže), a arhitektura tokena već ostavlja mjesto.

### 6.6 Boja teme na dijelovima kontrola

Cijela tema izvodi se iz **jednog naglaska**: iz njega se računaju `accent-soft`, `accent-hover`, `accent-pressed`, `focus` i `on-accent`.

| Dio kontrole | Boja |
|---|---|
| Gumb padajućeg popisa Combo-a (`::drop-down`, strelica) | `accent`; strelica `on-accent` (u pilula stilu okrugli gumb unutar polja) |
| Spin strelice, gumb kalendara (Date), gumb pretrage | `accent` |
| Primarni gumb (default) | `accent`; sporedni: obrub `accent`, prozirno |
| Aktivan tab, odabrani red, fokus, kvačica, uključen switch, klizač, progres | `accent` / `accent-soft` |
| Zaglavlje mreže, naizmjenični redovi | `header`/`soft` uz blagi dodir naglaska |
| Grafikoni | prva serija `accent` |
| SynEdit | trenutni redak, odabir i oznake iz `accent-soft` |

Gotove teme: **Plava** (zadana), **Zelena** (`#16A34A`), **Crvena** (`#DC2626`), **Ljubičasta**, **Narančasta**, **Grafit**, svaka svijetla i tamna. Semantičke boje se **ne mijenjaju s temom**; u crvenoj temi `danger` mora biti dovoljno različit od naglaska (tamniji `danger` i uvijek ikona uz boju, ne samo boja).

### 6.7 Font i tema kao JSON

- **Font:** za sada isključivo **JetBrains Mono** (tekst, polja, mreža, izbornici, grafikoni, izvješća; SynEdit ga koristi kao font koda). Jedan token `font.family`. Instaliran je na razvojnom računalu (`/usr/share/fonts/truetype/JetBrainsMono/`). **Isporuka:** mapa `fonts/` uz aplikaciju (licenca OFL dopušta), registrira se pri pokretanju; ako datoteke nema, pada na sustavni monospace; u PDF izvješća ugrađuje se podskup fonta.
- Monospace ima jednaku širinu znamenki pa brojke same ostaju poravnate, ali je širi od sans fonta: zadane širine kontrola i stupaca provjeriti u galeriji.
- **Tema kao JSON:** jedna datoteka po temi (`themes/*.json`), kopija u bazi aplikacije. Minimalan zapis: `{"name":"Zelena","accent":"#16A34A","shape":"rounded","dark":false}`; sve ostalo se izvodi iz naglaska, a svaki token može se nadjačati (`"tokens":{"radius":8}`). Učitavanje provjerava zapis (nepoznati ključ upozorava, loš kontrast naglaska javlja grešku); prozor "Tema" u dizajneru i IDE-u radi s istim zapisom.

### 6.8 Provjera teme

- **Galerija** (`tests/theme_gallery`): jedan prozor sa svim obiteljima i varijantama u stanjima normalno/fokus/onemogućeno/greška, u svim temama i varijantama, snimljen u PNG (offscreen); ista galerija kao prozor "Tema" uživo.
- Kriterij: ljudski pregled pri svakoj većoj promjeni; automatski test da nijedna kontrola ne koristi boju koja nije token ni korisnikov izbor; u svakoj kombinaciji vidljiv samo jedan naglasak, kontrast teksta na naglasku ≥ 4.5:1 (6 tema × 2 varijante × oblici koji postoje).

---

## 7. Izvori podataka (`TaSourceDef`) i 4GL kao izvor

Danas kontrole imaju `RowSource` i `ControlSource`. Uvodi se jedan zapis koji pokriva sve vrste izvora, **potpuno unatrag kompatibilno**. Bez prefiksa znači isto što i do sada.

### 7.1 Zapis

| Prefiks | Značenje | Primjer |
|---|---|---|
| *(nema)* | tablica, upit iz baze ili SELECT | `partneri`, `SELECT id, naziv FROM partneri` |
| `sql:` | izričito SQL | `sql:SELECT 1` |
| `expr:` | izraz koji vraća jednu vrijednost | `expr:Zaokruzi([kolicina]*[cijena], 2)` |
| `list:` | fiksni popis, odvojen `;` | `list:Novo;U tijeku;Završeno` |
| `fgl:` | **4GL program ili funkcija** uz parametre | `fgl:PopisPartnera(grad=[grad], aktivan=1)` |
| `fglv:` | 4GL koji vraća **jednu vrijednost** | `fglv:Popust([partner_id], [iznos])` |

### 7.2 Što koja kontrola radi s kojom vrstom izvora

| Kontrola | tablica / SQL | izraz | popis | `fgl:` (retci) | `fglv:` |
|---|---|---|---|---|---|
| Edit (polje), Memo, Label | `ControlSource` = polje | izračunato polje | – | – | izračun iz 4GL-a |
| Edit combo/droplist, List | popis redaka | – | da | **da** (1–3 stupca) | – |
| Choice | – | – | da | da (oznaka, vrijednost) | – |
| Grid | zapisi | – | – | **da** (samo čitanje) | – |
| Chart | 2 stupca | – | – | **da** (2 stupca) | – |
| Image | – | – | – | – | da (put ili bajtovi) |
| Izvješće (`RecordSource`) | tablica / SQL | – | – | **da** | – |

### 7.3 4GL kao izvor redaka (`fgl:`)

Dvije nove naredbe: `COLUMNS` (imenuje i tipizira izlazne stupce) i `EMIT` (jedan redak rezultata).

```4gl
FUNCTION PopisPartnera(grad, aktivan)
  DEFINE grad TEXT
  DEFINE aktivan INTEGER
  COLUMNS id INTEGER, naziv TEXT
  DEFINE r RECORD id INTEGER, naziv TEXT END RECORD
  DECLARE c CURSOR FOR
    SELECT id, naziv FROM partneri WHERE grad = $grad AND aktivan = $aktivan ORDER BY naziv
  FOREACH c INTO r.*
    EMIT r.id, r.naziv
  END FOREACH
END FUNCTION
```

- Rezultat je `TaFglDataSet` (memorijski `TDataSet`) koji kontrole vide kao svaki drugi skup.
- Parametri dolaze iz imenovanih argumenata (`grad=[grad]`), računaju se nad zapisom forme. **Requery** kad se promijeni polje iz parametara.
- Samo čitanje u prvoj fazi; `ON SAVE` blok za uređivanje kasnije.
- Ograničenja: vrijeme po pozivu (zadano 5 s), broj redaka (100.000), zabrana `INPUT`/dijaloga unutar izvora (jasna greška).

### 7.4 4GL kao izračun

`RETURN vrijednost` iz funkcije; u jeziku izraza funkcija `Fgl("Popust", [partner_id], [iznos])` (isto što i `fglv:`), upotrebljiva u pravilu, zadanoj vrijednosti, uvjetnom oblikovanju i izračunatom polju.

### 7.5 Primjer: padajući popis partnera

Dvoklik na `RowSource` → dijalog **Izvor podataka** → kartica *4GL program* → odabere `PopisPartnera` (ili *Novi iz kostura…*) → dijalog prepozna parametre i ponudi vezu na polja forme. Isto u CodeTyphonu i u dizajneru TyphAccessa.

---

## 8. Identično ponašanje (Z1)

### 8.1 Ugovor o svojstvima

Za svaku obitelj postoji **jedan popis svojstava** (tablica u dokumentaciji, opis klase u kodu). Svojstva su danas dijelom polja `TaControlDef`, dijelom ključevi u `Extra`.

| Skupina | Svojstva |
|---|---|
| Podaci | `ControlSource`, `RowSource` (poglavlje 7), `Format`, `DefaultValue`, `Locked` |
| Ponašanje | `VisibleIf`, `EnabledIf`, `Rule`, `RuleMessage`, `AutoFill`, `CalcRules` |
| Izgled | `CondFormat`, `Caption`, `Tip`, `Shape`, boje i font, `Anchors`, `Dock` |
| Radnje | `OnClick`, `OnChange`, `OnDblClick` (vrijednost je **radnja**, poglavlje 9.3) |

U Lazarusu to postaju **objavljena svojstva**, u TyphAccessu polja definicije. **Preslikavanje je tablica `TaPropMap`** (jedan redak po svojstvu: kako se vrijednost iz definicije upisuje u komponentu i obrnuto).

### 8.2 Zajednički stroj ponašanja (`TaBindingEngine`)

**Problem:** ponašanje (izrazi, pravila, uvjetno oblikovanje, vidljivost, omogućenost, zadane vrijednosti, izračuni, AutoFill) postoji dvaput: u `TaFormRunner` (3171 redak) i u `TaFormBinder`. Dok je tako, mogu se razići.

**Rješenje:** nevizualna klasa u sloju A. Ulaz: skup podataka, popis vezanja, domaćin izraza. Izlaz: vrijednosti, boje, stanja, odbijanje spremanja. `TaFormRunner` i `TaFormBinder` postaju **tanki adapteri**.

```pascal
TaBindingEngine = class
  procedure SetDataSet(ADataSet: TDataSet);
  procedure Add(const ABinding: TaBindingDef);        // definicija, ne kontrola
  procedure Refresh;                                  // izračuna sve, vrati promjene
  function Validate(AErrors: TStrings): Boolean;
  property OnApply: TaApplyEvent;                     // (vezanje, što: vrijednost/boja/vidljivost/omogućenost)
end;
```

### 8.3 Izgled

Kontrole crta isti kod; razlike mogu doći samo iz teme, fonta i `LC_NUMERIC`. **Hrvatski oblici:** `ApplyCroatianLocale` u oba okruženja; pokretači postavljaju `LC_NUMERIC=hr_HR.UTF-8` jer Qt spin čita okolinu procesa. **Provjera:** isti obrazac renderiran offscreen u oba okruženja daje PNG snimke koje se uspoređuju.

---

## 9. Dijalozi i čarobnjaci u oba okruženja (Z2)

### 9.1 Načelo

Svaki dijalog je **funkcija sloja B** koja prima kontekst i trenutnu vrijednost, a vraća novu vrijednost ili odustajanje. Ne zna ni za Inspektor objekata ni za dizajner.

```pascal
type
  TaEditContext = class
    Database: TaDatabase;     // popisi tablica, stupaca, programa, izvješća, formi
    FormFields: TStrings;     // polja forme (za parametre i izraze)
    Theme: TaTheme;           // tema
    Owner: TComponent;
  end;

function EditSource(ACtx: TaEditContext; var AValue: string): Boolean;
function EditAction(ACtx: TaEditContext; var AValue: string): Boolean;
function EditFormat(ACtx: TaEditContext; var AValue: string; AKind: TFieldKind): Boolean;
function EditCondFormat(ACtx: TaEditContext; var AValue: string): Boolean;
function EditRule(ACtx: TaEditContext; var AValue, AMessage: string): Boolean;
function EditExpression(ACtx: TaEditContext; var AValue: string): Boolean;
function EditSkeleton(ACtx: TaEditContext; var AProgramText: string): Boolean;
function EditProgramBlocks(ACtx: TaEditContext; var AProgramText: string): Boolean;
function EditTheme(ACtx: TaEditContext; var AThemeJson: string): Boolean;
```

### 9.2 Dva mjesta spajanja

| Okruženje | Poziv |
|---|---|
| CodeTyphon / Lazarus | `TPropertyEditor` (tipka `…`) i `TComponentEditor` (dvoklik, desni klik): tanki omot koji gradi kontekst iz `TaDatabase` na formi i zove funkciju sloja B |
| TyphAccess dizajner | stupac svojstava (`ta_propedit`, `ta_propdlgs`) zove **iste funkcije**; dijalozi iz `ta_propdlgs` sele se u sloj B bez promjene izgleda |

Popravak ili novi dijalog vrijedi u oba okruženja odjednom.

### 9.3 Radnje (`Action`)

| Radnja | Oblik | Što radi |
|---|---|---|
| forma | `openform:Naziv` | otvori formu (po želji s filtrom) |
| izvješće | `openreport:Naziv` | pregled izvješća |
| izvoz | `exportpdf:Naziv>datoteka.pdf`, `exporthtml:...` | izvoz izvješća |
| makro | `macro:Naziv` | makro |
| procedura modula | `run:Naziv` | PascalScript |
| **4GL program** | `fgl:Naziv` | pokrene 4GL program iz baze |
| SQL | `sql:...` | izravna naredba |
| pomoćne | `msg:`, `close`, `goto:` | poruka, zatvori, idi na kontrolu |

`EditAction` nudi izbornik vrsta s popisima iz baze (forme, izvješća, programi, makroi); za 4GL dodatno *Uredi program…* i *Novi iz kostura…*.

### 9.4 Primjer već izrađen: uređivač sidrenja

Lazarusov *Anchor Editor* postoji u IDE-u, a u TyphAccessu su se sidra tipkala kao tekst. Izrađen je kao dijalog sloja B (`src/gui/ta_anchoreditor.pas`, commit `7d0a99a`): funkcija `RunLayoutDialog(vlasnik, definicija forme, definicija kontrole, vrijednosti)` uređuje `Anchors`, `Dock`, `BorderSpacing` i `AnchorLeft/Top/Right/Bottom`; zapis je isti kao prije; dizajner ga zove s gumba **…**; u CodeTyphonu isti dijalog ide kao `TPropertyEditor` bez izmjena; ima testove bez prozora. Svaki sljedeći dijalog slijedi isti uzorak.

---

## 10. Kosturi (`.4glt`)

**Format** (tekst, mapa `skeletons/`, korisnik dodaje svoje; `@format 1` u zaglavlju, parser tolerantan na nepoznate direktive):

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
END MAIN
```

**Vrste utora:**

| Vrsta | Punjenje iz baze | Pitanje |
|---|---|---|
| `tablica` | popis korisničkih tablica | "Koja tablica?" |
| `stupac(tablica)` | stupci te tablice | "Po kojem stupcu grupirati?" |
| `stupci(tablica)` | višestruki izbor stupaca | "Koje stupce prikazati?" |
| `stupac:broj(t)`, `stupac:datum(t)`, `stupac:tekst(t)` | samo stupci tog tipa | "Koji iznos zbrajati?" |
| `veza(tablica)` | strani ključ i ciljna tablica | "Koji je detalj ovog zapisa?" |
| `program`, `izvjesce`, `forma` | objekti iz baze | "Koje izvješće otvoriti?" |
| `tekst`, `broj`, `da/ne`, `izbor(a;b;c)` | slobodan unos | "Naslov prozora" |

**Prilagođavanje podacima:** engine kostura (`ta_skeleton`) čita metapodatke (`TableInfo`, `ForeignKeys`, tipovi), predloži zadane utore (sva polja osim `id`, prvi datum, prvi iznos), zamijeni `{utor}`, izgradi **pregled generiranog 4GL-a**. Generirani program je običan 4GL, bez skrivenih ovisnosti o kosturu.

**Početna biblioteka (12 kostura):** Popis s filtrom; Unos i izmjena zapisa; Master-detail; Zbroj po grupi; Zbroj po razdoblju; Masovna izmjena s brojačem; Sljedeći broj dokumenta; Arhiviranje (kopiraj, obriši); Izvoz izvješća u PDF; Uvoz iz CSV (s preslikavanjem stupaca); Poravnanje stavki (iz SmartBet `poravnanje.4gl`); Izbornik programa. Temelje se na postojećim receptima (priručnik) i SmartBet programima.

---

## 11. Dva ulaza i vizualno programiranje

### 11.1 Dva ulaza (Z6)

- **Od kostura:** *Novi program iz kostura…* → popis po kategorijama → pitanja utora s popisima iz baze → **pregled 4GL-a** → *Spremi* (baza `_sys_programs` i/ili datoteka).
- **Od podataka:** na `TaDatabase` (desni klik) i u izborniku TyphAccessa: *Predloži programe…*. Engine **rangira** kosture po prikladnosti (datum + iznos → *Zbroj po razdoblju*; strani ključ → *Master-detail*; `status` + datum → *Arhiviranje*; pravilo/izračun u metapodacima → *Provjera i ispravak*). Jednim klikom se kostur **sam popuni**, korisnik potvrdi ili promijeni u pregledu.
- **Kontekstni prikaz:** ako je u formi odabrana kontrola, čarobnjak predlaže kosture koji joj odgovaraju (gumb: radnje; padajući popis: izvor retka).

### 11.2 Blokovi (postojeći `ta_blockedit`, `ta_blocks`, `ta_fglblocks`)

- **Paleta blokova:** *Otvori tablicu*, *Za svaki redak*, *Ako*, *Postavi varijablu*, *Upiši u tablicu*, *Pitaj korisnika*, *Prikaži*, *Pokreni izvješće*, *Izvezi PDF*, *Pozovi program*, *Otvori formu*, *Vrati redak (EMIT)*, *Vrati vrijednost*.
- **Polja blokova su padajući popisi iz baze:** tablica, stupac (samo traženog tipa), program, izvješće, forma, varijabla.
- **Dvosmjerno:** blokovi ↔ 4GL tekst (podskup već provjeren; širi se na `COLUMNS`/`EMIT`); prikaz teksta je obitelj Editor.
- **Kostur se otvara u blokovima** radi prilagodbe; **pogreške pokazuju na blok**; `ON SAVE` blok za uređive izvore.

---

## 12. Pretvorba TyphAccess kontrola u Lazarus komponente

### 12.1 Zašto

`TaTextBox`, `TaComboBox` itd. su danas tanke ljuske s `Def: TaControlDef`. Svojstva žive u definiciji pa ih Inspektor ne vidi, a `.lfm` ih ne sprema. Pretvorba ih čini **samostalnim komponentama** sa svim svojstvima kao objavljenima; runtime TyphAccessa stvara iste komponente iz JSON-a.

### 12.2 Mapiranje klasa

| Danas | Postaje | Napomena |
|---|---|---|
| `TaTextBox`, `TaComboBox` | **Edit** (`Variant` = text, combo, ...) | |
| `TaMemo`, `TaRichText` | **Memo** | rich ostaje na `TRichMemo` |
| `TaLabel`, `TaHyperlink` | **Label** | |
| `TaButton`, `TaToggle` | **Button** | |
| `TaCheckBox` | **Check** | |
| `TaOptionGroup` | **Choice** | |
| `TaListBox` | **List** | |
| `TaSubform` | **Grid** (varijanta datasheet/entry) + **Panel** | veza glavna/detalj ostaje svojstvo |
| `TaTabControl` | **Pages** | |
| `TaImage`, `TaRect`, `TaLine` | **Image** | oblici su varijante |
| `TaChart` | **Chart** (`TAChart`) | stari crtež ostaje za izvješća |
| `TaBarcode` | **Barcode** | |
| `TaSideMenu` | **Menu** | već ima zbirke `Groups`/`Items` |
| `TaPageBreak`, `TaSubreportBox` | ostaju dizajnerski elementi izvješća | |
| *(nema)* | **Progress**, **Calendar**, **Editor** | nove obitelji |

### 12.3 Kriterij "pretvoreno" (svih osam)

1. **Svojstva su objavljena** (izvor `TaSourceDef`, pravilo, oblik, `VisibleIf`, `EnabledIf`, `CondFormat`, radnje) i spremaju se u `.lfm`.
2. **`TaPropMap`:** isti zapis ide iz JSON-a u komponentu i natrag.
3. **Varijanta** (`Variant`) i podobjekt `Options`.
4. **Zamjenjivi pokretač** (`IaEngine`) s LCL pokretačem i, gdje je dogovoreno, neobaveznim.
5. **Registracija i ikone** (24, 36, 48 px, svijetle i tamne; PNG `TCLASSNAME.png` + `_150`, `_200`).
6. **Property i component editori** (dvoklik, "Prikaži kao", izbor izvora, radnje) iz sloja B.
7. **Tema:** čita tokene, prolazi galeriju u svim temama.
8. **Testovi:** čitanje/pisanje definicije, ponašanje (pravila, izrazi), snimka izgleda, zatvaranje bez pada.

### 12.4 Redoslijed pretvorbe

| Red | Obitelji | Razlog |
|---|---|---|
| 1 | Edit | najčešća, najviše varijanti, prototip arhitekture |
| 2 | Button, Label, Check | jednostavne |
| 3 | **Editor** | SynEdit u sve uređivače |
| 4 | Memo, Choice, List | osnovni skup |
| 5 | Grid, Panel, Pages | strukturne, izvori iz 4GL-a |
| 6 | Image, Chart, Barcode, Menu, Progress, Calendar | ostatak |

---

## 13. Light IDE ("Typhon Light")

### 13.1 Kome služi

CodeTyphon/Lazarus: stotine kontrola, uređivač koda, otklanjanje grešaka, više platformi; strma krivulja učenja; rezultat je prevedeni program. TyphAccess: vizualni dizajn formi i izvješća, 4GL, baza u jednoj datoteci, bez prevođenja; blaga krivulja. **Light IDE je sredina:** tko zna malo programirati slaže poslovnu aplikaciju iz male palete, kostura i čarobnjaka, a po želji je prevodi u samostalan program. Ciljni korisnici: (1) slagač aplikacija, (2) programer Pascala koji želi brzo složiti DB aplikaciju, (3) naš tim.

### 13.2 Tri izvedbe

| Izvedba | Što | Prednosti | Mane |
|---|---|---|---|
| **A: Light profil CodeTyphona** | skup konfiguracija i paket: paleta s jednom stranicom "TyphAccess", skriveno ostalo, predlošci projekta i forme, pokretač `typhon-light.sh` (`--pcp=`) | 1–2 dana, bez održavanja koda IDE-a, nadogradnje besplatne, bez pravnih pitanja | korisnik je i dalje u velikom IDE-u; "Light" je samo izgled |
| **B: prerađeni IDE** | ponovna izgradnja iz `typhon/ide` sa statičkim paketima (`staticpackages.inc`, `CT_Is_BigIDE`): naši paketi statički, vlastito ime, naslovni zaslon, skraćeni izbornici, pojednostavljen Inspektor; uklonjeno dockiranje, profiler, dijagrami, pas2js, ne-Qt6 | doista "svoj" IDE, zadržava Lazarusov dizajner i `.lfm` | prvo naučiti izgraditi IDE, zatim održavati; izvedeni IDE **ne smije nositi naziv CodeTyphon/Lazarus** |
| **C: TyphAccess kao IDE** | proširiti TyphAccess: urednik Pascala (SynEdit), prevođenje (`fpc`), pokretanje, otklanjanje grešaka, paketi, izvoz `.exe` | potpuno naše, jedan kod | **mjeseci rada**, rizik lošijeg IDE-a od postojećeg |

### 13.3 Preporuka: tri stupnja, svaki koristan sam

| Stupanj | Kad | Odluka nakon |
|---|---|---|
| **1. Light profil (A)** | odmah nakon prototipa Edit, 1–2 dana | je li dovoljno? |
| **2. Light IDE (B)** | nakon stabilne palete (etape do 7), 1–2 tjedna | je li "kopija Lazarusa" prihvatljiva? |
| **3. TyphAccess kao IDE (C)** | samo ako korisnici žele raditi bez prevođenja i bez Pascala | ne počinjati prije |

Zašto ne odmah B ili C: paleta još nije u konačnom obliku, IDE oko nje bi se stalno prepravljao. Za slagača aplikacija TyphAccess već *jest* Light IDE; B mu dodaje prevođenje i Pascal, C bi zamijenio Lazarus.

### 13.4 Stupanj 1: Light profil (1–2 dana)

| Dan | Posao | Rezultat |
|---|---|---|
| 1 | gdje CodeTyphon sprema konfiguraciju palete i izbornika (`~/.typhon64`); profil samo s našim stranicama palete; `typhon-light.sh` | IDE se otvara s našom paletom, bez ostalih stranica |
| 1 | predlošci: *TyphAccess aplikacija* (lpr s lokalizacijom, `TaDatabase`, izbornik), *Forma nad tablicom* | File → New nudi naše predloške |
| 2 | dokument "Prvi sat": od praznog projekta do forme s izračunom, pravilom i 4GL gumbom | opis koji korisnik izvede mišem |

**Prihvaćanje:** nova osoba uz upute složi u 30 minuta aplikaciju s popisom, unosom, jednim izvješćem i jednim 4GL programom, bez izlaska iz Light profila.

### 13.5 Pravna pitanja

CodeTyphon je distribucija s više licenci (Lazarus GPL/LGPL s iznimkom za komponente, FPC GPL/LGPL, PilotLogic dodaci vlastiti uvjeti). Izvedeni IDE (B) ne smije nositi naziv CodeTyphon ni Lazarus; uvjete preraspodjele provjeriti prije javne objave. Unutarnja upotreba je bez problema. Radni naziv "Typhon Light"; konačni naziv ne smije nalikovati nazivima trećih strana.

### 13.6 Zajednički temelj

Ovo se radi u svakom slučaju (izvedbe A, B, C su samo ovitci): obitelji s `Variant`, dijalozi kao funkcije (sloj B), kosturi i 4GL kao izvor, `TaBindingEngine`, tema, predlošci projekta.

---

## 14. Etape razvoja i raspored

Procjene su radni dani jednog programera uz postojeće znanje; orijentir, ne obećanje. Svaka etapa je sama korisna i ima kriterij prihvaćanja.

| Etapa | Posao | Dana | Kriterij prihvaćanja |
|---|---|---|---|
| **E0** | **Priprema:** razdvajanje paketa (`typhaccess_core`, `typhaccess_editors`, `typhaccess_dsgn`), dijalozi neovisni o dizajneru u sloj B, `TaPropMap` uz postojeći kod | 1 | smoke 0 grešaka; `typhaccess_dsgn` se prevodi iz novih paketa; TyphAccess radi isto |
| **E1** | **Tema:** `TaTheme` (tokeni u jednoj jedinici, JSON, JetBrains Mono s isporukom i rezervnim fontom, semantičke boje), **galerija i snimke**, **stil oblika** `rounded`/`square`, izvođenje iz jednog naglaska (zelena, crvena...), QSS za gumbe, polja, Combo gumb i tabove | 5 | galerija u svim temama, jedan vidljiv naglasak, kontrast ≥ 4.5:1 |
| **E2** | **Okvir obitelji** (`IaEngine`, `TaEngineRegistry`, domaćin, `Variant`, `Options`) i **prototip Edit** (text, password, combo, droplist, spin, date, currency) | 5 | polje se jednim klikom pretvara u padajući popis, zadržava izvor, pravilo, radnju; Tab i fokus prolaze; testovi. **Nakon ovoga odluka: host ili jedna klasa; uz Edit se dodaje pretvorba JSON ↔ `.lfm` (17.1)** |
| **E3** | **Light profil** (stupanj 1) i dokument "Prvi sat" | 2 | prihvaćanje iz 13.4 |
| **E4** | **4GL kao izvor:** `COLUMNS`/`EMIT`/`RETURN`, `TaFglDataSet`, `TaSourceDef` (`OpenSource` zamjenjuje razasuto otvaranje upita u `ta_formrun`, `ta_reportengine`, `ta_controls`), parametri iz forme i requery, `Fgl()`, kontrole Edit combo/List/Choice/Grid/Chart/`RecordSource` prihvaćaju `fgl:` + standardni događaji i hijerarhija (19.3) | 4 | padajući popis iz 4GL funkcije s parametrom iz drugog polja se osvježava; mreža, grafikon i izvješće iz `fgl:` daju isto kao ekvivalentni SQL; `Fgl()` kao pravilo i izračun; prekoračenje vremena/redaka daje poruku, ne zamrzava |
| **E5** | **Editor (SynEdit):** bojenje 4GL-a i izraza, dopuna iz baze, greške u rubu, ugradnja u sve uređivače; mjerenje veličine | 3 | 4GL se boji, sklapa i dopunjuje; greška parsera označena u rubu; tamna tema |
| **E6** | **Kosturi:** format `.4glt`, engine, 12 kostura, test nad barem 2 tablice | 3 | svaki kostur × 2 tablice daje program koji prolazi `--check` i izvršava se; isti rezultat kao rukom pisan ekvivalent; novi `.4glt` se pojavi bez ponovnog prevođenja |
| **E7** | **Dva ulaza i čarobnjak**, pregled 4GL-a, kontekstni prijedlozi + Blok-čarobnjak (19.2) | 3 | prazna SQLite baza s 3 tablice → 5 radnih programa u najviše 15 klikova |
| **E8** | **Blokovi:** paleta s padajućim popisima iz baze, dvosmjerno, greške na bloku, `ON SAVE` + standardne procedure forme u blokovima (19.3) | 4 | "popis partnera s filtrom po gradu i gumbom za PDF" složen samo blokovima |
| **E9** | **Dijalozi u oba okruženja:** `EditSource`, `EditAction`, `EditFormat`, `EditCondFormat`, `EditRule`, `EditExpression`, `EditTheme`; property i component editori; dizajner prelazi na iste funkcije + `EditAlert`, `EditPropertyClass` (19.7) | 5 | isti niz radnji u IDE-u i dizajneru daje identičnu vrijednost svojstva |
| **E11a** | **Neprekidna forma i podforma** (poglavlje 20): `TaRowModel`/`TaRowSource`, `TaRowsView` s recikliranjem redova, novi red, zaglavlje i podnožje, dizajner s pojasevima, peti raspored u Blok-čarobnjaku | 12 | račun s unosom stavki u neprekidnoj podformi; zbroj u podnožju i u glavnoj formi |
| **E10** | **Zajednički stroj ponašanja:** izdvajanje `TaBindingEngine`, paritetni skup (20 definicija formi kroz runner i binder), usporedba offscreen snimaka. **Prvo snimiti sadašnje ponašanje** + stanje zapisa/forme, upit po formi, tipkovnički standard, navigacijska traka (19.3, 19.4, 19.8) | 8 | 0 razlika u paritetnom skupu; smoke 0 grešaka; stare aplikacije rade isto |
| **E11** | **Ostale obitelji:** Button, Label, Check (2); Memo, Choice, List (2); Grid s `TRxDBGrid` (bojanje, `entry`), Panel, Pages (5); Image, Chart (`TAChart` + adapter), Barcode, Menu, Progress, Calendar (4) + varijanta `lov`, radnja `alert:` (19.5) | 15 | svaka obitelj ispunjava kriterij 12.3 |
| **E12** | Paket `typhaccess_ext` (neobavezni pokretači), ikone, dokumentacija palete i priručnik + klase svojstava i biblioteka objekata (19.7) | 4 | program bez neobaveznih paketa radi sve varijante s LCL pokretačima |
| **Poslije** | Stupanj 2 Light IDE (1–2 tjedna), `pill` stil, gustoća, prenosivost `.lfm`↔JSON, čarobnjaci *Nova TyphAccess aplikacija* i *Nova forma nad tablicom*, `TaDataForm` | po odluci | |

**Ukupno E0–E12: oko 60 radnih dana (12 tjedana)**, od toga 10 dana otpada na poglavlje 19 (Oracle Forms inspiracija); bez njega bi bilo 50. Prvi vidljivi rezultat (tema u galeriji, pa Edit) je u prvom tjednu; prvi pogled "radi" za 4GL (`fgl:` izvor, kosturi, čarobnjak) je oko etape E7.

### 14.0 Stanje izvedbe (2026-11-10)

- **E0 (gotovo 2026-11-10):** `src/` je u LightPalette jedina kopija (`../TyphAccess/src` je simbolička veza). Paketi `typhaccess_core` (79 jedinica), `typhaccess_editors` (22 dijaloga u `src/editors`) i `typhaccess_dsgn` prevode se redom. Dodan `TaPropMap` (`src/core/ta_propmap.pas`, 43 svojstva, test u smoke-u). Ograničenje: kod nije slojevit (npr. `ta_controls` koristi `ta_sidemenu`/`ta_icons`/`ta_richedit`, a `ta_formrun` dosiže dizajnere), pa je jezgra u paketu proširena tim jedinicama; dizajneri, `ta_formrun`, `ta_reportview` i ostalo su i dalje samo u aplikaciji i u putanji `typhaccess_dsgn`.
- **E7 (rano započet, okvir gotov):** pametni okvir čarobnjaka (`ta_wizardframework`, `ta_wizardgen`: `SuggestSolutions`, `BuildFormWithFilters`, `BuildFglScript`; `TfrmSmartWizard`; filteri `flt_*`/`filterFor` u `ta_formrun`; Component Editor na `TaDatabase`). Probni program `tests/wizards/wizard_smoke_test` prolazi (0 grešaka), TyphAccess smoke 0 grešaka. Preostaje: provjera u stvarnom GUI-ju (Blok-čarobnjak, `TaSourceDef`, kosturi iz E4/E6), hrvatska imena iz poglavlja 19.

- **E1 (gotovo koliko je moguće, 2026-11-10):** `ta_tokens` (tokeni, izvođenje teme iz jednog naglaska, JSON, kontrast, aktivna tema, adapteri `EditorPalette` za SynEdit i `ChartPalette` za TAChart), `ta_theme` generira QSS iz tokena (oblik `rounded`, `square` i `pill`; pill polja 11 px, gumbi 13 px), naglasak na gumbu padajućeg popisa, spinu, kvačici, radiju, tabovima, progresu, označenom retku popisa i mreže (`SelectedColor`/`FocusColor` iz tokena), font JetBrains Mono (mapa `fonts/` s OFL.txt, registracija pri pokretanju + Qt font aplikacije; kopira se i u deploy), šest ugrađenih tema i `themes/*.json`, izbornik u TyphAccessu (boja teme, oblik, učitavanje JSON-a, spremanje teme u aplikaciju), tema aplikacije u bazi (`tema.json` u postavkama; ne nadjačava korisnikov izbor), bočni izbornik i grafikon čitaju tokene, monospace u izvješćima je JetBrains Mono (pregled i ugrađeni podskup u PDF-u; ostali tekst izvješća i dalje DejaVu Sans). Galerija `tests/theme_gallery` (36 snimki, `run.sh`). **Ostaje:** gumb ikone `TDateEdit` u boji teme (zamjena ikone zamrzavala je program, odustalo se), izvješća u JetBrains Mono za sav tekst (mijenja raspored; odluka kasnije), stvarna ugradnja adaptera u SynEdit (E5) i TAChart (E11) kad te obitelji postoje, RX gumbi (E11), provjera PDF-a s mono stavkom u automatskom testu.

- **E2 (gotovo 2026-11-10, obitelj Edit):** `ta_family` (pokretač `TaEngine`, registar `RegisterEngine`/`FindEngine` s mogućnošću pružatelja, domaćin `TaFamilyHost`) i `ta_edit` (`TaEdit` s varijantama text, password, combo, droplist, spin, date, currency; opcije po varijanti `TaPasswordOptions`/`TaComboOptions`/`TaSpinOptions`/`TaCurrencyOptions`/`TaDateOptions` koje se pamte pri promjeni varijante; veza na podatke preko `TFieldDataLink`; `EditFromDef`/`EditToDef` (JSON definicija ↔ komponenta, alias `TextBox`/`ComboBox`, nepoznati ključevi u `Extra`) i `EditToLfm`/`EditFromLfm` (.lfm krug). Registrirano na stranici palete "TyphAccess: Podaci" s ikonom. **Odluka nakon prototipa:** domaćin (host) radi: Tab/Shift+Tab prolaze kroz domaćine, fokus ide u stvarnu kontrolu, `.lfm` ne sadrži unutarnju kontrolu, podaci se čitaju/pišu, tema se primjenjuje (galerija ima red sa svim varijantama). Ostaje kao u planu: varijante mask, time, search, lookup; ugradnja u `TaFormRunner`/`TaFormBinder` (E11), property editori i izbornik "Prikaži kao" (E9), više pokretača (RX/JVCL, E11–E12). Napomena: izravno pozivanje `OnExit` na `TDateEdit` u testu baca grešku zbog LCL ovojnice; zato postoji javni `LeaveField` (isto što se događa pri gubitku fokusa). Prirodni lijevi/desni poravnati iznos: `Alignment` je zadan lijevo, ali iznos je zadano desno dok se poravnanje ne postavi izričito.

- **E3 (gotovo 2026-11-10, Light profil):** `light/make_light_profile.py` (profil `~/.typhon-light` iz običnih postavki: paleta samo TyphAccess: Podaci, TyphAccess, Standard, Additional, Common Controls, Data Controls, Data Access, Dialogs; ostalih 251 stranica skriveno; bez povijesti projekata), `light/install_in_ide.sh` (gradi zaseban IDE `~/.typhon-light/bin/typhon-light` sa statički ugrađenim paketima TyphAccess; obični IDE `bin64/typhon` se ne dira; oko 2-5 min), `light/typhon-light.sh` (pokretač), predlošci `lazarus/ta_templates.pas` (File > New > Project > **TyphAccess aplikacija**, forma **TyphAccess forma**), ikone palete kao `lazarus/ta_register.res` (RCDATA, ime = veliko ime klase; gradi `make_icons_res.py` iz `resources/*.png`), dokument `docs/PRVI-SAT.md`. **Provjereno u stvarnom IDE-u pod Xvfb-om:** paleta pokazuje samo navedene stranice, TaEdit i ostale komponente s ikonama, predložak stvara projekt s formom (uses: `ta_edit`, `ta_components`), TaEdit se baca na formu, Inspektor pokazuje `Variant`, `ControlSource`, `DataSource`... **Poznato:** IDE imenuje nove komponente `aEdit1` (skida samo `T` s `TaEdit`); osnovne LCL stranice ostaju do E11; stranice novih paketa pojave se na kraju palete dok se ne dodaju u skriptu; predložak još ne stavlja komponente na formu (IDE nema takvu kuku; trebalo bi naslijeđenu formu u E9/E12).

- **E4 (uglavnom gotovo 2026-11-10, 4GL kao izvor):** `COLUMNS`/`EMIT` u 4GL-u (`ta_fgl`), `TaFglResult`, `TaFglSourceIO` (bez dijaloga: greška s porukom), `TaFglRunner.CallFunc` (vremensko ograničenje 5 s, najviše 100.000 redaka), `ta_source` (`ParseSource`, `OpenSource` za tablicu/`sql:`/`list:`/`fgl:`, `EvalSourceValue` za `fglv:`/`expr:`, `TaFglDataSet`, imenovani i pozicijski argumenti, `SourceFieldRefs`), funkcija **`Fgl("Program.Funkcija", ...)` u izrazima**. Spojeno u `TaFormRunner` (popis, lista, grupa izbora i grafikon prihvaćaju `fgl:`, `list:`, `sql:`; promjena polja iz parametara osvježava izvor) i u izvješća (`RecordSource = fgl:...`). Dokumentirano u `TyphAccess/docs/4GL-SPEC.md` (poglavlje 16). Napomena: parametri funkcije bez tipova u zaglavlju (kao i do sada, tip daje `DEFINE`), pa je primjer iz 7.3 ispravljen. **Ostaje:** podforma/mreža iz `fgl:` (veže se uz `TZQuery` i uređivanje), `ON SAVE`, parametri izvješća, predmemorija po parametrima, kontrola `lov`/`lookup` iz izvora (E11), dijalog `EditSource` (E9), uređivač 4GL-a s označavanjem `COLUMNS`/`EMIT` (E5).

- **E5 (gotovo 2026-11-10, obitelj Editor):** `ta_synhl` (vlastito bojenje na SynEditu: 4GL s komentarima `--` i viseretkovnim `{ }`, nizovi s udvojenim navodnicima, `$parametri`, tipovi, funkcije, **sklapanje blokova** `MAIN/FUNCTION/REPORT/IF/WHILE/FOR/FOREACH/CASE/MENU/GLOBALS/SCREEN ... END`; jezik izraza s `[polje]`, `[?parametar]`, funkcijama) i `ta_editor` (`TaEditor`, varijante 4gl, sql, expression, pascal, json, text; boje, font, rub i označeni redak iz tokena teme i uživo pri promjeni teme; `SetErrorsFromLog` pretvara poruke parsera `datoteka:redak:stupac: poruka` u označene retke; dopuna koda Ctrl+Space iz riječi jezika i iz baze: tablice, stupci, 4GL programi, izvješća, forme; jednoredni način za izraze). Ugrađeno u uređivače: 4GL program (`ta_fgledit`, s označavanjem grešaka nakon *Provjeri* i dopunom iz baze), moduli i makroi (`ta_modeditor`), graditelj izraza (`ta_exprbuilder`), SQL u dizajneru upita (`ta_querydesign`). Registrirano na stranici "TyphAccess: Logika i uređivači" (ikona; Light profil je proširen); provjereno u Light IDE-u. **Ostaje:** brojevi redaka u `Gutter` oznakama za greške (zasad se označava pozadina retka), dopuna za svojstva s izrazima u Inspektoru (E9), predlošci/snippeti `.4glt` (E6), bojenje `COLUMNS`/`EMIT` kao posebnih riječi nije razlikovano od ostalih ključnih riječi, blokovski uređivač 4GL-a još koristi svoj tekstni prikaz.

- **E9 (gotovo djelomično 2026-11-10, dijalozi u oba okruženja; provjereno u Light IDE-u pod Xvfb-om: gumb … na Format, CondFormat i EnabledIf otvara dijaloge, EnabledIf dobiva `[grad]`; u dizajnu se baza sada sama otvara za dijalog):** `ta_editdlg` (sloj B): `TaEditContext` (baza, polja forme, izvor, vlasnik; zadani izvor je prva tablica) i funkcije `EditSource`, `EditAction`, `EditFormat` (nova: popisi formata za datum, iznos, postotak, broj, tekst), `EditCondFormat`, `EditRule`, `EditExpr` (zbog sudara imena s `EditExpression` iz `ta_exprbuilder`), `EditTheme` (nova: naglasak, tamna, oblik → JSON teme). Dizajneri formi i izvješća više ne zovu `Run*Builder` izravno nego `DesignEdit*` koji grade kontekst i zovu iste `Edit*`. IDE: `TStringPropertyEditor` (`ta_register`, gumb `…`) za `TaEdit.RowSource`, `VisibleIf`, `EnabledIf`, `CondFormat`, `Format`; kontekst se uzima iz `TaDatabase` na formi. Test: s kukom `EditDialogHook` se provjerava da IDE put i put dizajnera daju **istu vrijednost** za radnju, uvjetno oblikovanje, pravilo i izvor. **Ostaje:** `EditAlert` i `EditPropertyClass` (E11/E12), `AutoFill` u dizajneru još zove stari dijalog, uređivači svojstava za ostale komponente (TaProgram, TaReport, TaFormBinder) i `EditTheme` kao svojstvo, provjera u stvarnom IDE-u (Inspektor) i snimka.
- **E8 (gotovo djelomično 2026-11-10, paleta blokova):** `ta_fglpalette` (19 blokova iz 11.2: Glavni program, Varijabla, Zapis tablice, Otvori tablicu, Otvori tablicu s filtrom po stupcu, Za svaki redak, Upiši u tablicu, Ako, Postavi varijablu, Pitaj korisnika, Prikaži, Izvješće nad tablicom, Pokreni izvješće, Izvezi u PDF, Redak u izvješće, Završi izvješće, Pozovi program, Otvori formu, Vrati vrijednost; polja su **padajući popisi iz baze**: tablice, stupci odabrane tablice, programi, forme te varijable i izvješća koji već postoje u programu; **dvosmjerno** `MatchLine` prepoznaje redak 4GL-a kao blok s vrijednostima; **greške na bloku** `AnnotateLog`: poruka parsera dobiva naziv bloka) i dijalog `ta_fglblockdlg` (*Blok iz baze…* u blokovskom uređivaču 4GL-a, pregled redaka uz umetanje; *Provjeri* piše "Blok «…» (redak N): …"). Test: *popis partnera s filtrom po gradu i gumbom za PDF* složen samo od blokova prolazi provjeru, izvodi se i stvara PDF. **Ostaje:** `ON SAVE` blok za uređive izvore i standardne procedure forme (`GoBlock`, `NextRecord`… traže runtime forme, dolazi s E10), redak blokovskog uređivača još ne prikazuje padajuće popise izravno u retku (zasad ih nudi dijalog), `COLUMNS`/`EMIT` u dvosmjernom prepoznavanju (blok *Vrati redak* nije dodan).
- **E11 (počelo 2026-11-11), Check:** `ta_check` — obitelj **Check** po uzoru na Edit: domaćin `TaCheck` (`TaFamilyHost`), varijante `checkbox`, `switch` (vlastito crtanje, boje iz tokena teme, razmak i klik, natpisi `OnCaption`/`OffCaption` u `TaSwitchOptions`), `radio` i `tristate` (`Value` je Boolean ili Null = nije određeno), samo za čitanje, veza na polje (`DataSource`/`DataField`; Boolean, brojčano i tekstualno polje; za razliku od teksta upis u polje je odmah pri kliku), `CheckFromDef`/`CheckToDef` (vrste `Check` i `CheckBox`, nepoznati ključevi se čuvaju), `.lfm` (`CheckToLfm`/`CheckFromLfm`), registracija na stranici *TyphAccess: Podaci* s ikonom i uređivačima svojstava `VisibleIf`/`EnabledIf`/`CondFormat`. Smoke `TestCheck` 24 provjere. **Button:** `ta_button` — `TaButton`, varijante `standard`, `default`, `cancel` (`TBitBtn`), `toggle` (`TToggleBox`, uz polje kao Check), `flat` i `link` (vlastito crtanje `TaFlatPaint`, boje iz tokena, hover/pritisak/fokus); ikona iz biblioteke ikona (`Options.Icon`), radnja definicije u `ClickAction`, LCL-ov `OnClick`; `ButtonFromDef`/`ButtonToDef` (`Button` i `ToggleButton`), `.lfm`; smoke `TestButton` 22 provjere. Nisu napravljene varijante `image`, `menu`, `split`. **Label:** `ta_label` — `TaLabel`, varijante `text`, `hyperlink` (adresa u `TaHyperlinkOptions`, `OpenURL` ili `LabelOpenHook`, plus `OnClick`), `html` (podskup iz `ta_richtext`) i `badge` (`TaBadgeOptions.Tone`: neutral, accent, success, warning, danger iz tokena); jedan pokretač `TaLabelPaint` s `RenderTo(Canvas)`; prikaz polja (`DataSource`/`DataField`); `LabelFromDef`/`LabelToDef` (`Label`, `Hyperlink`), `.lfm`; smoke `TestLabel` 15 provjera. Sve tri obitelji su na stranici *TyphAccess: Podaci* s ikonama. **Memo:** `ta_memo` — `TaMemo`, `plain` (`TMemo`), `rich` (`TaRichEdit`, mali HTML) i `markdown` (`TMemo` s mono fontom, izvorni tekst bez pregleda); `Options.WordWrap`, `MaxLength`, veza na polje (upis pri izlasku). **Choice:** `ta_choice` — `TaChoice`, `radio` (`TRadioGroup`), `check` (`TCheckGroup`, kljucevi odvojeni zarezom) i `segmented` (vlastito crtanje); stavke `kljuc=natpis`, `Title`, `Options.Columns`; `OptionGroup` iz definicije. **List:** `ta_list` — `TaList`, `list`, `checklist`, `iconlist` (`TListView`, bez ikona) i `tree` (razina iz uvlake od dva razmaka); vrijednost je kljuc; `ListBox` iz definicije. Sve imaju samo-za-citanje, vezu na polje (Choice i List upisuju odmah), `...FromDef/ToDef`, `.lfm`, ikone, uredjivace izraza; smoke `TestMemo` 23, `TestChoice` 25, `TestList` 24 provjere. **Grid:** `ta_grid` — `TaGrid`, `readonly`, `editable`, `datasheet` nad `TDBGrid` (plan: `TRxDBGrid`, nije u paketima), `DataSource`, `Options.RowHeight`/`Zebra`; nema footer-sum, reda filtara ni varijante `entry`. **Panel:** `ta_panel` — `TaPanel` je spremnik (kontrole se spuštaju na domaćina, pozadina je ispod njih i ne sprema se u `.lfm`), `plain`, `group`, `card` (crtanje po tokenima), `expander` (klik na naslov sklapa na 28 px i vraća visinu); nema `scroll` i `splitter`. **Pages:** `ta_pages` — `TaPages`, `tabs` (`TTabControl`), `list`, `steps` (korake crta sam); popis stranica i `ActivePage`, `OnChange`; sadržaj stranica i dalje određuje `page` u definiciji; nema `accordion`. Raspored palete: *Podaci* (Edit, Memo, Check, Choice, List, Grid), *Prikaz* (Label), *Raspored i navigacija* (Button, Panel, Pages); `make_light_profile.py` zadržava i nove stranice. Smoke `TestPanel` 14, `TestGrid` 12, `TestPages` 15 provjera. **Progress:** `ta_progress` — `TaProgress`, `bar`, `ring`, `led` (zeleno/žuto/crveno po `WarnAt`/`DangerAt`) i `busy` (traka bez kraja, tajmer); `Min`/`Max`, prikaz polja. **Calendar:** `ta_calendar` — `TaCalendar`, `month` (`TCalendar`), `range` (dva klika daju `od..do`) i `agenda` (idućih `Days` dana); vrijednost je ISO datum, veza na polje datum/tekst. **Image:** `ta_image` — `TaImage`, `picture` (datoteka, uklopi/istegni/središte), `shape` (pravokutnik, zaobljeni, elipsa, crta, boje `#RRGGBB`), `gradient` i `icon` (biblioteka ikona ili SVG tekst). **Barcode:** `ta_barcodebox` — `TaBarcode`, varijanta je vrsta koda (`code128`, `ean13`, `ean8`, `code39`, `itf`, `qr`, `pdf417`; kodira `ta_barcode`), vrijednost iz teksta ili polja, greška kodiranja u `Painter.Error`. **Chart:** `ta_chartbox` — `TaChart`, `bar`, `line`, `pie` (crta `DrawChart` kao izvješća) i `gauge` (mjerač); podaci su stavke `natpis=vrijednost` ili skup podataka (`LabelField`, `ValueField`); plan je TAChart, ali nije dodan paket. **Menu:** `ta_menu` — `TaMenu`, `side` (`TaSideMenu`), `toolbar` (`TToolBar`) i `tree` (`TTreeView`); stavke u zapisu bočnog izbornika, `OnAction(radnja)`. Smoke: `TestProgress` 12, `TestCalendar` 20, `TestImage` 19, `TestBarcode` 15, `TestChartFamily` 9, `TestMenu` 12 provjera. **Napomena o imenima:** obitelji Label, Button, Memo, Image, Chart i Barcode zadržale su imena iz plana (`TaLabel`, `TaButton`, `TaMemo`, `TaImage`, `TaChart`, `TaBarcode`) koja se još poklapaju s klasama u `ta_controls` koje koristi runner; jedinica koja koristi obje bira onu iz kasnije navedene jedinice, pa se stare moraju pisati `ta_controls.TaChart`. To nestaje kad runner pređe na obitelji. **Dopune nakon E11 (2026-11-11):** *Choice* ima varijantu `multisegment` i opcije `MinSelected`/`MaxSelected` (vrijede i za `check`); *List* ima `Options.MultiSelect` (list, iconlist); unutarnje kontrole ne prihvaćaju ime iz dizajnera kao natpis (nestaje "RadioGroup1"); *Grid* ima varijantu `entry` (Tab/Enter iz zadnje ćelije zadnjeg retka dodaje red) i podnožje zbrojeva `Options.SumFields`; *Pages* ima `accordion`; *Button* ima `image` (ikona, natpis je savjet), `menu` i `split` (stavke `Options.MenuItems`, događaj `OnMenuAction`); *Memo* `markdown` ima pregled `Options.Preview` (`MarkdownToRt`: naslovi, podebljano, kosa slova, natuknice). Nisu: Panel `scroll` i `splitter` (spremnik ne prenosi pomak, a splitter mora mijenjati susjeda domaćina), red filtara u Gridu.
**E12, korak 1 — paket `typhaccess_ext` (2026-11-11):** neobavezni pokretači, zasebni paket (`lazarus/typhaccess_ext.ctpkg/.lpk`, izvori `src/ext`) koji traži `lz_taChart` i `pl_RX`: `ta_ext_chart` (`TaTaChartEngine`, pružatelj `tachart`: bar, line i pie nad `TChart` i `TListChartSource`) i `ta_ext_grid` (`TaGridRxEngine`, pružatelj `rx`: sve četiri varijante mreže nad `TRxDBGrid`, pravo podnožje zbrojeva `fvtSum`, entry). Uključuje se s `SetPreferredProvider('tachart')` odnosno `'rx'`; bez paketa sve obitelji rade s LCL pokretačima (glavna aplikacija ga ne veže). Za to su obitelji dobile zajedničke osnove (`TaChartDataEngine`, `TaGridDataEngine`). Ispitivanje `tests/ext/run.sh` (zaseban program koji gradi `Ext.ctpr` iz `Smoke.ctpr`): 18 provjera, uključujući prebacivanje pružatelja tamo-amo.
**E12, korak 2 — klase svojstava i biblioteka objekata (2026-11-11, 19.7):** `ta_propclass`: klasa svojstava je imenovan skup (`_sys_propclasses`, JSON "svojstvo": "vrijednost"; svojstva: Format, Align, Bold, Italic, Locked, Tip, FontName, FontSize, ForeColor, BackColor, BorderWidth, CondFormat, VisibleIf, EnabledIf, Icon), kontrola je navodi svojstvom `PropertyClass` (Extra ključ `class`, u `PropMap`, `DefGet/DefSet` i Inspektoru), a **vlastita svojstva nadjačavaju** (klasa popunjava samo prazno); `TaFormRunner` je primjenjuje pri otvaranju (`ApplyPropClasses`). Grupe kontrola (`_sys_ctlgroups`): `ControlGroupSave` (položaj relativan prema lijevom gornjem kutu), `ControlGroupInsert` (pomak, prefiks, sudar naziva rješava brojkom). Biblioteka u datoteku: `LibraryExport`/`LibraryImport` (bez prepisivanja ili s njim). Dizajner: u popisu svojstava *PropertyClass* je padajući popis s *nova klasa iz ove kontrole…* (dijalog `RunPropClassDialog`: svojstva kontrole koja idu u klasu, spremi, obriši), a izbornik rasporeda ima *Spremi odabrane kontrole kao grupu…* i *Umetni grupu kontrola…* (`RunPickDialog`). Sistemske tablice `SysTables` imaju dvije nove. Smoke `TestPropClass` 23 provjere (uključujući pravi dijalog preko tajmera). **E12, korak 3 — dokumentacija:** `docs/PALETA.md` (stranice palete, tablica obitelji, varijante i opcije, veza na podatke, LOV i upit po formi, klase svojstava i biblioteka, neobavezni pokretači, ograničenja). **Nije u E12:** tamne inačice ikona palete (postoje 24/36/48 px za svijetlu temu), 4GL funkcije i kosturi u izvozu biblioteke (ostaju uz bazu/mapu), uređivač sadržaja biblioteke kao zasebna forma.
**Izvršitelj formi na obiteljima (2026-11-11):** `ta_famctl` — `TaFormRunner` sada za vrste TextBox, CheckBox, Button, ToggleButton, Label, Hyperlink, MemoBox, RichText, OptionGroup i ListBox stvara komponente obitelji (`TaEdit`, `TaCheck`, `TaButton`, `TaLabel`, `TaMemo`, `TaChoice`, `TaList`), pa **varijanta iz definicije radi i u izvršavanju** (svojstvo `Variant`/ključ `variant`: npr. TextBox s `currency` ili `lov`, CheckBox `switch`, OptionGroup `segmented`/`check`, Memo `markdown`; vrsta `Calendar` i `Progress` izvršitelj stvara ako su u definiciji). Kuke u `ta_controls` (`DefOf`, `ReadControlValue`, `WriteControlValue`, `IsBoundControl`) znaju za domaćine pa je ostatak izvršitelja ostao isti; domaćin nosi svoju `Def`. Stare kontrole ostaju za ComboBox (ključ/natpis + pretraga), Subform, TabControl, SideMenu, Image, Chart, Barcode i izvješća; isključivanje: `RunnerUsesFamilies := False` (glavni smoke skup ispituje stari put, `TestRunnerFamilies` i paritetni skup novi). **Paritet:** isti 21 slučaj + 5 binderskih daje isto **stanje** kontrola (neutralan ispis po vrsti, ne po razredu) s obiteljima; snimke zaslona su ponovno snimljene i pregledane (kvačica proširena do natpisa kao nekad, boje i veličine iste). **Nalazi:** (1) tema je crtala okvir oko svakog `QAbstractScrollArea` pa su svi vlastiti `TCustomControl`-i imali okvir — selektor sužen na tablice, popise, stabla i tekstna polja; (2) uvjetno oblikovanje i boja neispravnog pravila idu na unutarnju kontrolu (`StyleTarget`); (3) `LockControl` ostaje kao prije (tekst samo za čitanje, ostalo onemogućeno). Inspektor nudi svojstvo **Variant** (popis varijanti po vrsti, `VariantsForKind`); dizajner još crta stare kontrole pa se varijanta vidi tek u izvršavanju.
**Panel `scroll` i `splitter`, tamne ikone (2026-11-11):** `scroll` — domaćin pomiče vlastitu djecu (okomita i vodoravna traka kad je sadržaj veći od panela, kotačić miša, pomak se ne sprema u `.lfm`; u dizajnu su trake skrivene da raspored ostane netaknut); `splitter` — vučna crta (`TaSplitPaint`) čije povlačenje mijenja veličinu susjeda prema poravnanju domaćina (`alLeft`/`alRight`/`alTop`/`alBottom`, `Options.MinSize`, `DragSplitter` za skripte i testove). Smoke `TestPanel` 29 provjera. **Ikone:** `lazarus/make_dark_icons.py` izrađuje `resources/dark/` (tamni obrisi se posvijetle, zasićene boje ostaju) za svih 24 komponente × 3 veličine; `make_icons_res.py dark` sastavlja `ta_register.res` s njima, a `LIGHT_ICONS=dark bash light/install_in_ide.sh` gradi Light IDE s tamnim ikonama (po završetku vraća svijetli `.res`, repozitorij ostaje svijetao); provjereno u IDE-u (paleta s tamnim ikonama).
**ComboBox na obitelji Edit (2026-11-11):** combo/droplist pokretač je sada `TaComboBox` (ključevi i pretraživanje iz `ta_controls`) s opcijama `TaComboOptions.Keyed` (stavke `ključ=natpis`: vrijednost polja je ključ, popis pokazuje natpise, `Text` vraća ključ) i `Search` (popis se sužava tipkanjem; `EnableSearch`); u definiciji ključevi `keyed` i `search`. Izvršitelj stvara ComboBox kao `TaEdit` (varijanta `combo`, a `droplist` se može zadati svojstvom *Variant*); izvor `list:` s parovima, `sql:` ili SELECT s dva stupca je ključan, jedan stupac je običan popis. `LockControl` kao prije (kontrola se onemogući). Paritet: stanje svih 21 slučaja isto, snimka 05 razlikuje se za 2 px visine. Smoke `TestRunnerCombo` 9 provjera.
**Dizajner formi na obiteljima (2026-11-11):** `FamilyControlFor(..., ADesign)` stvara iste komponente kao izvršitelj, s pregledom (polje se vidi kao `[naziv]`, popisi i izbori imaju primjere, Progress 40 %, sve samo za čitanje); dogadaji misa unutarnjih kontrola idu dizajneru kao da su na domaćinu (`FamilyHookMouse`: odabir, povlačenje, mijenjanje veličine, hvatanje miša); promjena svojstva gradi domaćina iznova iz definicije na istom mjestu i u istom z-redoslijedu (`RebuildFamily`), pa se **varijanta vidi odmah**. Stare kontrole ostaju za Image, Chart, Barcode, Subform, TabControl, SideMenu, Rectangle, Line. **Nove vrste u paleti dizajnera:** `Calendar` i `Progress` (ikone `c_calendar`, `c_progress`, zadane veličine, svojstva u Inspektoru: Days; Min, Max, WarnAt, DangerAt). **Paleta dizajnera je razvrstana:** unos podataka (TextBox, MemoBox, RichText, ComboBox, CheckBox, OptionGroup, ListBox, Calendar), prikaz (Label, Hyperlink, Image, Chart, Barcode, Progress), radnje (Button, ToggleButton), razmještaj i navigacija (Subform, TabControl, SideMenu), oblici (Rectangle, Line). Inspektor ima i opcije obitelji kao svojstva: Preview (Memo), MenuItems (Button), MultiSelect (ListBox), Columns, MinSelected, MaxSelected (OptionGroup). `PropMap` ima 59 svojstava. Smoke `TestDesignerFamilies` 13 provjera; snimka `tests/dzshot/run.sh`. **Nije:** Panel i Pages kao vrste dizajnera (traže spremnik kontrola).
**Image, Chart i Barcode na obiteljima (2026-11-11):** izvršitelj i dizajner stvaraju `TaImage`, `TaChart` i `TaBarcode` iz obitelji (nazivi se podudaraju sa starim klasama u `ta_controls`, pa izvršitelj kroz `ta_famctl` pristupa preko `FamilyKindOf`, `FamilySetPicture`, `FamilySetChartData`, `FamilySetBarcode`, `FamilySetDblClick`, `FamilySetPopup`). Slika iz polja ide u painter (`SetPicture`, prazno polje briše sliku), statična slika iz definicije (`picture`: base64 ili `file:`) učitava se pri stvaranju, dvoklik i izbornik *Odaberi/Ukloni sliku* rade i preko unutarnjih kontrola. Grafikon i dalje čita `RowSource` u izvršitelju, a podatke šalje pokretaču. Inspektor ima Variant za Image (picture, shape, gradient, icon), Chart (bar, line, pie, gauge) i Barcode (code128, ean13, ean8, code39, itf, qr, pdf417); `ChartType` i `BarType` ostaju u skladu s njim, a `Variant` ima prednost kod čitanja barkoda. Dizajner pokazuje primjer podataka (grafikon A-D, barkod `TyphAccess`/EAN). Smoke `TestRunnerDisplayFamilies` 9 provjera. **Rectangle i Line** su sada oblik obitelji Image (varijanta shape): Rectangle ima okvir u boji teksta, širinu `BorderWidth` i ispunu `BackColor` (bez nje ispuna `none` = prozirno), Line je puni pravokutnik u boji teksta kao prije. Stare kontrole ostaju samo za Subform, TabControl i SideMenu.
**Povlačenje u Panel/Pages i maska unosa (2026-11-11):** kad se povlačenje kontrole u dizajneru formi završi iznad Panela ili Pages-a (najmanji pogon ispod kursora), kontrola (i odabrana skupina) prelazi u njega i ostaje na istom mjestu na zaslonu (`MoveToContainer`, `FinishDragDrop`); povlačenje izvan pogona vraća je na formu; provjereno stvarnim mišem u Xvfb-u. Povlačenje u stari TabControl (na aktivnu stranicu) radi i ono. Maska unosa: `ta_mask` (9 znamenka, A slovo, X slovo/znamenka, ostalo fiksno; `ApplyMask`, `MaskComplete`), svojstvo `Mask` obitelji Edit (isti put kao `MaxLength`), ključ `mask` u definiciji kontrole i u rječniku, polje u dijalogu svojstava polja, nepotpun unos blokira spremanje. Smoke 15 provjera.

**Panel u dizajneru i izvršitelju (2026-11-11):** vrsta `Panel` (varijante plain, group, card, expander, scroll, splitter; svojstva Expanded i MinSize; ikona `c_panel`) je pogon: djeca imaju `container=<naziv panela>` (isti ključ kao kod TabControl, stranica 0) i roditelj im je domaćin panela. U dizajneru se kontrola iz palete ispušta klikom na panel, svojstvo Container premješta kontrolu, brisanje panela briše i djecu, a promjena varijante gradi panel iznova i prebacuje djecu na novog domaćina. Izvršitelj traži pogon i među obiteljima. **Pages u dizajneru i izvršitelju (2026-11-11):** vrsta `Pages` (tabs, list, steps, accordion; popis stranica u RowSource `Prva;Druga`, svojstvo ActivePage, ikona `c_pages`) je pogon kao Panel: djeca imaju `container=<naziv>` i `page=<indeks>`, a roditelj im je domaćin. Vidljiva je samo aktivna stranica (`FamilyShowPages`; promjenu stranice klikom javlja domaćin, a izvršitelj pri VisibleIf poštuje stranicu preko `FamilyPageHidden`). Ispuštanje iz palete na Pages ide na aktivnu stranicu. Programsko postavljanje `ActivePage` i dalje ne javlja OnChange (ugovor obitelji), pa kod mora pozvati `FamilyShowPages`. **Nije:** povlačenje postojeće kontrole u Panel/Pages mišem (samo svojstvom Container i Page).

**E11 (paleta) završena osim:** runner još stvara stare kontrole, `entry` i footer-sum u Gridu, `scroll`/`splitter`/`accordion`, `image`/`menu`/`split` gumb, SVG varijanta pregleda u Image, TAChart pokretač i Memo `markdown` pregled.
- **E10 (korak 1 gotov 2026-11-10: osnovni snimak ponašanja):** `tests/parity/` (`parity.pas`, `run.sh`, `golden/`): 20 definicija formi kroz `TaFormRunner` s istim scenarijem (otvaranje, kretanje, izmjene, spremanje, greške, brisanje), nakon svakog koraka stanje svih kontrola (vrijednost, vidljivost, omogućenost, boje), položaj zapisa, poruke korisniku, stanje tablica i snimka zaslona; usporedba teksta i PNG-a bajt po bajt, tri uzastopna pokretanja daju isti rezultat. Za ispitivanje je u `TaFormRunner` dodan `OnRunnerConfirm` (potvrda brisanja bez dijaloga) i svi `ShowMessage` idu preko `Notify`. **Nalazi:** `[kvačica] = 1` je bila laž (logička vrijednost se brojala kao Access-ov True = -1) — **riješeno po odluci korisnika: označena kvačica = 1, prazna = 0** (`AsNum(True) = 1`; `Not/And/Or` ostaju logički; smoke `TestBoolSemantics`, 8 provjera; parity slučaj 03 ponovno snimljen); pristupno kršenje u `TDBGrid.GetDefaultWidth` pri oslobađanju forme s mrežom (5 slučajeva) — **popravljeno 2026-11-10**: `TaFormRunner.Destroy` i `TaSubInfo.Destroy` odvajaju izvor podataka i poništavaju polja stupaca prije oslobađanja upita; iznimka u događaju sada je neuspjeh paritetnog skupa. **Korak 2 (2026-11-10):** `ta_bindengine` (`TaBindingEngine`: `Condition`, `RuleFailed`, `Style`, `Value`) izdvojen i priključen u `TaFormRunner` i `TaFormBinder` za vidljivost, omogućenost, uvjetno oblikovanje i pravila; `run.sh` uspoređuje i isti scenarij kroz `TaFormBinder` s istim snimkama (slučajevi 02, 03, 04, 18), 8 smoke provjera za stroj; usporedba je otkrila i ujednačila razlike binder/runner (kvačica 0/1, `#Err` za neispravan izraz, izračun samo za čitanje i prema `Format`, brojevi bez nametnutih decimala). **Korak 3 (2026-11-11):** u `TaBindingEngine` prebačeni zadane vrijednosti, `CalcRules` (parser i izračun, koriste ih runner, mreža podforme i `TaRowsView`), `AutoFill` (parser i dohvat, forma i mreža) i `Validation` runnera (`RuleFailed`); `TestBindEngine2` 15 provjera; binder-usporedba i za slučaj 06. **Odlučeno:** runner, kao i binder, boji polje s prekršenim pravilom odmah (`RuleBadColor`, prednost nad uvjetnim oblikovanjem; boja nestaje kad vrijednost zadovolji pravilo). **Korak 4 (2026-11-11), obrazac (19.3, 19.4, 19.8):** `TaRecordState` (`spremljen`, `novi`, `promijenjen`, `upit`; `RecordState`/`StateText`, prikazano uz oznaku zapisa), zatvaranje promijenjene forme pita *Spremiti promjene?* (`AskRunner`/`OnRunnerConfirm`); **upit po formi**: `EnterQuery` prazni polja, uzorci (`Ma*`, `>100`, `10..20`, datum, prazno, isti `ColumnFilterSql` kao filtri stupaca) postaju `WHERE`, `ExecuteQuery` izvršava (bez rezultata vraća prethodni filtar uz poruku, neispravan uzorak ostaje u upitu), `CancelQuery`, `clearquery`; u upitu su kretanje i spremanje zabranjeni, uzorci ne čine formu "promijenjenom" i ne pokreću pravila; **tipkovnički standard** preko `ta_keymap` (isti kao neprekidna forma, promjenjiv): PgDn/PgUp/Ctrl+Home/End kretanje, Ctrl+N novi, F10 i Shift+Enter spremi, Ctrl+Delete briši, F7 upit, F8 izvrši, Esc odustani, Enter iduće polje (ne u višeretkovnim poljima); **navigacijska traka** ima gumbe Upit i Izvrši iza oznake zapisa; prikaz izračunatih polja (`Display`) u stroju; parity slučaj 21, `TestRunnerKeys` 24 provjere. Ctrl+↓/Ctrl+↑ iz 19.8 nisu u zadanim tipkama (Ctrl+↑ bi brisao bez pitanja u neprekidnoj formi), mogu se postaviti u `tipke.json`. **Nalaz:** paket `typhaccess_core` kroz `ta_components` → `ta_reportdesign` koristi jedinice iz `src/editors` (ciklus gui ↔ editors iz E0); pri promjeni zajedničkog sučelja (npr. `ta_keymap`) čist prijevod puca dok se ne doda `--opt=-Fu src/editors` (`light/install_in_ide.sh` to sada radi). **Ciklus gui ↔ editors razbijen (2026-11-11):** uzrok je bila samo jedna jedinica — IDE komponenta `ta_contcomp` bila je u paketu `core`, a koristi `ta_components` koji povlači `ta_reportdesign` i dijaloge iz `editors`. Premještena je u `typhaccess_dsgn` (gdje je i registrira `ta_register`); `core` više ne ovisi o `editors`, redoslijed gradnje je `core → editors → dsgn`, zaobilaznica `--opt=-Fu src/editors` uklonjena iz `light/install_in_ide.sh`; čist prijevod sva tri paketa, aplikacije, smoke (`fails=0`) i paritet (21 + 5, 0 razlika) prolaze. **Upit po formi u tablici (2026-11-11):** F7 (ili gumb *Upit* uz *Filtri...*) otvara traku s poljem za uzorak po vidljivom stupcu, predpunjenu aktivnim filtrima; F8/Shift+Enter izvršava (isti `ColumnFilterSql`, bez rezultata vraća prethodne filtre, neispravan uzorak ostaje u upitu), Esc zatvara; prazno polje uklanja uvjet. U neprekidnoj formi i dalje služe filtri u zaglavlju. Smoke `TestGridQuery` 10 provjera. **LOV (F9) na obrascu (2026-11-11, 19.5):** kontrola dobiva svojstva `lov` (izvor: tablica, `sql:`, `list:` ili `fgl:`), `lovmap` (`polje_izvora=kontrola;...`, izbor upisuje više polja odjednom; bez toga samo vlastito polje) i `lovvalidate=1` (pri spremanju odbija vrijednost kojoj nema u popisu, bez obzira na velika/mala slova). F9 (nova radnja `Lov` u mapi tipki, promjenjiva) otvara dijalog `ta_lovdlg` (`RunLov`: pretraga upisom po svim stupcima, strelice, Enter/dvoklik odabire, Esc odustaje; u memoriji do 20.000 redaka, pa isto radi za sve vrste izvora). Za testove `OnRunnerLov`. Smoke `TestLov` 10 provjera (uključuje pravi dijalog preko tajmera). **LOV dopuna (2026-11-11):** (1) **dizajner:** TextBox ima svojstva `Lov`, `LovMap`, `LovValidate` (tablica `ta_propmap` i `DefGet/DefSet`, 46 svojstava), a forma svojstvo `GridLov`; (2) **gumb "..."** uz polje s `lov` u pokretaču (uz F9); (3) **LOV po ćeliji tablice:** `GridLov` = `polje | izvor | izvor_polje=polje_tablice;...` (unosi odvojeni s `;;`), F9 na ćeliji tog stupca otvara popis i upisuje više stupaca u red (u izmjeni); (4) **varijanta `lov` na `TaEdit`** (`TaLovOptions`: `Source`, `Map`, `Validate`; polje s gumbom `TEditButton`, F9, događaj `OnLov`, spremanje u `.lfm` i `TaControlDef` kroz ključeve `lov/lovmap/lovvalidate`), a `TaFormBinder` ga sam priključuje na bazu (`RunLov`, upis u ciljne kontrole preko pokretača pa u polja, provjera iz popisa pri `BeforePost`). `LovPickHook` zamjenjuje dijalog u testovima. Smoke: `TestLov` 15, `TestBinderLov` 5 provjera. **LOV u neprekidnoj formi (2026-11-11):** `TaRowsView` rukuje akcijom `Lov` (F9 u živoj ćeliji čiji `Def` ima `lov`): upisuje preslikane vrijednosti kroz `SimulateEdit` (pa se pokreću i pravila izračuna), `lovvalidate` provjerava pri `CommitRow`. Da jezgra (paket `core`) ne ovisi o `editors`, dijalog se registrira u `ta_source.LovPicker` iz `ta_lovdlg` (`PickLov`). Smoke `TestRowLov` 7 provjera. **Light IDE** ponovno izgrađen i pokrenut u Xvfb-u: projekt s neprekidnom formom se učitava, a `TaEdit` s `Variant = evLov` i `Options.*` iz `.frm` crta polje s gumbom "..." u dizajneru (snimka); uređivanje svojstava mišem nije isprobano. **Builder (2026-11-11):** gumb "..." na svojstvima `Lov`/`LovMap` otvara `RunLovBuilder` (izvor iz popisa tablica i upita ili upisan, do 5 parova *stupac izvora → kontrola forme*, kvačica *Dopusti samo vrijednosti iz popisa*; piše sva tri svojstva), a na `GridLov` forme `RunGridLovBuilder` (stupac tablice → izvor → parovi stupaca; pamti unose više stupaca, *Ukloni za stupac*). Pomoćne `GridLovEntry`/`GridLovSet`. Smoke `TestLovBuilder` 6 + `TestLovBuilderDialogs` 3 provjere (pravi dijalozi preko tajmera). **Gumb "..." u neprekidnoj formi:** živa ćelija s `lov` postaje `TaEdit` varijante `evLov` (polje s gumbom, `OnLov` → `ShowLov`); F9 u pokretaču `lov` radi samo kad domaćin nema `OnInnerKeyDown` (u neprekidnoj formi tipke ostaju u mapi tipki). Smoke `TestRowLov` 10 provjera. **Nije još:** builder nije isproban rukom u IDE-u.
- **E7 (gotovo 2026-11-10, dva ulaza i čarobnjak za kosture):** `ta_skelflow` (tok bez sučelja: *od podataka* = tablica → kosturi poredani po prikladnosti u postocima; *od kostura* = popis po kategorijama; utori se pune iz baze, promjena utora vraća ovisne utore na zadano; provjera `--check`; spremanje u bazu i/ili datoteku; brojač klikova), `ta_skelwizard` (`TfrmSkelWizard`: dva načina u jednom prozoru, pitanja po vrsti utora, pregled 4GL-a u `TaEditor` s označenim greškama, *Spremi u bazu / u datoteku*), `@kontekst` u kosturima (gumb/unos/izvor/izvješće → `ForContext`), 13. kostur *Izvor podataka za popis* (koristi se kao `fgl:`), izbornik Skripta: *Novi program iz kostura…* i *Predloži programe za tablicu…*, retci desnog klika na `TaDatabase`. Test: iz prazne baze s 3 tablice 5 programa u točno 15 klikova, svi prolaze `--check`; dijalog testiran bez zaslona. **Blok-čarobnjak (19.2) gotov 2026-11-10:** `ta_blockwiz` (tablica + raspored obrazac / dva stupca / tablica / obrazac i tablica → forma preko `BuildFormEx`: datum, kvačica, memo, strani ključ kao padajući popis iz povezane tablice, podforme iz stranih ključeva; popis *Što će nastati*) i `ta_blockdlg` (izbornik Skripta *Nova forma nad tablicom (blok)…*, redak na `TaDatabase`); test `TestBlockWizard`. **Ostaje:** navigacijska traka (E10, 19.8), provjera dijaloga u stvarnom GUI-ju (snimka zaslona), pregled/izmjena kostura u E9.
- **E6 (gotovo 2026-11-10, kosturi):** `ta_skeleton` (parser `.4glt`, knjižnica iz mape `skeletons/`, vrste utora, zadane vrijednosti iz metapodataka baze: `sviOsimId`, `kljuc`, `imaFk`, `ciljFk(utor)`, izgradnja teksta s `{utor}`, formatima `:lista :tablicno :ispis :zapis :postavi :vrijednosti :tip :naslov` i blokom `@each ... @end`, preduvjeti i ocjena prikladnosti za tablicu) i **12 kostura** u `skeletons/`: Popis s filtrom, Pregled u mreži, Unos i izmjena zapisa, Master-detalj, Zbroj po grupi, Zbroj po razdoblju, Masovna izmjena s brojačem, Sljedeći broj dokumenta, Arhiviranje, Izvoz tablice u PDF, Brisanje s provjerom veza, Izbornik nad tablicom. Test (`TestSkeletons`): svih 12 nad dvije različite tablice prolazi `--check`; 10 se izvršava s provjerom rezultata (zbrojevi po grupi i po mjesecu/godini, sljedeći broj, izmjena i broj redaka, arhiviranje u transakciji, pretraga CONSTRUCT, unos i izmjena kroz INPUT, master-detalj, brisanje s odbijanjem, izbornik, PDF); vlastiti `.4glt` u mapi radi bez prevođenja. **Odstupanja od plana:** umjesto "Izvoz izvješća u PDF" je "Izvoz tablice u PDF" (4GL ne može pozvati spremljeno izvješće), umjesto "Uvoz iz CSV" (4GL nema čitanje datoteka) je "Pregled u mreži", umjesto "Poravnanje stavki" (specifično za SmartBet) je "Brisanje s provjerom veza", umjesto "Izbornik programa" je "Izbornik nad tablicom". **Ostaje:** sučelje čarobnjaka za kosture (E7), pregled generiranog 4GL-a i spremanje u bazu i/ili datoteku (E7), uređivač kostura i predlošci dopune u Editoru (E9), utori `program/izvjesce/forma` nisu korišteni u ugrađenim kosturima.

### 14.1 Raspored prvih tjedana

| Tjedan | Etape | Vidljivo |
|---|---|---|
| 1 | E0, E1 | galerija u temi Plava i Zelena; font JetBrains Mono |
| 2 | E2, E3 | prototip Edit; Light profil |
| 3 | E4, E5 | `fgl:` izvor; Editor sa SynEditom |
| 4 | E6, E7 | kosturi i čarobnjak |
| 5 | E8, E9 | blokovi; isti dijalozi u oba okruženja |
| 6–7 | E10 | paritet |
| 8–12 | E11, E12 | cijela paleta |

Redoslijed E4–E9 (4GL) i E10 (stroj) može se zamijeniti ako je identičnost važnija od brzog vidljivog rezultata.

---

## 15. Provjera i kontrola kvalitete

| Vrsta | Kako | Gdje |
|---|---|---|
| Smoke test | postojeći `tools/smoke.sh`; svaka etapa dodaje provjere | `tests/smoke.pas` |
| Tema | galerija PNG u svim temama i varijantama; test da nema boje izvan tokena | `tests/theme_gallery/` |
| Kosturi | svaki kostur × barem 2 tablice → `--check` i izvršenje | `tests/skeletons/` |
| Izvori podataka | `fgl:` rezultat naspram ekvivalentnog SQL-a | smoke |
| Paritet ponašanja | ista definicija kroz runner i binder | `tests/parity/` |
| Izgled | offscreen PNG usporedba reprezentativnih formi | `tests/shots/` |
| Dijalozi | niz radnji u oba okruženja → isti zapis svojstva | smoke + skripta |
| Unatrag kompatibilnost | SmartBetTA, Trgovina Jadran prolaze nepromijenjeni | smoke + deploy skripta |
| Deploy | `izradi_deploy.sh` i `--run` programa iz baze nakon svake etape | `SmartBetTA/` |
| Prihvaćanje obitelji | 12.3 (osam točaka) | po obitelji |

---

## 16. Rizici

| Rizik | Vjerojatnost | Ublažavanje |
|---|---|---|
| Izdvajanje stroja iz `TaFormRunner` (3171 redak) razbija postojeće forme | srednja | paritetni testovi **prije** preinake, postupno prebacivanje po svojstvu |
| `fgl:` izvori usporavaju formu | srednja | predmemorija po parametrima, requery samo uz promjenu parametra, ograničenje vremena |
| Domaćin pokretača otežava dizajnerske ručke i tabulatore | srednja | prototip Edit (E2) prije svega ostalog; alternativa jedna klasa nad `TCustomComboBox` |
| Svojstva ovisna o varijanti u Inspektoru | niska | podobjekt `Options`; alternativa kategorije i opis |
| Tema se ne primjenjuje na neku kontrolu na Qt6 | srednja | `RecolorForm`; kontrola koja prolazi M1, a pada M2, ostaje izvan zadane palete |
| Vlastito crtanje (switch, ring, led, card) izgleda drukčije od Qt kontrola | srednja | iste mjere i stanja (6.4), galerija |
| Monospace font čini forme šire | srednja | provjera u galeriji, prilagodba zadanih širina |
| SynEdit/RX/TAChart povećavaju binarnu datoteku i vrijeme prevođenja | niska | mjeriti u E5 i E11 |
| RX i TAChart pod Qt6 ponašaju se drukčije od LCL | srednja | probni projekti (M1), posebni testovi, rezervni LCL pokretač za Grid |
| Preimenovanje boja (`#C00000` → `danger`) mijenja izgled postojećih aplikacija | niska | stare boje ostaju u zapisima; tokeni vrijede za nove i za ono bez vlastite boje |
| Format kostura prerano zamrznut | srednja | `@format 1`, tolerantan parser |
| Održavanje izvedenog IDE-a kroz nove verzije CodeTyphona (B) | srednja | ostati na stupnju 1 dok je moguće |
| Licenca i naziv Light IDE-a | srednja | provjeriti prije javne distribucije |
| "Light" razočara bez Lazarusovih mogućnosti | niska | jasna poruka: za više, puni IDE s istom paletom |
| Opseg (50 dana) | visoka | etape su samostalne; nakon svake demo i odluka o nastavku |

---

## 17. Odluke iz poglavlja 17 (zatvoreno 2026-11-07)

Korisnik je potvrdio preporuke; kod "ili" pitanja (2 i 5) odluka je **oboje**.

| # | Pitanje | Odluka |
|---|---|---|
| 1 | Kosturi: kod ili datoteke? | **datoteke** `.4glt` u mapi `skeletons/` (uz program i uz bazu), uz ugrađeni zadani skup |
| 2 | Gdje se sprema generirani 4GL? | **i baza (`_sys_programs`) i datoteka**; čarobnjak nudi oba, a sinkronizacija je izričita (spremi u bazu / izvezi u datoteku / uvezi iz datoteke) |
| 3 | Uređivanje iz `fgl:` izvora | samo čitanje u prvoj fazi, `ON SAVE` u E8 |
| 4 | Redoslijed | tema i Edit prvo (E1–E2), zatim 4GL |
| 5 | Forma: `.lfm` ili JSON? | **oboje**: JSON u bazi ostaje izvorni zapis TyphAccessa, a `.lfm` (LCL tok) je izvorni zapis u CodeTyphonu; dvosmjerna pretvorba JSON ↔ `.lfm` postaje dio plana (vidi 17.1) |
| 6 | Light IDE | stupanj 1 (E3); odluka o stupnju 2 nakon E7 |
| 7 | Samostalni `.exe` | oboje: runtime kao zadano, `.exe` kao izbor |
| 8 | Naziv | radno "Typhon Light"; pravno provjeriti prije javne objave |
| 9 | Ograničenja izvora | 5 s, 100.000 redaka, kao postavke |
| 10 | Prvi korisnici | slagač aplikacija, zatim programer Pascala |

### 17.1 Dvosmjerna pretvorba forme (JSON ↔ `.lfm`)

- Obitelji su prave Lazarus komponente s objavljenim svojstvima (poglavlje 12), pa im `.lfm` tok radi sam. `TaPropMap` (8.1) je ujedno tablica pretvorbe: isti redak preslikava svojstvo između JSON definicije i komponente.
- **Dodaje se u etapu E2** (nakon prototipa Edit): `FormToLfm` i `LfmToForm` za obitelj Edit, s testom kruga (JSON → `.lfm` → JSON daje isti zapis). Ostale obitelji dobivaju pretvorbu kako se pretvaraju (E11).
- **Pravilo izvora istine:** forma ima jedan izvor po projektu (baza ili `.lfm`); drugi zapis se **izvozi** na zahtjev, ne vodi se usporedno automatski, da se izbjegnu razilaženja.
- Stara pitanja o prenosivosti (Z10) time su obuhvaćena; rizik: svojstva koja TyphAccess ima, a Lazarus nema (npr. `Extra` ključevi) idu u objavljeno svojstvo `Extra` ili se čuvaju kao komentar u `.lfm`; to se utvrđuje prototipom Edit.

---

## 18. Arhiva i rječnik

### 18.1 Što je objedinjeno

| Raniji dokument | Gdje je sada |
|---|---|
| `PLAN-paleta-i-vizualno-programiranje.md` | poglavlja 1, 2, 7–11, 14–16 |
| `PLAN-univerzalne-kontrole.md` | poglavlje 3 |
| `PLAN-paleta-izbor-tema-komponente.md` | poglavlja 3, 4, 5, 6, 12 |
| `PLAN-light-ide.md` | poglavlje 13 |

Stari dokumenti su u `docs/arhiva/` samo radi povijesti; vrijedi ovaj plan.

### 18.2 Rječnik

| Pojam | Značenje |
|---|---|
| **Obitelj** | jedna kontrola palete s više varijanti |
| **Varijanta** | način rada obitelji (`Variant`) |
| **Pokretač** (`IaEngine`) | stvarna kontrola ispod obitelji (LCL, RX, TAChart, SynEdit...) |
| **Kostur** | `.4glt`: 4GL s tipiziranim utorima koji se pune iz baze |
| **Utor** | mjesto u kosturu koje se popunjava |
| **Izvor** (`TaSourceDef`) | tekst koji kaže odakle kontrola uzima podatke |
| **`fgl:`** | izvor koji pokreće 4GL program i uzima njegove retke |
| **`fglv:` / `Fgl()`** | 4GL funkcija koja vraća jednu vrijednost |
| **Sloj A / B / C** | jezgra / dijalozi i čarobnjaci / sučelja (IDE i dizajner) |
| **Light** | TyphAccess dizajner i runtime bez CodeTyphona |
| **Light IDE (Typhon Light)** | IDE (ili profil) samo s našom paletom |
| **`TaBindingEngine`** | zajednički stroj ponašanja |
| **Token** | imenovana vrijednost teme (boja, polumjer, font...) |
| **Naglasak** (`accent`) | jedina boja iz koje se izvodi cijela tema |

---

## 19. Inspiracija: Oracle Forms / Developer 2000 (PRIHVAĆENO 2026-11-07)

Oracle Forms (Developer 2000, uz Reports i Graphics) je desetljećima bio mjerilo za "bazu podataka s ekranima": forma se slaže nad tablicom, a velik dio ponašanja dolazi gotov. Naš plan već pokriva velik dio (blokovi i kosturi, 4GL kao jezik, izvješća, izrazi). Ovo poglavlje preslikava ideje Forms-a na naš plan i bira što uzimamo, a što namjerno ne.

### 19.1 Preslikavanje pojmova

| Oracle Forms | Što je | Naš ekvivalent danas | Prijedlog |
|---|---|---|---|
| **Data block** (blok nad tablicom) | skup polja vezan za tablicu, s gotovim ponašanjem (upit, unos, izmjena, brisanje) | forma + `TaSubform`, kostur *Unos i izmjena zapisa* | **Blok** kao jedinica u čarobnjaku: jedan klik daje blok s poljima, navigacijom i zadanim ponašanjem (19.2) |
| **Master-detail** (relation objects) | veza blokova s koordinacijom (promjena glavnog zapisa osvježava detalj, zabrana brisanja s detaljima) | `LinkMaster`, kostur *Master-detail* | svojstva veze: *brisanje s detaljima: zabrani / kaskadno*, *odgođeno ili odmah osvježavanje*; generira se iz stranog ključa |
| **Triggeri** (`WHEN-VALIDATE-ITEM`, `PRE-INSERT`, `POST-QUERY`, `ON-ERROR`, `KEY-*`...) | PL/SQL na događajima, na razini stavke, bloka ili forme | `OnClick`/`OnChange`/`OnDblClick`, `Rule` | **standardni događaji** u radnjama (`fgl:`): `BeforeInsert`, `AfterQuery`, `ValidateItem`, `OnError`, `OnKey`, uz **hijerarhiju** stavka → blok → forma (19.3) |
| **Built-ins** (`GO_BLOCK`, `EXECUTE_QUERY`, `COMMIT_FORM`, `NEXT_RECORD`, `SET_ITEM_PROPERTY`, `SHOW_LOV`, `CALL_FORM`...) | gotove procedure za upravljanje formom | radnje (`openform:`, `msg:`, `goto:`) | **standardne 4GL procedure forme** s istim imenima po značenju (19.3), blokovi u uređivaču blokova |
| **Enter-Query / Execute-Query** | pretraga unosom uzorka izravno u polja forme (F7 pa F8) | `CONSTRUCT` u 4GL-u | **Upit po formi** kao način rada obitelji Grid i forme (19.4) |
| **LOV** (List of Values) + **record group** | skočni popis s filtriranjem, vraća više stupaca u više polja | varijanta Edit `lookup`/`combo` | varijanta Edit **`lov`** (19.5); record group = imenovani izvor `TaSource` |
| **Alert** (stop/caution/note, do 3 gumba) | standardni dijalog poruke | `msg:` | radnja `alert:` s razinama i gumbima; dijalog `EditAlert` |
| **Parameters / globals** (`:PARAMETER`, `:GLOBAL`) | prijenos vrijednosti među formama | `openform:` s filtrom | parametri forme i globalne varijable 4GL-a, **uz ograničenje** (19.6) |
| **Visual attribute** | imenovani skup boja/fonta za višekratnu uporabu | tokeni teme | **imenovani stilovi** (npr. `Obavezno`, `Upozorenje`) nad tokenima teme |
| **Property class** | imenovani skup svojstava koji se primjenjuje na više stavki | – | **Klase svojstava** (19.7): jednom definiraš "polje iznosa" (format, desno, rule), primijeniš na sve |
| **Object library / PL/SQL library** | zajednička biblioteka objekata i koda | kosturi `.4glt` | **biblioteka objekata** (kontrole, forme, klase svojstava, 4GL funkcije) koju dijele projekti |
| **Object Navigator** | stablo svih objekata projekta | izbornik objekata aplikacije | stablo u Light IDE-u (stupanj 1 ga može imati kao zaseban prozor) |
| **Standardni izbornik i F-tipke** | `Action, Edit, Query, Record, Block, Field`; F7 upit, F8 izvrši, F10 spremi... | djelomično | **tipkovnički standard forme** (19.8) |
| **Status zapisa** (NEW, QUERY, CHANGED, INSERT) i **commit** pri izlazu | forma zna je li prljava i pita "Spremiti promjene?" | djelomično | **stanje forme** u `TaBindingEngine` (19.3) |
| **Data Block Wizard / Layout Wizard** | čarobnjaci "nad tablicom" | skeleton wizard, "od podataka" | već planirano (poglavlje 11); Layout wizard = izbor rasporeda (stupci/obrazac/tablica) |
| **Reports:** data model s grupama, **break** grupe, **matrix**, predlošci, ***Graphics*** | izvješća s grupiranjem i križnim tablicama | vlastiti motor izvješća, `grafikoni` | kasnije: *Report wizard* sa stilovima (tablični, grupe lijevo, matrica) |

### 19.2 Blok kao jedinica

*Nova forma nad tablicom* (čarobnjak, već u "Poslije") postaje **Blok-čarobnjak**: odabereš tablicu i raspored (obrazac, tablica, obrazac + tablica), dobiješ polja s varijantama po tipu stupca (datum → `date`, strani ključ → `lov`, logički → `switch`), navigacijsku traku (19.8), master-detail iz stranih ključeva i zadane događaje. Sve je običan JSON/`.lfm` i 4GL; ništa skriveno.

### 19.3 Događaji, ugrađene procedure i stanje forme

- **Događaji** (radnja `fgl:` na svojstvu): `AfterQuery` (obračunati polja po učitavanju), `ValidateItem` (provjera polja, uz postojeći `Rule`), `BeforeInsert`/`BeforeUpdate`/`BeforeDelete` (može odbiti), `AfterCommit`, `OnError` (pretvara tehničku grešku u poruku), `OnKey`. **Hijerarhija:** događaj na stavci nadjačava događaj bloka, a on događaj forme; svojstvo `Mode: nadjačaj / prije / poslije` kao u Forms-u.
- **Standardne procedure** u 4GL-u, imenovane po Forms-u radi prepoznatljivosti: `GoBlock`, `GoItem`, `NextRecord`, `PreviousRecord`, `FirstRecord`, `LastRecord`, `CreateRecord`, `DeleteRecord`, `EnterQuery`, `ExecuteQuery`, `CommitForm`, `ClearForm`, `ShowLov`, `SetItemProperty`, `GetItemProperty`, `OpenForm`. Većina već postoji kao radnje; ujednačuje se imenovanje i dodaju blokovi u uređivač blokova.
- **Stanje forme/zapisa** u `TaBindingEngine`: zapis je `novi`, `upit`, `promijenjen`, `spremljen`. Zatvaranje prljave forme pita *Spremiti promjene?* (Forms to radi samo), a statusna crta prikazuje stanje, broj zapisa i poruku.

### 19.4 Upit po formi (Enter-Query)

Tipka *Upit* prebacuje formu u način u kojem su sva polja prazna i unosiš **uzorak** (`Ma*`, `>100`, `01.01.2026..31.01.2026`, `is null`), a *Izvrši* (`ExecuteQuery`) puni blok. Ispod je isti mehanizam kao `CONSTRUCT`, pa uzorci postaju `WHERE`. Radi na obitelji **Grid** (filter-red već planiran) i na obrascu. Prednost za korisnika: nema posebne forme za pretragu.

### 19.5 Varijanta Edit `lov`

Polje s tipkom (ili F9) otvara skočni popis s filtriranjem upisom, a izbor **upisuje više stupaca u više polja forme** (npr. šifra artikla → naziv, cijena, PDV). Izvor je `TaSourceDef` (tablica, SQL ili `fgl:`), `ValidateFromList` odbija vrijednost koje nema u popisu. Razlika od običnog `lookup`: povratne stavke i potpuni popis s pretragom, ne samo padajući izbor. U `TRxDBGrid` varijanti `entry` isti LOV vrijedi po ćeliji (stavke računa).

### 19.6 Što namjerno NE preuzimamo

| Forms | Zašto ne |
|---|---|
| Globalne varijable `:GLOBAL` kao uobičajen prijenos | skrivene ovisnosti i greške; umjesto toga eksplicitni parametri forme, a globali samo uz izričito svojstvo |
| Forme u binarnom `.fmb` koji se ne može usporediti | naš zapis je JSON i `.lfm` (tekst, usporediv u gitu) |
| Logika u bazi (PL/SQL) kao jedino mjesto | naš 4GL ide u bazu **i** datoteku (odluka 2); logika ostaje prenosiva |
| Modalni, "znakovni" tijek i posebna sučelja po načinu | moderan raspored, Tab i miš; tipkovnički standard je samo dodatak |
| Zaključavanje redaka pri svakom retku (`Row Locking`) | SQLite nema takvu potrebu; za PostgreSQL/MariaDB razmotriti kao **neobavezno** (optimističko, s provjerom verzije), ne kao zadano |
| Poseban format izvješća po proizvodu | imamo jedan motor izvješća |

### 19.7 Klase svojstava i biblioteka objekata

- **Klasa svojstava** (`PropertyClass`): imenovan skup svojstava (npr. `PoljeIznosa`: format `#.##0,00`, desno, pravilo `>= 0`, stil `Obavezno`). Kontrola koja je referencira prima ta svojstva; vlastita svojstva nadjačavaju. Zapis u JSON-u i `.lfm` kao referenca po imenu. Rješava ponavljanje ("isto polje iznosa na deset formi").
- **Biblioteka objekata**: mapa uz bazu/projekt s klasama svojstava, kontrolama u skupini (npr. adresni blok), 4GL funkcijama i kosturima; projekti je dijele. Nadovezuje se na `skeletons/`.

### 19.8 Tipkovnički standard

| Tipka | Radnja |
|---|---|
| Enter | iduće polje (zadano, postavka) |
| F7 / F8 | Upit / Izvrši upit |
| F9 | LOV na polju |
| F10 | Spremi (`CommitForm`) |
| Ctrl+↓ / Ctrl+↑ | novi zapis (`CreateRecord`) / brisanje zapisa (`DeleteRecord`, uz potvrdu) |
| PgDn / PgUp, Ctrl+Home/End | idući/prethodni, prvi/zadnji zapis |
| Esc | odustani od upita ili izmjene |

Navigacijska traka (prvi, prethodni, iduci, zadnji, novi, obriši, spremi, upit) je dio varijante `Panel` (traka) i uključuje se jednom postavkom na bloku. Tipke su postavka (tema tipkovnice) jer se dio može sukobiti s Qt/IDE-om.

### 19.9 Gdje ulazi u plan i koliko košta

| Stavka | Etapa | Dana (procjena) |
|---|---|---|
| Stanje zapisa/forme, upit po formi, tipkovnički standard, navigacijska traka | **E10** (`TaBindingEngine`) | 3 |
| Standardni događaji, hijerarhija, standardne procedure, blokovi u uređivaču | **E4** i **E8** | 2 |
| Varijanta `lov` (Edit i ćelija u Gridu), `alert:` radnja i `EditAlert` | **E11** | 2 |
| Klase svojstava i biblioteka objekata, `EditPropertyClass` | **E9** i **E12** | 2 |
| Blok-čarobnjak (blokovi nad tablicom s varijantama po tipu) | **E7** | 1 |
| Report wizard sa stilovima (tablični, grupe, matrica) | *Poslije* | 3 |

**Stavke uključene u E0–E12 zbrajaju 10 dana** (raspored raste s 50 na oko 60 radnih dana); Report wizard (3 dana) je izvan toga, u "Poslije". (Ranija procjena "57 dana" bila je pogrešno zbrojena.) Nijedna stavka ne mijenja arhitekturu; sve se naslanja na obitelji, `TaSourceDef`, `TaBindingEngine` i kosture.

### 19.10 Odluke (zatvoreno 2026-11-07)

Prihvaćene su sve preporuke:

| # | Pitanje | Odluka |
|---|---|---|
| 1 | Poglavlje 19 dio plana? | **da**, kao proširenje etapa E4 i E7–E12 |
| 2 | Imena standardnih procedura | **hrvatska** (`IdiNaBlok`, `IzvrsiUpit`, `SpremiFormu`...) **uz englesku sinonimnu listu** (`GoBlock`, `ExecuteQuery`, `CommitForm`...) |
| 3 | Upit po formi (F7/F8) | uključen u Blok-čarobnjaku, inače isključen |
| 4 | Report wizard sa stilovima | poslije (izvan E0–E12) |
| 5 | Zaključavanje redaka (PostgreSQL/MariaDB) | neobavezno, kasnije |

---

## 20. Neprekidna forma i neprekidna podforma (zamjena za Access *Continuous Form*)

Zabilježeno 2026-11-10 na zahtjev korisnika. Cilj: forma s **zaglavljem**, **detaljem** koji se ponavlja za svaki zapis i **podnožjem**, kao u Accessu; u detalju su prave kontrole (edit, combo, kvačica, gumb, slika), ne samo ćelije mreže; novi zapis se unosi izravno u prazan red na dnu; ista stvar radi kao podforma (master-detalj).

### 20.1 Što Access zapravo radi (što moramo reproducirati)

| Svojstvo u Accessu | Ponašanje |
|---|---|
| tri odjeljka | *Form Header*, *Detail*, *Form Footer*; detalj je **jedan red dizajna** koji se crta za svaki zapis |
| trenutni zapis | samo jedan red je "trenutni" (označen), ostali su prikaz; fokus u kontroli drugog reda **čini taj red trenutnim** |
| uređivanje u mjestu | izmjena u kontroli mijenja zapis; pisanje u bazu tek **napuštanjem reda** (ili Shift+Enter), Esc poništava red |
| novi zapis | zadnji red je prazan red sa zvjezdicom; čim se u njega nešto upiše, nastaje novi zapis, a ispod se pojavi novi prazan red |
| birač zapisa | uski stupac lijevo: strelica = trenutni, olovka = nespremljeno, `*` = novi; klik označi cijeli red (brisanje) |
| tipkovnica | Tab/Enter kroz kontrole reda, **nakon zadnje kontrole na prvu kontrolu sljedećeg reda**; Shift+Tab natrag; PgUp/PgDn; Ctrl+Home/End |
| zaglavlje | naslovi stupaca (klik = sortiranje), filtri, gumbi; podnožje: zbrojevi i brojači nad **cijelim izvorom** (ne samo vidljivim redovima) |
| uvjetno oblikovanje | po retku (boja pozadine/teksta po izrazu nad poljima tog zapisa) |
| podforma | ista forma ugrađena u glavnu; veza `LinkMaster`/`LinkChild`; zbroj podforme se može čitati u glavnoj formi |

### 20.2 Zašto ne "dva panela i scrollbox s edit poljima"

Ideja je dobra za zaglavlje i podnožje, ali za detalj ima tri problema:

1. **Broj kontrola.** 1.000 zapisa × 8 polja = 8.000 prozorskih kontrola. Qt6/LCL to sporo stvara, sporo crta i troši memoriju; za 50.000 zapisa je neizvedivo.
2. **Jedan zapis u skupu podataka.** `TDataSet` ima samo **jedan trenutni zapis**. Osam `TDBEdit`-a u 1.000 redova ne mogu se istodobno vezati na 1.000 različitih zapisa; svaka bi kontrola vidjela isti zapis.
3. **Novi red i fokus.** Scrollbox ne zna "dodaj prazan red kad se u zadnjem nešto upiše", niti premješta trenutni zapis kad kontrola dobije fokus.

### 20.3 Rješenje (izmijenjeno nakon probnog projekta, 2026-11-10): **crtani redovi + jedan živi red**

**Mjerenje (korak 0, `tests/rowspike`, Qt6 offscreen, 30 redova × 8 polja):**

| Pristup | Vrijeme po koraku klizanja |
|---|---|
| 240 pravih `TaEdit` kontrola, ponovno punjenje svih | **162 ms** (samo punjenje 120 ms) |
| isto, ali recikliranje: pomak 30 panela + punjenje 1 reda | **50–60 ms** |
| isto, ali pomak jednog spremnika s redovima (1 `SetBounds`) | **38–40 ms** |
| 480 običnih `TEdit` (usporedba) | 305–320 ms |
| **jedna kontrola koja crta svih 240 ćelija** (`Paint`) | **~12 ms** |

Cilj je < 30 ms. Prave kontrole za sve vidljive redove ne zadovoljavaju (mjerenje je opterećeno crtanjem cijelog stabla prozorskih kontrola, što je skupo i pod Qt6), pa se primjenjuje **rezerva iz prvotnog plana**:

- **Neaktivni redovi se crtaju** u jednoj kontroli (`TaRowsView.Paint`) iz predloška detalja: tekst/broj/datum po formatu i poravnanju, kvačica, combo kao tekst sa strelicom, gumb kao crtani gumb, oznaka, slika (predmemorirana), uvjetne boje i alternirajući redovi iz tokena teme.
- **Samo trenutni red je živ:** jedan panel s pravim kontrolama (8 do 16 prozorskih kontrola) položen preko trenutnog reda. Klik ili fokus na crtani red **premješta živi red** na taj zapis: kontrole se napune vrijednostima, a ono što korisnik upiše ide kontroleru reda kao u 20.3a.
- Klik na crtani **gumb** u neaktivnom redu: red postane trenutni, a zatim se izvrši radnja gumba (korisnik ne mora kliknuti dvaput).
- Vizualno su trenutni i crtani redovi isti (isti crtež iz iste definicije), pa se prijelaz ne vidi.

Posljedica: broj prozorskih kontrola je **stalan i malen** (jedan crtani prikaz + jedan živi red) neovisno o broju zapisa.

#### 20.3a Kontroler reda

Kontrole živog reda su **nevezane** (`TaEdit` bez `DataSource`); vrijednost im daje i uzima kontroler:

- *čitanje:* za zapis `k` kontroler uzme red iz međuspremnika prozora i upiše vrijednosti u živi red;
- *pisanje:* izlaz iz kontrole ili `OnChange` javlja `(polje, vrijednost)`; kontroler postavi skup podataka na taj zapis i uđe u `Edit` (ili `Insert` za novi red);
- *spremanje:* napuštanje reda (fokus u drugi red, Enter u zadnjem polju, Shift+Enter, zatvaranje) zove `Post`; greška (pravilo, strani ključ, `NOT NULL`) zadrži fokus u redu i označi polje;
- *poništavanje:* Esc `Cancel` + ponovno punjenje reda iz baze.

Jedan trenutni zapis skupa podataka odgovara jednom živom redu (kao u Accessu).

### 20.4 Novi red kao "datagrid" (odgovor na pitanje iz zahtjeva)

Stvarni broj redova modela je `RecordCount + 1` (ako je `AllowAdds`): **zadnji red je virtualni "novi zapis"**, bez zapisa u bazi.

1. Prikaz: red ima `*` u biraču i **prazne** kontrole (zadane vrijednosti iz `OnNewRecord`, ugrađeno: vrijednost veze `LinkChild` iz glavne forme).
2. Čim korisnik **promijeni vrijednost** u bilo kojoj kontroli tog reda, kontroler zove `Append` (skup podataka u `dsInsert`), upiše polje i **ne dodaje još ništa u bazu**. Red postaje "olovka".
3. Napuštanje reda zove `Post` → zapis nastaje; model se osvježi (`RecordCount` + 1), a **ispod se pojavi novi prazan red**. Ako je klizač bio na dnu, ostaje na dnu (red se "pomakne gore").
4. Tipka ↓ u zadnjem stvarnom redu ide na novi red; Ctrl+N skače na novi red; Esc u neizmijenjenom novom redu ne radi ništa.
5. Brisanje: klik na birač + Delete (uz potvrdu) → `Delete`; zbrojevi u podnožju se osvježe.

To je **isti obrazac kao u `TDBGrid`-u s `dgEditing`** (red s `*`), samo što su ćelije prave kontrole. Zato je moguće i postupno: najprije mreža (`TRxDBGrid`, varijanta *entry*, E11), pa tek onda red s pravim kontrolama.

### 20.5 Komponente i podaci

| Komponenta | Što je | Napomena |
|---|---|---|
| `TaContinuousForm` (obitelj **Grid**, varijanta `continuous`) | `TCustomControl` s tri dijela: `HeaderPanel`, `RowHost`, `FooterPanel` | u IDE-u su `HeaderPanel`/`FooterPanel` obični paneli na koje se bacaju kontrole; **`DetailPanel` je dizajnerski predložak jednog reda** (stvarne kontrole, `ControlSource` = naziv polja), izvodi se kloniranjem |
| `TaRowsView` | virtualni popis redova: klizač, bazen redova, birač zapisa, trenutni red | crta pozadinu redova i birač iz tokena teme (alternirajući redovi, trenutni red, neispravan red) |
| `TaRowModel` | **bez sučelja**: pomak, broj redova, trenutni red, novi red, "prljavo" stanje, tipkovnička pravila | sav izračun je ovdje, pa se testira bez prozora (`smoke`) |
| `TaRowSource` | omot nad `OpenSource` (`TaSourceDef`): prozor zapisa, `RecNo`, `Locate`, `Append/Post/Cancel/Delete`, osvježavanje s očuvanjem položaja, sortiranje i filtar | radi s tablicom, `sql:` i `fgl:` (`fgl:` samo za čitanje dok ne postoji `ON SAVE`, E8) |
| Forma | `TaFormDef.ViewMode = 'continuous'`, kontrole imaju `Section = header / detail / footer`, svojstva `RowHeight`, `AlternateRows`, `RecordSelectors`, `NewRecordRow`, `AllowAdds/Edits/Deletes` | polje `Section` već postoji u definiciji kontrole (rabi ga izvješće): u formama dobiva ista značenja |
| Podforma | `TaSubform` pokazuje na spremljenu formu s `ViewMode = continuous`; **postojeći put** `Info.Embedded` (ugrađeni `TaFormRunner`, `SetMaster(dijete, vrijednost)`) već postoji | zbroj podforme u glavnoj formi: izraz `SubSum('podforma', 'iznos')` |

### 20.6 Podnožje i zaglavlje

- **Podnožje:** izrazi `Sum([iznos])`, `Count()`, `Avg()`, `Max()` računaju se **SQL-om nad istim izvorom, filtrom i vezom** kao red (ne nad 30 vidljivih redova); osvježavaju se nakon `Post`/`Delete` s kratkim odgodom (debounce).
- **Zaglavlje:** naslovi su obične oznake; svojstvo `SortField` na oznaci čini naslov klikom za sortiranje (strelica ▲▼ iz teme); *filtar po stupcu* je običan `TaEdit` u zaglavlju s izrazom `Filter`.
- Zaglavlje i podnožje **nisu dio klizanja**; vodoravno se poravnavaju s detaljem (isti `Left`/`Width` iz predloška), a pri vodoravnom klizanju kreću zajedno.

### 20.7 Tipkovnica i fokus (najteži dio)

- Redoslijed Tab-a: kontrola po kontrola kroz red, zatim prva kontrola sljedećeg reda (kontroler hvata `Tab` na zadnjoj kontroli i postavlja fokus u red `k+1`, uz pomak klizača po potrebi). Shift+Tab simetrično.
- Fokus u kontroli reda `k` → `RowModel.SetCurrent(k)` → ako je stari red bio "prljav", prvo `Post` (greška vraća fokus).
- ↑/↓ mijenjaju red kad kontrola nije višeredna ni otvoreni popis; PgUp/PgDn pomiču za jednu stranicu; Ctrl+Home/End na prvi/zadnji zapis; kotačić miša pomiče klizač.
- Pri ponovnom punjenju redova fokus mora ostati na **istom logičkom zapisu**, ne na istoj kontroli; kontroler pamti (oznaka zapisa, kontrola) i vraća fokus nakon osvježavanja.

### 20.8 Dizajner i čarobnjak

- **TyphAccess dizajner:** tri vodoravna pojasa (zaglavlje, detalj, podnožje) s razdjelnicima; visina detalja je visina reda; kontrola se baca u pojas i dobiva `Section`; pri prebacivanju `ViewMode` u `continuous` dizajner nudi rasporediti postojeće kontrole u pojaseve.
- **Lazarus/CodeTyphon:** `TaContinuousForm` ima tri panela; na `DetailPanel` korisnik slaže kontrole kao jedan red. Desni klik: *Napuni iz tablice…* (isti kôd kao Blok-čarobnjak).
- **Blok-čarobnjak** (E7) dobiva peti raspored **Neprekidna forma**: naslovi stupaca u zaglavlju, po jedna kontrola po stupcu u detalju (varijante po tipu: datum, kvačica, strani ključ kao combo), zbrojevi za numeričke stupce u podnožju; s opcijom *Dodaj podforme za povezane tablice* generira glavni obrazac + neprekidnu podformu.

### 20.9 Etape (nova etapa **E11a**, ~12 radnih dana, **prije E10**)

| Korak | Dani | Što | Prihvaćanje |
|---|---|---|---|
| 0 | 1 | **Probni projekt (spike) GOTOV 2026-11-10** (`tests/rowspike`): prave kontrole 40–160 ms po koraku, crtani redovi ~12 ms; odabrano **crtanje neaktivnih redova + jedan živi red** (20.3) | klizanje za 1 red < 30 ms: ispunjeno crtanjem |
| 1 | 2 | **GOTOVO 2026-11-10** (`ta_rowmodel`, `ta_rowsource`, 76 provjera u `smoke`; izvor čita prozor `LIMIT/OFFSET` s `ORDER BY`, piše jedan zapis `UPDATE/INSERT` s parametrima, greške baze dolaze kao poruka, uređivi su samo izvori koji su tablice, tablica bez ključa radi preko `rowid`) `TaRowModel` + `TaRowSource` bez sučelja: pomak, trenutni red, novi red, `Post/Cancel/Delete`, osvježavanje, sort, filtar, veza glavna-detalj | testovi u `smoke` (≥ 40 provjera): unos u novi red nastaje točno jedan zapis; Esc poništava; brisanje; 10.000 zapisa bez zastoja |
| 2b | 0,5 | **GOTOVO 2026-11-10** (`TestRowRules` 14 provjera): **pravila izračuna u retku** (`CalcRules` forme, isti zapis `a,b -> cilj = izraz ;; ...`; izraz vidi polja trenutnog reda s nepospremljenim izmjenama, lančano `iznos -> pdv`), **oblikovanje broja u živom redu** (u fokusu sirova vrijednost, izvan fokusa oblikovana prema `Format`, kao crtani red). |  |
| 2 | 3 | **GOTOVO 2026-11-10** (`ta_rowhost`, `TestRowHost` 31 provjera, snimka `tests/wizard_shots/out/neprekidna_forma.png`): crtanje svih vidljivih redova **2,2 ms** (cilj 30), živi red s pravim kontrolama (`TaEdit`, `TCheckBox`, `TButton`), birač zapisa (▶, ✎, *), klizač i kotačić, klik na crtani gumb. **Ostaje iz ovog koraka:** prikaz formata (npr. `#,##0.00`) u živom redu dok nema fokusa (crtani red ga već ima), combo s pravim popisom iz `RowSource` (zasad uređiva tekst), crtanje slike i kontrola `Image`, uvjetno oblikovanje po retku. `TaRowsView`: crtanje redova iz predloška (tekst, broj, datum, kvačica, combo, gumb, oznaka, slika), birač zapisa, klizač, boje iz tokena, uvjetno oblikovanje po retku; **živi red** (klon kontrola predloška) i njegovo premještanje | snimka zaslona i test: 200 zapisa, klizanje < 30 ms, crtani i živi red izgledaju isto, vrijednosti se podudaraju |
| 3 | 2 | **GOTOVO 2026-11-10** (`ta_keymap`, `HandleKey` u `TaRowsView`, dijalog `EditKeyMap` u izborniku *Tipke neprekidne forme…*; `TestRowKeys` 47 provjera). **Sve tipke su promjenjive:** radnje `NextField, PrevField, NextRow, PrevRow, PageDown, PageUp, FirstRecord, LastRecord, NewRecord, SaveRow, CancelRow, DeleteRow, CloseForm, CancelOrClose`; svaka ima jednu ili više tipki (`Insert`, `Ctrl+N`, `F12`, `Esc`, `Shift+Enter`…); zadano je Accessu slično (Tab/Enter, Ctrl+N, Esc, Shift+Enter, Ctrl+Delete); zapis je JSON u postavci aplikacije `tipke.json` (isti za dizajner, runtime i IDE), dijalog javlja neispravne tipke i sukobe. `CancelOrClose` = Esc poništi izmjene, a bez izmjena zatvori formu. Pravila: u combo kontroli strelice i stranice pripadaju popisu, na gumbu Enter i razmak pripadaju gumbu, Tab s kraja zadnjeg reda sprema zapis i ide na novi red. Tipkovnica i fokus (20.7) | skriptirani niz tipki (xdrive) daje isti rezultat kao očekivani niz zapisa; Tab s kraja reda ide u sljedeći |
| 4 | 1 | **GOTOVO 2026-11-10** (`ta_contform`: `TaContinuousForm` = zaglavlje + `TaRowsView` + podnožje; `TaRowSource.FilterClause`; `TestContForm` 31 provjera, snimka `neprekidna_zaglavlje_podnozje.png`). Oznake zaglavlja sa svojstvom `sort=polje` sortiraju klikom (▲ ▼), polja zaglavlja sa `filter=polje` filtriraju (broj: `100`, `>100`, `<>5`, `10..20`; tekst: sadrži, `*` zamjenski znak, `=točno`; filtri se zbrajaju s AND, tekst se uvijek ugrađuje kao literal, SQL u filtru je samo tekst); podnožje: `=Sum(polje)`, `=Count()`, `=Avg`, `=Min`, `=Max` računa SQL nad cijelim izvorom uz isti filtar i vezu i osvježava se nakon Posta i brisanja; kontrole zaglavlja i podnožja poravnate su s detaljem; `SetMaster` za podformu. Zaglavlje i podnožje: sortiranje klikom, filtar, zbrojevi SQL-om | zbroj se podudara s `SELECT SUM` nakon unosa, izmjene i brisanja |
| 5 | 2 | **GOTOVO 2026-11-10** (`TaFormRunner` s `ViewMode = continuous` gradi `TaContinuousForm` bez navigacijske trake i vlastitog upita; `SetMaster`, `Requery`, zatvaranje s nespremljenim redom; ugrađena forma javlja `OnDataChanged` glavnoj formi; novi izrazi **`SubSum("Podforma", "polje")`, `SubCount`, `SubAvg`, `SubMin`, `SubMax`** rade za neprekidnu podformu (SQL nad cijelim izvorom) i za staru mrežu (prolaz kroz upit), nalaze podformu po nazivu kontrole, dodani u graditelj izraza; `TestContSub` 17 provjera; snimka `racun_podforma.png`: račun sa stavkama, unos u prazan red, zbroj u podnožju podforme i u glavnoj formi). Ime klase prikaza je **`TaRowsView`** jer `TaRowHost` već postoji u `ta_datatools`. Podforma: `ViewMode = continuous` u `TaSubform`, `SubSum()`, zbroj podforme u glavnoj formi | račun sa stavkama: unos stavki mišem i tipkovnicom, zbroj u podnožju i u glavnoj formi se ažurira |
| 6 | 1 | **GOTOVO 2026-11-10** (`ta_formdef`: `HeaderHeight/RowHeight/FooterHeight`; dizajner formi: izbor *Prikaz = continuous* crta tri pojasa (zaglavlje, detalj, podnožje) kao graﬁčke kontrole ispod ostalih; u definiciji `Top` je unutar odjeljka, na površini dizajna odjeljci su jedan ispod drugog, pa `NormalizedJson` pri spremanju i pregledu dodjeljuje `Section` i `Top` prema tome u koji pojas je kontrola bačena; krug otvori-spremi je stabilan; `TestContDesign` 15 provjera, snimka `dizajner_neprekidna.png`; Blok-čarobnjak: rasporedi **Neprekidna forma** (zaglavlje s naslovima za sortiranje i filtrima, kontrola po stupcu prema tipu, strani ključ kao combo, podnožje s brojem redaka i zbrojevima) i **Obrazac + neprekidne podforme** (glavni obrazac + zasebna neprekidna forma stavki po tablici s ključem prema glavnoj, `LinkMaster/LinkChild` iz stranog ključa, ključ prema glavnoj se ne prikazuje); testirano do otvaranja izrađene forme i zbroja u podnožju). Ostaje: povlačenje razdjelnika pojasa mišem (zasad se visine mijenjaju u svojstvima forme). Dizajner (pojasevi) i čarobnjak (peti raspored) iz tablice `racuni` + `stavke` jednim klikom nastaje radna forma |
| 7 | 1 | **GOTOVO 2026-11-10** (`ta_contcomp`: komponenta **`TaContinuousForm`** na stranici *TyphAccess: Podaci* s ikonom; tri pojasa (zaglavlje, detalj, podnožje) crtaju se u dizajnu, svojstva `HeaderHeight/RowHeight/FooterHeight`, `Database`, `RecordSource`, `Filter`, `CalcRules`, `DetailField`, `Bindings` (`naziv=polje`, `naziv=sort:polje`, `naziv=filter:polje` za oznake i kvačice); događaji `OnButtonClick`, `OnDataChange`; pri izvođenju gradi isti `TaFormDef` i isto tijelo (`TaContinuousBody`) kao TyphAccess. **Provjereno u stvarnom Light IDE-u** (ikona u paleti, bacanje na formu, bacanje `TaEdit` na pojaseve, spremanje `.frm` čisto: kontrole su djeca komponente) **i kao stvarni program** (`tests/ide_neprekidna`: `.frm` iz IDE-a prevede se i pokrene; klik na naslov sortira ▲, filtar `split` daje 20 redova i podnožje 20, izmjena u redu + strelica dolje sprema u bazu). **Nalaz:** paneli kao podkomponente nisu mjesta za bacanje kontrola (IDE ih stavlja izravno na komponentu), pa je odjeljak određen **položajem** kontrole (isto kao u TyphAccess dizajneru). **Ispravak iz provjere:** nakon spremanja izmjene polja po kojem je sortirano, prelazak ide na zapis koji je bio cilj, ne na poziciju. Light IDE: komponenta + `DetailPanel` predložak, provjera u stvarnom IDE-u | forma složena u IDE-u i ista forma iz JSON-a izgledaju i ponašaju se jednako |

### 20.10 Rizici i odluke

| Rizik | Mjera |
|---|---|
| Brzina klizanja s pravim kontrolama pod Qt6 | **izmjereno i riješeno** (korak 0): crtani redovi + jedan živi red; krajnja rezerva: `TRxDBGrid` s `entry` (E11) |
| Vjernost crteža neaktivnih redova prema pravim kontrolama | jedan opis crteža po vrsti kontrole, snimke zaslona usporedbe crtanog i živog reda u testu |
| Fokus gubi trag pri recikliranju redova | fokus se veže uz oznaku zapisa, ne uz kontrolu; test s tipkovnicom |
| Dva izvora istine (međuspremnik i skup podataka) | međuspremnik se **uvijek** puni iz skupa podataka; pisanje ide samo kroz kontroler |
| `fgl:` izvori nisu uređivi | prikaz radi, uređivanje tek s `ON SAVE` (E8, ostaje) |
| Različite visine redova (memo koji raste) | v1: **stalna visina reda** (`RowHeight`); promjenjiva visina kasnije |
| Vodoravno klizanje | v1: forma je široka koliko prozor; vodoravni klizač zajednički za zaglavlje, detalj i podnožje kasnije |

### 20.11 Odluke (2026-11-10)

1. **Stalna visina reda:** da (v1). Detalj može biti viši i imati više linija kontrola, ali je visina ista za sve zapise.
2. **Filtar:** za sada samo filtar u zaglavlju (obične kontrole s izrazom `Filter`); *filtar po obrascu* kasnije.
3. **Grupiranje u zaglavlju grupe:** ne za sada.
4. **Više linija po zapisu:** da (slobodna, ali stalna visina detalja).
5. **Poredak:** **E11a ide prije E10** (korisnik ga treba za račune sa stavkama). E10 (zajednički stroj ponašanja) slijedi poslije.

---

## 21. Što je otvoreno (popis 2026-11-11)

Pregled onoga što iz plana (E0–E12, poglavlja 19 i 20) i iz razvoja još nije gotovo. Gotovo je navedeno u 14.0.

**Iz etapa:**
| Stavka | Etapa | Napomena |
|---|---|---|
| Provjera u stvarnom GUI-ju: Blok-čarobnjak, `TaSourceDef`, kosturi | E7 | sve provjereno samo u smoke testovima; ručno nikad |
| `ON SAVE` za `fgl:` izvore (uređivanje redaka iz 4GL-a) | E8 | `fgl:` izvori su samo za čitanje |
| Hrvatska imena standardnih procedura (`IdiNaBlok`, `IzvrsiUpit`, `SpremiFormu`...) uz engleske sinonime | 19.3, odluka 2 | u kodu nema `GoBlock`/`IdiNaBlok` |
| Radnja `alert:` i `EditAlert` | E11, 19.5 | nije u kodu |
| Standardni događaji `BeforeInsert`, `AfterQuery`, `OnError`, `OnKey` | 19.3 | **gotovo 2026-11-11** (`PLAN-rjecnik-okidaci.md`); hijerarhija stavka > blok > forma kao poseban mehanizam nije |
| Report wizard sa stilovima (tablični, grupe, matrica) | Poslije | 3 dana |
| Light IDE stupanj 2 (vlastiti izbornici, prevođenje i Pascal u njemu), gustoća, prenosivost `.lfm`↔JSON, `TaDataForm` | Poslije | po odluci |
| Zaključavanje redaka za PostgreSQL/MariaDB (optimističko) | odluka 5 | neobavezno |

**Iz poglavlja 20 (neprekidna forma):** promjenjiva visina reda (memo koji raste), vodoravno klizanje zajedničko za pojaseve, filtar po obrascu, grupiranje u zaglavlju grupe.

**Iz razvoja palete:**
| Stavka | Napomena |
|---|---|
| Subform, TabControl, SideMenu još su stare kontrole u izvršitelju i dizajneru | prelazak na obitelji (Pages, Menu) |
| Programsko `ActivePage` ne javlja `OnChange` | ugovor obitelji; kod mora zvati `FamilyShowPages` |
| U IDE-u kontrole na Pages nemaju indeks stranice (vide se na svim stranicama) | `page` postoji samo u dizajneru formi |
| Imena komponenti u IDE-u `aPages1`, `aChart1` (Lazarus skida `T`) | kozmetika |
| GTK3: 13 padova i zaglavljivanje pri gašenju | `docs/GTK3.md` |
| Prelazak na novi Lazarus: imena paketa, `lazbuild` skripta umjesto `typhonbuild` | procjena 1–3 dana |

**Prijevodi (2026-11-11; engleski izvor + hrvatski prijevod, `ta_i18n*`, detalji u `PLAN-rjecnik-okidaci.md` korak 0):** preostalo za kasnije:
| Stavka | Veličina | Napomena |
|---|---|---|
| Priručnik `ta_manualdata` (HTML, generira se iz `tools/manual_src`) | ~39.700 riječi | **plan u `docs/PLAN-prijevod-prirucnika.md`**: paralelno stablo `docs/manual/en/`, izbor jezika, povratak na hrvatski po poglavlju |
| Katalog domena (`catalog/*.json`, ~33.300 riječi) | veliko | isti plan; primjeri `ta_showcase*` su podaci i ostaju hrvatski |
| Tijela blokova i primjeri koda (npr. `DISPLAY "Pozdrav"`), predlošci pisama, nazivi varijabli u kosturima | ~100 | sadržaj koji završava u korisnikovu programu: treba izbor jezika pri generiranju |
| Poruke u višeredovnim pozivima i konstante izvan pozvanih konteksta | nepoznato | ponoviti `tools/i18n/scan.py` s proširenim kontekstima |
| Pomoćni tekstovi dijaloga pisma i uređivača modula; dugi natpisi odrezani u uskim dijalozima | ~20 | prelomiti ili skratiti |
| Vrijednosti izbornika (npr. raspored zadatka `dnevno 02:00`), nazivi izvoznih formata, `NavHints` i druge konstante samo kroz `Tr(ARR[i])` | ~30 | uskladiti ako treba |
| Dijalog makra nije zasebno pregledan u engleskom prikazu | 1 | |
| `Tr` u hrvatskom prikazu za nove poruke mora imati par u `ta_i18n_hr*` (provjera potpunosti prijevoda kao test) | – | dodati smoke provjeru "svaki `Tr('…')` ima hrvatski prijevod" |

**Iz aplikacije TyphAccess:** fiskalizacija XML i slanje na CIS stoji; GUI je mnogo toga testiran samo bez ručnog rada.
