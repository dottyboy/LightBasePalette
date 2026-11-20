# Popis komponenti TyphAccessa: porijeklo ideja, razlike i usporedba s komponentama CodeTyphona

Stanje: 2026-11-07 (commit `7dd0641`+). Popis je sastavljen iz izvornog koda (`src/core`, `src/gui`, `lazarus/`), iz zaglavlja jedinica, iz popisa `uses` i iz probnih projekata (`tests/jvspike`). Gdje stoji **(procjena)**, tvrdnja je zaključak iz koda i probnog rada, a **nije mjerena** usporedbom.

Sadržaj: 1. vanjske biblioteke · 2. kontrole · 3. nevizualne komponente · 4. dizajneri · 5. motori i jezici · 6. domenski moduli · 7. porijeklo ideja · 8. gdje je TyphAccess bolji · 9. gdje su komponente CodeTyphona bolje · 10. što iz toga slijedi.

---

## 1. Vanjske biblioteke koje TyphAccess koristi

Izvor: `TyphAccess.ctpr` (traženi paketi) i `uses` klauzule.

| Biblioteka | Paket u CodeTyphonu | Čemu služi u TyphAccessu | Gdje (primjeri) |
|---|---|---|---|
| **LCL (Qt6)** | `adLCL` | cijelo sučelje: forme, kontrole, dijalozi, crtanje | sve `gui/*` |
| **Zeos DBO** | `pl_ZeosDBO` | pristup bazi: SQLite, PostgreSQL, MariaDB; `TZConnection`, `TZQuery` | `ta_meta`, svi upiti |
| **PascalScript** | `pl_PascalScript` | moduli (`_sys_modules`): vlastite procedure i funkcije | `ta_script` |
| **fpspreadsheet** | `pl_FpSpreadsheet` | uvoz i izvoz XLSX/ODS, čitanje radnih knjiga | `ta_importexport`, `ta_dataimport` |
| **RichMemo** | `pl_RichMemo` | uređivač formatiranog teksta (pretvara se u mali HTML) | `ta_richedit` |
| **Image32** | `pl_Image32` | SVG u PNG za slike u izvješćima | `ta_svg` |
| FCL: `fpjson`, `jsonparser` | (FPC) | definicije formi i izvješća u JSON-u | `ta_formdef`, `ta_reportdef` |
| FCL: `fppdf` | (FPC) | PDF izlaz izvješća | `ta_reportview`, `ta_svgpdf` |
| FCL: `fpbarcode`, `fpqrcodegen` | (FPC) | kodiranje barkodova (code128, EAN, QR) | `ta_barcode` |
| FCL: `fphttpclient`, `opensslsockets` | (FPC) | preuzimanje datoteka preko HTTPS-a | `ta_download` |
| FCL: `zipper`, `XMLRead`, `DOM`, `RegExpr`, `sha1`, `Process` | (FPC) | arhive i XLSX, XML, regularni izrazi, lozinke, vanjski programi | razno |
| **pdf417gen** (MIT, Ivan Habunek) | — (tablice u `ta_pdf417data`) | tablice za PDF417 (HUB-3 uplatnice) | `ta_pdf417` |

**Što se ne koristi:** JVCL, RX, KControls, BGRA, TAChart, SynEdit, LazReport. Tijekom razvoja palete JVCL i RX su isprobani na Qt6 (23 kontrole rade, `tests/jvspike`), ali ih runtime TyphAccessa ne traži.

## 2. Kontrole TyphAccessa (vizualne)

Tablica: naziv, osnovna LCL klasa, odakle ideja, što je dodano, ograničenje.

| Kontrola | Osnova | Odakle ideja | Što je dodano naspram osnovne klase | Ograničenja |
|---|---|---|---|---|
| **TaTextBox** | `TEdit` | Access *Text Box* | `ControlSource` kao polje **ili izraz** (`=[kol]*[cij]`), oblik prikaza, zadana vrijednost, pravilo provjere, uvjetno oblikovanje, `VisibleIf`/`EnabledIf` | nema ugrađenog kalendara ni iznosa (to rade oblik i čarobnjak) |
| **TaMemo** | `TMemo` | Access *Memo* | isti izvor i pravila | — |
| **TaRichText** | `TaRichEdit` (`TRichMemo`) | Word/WordPad | formatirani tekst se **sprema kao mali HTML** u običnom tekstnom polju (`<p>`, `<b>`, `<i>`, `<u>`, `<font>`), pa ostaje pretraživ i čitljiv u SQL-u | podskup HTML-a (bez slika i tablica) |
| **TaLabel**, **TaHyperlink** | `TLabel` | Access *Label* | natpis može biti izraz (`="ID: " & [id]`) | — |
| **TaButton** | `TBitBtn` | Access *Command Button* | `OnClick` je **radnja** (`openform:`, `openreport:`, `macro:`, `run:`, `fgl:`, `sql:`...), ikona iz zalihe prema radnji | radnje su tekst (urednik radnji je u planu) |
| **TaCheckBox**, **TaToggle** | `TCheckBox`, `TToggleBox` | Access *Check Box*, *Toggle* | pohrana kao Da/Ne tip polja | — |
| **TaComboBox** | `TComboBox` | Access *Combo Box* | `RowSource` iz tablice, SQL-a ili popisa; **više stupaca**, pretraga upisom, `AutoFill` (prepisuje polja iz odabranog retka, npr. cijena iz artikla) | izvor nije još 4GL (plan) |
| **TaListBox**, **TaOptionGroup** | `TListBox`, `TRadioGroup` | Access *List Box*, *Option Group* | isto | — |
| **TaSubform** | `TPanel` + `TDBGrid` | Access *Subform* | veza glavna/detalj (`LinkMaster`/`LinkChild`), **zbroj stupca detalja**, uređivanje u mreži, izračunata polja stavke | mreža je standardni `TDBGrid` (bez podnožja iz RX) |
| **TaTabControl** | `TPageControl` | Access *Tab Control* | kontrole se ispuštaju na stranicu, spremaju se po stranici | — |
| **TaImage** | `TImage` | Access *Image* | slika **izvan baze** (`ta_filestore`: u bazi samo veza), ugrađena SVG slika se crta oštro i u PDF-u | — |
| **TaChart** | `TPaintBox` (vlastito crtanje) | Access *Chart* | stupci, linija i pita iz **jednog upita** (oznaka, vrijednost); isti crtež u formi, pregledu, PDF-u i HTML-u | samo 3 vrste (stupci, linija, pita), jedna serija, najviše 40 točaka; vrsta "line" crta stupiće s oznakom točke (poznato) |
| **TaBarcode** | `TPaintBox` | Access dodatak | code128, EAN13/8, code39, ITF, QR, **PDF417 i HUB-3** (hrvatska uplatnica); kodiranje preko FCL-a (`fpbarcode`, `fpqrcodegen`) i vlastitog PDF417 | — |
| **TaRect**, **TaLine**, **TaPageBreak** | `TShape` | Access oblici | prijelom stranice u izvješću | — |
| **TaSideMenu** | `TCustomControl` (vlastito crtanje) | **TJvXPBar** (JVCL) | vidi 2.1 | vidi 2.1 |
| **TaTabBar** | `TCustomControl` (vlastito crtanje) | MDI kartice preglednika | kartice s tipkom zatvaranja | postoji jer Qt6 sučelje ne crta tipke zatvaranja na karticama |
| **TaShell** | `TPanel` | Access *Navigation Form* | radni prostor: zaglavlje, bočni izbornik, kartice, jedna otvorena forma po skupini | — |

### 2.1 TaSideMenu naspram TJvXPBar (jedini izravan zamjenski par)

| | TJvXPBar (JVCL) | TaSideMenu |
|---|---|---|
| Crtanje | vlastito, tema XP | vlastito, **svijetla i tamna tema** prate program |
| Skupine koje se sklapaju | da | da |
| **Harmonika** (otvorena samo jedna skupina) | ne (svaka traka zasebno) | da (`Accordion`) |
| **Uski način samo s ikonama** (natpis u oblačiću, skupina se otvara pri prelasku mišem) | ne | da (`Compact`) |
| **Pamćenje zadnje stavke i otvorene skupine po korisniku** | ne | da (`StateKey`) |
| Ikone | popis slika | zaliha ikona po imenu, **ikona se bira sama prema radnji** ili iz popisa slika |
| Punjenje | zbirka `Items` (jedna traka = jedna kontrola) | **jedna kontrola**, dva izvora: tekst (jedan redak po stavci) ili zbirke `Groups`/`Items` u inspektoru |
| Radnja stavke | događaj | tekst radnje (`openform:...`), događaj `OnItemClick` |
| Ovisnosti | JVCL | **nema** |

## 3. Nevizualne komponente (nove, za paletu)

| Komponenta | Porijeklo ideje | Što radi | Naspram sličnih komponenti |
|---|---|---|---|
| **TaDatabase** | `TZConnection` + Access *CurrentDb* | baza (SQLite, PostgreSQL, MariaDB), objekti aplikacije, postavke, zadana baza za izraze | Zeosova komponenta samo spaja; ovdje su i metapodaci aplikacije (forme, izvješća, programi) |
| **TaExpression** | Access izrazi | računa izraze (`[x]*2`, `DSum`, `Zaokruzi`, `Predict`...) s varijablama | u standardnoj paleti nema evaluatora izraza |
| **TaReport** | Access izvješća | izvješće iz baze: pregled, PDF, HTML | LazReport/FastReport imaju bogatije dizajnere; ovdje je isti motor kao u aplikaciji |
| **TaProgram** | Informix 4GL | 4GL program iz baze ili teksta, ispis u događaje | — (4GL nema ekvivalent) |
| **TaFormBinder** | Access *Control Source / Conditional Formatting / Validation Rule* | izračun, pravila, zadane vrijednosti, uvjetno oblikovanje, hrvatski oblici na **bilo kojim** kontrolama (LCL, JVCL, RX) | RX/JVCL nemaju ekvivalent: njihove kontrole imaju samo `DataSource/DataField` |

## 4. Dizajneri i uređivači

| Alat | Porijeklo ideje | Što je dodano / različito |
|---|---|---|
| **Dizajner formi** (`ta_formdesign`) | Access *Design View*, Lazarusov dizajner | paleta, povlačenje i promjena veličine, poravnanje više kontrola kao u Lazarusu (`ta_layout`), poništavanje, uživo Dock i sidra |
| **Uređivač sidrenja** (`ta_anchoreditor`) | **Lazarusov Anchor Editor** | jedan dijalog za Dock, sidra uz rub ili susjeda, razmake, uz pregled u mjerilu; isti zapis u definiciji kao ranije |
| **Uređivači svojstava** (`ta_propedit`, `ta_propdlgs`) | Lazarusov Object Inspector | padajući popisi za nabrojane vrijednosti, Da/Ne, gumb ... za font, boju, sliku, izraz, izvor popisa, radnju, uvjetno oblikovanje |
| **Dizajner izvješća** (`ta_reportdesign`) | Access *Report Design* | **sedam pojasa**, grupe, zbrojevi, naljepnice (Avery/Herma), podizvješća, pregled stvarnim motorom |
| **Dizajner upita** (`ta_querydesign`) | Access **QBE** | mreža stupaca (polje/izraz, zbroj, poredak, kriterij, "ili"), SQL se piše uživo; izrazi se prevode u SQLite SQL |
| **Pogled na veze** (`ta_relview`) | Access *Relationships* | tablice kao pomične kutije, povlačenje polja stvara vezu |
| **Graditelj izraza** (`ta_exprbuilder`) | Access *Expression Builder* | kategorije, primjeri, provjera |
| **Uređivač blokova** (`ta_blockedit`, `ta_fgledit`) | blokovsko programiranje općenito, Access makro-uređivač (izvor ideje nije zapisan u kodu) | makro i **4GL kao blokovi**, dvosmjerno s tekstom bez gubitka |
| **Uređivač dopisa** (`ta_letterdlg`) | slično spajanju pisama (Mail Merge) | tekst s poljima i tablicom, po jedan dopis po primatelju, izvoz u Word i PDF |
| **Čarobnjaci** (`ta_wizards`, `ta_bizgen`, `ta_calcgen`) | Access *Wizards* | forma/izvješće/upit iz tablice; poslovni predlošci (račun sa stavkama, ponude i ugovori...); predlošci izračunatih polja |
| **Katalog shema** (`ta_catalog`) | Northwind kao primjer-baza, predlošci baza općenito | 15 domena kao JSON: tablice, veze, podaci, forme |

## 5. Motori i jezici

| Motor | Porijeklo | Razlike naspram izvornika |
|---|---|---|
| **Jezik izraza** (`ta_expr`) | Access izrazi (`[polje]`, `IIf`, `Nz`, `DLookup`) | prevodi se i u **SQLite SQL** (`ta_exprsql`), pa izračunato polje radi isto u formi i u upitu; hrvatske funkcije (brojevi slovima, OIB, ZKI) |
| **4GL** (`ta_fgl`) | **Informix-4GL** | isti program radi u prozoru, konzoli i u skriptama; SQL s parametrima `$var`; blokovi kao drugi prikaz; nove naredbe `COLUMNS`/`EMIT` planirane |
| **Makroi i moduli** (`ta_script`) | Access makroi + VBA; **PascalScript** | makro je jedna radnja po retku (dijeli radnje s gumbima); modul je PascalScript s pristupom formi |
| **Motor izvješća** (`ta_reportengine`) | Access izvješća | izlaz je **jedna lista crtanih stavki** (A4, 96 dpi) koju koriste pregled, HTML, PDF i ispis, pa je izgled isti svugdje |
| **Revizijski trag** (`ta_audit`) | Access nema; SQL okidači | bilježi **sve** promjene (forma, mreža, skripta, uvoz, SQL) preko SQLite okidača |
| **Planer zadataka** (`ta_tasks`) | planeri zadataka općenito | sigurnosne kopije, izvozi, SQL i makroi po rasporedu |
| **Korisnici i prava** (`ta_app`) | zaštita na razini korisnika kakva je bila u Accessu 2003 | uloge (gledatelj, korisnik, administrator), prava po objektu |
| **Uvoz iz Accessa** (`ta_mdbimport`) | — | tablice, ključevi, veze, zadane vrijednosti, indeksi i spremljeni upiti iz `.mdb/.accdb` |
| **Migracija baze** (`ta_migrate`) | — | SQLite ↔ PostgreSQL/MariaDB s formama i pravima |
| **Fiskalizacija** (`ta_fiscal`) | hrvatski propisi | ZKI, certifikat, CIS |
| **Hrvatski oblici** (`ta_locale`, `ta_words`, `ta_hub3`, `ta_pdf417`) | domaća potreba | brojevi i iznosi slovima, HUB-3 uplatnica kao PDF417 |

## 6. Domenski moduli (nisu komponente, nego prenesen kod)

Nativne replike modula iz Python aplikacije SmartBet (`ta_predict`, `ta_slipgen`, `ta_backtest`, `ta_enginebt`, `ta_newton`, `ta_marketfit`, `ta_pairs`, `ta_analytics`, `ta_reliability`, `ta_validation`, `ta_league`, `ta_dataimport` i drugi). Namjerno su odvojeni od palete; izlažu se kao **funkcije izraza**, ne kao komponente. Paritet s Pythonom je ispitan (vidi `SmartBetTA/paritet_*.sh`).

## 7. Odakle su potekle ideje (sažetak)

| Izvor ideje | Što je preuzeto |
|---|---|
| **Microsoft Access** | većina modela: kontrole i njihova svojstva (`ControlSource`, `RowSource`, `OnClick`), pojasevi izvješća, QBE, makroi, jezik izraza, podforme, izbornik (switchboard), parametri `[?Naziv]` |
| **Informix-4GL** | jezik 4GL (MAIN, FUNCTION, CURSOR, `INPUT`, `CONSTRUCT`, `MENU`, `REPORT`) |
| **Lazarus / LCL** | `Dock`, `BorderSpacing`, `AnchorSide`, poravnanje više kontrola, uređivači svojstava, Anchor Editor |
| **JVCL (TJvXPBar)** | izgled i ponašanje bočnog izbornika |
| **Northwind** | primjer-baze za ispitivanje |
| **Word / WordPad** | uređivač formatiranog teksta i dopisi |
| **SmartBet (Python)** | domenske replike, s ispitanim paritetom |

## 8. Gdje je TyphAccess bolji od odgovarajućih komponenti CodeTyphona **(procjena)**

1. **Podatkovna pravila na samoj kontroli.** U LCL-u, JVCL-u i RX-u data-aware kontrola zna samo `DataSource` i `DataField`. U TyphAccessu ista kontrola ima izraz, pravilo, zadanu vrijednost, uvjetno oblikovanje i uvjete vidljivosti, **bez ijedne linije koda**. `TaFormBinder` donosi to i na tuđe kontrole.
2. **Jedan izvor istine za izgled i ponašanje.** Definicija forme (JSON u bazi) pokreće runtime, dizajner i čarobnjake. U Lazarusu su izgled (`.lfm`), kod (`.pas`) i podaci tri odvojena svijeta.
3. **Izračunato polje radi i u SQL-u.** Isti izraz u formi i u upitu (`ta_exprsql`).
4. **Izvješća isti na zaslonu, u PDF-u i u HTML-u** jer svi crtaju istu listu stavki; PDF s pravim vektorom za SVG.
5. **Bočni izbornik** s harmonikom, uskim načinom i pamćenjem po korisniku (tablica 2.1).
6. **4GL i blokovi** kao način programiranja bez prevođenja; u paleti Lazarusa nema ekvivalenta.
7. **Aplikacija je jedna datoteka baze** (forme, izvješća, makroi, programi, prava): kopiranje baze je kopiranje aplikacije. Izvršni oblik traži samo `TyphAccess --runtime`.
8. **Revizijski trag preko okidača** bilježi sve promjene bez obzira na izvor.
9. **Hrvatske specifičnosti** (oblici, iznosi slovima, OIB, ZKI, HUB-3) gotove.
10. **Manje ovisnosti:** runtime ne traži JVCL, RX ni TAChart.

## 9. Gdje su komponente CodeTyphona bolje **(procjena)**

| Područje | Komponenta | Zašto je bolja od naše |
|---|---|---|
| Grafikoni | **TAChart** (`lz_taChart`, 126 komponenti) | desetci vrsta grafikona, više serija, osi, legende, interakcija; naš `TaChart` ima 3 vrste i jednu seriju |
| Mreža | **TRxDBGrid** (RX) | podnožje sa zbrojevima, filtri u zaglavlju, izvoz u PDF/tablicu, ispis, pretraga; naša mreža je `TDBGrid` s filtrima po stupcima |
| Raznolikost kontrola | **JVCL** (142 jedinice), RX | kalkulator, datum, iznos, lookup, `TJvPageList`, HTML natpisi, LED, vremenska crta; mi to rješavamo oblikom i čarobnjakom, ne posebnom kontrolom |
| Urednik koda | **SynEdit** | bojenje sintakse, dopuna koda, pregled; naš 4GL uređivač ima blokove i provjeru, ali ne i dopunu koda |
| Dizajner izvješća | **LazReport / FastReport** (ako ih ima) | bogatiji dizajner, kodni događaji, više izlaznih formata |
| Razvojno okruženje | **Lazarus IDE** | otklanjanje grešaka, paketi, više platformi, refaktoriranje |
| Zrelost | sve gore | desetljeća uporabe i testiranja; naše su kontrole mlade |

## 10. Što iz toga slijedi

- **Zadržati naše:** podatkovna pravila na kontroli, izvješća, 4GL, izbornik, fiskalizaciju. To je ono po čemu se razlikujemo, a nema ekvivalenta.
- **Posuditi, ne graditi:** grafikone (uz TAChart kao neobavezni pokretač) i naprednu mrežu (RX kao neobavezni pokretač). To je upravo ono što plan univerzalnih kontrola predviđa (pokretači po varijanti).
- **Ne brinuti o 1000 kontrola:** većina JVCL/RX kontrola je ista ideja u drugom izdanju. Šesnaest obitelji s varijantama pokriva ono što poslovne aplikacije trebaju (`PLAN.md`).
- **Mjeriti umjesto pretpostavljati:** gdje piše **(procjena)**, predlažem kratke probne usporedbe (npr. broj redaka koda za isti zaslon, vrijeme prikaza 10.000 redaka u mreži, izgled istog grafikona).

Vidi i: [PLAN.md](PLAN.md) (jedinstveni plan palete, teme, 4GL-a i Light IDE-a).
