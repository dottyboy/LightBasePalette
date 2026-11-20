unit ta_calendar;
{ Obitelj Calendar: izbor datuma. Varijante: month (TCalendar), range (isti prikaz, dva klika daju razdoblje
  "od..do") i agenda (popis idućih dana). Vrijednost je tekst u ISO obliku yyyy-mm-dd (razdoblje "a..b").
  Veza na polje: datum/datum-vrijeme ili tekst u ISO obliku. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, StdCtrls, Calendar, DateUtils, Graphics, Variants, DB, DBCtrls, ta_family, ta_formdef;

type
  TaCalendarVariant = (cmMonth, cmRange, cmAgenda);

const
  CalendarVariantNames: array[TaCalendarVariant] of string = ('month', 'range', 'agenda');
  CalendarFamily = 'Calendar';

type
  TaCalendarOptions = class(TPersistent)
  private
    FDays: Integer;
  public
    constructor Create;
    procedure Assign(ASource: TPersistent); override;
  published
    { agenda: koliko dana se nudi od danas }
    property Days: Integer read FDays write FDays default 14;
  end;

  TaCalendarMonthEngine = class(TaEngine)
  private
    FCal: TCalendar;
    FSetting: Boolean;
    procedure CalChange(Sender: TObject);
  public
    constructor Create(AHost: TaFamilyHost); override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
  end;

  TaCalendarRangeEngine = class(TaEngine)
  private
    FCal: TCalendar;
    FSetting: Boolean;
    FFrom, FTo: TDateTime;
    FWaitEnd: Boolean;
    procedure CalChange(Sender: TObject);
  public
    constructor Create(AHost: TaFamilyHost); override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
  end;

  TaCalendarAgendaEngine = class(TaEngine)
  private
    FBox: TListBox;
    FDates: array of TDateTime;
    FDays: Integer;
    FSetting: Boolean;
    procedure BoxSelect(Sender: TObject; User: Boolean);
    procedure Rebuild;
  public
    constructor Create(AHost: TaFamilyHost); override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
    procedure ApplyOptions(AOptions: TPersistent); override;
  end;

  TaCalendar = class(TaFamilyHost)
  private
    FVariant: TaCalendarVariant;
    FOptions: TaCalendarOptions;
    FText: string;
    FControlSource, FVisibleIf, FEnabledIf, FCondFormat, FExtra: string;
    FDataLink: TFieldDataLink;
    FUpdating, FSelfEdit: Boolean;
    function GetVariant: TaCalendarVariant;
    procedure SetVariant(AValue: TaCalendarVariant);
    function GetOptions: TaCalendarOptions;
    procedure SetOptions(AValue: TaCalendarOptions);
    function GetDataSource: TDataSource;
    procedure SetDataSource(AValue: TDataSource);
    function GetDataField: string;
    procedure SetDataField(const AValue: string);
    procedure DataChange(Sender: TObject);
    procedure UpdateData(Sender: TObject);
    procedure PushToEngine;
  protected
    function CreateEngine: TaEngine; override;
    procedure EngineChanged; override;
    function RealGetText: TCaption; override;
    procedure RealSetText(const AValue: TCaption); override;
    procedure Notification(AComponent: TComponent; AOperation: TOperation); override;
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function VariantName: string;
    { izabrani datum (month, agenda) ili pocetak razdoblja; 0 = nista }
    function SelectedDate: TDateTime;
    procedure SelectDate(ADate: TDateTime);
  published
    property Variant: TaCalendarVariant read GetVariant write SetVariant default cmMonth;
    { ISO datum yyyy-mm-dd, a za range "od..do" }
    property Text;
    property Options: TaCalendarOptions read GetOptions write SetOptions;
    property ControlSource: string read FControlSource write FControlSource;
    property VisibleIf: string read FVisibleIf write FVisibleIf;
    property EnabledIf: string read FEnabledIf write FEnabledIf;
    property CondFormat: string read FCondFormat write FCondFormat;
    property Extra: string read FExtra write FExtra;
    property DataSource: TDataSource read GetDataSource write SetDataSource;
    property DataField: string read GetDataField write SetDataField;
    property Align;
    property Anchors;
    property Enabled;
    property Visible;
    property Hint;
    property ShowHint;
    property TabOrder;
    property PopupMenu;
    property OnEnter;
    property OnExit;
  end;

function IsCalendarKind(const AKind: string): Boolean;
function CalendarVariantFromName(const AName: string; ADefault: TaCalendarVariant = cmMonth): TaCalendarVariant;
function CalendarFromDef(D: TaControlDef; AOwner: TComponent): TaCalendar;
procedure CalendarToDef(C: TaCalendar; D: TaControlDef);
function CalendarToLfm(C: TaCalendar): string;
function CalendarFromLfm(const ALfm: string; AOwner: TComponent): TaCalendar;

implementation

uses
  StrUtils, LResources;

function IsCalendarKind(const AKind: string): Boolean;
begin
  Result := SameText(AKind, 'Calendar');
end;

function CalendarVariantFromName(const AName: string; ADefault: TaCalendarVariant): TaCalendarVariant;
var
  V: TaCalendarVariant;
begin
  for V := Low(TaCalendarVariant) to High(TaCalendarVariant) do
    if SameText(CalendarVariantNames[V], AName) then Exit(V);
  Result := ADefault;
end;

function IsoOf(ADate: TDateTime): string;
begin
  Result := FormatDateTime('yyyy-mm-dd', ADate);
end;

function ParseIso(const S: string; out ADate: TDateTime): Boolean;
var
  Y, M, D: Word;
  T: string;
begin
  T := Trim(S);
  Result := False;
  if Length(T) < 10 then Exit;
  Y := StrToIntDef(Copy(T, 1, 4), 0);
  M := StrToIntDef(Copy(T, 6, 2), 0);
  D := StrToIntDef(Copy(T, 9, 2), 0);
  if (Y = 0) or (M = 0) or (D = 0) then Exit;
  Result := TryEncodeDate(Y, M, D, ADate);
end;

constructor TaCalendarOptions.Create;
begin
  inherited Create;
  FDays := 14;
end;

procedure TaCalendarOptions.Assign(ASource: TPersistent);
begin
  if ASource is TaCalendarOptions then FDays := TaCalendarOptions(ASource).FDays
  else inherited Assign(ASource);
end;

{ ---------------- pokretaci ---------------- }

constructor TaCalendarMonthEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FCal := TCalendar.Create(nil);
  FCal.OnChange := @CalChange;
  AttachInner(FCal);
end;

procedure TaCalendarMonthEngine.CalChange(Sender: TObject);
begin
  if FSetting then Exit;
  InnerChanged(Sender);
end;

function TaCalendarMonthEngine.GetText: string;
begin
  Result := IsoOf(FCal.DateTime);
end;

procedure TaCalendarMonthEngine.SetText(const AValue: string);
var
  D: TDateTime;
begin
  if not ParseIso(AValue, D) then Exit;
  FSetting := True;
  try
    FCal.DateTime := D;
  finally
    FSetting := False;
  end;
end;

constructor TaCalendarRangeEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FCal := TCalendar.Create(nil);
  FCal.OnChange := @CalChange;
  AttachInner(FCal);
end;

procedure TaCalendarRangeEngine.CalChange(Sender: TObject);
var
  D: TDateTime;
begin
  if FSetting then Exit;
  D := Trunc(FCal.DateTime);
  if not FWaitEnd then
  begin
    FFrom := D; FTo := D; FWaitEnd := True;
  end
  else
  begin
    if D < FFrom then begin FTo := FFrom; FFrom := D; end else FTo := D;
    FWaitEnd := False;
  end;
  InnerChanged(Sender);
end;

function TaCalendarRangeEngine.GetText: string;
begin
  if FFrom = 0 then Exit('');
  Result := IsoOf(FFrom) + '..' + IsoOf(FTo);
end;

procedure TaCalendarRangeEngine.SetText(const AValue: string);
var
  P: Integer;
  A, B: TDateTime;
begin
  P := Pos('..', AValue);
  if P > 0 then
  begin
    if not (ParseIso(Copy(AValue, 1, P - 1), A) and ParseIso(Copy(AValue, P + 2, MaxInt), B)) then Exit;
  end
  else if ParseIso(AValue, A) then B := A
  else begin FFrom := 0; FTo := 0; FWaitEnd := False; Exit; end;
  FFrom := A; FTo := B; FWaitEnd := False;
  FSetting := True;
  try
    FCal.DateTime := A;
  finally
    FSetting := False;
  end;
end;

constructor TaCalendarAgendaEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FDays := 14;
  FBox := TListBox.Create(nil);
  FBox.OnSelectionChange := @BoxSelect;
  AttachInner(FBox);
  Rebuild;
end;

procedure TaCalendarAgendaEngine.Rebuild;
var
  I: Integer;
  D: TDateTime;
begin
  SetLength(FDates, FDays);
  FSetting := True;
  try
    FBox.Items.Clear;
    for I := 0 to FDays - 1 do
    begin
      D := Trunc(Now) + I;
      FDates[I] := D;
      FBox.Items.Add(FormatDateTime('ddd dd.mm.yyyy', D));
    end;
  finally
    FSetting := False;
  end;
end;

procedure TaCalendarAgendaEngine.BoxSelect(Sender: TObject; User: Boolean);
begin
  if FSetting then Exit;
  InnerChanged(Sender);
end;

function TaCalendarAgendaEngine.GetText: string;
begin
  if (FBox.ItemIndex >= 0) and (FBox.ItemIndex < Length(FDates)) then Result := IsoOf(FDates[FBox.ItemIndex])
  else Result := '';
end;

procedure TaCalendarAgendaEngine.SetText(const AValue: string);
var
  D: TDateTime;
  I: Integer;
begin
  FSetting := True;
  try
    FBox.ItemIndex := -1;
    if ParseIso(AValue, D) then
      for I := 0 to High(FDates) do
        if Trunc(FDates[I]) = Trunc(D) then FBox.ItemIndex := I;
  finally
    FSetting := False;
  end;
end;

procedure TaCalendarAgendaEngine.ApplyOptions(AOptions: TPersistent);
var
  Keep: string;
begin
  if (AOptions is TaCalendarOptions) and (TaCalendarOptions(AOptions).Days > 0) and (TaCalendarOptions(AOptions).Days <> FDays) then
  begin
    Keep := GetText;
    FDays := TaCalendarOptions(AOptions).Days;
    Rebuild;
    SetText(Keep);
  end;
end;

{ ---------------- TaCalendar ---------------- }

constructor TaCalendar.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FDataLink := TFieldDataLink.Create;
  FDataLink.Control := Self;
  FDataLink.OnDataChange := @DataChange;
  FDataLink.OnUpdateData := @UpdateData;
  FOptions := TaCalendarOptions.Create;
  FVariant := cmMonth;
  Width := 230;
  Height := 170;
  ReplaceEngine;
  PushToEngine;
end;

destructor TaCalendar.Destroy;
begin
  FDataLink.OnDataChange := nil;
  FDataLink.OnUpdateData := nil;
  FDataLink.Free;
  FOptions.Free;
  inherited Destroy;
end;

function TaCalendar.CreateEngine: TaEngine;
var
  C: TaEngineClass;
begin
  C := FindEngine(CalendarFamily, CalendarVariantNames[FVariant]);
  if C = nil then C := FindEngine(CalendarFamily, 'month');
  Result := C.Create(Self);
end;

function TaCalendar.VariantName: string;
begin
  Result := CalendarVariantNames[FVariant];
end;

function TaCalendar.GetVariant: TaCalendarVariant;
begin
  Result := FVariant;
end;

procedure TaCalendar.SetVariant(AValue: TaCalendarVariant);
begin
  if AValue = FVariant then Exit;
  FText := RealGetText;
  FVariant := AValue;
  ReplaceEngine;
  PushToEngine;
end;

function TaCalendar.GetOptions: TaCalendarOptions;
begin
  Result := FOptions;
end;

procedure TaCalendar.SetOptions(AValue: TaCalendarOptions);
begin
  FOptions.Assign(AValue);
  if Engine <> nil then Engine.ApplyOptions(FOptions);
end;

procedure TaCalendar.PushToEngine;
begin
  if Engine = nil then Exit;
  FUpdating := True;
  try
    Engine.ApplyOptions(FOptions);
    if FText <> '' then Engine.SetText(FText);
  finally
    FUpdating := False;
  end;
end;

function TaCalendar.RealGetText: TCaption;
begin
  if Engine <> nil then Result := Engine.GetText else Result := FText;
end;

procedure TaCalendar.RealSetText(const AValue: TCaption);
begin
  FText := AValue;
  if Engine <> nil then
  begin
    FUpdating := True;
    try
      Engine.SetText(AValue);
    finally
      FUpdating := False;
    end;
  end;
end;

function TaCalendar.SelectedDate: TDateTime;
var
  S: string;
  P: Integer;
begin
  S := RealGetText;
  P := Pos('..', S);
  if P > 0 then S := Copy(S, 1, P - 1);
  if not ParseIso(S, Result) then Result := 0;
end;

procedure TaCalendar.SelectDate(ADate: TDateTime);
begin
  RealSetText(IsoOf(ADate));
end;

procedure TaCalendar.EngineChanged;
begin
  if FUpdating then Exit;
  if FDataLink.Active then
  begin
    FSelfEdit := True;
    try
      if FDataLink.Edit then FDataLink.Modified;
    finally
      FSelfEdit := False;
    end;
    try
      FDataLink.UpdateRecord;
    except
      FDataLink.Reset;
      raise;
    end;
  end;
  inherited EngineChanged;
end;

function TaCalendar.GetDataSource: TDataSource;
begin
  Result := FDataLink.DataSource;
end;

procedure TaCalendar.SetDataSource(AValue: TDataSource);
begin
  FDataLink.DataSource := AValue;
  if AValue <> nil then AValue.FreeNotification(Self);
end;

function TaCalendar.GetDataField: string;
begin
  Result := FDataLink.FieldName;
end;

procedure TaCalendar.SetDataField(const AValue: string);
begin
  FDataLink.FieldName := AValue;
end;

procedure TaCalendar.Notification(AComponent: TComponent; AOperation: TOperation);
begin
  inherited Notification(AComponent, AOperation);
  if (AOperation = opRemove) and (FDataLink <> nil) and (AComponent = FDataLink.DataSource) then
    FDataLink.DataSource := nil;
end;

procedure TaCalendar.Loaded;
begin
  inherited Loaded;
  PushToEngine;
end;

procedure TaCalendar.DataChange(Sender: TObject);
var
  F: TField;
begin
  if FSelfEdit then Exit;
  F := FDataLink.Field;
  FUpdating := True;
  try
    if (F = nil) or F.IsNull then Exit;
    if F.DataType in [ftDate, ftDateTime, ftTimeStamp] then Engine.SetText(IsoOf(F.AsDateTime))
    else Engine.SetText(F.AsString);
  finally
    FUpdating := False;
  end;
end;

procedure TaCalendar.UpdateData(Sender: TObject);
var
  F: TField;
  D: TDateTime;
begin
  F := FDataLink.Field;
  if F = nil then Exit;
  if not ParseIso(Engine.GetText, D) then Exit;
  if F.DataType in [ftDate, ftDateTime, ftTimeStamp] then F.AsDateTime := D
  else F.AsString := IsoOf(D);
end;

{ ---------------- definicija kontrole <-> komponenta ---------------- }

const
  OwnKeys = ',variant,tip,visibleIf,enabledIf,condFormat,days,';

function ExtraWithout(const AExtra: string): string;
var
  L: TStringList;
  I: Integer;
  K: string;
begin
  L := TStringList.Create;
  try
    L.Text := AExtra;
    for I := L.Count - 1 downto 0 do
    begin
      K := L.Names[I];
      if (K <> '') and (Pos(',' + K + ',', OwnKeys) > 0) then L.Delete(I);
    end;
    Result := Trim(L.Text);
  finally
    L.Free;
  end;
end;

function CalendarFromDef(D: TaControlDef; AOwner: TComponent): TaCalendar;
begin
  Result := TaCalendar.Create(AOwner);
  try
    Result.Name := D.Name;
    Result.SetBounds(D.Left, D.Top, D.Width, D.Height);
    Result.Variant := CalendarVariantFromName(D.GetX('variant'), cmMonth);
    Result.ControlSource := D.ControlSource;
    Result.Hint := D.GetX('tip');
    Result.VisibleIf := D.GetX('visibleIf');
    Result.EnabledIf := D.GetX('enabledIf');
    Result.CondFormat := D.GetX('condFormat');
    Result.Options.Days := StrToIntDef(D.GetX('days'), 14);
    Result.Options := Result.Options;
    Result.Extra := ExtraWithout(D.Extra);
  except
    Result.Free;
    raise;
  end;
end;

procedure CalendarToDef(C: TaCalendar; D: TaControlDef);
begin
  D.Kind := 'Calendar';
  D.Name := C.Name;
  D.Left := C.Left; D.Top := C.Top; D.Width := C.Width; D.Height := C.Height;
  D.ControlSource := C.ControlSource;
  D.Extra := C.Extra;
  D.SetX('variant', IfThen(C.Variant = cmMonth, '', C.VariantName));
  D.SetX('tip', C.Hint);
  D.SetX('visibleIf', C.VisibleIf);
  D.SetX('enabledIf', C.EnabledIf);
  D.SetX('condFormat', C.CondFormat);
  D.SetX('days', IfThen(C.Options.Days <> 14, IntToStr(C.Options.Days), ''));
end;

function CalendarToLfm(C: TaCalendar): string;
var
  M: TMemoryStream;
  L: TStringList;
begin
  M := TMemoryStream.Create;
  L := TStringList.Create;
  try
    WriteComponentAsTextToStream(M, C);
    M.Position := 0;
    L.LoadFromStream(M);
    Result := L.Text;
  finally
    L.Free;
    M.Free;
  end;
end;

type
  TCalendarLfmFinder = class
    procedure Find(Reader: TReader; const AClassName: string; var AClass: TComponentClass);
  end;

procedure TCalendarLfmFinder.Find(Reader: TReader; const AClassName: string; var AClass: TComponentClass);
begin
  if SameText(AClassName, 'TaCalendar') then AClass := TaCalendar;
end;

function CalendarFromLfm(const ALfm: string; AOwner: TComponent): TaCalendar;
var
  M: TMemoryStream;
  C: TComponent;
  F: TCalendarLfmFinder;
begin
  M := TMemoryStream.Create;
  try
    if ALfm <> '' then M.WriteBuffer(ALfm[1], Length(ALfm));
    M.Position := 0;
    C := nil;
    F := TCalendarLfmFinder.Create;
    try
      ReadComponentFromTextStream(M, C, @F.Find, AOwner);
    finally
      F.Free;
    end;
    Result := C as TaCalendar;
  finally
    M.Free;
  end;
end;

initialization
  RegisterClass(TaCalendar);
  RegisterEngine(CalendarFamily, 'month', TaCalendarMonthEngine);
  RegisterEngine(CalendarFamily, 'range', TaCalendarRangeEngine);
  RegisterEngine(CalendarFamily, 'agenda', TaCalendarAgendaEngine);

end.
