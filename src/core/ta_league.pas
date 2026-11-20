unit ta_league;
{ Tablica lige, trendovi i profili ponasanja (pregled lige), forma momcadi, medjusobni susreti i profil po
  razdobljima: nativna replika SMART-BETTING-APP analytics/standings.py, analytics/form.py i dashboarda.
    RunLeagueOverview(liga, sezona)      -> liga_tablica, liga_trendovi, liga_profili
    TeamForm(klub [, datum [, broj]])    -> tekst "WWLWD" (najstarija utakmica lijevo)
    RunHeadToHead(domaci, gosti [, datum]) -> h2h_sazetak, h2h_susreti
    RunSeasonProfile(klub [, datum])     -> forma_profil (5 razdoblja po 12 mjeseci, najnovije prvo) }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, StrUtils, Variants, ZDataset, ta_meta, ta_expr, ta_exprdb, ta_predict, ta_newton;

const
  FormLength = 5;
  H2hDetail = 6;
  SeasonDays = 365;
  SeasonBuckets = 5;

function RunLeagueOverview(ADb: TAppDb; const ADiv, ASeason: string): Integer;
{ najnovijih ALimit utakmica prije ABefore ('' = sve), "W/D/L" od najstarije prema najnovijoj }
function FormOf(ADb: TAppDb; const ATeam, ABefore: string; ALimit: Integer): string;
function RunHeadToHead(ADb: TAppDb; const AHome, AAway, ABefore: string): Integer;
function RunSeasonProfile(ADb: TAppDb; const ATeam, ABefore: string): Integer;

implementation

function DotFs: TFormatSettings;
begin
  Result := DefaultFormatSettings;
  Result.DecimalSeparator := '.';
end;

function F_(X: Double): string;
begin
  Result := FloatToStrF(X, ffGeneral, 17, 0, DotFs);
end;

function Q_(const S: string): string;
begin
  Result := '''' + StringReplace(S, '''', '''''', [rfReplaceAll]) + '''';
end;

function HasTable(ADb: TAppDb; const AName: string): Boolean;
var
  Tabs: TStringList;
begin
  Tabs := ADb.UserTables;
  try
    Result := Tabs.IndexOf(AName) >= 0;
  finally
    Tabs.Free;
  end;
end;

{ ---------------- pregled lige ---------------- }

function RunLeagueOverview(ADb: TAppDb; const ADiv, ASeason: string): Integer;
var
  Q: TZQuery;
  Pos_, N: Integer;
  MaxDay: string;
  Total, Goals: Double;
  Pr: TaPredictor;
  Prof: TaProfiles;
  Teams: TStringList;
  I: Integer;
  Cb, Cl: Double;

  procedure Trend(const AName: string; AValue: Double);
  begin
    ADb.Conn.ExecuteDirect('INSERT INTO liga_trendovi (naziv, vrijednost) VALUES (' + Q_(AName) + ',' + F_(AValue) + ')');
  end;

begin
  Result := 0;
  if not HasTable(ADb, 'matches') then Exit;
  ADb.Conn.ExecuteDirect('DROP TABLE IF EXISTS liga_tablica');
  ADb.Conn.ExecuteDirect('DROP TABLE IF EXISTS liga_trendovi');
  ADb.Conn.ExecuteDirect('DROP TABLE IF EXISTS liga_profili');
  ADb.Conn.ExecuteDirect('CREATE TABLE liga_tablica (id INTEGER PRIMARY KEY AUTOINCREMENT, poz INTEGER, momcad TEXT, odigrano INTEGER, pobjede INTEGER, neodluceno INTEGER, ' +
    'porazi INTEGER, gf INTEGER, ga INTEGER, gr INTEGER, bodovi INTEGER, ppg REAL)');
  ADb.Conn.ExecuteDirect('CREATE TABLE liga_trendovi (id INTEGER PRIMARY KEY AUTOINCREMENT, naziv TEXT, vrijednost REAL)');
  ADb.Conn.ExecuteDirect('CREATE TABLE liga_profili (id INTEGER PRIMARY KEY AUTOINCREMENT, momcad TEXT, closer_index REAL, chaos_index REAL, comeback_rate REAL, collapse_rate REAL)');
  Q := ADb.NewQuery(
    'SELECT team, SUM(w + d + l) AS played, SUM(w) AS won, SUM(d) AS drawn, SUM(l) AS lost, SUM(gf) AS gf, SUM(ga) AS ga FROM (' +
    'SELECT hometeam AS team, fthg AS gf, ftag AS ga, ftr = ''H'' AS w, ftr = ''D'' AS d, ftr = ''A'' AS l FROM matches WHERE division = :d AND season = :s AND ftr IS NOT NULL ' +
    'UNION ALL SELECT awayteam, ftag, fthg, ftr = ''A'', ftr = ''D'', ftr = ''H'' FROM matches WHERE division = :d AND season = :s AND ftr IS NOT NULL) ' +
    'GROUP BY team ORDER BY SUM(w) * 3 + SUM(d) DESC, SUM(gf) - SUM(ga) DESC, SUM(gf) DESC, team ASC');
  Teams := TStringList.Create;
  Teams.CaseSensitive := True;
  ADb.Conn.StartTransaction;
  try
    Q.ParamByName('d').AsString := ADiv; Q.ParamByName('s').AsString := ASeason;
    Q.Open;
    Pos_ := 0;
    while not Q.Eof do
    begin
      Inc(Pos_);
      N := Q.Fields[2].AsInteger * 3 + Q.Fields[3].AsInteger;
      Teams.Add(Q.Fields[0].AsString);
      ADb.Conn.ExecuteDirect('INSERT INTO liga_tablica (poz, momcad, odigrano, pobjede, neodluceno, porazi, gf, ga, gr, bodovi, ppg) VALUES (' + IntToStr(Pos_) + ',' +
        Q_(Q.Fields[0].AsString) + ',' + IntToStr(Q.Fields[1].AsInteger) + ',' + IntToStr(Q.Fields[2].AsInteger) + ',' + IntToStr(Q.Fields[3].AsInteger) + ',' +
        IntToStr(Q.Fields[4].AsInteger) + ',' + IntToStr(Q.Fields[5].AsInteger) + ',' + IntToStr(Q.Fields[6].AsInteger) + ',' +
        IntToStr(Q.Fields[5].AsInteger - Q.Fields[6].AsInteger) + ',' + IntToStr(N) + ',' +
        IfThen(Q.Fields[1].AsInteger > 0, F_(N / Q.Fields[1].AsInteger), '0') + ')');
      Q.Next;
    end;
    Q.Close;
    { trendovi lige }
    Q.SQL.Text := 'SELECT COUNT(*), AVG(fthg + ftag), AVG(ftr = ''H''), AVG(ftr = ''D''), AVG(ftr = ''A''), AVG(fthg + ftag > 2.5), AVG(fthg > 0 AND ftag > 0) ' +
      'FROM matches WHERE division = :d AND season = :s AND ftr IS NOT NULL';
    Q.ParamByName('d').AsString := ADiv; Q.ParamByName('s').AsString := ASeason;
    Q.Open;
    if Q.Fields[0].AsInteger > 0 then
    begin
      Trend('utakmica', Q.Fields[0].AsInteger); Trend('golova_po_utakmici', Q.Fields[1].AsFloat);
      Trend('domaci_pobjede', Q.Fields[2].AsFloat); Trend('neodluceno', Q.Fields[3].AsFloat); Trend('gosti_pobjede', Q.Fields[4].AsFloat);
      Trend('over25', Q.Fields[5].AsFloat); Trend('gg', Q.Fields[6].AsFloat);
    end;
    Q.Close;
    Q.SQL.Text := 'SELECT MAX(matchdate) FROM matches WHERE division = :d AND season = :s';
    Q.ParamByName('d').AsString := ADiv; Q.ParamByName('s').AsString := ASeason;
    Q.Open;
    if Q.Fields[0].IsNull then MaxDay := '' else MaxDay := Q.Fields[0].AsString;
    Q.Close;
    ADb.Conn.Commit;
  except
    ADb.Conn.Rollback;
    Q.Free; Teams.Free;
    raise;
  end;
  Q.Free;
  Result := Pos_;
  if MaxDay = '' then begin Teams.Free; Exit; end;
  { profili: iz podataka do kraja sezone (referentni dan = zadnji dan + 1), samo ta liga }
  Pr := TaPredictor.Create(ADb);
  try
    Prof := Pr.DivisionProfiles(ADiv, DayOfText(MaxDay) + 1);
  finally
    Pr.Free;
  end;
  try
    if Prof <> nil then
    begin
      Teams.Sorted := False;
      ADb.Conn.StartTransaction;
      try
        for I := 0 to Teams.Count - 1 do
        begin
          if Prof.Teams.IndexOf(Teams[I]) < 0 then Continue;     { Python table(): samo momcadi koje je profil vidio }
          Prof.Rates(Teams[I], Cb, Cl);
          ADb.Conn.ExecuteDirect('INSERT INTO liga_profili (momcad, closer_index, chaos_index, comeback_rate, collapse_rate) VALUES (' + Q_(Teams[I]) + ',' +
            F_(Prof.CloserIndex(Teams[I])) + ',' + F_(Prof.ChaosIndex(Teams[I])) + ',' + F_(Cb) + ',' + F_(Cl) + ')');
        end;
        ADb.Conn.Commit;
      except
        ADb.Conn.Rollback;
        raise;
      end;
    end;
  finally
    Prof.Free;
    Teams.Free;
  end;
end;

{ ---------------- forma ---------------- }

function FormOf(ADb: TAppDb; const ATeam, ABefore: string; ALimit: Integer): string;
var
  Q: TZQuery;
  Sc, Cn: Integer;
  S: string;
  Ch: string;
begin
  Result := '';
  if not HasTable(ADb, 'matches') then Exit;
  S := 'SELECT hometeam, fthg, ftag FROM matches WHERE (hometeam = :t OR awayteam = :t)';
  if ABefore <> '' then S := S + ' AND matchdate < :b';
  S := S + ' ORDER BY matchdate DESC, match_id DESC LIMIT ' + IntToStr(ALimit);
  Q := ADb.NewQuery(S);
  try
    Q.ParamByName('t').AsString := ATeam;
    if ABefore <> '' then Q.ParamByName('b').AsString := ABefore;
    Q.Open;
    while not Q.Eof do
    begin
      if Q.Fields[0].AsString = ATeam then begin Sc := Q.Fields[1].AsInteger; Cn := Q.Fields[2].AsInteger; end
      else begin Sc := Q.Fields[2].AsInteger; Cn := Q.Fields[1].AsInteger; end;
      if Sc > Cn then Ch := 'W' else if Sc = Cn then Ch := 'D' else Ch := 'L';
      Result := Ch + Result;                 { najnovija ide desno }
      Q.Next;
    end;
  finally
    Q.Free;
  end;
end;

{ ---------------- medjusobni susreti ---------------- }

function RunHeadToHead(ADb: TAppDb; const AHome, AAway, ABefore: string): Integer;
var
  Q: TZQuery;
  S, First, Last, Out_: string;
  Played, Wins, Draws, Losses, Scored, Conceded, Both, Over, Sc, Cn: Integer;
  AtHome: Boolean;

  procedure Sum(const AName: string; AValue: Double; const AText: string = '');
  begin
    ADb.Conn.ExecuteDirect('INSERT INTO h2h_sazetak (naziv, vrijednost, tekst) VALUES (' + Q_(AName) + ',' + F_(AValue) + ',' + Q_(AText) + ')');
  end;

begin
  Result := 0;
  if not HasTable(ADb, 'matches') then Exit;
  ADb.Conn.ExecuteDirect('DROP TABLE IF EXISTS h2h_sazetak');
  ADb.Conn.ExecuteDirect('DROP TABLE IF EXISTS h2h_susreti');
  ADb.Conn.ExecuteDirect('CREATE TABLE h2h_sazetak (id INTEGER PRIMARY KEY AUTOINCREMENT, naziv TEXT, vrijednost REAL, tekst TEXT)');
  ADb.Conn.ExecuteDirect('CREATE TABLE h2h_susreti (id INTEGER PRIMARY KEY AUTOINCREMENT, datum TEXT, liga TEXT, domaci TEXT, gosti TEXT, rezultat TEXT, ishod TEXT)');
  S := 'SELECT matchdate, division, hometeam, awayteam, fthg, ftag FROM matches WHERE ((hometeam = :h AND awayteam = :a) OR (hometeam = :a AND awayteam = :h))';
  if ABefore <> '' then S := S + ' AND matchdate < :b';
  S := S + ' ORDER BY matchdate DESC, match_id DESC';
  Q := ADb.NewQuery(S);
  Played := 0; Wins := 0; Draws := 0; Losses := 0; Scored := 0; Conceded := 0; Both := 0; Over := 0;
  First := ''; Last := '';
  ADb.Conn.StartTransaction;
  try
    Q.ParamByName('h').AsString := AHome; Q.ParamByName('a').AsString := AAway;
    if ABefore <> '' then Q.ParamByName('b').AsString := ABefore;
    Q.Open;
    while not Q.Eof do
    begin
      AtHome := Q.Fields[2].AsString = AHome;
      if AtHome then begin Sc := Q.Fields[4].AsInteger; Cn := Q.Fields[5].AsInteger; end
      else begin Sc := Q.Fields[5].AsInteger; Cn := Q.Fields[4].AsInteger; end;
      Inc(Played);
      Scored := Scored + Sc; Conceded := Conceded + Cn;
      if Sc > Cn then begin Inc(Wins); Out_ := 'W'; end else if Sc = Cn then begin Inc(Draws); Out_ := 'D'; end else begin Inc(Losses); Out_ := 'L'; end;
      if (Sc > 0) and (Cn > 0) then Inc(Both);
      if Sc + Cn > 2 then Inc(Over);
      if Played = 1 then Last := Q.Fields[0].AsString;
      First := Q.Fields[0].AsString;
      if Played <= H2hDetail then
        ADb.Conn.ExecuteDirect('INSERT INTO h2h_susreti (datum, liga, domaci, gosti, rezultat, ishod) VALUES (' + Q_(Q.Fields[0].AsString) + ',' + Q_(Q.Fields[1].AsString) + ',' +
          Q_(Q.Fields[2].AsString) + ',' + Q_(Q.Fields[3].AsString) + ',' + Q_(IntToStr(Sc) + '-' + IntToStr(Cn)) + ',' + Q_(Out_) + ')');
      Q.Next;
    end;
    Sum('susreta', Played);
    if Played > 0 then
    begin
      Sum('pobjeda', Wins); Sum('neodluceno', Draws); Sum('poraza', Losses); Sum('golova_zadano', Scored); Sum('golova_primljeno', Conceded);
      Sum('golova_po_utakmici', (Scored + Conceded) / Played); Sum('oba_zabila', Both / Played); Sum('preko25', Over / Played);
      Sum('prvi_susret', 0, First); Sum('zadnji_susret', 0, Last);
    end;
    ADb.Conn.Commit;
  except
    ADb.Conn.Rollback;
    Q.Free;
    raise;
  end;
  Q.Free;
  Result := Played;
end;

{ ---------------- profil po razdobljima ---------------- }

function RunSeasonProfile(ADb: TAppDb; const ATeam, ABefore: string): Integer;
var
  Q: TZQuery;
  EndDay, K, Lo, Hi, Day, Played, Wins, Draws, Scored, Conceded, Both, Over, Gf, Ga: Integer;
  Cnt: array of Integer;
  Start: Integer;

  function Num(AIsNull: Boolean; AValue: Double): string;
  begin
    if AIsNull then Result := 'NULL' else Result := F_(AValue);
  end;

begin
  Result := 0;
  if not HasTable(ADb, 'matches') then Exit;
  if ABefore = '' then EndDay := Trunc(Date) else EndDay := DayOfText(ABefore);
  Start := EndDay - SeasonDays * SeasonBuckets;
  ADb.Conn.ExecuteDirect('DROP TABLE IF EXISTS forma_profil');
  ADb.Conn.ExecuteDirect('CREATE TABLE forma_profil (id INTEGER PRIMARY KEY AUTOINCREMENT, razdoblje INTEGER, od TEXT, do_ TEXT, odigrano INTEGER, pobjede INTEGER, neodluceno INTEGER, ' +
    'porazi INTEGER, bodova_po_utakmici REAL, zadano_po_utakmici REAL, primljeno_po_utakmici REAL, oba_zabila REAL, preko25 REAL)');
  ADb.Conn.StartTransaction;
  try
    for K := 0 to SeasonBuckets - 1 do
    begin
      Lo := EndDay - SeasonDays * (K + 1); Hi := EndDay - SeasonDays * K;
      Q := ADb.NewQuery('SELECT hometeam, fthg, ftag FROM matches WHERE (hometeam = :t OR awayteam = :t) AND matchdate >= :lo AND matchdate < :hi');
      Played := 0; Wins := 0; Draws := 0; Scored := 0; Conceded := 0; Both := 0; Over := 0;
      try
        Q.ParamByName('t').AsString := ATeam;
        Q.ParamByName('lo').AsString := FormatDateTime('yyyy-mm-dd', Lo);
        Q.ParamByName('hi').AsString := FormatDateTime('yyyy-mm-dd', Hi);
        Q.Open;
        while not Q.Eof do
        begin
          if Q.Fields[0].AsString = ATeam then begin Gf := Q.Fields[1].AsInteger; Ga := Q.Fields[2].AsInteger; end
          else begin Gf := Q.Fields[2].AsInteger; Ga := Q.Fields[1].AsInteger; end;
          Inc(Played);
          Scored := Scored + Gf; Conceded := Conceded + Ga;
          if Gf > Ga then Inc(Wins);
          if Gf = Ga then Inc(Draws);
          if (Gf > 0) and (Ga > 0) then Inc(Both);
          if Gf + Ga > 2 then Inc(Over);
          Q.Next;
        end;
      finally
        Q.Free;
      end;
      ADb.Conn.ExecuteDirect('INSERT INTO forma_profil (razdoblje, od, do_, odigrano, pobjede, neodluceno, porazi, bodova_po_utakmici, zadano_po_utakmici, primljeno_po_utakmici, oba_zabila, preko25) VALUES (' +
        IntToStr(K) + ',' + Q_(FormatDateTime('yyyy-mm-dd', Lo)) + ',' + Q_(FormatDateTime('yyyy-mm-dd', Hi)) + ',' + IntToStr(Played) + ',' + IntToStr(Wins) + ',' +
        IntToStr(Draws) + ',' + IntToStr(Played - Wins - Draws) + ',' + Num(Played = 0, (3 * Wins + Draws) / Max(Played, 1)) + ',' +
        Num(Played = 0, Scored / Max(Played, 1)) + ',' + Num(Played = 0, Conceded / Max(Played, 1)) + ',' + Num(Played = 0, Both / Max(Played, 1)) + ',' +
        Num(Played = 0, Over / Max(Played, 1)) + ')');
    end;
    ADb.Conn.Commit;
  except
    ADb.Conn.Rollback;
    raise;
  end;
  Result := SeasonBuckets;
end;

{ ---------------- izrazi ---------------- }

function LeagueHookImpl(const AName: string; const A: array of Variant; N: Integer): Variant;
var
  Before: string;
  Lim: Integer;
begin
  Result := Null;
  if (ActiveDb = nil) or not ActiveDb.Connected then Exit;
  if AName = 'runleagueoverview' then
    Exit(RunLeagueOverview(ActiveDb, UpperCase(Trim(VarToStr(A[0]))), Trim(VarToStr(A[1]))));
  if AName = 'teamform' then
  begin
    Before := ''; Lim := FormLength;
    if (N >= 2) and not VarIsNull(A[1]) and (VarToStr(A[1]) <> '') then Before := FormatDateTime('yyyy-mm-dd', DayOfArg(A[1]));
    if (N >= 3) and not VarIsNull(A[2]) then Lim := Max(1, Trunc(Double(A[2])));
    Exit(FormOf(ActiveDb, Trim(VarToStr(A[0])), Before, Lim));
  end;
  Before := '';
  if (N >= 3) and not VarIsNull(A[2]) and (VarToStr(A[2]) <> '') then Before := FormatDateTime('yyyy-mm-dd', DayOfArg(A[2]));
  if AName = 'runheadtohead' then Exit(RunHeadToHead(ActiveDb, Trim(VarToStr(A[0])), Trim(VarToStr(A[1])), Before));
  { runseasonprofile }
  Before := '';
  if (N >= 2) and not VarIsNull(A[1]) and (VarToStr(A[1]) <> '') then Before := FormatDateTime('yyyy-mm-dd', DayOfArg(A[1]));
  Exit(RunSeasonProfile(ActiveDb, Trim(VarToStr(A[0])), Before));
end;

initialization
  LeagueHook := @LeagueHookImpl;

end.
