# Alat za prijevode (korak 0)

Izvorni jezik sucelja je engleski (`Tr('English')`), hrvatski je tablica prijevoda (`src/core/ta_i18n_hr_ui.pas`, generirana, plus rucna
`ta_i18n_hr.pas`). Alat prebacuje postojece hrvatske literale u pozivima sucelja (`Notify`, `AskRunner`, `ShowMessage`, `Caption :=`,
`Hint :=`, `TextHint :=`, `Lbl`, `InputBox`, `raise Exception.Create`) na `Tr('English')`.

1. `scan.py` trazi literale u tim pozivima (izlaz `/tmp/i18n/cand.json`), izdvoji jedinstvene u `uniq.json`.
2. Prijevod za svaki redni broj piše se u `trN.py` (rječnik `T = {id: 'English'}`); sto nije tekst sucelja (identifikatori, SQL) ne stavlja se.
3. `apply.py` zamijeni literale, doda `ta_i18n` u `uses` i generira `ta_i18n_hr_ui.pas` (engleski -> izvorni hrvatski tekst).
   Hrvatski prikaz ostaje **identican** prethodnom (prijevod je izvorni tekst), pa testovi ne ovise o jeziku.

Napomena: `apply.py` u ovom obliku radi nad `gui/` i `editors/` (`sel.json`); za druge mape treba prilagoditi odabir u `scan.py`/`apply.py`.
