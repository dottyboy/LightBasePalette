unit ta_shell;
{ Radni prostor aplikacije u radu: zaglavlje (naslov, korisnik, odjava), bocni izbornik i kartice.
  Svaka forma otvara se kao kartica (nesto poput MDI-ja preko PageControla), a zatvaranjem kartice zatvara se forma.
  Pravila: ista forma moze biti otvorena samo jednom (ponovno otvaranje vraca na njezinu karticu), a od forma iste
  "skupine iskljucivosti" (npr. Skladisni dokumenti) otvorena moze biti samo jedna u isto vrijeme. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, Forms, ExtCtrls, ComCtrls, StdCtrls, Buttons, Graphics, Contnrs,
  ta_meta, ta_formdef, ta_formrun, ta_sidemenu, ta_tabbar, ta_doctypes;

type
  TShellActionEvent = procedure(const AAction: string) of object;

  TShellTab = class
  public
    Name: string;          { naziv forme }
    Key: string;           { naziv forme + parametri: ista forma s drugom vrstom je druga kartica }
    Arg: string;           { izvorni argument akcije (za oznacavanje u izborniku) }
    DocCode: string;       { vrsta dokumenta objedinjene forme ('' = obicna forma) }
    Caption: string;
    Group: string;         { skupina iskljucivosti ('' = nema) }
    Runner: TaFormRunner;
    Sheet: TTabSheet;
    Scroll: TScrollBox;
  end;

  TaShell = class(TPanel)
  private
    FDb: TAppDb;
    FHead: TPanel;
    FTitle, FUser, FWelcome: TLabel;
    FOut: TBitBtn;
    FToggle: TSpeedButton;
    FLeave: TTimer;
    FPinned, FHover: Boolean;
    FMenuW: Integer;
    FMenuRight: Boolean;
    FMenu: TaSideMenu;
    FBody: TPanel;
    FBar: TaTabBar;
    FPages: TPageControl;
    FTabs: TObjectList;
    FOnAction: TShellActionEvent;
    FOnLogout: TNotifyEvent;
    FLastMsg: string;
    procedure MenuAction(const AAction: string);
    procedure BarSelect(Sender: TObject);
    procedure BarClose(Sender: TObject);
    procedure RunnerClosed(Sender: TObject);
    procedure DoRemove(Data: PtrInt);
    procedure LogoutClick(Sender: TObject);
    procedure LayoutShell;
    procedure ToggleClick(Sender: TObject);
    procedure MenuEnter(Sender: TObject);
    procedure MenuLeave(Sender: TObject);
    procedure LeaveTimer(Sender: TObject);
    procedure SetPinned(AValue: Boolean);
    procedure ShellResize(Sender: TObject);
    function StateFile: string;
    procedure SheetResize(Sender: TObject);
    procedure ShowCurrent;
    procedure Notify(const AMsg: string);
    function FindTab(const AKey: string): Integer;
    function TabOfRunner(ARunner: TObject): Integer;
    function GetTabCount: Integer;
    function GetActiveName: string;
  public
    constructor CreateShell(AOwner: TComponent; ADb: TAppDb);
    destructor Destroy; override;
    { izbornik: tekst stavki kao kod kontrole SideMenu, ili prazno = sam slozi iz objekata baze }
    procedure SetMenuText(const AText: string);
    procedure BuildDefaultMenu;
    procedure SetTitle(const ATitle: string);
    { izgled ljuske iz predloska glavne forme: sirina i strana izbornika, boja zaglavlja i naslova (clNone = tema) }
    procedure SetLook(AMenuWidth: Integer; AMenuRight: Boolean; AHeadColor, AHeadFore: TColor);
    property MenuRight: Boolean read FMenuRight;
    property MenuFullWidth: Integer read FMenuW;
    procedure SetUserText(const AText: string);
    { False ako forma ne postoji, nemate pravo ili je blokira otvorena forma iste skupine; tada se javlja poruka }
    function OpenForm(const AName: string): Boolean;
    { moze li se forma sada otvoriti; ako ne, ABlocker je naziv otvorene forme zbog koje ne moze }
    function CanOpen(const AKey, AGroup, ADocCode: string; out ABlocker: string): Boolean;
    procedure ActivateTab(AIndex: Integer);
    procedure CloseActive;
    { zatvara sve kartice; False ako je neka odbila zatvaranje (npr. nespremljen zapis) }
    function CloseAll: Boolean;
    function TabName(AIndex: Integer): string;
    function TabGroup(AIndex: Integer): string;
    function TabRunner(AIndex: Integer): TaFormRunner;
    { izbornik je ili stalno otvoren (pricvrscen) ili uski s ikonama koji se prosiri iznad forme kad se mis dovede na njega }
    property Pinned: Boolean read FPinned write SetPinned;
    function MenuWidth: Integer;
    function BodyLeft: Integer;
    procedure HoverForTest(AOn: Boolean);
    property TabCount: Integer read GetTabCount;
    property ActiveName: string read GetActiveName;
    property Menu: TaSideMenu read FMenu;
    property Bar: TaTabBar read FBar;
    property LastMessage: string read FLastMsg;
    property OnAction: TShellActionEvent read FOnAction write FOnAction;
    property OnLogout: TNotifyEvent read FOnLogout write FOnLogout;
  end;

implementation

uses
  ta_i18n,
  Dialogs, Menus, IniFiles, ta_app, ta_iconmap, ta_icons;

constructor TaShell.CreateShell(AOwner: TComponent; ADb: TAppDb);
begin
  inherited Create(AOwner);
  FDb := ADb;
  FTabs := TObjectList.Create(True);
  BevelOuter := bvNone;
  Align := alClient;

  FHead := TPanel.Create(Self);
  FHead.Parent := Self;
  FHead.Align := alTop;
  FHead.Height := 46;
  FHead.BevelOuter := bvNone;
  FToggle := TSpeedButton.Create(Self);
  FToggle.Parent := FHead;
  FToggle.SetBounds(8, 7, 32, 32);
  FToggle.Flat := True;
  FToggle.Hint := Tr('Pin the menu or collapse it into an icon bar');
  FToggle.ShowHint := True;
  FToggle.OnClick := @ToggleClick;
  if IconPng('menu', 24) <> nil then FToggle.Glyph.Assign(IconPng('menu', 24));
  FTitle := TLabel.Create(Self);
  FTitle.Parent := FHead;
  FTitle.SetBounds(52, 11, 400, 24);
  FTitle.Font.Size := 13;
  FTitle.Font.Style := [fsBold];
  FOut := TBitBtn.Create(Self);
  FOut.Parent := FHead;
  FOut.Caption := Tr('Log out');
  FOut.Anchors := [akTop, akRight];
  FOut.SetBounds(Width - 110, 8, 94, 30);
  FOut.OnClick := @LogoutClick;
  FUser := TLabel.Create(Self);
  FUser.Parent := FHead;
  FUser.Anchors := [akTop, akRight];
  FUser.AutoSize := False;
  FUser.Alignment := taRightJustify;
  FUser.SetBounds(Width - 330, 14, 210, 20);

  FMenu := TaSideMenu.Create(Self);
  FMenu.Parent := Self;
  FMenu.Align := alNone;
  FMenuW := 250;
  FMenu.Width := FMenuW;
  FMenu.OnPointerEnter := @MenuEnter;
  FMenu.OnPointerLeave := @MenuLeave;
  FMenu.OnAction := @MenuAction;
  FMenu.StateKey := 'shell/' + ExtractFileName(FDb.Conn.Database);

  FBody := TPanel.Create(Self);
  FBody.Parent := Self;
  FBody.Align := alNone;
  FBody.BevelOuter := bvNone;

  FBar := TaTabBar.Create(Self);
  FBar.Parent := FBody;
  FBar.Align := alTop;
  FBar.OnSelect := @BarSelect;
  FBar.OnClose := @BarClose;

  FPages := TPageControl.Create(Self);
  FPages.Parent := FBody;
  FPages.Align := alClient;
  FPages.ShowTabs := False;

  FWelcome := TLabel.Create(Self);
  FWelcome.Parent := FBody;
  FWelcome.Align := alClient;
  FWelcome.Alignment := taCenter;
  FWelcome.Layout := tlCenter;
  FWelcome.Caption := Tr('Choose an item in the menu on the left.');
  FLeave := TTimer.Create(Self);
  FLeave.Enabled := False;
  FLeave.Interval := 350;
  FLeave.OnTimer := @LeaveTimer;
  FPinned := True;
  try
    if FileExists(StateFile) then
      with TIniFile.Create(StateFile) do
      try
        FPinned := ReadString('shell/' + ExtractFileName(FDb.Conn.Database), 'pinned', '1') <> '0';
      finally
        Free;
      end;
  except
  end;
  OnResize := @ShellResize;
  LayoutShell;
  SetGlyph(FOut, 'power', 16);
  FWelcome.Font.Size := 12;
  FWelcome.Font.Color := clGray;
  ShowCurrent;
end;

destructor TaShell.Destroy;
begin
  Application.RemoveAsyncCalls(Self);
  FTabs.Free;
  inherited Destroy;
end;

function TaShell.StateFile: string;
begin
  Result := IncludeTrailingPathDelimiter(GetAppConfigDir(False)) + 'sidemenu.ini';
end;

function TaShell.MenuWidth: Integer;
begin
  if FPinned or FHover then Result := FMenuW else Result := 44;
end;

function TaShell.BodyLeft: Integer;
begin
  if FMenuRight then Result := 0
  else if FPinned then Result := FMenuW
  else Result := 44;
end;

procedure TaShell.LayoutShell;
var
  T, H: Integer;
begin
  if (FMenu = nil) or (FBody = nil) then Exit;
  T := FHead.Height;
  H := ClientHeight - T;
  if H < 10 then H := 10;
  FMenu.Compact := not (FPinned or FHover);
  if FMenuRight then
  begin
    if FPinned then FBody.SetBounds(0, T, ClientWidth - FMenuW, H) else FBody.SetBounds(0, T, ClientWidth - 44, H);
    FMenu.SetBounds(ClientWidth - MenuWidth, T, MenuWidth, H);
  end
  else
  begin
    FBody.SetBounds(BodyLeft, T, ClientWidth - BodyLeft, H);
    FMenu.SetBounds(0, T, MenuWidth, H);
  end;
  FMenu.BringToFront;
end;

procedure TaShell.ShellResize(Sender: TObject);
begin
  LayoutShell;
end;

procedure TaShell.SetPinned(AValue: Boolean);
begin
  FPinned := AValue;
  FHover := False;
  LayoutShell;
  try
    ForceDirectories(ExtractFilePath(StateFile));
    with TIniFile.Create(StateFile) do
    try
      WriteString('shell/' + ExtractFileName(FDb.Conn.Database), 'pinned', IntToStr(Ord(FPinned)));
    finally
      Free;
    end;
  except
  end;
end;

procedure TaShell.ToggleClick(Sender: TObject);
begin
  SetPinned(not FPinned);
end;

procedure TaShell.MenuEnter(Sender: TObject);
begin
  FLeave.Enabled := False;
  if (not FPinned) and (not FHover) then
  begin
    FHover := True;
    LayoutShell;
  end;
end;

procedure TaShell.MenuLeave(Sender: TObject);
begin
  if (not FPinned) and FHover then
  begin
    FLeave.Enabled := False;
    FLeave.Enabled := True;
  end;
end;

procedure TaShell.LeaveTimer(Sender: TObject);
begin
  FLeave.Enabled := False;
  if FHover then
  begin
    FHover := False;
    LayoutShell;
  end;
end;

procedure TaShell.HoverForTest(AOn: Boolean);
begin
  if AOn then MenuEnter(nil)
  else begin MenuLeave(nil); LeaveTimer(nil); end;
end;

procedure TaShell.SetLook(AMenuWidth: Integer; AMenuRight: Boolean; AHeadColor, AHeadFore: TColor);
var
  OldDark: Boolean;
  Rgb: TColor;
begin
  if AMenuWidth < 120 then AMenuWidth := 120;
  if AMenuWidth > 600 then AMenuWidth := 600;
  FMenuW := AMenuWidth;
  FMenuRight := AMenuRight;
  if AHeadColor <> clNone then FHead.Color := AHeadColor else FHead.Color := clDefault;
  { ikona izbornika: svijetla varijanta na tamnom zaglavlju }
  OldDark := IconDarkMode;
  if AHeadColor <> clNone then
  begin
    Rgb := ColorToRGB(AHeadColor);
    SetIconDark(((Red(Rgb) * 299 + Green(Rgb) * 587 + Blue(Rgb) * 114) div 1000) < 140);
  end;
  try
    if IconPng('menu', 24) <> nil then FToggle.Glyph.Assign(IconPng('menu', 24));
  finally
    SetIconDark(OldDark);
  end;
  if AHeadFore <> clNone then
  begin
    FTitle.Font.Color := AHeadFore;
    FUser.Font.Color := AHeadFore;
  end
  else
  begin
    FTitle.Font.Color := clDefault;
    FUser.Font.Color := clDefault;
  end;
  LayoutShell;
end;

procedure TaShell.SetTitle(const ATitle: string);
begin
  FTitle.Caption := ATitle;
end;

procedure TaShell.SetUserText(const AText: string);
begin
  FUser.Caption := AText;
end;

procedure TaShell.Notify(const AMsg: string);
begin
  FLastMsg := AMsg;
  if Assigned(OnRunnerMessage) then OnRunnerMessage(AMsg) else ShowMessage(AMsg);
end;

procedure TaShell.SetMenuText(const AText: string);
begin
  FMenu.Items := AText;
  FMenu.RestoreState;
end;

procedure TaShell.BuildDefaultMenu;
var
  L: TStringList;
  Txt: string;
  procedure Section(const ATitle, ATable, AVerb: string);
  var
    I: Integer;
    Any: Boolean;
  begin
    L := FDb.ListObjects(ATable);
    try
      Any := False;
      for I := 0 to L.Count - 1 do
        if CanRun(FDb, ATable, L[I]) and (Copy(L[I], 1, 1) <> '_') then
        begin
          if not Any then Txt := Txt + '# ' + ATitle + LineEnding;
          Any := True;
          Txt := Txt + L[I] + '|' + AVerb + ':' + L[I] + LineEnding;
        end;
    finally
      L.Free;
    end;
  end;
begin
  Txt := '';
  Section('Forme', '_sys_forms', 'openform');
  Section('Izvješća', '_sys_reports', 'openreport');
  Section('Makroi', '_sys_macros', 'macro');
  SetMenuText(Txt);
end;

function TaShell.GetTabCount: Integer;
begin
  Result := FTabs.Count;
end;

function TaShell.GetActiveName: string;
begin
  if (FBar.ActiveIndex >= 0) and (FBar.ActiveIndex < FTabs.Count) then Result := TShellTab(FTabs[FBar.ActiveIndex]).Name
  else Result := '';
end;

function TaShell.TabName(AIndex: Integer): string;
begin
  Result := TShellTab(FTabs[AIndex]).Name;
end;

function TaShell.TabGroup(AIndex: Integer): string;
begin
  Result := TShellTab(FTabs[AIndex]).Group;
end;

function TaShell.TabRunner(AIndex: Integer): TaFormRunner;
begin
  Result := TShellTab(FTabs[AIndex]).Runner;
end;

function TaShell.FindTab(const AKey: string): Integer;
var
  I: Integer;
begin
  for I := 0 to FTabs.Count - 1 do
    if SameText(TShellTab(FTabs[I]).Key, AKey) then Exit(I);
  Result := -1;
end;

function TaShell.TabOfRunner(ARunner: TObject): Integer;
var
  I: Integer;
begin
  for I := 0 to FTabs.Count - 1 do
    if TShellTab(FTabs[I]).Runner = ARunner then Exit(I);
  Result := -1;
end;

procedure TaShell.SheetResize(Sender: TObject);
var
  I: Integer;
begin
  for I := 0 to FTabs.Count - 1 do
    if TShellTab(FTabs[I]).Sheet = Sender then
      with TShellTab(FTabs[I]) do Runner.FitTo(Sheet.ClientWidth, Sheet.ClientHeight);
end;

procedure TaShell.ShowCurrent;
begin
  FPages.Visible := FTabs.Count > 0;
  FWelcome.Visible := FTabs.Count = 0;
end;

function TaShell.CanOpen(const AKey, AGroup, ADocCode: string; out ABlocker: string): Boolean;
var
  I: Integer;
  T: TShellTab;
  Block: Boolean;
begin
  ABlocker := '';
  for I := 0 to FTabs.Count - 1 do
  begin
    T := TShellTab(FTabs[I]);
    if SameText(T.Key, AKey) then Continue;
    Block := (AGroup <> '') and SameText(T.Group, AGroup);
    { objedinjene forme: vrste koje se medjusobno iskljucuju (tablica dokumenti, stupac srodne) }
    if (not Block) and (ADocCode <> '') and (T.DocCode <> '') then Block := DocTypesBlock(FDb, ADocCode, T.DocCode);
    if Block then
    begin
      ABlocker := T.Caption;
      Exit(False);
    end;
  end;
  Result := True;
end;

procedure TaShell.ActivateTab(AIndex: Integer);
begin
  if (AIndex < 0) or (AIndex >= FTabs.Count) then Exit;
  FBar.ActiveIndex := AIndex;
  FPages.ActivePage := TShellTab(FTabs[AIndex]).Sheet;
  { izbornik prati aktivnu karticu }
  FMenu.SelectAction('openform:' + TShellTab(FTabs[AIndex]).Arg);
  ShowCurrent;
end;

function TaShell.OpenForm(const AName: string): Boolean;
var
  Js, Blocker, FormName, Args, Key, Code, Cap, Msg: string;
  Def: TaFormDef;
  T: TShellTab;
  I: Integer;
  L: TStringList;
  DT: TaDocType;
begin
  Result := False;
  { "Dokument#vrsta=otp": ista forma otvorena s parametrom }
  SplitFormAction(AName, FormName, Args);
  Js := FDb.LoadObject('_sys_forms', FormName);
  if Js = '' then begin Notify(Tr('There is no form: ') + FormName); Exit; end;
  if not CanRun(FDb, '_sys_forms', FormName) then begin Notify(Tr('You do not have the right to open the form ') + FormName); Exit; end;
  Def := TaFormDef.Create;
  Def.FromJson(Js);
  Def.Name := FormName;
  Code := '';
  if (Def.DocTypeField <> '') and (Args <> '') then
  begin
    L := TStringList.Create;
    try
      ParseOpenArgs(Args, L);
      Code := L.Values['vrsta'];
    finally
      L.Free;
    end;
  end;
  if Def.DocTypeField <> '' then
  begin
    if Code = '' then
    begin
      Notify(Tr('Form "') + FormName + Tr('" works with document types: open it from the menu with a parameter (e.g. ') + FormName + Tr('#vrsta=otp).'));
      Def.Free;
      Exit;
    end;
    if not DocTypeLoad(FDb, Code, DT) then
    begin
      Notify(Tr('Document type "') + Code + Tr('" is not entered in the documents table.'));
      Def.Free;
      Exit;
    end;
  end;
  Key := LowerCase(FormName);
  if Code <> '' then Key := Key + '#' + LowerCase(Code);
  I := FindTab(Key);
  if I >= 0 then
  begin
    ActivateTab(I);
    Def.Free;
    Exit(True);
  end;
  Cap := Def.Caption;
  if Cap = '' then Cap := FormName;
  if Code <> '' then Cap := DT.Name;
  if not CanOpen(Key, Def.ExclusiveGroup, Code, Blocker) then
  begin
    Msg := '"' + Blocker + Tr('" is already open. Close it before opening "') + Cap + '": ';
    if Def.ExclusiveGroup <> '' then Msg := Msg + Tr('from the group "') + Def.ExclusiveGroup + Tr('" only one can be open at a time.')
    else Msg := Msg + Tr('these two document types must not be open at the same time (related types).');
    Notify(Msg);
    for I := 0 to FTabs.Count - 1 do
      if SameText(TShellTab(FTabs[I]).Caption, Blocker) then begin ActivateTab(I); Break; end;
    Def.Free;
    Exit;
  end;
  T := TShellTab.Create;
  T.Name := FormName;
  T.Key := Key;
  T.Arg := AName;
  T.DocCode := Code;
  T.Group := Def.ExclusiveGroup;
  T.Caption := Cap;
  T.Sheet := TTabSheet.Create(FPages);
  T.Sheet.PageControl := FPages;
  T.Scroll := TScrollBox.Create(T.Sheet);
  T.Scroll.Parent := T.Sheet;
  T.Scroll.Align := alClient;
  T.Scroll.BorderStyle := bsNone;
  T.Scroll.HorzScrollBar.Tracking := True;
  T.Scroll.VertScrollBar.Tracking := True;
  T.Sheet.OnResize := @SheetResize;
  T.Runner := TaFormRunner.CreateRunner(Self, FDb, Def);
  T.Runner.Embed(T.Scroll, @RunnerClosed);
  T.Runner.FitTo(T.Sheet.ClientWidth, T.Sheet.ClientHeight);
  FTabs.Add(T);
  FBar.AddTab(Cap, ObjectIconName('form', FormName));
  ActivateTab(FTabs.Count - 1);
  if Code <> '' then T.Runner.OpenWith(Args);
  Result := True;
end;

procedure TaShell.MenuAction(const AAction: string);
var
  P: Integer;
begin
  P := Pos(':', AAction);
  if (P > 0) and (LowerCase(Trim(Copy(AAction, 1, P - 1))) = 'openform') then OpenForm(Trim(Copy(AAction, P + 1, MaxInt)))
  else if Assigned(FOnAction) then FOnAction(AAction);
end;

procedure TaShell.BarSelect(Sender: TObject);
begin
  ActivateTab(FBar.ActiveIndex);
end;

procedure TaShell.BarClose(Sender: TObject);
var
  I: Integer;
begin
  I := FBar.CloseIndex;
  if (I < 0) or (I >= FTabs.Count) then Exit;
  { Close pokrece provjeru (nespremljen zapis...); ako je sve u redu, forma javlja RunnerClosed }
  TShellTab(FTabs[I]).Runner.Close;
end;

procedure TaShell.RunnerClosed(Sender: TObject);
var
  I: Integer;
begin
  I := TabOfRunner(Sender);
  if I < 0 then Exit;
  Application.QueueAsyncCall(@DoRemove, PtrInt(FTabs[I]));
end;

procedure TaShell.DoRemove(Data: PtrInt);
var
  T: TShellTab;
  I, NewIdx: Integer;
begin
  T := TShellTab(Data);
  I := FTabs.IndexOf(T);
  if I < 0 then Exit;
  FBar.DeleteTab(I);
  FTabs.Extract(T);
  T.Runner.Free;
  T.Sheet.OnResize := nil;
  T.Sheet.Free;
  T.Free;
  if FTabs.Count > 0 then
  begin
    NewIdx := I;
    if NewIdx >= FTabs.Count then NewIdx := FTabs.Count - 1;
    ActivateTab(NewIdx);
  end;
  ShowCurrent;
end;

procedure TaShell.CloseActive;
begin
  if (FBar.ActiveIndex >= 0) and (FBar.ActiveIndex < FTabs.Count) then
    TShellTab(FTabs[FBar.ActiveIndex]).Runner.Close;
end;

function TaShell.CloseAll: Boolean;
var
  I: Integer;
begin
  Result := True;
  for I := FTabs.Count - 1 downto 0 do
  begin
    ActivateTab(I);
    if not TShellTab(FTabs[I]).Runner.CloseQuery then Exit(False);
  end;
  Application.ProcessMessages;
  { sve su prihvatile: ukloni ih bez ponovnog pitanja }
  while FTabs.Count > 0 do DoRemove(PtrInt(FTabs[FTabs.Count - 1]));
end;

procedure TaShell.LogoutClick(Sender: TObject);
begin
  if Assigned(FOnLogout) then FOnLogout(Self);
end;

end.
