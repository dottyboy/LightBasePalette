unit ta_importexport;
{ Import and export: CSV (delimiter and code page detection), XLSX/ODS via
  fpspreadsheet, JSON. Imported columns get a logical type inferred from the
  data, so dates, decimals and Yes/No arrive as real typed fields. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Variants, DB, contnrs, fpjson, ZDataset, LConvEncoding,
  fpspreadsheet, fpstypes, fpsallformats, ta_meta, ta_types;

type
  TaRows = array of array of string;

  TaImportCol = record
    Name: string;
    LType: TaLogicalType;
    Decimals: Integer;
  end;
  TaImportCols = array of TaImportCol;

  TaImportResult = record
    Inserted, Skipped, BadValues: Integer;
  end;

function ReadCsvFile(const AFile: string; ADelim: Char; out ARows: TaRows; out AUsed: Char): Boolean;
function ReadSheetFile(const AFile: string; out ARows: TaRows): Boolean;
function ReadAnyFile(const AFile: string; ADelim: Char; out ARows: TaRows): Boolean;
function InferColumns(const ARows: TaRows; AHasHeader: Boolean): TaImportCols;
function ImportToNewTable(ADb: TAppDb; const ATable: string; const ARows: TaRows;
  AHasHeader, AAddKey: Boolean; const ACols: TaImportCols): TaImportResult;
function ImportToExisting(ADb: TAppDb; const ATable: string; const ARows: TaRows;
  AHasHeader: Boolean): TaImportResult;

procedure ExportCsv(ADb: TAppDb; const ASource, AFile: string; ADelim: Char);
{ izvozi vec pripremljen upit (npr. filtrirani pogled mreze) }
procedure ExportQueryCsv(ADb: TAppDb; Q: TZQuery; const AMetaSource, AFile: string; ADelim: Char);
procedure ExportXlsx(ADb: TAppDb; const ASource, AFile: string);
procedure ExportJson(ADb: TAppDb; const ASource, AFile: string);

implementation

{ ---------------- CSV ---------------- }

function ValidUtf8(const S: string): Boolean;
var
  I, N, K: Integer;
  C: Byte;
begin
  I := 1;
  N := Length(S);
  while I <= N do
  begin
    C := Ord(S[I]);
    if C < $80 then K := 0
    else if (C and $E0) = $C0 then K := 1
    else if (C and $F0) = $E0 then K := 2
    else if (C and $F8) = $F0 then K := 3
    else Exit(False);
    if I + K > N then Exit(False);
    while K > 0 do
    begin
      Inc(I);
      if (Ord(S[I]) and $C0) <> $80 then Exit(False);
      Dec(K);
    end;
    Inc(I);
  end;
  Result := True;
end;

function LoadText(const AFile: string): string;
var
  Fs: TFileStream;
begin
  Fs := TFileStream.Create(AFile, fmOpenRead or fmShareDenyNone);
  try
    SetLength(Result, Fs.Size);
    if Fs.Size > 0 then Fs.ReadBuffer(Result[1], Fs.Size);
  finally
    Fs.Free;
  end;
  if (Length(Result) >= 3) and (Result[1] = #$EF) and (Result[2] = #$BB) and (Result[3] = #$BF) then
    Delete(Result, 1, 3)
  else if not ValidUtf8(Result) then
    Result := CP1250ToUTF8(Result);   { typical for Croatian Excel exports }
end;

function DetectDelimiter(const S: string): Char;
const
  Cands: array[0..3] of Char = (';', ',', #9, '|');
var
  Counts: array[0..3] of Integer;
  I, K, Best: Integer;
  InQ: Boolean;
begin
  FillChar(Counts, SizeOf(Counts), 0);
  InQ := False;
  for I := 1 to Length(S) do
  begin
    if S[I] = '"' then InQ := not InQ
    else if (not InQ) and (S[I] in [#10, #13]) then Break
    else if not InQ then
      for K := 0 to 3 do
        if S[I] = Cands[K] then Inc(Counts[K]);
  end;
  Best := 0;
  for I := 1 to 3 do
    if Counts[I] > Counts[Best] then Best := I;
  if Counts[Best] = 0 then Result := ';' else Result := Cands[Best];
end;

function ReadCsvFile(const AFile: string; ADelim: Char; out ARows: TaRows; out AUsed: Char): Boolean;
var
  S, Field: string;
  I, N, Col, R: Integer;
  InQ, AnyChar: Boolean;
  Row: array of string;

  procedure EndField;
  begin
    SetLength(Row, Col + 1);
    Row[Col] := Field;
    Inc(Col);
    Field := '';
  end;

  procedure EndRow;
  var
    K: Integer;
  begin
    EndField;
    if (Length(Row) = 1) and (Row[0] = '') then begin Col := 0; SetLength(Row, 0); Exit; end;
    SetLength(ARows, R + 1);
    SetLength(ARows[R], Length(Row));
    for K := 0 to High(Row) do ARows[R][K] := Row[K];
    Inc(R);
    Col := 0;
    SetLength(Row, 0);
    AnyChar := False;
  end;

begin
  SetLength(ARows, 0);
  S := LoadText(AFile);
  if ADelim = #0 then AUsed := DetectDelimiter(S) else AUsed := ADelim;
  N := Length(S);
  I := 1;
  Col := 0;
  R := 0;
  Field := '';
  InQ := False;
  AnyChar := False;
  while I <= N do
  begin
    if InQ then
    begin
      if S[I] = '"' then
      begin
        if (I < N) and (S[I + 1] = '"') then begin Field := Field + '"'; Inc(I); end
        else InQ := False;
      end
      else Field := Field + S[I];
    end
    else if S[I] = '"' then begin InQ := True; AnyChar := True; end
    else if S[I] = AUsed then begin EndField; AnyChar := True; end
    else if S[I] = #13 then
    begin
      if (I < N) and (S[I + 1] = #10) then Inc(I);
      EndRow;
    end
    else if S[I] = #10 then EndRow
    else begin Field := Field + S[I]; AnyChar := True; end;
    Inc(I);
  end;
  if AnyChar or (Field <> '') or (Col > 0) then EndRow;
  Result := Length(ARows) > 0;
end;

{ ---------------- spreadsheets ---------------- }

function ReadSheetFile(const AFile: string; out ARows: TaRows): Boolean;
var
  Book: TsWorkbook;
  Sheet: TsWorksheet;
  R, C, LastR, LastC: Integer;
  Cell: PCell;
  D: TDateTime;
  S: string;
begin
  SetLength(ARows, 0);
  Book := TsWorkbook.Create;
  try
    Book.ReadFromFile(AFile);
    Sheet := Book.GetWorksheetByIndex(0);
    if Sheet = nil then Exit(False);
    LastR := Sheet.GetLastRowIndex;
    LastC := Sheet.GetLastColIndex;
    SetLength(ARows, LastR + 1);
    for R := 0 to LastR do
    begin
      SetLength(ARows[R], LastC + 1);
      for C := 0 to LastC do
      begin
        Cell := Sheet.FindCell(R, C);
        S := '';
        if Cell <> nil then
          case Cell^.ContentType of
            cctNumber: S := FloatToStr(Cell^.NumberValue, InvariantFS);
            cctDateTime:
              begin
                D := Cell^.DateTimeValue;
                if Trunc(D) = 0 then S := FormatDateTime('hh:nn:ss', D)
                else if Frac(D) = 0 then S := FormatDateTime('yyyy-mm-dd', D)
                else S := FormatDateTime('yyyy-mm-dd hh:nn:ss', D);
              end;
            cctBool:
              if Cell^.BoolValue then S := '1' else S := '0';
            cctUTF8String: S := Cell^.UTF8StringValue;
            cctEmpty: S := '';
          else
            S := Sheet.ReadAsText(Cell);
          end;
        ARows[R][C] := S;
      end;
    end;
    Result := Length(ARows) > 0;
  finally
    Book.Free;
  end;
end;

function ReadAnyFile(const AFile: string; ADelim: Char; out ARows: TaRows): Boolean;
var
  Ext: string;
  Used: Char;
begin
  Ext := LowerCase(ExtractFileExt(AFile));
  if (Ext = '.xlsx') or (Ext = '.xls') or (Ext = '.ods') then Result := ReadSheetFile(AFile, ARows)
  else Result := ReadCsvFile(AFile, ADelim, ARows, Used);
end;

{ ---------------- type inference ---------------- }

{ Integer part with thousands separators: one separator character only, first
  group 1-3 digits, every other group exactly 3. }
function ValidThousands(const S: string): Boolean;
var
  I, Grp, Groups: Integer;
  Sep: Char;
begin
  Result := False;
  Sep := #0;
  Grp := 0;
  Groups := 0;
  for I := 1 to Length(S) + 1 do
  begin
    if (I <= Length(S)) and (S[I] in ['0'..'9']) then Inc(Grp)
    else
    begin
      if Groups = 0 then begin if (Grp < 1) or (Grp > 3) then Exit; end
      else if Grp <> 3 then Exit;
      Inc(Groups);
      Grp := 0;
      if I <= Length(S) then
      begin
        if (Sep <> #0) and (S[I] <> Sep) then Exit;
        Sep := S[I];
      end;
    end;
  end;
  Result := True;
end;

{ A number uses '.' and ',' only as one decimal separator and/or thousands
  groups of exactly three digits, so 1.2.2026 is a date, not a number. }
function LooksNumeric(const S: string): Boolean;
var
  T, IntPart: string;
  I, LastSep, SameCount: Integer;
begin
  T := StringReplace(S, ' ', '', [rfReplaceAll]);
  if (T <> '') and (T[1] in ['+', '-']) then Delete(T, 1, 1);
  if T = '' then Exit(False);
  if not (T[1] in ['0'..'9']) or not (T[Length(T)] in ['0'..'9']) then Exit(False);
  LastSep := 0;
  for I := 1 to Length(T) do
    case T[I] of
      '0'..'9': ;
      '.', ',': LastSep := I;
    else
      Exit(False);
    end;
  if LastSep = 0 then Exit(True);
  SameCount := 0;
  for I := 1 to Length(T) do
    if T[I] = T[LastSep] then Inc(SameCount);
  IntPart := Copy(T, 1, LastSep - 1);
  if SameCount = 1 then
  begin
    { the last separator is the decimal one; anything before it is thousands }
    if (Pos('.', IntPart) = 0) and (Pos(',', IntPart) = 0) then Exit(True);
    Exit(ValidThousands(IntPart));
  end;
  { several equal separators: they can only be thousands }
  Result := ValidThousands(T);
end;

function IsDateLike(const S: string): Boolean;
var
  I, Seps: Integer;
  T: string;
begin
  T := Trim(S);
  if (T <> '') and (T[Length(T)] = '.') then Delete(T, Length(T), 1);
  Seps := 0;
  for I := 1 to Length(T) do
    case T[I] of
      '0'..'9': ;
      '.', '/', '-': Inc(Seps);
    else
      Exit(False);
    end;
  Result := (Seps = 2) and (T <> '') and (T[Length(T)] in ['0'..'9']);
end;

function IsPlainInteger(const S: string): Boolean;
var
  I, Start: Integer;
begin
  Result := False;
  Start := 1;
  if (S <> '') and (S[1] in ['+', '-']) then Start := 2;
  if (Length(S) - Start + 1 < 1) or (Length(S) - Start + 1 > 15) then Exit;
  for I := Start to Length(S) do
    if not (S[I] in ['0'..'9']) then Exit;
  { leading zeros (phone numbers, codes) stay text }
  if (S[Start] = '0') and (Length(S) - Start + 1 > 1) then Exit;
  Result := True;
end;

function FracDigits(const S: string): Integer;
var
  P: Integer;
begin
  P := LastDelimiter(',.', S);
  if P = 0 then Result := 0 else Result := Length(S) - P;
end;

function InferColumns(const ARows: TaRows; AHasHeader: Boolean): TaImportCols;
var
  NCols, R, C, FirstRow, MaxLen, Dec, K: Integer;
  S, T: string;
  M: TaFieldMeta;
  Stored: string;
  OkInt, OkDec, OkDate, OkDT, OkTime, OkYN, Any: Boolean;
  Names: TStringList;
begin
  NCols := 0;
  for R := 0 to High(ARows) do
    if Length(ARows[R]) > NCols then NCols := Length(ARows[R]);
  SetLength(Result, NCols);
  if AHasHeader then FirstRow := 1 else FirstRow := 0;
  Names := TStringList.Create;
  M := TaFieldMeta.Create;
  try
    for C := 0 to NCols - 1 do
    begin
      OkInt := True; OkDec := True; OkDate := True; OkDT := True; OkTime := True; OkYN := True;
      Any := False; MaxLen := 0; Dec := 0;
      for R := FirstRow to High(ARows) do
      begin
        if C > High(ARows[R]) then Continue;
        S := Trim(ARows[R][C]);
        if S = '' then Continue;
        Any := True;
        if Length(S) > MaxLen then MaxLen := Length(S);
        if not IsPlainInteger(S) then OkInt := False;
        if not LooksNumeric(S) then OkDec := False
        else if FracDigits(S) > Dec then Dec := FracDigits(S);
        M.LType := ltDate;
        if not IsDateLike(S) then OkDate := False
        else if not DisplayToStored(M, S, Stored) then OkDate := False;
        M.LType := ltDateTime;
        if (Pos(':', S) = 0) or ((Pos(' ', S) = 0) and (Pos('T', S) = 0)) then OkDT := False
        else if not DisplayToStored(M, S, Stored) then OkDT := False;
        M.LType := ltTime;
        if (Pos(':', S) = 0) or (Pos('.', S) > 0) or (Pos('-', S) > 0) or (Pos(' ', S) > 0) then OkTime := False
        else if not DisplayToStored(M, S, Stored) then OkTime := False;
        T := LowerCase(S);
        if not ((T = 'da') or (T = 'ne') or (T = 'yes') or (T = 'no') or (T = 'true') or (T = 'false')) then OkYN := False;
      end;
      if AHasHeader and (C <= High(ARows[0])) then S := Trim(ARows[0][C]) else S := '';
      if S = '' then S := 'polje' + IntToStr(C + 1);
      T := S;
      K := 2;
      while Names.IndexOf(LowerCase(T)) >= 0 do begin T := S + '_' + IntToStr(K); Inc(K); end;
      Names.Add(LowerCase(T));
      Result[C].Name := T;
      Result[C].Decimals := 0;
      if not Any then Result[C].LType := ltText
      else if OkInt then Result[C].LType := ltInteger
      else if OkDec then
      begin
        Result[C].LType := ltDecimal;
        if Dec > 4 then Dec := 4;
        if Dec = 0 then Dec := 2;
        Result[C].Decimals := Dec;
      end
      else if OkDate then Result[C].LType := ltDate
      else if OkDT then Result[C].LType := ltDateTime
      else if OkTime then Result[C].LType := ltTime
      else if OkYN then Result[C].LType := ltYesNo
      else if MaxLen > 255 then Result[C].LType := ltMemo
      else Result[C].LType := ltText;
    end;
  finally
    M.Free;
    Names.Free;
  end;
end;

{ ---------------- import ---------------- }

function ConvertCell(M: TaFieldMeta; const AText: string; var ABad: Integer; out AIsNull: Boolean): string;
var
  T: string;
begin
  T := Trim(AText);
  AIsNull := T = '';
  Result := '';
  if AIsNull then Exit;
  if M = nil then begin Result := AText; Exit; end;
  if M.LType in [ltText, ltMemo] then begin Result := AText; Exit; end;
  if not DisplayToStored(M, T, Result) then
  begin
    Inc(ABad);
    AIsNull := True;
    Result := '';
  end;
end;

function InsertRows(ADb: TAppDb; const ATable: string; const ARows: TaRows; AFirstRow: Integer;
  const ATargets: array of string; const AMetas: array of TaFieldMeta;
  const ASourceCols: array of Integer): TaImportResult;
var
  Q: TZQuery;
  Sql, Params, V: string;
  R, I: Integer;
  IsNull: Boolean;
begin
  Result.Inserted := 0; Result.Skipped := 0; Result.BadValues := 0;
  if Length(ATargets) = 0 then Exit;
  Sql := 'INSERT INTO ' + ADb.QuoteId(ATable) + ' (';
  Params := '';
  for I := 0 to High(ATargets) do
  begin
    if I > 0 then begin Sql := Sql + ', '; Params := Params + ', '; end;
    Sql := Sql + ADb.QuoteId(ATargets[I]);
    Params := Params + ':p' + IntToStr(I);
  end;
  Q := ADb.NewQuery(Sql + ') VALUES (' + Params + ')');
  ADb.Conn.StartTransaction;
  try
    for R := AFirstRow to High(ARows) do
    begin
      for I := 0 to High(ATargets) do
      begin
        if ASourceCols[I] <= High(ARows[R]) then
          V := ConvertCell(AMetas[I], ARows[R][ASourceCols[I]], Result.BadValues, IsNull)
        else
        begin
          V := '';
          IsNull := True;
        end;
        if IsNull then
        begin
          Q.Params[I].DataType := ftString;
          Q.Params[I].Clear;
        end
        else Q.Params[I].AsString := V;
      end;
      try
        Q.ExecSQL;
        Inc(Result.Inserted);
      except
        Inc(Result.Skipped);
      end;
    end;
    ADb.Conn.Commit;
  except
    ADb.Conn.Rollback;
    Q.Free;
    raise;
  end;
  Q.Free;
end;

function ImportToNewTable(ADb: TAppDb; const ATable: string; const ARows: TaRows;
  AHasHeader, AAddKey: Boolean; const ACols: TaImportCols): TaImportResult;
var
  Fl: TFieldDefs2;
  Targets: array of string;
  Metas: array of TaFieldMeta;
  Src: array of Integer;
  I, N, First: Integer;
  HasId: Boolean;
begin
  HasId := False;
  for I := 0 to High(ACols) do
    if SameText(ACols[I].Name, 'id') then HasId := True;
  AAddKey := AAddKey and not HasId;
  N := Length(ACols);
  if AAddKey then Inc(N);
  SetLength(Fl, N);
  SetLength(Targets, Length(ACols));
  SetLength(Metas, Length(ACols));
  SetLength(Src, Length(ACols));
  I := 0;
  if AAddKey then
  begin
    Fl[0].Name := 'id';
    Fl[0].PrimaryKey := True;
    Fl[0].Meta := TaFieldMeta.Create;
    Fl[0].Meta.LType := ltAutoNumber;
    Fl[0].Meta.Decimals := 0;
    I := 1;
  end;
  for N := 0 to High(ACols) do
  begin
    Fl[I].Name := ACols[N].Name;
    Fl[I].Meta := TaFieldMeta.Create;
    Fl[I].Meta.LType := ACols[N].LType;
    Fl[I].Meta.Decimals := ACols[N].Decimals;
    Fl[I].Meta.Format := DefaultFormat(ACols[N].LType, ACols[N].Decimals);
    Targets[N] := ACols[N].Name;
    Metas[N] := Fl[I].Meta;
    Src[N] := N;
    Inc(I);
  end;
  try
    ADb.CreateTable(ATable, Fl);
    if AHasHeader then First := 1 else First := 0;
    Result := InsertRows(ADb, ATable, ARows, First, Targets, Metas, Src);
  finally
    for I := 0 to High(Fl) do Fl[I].Meta.Free;
  end;
end;

function ImportToExisting(ADb: TAppDb; const ATable: string; const ARows: TaRows;
  AHasHeader: Boolean): TaImportResult;
var
  Info: TZQuery;
  TableCols: TStringList;
  Metas: TFPObjectList;
  Targets: array of string;
  MetaArr: array of TaFieldMeta;
  Src: array of Integer;
  I, J, N, First, K: Integer;
begin
  Result.Inserted := 0; Result.Skipped := 0; Result.BadValues := 0;
  TableCols := TStringList.Create;
  Info := ADb.TableInfo(ATable);
  try
    while not Info.EOF do
    begin
      TableCols.Add(Info.FieldByName('name').AsString);
      Info.Next;
    end;
  finally
    Info.Free;
  end;
  Metas := ADb.LoadFieldMetas(ATable);
  try
    if AHasHeader and (Length(ARows) > 0) then
    begin
      for I := 0 to High(ARows[0]) do
      begin
        J := -1;
        for N := 0 to TableCols.Count - 1 do
          if SameText(TableCols[N], Trim(ARows[0][I])) then begin J := N; Break; end;
        if J < 0 then Continue;
        K := Length(Targets);
        SetLength(Targets, K + 1);
        SetLength(MetaArr, K + 1);
        SetLength(Src, K + 1);
        Targets[K] := TableCols[J];
        Src[K] := I;
        MetaArr[K] := nil;
        for N := 0 to Metas.Count - 1 do
          if SameText(TaFieldMeta(Metas[N]).FieldName, TableCols[J]) then
            MetaArr[K] := TaFieldMeta(Metas[N]);
      end;
    end
    else
      { no header: map by position }
      for I := 0 to TableCols.Count - 1 do
      begin
        SetLength(Targets, I + 1);
        SetLength(MetaArr, I + 1);
        SetLength(Src, I + 1);
        Targets[I] := TableCols[I];
        Src[I] := I;
        MetaArr[I] := nil;
        for N := 0 to Metas.Count - 1 do
          if SameText(TaFieldMeta(Metas[N]).FieldName, TableCols[I]) then
            MetaArr[I] := TaFieldMeta(Metas[N]);
      end;
    if AHasHeader then First := 1 else First := 0;
    Result := InsertRows(ADb, ATable, ARows, First, Targets, MetaArr, Src);
  finally
    Metas.Free;
    TableCols.Free;
  end;
end;

{ ---------------- export ---------------- }

function SourceMetas(ADb: TAppDb; const ASource: string): TFPObjectList;
begin
  if ADb.LoadObject('_sys_queries', ASource) = '' then Result := ADb.LoadFieldMetas(ASource)
  else Result := TFPObjectList.Create(True);
end;

function MetaOf(AMetas: TFPObjectList; const AField: string): TaFieldMeta;
var
  I: Integer;
begin
  for I := 0 to AMetas.Count - 1 do
    if SameText(TaFieldMeta(AMetas[I]).FieldName, AField) then Exit(TaFieldMeta(AMetas[I]));
  Result := nil;
end;

function CsvQuote(const S: string; ADelim: Char): string;
begin
  if (Pos(ADelim, S) > 0) or (Pos('"', S) > 0) or (Pos(#10, S) > 0) or (Pos(#13, S) > 0) then
    Result := '"' + StringReplace(S, '"', '""', [rfReplaceAll]) + '"'
  else
    Result := S;
end;

procedure ExportQueryCsv(ADb: TAppDb; Q: TZQuery; const AMetaSource, AFile: string; ADelim: Char);
var
  Metas: TFPObjectList;
  L: TStringList;
  Line, V, Bom: string;
  I: Integer;
  M: TaFieldMeta;
  F: TField;
  Fs: TFileStream;
begin
  Metas := SourceMetas(ADb, AMetaSource);
  L := TStringList.Create;
  try
    if not Q.Active then Q.Open;
    Q.First;
    Line := '';
    for I := 0 to Q.FieldCount - 1 do
    begin
      if I > 0 then Line := Line + ADelim;
      Line := Line + CsvQuote(Q.Fields[I].FieldName, ADelim);
    end;
    L.Add(Line);
    while not Q.EOF do
    begin
      Line := '';
      for I := 0 to Q.FieldCount - 1 do
      begin
        F := Q.Fields[I];
        M := MetaOf(Metas, F.FieldName);
        if F.IsNull then V := ''
        else
        begin
          V := FieldStored(F);
          if (M <> nil) and (M.LType in [ltDate, ltTime, ltDateTime]) then V := StoredToDisplay(M, V)
          else if (F.DataType in [ftFloat, ftCurrency, ftBCD, ftFMTBcd, ftSingle]) and (ADelim = ';') then
            V := StringReplace(V, '.', ',', []);
        end;
        if I > 0 then Line := Line + ADelim;
        Line := Line + CsvQuote(V, ADelim);
      end;
      L.Add(Line);
      Q.Next;
    end;
    Fs := TFileStream.Create(AFile, fmCreate);
    try
      Bom := #$EF#$BB#$BF;
      Fs.WriteBuffer(Bom[1], 3);
      V := L.Text;
      if V <> '' then Fs.WriteBuffer(V[1], Length(V));
    finally
      Fs.Free;
    end;
  finally
    L.Free;
    Metas.Free;
  end;
end;

procedure ExportCsv(ADb: TAppDb; const ASource, AFile: string; ADelim: Char);
var
  Q: TZQuery;
begin
  Q := ADb.NewQuery(ADb.SourceSql(ASource));
  try
    ExportQueryCsv(ADb, Q, ASource, AFile, ADelim);
  finally
    Q.Free;
  end;
end;

procedure ExportXlsx(ADb: TAppDb; const ASource, AFile: string);
var
  Q: TZQuery;
  Metas: TFPObjectList;
  Book: TsWorkbook;
  Sheet: TsWorksheet;
  I, R, P: Integer;
  F: TField;
  M: TaFieldMeta;
  D, T: TDateTime;
  S, DP, TP: string;
begin
  Q := ADb.NewQuery(ADb.SourceSql(ASource));
  Metas := SourceMetas(ADb, ASource);
  Book := TsWorkbook.Create;
  try
    Q.Open;
    Sheet := Book.AddWorksheet('Podaci');
    for I := 0 to Q.FieldCount - 1 do
    begin
      Sheet.WriteText(0, I, Q.Fields[I].FieldName);
      Sheet.WriteFontStyle(0, I, [fssBold]);
    end;
    R := 1;
    while not Q.EOF do
    begin
      for I := 0 to Q.FieldCount - 1 do
      begin
        F := Q.Fields[I];
        if F.IsNull then Continue;
        M := MetaOf(Metas, F.FieldName);
        S := FieldStored(F);
        if (M <> nil) and (M.LType in [ltDate, ltDateTime, ltTime]) then
        begin
          P := Pos(' ', S);
          if P > 0 then begin DP := Copy(S, 1, P - 1); TP := Copy(S, P + 1, MaxInt); end
          else if M.LType = ltTime then begin DP := ''; TP := S; end
          else begin DP := S; TP := ''; end;
          D := 0; T := 0;
          if (DP <> '') and not TryStrToDate(DP, D, 'yyyy-mm-dd', '-') then D := 0;
          if (TP <> '') and not TryStrToTime(TP, T) then T := 0;
          case M.LType of
            ltDate: Sheet.WriteDateTime(R, I, D, nfCustom, 'dd.mm.yyyy');
            ltTime: Sheet.WriteDateTime(R, I, T, nfCustom, 'hh:nn');
          else Sheet.WriteDateTime(R, I, D + T, nfCustom, 'dd.mm.yyyy hh:nn');
          end;
        end
        else if F.DataType in [ftSmallint, ftInteger, ftLargeint, ftWord, ftAutoInc, ftBoolean,
                               ftFloat, ftCurrency, ftBCD, ftFMTBcd, ftSingle] then
          Sheet.WriteNumber(R, I, F.AsFloat)
        else
          Sheet.WriteText(R, I, F.AsString);
      end;
      Inc(R);
      Q.Next;
    end;
    Book.WriteToFile(AFile, sfOOXML, True);
  finally
    Book.Free;
    Metas.Free;
    Q.Free;
  end;
end;

procedure ExportJson(ADb: TAppDb; const ASource, AFile: string);
var
  Q: TZQuery;
  L: TStringList;
  I: Integer;
  F: TField;
  Line, V: string;
  First: Boolean;
begin
  Q := ADb.NewQuery(ADb.SourceSql(ASource));
  L := TStringList.Create;
  try
    Q.Open;
    L.Add('[');
    First := True;
    while not Q.EOF do
    begin
      if not First then L[L.Count - 1] := L[L.Count - 1] + ',';
      First := False;
      L.Add('  {');
      for I := 0 to Q.FieldCount - 1 do
      begin
        F := Q.Fields[I];
        if F.IsNull then V := 'null'
        else if F.DataType in [ftSmallint, ftInteger, ftLargeint, ftWord, ftAutoInc] then
          V := IntToStr(F.AsLargeInt)
        else if F.DataType in [ftFloat, ftCurrency, ftBCD, ftFMTBcd, ftSingle] then
          V := FloatToStr(F.AsFloat, InvariantFS)
        else
          V := '"' + StringToJSONString(F.AsString) + '"';
        Line := '    "' + StringToJSONString(F.FieldName) + '": ' + V;
        if I < Q.FieldCount - 1 then Line := Line + ',';
        L.Add(Line);
      end;
      L.Add('  }');
      Q.Next;
    end;
    L.Add(']');
    L.SaveToFile(AFile);
  finally
    L.Free;
    Q.Free;
  end;
end;

end.
