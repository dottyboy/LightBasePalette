# Paleta TyphAccess: obitelji, varijante, opcije

Svaka kontrola u paleti je **obitelj** s više **varijanti**. Varijanta se bira svojstvom `Variant` (u Inspektoru ili
kontekstnim izbornikom), a svojstva koja ovise o varijanti nalaze se u podobjektu `Options`. Zajednička svojstva
(`ControlSource`/`DataSource`+`DataField`, `VisibleIf`, `EnabledIf`, `CondFormat`, `Extra`, `PropertyClass` kod definicije
kontrole) ostaju ista kroz sve varijante; promjenom varijante vrijednost i zajednička svojstva ostaju.

Isti zapis ide u oba smjera: komponenta ↔ definicija kontrole (JSON u bazi) ↔ `.lfm`. Ključevi koje obitelj ne
poznaje čuvaju se u `Extra` i ne gube se pri pretvorbi.

## Stranice palete

Sve komponente su na **jednoj stranici palete, TyphAccess** (24 komponente, bez prebacivanja među stranicama), redom:

| Skupina | Komponente |
|---|---|
| Podaci | TaEdit, TaMemo, TaCheck, TaChoice, TaList, TaGrid, TaCalendar, TaContinuousForm |
| Prikaz | TaLabel, TaImage, TaChart, TaBarcode, TaProgress |
| Raspored i navigacija | TaButton, TaPanel, TaPages, TaMenu |
| Logika | TaEditor |
| Nevizualne | TaSideMenu, TaDatabase, TaExpression, TaReport, TaProgram, TaFormBinder |

## Obitelji

| Obitelj | Varijante | Vrijednost | Opcije (`Options`) |
|---|---|---|---|
| **Edit** | text, password, combo, droplist, spin, date, currency, lov | tekst / broj / datum; combo s `Keyed`: ključ | po varijanti; combo: `Keyed`, `Search`; `lov`: `Source`, `Map`, `Validate` |
| **Memo** | plain, rich, markdown | tekst; rich je mali HTML | `WordWrap`, `Preview` (markdown) |
| **Check** | checkbox, switch, radio, tristate | Boolean; tristate i Null | switch: `OnCaption`, `OffCaption` |
| **Choice** | radio, check, segmented, multisegment | ključ; check i multisegment: ključevi odvojeni zarezom | `Columns`, `MinSelected`, `MaxSelected` |
| **List** | list, checklist, iconlist, tree | ključ stavke(i) | `MultiSelect` (list, iconlist) |
| **Grid** | readonly, editable, datasheet, entry | – (izvor je `DataSource`) | `RowHeight`, `Zebra`, `SumFields` (podnožje) |
| **Calendar** | month, range, agenda | ISO datum; razdoblje `od..do` | `Days` (agenda) |
| **Label** | text, hyperlink, html, badge | natpis | hyperlink: `Address`; badge: `Tone` |
| **Image** | picture, shape, gradient, icon | – | `FileName`, `SizeMode`, `Shape`, `FillColor`, `LineColor`, `ColorTo`, `Icon`, `Svg` |
| **Chart** | bar, line, pie, gauge | stavke `natpis=vrijednost` | `Title`, `LabelField`, `ValueField`, `Max` |
| **Barcode** | code128, ean13, ean8, code39, itf, qr, pdf417 | tekst koji se kodira | `ShowText` |
| **Progress** | bar, ring, led, busy | broj od `Min` do `Max` | `Min`, `Max`, `WarnAt`, `DangerAt`, `ShowText` |
| **Button** | standard, default, cancel, toggle, flat, link, image, menu, split | toggle: Boolean | `Icon`, `MenuItems` (menu, split) |
| **Panel** | plain, group, card, expander, scroll, splitter | – | `Expanded` (expander), `MinSize` (splitter) |
| **Pages** | tabs, list, steps, accordion | indeks aktivne stranice | `TabsAtBottom` (tabs) |
| **Menu** | side, toolbar, tree | – | `Accordion`, `Compact` (side) |

Stavke popisa (Choice, List) pišu se kao `ključ=natpis` ili samo `natpis`. Stablo (List `tree`) uzima razinu iz uvlake
od po dva razmaka. Izbornik (Menu) koristi zapis bočnog izbornika: `# Skupina|ikona` i `Natpis|radnja|ikona`.

## Veza na podatke

- Polja koja korisnik mijenja (Edit, Memo, Check, Choice, List, Calendar, toggle gumb) imaju `DataSource` i `DataField`
  (komponenta) odnosno `ControlSource` (definicija). Check, Choice, List i Calendar **odmah upisuju** u polje pri izboru;
  Edit i Memo pri izlasku iz polja.
- Prikaz (Label, Barcode, Progress) čita polje samo za prikaz. Chart čita skup podataka (`DataSource` +
  `LabelField` + `ValueField`) ili stavke.
- `ReadOnly` vraća svaku promjenu korisnika (i kod višestrukog izbora).

## Popis vrijednosti (LOV) i upit po formi

- Kontrola s `Lov` (izvor: tablica, `sql:`, `list:` ili `fgl:`) otvara popis tipkom **F9** ili gumbom "…". Izbor upisuje
  više polja prema `LovMap` (`stupac=kontrola;…`), a `LovValidate=1` odbija vrijednost koje nema u popisu.
- Tablica: `GridLov` forme (`polje | izvor | stupac=polje_tablice;…`, više unosa odvojeno s `;;`), F9 na ćeliji.
- **F7** otvara upit po formi (u tablici traku s poljem po stupcu), **F8** ga izvršava, **Esc** odustaje. Uzorci: `Ma*`,
  `>100`, `10..20`, datum. Tipke su promjenjive (`tipke.json`).

## Klase svojstava i biblioteka objekata

- **Klasa svojstava** je imenovan skup svojstava (npr. `PoljeIznosa`: Format `#,##0.00`, Align `right`, ForeColor). Kontrola je
  navodi svojstvom **PropertyClass**; klasa popunjava samo ono što kontrola sama nema (vlastito nadjačava). U
  Inspektoru: padajući popis klasa i stavka *nova klasa iz ove kontrole…* (dijalog s popisom svojstava kontrole koja idu u
  klasu; može se i obrisati). Klase se primjenjuju pri otvaranju forme.
- **Grupe kontrola** (npr. adresni blok): u dizajneru izbornik rasporeda → *Spremi odabrane kontrole kao grupu…* i
  *Umetni grupu kontrola…*; nazivi koji se sudaraju dobivaju brojku.
- **Biblioteka** (klase + grupe) izvozi se u datoteku i uvozi u drugi projekt (`LibraryExport` / `LibraryImport`, bez
  prepisivanja postojećeg ili s njim). Kosturi (`skeletons/`) i 4GL programi i dalje žive uz bazu/mapu.

## Pokretači (neobavezni paket `typhaccess_ext`)

Zadani pokretači su LCL (`TDBGrid`, vlastito crtanje grafikona). Paket **`typhaccess_ext`** dodaje:

| Obitelj | Pružatelj | Pokretač |
|---|---|---|
| Chart (bar, line, pie) | `tachart` | `TChart` iz `lz_taChart` |
| Grid (sve varijante) | `rx` | `TRxDBGrid` iz `pl_RX` s pravim podnožjem zbrojeva |

Uključuje se jednom: `SetPreferredProvider('tachart')` odnosno `'rx'` (prije stvaranja kontrola). Jedinica `ta_ext_select` u paketu to radi pri pokretanju prema varijabli okoline `TYPHACCESS_PROVIDER` (`tachart` ili `rx`). Light IDE s paketom: `LIGHT_EXT=1 bash light/install_in_ide.sh`, pa `TYPHACCESS_PROVIDER=tachart light/typhon-light.sh` (gradnja Light IDE-a s paketom isprobana 2026-11-11: uspjela, IDE se pokreće i pokazuje jednu stranicu TyphAccess). Bez paketa sve obitelji
rade s LCL pokretačima. Ispitivanje: `tests/ext/run.sh`.

## Vlastiti pokretači (pružatelj `own`, neovisni o Qt/GTK)

Polja koja crta sam TyphAccess (`TCustomControl`), pa izgledaju i rade isto na svakom sučelju. Uključuju se varijablom okoline
`TYPHACCESS_PROVIDER=own` ili `SetPreferredProvider('own')`; varijante koje još nemaju vlastiti pokretač ostaju na LCL-u.

| Obitelj | Varijante | Stanje |
|---|---|---|
| Edit | text, password, currency | gotovo 2026-11-16 (`ta_ownedit`): unos i brisanje (UTF-8), kursor i oznaka tipkama i mišem, riječi (Ctrl+strelice, dvoklik), Ctrl+A/C/X/V/Z/Y, maska, najveća duljina, samo čitanje, poravnanje, boje iz teme |
| Edit | combo, droplist | gotovo 2026-11-16 (`ta_owncombo`): popis se crta preko forme (ne izvorni prozor), tipke F4 / Alt+strelica dolje / strelice / PgUp,PgDn / Enter / Esc, kotačić i klizač, dopuna tipkanja (AutoComplete), pretraga (Search suzuje popis), ključevi `ključ=natpis`, droplist: slovo skače na stavku, razmaknica otvara |
| Edit | date | gotovo 2026-11-16 (`ta_owndate`): tipkanje u obliku dd.mm.yyyy (i ISO iz baze), zapis u punom obliku pri izlasku, vlastiti mjesečni kalendar preko forme (F4 / Alt+strelica dolje, strelice dan/tjedan, PgUp/PgDn mjesec, Ctrl godina, Enter, Esc, Danas); isti kalendar je u dijalogu "Odaberi datum" koji otvara gumb .. uz datumska polja |
| Edit | spin | gotovo 2026-11-16 (`ta_ownspin`): samo znamenke i decimalni znak (zarez ili točka), strelice uz polje s ponavljanjem, Gore/Dolje (PgUp/PgDn deset koraka), kotačić, granice i decimale iz opcija, zapis u punom obliku pri izlasku |
| Edit | lov | gotovo 2026-11-16 (`ta_ownlov`): gumb "…" uz desni rub ili F9 traži popis vrijednosti (preko domaćina), samo čitanje gasi gumb |
| Edit | – | **sve varijante Edit obitelji imaju vlastiti pokretač** |
| Memo | plain | gotovo 2026-11-16 (`ta_ownmemo`): redci s prijelomom po riječima ili vodoravnim pomicanjem, Enter/Backspace/Delete preko redaka, oznaka preko redaka, strelice/Home/End/PgUp/PgDn (Ctrl riječi i početak/kraj), Ctrl+A/C/X/V/Z/Y, kotačić i klizač, najveća duljina, samo čitanje. Markdown (uređivač + pregled) i rich još su na LCL-u |
| Memo | rich | gotovo 2026-11-17 (`ta_ownrich`, osnova `ta_richbase`): vlastiti uređivač formatiranog teksta, isti zapis (mali HTML iz `ta_richtext`) kao RichMemo. Podebljano/kurziv/podcrtano/boja/veličina po znaku, odlomci s poravnanjem i natuknicom (svojstvo odlomka, ne tekst „• "), prijelom po riječima, strelice/Home/End/Ctrl, oznaka mišem i tipkama, Ctrl+A/C/X/V/Z/Y/B/I/U, kotačić i klizač, vlastita traka (B I U, paleta boja, veličina, ◀ ≡ ▶, natuknica, očisti), samo čitanje skriva traku. Tvornica `NewRichEditor` bira uređivač prema pružatelju; RichText kontrole na formama i markdown pregled koriste isti |
| Memo | markdown | gotovo 2026-11-17: izvorni tekst u vlastitom `TaOwnMemo`, pregled na vlastitom rich uređivaču (`TaOwnMarkdownEngine`) |
| List | list, checklist | gotovo 2026-11-17 (`ta_ownlist`): jedna ili više označenih stavki (Ctrl/Shift+klik, Shift+strelice, Ctrl+A), kvačice uz stavke (klik na kvadratić, razmaknica), strelice/PgUp,PgDn/Home/End, slovo skače na stavku, kotačić i klizač, samo čitanje |
| List | tree | gotovo 2026-11-17 (`ta_owntree`): trokuti za otvaranje/zatvaranje, tipke Gore/Dolje/Lijevo/Desno/Home/End/+/-/*, klik na trokut, dvoklik, kotačić i klizač, samo čitanje |
| List | iconlist | gotovo 2026-11-17 (`TaOwnList` u načinu `Tiles`): pločice u mreži s prvim slovom natpisa kao ikonom (prave ikone stavki nema ni u LCL varijanti), strelice u 2D, klik/Ctrl/Shift, klizač |
| Calendar | month, range, agenda | gotovo 2026-11-17 (`ta_owncalendar`, kalendar `TaOwnCalendar` iz `ta_owndate` sada i samostalan): ćelije se razvuku na veličinu domaćina, klik/strelice/PgUp,PgDn/kotačić (mjesec), razdoblje s istaknutim rasponom, agenda kao popis idućih dana |
| Grid | readonly, datasheet | gotovo 2026-11-17 (`ta_owngrid`, etape 0-2 plana `PLAN-vlastiti-grid.md`): pregled bez uređivanja; redci kao kod TDBGrida preko TDataLink-a (prozor oko tekućeg zapisa), stupci iz polja ili zadani, poravnanje, širine (povlačenje ruba zaglavlja), klik na naslov javlja događaj, uvjetno bojanje `OnPrepareCell`, zebra, indikator, logička polja kvačicom, okomiti i vodoravni klizač, kotačić, zbrojevi u podnožju. `InnerGrid` vraća nil (nema TDBGrid-a) |
| Grid u izvršitelju formi | datasheet, podforme | gotovo 2026-11-17 (`ta_gridview`): `TaFormRunner` kroz adapter koristi vlastiti Grid uz `TYPHACCESS_PROVIDER=own` (stupci iz rječnika, padajući popis za strani ključ, uvjetno bojanje `GridFormat`, sortiranje, uređivanje, podforme); `MainGrid`/`SubGrid` vraćaju nil, a `GridView`/`SubView` daju prikaz |
| Grid | označavanje i kopiranje | gotovo 2026-11-17: Ctrl+klik, Shift+klik, Shift+strelice, Ctrl+A; Ctrl+C kopira označene redke (stupci odvojeni tabulatorom) ili tekst ćelije; Ctrl+Delete briše sve označene (uz pitanje); povlačenje naslova mijenja redoslijed stupaca; dvoklik na rub naslova prilagođava širinu sadržaju; Esc odznačuje |
| Grid | potkartica (podtablica) | gotovo 2026-11-17: svojstvo forme `SubDatasheet` (`auto` ili `podtablica|stupac_veze|polje_roditelja`) daje plus uz svaki redak popisa; otvara ugniježđenu tablicu s podredjenim zapisima (poput Accessa), Alt+Dolje/Gore otvara i zatvara tekući redak; generator aplikacije postavlja `auto` na popise glavnih tablica sa stavkama; samo uz `TYPHACCESS_PROVIDER=own` |
| Grid | editable, entry | gotovo 2026-11-17 (etapa 3): uređivanje u ćeliji (F2, Enter, drugi klik, dvoklik, tipkanje), vlastiti Edit/padajući popis (`PickList` stupca) preko ćelije, Enter/Tab/strelice potvrđuju i pomiču, Esc odustaje, greška polja ide u `OnEditError`, Space mijenja logičko polje, Insert novi zapis, Ctrl+Delete briše (uz pitanje), entry: Tab iz zadnje ćelije zadnjeg retka dodaje redak i uređivač ostaje otvoren |

Ne zna (zasad): unos preko IME-a (kompozicija), kontekstni izbornik, povlačenje teksta. Cijeli smoke test s `TYPHACCESS_PROVIDER=own` pada samo u testovima koji sami pretvaraju kontrolu u LCL klasu (`TaComboBox`, `TEdit`).

## Poznata ograničenja

- Izvršavanje formi i dizajner formi koriste obitelji za TextBox, ComboBox, CheckBox, Button, ToggleButton, Label, Hyperlink,
  MemoBox, RichText, OptionGroup, ListBox, Calendar, Progress, Image, Chart, Barcode, Rectangle, Line, Panel i Pages (varijanta se bira svojstvom
  *Variant* i vidi se odmah u dizajneru). Subform, TabControl i SideMenu još su stare kontrole. Panel i Pages su pogoni: kontrola im pripada svojstvima Container (naziv) i Page (samo Pages).
- Grid nema red filtara; Memo `markdown` pregled je jednostavan podskup; `scroll` pomiče samo djecu panela (ne ugniježđene izvršitelje).
- Ikone palete postoje u 24, 36 i 48 px, svijetle (zadano) i tamne: `LIGHT_ICONS=dark bash light/install_in_ide.sh` gradi Light IDE s tamnim ikonama za tamnu temu IDE-a.

## Kanban ploča (prikaz forme `board`)

Stupci su vrijednosti jednog polja s vezom na šifrarnik (faza, status), kartice su retci izvora. Povlačenje kartice u drugi stupac upisuje novu vrijednost polja u bazu; dvoklik otvara karticu u formi za uređivanje, gumb + u zaglavlju stupca otvara novi zapis s već upisanim stupcem. Tipke: strelice biraju karticu, Alt+Lijevo/Desno premješta je, Enter otvara. Kotačić pomiče stupac, Shift+kotačić ploču vodoravno. Cards bez vrijednosti idu u stupac „(bez)”.

U opisu aplikacije:

```
forma "Ploča procesa"
  izvor: serije
  raspored: ploca
  ploca: faza_id | naziv | vrsta_id, pogon_id, datum_pocetka | Serije
```

Postavka je `polje stupaca | naslov kartice | polja redaka | forma za uređivanje`. Stupci se slažu po polju `redni` (ako šifrarnik ima) pa po ključu. Jedinica: `ta_ownboard` (kontrola), `ta_formboard` (spoj s bazom), svojstvo forme `Board` u dizajneru.

## Nadzorna ploča (prikaz forme `dash`)

Kartica po skupini (npr. pogon), u njoj redak po mjernoj vrijednosti s bojom stanja i malim grafom (sparkline). Izvor je upit s jednim retkom po vrijednosti i stupcem `id`. Osvježava se sama (`osvjezi=` sekunde). Unutar kartice: točkica stanja (zeleno u redu, crveno izvan granica, žuto bez podataka), naziv, zadnja vrijednost i graf zadnjih vrijednosti.

```
forma "Nadzorna ploča"
  izvor: Ploca senzora
  raspored: nadzor
  nadzor: grupa=Pogon ;; naziv=Uredjaj ;; vrijednost=Vrijednost ;; jedinica=Jedinica ;; stanje=Stanje ;; info=Signal ;; serija=SELECT vrijednost FROM ocitanja WHERE uredjaj_id = :id ORDER BY vrijeme DESC, id DESC LIMIT 60 ;; osvjezi=5
```

`stanje`: tekst koji sadrži `PRENISKO` ili `PREVISOKO` je izvan granica, `nema` je bez podataka. Jedinice: `ta_owndash` (kontrola), `ta_formdash` (spoj s bazom), svojstvo forme `Dash` u dizajneru.

## Raspored (prikaz forme `timeline`)

Tjedna vremenska crta: sedam redaka (Pon–Ned), 24 sata po retku. Zapis rasporeda je traka koja vrijedi za odabrane dane; ponavljanje („svakih N minuta po M sekundi") crta se kao tanke crtice. Povlačenje po praznom retku stvara traku, povlačenje trake je pomiče, rubovi mijenjaju početak i kraj, oznake dana ispod crte uključuju i isključuju dane, Delete briše. Strelice pomiču odabranu traku za 15 minuta, Shift+strelice mijenjaju kraj. Traka koja prelazi ponoć (22:00–06:00) crta se na dva retka i uređuje u tablici. Svaka promjena odmah se upisuje u tablicu stavki.

```
forma "Raspored (vremenska crta)"
  izvor: rasporedi
  raspored: crta
  crta: glavni=SELECT r.id, u.naziv || ' - ' || r.naziv FROM rasporedi r JOIN uredjaji u ON u.id = r.uredjaj_id ORDER BY 2 ;; stavke=rasporedi_stavke ;; veza=raspored_id ;; dani=dani ;; od=od ;; do=do ;; svakih=svakih_min ;; trajanje=trajanje_s
```

Jedinice: `ta_owntimeline` (kontrola), `ta_formtimeline` (spoj s bazom), svojstvo forme `Timeline` u dizajneru.

### Prekidači i alarmi na nadzornoj ploči

Redak čija je uloga `izvrsni` (izlaz: svjetlo, pumpa, ventilator, dozator) prikazuje se kao **prekidač** sa stvarnim stanjem uređaja. Klik pita „Poslati naredbu?" i izvršava SQL iz `klik=` s parametrima `:id` i `:akcija` (`ukljuci` ili `iskljuci`); u primjeru to je novi redak u `naredbe` sa stanjem `cekanje`. Dok uređaj ne potvrdi, prekidač ima žuti obrub i piše „čeka". Dodatne postavke: `uloga=` (stupac uloge), `cekanje=` (stupac, 1 dok naredba nije potvrđena), `potvrdi=ne` (bez pitanja), `alarmi=` (stupac s brojem otvorenih alarma): kartica skupine s alarmom je crvena i u zaglavlju piše koliko ih je.
