unit ta_panel;
{ Obitelj Panel: spremnik za druge kontrole. Varijante: plain (TPanel), group (TGroupBox), card (kartica, vlastito
  crtanje po tokenima teme) i expander (naslov koji sklapa i otvara sadrzaj). Kontrole se spustaju na domacina
  TaPanel (pokretac je pozadina ispod njih) i spremaju se s njim u .lfm. Nije jos: scroll i splitter. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, StdCtrls, ExtCtrls, Graphics, Variants, LCLType, Forms, ta_family, ta_formdef;

type
  TaPanelVariant = (pvPlain, pvGroup, pvCard, pvExpander, pvScroll, pvSplitter);

const
  PanelVariantNames: array[TaPanelVariant] of string = ('plain', 'group', 'card', 'expander', 'scroll', 'splitter');
  PanelFamily = 'Panel';
  ExpanderHeader = 28;

type
  TaPanelOptions = class(TPersistent)
  private
    FExpanded: Boolean;
    FMinSize: Integer;
  public
    constructor Create;
    procedure Assign(ASource: TPersistent); override;
  published
    { samo za expander: sadrzaj je otvoren }
    property Expanded: Boolean read FExpanded write FExpanded default True;
    { samo za splitter: najmanja velicina susjeda kojem se mijenja velicina }
    property MinSize: Integer read FMinSize write FMinSize default 30;
  end;

  { pozadina: kartica i expander }
  TaPanelPaint = class(TCustomControl)
  private
    FCaption: string;
    FExpander: Boolean;
    FOpen: Boolean;
    FOnToggle: TNotifyEvent;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure RenderTo(C: TCanvas);
    property CaptionText: string read FCaption write FCaption;
    property IsExpander: Boolean read FExpander write FExpander;
    property Open: Boolean read FOpen write FOpen;
    property OnToggle: TNotifyEvent read FOnToggle write FOnToggle;
  end;

  { vucna crta: povlacenje mijenja velicinu susjeda (prema poravnanju domacina) }
  TaSplitPaint = class(TCustomControl)
  private
    FDown: Boolean;
    FStart: Integer;
    FOnDrag: TNotifyEvent;
    FDelta: Integer;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure RenderTo(C: TCanvas);
    { pomak od zadnjeg poziva (px po osi povlacenja) }
    property Delta: Integer read FDelta;
    property OnDrag: TNotifyEvent read FOnDrag write FOnDrag;
  end;

  TaPanelSplitterEngine = class(TaEngine)
  private
    FSplit: TaSplitPaint;
    procedure Dragged(Sender: TObject);
  public
    constructor Create(AHost: TaFamilyHost); override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
    property Painter: TaSplitPaint read FSplit;
  end;

  TaPanelPlainEngine = class(TaEngine)
  protected
    FPanel: TPanel;
  public
    constructor Create(AHost: TaFamilyHost); override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
  end;

  TaPanelScrollEngine = class(TaPanelPlainEngine)
  public
    constructor Create(AHost: TaFamilyHost); override;
  end;

  TaPanelGroupEngine = class(TaEngine)
  private
    FGroup: TGroupBox;
  public
    constructor Create(AHost: TaFamilyHost); override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
  end;

  TaPanelCardEngine = class(TaEngine)
  private
    FPaint: TaPanelPaint;
  protected
    function AsExpander: Boolean; virtual;
    procedure Toggled(Sender: TObject);
  public
    constructor Create(AHost: TaFamilyHost); override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
    function GetValue: Variant; override;
    procedure SetValue(const AValue: Variant); override;
  end;

  TaPanelExpanderEngine = class(TaPanelCardEngine)
  protected
    function AsExpander: Boolean; override;
  end;

  TaPanel = class(TaFamilyHost)
  private
    FVariant: TaPanelVariant;
    FOptions: TaPanelOptions;
    FText: string;
    FFullHeight: Integer;
    FExtra, FVisibleIf, FEnabledIf: string;
    FVBar, FHBar: TScrollBar;
    FOffX, FOffY: Integer;
    FInScroll: Boolean;
    procedure ScrollChanged(Sender: TObject);
    procedure EnsureBars;
    function ContentExtent(out AW, AH: Integer): Boolean;
    function GetVariant: TaPanelVariant;
    procedure SetVariant(AValue: TaPanelVariant);
    function GetOptions: TaPanelOptions;
    procedure SetOptions(AValue: TaPanelOptions);
    function GetExpanded: Boolean;
    procedure SetExpanded(AValue: Boolean);
    procedure PushToEngine;
  protected
    function CreateEngine: TaEngine; override;
    procedure EngineChanged; override;
    function RealGetText: TCaption; override;
    procedure RealSetText(const AValue: TCaption); override;
    procedure GetChildren(Proc: TGetChildProc; Root: TComponent); override;
    procedure AlignControls(AControl: TControl; var ARect: TRect); override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function VariantName: string;
    { scroll: pomak sadrzaja u tockama i uskladivanje traka (poziva se i sam kad se djeca promijene) }
    procedure UpdateScroll;
    procedure ScrollTo(AX, AY: Integer);
    property ScrollX: Integer read FOffX;
    property ScrollY: Integer read FOffY;
    function VerticalBar: TScrollBar;
    function HorizontalBar: TScrollBar;
    { splitter: povuci rub za ADelta tocaka (susjed prema poravnanju domacina) }
    function DragSplitter(ADelta: Integer): Integer;
  published
    property Variant: TaPanelVariant read GetVariant write SetVariant default pvPlain;
    property Caption;
    property Options: TaPanelOptions read GetOptions write SetOptions;
    { expander: sadrzaj otvoren }
    property Expanded: Boolean read GetExpanded write SetExpanded default True;
    property VisibleIf: string read FVisibleIf write FVisibleIf;
    property EnabledIf: string read FEnabledIf write FEnabledIf;
    property Extra: string read FExtra write FExtra;
    property Align;
    property Anchors;
    property Enabled;
    property Visible;
    property Hint;
    property ShowHint;
    property PopupMenu;
  end;

function IsPanelKind(const AKind: string): Boolean;
function PanelVariantFromName(const AName: string; ADefault: TaPanelVariant = pvPlain): TaPanelVariant;
function PanelFromDef(D: TaControlDef; AOwner: TComponent): TaPanel;
procedure PanelToDef(P: TaPanel; D: TaControlDef);
function PanelToLfm(P: TaPanel): string;
function PanelFromLfm(const ALfm: string; AOwner: TComponent): TaPanel;

implementation

uses
  StrUtils, LResources, ta_tokens;

function IsPanelKind(const AKind: string): Boolean;
begin
  Result := SameText(AKind, 'Panel') or SameText(AKind, 'Rectangle');
end;

function PanelVariantFromName(const AName: string; ADefault: TaPanelVariant): TaPanelVariant;
var
  V: TaPanelVariant;
begin
  for V := Low(TaPanelVariant) to High(TaPanelVariant) do
    if SameText(PanelVariantNames[V], AName) then Exit(V);
  Result := ADefault;
end;

constructor TaPanelOptions.Create;
begin
  inherited Create;
  FExpanded := True;
  FMinSize := 30;
end;

procedure TaPanelOptions.Assign(ASource: TPersistent);
begin
  if ASource is TaPanelOptions then
  begin
    FExpanded := TaPanelOptions(ASource).FExpanded;
    FMinSize := TaPanelOptions(ASource).FMinSize;
  end
  else inherited Assign(ASource);
end;

{ ---------------- crtanje ---------------- }

constructor TaPanelPaint.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BorderStyle := bsNone;      { Qt: bez okvira QAbstractScrollArea koji tema crta kao polje }
  FOpen := True;
end;

procedure TaPanelPaint.Paint;
begin
  RenderTo(Canvas);
end;

procedure TaPanelPaint.RenderTo(C: TCanvas);
var
  T: TaThemeTokens;
  R, Th, Cx, Cy: Integer;
begin
  T := ActiveTokens;
  C.Brush.Color := Color;
  C.FillRect(0, 0, Width, Height);
  R := T.RadiusCard;
  if R > 24 then R := 24;
  C.Brush.Color := TokenColor(T.Surface);
  C.Pen.Color := TokenColor(T.Border);
  C.RoundRect(0, 0, Width, Height, R * 2, R * 2);
  if FExpander then
  begin
    C.Font.Color := TokenColor(T.Text);
    C.Font.Style := [fsBold];
    C.Brush.Style := bsClear;
    Th := C.TextHeight('Ag');
    C.TextOut(30, (ExpanderHeader - Th) div 2, FCaption);
    { strelica }
    Cx := 14;
    Cy := ExpanderHeader div 2;
    C.Pen.Color := TokenColor(T.TextSoft);
    C.Pen.Width := 2;
    if FOpen then begin C.MoveTo(Cx - 4, Cy - 2); C.LineTo(Cx, Cy + 3); C.LineTo(Cx + 5, Cy - 2); end
    else begin C.MoveTo(Cx - 2, Cy - 4); C.LineTo(Cx + 3, Cy); C.LineTo(Cx - 2, Cy + 5); end;
    C.Pen.Width := 1;
    if FOpen and (Height > ExpanderHeader) then
    begin
      C.Pen.Color := TokenColor(T.Border);
      C.MoveTo(1, ExpanderHeader);
      C.LineTo(Width - 1, ExpanderHeader);
    end;
  end;
  C.Brush.Style := bsSolid;
end;

procedure TaPanelPaint.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if FExpander and (Y < ExpanderHeader) and Assigned(FOnToggle) then FOnToggle(Self);
end;

{ ---------------- pokretaci ---------------- }

constructor TaPanelPlainEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FPanel := TPanel.Create(nil);
  FPanel.BevelOuter := bvLowered;
  FPanel.Caption := '';
  AttachInner(FPanel);
end;

function TaPanelPlainEngine.GetText: string;
begin
  Result := FPanel.Caption;
end;

procedure TaPanelPlainEngine.SetText(const AValue: string);
begin
  FPanel.Caption := AValue;
end;

constructor TaPanelGroupEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FGroup := TGroupBox.Create(nil);
  AttachInner(FGroup);
end;

function TaPanelGroupEngine.GetText: string;
begin
  Result := FGroup.Caption;
end;

procedure TaPanelGroupEngine.SetText(const AValue: string);
begin
  FGroup.Caption := AValue;
end;

constructor TaPanelCardEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FPaint := TaPanelPaint.Create(nil);
  FPaint.IsExpander := AsExpander;
  FPaint.OnToggle := @Toggled;
  AttachInner(FPaint);
end;

function TaPanelCardEngine.AsExpander: Boolean;
begin
  Result := False;
end;

function TaPanelExpanderEngine.AsExpander: Boolean;
begin
  Result := True;
end;

procedure TaPanelCardEngine.Toggled(Sender: TObject);
begin
  FPaint.Open := not FPaint.Open;
  FPaint.Invalidate;
  InnerChanged(Sender);
end;

function TaPanelCardEngine.GetText: string;
begin
  Result := FPaint.CaptionText;
end;

procedure TaPanelCardEngine.SetText(const AValue: string);
begin
  FPaint.CaptionText := AValue;
  FPaint.Invalidate;
end;

function TaPanelCardEngine.GetValue: Variant;
begin
  Result := FPaint.Open;
end;

procedure TaPanelCardEngine.SetValue(const AValue: Variant);
begin
  if VarIsNull(AValue) or VarIsEmpty(AValue) then FPaint.Open := True
  else if VarIsType(AValue, varBoolean) then FPaint.Open := Boolean(AValue)
  else FPaint.Open := Double(AValue) <> 0;
  FPaint.Invalidate;
end;

{ ---------------- splitter ---------------- }

constructor TaSplitPaint.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BorderStyle := bsNone;
  Width := 6;
  Height := 60;
end;

procedure TaSplitPaint.Paint;
begin
  RenderTo(Canvas);
end;

procedure TaSplitPaint.RenderTo(C: TCanvas);
var
  T: TaThemeTokens;
  I, N, Cx, Cy: Integer;
begin
  T := ActiveTokens;
  C.Brush.Color := TokenColor(T.Soft);
  C.FillRect(0, 0, Width, Height);
  C.Brush.Color := TokenColor(T.TextSoft);
  Cx := Width div 2;
  Cy := Height div 2;
  { tri tockice kao rucka }
  for I := -1 to 1 do
    if Height >= Width then C.FillRect(Cx - 1, Cy + I * 6 - 1, Cx + 1, Cy + I * 6 + 1)
    else C.FillRect(Cx + I * 6 - 1, Cy - 1, Cx + I * 6 + 1, Cy + 1);
  N := 0;
  if N = 1 then;
end;

procedure TaSplitPaint.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then Exit;
  FDown := True;
  if Height >= Width then FStart := Mouse.CursorPos.X else FStart := Mouse.CursorPos.Y;
end;

procedure TaSplitPaint.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  P: Integer;
begin
  inherited MouseMove(Shift, X, Y);
  if Height >= Width then Cursor := crHSplit else Cursor := crVSplit;
  if not FDown then Exit;
  if Height >= Width then P := Mouse.CursorPos.X else P := Mouse.CursorPos.Y;
  FDelta := P - FStart;
  if (FDelta <> 0) and Assigned(FOnDrag) then
  begin
    FOnDrag(Self);
    { host se pomaknuo za primijenjeni pomak: pocetak je sada tamo gdje je pokazivac }
    FStart := P;
  end;
end;

procedure TaSplitPaint.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  FDown := False;
end;

constructor TaPanelSplitterEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FSplit := TaSplitPaint.Create(nil);
  FSplit.OnDrag := @Dragged;
  AttachInner(FSplit);
end;

procedure TaPanelSplitterEngine.Dragged(Sender: TObject);
begin
  if Host is TaPanel then TaPanel(Host).DragSplitter(FSplit.Delta);
end;

function TaPanelSplitterEngine.GetText: string;
begin
  Result := '';
end;

procedure TaPanelSplitterEngine.SetText(const AValue: string);
begin
end;

constructor TaPanelScrollEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FPanel.BevelOuter := bvNone;
end;

{ ---------------- TaPanel ---------------- }

constructor TaPanel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csAcceptsControls];
  FOptions := TaPanelOptions.Create;
  FVariant := pvPlain;
  Width := 200;
  Height := 120;
  ReplaceEngine;
  PushToEngine;
end;

destructor TaPanel.Destroy;
begin
  FOptions.Free;
  inherited Destroy;
end;

function TaPanel.CreateEngine: TaEngine;
var
  C: TaEngineClass;
begin
  C := FindEngine(PanelFamily, PanelVariantNames[FVariant]);
  if C = nil then C := FindEngine(PanelFamily, 'plain');
  Result := C.Create(Self);
end;

function TaPanel.VariantName: string;
begin
  Result := PanelVariantNames[FVariant];
end;

function TaPanel.GetVariant: TaPanelVariant;
begin
  Result := FVariant;
end;

procedure TaPanel.SetVariant(AValue: TaPanelVariant);
begin
  if AValue = FVariant then Exit;
  FText := RealGetText;
  FVariant := AValue;
  ReplaceEngine;
  PushToEngine;
  { pokretac je opet prvi, ispod kontrola }
  if Engine.Inner <> nil then Engine.Inner.SendToBack;
  UpdateScroll;
end;

function TaPanel.GetOptions: TaPanelOptions;
begin
  Result := FOptions;
end;

procedure TaPanel.SetOptions(AValue: TaPanelOptions);
begin
  FOptions.Assign(AValue);
  SetExpanded(FOptions.Expanded);
end;

function TaPanel.GetExpanded: Boolean;
var
  V: System.Variant;
begin
  if (Engine = nil) or (FVariant <> pvExpander) then Exit(FOptions.Expanded);
  V := Engine.GetValue;
  Result := (not VarIsNull(V)) and Boolean(V);
end;

procedure TaPanel.SetExpanded(AValue: Boolean);
begin
  FOptions.Expanded := AValue;
  if (Engine = nil) or (FVariant <> pvExpander) then Exit;
  if AValue = GetExpanded then
  begin
    if (not AValue) and (Height <> ExpanderHeader) then begin FFullHeight := Height; Height := ExpanderHeader; end;
    Exit;
  end;
  Engine.SetValue(AValue);
  if AValue then
  begin
    if FFullHeight > ExpanderHeader then Height := FFullHeight;
  end
  else
  begin
    FFullHeight := Height;
    Height := ExpanderHeader;
  end;
end;

procedure TaPanel.PushToEngine;
begin
  if Engine = nil then Exit;
  Engine.SetText(FText);
  if FVariant = pvExpander then
  begin
    Engine.SetValue(FOptions.Expanded);
    if (not FOptions.Expanded) and (Height > ExpanderHeader) then begin FFullHeight := Height; Height := ExpanderHeader; end;
  end;
end;

procedure TaPanel.EngineChanged;
begin
  { klik na naslov expandera: sklopi ili otvori }
  if (FVariant = pvExpander) and (Engine <> nil) then
  begin
    FOptions.Expanded := Boolean(Engine.GetValue);
    if FOptions.Expanded then
    begin
      if FFullHeight > ExpanderHeader then Height := FFullHeight;
    end
    else
    begin
      if Height > ExpanderHeader then FFullHeight := Height;
      Height := ExpanderHeader;
    end;
  end;
  inherited EngineChanged;
end;

function TaPanel.RealGetText: TCaption;
begin
  if Engine <> nil then Result := Engine.GetText else Result := FText;
end;

procedure TaPanel.RealSetText(const AValue: TCaption);
begin
  FText := AValue;
  if Engine <> nil then Engine.SetText(AValue);
end;

procedure TaPanel.GetChildren(Proc: TGetChildProc; Root: TComponent);
var
  I: Integer;
begin
  { sprema se sve osim pokretaca i traka za pomicanje }
  for I := 0 to ControlCount - 1 do
    if ((Engine = nil) or (Controls[I] <> Engine.Inner)) and (Controls[I] <> FVBar) and (Controls[I] <> FHBar) then Proc(Controls[I]);
end;

{ ---------------- scroll ---------------- }

procedure TaPanel.EnsureBars;
begin
  if FVBar = nil then
  begin
    FVBar := TScrollBar.Create(Self);
    FVBar.Parent := Self;
    FVBar.Kind := sbVertical;
    FVBar.TabStop := False;
    FVBar.Visible := False;
    FVBar.OnChange := @ScrollChanged;
  end;
  if FHBar = nil then
  begin
    FHBar := TScrollBar.Create(Self);
    FHBar.Parent := Self;
    FHBar.Kind := sbHorizontal;
    FHBar.TabStop := False;
    FHBar.Visible := False;
    FHBar.OnChange := @ScrollChanged;
  end;
end;

function TaPanel.VerticalBar: TScrollBar;
begin
  Result := FVBar;
end;

function TaPanel.HorizontalBar: TScrollBar;
begin
  Result := FHBar;
end;

function TaPanel.ContentExtent(out AW, AH: Integer): Boolean;
var
  I: Integer;
  C: TControl;
begin
  AW := 0; AH := 0;
  Result := False;
  for I := 0 to ControlCount - 1 do
  begin
    C := Controls[I];
    if ((Engine <> nil) and (C = Engine.Inner)) or (C = FVBar) or (C = FHBar) then Continue;
    if not C.Visible then Continue;
    Result := True;
    { polozaj bez pomaka: tako sadrzaj ne mijenja velicinu dok se pomice }
    if C.Left + C.Width + FOffX > AW then AW := C.Left + C.Width + FOffX;
    if C.Top + C.Height + FOffY > AH then AH := C.Top + C.Height + FOffY;
  end;
end;

procedure TaPanel.ScrollTo(AX, AY: Integer);
var
  I: Integer;
  C: TControl;
  DX, DY: Integer;
begin
  if AX < 0 then AX := 0;
  if AY < 0 then AY := 0;
  DX := AX - FOffX;
  DY := AY - FOffY;
  if (DX = 0) and (DY = 0) then Exit;
  FInScroll := True;
  try
    for I := 0 to ControlCount - 1 do
    begin
      C := Controls[I];
      if ((Engine <> nil) and (C = Engine.Inner)) or (C = FVBar) or (C = FHBar) then Continue;
      C.SetBounds(C.Left - DX, C.Top - DY, C.Width, C.Height);
    end;
    FOffX := AX;
    FOffY := AY;
  finally
    FInScroll := False;
  end;
end;

procedure TaPanel.UpdateScroll;
var
  W, H, ViewW, ViewH: Integer;
  NeedV, NeedH: Boolean;
begin
  if FInScroll then Exit;
  if (FVariant <> pvScroll) or (csDesigning in ComponentState) or (csLoading in ComponentState) then
  begin
    if FVBar <> nil then FVBar.Visible := False;
    if FHBar <> nil then FHBar.Visible := False;
    Exit;
  end;
  EnsureBars;
  FInScroll := True;
  try
    if not ContentExtent(W, H) then begin W := 0; H := 0; end;
    NeedV := False; NeedH := False;
    ViewW := Width; ViewH := Height;
    { svaka traka smanjuje prostor druge: dva prolaza }
    if H > ViewH then begin NeedV := True; ViewW := Width - FVBar.Width; end;
    if W > ViewW then begin NeedH := True; ViewH := Height - FHBar.Height; end;
    if (not NeedV) and (H > ViewH) then begin NeedV := True; ViewW := Width - FVBar.Width; end;
    FVBar.Visible := NeedV;
    FHBar.Visible := NeedH;
    if NeedV then
    begin
      FVBar.SetBounds(Width - FVBar.Width, 0, FVBar.Width, ViewH);
      FVBar.Min := 0;
      FVBar.Max := H;
      FVBar.PageSize := ViewH;
      FVBar.LargeChange := ViewH;
      FVBar.SmallChange := 20;
    end;
    if NeedH then
    begin
      FHBar.SetBounds(0, Height - FHBar.Height, ViewW, FHBar.Height);
      FHBar.Min := 0;
      FHBar.Max := W;
      FHBar.PageSize := ViewW;
      FHBar.LargeChange := ViewW;
      FHBar.SmallChange := 20;
    end;
  finally
    FInScroll := False;
  end;
  { pomak mora ostati unutar sadrzaja }
  if NeedV then begin if FOffY > H - ViewH then ScrollTo(FOffX, H - ViewH); end else ScrollTo(FOffX, 0);
  if NeedH then begin if FOffX > W - ViewW then ScrollTo(W - ViewW, FOffY); end else ScrollTo(0, FOffY);
  if NeedV and (FVBar.Position <> FOffY) then begin FInScroll := True; try FVBar.Position := FOffY; finally FInScroll := False; end; end;
  if NeedH and (FHBar.Position <> FOffX) then begin FInScroll := True; try FHBar.Position := FOffX; finally FInScroll := False; end; end;
end;

procedure TaPanel.ScrollChanged(Sender: TObject);
var
  X, Y: Integer;
begin
  if FInScroll then Exit;
  X := FOffX; Y := FOffY;
  if (FHBar <> nil) and FHBar.Visible then X := FHBar.Position;
  if (FVBar <> nil) and FVBar.Visible then Y := FVBar.Position;
  ScrollTo(X, Y);
end;

procedure TaPanel.AlignControls(AControl: TControl; var ARect: TRect);
begin
  inherited AlignControls(AControl, ARect);
  if (FVariant = pvScroll) and not FInScroll then UpdateScroll;
end;

function TaPanel.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
begin
  Result := inherited DoMouseWheel(Shift, WheelDelta, MousePos);
  if Result or (FVariant <> pvScroll) or (FVBar = nil) or not FVBar.Visible then Exit;
  ScrollTo(FOffX, FOffY - WheelDelta div 3);
  FInScroll := True;
  try
    FVBar.Position := FOffY;
  finally
    FInScroll := False;
  end;
  Result := True;
end;

{ ---------------- splitter (host) ---------------- }

function TaPanel.DragSplitter(ADelta: Integer): Integer;
var
  I: Integer;
  C, Nb: TControl;
  Best: Integer;
  NewSize, Old, Mn: Integer;
begin
  Result := 0;
  if (FVariant <> pvSplitter) or (Parent = nil) or (ADelta = 0) then Exit;
  Mn := FOptions.MinSize;
  if Mn < 1 then Mn := 1;
  Nb := nil;
  case Align of
    alLeft:
      begin
        Best := -1;
        for I := 0 to Parent.ControlCount - 1 do
        begin
          C := Parent.Controls[I];
          if (C <> Self) and (C.Align = alLeft) and C.Visible and (C.Left < Left) and (C.Left > Best) then begin Best := C.Left; Nb := C; end;
        end;
        if Nb = nil then Exit;
        Old := Nb.Width;
        NewSize := Old + ADelta;
        if NewSize < Mn then NewSize := Mn;
        Nb.Width := NewSize;
        Result := Nb.Width - Old;
      end;
    alRight:
      begin
        Best := MaxInt;
        for I := 0 to Parent.ControlCount - 1 do
        begin
          C := Parent.Controls[I];
          if (C <> Self) and (C.Align = alRight) and C.Visible and (C.Left > Left) and (C.Left < Best) then begin Best := C.Left; Nb := C; end;
        end;
        if Nb = nil then Exit;
        Old := Nb.Width;
        NewSize := Old - ADelta;
        if NewSize < Mn then NewSize := Mn;
        Nb.Width := NewSize;
        Result := Old - Nb.Width;
      end;
    alTop:
      begin
        Best := -1;
        for I := 0 to Parent.ControlCount - 1 do
        begin
          C := Parent.Controls[I];
          if (C <> Self) and (C.Align = alTop) and C.Visible and (C.Top < Top) and (C.Top > Best) then begin Best := C.Top; Nb := C; end;
        end;
        if Nb = nil then Exit;
        Old := Nb.Height;
        NewSize := Old + ADelta;
        if NewSize < Mn then NewSize := Mn;
        Nb.Height := NewSize;
        Result := Nb.Height - Old;
      end;
    alBottom:
      begin
        Best := MaxInt;
        for I := 0 to Parent.ControlCount - 1 do
        begin
          C := Parent.Controls[I];
          if (C <> Self) and (C.Align = alBottom) and C.Visible and (C.Top > Top) and (C.Top < Best) then begin Best := C.Top; Nb := C; end;
        end;
        if Nb = nil then Exit;
        Old := Nb.Height;
        NewSize := Old - ADelta;
        if NewSize < Mn then NewSize := Mn;
        Nb.Height := NewSize;
        Result := Old - Nb.Height;
      end;
  end;
end;

procedure TaPanel.Loaded;
begin
  inherited Loaded;
  PushToEngine;
  if (Engine <> nil) and (Engine.Inner <> nil) then Engine.Inner.SendToBack;
end;

{ ---------------- definicija kontrole <-> komponenta ---------------- }

const
  OwnKeys = ',variant,visibleIf,enabledIf,expanded,minSize,';

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

function PanelFromDef(D: TaControlDef; AOwner: TComponent): TaPanel;
begin
  Result := TaPanel.Create(AOwner);
  try
    Result.Name := D.Name;
    Result.SetBounds(D.Left, D.Top, D.Width, D.Height);
    Result.Variant := PanelVariantFromName(D.GetX('variant'), pvPlain);
    Result.Caption := D.Caption;
    Result.VisibleIf := D.GetX('visibleIf');
    Result.EnabledIf := D.GetX('enabledIf');
    Result.Options.Expanded := D.GetX('expanded') <> '0';
    Result.Options.MinSize := StrToIntDef(D.GetX('minSize'), 30);
    Result.Options := Result.Options;
    Result.Extra := ExtraWithout(D.Extra);
  except
    Result.Free;
    raise;
  end;
end;

procedure PanelToDef(P: TaPanel; D: TaControlDef);
begin
  D.Kind := 'Panel';
  D.Name := P.Name;
  D.Left := P.Left; D.Top := P.Top; D.Width := P.Width; D.Height := P.Height;
  D.Caption := P.Caption;
  D.Extra := P.Extra;
  D.SetX('variant', IfThen(P.Variant = pvPlain, '', P.VariantName));
  D.SetX('visibleIf', P.VisibleIf);
  D.SetX('enabledIf', P.EnabledIf);
  D.SetX('expanded', IfThen(P.Options.Expanded, '', '0'));
  D.SetX('minSize', IfThen(P.Options.MinSize <> 30, IntToStr(P.Options.MinSize), ''));
end;

function PanelToLfm(P: TaPanel): string;
var
  M: TMemoryStream;
  L: TStringList;
begin
  M := TMemoryStream.Create;
  L := TStringList.Create;
  try
    WriteComponentAsTextToStream(M, P);
    M.Position := 0;
    L.LoadFromStream(M);
    Result := L.Text;
  finally
    L.Free;
    M.Free;
  end;
end;

type
  TPanelLfmFinder = class
    procedure Find(Reader: TReader; const AClassName: string; var AClass: TComponentClass);
  end;

procedure TPanelLfmFinder.Find(Reader: TReader; const AClassName: string; var AClass: TComponentClass);
begin
  if SameText(AClassName, 'TaPanel') then AClass := TaPanel;
end;

function PanelFromLfm(const ALfm: string; AOwner: TComponent): TaPanel;
var
  M: TMemoryStream;
  C: TComponent;
  F: TPanelLfmFinder;
begin
  M := TMemoryStream.Create;
  try
    if ALfm <> '' then M.WriteBuffer(ALfm[1], Length(ALfm));
    M.Position := 0;
    C := nil;
    F := TPanelLfmFinder.Create;
    try
      ReadComponentFromTextStream(M, C, @F.Find, AOwner);
    finally
      F.Free;
    end;
    Result := C as TaPanel;
  finally
    M.Free;
  end;
end;

initialization
  RegisterClass(TaPanel);
  RegisterEngine(PanelFamily, 'plain', TaPanelPlainEngine);
  RegisterEngine(PanelFamily, 'group', TaPanelGroupEngine);
  RegisterEngine(PanelFamily, 'card', TaPanelCardEngine);
  RegisterEngine(PanelFamily, 'expander', TaPanelExpanderEngine);
  RegisterEngine(PanelFamily, 'scroll', TaPanelScrollEngine);
  RegisterEngine(PanelFamily, 'splitter', TaPanelSplitterEngine);

end.
