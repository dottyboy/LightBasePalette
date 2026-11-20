# Plan: rječnik podataka koji upravlja formama, automatski unosi, okidači (2026-11-11)

Ideje posuđene iz Clariona (rječnik), FileMakera (auto-enter, script triggers) i Oracle Formsa (događaji, već u poglavlju 19).
Ovaj plan opisuje stavke 1, 2 i 3 iz razgovora. Procjene su radni dani; orijentir, ne obećanje.

## Što već imamo (provjereno u kodu)
- **Rječnik** `_sys_fields` (`TaFieldMeta`): tip, `Format`, `DefaultExpr`, `Decimals`, `Validation` + `ValidationMsg`, `Caption`,
  `Description`, `ColWidth`. Izvršitelj ih već koristi: provjera pri spremanju (`RuleFailed`), zadana vrijednost novog zapisa,
  format ćelije/polja, opis kao savjet kontroli. Tip `AutoNumber` zna za automatsko brojenje.
- **Događaji forme** (`FDef.GetEv`, `FireEvent`): `OnOpen`, `OnCurrent`, `BeforeUpdate` (može odbiti), `AfterUpdate`,
  `BeforeDelete` (može odbiti), `OnClose` (može odbiti).
- **Događaji kontrole:** `OnClick`, `OnChange`, `OnDblClick` (makro ili 4GL program).
- **Revizija** (`_sys_audit`, `ta_audit`): tko je što promijenio, već postoji.

## 1. Rječnik koji upravlja formama (4 dana) — **GOTOVO 2026-11-11, osim maske unosa i ikone u Inspektoru**

**Izvedeno:** `TaFieldMeta.Extra` (key=value: `required`, `readonly`, `align`, `variant`, `rowsource`, `lov`, `lovmap`, `class`), stupac `_sys_fields.extra` s migracijom (SQLite, PostgreSQL, MariaDB), dijalog svojstava polja ima nova polja, `ta_dict` (`ApplyDictionaryDefaults`: vlastito svojstvo > klasa svojstava > rječnik; `DictRequired`), `TaFormRunner` ih primjenjuje pri gradnji kontrola i blokira spremanje praznog obaveznog polja (poruka *"Naziv: obavezno polje"* kroz `Tr`). `ta_i18n` + `ta_i18n_hr`: engleski izvorni tekst, hrvatski prijevod uključiv postavkom (`SetUiLanguage`). Smoke `TestDictionary` 11 provjera. **Maska unosa gotova (isti dan, `ta_mask`).** **Oznaka "(rječnik)" u Inspektoru gotova:** kad kontrola sama nema vrijednost, a rječnik je daje (Variant, RowSource, Lov, LovMap, Mask, Align, PropertyClass, Locked), Inspektor je pokazuje s prefiksom `(rječnik)`; takav tekst se pri uređivanju ne upisuje (`DictValueFor`, `DictInheritedMarker`). Provjereno u dizajneru: polju s rječničkom maskom i poravnanjem oboje pokazuje prefiks. **Nije:** migracija postojećih hrvatskih tekstova na `Tr` (korak 0).
Cilj: jednom opišeš polje u rječniku, a svaka forma, mreža i izvješće ga prime bez ponavljanja.

| Korak | Posao | Prihvaćanje |
|---|---|---|
| 1.1 | Prošireni `TaFieldMeta`: `Required` (obavezno), `ReadOnly`, `Align`, `RowSource` (popis vrijednosti ili izvor kao u `TaSourceDef`), `Lov` + `LovMap`, `PropertyClass`, `Mask` (maska unosa, npr. OIB 11 znamenki, IBAN), `Variant` (npr. `switch` za Boolean). Novi stupci u `_sys_fields` s migracijom (`ALTER ... ADD` ako nedostaju). | stari rječnik se čita bez greške; smoke `TestDictMigrate` |
| 1.2 | Dijalog `ta_fielddlg` dobije nove kartice; `EditContext` ostaje isti. | polja se spremaju i vraćaju |
| 1.3 | **Nasljeđivanje:** kad se kontrola veže na polje, a sama nema vrijednost, `FamilyControlFor` ili `ApplyFamilyStyle` uzima iz rječnika: varijantu, popis, LOV, poravnanje, maska, obavezno (rub ili zvjezdica). **Vlastito uvijek nadjačava rječnik** (isto pravilo kao klase svojstava). | forma s kontrolom bez ijednog svojstva ponaša se kao rječnik opisuje; paritetni skup bez razlika |
| 1.4 | **Provjera obaveznosti** pri spremanju, uz postojeću `Validation`; poruka na hrvatskom po zadanome, vlastita iz `ValidationMsg`. | prazno obavezno polje blokira spremanje s porukom |
| 1.5 | Dizajner: "Dodaj sva polja" i čarobnjaci biraju varijantu iz rječnika (umjesto samo iz tipa). | novo polje daje gotovu kontrolu |

Rizik: **dvostruki izvor istine** (rječnik i svojstvo kontrole). Mjera: jasno pravilo prednosti, a Inspektor pokazuje
"naslijeđeno iz rječnika" sivo, kao kod klase svojstava.

## 2. Automatski unosi (3 dana, dijele rječnik) — **GOTOVO 2026-11-11, osim vrste `copy`**

**Izvedeno:** `ta_autoenter` (`TaAutoKind`: serial, created, modified, user, expr, const; ključevi u rječniku `autoenter`, `autoon`, `serial`, `serialyear`, `serialpp`, `serialnu`, `autoexpr`, `autoconst`). Predložak broja `{seq}`, `{seq:N}`, `{pp}`, `{nu}`, `{year}`, `{yy}`, `{mm}`; zadani `{seq}/{pp}/{nu}` (1/POSL1/2), numerički `{nu}{seq:6}` (8000001). Poslovni prostor, uređaj i vrsta slijeda (`SeqOnDevice`) dolaze iz fiskalnih postavki. Brojač u `_sys_serials`, relativni `UPDATE n = n + 1` u istoj transakciji kao spremanje: neuspjelo spremanje (npr. duplikat) vraća i brojač, slijed ostaje bez rupe. Nova forma pokazuje sljedeći broj (preview) ne mijenjajući brojač; polja `serial`, `created`, `modified` i `user` su zaključana. Korisnikova vlastita vrijednost ostaje (osim `always`). Dijalog polja ima Auto-enter. Smoke `TestAutoEnter` 14 provjera. **`copy` (isti dan):** `autoenter=copy`, `autocopy=<tablica.stupac>`, `autocopykey=<lokalno polje s ključem>`, `autocopysrckey` (zadano `id`). Rječnik izvodi pravilo `AutoFill` forme (`CopyRuleFor`): kad se promijeni polje s ključem, polje se puni iz povezane tablice; pri spremanju se prazno `copy` polje popunjava iz ključa (npr. ključ upisan skriptom). U dijalogu polja: `kupci.adresa < kupac_id`. Smoke 5 provjera. **Provjereno:** `modified` se osvježava i pri izmjeni (test), a `created` i `serial` ostaju. **Nije:** `copy` ne prati kasniju promjenu u izvornoj tablici (kopija je trenutna, kao FileMaker lookup).
Cilj: polje se samo popunjava pri stvaranju ili izmjeni zapisa.

| Vrsta (`AutoEnter`) | Kad | Primjer |
|---|---|---|
| `serial` s predloškom | novi zapis | broj računa `{GGGG}-{0000}` (godina, brojač po godini) |
| `created`, `modified` | novi zapis / svaka izmjena | datum i vrijeme |
| `user` | novi zapis / izmjena | prijavljeni korisnik (`_sys_users`) |
| `expr` | novi zapis (a opcionalno i izmjena) | bilo koji izraz, npr. `[kolicina] * [cijena]` ili `Nz(DMax(...),0)+1` (već imamo `DefaultExpr`) |
| `copy` (lookup) | novi zapis ili promjena izvornog polja | iz kupca u račun: adresa, OIB, uvjeti plaćanja |
| `const` | novi zapis | konstanta |

| Korak | Posao | Prihvaćanje |
|---|---|---|
| 2.1 | Stupci `auto_enter` i `auto_on` (`new`/`always`) u rječniku, parser predloška (`{GGGG}`, `{MM}`, `{0000}`, `{kupac}`). | jedinični test predloška |
| 2.2 | Brojač u tablici `_sys_serials` (ključ: tablica, polje, razdoblje), uvećanje u istoj transakciji kao spremanje zapisa. | dva zapisa u nizu daju uzastopne brojeve; poništeno spremanje ne troši broj |
| 2.3 | Izvršitelj: ispunjava prije `BeforeUpdate`, ne piše preko vrijednosti koju je korisnik ručno upisao (osim `always`). Polje je prikazano samo za čitanje. | smoke `TestAutoEnter` (svaka vrsta) |
| 2.4 | `AutoNumber` ostaje; `serial` je za oblikovane brojeve. | postojeći testovi prolaze |

Rizik: **brojač u višekorisničkom radu**. Mjera: uvećanje unutar iste transakcije (SQLite, PostgreSQL i MariaDB to znaju);
za mrežu bez transakcije koristiti `UPDATE ... SET n = n + 1` pa `SELECT`.

## 3. Okidači (3 dana, proširuje postojeće događaje) — **GOTOVO 2026-11-11**

**Izvedeno:** forma: `BeforeInsert` (može odbiti), `AfterInsert`, `AfterDelete`, `AfterQuery` (nakon `Requery`, pa i nakon upita po formi), `OnError` (skripta dobiva `eventMessage` i može ga promijeniti kroz `SetEventInfo`, ili `CancelEvent` ako je poruku sama prikazala). Kontrola (ključevi `onEnter`, `onExit`, `onValidate`, `onKey` u definiciji, u `PropMap`, Inspektoru i dizajneru): `OnEnter`; `OnExit` i `OnValidate` (`CancelEvent` zadržava fokus na kontroli; `OnValidate` se provjerava i pri spremanju: odbijena vrijednost blokira zapis); `OnKey` (`CancelEvent` guta tipku). PascalScript dobiva `EventInfo('eventControl'|'eventValue'|'eventKey'|'eventMessage')` i `SetEventInfo`. Smoke `TestTriggers` 12 provjera. **Hijerarhija okidača gotova (isti dan):** za `onEnter`, `onExit`, `onValidate` i `onKey` redoslijed je **kontrola > rječnik polja > zadani okidač forme** (`FieldOnEnter`, `FieldOnExit`, `FieldOnValidate`, `FieldOnKey` među događajima forme; `EffectiveEvent` u `ta_dict`); rječnik ih ima kao ključeve `onEnter`/`onExit`/`onValidate`/`onKey` u polju (dijalog polja: *Okidači polja* `onValidate=Proc;onExit=Proc`). Smoke 5 provjera. **Nije:** `OnEnter`/`OnExit` na kontrolama koje nisu `TWinControl`, primjer u kosturu *Unos i izmjena zapisa*.
Naslanja se na poglavlje 19.3 (već prihvaćeno), ali s nazivima poznatim iz FileMakera.

| Događaj | Razina | Može odbiti? | Stanje |
|---|---|---|---|
| `OnOpen`, `OnClose` | forma | `OnClose` da | **ima** |
| `OnCurrent` (= *OnRecordLoad*) | forma | ne | **ima** |
| `BeforeUpdate`, `AfterUpdate`, `BeforeDelete` | forma | prva i treća da | **ima** |
| `BeforeInsert`, `AfterInsert` | forma | `BeforeInsert` da | **novo** (sad se razlikuje samo Update) |
| `AfterDelete` | forma | ne | **novo** |
| `OnEnter`, `OnExit` | kontrola | `OnExit` da (zadrži fokus) | **novo** |
| `OnValidate` | kontrola | da | **novo** (uz rječničku `Validation`; kontrola je jača) |
| `OnKey` | kontrola, forma | da (guta tipku) | **novo** |
| `OnError` | forma | – | **novo**: tehničku grešku baze pretvara u poruku |
| `AfterQuery` | forma | ne | **novo**: nakon upita po formi/izvedbi |

| Korak | Posao | Prihvaćanje |
|---|---|---|
| 3.1 | `TaControlDef`: ključevi `onEnter`, `onExit`, `onValidate`, `onKey` (Extra), u `PropMap` i Inspektor (`DefGet/DefSet`, kategorija *Radnje*). | svojstva se vide i spremaju |
| 3.2 | Domaćini obitelji javljaju `OnEnter`/`OnExit` (iz unutarnje kontrole, preko `TaFamilyHost`); izvršitelj ih spaja. | smoke: fokus pokreće makro |
| 3.3 | `FireEvent` za nove događaje forme; `OnError` omota tekst greške baze. | smoke po događaju; `BeforeInsert` odbija zapis |
| 3.4 | Hijerarhija iz 19.3: događaj kontrole nadjačava rječnik, rječnik nadjačava formu (isti "vlastito pobjeđuje" princip). | test prednosti |
| 3.5 | Dokumentacija (`docs/PALETA.md` + priručnik) i primjer u kosturu *Unos i izmjena zapisa*. | primjer radi |

## Redoslijed i veza
1 → 2 → 3. Korak 1.1 je preduvjet za 2 (stupci), a 3 je nezavisan pa se može raditi paralelno ako treba. Ukupno oko **10 radnih dana**.
Svaki korak je sam korisna, ima smoke i paritetni test; ništa ne mijenja arhitekturu (oslanja se na `TaFieldMeta`,
`TaBindingEngine`, `FireEvent` i obitelji).

## 0. Prijevodi (korak 0) — **PRVI DIO GOTOV 2026-11-11 (gui/ i editors/)**
`ta_i18n` (hash tablica, `Tr`, `SetUiLanguage`), alat `tools/i18n` (scan, ručno prevedene tablice, apply). Prebačeno **1153 literala u 44 jedinice** (`gui/`, `editors/`) na `Tr('English')`; hrvatska tablica `ta_i18n_hr_ui` (873 para, generirana) + `ta_i18n_hr` (rucna), ukupno 887. Hrvatski ispis je identičan prijašnjem (smoke i paritet bez razlika); `SetUiLanguage('en')` daje engleski. **`core/` (isti dan):** 102 poruke u 16 jedinica (skripte, 4GL i makro naredbe, uvoz, katalog, pohrana datoteka, QBE, čarobnjaci, izraz greške) prebačene na `Tr`, tablica `ta_i18n_hr_core` (94 para); alat `tools/i18n/apply_core.py`. **Pregled engleskog prikaza (isti dan, `TYPHACCESS_LANG=en`):** aplikacija pokrenuta u Xvfb-u, prošli svi izbornici i dijalozi Nova tablica, Korisnici, Fiskalizacija, Vrste dokumenata. Nađeno i ispravljeno: 140 tekstova izvan pozvanih konteksta (`ta_i18n_hr_more`, uključuje filtre datoteka i gumbe), nazivi ugrađenih tema (`en` tablica), statusna traka, gumbi dizajna tablice, odrezani natpisi (širine gumba i skraćeni nazivi u fiskalnom dijalogu). `Tr` u `const` poljima nije moguć, pa ostaju hrvatski: `NavHints` (navigacija forme), `DockTitles`, `Caps` u dizajneru forme, popisi u `ta_companydlg` i `ta_taskdlg`; treba ih pretvoriti u funkcije. Jezik se bira varijablom `TYPHACCESS_LANG` (en, hr). **Drugi prolaz (dizajneri i čarobnjaci, isti dan):** konstantna polja ne treba pretvarati u funkcije: prikaz ide kroz `Tr(NAZIV[i])` uz tablicu `ta_i18n_en` (hrvatski ključ → engleski; `NavHints`, `DockTitles`, `Caps`, `Titles`, `LayoutOpNames`, `Cats`, `Presets`, imena tema), popisi opcija kroz `TrCsv` (odabir ostaje po indeksu), katalog funkcija u grafičaru izraza kroz `CatalogLine`. Ispravljeno: gumbi dizajnera, zaglavlja mreže tablice, popisi u čarobnjacima, dijalog alata za podatke, širine gumba. **Greška koju sam unio i popravio:** nova imena događaja forme bila su umetnuta usred `FormProps` pa su vrijednosti u Inspektoru forme bile pomaknute (BeforeInsert je pokazivao Resizable); sada su na kraju popisa. **Inspektor:** ključevi forme preimenovani u engleske identifikatore `Source`, `View`, `Title`, `Kind` (i u dizajneru izvješća); u hrvatskom prikazu Inspektor tako pokazuje isti engleski popis svojstava kao i za kontrole. **Treći prolaz (12 dijaloga):** postavke aplikacije, revizijski trag (zaglavlja mreže), planer zadataka, čarobnjak izbornika, tipke forme, uređivač 4GL blokova (gumbi), čarobnjak kostura (način), relacije, uvoz, izvoz, poslovni predlošci, podaci o tvrtki; ispravljeno što je nađeno. **Prijevod kataloga (isti dan):** prikaz kroz `Tr` uz tablicu `ta_i18n_en` (hrvatski izvor ostaje u datotekama, pa se katalog može i dalje uređivati): poslovni predlošci (9 naziva i opisa), paleta blokova `ta_fglpalette` (19 blokova, skupine, nazivi polja), paleta uređivača 4GL-a `ta_fglblocks` (30 stavki), kosturi `skeletons/*.4glt` (13 naziva, opisa, kategorija i 34 pitanja), katalog funkcija izraza (115 opisa), izbornici i dijalozi. **Četvrti prolaz (5 dijaloga):** dizajner izvješća (gumbi), dijalog pisma, uređivač modula, dizajner upita, stranica izvješća. **Ostalo hrvatsko u engleskom prikazu:** tijela blokova i primjeri koda (npr. `DISPLAY "Pozdrav"`, nazivi varijabli u predlošcima), sadržaj `ta_catalogdata`, priručnik (`ta_manualdata`), primjeri `ta_showcase*`, vrijednosti izbornika (npr. raspored zadatka `dnevno 02:00`), nazivi izvoznih formata, dugi pojašnjenski natpisi koji se odrežu u uskim dijalozima, pomoćni tekst dijaloga pisma i uređivača modula. **Nije:** imena i vrijednosti koji se zapisuju u bazu (nazivi izvješća, statusi, identifikatori) namjerno ostaju kakvi jesu; poruke u višeredovnim pozivima koje pretraga jednog retka ne vidi; generirani sadržaj (`ta_manualdata` 2600, `ta_catalogdata` 1200, `ta_showcase*` 400 redaka; prevode se u generatorima, ne kroz `Tr`), literali izvan pozvanih konteksta (`Items.Add` izbornici, konstante), dokumentacija (ostaje hrvatska).

## Odluke (2026-11-11)
1. **Jezik: sve na engleskom, hrvatski kao prijevod.** Identifikatori, ključevi u zapisu, nazivi događaja, svojstva i izvorni
   tekstovi sučelja su engleski. Hrvatski je **sloj prijevoda** koji se uključuje postavkom jezika (zadano `hr` za ovu
   aplikaciju) i može se isključiti. Početak: `ta_i18n` (`Tr('English text')` + tablica `hr`), nove poruke odmah engleski + prijevod.
   Postojeći hrvatski tekstovi (oko 4000 literala u 100 jedinica) prelaze postupno skriptom, vidi korak 0.
2. **Obavezno polje blokira spremanje** (poruka `Tr('Value is required')`).
3. **Broj računa (hrvatsko poslovanje):** zakon traži tri dijela: redni broj, oznaka poslovnog prostora, oznaka naplatnog uređaja,
   a slijed mora biti neprekinut (izvor: Zakon o fiskalizaciji u prometu gotovinom; točan oblik i razdvajanje određuje obveznik
   internim aktom, pa ga ne smijemo zaključati). Rješenje:
   - **Predložak** po polju s oznakama `{seq}`, `{seq:6}` (nadopuna nulama), `{pp}` (poslovni prostor), `{nu}` (naplatni uređaj), `{year}`,
     `{yy}`, `{mm}`. Zadani predložak za račun: `{seq}/{pp}/{nu}` (npr. `1/POSL1/2`); drugi gotov predložak je numerički
     `{nu}{seq:6}` (uređaj 8, redni broj 1 daje `8000001`) kao u tvom primjeru.
   - **Brojač** se ključa po (tablica, polje, `pp` ili `pp+nu` prema postojećoj postavci `SeqOnDevice` u `ta_fiscalcfg`, godina ako je
     uključeno "slijed po godini"). `pp` i `nu` uzima iz postojeće fiskalne postavke (`LoadFiscalConfig`), pa nema dvostrukog unosa.
   - Oba oblika se mogu pokazati u ispisu: formatirani broj računa i numerički serijski broj, jer se oba izvode iz iste dvije
     vrijednosti (brojač + uređaj).


## Posudba iz drugih programa: stanje (2026-11-11)
| Ideja | Izvor | Stanje |
|---|---|---|
| Rječnik koji upravlja formama | Clarion | **gotovo** (korak 1) |
| Automatski unosi (serijski broj računa, created/modified/user/expr/const/copy) | FileMaker | **gotovo** (korak 2) |
| Okidači i njihova hijerarhija | FileMaker, Oracle Forms | **gotovo** (korak 3) |
| Maska unosa | Clarion | **gotovo** |
| **Spremljena traženja** | FileMaker "saved finds" | **gotovo:** `savequery:Ime`, `loadquery:Ime`, `deletequery:Ime` (gumb ili makro), tablica `_sys_finds`, `ta_savedfinds` |
| Imenovani skupovi zapisa (unija, presjek) | 4D "sets" | nije: skup ključeva po imenu uz operacije; dijalog za spremljena traženja (popis, učitaj, obriši) |
| Točke umetanja u generirane forme | Clarion "embed points" | nije |
| Krajnji korisnik slaže izvješće | 4D Quick Report | nije |
