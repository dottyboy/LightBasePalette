-- naziv: Cjenik po kategorijama (REPORT)
-- opis: izvješće s grupama i zbrojevima, ispis u datoteku
-- expect: Cjenik je ispisan u /tmp/jadran-cjenik.txt
REPORT cjenik(r)
  DEFINE r RECORD kategorija TEXT, naziv TEXT, jmj TEXT, cijena DECIMAL(10,2) END RECORD
  OUTPUT PAGE LENGTH 60
  ORDER BY r.kategorija, r.naziv
  FORMAT
    PAGE HEADER
      PRINT "CJENIK  Trgovina Jadran", COLUMN 60, "Str. ", PAGENO
      PRINT "------------------------------------------------------------------"
    BEFORE GROUP OF r.kategorija
      SKIP 1 LINES
      PRINT r.kategorija
    ON EVERY ROW
      PRINT COLUMN 4, r.naziv, COLUMN 40, r.jmj, COLUMN 50, r.cijena USING "###&.&&"
    AFTER GROUP OF r.kategorija
      PRINT COLUMN 4, GROUP COUNT(*) USING "#&", " artikala"
    ON LAST ROW
      SKIP 1 LINES
      PRINT "Ukupno artikala: ", COUNT(*) USING "###&"
END REPORT

MAIN
  DEFINE r RECORD kategorija TEXT, naziv TEXT, jmj TEXT, cijena DECIMAL(10,2) END RECORD
  DECLARE c CURSOR FOR
    SELECT k.naziv, a.naziv, a.jmj, a.cijena FROM artikli a JOIN kategorije k ON k.id = a.kategorija_id WHERE a.aktivan = 1
  START REPORT cjenik TO FILE "/tmp/jadran-cjenik.txt"
  FOREACH c INTO r.*
    OUTPUT TO REPORT cjenik(r.*)
  END FOREACH
  FINISH REPORT cjenik
  DISPLAY "Cjenik je ispisan u /tmp/jadran-cjenik.txt"
END MAIN
