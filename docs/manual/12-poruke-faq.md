# Poruke i pogreške (najčešća pitanja)

Poruke koje program prikazuje, što ih uzrokuje i što napraviti. Naslovi su točni tekstovi poruka iz programa (`…` je mjesto na kojem program upisuje naziv ili opis
pogreške); `build_manual.py` provjerava da svaki naslov postoji u izvornom kodu, pa popis ne može zastarjeti zbog preimenovane poruke.

## Odabir i otvaranje

### „Prvo otvori ili napravi bazu.”

Naredba traži otvorenu bazu, a nijedna nije otvorena. *Baza → Nova…* ili *Otvori…* (ili *Spoji na poslužitelj…*). Slične poruke: „Prvo otvori bazu.”.

### „Odaberi tablicu na kartici Tablice.”

Naredba iz izbornika djeluje na **označeni** objekt. Klikni naziv u popisu s lijeve strane (kartice *Tablice*, *Forme*, *Upiti*, *Izvješća*, *Makroi*, *Moduli*); program javlja
istu poruku za svaku vrstu objekta (npr. „Odaberi formu na kartici Forme.”).

### „Forma već postoji.”

Naziv je zauzet. Objekti svake vrste imaju jedinstvene nazive (isto za upit, izvješće, makro i modul). Izaberi drugi naziv ili prvo obriši stari objekt.

### „Neispravno ili već zauzeto ime.”

U dizajneru: naziv kontrole smije imati slova, znamenke i podvlaku, ne smije počinjati znamenkom i mora biti jedinstven na formi ili izvješću.

## Spremanje i podaci

### „Spremanje nije uspjelo: …”

Baza je odbila zapis; dio iza dvotočke je njezina poruka. Najčešće:

* `UNIQUE constraint failed: tablica.polje` — vrijednost već postoji u polju koje mora biti jedinstveno (npr. broj računa). Promijeni vrijednost.
* `FOREIGN KEY constraint failed` — polje-veza pokazuje na redak koji ne postoji. Odaberi postojeći zapis (ili prvo upiši roditeljski redak).
* `NOT NULL constraint failed: tablica.polje` — obavezno polje je prazno.
* Poruka s nazivom polja i vlastitim tekstom (npr. „kolicina: Količina mora biti veća od nule.”) dolazi iz **provjere unosa** polja; ispravi vrijednost.

### „Brisanje nije uspjelo: …”

Redak se ne smije obrisati dok ga drugi zapisi koriste (veza *Pri brisanju: RESTRICT* ili `NO ACTION`). Obriši ili premjesti zavisne retke, ili promijeni vezu u `CASCADE`/`SET NULL`
(*Baza → Relacije*).

### „Novi red nije moguć: …”

Dodavanje reda nije prošlo (obično nespremljen redak ne zadovoljava pravila). Spremi ili poništi trenutni redak pa ponovi.

### „Prvo spremi glavni zapis, pa dodaj stavke.”

Podforma (stavke) veže se na glavni zapis, koji još nije spremljen pa nema ključ. Spremi glavni zapis (gumb *Spremi*), pa dodaj stavke.

### „Filter: …”

Svojstvo `Filter` forme ili filter stupca u mreži nije ispravan SQL uvjet; dio iza dvotočke opisuje grešku. Provjeri nazive polja i navodnike (tekst u jednostrukim navodnicima).

## Izrazi, upiti, skripte

### „Izraz nije ispravan: …”

Izraz ne prolazi provjeru: pogrešan naziv polja (u uglatim zagradama), nezatvorena zagrada ili neispravan argument. Provjeri naziv polja i kopiraj primjer iz *Reference izraza*.

### „Nepoznata funkcija: …”

Naziv funkcije ne postoji (ili je pogrešno napisan). Funkcije iz modula postoje tek kad se modul prevede: pokreni **Provjeri** u uređivaču modula.

### „Greška u upitu: …”

SQL upita nije prošao na bazi; poruka baze je iza dvotočke. Pogledaj nazive tablica i polja; u upitu s parametrom `[?Naziv]` provjeri je li vrijednost upisana.

### „SQL nije uspio: …”

Ručno napisana SQL naredba nije prošla. Tekst SQL-a piše se u jednostrukim navodnicima; nazivi tablica i polja bez razmaka.

### „Skripta se ne prevodi: …”

Modul (PascalScript) ima grešku; redak i stupac su u poruci (redak se broji unutar modula). Ispravi grešku; dok se ne prevede, ne rade ni procedure ni funkcije iz izraza.

### „Greška u skripti (…): …”

Modul se preveo, ali je pao tijekom izvođenja (npr. dijeljenje nulom, kontrola koja ne postoji). U zagradi je naziv procedure.

## Prava i korisnici

### „Nemate pravo otvoriti …”

Uloga prijavljenog korisnika (`viewer`/`user`/`admin`) niža je od one koju zahtijevaju *Prava objekata* za taj objekt. Administrator ih mijenja u *Aplikacija → Prava objekata*.

### „Samo administrator može otvoriti dizajn.”

Dizajneri su samo za ulogu `admin`. Isto vrijedi za planer zadataka, revizijski trag i alate za podatke („… smije koristiti samo administrator.”).

### „Zadnji administrator se ne može obrisati.”

Da program ne ostane bez administratora. Prvo napravi drugog korisnika s ulogom `admin`.

### „Prvi korisnik postaje administrator; nakon toga se traži prijava.”

Dok korisnika nema, svi su administratori. Čim dodaš prvog, program traži prijavu pri svakom pokretanju; zapamti lozinku (nije je moguće vratiti, administrator može postaviti novu).

## Slike i datoteke

### „Ovo polje sprema sliku u bazu. …”

Staro polje tipa BLOB. Slike se danas čuvaju kao datoteke uz vezu u bazi: *Baza → Pohrana datoteka… → Pretvori slike iz baze*.

### „Slika nije spremljena: …”

Datoteka nije kopirana u mapu pohrane (nema dozvole, mapa ne postoji, nema mjesta). Provjeri mapu u *Baza → Pohrana datoteka…*; za poslužiteljske baze koristi dijeljenu mapu.

## Poslužitelji i prijenos

### „Spajanje nije uspjelo: …”

Adresa, port, naziv baze, korisnik ili lozinka nisu ispravni, ili poslužitelj ne radi. Provjeri iste podatke drugim alatom (`psql`, `mysql`); MariaDB mora raditi s `lower_case_table_names=1`.

### „Kopiranje nije uspjelo: …”

Kopiranje baze na poslužitelj nije završilo; odredišna baza mora biti **prazna**. Ako je zapisnik pun upozorenja o vezama, podaci krše strane ključeve: tablice se kopiraju, a veza se ne postavlja.

## Uvoz i izvoz

### „Uvoz nije uspio: …”

Datoteka se ne može pročitati ili tablica ne može nastati. Provjeri razdjelnik (*Automatski* obično radi) i kodiranje; XLSX/ODS čita samo prvi list.

### „Tablica … već postoji. Odaberi je pod "u postojeću" ili promijeni naziv.”

Uvoz u **novu** tablicu ne prepisuje postojeću. Odaberi tu tablicu u polju „u postojeću” ili upiši drugi naziv.

### „Izvoz nije uspio: …”

Izvor se ne može pročitati ili se datoteka ne može spremiti (nema dozvole, datoteka je otvorena u drugom programu).

