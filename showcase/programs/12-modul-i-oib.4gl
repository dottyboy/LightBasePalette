-- naziv: Provjera OIB-a funkcijom iz modula
-- opis: poziv funkcije iz PascalScript modula (recept 17); poslovna pravila na jednom mjestu
-- expect: Provjereno partnera: 145, neispravnih: 0
-- expect: Razred kupca s 25000 EUR prometa: Zlatni
MAIN
  DEFINE oib, naziv TEXT
  DEFINE n, lose INTEGER
  LET n = 0
  LET lose = 0
  DECLARE c CURSOR FOR SELECT naziv, oib FROM partneri ORDER BY id
  FOREACH c INTO naziv, oib
    LET n = n + 1
    IF NOT pas.OibIspravan(oib) THEN
      LET lose = lose + 1
      DISPLAY "Neispravan OIB: ", naziv, " ", oib
    END IF
  END FOREACH
  DISPLAY "Provjereno partnera: ", n, ", neispravnih: ", lose
  DISPLAY "Razred kupca s 25000 EUR prometa: ", pas.RazredKupca(25000)
END MAIN
