-- naziv: Zatezne kamate za neplaćene račune
-- opis: datumi i rokovi (recept 13), CASE (recept 19), zbroj u programu
-- expect: Neplaćenih računa u kašnjenju: 34
-- expect: Od toga preko 90 dana: 16
-- expect: Obračunate kamate: 770.10
MAIN
  DEFINE broj TEXT
  DEFINE dospijece, danas DATE
  DEFINE osnovica, kamata, ukupno DECIMAL(12,2)
  DEFINE dani, n, kasni INTEGER
  LET danas = DateSerial(2026, 11, 4)
  LET ukupno = 0
  LET n = 0
  LET kasni = 0
  DECLARE c CURSOR FOR
    SELECT r.broj, r.dospijece, ROUND(SUM(s.iznos * (1 + s.pdv_stopa / 100.0)), 2)
      FROM racuni r JOIN racuni_stavke s ON s.dokument_id = r.id
     WHERE r.placeno = 0 AND r.dospijece < '2026-11-04'
     GROUP BY r.id ORDER BY r.dospijece
  FOREACH c INTO broj, dospijece, osnovica
    LET dani = DateDiff("d", dospijece, danas)
    CASE
      WHEN dani > 90
        LET kamata = ROUND(osnovica * 0.12 * dani / 365, 2)
        LET kasni = kasni + 1
      WHEN dani > 30
        LET kamata = ROUND(osnovica * 0.12 * dani / 365, 2)
      OTHERWISE
        LET kamata = 0
    END CASE
    LET ukupno = ukupno + kamata
    LET n = n + 1
  END FOREACH
  DISPLAY "Neplaćenih računa u kašnjenju: ", n
  DISPLAY "Od toga preko 90 dana: ", kasni
  DISPLAY "Obračunate kamate: ", ukupno USING "###,##0.00"
END MAIN
