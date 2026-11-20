unit ta_exprdb;
{ Database-backed pieces of the expression language: the domain functions
  DLookup, DCount, DSum, DAvg, DMin and DMax. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Variants, DB, ZDataset, ta_meta, ta_expr, ta_parse;

var
  { the database domain functions in field defaults run against }
  ActiveDb: TAppDb = nil;

function ActiveDomain(const AFunc, AExpr, ADomain, ACriteria: string): Variant;

{ AExpr and ACriteria are SQL text; ADomain is a table or saved query name. }
function DbDomain(ADb: TAppDb; const AFunc, AExpr, ADomain, ACriteria: string): Variant;

{ Replaces [name] in a SQL text with the value from AHost as a SQL literal. }
function ExpandPlaceholders(AHost: TaExprHost; const ASql: string): string;

implementation

function SettingOfActiveDb(const AKey: string): string;
begin
  if (ActiveDb <> nil) and ActiveDb.Connected then Result := ActiveDb.LoadSetting(AKey) else Result := '';
end;

function ActiveDomain(const AFunc, AExpr, ADomain, ACriteria: string): Variant;
begin
  Result := DbDomain(ActiveDb, AFunc, AExpr, ADomain, ACriteria);
end;

function ExpandPlaceholders(AHost: TaExprHost; const ASql: string): string;
var
  I, J: Integer;
  V: Variant;
  Lit: string;
begin
  Result := '';
  I := 1;
  while I <= Length(ASql) do
  begin
    if ASql[I] = '[' then
    begin
      J := I + 1;
      while (J <= Length(ASql)) and (ASql[J] <> ']') do Inc(J);
      V := AHost.FieldValue(Copy(ASql, I + 1, J - I - 1));
      if VarIsNull(V) or VarIsEmpty(V) then Lit := 'NULL'
      else if VarType(V) = varBoolean then
      begin
        if Boolean(V) then Lit := '1' else Lit := '0';
      end
      else if VarIsNumeric(V) then Lit := FloatToStr(Double(V), ParseFS)
      else Lit := '''' + StringReplace(VarToStr(V), '''', '''''', [rfReplaceAll]) + '''';
      Result := Result + Lit;
      I := J + 1;
    end
    else
    begin
      Result := Result + ASql[I];
      Inc(I);
    end;
  end;
end;

function IsPlainNumber(const S: string): Boolean;
var
  I: Integer;
begin
  Result := S <> '';
  for I := 1 to Length(S) do
    if not (S[I] in ['0'..'9', '.', '-']) then Result := False;
end;

function DbDomain(ADb: TAppDb; const AFunc, AExpr, ADomain, ACriteria: string): Variant;
var
  Q: TZQuery;
  Sql, Agg, E: string;
  F: TField;
  P: Integer;
  Tot: Double;
begin
  Result := Null;
  if ADb = nil then Exit;
  E := Trim(AExpr);
  if E = '' then E := '*';
  if SameText(AFunc, 'preuzmi') then
  begin
    { kljuc je primarni kljuc tablice; broj ide bez navodnika, tekst u navodnicima }
    Sql := ADb.PrimaryKeyOf(ADomain);
    if Sql = '' then Exit(Null);
    if IsPlainNumber(Trim(ACriteria)) then Agg := Trim(ACriteria)
    else Agg := '''' + StringReplace(ACriteria, '''', '''''', [rfReplaceAll]) + '''';
    Exit(DbDomain(ADb, 'dlookup', E, ADomain, ADb.QuoteId(Sql) + ' = ' + Agg));
  end;
  if SameText(AFunc, 'pdvpostopama') then
  begin
    { AExpr = 'iznos_polje,stopa_polje': zbroj osnovica po stopi, PDV zaokruzen po stopi }
    P := Pos(',', E);
    if P < 2 then Exit(Null);
    Sql := 'SELECT ' + ADb.QuoteId(Trim(Copy(E, P + 1, MaxInt))) + ', SUM(' + ADb.QuoteId(Trim(Copy(E, 1, P - 1))) +
      ') FROM ' + ADb.SourceFrom(ADomain);
    if Trim(ACriteria) <> '' then Sql := Sql + ' WHERE ' + ACriteria;
    Sql := Sql + ' GROUP BY ' + ADb.QuoteId(Trim(Copy(E, P + 1, MaxInt)));
    Q := ADb.NewQuery(Sql);
    try
      try
        Q.Open;
        Tot := 0;
        while not Q.EOF do
        begin
          if not Q.Fields[1].IsNull then Tot := Tot + RoundHalfUp(Q.Fields[1].AsFloat * Q.Fields[0].AsFloat / 100, 2);
          Q.Next;
        end;
        Exit(Tot);
      except
        Exit(Null);
      end;
    finally
      Q.Free;
    end;
  end;
  if SameText(AFunc, 'dlookup') then
    Sql := 'SELECT ' + E + ' FROM ' + ADb.SourceFrom(ADomain)
  else
  begin
    if SameText(AFunc, 'dcount') then Agg := 'COUNT'
    else if SameText(AFunc, 'dsum') then Agg := 'SUM'
    else if SameText(AFunc, 'davg') then Agg := 'AVG'
    else if SameText(AFunc, 'dmin') then Agg := 'MIN'
    else Agg := 'MAX';
    Sql := 'SELECT ' + Agg + '(' + E + ') FROM ' + ADb.SourceFrom(ADomain);
  end;
  if Trim(ACriteria) <> '' then Sql := Sql + ' WHERE ' + ACriteria;
  if SameText(AFunc, 'dlookup') then Sql := Sql + ' LIMIT 1';
  Q := ADb.NewQuery(Sql);
  try
    try
      Q.Open;
    except
      Exit(Null);
    end;
    if Q.EOF then Exit(Null);
    F := Q.Fields[0];
    if F.IsNull then Exit(Null);
    if F.DataType in [ftSmallint, ftInteger, ftLargeint, ftWord, ftAutoInc] then Result := F.AsLargeInt
    else if F.DataType in [ftFloat, ftCurrency, ftBCD, ftFMTBcd, ftSingle] then Result := F.AsFloat
    else Result := F.AsString;
  finally
    Q.Free;
  end;
end;

initialization
  SettingHook := @SettingOfActiveDb;

end.
