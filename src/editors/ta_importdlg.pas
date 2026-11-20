unit ta_importdlg;
{ Import wizard (file -> preview with inferred column types -> table) and the
  export dialog. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, ExtCtrls, StdCtrls, Grids,
  ta_meta, ta_types, ta_importexport, ta_catalog;

{ True when something was imported. }
var
  { ako je postavljeno, dijalog uvoza odmah ucita tu datoteku (snimke zaslona za priručnik) }
  ImportPresetFile: string = '';

function RunImportDialog(AOwner: TComponent; ADb: TAppDb): Boolean;
procedure RunExportDialog(AOwner: TComponent; ADb: TAppDb; const ADefaultSource: string);

implementation

uses
  ta_i18n;


type
  TImportDlg = class
  public
    Db: TAppDb;
    Form: TForm;
    FileEdit, NewName: TEdit;
    DelimBox, ExistingBox: TComboBox;
    HeaderCk, KeyCk, CatCk: TCheckBox;
    Grid: TStringGrid;
    Status: TLabel;
    Rows: TaRows;
    Cols: TaImportCols;
    Loaded: Boolean;
    Imported: Boolean;
    procedure BrowseClick(Sender: TObject);
    procedure OptionChange(Sender: TObject);
    procedure TypeDblClick(Sender: TObject);
    procedure DoImport(Sender: TObject);
    procedure Reload;
    procedure FillGrid;
  end;

procedure TImportDlg.BrowseClick(Sender: TObject);
var
  D: TOpenDialog;
  B: string;
  I: Integer;
begin
  D := TOpenDialog.Create(nil);
  try
    D.Filter := Tr('Data (*.csv;*.txt;*.tsv;*.xlsx;*.xls;*.ods)|*.csv;*.txt;*.tsv;*.xlsx;*.xls;*.ods|All files|*');
    if not D.Execute then Exit;
    FileEdit.Text := D.FileName;
    B := ChangeFileExt(ExtractFileName(D.FileName), '');
    for I := 1 to Length(B) do
      if not (B[I] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) then B[I] := '_';
    NewName.Text := B;
  finally
    D.Free;
  end;
  Reload;
end;

procedure TImportDlg.OptionChange(Sender: TObject);
begin
  Reload;
end;

procedure TImportDlg.Reload;
var
  Dl: Char;
begin
  Loaded := False;
  if not FileExists(FileEdit.Text) then Exit;
  case DelimBox.ItemIndex of
    1: Dl := ';';
    2: Dl := ',';
    3: Dl := #9;
    4: Dl := '|';
  else Dl := #0;
  end;
  try
    if not ReadAnyFile(FileEdit.Text, Dl, Rows) then
    begin
      Status.Caption := Tr('The file is empty.');
      Exit;
    end;
  except
    on E: Exception do begin Status.Caption := Tr('Reading failed: ') + E.Message; Exit; end;
  end;
  Cols := InferColumns(Rows, HeaderCk.Checked);
  Loaded := True;
  FillGrid;
end;

procedure TImportDlg.FillGrid;
var
  R, C, Shown, First: Integer;
begin
  Grid.RowCount := 2;
  Grid.ColCount := Length(Cols);
  if Length(Cols) = 0 then Exit;
  for C := 0 to High(Cols) do
  begin
    Grid.Cells[C, 0] := Cols[C].Name;
    Grid.Cells[C, 1] := LogicalNames[Cols[C].LType];
    Grid.ColWidths[C] := 120;
  end;
  if HeaderCk.Checked then First := 1 else First := 0;
  Shown := 0;
  for R := First to High(Rows) do
  begin
    if Shown >= 30 then Break;
    Grid.RowCount := Grid.RowCount + 1;
    for C := 0 to High(Cols) do
      if C <= High(Rows[R]) then Grid.Cells[C, Grid.RowCount - 1] := Rows[R][C]
      else Grid.Cells[C, Grid.RowCount - 1] := '';
    Inc(Shown);
  end;
  Status.Caption := Format(Tr('%d rows, %d columns. Double-click on a column type changes the type.'),
    [Length(Rows) - First, Length(Cols)]);
end;

procedure TImportDlg.TypeDblClick(Sender: TObject);
var
  C: Integer;
  S: string;
  T: TaLogicalType;
begin
  if not Loaded then Exit;
  C := Grid.Col;
  if (Grid.Row <> 1) or (C < 0) or (C > High(Cols)) then Exit;
  S := LogicalNames[Cols[C].LType];
  if not InputQuery(Tr('Column type ') + Cols[C].Name,
    'Text, Memo, Integer, Decimal, Currency, YesNo, Date, Time, DateTime:', S) then Exit;
  T := LogicalFromName(S);
  Cols[C].LType := T;
  if T in [ltDecimal, ltCurrency] then
  begin
    if Cols[C].Decimals = 0 then Cols[C].Decimals := 2;
  end
  else Cols[C].Decimals := 0;
  Grid.Cells[C, 1] := LogicalNames[T];
end;

procedure TImportDlg.DoImport(Sender: TObject);
var
  Res: TaImportResult;
  T: TStringList;
  Target: string;
begin
  if not Loaded then begin ShowMessage(Tr('Choose a file.')); Exit; end;
  try
    if ExistingBox.Text <> '' then
      Res := ImportToExisting(Db, ExistingBox.Text, Rows, HeaderCk.Checked)
    else
    begin
      Target := Trim(NewName.Text);
      if Target = '' then begin ShowMessage(Tr('Enter the name of the new table.')); Exit; end;
      T := Db.UserTables;
      try
        if T.IndexOf(Target) >= 0 then
        begin
          ShowMessage(Tr('Table ') + Target + Tr(' already exists. Choose it under "into an existing one" or change the name.'));
          Exit;
        end;
      finally
        T.Free;
      end;
      Res := ImportToNewTable(Db, Target, Rows, HeaderCk.Checked, KeyCk.Checked, Cols);
      if CatCk.Checked then ApplyCatalogToTable(Db, Target, nil);
    end;
  except
    on E: Exception do begin ShowMessage(Tr('Import failed: ') + E.Message); Exit; end;
  end;
  Imported := True;
  ShowMessage(Format(Tr('Rows imported: %d. Skipped: %d. Invalid values (left empty): %d.'),
    [Res.Inserted, Res.Skipped, Res.BadValues]));
  Form.ModalResult := mrOk;
end;

function RunImportDialog(AOwner: TComponent; ADb: TAppDb): Boolean;
var
  D: TImportDlg;
  T: TStringList;
  I: Integer;

  procedure Lbl(const ACap: string; X, Y: Integer);
  var
    L: TLabel;
  begin
    L := TLabel.Create(D.Form);
    L.Parent := D.Form;
    L.Caption := ACap;
    L.SetBounds(X, Y + 4, 110, 18);
  end;

begin
  D := TImportDlg.Create;
  D.Db := ADb;
  D.Form := TForm.CreateNew(AOwner);
  try
    D.Form.Caption := Tr('Data import');
    D.Form.SetBounds(0, 0, 900, 640);
    D.Form.Position := poOwnerFormCenter;
    Lbl(Tr('File:'), 12, 12);
    D.FileEdit := TEdit.Create(D.Form); D.FileEdit.Parent := D.Form; D.FileEdit.SetBounds(110, 12, 640, 26);
    D.FileEdit.ReadOnly := True;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Choose...'); SetBounds(760, 12, 110, 26); OnClick := @D.BrowseClick; end;
    Lbl(Tr('Separator:'), 12, 46);
    D.DelimBox := TComboBox.Create(D.Form); D.DelimBox.Parent := D.Form; D.DelimBox.SetBounds(110, 46, 130, 26);
    D.DelimBox.Style := csDropDownList;
    D.DelimBox.Items.CommaText := TrCsv('Automatski,";",",",Tab,"|"');
    D.DelimBox.ItemIndex := 0;
    D.DelimBox.OnChange := @D.OptionChange;
    D.HeaderCk := TCheckBox.Create(D.Form); D.HeaderCk.Parent := D.Form;
    D.HeaderCk.Caption := Tr('The first row contains names'); D.HeaderCk.SetBounds(250, 48, 240, 22); D.HeaderCk.Checked := True;
    D.HeaderCk.OnChange := @D.OptionChange;
    D.KeyCk := TCheckBox.Create(D.Form); D.KeyCk.Parent := D.Form;
    D.KeyCk.Caption := Tr('Add key (id)'); D.KeyCk.SetBounds(500, 48, 150, 22); D.KeyCk.Checked := True;
    D.CatCk := TCheckBox.Create(D.Form); D.CatCk.Parent := D.Form;
    D.CatCk.Caption := Tr('Labels, descriptions and checks from the catalog'); D.CatCk.SetBounds(660, 48, 230, 22); D.CatCk.Checked := True;
    Lbl(Tr('New table:'), 12, 80);
    D.NewName := TEdit.Create(D.Form); D.NewName.Parent := D.Form; D.NewName.SetBounds(110, 80, 240, 26);
    Lbl(Tr('or into an existing one:'), 370, 80);
    D.ExistingBox := TComboBox.Create(D.Form); D.ExistingBox.Parent := D.Form; D.ExistingBox.SetBounds(480, 80, 240, 26);
    D.ExistingBox.Style := csDropDownList;
    D.ExistingBox.Items.Add('');
    T := ADb.UserTables;
    try
      for I := 0 to T.Count - 1 do D.ExistingBox.Items.Add(T[I]);
    finally
      T.Free;
    end;
    D.ExistingBox.ItemIndex := 0;
    D.Status := TLabel.Create(D.Form); D.Status.Parent := D.Form; D.Status.SetBounds(12, 118, 860, 18);
    D.Status.Caption := Tr('Choose a CSV, XLSX or ODS file.');
    D.Grid := TStringGrid.Create(D.Form);
    D.Grid.Parent := D.Form;
    D.Grid.SetBounds(12, 142, 876, 400);
    D.Grid.Anchors := [akLeft, akTop, akRight, akBottom];
    D.Grid.FixedRows := 2;
    D.Grid.FixedCols := 0;
    D.Grid.ColCount := 1;
    D.Grid.RowCount := 2;
    D.Grid.OnDblClick := @D.TypeDblClick;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Import'); SetBounds(690, 560, 90, 30); Anchors := [akRight, akBottom]; OnClick := @D.DoImport; end;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Close'); ModalResult := mrCancel; SetBounds(790, 560, 90, 30); Anchors := [akRight, akBottom]; end;
    if (ImportPresetFile <> '') and FileExists(ImportPresetFile) then
    begin
      D.FileEdit.Text := ImportPresetFile;
      D.NewName.Text := 'uvezeno';
      D.Reload;
      D.FileEdit.SelLength := 0;
    end;
    D.Form.ShowModal;
    Result := D.Imported;
  finally
    D.Form.Free;
    D.Free;
  end;
end;

procedure RunExportDialog(AOwner: TComponent; ADb: TAppDb; const ADefaultSource: string);
var
  F: TForm;
  Src, Fmt: TComboBox;
  T: TStringList;
  I: Integer;
  D: TSaveDialog;
  Name, Ext: string;
begin
  F := TForm.CreateNew(AOwner);
  try
    F.Caption := Tr('Data export');
    F.SetBounds(0, 0, 460, 200);
    F.Position := poOwnerFormCenter;
    with TLabel.Create(F) do begin Parent := F; Caption := Tr('Source:'); SetBounds(12, 20, 80, 18); end;
    Src := TComboBox.Create(F); Src.Parent := F; Src.SetBounds(100, 16, 330, 26); Src.Style := csDropDownList;
    T := ADb.UserTables;
    try
      for I := 0 to T.Count - 1 do Src.Items.Add(T[I]);
    finally
      T.Free;
    end;
    T := ADb.ListObjects('_sys_queries');
    try
      for I := 0 to T.Count - 1 do Src.Items.Add(T[I]);
    finally
      T.Free;
    end;
    Src.ItemIndex := Src.Items.IndexOf(ADefaultSource);
    if (Src.ItemIndex < 0) and (Src.Items.Count > 0) then Src.ItemIndex := 0;
    with TLabel.Create(F) do begin Parent := F; Caption := Tr('Format:'); SetBounds(12, 58, 80, 18); end;
    Fmt := TComboBox.Create(F); Fmt.Parent := F; Fmt.SetBounds(100, 54, 330, 26); Fmt.Style := csDropDownList;
    Fmt.Items.Add(Tr('CSV (;) - for Croatian Excel'));
    Fmt.Items.Add('CSV (,)');
    Fmt.Items.Add('Excel (.xlsx)');
    Fmt.Items.Add('JSON');
    Fmt.ItemIndex := 0;
    with TButton.Create(F) do begin Parent := F; Caption := Tr('Export...'); ModalResult := mrOk; SetBounds(240, 120, 90, 30); end;
    with TButton.Create(F) do begin Parent := F; Caption := Tr('Cancel'); ModalResult := mrCancel; SetBounds(340, 120, 90, 30); end;
    if F.ShowModal <> mrOk then Exit;
    Name := Src.Text;
    if Name = '' then begin ShowMessage(Tr('There is no source to export.')); Exit; end;
    case Fmt.ItemIndex of
      2: Ext := 'xlsx';
      3: Ext := 'json';
    else Ext := 'csv';
    end;
    D := TSaveDialog.Create(nil);
    try
      D.DefaultExt := Ext;
      D.FileName := Name + '.' + Ext;
      D.Filter := Ext + ' (*.' + Ext + ')|*.' + Ext;
      if not D.Execute then Exit;
      try
        case Fmt.ItemIndex of
          0: ExportCsv(ADb, Name, D.FileName, ';');
          1: ExportCsv(ADb, Name, D.FileName, ',');
          2: ExportXlsx(ADb, Name, D.FileName);
          3: ExportJson(ADb, Name, D.FileName);
        end;
        ShowMessage(Tr('Saved: ') + D.FileName);
      except
        on E: Exception do ShowMessage(Tr('Export failed: ') + E.Message);
      end;
    finally
      D.Free;
    end;
  finally
    F.Free;
  end;
end;

end.
