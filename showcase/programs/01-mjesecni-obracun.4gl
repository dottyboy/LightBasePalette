-- naziv: Mjesečni obračun prodaje
-- opis: grupiranje u SQL-u, ukupno u programu (recept 9), poravnat ispis (recept 7)
-- expect: 2025-01         27      9,896.38    2,330.51
-- expect: Ukupno s PDV-om: 213,501.51
MAIN
  DEFINE mj TEXT
  DEFINE n INTEGER
  DEFINE osn, pdv, ukupno DECIMAL(12,2)
  DECLARE c CURSOR FOR
    SELECT strftime('%Y-%m', r.datum), COUNT(DISTINCT r.id), ROUND(SUM(s.iznos), 2), ROUND(SUM(s.iznos * s.pdv_stopa / 100.0), 2)
      FROM racuni r JOIN racuni_stavke s ON s.dokument_id = r.id
     GROUP BY 1 ORDER BY 1
  LET ukupno = 0
  DISPLAY RPad("Mjesec", 10), LPad("Računa", 8), LPad("Osnovica", 14), LPad("PDV", 12)
  FOREACH c INTO mj, n, osn, pdv
    DISPLAY RPad(mj, 10), LPad(n USING "####&", 8), LPad(osn USING "###,###,##0.00", 14), LPad(pdv USING "##,##0.00", 12)
    LET ukupno = ukupno + osn + pdv
  END FOREACH
  DISPLAY "Ukupno s PDV-om: ", ukupno USING "###,###,##0.00"
END MAIN
