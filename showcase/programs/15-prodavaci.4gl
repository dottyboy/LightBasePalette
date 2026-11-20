-- naziv: Zbroj prodaje po prodavačima (FOREACH i funkcija)
-- opis: funkcija s više povratnih vrijednosti (recept 8)
-- expect: Lucija Vidović                 15,246.66
-- expect: Najmanja stavka 1.53, najveća 1786
MAIN
  DEFINE ime TEXT
  DEFINE zbroj, lo, hi DECIMAL(12,2)
  DECLARE c CURSOR FOR
    SELECT z.ime || ' ' || z.prezime, ROUND(SUM(s.iznos), 2)
      FROM racuni r JOIN zaposlenici z ON z.id = r.zaposlenik_id JOIN racuni_stavke s ON s.dokument_id = r.id
     GROUP BY z.id ORDER BY 2 DESC
  FOREACH c INTO ime, zbroj
    DISPLAY RPad(ime, 26), LPad(zbroj USING "###,##0.00", 14)
  END FOREACH
  CALL raspon() RETURNING lo, hi
  DISPLAY "Najmanja stavka ", lo, ", najveća ", hi
END MAIN

FUNCTION raspon()
  DEFINE lo, hi DECIMAL(12,2)
  SELECT MIN(iznos), MAX(iznos) INTO lo, hi FROM racuni_stavke
  RETURN lo, hi
END FUNCTION
