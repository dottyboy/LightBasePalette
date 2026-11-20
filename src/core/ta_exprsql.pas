unit ta_exprsql;
{ Translates the expression language into SQLite SQL, so a calculated field in a
  query (or a generated table column) can be written the same way as anywhere
  else: [ime] & " " & [prezime], Iif([iznos] > 100, "velik", "mali"),
  DateAdd("d", 30, [datum]) ...

  Anything with no SQL equivalent (ValidOIB, Proper, RunSum ...) is reported by
  name instead of silently producing something different. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, ta_parse, ta_expr, ta_params;

type
  { Gets the SQL for a [name]; may raise to say the name is unknown or ambiguous. }
  TSqlFieldResolver = function(const AName: string): string of object;

function ExprToSql(const AExpr: string; AResolver: TSqlFieldResolver; out ASql, AError: string): Boolean;
{ names used as [field] in the expression }
function ExprFieldNames(const AExpr: string): TStringList;

implementation

type
  ESqlTr = class(Exception);

  TArg = record
    Sql: string;
    IsLit: Boolean;
    Lit: string;
  end;
  TArgs = array of TArg;

  TTr = class
  public
    S: string;
    P: Integer;
    Resolver: TSqlFieldResolver;
    CurName: string;      { the function name as the user typed it, for messages }
    function Peek: Char;
    function WordAt: string;
    function TryWord(const W: string): Boolean;
    function ParseOr: string;
    function ParseXor: string;
    function ParseAnd: string;
    function ParseNot: string;
    function ParseCmp: string;
    function ParseConcat: string;
    function ParseAdd: string;
    function ParseMod: string;
    function ParseMul: string;
    function ParseUnary: string;
    function ParsePow: string;
    function ParsePrimary: string;
    function ParseArgList: TArgs;
    function Call(const AName: string; const A: TArgs): string;
    procedure Expect(C: Char);
  end;

function Q(const S: string): string;
begin
  Result := '''' + StringReplace(S, '''', '''''', [rfReplaceAll]) + '''';
end;

function QId(const S: string): string;
begin
  Result := QuoteIdent(S);
end;

procedure Fail(const AMsg: string);
begin
  raise ESqlTr.Create(AMsg);
end;

function TTr.Peek: Char;
begin
  while (P <= Length(S)) and (S[P] in [' ', #9, #10, #13]) do Inc(P);
  if P > Length(S) then Result := #0 else Result := S[P];
end;

function TTr.WordAt: string;
var
  K: Integer;
begin
  Peek;
  Result := '';
  K := P;
  while (K <= Length(S)) and (S[K] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) do
  begin
    Result := Result + S[K];
    Inc(K);
  end;
end;

function TTr.TryWord(const W: string): Boolean;
begin
  Result := SameText(WordAt, W);
  if Result then Inc(P, Length(W));
end;

procedure TTr.Expect(C: Char);
begin
  if Peek <> C then Fail('Očekivano "' + C + '"');
  Inc(P);
end;

function CoalText(const X: string): string;
begin
  if SqlPostgres then Result := 'COALESCE(CAST(' + X + ' AS text), '''')'
  else Result := 'COALESCE(' + X + ', '''')';
end;

function RealType: string;
begin
  if SqlPostgres then Result := 'double precision'
  else if SqlMaria then Result := 'DOUBLE'
  else Result := 'REAL';
end;

function IntType: string;
begin
  if SqlMaria then Result := 'SIGNED' else Result := 'INTEGER';
end;

function LikeKw: string;
begin
  if SqlPostgres then Result := ' ILIKE ' else Result := ' LIKE ';
end;

function TTr.ParseOr: string;
begin
  Result := ParseXor;
  while TryWord('Or') do Result := '(' + Result + ' OR ' + ParseXor + ')';
end;

function TTr.ParseXor: string;
begin
  Result := ParseAnd;
  while TryWord('Xor') do Result := '((' + Result + ') <> (' + ParseAnd + '))';
end;

function TTr.ParseAnd: string;
begin
  Result := ParseNot;
  while TryWord('And') do Result := '(' + Result + ' AND ' + ParseNot + ')';
end;

function TTr.ParseNot: string;
begin
  if TryWord('Not') then Result := '(NOT ' + ParseNot() + ')'
  else Result := ParseCmp;
end;

function LikePattern(const AAccess: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(AAccess) do
    case AAccess[I] of
      '*': Result := Result + '%';
      '?', '#': Result := Result + '_';
    else
      Result := Result + AAccess[I];
    end;
end;

function TTr.ParseCmp: string;
var
  R, R2, Op, Lit: string;
  Neg: Boolean;
  StartP: Integer;
  Args: TArgs;
begin
  Result := ParseConcat;
  repeat
    Peek;
    Op := '';
    if P <= Length(S) then
    begin
      if (P < Length(S)) and (Copy(S, P, 2) = '<>') then Op := '<>'
      else if (P < Length(S)) and (Copy(S, P, 2) = '<=') then Op := '<='
      else if (P < Length(S)) and (Copy(S, P, 2) = '>=') then Op := '>='
      else if S[P] = '=' then Op := '='
      else if S[P] = '<' then Op := '<'
      else if S[P] = '>' then Op := '>';
    end;
    if Op <> '' then
    begin
      Inc(P, Length(Op));
      Result := '(' + Result + ' ' + Op + ' ' + ParseConcat + ')';
    end
    else if TryWord('Like') then
    begin
      Peek;
      StartP := P;
      if (P <= Length(S)) and (S[P] in ['"', '''']) then
      begin
        R := ParseConcat;
        { a plain string literal: turn the Access wildcards into SQL ones }
        if (Copy(R, 1, 1) = '''') and (R[Length(R)] = '''') and (Pos('||', R) = 0) then
          R := Q(LikePattern(StringReplace(Copy(R, 2, Length(R) - 2), '''''', '''', [rfReplaceAll])));
        Result := '(' + Result + LikeKw + R + ')';
      end
      else Result := '(' + Result + LikeKw + ParseConcat + ')';
    end
    else if TryWord('Is') then
    begin
      Neg := TryWord('Not');
      if not TryWord('Null') then Fail('Očekivano Null nakon Is');
      if Neg then Result := '(' + Result + ' IS NOT NULL)' else Result := '(' + Result + ' IS NULL)';
    end
    else if TryWord('Between') then
    begin
      R := ParseConcat;
      if not TryWord('And') then Fail('Očekivano And u Between');
      R2 := ParseConcat;
      Result := '(' + Result + ' BETWEEN ' + R + ' AND ' + R2 + ')';
    end
    else if TryWord('In') then
    begin
      Expect('(');
      R := '';
      repeat
        if R <> '' then R := R + ', ';
        R := R + ParseOr;
        Peek;
        if (P <= Length(S)) and (S[P] = ',') then Inc(P) else Break;
      until False;
      Expect(')');
      Result := '(' + Result + ' IN (' + R + '))';
    end
    else Break;
  until False;
  Lit := '';
  SetLength(Args, 0);
end;

function TTr.ParseConcat: string;
begin
  Result := ParseAdd;
  while Peek = '&' do
  begin
    Inc(P);
    Result := '(' + CoalText(Result) + ' || ' + CoalText(ParseAdd) + ')';
  end;
end;

function TTr.ParseAdd: string;
var
  C: Char;
  R: string;
begin
  Result := ParseMod;
  repeat
    C := Peek;
    if not (C in ['+', '-']) then Break;
    Inc(P);
    R := ParseMod;
    { text + text joins, like the expression language }
    if (C = '+') and ((Copy(Result, 1, 1) = '''') or (Copy(R, 1, 1) = '''')) then
      Result := '(' + CoalText(Result) + ' || ' + CoalText(R) + ')'
    else
      Result := '(' + Result + ' ' + C + ' ' + R + ')';
  until False;
end;

function TTr.ParseMod: string;
begin
  Result := ParseMul;
  while TryWord('Mod') do
    Result := '(CAST(' + Result + ' AS ' + IntType + ') % CAST(' + ParseMul + ' AS ' + IntType + '))';
end;

function TTr.ParseMul: string;
var
  C: Char;
  R: string;
begin
  Result := ParseUnary;
  repeat
    C := Peek;
    if not (C in ['*', '/', '\']) then Break;
    Inc(P);
    R := ParseUnary;
    if C = '*' then Result := '(' + Result + ' * ' + R + ')'
    else if C = '/' then Result := '(CAST(' + Result + ' AS ' + RealType + ') / ' + R + ')'
    else if SqlMaria then Result := '(CAST(' + Result + ' AS SIGNED) DIV CAST(' + R + ' AS SIGNED))'
    else Result := '(CAST(' + Result + ' AS INTEGER) / CAST(' + R + ' AS INTEGER))';
  until False;
end;

function TTr.ParseUnary: string;
begin
  if Peek = '-' then begin Inc(P); Result := '(-' + ParseUnary() + ')'; end
  else if Peek = '+' then begin Inc(P); Result := ParseUnary(); end
  else Result := ParsePow;
end;

function TTr.ParsePow: string;
begin
  Result := ParsePrimary;
  while Peek = '^' do
  begin
    Inc(P);
    Result := 'power(' + Result + ', ' + ParseUnary + ')';
  end;
end;

function TTr.ParseArgList: TArgs;
var
  N, StartP: Integer;
  Raw: string;
begin
  { P is just after '(' }
  SetLength(Result, 0);
  N := 0;
  if Peek = ')' then begin Inc(P); Exit; end;
  repeat
    SetLength(Result, N + 1);
    Peek;
    if (P <= Length(S)) and (S[P] = '*') then
    begin
      Inc(P);
      Result[N].Sql := '*';
    end
    else
    begin
      StartP := P;
      Result[N].Sql := ParseOr;
      Raw := Trim(Copy(S, StartP, P - StartP));
      Result[N].IsLit := (Length(Raw) >= 2) and (Raw[1] in ['"', '''']) and (Raw[Length(Raw)] = Raw[1]) and
        (Pos(Raw[1], Copy(Raw, 2, Length(Raw) - 2)) = 0);
      if Result[N].IsLit then Result[N].Lit := Copy(Raw, 2, Length(Raw) - 2);
    end;
    Inc(N);
    if Peek = ',' then Inc(P) else Break;
  until False;
  Expect(')');
end;

function TTr.ParsePrimary: string;
var
  C: Char;
  Start: Integer;
  W, Fn, Str: string;
  A: TArgs;
  D: TDateTime;
begin
  C := Peek;
  if C = '(' then
  begin
    Inc(P);
    Result := ParseOr;
    Expect(')');
    Result := '(' + Result + ')';
  end
  else if C in ['0'..'9', '.'] then
  begin
    Start := P;
    while (P <= Length(S)) and (S[P] in ['0'..'9', '.']) do Inc(P);
    Result := Copy(S, Start, P - Start);
  end
  else if C in ['"', ''''] then
  begin
    Inc(P);
    Str := '';
    while P <= Length(S) do
    begin
      if S[P] = C then
      begin
        if (P < Length(S)) and (S[P + 1] = C) then begin Str := Str + C; Inc(P, 2); Continue; end;
        Break;
      end;
      Str := Str + S[P];
      Inc(P);
    end;
    if P > Length(S) then Fail('Nezatvoren tekst');
    Inc(P);
    Result := Q(Str);
  end
  else if C = '#' then
  begin
    Inc(P);
    Start := P;
    while (P <= Length(S)) and (S[P] <> '#') do Inc(P);
    if not ParseAnyDateTime(Copy(S, Start, P - Start), D) then Fail('Neispravan datum');
    Inc(P);
    if Frac(D) = 0 then Result := Q(FormatDateTime('yyyy-mm-dd', D))
    else Result := Q(FormatDateTime('yyyy-mm-dd hh:nn:ss', D));
  end
  else if C = '[' then
  begin
    Inc(P);
    Start := P;
    while (P <= Length(S)) and (S[P] <> ']') do Inc(P);
    if P > Length(S) then Fail('Nezatvorena zagrada [');
    W := Copy(S, Start, P - Start);
    Inc(P);
    if Assigned(Resolver) then Result := Resolver(W) else Result := QId(W);
  end
  else if C in ['A'..'Z', 'a'..'z', '_'] then
  begin
    W := WordAt;
    Fn := LowerCase(W);
    Inc(P, Length(W));
    if Fn = 'true' then begin if SqlPostgres then Exit('TRUE'); Exit('1'); end;
    if Fn = 'false' then begin if SqlPostgres then Exit('FALSE'); Exit('0'); end;
    if Fn = 'null' then Exit('NULL');
    if Peek = '(' then
    begin
      Inc(P);
      A := ParseArgList;
      CurName := W;
      Result := Call(Fn, A);
    end
    else
    begin
      SetLength(A, 0);
      CurName := W;
      Result := Call(Fn, A);
    end;
  end
  else
    Fail('Sintaksa');
end;

{ ---------------- functions ---------------- }

function IntervalUnit(const AIv: string; out AIsTime: Boolean): string;
var
  L: string;
begin
  L := LowerCase(AIv);
  AIsTime := False;
  if L = 'yyyy' then Result := 'years'
  else if L = 'q' then Result := 'months'
  else if L = 'm' then Result := 'months'
  else if (L = 'd') or (L = 'y') or (L = 'w') then Result := 'days'
  else if L = 'ww' then Result := 'days'
  else if L = 'h' then begin Result := 'hours'; AIsTime := True; end
  else if L = 'n' then begin Result := 'minutes'; AIsTime := True; end
  else if L = 's' then begin Result := 'seconds'; AIsTime := True; end
  else Fail('Nepoznat interval: ' + AIv);
end;

function StrftimeFormat(const AFmt: string): string;
var
  I: Integer;
  S: string;
begin
  { yyyy mm dd hh nn ss  ->  %Y %m %d %H %M %S }
  S := AFmt;
  Result := '';
  I := 1;
  while I <= Length(S) do
  begin
    if Copy(LowerCase(S), I, 4) = 'yyyy' then begin Result := Result + '%Y'; Inc(I, 4); end
    else if Copy(LowerCase(S), I, 2) = 'yy' then begin Result := Result + '%y'; Inc(I, 2); end
    else if Copy(LowerCase(S), I, 2) = 'mm' then begin Result := Result + '%m'; Inc(I, 2); end
    else if Copy(LowerCase(S), I, 2) = 'dd' then begin Result := Result + '%d'; Inc(I, 2); end
    else if Copy(LowerCase(S), I, 2) = 'hh' then begin Result := Result + '%H'; Inc(I, 2); end
    else if Copy(LowerCase(S), I, 2) = 'nn' then begin Result := Result + '%M'; Inc(I, 2); end
    else if Copy(LowerCase(S), I, 2) = 'ss' then begin Result := Result + '%S'; Inc(I, 2); end
    else if S[I] = '%' then begin Result := Result + '%%'; Inc(I); end
    else begin Result := Result + S[I]; Inc(I); end;
  end;
end;

{ ---------------- Postgres dijalekt ---------------- }

function PgT(const X: string): string;
begin
  Result := 'CAST(' + X + ' AS text)';
end;

function PgTs(const X: string): string;
begin
  Result := 'CAST(' + X + ' AS timestamp)';
end;

function PgIsoDate(const X: string): string;
begin
  Result := 'to_char(' + X + ', ''YYYY-MM-DD'')';
end;

function PgPart(const APart, X: string): string;
begin
  Result := 'CAST(EXTRACT(' + APart + ' FROM ' + PgTs(X) + ') AS integer)';
end;

function PgMonths(const X: string): string;
begin
  Result := '(' + PgPart('year', X) + ' * 12 + ' + PgPart('month', X) + ')';
end;

{ yyyy mm dd hh nn ss  ->  YYYY MM DD HH24 MI SS }
function PgDateFormat(const AFmt: string): string;
var
  I: Integer;
  L: string;
begin
  L := LowerCase(AFmt);
  Result := '';
  I := 1;
  while I <= Length(L) do
  begin
    if Copy(L, I, 4) = 'yyyy' then begin Result := Result + 'YYYY'; Inc(I, 4); end
    else if Copy(L, I, 2) = 'yy' then begin Result := Result + 'YY'; Inc(I, 2); end
    else if Copy(L, I, 2) = 'mm' then begin Result := Result + 'MM'; Inc(I, 2); end
    else if Copy(L, I, 2) = 'dd' then begin Result := Result + 'DD'; Inc(I, 2); end
    else if Copy(L, I, 2) = 'hh' then begin Result := Result + 'HH24'; Inc(I, 2); end
    else if Copy(L, I, 2) = 'nn' then begin Result := Result + 'MI'; Inc(I, 2); end
    else if Copy(L, I, 2) = 'ss' then begin Result := Result + 'SS'; Inc(I, 2); end
    else begin Result := Result + '"' + AFmt[I] + '"'; Inc(I); end;
  end;
end;

function PgFixed(const AValue: string; ADec: Integer): string;
var
  F: string;
begin
  F := 'FM999999999999990';
  if ADec > 0 then F := F + '.' + StringOfChar('0', ADec);
  Result := 'to_char(CAST(' + AValue + ' AS numeric), ' + Q(F) + ')';
end;

{ True kad je funkcija prevedena (AResult); inace vrijedi zajednicki prijevod. }
function PgCall(const Fn: string; const A: TArgs; out AResult: string): Boolean;
var
  N, I: Integer;
  Iv, Un, D, Fmt: string;
  IsTime: Boolean;

  procedure Need(Cnt: Integer);
  begin
    if N < Cnt then Fail('Funkciji ' + Fn + ' nedostaju argumenti');
  end;

  function Days(const AFrom, ATo: string): string;
  begin
    Result := 'CAST(CAST(' + ATo + ' AS date) - CAST(' + AFrom + ' AS date) AS integer)';
  end;

  function Secs(const AFrom, ATo: string): string;
  begin
    Result := 'EXTRACT(epoch FROM (' + PgTs(ATo) + ' - ' + PgTs(AFrom) + '))';
  end;

begin
  N := Length(A);
  AResult := '';
  Result := True;
  if N = 0 then
  begin
    if (Fn = 'date') or (Fn = 'today') then begin AResult := PgIsoDate('CURRENT_DATE'); Exit; end;
    if Fn = 'now' then begin AResult := 'to_char(localtimestamp(0), ''YYYY-MM-DD HH24:MI:SS'')'; Exit; end;
    if Fn = 'time' then begin AResult := 'to_char(localtime(0), ''HH24:MI:SS'')'; Exit; end;
    Result := False;
    Exit;
  end;
  if Fn = 'nz' then
  begin
    Need(1);
    if N >= 2 then D := A[1].Sql else D := '0';
    { brojcani zadani izraz u navodnicima: Postgres ga sam svede na tip prvog argumenta }
    Iv := D;
    if (Iv <> '') and (Iv[1] = '(') and (Iv[Length(Iv)] = ')') then Iv := Copy(Iv, 2, Length(Iv) - 2);
    Iv := StringReplace(Iv, ' ', '', [rfReplaceAll]);
    IsTime := Iv <> '';
    for I := 1 to Length(Iv) do
      if not (Iv[I] in ['0'..'9', '.', '-']) then IsTime := False;
    if IsTime then
      D := Q(Iv);
    AResult := 'COALESCE(' + A[0].Sql + ', ' + D + ')';
    Exit;
  end;
  { ---- tekst ---- }
  if Fn = 'isempty' then begin Need(1); AResult := '(' + A[0].Sql + ' IS NULL OR trim(' + PgT(A[0].Sql) + ') = '''')'; Exit; end;
  if Fn = 'len' then begin Need(1); AResult := 'char_length(' + PgT(A[0].Sql) + ')'; Exit; end;
  if Fn = 'left' then begin Need(2); AResult := 'left(' + PgT(A[0].Sql) + ', ' + A[1].Sql + ')'; Exit; end;
  if Fn = 'right' then begin Need(2); AResult := 'right(' + PgT(A[0].Sql) + ', ' + A[1].Sql + ')'; Exit; end;
  if Fn = 'mid' then
  begin
    Need(2);
    if N >= 3 then AResult := 'substr(' + PgT(A[0].Sql) + ', ' + A[1].Sql + ', ' + A[2].Sql + ')'
    else AResult := 'substr(' + PgT(A[0].Sql) + ', ' + A[1].Sql + ')';
    Exit;
  end;
  if Fn = 'ucase' then begin Need(1); AResult := 'upper(' + PgT(A[0].Sql) + ')'; Exit; end;
  if Fn = 'lcase' then begin Need(1); AResult := 'lower(' + PgT(A[0].Sql) + ')'; Exit; end;
  if Fn = 'trim' then begin Need(1); AResult := 'trim(' + PgT(A[0].Sql) + ')'; Exit; end;
  if Fn = 'ltrim' then begin Need(1); AResult := 'ltrim(' + PgT(A[0].Sql) + ')'; Exit; end;
  if Fn = 'rtrim' then begin Need(1); AResult := 'rtrim(' + PgT(A[0].Sql) + ')'; Exit; end;
  if Fn = 'replace' then begin Need(3); AResult := 'replace(' + PgT(A[0].Sql) + ', ' + PgT(A[1].Sql) + ', ' + PgT(A[2].Sql) + ')'; Exit; end;
  if Fn = 'instr' then begin Need(2); AResult := 'strpos(lower(' + PgT(A[0].Sql) + '), lower(' + PgT(A[1].Sql) + '))'; Exit; end;
  if Fn = 'concat' then
  begin
    Need(1);
    AResult := '(';
    for I := 0 to N - 1 do
    begin
      if I > 0 then AResult := AResult + ' || ';
      AResult := AResult + 'COALESCE(' + PgT(A[I].Sql) + ', '''')';
    end;
    AResult := AResult + ')';
    Exit;
  end;
  if Fn = 'startswith' then begin Need(2); AResult := '(' + PgT(A[0].Sql) + ' ILIKE (' + PgT(A[1].Sql) + ' || ''%''))'; Exit; end;
  if Fn = 'endswith' then begin Need(2); AResult := '(' + PgT(A[0].Sql) + ' ILIKE (''%'' || ' + PgT(A[1].Sql) + '))'; Exit; end;
  if Fn = 'contains' then begin Need(2); AResult := '(strpos(lower(' + PgT(A[0].Sql) + '), lower(' + PgT(A[1].Sql) + ')) > 0)'; Exit; end;
  if Fn = 'space' then begin Need(1); AResult := 'repeat('' '', ' + A[0].Sql + ')'; Exit; end;
  if Fn = 'string' then begin Need(2); AResult := 'repeat(substr(' + PgT(A[1].Sql) + ', 1, 1), ' + A[0].Sql + ')'; Exit; end;
  { ---- brojevi ---- }
  if (Fn = 'round') or (Fn = 'zaokruzi') then
  begin
    Need(1);
    if N >= 2 then AResult := 'round(CAST(' + A[0].Sql + ' AS numeric), ' + A[1].Sql + ')'
    else AResult := 'round(CAST(' + A[0].Sql + ' AS numeric))';
    Exit;
  end;
  if (Fn = 'int') or (Fn = 'floor') then begin Need(1); AResult := 'CAST(floor(' + A[0].Sql + ') AS bigint)'; Exit; end;
  if Fn = 'ceil' then begin Need(1); AResult := 'CAST(ceil(' + A[0].Sql + ') AS bigint)'; Exit; end;
  if Fn = 'fix' then begin Need(1); AResult := 'CAST(trunc(' + A[0].Sql + ') AS bigint)'; Exit; end;
  if (Fn = 'val') or (Fn = 'cdbl') then begin Need(1); AResult := 'CAST(' + A[0].Sql + ' AS double precision)'; Exit; end;
  if (Fn = 'cint') or (Fn = 'clng') then begin Need(1); AResult := 'CAST(round(CAST(' + A[0].Sql + ' AS numeric)) AS bigint)'; Exit; end;
  if Fn = 'clamp' then begin Need(3); AResult := 'greatest(' + A[1].Sql + ', least(' + A[0].Sql + ', ' + A[2].Sql + '))'; Exit; end;
  if ((Fn = 'max') or (Fn = 'min')) and (N >= 2) and (A[0].Sql <> '*') then
  begin
    if Fn = 'max' then AResult := 'greatest(' else AResult := 'least(';
    for I := 0 to N - 1 do
    begin
      if I > 0 then AResult := AResult + ', ';
      AResult := AResult + A[I].Sql;
    end;
    AResult := AResult + ')';
    Exit;
  end;
  { ---- datumi (ISO tekst ili date/timestamp) ---- }
  if Fn = 'year' then begin Need(1); AResult := PgPart('year', A[0].Sql); Exit; end;
  if Fn = 'month' then begin Need(1); AResult := PgPart('month', A[0].Sql); Exit; end;
  if Fn = 'day' then begin Need(1); AResult := PgPart('day', A[0].Sql); Exit; end;
  if Fn = 'hour' then begin Need(1); AResult := PgPart('hour', A[0].Sql); Exit; end;
  if Fn = 'minute' then begin Need(1); AResult := PgPart('minute', A[0].Sql); Exit; end;
  if Fn = 'second' then begin Need(1); AResult := PgPart('second', A[0].Sql); Exit; end;
  if Fn = 'weekday' then begin Need(1); AResult := '(' + PgPart('dow', A[0].Sql) + ' + 1)'; Exit; end;
  if Fn = 'quarter' then begin Need(1); AResult := PgPart('quarter', A[0].Sql); Exit; end;
  if Fn = 'eomonth' then
  begin
    Need(1);
    AResult := PgIsoDate('(date_trunc(''month'', ' + PgTs(A[0].Sql) + ') + interval ''1 month'' - interval ''1 day'')');
    Exit;
  end;
  if Fn = 'bomonth' then begin Need(1); AResult := PgIsoDate('date_trunc(''month'', ' + PgTs(A[0].Sql) + ')'); Exit; end;
  if Fn = 'adddays' then begin Need(2); AResult := PgIsoDate('(' + PgTs(A[0].Sql) + ' + (' + A[1].Sql + ') * interval ''1 day'')'); Exit; end;
  if Fn = 'addmonths' then begin Need(2); AResult := PgIsoDate('(' + PgTs(A[0].Sql) + ' + (' + A[1].Sql + ') * interval ''1 month'')'); Exit; end;
  if Fn = 'daysbetween' then begin Need(2); AResult := Days(A[0].Sql, A[1].Sql); Exit; end;
  if Fn = 'dateserial' then
  begin
    Need(3);
    AResult := PgIsoDate('make_date(' + A[0].Sql + ', ' + A[1].Sql + ', ' + A[2].Sql + ')');
    Exit;
  end;
  if (Fn = 'datevalue') or (Fn = 'cdate') then begin Need(1); AResult := PgIsoDate(PgTs(A[0].Sql)); Exit; end;
  if Fn = 'age' then
  begin
    Need(1);
    if N >= 2 then AResult := 'CAST(EXTRACT(year FROM age(' + PgTs(A[1].Sql) + ', ' + PgTs(A[0].Sql) + ')) AS integer)'
    else AResult := 'CAST(EXTRACT(year FROM age(' + PgTs(A[0].Sql) + ')) AS integer)';
    Exit;
  end;
  if Fn = 'dateadd' then
  begin
    Need(3);
    if not A[0].IsLit then Fail('DateAdd traži interval kao tekst, npr. "d" ili "m".');
    Un := IntervalUnit(A[0].Lit, IsTime);
    Un := Copy(Un, 1, Length(Un) - 1);   { days -> day }
    Iv := LowerCase(A[0].Lit);
    D := '(' + A[1].Sql + ')';
    if Iv = 'q' then D := '(' + A[1].Sql + ' * 3)'
    else if Iv = 'ww' then D := '(' + A[1].Sql + ' * 7)';
    if IsTime then Fmt := 'YYYY-MM-DD HH24:MI:SS' else Fmt := 'YYYY-MM-DD';
    AResult := 'to_char(' + PgTs(A[2].Sql) + ' + ' + D + ' * interval ''1 ' + Un + ''', ' + Q(Fmt) + ')';
    Exit;
  end;
  if Fn = 'datediff' then
  begin
    Need(3);
    if not A[0].IsLit then Fail('DateDiff traži interval kao tekst, npr. "d" ili "m".');
    Iv := LowerCase(A[0].Lit);
    if Iv = 'yyyy' then begin AResult := '(' + PgPart('year', A[2].Sql) + ' - ' + PgPart('year', A[1].Sql) + ')'; Exit; end;
    if Iv = 'm' then begin AResult := '(' + PgMonths(A[2].Sql) + ' - ' + PgMonths(A[1].Sql) + ')'; Exit; end;
    if Iv = 'q' then begin AResult := '((' + PgMonths(A[2].Sql) + ' - ' + PgMonths(A[1].Sql) + ') / 3)'; Exit; end;
    if (Iv = 'd') or (Iv = 'y') or (Iv = 'w') then begin AResult := Days(A[1].Sql, A[2].Sql); Exit; end;
    if Iv = 'ww' then begin AResult := '(' + Days(A[1].Sql, A[2].Sql) + ' / 7)'; Exit; end;
    if Iv = 'h' then begin AResult := 'CAST(' + Secs(A[1].Sql, A[2].Sql) + ' / 3600 AS bigint)'; Exit; end;
    if Iv = 'n' then begin AResult := 'CAST(' + Secs(A[1].Sql, A[2].Sql) + ' / 60 AS bigint)'; Exit; end;
    if Iv = 's' then begin AResult := 'CAST(' + Secs(A[1].Sql, A[2].Sql) + ' AS bigint)'; Exit; end;
    Fail('Nepoznat interval: ' + A[0].Lit);
  end;
  Result := False;
end;

{ ---------------- MariaDB/MySQL dijalekt ---------------- }

function MaDate(const X: string): string;
begin
  Result := 'DATE_FORMAT(' + X + ', ''%Y-%m-%d'')';
end;

function MaMonths(const X: string): string;
begin
  Result := '(YEAR(' + X + ') * 12 + MONTH(' + X + '))';
end;

{ yyyy mm dd hh nn ss  ->  %Y %m %d %H %i %s }
function MaDateFormat(const AFmt: string): string;
var
  I: Integer;
  L: string;
begin
  L := LowerCase(AFmt);
  Result := '';
  I := 1;
  while I <= Length(L) do
  begin
    if Copy(L, I, 4) = 'yyyy' then begin Result := Result + '%Y'; Inc(I, 4); end
    else if Copy(L, I, 2) = 'yy' then begin Result := Result + '%y'; Inc(I, 2); end
    else if Copy(L, I, 2) = 'mm' then begin Result := Result + '%m'; Inc(I, 2); end
    else if Copy(L, I, 2) = 'dd' then begin Result := Result + '%d'; Inc(I, 2); end
    else if Copy(L, I, 2) = 'hh' then begin Result := Result + '%H'; Inc(I, 2); end
    else if Copy(L, I, 2) = 'nn' then begin Result := Result + '%i'; Inc(I, 2); end
    else if Copy(L, I, 2) = 'ss' then begin Result := Result + '%s'; Inc(I, 2); end
    else if AFmt[I] = '%' then begin Result := Result + '%%'; Inc(I); end
    else begin Result := Result + AFmt[I]; Inc(I); end;
  end;
end;

function MaFixed(const AValue: string; ADec: Integer): string;
begin
  Result := 'CAST(CAST(' + AValue + ' AS DECIMAL(30,' + IntToStr(ADec) + ')) AS CHAR)';
end;

function MariaCall(const Fn: string; const A: TArgs; out AResult: string): Boolean;
var
  N, I: Integer;
  Iv, Un, D, Fmt: string;
  IsTime: Boolean;

  procedure Need(Cnt: Integer);
  begin
    if N < Cnt then Fail('Funkciji ' + Fn + ' nedostaju argumenti');
  end;

begin
  N := Length(A);
  AResult := '';
  Result := True;
  if N = 0 then
  begin
    if (Fn = 'date') or (Fn = 'today') then begin AResult := MaDate('CURDATE()'); Exit; end;
    if Fn = 'now' then begin AResult := 'DATE_FORMAT(NOW(), ''%Y-%m-%d %H:%i:%s'')'; Exit; end;
    if Fn = 'time' then begin AResult := 'DATE_FORMAT(CURTIME(), ''%H:%i:%s'')'; Exit; end;
    Result := False;
    Exit;
  end;
  if Fn = 'len' then begin Need(1); AResult := 'char_length(' + A[0].Sql + ')'; Exit; end;
  if Fn = 'space' then begin Need(1); AResult := 'REPEAT('' '', ' + A[0].Sql + ')'; Exit; end;
  if Fn = 'string' then begin Need(2); AResult := 'REPEAT(substr(' + A[1].Sql + ', 1, 1), ' + A[0].Sql + ')'; Exit; end;
  if (Fn = 'cstr') or (Fn = 'str') then begin Need(1); AResult := 'CAST(' + A[0].Sql + ' AS CHAR)'; Exit; end;
  { ---- brojevi ---- }
  if (Fn = 'int') or (Fn = 'floor') then begin Need(1); AResult := 'CAST(FLOOR(' + A[0].Sql + ') AS SIGNED)'; Exit; end;
  if Fn = 'ceil' then begin Need(1); AResult := 'CAST(CEIL(' + A[0].Sql + ') AS SIGNED)'; Exit; end;
  if Fn = 'fix' then begin Need(1); AResult := 'CAST(TRUNCATE(' + A[0].Sql + ', 0) AS SIGNED)'; Exit; end;
  if (Fn = 'val') or (Fn = 'cdbl') then begin Need(1); AResult := 'CAST(' + A[0].Sql + ' AS DOUBLE)'; Exit; end;
  if (Fn = 'cint') or (Fn = 'clng') then begin Need(1); AResult := 'CAST(ROUND(' + A[0].Sql + ') AS SIGNED)'; Exit; end;
  if Fn = 'clamp' then begin Need(3); AResult := 'GREATEST(' + A[1].Sql + ', LEAST(' + A[0].Sql + ', ' + A[2].Sql + '))'; Exit; end;
  if ((Fn = 'max') or (Fn = 'min')) and (N >= 2) and (A[0].Sql <> '*') then
  begin
    if Fn = 'max' then AResult := 'GREATEST(' else AResult := 'LEAST(';
    for I := 0 to N - 1 do
    begin
      if I > 0 then AResult := AResult + ', ';
      AResult := AResult + A[I].Sql;
    end;
    AResult := AResult + ')';
    Exit;
  end;
  { ---- datumi (ISO tekst) ---- }
  if Fn = 'year' then begin Need(1); AResult := 'YEAR(' + A[0].Sql + ')'; Exit; end;
  if Fn = 'month' then begin Need(1); AResult := 'MONTH(' + A[0].Sql + ')'; Exit; end;
  if Fn = 'day' then begin Need(1); AResult := 'DAYOFMONTH(' + A[0].Sql + ')'; Exit; end;
  if Fn = 'hour' then begin Need(1); AResult := 'HOUR(' + A[0].Sql + ')'; Exit; end;
  if Fn = 'minute' then begin Need(1); AResult := 'MINUTE(' + A[0].Sql + ')'; Exit; end;
  if Fn = 'second' then begin Need(1); AResult := 'SECOND(' + A[0].Sql + ')'; Exit; end;
  if Fn = 'weekday' then begin Need(1); AResult := 'DAYOFWEEK(' + A[0].Sql + ')'; Exit; end;
  if Fn = 'quarter' then begin Need(1); AResult := 'QUARTER(' + A[0].Sql + ')'; Exit; end;
  if Fn = 'eomonth' then begin Need(1); AResult := MaDate('LAST_DAY(' + A[0].Sql + ')'); Exit; end;
  if Fn = 'bomonth' then
  begin
    Need(1);
    AResult := MaDate('DATE_SUB(CAST(' + A[0].Sql + ' AS DATE), INTERVAL (DAYOFMONTH(' + A[0].Sql + ') - 1) DAY)');
    Exit;
  end;
  if Fn = 'adddays' then begin Need(2); AResult := MaDate('DATE_ADD(CAST(' + A[0].Sql + ' AS DATE), INTERVAL (' + A[1].Sql + ') DAY)'); Exit; end;
  if Fn = 'addmonths' then begin Need(2); AResult := MaDate('DATE_ADD(CAST(' + A[0].Sql + ' AS DATE), INTERVAL (' + A[1].Sql + ') MONTH)'); Exit; end;
  if Fn = 'daysbetween' then begin Need(2); AResult := 'DATEDIFF(' + A[1].Sql + ', ' + A[0].Sql + ')'; Exit; end;
  if Fn = 'dateserial' then
  begin
    Need(3);
    AResult := MaDate('STR_TO_DATE(CONCAT(' + A[0].Sql + ', ''-'', ' + A[1].Sql + ', ''-'', ' + A[2].Sql + '), ''%Y-%m-%d'')');
    Exit;
  end;
  if (Fn = 'datevalue') or (Fn = 'cdate') then begin Need(1); AResult := MaDate('CAST(' + A[0].Sql + ' AS DATE)'); Exit; end;
  if Fn = 'age' then
  begin
    Need(1);
    if N >= 2 then AResult := 'TIMESTAMPDIFF(YEAR, ' + A[0].Sql + ', ' + A[1].Sql + ')'
    else AResult := 'TIMESTAMPDIFF(YEAR, ' + A[0].Sql + ', CURDATE())';
    Exit;
  end;
  if Fn = 'dateadd' then
  begin
    Need(3);
    if not A[0].IsLit then Fail('DateAdd traži interval kao tekst, npr. "d" ili "m".');
    Un := UpperCase(IntervalUnit(A[0].Lit, IsTime));
    Un := Copy(Un, 1, Length(Un) - 1);   { DAYS -> DAY }
    Iv := LowerCase(A[0].Lit);
    D := '(' + A[1].Sql + ')';
    if Iv = 'q' then D := '(' + A[1].Sql + ' * 3)'
    else if Iv = 'ww' then D := '(' + A[1].Sql + ' * 7)';
    if IsTime then Fmt := '%Y-%m-%d %H:%i:%s' else Fmt := '%Y-%m-%d';
    AResult := 'DATE_FORMAT(DATE_ADD(CAST(' + A[2].Sql + ' AS DATETIME), INTERVAL ' + D + ' ' + Un + '), ' + Q(Fmt) + ')';
    Exit;
  end;
  if Fn = 'datediff' then
  begin
    Need(3);
    if not A[0].IsLit then Fail('DateDiff traži interval kao tekst, npr. "d" ili "m".');
    Iv := LowerCase(A[0].Lit);
    if Iv = 'yyyy' then begin AResult := '(YEAR(' + A[2].Sql + ') - YEAR(' + A[1].Sql + '))'; Exit; end;
    if Iv = 'm' then begin AResult := '(' + MaMonths(A[2].Sql) + ' - ' + MaMonths(A[1].Sql) + ')'; Exit; end;
    if Iv = 'q' then begin AResult := '((' + MaMonths(A[2].Sql) + ' - ' + MaMonths(A[1].Sql) + ') DIV 3)'; Exit; end;
    if (Iv = 'd') or (Iv = 'y') or (Iv = 'w') then begin AResult := 'DATEDIFF(' + A[2].Sql + ', ' + A[1].Sql + ')'; Exit; end;
    if Iv = 'ww' then begin AResult := '(DATEDIFF(' + A[2].Sql + ', ' + A[1].Sql + ') DIV 7)'; Exit; end;
    if Iv = 'h' then begin AResult := 'TIMESTAMPDIFF(HOUR, ' + A[1].Sql + ', ' + A[2].Sql + ')'; Exit; end;
    if Iv = 'n' then begin AResult := 'TIMESTAMPDIFF(MINUTE, ' + A[1].Sql + ', ' + A[2].Sql + ')'; Exit; end;
    if Iv = 's' then begin AResult := 'TIMESTAMPDIFF(SECOND, ' + A[1].Sql + ', ' + A[2].Sql + ')'; Exit; end;
    Fail('Nepoznat interval: ' + A[0].Lit);
  end;
  Result := False;
end;

{ Brojevi u upitu prate zapis aplikacije: s decimalnim zarezom tocka se zamjenjuje zarezom. }
function DecComma(const ASql: string): string;
begin
  if DefaultFormatSettings.DecimalSeparator = ',' then Result := 'replace(' + ASql + ', ''.'', '','')'
  else Result := ASql;
end;

function FormatSql(const AValue, AFmt: string): string;
var
  L: string;
  P, Dec: Integer;
  OnlyNum: Boolean;
  I: Integer;
begin
  L := LowerCase(AFmt);
  if SqlMaria then
  begin
    if L = 'currency' then Exit(DecComma(MaFixed(AValue, 2)) + ' || '' €''');
    if (L = 'fixed') or (L = 'standard') then Exit(DecComma(MaFixed(AValue, 2)));
    if (L = 'short date') or (L = 'long date') then Exit('DATE_FORMAT(CAST(' + AValue + ' AS DATETIME), ''%d.%m.%Y'')');
    if L = 'short time' then Exit('DATE_FORMAT(CAST(' + AValue + ' AS DATETIME), ''%H:%i'')');
    if L = 'general date' then Exit('DATE_FORMAT(CAST(' + AValue + ' AS DATETIME), ''%d.%m.%Y %H:%i'')');
    OnlyNum := AFmt <> '';
    for I := 1 to Length(AFmt) do
      if not (AFmt[I] in ['0', '#', ',', '.']) then OnlyNum := False;
    if OnlyNum then
    begin
      P := Pos('.', AFmt);
      if P = 0 then Dec := 0 else Dec := Length(AFmt) - P;
      Exit(DecComma(MaFixed(AValue, Dec)));
    end;
    if (Pos('yy', L) > 0) or (Pos('dd', L) > 0) or (Pos('hh', L) > 0) or (Pos('nn', L) > 0) or (Pos('mm', L) > 0) then
      Exit('DATE_FORMAT(CAST(' + AValue + ' AS DATETIME), ' + Q(MaDateFormat(AFmt)) + ')');
    Fail('Format "' + AFmt + '" se ne može prevesti u upit (podržani su brojevi s decimalama i datumi).');
  end;
  if SqlPostgres then
  begin
    if L = 'currency' then Exit(DecComma(PgFixed(AValue, 2)) + ' || '' €''');
    if (L = 'fixed') or (L = 'standard') then Exit(DecComma(PgFixed(AValue, 2)));
    if (L = 'short date') or (L = 'long date') then Exit('to_char(' + PgTs(AValue) + ', ''DD.MM.YYYY'')');
    if L = 'short time' then Exit('to_char(' + PgTs(AValue) + ', ''HH24:MI'')');
    if L = 'general date' then Exit('to_char(' + PgTs(AValue) + ', ''DD.MM.YYYY HH24:MI'')');
    OnlyNum := AFmt <> '';
    for I := 1 to Length(AFmt) do
      if not (AFmt[I] in ['0', '#', ',', '.']) then OnlyNum := False;
    if OnlyNum then
    begin
      P := Pos('.', AFmt);
      if P = 0 then Dec := 0 else Dec := Length(AFmt) - P;
      Exit(DecComma(PgFixed(AValue, Dec)));
    end;
    if (Pos('yy', L) > 0) or (Pos('dd', L) > 0) or (Pos('hh', L) > 0) or (Pos('nn', L) > 0) or (Pos('mm', L) > 0) then
      Exit('to_char(' + PgTs(AValue) + ', ' + Q(PgDateFormat(AFmt)) + ')');
    Fail('Format "' + AFmt + '" se ne može prevesti u upit (podržani su brojevi s decimalama i datumi).');
  end;
  if L = 'currency' then Exit(DecComma('printf(''%.2f'', ' + AValue + ')') + ' || '' €''');
  if L = 'fixed' then Exit(DecComma('printf(''%.2f'', ' + AValue + ')'));
  if L = 'standard' then Exit(DecComma('printf(''%.2f'', ' + AValue + ')'));
  if L = 'short date' then Exit('strftime(''%d.%m.%Y'', ' + AValue + ')');
  if L = 'long date' then Exit('strftime(''%d.%m.%Y'', ' + AValue + ')');
  if L = 'short time' then Exit('strftime(''%H:%M'', ' + AValue + ')');
  if L = 'general date' then Exit('strftime(''%d.%m.%Y %H:%M'', ' + AValue + ')');
  { numbers: only the number of decimals survives (0, 0.0, 0.00, #,##0.00) }
  OnlyNum := AFmt <> '';
  for I := 1 to Length(AFmt) do
    if not (AFmt[I] in ['0', '#', ',', '.']) then OnlyNum := False;
  if OnlyNum then
  begin
    P := Pos('.', AFmt);
    if P = 0 then Dec := 0 else Dec := Length(AFmt) - P;
    Exit(DecComma('printf(''%.' + IntToStr(Dec) + 'f'', ' + AValue + ')'));
  end;
  if (Pos('yy', L) > 0) or (Pos('dd', L) > 0) or (Pos('hh', L) > 0) or (Pos('nn', L) > 0) or (Pos('mm', L) > 0) then
    Exit('strftime(' + Q(StrftimeFormat(AFmt)) + ', ' + AValue + ')');
  Fail('Format "' + AFmt + '" se ne može prevesti u upit (podržani su brojevi s decimalama i datumi).');
  Result := '';
end;

function Join(const A: TArgs; AFrom: Integer; const ASep: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := AFrom to High(A) do
  begin
    if Result <> '' then Result := Result + ASep;
    Result := Result + A[I].Sql;
  end;
end;

function DomainSql(const AFn: string; const A: TArgs): string;
var
  Expr, Crit, Dom: string;
  I: Integer;
  Plain: Boolean;
begin
  if (Length(A) < 2) or not A[0].IsLit or not A[1].IsLit or ((Length(A) >= 3) and not A[2].IsLit) then
    Fail(AFn + ' u upitu traži tekstualne argumente bez izraza (npr. DSum("iznos", "racun", "kupac_id = 1")).');
  Expr := A[0].Lit;
  Dom := A[1].Lit;
  if Length(A) >= 3 then Crit := A[2].Lit else Crit := '';
  Plain := Expr <> '';
  for I := 1 to Length(Expr) do
    if not (Expr[I] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) then Plain := False;
  if Plain then Expr := QId(Expr);
  if Expr = '' then Expr := '*';
  if AFn = 'dlookup' then Result := '(SELECT ' + Expr + ' FROM ' + QId(Dom)
  else if AFn = 'dcount' then Result := '(SELECT COUNT(' + Expr + ') FROM ' + QId(Dom)
  else if AFn = 'dsum' then Result := '(SELECT SUM(' + Expr + ') FROM ' + QId(Dom)
  else if AFn = 'davg' then Result := '(SELECT AVG(' + Expr + ') FROM ' + QId(Dom)
  else if AFn = 'dmin' then Result := '(SELECT MIN(' + Expr + ') FROM ' + QId(Dom)
  else Result := '(SELECT MAX(' + Expr + ') FROM ' + QId(Dom);
  if Crit <> '' then Result := Result + ' WHERE ' + Crit;
  if AFn = 'dlookup' then Result := Result + ' LIMIT 1';
  Result := Result + ')';
end;

function TTr.Call(const AName: string; const A: TArgs): string;
var
  N, I: Integer;
  Iv, Un, Fn: string;
  IsTime: Boolean;
  D: string;

  procedure Need(Cnt: Integer);
  begin
    if N < Cnt then Fail('Funkciji ' + AName + ' nedostaju argumenti');
  end;

  function YearsExpr(const AExpr: string): string;
  begin
    Result := 'CAST(strftime(''%Y'', ' + AExpr + ') AS INTEGER)';
  end;

  function MonthsExpr(const AExpr: string): string;
  begin
    Result := '(CAST(strftime(''%Y'', ' + AExpr + ') AS INTEGER) * 12 + CAST(strftime(''%m'', ' + AExpr + ') AS INTEGER))';
  end;

begin
  N := Length(A);
  Fn := AName;
  if SqlPostgres and PgCall(Fn, A, Result) then Exit;
  if SqlMaria and MariaCall(Fn, A, Result) then Exit;
  { ---- variables without parentheses ---- }
  if N = 0 then
  begin
    if (Fn = 'date') or (Fn = 'today') then Exit('date(''now'', ''localtime'')');
    if Fn = 'now' then Exit('datetime(''now'', ''localtime'')');
    if Fn = 'time' then Exit('time(''now'', ''localtime'')');
    if Fn = 'currentuser' then Exit(Q(CurrentUserName));
    if Fn = 'currentrole' then Exit(Q(CurrentUserRole));
    if (Fn = 'page') or (Fn = 'pages') or (Fn = 'rownum') then
      Fail(CurName + ' postoji samo u izvješćima, ne u upitima.');
  end;
  { ---- logic ---- }
  if Fn = 'iif' then begin Need(3); Exit('(CASE WHEN ' + A[0].Sql + ' THEN ' + A[1].Sql + ' ELSE ' + A[2].Sql + ' END)'); end;
  if Fn = 'switch' then
  begin
    Result := '(CASE';
    I := 0;
    while I + 1 < N do
    begin
      Result := Result + ' WHEN ' + A[I].Sql + ' THEN ' + A[I + 1].Sql;
      Inc(I, 2);
    end;
    Exit(Result + ' END)');
  end;
  if Fn = 'choose' then
  begin
    Need(2);
    Result := '(CASE ' + A[0].Sql;
    for I := 1 to N - 1 do Result := Result + ' WHEN ' + IntToStr(I) + ' THEN ' + A[I].Sql;
    Exit(Result + ' END)');
  end;
  if Fn = 'nz' then begin Need(1); if N >= 2 then Exit('COALESCE(' + A[0].Sql + ', ' + A[1].Sql + ')'); Exit('COALESCE(' + A[0].Sql + ', 0)'); end;
  if Fn = 'coalesce' then begin Need(1); Exit('COALESCE(' + Join(A, 0, ', ') + ')'); end;
  if Fn = 'nullif' then begin Need(2); Exit('NULLIF(' + A[0].Sql + ', ' + A[1].Sql + ')'); end;
  if Fn = 'isnull' then begin Need(1); Exit('(' + A[0].Sql + ' IS NULL)'); end;
  if Fn = 'isempty' then begin Need(1); Exit('(' + A[0].Sql + ' IS NULL OR trim(' + A[0].Sql + ') = '''')'); end;
  { ---- text ---- }
  if Fn = 'len' then begin Need(1); Exit('length(' + A[0].Sql + ')'); end;
  if Fn = 'left' then begin Need(2); Exit('substr(' + A[0].Sql + ', 1, ' + A[1].Sql + ')'); end;
  if Fn = 'right' then begin Need(2); Exit('substr(' + A[0].Sql + ', -(' + A[1].Sql + '))'); end;
  if Fn = 'mid' then
  begin
    Need(2);
    if N >= 3 then Exit('substr(' + A[0].Sql + ', ' + A[1].Sql + ', ' + A[2].Sql + ')');
    Exit('substr(' + A[0].Sql + ', ' + A[1].Sql + ')');
  end;
  if Fn = 'ucase' then begin Need(1); Exit('upper(' + A[0].Sql + ')'); end;
  if Fn = 'lcase' then begin Need(1); Exit('lower(' + A[0].Sql + ')'); end;
  if Fn = 'trim' then begin Need(1); Exit('trim(' + A[0].Sql + ')'); end;
  if Fn = 'ltrim' then begin Need(1); Exit('ltrim(' + A[0].Sql + ')'); end;
  if Fn = 'rtrim' then begin Need(1); Exit('rtrim(' + A[0].Sql + ')'); end;
  if Fn = 'replace' then begin Need(3); Exit('replace(' + A[0].Sql + ', ' + A[1].Sql + ', ' + A[2].Sql + ')'); end;
  if Fn = 'instr' then begin Need(2); Exit('instr(lower(' + A[0].Sql + '), lower(' + A[1].Sql + '))'); end;
  if Fn = 'concat' then
  begin
    Need(1);
    Result := '(';
    for I := 0 to N - 1 do
    begin
      if I > 0 then Result := Result + ' || ';
      Result := Result + 'COALESCE(' + A[I].Sql + ', '''')';
    end;
    Exit(Result + ')');
  end;
  if Fn = 'startswith' then begin Need(2); Exit('(' + A[0].Sql + ' LIKE (' + A[1].Sql + ' || ''%''))'); end;
  if Fn = 'endswith' then begin Need(2); Exit('(' + A[0].Sql + ' LIKE (''%'' || ' + A[1].Sql + '))'); end;
  if Fn = 'contains' then begin Need(2); Exit('(instr(lower(' + A[0].Sql + '), lower(' + A[1].Sql + ')) > 0)'); end;
  if Fn = 'space' then begin Need(1); Exit('replace(hex(zeroblob(' + A[0].Sql + ')), ''00'', '' '')'); end;
  if Fn = 'string' then begin Need(2); Exit('replace(hex(zeroblob(' + A[0].Sql + ')), ''00'', substr(' + A[1].Sql + ', 1, 1))'); end;
  if (Fn = 'cstr') or (Fn = 'str') then begin Need(1); Exit('CAST(' + A[0].Sql + ' AS TEXT)'); end;
  { ---- numbers ---- }
  if Fn = 'abs' then begin Need(1); Exit('abs(' + A[0].Sql + ')'); end;
  if (Fn = 'round') or (Fn = 'zaokruzi') then
  begin
    Need(1);
    if N >= 2 then Exit('round(' + A[0].Sql + ', ' + A[1].Sql + ')');
    Exit('round(' + A[0].Sql + ')');
  end;
  if (Fn = 'int') or (Fn = 'floor') then
  begin
    Need(1);
    Exit('(CAST(' + A[0].Sql + ' AS INTEGER) - (' + A[0].Sql + ' < CAST(' + A[0].Sql + ' AS INTEGER)))');
  end;
  if Fn = 'ceil' then
  begin
    Need(1);
    Exit('(CAST(' + A[0].Sql + ' AS INTEGER) + (' + A[0].Sql + ' > CAST(' + A[0].Sql + ' AS INTEGER)))');
  end;
  if Fn = 'fix' then begin Need(1); Exit('CAST(' + A[0].Sql + ' AS INTEGER)'); end;
  if Fn = 'sgn' then begin Need(1); Exit('(CASE WHEN ' + A[0].Sql + ' > 0 THEN 1 WHEN ' + A[0].Sql + ' < 0 THEN -1 ELSE 0 END)'); end;
  if Fn = 'sqr' then begin Need(1); Exit('sqrt(' + A[0].Sql + ')'); end;
  if Fn = 'exp' then begin Need(1); Exit('exp(' + A[0].Sql + ')'); end;
  if Fn = 'log' then begin Need(1); Exit('ln(' + A[0].Sql + ')'); end;
  if Fn = 'percent' then begin Need(2); Exit('(' + A[0].Sql + ' * 100.0 / NULLIF(' + A[1].Sql + ', 0))'); end;
  if Fn = 'clamp' then begin Need(3); Exit('max(' + A[1].Sql + ', min(' + A[0].Sql + ', ' + A[2].Sql + '))'); end;
  if (Fn = 'val') or (Fn = 'cdbl') then begin Need(1); Exit('CAST(' + A[0].Sql + ' AS REAL)'); end;
  if (Fn = 'cint') or (Fn = 'clng') then begin Need(1); Exit('CAST(round(' + A[0].Sql + ') AS INTEGER)'); end;
  if ((Fn = 'max') or (Fn = 'min')) and (N >= 2) and (A[0].Sql <> '*') then
    Exit(Fn + '(' + Join(A, 0, ', ') + ')');
  { ---- aggregates ---- }
  if (Fn = 'sum') or (Fn = 'count') or (Fn = 'avg') or (Fn = 'min') or (Fn = 'max') then
  begin
    Need(1);
    Exit(UpperCase(Fn) + '(' + A[0].Sql + ')');
  end;
  { ---- dates (stored as ISO text) ---- }
  if Fn = 'year' then begin Need(1); Exit(YearsExpr(A[0].Sql)); end;
  if Fn = 'month' then begin Need(1); Exit('CAST(strftime(''%m'', ' + A[0].Sql + ') AS INTEGER)'); end;
  if Fn = 'day' then begin Need(1); Exit('CAST(strftime(''%d'', ' + A[0].Sql + ') AS INTEGER)'); end;
  if Fn = 'hour' then begin Need(1); Exit('CAST(strftime(''%H'', ' + A[0].Sql + ') AS INTEGER)'); end;
  if Fn = 'minute' then begin Need(1); Exit('CAST(strftime(''%M'', ' + A[0].Sql + ') AS INTEGER)'); end;
  if Fn = 'second' then begin Need(1); Exit('CAST(strftime(''%S'', ' + A[0].Sql + ') AS INTEGER)'); end;
  if Fn = 'weekday' then begin Need(1); Exit('(CAST(strftime(''%w'', ' + A[0].Sql + ') AS INTEGER) + 1)'); end;
  if Fn = 'quarter' then begin Need(1); Exit('((CAST(strftime(''%m'', ' + A[0].Sql + ') AS INTEGER) + 2) / 3)'); end;
  if Fn = 'eomonth' then begin Need(1); Exit('date(' + A[0].Sql + ', ''start of month'', ''+1 month'', ''-1 day'')'); end;
  if Fn = 'bomonth' then begin Need(1); Exit('date(' + A[0].Sql + ', ''start of month'')'); end;
  if Fn = 'adddays' then begin Need(2); Exit('date(' + A[0].Sql + ', (' + A[1].Sql + ') || '' days'')'); end;
  if Fn = 'addmonths' then begin Need(2); Exit('date(' + A[0].Sql + ', (' + A[1].Sql + ') || '' months'')'); end;
  if Fn = 'daysbetween' then begin Need(2); Exit('CAST(julianday(date(' + A[1].Sql + ')) - julianday(date(' + A[0].Sql + ')) AS INTEGER)'); end;
  if Fn = 'dateserial' then begin Need(3); Exit('printf(''%04d-%02d-%02d'', ' + A[0].Sql + ', ' + A[1].Sql + ', ' + A[2].Sql + ')'); end;
  if (Fn = 'datevalue') or (Fn = 'cdate') then begin Need(1); Exit('date(' + A[0].Sql + ')'); end;
  if Fn = 'age' then
  begin
    Need(1);
    D := A[0].Sql;
    if N >= 2 then Exit('(' + YearsExpr(A[1].Sql) + ' - ' + YearsExpr(D) + ' - (strftime(''%m-%d'', ' + A[1].Sql + ') < strftime(''%m-%d'', ' + D + ')))');
    Exit('(CAST(strftime(''%Y'', ''now'') AS INTEGER) - ' + YearsExpr(D) + ' - (strftime(''%m-%d'', ''now'') < strftime(''%m-%d'', ' + D + ')))');
  end;
  if Fn = 'dateadd' then
  begin
    Need(3);
    if not A[0].IsLit then Fail('DateAdd traži interval kao tekst, npr. "d" ili "m".');
    Un := IntervalUnit(A[0].Lit, IsTime);
    Iv := LowerCase(A[0].Lit);
    D := '(' + A[1].Sql + ')';
    if Iv = 'q' then D := '(' + A[1].Sql + ' * 3)'
    else if Iv = 'ww' then D := '(' + A[1].Sql + ' * 7)';
    if IsTime then Exit('datetime(' + A[2].Sql + ', ' + D + ' || '' ' + Un + ''')');
    Exit('date(' + A[2].Sql + ', ' + D + ' || '' ' + Un + ''')');
  end;
  if Fn = 'datediff' then
  begin
    Need(3);
    if not A[0].IsLit then Fail('DateDiff traži interval kao tekst, npr. "d" ili "m".');
    Iv := LowerCase(A[0].Lit);
    if Iv = 'yyyy' then Exit('(' + YearsExpr(A[2].Sql) + ' - ' + YearsExpr(A[1].Sql) + ')');
    if Iv = 'm' then Exit('(' + MonthsExpr(A[2].Sql) + ' - ' + MonthsExpr(A[1].Sql) + ')');
    if Iv = 'q' then Exit('((' + MonthsExpr(A[2].Sql) + ' - ' + MonthsExpr(A[1].Sql) + ') / 3)');
    if (Iv = 'd') or (Iv = 'y') or (Iv = 'w') then
      Exit('CAST(julianday(date(' + A[2].Sql + ')) - julianday(date(' + A[1].Sql + ')) AS INTEGER)');
    if Iv = 'ww' then Exit('(CAST(julianday(date(' + A[2].Sql + ')) - julianday(date(' + A[1].Sql + ')) AS INTEGER) / 7)');
    if Iv = 'h' then Exit('CAST((julianday(' + A[2].Sql + ') - julianday(' + A[1].Sql + ')) * 24 AS INTEGER)');
    if Iv = 'n' then Exit('CAST((julianday(' + A[2].Sql + ') - julianday(' + A[1].Sql + ')) * 1440 AS INTEGER)');
    if Iv = 's' then Exit('CAST((julianday(' + A[2].Sql + ') - julianday(' + A[1].Sql + ')) * 86400 AS INTEGER)');
    Fail('Nepoznat interval: ' + A[0].Lit);
  end;
  if Fn = 'format' then
  begin
    Need(2);
    if not A[1].IsLit then Fail('Format u upitu traži oblik kao tekst, npr. "0.00" ili "dd.mm.yyyy".');
    Exit(FormatSql(A[0].Sql, A[1].Lit));
  end;
  { ---- domain functions ---- }
  if (Fn = 'dlookup') or (Fn = 'dcount') or (Fn = 'dsum') or (Fn = 'davg') or (Fn = 'dmin') or (Fn = 'dmax') then
    Exit(DomainSql(Fn, A));
  { ---- known but not expressible ---- }
  Fail('Funkcija ' + CurName + ' se ne može koristiti u upitu (nema SQL ekvivalenta). ' +
    'Koristi je u formi ili izvješću.');
  Result := '';
end;

function ExprToSql(const AExpr: string; AResolver: TSqlFieldResolver; out ASql, AError: string): Boolean;
var
  T: TTr;
  Body: string;
begin
  ASql := '';
  AError := '';
  Body := Trim(AExpr);
  if (Body <> '') and (Body[1] = '=') then Body := Trim(Copy(Body, 2, MaxInt));
  if Body = '' then begin AError := 'Prazan izraz'; Exit(False); end;
  T := TTr.Create;
  try
    T.S := Body;
    T.P := 1;
    T.Resolver := AResolver;
    try
      ASql := T.ParseOr;
      if T.Peek <> #0 then Fail('Neočekivani znak "' + T.S[T.P] + '"');
      Result := True;
    except
      on E: Exception do
      begin
        AError := E.Message;
        ASql := '';
        Result := False;
      end;
    end;
  finally
    T.Free;
  end;
end;

function ExprFieldNames(const AExpr: string): TStringList;
var
  I, J: Integer;
  InStr: Char;
begin
  Result := TStringList.Create;
  Result.Sorted := True;
  Result.Duplicates := dupIgnore;
  I := 1;
  InStr := #0;
  while I <= Length(AExpr) do
  begin
    if InStr <> #0 then
    begin
      if AExpr[I] = InStr then InStr := #0;
    end
    else if AExpr[I] in ['"', ''''] then InStr := AExpr[I]
    else if AExpr[I] = '[' then
    begin
      J := I + 1;
      while (J <= Length(AExpr)) and (AExpr[J] <> ']') do Inc(J);
      Result.Add(Copy(AExpr, I + 1, J - I - 1));
      I := J;
    end;
    Inc(I);
  end;
end;

end.
