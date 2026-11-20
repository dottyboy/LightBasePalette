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
