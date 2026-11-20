unit ta_condfmt;
{ Uvjetno oblikovanje: pravila oblika
    [iznos] > 1000 => #C00000 #FFE9E9 bold ;; [iznos] < 0 => #FFFFFF #C00000
  Prvo pravilo ciji je izraz istinit vrijedi. Boje su #RRGGBB, '-' znaci "bez promjene". }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ta_expr;

type
  TCondRule = record
    Expr, Fore, Back: string;     { boje kao #RRGGBB, prazno = bez promjene }
    Bold: Boolean;
  end;
  TCondRules = array of TCondRule;

function ParseCondFormat(const AText: string): TCondRules;
{ Prazan string = u redu, inace opis greske. }
function CondFormatError(const AText: string): string;
function MatchCondFormat(const ARules: TCondRules; AHost: TaExprHost; out ARule: TCondRule): Boolean;

implementation

function IsHexColor(const S: string): Boolean;
var
  I: Integer;
begin
  Result := (Length(S) = 7) and (S[1] = '#');
  if Result then
    for I := 2 to 7 do
      if not (S[I] in ['0'..'9', 'A'..'F', 'a'..'f']) then Exit(False);
end;

function LastArrow(const S: string): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := Length(S) - 1 downto 1 do
    if (S[I] = '=') and (S[I + 1] = '>') then Exit(I);
end;

function ParseCondFormat(const AText: string): TCondRules;
var
  S, Item, Style, Tok: string;
  P, K, N, Colors: Integer;
  Toks: TStringList;
  R: TCondRule;
begin
  SetLength(Result, 0);
  S := AText;
  N := 0;
  while Trim(S) <> '' do
  begin
    P := Pos(';;', S);
    if P = 0 then begin Item := S; S := ''; end
    else begin Item := Copy(S, 1, P - 1); S := Copy(S, P + 2, MaxInt); end;
    K := LastArrow(Item);
    if K < 2 then Continue;
    R.Expr := Trim(Copy(Item, 1, K - 1));
    Style := Trim(Copy(Item, K + 2, MaxInt));
    R.Fore := ''; R.Back := ''; R.Bold := False;
    Toks := TStringList.Create;
    try
      Toks.Delimiter := ' ';
      Toks.StrictDelimiter := True;
      Toks.DelimitedText := Style;
      Colors := 0;
      for P := 0 to Toks.Count - 1 do
      begin
        Tok := Trim(Toks[P]);
        if Tok = '' then Continue;
        if SameText(Tok, 'bold') then R.Bold := True
        else if (Tok = '-') or IsHexColor(Tok) then
        begin
          if Tok = '-' then Tok := '';
          if Colors = 0 then R.Fore := UpperCase(Tok)
          else if Colors = 1 then R.Back := UpperCase(Tok);
          Inc(Colors);
        end;
      end;
    finally
      Toks.Free;
    end;
    if R.Expr = '' then Continue;
    SetLength(Result, N + 1);
    Result[N] := R;
    Inc(N);
  end;
end;

function CondFormatError(const AText: string): string;
var
  S, Item, Style, Tok: string;
  P, K, I: Integer;
  Toks: TStringList;
begin
  Result := '';
  S := AText;
  while Trim(S) <> '' do
  begin
    P := Pos(';;', S);
    if P = 0 then begin Item := S; S := ''; end
    else begin Item := Copy(S, 1, P - 1); S := Copy(S, P + 2, MaxInt); end;
    if Trim(Item) = '' then Continue;
    K := LastArrow(Item);
    if K < 2 then Exit('Pravilo "' + Trim(Item) + '" nema oblik izraz => boje.');
    Style := Trim(Copy(Item, K + 2, MaxInt));
    Toks := TStringList.Create;
    try
      Toks.Delimiter := ' ';
      Toks.StrictDelimiter := True;
      Toks.DelimitedText := Style;
      for I := 0 to Toks.Count - 1 do
      begin
        Tok := Trim(Toks[I]);
        if (Tok <> '') and not (SameText(Tok, 'bold') or (Tok = '-') or IsHexColor(Tok)) then
          Exit('Nepoznato u stilu: "' + Tok + '" (boje su #RRGGBB, uz bold).');
      end;
    finally
      Toks.Free;
    end;
  end;
end;

function MatchCondFormat(const ARules: TCondRules; AHost: TaExprHost; out ARule: TCondRule): Boolean;
var
  I: Integer;
  Err: string;
  V: Variant;
begin
  Result := False;
  for I := 0 to High(ARules) do
  begin
    V := EvalExprEx(ARules[I].Expr, AHost, Err);
    if (Err = '') and ExprIsTrue(V) then
    begin
      ARule := ARules[I];
      Exit(True);
    end;
  end;
end;

end.
