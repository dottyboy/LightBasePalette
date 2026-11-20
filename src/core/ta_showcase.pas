unit ta_showcase;
{ "Trgovina Jadran": jaca primjer baze (u duhu Northwinda) s tisucama zapisa.
  Slaze poslovne predloske (partneri, artikli, dokumenti sa stavkama, skladiste, blagajna, zaposlenici, putni nalozi,
  ponude i ugovori), puni ih podacima, a povrh toga dodaje upite, izvjesca, naljepnice, dopise, makroe (blokovi),
  PascalScript modul, 4GL programe u bazi, planer zadataka i primjere svih funkcija izraza.
  Podaci se generiraju deterministicki (isti rezultat svaki put). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ta_meta;

{ Gradi cijelu bazu u otvorenoj (praznoj) bazi. ALog dobiva sto je izradeno. }
function BuildShowcase(ADb: TAppDb; ALog: TStrings): Boolean;

{ generatori ispravnih identifikatora (i za testove) }
function ShowcaseOib(ASeed: Integer): string;
function ShowcaseIban(ASeed: Integer): string;

implementation

uses
  DateUtils, ta_types, ta_formdef, ta_reportdef, ta_wizardgen, ta_bizgen, ta_app, ta_crosstab, ta_audit,
  ta_blocks, ta_letter, ta_offers, ta_script, ta_tasks, ta_pagesetup, ta_switchgen, ta_showcasedata;

const
  FirstNames: array[0..29] of string = (
    'Ivan', 'Marko', 'Luka', 'Josip', 'Ante', 'Petar', 'Tomislav', 'Davor', 'Mario', 'Zoran',
    'Ana', 'Marija', 'Ivana', 'Petra', 'Katarina', 'Mateja', 'Maja', 'Tihana', 'Sanja', 'Nikolina',
    'Domagoj', 'Filip', 'Matej', 'Karlo', 'Dino', 'Lana', 'Iva', 'Dora', 'Lucija', 'Martina');
  LastNames: array[0..29] of string = (
    'Horvat', 'Kovačević', 'Babić', 'Marić', 'Novak', 'Jurić', 'Knežević', 'Vuković', 'Matić', 'Tomić',
    'Pavlović', 'Božić', 'Blažević', 'Grgić', 'Pavić', 'Radić', 'Perić', 'Šimić', 'Filipović', 'Lukić',
    'Barišić', 'Vidović', 'Petrović', 'Posavec', 'Kralj', 'Zorić', 'Mikulić', 'Bašić', 'Jukić', 'Galić');
  { grad|postanski|pozivni }
  Cities: array[0..24] of string = (
    'Zagreb|10000|01', 'Split|21000|021', 'Rijeka|51000|051', 'Osijek|31000|031', 'Zadar|23000|023',
    'Pula|52100|052', 'Slavonski Brod|35000|035', 'Karlovac|47000|047', 'Varaždin|42000|042', 'Šibenik|22000|022',
    'Dubrovnik|20000|020', 'Bjelovar|43000|043', 'Koprivnica|48000|048', 'Čakovec|40000|040', 'Vinkovci|32100|032',
    'Velika Gorica|10410|01', 'Sisak|44000|044', 'Požega|34000|034', 'Virovitica|33000|033', 'Makarska|21300|021',
    'Poreč|52440|052', 'Vukovar|32000|032', 'Gospić|53000|053', 'Knin|22300|022', 'Rovinj|52210|052');
  Streets: array[0..19] of string = (
    'Ilica', 'Vukovarska', 'Savska', 'Radnička cesta', 'Trg bana Jelačića', 'Kralja Tomislava', 'Zrinskog', 'Frankopanska',
    'Obala hrvatskog narodnog preporoda', 'Strossmayerova', 'Gundulićeva', 'Preradovićeva', 'Hrvatske bratske zajednice',
    'Matice hrvatske', 'Ulica Ante Starčevića', 'Put Supavla', 'Poljička cesta', 'Industrijska ulica', 'Lička ulica', 'Dalmatinska');
  Prefixes: array[0..19] of string = (
    'Adria', 'Jadran', 'Slavonija', 'Zagorje', 'Kvarner', 'Dalmacija', 'Istra', 'Lika', 'Podravina', 'Posavina',
    'Mediteran', 'Panonija', 'Velebit', 'Medvednica', 'Biokovo', 'Kornat', 'Brač', 'Hvar', 'Drava', 'Sava');
  Nouns: array[0..11] of string = (
    'trgovina', 'market', 'ugostiteljstvo', 'servis', 'promet', 'gradnja', 'turist', 'distribucija',
    'pekara', 'restoran', 'caffe', 'hotel');
  Legal: array[0..4] of string = ('d.o.o.', 'd.o.o.', 'j.d.o.o.', 'obrt', 'd.d.');

  { kategorija|opis }
  Categories: array[1..10] of string = (
    'Pića|Voda, sokovi, pivo i vino',
    'Kava i čaj|Mljevena i zrnata kava, čajevi',
    'Mliječni proizvodi|Mlijeko, sirevi, jogurti',
    'Slastice|Čokolade, keksi, bomboni',
    'Pekarski proizvodi|Kruh, peciva, brašno',
    'Meso i suhomesnato|Svježe i prerađeno meso',
    'Voće i povrće|Svježe i sušeno',
    'Riba|Svježa i konzervirana riba',
    'Kućanstvo|Sredstva za čišćenje i higijenu',
    'Uredski materijal|Papir, olovke, mape');

  { naziv|jmj|cijena|PDV; 9 po kategoriji, redom kategorija }
  Products: array[0..89] of string = (
    'Izvorska voda 1,5 l|kom|0.65|25', 'Gazirana voda 1 l|kom|0.80|25', 'Sok od naranče 1 l|kom|1.60|25', 'Sok od jabuke 1 l|kom|1.45|25',
    'Pivo svijetlo 0,5 l|kom|1.15|25', 'Pivo tamno 0,5 l|kom|1.30|25', 'Vino bijelo 0,75 l|kom|6.90|25', 'Vino crno 0,75 l|kom|7.40|25', 'Energetsko piće 0,25 l|kom|1.35|25',
    'Mljevena kava 250 g|kom|3.20|25', 'Mljevena kava 500 g|kom|6.10|25', 'Zrnata kava 1 kg|kom|12.50|25', 'Instant kava 100 g|kom|4.30|25', 'Crni čaj 20 vrećica|kom|1.80|25',
    'Zeleni čaj 20 vrećica|kom|2.10|25', 'Čaj od kamilice 20 vrećica|kom|1.70|25', 'Čaj od mente 20 vrećica|kom|1.70|25', 'Kapsule za kavu 10 kom|kom|3.90|25',
    'Mlijeko 1 l|kom|1.05|5', 'Mlijeko bez laktoze 1 l|kom|1.45|5', 'Jogurt 1 kg|kom|1.80|5', 'Vrhnje za kuhanje 200 ml|kom|1.15|13', 'Svježi sir 250 g|kom|1.60|13',
    'Sir gauda 300 g|kom|3.40|13', 'Sir trapist 1 kg|kg|9.80|13', 'Maslac 250 g|kom|2.60|13', 'Mozzarella 125 g|kom|1.20|13',
    'Mliječna čokolada 100 g|kom|1.10|25', 'Tamna čokolada 100 g|kom|1.35|25', 'Keksi maslac 400 g|kom|2.20|25', 'Napolitanke 330 g|kom|1.90|25', 'Bomboni mix 1 kg|kg|6.50|25',
    'Gumeni bomboni 200 g|kom|1.40|25', 'Čokoladni namaz 400 g|kom|3.60|25', 'Pita jabuka 500 g|kom|3.20|25', 'Piškote 200 g|kom|1.15|25',
    'Kruh bijeli 700 g|kom|1.25|5', 'Kruh integralni 500 g|kom|1.60|5', 'Pecivo kifla|kom|0.45|5', 'Pecivo štrukla 100 g|kom|1.10|5', 'Brašno glatko 1 kg|kom|0.95|5',
    'Brašno oštro 1 kg|kom|0.95|5', 'Tjestenina špageti 500 g|kom|1.30|5', 'Tjestenina fusilli 500 g|kom|1.30|5', 'Riža dugo zrno 1 kg|kom|2.10|5',
    'Pileća prsa|kg|7.80|25', 'Svinjski vrat|kg|6.90|25', 'Mljeveno miješano|kg|6.20|25', 'Pileći batak|kg|3.90|25', 'Pršut 100 g|kom|3.60|25',
    'Kulen 300 g|kom|8.90|25', 'Kobasice 400 g|kom|4.30|25', 'Šunka 100 g|kom|1.50|25', 'Slanina 200 g|kom|2.30|25',
    'Jabuke|kg|1.30|13', 'Banane|kg|1.60|13', 'Naranče|kg|1.50|13', 'Krumpir|kg|0.90|13', 'Luk|kg|0.85|13',
    'Rajčica|kg|2.40|13', 'Paprika|kg|2.80|13', 'Mrkva|kg|1.00|13', 'Suhe šljive 250 g|kom|2.20|13',
    'Srdele u ulju 125 g|kom|1.40|25', 'Tuna u ulju 160 g|kom|2.30|25', 'Oslić filet 400 g|kom|4.70|25', 'Lignje 500 g|kom|5.20|25', 'Brancin svježi|kg|13.50|25',
    'Dagnje 1 kg|kg|3.80|25', 'Pašteta od tune 95 g|kom|1.30|25', 'Bakalar suhi|kg|17.00|25', 'Skuša dimljena|kg|8.20|25',
    'Deterdžent za rublje 3 kg|kom|8.90|25', 'Sredstvo za posuđe 1 l|kom|2.20|25', 'Sredstvo za pod 1 l|kom|2.40|25', 'Toaletni papir 8 rola|kom|3.30|25', 'Papirnati ubrusi 2 rola|kom|1.60|25',
    'Vreće za smeće 35 l|kom|1.40|25', 'Spužve 5 kom|kom|1.20|25', 'Sapun tekući 500 ml|kom|1.90|25', 'Odmašćivač 750 ml|kom|2.80|25',
    'Papir A4 500 listova|kom|4.10|25', 'Kemijska olovka|kom|0.45|25', 'Mape s gumicom|kom|0.70|25', 'Registrator A4|kom|2.10|25', 'Samoljepljive bilješke|kom|1.20|25',
    'Toner crni|kom|38.00|25', 'Ljepilo u stiku|kom|0.90|25', 'Markeri 4 boje|kom|2.60|25', 'Spajalice 100 kom|kom|0.60|25');

const
  { "danas" za podatke: isti rezultat svaki put }
  RefDate = 46330;   { 2026-11-04 }

var
  Seed: Int64 = 20261104;

function Rnd(AMax: Integer): Integer;
begin
  if AMax <= 0 then Exit(0);
  Seed := (Seed * 1103515245 + 12345) mod 2147483648;
  Result := (Seed div 65536) mod AMax;
end;

function Q(ADb: TAppDb; const S: string): string;
begin
  Result := '''' + StringReplace(S, '''', '''''', [rfReplaceAll]) + '''';
end;

function IsoDate(ADt: TDateTime): string;
begin
  Result := FormatDateTime('yyyy-mm-dd', ADt);
end;

function Num(AValue: Double): string;
begin
  Result := FloatToStr(AValue, InvariantFS);
end;

function Part(const S: string; AIndex: Integer): string;
var
  I, P, Start: Integer;
begin
  Start := 1;
  for I := 0 to AIndex - 1 do
  begin
    P := Pos('|', Copy(S, Start, MaxInt));
    if P = 0 then Exit('');
    Inc(Start, P);
  end;
  P := Pos('|', Copy(S, Start, MaxInt));
  if P = 0 then Result := Copy(S, Start, MaxInt) else Result := Copy(S, Start, P - 1);
end;

{ poruke makroa pri izradi ne smiju otvarati dijaloge }
procedure QuietMessage(const AMsg: string);
begin
end;

{ ---------------- identifikatori ---------------- }

{ OIB: 10 znamenki + kontrolna (ISO 7064, MOD 11,10) }
function ShowcaseOib(ASeed: Integer): string;
var
  I, A, D: Integer;
  S: string;
  X: Int64;
begin
  X := 1000000000 + (Int64(ASeed) * 7919 + 12345) mod 8999999999;
  S := IntToStr(X);
  S := Copy(S, 1, 10);
  A := 10;
  for I := 1 to 10 do
  begin
    D := Ord(S[I]) - 48;
    A := (A + D) mod 10;
    if A = 0 then A := 10;
    A := (A * 2) mod 11;
  end;
  D := (11 - A) mod 10;
  Result := S + IntToStr(D);
end;

{ IBAN (HR): HRkk + 7 znamenki banke + 10 znamenki racuna; kontrolni brojevi po mod 97 }
function ShowcaseIban(ASeed: Integer): string;
const
  Banks: array[0..4] of string = ('1001005', '2360000', '2484008', '2340009', '2402006');
var
  Bban, Num2: string;
  I, R: Integer;
begin
  Bban := Banks[ASeed mod 5] + Format('%.10d', [1000000000 + (Int64(ASeed) * 104729 + 99991) mod 8000000000]);
  Num2 := Bban + '172700';
  R := 0;
  for I := 1 to Length(Num2) do R := (R * 10 + Ord(Num2[I]) - 48) mod 97;
  Result := 'HR' + Format('%.2d', [98 - R]) + Bban;
end;

{ ---------------- predlosci i dodatne tablice ---------------- }

procedure MakeStructure(ADb: TAppDb; ALog: TStrings);
var
  Doc: TStringList;
  I: Integer;
begin
  ADb.SaveSetting('firma.naziv', 'Trgovina Jadran d.o.o.');
  ADb.SaveSetting('firma.adresa', 'Vukovarska 12');
  ADb.SaveSetting('firma.mjesto', '10000 Zagreb');
  ADb.SaveSetting('firma.iban', ShowcaseIban(1));
  ADb.SaveSetting('firma.oib', ShowcaseOib(1));
  EnsureTable(ADb, ALog, 'kategorije', ['id|AutoNumber', 'naziv|Text|||R', 'opis|Memo']);
  ApplyBizTemplate(ADb, 'partneri', '', False, ALog);
  ApplyBizTemplate(ADb, 'artikli', '', False, ALog);
  { artikli: kategorija, dobavljac i nabavna cijena (marza) }
  ADb.Conn.ExecuteDirect('ALTER TABLE artikli ADD COLUMN kategorija_id INTEGER REFERENCES kategorije(id)');
  ADb.Conn.ExecuteDirect('ALTER TABLE artikli ADD COLUMN dobavljac_id INTEGER REFERENCES partneri(id)');
  ADb.Conn.ExecuteDirect('ALTER TABLE artikli ADD COLUMN nabavna_cijena NUMERIC DEFAULT 0');
  Doc := DocumentTypes;
  try
    for I := 0 to Doc.Count - 1 do ApplyBizTemplate(ADb, 'dokument', Doc[I], False, ALog);
  finally
    Doc.Free;
  end;
  ApplyBizTemplate(ADb, 'skladiste', '', False, ALog);
  ApplyBizTemplate(ADb, 'blagajna', '', False, ALog);
  ApplyBizTemplate(ADb, 'zaposlenici', '', False, ALog);
  ApplyBizTemplate(ADb, 'putni', '', False, ALog);
  ApplyBizTemplate(ADb, 'ponude_ugovori', '', False, ALog);
  { racuni: prodavac, nacin placanja i dostava; uplate po racunu }
  ADb.Conn.ExecuteDirect('ALTER TABLE racuni ADD COLUMN zaposlenik_id INTEGER REFERENCES zaposlenici(id)');
  ADb.Conn.ExecuteDirect('ALTER TABLE racuni ADD COLUMN nacin_placanja TEXT DEFAULT ''Virman''');
  ADb.Conn.ExecuteDirect('ALTER TABLE racuni ADD COLUMN dostava NUMERIC DEFAULT 0');
  EnsureTable(ADb, ALog, 'uplate', [
    'id|AutoNumber', 'racun_id|Integer||racuni.id|R', 'datum|Date|Today()||R', 'iznos|Currency|0', 'nacin|Text|''Virman''']);
  SetRule(ADb, 'uplate', 'iznos', '[iznos] > 0', 'Iznos uplate mora biti veći od nule.');
  EnsureTable(ADb, ALog, 'racuni_arhiva', [
    'id|AutoNumber', 'broj|Text', 'datum|Date', 'partner_id|Integer', 'iznos|Currency|0', 'arhivirano|Date|Today()']);
  EnsureTable(ADb, ALog, 'dnevnik', ['id|AutoNumber', 'vrijeme|Text', 'izvor|Text', 'poruka|Memo']);
  SetRule(ADb, 'artikli', 'cijena', '[cijena] >= 0', 'Cijena ne može biti negativna.');
end;

{ ---------------- podaci ---------------- }

function PartnerName(AIndex: Integer): string;
begin
  case AIndex mod 5 of
    3: Result := FirstNames[AIndex mod 30] + ' ' + LastNames[(AIndex * 7) mod 30] + ' obrt';
    4: Result := Prefixes[AIndex mod 20] + ' ' + Nouns[(AIndex * 5) mod 12] + ' d.d.';
  else
    Result := Prefixes[AIndex mod 20] + ' ' + Nouns[(AIndex * 3 + 1) mod 12] + ' ' + Legal[AIndex mod 3];
  end;
  Result := UpCase(Result[1]) + Copy(Result, 2, MaxInt);
end;

procedure FillPartners(ADb: TAppDb; ALog: TStrings);
var
  I, C: Integer;
  Cn, Pc, Pre, Nm, Tip, Mail: string;
  Used: TStringList;
begin
  Used := TStringList.Create;
  Used.Sorted := True;
  Used.Duplicates := dupIgnore;
  try
  for I := 1 to 145 do
  begin
    if I <= 25 then Tip := 'Dobavljač' else Tip := 'Kupac';
    Cn := Cities[(I * 7 + I div 3) mod 25];
    C := (I * 7 + I div 3) mod 25;
    Pc := Part(Cities[C], 1);
    Pre := Part(Cities[C], 2);
    Nm := PartnerName(I + (I mod 2) * 40 + 3);
    if I <= 25 then Nm := Prefixes[(I * 3) mod 20] + ' ' + Part('Veleprodaja|Distribucija|Import|Proizvodnja|Logistika', I mod 5) + ' ' + Legal[I mod 2];
    if Used.IndexOf(Nm) >= 0 then Nm := Nm + ' ' + Part(Cn, 0);
    if Used.IndexOf(Nm) >= 0 then Nm := Nm + ' ' + IntToStr(I);
    Used.Add(Nm);
    Mail := LowerCase(StringReplace(StringReplace(Nm, ' ', '.', [rfReplaceAll]), '.d.o.o.', '', []));
    Mail := StringReplace(StringReplace(StringReplace(StringReplace(Mail, 'š', 's', [rfReplaceAll]), 'č', 'c', [rfReplaceAll]), 'ć', 'c', [rfReplaceAll]), 'ž', 'z', [rfReplaceAll]);
    Exec(ADb, 'INSERT INTO partneri (naziv, tip, oib, adresa, postanski, grad, drzava, telefon, email, iban, aktivan) VALUES (' +
      Q(ADb, Nm) + ', ' + Q(ADb, Tip) + ', ' + Q(ADb, ShowcaseOib(I)) + ', ' + Q(ADb, Streets[(I * 3) mod 20] + ' ' + IntToStr(1 + (I * 11) mod 90)) + ', ' +
      Q(ADb, Pc) + ', ' + Q(ADb, Part(Cn, 0)) + ', ''Hrvatska'', ' + Q(ADb, Pre + ' ' + IntToStr(200 + (I * 37) mod 700) + ' ' + IntToStr(1000 + (I * 91) mod 8999)) + ', ' +
      Q(ADb, 'info@' + StringReplace(Copy(Mail, 1, 24), '..', '.', [rfReplaceAll]) + '.hr') + ', ' + Q(ADb, ShowcaseIban(I + 10)) + ', ' +
      IntToStr(Ord((I mod 17) <> 0)) + ')');
  end;
  finally
    Used.Free;
  end;
  ALog.Add('upisano partnera: 25 dobavljača i 120 kupaca (ispravni OIB i IBAN)');
end;

procedure FillCategoriesAndArticles(ADb: TAppDb; ALog: TStrings);
var
  I, K: Integer;
  Price, Cost: Double;
begin
  for I := 1 to 10 do
    Exec(ADb, 'INSERT INTO kategorije (id, naziv, opis) VALUES (' + IntToStr(I) + ', ' + Q(ADb, Part(Categories[I], 0)) + ', ' + Q(ADb, Part(Categories[I], 1)) + ')');
  for I := 0 to 89 do
  begin
    K := I div 9 + 1;
    Price := StrToFloat(Part(Products[I], 2), InvariantFS);
    Cost := Round(Price * (0.62 + Rnd(15) / 100) * 100) / 100;
    Exec(ADb, 'INSERT INTO artikli (sifra, naziv, jmj, cijena, pdv_stopa, min_zaliha, aktivan, kategorija_id, dobavljac_id, nabavna_cijena) VALUES (' +
      Q(ADb, Format('A%.3d', [I + 1])) + ', ' + Q(ADb, Part(Products[I], 0)) + ', ' + Q(ADb, Part(Products[I], 1)) + ', ' + Part(Products[I], 2) + ', ' +
      Part(Products[I], 3) + ', ' + IntToStr(20 + Rnd(10) * 10) + ', ' + IntToStr(Ord((I mod 23) <> 0)) + ', ' + IntToStr(K) + ', ' +
      IntToStr(1 + (I * 5) mod 25) + ', ' + Num(Cost) + ')');
  end;
  ALog.Add('upisano: 10 kategorija i 90 artikala (PDV 25, 13 i 5 %)');
end;

procedure FillEmployees(ADb: TAppDb; ALog: TStrings);
const
  Jobs: array[0..7] of string = ('Voditelj prodaje|Prodaja', 'Prodavač|Prodaja', 'Komercijalist|Prodaja', 'Skladištar|Skladište',
    'Vozač|Skladište', 'Knjigovođa|Financije', 'Administrator|Uprava', 'Direktor|Uprava');
var
  I: Integer;
  Job: string;
  Born, Hired: TDateTime;
begin
  for I := 1 to 16 do
  begin
    Job := Jobs[(I - 1) mod 8];
    Born := EncodeDate(1965 + Rnd(35), 1 + Rnd(12), 1 + Rnd(28));
    Hired := EncodeDate(2008 + Rnd(17), 1 + Rnd(12), 1 + Rnd(28));
    Exec(ADb, 'INSERT INTO zaposlenici (ime, prezime, oib, datum_rodjenja, datum_zaposlenja, radno_mjesto, odjel, placa, email, telefon, aktivan) VALUES (' +
      Q(ADb, FirstNames[(I * 4) mod 30]) + ', ' + Q(ADb, LastNames[(I * 3) mod 30]) + ', ' + Q(ADb, ShowcaseOib(900 + I)) + ', ' +
      Q(ADb, IsoDate(Born)) + ', ' + Q(ADb, IsoDate(Hired)) + ', ' + Q(ADb, Part(Job, 0)) + ', ' + Q(ADb, Part(Job, 1)) + ', ' +
      Num(1100 + Rnd(2200)) + ', ' + Q(ADb, 'z' + IntToStr(I) + '@jadran.hr') + ', ' + Q(ADb, '091 ' + IntToStr(100 + I * 13) + ' ' + IntToStr(1000 + I * 77)) + ', 1)');
  end;
  ALog.Add('upisano zaposlenika: 16');
end;

{ jedna vrsta dokumenta: zaglavlja + stavke }
procedure FillDocuments(ADb: TAppDb; const ATable, AStatus: string; ACount, AVendorMode: Integer; ABase: TDateTime;
  ADays: Integer; ALog: TStrings);
var
  N, J, Partner, Lines, Art, Cnt, Seq, Yr, LastYr: Integer;
  D, Due: TDateTime;
  Price, Qty, Rabat, Amount: Double;
  Paid, Tip, Broj, Jmj: string;
  Used: array[0..89] of Boolean;
  Items: string;
begin
  Items := ATable + '_stavke';
  Seq := 0; LastYr := 0; Cnt := 0;
  ADb.Conn.StartTransaction;
  try
    for N := 1 to ACount do
    begin
      D := ABase + (N - 1) * ADays / ACount + Rnd(2);
      Yr := YearOf(D);
      if Yr <> LastYr then begin Seq := 0; LastYr := Yr; end;
      Inc(Seq);
      Broj := Format('%d-%.3d', [Yr, Seq]);
      { kupci su 26..145, dobavljaci 1..25; blaga skewed prema prvim kupcima }
      if AVendorMode = 1 then Partner := 1 + Rnd(25)
      else Partner := 26 + Rnd(1 + Rnd(120));
      Due := D + 15 + 15 * Rnd(2);
      if D < RefDate - 60 then Paid := IntToStr(Ord(Rnd(100) < 96))
      else if D < RefDate - 20 then Paid := IntToStr(Ord(Rnd(100) < 60))
      else Paid := IntToStr(Ord(Rnd(100) < 25));
      if ATable = 'racuni' then
        Exec(ADb, 'INSERT INTO racuni (id, broj, datum, dospijece, partner_id, placeno, zaposlenik_id, nacin_placanja, dostava) VALUES (' +
          IntToStr(N) + ', ' + Q(ADb, Broj) + ', ' + Q(ADb, IsoDate(D)) + ', ' + Q(ADb, IsoDate(Due)) + ', ' + IntToStr(Partner) + ', ' + Paid + ', ' +
          IntToStr(1 + Rnd(16)) + ', ' + Q(ADb, Part('Virman|Kartica|Gotovina|Virman|Virman', Rnd(5))) + ', ' + Num(Rnd(4) * 3.5) + ')')
      else
        Exec(ADb, 'INSERT INTO ' + ATable + ' (id, broj, datum, dospijece, partner_id, ' + AStatus + ') VALUES (' +
          IntToStr(N) + ', ' + Q(ADb, Broj) + ', ' + Q(ADb, IsoDate(D)) + ', ' + Q(ADb, IsoDate(Due)) + ', ' + IntToStr(Partner) + ', ' + Paid + ')');
      Lines := 1 + Rnd(6);
      FillChar(Used, SizeOf(Used), 0);
      for J := 1 to Lines do
      begin
        repeat Art := Rnd(90); until not Used[Art];
        Used[Art] := True;
        Price := StrToFloat(Part(Products[Art], 2), InvariantFS);
        Jmj := Part(Products[Art], 1);
        if Jmj = 'kg' then Qty := 2 + Rnd(40) else Qty := 3 + Rnd(24) * 2;
        case Rnd(8) of 0: Rabat := 5; 1: Rabat := 10; 2: Rabat := 3; else Rabat := 0; end;
        Amount := Round(Qty * Price * (1 - Rabat / 100) * 100) / 100;
        Exec(ADb, 'INSERT INTO ' + Items + ' (dokument_id, artikl_id, opis, kolicina, jmj, cijena, rabat, pdv_stopa, iznos) VALUES (' +
          IntToStr(N) + ', ' + IntToStr(Art + 1) + ', ' + Q(ADb, Part(Products[Art], 0)) + ', ' + Num(Qty) + ', ' + Q(ADb, Jmj) + ', ' +
          Num(Price) + ', ' + Num(Rabat) + ', ' + Part(Products[Art], 3) + ', ' + Num(Amount) + ')');
        Inc(Cnt);
      end;
    end;
    ADb.Conn.Commit;
  except
    ADb.Conn.Rollback;
    raise;
  end;
  if Tip = '' then;
  ALog.Add('upisano: ' + ATable + ' ' + IntToStr(ACount) + ', stavki ' + IntToStr(Cnt));
end;

procedure FillWarehouse(ADb: TAppDb; ALog: TStrings);
var
  A, N, J: Integer;
begin
  ADb.Conn.StartTransaction;
  try
    { pocetno stanje }
    Exec(ADb, 'INSERT INTO skl_dokumenti (id, tip, broj, datum, partner_id, napomena) VALUES (1, ''Primka'', ''PS-2025'', ''2025-01-01'', 1, ''Početno stanje'')');
    for A := 1 to 90 do
      Exec(ADb, 'INSERT INTO skl_stavke (dokument_id, artikl_id, kolicina, cijena) SELECT 1, id, ' + IntToStr(700 + Rnd(700)) + ', nabavna_cijena FROM artikli WHERE id = ' + IntToStr(A));
    { primke po narudzbenicama }
    Exec(ADb, 'INSERT INTO skl_dokumenti (id, tip, broj, datum, partner_id, napomena) SELECT 1 + n.id, ''Primka'', ''PR-'' || n.broj, n.datum, n.partner_id, ''Po narudžbenici '' || n.broj ' +
      'FROM narudzbenice n WHERE n.isporucena = 1');
    Exec(ADb, 'INSERT INTO skl_stavke (dokument_id, artikl_id, kolicina, cijena) SELECT 1 + s.dokument_id, s.artikl_id, s.kolicina * 3, s.cijena * 0.7 ' +
      'FROM narudzbenice_stavke s JOIN narudzbenice n ON n.id = s.dokument_id WHERE n.isporucena = 1');
    { izdatnice po racunima: svaki 2. racun }
    N := 1000;
    Exec(ADb, 'INSERT INTO skl_dokumenti (id, tip, broj, datum, partner_id, napomena) SELECT ' + IntToStr(N) + ' + r.id, ''Izdatnica'', ''IZ-'' || r.broj, r.datum, r.partner_id, ''Po računu '' || r.broj ' +
      'FROM racuni r WHERE r.id % 2 = 0');
    Exec(ADb, 'INSERT INTO skl_stavke (dokument_id, artikl_id, kolicina, cijena) SELECT ' + IntToStr(N) + ' + s.dokument_id, s.artikl_id, s.kolicina, s.cijena ' +
      'FROM racuni_stavke s WHERE s.dokument_id % 2 = 0');
    { inventura: svaki 8. artikl pada ispod minimuma da upiti i makroi imaju sto pokazati }
    Exec(ADb, 'INSERT INTO skl_dokumenti (id, tip, broj, datum, partner_id, napomena) VALUES (5000, ''Izdatnica'', ''IZ-INV-2026'', ''2026-10-30'', 26, ''Inventurna korekcija'')');
    Exec(ADb, 'INSERT INTO skl_stavke (dokument_id, artikl_id, kolicina, cijena) SELECT 5000, a.id, ' +
      'COALESCE((SELECT SUM(CASE WHEN d.tip = ''Primka'' THEN k.kolicina ELSE -k.kolicina END) FROM skl_stavke k JOIN skl_dokumenti d ON d.id = k.dokument_id WHERE k.artikl_id = a.id), 0) - a.min_zaliha * 0.5, a.nabavna_cijena ' +
      'FROM artikli a WHERE a.id % 8 = 0');
    ADb.Conn.Commit;
  except
    ADb.Conn.Rollback;
    raise;
  end;
  if J = 0 then;
  ALog.Add('skladište: početno stanje, primke po narudžbenicama i izdatnice po računima');
end;

procedure FillCashAndTravel(ADb: TAppDb; ALog: TStrings);
const
  Costs: array[0..7] of string = ('Gorivo za dostavu|180', 'Uredski materijal|45', 'Popravak vozila|320', 'Čišćenje poslovnog prostora|90',
    'Reprezentacija|60', 'Poštarina|25', 'Tisak letaka|130', 'Parkirne karte|40');
var
  I: Integer;
  D: TDateTime;
begin
  ADb.Conn.StartTransaction;
  try
    for I := 1 to 260 do
    begin
      D := EncodeDate(2025, 1, 3) + (I - 1) * 2.6;
      if I mod 3 = 0 then
        Exec(ADb, 'INSERT INTO blagajna (broj, datum, opis, partner_id, uplata, isplata) VALUES (' + Q(ADb, Format('B-%.3d', [I])) + ', ' + Q(ADb, IsoDate(D)) + ', ' +
          Q(ADb, Part(Costs[I mod 8], 0)) + ', NULL, 0, ' + Num(StrToFloat(Part(Costs[I mod 8], 1), InvariantFS) + Rnd(60)) + ')')
      else
        Exec(ADb, 'INSERT INTO blagajna (broj, datum, opis, partner_id, uplata, isplata) VALUES (' + Q(ADb, Format('B-%.3d', [I])) + ', ' + Q(ADb, IsoDate(D)) + ', ' +
          Q(ADb, 'Gotovinska prodaja') + ', NULL, ' + Num(40 + Rnd(900) + Rnd(100) / 100) + ', 0)');
    end;
    for I := 1 to 50 do
    begin
      D := EncodeDate(2025, 1, 10) + (I - 1) * 12.5;
      Exec(ADb, 'INSERT INTO putni_nalozi (broj, zaposlenik_id, relacija, svrha, datum_od, datum_do, km, cijena_km, dnevnice_broj, dnevnica_iznos, ostali_troskovi, isplaceno) VALUES (' +
        Q(ADb, Format('PN-%.3d', [I])) + ', ' + IntToStr(1 + Rnd(16)) + ', ' + Q(ADb, 'Zagreb - ' + Part(Cities[1 + Rnd(24)], 0)) + ', ' +
        Q(ADb, Part('Sastanak s kupcem|Obilazak dobavljača|Sajam|Edukacija|Dostava robe', Rnd(5))) + ', ' + Q(ADb, IsoDate(D)) + ', ' + Q(ADb, IsoDate(D + Rnd(3))) + ', ' +
        IntToStr(60 + Rnd(700)) + ', 0.40, ' + Num(1 + Rnd(3)) + ', 26.55, ' + Num(Rnd(60)) + ', ' + IntToStr(Ord(I < 40)) + ')');
    end;
    ADb.Conn.Commit;
  except
    ADb.Conn.Rollback;
    raise;
  end;
  ALog.Add('upisano: blagajna 260 stavki, putni nalozi 50');
end;

procedure FillPayments(ADb: TAppDb; ALog: TStrings);
begin
  { uplata za svaki placeni racun, par dana poslije dospijeca ili prije; djelomicne uplate za dio neplacenih }
  Exec(ADb, 'INSERT INTO uplate (racun_id, datum, iznos, nacin) ' +
    'SELECT r.id, date(r.datum, ''+'' || (3 + (r.id * 7) % 25) || '' days''), ' +
    'ROUND((SELECT SUM(s.iznos * (1 + s.pdv_stopa / 100.0)) FROM racuni_stavke s WHERE s.dokument_id = r.id), 2), r.nacin_placanja ' +
    'FROM racuni r WHERE r.placeno = 1 AND EXISTS (SELECT 1 FROM racuni_stavke x WHERE x.dokument_id = r.id)');
  Exec(ADb, 'INSERT INTO uplate (racun_id, datum, iznos, nacin) ' +
    'SELECT r.id, date(r.datum, ''+10 days''), ROUND((SELECT SUM(s.iznos * (1 + s.pdv_stopa / 100.0)) FROM racuni_stavke s WHERE s.dokument_id = r.id) * 0.4, 2), ''Virman'' ' +
    'FROM racuni r WHERE r.placeno = 0 AND r.id % 9 = 0 AND r.datum < date(''now'', ''-30 days'')');
  ALog.Add('upisane uplate po računima (i djelomične za dio neplaćenih)');
end;

procedure FillOffersAndContracts(ADb: TAppDb; ALog: TStrings);
var
  Ctx: TaScriptContext;
  I: Integer;
  Old: procedure(const AMsg: string);
begin
  { 6 ponuda za posao s fazama i stavkama; ugovori nastaju istim makroom kao pritiskom na gumb }
  for I := 1 to 6 do
  begin
    Exec(ADb, 'INSERT INTO ponude_posla (broj, datum, partner_id, naziv, vrsta, status, avans_postotak, prekoracenje_postotak, rok_pocetka, rok_zavrsetka, uvjeti) VALUES (' +
      Q(ADb, Format('P-2026-%.3d', [I])) + ', ' + Q(ADb, IsoDate(EncodeDate(2026, 1, 8) + I * 17)) + ', ' + IntToStr(26 + I * 9) + ', ' +
      Q(ADb, Part('Opremanje poslovnog prostora|Adaptacija skladišta|Ugradnja rashladnih vitrina|Uređenje prodajnog mjesta|Montaža regala|Obnova ulaza', I - 1)) +
      ', ''Osnovna'', ''poslana'', ' + IntToStr(20 + (I mod 3) * 10) + ', ' + IntToStr(5 + (I mod 2) * 5) + ', ' +
      Q(ADb, IsoDate(EncodeDate(2026, 3, 1) + I * 10)) + ', ' + Q(ADb, IsoDate(EncodeDate(2026, 4, 20) + I * 10)) + ', ''Dodatni troškovi po stvarnom trošku uz račun.'')');
    Exec(ADb, 'INSERT INTO ponude_posla_faze (ponuda_id, redni, naziv, rok) VALUES (' + IntToStr(I) + ', 1, ''Priprema'', ' + Q(ADb, IsoDate(EncodeDate(2026, 3, 15) + I * 10)) +
      '), (' + IntToStr(I) + ', 2, ''Izvedba'', ' + Q(ADb, IsoDate(EncodeDate(2026, 4, 5) + I * 10)) + '), (' + IntToStr(I) + ', 3, ''Završetak'', ' + Q(ADb, IsoDate(EncodeDate(2026, 4, 20) + I * 10)) + ')');
    Exec(ADb, 'INSERT INTO ponude_posla_stavke (ponuda_id, vrsta, faza, opis, kolicina, jmj, cijena, iznos) VALUES ' +
      '(' + IntToStr(I) + ', ''Usluga'', 1, ''Priprema prostora'', 1, ''kom'', ' + IntToStr(400 + I * 50) + ', ' + IntToStr(400 + I * 50) + '), ' +
      '(' + IntToStr(I) + ', ''Materijal'', 2, ''Materijal'', 1, ''kom'', ' + IntToStr(900 + I * 120) + ', ' + IntToStr(900 + I * 120) + '), ' +
      '(' + IntToStr(I) + ', ''Usluga'', 2, ''Montaža'', 1, ''kom'', ' + IntToStr(650 + I * 40) + ', ' + IntToStr(650 + I * 40) + '), ' +
      '(' + IntToStr(I) + ', ''Usluga'', 3, ''Završni radovi'', 1, ''kom'', ' + IntToStr(300 + I * 30) + ', ' + IntToStr(300 + I * 30) + ')');
  end;
  Old := OnScriptMessage;
  OnScriptMessage := @QuietMessage;
  Ctx := TaScriptContext.Create(ADb);
  try
    for I := 1 to 4 do RunMacro(Ctx, OffersMacroText('Napravi ugovor', I));
    RunMacro(Ctx, OffersMacroText('Napravi dodatnu ponudu', 1));
    Exec(ADb, 'INSERT INTO ponude_posla_stavke (ponuda_id, vrsta, faza, opis, kolicina, jmj, cijena, iznos) VALUES ' +
      '(7, ''Usluga'', 1, ''Dodatna rasvjeta'', 1, ''kom'', 380, 380), (7, ''Materijal'', 1, ''Kabeli i svjetiljke'', 1, ''kom'', 520, 520)');
    RunMacro(Ctx, OffersMacroText('Napravi aneks', 7));
  finally
    OnScriptMessage := Old;
    Ctx.Free;
  end;
  Exec(ADb, 'INSERT INTO ugovor_troskovi (ugovor_id, datum, opis, iznos) VALUES (1, ''2026-04-02'', ''Odvoz šute'', 180), (1, ''2026-04-18'', ''Dodatni materijal'', 420), (2, ''2026-05-03'', ''Najam skele'', 260)');
  { jedan ugovor prelazi dopusteno prekoracenje (provjera prekoracenja ga prijavljuje) }
  Exec(ADb, 'INSERT INTO ugovor_troskovi (ugovor_id, datum, opis, iznos) SELECT id, ''2026-06-01'', ''Neplanirani radovi'', ROUND(ukupno * (1 + prekoracenje_postotak / 100.0) + 150, 2) FROM ugovori WHERE id = 3');
  ALog.Add('ponude za posao (6), ugovori (4), dodatna ponuda i aneks');
end;


{ ---------------- upiti ---------------- }

procedure MakeQueries(ADb: TAppDb; ALog: TStrings);
var
  Sql, Err: string;
begin
  SaveQuery(ADb, ALog, 'Prodaja po kategoriji i mjesecu',
    'SELECT k.naziv AS kategorija, strftime(''%Y-%m'', r.datum) AS mjesec, ROUND(SUM(s.iznos), 2) AS osnovica' + LineEnding +
    'FROM racuni_stavke s JOIN racuni r ON r.id = s.dokument_id JOIN artikli a ON a.id = s.artikl_id JOIN kategorije k ON k.id = a.kategorija_id' + LineEnding +
    'GROUP BY 1, 2 ORDER BY 1, 2');
  SaveQuery(ADb, ALog, 'Prodaja po kategorijama',
    'SELECT k.naziv AS kategorija, strftime(''%Y'', r.datum) AS godina, COUNT(*) AS stavki,' + LineEnding +
    '       ROUND(SUM(s.iznos), 2) AS osnovica, ROUND(SUM(s.iznos * s.pdv_stopa / 100.0), 2) AS pdv,' + LineEnding +
    '       ROUND(SUM(s.iznos * (1 + s.pdv_stopa / 100.0)), 2) AS ukupno' + LineEnding +
    'FROM racuni_stavke s JOIN racuni r ON r.id = s.dokument_id JOIN artikli a ON a.id = s.artikl_id JOIN kategorije k ON k.id = a.kategorija_id' + LineEnding +
    'GROUP BY 1, 2 ORDER BY 1, 2');
  SaveQuery(ADb, ALog, 'Prodaja po mjesecima',
    'SELECT strftime(''%Y-%m'', r.datum) AS mjesec, COUNT(DISTINCT r.id) AS racuna, ROUND(SUM(s.iznos), 2) AS osnovica,' + LineEnding +
    '       ROUND(SUM(s.iznos * (1 + s.pdv_stopa / 100.0)), 2) AS ukupno' + LineEnding +
    'FROM racuni r JOIN racuni_stavke s ON s.dokument_id = r.id GROUP BY 1 ORDER BY 1');
  SaveQuery(ADb, ALog, 'Top kupci',
    'SELECT p.naziv AS kupac, p.grad AS grad, '''' AS razred, COUNT(DISTINCT r.id) AS racuna,' + LineEnding +
    '       ROUND(SUM(s.iznos), 2) AS osnovica, ROUND(SUM(s.iznos * (1 + s.pdv_stopa / 100.0)), 2) AS ukupno,' + LineEnding +
    '       MAX(r.datum) AS zadnji_racun' + LineEnding +
    'FROM partneri p JOIN racuni r ON r.partner_id = p.id JOIN racuni_stavke s ON s.dokument_id = r.id' + LineEnding +
    'GROUP BY p.id ORDER BY ukupno DESC');
  SaveQuery(ADb, ALog, 'Neplaćeni računi',
    'SELECT r.broj, r.datum, r.dospijece, p.naziv AS kupac,' + LineEnding +
    '       ROUND(SUM(s.iznos * (1 + s.pdv_stopa / 100.0)), 2) AS iznos,' + LineEnding +
    '       CAST(julianday(date(''now'')) - julianday(r.dospijece) AS INTEGER) AS dana_kasnjenja' + LineEnding +
    'FROM racuni r JOIN partneri p ON p.id = r.partner_id JOIN racuni_stavke s ON s.dokument_id = r.id' + LineEnding +
    'WHERE r.placeno = 0 GROUP BY r.id ORDER BY r.dospijece');
  SaveQuery(ADb, ALog, 'Računi i uplate',
    'SELECT r.broj, r.datum, p.naziv AS kupac,' + LineEnding +
    '       ROUND(COALESCE((SELECT SUM(s.iznos * (1 + s.pdv_stopa / 100.0)) FROM racuni_stavke s WHERE s.dokument_id = r.id), 0), 2) AS iznos,' + LineEnding +
    '       ROUND(COALESCE((SELECT SUM(u.iznos) FROM uplate u WHERE u.racun_id = r.id), 0), 2) AS uplaceno,' + LineEnding +
    '       ROUND(COALESCE((SELECT SUM(s.iznos * (1 + s.pdv_stopa / 100.0)) FROM racuni_stavke s WHERE s.dokument_id = r.id), 0) -' + LineEnding +
    '             COALESCE((SELECT SUM(u.iznos) FROM uplate u WHERE u.racun_id = r.id), 0), 2) AS dug' + LineEnding +
    'FROM racuni r JOIN partneri p ON p.id = r.partner_id ORDER BY r.datum, r.id');
  SaveQuery(ADb, ALog, 'Prodaja po prodavačima',
    'SELECT z.prezime || '' '' || z.ime AS prodavac, z.radno_mjesto AS radno_mjesto, COUNT(DISTINCT r.id) AS racuna,' + LineEnding +
    '       ROUND(SUM(s.iznos), 2) AS osnovica' + LineEnding +
    'FROM zaposlenici z JOIN racuni r ON r.zaposlenik_id = z.id JOIN racuni_stavke s ON s.dokument_id = r.id GROUP BY z.id ORDER BY osnovica DESC');
  SaveQuery(ADb, ALog, 'Marža po artiklima',
    'SELECT a.sifra, a.naziv, a.nabavna_cijena AS nabavna, a.cijena AS prodajna, 0 AS marza_posto,' + LineEnding +
    '       ROUND(COALESCE(SUM(s.kolicina), 0), 2) AS prodano, ROUND(COALESCE(SUM(s.iznos), 0) - COALESCE(SUM(s.kolicina), 0) * a.nabavna_cijena, 2) AS zarada' + LineEnding +
    'FROM artikli a LEFT JOIN racuni_stavke s ON s.artikl_id = a.id GROUP BY a.id ORDER BY zarada DESC');
  SaveQuery(ADb, ALog, 'Računi kupca (parametar)',
    'SELECT r.broj, r.datum, r.dospijece, p.naziv AS kupac, r.placeno,' + LineEnding +
    '       ROUND(SUM(s.iznos * (1 + s.pdv_stopa / 100.0)), 2) AS iznos' + LineEnding +
    'FROM racuni r JOIN partneri p ON p.id = r.partner_id JOIN racuni_stavke s ON s.dokument_id = r.id' + LineEnding +
    'WHERE p.naziv LIKE [?Početak naziva kupca] || ''%'' GROUP BY r.id ORDER BY r.datum');
  SaveQuery(ADb, ALog, 'Kontakti (unija)',
    'SELECT naziv AS ime, tip AS vrsta, grad, telefon, email FROM partneri' + LineEnding +
    'UNION ALL' + LineEnding +
    'SELECT ime || '' '' || prezime, ''Zaposlenik'', ''Zagreb'', telefon, email FROM zaposlenici ORDER BY 1');
  SaveQuery(ADb, ALog, 'Ugovori i troškovi',
    'SELECT u.broj, u.naziv, u.ukupno AS ugovoreno, ROUND(u.ukupno * (1 + u.prekoracenje_postotak / 100.0), 2) AS najvise,' + LineEnding +
    '       COALESCE((SELECT SUM(t.iznos) FROM ugovor_troskovi t WHERE t.ugovor_id = u.id), 0) AS troskovi' + LineEnding +
    'FROM ugovori u ORDER BY u.broj');
  if BuildCrosstabSql(ADb, 'Prodaja po kategoriji i mjesecu', 'kategorija', 'mjesec', 'osnovica', caSum, True, Sql, Err) then
    SaveQuery(ADb, ALog, 'Kategorije po mjesecima (unakrsni)', Sql)
  else
    ALog.Add('unakrsni upit nije izrađen: ' + Err);
end;

{ ---------------- izvjesca ---------------- }

function Tabular(ADb: TAppDb; ALog: TStrings; const ASource, AName, ATitle, AFields, AGroup: string; ASums: Boolean): TaReportDef;
var
  Ro: TaReportOptions;
  Fl: TStringList;
begin
  Fl := TStringList.Create;
  try
    Fl.CommaText := AFields;
    Ro.Source := ASource; Ro.Name := AName; Ro.Title := ATitle;
    Ro.GroupField := AGroup; Ro.SortField := ''; Ro.Fields := Fl; Ro.Kind := rkTabular;
    Ro.Descending := False; Ro.Sums := ASums; Ro.PageBreakPerRecord := False; Ro.LabelColumns := 3; Ro.LabelLines := nil;
    Result := BuildReportEx(ADb, Ro);
  finally
    Fl.Free;
  end;
end;

{ stavka koja je u izvjescu zamijenjena izrazom (npr. =RazredKupca([ukupno])) }
procedure Rebind(ARep: TaReportDef; const AField, ANewSource, ANewCaption: string);
var
  I: Integer;
begin
  for I := 0 to ARep.Count - 1 do
  begin
    if SameText(ARep[I].ControlSource, AField) and (ARep[I].Kind = 'TextBox') then ARep[I].ControlSource := ANewSource
    else if (ARep[I].Kind = 'Label') and (ANewCaption <> '') and SameText(ARep[I].Caption, PrettyName(AField)) and
      (SectionIndex(ARep[I].Section) = SecPageHeader) then ARep[I].Caption := ANewCaption;
  end;
end;

{ sirine stupaca u px po redu polja: "kupac=210,grad=110,..." (zaglavlje, redak i zbrojevi se pomicu zajedno) }
procedure Widths(ARep: TaReportDef; const ASpec: string);
var
  L: TStringList;
  I, K, X, W: Integer;
  F, Src: string;
begin
  L := TStringList.Create;
  try
    L.CommaText := ASpec;
    X := 0;
    for K := 0 to L.Count - 1 do
    begin
      F := L.Names[K];
      W := StrToIntDef(L.ValueFromIndex[K], 80);
      for I := 0 to ARep.Count - 1 do
      begin
        Src := ARep[I].ControlSource;
        if SameText(Src, F) or (Pos('[' + LowerCase(F) + ']', LowerCase(Src)) > 0) or
           ((ARep[I].Kind = 'Label') and (SectionIndex(ARep[I].Section) = SecPageHeader) and SameText(ARep[I].Caption, PrettyName(F))) then
        begin
          ARep[I].Left := X;
          ARep[I].Width := W - 6;
        end;
      end;
      Inc(X, W);
    end;
  finally
    L.Free;
  end;
end;

procedure Sheet(ADb: TAppDb; ALog: TStrings; const AName: string; ACols: Integer; AW, AH, AGapH, AGapV, AMarL, AMarT: Double);
var
  Rd: TaReportDef;
  Err: string;
begin
  Rd := TaReportDef.Create;
  try
    Rd.FromJson(ADb.LoadObject('_sys_reports', AName));
    if ApplyPageSetupMm(Rd, 210, 297, AMarL, AMarT, 0, 0, ACols, AW, AH, AGapH, AGapV, Err) then
    begin
      ADb.SaveObject('_sys_reports', AName, Rd.ToJson);
      ALog.Add('naljepnice ' + AName + ': ' + IntToStr(ACols) + ' u retku, ' + FormatFloat('0.#', AW) + ' x ' + FormatFloat('0.#', AH) + ' mm');
    end
    else ALog.Add('naljepnice ' + AName + ' nisu postavljene: ' + Err);
  finally
    Rd.Free;
  end;
end;

procedure AddChart(ARep: TaReportDef; const ATitleName, AType, ASql: string; X, Y, W, H: Integer);
var
  C: TaControlDef;
begin
  C := TaControlDef.Create;
  C.Kind := 'Label';
  C.Name := ARep.UniqueName('lblGraf');
  C.Section := 'ReportHeader';
  C.Caption := ATitleName;
  C.Bold := True;
  C.Left := X; C.Top := Y; C.Width := W; C.Height := 18;
  ARep.Add(C);
  C := TaControlDef.Create;
  C.Kind := 'Chart';
  C.Name := ARep.UniqueName('chart');
  C.Section := 'ReportHeader';
  C.RowSource := ASql;
  C.SetX('chartType', AType);
  C.Left := X; C.Top := Y + 20; C.Width := W; C.Height := H;
  ARep.Add(C);
end;

procedure MakeReports(ADb: TAppDb; ALog: TStrings);
var
  Rd: TaReportDef;
  Ro: TaReportOptions;
  Fl, Ll: TStringList;
  L: TaControlDef;
begin
  SaveReport(ADb, ALog, Tabular(ADb, ALog, 'Prodaja po kategorijama', 'Prodaja po kategorijama', 'Prodaja po kategorijama',
    'kategorija,godina,stavki,osnovica,pdv,ukupno', 'kategorija', True));
  SaveReport(ADb, ALog, Tabular(ADb, ALog, 'Prodaja po mjesecima', 'Prodaja po mjesecima', 'Prodaja po mjesecima',
    'mjesec,racuna,osnovica,ukupno', '', True));
  Rd := Tabular(ADb, ALog, 'Top kupci', 'Top kupci', 'Najbolji kupci', 'kupac,grad,razred,racuna,osnovica,ukupno', '', True);
  Rebind(Rd, 'razred', '=RazredKupca([ukupno])', 'Razred');
  Widths(Rd, 'kupac=230,grad=110,razred=70,racuna=50,osnovica=85,ukupno=85');
  SaveReport(ADb, ALog, Rd);
  Rd := Tabular(ADb, ALog, 'Neplaćeni računi', 'Neplaćeni računi', 'Neplaćeni računi',
    'broj,datum,dospijece,kupac,iznos,dana_kasnjenja', '', True);
  Widths(Rd, 'broj=80,datum=80,dospijece=80,kupac=230,iznos=90,dana_kasnjenja=90');
  SaveReport(ADb, ALog, Rd);
  Rd := Tabular(ADb, ALog, 'Računi i uplate', 'Računi i uplate', 'Računi i uplate (saldo po računu)',
    'broj,datum,kupac,iznos,uplaceno,dug', '', True);
  Widths(Rd, 'broj=80,datum=80,kupac=260,iznos=90,uplaceno=90,dug=90');
  SaveReport(ADb, ALog, Rd);
  SaveReport(ADb, ALog, Tabular(ADb, ALog, 'Prodaja po prodavačima', 'Prodaja po prodavačima', 'Prodaja po prodavačima',
    'prodavac,radno_mjesto,racuna,osnovica', '', True));
  Rd := Tabular(ADb, ALog, 'Marža po artiklima', 'Marža po artiklima', 'Marža po artiklima',
    'sifra,naziv,nabavna,prodajna,marza_posto,prodano,zarada', '', False);
  Rebind(Rd, 'marza_posto', '=Marza([nabavna], [prodajna])', 'Marža %');
  Widths(Rd, 'sifra=55,naziv=230,nabavna=70,prodajna=70,marza_posto=70,prodano=70,zarada=70');
  SaveReport(ADb, ALog, Rd);
  SaveReport(ADb, ALog, Tabular(ADb, ALog, 'Računi kupca (parametar)', 'Računi kupca', 'Računi kupca',
    'broj,datum,dospijece,kupac,iznos', '', True));
  Rd := Tabular(ADb, ALog, 'Kontakti (unija)', 'Kontakti', 'Kontakti partnera i zaposlenika',
    'ime,vrsta,grad,telefon,email', 'vrsta', False);
  Widths(Rd, 'ime=250,vrsta=90,grad=110,telefon=110,email=150');
  SaveReport(ADb, ALog, Rd);
  SaveReport(ADb, ALog, Tabular(ADb, ALog, 'Ugovori i troškovi', 'Ugovori i troškovi', 'Ugovori i stvarni troškovi',
    'broj,naziv,ugovoreno,najvise,troskovi', '', True));
  { naljepnice: pravi araci (vidi Izvješće > Stranica i naljepnice) }
  Sheet(ADb, ALog, 'Naljepnice partnera', 3, 63.5, 38.1, 2.5, 0, 7.2, 15.1);
  Sheet(ADb, ALog, 'Naljepnice artikala', 3, 69.8, 37, 0, 0, 0, 0);
  { grafikoni }
  Rd := TaReportDef.Create;
  Rd.Name := 'Pregled prodaje';
  Rd.Title := 'Pregled prodaje';
  Rd.RecordSource := 'kategorije';
  Rd.Heights[SecReportHeader] := 900;
  Rd.Heights[SecPageHeader] := 0;
  Rd.Heights[SecDetail] := 0;
  Rd.Heights[SecPageFooter] := 24;
  L := TaControlDef.Create;
  L.Kind := 'Label'; L.Name := 'lblNaslov'; L.Section := 'ReportHeader'; L.Caption := 'Trgovina Jadran: pregled prodaje'; L.Bold := True;
  L.Left := 0; L.Top := 0; L.Width := 700; L.Height := 24;
  Rd.Add(L);
  AddChart(Rd, 'Osnovica po mjesecima', 'bar',
    'SELECT strftime(''%Y-%m'', r.datum), ROUND(SUM(s.iznos), 0) FROM racuni r JOIN racuni_stavke s ON s.dokument_id = r.id GROUP BY 1 ORDER BY 1', 0, 34, 700, 220);
  AddChart(Rd, 'Udio kategorija u prodaji', 'pie',
    'SELECT k.naziv, ROUND(SUM(s.iznos), 0) FROM racuni_stavke s JOIN artikli a ON a.id = s.artikl_id JOIN kategorije k ON k.id = a.kategorija_id GROUP BY 1 ORDER BY 2 DESC', 0, 290, 700, 270);
  AddChart(Rd, 'Deset najboljih kupaca', 'bar',
    'SELECT substr(p.naziv, 1, 14), ROUND(SUM(s.iznos), 0) FROM partneri p JOIN racuni r ON r.partner_id = p.id JOIN racuni_stavke s ON s.dokument_id = r.id GROUP BY p.id ORDER BY 2 DESC LIMIT 10', 0, 590, 700, 240);
  SaveReport(ADb, ALog, Rd);
  { zivi primjeri svih funkcija izraza }
  Fl := TStringList.Create;
  Ll := TStringList.Create;
  try
    Fl.CommaText := 'skupina,naziv,primjer,rezultat';
    Ro.Source := 'primjeri_funkcija'; Ro.Name := 'Funkcije: živi primjeri'; Ro.Title := 'Funkcije izraza: živi primjeri (rezultat računa sam program)';
    Ro.GroupField := 'skupina'; Ro.SortField := ''; Ro.Fields := Fl; Ro.Kind := rkTabular;
    Ro.Descending := False; Ro.Sums := False; Ro.PageBreakPerRecord := False; Ro.LabelColumns := 3; Ro.LabelLines := nil;
    Rd := BuildReportEx(ADb, Ro);
    Rebind(Rd, 'rezultat', '=Eval([primjer])', 'Rezultat');
    SaveReport(ADb, ALog, Rd);
  finally
    Fl.Free;
    Ll.Free;
  end;
end;

{ ---------------- funkcije kao zapisi ---------------- }

{ primjeri iz priručnika koriste tablice iz tutoriala; ovdje se zamjenjuju tablicama ove baze }
function LocalExample(const AName, AExample: string): string;
begin
  Result := AExample;
  if AName = 'dlookup' then Result := 'DLookup("naziv", "partneri", "id = 30")'
  else if AName = 'dcount' then Result := 'DCount("*", "racuni", "placeno = 0")'
  else if AName = 'dsum' then Result := 'DSum("kolicina", "racuni_stavke", "artikl_id = 1")'
  else if AName = 'davg' then Result := 'Round(DAvg("cijena", "artikli"), 2)'
  else if AName = 'dmin' then Result := 'DMin("datum", "racuni")'
  else if AName = 'dmax' then Result := 'DMax("sifra", "artikli")'
  else if AName = 'preuzmi' then Result := 'Preuzmi("partneri", "naziv", 30)'
  else if AName = 'pdvpostopama' then Result := 'PdvPoStopama("racuni_stavke", "iznos", "pdv_stopa", "dokument_id = 1")'
  else if AName = 'zki' then Result := '"traži certifikat (Aplikacija > Fiskalizacija)"';
end;

procedure FillFunctionTable(ADb: TAppDb; ALog: TStrings);
var
  I: Integer;
  Row: string;
begin
  EnsureTable(ADb, ALog, 'primjeri_funkcija', [
    'id|AutoNumber', 'skupina|Text', 'naziv|Text', 'potpis|Text', 'opis|Memo', 'primjer|Text', 'rezultat|Text']);
  ADb.Conn.StartTransaction;
  try
    for I := 0 to ShowcaseFuncCount - 1 do
    begin
      Row := ShowcaseFuncRow(I);
      Exec(ADb, 'INSERT INTO primjeri_funkcija (skupina, naziv, potpis, opis, primjer) VALUES (' + Q(ADb, Part(Row, 0)) + ', ' + Q(ADb, Part(Row, 1)) + ', ' +
        Q(ADb, Part(Row, 2)) + ', ' + Q(ADb, Part(Row, 3)) + ', ' + Q(ADb, LocalExample(Part(Row, 1), Part(Row, 4))) + ')');
    end;
    ADb.Conn.Commit;
  except
    ADb.Conn.Rollback;
    raise;
  end;
  ALog.Add('upisano primjera funkcija: ' + IntToStr(ShowcaseFuncCount));
end;

{ ---------------- forme ---------------- }

procedure AddCalc(AForm: TaFormDef; const ACaption, AName, ASource, AFormat: string; X, Y, W: Integer);
var
  C: TaControlDef;
begin
  C := TaControlDef.Create;
  C.Kind := 'Label'; C.Name := AForm.UniqueName('lbl' + AName); C.Caption := ACaption;
  C.Left := X; C.Top := Y + 4; C.Width := 110; C.Height := 20;
  AForm.Add(C);
  C := TaControlDef.Create;
  C.Kind := 'TextBox'; C.Name := AName; C.ControlSource := ASource; C.Format := AFormat; C.SetX('locked', '1');
  C.Left := X + 114; C.Top := Y; C.Width := W; C.Height := 24;
  AForm.Add(C);
end;

{ forma Racuni dobiva prodavaca, nacin placanja i dostavu (stupci dodani na racune) }
procedure ExtendInvoiceForm(ADb: TAppDb; ALog: TStrings);
var
  Js: string;
  F: TaFormDef;

  procedure Fld(const AKind, AName, ACaption, ASource, ARows: string; Y, W: Integer);
  var
    C: TaControlDef;
  begin
    C := TaControlDef.Create;
    C.Kind := 'Label'; C.Name := 'lbl' + AName; C.Caption := ACaption;
    C.Left := 268; C.Top := Y + 2; C.Width := 70; C.Height := 22;
    F.Add(C);
    C := TaControlDef.Create;
    C.Kind := AKind; C.Name := AName; C.ControlSource := ASource; C.RowSource := ARows;
    C.Left := 342; C.Top := Y; C.Width := W; C.Height := 24;
    F.Add(C);
  end;

begin
  Js := ADb.LoadObject('_sys_forms', 'Računi');
  if Js = '' then Exit;
  F := TaFormDef.Create;
  F.FromJson(Js);
  F.Name := 'Računi';
  Fld('ComboBox', 'Comzaposlenik', 'Prodavač', 'zaposlenik_id', 'SELECT "id", "prezime" || '' '' || "ime" FROM "zaposlenici" ORDER BY "prezime"', 90, 142);
  Fld('TextBox', 'Texnacin', 'Plaćanje', 'nacin_placanja', '', 124, 142);
  Fld('TextBox', 'Texdostava', 'Dostava', 'dostava', '', 192, 100);
  SaveForm(ADb, ALog, F);
end;

procedure MakeForms(ADb: TAppDb; ALog: TStrings);
var
  Fl, Master: TStringList;
  F: TaFormDef;
  MM: TaMDMulti;
  MR: TaMDMultiResult;
  J: Integer;
begin
  { artikli: sada s kategorijom, dobavljacem, nabavnom cijenom i maržom iz modula }
  Fl := TStringList.Create;
  try
    Fl.CommaText := 'sifra,naziv,kategorija_id,dobavljac_id,jmj,nabavna_cijena,cijena,pdv_stopa,min_zaliha,aktivan';
    F := BuildFormDef(ADb, 'artikli', 'Artikli', Fl, True);
    F.Caption := 'Artikli i usluge';
    AddCalc(F, 'Marža %:', 'txtMarza', '=Marza([nabavna_cijena], [cijena])', '0.00', 16, F.Height - 10, 90);
    AddCalc(F, 'S PDV-om:', 'txtSPdv', '=Zaokruzi([cijena] * (1 + [pdv_stopa] / 100), 2)', '0.00', 330, F.Height - 10, 90);
    F.Height := F.Height + 40;
    SaveForm(ADb, ALog, F);
  finally
    Fl.Free;
  end;
  { kupac s racunima (master-detail) }
  Master := TStringList.Create;
  try
    Master.CommaText := 'naziv,tip,oib,adresa,postanski,grad,telefon,email,iban';
    MM.Master := 'partneri'; MM.Name := 'Kupac s računima'; MM.Title := 'Kupac s računima'; MM.MasterFields := Master;
    MM.DetailAsForm := False; MM.UseTabs := False;
    SetLength(MM.Details, 1);
    MM.Details[0].Table := 'racuni'; MM.Details[0].Fields := nil; MM.Details[0].SumField := '';
    MM.Details[0].ShowCount := True; MM.Details[0].FkCol := 'partner_id'; MM.Details[0].ParentCol := 'id';
    MR := BuildMasterDetailMulti(ADb, MM);
    if MR.Error <> '' then ALog.Add('Kupac s računima: ' + MR.Error)
    else
    begin
      SaveForm(ADb, ALog, MR.MasterForm);
      for J := 0 to High(MR.Items) do MR.Items[J].Form.Free;
    end;
  finally
    Master.Free;
  end;
  { funkcije: zivi primjeri }
  Fl := TStringList.Create;
  try
    Fl.CommaText := 'skupina,naziv,potpis,opis,primjer';
    F := BuildFormDef(ADb, 'primjeri_funkcija', 'Funkcije', Fl, False);
    F.Caption := 'Funkcije izraza: živi primjeri';
    AddCalc(F, 'Rezultat:', 'txtRezultat', '=Eval([primjer])', '', 16, F.Height - 6, 400);
    F.Height := F.Height + 40;
    SaveForm(ADb, ALog, F);
  finally
    Fl.Free;
  end;
end;

{ ---------------- formatirani tekst ---------------- }

procedure MakeNotices(ADb: TAppDb; ALog: TStrings);
var
  Fl: TStringList;
  F: TaFormDef;
  I: Integer;
  Rd: TaReportDef;
  C: TaControlDef;
const
  Notices: array[0..3] of string = (
    'Nova cijena kave|<p align="center"><b><font color="#b22222" size="16">Nova cijena kave</font></b></p><p>Od <b>1. prosinca</b> mijenja se cijena mljevene kave:</p><p list="1">Mljevena kava 250 g: <u>3,20 €</u> → <b>3,45 €</b></p><p list="1">Mljevena kava 500 g: <u>6,10 €</u> → <b>6,60 €</b></p><p>Narudžbe zaprimljene do kraja studenoga ostaju po staroj cijeni.</p>',
    'Radno vrijeme o blagdanima|<p><b>Radno vrijeme o blagdanima</b></p><p>Poštovani kupci, u <font color="#1f4e9c">blagdansko vrijeme</font> skladište radi:</p><p list="1">24. i 31. prosinca: <b>7:00 – 13:00</b></p><p list="1">25., 26. prosinca i 1. siječnja: <i>zatvoreno</i></p><p align="right">Trgovina Jadran</p>',
    'Inventura|<p><b>Inventura skladišta</b></p><p>Inventura je u <font color="#2e7d32">ponedjeljak</font>. Isporuke tog dana kasne <u>do dva sata</u>.</p>',
    'Novi artikli|<p align="center"><font size="14"><b>Novi u ponudi</b></font></p><p>U ponudi su novi <b>riblji proizvodi</b>: srdele, tuna i pašteta od tune, te <i>bakalar</i> po akcijskoj cijeni.</p><p>Cjenik je u privitku.</p>');
begin
  EnsureTable(ADb, ALog, 'obavijesti', ['id|AutoNumber', 'naslov|Text|||R', 'datum|Date|Today()', 'tekst|Memo']);
  for I := 0 to High(Notices) do
    Exec(ADb, 'INSERT INTO obavijesti (naslov, datum, tekst) VALUES (' + Q(ADb, Part(Notices[I], 0)) + ', ' + Q(ADb, IsoDate(EncodeDate(2026, 10, 5) + I * 6)) + ', ' + Q(ADb, Copy(Notices[I], Pos('|', Notices[I]) + 1, MaxInt)) + ')');
  { forma: polje tekst je RichText (formatirani tekst u bazi) }
  Fl := TStringList.Create;
  try
    Fl.CommaText := 'naslov,datum,tekst';
    F := BuildFormDef(ADb, 'obavijesti', 'Obavijesti', Fl, False);
    F.Caption := 'Obavijesti kupcima';
    for I := 0 to F.Count - 1 do
      if SameText(F[I].ControlSource, 'tekst') then
      begin
        F[I].Kind := 'RichText';
        F[I].Width := 440;
        F[I].Height := 200;
      end;
    F.Width := 600;
    F.Height := F.Height + 180;
    SaveForm(ADb, ALog, F);
  finally
    Fl.Free;
  end;
  { izvjesce: svaka obavijest s oblikovanim tekstom; redak se sam produlji }
  Rd := TaReportDef.Create;
  Rd.Name := 'Obavijesti';
  Rd.Title := 'Obavijesti kupcima';
  Rd.RecordSource := 'obavijesti';
  Rd.SortBy := 'datum DESC';
  Rd.Heights[SecDetail] := 80;
  Rd.Heights[SecPageHeader] := 0;
  C := TaControlDef.Create;
  C.Kind := 'Label'; C.Name := 'lblNaslov'; C.Section := 'ReportHeader'; C.Caption := 'Obavijesti kupcima'; C.Bold := True;
  C.Left := 0; C.Top := 6; C.Width := 600; C.Height := 24;
  Rd.Add(C);
  C := TaControlDef.Create;
  C.Kind := 'TextBox'; C.Name := 'tNaslov'; C.Section := 'Detail'; C.ControlSource := 'naslov'; C.Bold := True;
  C.Left := 0; C.Top := 4; C.Width := 400; C.Height := 18;
  Rd.Add(C);
  C := TaControlDef.Create;
  C.Kind := 'TextBox'; C.Name := 'tDatum'; C.Section := 'Detail'; C.ControlSource := 'datum';
  C.Left := 560; C.Top := 4; C.Width := 100; C.Height := 18;
  Rd.Add(C);
  C := TaControlDef.Create;
  C.Kind := 'RichText'; C.Name := 'rtTekst'; C.Section := 'Detail'; C.ControlSource := 'tekst';
  C.Left := 0; C.Top := 26; C.Width := 660; C.Height := 40;
  Rd.Add(C);
  SaveReport(ADb, ALog, Rd);
  ALog.Add('formatirani tekst: tablica obavijesti, forma i izvješće s poljem RichText');
end;

{ ---------------- dopisi ---------------- }

procedure MakeLetters(ADb: TAppDb; ALog: TStrings);
var
  Lt: TaLetterDef;
begin
  Lt := TaLetterDef.Create;
  try
    Lt.Name := 'Opomena';
    Lt.Source := 'partneri';
    Lt.Filter := 'id IN (SELECT partner_id FROM racuni WHERE placeno = 0 AND dospijece < date(''now''))';
    Lt.DetailSql := 'SELECT r.broj, r.datum, r.dospijece, ROUND(SUM(s.iznos * (1 + s.pdv_stopa / 100.0)), 2) AS iznos ' +
      'FROM racuni r JOIN racuni_stavke s ON s.dokument_id = r.id WHERE r.partner_id = {id} AND r.placeno = 0 AND r.dospijece < date(''now'') ' +
      'GROUP BY r.id ORDER BY r.datum, r.id';
    Lt.Columns := 'broj|Broj računa||left|2' + LineEnding + 'datum|Datum||left|2' + LineEnding + 'dospijece|Dospijeće||left|2' + LineEnding + 'iznos|Iznos s PDV-om (EUR)|0.00|right|3';
    Lt.TotalField := 'iznos';
    Lt.TotalLabel := 'Ukupno';
    Lt.Body := '#>[firma_naziv]' + LineEnding + '>[firma_adresa], [firma_mjesto]' + LineEnding + '>IBAN: [firma_iban]' + LineEnding + LineEnding +
      '>[firma_mjesto], [datum]' + LineEnding + LineEnding +
      '#[naziv]' + LineEnding + '[adresa]' + LineEnding + '[postanski] [grad]' + LineEnding + LineEnding +
      '#Predmet: opomena pred tužbu za neplaćene račune' + LineEnding + LineEnding +
      'Poštovani,' + LineEnding + LineEnding +
      'na dan [datum] imate [stavki] računa s isteklim rokom plaćanja:' + LineEnding + LineEnding +
      '[tablica]' + LineEnding +
      'Ukupan dug iznosi [ukupno] EUR, uz zakonsku zateznu kamatu.' + LineEnding + LineEnding +
      'Molimo uplatu na IBAN [firma_iban] u roku od osam dana.' + LineEnding + LineEnding +
      'S poštovanjem,' + LineEnding + '[firma_naziv]';
    ADb.SaveObject('_sys_letters', Lt.Name, Lt.ToJson);
  finally
    Lt.Free;
  end;
  Lt := TaLetterDef.Create;
  try
    Lt.Name := 'Zahvalnica kupcu';
    Lt.Source := 'Top kupci';
    Lt.Filter := 'ukupno > 5000';
    Lt.Body := '#>[firma_naziv]' + LineEnding + '>[firma_adresa], [firma_mjesto]' + LineEnding + LineEnding + '>[firma_mjesto], [datum]' + LineEnding + LineEnding +
      '#[kupac]' + LineEnding + '[grad]' + LineEnding + LineEnding +
      'Poštovani,' + LineEnding + LineEnding +
      'zahvaljujemo na suradnji: u razdoblju od početka godine ostvarili ste promet od [ukupno|#,##0.00] EUR u [racuna] računa.' + LineEnding + LineEnding +
      'Kao zahvalu odobravamo Vam rabat od {Iif([ukupno] > 8000, 5, 3)} % na sljedeću narudžbu.' + LineEnding + LineEnding +
      'S poštovanjem,' + LineEnding + '[firma_naziv]';
    ADb.SaveObject('_sys_letters', Lt.Name, Lt.ToJson);
  finally
    Lt.Free;
  end;
  ALog.Add('dopisi: Opomena (s tablicom računa), Zahvalnica kupcu');
end;

{ ---------------- makroi ---------------- }

procedure Com(P: TaBlockProgram; const ATxt: string);
begin
  P.Add(NewCommentBlock(ATxt));
end;

procedure Cmd(P: TaBlockProgram; const AVerb, AArg: string);
begin
  P.Add(NewCommandBlock(AVerb, AArg));
end;

procedure IfB(P: TaBlockProgram; const ACond: string);
begin
  P.Add(NewStructBlock(bkIfBlock, ACond));
end;

procedure ElseB(P: TaBlockProgram);
begin
  P.Add(NewStructBlock(bkElse, ''));
end;

procedure EndIf(P: TaBlockProgram);
begin
  P.Add(NewStructBlock(bkEndIf, ''));
end;

procedure SaveMacro(ADb: TAppDb; ALog: TStrings; const AName: string; P: TaBlockProgram);
begin
  ADb.SaveObject('_sys_macros', AName, P.Text);
  ALog.Add('makro (blokovi): ' + AName);
  P.Free;
end;

procedure MakeMacros(ADb: TAppDb; ALog: TStrings);
var
  P: TaBlockProgram;
begin
  P := TaBlockProgram.Create;
  Com(P, 'Sažetak: koliko je računa neplaćeno i koliko je od toga u kašnjenju');
  Cmd(P, 'fetch', 'n = SELECT COUNT(*) FROM racuni WHERE placeno = 0');
  Cmd(P, 'fetch', 'k = SELECT COUNT(*) FROM racuni WHERE placeno = 0 AND dospijece < date(''now'')');
  Cmd(P, 'fetch', 'dug = SELECT ROUND(COALESCE(SUM(s.iznos * (1 + s.pdv_stopa / 100.0)), 0), 2) FROM racuni r JOIN racuni_stavke s ON s.dokument_id = r.id WHERE r.placeno = 0');
  IfB(P, '[n] = 0');
  Cmd(P, 'msg', 'Nema neplaćenih računa.');
  ElseB(P);
  Cmd(P, 'msg', 'Neplaćenih računa: {n}, od toga u kašnjenju {k}. Dug s PDV-om: {dug} EUR.');
  EndIf(P);
  SaveMacro(ADb, ALog, 'Sažetak neplaćenih', P);

  P := TaBlockProgram.Create;
  Com(P, 'Poskupljenje cijelog cjenika za postotak, uz provjeru raspona i potvrdu (petlja: dok unos nije ispravan)');
  Cmd(P, 'input', 'Za koliko posto povećati cijene (1 do 30)?');
  P.Add(NewLetBlock('p', 'Val([unos])'));
  P.Add(NewStructBlock(bkWhile, '[p] < 1 Or [p] > 30'));
  Cmd(P, 'input', 'Upiši broj od 1 do 30 (prazno = odustani):');
  IfB(P, '[unos] = ""');
  Cmd(P, 'msg', 'Odustali ste.');
  Cmd(P, 'stop', '');
  EndIf(P);
  P.Add(NewLetBlock('p', 'Val([unos])'));
  P.Add(NewStructBlock(bkEndWhile, ''));
  Cmd(P, 'ask', 'Povećati sve cijene za {p} %?');
  IfB(P, '[odgovor] = 1');
  Cmd(P, 'sql', 'UPDATE artikli SET cijena = ROUND(cijena * (1 + {p} / 100.0), 2)');
  Cmd(P, 'msg', 'Cijene su povećane za {p} %.');
  EndIf(P);
  SaveMacro(ADb, ALog, 'Povećaj cijene', P);

  P := TaBlockProgram.Create;
  Com(P, 'Narudžbenica za artikle ispod minimalne zalihe (dokument iz podataka: copyrows)');
  Cmd(P, 'fetch', 'n = SELECT COUNT(*) FROM artikli a WHERE a.aktivan = 1 AND COALESCE((SELECT SUM(CASE WHEN d.tip = ''Primka'' THEN k.kolicina ELSE -k.kolicina END) FROM skl_stavke k JOIN skl_dokumenti d ON d.id = k.dokument_id WHERE k.artikl_id = a.id), 0) < a.min_zaliha');
  IfB(P, '[n] = 0');
  Cmd(P, 'msg', 'Nijedan artikl nije ispod minimalne zalihe.');
  Cmd(P, 'stop', '');
  EndIf(P);
  Cmd(P, 'sql', 'INSERT INTO narudzbenice (broj, datum, dospijece, partner_id, isporucena, napomena) VALUES (strftime(''%Y'', ''now'') || ''-N'' || printf(''%03d'', (SELECT COALESCE(MAX(id), 0) + 1 FROM narudzbenice)), date(''now''), date(''now'', ''+14 days''), 1, 0, ''Automatska narudžba po minimalnim zalihama'')');
  Cmd(P, 'fetch', 'nid = SELECT MAX(id) FROM narudzbenice');
  Cmd(P, 'copyrows', 'artikli WHERE aktivan = 1 AND COALESCE((SELECT SUM(CASE WHEN d.tip = ''Primka'' THEN k.kolicina ELSE -k.kolicina END) FROM skl_stavke k JOIN skl_dokumenti d ON d.id = k.dokument_id WHERE k.artikl_id = artikli.id), 0) < min_zaliha -> narudzbenice_stavke : dokument_id = {nid}, artikl_id = id, opis = naziv, kolicina = min_zaliha * 2, jmj = jmj, cijena = nabavna_cijena, rabat = 0, pdv_stopa = pdv_stopa, iznos = ROUND(min_zaliha * 2 * nabavna_cijena, 2)');
  Cmd(P, 'msg', 'Napravljena je narudžbenica s {kopirano} artikala (dobavljač je Prvi u popisu; promijeni ga na formi).');
  SaveMacro(ADb, ALog, 'Narudžbenica po minimumima', P);

  P := TaBlockProgram.Create;
  Com(P, 'Račun iz ponude: ponuda se kopira u račun s istim stavkama (copyrows za zaglavlje i za stavke)');
  Cmd(P, 'input', 'Broj ponude (npr. 2026-001):');
  Cmd(P, 'fetch', 'pid = SELECT id FROM ponude WHERE broj = {unos}');
  IfB(P, 'IsNull([pid])');
  Cmd(P, 'msg', 'Nema ponude s tim brojem.');
  Cmd(P, 'stop', '');
  EndIf(P);
  Cmd(P, 'copyrows', 'ponude WHERE id = {pid} -> racuni : broj = ''R-'' || broj, datum = date(''now''), dospijece = date(''now'', ''+15 days''), partner_id = partner_id, placeno = 0, napomena = ''Po ponudi '' || broj');
  Cmd(P, 'fetch', 'rid = SELECT MAX(id) FROM racuni');
  Cmd(P, 'copyrows', 'ponude_stavke WHERE dokument_id = {pid} -> racuni_stavke : dokument_id = {rid}, artikl_id = artikl_id, opis = opis, kolicina = kolicina, jmj = jmj, cijena = cijena, rabat = rabat, pdv_stopa = pdv_stopa, iznos = iznos');
  Cmd(P, 'msg', 'Napravljen je račun s {kopirano} stavki iz ponude {unos}.');
  SaveMacro(ADb, ALog, 'Račun iz ponude', P);

  P := TaBlockProgram.Create;
  Com(P, 'Dnevni izvještaji u PDF u mapu koju korisnik upiše');
  Cmd(P, 'input', 'Mapa za PDF izvještaje (npr. /home/ana/izvjestaji):');
  IfB(P, '[unos] = ""');
  Cmd(P, 'msg', 'Odustali ste.');
  ElseB(P);
  Cmd(P, 'exportpdf', 'Prodaja po kategorijama > {unos}/prodaja-po-kategorijama.pdf');
  Cmd(P, 'exportpdf', 'Top kupci > {unos}/top-kupci.pdf');
  Cmd(P, 'exportpdf', 'Neplaćeni računi > {unos}/neplaceni.pdf');
  Cmd(P, 'exportpdf', 'Pregled prodaje > {unos}/pregled-prodaje.pdf');
  Cmd(P, 'msg', 'PDF izvještaji su spremljeni u {unos}.');
  EndIf(P);
  SaveMacro(ADb, ALog, 'Dnevni izvještaji u PDF', P);

  P := TaBlockProgram.Create;
  Com(P, 'Uvoz cjenika dobavljača iz CSV/XLSX datoteke u pomoćnu tablicu');
  Cmd(P, 'input', 'Puna putanja CSV ili XLSX datoteke (prvi redak: naziv polja):');
  IfB(P, '[unos] = ""');
  Cmd(P, 'msg', 'Odustali ste.');
  ElseB(P);
  Cmd(P, 'importtable', 'uvoz_cjenika < {unos}');
  Cmd(P, 'msg', 'Uvezeno redaka: {uvezeno}, preskočeno: {preskoceno}.');
  EndIf(P);
  SaveMacro(ADb, ALog, 'Uvoz cjenika', P);

  P := TaBlockProgram.Create;
  Com(P, 'Izvoz računa za razdoblje u Excel; datumi se upisuju, a izvoz ide kroz upit');
  Cmd(P, 'input', 'Izvoz u datoteku (npr. /home/ana/racuni.xlsx):');
  IfB(P, '[unos] <> ""');
  Cmd(P, 'exporttable', 'Računi i uplate > {unos}');
  Cmd(P, 'msg', 'Izvoz je gotov.');
  EndIf(P);
  SaveMacro(ADb, ALog, 'Izvoz računa u Excel', P);

  P := TaBlockProgram.Create;
  Com(P, 'Opomena e-poštom: otvara poruku programu za e-poštu (privitak PDF-a pripremi naredbom exportletter)');
  Cmd(P, 'input', 'E-adresa dužnika:');
  IfB(P, '[unos] <> ""');
  Cmd(P, 'mailto', '{unos} ; Opomena za neplaćene račune ; Poštovani, u privitku je opomena za neplaćene račune. Lijep pozdrav, Trgovina Jadran');
  EndIf(P);
  SaveMacro(ADb, ALog, 'Opomena e-poštom', P);

  P := TaBlockProgram.Create;
  Com(P, 'Zaključak mjeseca: 4GL program obračuna i dnevnik (modul), pa sigurnosna kopija baze');
  Cmd(P, 'run4gl', 'Mjesečni obračun prodaje');
  Cmd(P, 'run', 'ZabiljeziZakljucak');
  Cmd(P, 'input', 'Sigurnosna kopija u datoteku (prazno = bez kopije):');
  IfB(P, '[unos] <> ""');
  Cmd(P, 'backup', '{unos}');
  Cmd(P, 'msg', 'Kopija je spremljena.');
  EndIf(P);
  SaveMacro(ADb, ALog, 'Zaključak mjeseca', P);

  P := TaBlockProgram.Create;
  Com(P, 'Gumb na formi Računi: označi račun plaćenim i upiši uplatu');
  Cmd(P, 'ask', 'Označiti račun kao plaćen?');
  IfB(P, '[odgovor] = 1');
  Cmd(P, 'set', 'placeno = 1');
  Cmd(P, 'save', '');
  Cmd(P, 'msg', 'Račun je označen kao plaćen.');
  EndIf(P);
  SaveMacro(ADb, ALog, 'Označi plaćenim', P);

  P := TaBlockProgram.Create;
  Com(P, 'Provjera ugovora: prekoračenje troškova (isti makro kao u predlošku, za sve ugovore redom)');
  Cmd(P, 'fetch', 'n = SELECT COUNT(*) FROM ugovori u WHERE (SELECT COALESCE(SUM(t.iznos), 0) FROM ugovor_troskovi t WHERE t.ugovor_id = u.id) > u.ukupno * (1 + u.prekoracenje_postotak / 100.0)');
  IfB(P, '[n] = 0');
  Cmd(P, 'msg', 'Nijedan ugovor nije prekoračio dopuštenu granicu.');
  ElseB(P);
  Cmd(P, 'msg', 'UPOZORENJE: {n} ugovora ima troškove iznad dopuštene granice (vidi upit Ugovori i troškovi).');
  EndIf(P);
  SaveMacro(ADb, ALog, 'Provjera prekoračenja ugovora', P);

  ADb.Conn.ExecuteDirect('CREATE TABLE IF NOT EXISTS uvoz_cjenika (id INTEGER PRIMARY KEY AUTOINCREMENT, sifra TEXT, naziv TEXT, cijena NUMERIC)');
end;

{ ---------------- modul, 4GL programi, planer ---------------- }

procedure SaveCode(ADb: TAppDb; ALog: TStrings);
var
  I: Integer;
begin
  ADb.SaveObject('_sys_modules', 'Poslovne_funkcije', ShowcaseModuleText);
  ALog.Add('modul: Poslovne_funkcije (Marza, RabatPoKolicini, RazredKupca, Kamata, Zaokruzi5, OibIspravan, SifraArtikla, ZabiljeziDnevnik, ZabiljeziZakljucak)');
  for I := 0 to ShowcaseProgramCount - 1 do
    ADb.SaveObject('_sys_programs', ShowcaseProgramName(I), ShowcaseProgramText(I));
  ALog.Add('4GL programi u bazi: ' + IntToStr(ShowcaseProgramCount));
end;

procedure MakeTasks(ADb: TAppDb; ALog: TStrings);
var
  T: TaTask;
begin
  T.Name := 'Noćna sigurnosna kopija'; T.Kind := 'backup'; T.Arg := '/tmp/jadran-kopije'; T.Arg2 := '10';
  T.Schedule := 'dnevno 02:00'; T.Enabled := False; T.LastRun := 0; T.LastResult := '';
  SaveTask(ADb, T);
  T.Name := 'Mjesečni izvještaj o prodaji'; T.Kind := 'report_pdf'; T.Arg := 'Prodaja po mjesecima'; T.Arg2 := '/tmp/jadran-izvjestaji';
  T.Schedule := 'mjesečno 1 06:30'; SaveTask(ADb, T);
  T.Name := 'Izvoz neplaćenih računa'; T.Kind := 'export_csv'; T.Arg := 'Neplaćeni računi'; T.Arg2 := '/tmp/jadran-izvozi';
  T.Schedule := 'tjedno pon 07:00'; SaveTask(ADb, T);
  T.Name := 'Pregled prekoračenja'; T.Kind := 'macro'; T.Arg := 'Provjera prekoračenja ugovora'; T.Arg2 := '';
  T.Schedule := 'dnevno 08:00'; SaveTask(ADb, T);
  ALog.Add('planer zadataka: 4 zadatka (isključeni dok ih ne uključiš: Aplikacija > Planer zadataka)');
end;

{ ---------------- cjelina ---------------- }

function BuildShowcase(ADb: TAppDb; ALog: TStrings): Boolean;
var
  S: TaAppSettings;
  Items: TStringList;
  Def: TaFormDef;
begin
  Result := True;
  try
    MakeStructure(ADb, ALog);
    ADb.Conn.StartTransaction;
    try
      FillPartners(ADb, ALog);
      FillCategoriesAndArticles(ADb, ALog);
      FillEmployees(ADb, ALog);
      ADb.Conn.Commit;
    except
      ADb.Conn.Rollback;
      raise;
    end;
    FillDocuments(ADb, 'racuni', 'placeno', 600, 0, EncodeDate(2025, 1, 2), 670, ALog);
    FillDocuments(ADb, 'ponude', 'prihvacena', 150, 0, EncodeDate(2025, 1, 5), 660, ALog);
    FillDocuments(ADb, 'narudzbenice', 'isporucena', 120, 1, EncodeDate(2025, 1, 3), 650, ALog);
    FillDocuments(ADb, 'otpremnice', 'potpisana', 100, 0, EncodeDate(2025, 1, 4), 665, ALog);
    FillDocuments(ADb, 'predracuni', 'placeno', 60, 0, EncodeDate(2025, 2, 1), 600, ALog);
    FillWarehouse(ADb, ALog);
    FillCashAndTravel(ADb, ALog);
    FillPayments(ADb, ALog);
    FillOffersAndContracts(ADb, ALog);
    FillFunctionTable(ADb, ALog);
    MakeQueries(ADb, ALog);
    MakeReports(ADb, ALog);
    MakeForms(ADb, ALog);
    ExtendInvoiceForm(ADb, ALog);
    MakeNotices(ADb, ALog);
    MakeLetters(ADb, ALog);
    MakeMacros(ADb, ALog);
    SaveCode(ADb, ALog);
    MakeTasks(ADb, ALog);
    AuditEnable(ADb, 'partneri');
    AuditEnable(ADb, 'artikli');
    AuditEnable(ADb, 'racuni');
    ALog.Add('revizijski trag uključen na partneri, artikli i računi');
    { izbornik: forme, izvjesca i makroi }
    Items := TStringList.Create;
    try
      Items.Add('# Dokumenti');
      Items.Add('Računi|openform:Računi');
      Items.Add('Ponude|openform:Ponude');
      Items.Add('Narudžbenice|openform:Narudžbenice');
      Items.Add('Otpremnice|openform:Otpremnice');
      Items.Add('Predračuni|openform:Predračuni');
      Items.Add('# Šifrarnici i ljudi');
      Items.Add('Kupci i dobavljači|openform:Partneri');
      Items.Add('Kupac s računima|openform:Kupac s računima');
      Items.Add('Artikli|openform:Artikli');
      Items.Add('Skladišni dokumenti|openform:Skladišni dokumenti');
      Items.Add('Blagajna|openform:Blagajna');
      Items.Add('Zaposlenici|openform:Zaposlenici');
      Items.Add('Putni nalozi|openform:Putni nalozi');
      Items.Add('Ponude poslova|openform:Ponude poslova');
      Items.Add('Ugovori i aneksi|openform:Ugovori');
      Items.Add('# Izvještaji');
      Items.Add('Pregled prodaje (grafikoni)|openreport:Pregled prodaje');
      Items.Add('Prodaja po kategorijama|openreport:Prodaja po kategorijama');
      Items.Add('Prodaja po mjesecima|openreport:Prodaja po mjesecima');
      Items.Add('Najbolji kupci|openreport:Top kupci');
      Items.Add('Prodaja po prodavačima|openreport:Prodaja po prodavačima');
      Items.Add('Marža po artiklima|openreport:Marža po artiklima');
      Items.Add('Stanje zaliha|openreport:Stanje zaliha');
      Items.Add('Računi po razdoblju|openreport:Računi po razdoblju');
      Items.Add('Neplaćeni računi|openreport:Neplaćeni računi');
      Items.Add('Računi i uplate|openreport:Računi i uplate');
      Items.Add('Cjenik|openreport:Cjenik');
      Items.Add('Naljepnice kupaca|openreport:Naljepnice partnera');
      Items.Add('Naljepnice artikala|openreport:Naljepnice artikala');
      Items.Add('# Dopisi i makroi');
      Items.Add('Opomene (dopis)|openletter:Opomena');
      Items.Add('Zahvalnice (dopis)|openletter:Zahvalnica kupcu');
      Items.Add('Sažetak neplaćenih|macro:Sažetak neplaćenih');
      Items.Add('Povećaj cijene|macro:Povećaj cijene');
      Items.Add('Narudžbenica po minimumima|macro:Narudžbenica po minimumima');
      Items.Add('Provjera prekoračenja ugovora|macro:Provjera prekoračenja ugovora');
      Items.Add('Zaključak mjeseca|macro:Zaključak mjeseca');
      Items.Add('# Jezik izraza');
      Items.Add('Funkcije: živi primjeri|openform:Funkcije');
      Items.Add('Funkcije: ispis svih|openreport:Funkcije: živi primjeri');
      Items.Add('# Formatirani tekst');
      Items.Add('Obavijesti (RichText)|openform:Obavijesti');
      Items.Add('Obavijesti: ispis|openreport:Obavijesti');
      Items.Add('Zatvori|close');
      Def := BuildSwitchboard('Izbornik', 'Trgovina Jadran', Items);
      SaveForm(ADb, ALog, Def);
    finally
      Items.Free;
    end;
    S := LoadAppSettings(ADb);
    S.Title := 'Trgovina Jadran';
    S.StartupForm := 'Izbornik';
    SaveAppSettings(ADb, S);
    ALog.Add('naslov aplikacije: Trgovina Jadran; početna forma: Izbornik');
  except
    on E: Exception do
    begin
      ALog.Add('GREŠKA: ' + E.Message);
      Result := False;
    end;
  end;
end;

end.
