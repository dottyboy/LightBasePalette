# 4GL: programiranje poslovnih aplikacija

**4GL** je programski jezik u duhu Informix-4GL-a ugrađen u TyphAccess. Namijenjen je poslovima koje je teško složiti iz formi i makroa: izbornici, unos s provjerama, petlje preko rezultata upita, transakcije, tekstualna izvješća. SQL je dio jezika, bez posebnih biblioteka.

Programi su obične tekstualne datoteke (`.4gl`) koje se uređuju bilo kojim uređivačem, drže u gitu i pokreću ovako:

```
typhaccess --check=program.4gl                  # provjeri bez izvođenja
typhaccess --run=program.4gl baza.db            # pokreni s prozorima
typhaccess --run=program.4gl baza.db --console  # pokreni u terminalu (npr. iz skripte)
typhaccess --run=program.4gl --pg=host:5432/baza/korisnik
```

Primjeri u ovom poglavlju koriste bazu *Northwind* (`typhaccess --make-northwind Northwind.db`). Svi cjeloviti programi ispod prolaze `--check` u testovima programa.

## Uređivač blokova za 4GL

*Skripta → 4GL program (blokovi)…* otvara uređivač u kojem se 4GL program slaže blokovima, a gumb **Tekst** ga prebacuje u običan tekst (i natrag). Svaki redak programa je jedan blok; strukture
(`MAIN`, `FUNCTION`, `IF`, `WHILE`, `FOR`, `FOREACH`, `CASE`, `MENU`, `INPUT`, `REPORT`…) su uvučene, a `ELSE`, `WHEN`, `COMMAND` stoje u razini svog početka. Redak koji ne diraš ostaje točno onakav kakav je bio.

* **Lijevo** je popis predložaka po namjeni: *Program* (MAIN, funkcija, varijable), *Tijek* (IF, ELSE, CASE, WHILE, FOR, LET, CALL, EXIT, RETURN), *Baza* (SELECT INTO, kursor s FOREACH, INSERT, UPDATE, DELETE, transakcija),
  *Ispis i unos* (DISPLAY, MESSAGE, ERROR, PROMPT, MENU), *Ostalo* (komentar, WHENEVER ERROR, poziv PascalScript modula). Dvoklik umeće predložak **iza označenog retka**: unutar bloka ako je označen početak bloka, inače u istoj razini.
* **Desno** je program: tekst retka se uređuje izravno, **↑ ↓** ga pomiču, **✕** briše; brisanje početka strukture briše i njezin `END`, a sadržaj ostaje.
* **Provjeri** pokreće pravi parser (iste poruke kao `--check`), uz javljanje neuparenih struktura; **Pokreni** provjerava i izvodi program; **Spremi** piše `.4gl` datoteku.

Svi predlošci su ispravan 4GL (provjereni parserom), a model je isproban na svim programima iz ovog priručnika i primjera.

## 1. Prvi program

```4gl
MAIN
  DEFINE i INTEGER
  DEFINE ime TEXT
  LET ime = "svijete"
  DISPLAY "Pozdrav, ", ime, "!"
  FOR i = 1 TO 3
    DISPLAY "Redak ", i
  END FOR
END MAIN
```

* Program počinje blokom `MAIN`.
* `DEFINE` deklarira varijable; `LET` im dodjeljuje vrijednost.
* `DISPLAY` ispisuje; popis se spaja bez razmaka, pa razmake pišeš sam.
* Naredbe ne trebaju točku sa zarezom; kraj retka je dovoljan.
* Komentar počinje s `--` ili je u vitičastim zagradama `{ ... }`.
* Velika i mala slova se ne razlikuju.

Tipovi: `INTEGER`, `DECIMAL(10,2)`, `FLOAT`, `TEXT` (ili `CHAR`, `VARCHAR`), `DATE`, `DATETIME`, `BOOLEAN`, `RECORD`, `ARRAY`. Vrijednost `NULL` znači „nema vrijednosti”; `IF x IS NULL THEN`.

## 2. Naredbe toka

```4gl
MAIN
  DEFINE n, zbroj INTEGER
  LET zbroj = 0
  FOR n = 1 TO 10
    IF n MOD 2 = 0 THEN
      LET zbroj = zbroj + n
    END IF
  END FOR
  WHILE zbroj > 20
    LET zbroj = zbroj - 10
  END WHILE
  CASE zbroj
    WHEN 0     DISPLAY "nula"
    WHEN 10    DISPLAY "deset"
    OTHERWISE  DISPLAY "ostalo: ", zbroj
  END CASE
END MAIN
```

Petlje prekidaš s `EXIT FOR`, `EXIT WHILE`, `EXIT FOREACH` ili preskačeš s `CONTINUE …`; program završava s `EXIT PROGRAM`.

## 3. Baza u programu

Tablica kao tip: `RECORD LIKE customers.*` uzima stupce izravno iz baze. Parametri u SQL-u pišu se kao `$varijabla` (uvijek parametar, nikad spajanje teksta, pa nema SQL injekcije).

```4gl
DATABASE northwind

MAIN
  DEFINE k RECORD LIKE customers.*
  DEFINE n INTEGER
  SELECT COUNT(*) INTO n FROM customers
  DISPLAY "Kupaca: ", n

  SELECT * INTO k.* FROM customers WHERE customerid = 1
  IF SQLCA.SQLCODE = 100 THEN
    DISPLAY "Nema takvog kupca"
  ELSE
    DISPLAY k.companyname, " (", k.city, ")"
  END IF

  UPDATE customers SET city = $k.city WHERE customerid = $k.customerid
  DISPLAY "Promijenjeno redaka: ", SQLCA.SQLERRD[3]
END MAIN
```

* `SELECT … INTO` puni varijable; ako nema retka, `SQLCA.SQLCODE` je 100.
* `SQLCA.SQLERRD[3]` je broj redaka koje je zahvatila zadnja naredba.
* Pogreška SQL-a zaustavlja program porukom (`WHENEVER ERROR STOP`, zadano). Uz `WHENEVER ERROR CONTINUE` program nastavlja, a `SQLCA.SQLCODE` je negativan i tekst pogreške je u `SQLCA.SQLERRM`.
* `BEGIN WORK`, `COMMIT WORK`, `ROLLBACK WORK` upravljaju transakcijom.

### Kursori: petlja preko rezultata

```4gl
DATABASE northwind

MAIN
  DEFINE r RECORD LIKE orders.*
  DEFINE kupac, n INTEGER
  LET kupac = 1
  DECLARE c CURSOR FOR
    SELECT * FROM orders WHERE customerid = $kupac ORDER BY orderid
  LET n = 0
  FOREACH c INTO r.*
    LET n = n + 1
    DISPLAY n, ". narudžba ", r.orderid
    IF n >= 5 THEN
      EXIT FOREACH
    END IF
  END FOREACH
END MAIN
```

SQL naredba završava s krajem retka kad sljedeći redak počinje naredbom jezika (`LET`, `IF`, `END`…); kod dugih naredbi u više redaka slobodno lomi retke. Ako SQL treba završiti usred retka, upiši `;`.

Dinamički SQL: `PREPARE p FROM "SELECT … WHERE id > ?"`, pa `DECLARE c CURSOR FOR p` i `OPEN c USING 70`; `FETCH c INTO x` čita redak po redak, `CLOSE c` zatvara.

## 4. Izbornik

```4gl
DATABASE northwind

MAIN
  MENU "Northwind"
    COMMAND "Kupci"  "Pregled kupaca"
      CALL kupci()
    COMMAND "Izlaz"  "Kraj programa"
      EXIT MENU
  END MENU
END MAIN

FUNCTION kupci()
  DEFINE r RECORD LIKE customers.*
  DECLARE c CURSOR FOR SELECT * FROM customers ORDER BY companyname
  FOREACH c INTO r.*
    DISPLAY r.customerid, "  ", r.companyname
  END FOREACH
END FUNCTION
```

U prozoru je izbornik niz gumba (Esc zatvara), u konzoli numerirani popis. Svaka `COMMAND` ima naziv, kratak opis i naredbe koje se izvode.

## 5. Funkcije i više datoteka

```4gl
FUNCTION zbroji(a, b)
  DEFINE a, b INTEGER
  RETURN a + b, a * b
END FUNCTION

MAIN
  DEFINE s, p INTEGER
  CALL zbroji(3, 4) RETURNING s, p
  DISPLAY s, " ", p
  DISPLAY zbroji(1, 2)
END MAIN
```

* Parametri se navode imenom; tip im daješ s `DEFINE` u tijelu funkcije.
* `RETURN a, b` vraća više vrijednosti, `CALL … RETURNING x, y` ih prima.
* Funkcija se u izrazu koristi kao `zbroji(1, 2)` (prva vraćena vrijednost).
* `GLOBALS … END GLOBALS` deklarira globalne varijable, `INCLUDE "druga.4gl"` uključuje drugu datoteku.
* Ugrađene funkcije: `Length`, `Upper`, `Lower`, `Trim`, `Substr`, `Nvl`, `Ask`, `LPad`, `RPad`, `Center`, `Today`, `Current`, te sve funkcije izraza iz *Reference izraza* (`Round`, `Format`, `DateAdd`…). Funkcije iz modula (PascalScript) zovu se s `pas.Naziv(…)`.

## 6. Unos podataka

### Jednostavan unos

`PROMPT` pita jednu vrijednost i postavlja `INT_FLAG` na istinu ako korisnik odustane:

```4gl
MAIN
  DEFINE postotak DECIMAL(5,2)
  PROMPT "Postotak poskupljenja: " FOR postotak
  IF NOT INT_FLAG THEN
    DISPLAY "Upisano: ", postotak
  END IF
END MAIN
```

### Zaslon (SCREEN)

`SCREEN` opisuje polja unosa: oznaku, pravila i izbornik vrijednosti. Veže se na zapis imenima polja.

```4gl
DATABASE northwind

SCREEN s_dostavljac
  TITLE "Dostavljač"
  LABEL "Šifra"   FIELD shipperid   READONLY
  LABEL "Naziv"   FIELD companyname REQUIRED UPSHIFT COMMENT "Ime tvrtke"
  LABEL "Telefon" FIELD phone       DEFAULT "000"
END SCREEN

MAIN
  DEFINE k RECORD LIKE shippers.*
  LET k.shipperid = 88
  INPUT BY NAME k.* FROM s_dostavljac
    AFTER FIELD companyname
      IF LENGTH(k.companyname) < 3 THEN
        ERROR "Naziv je prekratak"
        NEXT FIELD companyname
      END IF
  END INPUT
  IF NOT INT_FLAG THEN
    INSERT INTO shippers (shipperid, companyname, phone)
      VALUES ($k.shipperid, $k.companyname, $k.phone)
    DISPLAY "Spremljeno: ", k.companyname
  END IF
END MAIN
```

Opcije polja: `READONLY`, `REQUIRED` (ne dopušta prazno), `UPSHIFT` (velika slova), `DEFAULT izraz`, `COMMENT "savjet"`, `LOOKUP tablica(ključ, naziv)` (padajući popis; u varijablu ide ključ). Bez `FROM zaslon` `INPUT BY NAME` sam složi polja iz zapisa.

Blokovi uz `INPUT`: `BEFORE INPUT`, `BEFORE FIELD x`, `AFTER FIELD x`, `AFTER INPUT`; `NEXT FIELD x` vraća korisnika na polje. `DISPLAY BY NAME zapis.* TO zaslon` samo prikazuje zapis.

### Upit po primjeru (CONSTRUCT)

Korisnik upiše uvjete poput `A*` (počinje s A), `>5`, `3:7` (od 3 do 7), `a|b` (a ili b); program ih pretvara u `WHERE`:

```4gl
DATABASE northwind

MAIN
  DEFINE uvjet, sql TEXT
  DEFINE n INTEGER
  CONSTRUCT BY NAME uvjet ON customers.companyname, customers.city
  IF NOT INT_FLAG THEN
    LET sql = "SELECT COUNT(*) FROM customers WHERE " || uvjet
    PREPARE p FROM sql
    DECLARE c CURSOR FOR p
    OPEN c
    FETCH c INTO n
    CLOSE c
    DISPLAY "Pronađeno: ", n
  END IF
END MAIN
```

## 7. Mreže (polja zapisa)

`DISPLAY ARRAY` i `INPUT ARRAY` prikazuju i uređuju polje zapisa u mreži. `ARRAY[]` je polje koje raste; `ARRAY[100]` ima najviše 100 redaka. Poslije naredbe `ARR_COUNT` je broj redaka.

```4gl
DATABASE northwind

SCREEN s_cijene
  TITLE "Cjenik"
  LABEL "Šifra"    FIELD productid
  LABEL "Proizvod" FIELD productname
  LABEL "Cijena"   FIELD unitprice
END SCREEN

MAIN
  DEFINE r RECORD LIKE products.*
  DEFINE lista ARRAY[] OF RECORD LIKE products.*
  DEFINE n, i INTEGER
  DECLARE c CURSOR FOR SELECT * FROM products WHERE categoryid = 1 ORDER BY productname
  LET n = 0
  FOREACH c INTO r.*
    LET n = n + 1
    LET lista[n].* = r.*
  END FOREACH

  INPUT ARRAY lista FROM s_cijene
  IF NOT INT_FLAG THEN
    BEGIN WORK
    FOR i = 1 TO ARR_COUNT
      LET r.* = lista[i].*
      UPDATE products SET unitprice = $r.unitprice WHERE productid = $r.productid
    END FOR
    COMMIT WORK
    DISPLAY "Spremljeno redaka: ", ARR_COUNT
  END IF
END MAIN
```

## 8. Otvaranje postojećih formi

Uz zaslone možeš otvoriti forme izrađene u dizajneru:

```4gl
DATABASE northwind

MAIN
  OPEN FORM f_kupci FROM "Customers"
  DISPLAY FORM f_kupci WHERE "country = 'Germany'"
END MAIN
```

## 9. Izvješća

Izvješće se piše kao `REPORT` blok, a puni se naredbom `OUTPUT TO REPORT` redak po redak:

```4gl
DATABASE northwind

REPORT cjenik(r)
  DEFINE r RECORD kategorija TEXT, proizvod TEXT, cijena DECIMAL(10,2) END RECORD
  OUTPUT PAGE LENGTH 40
  ORDER BY r.kategorija, r.proizvod
  FORMAT
    PAGE HEADER
      PRINT "CJENIK", COLUMN 50, "Str. ", PAGENO
      PRINT "----------------------------------------------------"
    BEFORE GROUP OF r.kategorija
      SKIP 1 LINES
      PRINT r.kategorija
    ON EVERY ROW
      PRINT COLUMN 4, r.proizvod, COLUMN 40, r.cijena USING "####&.&&"
    AFTER GROUP OF r.kategorija
      PRINT COLUMN 4, GROUP COUNT(*), " proizvoda",
        COLUMN 40, GROUP SUM(r.cijena) USING "####&.&&"
    ON LAST ROW
      SKIP 1 LINES
      PRINT "UKUPNO: ", SUM(r.cijena) USING "#####&.&&"
    PAGE TRAILER
      PRINT COLUMN 50, "Northwind"
END REPORT

MAIN
  DEFINE r RECORD kategorija TEXT, proizvod TEXT, cijena DECIMAL(10,2) END RECORD
  DECLARE c CURSOR FOR
    SELECT c.categoryname, p.productname, p.unitprice
      FROM products p JOIN categories c ON c.categoryid = p.categoryid
  START REPORT cjenik TO PDF "cjenik.pdf"
  FOREACH c INTO r.*
    OUTPUT TO REPORT cjenik(r.*)
  END FOREACH
  FINISH REPORT cjenik
END MAIN
```

* `START REPORT … TO` prima `SCREEN` (zadano), `FILE "x.txt"`, `PDF "x.pdf"`, `PRINTER ["ime"]` ili `PIPE "naredba"`.
* `ORDER BY` sortira, a `ORDER EXTERNAL BY` kaže da su podaci već sortirani (tada se izvješće obrađuje redak po redak).
* `PRINT` poravnava stupcima (`COLUMN n`), `USING` oblikuje brojeve (`#` znamenka ili razmak, `&` znamenka ili nula).
* Zbrojevi: `SUM`, `COUNT(*)`, `AVG`, `MIN`, `MAX`, `PERCENT(*)`; `GROUP …` vrijedi za tekuću grupu.

### Programi u bazi

Programi se ne moraju čuvati u datotekama: u uređivaču gumb **U bazu…** sprema program u bazu pod nazivom, a **Iz baze…** ga otvara. Izbornik *Skripta* ima *Novi 4GL program u bazi*, *Uredi*, *Pokreni* i *Obriši*, a popis je na kartici **4GL**. Iz makroa se pokreće naredbom `run4gl: Naziv`. Programi u bazi putuju s bazom (kopija, izvoz aplikacije). Zbirka od petnaest takvih programa je u velikom primjeru *Trgovina Jadran*.

## 10. Provjera i rješavanje pogrešaka

`--check` pronalazi: sintaksne greške (`datoteka:redak:stupac`), nedefinirane varijable, neispravan broj argumenata funkcije, nedeklarirane kursore, zaslone i izvješća te `EXIT` izvan petlje. Tijekom izvođenja greška izvan `WHENEVER ERROR CONTINUE` zaustavlja program porukom s retkom.

Pravila:

* varijable ne smiju imati imena rezerviranih riječi (`FOR`, `END`, `NEXT`, `FILE`…);
* velika i mala slova se ne razlikuju ni u nazivima;
* SQL se izvodi na bazi na koju je program spojen (SQLite, Postgres, MariaDB), pa SQL pišeš za nju.

## Pregled naredbi

| Skupina | Naredbe |
|---|---|
| Program | `MAIN`, `FUNCTION`, `RETURN`, `CALL … RETURNING`, `GLOBALS`, `INCLUDE`, `DATABASE`, `EXIT PROGRAM` |
| Podaci | `DEFINE`, `LET`, `INITIALIZE … TO NULL`, `RECORD LIKE`, `ARRAY` |
| Tok | `IF`, `CASE`, `WHILE`, `FOR`, `FOREACH`, `EXIT`, `CONTINUE`, `SLEEP` |
| SQL | `SELECT … INTO`, `INSERT`, `UPDATE`, `DELETE`, `DECLARE`, `OPEN`, `FETCH`, `CLOSE`, `FREE`, `PREPARE`, `EXECUTE`, `BEGIN/COMMIT/ROLLBACK WORK`, `WHENEVER ERROR` |
| Prikaz i unos | `DISPLAY`, `MESSAGE`, `ERROR`, `PROMPT`, `MENU`, `SCREEN`, `INPUT BY NAME`, `DISPLAY BY NAME`, `CONSTRUCT`, `INPUT/DISPLAY ARRAY`, `OPEN FORM`, `DISPLAY FORM` |
| Izvješća | `REPORT`, `START/OUTPUT TO/FINISH REPORT`, `PRINT`, `SKIP`, `NEED`, `PAGENO`, `LINENO` |

Gotovi kratki programi za česte zadatke (transakcije, parametri, arhiviranje, izbornici, datumi, polja…) su u poglavlju *4GL recepti*. Potpuna specifikacija (svi detalji i ograničenja) nalazi se u sljedećem poglavlju.
