# Izrazi

Izraz je kratka formula: `=[cijena] * [kolicina]`, `Iif([iznos] > 1000, "velika", "")`, `Format([datum], "dd.mm.yyyy")`. Izrazi se koriste svugdje gdje program traži izračun: izvor kontrole u formi i izvješću (s predznakom `=`), zadana vrijednost i provjera polja, uvjeti `VisibleIf`/`EnabledIf`, uvjeti u makroima (`if … then`), izračunata polja i pretvorba u SQL.

## Vrijednosti

| Vrsta | Pisanje | Napomena |
|---|---|---|
| Polje | `[naziv_polja]` | Vrijednost polja trenutnog retka. U provjeri polja trenutna vrijednost je `[value]`. |
| Tekst | `"tekst"` ili `'tekst'` | |
| Broj | `12`, `12.5` | Decimalna **točka** u izrazima (prikaz je uvijek hrvatski, `12,5`). |
| Datum | `#2026-01-31#` ili funkcija `DateSerial(2026,1,31)` | Tekst poput `"31.12.2026"` pretvara se kad treba. |
| Logička | `True`, `False` | Prikazuju se kao *Da* i *Ne*. |
| Prazno | `Null` | |

Posebne vrijednosti izvješća: `Page` (broj stranice) i `Pages` (broj stranica), te zbrojevi (`Sum([iznos])`, `Count`, `Avg`, `Min`, `Max`, `First`, `Last`, `StDev`, `Var`, `Median`, `SumAll`, `CountAll`, `AvgAll`, `RunSum`, `RunCount`, `RunGSum`).

## Operatori (od najslabijeg prema najjačem)

| Razina | Operatori |
|---|---|
| 1 | `Or` |
| 2 | `Xor` |
| 3 | `And` |
| 4 | `Not` |
| 5 | usporedbe `=` `<>` `<` `>` `<=` `>=`, `Like`, `Is Null`, `Is Not Null`, `Between a And b`, `In (a, b, c)` |
| 6 | `&` (spajanje teksta) |
| 7 | `+` `-` |
| 8 | `Mod` (ostatak pri dijeljenju) |
| 9 | `*` `/` `\` (cjelobrojno dijeljenje) |
| 10 | unarni `-` |
| 11 | `^` (potencija) |

Primjeri: `10 \ 3` = 3, `10 Mod 3` = 1, `2 ^ 10` = 1024, `5 / 2` = 2,5, `"a" & "b"` = ab, `"abc" Like "a*"` = Da (`*` je bilo koji niz, `?` jedan znak), `3 Between 1 And 5` = Da, `3 In (1, 2, 3)` = Da.

## Prazne vrijednosti

Prazna vrijednost (`Null`) prenosi se kroz račun i usporedbe: `1 + Null` je prazno, `Len(Null)` je prazno. Zato se u zbrojevima koristi `Nz`:

```
=Nz([popust], 0) + [iznos]
=Iif(IsNull([datum_vracanja]), "posuđeno", "vraćeno")
```

## Funkcije

Potpuni popis s opisom i primjerom je u **Referenci izraza**. Grupe: logika i provjere, tekst, brojevi i pretvorbe, datum i vrijeme, hrvatsko poslovanje (OIB, IBAN, iznos slovima, HUB-3, ZKI), zbrojevi nad tablicom (`DLookup`, `DCount`, `DSum`, `DAvg`, `DMin`, `DMax`) i sustav.

Vlastite funkcije pišeš u **modulu** i zoveš ih iz izraza: ako modul ima `function Dvaput(x: Double): Double;`, izraz je `=Dvaput([iznos])`.

## Zbrojevi nad tablicom (domenske funkcije)

`DLookup("naziv", "kupac", "sifra = 3")` traži vrijednost u drugoj tablici. Treći argument je SQL uvjet bez riječi WHERE; možeš ga sastaviti iz polja trenutnog retka:

```
=DLookup("naziv", "kategorija", "id = " & [kategorija_id])
=DSum("iznos", "transakcija", "kategorija_id = " & [id])
=DCount("*", "racun", "status_racuna = 'Otvoren'")
```

## Oblici (Format)

`Format(vrijednost, oblik)` prima uzorak ili ime:

| Uzorak | Primjer |
|---|---|
| `#,##0.00` | 1.234,50 |
| `0.0` | 12,3 |
| `dd.mm.yyyy` | 15.03.2026 |
| `dd.mm.yyyy hh:nn` | 15.03.2026 13:30 |
| `d. mmmm yyyy` | 15. ožujak 2026 |
| `>` / `<` | velika / mala slova |

Imena: `Currency` (1.234,50 €), `Fixed` (0.00), `Standard` (#,##0.00), `Percent` (0.256 → 25,60%), `Scientific`, `Short Date`, `Long Date`, `Short Time`, `Long Time`, `General Date`, `Yes/No` (Da/Ne), `True/False`, `On/Off`.

Isti oblici se upisuju u svojstvo **Format** kontrole ili polja.

## Izrazi i SQL

Izrazi u upitima, uvjetima i izračunatim poljima prevode se u SQL za bazu koja se koristi (SQLite, Postgres, MariaDB), pa se izračun izvodi na poslužitelju. Program provjerava da funkcija ima SQL ekvivalent i javlja „nepoznata funkcija” kad nema. Rezultati izraza prevedenih u SQL i izračunatih u programu slažu se na sva tri sustava (testira se na 60+ izraza).

## Provjera i poruke o greškama

Pogrešan izraz (nezatvorena zagrada, nepoznata funkcija) javlja se pri spremanju svojstva ili pri prvom izračunu; u izvješću je rezultat `#Err`. Dijalog izraza (*Izraz…* kod svojstava) nudi popis polja i funkcija i probno izvođenje.
