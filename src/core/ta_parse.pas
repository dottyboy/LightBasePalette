unit ta_parse;
{ Tolerant parsing of dates, times and numbers as people type them
  (1.2.2026, 01/02/2026, 2026-02-01, 1.234,5 ...). Shared by field types,
  import and the expression language. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math;

var
  ParseFS: TFormatSettings;   { invariant: '.' decimal separator }

function SplitInts(const S: string; out A: array of Integer; AMax: Integer): Integer;
function ParseDatePart(const S: string; out ADate: TDateTime): Boolean;
function ParseTimePart(const S: string; out ATime: TDateTime): Boolean;
function ParseNumber(const S: string; out V: Double): Boolean;
function SplitDateTime(const S: string; out ADatePart, ATimePart: string): Boolean;
{ Date, time or both in any of the accepted forms. }
function ParseAnyDateTime(const S: string; out ADateTime: TDateTime): Boolean;

implementation


function SplitInts(const S: string; out A: array of Integer; AMax: Integer): Integer;
var
  I, N: Integer;
  Cur: string;
begin
  N := 0;
  Cur := '';
  for I := 1 to Length(S) + 1 do
  begin
    if (I <= Length(S)) and (S[I] in ['0'..'9']) then Cur := Cur + S[I]
    else
    begin
      if Cur <> '' then
      begin
        if N < AMax then A[N] := StrToIntDef(Cur, -1);
        Inc(N);
        Cur := '';
      end;
    end;
  end;
  Result := N;
end;

function ParseDatePart(const S: string; out ADate: TDateTime): Boolean;
var
  P: array[0..2] of Integer;
  Y, M, D: Integer;
  First: string;
begin
  Result := False;
  if SplitInts(S, P, 3) <> 3 then Exit;
  First := '';
  while (Length(First) < Length(S)) and (S[Length(First) + 1] in ['0'..'9']) do
    First := First + S[Length(First) + 1];
  if Length(First) = 4 then begin Y := P[0]; M := P[1]; D := P[2]; end
  else begin D := P[0]; M := P[1]; Y := P[2]; end;
  if (Y >= 0) and (Y < 100) then Y := Y + 2000;
  Result := TryEncodeDate(Y, M, D, ADate);
end;

function ParseTimePart(const S: string; out ATime: TDateTime): Boolean;
var
  P: array[0..2] of Integer;
  N: Integer;
begin
  P[2] := 0;
  N := SplitInts(S, P, 3);
  if (N < 2) or (N > 3) then Exit(False);
  Result := TryEncodeTime(P[0], P[1], P[2], 0, ATime);
end;

function ParseNumber(const S: string; out V: Double): Boolean;
var
  T: string;
  I, LastComma, LastDot: Integer;
begin
  T := '';
  for I := 1 to Length(S) do
    if S[I] in ['0'..'9', '-', '+', '.', ','] then T := T + S[I];
  if (T = '') or (T = '-') or (T = '+') then Exit(False);
  LastComma := LastDelimiter(',', T);
  LastDot := LastDelimiter('.', T);
  if (LastComma > 0) and (LastDot > 0) then
  begin
    if LastComma > LastDot then
    begin
      T := StringReplace(T, '.', '', [rfReplaceAll]);
      T := StringReplace(T, ',', '.', [rfReplaceAll]);
    end
    else
      T := StringReplace(T, ',', '', [rfReplaceAll]);
  end
  else if LastComma > 0 then
    T := StringReplace(T, ',', '.', [rfReplaceAll]);
  Result := TryStrToFloat(T, V, ParseFS);
end;

function SplitDateTime(const S: string; out ADatePart, ATimePart: string): Boolean;
var
  P: Integer;
  T: string;
begin
  T := Trim(StringReplace(S, 'T', ' ', []));
  P := Pos(' ', T);
  if P > 0 then
  begin
    ADatePart := Copy(T, 1, P - 1);
    ATimePart := Trim(Copy(T, P + 1, MaxInt));
  end
  else
  begin
    ADatePart := T;
    ATimePart := '';
  end;
  Result := True;
end;


function ParseAnyDateTime(const S: string; out ADateTime: TDateTime): Boolean;
var
  DP, TP: string;
  D, T: TDateTime;
begin
  Result := False;
  ADateTime := 0;
  SplitDateTime(S, DP, TP);
  if (DP <> '') and (Pos(':', DP) > 0) and (TP = '') then
  begin
    { time only }
    if not ParseTimePart(DP, T) then Exit;
    ADateTime := T;
    Exit(True);
  end;
  if not ParseDatePart(DP, D) then Exit;
  T := 0;
  if TP <> '' then
    if not ParseTimePart(TP, T) then Exit;
  ADateTime := D + T;
  Result := True;
end;

initialization
  ParseFS := DefaultFormatSettings;
  ParseFS.DecimalSeparator := '.';
  ParseFS.ThousandSeparator := ',';
end.
