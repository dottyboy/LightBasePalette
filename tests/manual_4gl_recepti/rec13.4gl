-- expect: Dospijeće: 2026-03-16
-- expect: Dana kašnjenja: 20
MAIN
  DEFINE izdan, dospijece, danas DATE
  LET izdan = DateSerial(2026, 3, 1)
  LET dospijece = DateAdd("d", 15, izdan)
  LET danas = DateSerial(2026, 4, 5)
  DISPLAY "Dospijeće: ", Format(dospijece, "yyyy-mm-dd")
  DISPLAY "Dana kašnjenja: ", DateDiff("d", dospijece, danas)
END MAIN
