# Opis aplikacije: cijela aplikacija iz jedne tekstualne datoteke

Umjesto da se tablice, forme, izvješća i izbornik slažu čarobnjacima jedno po jedno, aplikacija se može **opisati u jednoj tekstualnoj datoteci** (`.opis`) i izraditi jednom naredbom. Alat pročita opis, provjeri ga (pogreške imaju broj retka) i izradi isto što bi izradili čarobnjaci. Što opis ne kaže, složi se samo: tablica bez forme dobije formu i popis, a aplikacija bez izbornika dobije bočni izbornik.

```
typhaccess --make-app=mali-obrt.opis MaliObrt.db
```

ili *Baza → Nova: aplikacija iz opisa…* (otvara se opis, pa se bira datoteka nove baze). Potpun primjer je `examples/aplikacije/mali-obrt.opis`: šifrarnici, objedinjena forma za ponude, otpremnice i reverse, izvješće, izbornik, prava i postavke.

Najmanji mogući opis su samo tablice:

```
tablica partneri "Partneri"
  naziv Text obavezno
  grad  Text
```

Iz toga nastaje tablica, forma *Partneri*, izvješće *Popis: Partneri* i izbornik s obje stavke. Ostalo se dodaje po potrebi.

## Pravila zapisa

* Odjeljak počinje u prvom stupcu (`tablica`, `forma`, `izvjesce`, `upit`, `izbornik`, `vrsta`, `prava`, `postavke`, `aplikacija`), a njegove retke uvlačiš razmacima.
* Redak koji počinje s `//` je komentar. Prazni retci se preskaču.
* Naziv s razmacima piše se u navodnicima: `forma "Računi po razdoblju"`. Dijakritici se u ključnim riječima ne razlikuju (`izvjesce` i `izvješće`).
* `svojstvo: vrijednost` je cijeli redak do kraja, pa vrijednost može imati razmake, zagrade i navodnike (izrazi).

## aplikacija

```
aplikacija "Mali obrt"
  naslov: Mali obrt d.o.o.       naslov prozora i izbornika
  pocetna: Izbornik              naziv izbornika (zadano Izbornik); postaje početna forma
  izbornik: bocni                bocni (zadano), gumbi ili glavna (predložak glavne forme)
```

## tablica

```
tablica artikli "Artikli" bezforme bezizvjesca
  sifra Text obavezno
  cijena Currency
    zadano: 0
    pravilo: [cijena] >= 0 | Cijena ne može biti negativna
    opis: Prodajna cijena bez PDV-a
  grupa_id Integer veza=grupe.id kaskada
```

* Polje: **naziv vrsta** uz oznake u istom retku. Vrste: `Text`, `Memo`, `Integer`, `Decimal` (uz broj decimala: `Decimal/4`), `Currency`, `YesNo`, `Date`, `Time`, `DateTime`, `Picture`; hrvatski nazivi `tekst`, `cijeli`, `decimalni`, `iznos`, `dane`, `datum`, `vrijeme`, `slika` rade isto.
* Oznake: `obavezno`, `kaskada` (brisanje uz vezu briše i podređene zapise), `veza=tablica.polje` (strani ključ, na formi postaje padajući popis), `zadano=vrijednost` (bez razmaka).
* Retci uvučeni dublje ispod polja daju svojstva: `zadano:` (izraz, npr. `Today()`), `pravilo: izraz | poruka` (provjera pri unosu), `opis:`.
* Polje `id` (AutoNumber, ključ) dodaje se samo ako ga ne navedeš.
* Oznake tablice: `bezforme` i `bezizvjesca` isključuju automatsku formu i popis. Tablice koje su **detalji** neke forme (vidi dolje) ih ionako ne dobivaju.
* Tablice se izrađuju redom prema vezama (najprije one na koje se veže), pa redoslijed u opisu nije bitan.

## forma

```
forma Dokument
  izvor: dokument                      tablica (zadano tablica istog naziva)
  naslov: Dokument
  raspored: dvastupca                  jedan | dvastupca | tablica | podijeljeno
  polja: broj, datum, partner_id       (zadano sva osim id)
  detalji: dokument_stavke(dokument_id)   podređene tablice, uz stupac veze
  zbroj: iznos                         zbroj stupca detalja (kad je jedan detalj)
  izracun: kolicina,cijena -> iznos = Zaokruzi([kolicina] * [cijena], 2)
  autofill: artikl_id>artikli.id:opis=naziv,cijena=cijena
  izracunato: Ukupno = Nz(DSum("iznos", "dokument_stavke", "dokument_id = " & [id]), 0)
  skupina: Skladišni dokumenti         skupina isključivosti (jedna otvorena u radnom prostoru)
  dokument: vrsta, broj                polje vrste i polje broja objedinjene forme
```

`izracun` i `autofill` vrijede za tablicu detalja (isti zapis kao u dizajneru); `izracunato` dodaje izračunata polja pri dnu forme (`Natpis = izraz | oblik`). Retke `izracun` i `izracunato` možeš ponoviti.

## izvjesce i upit

```
izvjesce "Artikli po cijeni"
  izvor: artikli                       tablica ili upit iz opisa
  vrsta: tablicno                      tablicno | stupcano | naljepnice | sazetak | grafikoni
  polja: sifra, naziv, jmj, cijena
  grupa: jmj
  poredak: cijena
  opadajuce: da
  zbrojevi: da
  sirine: sifra=60, naziv=200, cijena=70   sirine stupaca u tockama (nije obavezno)

upit "Neplaćeni računi"
  SELECT ... FROM racuni WHERE placeno = 0
```

Retci uvučeni ispod `upit` su SQL.

Širine stupaca tabličnog izvješća (`sirine:`) zadaju se u točkama, `polje=točke` odvojeno zarezom. Stupci koje ne navedeš dobivaju širinu prema zaglavlju i sadržaju (uzorak prvih 200 redaka za tekst; ako je tablica pri izradi prazna, tekst dobiva razumnu zadanu širinu), pa se cijeli redak prilagodi širini stranice: brojevi i datumi zadržavaju svoju širinu, a tekst dobiva ostatak. Prije su svi stupci dobivali istu širinu, pa se široka tablica izlazila iz stranice.

## program

```
program Poravnanje
  MAIN
    UPDATE listici SET status = 'LOST' WHERE ...
    DISPLAY "Gotovo"
  END MAIN

program Cjenik
  datoteka: cjenik.4gl
```

Spremi 4GL program u bazu (isto kao *Skripta → 4GL program…*), pa ga izbornik pokreće radnjom `program Poravnanje`. Tijelo je uvučeno ispod naslova: uvlaka prvog retka se skida, a uvlake unutar programa ostaju. Umjesto tijela može stajati jedan redak `datoteka: put.4gl`; put je relativan prema opisu pa program ostaje u svojoj datoteci, gdje ga uređuje uređivač teksta i provjerava `--check`. Datoteka se čita pri izradi, ne pri svakom pokretanju: nakon izmjene u njoj opis se mora ponovno primijeniti. Naziv programa mora biti jedinstven, a program bez teksta ili datoteka koje nema su pogreške s brojem retka.

## izbornik

```
izbornik
  # Dokumenti
  Ponude -> forma Dokument vrsta=ponuda
  Otpremnice -> forma Dokument vrsta=otp
  # Izvješća
  Artikli po cijeni -> izvjesce Artikli po cijeni
  Izlaz -> zatvori
```

`# Naslov` je skupina koja se sklapa. Radnje: `forma Naziv` (uz `vrsta=oznaka` za objedinjenu formu), `izvjesce Naziv`, `makro Naziv`, `program Naziv`, `zatvori`, ili izravno `openform:…`. Forma ili izvješće koje u opisu ne postoji, a ima isti naziv kao tablica (`forma Partneri`), znači automatsku formu te tablice, a `izvjesce Popis: Partneri` njezin popis.

## vrsta (objedinjeni dokumenti)

```
vrsta otp "Otpremnica" prefiks=otp srodne=rv oblik={sifra}-{godina}-{broj:4}
```

Upisuje vrstu u tablicu `dokumenti` (vidi poglavlje o formama, *Objedinjeni dokumenti*). `srodne` je popis vrsta koje ne smiju biti otvorene dok je ova otvorena; navedene vrste moraju biti opisane.

## prava i postavke

```
prava
  forma Postavke: admin
  izvjesce Artikli po cijeni: korisnik

postavke
  firma.naziv: Mali obrt d.o.o.
  firma.iban: HR1210010051863000160
```

Uloge su `pregled`, `korisnik` i `admin`. Za prava se navode forma, izvješće, makro ili upit. Postavke su ključevi iz *Podaci o tvrtki* i drugi ključevi aplikacije.

## Pogreške

Opis se provjerava prije izrade i ništa se ne izrađuje dok ima pogrešaka. Poruke imaju broj retka:

```
GREŠKA retak 12: nepoznata vrsta polja "Tekstic"
GREŠKA retak 15: veza vodi na nepoznatu tablicu "grupe"
GREŠKA retak 40: izbornik: nema forme "Ponude"
```

Provjeravaju se vrste polja, veze između tablica, nazivi polja u formama i izvješćima, detalji, radnje izbornika, srodne vrste i prava. Opis se smije primijeniti i na bazu koja već ima neke od tablica: postojeće se preskaču, a nove i objekti koji se mijenjaju izrađuju se iznova. Naredba `--make-app` **ne briše** postojeću bazu, nego opis primjenjuje na nju, pa se gotova baza s podacima može pretvoriti u aplikaciju. Izbornik *Baza → Nova: aplikacija iz opisa…* pita za prepisivanje i tada izrađuje potpuno novu bazu.

## Što opis (još) ne pokriva

Makroi, moduli, dopisi, korisnici i lozinke ne opisuju se ovom datotekom: dodaju se u dizajnerima ili čarobnjacima nakon izrade, a u izbornik se vežu radnjama `makro` i `program`. Korisnici se namjerno ne stavljaju u opis jer bi lozinke završile u datoteci koja se dijeli.


## Izvješće s grafikonima

Vrsta `grafikoni` slaže na jednu stranicu više grafikona, po dva u retku. Svaki je redak `grafikon: Naslov | tip | izvor`, gdje je tip `bar`, `line` ili `pie`, a izvor naziv upita iz opisa ili izravno `SELECT` s dva stupca (oznaka i vrijednost, do 40 redaka):

```
izvjesce "Pregled prodaje"
  vrsta: grafikoni
  naslov: Prodaja po mjesecima
  grafikon: Po mjesecima | bar | Prodaja po mjesecima
  grafikon: Trend | line | SELECT mjesec, iznos FROM prodaja ORDER BY mjesec
```

Izvor (`izvor:`) se ne piše. Do šest grafikona stane na jednu A4 stranicu.

## Kanban ploča

Forma s rasporedom `ploca` prikazuje retke tablice kao kartice po stupcima (npr. serije po fazama procesa):

```
forma "Ploča procesa"
  izvor: serije
  raspored: ploca
  ploca: faza_id | naziv | vrsta_id, pogon_id, datum_pocetka | Serije
```

Dijelovi retka `ploca:` odvojeni su znakom `|`: polje po kojem se prave stupci (mora imati vezu na šifrarnik), polje za naslov kartice, polja koja se ispisuju ispod naslova i, nije obavezno, forma u kojoj se kartica otvara dvoklikom. Povlačenje kartice u drugi stupac mijenja polje u bazi. Cjelovit primjer je `examples/aplikacije/procesi.opis`.

## Nadzorna ploča i raspored

Dvije forme prikazuju podatke vlastitim kontrolama: `raspored: nadzor` (kartica po skupini, redak po mjernoj vrijednosti, graf zadnjih vrijednosti, automatsko osvježavanje) i `raspored: crta` (tjedna vremenska crta s trakama po danima; povlačenjem se stvara, pomiče i produljuje, promjene se odmah upisuju). Postavka je u retku `nadzor:` odnosno `crta:`, a oblik je u `procesi.opis`. Uz njih ide most `procesi_most.py` koji prenosi vrijednosti i rasporede između MQTT-a i baze.
