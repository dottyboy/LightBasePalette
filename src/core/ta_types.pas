unit ta_types;
{ Logical field types on top of SQLite's loose typing. A field keeps its
  logical type, display format, decimals and default expression in the
  _sys_fields table. Values are stored in a fixed, sortable form:
    Date     yyyy-mm-dd         Time      hh:nn:ss
    DateTime yyyy-mm-dd hh:nn:ss
    Decimal/Currency  REAL (rounded to Decimals)   YesNo  0/1 }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Variants, Math, DB, contnrs, DateUtils, ta_expr, ta_parse;

type
  TaLogicalType = (ltText, ltMemo, ltInteger, ltDecimal, ltCurrency, ltYesNo,
    ltDate, ltTime, ltDateTime, ltAutoNumber, ltPicture);

  TaFieldMeta = class
  public
    TableName, FieldName: string;
    LType: TaLogicalType;
    Format, DefaultExpr: string;
    Validation, ValidationMsg: string;   { expression using [value]/the field name; message on failure }
    Decimals: Integer;
    { rjecnik podataka: nasljeduju ih forme, izvjesca i mreze }
    Caption, Description: string;
    ColWidth: Integer;                   { sirina stupca u mrezi u pikselima, 0 = automatski }
    { dodatna svojstva rjecnika kao retci key=value: required, readonly, align, variant, rowsource, lov, lovmap, class,
      autoenter (vidi ta_dict); nepoznati kljucevi se cuvaju }
    Extra: string;
    constructor Create;
    function Clone: TaFieldMeta;
    function GetX(const AKey: string): string;
    procedure SetX(const AKey, AValue: string);
  end;

const
  LogicalNames: array[TaLogicalType] of string = (
    'Text', 'Memo', 'Integer', 'Decimal', 'Currency', 'YesNo', 'Date', 'Time',
    'DateTime', 'AutoNumber', 'Picture');

type
  { lets a default like Nz(DMax("id", "racuni", ""), 0) + 1 reach the database }
  TDomainFunc = function(const AFunc, AExpr, ADomain, ACriteria: string): Variant;

var
  { Stored form uses '.' as decimal separator whatever the locale is. }
  InvariantFS: TFormatSettings;
  DefaultDomainHook: TDomainFunc = nil;

function LogicalFromName(const S: string): TaLogicalType;
function PhysicalType(T: TaLogicalType): string;
function DefaultFormat(T: TaLogicalType; ADecimals: Integer): string;
function IsNumericType(T: TaLogicalType): Boolean;

function StoredToDisplay(M: TaFieldMeta; const AStored: string): string;
function DisplayToStored(M: TaFieldMeta; const AText: string; out AStored: string): Boolean;
function EvalDefault(M: TaFieldMeta): string;   { stored form, '' when none }

{ Field <-> invariant stored string (floats are not locale dependent). }
function FieldStored(F: TField): string;
procedure SetFieldStored(F: TField; const AStored: string);

{ Hooks a dataset so that fields show/accept their display format and new
  records get default values. }
type
  TaFieldFmt = class
  public
    Meta: TaFieldMeta;
    procedure GetText(Sender: TField; var AText: string; ADisplayText: Boolean);
    procedure SetText(Sender: TField; const AText: string);
  end;

  { shows a foreign key as the name of the row it points at, accepts the name back }
  TaLookupFmt = class
  public
    Keys, Labels: TStringList;
    constructor Create;
    destructor Destroy; override;
    procedure GetText(Sender: TField; var AText: string; ADisplayText: Boolean);
    procedure SetText(Sender: TField; const AText: string);
  end;

  TaDatasetFormatter = class
  private
    FDataSet: TDataSet;
    FFmts: TFPObjectList;
    FMetas: TFPObjectList;
  public
    procedure NewRecord(DataSet: TDataSet);
    constructor Create(ADataSet: TDataSet; AMetas: TFPObjectList);
    destructor Destroy; override;
  end;

implementation

uses
  ta_i18n;


{ TaFieldMeta }

constructor TaFieldMeta.Create;
begin
  Decimals := 2;
end;

function TaFieldMeta.Clone: TaFieldMeta;
begin
  Result := TaFieldMeta.Create;
  Result.TableName := TableName;
  Result.FieldName := FieldName;
  Result.LType := LType;
  Result.Format := Format;
  Result.DefaultExpr := DefaultExpr;
  Result.Validation := Validation;
  Result.ValidationMsg := ValidationMsg;
  Result.Decimals := Decimals;
  Result.Caption := Caption;
  Result.Description := Description;
  Result.ColWidth := ColWidth;
  Result.Extra := Extra;
end;

function TaFieldMeta.GetX(const AKey: string): string;
var
  L: TStringList;
begin
  L := TStringList.Create;
  try
    L.Text := Extra;
    Result := L.Values[AKey];
  finally
    L.Free;
  end;
end;

procedure TaFieldMeta.SetX(const AKey, AValue: string);
var
  L: TStringList;
begin
  L := TStringList.Create;
  try
    L.Text := Extra;
    { vrijednost je u jednom retku }
    if AValue = '' then
    begin
      if L.IndexOfName(AKey) >= 0 then L.Delete(L.IndexOfName(AKey));
    end
    else L.Values[AKey] := StringReplace(StringReplace(AValue, #13, ' ', [rfReplaceAll]), #10, ' ', [rfReplaceAll]);
    Extra := Trim(L.Text);
  finally
    L.Free;
  end;
end;

function LogicalFromName(const S: string): TaLogicalType;
var
  T: TaLogicalType;
begin
  for T := Low(T) to High(T) do
    if SameText(LogicalNames[T], S) then Exit(T);
  Result := ltText;
end;

function PhysicalType(T: TaLogicalType): string;
begin
  case T of
    ltInteger, ltYesNo: Result := 'INTEGER';
    ltAutoNumber: Result := 'INTEGER';
    ltPicture: Result := 'TEXT';   { veza na datoteku, ne sadrzaj slike }
    ltDecimal, ltCurrency: Result := 'REAL';
  else
    Result := 'TEXT';
  end;
end;

function IsNumericType(T: TaLogicalType): Boolean;
begin
  Result := T in [ltInteger, ltDecimal, ltCurrency, ltAutoNumber];
end;

function DefaultFormat(T: TaLogicalType; ADecimals: Integer): string;
var
  Z: string;
begin
  Z := StringOfChar('0', ADecimals);
  case T of
    ltDate: Result := 'dd.mm.yyyy';
    ltTime: Result := 'hh:nn';
    ltDateTime: Result := 'dd.mm.yyyy hh:nn';
    ltDecimal: if ADecimals > 0 then Result := '0.' + Z else Result := '0';
    ltCurrency: if ADecimals > 0 then Result := '#,##0.' + Z + ' "€"' else Result := '#,##0 "€"';
  else
    Result := '';
  end;
end;

{ ---- stored <-> display ---- }

function StoredToDisplay(M: TaFieldMeta; const AStored: string): string;
var
  D, Tm: TDateTime;
  V: Double;
  Fmt, DP, TP: string;
begin
  Result := AStored;
  if (M = nil) or (AStored = '') then Exit;
  Fmt := M.Format;
  if Fmt = '' then Fmt := DefaultFormat(M.LType, M.Decimals);
  case M.LType of
    ltDate:
      if ParseDatePart(AStored, D) then Result := FormatDateTime(Fmt, D);
    ltTime:
      if ParseTimePart(AStored, Tm) then Result := FormatDateTime(Fmt, Tm);
    ltDateTime:
      begin
        SplitDateTime(AStored, DP, TP);
        if ParseDatePart(DP, D) then
        begin
          if (TP <> '') and ParseTimePart(TP, Tm) then D := D + Tm;
          Result := FormatDateTime(Fmt, D);
        end;
      end;
    ltDecimal, ltCurrency:
      if TryStrToFloat(AStored, V, InvariantFS) then Result := FormatFloat(Fmt, V);
    ltInteger:
      if (Fmt <> '') and TryStrToFloat(AStored, V, InvariantFS) then Result := FormatFloat(Fmt, V);
    ltYesNo:
      if (AStored = '1') or SameText(AStored, 'true') then Result := 'Da' else Result := 'Ne';
  end;
end;

function DisplayToStored(M: TaFieldMeta; const AText: string; out AStored: string): Boolean;
var
  D, Tm: TDateTime;
  V: Double;
  T, DP, TP, L: string;
begin
  AStored := AText;
  Result := True;
  T := Trim(AText);
  if M = nil then Exit;
  if T = '' then begin AStored := ''; Exit; end;
  case M.LType of
    ltDate:
      begin
        Result := ParseDatePart(T, D);
        if Result then AStored := FormatDateTime('yyyy-mm-dd', D);
      end;
    ltTime:
      begin
        Result := ParseTimePart(T, Tm);
        if Result then AStored := FormatDateTime('hh:nn:ss', Tm);
      end;
    ltDateTime:
      begin
        SplitDateTime(T, DP, TP);
        Result := ParseDatePart(DP, D);
        if Result then
        begin
          if TP <> '' then
          begin
            Result := ParseTimePart(TP, Tm);
            if Result then D := D + Tm;
          end;
          if Result then AStored := FormatDateTime('yyyy-mm-dd hh:nn:ss', D);
        end;
      end;
    ltDecimal, ltCurrency:
      begin
        Result := ParseNumber(T, V);
        if Result then AStored := FloatToStr(RoundTo(V, -M.Decimals), InvariantFS);
      end;
    ltInteger, ltAutoNumber:
      begin
        Result := ParseNumber(T, V);
        if Result then AStored := IntToStr(Round(V));
      end;
    ltYesNo:
      begin
        L := LowerCase(T);
        if (L = '1') or (L = 'da') or (L = 'true') or (L = 'yes') or (L = 'x') or (L = 'd') then AStored := '1'
        else if (L = '0') or (L = 'ne') or (L = 'false') or (L = 'no') or (L = 'n') then AStored := '0'
        else Result := False;
      end;
  end;
end;

type
  { Host for default expressions: no fields, only date/time variables. }
  TDefaultHost = class(TaExprHost)
  public
    function FieldValue(const AName: string): Variant; override;
    function Aggregate(const AFunc, AField: string): Variant; override;
    function Variable(const AName: string): Variant; override;
    function Domain(const AFunc, AExpr, ADomain, ACriteria: string): Variant; override;
  end;

function TDefaultHost.FieldValue(const AName: string): Variant;
begin
  Result := Null;
end;

function TDefaultHost.Aggregate(const AFunc, AField: string): Variant;
begin
  Result := Null;
end;

function TDefaultHost.Domain(const AFunc, AExpr, ADomain, ACriteria: string): Variant;
begin
  if Assigned(DefaultDomainHook) then Result := DefaultDomainHook(AFunc, AExpr, ADomain, ACriteria)
  else Result := Null;
end;

function TDefaultHost.Variable(const AName: string): Variant;
var
  N: string;
begin
  N := LowerCase(AName);
  if (N = 'today') or (N = 'date') then Result := VarFromDateTime(Date)
  else if N = 'now' then Result := VarFromDateTime(Now)
  else if N = 'time' then Result := VarFromDateTime(Frac(Now))
  else if N = 'year' then Result := YearOf(Date)
  else Result := Null;
end;

function EvalDefault(M: TaFieldMeta): string;
var
  H: TDefaultHost;
  E, Stored: string;
  V: Variant;
begin
  Result := '';
  if (M = nil) or (Trim(M.DefaultExpr) = '') then Exit;
  E := Trim(M.DefaultExpr);
  if E[1] = '=' then E := Trim(Copy(E, 2, MaxInt));
  H := TDefaultHost.Create;
  try
    V := EvalExpr(E, H);
  finally
    H.Free;
  end;
  if VarIsNull(V) then Exit;
  if VarType(V) = varDate then
  begin
    case M.LType of
      ltDate: Result := FormatDateTime('yyyy-mm-dd', V);
      ltTime: Result := FormatDateTime('hh:nn:ss', V);
    else
      Result := FormatDateTime('yyyy-mm-dd hh:nn:ss', V);
    end;
  end
  else if VarIsNumeric(V) then
  begin
    if DisplayToStored(M, FloatToStr(Double(V), InvariantFS), Stored) then Result := Stored
    else Result := FloatToStr(Double(V), InvariantFS);
  end
  else
  begin
    E := VarToStr(V);
    if E = '#Err' then E := Trim(M.DefaultExpr);   { not an expression: literal }
    if DisplayToStored(M, E, Stored) then Result := Stored else Result := E;
  end;
end;

{ ---- dataset glue ---- }

function FieldStored(F: TField): string;
begin
  if F.IsNull then Exit('');
  if F.DataType in [ftFloat, ftCurrency, ftBCD, ftFMTBcd, ftSingle, ftExtended] then
    Result := FloatToStr(F.AsFloat, InvariantFS)
  else if F.DataType = ftBoolean then
  begin
    if F.AsBoolean then Result := '1' else Result := '0';
  end
  else
    Result := F.AsString;
end;

procedure SetFieldStored(F: TField; const AStored: string);
var
  V: Double;
begin
  if AStored = '' then F.Clear
  else if F.DataType in [ftFloat, ftCurrency, ftBCD, ftFMTBcd, ftSingle, ftExtended] then
  begin
    if TryStrToFloat(AStored, V, InvariantFS) then F.AsFloat := V else F.AsString := AStored;
  end
  else if F.DataType = ftBoolean then F.AsBoolean := (AStored = '1')
  else F.AsString := AStored;
end;

constructor TaLookupFmt.Create;
begin
  Keys := TStringList.Create;
  Labels := TStringList.Create;
end;

destructor TaLookupFmt.Destroy;
begin
  Keys.Free;
  Labels.Free;
  inherited Destroy;
end;

procedure TaLookupFmt.GetText(Sender: TField; var AText: string; ADisplayText: Boolean);
var
  I: Integer;
begin
  if Sender.IsNull then begin AText := ''; Exit; end;
  I := Keys.IndexOf(FieldStored(Sender));
  if I >= 0 then AText := Labels[I] else AText := Sender.AsString;
end;

procedure TaLookupFmt.SetText(Sender: TField; const AText: string);
var
  I: Integer;
begin
  if Trim(AText) = '' then begin Sender.Clear; Exit; end;
  I := Labels.IndexOf(AText);
  if I < 0 then I := Keys.IndexOf(Trim(AText));    { typing the key itself also works }
  if I < 0 then raise Exception.Create(Tr('Unknown value: ') + AText);
  SetFieldStored(Sender, Keys[I]);
end;

procedure TaFieldFmt.GetText(Sender: TField; var AText: string; ADisplayText: Boolean);
begin
  if Sender.IsNull then AText := '' else AText := StoredToDisplay(Meta, FieldStored(Sender));
end;

procedure TaFieldFmt.SetText(Sender: TField; const AText: string);
var
  S: string;
begin
  if not DisplayToStored(Meta, AText, S) then
    raise Exception.Create(Tr('Invalid value for the field ') + Sender.FieldName + ': ' + AText);
  SetFieldStored(Sender, S);
end;

constructor TaDatasetFormatter.Create(ADataSet: TDataSet; AMetas: TFPObjectList);
var
  I, J: Integer;
  F: TField;
  Fm: TaFieldFmt;
  M: TaFieldMeta;
begin
  FDataSet := ADataSet;
  FFmts := TFPObjectList.Create(True);
  FMetas := AMetas;
  for I := 0 to FDataSet.FieldCount - 1 do
  begin
    F := FDataSet.Fields[I];
    for J := 0 to FMetas.Count - 1 do
    begin
      M := TaFieldMeta(FMetas[J]);
      if not SameText(M.FieldName, F.FieldName) then Continue;
      if M.LType in [ltDate, ltTime, ltDateTime, ltDecimal, ltCurrency, ltYesNo] then
      begin
        Fm := TaFieldFmt.Create;
        Fm.Meta := M;
        F.OnGetText := @Fm.GetText;
        F.OnSetText := @Fm.SetText;
        FFmts.Add(Fm);
      end;
      Break;
    end;
  end;
  FDataSet.OnNewRecord := @NewRecord;
end;

destructor TaDatasetFormatter.Destroy;
begin
  if FDataSet <> nil then FDataSet.OnNewRecord := nil;
  FFmts.Free;
  FMetas.Free;
  inherited Destroy;
end;

procedure TaDatasetFormatter.NewRecord(DataSet: TDataSet);
var
  I: Integer;
  M: TaFieldMeta;
  F: TField;
  S: string;
begin
  for I := 0 to FMetas.Count - 1 do
  begin
    M := TaFieldMeta(FMetas[I]);
    if M.DefaultExpr = '' then Continue;
    F := DataSet.FindField(M.FieldName);
    if F = nil then Continue;
    S := EvalDefault(M);
    if S <> '' then SetFieldStored(F, S);
  end;
end;

initialization
  InvariantFS := DefaultFormatSettings;
  InvariantFS.DecimalSeparator := '.';
  InvariantFS.ThousandSeparator := ',';
end.
