-- expect: najmanji=20 najveći=100
MAIN
  DEFINE a, b DECIMAL(10,2)
  CALL raspon() RETURNING a, b
  DISPLAY "najmanji=", a, " najveći=", b
END MAIN

FUNCTION raspon()
  DEFINE lo, hi DECIMAL(10,2)
  SELECT MIN(iznos), MAX(iznos) INTO lo, hi FROM racun
  RETURN lo, hi
END FUNCTION
