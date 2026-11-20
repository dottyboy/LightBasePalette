-- expect: 100
-- expect: 75.5
-- expect: 50
MAIN
  DEFINE a ARRAY[20] OF DECIMAL(10,2)
  DEFINE iznos, t DECIMAL(10,2)
  DEFINE n, i, j INTEGER
  DECLARE c CURSOR FOR SELECT iznos FROM racun
  LET n = 0
  FOREACH c INTO iznos
    LET n = n + 1
    LET a[n] = iznos
  END FOREACH
  FOR i = 1 TO n - 1
    FOR j = i + 1 TO n
      IF a[j] > a[i] THEN
        LET t = a[i]
        LET a[i] = a[j]
        LET a[j] = t
      END IF
    END FOR
  END FOR
  FOR i = 1 TO 3
    DISPLAY a[i]
  END FOR
END MAIN
