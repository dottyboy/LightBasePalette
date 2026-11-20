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
