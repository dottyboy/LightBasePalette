# TyphAccess 4GL — specifikacija sintakse (nacrt 0.1)

Cilj: aplikacija je skup tekstualnih `.4gl` datoteka koje se pokreću s
`typhaccess run app.4gl --sqlite Northwind.db` (ili `--pg=...`, `--maria=...`).
Jezik je tumač nad stablom (tree-walking interpreter), ne kompajler.
Sintaksa je u duhu Informix-4GL-a; zasloni i izvješća se prevode u postojeće
`TaFormDef` i definicije izvješća, pa se ne piše novi UI sloj.

## 1. Odluke koje treba potvrditi

| # | Pitanje | Prijedlog |
|---|---------|-----------|
| 1 | Jezik ključnih riječi | engleski (kao 4GL), poruke i oznake su proizvoljan tekst |
| 2 | Velika/mala slova | neosjetljivo; naredbe završavaju krajem retka, `;` nije potreban |
| 3 | Odnos prema PascalScript modulima | ostaju kako jesu; 4GL ih može pozvati s `CALL pas.NazivFunkcije(...)` |
| 4 | Tipovi | `INTEGER`, `DECIMAL(p,s)`, `FLOAT`, `CHAR`/`TEXT`, `DATE`, `DATETIME`, `BOOLEAN`, `RECORD` |
| 5 | Datumi | interno ISO tekst (kao u ostatku TyphAccessa) |
| 6 | Greške | `WHENEVER ERROR CONTINUE/STOP`, `STATUS`, `SQLCA.SQLCODE` |

## 2. Struktura programa

```
DATABASE northwind              -- po želji; inače uzima bazu iz naredbene linije

GLOBALS
  DEFINE g_user TEXT
END GLOBALS

MAIN
  LET g_user = "ana"
  CALL main_menu()
END MAIN

FUNCTION main_menu()
  MENU "Northwind"
    COMMAND "Kupci"     "Pregled i uređivanje kupaca"   CALL kupci()
    COMMAND "Narudžbe"  "Narudžbe s pretraživanjem"     CALL narudzbe()
    COMMAND "Izvješće"  "Prodaja po kategorijama"       CALL prodaja_izvjesce()
    COMMAND "Izlaz"     "Kraj"                          EXIT MENU
  END MENU
END FUNCTION
```

- `INCLUDE "naziv.4gl"` uključuje drugu datoteku (modul).
- `FUNCTION naziv(parametri) RETURNING tip, ...` s `RETURN vrijednosti`.
- Komentari: `--` do kraja retka i `{ ... }`.

## 3. Varijable i zapisi

```
DEFINE n INTEGER
DEFINE ime TEXT
DEFINE kupac RECORD LIKE customers.*         -- polja iz sheme baze
DEFINE red RECORD
         sifra INTEGER,
         iznos DECIMAL(12,2)
       END RECORD
DEFINE popis ARRAY[100] OF RECORD LIKE products.*   -- dinamički: ARRAY[] OF
```

- `RECORD LIKE tablica.*` čita stupce iz sheme u trenutku izvođenja
  (radi i na SQLiteu, Postgresu i MariaDB-u jer `TableInfo` ima isti oblik).
- Pristup polju: `kupac.companyname`; cijelom zapisu: `kupac.*`.
- `LET x = izraz` — izrazi koriste postojeći evaluator (`ta_expr`), pa vrijede
  sve funkcije (`Nz`, `DLookup`, `Format`, `Date()`...).

## 4. Ugrađeni SQL

Bilo koja naredba `SELECT/INSERT/UPDATE/DELETE` piše se izravno. Varijable se
umeću s `$` i postaju parametri (nikad spajanje teksta):

```
SELECT companyname, city INTO kupac.companyname, kupac.city
  FROM customers WHERE customerid = $kupac.customerid

UPDATE products SET unitprice = unitprice * 1.1 WHERE categoryid = $kat
IF SQLCA.SQLERRD[3] = 0 THEN ... END IF         -- broj zahvaćenih redaka

BEGIN WORK
  INSERT INTO shippers (companyname) VALUES ($naziv)
COMMIT WORK                                      -- ili ROLLBACK WORK
```

Kursori:

```
DECLARE c_nar CURSOR FOR
  SELECT orderid, orderdate, customerid FROM orders WHERE customerid = $kupac.customerid

FOREACH c_nar INTO red.*
  DISPLAY red.orderid, " ", red.orderdate
END FOREACH
```

Također `OPEN c`, `FETCH c INTO ...`, `CLOSE c`, `FREE c`.

Prenosivost: SQL se šalje kroz isti `PortableSql`/dijalekt sloj kao ostali upiti;
funkcije posebne za bazu kvare prenosivost i dokumentirano je koje su sigurne.

## 5. Zasloni (forme kao tekst)

Dva načina, oba se prevode u `TaFormDef`:

**a) Postojeća forma iz baze** (najjeftinije, prva faza):
```
OPEN FORM f_kupci FROM "Kupci"            -- ime forme spremljene u bazi
DISPLAY FORM f_kupci
```

**b) Zaslon opisan tekstom** (druga faza):
```
SCREEN s_kupac
  TITLE "Kupac"
  LABEL "Šifra"    FIELD customerid  READONLY
  LABEL "Tvrtka"   FIELD companyname REQUIRED
  LABEL "Grad"     FIELD city
  LABEL "Država"   FIELD country     LOOKUP countries(code, name)
END SCREEN
```

Naredbe za unos:

```
INPUT BY NAME kupac.* FROM s_kupac        -- unos u zapis, kontrole prema polju
  BEFORE FIELD city     MESSAGE "Unesi grad"
  AFTER FIELD companyname
    IF kupac.companyname IS NULL THEN ERROR "Naziv je obavezan" NEXT FIELD companyname END IF
  ON KEY (F5)           CALL pomoc()
END INPUT
IF INT_FLAG THEN LET INT_FLAG = FALSE ...  -- korisnik odustao

DISPLAY BY NAME kupac.* TO s_kupac

CONSTRUCT BY NAME uvjet ON customers.companyname, customers.city FROM s_kupac
-- uvjet je tekst "companyname LIKE 'A%' AND city = 'Zagreb'" za WHERE
LET sql = "SELECT * FROM customers WHERE " || uvjet

PROMPT "Šifra kupca: " FOR sifra
```

`INPUT ARRAY` / `DISPLAY ARRAY` rade nad mrežom (`TDBGrid`) za master-detalj.

## 6. Izvješća

```
REPORT prodaja(r)
  DEFINE r RECORD kategorija TEXT, proizvod TEXT, iznos DECIMAL(12,2) END RECORD
  ORDER BY r.kategorija, r.proizvod
  FORMAT
    PAGE HEADER
      PRINT "Prodaja po kategorijama", COLUMN 60, "Str. ", PAGENO
    BEFORE GROUP OF r.kategorija
      PRINT r.kategorija
    ON EVERY ROW
      PRINT COLUMN 4, r.proizvod, COLUMN 40, r.iznos USING "#,##0.00"
    AFTER GROUP OF r.kategorija
      PRINT COLUMN 40, GROUP SUM(r.iznos) USING "#,##0.00"
    ON LAST ROW
      PRINT COLUMN 40, SUM(r.iznos) USING "#,##0.00"
END REPORT

FUNCTION prodaja_izvjesce()
  DEFINE r RECORD kategorija TEXT, proizvod TEXT, iznos DECIMAL(12,2) END RECORD
  START REPORT prodaja TO PDF "prodaja.pdf"        -- ili TO SCREEN / TO PRINTER
  DECLARE c CURSOR FOR
    SELECT c.categoryname, p.productname, SUM(d.unitprice*d.quantity)
      FROM orderdetails d JOIN products p USING (productid) JOIN categories c USING (categoryid)
     GROUP BY 1, 2
  FOREACH c INTO r.*
    OUTPUT TO REPORT prodaja(r.*)
  END FOREACH
  FINISH REPORT prodaja
END FUNCTION
```

`REPORT` blok se prevodi u `TaReportDef` (grupe, zbrojevi, zaglavlja), a
postojeći motor ga prikazuje ili izvozi u PDF.

## 7. Upravljanje tokom

`IF/ELSE/END IF`, `CASE/WHEN/OTHERWISE/END CASE`, `WHILE`, `FOR i = 1 TO n`,
`FOREACH`, `CONTINUE`, `EXIT`, `GOTO` se ne podržava.
`TRY ... CATCH` nije 4GL, ali se dodaje kao proširenje uz `WHENEVER`.
Poruke: `MESSAGE "..."`, `ERROR "..."`, `CALL ask("pitanje") RETURNING da`.

## 8. Cijela primjer-aplikacija (Northwind)

```
DATABASE northwind

MAIN
  MENU "Northwind 4GL"
    COMMAND "Kupci"    "Pretraži i uredi"  CALL kupci()
    COMMAND "Cjenik"   "Poskupljenje"      CALL poskupljenje()
    COMMAND "Izvješće" "Prodaja u PDF"     CALL prodaja_izvjesce()
    COMMAND "Izlaz"    ""                  EXIT MENU
  END MENU
END MAIN

FUNCTION kupci()
  DEFINE k RECORD LIKE customers.*
  DEFINE uvjet, sql TEXT
  CONSTRUCT BY NAME uvjet ON customers.companyname, customers.city FROM s_kupac
  IF INT_FLAG THEN RETURN END IF
  LET sql = "SELECT * FROM customers WHERE " || uvjet || " ORDER BY companyname"
  PREPARE p1 FROM sql
  DECLARE c CURSOR FOR p1
  FOREACH c INTO k.*
    DISPLAY BY NAME k.* TO s_kupac
    INPUT BY NAME k.* WITHOUT DEFAULTS FROM s_kupac
      AFTER FIELD companyname
        IF k.companyname IS NULL THEN ERROR "Naziv je obavezan" NEXT FIELD companyname END IF
    END INPUT
    IF NOT INT_FLAG THEN
      UPDATE customers SET companyname = $k.companyname, city = $k.city
       WHERE customerid = $k.customerid
    END IF
    LET INT_FLAG = FALSE
  END FOREACH
END FUNCTION

FUNCTION poskupljenje()
  DEFINE postotak DECIMAL(5,2)
  PROMPT "Postotak poskupljenja: " FOR postotak
  IF INT_FLAG THEN RETURN END IF
  BEGIN WORK
    UPDATE products SET unitprice = ROUND(unitprice * (1 + $postotak / 100), 2)
  COMMIT WORK
  MESSAGE "Promijenjeno redaka: ", SQLCA.SQLERRD[3]
END FUNCTION
```

## 9. Pokretanje i alati

- `typhaccess run app.4gl [--sqlite f | --pg=... | --maria=...]`
- `typhaccess check app.4gl` — samo parsira i provjerava (imena varijabli,
  tablice i stupci u SQL-u, tipovi gdje se mogu izvesti).
- Greške uvijek sa `datoteka:redak:stupac`.
- Debugger/uređivač s bojanjem sintakse je kasnija faza (modul-editor već postoji).

## 10. Faze izgradnje

1. **Jezgra (2–3 dana):** lexer, parser, tumač; `DEFINE`, `LET`, `IF/WHILE/FOR/CASE`,
   funkcije, ugrađeni SQL s parametrima, kursori, `FOREACH`, `MENU`, `MESSAGE`,
   `PROMPT`, `DISPLAY/INPUT` nad postojećom formom (5a), `typhaccess run/check`.
2. **Zasloni i CONSTRUCT:** `SCREEN` kao tekst, `INPUT BY NAME`, `CONSTRUCT`,
   `INPUT/DISPLAY ARRAY`.
3. **Izvješća:** `REPORT` → `TaReportDef`, `START/OUTPUT/FINISH REPORT`.
4. **Alati:** `check` s provjerom sheme, editor s bojanjem, primjeri, dokumentacija.

## 11. Što NE radimo

- ne generiramo native kod ni p-code (tumač je dovoljno brz za poslovnu logiku)
- ne emuliramo Informixov `.per` format ni njegov ISAM; samo sintaksu jezika
- ne radimo web ni mobilni UI; ciljna platforma je desktop (Qt6)

## 12. Stanje: faza 1 gotova (2026-11-03)

Implementirano u `src/core/ta_fgl.pas` (lexer, parser, tumač, I/O sloj) i
`src/gui/ta_fglgui.pas` (dijalozi). Pokretanje:

```
TyphAccess --check=app.4gl                       # parser + staticka provjera
TyphAccess --run=app.4gl baza.db [--console]     # --console: stdin/stdout umjesto prozora
TyphAccess --run=app.4gl --pg=host:port/baza/korisnik
```

Primjer: `examples/4gl/northwind.4gl`. Testovi: `TestFgl` u `tests/smoke.pas`.

Radi: `DATABASE`, `GLOBALS`, `INCLUDE`, `MAIN`, `FUNCTION` (neutipizirani parametri,
tip se daje s `DEFINE` u tijelu; `RETURN a, b`; `CALL f() RETURNING x, y`),
`DEFINE` (`INTEGER`, `DECIMAL`, `FLOAT`, `TEXT/CHAR/VARCHAR`, `DATE`, `DATETIME`,
`BOOLEAN`, `RECORD ... END RECORD`, `RECORD LIKE tablica.*`, `LIKE tablica.stupac`,
`ARRAY[n] OF`, `ARRAY[] OF`), `LET`, `INITIALIZE`, `IF`, `CASE` (oba oblika),
`WHILE`, `FOR ... STEP`, `FOREACH`, `EXIT/CONTINUE`, `EXIT PROGRAM`, `MENU`,
ugradeni SQL s `$varijabla` parametrima i `SELECT ... INTO`, `DECLARE/OPEN/FETCH/
CLOSE/FREE`, `PREPARE/EXECUTE` (s `?` i `USING`), `BEGIN/COMMIT/ROLLBACK WORK`,
`WHENEVER ERROR CONTINUE|STOP`, `SQLCA.SQLCODE/SQLERRD[3]`, `STATUS`, `INT_FLAG`,
`MESSAGE`, `ERROR`, `DISPLAY`, `PROMPT`, `CONSTRUCT BY NAME`, `OPEN FORM / DISPLAY FORM`,
`INPUT BY NAME` s `BEFORE/AFTER FIELD`, `BEFORE/AFTER INPUT`, `NEXT FIELD`.
Izrazi: `|| + - * / MOD ^`, usporedbe, `AND OR NOT`, `IS [NOT] NULL`, `LIKE`, `MATCHES`,
`BETWEEN`, `IN`, `x USING "fmt"`; funkcije `LENGTH UPPER LOWER TRIM SUBSTR NVL ASK
TODAY CURRENT`, sve Access funkcije iz `ta_expr` (Round, Format, DateAdd...) i
`CALL pas.Naziv(...)` za PascalScript module.

Odstupanja od nacrta gore:
- `INPUT BY NAME rec.*` otvara automatski generiran dijalog (polje po stupcu
  zapisa); `SCREEN` kao tekst dolazi u fazi 2. `OPEN FORM f FROM "Forma"` +
  `DISPLAY FORM f [WHERE uvjet]` otvara postojecu formu modalno.
- Kraj SQL naredbe: `;` ili novi redak koji pocinje naredbom jezika (`LET`,
  `IF`, `SELECT`...). `INSERT ... SELECT` i `UNION` mogu nastaviti u novom retku,
  ali ako SQL zavrsava na `END` ili `ON` u istom retku s drugom naredbom, koristi `;`.
- Kursor `FOREACH` cita red pa ga odmah pomice naprijed, prije tijela petlje.
- `CONSTRUCT` upisuje `stupac LIKE 'A%'`, `BETWEEN`, `=`, `>` itd. spojene s `AND`
  (`|` unutar polja = ILI).
- Ne radi jos: `SCREEN`, `INPUT/DISPLAY ARRAY`, `REPORT`, `ON KEY`, `GOTO`, `CLIPPED`.
- Jezik ne razlikuje velika/mala slova ni u ključnim riječima ni u nazivima;
  nazivi varijabli ne smiju biti rezervirane riječi (`FOR`, `END`, `NEXT`...).

## 13. Stanje: faza 2 gotova (2026-11-03)

Zasloni kao tekst i mreže nad poljima. Primjer: `examples/4gl/cjenik.4gl`.

```
SCREEN s_filter
  TITLE "Koji proizvodi?"
  LABEL "Kategorija" FIELD categoryid REQUIRED LOOKUP categories(categoryid, categoryname)
  LABEL "Najveća cijena" FIELD maxprice DEFAULT 1000 COMMENT "podsjetnik"
  FIELD naziv UPSHIFT READONLY
END SCREEN
```

- Opcije polja: `READONLY`, `REQUIRED`, `UPSHIFT`, `DEFAULT izraz`, `COMMENT "..."`,
  `LOOKUP tablica(kljuc, naziv)` (padajući popis; u varijablu ide ključ).
- Zaslon bira i redoslijed polja: `INPUT BY NAME rec.* FROM zaslon`,
  `DISPLAY BY NAME rec.* TO zaslon`, `CONSTRUCT BY NAME v ON ... FROM zaslon`
  (naslov). Polje zaslona koje nije među varijablama je greška; varijable koje nisu
  na zaslonu se ne prikazuju. `WITHOUT DEFAULTS` isključuje `DEFAULT`.
- `REQUIRED` se provjerava nakon potvrde (poruka s oznakom polja, fokus na polje),
  prije `AFTER FIELD`; `UPSHIFT` pretvara u velika slova.
- `DISPLAY ARRAY polje [TO zaslon] [TITLE ..]` i `INPUT ARRAY polje [WITHOUT DEFAULTS]
  [FROM zaslon] [TITLE ..]`: mreža nad poljem zapisa (ili skalara). Stupci su polja
  zaslona (ili svi članovi zapisa). `INPUT ARRAY` upisuje natrag samo neprazne redke;
  dinamičko polje `ARRAY[]` se skraćuje/produljuje, polje `ARRAY[n]` javlja grešku
  iznad n. Poslije naredbe: `ARR_COUNT` (broj redaka), `ARR_CURR` (odabrani redak),
  `INT_FLAG` (odustao).
- `--check` provjerava i nedefinirane zaslone.
- Nije još: `READONLY` stupci u mreži, `LOOKUP` u mreži, `ON KEY`, `BEFORE/AFTER ROW`.
  Grafički dijalozi (`ta_fglgui.pas`) nisu ručno isprobani; test pokriva logiku kroz
  `TaFglScriptIO`, a `--console` kroz stdin.

## 14. Stanje: faza 3 gotova (2026-11-03)

Izvješća u stilu Informixa. Primjer: `examples/4gl/prodaja_izvjesce.4gl` (Northwind, PDF).

```
REPORT cjenik(r)
  DEFINE r RECORD kategorija TEXT, proizvod TEXT, cijena DECIMAL(10,2) END RECORD
  OUTPUT LEFT MARGIN 0 PAGE LENGTH 40
  ORDER BY r.kategorija, r.proizvod          -- ili ORDER EXTERNAL BY (ulaz je već sortiran); može DESC
  FORMAT
    FIRST PAGE HEADER ...                    -- neobavezno; inače vrijedi PAGE HEADER
    PAGE HEADER ...
    BEFORE GROUP OF r.kategorija ...
    ON EVERY ROW ...
    AFTER GROUP OF r.kategorija ...
    ON LAST ROW ...
    PAGE TRAILER ...
END REPORT

START REPORT cjenik [TO SCREEN | FILE "x.txt" | PDF "x.pdf"]
OUTPUT TO REPORT cjenik(r.*)                 -- jedan redak; zapis se prenosi poljima, a može i više argumenata
FINISH REPORT cjenik                         -- sortira, ispisuje i isporučuje izvješće
```

- Naredbe u blokovima: `PRINT izrazi` (`COLUMN n` pomiče na stupac, `SPACES n`, `x USING "fmt"`, završni `;` = bez novog retka),
  `SKIP n LINES`, `SKIP TO TOP OF PAGE`, `NEED n LINES`; sve ostale naredbe jezika (`LET`, `IF`, `CALL`…) rade i u blokovima.
- Izrazi: `PAGENO`, `LINENO`, `TODAY`; zbrojevi `SUM`, `COUNT(*)`, `AVG`, `MIN`, `MAX` za cijelo izvješće i `GROUP …` za
  tekuću grupu (vrijednost je ispravna i u `AFTER GROUP OF`, gdje parametri još drže zadnji redak grupe).
- Više razina grupa: `ORDER BY a, b`; promjena ključa `a` zatvara i grupu `b`. `BEFORE/AFTER GROUP OF` bez `ORDER BY` uzima
  ključeve iz naredbi redom pojavljivanja.
- Stranice: `PAGE LENGTH` (zadano 60 redaka), `PAGE TRAILER` se ispisuje na dnu stranice (broji se broj njegovih `PRINT` naredbi).
- Ispis: `TO SCREEN` – pregled (u grafičkom načinu preglednik izvješća, u konzoli običan ispis); `TO FILE` – tekst, stranice
  odvojene znakom nove stranice (form feed); `TO PDF` – monospace PDF (DejaVu Sans Mono).
- `x USING "###,##&.&&"` (Informix): `#` znamenka ili razmak, `&` znamenka ili nula, `,` tisućice samo uz lijeve znamenke,
  `.` decimale, `-` mjesto za predznak, `<` bez vodećih razmaka; preveliki broj daje `*`. Oblici s `0` ili slovima
  (`#,##0.00`, `dd.mm.yyyy`) i dalje idu kroz izraze programa.
- `--check` javlja nedefinirano izvješće i nedefinirane varijable u blokovima izvješća.
- Ograničenja: vidi §15 (što je dodano nakon prve izvedbe); izvješće bez `ORDER BY` ili s `ORDER EXTERNAL BY` bez `PERCENT`
  obrađuje se redak po redak, a sortirano se do `FINISH REPORT` drži u memoriji.

## 15. Dopune izvješća (2026-11-03)

- `START REPORT x TO PRINTER ["ime pisača"]`: na Linuxu PDF + CUPS `lp [-d ime]`; bez `lp`-a ide LCL ispis na zadani pisač.
- `START REPORT x TO PIPE "naredba"`: tekst izvješća (stranice odvojene znakom nove stranice) ulazi u standardni ulaz naredbe,
  npr. `TO PIPE "lp -d laser"` ili `TO PIPE "cat > izvjestaj.txt"`. Nenulti izlazni kod je greška programa s ispisom naredbe.
- `GROUP PERCENT(*)` i `PERCENT(*)`: postotak redaka grupe (odnosno cijelog izvješća = 100) u ukupnom broju redaka;
  zbog toga se izvješće s `PERCENT` drži u memoriji do kraja.
- `PRINT FILE "datoteka"`: ispisuje retke datoteke.
- Poravnanje: `LPAD(s, n[, znak])` (desno), `RPAD(...)` (lijevo), `CENTER(s, n[, znak])` i postfiks `izraz CLIPPED` (bez završnih razmaka).
- `OUTPUT TOP MARGIN n` (prazni retci na vrhu svake stranice) i `BOTTOM MARGIN n` (prazni retci na dnu) uz `LEFT MARGIN` i `PAGE LENGTH`.
- Obrada redak po redak za `ORDER EXTERNAL BY` i izvješća bez ključeva (bez `PERCENT`): `OUTPUT TO REPORT` odmah obrađuje redak, pa veliki
  ulazi ne zauzimaju memoriju osim stranica izlaza.


## 16. 4GL kao izvor podataka (2026-11-10, LightPalette E4)

Program se može koristiti kao **izvor podataka** za kontrole: padajući popis, popis, grupu izbora, grafikon i izvješće
(podforma/mreža dolazi poslije). Izvor je tekst s prefiksom; bez prefiksa je sve kao prije (tablica, upit, SELECT).

| Prefiks | Značenje | Primjer |
|---|---|---|
| *(nema)* | tablica, spremljeni upit ili SELECT | `partneri` |
| `sql:` | izričito SQL | `sql:SELECT id, naziv FROM partneri` |
| `list:` | fiksni popis (`A;B;C` ili `kljuc=oznaka;...`) | `list:Novo;U tijeku;Završeno` |
| `fgl:` | 4GL funkcija koja vraća retke | `fgl:PopisPartnera(grad=[grad], aktivan=1)` |
| `fglv:` | 4GL funkcija koja vraća jednu vrijednost | `fglv:Popust([partner_id], [iznos])` |

Nove naredbe (vrijede samo kad se funkcija koristi kao izvor):

```4gl
FUNCTION PopisPartnera(grad, aktivan)
  DEFINE grad TEXT
  DEFINE aktivan INTEGER
  COLUMNS id INTEGER, naziv TEXT              -- naslovi i tipovi izlaznih stupaca
  DEFINE r RECORD id INTEGER, naziv TEXT END RECORD
  DECLARE c CURSOR FOR SELECT id, naziv FROM partneri WHERE grad = $grad AND aktivan = $aktivan ORDER BY naziv
  FOREACH c INTO r.*
    EMIT r.id, r.naziv                        -- jedan redak rezultata
  END FOREACH
END FUNCTION
```

- `COLUMNS naziv tip, ...` imenuje stupce; bez njega prvi `EMIT` stvara stupce `c1`, `c2`, ... (tekst). Tipovi: `INTEGER`, `FLOAT`/`DECIMAL`, `TEXT`/`CHAR`, `DATE`, `DATETIME`, `BOOLEAN`.
- `EMIT v1, v2, ...` dodaje redak; broj vrijednosti mora odgovarati stupcima.
- **Parametri** su imenovani (`grad=[grad]`) ili pozicijski; vrijednosti su izrazi koji se računaju nad zapisom forme. Kad se promijeni polje iz parametara, popis se ponovno puni (kao i uz SQL s `[polje]`).
- **Funkcija se traži** u programu istog naziva (`fgl:Program(...)`), ili kao `fgl:Program.Funkcija(...)`; ako program ima jednu funkciju koristi se ona, a inače `MAIN`.
- **Ograničenja:** najviše 5 s izvršavanja i 100.000 redaka (greška s porukom, ne zamrzava program); `INPUT`, `PROMPT`, `MENU`, `DISPLAY ARRAY`, `OPEN FORM` unutar izvora su greška s jasnom porukom.
- **Jedna vrijednost:** funkcija s `RETURN` vraća prvu vrijednost; u izrazima `Fgl("Program.Funkcija", arg, ...)` (pravilo, zadana vrijednost, izračunato polje, uvjetno oblikovanje).
- Izvješća: `RecordSource = fgl:...` daje retke iz programa (poredak i filter su stvar programa).
- Kod: `src/core/ta_source.pas` (`OpenSource`, `EvalSourceValue`, `TaFglDataSet`), `ta_fgl.pas` (`COLUMNS`, `EMIT`, `TaFglResult`, `TaFglSourceIO`, `TaFglRunner.CallFunc`). Testovi: `TestFglSource` u `tests/smoke.pas`.
- Još nije: podforma/mreža iz `fgl:`, uređivanje rezultata (`ON SAVE`), parametri izvješća.

## 17. Kosturi programa (`.4glt`, LightPalette E6)

Kostur je 4GL tekst s tipiziranim utorima koji se popunjavaju iz metapodataka baze (`ta_skeleton`). Knjižnica od 12 kostura je u
`LightPalette/skeletons/`, a korisnik dodaje svoje u istu mapu ili u `skeletons/` uz bazu. Format i sve zamjene opisani su u
`LightPalette/skeletons/README.md`. Rezultat je običan 4GL program koji prolazi `--check`; kosturi se ispituju u `TestSkeletons`
(`tests/smoke.pas`) nad dvije različite tablice i izvršavaju s provjerom rezultata. Sučelje čarobnjaka dolazi u etapi E7.
