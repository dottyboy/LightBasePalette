unit ta_pages;
{ Obitelj Pages: izbornik stranica. Varijante: tabs (TTabControl), list (TListBox) i steps (koraci, vlastito
  crtanje). Domacin daje popis stranica (Items) i aktivnu stranicu (ActivePage, od 0); sadrzaj stranica
  (kontrole s "page" u definiciji) prikazuje forma prema dogadaju OnChange. Nije jos: accordion i stranice-spremnici. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, StdCtrls, ComCtrls, ExtCtrls, Graphics, Variants, LCLType, ta_family, ta_formdef;

type
  TaPagesVariant = (pgTabs, pgList, pgSteps, pgAccordion);

const
  PagesVariantNames: array[TaPagesVariant] of string = ('tabs', 'list', 'steps', 'accordion');
  PagesFamily = 'Pages';

type
  TaPagesOptions = class(TPersistent)
  private
    FTabsAtBottom: Boolean;
  public
    procedure Assign(ASource: TPersistent); override;
  published
    { samo tabs }
    property TabsAtBottom: Boolean read FTabsAtBottom write FTabsAtBottom default False;
  end;

  TaStepsPaint = class(TCustomControl)
  private
    FItems: TStringList;
    FIndex: Integer;
    FStacked: Boolean;
    FOnSelect: TNotifyEvent;
    procedure SetIndex(AValue: Integer);
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure SetLabels(AValue: TStrings);
    property ItemIndex: Integer read FIndex write SetIndex;
    { harmonika: zaglavlja jedno ispod drugoga, aktivno istaknuto }
    property Stacked: Boolean read FStacked write FStacked;
    property OnSelect: TNotifyEvent read FOnSelect write FOnSelect;
  end;

  TaPagesTabsEngine = class(TaEngine)
  private
    FTabs: TTabControl;
    FSetting: Boolean;
    procedure TabChange(Sender: TObject);
  public
    constructor Create(AHost: TaFamilyHost); override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
    procedure SetItems(AItems: TStrings); override;
    procedure ApplyOptions(AOptions: TPersistent); override;
  end;

  TaPagesListEngine = class(TaEngine)
  private
    FBox: TListBox;
    FSetting: Boolean;
    procedure BoxSelect(Sender: TObject; User: Boolean);
  public
    constructor Create(AHost: TaFamilyHost); override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
    procedure SetItems(AItems: TStrings); override;
  end;

  TaPagesStepsEngine = class(TaEngine)
  private
    FSteps: TaStepsPaint;
    procedure Selected(Sender: TObject);
  protected
    function Stacked: Boolean; virtual;
  public
    constructor Create(AHost: TaFamilyHost); override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
    procedure SetItems(AItems: TStrings); override;
  end;

  TaPagesAccordionEngine = class(TaPagesStepsEngine)
  protected
    function Stacked: Boolean; override;
  end;

  TaPages = class(TaFamilyHost)
  private
    FVariant: TaPagesVariant;
    FOptions: TaPagesOptions;
    FItems: TStringList;
    FIndex: Integer;
    FVisibleIf, FEnabledIf, FExtra: string;
    function GetVariant: TaPagesVariant;
    procedure SetVariant(AValue: TaPagesVariant);
    function GetOptions: TaPagesOptions;
    procedure SetOptions(AValue: TaPagesOptions);
    procedure SetItemsList(AValue: TStrings);
    function GetItemsList: TStrings;
    procedure ItemsChanged(Sender: TObject);
    function GetActivePage: Integer;
    procedure SetActivePage(AValue: Integer);
    procedure PushToEngine;
  protected
    function CreateEngine: TaEngine; override;
    function RealGetText: TCaption; override;
    procedure RealSetText(const AValue: TCaption); override;
    procedure GetChildren(Proc: TGetChildProc; Root: TComponent); override;
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function VariantName: string;
  published
    property Variant: TaPagesVariant read GetVariant write SetVariant default pgTabs;
    { natpisi stranica, jedan po retku }
    property Items: TStrings read GetItemsList write SetItemsList;
    property ActivePage: Integer read GetActivePage write SetActivePage default 0;
    property Options: TaPagesOptions read GetOptions write SetOptions;
    property VisibleIf: string read FVisibleIf write FVisibleIf;
    property EnabledIf: string read FEnabledIf write FEnabledIf;
    property Extra: string read FExtra write FExtra;
    property Align;
    property Anchors;
    property Enabled;
    property Visible;
    property Hint;
    property ShowHint;
    property TabOrder;
    property PopupMenu;
  end;

function IsPagesKind(const AKind: string): Boolean;
function PagesVariantFromName(const AName: string; ADefault: TaPagesVariant = pgTabs): TaPagesVariant;
function PagesFromDef(D: TaControlDef; AOwner: TComponent): TaPages;
procedure PagesToDef(P: TaPages; D: TaControlDef);
function PagesToLfm(P: TaPages): string;
function PagesFromLfm(const ALfm: string; AOwner: TComponent): TaPages;

implementation

uses
  StrUtils, Math, LResources, ta_tokens;

function IsPagesKind(const AKind: string): Boolean;
begin
  Result := SameText(AKind, 'Pages') or SameText(AKind, 'TabControl');
end;

function PagesVariantFromName(const AName: string; ADefault: TaPagesVariant): TaPagesVariant;
var
  V: TaPagesVariant;
begin
  for V := Low(TaPagesVariant) to High(TaPagesVariant) do
    if SameText(PagesVariantNames[V], AName) then Exit(V);
  Result := ADefault;
end;

procedure TaPagesOptions.Assign(ASource: TPersistent);
begin
  if ASource is TaPagesOptions then FTabsAtBottom := TaPagesOptions(ASource).FTabsAtBottom
  else inherited Assign(ASource);
end;

{ ---------------- koraci ---------------- }

constructor TaStepsPaint.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BorderStyle := bsNone;      { Qt: bez okvira QAbstractScrollArea koji tema crta kao polje }
  FItems := TStringList.Create;
  TabStop := True;
  Width := 300;
  Height := 40;
end;

destructor TaStepsPaint.Destroy;
begin
  FItems.Free;
  inherited Destroy;
end;

procedure TaStepsPaint.SetLabels(AValue: TStrings);
begin
  FItems.Assign(AValue);
  if FIndex >= FItems.Count then FIndex := 0;
  Invalidate;
end;

procedure TaStepsPaint.SetIndex(AValue: Integer);
begin
  if (AValue < 0) or (AValue >= FItems.Count) then Exit;
  if AValue = FIndex then Exit;
  FIndex := AValue;
  Invalidate;
end;

procedure TaStepsPaint.Paint;
var
  T: TaThemeTokens;
  I, X0, W, Cy, Rad, Th, Tw: Integer;
  Bg, Fg, Line: TColor;
  S: string;
begin
  T := ActiveTokens;
  Canvas.Brush.Color := Color;
  Canvas.FillRect(0, 0, Width, Height);
  if FItems.Count = 0 then Exit;
  if FStacked then
  begin
    Th := Height div FItems.Count;
    if Th > 34 then Th := 34;
    for I := 0 to FItems.Count - 1 do
    begin
      if I = FIndex then begin Bg := TokenColor(T.Accent); Fg := TokenColor(T.OnAccent); end
      else begin Bg := TokenColor(T.Soft); Fg := TokenColor(T.Text); end;
      Canvas.Brush.Style := bsSolid;
      Canvas.Brush.Color := Bg;
      Canvas.Pen.Color := TokenColor(T.Border);
      Canvas.RoundRect(0, I * (Th + 2), Width, I * (Th + 2) + Th, T.RadiusButton * 2, T.RadiusButton * 2);
      Canvas.Brush.Style := bsClear;
      Canvas.Font.Color := Fg;
      if I = FIndex then Canvas.Font.Style := [fsBold] else Canvas.Font.Style := [];
      Canvas.TextOut(12, I * (Th + 2) + (Th - Canvas.TextHeight('Ag')) div 2, FItems[I]);
    end;
    Canvas.Brush.Style := bsSolid;
    Exit;
  end;
  Rad := 11;
  Cy := Height div 2;
  Canvas.Brush.Style := bsClear;
  for I := 0 to FItems.Count - 1 do
  begin
    X0 := I * Width div FItems.Count;
    W := Width div FItems.Count;
    if I <= FIndex then begin Bg := TokenColor(T.Accent); Fg := TokenColor(T.OnAccent); end
    else begin Bg := TokenColor(T.Soft); Fg := TokenColor(T.TextSoft); end;
    Line := TokenColor(T.Border);
    if I < FItems.Count - 1 then
    begin
      if I < FIndex then Canvas.Pen.Color := TokenColor(T.Accent) else Canvas.Pen.Color := Line;
      Canvas.MoveTo(X0 + Rad + 4 + Canvas.TextWidth(FItems[I]) + 8 + Rad, Cy);
      Canvas.LineTo(X0 + W - 4, Cy);
    end;
    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := Bg;
    Canvas.Pen.Color := Bg;
    Canvas.Ellipse(X0 + 4, Cy - Rad, X0 + 4 + Rad * 2, Cy + Rad);
    Canvas.Brush.Style := bsClear;
    S := IntToStr(I + 1);
    Canvas.Font.Color := Fg;
    Tw := Canvas.TextWidth(S);
    Th := Canvas.TextHeight(S);
    Canvas.TextOut(X0 + 4 + Rad - Tw div 2, Cy - Th div 2, S);
    if I = FIndex then Canvas.Font.Color := TokenColor(T.Text) else Canvas.Font.Color := TokenColor(T.TextSoft);
    Canvas.TextOut(X0 + 4 + Rad * 2 + 6, Cy - Canvas.TextHeight('Ag') div 2, FItems[I]);
  end;
  Canvas.Brush.Style := bsSolid;
end;

procedure TaStepsPaint.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  I: Integer;
begin
  inherited MouseDown(Button, Shift, X, Y);
  if CanFocus then SetFocus;
  if FItems.Count = 0 then Exit;
  if FStacked then
  begin
    I := Y div (Max(1, Min(34, Height div FItems.Count)) + 2);
    if I >= FItems.Count then Exit;
  end
  else I := X * FItems.Count div Width;
  if I >= FItems.Count then I := FItems.Count - 1;
  if (I >= 0) and (I <> FIndex) then
  begin
    SetIndex(I);
    if Assigned(FOnSelect) then FOnSelect(Self);
  end;
end;

procedure TaStepsPaint.KeyDown(var Key: Word; Shift: TShiftState);
var
  N: Integer;
begin
  inherited KeyDown(Key, Shift);
  if Key = VK_RIGHT then N := FIndex + 1
  else if Key = VK_LEFT then N := FIndex - 1
  else Exit;
  Key := 0;
  if (N >= 0) and (N < FItems.Count) and (N <> FIndex) then
  begin
    SetIndex(N);
    if Assigned(FOnSelect) then FOnSelect(Self);
  end;
end;

{ ---------------- pokretaci ---------------- }

constructor TaPagesTabsEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FTabs := TTabControl.Create(nil);
  FTabs.OnChange := @TabChange;
  AttachInner(FTabs);
end;

procedure TaPagesTabsEngine.TabChange(Sender: TObject);
begin
  if FSetting then Exit;
  InnerChanged(Sender);
end;

function TaPagesTabsEngine.GetText: string;
begin
  Result := IntToStr(FTabs.TabIndex);
end;

procedure TaPagesTabsEngine.SetText(const AValue: string);
begin
  FSetting := True;
  try
    FTabs.TabIndex := StrToIntDef(AValue, 0);
  finally
    FSetting := False;
  end;
end;

procedure TaPagesTabsEngine.SetItems(AItems: TStrings);
var
  Keep: Integer;
begin
  Keep := FTabs.TabIndex;
  FSetting := True;
  try
    FTabs.Tabs.Assign(AItems);
    if Keep >= 0 then FTabs.TabIndex := Keep;
  finally
    FSetting := False;
  end;
end;

procedure TaPagesTabsEngine.ApplyOptions(AOptions: TPersistent);
begin
  if AOptions is TaPagesOptions then
    if TaPagesOptions(AOptions).TabsAtBottom then FTabs.TabPosition := tpBottom else FTabs.TabPosition := tpTop;
end;

constructor TaPagesListEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FBox := TListBox.Create(nil);
  FBox.OnSelectionChange := @BoxSelect;
  AttachInner(FBox);
end;

procedure TaPagesListEngine.BoxSelect(Sender: TObject; User: Boolean);
begin
  if FSetting then Exit;
  InnerChanged(Sender);
end;

function TaPagesListEngine.GetText: string;
begin
  Result := IntToStr(FBox.ItemIndex);
end;

procedure TaPagesListEngine.SetText(const AValue: string);
begin
  FSetting := True;
  try
    FBox.ItemIndex := StrToIntDef(AValue, 0);
  finally
    FSetting := False;
  end;
end;

procedure TaPagesListEngine.SetItems(AItems: TStrings);
var
  Keep: Integer;
begin
  Keep := FBox.ItemIndex;
  FSetting := True;
  try
    FBox.Items.Assign(AItems);
    if (Keep >= 0) and (Keep < FBox.Items.Count) then FBox.ItemIndex := Keep;
  finally
    FSetting := False;
  end;
end;

constructor TaPagesStepsEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FSteps := TaStepsPaint.Create(nil);
  FSteps.Stacked := Stacked;
  FSteps.OnSelect := @Selected;
  AttachInner(FSteps);
end;

function TaPagesStepsEngine.Stacked: Boolean;
begin
  Result := False;
end;

function TaPagesAccordionEngine.Stacked: Boolean;
begin
  Result := True;
end;

procedure TaPagesStepsEngine.Selected(Sender: TObject);
begin
  InnerChanged(Sender);
end;

function TaPagesStepsEngine.GetText: string;
begin
  Result := IntToStr(FSteps.ItemIndex);
end;

procedure TaPagesStepsEngine.SetText(const AValue: string);
begin
  FSteps.ItemIndex := StrToIntDef(AValue, 0);
end;

procedure TaPagesStepsEngine.SetItems(AItems: TStrings);
begin
  FSteps.SetLabels(AItems);
end;

{ ---------------- TaPages ---------------- }

constructor TaPages.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FItems := TStringList.Create;
  FItems.OnChange := @ItemsChanged;
  FOptions := TaPagesOptions.Create;
  FVariant := pgTabs;
  ControlStyle := ControlStyle + [csAcceptsControls];   { kontrole ispustene na Pages ostaju na njemu }
  Width := 300;
  Height := 120;
  ReplaceEngine;
  PushToEngine;
end;

destructor TaPages.Destroy;
begin
  FOptions.Free;
  FItems.Free;
  inherited Destroy;
end;

function TaPages.CreateEngine: TaEngine;
var
  C: TaEngineClass;
begin
  C := FindEngine(PagesFamily, PagesVariantNames[FVariant]);
  if C = nil then C := FindEngine(PagesFamily, 'tabs');
  Result := C.Create(Self);
end;

function TaPages.VariantName: string;
begin
  Result := PagesVariantNames[FVariant];
end;

function TaPages.GetVariant: TaPagesVariant;
begin
  Result := FVariant;
end;

procedure TaPages.SetVariant(AValue: TaPagesVariant);
begin
  if AValue = FVariant then Exit;
  FIndex := GetActivePage;
  FVariant := AValue;
  ReplaceEngine;
  PushToEngine;
end;

function TaPages.GetOptions: TaPagesOptions;
begin
  Result := FOptions;
end;

procedure TaPages.SetOptions(AValue: TaPagesOptions);
begin
  FOptions.Assign(AValue);
  if Engine <> nil then Engine.ApplyOptions(FOptions);
end;

procedure TaPages.SetItemsList(AValue: TStrings);
begin
  FItems.Assign(AValue);
end;

function TaPages.GetItemsList: TStrings;
begin
  Result := FItems;
end;

procedure TaPages.ItemsChanged(Sender: TObject);
begin
  if (Engine <> nil) and not (csLoading in ComponentState) then
  begin
    Engine.SetItems(FItems);
    Engine.SetText(IntToStr(FIndex));
  end;
end;

procedure TaPages.PushToEngine;
begin
  if Engine = nil then Exit;
  Engine.ApplyOptions(FOptions);
  Engine.SetItems(FItems);
  Engine.SetText(IntToStr(FIndex));
end;

procedure TaPages.GetChildren(Proc: TGetChildProc; Root: TComponent);
var
  I: Integer;
begin
  { sprema se sve osim pokretaca }
  for I := 0 to ControlCount - 1 do
    if (Engine = nil) or (Controls[I] <> Engine.Inner) then Proc(Controls[I]);
end;

function TaPages.GetActivePage: Integer;
begin
  if Engine <> nil then Result := StrToIntDef(Engine.GetText, 0) else Result := FIndex;
end;

procedure TaPages.SetActivePage(AValue: Integer);
begin
  FIndex := AValue;
  if Engine <> nil then Engine.SetText(IntToStr(AValue));
end;

function TaPages.RealGetText: TCaption;
begin
  Result := IntToStr(GetActivePage);
end;

procedure TaPages.RealSetText(const AValue: TCaption);
begin
  SetActivePage(StrToIntDef(AValue, 0));
end;

procedure TaPages.Loaded;
begin
  inherited Loaded;
  PushToEngine;
end;

{ ---------------- definicija kontrole <-> komponenta ---------------- }

const
  OwnKeys = ',variant,visibleIf,enabledIf,tabsAtBottom,items,active,';

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

function PagesFromDef(D: TaControlDef; AOwner: TComponent): TaPages;
var
  L: TStringList;
  S: string;
begin
  Result := TaPages.Create(AOwner);
  try
    Result.Name := D.Name;
    Result.SetBounds(D.Left, D.Top, D.Width, D.Height);
    Result.Variant := PagesVariantFromName(D.GetX('variant'), pgTabs);
    Result.VisibleIf := D.GetX('visibleIf');
    Result.EnabledIf := D.GetX('enabledIf');
    Result.Options.TabsAtBottom := D.GetX('tabsAtBottom') = '1';
    Result.Options := Result.Options;
    L := TStringList.Create;
    try
      { TabControl: popis stranica je RowSource "list:Prva;Druga" ili retci }
      S := D.GetX('items');
      if S = '' then
      begin
        S := Trim(D.RowSource);
        if LowerCase(Copy(S, 1, 5)) = 'list:' then S := Copy(S, 6, MaxInt);
      end;
      if S <> '' then
      begin
        L.Delimiter := ';';
        L.StrictDelimiter := True;
        L.DelimitedText := S;
      end;
      Result.Items.Assign(L);
    finally
      L.Free;
    end;
    Result.ActivePage := StrToIntDef(D.GetX('active'), 0);
    Result.Extra := ExtraWithout(D.Extra);
  except
    Result.Free;
    raise;
  end;
end;

procedure PagesToDef(P: TaPages; D: TaControlDef);
var
  I: Integer;
  S: string;
begin
  D.Kind := 'TabControl';
  D.Name := P.Name;
  D.Left := P.Left; D.Top := P.Top; D.Width := P.Width; D.Height := P.Height;
  D.Extra := P.Extra;
  D.SetX('variant', IfThen(P.Variant = pgTabs, '', P.VariantName));
  D.SetX('visibleIf', P.VisibleIf);
  D.SetX('enabledIf', P.EnabledIf);
  D.SetX('tabsAtBottom', IfThen(P.Options.TabsAtBottom, '1', ''));
  S := '';
  for I := 0 to P.Items.Count - 1 do
  begin
    if S <> '' then S := S + ';';
    S := S + P.Items[I];
  end;
  D.SetX('items', S);
  D.SetX('active', IfThen(P.ActivePage > 0, IntToStr(P.ActivePage), ''));
end;

function PagesToLfm(P: TaPages): string;
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
  TPagesLfmFinder = class
    procedure Find(Reader: TReader; const AClassName: string; var AClass: TComponentClass);
  end;

procedure TPagesLfmFinder.Find(Reader: TReader; const AClassName: string; var AClass: TComponentClass);
begin
  if SameText(AClassName, 'TaPages') then AClass := TaPages;
end;

function PagesFromLfm(const ALfm: string; AOwner: TComponent): TaPages;
var
  M: TMemoryStream;
  C: TComponent;
  F: TPagesLfmFinder;
begin
  M := TMemoryStream.Create;
  try
    if ALfm <> '' then M.WriteBuffer(ALfm[1], Length(ALfm));
    M.Position := 0;
    C := nil;
    F := TPagesLfmFinder.Create;
    try
      ReadComponentFromTextStream(M, C, @F.Find, AOwner);
    finally
      F.Free;
    end;
    Result := C as TaPages;
  finally
    M.Free;
  end;
end;

initialization
  RegisterClass(TaPages);
  RegisterEngine(PagesFamily, 'tabs', TaPagesTabsEngine);
  RegisterEngine(PagesFamily, 'list', TaPagesListEngine);
  RegisterEngine(PagesFamily, 'steps', TaPagesStepsEngine);
  RegisterEngine(PagesFamily, 'accordion', TaPagesAccordionEngine);

end.
