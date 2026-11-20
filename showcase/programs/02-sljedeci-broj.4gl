-- naziv: Novi račun sa sljedećim brojem
-- opis: sljedeći broj dokumenta (recept 5), vrijednosti iz programa kao $parametri
-- expect: Novi račun: 2026-275
-- expect-sql: SELECT COUNT(*) FROM racuni WHERE broj = '2026-275' => 1
MAIN
  DEFINE sljedeci, godina INTEGER
  DEFINE broj TEXT
  DEFINE danas, dosp DATE
  LET danas = DateSerial(2026, 11, 4)
  LET godina = Year(danas)
  LET dosp = DateAdd("d", 15, danas)
  SELECT COALESCE(MAX(CAST(SUBSTR(broj, 6) AS INTEGER)), 0) + 1 INTO sljedeci FROM racuni WHERE broj LIKE $godina || '-%'
  LET broj = godina || "-" || Format(sljedeci, "000")
  INSERT INTO racuni (broj, datum, dospijece, partner_id, placeno) VALUES ($broj, $danas, $dosp, 30, 0)
  DISPLAY "Novi račun: ", broj
END MAIN
