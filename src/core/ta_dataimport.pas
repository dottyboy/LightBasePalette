unit ta_dataimport;
{ Uvoz utakmica iz football-data datoteka (radna knjiga sezone s listom po ligi, Latest_Results, csv):
  nativna replika excel._ingest (SmartBet). Isti nazivi stupaca, iste kvote i statistika, isto pravilo
  zamjene sezone unutar liga koje datoteka nosi (uz zastitu od nepotpunog preuzimanja) i spajanje bez
  brisanja za djelomicne izvore. Jedina namjerna razlika: prazna ćelija suca postaje NULL, a ne tekst "nan"
  (Python to upisuje, vidi 27 redaka u zivoj bazi). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, StrUtils, ZDataset, fpspreadsheet, fpstypes, fpsallformats, ta_meta, ta_importexport, ta_fixtureimport;

type
  TaImportReport = record
    FileName, Season: string;
    Divisions, Matches, Odds, Stats, Skipped, Added, Updated: Integer;
    Kept: Boolean;
    Problems: string;
    NewDivisions: string;
  end;

{ AMerge: spoji bez brisanja (Latest_Results); inace zamijeni sezonu unutar liga iz datoteke.
  AOnlyIfLarger: preskoci ako baza vec ima barem toliko utakmica. }
function ImportMatchFile(ADb: TAppDb; const AFile, ASeason: string; AMerge, AOnlyIfLarger: Boolean; AMinRatio: Double = 0.5): TaImportReport;
{ sezona kojoj pripada datum (europske sezone se mijenjaju u srpnju) }
{ oznaka lige iz config.DIVISION_NAMES: naziv i drzava; False ako nije poznata }
function DivisionInfo(const ACode: string; out AName, ACountry: string): Boolean;
{ doda sve poznate oznake liga u popis }
procedure AddKnownDivisionCodes(AList: TStrings);
function SeasonOfDate(ADate: TDateTime): string;
function SeasonFromFileName(const AFile: string): string;
{ koliko listova s citljivom tablicom utakmica datoteka ima (radna knjiga mora imati barem jedan) }
function CountMatchSheets(const AFile: string): Integer;
{ redaka s klubovima i rezultatom (Latest_Results); -1 ako stupci nisu oni od rezultata }
function CountResultRows(const AFile: string): Integer;
{ redaka rasporeda (Div, HomeTeam, AwayTeam s popunjenim klubovima); -1 ako to nije raspored }
function CountFixtureRows(const AFile: string): Integer;

type
  TaCountryReport = record
    FileName: string;
    Divisions, Problems, Unknown: string;
    Seasons, Matches, Odds, SkippedRows: Integer;
  end;

{ datoteka drzave (Country, League, Season, ...): radna knjiga s jednim listom po drzavi (ili s vise njih), ili csv.
  Svaka (sezona, liga) se uvozi za sebe; sve cijene su zavrsne i nema statistike. AMerge za Latest_Results. }
function ImportCountryFile(ADb: TAppDb; const AFile: string; AMerge: Boolean): TaCountryReport;
{ koliko listova ima stupce Country, League, Season, Home i Away }
function CountCountrySheets(const AFile: string): Integer;
{ csv koji je izradio preuzimac (HNL, UEFA): bez kvota i statistike; sezona zamjenjuje samo ligu iz stupca Div }
function ImportScrapedFile(ADb: TAppDb; const AFile, ASeason: string): TaImportReport;

implementation

uses
  ta_i18n;


const
  { smartbet/config.py DIVISION_NAMES }
  DivNames: array[0..44, 0..2] of string = (
    ('E0', 'Premier League', 'England'),
    ('E1', 'Championship', 'England'),
    ('E2', 'League One', 'England'),
    ('E3', 'League Two', 'England'),
    ('EC', 'National League', 'England'),
    ('SC0', 'Premiership', 'Scotland'),
    ('SC1', 'Championship', 'Scotland'),
    ('SC2', 'League One', 'Scotland'),
    ('SC3', 'League Two', 'Scotland'),
    ('D1', 'Bundesliga', 'Germany'),
    ('D2', '2. Bundesliga', 'Germany'),
    ('I1', 'Serie A', 'Italy'),
    ('I2', 'Serie B', 'Italy'),
    ('SP1', 'La Liga', 'Spain'),
    ('SP2', 'La Liga 2', 'Spain'),
    ('F1', 'Ligue 1', 'France'),
    ('F2', 'Ligue 2', 'France'),
    ('N1', 'Eredivisie', 'Netherlands'),
    ('B1', 'Jupiler Pro League', 'Belgium'),
    ('P1', 'Liga Portugal', 'Portugal'),
    ('T1', 'Super Lig', 'Turkey'),
    ('G1', 'Super League', 'Greece'),
    ('ARG1', 'Liga Profesional', 'Argentina'),
    ('ARGC', 'Copa de la Liga', 'Argentina'),
    ('AUT1', 'Bundesliga', 'Austria'),
    ('BRA1', 'Serie A', 'Brazil'),
    ('CHN1', 'Super League', 'China'),
    ('DNK1', 'Superliga', 'Denmark'),
    ('FIN1', 'Veikkausliiga', 'Finland'),
    ('IRL1', 'Premier Division', 'Ireland'),
    ('JPN1', 'J1 League', 'Japan'),
    ('MEX1', 'Liga MX', 'Mexico'),
    ('NOR1', 'Eliteserien', 'Norway'),
    ('POL1', 'Ekstraklasa', 'Poland'),
    ('ROU1', 'Superliga', 'Romania'),
    ('RUS1', 'Premier League', 'Russia'),
    ('SWE1', 'Allsvenskan', 'Sweden'),
    ('SWZ1', 'Super League', 'Switzerland'),
    ('USA1', 'MLS', 'USA'),
    ('CRO1', 'Prva HNL', 'Croatia'),
    ('CRO2', 'Druga HNL', 'Croatia'),
    ('CROCUP', 'Hrvatski kup', 'Croatia'),
    ('UCL', 'UEFA Liga prvaka', 'Europa'),
    ('UEL', 'UEFA Europa liga', 'Europa'),
    ('UECL', 'UEFA Konferencijska liga', 'Europa')
  );

type
  TCell = record
    Kind: Byte;            { 0 prazno, 1 broj, 2 tekst, 3 datum }
    Num: Double;
    Txt: string;
  end;
  TRowCells = array of TCell;

  TFrame = class
  public
    Name: string;
    Cols: array of string;
    Rows: array of TRowCells;
    function ColIdx(const AName: string): Integer;
  end;

  TOdd = record
    Bk, Mk, Sel: string;
    Closing: Integer;
    Price: Double;
  end;

  TStat = record
    Referee: string;
    Vals: array[0..14] of Double;
    Nul: array[0..14] of Boolean;
  end;

  TIngRow = record
    Div_, Date, Home, Away: string;
    Fthg, Ftag, Hthg, Htag: Integer;
    HasHt: Boolean;
    Odds: array of TOdd;
    HasStat: Boolean;
    Stat: TStat;
  end;

const
  { excel.STAT_COLUMNS u redoslijedu stupaca tablice match_stats (bez match_id) }
  StatDb: array[0..14] of string = ('referee', 'hxg', 'axg', 'hs', 'as', 'hst', 'ast', 'hc', 'ac', 'hf', 'af', 'hy', 'ay', 'hr', 'ar');
  StatXl: array[0..14] of string = ('Referee', 'HxG', 'AxG', 'HS', 'AS', 'HST', 'AST', 'HC', 'AC', 'HF', 'AF', 'HY', 'AY', 'HR', 'AR');
  CoreNames: array[0..9] of string = ('Div', 'Date', 'HomeTeam', 'AwayTeam', 'FTHG', 'FTAG', 'FTR', 'HTHG', 'HTAG', 'HTR');
  NotBookmakers: array[0..7] of string = ('FT', 'HT', 'AH', 'AHC', 'BbAH', 'BbAHh', 'GB', 'Bb');

function TFrame.ColIdx(const AName: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(Cols) do if Cols[I] = AName then Exit(I);
  Result := -1;
end;

procedure AddKnownDivisionCodes(AList: TStrings);
var
  I: Integer;
begin
  for I := 0 to High(DivNames) do AList.Add(DivNames[I][0]);
end;

function DivisionInfo(const ACode: string; out AName, ACountry: string): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(DivNames) do
    if DivNames[I][0] = ACode then
    begin
      AName := DivNames[I][1]; ACountry := DivNames[I][2];
      Exit(True);
    end;
  Result := False;
end;

function SeasonOfDate(ADate: TDateTime): string;
var
  Y, M, D: Word;
  S: Integer;
begin
  DecodeDate(ADate, Y, M, D);
  if M >= 7 then S := Y else S := Y - 1;
  Result := Format('%d-%d', [S, S + 1]);
end;

function SeasonFromFileName(const AFile: string): string;
var
  S: string;
  I: Integer;
begin
  Result := '';
  S := ChangeFileExt(ExtractFileName(AFile), '');
  for I := 1 to Length(S) - 8 do
    if (StrToIntDef(Copy(S, I, 4), -1) >= 0) and (S[I + 4] = '-') and (StrToIntDef(Copy(S, I + 5, 4), -1) >= 0) then
      Exit(Copy(S, I, 9));
end;

{ ---------------- citanje ---------------- }

function TextCell(const S: string): TCell;
begin
  Result.Num := 0; Result.Txt := S;
  if S = '' then Result.Kind := 0 else Result.Kind := 2;
end;

procedure ReadFrames(const AFile: string; AOut: TList);
var
  Ext: string;
  Book: TsWorkbook;
  Sheet: TsWorksheet;
  Cell: PCell;
  W, R, C, LastR, LastC, I: Integer;
  F: TFrame;
  Rows: TaRows;
  Used: Char;
begin
  Ext := LowerCase(ExtractFileExt(AFile));
  if (Ext = '.xlsx') or (Ext = '.xls') or (Ext = '.ods') then
  begin
    Book := TsWorkbook.Create;
    try
      Book.ReadFromFile(AFile);
      for W := 0 to Book.GetWorksheetCount - 1 do
      begin
        Sheet := Book.GetWorksheetByIndex(W);
        LastR := Sheet.GetLastRowIndex;
        LastC := Sheet.GetLastColIndex;
        if (LastR < 1) or (LastC < 0) then Continue;
        F := TFrame.Create;
        F.Name := Sheet.Name;
        SetLength(F.Cols, LastC + 1);
        for C := 0 to LastC do
        begin
          Cell := Sheet.FindCell(0, C);
          if Cell = nil then F.Cols[C] := '' else F.Cols[C] := Trim(Sheet.ReadAsText(Cell));
        end;
        SetLength(F.Rows, LastR);
        for R := 1 to LastR do
        begin
          SetLength(F.Rows[R - 1], LastC + 1);
          for C := 0 to LastC do
          begin
            Cell := Sheet.FindCell(R, C);
            F.Rows[R - 1][C].Kind := 0; F.Rows[R - 1][C].Num := 0; F.Rows[R - 1][C].Txt := '';
            if Cell = nil then Continue;
            case Cell^.ContentType of
              cctNumber: begin F.Rows[R - 1][C].Kind := 1; F.Rows[R - 1][C].Num := Cell^.NumberValue; end;
              cctDateTime: begin F.Rows[R - 1][C].Kind := 3; F.Rows[R - 1][C].Num := Cell^.DateTimeValue; end;
              cctBool: begin F.Rows[R - 1][C].Kind := 1; F.Rows[R - 1][C].Num := Ord(Cell^.BoolValue); end;
              cctUTF8String: F.Rows[R - 1][C] := TextCell(Cell^.UTF8StringValue);
              cctEmpty: ;
            else
              F.Rows[R - 1][C] := TextCell(Sheet.ReadAsText(Cell));
            end;
          end;
        end;
        AOut.Add(F);
      end;
    finally
      Book.Free;
    end;
  end
  else
  begin
    if not ReadCsvFile(AFile, ',', Rows, Used) or (Length(Rows) < 2) then Exit;
    F := TFrame.Create;
    F.Name := '';
    SetLength(F.Cols, Length(Rows[0]));
    for C := 0 to High(Rows[0]) do
    begin
      F.Cols[C] := Trim(Rows[0][C]);
      if (C = 0) and (Copy(F.Cols[C], 1, 3) = #$EF#$BB#$BF) then F.Cols[C] := Copy(F.Cols[C], 4, MaxInt);
    end;
    SetLength(F.Rows, Length(Rows) - 1);
    for R := 1 to High(Rows) do
    begin
      SetLength(F.Rows[R - 1], Length(F.Cols));
      for C := 0 to High(F.Cols) do
        if C < Length(Rows[R]) then F.Rows[R - 1][C] := TextCell(Rows[R][C])
        else F.Rows[R - 1][C] := TextCell('');
    end;
    AOut.Add(F);
  end;
  I := 0;
  if I = 1 then Exit;
end;

{ ---------------- pretvorbe celija (excel._to_*) ---------------- }

function FloatOfText(const S: string; out V: Double): Boolean;
var
  Fs: TFormatSettings;
begin
  Fs := DefaultFormatSettings;
  Fs.DecimalSeparator := '.';
  Result := TryStrToFloat(Trim(S), V, Fs);
end;

function CellFloat(const C: TCell; out V: Double): Boolean;
begin
  Result := False;
  case C.Kind of
    1, 3: begin V := C.Num; Result := True; end;
    2: Result := FloatOfText(C.Txt, V);
  end;
end;

function CellInt(const C: TCell; out V: Integer): Boolean;
var
  D: Double;
begin
  Result := CellFloat(C, D);
  if Result then V := Trunc(D);
end;

function CellOdds(const C: TCell; out V: Double): Boolean;
begin
  Result := CellFloat(C, V) and (V > 1.0) and (V < 1000.0);
end;

function CellText(const C: TCell): string;
var
  Fs: TFormatSettings;
begin
  case C.Kind of
    2: Result := Trim(C.Txt);
    1: begin
         Fs := DefaultFormatSettings; Fs.DecimalSeparator := '.';
         if Frac(C.Num) = 0 then Result := FloatToStr(C.Num, Fs) + '.0' else Result := FloatToStr(C.Num, Fs);
       end;
    3: Result := FormatDateTime('yyyy-mm-dd', C.Num);
  else
    Result := '';
  end;
end;

function DateOfCell(const C: TCell): string;
var
  T: string;
  P1, P2, D, M, Y: Integer;
begin
  Result := '';
  case C.Kind of
    3: Exit(FormatDateTime('yyyy-mm-dd', Trunc(C.Num)));
    1: begin
         if (C.Num > 1) and (C.Num < 200000) then Exit(FormatDateTime('yyyy-mm-dd', EncodeDate(1899, 12, 30) + Trunc(C.Num)));
         Exit;
       end;
    0: Exit;
  end;
  T := Trim(C.Txt);
  if T = '' then Exit;
  if (Length(T) >= 10) and (T[5] = '-') and (T[8] = '-') then Exit(Copy(T, 1, 10));
  P1 := Pos('/', T);
  if P1 = 0 then Exit;
  P2 := Pos('/', Copy(T, P1 + 1, MaxInt));
  if P2 = 0 then Exit;
  P2 := P1 + P2;
  D := StrToIntDef(Trim(Copy(T, 1, P1 - 1)), -1);
  M := StrToIntDef(Trim(Copy(T, P1 + 1, P2 - P1 - 1)), -1);
  Y := StrToIntDef(Trim(Copy(T, P2 + 1, MaxInt)), -1);
  if (D < 1) or (M < 1) or (Y < 0) then Exit;
  if Length(Trim(Copy(T, P2 + 1, MaxInt))) = 2 then
  begin
    { arhiva pocinje 1993: dvoznamenkasta godina ispod 70 je ovo stoljece }
    if Y < 70 then Y := Y + 2000 else Y := Y + 1900;
  end;
  if (M > 12) or (D > 31) then Exit;
  Result := Format('%.4d-%.2d-%.2d', [Y, M, D]);
end;

function ResultOf(AHome, AAway: Integer): string;
begin
  if AHome > AAway then Result := 'H' else if AHome = AAway then Result := 'D' else Result := 'A';
end;

{ ---------------- zaglavlja (normalise_columns, odds_columns) ---------------- }

procedure NormaliseColumns(F: TFrame);
const
  Aliases: array[0..9] of string = (
    'div|division_id|division|league', 'date|matchdate|match_date', 'hometeam|home_team|home|ht', 'awayteam|away_team|away|at',
    'fthg|hg|homegoals', 'ftag|ag|awaygoals', 'ftr|res|result', 'hthg|hthg1', 'htag', 'htr');
var
  I, J, K, P: Integer;
  Canon, Al, Orig: string;
  Parts: TStringList;
  Used: TStringList;
  Idx: Integer;
begin
  Used := TStringList.Create;
  Parts := TStringList.Create;
  try
    for I := 0 to High(CoreNames) do
    begin
      Canon := CoreNames[I];
      if F.ColIdx(Canon) >= 0 then Continue;
      Parts.Clear;
      Parts.Delimiter := '|'; Parts.StrictDelimiter := True; Parts.DelimitedText := Aliases[I];
      for J := 0 to Parts.Count - 1 do
      begin
        Al := Parts[J];
        Idx := -1;
        { lower[c.lower()] = c: posljednji stupac s tim nazivom }
        for K := 0 to High(F.Cols) do if LowerCase(F.Cols[K]) = Al then Idx := K;
        if Idx < 0 then Continue;
        Orig := F.Cols[Idx];
        if Used.IndexOf(Orig) >= 0 then Continue;
        Used.Add(Orig);
        F.Cols[Idx] := Canon;
        Break;
      end;
    end;
    P := 0;
    if P = 1 then Exit;
  finally
    Parts.Free; Used.Free;
  end;
end;

type
  TOddCol = record
    Col: Integer;
    Bk, Mk, Sel: string;
    Closing: Boolean;
  end;
  TOddCols = array of TOddCol;

function IsNotBook(const S: string): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(NotBookmakers) do if NotBookmakers[I] = S then Exit(True);
  Result := False;
end;

function OddsColumns(F: TFrame): TOddCols;
var
  Trios: TStringList;
  I, N: Integer;
  Pre, Col, BK: string;
  Closing: Boolean;

  procedure Add(ACol: Integer; const ABk, AMk, ASel: string; AClosing: Boolean);
  begin
    SetLength(Result, N + 1);
    Result[N].Col := ACol; Result[N].Bk := ABk; Result[N].Mk := AMk; Result[N].Sel := ASel; Result[N].Closing := AClosing;
    Inc(N);
  end;

begin
  N := 0;
  SetLength(Result, 0);
  Trios := TStringList.Create;
  try
    Trios.CaseSensitive := True; Trios.Sorted := True; Trios.Duplicates := dupIgnore;
    for I := 0 to High(F.Cols) do
    begin
      Col := F.Cols[I];
      if (Length(Col) > 1) and (Col[Length(Col)] = 'H') then
      begin
        Pre := Copy(Col, 1, Length(Col) - 1);
        if (F.ColIdx(Pre + 'D') >= 0) and (F.ColIdx(Pre + 'A') >= 0) and not IsNotBook(Pre) then Trios.Add(Pre);
      end;
    end;
    for I := 0 to Trios.Count - 1 do
    begin
      Pre := Trios[I];
      Closing := (Pre[Length(Pre)] = 'C') and (Trios.IndexOf(Copy(Pre, 1, Length(Pre) - 1)) >= 0);
      if Closing then BK := Copy(Pre, 1, Length(Pre) - 1) else BK := Pre;
      Add(F.ColIdx(Pre + 'H'), BK, '1X2', '1', Closing);
      Add(F.ColIdx(Pre + 'D'), BK, '1X2', 'X', Closing);
      Add(F.ColIdx(Pre + 'A'), BK, '1X2', '2', Closing);
    end;
    for I := 0 to High(F.Cols) do
    begin
      Col := F.Cols[I];
      if (Length(Col) > 4) and (Copy(Col, Length(Col) - 3, 4) = '>2.5') then
      begin
        Pre := Copy(Col, 1, Length(Col) - 4);
        if F.ColIdx(Pre + '<2.5') < 0 then Continue;
        Closing := (Pre <> '') and (Pre[Length(Pre)] = 'C');
        if Closing then BK := Copy(Pre, 1, Length(Pre) - 1) else BK := Pre;
        Add(I, BK, 'OU25', 'Over 2.5', Closing);
        Add(F.ColIdx(Pre + '<2.5'), BK, 'OU25', 'Under 2.5', Closing);
      end;
    end;
  finally
    Trios.Free;
  end;
end;

{ ---------------- baza ---------------- }

function Q_(const S: string): string;
begin
  Result := '''' + StringReplace(S, '''', '''''', [rfReplaceAll]) + '''';
end;

procedure EnsureDivisions(ADb: TAppDb; ADivs: TStringList; var ANew: string);
var
  Q: TZQuery;
  Have: TStringList;
  I, J: Integer;
  Nm, Ct: string;
begin
  Have := TStringList.Create;
  try
    Have.CaseSensitive := True;
    Q := ADb.NewQuery('SELECT division FROM divisions');
    try
      Q.Open;
      while not Q.Eof do begin Have.Add(Q.Fields[0].AsString); Q.Next; end;
    finally
      Q.Free;
    end;
    for I := 0 to ADivs.Count - 1 do
    begin
      if Have.IndexOf(ADivs[I]) >= 0 then Continue;
      Nm := ADivs[I]; Ct := 'Nepoznato';
      for J := 0 to High(DivNames) do
        if DivNames[J][0] = ADivs[I] then begin Nm := DivNames[J][1]; Ct := DivNames[J][2]; Break; end;
      ADb.Conn.ExecuteDirect('INSERT OR IGNORE INTO divisions (division, division_name, country) VALUES (' + Q_(ADivs[I]) + ',' + Q_(Nm) + ',' + Q_(Ct) + ')');
      if ANew <> '' then ANew := ANew + ',';
      ANew := ANew + ADivs[I];
    end;
  finally
    Have.Free;
  end;
end;

function ScalarInt(ADb: TAppDb; const ASql: string): Integer;
var
  Q: TZQuery;
begin
  Q := ADb.NewQuery(ASql);
  try
    Q.Open;
    Result := Q.Fields[0].AsInteger;
  finally
    Q.Free;
  end;
end;

{ Promjena u trazenom prozoru: leg se ponovno veze uz utakmicu najblizu kolu iz ref_date (isto kao poravnanje) }
procedure DetachLegs(ADb: TAppDb; const ASeason: string; ALegs: TStringList);
var
  Q: TZQuery;
begin
  Q := ADb.NewQuery('SELECT leg_id FROM slip_legs WHERE match_id IN (SELECT match_id FROM matches WHERE season = ' + Q_(ASeason) + ')');
  try
    Q.Open;
    while not Q.Eof do begin ALegs.Add(Q.Fields[0].AsString); Q.Next; end;
  finally
    Q.Free;
  end;
  if ALegs.Count > 0 then
    ADb.Conn.ExecuteDirect('UPDATE slip_legs SET match_id = NULL WHERE leg_id IN (SELECT leg_id FROM slip_legs WHERE match_id IN (SELECT match_id FROM matches WHERE season = ' + Q_(ASeason) + '))');
end;

procedure ReattachLegs(ADb: TAppDb; const ASeason: string; ALegs: TStringList);
var
  I: Integer;
begin
  for I := 0 to ALegs.Count - 1 do
    ADb.Conn.ExecuteDirect('UPDATE slip_legs SET match_id = (SELECT m.match_id FROM matches m, slips s WHERE s.slip_id = slip_legs.slip_id ' +
      'AND m.season = ' + Q_(ASeason) + ' AND m.division = slip_legs.division AND m.hometeam = slip_legs.hometeam AND m.awayteam = slip_legs.awayteam ' +
      'AND m.matchdate >= date(s.ref_date, ''-3 days'') AND m.matchdate <= date(s.ref_date, ''+45 days'') ORDER BY m.matchdate LIMIT 1) ' +
      'WHERE leg_id = ' + ALegs[I]);
end;

function CountMatchSheets(const AFile: string): Integer;
var
  Frames: TList;
  I: Integer;
  F: TFrame;
begin
  Result := 0;
  Frames := TList.Create;
  try
    ReadFrames(AFile, Frames);
    for I := 0 to Frames.Count - 1 do
    begin
      F := TFrame(Frames[I]);
      NormaliseColumns(F);
      if (F.ColIdx('HomeTeam') >= 0) and (F.ColIdx('AwayTeam') >= 0) and (F.ColIdx('Date') >= 0) then Inc(Result);
    end;
  finally
    for I := 0 to Frames.Count - 1 do TObject(Frames[I]).Free;
    Frames.Free;
  end;
end;

function CountResultRows(const AFile: string): Integer;
var
  Frames: TList;
  I, R: Integer;
  F: TFrame;
  Iv: Integer;
  Ch, Ca, Cf, Cg: Integer;
begin
  Result := -1;
  Frames := TList.Create;
  try
    ReadFrames(AFile, Frames);
    if Frames.Count = 0 then Exit;
    F := TFrame(Frames[0]);
    NormaliseColumns(F);
    Ch := F.ColIdx('HomeTeam'); Ca := F.ColIdx('AwayTeam'); Cf := F.ColIdx('FTHG'); Cg := F.ColIdx('FTAG');
    if (F.ColIdx('Div') < 0) or (Ch < 0) or (Ca < 0) or (Cf < 0) then Exit;
    Result := 0;
    for R := 0 to High(F.Rows) do
      if (CellText(F.Rows[R][Ch]) <> '') and (CellText(F.Rows[R][Ca]) <> '') and CellInt(F.Rows[R][Cf], Iv) and
         ((Cg < 0) or CellInt(F.Rows[R][Cg], Iv)) then Inc(Result);
  finally
    for I := 0 to Frames.Count - 1 do TObject(Frames[I]).Free;
    Frames.Free;
  end;
end;

function CountFixtureRows(const AFile: string): Integer;
var
  Frames: TList;
  I, R, Ch, Ca: Integer;
  F: TFrame;
begin
  Result := -1;
  Frames := TList.Create;
  try
    ReadFrames(AFile, Frames);
    if Frames.Count = 0 then Exit;
    F := TFrame(Frames[0]);
    NormaliseColumns(F);
    Ch := F.ColIdx('HomeTeam'); Ca := F.ColIdx('AwayTeam');
    if (F.ColIdx('Div') < 0) or (Ch < 0) or (Ca < 0) then Exit;
    Result := 0;
    for R := 0 to High(F.Rows) do
      if (CellText(F.Rows[R][Ch]) <> '') and (CellText(F.Rows[R][Ca]) <> '') then Inc(Result);
  finally
    for I := 0 to Frames.Count - 1 do TObject(Frames[I]).Free;
    Frames.Free;
  end;
end;

function IngestFrames(ADb: TAppDb; const AFile, ASeason: string; AFrames: TList; AMerge, AOnlyIfLarger: Boolean; AMinRatio: Double;
  AWithStats, AClosingOnly: Boolean; AWithOdds: Boolean = True): TaImportReport;
var
  Frames: TList;
  F: TFrame;
  Rows: array of TIngRow;
  Keys: TStringList;
  NRows, FI, RI, I, K, CI: Integer;
  OddCols: TOddCols;
  StatCol: array[0..14] of Integer;
  AnyStat: Boolean;
  Rec: TRowCells;
  Row: TIngRow;
  Dv, Dt, Hm, Aw, Key, Hint: string;
  Fthg, Ftag, Hthg, Htag, Iv: Integer;
  Pv: Double;
  C0: TCell;
  Season: string;
  DivSet: TStringList;
  Scope: string;
  Existing, ExistingBefore, Before, After: Integer;
  Ids: TStringList;
  Q, Qo: TZQuery;
  Legs: TStringList;
  HasHt: Boolean;
  J, Pos_: Integer;
  Found: Boolean;
  NewDivs: string;

  procedure Fill(var R: TIngRow);
  var
    S: Integer;
    Sv: TStat;
    Any: Boolean;
    V: Double;
    Oi, Pi: Integer;
    Fnd: Boolean;
    Od: TOdd;
  begin
    for Oi := 0 to High(OddCols) do
    begin
      if not CellOdds(Rec[OddCols[Oi].Col], V) then Continue;
      Od.Bk := OddCols[Oi].Bk; Od.Mk := OddCols[Oi].Mk; Od.Sel := OddCols[Oi].Sel;
      Od.Closing := Ord(OddCols[Oi].Closing or AClosingOnly); Od.Price := V;
      { ista kvota (kladionica, trziste, izbor, zatvaranje) se prepisuje, ostale ostaju }
      Fnd := False;
      for Pi := 0 to High(R.Odds) do
        if (R.Odds[Pi].Bk = Od.Bk) and (R.Odds[Pi].Mk = Od.Mk) and (R.Odds[Pi].Sel = Od.Sel) and (R.Odds[Pi].Closing = Od.Closing) then
        begin
          R.Odds[Pi] := Od; Fnd := True; Break;
        end;
      if not Fnd then
      begin
        SetLength(R.Odds, Length(R.Odds) + 1);
        R.Odds[High(R.Odds)] := Od;
      end;
    end;
    if AnyStat then
    begin
      Any := False;
      for S := 0 to 14 do
      begin
        Sv.Nul[S] := True; Sv.Vals[S] := 0;
        if StatCol[S] < 0 then Continue;
        if Rec[StatCol[S]].Kind <> 0 then Any := True;
      end;
      if Any then
      begin
        Sv.Referee := '';
        for S := 0 to 14 do
        begin
          if StatCol[S] < 0 then Continue;
          if S = 0 then
          begin
            Sv.Referee := CellText(Rec[StatCol[S]]);
            Sv.Nul[0] := Sv.Referee = '';
          end
          else if (S = 1) or (S = 2) then
          begin
            if CellFloat(Rec[StatCol[S]], V) then begin Sv.Vals[S] := V; Sv.Nul[S] := False; end;
          end
          else if CellInt(Rec[StatCol[S]], Iv) then begin Sv.Vals[S] := Iv; Sv.Nul[S] := False; end;
        end;
        R.Stat := Sv; R.HasStat := True;
      end;
    end;
  end;

begin
  FillChar(Result, SizeOf(Result), 0);
  Result.FileName := ExtractFileName(AFile);
  Result.Kept := True;
  Season := ASeason;
  if Season = '' then Season := SeasonFromFileName(AFile);
  if Season = '' then raise Exception.Create(Result.FileName + Tr(': the season cannot be read from the name'));
  Result.Season := Season;
  Frames := AFrames;
  Keys := TStringList.Create;
  DivSet := TStringList.Create;
  Legs := TStringList.Create;
  Ids := TStringList.Create;
  try
    Keys.CaseSensitive := True;
    DivSet.CaseSensitive := True; DivSet.Sorted := True; DivSet.Duplicates := dupIgnore;
    NRows := 0;
    for FI := 0 to Frames.Count - 1 do
    begin
      F := TFrame(Frames[FI]);
      NormaliseColumns(F);
      if (F.ColIdx('HomeTeam') < 0) or (F.ColIdx('AwayTeam') < 0) or (F.ColIdx('Date') < 0) then Continue;
      if AWithOdds then OddCols := OddsColumns(F) else SetLength(OddCols, 0);
      for K := 0 to 14 do StatCol[K] := F.ColIdx(StatXl[K]);
      AnyStat := False;
      for K := 0 to 14 do if AWithStats and (StatCol[K] >= 0) then AnyStat := True;
      Inc(Result.Divisions);
      Hint := F.Name;
      for RI := 0 to High(F.Rows) do
      begin
        Rec := F.Rows[RI];
        CI := F.ColIdx('Div');
        if CI >= 0 then Dv := UpperCase(CellText(Rec[CI])) else Dv := '';
        if Dv = '' then Dv := UpperCase(Trim(Hint));
        Dt := DateOfCell(Rec[F.ColIdx('Date')]);
        Hm := CellText(Rec[F.ColIdx('HomeTeam')]);
        Aw := CellText(Rec[F.ColIdx('AwayTeam')]);
        CI := F.ColIdx('FTHG'); if (CI < 0) or not CellInt(Rec[CI], Fthg) then begin Inc(Result.Skipped); Continue; end;
        CI := F.ColIdx('FTAG'); if (CI < 0) or not CellInt(Rec[CI], Ftag) then begin Inc(Result.Skipped); Continue; end;
        if (Dv = '') or (Dt = '') or (Hm = '') or (Aw = '') then begin Inc(Result.Skipped); Continue; end;
        HasHt := False; Hthg := 0; Htag := 0;
        CI := F.ColIdx('HTHG');
        if (CI >= 0) and CellInt(Rec[CI], Hthg) then
        begin
          CI := F.ColIdx('HTAG');
          if (CI >= 0) and CellInt(Rec[CI], Htag) then HasHt := True;
        end;
        { Python: hthg i htag se citaju neovisno, ali htr samo kad su oba; zapisujemo oba kao u Pythonu }
        Key := Dv + #1 + Dt + #1 + Hm + #1 + Aw;
        Pos_ := Keys.IndexOf(Key);
        FillChar(Row, SizeOf(Row), 0);
        Row.Div_ := Dv; Row.Date := Dt; Row.Home := Hm; Row.Away := Aw; Row.Fthg := Fthg; Row.Ftag := Ftag;
        Row.HasHt := HasHt; Row.Hthg := Hthg; Row.Htag := Htag;
        if Pos_ < 0 then
        begin
          if NRows >= Length(Rows) then SetLength(Rows, Max(256, Length(Rows) * 2));
          Pos_ := NRows;
          Keys.AddObject(Key, TObject(PtrInt(Pos_)));
          Rows[Pos_] := Row;
          Inc(NRows);
          Fill(Rows[Pos_]);
        end
        else
        begin
          Pos_ := PtrInt(Keys.Objects[Keys.IndexOf(Key)]);
          { isti ključ ponovno: zadnji redak pobjeđuje, ali kvote koje nedostaju ne brišu ranije }
          Row.Odds := Rows[Pos_].Odds; Row.HasStat := Rows[Pos_].HasStat; Row.Stat := Rows[Pos_].Stat;
          Rows[Pos_] := Row;
          Fill(Rows[Pos_]);
        end;
      end;
    end;
    if NRows = 0 then raise Exception.Create(Result.FileName + Tr(': no match was read'));
    SetLength(Rows, NRows);
    for I := 0 to NRows - 1 do DivSet.Add(Rows[I].Div_);
    Result.Matches := NRows;
    Scope := 'season = ' + Q_(Season) + ' AND division IN (';
    for I := 0 to DivSet.Count - 1 do
    begin
      if I > 0 then Scope := Scope + ',';
      Scope := Scope + Q_(DivSet[I]);
    end;
    Scope := Scope + ')';
    Existing := ScalarInt(ADb, 'SELECT COUNT(*) FROM matches WHERE ' + Scope);

    ADb.Conn.StartTransaction;
    try
      NewDivs := '';
      if AMerge then
      begin
        EnsureDivisions(ADb, DivSet, NewDivs);
        Before := ScalarInt(ADb, 'SELECT COUNT(*) FROM matches WHERE season = ' + Q_(Season));
      end
      else
      begin
        if (Existing > 0) and (NRows < Existing * AMinRatio) then
        begin
          Result.Kept := False;
          Result.Problems := Format('odbijeno: izvor nudi %d utakmica, baza ih ima %d - izgleda kao nepotpuno preuzimanje', [NRows, Existing]);
          ADb.Conn.Rollback;
          Exit;
        end;
        if AOnlyIfLarger and (Existing >= NRows) then
        begin
          Result.Kept := False;
          Result.Problems := Format('preskoceno: baza vec ima %d utakmica, izvor nudi %d', [Existing, NRows]);
          ADb.Conn.Rollback;
          Exit;
        end;
        EnsureDivisions(ADb, DivSet, NewDivs);
        DetachLegs(ADb, Season, Legs);
        ADb.Conn.ExecuteDirect('DELETE FROM match_odds WHERE match_id IN (SELECT match_id FROM matches WHERE ' + Scope + ')');
        ADb.Conn.ExecuteDirect('DELETE FROM match_stats WHERE match_id IN (SELECT match_id FROM matches WHERE ' + Scope + ')');
        ADb.Conn.ExecuteDirect('DELETE FROM matches WHERE ' + Scope);
      end;
      Result.NewDivisions := NewDivs;

      Q := ADb.NewQuery('INSERT INTO matches (division, matchdate, season, hometeam, awayteam, fthg, ftag, ftr, hthg, htag, htr) ' +
        'VALUES (:d, :m, :s, :h, :a, :fh, :fa, :fr, :hh, :ha, :hr)' +
        IfThen(AMerge, ' ON CONFLICT (division, matchdate, hometeam, awayteam) DO UPDATE SET season = excluded.season, fthg = excluded.fthg, ' +
          'ftag = excluded.ftag, ftr = excluded.ftr, hthg = excluded.hthg, htag = excluded.htag, htr = excluded.htr', ''));
      try
        for I := 0 to NRows - 1 do
        begin
          Q.ParamByName('d').AsString := Rows[I].Div_; Q.ParamByName('m').AsString := Rows[I].Date;
          Q.ParamByName('s').AsString := Season; Q.ParamByName('h').AsString := Rows[I].Home; Q.ParamByName('a').AsString := Rows[I].Away;
          Q.ParamByName('fh').AsInteger := Rows[I].Fthg; Q.ParamByName('fa').AsInteger := Rows[I].Ftag;
          Q.ParamByName('fr').AsString := ResultOf(Rows[I].Fthg, Rows[I].Ftag);
          if Rows[I].HasHt then
          begin
            Q.ParamByName('hh').AsInteger := Rows[I].Hthg; Q.ParamByName('ha').AsInteger := Rows[I].Htag;
            Q.ParamByName('hr').AsString := ResultOf(Rows[I].Hthg, Rows[I].Htag);
          end
          else
          begin
            Q.ParamByName('hh').Clear; Q.ParamByName('ha').Clear; Q.ParamByName('hr').Clear;
          end;
          Q.ExecSQL;
        end;
      finally
        Q.Free;
      end;
      if AMerge then
      begin
        After := ScalarInt(ADb, 'SELECT COUNT(*) FROM matches WHERE season = ' + Q_(Season));
        Result.Added := After - Before;
        Result.Updated := NRows - Result.Added;
      end
      else ReattachLegs(ADb, Season, Legs);

      { identifikatori utakmica ove sezone }
      Ids.CaseSensitive := True; Ids.Sorted := True; Ids.Duplicates := dupIgnore;
      Q := ADb.NewQuery('SELECT match_id, division, matchdate, hometeam, awayteam FROM matches WHERE ' +
        IfThen(AMerge, 'season = ' + Q_(Season), Scope));
      try
        Q.Open;
        while not Q.Eof do
        begin
          Ids.AddObject(Q.Fields[1].AsString + #1 + Q.Fields[2].AsString + #1 + Q.Fields[3].AsString + #1 + Q.Fields[4].AsString,
            TObject(PtrInt(Q.Fields[0].AsInteger)));
          Q.Next;
        end;
      finally
        Q.Free;
      end;

      Qo := ADb.NewQuery('INSERT OR REPLACE INTO match_odds (match_id, bookmaker, market, selection, odds, closing) VALUES (:i, :b, :m, :s, :o, :c)');
      try
        for I := 0 to NRows - 1 do
        begin
          J := Ids.IndexOf(Rows[I].Div_ + #1 + Rows[I].Date + #1 + Rows[I].Home + #1 + Rows[I].Away);
          if J < 0 then Continue;
          for K := 0 to High(Rows[I].Odds) do
          begin
            Qo.ParamByName('i').AsInteger := PtrInt(Ids.Objects[J]);
            Qo.ParamByName('b').AsString := Rows[I].Odds[K].Bk; Qo.ParamByName('m').AsString := Rows[I].Odds[K].Mk;
            Qo.ParamByName('s').AsString := Rows[I].Odds[K].Sel; Qo.ParamByName('o').AsFloat := Rows[I].Odds[K].Price;
            Qo.ParamByName('c').AsInteger := Rows[I].Odds[K].Closing;
            Qo.ExecSQL;
            Inc(Result.Odds);
          end;
        end;
      finally
        Qo.Free;
      end;
      Qo := ADb.NewQuery('INSERT OR REPLACE INTO match_stats (match_id, referee, hxg, axg, hs, "as", hst, ast, hc, ac, hf, af, hy, ay, hr, ar) ' +
        'VALUES (:i, :p0, :p1, :p2, :p3, :p4, :p5, :p6, :p7, :p8, :p9, :p10, :p11, :p12, :p13, :p14)');
      try
        for I := 0 to NRows - 1 do
        begin
          if not Rows[I].HasStat then Continue;
          J := Ids.IndexOf(Rows[I].Div_ + #1 + Rows[I].Date + #1 + Rows[I].Home + #1 + Rows[I].Away);
          if J < 0 then Continue;
          Qo.ParamByName('i').AsInteger := PtrInt(Ids.Objects[J]);
          for K := 0 to 14 do
          begin
            if Rows[I].Stat.Nul[K] then Qo.ParamByName('p' + IntToStr(K)).Clear
            else if K = 0 then Qo.ParamByName('p0').AsString := Rows[I].Stat.Referee
            else if (K = 1) or (K = 2) then Qo.ParamByName('p' + IntToStr(K)).AsFloat := Rows[I].Stat.Vals[K]
            else Qo.ParamByName('p' + IntToStr(K)).AsInteger := Trunc(Rows[I].Stat.Vals[K]);
          end;
          Qo.ExecSQL;
          Inc(Result.Stats);
        end;
      finally
        Qo.Free;
      end;
      ADb.Conn.Commit;
    except
      ADb.Conn.Rollback;
      raise;
    end;
    C0.Kind := 0; Pv := 0; Found := False; ExistingBefore := 0;
    if Found then Exit;
  finally
    Keys.Free; DivSet.Free; Legs.Free; Ids.Free;
  end;
end;

function SeasonCellText(const C: TCell): string;
begin
  if (C.Kind = 1) and (Frac(C.Num) = 0) then Result := IntToStr(Trunc(C.Num))
  else Result := CellText(C);
end;

{ newleagues.normalise_season: 2012/2013 i 2012-2013 -> 2012-2013, 2026 ostaje 2026, inace '' }
function NormaliseSeason(const AText: string): string;
var
  T: string;
  I: Integer;
  AllDig: Boolean;
begin
  Result := '';
  T := Trim(AText);
  if (Length(T) = 9) and ((T[5] = '/') or (T[5] = '-')) and (StrToIntDef(Copy(T, 1, 4), -1) >= 0) and (StrToIntDef(Copy(T, 6, 4), -1) >= 0) then
    Exit(Copy(T, 1, 4) + '-' + Copy(T, 6, 4));
  if Length(T) = 4 then
  begin
    AllDig := True;
    for I := 1 to 4 do if not (T[I] in ['0'..'9']) then AllDig := False;
    if AllDig then Result := T;
  end;
end;

{ newleagues.ODDS_COLUMNS: zavrsne cijene se preimenuju u uobicajena imena (C se vraca preko closing_only) }
function RenameCountryColumn(const AName: string): string;
const
  From_: array[0..14] of string = ('PSCH', 'PSCD', 'PSCA', 'MaxCH', 'MaxCD', 'MaxCA', 'AvgCH', 'AvgCD', 'AvgCA', 'BFECH', 'BFECD', 'BFECA', 'B365CH', 'B365CD', 'B365CA');
  To_: array[0..14] of string = ('PSH', 'PSD', 'PSA', 'MaxH', 'MaxD', 'MaxA', 'AvgH', 'AvgD', 'AvgA', 'BFEH', 'BFED', 'BFEA', 'B365H', 'B365D', 'B365A');
var
  I: Integer;
begin
  for I := 0 to High(From_) do if From_[I] = AName then Exit(To_[I]);
  Result := AName;
end;

function CountCountrySheets(const AFile: string): Integer;
var
  Frames: TList;
  I: Integer;
  F: TFrame;
begin
  Result := 0;
  Frames := TList.Create;
  try
    ReadFrames(AFile, Frames);
    for I := 0 to Frames.Count - 1 do
    begin
      F := TFrame(Frames[I]);
      if (F.ColIdx('Country') >= 0) and (F.ColIdx('League') >= 0) and (F.ColIdx('Season') >= 0) and (F.ColIdx('Home') >= 0) and (F.ColIdx('Away') >= 0) then Inc(Result);
    end;
  finally
    for I := 0 to Frames.Count - 1 do TObject(Frames[I]).Free;
    Frames.Free;
  end;
end;

{ redoslijed po bajtovima (isto kao Pythonovo sortiranje tekstova), ne po jezicnom pravilu sustava }
function OrdinalCompare(List: TStringList; Index1, Index2: Integer): Integer;
begin
  Result := CompareStr(List[Index1], List[Index2]);
end;

procedure ImportCountryFrame(ADb: TAppDb; F: TFrame; const ALabel: string; AMerge: Boolean; var Rep: TaCountryReport);
var
  CCountry, CLeague, CSeason, R, C, N, G, K: Integer;
  Dv, Se, Key: string;
  Groups: TStringList;
  Idx: TList;
  Keep: array of Integer;
  Sub: TFrame;
  Frames: TList;
  Card: TaImportReport;
  Unknown: TStringList;
  Usable: Integer;
  Names: TStringList;
begin
  CCountry := F.ColIdx('Country'); CLeague := F.ColIdx('League'); CSeason := F.ColIdx('Season');
  if (CCountry < 0) or (CLeague < 0) or (CSeason < 0) then
    raise Exception.Create(ALabel + Tr(': the columns Country, League or Season are missing'));
  Groups := TStringList.Create;
  Unknown := TStringList.Create;
  Names := TStringList.Create;
  try
    Groups.CaseSensitive := True;
    Unknown.CaseSensitive := True; Unknown.Sorted := True; Unknown.Duplicates := dupIgnore;
    Usable := 0;
    for R := 0 to High(F.Rows) do
    begin
      Dv := DivisionOfLeague(CellText(F.Rows[R][CCountry]), CellText(F.Rows[R][CLeague]));
      if Dv = '' then Unknown.Add(CellText(F.Rows[R][CCountry]) + ' / ' + CellText(F.Rows[R][CLeague]));
      Se := NormaliseSeason(SeasonCellText(F.Rows[R][CSeason]));
      if (Dv = '') or (Se = '') then begin Inc(Rep.SkippedRows); Continue; end;
      Key := Se + #1 + Dv;
      K := Groups.IndexOf(Key);
      if K < 0 then K := Groups.AddObject(Key, TList.Create);
      TList(Groups.Objects[K]).Add(Pointer(PtrInt(R)));
      Inc(Usable);
    end;
    if Usable = 0 then raise Exception.Create(ALabel + Tr(': no league was recognized'));
    Groups.CustomSort(@OrdinalCompare);
    for K := 0 to Unknown.Count - 1 do
    begin
      if Rep.Unknown <> '' then Rep.Unknown := Rep.Unknown + '; ';
      Rep.Unknown := Rep.Unknown + Unknown[K];
    end;
    { stupci koji ostaju: bez Country, League, Season, Time; zavrsne cijene preimenovane }
    SetLength(Keep, 0);
    for C := 0 to High(F.Cols) do
      if (F.Cols[C] <> 'Country') and (F.Cols[C] <> 'League') and (F.Cols[C] <> 'Season') and (F.Cols[C] <> 'Time') then
      begin
        SetLength(Keep, Length(Keep) + 1);
        Keep[High(Keep)] := C;
      end;
    for G := 0 to Groups.Count - 1 do
    begin
      Key := Groups[G];
      Se := Copy(Key, 1, Pos(#1, Key) - 1);
      Dv := Copy(Key, Pos(#1, Key) + 1, MaxInt);
      Idx := TList(Groups.Objects[G]);
      Sub := TFrame.Create;
      Frames := TList.Create;
      try
        Sub.Name := Dv;
        SetLength(Sub.Cols, Length(Keep));
        for C := 0 to High(Keep) do Sub.Cols[C] := RenameCountryColumn(F.Cols[Keep[C]]);
        SetLength(Sub.Rows, Idx.Count);
        for R := 0 to Idx.Count - 1 do
        begin
          SetLength(Sub.Rows[R], Length(Keep));
          for C := 0 to High(Keep) do Sub.Rows[R][C] := F.Rows[PtrInt(Idx[R])][Keep[C]];
        end;
        Frames.Add(Sub);
        try
          Card := IngestFrames(ADb, ALabel + ':' + Dv, Se, Frames, AMerge, False, 0.5, False, True);
          if not Card.Kept then
          begin
            if Rep.Problems <> '' then Rep.Problems := Rep.Problems + '; ';
            Rep.Problems := Rep.Problems + Dv + ' ' + Se + ': ' + Card.Problems;
          end
          else
          begin
            Inc(Rep.Seasons); Inc(Rep.Matches, Card.Matches); Inc(Rep.Odds, Card.Odds);
            if Pos(',' + Dv + ',', ',' + Rep.Divisions + ',') = 0 then
            begin
              if Rep.Divisions <> '' then Rep.Divisions := Rep.Divisions + ',';
              Rep.Divisions := Rep.Divisions + Dv;
            end;
          end;
        except
          on E: Exception do
          begin
            if Rep.Problems <> '' then Rep.Problems := Rep.Problems + '; ';
            Rep.Problems := Rep.Problems + Dv + ' ' + Se + ': ' + E.Message;
          end;
        end;
      finally
        Sub.Free;
        Frames.Free;
      end;
    end;
  finally
    for K := 0 to Groups.Count - 1 do TList(Groups.Objects[K]).Free;
    Groups.Free; Unknown.Free; Names.Free;
  end;
end;

function ImportCountryFile(ADb: TAppDb; const AFile: string; AMerge: Boolean): TaCountryReport;
var
  Frames: TList;
  I, Done: Integer;
  F: TFrame;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.FileName := ExtractFileName(AFile);
  Frames := TList.Create;
  try
    ReadFrames(AFile, Frames);
    Done := 0;
    for I := 0 to Frames.Count - 1 do
    begin
      F := TFrame(Frames[I]);
      if (F.ColIdx('Country') < 0) and (F.ColIdx('League') < 0) then Continue;
      ImportCountryFrame(ADb, F, Result.FileName, AMerge, Result);
      Inc(Done);
    end;
    if Done = 0 then raise Exception.Create(Result.FileName + Tr(': the columns Country, League, Season are missing'));
  finally
    for I := 0 to Frames.Count - 1 do TObject(Frames[I]).Free;
    Frames.Free;
  end;
end;

function ImportScrapedFile(ADb: TAppDb; const AFile, ASeason: string): TaImportReport;
var
  Frames: TList;
  I: Integer;
begin
  Frames := TList.Create;
  try
    ReadFrames(AFile, Frames);
    Result := IngestFrames(ADb, AFile, ASeason, Frames, False, False, 0.5, False, False, False);
  finally
    for I := 0 to Frames.Count - 1 do TObject(Frames[I]).Free;
    Frames.Free;
  end;
end;

function ImportMatchFile(ADb: TAppDb; const AFile, ASeason: string; AMerge, AOnlyIfLarger: Boolean; AMinRatio: Double): TaImportReport;
var
  Frames: TList;
  I: Integer;
begin
  Frames := TList.Create;
  try
    ReadFrames(AFile, Frames);
    Result := IngestFrames(ADb, AFile, ASeason, Frames, AMerge, AOnlyIfLarger, AMinRatio, True, False);
  finally
    for I := 0 to Frames.Count - 1 do TObject(Frames[I]).Free;
    Frames.Free;
  end;
end;

end.
