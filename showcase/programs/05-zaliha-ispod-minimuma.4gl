-- naziv: Artikli ispod minimalne zalihe
-- opis: uvjet u upitu, a ne u petlji (recept 18); stanje iz skladišnih dokumenata
-- expect: A080 Sapun tekući 500 ml            stanje 20 / min 40
-- expect: Artikala ispod minimuma: 10
MAIN
  DEFINE sifra, naziv TEXT
  DEFINE stanje, minimum DECIMAL(12,2)
  DEFINE n INTEGER
  LET n = 0
  DECLARE c CURSOR FOR
    SELECT a.sifra, a.naziv, a.min_zaliha,
           COALESCE((SELECT SUM(CASE WHEN d.tip = 'Primka' THEN k.kolicina ELSE -k.kolicina END)
                       FROM skl_stavke k JOIN skl_dokumenti d ON d.id = k.dokument_id WHERE k.artikl_id = a.id), 0) AS stanje
      FROM artikli a WHERE a.aktivan = 1
     ORDER BY 4, a.naziv
  FOREACH c INTO sifra, naziv, minimum, stanje
    IF stanje < minimum THEN
      DISPLAY sifra, " ", RPad(naziv, 30), " stanje ", stanje USING "###0", " / min ", minimum USING "###0"
      LET n = n + 1
    END IF
  END FOREACH
  DISPLAY "Artikala ispod minimuma: ", n
END MAIN
