unit ta_report;
{ Izvjestaj kola: tekstualni izvoz generiranih listica jednog kola (smartbet/report.py): parovi poredani od najboljeg
  predvidanja, pa za listice s vise nogu detalji svakog (zajednicka vjerojatnost), a nakon odigranih utakmica i rezultati
  i novac. Isti naslovi, isto razvrstavanje listica po vrsti (bets.kind_of) i isti zapis brojeva kao u Pythonu. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Variants, LazUTF8, ZDataset, ta_meta, ta_expr, ta_exprdb;

{ vrsta listica po biljesci i broju nogu: MALI, PRIJELAZI, POLUVRIJEME, ELITA, MIKS, TOP, HEDGE, VELIKI }
function KindOfSlip(const ANote: string; ALegs: Integer): string;
{ cijeli izvjestaj kola; ARef je 'GGGG-MM-DD'; AResults dodaje sto se doista dogodilo }
function BuildRoundReport(ADb: TAppDb; const ARef: string; AResults: Boolean; const ANow: string = ''): string;
{ najnovije kolo s otvorenim generiranim listicima (ASettled = False) ili s barem jednim rijesenim parom (True); '' ako nema }
function LatestRound(ADb: TAppDb; ASettled: Boolean): string;

implementation

const
  Rule = '------------------------';
  DoubleRule = '========================';

type
  TRLeg = record
    SlipId: Integer;
    Div_, Home, Away, Market, Sel, Status, Score: string;
    HasScore: Boolean;
    Prob: Double;
    SlipLegs: Integer;
  end;
  TRLegs = array of TRLeg;

  TRSlip = record
    Id: Integer;
    Stake, Odds, Payout: Double;
    Status, Note, Kind: string;
    Legs, Pending: Integer;
  end;
  TRSlips = array of TRSlip;

function KindOfSlip(const ANote: string; ALegs: Integer): string;
var
  T: string;
begin
  T := UTF8LowerCase(ANote);
  if Pos('hedge', T) > 0 then Exit('HEDGE');
  if Pos('top listici', T) > 0 then Exit('TOP');
  if Pos('elita', T) > 0 then Exit('ELITA');
  if Pos('miks', T) > 0 then Exit('MIKS');
  if Pos('prijelaz', T) > 0 then Exit('PRIJELAZI');
  if Pos('poluvrijeme', T) > 0 then Exit('POLUVRIJEME');
  if ALegs > 10 then Exit('VELIKI');
  Result := 'MALI';
end;

{ ---------------- zapis brojeva kao u Pythonu ---------------- }

function F1(X: Double): string;
begin
  Result := Format('%.1f', [X], DefaultFormatSettings);
end;

function Fix(const S: string): string;
begin
  Result := StringReplace(S, DefaultFormatSettings.DecimalSeparator, '.', []);
end;

function PadLeft(const S: string; W: Integer): string;
begin
  Result := S;
  while UTF8Length(Result) < W do Result := ' ' + Result;
end;

function PadRight(const S: string; W: Integer): string;
begin
  Result := S;
  while UTF8Length(Result) < W do Result := Result + ' ';
end;

{ {x:5.1%} }
function Pct1(X: Double; AWidth: Integer): string;
begin
  Result := PadLeft(Fix(F1(X * 100.0)) + '%', AWidth);
end;

{ {x:.2f} i {x:+.2f} }
function Num2(X: Double; ASign: Boolean): string;
begin
  Result := Fix(Format('%.2f', [X], DefaultFormatSettings));
  if ASign and (X >= 0) then Result := '+' + Result;
end;

function RoundHalfEven0(X: Double): Integer;
begin
  Result := Round(X);
end;

{ ---------------- citanje ---------------- }

procedure LoadRound(ADb: TAppDb; const ARef: string; out ASlips: TRSlips; out ALegs: TRLegs);
var
  Q: TZQuery;
  N, I, J: Integer;
  Idx: TStringList;
  Prod: Double;
begin
  SetLength(ASlips, 0);
  SetLength(ALegs, 0);
  Idx := TStringList.Create;
  try
    Idx.Sorted := True;
    Q := ADb.NewQuery('SELECT slip_id, stake, status, note FROM slips WHERE paper = 1 AND ref_date = :r ORDER BY slip_id DESC');
    try
      Q.ParamByName('r').AsString := ARef;
      Q.Open;
      N := 0;
      while not Q.Eof do
      begin
        SetLength(ASlips, N + 1);
        ASlips[N].Id := Q.Fields[0].AsInteger; ASlips[N].Stake := Q.Fields[1].AsFloat;
        ASlips[N].Status := Q.Fields[2].AsString; ASlips[N].Note := Q.Fields[3].AsString;
        ASlips[N].Legs := 0; ASlips[N].Pending := 0; ASlips[N].Odds := 1.0;
        Idx.AddObject(IntToStr(ASlips[N].Id), TObject(PtrInt(N)));
        Inc(N);
        Q.Next;
      end;
    finally
      Q.Free;
    end;
    if Length(ASlips) = 0 then Exit;
    Q := ADb.NewQuery('SELECT l.slip_id, l.division, l.hometeam, l.awayteam, l.market, l.selection, l.model_probability, l.odds, l.status, l.score ' +
      'FROM slip_legs l WHERE l.slip_id IN (SELECT slip_id FROM slips WHERE paper = 1 AND ref_date = :r) ORDER BY l.slip_id, l.leg_id');
    try
      Q.ParamByName('r').AsString := ARef;
      Q.Open;
      N := 0;
      while not Q.Eof do
      begin
        SetLength(ALegs, N + 1);
        ALegs[N].SlipId := Q.Fields[0].AsInteger; ALegs[N].Div_ := Q.Fields[1].AsString;
        ALegs[N].Home := Q.Fields[2].AsString; ALegs[N].Away := Q.Fields[3].AsString;
        ALegs[N].Market := Q.Fields[4].AsString; ALegs[N].Sel := Q.Fields[5].AsString;
        ALegs[N].Prob := Q.Fields[6].AsFloat; ALegs[N].Status := Q.Fields[8].AsString;
        ALegs[N].HasScore := not Q.Fields[9].IsNull; ALegs[N].Score := Q.Fields[9].AsString;
        J := Idx.IndexOf(IntToStr(ALegs[N].SlipId));
        if J >= 0 then
        begin
          I := PtrInt(Idx.Objects[J]);
          Inc(ASlips[I].Legs);
          ASlips[I].Odds := ASlips[I].Odds * Q.Fields[7].AsFloat;
          if ALegs[N].Status = 'PENDING' then Inc(ASlips[I].Pending);
        end;
        Inc(N);
        Q.Next;
      end;
    finally
      Q.Free;
    end;
    for I := 0 to High(ASlips) do
    begin
      ASlips[I].Kind := KindOfSlip(ASlips[I].Note, ASlips[I].Legs);
      if ASlips[I].Status = 'WON' then ASlips[I].Payout := ASlips[I].Stake * ASlips[I].Odds else ASlips[I].Payout := 0;
    end;
    for I := 0 to High(ALegs) do
    begin
      J := Idx.IndexOf(IntToStr(ALegs[I].SlipId));
      if J >= 0 then ALegs[I].SlipLegs := ASlips[PtrInt(Idx.Objects[J])].Legs;
    end;
    Prod := 0;
    if Prod = 1 then Exit;
  finally
    Idx.Free;
  end;
end;

{ ---------------- izvjestaj ---------------- }

function StatusLabel(const S: string): string;
begin
  if S = 'WON' then Result := 'PROSAO'
  else if S = 'LOST' then Result := 'PAO'
  else if S = 'PENDING' then Result := 'CEKA'
  else if S = 'NO_MATCH' then Result := 'NEMA UTAKMICE'
  else Result := S;
end;

function PickLine(const L: TRLeg; AShowResult: Boolean): string;
begin
  Result := '  ' + PadRight(L.Div_, 4) + ' ' + PadRight(UTF8Copy(L.Home, 1, 20), 20) + ' - ' + PadRight(UTF8Copy(L.Away, 1, 20), 20) + '  ' +
    PadRight(L.Sel, 8) + ' model ' + Pct1(L.Prob, 5);
  if not AShowResult then Exit;
  Result := Result + '  ->  ' + StatusLabel(L.Status);
  if L.HasScore then Result := Result + '  ' + L.Score;
end;

{ stabilno padajuce po vjerojatnosti }
procedure SortByProb(var A: TRLegs);
var
  I, J: Integer;
  T: TRLeg;
begin
  for I := 1 to High(A) do
  begin
    T := A[I]; J := I - 1;
    while (J >= 0) and (A[J].Prob < T.Prob) do begin A[J + 1] := A[J]; Dec(J); end;
    A[J + 1] := T;
  end;
end;

function ComboStatus(const AGroup: TRLegs): string;
var
  I: Integer;
  AllWon, AnyLost, AnyPending: Boolean;
begin
  AllWon := True; AnyLost := False; AnyPending := False;
  for I := 0 to High(AGroup) do
  begin
    if AGroup[I].Status = 'LOST' then AnyLost := True;
    if AGroup[I].Status = 'PENDING' then AnyPending := True;
    if AGroup[I].Status <> 'WON' then AllWon := False;
  end;
  if AnyLost then Result := StatusLabel('LOST')
  else if AnyPending then Result := StatusLabel('PENDING')
  else if AllWon then Result := StatusLabel('WON')
  else Result := StatusLabel('NO_MATCH');
end;

procedure Section(ALines: TStrings; const ATitle: string; const ASlips: TRSlips; const ALegs: TRLegs; AShowDetail, AShowResult: Boolean);
var
  I, J, K, NPicks, Graded, Won, Settled, Pending, WonSlips: Integer;
  Picks, Combos, Grp: TRLegs;
  Seen: TStringList;
  Key: string;
  Staked, Returned, Profit: Double;
  Ids: array of Integer;
  Prods: array of Double;
  T: Integer;
  TP: Double;
  Shape: string;
begin
  ALines.Add(ATitle);
  ALines.Add(Rule);
  ALines.Add(IntToStr(Length(ASlips)) + ' listica');
  if (Length(ASlips) = 0) or (Length(ALegs) = 0) then
  begin
    ALines.Add('  (nema generiranih listica za ovo kolo)');
    Exit;
  end;
  ALines.Add('Parovi poredani od najboljeg predvidjanja do najgoreg:');
  { drop_duplicates po (liga, domaci, gosti, trziste, izbor): ostaje prvo pojavljivanje }
  Seen := TStringList.Create;
  try
    Seen.CaseSensitive := True;
    SetLength(Picks, 0);
    NPicks := 0;
    for I := 0 to High(ALegs) do
    begin
      Key := ALegs[I].Div_ + #1 + ALegs[I].Home + #1 + ALegs[I].Away + #1 + ALegs[I].Market + #1 + ALegs[I].Sel;
      if Seen.IndexOf(Key) >= 0 then Continue;
      Seen.Add(Key);
      SetLength(Picks, NPicks + 1);
      Picks[NPicks] := ALegs[I];
      Inc(NPicks);
    end;
  finally
    Seen.Free;
  end;
  SortByProb(Picks);
  for I := 0 to High(Picks) do ALines.Add(PickLine(Picks[I], AShowResult));

  if AShowResult then
  begin
    Graded := 0; Won := 0;
    for I := 0 to High(Picks) do
      if (Picks[I].Status = 'WON') or (Picks[I].Status = 'LOST') then
      begin
        Inc(Graded);
        if Picks[I].Status = 'WON' then Inc(Won);
      end;
    if Graded > 0 then
      ALines.Add(LineEnding + IntToStr(Won) + '/' + IntToStr(Graded) + ' pogodaka (' + IntToStr(RoundHalfEven0(Won / Graded * 100.0)) + '%).');
    if AShowDetail then
    begin
      Staked := 0; Returned := 0; Settled := 0; Pending := 0; WonSlips := 0;
      for I := 0 to High(ASlips) do
      begin
        if ASlips[I].Status = 'PENDING' then Inc(Pending);
        if (ASlips[I].Status = 'WON') or (ASlips[I].Status = 'LOST') then
        begin
          Inc(Settled); Staked := Staked + ASlips[I].Stake; Returned := Returned + ASlips[I].Payout;
          if ASlips[I].Status = 'WON' then Inc(WonSlips);
        end;
      end;
      if Settled > 0 then
      begin
        Profit := Returned - Staked;
        ALines.Add('Ulozeno ' + Num2(Staked, False) + ' EUR, vraceno ' + Num2(Returned, False) + ' EUR, dobitak ' + Num2(Profit, True) +
          ' EUR (ROI ' + Fix(Format('%.1f', [Profit / Staked * 100.0], DefaultFormatSettings)) + '%), ' + IntToStr(Settled) + ' rijesenih listica.');
        { ROI s predznakom }
        if Profit >= 0 then
          ALines[ALines.Count - 1] := StringReplace(ALines[ALines.Count - 1], '(ROI ', '(ROI +', []);
      end;
    end;
  end;

  if AShowDetail then
  begin
    { listici s vise od jedne noge, najbolja zajednicka vjerojatnost prva }
    SetLength(Combos, 0);
    for I := 0 to High(ALegs) do
      if ALegs[I].SlipLegs >= 2 then
      begin
        SetLength(Combos, Length(Combos) + 1);
        Combos[High(Combos)] := ALegs[I];
      end;
    if Length(Combos) > 0 then
    begin
      SetLength(Ids, 0); SetLength(Prods, 0);
      for I := 0 to High(Combos) do
      begin
        J := 0;
        while (J < Length(Ids)) and (Ids[J] <> Combos[I].SlipId) do Inc(J);
        if J = Length(Ids) then
        begin
          SetLength(Ids, J + 1); SetLength(Prods, J + 1);
          Ids[J] := Combos[I].SlipId; Prods[J] := 1.0;
        end;
        Prods[J] := Prods[J] * Combos[I].Prob;
      end;
      for I := 1 to High(Ids) do
      begin
        T := Ids[I]; TP := Prods[I]; J := I - 1;
        while (J >= 0) and (Prods[J] < TP) do begin Ids[J + 1] := Ids[J]; Prods[J + 1] := Prods[J]; Dec(J); end;
        Ids[J + 1] := T; Prods[J + 1] := TP;
      end;
      ALines.Add('');
      ALines.Add('Detalji svakog listica (vise od jedne noge):');
      for I := 0 to High(Ids) do
      begin
        SetLength(Grp, 0);
        for K := 0 to High(Combos) do
          if Combos[K].SlipId = Ids[I] then
          begin
            SetLength(Grp, Length(Grp) + 1);
            Grp[High(Grp)] := Combos[K];
          end;
        if Length(Grp) = 2 then Shape := 'par' else Shape := IntToStr(Length(Grp)) + ' noge';
        Key := '';
        if AShowResult then Key := ' - ' + ComboStatus(Grp);
        ALines.Add(LineEnding + '  Listic #' + IntToStr(Ids[I]) + ' (' + Shape + ', zajednicka vjerojatnost ' + Fix(F1(Prods[I] * 100.0)) + '%)' + Key + ':');
        SortByProb(Grp);
        for K := 0 to High(Grp) do ALines.Add('    ' + Trim(PickLine(Grp[K], AShowResult)));
      end;
    end;
  end;
end;

function BuildRoundReport(ADb: TAppDb; const ARef: string; AResults: Boolean; const ANow: string): string;
const
  Titles: array[0..5] of string = ('MALI', 'PRIJELAZI SVI', 'POLUVRIJEME ILI KRAJ', 'ELITA', 'MIKS (PRIJELAZI + POLUVRIJEME)', 'TOP LISTICI');
  Kinds: array[0..5] of string = ('MALI', 'PRIJELAZI', 'POLUVRIJEME', 'ELITA', 'MIKS', 'TOP');
  Detail: array[0..5] of Boolean = (False, True, True, True, True, True);
var
  Slips, Part: TRSlips;
  Legs, PartLegs: TRLegs;
  Lines: TStringList;
  S, I, J, K: Integer;
  Stamp, Title: string;
begin
  LoadRound(ADb, ARef, Slips, Legs);
  Lines := TStringList.Create;
  try
    if AResults then Title := 'REPORT LISTICA - REZULTATI' else Title := 'REPORT LISTICA';
    if ANow <> '' then Stamp := ANow else Stamp := FormatDateTime('yyyy-mm-dd hh:nn', Now);
    Lines.Add(Title);
    Lines.Add('Kolo ' + ARef + ', izvezeno ' + Stamp);
    Lines.Add(DoubleRule);
    Lines.Add('');
    for S := 0 to 5 do
    begin
      SetLength(Part, 0);
      for I := 0 to High(Slips) do
        if Slips[I].Kind = Kinds[S] then
        begin
          SetLength(Part, Length(Part) + 1);
          Part[High(Part)] := Slips[I];
        end;
      SetLength(PartLegs, 0);
      for J := 0 to High(Legs) do
        for K := 0 to High(Part) do
          if Legs[J].SlipId = Part[K].Id then
          begin
            SetLength(PartLegs, Length(PartLegs) + 1);
            PartLegs[High(PartLegs)] := Legs[J];
            Break;
          end;
      Section(Lines, Titles[S], Part, PartLegs, Detail[S], AResults);
      Lines.Add('');
    end;
    { Pythonov "\n".join: bez zavrsnog novog retka }
    Result := '';
    for I := 0 to Lines.Count - 1 do
    begin
      if I > 0 then Result := Result + LineEnding;
      Result := Result + Lines[I];
    end;
  finally
    Lines.Free;
  end;
end;

function LatestRound(ADb: TAppDb; ASettled: Boolean): string;
var
  Q: TZQuery;
  Best: string;
  Id, Legs, Pending, Open_: Integer;
  Note, Ref: string;
begin
  Best := '';
  Q := ADb.NewQuery('SELECT s.ref_date, s.note, COUNT(l.leg_id), SUM(l.status = ''PENDING''), s.status FROM slips s LEFT JOIN slip_legs l ON l.slip_id = s.slip_id ' +
    'WHERE s.paper = 1 GROUP BY s.slip_id');
  try
    Q.Open;
    while not Q.Eof do
    begin
      Ref := Q.Fields[0].AsString; Note := Q.Fields[1].AsString; Legs := Q.Fields[2].AsInteger; Pending := Q.Fields[3].AsInteger;
      Id := 0; Open_ := 0;
      if (KindOfSlip(Note, Legs) <> 'VELIKI') and (KindOfSlip(Note, Legs) <> 'HEDGE') then
      begin
        if ASettled then begin if Pending < Legs then Id := 1; end
        else if Q.Fields[4].AsString = 'PENDING' then Id := 1;
        if (Id = 1) and (Ref > Best) then Best := Ref;
      end;
      Q.Next;
    end;
  finally
    Q.Free;
  end;
  Result := Best;
  if Open_ = 1 then Exit;
end;

end.
