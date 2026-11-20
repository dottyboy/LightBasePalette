unit ta_params;
{ Parametri u upitima (kao [Unesi datum] u Accessu). U spremljenom SQL-u parametar
  je oznaka [?Naziv]; pri izvrsavanju se zamjenjuje unesenom vrijednoscu. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, StrUtils;

type
  { Pita korisnika za ANames; AValues (Naziv=Vrijednost) sadrzi zadane vrijednosti
    i vraca odgovore. False = otkazano. }
  TParamPrompt = function(ANames, AValues: TStrings): Boolean;

  EParamCancel = class(EAbort);

var
  { Dijalekt SQL-a za izraze: postavlja ga TAppDb pri otvaranju baze. }
  SqlPostgres: Boolean = False;
  SqlMaria: Boolean = False;     { MariaDB/MySQL; ANSI_QUOTES i PIPES_AS_CONCAT su ukljuceni u sesiji }
  ParamPromptHook: TParamPrompt = nil;

{ Identifikator u navodnicima; u Postgresu malim slovima (nenavedeni nazivi se tamo
  svode na mala slova, pa SQL pisan bez navodnika pogada iste tablice i stupce). }
function QuoteIdent(const S: string): string;
{ SQL pisan za SQLite (ROUND(x, n), strftime('%Y', x)) u oblik koji razumije Postgres.
  Za generirane upite; korisnikov SQL se ne dira. }
function PortableSql(const ASql: string): string;
function ParamMarker(const AName: string): string;
{ Nazivi parametara u SQL-u, bez ponavljanja, redom pojavljivanja. }
function ParamNamesIn(const ASql: string): TStringList;
{ Unos -> SQL literal: broj, datum (ISO) ili tekst; prazno = NULL. }
function ParamLiteral(const AValue: string): string;
{ Zamjenjuje oznake vrijednostima iz AValues (Naziv=Vrijednost); nepoznati -> NULL. }
function SubstituteParams(const ASql: string; AValues: TStrings): string;

implementation

function QuoteIdent(const S: string): string;
begin
  if SqlPostgres or SqlMaria then Result := '"' + StringReplace(LowerCase(S), '"', '""', [rfReplaceAll]) + '"'
  else Result := '"' + StringReplace(S, '"', '""', [rfReplaceAll]) + '"';
end;

{ Pozicija zatvorene zagrade koja odgovara otvorenoj na AOpen; 0 ako je nema. }
function MatchParen(const S: string; AOpen: Integer): Integer;
var
  I, Depth: Integer;
  InStr: Boolean;
begin
  Depth := 0;
  InStr := False;
  for I := AOpen to Length(S) do
  begin
    if S[I] = '''' then InStr := not InStr
    else if not InStr then
    begin
      if S[I] = '(' then Inc(Depth)
      else if S[I] = ')' then
      begin
        Dec(Depth);
        if Depth = 0 then Exit(I);
      end;
    end;
  end;
  Result := 0;
end;

{ Zadnji zarez izvan zagrada i navodnika, 0 ako ga nema. }
function LastTopComma(const S: string): Integer;
var
  I, Depth: Integer;
  InStr: Boolean;
begin
  Result := 0;
  Depth := 0;
  InStr := False;
  for I := 1 to Length(S) do
  begin
    if S[I] = '''' then InStr := not InStr
    else if not InStr then
    begin
      if S[I] = '(' then Inc(Depth)
      else if S[I] = ')' then Dec(Depth)
      else if (S[I] = ',') and (Depth = 0) then Result := I;
    end;
  end;
end;

function PortableSql(const ASql: string): string;
var
  P, E, C, Start: Integer;
  Inner, Digits, Head, Tail: string;
begin
  Result := ASql;
  if SqlMaria then
  begin
    { strftime('%Y', x) -> DATE_FORMAT(x, '%Y') }
    P := Pos('strftime(''%Y'', ', Result);
    while P > 0 do
    begin
      E := MatchParen(Result, P + 8);
      if E = 0 then Break;
      Inner := Copy(Result, P + Length('strftime(''%Y'', '), E - P - Length('strftime(''%Y'', '));
      Result := Copy(Result, 1, P - 1) + 'DATE_FORMAT(' + Inner + ', ''%Y'')' + Copy(Result, E + 1, MaxInt);
      P := Pos('strftime(''%Y'', ', Result);
    end;
    Exit;
  end;
  if not SqlPostgres then Exit;
  { ROUND(izraz, n) -> ROUND(CAST(izraz AS numeric), n) }
  Start := 1;
  repeat
    P := PosEx('ROUND(', UpperCase(Result), Start);
    if P = 0 then Break;
    E := MatchParen(Result, P + 5);
    if E = 0 then Break;
    Inner := Copy(Result, P + 6, E - P - 6);
    C := LastTopComma(Inner);
    Head := Copy(Result, 1, P - 1);
    Tail := Copy(Result, E + 1, MaxInt);
    if C > 0 then
    begin
      Digits := Trim(Copy(Inner, C + 1, MaxInt));
      Inner := Copy(Inner, 1, C - 1);
      Result := Head + 'ROUND(CAST(' + Inner + ' AS numeric), ' + Digits + ')' + Tail;
    end
    else
      Result := Head + 'ROUND(CAST(' + Inner + ' AS numeric))' + Tail;
    Start := P + 6;
  until False;
  { strftime('%Y', x) -> to_char(CAST(x AS date), 'YYYY') }
  P := Pos('strftime(''%Y'', ', Result);
  while P > 0 do
  begin
    E := MatchParen(Result, P + 8);
    if E = 0 then Break;
    Inner := Copy(Result, P + Length('strftime(''%Y'', '), E - P - Length('strftime(''%Y'', '));
    Result := Copy(Result, 1, P - 1) + 'to_char(CAST(' + Inner + ' AS date), ''YYYY'')' + Copy(Result, E + 1, MaxInt);
    P := Pos('strftime(''%Y'', ', Result);
  end;
end;

function ParamMarker(const AName: string): string;
begin
  Result := '[?' + AName + ']';
end;

function ParamNamesIn(const ASql: string): TStringList;
var
  I, J: Integer;
  N: string;
begin
  Result := TStringList.Create;
  Result.CaseSensitive := False;
  I := 1;
  while I < Length(ASql) do
  begin
    if (ASql[I] = '[') and (ASql[I + 1] = '?') then
    begin
      J := I + 2;
      while (J <= Length(ASql)) and (ASql[J] <> ']') do Inc(J);
      if J > Length(ASql) then Break;
      N := Trim(Copy(ASql, I + 2, J - I - 2));
      if (N <> '') and (Result.IndexOf(N) < 0) then Result.Add(N);
      I := J + 1;
    end
    else Inc(I);
  end;
end;

function IsNumber(const S: string; out ANorm: string): Boolean;
var
  I, Dots: Integer;
  T: string;
begin
  T := StringReplace(Trim(S), ',', '.', []);
  Result := False;
  if T = '' then Exit;
  Dots := 0;
  for I := 1 to Length(T) do
    if T[I] = '.' then Inc(Dots)
    else if T[I] in ['0'..'9'] then
    else if (I = 1) and (T[I] in ['-', '+']) and (Length(T) > 1) then
    else Exit;
  Result := (Dots <= 1) and (T[Length(T)] <> '.') and (T[1] <> '.');
  { vodece nule (npr. OIB, sifra 007) ostaju tekst }
  if Result and (Length(T) > 1) and (T[1] = '0') and (T[2] <> '.') then Result := False;
  if Result then ANorm := T;
end;

function IsDate(const S: string; out AIso: string): Boolean;
var
  T: string;
  P: array[0..2] of Integer;
  Parts: TStringList;
  D, M, Y: Integer;
begin
  Result := False;
  T := Trim(S);
  if (Length(T) > 0) and (T[Length(T)] = '.') then T := Copy(T, 1, Length(T) - 1);
  Parts := TStringList.Create;
  try
    if Pos('-', T) > 0 then Parts.Delimiter := '-' else Parts.Delimiter := '.';
    Parts.StrictDelimiter := True;
    Parts.DelimitedText := T;
    if Parts.Count <> 3 then Exit;
    P[0] := StrToIntDef(Trim(Parts[0]), -1);
    P[1] := StrToIntDef(Trim(Parts[1]), -1);
    P[2] := StrToIntDef(Trim(Parts[2]), -1);
    if (P[0] < 0) or (P[1] < 0) or (P[2] < 0) then Exit;
    if Pos('-', T) > 0 then begin Y := P[0]; M := P[1]; D := P[2]; end
    else begin D := P[0]; M := P[1]; Y := P[2]; end;
    if (Y < 1000) or (Y > 9999) or (M < 1) or (M > 12) or (D < 1) or (D > 31) then Exit;
    AIso := Format('%.4d-%.2d-%.2d', [Y, M, D]);
    Result := True;
  finally
    Parts.Free;
  end;
end;

function ParamLiteral(const AValue: string): string;
var
  V: string;
begin
  if Trim(AValue) = '' then Exit('NULL');
  if IsNumber(AValue, V) then Exit(V);
  if IsDate(AValue, V) then Exit('''' + V + '''');
  Result := '''' + StringReplace(Trim(AValue), '''', '''''', [rfReplaceAll]) + '''';
end;

function SubstituteParams(const ASql: string; AValues: TStrings): string;
var
  I, J: Integer;
  N: string;
begin
  Result := '';
  I := 1;
  while I <= Length(ASql) do
  begin
    if (ASql[I] = '[') and (I < Length(ASql)) and (ASql[I + 1] = '?') then
    begin
      J := I + 2;
      while (J <= Length(ASql)) and (ASql[J] <> ']') do Inc(J);
      if J <= Length(ASql) then
      begin
        N := Trim(Copy(ASql, I + 2, J - I - 2));
        if (AValues <> nil) and (AValues.IndexOfName(N) >= 0) then
          Result := Result + ParamLiteral(AValues.Values[N])
        else
          Result := Result + 'NULL';
        I := J + 1;
        Continue;
      end;
    end;
    Result := Result + ASql[I];
    Inc(I);
  end;
end;

end.
