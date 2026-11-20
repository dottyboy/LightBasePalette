-- expect: Plaćenih od 50 naviše: 2
MAIN
  DEFINE n INTEGER
  PREPARE p FROM "SELECT COUNT(*) FROM racun WHERE iznos >= ? AND placeno = ?"
  DECLARE c CURSOR FOR p
  OPEN c USING 50, 1
  FETCH c INTO n
  CLOSE c
  DISPLAY "Plaćenih od 50 naviše: ", n
END MAIN
