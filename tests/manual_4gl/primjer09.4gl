DATABASE northwind

MAIN
  DEFINE uvjet, sql TEXT
  DEFINE n INTEGER
  CONSTRUCT BY NAME uvjet ON customers.companyname, customers.city
  IF NOT INT_FLAG THEN
    LET sql = "SELECT COUNT(*) FROM customers WHERE " || uvjet
    PREPARE p FROM sql
    DECLARE c CURSOR FOR p
    OPEN c
    FETCH c INTO n
    CLOSE c
    DISPLAY "Pronađeno: ", n
  END IF
END MAIN
