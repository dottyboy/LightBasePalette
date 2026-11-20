-- expect: Prag 150 prijeđen na računu 3, zbroj 180
MAIN
  DEFINE id INTEGER
  DEFINE iznos, zbroj DECIMAL(10,2)
  DEFINE gotovo INTEGER
  DECLARE c CURSOR FOR SELECT id, iznos FROM racun ORDER BY id
  OPEN c
  LET zbroj = 0
  LET gotovo = 0
  WHILE gotovo = 0
    FETCH c INTO id, iznos
    IF SQLCA.SQLCODE <> 0 THEN
      LET gotovo = 1
    ELSE
      LET zbroj = zbroj + iznos
      IF zbroj > 150 THEN
        DISPLAY "Prag 150 prijeđen na računu ", id, ", zbroj ", zbroj
        LET gotovo = 1
      END IF
    END IF
  END WHILE
  CLOSE c
END MAIN
