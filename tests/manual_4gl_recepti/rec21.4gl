-- expect: Poskupjelo: 2
-- expect-sql: SELECT cijena FROM artikl WHERE id = 1 => 4.95
-- expect-sql: SELECT cijena FROM artikl WHERE id = 2 => 3.2
MAIN
  UPDATE artikl SET cijena = ROUND(cijena * 1.1, 2) WHERE zaliha > 0
  DISPLAY "Poskupjelo: ", SQLCA.SQLERRD[3]
END MAIN
