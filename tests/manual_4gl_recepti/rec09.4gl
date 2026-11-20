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
