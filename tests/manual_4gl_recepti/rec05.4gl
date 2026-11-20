-- expect: Novi račun: 6
-- expect-sql: SELECT COUNT(*) FROM racun WHERE kupac = 'Nova' => 1
MAIN
  DEFINE sljedeci INTEGER
  DEFINE danas DATE
  LET danas = TODAY
  SELECT COALESCE(MAX(id), 0) + 1 INTO sljedeci FROM racun
  INSERT INTO racun (id, kupac, iznos, placeno, datum) VALUES ($sljedeci, 'Nova', 10, 0, $danas)
  DISPLAY "Novi račun: ", sljedeci
END MAIN
