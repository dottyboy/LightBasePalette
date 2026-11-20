-- naziv: Poskupljenje kategorije za postotak
-- opis: unos s provjerom (recept 6), masovna izmjena i broj zahvaćenih redaka (recept 4)
-- prompt: abc
-- prompt: 8
-- expect: Poskupjelo artikala u kategoriji Kava i čaj: 9 (8 %)
MAIN
  DEFINE s TEXT
  DEFINE p DECIMAL(5,2)
  DEFINE n, pokusaji INTEGER
  LET p = 0
  LET pokusaji = 0
  WHILE (p <= 0 OR p > 30) AND pokusaji < 5
    LET pokusaji = pokusaji + 1
    PROMPT "Za koliko posto (1-30)? " FOR s
    IF IsNumeric(s) THEN
      LET p = s
    END IF
    IF p <= 0 OR p > 30 THEN
      DISPLAY "Upiši broj između 1 i 30"
    END IF
  END WHILE
  IF p <= 0 OR p > 30 THEN
    DISPLAY "Odustajem: nije upisan ispravan postotak"
    RETURN
  END IF
  UPDATE artikli SET cijena = ROUND(cijena * (1 + $p / 100), 2) WHERE kategorija_id = 2 AND aktivan = 1
  LET n = SQLCA.SQLERRD[3]
  DISPLAY "Poskupjelo artikala u kategoriji Kava i čaj: ", n, " (", p, " %)"
END MAIN
