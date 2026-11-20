unit ta_predict;
{ Predvidanja utakmica: nativna replika SMART-BETTING-APP modela (smartbet/analytics/ratings.py,
  gamestate.py, models/markets.py, predictor.py, analytics/rounds.py). Isti postupak i iste postavke,
  pa daje iste brojke; paritet se provjerava naredbom --predict (vidi ta_mainform). Nema slucajnosti
  i optimizatora: ocjene su koordinatni uspon sa zatvorenim izrazom, pa je rezultat odredjen podacima. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, StrUtils, Variants, ZDataset, ta_meta, ta_expr, ta_exprdb, ta_parse;

type
  TaModelCfg = record
    HalfLife, Lookback: Double;
    MaxIter: Integer;
    Tol, ShrinkMatches, PriorGoals: Double;
    RhoLo, RhoHi: Double;
    RhoGrid: Integer;
    RhoPrior, RhoShrink: Double;
    CalPower: Double;
    OuOn: Boolean;
    OuSlope, OuShift: array[0..2] of Double;      { linije 1.5, 2.5, 3.5 }
    BttsOn: Boolean;
    BttsSlope, BttsShift: Double;
    LastRoundOn: Boolean;
    LastRoundShift: Double;                       { samo linija 2.5 }
    StateShrink, StateLo, StateHi: Double;
    MaxGoalsFt, MaxGoalsHalf: Integer;
  end;

  TaPredItem = record
    Market, Selection: string;
    P: Double;
  end;

  TMatrix = array of array of Double;

  TaPrediction = record
    Ok: Boolean;
    XgH, XgA, XgHtH, XgHtA: Double;
    HalfTimeFitted, LastRound: Boolean;
    Notes: string;                       { napomene odvojene s '; ' (klub bez povijesti...) }
    Items: array of TaPredItem;
    Matrix: TMatrix;                     { matrica rezultata punog vremena (samo Poisson model) }
  end;

  TaMatchRow = record
    Div_, Home, Away: string;
    Day: Integer;
    Fthg, Ftag, Hthg, Htag: Integer;
    HasHt: Boolean;
  end;
  TaMatchRows = array of TaMatchRow;

  TaRatingSet = class
  public
    Teams, Divs: TStringList;
    Attack, Defence, Eff, DivLevel: array of Double;
    Gamma, Rho: Double;
    constructor Create;
    destructor Destroy; override;
    function Copy_Halved: TaRatingSet;
    procedure Rate(const ATeam: string; out A, D: Double);
    function Level(const ADiv: string): Double;
    procedure ExpectedGoals(const ADiv, AHome, AAway: string; out H, A: Double);
  end;

  TaProfiles = class
  public
    Teams: TStringList;
    AtkMult, DefMult: array of Double;     { team * 3 + stanje }
    LeagueAtk, LeagueDef: array[0..2] of Double;
    ComebackRate, CollapseRate: array of Double;   { po momcadi: gubio na poluvremenu pa dobio / vodio pa nije dobio }
    constructor Create;
    destructor Destroy; override;
    procedure Multipliers(const ATeam: string; AState: Integer; out Atk, Def: Double);
    { gamestate.closer_index / chaos_index: iznad 1 = gasi utakmicu kad vodi / otvara je kad gubi }
    function CloserIndex(const ATeam: string): Double;
    function ChaosIndex(const ATeam: string): Double;
    procedure Rates(const ATeam: string; out AComeback, ACollapse: Double);
  end;

  TaBundle = class
  public
    Ft, Ht, Sh: TaRatingSet;
    Profiles: TaProfiles;
    HalfFitted: Boolean;
    OwnsHalves: Boolean;
    destructor Destroy; override;
  end;

  TaPredBox = class
  public
    Pred: TaPrediction;
  end;

  { zamjenski model (Newton): isto sucelje kao Poisson predvidjanje, vidi ta_newton }
  TaAltEngine = class
  public
    function Predict(const ADiv, AHome, AAway: string; ARef: Integer): TaPrediction; virtual; abstract;
    procedure Clear; virtual;
  end;

  TaPredictor = class
  private
    FDb: TAppDb;
    FCache: TStringList;           { grupa|dan -> TaBundle (ili nil) }
    FPreds: TStringList;           { liga|domaci|gosti|dan -> TaPredBox }
    function BundleFor(const ADiv: string; ARef: Integer): TaBundle;
    function LoadRows(const ADivs: array of string; ARef: Integer): TaMatchRows;
    function IsLastRound(const ADiv, AHome, AAway: string; ARef: Integer): Boolean;
    function ScalarStr(const ASql: string; const AParams: array of string): string;
  public
    Cfg: TaModelCfg;
    Alt: TaAltEngine;              { nil = Poisson; inace sve predvidja zamjenski model }
    constructor Create(ADb: TAppDb);
    { 'poisson' ili 'newton' (isto kao MODELS u backtest/standard.py) }
    procedure SetModel(const AModel: string);
    { profili ponasanja u 2. poluvremenu samo za jednu ligu (dashboard); vlasnik oslobadja; nil ako je podataka premalo }
    function DivisionProfiles(const ADiv: string; ARef: Integer): TaProfiles;
    destructor Destroy; override;
    function Predict(const ADiv, AHome, AAway: string; ARef: Integer): TaPrediction;
    { isto, ali pamti rezultat po utakmici i danu }
    function PredictCached(const ADiv, AHome, AAway: string; ARef: Integer): TaPredBox;
    procedure Clear;
  end;

var
  { registrira ta_newton: (baza, naziv modela) -> motor }
  AltEngineFactory: function(ADb: TAppDb; const AModel: string): TaAltEngine = nil;

{ markets.score_matrix: Dixon-Coles matrica rezultata }
function ScoreMatrix(ALamH, ALamA, ARho: Double; AMax: Integer): TMatrix;
function DefaultModelCfg: TaModelCfg;
function DayOfText(const S: string): Integer;      { 'GGGG-MM-DD' -> broj dana }
function GroupOfDivision(const ADiv: string): TStringArray;
{ datum iz izraza (datum, broj ili tekst) kao broj dana; prazno je danas }
function DayOfArg(const V: Variant): Integer;
{ "Poluvrijeme ili kraj" iz HT/FT tablice (kao markets.ht_or_ft) }
procedure HtOrFt(const AHtft: array of Double; out P1, PX, P2: Double);
{ ispis predvidanja za popis "liga;domaci;gosti" na standardni izlaz (paritet s Pythonom) }
procedure WritePredictions(ADb: TAppDb; AFixtures: TStrings; const ARef: string; const AModel: string = '');

implementation

uses
  ta_i18n;


const
  HtftNames: array[0..8] of string = ('1/1', '1/X', '1/2', 'X/1', 'X/X', 'X/2', '2/1', '2/X', '2/2');
  OuLines: array[0..2] of string = ('1.5', '2.5', '3.5');
  OuValues: array[0..2] of Double = (1.5, 2.5, 3.5);

{ ---------------- postavke i grupe liga (config.py) ---------------- }

function DefaultModelCfg: TaModelCfg;
begin
  Result.HalfLife := 300.0;
  Result.Lookback := 1680.0;
  Result.MaxIter := 200;
  Result.Tol := 1e-9;
  Result.ShrinkMatches := 8.0;
  Result.PriorGoals := 0.25;
  Result.RhoLo := -0.25; Result.RhoHi := 0.25; Result.RhoGrid := 41;
  Result.RhoPrior := -0.05; Result.RhoShrink := 160.0;
  Result.CalPower := 1.12;
  Result.OuOn := True;
  Result.OuSlope[0] := 0.745; Result.OuShift[0] := 0.333;
  Result.OuSlope[1] := 0.740; Result.OuShift[1] := 0.074;
  Result.OuSlope[2] := 0.751; Result.OuShift[2] := -0.179;
  Result.BttsOn := True; Result.BttsSlope := 0.61; Result.BttsShift := 0.077;
  Result.LastRoundOn := True; Result.LastRoundShift := 0.40;
  Result.StateShrink := 12.0; Result.StateLo := 0.55; Result.StateHi := 1.75;
  Result.MaxGoalsFt := 12; Result.MaxGoalsHalf := 7;
end;

const
  Groups: array[0..29] of string = (
    'E0,E1,E2,E3,EC', 'SC0,SC1,SC2,SC3', 'D1,D2', 'I1,I2', 'SP1,SP2', 'F1,F2', 'N1', 'B1', 'P1', 'T1', 'G1',
    'ARG1,ARGC', 'AUT1', 'BRA1', 'CHN1', 'DNK1', 'FIN1', 'IRL1', 'JPN1', 'MEX1', 'NOR1', 'POL1', 'ROU1',
    'RUS1', 'SWE1', 'SWZ1', 'USA1', 'CRO1,CRO2,CROCUP', 'UCL,UEL,UECL', '');
  NoHalfTime = ',CRO1,CRO2,CROCUP,';

function SplitComma(const S: string): TStringArray;
var
  P, Q: Integer;
begin
  Result := nil;
  P := 1;
  while P <= Length(S) + 1 do
  begin
    Q := PosEx(',', S, P);
    if Q = 0 then Q := Length(S) + 1;
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := Copy(S, P, Q - P);
    P := Q + 1;
  end;
end;

function GroupOfDivision(const ADiv: string): TStringArray;
var
  I, J: Integer;
  M: TStringArray;
begin
  for I := 0 to High(Groups) do
  begin
    if Groups[I] = '' then Continue;
    M := SplitComma(Groups[I]);
    for J := 0 to High(M) do
      if M[J] = ADiv then Exit(M);
  end;
  SetLength(Result, 1);
  Result[0] := ADiv;
end;

function DayOfText(const S: string): Integer;
begin
  Result := Trunc(EncodeDate(StrToInt(Copy(S, 1, 4)), StrToInt(Copy(S, 6, 2)), StrToInt(Copy(S, 9, 2))));
end;

function TextOfDay(ADay: Integer): string;
begin
  Result := FormatDateTime('yyyy-mm-dd', ADay);
end;

{ ---------------- ocjene (ratings.py) ---------------- }

constructor TaRatingSet.Create;
begin
  Teams := TStringList.Create;
  Teams.CaseSensitive := True;
  Divs := TStringList.Create;
  Divs.CaseSensitive := True;
end;

destructor TaRatingSet.Destroy;
begin
  Teams.Free;
  Divs.Free;
  inherited Destroy;
end;

function TaRatingSet.Copy_Halved: TaRatingSet;
var
  I: Integer;
begin
  Result := TaRatingSet.Create;
  Result.Teams.Assign(Teams);
  Result.Divs.Assign(Divs);
  Result.Attack := Copy(Attack);
  Result.Defence := Copy(Defence);
  Result.Eff := Copy(Eff);
  Result.DivLevel := Copy(DivLevel);
  for I := 0 to High(Result.DivLevel) do Result.DivLevel[I] := Result.DivLevel[I] / 2.0;
  Result.Gamma := Gamma;
  Result.Rho := 0.0;
end;

procedure TaRatingSet.Rate(const ATeam: string; out A, D: Double);
var
  I: Integer;
begin
  I := Teams.IndexOf(ATeam);
  if I < 0 then begin A := 1.0; D := 1.0; end
  else begin A := Attack[I]; D := Defence[I]; end;
end;

function TaRatingSet.Level(const ADiv: string): Double;
var
  I: Integer;
  S: Double;
begin
  if Length(DivLevel) = 0 then Exit(1.0);
  I := Divs.IndexOf(ADiv);
  if I >= 0 then Exit(DivLevel[I]);
  S := 0;
  for I := 0 to High(DivLevel) do S := S + DivLevel[I];
  Result := S / Length(DivLevel);
end;

procedure TaRatingSet.ExpectedGoals(const ADiv, AHome, AAway: string; out H, A: Double);
var
  Mu, AtkH, DefH, AtkA, DefA: Double;
begin
  Mu := Level(ADiv);
  Rate(AHome, AtkH, DefH);
  Rate(AAway, AtkA, DefA);
  H := Mu * AtkH * DefA * Gamma;
  A := Mu * AtkA * DefH;
end;

{ nacin gola: 0 = puno vrijeme, 1 = prvo poluvrijeme, 2 = drugo poluvrijeme }
procedure GoalsOf(const R: TaMatchRow; AMode: Integer; out HG, AG: Integer);
begin
  case AMode of
    0: begin HG := R.Fthg; AG := R.Ftag; end;
    1: begin HG := R.Hthg; AG := R.Htag; end;
  else
    begin HG := Max(R.Fthg - R.Hthg, 0); AG := Max(R.Ftag - R.Htag, 0); end;
  end;
end;

function FitRho(const HG, AG: array of Integer; const LamH, LamA, W: array of Double; const C: TaModelCfg): Double;
var
  I, G, N: Integer;
  Low: array of Integer;
  BestRho, BestLl, Ll, Rho, Tau, Eff: Double;
  Bad: Boolean;
begin
  N := 0;
  SetLength(Low, Length(HG));
  for I := 0 to High(HG) do
    if (HG[I] <= 1) and (AG[I] <= 1) then begin Low[N] := I; Inc(N); end;
  if N = 0 then Exit(0.0);
  BestRho := 0.0; BestLl := -Infinity;
  for G := 0 to C.RhoGrid - 1 do
  begin
    Rho := C.RhoLo + G * ((C.RhoHi - C.RhoLo) / (C.RhoGrid - 1));
    if G = C.RhoGrid - 1 then Rho := C.RhoHi;
    Ll := 0; Bad := False;
    for I := 0 to N - 1 do
    begin
      if (HG[Low[I]] = 0) and (AG[Low[I]] = 0) then Tau := 1.0 - LamH[Low[I]] * LamA[Low[I]] * Rho
      else if (HG[Low[I]] = 0) and (AG[Low[I]] = 1) then Tau := 1.0 + LamH[Low[I]] * Rho
      else if (HG[Low[I]] = 1) and (AG[Low[I]] = 0) then Tau := 1.0 + LamA[Low[I]] * Rho
      else Tau := 1.0 - Rho;
      if Tau <= 1e-9 then begin Bad := True; Break; end;
      Ll := Ll + W[Low[I]] * Ln(Tau);
    end;
    if Bad then Continue;
    if Ll > BestLl then begin BestLl := Ll; BestRho := Rho; end;
  end;
  Eff := 0;
  for I := 0 to N - 1 do Eff := Eff + W[Low[I]];
  if C.RhoShrink <= 0 then Exit(BestRho);
  Result := (Eff * BestRho + C.RhoShrink * C.RhoPrior) / (Eff + C.RhoShrink);
end;

{ ARows moraju prethoditi ARef; ARows nisu nuzno vec filtrirani prozorom }
function FitRatings(const ARows: TaMatchRows; ARef: Integer; AMode: Integer; const C: TaModelCfg): TaRatingSet;
var
  I, K, It, NT, ND, N, Cutoff: Integer;
  Keep: TaMatchRows;
  Wt: array of Double;
  W: Double;
  HI, AI, DI, HG, AG: array of Integer;
  Hg1, Ag1: Integer;
  Teams, Divs: TStringList;
  GoalsFor, GoalsAgainst, Eff, Exposure: array of Double;
  Att, Def, Mu, Den, Prev: array of Double;
  Gamma, GoalsHomeTotal, DenGamma, SumW, SumG, Prior, ScaleA, ScaleD, MaxDiff, MuM, Contrib: Double;
  DivGoalTotals, DenDiv: array of Double;
  Cred, LogA, LogD, DivW, DivLogA, DivLogD, TeamW, BaseA, BaseD, Share: array of Double;
  LamH, LamA: array of Double;
  Safe, Tw: Double;
  Res: TaRatingSet;
begin
  Result := nil;
  if Length(ARows) < 20 then Exit;
  Cutoff := ARef - Trunc(C.Lookback);
  { prozor: prije ref_date i unutar lookbacka; zatim tezine; tezine ispod 1e-6 otpadaju }
  N := 0;
  SetLength(Keep, Length(ARows));
  SetLength(Wt, Length(ARows));
  for I := 0 to High(ARows) do
  begin
    if (ARows[I].Day >= ARef) or (ARows[I].Day < Cutoff) then Continue;
    W := Power(0.5, Max(ARef - ARows[I].Day, 0) / C.HalfLife);
    if W <= 1e-6 then Continue;
    Keep[N] := ARows[I]; Wt[N] := W; Inc(N);
  end;
  if N < 20 then Exit;
  SetLength(Keep, N); SetLength(Wt, N);

  Teams := TStringList.Create; Divs := TStringList.Create;
  try
    Teams.CaseSensitive := True; Divs.CaseSensitive := True;
    Teams.Sorted := True; Teams.Duplicates := dupIgnore;
    Divs.Sorted := True; Divs.Duplicates := dupIgnore;
    for I := 0 to N - 1 do
    begin
      Teams.Add(Keep[I].Home); Teams.Add(Keep[I].Away); Divs.Add(Keep[I].Div_);
    end;
    NT := Teams.Count; ND := Divs.Count;
    SetLength(HI, N); SetLength(AI, N); SetLength(DI, N); SetLength(HG, N); SetLength(AG, N);
    for I := 0 to N - 1 do
    begin
      HI[I] := Teams.IndexOf(Keep[I].Home); AI[I] := Teams.IndexOf(Keep[I].Away); DI[I] := Divs.IndexOf(Keep[I].Div_);
      GoalsOf(Keep[I], AMode, Hg1, Ag1);
      HG[I] := Hg1; AG[I] := Ag1;
    end;
    SetLength(GoalsFor, NT); SetLength(GoalsAgainst, NT); SetLength(Eff, NT);
    SetLength(Exposure, NT * ND);
    for I := 0 to NT - 1 do begin GoalsFor[I] := 0; GoalsAgainst[I] := 0; Eff[I] := 0; end;
    for I := 0 to NT * ND - 1 do Exposure[I] := 0;
    GoalsHomeTotal := 0; SumW := 0; SumG := 0;
    SetLength(DivGoalTotals, ND);
    for I := 0 to ND - 1 do DivGoalTotals[I] := 0;
    for I := 0 to N - 1 do
    begin
      GoalsFor[HI[I]] := GoalsFor[HI[I]] + Wt[I] * HG[I];
      GoalsFor[AI[I]] := GoalsFor[AI[I]] + Wt[I] * AG[I];
      GoalsAgainst[HI[I]] := GoalsAgainst[HI[I]] + Wt[I] * AG[I];
      GoalsAgainst[AI[I]] := GoalsAgainst[AI[I]] + Wt[I] * HG[I];
      Eff[HI[I]] := Eff[HI[I]] + Wt[I];
      Eff[AI[I]] := Eff[AI[I]] + Wt[I];
      Exposure[HI[I] * ND + DI[I]] := Exposure[HI[I] * ND + DI[I]] + Wt[I];
      Exposure[AI[I] * ND + DI[I]] := Exposure[AI[I] * ND + DI[I]] + Wt[I];
      GoalsHomeTotal := GoalsHomeTotal + Wt[I] * HG[I];
      DivGoalTotals[DI[I]] := DivGoalTotals[DI[I]] + Wt[I] * (HG[I] + AG[I]);
      SumW := SumW + Wt[I];
      SumG := SumG + Wt[I] * (HG[I] + AG[I]);
    end;

    SetLength(Att, NT); SetLength(Def, NT); SetLength(Mu, ND); SetLength(Den, NT);
    SetLength(Prev, 2 * NT + ND + 1); SetLength(DenDiv, ND);
    for I := 0 to NT - 1 do begin Att[I] := 1.0; Def[I] := 1.0; end;
    Gamma := 1.25;
    for I := 0 to ND - 1 do Mu[I] := Max(SumG / SumW / 2.0, 1e-3);
    Prior := C.PriorGoals;

    for It := 1 to C.MaxIter do
    begin
      for I := 0 to NT - 1 do begin Prev[I] := Att[I]; Prev[NT + I] := Def[I]; end;
      for I := 0 to ND - 1 do Prev[2 * NT + I] := Mu[I];
      Prev[2 * NT + ND] := Gamma;

      { napad }
      for I := 0 to NT - 1 do Den[I] := 0;
      for I := 0 to N - 1 do
      begin
        MuM := Mu[DI[I]];
        Den[HI[I]] := Den[HI[I]] + Wt[I] * MuM * Def[AI[I]] * Gamma;
      end;
      for I := 0 to N - 1 do
      begin
        MuM := Mu[DI[I]];
        Den[AI[I]] := Den[AI[I]] + Wt[I] * MuM * Def[HI[I]];
      end;
      for I := 0 to NT - 1 do
        if Den[I] + Prior > 1e-12 then Att[I] := (GoalsFor[I] + Prior) / (Den[I] + Prior) else Att[I] := 1.0;

      { obrana }
      for I := 0 to NT - 1 do Den[I] := 0;
      for I := 0 to N - 1 do
      begin
        MuM := Mu[DI[I]];
        Den[HI[I]] := Den[HI[I]] + Wt[I] * MuM * Att[AI[I]];
      end;
      for I := 0 to N - 1 do
      begin
        MuM := Mu[DI[I]];
        Den[AI[I]] := Den[AI[I]] + Wt[I] * MuM * Att[HI[I]] * Gamma;
      end;
      for I := 0 to NT - 1 do
        if Den[I] + Prior > 1e-12 then Def[I] := (GoalsAgainst[I] + Prior) / (Den[I] + Prior) else Def[I] := 1.0;

      { prednost domaceg terena }
      DenGamma := 0;
      for I := 0 to N - 1 do DenGamma := DenGamma + Wt[I] * Mu[DI[I]] * Att[HI[I]] * Def[AI[I]];
      if DenGamma > 1e-12 then Gamma := GoalsHomeTotal / DenGamma;

      { razina golova po ligi }
      for I := 0 to ND - 1 do DenDiv[I] := 0;
      for I := 0 to N - 1 do
      begin
        Contrib := Wt[I] * (Att[HI[I]] * Def[AI[I]] * Gamma + Att[AI[I]] * Def[HI[I]]);
        DenDiv[DI[I]] := DenDiv[DI[I]] + Contrib;
      end;
      for I := 0 to ND - 1 do
        if DenDiv[I] > 1e-12 then Mu[I] := DivGoalTotals[I] / DenDiv[I];

      { skala: geometrijska sredina obje ocjene = 1, razinu nosi mu }
      for I := 0 to NT - 1 do begin Att[I] := Max(Att[I], 1e-6); Def[I] := Max(Def[I], 1e-6); end;
      ScaleA := 0; ScaleD := 0;
      for I := 0 to NT - 1 do begin ScaleA := ScaleA + Ln(Att[I]); ScaleD := ScaleD + Ln(Def[I]); end;
      ScaleA := Exp(ScaleA / NT); ScaleD := Exp(ScaleD / NT);
      for I := 0 to NT - 1 do begin Att[I] := Att[I] / ScaleA; Def[I] := Def[I] / ScaleD; end;
      for I := 0 to ND - 1 do Mu[I] := Mu[I] * ScaleA * ScaleD;

      MaxDiff := 0;
      for I := 0 to NT - 1 do
      begin
        MaxDiff := Max(MaxDiff, Abs(Att[I] - Prev[I]));
        MaxDiff := Max(MaxDiff, Abs(Def[I] - Prev[NT + I]));
      end;
      for I := 0 to ND - 1 do MaxDiff := Max(MaxDiff, Abs(Mu[I] - Prev[2 * NT + I]));
      MaxDiff := Max(MaxDiff, Abs(Gamma - Prev[2 * NT + ND]));
      if MaxDiff < C.Tol then Break;
    end;

    { shrinkage prema prosjeku lige u kojoj klub igra }
    SetLength(Cred, NT); SetLength(LogA, NT); SetLength(LogD, NT);
    SetLength(DivW, ND); SetLength(DivLogA, ND); SetLength(DivLogD, ND);
    SetLength(TeamW, NT); SetLength(BaseA, NT); SetLength(BaseD, NT);
    for I := 0 to NT - 1 do
    begin
      Cred[I] := Eff[I] / (Eff[I] + C.ShrinkMatches);
      LogA[I] := Ln(Att[I]); LogD[I] := Ln(Def[I]);
    end;
    for K := 0 to ND - 1 do
    begin
      DivW[K] := 0; DivLogA[K] := 0; DivLogD[K] := 0;
      for I := 0 to NT - 1 do
      begin
        DivW[K] := DivW[K] + Exposure[I * ND + K];
        DivLogA[K] := DivLogA[K] + Exposure[I * ND + K] * LogA[I];
        DivLogD[K] := DivLogD[K] + Exposure[I * ND + K] * LogD[I];
      end;
      if DivW[K] > 1e-12 then Safe := DivW[K] else Safe := 1.0;
      DivLogA[K] := DivLogA[K] / Safe; DivLogD[K] := DivLogD[K] / Safe;
    end;
    for I := 0 to NT - 1 do
    begin
      Tw := 0;
      for K := 0 to ND - 1 do Tw := Tw + Exposure[I * ND + K];
      if Tw <= 1e-12 then Tw := 1.0;
      BaseA[I] := 0; BaseD[I] := 0;
      for K := 0 to ND - 1 do
      begin
        BaseA[I] := BaseA[I] + (Exposure[I * ND + K] / Tw) * DivLogA[K];
        BaseD[I] := BaseD[I] + (Exposure[I * ND + K] / Tw) * DivLogD[K];
      end;
      Att[I] := Exp(BaseA[I] + Cred[I] * (LogA[I] - BaseA[I]));
      Def[I] := Exp(BaseD[I] + Cred[I] * (LogD[I] - BaseD[I]));
    end;

    SetLength(LamH, N); SetLength(LamA, N);
    for I := 0 to N - 1 do
    begin
      LamH[I] := Mu[DI[I]] * Att[HI[I]] * Def[AI[I]] * Gamma;
      LamA[I] := Mu[DI[I]] * Att[AI[I]] * Def[HI[I]];
    end;

    Res := TaRatingSet.Create;
    Res.Teams.Assign(Teams);
    Res.Divs.Assign(Divs);
    Res.Attack := Copy(Att); Res.Defence := Copy(Def); Res.Eff := Copy(Eff); Res.DivLevel := Copy(Mu);
    Res.Gamma := Gamma;
    Res.Rho := FitRho(HG, AG, LamH, LamA, Wt, C);
    Result := Res;
  finally
    Teams.Free; Divs.Free;
  end;
end;

{ ---------------- profili stanja igre (gamestate.py) ---------------- }

constructor TaProfiles.Create;
begin
  Teams := TStringList.Create;
  Teams.CaseSensitive := True;
end;

destructor TaProfiles.Destroy;
begin
  Teams.Free;
  inherited Destroy;
end;

function TaProfiles.CloserIndex(const ATeam: string): Double;
var
  Atk, Def, League: Double;
begin
  Multipliers(ATeam, 0, Atk, Def);
  League := LeagueAtk[0] + LeagueDef[0];
  Result := League / Max(Atk + Def, 1e-6);
end;

function TaProfiles.ChaosIndex(const ATeam: string): Double;
var
  Atk, Def, League: Double;
begin
  Multipliers(ATeam, 2, Atk, Def);
  League := LeagueAtk[2] + LeagueDef[2];
  Result := (Atk + Def) / Max(League, 1e-6);
end;

procedure TaProfiles.Rates(const ATeam: string; out AComeback, ACollapse: Double);
var
  I: Integer;
begin
  I := Teams.IndexOf(ATeam);
  if (I < 0) or (I >= Length(ComebackRate)) then begin AComeback := 0; ACollapse := 0; end
  else begin AComeback := ComebackRate[I]; ACollapse := CollapseRate[I]; end;
end;

procedure TaProfiles.Multipliers(const ATeam: string; AState: Integer; out Atk, Def: Double);
var
  I: Integer;
begin
  I := Teams.IndexOf(ATeam);
  if I < 0 then begin Atk := LeagueAtk[AState]; Def := LeagueDef[AState]; end
  else begin Atk := AtkMult[I * 3 + AState]; Def := DefMult[I * 3 + AState]; end;
end;

function FitProfiles(const AHalves: TaMatchRows; ARef: Integer; ASh: TaRatingSet; const C: TaModelCfg): TaProfiles;
var
  I, S, N, NT, Cutoff: Integer;
  Keep: TaMatchRows;
  Wt: array of Double;
  W: Double;
  Teams: TStringList;
  HI, AI, HS, AS_: array of Integer;
  ShH, ShA, ExpH, ExpA: Double;
  Scored, Conceded, ExpScored, ExpConceded: array of Double;
  Res: TaProfiles;
  SumA, SumB: Double;
  LeagueA, LeagueD: array[0..2] of Double;
  CbH, CbT, ClH, ClT: array of Double;

  procedure Shrink(const AObs, AExp: array of Double; const ALeague: array of Double; out AOut: array of Double);
  var
    T, K: Integer;
    Cr, Raw, Ratio, V: Double;
  begin
    for T := 0 to NT - 1 do
      for K := 0 to 2 do
      begin
        Cr := AExp[T * 3 + K] / (AExp[T * 3 + K] + C.StateShrink);
        if AExp[T * 3 + K] > 1e-9 then Raw := AObs[T * 3 + K] / AExp[T * 3 + K] else Raw := 1.0;
        if ALeague[K] > 1e-9 then Ratio := Raw / ALeague[K] else Ratio := 1.0;
        V := ALeague[K] * Power(Ratio, Cr);
        AOut[T * 3 + K] := Min(Max(V, C.StateLo), C.StateHi);
      end;
  end;

begin
  Result := nil;
  Cutoff := ARef - Trunc(C.Lookback);
  N := 0;
  SetLength(Keep, Length(AHalves)); SetLength(Wt, Length(AHalves));
  { prvi prag od 50 gleda cijeli okvir u prozoru, prije tezina }
  for I := 0 to High(AHalves) do
  begin
    if (AHalves[I].Day >= ARef) or (AHalves[I].Day < Cutoff) then Continue;
    Keep[N] := AHalves[I]; Inc(N);
  end;
  if N < 50 then Exit;
  SetLength(Keep, N);
  SetLength(Wt, N);
  S := 0;
  for I := 0 to N - 1 do
  begin
    W := Power(0.5, Max(ARef - Keep[I].Day, 0) / C.HalfLife);
    if W <= 1e-6 then Continue;
    Keep[S] := Keep[I]; Wt[S] := W; Inc(S);
  end;
  N := S;
  if N < 50 then Exit;
  SetLength(Keep, N); SetLength(Wt, N);

  Teams := TStringList.Create;
  try
    Teams.CaseSensitive := True; Teams.Sorted := True; Teams.Duplicates := dupIgnore;
    for I := 0 to N - 1 do begin Teams.Add(Keep[I].Home); Teams.Add(Keep[I].Away); end;
    NT := Teams.Count;
    SetLength(HI, N); SetLength(AI, N); SetLength(HS, N); SetLength(AS_, N);
    SetLength(Scored, NT * 3); SetLength(Conceded, NT * 3); SetLength(ExpScored, NT * 3); SetLength(ExpConceded, NT * 3);
    for I := 0 to NT * 3 - 1 do begin Scored[I] := 0; Conceded[I] := 0; ExpScored[I] := 0; ExpConceded[I] := 0; end;
    for I := 0 to N - 1 do
    begin
      HI[I] := Teams.IndexOf(Keep[I].Home); AI[I] := Teams.IndexOf(Keep[I].Away);
      if Keep[I].Hthg > Keep[I].Htag then HS[I] := 0 else if Keep[I].Hthg = Keep[I].Htag then HS[I] := 1 else HS[I] := 2;
      if Keep[I].Htag > Keep[I].Hthg then AS_[I] := 0 else if Keep[I].Hthg = Keep[I].Htag then AS_[I] := 1 else AS_[I] := 2;
      ShH := Max(Keep[I].Fthg - Keep[I].Hthg, 0);
      ShA := Max(Keep[I].Ftag - Keep[I].Htag, 0);
      ASh.ExpectedGoals(Keep[I].Div_, Keep[I].Home, Keep[I].Away, ExpH, ExpA);
      Scored[HI[I] * 3 + HS[I]] := Scored[HI[I] * 3 + HS[I]] + Wt[I] * ShH;
      Scored[AI[I] * 3 + AS_[I]] := Scored[AI[I] * 3 + AS_[I]] + Wt[I] * ShA;
      Conceded[HI[I] * 3 + HS[I]] := Conceded[HI[I] * 3 + HS[I]] + Wt[I] * ShA;
      Conceded[AI[I] * 3 + AS_[I]] := Conceded[AI[I] * 3 + AS_[I]] + Wt[I] * ShH;
      ExpScored[HI[I] * 3 + HS[I]] := ExpScored[HI[I] * 3 + HS[I]] + Wt[I] * ExpH;
      ExpScored[AI[I] * 3 + AS_[I]] := ExpScored[AI[I] * 3 + AS_[I]] + Wt[I] * ExpA;
      ExpConceded[HI[I] * 3 + HS[I]] := ExpConceded[HI[I] * 3 + HS[I]] + Wt[I] * ExpA;
      ExpConceded[AI[I] * 3 + AS_[I]] := ExpConceded[AI[I] * 3 + AS_[I]] + Wt[I] * ExpH;
    end;
    for S := 0 to 2 do
    begin
      SumA := 0; SumB := 0;
      for I := 0 to NT - 1 do begin SumA := SumA + Scored[I * 3 + S]; SumB := SumB + ExpScored[I * 3 + S]; end;
      if SumB > 1e-9 then LeagueA[S] := SumA / SumB else LeagueA[S] := 1.0;
      SumA := 0; SumB := 0;
      for I := 0 to NT - 1 do begin SumA := SumA + Conceded[I * 3 + S]; SumB := SumB + ExpConceded[I * 3 + S]; end;
      if SumB > 1e-9 then LeagueD[S] := SumA / SumB else LeagueD[S] := 1.0;
    end;
    Res := TaProfiles.Create;
    Res.Teams.Assign(Teams);
    SetLength(Res.AtkMult, NT * 3); SetLength(Res.DefMult, NT * 3);
    Shrink(Scored, ExpScored, LeagueA, Res.AtkMult);
    Shrink(Conceded, ExpConceded, LeagueD, Res.DefMult);
    for S := 0 to 2 do begin Res.LeagueAtk[S] := LeagueA[S]; Res.LeagueDef[S] := LeagueD[S]; end;
    { povratak i slom: tezinska ucestalost pobjede kad se gubi na poluvremenu, odnosno ne-pobjede kad se vodi }
    SetLength(Res.ComebackRate, NT); SetLength(Res.CollapseRate, NT);
    SetLength(CbH, NT); SetLength(CbT, NT); SetLength(ClH, NT); SetLength(ClT, NT);
    for I := 0 to NT - 1 do begin CbH[I] := 0; CbT[I] := 0; ClH[I] := 0; ClT[I] := 0; end;
    for I := 0 to N - 1 do
    begin
      if HS[I] = 2 then begin CbT[HI[I]] := CbT[HI[I]] + Wt[I]; if Keep[I].Fthg > Keep[I].Ftag then CbH[HI[I]] := CbH[HI[I]] + Wt[I]; end;
      if AS_[I] = 2 then begin CbT[AI[I]] := CbT[AI[I]] + Wt[I]; if Keep[I].Ftag > Keep[I].Fthg then CbH[AI[I]] := CbH[AI[I]] + Wt[I]; end;
      if HS[I] = 0 then begin ClT[HI[I]] := ClT[HI[I]] + Wt[I]; if not (Keep[I].Fthg > Keep[I].Ftag) then ClH[HI[I]] := ClH[HI[I]] + Wt[I]; end;
      if AS_[I] = 0 then begin ClT[AI[I]] := ClT[AI[I]] + Wt[I]; if not (Keep[I].Ftag > Keep[I].Fthg) then ClH[AI[I]] := ClH[AI[I]] + Wt[I]; end;
    end;
    for I := 0 to NT - 1 do
    begin
      if CbT[I] > 1e-9 then Res.ComebackRate[I] := CbH[I] / CbT[I] else Res.ComebackRate[I] := 0;
      if ClT[I] > 1e-9 then Res.CollapseRate[I] := ClH[I] / ClT[I] else Res.CollapseRate[I] := 0;
    end;
    Result := Res;
  finally
    Teams.Free;
  end;
end;

destructor TaBundle.Destroy;
begin
  Profiles.Free;
  if OwnsHalves then begin Ht.Free; Sh.Free; end;
  Ft.Free;
  inherited Destroy;
end;

{ ---------------- matrica rezultata i trzista (markets.py) ---------------- }

procedure PoissonPmf(AMax: Integer; ALam: Double; out P: array of Double);
var
  G: Integer;
  Lf: Double;
begin
  Lf := 0;
  for G := 0 to AMax do
  begin
    if G > 0 then Lf := Lf + Ln(G);
    P[G] := Exp(G * Ln(ALam) - ALam - Lf);
  end;
end;

function ScoreMatrix(ALamH, ALamA, ARho: Double; AMax: Integer): TMatrix;
var
  Ph, Pa: array of Double;
  I, J: Integer;
  Tot, T00, T01, T10, T11: Double;
begin
  ALamH := Max(ALamH, 1e-6); ALamA := Max(ALamA, 1e-6);
  SetLength(Ph, AMax + 1); SetLength(Pa, AMax + 1);
  PoissonPmf(AMax, ALamH, Ph); PoissonPmf(AMax, ALamA, Pa);
  SetLength(Result, AMax + 1, AMax + 1);
  for I := 0 to AMax do
    for J := 0 to AMax do Result[I][J] := Ph[I] * Pa[J];
  if ARho <> 0 then
  begin
    T00 := 1.0 - ALamH * ALamA * ARho;
    T01 := 1.0 + ALamH * ARho;
    T10 := 1.0 + ALamA * ARho;
    T11 := 1.0 - ARho;
    if (T00 > 0) and (T01 > 0) and (T10 > 0) and (T11 > 0) then
    begin
      Result[0][0] := Result[0][0] * T00;
      Result[0][1] := Result[0][1] * T01;
      Result[1][0] := Result[1][0] * T10;
      Result[1][1] := Result[1][1] * T11;
    end;
  end;
  Tot := 0;
  for I := 0 to AMax do for J := 0 to AMax do Tot := Tot + Result[I][J];
  if Tot > 0 then
    for I := 0 to AMax do for J := 0 to AMax do Result[I][J] := Result[I][J] / Tot;
end;

function CalibrateOu(AOver, ASlope, AShift: Double): Double;
var
  P: Double;
begin
  P := Min(Max(AOver, 1e-9), 1.0 - 1e-9);
  Result := 1.0 / (1.0 + Exp(-(ASlope * Ln(P / (1.0 - P)) + AShift)));
end;

procedure AddItem(var AP: TaPrediction; const AMarket, ASel: string; AValue: Double);
var
  N: Integer;
begin
  N := Length(AP.Items);
  SetLength(AP.Items, N + 1);
  AP.Items[N].Market := AMarket; AP.Items[N].Selection := ASel; AP.Items[N].P := AValue;
end;

function ItemIndex(const AP: TaPrediction; const AMarket, ASel: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(AP.Items) do
    if (AP.Items[I].Market = AMarket) and (AP.Items[I].Selection = ASel) then Exit(I);
  Result := -1;
end;

procedure HtOrFt(const AHtft: array of Double; out P1, PX, P2: Double);
begin
  { indeksi: 0 1/1, 1 1/X, 2 1/2, 3 X/1, 4 X/X, 5 X/2, 6 2/1, 7 2/X, 8 2/2 }
  P1 := AHtft[0] + AHtft[1] + AHtft[2] + AHtft[3] + AHtft[6];
  PX := AHtft[3] + AHtft[4] + AHtft[5] + AHtft[1] + AHtft[7];
  P2 := AHtft[6] + AHtft[7] + AHtft[8] + AHtft[2] + AHtft[5];
end;

{ ---------------- predviđač (predictor.py + rounds.py) ---------------- }

constructor TaPredictor.Create(ADb: TAppDb);
begin
  FDb := ADb;
  FCache := TStringList.Create;
  FCache.CaseSensitive := True;
  FPreds := TStringList.Create;
  FPreds.CaseSensitive := True;
  Cfg := DefaultModelCfg;
end;

procedure TaAltEngine.Clear;
begin
end;

procedure TaPredictor.SetModel(const AModel: string);
begin
  Clear;
  FreeAndNil(Alt);
  if (AModel = '') or (LowerCase(AModel) = 'poisson') then Exit;
  if Assigned(AltEngineFactory) then Alt := AltEngineFactory(FDb, LowerCase(AModel));
  if Alt = nil then raise Exception.Create(Tr('Unknown model "') + AModel + Tr('", expected poisson, newton or market'));
end;

destructor TaPredictor.Destroy;
begin
  Clear;
  Alt.Free;
  FCache.Free;
  FPreds.Free;
  inherited Destroy;
end;

procedure TaPredictor.Clear;
var
  I: Integer;
begin
  if Alt <> nil then Alt.Clear;
  for I := 0 to FCache.Count - 1 do FCache.Objects[I].Free;
  FCache.Clear;
  for I := 0 to FPreds.Count - 1 do FPreds.Objects[I].Free;
  FPreds.Clear;
end;

function TaPredictor.LoadRows(const ADivs: array of string; ARef: Integer): TaMatchRows;
var
  Q: TZQuery;
  In_: string;
  I, N: Integer;
begin
  In_ := '';
  for I := 0 to High(ADivs) do
  begin
    if In_ <> '' then In_ := In_ + ',';
    In_ := In_ + '''' + StringReplace(ADivs[I], '''', '''''', [rfReplaceAll]) + '''';
  end;
  Q := FDb.NewQuery('SELECT division, matchdate, hometeam, awayteam, fthg, ftag, hthg, htag FROM matches ' +
    'WHERE division IN (' + In_ + ') AND matchdate < :b AND matchdate >= :s ORDER BY matchdate, match_id');
  try
    Q.ParamByName('b').AsString := TextOfDay(ARef);
    Q.ParamByName('s').AsString := TextOfDay(ARef - Trunc(Cfg.Lookback));
    Q.Open;
    N := 0;
    SetLength(Result, 4096);
    while not Q.Eof do
    begin
      if N >= Length(Result) then SetLength(Result, Length(Result) * 2);
      Result[N].Div_ := Q.Fields[0].AsString;
      Result[N].Day := DayOfText(Q.Fields[1].AsString);
      Result[N].Home := Q.Fields[2].AsString;
      Result[N].Away := Q.Fields[3].AsString;
      Result[N].Fthg := Q.Fields[4].AsInteger;
      Result[N].Ftag := Q.Fields[5].AsInteger;
      Result[N].HasHt := (not Q.Fields[6].IsNull) and (not Q.Fields[7].IsNull);
      if Result[N].HasHt then begin Result[N].Hthg := Q.Fields[6].AsInteger; Result[N].Htag := Q.Fields[7].AsInteger; end
      else begin Result[N].Hthg := 0; Result[N].Htag := 0; end;
      Inc(N);
      Q.Next;
    end;
    SetLength(Result, N);
  finally
    Q.Free;
  end;
end;

function TaPredictor.BundleFor(const ADiv: string; ARef: Integer): TaBundle;
var
  Divs: TStringArray;
  Key: string;
  I, N: Integer;
  Rows, Halves: TaMatchRows;
  B: TaBundle;
  NoHalf: Boolean;
  Ft, Ht, Sh: TaRatingSet;
  Prof: TaProfiles;
  Tabs: TStringList;
  HasMatches: Boolean;
begin
  Divs := GroupOfDivision(ADiv);
  Key := '';
  for I := 0 to High(Divs) do Key := Key + Divs[I] + ',';
  Key := Key + '|' + IntToStr(ARef);
  I := FCache.IndexOf(Key);
  if I >= 0 then Exit(TaBundle(FCache.Objects[I]));

  B := nil;
  { baza bez tablice utakmica nema predvidanja (a ne gresku); PredictReset to ponovno provjerava }
  Tabs := FDb.UserTables;
  try
    HasMatches := Tabs.IndexOf('matches') >= 0;
  finally
    Tabs.Free;
  end;
  if not HasMatches then
  begin
    FCache.AddObject(Key, nil);
    Exit(nil);
  end;
  Rows := LoadRows(Divs, ARef);
  Ft := FitRatings(Rows, ARef, 0, Cfg);
  if Ft <> nil then
  begin
    NoHalf := True;
    for I := 0 to High(Divs) do
      if Pos(',' + Divs[I] + ',', NoHalfTime) = 0 then NoHalf := False;
    N := 0;
    SetLength(Halves, 0);
    if not NoHalf then
    begin
      SetLength(Halves, Length(Rows));
      for I := 0 to High(Rows) do
        if Rows[I].HasHt then begin Halves[N] := Rows[I]; Inc(N); end;
      SetLength(Halves, N);
    end;
    Ht := nil; Sh := nil; Prof := nil;
    if Length(Halves) >= 50 then
    begin
      Ht := FitRatings(Halves, ARef, 1, Cfg);
      Sh := FitRatings(Halves, ARef, 2, Cfg);
      if Sh <> nil then Prof := FitProfiles(Halves, ARef, Sh, Cfg);
    end;
    B := TaBundle.Create;
    B.Ft := Ft;
    B.HalfFitted := (Ht <> nil) and (Sh <> nil);
    if B.HalfFitted then
    begin
      B.Ht := Ht; B.Sh := Sh; B.Profiles := Prof; B.OwnsHalves := True;
    end
    else
    begin
      Ht.Free; Sh.Free; Prof.Free;
      B.Ht := Ft.Copy_Halved; B.Sh := Ft.Copy_Halved; B.Profiles := nil; B.OwnsHalves := True;
    end;
  end;
  FCache.AddObject(Key, B);
  Result := B;
end;

function TaPredictor.DivisionProfiles(const ADiv: string; ARef: Integer): TaProfiles;
var
  Rows, Halves: TaMatchRows;
  Sh: TaRatingSet;
  I, N: Integer;
  Tabs: TStringList;
  Has: Boolean;
begin
  Result := nil;
  Tabs := FDb.UserTables;
  try
    Has := Tabs.IndexOf('matches') >= 0;
  finally
    Tabs.Free;
  end;
  if not Has then Exit;
  Rows := LoadRows([ADiv], ARef);
  N := 0;
  SetLength(Halves, Length(Rows));
  for I := 0 to High(Rows) do
    if Rows[I].HasHt then begin Halves[N] := Rows[I]; Inc(N); end;
  SetLength(Halves, N);
  if N < 50 then Exit;
  Sh := FitRatings(Halves, ARef, 2, Cfg);
  if Sh = nil then Exit;
  try
    Result := FitProfiles(Halves, ARef, Sh, Cfg);
  finally
    Sh.Free;
  end;
end;

function TaPredictor.ScalarStr(const ASql: string; const AParams: array of string): string;
var
  Q: TZQuery;
  I: Integer;
begin
  Result := '';
  Q := FDb.NewQuery(ASql);
  try
    for I := 0 to High(AParams) do Q.Params[I].AsString := AParams[I];
    Q.Open;
    if not Q.Eof then Result := Q.Fields[0].AsString;
  finally
    Q.Free;
  end;
end;

{ Je li utakmica zadnje kolo sezone za oba kluba (rounds.is_last_round) }
function TaPredictor.IsLastRound(const ADiv, AHome, AAway: string; ARef: Integer): Boolean;
var
  Before, Season, Prev: string;
  Counts: array of Integer;
  I, J, Tmp, NowTeams, Len: Integer;
  Median, LenF: Double;

  function TeamCounts(const ASeason: string): Integer;
  var
    Q2: TZQuery;
    N: Integer;
  begin
    Q2 := FDb.NewQuery('SELECT COUNT(*) FROM (SELECT hometeam AS team FROM matches WHERE division = :d AND season = :s ' +
      'UNION ALL SELECT awayteam FROM matches WHERE division = :d2 AND season = :s2) GROUP BY team');
    try
      Q2.ParamByName('d').AsString := ADiv; Q2.ParamByName('s').AsString := ASeason;
      Q2.ParamByName('d2').AsString := ADiv; Q2.ParamByName('s2').AsString := ASeason;
      Q2.Open;
      N := 0;
      SetLength(Counts, 0);
      while not Q2.Eof do
      begin
        SetLength(Counts, N + 1);
        Counts[N] := Q2.Fields[0].AsInteger;
        Inc(N);
        Q2.Next;
      end;
      Result := N;
    finally
      Q2.Free;
    end;
  end;

  function Played(const ATeam: string): Integer;
  begin
    Result := StrToIntDef(ScalarStr('SELECT COUNT(*) FROM matches WHERE division = :d AND season = :s AND matchdate < :b ' +
      'AND (hometeam = :t OR awayteam = :t2)', [ADiv, Season, Before, ATeam, ATeam]), 0);
  end;

begin
  Result := False;
  Before := TextOfDay(ARef);
  Season := ScalarStr('SELECT season FROM matches WHERE division = :d AND matchdate < :b ORDER BY matchdate DESC LIMIT 1', [ADiv, Before]);
  if Season = '' then Exit;
  Prev := ScalarStr('SELECT season FROM matches WHERE division = :d AND season < :s ORDER BY season DESC LIMIT 1', [ADiv, Season]);
  if Prev = '' then Exit;
  J := TeamCounts(Prev);
  if J < 6 then Exit;
  { medijan broja utakmica po klubu prosle sezone }
  for I := 0 to J - 2 do
    for Tmp := I + 1 to J - 1 do
      if Counts[Tmp] < Counts[I] then begin Len := Counts[I]; Counts[I] := Counts[Tmp]; Counts[Tmp] := Len; end;
  if Odd(J) then Median := Counts[J div 2] else Median := (Counts[J div 2 - 1] + Counts[J div 2]) / 2.0;
  LenF := Median;
  NowTeams := TeamCounts(Season);
  if (NowTeams >= 6) and (NowTeams <> J) then LenF := LenF * (NowTeams - 1) / (J - 1);
  Len := Round(LenF);
  Result := (Played(AHome) = Len - 1) and (Played(AAway) = Len - 1);
end;

function TaPredictor.Predict(const ADiv, AHome, AAway: string; ARef: Integer): TaPrediction;
var
  B: TaBundle;
  XgH, XgA, HtH, HtA, ShH, ShA, LamH, LamA, AtkH, DefH, AtkA, DefA: Double;
  Mf: TMatrix;
  Hm: TMatrix;
  Sm: array[0..2] of TMatrix;
  I, J, S, H1, A1, Sz, FinalH, FinalA, Lab: Integer;
  Home_, Draw_, Away_, Pw, Tot, BYes, PHt, Over: Double;
  Htft: array[0..8] of Double;
  HsState: array[0..2, 0..1] of Integer;
  Overs: array[0..2] of Double;
begin
  Result.Ok := False; Result.LastRound := False; Result.Notes := ''; SetLength(Result.Items, 0);
  if Alt <> nil then Exit(Alt.Predict(ADiv, AHome, AAway, ARef));
  B := BundleFor(ADiv, ARef);
  if B = nil then Exit;
  Result.HalfTimeFitted := B.HalfFitted;
  if B.Ft.Teams.IndexOf(AHome) < 0 then Result.Notes := 'nema povijesti za ' + AHome + ' (prosjek lige)';
  if B.Ft.Teams.IndexOf(AAway) < 0 then
  begin
    if Result.Notes <> '' then Result.Notes := Result.Notes + '; ';
    Result.Notes := Result.Notes + 'nema povijesti za ' + AAway + ' (prosjek lige)';
  end;

  { --- puno vrijeme --- }
  B.Ft.ExpectedGoals(ADiv, AHome, AAway, XgH, XgA);
  Mf := ScoreMatrix(XgH, XgA, B.Ft.Rho, Cfg.MaxGoalsFt);
  Result.Matrix := Mf;
  Sz := Cfg.MaxGoalsFt;
  Home_ := 0; Draw_ := 0; Away_ := 0;
  for I := 0 to Sz do
    for J := 0 to Sz do
      if I > J then Home_ := Home_ + Mf[I][J]
      else if I = J then Draw_ := Draw_ + Mf[I][J]
      else Away_ := Away_ + Mf[I][J];
  if Cfg.CalPower <> 1.0 then
  begin
    Home_ := Power(Min(Max(Home_, 1e-12), 1.0), Cfg.CalPower);
    Draw_ := Power(Min(Max(Draw_, 1e-12), 1.0), Cfg.CalPower);
    Away_ := Power(Min(Max(Away_, 1e-12), 1.0), Cfg.CalPower);
    Tot := Home_ + Draw_ + Away_;
    Home_ := Home_ / Tot; Draw_ := Draw_ / Tot; Away_ := Away_ / Tot;
  end;
  BYes := 0;
  for I := 1 to Sz do for J := 1 to Sz do BYes := BYes + Mf[I][J];
  if Cfg.BttsOn then BYes := CalibrateOu(BYes, Cfg.BttsSlope, Cfg.BttsShift);

  AddItem(Result, '1X2', '1', Home_); AddItem(Result, '1X2', 'X', Draw_); AddItem(Result, '1X2', '2', Away_);
  AddItem(Result, 'DOUBLE_CHANCE', '1X', Home_ + Draw_);
  AddItem(Result, 'DOUBLE_CHANCE', '12', Home_ + Away_);
  AddItem(Result, 'DOUBLE_CHANCE', 'X2', Draw_ + Away_);
  AddItem(Result, 'BTTS', 'GG', BYes); AddItem(Result, 'BTTS', 'NG', 1.0 - BYes);
  for S := 0 to 2 do
  begin
    Over := 0;
    for I := 0 to Sz do for J := 0 to Sz do if I + J > OuValues[S] then Over := Over + Mf[I][J];
    if Cfg.OuOn then Over := CalibrateOu(Over, Cfg.OuSlope[S], Cfg.OuShift[S]);
    Overs[S] := Over;
  end;

  { --- poluvrijeme i drugo poluvrijeme ovisno o stanju --- }
  B.Ht.ExpectedGoals(ADiv, AHome, AAway, HtH, HtA);
  Hm := ScoreMatrix(HtH, HtA, B.Ht.Rho, Cfg.MaxGoalsHalf);
  B.Sh.ExpectedGoals(ADiv, AHome, AAway, ShH, ShA);
  { stanje: 0 domaci vodi, 1 izjednaceno, 2 domaci zaostaje }
  HsState[0][0] := 0; HsState[0][1] := 2;
  HsState[1][0] := 1; HsState[1][1] := 1;
  HsState[2][0] := 2; HsState[2][1] := 0;
  for S := 0 to 2 do
  begin
    LamH := ShH; LamA := ShA;
    if B.Profiles <> nil then
    begin
      B.Profiles.Multipliers(AHome, HsState[S][0], AtkH, DefH);
      B.Profiles.Multipliers(AAway, HsState[S][1], AtkA, DefA);
      LamH := ShH * Sqrt(AtkH * DefA);
      LamA := ShA * Sqrt(AtkA * DefH);
    end;
    Sm[S] := ScoreMatrix(LamH, LamA, B.Sh.Rho, Cfg.MaxGoalsHalf);
  end;

  if B.HalfFitted then
  begin
    for I := 0 to 8 do Htft[I] := 0;
    Sz := Cfg.MaxGoalsHalf;
    for H1 := 0 to Sz do
      for A1 := 0 to Sz do
      begin
        PHt := Hm[H1][A1];
        if PHt < 1e-12 then Continue;
        if H1 > A1 then begin S := 0; Lab := 0; end
        else if H1 = A1 then begin S := 1; Lab := 1; end
        else begin S := 2; Lab := 2; end;
        for I := 0 to Sz do
          for J := 0 to Sz do
          begin
            Pw := PHt * Sm[S][I][J];
            FinalH := H1 + I; FinalA := A1 + J;
            if FinalH > FinalA then Htft[Lab * 3 + 0] := Htft[Lab * 3 + 0] + Pw
            else if FinalH = FinalA then Htft[Lab * 3 + 1] := Htft[Lab * 3 + 1] + Pw
            else Htft[Lab * 3 + 2] := Htft[Lab * 3 + 2] + Pw;
          end;
      end;
    Tot := 0;
    for I := 0 to 8 do Tot := Tot + Htft[I];
    if Tot > 0 then for I := 0 to 8 do Htft[I] := Htft[I] / Tot;
  end;

  { --- zadnje kolo: pomak linije Over 2.5, linije ostaju poredane --- }
  if Cfg.LastRoundOn and IsLastRound(ADiv, AHome, AAway, ARef) then
  begin
    Result.LastRound := True;
    Overs[1] := CalibrateOu(Overs[1], 1.0, Cfg.LastRoundShift);
    for S := 1 to 2 do if Overs[S] > Overs[S - 1] then Overs[S] := Overs[S - 1];
  end;
  for S := 0 to 2 do
  begin
    AddItem(Result, 'OVER_UNDER', 'Over ' + OuLines[S], Overs[S]);
    AddItem(Result, 'OVER_UNDER', 'Under ' + OuLines[S], 1.0 - Overs[S]);
  end;
  if B.HalfFitted then
    for I := 0 to 8 do AddItem(Result, 'HTFT', HtftNames[I], Htft[I]);

  Result.XgH := XgH; Result.XgA := XgA; Result.XgHtH := HtH; Result.XgHtA := HtA;
  Result.Ok := True;
end;

function TaPredictor.PredictCached(const ADiv, AHome, AAway: string; ARef: Integer): TaPredBox;
var
  Key: string;
  I: Integer;
begin
  Key := ADiv + '|' + AHome + '|' + AAway + '|' + IntToStr(ARef);
  I := FPreds.IndexOf(Key);
  if I >= 0 then Exit(TaPredBox(FPreds.Objects[I]));
  Result := TaPredBox.Create;
  Result.Pred := Predict(ADiv, AHome, AAway, ARef);
  FPreds.AddObject(Key, Result);
end;

{ ---------------- funkcije izraza: Predict, PredictXG, PredictReset ---------------- }

var
  GPredictor: TaPredictor = nil;
  GPredictorDb: TAppDb = nil;
  GNewton: TaPredictor = nil;
  GNewtonDb: TAppDb = nil;
  GMarket: TaPredictor = nil;
  GMarketDb: TAppDb = nil;

function MarketForActiveDb: TaPredictor;
begin
  if (ActiveDb = nil) or not ActiveDb.Connected then Exit(nil);
  if (GMarket = nil) or (GMarketDb <> ActiveDb) then
  begin
    GMarket.Free;
    GMarket := TaPredictor.Create(ActiveDb);
    GMarket.SetModel('market');
    GMarketDb := ActiveDb;
  end;
  Result := GMarket;
end;

function NewtonForActiveDb: TaPredictor;
begin
  if (ActiveDb = nil) or not ActiveDb.Connected then Exit(nil);
  if (GNewton = nil) or (GNewtonDb <> ActiveDb) then
  begin
    GNewton.Free;
    GNewton := TaPredictor.Create(ActiveDb);
    GNewton.SetModel('newton');
    GNewtonDb := ActiveDb;
  end;
  Result := GNewton;
end;

function PredictorForActiveDb: TaPredictor;
begin
  if (ActiveDb = nil) or not ActiveDb.Connected then Exit(nil);
  if (GPredictor = nil) or (GPredictorDb <> ActiveDb) then
  begin
    GPredictor.Free;
    GPredictor := TaPredictor.Create(ActiveDb);
    GPredictorDb := ActiveDb;
  end;
  Result := GPredictor;
end;

function DayOfArg(const V: Variant): Integer;
var
  D: TDateTime;
begin
  if VarIsNull(V) or (VarToStr(V) = '') then Exit(Trunc(Date));
  if VarIsType(V, varDate) then Exit(Trunc(TDateTime(V)));
  if VarIsNumeric(V) then Exit(Trunc(Double(V)));
  if not ParseAnyDateTime(VarToStr(V), D) then raise EExpr.Create('Nije datum: ' + VarToStr(V));
  Result := Trunc(D);
end;

function ItemProb(const P: TaPrediction; const AMarket, ASel: string; out AValue: Double): Boolean;
var
  I: Integer;
  H: array[0..8] of Double;
  P1, PX, P2: Double;
begin
  Result := False;
  if UpperCase(AMarket) = 'HT_OR_FT' then
  begin
    for I := 0 to 8 do
    begin
      H[I] := 0;
      if ItemIndex(P, 'HTFT', HtftNames[I]) >= 0 then H[I] := P.Items[ItemIndex(P, 'HTFT', HtftNames[I])].P
      else Exit;
    end;
    HtOrFt(H, P1, PX, P2);
    if ASel = '1' then AValue := P1 else if UpperCase(ASel) = 'X' then AValue := PX else if ASel = '2' then AValue := P2 else Exit;
    Exit(True);
  end;
  for I := 0 to High(P.Items) do
    if SameText(P.Items[I].Market, AMarket) and SameText(P.Items[I].Selection, ASel) then
    begin
      AValue := P.Items[I].P;
      Exit(True);
    end;
end;

function PredictHookImpl(const AName: string; const A: array of Variant; N: Integer): Variant;
var
  Pr: TaPredictor;
  Box: TaPredBox;
  V: Double;
  Part: string;
begin
  Result := Null;
  if AName = 'predictreset' then
  begin
    if GPredictor <> nil then GPredictor.Clear;
    if GNewton <> nil then GNewton.Clear;
    if GMarket <> nil then GMarket.Clear;
    Exit;
  end;
  if AName = 'predictnewton' then Pr := NewtonForActiveDb
  else if AName = 'predictmarket' then Pr := MarketForActiveDb
  else Pr := PredictorForActiveDb;
  if Pr = nil then Exit;          { bez otvorene baze nema predvidanja }
  Box := Pr.PredictCached(VarToStr(A[0]), VarToStr(A[1]), VarToStr(A[2]), DayOfArg(A[3]));
  if not Box.Pred.Ok then Exit;
  if (AName = 'predict') or (AName = 'predictnewton') or (AName = 'predictmarket') then
  begin
    if ItemProb(Box.Pred, VarToStr(A[4]), VarToStr(A[5]), V) then Result := V;
  end
  else
  begin
    Part := LowerCase(VarToStr(A[4]));
    if Part = 'domaci' then Result := Box.Pred.XgH
    else if Part = 'gosti' then Result := Box.Pred.XgA
    else if Part = 'domaci_poluvrijeme' then Result := Box.Pred.XgHtH
    else if Part = 'gosti_poluvrijeme' then Result := Box.Pred.XgHtA
    else raise EExpr.Create('PredictXG: dio je domaci, gosti, domaci_poluvrijeme ili gosti_poluvrijeme');
  end;
end;

procedure WritePredictions(ADb: TAppDb; AFixtures: TStrings; const ARef: string; const AModel: string);
var
  Pr: TaPredictor;
  I, J, P1, P2: Integer;
  L, Line: string;
  R: TaPrediction;
  Fs: TFormatSettings;
begin
  Fs := DefaultFormatSettings;
  Fs.DecimalSeparator := '.';
  Pr := TaPredictor.Create(ADb);
  try
    Pr.SetModel(AModel);
    for I := 0 to AFixtures.Count - 1 do
    begin
      L := Trim(AFixtures[I]);
      if L = '' then Continue;
      P1 := Pos(';', L);
      P2 := PosEx(';', L, P1 + 1);
      R := Pr.Predict(Copy(L, 1, P1 - 1), Copy(L, P1 + 1, P2 - P1 - 1), Copy(L, P2 + 1, MaxInt), DayOfText(ARef));
      if not R.Ok then begin WriteLn(L, ';NONE'); Continue; end;
      Line := L + ';' + FloatToStrF(R.XgH, ffGeneral, 17, 0, Fs) + ';' + FloatToStrF(R.XgA, ffGeneral, 17, 0, Fs) + ';' +
        FloatToStrF(R.XgHtH, ffGeneral, 17, 0, Fs) + ';' + FloatToStrF(R.XgHtA, ffGeneral, 17, 0, Fs);
      for J := 0 to High(R.Items) do
        Line := Line + ';' + R.Items[J].Market + '|' + R.Items[J].Selection + '=' + FloatToStrF(R.Items[J].P, ffGeneral, 17, 0, Fs);
      WriteLn(Line);
    end;
  finally
    Pr.Free;
  end;
end;

initialization
  PredictHook := @PredictHookImpl;

finalization
  GPredictor.Free;

end.
