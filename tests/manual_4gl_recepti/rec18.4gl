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
