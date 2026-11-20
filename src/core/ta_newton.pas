unit ta_newton;
{ Newtonov model ("Sustav 2"): nativna replika SMART-BETTING-APP smartbet/quantum/newtonian_adapter.py i
  NewtonianGravitationStrategy.fit/predict_one. Nema fizike: snaga momcadi je zaglazena prosjecna gol-razlika,
  jaz u snazi (domaci minus gosti) se po ligi dijeli u kvintile, a vjerojatnost 1/X/2 je zaglazena povijesna
  ucestalost ishoda u tom kvintilu. Daje samo 1X2 i dvostruku sansu (nema modela golova). Povijest su
  utakmice iz cijele grupe lige prije datuma, i to samo one s B365 kvotama (kao u Pythonu). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, StrUtils, ZDataset, ta_meta, ta_predict;

type
  TNwAcc = class
    Sum, N, Mass: Double;
  end;

  TNwDiv = class
    Edges: array of Double;            { granice kvintila, prva -inf, zadnja +inf; prazno = nema kutija }
    Cnt: array of array[0..2] of Double;
    Gaps: array of Double;
    Out_: array of Integer;
  end;

  TNwFit = class
  public
    Teams: TStringList;                { momcad -> TNwAcc }
    GlobalMean: Double;
    Divs: TStringList;                 { liga -> TNwDiv }
    GlobalDist: array[0..2] of Double;
    constructor Create;
    destructor Destroy; override;
  end;

  TaNewtonEngine = class(TaAltEngine)
  private
    FDb: TAppDb;
    FFits: TStringList;                { grupa|dan -> TNwFit (ili nil) }
    function FitFor(const ADiv: string; ARef: Integer): TNwFit;
  public
    PseudoCount, MassShrink: Double;
    constructor Create(ADb: TAppDb);
    destructor Destroy; override;
    function Predict(const ADiv, AHome, AAway: string; ARef: Integer): TaPrediction; override;
    procedure Clear; override;
  end;

implementation

constructor TNwFit.Create;
begin
  Teams := TStringList.Create; Teams.CaseSensitive := True; Teams.Sorted := True; Teams.Duplicates := dupIgnore;
  Divs := TStringList.Create; Divs.CaseSensitive := True; Divs.Sorted := True; Divs.Duplicates := dupIgnore;
end;

destructor TNwFit.Destroy;
var
  I: Integer;
begin
  for I := 0 to Teams.Count - 1 do Teams.Objects[I].Free;
  for I := 0 to Divs.Count - 1 do Divs.Objects[I].Free;
  Teams.Free; Divs.Free;
  inherited Destroy;
end;

constructor TaNewtonEngine.Create(ADb: TAppDb);
begin
  FDb := ADb;
  PseudoCount := 8.0;
  MassShrink := 10.0;
  FFits := TStringList.Create;
  FFits.CaseSensitive := True;
end;

destructor TaNewtonEngine.Destroy;
begin
  Clear;
  FFits.Free;
  inherited Destroy;
end;

procedure TaNewtonEngine.Clear;
var
  I: Integer;
begin
  for I := 0 to FFits.Count - 1 do FFits.Objects[I].Free;
  FFits.Clear;
end;

{ numpy.quantile (linearna interpolacija) nad vec sortiranim nizom }
function NpQuantile(const AX: array of Double; AQ: Double): Double;
var
  N, Prev, Nxt: Integer;
  Vi, G, A, B, Diff: Double;
begin
  N := Length(AX);
  Vi := AQ * (N - 1);
  Prev := Trunc(Floor(Vi));
  if Prev < 0 then Prev := 0;
  if Prev > N - 1 then Prev := N - 1;
  Nxt := Prev + 1;
  if Nxt > N - 1 then Nxt := N - 1;
  G := Vi - Floor(Vi);
  A := AX[Prev]; B := AX[Nxt];
  Diff := B - A;
  Result := A + Diff * G;
  if G >= 0.5 then Result := B - Diff * (1 - G);
end;

function NextAfterUp(X: Double): Double;
var
  I: Int64 absolute X;
  R: Double;
  J: Int64 absolute R;
begin
  R := X;
  if X >= 0 then J := I + 1 else J := I - 1;
  Result := R;
end;

type
  TDblArr = array of Double;

procedure SortDoubles(var A: TDblArr);
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

{ pd.qcut(gaps, 5, duplicates='drop') granice; -inf/+inf na rubovima. Nema kutija kad se sve granice slore. }
procedure QuintileEdges(const AGaps: array of Double; out AEdges: TDblArr);
var
  S: TDblArr;
  Q: array[0..5] of Double;
  I, K: Integer;
  E: TDblArr;
begin
  SetLength(S, Length(AGaps));
  for I := 0 to High(AGaps) do S[I] := AGaps[I];
  SortDoubles(S);
  for I := 0 to 5 do
  begin
    Q[I] := I * (1.0 / 5);
    if I = 5 then Q[I] := 1.0
    else if 5 * Q[I] <> I then Q[I] := NextAfterUp(Q[I]);
  end;
  SetLength(E, 0);
  for I := 0 to 5 do
  begin
    K := Length(E);
    if (K > 0) and (NpQuantile(S, Q[I]) = E[K - 1]) then Continue;
    SetLength(E, K + 1);
    E[K] := NpQuantile(S, Q[I]);
  end;
  if Length(E) >= 2 then begin E[0] := NegInfinity; E[High(E)] := Infinity; end
  else SetLength(E, 0);
  AEdges := E;
end;

{ pd.cut(x, edges, include_lowest=True): kutija 1.. (desno zatvoreno), 0 = nema }
function BucketOf(const AEdges: array of Double; X: Double): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to Length(AEdges) - 2 do
    if (X > AEdges[I]) and (X <= AEdges[I + 1]) then Exit(I + 1);
end;

function TaNewtonEngine.FitFor(const ADiv: string; ARef: Integer): TNwFit;
var
  Divs: TStringArray;
  Key, In_, Ref: string;
  I, J, K, N, Idx, Bk: Integer;
  Q: TZQuery;
  Rows: array of record Dv, Home, Away: string; Gd: Double; Out_: Integer; end;
  Fit: TNwFit;
  Acc: TNwAcc;
  Dv: TNwDiv;
  Fh: Double;
  Edges: TDblArr;
  GCnt: array[0..2] of Double;
  Total: Double;
  Tabs: TStringList;
  Have: Boolean;
begin
  Divs := GroupOfDivision(ADiv);
  Key := '';
  for I := 0 to High(Divs) do Key := Key + Divs[I] + ',';
  Key := Key + '|' + IntToStr(ARef);
  I := FFits.IndexOf(Key);
  if I >= 0 then Exit(TNwFit(FFits.Objects[I]));
  In_ := '';
  for I := 0 to High(Divs) do
  begin
    if In_ <> '' then In_ := In_ + ',';
    In_ := In_ + '''' + StringReplace(Divs[I], '''', '''''', [rfReplaceAll]) + '''';
  end;
  { baza bez tablica utakmica i kvota nema predvidanja (a ne gresku) }
  Tabs := FDb.UserTables;
  try
    Have := (Tabs.IndexOf('matches') >= 0) and (Tabs.IndexOf('match_odds') >= 0);
  finally
    Tabs.Free;
  end;
  if not Have then
  begin
    FFits.AddObject(Key, nil);
    Exit(nil);
  end;
  Ref := FormatDateTime('yyyy-mm-dd', ARef);
  Q := FDb.NewQuery('SELECT m.division, m.hometeam, m.awayteam, m.fthg, m.ftag, h.odds, d.odds, a.odds FROM matches m ' +
    'LEFT JOIN match_odds h ON h.match_id = m.match_id AND h.bookmaker = ''B365'' AND h.market = ''1X2'' AND h.selection = ''1'' AND h.closing = 0 ' +
    'LEFT JOIN match_odds d ON d.match_id = m.match_id AND d.bookmaker = ''B365'' AND d.market = ''1X2'' AND d.selection = ''X'' AND d.closing = 0 ' +
    'LEFT JOIN match_odds a ON a.match_id = m.match_id AND a.bookmaker = ''B365'' AND a.market = ''1X2'' AND a.selection = ''2'' AND a.closing = 0 ' +
    'WHERE m.division IN (' + In_ + ') AND m.matchdate < :b');
  N := 0;
  SetLength(Rows, 0);
  try
    Q.ParamByName('b').AsString := Ref;
    Q.Open;
    SetLength(Rows, 4096);
    while not Q.Eof do
    begin
      { _prepare: rezultat i sve tri kvote moraju postojati i biti veci od 1 }
      if not (Q.Fields[3].IsNull or Q.Fields[4].IsNull or Q.Fields[5].IsNull or Q.Fields[6].IsNull or Q.Fields[7].IsNull) then
        if (Q.Fields[5].AsFloat > 1.0) and (Q.Fields[6].AsFloat > 1.0) and (Q.Fields[7].AsFloat > 1.0) then
        begin
          if N >= Length(Rows) then SetLength(Rows, Length(Rows) * 2);
          Rows[N].Dv := Q.Fields[0].AsString; Rows[N].Home := Q.Fields[1].AsString; Rows[N].Away := Q.Fields[2].AsString;
          Rows[N].Gd := Q.Fields[3].AsInteger - Q.Fields[4].AsInteger;
          if Rows[N].Gd > 0 then Rows[N].Out_ := 0 else if Rows[N].Gd < 0 then Rows[N].Out_ := 2 else Rows[N].Out_ := 1;
          Inc(N);
        end;
      Q.Next;
    end;
  finally
    Q.Free;
  end;
  if N = 0 then
  begin
    FFits.AddObject(Key, nil);
    Exit(nil);
  end;
  Fit := TNwFit.Create;
  { snaga momcadi: zaglazena prosjecna gol-razlika po nastupu }
  Total := 0;
  for I := 0 to N - 1 do
  begin
    for J := 0 to 1 do
    begin
      if J = 0 then begin Idx := Fit.Teams.IndexOf(Rows[I].Home); Fh := Rows[I].Gd; end
      else begin Idx := Fit.Teams.IndexOf(Rows[I].Away); Fh := -Rows[I].Gd; end;
      if Idx < 0 then
      begin
        Acc := TNwAcc.Create;
        if J = 0 then Fit.Teams.AddObject(Rows[I].Home, Acc) else Fit.Teams.AddObject(Rows[I].Away, Acc);
      end
      else Acc := TNwAcc(Fit.Teams.Objects[Idx]);
      Acc.Sum := Acc.Sum + Fh; Acc.N := Acc.N + 1;
      Total := Total + Fh;
    end;
  end;
  Fit.GlobalMean := Total / (2 * N);
  for I := 0 to Fit.Teams.Count - 1 do
  begin
    Acc := TNwAcc(Fit.Teams.Objects[I]);
    Acc.Mass := (Acc.Sum + MassShrink * Fit.GlobalMean) / (Acc.N + MassShrink);
  end;
  { jaz u snazi po ligi }
  for I := 0 to N - 1 do
  begin
    Idx := Fit.Divs.IndexOf(Rows[I].Dv);
    if Idx < 0 then Idx := Fit.Divs.AddObject(Rows[I].Dv, TNwDiv.Create);
    Dv := TNwDiv(Fit.Divs.Objects[Idx]);
    K := Length(Dv.Gaps);
    SetLength(Dv.Gaps, K + 1); SetLength(Dv.Out_, K + 1);
    Dv.Gaps[K] := TNwAcc(Fit.Teams.Objects[Fit.Teams.IndexOf(Rows[I].Home)]).Mass -
                  TNwAcc(Fit.Teams.Objects[Fit.Teams.IndexOf(Rows[I].Away)]).Mass;
    Dv.Out_[K] := Rows[I].Out_;
  end;
  GCnt[0] := 0; GCnt[1] := 0; GCnt[2] := 0;
  for I := 0 to N - 1 do GCnt[Rows[I].Out_] := GCnt[Rows[I].Out_] + 1;
  for K := 0 to 2 do
  begin
    Fit.GlobalDist[K] := GCnt[K] / N;
    if GCnt[K] = 0 then Fit.GlobalDist[K] := 1e-6;
  end;
  for I := 0 to Fit.Divs.Count - 1 do
  begin
    Dv := TNwDiv(Fit.Divs.Objects[I]);
    QuintileEdges(Dv.Gaps, Edges);
    SetLength(Dv.Edges, Length(Edges));
    for K := 0 to High(Edges) do Dv.Edges[K] := Edges[K];
    SetLength(Dv.Cnt, Length(Edges));      { indeks kutije 1.. }
    for K := 0 to High(Dv.Cnt) do begin Dv.Cnt[K][0] := 0; Dv.Cnt[K][1] := 0; Dv.Cnt[K][2] := 0; end;
    for K := 0 to High(Dv.Gaps) do
    begin
      Bk := BucketOf(Dv.Edges, Dv.Gaps[K]);
      if Bk > 0 then Dv.Cnt[Bk][Dv.Out_[K]] := Dv.Cnt[Bk][Dv.Out_[K]] + 1;
    end;
  end;
  FFits.AddObject(Key, Fit);
  Result := Fit;
end;

function TaNewtonEngine.Predict(const ADiv, AHome, AAway: string; ARef: Integer): TaPrediction;
var
  Fit: TNwFit;
  HI, AI, Idx, Bk, K: Integer;
  MassH, MassA, Gap, Nn: Double;
  Dist: array[0..2] of Double;
  Dv: TNwDiv;

  procedure Add(const AMarket, ASel: string; AValue: Double);
  var
    L: Integer;
  begin
    L := Length(Result.Items);
    SetLength(Result.Items, L + 1);
    Result.Items[L].Market := AMarket; Result.Items[L].Selection := ASel; Result.Items[L].P := AValue;
  end;

begin
  Result.Ok := False; Result.LastRound := False; Result.Notes := ''; SetLength(Result.Items, 0);
  Result.HalfTimeFitted := False;
  Result.XgH := NaN; Result.XgA := NaN; Result.XgHtH := NaN; Result.XgHtA := NaN;
  Fit := FitFor(ADiv, ARef);
  if Fit = nil then Exit;
  HI := Fit.Teams.IndexOf(AHome); AI := Fit.Teams.IndexOf(AAway);
  if (HI < 0) and (AI < 0) then Exit;
  if HI >= 0 then MassH := TNwAcc(Fit.Teams.Objects[HI]).Mass else MassH := Fit.GlobalMean;
  if AI >= 0 then MassA := TNwAcc(Fit.Teams.Objects[AI]).Mass else MassA := Fit.GlobalMean;
  Gap := MassH - MassA;
  Bk := 0; Nn := 0;
  Idx := Fit.Divs.IndexOf(ADiv);
  Dist[0] := Fit.GlobalDist[0]; Dist[1] := Fit.GlobalDist[1]; Dist[2] := Fit.GlobalDist[2];
  if Idx >= 0 then
  begin
    Dv := TNwDiv(Fit.Divs.Objects[Idx]);
    Bk := BucketOf(Dv.Edges, Gap);
    if Bk > 0 then
    begin
      { povijesni uzorak u kutiji; ako kutija nema nijednu utakmicu, Python nema zapis pa vrijedi globalna raspodjela }
      Nn := Dv.Cnt[Bk][0] + Dv.Cnt[Bk][1] + Dv.Cnt[Bk][2];
      if Nn > 0 then
        for K := 0 to 2 do
          Dist[K] := (Dv.Cnt[Bk][K] + PseudoCount * Fit.GlobalDist[K]) / (Nn + PseudoCount);
    end;
  end;
  Add('1X2', '1', Dist[0]); Add('1X2', 'X', Dist[1]); Add('1X2', '2', Dist[2]);
  Add('DOUBLE_CHANCE', '1X', Dist[0] + Dist[1]);
  Add('DOUBLE_CHANCE', '12', Dist[0] + Dist[2]);
  Add('DOUBLE_CHANCE', 'X2', Dist[1] + Dist[2]);
  Result.Notes := 'Sustav 2 (Newton) - eksperimentalno, bez provjere na proslim sezonama. Samo 1X2 i dvostruka sansa - nema modela golova.; ' +
    'Povijesni uzorak: ' + IntToStr(Round(Nn)) + ' utakmica u ovoj skupini snage (kvintil ' + IfThen(Bk > 0, IntToStr(Bk), 'None') + ').';
  Result.Ok := True;
end;

function NewtonFactory(ADb: TAppDb; const AModel: string): TaAltEngine;
begin
  if AModel = 'newton' then Result := TaNewtonEngine.Create(ADb) else Result := nil;
end;

initialization
  AltEngineFactory := @NewtonFactory;

end.
