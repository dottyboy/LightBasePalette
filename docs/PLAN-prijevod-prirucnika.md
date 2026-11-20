# Plan: engleski priručnik i katalozi (2026-11-11)

Sučelje je prevedeno (`Tr`, vidi `PLAN-rjecnik-okidaci.md` korak 0). **Priručnik i katalozi još nisu**: to je sadržaj, ne poruke,
i velik je.

## Opseg (izmjereno)
| Dio | Izvor | Veličina | Kako se koristi |
|---|---|---|---|
| Priručnik | `TyphAccess/docs/manual/*.md` (24 poglavlja) | ~39.700 riječi | `tools/manual_src/build_manual.py` → `docs/manual/html/prirucnik.html` → `tools/gen_manual.py` → `src/gui/ta_manualdata.pas` |
| Katalog domena | `TyphAccess/catalog/*.json` (43 domene) | ~33.300 riječi | `tools/gen_catalog.py` → `ta_catalogdata.pas`; nazivi tablica i polja, opisi, primjeri |
| Primjeri (Trgovina Jadran i dr.) | `tools/gen_showcase.py` | ~400 redaka podataka | `ta_showcase*.pas`; to su **podaci** (kupci, artikli) i ostaju hrvatski |
| Opisi funkcija u izrazima | `tools/manual_src/functions.py` | ~115 | već prevedeno u grafičaru (`ta_i18n_en`), priručnik ih još nema |
| Predlošci pisama | `ta_letter*`, `ta_offers` | ~60 redaka | ide u korisnikov dokument; treba izbor jezika pri generiranju |
Ukupno oko **73.000 riječi** (priručnik i katalog), za usporedbu: oko 25 stranica po 1000 riječi dnevno prijevoda s pregledom ≈ 70 radnih dana
ručno, ili 3-5 dana uz strojno nacrt i pregled po poglavlju.

## Pristup (kad se krene)
1. **Paralelno stablo** `docs/manual/en/*.md` (ista imena datoteka); `build_manual.py --lang en` gradi `prirucnik_en.html` iz `en/` uz
   **povratak na hrvatsko poglavlje** ako engleskog još nema, pa se može ići poglavlje po poglavlje.
2. `gen_manual.py` generira `ManualHtmlHr` i `ManualHtmlEn`; `ManualHtml` bira prema `UiLanguage`.
3. Provjere koje čitaju priručnik (`check_faq`, `check_controls`, izvedeni primjeri 4GL-a i PascalScripta) moraju raditi nad **oba** stabla;
   poglavlje 12 (poruke i pogreške) navodi tekst poruka iz koda, pa se njegov engleski naslov mora poklapati s engleskim izvornim `Tr` tekstom.
4. **Katalog:** `catalog/*.json` dobije polja `title_en`, `desc_en` (ili `en/` mapa); `gen_catalog.py` bira prema jeziku pri generiranju
   baze iz kataloga (nazivi tablica i polja ostaju kako jesu).
5. Redoslijed: `00-uvod`, `01-tutorial`, `12-poruke-faq`, `04-forme`, `04b-dizajneri`, pa ostalo; katalog posljednji.

## Zašto sada nije napravljeno
Nema smisla prevoditi pola priručnika bez promjene generatora i provjera (točke 1-3), a prijevod 73.000 riječi ne stane u jedan korak
rada bez pregleda. Prva etapa je infrastruktura (točke 1-3) + jedno poglavlje kao proba.
