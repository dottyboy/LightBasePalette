unit ta_enginebt;
{ "Vremenska kapsula" backtest SmartBeta (smartbet/backtest/engine.py + metrics.py): sezona jedne lige se igra dan
  po dan, model se ponovno fita svakih N dana (zadano 3) samo na utakmicama prije tog dana, a za svaku utakmicu se
  po svakom trzistu uzme najvjerojatniji izbor i kladi se ako prelazi prag. Oklade se vrednuju po STVARNOJ
  kvoti koju je kladionica ponudila (zatvarajuca kvota, Pinnacle prvi), a tamo gdje je nema po referentnoj
  (ASSUMED_ODDS). Uz to se racunaju skill ocjene (log loss i Brier modela naspram prosjeka lige) nad SVIM
  utakmicama, ne samo onima s okladom. Rezultati idu u tablice engine_tips, engine_summary, engine_curve i
  engine_skill. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Variants, ZDataset, ta_meta, ta_expr, ta_exprdb, ta_predict;

type
  TaEbTip = record
    MatchId: Integer;
    Day: Integer;
    Home, Away, Score, Market, Selection: string;
    Prob, Odds: Double;
    Won, Real: Boolean;
  end;
  TaEbTips = array of TaEbTip;

  TaEbSummary = record
    Market: string;
    Tips, Correct, Real: Integer;
    HitRate, Expected, Gap, BreakEven, Profit, Roi, Odds: Double;
  end;
  TaEbSummaries = array of TaEbSummary;

  TaEbResult = record
    Div_, Season: string;
    Threshold: Double;
    Simulated, Refits, RealPrices: Integer;
    Tips: TaEbTips;                     { redoslijed kao u Pythonu: po danu, pa po trzistu }
    Summary: TaEbSummaries;
    CurveDay: array of Integer;
    CurveProfit, CurveCum: array of Double;
    MaxDrawdown, RealProfit, RealRoi: Double;
    SkillMatches: Integer;
    LogLoss, BaseLogLoss, Brier, BaseBrier: Double;
  end;

function RunEngineBacktest(ADb: TAppDb; const ADiv, ASeason: string; AThreshold: Double; ARefitDays: Integer;
  AStake: Double): TaEbResult;
{ decimalni broj s tockom ili zarezom }
function ParseDot(const S: string; ADefault: Double): Double;
{ upise rezultat u tablice engine_*; vrati broj oklada }
function EngineBacktestToTables(ADb: TAppDb; const ADiv, ASeason: string; AThreshold: Double; ARefitDays: Integer;
  AStake: Double): Integer;
{ ispis za provjeru pariteta s Pythonom (naredba --engine) }
procedure EngineBacktestWriteReport(ADb: TAppDb; const ADiv, ASeason: string; AThreshold: Double; ARefitDays: Integer;
  AStake: Double);

implementation

uses
  ta_i18n;


const
  BtMarkets: array[0..4] of string = ('1X2', 'DOUBLE_CHANCE', 'OVER_UNDER', 'BTTS', 'HTFT');
  PriceOrder: array[0..6] of string = ('PS', 'P', 'Avg', 'B365', 'BW', 'WH', 'Max');

function AssumedOdds(const AMarket: string): Double;
begin
  if AMarket = '1X2' then Result := 1.95
  else if AMarket = 'DOUBLE_CHANCE' then Result := 1.35
  else if AMarket = 'OVER_UNDER' then Result := 1.85
  else if AMarket = 'BTTS' then Result := 1.85
  else if AMarket = 'HTFT' then Result := 5.50
  else Result := 2.0;
end;

function RankOf(const ABook: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(PriceOrder) do
    if PriceOrder[I] = ABook then Exit(I);
  Result := -1;
end;

function DotFs: TFormatSettings;
begin
  Result := DefaultFormatSettings;
  Result.DecimalSeparator := '.';
end;

function ParseDot(const S: string; ADefault: Double): Double;
begin
  Result := StrToFloatDef(StringReplace(Trim(S), ',', '.', []), ADefault, DotFs);
end;

function F_(X: Double): string;
begin
  Result := FloatToStrF(X, ffGeneral, 17, 0, DotFs);
end;

function IfS(ACond: Boolean; const AYes, ANo: string): string;
begin
  if ACond then Result := AYes else Result := ANo;
end;

function Q_(const S: string): string;
begin
  Result := '''' + StringReplace(S, '''', '''''', [rfReplaceAll]) + '''';
end;

{ metrics.settle za trzista koja backtest nudi; ADecided = False kad treba poluvrijeme a nema ga }
function SettleTip(const AMarket, ASel: string; Fthg, Ftag: Integer; const AFtr: string; HasHt: Boolean; Hthg, Htag: Integer;
  out ADecided: Boolean): Boolean;
var
  Total, P: Integer;
  Ht, Ft: string;
  Line: Double;
  Both: Boolean;
begin
  ADecided := True;
  Result := False;
  Total := Fthg + Ftag;
  Both := (Fthg > 0) and (Ftag > 0);
  if AFtr = 'H' then Ft := '1' else if AFtr = 'D' then Ft := 'X' else Ft := '2';
  if AMarket = '1X2' then Exit(ASel = Ft);
  if AMarket = 'DOUBLE_CHANCE' then
  begin
    if ASel = '1X' then Exit((AFtr = 'H') or (AFtr = 'D'));
    if ASel = '12' then Exit((AFtr = 'H') or (AFtr = 'A'));
    Exit((AFtr = 'D') or (AFtr = 'A'));
  end;
  if AMarket = 'OVER_UNDER' then
  begin
    P := Pos(' ', ASel);
    Line := StrToFloat(Copy(ASel, P + 1, MaxInt), DotFs);
    if Copy(ASel, 1, P - 1) = 'Over' then Exit(Total > Line) else Exit(Total < Line);
  end;
  if AMarket = 'BTTS' then
  begin
    if ASel = 'GG' then Exit(Both) else Exit(not Both);
  end;
  if not HasHt then begin ADecided := False; Exit; end;
  if Hthg > Htag then Ht := '1' else if Hthg = Htag then Ht := 'X' else Ht := '2';
  if AMarket = 'HTFT' then Exit(ASel = Ht + '/' + Ft);
  ADecided := False;
end;

type
  TMatch = record
    Id, Day: Integer;
    Home, Away, Ftr: string;
    Fthg, Ftag, Hthg, Htag: Integer;
    HasHt: Boolean;
  end;

function MarketIndex(const AMarket: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(BtMarkets) do
    if BtMarkets[I] = AMarket then Exit(I);
  Result := 99;
end;

function RunEngineBacktest(ADb: TAppDb; const ADiv, ASeason: string; AThreshold: Double; ARefitDays: Integer;
  AStake: Double): TaEbResult;
var
  Q: TZQuery;
  Ms: array of TMatch;
  NM, I, J, K, N, Day, LastFit, Cnt, Mi, Rank, Pi_: Integer;
  Pr: TaPredictor;
  Pred: TaPrediction;
  HaveBundle: Boolean;
  Keys: TStringList;
  PrOdds: array of Double;
  PrRank: array of Integer;
  Key, Mk, BestSel: string;
  Best, Pw1, PwX, Pw2, Sum, Cum, Peak, Prof, OddsV: Double;
  Decided, Won: Boolean;
  Tip: TaEbTip;
  Sk: array of record P: array[0..2] of Double; A: Integer; end;
  NS: Integer;
  Base: array[0..2] of Double;
  Sm: TaEbSummary;
  Used: array of Boolean;
  Tmp: TaEbTip;

  function ItemP(const AMarket, ASel: string; out AP: Double): Boolean;
  var
    L: Integer;
  begin
    Result := False;
    for L := 0 to High(Pred.Items) do
      if (Pred.Items[L].Market = AMarket) and (Pred.Items[L].Selection = ASel) then
      begin
        AP := Pred.Items[L].P;
        Exit(True);
      end;
  end;

begin
  Result.Div_ := ADiv; Result.Season := ASeason; Result.Threshold := AThreshold;
  Result.Simulated := 0; Result.Refits := 0; Result.RealPrices := 0;
  Result.MaxDrawdown := 0; Result.RealProfit := 0; Result.RealRoi := 0; Result.SkillMatches := 0;
  SetLength(Result.Tips, 0); SetLength(Result.Summary, 0);
  SetLength(Result.CurveDay, 0); SetLength(Result.CurveProfit, 0); SetLength(Result.CurveCum, 0);
  NM := 0;
  Q := ADb.NewQuery('SELECT match_id, matchdate, hometeam, awayteam, ftr, fthg, ftag, hthg, htag FROM matches ' +
    'WHERE division = :d AND season = :s ORDER BY matchdate, match_id');
  try
    Q.ParamByName('d').AsString := ADiv; Q.ParamByName('s').AsString := ASeason;
    Q.Open;
    while not Q.Eof do
    begin
      if not (Q.Fields[5].IsNull or Q.Fields[6].IsNull or Q.Fields[4].IsNull) then
      begin
        SetLength(Ms, NM + 1);
        Ms[NM].Id := Q.Fields[0].AsInteger; Ms[NM].Day := DayOfText(Q.Fields[1].AsString);
        Ms[NM].Home := Q.Fields[2].AsString; Ms[NM].Away := Q.Fields[3].AsString; Ms[NM].Ftr := Q.Fields[4].AsString;
        Ms[NM].Fthg := Q.Fields[5].AsInteger; Ms[NM].Ftag := Q.Fields[6].AsInteger;
        Ms[NM].HasHt := not (Q.Fields[7].IsNull or Q.Fields[8].IsNull);
        Ms[NM].Hthg := Q.Fields[7].AsInteger; Ms[NM].Htag := Q.Fields[8].AsInteger;
        Inc(NM);
      end;
      Q.Next;
    end;
  finally
    Q.Free;
  end;
  if NM = 0 then raise Exception.Create(Tr('There are no matches for ') + ADiv + ' ' + ASeason);
  Pr := TaPredictor.Create(ADb);
  Pr.Cfg.LastRoundOn := False;           { engine.py koristi bundle.predict, bez zadnjeg kola }
  N := 0; NS := 0;
  try
    HaveBundle := False; LastFit := 0;
    I := 0;
    while I < NM do
    begin
      Day := Ms[I].Day;
      J := I;
      while (J < NM) and (Ms[J].Day = Day) do Inc(J);
      if (not HaveBundle) or (Day - LastFit >= ARefitDays) then
      begin
        LastFit := Day;
        Inc(Result.Refits);
        HaveBundle := True;
      end;
      for K := I to J - 1 do
      begin
        Inc(Result.Simulated);
        Pred := Pr.Predict(ADiv, Ms[K].Home, Ms[K].Away, LastFit);
        if not Pred.Ok then begin HaveBundle := False; Continue; end;
        if ItemP('1X2', '1', Pw1) and ItemP('1X2', 'X', PwX) and ItemP('1X2', '2', Pw2) then
        begin
          SetLength(Sk, NS + 1);
          Sk[NS].P[0] := Pw1; Sk[NS].P[1] := PwX; Sk[NS].P[2] := Pw2;
          if Ms[K].Ftr = 'H' then Sk[NS].A := 0 else if Ms[K].Ftr = 'D' then Sk[NS].A := 1 else Sk[NS].A := 2;
          Inc(NS);
        end;
        for Mi := 0 to High(BtMarkets) do
        begin
          Mk := BtMarkets[Mi];
          Best := -1; BestSel := '';
          for Cnt := 0 to High(Pred.Items) do
            if (Pred.Items[Cnt].Market = Mk) and (Pred.Items[Cnt].P > Best) then
            begin
              Best := Pred.Items[Cnt].P; BestSel := Pred.Items[Cnt].Selection;
            end;
          if (BestSel = '') or (Best < AThreshold) then Continue;
          Won := SettleTip(Mk, BestSel, Ms[K].Fthg, Ms[K].Ftag, Ms[K].Ftr, Ms[K].HasHt, Ms[K].Hthg, Ms[K].Htag, Decided);
          if not Decided then Continue;
          Tip.MatchId := Ms[K].Id; Tip.Day := Day; Tip.Home := Ms[K].Home; Tip.Away := Ms[K].Away;
          Tip.Score := IntToStr(Ms[K].Fthg) + '-' + IntToStr(Ms[K].Ftag);
          Tip.Market := Mk; Tip.Selection := BestSel; Tip.Prob := Best; Tip.Won := Won;
          Tip.Odds := 0; Tip.Real := False;
          SetLength(Result.Tips, N + 1);
          Result.Tips[N] := Tip;
          Inc(N);
        end;
      end;
      I := J;
    end;
  finally
    Pr.Free;
  end;

  { stvarne kvote: zatvarajuce, prva kladionica po PriceOrder }
  if N > 0 then
  begin
    Keys := TStringList.Create;
    try
      Keys.CaseSensitive := True; Keys.Sorted := True; Keys.Duplicates := dupIgnore;
      Q := ADb.NewQuery('SELECT o.match_id, o.bookmaker, o.market, o.selection, o.odds FROM match_odds o ' +
        'JOIN matches m ON m.match_id = o.match_id WHERE o.closing = 1 AND m.division = :d AND m.season = :s');
      try
        Q.ParamByName('d').AsString := ADiv; Q.ParamByName('s').AsString := ASeason;
        Q.Open;
        while not Q.Eof do
        begin
          Rank := RankOf(Q.Fields[1].AsString);
          if Rank >= 0 then
          begin
            if Q.Fields[2].AsString = '1X2' then Mk := '1X2' else Mk := 'OVER_UNDER';
            Key := IntToStr(Q.Fields[0].AsInteger) + '|' + Mk + '|' + Q.Fields[3].AsString;
            Pi_ := Keys.IndexOf(Key);
            if Pi_ < 0 then
            begin
              Pi_ := Keys.AddObject(Key, TObject(PtrInt(Keys.Count)));
            end;
            Cnt := PtrInt(Keys.Objects[Pi_]);
            if Cnt >= Length(PrOdds) then begin SetLength(PrOdds, Cnt + 1); SetLength(PrRank, Cnt + 1); PrRank[Cnt] := 99; end;
            if Rank < PrRank[Cnt] then begin PrRank[Cnt] := Rank; PrOdds[Cnt] := Q.Fields[4].AsFloat; end;
          end;
          Q.Next;
        end;
      finally
        Q.Free;
      end;
      for I := 0 to N - 1 do
      begin
        Key := IntToStr(Result.Tips[I].MatchId) + '|' + Result.Tips[I].Market + '|' + Result.Tips[I].Selection;
        Pi_ := Keys.IndexOf(Key);
        if Pi_ >= 0 then
        begin
          Result.Tips[I].Odds := PrOdds[PtrInt(Keys.Objects[Pi_])];
          Result.Tips[I].Real := True;
          Inc(Result.RealPrices);
        end
        else Result.Tips[I].Odds := AssumedOdds(Result.Tips[I].Market);
      end;
    finally
      Keys.Free;
    end;
  end;

  { poredak kao u Pythonu: po danu, pa po trzistu (stabilno) }
  for I := 1 to N - 1 do
  begin
    Tmp := Result.Tips[I];
    J := I - 1;
    while (J >= 0) and ((Result.Tips[J].Day > Tmp.Day) or
      ((Result.Tips[J].Day = Tmp.Day) and (CompareStr(Result.Tips[J].Market, Tmp.Market) > 0))) do
    begin
      Result.Tips[J + 1] := Result.Tips[J];
      Dec(J);
    end;
    Result.Tips[J + 1] := Tmp;
  end;

  { sazetak po trzistu (redom prvog pojavljivanja, pa po broju tipova silazno), zatim ALL }
  SetLength(Used, 0);
  for I := 0 to N - 1 do
  begin
    Mi := -1;
    for J := 0 to High(Result.Summary) do
      if Result.Summary[J].Market = Result.Tips[I].Market then Mi := J;
    if Mi < 0 then
    begin
      Mi := Length(Result.Summary);
      SetLength(Result.Summary, Mi + 1);
      Result.Summary[Mi].Market := Result.Tips[I].Market;
      Result.Summary[Mi].Tips := 0; Result.Summary[Mi].Correct := 0; Result.Summary[Mi].Real := 0;
      Result.Summary[Mi].Expected := 0; Result.Summary[Mi].Profit := 0; Result.Summary[Mi].Odds := 0;
    end;
    with Result.Summary[Mi] do
    begin
      Inc(Tips);
      if Result.Tips[I].Won then Inc(Correct);
      if Result.Tips[I].Real then Inc(Real);
      Expected := Expected + Result.Tips[I].Prob;
      Odds := Odds + Result.Tips[I].Odds;
      if Result.Tips[I].Won then Profit := Profit + AStake * (Result.Tips[I].Odds - 1.0) else Profit := Profit - AStake;
    end;
  end;
  for I := 0 to High(Result.Summary) do
    with Result.Summary[I] do
    begin
      Expected := Expected / Tips;
      Odds := Odds / Tips;
      HitRate := Correct / Tips;
      Gap := HitRate - Expected;
      if Correct > 0 then BreakEven := Tips / Correct else BreakEven := Infinity;
      Roi := Profit / (Tips * AStake);
    end;
  for I := 1 to High(Result.Summary) do
  begin
    Sm := Result.Summary[I];
    J := I - 1;
    while (J >= 0) and (Result.Summary[J].Tips < Sm.Tips) do
    begin
      Result.Summary[J + 1] := Result.Summary[J];
      Dec(J);
    end;
    Result.Summary[J + 1] := Sm;
  end;
  if N > 0 then
  begin
    Sm.Market := 'ALL'; Sm.Tips := N; Sm.Correct := 0; Sm.Real := 0; Sm.Expected := 0; Sm.Profit := 0; Sm.Odds := NaN;
    for I := 0 to N - 1 do
    begin
      if Result.Tips[I].Won then Inc(Sm.Correct);
      if Result.Tips[I].Real then Inc(Sm.Real);
      Sm.Expected := Sm.Expected + Result.Tips[I].Prob;
      if Result.Tips[I].Won then Sm.Profit := Sm.Profit + AStake * (Result.Tips[I].Odds - 1.0) else Sm.Profit := Sm.Profit - AStake;
    end;
    Sm.Expected := Sm.Expected / N;
    Sm.HitRate := Sm.Correct / N;
    Sm.Gap := Sm.HitRate - Sm.Expected;
    if Sm.Correct > 0 then Sm.BreakEven := N / Sm.Correct else Sm.BreakEven := Infinity;
    Sm.Roi := Sm.Profit / (N * AStake);
    SetLength(Result.Summary, Length(Result.Summary) + 1);
    Result.Summary[High(Result.Summary)] := Sm;
  end;

  { krivulja dobiti i najveci pad }
  SetLength(Result.CurveDay, N); SetLength(Result.CurveProfit, N); SetLength(Result.CurveCum, N);
  Cum := 0; Peak := 0;
  for I := 0 to N - 1 do
  begin
    if Result.Tips[I].Won then Prof := AStake * (Result.Tips[I].Odds - 1.0) else Prof := -AStake;
    Cum := Cum + Prof;
    Result.CurveDay[I] := Result.Tips[I].Day; Result.CurveProfit[I] := Prof; Result.CurveCum[I] := Cum;
    if I = 0 then Peak := Cum else if Cum > Peak then Peak := Cum;
    if Peak - Cum > Result.MaxDrawdown then Result.MaxDrawdown := Peak - Cum;
  end;
  { izmjereni dio: samo oklade po stvarnoj kvoti (ulog 1 po okladi, kao real_profit u Pythonu) }
  Sum := 0; Cnt := 0;
  for I := 0 to N - 1 do
    if Result.Tips[I].Real then
    begin
      Inc(Cnt);
      if Result.Tips[I].Won then Sum := Sum + (Result.Tips[I].Odds - 1.0) else Sum := Sum - 1.0;
    end;
  Result.RealProfit := Sum;
  if Cnt > 0 then Result.RealRoi := Sum / Cnt;

  { skill ocjene nad svim utakmicama }
  Result.SkillMatches := NS;
  if NS > 0 then
  begin
    for K := 0 to 2 do
    begin
      Cnt := 0;
      for I := 0 to NS - 1 do if Sk[I].A = K then Inc(Cnt);
      Base[K] := Max(Cnt / NS, 1e-6);
    end;
    Result.LogLoss := 0; Result.BaseLogLoss := 0; Result.Brier := 0; Result.BaseBrier := 0;
    for I := 0 to NS - 1 do
    begin
      Result.LogLoss := Result.LogLoss - Ln(Min(Max(Sk[I].P[Sk[I].A], 1e-9), 1.0));
      Result.BaseLogLoss := Result.BaseLogLoss - Ln(Base[Sk[I].A]);
      for K := 0 to 2 do
      begin
        if K = Sk[I].A then OddsV := 1.0 else OddsV := 0.0;
        Result.Brier := Result.Brier + Sqr(Sk[I].P[K] - OddsV);
        Result.BaseBrier := Result.BaseBrier + Sqr(Base[K] - OddsV);
      end;
    end;
    Result.LogLoss := Result.LogLoss / NS; Result.BaseLogLoss := Result.BaseLogLoss / NS;
    Result.Brier := Result.Brier / NS; Result.BaseBrier := Result.BaseBrier / NS;
  end;
end;

function EngineBacktestToTables(ADb: TAppDb; const ADiv, ASeason: string; AThreshold: Double; ARefitDays: Integer;
  AStake: Double): Integer;
var
  R: TaEbResult;
  I: Integer;

  procedure Skill(const AKey: string; AValue: Double);
  begin
    ADb.Conn.ExecuteDirect('INSERT INTO engine_skill VALUES (' + Q_(AKey) + ',' + F_(AValue) + ')');
  end;

begin
  R := RunEngineBacktest(ADb, ADiv, ASeason, AThreshold, ARefitDays, AStake);
  ADb.Conn.ExecuteDirect('DROP TABLE IF EXISTS engine_tips');
  ADb.Conn.ExecuteDirect('DROP TABLE IF EXISTS engine_summary');
  ADb.Conn.ExecuteDirect('DROP TABLE IF EXISTS engine_curve');
  ADb.Conn.ExecuteDirect('DROP TABLE IF EXISTS engine_skill');
  ADb.Conn.ExecuteDirect('CREATE TABLE engine_tips (id INTEGER PRIMARY KEY AUTOINCREMENT, match_id INTEGER, matchdate TEXT, hometeam TEXT, awayteam TEXT, score TEXT, market TEXT, selection TEXT, probability REAL, odds REAL, real_price INTEGER, won INTEGER)');
  ADb.Conn.ExecuteDirect('CREATE TABLE engine_summary (market TEXT, tips INTEGER, correct INTEGER, hit_rate REAL, expected REAL, calibration_gap REAL, break_even REAL, real INTEGER, profit REAL, roi REAL, odds REAL)');
  ADb.Conn.ExecuteDirect('CREATE TABLE engine_curve (matchdate TEXT, profit REAL, cumulative REAL)');
  ADb.Conn.ExecuteDirect('CREATE TABLE engine_skill (name TEXT, value REAL)');
  ADb.Conn.StartTransaction;
  try
    for I := 0 to High(R.Tips) do
      ADb.Conn.ExecuteDirect('INSERT INTO engine_tips (match_id, matchdate, hometeam, awayteam, score, market, selection, probability, odds, real_price, won) VALUES (' +
        IntToStr(R.Tips[I].MatchId) + ',' + Q_(FormatDateTime('yyyy-mm-dd', R.Tips[I].Day)) + ',' + Q_(R.Tips[I].Home) + ',' + Q_(R.Tips[I].Away) + ',' +
        Q_(R.Tips[I].Score) + ',' + Q_(R.Tips[I].Market) + ',' + Q_(R.Tips[I].Selection) + ',' + F_(R.Tips[I].Prob) + ',' + F_(R.Tips[I].Odds) + ',' +
        IntToStr(Ord(R.Tips[I].Real)) + ',' + IntToStr(Ord(R.Tips[I].Won)) + ')');
    for I := 0 to High(R.Summary) do
      with R.Summary[I] do
        ADb.Conn.ExecuteDirect('INSERT INTO engine_summary VALUES (' + Q_(Market) + ',' + IntToStr(Tips) + ',' + IntToStr(Correct) + ',' + F_(HitRate) + ',' +
          F_(Expected) + ',' + F_(Gap) + ',' + IfS(IsInfinite(BreakEven), 'NULL', F_(BreakEven)) + ',' + IntToStr(Real) + ',' + F_(Profit) + ',' +
          F_(Roi) + ',' + IfS(IsNan(Odds), 'NULL', F_(Odds)) + ')');
    for I := 0 to High(R.CurveDay) do
      ADb.Conn.ExecuteDirect('INSERT INTO engine_curve VALUES (' + Q_(FormatDateTime('yyyy-mm-dd', R.CurveDay[I])) + ',' + F_(R.CurveProfit[I]) + ',' + F_(R.CurveCum[I]) + ')');
    Skill('matches', R.SkillMatches); Skill('log_loss', R.LogLoss); Skill('baseline_log_loss', R.BaseLogLoss);
    Skill('brier', R.Brier); Skill('baseline_brier', R.BaseBrier);
    Skill('simulated', R.Simulated); Skill('refits', R.Refits); Skill('real_prices', R.RealPrices);
    Skill('max_drawdown', R.MaxDrawdown); Skill('real_profit', R.RealProfit); Skill('real_roi', R.RealRoi);
    ADb.Conn.Commit;
  except
    ADb.Conn.Rollback;
    raise;
  end;
  Result := Length(R.Tips);
end;

procedure EngineBacktestWriteReport(ADb: TAppDb; const ADiv, ASeason: string; AThreshold: Double; ARefitDays: Integer;
  AStake: Double);
var
  R: TaEbResult;
  I: Integer;
begin
  R := RunEngineBacktest(ADb, ADiv, ASeason, AThreshold, ARefitDays, AStake);
  for I := 0 to High(R.Tips) do
    WriteLn('TIP;', R.Tips[I].MatchId, ';', FormatDateTime('yyyy-mm-dd', R.Tips[I].Day), ';', R.Tips[I].Market, ';', R.Tips[I].Selection, ';',
      F_(R.Tips[I].Prob), ';', F_(R.Tips[I].Odds), ';', Ord(R.Tips[I].Real), ';', Ord(R.Tips[I].Won));
  for I := 0 to High(R.Summary) do
    with R.Summary[I] do
      WriteLn('SUM;', Market, ';', Tips, ';', Correct, ';', F_(HitRate), ';', F_(Expected), ';', Real, ';', F_(Profit), ';', F_(Roi));
  WriteLn('CURVE;', Length(R.CurveCum), ';', F_(R.MaxDrawdown), ';', F_(R.RealProfit), ';', F_(R.RealRoi));
  WriteLn('SKILL;', R.SkillMatches, ';', F_(R.LogLoss), ';', F_(R.BaseLogLoss), ';', F_(R.Brier), ';', F_(R.BaseBrier));
  WriteLn('META;', R.Simulated, ';', R.Refits, ';', R.RealPrices);
end;

function EngineHookImpl(const AName: string; const A: array of Variant; N: Integer): Variant;
var
  Thr: Double;
  Refit: Integer;
  Tabs: TStringList;
begin
  Result := Null;
  if (ActiveDb = nil) or not ActiveDb.Connected then Exit;
  Tabs := ActiveDb.UserTables;
  try
    if Tabs.IndexOf('matches') < 0 then Exit(0);
  finally
    Tabs.Free;
  end;
  Thr := 0.75; Refit := 3;
  if (N >= 3) and not VarIsNull(A[2]) then Thr := Double(A[2]);
  if (N >= 4) and not VarIsNull(A[3]) then Refit := Max(1, Trunc(Double(A[3])));
  Result := EngineBacktestToTables(ActiveDb, UpperCase(Trim(VarToStr(A[0]))), Trim(VarToStr(A[1])), Thr, Refit, 1.0);
end;

initialization
  EngineBacktestHook := @EngineHookImpl;

end.
