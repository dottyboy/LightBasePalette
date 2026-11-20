unit ta_qbe;
{ Query-by-example model: tables, then one row per output column (field or
  calculated expression, name, show, total, sort, criteria, "or" criteria).
  BuildQbeSql turns it into SQLite SQL; calculated expressions and criteria use
  the same language as forms and reports (ta_exprsql translates them).

  The design is kept inside the saved query as a trailing /*QBE{json}*/ comment,
  so a query reopens as a grid, and still runs as plain SQL everywhere else. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, jsonparser, ZDataset, ta_meta, ta_params, ta_types, ta_exprsql, ta_wizardgen;

type
  TaQbeColumn = record
    Expr: string;       { table.field, field, or an expression like [a] * 2 }
    Alias: string;
    Show: Boolean;
    Total: string;      { '' | group | sum | avg | count | min | max | expr | where }
    Sort: string;       { '' | asc | desc }
    Crit, OrCrit: string;
  end;

  TaQbeDesign = class
  public
    Tables: TStringList;
    JoinType: string;   { inner | left }
    Distinct: Boolean;
    Top: Integer;       { 0 = all rows }
    Cols: array of TaQbeColumn;
    constructor Create;
    destructor Destroy; override;
    procedure AddColumn(const AExpr, AAlias: string; AShow: Boolean = True;
      const ATotal: string = ''; const ASort: string = '');
    function ToJson: string;
    procedure FromJson(const S: string);
  end;

function BuildQbeSql(ADb: TAppDb; D: TaQbeDesign; out ASql, AError: string): Boolean;
{ "table.field" for everything the selected tables offer (queries too) }
function QbeFieldChoices(ADb: TAppDb; ATables: TStrings): TStringList;
{ Calculated columns for a datasheet: "Alias=expression ;; Alias2=expression2".
  CalcFieldsSql gives ', (sql) AS "Alias", ...' to put after SELECT *. }
function CalcFieldsSql(ADb: TAppDb; const ACalc: string; out ACols, AError: string): Boolean;
function CalcFieldNames(const ACalc: string): TStringList;

{ the SQL with the design appended as a comment, and the way back }
function QbeSqlWithDesign(const ASql: string; D: TaQbeDesign): string;
function QbeDesignFromSql(const ASql: string): TaQbeDesign;   { nil when none }

implementation

uses
  ta_i18n;


constructor TaQbeDesign.Create;
begin
  Tables := TStringList.Create;
  JoinType := 'inner';
end;

destructor TaQbeDesign.Destroy;
begin
  Tables.Free;
  inherited Destroy;
end;

procedure TaQbeDesign.AddColumn(const AExpr, AAlias: string; AShow: Boolean; const ATotal, ASort: string);
var
  N: Integer;
begin
  N := Length(Cols);
  SetLength(Cols, N + 1);
  Cols[N].Expr := AExpr;
  Cols[N].Alias := AAlias;
  Cols[N].Show := AShow;
  Cols[N].Total := ATotal;
  Cols[N].Sort := ASort;
  Cols[N].Crit := '';
  Cols[N].OrCrit := '';
end;

function TaQbeDesign.ToJson: string;
var
  O, C: TJSONObject;
  A, T: TJSONArray;
  I: Integer;
begin
  O := TJSONObject.Create;
  try
    T := TJSONArray.Create;
    for I := 0 to Tables.Count - 1 do T.Add(Tables[I]);
    O.Add('tables', T);
    O.Add('join', JoinType);
    O.Add('distinct', Distinct);
    O.Add('top', Top);
    A := TJSONArray.Create;
    for I := 0 to High(Cols) do
    begin
      C := TJSONObject.Create;
      C.Add('expr', Cols[I].Expr);
      C.Add('alias', Cols[I].Alias);
      C.Add('show', Cols[I].Show);
      C.Add('total', Cols[I].Total);
      C.Add('sort', Cols[I].Sort);
      C.Add('crit', Cols[I].Crit);
      C.Add('or', Cols[I].OrCrit);
      A.Add(C);
    end;
    O.Add('cols', A);
    Result := O.AsJSON;
  finally
    O.Free;
  end;
end;

procedure TaQbeDesign.FromJson(const S: string);
var
  J: TJSONData;
  O: TJSONObject;
  A: TJSONData;
  I: Integer;
  C: TJSONObject;
begin
  Tables.Clear;
  SetLength(Cols, 0);
  J := GetJSON(S);
  try
    O := J as TJSONObject;
    A := O.Find('tables');
    if A is TJSONArray then
      for I := 0 to TJSONArray(A).Count - 1 do Tables.Add(TJSONArray(A).Strings[I]);
    JoinType := O.Get('join', 'inner');
    Distinct := O.Get('distinct', False);
    Top := O.Get('top', 0);
    A := O.Find('cols');
    if A is TJSONArray then
      for I := 0 to TJSONArray(A).Count - 1 do
      begin
        C := TJSONArray(A).Objects[I];
        AddColumn(C.Get('expr', ''), C.Get('alias', ''), C.Get('show', True), C.Get('total', ''), C.Get('sort', ''));
        Cols[High(Cols)].Crit := C.Get('crit', '');
        Cols[High(Cols)].OrCrit := C.Get('or', '');
      end;
  finally
    J.Free;
  end;
end;

{ ---------------- field resolution ---------------- }

type
  TQbeBuilder = class
  public
    Db: TAppDb;
    D: TaQbeDesign;
    Fields: TStringList;       { Objects[i] = TStringList of field names, Strings = source names }
    ColBase: string;           { value of [__col__] while a criterion is translated }
    AllowParams: Boolean;      { nepoznato [ime] u kriteriju je parametar upita }
    function Resolve(const AName: string): string;
    function TableOf(const AName: string): Integer;
    destructor Destroy; override;
  end;

destructor TQbeBuilder.Destroy;
var
  I: Integer;
begin
  for I := 0 to Fields.Count - 1 do Fields.Objects[I].Free;
  Fields.Free;
  inherited Destroy;
end;

function TQbeBuilder.TableOf(const AName: string): Integer;
var
  I: Integer;
begin
  for I := 0 to Fields.Count - 1 do
    if SameText(Fields[I], AName) then Exit(I);
  Result := -1;
end;

function TQbeBuilder.Resolve(const AName: string): string;
var
  P, I, Hits, Where: Integer;
  T, F: string;
  L: TStringList;
begin
  if AName = '__col__' then Exit(ColBase);
  P := Pos('.', AName);
  if P > 0 then
  begin
    T := Copy(AName, 1, P - 1);
    F := Copy(AName, P + 1, MaxInt);
    I := TableOf(T);
    if I < 0 then raise Exception.Create(Tr('Table "') + T + Tr('" is not in the query.'));
    L := TStringList(Fields.Objects[I]);
    if L.IndexOf(LowerCase(F)) < 0 then raise Exception.Create(Tr('Field "') + F + Tr('" does not exist in ') + T + '.');
    Exit(Db.QuoteId(Fields[I]) + '.' + Db.QuoteId(F));
  end;
  Hits := 0;
  Where := -1;
  for I := 0 to Fields.Count - 1 do
    if TStringList(Fields.Objects[I]).IndexOf(LowerCase(AName)) >= 0 then
    begin
      Inc(Hits);
      Where := I;
    end;
  if (Hits = 0) and AllowParams then Exit(ParamMarker(AName));
  if Hits = 0 then raise Exception.Create(Tr('Unknown field [') + AName + '].');
  if Hits > 1 then raise Exception.Create(Tr('Field [') + AName + Tr('] exists in several tables; write [table.') + AName + '].');
  Result := Db.QuoteId(Fields[Where]) + '.' + Db.QuoteId(AName);
end;

function QbeFieldChoices(ADb: TAppDb; ATables: TStrings): TStringList;
var
  I, J: Integer;
  L: TaSourceFields;
begin
  Result := TStringList.Create;
  for I := 0 to ATables.Count - 1 do
  begin
    try
      L := SourceFieldList(ADb, ATables[I]);
    except
      Continue;
    end;
    for J := 0 to High(L) do Result.Add(ATables[I] + '.' + L[J].Name);
  end;
end;

function IsPlainField(const S: string): Boolean;
var
  I, Dots: Integer;
begin
  Result := S <> '';
  if S = '*' then Exit(True);
  Dots := 0;
  for I := 1 to Length(S) do
    if S[I] = '.' then Inc(Dots)
    else if (S[I] = '*') and (I = Length(S)) and (I > 1) and (S[I - 1] = '.') then { table.* }
    else if not (S[I] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) then Exit(False);
  Result := Result and (Dots <= 1) and (S[1] <> '.') and ((S[Length(S)] <> '.'));
end;

function HasAggregate(const AExpr: string): Boolean;
var
  L: string;
  I: Integer;
const
  Names: array[0..4] of string = ('sum(', 'count(', 'avg(', 'min(', 'max(');
begin
  L := StringReplace(LowerCase(AExpr), ' ', '', [rfReplaceAll]);
  for I := 0 to High(Names) do
    if Pos(Names[I], L) > 0 then Exit(True);
  Result := False;
end;

{ A bare word in a criterion is text: Ana  ->  "Ana" (numbers, dates, [refs] and calls are left alone). }
function QuoteBareValue(const AValue: string): string;
var
  V, L: string;
  I: Integer;
  Bare: Boolean;
begin
  V := Trim(AValue);
  Result := V;
  if V = '' then Exit;
  L := LowerCase(V);
  if (V[1] in ['"', '''', '#', '[', '(', '-', '+', '0'..'9']) then Exit;
  if (L = 'true') or (L = 'false') or (L = 'null') then Exit;
  Bare := True;
  for I := 1 to Length(V) do
    if V[I] in ['(', ')', '[', ']', '"', '''', '&', '*', '/', '<', '>', '=', ','] then Bare := False;
  if Bare then Result := '"' + V + '"';
end;

{ Access criteria are written without the field: >100, "Ana", Like "A*",
  Between 1 And 5, Is Null. Put the field in front. }
function NormalizeCrit(const ACrit: string): string;
var
  C, L: string;
  I: Integer;
begin
  C := Trim(ACrit);
  L := LowerCase(C);
  if L = 'null' then Exit('Is Null');
  if L = 'not null' then Exit('Is Not Null');
  if (C <> '') and (C[1] in ['=', '<', '>']) then
  begin
    I := 1;
    while (I <= Length(C)) and (C[I] in ['=', '<', '>']) do Inc(I);
    Exit(Copy(C, 1, I - 1) + ' ' + QuoteBareValue(Copy(C, I, MaxInt)));
  end;
  if (Copy(L, 1, 5) = 'like ') or (Copy(L, 1, 8) = 'between ') or (Copy(L, 1, 3) = 'in ') or
     (Copy(L, 1, 3) = 'in(') or (Copy(L, 1, 3) = 'is ') or (Copy(L, 1, 4) = 'not ') then Exit(C);
  Result := '= ' + QuoteBareValue(C);
end;

function JoinClause(ADb: TAppDb; ATables: TStringList; const AJoin: string): string;
var
  I, J, K: Integer;
  Fk, Parts: TStringList;
  Found: Boolean;
  Kw: string;
  IsTable: array of Boolean;

  function FromItem(const AName: string): string;
  begin
    if ADb.LoadObject('_sys_queries', AName) <> '' then
      Result := ADb.SourceFromRaw(AName) + ' AS ' + ADb.QuoteId(AName)
    else
      Result := ADb.QuoteId(AName);
  end;

begin
  if SameText(AJoin, 'left') then Kw := ' LEFT JOIN ' else Kw := ' INNER JOIN ';
  Result := FromItem(ATables[0]);
  SetLength(IsTable, ATables.Count);
  for I := 0 to ATables.Count - 1 do IsTable[I] := ADb.LoadObject('_sys_queries', ATables[I]) = '';
  Parts := TStringList.Create;
  Parts.Delimiter := '|';
  Parts.StrictDelimiter := True;
  try
    for I := 1 to ATables.Count - 1 do
    begin
      Found := False;
      if IsTable[I] then
      begin
        { a foreign key from the new table to an earlier one, or the other way round }
        Fk := ADb.ForeignKeys(ATables[I]);
        try
          for K := 0 to Fk.Count - 1 do
          begin
            Parts.DelimitedText := Fk[K];
            for J := 0 to I - 1 do
              if (not Found) and IsTable[J] and SameText(Parts[1], ATables[J]) then
              begin
                Result := Result + Kw + FromItem(ATables[I]) + ' ON ' + ADb.QuoteId(ATables[I]) + '.' +
                  ADb.QuoteId(Parts[0]) + ' = ' + ADb.QuoteId(ATables[J]) + '.' + ADb.QuoteId(Parts[2]);
                Found := True;
              end;
          end;
        finally
          Fk.Free;
        end;
        for J := 0 to I - 1 do
        begin
          if Found or not IsTable[J] then Continue;
          Fk := ADb.ForeignKeys(ATables[J]);
          try
            for K := 0 to Fk.Count - 1 do
            begin
              Parts.DelimitedText := Fk[K];
              if (not Found) and SameText(Parts[1], ATables[I]) then
              begin
                Result := Result + Kw + FromItem(ATables[I]) + ' ON ' + ADb.QuoteId(ATables[J]) + '.' +
                  ADb.QuoteId(Parts[0]) + ' = ' + ADb.QuoteId(ATables[I]) + '.' + ADb.QuoteId(Parts[2]);
                Found := True;
              end;
            end;
          finally
            Fk.Free;
          end;
        end;
      end;
      if not Found then Result := Result + ', ' + FromItem(ATables[I]);
    end;
  finally
    Parts.Free;
  end;
end;

function BuildQbeSql(ADb: TAppDb; D: TaQbeDesign; out ASql, AError: string): Boolean;
var
  B: TQbeBuilder;
  I, J, N: Integer;
  Base, Sel, Alias, Tot, Where, Having, Grp, Ord, Cond, C1, C2, Err, FromSql: string;
  Bases: array of string;
  Plain, Totals: Boolean;
  L: TStringList;
  Fl: TaSourceFields;
  Agg: Boolean;

  function Crit(const ABase, ACrit: string): string;
  var
    Sql, E: string;
  begin
    Result := '';
    if Trim(ACrit) = '' then Exit;
    B.ColBase := ABase;
    B.AllowParams := True;
    try
      if not ExprToSql('[__col__] ' + NormalizeCrit(ACrit), @B.Resolve, Sql, E) then
        raise Exception.Create(Tr('Criterion "') + ACrit + '": ' + E);
    finally
      B.AllowParams := False;
    end;
    Result := Sql;
  end;

begin
  ASql := '';
  AError := '';
  Result := False;
  if D.Tables.Count = 0 then begin AError := 'Odaberi barem jednu tablicu.'; Exit; end;
  if Length(D.Cols) = 0 then begin AError := 'Dodaj barem jedan stupac.'; Exit; end;
  B := TQbeBuilder.Create;
  B.Db := ADb;
  B.D := D;
  B.Fields := TStringList.Create;
  try
    try
      for I := 0 to D.Tables.Count - 1 do
      begin
        Fl := SourceFieldList(ADb, D.Tables[I]);
        L := TStringList.Create;
        for J := 0 to High(Fl) do L.Add(LowerCase(Fl[J].Name));
        B.Fields.AddObject(D.Tables[I], L);
      end;
      Totals := False;
      for I := 0 to High(D.Cols) do
        if (D.Cols[I].Total <> '') and not SameText(D.Cols[I].Total, 'where') and not SameText(D.Cols[I].Total, 'expr') then Totals := True;
      SetLength(Bases, Length(D.Cols));
      Sel := ''; Where := ''; Having := ''; Grp := ''; Ord := '';
      N := 0;
      for I := 0 to High(D.Cols) do
      begin
        if Trim(D.Cols[I].Expr) = '' then Continue;
        Plain := IsPlainField(Trim(D.Cols[I].Expr));
        { value of the column before totals }
        if Plain then
        begin
          if Trim(D.Cols[I].Expr) = '*' then Base := '*'
          else if Copy(Trim(D.Cols[I].Expr), Length(Trim(D.Cols[I].Expr)) - 1, 2) = '.*' then
          begin
            Base := Copy(Trim(D.Cols[I].Expr), 1, Length(Trim(D.Cols[I].Expr)) - 2);
            if B.TableOf(Base) < 0 then raise Exception.Create(Tr('Table "') + Base + Tr('" is not in the query.'));
            Base := ADb.QuoteId(Base) + '.*';
          end
          else Base := B.Resolve(Trim(D.Cols[I].Expr));
        end
        else
        begin
          if not ExprToSql(D.Cols[I].Expr, @B.Resolve, Base, Err) then
            raise Exception.Create(Tr('Expression "') + D.Cols[I].Expr + '": ' + Err);
        end;
        Tot := LowerCase(D.Cols[I].Total);
        Agg := False;
        if Tot = 'sum' then begin Base := 'SUM(' + Base + ')'; Agg := True; end
        else if Tot = 'avg' then begin Base := 'AVG(' + Base + ')'; Agg := True; end
        else if Tot = 'count' then begin Base := 'COUNT(' + Base + ')'; Agg := True; end
        else if Tot = 'min' then begin Base := 'MIN(' + Base + ')'; Agg := True; end
        else if Tot = 'max' then begin Base := 'MAX(' + Base + ')'; Agg := True; end
        else if (Tot = 'expr') or ((not Plain) and HasAggregate(D.Cols[I].Expr)) then Agg := HasAggregate(D.Cols[I].Expr);
        Bases[I] := Base;
        { SELECT list }
        Alias := Trim(D.Cols[I].Alias);
        if (Tot <> 'where') and D.Cols[I].Show then
        begin
          if (Alias = '') and not Plain then Alias := 'Izraz' + IntToStr(I + 1);
          if (Alias = '') and (Tot <> '') and (Tot <> 'group') and (Tot <> 'expr') then
          begin
            Alias := Trim(D.Cols[I].Expr);
            if Pos('.', Alias) > 0 then Alias := Copy(Alias, Pos('.', Alias) + 1, MaxInt);
            if Tot = 'sum' then Alias := 'Zbroj_' + Alias
            else if Tot = 'avg' then Alias := 'Prosjek_' + Alias
            else if Tot = 'count' then Alias := 'Broj_' + Alias
            else if Tot = 'min' then Alias := 'Min_' + Alias
            else Alias := 'Max_' + Alias;
          end;
          if Sel <> '' then Sel := Sel + ',' + LineEnding + '       ';
          Sel := Sel + Base;
          if Alias <> '' then Sel := Sel + ' AS ' + ADb.QuoteId(Alias);
          Inc(N);
        end;
        { grouping: every plain column that is not aggregated, once any totals are used }
        if Totals and not Agg and ((Tot = '') or (Tot = 'group')) then
        begin
          if Grp <> '' then Grp := Grp + ', ';
          Grp := Grp + Base;
        end;
        { criteria: this column's own, ORed; columns AND together }
        C1 := Crit(Base, D.Cols[I].Crit);
        C2 := Crit(Base, D.Cols[I].OrCrit);
        Cond := '';
        if (C1 <> '') and (C2 <> '') then Cond := '(' + C1 + ' OR ' + C2 + ')'
        else if C1 <> '' then Cond := C1
        else Cond := C2;
        if Cond <> '' then
        begin
          if Agg then
          begin
            if Having <> '' then Having := Having + ' AND ';
            Having := Having + Cond;
          end
          else
          begin
            if Where <> '' then Where := Where + ' AND ';
            Where := Where + Cond;
          end;
        end;
        { sort }
        if (LowerCase(D.Cols[I].Sort) = 'asc') or (LowerCase(D.Cols[I].Sort) = 'desc') then
        begin
          if Ord <> '' then Ord := Ord + ', ';
          Ord := Ord + Base + ' ' + UpperCase(D.Cols[I].Sort);
        end;
      end;
      if N = 0 then raise Exception.Create(Tr('No column is shown.'));
      FromSql := JoinClause(ADb, D.Tables, D.JoinType);
      ASql := 'SELECT ';
      if D.Distinct then ASql := ASql + 'DISTINCT ';
      ASql := ASql + Sel + LineEnding + 'FROM ' + FromSql;
      if Where <> '' then ASql := ASql + LineEnding + 'WHERE ' + Where;
      if Grp <> '' then ASql := ASql + LineEnding + 'GROUP BY ' + Grp;
      if Having <> '' then ASql := ASql + LineEnding + 'HAVING ' + Having;
      if Ord <> '' then ASql := ASql + LineEnding + 'ORDER BY ' + Ord;
      if D.Top > 0 then ASql := ASql + LineEnding + 'LIMIT ' + IntToStr(D.Top);
      Result := True;
    except
      on E: Exception do begin AError := E.Message; ASql := ''; end;
    end;
  finally
    B.Free;
  end;
end;

type
  TCalcResolver = class
    function Pass(const AName: string): string;
  end;

function TCalcResolver.Pass(const AName: string): string;
var
  P: Integer;
  N: string;
begin
  N := AName;
  P := Pos('.', N);
  if P > 0 then N := Copy(N, P + 1, MaxInt);
  Result := QuoteIdent(N);
end;

function SplitCalc(const ACalc: string): TStringList;
var
  S, Item: string;
  P: Integer;
begin
  Result := TStringList.Create;
  S := ACalc;
  while Trim(S) <> '' do
  begin
    P := Pos(';;', S);
    if P = 0 then begin Item := S; S := ''; end
    else begin Item := Copy(S, 1, P - 1); S := Copy(S, P + 2, MaxInt); end;
    Item := Trim(Item);
    if (Item <> '') and (Pos('=', Item) > 1) then Result.Add(Item);
  end;
end;

function CalcFieldNames(const ACalc: string): TStringList;
var
  L: TStringList;
  I: Integer;
begin
  Result := TStringList.Create;
  L := SplitCalc(ACalc);
  try
    for I := 0 to L.Count - 1 do Result.Add(Trim(Copy(L[I], 1, Pos('=', L[I]) - 1)));
  finally
    L.Free;
  end;
end;

function CalcFieldsSql(ADb: TAppDb; const ACalc: string; out ACols, AError: string): Boolean;
var
  L: TStringList;
  I: Integer;
  R: TCalcResolver;
  Sql, Err, Alias: string;
begin
  ACols := '';
  AError := '';
  Result := True;
  L := SplitCalc(ACalc);
  R := TCalcResolver.Create;
  try
    for I := 0 to L.Count - 1 do
    begin
      Alias := Trim(Copy(L[I], 1, Pos('=', L[I]) - 1));
      if not ExprToSql(Copy(L[I], Pos('=', L[I]) + 1, MaxInt), @R.Pass, Sql, Err) then
      begin
        AError := Alias + ': ' + Err;
        ACols := '';
        Exit(False);
      end;
      ACols := ACols + ', ' + Sql + ' AS ' + ADb.QuoteId(Alias);
    end;
  finally
    R.Free;
    L.Free;
  end;
end;

function QbeSqlWithDesign(const ASql: string; D: TaQbeDesign): string;
var
  Js: string;
begin
  Js := StringReplace(D.ToJson, '*/', '*\/', [rfReplaceAll]);
  Result := Trim(ASql) + LineEnding + '/*QBE' + Js + '*/';
end;

function QbeDesignFromSql(const ASql: string): TaQbeDesign;
var
  P, Q: Integer;
  Js: string;
begin
  Result := nil;
  P := Pos('/*QBE', ASql);
  if P = 0 then Exit;
  Q := Pos('*/', Copy(ASql, P + 5, MaxInt));
  if Q = 0 then Exit;
  Js := Copy(ASql, P + 5, Q - 1);
  Result := TaQbeDesign.Create;
  try
    Result.FromJson(Js);
  except
    FreeAndNil(Result);
  end;
end;

end.
