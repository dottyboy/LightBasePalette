FUNCTION zbroji(a, b)
  DEFINE a, b INTEGER
  RETURN a + b, a * b
END FUNCTION

MAIN
  DEFINE s, p INTEGER
  CALL zbroji(3, 4) RETURNING s, p
  DISPLAY s, " ", p
  DISPLAY zbroji(1, 2)
END MAIN
