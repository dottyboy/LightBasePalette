-- naziv: Prijenos dijela uplate na drugi račun (transakcija)
-- opis: obje izmjene su jedna cjelina, ili prođu ili se poništavaju (recept 3)
-- expect: Preneseno 50.00
-- expect: Nedovoljno na uplati, poništeno
-- expect-sql: SELECT SUM(iznos) FROM uplate WHERE racun_id = 2 AND nacin = 'Prijenos' => 50
MAIN
  CALL prenesi(1, 2, 50)
  CALL prenesi(1, 2, 100000)
END MAIN

FUNCTION prenesi(od, prema, iznos)
  DEFINE od, prema INTEGER
  DEFINE iznos, ostalo DECIMAL(12,2)
  DEFINE n INTEGER
  SELECT COUNT(*) INTO n FROM uplate WHERE racun_id = $od
  IF n = 0 THEN
    INSERT INTO uplate (racun_id, datum, iznos, nacin) VALUES ($od, '2026-11-01', 200, 'Virman')
  END IF
  BEGIN WORK
  UPDATE uplate SET iznos = iznos - $iznos WHERE racun_id = $od
  INSERT INTO uplate (racun_id, datum, iznos, nacin) VALUES ($prema, '2026-11-04', $iznos, 'Prijenos')
  SELECT COALESCE(MIN(iznos), 0) INTO ostalo FROM uplate WHERE racun_id = $od
  IF ostalo <= 0 THEN
    ROLLBACK WORK
    DISPLAY "Nedovoljno na uplati, poništeno"
  ELSE
    COMMIT WORK
    DISPLAY "Preneseno ", iznos USING "###0.00"
  END IF
END FUNCTION
