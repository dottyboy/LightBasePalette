MAIN
  DEFINE n, zbroj INTEGER
  LET zbroj = 0
  FOR n = 1 TO 10
    IF n MOD 2 = 0 THEN
      LET zbroj = zbroj + n
    END IF
  END FOR
  WHILE zbroj > 20
    LET zbroj = zbroj - 10
  END WHILE
  CASE zbroj
    WHEN 0     DISPLAY "nula"
    WHEN 10    DISPLAY "deset"
    OTHERWISE  DISPLAY "ostalo: ", zbroj
  END CASE
END MAIN
