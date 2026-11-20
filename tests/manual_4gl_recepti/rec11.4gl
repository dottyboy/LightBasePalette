-- menu: Izvješća
-- menu: Ukupno
-- menu: Natrag
-- menu: Izlaz
-- expect: Ukupno računa: 5
MAIN
  MENU "Glavni"
    COMMAND "Izvješća" "Pregledi"
      CALL izvjesca()
    COMMAND "Izlaz" "Kraj"
      EXIT MENU
  END MENU
END MAIN

FUNCTION izvjesca()
  DEFINE n INTEGER
  MENU "Izvješća"
    COMMAND "Ukupno" "Broj računa"
      SELECT COUNT(*) INTO n FROM racun
      DISPLAY "Ukupno računa: ", n
    COMMAND "Natrag" "Povratak"
      EXIT MENU
  END MENU
END FUNCTION
