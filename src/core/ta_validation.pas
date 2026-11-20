unit ta_validation;
{ Provjera ispravnosti datoteke sezone prije uvoza: nativna replika SMART-BETTING-APP smartbet/validation.py
  (validate_season) nad csv datotekom s utakmicama. Cita datoteku, usporedi je s onim sto baza vec ima i
  izvjesti sto bi se stvarno promijenilo. Nalazi imaju razinu GRESKA (nemoguci podaci, uvoz se odbija),
  UPOZORENJE (vjerojatno u redu, ali treba pogledati) i INFO (normalne cinjenice sezone koja traje).
  ValidateSeason(datoteka [, sezona]) upisuje tablice validacija_sazetak i validacija_nalazi i vraca broj GRESAKA,
  pa 4GL moze odbiti uvoz kad je rezultat veci od nule. Pravila, pragovi i poruke su isti kao u Pythonu. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, StrUtils, Variants, ZDataset, ta_meta, ta_expr, ta_exprdb, ta_importexport, ta_dataimport;

type
  TIntegerArr = array of Integer;
  TaVLevel = (vlInfo, vlWarning, vlError);

  TaVIssue = record
    Level: TaVLevel;
    Code, Msg, Examples: string;       { primjeri odvojeni znakom #10 }
  end;

  TaVReport = record
    Season, FileName: string;
    Played, Unplayed, Malformed, InDatabase, Added, Updated, Removed: Integer;
    Issues: array of TaVIssue;
    Errors, Warnings: Integer;
  end;

function ValidateSeasonFile(ADb: TAppDb; const AFile, ASeason: string; AMinRatio: Double = 0.5): TaVReport;
{ upise tablice validacija_*; vrati broj gresaka }
function ValidateSeasonToTables(ADb: TAppDb; const AFile, ASeason: string): Integer;
{ ispis za provjeru pariteta (naredba --validate) }
procedure ValidateSeasonWrite(ADb: TAppDb; const AFile, ASeason: string);

implementation

const
  MaxPlausibleGoals = 20;
  MaxExamples = 6;
  MinRowsForRate = 30;
  RateWarningSigmas = 3.0;
  RateErrorSigmas = 5.0;
  MinSeasonsForNorm = 5;
  RecentSeasonsForLength = 5;
  MadToSigma = 1.4826;
  Replacement = #$EF#$BF#$BD;      { U+FFFD u UTF-8 }

type
  TVRow = record
    Div_, Date, Season, Home, Away, Ftr, FileFtr: string;
    Fthg, Ftag, Hthg, Htag: Integer;
    HasHt: Boolean;
  end;

  TSkip = record
    Line: Integer;
    Reason: string;
  end;

function DotFs: TFormatSettings;
begin
  Result := DefaultFormatSettings;
  Result.DecimalSeparator := '.';
end;

function F2(X: Double): string; begin Result := Format('%.2f', [X], DotFs); end;
function F0(X: Double): string; begin Result := Format('%.0f', [X], DotFs); end;
function F1(X: Double): string; begin Result := Format('%.1f', [X], DotFs); end;
function Pct1(X: Double): string; begin Result := Format('%.1f%%', [X * 100], DotFs); end;

{ ---------------- ucitavanje (ingest.scan_csv) ---------------- }

function StrictInt(const S: string; out V: Integer): Boolean;
var
  I, Start: Integer;
  T: string;
begin
  Result := False;
  T := Trim(S);
  if T = '' then Exit;
  Start := 1;
  if (T[1] = '+') or (T[1] = '-') then Start := 2;
  if Start > Length(T) then Exit;
  for I := Start to Length(T) do
    if not (T[I] in ['0'..'9']) then Exit;
  V := StrToInt(T);
  Result := True;
end;

{ ingest._normalise_date: ISO ili dd/mm/yy(yy) }
function NormDate(const Raw: string): string;
var
  T, D, M, Y: string;
  P1, P2: Integer;
begin
  Result := '';
  T := Trim(Raw);
  if T = '' then Exit;
  if (Length(T) >= 10) and (T[5] = '-') and (T[8] = '-') then Exit(Copy(T, 1, 10));
  P1 := Pos('/', T);
  if P1 = 0 then Exit;
  P2 := PosEx('/', T, P1 + 1);
  if P2 = 0 then Exit;
  if PosEx('/', T, P2 + 1) > 0 then Exit;
  D := Trim(Copy(T, 1, P1 - 1)); M := Trim(Copy(T, P1 + 1, P2 - P1 - 1)); Y := Trim(Copy(T, P2 + 1, MaxInt));
  if (StrToIntDef(D, -1) < 0) or (StrToIntDef(M, -1) < 0) or (StrToIntDef(Y, -1) < 0) then Exit;
  if Length(Y) = 2 then
  begin
    if StrToInt(Y) < 70 then Y := '20' + Y else Y := '19' + Y;
  end;
  Result := Format('%s-%.2d-%.2d', [Y, StrToInt(M), StrToInt(D)]);
end;

function ResultOf(H, A: Integer): string;
begin
  if H > A then Result := 'H' else if A > H then Result := 'A' else Result := 'D';
end;

function SeasonOfFileName(const AFile: string): string;
var
  Stem, C: string;
begin
  Result := '';
  Stem := ChangeFileExt(ExtractFileName(AFile), '');
  if (Copy(Stem, 1, 3) = 'all') and (Pos('-', Stem) > 0) then
  begin
    C := Copy(Stem, 4, MaxInt);
    if (Length(C) = 9) and (StrToIntDef(Copy(C, 1, 4), -1) >= 0) and (StrToIntDef(Copy(C, 6, 4), -1) >= 0) and (C[5] = '-') then Result := C;
  end;
end;

function ColOf(const AHead: array of string; const AAlias: array of string): Integer;
var
  I, J: Integer;
begin
  for I := 0 to High(AHead) do
    for J := 0 to High(AAlias) do
      if LowerCase(Trim(AHead[I])) = AAlias[J] then Exit(I);
  Result := -1;
end;

type
  TKv = class
    Keys, Vals, Lookup: TStringList;
    constructor Create;
    destructor Destroy; override;
    function Find(const AKey: string): Integer;
    procedure Put(const AKey, AVal: string; AKeepFirst: Boolean);
  end;

constructor TKv.Create;
begin
  Keys := TStringList.Create; Vals := TStringList.Create;
  Lookup := TStringList.Create; Lookup.CaseSensitive := True; Lookup.Sorted := True; Lookup.Duplicates := dupIgnore;
end;

destructor TKv.Destroy;
begin
  Keys.Free; Vals.Free; Lookup.Free;
  inherited Destroy;
end;

function TKv.Find(const AKey: string): Integer;
var
  I: Integer;
begin
  I := Lookup.IndexOf(AKey);
  if I < 0 then Result := -1 else Result := PtrInt(Lookup.Objects[I]);
end;

procedure TKv.Put(const AKey, AVal: string; AKeepFirst: Boolean);
var
  I: Integer;
begin
  I := Find(AKey);
  if I >= 0 then
  begin
    if not AKeepFirst then Vals[I] := AVal;
    Exit;
  end;
  Keys.Add(AKey); Vals.Add(AVal);
  Lookup.AddObject(AKey, TObject(PtrInt(Keys.Count - 1)));
end;

function CompareStrList_(List: TStringList; I, J: Integer): Integer;
begin
  Result := CompareStr(List[I], List[J]);
end;

{ ---------------- pomocne ---------------- }

function Fixture(const R: TVRow): string;
begin
  Result := R.Date + ' ' + R.Div_ + ' ' + R.Home + '-' + R.Away;
end;

function KeyOf(const R: TVRow): string;
begin
  Result := R.Div_ + #1 + R.Date + #1 + R.Home + #1 + R.Away;
end;

procedure AddIssue(var AR: TaVReport; ALevel: TaVLevel; const ACode, AMsg: string; const AEx: TStrings);
var
  N, I: Integer;
  Ex: string;
begin
  N := Length(AR.Issues);
  SetLength(AR.Issues, N + 1);
  AR.Issues[N].Level := ALevel; AR.Issues[N].Code := ACode; AR.Issues[N].Msg := AMsg;
  Ex := '';
  if AEx <> nil then
  begin
    for I := 0 to AEx.Count - 1 do
    begin
      if I >= MaxExamples then Break;
      if Ex <> '' then Ex := Ex + #10;
      Ex := Ex + AEx[I];
    end;
    if AEx.Count > MaxExamples then Ex := Ex + #10 + '... i jos ' + IntToStr(AEx.Count - MaxExamples);
  end;
  AR.Issues[N].Examples := Ex;
  if ALevel = vlError then Inc(AR.Errors);
  if ALevel = vlWarning then Inc(AR.Warnings);
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

function Q_(const S: string): string;
begin
  Result := '''' + StringReplace(S, '''', '''''', [rfReplaceAll]) + '''';
end;

function TableExists(ADb: TAppDb; const AName: string): Boolean;
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

{ ---------------- osteceni nazivi klubova (ingest.repair_team_names) ---------------- }

{ je li ime AName jedno od onih koje obrazac (ostecen naziv) pokriva: niz zamjenskih znakova duljine N zamjenjuje 1..N znakova }
function MojibakeMatch(const ABroken, AName: string): Boolean;
var
  B, N: UnicodeString;

  function Rec(I, J: Integer): Boolean;
  var
    Run, K: Integer;
  begin
    if I > Length(B) then Exit(J > Length(N));
    if B[I] = #$FFFD then
    begin
      Run := 0; K := I;
      while (K <= Length(B)) and (B[K] = #$FFFD) do begin Inc(Run); Inc(K); end;
      for Run := 1 to Run do
        if (J + Run - 1 <= Length(N)) and Rec(K, J + Run) then Exit(True);
      Exit(False);
    end;
    if (J > Length(N)) or (B[I] <> N[J]) then Exit(False);
    Result := Rec(I + 1, J + 1);
  end;

begin
  B := UTF8Decode(ABroken); N := UTF8Decode(AName);
  Result := Rec(1, 1);
end;

{ ---------------- provjere ---------------- }

procedure CheckRows(var AR: TaVReport; const ARows: array of TVRow; ACount: Integer; const ASkips: array of TSkip; ASkipCount: Integer;
  const ASeason: string; AKnown: TStringList);
var
  Half, SelfPlay, Absurd, WrongFtr, WrongSeason, OutsideWindow, Malformed: TStringList;
  UnknownDiv: TStringList;
  Counts: TStringList;
  I, J, Y1, Y2, UnplayedN: Integer;
  R: TVRow;
  D, WStart, WEnd: string;
  HasWindow: Boolean;
  Tmp: TStringList;
  Idx, Cnt, Best, BestI: Integer;
begin
  Half := TStringList.Create; SelfPlay := TStringList.Create; Absurd := TStringList.Create; WrongFtr := TStringList.Create;
  WrongSeason := TStringList.Create; OutsideWindow := TStringList.Create; Malformed := TStringList.Create;
  UnknownDiv := TStringList.Create; Counts := TStringList.Create;
  try
    HasWindow := False;
    if (Length(ASeason) = 9) and (ASeason[5] = '-') then
    begin
      Y1 := StrToIntDef(Copy(ASeason, 1, 4), -1); Y2 := StrToIntDef(Copy(ASeason, 6, 4), -1);
      if (Y1 >= 0) and (Y2 >= 0) then
      begin
        HasWindow := True;
        WStart := Format('%.4d-06-01', [Y1]); WEnd := Format('%.4d-08-31', [Y2]);
      end;
    end;
    for I := 0 to ACount - 1 do
    begin
      R := ARows[I];
      if R.Home = R.Away then SelfPlay.Add(Fixture(R));
      if (R.Fthg < 0) or (R.Ftag < 0) or (Max(R.Fthg, R.Ftag) > MaxPlausibleGoals) then
        Absurd.Add(Fixture(R) + ' ' + IntToStr(R.Fthg) + '-' + IntToStr(R.Ftag));
      if R.HasHt then
      begin
        if (R.Hthg < 0) or (R.Htag < 0) then
          Absurd.Add(Fixture(R) + ' HT ' + IntToStr(R.Hthg) + '-' + IntToStr(R.Htag))
        else if (R.Hthg > R.Fthg) or (R.Htag > R.Ftag) then
          Half.Add(Fixture(R) + ' HT ' + IntToStr(R.Hthg) + '-' + IntToStr(R.Htag) + ' > FT ' + IntToStr(R.Fthg) + '-' + IntToStr(R.Ftag));
      end;
      if (R.FileFtr <> '') and (R.FileFtr <> R.Ftr) then
        WrongFtr.Add(Fixture(R) + ' ' + IntToStr(R.Fthg) + '-' + IntToStr(R.Ftag) + ' oznacen kao ' + R.FileFtr);
      if R.Season <> ASeason then WrongSeason.Add(Fixture(R) + ' -> ' + R.Season);
      if AKnown.IndexOf(R.Div_) < 0 then UnknownDiv.Add(R.Div_);
      if HasWindow then
      begin
        D := R.Date;
        if (CompareStr(D, WStart) < 0) or (CompareStr(D, WEnd) > 0) then OutsideWindow.Add(Fixture(R));
      end;
    end;
    UnplayedN := 0;
    for I := 0 to ASkipCount - 1 do
      if ASkips[I].Reason = 'no result yet' then Inc(UnplayedN)
      else Malformed.Add('redak ' + IntToStr(ASkips[I].Line) + ': ' + ASkips[I].Reason);

    if Half.Count > 0 then AddIssue(AR, vlError, 'poluvrijeme>kraj', IntToStr(Half.Count) + ' utakmica ima rezultat poluvremena veci od konacnog', Half);
    if SelfPlay.Count > 0 then AddIssue(AR, vlError, 'isti-tim', IntToStr(SelfPlay.Count) + ' utakmica ima istog domacina i gosta', SelfPlay);
    if Absurd.Count > 0 then AddIssue(AR, vlError, 'nemoguc-rezultat',
      IntToStr(Absurd.Count) + ' utakmica ima negativan ili nevjerojatan broj golova (>' + IntToStr(MaxPlausibleGoals) + ')', Absurd);
    if WrongFtr.Count > 0 then AddIssue(AR, vlWarning, 'ftr-neslaganje',
      IntToStr(WrongFtr.Count) + ' utakmica ima stupac FTR koji ne odgovara golovima (ishod se racuna iz golova, stupac se ignorira)', WrongFtr);
    if WrongSeason.Count > 0 then AddIssue(AR, vlWarning, 'kriva-sezona', IntToStr(WrongSeason.Count) + ' redaka nosi drugu sezonu i bit ce preskoceno', WrongSeason);
    if UnknownDiv.Count > 0 then
    begin
      { Counter.most_common: po broju silazno, a jednaki po redu prvog pojavljivanja }
      Counts.CaseSensitive := True;
      Tmp := TStringList.Create;
      try
        for I := 0 to UnknownDiv.Count - 1 do
        begin
          Idx := Counts.IndexOf(UnknownDiv[I]);
          if Idx < 0 then Counts.AddObject(UnknownDiv[I], TObject(PtrInt(1)))
          else Counts.Objects[Idx] := TObject(PtrInt(PtrInt(Counts.Objects[Idx]) + 1));
        end;
        for J := 0 to Counts.Count - 1 do
        begin
          Best := -1; BestI := -1;
          for I := 0 to Counts.Count - 1 do
          begin
            Cnt := PtrInt(Counts.Objects[I]);
            if (Cnt > Best) then begin Best := Cnt; BestI := I; end;
          end;
          Tmp.Add(Counts[BestI] + ' (' + IntToStr(Best) + ' utakmica)');
          Counts.Objects[BestI] := TObject(PtrInt(-2));
          if Tmp.Count >= MaxExamples then Break;
        end;
        AddIssue(AR, vlWarning, 'nepoznata-liga',
          IntToStr(Counts.Count) + ' oznaka lige nije definirano u tablici divisions (uvest ce se, ali bez naziva i drzave)', Tmp);
      finally
        Tmp.Free;
      end;
    end;
    if OutsideWindow.Count > 0 then AddIssue(AR, vlWarning, 'datum-izvan-sezone',
      IntToStr(OutsideWindow.Count) + ' utakmica ima datum izvan ocekivanog raspona sezone', OutsideWindow);
    if Malformed.Count > 0 then AddIssue(AR, vlWarning, 'neispravan-redak', IntToStr(Malformed.Count) + ' redaka nije bilo moguce procitati', Malformed);
    if UnplayedN > 0 then AddIssue(AR, vlInfo, 'nije-odigrano', IntToStr(UnplayedN) + ' utakmica jos nema rezultat i nece biti upisano', nil);
  finally
    Half.Free; SelfPlay.Free; Absurd.Free; WrongFtr.Free; WrongSeason.Free; OutsideWindow.Free; Malformed.Free;
    UnknownDiv.Free; Counts.Free;
  end;
end;

procedure CheckFixtureSet(var AR: TaVReport; const ARows: array of TVRow; ACount: Integer);
var
  Keys: TStringList;          { kljuc -> indeks prvog retka }
  Idents, Contra, Twice, PerDay: TStringList;
  Groups: array of array of Integer;
  I, J, K, Idx, Same, G: Integer;
  R, F: TVRow;
  Res: TStringList;
  Txt, Rs: string;
  Last: array of Integer;
begin
  Keys := TStringList.Create; Keys.CaseSensitive := True;
  Idents := TStringList.Create; Contra := TStringList.Create; Twice := TStringList.Create; PerDay := TStringList.Create;
  PerDay.CaseSensitive := True;
  try
    SetLength(Groups, 0);
    for I := 0 to ACount - 1 do
    begin
      Idx := Keys.IndexOf(KeyOf(ARows[I]));
      if Idx < 0 then
      begin
        Idx := Keys.AddObject(KeyOf(ARows[I]), TObject(PtrInt(Length(Groups))));
        SetLength(Groups, Length(Groups) + 1);
      end;
      G := PtrInt(Keys.Objects[Idx]);
      SetLength(Groups[G], Length(Groups[G]) + 1);
      Groups[G][High(Groups[G])] := I;
    end;
    for G := 0 to High(Groups) do
    begin
      if Length(Groups[G]) < 2 then Continue;
      Res := TStringList.Create;
      try
        Res.CaseSensitive := True; Res.Sorted := True; Res.Duplicates := dupIgnore;
        for K := 0 to High(Groups[G]) do
        begin
          R := ARows[Groups[G][K]];
          if R.HasHt then Rs := Format('%.6d', [R.Fthg + 100000]) + Format('%.6d', [R.Ftag + 100000]) + '1' + Format('%.6d', [R.Hthg + 100000]) + Format('%.6d', [R.Htag + 100000])
          else Rs := Format('%.6d', [R.Fthg + 100000]) + Format('%.6d', [R.Ftag + 100000]) + '0';
          Res.Add(Rs);
        end;
        R := ARows[Groups[G][0]];
        Txt := R.Date + ' ' + R.Div_ + ' ' + R.Home + '-' + R.Away;
        if Res.Count = 1 then Idents.Add(Txt)
        else
        begin
          Txt := Txt + '  ';
          for K := 0 to Res.Count - 1 do
          begin
            if K > 0 then Txt := Txt + ' / ';
            Txt := Txt + IntToStr(StrToInt(Copy(Res[K], 1, 6)) - 100000) + '-' + IntToStr(StrToInt(Copy(Res[K], 7, 6)) - 100000);
          end;
          Contra.Add(Txt);
        end;
      finally
        Res.Free;
      end;
    end;
    if Idents.Count > 0 then AddIssue(AR, vlWarning, 'duplikat', IntToStr(Idents.Count) + ' utakmica se ponavlja s istim rezultatom (sazima se)', Idents);
    if Contra.Count > 0 then AddIssue(AR, vlWarning, 'duplikat-razlicit',
      IntToStr(Contra.Count) + ' utakmica se ponavlja s RAZLICITIM rezultatom (zadnji redak pobjeduje)', Contra);
    { klub ne igra dvaput istog dana (nad sazetim skupom) }
    for G := 0 to High(Groups) do
    begin
      R := ARows[Groups[G][0]];
      for K := 0 to 1 do
      begin
        if K = 0 then Txt := R.Date + #1 + R.Div_ + #1 + R.Home else Txt := R.Date + #1 + R.Div_ + #1 + R.Away;
        Idx := PerDay.IndexOf(Txt);
        if Idx < 0 then PerDay.AddObject(Txt, TObject(PtrInt(1)))
        else PerDay.Objects[Idx] := TObject(PtrInt(PtrInt(PerDay.Objects[Idx]) + 1));
      end;
    end;
    for I := 0 to PerDay.Count - 1 do
      if PtrInt(PerDay.Objects[I]) > 1 then
      begin
        Txt := PerDay[I];
        { datum #1 liga #1 tim -> "tim datum" }
        J := Pos(#1, Txt);
        Rs := Copy(Txt, 1, J - 1);
        Txt := Copy(Txt, J + 1, MaxInt);
        J := Pos(#1, Txt);
        Twice.Add(Copy(Txt, J + 1, MaxInt) + ' ' + Rs);
      end;
    if Twice.Count > 0 then AddIssue(AR, vlWarning, 'dvije-utakmice-isti-dan', IntToStr(Twice.Count) + ' slucajeva kad tim igra dvaput istog dana', Twice);
  finally
    Keys.Free; Idents.Free; Contra.Free; Twice.Free; PerDay.Free;
  end;
end;

procedure CheckAgainstDatabase(var AR: TaVReport; ADb: TAppDb; var ARows: array of TVRow; ACount: Integer; const ASeason: string; AMinRatio: Double);
var
  Damaged, Repairs, Unresolved, Known, Scope, Added, Removed, Updated, Ex, NewC, Divs: TStringList;
  Incoming, Existing: TKv;
  Q: TZQuery;
  I, J, K, Matches: Integer;
  Div_, Broken, Good, Names, Key, Val, T: string;
  DivList: string;
  Hits: array of string;
begin
  Damaged := TStringList.Create; Repairs := TStringList.Create; Unresolved := TStringList.Create; Known := TStringList.Create;
  Incoming := TKv.Create; Existing := TKv.Create; Added := TStringList.Create; Removed := TStringList.Create;
  Updated := TStringList.Create; Ex := TStringList.Create; NewC := TStringList.Create; Divs := TStringList.Create;
  try
    Damaged.CaseSensitive := True; Damaged.Sorted := True; Damaged.Duplicates := dupIgnore;
    Known.CaseSensitive := True;
    Known.Sorted := True; Known.Duplicates := dupIgnore;
    NewC.CaseSensitive := True; NewC.Sorted := True; NewC.Duplicates := dupIgnore;
    Divs.CaseSensitive := True; Divs.Sorted := True; Divs.Duplicates := dupIgnore;
    for I := 0 to ACount - 1 do
    begin
      if Pos(Replacement, ARows[I].Home) > 0 then Damaged.Add(ARows[I].Div_ + #1 + ARows[I].Home);
      if Pos(Replacement, ARows[I].Away) > 0 then Damaged.Add(ARows[I].Div_ + #1 + ARows[I].Away);
    end;
    { popravak ostecenih imena: jedino podudaranje u istoj ligi (sortirano po (liga, ime) kao u Pythonu) }
    Damaged.CustomSort(@CompareStrList_);
    for I := 0 to Damaged.Count - 1 do
    begin
      J := Pos(#1, Damaged[I]);
      Div_ := Copy(Damaged[I], 1, J - 1); Broken := Copy(Damaged[I], J + 1, MaxInt);
      Known.Clear;
      Q := ADb.NewQuery('SELECT hometeam FROM matches WHERE division = :d AND season <> :s UNION SELECT awayteam FROM matches WHERE division = :d AND season <> :s');
      try
        Q.ParamByName('d').AsString := Div_; Q.ParamByName('s').AsString := ASeason;
        Q.Open;
        while not Q.Eof do
        begin
          if Pos(Replacement, Q.Fields[0].AsString) = 0 then Known.Add(Q.Fields[0].AsString);
          Q.Next;
        end;
      finally
        Q.Free;
      end;
      Matches := 0; Names := ''; Good := '';
      for K := 0 to Known.Count - 1 do
        if MojibakeMatch(Broken, Known[K]) then
        begin
          Inc(Matches);
          if Names <> '' then Names := Names + ', ';
          Names := Names + Known[K];
          Good := Known[K];
        end;
      if Matches = 1 then Repairs.Add(Div_ + #1 + Broken + #1 + Good)
      else
      begin
        T := Div_ + ': ' + Broken;
        if Matches > 0 then T := T + ' (visestruko podudaranje: ' + Names + ')';
        Unresolved.Add(T);
      end;
    end;
    for I := 0 to ACount - 1 do
      for K := 0 to Repairs.Count - 1 do
      begin
        T := Repairs[K];
        J := Pos(#1, T); Div_ := Copy(T, 1, J - 1); T := Copy(T, J + 1, MaxInt);
        J := Pos(#1, T); Broken := Copy(T, 1, J - 1); Good := Copy(T, J + 1, MaxInt);
        if ARows[I].Div_ = Div_ then
        begin
          if ARows[I].Home = Broken then ARows[I].Home := Good;
          if ARows[I].Away = Broken then ARows[I].Away := Good;
        end;
      end;
    if Repairs.Count > 0 then
    begin
      for K := 0 to Repairs.Count - 1 do
      begin
        T := Repairs[K];
        J := Pos(#1, T); T := Copy(T, J + 1, MaxInt);
        J := Pos(#1, T);
        Ex.Add(Copy(T, 1, J - 1) + '  ->  ' + Copy(T, J + 1, MaxInt));
      end;
      AddIssue(AR, vlInfo, 'ostecena-imena', IntToStr(Repairs.Count) + ' imena klubova ostecenih kodiranjem bit ce ispravljeno', Ex);
      Ex.Clear;
    end;
    if Unresolved.Count > 0 then
      AddIssue(AR, vlError, 'ostecena-imena-nerjesiva',
        IntToStr(Unresolved.Count) + ' imena klubova ostecenih kodiranjem nije moguce povezati s poznatim klubom - upisali bi se kao novi klub bez povijesti', Unresolved);

    { postojece utakmice sezone u ligama koje datoteka nosi }
    for I := 0 to ACount - 1 do
      if ARows[I].Season = ASeason then Divs.Add(ARows[I].Div_);
    DivList := '';
    for I := 0 to Divs.Count - 1 do
    begin
      if I > 0 then DivList := DivList + ',';
      DivList := DivList + Q_(Divs[I]);
    end;
    if Divs.Count = 0 then
      Q := ADb.NewQuery('SELECT division, matchdate, hometeam, awayteam, fthg, ftag, hthg, htag FROM matches WHERE season = ' + Q_(ASeason))
    else
      Q := ADb.NewQuery('SELECT division, matchdate, hometeam, awayteam, fthg, ftag, hthg, htag FROM matches WHERE season = ' + Q_(ASeason) + ' AND division IN (' + DivList + ')');
    try
      Q.Open;
      while not Q.Eof do
      begin
        Key := Q.Fields[0].AsString + #1 + Q.Fields[1].AsString + #1 + Q.Fields[2].AsString + #1 + Q.Fields[3].AsString;
        Val := Q.Fields[4].AsString + #2 + Q.Fields[5].AsString + #2 + IfThen(Q.Fields[6].IsNull, 'N', Q.Fields[6].AsString) + #2 + IfThen(Q.Fields[7].IsNull, 'N', Q.Fields[7].AsString);
        Existing.Put(Key, Val, True);
        Q.Next;
      end;
    finally
      Q.Free;
    end;
    AR.InDatabase := Existing.Keys.Count;
    for I := 0 to ACount - 1 do
    begin
      if ARows[I].Season <> ASeason then Continue;
      Key := ARows[I].Div_ + #1 + ARows[I].Date + #1 + ARows[I].Home + #1 + ARows[I].Away;
      Val := IntToStr(ARows[I].Fthg) + #2 + IntToStr(ARows[I].Ftag) + #2 +
        IfThen(ARows[I].HasHt, IntToStr(ARows[I].Hthg), 'N') + #2 + IfThen(ARows[I].HasHt, IntToStr(ARows[I].Htag), 'N');
      Incoming.Put(Key, Val, False);
    end;
    for I := 0 to Incoming.Keys.Count - 1 do
    begin
      Key := Incoming.Keys[I];
      J := Existing.Find(Key);
      if J < 0 then Added.Add(Key)
      else if Existing.Vals[J] <> Incoming.Vals[I] then Updated.Add(Key);
    end;
    for I := 0 to Existing.Keys.Count - 1 do
      if Incoming.Find(Existing.Keys[I]) < 0 then Removed.Add(Existing.Keys[I]);
    AR.Added := Added.Count; AR.Removed := Removed.Count; AR.Updated := Updated.Count;

    if (Existing.Keys.Count > 0) and (Incoming.Keys.Count < Existing.Keys.Count * AMinRatio) then
      AddIssue(AR, vlError, 'skracena-datoteka',
        'datoteka nosi ' + IntToStr(Incoming.Keys.Count) + ' utakmica, a baza ih ima ' + IntToStr(Existing.Keys.Count) + ' za ovu sezonu - izgleda kao nepotpun export', nil);
    if Removed.Count > 0 then
    begin
      for I := 0 to Removed.Count - 1 do
      begin
        T := Removed[I];
        J := Pos(#1, T); Div_ := Copy(T, 1, J - 1); T := Copy(T, J + 1, MaxInt);
        J := Pos(#1, T); Names := Copy(T, 1, J - 1); T := Copy(T, J + 1, MaxInt);
        J := Pos(#1, T);
        Ex.Add(Names + ' ' + Div_ + ' ' + Copy(T, 1, J - 1) + '-' + Copy(T, J + 1, MaxInt));
      end;
      AddIssue(AR, vlWarning, 'nestale-utakmice', IntToStr(Removed.Count) + ' utakmica postoji u bazi, a nema ih u datoteci - bit ce obrisane', Ex);
      Ex.Clear;
    end;
    if Updated.Count > 0 then
    begin
      for I := 0 to Updated.Count - 1 do
      begin
        T := Updated[I];
        J := Pos(#1, T); Div_ := Copy(T, 1, J - 1); T := Copy(T, J + 1, MaxInt);
        J := Pos(#1, T); Names := Copy(T, 1, J - 1); T := Copy(T, J + 1, MaxInt);
        J := Pos(#1, T);
        Good := Copy(T, 1, J - 1) + '-' + Copy(T, J + 1, MaxInt);
        Val := Existing.Vals[Existing.Find(Updated[I])];
        Broken := Incoming.Vals[Incoming.Find(Updated[I])];
        Ex.Add(Names + ' ' + Div_ + ' ' + Good + ': ' + Copy(Val, 1, Pos(#2, Val) - 1) + '-' + Copy(Copy(Val, Pos(#2, Val) + 1, MaxInt), 1, Pos(#2, Copy(Val, Pos(#2, Val) + 1, MaxInt)) - 1) +
          ' -> ' + Copy(Broken, 1, Pos(#2, Broken) - 1) + '-' + Copy(Copy(Broken, Pos(#2, Broken) + 1, MaxInt), 1, Pos(#2, Copy(Broken, Pos(#2, Broken) + 1, MaxInt)) - 1));
      end;
      AddIssue(AR, vlWarning, 'izmijenjen-rezultat', IntToStr(Updated.Count) + ' utakmica mijenja rezultat', Ex);
      Ex.Clear;
    end;
    { klubovi koji prije nisu igrali u svojoj ligi }
    Divs.Clear;
    for I := 0 to ACount - 1 do Divs.Add(ARows[I].Div_);
    Scope := TStringList.Create;
    try
      Scope.CaseSensitive := True; Scope.Sorted := True; Scope.Duplicates := dupIgnore;
      for I := 0 to Divs.Count - 1 do
      begin
        Q := ADb.NewQuery('SELECT hometeam FROM matches WHERE division = :d AND season <> :s UNION SELECT awayteam FROM matches WHERE division = :d AND season <> :s');
        try
          Q.ParamByName('d').AsString := Divs[I]; Q.ParamByName('s').AsString := ASeason;
          Q.Open;
          while not Q.Eof do
          begin
            Scope.Add(Divs[I] + #1 + Q.Fields[0].AsString);
            Q.Next;
          end;
        finally
          Q.Free;
        end;
      end;
      for I := 0 to ACount - 1 do
      begin
        for K := 0 to 1 do
        begin
          if K = 0 then Names := ARows[I].Home else Names := ARows[I].Away;
          if not (Scope.Find(ARows[I].Div_ + #1 + Names, J)) then NewC.Add(ARows[I].Div_ + ': ' + Names);
        end;
      end;
    finally
      Scope.Free;
    end;
    if NewC.Count > 0 then
    begin
      NewC.CustomSort(@CompareStrList_);
      AddIssue(AR, vlInfo, 'novi-klubovi',
        IntToStr(NewC.Count) + ' klubova nije prije igralo u svojoj ligi (promaknuce - ili preimenovan klub, sto bi krenulo bez ocjene)', NewC);
    end;
  finally
    Damaged.Free; Repairs.Free; Unresolved.Free; Known.Free; Incoming.Free; Existing.Free; Added.Free; Removed.Free;
    Updated.Free; Ex.Free; NewC.Free; Divs.Free;
  end;
end;


{ ---------------- povijesne norme (_history_norms / _check_against_history) ---------------- }

type
  TNorm = record
    Div_: string;
    FullSeason, GoalsMean, GoalsSd, HomeMean, HomeSd: Double;
  end;

procedure SortD(var A: array of Double);
var
  I, J: Integer;
  T: Double;
begin
  for I := 1 to High(A) do
  begin
    T := A[I]; J := I - 1;
    while (J >= 0) and (A[J] > T) do begin A[J + 1] := A[J]; Dec(J); end;
    A[J + 1] := T;
  end;
end;

function Median(const A: array of Double): Double;
var
  S: array of Double;
  I, N: Integer;
begin
  N := Length(A);
  SetLength(S, N);
  for I := 0 to N - 1 do S[I] := A[I];
  SortD(S);
  if Odd(N) then Result := S[N div 2] else Result := (S[N div 2 - 1] + S[N div 2]) / 2.0;
end;

function RobustSpread(const A: array of Double; AFloor: Double): Double;
var
  Dev: array of Double;
  M: Double;
  I: Integer;
begin
  if Length(A) < 3 then Exit(AFloor);
  M := Median(A);
  SetLength(Dev, Length(A));
  for I := 0 to High(A) do Dev[I] := Abs(A[I] - M);
  Result := Max(Median(Dev) * MadToSigma, AFloor);
end;

procedure CheckAgainstHistory(var AR: TaVReport; ADb: TAppDb; const ARows: array of TVRow; ACount: Integer; const ASeason: string);
var
  Q: TZQuery;
  Norms: array of TNorm;
  I, J, K, N, Idx: Integer;
  Cur: string;
  Ns, Gs, Hs: array of Double;
  Seasons: array of string;
  CompN, CompG, CompH: array of Double;
  CompS: array of string;
  Med, Goals, Home, Sig: Double;
  Divs: TStringList;
  Rows, Cnt: Integer;
  Name_, Ctry, Label_: string;
  Norm: TNorm;
  HasNorm: Boolean;
  Shown, Hint, Nm: string;
  Mean, Sd, Value: Double;
  Pass: Integer;

  procedure Flush;
  var
    A: Integer;
    Recent: array of Integer;
    Best, BestI, Used, PP, KK: Integer;
    Taken: array of Boolean;
    RN: array of Double;
  begin
    if Cur = '' then Exit;
    N := Length(Ns);
    Med := Median(Ns);
    SetLength(CompN, 0); SetLength(CompG, 0); SetLength(CompH, 0); SetLength(CompS, 0);
    for A := 0 to N - 1 do
      if Ns[A] >= Med * 0.5 then
      begin
        SetLength(CompN, Length(CompN) + 1); SetLength(CompG, Length(CompG) + 1); SetLength(CompH, Length(CompH) + 1); SetLength(CompS, Length(CompS) + 1);
        CompN[High(CompN)] := Ns[A]; CompG[High(CompG)] := Gs[A]; CompH[High(CompH)] := Hs[A]; CompS[High(CompS)] := Seasons[A];
      end;
    if Length(CompN) >= MinSeasonsForNorm then
    begin
      { posljednjih 5 sezona po oznaci sezone (sirina prozora za duljinu sezone) }
      SetLength(Taken, Length(CompN));
      for A := 0 to High(Taken) do Taken[A] := False;
      Used := Min(RecentSeasonsForLength, Length(CompN));
      Norm.FullSeason := 0;
      for PP := 1 to Used do
      begin
        BestI := -1;
        for KK := 0 to High(CompN) do
          if (not Taken[KK]) and ((BestI < 0) or (CompareStr(CompS[KK], CompS[BestI]) > 0)) then BestI := KK;
        Taken[BestI] := True;
        if CompN[BestI] > Norm.FullSeason then Norm.FullSeason := CompN[BestI];
      end;
      Norm.Div_ := Cur;
      Norm.GoalsMean := Median(CompG); Norm.GoalsSd := RobustSpread(CompG, 0.08);
      Norm.HomeMean := Median(CompH); Norm.HomeSd := RobustSpread(CompH, 0.015);
      SetLength(Norms, Length(Norms) + 1);
      Norms[High(Norms)] := Norm;
    end;
    SetLength(Ns, 0); SetLength(Gs, 0); SetLength(Hs, 0); SetLength(Seasons, 0);
  end;

begin
  { po (liga, sezona) u svim ostalim sezonama }
  Q := ADb.NewQuery('SELECT division, season, COUNT(*), AVG(fthg + ftag), AVG(CASE WHEN ftr = ''H'' THEN 1.0 ELSE 0.0 END) FROM matches WHERE season <> :s GROUP BY division, season ORDER BY division, season');
  Cur := '';
  try
    Q.ParamByName('s').AsString := ASeason;
    Q.Open;
    while not Q.Eof do
    begin
      if Q.Fields[0].AsString <> Cur then
      begin
        Flush;
        Cur := Q.Fields[0].AsString;
      end;
      SetLength(Ns, Length(Ns) + 1); SetLength(Gs, Length(Gs) + 1); SetLength(Hs, Length(Hs) + 1); SetLength(Seasons, Length(Seasons) + 1);
      Ns[High(Ns)] := Q.Fields[2].AsInteger; Gs[High(Gs)] := Q.Fields[3].AsFloat; Hs[High(Hs)] := Q.Fields[4].AsFloat;
      Seasons[High(Seasons)] := Q.Fields[1].AsString;
      Q.Next;
    end;
    Flush;
  finally
    Q.Free;
  end;
  if Length(Norms) = 0 then Exit;
  Divs := TStringList.Create;
  try
    Divs.CaseSensitive := True; Divs.Sorted := True; Divs.Duplicates := dupIgnore;
    for I := 0 to ACount - 1 do Divs.Add(ARows[I].Div_);
    Divs.CustomSort(@CompareStrList_);
    for I := 0 to Divs.Count - 1 do
    begin
      HasNorm := False;
      for J := 0 to High(Norms) do if Norms[J].Div_ = Divs[I] then begin Norm := Norms[J]; HasNorm := True; end;
      if not HasNorm then Continue;
      if DivisionInfo(Divs[I], Name_, Ctry) then Label_ := Name_ else Label_ := Divs[I];
      Rows := 0; Goals := 0; Home := 0;
      for K := 0 to ACount - 1 do
        if ARows[K].Div_ = Divs[I] then
        begin
          Inc(Rows);
          Goals := Goals + ARows[K].Fthg + ARows[K].Ftag;
          if ARows[K].Fthg > ARows[K].Ftag then Home := Home + 1;
        end;
      if Rows > Norm.FullSeason then
        AddIssue(AR, vlError, 'previse-utakmica',
          Divs[I] + ' (' + Label_ + ') nosi ' + IntToStr(Rows) + ' utakmica, a puna sezona ih ima ' + F0(Norm.FullSeason) +
          ' - visak znaci duplikate ili pomijesane sezone', nil);
      if Rows < MinRowsForRate then Continue;
      Goals := Goals / Rows; Home := Home / Rows;
      for Pass := 0 to 1 do
      begin
        if Pass = 0 then
        begin
          Nm := 'golovi'; Value := Goals; Mean := Norm.GoalsMean; Sd := Norm.GoalsSd;
          Shown := F2(Goals) + ' po utakmici (normalno ' + F2(Norm.GoalsMean) + ')';
          Hint := 'poluvremenski golovi u stupcima za kraj utakmice';
        end
        else
        begin
          Nm := 'domaci'; Value := Home; Mean := Norm.HomeMean; Sd := Norm.HomeSd;
          Shown := Pct1(Home) + ' domacih pobjeda (normalno ' + Pct1(Norm.HomeMean) + ')';
          Hint := 'zamijenjeni stupci domacina i gosta';
        end;
        if Sd > 0 then Sig := Abs(Value - Mean) / Sd else Sig := 0;
        if Sig >= RateErrorSigmas then
          AddIssue(AR, vlError, 'nenormalno-' + Nm,
            Divs[I] + ' (' + Label_ + '): ' + Shown + ' - odstupanje od ' + F1(Sig) + ' standardnih devijacija, izgleda kao ' + Hint, nil)
        else if Sig >= RateWarningSigmas then
          AddIssue(AR, vlWarning, 'neobicno-' + Nm,
            Divs[I] + ' (' + Label_ + '): ' + Shown + ' - odstupanje od ' + F1(Sig) + ' standardnih devijacija, vrijedi pogledati', nil);
      end;
    end;
  finally
    Divs.Free;
  end;
end;

{ ---------------- ulazna tocka ---------------- }

function ValidateSeasonFile(ADb: TAppDb; const AFile, ASeason: string; AMinRatio: Double): TaVReport;
var
  Rows: TaRows;
  Head: array of string;
  Sc: array of TVRow;
  Skips: array of TSkip;
  NS, NK, I, Line, CD, CDt, CH, CA, CHt, CAt, CFt, CHtr, CSe, CDiv: Integer;
  Dt, Dv, Hm, Aw, Se, Fallback, Season: string;
  Fthg, Ftag, Hthg, Htag: Integer;
  Known: TStringList;
  Q: TZQuery;
  Bom: string;
  R: TVRow;

  function C(ARow, AIdx: Integer): string;
  begin
    if (AIdx >= 0) and (AIdx < Length(Rows[ARow])) then Result := Trim(Rows[ARow][AIdx]) else Result := '';
  end;

begin
  FillChar(Result, SizeOf(Result), 0);
  Result.FileName := ExtractFileName(AFile);
  if not FileExists(AFile) then raise EExpr.Create('Nema datoteke: ' + AFile);
  Season := ASeason;
  if Season = '' then Season := SeasonOfFileName(AFile);
  if Season = '' then raise EExpr.Create(Result.FileName + ': sezona se ne moze iscitati iz imena, zadaj je kao drugi argument');
  Result.Season := Season;
  Fallback := SeasonOfFileName(AFile);
  if not ReadAnyFile(AFile, ',', Rows) then raise EExpr.Create('Datoteka se ne moze procitati: ' + AFile);
  if Length(Rows) = 0 then begin AddIssue(Result, vlError, 'prazna-datoteka', 'datoteka ne sadrzi nijednu odigranu utakmicu', nil); Exit; end;
  Head := Rows[0];
  Bom := #$EF#$BB#$BF;
  if (Length(Head) > 0) and (Copy(Head[0], 1, 3) = Bom) then Head[0] := Copy(Head[0], 4, MaxInt);
  CDiv := ColOf(Head, ['division_id', 'division', 'div']);
  CDt := ColOf(Head, ['matchdate', 'date']);
  CH := ColOf(Head, ['hometeam', 'home_team']);
  CA := ColOf(Head, ['awayteam', 'away_team']);
  CD := ColOf(Head, ['fthg']);
  CAt := ColOf(Head, ['ftag']);
  CHt := ColOf(Head, ['hthg']);
  CFt := ColOf(Head, ['htag']);
  CHtr := ColOf(Head, ['ftr']);
  CSe := ColOf(Head, ['season']);
  if (CDiv < 0) or (CDt < 0) or (CH < 0) or (CA < 0) or (CD < 0) or (CAt < 0) then
    raise EExpr.Create(Result.FileName + ': nedostaju obavezni stupci (division, matchdate, hometeam, awayteam, fthg, ftag)');
  NS := 0; NK := 0;
  for I := 1 to High(Rows) do
  begin
    Line := I + 1;
    Dt := NormDate(C(I, CDt));
    if Dt = '' then begin SetLength(Skips, NK + 1); Skips[NK].Line := Line; Skips[NK].Reason := 'unreadable date'; Inc(NK); Continue; end;
    Dv := UpperCase(C(I, CDiv));
    if Dv = '' then begin SetLength(Skips, NK + 1); Skips[NK].Line := Line; Skips[NK].Reason := 'missing division'; Inc(NK); Continue; end;
    Hm := C(I, CH); Aw := C(I, CA);
    if (Hm = '') or (Aw = '') then begin SetLength(Skips, NK + 1); Skips[NK].Line := Line; Skips[NK].Reason := 'missing team'; Inc(NK); Continue; end;
    if not (StrictInt(C(I, CD), Fthg) and StrictInt(C(I, CAt), Ftag)) then
    begin SetLength(Skips, NK + 1); Skips[NK].Line := Line; Skips[NK].Reason := 'no result yet'; Inc(NK); Continue; end;
    R.HasHt := (CHt >= 0) and (CFt >= 0) and StrictInt(C(I, CHt), Hthg) and StrictInt(C(I, CFt), Htag);
    if not R.HasHt then begin Hthg := 0; Htag := 0; end;
    if CSe >= 0 then Se := C(I, CSe) else Se := '';
    if Se = '' then Se := Fallback;
    if Se = '' then Se := Copy(Dt, 1, 4);
    R.Div_ := Dv; R.Date := Dt; R.Season := Se; R.Home := Hm; R.Away := Aw;
    R.Fthg := Fthg; R.Ftag := Ftag; R.Hthg := Hthg; R.Htag := Htag; R.Ftr := ResultOf(Fthg, Ftag);
    if CHtr >= 0 then R.FileFtr := UpperCase(C(I, CHtr)) else R.FileFtr := '';
    SetLength(Sc, NS + 1);
    Sc[NS] := R; Inc(NS);
  end;
  Result.Played := NS; Result.Unplayed := 0; Result.Malformed := 0;
  for I := 0 to NK - 1 do
    if Skips[I].Reason = 'no result yet' then Inc(Result.Unplayed) else Inc(Result.Malformed);
  if NS = 0 then
  begin
    AddIssue(Result, vlError, 'prazna-datoteka', 'datoteka ne sadrzi nijednu odigranu utakmicu', nil);
    Exit;
  end;
  Known := TStringList.Create;
  try
    Known.CaseSensitive := True;
    Known.Sorted := True; Known.Duplicates := dupIgnore;
    AddKnownDivisionCodes(Known);
    if TableExists(ADb, 'divisions') then
    begin
      Q := ADb.NewQuery('SELECT division FROM divisions');
      try
        Q.Open;
        while not Q.Eof do begin Known.Add(Q.Fields[0].AsString); Q.Next; end;
      finally
        Q.Free;
      end;
    end;
    CheckRows(Result, Sc, NS, Skips, NK, Season, Known);
  finally
    Known.Free;
  end;
  CheckFixtureSet(Result, Sc, NS);
  if TableExists(ADb, 'matches') then
  begin
    CheckAgainstDatabase(Result, ADb, Sc, NS, Season, AMinRatio);
    CheckAgainstHistory(Result, ADb, Sc, NS, Season);
  end;
end;

function Headline(const R: TaVReport): string;
begin
  if R.Errors > 0 then Result := IntToStr(R.Errors) + ' gresaka - uvoz odbijen'
  else if R.Added + R.Updated + R.Removed = 0 then Result := 'bez promjena'
  else Result := '+' + IntToStr(R.Added) + ' novih, ' + IntToStr(R.Updated) + ' izmijenjenih, ' + IntToStr(R.Removed) + ' uklonjenih';
end;

function LevelName(L: TaVLevel): string;
begin
  case L of
    vlError: Result := 'ERROR';
    vlWarning: Result := 'WARNING';
  else
    Result := 'INFO';
  end;
end;

{ nalazi od najtezeg, jednaka razina po redu nastanka (sorted(key=-level)) }
function OrderOf(const R: TaVReport): TIntegerArr;
var
  I, J, N: Integer;
begin
  N := Length(R.Issues);
  SetLength(Result, N);
  J := 0;
  for I := Ord(vlError) downto Ord(vlInfo) do
    for N := 0 to High(R.Issues) do
      if Ord(R.Issues[N].Level) = I then begin Result[J] := N; Inc(J); end;
end;

function ValidateSeasonToTables(ADb: TAppDb; const AFile, ASeason: string): Integer;
var
  R: TaVReport;
  O: TIntegerArr;
  I: Integer;

  procedure Sum(const AName: string; AValue: Double);
  begin
    ADb.Conn.ExecuteDirect('INSERT INTO validacija_sazetak (naziv, vrijednost) VALUES (' + Q_(AName) + ',' + FloatToStr(AValue, DotFs) + ')');
  end;

begin
  R := ValidateSeasonFile(ADb, AFile, ASeason);
  ADb.Conn.ExecuteDirect('DROP TABLE IF EXISTS validacija_sazetak');
  ADb.Conn.ExecuteDirect('DROP TABLE IF EXISTS validacija_nalazi');
  ADb.Conn.ExecuteDirect('CREATE TABLE validacija_sazetak (id INTEGER PRIMARY KEY AUTOINCREMENT, naziv TEXT, vrijednost REAL)');
  ADb.Conn.ExecuteDirect('CREATE TABLE validacija_nalazi (id INTEGER PRIMARY KEY AUTOINCREMENT, razina TEXT, provjera TEXT, opis TEXT, primjeri TEXT)');
  O := OrderOf(R);
  ADb.Conn.StartTransaction;
  try
    Sum('odigrano', R.Played); Sum('nadolazecih', R.Unplayed); Sum('neispravnih', R.Malformed);
    Sum('u_bazi', R.InDatabase); Sum('dodano', R.Added); Sum('izmijenjeno', R.Updated); Sum('uklonjeno', R.Removed);
    Sum('gresaka', R.Errors); Sum('upozorenja', R.Warnings);
    Sum('uvoz_dopusten', Ord(R.Errors = 0));
    for I := 0 to High(O) do
      ADb.Conn.ExecuteDirect('INSERT INTO validacija_nalazi (razina, provjera, opis, primjeri) VALUES (' + Q_(LevelName(R.Issues[O[I]].Level)) + ',' +
        Q_(R.Issues[O[I]].Code) + ',' + Q_(R.Issues[O[I]].Msg) + ',' + Q_(StringReplace(R.Issues[O[I]].Examples, #10, '; ', [rfReplaceAll])) + ')');
    ADb.Conn.Commit;
  except
    ADb.Conn.Rollback;
    raise;
  end;
  Result := R.Errors;
end;

procedure ValidateSeasonWrite(ADb: TAppDb; const AFile, ASeason: string);
var
  R: TaVReport;
  O: TIntegerArr;
  I: Integer;
begin
  R := ValidateSeasonFile(ADb, AFile, ASeason);
  WriteLn('META;', R.Played, ';', R.Unplayed, ';', R.Malformed, ';', R.InDatabase, ';', R.Added, ';', R.Updated, ';', R.Removed, ';', Headline(R));
  O := OrderOf(R);
  for I := 0 to High(O) do
    WriteLn('ISSUE;', LevelName(R.Issues[O[I]].Level), ';', R.Issues[O[I]].Code, ';', R.Issues[O[I]].Msg, ';', StringReplace(R.Issues[O[I]].Examples, #10, '|', [rfReplaceAll]));
end;

function ValidationHookImpl(const AName: string; const A: array of Variant; N: Integer): Variant;
var
  S: string;
begin
  Result := Null;
  if (ActiveDb = nil) or not ActiveDb.Connected then Exit;
  S := '';
  if (N >= 2) and not VarIsNull(A[1]) then S := Trim(VarToStr(A[1]));
  { datoteka koje nema: -1 (nista nije provjereno) }
  if not FileExists(VarToStr(A[0])) then Exit(-1);
  Result := ValidateSeasonToTables(ActiveDb, VarToStr(A[0]), S);
end;

initialization
  ValidationHook := @ValidationHookImpl;

end.
