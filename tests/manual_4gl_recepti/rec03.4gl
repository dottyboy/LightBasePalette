-- expect: Premješteno 4
-- expect: Nedovoljna zaliha, poništeno
-- expect-sql: SELECT zaliha FROM artikl WHERE id = 1 => 6
-- expect-sql: SELECT zaliha FROM artikl WHERE id = 2 => 4
MAIN
  CALL premjesti(1, 2, 4)
  CALL premjesti(1, 2, 20)
END MAIN

FUNCTION premjesti(od, prema, kol)
  DEFINE od, prema, kol, z INTEGER
  BEGIN WORK
  UPDATE artikl SET zaliha = zaliha - $kol WHERE id = $od
  UPDATE artikl SET zaliha = zaliha + $kol WHERE id = $prema
  SELECT zaliha INTO z FROM artikl WHERE id = $od
  IF z < 0 THEN
    ROLLBACK WORK
    DISPLAY "Nedovoljna zaliha, poništeno"
  ELSE
    COMMIT WORK
    DISPLAY "Premješteno ", kol
  END IF
END FUNCTION
