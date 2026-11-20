# Katalog shema

Svaka datoteka `*.json` opisuje jednu domenu (npr. `racuni`, `recepti`, `budzet`, `knjiznica`).
Program ih ugrađuje u izvršnu datoteku (`tools/gen_catalog.py` → `src/core/ta_catalogdata.pas`;
`tools/build.sh` to radi sam), a dodatne domene može učitati iz mape `catalog/` pokraj programa
ili iz mape u `TYPHACCESS_CATALOG` (ista `id` zamjenjuje ugrađenu domenu).

Što se dobije iz kataloga:
- **Baza → Nova: primjer-baza iz kataloga…** izrađuje tablice, veze, tipove polja, provjere,
  nekoliko redaka primjera, formu za svaku tablicu i popis za glavne tablice.
- **Nova tablica → Polje iz kataloga… / Tablica iz kataloga…** biraju se polja iz biblioteke:
  tip, format, zadana vrijednost, provjera, oznaka i opis postavljaju se sami.
- **Baza → Katalog shema: dokumentacija (HTML)…** (ili `TyphAccess --catalog-doc=datoteka.html`)
  ispisuje sva polja s tipom, ulogom, opisom i popisom mjesta na kojima se pojavljuju.

## Oblik datoteke

```json
{ "id": "racuni", "title": "Računi", "descr": "...", "tags": "posao,financije",
  "tables": [ {
    "name": "kupac", "caption": "Kupci", "descr": "...",
    "report": true, "report_group": "status", "report_sort": "datum",   // nepovezano: izvješće-popis
    "fields": [
      { "name": "sifra", "caption": "Šifra", "type": "autonumber", "role": "kljuc", "descr": "...", "pk": true },
      { "name": "kupac_id", "type": "integer", "role": "veza", "ref": "kupac.sifra", "on_delete": "cascade", ... },
      { "name": "status", "type": "text", "role": "status", "choices": "Otvoren,Plaćen", "default": "\"Otvoren\"" },
      { "name": "email", "type": "text", "role": "kontakt", "validation": "[value] Like \"*@*.*\"",
        "validation_msg": "...", "concept": "email", "width": 200, "decimals": 2, "format": "...", "required": true }
    ],
    "sample": [ [1, "Ana", ...], ... ]        // vrijednosti po redoslijedu polja; null = prazno
  } ] }
```

- **Tipovi:** `text memo integer decimal currency yesno date time datetime autonumber picture`.
- **Uloge** (obavezno, popis u `CatRoles`): `kljuc sifra naziv opis biljeska kategorija veza status oznaka
  kolicina cijena iznos postotak datum vrijeme kontakt adresa identifikator mjera slika redoslijed rezultat`.
- **Koncept:** polja s istim nazivom (ili istim `concept`) u više domena čine jedno polje biblioteke i moraju
  imati isti tip i ulogu (provjerava se). Ključevi i veze ne ulaze u biblioteku.
- **`choices`:** popis dopuštenih vrijednosti; ako nema `validation`, provjera `[value] In (...)` se izvodi sama.
- **Izrazi** (`default`, `validation`) koriste jezik izraza programa; vrijednost polja je `[value]`.
- Nazivi tablica i polja su `[a-z0-9_]` bez dijakritika; oznake (`caption`) i opisi su normalan hrvatski tekst.
- Provjera kataloga: `TestCatalog` u `tests/smoke.pas` (`ValidateCatalog`) — svako polje mora imati opis i
  ulogu, veze moraju postojati, primjeri moraju imati točan broj vrijednosti, izrazi se moraju prevesti.

## Rječnik postojeće tablice

*Tablica → Dopuni rječnik polja iz kataloga* (i kvačica pri uvozu u novu tablicu) puni oznaku, opis,
format, provjeru i širinu polja prema konceptu istog naziva; ne prepisuje ništa što je već upisano i ne
mijenja tip.

## Domena iz vlastite baze

*Baza → Katalog shema: snimka ove baze u domenu…* pravi JSON domene iz tablica otvorene baze
(tipovi, veze, rječnik polja, neobavezno prvih n redaka kao primjer). Uloge se pogađaju iz tipa i
naziva polja, pa ih treba pregledati; ako polje nema opis, upisuje se njegova oznaka. Rezultat je
obična datoteka domene: stavi je u `catalog/` pokraj programa.

## Kako se katalog održava

JSON datoteke su izvor istine; zgodno ih je uređivati ručno. Početni skup (42 domene) napisan je
skriptama u `tools/catalog_src/` (`mkcatalog5.py` pokreće sve pet redom i provjerava duljinu redaka primjera,
postojanje ciljeva veza i dosljednost koncepata) — korisne su kao predložak za nove domene, ali se
ponovnim pokretanjem prepisuju datoteke u `catalog/`, pa ručne izmjene JSON-a nemoj miješati sa skriptama.

Hrvatske poslovne domene (`racunovodstvo`, `pdv_knjige`, `place_hr`, `osnovna_sredstva`, `blagajna`, `obrt`,
`bankovni_izvodi`) su primjeri za učenje i polazna točka. Stope (PDV, doprinosi, porez, amortizacija), konta i
obrasci se mijenjaju propisima: provjeri ih kod računovođe prije stvarne uporabe. U `place_hr` stope su podaci
(tablica `porezna_stopa` s datumom važenja), a ne ugrađene u formule.
