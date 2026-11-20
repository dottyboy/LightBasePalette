unit ta_crosstabdlg;
{ Čarobnjak za unakrsni upit (pivot) i uniju upita/tablica. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, StdCtrls, ExtCtrls, ComCtrls, CheckLst,
  ta_meta, ta_wizardgen, ta_crosstab;

{ Vraća naziv spremljenog upita ili '' ako je odustao. }
function RunCrosstabWizard(AOwner: TComponent; ADb: TAppDb): string;

implementation

uses
  ta_i18n;


type
  TCtDlg = class
  public
    Db: TAppDb;
    Form: TForm;
    Pages: TPageControl;
    SrcBox, RowBox, ColBox, ValBox, AggBox: TComboBox;
    TotalCk, AllCk: TCheckBox;
    NameEdit, UNameEdit: TEdit;
    Sql, USql: TMemo;
    UList: TCheckListBox;
    Saved: string;
    procedure SourceChange(Sender: TObject);
    procedure PreviewClick(Sender: TObject);
    procedure SaveClick(Sender: TObject);
    procedure UPreviewClick(Sender: TObject);
    procedure USaveClick(Sender: TObject);
    function Build(out ASql: string): Boolean;
    function BuildU(out ASql: string): Boolean;
    function SaveAs(const AName, ASql: string): Boolean;
  end;

procedure TCtDlg.SourceChange(Sender: TObject);
var
  L: TaSourceFields;
  I: Integer;
begin
  RowBox.Items.Clear;
  ColBox.Items.Clear;
  ValBox.Items.Clear;
  ValBox.Items.Add('');
  if SrcBox.Text = '' then Exit;
  try
    Inc(Db.QuietParams);
    try
      L := SourceFieldList(Db, SrcBox.Text);
    finally
      Dec(Db.QuietParams);
    end;
  except
    Exit;
  end;
  for I := 0 to High(L) do
  begin
    RowBox.Items.Add(L[I].Name);
    ColBox.Items.Add(L[I].Name);
    ValBox.Items.Add(L[I].Name);
  end;
  if RowBox.Items.Count > 0 then RowBox.ItemIndex := 0;
  if ColBox.Items.Count > 1 then ColBox.ItemIndex := 1;
  if ValBox.Items.Count > 2 then ValBox.ItemIndex := ValBox.Items.Count - 1;
end;

function TCtDlg.Build(out ASql: string): Boolean;
var
  Err: string;
begin
  Result := BuildCrosstabSql(Db, SrcBox.Text, RowBox.Text, ColBox.Text, ValBox.Text,
    TCtAgg(AggBox.ItemIndex), TotalCk.Checked, ASql, Err);
  if not Result then ASql := '-- ' + Err;
end;

procedure TCtDlg.PreviewClick(Sender: TObject);
var
  S: string;
begin
  Build(S);
  Sql.Text := S;
end;

function TCtDlg.SaveAs(const AName, ASql: string): Boolean;
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

procedure TCtDlg.SaveClick(Sender: TObject);
var
  S: string;
begin
  Build(S);
  Sql.Text := S;
  SaveAs(NameEdit.Text, S);
end;

function TCtDlg.BuildU(out ASql: string): Boolean;
var
  L: TStringList;
  I: Integer;
  Err: string;
begin
  L := TStringList.Create;
  try
    for I := 0 to UList.Count - 1 do
      if UList.Checked[I] then L.Add(UList.Items[I]);
    Result := BuildUnionSql(Db, L, AllCk.Checked, ASql, Err);
    if not Result then ASql := '-- ' + Err;
  finally
    L.Free;
  end;
end;

procedure TCtDlg.UPreviewClick(Sender: TObject);
var
  S: string;
begin
  BuildU(S);
  USql.Text := S;
end;

procedure TCtDlg.USaveClick(Sender: TObject);
var
  S: string;
begin
  BuildU(S);
  USql.Text := S;
  SaveAs(UNameEdit.Text, S);
end;

function RunCrosstabWizard(AOwner: TComponent; ADb: TAppDb): string;
var
  D: TCtDlg;
  T1, T2: TTabSheet;
  L, Tmp: TStringList;
  I: Integer;

  procedure Lbl(AParent: TWinControl; const ACap: string; X, Y: Integer);
  begin
    with TLabel.Create(D.Form) do begin Parent := AParent; Caption := ACap; SetBounds(X, Y, 200, 18); end;
  end;

  function Cmb(AParent: TWinControl; X, Y, W: Integer): TComboBox;
  begin
    Result := TComboBox.Create(D.Form);
    Result.Parent := AParent;
    Result.Style := csDropDownList;
    Result.SetBounds(X, Y, W, 26);
  end;

begin
  D := TCtDlg.Create;
  D.Db := ADb;
  D.Form := TForm.CreateNew(AOwner);
  try
    D.Form.Caption := Tr('Crosstab query and union');
    D.Form.SetBounds(0, 0, 760, 600);
    D.Form.Position := poOwnerFormCenter;
    D.Pages := TPageControl.Create(D.Form);
    D.Pages.Parent := D.Form;
    D.Pages.SetBounds(8, 8, 744, 540);
    T1 := D.Pages.AddTabSheet; T1.Caption := Tr('Crosstab query');
    T2 := D.Pages.AddTabSheet; T2.Caption := Tr('Union');
    L := TStringList.Create;
    try
      Tmp := ADb.UserTables;
      try L.AddStrings(Tmp); finally Tmp.Free; end;
      Tmp := ADb.ListObjects('_sys_queries');
      try L.AddStrings(Tmp); finally Tmp.Free; end;
      { tablice i upiti }
      Lbl(T1, Tr('Source (table or query)'), 12, 10);
      D.SrcBox := Cmb(T1, 12, 30, 300);
      D.SrcBox.Items.AddStrings(L);
      Lbl(T2, Tr('Choose the sources to combine (same number of columns)'), 12, 10);
      D.UList := TCheckListBox.Create(D.Form);
      D.UList.Parent := T2;
      D.UList.SetBounds(12, 32, 300, 330);
      D.UList.Items.AddStrings(L);
    finally
      L.Free;
    end;
    D.SrcBox.OnChange := @D.SourceChange;
    Lbl(T1, Tr('In rows (groups)'), 12, 66);
    D.RowBox := Cmb(T1, 12, 86, 300);
    Lbl(T1, Tr('In columns (values become columns)'), 330, 66);
    D.ColBox := Cmb(T1, 330, 86, 300);
    Lbl(T1, Tr('Value (what is summed)'), 12, 122);
    D.ValBox := Cmb(T1, 12, 142, 300);
    Lbl(T1, Tr('Function'), 330, 122);
    D.AggBox := Cmb(T1, 330, 142, 200);
    for I := Ord(Low(TCtAgg)) to Ord(High(TCtAgg)) do D.AggBox.Items.Add(CtAggNames[TCtAgg(I)]);
    D.AggBox.ItemIndex := 0;
    D.TotalCk := TCheckBox.Create(D.Form);
    D.TotalCk.Parent := T1;
    D.TotalCk.Caption := Tr('Add a Total column');
    D.TotalCk.SetBounds(12, 180, 300, 22);
    D.TotalCk.Checked := True;
    Lbl(T1, Tr('Query name'), 12, 214);
    D.NameEdit := TEdit.Create(D.Form); D.NameEdit.Parent := T1; D.NameEdit.SetBounds(12, 234, 300, 26);
    with TButton.Create(D.Form) do begin Parent := T1; Caption := Tr('Show SQL'); SetBounds(330, 232, 110, 28); OnClick := @D.PreviewClick; end;
    with TButton.Create(D.Form) do begin Parent := T1; Caption := Tr('Save query'); SetBounds(448, 232, 110, 28); OnClick := @D.SaveClick; end;
    D.Sql := TMemo.Create(D.Form);
    D.Sql.Parent := T1;
    D.Sql.SetBounds(12, 272, 710, 230);
    D.Sql.ReadOnly := True;
    D.Sql.ScrollBars := ssAutoBoth;
    D.AllCk := TCheckBox.Create(D.Form);
    D.AllCk.Parent := T2;
    D.AllCk.Caption := Tr('Keep duplicates (UNION ALL)');
    D.AllCk.SetBounds(330, 32, 300, 22);
    Lbl(T2, Tr('Query name'), 330, 66);
    D.UNameEdit := TEdit.Create(D.Form); D.UNameEdit.Parent := T2; D.UNameEdit.SetBounds(330, 86, 300, 26);
    with TButton.Create(D.Form) do begin Parent := T2; Caption := Tr('Show SQL'); SetBounds(330, 124, 110, 28); OnClick := @D.UPreviewClick; end;
    with TButton.Create(D.Form) do begin Parent := T2; Caption := Tr('Save query'); SetBounds(448, 124, 110, 28); OnClick := @D.USaveClick; end;
    D.USql := TMemo.Create(D.Form);
    D.USql.Parent := T2;
    D.USql.SetBounds(12, 372, 710, 130);
    D.USql.ReadOnly := True;
    D.USql.ScrollBars := ssAutoBoth;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Close'); ModalResult := mrCancel; SetBounds(652, 556, 100, 30); end;
    D.Form.ShowModal;
    Result := D.Saved;
  finally
    D.Form.Free;
    D.Free;
  end;
end;

end.
