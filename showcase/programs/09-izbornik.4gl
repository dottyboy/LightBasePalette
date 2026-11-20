-- naziv: Izbornik s podizbornikom
-- opis: MENU, podizbornik kao funkcija (recept 11)
-- menu: Pregledi
-- menu: Broj računa
-- menu: Natrag
-- menu: Izlaz
-- expect: Računa: 600
MAIN
  MENU "Trgovina Jadran"
    COMMAND "Pregledi" "Brojevi u bazi"
      CALL pregledi()
    COMMAND "Izlaz" "Kraj"
      EXIT MENU
  END MENU
END MAIN

FUNCTION pregledi()
  DEFINE n INTEGER
  MENU "Pregledi"
    COMMAND "Broj računa" "Koliko ih ima"
      SELECT COUNT(*) INTO n FROM racuni
      DISPLAY "Računa: ", n
    COMMAND "Broj kupaca" "Koliko ih ima"
      SELECT COUNT(*) INTO n FROM partneri WHERE tip = 'Kupac'
      DISPLAY "Kupaca: ", n
    COMMAND "Natrag" "Povratak"
      EXIT MENU
  END MENU
END FUNCTION
