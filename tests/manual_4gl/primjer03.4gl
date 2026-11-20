DATABASE northwind

MAIN
  DEFINE k RECORD LIKE customers.*
  DEFINE n INTEGER
  SELECT COUNT(*) INTO n FROM customers
  DISPLAY "Kupaca: ", n

  SELECT * INTO k.* FROM customers WHERE customerid = 1
  IF SQLCA.SQLCODE = 100 THEN
    DISPLAY "Nema takvog kupca"
  ELSE
    DISPLAY k.companyname, " (", k.city, ")"
  END IF

  UPDATE customers SET city = $k.city WHERE customerid = $k.customerid
  DISPLAY "Promijenjeno redaka: ", SQLCA.SQLERRD[3]
END MAIN
