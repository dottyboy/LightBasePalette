DATABASE northwind

REPORT cjenik(r)
  DEFINE r RECORD kategorija TEXT, proizvod TEXT, cijena DECIMAL(10,2) END RECORD
  OUTPUT PAGE LENGTH 40
  ORDER BY r.kategorija, r.proizvod
  FORMAT
    PAGE HEADER
      PRINT "CJENIK", COLUMN 50, "Str. ", PAGENO
      PRINT "----------------------------------------------------"
    BEFORE GROUP OF r.kategorija
      SKIP 1 LINES
      PRINT r.kategorija
    ON EVERY ROW
      PRINT COLUMN 4, r.proizvod, COLUMN 40, r.cijena USING "####&.&&"
    AFTER GROUP OF r.kategorija
      PRINT COLUMN 4, GROUP COUNT(*), " proizvoda",
        COLUMN 40, GROUP SUM(r.cijena) USING "####&.&&"
    ON LAST ROW
      SKIP 1 LINES
      PRINT "UKUPNO: ", SUM(r.cijena) USING "#####&.&&"
    PAGE TRAILER
      PRINT COLUMN 50, "Northwind"
END REPORT

MAIN
  DEFINE r RECORD kategorija TEXT, proizvod TEXT, cijena DECIMAL(10,2) END RECORD
  DECLARE c CURSOR FOR
    SELECT c.categoryname, p.productname, p.unitprice
      FROM products p JOIN categories c ON c.categoryid = p.categoryid
  START REPORT cjenik TO PDF "cjenik.pdf"
  FOREACH c INTO r.*
    OUTPUT TO REPORT cjenik(r.*)
  END FOREACH
  FINISH REPORT cjenik
END MAIN
