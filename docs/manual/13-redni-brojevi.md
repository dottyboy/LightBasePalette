# Redni brojevi dokumenata: recepti

Svaki dokument (račun, otpremnica, revers…) treba broj kakav zahtijeva posao: na primjer `otp-2026-0007` (prefiks vrste, godina, redni broj), svaka vrsta s vlastitim brojačem, a brojač svake godine počinje iznova. Isto se može riješiti na više mjesta; ovo poglavlje pokazuje sve, s razlikama, da se izabere ono što pristaje aplikaciji.

Primjeri koriste tablicu brojača `dokumenti` (po jedan redak za svaku vrstu) i tablicu dokumenata `dokument`:

| `dokumenti` | |
|---|---|
| `vrsta` | oznaka vrste (`otp`, `rv`), ključ |
| `sifradok` | prefiks u broju (`otp`) |
| `rednidok` | zadnji dodijeljeni redni broj |
| `godina` | godina u kojoj je zadnji put dodijeljen (kad se promijeni, brojač kreće od 1) |

`dokument` ima `vrsta` i `broj` (uz ostala polja). Tablica `dokumenti` je ista ona koju koriste objedinjene forme (vidi poglavlje o formama, *Objedinjeni dokumenti*), pa se bilo koji od ovih recepata može koristiti umjesto ili uz ugrađeno rješenje.

## Što treba paziti

* **Rupe.** Broj se smije potrošiti tek kad je dokument stvarno spremljen. Predloženi broj na praznoj formi ne smije se „potrošiti”, a pri poništenom upisu broj se vraća (broj i upis moraju u istu transakciju).
* **Istodobnost.** Dva korisnika koja istodobno spremaju dokument iste vrste ne smiju dobiti isti broj. Najjednostavnije: brojač se povećava jednom naredbom `UPDATE` na retku vrste, koja redak zaključava do kraja transakcije.
* **Godina.** Brojač se vraća na 1 kad se godina promijeni (`CASE WHEN godina = tekuća THEN rednidok + 1 ELSE 1 END`).
* **Tko dodjeljuje.** Ako dokumente upisuje samo aplikacija, dovoljno je rješenje u aplikaciji (forma, makro, modul, 4GL). Ako se upisuje i iz uvoza, drugih programa ili ručno u bazu, broj treba dodijeliti **baza** (okidač).

## 1. Ugrađeno: objedinjena forma (preporučeno za nove aplikacije)

Forma s `DocTypeField` i `DocNumberField` sama predlaže broj iz `dokumenti` i pri spremanju stvarno dodjeljuje broj i upisuje novi zadnji broj. Ništa se ne programira; vrste se uređuju u *Aplikacija → Vrste dokumenata…*. Opis je u poglavlju o formama.

## 2. Zadani izraz polja (najjednostavnije, bez brojača)

U polju `broj` zadana vrijednost:

```
Format(Year(Today()), "0000") & "-" & Format(Nz(DMax("id", "racuni", ""), 0) + 1, "000")
```

Računi i ostali predlošci čarobnjaka tako dobivaju brojeve (`2026-014`). Rješenje je bez posebne tablice, ali broj prati `id` zapisa (ne vrstu ni godinu), pa nakon brisanja ostaju rupe, a brojač ne kreće iznova svake godine. Dobro za jednostavne popise, a za pravi poslovni dokument bolje je neko od ostalih rješenja.

## 3. Makro (blokovi)

Makro prvo povećava brojač, a zatim upisuje dokument s tim brojem. Isti se makro može staviti na gumb *Novi dokument* ili u izbornik:

Blokovi makroa, redom:

1. `sql`: `UPDATE dokumenti SET rednidok = CASE WHEN godina = CAST(strftime('%Y', 'now') AS INTEGER) THEN rednidok + 1 ELSE 1 END, godina = CAST(strftime('%Y', 'now') AS INTEGER) WHERE vrsta = 'otp'`
2. `sql`: `INSERT INTO dokument (vrsta, broj, datum) SELECT vrsta, sifradok || '-' || godina || '-' || printf('%04d', rednidok), date('now') FROM dokumenti WHERE vrsta = 'otp'`
3. `fetch`: `nid = SELECT MAX(id) FROM dokument`
4. `msg`: `Napravljen je dokument {nid}.`

Makro „Narudžbenica po minimumima” u primjeru *Trgovina Jadran 2* radi upravo to. Naredbe `sql` izvode se jedna za drugom, ali ne moraju biti jedna transakcija; kad treba i to, upotrijebi 4GL (sljedeći recept) ili okidač.

## 4. 4GL program

Cijeli posao u jednoj transakciji (`BEGIN WORK` … `COMMIT WORK`): vidi **recept 23** u poglavlju *4GL recepti*. Program je testiran nad pravim bazom i može se pozvati iz makroa (`run4gl`) ili s gumba.

## 5. Modul (PascalScript)

Funkcija koja dodjeljuje broj, pa se zove iz forme (događaj `BeforeUpdate` / `AfterUpdate`) ili iz makroa naredbom `run`:

```pascal
function DodijeliBroj(vrsta: string): string;
var
  g: Integer;
begin
  g := StrToInt(SqlValue('SELECT CAST(strftime(''%Y'', ''now'') AS INTEGER)'));
  SqlExec('UPDATE dokumenti SET rednidok = CASE WHEN godina = ' + IntToStr(g) + ' THEN rednidok + 1 ELSE 1 END, godina = ' +
    IntToStr(g) + ' WHERE vrsta = ''' + vrsta + '''');
  Result := SqlValue('SELECT sifradok || ''-'' || godina || ''-'' || printf(''%04d'', rednidok) FROM dokumenti WHERE vrsta = ''' + vrsta + '''');
end;
```

Poziv: `DodijeliBroj("otp")` u izrazu (npr. u makrou: `fetch: broj = ...`) ili iz drugog modula. **Pozor:** funkcija **troši broj** pri svakom pozivu, pa je ne stavljaj u zadanu vrijednost polja (ona se računa i kad se samo otvori nova forma) nego u događaj spremanja ili u radnju koja stvarno upisuje dokument.

## 6. Okidač u bazi (kad dokumente upisuje i netko drugi)

Okidač dodjeljuje broj pri svakom upisu u `dokument` kojem je `broj` prazan; ako je broj već zadan, ne dira ga (pa aplikacija i okidač mogu raditi zajedno). Upis i broj su u istoj transakciji: ako se upis poništi, vraća se i brojač.

**SQLite** (okidač `AFTER INSERT`, jer SQLite ne dopušta mijenjanje `NEW`):

```sql
CREATE TRIGGER dokument_broj AFTER INSERT ON dokument
WHEN NEW.broj IS NULL OR NEW.broj = ''
BEGIN
  UPDATE dokumenti
     SET rednidok = CASE WHEN godina = CAST(strftime('%Y', 'now') AS INTEGER) THEN rednidok + 1 ELSE 1 END,
         godina = CAST(strftime('%Y', 'now') AS INTEGER)
   WHERE vrsta = NEW.vrsta;
  UPDATE dokument
     SET broj = (SELECT sifradok || '-' || godina || '-' || printf('%04d', rednidok) FROM dokumenti WHERE vrsta = NEW.vrsta)
   WHERE id = NEW.id;
END;
```

**PostgreSQL** (funkcija i okidač `BEFORE INSERT`; `UPDATE … RETURNING` zaključava redak vrste pa se istodobni upisi poredaju):

```sql
CREATE OR REPLACE FUNCTION dokument_broj() RETURNS trigger AS $$
DECLARE
  r dokumenti%ROWTYPE;
BEGIN
  IF NEW.broj IS NULL OR NEW.broj = '' THEN
    UPDATE dokumenti
       SET rednidok = CASE WHEN godina = EXTRACT(YEAR FROM CURRENT_DATE)::int THEN rednidok + 1 ELSE 1 END,
           godina = EXTRACT(YEAR FROM CURRENT_DATE)::int
     WHERE vrsta = NEW.vrsta
    RETURNING * INTO r;
    NEW.broj := r.sifradok || '-' || r.godina || '-' || lpad(r.rednidok::text, 4, '0');
  END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

CREATE TRIGGER dokument_broj BEFORE INSERT ON dokument
  FOR EACH ROW EXECUTE FUNCTION dokument_broj();
```

**MariaDB / MySQL** (okidač `BEFORE INSERT`; u klijentu postavi `DELIMITER $$` jer tijelo sadrži `;`):

```sql
DELIMITER $$
CREATE TRIGGER dokument_broj BEFORE INSERT ON dokument FOR EACH ROW
BEGIN
  DECLARE b VARCHAR(60);
  IF NEW.broj IS NULL OR NEW.broj = '' THEN
    UPDATE dokumenti
       SET rednidok = IF(godina = YEAR(CURDATE()), rednidok + 1, 1),
           godina = YEAR(CURDATE())
     WHERE vrsta = NEW.vrsta;
    SELECT CONCAT(sifradok, '-', godina, '-', LPAD(rednidok, 4, '0')) INTO b FROM dokumenti WHERE vrsta = NEW.vrsta;
    SET NEW.broj = b;
  END IF;
END$$
DELIMITER ;
```

Sva tri su isprobana: dva upisa vrste `otp` daju `otp-2026-0001` i `otp-2026-0002`, vrsta `rv` s brojačem iz prošle godine počinje od `rv-2026-0001`, a upis s već zadanim brojem ostaje nedirnut.

Kad okidač dodjeljuje broj, **forma** ne smije sama dodjeljivati (inače se broj troši dvaput): na objedinjenoj formi ostavi `DocNumberField` prazno, pa forma neće predlagati ni dodjeljivati broj, nego će ga dodijeliti baza pri upisu.

### Samo broj, bez godine: niz (sequence)

Ako brojevi ne moraju biti bez rupa ni ponovno krenuti svake godine, PostgreSQL ima niz koji sve to radi sam:

```sql
CREATE SEQUENCE otp_niz;
ALTER TABLE dokument ALTER COLUMN broj SET DEFAULT 'otp-' || lpad(nextval('otp_niz')::text, 6, '0');
```

MariaDB ima `AUTO_INCREMENT` i nizove (`CREATE SEQUENCE`, `NEXTVAL`). Niz ne zaključava ništa i najbrži je, ali poništen upis ostavlja rupu u brojevima, što u računovodstvu često nije dopušteno.

## Usporedba

| Rješenje | Gdje se računa | Bez rupa | Istodobni korisnici | Godišnji reset | Radi i za uvoz i druge programe |
|---|---|---|---|---|---|
| Zadani izraz (`DMax`) | forma | ne | ne | ne | ne |
| Objedinjena forma | aplikacija | da (broj tek pri spremanju) | da | da | ne |
| Makro | aplikacija | uglavnom | da (`UPDATE` zaključava) | da | ne |
| 4GL | aplikacija | da (transakcija) | da | da | ne |
| Modul | aplikacija | uglavnom | da | da | ne |
| Okidač | baza | da | da | da | **da** |
| Niz (sequence) | baza | ne | da | ne | da |
