DATABASE northwind

MAIN
  OPEN FORM f_kupci FROM "Customers"
  DISPLAY FORM f_kupci WHERE "country = 'Germany'"
END MAIN
