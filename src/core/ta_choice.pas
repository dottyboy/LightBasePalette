unit ta_choice;
{ Obitelj Choice: izbor iz nekoliko ponudenih vrijednosti. Varijante: radio (TRadioGroup), check (TCheckGroup:
  vise vrijednosti, spremaju se odvojene zarezom) i segmented (vlastito crtanje, jedan izbor).
  Stavke su retci "kljuc=natpis" ili samo "natpis" (tada je kljuc natpis). Vrijednost je kljuc (kod check: kljucevi
  odvojeni zarezom). Isti nacin kao Edit: domacin TaChoice, pokretaci, veza na polje, definicija <-> komponenta, .lfm. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, StdCtrls, ExtCtrls, Graphics, Variants, DB, DBCtrls, LCLType, ta_family, ta_formdef;

type
  TaChoiceVariant = (chRadio, chCheck, chSegmented, chMultiSegment);

const
  ChoiceVariantNames: array[TaChoiceVariant] of string = ('radio', 'check', 'segmented', 'multisegment');
  ChoiceFamily = 'Choice';

type
  TaChoiceOptions = class(TPersistent)
  private
    FColumns, FMinSelected, FMaxSelected: Integer;
  public
    constructor Create;
    procedure Assign(ASource: TPersistent); override;
  published
    { stupaca u grupi (radio, check) }
    property Columns: Integer read FColumns write FColumns default 1;
    { vise izbora (check, multisegment): najmanje i najvise oznacenih; 0 = bez ogranicenja }
    property MinSelected: Integer read FMinSelected write FMinSelected default 0;
    property MaxSelected: Integer read FMaxSelected write FMaxSelected default 0;
  end;

  TaSegmentPaint = class(TCustomControl)
  private
    FItems: TStringList;
    FIndex: Integer;
    FReadOnly: Boolean;
    FMulti: Boolean;
    FSel: array of Boolean;
    FOnSelect: TNotifyEvent;
    procedure SetIndex(AValue: Integer);
    function GetSel(AIndex: Integer): Boolean;
    procedure SetSel(AIndex: Integer; AValue: Boolean);
    function SegmentAt(X: Integer): Integer;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure SetLabels(AValue: TStrings);
    property ItemIndex: Integer read FIndex write SetIndex;
    property Multi: Boolean read FMulti write FMulti;
    property Selected[AIndex: Integer]: Boolean read GetSel write SetSel;
    function SelectedCount: Integer;
    property ReadOnly: Boolean read FReadOnly write FReadOnly;
    property OnSelect: TNotifyEvent read FOnSelect write FOnSelect;
  end;

  TaChoiceEngine = class(TaEngine)
  private
    FKeys: TStringList;
    FSetting, FReadOnly: Boolean;
    FPrevIdx: Integer;
    FPrevChecked: string;
    FMin, FMax: Integer;
  protected
    { oznaceno je izvan dopustenog (najmanje / najvise) }
    function FLimitsBroken: Boolean;
    function SelectedTotal: Integer; virtual;
    procedure LoadKeys(AItems: TStrings; ALabels: TStrings);
    function KeyAt(AIndex: Integer): string;
    function IndexOfKey(const AKey: string): Integer;
  public
    constructor Create(AHost: TaFamilyHost); override;
    destructor Destroy; override;
    procedure SetReadOnly(AValue: Boolean); override;
  end;

  TaChoiceRadioEngine = class(TaChoiceEngine)
  private
    FGroup: TRadioGroup;
    procedure GroupClick(Sender: TObject);
  public
    constructor Create(AHost: TaFamilyHost); override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
    procedure SetItems(AItems: TStrings); override;
    procedure ApplyOptions(AOptions: TPersistent); override;
  end;

  TaChoiceCheckEngine = class(TaChoiceEngine)
  private
    FGroup: TCheckGroup;
    procedure ItemClick(Sender: TObject; Index: Integer);
    function Joined: string;
  protected
    function SelectedTotal: Integer; override;
  public
    constructor Create(AHost: TaFamilyHost); override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
    procedure SetItems(AItems: TStrings); override;
    procedure ApplyOptions(AOptions: TPersistent); override;
  end;

  TaChoiceSegmentEngine = class(TaChoiceEngine)
  private
    FSeg: TaSegmentPaint;
    FPrevMulti: string;
    procedure Selected(Sender: TObject);
    function Joined: string;
  protected
    function IsMulti: Boolean; virtual;
    function SelectedTotal: Integer; override;
  public
    constructor Create(AHost: TaFamilyHost); override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
    procedure SetItems(AItems: TStrings); override;
    procedure SetReadOnly(AValue: Boolean); override;
    procedure ApplyOptions(AOptions: TPersistent); override;
  end;

  TaChoiceMultiSegmentEngine = class(TaChoiceSegmentEngine)
  protected
    function IsMulti: Boolean; override;
  end;

  TaChoice = class(TaFamilyHost)
  private
    FVariant: TaChoiceVariant;
    FOptions: TaChoiceOptions;
    FItems: TStringList;
    FText: string;
    FTitle: string;
    FReadOnly: Boolean;
    FControlSource, FVisibleIf, FEnabledIf, FCondFormat, FExtra: string;
    FDataLink: TFieldDataLink;
    FUpdating, FSelfEdit: Boolean;
    function GetVariant: TaChoiceVariant;
    procedure SetVariant(AValue: TaChoiceVariant);
    function GetOptions: TaChoiceOptions;
    procedure SetOptions(AValue: TaChoiceOptions);
    procedure SetItemsList(AValue: TStrings);
    function GetItemsList: TStrings;
    procedure ItemsChanged(Sender: TObject);
    procedure SetReadOnly(AValue: Boolean);
    procedure SetTitle(const AValue: string);
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
    { odabrani kljuc(evi) }
    function Selected: string;
    procedure Select(const AKeys: string);
  published
    property Variant: TaChoiceVariant read GetVariant write SetVariant default chRadio;
    property Title: string read FTitle write SetTitle;
    property Items: TStrings read GetItemsList write SetItemsList;
    property Options: TaChoiceOptions read GetOptions write SetOptions;
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

{ "kljuc=natpis" -> kljuc / natpis }
function ChoiceKeyOf(const AItem: string): string;
function ChoiceLabelOf(const AItem: string): string;
function IsChoiceKind(const AKind: string): Boolean;
function ChoiceVariantFromName(const AName: string; ADefault: TaChoiceVariant = chRadio): TaChoiceVariant;
function ChoiceFromDef(D: TaControlDef; AOwner: TComponent): TaChoice;
procedure ChoiceToDef(C: TaChoice; D: TaControlDef);
function ChoiceToLfm(C: TaChoice): string;
function ChoiceFromLfm(const ALfm: string; AOwner: TComponent): TaChoice;

implementation

uses
  StrUtils, LResources, ta_tokens;

function ChoiceKeyOf(const AItem: string): string;
var
  P: Integer;
begin
  P := Pos('=', AItem);
  if P > 0 then Result := Trim(Copy(AItem, 1, P - 1)) else Result := Trim(AItem);
end;

function ChoiceLabelOf(const AItem: string): string;
var
  P: Integer;
begin
  P := Pos('=', AItem);
  if P > 0 then Result := Trim(Copy(AItem, P + 1, MaxInt)) else Result := Trim(AItem);
end;

function IsChoiceKind(const AKind: string): Boolean;
begin
  Result := SameText(AKind, 'Choice') or SameText(AKind, 'OptionGroup');
end;

function ChoiceVariantFromName(const AName: string; ADefault: TaChoiceVariant): TaChoiceVariant;
var
  V: TaChoiceVariant;
begin
  for V := Low(TaChoiceVariant) to High(TaChoiceVariant) do
    if SameText(ChoiceVariantNames[V], AName) then Exit(V);
  Result := ADefault;
end;

constructor TaChoiceOptions.Create;
begin
  inherited Create;
  FColumns := 1;
end;

procedure TaChoiceOptions.Assign(ASource: TPersistent);
begin
  if ASource is TaChoiceOptions then
  begin
    FColumns := TaChoiceOptions(ASource).FColumns;
    FMinSelected := TaChoiceOptions(ASource).FMinSelected;
    FMaxSelected := TaChoiceOptions(ASource).FMaxSelected;
  end
  else inherited Assign(ASource);
end;

{ ---------------- segmentirani izbor ---------------- }

constructor TaSegmentPaint.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BorderStyle := bsNone;      { Qt: bez okvira QAbstractScrollArea koji tema crta kao polje }
  FItems := TStringList.Create;
  FIndex := -1;
  TabStop := True;
  Width := 240;
  Height := 30;
end;

destructor TaSegmentPaint.Destroy;
begin
  FItems.Free;
  inherited Destroy;
end;

function TaSegmentPaint.GetSel(AIndex: Integer): Boolean;
begin
  Result := (AIndex >= 0) and (AIndex < Length(FSel)) and FSel[AIndex];
end;

procedure TaSegmentPaint.SetSel(AIndex: Integer; AValue: Boolean);
begin
  if (AIndex < 0) or (AIndex >= Length(FSel)) then Exit;
  FSel[AIndex] := AValue;
  Invalidate;
end;

function TaSegmentPaint.SelectedCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(FSel) do if FSel[I] then Inc(Result);
end;

procedure TaSegmentPaint.SetLabels(AValue: TStrings);
var
  I: Integer;
  Old: array of Boolean;
begin
  Old := FSel;
  SetLength(FSel, AValue.Count);
  for I := 0 to High(FSel) do FSel[I] := (I < Length(Old)) and Old[I];
  FItems.Assign(AValue);
  if FIndex >= FItems.Count then FIndex := -1;
  Invalidate;
end;

procedure TaSegmentPaint.SetIndex(AValue: Integer);
begin
  if (AValue < -1) or (AValue >= FItems.Count) then AValue := -1;
  if AValue = FIndex then Exit;
  FIndex := AValue;
  Invalidate;
end;

function TaSegmentPaint.SegmentAt(X: Integer): Integer;
begin
  if FItems.Count = 0 then Exit(-1);
  Result := X * FItems.Count div Width;
  if Result >= FItems.Count then Result := FItems.Count - 1;
  if Result < 0 then Result := 0;
end;

procedure TaSegmentPaint.Paint;
var
  T: TaThemeTokens;
  I, W, X0, X1, Tw, Th, R: Integer;
  Bg, Fg, Bd: TColor;
begin
  T := ActiveTokens;
  Canvas.Brush.Color := Color;
  Canvas.FillRect(0, 0, Width, Height);
  if FItems.Count = 0 then Exit;
  Bd := TokenColor(T.Border);
  if Focused then Bd := TokenColor(T.Accent);
  R := T.RadiusButton;
  if R > Height div 2 then R := Height div 2;
  Canvas.Brush.Color := TokenColor(T.Surface);
  Canvas.Pen.Color := Bd;
  Canvas.RoundRect(0, 0, Width, Height, R * 2, R * 2);
  Canvas.Brush.Style := bsClear;
  for I := 0 to FItems.Count - 1 do
  begin
    X0 := I * Width div FItems.Count;
    X1 := (I + 1) * Width div FItems.Count;
    W := X1 - X0;
    if (FMulti and GetSel(I)) or ((not FMulti) and (I = FIndex)) then
    begin
      Canvas.Brush.Style := bsSolid;
      Canvas.Brush.Color := TokenColor(T.Accent);
      Canvas.Pen.Color := TokenColor(T.Accent);
      Canvas.RoundRect(X0 + 2, 2, X1 - 2, Height - 2, R * 2, R * 2);
      Canvas.Brush.Style := bsClear;
      Fg := TokenColor(T.OnAccent);
    end
    else Fg := TokenColor(T.Text);
    if not Enabled then Fg := TokenColor(T.TextSoft);
    Canvas.Font.Color := Fg;
    Tw := Canvas.TextWidth(ChoiceLabelOf(FItems[I]));
    Th := Canvas.TextHeight('Ag');
    Canvas.TextOut(X0 + (W - Tw) div 2, (Height - Th) div 2, ChoiceLabelOf(FItems[I]));
  end;
  Canvas.Brush.Style := bsSolid;
  if Bg = 0 then;
end;

procedure TaSegmentPaint.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  I: Integer;
begin
  inherited MouseDown(Button, Shift, X, Y);
  if CanFocus then SetFocus;
  if FReadOnly or not Enabled then Exit;
  I := SegmentAt(X);
  if FMulti then
  begin
    if I >= 0 then
    begin
      FIndex := I;
      SetSel(I, not GetSel(I));
      if Assigned(FOnSelect) then FOnSelect(Self);
    end;
    Exit;
  end;
  if (I >= 0) and (I <> FIndex) then
  begin
    SetIndex(I);
    if Assigned(FOnSelect) then FOnSelect(Self);
  end;
end;

procedure TaSegmentPaint.KeyDown(var Key: Word; Shift: TShiftState);
var
  N: Integer;
begin
  inherited KeyDown(Key, Shift);
  if FReadOnly or (FItems.Count = 0) then Exit;
  if FMulti and (Key = VK_SPACE) and (FIndex >= 0) then
  begin
    SetSel(FIndex, not GetSel(FIndex));
    Key := 0;
    if Assigned(FOnSelect) then FOnSelect(Self);
    Exit;
  end;
  N := FIndex;
  if FMulti then
  begin
    if Key = VK_RIGHT then begin if FIndex < FItems.Count - 1 then Inc(FIndex); Key := 0; Invalidate; end
    else if Key = VK_LEFT then begin if FIndex > 0 then Dec(FIndex); Key := 0; Invalidate; end;
    Exit;
  end;
  if Key = VK_RIGHT then N := FIndex + 1
  else if Key = VK_LEFT then N := FIndex - 1
  else Exit;
  if N < 0 then N := 0;
  if N >= FItems.Count then N := FItems.Count - 1;
  Key := 0;
  if N <> FIndex then
  begin
    SetIndex(N);
    if Assigned(FOnSelect) then FOnSelect(Self);
  end;
end;

{ ---------------- pokretaci ---------------- }

constructor TaChoiceEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FKeys := TStringList.Create;
  FPrevIdx := -1;
end;

destructor TaChoiceEngine.Destroy;
begin
  FKeys.Free;
  inherited Destroy;
end;

procedure TaChoiceEngine.LoadKeys(AItems: TStrings; ALabels: TStrings);
var
  I: Integer;
begin
  FKeys.Clear;
  ALabels.Clear;
  for I := 0 to AItems.Count - 1 do
  begin
    FKeys.Add(ChoiceKeyOf(AItems[I]));
    ALabels.Add(ChoiceLabelOf(AItems[I]));
  end;
end;

function TaChoiceEngine.KeyAt(AIndex: Integer): string;
begin
  if (AIndex >= 0) and (AIndex < FKeys.Count) then Result := FKeys[AIndex] else Result := '';
end;

function TaChoiceEngine.IndexOfKey(const AKey: string): Integer;
var
  I: Integer;
begin
  for I := 0 to FKeys.Count - 1 do
    if SameText(FKeys[I], AKey) then Exit(I);
  Result := -1;
end;

function TaChoiceEngine.SelectedTotal: Integer;
begin
  Result := 0;
end;

function TaChoiceEngine.FLimitsBroken: Boolean;
var
  N: Integer;
begin
  N := SelectedTotal;
  Result := ((FMax > 0) and (N > FMax)) or ((FMin > 0) and (N < FMin));
end;

procedure TaChoiceEngine.SetReadOnly(AValue: Boolean);
begin
  FReadOnly := AValue;
end;

constructor TaChoiceRadioEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FGroup := TRadioGroup.Create(nil);
  FGroup.AutoSize := False;
  FGroup.OnClick := @GroupClick;
  AttachInner(FGroup);
end;

procedure TaChoiceRadioEngine.GroupClick(Sender: TObject);
begin
  if FSetting then Exit;
  if FReadOnly then
  begin
    FSetting := True;
    try
      FGroup.ItemIndex := FPrevIdx;
    finally
      FSetting := False;
    end;
    Exit;
  end;
  FPrevIdx := FGroup.ItemIndex;
  InnerChanged(Sender);
end;

function TaChoiceRadioEngine.GetText: string;
begin
  Result := KeyAt(FGroup.ItemIndex);
end;

procedure TaChoiceRadioEngine.SetText(const AValue: string);
begin
  FSetting := True;
  try
    FGroup.ItemIndex := IndexOfKey(AValue);
    FPrevIdx := FGroup.ItemIndex;
  finally
    FSetting := False;
  end;
end;

procedure TaChoiceRadioEngine.SetItems(AItems: TStrings);
var
  Lb: TStringList;
  Keep: string;
begin
  Keep := GetText;
  Lb := TStringList.Create;
  try
    LoadKeys(AItems, Lb);
    FSetting := True;
    try
      FGroup.Items.Assign(Lb);
    finally
      FSetting := False;
    end;
  finally
    Lb.Free;
  end;
  SetText(Keep);
end;

procedure TaChoiceRadioEngine.ApplyOptions(AOptions: TPersistent);
begin
  if (AOptions is TaChoiceOptions) and (TaChoiceOptions(AOptions).Columns > 0) then
    FGroup.Columns := TaChoiceOptions(AOptions).Columns;
end;

constructor TaChoiceCheckEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FGroup := TCheckGroup.Create(nil);
  FGroup.AutoSize := False;
  FGroup.OnItemClick := @ItemClick;
  AttachInner(FGroup);
end;

function TaChoiceCheckEngine.SelectedTotal: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to FGroup.Items.Count - 1 do if FGroup.Checked[I] then Inc(Result);
end;

function TaChoiceCheckEngine.Joined: string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to FGroup.Items.Count - 1 do
    if FGroup.Checked[I] then
    begin
      if Result <> '' then Result := Result + ',';
      Result := Result + KeyAt(I);
    end;
end;

procedure TaChoiceCheckEngine.ItemClick(Sender: TObject; Index: Integer);
var
  Back: TStringList;
  I: Integer;
begin
  if FSetting then Exit;
  if FReadOnly or FLimitsBroken then
  begin
    FSetting := True;
    try
      Back := TStringList.Create;
      try
        Back.CommaText := FPrevChecked;
        for I := 0 to FGroup.Items.Count - 1 do FGroup.Checked[I] := Back.IndexOf(KeyAt(I)) >= 0;
      finally
        Back.Free;
      end;
    finally
      FSetting := False;
    end;
    Exit;
  end;
  FPrevChecked := Joined;
  InnerChanged(Sender);
end;

function TaChoiceCheckEngine.GetText: string;
begin
  Result := Joined;
end;

procedure TaChoiceCheckEngine.SetText(const AValue: string);
var
  L: TStringList;
  I: Integer;
begin
  L := TStringList.Create;
  try
    L.CommaText := AValue;
    FSetting := True;
    try
      for I := 0 to FGroup.Items.Count - 1 do FGroup.Checked[I] := L.IndexOf(KeyAt(I)) >= 0;
    finally
      FSetting := False;
    end;
    FPrevChecked := Joined;
  finally
    L.Free;
  end;
end;

procedure TaChoiceCheckEngine.SetItems(AItems: TStrings);
var
  Lb: TStringList;
  Keep: string;
begin
  Keep := Joined;
  Lb := TStringList.Create;
  try
    LoadKeys(AItems, Lb);
    FSetting := True;
    try
      FGroup.Items.Assign(Lb);
    finally
      FSetting := False;
    end;
  finally
    Lb.Free;
  end;
  SetText(Keep);
end;

procedure TaChoiceCheckEngine.ApplyOptions(AOptions: TPersistent);
begin
  if AOptions is TaChoiceOptions then
  begin
    FMin := TaChoiceOptions(AOptions).MinSelected;
    FMax := TaChoiceOptions(AOptions).MaxSelected;
    if TaChoiceOptions(AOptions).Columns > 0 then FGroup.Columns := TaChoiceOptions(AOptions).Columns;
  end;
end;

constructor TaChoiceSegmentEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FSeg := TaSegmentPaint.Create(nil);
  FSeg.Multi := IsMulti;
  FSeg.OnSelect := @Selected;
  AttachInner(FSeg);
end;

function TaChoiceSegmentEngine.IsMulti: Boolean;
begin
  Result := False;
end;

function TaChoiceMultiSegmentEngine.IsMulti: Boolean;
begin
  Result := True;
end;

function TaChoiceSegmentEngine.SelectedTotal: Integer;
begin
  Result := FSeg.SelectedCount;
end;

function TaChoiceSegmentEngine.Joined: string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to FKeys.Count - 1 do
    if FSeg.Selected[I] then
    begin
      if Result <> '' then Result := Result + ',';
      Result := Result + KeyAt(I);
    end;
end;

procedure TaChoiceSegmentEngine.Selected(Sender: TObject);
var
  Back: TStringList;
  I: Integer;
begin
  if IsMulti then
  begin
    if FReadOnly or (FLimitsBroken) then
    begin
      Back := TStringList.Create;
      try
        Back.CommaText := FPrevMulti;
        for I := 0 to FKeys.Count - 1 do FSeg.Selected[I] := Back.IndexOf(KeyAt(I)) >= 0;
      finally
        Back.Free;
      end;
      Exit;
    end;
    FPrevMulti := Joined;
  end
  else FPrevIdx := FSeg.ItemIndex;
  InnerChanged(Sender);
end;

function TaChoiceSegmentEngine.GetText: string;
begin
  if IsMulti then Result := Joined else Result := KeyAt(FSeg.ItemIndex);
end;

procedure TaChoiceSegmentEngine.SetText(const AValue: string);
var
  L: TStringList;
  I: Integer;
begin
  if IsMulti then
  begin
    L := TStringList.Create;
    try
      L.CommaText := AValue;
      for I := 0 to FKeys.Count - 1 do FSeg.Selected[I] := L.IndexOf(KeyAt(I)) >= 0;
    finally
      L.Free;
    end;
    FPrevMulti := Joined;
  end
  else
  begin
    FSeg.ItemIndex := IndexOfKey(AValue);
    FPrevIdx := FSeg.ItemIndex;
  end;
end;

procedure TaChoiceSegmentEngine.SetItems(AItems: TStrings);
var
  Lb: TStringList;
  Keep: string;
begin
  Keep := GetText;
  Lb := TStringList.Create;
  try
    LoadKeys(AItems, Lb);
    FSeg.SetLabels(Lb);
  finally
    Lb.Free;
  end;
  SetText(Keep);
end;

procedure TaChoiceSegmentEngine.SetReadOnly(AValue: Boolean);
begin
  inherited SetReadOnly(AValue);
  FSeg.ReadOnly := AValue;
end;

procedure TaChoiceSegmentEngine.ApplyOptions(AOptions: TPersistent);
begin
  if AOptions is TaChoiceOptions then
  begin
    FMin := TaChoiceOptions(AOptions).MinSelected;
    FMax := TaChoiceOptions(AOptions).MaxSelected;
  end;
end;

{ ---------------- TaChoice ---------------- }

constructor TaChoice.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FItems := TStringList.Create;
  FItems.OnChange := @ItemsChanged;
  FDataLink := TFieldDataLink.Create;
  FDataLink.Control := Self;
  FDataLink.OnDataChange := @DataChange;
  FDataLink.OnUpdateData := @UpdateData;
  FOptions := TaChoiceOptions.Create;
  FVariant := chRadio;
  Width := 200;
  Height := 90;
  ReplaceEngine;
  PushToEngine;
end;

destructor TaChoice.Destroy;
begin
  FDataLink.OnDataChange := nil;
  FDataLink.OnUpdateData := nil;
  FDataLink.Free;
  FOptions.Free;
  FItems.Free;
  inherited Destroy;
end;

function TaChoice.CreateEngine: TaEngine;
var
  C: TaEngineClass;
begin
  C := FindEngine(ChoiceFamily, ChoiceVariantNames[FVariant]);
  if C = nil then C := FindEngine(ChoiceFamily, 'radio');
  Result := C.Create(Self);
end;

function TaChoice.VariantName: string;
begin
  Result := ChoiceVariantNames[FVariant];
end;

function TaChoice.GetVariant: TaChoiceVariant;
begin
  Result := FVariant;
end;

procedure TaChoice.SetVariant(AValue: TaChoiceVariant);
begin
  if AValue = FVariant then Exit;
  FText := RealGetText;
  FVariant := AValue;
  ReplaceEngine;
  PushToEngine;
end;

function TaChoice.GetOptions: TaChoiceOptions;
begin
  Result := FOptions;
end;

procedure TaChoice.SetOptions(AValue: TaChoiceOptions);
begin
  FOptions.Assign(AValue);
  if Engine <> nil then Engine.ApplyOptions(FOptions);
end;

procedure TaChoice.SetItemsList(AValue: TStrings);
begin
  FItems.Assign(AValue);
end;

function TaChoice.GetItemsList: TStrings;
begin
  Result := FItems;
end;

procedure TaChoice.ItemsChanged(Sender: TObject);
begin
  if (Engine <> nil) and not (csLoading in ComponentState) then
  begin
    FUpdating := True;
    try
      Engine.SetItems(FItems);
    finally
      FUpdating := False;
    end;
  end;
end;

procedure TaChoice.PushToEngine;
begin
  if Engine = nil then Exit;
  FUpdating := True;
  try
    Engine.ApplyOptions(FOptions);
    Engine.SetItems(FItems);
    Engine.SetText(FText);
    Engine.SetReadOnly(FReadOnly);
    if (Engine.Inner is TCustomGroupBox) then Engine.Inner.Caption := FTitle;
  finally
    FUpdating := False;
  end;
end;

procedure TaChoice.SetReadOnly(AValue: Boolean);
begin
  if FReadOnly = AValue then Exit;
  FReadOnly := AValue;
  if Engine <> nil then Engine.SetReadOnly(AValue);
end;

procedure TaChoice.SetTitle(const AValue: string);
begin
  FTitle := AValue;
  if (Engine <> nil) and (Engine.Inner is TCustomGroupBox) then Engine.Inner.Caption := AValue;
end;

function TaChoice.RealGetText: TCaption;
begin
  if Engine <> nil then Result := Engine.GetText else Result := FText;
end;

procedure TaChoice.RealSetText(const AValue: TCaption);
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

function TaChoice.Selected: string;
begin
  Result := RealGetText;
end;

procedure TaChoice.Select(const AKeys: string);
begin
  RealSetText(AKeys);
end;

procedure TaChoice.EngineChanged;
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
    try
      FDataLink.UpdateRecord;
    except
      FDataLink.Reset;
      raise;
    end;
  end;
  inherited EngineChanged;
end;

function TaChoice.GetDataSource: TDataSource;
begin
  Result := FDataLink.DataSource;
end;

procedure TaChoice.SetDataSource(AValue: TDataSource);
begin
  FDataLink.DataSource := AValue;
  if AValue <> nil then AValue.FreeNotification(Self);
end;

function TaChoice.GetDataField: string;
begin
  Result := FDataLink.FieldName;
end;

procedure TaChoice.SetDataField(const AValue: string);
begin
  FDataLink.FieldName := AValue;
end;

procedure TaChoice.Notification(AComponent: TComponent; AOperation: TOperation);
begin
  inherited Notification(AComponent, AOperation);
  if (AOperation = opRemove) and (FDataLink <> nil) and (AComponent = FDataLink.DataSource) then
    FDataLink.DataSource := nil;
end;

procedure TaChoice.Loaded;
begin
  inherited Loaded;
  PushToEngine;
end;

procedure TaChoice.DataChange(Sender: TObject);
var
  F: TField;
begin
  if FSelfEdit then Exit;
  F := FDataLink.Field;
  FUpdating := True;
  try
    if (F = nil) or F.IsNull then Engine.SetText('')
    else Engine.SetText(F.AsString);
  finally
    FUpdating := False;
  end;
end;

procedure TaChoice.UpdateData(Sender: TObject);
var
  F: TField;
  S: string;
begin
  F := FDataLink.Field;
  if F = nil then Exit;
  S := Engine.GetText;
  if S = '' then F.Clear
  else
    case F.DataType of
      ftSmallint, ftInteger, ftLargeint, ftWord, ftAutoInc: F.AsInteger := StrToIntDef(S, 0);
      ftFloat, ftCurrency, ftBCD, ftFMTBcd: F.AsFloat := StrToFloatDef(S, 0);
    else
      F.AsString := S;
    end;
end;

{ ---------------- definicija kontrole <-> komponenta ---------------- }

const
  OwnKeys = ',variant,tip,locked,visibleIf,enabledIf,condFormat,columns,minSelected,maxSelected,';

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

{ RowSource definicije: "list:kljuc=natpis;kljuc=natpis" ili retci }
function ItemsFromRowSource(const ASource: string; AItems: TStrings): Boolean;
var
  S: string;
begin
  Result := False;
  S := Trim(ASource);
  if LowerCase(Copy(S, 1, 5)) = 'list:' then
  begin
    S := Copy(S, 6, MaxInt);
    AItems.Delimiter := ';';
    AItems.StrictDelimiter := True;
    AItems.DelimitedText := S;
    Result := True;
  end
  else if (S <> '') and (Pos('sql:', LowerCase(S)) <> 1) and (Pos('fgl:', LowerCase(S)) <> 1) and (Pos('select ', LowerCase(S)) <> 1) then
  begin
    AItems.Text := StringReplace(S, ';', LineEnding, [rfReplaceAll]);
    Result := AItems.Count > 0;
  end;
end;

function ChoiceFromDef(D: TaControlDef; AOwner: TComponent): TaChoice;
var
  L: TStringList;
  S: string;
begin
  Result := TaChoice.Create(AOwner);
  try
    Result.Name := D.Name;
    Result.SetBounds(D.Left, D.Top, D.Width, D.Height);
    Result.Variant := ChoiceVariantFromName(D.GetX('variant'), chRadio);
    Result.Title := D.Caption;
    Result.ControlSource := D.ControlSource;
    Result.ReadOnly := D.GetX('locked') = '1';
    Result.Hint := D.GetX('tip');
    Result.VisibleIf := D.GetX('visibleIf');
    Result.EnabledIf := D.GetX('enabledIf');
    Result.CondFormat := D.GetX('condFormat');
    Result.Options.Columns := StrToIntDef(D.GetX('columns'), 1);
    Result.Options.MinSelected := StrToIntDef(D.GetX('minSelected'), 0);
    Result.Options.MaxSelected := StrToIntDef(D.GetX('maxSelected'), 0);
    Result.Options := Result.Options;
    L := TStringList.Create;
    try
      S := D.GetX('items');
      if S <> '' then
      begin
        L.Delimiter := ';';
        L.StrictDelimiter := True;
        L.DelimitedText := S;
      end
      else ItemsFromRowSource(D.RowSource, L);
      Result.Items.Assign(L);
    finally
      L.Free;
    end;
    Result.Extra := ExtraWithout(D.Extra);
  except
    Result.Free;
    raise;
  end;
end;

procedure ChoiceToDef(C: TaChoice; D: TaControlDef);
var
  I: Integer;
  S: string;
begin
  D.Kind := 'OptionGroup';
  D.Name := C.Name;
  D.Left := C.Left; D.Top := C.Top; D.Width := C.Width; D.Height := C.Height;
  D.Caption := C.Title;
  D.ControlSource := C.ControlSource;
  D.Extra := C.Extra;
  D.SetX('variant', IfThen(C.Variant = chRadio, '', C.VariantName));
  D.SetX('locked', IfThen(C.ReadOnly, '1', ''));
  D.SetX('tip', C.Hint);
  D.SetX('visibleIf', C.VisibleIf);
  D.SetX('enabledIf', C.EnabledIf);
  D.SetX('condFormat', C.CondFormat);
  D.SetX('columns', IfThen(C.Options.Columns <> 1, IntToStr(C.Options.Columns), ''));
  D.SetX('minSelected', IfThen(C.Options.MinSelected <> 0, IntToStr(C.Options.MinSelected), ''));
  D.SetX('maxSelected', IfThen(C.Options.MaxSelected <> 0, IntToStr(C.Options.MaxSelected), ''));
  S := '';
  for I := 0 to C.Items.Count - 1 do
  begin
    if S <> '' then S := S + ';';
    S := S + C.Items[I];
  end;
  D.SetX('items', S);
end;

function ChoiceToLfm(C: TaChoice): string;
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
  TChoiceLfmFinder = class
    procedure Find(Reader: TReader; const AClassName: string; var AClass: TComponentClass);
  end;

procedure TChoiceLfmFinder.Find(Reader: TReader; const AClassName: string; var AClass: TComponentClass);
begin
  if SameText(AClassName, 'TaChoice') then AClass := TaChoice;
end;

function ChoiceFromLfm(const ALfm: string; AOwner: TComponent): TaChoice;
var
  M: TMemoryStream;
  C: TComponent;
  F: TChoiceLfmFinder;
begin
  M := TMemoryStream.Create;
  try
    if ALfm <> '' then M.WriteBuffer(ALfm[1], Length(ALfm));
    M.Position := 0;
    C := nil;
    F := TChoiceLfmFinder.Create;
    try
      ReadComponentFromTextStream(M, C, @F.Find, AOwner);
    finally
      F.Free;
    end;
    Result := C as TaChoice;
  finally
    M.Free;
  end;
end;

initialization
  RegisterClass(TaChoice);
  RegisterEngine(ChoiceFamily, 'radio', TaChoiceRadioEngine);
  RegisterEngine(ChoiceFamily, 'check', TaChoiceCheckEngine);
  RegisterEngine(ChoiceFamily, 'segmented', TaChoiceSegmentEngine);
  RegisterEngine(ChoiceFamily, 'multisegment', TaChoiceMultiSegmentEngine);

end.
