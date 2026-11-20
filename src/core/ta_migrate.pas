unit ta_migrate;
{ Kopiranje cijele baze u drugu bazu (SQLite -> Postgres / MariaDB): tablice,
  podaci, veze, opisi polja, forme, izvjesca, upiti, makroi, moduli, postavke,
  korisnici i prava. Revizijski trag (_sys_audit) se ne prenosi. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DB, ZDataset, ZDatasetParam, contnrs, ta_meta, ta_types, ta_filestore;

{ Odredisna baza mora biti prazna (bez korisnickih tablica). ALog dobiva tijek. }
function MigrateDb(ASrc, ADst: TAppDb; ALog: TStrings): Boolean;
{ Postgres: podigni niz identity stupca iza umetanja s izričitim šiframa. }
procedure FixSequence(ADst: TAppDb; const ATable, ACol: string);

implementation

function LogicalSqlType(const ADeclared: string): string;
var
  U: string;
begin
  U := UpperCase(ADeclared);
  if Pos('INT', U) > 0 then Result := 'INTEGER'
  else if (Pos('REAL', U) > 0) or (Pos('FLOA', U) > 0) or (Pos('DOUB', U) > 0) or
    (Pos('DEC', U) > 0) or (Pos('NUM', U) > 0) then Result := 'REAL'
  else if Pos('BLOB', U) > 0 then Result := 'BLOB'
  else Result := 'TEXT';
end;

function MetaOf(AMetas: TFPObjectList; const AField: string): TaFieldMeta;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to AMetas.Count - 1 do
    if SameText(TaFieldMeta(AMetas[I]).FieldName, AField) then Exit(TaFieldMeta(AMetas[I]));
end;

{ Struktura tablice iz izvora; autonumber = opis polja ili jedini cjelobrojni primarni kljuc. }
function BuildFieldDefs(ASrc: TAppDb; const ATable: string; out AAutoCol: string): TFieldDefs2;
var
  Q: TZQuery;
  Metas: TFPObjectList;
  M: TaFieldMeta;
  N, PkCount, I: Integer;
begin
  AAutoCol := '';
  SetLength(Result, 0);
  Metas := ASrc.LoadFieldMetas(ATable);
  Q := ASrc.TableInfo(ATable);
  try
    PkCount := 0;
    N := 0;
    while not Q.EOF do
    begin
      if Q.FieldByName('pk').AsInteger > 0 then Inc(PkCount);
      SetLength(Result, N + 1);
      Result[N].Name := Q.FieldByName('name').AsString;
      Result[N].SqlType := LogicalSqlType(Q.FieldByName('type').AsString);
      Result[N].PrimaryKey := Q.FieldByName('pk').AsInteger > 0;
      Result[N].NotNull := Q.FieldByName('notnull').AsInteger <> 0;
      Result[N].Meta := nil;
      M := MetaOf(Metas, Result[N].Name);
      if M <> nil then Result[N].Meta := M.Clone;
      Inc(N);
      Q.Next;
    end;
  finally
    Q.Free;
    Metas.Free;
  end;
  for I := 0 to High(Result) do
  begin
    if (Result[I].Meta <> nil) and (Result[I].Meta.LType = ltAutoNumber) then
      AAutoCol := Result[I].Name
    else if (PkCount = 1) and Result[I].PrimaryKey and (Result[I].SqlType = 'INTEGER') and
      (Result[I].Meta = nil) then
    begin
      Result[I].Meta := TaFieldMeta.Create;
      Result[I].Meta.LType := ltAutoNumber;
      Result[I].Meta.Decimals := 0;
      AAutoCol := Result[I].Name;
    end;
  end;
end;

function CopyRows(ASrc, ADst: TAppDb; const ATable: string): Integer;
var
  S, D: TZQuery;
  Cols, Ph: string;
  I: Integer;
  F: TField;
  P: TZParam;
begin
  Result := 0;
  S := ASrc.NewQuery('SELECT * FROM ' + ASrc.QuoteId(ATable));
  try
    S.Open;
    Cols := '';
    Ph := '';
    for I := 0 to S.FieldCount - 1 do
    begin
      if I > 0 then begin Cols := Cols + ', '; Ph := Ph + ', '; end;
      Cols := Cols + ADst.QuoteId(S.Fields[I].FieldName);
      Ph := Ph + ':p' + IntToStr(I);
    end;
    D := ADst.NewQuery('INSERT INTO ' + ADst.QuoteId(ATable) + ' (' + Cols + ') VALUES (' + Ph + ')');
    try
      while not S.EOF do
      begin
        for I := 0 to S.FieldCount - 1 do
        begin
          F := S.Fields[I];
          P := D.Params.ParamByName('p' + IntToStr(I));
          if F.IsNull then
          begin
            { NULL ipak nosi tip stupca, inace Postgres odbije "character varying" za integer }
            if F.DataType in [ftSmallint, ftInteger, ftLargeint, ftWord, ftAutoInc] then P.DataType := ftLargeint
            else if F.DataType in [ftFloat, ftCurrency, ftFMTBcd] then P.DataType := ftFloat
            else if F.DataType in [ftBlob, ftBytes, ftVarBytes] then P.DataType := ftBlob
            else P.DataType := ftString;
            P.Clear;
          end
          else if F.DataType in [ftBlob, ftBytes, ftVarBytes] then
          begin
            P.DataType := ftBlob;
            P.AsBlob := F.AsBytes;
          end
          else if F.DataType in [ftSmallint, ftInteger, ftLargeint, ftWord, ftAutoInc] then
            P.AsLargeInt := F.AsLargeInt
          else if F.DataType in [ftFloat, ftCurrency] then
            P.AsFloat := F.AsFloat
          else if F.DataType = ftFMTBcd then
            P.AsFloat := F.AsFloat
          else
            P.AsString := F.AsString;
        end;
        D.ExecSQL;
        Inc(Result);
        S.Next;
      end;
    finally
      D.Free;
    end;
  finally
    S.Free;
  end;
end;

procedure FixSequence(ADst: TAppDb; const ATable, ACol: string);
var
  Q: TZQuery;
begin
  if ADst.Kind <> dkPostgres then Exit;   { MariaDB sam podigne AUTO_INCREMENT }
  Q := ADst.NewQuery('SELECT setval(pg_get_serial_sequence(' +
    ADst.QuoteLit(ADst.QuoteId(ATable)) + ', ' + ADst.QuoteLit(LowerCase(ACol)) + '), ' +
    'COALESCE(MAX(' + ADst.QuoteId(ACol) + '), 1), MAX(' + ADst.QuoteId(ACol) + ') IS NOT NULL) FROM ' +
    ADst.QuoteId(ATable));
  try
    Q.Open;
  finally
    Q.Free;
  end;
end;

{ Kopira redove tablice _sys_* po stupcima koje imaju obje strane. }
procedure CopySysRows(ASrc, ADst: TAppDb; const ATable, AKeys: string; ALog: TStrings);
var
  S, T, D: TZQuery;
  Cols, Ph: string;
  I, N: Integer;
  Use: TStringList;
begin
  Use := TStringList.Create;
  try
    try
      S := ASrc.NewQuery('SELECT * FROM ' + ASrc.QuoteId(ATable));
      T := ADst.NewQuery('SELECT * FROM ' + ADst.QuoteId(ATable) + ' WHERE 1 = 0');
    except
      Exit;   { izvor nema ovu tablicu }
    end;
    try
      S.Open;
      T.Open;
      for I := 0 to S.FieldCount - 1 do
        if T.FindField(S.Fields[I].FieldName) <> nil then Use.Add(S.Fields[I].FieldName);
      if Use.Count = 0 then Exit;
      Cols := '';
      Ph := '';
      for I := 0 to Use.Count - 1 do
      begin
        if I > 0 then begin Cols := Cols + ', '; Ph := Ph + ', '; end;
        Cols := Cols + Use[I];
        Ph := Ph + ':p' + IntToStr(I);
      end;
      D := ADst.NewQuery(ADst.UpsertSql(ADst.QuoteId(ATable), AKeys, Cols, Ph));
      try
        N := 0;
        while not S.EOF do
        begin
          for I := 0 to Use.Count - 1 do
            if S.FieldByName(Use[I]).IsNull then
            begin
              D.Params.ParamByName('p' + IntToStr(I)).DataType := ftString;
              D.Params.ParamByName('p' + IntToStr(I)).Clear;
            end
            else D.Params.ParamByName('p' + IntToStr(I)).AsString := S.FieldByName(Use[I]).AsString;
          D.ExecSQL;
          Inc(N);
          S.Next;
        end;
        if N > 0 then ALog.Add(ATable + ': ' + IntToStr(N));
      finally
        D.Free;
      end;
    finally
      S.Free;
      T.Free;
    end;
  finally
    Use.Free;
  end;
end;

{ Spremljeni SQL u formama/upitima navodi tablice kao "OrderDetails"; poslužitelji
  ih vode malim slovima. JSON zapis ima \"Naziv\", a običan tekst "Naziv". }
function LowerQuotedNames(const ADef: string; ANames: TStrings): string;
var
  I: Integer;
  Json: Boolean;
  T: string;
begin
  Result := ADef;
  T := TrimLeft(ADef);
  Json := (T <> '') and (T[1] in ['{', '[']);
  for I := 0 to ANames.Count - 1 do
  begin
    if ANames[I] = LowerCase(ANames[I]) then Continue;
    if Json then
      Result := StringReplace(Result, '\"' + ANames[I] + '\"', '\"' + LowerCase(ANames[I]) + '\"', [rfReplaceAll])
    else
      Result := StringReplace(Result, '"' + ANames[I] + '"', '"' + LowerCase(ANames[I]) + '"', [rfReplaceAll]);
  end;
end;

{ Nazivi svih tablica i stupaca izvora (za prepisivanje navodnika). }
procedure CollectNames(ASrc: TAppDb; ATabs: TStrings; ANames: TStringList);
var
  I: Integer;
  Q: TZQuery;
begin
  ANames.Sorted := True;
  ANames.Duplicates := dupIgnore;
  for I := 0 to ATabs.Count - 1 do
  begin
    ANames.Add(ATabs[I]);
    Q := ASrc.TableInfo(ATabs[I]);
    try
      while not Q.EOF do
      begin
        ANames.Add(Q.FieldByName('name').AsString);
        Q.Next;
      end;
    finally
      Q.Free;
    end;
  end;
end;

function MigrateDb(ASrc, ADst: TAppDb; ALog: TStrings): Boolean;
var
  Tabs, Existing, Objs: TStringList;
  I, J, K, Rows: Integer;
  Fd: TFieldDefs2;
  Auto: string;
  Fks: TaFkDefs;
  AutoCols: TStringList;
  Failed: Integer;
  Names: TStringList;
begin
  Result := False;
  Failed := 0;
  if not (ASrc.Connected and ADst.Connected) then
  begin
    ALog.Add('GREŠKA: obje baze moraju biti otvorene');
    Exit;
  end;
  Existing := ADst.UserTables;
  try
    if Existing.Count > 0 then
    begin
      ALog.Add('GREŠKA: odredišna baza nije prazna (' + Existing[0] + ', ...). Koristi praznu bazu.');
      Exit;
    end;
  finally
    Existing.Free;
  end;
  Tabs := ASrc.UserTables;
  AutoCols := TStringList.Create;
  Names := TStringList.Create;
  try
    CollectNames(ASrc, Tabs, Names);
    { 1. tablice i podaci (veze tek poslije, da redoslijed ne smeta) }
    for I := 0 to Tabs.Count - 1 do
    begin
      Fd := BuildFieldDefs(ASrc, Tabs[I], Auto);
      AutoCols.Add(Auto);
      try
        ADst.CreateTable(Tabs[I], Fd);
        Rows := CopyRows(ASrc, ADst, Tabs[I]);
        if Auto <> '' then FixSequence(ADst, Tabs[I], Auto);
        ALog.Add('tablica ' + Tabs[I] + ': ' + IntToStr(Rows) + ' redaka');
      except
        on E: Exception do
        begin
          Inc(Failed);
          ALog.Add('GREŠKA tablica ' + Tabs[I] + ': ' + E.Message);
        end;
      end;
      for J := 0 to High(Fd) do Fd[J].Meta.Free;
    end;
    { 2. strani kljucevi }
    for I := 0 to Tabs.Count - 1 do
    begin
      Fks := ASrc.GetFks(Tabs[I]);
      if Length(Fks) = 0 then Continue;
      try
        ADst.SetFks(Tabs[I], Fks);
        ALog.Add('veze ' + Tabs[I] + ': ' + IntToStr(Length(Fks)));
      except
        on E: Exception do
        begin
          Inc(Failed);
          ALog.Add('UPOZORENJE veze ' + Tabs[I] + ' nisu postavljene (podaci ih krše?): ' + E.Message);
        end;
      end;
    end;
    { 3. forme, izvjesca, upiti, makroi, moduli }
    for K := Low(SysTables) to High(SysTables) do
    begin
      try
        Objs := ASrc.ListObjects(SysTables[K]);
      except
        Continue;
      end;
      try
        for J := 0 to Objs.Count - 1 do
          ADst.SaveObject(SysTables[K], Objs[J],
            LowerQuotedNames(ASrc.LoadObject(SysTables[K], Objs[J]), Names));
        if Objs.Count > 0 then ALog.Add(SysTables[K] + ': ' + IntToStr(Objs.Count));
      finally
        Objs.Free;
      end;
    end;
    { 4. postavke, korisnici, prava, zadaci }
    try
      CopySysRows(ASrc, ADst, '_sys_settings', 'k', ALog);
      CopySysRows(ASrc, ADst, '_sys_users', 'name', ALog);
      CopySysRows(ASrc, ADst, '_sys_rights', 'kind, name', ALog);
      CopySysRows(ASrc, ADst, '_sys_tasks', 'name', ALog);
    except
      on E: Exception do
      begin
        Inc(Failed);
        ALog.Add('GREŠKA postavke: ' + E.Message);
      end;
    end;
    CopyFileStore(ASrc, ADst, ALog);
    ALog.Add('Spremne vlastite SQL naredbe u upitima/formama prepisuju se doslovno: ' +
      'provjeri ih na novoj bazi (datumske i tekstualne funkcije mogu se razlikovati).');
    Result := Failed = 0;
  finally
    Names.Free;
    AutoCols.Free;
    Tabs.Free;
  end;
end;

end.
