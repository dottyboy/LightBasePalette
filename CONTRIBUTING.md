# Doprinos

Projekt je u ranoj alpha fazi pa su najkorisnije **prijave grešaka s uputama za ponavljanje** i **prijedlozi** (obrasci u *Issues*).
Ako šalješ izmjenu koda:

* Izvor je u `src/` (jezgra bez sučelja u `src/core/`, forme u `src/gui/`, dijalozi u `src/editors/`), paketi u `lazarus/`.
* Prije prijedloga pokreni `tools/smoke.sh` (izgradi i pokrene testove; ispis `fails=0` je cilj) i, za promjene vlastitih kontrola, `tests/own/run.sh`
  (usporedba snimki zaslona; nove snimke `run.sh record` samo uz objašnjenje što se promijenilo).
* Imena u izvoru i sučelju pišu se engleski i prevode kroz `Tr(...)` (hrvatski prijevodi u `src/core/ta_i18n_hr_*.pas`); `python3 tools/i18n/check.py` mora javiti 0 neprevedenih.
* Uz novu mogućnost ide test (`tests/smoke.pas`) i redak u priručniku (`docs/manual/`); `tools/manual_src/build_manual.py` provjerava da se kod i priručnik ne razilaze.
* Licenca doprinosa je MIT kao i ostatak projekta.

Fiskalizacija nije dio ovog repozitorija i trenutno se ne prima.
