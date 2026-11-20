DATABASE northwind

MAIN
  DEFINE r RECORD LIKE orders.*
  DEFINE kupac, n INTEGER
  LET kupac = 1
  DECLARE c CURSOR FOR
    SELECT * FROM orders WHERE customerid = $kupac ORDER BY orderid
  LET n = 0
  FOREACH c INTO r.*
    LET n = n + 1
    DISPLAY n, ". narudžba ", r.orderid
    IF n >= 5 THEN
      EXIT FOREACH
    END IF
  END FOREACH
END MAIN
