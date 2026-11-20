unit ta_gendlg;
{ Application wizard: analyses the database schema, shows every table with its detected role (changeable from a drop-down),
  lets the user pick a few options, previews what will be made and then generates forms, lists, reports and the main menu. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, ExtCtrls, StdCtrls, ComCtrls, ta_meta;

{ True when the application was generated. }
function RunApplicationWizard(AOwner: TComponent; ADb: TAppDb): Boolean;

implementation

uses
  ta_i18n, ta_types, ta_wizardgen, ta_schemaplan, ta_appgen;

type
  TGenDlg = class
  public
    Db: TAppDb;
    Plan: TaSchemaPlan;
    Form: TForm;
    Tables: TListView;
    RoleBox, ParentBox, LayoutBox, DetailBox: TComboBox;
    ListsCk, ReportsCk, CodebooksCk, MenuCk, DictCk, NumberCk, StampsCk, OverwriteCk: TCheckBox;
    LogMemo: TMemo;
    GenBtn: TButton;
    Done: Boolean;
    Busy: Boolean;
    procedure FillTable;
    procedure RefreshRow(AIndex: Integer);
    procedure SelectTable(Sender: TObject; Item: TListItem; Selected: Boolean);
    procedure FormShow(Sender: TObject);
    procedure RoleChange(Sender: TObject);
    procedure ParentChange(Sender: TObject);
    procedure PreviewClick(Sender: TObject);
    procedure GenerateClick(Sender: TObject);
    procedure ParentsFor(T: TaTablePlan);
    function Options: TaGenOptions;
  end;

function RoleCaption(R: TaTableRole): string;
begin
  case R of
    trMain: Result := Tr('Main (form, list, report)');
    trDetail: Result := Tr('Items of another table');
    trCodebook: Result := Tr('Codebook (grid)');
    trJunction: Result := Tr('Link table (skip)');
  else
    Result := Tr('Skip');
  end;
end;

procedure TGenDlg.RefreshRow(AIndex: Integer);
var
  T: TaTablePlan;
  It: TListItem;
begin
  T := Plan.Items2(AIndex);
  It := Tables.Items[AIndex];
  It.Caption := T.Name;
  It.SubItems.Clear;
  It.SubItems.Add(RoleCaption(T.Role));
  It.SubItems.Add(T.Parent);
  It.SubItems.Add(IntToStr(Length(T.Cols)));
end;

procedure TGenDlg.FillTable;
var
  I: Integer;
begin
  Tables.Items.Clear;
  for I := 0 to Plan.Count - 1 do
  begin
    Tables.Items.Add;
    RefreshRow(I);
  end;
end;

procedure TGenDlg.ParentsFor(T: TaTablePlan);
var
  C: TStringList;
begin
  ParentBox.Items.Clear;
  if (T = nil) or (T.Role <> trDetail) then begin ParentBox.Enabled := False; Exit; end;
  C := ParentCandidates(Plan, T);
  try
    ParentBox.Items.Assign(C);
  finally
    C.Free;
  end;
  ParentBox.ItemIndex := ParentBox.Items.IndexOf(T.Parent);
  ParentBox.Enabled := ParentBox.Items.Count > 1;
end;

procedure TGenDlg.SelectTable(Sender: TObject; Item: TListItem; Selected: Boolean);
var
  T: TaTablePlan;
begin
  if (not Selected) or (Item = nil) or Busy then Exit;
  T := Plan.Items2(Item.Index);
  Busy := True;
  try
    RoleBox.ItemIndex := Ord(T.Role);
    RoleBox.Enabled := True;
    ParentsFor(T);
  finally
    Busy := False;
  end;
end;

procedure TGenDlg.FormShow(Sender: TObject);
begin
  if Tables.Items.Count = 0 then Exit;
  Tables.Items[0].Selected := True;
  Tables.ItemIndex := 0;
  SelectTable(Tables, Tables.Items[0], True);
end;

procedure TGenDlg.RoleChange(Sender: TObject);
var
  T: TaTablePlan;
  R: TaTableRole;
  Idx: Integer;
begin
  if Busy or (Tables.Selected = nil) or (RoleBox.ItemIndex < 0) then Exit;
  Idx := Tables.Selected.Index;
  T := Plan.Items2(Idx);
  R := TaTableRole(RoleBox.ItemIndex);
  if not SetTableRole(Plan, T, R, '') then
  begin
    ShowMessage(Tr('This table has no foreign key to a table it could be the items of.'));
    SetTableRole(Plan, T, trMain, '');
  end;
  Busy := True;
  try
    RoleBox.ItemIndex := Ord(T.Role);
    ParentsFor(T);
  finally
    Busy := False;
  end;
  RefreshRow(Idx);
end;

procedure TGenDlg.ParentChange(Sender: TObject);
var
  T: TaTablePlan;
  Idx: Integer;
begin
  if Busy or (Tables.Selected = nil) or (ParentBox.ItemIndex < 0) then Exit;
  Idx := Tables.Selected.Index;
  T := Plan.Items2(Idx);
  if not SetTableRole(Plan, T, trDetail, ParentBox.Text) then
    ShowMessage(Tr('That table cannot be the parent.'));
  RefreshRow(Idx);
end;

function TGenDlg.Options: TaGenOptions;
begin
  Result := DefaultGenOptions;
  if LayoutBox.ItemIndex = 0 then Result.Layout := flOneColumn else Result.Layout := flTwoColumns;
  Result.DetailTabs := DetailBox.ItemIndex = 1;
  Result.Lists := ListsCk.Checked;
  Result.Reports := ReportsCk.Checked;
  Result.Codebooks := CodebooksCk.Checked;
  Result.Menu := MenuCk.Checked;
  Result.Dictionary := DictCk.Checked;
  Result.DictOptions.Numbering := NumberCk.Checked;
  Result.DictOptions.Stamps := StampsCk.Checked;
  Result.Overwrite := OverwriteCk.Checked;
end;

procedure TGenDlg.PreviewClick(Sender: TObject);
var
  R: TaGenResult;
begin
  LogMemo.Lines.Clear;
  R := PreviewApplication(Db, Plan, Options, LogMemo.Lines);
  LogMemo.Lines.Add('');
  LogMemo.Lines.Add(Format(Tr('Preview: %d forms, %d lists, %d reports, %d codebooks, %d already exist'),
    [R.Forms, R.Lists, R.Reports, R.Codebooks, R.Skipped]));
end;

procedure TGenDlg.GenerateClick(Sender: TObject);
var
  R: TaGenResult;
begin
  if Options.Overwrite and
     (MessageDlg(Tr('Existing forms and reports with the same names will be replaced. Continue?'), mtConfirmation, [mbYes, mbNo], 0) <> mrYes) then Exit;
  LogMemo.Lines.Clear;
  Screen.Cursor := crHourGlass;
  try
    R := GenerateApplication(Db, Plan, Options, LogMemo.Lines);
  finally
    Screen.Cursor := crDefault;
  end;
  LogMemo.Lines.Add('');
  LogMemo.Lines.Add(Format(Tr('Done: %d forms, %d lists, %d reports, %d codebooks, %d skipped'),
    [R.Forms, R.Lists, R.Reports, R.Codebooks, R.Skipped]));
  Done := True;
end;

function RunApplicationWizard(AOwner: TComponent; ADb: TAppDb): Boolean;
var
  D: TGenDlg;
  R: TaTableRole;
  Y: Integer;

  function Lbl(const ACaption: string; X, AY, W: Integer): TLabel;
  begin
    Result := TLabel.Create(D.Form);
    Result.Parent := D.Form;
    Result.Caption := ACaption;
    Result.SetBounds(X, AY, W, 18);
  end;

  function Cb(const ACaption: string; X, AY: Integer; AChecked: Boolean): TCheckBox;
  begin
    Result := TCheckBox.Create(D.Form);
    Result.Parent := D.Form;
    Result.Caption := ACaption;
    Result.SetBounds(X, AY, 440, 22);
    Result.Checked := AChecked;
  end;

  function Combo(X, AY, W: Integer; const AItems: string): TComboBox;
  begin
    Result := TComboBox.Create(D.Form);
    Result.Parent := D.Form;
    Result.SetBounds(X, AY, W, 26);
    Result.Style := csDropDownList;
    Result.Items.Text := AItems;
    Result.ItemIndex := 0;
  end;

begin
  D := TGenDlg.Create;
  D.Db := ADb;
  D.Plan := AnalyzeSchema(ADb);
  D.Form := TForm.CreateNew(AOwner);
  try
    D.Form.Caption := Tr('Create application from database');
    D.Form.SetBounds(0, 0, 1100, 720);
    D.Form.Position := poOwnerFormCenter;
    Lbl(Tr('Tables and what the application makes of them (select a table to change its role)'), 14, 10, 600);
    D.Tables := TListView.Create(D.Form);
    D.Tables.Parent := D.Form;
    D.Tables.SetBounds(14, 32, 615, 300);
    D.Tables.ViewStyle := vsReport;
    D.Tables.ReadOnly := True;
    D.Tables.RowSelect := True;
    D.Tables.HideSelection := False;
    with D.Tables.Columns.Add do begin Caption := Tr('Table'); Width := 160; end;
    with D.Tables.Columns.Add do begin Caption := Tr('Role'); Width := 265; end;
    with D.Tables.Columns.Add do begin Caption := Tr('Items of'); Width := 100; end;
    with D.Tables.Columns.Add do begin Caption := Tr('Columns'); Width := 66; end;
    D.FillTable;
    D.Tables.OnSelectItem := @D.SelectTable;
    Lbl(Tr('Role of the selected table:'), 14, 344, 200);
    D.RoleBox := TComboBox.Create(D.Form);
    D.RoleBox.Parent := D.Form;
    D.RoleBox.SetBounds(210, 340, 404, 26);
    D.RoleBox.Style := csDropDownList;
    for R := Low(R) to High(R) do D.RoleBox.Items.Add(RoleCaption(R));
    D.RoleBox.Enabled := False;
    D.RoleBox.OnChange := @D.RoleChange;
    Lbl(Tr('Items of table:'), 14, 376, 200);
    D.ParentBox := TComboBox.Create(D.Form);
    D.ParentBox.Parent := D.Form;
    D.ParentBox.SetBounds(210, 372, 404, 26);
    D.ParentBox.Style := csDropDownList;
    D.ParentBox.Enabled := False;
    D.ParentBox.OnChange := @D.ParentChange;
    { opcije }
    Lbl(Tr('Entry form layout:'), 640, 32, 170);
    D.LayoutBox := Combo(840, 28, 220, Tr('One column') + LineEnding + Tr('Two columns'));
    D.LayoutBox.ItemIndex := 1;
    Lbl(Tr('Items of a document:'), 640, 64, 170);
    D.DetailBox := Combo(840, 60, 220, Tr('Below the form') + LineEnding + Tr('On tabs'));
    Y := 98;
    D.ListsCk := Cb(Tr('A list (with filters) for every main table'), 640, Y, True); Inc(Y, 26);
    D.ReportsCk := Cb(Tr('A report for every main table'), 640, Y, True); Inc(Y, 26);
    D.CodebooksCk := Cb(Tr('Editing grids for codebooks'), 640, Y, True); Inc(Y, 26);
    D.MenuCk := Cb(Tr('Make a main menu from all forms and reports'), 640, Y, True); Inc(Y, 26);
    D.DictCk := Cb(Tr('Fill the data dictionary (captions, formats)'), 640, Y, True); Inc(Y, 26);
    D.StampsCk := Cb(Tr('Created and modified stamps filled in automatically'), 640, Y, True); Inc(Y, 26);
    D.NumberCk := Cb(Tr('Number documents automatically (no./premises/device)'), 640, Y, False); Inc(Y, 26);
    D.OverwriteCk := Cb(Tr('Replace forms and reports that already exist'), 640, Y, False);
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Preview'); SetBounds(14, 412, 160, 30); OnClick := @D.PreviewClick; end;
    D.GenBtn := TButton.Create(D.Form);
    D.GenBtn.Parent := D.Form;
    D.GenBtn.Caption := Tr('Generate application');
    D.GenBtn.SetBounds(184, 412, 200, 30);
    D.GenBtn.OnClick := @D.GenerateClick;
    Lbl(Tr('What was made'), 14, 452, 200);
    D.LogMemo := TMemo.Create(D.Form);
    D.LogMemo.Parent := D.Form;
    D.LogMemo.SetBounds(14, 474, 1066, 190);
    D.LogMemo.ReadOnly := True;
    D.LogMemo.ScrollBars := ssAutoVertical;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Close'); ModalResult := mrCancel; SetBounds(980, 674, 100, 30); end;
    D.Form.OnShow := @D.FormShow;
    D.Form.ShowModal;
    Result := D.Done;
  finally
    D.Form.Free;
    D.Plan.Free;
    D.Free;
  end;
end;

end.
