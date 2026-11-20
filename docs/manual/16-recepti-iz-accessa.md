# Recepti iz Accessa

Ovo poglavlje preslikava uobičajene Accessove VBA obrasce na ono što u TyphAccessu radi isto. Obrasci su uzeti iz stvarnog koda Access 97 aplikacija koje je uvoz izvukao (Northwind, Microsoftovi primjeri *Forms* i *Solutions*, uzorci s *The Access Web*; vidi *Uvoz iz Accessa*). Primjeri u PascalScriptu uz kvačicu `// test:` provjerava test programa. VBA se ne prevodi: za svaki obrazac je naveden TyphAccessov način, a gdje je prikladno i kratak modul u PascalScriptu.

| U Accessu (VBA) | U TyphAccessu |
|---|---|
| `IsLoaded("Forma")` prije `DoCmd.OpenForm` | ništa: svaka forma se otvara samo jednom, ponovno otvaranje prebacuje na karticu |
| uzajamno isključive forme (otpremnica / revers) | svojstvo forme **ExclusiveGroup** |
| `Form_BeforeUpdate` + `Cancel = True` + `MsgBox` | pravilo provjere polja, ili `BeforeUpdate` s `CancelEvent` |
| `Form_Error` (vlastita poruka za grešku baze) | poruke pogrešaka baze prikazuju se razumljivo, pravila imaju vlastitu poruku |
| `DoCmd.OpenForm "F", , , "uvjet"` | gumb `openform:F`; filtar se postavlja u formi (svojstvo forme) |
| `DoCmd.OpenForm "F", , , , acAdd, , OpenArgs` | podforma vezana na nadređeni zapis, ili modul s `SetValue` |
| dijalog s grupom opcija pa `Select Case` + `DoCmd.OpenReport` | upit s parametrom `[?...]` ili makro s izborom |
| `Report_NoData` (poruka i otkazivanje ispisa) | makro prije otvaranja provjeri `DCount` i javi poruku |
| `Detail_Format` (skrivanje zapisa) | uvjet (`WHERE`) u upitu na kojem se izvješće temelji |
| `Autoexec` makro i početna forma | prijava, glavni prozor i početna forma aplikacije |
| lista (ListBox) s `RowSource` zadanim u `;` | kontrole `ListBox`/`ComboBox` s izvorom iz tablice ili upita |
| `DLookup`, `DCount`, `DSum` | iste funkcije u izrazima i modulima |
| `AfterUpdate` s `DLookup` (cijena iz šifrarnika) | modul s `DLookup` i `SetValue` (recept 7) |
| `IsNull(...)` u `BeforeUpdate` (obavezno polje) | obavezno polje u tablici, ili modul s `CancelEvent` (recept 8) |
| `AutoFillNewRecord` (prepiši prethodni zapis) | `SqlValue` u `OnCurrent` (recept 9) |
| `NotInList` (nova stavka popisa) | modul s `Confirm` i `SqlExec` (recept 10) |
| tablica povijesti s bitmaskom promijenjenih polja | revizijski trag (recept 14) |
| upit s `[Unesi tekst]` | upit za vrijednost pri otvaranju (recept 15) |
| korisnička funkcija u upitu (`mycalculateage([DoB])`) | modul u PascalScriptu, funkcija se zove iz izraza `=Dob([datum], Today())` |

## 1. Jedna instanca forme i uzajamno isključive forme

Northwind ima `IsLoaded(strFormName)` koja pregleda otvorene forme prije otvaranja. U TyphAccessu to ne treba pisati: kartica forme već postoji pa otvaranje samo prebacuje na nju. Uzajamno isključive forme (primjerice otpremnica i revers) stavljaju se u istu **skupinu isključivosti**; poruka koja kaže što je već otvoreno dolazi sama (vidi *Forme*, *Aplikacija u radu*).

## 2. Provjera unosa prije spremanja

Primjer iz Northwinda (`Suppliers`): poštanski broj mora imati duljinu koja ovisi o državi.

```
Select Case Me!Country
  Case "France", "Italy", "Spain":  duljina mora biti 5
  Case "Australia", "Singapore":    duljina mora biti 4
  Case "Canada":                    oblik A1A 1A1
```

Najjednostavnije je **pravilo provjere polja** (izraz i poruka). Kad pravilo ovisi o drugom polju, ide u `BeforeUpdate` modula:

```pascal
function PostanskiBrojOk(drzava, broj: string): Boolean;
var
  n: Integer;
begin
  n := Length(broj);
  Result := True;
  if (drzava = 'France') or (drzava = 'Italy') or (drzava = 'Spain') then
    Result := n = 5
  else if (drzava = 'Australia') or (drzava = 'Singapore') then
    Result := n = 4;
end;

procedure ProvjeriPostanskiBroj;
begin
  if not PostanskiBrojOk(GetValue('Country'), GetValue('PostalCode')) then
  begin
    ShowMessage('Poštanski broj nije ispravne duljine za tu državu');
    FocusControl('PostalCode');
    CancelEvent;
  end;
end;
// test: PostanskiBrojOk("France", "75001") => Da
// test: PostanskiBrojOk("France", "7500") => Ne
// test: PostanskiBrojOk("Australia", "2000") => Da
// test: PostanskiBrojOk("Croatia", "10000") => Da
```

Uzorak (`Like "[A-Z][0-9][A-Z] [0-9][A-Z][0-9]"`) u izrazu pravila piše se s `Like`, jednako kao u Accessu.

## 3. Otvaranje druge forme s početnom vrijednošću

Access: `DoCmd.OpenForm "Products", , , , acAdd, , Me!SupplierID`, pa u otvorenoj formi `OpenArgs` upiše dobavljača. U TyphAccessu je za većinu slučajeva dovoljna **podforma** vezana na dobavljača (`LinkMaster`/`LinkChild`): novi zapis sam preuzima vrijednost veze. Za posebne slučajeve modul nakon otvaranja forme postavlja polje pozivom `SetValue`. Za dokumente s vrstom postoji `openform:Dokument#vrsta=otp` (vidi *Objedinjeni dokumenti*).

## 4. Dijalog za izvješće s grupom opcija

`Sales Reports Dialog` u Northwindu: grupa opcija bira izvješće, polja za datum daju razdoblje, a `Select Case` otvara jedno od izvješća. U TyphAccessu su dvije mogućnosti:

* **parametri upita**: izvješće nad upitom koji u uvjetu ima `[?Od]` i `[?Do]` samo pita za vrijednosti pri otvaranju (uvoz ovako preslikava reference na `[Forms]![Dijalog]![Polje]`);
* **makro** s izborom: `MENU` u 4GL-u ili `Confirm`/`InputBox` u modulu, pa `DoAction('openreport:Naziv')`.

## 5. Vlastita funkcija u upitu

Access dopušta da upit zove funkciju iz modula (`mycalculateage([DoB]) AS Age`). Takav upit uvoz ne prepisuje; u TyphAccessu se funkcija piše u modulu:

```pascal
function Dob(rodjen, na: string): Double;
begin
  { datumi su tekst oblika GGGG-MM-DD; godine razlike, bez dana u godini }
  Result := StrToNum(Copy(na, 1, 4)) - StrToNum(Copy(rodjen, 1, 4));
end;
// test: Dob("1980-05-17", "2026-11-05") => 46
```

a zatim zove iz izraza kontrole ili izvješća (`=Dob([DoB], Today())`). U samom upitu ista stvar piše se izrazom (`CAST(strftime('%Y','now') AS INTEGER) - CAST(strftime('%Y', DoB) AS INTEGER)`).

## 6. Pokretanje aplikacije

`Autoexec` makro i `Startup` iz Northwinda otvaraju prijavu, glavnu formu i sakrivaju prozor baze. U TyphAccessu to je ugrađeno: prijava, glavni prozor s bočnim izbornikom i kartice (vidi *Forme*). Što se pri pokretanju mora dogoditi još, ide u događaj `OnOpen` početne forme.

## 7. Cijena iz šifrarnika nakon odabira artikla

Najčešći obrazac stavki dokumenta (Northwind *Orders Subform*, primjer *Forms* iz Accessa 97): kad se odabere artikl, `AfterUpdate` upiše njegovu cijenu pomoću `DLookup`:

```
Me!UnitPrice = DLookup("UnitPrice", "Products", "ProductID = " & Me!ProductID)
```

U modulu je to isto, a funkciju koja traži vrijednost korisno je odvojiti da se može provjeriti. Primjer s tablicama iz tutoriala (kategorija → naziv):

```pascal
function NazivKategorije(id: string): string;
begin
  Result := DLookup('naziv', 'kategorija', 'id = ' + id);
end;

procedure NakonOdabiraKategorije;
begin
  SetValue('opis', NazivKategorije(GetValue('kategorija_id')));
end;
// test: NazivKategorije("1") => Hrana
// test: NazivKategorije("3") => Prijevoz
```

Procedura se postavlja kao događaj `AfterUpdate` kontrole (`macro:` s nazivom procedure). Kad se vrijednost uvijek mora povući iz šifrarnika, može se i izbjeći modul: polje stavke postaje **izračunato** iz veze, ili se cijena upisuje zadanom vrijednošću polja.

## 8. Obavezno polje prije napuštanja zapisa

Access *Sync Form* primjer: `BeforeUpdate` forme provjeri `IsNull(Me![ProductName])`, javi poruku i otkaže događaj; `Form_Error` prešuti Accessovu vlastitu grešku 3314 (vrijednost je obavezna). U TyphAccessu to je **obavezno polje** u tablici (poruku daje baza), a kad treba vlastita poruka, ide modul:

```pascal
function Prazno(v: string): Boolean;
begin
  Result := Trim(v) = '';
end;

procedure ProvjeriNaziv;
begin
  if Prazno(GetValue('naziv')) then
  begin
    ShowMessage('Naziv je obavezan prije nego napustiš zapis');
    FocusControl('naziv');
    CancelEvent;
  end;
end;
// test: Prazno("") => Da
// test: Prazno("  ") => Da
// test: Prazno("Hrana") => Ne
```

## 9. Novi zapis preuzima vrijednosti prethodnog

Access *Forms* primjer ima funkciju `AutoFillNewRecord`: na novom zapisu otvori kopiju skupa zapisa, ode na zadnji redak i prepiše navedena polja (`RS(C.ControlSource)`). Za unos serije sličnih zapisa (isti kupac, isti datum) to je velika ušteda. U TyphAccessu zadnja vrijednost čita se jednim SQL-om, pa se postavlja u `OnCurrent` novog zapisa:

```pascal
function ZadnjiOpis: string;
begin
  Result := SqlValue('SELECT opis FROM transakcija ORDER BY id DESC LIMIT 1');
end;

procedure PreuzmiOpis;
begin
  if GetValue('opis') = '' then SetValue('opis', ZadnjiOpis);
end;
// test: ZadnjiOpis() => Plac
```

Za jedno polje dovoljna je i **zadana vrijednost** polja tablice (izraz), ali ona ne može čitati zadnji zapis; zato je potreban `SqlValue`.

## 10. Vrijednost koje nema u popisu (NotInList)

Access *Solutions*, forma *Enter or Edit Products*: kad korisnik u padajući popis kategorije upiše naziv kojeg nema, događaj `NotInList` pita „Želiš li dodati novu kategoriju?“, po potrebi skrati naziv na 15 znakova, otvori formu za novu kategoriju i javi Accessu da je stavka dodana. U TyphAccessu isti tok je modul na događaju kontrole:

```pascal
function IdKategorije(naziv: string): string;
begin
  Result := SqlValue('SELECT id FROM kategorija WHERE naziv = ''' + naziv + '''');
end;

procedure KategorijaIzUnosa;
var
  naziv: string;
begin
  naziv := Copy(Trim(GetValue('kategorija_naziv')), 1, 15);
  if (naziv <> '') and (IdKategorije(naziv) = '') then
    if Confirm('Kategorije "' + naziv + '" nema. Dodati je?') then
      SqlExec('INSERT INTO kategorija (naziv, vrsta) VALUES (''' + naziv + ''', ''Rashod'')');
  SetValue('kategorija_id', IdKategorije(naziv));
end;
// test: IdKategorije("Hrana") => 1
// test: IdKategorije("Nema je") => 
```

Duljina naziva ograničava se kao u Accessu (`Left(NewData, 15)`), samo ovdje s `Copy`.

## 11. Provjera razdoblja u dijalogu za pretragu

Forma *Show Sales* provjeri da završni datum nije prije početnog (`If EndingDate < BeginningDate Then MsgBox ...`), pa tek onda slaže SQL (`WHERE Orders.ShippedDate Between ... And ...`) i ugrađuje ga u podformu. Datumi su u TyphAccessu tekst `GGGG-MM-DD`, pa se uspoređuju kao tekst; SQL ne treba slagati rukom jer upit s `[?Od]` i `[?Do]` pita za razdoblje sam:

```pascal
function RazdobljeOk(od, do_: string): Boolean;
begin
  Result := do_ >= od;
end;
// test: RazdobljeOk("2026-03-01", "2026-03-31") => Da
// test: RazdobljeOk("2026-03-31", "2026-03-01") => Ne
```

## 12. Ispravak unosa: prvo slovo veliko

Isto iz *Solutions*: `CapitalizeFirst` odreže razmake i prvo slovo učini velikim, ostatak ostavi kako je upisan. Poziva se u `AfterUpdate` polja.

```pascal
function PrvoVeliko(s: string): string;
begin
  s := Trim(s);
  Result := UpperCase(Copy(s, 1, 1)) + Copy(s, 2, Length(s));
end;
// test: PrvoVeliko("  hrana i piće ") => Hrana i piće
// test: PrvoVeliko("iPhone") => IPhone
```

## 13. Isti zapis u više prozora

*Solutions* ima i primjer s kolekcijom instanci forme *Customers* (jedna forma po kupcu, `New Form_Customers`). TyphAccess to **namjerno ne radi**: svaka forma je jedna kartica (vidi *Aplikacija u radu*), a drugi zapis otvara se kretanjem po zapisima ili filtrom. Isto vrijedi za sakrivanje ugrađenih alatnih traka (`DoCmd.ShowToolbar`), jer forme nemaju Accessove trake.

## 14. Povijest promjena zapisa

Primjer *History* (Dev Ashish i Terry Kreft, The Access Web) bilježi u zasebnu tablicu povijesti svaku promjenu klijenta: tko, kada i **koja su polja promijenjena**. Polja prati bitmaskom: svako polje ima potenciju broja 2 (`cvClientName = &H1`, `cvAccountBalance = &H2`, `cvAccountCurrent = &H4`), a `If (Ckval And Testval) Then` pretražuje koji su bitovi uključeni. U TyphAccessu to ne treba programirati: **revizijski trag** (*Aplikacija → Revizijski trag…*, poglavlje *Uvoz, izvoz, revizija, planer*) za odabrane tablice sam bilježi tko je, kada i što promijenio, i staru i novu vrijednost.

Ako ipak treba bitmaska (npr. uvezena povijest iz Accessa u kojoj je stupac `FieldsUpdated` zbroj bitova), čitanje je u modulu:

```pascal
function PromijenjenaPolja(maska: Integer): string;
var
  bit, i: Integer;
  imena: string;
begin
  imena := 'ClientName,AccountBalance,AccountCurrent';
  Result := '';
  bit := 1;
  for i := 1 to 3 do
  begin
    if (maska and bit) <> 0 then
    begin
      if Result <> '' then Result := Result + ', ';
      Result := Result + Trim(Copy(imena, 1, Pos(',', imena + ',') - 1));
    end;
    Delete(imena, 1, Pos(',', imena + ','));
    bit := bit * 2;
  end;
end;
// test: PromijenjenaPolja(5) => ClientName, AccountCurrent
// test: PromijenjenaPolja(2) => AccountBalance
// test: PromijenjenaPolja(0) => 
```

## 15. Pretraga unosom teksta u upitu

Upiti iz primjera *KB* (baza Microsoftovih članaka) i *Date* imaju uvjet koji sam traži vrijednost: `Like "*" & [Enter Text to Search for] & "*"`, ili `Like [Pay code or * for All]`. Access pri otvaranju upita pokaže okvir za unos. Uvoz takvu **neimenovanu zagradu** (naziv koji nije stupac) pretvara u upit za vrijednost pri otvaranju (`[?Enter Text to Search for]`), pa upit radi bez prepravka i pita korisnika kao u Accessu. Tekst se pritom slaže u SQL-u; ako u pretrazi treba `%` kao u `LIKE`, upiši ga u unos.

## 16. Što se ne isplati prenositi

* Pozivi Windows API-ja (`WinHelp`, `Declare Function ... Lib "user32.dll"`): nemaju značenje izvan Windowsa.
* `PivotTable` i OLE kontrole: slike se uvoze, ostalo ne.
* Ručno upravljanje popisom (`myAddItem`, `myRemoveItem` nad `RowSource` s `;` u Listbox primjeru): u TyphAccessu popis se puni iz tablice ili upita, pa se dodaje i briše redak u tablici, a popis se osvježi.
