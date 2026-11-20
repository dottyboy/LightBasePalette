unit ta_analytics;
{ Analize nad zapisanim listicima (smartbet/bets.py): sazetak, kalibracija po sustavima i trzistima, usporedba sustava,
  usporedba strategija (cijeli listic naspram pojedinacnih) i pracenje informativnih sustava (prijelazi, poluvrijeme ili
  kraj, elita, miks, top). Svaka analiza je tablica an_*; isti odabir redaka (informativni listici izvan glavnih
  statistika, pozivi bez duplikata) i iste formule kao u Pythonu. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Variants, LazUTF8, ZDataset, ta_meta, ta_expr, ta_exprdb;

{ izradi/zamijeni sve tablice an_*; vraca ukupan broj upisanih redaka }
function RunAnalytics(ADb: TAppDb): Integer;

implementation

type
  TSl = record
    Id: Integer;
    Ref, Note, Status, Sys: string;
    Stake, Odds, Payout, Claimed: Double;
    HasClaimed: Boolean;
    Paper, Legs, Won, Pending, NoMatch: Integer;
  end;
  TSls = array of TSl;

  TLg = record
    SlipId: Integer;
    Div_, Home, Away, Market, Sel, Status, Ref, Note, Sys: string;
    Odds, Prob: Double;
  end;
  TLgs = array of TLg;

  TStats = record
    Legs: Integer;
    Expected, Hit, Gap, Se, Z: Double;
  end;

const
  Informational: array[0..6] of string = ('veliki', 'prijelaz', 'poluvrijeme', 'miks', 'top listici', 'hedge', 'elita');
  FairTol = 1e-6;

function IsInformational(const ANote: string): Boolean;
var
  T: string;
  I: Integer;
begin
  T := UTF8LowerCase(ANote);
  for I := 0 to High(Informational) do if Pos(Informational[I], T) > 0 then Exit(True);
  Result := False;
end;

function SystemOf(const ANote: string): string;
var
  P: Integer;
begin
  P := Pos(' - ', ANote);
  if P > 0 then Result := Trim(Copy(ANote, 1, P - 1)) else Result := Trim(ANote);
  if Result = '' then Result := 'bez oznake';
end;

function Has(const ANote, AMarker: string): Boolean;
begin
  Result := Pos(AMarker, UTF8LowerCase(ANote)) > 0;
end;

function OrdCmp(List: TStringList; I, J: Integer): Integer;
begin
  Result := CompareStr(List[I], List[J]);
end;

function Q_(const S: string): string;
begin
  Result := '''' + StringReplace(S, '''', '''''', [rfReplaceAll]) + '''';
end;

function F_(X: Double): string;
var
  Fs: TFormatSettings;
begin
  Fs := DefaultFormatSettings;
  Fs.DecimalSeparator := '.';
  Result := FloatToStrF(X, ffGeneral, 17, 0, Fs);
end;

function N_(AHas: Boolean; X: Double): string;
begin
  if AHas then Result := F_(X) else Result := 'NULL';
end;

function Median(A: array of Double): Double;
var
  I, J: Integer;
  T: Double;
begin
  if Length(A) = 0 then Exit(0);
  for I := 1 to High(A) do
  begin
    T := A[I]; J := I - 1;
    while (J >= 0) and (A[J] > T) do begin A[J + 1] := A[J]; Dec(J); end;
    A[J + 1] := T;
  end;
  if Odd(Length(A)) then Result := A[Length(A) div 2] else Result := (A[Length(A) div 2 - 1] + A[Length(A) div 2]) / 2.0;
end;

{ ---------------- citanje ---------------- }

procedure LoadSlips(ADb: TAppDb; var ASlips: TSls);
var
  Q: TZQuery;
  N: Integer;
begin
  SetLength(ASlips, 0);
  Q := ADb.NewQuery('SELECT s.slip_id, s.ref_date, s.stake, s.status, s.note, s.paper, COUNT(l.leg_id), COALESCE(EXP(SUM(LN(l.odds))), 1.0), ' +
    'COALESCE(SUM(l.status = ''WON''), 0), COALESCE(SUM(l.status = ''PENDING''), 0), COALESCE(SUM(l.status = ''NO_MATCH''), 0) ' +
    'FROM slips s LEFT JOIN slip_legs l ON l.slip_id = s.slip_id GROUP BY s.slip_id ORDER BY s.slip_id DESC');
  try
    Q.Open;
    N := 0;
    SetLength(ASlips, 4096);
    while not Q.Eof do
    begin
      if N >= Length(ASlips) then SetLength(ASlips, Length(ASlips) * 2);
      ASlips[N].Id := Q.Fields[0].AsInteger; ASlips[N].Ref := Q.Fields[1].AsString; ASlips[N].Stake := Q.Fields[2].AsFloat;
      ASlips[N].Status := Q.Fields[3].AsString; ASlips[N].Note := Q.Fields[4].AsString; ASlips[N].Paper := Q.Fields[5].AsInteger;
      ASlips[N].Legs := Q.Fields[6].AsInteger; ASlips[N].Odds := Q.Fields[7].AsFloat; ASlips[N].Won := Q.Fields[8].AsInteger;
      ASlips[N].Pending := Q.Fields[9].AsInteger; ASlips[N].NoMatch := Q.Fields[10].AsInteger;
      if ASlips[N].Status = 'WON' then ASlips[N].Payout := ASlips[N].Stake * ASlips[N].Odds else ASlips[N].Payout := 0;
      ASlips[N].Sys := SystemOf(ASlips[N].Note);
      ASlips[N].HasClaimed := False; ASlips[N].Claimed := 1;
      Inc(N);
      Q.Next;
    end;
    SetLength(ASlips, N);
  finally
    Q.Free;
  end;
end;

procedure LoadLegs(ADb: TAppDb; var ALegs: TLgs);
var
  Q: TZQuery;
  N: Integer;
begin
  SetLength(ALegs, 0);
  Q := ADb.NewQuery('SELECT l.slip_id, l.division, l.hometeam, l.awayteam, l.market, l.selection, l.odds, l.model_probability, l.status, s.ref_date, s.note ' +
    'FROM slip_legs l JOIN slips s ON s.slip_id = l.slip_id ORDER BY l.leg_id');
  try
    Q.Open;
    N := 0;
    SetLength(ALegs, 8192);
    while not Q.Eof do
    begin
      if N >= Length(ALegs) then SetLength(ALegs, Length(ALegs) * 2);
      ALegs[N].SlipId := Q.Fields[0].AsInteger; ALegs[N].Div_ := Q.Fields[1].AsString; ALegs[N].Home := Q.Fields[2].AsString;
      ALegs[N].Away := Q.Fields[3].AsString; ALegs[N].Market := Q.Fields[4].AsString; ALegs[N].Sel := Q.Fields[5].AsString;
      ALegs[N].Odds := Q.Fields[6].AsFloat; ALegs[N].Prob := Q.Fields[7].AsFloat; ALegs[N].Status := Q.Fields[8].AsString;
      ALegs[N].Ref := Q.Fields[9].AsString; ALegs[N].Note := Q.Fields[10].AsString; ALegs[N].Sys := SystemOf(ALegs[N].Note);
      Inc(N);
      Q.Next;
    end;
    SetLength(ALegs, N);
  finally
    Q.Free;
  end;
end;

procedure Settled(const AAll: TLgs; ACountable: Boolean; var AOut: TLgs);
var
  I, N: Integer;
begin
  N := 0;
  SetLength(AOut, Length(AAll));
  for I := 0 to High(AAll) do
  begin
    if (AAll[I].Status <> 'WON') and (AAll[I].Status <> 'LOST') then Continue;
    if ACountable and IsInformational(AAll[I].Note) then Continue;
    AOut[N] := AAll[I]; Inc(N);
  end;
  SetLength(AOut, N);
end;

{ drop_duplicates: ostaje prvo pojavljivanje; AKind 0 = sustav+kolo+liga+klubovi+trziste+izbor, 1 = kolo+klubovi+trziste+izbor (bez lige i sustava), 2 = kolo+liga+klubovi+izbor }
procedure Dedup(const AIn: TLgs; AKind: Integer; var AOut: TLgs);
var
  Seen: TStringList;
  I, N: Integer;
  K: string;
begin
  Seen := TStringList.Create;
  try
    Seen.CaseSensitive := True; Seen.Sorted := True;
    N := 0;
    SetLength(AOut, Length(AIn));
    for I := 0 to High(AIn) do
    begin
      case AKind of
        0: K := AIn[I].Sys + #1 + AIn[I].Ref + #1 + AIn[I].Div_ + #1 + AIn[I].Home + #1 + AIn[I].Away + #1 + AIn[I].Market + #1 + AIn[I].Sel;
        1: K := AIn[I].Ref + #1 + AIn[I].Home + #1 + AIn[I].Away + #1 + AIn[I].Market + #1 + AIn[I].Sel;
      else K := AIn[I].Ref + #1 + AIn[I].Div_ + #1 + AIn[I].Home + #1 + AIn[I].Away + #1 + AIn[I].Sel;
      end;
      if Seen.IndexOf(K) >= 0 then Continue;
      Seen.Add(K);
      AOut[N] := AIn[I]; Inc(N);
    end;
    SetLength(AOut, N);
  finally
    Seen.Free;
  end;
end;

function StatsOf(const A: TLgs): TStats;
var
  I, W: Integer;
  SP, SV: Double;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Legs := Length(A);
  if Result.Legs = 0 then Exit;
  SP := 0; SV := 0; W := 0;
  for I := 0 to High(A) do
  begin
    SP := SP + A[I].Prob;
    SV := SV + A[I].Prob * (1.0 - A[I].Prob);
    if A[I].Status = 'WON' then Inc(W);
  end;
  Result.Expected := SP / Result.Legs;
  Result.Hit := W / Result.Legs;
  Result.Gap := Result.Hit - Result.Expected;
  Result.Se := Sqrt(SV) / Result.Legs;
  if Result.Se > 1e-12 then Result.Z := Result.Gap / Result.Se else Result.Z := 0;
end;

function RoiOf(const A: TLgs): Double;
var
  I: Integer;
  S: Double;
begin
  S := 0;
  for I := 0 to High(A) do if A[I].Status = 'WON' then S := S + A[I].Odds;
  if Length(A) = 0 then Exit(0);
  Result := S / Length(A) - 1.0;
end;

function Where(const A: TLgs; const ASys, AMarket: string): TLgs;
var
  I, N: Integer;
begin
  SetLength(Result, Length(A));
  N := 0;
  for I := 0 to High(A) do
  begin
    if (ASys <> '') and (A[I].Sys <> ASys) then Continue;
    if (AMarket <> '') and (A[I].Market <> AMarket) then Continue;
    Result[N] := A[I]; Inc(N);
  end;
  SetLength(Result, N);
end;

{ jedinstvene vrijednosti poredane po bajtovima }
function Uniq(const A: TLgs; AWhat: Integer): TStringList;
var
  I: Integer;
begin
  Result := TStringList.Create;
  Result.CaseSensitive := True; Result.Duplicates := dupIgnore; Result.Sorted := False;
  for I := 0 to High(A) do
    case AWhat of
      0: if Result.IndexOf(A[I].Sys) < 0 then Result.Add(A[I].Sys);
      1: if Result.IndexOf(A[I].Market) < 0 then Result.Add(A[I].Market);
      2: if Result.IndexOf(A[I].Sel) < 0 then Result.Add(A[I].Sel);
    end;
  Result.CustomSort(@OrdCmp);
end;

{ indeksi poredani po broju silazno, stabilno (Pythonov sorted s key=-broj) }
procedure SortDesc(var AOrder, ACnt: array of Integer);
var
  I, J, T, TC: Integer;
begin
  for I := 1 to High(AOrder) do
  begin
    T := AOrder[I]; TC := ACnt[I]; J := I - 1;
    while (J >= 0) and (ACnt[J] < TC) do begin AOrder[J + 1] := AOrder[J]; ACnt[J + 1] := ACnt[J]; Dec(J); end;
    AOrder[J + 1] := T; ACnt[J + 1] := TC;
  end;
end;

{ pozivi jednog sustava: bez duplikata (kolo, klubovi, trziste, izbor) i po fer cijeni (calibration_check) }
procedure FairOf(const ASettled: TLgs; const ASys: string; out AOut: TLgs);
var
  Pool, Unique: TLgs;
  I, J: Integer;
begin
  Pool := Where(ASettled, ASys, '');
  Dedup(Pool, 1, Unique);
  SetLength(AOut, Length(Unique));
  J := 0;
  for I := 0 to High(Unique) do
    if Abs(Unique[I].Odds * Unique[I].Prob - 1) < FairTol then begin AOut[J] := Unique[I]; Inc(J); end;
  SetLength(AOut, J);
end;

{ pozivi ciji je izbor medu zajednickim trzistima }
procedure InShared(const AIn: TLgs; AMarkets: TStringList; out AOut: TLgs);
var
  I, J: Integer;
begin
  SetLength(AOut, Length(AIn));
  J := 0;
  for I := 0 to High(AIn) do if AMarkets.IndexOf(AIn[I].Market) >= 0 then begin AOut[J] := AIn[I]; Inc(J); end;
  SetLength(AOut, J);
end;

{ ---------------- tablice ---------------- }

procedure Recreate(ADb: TAppDb; const AName, ADdl: string);
begin
  ADb.Conn.ExecuteDirect('DROP TABLE IF EXISTS ' + AName);
  ADb.Conn.ExecuteDirect('CREATE TABLE ' + AName + ' (' + ADdl + ')');
end;

procedure PutStats(ADb: TAppDb; const ATable, APrefix: string; const S: TStats);
begin
  ADb.Conn.ExecuteDirect('INSERT INTO ' + ATable + ' VALUES (' + APrefix + ',' + IntToStr(S.Legs) + ',' + F_(S.Expected) + ',' + F_(S.Hit) + ',' + F_(S.Gap) + ',' +
    F_(S.Se) + ',' + F_(S.Z) + ')');
end;

function RunAnalytics(ADb: TAppDb): Integer;
var
  Slips: TSls;
  All, Settled_, Unique, Unique2, Pool: TLgs;
  Tabs, SysAll, MNames, Shared: TStringList;
  I, K, X, PaperV: Integer;
  Count: Integer;
  Order, Cnts, Order2, Cnts2: array of Integer;
  Meds: array of Double;
  St: TStats;
  ListS, Lbl: string;

  procedure Add; begin Inc(Count); end;

  { ---- sazetak(paper) ---- }
  procedure Summary(APaper: Integer; const ALabel: string);
  var
    Every, Count_: TSls;
    NE, NC, X, Pending, SettledN, WonN, LegsN, LegsWon: Integer;
    Staked, Returned, SumProb: Double;
    Odds, Fair: array of Double;
    NoLegs: Boolean;
    Ids: TStringList;
    L: Integer;
  begin
    SetLength(Every, Length(Slips)); NE := 0;
    for X := 0 to High(Slips) do if Slips[X].Paper = APaper then begin Every[NE] := Slips[X]; Inc(NE); end;
    SetLength(Every, NE);
    SetLength(Count_, NE); NC := 0;
    for X := 0 to NE - 1 do if not IsInformational(Every[X].Note) then begin Count_[NC] := Every[X]; Inc(NC); end;
    SetLength(Count_, NC);
    if NC = 0 then
    begin
      ADb.Conn.ExecuteDirect('INSERT INTO an_sazetak (opseg, listica, informativnih) VALUES (' + Q_(ALabel) + ',0,' + IntToStr(NE - NC) + ')');
      Add; Exit;
    end;
    Pending := 0; SettledN := 0; WonN := 0; Staked := 0; Returned := 0;
    Ids := TStringList.Create;
    try
      Ids.Sorted := True;
      for X := 0 to NC - 1 do
      begin
        Ids.Add(IntToStr(Count_[X].Id));
        if Count_[X].Status = 'PENDING' then Inc(Pending);
        if Count_[X].Status <> 'PENDING' then
        begin
          Inc(SettledN); Staked := Staked + Count_[X].Stake; Returned := Returned + Count_[X].Payout;
          if Count_[X].Status = 'WON' then Inc(WonN);
        end;
      end;
      LegsN := 0; LegsWon := 0; SumProb := 0; SetLength(Odds, 0); SetLength(Fair, 0);
      for L := 0 to High(All) do
        if ((All[L].Status = 'WON') or (All[L].Status = 'LOST')) and (Ids.IndexOf(IntToStr(All[L].SlipId)) >= 0) then
        begin
          Inc(LegsN);
          if All[L].Status = 'WON' then Inc(LegsWon);
          SumProb := SumProb + All[L].Prob;
          SetLength(Odds, LegsN); Odds[LegsN - 1] := All[L].Odds;
          SetLength(Fair, LegsN); Fair[LegsN - 1] := 1.0 / All[L].Prob;
        end;
      NoLegs := LegsN = 0;
      ADb.Conn.ExecuteDirect('INSERT INTO an_sazetak VALUES (' + Q_(ALabel) + ',' + IntToStr(NC) + ',' + IntToStr(NE - NC) + ',' + IntToStr(Pending) + ',' + IntToStr(SettledN) + ',' +
        IntToStr(WonN) + ',' + F_(Staked) + ',' + F_(Returned) + ',' + F_(Returned - Staked) + ',' + N_(Staked <> 0, (Returned - Staked) / Max(Staked, 1e-300)) + ',' +
        IntToStr(LegsN) + ',' + N_(not NoLegs, LegsWon / Max(LegsN, 1)) + ',' + N_(not NoLegs, SumProb / Max(LegsN, 1)) + ',' +
        N_(not NoLegs, Median(Odds)) + ',' + N_(not NoLegs, Median(Fair)) + ')');
      Add;
    finally
      Ids.Free;
    end;
  end;

  { ---- usporedba strategija ---- }
  procedure Strategy(APaper: Integer; const ALabel, ASys: string; AMaxLegs: Integer);
  var
    Cand: TSls;
    X, NCand, Usable, NIdx, Ahead1, Ahead2, Lg: Integer;
    Staked, Ret1, Ret2, Prod, SumWon, Stake: Double;
    AllWon, Bad: Boolean;
  begin
    NCand := 0;
    SetLength(Cand, Length(Slips));
    for X := 0 to High(Slips) do
    begin
      if (APaper <> -1) and (Slips[X].Paper <> APaper) then Continue;
      if IsInformational(Slips[X].Note) then Continue;
      if (ASys <> '') and (Slips[X].Sys <> ASys) then Continue;
      if (Slips[X].Status <> 'WON') and (Slips[X].Status <> 'LOST') then Continue;
      Cand[NCand] := Slips[X]; Inc(NCand);
    end;
    Usable := 0; NIdx := 0; Staked := 0; Ret1 := 0; Ret2 := 0; Ahead1 := 0; Ahead2 := 0;
    for X := 0 to NCand - 1 do
    begin
      { listic s utakmicom koja nije odigrana ili s previse nogu se ne usporeduje }
      if Cand[X].NoMatch > 0 then Continue;
      if (AMaxLegs > 0) and (Cand[X].Legs > AMaxLegs) then Continue;
      Inc(Usable);
      if Cand[X].Legs = 0 then Continue;
      Prod := 1.0; SumWon := 0; AllWon := True;
      for Lg := 0 to High(All) do
        if All[Lg].SlipId = Cand[X].Id then
        begin
          Prod := Prod * All[Lg].Odds;
          if All[Lg].Status = 'WON' then SumWon := SumWon + All[Lg].Odds else AllWon := False;
        end;
      Stake := Cand[X].Stake;
      Inc(NIdx);
      Staked := Staked + Stake;
      if AllWon then begin Ret1 := Ret1 + Stake * Prod; if Stake * Prod > Stake then Inc(Ahead1); end;
      Ret2 := Ret2 + (Stake / Cand[X].Legs) * SumWon;
      if (Stake / Cand[X].Legs) * SumWon > Stake then Inc(Ahead2);
    end;
    Bad := Usable = 0;
    if Bad then Exit;
    ADb.Conn.ExecuteDirect('INSERT INTO an_strategija VALUES (' + Q_(ALabel) + ',' + Q_(ASys) + ',' + IntToStr(Usable) + ',' + F_(Staked) + ',' + F_(Ret1) + ',' + F_(Ret1 - Staked) + ',' +
      F_(IfThen(Staked <> 0, (Ret1 - Staked) / Max(Staked, 1e-300), 0.0)) + ',' + IntToStr(Ahead1) + ',' + F_(Staked) + ',' + F_(Ret2) + ',' + F_(Ret2 - Staked) + ',' +
      F_(IfThen(Staked <> 0, (Ret2 - Staked) / Max(Staked, 1e-300), 0.0)) + ',' + IntToStr(Ahead2) + ')');
    Add;
  end;

  { ---- pracenje jednog informativnog sustava ---- }
  procedure Tracking(const AName, AMarkerKind: string; const AMarkets: array of string);
  var
    Mine: TSls;
    NM, X, Y, Lg: Integer;
    Ids: TStringList;
    Calls, Filtered: TLgs;
    ByMarket: TLgs;
    Names: TStringList;
    NF: Integer;

    function InSystem(const ANote: string): Boolean;
    begin
      if AMarkerKind = 'prijelazi' then Result := Has(ANote, 'prijelaz')
      else if AMarkerKind = 'poluvrijeme' then Result := Has(ANote, 'poluvrijeme')
      else if AMarkerKind = 'elita' then Result := Has(ANote, 'elita')
      else if AMarkerKind = 'miks' then Result := Has(ANote, 'miks')
      else Result := Has(ANote, 'top listici');
    end;

    procedure Block(const ASection, AItem: string; const AFrame: TSls);
    var
      B: Integer;
      Done, WonN, PendingN: Integer;
      Staked, Returned, CSum: Double;
      HasC: Boolean;
      CN: Integer;
    begin
      Done := 0; WonN := 0; PendingN := 0; Staked := 0; Returned := 0; CSum := 0; CN := 0;
      for B := 0 to High(AFrame) do
      begin
        if AFrame[B].Status = 'PENDING' then Inc(PendingN);
        if (AFrame[B].Status = 'WON') or (AFrame[B].Status = 'LOST') then
        begin
          Inc(Done); Staked := Staked + AFrame[B].Stake; Returned := Returned + AFrame[B].Payout;
          if AFrame[B].Status = 'WON' then Inc(WonN);
          if AFrame[B].HasClaimed then begin CSum := CSum + AFrame[B].Claimed; Inc(CN); end;
        end;
      end;
      HasC := CN > 0;
      ADb.Conn.ExecuteDirect('INSERT INTO an_pracenje (sustav, odjeljak, naziv, listica, rijeseno, otvoreno, dobiveno, claimed, ulozeno, vraceno, dobitak, roi) VALUES (' +
        Q_(AName) + ',' + Q_(ASection) + ',' + Q_(AItem) + ',' + IntToStr(Length(AFrame)) + ',' + IntToStr(Done) + ',' + IntToStr(PendingN) + ',' + IntToStr(WonN) + ',' +
        N_(HasC, CSum / Max(CN, 1)) + ',' + F_(Staked) + ',' + F_(Returned) + ',' + F_(Returned - Staked) + ',' + N_(Staked <> 0, (Returned - Staked) / Max(Staked, 1e-300)) + ')');
      Add;
    end;

    procedure CallRow(const AItem, ASection: string; const AFrame: TLgs);
    var
      S: TStats;
    begin
      S := StatsOf(AFrame);
      ADb.Conn.ExecuteDirect('INSERT INTO an_pracenje (sustav, odjeljak, naziv, legs, ocekivano, pogodeno, razlika, se, z, roi) VALUES (' + Q_(AName) + ',' + Q_(ASection) + ',' + Q_(AItem) + ',' +
        IntToStr(S.Legs) + ',' + F_(S.Expected) + ',' + F_(S.Hit) + ',' + F_(S.Gap) + ',' + F_(S.Se) + ',' + F_(S.Z) + ',' + N_(S.Legs > 0, RoiOf(AFrame)) + ')');
      Add;
    end;

    procedure ShapeBlock(const AShape: string);
    var
      Sub: TSls;
      NS, B: Integer;
    begin
      SetLength(Sub, NM); NS := 0;
      for B := 0 to NM - 1 do
        if (AShape = 'pojedinacni') = (Mine[B].Legs = 1) then begin Sub[NS] := Mine[B]; Inc(NS); end;
      SetLength(Sub, NS);
      if NS > 0 then Block('oblik', AShape, Sub);
    end;

  var
    Sel: TSls;
    NSys: Integer;
    SysNames: TStringList;
    KeepOrder: array of Integer;
    Cnt: array of Integer;
    T, Pi: Integer;
    Tmp: string;
    TmpI: Integer;
  begin
    NM := 0;
    SetLength(Mine, Length(Slips));
    for X := 0 to High(Slips) do if InSystem(Slips[X].Note) then begin Mine[NM] := Slips[X]; Inc(NM); end;
    SetLength(Mine, NM);
    if NM = 0 then Exit;
    { zajednicka vjerojatnost listica: umnozak vjerojatnosti nogu }
    for X := 0 to NM - 1 do
    begin
      Mine[X].Claimed := 1.0; Mine[X].HasClaimed := False;
      for Lg := 0 to High(All) do
        if All[Lg].SlipId = Mine[X].Id then begin Mine[X].Claimed := Mine[X].Claimed * All[Lg].Prob; Mine[X].HasClaimed := True; end;
    end;
    Block('ukupno', '', Mine);
    { po sustavu: abecedno, pa po broju listica silazno (stabilno) }
    SysNames := TStringList.Create;
    try
      SysNames.CaseSensitive := True;
      for X := 0 to NM - 1 do if SysNames.IndexOf(Mine[X].Sys) < 0 then SysNames.Add(Mine[X].Sys);
      SysNames.CustomSort(@OrdCmp);
      NSys := SysNames.Count;
      SetLength(KeepOrder, NSys); SetLength(Cnt, NSys);
      for X := 0 to NSys - 1 do
      begin
        KeepOrder[X] := X; Cnt[X] := 0;
        for Y := 0 to NM - 1 do if Mine[Y].Sys = SysNames[X] then Inc(Cnt[X]);
      end;
      for X := 1 to NSys - 1 do
      begin
        T := KeepOrder[X]; Pi := X - 1;
        while (Pi >= 0) and (Cnt[KeepOrder[Pi]] < Cnt[T]) do begin KeepOrder[Pi + 1] := KeepOrder[Pi]; Dec(Pi); end;
        KeepOrder[Pi + 1] := T;
      end;
      for X := 0 to NSys - 1 do
      begin
        SetLength(Sel, NM); NF := 0;
        for Y := 0 to NM - 1 do if Mine[Y].Sys = SysNames[KeepOrder[X]] then begin Sel[NF] := Mine[Y]; Inc(NF); end;
        SetLength(Sel, NF);
        Block('sustav', SysNames[KeepOrder[X]], Sel);
      end;
    finally
      SysNames.Free;
    end;
    ShapeBlock('pojedinacni');
    ShapeBlock('kombinacija');

    { pozivi: odigrani, odabrana trzista, bez duplikata (kolo, liga, klubovi, izbor), po fer cijeni }
    Ids := TStringList.Create;
    try
      Ids.Sorted := True;
      for X := 0 to NM - 1 do Ids.Add(IntToStr(Mine[X].Id));
      SetLength(Calls, Length(All)); NF := 0;
      for Lg := 0 to High(All) do
      begin
        if Ids.IndexOf(IntToStr(All[Lg].SlipId)) < 0 then Continue;
        if (All[Lg].Status <> 'WON') and (All[Lg].Status <> 'LOST') then Continue;
        T := 0;
        for Y := 0 to High(AMarkets) do if All[Lg].Market = AMarkets[Y] then T := 1;
        if T = 0 then Continue;
        Calls[NF] := All[Lg]; Inc(NF);
      end;
      SetLength(Calls, NF);
    finally
      Ids.Free;
    end;
    Dedup(Calls, 2, Filtered);
    SetLength(Calls, 0); NF := 0;
    SetLength(Calls, Length(Filtered));
    for X := 0 to High(Filtered) do
      if Abs(Filtered[X].Odds * Filtered[X].Prob - 1) < FairTol then begin Calls[NF] := Filtered[X]; Inc(NF); end;
    SetLength(Calls, NF);
    Names := Uniq(Calls, 2);
    try
      { po izboru, po broju poziva silazno (stabilno) }
      SetLength(KeepOrder, Names.Count); SetLength(Cnt, Names.Count);
      for X := 0 to Names.Count - 1 do
      begin
        KeepOrder[X] := X;
        Cnt[X] := 0;
        for Y := 0 to High(Calls) do if Calls[Y].Sel = Names[X] then Inc(Cnt[X]);
      end;
      for X := 1 to Names.Count - 1 do
      begin
        T := KeepOrder[X]; Pi := X - 1;
        while (Pi >= 0) and (Cnt[KeepOrder[Pi]] < Cnt[T]) do begin KeepOrder[Pi + 1] := KeepOrder[Pi]; Dec(Pi); end;
        KeepOrder[Pi + 1] := T;
      end;
      for X := 0 to Names.Count - 1 do
      begin
        SetLength(ByMarket, Length(Calls)); NF := 0;
        for Y := 0 to High(Calls) do if Calls[Y].Sel = Names[KeepOrder[X]] then begin ByMarket[NF] := Calls[Y]; Inc(NF); end;
        SetLength(ByMarket, NF);
        CallRow(Names[KeepOrder[X]], 'izbor', ByMarket);
      end;
    finally
      Names.Free;
    end;
    Names := Uniq(Calls, 1);
    try
      SetLength(KeepOrder, Names.Count); SetLength(Cnt, Names.Count);
      for X := 0 to Names.Count - 1 do
      begin
        KeepOrder[X] := X; Cnt[X] := 0;
        for Y := 0 to High(Calls) do if Calls[Y].Market = Names[X] then Inc(Cnt[X]);
      end;
      for X := 1 to Names.Count - 1 do
      begin
        T := KeepOrder[X]; Pi := X - 1;
        while (Pi >= 0) and (Cnt[KeepOrder[Pi]] < Cnt[T]) do begin KeepOrder[Pi + 1] := KeepOrder[Pi]; Dec(Pi); end;
        KeepOrder[Pi + 1] := T;
      end;
      for X := 0 to Names.Count - 1 do
      begin
        ByMarket := Where(Calls, '', Names[KeepOrder[X]]);
        CallRow(Names[KeepOrder[X]], 'trziste', ByMarket);
      end;
    finally
      Names.Free;
    end;
    if Length(Calls) > 0 then CallRow('sve', 'sve', Calls);
    Tmp := ''; TmpI := 0;
    if TmpI = 1 then Exit;
  end;

begin
  Count := 0;
  Result := 0;
  Tabs := ADb.UserTables;
  try
    if (Tabs.IndexOf('slips') < 0) or (Tabs.IndexOf('slip_legs') < 0) then Exit;
  finally
    Tabs.Free;
  end;
  Recreate(ADb, 'an_sazetak', 'opseg TEXT, listica INTEGER, informativnih INTEGER, otvorenih INTEGER, rijesenih INTEGER, dobivenih INTEGER, ulozeno REAL, vraceno REAL, dobitak REAL, roi REAL, ' +
    'parova_rijeseno INTEGER, parova_pogodak REAL, parova_model REAL, parova_prosj_kvota REAL, parova_prosj_fer REAL');
  Recreate(ADb, 'an_kalibracija_sustava', 'sustav TEXT, parova INTEGER, pogodak REAL, ocekivano REAL, roi REAL, medijan_kvota REAL');
  Recreate(ADb, 'an_kalibracija', 'sustav TEXT, trziste TEXT, parova INTEGER, ocekivano REAL, pogodak REAL, razlika REAL, se REAL, z REAL');
  Recreate(ADb, 'an_head_to_head', 'sustav TEXT, trzista TEXT, parova INTEGER, ocekivano REAL, pogodak REAL, razlika REAL, se REAL, z REAL');
  Recreate(ADb, 'an_strategija', 'opseg TEXT, sustav TEXT, listica INTEGER, cijeli_ulozeno REAL, cijeli_vraceno REAL, cijeli_dobitak REAL, cijeli_roi REAL, cijeli_ispred INTEGER, ' +
    'pojed_ulozeno REAL, pojed_vraceno REAL, pojed_dobitak REAL, pojed_roi REAL, pojed_ispred INTEGER');
  Recreate(ADb, 'an_pracenje', 'sustav TEXT, odjeljak TEXT, naziv TEXT, listica INTEGER, rijeseno INTEGER, otvoreno INTEGER, dobiveno INTEGER, claimed REAL, ulozeno REAL, vraceno REAL, dobitak REAL, roi REAL, ' +
    'legs INTEGER, ocekivano REAL, pogodeno REAL, razlika REAL, se REAL, z REAL');
  LoadSlips(ADb, Slips);
  LoadLegs(ADb, All);
  ADb.Conn.StartTransaction;
  try
    Summary(0, 'stvarno');
    Summary(1, 'probno');

    Settled(All, True, Settled_);

    { ---- kalibracija po sustavima (calibration_by_system): fer cijena, pozivi bez duplikata, sustav po sustavu ---- }
    SysAll := TStringList.Create;
    try
      SysAll.CaseSensitive := True;
      for I := 0 to High(Slips) do
        if (Slips[I].Note <> '') and (SysAll.IndexOf(Slips[I].Sys) < 0) then SysAll.Add(Slips[I].Sys);
      SysAll.CustomSort(@OrdCmp);
      SetLength(Order, 0); SetLength(Cnts, 0);
      for K := 0 to SysAll.Count - 1 do
      begin
        FairOf(Settled_, SysAll[K], Pool);
        if Length(Pool) = 0 then Continue;
        SetLength(Order, Length(Order) + 1); Order[High(Order)] := K;
        SetLength(Cnts, Length(Cnts) + 1); Cnts[High(Cnts)] := Length(Pool);
      end;
      SortDesc(Order, Cnts);
      for X := 0 to High(Order) do
      begin
        FairOf(Settled_, SysAll[Order[X]], Pool);
        SetLength(Meds, Length(Pool));
        for I := 0 to High(Pool) do Meds[I] := Pool[I].Odds;
        St := StatsOf(Pool);
        ADb.Conn.ExecuteDirect('INSERT INTO an_kalibracija_sustava VALUES (' + Q_(SysAll[Order[X]]) + ',' + IntToStr(Length(Pool)) + ',' + F_(St.Hit) + ',' + F_(St.Expected) + ',' +
          F_(RoiOf(Pool)) + ',' + F_(Median(Meds)) + ')');
        Add;
      end;
    finally
      SysAll.Free;
    end;

    { ---- usporedba sustava (comparison) i head_to_head: pozivi bez duplikata unutar sustava ---- }
    Dedup(Settled_, 0, Unique);
    SysAll := Uniq(Unique, 0);
    try
      SetLength(Order, 0); SetLength(Cnts, 0);
      for K := 0 to SysAll.Count - 1 do
      begin
        SetLength(Order, Length(Order) + 1); Order[High(Order)] := K;
        SetLength(Cnts, Length(Cnts) + 1); Cnts[High(Cnts)] := Length(Where(Unique, SysAll[K], ''));
      end;
      SortDesc(Order, Cnts);
      for X := 0 to High(Order) do
      begin
        Pool := Where(Unique, SysAll[Order[X]], '');
        PutStats(ADb, 'an_kalibracija', Q_(SysAll[Order[X]]) + ',' + Q_('SVE'), StatsOf(Pool)); Add;
        MNames := Uniq(Pool, 1);
        try
          SetLength(Order2, 0); SetLength(Cnts2, 0);
          for K := 0 to MNames.Count - 1 do
          begin
            SetLength(Order2, Length(Order2) + 1); Order2[High(Order2)] := K;
            SetLength(Cnts2, Length(Cnts2) + 1); Cnts2[High(Cnts2)] := Length(Where(Pool, '', MNames[K]));
          end;
          SortDesc(Order2, Cnts2);
          for K := 0 to High(Order2) do
          begin
            PutStats(ADb, 'an_kalibracija', Q_(SysAll[Order[X]]) + ',' + Q_(MNames[Order2[K]]), StatsOf(Where(Pool, '', MNames[Order2[K]]))); Add;
          end;
        finally
          MNames.Free;
        end;
      end;
      { head_to_head: samo trzista koja je igrao svaki sustav }
      if SysAll.Count > 0 then
      begin
        Shared := Uniq(Where(Unique, SysAll[0], ''), 1);
        try
          for K := 1 to SysAll.Count - 1 do
          begin
            MNames := Uniq(Where(Unique, SysAll[K], ''), 1);
            try
              for I := Shared.Count - 1 downto 0 do
                if MNames.IndexOf(Shared[I]) < 0 then Shared.Delete(I);
            finally
              MNames.Free;
            end;
          end;
          if Shared.Count > 0 then
          begin
            ListS := '';
            for I := 0 to Shared.Count - 1 do begin if I > 0 then ListS := ListS + ','; ListS := ListS + Shared[I]; end;
            SetLength(Order, 0); SetLength(Cnts, 0);
            for K := 0 to SysAll.Count - 1 do
            begin
              InShared(Where(Unique, SysAll[K], ''), Shared, Unique2);
              SetLength(Order, Length(Order) + 1); Order[High(Order)] := K;
              SetLength(Cnts, Length(Cnts) + 1); Cnts[High(Cnts)] := Length(Unique2);
            end;
            SortDesc(Order, Cnts);
            for X := 0 to High(Order) do
            begin
              InShared(Where(Unique, SysAll[Order[X]], ''), Shared, Unique2);
              PutStats(ADb, 'an_head_to_head', Q_(SysAll[Order[X]]) + ',' + Q_(ListS), StatsOf(Unique2)); Add;
            end;
          end;
        finally
          Shared.Free;
        end;
      end;
    finally
      SysAll.Free;
    end;

    { ---- usporedba strategija: listic naspram pojedinacnih, listici do 10 nogu ---- }
    for X := 0 to 2 do
    begin
      if X = 0 then begin Lbl := 'stvarno'; PaperV := 0; end
      else if X = 1 then begin Lbl := 'probno'; PaperV := 1; end
      else begin Lbl := 'sve'; PaperV := -1; end;
      Strategy(PaperV, Lbl, '', 10);
      SysAll := TStringList.Create;
      try
        SysAll.CaseSensitive := True;
        for I := 0 to High(Slips) do
          if (not IsInformational(Slips[I].Note)) and ((PaperV = -1) or (Slips[I].Paper = PaperV)) and (SysAll.IndexOf(Slips[I].Sys) < 0) then SysAll.Add(Slips[I].Sys);
        SysAll.CustomSort(@OrdCmp);
        for I := 0 to SysAll.Count - 1 do Strategy(PaperV, Lbl, SysAll[I], 10);
      finally
        SysAll.Free;
      end;
    end;

    { ---- pracenje informativnih sustava ---- }
    Tracking('prijelazi', 'prijelazi', ['HTFT']);
    Tracking('poluvrijeme ili kraj', 'poluvrijeme', ['HT_OR_FT']);
    Tracking('elita', 'elita', ['HT_OR_FT']);
    Tracking('miks', 'miks', ['HTFT', 'HT_OR_FT']);
    Tracking('top listici', 'top', ['HTFT', 'HT_OR_FT']);
  except
    ADb.Conn.Rollback;
    raise;
  end;
  ADb.Conn.Commit;
  Result := Count;
end;

function AnalyticsHookImpl(const AName: string; const A: array of Variant; N: Integer): Variant;
begin
  Result := Null;
  if (ActiveDb = nil) or not ActiveDb.Connected then Exit;
  Result := RunAnalytics(ActiveDb);
end;

initialization
  AnalyticsHook := @AnalyticsHookImpl;

end.
