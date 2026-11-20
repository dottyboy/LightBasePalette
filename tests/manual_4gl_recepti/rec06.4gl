-- prompt: abc
-- prompt: -5
-- prompt: 12
-- expect: Prihvaćeno: 12
MAIN
  DEFINE s TEXT
  DEFINE kol INTEGER
  LET kol = 0
  WHILE kol <= 0
    PROMPT "Količina: " FOR s
    IF IsNumeric(s) THEN
      LET kol = s
    END IF
    IF kol <= 0 THEN
      DISPLAY "Unesi broj veći od nule"
    END IF
  END WHILE
  DISPLAY "Prihvaćeno: ", kol
END MAIN
