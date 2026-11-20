# 4GL recepti

Kratki programi za stvari koje se često traže. Svaki program je potpun i izvodi se u testu programa nad malom bazom; retci `-- expect:` iznad programa
pokazuju što program ispiše (ili što je u bazi poslije njega), a redci `-- prompt:` i `-- menu:` odgovori koje test daje na pitanja i izbornike.
Programi koriste tablice `racun` (`id`, `kupac`, `iznos`, `placeno`, `datum`) i `artikl` (`id`, `naziv`, `cijena`, `zaliha`). Pokretanje: `typhaccess --run=program.4gl baza.db --console`.

## 1. Zbroj i brojanje petljom

```4gl
-- expect: Ukupno: 275.5
-- expect: Plaćenih računa: 3
MAIN
  DEFINE iznos, ukupno DECIMAL(10,2)
  DEFINE placeno, n INTEGER
  DECLARE c CURSOR FOR SELECT iznos, placeno FROM racun
  LET ukupno = 0
  LET n = 0
  FOREACH c INTO iznos, placeno
    LET ukupno = ukupno + iznos
    IF placeno = 1 THEN
      LET n = n + 1
    END IF
  END FOREACH
  DISPLAY "Ukupno: ", ukupno
  DISPLAY "Plaćenih računa: ", n
END MAIN
```

Kad treba samo zbroj, jednostavniji je jedan SQL: `SELECT SUM(iznos) INTO ukupno FROM racun`. Petlja se isplati kad se po retku nešto odlučuje ili ispisuje.

## 2. Upit s parametrom iz unosa

```4gl
-- prompt: Ana
-- expect: Ana duguje 50
MAIN
  DEFINE kupac TEXT
  DEFINE dug DECIMAL(10,2)
  PROMPT "Kupac: " FOR kupac
  SELECT SUM(iznos) INTO dug FROM racun WHERE kupac = $kupac AND placeno = 0
  DISPLAY kupac, " duguje ", NVL(dug, 0)
END MAIN
```

`$kupac` je uvijek **parametar**, nikad dio teksta upita, pa nema SQL injekcije ni problema s apostrofima. `NVL` zamjenjuje „nema retka” nulom.

## 3. Transakcija s poništavanjem

```4gl
-- expect: Premješteno 4
-- expect: Nedovoljna zaliha, poništeno
-- expect-sql: SELECT zaliha FROM artikl WHERE id = 1 => 6
-- expect-sql: SELECT zaliha FROM artikl WHERE id = 2 => 4
MAIN
  CALL premjesti(1, 2, 4)
  CALL premjesti(1, 2, 20)
END MAIN

FUNCTION premjesti(od, prema, kol)
  DEFINE od, prema, kol, z INTEGER
  BEGIN WORK
  UPDATE artikl SET zaliha = zaliha - $kol WHERE id = $od
  UPDATE artikl SET zaliha = zaliha + $kol WHERE id = $prema
  SELECT zaliha INTO z FROM artikl WHERE id = $od
  IF z < 0 THEN
    ROLLBACK WORK
    DISPLAY "Nedovoljna zaliha, poništeno"
  ELSE
    COMMIT WORK
    DISPLAY "Premješteno ", kol
  END IF
END FUNCTION
```

Obje izmjene su jedna cjelina: ili prođu obje (`COMMIT WORK`) ili nijedna (`ROLLBACK WORK`). Drugi poziv vraća zalihu na stanje prije njega.

## 4. Masovna izmjena i broj zahvaćenih redaka

```4gl
-- expect: Promijenjeno redaka: 2
-- expect-sql: SELECT cijena FROM artikl WHERE id = 1 => 4.95
MAIN
  UPDATE artikl SET cijena = ROUND(cijena * 1.10, 2) WHERE zaliha > 0
  DISPLAY "Promijenjeno redaka: ", SQLCA.SQLERRD[3]
END MAIN
```

`SQLCA.SQLERRD[3]` je broj redaka koje je zahvatila zadnja naredba. Artikl bez zalihe (`Čaj`) nije promijenjen.

## 5. Sljedeći broj dokumenta

```4gl
-- expect: Novi račun: 6
-- expect-sql: SELECT COUNT(*) FROM racun WHERE kupac = 'Nova' => 1
MAIN
  DEFINE sljedeci INTEGER
  DEFINE danas DATE
  LET danas = TODAY
  SELECT COALESCE(MAX(id), 0) + 1 INTO sljedeci FROM racun
  INSERT INTO racun (id, kupac, iznos, placeno, datum) VALUES ($sljedeci, 'Nova', 10, 0, $danas)
  DISPLAY "Novi račun: ", sljedeci
END MAIN
```

U SQL-u koristi SQL funkcije (`COALESCE`, ne `NVL`; `NVL` je funkcija jezika 4GL i radi samo izvan SQL naredbi). Tekst u SQL-u piše se u **jednostrukim** navodnicima (`'Nova'`), a vrijednosti iz programa (i `TODAY`, preko varijable) idu kao `$parametar`. U jednom korisniku to je dovoljno. Kad više osoba unosi istodobno, dodaj `UNIQUE` na polje i pokušaj ponovo kad `SQLCA.SQLCODE` javi duplikat (vidi recept 10).

## 6. Ponavljaj unos dok nije ispravan

```4gl
-- prompt: abc
-- prompt: -5
-- prompt: 12
-- expect: Prihvaćeno: 12
MAIN
  DEFINE s TEXT
  DEFINE kol INTEGER
  LET kol = 0
  WHILE kol <= 0
    PROMPT "Količina: " FOR s
    IF IsNumeric(s) THEN
      LET kol = s
    END IF
    IF kol <= 0 THEN
      DISPLAY "Unesi broj veći od nule"
    END IF
  END WHILE
  DISPLAY "Prihvaćeno: ", kol
END MAIN
```

Provjera ide **prije** pretvorbe u broj (`IsNumeric`), pa „abc” ne ruši program.

## 7. Poravnat ispis s oblikom brojeva

```4gl
-- expect: Ana         100.00
-- expect: Ivo          75.50
MAIN
  DEFINE kupac TEXT
  DEFINE iznos DECIMAL(10,2)
  DECLARE c CURSOR FOR SELECT kupac, iznos FROM racun WHERE iznos >= 75 ORDER BY kupac
  FOREACH c INTO kupac, iznos
    DISPLAY RPad(kupac, 8), LPad(iznos USING "###,##0.00", 10)
  END FOREACH
END MAIN
```

`USING` oblikuje broj (`#` znamenka ili razmak, `0` znamenka, `,` tisućice, `.` decimale); `RPad` i `LPad` poravnavaju tekst.

## 8. Funkcija s više povratnih vrijednosti

```4gl
-- expect: najmanji=20 najveći=100
MAIN
  DEFINE a, b DECIMAL(10,2)
  CALL raspon() RETURNING a, b
  DISPLAY "najmanji=", a, " najveći=", b
END MAIN

FUNCTION raspon()
  DEFINE lo, hi DECIMAL(10,2)
  SELECT MIN(iznos), MAX(iznos) INTO lo, hi FROM racun
  RETURN lo, hi
END FUNCTION
```

## 9. Grupiranje u SQL-u, ukupno u programu

```4gl
-- expect: Ana 150
-- expect: Ivo 75.5
-- expect: Marko 50
-- expect: Ukupno 275.5
MAIN
  DEFINE kupac TEXT
  DEFINE zbroj, ukupno DECIMAL(10,2)
  LET ukupno = 0
  DECLARE c CURSOR FOR SELECT kupac, SUM(iznos) FROM racun GROUP BY kupac ORDER BY 2 DESC
  FOREACH c INTO kupac, zbroj
    DISPLAY kupac, " ", zbroj
    LET ukupno = ukupno + zbroj
  END FOREACH
  DISPLAY "Ukupno ", ukupno
END MAIN
```

## 10. Pogreška baze bez rušenja programa

```4gl
-- expect: Račun 1 već postoji
-- expect: Nastavljam
-- expect-sql: SELECT COUNT(*) FROM racun WHERE kupac = 'Dupli' => 0
MAIN
  DEFINE danas DATE
  LET danas = TODAY
  WHENEVER ERROR CONTINUE
  INSERT INTO racun (id, kupac, iznos, placeno, datum) VALUES (1, 'Dupli', 1, 0, $danas)
  IF SQLCA.SQLCODE < 0 THEN
    DISPLAY "Račun 1 već postoji"
  END IF
  WHENEVER ERROR STOP
  DISPLAY "Nastavljam"
END MAIN
```

Uz `WHENEVER ERROR CONTINUE` pogreška ne zaustavlja program: `SQLCA.SQLCODE` je negativan, a tekst pogreške baze je u `SQLCA.SQLERRM`. Vrati `WHENEVER ERROR STOP` čim provjera prođe.

## 11. Izbornik s podizbornikom

```4gl
-- menu: Izvješća
-- menu: Ukupno
-- menu: Natrag
-- menu: Izlaz
-- expect: Ukupno računa: 5
MAIN
  MENU "Glavni"
    COMMAND "Izvješća" "Pregledi"
      CALL izvjesca()
    COMMAND "Izlaz" "Kraj"
      EXIT MENU
  END MENU
END MAIN

FUNCTION izvjesca()
  DEFINE n INTEGER
  MENU "Izvješća"
    COMMAND "Ukupno" "Broj računa"
      SELECT COUNT(*) INTO n FROM racun
      DISPLAY "Ukupno računa: ", n
    COMMAND "Natrag" "Povratak"
      EXIT MENU
  END MENU
END FUNCTION
```

Podizbornik je obična funkcija s vlastitim `MENU`; `EXIT MENU` vraća na izbornik iznad.

## 12. Rad s tekstom

```4gl
-- expect: IVO
-- expect: iv
-- expect: 3
-- expect: [   Ivo]
MAIN
  DEFINE ime TEXT
  LET ime = "  Ivo  "
  LET ime = Trim(ime)
  DISPLAY Upper(ime)
  DISPLAY Lower(Substr(ime, 1, 2))
  DISPLAY Length(ime)
  DISPLAY "[", LPad(ime, 6), "]"
END MAIN
```

`Substr(tekst, početak, duljina)` broji od 1. Tekstove spajaš s `||` ili zarezom u `DISPLAY`.

## 13. Datumi i rokovi

```4gl
-- expect: Dospijeće: 2026-03-16
-- expect: Dana kašnjenja: 20
MAIN
  DEFINE izdan, dospijece, danas DATE
  LET izdan = DateSerial(2026, 3, 1)
  LET dospijece = DateAdd("d", 15, izdan)
  LET danas = DateSerial(2026, 4, 5)
  DISPLAY "Dospijeće: ", Format(dospijece, "yyyy-mm-dd")
  DISPLAY "Dana kašnjenja: ", DateDiff("d", dospijece, danas)
END MAIN
```

Sve funkcije izraza (`DateAdd`, `DateDiff`, `Format`, `Round`…) dostupne su i u 4GL-u.

## 14. Arhiviranje: kopiraj pa obriši

```4gl
-- expect: Arhivirano: 3
-- expect-sql: SELECT COUNT(*) FROM racun_arhiva => 3
-- expect-sql: SELECT COUNT(*) FROM racun => 2
MAIN
  DEFINE n INTEGER
  BEGIN WORK
  INSERT INTO racun_arhiva SELECT * FROM racun WHERE placeno = 1
  LET n = SQLCA.SQLERRD[3]
  DELETE FROM racun WHERE placeno = 1
  COMMIT WORK
  DISPLAY "Arhivirano: ", n
END MAIN
```

Kopiranje i brisanje su u jednoj transakciji: ako nešto pukne, ništa se ne gubi.

## 15. Upit s više parametara (PREPARE)

```4gl
-- expect: Plaćenih od 50 naviše: 2
MAIN
  DEFINE n INTEGER
  PREPARE p FROM "SELECT COUNT(*) FROM racun WHERE iznos >= ? AND placeno = ?"
  DECLARE c CURSOR FOR p
  OPEN c USING 50, 1
  FETCH c INTO n
  CLOSE c
  DISPLAY "Plaćenih od 50 naviše: ", n
END MAIN
```

`PREPARE` je koristan kad se tekst upita slaže u programu (npr. uvjeti ovise o unosu); vrijednosti uvijek idu kroz `?` i `USING`.

## 16. Tri najveća računa (polje u memoriji)

```4gl
-- expect: 100
-- expect: 75.5
-- expect: 50
MAIN
  DEFINE a ARRAY[20] OF DECIMAL(10,2)
  DEFINE iznos, t DECIMAL(10,2)
  DEFINE n, i, j INTEGER
  DECLARE c CURSOR FOR SELECT iznos FROM racun
  LET n = 0
  FOREACH c INTO iznos
    LET n = n + 1
    LET a[n] = iznos
  END FOREACH
  FOR i = 1 TO n - 1
    FOR j = i + 1 TO n
      IF a[j] > a[i] THEN
        LET t = a[i]
        LET a[i] = a[j]
        LET a[j] = t
      END IF
    END FOR
  END FOR
  FOR i = 1 TO 3
    DISPLAY a[i]
  END FOR
END MAIN
```

Za ovakav zadatak obično je jednostavnije `ORDER BY iznos DESC` i prva tri retka; polje treba kad se podaci obrađuju više puta ili kad redoslijed ovisi o izračunu.

## 17. Poziv funkcije iz PascalScript modula

```4gl
-- expect: PDV: 25
MAIN
  DISPLAY "PDV: ", pas.Pdv(100)
END MAIN
```

Funkcija `Pdv` je u modulu (u testu: `function Pdv(x: Double): Double; begin Result := Round(x * 25) / 100; end;`). Tako se poslovna pravila drže na jednom mjestu i za forme, izvješća i 4GL.

## 18. Popis onoga čega nema na zalihi

```4gl
-- expect: Nema na zalihi: Čaj
-- expect: Ukupno: 1
MAIN
  DEFINE naziv TEXT
  DEFINE n INTEGER
  DECLARE c CURSOR FOR SELECT naziv FROM artikl WHERE zaliha <= 0 ORDER BY naziv
  LET n = 0
  FOREACH c INTO naziv
    DISPLAY "Nema na zalihi: ", naziv
    LET n = n + 1
  END FOREACH
  DISPLAY "Ukupno: ", n
END MAIN
```

Uvjet ide u upit, a ne u petlju: baza vrati samo potrebne retke.

## 19. Razvrstavanje računa po iznosu (CASE)

```4gl
-- expect: mali: 2
-- expect: srednji: 2
-- expect: veliki: 1
MAIN
  DEFINE iznos DECIMAL(10,2)
  DEFINE mali, srednji, veliki INTEGER
  DECLARE c CURSOR FOR SELECT iznos FROM racun
  LET mali = 0
  LET srednji = 0
  LET veliki = 0
  FOREACH c INTO iznos
    CASE
      WHEN iznos < 50
        LET mali = mali + 1
      WHEN iznos < 100
        LET srednji = srednji + 1
      OTHERWISE
        LET veliki = veliki + 1
    END CASE
  END FOREACH
  DISPLAY "mali: ", mali
  DISPLAY "srednji: ", srednji
  DISPLAY "veliki: ", veliki
END MAIN
```

Grane se provjeravaju redom, prva koja vrijedi izvede se, pa uvjeti idu od najužeg prema najširem.

## 20. Prekini kad zbroj prijeđe prag (WHILE)

```4gl
-- expect: Prag 150 prijeđen na računu 3, zbroj 180
MAIN
  DEFINE id INTEGER
  DEFINE iznos, zbroj DECIMAL(10,2)
  DEFINE gotovo INTEGER
  DECLARE c CURSOR FOR SELECT id, iznos FROM racun ORDER BY id
  OPEN c
  LET zbroj = 0
  LET gotovo = 0
  WHILE gotovo = 0
    FETCH c INTO id, iznos
    IF SQLCA.SQLCODE <> 0 THEN
      LET gotovo = 1
    ELSE
      LET zbroj = zbroj + iznos
      IF zbroj > 150 THEN
        DISPLAY "Prag 150 prijeđen na računu ", id, ", zbroj ", zbroj
        LET gotovo = 1
      END IF
    END IF
  END WHILE
  CLOSE c
END MAIN
```

`FETCH` izvan `FOREACH` daje kontrolu nad petljom; kraj podataka prepoznaje se po `SQLCA.SQLCODE <> 0`.

## 21. Poskupljenje samo za artikle na zalihi

```4gl
-- expect: Poskupjelo: 2
-- expect-sql: SELECT cijena FROM artikl WHERE id = 1 => 4.95
-- expect-sql: SELECT cijena FROM artikl WHERE id = 2 => 3.2
MAIN
  UPDATE artikl SET cijena = ROUND(cijena * 1.1, 2) WHERE zaliha > 0
  DISPLAY "Poskupjelo: ", SQLCA.SQLERRD[3]
END MAIN
```

Jedna naredba umjesto petlje; broj zahvaćenih redaka je u `SQLCA.SQLERRD[3]`. Prije masovne izmjene isprobaj isti uvjet kao `SELECT COUNT(*)`.

## 22. Ne briši kupca koji ima neplaćene račune

```4gl
-- expect: Ne može: Ana ima neplaćenih računa: 1
-- expect-sql: SELECT COUNT(*) FROM racun WHERE kupac = 'Ana' => 2
MAIN
  DEFINE kupac TEXT
  DEFINE n INTEGER
  LET kupac = "Ana"
  SELECT COUNT(*) INTO n FROM racun WHERE kupac = $kupac AND placeno = 0
  IF n > 0 THEN
    DISPLAY "Ne može: ", kupac, " ima neplaćenih računa: ", n
  ELSE
    DELETE FROM racun WHERE kupac = $kupac
    DISPLAY "Obrisano"
  END IF
END MAIN
```

Provjera ide prije brisanja, a ne nakon njega. Isto se može napisati kao provjera polja (`BeforeUpdate`) u formi; 4GL je zgodniji za noćne i skupne obrade.

## 23. Redni broj dokumenta iz tablice brojača (po vrsti i godini)

Tablica `dokumenti` ima po jedan redak za svaku vrstu (`vrsta`, `sifradok` = prefiks, `rednidok` = zadnji broj, `godina`). Broj se dodjeljuje i dokument upisuje u **jednoj transakciji**, pa se broj ne troši ako upis ne uspije, a istodobni korisnici ne dobiju isti broj.

```4gl
-- expect: Dokument otp, redni broj 1
-- expect: Dokument otp, redni broj 2
-- expect: Dokument rv, redni broj 1
-- expect-sql: SELECT COUNT(*) FROM dokument WHERE broj = 'otp-' || strftime('%Y', 'now') || '-0002' => 1
-- expect-sql: SELECT rednidok FROM dokumenti WHERE vrsta = 'otp' => 2
MAIN
  CALL novi_dokument("otp")
  CALL novi_dokument("otp")
  CALL novi_dokument("rv")
END MAIN

FUNCTION novi_dokument(vrsta)
  DEFINE vrsta, broj TEXT
  DEFINE g, n INTEGER
  SELECT CAST(strftime('%Y', 'now') AS INTEGER) INTO g FROM dokumenti WHERE vrsta = $vrsta
  BEGIN WORK
  UPDATE dokumenti SET rednidok = CASE WHEN godina = $g THEN rednidok + 1 ELSE 1 END, godina = $g WHERE vrsta = $vrsta
  SELECT rednidok, sifradok || '-' || godina || '-' || printf('%04d', rednidok) INTO n, broj FROM dokumenti WHERE vrsta = $vrsta
  INSERT INTO dokument (vrsta, broj) VALUES ($vrsta, $broj)
  COMMIT WORK
  DISPLAY "Dokument ", vrsta, ", redni broj ", n
END FUNCTION
```

`UPDATE` zaključava redak vrste do `COMMIT WORK`, pa se istodobni pozivi poredaju jedan iza drugoga. Kad se godina promijeni, brojač (`CASE`) počinje ponovno od 1. Broj `otp-2026-0002` u tablici `dokument` je prefiks, godina i redni broj s 4 znamenke.
