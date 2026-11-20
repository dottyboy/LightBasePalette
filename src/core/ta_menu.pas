unit ta_menu;
{ Obitelj Menu: izbornik aplikacije. Varijante: side (bocni izbornik TaSideMenu), toolbar (TToolBar) i tree (TTreeView).
  Stavke su retci kao u TaSideMenu: "# Skupina|ikona" i "Natpis|radnja|ikona" (radnja kao na gumbu: openform:Racuni).
  Klik na stavku javlja OnAction(radnja). Isti nacin kao Edit: domacin TaMenu, pokretaci, Options, definicija, .lfm. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, ComCtrls, Graphics, Variants, ta_family, ta_formdef, ta_sidemenu;

type
  TaMenuVariant = (muSide, muToolbar, muTree);
  TaMenuActionEvent = procedure(Sender: TObject; const AAction: string) of object;

const
  MenuVariantNames: array[TaMenuVariant] of string = ('side', 'toolbar', 'tree');
  MenuFamily = 'Menu';

type
  TaMenuOptions = class(TPersistent)
  private
    FAccordion, FCompact: Boolean;
  public
    constructor Create;
    procedure Assign(ASource: TPersistent); override;
  published
    { side }
    property Accordion: Boolean read FAccordion write FAccordion default True;
    property Compact: Boolean read FCompact write FCompact default False;
  end;

  TaMenuEngine = class(TaEngine)
  protected
    FItems: TStringList;
    procedure Fire(const AAction: string);
  public
    constructor Create(AHost: TaFamilyHost); override;
    destructor Destroy; override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
    { za ispitivanje: klik na stavku s tom radnjom }
    procedure Activate(const AAction: string); virtual; abstract;
    function ItemCount: Integer; virtual; abstract;
  end;

  TaMenuSideEngine = class(TaMenuEngine)
  private
    FMenu: TaSideMenu;
    procedure MenuAction(const AAction: string);
  public
    constructor Create(AHost: TaFamilyHost); override;
    procedure SetItems(AItems: TStrings); override;
    procedure ApplyOptions(AOptions: TPersistent); override;
    procedure Activate(const AAction: string); override;
    function ItemCount: Integer; override;
  end;

  TaMenuToolbarEngine = class(TaMenuEngine)
  private
    FBar: TToolBar;
    procedure ButtonClick(Sender: TObject);
  public
    constructor Create(AHost: TaFamilyHost); override;
    procedure SetItems(AItems: TStrings); override;
    procedure Activate(const AAction: string); override;
    function ItemCount: Integer; override;
  end;

  TaMenuTreeEngine = class(TaMenuEngine)
  private
    FTree: TTreeView;
    FActions: TStringList;
    procedure TreeClick(Sender: TObject);
  public
    constructor Create(AHost: TaFamilyHost); override;
    destructor Destroy; override;
    procedure SetItems(AItems: TStrings); override;
    procedure Activate(const AAction: string); override;
    function ItemCount: Integer; override;
  end;

  TaMenu = class(TaFamilyHost)
  private
    FVariant: TaMenuVariant;
    FOptions: TaMenuOptions;
    FItems: TStringList;
    FOnAction: TaMenuActionEvent;
    FVisibleIf, FEnabledIf, FExtra: string;
    function GetVariant: TaMenuVariant;
    procedure SetVariant(AValue: TaMenuVariant);
    function GetOptions: TaMenuOptions;
    procedure SetOptions(AValue: TaMenuOptions);
    procedure SetItemsList(AValue: TStrings);
    function GetItemsList: TStrings;
    procedure ItemsChanged(Sender: TObject);
    procedure PushToEngine;
  protected
    function CreateEngine: TaEngine; override;
    function RealGetText: TCaption; override;
    procedure RealSetText(const AValue: TCaption); override;
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function VariantName: string;
    procedure FireAction(const AAction: string);
    { klik na stavku (za ispitivanje i skripte) }
    procedure Activate(const AAction: string);
    function ItemCount: Integer;
  published
    property Variant: TaMenuVariant read GetVariant write SetVariant default muSide;
    property Items: TStrings read GetItemsList write SetItemsList;
    property Options: TaMenuOptions read GetOptions write SetOptions;
    property OnAction: TaMenuActionEvent read FOnAction write FOnAction;
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

function IsMenuKind(const AKind: string): Boolean;
function MenuVariantFromName(const AName: string; ADefault: TaMenuVariant = muSide): TaMenuVariant;
function MenuFromDef(D: TaControlDef; AOwner: TComponent): TaMenu;
procedure MenuToDef(M: TaMenu; D: TaControlDef);
function MenuToLfm(M: TaMenu): string;
function MenuFromLfm(const ALfm: string; AOwner: TComponent): TaMenu;

implementation

uses
  StrUtils, LResources;

function IsMenuKind(const AKind: string): Boolean;
begin
  Result := SameText(AKind, 'Menu') or SameText(AKind, 'SideMenu');
end;

function MenuVariantFromName(const AName: string; ADefault: TaMenuVariant): TaMenuVariant;
var
  V: TaMenuVariant;
begin
  for V := Low(TaMenuVariant) to High(TaMenuVariant) do
    if SameText(MenuVariantNames[V], AName) then Exit(V);
  Result := ADefault;
end;

function PartOf(const S: string; AIndex: Integer): string;
var
  P: TStringList;
begin
  P := TStringList.Create;
  try
    P.Delimiter := '|';
    P.StrictDelimiter := True;
    P.DelimitedText := S;
    if AIndex < P.Count then Result := Trim(P[AIndex]) else Result := '';
  finally
    P.Free;
  end;
end;

constructor TaMenuOptions.Create;
begin
  inherited Create;
  FAccordion := True;
end;

procedure TaMenuOptions.Assign(ASource: TPersistent);
begin
  if ASource is TaMenuOptions then
  begin
    FAccordion := TaMenuOptions(ASource).FAccordion;
    FCompact := TaMenuOptions(ASource).FCompact;
  end
  else inherited Assign(ASource);
end;

{ ---------------- pokretaci ---------------- }

constructor TaMenuEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FItems := TStringList.Create;
end;

destructor TaMenuEngine.Destroy;
begin
  FItems.Free;
  inherited Destroy;
end;

procedure TaMenuEngine.Fire(const AAction: string);
begin
  if Host is TaMenu then TaMenu(Host).FireAction(AAction);
end;

function TaMenuEngine.GetText: string;
begin
  Result := FItems.Text;
end;

procedure TaMenuEngine.SetText(const AValue: string);
begin
  FItems.Text := AValue;
end;

constructor TaMenuSideEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FMenu := TaSideMenu.Create(nil);
  FMenu.OnAction := @MenuAction;
  AttachInner(FMenu);
end;

procedure TaMenuSideEngine.MenuAction(const AAction: string);
begin
  Fire(AAction);
end;

procedure TaMenuSideEngine.SetItems(AItems: TStrings);
begin
  FItems.Assign(AItems);
  FMenu.Items := AItems.Text;
end;

procedure TaMenuSideEngine.ApplyOptions(AOptions: TPersistent);
begin
  if AOptions is TaMenuOptions then
  begin
    FMenu.Accordion := TaMenuOptions(AOptions).Accordion;
    FMenu.Compact := TaMenuOptions(AOptions).Compact;
  end;
end;

procedure TaMenuSideEngine.Activate(const AAction: string);
begin
  Fire(AAction);
end;

function TaMenuSideEngine.ItemCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to FItems.Count - 1 do
    if (Trim(FItems[I]) <> '') and (Copy(Trim(FItems[I]), 1, 1) <> '#') then Inc(Result);
end;

constructor TaMenuToolbarEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FBar := TToolBar.Create(nil);
  FBar.ShowCaptions := True;
  FBar.AutoSize := False;
  AttachInner(FBar);
end;

procedure TaMenuToolbarEngine.ButtonClick(Sender: TObject);
begin
  Fire(TToolButton(Sender).Hint);
end;

procedure TaMenuToolbarEngine.SetItems(AItems: TStrings);
var
  I: Integer;
  S: string;
  B: TToolButton;
begin
  FItems.Assign(AItems);
  for I := FBar.ButtonCount - 1 downto 0 do FBar.Buttons[I].Free;
  for I := AItems.Count - 1 downto 0 do
  begin
    S := Trim(AItems[I]);
    if (S = '') or (S[1] = '#') then Continue;
    B := TToolButton.Create(FBar);
    B.Parent := FBar;
    B.Caption := PartOf(S, 0);
    B.Hint := PartOf(S, 1);
    B.OnClick := @ButtonClick;
  end;
end;

procedure TaMenuToolbarEngine.Activate(const AAction: string);
var
  I: Integer;
begin
  for I := 0 to FBar.ButtonCount - 1 do
    if FBar.Buttons[I].Hint = AAction then begin FBar.Buttons[I].Click; Exit; end;
end;

function TaMenuToolbarEngine.ItemCount: Integer;
begin
  Result := FBar.ButtonCount;
end;

constructor TaMenuTreeEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FActions := TStringList.Create;
  FTree := TTreeView.Create(nil);
  FTree.ReadOnly := True;
  FTree.OnClick := @TreeClick;
  AttachInner(FTree);
end;

destructor TaMenuTreeEngine.Destroy;
begin
  FActions.Free;
  inherited Destroy;
end;

procedure TaMenuTreeEngine.TreeClick(Sender: TObject);
begin
  if (FTree.Selected <> nil) and (FTree.Selected.AbsoluteIndex < FActions.Count) then
    if FActions[FTree.Selected.AbsoluteIndex] <> '' then Fire(FActions[FTree.Selected.AbsoluteIndex]);
end;

procedure TaMenuTreeEngine.SetItems(AItems: TStrings);
var
  I: Integer;
  S: string;
  Grp: TTreeNode;
begin
  FItems.Assign(AItems);
  FActions.Clear;
  FTree.Items.Clear;
  Grp := nil;
  for I := 0 to AItems.Count - 1 do
  begin
    S := Trim(AItems[I]);
    if S = '' then Continue;
    if S[1] = '#' then
    begin
      Grp := FTree.Items.AddChild(nil, Trim(PartOf(Copy(S, 2, MaxInt), 0)));
      FActions.Add('');
    end
    else
    begin
      FTree.Items.AddChild(Grp, PartOf(S, 0));
      FActions.Add(PartOf(S, 1));
    end;
  end;
  FTree.FullExpand;
end;

procedure TaMenuTreeEngine.Activate(const AAction: string);
var
  I: Integer;
begin
  for I := 0 to FActions.Count - 1 do
    if FActions[I] = AAction then
    begin
      FTree.Selected := FTree.Items[I];
      TreeClick(FTree);
      Exit;
    end;
end;

function TaMenuTreeEngine.ItemCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to FActions.Count - 1 do if FActions[I] <> '' then Inc(Result);
end;

{ ---------------- TaMenu ---------------- }

constructor TaMenu.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FItems := TStringList.Create;
  FItems.OnChange := @ItemsChanged;
  FOptions := TaMenuOptions.Create;
  FVariant := muSide;
  Width := 200;
  Height := 260;
  ReplaceEngine;
  PushToEngine;
end;

destructor TaMenu.Destroy;
begin
  FOptions.Free;
  FItems.Free;
  inherited Destroy;
end;

function TaMenu.CreateEngine: TaEngine;
var
  C: TaEngineClass;
begin
  C := FindEngine(MenuFamily, MenuVariantNames[FVariant]);
  if C = nil then C := FindEngine(MenuFamily, 'side');
  Result := C.Create(Self);
end;

function TaMenu.VariantName: string;
begin
  Result := MenuVariantNames[FVariant];
end;

function TaMenu.GetVariant: TaMenuVariant;
begin
  Result := FVariant;
end;

procedure TaMenu.SetVariant(AValue: TaMenuVariant);
begin
  if AValue = FVariant then Exit;
  FVariant := AValue;
  ReplaceEngine;
  PushToEngine;
end;

function TaMenu.GetOptions: TaMenuOptions;
begin
  Result := FOptions;
end;

procedure TaMenu.SetOptions(AValue: TaMenuOptions);
begin
  FOptions.Assign(AValue);
  if Engine <> nil then Engine.ApplyOptions(FOptions);
end;

procedure TaMenu.SetItemsList(AValue: TStrings);
begin
  FItems.Assign(AValue);
end;

function TaMenu.GetItemsList: TStrings;
begin
  Result := FItems;
end;

procedure TaMenu.ItemsChanged(Sender: TObject);
begin
  if (Engine <> nil) and not (csLoading in ComponentState) then Engine.SetItems(FItems);
end;

procedure TaMenu.PushToEngine;
begin
  if Engine = nil then Exit;
  Engine.ApplyOptions(FOptions);
  Engine.SetItems(FItems);
end;

function TaMenu.RealGetText: TCaption;
begin
  Result := '';
end;

procedure TaMenu.RealSetText(const AValue: TCaption);
begin
end;

procedure TaMenu.Loaded;
begin
  inherited Loaded;
  PushToEngine;
end;

procedure TaMenu.FireAction(const AAction: string);
begin
  if Assigned(FOnAction) then FOnAction(Self, AAction);
end;

procedure TaMenu.Activate(const AAction: string);
begin
  if Engine is TaMenuEngine then TaMenuEngine(Engine).Activate(AAction);
end;

function TaMenu.ItemCount: Integer;
begin
  if Engine is TaMenuEngine then Result := TaMenuEngine(Engine).ItemCount else Result := 0;
end;

{ ---------------- definicija kontrole <-> komponenta ---------------- }

const
  OwnKeys = ',variant,visibleIf,enabledIf,accordion,compact,items,';

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

function MenuFromDef(D: TaControlDef; AOwner: TComponent): TaMenu;
var
  L: TStringList;
  S: string;
begin
  Result := TaMenu.Create(AOwner);
  try
    Result.Name := D.Name;
    Result.SetBounds(D.Left, D.Top, D.Width, D.Height);
    Result.Variant := MenuVariantFromName(D.GetX('variant'), muSide);
    Result.VisibleIf := D.GetX('visibleIf');
    Result.EnabledIf := D.GetX('enabledIf');
    Result.Options.Accordion := D.GetX('accordion') <> '0';
    Result.Options.Compact := D.GetX('compact') = '1';
    Result.Options := Result.Options;
    L := TStringList.Create;
    try
      { SideMenu: stavke su u RowSource, redci odvojeni znakom novog retka; u Extra kao items s " / " }
      S := D.GetX('items');
      if S <> '' then L.Text := StringReplace(S, ' / ', LineEnding, [rfReplaceAll])
      else L.Text := D.RowSource;
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

procedure MenuToDef(M: TaMenu; D: TaControlDef);
var
  I: Integer;
  S: string;
begin
  D.Kind := 'SideMenu';
  D.Name := M.Name;
  D.Left := M.Left; D.Top := M.Top; D.Width := M.Width; D.Height := M.Height;
  D.Extra := M.Extra;
  D.RowSource := '';
  D.SetX('variant', IfThen(M.Variant = muSide, '', M.VariantName));
  D.SetX('visibleIf', M.VisibleIf);
  D.SetX('enabledIf', M.EnabledIf);
  D.SetX('accordion', IfThen(M.Options.Accordion, '', '0'));
  D.SetX('compact', IfThen(M.Options.Compact, '1', ''));
  S := '';
  for I := 0 to M.Items.Count - 1 do
  begin
    if S <> '' then S := S + ' / ';
    S := S + M.Items[I];
  end;
  D.SetX('items', S);
end;

function MenuToLfm(M: TaMenu): string;
var
  St: TMemoryStream;
  L: TStringList;
begin
  St := TMemoryStream.Create;
  L := TStringList.Create;
  try
    WriteComponentAsTextToStream(St, M);
    St.Position := 0;
    L.LoadFromStream(St);
    Result := L.Text;
  finally
    L.Free;
    St.Free;
  end;
end;

type
  TMenuLfmFinder = class
    procedure Find(Reader: TReader; const AClassName: string; var AClass: TComponentClass);
  end;

procedure TMenuLfmFinder.Find(Reader: TReader; const AClassName: string; var AClass: TComponentClass);
begin
  if SameText(AClassName, 'TaMenu') then AClass := TaMenu;
end;

function MenuFromLfm(const ALfm: string; AOwner: TComponent): TaMenu;
var
  St: TMemoryStream;
  C: TComponent;
  F: TMenuLfmFinder;
begin
  St := TMemoryStream.Create;
  try
    if ALfm <> '' then St.WriteBuffer(ALfm[1], Length(ALfm));
    St.Position := 0;
    C := nil;
    F := TMenuLfmFinder.Create;
    try
      ReadComponentFromTextStream(St, C, @F.Find, AOwner);
    finally
      F.Free;
    end;
    Result := C as TaMenu;
  finally
    St.Free;
  end;
end;

initialization
  RegisterClass(TaMenu);
  RegisterEngine(MenuFamily, 'side', TaMenuSideEngine);
  RegisterEngine(MenuFamily, 'toolbar', TaMenuToolbarEngine);
  RegisterEngine(MenuFamily, 'tree', TaMenuTreeEngine);

end.
