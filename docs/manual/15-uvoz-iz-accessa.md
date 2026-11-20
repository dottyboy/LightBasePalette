# Uvoz iz Accessa

Iz Access baze (`.mdb` iz Accessa 97, 2000 i 2003, te `.accdb`) uvoze se **tablice s podacima i vezama**, a iz njih se odmah složi aplikacija: forma za svaku tablicu, popis (izvješće) i bočni izbornik. Forme, izvješća, makroi i VBA iz Accessa **ne prevode se** (vlasnički su format vezan uz VBA), ali se VBA kod izvuče kao tekst za inspiraciju (samo iz Access 97 datoteka); umjesto toga dobiješ popis što nije uvezeno, a nove forme i izvješća slažu se opisom aplikacije (poglavlje *Opis aplikacije*).

## Što je potrebno

Datoteke čita program **mdbtools**, koji se samo pokreće kao zaseban program (nije ugrađen u TyphAccess):

* Debian i Ubuntu: `sudo apt install mdbtools`;
* bez instalacije: raspakiraj `.deb` pakete `mdbtools` i `libmdb3t64` u `~/.local/share/typhaccess/mdbtools` (program ih tamo sam nađe) ili postavi `MDBTOOLS_DIR` na mapu s programima `mdb-tables`, `mdb-schema`, `mdb-export`, `mdb-queries`.

Ako programa nema, izbornik to javlja i ništa ne radi.

## Kako se pokreće

* *Baza → Nova: uvoz iz Accessa (.mdb, .accdb)…* (bira se Access datoteka, pa datoteka nove baze), ili
* naredbom: `typhaccess --import-mdb=Northwind.mdb Northwind.db`.

Uz novu bazu nastaju dvije datoteke:

* `Northwind.opis`: **nacrt opisa aplikacije** nad uvezenim tablicama (tablice, polja, veze). Uredi ga i primijeni da dodaš forme, izvješća, vrste dokumenata i prava onako kako ti treba.
* `Northwind.uvoz.txt`: **izvještaj o neuvezenom** (vidi niže).

## Što se uvozi

| Iz Accessa | U TyphAccess |
|---|---|
| tablice | tablice **istog naziva** (i `Order Details` s razmakom ostaje takva), nazivi polja isti |
| vrste polja | Text, Memo, Integer, Decimal, Currency, YesNo, Date, DateTime; datum s vremenom u ponoć postaje Date |
| AutoNumber | AutoNumber (ključ tablice) |
| primarni ključ | primarni ključ (i složeni) |
| veze između tablica | strani ključevi; brisanje u nizu (cascade delete) ako ga veza ima; padajući popisi na formama |
| NOT NULL, zadane vrijednosti | obavezna polja, zadani izrazi (`No` → 0, `Date()` → `Today()`, `Now()`) |
| opisi polja i tablica | opis polja u rječniku podataka |
| indeksi | indeksi |
| naslovi (Caption), pravila provjere unosa (ValidationRule/Text), obavezna polja | naslovi polja, pravila s porukom (djelomično pravilo `>= 0` postaje `[polje] >= 0`) |
| popis za odabir (lookup) bez zasebne veze | strani ključ, pa padajući popis na formi |
| slike (OLE objekti) | slikovne datoteke u pohrani, polje je veza na sliku i prikazuje se kao slika |
| podaci | svi retci |
| spremljeni upiti (SELECT, unija, unakrsni) | spremljeni upiti, uz prepis Access SQL-a (vidi niže) |

Nazivi ostaju kakvi jesu u Accessu zato da spremljeni upiti, koji ih koriste, rade bez prepravljanja.

Nakon uvoza veze se provjeravaju. Access dopušta zapise koji upućuju na zapis kojeg nema; takvi se uvoze, a u izvještaju se javlja koliko ih je.

## Spremljeni upiti

Upiti se ne čitaju iz teksta nego se **sastavljaju iz Accessove interne tablice upita** (`MSysQueries`): stupci, tablice, spojevi (unutarnji i lijevi/desni), uvjeti, grupiranje, poredak, `TOP n`, `DISTINCT`, unije (`UNION`) i unakrsni upiti. Tako se uvoze i oni koje alat mdbtools ne zna prepisati u tekst.

* **Unakrsni upiti** (`TRANSFORM … PIVOT`) postaju običan SQL sa stupcem za svaku vrijednost zaglavlja (`SUM(CASE WHEN … THEN … END)`). Popis vrijednosti je onaj zadan u Accessu (`In ("Qtr 1", …)`); kad ga nema, čita se iz podataka u trenutku uvoza (do 60 vrijednosti), pa se nove vrijednosti kasnije moraju dodati ručno.
* **Upiti s parametrima iz formi** (`[Forms]![Obrazac]![Polje]`, i kroz podforme `…![Podforma].[Form]![Polje]`) i parametri koje upit sam traži (`[Beginning Date]`, također kad nisu izričito deklarirani: naziv u zagradi koji nije stupac) postaju **upit za vrijednost pri otvaranju** (`[?Polje]`): program pita za vrijednost kad otvoriš upit ili izvješće nad njim.
* **Akcijski upiti** (izrada tablice, dodavanje, izmjena, brisanje) ne uvoze se; navedeni su u izvještaju.

Access SQL se prepisuje: `DISTINCTROW` → `DISTINCT`, `TOP n` → `LIMIT n`, `DESCENDING` → `DESC`, `&` → `||`, tekst u dvostrukim navodnicima → jednostruki, `Like "A*"` → `LIKE 'A%'`, datumi `#1/2/1995#` → `'1995-01-02'`, `Yes`/`No`/`True`/`False` → 1/0, funkcije `IIf`, `Nz`, `CCur`, `CDbl`, `CSng`, `CLng`, `CInt`, `CStr`, `Int`, `Year`, `Month`, `Day`, `DatePart` (yyyy, q, m, d, w, y, h, n, s), `Format` (uobičajeni datumski oblici i dvije decimale), `Left`, `Right`, `Mid`, `Len`, `InStr`, `UCase`, `LCase`, `Date()`, `Now()`. Upit se zatim isproba; ako radi, sprema se (i kao pogled, pa ga drugi upiti mogu koristiti kao tablicu). Upiti koji ovise o drugima uvoze se u nekoliko prolaza.

Što ne radi, ne uvozi se nego se upiše u izvještaj zajedno s izvornim SQL-om, da ga prepraviš ručno. To su upiti s funkcijama koje se ne prepisuju (npr. `Switch`, `Partition`, `DLookup` s Access sintaksom), upiti koji zovu vlastitu VBA funkciju (npr. `mycalculateage([DoB])`) i upiti koji kao tablicu koriste upit s parametrima i upiti s kojima se ne može sastaviti SELECT.

## Što se ne uvozi

* **Forme, izvješća, makroi, moduli (VBA):** navode se imenom u izvještaju. Nove forme i izvješća slože se iz opisa aplikacije.
* **Makroi** (Access ih sprema u zatvorenom obliku) ne mogu se pročitati.

### VBA kao inspiracija

Izvorni kod modula i kodova iza formi i izvješća (`Form_*`, `Report_*`) izvlači se kao tekst u mapu `<baza>_vba/`, jedna `.bas` datoteka po modulu, a izvještaj za svaku daje broj redaka i prvi komentar. Kod se ne izvodi i ne prevodi; služi da vidiš što je aplikacija radila (provjera unosa u `BeforeUpdate`, otvaranje forme s parametrom, dijalog za izvješće) i to složiš recepatima iz poglavlja *4GL recepti*. Samo **Access 97** (`.mdb`) čuva kod u tablici koju alat mdbtools može čitati. Kod u datotekama iz Accessa 2000 i novijih (`.mdb` formata 2000/2002/2003 i `.accdb`) nije dostupan pa se u izvještaju samo navodi imenom. Zaštita lozinkom nije isprobana.
* **OLE objekti koji nisu slika** (npr. Word dokumenti): slike (BMP, PNG, JPEG, GIF) se prenose, ostalo ne.
* **Veze s više stupaca** (složeni strani ključ).
* **Povezane tablice** (*Linked tables*, podaci su u drugoj Access ili vanjskoj datoteci): ne uvoze se, pa upiti nad njima ne rade. Uvezi izvornu datoteku s podacima, pa tek onda ovu.

## Primjer: Northwind

Uvoz Microsoftovog primjera Northwind (`nwind.mdb`, Access 97) daje 9 tablica, 4150 redaka, 7 veza, 17 fotografija i slika (zaposlenici, kategorije) i svih 22 spremljena upita, uključujući unakrsni (*Quarterly Orders by Product*) i one s parametrima iz formi (*Sales by Year*), te aplikaciju s formom i popisom za svaku tablicu. Na formi *Orders* kupac, zaposlenik i dostavljač su padajući popisi. Primjer za `.accdb` (`ASampleDatabase.accdb`, ACE) uvozi se na isti način.

## Napomena o licenci

mdbtools je slobodan softver (alati su pod GPL licencom). TyphAccess ga samo pokreće kao zaseban program i ne uključuje njegov kod.
