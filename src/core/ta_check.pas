unit ta_check;
{ Obitelj Check (poglavlje 3, 12): kvacica, prekidac (switch), radio i kvacica s tri stanja.
  Isti nacin kao Edit: domacin TaCheck, zamjenjivi pokretaci, Options po varijanti, veza na polje (TFieldDataLink),
  definicija kontrole <-> komponenta i .lfm. Vrijednost je Boolean, a kod tri stanja i Null ("nije odredeno"). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, StdCtrls, ExtCtrls, Graphics, Variants, DB, DBCtrls, LCLType, ta_family, ta_formdef;

type
  TaCheckVariant = (cvCheckbox, cvSwitch, cvRadio, cvTriState);

const
  CheckVariantNames: array[TaCheckVariant] of string = ('checkbox', 'switch', 'radio', 'tristate');
  CheckFamily = 'Check';

type
  TaCheckOptions = class(TPersistent)
  public
    constructor Create; virtual;
    procedure Assign(ASource: TPersistent); override;
  end;

  TaCheckOptionsClass = class of TaCheckOptions;

  { prekidac: natpisi koji se prikazuju umjesto naslova kad je ukljucen/iskljucen (prazno = naslov) }
  TaSwitchOptions = class(TaCheckOptions)
  private
    FOnCaption, FOffCaption: string;
  public
    procedure Assign(ASource: TPersistent); override;
  published
    property OnCaption: string read FOnCaption write FOnCaption;
    property OffCaption: string read FOffCaption write FOffCaption;
  end;

  { prekidac koji crta sam sebe: kliknuti, razmak }
  TaSwitchPaint = class(TCustomControl)
  private
    FChecked: Boolean;
    FCaption: string;
    FReadOnly: Boolean;
    FOnToggle: TNotifyEvent;
    procedure SetChecked(AValue: Boolean);
  protected
    procedure Paint; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure KeyUp(var Key: Word; Shift: TShiftState); override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Click; override;
    property Checked: Boolean read FChecked write SetChecked;
    property CaptionText: string read FCaption write FCaption;
    property ReadOnly: Boolean read FReadOnly write FReadOnly;
    property OnToggle: TNotifyEvent read FOnToggle write FOnToggle;
  end;

  TaCheckBoxEngine = class(TaEngine)
  private
    FBox: TCheckBox;
    FReadOnly, FSetting: Boolean;
    FPrev: TCheckBoxState;
    procedure BoxChange(Sender: TObject);
  protected
    function AllowsGrayed: Boolean; virtual;
  public
    constructor Create(AHost: TaFamilyHost); override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
    function GetValue: Variant; override;
    procedure SetValue(const AValue: Variant); override;
    procedure SetReadOnly(AValue: Boolean); override;
  end;

  TaCheckTriEngine = class(TaCheckBoxEngine)
  protected
    function AllowsGrayed: Boolean; override;
  end;

  TaCheckRadioEngine = class(TaEngine)
  private
    FRadio: TRadioButton;
    FReadOnly, FSetting: Boolean;
    FPrev: Boolean;
    procedure RadioChange(Sender: TObject);
  public
    constructor Create(AHost: TaFamilyHost); override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
    function GetValue: Variant; override;
    procedure SetValue(const AValue: Variant); override;
    procedure SetReadOnly(AValue: Boolean); override;
  end;

  TaCheckSwitchEngine = class(TaEngine)
  private
    FSw: TaSwitchPaint;
    FBase, FOn, FOff: string;
    procedure Toggled(Sender: TObject);
    procedure ShowCaption;
  public
    constructor Create(AHost: TaFamilyHost); override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
    function GetValue: Variant; override;
    procedure SetValue(const AValue: Variant); override;
    procedure SetReadOnly(AValue: Boolean); override;
    procedure ApplyOptions(AOptions: TPersistent); override;
  end;

  TaCheck = class(TaFamilyHost)
  private
    FVariant: TaCheckVariant;
    FOptions: array[TaCheckVariant] of TaCheckOptions;
    FText: string;
    FChecked: Boolean;
    FNull: Boolean;
    FReadOnly: Boolean;
    FControlSource, FVisibleIf, FEnabledIf, FCondFormat, FExtra: string;
    FDataLink: TFieldDataLink;
    FUpdating, FSelfEdit: Boolean;
    function GetVariant: TaCheckVariant;
    procedure SetVariant(AValue: TaCheckVariant);
    function GetOptions: TaCheckOptions;
    procedure SetOptions(AValue: TaCheckOptions);
    function OptionsClassFor(AVariant: TaCheckVariant): TaCheckOptionsClass;
    function OptionsStored: Boolean;
    procedure SetReadOnly(AValue: Boolean);
    function GetChecked: Boolean;
    procedure SetChecked(AValue: Boolean);
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
    procedure EngineExit; override;
    function RealGetText: TCaption; override;
    procedure RealSetText(const AValue: TCaption); override;
    procedure Notification(AComponent: TComponent; AOperation: TOperation); override;
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function VariantName: string;
    { Boolean ili Null (kvacica s tri stanja, nije odredeno) }
    function Value: System.Variant;
    procedure SetValue(const AValue: System.Variant);
    { kvacica s tri stanja: nije odredeno }
    function IsUndetermined: Boolean;
  published
    property Variant: TaCheckVariant read GetVariant write SetVariant default cvCheckbox;
    property Caption;
    property Checked: Boolean read GetChecked write SetChecked default False;
    property Options: TaCheckOptions read GetOptions write SetOptions stored OptionsStored;
    property ReadOnly: Boolean read FReadOnly write SetReadOnly default False;
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

{ definicija kontrole <-> komponenta: vrste 'Check' i 'CheckBox' }
function IsCheckKind(const AKind: string): Boolean;
function CheckVariantFromName(const AName: string; ADefault: TaCheckVariant = cvCheckbox): TaCheckVariant;
function CheckFromDef(D: TaControlDef; AOwner: TComponent): TaCheck;
procedure CheckToDef(C: TaCheck; D: TaControlDef);
{ tekst .lfm toka komponente i obrnuto }
function CheckToLfm(C: TaCheck): string;
function CheckFromLfm(const ALfm: string; AOwner: TComponent): TaCheck;

implementation

uses
  StrUtils, LResources, ta_tokens;

function IsCheckKind(const AKind: string): Boolean;
begin
  Result := SameText(AKind, 'Check') or SameText(AKind, 'CheckBox');
end;

function CheckVariantFromName(const AName: string; ADefault: TaCheckVariant): TaCheckVariant;
var
  V: TaCheckVariant;
begin
  for V := Low(TaCheckVariant) to High(TaCheckVariant) do
    if SameText(CheckVariantNames[V], AName) then Exit(V);
  Result := ADefault;
end;

{ ---------------- opcije ---------------- }

constructor TaCheckOptions.Create;
begin
  inherited Create;
end;

procedure TaCheckOptions.Assign(ASource: TPersistent);
begin
  if not (ASource is TaCheckOptions) then inherited Assign(ASource);
end;

procedure TaSwitchOptions.Assign(ASource: TPersistent);
begin
  if ASource is TaSwitchOptions then
  begin
    FOnCaption := TaSwitchOptions(ASource).FOnCaption;
    FOffCaption := TaSwitchOptions(ASource).FOffCaption;
  end
  else inherited Assign(ASource);
end;

{ ---------------- prekidac (crtanje) ---------------- }

constructor TaSwitchPaint.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BorderStyle := bsNone;      { Qt: bez okvira QAbstractScrollArea koji tema crta kao polje }
  TabStop := True;
  Width := 120;
  Height := 26;
  ControlStyle := ControlStyle + [csClickEvents, csCaptureMouse];
end;

procedure TaSwitchPaint.SetChecked(AValue: Boolean);
begin
  if FChecked = AValue then Exit;
  FChecked := AValue;
  Invalidate;
end;

procedure TaSwitchPaint.Paint;
var
  T: TaThemeTokens;
  H, W, R, KnobD, Gap: Integer;
  Track, Knob, Txt: TColor;
  Ty: Integer;
begin
  T := ActiveTokens;
  H := Height - 4;
  if H > 22 then H := 22;
  W := H * 2 - 2;
  R := H div 2;
  Gap := 8;
  if FChecked then Track := TokenColor(T.Accent) else Track := TokenColor(T.Border);
  if FChecked then Knob := TokenColor(T.OnAccent) else Knob := TokenColor(T.Surface);
  Txt := TokenColor(T.Text);
  if not Enabled then begin Track := TokenColor(T.Soft); Txt := TokenColor(T.TextSoft); end;
  Canvas.Brush.Color := Color;
  Canvas.FillRect(0, 0, Width, Height);
  Canvas.Brush.Color := Track;
  Canvas.Pen.Color := Track;
  Canvas.RoundRect(1, (Height - H) div 2, 1 + W, (Height - H) div 2 + H, R * 2, R * 2);
  KnobD := H - 6;
  Canvas.Brush.Color := Knob;
  Canvas.Pen.Color := Knob;
  if FChecked then
    Canvas.Ellipse(1 + W - KnobD - 3, (Height - H) div 2 + 3, 1 + W - 3, (Height - H) div 2 + 3 + KnobD)
  else
    Canvas.Ellipse(1 + 3, (Height - H) div 2 + 3, 1 + 3 + KnobD, (Height - H) div 2 + 3 + KnobD);
  if Focused then
  begin
    Canvas.Brush.Style := bsClear;
    Canvas.Pen.Color := TokenColor(T.Accent);
    Canvas.Rectangle(0, 0, Width, Height);
    Canvas.Brush.Style := bsSolid;
  end;
  Canvas.Font.Color := Txt;
  Canvas.Brush.Style := bsClear;
  Ty := (Height - Canvas.TextHeight('Ag')) div 2;
  Canvas.TextOut(W + Gap + 2, Ty, FCaption);
  Canvas.Brush.Style := bsSolid;
end;

procedure TaSwitchPaint.Click;
begin
  inherited Click;
  if FReadOnly or not Enabled then Exit;
  FChecked := not FChecked;
  Invalidate;
  if Assigned(FOnToggle) then FOnToggle(Self);
end;

procedure TaSwitchPaint.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  if (Key = VK_SPACE) and (Shift = []) then
  begin
    Click;
    Key := 0;
  end;
end;

procedure TaSwitchPaint.KeyUp(var Key: Word; Shift: TShiftState);
begin
  inherited KeyUp(Key, Shift);
end;

{ ---------------- pokretac: kvacica ---------------- }

function TaCheckBoxEngine.AllowsGrayed: Boolean;
begin
  Result := False;
end;

function TaCheckTriEngine.AllowsGrayed: Boolean;
begin
  Result := True;
end;

constructor TaCheckBoxEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FBox := TCheckBox.Create(nil);
  FBox.AutoSize := False;
  FBox.AllowGrayed := AllowsGrayed;
  FBox.OnChange := @BoxChange;
  FPrev := cbUnchecked;
  AttachInner(FBox);
end;

procedure TaCheckBoxEngine.BoxChange(Sender: TObject);
begin
  if FSetting then Exit;
  if FReadOnly then
  begin
    FSetting := True;
    try
      FBox.State := FPrev;
    finally
      FSetting := False;
    end;
    Exit;
  end;
  FPrev := FBox.State;
  InnerChanged(Sender);
end;

function TaCheckBoxEngine.GetText: string;
begin
  Result := FBox.Caption;
end;

procedure TaCheckBoxEngine.SetText(const AValue: string);
begin
  if FBox.Caption <> AValue then FBox.Caption := AValue;
end;

function TaCheckBoxEngine.GetValue: Variant;
begin
  if FBox.State = cbGrayed then Result := Null
  else Result := FBox.State = cbChecked;
end;

procedure TaCheckBoxEngine.SetValue(const AValue: Variant);
begin
  FSetting := True;
  try
    if VarIsNull(AValue) or VarIsEmpty(AValue) then
    begin
      if FBox.AllowGrayed then FBox.State := cbGrayed else FBox.State := cbUnchecked;
    end
    else if VarIsType(AValue, varBoolean) then
    begin
      if Boolean(AValue) then FBox.State := cbChecked else FBox.State := cbUnchecked;
    end
    else if VarIsNumeric(AValue) then
    begin
      if Double(AValue) <> 0 then FBox.State := cbChecked else FBox.State := cbUnchecked;
    end
    else
      if SameText(VarToStr(AValue), '1') or SameText(VarToStr(AValue), 'true') or SameText(VarToStr(AValue), 'da') then
        FBox.State := cbChecked
      else FBox.State := cbUnchecked;
    FPrev := FBox.State;
  finally
    FSetting := False;
  end;
end;

procedure TaCheckBoxEngine.SetReadOnly(AValue: Boolean);
begin
  FReadOnly := AValue;
end;

{ ---------------- pokretac: radio ---------------- }

constructor TaCheckRadioEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FRadio := TRadioButton.Create(nil);
  FRadio.AutoSize := False;
  FRadio.OnChange := @RadioChange;
  AttachInner(FRadio);
end;

procedure TaCheckRadioEngine.RadioChange(Sender: TObject);
begin
  if FSetting then Exit;
  if FReadOnly then
  begin
    FSetting := True;
    try
      FRadio.Checked := FPrev;
    finally
      FSetting := False;
    end;
    Exit;
  end;
  FPrev := FRadio.Checked;
  InnerChanged(Sender);
end;

function TaCheckRadioEngine.GetText: string;
begin
  Result := FRadio.Caption;
end;

procedure TaCheckRadioEngine.SetText(const AValue: string);
begin
  if FRadio.Caption <> AValue then FRadio.Caption := AValue;
end;

function TaCheckRadioEngine.GetValue: Variant;
begin
  Result := FRadio.Checked;
end;

procedure TaCheckRadioEngine.SetValue(const AValue: Variant);
var
  B: Boolean;
begin
  if VarIsNull(AValue) or VarIsEmpty(AValue) then B := False
  else if VarIsType(AValue, varBoolean) then B := Boolean(AValue)
  else if VarIsNumeric(AValue) then B := Double(AValue) <> 0
  else B := SameText(VarToStr(AValue), '1') or SameText(VarToStr(AValue), 'true') or SameText(VarToStr(AValue), 'da');
  FSetting := True;
  try
    FRadio.Checked := B;
    FPrev := B;
  finally
    FSetting := False;
  end;
end;

procedure TaCheckRadioEngine.SetReadOnly(AValue: Boolean);
begin
  FReadOnly := AValue;
end;

{ ---------------- pokretac: prekidac ---------------- }

constructor TaCheckSwitchEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FSw := TaSwitchPaint.Create(nil);
  FSw.OnToggle := @Toggled;
  AttachInner(FSw);
end;

procedure TaCheckSwitchEngine.Toggled(Sender: TObject);
begin
  ShowCaption;
  InnerChanged(Sender);
end;

procedure TaCheckSwitchEngine.ShowCaption;
begin
  if FSw.Checked and (FOn <> '') then FSw.CaptionText := FOn
  else if (not FSw.Checked) and (FOff <> '') then FSw.CaptionText := FOff
  else FSw.CaptionText := FBase;
  FSw.Invalidate;
end;

function TaCheckSwitchEngine.GetText: string;
begin
  Result := FBase;
end;

procedure TaCheckSwitchEngine.SetText(const AValue: string);
begin
  FBase := AValue;
  ShowCaption;
end;

function TaCheckSwitchEngine.GetValue: Variant;
begin
  Result := FSw.Checked;
end;

procedure TaCheckSwitchEngine.SetValue(const AValue: Variant);
var
  B: Boolean;
begin
  if VarIsNull(AValue) or VarIsEmpty(AValue) then B := False
  else if VarIsType(AValue, varBoolean) then B := Boolean(AValue)
  else if VarIsNumeric(AValue) then B := Double(AValue) <> 0
  else B := SameText(VarToStr(AValue), '1') or SameText(VarToStr(AValue), 'true') or SameText(VarToStr(AValue), 'da');
  FSw.Checked := B;
  ShowCaption;
end;

procedure TaCheckSwitchEngine.SetReadOnly(AValue: Boolean);
begin
  FSw.ReadOnly := AValue;
end;

procedure TaCheckSwitchEngine.ApplyOptions(AOptions: TPersistent);
begin
  if AOptions is TaSwitchOptions then
  begin
    FOn := TaSwitchOptions(AOptions).OnCaption;
    FOff := TaSwitchOptions(AOptions).OffCaption;
    ShowCaption;
  end;
end;

{ ---------------- TaCheck ---------------- }

constructor TaCheck.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FDataLink := TFieldDataLink.Create;
  FDataLink.Control := Self;
  FDataLink.OnDataChange := @DataChange;
  FDataLink.OnUpdateData := @UpdateData;
  FVariant := cvCheckbox;
  Width := 140;
  Height := 24;
  ReplaceEngine;
  PushToEngine;
end;

destructor TaCheck.Destroy;
var
  V: TaCheckVariant;
begin
  FDataLink.OnDataChange := nil;
  FDataLink.OnUpdateData := nil;
  FDataLink.Free;
  for V := Low(TaCheckVariant) to High(TaCheckVariant) do FOptions[V].Free;
  inherited Destroy;
end;

function TaCheck.OptionsClassFor(AVariant: TaCheckVariant): TaCheckOptionsClass;
begin
  case AVariant of
    cvSwitch: Result := TaSwitchOptions;
  else
    Result := TaCheckOptions;
  end;
end;

function TaCheck.CreateEngine: TaEngine;
var
  C: TaEngineClass;
begin
  C := FindEngine(CheckFamily, CheckVariantNames[FVariant]);
  if C = nil then C := FindEngine(CheckFamily, 'checkbox');
  Result := C.Create(Self);
end;

function TaCheck.VariantName: string;
begin
  Result := CheckVariantNames[FVariant];
end;

function TaCheck.GetVariant: TaCheckVariant;
begin
  Result := FVariant;
end;

procedure TaCheck.SetVariant(AValue: TaCheckVariant);
var
  V: System.Variant;
begin
  if AValue = FVariant then Exit;
  FText := RealGetText;
  V := Value;
  FChecked := (not VarIsNull(V)) and Boolean(V);
  FNull := VarIsNull(V);
  FVariant := AValue;
  ReplaceEngine;
  PushToEngine;
end;

function TaCheck.GetOptions: TaCheckOptions;
begin
  if FOptions[FVariant] = nil then FOptions[FVariant] := OptionsClassFor(FVariant).Create;
  Result := FOptions[FVariant];
end;

procedure TaCheck.SetOptions(AValue: TaCheckOptions);
begin
  GetOptions.Assign(AValue);
  if Engine <> nil then Engine.ApplyOptions(GetOptions);
end;

function TaCheck.OptionsStored: Boolean;
begin
  Result := FVariant = cvSwitch;
end;

procedure TaCheck.PushToEngine;
begin
  if Engine = nil then Exit;
  FUpdating := True;
  try
    Engine.ApplyOptions(GetOptions);
    Engine.SetText(FText);
    if FNull then Engine.SetValue(Null) else Engine.SetValue(FChecked);
    Engine.SetReadOnly(FReadOnly);
  finally
    FUpdating := False;
  end;
end;

procedure TaCheck.SetReadOnly(AValue: Boolean);
begin
  if FReadOnly = AValue then Exit;
  FReadOnly := AValue;
  if Engine <> nil then Engine.SetReadOnly(FReadOnly);
end;

function TaCheck.RealGetText: TCaption;
begin
  if Engine <> nil then Result := Engine.GetText else Result := FText;
end;

procedure TaCheck.RealSetText(const AValue: TCaption);
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

function TaCheck.GetChecked: Boolean;
var
  V: System.Variant;
begin
  if Engine = nil then Exit(FChecked);
  V := Engine.GetValue;
  Result := (not VarIsNull(V)) and Boolean(V);
end;

procedure TaCheck.SetChecked(AValue: Boolean);
begin
  FChecked := AValue;
  FNull := False;
  SetValue(AValue);
end;

function TaCheck.Value: System.Variant;
begin
  if Engine <> nil then Result := Engine.GetValue else Result := Null;
end;

procedure TaCheck.SetValue(const AValue: System.Variant);
begin
  if Engine = nil then Exit;
  FUpdating := True;
  try
    Engine.SetValue(AValue);
  finally
    FUpdating := False;
  end;
end;

function TaCheck.IsUndetermined: Boolean;
begin
  Result := VarIsNull(Value);
end;

procedure TaCheck.EngineChanged;
begin
  if FUpdating then Exit;
  if FDataLink.Active and not FReadOnly then
  begin
    FSelfEdit := True;
    try
      if FDataLink.Edit then FDataLink.Modified;
    finally
      FSelfEdit := False;
    end;
    { za razliku od teksta, kvacica se upisuje u polje odmah }
    try
      FDataLink.UpdateRecord;
    except
      FDataLink.Reset;
      raise;
    end;
  end;
  inherited EngineChanged;
end;

procedure TaCheck.EngineExit;
begin
  inherited EngineExit;
end;

{ ---------------- podaci ---------------- }

function TaCheck.GetDataSource: TDataSource;
begin
  Result := FDataLink.DataSource;
end;

procedure TaCheck.SetDataSource(AValue: TDataSource);
begin
  FDataLink.DataSource := AValue;
  if AValue <> nil then AValue.FreeNotification(Self);
end;

function TaCheck.GetDataField: string;
begin
  Result := FDataLink.FieldName;
end;

procedure TaCheck.SetDataField(const AValue: string);
begin
  FDataLink.FieldName := AValue;
end;

procedure TaCheck.Notification(AComponent: TComponent; AOperation: TOperation);
begin
  inherited Notification(AComponent, AOperation);
  if (AOperation = opRemove) and (FDataLink <> nil) and (AComponent = FDataLink.DataSource) then
    FDataLink.DataSource := nil;
end;

procedure TaCheck.Loaded;
begin
  inherited Loaded;
  PushToEngine;
end;

function FieldIsTrue(F: TField): Boolean;
var
  S: string;
begin
  case F.DataType of
    ftBoolean: Result := F.AsBoolean;
    ftSmallint, ftInteger, ftLargeint, ftWord, ftAutoInc, ftFloat, ftCurrency, ftBCD, ftFMTBcd: Result := F.AsFloat <> 0;
  else
    begin
      S := LowerCase(Trim(F.AsString));
      Result := (S = '1') or (S = 'true') or (S = 'da') or (S = 'y') or (S = 'yes') or (S = 't');
    end;
  end;
end;

procedure TaCheck.DataChange(Sender: TObject);
var
  F: TField;
begin
  if FSelfEdit then Exit;
  F := FDataLink.Field;
  FUpdating := True;
  try
    if F = nil then
    begin
      if not (csDesigning in ComponentState) then Engine.SetValue(Null);
    end
    else if F.IsNull then Engine.SetValue(Null)
    else Engine.SetValue(FieldIsTrue(F));
  finally
    FUpdating := False;
  end;
end;

procedure TaCheck.UpdateData(Sender: TObject);
var
  F: TField;
  V: System.Variant;
  B: Boolean;
begin
  F := FDataLink.Field;
  if F = nil then Exit;
  V := Engine.GetValue;
  if VarIsNull(V) then
  begin
    F.Clear;
    Exit;
  end;
  B := Boolean(V);
  case F.DataType of
    ftBoolean: F.AsBoolean := B;
    ftSmallint, ftInteger, ftLargeint, ftWord, ftAutoInc: F.AsInteger := Ord(B);
    ftFloat, ftCurrency, ftBCD, ftFMTBcd: F.AsFloat := Ord(B);
  else
    F.AsString := IfThen(B, '1', '0');
  end;
end;

{ ---------------- definicija kontrole <-> komponenta ---------------- }

const
  OwnKeys = ',variant,tip,locked,visibleIf,enabledIf,condFormat,onCaption,offCaption,';

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

function CheckFromDef(D: TaControlDef; AOwner: TComponent): TaCheck;
begin
  Result := TaCheck.Create(AOwner);
  try
    Result.Name := D.Name;
    Result.SetBounds(D.Left, D.Top, D.Width, D.Height);
    Result.ControlSource := D.ControlSource;
    Result.Variant := CheckVariantFromName(D.GetX('variant'), cvCheckbox);
    Result.Caption := D.Caption;
    Result.ReadOnly := D.GetX('locked') = '1';
    Result.Hint := D.GetX('tip');
    Result.VisibleIf := D.GetX('visibleIf');
    Result.EnabledIf := D.GetX('enabledIf');
    Result.CondFormat := D.GetX('condFormat');
    if Result.Variant = cvSwitch then
    begin
      TaSwitchOptions(Result.Options).OnCaption := D.GetX('onCaption');
      TaSwitchOptions(Result.Options).OffCaption := D.GetX('offCaption');
      Result.SetOptions(Result.Options);
    end;
    Result.Extra := ExtraWithout(D.Extra);
  except
    Result.Free;
    raise;
  end;
end;

procedure CheckToDef(C: TaCheck; D: TaControlDef);
var
  O: TaCheckOptions;
begin
  D.Kind := 'Check';
  D.Name := C.Name;
  D.Left := C.Left; D.Top := C.Top; D.Width := C.Width; D.Height := C.Height;
  D.ControlSource := C.ControlSource;
  D.Caption := C.Caption;
  D.Extra := C.Extra;
  D.SetX('variant', IfThen(C.Variant = cvCheckbox, '', C.VariantName));
  D.SetX('locked', IfThen(C.ReadOnly, '1', ''));
  D.SetX('tip', C.Hint);
  D.SetX('visibleIf', C.VisibleIf);
  D.SetX('enabledIf', C.EnabledIf);
  D.SetX('condFormat', C.CondFormat);
  O := C.Options;
  if O is TaSwitchOptions then
  begin
    D.SetX('onCaption', TaSwitchOptions(O).OnCaption);
    D.SetX('offCaption', TaSwitchOptions(O).OffCaption);
  end;
end;

function CheckToLfm(C: TaCheck): string;
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
  TCheckLfmFinder = class
    procedure Find(Reader: TReader; const AClassName: string; var AClass: TComponentClass);
  end;

procedure TCheckLfmFinder.Find(Reader: TReader; const AClassName: string; var AClass: TComponentClass);
begin
  if SameText(AClassName, 'TaCheck') then AClass := TaCheck;
end;

function CheckFromLfm(const ALfm: string; AOwner: TComponent): TaCheck;
var
  M: TMemoryStream;
  C: TComponent;
  F: TCheckLfmFinder;
begin
  M := TMemoryStream.Create;
  try
    if ALfm <> '' then M.WriteBuffer(ALfm[1], Length(ALfm));
    M.Position := 0;
    C := nil;
    F := TCheckLfmFinder.Create;
    try
      ReadComponentFromTextStream(M, C, @F.Find, AOwner);
    finally
      F.Free;
    end;
    Result := C as TaCheck;
  finally
    M.Free;
  end;
end;

initialization
  RegisterClass(TaCheck);
  RegisterEngine(CheckFamily, 'checkbox', TaCheckBoxEngine);
  RegisterEngine(CheckFamily, 'switch', TaCheckSwitchEngine);
  RegisterEngine(CheckFamily, 'radio', TaCheckRadioEngine);
  RegisterEngine(CheckFamily, 'tristate', TaCheckTriEngine);

end.
