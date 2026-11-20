# Vodič kroz module (PascalScript)

Poglavlje *Makroi, događaji i moduli* navodi što je dostupno. Ovdje se modul uči na primjerima, od najmanjeg prema onima koji čitaju bazu i reagiraju na događaje u formi. Primjeri koriste tablice iz tutoriala (`kategorija` i `transakcija`), a svaki primjer sa završnim oznakama `// test:` provjerava se u testu programa: izraz s lijeve strane mora dati rezultat s desne.

## Kako se piše i pokreće modul

1. *Skripta → Novi modul…*, upiši naziv (npr. `Pomocne`) i kod.
2. Gumb **Provjeri** prevodi bez spremanja i javlja grešku s retkom i stupcem; **Spremi** sprema.
3. Modul sadrži samo procedure i funkcije. Program sam dodaje završni `begin end.`, a svi se moduli prevode zajedno.
4. Funkciju pozivaš iz **izraza** (`=Dvaput([iznos])` ili u zadanoj vrijednosti i provjeri), a proceduru iz **događaja** (`OnClick`, `OnCurrent`, `BeforeUpdate`…) ili iz makroa naredbom `run:Naziv`.

Jezik je Pascal: `begin … end`, `if … then … else`, `for … to … do`, `while`, `repeat … until`, `case`, `var` iznad `begin`. Tekst je u jednostrukim navodnicima, a jednostruki navodnik unutar teksta udvostručuje se (`'Ivan''s'`). Komentari su `// …` i `{ … }`. Pozivi iz izraza koriste dvostruke navodnike (`Pozdrav("Ana")`), a unutar modula jednostruke.

## 1. Prva funkcija

Funkcija vraća vrijednost preko `Result`. Pozovi je iz izraza jednako kao ugrađenu.

```pascal
// test: Dvaput(21) => 42
// test: Pozdrav("Ana") => Bok, Ana!
function Dvaput(x: Double): Double;
begin
  Result := x * 2;
end;

function Pozdrav(ime: string): string;
begin
  Result := 'Bok, ' + ime + '!';
end;
```

U formi stavi izračunatu kontrolu s izvorom `=Dvaput([iznos])`.

## 2. Petlje i varijable

Lokalne varijable navode se iznad `begin`.

```pascal
// test: Faktorijel(5) => 120
// test: ZbrojDo(10) => 55
// test: Fibonacci(10) => 55
function Faktorijel(n: Integer): Integer;
var
  i: Integer;
begin
  Result := 1;
  for i := 2 to n do
    Result := Result * i;
end;

function ZbrojDo(n: Integer): Integer;
var
  i: Integer;
begin
  i := 1;
  Result := 0;
  while i <= n do
  begin
    Result := Result + i;
    i := i + 1;
  end;
end;

function Fibonacci(n: Integer): Integer;
var
  a, b, t, i: Integer;
begin
  a := 0;
  b := 1;
  for i := 1 to n do
  begin
    t := a + b;
    a := b;
    b := t;
  end;
  Result := a;
end;
```

## 3. Rad s tekstom

Standardne funkcije za tekst rade kao u Pascalu: `Length`, `Copy`, `Pos`, `UpperCase`, `LowerCase`, `Trim`, `IntToStr`.

```pascal
// test: Inicijali("Ana Marija Horvat") => AMH
// test: Obrni("Zagreb") => bergaZ
// test: BrojRijeci("jedan dva tri") => 3
function Inicijali(s: string): string;
var
  i: Integer;
  novaRijec: Boolean;
begin
  Result := '';
  novaRijec := True;
  for i := 1 to Length(s) do
  begin
    if s[i] = ' ' then
      novaRijec := True
    else
    begin
      if novaRijec then
        Result := Result + UpperCase(s[i]);
      novaRijec := False;
    end;
  end;
end;

function Obrni(s: string): string;
var
  i: Integer;
begin
  Result := '';
  for i := Length(s) downto 1 do
    Result := Result + s[i];
end;

function BrojRijeci(s: string): Integer;
var
  i: Integer;
  uRijeci: Boolean;
begin
  Result := 0;
  uRijeci := False;
  for i := 1 to Length(s) do
  begin
    if s[i] <> ' ' then
    begin
      if not uRijeci then
        Result := Result + 1;
      uRijeci := True;
    end
    else
      uRijeci := False;
  end;
end;
```

## 4. Račun s rezultatom: kredit i zaokruživanje

Funkcije mogu pozivati jedna drugu. Ovdje pomoćna `Zaokruzi` služi izračunu mjesečne rate anuiteta.

```pascal
// test: Zaokruzi(2.3456, 2) => 2,35
// test: Rata(1000, 12, 12) => 88,85
function Zaokruzi(x: Double; decimale: Integer): Double;
var
  f: Double;
  i: Integer;
begin
  f := 1;
  for i := 1 to decimale do
    f := f * 10;
  Result := Round(x * f) / f;
end;

// glavnica, godišnja kamata u postocima, broj mjeseci
function Rata(glavnica, kamata: Double; mjeseci: Integer): Double;
var
  r, faktor: Double;
  i: Integer;
begin
  r := kamata / 12 / 100;
  faktor := 1;
  for i := 1 to mjeseci do
    faktor := faktor * (1 + r);
  Result := Zaokruzi(glavnica * r * faktor / (faktor - 1), 2);
end;
```

## 5. Čitanje baze

Za čitanje služe `DLookup`, `DCount`, `DSum` (kao u izrazima) i `SqlValue` za bilo koji upit koji vraća jednu vrijednost. Uvjet je tekst bez riječi `WHERE`.

```pascal
// test: Saldo() => 1364,5
// test: Potroseno("Hrana") => 105,5
// test: BrojTransakcija() => 4
function Saldo: Double;
begin
  Result := DSum('iznos', 'transakcija', '');
end;

function Potroseno(kategorija: string): Double;
begin
  Result := -DSum('iznos', 'transakcija',
    'kategorija_id = (SELECT id FROM kategorija WHERE naziv = ''' + kategorija + ''')');
end;

function BrojTransakcija: Integer;
begin
  Result := DCount('transakcija', '');
end;
```

U SQL-u koji slažeš od teksta udvostruči jednostruke navodnike u vrijednostima koje unosi korisnik (kao gore), inače upit puca na imenu s apostrofom.

## 6. Upit u jednoj naredbi

`SqlValue` izvede cijeli `SELECT` i vrati prvu vrijednost kao tekst.

```pascal
// test: NajveciTrosak() => -60
function NajveciTrosak: string;
begin
  Result := SqlValue('SELECT MIN(iznos) FROM transakcija');
end;
```

## 7. Mijenjanje podataka

`SqlExec` izvodi `INSERT`, `UPDATE` ili `DELETE` i vraća `True` ako je uspjelo. Ovakve procedure pokrećeš gumbom (`OnClick` = `run:Zaokruzi`) ili makroom, a ne iz izraza, jer izraz ne bi smio mijenjati podatke.

```pascal
procedure DodajKategoriju;
var
  naziv: string;
begin
  naziv := InputBox('Nova kategorija', 'Naziv:', '');
  if naziv = '' then
    Exit;
  if SqlValue('SELECT COUNT(*) FROM kategorija WHERE naziv = ''' + naziv + '''') <> '0' then
  begin
    ShowMessage('Kategorija već postoji.');
    Exit;
  end;
  SqlExec('INSERT INTO kategorija (naziv, vrsta) VALUES (''' + naziv + ''', ''Rashod'')');
  ShowMessage('Dodano: ' + naziv);
end;
```

## 8. Događaji u formi

Procedure bez parametara spajaš na događaje forme u dizajneru (svojstva `OnCurrent`, `BeforeUpdate`, `BeforeDelete`, `AfterUpdate`) ili na gumb (`OnClick` = `run:Naziv`). Vrijednosti kontrola čitaš s `GetValue` (tekst) i `GetNumber` (broj), a upisuješ s `SetValue` i `SetNumber`. Imena su imena **kontrola** u formi, ne nužno polja.

```pascal
// pozovi iz BeforeUpdate
procedure ProvjeriTransakciju;
begin
  if GetNumber('txtIznos') = 0 then
  begin
    ShowMessage('Iznos ne može biti nula.');
    FocusControl('txtIznos');
    CancelEvent;
  end;
end;

// pozovi iz OnCurrent: pokaži upozorenje samo za velike rashode
procedure PrikaziUpozorenje;
begin
  SetVisible('lblUpozorenje', GetNumber('txtIznos') < -1000);
end;

// pozovi iz BeforeDelete: pitaj prije brisanja
procedure PitajPrijeBrisanja;
begin
  if not Confirm('Stvarno obrisati transakciju?') then
    CancelEvent;
end;
```

`CancelEvent` ima učinka samo u događajima koji se mogu otkazati (`BeforeUpdate`, `BeforeDelete`, `OnClose`).

## 9. Poziv makroa i naredbi iz modula

`DoAction` izvodi bilo koju naredbu makroa. Naredbe koje djeluju na formu (`filter`, `nofilter`, `new`, `save`…) rade na formi iz koje je modul pozvan, a `openform`, `openreport`, `sql` i `msg` rade odasvud.

```pascal
// gumb na formi: prebacuje između svih transakcija i samo rashoda
procedure PrebaciRashode;
begin
  if Confirm('Prikazati samo rashode? (Ne = prikaži sve)') then
    DoAction('filter:iznos < 0')
  else
    DoAction('nofilter');
end;

procedure PregledMjeseca;
begin
  DoAction('openreport:Mjesecni@"datum >= ''2026-03-01''"');
end;
```

## Pogreške i otklanjanje

* **Greška pri spremanju:** javlja se kao `(redak:stupac) poruka`, redak je unutar modula. Najčešće: zaboravljeno `;`, nepoznato ime ili krivi tip (broj u tekst).
* **Pogreška pri izvođenju:** javlja se kao „Greška u skripti (Naziv): …”. Uzroci su obično dijeljenje nulom ili nepostojeća kontrola.
* **Nepoznata funkcija u izrazu:** modul se nije preveo (pogledaj Provjeri) ili naziv funkcije nije napisan isto.
* **Ispis međukoraka:** `ShowMessage(IntToStr(x))` u petlji dok tražiš grešku.
* Sporo? Funkcija u izračunatoj kontroli izvodi se za svaki redak. Čitanja baze unutar nje (`DSum`…) zato koristi štedljivo.
