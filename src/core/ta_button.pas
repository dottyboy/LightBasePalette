unit ta_button;
{ Obitelj Button: standard, default, cancel (TBitBtn), toggle (TToggleBox), flat i link (vlastito crtanje, boje iz tokena).
  Isti nacin kao Edit i Check: domacin TaButton, zamjenjivi pokretaci, Options, definicija kontrole <-> komponenta, .lfm.
  Radnja gumba (OnClick definicije: "macro:...", "openform:..." itd.) je svojstvo ClickAction; dogadaj OnClick je LCL-ov.
  Nije jos: varijante image, menu i split (plan 3.2). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, StdCtrls, Buttons, ExtCtrls, Graphics, Menus, Variants, DB, DBCtrls, LCLType, ta_family, ta_formdef;

type
  TaButtonVariant = (bvStandard, bvDefault, bvCancel, bvToggle, bvFlat, bvLink, bvImage, bvMenu, bvSplit);

const
  ButtonVariantNames: array[TaButtonVariant] of string = ('standard', 'default', 'cancel', 'toggle', 'flat', 'link', 'image', 'menu', 'split');
  ButtonFamily = 'Button';

type
  TaButtonMenuEvent = procedure(Sender: TObject; const AAction: string) of object;

  TaButtonOptions = class(TPersistent)
  private
    FIcon, FMenuItems: string;
  public
    procedure Assign(ASource: TPersistent); override;
  published
    { naziv ikone iz biblioteke ikona (ta_icons) }
    property Icon: string read FIcon write FIcon;
    { menu i split: stavke izbornika, jedan redak "Natpis|radnja" }
    property MenuItems: string read FMenuItems write FMenuItems;
  end;

  { gumb koji crta sam sebe: ravni (flat) i poveznica (link) }
  TaFlatPaint = class(TCustomControl)
  private
    FCaption: string;
    FLink, FHot, FDown, FSplit: Boolean;
    FLastX: Integer;
    FOnSplit: TNotifyEvent;
    procedure SetLink(AValue: Boolean);
  protected
    procedure Paint; override;
    procedure MouseEnter; override;
    procedure MouseLeave; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Click; override;
    property CaptionText: string read FCaption write FCaption;
    { klik na zadanoj vodoravnoj tocki (za ispitivanje split gumba) }
    procedure ClickAt(X: Integer);
    property IsLink: Boolean read FLink write SetLink;
    { split: desnih 22 tocaka su strelica koja otvara izbornik }
    property IsSplit: Boolean read FSplit write FSplit;
    property OnSplit: TNotifyEvent read FOnSplit write FOnSplit;
  end;

  TaButtonStdEngine = class(TaEngine)
  private
    FBtn: TBitBtn;
    procedure BtnClick(Sender: TObject);
  protected
    function IsDefault: Boolean; virtual;
    function IsCancel: Boolean; virtual;
  public
    constructor Create(AHost: TaFamilyHost); override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
    procedure ApplyOptions(AOptions: TPersistent); override;
  end;

  TaButtonDefaultEngine = class(TaButtonStdEngine)
  protected
    function IsDefault: Boolean; override;
  end;

  TaButtonCancelEngine = class(TaButtonStdEngine)
  protected
    function IsCancel: Boolean; override;
  end;

  TaButtonToggleEngine = class(TaEngine)
  private
    FBox: TToggleBox;
    FSetting: Boolean;
    procedure BoxClick(Sender: TObject);
  public
    constructor Create(AHost: TaFamilyHost); override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
    function GetValue: Variant; override;
    procedure SetValue(const AValue: Variant); override;
  end;

  { izbornik radnji uz gumb: "Natpis|radnja" po retku }
  TaButtonPopup = class
  private
    FMenu: TPopupMenu;
    FHost: TaFamilyHost;
    FItems: TStringList;
    procedure ItemClick(Sender: TObject);
  public
    constructor Create(AHost: TaFamilyHost);
    destructor Destroy; override;
    procedure Load(const AText: string);
    procedure Show(AControl: TControl);
    procedure Activate(const AAction: string);
    function Count: Integer;
  end;

  TaButtonImageEngine = class(TaButtonStdEngine)
  private
    FCaptionText: string;
  public
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
  end;

  TaButtonMenuEngine = class(TaButtonStdEngine)
  private
    FPopup: TaButtonPopup;
    procedure BtnDrop(Sender: TObject);
  public
    constructor Create(AHost: TaFamilyHost); override;
    destructor Destroy; override;
    procedure ApplyOptions(AOptions: TPersistent); override;
    property Popup: TaButtonPopup read FPopup;
  end;

  TaButtonFlatEngine = class(TaEngine)
  private
    FFlat: TaFlatPaint;
    procedure FlatClick(Sender: TObject);
  protected
    function AsLink: Boolean; virtual;
    function AsSplit: Boolean; virtual;
  public
    constructor Create(AHost: TaFamilyHost); override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
  end;

  TaButtonLinkEngine = class(TaButtonFlatEngine)
  protected
    function AsLink: Boolean; override;
  end;

  TaButtonSplitEngine = class(TaButtonFlatEngine)
  private
    FPopup: TaButtonPopup;
    procedure SplitDrop(Sender: TObject);
  protected
    function AsSplit: Boolean; override;
  public
    constructor Create(AHost: TaFamilyHost); override;
    destructor Destroy; override;
    procedure ApplyOptions(AOptions: TPersistent); override;
    property Popup: TaButtonPopup read FPopup;
  end;

  TaButton = class(TaFamilyHost)
  private
    FOnMenuAction: TaButtonMenuEvent;
    FVariant: TaButtonVariant;
    FOptions: TaButtonOptions;
    FText: string;
    FChecked: Boolean;
    FClickAction, FControlSource, FVisibleIf, FEnabledIf, FCondFormat, FExtra: string;
    FDataLink: TFieldDataLink;
    FUpdating, FSelfEdit: Boolean;
    function GetVariant: TaButtonVariant;
    procedure SetVariant(AValue: TaButtonVariant);
    function GetOptions: TaButtonOptions;
    procedure SetOptions(AValue: TaButtonOptions);
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
    function RealGetText: TCaption; override;
    procedure RealSetText(const AValue: TCaption); override;
    procedure Notification(AComponent: TComponent; AOperation: TOperation); override;
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function VariantName: string;
    { za testove i skripte: isto sto korisnik napravi klikom }
    procedure PerformClick;
    { stavka izbornika (menu, split) }
    procedure FireMenu(const AAction: string);
    { za testove i skripte: izaberi stavku izbornika s tom radnjom }
    procedure PerformMenu(const AAction: string);
    function MenuCount: Integer;
  published
    property Variant: TaButtonVariant read GetVariant write SetVariant default bvStandard;
    property Caption;
    property Options: TaButtonOptions read GetOptions write SetOptions;
    { za varijantu toggle: pritisnut }
    property Checked: Boolean read GetChecked write SetChecked default False;
    { radnja iz definicije kontrole (OnClick): macro:..., openform:... }
    property ClickAction: string read FClickAction write FClickAction;
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
    property OnClick;
    property OnMenuAction: TaButtonMenuEvent read FOnMenuAction write FOnMenuAction;
    property OnEnter;
    property OnExit;
  end;

function IsButtonKind(const AKind: string): Boolean;
function ButtonVariantFromName(const AName: string; ADefault: TaButtonVariant = bvStandard): TaButtonVariant;
function ButtonFromDef(D: TaControlDef; AOwner: TComponent): TaButton;
procedure ButtonToDef(B: TaButton; D: TaControlDef);
function ButtonToLfm(B: TaButton): string;
function ButtonFromLfm(const ALfm: string; AOwner: TComponent): TaButton;

implementation

uses
  StrUtils, LResources, ta_tokens, ta_icons;

function IsButtonKind(const AKind: string): Boolean;
begin
  Result := SameText(AKind, 'Button') or SameText(AKind, 'ToggleButton');
end;

function ButtonVariantFromName(const AName: string; ADefault: TaButtonVariant): TaButtonVariant;
var
  V: TaButtonVariant;
begin
  for V := Low(TaButtonVariant) to High(TaButtonVariant) do
    if SameText(ButtonVariantNames[V], AName) then Exit(V);
  Result := ADefault;
end;

procedure TaButtonOptions.Assign(ASource: TPersistent);
begin
  if ASource is TaButtonOptions then
  begin
    FIcon := TaButtonOptions(ASource).FIcon;
    FMenuItems := TaButtonOptions(ASource).FMenuItems;
  end
  else inherited Assign(ASource);
end;

type
  TCtlCrack = class(TControl)
  public
    procedure DoClick;
  end;

procedure TCtlCrack.DoClick;
begin
  Click;
end;

procedure HostClick(AHost: TControl);
begin
  if AHost <> nil then TCtlCrack(AHost).DoClick;
end;

{ ---------------- vlastito crtanje ---------------- }

constructor TaFlatPaint.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BorderStyle := bsNone;      { Qt: bez okvira QAbstractScrollArea koji tema crta kao polje }
  TabStop := True;
  Width := 90;
  Height := 28;
  ControlStyle := ControlStyle + [csClickEvents, csCaptureMouse];
end;

procedure TaFlatPaint.SetLink(AValue: Boolean);
begin
  FLink := AValue;
  if FLink then Cursor := crHandPoint else Cursor := crDefault;
  Invalidate;
end;

procedure TaFlatPaint.Paint;
var
  T: TaThemeTokens;
  Bg, Fg, Bd: TColor;
  Tw, Th, R: Integer;
begin
  T := ActiveTokens;
  Canvas.Brush.Color := Color;
  Canvas.FillRect(0, 0, Width, Height);
  Fg := TokenColor(T.Text);
  if FLink then
  begin
    Fg := TokenColor(T.Accent);
    if not Enabled then Fg := TokenColor(T.TextSoft);
    Canvas.Font.Color := Fg;
    Canvas.Font.Style := [fsUnderline];
    Canvas.Brush.Style := bsClear;
    Th := Canvas.TextHeight('Ag');
    Canvas.TextOut(2, (Height - Th) div 2, FCaption);
    if Focused then
    begin
      Canvas.Pen.Color := Fg;
      Canvas.Pen.Style := psDot;
      Canvas.Rectangle(0, 0, Width, Height);
      Canvas.Pen.Style := psSolid;
    end;
    Canvas.Brush.Style := bsSolid;
    Exit;
  end;
  if FDown then Bg := TokenColor(T.AccentSoft)
  else if FHot then Bg := TokenColor(T.Soft)
  else Bg := Color;
  Bd := TokenColor(T.Border);
  if Focused then Bd := TokenColor(T.Accent);
  if not Enabled then Fg := TokenColor(T.TextSoft);
  R := T.RadiusButton;
  if R > Height div 2 then R := Height div 2;
  Canvas.Brush.Color := Bg;
  Canvas.Pen.Color := Bd;
  Canvas.RoundRect(0, 0, Width, Height, R * 2, R * 2);
  Canvas.Font.Color := Fg;
  Canvas.Brush.Style := bsClear;
  Tw := Canvas.TextWidth(FCaption);
  Th := Canvas.TextHeight('Ag');
  if FSplit then
  begin
    Canvas.TextOut((Width - 22 - Tw) div 2, (Height - Th) div 2, FCaption);
    Canvas.Pen.Color := Bd;
    Canvas.MoveTo(Width - 22, 4);
    Canvas.LineTo(Width - 22, Height - 4);
    Canvas.Pen.Color := Fg;
    Canvas.Pen.Width := 2;
    Canvas.MoveTo(Width - 16, Height div 2 - 2);
    Canvas.LineTo(Width - 12, Height div 2 + 2);
    Canvas.LineTo(Width - 8, Height div 2 - 2);
    Canvas.Pen.Width := 1;
  end
  else Canvas.TextOut((Width - Tw) div 2, (Height - Th) div 2, FCaption);
  Canvas.Brush.Style := bsSolid;
end;

procedure TaFlatPaint.MouseEnter;
begin
  inherited MouseEnter;
  FHot := True;
  Invalidate;
end;

procedure TaFlatPaint.MouseLeave;
begin
  inherited MouseLeave;
  FHot := False;
  FDown := False;
  Invalidate;
end;

procedure TaFlatPaint.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  FDown := True;
  FLastX := X;
  if CanFocus then SetFocus;
  Invalidate;
end;

procedure TaFlatPaint.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  FDown := False;
  Invalidate;
end;

procedure TaFlatPaint.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  if ((Key = VK_SPACE) or (Key = VK_RETURN)) and (Shift = []) then
  begin
    Click;
    Key := 0;
  end;
end;

procedure TaFlatPaint.ClickAt(X: Integer);
begin
  FLastX := X;
  Click;
end;

procedure TaFlatPaint.Click;
begin
  if not Enabled then Exit;
  if FSplit and (FLastX >= Width - 22) then
  begin
    if Assigned(FOnSplit) then FOnSplit(Self);
    Exit;
  end;
  inherited Click;
end;

{ ---------------- pokretaci ---------------- }

constructor TaButtonStdEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FBtn := TBitBtn.Create(nil);
  FBtn.AutoSize := False;
  FBtn.Default := IsDefault;
  FBtn.Cancel := IsCancel;
  FBtn.OnClick := @BtnClick;
  AttachInner(FBtn);
end;

function TaButtonStdEngine.IsDefault: Boolean;
begin
  Result := False;
end;

function TaButtonStdEngine.IsCancel: Boolean;
begin
  Result := False;
end;

function TaButtonDefaultEngine.IsDefault: Boolean;
begin
  Result := True;
end;

function TaButtonCancelEngine.IsCancel: Boolean;
begin
  Result := True;
end;

procedure TaButtonStdEngine.BtnClick(Sender: TObject);
begin
  HostClick(Host);
end;

function TaButtonStdEngine.GetText: string;
begin
  Result := FBtn.Caption;
end;

procedure TaButtonStdEngine.SetText(const AValue: string);
begin
  if FBtn.Caption <> AValue then FBtn.Caption := AValue;
end;

procedure TaButtonStdEngine.ApplyOptions(AOptions: TPersistent);
begin
  if (AOptions is TaButtonOptions) and (TaButtonOptions(AOptions).Icon <> '') then
    SetGlyph(FBtn, TaButtonOptions(AOptions).Icon);
end;

constructor TaButtonToggleEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FBox := TToggleBox.Create(nil);
  FBox.AutoSize := False;
  FBox.OnClick := @BoxClick;
  AttachInner(FBox);
end;

procedure TaButtonToggleEngine.BoxClick(Sender: TObject);
begin
  if FSetting then Exit;
  InnerChanged(Sender);
  HostClick(Host);
end;

function TaButtonToggleEngine.GetText: string;
begin
  Result := FBox.Caption;
end;

procedure TaButtonToggleEngine.SetText(const AValue: string);
begin
  if FBox.Caption <> AValue then FBox.Caption := AValue;
end;

function TaButtonToggleEngine.GetValue: Variant;
begin
  Result := FBox.Checked;
end;

procedure TaButtonToggleEngine.SetValue(const AValue: Variant);
var
  B: Boolean;
begin
  if VarIsNull(AValue) or VarIsEmpty(AValue) then B := False
  else if VarIsType(AValue, varBoolean) then B := Boolean(AValue)
  else if VarIsNumeric(AValue) then B := Double(AValue) <> 0
  else B := SameText(VarToStr(AValue), '1') or SameText(VarToStr(AValue), 'true') or SameText(VarToStr(AValue), 'da');
  FSetting := True;
  try
    FBox.Checked := B;
  finally
    FSetting := False;
  end;
end;

constructor TaButtonFlatEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FFlat := TaFlatPaint.Create(nil);
  FFlat.IsLink := AsLink;
  FFlat.IsSplit := AsSplit;
  FFlat.OnClick := @FlatClick;
  AttachInner(FFlat);
end;

function TaButtonFlatEngine.AsLink: Boolean;
begin
  Result := False;
end;

function TaButtonLinkEngine.AsLink: Boolean;
begin
  Result := True;
end;

procedure TaButtonFlatEngine.FlatClick(Sender: TObject);
begin
  HostClick(Host);
end;

function TaButtonFlatEngine.GetText: string;
begin
  Result := FFlat.CaptionText;
end;

procedure TaButtonFlatEngine.SetText(const AValue: string);
begin
  FFlat.CaptionText := AValue;
  FFlat.Invalidate;
end;

{ ---------------- izbornik uz gumb ---------------- }

constructor TaButtonPopup.Create(AHost: TaFamilyHost);
begin
  inherited Create;
  FHost := AHost;
  FMenu := TPopupMenu.Create(nil);
  FItems := TStringList.Create;
end;

destructor TaButtonPopup.Destroy;
begin
  FItems.Free;
  FMenu.Free;
  inherited Destroy;
end;

procedure TaButtonPopup.Load(const AText: string);
var
  L: TStringList;
  I, P: Integer;
  S: string;
  Mi: TMenuItem;
begin
  FMenu.Items.Clear;
  FItems.Clear;
  L := TStringList.Create;
  try
    L.Text := StringReplace(AText, ' / ', LineEnding, [rfReplaceAll]);
    for I := 0 to L.Count - 1 do
    begin
      S := Trim(L[I]);
      if S = '' then Continue;
      P := Pos('|', S);
      Mi := TMenuItem.Create(FMenu);
      if P > 0 then
      begin
        Mi.Caption := Trim(Copy(S, 1, P - 1));
        FItems.Add(Trim(Copy(S, P + 1, MaxInt)));
      end
      else
      begin
        Mi.Caption := S;
        FItems.Add(S);
      end;
      Mi.Tag := FItems.Count - 1;
      Mi.OnClick := @ItemClick;
      FMenu.Items.Add(Mi);
    end;
  finally
    L.Free;
  end;
end;

procedure TaButtonPopup.ItemClick(Sender: TObject);
begin
  Activate(FItems[TMenuItem(Sender).Tag]);
end;

procedure TaButtonPopup.Activate(const AAction: string);
begin
  if FHost is TaButton then TaButton(FHost).FireMenu(AAction);
end;

function TaButtonPopup.Count: Integer;
begin
  Result := FItems.Count;
end;

procedure TaButtonPopup.Show(AControl: TControl);
var
  P: TPoint;
begin
  if FMenu.Items.Count = 0 then Exit;
  P := AControl.ClientToScreen(Point(0, AControl.Height));
  FMenu.PopUp(P.X, P.Y);
end;

{ ---------------- pokretaci: image, menu, split ---------------- }

function TaButtonImageEngine.GetText: string;
begin
  Result := FCaptionText;
end;

procedure TaButtonImageEngine.SetText(const AValue: string);
begin
  { gumb s ikonom bez natpisa; natpis je savjet }
  FCaptionText := AValue;
  FBtn.Caption := '';
  FBtn.Hint := AValue;
  FBtn.ShowHint := AValue <> '';
end;

constructor TaButtonMenuEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FPopup := TaButtonPopup.Create(AHost);
  FBtn.OnClick := @BtnDrop;
end;

destructor TaButtonMenuEngine.Destroy;
begin
  FPopup.Free;
  inherited Destroy;
end;

procedure TaButtonMenuEngine.BtnDrop(Sender: TObject);
begin
  FPopup.Show(FBtn);
  HostClick(Host);
end;

procedure TaButtonMenuEngine.ApplyOptions(AOptions: TPersistent);
begin
  inherited ApplyOptions(AOptions);
  if AOptions is TaButtonOptions then FPopup.Load(TaButtonOptions(AOptions).MenuItems);
end;

function TaButtonFlatEngine.AsSplit: Boolean;
begin
  Result := False;
end;

function TaButtonSplitEngine.AsSplit: Boolean;
begin
  Result := True;
end;

constructor TaButtonSplitEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FPopup := TaButtonPopup.Create(AHost);
  FFlat.OnSplit := @SplitDrop;
end;

destructor TaButtonSplitEngine.Destroy;
begin
  FPopup.Free;
  inherited Destroy;
end;

procedure TaButtonSplitEngine.SplitDrop(Sender: TObject);
begin
  FPopup.Show(FFlat);
end;

procedure TaButtonSplitEngine.ApplyOptions(AOptions: TPersistent);
begin
  if AOptions is TaButtonOptions then FPopup.Load(TaButtonOptions(AOptions).MenuItems);
end;

{ ---------------- TaButton ---------------- }

constructor TaButton.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FDataLink := TFieldDataLink.Create;
  FDataLink.Control := Self;
  FDataLink.OnDataChange := @DataChange;
  FDataLink.OnUpdateData := @UpdateData;
  FOptions := TaButtonOptions.Create;
  FVariant := bvStandard;
  Width := 90;
  Height := 28;
  ReplaceEngine;
  PushToEngine;
end;

destructor TaButton.Destroy;
begin
  FDataLink.OnDataChange := nil;
  FDataLink.OnUpdateData := nil;
  FDataLink.Free;
  FOptions.Free;
  inherited Destroy;
end;

function TaButton.CreateEngine: TaEngine;
var
  C: TaEngineClass;
begin
  C := FindEngine(ButtonFamily, ButtonVariantNames[FVariant]);
  if C = nil then C := FindEngine(ButtonFamily, 'standard');
  Result := C.Create(Self);
end;

function TaButton.VariantName: string;
begin
  Result := ButtonVariantNames[FVariant];
end;

function TaButton.GetVariant: TaButtonVariant;
begin
  Result := FVariant;
end;

procedure TaButton.SetVariant(AValue: TaButtonVariant);
begin
  if AValue = FVariant then Exit;
  FText := RealGetText;
  FChecked := GetChecked;
  FVariant := AValue;
  ReplaceEngine;
  PushToEngine;
end;

function TaButton.GetOptions: TaButtonOptions;
begin
  Result := FOptions;
end;

procedure TaButton.SetOptions(AValue: TaButtonOptions);
begin
  FOptions.Assign(AValue);
  if Engine <> nil then Engine.ApplyOptions(FOptions);
end;

procedure TaButton.PushToEngine;
begin
  if Engine = nil then Exit;
  FUpdating := True;
  try
    Engine.ApplyOptions(FOptions);
    Engine.SetText(FText);
    if FVariant = bvToggle then Engine.SetValue(FChecked);
  finally
    FUpdating := False;
  end;
end;

function TaButton.RealGetText: TCaption;
begin
  if Engine <> nil then Result := Engine.GetText else Result := FText;
end;

procedure TaButton.RealSetText(const AValue: TCaption);
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

function TaButton.GetChecked: Boolean;
var
  V: System.Variant;
begin
  if (Engine = nil) or (FVariant <> bvToggle) then Exit(FChecked);
  V := Engine.GetValue;
  Result := (not VarIsNull(V)) and Boolean(V);
end;

procedure TaButton.SetChecked(AValue: Boolean);
begin
  FChecked := AValue;
  if (Engine <> nil) and (FVariant = bvToggle) then
  begin
    FUpdating := True;
    try
      Engine.SetValue(AValue);
    finally
      FUpdating := False;
    end;
  end;
end;

procedure TaButton.PerformClick;
begin
  if FVariant = bvToggle then
  begin
    TToggleBox(Engine.Inner).Checked := not TToggleBox(Engine.Inner).Checked;
    Exit;
  end;
  Engine.Inner.Click;
end;

procedure TaButton.FireMenu(const AAction: string);
begin
  if Assigned(FOnMenuAction) then FOnMenuAction(Self, AAction);
end;

function PopupOf(AEngine: TaEngine): TaButtonPopup;
begin
  Result := nil;
  if AEngine is TaButtonMenuEngine then Result := TaButtonMenuEngine(AEngine).Popup
  else if AEngine is TaButtonSplitEngine then Result := TaButtonSplitEngine(AEngine).Popup;
end;

procedure TaButton.PerformMenu(const AAction: string);
var
  P: TaButtonPopup;
begin
  P := PopupOf(Engine);
  if P <> nil then P.Activate(AAction);
end;

function TaButton.MenuCount: Integer;
var
  P: TaButtonPopup;
begin
  P := PopupOf(Engine);
  if P <> nil then Result := P.Count else Result := 0;
end;

procedure TaButton.EngineChanged;
begin
  if FUpdating then Exit;
  if (FVariant = bvToggle) and FDataLink.Active then
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

function TaButton.GetDataSource: TDataSource;
begin
  Result := FDataLink.DataSource;
end;

procedure TaButton.SetDataSource(AValue: TDataSource);
begin
  FDataLink.DataSource := AValue;
  if AValue <> nil then AValue.FreeNotification(Self);
end;

function TaButton.GetDataField: string;
begin
  Result := FDataLink.FieldName;
end;

procedure TaButton.SetDataField(const AValue: string);
begin
  FDataLink.FieldName := AValue;
end;

procedure TaButton.Notification(AComponent: TComponent; AOperation: TOperation);
begin
  inherited Notification(AComponent, AOperation);
  if (AOperation = opRemove) and (FDataLink <> nil) and (AComponent = FDataLink.DataSource) then
    FDataLink.DataSource := nil;
end;

procedure TaButton.Loaded;
begin
  inherited Loaded;
  PushToEngine;
end;

procedure TaButton.DataChange(Sender: TObject);
var
  F: TField;
  S: string;
begin
  if FSelfEdit or (FVariant <> bvToggle) then Exit;
  F := FDataLink.Field;
  FUpdating := True;
  try
    if (F = nil) or F.IsNull then Engine.SetValue(False)
    else
    begin
      case F.DataType of
        ftBoolean: Engine.SetValue(F.AsBoolean);
        ftSmallint, ftInteger, ftLargeint, ftWord, ftAutoInc, ftFloat, ftCurrency, ftBCD, ftFMTBcd: Engine.SetValue(F.AsFloat <> 0);
      else
        begin
          S := LowerCase(Trim(F.AsString));
          Engine.SetValue((S = '1') or (S = 'true') or (S = 'da') or (S = 'y') or (S = 'yes') or (S = 't'));
        end;
      end;
    end;
  finally
    FUpdating := False;
  end;
end;

procedure TaButton.UpdateData(Sender: TObject);
var
  F: TField;
  B: Boolean;
begin
  F := FDataLink.Field;
  if (F = nil) or (FVariant <> bvToggle) then Exit;
  B := Boolean(Engine.GetValue);
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
  OwnKeys = ',variant,tip,locked,visibleIf,enabledIf,condFormat,icon,menuItems,';

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

function ButtonFromDef(D: TaControlDef; AOwner: TComponent): TaButton;
var
  V: TaButtonVariant;
begin
  Result := TaButton.Create(AOwner);
  try
    Result.Name := D.Name;
    Result.SetBounds(D.Left, D.Top, D.Width, D.Height);
    V := ButtonVariantFromName(D.GetX('variant'), bvStandard);
    if SameText(D.Kind, 'ToggleButton') and (D.GetX('variant') = '') then V := bvToggle;
    Result.Variant := V;
    Result.Caption := D.Caption;
    Result.ControlSource := D.ControlSource;
    Result.ClickAction := D.OnClick;
    Result.Hint := D.GetX('tip');
    Result.VisibleIf := D.GetX('visibleIf');
    Result.EnabledIf := D.GetX('enabledIf');
    Result.CondFormat := D.GetX('condFormat');
    Result.Options.Icon := D.GetX('icon');
    Result.Options.MenuItems := StringReplace(D.GetX('menuItems'), ' / ', LineEnding, [rfReplaceAll]);
    Result.Options := Result.Options;
    Result.Enabled := D.GetX('locked') <> '1';
    Result.Extra := ExtraWithout(D.Extra);
  except
    Result.Free;
    raise;
  end;
end;

procedure ButtonToDef(B: TaButton; D: TaControlDef);
begin
  if B.Variant = bvToggle then D.Kind := 'ToggleButton' else D.Kind := 'Button';
  D.Name := B.Name;
  D.Left := B.Left; D.Top := B.Top; D.Width := B.Width; D.Height := B.Height;
  D.Caption := B.Caption;
  D.ControlSource := B.ControlSource;
  D.OnClick := B.ClickAction;
  D.Extra := B.Extra;
  D.SetX('variant', IfThen(B.Variant in [bvStandard, bvToggle], '', B.VariantName));
  D.SetX('icon', B.Options.Icon);
  D.SetX('menuItems', StringReplace(Trim(B.Options.MenuItems), LineEnding, ' / ', [rfReplaceAll]));
  D.SetX('locked', IfThen(B.Enabled, '', '1'));
  D.SetX('tip', B.Hint);
  D.SetX('visibleIf', B.VisibleIf);
  D.SetX('enabledIf', B.EnabledIf);
  D.SetX('condFormat', B.CondFormat);
end;

function ButtonToLfm(B: TaButton): string;
var
  M: TMemoryStream;
  L: TStringList;
begin
  M := TMemoryStream.Create;
  L := TStringList.Create;
  try
    WriteComponentAsTextToStream(M, B);
    M.Position := 0;
    L.LoadFromStream(M);
    Result := L.Text;
  finally
    L.Free;
    M.Free;
  end;
end;

type
  TButtonLfmFinder = class
    procedure Find(Reader: TReader; const AClassName: string; var AClass: TComponentClass);
  end;

procedure TButtonLfmFinder.Find(Reader: TReader; const AClassName: string; var AClass: TComponentClass);
begin
  if SameText(AClassName, 'TaButton') then AClass := TaButton;
end;

function ButtonFromLfm(const ALfm: string; AOwner: TComponent): TaButton;
var
  M: TMemoryStream;
  C: TComponent;
  F: TButtonLfmFinder;
begin
  M := TMemoryStream.Create;
  try
    if ALfm <> '' then M.WriteBuffer(ALfm[1], Length(ALfm));
    M.Position := 0;
    C := nil;
    F := TButtonLfmFinder.Create;
    try
      ReadComponentFromTextStream(M, C, @F.Find, AOwner);
    finally
      F.Free;
    end;
    Result := C as TaButton;
  finally
    M.Free;
  end;
end;

initialization
  RegisterClass(TaButton);
  RegisterEngine(ButtonFamily, 'standard', TaButtonStdEngine);
  RegisterEngine(ButtonFamily, 'default', TaButtonDefaultEngine);
  RegisterEngine(ButtonFamily, 'cancel', TaButtonCancelEngine);
  RegisterEngine(ButtonFamily, 'toggle', TaButtonToggleEngine);
  RegisterEngine(ButtonFamily, 'flat', TaButtonFlatEngine);
  RegisterEngine(ButtonFamily, 'link', TaButtonLinkEngine);
  RegisterEngine(ButtonFamily, 'image', TaButtonImageEngine);
  RegisterEngine(ButtonFamily, 'menu', TaButtonMenuEngine);
  RegisterEngine(ButtonFamily, 'split', TaButtonSplitEngine);

end.
