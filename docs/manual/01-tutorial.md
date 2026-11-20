# Tutorial: kućni budžet, od tablice do aplikacije

U ovom tutorialu gradimo malu aplikaciju za praćenje troškova: tablice, unos podataka, formu, upit, izvješće s grupama i zbrojevima, makro, izbornik, korisnike i gotovu aplikaciju. Naziv dijaloga i gumba odgovaraju programu; ako radije počinješ iz gotovog, u *Baza → Nova: primjer-baza iz kataloga* postoji domena „Kućni budžet” s istim tablicama.

**Što ćeš naučiti:** logičke tipove polja, veze među tablicama, forme iz čarobnjaka, izraze, upite, izvješća, makroe, izbornik, prava, izvoz i rad na serveru.

## 1. Nova baza

1. *Baza → Nova…* i odaberi mjesto i naziv, npr. `budzet.db`.
2. Baza je SQLite datoteka. U njoj će biti tvoji podaci i sve što praviš (forme, izvješća, makroi).

## 2. Prva tablica: kategorije

1. *Tablica → Nova tablica…*
2. Naziv: `kategorija`. Popis polja već ima prvo polje `id` (tip *AutoNumber*, primarni ključ) — broji se samo.
3. **Dodaj…** i u dijalogu *Svojstva polja* upiši:
   * Naziv `naziv`, Tip `Text`, označi **Obavezno (NOT NULL)**, Oznaka u formama `Naziv`.
   * Opis (savjet) po želji — pojavljuje se kao opis polja u formama.
4. **Dodaj…** polje `vrsta`, Tip `Text`, Zadana vrijednost `"Rashod"` (zadana vrijednost je izraz, pa je tekst u navodnicima).
5. **Izradi**.

> Brže: tipku **Polje iz kataloga** ili **Tablica iz kataloga** koristiš kad želiš gotova polja (npr. e-pošta s provjerom oblika, IBAN, OIB) ili cijelu tablicu iz kataloga; tip, format, provjera i opis postave se sami.

## 3. Druga tablica: transakcije

*Tablica → Nova tablica…* s nazivom `transakcija` i poljima:

| Polje | Tip | Napomena |
|---|---|---|
| `id` | AutoNumber | primarni ključ (već ponuđeno) |
| `datum` | Date | Zadana vrijednost: `Date()` — današnji datum za svaki novi redak |
| `iznos` | Currency | Decimale: `2`; prikazuje se kao `1.234,50 €` |
| `kategorija_id` | Integer | **Veza na tablicu** `kategorija`, polje `id`, Pri brisanju: `RESTRICT` (kategorija se ne može obrisati dok ima transakcija) |
| `opis` | Text | |
| `racun` | Picture | fotografija računa — u bazi se čuva samo **veza** na sliku (vidi poglavlje o pohrani datoteka) |

Veza na tablicu daje dvije stvari odjednom: bazu čuva od neispravnih podataka i forme su u mogućnosti pokazati naziv kategorije umjesto broja.

## 4. Unos podataka

Na kartici *Tablice* označi tablicu da se otvori mreža. U `kategorija` upiši nekoliko redaka (Plaća — Prihod, Hrana, Stanovanje, Prijevoz — Rashod), pa u `transakcija` nekoliko transakcija. Datum i iznos se prikazuju u hrvatskom zapisu i provjeravaju pri unosu; krivo upisan datum ili iznos neće se spremiti.

## 5. Forma iz čarobnjaka

1. *Forma → Čarobnjak forme…*
2. **Izvor:** `transakcija`. U popisu **Polja** označi sva (gumb *Sva*).
3. **Raspored:** *Jedan stupac*. **Naziv:** `Transakcije`. **Izradi**.
4. Na kartici *Forme* označi `Transakcije` i **Otvori**. Vidiš polja, navigaciju (prvi, prethodni, sljedeći, zadnji, novi, obriši) i pretragu. Kategorija je padajući popis jer polje ima vezu.
5. **Dizajn** otvara dizajner: pomičeš i mijenjaš kontrole i njihova svojstva.

### Izrazi u formi

U dizajneru dodaj *TextBox* kojem u `ControlSource` upišeš izraz s predznakom `=`:

```
=Format([iznos], "Currency") & " — " & Format([datum], "dd.mm.yyyy")
=Iif([iznos] > 1000, "Velika stavka", "")
=DLookup("naziv", "kategorija", "id = " & [kategorija_id])
```

`[ime]` je vrijednost polja, `&` spaja tekst, `Iif` bira. Svojstva `VisibleIf` i `EnabledIf` primaju izraz koji je istinit ili ne; `Locked` zaključava kontrolu. Cijeli popis funkcija je u *Referenci izraza*.

## 6. Upit: potrošnja po kategoriji

1. *Upit → Čarobnjak upita…*
2. **1. Tablice i upiti:** `transakcija` i `kategorija`. Veza se uzima iz stranog ključa.
3. **2. Polja:** `kategorija.naziv`, `transakcija.iznos`.
4. **3. Vrsta upita:** zbirni (grupiranje). U koraku **4. Što se radi sa svakim poljem** naziv kategorije je *Grupiraj*, iznos *Zbroj*.
5. **Naziv upita:** `Potrošnja po kategoriji`. **Izradi** (ili „Otvori u dizajneru nakon izrade”).

Pokreni upit iz izbornika *Upit → Pokreni*. Upit s oznakom `[?Mjesec]` u uvjetu traži vrijednost pri pokretanju (parametarski upit).

## 7. Izvješće s grupama i zbrojevima

1. *Izvješće → Čarobnjak izvješća…*
2. **Izvor:** `transakcija`; **Vrsta:** *Tablično*; **Polja:** datum, opis, iznos.
3. **Grupiraj po:** `kategorija_id`; **Sortiraj po:** `datum`; uključi **Zbrojevi za brojčana polja**; **Naslov:** „Troškovi po kategoriji”; **Naziv:** `Troškovi`; **Izradi**.
4. *Izvješće → Pregled* prikazuje stranice; tipke u pregledniku izvoze u **PDF**, **HTML** ili šalju na pisač.

U dizajneru izvješća možeš dodati izraze (`=Sum([iznos])` u podnožju grupe, `=Page & "/" & Pages` u podnožju stranice) i uvjetno oblikovanje (npr. iznosi veći od 1000 crveno).

## 8. Makro

*Skripta → Novi makro…* s nazivom `Provjera` i tekstom:

```
# upozorenje za velike transakcije
if [iznos] > 1000 then msg: Velika transakcija, provjeri račun!
```

U dizajneru forme dodaj *Button* s `OnClick` = `macro:Provjera`. Makro se izvodi nad trenutnim zapisom. Pregled naredbi je u poglavlju o makroima. Za složenije od toga postoje **moduli** (PascalScript) čije se funkcije zovu i iz izraza.

## 9. Izbornik aplikacije

1. *Aplikacija → Čarobnjak izbornika…* — naslov „Kućni budžet”.
2. **Dodaj…** stavke u dijalogu *Stavka izbornika* (Natpis, Akcija, Objekt): „Transakcije” — akcija *Otvori formu* — objekt `Transakcije`; „Troškovi” — akcija *Otvori izvješće* — objekt `Troškovi`. Ostale akcije su *Pokreni makro*, *Pokreni proceduru* i *Zatvori*. Gumbi *Gore* i *Dolje* mijenjaju redoslijed.
3. Označi **Postavi kao početnu formu aplikacije**, **Izradi**.

## 10. Korisnici i prava

* *Aplikacija → Korisnici…* — **Dodaj…** korisnike i uloge: `viewer` (samo čita podatke), `user` (unosi podatke, pokreće forme, izvješća i makroe), `admin` (sve, uključujući dizajn). Dok nema nijednog korisnika, svatko je administrator i prijava se ne traži.
* *Aplikacija → Prava objekata…* — za pojedinu formu, izvješće ili makro postavi najnižu ulogu koja ga smije otvoriti.

## 11. Gotova aplikacija

*Aplikacija → Postavke i izvoz aplikacije…*: **Naslov**, **Početna forma**, uključi „Pokreni u runtime načinu” i **Spremi**. **Izvezi aplikaciju…** pravi mapu s čistom kopijom baze (`Naslov.db`), kopijom programa, pokretačem (`Naslov.sh`) i datotekom za radnu površinu (`Naslov.desktop`); mapa sa slikama ide uz bazu (`Naslov_datoteke`), osim ako je postavljena vlastita ili dijeljena mapa. Korisnici pokreću pokretač (ili `TyphAccess --runtime Naslov.db`): bez izbornika i dizajnera, s prijavom, samo s onim do čega imaju pravo. Izvoz radi s SQLite bazama.

## 12. Sigurnost podataka

* *Baza → Sigurnosna kopija…* sprema kopiju baze **i** mape sa slikama (`…_datoteke`).
* *Aplikacija → Planer zadataka…* automatizira kopije, PDF izvješća i izvoze po rasporedu (`--run-tasks`).
* *Aplikacija → Revizijski trag…* bilježi tko je što i kada promijenio u tablicama za koje ga uključiš.

## 13. Slike i datoteke

Slika na formi se bira dvoklikom na kontrolu *Image* (ili desnim klikom: *Odaberi sliku…*, *Ukloni sliku*). Slika se **ne sprema u bazu**: kopira se u mapu pohrane, a u polje ide samo veza (npr. `slike/transakcija/20261103-racun.png`). Gdje je mapa i kako je promijeniti vidi se u *Baza → Pohrana datoteka…*.

## 14. Isti podaci na serveru, rad u mreži

1. Pripremi praznu bazu na Postgresu ili MariaDB-u.
2. *Baza → Kopiraj ovu bazu na poslužitelj…* i unesi vrstu baze, poslužitelj, bazu, korisnika i lozinku. Kopiraju se tablice, podaci, veze, forme, izvješća, upiti, makroi i moduli (a i slike u pohranu odredišta).
3. Za rad više korisnika postavi **dijeljenu mapu** za slike (*Baza → Pohrana datoteka… → Promijeni mapu*) ili, po računalu, varijablu `TYPHACCESS_FILES`.
4. Svaki korisnik: *Baza → Spoji na poslužitelj…* ili `typhaccess --pg=host:port/baza/korisnik`.

## Što dalje

* Isprobaj primjer *Northwind Traders* (*Baza → Nova: primjer Northwind Traders…*) — veliki primjer s master–detalj formama, izvješćem računa i izbornikom.
* U *Nova: primjer-baza iz kataloga* ima 42 gotove domene (računi, skladište, plaće, PDV knjige, recepti…).
* Kad ti formule i makroi više nisu dovoljni, **4GL** je cijeli programski jezik za izbornike, unos, SQL i izvješća (poglavlje 4GL).
