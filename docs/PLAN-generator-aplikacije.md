# Plan: generator aplikacije iz čiste baze (2026-11-11)

**Cilj (odluka korisnika):** iz čiste baze, uz nekoliko klikova i odabira iz padajućih popisa, složiti oko **90 % aplikacije**
(forme, popise, izvješća, izbornik, rječnik podataka), bez pisanja; ostaje ručno doraditi forme i izvješća. **Fiskalizacija je zadnja** i
ulazi kao nova kontrola u paleti.

## Što već imamo (gradivni blokovi)
| Dio | Gdje |
|---|---|
| Forma nad tablicom (jedan/dva stupca, mreža, forma + tablica), filteri, FK padajući popisi | `ta_wizardgen`: `BuildFormEx`, `LookupQuerySql`, `DisplayColumn` |
| Master-detail s više detalja, kartice ili ispod, zbrojevi | `BuildMasterDetailMulti`, `ChildRelations` |
| Izvješća: tablični, stupčasti, naljepnice, sažetak, master-detail | `BuildReportEx`, `BuildMasterDetailReport(Multi)` |
| Glavni izbornik iz svih formi i izvješća | `ta_bizgen.BuildAppSwitchboard`, `ta_switchgen` |
| Rječnik podataka: obavezno, format, maska, popis, okidači, auto-unos, serijski broj | `_sys_fields`, `ta_dict`, `ta_autoenter`, `ta_mask` |
| Pametni prijedlozi rješenja po pouzdanosti | `SuggestSolutions` (`ta_wizardframework`) |
| Veze (FK), ključevi, tipovi | `GetFks`, `AllRelations`, `PrimaryKeyOf`, `SourceFieldList` |
Nedostaje **orkestrator**: nešto što cijelu bazu pročita, predloži uloge tablica i sve generira u jednom prolazu.

## Etape
| Etapa | Posao | Rezultat |
|---|---|---|
| **1. Analiza sheme i rječnik** (GOTOVO 2026-11-11) | `ta_schemaplan`: uloge tablica (glavna, stavke, šifrarnik, veza, preskoči), stupci s FK-om i prikaznim stupcem; `ApplyDictionaryFromSchema` popunjava `_sys_fields` samo ondje gdje nema (oznake, formati, obavezno iz NOT NULL, poravnanje, prekidač za logičke, padajući popis za FK, maske po imenu OIB/IBAN/PBR, `created`/`modified`, neobavezno serijski broj) | rječnik iz prazne baze jednim pozivom |
| **2. Generator** (GOTOVO 2026-11-11: `ta_appgen`, `GenerateApplication`; smoke 11 provjera) | `ta_appgen`: za svaku glavnu tablicu forma (unos), popis (mreža s filterima), izvješće; stavke ugrađene kao podforma u glavnu; šifrarnici kao jednostavne forme; izbornik s grupama; opcije iz padajućih popisa | cijela aplikacija u jednom prolazu, ponovljiva (ne prepisuje ručno doređeno) |
| **3. Čarobnjak** (GOTOVO 2026-11-16: `ta_gendlg`, `PreviewApplication`, `SetTableRole`; smoke 7 provjera; pregledan u Xvfb-u) | jedan dijalog: 1. odaberi tablice i ulogu (padajući popis po tablici), 2. opcije (raspored forme, stavke ispod/kartice, izvješća da/ne, izbornik, numeriranje), 3. pregled što će nastati, 4. izradi + zapisnik | `Aplikacija > Izradi aplikaciju iz baze…` |
| **4. Ponovno generiranje** (GOTOVO 2026-11-16: umjesto `generated=1` otisak sadržaja u postavkama `gen:vrsta:naziv`; neizmijenjeno se obnavlja, ručno izmijenjeno ili tuđe ostaje, Overwrite prepisuje sve; pregled to označava) | oznaka `generated=1` na generiranim objektima; ponovno generiranje obnavlja samo neizmijenjene, ostalo pita | sigurna iteracija: promijeni shemu, generiraj opet |
| **5. Fiskalizacija (zadnje)** | kontrola u paleti (slanje na CIS, JIR/ZKI na računu) | kad sve gore radi |

## Heuristike uloga (etapa 1)
- **Veza (junction):** dva ili više stranih ključeva i najviše jedan drugi stupac (osim ključa).
- **Šifrarnik:** na njega pokazuje barem jedan strani ključ, ima najviše tri stupca izvan ključa i nema vlastitih stranih ključeva.
- **Stavke (detail):** ima strani ključ prema glavnoj tablici i naziv sadrži `detail`, `stavk`, `item`, `line`, `row` (npr. `OrderDetails`, `stavke_racuna`); nadređena je ona čiji je naziv sadržan u nazivu stavki.
- **Glavna:** sve ostalo.
Uloga se uvijek može promijeniti u čarobnjaku (etapa 3).

## Vizualna provjera generiranog (2026-11-16, Jadran)
Slike svih formi (offscreen) i PDF svih izvješća: `TA_SHOTS=/tmp/mapa tests/smoke` (TestGenShots u smoke.pas). Pronađeno i popravljeno:
- natpisi bez dijakritika (Racuni, Nacin placanja) → mala tablica hrvatskih riječi u `PrettyName` (računi, način plaćanja, poštanski, OIB…);
- forme sa stavkama preuske (stupci stavki odrezani) → najmanje 820 px; popisi (datasheet) široki prema broju stupaca;
- izvješća pokazivala šifru stranog ključa (Partner 26) → spremljeni upit "<naziv> podaci" s nazivom iz povezane tablice, logički stupci kao Da/Ne;
- izvješća s mnogo stupaca preplavljena → najviše 8 stupaca (opisni otpadaju prvi) i položena stranica kad ih je više od 6; PDF izvoz vlastite veličine papira bio u krivim jedinicama (297 x 210 pt) → ispravljeno.
Riješeno kasnije istog dana: širine stupaca u popisima (rječnik `colwidth` iz vrste, zaglavlja i uzorka; strani ključ prema nazivima), datumi i iznosi u mreži s formatom iz rječnika (mreža je za SQLite TEXT/memo prikazivala sirovi tekst, sad se iscrtava preko), FK stupci lijevo poravnati; u izvješću tekstno polje raste na više redaka: svojstvo **GrowLines** (najveći broj redaka, od 2; u inspektoru izvješća za TextBox), redak se produlji za najviše prošireno polje, generator ga postavlja na 3 za tekstne stupce.
