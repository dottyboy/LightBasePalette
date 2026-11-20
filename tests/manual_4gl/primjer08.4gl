DATABASE northwind

SCREEN s_dostavljac
  TITLE "Dostavljač"
  LABEL "Šifra"   FIELD shipperid   READONLY
  LABEL "Naziv"   FIELD companyname REQUIRED UPSHIFT COMMENT "Ime tvrtke"
  LABEL "Telefon" FIELD phone       DEFAULT "000"
END SCREEN

MAIN
  DEFINE k RECORD LIKE shippers.*
  LET k.shipperid = 88
  INPUT BY NAME k.* FROM s_dostavljac
    AFTER FIELD companyname
      IF LENGTH(k.companyname) < 3 THEN
        ERROR "Naziv je prekratak"
        NEXT FIELD companyname
      END IF
  END INPUT
  IF NOT INT_FLAG THEN
    INSERT INTO shippers (shipperid, companyname, phone)
      VALUES ($k.shipperid, $k.companyname, $k.phone)
    DISPLAY "Spremljeno: ", k.companyname
  END IF
END MAIN
