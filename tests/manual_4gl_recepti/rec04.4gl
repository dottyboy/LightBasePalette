-- expect: Promijenjeno redaka: 2
-- expect-sql: SELECT cijena FROM artikl WHERE id = 1 => 4.95
MAIN
  UPDATE artikl SET cijena = ROUND(cijena * 1.10, 2) WHERE zaliha > 0
  DISPLAY "Promijenjeno redaka: ", SQLCA.SQLERRD[3]
END MAIN
