unit ta_datatoolsdlg;
{ Alati za podatke: traži i zamijeni, skupno ažuriranje, duplikati, nepovezani
  zapisi, provjera pravila. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, StdCtrls, ExtCtrls, ComCtrls, CheckLst,
  ta_meta, ta_datatools, ta_wizardgen;

{ Vraća naziv spremljenog upita (duplikati / nepovezani) ili '' }
function RunDataTools(AOwner: TComponent; ADb: TAppDb): string;

implementation

uses
  ta_i18n;


type
  TDtDlg = class
  public
    Db: TAppDb;
    Form: TForm;
    Pages: TPageControl;
    Saved: string;
    { traži i zamijeni }
    FrTable, FrField: TComboBox;
    FrFind, FrRepl: TEdit;
    FrCase, FrWhole: TCheckBox;
    FrInfo: TLabel;
    { skupno }
    BuTable, BuField: TComboBox;
    BuExpr, BuWhere: TEdit;
    BuInfo: TLabel;
    BuSql: TMemo;
    { duplikati }
    DpSrc: TComboBox;
    DpFields: TCheckListBox;
    DpRows: TCheckBox;
    DpName: TEdit;
    DpSql: TMemo;
    { nepovezani }
    UmA, UmFa, UmB, UmFb: TComboBox;
    UmName: TEdit;
    UmSql: TMemo;
    { pravila }
    RlTable: TComboBox;
    RlLog: TMemo;
    procedure FillFields(ATable: TComboBox; AFields: TComboBox; AAddAll: Boolean);
    procedure FrTableChange(Sender: TObject);
    procedure FrCountClick(Sender: TObject);
    procedure FrDoClick(Sender: TObject);
    procedure BuTableChange(Sender: TObject);
    procedure BuCountClick(Sender: TObject);
    procedure BuDoClick(Sender: TObject);
    procedure DpSrcChange(Sender: TObject);
    procedure DpShowClick(Sender: TObject);
    procedure DpSaveClick(Sender: TObject);
    procedure UmAChange(Sender: TObject);
    procedure UmBChange(Sender: TObject);
    procedure UmShowClick(Sender: TObject);
    procedure UmSaveClick(Sender: TObject);
    procedure RlCheckClick(Sender: TObject);
    function DupSql: string;
    function UnSql: string;
    function SaveQuery(const AName, ASql: string): Boolean;
    procedure FrRun(ADry: Boolean);
    procedure BuRun(ADry: Boolean);
  end;

procedure TDtDlg.FillFields(ATable: TComboBox; AFields: TComboBox; AAddAll: Boolean);
var
  L: TaSourceFields;
  I: Integer;
begin
  AFields.Items.Clear;
  if AAddAll then AFields.Items.Add('');
  if ATable.Text = '' then Exit;
  try
    Inc(Db.QuietParams);
    try
      L := SourceFieldList(Db, ATable.Text);
    finally
      Dec(Db.QuietParams);
    end;
  except
    Exit;
  end;
  for I := 0 to High(L) do AFields.Items.Add(L[I].Name);
  if AFields.Items.Count > 0 then AFields.ItemIndex := 0;
end;

procedure TDtDlg.FrTableChange(Sender: TObject);
begin
  FillFields(FrTable, FrField, True);
  FrField.ItemIndex := 0;
end;

procedure TDtDlg.FrRun(ADry: Boolean);
var
  R: TReplaceResult;
  Err: string;
begin
  if FrTable.Text = '' then begin FrInfo.Caption := Tr('Choose a table.'); Exit; end;
  if not FindReplace(Db, FrTable.Text, FrField.Text, FrFind.Text, FrRepl.Text, FrCase.Checked, FrWhole.Checked, ADry, R, Err) then
  begin FrInfo.Caption := Tr('Error: ') + Err; Exit; end;
  if ADry then FrInfo.Caption := Tr('Will be changed: ') + IntToStr(R.Cells) + Tr(' values in ') + IntToStr(R.Rows) + Tr(' rows.')
  else FrInfo.Caption := Tr('Changed: ') + IntToStr(R.Cells) + Tr(' values in ') + IntToStr(R.Rows) + Tr(' rows.');
end;

procedure TDtDlg.FrCountClick(Sender: TObject);
begin
  FrRun(True);
end;

procedure TDtDlg.FrDoClick(Sender: TObject);
begin
  if MessageDlg(Tr('Replace in table "') + FrTable.Text + Tr('"? This changes data (a backup is recommended).'),
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  FrRun(False);
end;

procedure TDtDlg.BuTableChange(Sender: TObject);
begin
  FillFields(BuTable, BuField, False);
end;

procedure TDtDlg.BuRun(ADry: Boolean);
var
  N: Integer;
  Sql, Err: string;
begin
  if not BulkUpdate(Db, BuTable.Text, BuField.Text, BuExpr.Text, BuWhere.Text, ADry, N, Sql, Err) then
  begin BuInfo.Caption := Tr('Error: ') + Err; BuSql.Text := ''; Exit; end;
  BuSql.Text := Sql;
  if ADry then BuInfo.Caption := Tr('Rows covered: ') + IntToStr(N)
  else BuInfo.Caption := Tr('Rows updated: ') + IntToStr(N);
end;

procedure TDtDlg.BuCountClick(Sender: TObject);
begin
  BuRun(True);
end;

procedure TDtDlg.BuDoClick(Sender: TObject);
begin
  if MessageDlg(Tr('Update field "') + BuField.Text + Tr('" in table "') + BuTable.Text + Tr('"? This cannot be undone.'),
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  BuRun(False);
end;

procedure TDtDlg.DpSrcChange(Sender: TObject);
var
  L: TaSourceFields;
  I: Integer;
begin
  DpFields.Items.Clear;
  if DpSrc.Text = '' then Exit;
  try
    Inc(Db.QuietParams);
    try
      L := SourceFieldList(Db, DpSrc.Text);
    finally
      Dec(Db.QuietParams);
    end;
  except
    Exit;
  end;
  for I := 0 to High(L) do DpFields.Items.Add(L[I].Name);
end;

function TDtDlg.DupSql: string;
var
  F: TStringList;
  I: Integer;
  Err: string;
begin
  F := TStringList.Create;
  try
    for I := 0 to DpFields.Count - 1 do
      if DpFields.Checked[I] then F.Add(DpFields.Items[I]);
    if not DuplicatesSql(Db, DpSrc.Text, F, DpRows.Checked, Result, Err) then Result := '-- ' + Err;
  finally
    F.Free;
  end;
end;

function TDtDlg.SaveQuery(const AName, ASql: string): Boolean;
begin
  Result := False;
  if Trim(AName) = '' then begin ShowMessage(Tr('Enter a query name.')); Exit; end;
  if Copy(ASql, 1, 2) = '--' then begin ShowMessage(Tr('The query is not valid:') + LineEnding + ASql); Exit; end;
  if Db.LoadObject('_sys_queries', Trim(AName)) <> '' then
    if MessageDlg(Tr('Query "') + Trim(AName) + Tr('" already exists. Replace it?'), mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  Db.SaveObject('_sys_queries', Trim(AName), ASql);
  Saved := Trim(AName);
  Form.ModalResult := mrOk;
  Result := True;
end;

procedure TDtDlg.DpShowClick(Sender: TObject);
begin
  DpSql.Text := DupSql;
end;

procedure TDtDlg.DpSaveClick(Sender: TObject);
begin
  DpSql.Text := DupSql;
  SaveQuery(DpName.Text, DpSql.Text);
end;

procedure TDtDlg.UmAChange(Sender: TObject);
begin
  FillFields(UmA, UmFa, False);
end;

procedure TDtDlg.UmBChange(Sender: TObject);
begin
  FillFields(UmB, UmFb, False);
end;

function TDtDlg.UnSql: string;
var
  Err: string;
begin
  if not UnmatchedSql(Db, UmA.Text, UmFa.Text, UmB.Text, UmFb.Text, Result, Err) then Result := '-- ' + Err;
end;

procedure TDtDlg.UmShowClick(Sender: TObject);
begin
  UmSql.Text := UnSql;
end;

procedure TDtDlg.UmSaveClick(Sender: TObject);
begin
  UmSql.Text := UnSql;
  SaveQuery(UmName.Text, UmSql.Text);
end;

function Shown(ACount, ATotal: Integer): string;
begin
  if ACount < ATotal then Result := ' (prikazano prvih ' + IntToStr(ACount) + ')' else Result := '';
end;

procedure TDtDlg.RlCheckClick(Sender: TObject);
var
  Log: TStringList;
  N: Integer;
  T: string;
begin
  Log := TStringList.Create;
  try
    T := RlTable.Text;
    if T = '(sve tablice)' then T := '';
    N := CheckRules(Db, T, Log);
    if N = 0 then RlLog.Text := Tr('All data satisfy the field rules.')
    else
    begin
      Log.Insert(0, Tr('Rule violations: ') + IntToStr(N) + Shown(Log.Count, N) + LineEnding);
      RlLog.Text := Log.Text;
    end;
  finally
    Log.Free;
  end;
end;

function RunDataTools(AOwner: TComponent; ADb: TAppDb): string;
var
  D: TDtDlg;
  T: array[0..4] of TTabSheet;
  Tabs, Srcs, Tmp: TStringList;
  I: Integer;

  procedure Lbl(AParent: TWinControl; const ACap: string; X, Y: Integer);
  begin
    with TLabel.Create(D.Form) do begin Parent := AParent; Caption := ACap; SetBounds(X, Y, 340, 18); end;
  end;

  function Cmb(AParent: TWinControl; X, Y, W: Integer; AItems: TStrings): TComboBox;
  begin
    Result := TComboBox.Create(D.Form);
    Result.Parent := AParent;
    Result.Style := csDropDownList;
    Result.SetBounds(X, Y, W, 26);
    if AItems <> nil then Result.Items.AddStrings(AItems);
  end;

  function Ed(AParent: TWinControl; X, Y, W: Integer): TEdit;
  begin
    Result := TEdit.Create(D.Form);
    Result.Parent := AParent;
    Result.SetBounds(X, Y, W, 26);
  end;

  function Btn(AParent: TWinControl; const ACap: string; X, Y, W: Integer; AClick: TNotifyEvent): TButton;
  begin
    Result := TButton.Create(D.Form);
    Result.Parent := AParent;
    Result.Caption := ACap;
    Result.SetBounds(X, Y, W, 28);
    Result.OnClick := AClick;
  end;

  function Mm(AParent: TWinControl; X, Y, W, H: Integer): TMemo;
  begin
    Result := TMemo.Create(D.Form);
    Result.Parent := AParent;
    Result.SetBounds(X, Y, W, H);
    Result.ReadOnly := True;
    Result.ScrollBars := ssAutoBoth;
  end;

  function Cb(AParent: TWinControl; const ACap: string; X, Y: Integer): TCheckBox;
  begin
    Result := TCheckBox.Create(D.Form);
    Result.Parent := AParent;
    Result.Caption := ACap;
    Result.SetBounds(X, Y, 320, 22);
  end;

begin
  D := TDtDlg.Create;
  D.Db := ADb;
  D.Form := TForm.CreateNew(AOwner);
  Tabs := ADb.UserTables;
  Srcs := TStringList.Create;
  try
    Srcs.AddStrings(Tabs);
    Tmp := ADb.ListObjects('_sys_queries');
    try Srcs.AddStrings(Tmp); finally Tmp.Free; end;
    D.Form.Caption := Tr('Data tools');
    D.Form.SetBounds(0, 0, 800, 620);
    D.Form.Position := poOwnerFormCenter;
    D.Pages := TPageControl.Create(D.Form);
    D.Pages.Parent := D.Form;
    D.Pages.SetBounds(8, 8, 784, 566);
    T[0] := D.Pages.AddTabSheet; T[0].Caption := Tr('Find and replace');
    T[1] := D.Pages.AddTabSheet; T[1].Caption := Tr('Bulk update');
    T[2] := D.Pages.AddTabSheet; T[2].Caption := Tr('Duplicates');
    T[3] := D.Pages.AddTabSheet; T[3].Caption := Tr('Orphan records');
    T[4] := D.Pages.AddTabSheet; T[4].Caption := Tr('Rule check');
    { traži i zamijeni }
    Lbl(T[0], Tr('Table'), 12, 10);   D.FrTable := Cmb(T[0], 12, 30, 260, Tabs);
    Lbl(T[0], Tr('Field (empty = all text fields)'), 290, 10); D.FrField := Cmb(T[0], 290, 30, 260, nil);
    D.FrTable.OnChange := @D.FrTableChange;
    Lbl(T[0], Tr('Find'), 12, 68);     D.FrFind := Ed(T[0], 12, 88, 260);
    Lbl(T[0], Tr('Replace with'), 290, 68); D.FrRepl := Ed(T[0], 290, 88, 260);
    D.FrCase := Cb(T[0], Tr('Case sensitive'), 12, 128);
    D.FrWhole := Cb(T[0], Tr('Whole field value'), 290, 128);
    Btn(T[0], Tr('Count'), 12, 164, 110, @D.FrCountClick);
    Btn(T[0], Tr('Replace all'), 130, 164, 120, @D.FrDoClick);
    D.FrInfo := TLabel.Create(D.Form); D.FrInfo.Parent := T[0]; D.FrInfo.SetBounds(12, 206, 700, 20);
    { skupno ažuriranje }
    Lbl(T[1], Tr('Table'), 12, 10);   D.BuTable := Cmb(T[1], 12, 30, 260, Tabs);
    Lbl(T[1], Tr('Field to change'), 290, 10); D.BuField := Cmb(T[1], 290, 30, 260, nil);
    D.BuTable.OnChange := @D.BuTableChange;
    Lbl(T[1], Tr('New value (expression, e.g. [price] * 1.1  or  "Zagreb")'), 12, 68); D.BuExpr := Ed(T[1], 12, 88, 540);
    Lbl(T[1], Tr('Only for rows where (expression, empty = all, e.g. [city] = "Zg")'), 12, 124); D.BuWhere := Ed(T[1], 12, 144, 540);
    Btn(T[1], Tr('Count rows'), 12, 184, 130, @D.BuCountClick);
    Btn(T[1], Tr('Update'), 150, 184, 110, @D.BuDoClick);
    D.BuInfo := TLabel.Create(D.Form); D.BuInfo.Parent := T[1]; D.BuInfo.SetBounds(12, 226, 700, 20);
    D.BuSql := Mm(T[1], 12, 254, 740, 150);
    { duplikati }
    Lbl(T[2], Tr('Source (table or query)'), 12, 10); D.DpSrc := Cmb(T[2], 12, 30, 300, Srcs);
    D.DpSrc.OnChange := @D.DpSrcChange;
    Lbl(T[2], Tr('Fields to compare'), 12, 66);
    D.DpFields := TCheckListBox.Create(D.Form); D.DpFields.Parent := T[2]; D.DpFields.SetBounds(12, 88, 300, 200);
    D.DpRows := Cb(T[2], Tr('Show whole rows (not only the summary)'), 330, 88);
    Lbl(T[2], Tr('Query name'), 330, 126); D.DpName := Ed(T[2], 330, 146, 260);
    Btn(T[2], Tr('Show SQL'), 330, 184, 110, @D.DpShowClick);
    Btn(T[2], Tr('Save query'), 448, 184, 110, @D.DpSaveClick);
    D.DpSql := Mm(T[2], 12, 304, 740, 200);
    { nepovezani }
    Lbl(T[3], Tr('Records from table'), 12, 10); D.UmA := Cmb(T[3], 12, 30, 260, Srcs);
    Lbl(T[3], Tr('field'), 290, 10); D.UmFa := Cmb(T[3], 290, 30, 200, nil);
    D.UmA.OnChange := @D.UmAChange;
    Lbl(T[3], Tr('that have no match in table'), 12, 68); D.UmB := Cmb(T[3], 12, 88, 260, Srcs);
    Lbl(T[3], Tr('field'), 290, 68); D.UmFb := Cmb(T[3], 290, 88, 200, nil);
    D.UmB.OnChange := @D.UmBChange;
    Lbl(T[3], Tr('Query name'), 12, 126); D.UmName := Ed(T[3], 12, 146, 260);
    Btn(T[3], Tr('Show SQL'), 290, 144, 110, @D.UmShowClick);
    Btn(T[3], Tr('Save query'), 408, 144, 110, @D.UmSaveClick);
    D.UmSql := Mm(T[3], 12, 190, 740, 200);
    { pravila }
    Lbl(T[4], Tr('Table'), 12, 10);
    D.RlTable := Cmb(T[4], 12, 30, 260, nil);
    D.RlTable.Items.Add('(sve tablice)');
    D.RlTable.Items.AddStrings(Tabs);
    D.RlTable.ItemIndex := 0;
    Btn(T[4], Tr('Check'), 290, 29, 110, @D.RlCheckClick);
    D.RlLog := Mm(T[4], 12, 70, 740, 430);
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Close'); ModalResult := mrCancel; SetBounds(692, 582, 100, 30); end;
    D.Form.ShowModal;
    Result := D.Saved;
  finally
    Tabs.Free;
    Srcs.Free;
    D.Form.Free;
    D.Free;
  end;
  if I = 0 then;
end;

end.
