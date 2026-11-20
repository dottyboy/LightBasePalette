unit ta_datarefresh;
{ Osvjezavanje podataka o utakmicama: preuzimanje i uvoz glavnog izvora (football-data.co.uk) kao u SmartBetu
  (refresh.py): arhiva sezone, najnoviji rezultati, raspored; svaki korak za sebe, pogreska jednog ne zaustavlja
  ostale. Funkcije izraza: DownloadFile, ImportMatches, RefreshMain. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Variants, ta_parse, ta_meta, ta_expr, ta_exprdb, ta_download, ta_dataimport, ta_fixtureimport, ta_datascrape, ta_report;

{ sezona -> kod u adresi: 2026-2027 je 2627 }
function SeasonCode(const ASeason: string): string;
{ cijelo osvjezavanje glavnog izvora; vraca izvjestaj u recima }
function RefreshMainSource(ADb: TAppDb; const ASeason, AFolder: string; ATimeoutSec: Integer): string;
{ dodatne lige (datoteke drzava, najnoviji rezultati i raspored); vraca izvjestaj u recima }
function RefreshCountries(ADb: TAppDb; const AFolder: string; ATimeoutSec: Integer): string;

implementation

const
  BaseUrl = 'https://football-data.co.uk/';

function SeasonCode(const ASeason: string): string;
begin
  Result := Copy(ASeason, 3, 2) + Copy(ASeason, 8, 2);
end;

function FSize(const AFile: string): Int64;
var
  F: TFileStream;
begin
  F := TFileStream.Create(AFile, fmOpenRead or fmShareDenyNone);
  try
    Result := F.Size;
  finally
    F.Free;
  end;
end;

function FolderOf(ADb: TAppDb; const AFolder: string): string;
begin
  if AFolder <> '' then Result := AFolder
  else Result := ExtractFilePath(ExpandFileName(ADb.Conn.Database)) + 'download_data';
  Result := IncludeTrailingPathDelimiter(Result);
end;

{ preuzmi prvu varijantu koja se moze procitati; Valid vraca >0 kad je sadrzaj dobar }
function FetchValid(const AUrls: array of string; const ADests: array of string; ATimeout: Integer; AKind: Integer;
  out AUsed: string; out AError: string): Boolean;
var
  I, N: Integer;
  E: string;
begin
  Result := False;
  AError := '';
  for I := 0 to High(AUrls) do
  begin
    if not HttpFetchToFile(AUrls[I], ADests[I], ATimeout, E) then
    begin
      if AError <> '' then AError := AError + '; ';
      AError := AError + E;
      Continue;
    end;
    try
      if AKind = 0 then N := CountMatchSheets(ADests[I])
      else if AKind = 1 then N := CountResultRows(ADests[I])
      else N := CountFixtureRows(ADests[I]);
    except
      on Ex: Exception do begin N := -1; E := Ex.Message; end;
    end;
    if N > 0 then begin AUsed := ADests[I]; Exit(True); end;
    if AError <> '' then AError := AError + '; ';
    AError := AError + AUrls[I] + ': nije citljivo ili je prazno';
    DeleteFile(ADests[I]);
  end;
end;

function RefreshMainSource(ADb: TAppDb; const ASeason, AFolder: string; ATimeoutSec: Integer): string;
var
  Season, Dir, SDir, Code, Used, Err: string;
  Out_: TStringList;
  Archive, Latest, Fixt: string;
  Rep: TaImportReport;
  HaveArchive, HaveLatest, HaveFix: Boolean;
  N: Integer;
begin
  Out_ := TStringList.Create;
  try
    Season := ASeason;
    if Season = '' then Season := SeasonOfDate(Date);
    Code := SeasonCode(Season);
    Dir := FolderOf(ADb, AFolder);
    SDir := Dir + Season + PathDelim;
    ForceDirectories(SDir);
    Archive := ''; Latest := ''; Fixt := '';

    { 1. arhiva sezone (radna knjiga: list po ligi) }
    HaveArchive := FetchValid([BaseUrl + 'mmz4281/' + Code + '/all-euro-data-' + Season + '.xlsx'],
      [SDir + 'all-euro-data-' + Season + '.xlsx'], ATimeoutSec, 0, Archive, Err);
    if HaveArchive then Out_.Add('arhiva ' + Season + ': ' + IntToStr(FSize(Archive) div 1024) + ' KB')
    else Out_.Add('arhiva ' + Season + ': NEUSPJEH - ' + Err);

    { 2. najnoviji rezultati: xlsx pa csv }
    HaveLatest := FetchValid([BaseUrl + 'mmz4281/' + Code + '/Latest_Results.xlsx', BaseUrl + 'mmz4281/' + Code + '/Latest_Results.csv'],
      [SDir + 'Latest_Results.xlsx', SDir + 'Latest_Results.csv'], ATimeoutSec, 1, Latest, Err);
    if HaveLatest then Out_.Add('najnoviji rezultati: ' + IntToStr(CountResultRows(Latest)) + ' utakmica')
    else Out_.Add('najnoviji rezultati: NEUSPJEH - ' + Err);

    { 3. raspored glavnih liga }
    HaveFix := FetchValid([BaseUrl + 'fixtures.xlsx', BaseUrl + 'fixtures.csv'], [Dir + 'fixtures.xlsx', Dir + 'fixtures.csv'],
      ATimeoutSec, 2, Fixt, Err);
    if not HaveFix then Out_.Add('raspored glavnih liga: NEUSPJEH - ' + Err);

    { 4. uvoz }
    if HaveArchive then
    try
      Rep := ImportMatchFile(ADb, Archive, Season, False, False);
      if Rep.Kept then Out_.Add(Format('uvoz arhive: %d utakmica, %d kvota, %d statistika', [Rep.Matches, Rep.Odds, Rep.Stats]))
      else Out_.Add('uvoz arhive: ' + Rep.Problems);
    except
      on E: Exception do Out_.Add('uvoz arhive: NEUSPJEH - ' + E.Message);
    end;
    if HaveLatest then
    try
      Rep := ImportMatchFile(ADb, Latest, Season, True, False);
      Out_.Add(Format('uvoz najnovijih: %d novih, %d osvjezenih', [Rep.Added, Rep.Updated]));
    except
      on E: Exception do Out_.Add('uvoz najnovijih: NEUSPJEH - ' + E.Message);
    end;
    if HaveFix then
    try
      N := ImportFixtureFile(ADb, Fixt);
      Out_.Add(Format('raspored glavnih liga: %d novih utakmica u tablici fixtures', [N]));
    except
      on E: Exception do Out_.Add('raspored glavnih liga: NEUSPJEH - ' + E.Message);
    end;
    Result := Trim(Out_.Text);
  finally
    Out_.Free;
  end;
end;

function RefreshCountries(ADb: TAppDb; const AFolder: string; ATimeoutSec: Integer): string;
const
  Countries: array[0..15] of string = ('ARG', 'AUT', 'BRA', 'CHN', 'DNK', 'FIN', 'IRL', 'JPN', 'MEX', 'NOR', 'POL', 'ROU', 'RUS', 'SWE', 'SWZ', 'USA');
var
  Out_: TStringList;
  Dir, Used, Err, Combined, E2: string;
  I, Got: Integer;
  Files: array of string;
  Rep: TaCountryReport;
  HaveLatest, HaveFix: Boolean;
  LatestFile, FixFile: string;
  N, Tot, TotOdds: Integer;
begin
  Out_ := TStringList.Create;
  try
    Dir := FolderOf(ADb, AFolder) + 'new' + PathDelim;
    ForceDirectories(Dir);
    SetLength(Files, 0);
    { 1. sve drzave u jednoj radnoj knjizi (kratko ogranicenje), pa pojedinacno ako ne uspije }
    Combined := Dir + 'new_leagues_data.xlsx';
    if HttpFetchToFile(BaseUrl + 'new/new_leagues_data.xlsx', Combined, 25, Err) and (CountCountrySheets(Combined) > 0) then
    begin
      SetLength(Files, 1);
      Files[0] := Combined;
      Out_.Add('datoteke drzava: skupna radna knjiga, ' + IntToStr(CountCountrySheets(Combined)) + ' listova');
    end
    else
    begin
      Got := 0;
      for I := 0 to High(Countries) do
      begin
        Used := '';
        if HttpFetchToFile(BaseUrl + 'new/' + Countries[I] + '.xlsx', Dir + Countries[I] + '.xlsx', 60, E2) and (CountCountrySheets(Dir + Countries[I] + '.xlsx') > 0) then
          Used := Dir + Countries[I] + '.xlsx'
        else if HttpFetchToFile(BaseUrl + 'new/' + Countries[I] + '.csv', Dir + Countries[I] + '.csv', 60, E2) and (CountCountrySheets(Dir + Countries[I] + '.csv') > 0) then
          Used := Dir + Countries[I] + '.csv'
        else
          Out_.Add(Countries[I] + ': NEUSPJEH - ' + E2);
        if Used <> '' then
        begin
          SetLength(Files, Length(Files) + 1);
          Files[High(Files)] := Used;
          Inc(Got);
        end;
      end;
      Out_.Add(Format('datoteke drzava: %d od %d pojedinacno (skupna nije uspjela: %s)', [Got, Length(Countries), Err]));
    end;

    { 2. najnoviji rezultati dodatnih liga }
    HaveLatest := False;
    LatestFile := '';
    if HttpFetchToFile(BaseUrl + 'new/Latest_Results.xlsx', Dir + 'Latest_Results.xlsx', ATimeoutSec, Err) and (CountCountrySheets(Dir + 'Latest_Results.xlsx') > 0) then
    begin LatestFile := Dir + 'Latest_Results.xlsx'; HaveLatest := True; end
    else if HttpFetchToFile(BaseUrl + 'new/Latest_Results.csv', Dir + 'Latest_Results.csv', ATimeoutSec, E2) and (CountCountrySheets(Dir + 'Latest_Results.csv') > 0) then
    begin LatestFile := Dir + 'Latest_Results.csv'; HaveLatest := True; end
    else Out_.Add('najnoviji dodatnih liga: NEUSPJEH - ' + Err + '; ' + E2);

    { 3. raspored dodatnih liga }
    HaveFix := False;
    FixFile := '';
    if HttpFetchToFile(BaseUrl + 'new_league_fixtures.xlsx', Dir + 'new_league_fixtures.xlsx', ATimeoutSec, Err) and (CountFixtureRows(Dir + 'new_league_fixtures.xlsx') >= 0) then
    begin FixFile := Dir + 'new_league_fixtures.xlsx'; HaveFix := True; end
    else if HttpFetchToFile(BaseUrl + 'new_league_fixtures.csv', Dir + 'new_league_fixtures.csv', ATimeoutSec, E2) then
    begin FixFile := Dir + 'new_league_fixtures.csv'; HaveFix := True; end
    else Out_.Add('raspored dodatnih liga: NEUSPJEH - ' + Err + '; ' + E2);

    { 4. uvoz }
    Tot := 0; TotOdds := 0;
    for I := 0 to High(Files) do
    try
      Rep := ImportCountryFile(ADb, Files[I], False);
      Inc(Tot, Rep.Matches); Inc(TotOdds, Rep.Odds);
      if Rep.Problems <> '' then Out_.Add(ExtractFileName(Files[I]) + ': ' + Rep.Problems);
    except
      on E: Exception do Out_.Add(ExtractFileName(Files[I]) + ': uvoz NEUSPJEH - ' + E.Message);
    end;
    if Length(Files) > 0 then Out_.Add(Format('uvoz dodatnih liga: %d utakmica, %d kvota', [Tot, TotOdds]));
    if HaveLatest then
    try
      Rep := ImportCountryFile(ADb, LatestFile, True);
      Out_.Add(Format('uvoz najnovijih dodatnih liga: %d utakmica', [Rep.Matches]));
    except
      on E: Exception do Out_.Add('uvoz najnovijih dodatnih liga: preskoceno - ' + E.Message);
    end;
    if HaveFix then
    try
      N := ImportFixtureFile(ADb, FixFile);
      Out_.Add(Format('raspored dodatnih liga: %d novih utakmica u tablici fixtures', [N]));
    except
      on E: Exception do Out_.Add('raspored dodatnih liga: NEUSPJEH - ' + E.Message);
    end;
    Result := Trim(Out_.Text);
  finally
    Out_.Free;
  end;
end;

{ datum iz izraza kao 'GGGG-MM-DD'; prazno za prazan argument }
function DateToIsoArg(const V: Variant): string;
var
  D: TDateTime;
begin
  Result := '';
  if VarIsNull(V) or (VarToStr(V) = '') then Exit;
  if VarIsType(V, varDate) then Exit(FormatDateTime('yyyy-mm-dd', Trunc(TDateTime(V))));
  if (Length(VarToStr(V)) >= 10) and (VarToStr(V)[5] = '-') then Exit(Copy(VarToStr(V), 1, 10));
  if ParseAnyDateTime(VarToStr(V), D) then Result := FormatDateTime('yyyy-mm-dd', Trunc(D));
end;

function DataHookImpl(const AName: string; const A: array of Variant; N: Integer): Variant;
var
  Err, Season: string;
  Timeout: Integer;
  Rep: TaImportReport;
  CRep: TaCountryReport;
  Out_Path: string;
  Tabs: TStringList;
  HasTables: Boolean;
begin
  Result := Null;
  if (ActiveDb = nil) or not ActiveDb.Connected then Exit;
  if AName = 'downloadfile' then
  begin
    if (Trim(VarToStr(A[0])) = '') or (Trim(VarToStr(A[1])) = '') then Exit(0);   { nema sto preuzeti }
    Timeout := 60;
    if (N >= 3) and not VarIsNull(A[2]) then Timeout := Trunc(Double(A[2]));
    if not HttpFetchToFile(VarToStr(A[0]), VarToStr(A[1]), Timeout, Err) then raise EExpr.Create('DownloadFile: ' + Err);
    Result := FSize(VarToStr(A[1]));
  end
  else if AName = 'importmatches' then
  begin
    if Trim(VarToStr(A[0])) = '' then Exit(0);
    Season := '';
    if (N >= 2) and not VarIsNull(A[1]) then Season := VarToStr(A[1]);
    Rep := ImportMatchFile(ActiveDb, VarToStr(A[0]), Season, (N >= 3) and not VarIsNull(A[2]) and (Trunc(Double(A[2])) <> 0), False);
    if not Rep.Kept then raise EExpr.Create('ImportMatches: ' + Rep.Problems);
    Result := Rep.Matches;
  end
  else if AName = 'importcountries' then
  begin
    if Trim(VarToStr(A[0])) = '' then Exit(0);
    CRep := ImportCountryFile(ActiveDb, VarToStr(A[0]), (N >= 2) and not VarIsNull(A[1]) and (Trunc(Double(A[1])) <> 0));
    Result := CRep.Matches;
  end
  else if AName = 'latestround' then
  begin
    Tabs := ActiveDb.UserTables;
    try
      HasTables := (Tabs.IndexOf('slips') >= 0) and (Tabs.IndexOf('slip_legs') >= 0);
    finally
      Tabs.Free;
    end;
    if not HasTables then Exit('');
    Result := LatestRound(ActiveDb, (N >= 1) and not VarIsNull(A[0]) and (Trunc(Double(A[0])) <> 0));
  end
  else if AName = 'roundreport' then
  begin
    { RoundReport(datum [, rezultati [, datoteka]]): tekst izvjestaja; ako je datoteka navedena, upisuje se i u nju }
    Season := DateToIsoArg(A[0]);
    if Season = '' then Exit('');
    Tabs := ActiveDb.UserTables;
    try
      HasTables := (Tabs.IndexOf('slips') >= 0) and (Tabs.IndexOf('slip_legs') >= 0);
    finally
      Tabs.Free;
    end;
    if not HasTables then Exit('');
    Result := BuildRoundReport(ActiveDb, Season, (N >= 2) and not VarIsNull(A[1]) and (Trunc(Double(A[1])) <> 0));
    if (N >= 3) and (Trim(VarToStr(A[2])) <> '') then
    begin
      { relativna putanja je uz bazu (mapa reports), kao u SmartBetu }
      Out_Path := VarToStr(A[2]);
      if Out_Path[1] <> '/' then Out_Path := ExtractFilePath(ExpandFileName(ActiveDb.Conn.Database)) + Out_Path;
      ForceDirectories(ExtractFilePath(Out_Path));
      with TStringList.Create do
      try
        Text := VarToStr(Result) + LineEnding;
        SaveToFile(Out_Path);
      finally
        Free;
      end;
    end;
  end
  else if (AName = 'refreshcroatia') or (AName = 'refreshuefa') then
  begin
    Season := '';
    if (N >= 1) and not VarIsNull(A[0]) then Season := VarToStr(A[0]);
    Tabs := ActiveDb.UserTables;
    try
      HasTables := (Tabs.IndexOf('matches') >= 0) and (Tabs.IndexOf('divisions') >= 0) and (Tabs.IndexOf('match_odds') >= 0) and (Tabs.IndexOf('match_stats') >= 0);
    finally
      Tabs.Free;
    end;
    if not HasTables then Exit('Osvjezavanje treba bazu s tablicama divisions, matches, match_odds i match_stats.');
    if AName = 'refreshcroatia' then Result := RefreshCroatiaSource(ActiveDb, Season, '', 30)
    else Result := RefreshUefaSource(ActiveDb, Season, '', 30);
  end
  else if AName = 'refreshcountries' then
  begin
    Tabs := ActiveDb.UserTables;
    try
      HasTables := (Tabs.IndexOf('matches') >= 0) and (Tabs.IndexOf('divisions') >= 0) and (Tabs.IndexOf('match_odds') >= 0) and (Tabs.IndexOf('match_stats') >= 0);
    finally
      Tabs.Free;
    end;
    if not HasTables then Exit('Osvjezavanje treba bazu s tablicama divisions, matches, match_odds i match_stats.');
    Result := RefreshCountries(ActiveDb, '', 60);
  end
  else if AName = 'refreshmain' then
  begin
    Season := '';
    if (N >= 1) and not VarIsNull(A[0]) then Season := VarToStr(A[0]);
    Tabs := ActiveDb.UserTables;
    try
      HasTables := (Tabs.IndexOf('matches') >= 0) and (Tabs.IndexOf('divisions') >= 0) and (Tabs.IndexOf('match_odds') >= 0) and (Tabs.IndexOf('match_stats') >= 0);
    finally
      Tabs.Free;
    end;
    if not HasTables then Exit('Osvjezavanje treba bazu s tablicama divisions, matches, match_odds i match_stats.');
    Result := RefreshMainSource(ActiveDb, Season, '', 60);
  end;
end;

initialization
  DataHook := @DataHookImpl;

end.
