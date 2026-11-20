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
