# LightPalette

Mala paleta univerzalnih kontrola za CodeTyphon/Lazarus i TyphAccess (17 obitelji s varijantama, jedinstvena tema, 4GL kao izvor podataka, kosturi, Light IDE).

- `docs/PLAN.md` je jedini plan (etape E0-E12); `docs/arhiva/` samo povijest; `docs/POPIS-KOMPONENTI.md` inventar komponenti.
- `lazarus/` paket palete (`typhaccess_dsgn`), registracija, ikone, demo `binderdemo`.
- `tests/jvspike/` probni projekt JVCL/RX na Qt6.

Izvorni kod jezgre je u `src/` ovog projekta; `../TyphAccess/src` je simbolička veza na njega.

Prevođenje paketa: `typhonbuild --pcp=$HOME/.typhon64 --ws=qt6 lazarus/typhaccess_dsgn.ctpkg`

**Izvor jezgre (od E0):** `src/` je ovdje jedina kopija. `../TyphAccess/src` je simbolička veza na ovu mapu, pa se TyphAccess i paleta prevode iz istog koda. Paketi su `../src/...`; razdvajanje na `typhaccess_core` / `typhaccess_editors` / `typhaccess_dsgn` još slijedi.

**Light profil CodeTyphona (E3):** `light/install_in_ide.sh` jednom (gradi IDE s našim paketima u `~/.typhon-light`), zatim `light/typhon-light.sh`. Vodič: `docs/PRVI-SAT.md`. Obični IDE se ne mijenja.
