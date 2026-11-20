unit ta_sidemenu;
{ Bocni izbornik u stilu XP trake zadataka (JvXPBar): skupine koje se sklapaju i stavke s ikonom.
  Nacrtan je sam (bez vanjskih komponenti), boje prate svijetlu ili tamnu temu, ikone dolaze iz zalihe.
  Tekst stavki, jedan redak po stavci:
    # Naslov skupine|ikona          skupina koja se sklapa (ikona nije obavezna)
    Natpis|akcija|ikona             stavka; akcija je ista kao na gumbu (openform:Racuni, openreport:..., macro:...);
                                    bez ikone program sam bira ikonu prema akciji i natpisu }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, Graphics, ImgList, LCLType;

type
  TSideMenuAction = procedure(const AAction: string) of object;
  { klik na stavku: Sender je izbornik, redni brojevi skupine i stavke (od 0), radnja stavke }
  TaSideItemClickEvent = procedure(Sender: TObject; AGroup, AItem: Integer; const AAction: string) of object;

  TaSideMenu = class;

  { stavka skupine (kao stavka TJvXPBar-a): natpis, radnja, ikona po imenu ili iz popisa slika }
  TaSideMenuItem = class(TCollectionItem)
  private
    FCaption, FAction, FIconName: string;
    FImageIndex: Integer;
    FVisible: Boolean;
    procedure SetCaption(const AValue: string);
    procedure SetAction(const AValue: string);
    procedure SetIconName(const AValue: string);
    procedure SetImageIndex(AValue: Integer);
    procedure SetVisible(AValue: Boolean);
  protected
    function GetDisplayName: string; override;
  public
    constructor Create(ACollection: TCollection); override;
    procedure Assign(ASource: TPersistent); override;
  published
    property Caption: string read FCaption write SetCaption;
    { radnja kao na gumbu: openform:Racuni, openreport:..., macro:..., fgl:Program, run:Procedura }
    property Action: string read FAction write SetAction;
    { ime ikone iz zalihe (prazno = program bira prema radnji); ima prednost ImageIndex }
    property IconName: string read FIconName write SetIconName;
    property ImageIndex: Integer read FImageIndex write SetImageIndex default -1;
    property Visible: Boolean read FVisible write SetVisible default True;
  end;

  TaSideMenuItems = class(TOwnedCollection)
  private
    function GetItem(AIndex: Integer): TaSideMenuItem;
  protected
    procedure Update(AItem: TCollectionItem); override;
  public
    constructor Create(AOwner: TPersistent);
    function Add: TaSideMenuItem;
    property Items[AIndex: Integer]: TaSideMenuItem read GetItem; default;
  end;

  { skupina koja se sklapa (kao TJvXPBar), sa svojim stavkama }
  TaSideMenuGroup = class(TCollectionItem)
  private
    FCaption, FIconName: string;
    FImageIndex: Integer;
    FItems: TaSideMenuItems;
    procedure SetCaption(const AValue: string);
    procedure SetIconName(const AValue: string);
    procedure SetImageIndex(AValue: Integer);
    procedure SetItems(AValue: TaSideMenuItems);
  protected
    function GetDisplayName: string; override;
  public
    constructor Create(ACollection: TCollection); override;
    destructor Destroy; override;
    procedure Assign(ASource: TPersistent); override;
  published
    property Caption: string read FCaption write SetCaption;
    property IconName: string read FIconName write SetIconName;
    property ImageIndex: Integer read FImageIndex write SetImageIndex default -1;
    property Items: TaSideMenuItems read FItems write SetItems;
  end;

  TaSideMenuGroups = class(TOwnedCollection)
  private
    function GetItem(AIndex: Integer): TaSideMenuGroup;
  protected
    procedure Update(AItem: TCollectionItem); override;
  public
    constructor Create(AOwner: TPersistent);
    function Add: TaSideMenuGroup;
    property Items[AIndex: Integer]: TaSideMenuGroup read GetItem; default;
  end;

  TSideItem = record
    IsGroup: Boolean;
    Caption: string;
    Action: string;
    Icon: string;
    ImageIndex: Integer;       { ikona iz popisa slika (-1 = nema) }
    Group: Integer;            { redni broj skupine kojoj stavka pripada (-1 = bez skupine) }
  end;

  TaSideMenu = class(TCustomControl)
  private
    FGroups: TaSideMenuGroups;
    FImages: TCustomImageList;
    FSyncing: Boolean;
    FOnItemClick: TaSideItemClickEvent;
    procedure TokensChanged(Sender: TObject);
    procedure SetGroups(AValue: TaSideMenuGroups);
    procedure SetImages(AValue: TCustomImageList);
    procedure RebuildFromGroups;
    procedure FillGroupsFromRows;
    procedure AfterRows(const AOldCollapsed: array of Boolean);
    function DrawRowIcon(AIndex, X, Y: Integer; AFallback: Boolean): Boolean;
    function RowHasIcon(AIndex: Integer): Boolean;
    function FindGroupStart(AIndex: Integer): Integer;
  private
    FItems: array of TSideItem;
    FCollapsed: array of Boolean;
    FText: string;
    FHot: Integer;
    FScroll: Integer;
    FOnAction: TSideMenuAction;
    FOnPointerEnter, FOnPointerLeave: TNotifyEvent;
    FAccordion: Boolean;
    FCompact: Boolean;
    FSelected: Integer;
    FStateKey: string;
    procedure SetCompact(AValue: Boolean);
    function GroupIconName(AIndex: Integer): string;
    procedure SaveState;
    procedure OpenOnly(AGroup: Integer);
    procedure SetText(const AValue: string);
    function GroupCount: Integer;
    function RowVisible(AIndex: Integer): Boolean;
    function RowHeight(AIndex: Integer): Integer;
    function RowTop(AIndex: Integer): Integer;
    function RowAt(X, Y: Integer): Integer;
    function ContentHeight: Integer;
  protected
    procedure Paint; override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseEnter; override;
    procedure MouseLeave; override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
    procedure Loaded; override;
    procedure Notification(AComponent: TComponent; AOperation: TOperation); override;
  public
    Def: TObject;                { TaControlDef kontrole (ne koristi se ovdje, da jedinica ostane neovisna) }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure GroupsChanged;
    procedure ClickRow(AIndex: Integer);
    function RowCount: Integer;
    { koliko je redaka trenutno vidljivo (u uskom izborniku samo skupine) }
    function VisibleCount: Integer;
    function RowIsGroup(AIndex: Integer): Boolean;
    function RowAction(AIndex: Integer): string;
    function RowIcon(AIndex: Integer): string;
    function IsCollapsed(AGroup: Integer): Boolean;
    { zapamceno stanje (otvorena skupina i zadnja stavka) po korisniku; zove se nakon sto su stavke postavljene }
    procedure RestoreState;
    function SelectedIndex: Integer;
    procedure SelectAction(const AAction: string);
    { uski izbornik samo s ikonama (natpis je u oblačiću); za radni prostor kad izbornik nije u upotrebi }
    property Items: string read FText write SetText;
    property OnAction: TSideMenuAction read FOnAction write FOnAction;
    property OnPointerEnter: TNotifyEvent read FOnPointerEnter write FOnPointerEnter;
    property OnPointerLeave: TNotifyEvent read FOnPointerLeave write FOnPointerLeave;
  published
    property Accordion: Boolean read FAccordion write FAccordion default True;
    { uski izbornik samo s ikonama (natpis je u oblacicu) }
    property Compact: Boolean read FCompact write SetCompact default False;
    { kljuc pod kojim se pamti otvorena skupina i zadnja stavka po korisniku }
    property StateKey: string read FStateKey write FStateKey;
    { skupine i stavke se pune u inspektoru objekata (kao kod TJvXPBar-a); tekst Items i Groups opisuju isto }
    property Groups: TaSideMenuGroups read FGroups write SetGroups;
    property Images: TCustomImageList read FImages write SetImages;
    property OnItemClick: TaSideItemClickEvent read FOnItemClick write FOnItemClick;
    property Align;
    property Anchors;
    property Font;
    property Hint;
    property ShowHint;
    property Visible;
  end;

implementation

uses
  Math, StrUtils, IniFiles, ta_icons, ta_iconmap, ta_tokens;

const
  HeadH = 30;
  ItemH = 28;
  Gap = 8;

type
  TPal = record Bg, Head, HeadText, Text, Hot, Line, Accent: TColor; end;

function Palette: TPal;
var
  T: TaThemeTokens;
begin
  T := ActiveTokens;
  Result.Accent := TokenColor(T.Accent);
  Result.Line := TokenColor(T.Border);
  Result.Text := TokenColor(T.Text);
  Result.HeadText := TokenColor(T.Text);
  Result.Head := TokenColor(T.AccentSoft);
  if T.Dark then
  begin
    Result.Bg := TokenColor(T.Surface);
    Result.Hot := TokenColor(T.Border);
  end
  else
  begin
    Result.Bg := TokenColor(T.Soft);
    Result.Hot := TokenColor(MixHex(T.AccentSoft, '#FFFFFF', 0.5));
  end;
end;


{ ---------------- zbirke za dizajn (skupine i stavke) ---------------- }

constructor TaSideMenuItem.Create(ACollection: TCollection);
begin
  FImageIndex := -1;
  FVisible := True;
  inherited Create(ACollection);
end;

procedure TaSideMenuItem.Assign(ASource: TPersistent);
begin
  if ASource is TaSideMenuItem then
  begin
    FCaption := TaSideMenuItem(ASource).FCaption; FAction := TaSideMenuItem(ASource).FAction;
    FIconName := TaSideMenuItem(ASource).FIconName; FImageIndex := TaSideMenuItem(ASource).FImageIndex;
    FVisible := TaSideMenuItem(ASource).FVisible;
    Changed(False);
  end
  else inherited Assign(ASource);
end;

function TaSideMenuItem.GetDisplayName: string;
begin
  if FCaption <> '' then Result := FCaption else Result := inherited GetDisplayName;
end;

procedure TaSideMenuItem.SetCaption(const AValue: string);
begin
  if FCaption = AValue then Exit;
  FCaption := AValue; Changed(False);
end;

procedure TaSideMenuItem.SetAction(const AValue: string);
begin
  if FAction = AValue then Exit;
  FAction := AValue; Changed(False);
end;

procedure TaSideMenuItem.SetIconName(const AValue: string);
begin
  if FIconName = AValue then Exit;
  FIconName := AValue; Changed(False);
end;

procedure TaSideMenuItem.SetImageIndex(AValue: Integer);
begin
  if FImageIndex = AValue then Exit;
  FImageIndex := AValue; Changed(False);
end;

procedure TaSideMenuItem.SetVisible(AValue: Boolean);
begin
  if FVisible = AValue then Exit;
  FVisible := AValue; Changed(False);
end;

constructor TaSideMenuItems.Create(AOwner: TPersistent);
begin
  inherited Create(AOwner, TaSideMenuItem);
end;

function TaSideMenuItems.GetItem(AIndex: Integer): TaSideMenuItem;
begin
  Result := TaSideMenuItem(inherited Items[AIndex]);
end;

function TaSideMenuItems.Add: TaSideMenuItem;
begin
  Result := TaSideMenuItem(inherited Add);
end;

procedure TaSideMenuItems.Update(AItem: TCollectionItem);
begin
  inherited Update(AItem);
  { promjena stavke je promjena njezine skupine, a ta javlja izborniku }
  if (Owner is TaSideMenuGroup) and (TaSideMenuGroup(Owner).Collection <> nil) then TaSideMenuGroup(Owner).Changed(False);
end;

constructor TaSideMenuGroup.Create(ACollection: TCollection);
begin
  { polja prije inherited: dodavanje u zbirku odmah javlja izborniku, a on cita stavke }
  FImageIndex := -1;
  FItems := TaSideMenuItems.Create(Self);
  inherited Create(ACollection);
end;

destructor TaSideMenuGroup.Destroy;
begin
  FItems.Free;
  inherited Destroy;
end;

procedure TaSideMenuGroup.Assign(ASource: TPersistent);
begin
  if ASource is TaSideMenuGroup then
  begin
    FCaption := TaSideMenuGroup(ASource).FCaption; FIconName := TaSideMenuGroup(ASource).FIconName;
    FImageIndex := TaSideMenuGroup(ASource).FImageIndex;
    FItems.Assign(TaSideMenuGroup(ASource).FItems);
    Changed(False);
  end
  else inherited Assign(ASource);
end;

function TaSideMenuGroup.GetDisplayName: string;
begin
  if FCaption <> '' then Result := FCaption else Result := inherited GetDisplayName;
end;

procedure TaSideMenuGroup.SetCaption(const AValue: string);
begin
  if FCaption = AValue then Exit;
  FCaption := AValue; Changed(False);
end;

procedure TaSideMenuGroup.SetIconName(const AValue: string);
begin
  if FIconName = AValue then Exit;
  FIconName := AValue; Changed(False);
end;

procedure TaSideMenuGroup.SetImageIndex(AValue: Integer);
begin
  if FImageIndex = AValue then Exit;
  FImageIndex := AValue; Changed(False);
end;

procedure TaSideMenuGroup.SetItems(AValue: TaSideMenuItems);
begin
  FItems.Assign(AValue);
end;

constructor TaSideMenuGroups.Create(AOwner: TPersistent);
begin
  inherited Create(AOwner, TaSideMenuGroup);
end;

function TaSideMenuGroups.GetItem(AIndex: Integer): TaSideMenuGroup;
begin
  Result := TaSideMenuGroup(inherited Items[AIndex]);
end;

function TaSideMenuGroups.Add: TaSideMenuGroup;
begin
  Result := TaSideMenuGroup(inherited Add);
end;

procedure TaSideMenuGroups.Update(AItem: TCollectionItem);
begin
  inherited Update(AItem);
  if Owner is TaSideMenu then TaSideMenu(Owner).GroupsChanged;
end;

procedure TaSideMenu.TokensChanged(Sender: TObject);
begin
  if not (csDestroying in ComponentState) then Invalidate;
end;

constructor TaSideMenu.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque];
  AddTokensListener(@TokensChanged);
  FHot := -1;
  FSelected := -1;
  FAccordion := True;
  FGroups := TaSideMenuGroups.Create(Self);
  Width := 200;
  Height := 300;
  DoubleBuffered := True;
end;

destructor TaSideMenu.Destroy;
begin
  RemoveTokensListener(@TokensChanged);
  FSyncing := True;       { brisanje zbirki ne smije ponovno slagati redove }
  FGroups.Free;
  inherited Destroy;
end;

procedure TaSideMenu.SetGroups(AValue: TaSideMenuGroups);
begin
  FGroups.Assign(AValue);
end;

procedure TaSideMenu.SetImages(AValue: TCustomImageList);
begin
  if FImages = AValue then Exit;
  FImages := AValue;
  if FImages <> nil then FImages.FreeNotification(Self);
  Invalidate;
end;

procedure TaSideMenu.Notification(AComponent: TComponent; AOperation: TOperation);
begin
  inherited Notification(AComponent, AOperation);
  if (AOperation = opRemove) and (AComponent = FImages) then begin FImages := nil; Invalidate; end;
end;

procedure TaSideMenu.Loaded;
begin
  inherited Loaded;
  RebuildFromGroups;
end;

procedure TaSideMenu.GroupsChanged;
begin
  if FSyncing or (csLoading in ComponentState) or (csDestroying in ComponentState) then Exit;
  RebuildFromGroups;
end;

{ nakon sto su redci postavljeni: stanje sklapanja skupina, odabir i pomak }
procedure TaSideMenu.AfterRows(const AOldCollapsed: array of Boolean);
var
  P: Integer;
begin
  SetLength(FCollapsed, GroupCount);
  for P := 0 to High(FCollapsed) do
    if P <= High(AOldCollapsed) then FCollapsed[P] := AOldCollapsed[P]
    else FCollapsed[P] := FAccordion and (P > 0);     { harmonika: na pocetku je otvorena samo prva skupina }
  FSelected := -1;
  FScroll := 0;
  Invalidate;
end;

{ redci i tekst iz zbirki Groups (stavke s Visible = False se preskacu) }
procedure TaSideMenu.RebuildFromGroups;
var
  G, K, N: Integer;
  Gr: TaSideMenuGroup;
  It: TaSideMenuItem;
  OldCol: array of Boolean;
  Txt: string;
begin
  OldCol := FCollapsed;
  SetLength(FItems, 0);
  Txt := '';
  N := 0;
  for G := 0 to FGroups.Count - 1 do
  begin
    Gr := FGroups[G];
    SetLength(FItems, N + 1);
    FItems[N].IsGroup := True; FItems[N].Caption := Gr.Caption; FItems[N].Action := '';
    FItems[N].Icon := Gr.IconName; FItems[N].ImageIndex := Gr.ImageIndex; FItems[N].Group := G;
    Inc(N);
    Txt := Txt + '# ' + Gr.Caption + IfThen(Gr.IconName <> '', '|' + Gr.IconName, '') + LineEnding;
    for K := 0 to Gr.Items.Count - 1 do
    begin
      It := Gr.Items[K];
      if not It.Visible then Continue;
      SetLength(FItems, N + 1);
      FItems[N].IsGroup := False; FItems[N].Caption := It.Caption; FItems[N].Action := It.Action;
      FItems[N].ImageIndex := It.ImageIndex; FItems[N].Group := G;
      if It.IconName <> '' then FItems[N].Icon := It.IconName
      else if (It.ImageIndex >= 0) and (FImages <> nil) then FItems[N].Icon := ''
      else FItems[N].Icon := ActionIconName(It.Action, It.Caption);
      Inc(N);
      Txt := Txt + It.Caption + '|' + It.Action + IfThen(It.IconName <> '', '|' + It.IconName, '') + LineEnding;
    end;
  end;
  FText := Txt;
  AfterRows(OldCol);
end;

{ zbirke iz redaka (kad je izbornik postavljen tekstom) }
procedure TaSideMenu.FillGroupsFromRows;
var
  I: Integer;
  Gr: TaSideMenuGroup;
  It: TaSideMenuItem;
begin
  FSyncing := True;
  try
    FGroups.BeginUpdate;
    try
      FGroups.Clear;
      Gr := nil;
      for I := 0 to High(FItems) do
      begin
        if FItems[I].IsGroup then
        begin
          Gr := FGroups.Add;
          Gr.Caption := FItems[I].Caption; Gr.IconName := FItems[I].Icon; Gr.ImageIndex := -1;
        end
        else if Gr <> nil then
        begin
          It := Gr.Items.Add;
          It.Caption := FItems[I].Caption; It.Action := FItems[I].Action; It.IconName := FItems[I].Icon; It.ImageIndex := -1;
        end;
      end;
    finally
      FGroups.EndUpdate;
    end;
  finally
    FSyncing := False;
  end;
end;

procedure TaSideMenu.SetText(const AValue: string);
var
  L: TStringList;
  I, G, N: Integer;
  Ln, A, B, C: string;
  OldCol: array of Boolean;

  function Part(const S: string; AIndex: Integer): string;
  var
    K, Q: Integer;
    R: string;
  begin
    R := S;
    for K := 1 to AIndex do
    begin
      Q := Pos('|', R);
      if Q = 0 then Exit('');
      R := Copy(R, Q + 1, MaxInt);
    end;
    Q := Pos('|', R);
    if Q > 0 then R := Copy(R, 1, Q - 1);
    Result := Trim(R);
  end;

begin
  FText := AValue;
  OldCol := FCollapsed;
  L := TStringList.Create;
  try
    L.Text := AValue;
    SetLength(FItems, 0);
    G := -1;
    N := 0;
    for I := 0 to L.Count - 1 do
    begin
      Ln := Trim(L[I]);
      if Ln = '' then Continue;
      SetLength(FItems, N + 1);
      if Ln[1] = '#' then
      begin
        Inc(G);
        Ln := Trim(Copy(Ln, 2, MaxInt));
        FItems[N].IsGroup := True;
        FItems[N].Caption := Part(Ln, 0);
        FItems[N].Icon := Part(Ln, 1);
        FItems[N].ImageIndex := -1;
        FItems[N].Action := '';
        FItems[N].Group := G;
      end
      else
      begin
        A := Part(Ln, 0); B := Part(Ln, 1); C := Part(Ln, 2);
        FItems[N].IsGroup := False;
        FItems[N].Caption := A;
        FItems[N].Action := B;
        FItems[N].ImageIndex := -1;
        if C <> '' then FItems[N].Icon := C else FItems[N].Icon := ActionIconName(B, A);
        FItems[N].Group := G;
      end;
      Inc(N);
    end;
  finally
    L.Free;
  end;
  AfterRows(OldCol);
  FillGroupsFromRows;
end;

function TaSideMenu.GroupCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(FItems) do if FItems[I].IsGroup then Inc(Result);
end;

{ ikona skupine: njezina vlastita, inace ikona prve stavke u skupini }
function TaSideMenu.GroupIconName(AIndex: Integer): string;
var
  I: Integer;
begin
  Result := FItems[AIndex].Icon;
  if Result <> '' then Exit;
  for I := AIndex + 1 to High(FItems) do
  begin
    if FItems[I].IsGroup then Break;
    if FItems[I].Icon <> '' then Exit(FItems[I].Icon);
  end;
  Result := 'category';
end;

procedure TaSideMenu.SetCompact(AValue: Boolean);
begin
  if FCompact = AValue then Exit;
  FCompact := AValue;
  FScroll := 0;
  FHot := -1;
  Hint := '';
  Invalidate;
end;

function TaSideMenu.RowVisible(AIndex: Integer): Boolean;
begin
  { uski izbornik: samo skupine (i stavke izvan skupina), ne i stavke unutar skupina }
  if FCompact then Exit(FItems[AIndex].IsGroup or (FItems[AIndex].Group < 0));
  Result := FItems[AIndex].IsGroup or (FItems[AIndex].Group < 0) or not FCollapsed[FItems[AIndex].Group];
end;

function TaSideMenu.RowHeight(AIndex: Integer): Integer;
begin
  if FCompact then
  begin
    Result := 40;
    Exit;
  end;
  if FItems[AIndex].IsGroup then Result := HeadH else Result := ItemH;
end;

function TaSideMenu.RowTop(AIndex: Integer): Integer;
var
  I: Integer;
begin
  Result := Gap - FScroll;
  for I := 0 to AIndex - 1 do
  begin
    if not RowVisible(I) then Continue;
    Inc(Result, RowHeight(I));
    if FCompact then Continue;
    if FItems[I].IsGroup then Inc(Result, 2);
    { razmak iza zadnje stavke skupine }
    if (I < High(FItems)) and (not FItems[I].IsGroup) and FItems[I + 1].IsGroup then Inc(Result, Gap);
    if FItems[I].IsGroup and (I < High(FItems)) and FItems[I + 1].IsGroup then Inc(Result, Gap);
  end;
end;

function TaSideMenu.ContentHeight: Integer;
var
  I: Integer;
begin
  Result := Gap;
  for I := 0 to High(FItems) do
  begin
    if not RowVisible(I) then Continue;
    Inc(Result, RowHeight(I));
    if FCompact then Continue;
    if FItems[I].IsGroup then Inc(Result, 2);
    if (I < High(FItems)) and (not FItems[I].IsGroup) and FItems[I + 1].IsGroup then Inc(Result, Gap);
    if FItems[I].IsGroup and (I < High(FItems)) and FItems[I + 1].IsGroup then Inc(Result, Gap);
  end;
  Inc(Result, Gap);
end;

function TaSideMenu.RowAt(X, Y: Integer): Integer;
var
  I, T: Integer;
begin
  Result := -1;
  if (not FCompact) and ((X < Gap) or (X > Width - Gap)) then Exit;
  for I := 0 to High(FItems) do
  begin
    if not RowVisible(I) then Continue;
    T := RowTop(I);
    if (Y >= T) and (Y < T + RowHeight(I)) then Exit(I);
  end;
end;

function TaSideMenu.RowHasIcon(AIndex: Integer): Boolean;
begin
  Result := (FItems[AIndex].Icon <> '') or ((FItems[AIndex].ImageIndex >= 0) and (FImages <> nil) and (FItems[AIndex].ImageIndex < FImages.Count));
end;

{ ikona retka: iz popisa slika (ImageIndex) ili iz zalihe po imenu; AFallback = skupina bez ikone uzima ikonu prve stavke }
function TaSideMenu.DrawRowIcon(AIndex, X, Y: Integer; AFallback: Boolean): Boolean;
var
  Png: TPortableNetworkGraphic;
  Nm: string;
begin
  Result := False;
  if (FItems[AIndex].ImageIndex >= 0) and (FImages <> nil) and (FItems[AIndex].ImageIndex < FImages.Count) then
  begin
    FImages.Draw(Canvas, X, Y, FItems[AIndex].ImageIndex);
    Exit(True);
  end;
  if AFallback and FItems[AIndex].IsGroup then Nm := GroupIconName(AIndex) else Nm := FItems[AIndex].Icon;
  if Nm = '' then Exit;
  Png := IconPng(Nm, 16);
  if Png <> nil then begin Canvas.Draw(X, Y, Png); Result := True; end;
end;

procedure TaSideMenu.Paint;
var
  P: TPal;
  I, T, H, X0, TX, Cy, G: Integer;
  R: TRect;
  Pts: array[0..2] of TPoint;
  Sel: Boolean;
begin
  P := Palette;
  Canvas.Brush.Color := P.Bg;
  Canvas.FillRect(ClientRect);
  Canvas.Font.Assign(Font);
  for I := 0 to High(FItems) do
  begin
    if not RowVisible(I) then Continue;
    T := RowTop(I);
    H := RowHeight(I);
    if (T + H < 0) or (T > Height) then Continue;
    R := Rect(Gap, T, Width - Gap, T + H);
    if FCompact then
    begin
      Sel := (I = FSelected) or (FItems[I].IsGroup and (FSelected >= 0) and (FItems[FSelected].Group = FItems[I].Group));
      if Sel or (I = FHot) then
      begin
        Canvas.Brush.Color := P.Hot;
        Canvas.Pen.Color := P.Hot;
        Canvas.RoundRect(3, T + 2, Width - 3, T + H - 2, 6, 6);
      end;
      if Sel then
      begin
        Canvas.Brush.Color := P.Accent;
        Canvas.Pen.Color := P.Accent;
        Canvas.Rectangle(0, T + 8, 3, T + H - 8);
      end;
      DrawRowIcon(I, (Width - 16) div 2, T + (H - 16) div 2, True);
      Continue;
    end;
    if FItems[I].IsGroup then
    begin
      Canvas.Brush.Color := P.Head;
      Canvas.Pen.Color := P.Head;
      Canvas.RoundRect(R.Left, R.Top, R.Right, R.Bottom, 8, 8);
      TX := R.Left + 8;
      if RowHasIcon(I) then
        if DrawRowIcon(I, TX, T + (H - 16) div 2, False) then Inc(TX, 22);
      Canvas.Brush.Style := bsClear;
      Canvas.Font.Style := [fsBold];
      Canvas.Font.Color := P.HeadText;
      Canvas.TextOut(TX, T + (H - Canvas.TextHeight('Ag')) div 2, FItems[I].Caption);
      Canvas.Font.Style := [];
      { strelica: dolje = otvoreno, desno = sklopljeno }
      Cy := T + H div 2;
      X0 := R.Right - 16;
      Canvas.Brush.Style := bsSolid;
      Canvas.Brush.Color := P.HeadText;
      Canvas.Pen.Color := P.HeadText;
      if FCollapsed[FItems[I].Group] then
      begin
        Pts[0] := Point(X0 - 2, Cy - 4); Pts[1] := Point(X0 - 2, Cy + 4); Pts[2] := Point(X0 + 3, Cy);
      end
      else
      begin
        Pts[0] := Point(X0 - 4, Cy - 2); Pts[1] := Point(X0 + 4, Cy - 2); Pts[2] := Point(X0, Cy + 3);
      end;
      Canvas.Polygon(Pts);
      Canvas.Brush.Style := bsClear;
    end
    else
    begin
      G := FItems[I].Group;
      if I = FSelected then
      begin
        Canvas.Brush.Color := P.Hot;
        Canvas.Pen.Color := P.Hot;
        Canvas.RoundRect(R.Left + 4, R.Top, R.Right - 4, R.Bottom, 6, 6);
        Canvas.Brush.Color := P.Accent;
        Canvas.Pen.Color := P.Accent;
        Canvas.Rectangle(R.Left + 4, R.Top + 4, R.Left + 7, R.Bottom - 4);
      end
      else if I = FHot then
      begin
        Canvas.Brush.Color := P.Hot;
        Canvas.Pen.Color := P.Hot;
        Canvas.RoundRect(R.Left + 4, R.Top, R.Right - 4, R.Bottom, 6, 6);
      end;
      Canvas.Brush.Style := bsClear;
      TX := R.Left + 14;
      if G < 0 then TX := R.Left + 8;
      if RowHasIcon(I) then
      begin
        DrawRowIcon(I, TX, T + (H - 16) div 2, False);
        Inc(TX, 24);
      end;
      Canvas.Font.Style := [];
      if (I = FHot) or (I = FSelected) then Canvas.Font.Color := P.Accent else Canvas.Font.Color := P.Text;
      if I = FSelected then Canvas.Font.Style := [fsBold]
      else if I = FHot then Canvas.Font.Style := [fsUnderline];
      Canvas.TextOut(TX, T + (H - Canvas.TextHeight('Ag')) div 2, FItems[I].Caption);
      Canvas.Font.Style := [];
    end;
  end;
  Canvas.Brush.Style := bsClear;
  Canvas.Pen.Color := P.Line;
  Canvas.Rectangle(0, 0, Width, Height);
end;

procedure TaSideMenu.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  R: Integer;
begin
  inherited MouseMove(Shift, X, Y);
  R := RowAt(X, Y);
  if (R >= 0) and FItems[R].IsGroup and not FCompact then R := -1;
  if R <> FHot then
  begin
    FHot := R;
    if (R >= 0) then Cursor := crHandPoint else Cursor := crDefault;
    if FCompact and (R >= 0) then begin Hint := FItems[R].Caption; ShowHint := True; end else Hint := '';
    Invalidate;
  end;
end;

procedure TaSideMenu.MouseEnter;
var
  Pt: TPoint;
  R: Integer;
begin
  inherited MouseEnter;
  { iz uskog izbornika: skupina na koju je dosao mis bit ce otvorena kad se izbornik prosiri }
  if FCompact and FAccordion then
  begin
    Pt := ScreenToClient(Mouse.CursorPos);
    R := RowAt(Pt.X, Pt.Y);
    if (R >= 0) and FItems[R].IsGroup then OpenOnly(FItems[R].Group)
    else if (R >= 0) and (FItems[R].Group >= 0) then OpenOnly(FItems[R].Group);
  end;
  if Assigned(FOnPointerEnter) then FOnPointerEnter(Self);
end;

procedure TaSideMenu.MouseLeave;
begin
  inherited MouseLeave;
  if Assigned(FOnPointerLeave) then FOnPointerLeave(Self);
  if FHot <> -1 then begin FHot := -1; Invalidate; end;
end;

procedure TaSideMenu.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  R: Integer;
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then Exit;
  R := RowAt(X, Y);
  if R >= 0 then ClickRow(R);
end;

function TaSideMenu.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
var
  Mx: Integer;
begin
  Mx := Max(0, ContentHeight - Height);
  FScroll := Max(0, Min(Mx, FScroll - WheelDelta div 3));
  Invalidate;
  Result := True;
end;

{ redak skupine kojoj stavka pripada (-1 = nema) }
function TaSideMenu.FindGroupStart(AIndex: Integer): Integer;
begin
  Result := AIndex;
  while (Result >= 0) and not FItems[Result].IsGroup do Dec(Result);
end;

procedure TaSideMenu.ClickRow(AIndex: Integer);
var
  Mx, I, K: Integer;
begin
  if (AIndex < 0) or (AIndex > High(FItems)) then Exit;
  if FItems[AIndex].IsGroup then
  begin
    if FCompact then OpenOnly(FItems[AIndex].Group)
    else if FCollapsed[FItems[AIndex].Group] and FAccordion then OpenOnly(FItems[AIndex].Group)
    else FCollapsed[FItems[AIndex].Group] := not FCollapsed[FItems[AIndex].Group];
    Mx := Max(0, ContentHeight - Height);
    if FScroll > Mx then FScroll := Mx;
    SaveState;
    Invalidate;
  end
  else
  begin
    FSelected := AIndex;
    SaveState;
    Invalidate;
    if FItems[AIndex].Action <> '' then
    begin
      if Assigned(FOnItemClick) then
      begin
        K := 0;
        for I := FindGroupStart(AIndex) + 1 to AIndex - 1 do if not FItems[I].IsGroup then Inc(K);
        FOnItemClick(Self, FItems[AIndex].Group, K, FItems[AIndex].Action);
      end;
      if Assigned(FOnAction) then FOnAction(FItems[AIndex].Action);
    end;
  end;
end;

procedure TaSideMenu.OpenOnly(AGroup: Integer);
var
  I: Integer;
begin
  for I := 0 to High(FCollapsed) do FCollapsed[I] := I <> AGroup;
end;

function TaSideMenu.SelectedIndex: Integer;
begin
  Result := FSelected;
end;

procedure TaSideMenu.SelectAction(const AAction: string);
var
  I: Integer;
begin
  for I := 0 to High(FItems) do
    if (not FItems[I].IsGroup) and (FItems[I].Action = AAction) then
    begin
      FSelected := I;
      if (FItems[I].Group >= 0) and FAccordion then OpenOnly(FItems[I].Group)
      else if FItems[I].Group >= 0 then FCollapsed[FItems[I].Group] := False;
      SaveState;
      Invalidate;
      Exit;
    end;
end;

function StateFile: string;
begin
  Result := IncludeTrailingPathDelimiter(GetAppConfigDir(False)) + 'sidemenu.ini';
end;

procedure TaSideMenu.SaveState;
var
  F: TIniFile;
  I: Integer;
  Open: string;
begin
  if FStateKey = '' then Exit;
  try
    ForceDirectories(ExtractFilePath(StateFile));
    F := TIniFile.Create(StateFile);
    try
      Open := '';
      for I := 0 to High(FCollapsed) do
        if not FCollapsed[I] then Open := Open + IntToStr(I) + ',';
      F.WriteString(FStateKey, 'open', Open);
      if FSelected >= 0 then F.WriteString(FStateKey, 'item', FItems[FSelected].Caption + '|' + FItems[FSelected].Action)
      else F.WriteString(FStateKey, 'item', '');
    finally
      F.Free;
    end;
  except
  end;
end;

procedure TaSideMenu.RestoreState;
var
  F: TIniFile;
  I, G: Integer;
  Open, Item: string;
  Sl: TStringList;
begin
  if (FStateKey = '') or not FileExists(StateFile) then Exit;
  try
    F := TIniFile.Create(StateFile);
    try
      if not F.SectionExists(FStateKey) then Exit;
      Open := F.ReadString(FStateKey, 'open', '');
      Item := F.ReadString(FStateKey, 'item', '');
    finally
      F.Free;
    end;
  except
    Exit;
  end;
  Sl := TStringList.Create;
  try
    Sl.CommaText := Open;
    for I := 0 to High(FCollapsed) do FCollapsed[I] := Sl.IndexOf(IntToStr(I)) < 0;
  finally
    Sl.Free;
  end;
  FSelected := -1;
  for I := 0 to High(FItems) do
    if (not FItems[I].IsGroup) and (FItems[I].Caption + '|' + FItems[I].Action = Item) then
    begin
      FSelected := I;
      G := FItems[I].Group;
      { zapamcena stavka uvijek je vidljiva: njezina skupina je otvorena }
      if G >= 0 then
      begin
        if FAccordion then OpenOnly(G) else FCollapsed[G] := False;
      end;
      Break;
    end;
  if FAccordion then
  begin
    { najvise jedna otvorena skupina }
    G := -1;
    for I := 0 to High(FCollapsed) do
      if not FCollapsed[I] then begin if G < 0 then G := I else FCollapsed[I] := True; end;
  end;
  Invalidate;
end;

function TaSideMenu.VisibleCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(FItems) do if RowVisible(I) then Inc(Result);
end;

function TaSideMenu.RowCount: Integer;
begin
  Result := Length(FItems);
end;

function TaSideMenu.RowIsGroup(AIndex: Integer): Boolean;
begin
  Result := FItems[AIndex].IsGroup;
end;

function TaSideMenu.RowAction(AIndex: Integer): string;
begin
  Result := FItems[AIndex].Action;
end;

function TaSideMenu.RowIcon(AIndex: Integer): string;
begin
  Result := FItems[AIndex].Icon;
end;

function TaSideMenu.IsCollapsed(AGroup: Integer): Boolean;
begin
  Result := (AGroup >= 0) and (AGroup <= High(FCollapsed)) and FCollapsed[AGroup];
end;

end.
