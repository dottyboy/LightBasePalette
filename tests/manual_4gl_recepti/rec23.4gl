-- expect: Dokument otp, redni broj 1
-- expect: Dokument otp, redni broj 2
-- expect: Dokument rv, redni broj 1
-- expect-sql: SELECT COUNT(*) FROM dokument WHERE broj = 'otp-' || strftime('%Y', 'now') || '-0002' => 1
-- expect-sql: SELECT rednidok FROM dokumenti WHERE vrsta = 'otp' => 2
MAIN
  CALL novi_dokument("otp")
  CALL novi_dokument("otp")
  CALL novi_dokument("rv")
END MAIN

FUNCTION novi_dokument(vrsta)
  DEFINE vrsta, broj TEXT
  DEFINE g, n INTEGER
  SELECT CAST(strftime('%Y', 'now') AS INTEGER) INTO g FROM dokumenti WHERE vrsta = $vrsta
  BEGIN WORK
  UPDATE dokumenti SET rednidok = CASE WHEN godina = $g THEN rednidok + 1 ELSE 1 END, godina = $g WHERE vrsta = $vrsta
  SELECT rednidok, sifradok || '-' || godina || '-' || printf('%04d', rednidok) INTO n, broj FROM dokumenti WHERE vrsta = $vrsta
  INSERT INTO dokument (vrsta, broj) VALUES ($vrsta, $broj)
  COMMIT WORK
  DISPLAY "Dokument ", vrsta, ", redni broj ", n
END FUNCTION
