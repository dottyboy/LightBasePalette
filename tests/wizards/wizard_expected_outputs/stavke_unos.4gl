-- 4GL skripta za unos u stavke
MAIN
  DEFINE r_stavke RECORD LIKE stavke.*

  CLEAR SCREEN
  DISPLAY "Unos stavki računa" AT 2, 2
  INPUT BY NAME r_stavke.artikal, r_stavke.kolicina, r_stavke.cijena WITHOUT DEFAULTS
    ON ACTION spremi
      INSERT INTO stavke VALUES (r_stavke.*)
      MESSAGE "Zapis je uspješno spremljen."
      EXIT INPUT
    ON ACTION odustani
      MESSAGE "Unos prekinut."
      EXIT INPUT
  END INPUT
END MAIN
