-- naziv: Brisanje kupca uz provjeru neplaćenih računa
-- opis: ne briši kupca koji ima neplaćene račune (recept 22), pogreška baze bez rušenja (recept 10)
-- expect: Kupac Posavina market d.d. ima 2 neplaćenih računa, ne brišem
-- expect: Obrisan kupac Mario Mikulić obrt Čakovec
-- expect-sql: SELECT COUNT(*) FROM partneri => 144
MAIN
  CALL obrisi(26)
  CALL obrisi(145)
END MAIN

FUNCTION obrisi(id)
  DEFINE id, n, m INTEGER
  DEFINE naziv TEXT
  SELECT naziv INTO naziv FROM partneri WHERE id = $id
  SELECT COUNT(*) INTO n FROM racuni WHERE partner_id = $id AND placeno = 0
  SELECT COUNT(*) INTO m FROM racuni WHERE partner_id = $id
  IF n > 0 THEN
    DISPLAY "Kupac ", naziv, " ima ", n, " neplaćenih računa, ne brišem"
  ELSE
    IF m > 0 THEN
      DISPLAY "Kupac ", naziv, " ima račune (", m, "), ne brišem"
    ELSE
      WHENEVER ERROR CONTINUE
      DELETE FROM partneri WHERE id = $id
      WHENEVER ERROR STOP
      IF SQLCA.SQLCODE = 0 THEN
        DISPLAY "Obrisan kupac ", naziv
      ELSE
        DISPLAY "Brisanje nije uspjelo"
      END IF
    END IF
  END IF
END FUNCTION
