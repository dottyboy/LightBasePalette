unit ta_appdlg;
{ Dialogs for the application layer: settings and packaging, login, user
  management, object rights and the switchboard wizard. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, ExtCtrls, StdCtrls, Graphics,
  CheckLst, ta_meta, ta_formdef, ta_app, ta_switchgen, ta_audit, ta_doctypes;

procedure RunAppSettings(AOwner: TComponent; ADb: TAppDb);
{ True when someone logged in (or no users exist). Sets the session. }
function RunLogin(AOwner: TComponent; ADb: TAppDb): Boolean;
procedure RunUsers(AOwner: TComponent; ADb: TAppDb);
procedure RunRights(AOwner: TComponent; ADb: TAppDb);
{ Returns the name of the switchboard form that was saved, or ''. }
function RunSwitchboard(AOwner: TComponent; ADb: TAppDb): string;
{ vrste dokumenata objedinjenih formi: oznaka, naziv, prefiks, oblik broja, zadnji broj i srodne vrste }
procedure RunDocTypes(AOwner: TComponent; ADb: TAppDb);

implementation

uses
  ta_i18n;


{ ---------------- settings ---------------- }

type
  TSettingsDlg = class
  public
    Db: TAppDb;
    Form: TForm;
    TitleEdit: TEdit;
    StartBox: TComboBox;
    RuntimeCk: TCheckBox;
    procedure SaveClick(Sender: TObject);
    procedure ExportClick(Sender: TObject);
    function Collect: TaAppSettings;
  end;

function TSettingsDlg.Collect: TaAppSettings;
begin
  Result.Title := Trim(TitleEdit.Text);
  Result.StartupForm := Trim(StartBox.Text);
  Result.RuntimeOnly := RuntimeCk.Checked;
end;

procedure TSettingsDlg.SaveClick(Sender: TObject);
begin
  SaveAppSettings(Db, Collect);
  Form.ModalResult := mrOk;
end;

procedure TSettingsDlg.ExportClick(Sender: TObject);
var
  Dlg: TSelectDirectoryDialog;
  S: TaAppSettings;
  Dir: string;
begin
  Dlg := TSelectDirectoryDialog.Create(nil);
  try
    Dlg.Title := Tr('Folder for the finished application');
    if not Dlg.Execute then Exit;
    S := Collect;
    S.RuntimeOnly := True;
    SaveAppSettings(Db, S);
    try
      Dir := ExportApplication(Db, Dlg.FileName, ParamStr(0), S.Title);
    except
      on E: Exception do begin ShowMessage(Tr('Export failed: ') + E.Message); Exit; end;
    end;
    ShowMessage(Tr('The application was saved in:') + LineEnding + Dir + LineEnding +
      Tr('It is started by an .sh script (or a .desktop file). On another computer you need ') +
      'iste sistemske biblioteke (Qt6, SQLite).');
  finally
    Dlg.Free;
  end;
end;

procedure RunAppSettings(AOwner: TComponent; ADb: TAppDb);
var
  D: TSettingsDlg;
  S: TaAppSettings;
  L: TStringList;
  I: Integer;
begin
  D := TSettingsDlg.Create;
  D.Db := ADb;
  D.Form := TForm.CreateNew(AOwner);
  try
    D.Form.Caption := Tr('Application settings');
    D.Form.SetBounds(0, 0, 520, 300);
    D.Form.Position := poOwnerFormCenter;
    S := LoadAppSettings(ADb);
    with TLabel.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Title:'); SetBounds(14, 20, 110, 18); end;
    D.TitleEdit := TEdit.Create(D.Form); D.TitleEdit.Parent := D.Form; D.TitleEdit.SetBounds(130, 16, 370, 26);
    D.TitleEdit.Text := S.Title;
    with TLabel.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Start form:'); SetBounds(14, 60, 110, 18); end;
    D.StartBox := TComboBox.Create(D.Form); D.StartBox.Parent := D.Form; D.StartBox.SetBounds(130, 56, 370, 26);
    D.StartBox.Style := csDropDownList;
    D.StartBox.Items.Add('');
    L := ADb.ListObjects('_sys_forms');
    try
      for I := 0 to L.Count - 1 do D.StartBox.Items.Add(L[I]);
    finally
      L.Free;
    end;
    D.StartBox.ItemIndex := D.StartBox.Items.IndexOf(S.StartupForm);
    if D.StartBox.ItemIndex < 0 then D.StartBox.ItemIndex := 0;
    D.RuntimeCk := TCheckBox.Create(D.Form);
    D.RuntimeCk.Parent := D.Form;
    D.RuntimeCk.Caption := Tr('Run in runtime mode (without design tools)');
    D.RuntimeCk.SetBounds(130, 100, 370, 22);
    D.RuntimeCk.Checked := S.RuntimeOnly;
    with TLabel.Create(D.Form) do
    begin
      Parent := D.Form;
      Caption := Tr('Runtime mode hides the menu and the designers; only an administrator can bring them back ') +
        '(Ctrl+Shift+D). Makro AutoExec izvodi se pri otvaranju baze.';
      WordWrap := True;
      SetBounds(130, 130, 370, 54);
    end;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Export application...'); SetBounds(14, 230, 170, 30); OnClick := @D.ExportClick; end;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Save'); SetBounds(320, 230, 90, 30); OnClick := @D.SaveClick; end;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Close'); ModalResult := mrCancel; SetBounds(416, 230, 90, 30); end;
    D.Form.ShowModal;
  finally
    D.Form.Free;
    D.Free;
  end;
end;

{ ---------------- login ---------------- }

type
  TLoginDlg = class
  public
    Db: TAppDb;
    Form: TForm;
    NameEdit, PassEdit: TEdit;
    Msg: TLabel;
    Role: TaRole;
    Ok: Boolean;
    procedure OkClick(Sender: TObject);
  end;

procedure TLoginDlg.OkClick(Sender: TObject);
begin
  if Authenticate(Db, NameEdit.Text, PassEdit.Text, Role) then
  begin
    Ok := True;
    StartSession(Trim(NameEdit.Text), Role);
    AuditSetUser(Db, Trim(NameEdit.Text));
    Form.ModalResult := mrOk;
  end
  else
  begin
    Msg.Caption := Tr('Wrong user name or password.');
    PassEdit.Text := '';
    PassEdit.SetFocus;
  end;
end;

function RunLogin(AOwner: TComponent; ADb: TAppDb): Boolean;
var
  D: TLoginDlg;
begin
  if UserCount(ADb) = 0 then
  begin
    StartSession('', arAdmin);
    AuditSetUser(ADb, '');
    Exit(True);
  end;
  D := TLoginDlg.Create;
  D.Db := ADb;
  D.Form := TForm.CreateNew(AOwner);
  try
    D.Form.Caption := Tr('Login');
    D.Form.SetBounds(0, 0, 340, 210);
    D.Form.Position := poScreenCenter;
    with TLabel.Create(D.Form) do begin Parent := D.Form; Caption := Tr('User:'); SetBounds(16, 24, 80, 18); end;
    D.NameEdit := TEdit.Create(D.Form); D.NameEdit.Parent := D.Form; D.NameEdit.SetBounds(100, 20, 220, 26);
    with TLabel.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Password:'); SetBounds(16, 64, 80, 18); end;
    D.PassEdit := TEdit.Create(D.Form); D.PassEdit.Parent := D.Form; D.PassEdit.SetBounds(100, 60, 220, 26);
    D.PassEdit.PasswordChar := '*';
    D.Msg := TLabel.Create(D.Form); D.Msg.Parent := D.Form; D.Msg.SetBounds(16, 100, 300, 18);
    D.Msg.Font.Color := clMaroon;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Login'); Default := True; SetBounds(130, 140, 90, 30); OnClick := @D.OkClick; end;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Cancel'); ModalResult := mrCancel; SetBounds(230, 140, 90, 30); end;
    D.Form.ShowModal;
    Result := D.Ok;
  finally
    D.Form.Free;
    D.Free;
  end;
end;

{ ---------------- users ---------------- }

function AskUser(AOwner: TComponent; const ATitle: string; var AName, APass: string;
  var ARole: TaRole; ANameEditable, APassNeeded, ARoleNeeded: Boolean): Boolean;
var
  F: TForm;
  NameEdit, PassEdit: TEdit;
  RoleBox: TComboBox;
  R: TaRole;
begin
  Result := False;
  F := TForm.CreateNew(AOwner);
  try
    F.Caption := ATitle;
    F.SetBounds(0, 0, 380, 220);
    F.Position := poOwnerFormCenter;
    with TLabel.Create(F) do begin Parent := F; Caption := Tr('User:'); SetBounds(14, 22, 90, 18); end;
    NameEdit := TEdit.Create(F); NameEdit.Parent := F; NameEdit.SetBounds(110, 18, 250, 26);
    NameEdit.Text := AName; NameEdit.Enabled := ANameEditable;
    with TLabel.Create(F) do begin Parent := F; Caption := Tr('Password:'); SetBounds(14, 62, 90, 18); end;
    PassEdit := TEdit.Create(F); PassEdit.Parent := F; PassEdit.SetBounds(110, 58, 250, 26);
    PassEdit.PasswordChar := '*'; PassEdit.Enabled := APassNeeded;
    with TLabel.Create(F) do begin Parent := F; Caption := Tr('Role:'); SetBounds(14, 102, 90, 18); end;
    RoleBox := TComboBox.Create(F); RoleBox.Parent := F; RoleBox.SetBounds(110, 98, 250, 26);
    RoleBox.Style := csDropDownList; RoleBox.Enabled := ARoleNeeded;
    for R := Low(R) to High(R) do RoleBox.Items.Add(RoleNames[R]);
    RoleBox.ItemIndex := Ord(ARole);
    with TButton.Create(F) do begin Parent := F; Caption := Tr('OK'); ModalResult := mrOk; SetBounds(180, 150, 90, 30); end;
    with TButton.Create(F) do begin Parent := F; Caption := Tr('Cancel'); ModalResult := mrCancel; SetBounds(276, 150, 84, 30); end;
    if F.ShowModal <> mrOk then Exit;
    AName := Trim(NameEdit.Text);
    APass := PassEdit.Text;
    ARole := TaRole(RoleBox.ItemIndex);
    Result := AName <> '';
  finally
    F.Free;
  end;
end;

type
  TUsersDlg = class
  public
    Db: TAppDb;
    Form: TForm;
    List: TListBox;
    Names: TStringList;
    procedure Reload;
    procedure AddClick(Sender: TObject);
    procedure PassClick(Sender: TObject);
    procedure RoleClick(Sender: TObject);
    procedure DelClick(Sender: TObject);
    function Selected: string;
  end;

procedure TUsersDlg.Reload;
var
  L: TStringList;
  I, P: Integer;
begin
  Names.Clear;
  List.Items.Clear;
  L := ListUsers(Db);
  try
    for I := 0 to L.Count - 1 do
    begin
      P := Pos('|', L[I]);
      Names.Add(Copy(L[I], 1, P - 1));
      List.Items.Add(Copy(L[I], 1, P - 1) + '   [' + Copy(L[I], P + 1, MaxInt) + ']');
    end;
  finally
    L.Free;
  end;
end;

function TUsersDlg.Selected: string;
begin
  Result := '';
  if List.ItemIndex >= 0 then Result := Names[List.ItemIndex];
end;

procedure TUsersDlg.AddClick(Sender: TObject);
var
  N, P: string;
  R: TaRole;
begin
  N := ''; P := ''; R := arUser;
  if Names.Count = 0 then
    ShowMessage(Tr('The first user becomes the administrator; after that a login is required.'));
  if Names.Count = 0 then R := arAdmin;
  if not AskUser(Form, Tr('New user'), N, P, R, True, True, Names.Count > 0) then Exit;
  if P = '' then begin ShowMessage(Tr('A password is required.')); Exit; end;
  if Names.Count = 0 then R := arAdmin;
  if not AddUser(Db, N, P, R) then ShowMessage(Tr('The user already exists.'));
  Reload;
end;

procedure TUsersDlg.PassClick(Sender: TObject);
var
  N, P: string;
  R: TaRole;
begin
  N := Selected;
  if N = '' then Exit;
  P := ''; R := arUser;
  if AskUser(Form, Tr('New password'), N, P, R, False, True, False) and (P <> '') then
    SetPassword(Db, N, P);
end;

procedure TUsersDlg.RoleClick(Sender: TObject);
var
  N, P: string;
  R: TaRole;
  L: TStringList;
  I: Integer;
begin
  N := Selected;
  if N = '' then Exit;
  P := '';
  R := arUser;
  L := ListUsers(Db);
  try
    for I := 0 to L.Count - 1 do
      if Copy(L[I], 1, Length(N) + 1) = N + '|' then R := RoleFromName(Copy(L[I], Length(N) + 2, MaxInt));
  finally
    L.Free;
  end;
  if AskUser(Form, 'Uloga korisnika', N, P, R, False, False, True) then
  begin
    if (R <> arAdmin) and (N = SessionUser) and (SessionRole = arAdmin) and (Names.Count > 0) then
      if MessageDlg(Tr('You are removing your own administrator role. Continue?'), mtWarning, [mbYes, mbNo], 0) <> mrYes then Exit;
    SetUserRole(Db, N, R);
    Reload;
  end;
end;

procedure TUsersDlg.DelClick(Sender: TObject);
var
  N: string;
begin
  N := Selected;
  if N = '' then Exit;
  if MessageDlg(Tr('Delete user ') + N + '?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  if not DeleteUser(Db, N) then ShowMessage(Tr('The last administrator cannot be deleted.'));
  Reload;
end;

procedure RunUsers(AOwner: TComponent; ADb: TAppDb);
var
  D: TUsersDlg;
begin
  D := TUsersDlg.Create;
  D.Db := ADb;
  D.Names := TStringList.Create;
  D.Form := TForm.CreateNew(AOwner);
  try
    D.Form.Caption := Tr('Users');
    D.Form.SetBounds(0, 0, 520, 380);
    D.Form.Position := poOwnerFormCenter;
    D.List := TListBox.Create(D.Form);
    D.List.Parent := D.Form;
    D.List.SetBounds(12, 12, 330, 320);
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Add...'); SetBounds(356, 12, 140, 30); OnClick := @D.AddClick; end;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Password...'); SetBounds(356, 50, 140, 30); OnClick := @D.PassClick; end;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Role...'); SetBounds(356, 88, 140, 30); OnClick := @D.RoleClick; end;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Delete'); SetBounds(356, 126, 140, 30); OnClick := @D.DelClick; end;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Close'); ModalResult := mrCancel; SetBounds(356, 302, 140, 30); end;
    with TLabel.Create(D.Form) do
    begin
      Parent := D.Form;
      Caption := Tr('viewer: reads data only') + LineEnding + Tr('user: edits data, runs forms and reports') +
        LineEnding + Tr('admin: everything, including design');
      SetBounds(356, 170, 150, 100);
      WordWrap := True;
    end;
    D.Reload;
    D.Form.ShowModal;
  finally
    D.Form.Free;
    D.Names.Free;
    D.Free;
  end;
end;

{ ---------------- object rights ---------------- }

type
  TRightsDlg = class
  public
    Db: TAppDb;
    Form: TForm;
    List: TListBox;
    RoleBox: TComboBox;
    Kinds, Names: TStringList;
    procedure Reload;
    procedure SetClick(Sender: TObject);
  end;

procedure TRightsDlg.Reload;
var
  Sel, I, K: Integer;
  L: TStringList;
  Table: string;
  Lbl: string;
begin
  Sel := List.ItemIndex;
  List.Items.Clear;
  Kinds.Clear;
  Names.Clear;
  for K := 0 to 2 do
  begin
    case K of
      0: begin Table := '_sys_forms'; Lbl := Tr('Form'); end;
      1: begin Table := '_sys_reports'; Lbl := Tr('Report'); end;
    else begin Table := '_sys_macros'; Lbl := Tr('Macro'); end;
    end;
    L := Db.ListObjects(Table);
    try
      for I := 0 to L.Count - 1 do
      begin
        Kinds.Add(Table);
        Names.Add(L[I]);
        List.Items.Add(Format('%s: %s   (od uloge: %s)', [Lbl, L[I], RoleNames[GetObjectRight(Db, Table, L[I])]]));
      end;
    finally
      L.Free;
    end;
  end;
  if Sel < List.Count then List.ItemIndex := Sel;
end;

procedure TRightsDlg.SetClick(Sender: TObject);
begin
  if List.ItemIndex < 0 then Exit;
  SetObjectRight(Db, Kinds[List.ItemIndex], Names[List.ItemIndex], TaRole(RoleBox.ItemIndex));
  Reload;
end;

procedure RunRights(AOwner: TComponent; ADb: TAppDb);
var
  D: TRightsDlg;
  R: TaRole;
begin
  D := TRightsDlg.Create;
  D.Db := ADb;
  D.Kinds := TStringList.Create;
  D.Names := TStringList.Create;
  D.Form := TForm.CreateNew(AOwner);
  try
    D.Form.Caption := Tr('Object rights');
    D.Form.SetBounds(0, 0, 560, 440);
    D.Form.Position := poOwnerFormCenter;
    D.List := TListBox.Create(D.Form);
    D.List.Parent := D.Form;
    D.List.SetBounds(12, 12, 536, 330);
    with TLabel.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Lowest role allowed to open:'); SetBounds(12, 358, 220, 18); end;
    D.RoleBox := TComboBox.Create(D.Form);
    D.RoleBox.Parent := D.Form;
    D.RoleBox.SetBounds(240, 354, 130, 26);
    D.RoleBox.Style := csDropDownList;
    for R := Low(R) to High(R) do D.RoleBox.Items.Add(RoleNames[R]);
    D.RoleBox.ItemIndex := 0;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Set'); SetBounds(380, 352, 80, 30); OnClick := @D.SetClick; end;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Close'); ModalResult := mrCancel; SetBounds(468, 352, 80, 30); end;
    D.Reload;
    D.Form.ShowModal;
  finally
    D.Form.Free;
    D.Kinds.Free;
    D.Names.Free;
    D.Free;
  end;
end;

{ ---------------- switchboard wizard ---------------- }

type
  TSwitchDlg = class
  public
    Db: TAppDb;
    Form: TForm;
    TitleEdit, NameEdit: TEdit;
    List: TListBox;
    StartCk, SideCk, MainCk: TCheckBox;
    Items: TStringList;
    procedure AddClick(Sender: TObject);
    procedure GroupClick(Sender: TObject);
    procedure DelClick(Sender: TObject);
    procedure UpClick(Sender: TObject);
    procedure DownClick(Sender: TObject);
    procedure ShowItems;
  end;

procedure TSwitchDlg.ShowItems;
var
  I, P: Integer;
begin
  List.Items.Clear;
  for I := 0 to Items.Count - 1 do
  begin
    P := Pos('|', Items[I]);
    if (Items[I] <> '') and (Items[I][1] = '#') then List.Items.Add('▸ ' + Trim(Copy(Items[I], 2, MaxInt)))
    else List.Items.Add(Copy(Items[I], 1, P - 1) + '   →   ' + Copy(Items[I], P + 1, MaxInt));
  end;
end;

type
  TItemDlg = class
  public
    Db: TAppDb;
    TypeBox, ObjBox: TComboBox;
    procedure TypeChange(Sender: TObject);
  end;

procedure TItemDlg.TypeChange(Sender: TObject);
var
  L: TStringList;
  Table: string;
begin
  ObjBox.Items.Clear;
  case TypeBox.ItemIndex of
    0: Table := '_sys_forms';
    1: Table := '_sys_reports';
    2: Table := '_sys_macros';
    3: Table := '_sys_modules';
  else Table := '';
  end;
  ObjBox.Enabled := Table <> '';
  if Table = '' then Exit;
  L := Db.ListObjects(Table);
  try
    ObjBox.Items.Assign(L);
  finally
    L.Free;
  end;
  if ObjBox.Items.Count > 0 then ObjBox.ItemIndex := 0;
end;

procedure TSwitchDlg.AddClick(Sender: TObject);
var
  F: TForm;
  Cap: TEdit;
  ID: TItemDlg;
  Act, Obj: string;
begin
  ID := TItemDlg.Create;
  ID.Db := Db;
  F := TForm.CreateNew(Form);
  try
    F.Caption := Tr('Menu item');
    F.SetBounds(0, 0, 420, 230);
    F.Position := poOwnerFormCenter;
    with TLabel.Create(F) do begin Parent := F; Caption := Tr('Caption:'); SetBounds(14, 22, 80, 18); end;
    Cap := TEdit.Create(F); Cap.Parent := F; Cap.SetBounds(100, 18, 300, 26);
    with TLabel.Create(F) do begin Parent := F; Caption := Tr('Action:'); SetBounds(14, 62, 80, 18); end;
    ID.TypeBox := TComboBox.Create(F); ID.TypeBox.Parent := F; ID.TypeBox.SetBounds(100, 58, 300, 26);
    ID.TypeBox.Style := csDropDownList;
    ID.TypeBox.Items.CommaText := TrCsv('"Otvori formu","Otvori izvješće","Pokreni makro","Pokreni proceduru","Zatvori"');
    ID.TypeBox.ItemIndex := 0;
    with TLabel.Create(F) do begin Parent := F; Caption := Tr('Object:'); SetBounds(14, 102, 80, 18); end;
    ID.ObjBox := TComboBox.Create(F); ID.ObjBox.Parent := F; ID.ObjBox.SetBounds(100, 98, 300, 26);
    ID.ObjBox.Style := csDropDownList;
    ID.TypeBox.OnChange := @ID.TypeChange;
    ID.TypeChange(nil);
    with TButton.Create(F) do begin Parent := F; Caption := Tr('OK'); ModalResult := mrOk; SetBounds(220, 160, 90, 30); end;
    with TButton.Create(F) do begin Parent := F; Caption := Tr('Cancel'); ModalResult := mrCancel; SetBounds(316, 160, 84, 30); end;
    if F.ShowModal <> mrOk then Exit;
    Obj := ID.ObjBox.Text;
    case ID.TypeBox.ItemIndex of
      0: Act := 'openform:' + Obj;
      1: Act := 'openreport:' + Obj;
      2: Act := 'macro:' + Obj;
      3: Act := 'run:' + Obj;
    else Act := 'close';
    end;
    if (Trim(Cap.Text) = '') or ((ID.TypeBox.ItemIndex < 4) and (Obj = '')) then
    begin
      ShowMessage(Tr('Enter a caption and choose an object.'));
      Exit;
    end;
    Items.Add(Trim(Cap.Text) + '|' + Act);
    ShowItems;
  finally
    F.Free;
    ID.Free;
  end;
end;

procedure TSwitchDlg.GroupClick(Sender: TObject);
var
  T: string;
begin
  T := '';
  if not InputQuery(Tr('Group'), Tr('Group title (the following items go into it):'), T) then Exit;
  T := Trim(T);
  if T = '' then Exit;
  Items.Add('# ' + T);
  ShowItems;
end;

procedure TSwitchDlg.DelClick(Sender: TObject);
begin
  if List.ItemIndex < 0 then Exit;
  Items.Delete(List.ItemIndex);
  ShowItems;
end;

procedure TSwitchDlg.UpClick(Sender: TObject);
var
  I: Integer;
begin
  I := List.ItemIndex;
  if I < 1 then Exit;
  Items.Exchange(I, I - 1);
  ShowItems;
  List.ItemIndex := I - 1;
end;

procedure TSwitchDlg.DownClick(Sender: TObject);
var
  I: Integer;
begin
  I := List.ItemIndex;
  if (I < 0) or (I >= Items.Count - 1) then Exit;
  Items.Exchange(I, I + 1);
  ShowItems;
  List.ItemIndex := I + 1;
end;

function RunSwitchboard(AOwner: TComponent; ADb: TAppDb): string;
var
  D: TSwitchDlg;
  F: TaFormDef;
  Name: string;
  S: TaAppSettings;
begin
  Result := '';
  D := TSwitchDlg.Create;
  D.Db := ADb;
  D.Items := TStringList.Create;
  D.Form := TForm.CreateNew(AOwner);
  try
    D.Form.Caption := Tr('Menu wizard');
    D.Form.SetBounds(0, 0, 640, 560);
    D.Form.Position := poOwnerFormCenter;
    with TLabel.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Title:'); SetBounds(14, 20, 90, 18); end;
    D.TitleEdit := TEdit.Create(D.Form); D.TitleEdit.Parent := D.Form; D.TitleEdit.SetBounds(110, 16, 300, 26);
    D.TitleEdit.Text := 'Glavni izbornik';
    with TLabel.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Form name:'); SetBounds(14, 60, 90, 18); end;
    D.NameEdit := TEdit.Create(D.Form); D.NameEdit.Parent := D.Form; D.NameEdit.SetBounds(110, 56, 300, 26);
    D.NameEdit.Text := 'Switchboard';
    D.List := TListBox.Create(D.Form);
    D.List.Parent := D.Form;
    D.List.SetBounds(14, 100, 470, 320);
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Add...'); SetBounds(500, 100, 120, 30); OnClick := @D.AddClick; end;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Group...'); SetBounds(500, 252, 120, 30); OnClick := @D.GroupClick; end;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Delete'); SetBounds(500, 138, 120, 30); OnClick := @D.DelClick; end;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Up'); SetBounds(500, 176, 120, 30); OnClick := @D.UpClick; end;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Down'); SetBounds(500, 214, 120, 30); OnClick := @D.DownClick; end;
    D.StartCk := TCheckBox.Create(D.Form);
    D.StartCk.Parent := D.Form;
    D.StartCk.Caption := Tr('Set as the application''s start form');
    D.StartCk.SetBounds(14, 432, 400, 22);
    D.StartCk.Checked := True;
    D.SideCk := TCheckBox.Create(D.Form);
    D.SideCk.Parent := D.Form;
    D.SideCk.Caption := Tr('Side menu instead of buttons (groups collapse, one is open)');
    D.SideCk.SetBounds(14, 454, 480, 22);
    D.MainCk := TCheckBox.Create(D.Form);
    D.MainCk.Parent := D.Form;
    D.MainCk.Caption := Tr('Main form template (header, side menu, work area and status bar)');
    D.MainCk.SetBounds(14, 476, 600, 22);
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Create'); ModalResult := mrOk; SetBounds(430, 508, 90, 30); end;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Cancel'); ModalResult := mrCancel; SetBounds(528, 508, 92, 30); end;
    repeat
      if D.Form.ShowModal <> mrOk then Exit;
      Name := Trim(D.NameEdit.Text);
      if (Name = '') or (D.Items.Count = 0) then
      begin
        ShowMessage(Tr('Enter a form name and add at least one item.'));
        Continue;
      end;
      if ADb.LoadObject('_sys_forms', Name) <> '' then
        if MessageDlg(Tr('The form already exists. Overwrite?'), mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Continue;
      if D.MainCk.Checked then F := BuildMainForm(Name, Trim(D.TitleEdit.Text), D.Items)
      else if D.SideCk.Checked then F := BuildSideBoard(Name, Trim(D.TitleEdit.Text), D.Items)
      else F := BuildSwitchboard(Name, Trim(D.TitleEdit.Text), D.Items);
      try
        ADb.SaveObject('_sys_forms', Name, F.ToJson);
      finally
        F.Free;
      end;
      if D.StartCk.Checked then
      begin
        S := LoadAppSettings(ADb);
        S.StartupForm := Name;
        SaveAppSettings(ADb, S);
      end;
      Result := Name;
      Break;
    until False;
  finally
    D.Form.Free;
    D.Items.Free;
    D.Free;
  end;
end;


{ ---------------- vrste dokumenata ---------------- }

type
  TDocTypesDlg = class
  public
    Db: TAppDb;
    Form: TForm;
    List: TListBox;
    CodeEdit, NameEdit, PrefixEdit, FormatEdit, LastEdit, YearEdit: TEdit;
    Related: TCheckListBox;
    Sample: TLabel;
    Current: string;
    procedure Fill;
    procedure Pick(Sender: TObject);
    procedure ShowType(const ACode: string);
    procedure NewClick(Sender: TObject);
    procedure SaveClick(Sender: TObject);
    procedure DeleteClick(Sender: TObject);
    procedure FormatChange(Sender: TObject);
  end;

procedure TDocTypesDlg.Fill;
var
  L: TStringList;
  I: Integer;
  T: TaDocType;
begin
  List.Items.Clear;
  L := DocTypeCodes(Db);
  try
    for I := 0 to L.Count - 1 do
      if DocTypeLoad(Db, L[I], T) then List.Items.Add(L[I] + '   ' + T.Name);
  finally
    L.Free;
  end;
  Related.Items.Clear;
  L := DocTypeCodes(Db);
  try
    Related.Items.Assign(L);
  finally
    L.Free;
  end;
end;

procedure TDocTypesDlg.ShowType(const ACode: string);
var
  T: TaDocType;
  Rel: TStringList;
  I: Integer;
begin
  Current := ACode;
  if not DocTypeLoad(Db, ACode, T) then
  begin
    CodeEdit.Text := ''; NameEdit.Text := ''; PrefixEdit.Text := ''; FormatEdit.Text := DefaultDocFormat;
    LastEdit.Text := '0'; YearEdit.Text := '0';
    for I := 0 to Related.Count - 1 do Related.Checked[I] := False;
    CodeEdit.ReadOnly := False;
    FormatChange(nil);
    Exit;
  end;
  CodeEdit.Text := T.Code; CodeEdit.ReadOnly := True;
  NameEdit.Text := T.Name; PrefixEdit.Text := T.Prefix; FormatEdit.Text := T.Format;
  LastEdit.Text := IntToStr(T.Last); YearEdit.Text := IntToStr(T.Year);
  Rel := TStringList.Create;
  try
    Rel.CommaText := StringReplace(T.Related, ';', ',', [rfReplaceAll]);
    for I := 0 to Related.Count - 1 do
      Related.Checked[I] := (Rel.IndexOf(Related.Items[I]) >= 0);
  finally
    Rel.Free;
  end;
  FormatChange(nil);
end;

procedure TDocTypesDlg.Pick(Sender: TObject);
var
  S: string;
begin
  if List.ItemIndex < 0 then Exit;
  S := List.Items[List.ItemIndex];
  ShowType(Trim(Copy(S, 1, Pos(' ', S + ' ') - 1)));
end;

procedure TDocTypesDlg.NewClick(Sender: TObject);
begin
  List.ItemIndex := -1;
  ShowType('');
  CodeEdit.SetFocus;
end;

procedure TDocTypesDlg.FormatChange(Sender: TObject);
begin
  Sample.Caption := Tr('Next number: ') + DocFormatNumber(FormatEdit.Text, PrefixEdit.Text,
    StrToIntDef(YearEdit.Text, 0), StrToIntDef(LastEdit.Text, 0) + 1);
end;

procedure TDocTypesDlg.SaveClick(Sender: TObject);
var
  T: TaDocType;
  I: Integer;
  Rel: string;
begin
  T.Code := Trim(CodeEdit.Text);
  if T.Code = '' then begin ShowMessage(Tr('Enter a type code (e.g. dn).')); Exit; end;
  T.Name := Trim(NameEdit.Text);
  if T.Name = '' then T.Name := T.Code;
  T.Prefix := Trim(PrefixEdit.Text);
  if T.Prefix = '' then T.Prefix := T.Code;
  T.Format := Trim(FormatEdit.Text);
  if T.Format = '' then T.Format := DefaultDocFormat;
  T.Last := StrToIntDef(LastEdit.Text, 0);
  T.Year := StrToIntDef(YearEdit.Text, 0);
  Rel := '';
  for I := 0 to Related.Count - 1 do
    if Related.Checked[I] and not SameText(Related.Items[I], T.Code) then Rel := Rel + Related.Items[I] + ',';
  if Rel <> '' then SetLength(Rel, Length(Rel) - 1);
  T.Related := Rel;
  try
    DocTypeSave(Db, T);
  except
    on E: Exception do begin ShowMessage(Tr('Saving failed: ') + E.Message); Exit; end;
  end;
  Fill;
  ShowType(T.Code);
  List.ItemIndex := List.Items.IndexOf(T.Code + '   ' + T.Name);
end;

procedure TDocTypesDlg.DeleteClick(Sender: TObject);
begin
  if Current = '' then Exit;
  if MessageDlg(Tr('Delete type "') + Current + Tr('"? Documents already entered remain.'), mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  DocTypeDelete(Db, Current);
  Fill;
  ShowType('');
end;

procedure RunDocTypes(AOwner: TComponent; ADb: TAppDb);
var
  D: TDocTypesDlg;
  Y: Integer;
  procedure Lbl(const ACaption: string; AY: Integer);
  begin
    with TLabel.Create(D.Form) do begin Parent := D.Form; Caption := ACaption; SetBounds(250, AY + 4, 110, 18); end;
  end;
  function Edt(AY, AW: Integer): TEdit;
  begin
    Result := TEdit.Create(D.Form);
    Result.Parent := D.Form;
    Result.SetBounds(366, AY, AW, 26);
  end;
begin
  EnsureDocTypes(ADb);
  D := TDocTypesDlg.Create;
  D.Db := ADb;
  D.Form := TForm.CreateNew(AOwner);
  try
    D.Form.Caption := Tr('Document types');
    D.Form.SetBounds(0, 0, 720, 520);
    D.Form.Position := poOwnerFormCenter;
    with TLabel.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Types (table ') + DocTypesTable + '):'; SetBounds(14, 12, 220, 18); end;
    D.List := TListBox.Create(D.Form);
    D.List.Parent := D.Form;
    D.List.SetBounds(14, 34, 220, 400);
    D.List.OnClick := @D.Pick;
    Y := 14;
    Lbl(Tr('Type code:'), Y); D.CodeEdit := Edt(Y, 120); Y := Y + 34;
    Lbl(Tr('Name:'), Y); D.NameEdit := Edt(Y, 320); Y := Y + 34;
    Lbl(Tr('Number prefix:'), Y); D.PrefixEdit := Edt(Y, 120); Y := Y + 34;
    Lbl(Tr('Number format:'), Y); D.FormatEdit := Edt(Y, 320); Y := Y + 34;
    Lbl(Tr('Last number:'), Y); D.LastEdit := Edt(Y, 100); Y := Y + 34;
    Lbl(Tr('Counter year:'), Y); D.YearEdit := Edt(Y, 100); Y := Y + 34;
    D.PrefixEdit.OnChange := @D.FormatChange;
    D.FormatEdit.OnChange := @D.FormatChange;
    D.LastEdit.OnChange := @D.FormatChange;
    D.YearEdit.OnChange := @D.FormatChange;
    D.Sample := TLabel.Create(D.Form);
    D.Sample.Parent := D.Form;
    D.Sample.SetBounds(366, Y - 4, 330, 18);
    D.Sample.Font.Style := [fsBold];
    Y := Y + 26;
    with TLabel.Create(D.Form) do
    begin
      Parent := D.Form; SetBounds(250, Y, 450, 34); AutoSize := False; WordWrap := True;
      Caption := Tr('Related types: must not be open while this one is open (e.g. delivery note and return note). Applies in both directions.');
    end;
    D.Related := TCheckListBox.Create(D.Form);
    D.Related.Parent := D.Form;
    D.Related.SetBounds(250, Y + 38, 446, 130);
    D.Fill;
    with TLabel.Create(D.Form) do
    begin
      Parent := D.Form; SetBounds(14, 440, 690, 34); AutoSize := False; WordWrap := True;
      Caption := Tr('Number format: {sifra} prefix, {godina} year (or {godina:2}), {broj:4} serial number with 4 digits. The menu opens the form with a type: openform:Dokument#vrsta=otp');
    end;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('New'); SetBounds(14, 480, 80, 30); OnClick := @D.NewClick; end;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Save'); SetBounds(100, 480, 90, 30); OnClick := @D.SaveClick; end;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Delete'); SetBounds(196, 480, 90, 30); OnClick := @D.DeleteClick; end;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Close'); ModalResult := mrCancel; SetBounds(610, 480, 90, 30); end;
    D.Form.Height := 524;
    if D.List.Items.Count > 0 then begin D.List.ItemIndex := 0; D.Pick(nil); end else D.ShowType('');
    D.Form.ShowModal;
  finally
    D.Form.Free;
    D.Free;
  end;
end;

end.
