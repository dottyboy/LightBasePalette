unit ta_fixtureimport;
{ Uvoz rasporeda utakmica u tablicu "fixtures" (division, matchdate, hometeam, awayteam) iz datoteka
  koje preuzima SmartBet: football-data (Div, Date, HomeTeam, AwayTeam), dodatne lige (Country, League,
  Home, Away) te Hrvatska i UEFA natjecanja (Div, Date ISO). Oblik se prepoznaje po zaglavlju; xlsx uz
  csv ima prednost kao u SmartBetu. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ZDataset, ta_meta, ta_importexport;

{ broj novih redaka; utakmica koja je vec u tablici (liga, klubovi, datum) se ne dodaje ponovno }
function ImportFixtureFile(ADb: TAppDb; const AFile: string): Integer;
{ (drzava, liga) -> sifra lige iz SmartBeta (newleagues.DIVISION_CODES), '' ako nije poznata }
function DivisionOfLeague(const ACountry, ALeague: string): string;

implementation

uses
  ta_i18n;


const
  { newleagues.DIVISION_CODES: (drzava, liga) -> sifra }
  LeagueKeys: array[0..16] of string = (
    'Argentina|Liga Profesional', 'Argentina|Copa De La Liga Profesional', 'Austria|Bundesliga', 'Brazil|Serie A',
    'China|Super League', 'Denmark|Superliga', 'Finland|Veikkausliiga', 'Ireland|Premier Division', 'Japan|J1 League',
    'Mexico|Liga MX', 'Norway|Eliteserien', 'Poland|Ekstraklasa', 'Romania|Superliga', 'Russia|Premier League',
    'Sweden|Allsvenskan', 'Switzerland|Super League', 'USA|MLS');
  LeagueCodes: array[0..16] of string = (
    'ARG1', 'ARGC', 'AUT1', 'BRA1', 'CHN1', 'DNK1', 'FIN1', 'IRL1', 'JPN1', 'MEX1', 'NOR1', 'POL1', 'ROU1', 'RUS1',
    'SWE1', 'SWZ1', 'USA1');

function DivisionOfLeague(const ACountry, ALeague: string): string;
var
  I: Integer;
begin
  for I := 0 to High(LeagueKeys) do
    if LeagueKeys[I] = ACountry + '|' + ALeague then Exit(LeagueCodes[I]);
  Result := '';
end;

{ 2026-09-15, 15/09/2026, 15/09/26 (dvoznamenkasta godina ispod 70 je ovo stoljece) ili Excel serijski broj }
function DateToIso(const AText: string): string;
var
  T: string;
  P1, P2, D, M, Y: Integer;
begin
  Result := '';
  T := Trim(AText);
  if T = '' then Exit;
  if (Length(T) >= 10) and (T[5] = '-') and (T[8] = '-') then Exit(Copy(T, 1, 10));
  { Excel serijski broj dana (epoha 1899-12-30) }
  if StrToIntDef(T, -1) > 20000 then Exit(FormatDateTime('yyyy-mm-dd', EncodeDate(1899, 12, 30) + StrToInt(T)));
  P1 := Pos('/', T);
  if P1 = 0 then Exit;
  P2 := Pos('/', Copy(T, P1 + 1, MaxInt));
  if P2 = 0 then Exit;
  P2 := P1 + P2;
  D := StrToIntDef(Trim(Copy(T, 1, P1 - 1)), -1);
  M := StrToIntDef(Trim(Copy(T, P1 + 1, P2 - P1 - 1)), -1);
  Y := StrToIntDef(Trim(Copy(T, P2 + 1, 4)), -1);
  if (D < 1) or (M < 1) or (Y < 0) then Exit;
  if Length(Trim(Copy(T, P2 + 1, MaxInt))) = 2 then
  begin
    if Y < 70 then Y := Y + 2000 else Y := Y + 1900;
  end;
  Result := Format('%.4d-%.2d-%.2d', [Y, M, D]);
end;

function Quote(const S: string): string;
begin
  Result := '''' + StringReplace(S, '''', '''''', [rfReplaceAll]) + '''';
end;

function ColIndex(const AHead: array of string; const AName: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(AHead) do
    if SameText(Trim(AHead[I]), AName) then Exit(I);
  Result := -1;
end;

{ xlsx uz csv ima prednost (kao u SmartBetu: preuzima se xlsx, csv je pricuva) }
function PreferredFile(const AFile: string): string;
begin
  Result := AFile;
  if LowerCase(ExtractFileExt(AFile)) = '.csv' then
    if FileExists(ChangeFileExt(AFile, '.xlsx')) then Result := ChangeFileExt(AFile, '.xlsx');
end;

function ImportFixtureFile(ADb: TAppDb; const AFile: string): Integer;
const
  MainBooks: array[0..3] of string = ('Avg', 'Max', 'B365', 'BFE');
  NewBooks: array[0..4] of string = ('Avg', 'Max', 'PS', 'BFE', 'B365');
var
  PricesOk: Boolean;
  BookNames: array of string;
  PH, PD, PA, PO, PU: array of Integer;
  Rows: TaRows;
  Head: array of string;
  Tabs, Have: TStringList;
  I, CDiv, CDate, CHome, CAway, CCountry, CLeague: Integer;
  Dv, Dt, Hm, Aw, Key, Src: string;
  HasTable: Boolean;
  Q: TZQuery;
  FsDot: TFormatSettings;

  function Cell(ARow, AIdx: Integer): string;
  begin
    if (AIdx >= 0) and (AIdx < Length(Rows[ARow])) then Result := Trim(Rows[ARow][AIdx]) else Result := '';
  end;

  { cijena: pozitivan decimalni broj (tocka ili zarez), inace nista }
  function Price(ARow, AIdx: Integer; out AValue: Double): Boolean;
  var
    T: string;
  begin
    Result := False;
    if AIdx < 0 then Exit;
    T := StringReplace(Cell(ARow, AIdx), ',', '.', []);
    if T = '' then Exit;
    AValue := StrToFloatDef(T, -1, FsDot);
    Result := AValue > 0;
  end;

  procedure StorePrices(ARow: Integer; const ADv, ADt, AHm, AAw: string);
  var
    B, B2: Integer;
    H, D, A, O, U: Double;
    OBook, HBook, OuPart: string;
  begin
    HBook := ''; OBook := ''; OuPart := 'NULL, NULL, NULL';
    H := 0; D := 0; A := 0;
    for B := 0 to High(BookNames) do
      if (HBook = '') and Price(ARow, PH[B], H) and Price(ARow, PD[B], D) and Price(ARow, PA[B], A) then HBook := BookNames[B];
    if HBook = '' then Exit;
    for B2 := 0 to High(BookNames) do
      if (OBook = '') and Price(ARow, PO[B2], O) and Price(ARow, PU[B2], U) then OBook := BookNames[B2];
    if OBook <> '' then OuPart := Quote(OBook) + ', ' + FloatToStr(O, FsDot) + ', ' + FloatToStr(U, FsDot);
    ADb.Conn.ExecuteDirect('INSERT OR REPLACE INTO fixture_prices (division, hometeam, awayteam, matchdate, book, h, d, a, ou_book, over, under) VALUES (' +
      Quote(ADv) + ', ' + Quote(AHm) + ', ' + Quote(AAw) + ', ' + Quote(ADt) + ', ' + Quote(HBook) + ', ' + FloatToStr(H, FsDot) + ', ' + FloatToStr(D, FsDot) + ', ' +
      FloatToStr(A, FsDot) + ', ' + OuPart + ')');
  end;

begin
  Result := 0;
  FsDot := DefaultFormatSettings;
  FsDot.DecimalSeparator := '.';
  Src := PreferredFile(AFile);
  if not FileExists(Src) then raise Exception.Create(Tr('There is no layout file: ') + AFile);
  if not ReadAnyFile(Src, ',', Rows) then raise Exception.Create(Tr('The layout cannot be read: ') + Src);
  if Length(Rows) < 2 then Exit;
  Head := Rows[0];
  if (Length(Head) > 0) and (Copy(Head[0], 1, 3) = #$EF#$BB#$BF) then Head[0] := Copy(Head[0], 4, MaxInt);
  CDiv := ColIndex(Head, 'Div'); CDate := ColIndex(Head, 'Date');
  CHome := ColIndex(Head, 'HomeTeam'); CAway := ColIndex(Head, 'AwayTeam');
  CCountry := -1; CLeague := -1;
  if (CDiv < 0) or (CHome < 0) or (CAway < 0) then
  begin
    CDiv := -1;
    CCountry := ColIndex(Head, 'Country'); CLeague := ColIndex(Head, 'League');
    CHome := ColIndex(Head, 'Home'); CAway := ColIndex(Head, 'Away');
    if (CCountry < 0) or (CLeague < 0) or (CHome < 0) or (CAway < 0) then
      raise Exception.Create(Tr('Layout ') + ExtractFileName(Src) + Tr(': unknown header form (needs Div/HomeTeam/AwayTeam or Country/League/Home/Away)'));
  end;
  { kvote kladionica za marketfit: prva kladionica po redu koja ima sve cijene (kao excel/newleagues.fixture_prices) }
  if CDiv >= 0 then
  begin
    SetLength(BookNames, Length(MainBooks));
    for I := 0 to High(MainBooks) do BookNames[I] := MainBooks[I];
  end
  else
  begin
    SetLength(BookNames, Length(NewBooks));
    for I := 0 to High(NewBooks) do BookNames[I] := NewBooks[I];
  end;
  SetLength(PH, Length(BookNames)); SetLength(PD, Length(BookNames)); SetLength(PA, Length(BookNames));
  SetLength(PO, Length(BookNames)); SetLength(PU, Length(BookNames));
  for I := 0 to High(BookNames) do
  begin
    PH[I] := ColIndex(Head, BookNames[I] + 'H'); PD[I] := ColIndex(Head, BookNames[I] + 'D'); PA[I] := ColIndex(Head, BookNames[I] + 'A');
    if CDiv >= 0 then begin PO[I] := ColIndex(Head, BookNames[I] + '>2.5'); PU[I] := ColIndex(Head, BookNames[I] + '<2.5'); end
    else begin PO[I] := -1; PU[I] := -1; end;
  end;
  PricesOk := False;
  for I := 0 to High(BookNames) do if (PH[I] >= 0) and (PD[I] >= 0) and (PA[I] >= 0) then PricesOk := True;
  if PricesOk then
    ADb.Conn.ExecuteDirect('CREATE TABLE IF NOT EXISTS fixture_prices (division TEXT NOT NULL, hometeam TEXT NOT NULL, awayteam TEXT NOT NULL, ' +
      'matchdate TEXT, book TEXT, h REAL, d REAL, a REAL, ou_book TEXT, over REAL, under REAL, PRIMARY KEY (division, hometeam, awayteam))');
  Have := TStringList.Create;
  try
    Have.CaseSensitive := True; Have.Sorted := True; Have.Duplicates := dupIgnore;
    Tabs := ADb.UserTables;
    try
      HasTable := Tabs.IndexOf('fixtures') >= 0;
    finally
      Tabs.Free;
    end;
    if not HasTable then
      ADb.Conn.ExecuteDirect('CREATE TABLE fixtures (division TEXT NOT NULL, matchdate TEXT NOT NULL, hometeam TEXT NOT NULL, awayteam TEXT NOT NULL)')
    else
    begin
      Q := ADb.NewQuery('SELECT division, matchdate, hometeam, awayteam FROM fixtures');
      try
        Q.Open;
        while not Q.Eof do
        begin
          Have.Add(Q.Fields[0].AsString + '|' + Q.Fields[1].AsString + '|' + Q.Fields[2].AsString + '|' + Q.Fields[3].AsString);
          Q.Next;
        end;
      finally
        Q.Free;
      end;
    end;
    ADb.Conn.StartTransaction;
    try
      for I := 1 to High(Rows) do
      begin
        Hm := Cell(I, CHome); Aw := Cell(I, CAway);
        if (Hm = '') or (Aw = '') then Continue;
        if CDiv >= 0 then Dv := UpperCase(Cell(I, CDiv))
        else Dv := DivisionOfLeague(Cell(I, CCountry), Cell(I, CLeague));
        if Dv = '' then Continue;
        Dt := '';
        if CDate >= 0 then Dt := DateToIso(Cell(I, CDate));
        if PricesOk then StorePrices(I, Dv, Dt, Hm, Aw);
        if Dt = '' then Continue;      { utakmica bez datuma ne moze u raspored kola }
        Key := Dv + '|' + Dt + '|' + Hm + '|' + Aw;
        if Have.IndexOf(Key) >= 0 then Continue;
        Have.Add(Key);
        ADb.Conn.ExecuteDirect('INSERT INTO fixtures (division, matchdate, hometeam, awayteam) VALUES (' +
          Quote(Dv) + ', ' + Quote(Dt) + ', ' + Quote(Hm) + ', ' + Quote(Aw) + ')');
        Inc(Result);
      end;
      ADb.Conn.Commit;
    except
      ADb.Conn.Rollback;
      raise;
    end;
  finally
    Have.Free;
  end;
end;

end.
