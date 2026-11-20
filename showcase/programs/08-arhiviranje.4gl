-- naziv: Arhiviranje starih plaćenih računa
-- opis: kopiraj pa obriši u jednoj transakciji (recept 14)
-- expect: Arhivirano računa: 72
-- expect-sql: SELECT COUNT(*) FROM racuni_arhiva => 72
-- expect-sql: SELECT COUNT(*) FROM racuni WHERE placeno = 1 AND datum < '2025-04-01' => 0
MAIN
  DEFINE n INTEGER
  BEGIN WORK
  INSERT INTO racuni_arhiva (broj, datum, partner_id, iznos)
    SELECT r.broj, r.datum, r.partner_id, ROUND(COALESCE((SELECT SUM(s.iznos * (1 + s.pdv_stopa / 100.0)) FROM racuni_stavke s WHERE s.dokument_id = r.id), 0), 2)
      FROM racuni r WHERE r.placeno = 1 AND r.datum < '2025-04-01'
  LET n = SQLCA.SQLERRD[3]
  DELETE FROM uplate WHERE racun_id IN (SELECT id FROM racuni WHERE placeno = 1 AND datum < '2025-04-01')
  DELETE FROM racuni WHERE placeno = 1 AND datum < '2025-04-01'
  COMMIT WORK
  DISPLAY "Arhivirano računa: ", n
END MAIN
