MAIN
  DEFINE postotak DECIMAL(5,2)
  PROMPT "Postotak poskupljenja: " FOR postotak
  IF NOT INT_FLAG THEN
    DISPLAY "Upisano: ", postotak
  END IF
END MAIN
