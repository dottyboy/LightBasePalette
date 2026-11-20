-- naziv: Računi u razdoblju iznad iznosa (PREPARE)
-- opis: upit s više parametara (recept 15), prekid petlje pragom (recept 20)
-- prompt: 2026-01-01
-- prompt: 2026-03-31
-- prompt: 300
-- expect: Računa od 2026-01-01 do 2026-03-31 iznad 300: 35
-- expect: Ukupno: 19,360.05
MAIN
  DEFINE od, do, minimum TEXT
  DEFINE n INTEGER
  DEFINE suma DECIMAL(14,2)
  PROMPT "Od datuma (gggg-mm-dd): " FOR od
  PROMPT "Do datuma: " FOR do
  PROMPT "Najmanji iznos s PDV-om: " FOR minimum
  PREPARE p FROM "SELECT COUNT(*), COALESCE(SUM(t.iznos), 0) FROM (SELECT r.id, SUM(s.iznos * (1 + s.pdv_stopa / 100.0)) AS iznos FROM racuni r JOIN racuni_stavke s ON s.dokument_id = r.id WHERE r.datum BETWEEN ? AND ? GROUP BY r.id HAVING SUM(s.iznos * (1 + s.pdv_stopa / 100.0)) >= CAST(? AS REAL)) t"
  DECLARE c CURSOR FOR p
  OPEN c USING od, do, minimum
  FETCH c INTO n, suma
  CLOSE c
  DISPLAY "Računa od ", od, " do ", do, " iznad ", minimum, ": ", n
  DISPLAY "Ukupno: ", suma USING "###,##0.00"
END MAIN
