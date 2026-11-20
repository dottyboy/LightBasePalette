unit ta_rowsource;
{ Izvor zapisa neprekidne forme (poglavlje 20 plana): prozor zapisa iz tablice ili spremljenog upita, bez TDataSet-a.
  Citanje ide SELECT ... ORDER BY ... LIMIT/OFFSET, pa je isti trosak za 30 i za 3.000.000 zapisa.
  Pisanje je jedan zapis odjednom: BeginEdit/BeginNew -> SetValue... -> Post | Cancel; UPDATE/INSERT s parametrima,
  pa greske baze (NOT NULL, strani kljuc, jedinstvenost) dolaze kao poruka i red ostaje nespremljen.
  Uredivi su samo izvori koji su tablice (spremljeni upit je samo za citanje). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Variants, DB, ZDataset, ta_meta;

type
  TaRowCells = array of string;

  TaRowSource = class
  private
    FDb: TAppDb;
    FSource: string;
    FIsTable: Boolean;
    FKeyExpr: string;         { izraz kljuca: stupac PK ili rowid }
    FKeyField: string;
    FColumns: TStringList;
    FNumeric: TStringList;    { nazivi brojcanih stupaca }
    FLinkChild, FLinkValue: string;
    FFilter: string;
    FSortField: string;
    FSortDesc: Boolean;
    FWinStart: Integer;
    FWin: array of TaRowCells;
    FWinKeys: TStringList;
    FPending: TStringList;    { polje=vrijednost }
    FPendingKey: string;
    FEditing, FIsNew: Boolean;
    FPostedKey: string;
    FError: string;
    function FromSql: string;
    function WhereSql: string;
    function OrderSql: string;
    procedure LoadColumns;
    procedure BindLink(Q: TZQuery);
  public
    property Db: TAppDb read FDb;
    constructor Create(ADb: TAppDb; const ASource: string);
    destructor Destroy; override;
    { veza glavna-detalj: stupac djeteta = vrijednost; prazna vrijednost = nema zapisa }
    procedure SetLink(const AChildField, AValue: string);
    procedure SetFilter(const AWhere: string);
    function ColumnIsNumeric(const AField: string): Boolean;
    { SQL uvjet iz teksta koji je korisnik upisao u filtar zaglavlja; '' ako je tekst prazan.
      Broj: 100, >100, >=100, <>5, 10..20; tekst: sadrzi (* je zamjenski znak), =tocno }
    function FilterClause(const AField, AText: string): string;
    procedure SetSort(const AField: string; ADescending: Boolean);
    function Count: Integer;
    { puni prozor: AOffset, ACount zapisa }
    procedure Fetch(AOffset, ACount: Integer);
    function InWindow(AAbsRow: Integer): Boolean;
    { vrijednost polja u apsolutnom retku (ako je izvan prozora, prozor se pomakne) }
    function Value(AAbsRow: Integer; const AField: string): string;
    function KeyOf(AAbsRow: Integer): string;
    { apsolutni redak zapisa s tim kljucem ili -1 }
    function IndexOfKey(const AKey: string): Integer;
    { uredivanje }
    function BeginEdit(AAbsRow: Integer): Boolean;
    function BeginNew: Boolean;
    procedure SetValue(const AField, AValue: string);
    function Pending(const AField: string): string;
    function HasPending(const AField: string): Boolean;
    function Post: Boolean;
    procedure Cancel;
    function Delete(AAbsRow: Integer): Boolean;
    { SUM/COUNT/AVG/MIN/MAX nad istim izvorom, filtrom i vezom; AField '*' za COUNT }
    function Aggregate(const AFunc, AField: string): string;
    property Columns: TStringList read FColumns;
    property CanEdit: Boolean read FIsTable;
    property KeyField: string read FKeyField;
    property LinkChild: string read FLinkChild;
    property WindowStart: Integer read FWinStart;
    property Editing: Boolean read FEditing;
    property IsNew: Boolean read FIsNew;
    property PostedKey: string read FPostedKey;
    property Error: string read FError;
  end;

implementation

constructor TaRowSource.Create(ADb: TAppDb; const ASource: string);
var
  T: TStringList;
begin
  FDb := ADb;
  FSource := ASource;
  FColumns := TStringList.Create;
  FNumeric := TStringList.Create;
  FWinKeys := TStringList.Create;
  FPending := TStringList.Create;
  FIsTable := False;
  T := FDb.UserTables;
  try
    FIsTable := T.IndexOf(ASource) >= 0;
  finally
    T.Free;
  end;
  if FIsTable then
  begin
    FKeyField := FDb.PrimaryKeyOf(ASource);
    if FKeyField <> '' then FKeyExpr := FDb.QuoteId(FKeyField)
    else FKeyExpr := FDb.RowIdSql(ASource);
    if FKeyExpr = '' then FIsTable := False;
  end;
  if FKeyExpr = '' then FKeyExpr := '1';
  LoadColumns;
end;

destructor TaRowSource.Destroy;
begin
  FColumns.Free;
  FNumeric.Free;
  FWinKeys.Free;
  FPending.Free;
  inherited Destroy;
end;

function TaRowSource.FromSql: string;
begin
  Result := FDb.SourceFrom(FSource);
end;

function TaRowSource.WhereSql: string;
begin
  Result := '';
  if FLinkChild <> '' then Result := FDb.QuoteId(FLinkChild) + ' = :lnk';
  if Trim(FFilter) <> '' then
  begin
    if Result <> '' then Result := Result + ' AND ';
    Result := Result + '(' + FFilter + ')';
  end;
  if Result <> '' then Result := ' WHERE ' + Result;
end;

function TaRowSource.OrderSql: string;
begin
  Result := '';
  if FSortField <> '' then
  begin
    Result := FDb.QuoteId(FSortField);
    if FSortDesc then Result := Result + ' DESC';
    Result := Result + ', ';
  end;
  Result := ' ORDER BY ' + Result + FKeyExpr;
end;

procedure TaRowSource.BindLink(Q: TZQuery);
begin
  if FLinkChild <> '' then Q.ParamByName('lnk').AsString := FLinkValue;
end;

procedure TaRowSource.LoadColumns;
var
  Q: TZQuery;
  I: Integer;
begin
  FColumns.Clear;
  Inc(FDb.QuietParams);
  try
    Q := FDb.NewQuery('SELECT * FROM ' + FromSql + ' LIMIT 1');
    try
      Q.Open;
      for I := 0 to Q.FieldCount - 1 do
      begin
        FColumns.Add(Q.Fields[I].FieldName);
        if Q.Fields[I].DataType in [ftSmallint, ftInteger, ftLargeint, ftWord, ftAutoInc, ftFloat, ftCurrency, ftBCD, ftFMTBcd, ftSingle] then
          FNumeric.Add(Q.Fields[I].FieldName);
      end;
    finally
      Q.Free;
    end;
  finally
    Dec(FDb.QuietParams);
  end;
end;

procedure TaRowSource.SetLink(const AChildField, AValue: string);
begin
  FLinkChild := AChildField;
  FLinkValue := AValue;
  FWinStart := -1;
  SetLength(FWin, 0);
end;

procedure TaRowSource.SetFilter(const AWhere: string);
begin
  FFilter := AWhere;
  FWinStart := -1;
  SetLength(FWin, 0);
end;

function TaRowSource.ColumnIsNumeric(const AField: string): Boolean;
begin
  Result := FNumeric.IndexOf(AField) >= 0;
end;

function TaRowSource.FilterClause(const AField, AText: string): string;
var
  T, Op, A, B: string;
  P: Integer;
  F: Double;
  Col: string;

  function Num(const S: string; out V: Double): Boolean;
  begin
    Result := TryStrToFloat(StringReplace(Trim(S), ',', '.', []), V, DefaultFormatSettings);
  end;

  function Lit(V: Double): string;
  begin
    Result := StringReplace(FloatToStr(V, DefaultFormatSettings), ',', '.', []);
  end;

begin
  Result := '';
  T := Trim(AText);
  if T = '' then Exit;
  if FColumns.IndexOf(AField) < 0 then Exit;
  Col := FDb.QuoteId(AField);
  if ColumnIsNumeric(AField) then
  begin
    P := Pos('..', T);
    if P > 0 then
    begin
      if Num(Copy(T, 1, P - 1), F) and Num(Copy(T, P + 2, MaxInt), F) then
      begin
        Num(Copy(T, 1, P - 1), F);
        A := Lit(F);
        Num(Copy(T, P + 2, MaxInt), F);
        B := Lit(F);
        Exit(Col + ' BETWEEN ' + A + ' AND ' + B);
      end;
      Exit('1 = 0');
    end;
    Op := '=';
    if Copy(T, 1, 2) = '>=' then begin Op := '>='; T := Copy(T, 3, MaxInt); end
    else if Copy(T, 1, 2) = '<=' then begin Op := '<='; T := Copy(T, 3, MaxInt); end
    else if Copy(T, 1, 2) = '<>' then begin Op := '<>'; T := Copy(T, 3, MaxInt); end
    else if Copy(T, 1, 1) = '>' then begin Op := '>'; T := Copy(T, 2, MaxInt); end
    else if Copy(T, 1, 1) = '<' then begin Op := '<'; T := Copy(T, 2, MaxInt); end
    else if Copy(T, 1, 1) = '=' then T := Copy(T, 2, MaxInt);
    if Num(T, F) then Result := Col + ' ' + Op + ' ' + Lit(F)
    else Result := '1 = 0';
    Exit;
  end;
  { tekst: = tocno, inace sadrzi }
  if Copy(T, 1, 1) = '=' then
    Result := 'LOWER(' + Col + ') = LOWER(' + FDb.QuoteLit(Copy(T, 2, MaxInt)) + ')'
  else
  begin
    A := StringReplace(T, '*', '%', [rfReplaceAll]);
    if Pos('%', A) = 0 then A := '%' + A + '%';
    Result := 'LOWER(' + Col + ') LIKE LOWER(' + FDb.QuoteLit(A) + ')';
  end;
end;

procedure TaRowSource.SetSort(const AField: string; ADescending: Boolean);
begin
  FSortField := AField;
  FSortDesc := ADescending;
  FWinStart := -1;
  SetLength(FWin, 0);
end;

function TaRowSource.Count: Integer;
var
  Q: TZQuery;
begin
  Result := 0;
  { veza bez vrijednosti = nema zapisa (npr. glavni zapis jos ne postoji) }
  if (FLinkChild <> '') and (FLinkValue = '') and not FEditing then Exit;
  Inc(FDb.QuietParams);
  Q := FDb.NewQuery('SELECT COUNT(*) FROM ' + FromSql + WhereSql);
  Dec(FDb.QuietParams);
  try
    BindLink(Q);
    Q.Open;
    Result := Q.Fields[0].AsInteger;
  finally
    Q.Free;
  end;
end;

procedure TaRowSource.Fetch(AOffset, ACount: Integer);
var
  Q: TZQuery;
  I, N: Integer;
begin
  if AOffset < 0 then AOffset := 0;
  FWinStart := AOffset;
  SetLength(FWin, 0);
  FWinKeys.Clear;
  if (FLinkChild <> '') and (FLinkValue = '') then Exit;
  Inc(FDb.QuietParams);
  Q := FDb.NewQuery('SELECT ' + FKeyExpr + ' AS __k, * FROM ' + FromSql + WhereSql + OrderSql +
    ' LIMIT ' + IntToStr(ACount) + ' OFFSET ' + IntToStr(AOffset));
  Dec(FDb.QuietParams);
  try
    BindLink(Q);
    Q.Open;
    N := 0;
    while not Q.EOF do
    begin
      SetLength(FWin, N + 1);
      SetLength(FWin[N], FColumns.Count);
      FWinKeys.Add(Q.Fields[0].AsString);
      for I := 0 to FColumns.Count - 1 do
        if Q.FieldByName(FColumns[I]).IsNull then FWin[N][I] := ''
        else FWin[N][I] := Q.FieldByName(FColumns[I]).AsString;
      Inc(N);
      Q.Next;
    end;
  finally
    Q.Free;
  end;
end;

function TaRowSource.InWindow(AAbsRow: Integer): Boolean;
begin
  Result := (FWinStart >= 0) and (AAbsRow >= FWinStart) and (AAbsRow < FWinStart + Length(FWin));
end;

function TaRowSource.Value(AAbsRow: Integer; const AField: string): string;
var
  C: Integer;
begin
  Result := '';
  if not InWindow(AAbsRow) then Fetch(AAbsRow, 60);
  if not InWindow(AAbsRow) then Exit;
  C := FColumns.IndexOf(AField);
  if C >= 0 then Result := FWin[AAbsRow - FWinStart][C];
end;

function TaRowSource.KeyOf(AAbsRow: Integer): string;
begin
  Result := '';
  if not InWindow(AAbsRow) then Fetch(AAbsRow, 60);
  if InWindow(AAbsRow) then Result := FWinKeys[AAbsRow - FWinStart];
end;

function TaRowSource.IndexOfKey(const AKey: string): Integer;
var
  Q: TZQuery;
  N: Integer;
begin
  Result := -1;
  if (FLinkChild <> '') and (FLinkValue = '') then Exit;
  Inc(FDb.QuietParams);
  Q := FDb.NewQuery('SELECT ' + FKeyExpr + ' AS __k FROM ' + FromSql + WhereSql + OrderSql);
  Dec(FDb.QuietParams);
  try
    BindLink(Q);
    Q.Open;
    N := 0;
    while not Q.EOF do
    begin
      if Q.Fields[0].AsString = AKey then Exit(N);
      Inc(N);
      Q.Next;
    end;
  finally
    Q.Free;
  end;
end;

function TaRowSource.BeginEdit(AAbsRow: Integer): Boolean;
begin
  FError := '';
  Result := False;
  if not FIsTable then begin FError := 'Izvor je samo za čitanje'; Exit; end;
  if FEditing then begin FError := 'Prethodni red nije spremljen'; Exit; end;
  FPendingKey := KeyOf(AAbsRow);
  if FPendingKey = '' then begin FError := 'Zapis ne postoji'; Exit; end;
  FPending.Clear;
  FEditing := True;
  FIsNew := False;
  Result := True;
end;

function TaRowSource.BeginNew: Boolean;
begin
  FError := '';
  Result := False;
  if not FIsTable then begin FError := 'Izvor je samo za čitanje'; Exit; end;
  if FEditing then begin FError := 'Prethodni red nije spremljen'; Exit; end;
  FPending.Clear;
  FPendingKey := '';
  FEditing := True;
  FIsNew := True;
  if FLinkChild <> '' then FPending.Values[FLinkChild] := FLinkValue;
  Result := True;
end;

procedure TaRowSource.SetValue(const AField, AValue: string);
var
  I: Integer;
begin
  { ime polja mora biti stupac izvora }
  if FColumns.IndexOf(AField) < 0 then Exit;
  I := FPending.IndexOfName(AField);
  if I >= 0 then FPending.ValueFromIndex[I] := AValue
  else FPending.Add(AField + '=' + AValue);
end;

function TaRowSource.Pending(const AField: string): string;
begin
  Result := FPending.Values[AField];
end;

function TaRowSource.HasPending(const AField: string): Boolean;
begin
  Result := FPending.IndexOfName(AField) >= 0;
end;

function TaRowSource.Post: Boolean;
var
  Q: TZQuery;
  Sql, Cols, Vals: string;
  I: Integer;
  L: TZQuery;
begin
  Result := False;
  FError := '';
  FPostedKey := '';
  if not FEditing then begin Result := True; Exit; end;
  try
    if FIsNew then
    begin
      Cols := '';
      Vals := '';
      for I := 0 to FPending.Count - 1 do
      begin
        if Cols <> '' then begin Cols := Cols + ', '; Vals := Vals + ', '; end;
        Cols := Cols + FDb.QuoteId(FPending.Names[I]);
        Vals := Vals + ':p' + IntToStr(I);
      end;
      if Cols = '' then Sql := 'INSERT INTO ' + FDb.QuoteId(FSource) + ' DEFAULT VALUES'
      else Sql := 'INSERT INTO ' + FDb.QuoteId(FSource) + ' (' + Cols + ') VALUES (' + Vals + ')';
    end
    else
    begin
      Cols := '';
      for I := 0 to FPending.Count - 1 do
      begin
        if Cols <> '' then Cols := Cols + ', ';
        Cols := Cols + FDb.QuoteId(FPending.Names[I]) + ' = :p' + IntToStr(I);
      end;
      if Cols = '' then begin FEditing := False; Exit(True); end;
      Sql := 'UPDATE ' + FDb.QuoteId(FSource) + ' SET ' + Cols + ' WHERE ' + FKeyExpr + ' = :k';
    end;
    Inc(FDb.QuietParams);
    Q := FDb.NewQuery(Sql);
    Dec(FDb.QuietParams);
    try
      for I := 0 to FPending.Count - 1 do
        if FPending.ValueFromIndex[I] = '' then Q.ParamByName('p' + IntToStr(I)).Value := Null
        else Q.ParamByName('p' + IntToStr(I)).AsString := FPending.ValueFromIndex[I];
      if not FIsNew then Q.ParamByName('k').AsString := FPendingKey;
      Q.ExecSQL;
    finally
      Q.Free;
    end;
    if FIsNew then
    begin
      if FKeyField <> '' then FPostedKey := FPending.Values[FKeyField];
      if FPostedKey = '' then
      begin
        { kljuc koji je dala baza: najveci kljuc koji je upravo nastao }
        L := FDb.NewQuery('SELECT MAX(' + FKeyExpr + ') FROM ' + FDb.QuoteId(FSource));
        try
          L.Open;
          FPostedKey := L.Fields[0].AsString;
        finally
          L.Free;
        end;
      end;
    end
    else FPostedKey := FPendingKey;
    FEditing := False;
    FIsNew := False;
    FWinStart := -1;
    SetLength(FWin, 0);
    Result := True;
  except
    on E: Exception do FError := E.Message;
  end;
end;

procedure TaRowSource.Cancel;
begin
  FPending.Clear;
  FEditing := False;
  FIsNew := False;
  FError := '';
end;

function TaRowSource.Delete(AAbsRow: Integer): Boolean;
var
  K: string;
  Q: TZQuery;
begin
  Result := False;
  FError := '';
  if not FIsTable then begin FError := 'Izvor je samo za čitanje'; Exit; end;
  K := KeyOf(AAbsRow);
  if K = '' then begin FError := 'Zapis ne postoji'; Exit; end;
  try
    Inc(FDb.QuietParams);
    Q := FDb.NewQuery('DELETE FROM ' + FDb.QuoteId(FSource) + ' WHERE ' + FKeyExpr + ' = :k');
    Dec(FDb.QuietParams);
    try
      Q.ParamByName('k').AsString := K;
      Q.ExecSQL;
    finally
      Q.Free;
    end;
    FWinStart := -1;
    SetLength(FWin, 0);
    Result := True;
  except
    on E: Exception do FError := E.Message;
  end;
end;

function TaRowSource.Aggregate(const AFunc, AField: string): string;
var
  Q: TZQuery;
  F, Arg: string;
begin
  Result := '';
  F := UpperCase(AFunc);
  if (F <> 'SUM') and (F <> 'COUNT') and (F <> 'AVG') and (F <> 'MIN') and (F <> 'MAX') then Exit;
  if AField = '*' then Arg := '*'
  else
  begin
    if FColumns.IndexOf(AField) < 0 then Exit;
    Arg := FDb.QuoteId(AField);
  end;
  if (FLinkChild <> '') and (FLinkValue = '') then
  begin
    if F = 'COUNT' then Result := '0';
    Exit;
  end;
  Inc(FDb.QuietParams);
  Q := FDb.NewQuery('SELECT ' + F + '(' + Arg + ') FROM ' + FromSql + WhereSql);
  Dec(FDb.QuietParams);
  try
    BindLink(Q);
    Q.Open;
    if not Q.Fields[0].IsNull then Result := Q.Fields[0].AsString;
  finally
    Q.Free;
  end;
end;

end.
