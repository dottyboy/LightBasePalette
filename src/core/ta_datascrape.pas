unit ta_datascrape;
{ Hrvatski nogomet (semafor.hns.family, HNS-ov portal rezultata) i UEFA klupska natjecanja (openfootball na GitHubu):
  nativna replika smartbet/croatia.py i champions.py. HTML i tekst se citaju istim regularnim izrazima kao u Pythonu,
  rezultat se zapise u csv iste ustroje (mapa croatia/ i champions/), pa se uvozi bez kvota i statistike. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, StrUtils, RegExpr, fpjson, jsonparser, LazUTF8, ta_meta, ta_download, ta_dataimport, ta_fixtureimport;

type
  TaScrapeRow = record
    Div_, Date, Home, Away: string;
    Fthg, Ftag: Integer;
    HasHt: Boolean;
    Hthg, Htag: Integer;
  end;
  TaScrapeRows = array of TaScrapeRow;

{ HNS portal: odigrane utakmice i neodigrane (raspored) s jedne stranice natjecanja }
procedure ParseHnl(const AHtml, ADiv: string; out APlayed, AFixtures: TaScrapeRows);
{ openfootball football.txt: odigrane utakmice i raspored; AStartYear je godina pocetka sezone }
procedure ParseUefa(const AText, ADiv: string; AStartYear: Integer; out APlayed, AFixtures: TaScrapeRows);
{ id natjecanja za (razina, sezona): poznat iz tablice ili otkriven pretrazivanjem portala }
function HnlCompetitionId(const ADiv, ASeason: string; ATimeoutSec: Integer; out AError: string; AIgnoreTable: Boolean = False): Int64;
{ osvjezavanje: preuzmi, zapisi csv, uvezi; izvjesce u recima }
function RefreshCroatiaSource(ADb: TAppDb; const ASeason, AFolder: string; ATimeoutSec: Integer): string;
function RefreshUefaSource(ADb: TAppDb; const ASeason, AFolder: string; ATimeoutSec: Integer): string;
{ ispis procitanog za provjeru pariteta (AKind: hnl ili uefa) }
procedure WriteParsed(const AKind, AFile, ADiv: string; AStartYear: Integer);

implementation

const
  HnlUrl = 'https://semafor.hns.family/natjecanja/%d/x/';
  HnlSearch = 'https://semafor.hns.family/handlers/getCompetitions/';
  UefaRaw = 'https://raw.githubusercontent.com/openfootball/champions-league/master/%s/%s.txt';
  Tiers: array[0..2] of string = ('CRO1', 'CRO2', 'CROCUP');
  Uefa: array[0..2] of string = ('UCL', 'UEL', 'UECL');
  UefaFile: array[0..2] of string = ('cl', 'el', 'conf');

type
  TIdRow = record
    Div_, Season: string;
    Id: Int64;
  end;

const
  { croatia.TIERS[...]["season_ids"]: pronadeno rucno jednom po razini }
  HnlIds: array[0..59] of TIdRow = (
    (Div_: 'CRO1'; Season: '2004-2005'; Id: 126),
    (Div_: 'CRO1'; Season: '2005-2006'; Id: 165),
    (Div_: 'CRO1'; Season: '2006-2007'; Id: 446),
    (Div_: 'CRO1'; Season: '2007-2008'; Id: 656),
    (Div_: 'CRO1'; Season: '2008-2009'; Id: 895),
    (Div_: 'CRO1'; Season: '2009-2010'; Id: 1134),
    (Div_: 'CRO1'; Season: '2010-2011'; Id: 1443),
    (Div_: 'CRO1'; Season: '2011-2012'; Id: 1725),
    (Div_: 'CRO1'; Season: '2012-2013'; Id: 2061),
    (Div_: 'CRO1'; Season: '2013-2014'; Id: 2525),
    (Div_: 'CRO1'; Season: '2014-2015'; Id: 22869),
    (Div_: 'CRO1'; Season: '2015-2016'; Id: 23181),
    (Div_: 'CRO1'; Season: '2016-2017'; Id: 23604),
    (Div_: 'CRO1'; Season: '2017-2018'; Id: 9400615),
    (Div_: 'CRO1'; Season: '2018-2019'; Id: 28050689),
    (Div_: 'CRO1'; Season: '2019-2020'; Id: 33515858),
    (Div_: 'CRO1'; Season: '2020-2021'; Id: 40743217),
    (Div_: 'CRO1'; Season: '2021-2022'; Id: 50706994),
    (Div_: 'CRO1'; Season: '2022-2023'; Id: 65327115),
    (Div_: 'CRO1'; Season: '2023-2024'; Id: 78093806),
    (Div_: 'CRO1'; Season: '2024-2025'; Id: 88712926),
    (Div_: 'CRO1'; Season: '2025-2026'; Id: 100391485),
    (Div_: 'CRO1'; Season: '2026-2027'; Id: 114137140),
    (Div_: 'CRO2'; Season: '2006-2007'; Id: 447),
    (Div_: 'CRO2'; Season: '2007-2008'; Id: 660),
    (Div_: 'CRO2'; Season: '2008-2009'; Id: 889),
    (Div_: 'CRO2'; Season: '2009-2010'; Id: 1142),
    (Div_: 'CRO2'; Season: '2010-2011'; Id: 1436),
    (Div_: 'CRO2'; Season: '2011-2012'; Id: 1740),
    (Div_: 'CRO2'; Season: '2012-2013'; Id: 2066),
    (Div_: 'CRO2'; Season: '2013-2014'; Id: 2521),
    (Div_: 'CRO2'; Season: '2014-2015'; Id: 22879),
    (Div_: 'CRO2'; Season: '2015-2016'; Id: 23189),
    (Div_: 'CRO2'; Season: '2016-2017'; Id: 23616),
    (Div_: 'CRO2'; Season: '2017-2018'; Id: 9409858),
    (Div_: 'CRO2'; Season: '2020-2021'; Id: 40724997),
    (Div_: 'CRO2'; Season: '2021-2022'; Id: 51311185),
    (Div_: 'CRO2'; Season: '2022-2023'; Id: 66278530),
    (Div_: 'CRO2'; Season: '2023-2024'; Id: 78146642),
    (Div_: 'CRO2'; Season: '2024-2025'; Id: 88816130),
    (Div_: 'CRO2'; Season: '2025-2026'; Id: 100418001),
    (Div_: 'CRO2'; Season: '2026-2027'; Id: 114348039),
    (Div_: 'CROCUP'; Season: '2009-2010'; Id: 1295),
    (Div_: 'CROCUP'; Season: '2010-2011'; Id: 1442),
    (Div_: 'CROCUP'; Season: '2011-2012'; Id: 1759),
    (Div_: 'CROCUP'; Season: '2012-2013'; Id: 2224),
    (Div_: 'CROCUP'; Season: '2013-2014'; Id: 22598),
    (Div_: 'CROCUP'; Season: '2014-2015'; Id: 22930),
    (Div_: 'CROCUP'; Season: '2015-2016'; Id: 23345),
    (Div_: 'CROCUP'; Season: '2016-2017'; Id: 23644),
    (Div_: 'CROCUP'; Season: '2017-2018'; Id: 9422110),
    (Div_: 'CROCUP'; Season: '2018-2019'; Id: 28096424),
    (Div_: 'CROCUP'; Season: '2019-2020'; Id: 34038642),
    (Div_: 'CROCUP'; Season: '2020-2021'; Id: 41706624),
    (Div_: 'CROCUP'; Season: '2021-2022'; Id: 52338973),
    (Div_: 'CROCUP'; Season: '2022-2023'; Id: 65901769),
    (Div_: 'CROCUP'; Season: '2023-2024'; Id: 78204094),
    (Div_: 'CROCUP'; Season: '2024-2025'; Id: 88992641),
    (Div_: 'CROCUP'; Season: '2025-2026'; Id: 100439118),
    (Div_: 'CROCUP'; Season: '2026-2027'; Id: 114492931)
  );

function FileToString(const AFile: string): string;
var
  F: TFileStream;
begin
  F := TFileStream.Create(AFile, fmOpenRead or fmShareDenyNone);
  try
    SetLength(Result, F.Size);
    if F.Size > 0 then F.ReadBuffer(Result[1], F.Size);
  finally
    F.Free;
  end;
end;

function IsDigits(const S: string): Boolean;
var
  I: Integer;
begin
  Result := S <> '';
  for I := 1 to Length(S) do if not (S[I] in ['0'..'9']) then Exit(False);
end;

procedure AddRow(var A: TaScrapeRows; const R: TaScrapeRow);
begin
  SetLength(A, Length(A) + 1);
  A[High(A)] := R;
end;

{ ---------------- HNS portal (croatia._parse_matches / _parse_fixtures) ---------------- }

procedure ParseHnl(const AHtml, ADiv: string; out APlayed, AFixtures: TaScrapeRows);
var
  Row, Club, Score, Dt, Parts: TRegExpr;
  SeenP, SeenF: TStringList;
  Id, Body, DateText, Hg, Ag, H1, H2: string;
  Clubs: TStringList;
  R: TaScrapeRow;
  HasScore, Played: Boolean;
begin
  SetLength(APlayed, 0);
  SetLength(AFixtures, 0);
  Row := TRegExpr.Create('<li class="row[^"]*" data-round="(\d+)" data-match="(\d+)">(.*?)</li>');
  Club := TRegExpr.Create('<div class="club\d" data-id="\d+"><a[^>]*>([^<]+)<div class="logo">');
  Score := TRegExpr.Create('<div class="res1">([^<]+)</div>.*?<div class="res2">([^<]+)</div>');
  Dt := TRegExpr.Create('<div class="date">([^<]*)</div>');
  Parts := TRegExpr.Create('^(\d{2})\.(\d{2})\.(\d{4})\.');
  SeenP := TStringList.Create;
  SeenF := TStringList.Create;
  Clubs := TStringList.Create;
  try
    SeenP.Sorted := True; SeenF.Sorted := True;
    if Row.Exec(AHtml) then
    repeat
      Id := Row.Match[2];
      Body := Row.Match[3];
      Clubs.Clear;
      if Club.Exec(Body) then
      repeat
        Clubs.Add(Club.Match[1]);
      until not Club.ExecNext;
      HasScore := Score.Exec(Body);
      if (Clubs.Count <> 2) or not HasScore or not Dt.Exec(Body) then Continue;
      Hg := Trim(Score.Match[1]); Ag := Trim(Score.Match[2]);
      DateText := Trim(Dt.Match[1]);
      if not Parts.Exec(DateText) then Continue;
      Played := IsDigits(Hg) and IsDigits(Ag);
      R.Div_ := ADiv;
      R.Date := Parts.Match[3] + '-' + Parts.Match[2] + '-' + Parts.Match[1];
      R.Home := Trim(Clubs[0]); R.Away := Trim(Clubs[1]);
      R.HasHt := False; R.Hthg := 0; R.Htag := 0;
      if Played then
      begin
        if SeenP.IndexOf(Id) >= 0 then Continue;
        SeenP.Add(Id);
        R.Fthg := StrToInt(Hg); R.Ftag := StrToInt(Ag);
        AddRow(APlayed, R);
      end
      else
      begin
        if SeenF.IndexOf(Id) >= 0 then Continue;
        SeenF.Add(Id);
        R.Fthg := 0; R.Ftag := 0;
        AddRow(AFixtures, R);
      end;
    until not Row.ExecNext;
    H1 := ''; H2 := '';
  finally
    Clubs.Free; SeenF.Free; SeenP.Free;
    Parts.Free; Dt.Free; Score.Free; Club.Free; Row.Free;
  end;
end;

{ ---------------- UEFA (champions._parse_text) ---------------- }

function MonthOf(const AName: string): Integer;
const
  Names: array[1..12] of string = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
var
  I: Integer;
begin
  for I := 1 to 12 do if Names[I] = AName then Exit(I);
  Result := 0;
end;

procedure ParseUefa(const AText, ADiv: string; AStartYear: Integer; out APlayed, AFixtures: TaScrapeRows);
var
  DateLine, MatchLine, FixLine, StripC: TRegExpr;
  Lines: TStringList;
  I, CurMonth, CurYear, CurDay, M: Integer;
  Line, Stripped, Dt: string;
  R: TaScrapeRow;
begin
  SetLength(APlayed, 0);
  SetLength(AFixtures, 0);
  DateLine := TRegExpr.Create('^\s*(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun)\s+([A-Z][a-z]{2})\s+(\d{1,2})(?:\s+(\d{4}))?\s*$');
  MatchLine := TRegExpr.Create('^\s*(?:\d{2}:\d{2}\s+)?(.+?\([A-Z]{3}\))\s+v\s+(.+?\([A-Z]{3}\))\s+(?:\d+-\d+\s+pen\.\s+)?(\d+)-(\d+)(?:\s+a\.e\.t\.)?(?:\s+\((\d+)-(\d+)(?:,\s*(\d+)-(\d+))?\))?\s*$');
  FixLine := TRegExpr.Create('^\s*(?:\d{2}:\d{2}\s+)?(.+?\([A-Z]{3}\))\s+v\s+(.+?\([A-Z]{3}\))\s*$');
  StripC := TRegExpr.Create('\s*\([A-Z]{3}\)\s*$');
  Lines := TStringList.Create;
  try
    Lines.Text := AText;
    CurMonth := 0; CurYear := AStartYear; CurDay := 1;
    for I := 0 to Lines.Count - 1 do
    begin
      Line := Lines[I];
      if Trim(Line) = '' then Continue;
      if DateLine.Exec(Line) then
      begin
        M := MonthOf(DateLine.Match[1]);
        if DateLine.Match[3] <> '' then CurYear := StrToInt(DateLine.Match[3])
        else if (CurMonth <> 0) and (M < CurMonth) then Inc(CurYear);
        CurMonth := M; CurDay := StrToInt(DateLine.Match[2]);
        Continue;
      end;
      Stripped := Trim(Line);
      if Copy(Stripped, 1, 3) = #$E2#$96#$AA then
      begin
        { novi odjeljak: paralelne grupe ponavljaju svoje datume, pa se tekuci mjesec ne smije usporedivati preko granice }
        CurMonth := 0;
        Continue;
      end;
      if (Stripped[1] = '=') or (Stripped[1] = '#') then Continue;
      Dt := Format('%.4d-%.2d-%.2d', [CurYear, CurMonth, CurDay]);
      if MatchLine.Exec(Line) then
      begin
        if CurMonth = 0 then Continue;
        R.Div_ := ADiv; R.Date := Dt;
        R.Home := Trim(StripC.Replace(MatchLine.Match[1], '', False));
        R.Away := Trim(StripC.Replace(MatchLine.Match[2], '', False));
        R.Fthg := StrToInt(MatchLine.Match[3]); R.Ftag := StrToInt(MatchLine.Match[4]);
        R.HasHt := False; R.Hthg := 0; R.Htag := 0;
        if MatchLine.Match[7] <> '' then
        begin
          R.HasHt := True; R.Hthg := StrToInt(MatchLine.Match[7]); R.Htag := StrToInt(MatchLine.Match[8]);
        end
        else if MatchLine.Match[5] <> '' then
        begin
          R.HasHt := True; R.Hthg := StrToInt(MatchLine.Match[5]); R.Htag := StrToInt(MatchLine.Match[6]);
        end;
        AddRow(APlayed, R);
        Continue;
      end;
      if FixLine.Exec(Line) and (CurMonth <> 0) then
      begin
        R.Div_ := ADiv; R.Date := Dt;
        R.Home := Trim(StripC.Replace(FixLine.Match[1], '', False));
        R.Away := Trim(StripC.Replace(FixLine.Match[2], '', False));
        R.Fthg := 0; R.Ftag := 0; R.HasHt := False; R.Hthg := 0; R.Htag := 0;
        AddRow(AFixtures, R);
      end;
    end;
  finally
    Lines.Free; StripC.Free; FixLine.Free; MatchLine.Free; DateLine.Free;
  end;
end;

{ ---------------- id natjecanja ---------------- }

function HasAny(const AName: string; const AList: array of string): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(AList) do if Pos(AList[I], AName) > 0 then Exit(True);
  Result := False;
end;

function UrlEncode(const S: string): string;
var
  I: Integer;
  C: Char;
begin
  Result := '';
  for I := 1 to Length(S) do
  begin
    C := S[I];
    if C in ['A'..'Z', 'a'..'z', '0'..'9', '_', '.', '-', '~'] then Result := Result + C
    else if C = ' ' then Result := Result + '+'
    else Result := Result + '%' + IntToHex(Ord(C), 2);
  end;
end;

function HnlCompetitionId(const ADiv, ASeason: string; ATimeoutSec: Integer; out AError: string; AIgnoreTable: Boolean): Int64;
const
  ExcludeCommon: array[0..19] of string = ('hmnl', 'hnlž', 'hnlz', 'malom', 'futsal', 'juniori', 'kadet', 'pionir', 'početni', 'pocetni', 'žen',
    'doigravanje', 'nadnatjecanje', 'popunu', 'kvalifikacij', 'završnic', 'zavrsnic', 'kadetkinj', 'pionirk', 'superliga');
  Any1: array[0..1] of string = ('hnl', 'liga');
  Ex1: array[0..8] of string = ('2.', '3.', '4.', 'druga', 'treća', 'treca', 'četvrta', 'cetvrta', 'kup');
  Any2: array[0..3] of string = ('druga hnl', 'druga nl', '2. hnl', '2. nl');
  Ex2: array[0..6] of string = ('3.', '4.', 'treća', 'treca', 'četvrta', 'cetvrta', 'kup');
  Any3: array[0..1] of string = ('hnk', 'kup');
  Ex3: array[0..4] of string = ('superkup', 'hnkž', 'žns', 'znk', 'hmnl');
var
  I: Integer;
  Url, Tmp, Txt, Nm, Season2, Err: string;
  Data: TJSONData;
  Arr: TJSONArray;
  O: TJSONObject;
  BestSort: Double;
  Found, Ok: Boolean;
begin
  Result := 0;
  AError := '';
  if not AIgnoreTable then
    for I := 0 to High(HnlIds) do
      if (HnlIds[I].Div_ = ADiv) and (HnlIds[I].Season = ASeason) then Exit(HnlIds[I].Id);
  { sezona koje nema u tablici: pitaj pretrazivanje portala }
  Season2 := StringReplace(ASeason, '-', '/', []);
  Url := HnlSearch + '?season=' + UrlEncode(Season2) + '&oid=1&t=1&lang=hr&teamch=Club&linkType=competitions&linkConstructor=' +
    UrlEncode('https://semafor.hns.family/natjecanja/{cid}/{cname}/');
  Tmp := GetTempFileName('', 'hnl');
  if not HttpFetchToFile(Url, Tmp, ATimeoutSec, Err) then begin AError := Err; Exit; end;
  try
    Txt := FileToString(Tmp);
  finally
    DeleteFile(Tmp);
  end;
  Data := nil;
  try
    Data := GetJSON(Txt);
    if not (Data is TJSONArray) then begin AError := 'odgovor pretrazivanja nije popis'; Exit; end;
    Arr := TJSONArray(Data);
    Found := False; BestSort := 0;
    for I := 0 to Arr.Count - 1 do
    begin
      O := Arr.Objects[I];
      Nm := UTF8LowerCase(O.Get('value', ''));
      if HasAny(Nm, ExcludeCommon) then Continue;
      if ADiv = 'CRO1' then Ok := HasAny(Nm, Any1) and not HasAny(Nm, Ex1)
      else if ADiv = 'CRO2' then Ok := HasAny(Nm, Any2) and not HasAny(Nm, Ex2)
      else Ok := HasAny(Nm, Any3) and not HasAny(Nm, Ex3);
      if not Ok then Continue;
      if (not Found) or (O.Get('sort', 0.0) < BestSort) then
      begin
        Found := True; BestSort := O.Get('sort', 0.0); Result := O.Get('id', Int64(0));
      end;
    end;
    if not Found then AError := ASeason + ': nijedno natjecanje ' + ADiv + ' nije pronadeno';
  finally
    Data.Free;
  end;
end;

{ ---------------- csv ---------------- }

function CsvEsc(const S: string): string;
begin
  if (Pos(',', S) > 0) or (Pos('"', S) > 0) or (Pos(#10, S) > 0) then
    Result := '"' + StringReplace(S, '"', '""', [rfReplaceAll]) + '"'
  else Result := S;
end;

procedure WriteCsv(const AFile: string; const ARows: TaScrapeRows; AWithScore, AWithHt: Boolean);
var
  L: TStringList;
  I: Integer;
  Ln: string;
begin
  L := TStringList.Create;
  try
    Ln := 'Div,Date,HomeTeam,AwayTeam';
    if AWithScore then Ln := Ln + ',FTHG,FTAG';
    if AWithHt then Ln := Ln + ',HTHG,HTAG';
    L.Add(Ln);
    for I := 0 to High(ARows) do
    begin
      Ln := CsvEsc(ARows[I].Div_) + ',' + ARows[I].Date + ',' + CsvEsc(ARows[I].Home) + ',' + CsvEsc(ARows[I].Away);
      if AWithScore then Ln := Ln + ',' + IntToStr(ARows[I].Fthg) + ',' + IntToStr(ARows[I].Ftag);
      if AWithHt then
        if ARows[I].HasHt then Ln := Ln + ',' + IntToStr(ARows[I].Hthg) + ',' + IntToStr(ARows[I].Htag) else Ln := Ln + ',,';
      L.Add(Ln);
    end;
    ForceDirectories(ExtractFilePath(ExpandFileName(AFile)));
    L.SaveToFile(AFile);
  finally
    L.Free;
  end;
end;

{ sortiranje po datumu, stabilno (Python sort_values("Date")) }
procedure SortByDate(var A: TaScrapeRows);
var
  I, J: Integer;
  T: TaScrapeRow;
begin
  for I := 1 to High(A) do
  begin
    T := A[I]; J := I - 1;
    while (J >= 0) and (A[J].Date > T.Date) do begin A[J + 1] := A[J]; Dec(J); end;
    A[J + 1] := T;
  end;
end;

function BaseFolder(ADb: TAppDb; const AFolder: string): string;
begin
  if AFolder <> '' then Result := AFolder
  else Result := ExtractFilePath(ExpandFileName(ADb.Conn.Database)) + 'download_data';
  Result := IncludeTrailingPathDelimiter(Result);
end;

function SeasonNow: string;
var
  Y, M, D: Word;
  S: Integer;
begin
  DecodeDate(Date, Y, M, D);
  if M >= 7 then S := Y else S := Y - 1;
  Result := Format('%d-%d', [S, S + 1]);
end;

{ ---------------- osvjezavanje ---------------- }

function RefreshCroatiaSource(ADb: TAppDb; const ASeason, AFolder: string; ATimeoutSec: Integer): string;
var
  Season, Dir, Sub, Tmp, Html, Err: string;
  Out_: TStringList;
  T: Integer;
  Id: Int64;
  Played, Fix: TaScrapeRows;
  Rep: TaImportReport;
  N: Integer;
begin
  Out_ := TStringList.Create;
  try
    Season := ASeason;
    if Season = '' then Season := SeasonNow;
    for T := 0 to High(Tiers) do
    try
      Id := HnlCompetitionId(Tiers[T], Season, ATimeoutSec, Err);
      if Id = 0 then begin Out_.Add(Tiers[T] + ': NEUSPJEH - ' + Err); Continue; end;
      Tmp := GetTempFileName('', 'hnl');
      if not HttpFetchToFile(Format(HnlUrl, [Id]), Tmp, ATimeoutSec, Err) then begin Out_.Add(Tiers[T] + ': NEUSPJEH - ' + Err); Continue; end;
      try
        Html := FileToString(Tmp);
      finally
        DeleteFile(Tmp);
      end;
      ParseHnl(Html, Tiers[T], Played, Fix);
      if Length(Played) = 0 then begin Out_.Add(Tiers[T] + ': NEUSPJEH - nijedna odigrana utakmica za sezonu ' + Season); Continue; end;
      SortByDate(Played);
      { CRO1 ima svoju mapu croatia/, ostale razine podmape }
      if Tiers[T] = 'CRO1' then Sub := 'croatia' + PathDelim else Sub := 'croatia' + PathDelim + Tiers[T] + PathDelim;
      Dir := BaseFolder(ADb, AFolder) + Sub;
      WriteCsv(Dir + Season + '.csv', Played, True, False);
      WriteCsv(Dir + 'fixtures.csv', Fix, False, False);
      Rep := ImportScrapedFile(ADb, Dir + Season + '.csv', Season);
      N := ImportFixtureFile(ADb, Dir + 'fixtures.csv');
      if Rep.Kept then
        Out_.Add(Format('%s %s: %d utakmica uvezeno, %d nadolazecih (%d novih u rasporedu)', [Tiers[T], Season, Rep.Matches, Length(Fix), N]))
      else
        Out_.Add(Tiers[T] + ' ' + Season + ': ' + Rep.Problems);
    except
      on E: Exception do Out_.Add(Tiers[T] + ': NEUSPJEH - ' + E.Message);
    end;
    Result := Trim(Out_.Text);
  finally
    Out_.Free;
  end;
end;

function RefreshUefaSource(ADb: TAppDb; const ASeason, AFolder: string; ATimeoutSec: Integer): string;
var
  Season, Dir, OfSeason, Tmp, Text, Err: string;
  Out_: TStringList;
  C, StartYear, N: Integer;
  Played, Fix: TaScrapeRows;
  Rep: TaImportReport;
begin
  Out_ := TStringList.Create;
  try
    Season := ASeason;
    if Season = '' then Season := SeasonNow;
    StartYear := StrToInt(Copy(Season, 1, 4));
    OfSeason := Copy(Season, 1, 4) + '-' + Copy(Season, 8, 2);
    for C := 0 to High(Uefa) do
    try
      Tmp := GetTempFileName('', 'uefa');
      if not HttpFetchToFile(Format(UefaRaw, [OfSeason, UefaFile[C]]), Tmp, ATimeoutSec, Err) then
      begin
        Out_.Add(Uefa[C] + ': nedostupno');
        Continue;
      end;
      try
        Text := FileToString(Tmp);
      finally
        DeleteFile(Tmp);
      end;
      ParseUefa(Text, Uefa[C], StartYear, Played, Fix);
      if Length(Played) = 0 then begin Out_.Add(Uefa[C] + ': nedostupno'); Continue; end;
      SortByDate(Played);
      Dir := BaseFolder(ADb, AFolder) + 'champions' + PathDelim + Uefa[C] + PathDelim;
      WriteCsv(Dir + Season + '.csv', Played, True, True);
      WriteCsv(Dir + 'fixtures.csv', Fix, False, False);
      Rep := ImportScrapedFile(ADb, Dir + Season + '.csv', Season);
      N := ImportFixtureFile(ADb, Dir + 'fixtures.csv');
      if Rep.Kept then
        Out_.Add(Format('%s %s: %d utakmica uvezeno, %d nadolazecih (%d novih u rasporedu)', [Uefa[C], Season, Rep.Matches, Length(Fix), N]))
      else
        Out_.Add(Uefa[C] + ' ' + Season + ': ' + Rep.Problems);
    except
      on E: Exception do Out_.Add(Uefa[C] + ': NEUSPJEH - ' + E.Message);
    end;
    Result := Trim(Out_.Text);
  finally
    Out_.Free;
  end;
end;

procedure WriteParsed(const AKind, AFile, ADiv: string; AStartYear: Integer);
var
  Played, Fix: TaScrapeRows;
  I: Integer;

  procedure Dump(const ATag: string; const A: TaScrapeRows);
  var
    K: Integer;
    Ht: string;
  begin
    for K := 0 to High(A) do
    begin
      if A[K].HasHt then Ht := IntToStr(A[K].Hthg) + ';' + IntToStr(A[K].Htag) else Ht := ';';
      WriteLn(ATag, ';', A[K].Div_, ';', A[K].Date, ';', A[K].Home, ';', A[K].Away, ';', A[K].Fthg, ';', A[K].Ftag, ';', Ht);
    end;
  end;

var
  Err: string;
begin
  if AKind = 'discover' then
  begin
    WriteLn('ID;', ADiv, ';', AFile, ';', HnlCompetitionId(ADiv, AFile, 30, Err, True), ';', Err);
    Exit;
  end;
  if AKind = 'hnl' then ParseHnl(FileToString(AFile), ADiv, Played, Fix)
  else ParseUefa(FileToString(AFile), ADiv, AStartYear, Played, Fix);
  Dump('P', Played);
  Dump('F', Fix);
  I := 0;
  if I = 1 then Exit;
end;

end.
