-- Northwind u 4GL-u: izbornik, pretraga po primjeru, kursor, poskupljenje u transakciji.
DATABASE northwind

GLOBALS
  DEFINE g_pregledano INTEGER
END GLOBALS

MAIN
  LET g_pregledano = 0
  MENU "Northwind 4GL"
    COMMAND "Kupci"     "Pretraži kupce po primjeru"   CALL kupci()
    COMMAND "Kategorije" "Broj proizvoda po kategoriji" CALL kategorije()
    COMMAND "Poskupljenje" "Cjenik +x% (probno)"       CALL poskupljenje()
    COMMAND "Izlaz"     "Kraj"                          EXIT MENU
  END MENU
  DISPLAY "Pregledano kupaca: ", g_pregledano
END MAIN

FUNCTION kupci()
  DEFINE k RECORD LIKE customers.*
  DEFINE uvjet, sql TEXT
  CONSTRUCT BY NAME uvjet ON customers.companyname, customers.city TITLE "Pretraga kupaca"
  IF INT_FLAG THEN
    RETURN
  END IF
  LET sql = "SELECT * FROM customers WHERE " || uvjet || " ORDER BY companyname"
  PREPARE p1 FROM sql
  DECLARE c CURSOR FOR p1
  FOREACH c INTO k.*
    LET g_pregledano = g_pregledano + 1
    DISPLAY k.customerid USING "000", "  ", k.companyname, " (", k.city, ")"
  END FOREACH
END FUNCTION

FUNCTION kategorije()
  DEFINE naziv TEXT
  DEFINE n INTEGER
  DECLARE ck CURSOR FOR
    SELECT c.categoryname, COUNT(*)
      FROM products p JOIN categories c ON c.categoryid = p.categoryid
     GROUP BY c.categoryname
     ORDER BY 2 DESC, 1
  FOREACH ck INTO naziv, n
    DISPLAY naziv, ": ", n
  END FOREACH
END FUNCTION

FUNCTION poskupljenje()
  DEFINE postotak DECIMAL(5,2)
  DEFINE prije, poslije DECIMAL(12,2)
  PROMPT "Postotak poskupljenja: " FOR postotak
  IF INT_FLAG THEN
    RETURN
  END IF
  SELECT SUM(unitprice) INTO prije FROM products
  BEGIN WORK
  UPDATE products SET unitprice = ROUND(unitprice * (1 + $postotak / 100.0), 2)
  SELECT SUM(unitprice) INTO poslije FROM products
  DISPLAY "Zbroj cijena: ", prije USING "#,##0.00", " -> ", poslije USING "#,##0.00"
  IF ask("Potvrditi promjenu?") THEN
    COMMIT WORK
    MESSAGE "Promijenjeno redaka: ", SQLCA.SQLERRD[3]
  ELSE
    ROLLBACK WORK
    DISPLAY "Odustao, cijene vraćene."
  END IF
END FUNCTION
