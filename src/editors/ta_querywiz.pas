unit ta_querywiz;
{ Simple query wizard: tables, fields, detail or summary, name. It builds the
  same design the query designer edits, so the result can be refined there. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, ExtCtrls, StdCtrls, CheckLst, Grids, Graphics,
  ta_meta, ta_types, ta_wizardgen, ta_qbe, ta_calcdlg;

{ Returns the saved query's name, or '' when cancelled. }
function RunQueryWizard(AOwner: TComponent; ADb: TAppDb): string;

{ the roles offered for a column, for tests }
function QueryWizardDesign(ADb: TAppDb; ATables, AFields: TStrings; ASummary: Boolean): TaQbeDesign;

implementation

uses
  ta_i18n;


function QueryWizardDesign(ADb: TAppDb; ATables, AFields: TStrings; ASummary: Boolean): TaQbeDesign;
var
  I, P: Integer;
  L: TaSourceFields;
  T, F: string;
  Numeric: Boolean;
  K: Integer;
begin
  Result := TaQbeDesign.Create;
  Result.Tables.Assign(ATables);
  for I := 0 to AFields.Count - 1 do
  begin
    P := Pos('.', AFields[I]);
    T := Copy(AFields[I], 1, P - 1);
    F := Copy(AFields[I], P + 1, MaxInt);
    Numeric := False;
    try
      L := SourceFieldList(ADb, T);
      for K := 0 to High(L) do
        if SameText(L[K].Name, F) and (L[K].LType in [ltInteger, ltDecimal, ltCurrency]) then Numeric := True;
    except
    end;
    if not ASummary then Result.AddColumn(AFields[I], '')
    else if Numeric then Result.AddColumn(AFields[I], '', True, 'sum')
    else Result.AddColumn(AFields[I], '', True, 'group');
  end;
end;

type
  TQWiz = class
  public
    Db: TAppDb;
    Form: TForm;
    Tables: TCheckListBox;
    Fields: TCheckListBox;
    Grid: TStringGrid;
    ModeBox: TComboBox;
    NameEdit: TEdit;
    OpenCk: TCheckBox;
    Updating: Boolean;
    procedure TablesCheck(Sender: TObject);
    procedure FieldsCheck(Sender: TObject);
    procedure ModeChange(Sender: TObject);
    procedure CalcClick(Sender: TObject);
    procedure CheckedTables(AList: TStrings);
    procedure Refill;
    function IsNumeric(const AField: string): Boolean;
    function Design: TaQbeDesign;
  end;

const
  RoleNames: array[0..5] of string = ('Prikaži', 'Grupiraj', 'Zbroj', 'Prosjek', 'Broj', 'Min');
  RoleCodes: array[0..5] of string = ('', 'group', 'sum', 'avg', 'count', 'min');

procedure TQWiz.CheckedTables(AList: TStrings);
var
  I: Integer;
begin
  AList.Clear;
  for I := 0 to Tables.Count - 1 do
    if Tables.Checked[I] then AList.Add(Tables.Items[I]);
end;

function TQWiz.IsNumeric(const AField: string): Boolean;
var
  P, K: Integer;
  L: TaSourceFields;
begin
  Result := False;
  P := Pos('.', AField);
  if P = 0 then Exit;
  try
    L := SourceFieldList(Db, Copy(AField, 1, P - 1));
    for K := 0 to High(L) do
      if SameText(L[K].Name, Copy(AField, P + 1, MaxInt)) and (L[K].LType in [ltInteger, ltDecimal, ltCurrency]) then
        Result := True;
  except
  end;
end;

procedure TQWiz.TablesCheck(Sender: TObject);
var
  T, F: TStringList;
  I: Integer;
  Keep: TStringList;
begin
  T := TStringList.Create;
  Keep := TStringList.Create;
  try
    CheckedTables(T);
    for I := 0 to Fields.Count - 1 do if Fields.Checked[I] then Keep.Add(Fields.Items[I]);
    F := QbeFieldChoices(Db, T);
    try
      Fields.Items.Assign(F);
    finally
      F.Free;
    end;
    for I := 0 to Fields.Count - 1 do Fields.Checked[I] := Keep.IndexOf(Fields.Items[I]) >= 0;
  finally
    Keep.Free;
    T.Free;
  end;
  Refill;
end;

procedure TQWiz.FieldsCheck(Sender: TObject);
begin
  Refill;
end;

procedure TQWiz.ModeChange(Sender: TObject);
var
  I: Integer;
begin
  { summary: numbers are added up, everything else groups }
  for I := 1 to Grid.RowCount - 1 do
  begin
    if ModeBox.ItemIndex = 0 then Grid.Cells[1, I] := RoleNames[0]
    else if IsNumeric(Grid.Cells[0, I]) then Grid.Cells[1, I] := RoleNames[2]
    else Grid.Cells[1, I] := RoleNames[1];
  end;
end;

{ one row per selected field, keeping what the user already chose for it }
procedure TQWiz.Refill;
var
  Old: TStringList;
  I, R: Integer;
  Role, Sort, Alias: string;
begin
  Old := TStringList.Create;
  try
    for R := 1 to Grid.RowCount - 1 do
      Old.Add(Grid.Cells[0, R] + #1 + Grid.Cells[1, R] + #1 + Grid.Cells[2, R] + #1 + Grid.Cells[3, R]);
    Grid.RowCount := 1;
    for I := 0 to Fields.Count - 1 do
      if Fields.Checked[I] then
      begin
        Role := ''; Sort := ''; Alias := '';
        for R := 0 to Old.Count - 1 do
          if Copy(Old[R], 1, Length(Fields.Items[I]) + 1) = Fields.Items[I] + #1 then
          begin
            Role := Copy(Old[R], Pos(#1, Old[R]) + 1, MaxInt);
            Sort := Copy(Role, Pos(#1, Role) + 1, MaxInt);
            Alias := Copy(Sort, Pos(#1, Sort) + 1, MaxInt);
            Role := Copy(Role, 1, Pos(#1, Role) - 1);
            Sort := Copy(Sort, 1, Pos(#1, Sort) - 1);
          end;
        Grid.RowCount := Grid.RowCount + 1;
        R := Grid.RowCount - 1;
        Grid.Cells[0, R] := Fields.Items[I];
        if Role = '' then
        begin
          if ModeBox.ItemIndex = 0 then Role := RoleNames[0]
          else if IsNumeric(Fields.Items[I]) then Role := RoleNames[2]
          else Role := RoleNames[1];
        end;
        Grid.Cells[1, R] := Role;
        Grid.Cells[2, R] := Sort;
        Grid.Cells[3, R] := Alias;
      end;
  finally
    Old.Free;
  end;
end;

procedure TQWiz.CalcClick(Sender: TObject);
var
  T: TStringList;
  A, E: string;
  R: Integer;
begin
  T := TStringList.Create;
  try
    CheckedTables(T);
    if T.Count = 0 then begin ShowMessage(Tr('First select at least one table.')); Exit; end;
    if RunCalcWizard(Form, Db, T, True, A, E) then
    begin
      Grid.RowCount := Grid.RowCount + 1;
      R := Grid.RowCount - 1;
      Grid.Cells[0, R] := E;
      Grid.Cells[1, R] := RoleNames[0];
      Grid.Cells[2, R] := '';
      Grid.Cells[3, R] := A;
    end;
  finally
    T.Free;
  end;
end;

function TQWiz.Design: TaQbeDesign;
var
  R, K: Integer;
  Code, Sort: string;
begin
  Result := TaQbeDesign.Create;
  CheckedTables(Result.Tables);
  for R := 1 to Grid.RowCount - 1 do
  begin
    Code := '';
    for K := 0 to High(RoleNames) do
      if SameText(RoleNames[K], Grid.Cells[1, R]) then Code := RoleCodes[K];
    Sort := '';
    if SameText(Grid.Cells[2, R], 'Uzlazno') then Sort := 'asc'
    else if SameText(Grid.Cells[2, R], 'Silazno') then Sort := 'desc';
    { a calculated column is not grouped by the wizard }
    Result.AddColumn(Grid.Cells[0, R], Grid.Cells[3, R], True, Code, Sort);
  end;
end;

function RunQueryWizard(AOwner: TComponent; ADb: TAppDb): string;
var
  W: TQWiz;
  T: TStringList;
  I: Integer;
  Col: TGridColumn;
  D: TaQbeDesign;
  Sql, Err, Name: string;

  procedure Lbl(const ACap: string; X, Y: Integer);
  begin
    with TLabel.Create(W.Form) do begin Parent := W.Form; Caption := ACap; SetBounds(X, Y, 300, 18); end;
  end;

begin
  Result := '';
  W := TQWiz.Create;
  W.Db := ADb;
  W.Form := TForm.CreateNew(AOwner);
  try
    W.Form.Caption := Tr('Query wizard');
    W.Form.SetBounds(0, 0, 980, 680);
    W.Form.Position := poOwnerFormCenter;
    Lbl(Tr('1. Tables and queries'), 12, 10);
    W.Tables := TCheckListBox.Create(W.Form); W.Tables.Parent := W.Form; W.Tables.SetBounds(12, 30, 230, 280);
    T := ADb.UserTables;
    try
      for I := 0 to T.Count - 1 do W.Tables.Items.Add(T[I]);
    finally
      T.Free;
    end;
    T := ADb.ListObjects('_sys_queries');
    try
      for I := 0 to T.Count - 1 do W.Tables.Items.Add(T[I]);
    finally
      T.Free;
    end;
    W.Tables.OnClickCheck := @W.TablesCheck;
    Lbl(Tr('2. Fields (select the ones you want)'), 256, 10);
    W.Fields := TCheckListBox.Create(W.Form); W.Fields.Parent := W.Form; W.Fields.SetBounds(256, 30, 280, 280);
    W.Fields.OnClickCheck := @W.FieldsCheck;
    Lbl(Tr('3. Query type'), 552, 10);
    W.ModeBox := TComboBox.Create(W.Form); W.ModeBox.Parent := W.Form; W.ModeBox.SetBounds(552, 30, 410, 26);
    W.ModeBox.Style := csDropDownList;
    W.ModeBox.Items.CommaText := TrCsv('"Detaljni (prikaži sve retke)","Zbirni (grupiraj i zbroji brojeve)"');
    W.ModeBox.ItemIndex := 0;
    W.ModeBox.OnChange := @W.ModeChange;
    with TLabel.Create(W.Form) do
    begin
      Parent := W.Form;
      Caption := Tr('The link between tables is taken from foreign keys. Criteria, order and more complex expressions ') +
        Tr('you can add it later in the query designer.');
      AutoSize := False;
      WordWrap := True;
      SetBounds(552, 66, 410, 60);
    end;
    with TButton.Create(W.Form) do begin Parent := W.Form; Caption := Tr('Add calculated field...'); SetBounds(552, 130, 240, 30); OnClick := @W.CalcClick; end;
    Lbl(Tr('4. What is done with each field'), 12, 322);
    W.Grid := TStringGrid.Create(W.Form);
    W.Grid.Parent := W.Form;
    W.Grid.SetBounds(12, 342, 950, 220);
    W.Grid.FixedCols := 0;
    W.Grid.Options := W.Grid.Options + [goEditing];
    W.Grid.Columns.Clear;
    Col := W.Grid.Columns.Add; Col.Title.Caption := Tr('Field / expression'); Col.Width := 380; Col.ReadOnly := True;
    Col := W.Grid.Columns.Add; Col.Title.Caption := Tr('Role'); Col.Width := 150; Col.ButtonStyle := cbsPickList;
    for I := 0 to High(RoleNames) do Col.PickList.Add(RoleNames[I]);
    Col := W.Grid.Columns.Add; Col.Title.Caption := Tr('Order'); Col.Width := 120; Col.ButtonStyle := cbsPickList;
    Col.PickList.Add(''); Col.PickList.Add('Uzlazno'); Col.PickList.Add('Silazno');
    Col := W.Grid.Columns.Add; Col.Title.Caption := Tr('Column name (optional)'); Col.Width := 260;
    W.Grid.RowCount := 1;
    Lbl(Tr('Query name:'), 12, 580);
    W.NameEdit := TEdit.Create(W.Form); W.NameEdit.Parent := W.Form; W.NameEdit.SetBounds(100, 576, 260, 26);
    W.OpenCk := TCheckBox.Create(W.Form); W.OpenCk.Parent := W.Form;
    W.OpenCk.Caption := Tr('Open in the designer after creating'); W.OpenCk.SetBounds(380, 578, 280, 22); W.OpenCk.Checked := True;
    with TButton.Create(W.Form) do begin Parent := W.Form; Caption := Tr('Create'); ModalResult := mrOk; SetBounds(770, 620, 100, 32); end;
    with TButton.Create(W.Form) do begin Parent := W.Form; Caption := Tr('Cancel'); ModalResult := mrCancel; SetBounds(876, 620, 86, 32); end;
    repeat
      if W.Form.ShowModal <> mrOk then Exit;
      Name := Trim(W.NameEdit.Text);
      if (Name = '') or (W.Grid.RowCount < 2) then
      begin
        ShowMessage(Tr('Choose tables, fields and enter a query name.'));
        Continue;
      end;
      if ADb.LoadObject('_sys_queries', Name) <> '' then
        if MessageDlg(Tr('The query already exists. Overwrite?'), mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Continue;
      D := W.Design;
      try
        if not BuildQbeSql(ADb, D, Sql, Err) then begin ShowMessage(Err); Continue; end;
        ADb.SaveObject('_sys_queries', Name, QbeSqlWithDesign(Sql, D));
      finally
        D.Free;
      end;
      Result := Name;
      Break;
    until False;
  finally
    W.Form.Free;
    W.Free;
  end;
end;

end.
