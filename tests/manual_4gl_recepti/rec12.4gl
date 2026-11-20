-- expect: IVO
-- expect: iv
-- expect: 3
-- expect: [   Ivo]
MAIN
  DEFINE ime TEXT
  LET ime = "  Ivo  "
  LET ime = Trim(ime)
  DISPLAY Upper(ime)
  DISPLAY Lower(Substr(ime, 1, 2))
  DISPLAY Length(ime)
  DISPLAY "[", LPad(ime, 6), "]"
END MAIN
