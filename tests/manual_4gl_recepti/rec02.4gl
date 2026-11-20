-- prompt: Ana
-- expect: Ana duguje 50
MAIN
  DEFINE kupac TEXT
  DEFINE dug DECIMAL(10,2)
  PROMPT "Kupac: " FOR kupac
  SELECT SUM(iznos) INTO dug FROM racun WHERE kupac = $kupac AND placeno = 0
  DISPLAY kupac, " duguje ", NVL(dug, 0)
END MAIN
