> **ARHIVA:** objedinjeno u [../PLAN.md](../PLAN.md) (2026-11-07). Vrijedi samo taj plan.

# Plan: izbor kontrola, paleta, jedinstvena tema i pretvorba u Lazarus komponente

Verzija: 2026-11-07. Ovo je **plan prije razvoja**: što biramo, kako grupiramo, kako izgleda i kako pretvaramo. Razvoj ide poslije, po redoslijedu iz poglavlja 8.

Nadovezuje se na `PLAN-univerzalne-kontrole.md` (obitelji i varijante), `PLAN-light-ide.md` i `POPIS-KOMPONENTI.md` (što danas imamo i što koriste Typhon komponente). Činjenice o dostupnim bibliotekama dolaze iz instalacije CodeTyphona (`/usr/local/codetyphon/typhon/components`), a o temi iz `ta_theme.pas`, `ta_sidemenu.pas` i `ta_controls.pas`.

---

## 0. Sažetak odluka

1. **Paleta ima 17 vizualnih obitelji i 7 nevizualnih komponenti**, svrstanih na 4 stranice (poglavlje 2). Svaka obitelj ima zadani pokretač nad **LCL-om** (nema dodatnih ovisnosti) i neobavezne pokretače iz drugih biblioteka.
2. **SynEdit se uzima** kao pokretač nove obitelji **Editor** (4GL, SQL, izrazi, PascalScript). Zamjenjuje obične `TMemo` uređivače i daje bojenje sintakse, brojeve redaka, sklapanje blokova, dopunu koda i oznake grešaka.
3. **Jedna tema ("Design tokens")**: skup od oko 25 vrijednosti (boje, razmaci, polumjeri, fontovi) za svijetlu i tamnu varijantu. Sve što crta LCL ide kroz Qt stilsku tablicu (QSS) iz tih vrijednosti; sve što crta sama kontrola (bočni izbornik, kartice, grafikon, LED) čita iste vrijednosti. Biblioteka čija se kontrola ne da uskladiti s temom **ne ulazi u zadanu paletu**.
4. **Svaka postojeća TyphAccess kontrola pretvara se u Lazarus komponentu** koja nosi sva svoja svojstva kao objavljena svojstva (bez ovisnosti o `TaControlDef`). Runtime TyphAccessa stvara iste komponente iz JSON-a.
5. Biblioteke se **ocjenjuju po pet mjerila** (poglavlje 3); ishod je odluka *Zadano / Neobavezno / Odbijeno* za svaku.

---

## 1. Načela izbora kontrole

Kontrola ulazi u paletu (kao zadani ili kao neobavezni pokretač) samo ako ispuni **svih pet**:

| # | Mjerilo | Kako se provjerava |
|---|---|---|
| M1 | **Radi na Qt6** | probni projekt (kao `tests/jvspike`): stvaranje, veza na bazu, crtanje, unos, bez rušenja pri zatvaranju |
| M2 | **Uklapa se u temu** | boje i fontove prima iz QSS-a ili iz tokena; snimka u svijetloj i tamnoj temi izgleda kao ostatak programa |
| M3 | **Veže se na podatke** | ima `DataSource`/`DataField` ili je `TaFormBinder` može vezati (RTTI) |
| M4 | **Ne udvostručuje** ono što već imamo | ne dodaje drugo ime za istu funkciju (to je smisao obitelji i varijanti) |
| M5 | **Licenca i održavanje** | licenca dopušta uporabu; paket je u CodeTyphonu, održavan i prevodi se bez zakrpa |

Biblioteka s kontrolama koje ne ispunjavaju M1 ili M2 ne dolazi u paletu ni kao neobavezni pokretač.

---

## 2. Konačna paleta

Paleta se u IDE-u (i u dizajneru TyphAccessa) prikazuje na **četiri stranice**. Stupac "Zadani pokretač" je ono što radi bez ikakve dodatne biblioteke.

### 2.1 Stranica "TyphAccess: Podaci" (unos i prikaz zapisa)

| Obitelj | Varijante | Zadani pokretač (LCL) | Neobavezni pokretači |
|---|---|---|---|
| **Edit** | text, password, mask, spin, date, time, currency, search, combo, droplist, lookup | `TEdit`, `TMaskEdit`, `TFloatSpinEdit`, `TDateEdit`, `TComboBox` | RX (`TRxDBCurrEdit`, `TRxDBDateEdit`, `TRxDBLookupCombo`), JVCL (`TJvxCurrencyEdit`, `TJvCalcEdit`) |
| **Memo** | plain, rich, markdown | `TMemo`; rich: `TRichMemo` (već u upotrebi, sprema se kao mali HTML) | `TKMemo` (KControls: slike, tablice u tekstu) |
| **Check** | checkbox, switch, radio, tri-state | `TCheckBox`, `TRadioButton`; switch: vlastito crtanje (token teme) | — |
| **Choice** | radio group, check group, segmented | `TRadioGroup`, `TCheckGroup`; segmented: vlastito crtanje | — |
| **List** | list, checklist, icon list, tree | `TListBox`, `TCheckListBox`, `TListView`, `TTreeView` | `TVirtualStringTree` (VirtualTrees) za velike popise |
| **Grid** | read-only, editable, datasheet, footer-sum, filter row, **entry** (unos stavki) | **`TRxDBGrid`** (ODLUKA 2026-11-07: zadani pokretač, ne neobavezni) | `TDBGrid` samo kao rezervni pokretač bez RX paketa |
| **Calendar** | month, range, agenda | `TCalendar`, `TDateTimePicker` (`lz_DateTimeCtrls`) | — |

### 2.2 Stranica "TyphAccess: Prikaz"

| Obitelj | Varijante | Zadani pokretač | Neobavezni |
|---|---|---|---|
| **Label** | text, hyperlink, html, badge | `TLabel`; html: naš mali HTML podskup (`ta_richtext`) | `THtmlViewer` (puni HTML) |
| **Image** | picture, shape, gradient, svg/icon | `TImage`, `TShape`; SVG preko Image32 | — |
| **Chart** | bar, line, pie, gauge, area, scatter | **`TAChart`** (`lz_taChart`): više serija, osi, legende, zumiranje | vlastito crtanje (`TaChart`) samo za izvješća, PDF i HTML, ista paleta |
| **Barcode** | code128, ean13/8, code39, itf, qr, pdf417, HUB-3 | vlastito (`ta_barcode`, `ta_pdf417`, FCL `fpbarcode`/`fpqrcodegen`) | — |
| **Progress** | bar, ring, led, busy | `TProgressBar`; ring i led: vlastito crtanje | `TECProgressBar` (ECControls) |

### 2.3 Stranica "TyphAccess: Raspored i navigacija"

| Obitelj | Varijante | Zadani pokretač | Neobavezni |
|---|---|---|---|
| **Button** | standard, flat, toggle, image, link, menu, split, default, cancel | `TBitBtn`, `TSpeedButton`, `TToggleBox` + QSS za izgled | — (BGRA `TBCButton` odbijen, vidi 3) |
| **Panel** | plain, group, card, scroll, expander, splitter | `TPanel`, `TGroupBox`, `TScrollBox`, `TSplitter`; card/expander: vlastito crtanje | `TECAccordion` |
| **Pages** | tabs, page list, steps, accordion | `TPageControl`; radni prostor: naš `TaTabBar` | — |
| **Menu** | side menu, toolbar, tree menu | **`TaSideMenu`** (naš, po uzoru na TJvXPBar), `TToolBar`, `TMainMenu` | `TSpkToolbar` (Ribbon) kao opcija |

### 2.4 Stranica "TyphAccess: Logika i uređivači"

| Komponenta | Vrsta | Što radi |
|---|---|---|
| **Editor** | vizualna obitelj | uređivač koda: varijante `4gl`, `sql`, `expression`, `pascal`, `json`, `text`; pokretač **SynEdit** (poglavlje 4) |
| `TaDatabase` | nevizualna | baza (SQLite/PostgreSQL/MariaDB), objekti aplikacije, postavke |
| `TaExpression` | nevizualna | računanje izraza s varijablama |
| `TaFormBinder` | nevizualna | izračun, pravila, boje i vidljivost na bilo kojoj kontroli |
| `TaReport` | nevizualna | izvješće: pregled, PDF, HTML |
| `TaProgram` | nevizualna | 4GL program iz baze ili teksta |
| `TaSource` | nevizualna, **nova** | izvor podataka: tablica, SQL, izraz, popis ili 4GL (`TaSourceDef`), daje `TDataSet` svim obiteljima |
| `TaTheme` | nevizualna, **nova** | tema (tokeni) aplikacije: svijetla/tamna, prebojavanje, obavijest kontrolama |

**Ukupno 17 vizualnih obitelji** (7 + 5 + 4 + Editor) i **7 nevizualnih** komponenti.

---

### 2.5 Odluke korisnika (2026-11-07)

00. **Zadani stil je `rounded`; `pill` se uvodi kasnije kao opcija; gustoća (kompaktno/normalno/prostrano) također kasnije.** Prva faza (R2b) gradi `rounded` i `square`; arhitektura tokena `shape` i `density` ostavlja mjesto za oboje.

0. **TAChart je zadani pokretač Charta** (ne neobavezni); vlastito crtanje ostaje samo za izvješća, PDF i HTML, s istom paletom iz tokena. **Tema je JSON** (korisnik dodaje svoju). **Font: za sada isključivo JetBrains Mono** (poglavlje 5.8).

1. **17 obitelji potvrđeno.**
2. **Grid = `TRxDBGrid` kao zadani pokretač.** Napredniji je od `TDBGrid`: podnožje sa zbrojevima, filtri u zaglavlju, izvoz. Obavezno: (a) **bojanje redova i ćelija** po pravilu (`CondFormat` iz `TaFormBinder`, tokeni `success/warning/danger`, naizmjenične boje redova); (b) **unos podataka izravno u mrežu** (varijanta `entry`): npr. forma računa s unosom stavki: novi red na dnu, Tab/Enter prelazi na iduću ćeliju, padajući izbor artikla (lookup), automatski izračun iznosa retka i zbroja u podnožju, brisanje retka, provjera pravila po ćeliji.
3. **Gumbi i kartice (Pages) se prilagođavaju**: standardni LCL oblik je kvadratan, mi dodajemo **stil oblika** (poglavlje 5.6): `square`, `rounded`, `pill`. `TPageControl` ostaje pokretač, ali ga crta naš stilizator.
4. **Stil oblika vrijedi za cijelu obitelj polja:** ako je stil `pill`, i Edit, Combo, Spin, Date i Search polja su pilule; ništa se ne miješa.
5. **Boja teme prati i dijelove kontrola:** u zelenoj temi gumb padajućeg popisa na Combo-u je zelen, u crvenoj crven (poglavlje 5.7).

## 3. Odluke o bibliotekama

Ocjena po mjerilima M1–M5 (poglavlje 1). "Zadano" = ulazi u zadanu paletu; "Neobavezno" = pokretač koji se uključi paketom `typhaccess_ext`; "Odbijeno" = ne koristimo.

| Biblioteka (paket) | Odluka | Što uzimamo / zašto ne |
|---|---|---|
| **LCL** (`adLCL`) | **Zadano** | osnova svih obitelji; QSS stilizira sve što crta Qt |
| **SynEdit** (`BaseSynedit`, `lz_SynEditExtra`, `lz_SynUni`) | **Zadano** za Editor | bojenje, brojevi redaka, sklapanje, dopuna; nema ekvivalenta u LCL-u; bojenje se spaja na temu |
| **Zeos** (`pl_ZeosDBO`) | **Zadano** | baza |
| **TAChart** (`lz_taChart`) | **Zadano** (Chart) | bogatiji od našeg; boje, osi i fontovi preslikavaju se iz tokena (adapter); vlastito crtanje ostaje za izvješća/PDF/HTML |
| **RX** (`pl_RX`) | **Zadano za Grid** (`TRxDBGrid`), neobavezno za Edit | `TRxDBGrid` je najkorisniji dodatak (podnožje, filtri, izvoz); testirano na Qt6 |
| **JVCL** (`pl_JVCL`) | **Neobavezno, usko** | samo `TJvxCurrencyEdit`/`TJvCalcEdit` ako RX nije dovoljan; ostalo odbijeno (udvostručuje, XP izgled) |
| **KControls** (`pl_KControls`) | **Neobavezno, usko** | `TKMemo` kao bogati urednik; `KGrid`, `KHexEditor` odbijeno |
| **ECControls** (`pl_ECControls`) | **Neobavezno, usko** | `TECProgressBar`, `TECAccordion`; ostalo duplira LCL |
| **VirtualTrees** (`pl_VirtualTrees`) | **Neobavezno** (List, varijanta "veliki popis") | brzo crtanje stotina tisuća redaka |
| **HtmlViewer** (`pl_HtmlViewer`) | **Neobavezno** (Label html) | puni HTML; zadano je naš podskup |
| **SpkToolBar** (Ribbon) | **Neobavezno** | samo za korisnike koji žele Office izgled; mijenja izgled pa nije u zadanom |
| **BGRAControls** (`pl_BGRAcontrols`) | **Odbijeno** | vlastiti iscrtani izgled ne prati QSS; mogli bi se uskladiti samo kroz njihov `TBCDefaultThemeManager` (zaseban posao) |
| **ExtTabCtrl** (`pl_ExtTabCtrl`) | **Odbijeno** | imamo `TaTabBar` (Qt6 ne crta tipke zatvaranja na karticama) |
| **LazReport, FpReport, FortesReport** | **Odbijeno** | imamo vlastiti motor izvješća (isti izlaz za pregled, PDF, HTML) |
| **pl_Barcodes, ZXing, QRCodeGen** | **Odbijeno** za crtanje | imamo vlastito i FCL-ovo kodiranje; ZXing bi bio zanimljiv za *čitanje* kasnije |
| **LuiControls, MiniControls, Orpheus, UserControl** | **Odbijeno** | nema jasne koristi za poslovne aplikacije |
| **Indy, Synapse, mORMot, WebUI, CEF** | **Odbijeno** | izvan opsega palete (mreža i web) |

**Pravilo za nove biblioteke:** kandidat prolazi M1 probnim projektom (po uzoru na `tests/jvspike`), zatim M2 snimkom u obje teme, pa tek onda ulazi u tablicu odluka.

---

## 4. Obitelj Editor (SynEdit)

### 4.1 Zašto SynEdit

Uređivači 4GL-a, SQL-a, izraza i PascalScript modula danas su `TMemo` s nešto pomoći. SynEdit daje ono što korisnik od uređivača koda očekuje, a već je dio CodeTyphona.

| Mogućnost | Danas | Sa SynEditom |
|---|---|---|
| Bojenje sintakse (ključne riječi, nizovi, komentari, brojevi) | ne | da |
| Brojevi redaka, trenutni redak | djelomično | da |
| Sklapanje blokova (`MAIN`…`END MAIN`, `IF`…`END IF`) | ne | da |
| Dopuna koda (tablice, stupci, funkcije, programi) | ne | da, iz baze |
| Oznake grešaka u rubu (`redak:stupac` iz parsera) | poruka na dnu | valovita crta + ikona |
| Pretraga i zamjena s regularnim izrazima | osnovna | da |
| Višestruki kursori, uvlačenje, komentiranje bloka | ne | da |
| Predlošci (snippeti) | ne | da: **kosturi `.4glt`** kao predlošci |

### 4.2 Varijante i bojenje

| Varijanta | Bojenje | Dopuna koda | Napomena |
|---|---|---|---|
| `4gl` | **novo**: `TSynCustomHighlighter` nad ključnim riječima iz `ta_fgl` | tablice i stupci, funkcije izraza, nazivi programa i izvješća, varijable programa | sklapanje po `MAIN`/`FUNCTION`/`IF`/`WHILE`/`FOR` |
| `sql` | gotovo (`SynHighlighterSQL`) uz naše funkcije | tablice, stupci, `[?Parametar]` | |
| `expression` | **novo**: polja `[ime]`, funkcije, nizovi | polja izvora, funkcije jezika izraza | jednoredni način za svojstva |
| `pascal` | gotovo (`SynHighlighterPas`) | uključuje procedure modula | za PascalScript module |
| `json`, `text` | gotovo | — | |

### 4.3 Veza s ostalim dijelovima plana

- **Blokovski uređivač ostaje** kao drugi prikaz istog programa (prekidač *Blokovi / Tekst*), a tekstni prikaz postaje Editor.
- **Greške parsera** (`datoteka:redak:stupac: poruka`) postaju oznake u rubu; klik na grešku skače na redak.
- **Kosturi `.4glt`** (glavni plan, poglavlje 6.2) dolaze kao predlošci dopune: `rec` + Tab = kostur "Popis s filtrom".
- **Svojstva s izrazima** (`VisibleIf`, `Rule`, `CondFormat`) otvaraju jednoredni Editor varijante `expression` s dopunom polja.

### 4.4 Rizici

- SynEdit se u izvršnom obliku povezuje u cijeli TyphAccess (veličina binarne datoteke raste); **mjeriti** prije odluke (cilj: manje od 3 MB).
- Bojenje i boje oznaka moraju slijediti temu (tamna varijanta); SynEdit ima vlastite atribute, pa ih treba preslikati iz tokena (poglavlje 5.4).

---

## 5. Jedinstvena grafička tema

### 5.1 Stanje danas

Tema je već **dobra osnova**, ali nije imenovana kao sustav:

- `ta_theme.pas` primjenjuje **Qt stilsku tablicu (QSS)** s devet vrijednosti (`Bg`, `Fg`, `Border`, `Soft`, `Accent`, `AccentSoft`, `Header`, `Input`, `Tip`) za svijetlu (`thModern`) i tamnu (`thModernDark`) varijantu. Radi samo na Qt6, a za sve što crta LCL (popisi, tablice, polja) postoji `RecolorForm`.
- `TaSideMenu` ima vlastitu paletu (`Palette`) s istim naglaskom (`#2563EB`), ali kao posebne konstante.
- `TaChart` ima vlastiti niz od 8 boja serija.
- Ikone su zaseban skup (`ikone/`, svijetle i tamne SVG) s `IconDarkMode`.

Rezultat: izgled je skladan, ali **tokeni su razbacani** u tri jedinice. Plan ih skuplja na jedno mjesto.

### 5.2 Tokeni teme (verzija 1)

Boje preuzete iz postojećeg koda (paleta "slate" + plavi naglasak); nove vrijednosti označene su **novo**.

| Token | Svijetla | Tamna | Značenje |
|---|---|---|---|
| `bg` | `#F1F5F9` | `#0F172A` | pozadina prozora |
| `surface` (`Input`) | `#FFFFFF` | `#111827` | polja, popisi, kartice |
| `soft` | `#F8FAFC` | `#1E293B` | sporedne plohe (izbornik, onemogućeno) |
| `header` | `#E2E8F0` | `#1E293B` | zaglavlja tablica i skupina |
| `border` | `#CBD5E1` | `#334155` | obrubi |
| `text` | `#0F172A` | `#E2E8F0` | tekst |
| `text-soft` | `#64748B` **novo** | `#94A3B8` | sporedni tekst, onemogućeno (danas `#94A3B8`) |
| `accent` | `#2563EB` | `#60A5FA` | naglasak, fokus, odabir |
| `accent-soft` | `#DBEAFE` | `#1E3A5F` | pozadina odabira i prelaska mišem |
| `tip` | `#1E293B` | `#334155` | oblačići |
| `success` | `#16A34A` **novo** | `#4ADE80` **novo** | uspjeh (Da, spremljeno) |
| `warning` | `#D97706` **novo** | `#FBBF24` **novo** | upozorenje |
| `danger` | `#DC2626` **novo** | `#F87171` **novo** | greška, neispunjeno pravilo (zamjenjuje `#C00000` iz primjera) |
| `danger-soft` | `#FEE2E2` **novo** | `#4C1D1D` **novo** | pozadina greške (zamjenjuje `#FFE9E9` i `RuleBad`) |
| `radius` | 6 px (gumbi), 5 px (polja), 8 px (kartice) | isto | zaobljenje |
| `space` | 4, 8, 12, 16 px | isto | razmaci |
| `control-height` | 28 px | isto | visina jednoredne kontrole |
| `font` | **JetBrains Mono**, 10 pt | isto | jedini font za sada; naslovi 12 i 16 pt podebljano; vidi 5.8 |
| `focus` | 1 px `accent` | isto | obrub fokusa |
| `shape` | `rounded` | isto | oblik kontrola: `square` (0–2 px), `rounded` (5–6 px), `pill` (pola visine); vrijedi za gumbe, polja, kartice, značke (5.6) |
| `accent` (po temi) | plava; zelena `#16A34A`, crvena `#DC2626`, ... | svjetlije | cijela tema se izvodi iz jednog naglaska (5.7) |
| `chart[0..7]` | `#2563EB`, `#F97316`, `#16A34A`, `#DC2626`, `#9333EA`, `#0891B2`, `#CA8A04`, `#DB2777` **novo** | svjetlije za tamnu | serije grafikona (danas "tab10" paleta, ne prati naglasak) |

Tokeni se čuvaju kao jedan zapis (JSON), a ne kao razbacane konstante: korisnik može dodati vlastitu temu (npr. "Obrt zeleno") promjenom nekoliko vrijednosti.

### 5.3 Kako tema dolazi do kontrola

| Vrsta kontrole | Kako dobiva izgled |
|---|---|
| **LCL kontrole na Qt6** (polja, gumbi, popisi, kartice) | QSS iz tokena (`ThemeSheet`), kao i danas |
| **LCL kontrole koje Qt ne crta** (`TDBGrid`, `TStringGrid`, `TListView` u nekim dijelovima) | `RecolorForm` prebojava iz tokena |
| **Vlastite iscrtane kontrole** (`TaSideMenu`, `TaTabBar`, `TaChart`, switch, ring, led, card) | čitaju tokene izravno (`TaTheme.Tokens`) i **ponovno se crtaju pri promjeni teme** (obavijest `ThemeChanged`) |
| **Kontrole iz drugih biblioteka** (RX, JVCL, TAChart, SynEdit) | RX/JVCL: QSS i `RecolorForm`; TAChart i SynEdit: **adapter** koji preslikava tokene u njihove atribute (boje serija i osi, boje bojenja sintakse) |
| **Ikone** | već dvije grupe (svijetle i tamne); token `icon-set` bira grupu |
| **Izvješća, PDF, HTML** | zasebna **tema ispisa** (svijetla, bez naglašenih pozadina); ista paleta grafikona |

Jedno sučelje: `TaTheme.Apply(ATheme)`, `TaTheme.Tokens.Accent`, `TaTheme.OnChange`.

### 5.4 Pravila izgleda (da kontrole budu skladne)

1. **Jedan naglasak** (`accent`). Nema drugih boja za označavanje osim semantičkih (`success`, `warning`, `danger`).
2. **Jedna visina i zaobljenje** za sve jednorednne kontrole (polje, padajući popis, gumb, spin): 28 px, polumjer iz tokena.
3. **Isto stanje svugdje:** normalno, prelazak mišem (`accent-soft`), fokus (obrub `accent`), onemogućeno (`text-soft` na `soft`), greška (`danger` na `danger-soft`).
4. **Razmaci su višekratnici od 4 px**; dizajner prvo ponudi 8 i 16.
5. **Ikone** uvijek iz zalihe (`ikone/`), jedna debljina crte, 16 i 24 px.
6. **Tipografija:** jedan font i tri veličine (tekst, podnaslov, naslov).
7. **Brojke** u tablicama desno poravnate, hrvatski oblik (`1.234,50`).

### 5.5 Provjera teme

- **Galerija** (`tests/theme_gallery`): jedan prozor sa svim obiteljima i varijantama, u svijetloj i tamnoj temi, u stanjima normalno/fokus/onemogućeno/greška. Snima se u PNG (offscreen).
- **Pregled uživo**: ista galerija kao prozor "Tema" u dizajneru i IDE-u (promjena tokena uživo).
- **Kriterij prihvaćanja:** galerija se pregledava ljudskim okom pri svakoj većoj promjeni; uz to automatski test da nijedna kontrola ne koristi boju koja nije token ni korisnikov izbor.

---

### 5.6 Stil oblika (square / rounded / pill)

Token `shape` mijenja geometriju svih kontrola odjednom, tako da izgled ostaje skladan:

| Kontrola | `square` | `rounded` | `pill` |
|---|---|---|---|
| Button (svi tipovi) | polumjer 2 px | 6 px | pola visine (14 px pri 28 px) |
| Edit, Spin, Date, Search, Combo (polje) | 2 px | 5 px | pola visine, **veći lijevi i desni unutarnji razmak** (npr. 12 px) da tekst ne dodiruje zakrivljeni rub |
| Tabovi (Pages, `TaTabBar`) | pravokutni | zaobljeni gornji kutovi | **pilule** (aktivna kartica puna `accent`, ostale `soft`) |
| Značke (badge), Segmented | 2 px | 6 px | pilula |
| Kartice, paneli, mreža | 2 px | 8 px | **ostaju 8 px** (pilula na velikoj plohi izgleda loše) |
| Check, Radio | kvadrat / krug | zaobljeni kvadrat / krug | zaobljeni kvadrat / krug (nepromijenjeno) |

Pravila: (1) stil bira se jednom, na temi (`TaTheme.Shape`), s mogućnošću nadjačavanja po kontroli; (2) kontrola s drukčijim oblikom od ostalih u istoj formi ne smije proći galeriju; (3) QSS: `border-radius` iz tokena; `TPageControl` i gumbe na Qt6 stilizira QSS (`QTabBar::tab`, `QPushButton`), a gdje Qt ne crta (RX mreža, SynEdit) oblik se ne mijenja.

**Prilagodba gumba i tabova:** `TBitBtn`/`TSpeedButton` i `TPageControl` zadržavamo kao pokretače (ponašanje, tipkovnica, dizajner), a izgled preuzima QSS ili tanki `TaButtonPainter`/`TaTabPainter` ako QSS nije dovoljan (npr. pilula s ikonom i znakom zatvaranja).

### 5.7 Boja teme na dijelovima kontrola

Cijela tema izvodi se iz **jednog naglaska** (`accent`): iz njega se računaju `accent-soft`, `accent-hover`, `accent-pressed`, `focus` i boja teksta na naglasku (`on-accent`, bijela ili tamna po kontrastu, najmanje 4.5:1).

| Dio kontrole | Boja |
|---|---|
| Gumb padajućeg popisa na Combo-u (`::drop-down`, strelica) | `accent`; strelica `on-accent`; u pilula stilu okrugli gumb unutar polja |
| Spin strelice, gumb kalendara (Date), gumb pretrage | `accent` na isti način |
| Primarni gumb (default) | `accent`; sporedni: obrub `accent`, prozirno |
| Aktivan tab, odabrani red, fokus, kvačica, switch uključen, klizač, progres | `accent` / `accent-soft` |
| Zaglavlje mreže, naizmjenični redovi | iz `header`/`soft`, uz blagi dodir naglaska |
| Grafikoni | prva serija `accent`, ostale iz palete serija |
| SynEdit | trenutni redak, odabir i oznake iz `accent-soft` |

Gotove teme: **Plava** (zadana), **Zelena** (`#16A34A`), **Crvena** (`#DC2626`), **Ljubičasta**, **Narančasta**, **Grafit**, svaka u svijetloj i tamnoj varijanti; korisnik dodaje vlastitu zadavanjem samo naglaska (i neobavezno oblika). Semantičke boje (`success`, `warning`, `danger`) **se ne mijenjaju s temom**; u crvenoj temi `danger` mora biti dovoljno različit od naglaska (provjera u galeriji: crvena tema koristi tamniji `danger` i uvijek ikonu uz boju, ne samo boju).

Provjera: galerija se snima za 6 tema x 2 varijante x 3 oblika; kriterij je da je u svakoj kombinaciji vidljiv samo jedan naglasak, a kontrast teksta na naglasku najmanje 4.5:1.

### 5.8 Font i tema kao JSON

- **Font:** za sada samo **JetBrains Mono** (tekst, polja, mreža, izbornici, grafikoni, izvješća; SynEdit ga već koristi kao font koda). Jedan token `font.family`; izmjena kasnije mijenja jednu vrijednost. Nema drugih fontova u paleti dok ne odlučimo drukčije.
  - Monospace znači jednaku širinu znamenki, pa brojke u mrežama i iznosima na računu same ostaju poravnate. Treba paziti na širinu: kontrole i stupci mjere se po širini znaka, ne po starim pretpostavkama.
  - **Isporuka:** font se dolazi uz aplikaciju (mapa `fonts/`, licenca OFL dopušta) i registrira pri pokretanju, da radi i na računalu gdje nije instaliran; ako datoteke nema, pada na sustavni monospace. Isto u PDF izvješćima (ugraditi podskup fonta).
  - Svjesni kompromis: monospace je širi od običnog sans fonta, pa su forme veće; provjeriti u galeriji i prilagoditi zadane širine.
- **Tema kao JSON:** jedna datoteka po temi (`themes/*.json`), a spremaju se i u bazu aplikacije. Minimalan zapis: `{"name":"Zelena","accent":"#16A34A","shape":"pill","dark":false}`; sve ostalo izvodi se iz naglaska (5.7), a svaki token može se nadjačati ručno (`"tokens":{"radius":8,...}`). Učitavanje je provjereno (nepoznati ključ upozorava, loš kontrast naglaska javlja grešku), a `TaTheme.LoadFromFile/SaveToFile` i prozor "Tema" u dizajneru i IDE-u rade s istim zapisom.

## 6. Pretvorba TyphAccess kontrola u Lazarus komponente

### 6.1 Zašto postojeće klase nisu dovoljne

`TaTextBox`, `TaComboBox` itd. danas su tanke ljuske koje nose `Def: TaControlDef`. Svojstva (izvor, pravilo, oblik, radnja) žive u definiciji, a ne u komponenti, pa ih Inspektor objekata ne vidi i `.lfm` ih ne sprema. Pretvorba ih čini **samostalnima**.

### 6.2 Mapiranje postojećih klasa

| Danas | Postaje | Napomena |
|---|---|---|
| `TaTextBox`, `TaComboBox` | **Edit** (`Variant` = text, combo, ...) | |
| `TaMemo`, `TaRichText` | **Memo** | rich ostaje na `TRichMemo` |
| `TaLabel`, `TaHyperlink` | **Label** | |
| `TaButton`, `TaToggle` | **Button** | |
| `TaCheckBox` | **Check** | |
| `TaOptionGroup` | **Choice** | |
| `TaListBox` | **List** | |
| `TaSubform` | **Grid** (varijanta datasheet/subform) + **Panel** | veza glavna/detalj ostaje svojstvo |
| `TaTabControl` | **Pages** | |
| `TaImage`, `TaRect`, `TaLine` | **Image** | oblici su varijante |
| `TaChart` | **Chart** | |
| `TaBarcode` | **Barcode** | |
| `TaSideMenu` | **Menu** | već ima zbirke `Groups`/`Items` |
| `TaPageBreak`, `TaSubreportBox` | samo u izvješćima, ostaju kao dizajnerski elementi | |
| *(nema)* | **Progress**, **Calendar**, **Editor** | nove obitelji |

### 6.3 Što znači "pretvoreno" (kontrolni popis po obitelji)

Obitelj je gotova tek kad ispuni svih osam:

1. **Svojstva su objavljena** (uključujući izvor `TaSourceDef`, pravilo, oblik, `VisibleIf`, `EnabledIf`, `CondFormat`, radnje) i spremaju se u `.lfm`.
2. **Tablica preslikavanja `TaPropMap`:** isti zapis ide iz JSON definicije u komponentu i natrag (jedan redak po svojstvu).
3. **Varijanta** (`Variant`) i podobjekt `Options` koji ovisi o njoj.
4. **Zamjenjivi pokretač** (`IaEngine`) s LCL pokretačem i, gdje je dogovoreno, neobaveznim.
5. **Registracija i ikone** (24, 36, 48 px, svijetle i tamne).
6. **Property i component editori** (dvoklik, "Prikaži kao", izbor izvora, radnje) iz sloja dijaloga (glavni plan, poglavlje 5).
7. **Tema:** čita tokene, prolazi galeriju u obje teme.
8. **Testovi:** čitanje i pisanje definicije, ponašanje (pravila, izrazi), snimka izgleda, zatvaranje bez pada.

### 6.4 Redoslijed pretvorbe

Prvo se pretvara ono što je najčešće i najjednostavnije; Editor ide rano jer daje najvidljiviju korist uređivačima:

| Red | Obitelji | Razlog |
|---|---|---|
| 1 | Edit | najčešća kontrola, najviše varijanti, prototip arhitekture |
| 2 | Button, Label, Check | jednostavne, brzo gotove |
| 3 | **Editor** | donosi SynEdit i dopunu koda u sve uređivače |
| 4 | Memo, Choice, List | nastavak osnovnog skupa |
| 5 | Grid, Panel, Pages | strukturne obitelji, izvori iz 4GL-a |
| 6 | Image, Chart, Barcode, Menu, Progress, Calendar | ostatak palete |

---

## 7. Što se dobiva za korisnika

- **Jedna paleta** na četiri stranice, jasno imenovana, s oko 24 stavke umjesto stotina.
- **Isti izgled** svugdje: na formama, u izvješćima, u dizajneru i u IDE-u; svijetla i tamna tema jednim klikom.
- **Uređivač koda** koji pomaže (boje, dopuna, greške u rubu).
- **Ista komponenta u IDE-u i u TyphAccessu**, s istim svojstvima i istim dijalozima.
- **Moguće proširenje** bez nove palete: napredna mreža, grafikon i unos iznosa uključuju se kao pokretač, a ne kao nova imena.

---

## 8. Redoslijed razvoja i procjena (kasnije; samo orijentir)

| Korak | Posao | Procjena |
|---|---|---|
| R1 | **Tokeni teme** u jednu jedinicu (`TaTheme`), JSON zapis, JetBrains Mono (isporuka i rezervni font), nove semantičke boje | 2 dana |
| R2 | **Galerija i snimke** u obje teme (temelj za sve kasnije provjere) | 1 dan |
| R2b | **Stil oblika** (`square/rounded/pill`) i izvođenje teme iz jednog naglaska (zelena, crvena...), QSS za gumbe, polja, Combo gumb i tabove | 2 dana |
| R3 | Okvir obitelji: `IaEngine`, registar, `Variant`, `Options`, `TaPropMap` | 2 dana |
| R4 | Prototip **Edit** (text, combo, droplist, spin, date, currency) + testovi + snimke | 3 dana |
| R5 | **SynEdit i obitelj Editor**: bojenje 4GL-a i izraza, dopuna iz baze, greške u rubu, ugradnja u uređivače | 3 dana |
| R6 | Button, Label, Check | 2 dana |
| R7 | Memo, Choice, List | 2 dana |
| R8 | Grid (`TRxDBGrid` kao zadani: bojanje redova, varijanta `entry` za unos stavki računa), Panel, Pages | 5 dana |
| R9 | Image, Chart (`TAChart` zadani + adapter teme, vlastiti za izvješća), Barcode, Menu, Progress, Calendar | 4 dana |
| R10 | Property i component editori u oba okruženja; ikone | 3 dana |
| R11 | Paket `typhaccess_ext` (neobavezni pokretači) i dokumentacija palete | 2 dana |

Zbroj: oko **32 radna dana** (šest tjedana), s prvim vidljivim rezultatom (tema u galeriji, pa Edit) u prvom tjednu.

---

## 9. Rizici

| Rizik | Vjerojatnost | Ublažavanje |
|---|---|---|
| Domaćin (host) pokretača otežava dizajnerske ručke i redoslijed tabulatora | srednja | prototip Edit (R4) prije svega ostalog; alternativa je jedna klasa nad `TCustomComboBox` |
| Tema se ne primjenjuje na neku kontrolu na Qt6 | srednja | `RecolorForm`; kontrola koja prolazi M1 ali pada M2 ostaje izvan zadane palete |
| SynEdit povećava binarnu datoteku i vrijeme prevođenja | niska | mjeriti u R5 |
| Vlastito crtanje (switch, ring, led, card) izgleda drukčije od Qt kontrola | srednja | iste mjere i stanja (poglavlje 5.4), galerija |
| Opseg | visoka | koraci R1–R5 daju korist sami za sebe; ostalo po važnosti |
| Preimenovanje boja (`#C00000` → `danger`) mijenja izgled postojećih aplikacija | niska | zadržati stare boje u zapisima; tokeni vrijede za nove i za sve što nema vlastitu boju |

---

## 10. Otvorena pitanja za odluku

| # | Pitanje | Preporuka |
|---|---|---|
| 1 | Je li popis od 17 obitelji u redu? (dodati ili maknuti) | kako je navedeno |
| ~~1~~ | ~~17 obitelji~~ | **potvrđeno** |
| ~~3~~ | ~~TRxDBGrid~~ | **odlučeno: zadani pokretač Grida** |
| ~~2~~ | ~~TAChart~~ | **odlučeno: zadani pokretač Charta** |
| 3 | Uzimamo li **TRxDBGrid** kao neobavezni pokretač mreže? | da; najkorisniji dodatak |
| ~~4~~ | ~~Tema kao JSON~~ | **odlučeno: da** |
| 5 | Je li **tamna tema** jednako važna kao svijetla od prvog dana? | da (već postoji) |
| ~~6~~ | ~~Font~~ | **odlučeno: samo JetBrains Mono za sada** |
| ~~8~~ | ~~Zadani stil oblika~~ | **odlučeno: `rounded` zadano; `pill` kasnije kao opcija** (R2b prvo radi `rounded` i `square`, `pill` dolazi poslije) |
| 9 | Treba li Grid u `pill` stilu imati pilula-filtre u zaglavlju? | da, samo filtri; mreža ostaje pravokutna |
| ~~7~~ | ~~Gustoća~~ | **odlučeno: kasnije** (token `density` predviđen, nije u prvoj fazi) |
