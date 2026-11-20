unit ta_pairs;
{ Parovi na istoj utakmici, sesija od odvojenih listica po Kellyju i Monte Carlo (smartbet/models/combinations.py,
  models/portfolio.py, backtest/montecarlo.py). Parovi i sesija su deterministicki i daju iste brojke kao Python;
  Monte Carlo koristi vlastiti generator (Mersenne), pa se podudara statisticki, ne brojku po brojku.
    RunCombinations(liga, domaci, gosti [, datum])  -> tablica comb_parovi
    RunSession(banka [, frakcija_kellyja])           -> sesija_listici + sesija_sazetak iz tablice sesija_ulaz
    RunMonteCarlo("tips" [, ulog [, ponavljanja [, seed]]])                        -> nad tablicom engine_tips
    RunMonteCarlo("sesija", banka [, kola [, ponavljanja [, frakcija [, seed]]]])  -> nad listicima sesije }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, StrUtils, Variants, ZDataset, ta_meta, ta_expr, ta_exprdb, ta_predict, ta_newton;

const
  KellyDefault = 0.25;
  MinLegs = 4;
  MaxLegs = 6;
  MaxSessionExposure = 0.25;

function RunCombinations(ADb: TAppDb; const ADiv, AHome, AAway: string; ARef: Integer): Integer;
function RunSession(ADb: TAppDb; ABank, AKelly: Double): Integer;
function RunMonteCarloTips(ADb: TAppDb; AStake: Double; AReps, ASeed: Integer): Integer;
function RunMonteCarloSession(ADb: TAppDb; ABank: Double; ARounds, AReps: Integer; AKelly: Double; ASeed: Integer): Integer;

implementation

const
  QLevels: array[0..4] of Double = (5, 25, 50, 75, 95);
  SelNames: array[0..13] of string = ('1', 'X', '2', '1X', '12', 'X2', 'GG', 'NG',
    'Over 1.5', 'Under 1.5', 'Over 2.5', 'Under 2.5', 'Over 3.5', 'Under 3.5');

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

function SelIndex(const AName: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(SelNames) do
    if SelNames[I] = AName then Exit(I);
  Result := -1;
end;

{ maska odabira nad rezultatom (domaci I, gosti J) }
function InSel(AIdx, I, J: Integer): Boolean;
var
  T: Integer;
begin
  T := I + J;
  case AIdx of
    0: Result := I > J;
    1: Result := I = J;
    2: Result := I < J;
    3: Result := I >= J;
    4: Result := I <> J;
    5: Result := I <= J;
    6: Result := (I > 0) and (J > 0);
    7: Result := (I = 0) or (J = 0);
    8: Result := T > 1.5;
    9: Result := T < 1.5;
    10: Result := T > 2.5;
    11: Result := T < 2.5;
    12: Result := T > 3.5;
  else
    Result := T < 3.5;
  end;
end;

function SelSum(const AM: TMatrix; A1, A2: Integer): Double;
var
  I, J: Integer;
begin
  Result := 0;
  for I := 0 to High(AM) do
    for J := 0 to High(AM) do
      if InSel(A1, I, J) and ((A2 < 0) or InSel(A2, I, J)) then Result := Result + AM[I][J];
end;

function Degenerate(AJoint, APa, APb: Double): Boolean;
begin
  Result := (AJoint < 1e-6) or (AJoint > Min(APa, APb) - 1e-9);
end;

function EnsureTable(ADb: TAppDb; const AName: string): Boolean;
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

{ ---------------- parovi ---------------- }

type
  TComb = record
    A, B: Integer;
    Pa, Pb, Joint, Lift: Double;
  end;

function RunCombinations(ADb: TAppDb; const ADiv, AHome, AAway: string; ARef: Integer): Integer;
var
  Pr: TaPredictor;
  P: TaPrediction;
  Singles: array[0..13] of Double;
  Found: array of TComb;
  I, J, N: Integer;
  C, Tmp: TComb;
  Ind: Double;
begin
  Result := 0;
  if not EnsureTable(ADb, 'matches') then Exit;
  Pr := TaPredictor.Create(ADb);
  try
    P := Pr.Predict(ADiv, AHome, AAway, ARef);
  finally
    Pr.Free;
  end;
  if (not P.Ok) or (Length(P.Matrix) = 0) then raise EExpr.Create('RunCombinations: nema dovoljno povijesnih podataka prije tog datuma');
  for I := 0 to 13 do Singles[I] := SelSum(P.Matrix, I, -1);
  N := 0;
  for I := 0 to 12 do
    for J := I + 1 to 13 do
    begin
      C.A := I; C.B := J; C.Pa := Singles[I]; C.Pb := Singles[J];
      C.Joint := SelSum(P.Matrix, I, J);
      if (C.Pa < 0.05) or (C.Pb < 0.05) then Continue;
      if Degenerate(C.Joint, C.Pa, C.Pb) then Continue;
      Ind := C.Pa * C.Pb;
      if Ind > 0 then C.Lift := C.Joint / Ind else C.Lift := 0;
      SetLength(Found, N + 1);
      Found[N] := C; Inc(N);
    end;
  { najjaca povezanost prva; stabilno (Python sorted s reverse=True) }
  for I := 1 to N - 1 do
  begin
    Tmp := Found[I]; J := I - 1;
    while (J >= 0) and (Found[J].Lift < Tmp.Lift) do begin Found[J + 1] := Found[J]; Dec(J); end;
    Found[J + 1] := Tmp;
  end;
  ADb.Conn.ExecuteDirect('DROP TABLE IF EXISTS comb_parovi');
  ADb.Conn.ExecuteDirect('CREATE TABLE comb_parovi (id INTEGER PRIMARY KEY AUTOINCREMENT, prvi TEXT, drugi TEXT, p_prvi REAL, p_drugi REAL, zajedno REAL, ' +
    'nezavisno REAL, lift REAL, fer_kvota REAL, kvota_mnozenjem REAL, prednost_ako_nezavisno REAL)');
  ADb.Conn.StartTransaction;
  try
    for I := 0 to N - 1 do
    begin
      Ind := Found[I].Pa * Found[I].Pb;
      ADb.Conn.ExecuteDirect('INSERT INTO comb_parovi (prvi, drugi, p_prvi, p_drugi, zajedno, nezavisno, lift, fer_kvota, kvota_mnozenjem, prednost_ako_nezavisno) VALUES (' +
        Q_(SelNames[Found[I].A]) + ',' + Q_(SelNames[Found[I].B]) + ',' + F_(Found[I].Pa) + ',' + F_(Found[I].Pb) + ',' + F_(Found[I].Joint) + ',' + F_(Ind) + ',' +
        F_(Found[I].Lift) + ',' + F_(1.0 / Found[I].Joint) + ',' + F_(1.0 / Ind) + ',' + F_(Found[I].Lift - 1.0) + ')');
    end;
    ADb.Conn.Commit;
  except
    ADb.Conn.Rollback;
    raise;
  end;
  Result := N;
end;

{ ---------------- sesija ---------------- }

type
  TLeg = record
    Match, First, Second: string;
    Prob, Odds, Edge, Kelly, Stake, Fraction: Double;
  end;

function RunSession(ADb: TAppDb; ABank, AKelly: Double): Integer;
var
  Q: TZQuery;
  Pr: TaPredictor;
  P: TaPrediction;
  Legs: array of TLeg;
  N, I, J, A1, A2: Integer;
  Dv, Hm, Aw, Dt, Fs, Sc: string;
  Joint, Pa, Pb, Odds, Total, Raw, Exposure, StakeSum: Double;
  Skipped: Integer;
begin
  Result := 0;
  { bez tablice ulaza nema sto racunati (kao baza bez utakmica) }
  if not EnsureTable(ADb, 'sesija_ulaz') then Exit;
  if ABank <= 0 then raise EExpr.Create('banka mora biti pozitivna');
  if (AKelly <= 0) or (AKelly > 1) then raise EExpr.Create('djelic Kellyja mora biti u (0, 1]');
  Pr := TaPredictor.Create(ADb);
  Q := ADb.NewQuery('SELECT liga, domaci, gosti, prvi, drugi, kvota, datum FROM sesija_ulaz ORDER BY rowid');
  N := 0;
  try
    Q.Open;
    while not Q.Eof do
    begin
      Dv := Q.Fields[0].AsString; Hm := Q.Fields[1].AsString; Aw := Q.Fields[2].AsString;
      Fs := Q.Fields[3].AsString; Sc := Q.Fields[4].AsString; Odds := Q.Fields[5].AsFloat;
      if Q.Fields[6].IsNull then Dt := '' else Dt := Q.Fields[6].AsString;
      for I := 0 to N - 1 do
        if Legs[I].Match = Hm + '-' + Aw then
          raise EExpr.Create('dva listica s iste utakmice nisu neovisna - jedna utakmica, jedan listic');
      if Dt = '' then P := Pr.Predict(Dv, Hm, Aw, Trunc(Date)) else P := Pr.Predict(Dv, Hm, Aw, DayOfText(Dt));
      if (not P.Ok) or (Length(P.Matrix) = 0) then raise EExpr.Create(Hm + '-' + Aw + ': model nema dovoljno povijesti za ovu ligu');
      A1 := SelIndex(Fs); A2 := SelIndex(Sc);
      if A1 < 0 then raise EExpr.Create('nepoznato trziste: ' + Fs);
      if A2 < 0 then raise EExpr.Create('nepoznato trziste: ' + Sc);
      Joint := SelSum(P.Matrix, A1, A2); Pa := SelSum(P.Matrix, A1, -1); Pb := SelSum(P.Matrix, A2, -1);
      if Degenerate(Joint, Pa, Pb) then
        raise EExpr.Create(Fs + ' + ' + Sc + ': par je ugnijezden ili nemoguc - kombinacija je samo stroza od dvije oklade');
      if not ((Joint > 0.0) and (Joint < 1.0)) then raise EExpr.Create(Hm + '-' + Aw + ': vjerojatnost nije u (0, 1)');
      if Odds <= 1.0 then raise EExpr.Create(Hm + '-' + Aw + ': kvota mora biti veca od 1.0');
      SetLength(Legs, N + 1);
      Legs[N].Match := Hm + '-' + Aw; Legs[N].First := Fs; Legs[N].Second := Sc;
      Legs[N].Prob := Joint; Legs[N].Odds := Odds;
      Legs[N].Edge := Joint * Odds - 1.0;
      if Legs[N].Edge <= 0 then Legs[N].Kelly := 0 else Legs[N].Kelly := Legs[N].Edge / (Odds - 1.0);
      Inc(N);
      Q.Next;
    end;
  finally
    Q.Free;
    Pr.Free;
  end;
  if (N < MinLegs) or (N > MaxLegs) then
    raise EExpr.Create('sesija trazi ' + IntToStr(MinLegs) + '-' + IntToStr(MaxLegs) + ' odvojenih listica, dobiveno ' + IntToStr(N));
  Total := 0; Skipped := 0;
  for I := 0 to N - 1 do
  begin
    Raw := Legs[I].Kelly * AKelly;
    Legs[I].Fraction := Raw;
    if Raw <= 0 then Inc(Skipped);
    Total := Total + Raw;
  end;
  if Total > MaxSessionExposure then
    for I := 0 to N - 1 do Legs[I].Fraction := Legs[I].Fraction * MaxSessionExposure / Total;
  StakeSum := 0;
  for I := 0 to N - 1 do begin Legs[I].Stake := ABank * Legs[I].Fraction; StakeSum := StakeSum + Legs[I].Stake; end;
  Exposure := StakeSum / ABank;
  ADb.Conn.ExecuteDirect('DROP TABLE IF EXISTS sesija_listici');
  ADb.Conn.ExecuteDirect('DROP TABLE IF EXISTS sesija_sazetak');
  ADb.Conn.ExecuteDirect('CREATE TABLE sesija_listici (id INTEGER PRIMARY KEY AUTOINCREMENT, utakmica TEXT, par TEXT, vjerojatnost REAL, fer_kvota REAL, ' +
    'ponudjena_kvota REAL, prednost REAL, kelly REAL, udio REAL, ulog REAL, igra TEXT)');
  ADb.Conn.ExecuteDirect('CREATE TABLE sesija_sazetak (naziv TEXT, vrijednost REAL)');
  ADb.Conn.StartTransaction;
  try
    for I := 0 to N - 1 do
      ADb.Conn.ExecuteDirect('INSERT INTO sesija_listici (utakmica, par, vjerojatnost, fer_kvota, ponudjena_kvota, prednost, kelly, udio, ulog, igra) VALUES (' +
        Q_(Legs[I].Match) + ',' + Q_(Legs[I].First + ' + ' + Legs[I].Second) + ',' + F_(Legs[I].Prob) + ',' + F_(1.0 / Legs[I].Prob) + ',' + F_(Legs[I].Odds) + ',' +
        F_(Legs[I].Edge) + ',' + F_(Legs[I].Kelly) + ',' + F_(Legs[I].Fraction) + ',' + F_(Legs[I].Stake) + ',' + Q_(IfThen(Legs[I].Stake > 0, 'DA', 'NE')) + ')');
    ADb.Conn.ExecuteDirect('INSERT INTO sesija_sazetak VALUES (''banka'',' + F_(ABank) + ')');
    ADb.Conn.ExecuteDirect('INSERT INTO sesija_sazetak VALUES (''kelly_frakcija'',' + F_(AKelly) + ')');
    ADb.Conn.ExecuteDirect('INSERT INTO sesija_sazetak VALUES (''listica'',' + IntToStr(N) + ')');
    ADb.Conn.ExecuteDirect('INSERT INTO sesija_sazetak VALUES (''preskoceno'',' + IntToStr(Skipped) + ')');
    ADb.Conn.ExecuteDirect('INSERT INTO sesija_sazetak VALUES (''ukupni_ulog'',' + F_(StakeSum) + ')');
    ADb.Conn.ExecuteDirect('INSERT INTO sesija_sazetak VALUES (''izlozenost'',' + F_(Exposure) + ')');
    ADb.Conn.Commit;
  except
    ADb.Conn.Rollback;
    raise;
  end;
  Result := N;
end;

{ ---------------- Monte Carlo ---------------- }

function Rnd: Double;
begin
  Result := ((Random(67108864) * 134217728.0) + Random(134217728)) / 9007199254740992.0;
end;

procedure SortD(var A: array of Double);
  procedure QS(L, R: Integer);
  var
    I, J: Integer;
    P, T: Double;
  begin
    I := L; J := R; P := A[(L + R) div 2];
    repeat
      while A[I] < P do Inc(I);
      while A[J] > P do Dec(J);
      if I <= J then begin T := A[I]; A[I] := A[J]; A[J] := T; Inc(I); Dec(J); end;
    until I > J;
    if L < J then QS(L, J);
    if I < R then QS(I, R);
  end;
begin
  if Length(A) > 1 then QS(0, High(A));
end;

{ np.percentile (linearna interpolacija) nad sortiranim nizom }
function Pct(const A: array of Double; AQ: Double): Double;
var
  Vi, G: Double;
  Lo, Hi: Integer;
begin
  if Length(A) = 0 then Exit(0);
  Vi := AQ / 100.0 * (Length(A) - 1);
  Lo := Trunc(Floor(Vi)); Hi := Min(Lo + 1, High(A));
  G := Vi - Lo;
  Result := A[Lo] + (A[Hi] - A[Lo]) * G;
end;

procedure WriteMc(ADb: TAppDb; const AMode: string; AReps: Integer; var AFinal, ADd: array of Double; ARuin: Integer);
var
  Loss, I: Integer;
  Qs: array[0..4] of Double;

  procedure Row(const AName: string; const A: array of Double);
  var
    K: Integer;
  begin
    for K := 0 to 4 do Qs[K] := Pct(A, QLevels[K]);
    ADb.Conn.ExecuteDirect('INSERT INTO mc_rezultat (nacin, mjera, p5, p25, p50, p75, p95) VALUES (' + Q_(AMode) + ',' + Q_(AName) + ',' + F_(Qs[0]) + ',' + F_(Qs[1]) + ',' + F_(Qs[2]) + ',' + F_(Qs[3]) + ',' + F_(Qs[4]) + ')');
  end;

begin
  SortD(AFinal); SortD(ADd);
  Loss := 0;
  for I := 0 to High(AFinal) do if AFinal[I] < 0 then Inc(Loss);
  { svaki nacin (tips, sesija) cuva svoje retke }
  ADb.Conn.ExecuteDirect('CREATE TABLE IF NOT EXISTS mc_rezultat (nacin TEXT, mjera TEXT, p5 REAL, p25 REAL, p50 REAL, p75 REAL, p95 REAL)');
  ADb.Conn.ExecuteDirect('CREATE TABLE IF NOT EXISTS mc_sazetak (nacin TEXT, naziv TEXT, vrijednost REAL)');
  ADb.Conn.ExecuteDirect('DELETE FROM mc_rezultat WHERE nacin = ' + Q_(AMode));
  ADb.Conn.ExecuteDirect('DELETE FROM mc_sazetak WHERE nacin = ' + Q_(AMode));
  ADb.Conn.StartTransaction;
  try
    Row('konacno', AFinal);
    Row('najveci_pad', ADd);
    ADb.Conn.ExecuteDirect('INSERT INTO mc_sazetak (nacin, naziv, vrijednost) VALUES (' + Q_(AMode) + ',''ponavljanja'',' + IntToStr(AReps) + ')');
    ADb.Conn.ExecuteDirect('INSERT INTO mc_sazetak (nacin, naziv, vrijednost) VALUES (' + Q_(AMode) + ',''udio_gubitka'',' + F_(Loss / Length(AFinal)) + ')');
    ADb.Conn.ExecuteDirect('INSERT INTO mc_sazetak (nacin, naziv, vrijednost) VALUES (' + Q_(AMode) + ',''udio_propasti'',' + F_(ARuin / Length(AFinal)) + ')');
    ADb.Conn.Commit;
  except
    ADb.Conn.Rollback;
    raise;
  end;
end;

function RunMonteCarloTips(ADb: TAppDb; AStake: Double; AReps, ASeed: Integer): Integer;
var
  Q: TZQuery;
  Prob, Odds: array of Double;
  N, R, I: Integer;
  Cum, Peak, Dd: Double;
  Fin, Dds: array of Double;
begin
  Result := 0;
  if not EnsureTable(ADb, 'engine_tips') then Exit;
  Q := ADb.NewQuery('SELECT probability, odds FROM engine_tips ORDER BY matchdate, market, id');
  N := 0;
  try
    Q.Open;
    while not Q.Eof do
    begin
      SetLength(Prob, N + 1); SetLength(Odds, N + 1);
      Prob[N] := Q.Fields[0].AsFloat; Odds[N] := Q.Fields[1].AsFloat;
      Inc(N);
      Q.Next;
    end;
  finally
    Q.Free;
  end;
  if N = 0 then Exit;
  RandSeed := ASeed;
  SetLength(Fin, AReps); SetLength(Dds, AReps);
  for R := 0 to AReps - 1 do
  begin
    Cum := 0; Peak := 0; Dd := 0;
    for I := 0 to N - 1 do
    begin
      if Rnd < Prob[I] then Cum := Cum + AStake * (Odds[I] - 1.0) else Cum := Cum - AStake;
      if I = 0 then Peak := Cum else if Cum > Peak then Peak := Cum;
      if Peak - Cum > Dd then Dd := Peak - Cum;
    end;
    Fin[R] := Cum; Dds[R] := Dd;
  end;
  WriteMc(ADb, 'tips', AReps, Fin, Dds, 0);
  Result := AReps;
end;

function RunMonteCarloSession(ADb: TAppDb; ABank: Double; ARounds, AReps: Integer; AKelly: Double; ASeed: Integer): Integer;
var
  Q: TZQuery;
  Prob, Odds, Frac: array of Double;
  N, R, K, I, Ruined: Integer;
  Bank, Peak, Dd, Prof: Double;
  Fin, Dds: array of Double;
  Gone: Boolean;
  Total, Raw: Double;
begin
  Result := 0;
  if not EnsureTable(ADb, 'sesija_listici') then Exit;
  Q := ADb.NewQuery('SELECT vjerojatnost, ponudjena_kvota, kelly FROM sesija_listici ORDER BY id');
  N := 0;
  try
    Q.Open;
    while not Q.Eof do
    begin
      SetLength(Prob, N + 1); SetLength(Odds, N + 1); SetLength(Frac, N + 1);
      Prob[N] := Q.Fields[0].AsFloat; Odds[N] := Q.Fields[1].AsFloat; Frac[N] := Q.Fields[2].AsFloat * AKelly;
      Inc(N);
      Q.Next;
    end;
  finally
    Q.Free;
  end;
  if N = 0 then Exit;
  Total := 0;
  for I := 0 to N - 1 do Total := Total + Frac[I];
  if Total > MaxSessionExposure then
    for I := 0 to N - 1 do Frac[I] := Frac[I] * MaxSessionExposure / Total;
  RandSeed := ASeed;
  SetLength(Fin, AReps); SetLength(Dds, AReps);
  Ruined := 0;
  for R := 0 to AReps - 1 do
  begin
    Bank := ABank; Peak := Bank; Dd := 0; Gone := False;
    for K := 1 to ARounds do
    begin
      if Bank <= 0 then begin Gone := True; Break; end;
      Prof := 0;
      for I := 0 to N - 1 do
      begin
        Raw := Bank * Frac[I];
        if Rnd < Prob[I] then Prof := Prof + Raw * (Odds[I] - 1.0) else Prof := Prof - Raw;
      end;
      Bank := Bank + Prof;
      if Bank > Peak then Peak := Bank;
      if Peak - Bank > Dd then Dd := Peak - Bank;
    end;
    if Gone then Inc(Ruined);
    Fin[R] := Bank - ABank; Dds[R] := Dd;
  end;
  WriteMc(ADb, 'sesija', AReps, Fin, Dds, Ruined);
  Result := AReps;
end;

{ ---------------- izrazi ---------------- }

function PairsHookImpl(const AName: string; const A: array of Variant; N: Integer): Variant;
var
  Ref: Integer;
  Reps, Seed, Rounds: Integer;
  Mode: string;
  Bank, Kelly, Stake: Double;
begin
  Result := Null;
  if (ActiveDb = nil) or not ActiveDb.Connected then Exit;
  if AName = 'runcombinations' then
  begin
    if (N >= 4) and not VarIsNull(A[3]) then Ref := DayOfArg(A[3]) else Ref := Trunc(Date);
    Exit(RunCombinations(ActiveDb, UpperCase(Trim(VarToStr(A[0]))), Trim(VarToStr(A[1])), Trim(VarToStr(A[2])), Ref));
  end;
  if AName = 'runsession' then
  begin
    Kelly := KellyDefault;
    if (N >= 2) and not VarIsNull(A[1]) then Kelly := Double(A[1]);
    Exit(RunSession(ActiveDb, Double(A[0]), Kelly));
  end;
  { runmontecarlo }
  Mode := LowerCase(Trim(VarToStr(A[0])));
  if Mode = 'tips' then
  begin
    Stake := 1.0; Reps := 2000; Seed := 0;
    if (N >= 2) and not VarIsNull(A[1]) then Stake := Double(A[1]);
    if (N >= 3) and not VarIsNull(A[2]) then Reps := Max(1, Trunc(Double(A[2])));
    if (N >= 4) and not VarIsNull(A[3]) then Seed := Trunc(Double(A[3]));
    Exit(RunMonteCarloTips(ActiveDb, Stake, Reps, Seed));
  end;
  if (Mode = 'sesija') or (Mode = 'session') then
  begin
    if N < 2 then raise EExpr.Create('RunMonteCarlo("sesija", banka [, kola [, ponavljanja [, frakcija [, seed]]]])');
    Bank := Double(A[1]); Rounds := 50; Reps := 2000; Kelly := KellyDefault; Seed := 0;
    if (N >= 3) and not VarIsNull(A[2]) then Rounds := Max(1, Trunc(Double(A[2])));
    if (N >= 4) and not VarIsNull(A[3]) then Reps := Max(1, Trunc(Double(A[3])));
    if (N >= 5) and not VarIsNull(A[4]) then Kelly := Double(A[4]);
    if (N >= 6) and not VarIsNull(A[5]) then Seed := Trunc(Double(A[5]));
    Exit(RunMonteCarloSession(ActiveDb, Bank, Rounds, Reps, Kelly, Seed));
  end;
  raise EExpr.Create('RunMonteCarlo: nacin je "tips" ili "sesija"');
end;

initialization
  PairsHook := @PairsHookImpl;

end.
