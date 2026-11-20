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
