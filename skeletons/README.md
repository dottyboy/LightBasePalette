# Kosturi 4GL programa (`.4glt`)

Kostur je 4GL tekst s **utorima** koji se popunjavaju iz baze. Dodaj svoj: stavi `.4glt` u ovu mapu (ili u mapu `skeletons/` uz bazu/program); pojavi se bez prevođenja.

```
@format 1
@kostur  Naziv kostura
@opis    Kratki opis
@kategorija  Popisi
@utor   tablica : tablica                           "Koja tablica?"
@utor   stupci  : stupci(tablica) zadano=sviOsimId   "Koji stupci?"
@preduvjet  tablica ima barem 2 stupca
@predlazi   tablica ima stupac tipa datum => preporuči
---
MAIN
  DEFINE r RECORD LIKE {tablica}.*
  ...
  DISPLAY {stupci:ispis}
END MAIN
```

**Vrste utora:** `tablica`, `stupac(t)`, `stupci(t)`, `stupac:broj(t)`, `stupac:datum(t)`, `stupac:tekst(t)`, `veza(detalj,glavna)`, `program`, `izvjesce`, `forma`, `tekst`, `broj`, `danet`, `izbor(a=oznaka;b=oznaka)`.

**Zadano (`zadano=`):** `sviOsimId`, `kljuc` (primarni ključ), `imaFk` (tablica sa stranim ključem), `ciljFk(utor)` (tablica na koju taj strani ključ pokazuje), doslovan tekst; u tekstu se mogu koristiti drugi utori kao `{utor}`.

**Zamjene u tijelu:** `{utor}`; `{stupci:lista}` (`a, b`), `:tablicno` (`t.a, t.b`), `:ispis` / `:ispis_g` / `:ispis_d` (`r.a, "  ", r.b` s predloškom r, g ili d), `:zapis` (`r.a, r.b`), `:postavi` (`a = $r.a, ...`), `:vrijednosti` (`$r.a, ...`), `:prvi`; za jedan stupac `{stupac:tip}` (4GL tip) i `:naslov`; za vezu `{veza}` (stupac detalja), `{veza:cilj}`, `{veza:ciljtip}`, `{veza:kolonatip}`.
**Petlja:** `@each c IN stupci` ... `@end` ponavlja retke za svaki stupac (`{c}`, `{c:tip}`, `{c:naslov}`).

Rezultat je običan 4GL program; provjeri ga `TyphAccess --check=program.4gl`.
