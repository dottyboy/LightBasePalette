unit ta_backtest;
{ Standardni backtest SmartBeta (smartbet/backtest/standard.py): hod kroz cijele sezone, model se fita jednom
  na pocetku sezone iz utakmica prije nje (isto kao zivo predvidanje), svaka utakmica se kladi po fer kvoti
  (1 / vjerojatnost) za svaki sustav, a banka se vodi kronoloski. Deterministicki dio (hod, sazetci, banka,
  preživljavanje po sezonama) daje iste brojke kao Python; Monte Carlo dio (rizik propasti) koristi vlastiti
  generator, pa se podudara statisticki, ne brojku po brojku. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Variants, ZDataset, ta_meta, ta_expr, ta_exprdb, ta_predict, ta_slipgen;

const
  BtSystems: array[0..9] of string = ('veliki', 'drugi', 'treci', 'mjesoviti', 'prag65', 'prag75', 'prag85', 'prag95',
    'prijelazi', 'poluvrijeme');
  BtStartingBankroll = 150.0;

type
  TaBtRow = record
    System, Div_, Season, MatchDate, Market, Selection: string;
    MatchId: Integer;
    Prob, FairOdds, Profit: Double;
    Won: Boolean;
  end;
  TaBtRows = array of TaBtRow;

  TaBtSummary = record
    System: string;
    N: Integer;
    FairP, Hit, Roi, Gap: Double;
  end;
  TaBtSummaries = array of TaBtSummary;

  TaBtBank = record
    System: string;
    Start, EndV, MaxDdPct: Double;
    RuinedAt: string;
    Wins, Losses: Integer;
    SeasonsSurvived, SeasonsTotal: Integer;
    BestSeason, WorstSeason: string;
    BestEnd, WorstEnd: Double;
  end;
  TaBtBanks = array of TaBtBank;

  TaBtSeasonEnd = record
    System, Season: string;
    EndV: Double;
  end;
  TaBtSeasonEnds = array of TaBtSeasonEnd;

  TaBtRuin = record
    System: string;
    Length: Integer;
    Ruin, Median, P5, P95, BelowStart: Double;
  end;
  TaBtRuins = array of TaBtRuin;

{ AMarkets: popis dopustenih trzista odvojen zarezom, prazno = sva; AModel: poisson (zadano) ili newton }
function BtWalk(ADb: TAppDb; const ADivs: array of string; ADepth: Integer; const AMarkets: string = ''; const AModel: string = ''): TaBtRows;
function BtSummaries(const ARows: TaBtRows): TaBtSummaries;
{ ACombo > 1: listici od ACombo uzastopnih parova istog sustava (kao group_into_combos) }
function BtBanks(const ARows: TaBtRows; ACombo: Integer; AStart: Double; out ASeasonEnds: TaBtSeasonEnds): TaBtBanks;
function BtRuinReport(const ARows: TaBtRows; AStart, AStake: Double; AReps, ASeed: Integer): TaBtRuins;
{ upise rezultate u tablice backtest_bets, backtest_summary, backtest_bankroll, backtest_seasons, backtest_ruin }
function BtRunToTables(ADb: TAppDb; const ADivs: array of string; ADepth, ACombo: Integer; AStart: Double;
  const AMarkets: string; AWithRuin: Boolean; const AModel: string = ''): Integer;
{ ispis za provjeru pariteta s Pythonom (naredba --backtest) }
procedure BtWriteReport(ADb: TAppDb; const ADivs: array of string; ADepth, ACombo: Integer; AStart, AStake: Double;
  const AModel: string = '');

implementation

type
  TPick = record
    Ok: Boolean;
    Market, Selection: string;
    Prob: Double;
  end;

function SeasonGuess(AToday: TDateTime): string;
var
  Y, M, D: Word;
  S: Integer;
begin
  DecodeDate(AToday, Y, M, D);
  if M >= 7 then S := Y else S := Y - 1;
  Result := Format('%d-%d', [S, S + 1]);
end;

function MarketAllowed(const AList, AMarket: string): Boolean;
begin
  Result := (AList = '') or (Pos(',' + AMarket + ',', ',' + AList + ',') > 0);
end;

{ best_per_market: najvjerojatniji izbor svakog trzista, poredano po vjerojatnosti (stabilno) }
procedure BestPerMarket(const P: TaPrediction; const AAllowed: string; out AList: array of TPick; out ACount: Integer);
var
  I, J, K: Integer;
  Seen: TStringList;
  Best: TPick;
  T: TPick;
begin
  ACount := 0;
  Seen := TStringList.Create;
  try
    for I := 0 to High(P.Items) do
    begin
      if Seen.IndexOf(P.Items[I].Market) >= 0 then Continue;
      Seen.Add(P.Items[I].Market);
      Best.Ok := True; Best.Market := P.Items[I].Market; Best.Selection := P.Items[I].Selection; Best.Prob := P.Items[I].P;
      for J := I + 1 to High(P.Items) do
        if (P.Items[J].Market = Best.Market) and (P.Items[J].P > Best.Prob) then
        begin
          Best.Selection := P.Items[J].Selection; Best.Prob := P.Items[J].P;
        end;
      if not MarketAllowed(AAllowed, Best.Market) then Continue;
      AList[ACount] := Best; Inc(ACount);
    end;
  finally
    Seen.Free;
  end;
  { stabilno, padajuce }
  for I := 1 to ACount - 1 do
  begin
    T := AList[I];
    K := I - 1;
    while (K >= 0) and (AList[K].Prob < T.Prob) do begin AList[K + 1] := AList[K]; Dec(K); end;
    AList[K + 1] := T;
  end;
end;

{ prediction.tips(threshold)[0] uz filter trzista: prvi s najvecom vjerojatnoscu (ravnopravni: prvi po redu) }
function TopTip(const P: TaPrediction; AThr: Double; const AAllowed: string; out APick: TPick): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(P.Items) do
  begin
    if P.Items[I].P < AThr then Continue;
    if not MarketAllowed(AAllowed, P.Items[I].Market) then Continue;
    if (not Result) or (P.Items[I].P > APick.Prob) then
    begin
      APick.Ok := True; APick.Market := P.Items[I].Market; APick.Selection := P.Items[I].Selection; APick.Prob := P.Items[I].P;
      Result := True;
    end;
  end;
end;

function PickFor(const ASystem: string; const P: TaPrediction; AMatchIndex: Integer; const AAllowed: string;
  AGen: TaSlipGen; ABase: TObject): TPick;
var
  List: array[0..15] of TPick;
  N, Rank: Integer;
  Sel: string;
  Prob, Lift: Double;
begin
  Result.Ok := False;
  if ASystem = 'prijelazi' then
  begin
    if not MarketAllowed(AAllowed, 'HTFT') then Exit;
    if not AGen.BestTransition(P, ABase, TransitionDefaultMin, Sel, Prob, Lift) then Exit;
    Result.Ok := True; Result.Market := 'HTFT'; Result.Selection := Sel; Result.Prob := Prob;
    Exit;
  end;
  if ASystem = 'poluvrijeme' then
  begin
    if not MarketAllowed(AAllowed, 'HT_OR_FT') then Exit;
    if not AGen.BestEither(P, False, Sel, Prob) then Exit;
    Result.Ok := True; Result.Market := 'HT_OR_FT'; Result.Selection := Sel; Result.Prob := Prob;
    Exit;
  end;
  if (ASystem = 'veliki') or (ASystem = 'drugi') or (ASystem = 'treci') or (ASystem = 'mjesoviti') then
  begin
    BestPerMarket(P, AAllowed, List, N);
    if ASystem = 'veliki' then Rank := 0
    else if ASystem = 'drugi' then Rank := 1
    else if ASystem = 'treci' then Rank := 2
    else Rank := AMatchIndex mod 3;     { MIXED_PATTERN = (0, 1, 2) }
    if Rank >= N then Exit;
    Result := List[Rank];
    Exit;
  end;
  if ASystem = 'prag65' then begin TopTip(P, 0.65, AAllowed, Result); Exit; end;
  if ASystem = 'prag75' then begin TopTip(P, 0.75, AAllowed, Result); Exit; end;
  if ASystem = 'prag85' then begin TopTip(P, 0.85, AAllowed, Result); Exit; end;
  if ASystem = 'prag95' then begin TopTip(P, 0.95, AAllowed, Result); Exit; end;
end;

{ settle(market, selection, row): Won, a Decided=False kad treba poluvrijeme a nema ga }
function Settle(const AMarket, ASel: string; AFt, AFa: Integer; const AFtr: string; AHasHt: Boolean; AHt, AHa: Integer;
  out ADecided: Boolean): Boolean;
var
  Total: Integer;
  HtR, FtR, Line: string;
  L: Double;
  P: Integer;
begin
  ADecided := True;
  Result := False;
  Total := AFt + AFa;
  if AFtr = 'H' then FtR := '1' else if AFtr = 'D' then FtR := 'X' else FtR := '2';
  if AMarket = '1X2' then Exit(ASel = FtR);
  if AMarket = 'DOUBLE_CHANCE' then
  begin
    if ASel = '1X' then Exit((AFtr = 'H') or (AFtr = 'D'));
    if ASel = '12' then Exit((AFtr = 'H') or (AFtr = 'A'));
    Exit((AFtr = 'D') or (AFtr = 'A'));
  end;
  if AMarket = 'OVER_UNDER' then
  begin
    P := Pos(' ', ASel);
    Line := Copy(ASel, P + 1, MaxInt);
    L := StrToFloat(StringReplace(Line, '.', DefaultFormatSettings.DecimalSeparator, []));
    if Copy(ASel, 1, 4) = 'Over' then Exit(Total > L) else Exit(Total < L);
  end;
  if AMarket = 'BTTS' then
  begin
    if (AFt > 0) and (AFa > 0) then Exit(ASel = 'GG') else Exit(ASel <> 'GG');
  end;
  if not AHasHt then begin ADecided := False; Exit; end;
  if AHt > AHa then HtR := '1' else if AHt = AHa then HtR := 'X' else HtR := '2';
  if AMarket = 'HTFT' then Exit(ASel = HtR + '/' + FtR);
  if AMarket = 'HT_OR_FT' then Exit((ASel = HtR) or (ASel = FtR));
  ADecided := False;
end;

function BtWalk(ADb: TAppDb; const ADivs: array of string; ADepth: Integer; const AMarkets: string; const AModel: string): TaBtRows;
var
  Pr: TaPredictor;
  Gen: TaSlipGen;
  Rows: TaBtRows;
  N, D, S, I, K, MatchIndex, StartDay, Cnt: Integer;
  Complete: TStringList;
  Q: TZQuery;
  Guess, Season, Div_: string;
  Base: TObject;
  Pred: TaPrediction;
  Pick: TPick;
  Won, Decided: Boolean;
  Odds: Double;
  Mrows: array of record Id: Integer; Dt, Home, Away, Ftr: string; Fthg, Ftag, Hthg, Htag: Integer; HasHt: Boolean; end;
begin
  N := 0;
  SetLength(Rows, 0);
  Guess := SeasonGuess(Date);
  Pr := TaPredictor.Create(ADb);
  Pr.SetModel(AModel);
  Pr.Cfg.LastRoundOn := False;           { standardni backtest ne primjenjuje zadnje kolo }
  Gen := TaSlipGen.Create(ADb, Pr);
  Complete := TStringList.Create;
  try
    for D := 0 to High(ADivs) do
    begin
      Div_ := ADivs[D];
      { sezone s svim rezultatima, najstarija prva }
      Complete.Clear;
      Q := ADb.NewQuery('SELECT season, SUM(CASE WHEN ftr IS NULL THEN 1 ELSE 0 END), COUNT(*) FROM matches WHERE division = :d GROUP BY season ORDER BY season');
      try
        Q.ParamByName('d').AsString := Div_;
        Q.Open;
        while not Q.Eof do
        begin
          if (Q.Fields[0].AsString <> Guess) and (Q.Fields[1].AsInteger = 0) and (Q.Fields[2].AsInteger > 0) then
            Complete.Add(Q.Fields[0].AsString);
          Q.Next;
        end;
      finally
        Q.Free;
      end;
      Complete.CaseSensitive := True;
      I := 0;
      if (ADepth > 0) and (Complete.Count > ADepth) then I := Complete.Count - ADepth;
      for S := I to Complete.Count - 1 do
      begin
        Season := Complete[S];
        { utakmice sezone kronoloski }
        SetLength(Mrows, 0);
        Cnt := 0;
        Q := ADb.NewQuery('SELECT match_id, matchdate, hometeam, awayteam, ftr, fthg, ftag, hthg, htag FROM matches ' +
          'WHERE division = :d AND season = :s ORDER BY matchdate, match_id');
        try
          Q.ParamByName('d').AsString := Div_;
          Q.ParamByName('s').AsString := Season;
          Q.Open;
          while not Q.Eof do
          begin
            SetLength(Mrows, Cnt + 1);
            Mrows[Cnt].Id := Q.Fields[0].AsInteger; Mrows[Cnt].Dt := Q.Fields[1].AsString;
            Mrows[Cnt].Home := Q.Fields[2].AsString; Mrows[Cnt].Away := Q.Fields[3].AsString;
            Mrows[Cnt].Ftr := Q.Fields[4].AsString; Mrows[Cnt].Fthg := Q.Fields[5].AsInteger; Mrows[Cnt].Ftag := Q.Fields[6].AsInteger;
            Mrows[Cnt].HasHt := (not Q.Fields[7].IsNull) and (not Q.Fields[8].IsNull);
            Mrows[Cnt].Hthg := Q.Fields[7].AsInteger; Mrows[Cnt].Htag := Q.Fields[8].AsInteger;
            Inc(Cnt);
            Q.Next;
          end;
        finally
          Q.Free;
        end;
        if Cnt = 0 then Continue;
        StartDay := DayOfText(Mrows[0].Dt);
        Base := Gen.BaseRatesWindow(Div_, StartDay - 5 * 365, StartDay);
        try
          for MatchIndex := 0 to Cnt - 1 do
          begin
            Pred := Pr.Predict(Div_, Mrows[MatchIndex].Home, Mrows[MatchIndex].Away, StartDay);
            if not Pred.Ok then Continue;
            for K := 0 to High(BtSystems) do
            begin
              Pick := PickFor(BtSystems[K], Pred, MatchIndex, AMarkets, Gen, Base);
              if not Pick.Ok then Continue;
              Won := Settle(Pick.Market, Pick.Selection, Mrows[MatchIndex].Fthg, Mrows[MatchIndex].Ftag, Mrows[MatchIndex].Ftr,
                Mrows[MatchIndex].HasHt, Mrows[MatchIndex].Hthg, Mrows[MatchIndex].Htag, Decided);
              if not Decided then Continue;
              if N >= Length(Rows) then SetLength(Rows, Max(1024, Length(Rows) * 2));
              Odds := 1.0 / Pick.Prob;
              Rows[N].System := BtSystems[K]; Rows[N].Div_ := Div_; Rows[N].Season := Season;
              Rows[N].MatchDate := Mrows[MatchIndex].Dt; Rows[N].MatchId := Mrows[MatchIndex].Id;
              Rows[N].Market := Pick.Market; Rows[N].Selection := Pick.Selection;
              Rows[N].Prob := Pick.Prob; Rows[N].FairOdds := Odds; Rows[N].Won := Won;
              if Won then Rows[N].Profit := 1.0 * (Odds - 1.0) else Rows[N].Profit := -1.0;
              Inc(N);
            end;
          end;
        finally
          Base.Free;
        end;
      end;
    end;
    SetLength(Rows, N);
    Result := Rows;
  finally
    Complete.Free; Gen.Free; Pr.Free;
  end;
end;

function SystemIndex(const AName: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(BtSystems) do if BtSystems[I] = AName then Exit(I);
  Result := 999;
end;

function BtSummaries(const ARows: TaBtRows): TaBtSummaries;
var
  K, I, N, Wins: Integer;
  SP, SPr: Double;
begin
  SetLength(Result, 0);
  for K := 0 to High(BtSystems) do
  begin
    N := 0; Wins := 0; SP := 0; SPr := 0;
    for I := 0 to High(ARows) do
      if ARows[I].System = BtSystems[K] then
      begin
        Inc(N); if ARows[I].Won then Inc(Wins);
        SP := SP + ARows[I].Prob; SPr := SPr + ARows[I].Profit;
      end;
    if N = 0 then Continue;
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)].System := BtSystems[K];
    Result[High(Result)].N := N;
    Result[High(Result)].FairP := SP / N;
    Result[High(Result)].Hit := Wins / N;
    Result[High(Result)].Roi := SPr / N;
    Result[High(Result)].Gap := Wins / N - SP / N;
  end;
end;

{ ---------------- banka ---------------- }

type
  TIdx = array of Integer;

{ indeksi redaka jednog sustava, poredani po datumu (stabilno) }
function SystemRowsByDate(const ARows: TaBtRows; const ASystem: string): TIdx;
var
  I, J, N, T: Integer;
begin
  N := 0;
  SetLength(Result, Length(ARows));
  for I := 0 to High(ARows) do if ARows[I].System = ASystem then begin Result[N] := I; Inc(N); end;
  SetLength(Result, N);
  for I := 1 to N - 1 do
  begin
    T := Result[I];
    J := I - 1;
    while (J >= 0) and (ARows[Result[J]].MatchDate > ARows[T].MatchDate) do begin Result[J + 1] := Result[J]; Dec(J); end;
    Result[J + 1] := T;
  end;
end;

function SystemRowsBySeasonDate(const ARows: TaBtRows; const ASystem: string): TIdx;
var
  I, J, N, T: Integer;
begin
  N := 0;
  SetLength(Result, Length(ARows));
  for I := 0 to High(ARows) do if ARows[I].System = ASystem then begin Result[N] := I; Inc(N); end;
  SetLength(Result, N);
  for I := 1 to N - 1 do
  begin
    T := Result[I];
    J := I - 1;
    while (J >= 0) and ((ARows[Result[J]].Season > ARows[T].Season) or
      ((ARows[Result[J]].Season = ARows[T].Season) and (ARows[Result[J]].MatchDate > ARows[T].MatchDate))) do
    begin Result[J + 1] := Result[J]; Dec(J); end;
    Result[J + 1] := T;
  end;
end;

{ group_into_combos: uzastopni parovi (po sezoni, datumu) u listice od ASize; ostatak se odbacuje }
function MakeCombos(const ARows: TaBtRows; const ASystem: string; ASize: Integer): TaBtRows;
var
  Ix: TIdx;
  I, J, NFull, Last: Integer;
  Odds, Pr: Double;
  AllWon: Boolean;
begin
  SetLength(Result, 0);
  Ix := SystemRowsBySeasonDate(ARows, ASystem);
  NFull := Length(Ix) div ASize;
  SetLength(Result, NFull);
  for I := 0 to NFull - 1 do
  begin
    Odds := 1.0; Pr := 1.0; AllWon := True;
    for J := 0 to ASize - 1 do
    begin
      Odds := Odds * ARows[Ix[I * ASize + J]].FairOdds;
      Pr := Pr * ARows[Ix[I * ASize + J]].Prob;
      if not ARows[Ix[I * ASize + J]].Won then AllWon := False;
    end;
    Last := Ix[I * ASize + ASize - 1];
    Result[I].System := ASystem; Result[I].Season := ARows[Last].Season; Result[I].MatchDate := ARows[Last].MatchDate;
    Result[I].FairOdds := Odds; Result[I].Prob := Pr; Result[I].Won := AllWon;
    if AllWon then Result[I].Profit := ASize * (Odds - 1.0) else Result[I].Profit := -ASize;
  end;
end;

function BtBanks(const ARows: TaBtRows; ACombo: Integer; AStart: Double; out ASeasonEnds: TaBtSeasonEnds): TaBtBanks;
var
  K, I, J, N, NE, Q2, Tm: Integer;
  Src: TaBtRows;
  Ix: TIdx;
  Bank, Peak, Dd: Double;
  Ruined: string;
  Wins, Losses: Integer;
  Seasons: TStringList;
  Survived, RuinedN: Integer;
  Broke: Boolean;
  BestV, WorstV: Double;
  BestS, WorstS: string;
  SeasonName: string;
begin
  SetLength(Result, 0);
  SetLength(ASeasonEnds, 0);
  NE := 0;
  for K := 0 to High(BtSystems) do
  begin
    if ACombo > 1 then Src := MakeCombos(ARows, BtSystems[K], ACombo)
    else
    begin
      N := 0;
      SetLength(Src, Length(ARows));
      for I := 0 to High(ARows) do if ARows[I].System = BtSystems[K] then begin Src[N] := ARows[I]; Inc(N); end;
      SetLength(Src, N);
    end;
    if Length(Src) = 0 then Continue;
    { jedna banka kroz sve redove kronoloski }
    SetLength(Ix, Length(Src));
    for I := 0 to High(Src) do Ix[I] := I;
    for I := 1 to High(Ix) do
    begin
      J := I - 1; N := Ix[I];
      while (J >= 0) and (Src[Ix[J]].MatchDate > Src[N].MatchDate) do begin Ix[J + 1] := Ix[J]; Dec(J); end;
      Ix[J + 1] := N;
    end;
    Bank := AStart; Peak := Bank; Dd := 0; Ruined := ''; Wins := 0; Losses := 0;
    for I := 0 to High(Ix) do
    begin
      if Ruined <> '' then Break;
      if Src[Ix[I]].Won then Inc(Wins) else Inc(Losses);
      Bank := Bank + Src[Ix[I]].Profit;
      if Bank <= 0 then begin Bank := 0; Ruined := Src[Ix[I]].MatchDate; end;
      if Bank > Peak then Peak := Bank;
      if Peak > 0 then Dd := Max(Dd, (Peak - Bank) / Peak);
    end;
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)].System := BtSystems[K]; Result[High(Result)].Start := AStart;
    Result[High(Result)].EndV := Bank; Result[High(Result)].MaxDdPct := Dd; Result[High(Result)].RuinedAt := Ruined;
    Result[High(Result)].Wins := Wins; Result[High(Result)].Losses := Losses;

    { svaka sezona od pocetne banke: preživljavanje }
    Seasons := TStringList.Create;
    try
      Seasons.Sorted := True; Seasons.Duplicates := dupIgnore; Seasons.CaseSensitive := True;
      for I := 0 to High(Src) do Seasons.Add(Src[I].Season);
      Survived := 0; RuinedN := 0; BestV := -1; WorstV := -1; BestS := ''; WorstS := '';
      for J := 0 to Seasons.Count - 1 do
      begin
        SeasonName := Seasons[J];
        { redovi sezone po datumu }
        SetLength(Ix, 0); N := 0;
        for I := 0 to High(Src) do
          if Src[I].Season = SeasonName then begin SetLength(Ix, N + 1); Ix[N] := I; Inc(N); end;
        for I := 1 to High(Ix) do
        begin
          Q2 := I - 1; Tm := Ix[I];
          while (Q2 >= 0) and (Src[Ix[Q2]].MatchDate > Src[Tm].MatchDate) do begin Ix[Q2 + 1] := Ix[Q2]; Dec(Q2); end;
          Ix[Q2 + 1] := Tm;
        end;
        Bank := AStart; Broke := False;
        for I := 0 to High(Ix) do
        begin
          Bank := Bank + Src[Ix[I]].Profit;
          if Bank <= 0 then begin Bank := 0; Broke := True; Break; end;
        end;
        if Broke then Inc(RuinedN) else Inc(Survived);
        if (BestS = '') or (Bank > BestV) then begin BestV := Bank; BestS := SeasonName; end;
        if (WorstS = '') or (Bank < WorstV) then begin WorstV := Bank; WorstS := SeasonName; end;
        SetLength(ASeasonEnds, Length(ASeasonEnds) + 1);
        ASeasonEnds[High(ASeasonEnds)].System := Result[High(Result)].System;
        ASeasonEnds[High(ASeasonEnds)].Season := SeasonName;
        ASeasonEnds[High(ASeasonEnds)].EndV := Bank;
      end;
      Result[High(Result)].SeasonsSurvived := Survived;
      Result[High(Result)].SeasonsTotal := Survived + RuinedN;
      Result[High(Result)].BestSeason := BestS; Result[High(Result)].BestEnd := BestV;
      Result[High(Result)].WorstSeason := WorstS; Result[High(Result)].WorstEnd := WorstV;
    finally
      Seasons.Free;
    end;
  end;
end;

{ ---------------- rizik propasti (Monte Carlo nad stvarnim okladama) ---------------- }

procedure SortDoubles(var A: array of Double);
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

{ numpyjev percentil s linearnom interpolacijom nad sortiranim poljem }
function Percentile(const ASorted: array of Double; APct: Double): Double;
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

function BtRuinReport(const ARows: TaBtRows; AStart, AStake: Double; AReps, ASeed: Integer): TaBtRuins;
var
  K, I, J, N, Len, Rep: Integer;
  Profits: array of Double;
  Ended: array of Double;
  Ruined, Below: Integer;
  W: Double;
  Bad: Boolean;
  Counts: TStringList;
  M: Double;
  SeasonCounts: array of Integer;
begin
  SetLength(Result, 0);
  RandSeed := ASeed;
  for K := 0 to High(BtSystems) do
  begin
    N := 0;
    SetLength(Profits, Length(ARows));
    Counts := TStringList.Create;
    try
      Counts.CaseSensitive := True; Counts.Sorted := True; Counts.Duplicates := dupIgnore;
      for I := 0 to High(ARows) do
        if ARows[I].System = BtSystems[K] then
        begin
          Profits[N] := ARows[I].Profit * AStake; Inc(N);
          Counts.Add(ARows[I].Div_ + '|' + ARows[I].Season);
        end;
      SetLength(Profits, N);
      if N < 2 then Continue;
      { duljina sezone = medijan tipova po (liga, sezona); python groupby("season") u ovom testu grupira samo po sezoni }
      Counts.Clear;
      Counts.Sorted := True; Counts.Duplicates := dupIgnore;
      for I := 0 to High(ARows) do
        if ARows[I].System = BtSystems[K] then Counts.Add(ARows[I].Season);
      SetLength(SeasonCounts, Counts.Count);
      for J := 0 to Counts.Count - 1 do
      begin
        SeasonCounts[J] := 0;
        for I := 0 to High(ARows) do
          if (ARows[I].System = BtSystems[K]) and (ARows[I].Season = Counts[J]) then Inc(SeasonCounts[J]);
      end;
      for I := 1 to High(SeasonCounts) do
      begin
        Len := SeasonCounts[I]; J := I - 1;
        while (J >= 0) and (SeasonCounts[J] > Len) do begin SeasonCounts[J + 1] := SeasonCounts[J]; Dec(J); end;
        SeasonCounts[J + 1] := Len;
      end;
      if Odd(Length(SeasonCounts)) then M := SeasonCounts[Length(SeasonCounts) div 2]
      else M := (SeasonCounts[Length(SeasonCounts) div 2 - 1] + SeasonCounts[Length(SeasonCounts) div 2]) / 2.0;
      Len := Trunc(M);
      if Len < 1 then Continue;
    finally
      Counts.Free;
    end;
    SetLength(Ended, AReps);
    Ruined := 0; Below := 0;
    for Rep := 0 to AReps - 1 do
    begin
      W := AStart; Bad := False;
      for I := 1 to Len do
      begin
        W := W + Profits[Random(N)];
        if W <= 0 then Bad := True;
      end;
      if Bad then Inc(Ruined);
      if W < 0 then W := 0;
      Ended[Rep] := W;
      if W < AStart then Inc(Below);
    end;
    SortDoubles(Ended);
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)].System := BtSystems[K]; Result[High(Result)].Length := Len;
    Result[High(Result)].Ruin := Ruined / AReps; Result[High(Result)].Median := Percentile(Ended, 50);
    Result[High(Result)].P5 := Percentile(Ended, 5); Result[High(Result)].P95 := Percentile(Ended, 95);
    Result[High(Result)].BelowStart := Below / AReps;
  end;
end;

{ ---------------- tablice rezultata ---------------- }

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

function BtRunToTables(ADb: TAppDb; const ADivs: array of string; ADepth, ACombo: Integer; AStart: Double;
  const AMarkets: string; AWithRuin: Boolean; const AModel: string): Integer;
var
  Rows: TaBtRows;
  Sums: TaBtSummaries;
  Banks: TaBtBanks;
  Ends: TaBtSeasonEnds;
  Ruins: TaBtRuins;
  I: Integer;
begin
  Rows := BtWalk(ADb, ADivs, ADepth, AMarkets, AModel);
  Sums := BtSummaries(Rows);
  Banks := BtBanks(Rows, ACombo, AStart, Ends);
  ADb.Conn.ExecuteDirect('DROP TABLE IF EXISTS backtest_bets');
  ADb.Conn.ExecuteDirect('DROP TABLE IF EXISTS backtest_summary');
  ADb.Conn.ExecuteDirect('DROP TABLE IF EXISTS backtest_bankroll');
  ADb.Conn.ExecuteDirect('DROP TABLE IF EXISTS backtest_seasons');
  ADb.Conn.ExecuteDirect('DROP TABLE IF EXISTS backtest_ruin');
  ADb.Conn.ExecuteDirect('CREATE TABLE backtest_bets (id INTEGER PRIMARY KEY AUTOINCREMENT, system TEXT, division TEXT, season TEXT, matchdate TEXT, match_id INTEGER, market TEXT, selection TEXT, probability REAL, fair_odds REAL, won INTEGER, profit REAL)');
  ADb.Conn.ExecuteDirect('CREATE TABLE backtest_summary (system TEXT, n INTEGER, fair_p REAL, hit REAL, gap REAL, roi REAL)');
  ADb.Conn.ExecuteDirect('CREATE TABLE backtest_bankroll (system TEXT, start REAL, ending REAL, ruined_at TEXT, max_drawdown_pct REAL, wins INTEGER, losses INTEGER, seasons_survived INTEGER, seasons_total INTEGER, best_season TEXT, best_end REAL, worst_season TEXT, worst_end REAL)');
  ADb.Conn.ExecuteDirect('CREATE TABLE backtest_seasons (system TEXT, season TEXT, ending REAL)');
  ADb.Conn.ExecuteDirect('CREATE TABLE backtest_ruin (system TEXT, length INTEGER, ruin REAL, median REAL, p5 REAL, p95 REAL, below_start REAL)');
  ADb.Conn.StartTransaction;
  try
    for I := 0 to High(Rows) do
      ADb.Conn.ExecuteDirect('INSERT INTO backtest_bets (system, division, season, matchdate, match_id, market, selection, probability, fair_odds, won, profit) VALUES (' +
        Q_(Rows[I].System) + ',' + Q_(Rows[I].Div_) + ',' + Q_(Rows[I].Season) + ',' + Q_(Rows[I].MatchDate) + ',' + IntToStr(Rows[I].MatchId) + ',' +
        Q_(Rows[I].Market) + ',' + Q_(Rows[I].Selection) + ',' + F_(Rows[I].Prob) + ',' + F_(Rows[I].FairOdds) + ',' +
        IntToStr(Ord(Rows[I].Won)) + ',' + F_(Rows[I].Profit) + ')');
    for I := 0 to High(Sums) do
      ADb.Conn.ExecuteDirect('INSERT INTO backtest_summary VALUES (' + Q_(Sums[I].System) + ',' + IntToStr(Sums[I].N) + ',' + F_(Sums[I].FairP) + ',' +
        F_(Sums[I].Hit) + ',' + F_(Sums[I].Gap) + ',' + F_(Sums[I].Roi) + ')');
    for I := 0 to High(Banks) do
      ADb.Conn.ExecuteDirect('INSERT INTO backtest_bankroll VALUES (' + Q_(Banks[I].System) + ',' + F_(Banks[I].Start) + ',' + F_(Banks[I].EndV) + ',' +
        Q_(Banks[I].RuinedAt) + ',' + F_(Banks[I].MaxDdPct) + ',' + IntToStr(Banks[I].Wins) + ',' + IntToStr(Banks[I].Losses) + ',' +
        IntToStr(Banks[I].SeasonsSurvived) + ',' + IntToStr(Banks[I].SeasonsTotal) + ',' + Q_(Banks[I].BestSeason) + ',' + F_(Banks[I].BestEnd) + ',' +
        Q_(Banks[I].WorstSeason) + ',' + F_(Banks[I].WorstEnd) + ')');
    for I := 0 to High(Ends) do
      ADb.Conn.ExecuteDirect('INSERT INTO backtest_seasons VALUES (' + Q_(Ends[I].System) + ',' + Q_(Ends[I].Season) + ',' + F_(Ends[I].EndV) + ')');
    if AWithRuin then
    begin
      Ruins := BtRuinReport(Rows, AStart, 1.0, 2000, 0);
      for I := 0 to High(Ruins) do
        ADb.Conn.ExecuteDirect('INSERT INTO backtest_ruin VALUES (' + Q_(Ruins[I].System) + ',' + IntToStr(Ruins[I].Length) + ',' + F_(Ruins[I].Ruin) + ',' +
          F_(Ruins[I].Median) + ',' + F_(Ruins[I].P5) + ',' + F_(Ruins[I].P95) + ',' + F_(Ruins[I].BelowStart) + ')');
    end;
    ADb.Conn.Commit;
  except
    ADb.Conn.Rollback;
    raise;
  end;
  Result := Length(Rows);
end;

procedure BtWriteReport(ADb: TAppDb; const ADivs: array of string; ADepth, ACombo: Integer; AStart, AStake: Double;
  const AModel: string);
var
  Rows: TaBtRows;
  Sums: TaBtSummaries;
  Banks: TaBtBanks;
  Ends: TaBtSeasonEnds;
  Ruins: TaBtRuins;
  I: Integer;
begin
  Rows := BtWalk(ADb, ADivs, ADepth, '', AModel);
  for I := 0 to High(Rows) do
    WriteLn('ROW;', Rows[I].System, ';', Rows[I].Div_, ';', Rows[I].Season, ';', Rows[I].MatchDate, ';', Rows[I].MatchId, ';', Rows[I].Market, ';',
      Rows[I].Selection, ';', F_(Rows[I].Prob), ';', F_(Rows[I].FairOdds), ';', Ord(Rows[I].Won), ';', F_(Rows[I].Profit));
  Sums := BtSummaries(Rows);
  for I := 0 to High(Sums) do
    WriteLn('SUM;', Sums[I].System, ';', Sums[I].N, ';', F_(Sums[I].FairP), ';', F_(Sums[I].Hit), ';', F_(Sums[I].Roi));
  Banks := BtBanks(Rows, ACombo, AStart, Ends);
  for I := 0 to High(Banks) do
    WriteLn('BANK;', Banks[I].System, ';', F_(Banks[I].EndV), ';', Banks[I].RuinedAt, ';', F_(Banks[I].MaxDdPct), ';', Banks[I].Wins, ';', Banks[I].Losses, ';',
      Banks[I].SeasonsSurvived, ';', Banks[I].SeasonsTotal, ';', Banks[I].BestSeason, ';', F_(Banks[I].BestEnd), ';', Banks[I].WorstSeason, ';', F_(Banks[I].WorstEnd));
  Ruins := BtRuinReport(Rows, AStart, AStake, 2000, 0);
  for I := 0 to High(Ruins) do
    WriteLn('RUIN;', Ruins[I].System, ';', Ruins[I].Length, ';', F_(Ruins[I].Ruin), ';', F_(Ruins[I].Median), ';', F_(Ruins[I].P5), ';', F_(Ruins[I].P95), ';', F_(Ruins[I].BelowStart));
end;

function BacktestHookImpl(const AName: string; const A: array of Variant; N: Integer): Variant;
var
  Divs: TStringArray;
  Depth, Combo: Integer;
  Start: Double;
  Mk, Model: string;
  I, P: Integer;
  Txt: string;
  Tabs: TStringList;
begin
  Result := Null;
  if (ActiveDb = nil) or not ActiveDb.Connected then Exit;
  { baza bez tablice utakmica nema sto testirati }
  Tabs := ActiveDb.UserTables;
  try
    if Tabs.IndexOf('matches') < 0 then Exit(0);
  finally
    Tabs.Free;
  end;
  Txt := StringReplace(VarToStr(A[0]), ' ', '', [rfReplaceAll]);
  SetLength(Divs, 0);
  while Txt <> '' do
  begin
    P := Pos(',', Txt);
    if P = 0 then P := Length(Txt) + 1;
    SetLength(Divs, Length(Divs) + 1);
    Divs[High(Divs)] := UpperCase(Copy(Txt, 1, P - 1));
    Txt := Copy(Txt, P + 1, MaxInt);
  end;
  if Length(Divs) = 0 then raise EExpr.Create('RunBacktest: navedi barem jednu ligu');
  Depth := 0; Combo := 1; Start := BtStartingBankroll; Mk := ''; Model := '';
  if not VarIsNull(A[1]) then Depth := Trunc(Double(A[1]));
  if (N >= 3) and not VarIsNull(A[2]) then Combo := Max(1, Trunc(Double(A[2])));
  if (N >= 4) and not VarIsNull(A[3]) then Start := Double(A[3]);
  if N >= 5 then Mk := StringReplace(VarToStr(A[4]), ' ', '', [rfReplaceAll]);
  if N >= 6 then Model := VarToStr(A[5]);
  I := BtRunToTables(ActiveDb, Divs, Depth, Combo, Start, Mk, True, Model);
  Result := I;
end;

initialization
  BacktestHook := @BacktestHookImpl;

end.
