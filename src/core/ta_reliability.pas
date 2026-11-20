unit ta_reliability;
{ Izvjesce pouzdanosti i simulacija progresija ulaganja nad rezultatima backtesta (smartbet/backtest/standard.py:
  reliability_report, simulate_progression, progression_report). Citaju tablicu backtest_bets koju puni RunBacktest.
  Postupak je isti kao u Pythonu, ali slucajni brojevi dolaze iz vlastitog generatora (Mersenne), ne iz numpyjevog, pa se
  rezultati podudaraju statisticki (unutar greske simulacije), ne brojku po brojku. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, StrUtils, Variants, ZDataset, ta_meta, ta_expr, ta_exprdb;

{ backtest_pouzdanost: po sustavu intervali ROI-ja (bootstrap po kolima i po sezonama) i p-vrijednosti; vraca broj redaka }
function RunReliability(ADb: TAppDb; AReps, ASeed: Integer): Integer;
{ backtest_progresije: za "veliki" sustav, po pravilu ulaganja medijan, prosjek, 5. i 95. percentil, najgore i udio negativnih;
  AHorizon > 0 skraci svaku sezonu na prvih toliko kola (razlicitih datuma) }
function RunProgression(ADb: TAppDb; AHorizon, AReps, ASeed: Integer): Integer;

implementation

const
  Rules: array[0..8] of string = ('FLAT', 'MARTINGALE', 'FIBONACCI', 'FIBONACCI_ADJ', 'LET_IT_RIDE', 'PAROLI_3', 'ANTI_MARTINGALE', 'DALEMBERT', 'SEQ_1324');
  Seq1324: array[0..3] of Double = (1.0, 3.0, 2.0, 4.0);

type
  TBet = record
    System, Div_, Season, Date: string;
    Prob, Odds, Profit: Double;
    Won: Boolean;
  end;
  TBets = array of TBet;

type
  TDoubleArray = array of Double;

var
  Fib: array[0..39] of Double;
  FibAdj: array[0..38] of Double;

procedure InitFib;
var
  I: Integer;
begin
  Fib[0] := 1; Fib[1] := 1;
  for I := 2 to 39 do Fib[I] := Fib[I - 1] + Fib[I - 2];
  for I := 0 to 38 do FibAdj[I] := Fib[I + 1];
end;

function Rnd: Double;
begin
  { 53 bita: dva poziva po 26/27 bita }
  Result := ((Random(67108864) * 134217728.0) + Random(134217728)) / 9007199254740992.0;
end;

procedure QuickSortD(var A: array of Double; L, R: Integer);
var
  I, J: Integer;
  P, T: Double;
begin
  I := L; J := R;
  P := A[(L + R) div 2];
  repeat
    while A[I] < P do Inc(I);
    while A[J] > P do Dec(J);
    if I <= J then begin T := A[I]; A[I] := A[J]; A[J] := T; Inc(I); Dec(J); end;
  until I > J;
  if L < J then QuickSortD(A, L, J);
  if I < R then QuickSortD(A, I, R);
end;

procedure SortD(var A: array of Double);
begin
  if Length(A) < 2 then Exit;
  QuickSortD(A, 0, High(A));
end;

{ numpyjev percentil s linearnom interpolacijom nad sortiranim poljem }
function Pctl(const ASorted: array of Double; APct: Double): Double;
var
  Pos_, Fr: Double;
  Lo: Integer;
begin
  if Length(ASorted) = 0 then Exit(0);
  Pos_ := (APct / 100.0) * (Length(ASorted) - 1);
  Lo := Trunc(Pos_);
  Fr := Pos_ - Lo;
  if Lo >= High(ASorted) then Exit(ASorted[High(ASorted)]);
  Result := ASorted[Lo] + (ASorted[Lo + 1] - ASorted[Lo]) * Fr;
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

procedure LoadBets(ADb: TAppDb; var ABets: TBets);
var
  Q: TZQuery;
  N: Integer;
begin
  SetLength(ABets, 0);
  Q := ADb.NewQuery('SELECT system, division, season, matchdate, probability, fair_odds, won, profit FROM backtest_bets ORDER BY id');
  try
    Q.Open;
    N := 0;
    SetLength(ABets, 4096);
    while not Q.Eof do
    begin
      if N >= Length(ABets) then SetLength(ABets, Length(ABets) * 2);
      ABets[N].System := Q.Fields[0].AsString; ABets[N].Div_ := Q.Fields[1].AsString; ABets[N].Season := Q.Fields[2].AsString;
      ABets[N].Date := Q.Fields[3].AsString; ABets[N].Prob := Q.Fields[4].AsFloat; ABets[N].Odds := Q.Fields[5].AsFloat;
      ABets[N].Won := Q.Fields[6].AsInteger <> 0; ABets[N].Profit := Q.Fields[7].AsFloat;
      Inc(N);
      Q.Next;
    end;
    SetLength(ABets, N);
  finally
    Q.Free;
  end;
end;

{ ---------------- pouzdanost ---------------- }

{ 95% interval ROI-ja kad se uzorkuju cijeli klasteri (kolo, sezona); k < 2: nema intervala }
function ClusterInterval(const AProfit, ACount: array of Double; AReps: Integer; out ALo, AHi: Double): Boolean;
var
  K, R, I, J: Integer;
  Rois: array of Double;
  SP, SC: Double;
begin
  K := Length(AProfit);
  Result := K >= 2;
  if not Result then Exit;
  SetLength(Rois, AReps);
  for R := 0 to AReps - 1 do
  begin
    SP := 0; SC := 0;
    for I := 1 to K do
    begin
      J := Random(K);
      SP := SP + AProfit[J]; SC := SC + ACount[J];
    end;
    Rois[R] := SP / SC;
  end;
  SortD(Rois);
  ALo := Pctl(Rois, 2.5); AHi := Pctl(Rois, 97.5);
end;

procedure Clusters(const A: TBets; AUseDate: Boolean; out AProfit, ACount: TDoubleArray);
var
  I, K: Integer;
  Keys: TStringList;
  Key: string;
begin
  Keys := TStringList.Create;
  try
    Keys.CaseSensitive := True; Keys.Sorted := True;
    SetLength(AProfit, 0); SetLength(ACount, 0);
    for I := 0 to High(A) do
    begin
      if AUseDate then Key := A[I].Div_ + #1 + A[I].Season + #1 + A[I].Date else Key := A[I].Div_ + #1 + A[I].Season;
      K := Keys.IndexOf(Key);
      if K < 0 then
      begin
        K := Keys.AddObject(Key, TObject(PtrInt(Length(AProfit))));
        SetLength(AProfit, Length(AProfit) + 1); SetLength(ACount, Length(ACount) + 1);
        AProfit[High(AProfit)] := 0; ACount[High(ACount)] := 0;
        K := Keys.IndexOf(Key);
      end;
      K := PtrInt(Keys.Objects[K]);
      AProfit[K] := AProfit[K] + A[I].Profit;
      ACount[K] := ACount[K] + 1;
    end;
  finally
    Keys.Free;
  end;
end;

function RunReliability(ADb: TAppDb; AReps, ASeed: Integer): Integer;
var
  Bets, G: TBets;
  Tabs: TStringList;
  Systems: TStringList;
  S, I, R, N, J, T: Integer;
  P, Won, Delta, Odds: array of Double;
  Prof, Cnt: TDoubleArray;
  LoK, HiK, LoS, HiS: Double;
  HasK, HasS: Boolean;
  Roi, Obs, Null_, Centre, Dist, SumSim, Tmp: Double;
  Sim, Perm: array of Double;
  CntInfo, CntRoi: Integer;
  PInfo, PRoi: Double;
  Pi: Double;
begin
  Result := 0;
  Tabs := ADb.UserTables;
  try
    if Tabs.IndexOf('backtest_bets') < 0 then Exit;
  finally
    Tabs.Free;
  end;
  LoadBets(ADb, Bets);
  ADb.Conn.ExecuteDirect('DROP TABLE IF EXISTS backtest_pouzdanost');
  ADb.Conn.ExecuteDirect('CREATE TABLE backtest_pouzdanost (system TEXT, n INTEGER, roi REAL, kolo_lo REAL, kolo_hi REAL, sez_lo REAL, sez_hi REAL, p_info REAL, p_roi REAL)');
  RandSeed := ASeed;
  Systems := TStringList.Create;
  try
    Systems.CaseSensitive := True;
    for I := 0 to High(Bets) do if Systems.IndexOf(Bets[I].System) < 0 then Systems.Add(Bets[I].System);
    ADb.Conn.StartTransaction;
    try
      for S := 0 to Systems.Count - 1 do
      begin
        SetLength(G, 0); N := 0;
        SetLength(G, Length(Bets));
        for I := 0 to High(Bets) do if Bets[I].System = Systems[S] then begin G[N] := Bets[I]; Inc(N); end;
        SetLength(G, N);
        if N < 2 then Continue;
        SetLength(P, N); SetLength(Won, N); SetLength(Delta, N); SetLength(Odds, N);
        Roi := 0;
        for I := 0 to N - 1 do
        begin
          P[I] := Min(Max(G[I].Prob, 1e-9), 1.0 - 1e-9);
          if G[I].Won then Won[I] := 1 else Won[I] := 0;
          Odds[I] := G[I].Odds;
          Delta[I] := Ln(P[I]) - Ln(1.0 - P[I]);
          Roi := Roi + G[I].Profit;
        end;
        Roi := Roi / N;
        Clusters(G, True, Prof, Cnt);
        HasK := ClusterInterval(Prof, Cnt, AReps, LoK, HiK);
        Clusters(G, False, Prof, Cnt);
        HasS := ClusterInterval(Prof, Cnt, AReps, LoS, HiS);

        { permutacijski test: ima li vjerojatnosti informaciju o tome tko dobiva osim osnovne stope }
        Obs := 0;
        for I := 0 to N - 1 do Obs := Obs + Won[I] * Delta[I];
        SetLength(Perm, N);
        for I := 0 to N - 1 do Perm[I] := Won[I];
        CntInfo := 0;
        for R := 0 to AReps - 1 do
        begin
          for I := N - 1 downto 1 do
          begin
            J := Random(I + 1);
            Tmp := Perm[I]; Perm[I] := Perm[J]; Perm[J] := Tmp;
          end;
          Null_ := 0;
          for I := 0 to N - 1 do Null_ := Null_ + Perm[I] * Delta[I];
          if Null_ >= Obs then Inc(CntInfo);
        end;
        PInfo := (CntInfo + 1) / (AReps + 1);

        { Monte Carlo uz savrsenu kalibraciju: svaka oklada se ponovno izvuce po svojoj vjerojatnosti }
        SetLength(Sim, AReps);
        SumSim := 0;
        for R := 0 to AReps - 1 do
        begin
          Tmp := 0;
          for I := 0 to N - 1 do if Rnd < P[I] then Tmp := Tmp + Odds[I];
          Sim[R] := Tmp / N - 1.0;
          SumSim := SumSim + Sim[R];
        end;
        Centre := SumSim / AReps;
        Dist := Abs(Roi - Centre);
        CntRoi := 0;
        for R := 0 to AReps - 1 do if Abs(Sim[R] - Centre) >= Dist then Inc(CntRoi);
        PRoi := (CntRoi + 1) / (AReps + 1);

        ADb.Conn.ExecuteDirect('INSERT INTO backtest_pouzdanost VALUES (' + Q_(Systems[S]) + ',' + IntToStr(N) + ',' + F_(Roi) + ',' +
          IfThen(HasK, F_(LoK), 'NULL') + ',' + IfThen(HasK, F_(HiK), 'NULL') + ',' + IfThen(HasS, F_(LoS), 'NULL') + ',' + IfThen(HasS, F_(HiS), 'NULL') + ',' +
          F_(PInfo) + ',' + F_(PRoi) + ')');
        Inc(Result);
      end;
      ADb.Conn.Commit;
    except
      ADb.Conn.Rollback;
      raise;
    end;
  finally
    Systems.Free;
  end;
  Pi := 0;
  if Pi = 1 then Exit;
end;

{ ---------------- progresije ---------------- }

{ ukupna dobit po ponavljanju: sve slijedi Pythonov simulate_progression, jedna replika po petlji }
procedure SimulateProgression(const AProbs, AOdds: array of Double; ARule, AReps: Integer; var ATotals: array of Double; AFrom: Integer);
var
  R, B, FibIdx, Press, SeqStep: Integer;
  Stake, Total, Profit: Double;
  Won, Capped: Boolean;
begin
  for R := 0 to AReps - 1 do
  begin
    Stake := 1.0; Total := 0; FibIdx := 0; Press := 0; SeqStep := 0;
    for B := 0 to High(AProbs) do
    begin
      Won := Rnd < AProbs[B];
      if Won then Profit := Stake * (AOdds[B] - 1.0) else Profit := -Stake;
      Total := Total + Profit;
      case ARule of
        0: ;
        1: if Won then Stake := 1.0 else Stake := Stake * 2.0;
        2: begin
             if Won then FibIdx := Max(FibIdx - 2, 0) else Inc(FibIdx);
             FibIdx := Min(FibIdx, 39);
             Stake := Fib[FibIdx];
           end;
        3: begin
             if Won then FibIdx := Max(FibIdx - 2, 0) else Inc(FibIdx);
             FibIdx := Min(FibIdx, 38);
             Stake := FibAdj[FibIdx];
           end;
        4: if Won then Stake := Stake + Profit else Stake := 1.0;
        5: begin
             if Won then Inc(Press) else Press := 0;
             Capped := Press >= 3;
             if not Won then Stake := 1.0
             else if Capped then Stake := 1.0
             else Stake := Stake + Profit;
             if Capped then Press := 0;
           end;
        6: if Won then Stake := Stake + 1.0 else Stake := 1.0;
        7: if Won then Stake := Max(Stake - 1.0, 1.0) else Stake := Stake + 1.0;
        8: begin
             SeqStep := (SeqStep + 1) mod 4;
             Stake := Seq1324[SeqStep];
           end;
      end;
    end;
    ATotals[AFrom + R] := Total;
  end;
end;

function RunProgression(ADb: TAppDb; AHorizon, AReps, ASeed: Integer): Integer;
var
  Bets, G: TBets;
  Tabs, Seasons, Dates: TStringList;
  S, I, K, R, N, Rule: Integer;
  Probs, Odds: array of Double;
  All: array of Double;
  Total, Neg, Sum: Double;
  Cnt: Integer;
begin
  Result := 0;
  Tabs := ADb.UserTables;
  try
    if Tabs.IndexOf('backtest_bets') < 0 then Exit;
  finally
    Tabs.Free;
  end;
  LoadBets(ADb, Bets);
  ADb.Conn.ExecuteDirect('DROP TABLE IF EXISTS backtest_progresije');
  ADb.Conn.ExecuteDirect('CREATE TABLE backtest_progresije (pravilo TEXT, medijan REAL, prosjek REAL, p5 REAL, p95 REAL, najgore REAL, udio_negativnih REAL, replikacija INTEGER)');
  RandSeed := ASeed;
  Seasons := TStringList.Create;
  Dates := TStringList.Create;
  try
    Seasons.CaseSensitive := True; Seasons.Sorted := True; Seasons.Duplicates := dupIgnore;
    { samo sustav "veliki", kao u Pythonu }
    SetLength(G, 0); N := 0;
    SetLength(G, Length(Bets));
    for I := 0 to High(Bets) do
      if Bets[I].System = 'veliki' then begin G[N] := Bets[I]; Inc(N); Seasons.Add(Bets[I].Season); end;
    SetLength(G, N);
    if N = 0 then Exit;
    for Rule := 0 to High(Rules) do
    begin
      SetLength(All, 0); Cnt := 0;
      for S := 0 to Seasons.Count - 1 do
      begin
        { oklade sezone kronoloski (sezona, datum), stabilno }
        SetLength(Probs, 0); SetLength(Odds, 0);
        Dates.Clear; Dates.Sorted := True; Dates.Duplicates := dupIgnore; Dates.CaseSensitive := True;
        for I := 0 to High(G) do if G[I].Season = Seasons[S] then Dates.Add(G[I].Date);
        K := 0;
        { redoslijed: po datumu, a unutar datuma redoslijed unosa }
        for R := 0 to Dates.Count - 1 do
        begin
          if (AHorizon > 0) and (R >= AHorizon) then Break;
          for I := 0 to High(G) do
            if (G[I].Season = Seasons[S]) and (G[I].Date = Dates[R]) then
            begin
              SetLength(Probs, K + 1); SetLength(Odds, K + 1);
              Probs[K] := G[I].Prob; Odds[K] := G[I].Odds; Inc(K);
            end;
        end;
        if K = 0 then Continue;
        SetLength(All, Cnt + AReps);
        SimulateProgression(Probs, Odds, Rule, AReps, All, Cnt);
        Inc(Cnt, AReps);
      end;
      if Cnt = 0 then Continue;
      Total := 0; Neg := 0; Sum := 0;
      SortD(All);
      for I := 0 to Cnt - 1 do begin Sum := Sum + All[I]; if All[I] < 0 then Neg := Neg + 1; end;
      ADb.Conn.ExecuteDirect('INSERT INTO backtest_progresije VALUES (' + Q_(Rules[Rule]) + ',' + F_(Pctl(All, 50)) + ',' + F_(Sum / Cnt) + ',' + F_(Pctl(All, 5)) + ',' +
        F_(Pctl(All, 95)) + ',' + F_(All[0]) + ',' + F_(Neg / Cnt) + ',' + IntToStr(Cnt) + ')');
      Inc(Result);
    end;
  finally
    Dates.Free; Seasons.Free;
  end;
  Total := 0;
  if Total = 1 then Exit;
end;

function ReliabilityHook(const AName: string; const A: array of Variant; N: Integer): Variant;
var
  Reps, Seed, Horizon: Integer;
begin
  Result := Null;
  if (ActiveDb = nil) or not ActiveDb.Connected then Exit;
  Reps := 2000; Seed := 0; Horizon := 0;
  if AName = 'runreliability' then
  begin
    if (N >= 1) and not VarIsNull(A[0]) then Reps := Trunc(Double(A[0]));
    if (N >= 2) and not VarIsNull(A[1]) then Seed := Trunc(Double(A[1]));
    Result := RunReliability(ActiveDb, Reps, Seed);
  end
  else
  begin
    if (N >= 1) and not VarIsNull(A[0]) then Horizon := Trunc(Double(A[0]));
    if (N >= 2) and not VarIsNull(A[1]) then Reps := Trunc(Double(A[1]));
    if (N >= 3) and not VarIsNull(A[2]) then Seed := Trunc(Double(A[2]));
    Result := RunProgression(ActiveDb, Horizon, Reps, Seed);
  end;
end;

initialization
  InitFib;
  StatsHook := @ReliabilityHook;

end.
