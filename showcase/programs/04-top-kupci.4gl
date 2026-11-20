-- naziv: Pet najvećih kupaca (polje u memoriji)
-- opis: polje i sortiranje u programu (recept 16), funkcija s više povratnih vrijednosti (recept 8)
-- expect: 1. Posavina market d.d.                    9,111.96
-- expect: 5. Kornat caffe j.d.o.o.                   4,911.87
MAIN
  DEFINE naz ARRAY[200] OF TEXT
  DEFINE zbr ARRAY[200] OF DECIMAL(12,2)
  DEFINE ime TEXT
  DEFINE iznos, t DECIMAL(12,2)
  DEFINE tn TEXT
  DEFINE n, i, j INTEGER
  DECLARE c CURSOR FOR
    SELECT p.naziv, ROUND(SUM(s.iznos), 2)
      FROM racuni r JOIN partneri p ON p.id = r.partner_id JOIN racuni_stavke s ON s.dokument_id = r.id
     GROUP BY p.id
  LET n = 0
  FOREACH c INTO ime, iznos
    LET n = n + 1
    LET naz[n] = ime
    LET zbr[n] = iznos
  END FOREACH
  FOR i = 1 TO 5
    FOR j = i + 1 TO n
      IF zbr[j] > zbr[i] THEN
        LET t = zbr[i]
        LET zbr[i] = zbr[j]
        LET zbr[j] = t
        LET tn = naz[i]
        LET naz[i] = naz[j]
        LET naz[j] = tn
      END IF
    END FOR
  END FOR
  FOR i = 1 TO 5
    DISPLAY i, ". ", RPad(naz[i], 36), LPad(zbr[i] USING "###,##0.00", 12)
  END FOR
END MAIN
