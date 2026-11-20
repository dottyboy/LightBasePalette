unit ta_datatools;
{ Alati za podatke: traži i zamijeni, skupno ažuriranje, duplikati, nepovezani
  zapisi i provjera pravila nad postojećim podacima. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Variants, DB, ZDataset, contnrs, ta_meta, ta_expr;

type
  { Cita redak iz TZQuery za izraze; [value] je ValueV (vrijednost koja se provjerava). }
  TaRowHost = class(TaExprHost)
  public
    Q: TZQuery;
    Metas: TFPObjectList;
    Db: TAppDb;
    ValueV: Variant;
    function FieldValue(const AName: string): Variant; override;
    function Aggregate(const AFunc, AField: string): Variant; override;
    function Variable(const AName: string): Variant; override;
    function Domain(const AFunc, AExpr, ADomain, ACriteria: string): Variant; override;
    function Typed(F: TField): Variant;
  end;

  TReplaceResult = record
    Rows, Cells: Integer;
  end;

{ AField prazno = sva tekstualna polja. Pri ADry samo broji. }
function FindReplace(ADb: TAppDb; const ATable, AField, AFind, AReplace: string;
  AMatchCase, AWholeField, ADry: Boolean; out AResult: TReplaceResult; out AError: string): Boolean;
{ UPDATE tablica SET polje = izraz WHERE uvjet; izraz i uvjet su u jeziku izraza ([polje], Iif, Date...). }
function BulkUpdate(ADb: TAppDb; const ATable, AField, AExpr, AWhere: string; ADry: Boolean;
  out AAffected: Integer; out ASql, AError: string): Boolean;
function DuplicatesSql(ADb: TAppDb; const ASource: string; AFields: TStrings; AShowRows: Boolean;
  out ASql, AError: string): Boolean;
function UnmatchedSql(ADb: TAppDb; const ATableA, AFieldA, ATableB, AFieldB: string;
  out ASql, AError: string): Boolean;
{ Provjerava pravila polja nad svim redcima; vraca broj prekrsaja. ATable prazno = sve tablice. }
function CheckRules(ADb: TAppDb; const ATable: string; ALog: TStrings; AMaxLog: Integer = 200): Integer;

implementation

uses
  ta_types, ta_exprdb, ta_exprsql, ta_wizardgen;

{ ---------------- find and replace ---------------- }

function ReplaceText(const S, AFind, ARepl: string; AMatchCase, AWhole: Boolean): string;
var
  Flags: TReplaceFlags;
begin
  if AWhole then
  begin
    if (AMatchCase and (S = AFind)) or ((not AMatchCase) and SameText(S, AFind)) then Exit(ARepl);
    Exit(S);
  end;
  Flags := [rfReplaceAll];
  if not AMatchCase then Include(Flags, rfIgnoreCase);
  Result := StringReplace(S, AFind, ARepl, Flags);
end;

function FindReplace(ADb: TAppDb; const ATable, AField, AFind, AReplace: string;
  AMatchCase, AWholeField, ADry: Boolean; out AResult: TReplaceResult; out AError: string): Boolean;
var
  Fields: TStringList;
  Metas: TFPObjectList;
  Q, U: TZQuery;
  I, J: Integer;
  M: TaFieldMeta;
  Rowids, Olds, News, RowSet: TStringList;
  Changed: Boolean;
  Typ: string;
begin
  Result := False;
  AResult.Rows := 0;
  AResult.Cells := 0;
  AError := '';
  if AFind = '' then begin AError := 'Upiši što se traži.'; Exit; end;
  Fields := TStringList.Create;
  Metas := ADb.LoadFieldMetas(ATable);
  try
    if AField <> '' then Fields.Add(AField)
    else
    begin
      Q := ADb.TableInfo(ATable);
      try
        while not Q.EOF do
        begin
          Typ := UpperCase(Q.FieldByName('type').AsString);
          M := nil;
          for J := 0 to Metas.Count - 1 do
            if SameText(TaFieldMeta(Metas[J]).FieldName, Q.FieldByName('name').AsString) then M := TaFieldMeta(Metas[J]);
          if ((M <> nil) and (M.LType in [ltText, ltMemo])) or ((M = nil) and (Pos('CHAR', Typ) + Pos('TEXT', Typ) > 0)) then
            Fields.Add(Q.FieldByName('name').AsString);
          Q.Next;
        end;
      finally
        Q.Free;
      end;
    end;
    if Fields.Count = 0 then begin AError := 'Nema tekstualnih polja.'; Exit; end;
    Rowids := TStringList.Create;
    Olds := TStringList.Create;
    News := TStringList.Create;
    RowSet := TStringList.Create;
    RowSet.Sorted := True;
    RowSet.Duplicates := dupIgnore;
    try
      try
        ADb.Conn.StartTransaction;
        for I := 0 to Fields.Count - 1 do
        begin
          Rowids.Clear; Olds.Clear; News.Clear;
          Q := ADb.NewQuery('SELECT ' + ADb.RowIdSql(ATable) + ', ' + ADb.QuoteId(Fields[I]) + ' FROM ' + ADb.QuoteId(ATable) +
            ' WHERE ' + ADb.QuoteId(Fields[I]) + ' IS NOT NULL');
          try
            Q.Open;
            while not Q.EOF do
            begin
              Rowids.Add(Q.Fields[0].AsString);
              Olds.Add(Q.Fields[1].AsString);
              Q.Next;
            end;
          finally
            Q.Free;
          end;
          for J := 0 to Rowids.Count - 1 do
          begin
            News.Add(ReplaceText(Olds[J], AFind, AReplace, AMatchCase, AWholeField));
            if News[J] <> Olds[J] then
            begin
              Inc(AResult.Cells);
              RowSet.Add(Rowids[J]);
              if not ADry then
              begin
                U := ADb.NewQuery('UPDATE ' + ADb.QuoteId(ATable) + ' SET ' + ADb.QuoteId(Fields[I]) + ' = :v WHERE ' + ADb.RowIdSql(ATable) + ' = :r');
                try
                  U.ParamByName('v').AsString := News[J];
                  U.ParamByName('r').AsString := Rowids[J];
                  U.ExecSQL;
                finally
                  U.Free;
                end;
              end;
            end;
          end;
        end;
        if ADry then ADb.Conn.Rollback else ADb.Conn.Commit;
      except
        on E: Exception do
        begin
          AError := E.Message;
          if ADb.Conn.InTransaction then ADb.Conn.Rollback;
          Exit;
        end;
      end;
      AResult.Rows := RowSet.Count;
    finally
      Rowids.Free; Olds.Free; News.Free; RowSet.Free;
    end;
    Changed := True;
    Result := Changed;
  finally
    Fields.Free;
    Metas.Free;
  end;
end;

{ ---------------- bulk update ---------------- }

type
  TFieldQuoter = class
    Db: TAppDb;
    function Resolve(const AName: string): string;
  end;

function TFieldQuoter.Resolve(const AName: string): string;
var
  P: Integer;
  N: string;
begin
  N := AName;
  P := Pos('.', N);
  if P > 0 then N := Copy(N, P + 1, MaxInt);
  Result := Db.QuoteId(N);
end;

function BulkUpdate(ADb: TAppDb; const ATable, AField, AExpr, AWhere: string; ADry: Boolean;
  out AAffected: Integer; out ASql, AError: string): Boolean;
var
  R: TFieldQuoter;
  ExprSql, WhereSql, Err: string;
  Q: TZQuery;
  Cond: string;
begin
  Result := False;
  AAffected := 0;
  ASql := '';
  AError := '';
  if (ATable = '') or (AField = '') or (Trim(AExpr) = '') then
  begin AError := 'Odaberi tablicu, polje i upiši novu vrijednost.'; Exit; end;
  R := TFieldQuoter.Create;
  try
    R.Db := ADb;
    if not ExprToSql(AExpr, @R.Resolve, ExprSql, Err) then begin AError := 'Nova vrijednost: ' + Err; Exit; end;
    WhereSql := '';
    if Trim(AWhere) <> '' then
      if not ExprToSql(AWhere, @R.Resolve, WhereSql, Err) then begin AError := 'Uvjet: ' + Err; Exit; end;
  finally
    R.Free;
  end;
  Cond := '';
  if WhereSql <> '' then Cond := ' WHERE ' + WhereSql;
  ASql := 'UPDATE ' + ADb.QuoteId(ATable) + ' SET ' + ADb.QuoteId(AField) + ' = ' + ExprSql + Cond;
  try
    if ADry then
    begin
      Q := ADb.NewQuery('SELECT COUNT(*) FROM ' + ADb.QuoteId(ATable) + Cond);
      try
        Q.Open;
        AAffected := Q.Fields[0].AsInteger;
      finally
        Q.Free;
      end;
    end
    else
    begin
      Q := ADb.NewQuery(ASql);
      try
        Q.ExecSQL;
        AAffected := Q.RowsAffected;
      finally
        Q.Free;
      end;
    end;
    Result := True;
  except
    on E: Exception do AError := E.Message;
  end;
end;

{ ---------------- duplicates and unmatched ---------------- }

function DuplicatesSql(ADb: TAppDb; const ASource: string; AFields: TStrings; AShowRows: Boolean;
  out ASql, AError: string): Boolean;
var
  I: Integer;
  Cols, From: string;
begin
  Result := False;
  ASql := '';
  AError := '';
  if (ASource = '') or (AFields.Count = 0) then begin AError := 'Odaberi izvor i barem jedno polje.'; Exit; end;
  From := ADb.SourceFromRaw(ASource);
  Cols := '';
  for I := 0 to AFields.Count - 1 do
  begin
    if Cols <> '' then Cols := Cols + ', ';
    Cols := Cols + ADb.QuoteId(AFields[I]);
  end;
  if AShowRows then
    ASql := 'SELECT * FROM ' + From + ' WHERE (' + Cols + ') IN (SELECT ' + Cols + ' FROM ' + From +
      ' GROUP BY ' + Cols + ' HAVING COUNT(*) > 1)' + LineEnding + 'ORDER BY ' + Cols
  else
    ASql := 'SELECT ' + Cols + ', COUNT(*) AS ' + ADb.QuoteId('Broj') + LineEnding + 'FROM ' + From + LineEnding +
      'GROUP BY ' + Cols + LineEnding + 'HAVING COUNT(*) > 1' + LineEnding + 'ORDER BY COUNT(*) DESC, ' + Cols;
  Result := True;
end;

function UnmatchedSql(ADb: TAppDb; const ATableA, AFieldA, ATableB, AFieldB: string;
  out ASql, AError: string): Boolean;
begin
  Result := False;
  ASql := '';
  AError := '';
  if (ATableA = '') or (AFieldA = '') or (ATableB = '') or (AFieldB = '') then
  begin AError := 'Odaberi obje tablice i po jedno polje za usporedbu.'; Exit; end;
  ASql := 'SELECT a.* FROM ' + ADb.SourceFromRaw(ATableA) + ' AS a' + LineEnding +
    'WHERE NOT EXISTS (SELECT 1 FROM ' + ADb.SourceFromRaw(ATableB) + ' AS b WHERE b.' + ADb.QuoteId(AFieldB) +
    ' = a.' + ADb.QuoteId(AFieldA) + ')';
  Result := True;
end;

{ ---------------- rule check ---------------- }

function TaRowHost.Typed(F: TField): Variant;
var
  I: Integer;
  M: TaFieldMeta;
begin
  if F.IsNull then Exit(Null);
  M := nil;
  for I := 0 to Metas.Count - 1 do
    if SameText(TaFieldMeta(Metas[I]).FieldName, F.FieldName) then M := TaFieldMeta(Metas[I]);
  if F.DataType in [ftSmallint, ftInteger, ftLargeint, ftWord, ftAutoInc] then
  begin
    if (M <> nil) and (M.LType = ltYesNo) then Exit(F.AsInteger <> 0);
    Exit(F.AsLargeInt);
  end;
  if F.DataType in [ftFloat, ftCurrency, ftBCD, ftFMTBcd, ftSingle] then Exit(F.AsFloat);
  if F.DataType = ftBoolean then Exit(F.AsBoolean);
  Result := F.AsString;
end;

function TaRowHost.FieldValue(const AName: string): Variant;
var
  F: TField;
begin
  { [value] je vrijednost polja koje se provjerava }
  if SameText(AName, 'value') then Exit(ValueV);
  F := Q.FindField(AName);
  if F = nil then Exit(Null);
  Result := Typed(F);
end;

function TaRowHost.Aggregate(const AFunc, AField: string): Variant;
begin
  Result := Null;
end;

function TaRowHost.Variable(const AName: string): Variant;
begin
  if SameText(AName, 'value') then Result := ValueV else Result := Null;
end;

function TaRowHost.Domain(const AFunc, AExpr, ADomain, ACriteria: string): Variant;
begin
  Result := DbDomain(Db, AFunc, AExpr, ADomain, ACriteria);
end;

function CheckRules(ADb: TAppDb; const ATable: string; ALog: TStrings; AMaxLog: Integer): Integer;
var
  Tables: TStringList;
  T, I: Integer;
  Metas: TFPObjectList;
  M: TaFieldMeta;
  Q: TZQuery;
  H: TaRowHost;
  F: TField;
  R: Variant;
  Msg, Key: string;
  OldDb: TAppDb;
begin
  Result := 0;
  Tables := TStringList.Create;
  OldDb := ActiveDb;
  ActiveDb := ADb;
  try
    if ATable <> '' then Tables.Add(ATable)
    else
    begin
      Tables.Free;
      Tables := ADb.UserTables;
    end;
    for T := 0 to Tables.Count - 1 do
    begin
      Metas := ADb.LoadFieldMetas(Tables[T]);
      try
        for I := 0 to Metas.Count - 1 do
        begin
          M := TaFieldMeta(Metas[I]);
          if Trim(M.Validation) = '' then Continue;
          Q := ADb.NewQuery('SELECT ' + ADb.RowIdSql(Tables[T]) + ' AS _rid_, * FROM ' + ADb.QuoteId(Tables[T]));
          H := TaRowHost.Create;
          try
            H.Q := Q; H.Metas := Metas; H.Db := ADb;
            Q.Open;
            while not Q.EOF do
            begin
              F := Q.FindField(M.FieldName);
              if (F <> nil) and (not F.IsNull) and (F.AsString <> '') then
              begin
                H.ValueV := H.Typed(F);
                R := EvalExpr(M.Validation, H);
                if (not VarIsNull(R)) and not ExprIsTrue(R) then
                begin
                  Inc(Result);
                  if (ALog <> nil) and (ALog.Count < AMaxLog) then
                  begin
                    Msg := M.ValidationMsg;
                    if Msg = '' then Msg := 'ne zadovoljava pravilo ' + M.Validation;
                    Key := Q.FieldByName('_rid_').AsString;
                    ALog.Add(Tables[T] + ' (redak ' + Key + '), ' + M.FieldName + ' = "' + F.AsString + '": ' + Msg);
                  end;
                end;
              end;
              Q.Next;
            end;
          finally
            H.Free;
            Q.Free;
          end;
        end;
      finally
        Metas.Free;
      end;
    end;
  finally
    ActiveDb := OldDb;
    Tables.Free;
  end;
end;

end.
