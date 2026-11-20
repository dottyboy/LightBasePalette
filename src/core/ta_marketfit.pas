unit ta_marketfit;
{ Predvidanja iz kvota kladionice: nativna replika SMART-BETTING-APP smartbet/models/marketfit.py i
  training.market_prediction. Iz kvota 1X2 (i, ako ih ima, preko/ispod 2.5) uklanja se marza (zadano Shin),
  a zatim se matrica rezultata trazi tako da tri cilja (pobjeda domacih, neodluceno, Over 2.5) budu pogodjena
  s tri nepoznanice (ukupna stopa golova, nadmoc, rho): ista koordinatna bisekcija kao u Pythonu. Kvote se
  citaju iz tablice fixture_prices koju puni ImportFixtures. Ne tvrdi nikakvu prednost nad kvotama: to je
  mišljenje trzista, namijenjeno usporedbi s modelom. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Variants, ZDataset, ta_meta, ta_expr, ta_predict, ta_newton;

type
  TaMarginMethod = (mmProportional, mmMpto, mmPower, mmOddsRatio, mmShin);

  TaMarketFit = record
    Ok: Boolean;
    LamHome, LamAway, Rho: Double;
    Matrix: TMatrix;
    Target: array[0..3] of Double;      { 1, X, 2, Over }
    HasOver: Boolean;
    Resid: array[0..3] of Double;
    Margin1x2, MarginOu: Double;
    WorstResidual: Double;
    Reliable: Boolean;
  end;

{ vjerojatnosti bez marze za popis kvota; vrati marzu (zbroj - 1); False ako kvote nisu valjane }
function RemoveMargin(const AOdds: array of Double; AMethod: TaMarginMethod; out AProbs: array of Double;
  out AMargin: Double): Boolean;
function FitMarket(H, D, A: Double; AOu: Boolean; AOver, AUnder: Double; AMethod: TaMarginMethod): TaMarketFit;
{ predvidanje iz kvota (training.market_prediction): trzista ovise o tome ima li O/U i je li prilagodba pouzdana }
function MarketPrediction(const ABook: string; H, D, A: Double; AOu: Boolean; AOver, AUnder: Double;
  const ADiv: string): TaPrediction;

type
  TaMarketEngine = class(TaAltEngine)
  private
    FDb: TAppDb;
  public
    constructor Create(ADb: TAppDb);
    function Predict(const ADiv, AHome, AAway: string; ARef: Integer): TaPrediction; override;
  end;

implementation

const
  RateLo = 0.05;
  RateHi = 6.0;
  RhoLo = -0.25;
  RhoHi = 0.25;
  Tolerance = 1e-4;
  UnreliableResidual = 0.005;
  MaxGoals = 12;
  Line = 2.5;

type
  TFn = function(AValue: Double): Double of object;

{ ---------------- marza ---------------- }

type
  TMarginCtx = class
    Q: array of Double;
    Booksum: Double;
    Method: TaMarginMethod;
    function Residual(AParam: Double): Double;
  end;

function TMarginCtx.Residual(AParam: Double): Double;
var
  I: Integer;
  S, P: Double;
begin
  S := 0;
  for I := 0 to High(Q) do
  begin
    case Method of
      mmPower: P := Power(Q[I], AParam);
      mmOddsRatio: P := Q[I] / (AParam * (1.0 - Q[I]) + Q[I]);
    else
      P := (Sqrt(AParam * AParam + 4.0 * (1.0 - AParam) * Q[I] * Q[I] / Booksum) - AParam) / (2.0 * (1.0 - AParam));
    end;
    S := S + P;
  end;
  Result := S - 1.0;
end;

function MarginRoot(ACtx: TMarginCtx; ALow, AHigh: Double): Double;
var
  I: Integer;
  Mid: Double;
begin
  for I := 1 to 80 do
  begin
    Mid := 0.5 * (ALow + AHigh);
    if ACtx.Residual(Mid) > 0.0 then ALow := Mid else AHigh := Mid;
  end;
  Result := 0.5 * (ALow + AHigh);
end;

function RemoveMargin(const AOdds: array of Double; AMethod: TaMarginMethod; out AProbs: array of Double;
  out AMargin: Double): Boolean;
var
  Ctx: TMarginCtx;
  I, N: Integer;
  Sum, K, Z, C, P: Double;
  Neg: Boolean;
begin
  Result := False;
  N := Length(AOdds);
  for I := 0 to N - 1 do if AOdds[I] <= 1.0 then Exit;
  Ctx := TMarginCtx.Create;
  try
    SetLength(Ctx.Q, N);
    Ctx.Booksum := 0;
    for I := 0 to N - 1 do begin Ctx.Q[I] := 1.0 / AOdds[I]; Ctx.Booksum := Ctx.Booksum + Ctx.Q[I]; end;
    if Ctx.Booksum <= 0 then Exit;
    AMargin := Ctx.Booksum - 1.0;
    if (AMethod = mmProportional) or (AMargin <= 1e-12) then
      for I := 0 to N - 1 do AProbs[I] := Ctx.Q[I] / Ctx.Booksum
    else if AMethod = mmMpto then
    begin
      Neg := False;
      for I := 0 to N - 1 do begin AProbs[I] := Ctx.Q[I] - AMargin / N; if AProbs[I] <= 0 then Neg := True; end;
      if Neg then for I := 0 to N - 1 do AProbs[I] := Ctx.Q[I] / Ctx.Booksum;
    end
    else if AMethod = mmPower then
    begin
      Ctx.Method := mmPower;
      K := MarginRoot(Ctx, 1.0, 60.0);
      for I := 0 to N - 1 do AProbs[I] := Power(Ctx.Q[I], K);
    end
    else if AMethod = mmOddsRatio then
    begin
      Ctx.Method := mmOddsRatio;
      C := MarginRoot(Ctx, 1.0, 60.0);
      for I := 0 to N - 1 do AProbs[I] := Ctx.Q[I] / (C * (1.0 - Ctx.Q[I]) + Ctx.Q[I]);
    end
    else
    begin
      Ctx.Method := mmShin;
      Z := MarginRoot(Ctx, 0.0, 0.999);
      for I := 0 to N - 1 do
      begin
        P := (Sqrt(Z * Z + 4.0 * (1.0 - Z) * Ctx.Q[I] * Ctx.Q[I] / Ctx.Booksum) - Z) / (2.0 * (1.0 - Z));
        AProbs[I] := P;
      end;
    end;
    Sum := 0;
    for I := 0 to N - 1 do Sum := Sum + AProbs[I];
    for I := 0 to N - 1 do AProbs[I] := AProbs[I] / Sum;
    Result := True;
  finally
    Ctx.Free;
  end;
end;

{ ---------------- rjesavanje ---------------- }

procedure ResultProbs(const AM: TMatrix; out AH, AD, AA: Double);
var
  I, J: Integer;
begin
  AH := 0; AD := 0; AA := 0;
  for I := 0 to High(AM) do
    for J := 0 to High(AM) do
      if I > J then AH := AH + AM[I][J]
      else if I = J then AD := AD + AM[I][J]
      else AA := AA + AM[I][J];
end;

function OverOf(const AM: TMatrix; ALine: Double): Double;
var
  I, J: Integer;
begin
  Result := 0;
  for I := 0 to High(AM) do
    for J := 0 to High(AM) do
      if I + J > ALine then Result := Result + AM[I][J];
end;

function BuildM(AMu, ASup, ARho: Double): TMatrix;
var
  Half: Double;
begin
  Half := AMu / 2.0;
  Result := ScoreMatrix(Max(Half + ASup / 2, RateLo), Max(Half - ASup / 2, RateLo), ARho, MaxGoals);
end;

type
  TSolveKind = (skOver, skSupremacy, skRho, skDraw);
  TSolver = class
    Kind: TSolveKind;
    Mu, Sup, Rho, HomeT, AwayT, DrawT, OverT: Double;
    function Res(AValue: Double): Double;
  end;

function TSolver.Res(AValue: Double): Double;
var
  M: TMatrix;
  H, D, A: Double;
begin
  case Kind of
    skOver:
      Result := OverOf(BuildM(AValue, Sup, Rho), Line) - OverT;
    skSupremacy:
    begin
      M := BuildM(Mu, AValue, Rho);
      ResultProbs(M, H, D, A);
      Result := (H - A) - (HomeT - AwayT);
    end;
    skRho:
    begin
      M := BuildM(Mu, Sup, AValue);
      ResultProbs(M, H, D, A);
      Result := -(D - DrawT);
    end;
  else
    M := BuildM(AValue, Sup, Rho);
    ResultProbs(M, H, D, A);
    Result := -(D - DrawT);
  end;
end;

{ _bisect: nultocka ili najblizi rub }
function Bisect(ASolver: TSolver; ALo, AHi: Double): Double;
var
  FLo, FHi, Mid: Double;
  I: Integer;
begin
  FLo := ASolver.Res(ALo); FHi := ASolver.Res(AHi);
  if FLo > 0 then Exit(ALo);
  if FHi < 0 then Exit(AHi);
  for I := 1 to 32 do
  begin
    Mid := (ALo + AHi) / 2;
    if ASolver.Res(Mid) < 0 then ALo := Mid else AHi := Mid;
  end;
  Result := (ALo + AHi) / 2;
end;

function RateFromOver(AOver: Double): Double;
var
  Lo, Hi, Mid: Double;
  I: Integer;
begin
  Lo := 0.2; Hi := 8.0;
  for I := 1 to 40 do
  begin
    Mid := (Lo + Hi) / 2;
    if OverOf(ScoreMatrix(Mid / 2, Mid / 2, 0.0, 12), Line) < AOver then Lo := Mid else Hi := Mid;
  end;
  Result := (Lo + Hi) / 2;
end;

function FitProbs(H, D, A: Double; AHasOver: Boolean; AOver: Double): TaMarketFit;
var
  Tot, Mu, Sup, Rho, GH, GD, GA, Worst, Go: Double;
  It: Integer;
  S: TSolver;
  M: TMatrix;
begin
  Result.Ok := False;
  Tot := H + D + A;
  if Tot <= 0 then Exit;
  H := H / Tot; D := D / Tot; A := A / Tot;
  if AHasOver and not ((AOver > 0.0) and (AOver < 1.0)) then Exit;
  S := TSolver.Create;
  try
    S.HomeT := H; S.DrawT := D; S.AwayT := 1.0 - H - D; S.OverT := AOver;
    if AHasOver then Mu := RateFromOver(AOver) else Mu := 2.6;
    Sup := 0.0; Rho := 0.0;
    for It := 1 to 12 do
    begin
      S.Mu := Mu; S.Sup := Sup; S.Rho := Rho;
      if AHasOver then
      begin
        S.Kind := skOver;
        Mu := Bisect(S, 2 * RateLo, 2 * RateHi);
        S.Mu := Mu;
      end;
      S.Kind := skSupremacy;
      Sup := Bisect(S, -Mu + 2 * RateLo, Mu - 2 * RateLo);
      S.Sup := Sup;
      if AHasOver then
      begin
        S.Kind := skRho;
        Rho := Bisect(S, RhoLo, RhoHi);
        S.Rho := Rho;
      end
      else
      begin
        S.Kind := skDraw;
        Mu := Bisect(S, 2 * RateLo, 2 * RateHi);
        S.Mu := Mu;
      end;
      M := BuildM(Mu, Sup, Rho);
      ResultProbs(M, GH, GD, GA);
      Worst := Max(Abs(GH - H), Abs(GD - D));
      if AHasOver then Worst := Max(Worst, Abs(OverOf(M, Line) - AOver));
      if Worst < Tolerance then Break;
    end;
  finally
    S.Free;
  end;
  Result.LamHome := Max(Mu / 2.0 + Sup / 2, RateLo);
  Result.LamAway := Max(Mu / 2.0 - Sup / 2, RateLo);
  Result.Rho := Rho;
  Result.Matrix := ScoreMatrix(Result.LamHome, Result.LamAway, Rho, MaxGoals);
  ResultProbs(Result.Matrix, GH, GD, GA);
  Go := OverOf(Result.Matrix, Line);
  Result.Target[0] := H; Result.Target[1] := D; Result.Target[2] := A; Result.Target[3] := AOver;
  Result.HasOver := AHasOver;
  Result.Resid[0] := GH - H; Result.Resid[1] := GD - D; Result.Resid[2] := (1.0 - GH - GD) - A;
  Result.Resid[3] := 0;
  Result.WorstResidual := Max(Abs(Result.Resid[0]), Max(Abs(Result.Resid[1]), Abs(Result.Resid[2])));
  if AHasOver then
  begin
    Result.Resid[3] := Go - AOver;
    Result.WorstResidual := Max(Result.WorstResidual, Abs(Result.Resid[3]));
  end;
  Result.Reliable := Result.WorstResidual <= UnreliableResidual;
  Result.Ok := True;
end;

function FitMarket(H, D, A: Double; AOu: Boolean; AOver, AUnder: Double; AMethod: TaMarginMethod): TaMarketFit;
var
  R3: array[0..2] of Double;
  R2: array[0..1] of Double;
  M1, M2: Double;
begin
  Result.Ok := False;
  if not RemoveMargin([H, D, A], AMethod, R3, M1) then Exit;
  M2 := 0;
  if AOu then
  begin
    if not RemoveMargin([AOver, AUnder], AMethod, R2, M2) then Exit;
    Result := FitProbs(R3[0], R3[1], R3[2], True, R2[0]);
  end
  else Result := FitProbs(R3[0], R3[1], R3[2], False, 0.0);
  Result.Margin1x2 := M1; Result.MarginOu := M2;
end;

{ ---------------- predvidanje (training.market_prediction) ---------------- }

function MarketPrediction(const ABook: string; H, D, A: Double; AOu: Boolean; AOver, AUnder: Double;
  const ADiv: string): TaPrediction;
var
  F: TaMarketFit;
  P1, PX, P2, Yes, O: Double;
  Full, Li: Integer;
  Lines: array[0..2] of string;
  LineV: array[0..2] of Double;

  procedure Add(const AMarket, ASel: string; AValue: Double);
  var
    L: Integer;
  begin
    L := Length(Result.Items);
    SetLength(Result.Items, L + 1);
    Result.Items[L].Market := AMarket; Result.Items[L].Selection := ASel; Result.Items[L].P := AValue;
  end;

  function Pct(X: Double): string;
  begin
    Result := FormatFloat('0.0', X * 100, DefaultFormatSettings) + '%';
  end;

begin
  Result.Ok := False; Result.LastRound := False; Result.Notes := ''; SetLength(Result.Items, 0);
  Result.HalfTimeFitted := False;
  Result.XgH := NaN; Result.XgA := NaN; Result.XgHtH := NaN; Result.XgHtA := NaN;
  F := FitMarket(H, D, A, AOu, AOver, AUnder, mmShin);
  if not F.Ok then Exit;
  ResultProbs(F.Matrix, P1, PX, P2);
  if not F.Reliable then
  begin
    P1 := F.Target[0]; PX := F.Target[1]; P2 := F.Target[2];
  end;
  Add('1X2', '1', P1); Add('1X2', 'X', PX); Add('1X2', '2', P2);
  Add('DOUBLE_CHANCE', '1X', P1 + PX); Add('DOUBLE_CHANCE', '12', P1 + P2); Add('DOUBLE_CHANCE', 'X2', PX + P2);
  Result.Notes := 'Iz kvota kladionice (' + ABook + '), marza 1X2 ' + Pct(F.Margin1x2);
  if AOu then Result.Notes := Result.Notes + ', O/U ' + Pct(F.MarginOu);
  if AOu and F.Reliable then
  begin
    { BTTS i ukupni golovi iz matrice, bez kalibracije }
    Yes := 0;
    for Full := 1 to High(F.Matrix) do
      for Li := 1 to High(F.Matrix) do Yes := Yes + F.Matrix[Full][Li];
    Add('BTTS', 'GG', Yes); Add('BTTS', 'NG', 1.0 - Yes);
    Lines[0] := '1.5'; Lines[1] := '2.5'; Lines[2] := '3.5';
    LineV[0] := 1.5; LineV[1] := 2.5; LineV[2] := 3.5;
    for Li := 0 to 2 do
    begin
      O := OverOf(F.Matrix, LineV[Li]);
      Add('OVER_UNDER', 'Over ' + Lines[Li], O); Add('OVER_UNDER', 'Under ' + Lines[Li], 1.0 - O);
    end;
  end;
  if AOu and not F.Reliable then
    Result.Notes := Result.Notes + '; Prilagodba promasuje cijenu za ' + FormatFloat('0.0', 100 * F.WorstResidual, DefaultFormatSettings) +
      ' boda - samo 1X2 i dvostruka sansa su pouzdani.';
  if (not AOu) and (not F.Reliable) then
    Result.Notes := Result.Notes + '; Prilagodba promasuje cijenu - 1X2 i dvostruka sansa su izravno iz kvota.';
  if not AOu then
    Result.Notes := Result.Notes + '; Bez O/U 2.5 u izvoru - nema BTTS ni ukupnih golova, jer bi dolazili iz nase pretpostavke, a ne iz cijene.';
  Result.XgH := F.LamHome; Result.XgA := F.LamAway; Result.XgHtH := F.LamHome / 2; Result.XgHtA := F.LamAway / 2;
  Result.Ok := True;
end;

{ ---------------- motor ---------------- }

constructor TaMarketEngine.Create(ADb: TAppDb);
begin
  FDb := ADb;
end;

function TaMarketEngine.Predict(const ADiv, AHome, AAway: string; ARef: Integer): TaPrediction;
var
  Tabs: TStringList;
  Q: TZQuery;
  Have: Boolean;
begin
  Result.Ok := False; Result.LastRound := False; Result.Notes := ''; SetLength(Result.Items, 0);
  Result.HalfTimeFitted := False;
  Tabs := FDb.UserTables;
  try
    Have := Tabs.IndexOf('fixture_prices') >= 0;
  finally
    Tabs.Free;
  end;
  if not Have then Exit;
  Q := FDb.NewQuery('SELECT book, h, d, a, over, under FROM fixture_prices WHERE division = :d AND hometeam = :h AND awayteam = :a');
  try
    Q.ParamByName('d').AsString := ADiv; Q.ParamByName('h').AsString := AHome; Q.ParamByName('a').AsString := AAway;
    Q.Open;
    if Q.Eof then Exit;
    Result := MarketPrediction(Q.Fields[0].AsString, Q.Fields[1].AsFloat, Q.Fields[2].AsFloat, Q.Fields[3].AsFloat,
      not (Q.Fields[4].IsNull or Q.Fields[5].IsNull), Q.Fields[4].AsFloat, Q.Fields[5].AsFloat, ADiv);
  finally
    Q.Free;
  end;
end;

var
  PrevFactory: function(ADb: TAppDb; const AModel: string): TaAltEngine = nil;

function MarketFactory(ADb: TAppDb; const AModel: string): TaAltEngine;
begin
  if AModel = 'market' then Result := TaMarketEngine.Create(ADb)
  else if Assigned(PrevFactory) then Result := PrevFactory(ADb, AModel)
  else Result := nil;
end;

initialization
  PrevFactory := AltEngineFactory;
  AltEngineFactory := @MarketFactory;

end.
