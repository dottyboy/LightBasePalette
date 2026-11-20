DATABASE northwind

MAIN
  MENU "Northwind"
    COMMAND "Kupci"  "Pregled kupaca"
      CALL kupci()
    COMMAND "Izlaz"  "Kraj programa"
      EXIT MENU
  END MENU
END MAIN

FUNCTION kupci()
  DEFINE r RECORD LIKE customers.*
  DECLARE c CURSOR FOR SELECT * FROM customers ORDER BY companyname
  FOREACH c INTO r.*
    DISPLAY r.customerid, "  ", r.companyname
  END FOREACH
END FUNCTION
