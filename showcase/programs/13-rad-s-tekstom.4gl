-- naziv: Šifre i natpisi artikala (rad s tekstom)
-- opis: Trim, Upper, Substr, LPad (recept 12)
-- expect: IZV-001  Izvorska voda 1,5 l  (19 znakova)
MAIN
  DEFINE naziv, kratko TEXT
  DEFINE n INTEGER
  LET n = 0
  DECLARE c CURSOR FOR SELECT naziv FROM artikli ORDER BY id LIMIT 6
  FOREACH c INTO naziv
    LET n = n + 1
    LET kratko = Upper(Substr(Trim(naziv), 1, 3)) || "-" || LPad(n USING "&&&", 3)
    DISPLAY kratko, "  ", naziv, "  (", Length(naziv), " znakova)"
  END FOREACH
END MAIN
