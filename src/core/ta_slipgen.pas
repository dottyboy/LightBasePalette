unit ta_slipgen;
{ Generiranje listica: nativna replika sustava iz SMART-BETTING-APP (training.py): prijelazi v1,
  poluvrijeme ili kraj v1, elita v1, miks v1 i top listici v1. Pragovi i pravila su iz config.py,
  redoslijed pickova i prstenasto kombiniranje isti kao u Pythonu, pa se isti krug daje iste listice.
  Utakmice kola citaju se iz tablice "fixtures" (division, matchdate, hometeam, awayteam). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, StrUtils, Variants, ZDataset, ta_meta, ta_expr, ta_exprdb, ta_predict, ta_newton, ta_league, ta_fixtureimport;

type
  TaSuggestion = record
    Div_, Home, Away, MatchDate, Market, Selection: string;
    Prob, Lift: Double;
  end;
  TaSuggestions = array of TaSuggestion;

  TaGenLeg = record
    Div_, Home, Away, Market, Selection: string;
    Prob, Odds: Double;
  end;

  TaGenSlip = record
    Name: string;
    Legs: array of TaGenLeg;
  end;
  TaGenSlips = array of TaGenSlip;

  TaFixture = record
    Div_, Home, Away, MatchDate: string;
  end;
  TaFixtures = array of TaFixture;

const
  TransitionDefaultMin = 0.40;
  TopDefaultPrijelazi = 10;
  TopDefaultPikovi = 5;
  TopDefaultLegs = 4;
  TopDefaultCount = 30;
  TopDefaultMinPrijelazi = 0.40;
  FixtureHorizonDays = 4;
  StaleFixtureWindowDays = 21;
  ElitaStake = 4.0;
  StandardThreshold = 0.75;       { cfg.confidence_threshold }
  HedgeCount = 6;
  HedgeNeed = 4;

type
  TaSlipGen = class
  private
    FDb: TAppDb;
    FPred: TaPredictor;
    FBaseRates: TStringList;      { liga -> TaRates }
    function BaseRates(const ADiv: string): TObject;
  private
    procedure GenStandard(const AFx: TaFixtures; ARef: Integer; AThreshold: Double; var AOut: TaGenSlips);
    procedure GenHedge(const AFx: TaFixtures; ARef: Integer; AMin: Double; var AOut: TaGenSlips);
  public
    { odabir jednog para po utakmici (isti kao u Pythonu); ABase = frekvencije prijelaza lige }
    function BestTransition(const P: TaPrediction; ABase: TObject; AMin: Double; out ASel: string; out AProb, ALift: Double): Boolean;
    function BestEither(const P: TaPrediction; AElita: Boolean; out ASel: string; out AProb: Double): Boolean;
    { htft_base_rates nad utakmicama lige u [AFromDay, AToDay) - za backtest bez zaviranja u buducnost }
    function BaseRatesWindow(const ADiv: string; AFromDay, AToDay: Integer): TObject;
    constructor Create(ADb: TAppDb; APred: TaPredictor);
    destructor Destroy; override;
    function RecommendTransitions(const AFx: TaFixtures; ARef: Integer; AMin: Double): TaSuggestions;
    function RecommendEither(const AFx: TaFixtures; ARef: Integer; AElita: Boolean): TaSuggestions;
    { _ranked: izbor ranga ARank medu svim tržištima osim HT/FT, najvjerojatniji prvi, po jedan po tržištu }
    function RankedLeg(const P: TaPrediction; const F: TaFixture; ARank: Integer; out ALeg: TaGenLeg): Boolean;
    { sustav: prijelazi | poluvrijeme | elita | miks | top | standard | hedge; AUnit i APrefix se vracaju za spremanje }
    function Generate(const ASystem: string; const AFx: TaFixtures; ARef: Integer; AMin: Double;
      out AUnit: Double; out APrefix: string): TaGenSlips;
  end;

function LoadFixtures(ADb: TAppDb; ARef, AHorizon, ACutoffDay: Integer): TaFixtures;
{ sprema listice kao probne (paper); preskace one ciji je isti sadrzaj vec PENDING u istom kolu i sustavu }
function SaveGeneratedSlips(ADb: TAppDb; const ASlips: TaGenSlips; ARef, AToday: Integer; AUnit: Double; const APrefix: string): Integer;
{ predvidanja utakmica kola u tablice kolo_utakmice (jedna utakmica u retku, rangirano po najsigurnijem izboru) i kolo_trzista
  (sva trzista po utakmici); vraca broj utakmica }
function PredictRoundToTables(ADb: TAppDb; ARef, AHorizon: Integer): Integer;
{ ispis listica za provjeru pariteta (naredba --slips) }
procedure WriteGeneratedSlips(ADb: TAppDb; const ASystem, ARef: string; AMin: Double);

implementation

type
  TaRates = class
  public
    R: array[0..8] of Double;
  end;

const
  HtftNames: array[0..8] of string = ('1/1', '1/X', '1/2', 'X/1', 'X/X', 'X/2', '2/1', '2/X', '2/2');
  { TRANSITION_POOL u redoslijedu iz config.py: odabir, min lift, min vjerojatnost, shrink }
  PoolSel: array[0..3] of string = ('X/1', 'X/2', '1/1', '2/2');
  PoolLift: array[0..3] of Double = (1.6, 1.35, 1.15, 1.15);
  PoolMin: array[0..3] of Double = (0.10, 0.10, 0.30, 0.20);
  PoolShrink: array[0..3] of Double = (0.80, 0.83, 0.98, 0.98);
  { TRANSITION_CONFIRM: X/1 -> 1/1, X/2 -> 2/2, 2/2 -> X/2 }

function HtftIndex(const ASel: string): Integer;
var
  I: Integer;
begin
  for I := 0 to 8 do if HtftNames[I] = ASel then Exit(I);
  Result := -1;
end;

function PoolIndex(const ASel: string): Integer;
var
  I: Integer;
begin
  for I := 0 to 3 do if PoolSel[I] = ASel then Exit(I);
  Result := -1;
end;

function ConfirmOf(const ASel: string): string;
begin
  if ASel = 'X/1' then Result := '1/1'
  else if ASel = 'X/2' then Result := '2/2'
  else if ASel = '2/2' then Result := 'X/2'
  else Result := '';
end;

function GetHtft(const P: TaPrediction; out H: array of Double): Boolean;
var
  I, J, N: Integer;
begin
  N := 0;
  for I := 0 to 8 do H[I] := 0;
  for J := 0 to High(P.Items) do
    if P.Items[J].Market = 'HTFT' then
    begin
      I := HtftIndex(P.Items[J].Selection);
      if I >= 0 then begin H[I] := P.Items[J].P; Inc(N); end;
    end;
  Result := N = 9;
end;

constructor TaSlipGen.Create(ADb: TAppDb; APred: TaPredictor);
begin
  FDb := ADb;
  FPred := APred;
  FBaseRates := TStringList.Create;
  FBaseRates.CaseSensitive := True;
end;

destructor TaSlipGen.Destroy;
var
  I: Integer;
begin
  for I := 0 to FBaseRates.Count - 1 do FBaseRates.Objects[I].Free;
  FBaseRates.Free;
  inherited Destroy;
end;

{ htft_base_rates nad zadnjih 5 godina lige (po najnovijoj utakmici u ligi) }
function TaSlipGen.BaseRates(const ADiv: string): TObject;
var
  I, Total, K: Integer;
  Q: TZQuery;
  Counts: array[0..8] of Integer;
  MaxDate, Cutoff, Ht, Ft: string;
  R: TaRates;
begin
  I := FBaseRates.IndexOf(ADiv);
  if I >= 0 then Exit(FBaseRates.Objects[I]);
  R := TaRates.Create;
  for K := 0 to 8 do begin R.R[K] := 0; Counts[K] := 0; end;
  Total := 0;
  Q := FDb.NewQuery('SELECT MAX(matchdate) FROM matches WHERE division = :d');
  try
    Q.ParamByName('d').AsString := ADiv;
    Q.Open;
    MaxDate := Q.Fields[0].AsString;
  finally
    Q.Free;
  end;
  if MaxDate <> '' then
  begin
    Cutoff := FormatDateTime('yyyy-mm-dd', DayOfText(MaxDate) - 5 * 365);
    Q := FDb.NewQuery('SELECT hthg, htag, ftr FROM matches WHERE division = :d AND matchdate >= :c ' +
      'AND hthg IS NOT NULL AND htag IS NOT NULL AND ftr IS NOT NULL');
    try
      Q.ParamByName('d').AsString := ADiv;
      Q.ParamByName('c').AsString := Cutoff;
      Q.Open;
      while not Q.Eof do
      begin
        if Q.Fields[0].AsInteger > Q.Fields[1].AsInteger then Ht := '1'
        else if Q.Fields[0].AsInteger = Q.Fields[1].AsInteger then Ht := 'X' else Ht := '2';
        if Q.Fields[2].AsString = 'H' then Ft := '1' else if Q.Fields[2].AsString = 'D' then Ft := 'X' else Ft := '2';
        K := HtftIndex(Ht + '/' + Ft);
        if K >= 0 then begin Inc(Counts[K]); Inc(Total); end;
        Q.Next;
      end;
    finally
      Q.Free;
    end;
    if Total > 0 then
      for K := 0 to 8 do R.R[K] := Counts[K] / Total;
  end;
  FBaseRates.AddObject(ADiv, R);
  Result := R;
end;

{ htft_base_rates za prozor [AFromDay, AToDay): backtest smije gledati samo prije sezone koju testira }
function TaSlipGen.BaseRatesWindow(const ADiv: string; AFromDay, AToDay: Integer): TObject;
var
  Q: TZQuery;
  Counts: array[0..8] of Integer;
  K, Total: Integer;
  Ht, Ft: string;
  R: TaRates;
begin
  R := TaRates.Create;
  for K := 0 to 8 do begin R.R[K] := 0; Counts[K] := 0; end;
  Total := 0;
  Q := FDb.NewQuery('SELECT hthg, htag, ftr FROM matches WHERE division = :d AND matchdate >= :f AND matchdate < :t ' +
    'AND hthg IS NOT NULL AND htag IS NOT NULL AND ftr IS NOT NULL');
  try
    Q.ParamByName('d').AsString := ADiv;
    Q.ParamByName('f').AsString := FormatDateTime('yyyy-mm-dd', AFromDay);
    Q.ParamByName('t').AsString := FormatDateTime('yyyy-mm-dd', AToDay);
    Q.Open;
    while not Q.Eof do
    begin
      if Q.Fields[0].AsInteger > Q.Fields[1].AsInteger then Ht := '1'
      else if Q.Fields[0].AsInteger = Q.Fields[1].AsInteger then Ht := 'X' else Ht := '2';
      if Q.Fields[2].AsString = 'H' then Ft := '1' else if Q.Fields[2].AsString = 'D' then Ft := 'X' else Ft := '2';
      K := HtftIndex(Ht + '/' + Ft);
      if K >= 0 then begin Inc(Counts[K]); Inc(Total); end;
      Q.Next;
    end;
  finally
    Q.Free;
  end;
  if Total > 0 then
    for K := 0 to 8 do R.R[K] := Counts[K] / Total;
  Result := R;
end;

{ best_transition_pick: najbolji lift u TRANSITION_POOL, X/1 i X/2 (i 2/2) trebaju potvrdu susjeda }
function TaSlipGen.BestTransition(const P: TaPrediction; ABase: TObject; AMin: Double;
  out ASel: string; out AProb, ALift: Double): Boolean;
var
  H: array[0..8] of Double;
  Base: TaRates;
  I, S, J: Integer;
  Lift, BestLift, Prob: Double;
  BestI: Integer;
  Sib: string;

  { _clears_pool_bar: lift ako izbor prelazi svoj prag, inace -1 }
  function Clears(AIdx: Integer): Double;
  var
    Ref, Pr: Double;
    H2: Integer;
  begin
    H2 := HtftIndex(PoolSel[AIdx]);
    Pr := H[H2];
    Ref := Base.R[H2];
    if (Ref = 0) or (Pr < PoolMin[AIdx]) then Exit(-1);
    Result := Pr / Ref;
    if Result < PoolLift[AIdx] then Result := -1;
  end;

begin
  Result := False;
  if not GetHtft(P, H) then Exit;
  Base := TaRates(ABase);
  BestI := -1; BestLift := 0;
  for I := 0 to 3 do
  begin
    Lift := Clears(I);
    if Lift < 0 then Continue;
    Sib := ConfirmOf(PoolSel[I]);
    if Sib <> '' then
    begin
      J := PoolIndex(Sib);
      if Clears(J) < 0 then Continue;
    end;
    if (BestI < 0) or (Lift > BestLift) then begin BestI := I; BestLift := Lift; end;
  end;
  if BestI < 0 then Exit;
  S := HtftIndex(PoolSel[BestI]);
  Prob := H[S] * PoolShrink[BestI];
  if Prob < AMin then Exit;
  ASel := PoolSel[BestI]; AProb := Prob; ALift := BestLift;
  Result := True;
end;

{ best_ht_or_ft_pick / best_elita_pick: "1" i "2" iz HT/FT tablice, veca vjerojatnost pobjeduje }
function TaSlipGen.BestEither(const P: TaPrediction; AElita: Boolean; out ASel: string; out AProb: Double): Boolean;
var
  H: array[0..8] of Double;
  P1, PX, P2, Min1, Min2: Double;
begin
  Result := False;
  if not GetHtft(P, H) then Exit;
  HtOrFt(H, P1, PX, P2);
  if AElita then begin Min1 := 0.75; Min2 := 0.65; end else begin Min1 := 0.65; Min2 := 0.55; end;
  ASel := ''; AProb := 0;
  if P1 >= Min1 then begin ASel := '1'; AProb := P1; end;
  if (P2 >= Min2) and ((ASel = '') or (P2 > AProb)) then begin ASel := '2'; AProb := P2; end;
  Result := ASel <> '';
end;

function TaSlipGen.RecommendTransitions(const AFx: TaFixtures; ARef: Integer; AMin: Double): TaSuggestions;
var
  I, N: Integer;
  Box: TaPredBox;
  Sel: string;
  Prob, Lift: Double;
begin
  N := 0;
  SetLength(Result, Length(AFx));
  for I := 0 to High(AFx) do
  begin
    Box := FPred.PredictCached(AFx[I].Div_, AFx[I].Home, AFx[I].Away, ARef);
    if not Box.Pred.Ok then Continue;
    if not BestTransition(Box.Pred, BaseRates(AFx[I].Div_), AMin, Sel, Prob, Lift) then Continue;
    Result[N].Div_ := AFx[I].Div_; Result[N].Home := AFx[I].Home; Result[N].Away := AFx[I].Away;
    Result[N].MatchDate := AFx[I].MatchDate; Result[N].Market := 'HTFT'; Result[N].Selection := Sel;
    Result[N].Prob := Prob; Result[N].Lift := Lift;
    Inc(N);
  end;
  SetLength(Result, N);
end;

function TaSlipGen.RecommendEither(const AFx: TaFixtures; ARef: Integer; AElita: Boolean): TaSuggestions;
var
  I, N: Integer;
  Box: TaPredBox;
  Sel: string;
  Prob: Double;
begin
  N := 0;
  SetLength(Result, Length(AFx));
  for I := 0 to High(AFx) do
  begin
    Box := FPred.PredictCached(AFx[I].Div_, AFx[I].Home, AFx[I].Away, ARef);
    if not Box.Pred.Ok then Continue;
    if not BestEither(Box.Pred, AElita, Sel, Prob) then Continue;
    Result[N].Div_ := AFx[I].Div_; Result[N].Home := AFx[I].Home; Result[N].Away := AFx[I].Away;
    Result[N].MatchDate := AFx[I].MatchDate; Result[N].Market := 'HT_OR_FT'; Result[N].Selection := Sel;
    Result[N].Prob := Prob; Result[N].Lift := Prob;
    Inc(N);
  end;
  SetLength(Result, N);
end;

{ ---------------- prstenasto kombiniranje (_ring_windows, _combine_picks) ---------------- }

type
  TaWindow = array of Integer;
  TaWindows = array of TaWindow;

function RingWindows(N, ASize: Integer): TaWindows;
var
  Start, Step, K, Cnt: Integer;
  W: TaWindow;
  Seen: TStringList;
  Key: string;
  Sorted: array of Integer;
  I, J, T: Integer;
begin
  SetLength(Result, 0);
  if N < ASize then Exit;
  Seen := TStringList.Create;
  try
    Seen.Sorted := True;
    Cnt := 0;
    for Start := 0 to N - 1 do
    begin
      SetLength(W, ASize);
      for Step := 0 to ASize - 1 do W[Step] := (Start + Step) mod N;
      { kljuc je skup, ne redoslijed }
      SetLength(Sorted, ASize);
      for K := 0 to ASize - 1 do Sorted[K] := W[K];
      for I := 0 to ASize - 2 do
        for J := I + 1 to ASize - 1 do
          if Sorted[J] < Sorted[I] then begin T := Sorted[I]; Sorted[I] := Sorted[J]; Sorted[J] := T; end;
      Key := '';
      for K := 0 to ASize - 1 do Key := Key + IntToStr(Sorted[K]) + ',';
      if Seen.IndexOf(Key) >= 0 then Continue;
      Seen.Add(Key);
      SetLength(Result, Cnt + 1);
      Result[Cnt] := Copy(W);
      Inc(Cnt);
    end;
  finally
    Seen.Free;
  end;
end;

function LegOf(const S: TaSuggestion): TaGenLeg;
begin
  Result.Div_ := S.Div_; Result.Home := S.Home; Result.Away := S.Away;
  Result.Market := S.Market; Result.Selection := S.Selection;
  Result.Prob := S.Prob;
  if S.Prob <> 0 then Result.Odds := 1.0 / S.Prob else Result.Odds := 0.0;
end;

{ stabilno sortiranje po lift-u padajuce (kao Pythonov sorted s key=-lift) }
procedure StableSortBy(var A: TaSuggestions; AByLift: Boolean);
var
  I, J: Integer;
  T: TaSuggestion;
  Ki, Kj: Double;
begin
  for I := 1 to High(A) do
  begin
    T := A[I];
    if AByLift then Ki := T.Lift else Ki := T.Prob;
    J := I - 1;
    while J >= 0 do
    begin
      if AByLift then Kj := A[J].Lift else Kj := A[J].Prob;
      if Kj < Ki then begin A[J + 1] := A[J]; Dec(J); end else Break;
    end;
    A[J + 1] := T;
  end;
end;

function GroupName(const ALabel: string; const AGroup: array of TaSuggestion): string;
var
  I: Integer;
begin
  Result := ALabel + ' - ';
  for I := 0 to High(AGroup) do
  begin
    if I > 0 then Result := Result + ' + ';
    Result := Result + AGroup[I].Home + ' [' + AGroup[I].Div_ + '] (' + AGroup[I].Selection + ')';
  end;
end;

procedure AddSlip(var ASlips: TaGenSlips; const AName: string; const AGroup: array of TaSuggestion);
var
  N, I: Integer;
begin
  N := Length(ASlips);
  SetLength(ASlips, N + 1);
  ASlips[N].Name := AName;
  SetLength(ASlips[N].Legs, Length(AGroup));
  for I := 0 to High(AGroup) do ASlips[N].Legs[I] := LegOf(AGroup[I]);
end;

procedure CombinePicks(const APicks: TaSuggestions; AMaxLegs: Integer; const ALabel: string; var AOut: TaGenSlips);
var
  Ranked: TaSuggestions;
  Size, W, I: Integer;
  Wins: TaWindows;
  Grp: array of TaSuggestion;
begin
  Ranked := Copy(APicks);
  StableSortBy(Ranked, True);
  for Size := 2 to AMaxLegs do
  begin
    Wins := RingWindows(Length(Ranked), Size);
    for W := 0 to High(Wins) do
    begin
      SetLength(Grp, Size);
      for I := 0 to Size - 1 do Grp[I] := Ranked[Wins[W][I]];
      AddSlip(AOut, GroupName(ALabel, Grp), Grp);
    end;
  end;
end;

procedure AddSingles(const APicks: TaSuggestions; const ALabel: string; var AOut: TaGenSlips);
var
  I: Integer;
  G: array[0..0] of TaSuggestion;
begin
  for I := 0 to High(APicks) do
  begin
    G[0] := APicks[I];
    AddSlip(AOut, ALabel + ' - ' + APicks[I].Home + ' - ' + APicks[I].Away + ' [' + APicks[I].Div_ + '] (' + APicks[I].Selection + ')', G);
  end;
end;

function Claimed(const AList: TaSuggestions; const AItem: TaSuggestion): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(AList) do
    if (AList[I].Div_ = AItem.Div_) and (AList[I].Home = AItem.Home) and (AList[I].Away = AItem.Away) then Exit(True);
  Result := False;
end;

{ rank_top: najvjerojatniji pickovi iznad praga, bez vec zauzetih utakmica }
function RankTop(const APicks, AClaimed: TaSuggestions; ACount: Integer; AMin: Double): TaSuggestions;
var
  Ranked: TaSuggestions;
  I, N: Integer;
begin
  SetLength(Ranked, 0);
  N := 0;
  for I := 0 to High(APicks) do
    if APicks[I].Prob >= AMin then
    begin
      SetLength(Ranked, N + 1);
      Ranked[N] := APicks[I];
      Inc(N);
    end;
  StableSortBy(Ranked, False);
  SetLength(Result, 0);
  N := 0;
  for I := 0 to High(Ranked) do
  begin
    if Claimed(AClaimed, Ranked[I]) then Continue;
    SetLength(Result, N + 1);
    Result[N] := Ranked[I];
    Inc(N);
    if N >= ACount then Break;
  end;
end;

function TaSlipGen.RankedLeg(const P: TaPrediction; const F: TaFixture; ARank: Integer; out ALeg: TaGenLeg): Boolean;
var
  Idx: array of Integer;
  I, J, N, T: Integer;
  Seen: TStringList;
  Uniq: array of Integer;
  NU: Integer;
begin
  Result := False;
  N := 0;
  SetLength(Idx, Length(P.Items));
  for I := 0 to High(P.Items) do
    if (P.Items[I].Market <> 'HTFT') and (P.Items[I].P >= 0.08) then begin Idx[N] := I; Inc(N); end;
  SetLength(Idx, N);
  { stabilno, padajuce po vjerojatnosti }
  for I := 1 to N - 1 do
  begin
    T := Idx[I]; J := I - 1;
    while (J >= 0) and (P.Items[Idx[J]].P < P.Items[T].P) do begin Idx[J + 1] := Idx[J]; Dec(J); end;
    Idx[J + 1] := T;
  end;
  Seen := TStringList.Create;
  try
    SetLength(Uniq, N);
    NU := 0;
    for I := 0 to N - 1 do
    begin
      if Seen.IndexOf(P.Items[Idx[I]].Market) >= 0 then Continue;
      Seen.Add(P.Items[Idx[I]].Market);
      Uniq[NU] := Idx[I]; Inc(NU);
    end;
  finally
    Seen.Free;
  end;
  if ARank >= NU then Exit;
  ALeg.Div_ := F.Div_; ALeg.Home := F.Home; ALeg.Away := F.Away;
  ALeg.Market := P.Items[Uniq[ARank]].Market; ALeg.Selection := P.Items[Uniq[ARank]].Selection;
  ALeg.Prob := P.Items[Uniq[ARank]].P; ALeg.Odds := 1.0 / ALeg.Prob;
  Result := True;
end;

procedure AddGenSlip(var ASlips: TaGenSlips; const AName: string; const ALegs: array of TaGenLeg; AMinimum: Integer);
var
  N, I: Integer;
begin
  if Length(ALegs) < AMinimum then Exit;
  N := Length(ASlips);
  SetLength(ASlips, N + 1);
  ASlips[N].Name := AName;
  SetLength(ASlips[N].Legs, Length(ALegs));
  for I := 0 to High(ALegs) do ASlips[N].Legs[I] := ALegs[I];
end;

{ training.generate_slips: "veliki" (najsigurniji izbor svake utakmice iznad praga) i "mjesoviti" (tri uzorka ranga) po 3 utakmice }
procedure TaSlipGen.GenStandard(const AFx: TaFixtures; ARef: Integer; AThreshold: Double; var AOut: TaGenSlips);
const
  Patterns: array[0..2, 0..2] of Integer = ((0, 1, 2), (1, 2, 0), (2, 0, 1));
var
  Fx: TaFixtures;
  Preds: array of TaPrediction;
  N, I, Pi, Start, Pos_, K: Integer;
  Box: TaPredBox;
  Legs: array of TaGenLeg;
  Leg: TaGenLeg;
  Nm: string;
begin
  { utakmice za koje model ima predvidanje, redoslijedom rasporeda }
  N := 0;
  SetLength(Fx, Length(AFx));
  SetLength(Preds, Length(AFx));
  for I := 0 to High(AFx) do
  begin
    Box := FPred.PredictCached(AFx[I].Div_, AFx[I].Home, AFx[I].Away, ARef);
    if not Box.Pred.Ok then Continue;
    Fx[N] := AFx[I]; Preds[N] := Box.Pred; Inc(N);
  end;
  SetLength(Fx, N); SetLength(Preds, N);
  if N = 0 then Exit;

  SetLength(Legs, 0);
  for I := 0 to N - 1 do
    if RankedLeg(Preds[I], Fx[I], 0, Leg) and (Leg.Prob >= AThreshold) then
    begin
      SetLength(Legs, Length(Legs) + 1);
      Legs[High(Legs)] := Leg;
    end;
  AddGenSlip(AOut, 'veliki - najsigurniji izbor na svakoj utakmici', Legs, 3);

  for Pi := 0 to 2 do
  begin
    Start := 0;
    while Start < N do
    begin
      if Min(3, N - Start) >= 2 then
      begin
        SetLength(Legs, 0);
        for Pos_ := 0 to Min(3, N - Start) - 1 do
          if RankedLeg(Preds[Start + Pos_], Fx[Start + Pos_], Patterns[Pi][Pos_ mod 3], Leg) then
          begin
            SetLength(Legs, Length(Legs) + 1);
            Legs[High(Legs)] := Leg;
          end;
        Nm := 'mjesoviti ' + IntToStr(Start div 3 + 1) + ' - uzorak ' + IntToStr(Pi + 1);
        AddGenSlip(AOut, Nm, Legs, 2);
      end;
      Inc(Start, 3);
    end;
  end;
  K := 0;
  if K = 1 then Exit;
end;

{ druga najvjerojatnija selekcija na istoj utakmici (training.alternate_selection): samo HT/FT i poluvrijeme ili kraj }
function AlternateOf(const P: TaPrediction; const AMarket, ASel: string; out AAlt: string; out AProb: Double): Boolean;
var
  Sel: array of string;
  Pr: array of Double;
  H: array[0..8] of Double;
  I, N, Best: Integer;
  P1, PX, P2: Double;
  Names9: array[0..8] of string;
begin
  Result := False;
  Names9[0] := '1/1'; Names9[1] := '1/X'; Names9[2] := '1/2'; Names9[3] := 'X/1'; Names9[4] := 'X/X';
  Names9[5] := 'X/2'; Names9[6] := '2/1'; Names9[7] := '2/X'; Names9[8] := '2/2';
  if not GetHtft(P, H) then Exit;
  N := 0;
  if AMarket = 'HT_OR_FT' then
  begin
    HtOrFt(H, P1, PX, P2);
    SetLength(Sel, 3); SetLength(Pr, 3);
    Sel[0] := '1'; Pr[0] := P1; Sel[1] := 'X'; Pr[1] := PX; Sel[2] := '2'; Pr[2] := P2;
    N := 3;
  end
  else if AMarket = 'HTFT' then
  begin
    SetLength(Sel, 9); SetLength(Pr, 9);
    for I := 0 to 8 do begin Sel[I] := Names9[I]; Pr[I] := H[I]; end;
    N := 9;
  end
  else Exit;
  Best := -1;
  for I := 0 to N - 1 do
  begin
    if Sel[I] = ASel then Continue;
    if (Best < 0) or (Pr[I] > Pr[Best]) then Best := I;
  end;
  if Best < 0 then Exit;
  AAlt := Sel[Best]; AProb := Pr[Best];
  Result := True;
end;

{ stari "hedge v1": k od n nad najboljih n pickova, svaka kombinacija jednom, pa za svaku nogu s alternativom i s tom nogom zamijenjenom }
procedure TaSlipGen.GenHedge(const AFx: TaFixtures; ARef: Integer; AMin: Double; var AOut: TaGenSlips);
var
  Tr, Hf, Pri, Pik, Picks, Nop: TaSuggestions;
  I, J, K, N, Remaining: Integer;
  Prim: array of TaGenLeg;
  Alt: array of TaGenLeg;
  HasAlt: array of Boolean;
  Box: TaPredBox;
  AltSel: string;
  AltP: Double;
  Idx: array[0..9] of Integer;
  Done: Boolean;
  Legs: array of TaGenLeg;

  function NameFor(const AIdx: array of Integer; ASwapped: Integer): string;
  var
    X: Integer;
    L: TaGenLeg;
    Mark: string;
  begin
    Result := 'hedge - ';
    for X := 0 to High(AIdx) do
    begin
      if AIdx[X] = ASwapped then begin L := Alt[AIdx[X]]; Mark := '*'; end
      else begin L := Prim[AIdx[X]]; Mark := ''; end;
      if X > 0 then Result := Result + ' + ';
      Result := Result + L.Home + ' [' + L.Div_ + '] (' + L.Selection + Mark + ')';
    end;
  end;

  procedure EmitCombo(const AIdx: array of Integer);
  var
    X, Sw: Integer;
    Sel: array of Integer;
  begin
    SetLength(Legs, Length(AIdx));
    for X := 0 to High(AIdx) do Legs[X] := Prim[AIdx[X]];
    AddGenSlip(AOut, NameFor(AIdx, -1), Legs, 1);
    for Sw := 0 to High(AIdx) do
    begin
      if not HasAlt[AIdx[Sw]] then Continue;
      SetLength(Legs, Length(AIdx));
      for X := 0 to High(AIdx) do
        if X = Sw then Legs[X] := Alt[AIdx[X]] else Legs[X] := Prim[AIdx[X]];
      AddGenSlip(AOut, NameFor(AIdx, AIdx[Sw]), Legs, 1);
    end;
    SetLength(Sel, 0);
  end;

begin
  Tr := RecommendTransitions(AFx, ARef, AMin);
  Hf := RecommendEither(AFx, ARef, False);
  SetLength(Nop, 0);
  Pri := RankTop(Tr, Nop, HedgeCount, 0.0);
  Remaining := Max(HedgeCount - Length(Pri), 0);
  SetLength(Pik, 0);
  if Remaining > 0 then Pik := RankTop(Hf, Pri, Remaining, 0.0);
  N := Min(Length(Pri) + Length(Pik), HedgeCount);
  SetLength(Picks, N);
  for I := 0 to N - 1 do
    if I < Length(Pri) then Picks[I] := Pri[I] else Picks[I] := Pik[I - Length(Pri)];
  if N < HedgeNeed then Exit;

  SetLength(Prim, N); SetLength(Alt, N); SetLength(HasAlt, N);
  for I := 0 to N - 1 do
  begin
    Prim[I].Div_ := Picks[I].Div_; Prim[I].Home := Picks[I].Home; Prim[I].Away := Picks[I].Away;
    Prim[I].Market := Picks[I].Market; Prim[I].Selection := Picks[I].Selection; Prim[I].Prob := Picks[I].Prob;
    if Picks[I].Prob <> 0 then Prim[I].Odds := 1.0 / Picks[I].Prob else Prim[I].Odds := 0;
    HasAlt[I] := False;
    Box := FPred.PredictCached(Picks[I].Div_, Picks[I].Home, Picks[I].Away, ARef);
    if not Box.Pred.Ok then Continue;
    if not AlternateOf(Box.Pred, Picks[I].Market, Picks[I].Selection, AltSel, AltP) then Continue;
    if AltP <= 0 then Continue;
    Alt[I] := Prim[I];
    Alt[I].Selection := AltSel; Alt[I].Prob := AltP; Alt[I].Odds := 1.0 / AltP;
    HasAlt[I] := True;
  end;

  { sve kombinacije od HedgeNeed medu N, leksikografski (itertools.combinations) }
  for K := 0 to HedgeNeed - 1 do Idx[K] := K;
  repeat
    EmitCombo(Slice(Idx, HedgeNeed));
    J := HedgeNeed - 1;
    while (J >= 0) and (Idx[J] = N - HedgeNeed + J) do Dec(J);
    Done := J < 0;
    if not Done then
    begin
      Inc(Idx[J]);
      for K := J + 1 to HedgeNeed - 1 do Idx[K] := Idx[K - 1] + 1;
    end;
  until Done;
end;

function TaSlipGen.Generate(const ASystem: string; const AFx: TaFixtures; ARef: Integer; AMin: Double;
  out AUnit: Double; out APrefix: string): TaGenSlips;
var
  Tr, Hf, Pri, Pik, Pool, Rest: TaSuggestions;
  I, N, Mx, K: Integer;
  Wins: TaWindows;
  Grp: array of TaSuggestion;
  Nop: TaSuggestions;
  NewtonPred, OldPred: TaPredictor;
begin
  SetLength(Result, 0);
  AUnit := 1.0;
  if ASystem = 'prijelazi' then
  begin
    APrefix := 'prijelazi v1';
    Tr := RecommendTransitions(AFx, ARef, AMin);
    AddSingles(Tr, 'prijelaz', Result);
    CombinePicks(Tr, 4, 'prijelaz', Result);
  end
  else if ASystem = 'poluvrijeme' then
  begin
    APrefix := 'poluvrijeme ili kraj v1';
    Hf := RecommendEither(AFx, ARef, False);
    AddSingles(Hf, 'poluvrijeme ili kraj', Result);
    CombinePicks(Hf, 3, 'poluvrijeme ili kraj', Result);
  end
  else if ASystem = 'elita' then
  begin
    APrefix := 'elita v1';
    AUnit := ElitaStake;
    Hf := RecommendEither(AFx, ARef, True);
    AddSingles(Hf, 'elita', Result);
    CombinePicks(Hf, 3, 'elita', Result);
  end
  else if ASystem = 'miks' then
  begin
    APrefix := 'miks v1';
    Tr := RecommendTransitions(AFx, ARef, TransitionDefaultMin);
    Hf := RecommendEither(AFx, ARef, False);
    { prijelazi ima prvo pravo na utakmicu }
    SetLength(Rest, 0); N := 0;
    for I := 0 to High(Hf) do
      if not Claimed(Tr, Hf[I]) then begin SetLength(Rest, N + 1); Rest[N] := Hf[I]; Inc(N); end;
    SetLength(Pool, Length(Tr) + Length(Rest));
    for I := 0 to High(Tr) do Pool[I] := Tr[I];
    for I := 0 to High(Rest) do Pool[Length(Tr) + I] := Rest[I];
    CombinePicks(Pool, 5, 'miks', Result);
  end
  else if ASystem = 'top' then
  begin
    APrefix := 'top listici v1';
    Tr := RecommendTransitions(AFx, ARef, AMin);
    Hf := RecommendEither(AFx, ARef, False);
    SetLength(Nop, 0);
    Pri := RankTop(Tr, Nop, TopDefaultPrijelazi, TopDefaultMinPrijelazi);
    Pik := RankTop(Hf, Pri, TopDefaultPikovi, 0.0);
    { prepleti jedan-na-jedan: prijelaz, pik, prijelaz, pik... }
    Mx := Max(Length(Pri), Length(Pik));
    SetLength(Pool, 0); N := 0;
    for I := 0 to Mx - 1 do
    begin
      if I < Length(Pri) then begin SetLength(Pool, N + 1); Pool[N] := Pri[I]; Inc(N); end;
      if I < Length(Pik) then begin SetLength(Pool, N + 1); Pool[N] := Pik[I]; Inc(N); end;
    end;
    Wins := RingWindows(Length(Pool), TopDefaultLegs);
    for K := 0 to Min(High(Wins), TopDefaultCount - 1) do
    begin
      SetLength(Grp, TopDefaultLegs);
      for I := 0 to TopDefaultLegs - 1 do Grp[I] := Pool[Wins[K][I]];
      AddSlip(Result, GroupName('top listici', Grp), Grp);
    end;
  end
  else if ASystem = 'standard' then
  begin
    APrefix := 'generirani v2';
    GenStandard(AFx, ARef, AMin, Result);
  end
  else if ASystem = 'hedge' then
  begin
    APrefix := 'hedge v1';
    GenHedge(AFx, ARef, AMin, Result);
  end
  else if ASystem = 'newton' then
  begin
    { isti "standard" generator, ali predvidanja daje Newtonov model (Sustav 2); prefiks "Newton" cita bets.system_of }
    APrefix := 'Newton';
    NewtonPred := TaPredictor.Create(FDb);
    OldPred := FPred;
    try
      NewtonPred.SetModel('newton');
      FPred := NewtonPred;
      GenStandard(AFx, ARef, AMin, Result);
    finally
      FPred := OldPred;
      NewtonPred.Free;
    end;
  end
  else
    raise EExpr.Create('GenerateSlips: sustav je prijelazi, poluvrijeme, elita, miks, top, standard, hedge ili newton');
end;

{ ---------------- utakmice kola i spremanje ---------------- }

function LoadFixtures(ADb: TAppDb; ARef, AHorizon, ACutoffDay: Integer): TaFixtures;
var
  Q: TZQuery;
  N, I: Integer;
  Played, Tabs: TStringList;
  Key: string;
begin
  SetLength(Result, 0);
  { bez tablice utakmica kola nema sto generirati }
  Tabs := ADb.UserTables;
  try
    if (Tabs.IndexOf('fixtures') < 0) or (Tabs.IndexOf('matches') < 0) then Exit;
  finally
    Tabs.Free;
  end;
  Played := TStringList.Create;
  try
    Played.CaseSensitive := True;
    Played.Sorted := True;
    Played.Duplicates := dupIgnore;
    if ACutoffDay > 0 then
    begin
      Q := ADb.NewQuery('SELECT DISTINCT division, hometeam, awayteam FROM matches WHERE matchdate >= :c AND ftr IS NOT NULL');
      try
        Q.ParamByName('c').AsString := FormatDateTime('yyyy-mm-dd', ACutoffDay);
        Q.Open;
        while not Q.Eof do
        begin
          Played.Add(Q.Fields[0].AsString + '|' + Q.Fields[1].AsString + '|' + Q.Fields[2].AsString);
          Q.Next;
        end;
      finally
        Q.Free;
      end;
    end;
    Q := ADb.NewQuery('SELECT division, hometeam, awayteam, matchdate FROM fixtures ORDER BY rowid');
    try
      Q.Open;
      N := 0;
      while not Q.Eof do
      begin
        Key := Q.Fields[0].AsString + '|' + Q.Fields[1].AsString + '|' + Q.Fields[2].AsString;
        I := 0;
        if (Q.Fields[3].AsString <> '') and (Played.IndexOf(Key) < 0) then
        begin
          I := DayOfText(Q.Fields[3].AsString);
          if (I >= ARef) and (I <= ARef + AHorizon) then
          begin
            SetLength(Result, N + 1);
            Result[N].Div_ := Q.Fields[0].AsString; Result[N].Home := Q.Fields[1].AsString;
            Result[N].Away := Q.Fields[2].AsString; Result[N].MatchDate := Q.Fields[3].AsString;
            Inc(N);
          end;
        end;
        Q.Next;
      end;
    finally
      Q.Free;
    end;
  finally
    Played.Free;
  end;
end;

function LegSetKey(const S: TaGenSlip): string;
var
  L: TStringList;
  I: Integer;
begin
  L := TStringList.Create;
  try
    L.CaseSensitive := True;
    for I := 0 to High(S.Legs) do
      L.Add(S.Legs[I].Div_ + #1 + S.Legs[I].Home + #1 + S.Legs[I].Away + #1 + S.Legs[I].Market + #1 + S.Legs[I].Selection);
    L.Sort;
    Result := L.Text;
  finally
    L.Free;
  end;
end;

function SaveGeneratedSlips(ADb: TAppDb; const ASlips: TaGenSlips; ARef, AToday: Integer; AUnit: Double; const APrefix: string): Integer;
var
  Existing: TStringList;
  Q, Ql: TZQuery;
  I, J: Integer;
  Note, RefTxt, Today, Key, Legs: string;
  Id: Integer;
  Fs: TFormatSettings;
begin
  Result := 0;
  Fs := DefaultFormatSettings;
  Fs.DecimalSeparator := '.';
  RefTxt := FormatDateTime('yyyy-mm-dd', ARef);
  Today := FormatDateTime('yyyy-mm-dd', AToday);
  Existing := TStringList.Create;
  try
    Existing.CaseSensitive := True;
    { vec otvoreni (PENDING) listici istog kola i sustava: ne pisati ih dvaput }
    Q := ADb.NewQuery('SELECT slip_id, note FROM slips WHERE ref_date = :r AND note LIKE :p AND status = ''PENDING''');
    try
      Q.ParamByName('r').AsString := RefTxt;
      Q.ParamByName('p').AsString := APrefix + ' - %';
      Q.Open;
      while not Q.Eof do
      begin
        Ql := ADb.NewQuery('SELECT division, hometeam, awayteam, market, selection FROM slip_legs WHERE slip_id = :s');
        try
          Ql.ParamByName('s').AsInteger := Q.Fields[0].AsInteger;
          Ql.Open;
          Legs := '';
          { isti ključ kao LegSetKey: poredano }
          with TStringList.Create do
          try
            CaseSensitive := True;
            while not Ql.Eof do
            begin
              Add(Ql.Fields[0].AsString + #1 + Ql.Fields[1].AsString + #1 + Ql.Fields[2].AsString + #1 + Ql.Fields[3].AsString + #1 + Ql.Fields[4].AsString);
              Ql.Next;
            end;
            Sort;
            Legs := Text;
          finally
            Free;
          end;
        finally
          Ql.Free;
        end;
        Existing.Add(Q.Fields[1].AsString + #2 + Legs);
        Q.Next;
      end;
    finally
      Q.Free;
    end;
    for I := 0 to High(ASlips) do
    begin
      Note := APrefix + ' - ' + ASlips[I].Name;
      Key := Note + #2 + LegSetKey(ASlips[I]);
      if Existing.IndexOf(Key) >= 0 then Continue;
      ADb.Conn.ExecuteDirect(Format('INSERT INTO slips (created_at, ref_date, stake, note, status, paper) VALUES (''%s'', ''%s'', %s, ''%s'', ''PENDING'', 1)',
        [Today, RefTxt, FloatToStr(AUnit, Fs), StringReplace(Note, '''', '''''', [rfReplaceAll])]));
      Q := ADb.NewQuery('SELECT last_insert_rowid()');
      try
        Q.Open;
        Id := Q.Fields[0].AsInteger;
      finally
        Q.Free;
      end;
      for J := 0 to High(ASlips[I].Legs) do
        ADb.Conn.ExecuteDirect(Format('INSERT INTO slip_legs (slip_id, division, hometeam, awayteam, market, selection, model_probability, odds, status) ' +
          'VALUES (%d, ''%s'', ''%s'', ''%s'', ''%s'', ''%s'', %s, %s, ''PENDING'')',
          [Id, StringReplace(ASlips[I].Legs[J].Div_, '''', '''''', [rfReplaceAll]),
           StringReplace(ASlips[I].Legs[J].Home, '''', '''''', [rfReplaceAll]),
           StringReplace(ASlips[I].Legs[J].Away, '''', '''''', [rfReplaceAll]),
           ASlips[I].Legs[J].Market, StringReplace(ASlips[I].Legs[J].Selection, '''', '''''', [rfReplaceAll]),
           FloatToStr(ASlips[I].Legs[J].Prob, Fs), FloatToStr(ASlips[I].Legs[J].Odds, Fs)]));
      Existing.Add(Key);
      Inc(Result);
    end;
  finally
    Existing.Free;
  end;
end;

{ ---------------- izlaganje: GenerateSlips(sustav, datum [, min_vjerojatnost]) ---------------- }

var
  GGen: TaSlipGen = nil;
  GGenPred: TaPredictor = nil;
  GGenDb: TAppDb = nil;

function GenerateHook(const AName: string; const A: array of Variant; N: Integer): Variant;
var
  Fx: TaFixtures;
  Slips: TaGenSlips;
  U: Double;
  Pfx: string;
  Ref: Integer;
  Mn: Double;
begin
  Result := Null;
  if (ActiveDb = nil) or not ActiveDb.Connected then Exit;
  if AName = 'predictround' then
  begin
    if N >= 1 then Result := PredictRoundToTables(ActiveDb, DayOfArg(A[0]), FixtureHorizonDays)
    else Result := PredictRoundToTables(ActiveDb, Trunc(Date), FixtureHorizonDays);
    Exit;
  end;
  if AName = 'importfixtures' then
  begin
    if Trim(VarToStr(A[0])) = '' then Result := 0 else Result := ImportFixtureFile(ActiveDb, VarToStr(A[0]));
    Exit;
  end;
  if (GGenDb <> ActiveDb) or (GGen = nil) then
  begin
    GGen.Free; GGenPred.Free;
    GGenPred := TaPredictor.Create(ActiveDb);
    GGen := TaSlipGen.Create(ActiveDb, GGenPred);
    GGenDb := ActiveDb;
  end;
  Ref := DayOfArg(A[1]);
  Mn := TransitionDefaultMin;
  if (LowerCase(VarToStr(A[0])) = 'standard') or (LowerCase(VarToStr(A[0])) = 'newton') then Mn := StandardThreshold;      { prag pouzdanosti za "veliki" }
  if (N >= 3) and not VarIsNull(A[2]) then Mn := Double(A[2]);
  Fx := LoadFixtures(ActiveDb, Ref, FixtureHorizonDays, Trunc(Date) - StaleFixtureWindowDays);
  Slips := GGen.Generate(LowerCase(VarToStr(A[0])), Fx, Ref, Mn, U, Pfx);
  if Length(Slips) = 0 then Exit(0);
  Result := SaveGeneratedSlips(ActiveDb, Slips, Ref, Trunc(Date), U, Pfx);
end;

procedure WriteGeneratedSlips(ADb: TAppDb; const ASystem, ARef: string; AMin: Double);
var
  Pr: TaPredictor;
  Gen: TaSlipGen;
  Fx: TaFixtures;
  Slips: TaGenSlips;
  I, J, Ref: Integer;
  U: Double;
  Pfx, Line: string;
  Fs: TFormatSettings;
begin
  Fs := DefaultFormatSettings;
  Fs.DecimalSeparator := '.';
  Ref := DayOfText(ARef);
  Pr := TaPredictor.Create(ADb);
  Gen := TaSlipGen.Create(ADb, Pr);
  try
    Fx := LoadFixtures(ADb, Ref, FixtureHorizonDays, 0);
    if (ASystem = 'standard') or (ASystem = 'newton') then AMin := StandardThreshold;
    Slips := Gen.Generate(ASystem, Fx, Ref, AMin, U, Pfx);
    for I := 0 to High(Slips) do
    begin
      Line := 'SLIP;' + Pfx + ' - ' + Slips[I].Name + ';' + FloatToStr(U, Fs);
      for J := 0 to High(Slips[I].Legs) do
        Line := Line + ';' + Slips[I].Legs[J].Div_ + '~' + Slips[I].Legs[J].Home + '~' + Slips[I].Legs[J].Away + '~' +
          Slips[I].Legs[J].Market + '~' + Slips[I].Legs[J].Selection + '~' +
          FloatToStrF(Slips[I].Legs[J].Prob, ffGeneral, 17, 0, Fs) + '~' + FloatToStrF(Slips[I].Legs[J].Odds, ffGeneral, 17, 0, Fs);
      WriteLn(Line);
    end;
    WriteLn('COUNT;', Length(Slips));
  finally
    Gen.Free;
    Pr.Free;
  end;
end;

function PredictRoundToTables(ADb: TAppDb; ARef, AHorizon: Integer): Integer;
type
  TRoundRow = record
    F: TaFixture;
    P, M: TaPrediction;
    Best: TaGenLeg;
    HasBest: Boolean;
  end;
var
  Pr, Mkt: TaPredictor;
  Gen: TaSlipGen;
  Fx: TaFixtures;
  Rows: array of TRoundRow;
  Row: TRoundRow;
  I, J, K, N, Id: Integer;
  Q: TZQuery;
  Fs: TFormatSettings;
  Tabs: TStringList;
  P1, PX, P2, O15, O25, O35, Gg: Double;
  H: array[0..8] of Double;
  Note, Ph1, Ph2, KlBook, KlP1, KlPx, KlP2, KlBest, KlDiff: string;
  Mv, Bp: Double;

  function Pick(const AMarket, ASel: string): Double;
  var
    X: Integer;
  begin
    Result := 0;
    for X := 0 to High(Row.P.Items) do
      if (Row.P.Items[X].Market = AMarket) and (Row.P.Items[X].Selection = ASel) then Exit(Row.P.Items[X].P);
  end;

  function Sql(X: Double): string;
  begin
    Result := FloatToStr(X, Fs);
  end;

  function Quote(const S: string): string;
  begin
    Result := '''' + StringReplace(S, '''', '''''', [rfReplaceAll]) + '''';
  end;

  { najsigurniji izbor prvi; utakmice bez izbora na kraj }
  function KeyOf(const R: TRoundRow): Double;
  begin
    if R.HasBest then Result := R.Best.Prob else Result := -1;
  end;

  procedure AddMarket(AId: Integer; const AMarket, ASel: string; AP: Double);
  begin
    if AP <= 0 then Exit;
    ADb.Conn.ExecuteDirect('INSERT INTO kolo_trzista (utakmica_id, trziste, izbor, vjerojatnost, fer_kvota) VALUES (' + IntToStr(AId) + ',' + Quote(AMarket) + ',' +
      Quote(ASel) + ',' + Sql(AP) + ',' + Sql(1.0 / AP) + ')');
  end;

begin
  Fs := DefaultFormatSettings;
  Fs.DecimalSeparator := '.';
  Result := 0;
  Tabs := ADb.UserTables;
  try
    if Tabs.IndexOf('matches') < 0 then Exit;
    if Tabs.IndexOf('kolo_utakmice') < 0 then
      ADb.Conn.ExecuteDirect('CREATE TABLE kolo_utakmice (id INTEGER PRIMARY KEY AUTOINCREMENT, rang INTEGER, liga TEXT, datum TEXT, domaci TEXT, gosti TEXT, ' +
        'xg_domaci REAL, xg_gosti REAL, p1 REAL, px REAL, p2 REAL, over15 REAL, over25 REAL, over35 REAL, gg REAL, najbolji_trziste TEXT, najbolji_izbor TEXT, ' +
        'najbolji_p REAL, fer_kvota REAL, iznad_praga TEXT, poluvrijeme_1 REAL, poluvrijeme_2 REAL, napomena TEXT, ' +
        'kl_knjiga TEXT, kl_p1 REAL, kl_px REAL, kl_p2 REAL, kl_izbor_p REAL, kl_razlika REAL, forma_domaci TEXT, forma_gosti TEXT)');
    if Tabs.IndexOf('kolo_trzista') < 0 then
      ADb.Conn.ExecuteDirect('CREATE TABLE kolo_trzista (id INTEGER PRIMARY KEY AUTOINCREMENT, utakmica_id INTEGER, trziste TEXT, izbor TEXT, vjerojatnost REAL, fer_kvota REAL)');
  finally
    Tabs.Free;
  end;
  { forma momcadi (zadnjih 5, najstarija lijevo) za tablicu iz starijih izdanja }
  Q := ADb.NewQuery('SELECT COUNT(*) FROM pragma_table_info(''kolo_utakmice'') WHERE name = ''forma_domaci''');
  try
    Q.Open;
    if Q.Fields[0].AsInteger = 0 then
    begin
      ADb.Conn.ExecuteDirect('ALTER TABLE kolo_utakmice ADD COLUMN forma_domaci TEXT');
      ADb.Conn.ExecuteDirect('ALTER TABLE kolo_utakmice ADD COLUMN forma_gosti TEXT');
    end;
  finally
    Q.Free;
  end;
  { stupci usporedbe s trzistem (kvote kladionice) za tablicu iz starijih izdanja }
  Q := ADb.NewQuery('SELECT COUNT(*) FROM pragma_table_info(''kolo_utakmice'') WHERE name = ''kl_knjiga''');
  try
    Q.Open;
    if Q.Fields[0].AsInteger = 0 then
    begin
      ADb.Conn.ExecuteDirect('ALTER TABLE kolo_utakmice ADD COLUMN kl_knjiga TEXT');
      ADb.Conn.ExecuteDirect('ALTER TABLE kolo_utakmice ADD COLUMN kl_p1 REAL');
      ADb.Conn.ExecuteDirect('ALTER TABLE kolo_utakmice ADD COLUMN kl_px REAL');
      ADb.Conn.ExecuteDirect('ALTER TABLE kolo_utakmice ADD COLUMN kl_p2 REAL');
      ADb.Conn.ExecuteDirect('ALTER TABLE kolo_utakmice ADD COLUMN kl_izbor_p REAL');
      ADb.Conn.ExecuteDirect('ALTER TABLE kolo_utakmice ADD COLUMN kl_razlika REAL');
    end;
  finally
    Q.Free;
  end;
  Pr := TaPredictor.Create(ADb);
  Mkt := TaPredictor.Create(ADb);
  Mkt.SetModel('market');
  Gen := TaSlipGen.Create(ADb, Pr);
  try
    Fx := LoadFixtures(ADb, ARef, AHorizon, Trunc(Date) - StaleFixtureWindowDays);
    N := 0;
    SetLength(Rows, Length(Fx));
    for I := 0 to High(Fx) do
    begin
      Row.F := Fx[I];
      Row.P := Pr.PredictCached(Fx[I].Div_, Fx[I].Home, Fx[I].Away, ARef).Pred;
      if not Row.P.Ok then Continue;
      Row.HasBest := Gen.RankedLeg(Row.P, Fx[I], 0, Row.Best);
      Row.M := Mkt.PredictCached(Fx[I].Div_, Fx[I].Home, Fx[I].Away, ARef).Pred;
      Rows[N] := Row; Inc(N);
    end;
    SetLength(Rows, N);
    { najsigurniji izbor prvi (stabilno) }
    for I := 1 to N - 1 do
    begin
      Row := Rows[I]; J := I - 1;
      while (J >= 0) and (KeyOf(Rows[J]) < KeyOf(Row)) do
      begin Rows[J + 1] := Rows[J]; Dec(J); end;
      Rows[J + 1] := Row;
    end;
    ADb.Conn.StartTransaction;
    try
      ADb.Conn.ExecuteDirect('DELETE FROM kolo_trzista');
      ADb.Conn.ExecuteDirect('DELETE FROM kolo_utakmice');
      for I := 0 to N - 1 do
      begin
        Row := Rows[I];
        P1 := Pick('1X2', '1'); PX := Pick('1X2', 'X'); P2 := Pick('1X2', '2');
        O15 := Pick('OVER_UNDER', 'Over 1.5'); O25 := Pick('OVER_UNDER', 'Over 2.5'); O35 := Pick('OVER_UNDER', 'Over 3.5');
        Gg := Pick('BTTS', 'GG');
        Note := Row.P.Notes;
        if Row.P.LastRound then begin if Note <> '' then Note := Note + '; '; Note := Note + 'zadnje kolo sezone: obicno vise golova nego inace'; end;
        if not Row.P.HalfTimeFitted then begin if Note <> '' then Note := Note + '; '; Note := Note + 'nema poluvremena za ovu ligu: HT/FT nije ponudjen'; end;
        Ph1 := 'NULL'; Ph2 := 'NULL';
        if GetHtft(Row.P, H) then
        begin
          HtOrFt(H, P1, PX, P2);   { P1/PX/P2 se ovdje privremeno koriste za poluvrijeme ili kraj }
          Ph1 := Sql(P1); Ph2 := Sql(P2);
          P1 := Pick('1X2', '1'); PX := Pick('1X2', 'X'); P2 := Pick('1X2', '2');
        end;
        { mišljenje trzista iz kvota kladionice (marketfit) i razlika od modela za najbolji izbor }
        KlBook := 'NULL'; KlP1 := 'NULL'; KlPx := 'NULL'; KlP2 := 'NULL'; KlBest := 'NULL'; KlDiff := 'NULL';
        if Row.M.Ok then
        begin
          KlBook := Quote(Copy(Row.M.Notes, Pos('(', Row.M.Notes) + 1, Pos(')', Row.M.Notes) - Pos('(', Row.M.Notes) - 1));
          for K := 0 to High(Row.M.Items) do
          begin
            if (Row.M.Items[K].Market = '1X2') and (Row.M.Items[K].Selection = '1') then KlP1 := Sql(Row.M.Items[K].P);
            if (Row.M.Items[K].Market = '1X2') and (Row.M.Items[K].Selection = 'X') then KlPx := Sql(Row.M.Items[K].P);
            if (Row.M.Items[K].Market = '1X2') and (Row.M.Items[K].Selection = '2') then KlP2 := Sql(Row.M.Items[K].P);
            if Row.HasBest and (Row.M.Items[K].Market = Row.Best.Market) and (Row.M.Items[K].Selection = Row.Best.Selection) then
            begin
              Mv := Row.M.Items[K].P; Bp := Row.Best.Prob;
              KlBest := Sql(Mv); KlDiff := Sql(Bp - Mv);
            end;
          end;
        end;
        ADb.Conn.ExecuteDirect('INSERT INTO kolo_utakmice (rang, liga, datum, domaci, gosti, xg_domaci, xg_gosti, p1, px, p2, over15, over25, over35, gg, najbolji_trziste, ' +
          'najbolji_izbor, najbolji_p, fer_kvota, iznad_praga, poluvrijeme_1, poluvrijeme_2, napomena, kl_knjiga, kl_p1, kl_px, kl_p2, kl_izbor_p, kl_razlika, forma_domaci, forma_gosti) VALUES (' + IntToStr(I + 1) + ',' + Quote(Row.F.Div_) + ',' +
          Quote(Row.F.MatchDate) + ',' + Quote(Row.F.Home) + ',' + Quote(Row.F.Away) + ',' + Sql(Row.P.XgH) + ',' + Sql(Row.P.XgA) + ',' + Sql(P1) + ',' + Sql(PX) + ',' + Sql(P2) + ',' +
          Sql(O15) + ',' + Sql(O25) + ',' + Sql(O35) + ',' + Sql(Gg) + ',' + Quote(Row.Best.Market) + ',' + Quote(Row.Best.Selection) + ',' + Sql(Row.Best.Prob) + ',' +
          Sql(Row.Best.Odds) + ',' + Quote(IfThen(Row.HasBest and (Row.Best.Prob >= StandardThreshold), 'DA', 'NE')) + ',' + Ph1 + ',' + Ph2 + ',' + Quote(Note) + ',' + KlBook + ',' + KlP1 + ',' + KlPx + ',' + KlP2 + ',' + KlBest + ',' + KlDiff + ',' + Quote(FormOf(ADb, Row.F.Home, FormatDateTime('yyyy-mm-dd', ARef), 5)) + ',' + Quote(FormOf(ADb, Row.F.Away, FormatDateTime('yyyy-mm-dd', ARef), 5)) + ')');
        Q := ADb.NewQuery('SELECT last_insert_rowid()');
        try
          Q.Open;
          Id := Q.Fields[0].AsInteger;
        finally
          Q.Free;
        end;
        for K := 0 to High(Row.P.Items) do AddMarket(Id, Row.P.Items[K].Market, Row.P.Items[K].Selection, Row.P.Items[K].P);
        if GetHtft(Row.P, H) then
        begin
          HtOrFt(H, P1, PX, P2);
          AddMarket(Id, 'HT_OR_FT', '1', P1); AddMarket(Id, 'HT_OR_FT', 'X', PX); AddMarket(Id, 'HT_OR_FT', '2', P2);
        end;
      end;
      ADb.Conn.Commit;
    except
      ADb.Conn.Rollback;
      raise;
    end;
    Result := N;
  finally
    Gen.Free;
    Mkt.Free;
    Pr.Free;
  end;
end;

initialization
  GenerateSlipsHook := @GenerateHook;

finalization
  GGen.Free;
  GGenPred.Free;

end.
