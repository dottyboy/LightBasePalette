-- Uređivanje cjenika: zaslon s poljima + mreža (INPUT ARRAY) + spremanje u transakciji.
DATABASE northwind

SCREEN s_filter
  TITLE "Koji proizvodi?"
  LABEL "Kategorija" FIELD categoryid REQUIRED LOOKUP categories(categoryid, categoryname)
  LABEL "Najveća cijena" FIELD maxprice DEFAULT 1000 COMMENT "Prikaži samo jeftinije od ovoga"
END SCREEN

SCREEN s_cijene
  TITLE "Cjenik"
  LABEL "Šifra" FIELD productid READONLY
  LABEL "Proizvod" FIELD productname
  LABEL "Cijena" FIELD unitprice
END SCREEN

MAIN
  DEFINE f RECORD
    categoryid INTEGER,
    maxprice DECIMAL(10,2)
  END RECORD
  DEFINE r RECORD LIKE products.*
  DEFINE lista ARRAY[] OF RECORD LIKE products.*
  DEFINE n, i INTEGER

  INPUT BY NAME f.* FROM s_filter
  IF INT_FLAG THEN
    EXIT PROGRAM
  END IF

  DECLARE c CURSOR FOR
    SELECT * FROM products
     WHERE categoryid = $f.categoryid AND unitprice <= $f.maxprice
     ORDER BY productname
  LET n = 0
  FOREACH c INTO r.*
    LET n = n + 1
    LET lista[n].* = r.*
  END FOREACH
  IF n = 0 THEN
    MESSAGE "Nema proizvoda za zadani filter."
    EXIT PROGRAM
  END IF

  INPUT ARRAY lista FROM s_cijene
  IF INT_FLAG THEN
    EXIT PROGRAM
  END IF

  BEGIN WORK
  FOR i = 1 TO ARR_COUNT
    LET r.* = lista[i].*
    UPDATE products SET unitprice = $r.unitprice WHERE productid = $r.productid
  END FOR
  IF ask("Spremiti nove cijene (" || ARR_COUNT || " proizvoda)?") THEN
    COMMIT WORK
    MESSAGE "Spremljeno."
  ELSE
    ROLLBACK WORK
    MESSAGE "Odbačeno."
  END IF
END MAIN
