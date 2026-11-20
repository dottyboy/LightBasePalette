# TyphAccess: plan ručnog testiranja

Automatski testovi (`tests/smoke.pas`, ~1200 provjera) pokrivaju jezgru, izraze, izvješća, formu bez zaslona i dokumentaciju. **Ne pokrivaju:** izgled, povlačenje mišem,
tipkovnicu i fokus, dijaloge, stvarni ispis i PDF u pregledniku, dojam brzine. Ovaj plan pokriva upravo to. Redoslijed je po važnosti.

**Oznake:** `P1` mora raditi prije izdanja, `P2` važno, `P3` kozmetika. Uz svaki korak je očekivani rezultat; ako nije ispunjen, upiši u tablicu grešaka (kraj dokumenta).
Procjena: P1 oko 3 sata, P2 oko 4 sata, P3 oko 1 sat.

## 0. Priprema

| Korak | Kako |
|---|---|
| Izgradnja | `tools/build.sh`; mora proći bez grešaka |
| Pokretanje | `DBUS_SESSION_BUS_ADDRESS=disabled: bin/TyphAccess` (bez toga Qt uređivači ne primaju tipke) |
| Testne baze | prazna `test.db`; `--make-northwind`; po potrebi `tools/pg_test.sh start` (port 5433) i `tools/maria_test.sh start` (port 3307) |
| Sigurnost | testiraj na **kopijama** baza, nikad na pravim podacima |
| Okruženje | zabilježi zaslon (razlučivost, skaliranje), temu (`qt6ct` font), OS |

## 1. Dimni test (P1, 15 min): pokreće li se i radi li osnova

- [ ] Program se pokreće, glavni prozor se crta, izbornici: Baza, Tablica, Forma, Upit, Izvješće, Skripta, Aplikacija, Pomoć.
- [ ] *Baza → Nova…* izradi `test.db`; popisi Tablice/Forme/Upiti/Izvješća/Moduli/Makroi su prazni.
- [ ] *Tablica → Nova tablica…*, dvije tablice s različitim tipovima (tekst, cijeli broj, decimalni, datum, da/ne).
- [ ] Datasheet: upiši 5 redaka, spremi, zatvori i ponovo otvori program: podaci su tu.
- [ ] Zatvaranje prozora ne ostavlja zaostali proces (`pgrep TyphAccess`).

## 2. Tutorial s kraja na kraj (P1, 60 min)

Slijedi `docs/manual/01-tutorial.md` doslovno, kao novi korisnik. **Svaki korak koji nije jasan ili ne radi je greška dokumentacije ili programa.**

- [ ] 1 Nova baza · 2–3 Tablice · 4 Unos · 5 Forma iz čarobnjaka · 6 Upit · 7 Izvješće s grupama · 8 Makro · 9 Izbornik · 10 Korisnici i prava · 11 Gotova aplikacija · 12 Sigurnost · 13 Slike · 14 Server.
- [ ] Snimke zaslona u tutorialu odgovaraju onome što vidiš (naslovi dijaloga, nazivi gumba).
- [ ] Svi nazivi izbornika iz teksta postoje.

## 3. Baza i podaci

### 3.1 Baza (P1)
- [ ] *Otvori* preko dijaloga i preko argumenta naredbenog retka; datoteka koja nije SQLite daje razumljivu poruku, ne pad.
- [ ] *Nova: primjer Northwind* (i `--make-northwind`): forme, upiti, izvješća, izbornik rade.
- [ ] *Nova: iz kataloga*: izbor domene, tablice i veze se izrade; barem 3 domene (npr. računovodstvo, skladište, škola).
- [ ] *Sigurnosna kopija* → datoteka se može otvoriti kao baza. *Provjeri i sažmi* javlja veličinu prije i poslije.
- [ ] *Dokumentacija baze (HTML)* otvara se u pregledniku, sadrži sve tablice.
- [ ] *Relacije*: prikaz veza, dodavanje/brisanje veze, strani ključevi se poštuju pri unosu.

### 3.2 Tablice i svojstva polja (P1)
- [ ] Dodaj, preimenuj, obriši polje; brisanje polja traži potvrdu i javlja posljedice za forme/izvješća.
- [ ] *Svojstva polja*: tip, zadana vrijednost izrazom (`Today()`), provjera s porukom, obavezno, veza na drugu tablicu (combo), format, decimale.
- [ ] Tipovi: unos `1.234,56`, `31.12.2026`, negativni brojevi, vrlo dugi tekst, č ć š ž đ, emoji; sve se vraća neizmijenjeno.
- [ ] *Dopuni rječnik polja iz kataloga*: opisi se popune, postojeći se ne prepisuju bez pitanja.
- [ ] *Obriši tablicu* traži potvrdu; nakon brisanja forme koje je koriste pokazuju jasnu poruku.

### 3.3 Uvoz i izvoz (P1)
- [ ] CSV s `;` i hrvatskim brojevima (`1.234,56`) i datumima: stupci se prepoznaju kao Decimal/Date; pregled prije uvoza; uvoz u postojeću i novu tablicu.
- [ ] CSV s BOM-om, s navodnicima i novim redom u polju, s praznim redcima.
- [ ] Excel (.xlsx): više listova, datumi, formule (uvozi se vrijednost).
- [ ] Izvoz CSV (;), CSV (,), JSON, Excel: otvori u LibreOffice/Excelu; č ć š ž đ ispravni; brojevi i datumi ispravni.
- [ ] Spremljeni predložak uvoza (preset) vraća postavke.
- [ ] Uvoz od 50.000 redaka: traje razumno, ima traku napretka, može se prekinuti.

### 3.4 Pohrana datoteka (P2)
- [ ] Slika u polju (BLOB → veza): *Pohrana datoteka…* pretvara stare slike, u bazi ostaje samo veza.
- [ ] Zasebna mapa (`TYPHACCESS_FILES`), premještanje baze zajedno s mapom, slika se i dalje prikazuje.
- [ ] Čišćenje zaostalih datoteka premješta u `_neiskoristeno`, ništa ne briše.

### 3.5 Postgres i MariaDB (P2)
- [ ] *Spoji na poslužitelj*: pogrešna lozinka/port daje poruku, ne pad.
- [ ] Iste ključne radnje kao na SQLite-u: tablica, unos, forma, upit, izvješće, uvoz.
- [ ] *Kopiraj ovu bazu na poslužitelj*: tablice, podaci, forme, izvješća, korisnici stižu; broji se isto.
- [ ] Dva prozora na istoj bazi: izmjena u jednom vidi se nakon osvježavanja u drugom.

## 4. Forme

### 4.1 Čarobnjaci i dizajner (P1)
- [ ] *Čarobnjak forme* (jedna tablica) i *master–detail* (račun + stavke).
- [ ] Dizajner: dodaj svaku vrstu kontrole (TextBox, Label, ComboBox, CheckBox, gumb, podforma, slika, barkod/QR…), povuci, promijeni veličinu, poravnaj, kopiraj/zalijepi, poništi (Ctrl+Z), obriši.
- [ ] Svojstva kontrole: izvor, format, `VisibleIf`/`EnabledIf`, `RowSource`, `OnClick` (makro i izravna naredba); nevažeći izraz daje poruku, ne pad.
- [ ] Spremi, zatvori, ponovo otvori dizajn: ništa se ne gubi.

### 4.2 Rad u formi (P1)
- [ ] Navigacija (prvi/prethodni/sljedeći/zadnji), novi zapis, spremi, poništi, briši uz potvrdu, filter, traži.
- [ ] Tab-redoslijed, Enter, Esc; fokus na prvom polju pri novom zapisu.
- [ ] Provjera unosa s porukom (prazno obavezno polje, `[value] > 0`): spremanje se zaustavlja, fokus ide na polje.
- [ ] Izračunata kontrola (`=[kolicina] * [cijena]`) osvježava se pri tipkanju.
- [ ] Kaskadni popisi (grad ovisi o županiji); combo s ključem i prikazom.
- [ ] Forma u obliku mreže: sortiranje klikom na zaglavlje, uređivanje u ćeliji, novi redak na dnu.

### 4.3 Dokument sa stavkama (P1: nova pravila)
Poslovni predložak *Dokument sa stavkama* ili ručno: račun + podforma stavki.
- [ ] Odabir artikla puni opis i cijenu (`AutoFill`), i u mreži i u formi s jednim zapisom.
- [ ] Količina × cijena → iznos stavke (`CalcRules`); upis iznosa preračuna cijenu; nema beskonačne petlje ni treperenja.
- [ ] Zbroj stavki na glavnoj formi se osvježava pri svakoj izmjeni, dodavanju i brisanju stavke.
- [ ] PDV po stopama (`PdvPoStopama`): primjer 3 × 10,05 uz 10 % daje PDV 3,02 i ukupno 33,17; ukupno na ekranu = ispis.
- [ ] Pomoćnici u dizajneru: *Automatsko popunjavanje…* i *Pravila izračuna…* otvaraju se, popunjavaju i vraćaju točan tekst pravila; Otkaži ne mijenja ništa.
- [ ] Zaključavanje knjiženog dokumenta (`AllowEdits`), broj računa po godini bez rupa i duplikata pri dva istodobna unosa.

### 4.4 Događaji i makroi u formi (P2)
- [ ] `OnOpen`, `OnClose`, `BeforeUpdate`, `AfterUpdate`: izvršavaju se kad treba; greška u makrou daje poruku s retkom.
- [ ] Gumbi: `openform`, `openreport` s `@uvjet` i `#poredak=`, `filter`, `requery`, `duplicate`, `export`.

### 4.5 Dizajn: veličina i položaj kontrola (P1)
- [ ] Odaberi kontrolu: oko nje se vidi osam hvatišta (uglovi, sredine stranica).
- [ ] Povuci svako od osam hvatišta (i **izvan** kontrole, daleko od nje): mijenjaju se samo odgovarajući rubovi, suprotni ostaje; pokazivač je odgovarajuća strelica.
- [ ] Povuci sam rub kontrole (lijevi, desni, gornji, donji, uglovi) — isto ponašanje; sredina kontrole je i dalje pomicanje.
- [ ] Vrlo mala kontrola (npr. crta): da li se još može pomicati i povećati?
- [ ] U desnom popisu upiši `Left`, `Top`, `Width`, `Height` i pritisni **Enter**; promjena vrijedi odmah, i kad se vrijednost vrati na staru (npr. nakon neuspjelog povlačenja).
- [ ] Isto za **izvješće** (hvatišta su uz rub unutar kontrole); **Shift+strelice** mijenjaju veličinu, **Ctrl+strelice** pomiču za jednu točku; **Ctrl+Z** poništava jedan potez.

### 4.6 Označavanje skupine, veličina forme, stranica i naljepnice (P1: nova značajka)
- [ ] Forma: povuci okvir po praznoj površini: označe se sve kontrole koje okvir dotakne; **Ctrl+okvir** dodaje; klik u prazno poništava.
- [ ] Povuci jednu od označenih kontrola: cijela skupina ide zajedno, neoznačene ostaju; **Ctrl+Z** vraća jednim korakom.
- [ ] Forma: polja **Veličina forme (px)** u drugoj traci mijenjaju površinu; vrijedi i nakon Spremi i ponovnog otvaranja; Poništi vraća staru veličinu.
- [ ] Izvješće: isto označavanje okvirom (i preko više odjeljaka) i pomicanje skupine.
- [ ] Izvješće → **Stranica i naljepnice…**: A4 položeno, A5, vlastita veličina; margine; pregled i PDF imaju istu veličinu stranice kao dizajn (otvori PDF i izmjeri).
- [ ] Naljepnice: odaberi arak (npr. 63,5 × 38,1, 3 × 7), stavi polje u `Detail`, pregledaj: 21 naljepnica po stranici, razmaci i margine odgovaraju ruci izmjerenoj na ispisu na pravi arak (**provjeri s pravim papirom**).
- [ ] Prevelike mjere (naljepnice šire od lista) odbijene porukom, definicija ostaje netaknuta.
- [ ] Staro izvješće (spremljeno prije ove promjene) otvara se kao A4 s istim marginama kao prije.

### 4.7 Veliki primjer Trgovina Jadran (P1: nova značajka)
- [ ] *Baza → Nova: veliki primjer Trgovina Jadran…*: izradi se u par sekundi; otvori se Izbornik (četiri stupca gumba sa skupinama).
- [ ] Računi: forma s prodavačem, načinom plaćanja i dostavom; stavke; osnovica, PDV, ukupno; *Ispis*; *Pregled po razdoblju*.
- [ ] Artikli: *Marža %* i *S PDV-om* na formi; kategorije i dobavljač su padajući popisi.
- [ ] *Pregled prodaje (grafikoni)*: tri grafikona; *Top kupci*: stupac Razred (Zlatni/Srebrni/Brončani/Redovni); *Naljepnice partnera*: 21 po listu (isprobaj i ispis na pravom arku).
- [ ] *Funkcije: živi primjeri* (forma i izvješće): nigdje #Err.
- [ ] Kartica **4GL**: dvoklik pokreće program; *Uredi* otvara blokove; *U bazu…* sprema izmjenu; izbornik *Skripta* ima iste radnje.
- [ ] Makroi s izbornika: *Povećaj cijene* (neispravan pa ispravan unos, potvrda), *Narudžbenica po minimumima*, *Provjera prekoračenja ugovora* (javlja jedan ugovor), *Zaključak mjeseca*.
- [ ] Planer: četiri zadatka postoje, isključeni su; uključi *Mjesečni izvještaj o prodaji* i pokreni ga odmah.

### 4.8 Formatirani tekst RichText (P1: nova značajka)
- [ ] Forma s kontrolom `RichText` (dizajner: paleta, polje `ControlSource`): traka s B, I, U, A (boja), veličina, poravnanje, natuknica, očisti.
- [ ] Označi dio teksta i podebljaj/kurziv/podcrtaj; ponovni klik skida; promijeni boju i veličinu; poravnaj odlomak; natuknica; **hrvatska slova** (č, ć, š, ž, đ).
- [ ] Spremi zapis, prijeđi na drugi zapis i vrati se: oblikovanje je zadržano; u datasheetu/tablici u polju je HTML, a `PlainText([polje])` daje običan tekst.
- [ ] Stari običan tekst iz istog polja otvara se kao tekst i postaje formatiran nakon spremanja.
- [ ] Izvješće s `RichText` (dizajner izvješća: stavka u Detail): pregled, PDF, HTML i ispis imaju iste boje, podebljano, poravnanje i natuknice; **dugi tekst produlji redak** i ne preklapa sljedeći; lom stranice usred dugog teksta.
- [ ] Zalijepi tekst iz drugog programa: ne smije srušiti formu (izvorno oblikovanje se ne prenosi).
- [ ] Veliki primjer *Trgovina Jadran*: forma i ispis *Obavijesti*.

### 4.9 Ikone, sidrenje, prozor forme i izgled (P1: nova značajka)
- [ ] Glavni prozor: traka s ikonama lijevo prebacuje popise (tablice, forme, upiti, izvješća, dopisi, moduli, makroi, 4GL); naslov iznad popisa odgovara; savjet s nazivom pri prelasku mišem.
- [ ] Izbornici imaju ikone uz Novi / Otvori / Dizajn / Pregled / Obriši / Pokreni; nazivi izbornika u traci su tekst bez ikona.
- [ ] Dizajner forme i izvješća: ikone na gumbima i u paleti (svaka vrsta kontrole ima svoju); nema odrezanih natpisa.
- [ ] Forma: povuci hvatišta uz desni rub, donji rub i kut; veličina u poljima iznad se prati; Poništi vraća prije povlačenja.
- [ ] `Anchors` (gumb …): *Rasteži vodoravno* na tekstualnom polju i *Dolje desno* na gumbu; pokreni formu i povuci rub prozora: polje se rasteže, gumb prati kut.
- [ ] Forma s `Resizable=False`: prozor je fiksan, bez gumba za povećanje. `CanMinimize=False`, `CanMaximize=False`, `StartMaximized=True`: ponaša se kako piše.
- [ ] Aplikacija → Izgled: moderno svijetlo / sustavni; izbor ostaje nakon ponovnog pokretanja; provjeri čitljivost u mrežama, formama, dizajnerima i dijalozima (javi dijelove koji ne izgledaju dobro). Tamne teme još nema u izborniku.
- [ ] Gumbi *…* uz datume i mali gumbi (Novi red, Briši red) ne režu natpis.

## 5. Upiti

- [ ] *Dizajner upita*: dvije tablice, spoj INNER/LEFT, polja dvoklikom, izračunato polje, zbirni upit (Group/Sum/Avg/Count), poredak, kriteriji (`Like "A*"`, `Between`, `In`, `Null`), *Bez duplikata*, *Prvih n*; prikazani SQL je točan; **Pokreni** daje očekivane retke (P1).
- [ ] *Čarobnjak upita* (četiri koraka), *otvori u dizajneru* (P1).
- [ ] Parametri `[?Od]`/`[?Do]`: dijalog pita, datum u oba oblika, prazno = NULL, Otkaži prekida bez greške; isti parametri pri otvaranju izvješća (P1).
- [ ] *Unakrsni upit* i *Unija*; *Prikaži SQL*, *Spremi upit* (P2).
- [ ] *Alati za podatke*: traži/zamijeni s probnim prolazom (broji, ne mijenja), duplikati po OIB-u (P2).
- [ ] Akcijski upit (`UPDATE`/`DELETE`) javlja broj zahvaćenih redaka i traži potvrdu (P1).
- [ ] Spremljeni upit kao izvor forme i izvješća; promjena upita ne ruši ovisne objekte bez poruke (P2).
- [ ] Isti upit na SQLite-u, Postgresu i MariaDB-u daje iste redke (P2).

## 6. Izvješća

### 6.1 Dizajner i pregled (P1)
- [ ] *Čarobnjak izvješća*, *Novo izvješće*: odjeljci (zaglavlje izvješća/stranice/grupe, detalj, podnožja), dodavanje kontrola, povlačenje, svojstva.
- [ ] Grupiranje s zbrojem grupe i ukupnim zbrojem; udio grupe (`Percent`); tekući saldo (`RunSum`); redni broj (`RunCount`, `RunGCount`); uvjetni zbroj `Sum(Iif(...))`.
- [ ] Pregled: zumiranje, listanje stranica, dugo izvješće (>5 stranica); traka s *PDF*, *HTML*, *Ispis*.
- [ ] Brojevi stranica: `Stranica N / M`, po grupi (`GroupPage`/`GroupPages`) restartaju se kod nove grupe.
- [ ] Prijelom stranice: nova stranica po grupi bez prazne prve stranice; izvješće šire od stranice nema prazne stranice.
- [ ] Stupci (`Columns`) za naljepnice; filter (ispis jednog dokumenta); prazno izvješće (0 redaka) ne ruši.

### 6.2 Poredci (P1: nova značajka)
- [ ] Svojstvo *SortOptions…* otvara dijalog (do 6 redaka); spremanje i ponovno otvaranje čuva unos.
- [ ] Pregled: popis **Poredak** mijenja redoslijed i ponovo slaže stranice; PDF i ispis slijede odabrani poredak.
- [ ] `openreport:Naziv#poredak=Po marži` otvara izravno u tom poretku; kombinacija s `@uvjet`.
- [ ] Poredak po izračunatom polju upita (marža); grupa ostaje prva, poredak ide unutar grupe.
- [ ] *Poredak…* (SortBy) dijalog: do 4 polja, uzlazno/silazno.

### 6.3 Izlaz (P1)
- [ ] **Stvarni ispis** na pisač/PDF-pisač: margine, A4, čitljiv font, č ć š ž đ, brojevi poravnati, razmaci.
- [ ] PDF u pregledniku: sadržaj isti kao pregled, font ugrađen, tablice ne pucaju preko stranica.
- [ ] HTML izvoz otvara se u pregledniku.
- [ ] Barkod/QR na izvješću skenira se mobitelom; HUB-3 uplatnica (P2).

### 6.4 Dopisi (P1: nova značajka)
- [ ] Kartica **Dopisi** i izbornik **Dopis** postoje; *Novi dopis…* otvara uređivač s predloškom teksta.
- [ ] Primjer *mali obrt*: dopis **Opomena** → *Pregled*: dvije firme, svaka na svojoj stranici; tablica sa zaglavljem, zbrojem; hrvatski zarez i datumi `dd.mm.gggg`.
- [ ] Uređivač: promijeni tekst/stupce/filter, **Pregled** prikazuje izmjene; **Spremi** čuva; umetanje polja iz padajućeg popisa ubacuje `[polje]` na mjesto kursora.
- [ ] **Word…**: otvori `.docx` u Wordu i LibreOfficeu: tekst, poravnanje, podebljano, tablica, ukupno, nova stranica po primatelju; uredi u Wordu.
- [ ] **PDF…** i HTML izgledaju kao pregled; dug dopis (puno stavki) prelazi na iduću stranicu s ponovljenim zaglavljem tablice.
- [ ] Filter koji ne vraća nikoga: poruka „Nema dopisa za ispis”; pogrešan SQL stavki: razumljiva poruka, ne pad.
- [ ] Makro `exportletter: Opomena > /putanja/opomene.docx` i gumb *Opomene u Word*; `openletter: Opomena@2` pokazuje samo firmu s ključem 2.
- [ ] Brisanje dopisa traži potvrdu; dopis ostaje nakon *Baza → Sigurnosna kopija*.

### 6.5 Ponude i ugovori (P1: nova značajka)
- [ ] Blok **copyrows** (Baza): složi makro koji iz jedne tablice kopira retke u drugu s izračunatim poljima; nakon njega `[novi]` i `[kopirano]` u poruci. *Napravi dodatnu ponudu* sada radi preko njega.
- [ ] Ugovori: upiši stvarne troškove u podformu; **Provjeri prekoračenje**: ispod cijene = poruka da je unutar cijene; iznad cijene a unutar dopuštenog % = bez upozorenja; iznad granice = UPOZORENJE s iznosima. Obje podforme imaju naslove.
- [ ] *Aplikacija → Poslovni predlošci → Ponude i ugovori* (s primjerom) izrađuje tablice, forme *Ponude poslova* i *Ugovori*, makroe, dopise *Ugovor* i *Aneks ugovora*.
- [ ] *Ponude poslova*: nova ponuda s dvije faze, uslugama i materijalom: iznos stavke se računa iz količine i cijene (i obrnuto); ispod su točni zbrojevi usluga, materijala, ukupno i avans.
- [ ] **Napravi ugovor** na prihvaćenoj ponudi: nastaje ugovor s cijenom, avansom, rokovima; faze se zbrajaju u cijenu; drugi pokušaj javlja da ugovor već postoji.
- [ ] **Napravi dodatnu ponudu** pa upiši stavke i **Napravi aneks** (na dodatnoj ponudi); aneks se vidi na formi *Ugovori* s vezom na ugovor.
- [ ] *Ugovori* → **Pregled ugovora / aneksa**: članci, razdioba usluge/materijal, avans, tablica faza, rokovi, prekoračenje (postotak, iznos, najviše), dodatni troškovi; aneks s ukupnom cijenom s aneksima.
- [ ] **U Word…**: `.docx` otvori u Wordu: tekst i tablica uredljivi, potpisna crta na kraju.
- [ ] Promijeni postotak prekoračenja i avans na ponudi, napravi novi ugovor: brojevi u ugovoru se mijenjaju.
- [ ] *Ugovori* → **Napravi račun za sljedeću fazu** više puta: prvo avans (924), pa faze; računi se pojavljuju na formi *Računi* za pravog naručitelja; faza dobiva račun; nakon zadnje faze poruka da su sve naplaćene; zbroj osnovica = cijena ugovora.

## 7. Skripte

- [ ] **Makro** (P1): uređivač s označavanjem greške, `if … then`, `stop`, `macro:` ugniježđeno, `sql:`, `msg:`; *Pokreni makro* iz izbornika i s gumba.
- [ ] **PascalScript modul** (P1): uređivač, kompilacija s porukom greške i retkom, *Pokreni proceduru…*, poziv funkcije iz izraza i iz 4GL (`pas.Naziv`).
- [ ] **4GL** (P2): `--run`, `--check`, `--console` iz terminala; program iz izbornika s `MENU`/`PROMPT`; pogreška baze ne ruši (`WHENEVER ERROR CONTINUE`).
- [ ] Recepti iz priručnika (`10-kako-da`, `11-4gl-recepti`) kopirani izravno iz Pomoći rade bez izmjena (P2).

### 7a. Makro blokovima (P1: nova značajka)
- [ ] Uređivač makroa: gumb **Blokovi** prikazuje redove, **Tekst** vraća isti makro; neizmijenjeni redci ostaju znak po znak isti.
- [ ] Dvoklik na naredbu u popisu dodaje blok iza označenog; **Dodaj uvjet / komentar / stop** rade.
- [ ] ↑ ↓ ✕ rade; **povlačenje ručke ☰** na drugi blok premješta ga (provjeri i na kraju popisa).
- [ ] Polje argumenta za `openform`/`openreport`/`macro` nudi postojeće objekte; **ƒx** otvara graditelj izraza i vraća izraz.
- [ ] Redovi se ne preklapaju pri 20+ blokova; pomicanje kotačićem; promjena veličine prozora.
- [ ] **Provjeri** u prikazu blokova javlja istu grešku kao u tekstu; **Spremi** sprema makro koji se izvodi jednako.

### 7b. Makro jezik i primjer s blokovima (P1)
- [ ] Novi blokovi: **importtable** (CSV u postojeću tablicu), **copyfile**, **mailto** (otvara program za e-poštu s predmetom i tekstom; provjeri s dijakriticima), **copyrows**.
- [ ] Nove funkcije izraza (priručnik, Referenca): Between, InList, Mod, Power, Pi, Pmt, RadniDani, Praznik, Uskrs, IsWeekend, AddWorkDays, BOYear, EOYear, DayOfYear, DaysInMonth, MonthsBetween: pokušaj ih u uređivaču izraza (dvoklik umeće primjer).
- [ ] *Račun → Pregled po razdoblju*: upiši Od i Do; prazno = bez ograničenja; ukupni zbrojevi u podnožju; isti gumb postoji na svim vrstama dokumenata (ponude, narudžbenice…).
- [ ] Dizajner forme → događaj (npr. `OnOpen`) → **<novi makro blokovima…>**: otvara se uređivač blokova s makrom `Forma_OnOpen`; nakon Spremi vrijednost događaja je `macro:Forma_OnOpen`; događaj radi pri otvaranju forme.
- [ ] Gumb → `OnClick` **…** → *Da*: novi makro u blokovima; ponovni **…** otvara isti makro; *Ne*: stari graditelj akcija; *Cancel*: ništa.
- [ ] Prazna polja u blokovima su prazna (ne pokazuju nazive tipa `arg1`); redovi se ne preklapaju; uređivač pokazuje blokove preko cijele širine.
- [ ] *Baza → Nova: primjer s blokovima (mali obrt)…* izrađuje bazu; kartica Makroi ima 5 makroa; početna forma je *Izbornik*.
- [ ] Svaki gumb izbornika radi: forme se otvaraju; *Sažetak neplaćenih* javlja broj i iznos; *Povećaj cijene* pita postotak (probaj 10, 0, "abc", prazno); *Cjenik u PDF* i *Kopija baze* pišu datoteku.
- [ ] Na formi *Računi* gumb **Označi plaćenim** pita Da/Ne i pri *Da* označi kvačicu i spremi; pri *Ne* ništa ne mijenja.
- [ ] Otvori svaki makro u prikazu *Blokovi*: struktura se vidi (uvlačenje unutar uvjeta); promijeni argument, vrati na *Tekst* i izvedi makro.
- [ ] Palete: kategorije *Tijek i poruke*, *Baza*, *Forma*, *Izvješće*, *Ostalo*; naslov kategorije ne dodaje ništa.
- [ ] Novi makro samo blokovima: varijabla, petlja `ponovi`, uvjet `ako … inače`; **Provjeri** hvata neuparen blok i loš izraz.
- [ ] Petlja bez izlaza (`dok vrijedi 1 = 1`) prekida se porukom, program se ne zamrzne.

### 7c. 4GL blokovi (P1: nova značajka)
- [ ] *Skripta → 4GL program (blokovi)…* otvara uređivač s programom `MAIN … END MAIN`; paleta po namjeni; strukture uvučene.
- [ ] Označi redak i dvoklik na predložak (IF s ELSE, petlja, kursor s FOREACH, MENU): umeće se iza retka u pravoj razini; označen početak bloka umeće unutra.
- [ ] Uredi tekst retka, ↑ ↓ ✕; brisanje IF-a briše i END IF; **Tekst** i natrag daje isti program.
- [ ] **Provjeri** na ispravnom programu: „Program je ispravan”; na krivom (npr. IF izvan MAIN): poruka parsera s retkom; **Pokreni**: izlaz DISPLAY-a, upiti nad otvorenom bazom.
- [ ] **Otvori…** učitaj `examples/4gl/*.4gl` i priloženi primjer iz priručnika: vide se strukture (izvješće, izbornik, kursor), **Spremi** ne mijenja retke koje nisi dirao.

## 8. Aplikacija

- [ ] **Poslovni predlošci** (P1): Dokument sa stavkama, skladište, blagajna; izrade se tablice/forme/izvješća; ponovno pokretanje ne briše postojeće.
- [ ] **Čarobnjak izbornika** i *Pokreni početnu formu*; *Runtime / dizajn (Ctrl+Shift+D)* skriva dizajnerske izbornike (P1).
- [ ] **Korisnici** (P1): prvi korisnik uključuje prijavu; krivi unos lozinke; uloge viewer/user/admin; zadnjeg admina ne možeš obrisati ni sniziti.
- [ ] **Prava objekata** (P1): viewer ne otvara objekt koji traži `user`/`admin`; poruka je razumljiva; admin sve.
- [ ] **Revizijski trag** (P2): uključi na tablici, promijeni polje, pregled pokazuje korisnika, staro i novo; filter po tablici/korisniku.
- [ ] **Planer zadataka** (P2): zadatak sigurnosne kopije i izvoza; `--run-tasks` iz terminala/`cron` izvrši samo zadatke na redu.
- [ ] **Postavke i izvoz aplikacije** (P2): paket (baza + program + skripta za pokretanje) radi na drugom računalu bez razvojnih alata.
- [ ] **Podaci o tvrtki** (P2).

## 9. Katalog (P3)
- [ ] Svih 42 domene izrade bazu bez greške; veze i opisi polja prisutni.
- [ ] *Snimka ove baze u domenu* → JSON u `catalog/`; nakon ponovnog pokretanja domena je na popisu.
- [ ] *Dokumentacija kataloga (HTML)*.

## 10. Priručnik i pomoć (P1)
- [ ] F1 otvara priručnik u pregledniku; *Kako da…*, *4GL recepti* i *Poruke i pogreške* otvaraju točno poglavlje (**sidro `#…` u adresi** može ne raditi: provjeri u svom pregledniku).
- [ ] **Pretraga** (gore desno, `/`): „zatezne kamate”, „poredak izvješća”, „PDV”, riječ s č/ć/š/ž/đ bez dijakritika; strelice, Enter, Esc.
- [ ] Svaka snimka zaslona vidi se; tablice se ne prelijevaju na uskom prozoru; ispis priručnika bez okvira pretrage.
- [ ] Kopiranje koda iz recepta u program: radi bez ručnih ispravaka.
- [ ] FAQ: izazovi 5 poruka o greškama iz programa; svaka ima opis uzroka i rješenja.

## 11. Robusnost i sigurnost podataka (P1)
- [ ] **Prekid usred rada**: ubij proces (`kill -9`) tijekom unosa/uvoza; baza se otvara, nema oštećenja (SQLite WAL).
- [ ] Dva programa na istoj SQLite datoteci: zaključavanje daje poruku, ne gubi podatke.
- [ ] Diskovi: puna particija, baza samo za čitanje, datoteka bez ovlasti: poruka, ne pad.
- [ ] Poništavanje (Ctrl+Z) u dizajnerima do prvog koraka; zatvaranje s nespremljenim promjenama pita.
- [ ] Veliki podaci: tablica sa 200.000 redaka u datasheetu (pomicanje, sortiranje, filter), upit i izvješće nad njima.
- [ ] Posebni znakovi u nazivima: razmak, č, `'`, `"` u nazivu tablice/polja/forme.
- [ ] Hrvatski jezik: decimalni zarez, tisućice s točkom, datum `dd.mm.yyyy`, sortiranje č/ć/š/ž/đ (collation).
- [ ] Zaslon: skaliranje 125 % / 150 %, mali prozor 1024×600, više monitora; dijalozi se ne režu.
- [ ] Tamna tema/svjetla tema, veliki font; tekst ostaje čitljiv.

## 12. Performanse (P3)
- [ ] Pokretanje programa < 3 s; otvaranje velike forme < 1 s; izvješće s 10.000 redaka < 5 s; uvoz 50.000 redaka < 30 s.
- [ ] Nema rasta memorije pri 50 puta otvori/zatvori forme (promatraj `top`).

## 13. Regresija poznatih zamki (P2)
- [ ] `Round` je bankarski, `Zaokruzi` je poslovni (1,005 → 1,01): provjeri u formi i izvješću.
- [ ] Kalkulacija: cijena ⇄ iznos ne zapetlja se; izmjena rabata preračunava.
- [ ] Izvješće s grupom: broj stranica „1/1” na zadnjoj stranici druge grupe.
- [ ] Spremljeni upit s izračunatim poljem može se koristiti kao izvor izvješća i sortirati po tom polju.
- [ ] Offscreen vs stvarni font: nijedan tekst ne probija okvir kontrole u izvješću s JetBrains Mono.

## Zapisnik grešaka

| # | Područje | Korak | Očekivano | Dobiveno | Težina (blokira / smeta / kozmetika) | Snimka / baza |
|---|---|---|---|---|---|---|
| 1 | | | | | | |

**Prijava:** za svaku grešku sačuvaj bazu (kopiju), korake i snimku zaslona; greške iz sučelja postaju nove provjere u `tests/smoke.pas`.

## Redoslijed izvođenja
1. Dim (1) → tutorial (2): ako padne ovdje, ostalo nema smisla.
2. P1 točke iz 3–8 po izborniku.
3. 10 (priručnik) i 11 (robusnost).
4. P2, zatim P3.
5. Nakon svake serije ispravaka: `tools/smoke.sh` (puni test) i ponovi samo zahvaćene točke.
