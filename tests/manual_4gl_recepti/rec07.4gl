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
