# Veliki primjer: Trgovina Jadran

*Baza → Nova: veliki primjer Trgovina Jadran…* (ili u konzoli `TyphAccess --make-showcase TrgovinaJadran.db`) izgradi cijelu bazu veleprodajne tvrtke, u duhu Northwinda, ali hrvatsku i s tisućama zapisa. Podaci se generiraju uvijek isti (nema slučajnosti između pokretanja), pa se primjeri u priručniku i rezultati u testovima slažu s onim što vidiš.

Primjer služi kao **radni uzorak i zbirka trikova**: sve što priručnik opisuje na malim tablicama ovdje radi na stvarnoj količini podataka, a svaka stvar koja se može napraviti na više načina napravljena je na više načina (4GL, makro, modul).

## Što dobiješ

| Što | Koliko |
|---|---|
| Partneri (kupci i dobavljači, ispravni OIB i IBAN) | 145 |
| Artikli u 10 kategorija, s nabavnom cijenom, PDV 25, 13 i 5 % | 90 |
| Računi sa stavkama | 600, oko 2200 stavki |
| Ponude, narudžbenice, otpremnice, predračuni | 150, 120, 100, 60 |
| Skladišni dokumenti (primke, izdatnice, inventurna korekcija) | 417, oko 1500 stavki |
| Uplate po računima (i djelomične), blagajna, putni nalozi | oko 550, 260, 50 |
| Zaposlenici, ponude za posao, ugovori, aneks, troškovi ugovora | 16, 7, 5, 1, 7 |
| Upiti (parametarski, unija, unakrsni), izvješća (grafikoni, naljepnice, grupe), forme, dopisi | 27, 31, 16, 2 |
| Makroi (blokovi), PascalScript modul, 4GL programi u bazi, zadaci u planeru | 11, 1 (9 funkcija), 15, 4 |

Početna forma je **Izbornik** s gumbom za svaki dio.

## Kako je složeno

* **Predlošci** (*Aplikacija → Poslovni predlošci*): partneri, artikli, svih pet vrsta dokumenata sa stavkama, skladište, blagajna, zaposlenici, putni nalozi, ponude i ugovori. Svaki dokument ima ispis, a svaki ima i **pregled po razdoblju** (od–do).
* **Dodani stupci:** artikli imaju kategoriju, dobavljača i nabavnu cijenu (na formi je i *Marža %* izračunata funkcijom iz modula); računi imaju prodavača, način plaćanja i dostavu.
* **Forme:** *Kupac s računima* (master–detail), *Funkcije* (jedna funkcija po zapisu, s izračunatim rezultatom).
* **Izvješća:** *Pregled prodaje* ima tri grafikona; *Top kupci* ima stupac *Razred* koji računa funkcija iz modula; *Marža po artiklima* isto; *Naljepnice partnera* su postavljene za arak 63,5 × 38,1 mm, 3 × 7 (*Stranica i naljepnice…*), a *Naljepnice artikala* za 3 × 8 bez margina.
* **Upiti:** prodaja po kategoriji, mjesecu i prodavaču, najbolji kupci, neplaćeni računi s danima kašnjenja (`julianday`), računi i uplate (saldo), marža, *Računi kupca* s parametrom, unija kontakata, ugovori i troškovi, te **unakrsni** upit kategorije po mjesecima.
* **Dopisi:** *Opomena* (tablica neplaćenih računa po dužniku) i *Zahvalnica kupcu* (izraz u dopisu računa rabat iz prometa).
* **Revizijski trag** je uključen na partnere, artikle i račune.
* **Planer zadataka:** noćna kopija, mjesečni PDF, tjedni izvoz neplaćenih i dnevna provjera prekoračenja; isključeni su dok ih ne uključiš (*Aplikacija → Planer zadataka*). Zadaci rade bez korisnika: upiti s parametrima ne pitaju, a poruke makroa idu u rezultat zadatka.

## Formatirani tekst

Tablica `obavijesti` ima polje `tekst` u kojem je formatirani tekst (naslov u crvenom, podebljane riječi, natuknice, poravnanje). Forma *Obavijesti* ima kontrolu `RichText` s alatnom trakom, a izvješće *Obavijesti* ispisuje isti tekst s oblikovanjem; redak se produlji prema duljini teksta.

## Funkcije izraza kao zapisi

Tablica `primjeri_funkcija` sadrži svih 126 funkcija izraza (skupina, naziv, potpis, opis i primjer), a **rezultat računa sam program** izrazom `=Eval([primjer])`. Isto vidiš na formi *Funkcije* (jedna po zapisu) i u izvješću *Funkcije: živi primjeri*. Primjeri koji su u priručniku pisani za male tablice (`DSum`, `DLookup`, `PdvPoStopama`…) ovdje su prepisani na tablice ove baze.

## Modul `Poslovne_funkcije`

| Funkcija | Što radi | Gdje se koristi |
|---|---|---|
| `Marza(nabavna, prodajna)` | postotak marže | forma *Artikli*, izvješće *Marža po artiklima* |
| `RazredKupca(ukupno)` | Zlatni / Srebrni / Brončani / Redovni | izvješće *Top kupci*, 4GL program *Provjera OIB-a funkcijom iz modula* |
| `RabatPoKolicini(kol)` | stepenasti rabat | izrazi na formama i u izvješćima |
| `Kamata(osnovica, dani)` | zatezna kamata 12 % | izrazi, 4GL |
| `Zaokruzi5(x)` | zaokruživanje na 5 lipa | gotovinski iznosi |
| `OibIspravan(oib)` | provjera kontrolne znamenke | 4GL (`pas.OibIspravan(oib)`) |
| `SifraArtikla(naziv, n)` | šifra tipa `KAV-007` | izrazi |
| `ZabiljeziDnevnik`, `ZabiljeziZakljucak` | upis u tablicu `dnevnik` | makro *Zaključak mjeseca* (`run:`) |

Svaka funkcija ima redak `// test:` u kodu modula, a test programa ih provjerava.

## Makroi (blokovi)

*Sažetak neplaćenih*, *Povećaj cijene* (petlja `while`, pita i traži potvrdu), *Narudžbenica po minimumima* i *Račun iz ponude* (oba preko `copyrows`), *Dnevni izvještaji u PDF* (`exportpdf`), *Uvoz cjenika* (`importtable`), *Izvoz računa u Excel* (`exporttable`), *Opomena e-poštom* (`mailto`), *Zaključak mjeseca* (`run4gl`, `run`, `backup`), *Označi plaćenim* (gumb na formi) i *Provjera prekoračenja ugovora*.

## 4GL programi u bazi

Programi su u bazi (kartica **4GL**, izbornik *Skripta*: novi, uredi, pokreni, obriši; u uređivaču gumbi *Iz baze…* i *U bazu…*). Makro ih pokreće naredbom `run4gl: Naziv programa`. Svaki program je u priručniku već opisan kao recept; ovdje radi na pravim podacima, a test programa pokreće svaki na svježoj kopiji baze i provjerava retke `-- expect:` i `-- expect-sql:` iz njegova zaglavlja.

| Program | Recept / trik |
|---|---|
| Mjesečni obračun prodaje | 7 (poravnat ispis), 9 (grupiranje u SQL-u, zbroj u programu) |
| Novi račun sa sljedećim brojem | 5 (sljedeći broj dokumenta) |
| Zatezne kamate za neplaćene račune | 13 (datumi i rokovi), 19 (`CASE`) |
| Pet najvećih kupaca | 16 (polje u memoriji) |
| Artikli ispod minimalne zalihe | 18 (uvjet u upitu) |
| Poskupljenje kategorije za postotak | 4 (masovna izmjena), 6 (unos dok nije ispravan) |
| Brisanje kupca uz provjeru neplaćenih računa | 10 (pogreška baze), 22 |
| Arhiviranje starih plaćenih računa | 14 (kopiraj pa obriši, transakcija) |
| Izbornik s podizbornikom | 11 |
| Računi u razdoblju iznad iznosa | 15 (`PREPARE`), 20 |
| Cjenik po kategorijama (`REPORT`) | izvješće s grupama, ispis u datoteku |
| Provjera OIB-a funkcijom iz modula | 17 (poziv modula) |
| Šifre i natpisi artikala | 12 (rad s tekstom) |
| Prijenos dijela uplate na drugi račun | 3 (transakcija s poništavanjem) |
| Zbroj prodaje po prodavačima | 8 (funkcija s više povratnih vrijednosti) |

## Isprobaj

1. Otvori *Izbornik* → *Pregled prodaje (grafikoni)*.
2. *Računi* → *Pregled po razdoblju*: upiši Od i Do.
3. *Izvješća → Naljepnice partnera*: 21 naljepnica na listu. Postavke su u dizajneru (*Stranica i naljepnice…*).
4. Kartica *4GL* → dvoklik na *Pet najvećih kupaca*.
5. Izbornik → *Povećaj cijene*: upiši `abc`, pa `10`, pa potvrdi.
6. Izbornik → *Provjera prekoračenja ugovora*: javlja ugovor koji je prešao dopuštenu granicu.
7. Izbornik → *Funkcije: živi primjeri* i listaj funkcije.

Pokretanje svih programa i makroa, i izvješća s grafikonima, provjerava test programa (`TestShowcase`, `TestShowcasePrograms`).
