DATABASE northwind

SCREEN s_cijene
  TITLE "Cjenik"
  LABEL "Šifra"    FIELD productid
  LABEL "Proizvod" FIELD productname
  LABEL "Cijena"   FIELD unitprice
END SCREEN

MAIN
  DEFINE r RECORD LIKE products.*
  DEFINE lista ARRAY[] OF RECORD LIKE products.*
  DEFINE n, i INTEGER
  DECLARE c CURSOR FOR SELECT * FROM products WHERE categoryid = 1 ORDER BY productname
  LET n = 0
  FOREACH c INTO r.*
    LET n = n + 1
    LET lista[n].* = r.*
  END FOREACH

  INPUT ARRAY lista FROM s_cijene
  IF NOT INT_FLAG THEN
    BEGIN WORK
    FOR i = 1 TO ARR_COUNT
      LET r.* = lista[i].*
      UPDATE products SET unitprice = $r.unitprice WHERE productid = $r.productid
    END FOR
    COMMIT WORK
    DISPLAY "Spremljeno redaka: ", ARR_COUNT
  END IF
END MAIN
