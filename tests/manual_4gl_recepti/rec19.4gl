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
