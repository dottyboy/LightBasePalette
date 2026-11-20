-- Izvješće „Cjenik po kategorijama” iz Northwinda: grupe, zbrojevi, stranice, PDF.
DATABASE northwind

REPORT cjenik(r)
  DEFINE r RECORD
    kategorija TEXT,
    proizvod TEXT,
    cijena DECIMAL(10,2)
  END RECORD
  OUTPUT PAGE LENGTH 40
  ORDER BY r.kategorija, r.proizvod
  FORMAT
    FIRST PAGE HEADER
      PRINT "CJENIK PO KATEGORIJAMA", COLUMN 60, "Str. ", PAGENO
      PRINT "Datum: ", TODAY
      PRINT "======================================================="
    PAGE HEADER
      PRINT "Cjenik (nastavak)", COLUMN 60, "Str. ", PAGENO
      PRINT "-------------------------------------------------------"
    BEFORE GROUP OF r.kategorija
      SKIP 1 LINES
      NEED 4 LINES
      PRINT r.kategorija
    ON EVERY ROW
      PRINT COLUMN 4, r.proizvod, COLUMN 45, r.cijena USING "####&.&&"
    AFTER GROUP OF r.kategorija
      PRINT COLUMN 4, GROUP COUNT(*), " proizvoda", COLUMN 45, GROUP SUM(r.cijena) USING "####&.&&"
    ON LAST ROW
      SKIP 1 LINES
      PRINT "UKUPNO ", COUNT(*), " proizvoda, prosječna cijena ", AVG(r.cijena) USING "###&.&&"
    PAGE TRAILER
      PRINT COLUMN 60, "Northwind"
END REPORT


MAIN
  DEFINE r RECORD
    kategorija TEXT,
    proizvod TEXT,
    cijena DECIMAL(10,2)
  END RECORD
  DECLARE c CURSOR FOR
    SELECT c.categoryname, p.productname, p.unitprice
      FROM products p JOIN categories c ON c.categoryid = p.categoryid
  START REPORT cjenik TO PDF "cjenik.pdf"
  FOREACH c INTO r.*
    OUTPUT TO REPORT cjenik(r.*)
  END FOREACH
  FINISH REPORT cjenik
  MESSAGE "Izvješće je spremljeno u cjenik.pdf"
END MAIN
