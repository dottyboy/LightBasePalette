unit ta_querydesign;
{ Query designer, Access style: pick tables, then fill a grid with one row per
  output column - field or calculated expression, name, show, total, sort,
  criteria and "or" criteria. The SQL is generated live; it can also be edited
  by hand. SELECTs open as a datasheet, anything else runs as an action query. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, ExtCtrls, StdCtrls, CheckLst, Grids, DBGrids, LCLType,
  DB, ZDataset, Graphics, ta_meta, ta_qbe, ta_calcdlg, ta_editor, ta_gridview, ta_family;

type

  { TaQueryDesigner }

  TaQueryDesigner = class(TForm)
  private
    FDb: TAppDb;
    FName: string;
    FTables: TCheckListBox;
    FFieldList: TListBox;
    FFieldKeys: TStringList;       { uz svaku stavku popisa: tablica.polje, ili prazno za naslov tablice }
    FFieldFilter: TEdit;
    FGrid: TStringGrid;
    FSql: TaEditor;
    FResultGrid: TaGridView;
    FSource: TDataSource;
    FResult: TZQuery;
    FJoin: TComboBox;
    FDistinct, FManual: TCheckBox;
    FTop: TEdit;
    FStatus: TLabel;
    FLoading: Boolean;
    procedure BuildUi;
    procedure ConfigureGrid;
    procedure RefreshChoices;
    procedure CheckedTables(AList: TStrings);
    procedure TablesCheck(Sender: TObject);
    procedure OptionChanged(Sender: TObject);
    procedure GridEdited(Sender: TObject);
    procedure GridPicked(Sender: TObject);
    procedure GridChecked(Sender: TObject; ACol, ARow: Integer; aState: TCheckboxState);
    procedure FieldDblClick(Sender: TObject);
    procedure GridResize(Sender: TObject);
    procedure FieldDrawItem(Control: TWinControl; Index: Integer; ARect: TRect; State: TOwnerDrawState);
    procedure FieldFilterChange(Sender: TObject);
    procedure FillFieldList(AChoices: TStrings);
    procedure AddKeyedItem(AIndex: Integer);
    procedure ManualToggle(Sender: TObject);
    procedure AddRowClick(Sender: TObject);
    procedure DelRowClick(Sender: TObject);
    procedure UpClick(Sender: TObject);
    procedure DownClick(Sender: TObject);
    procedure AllFieldsClick(Sender: TObject);
    procedure CalcClick(Sender: TObject);
    procedure RunClick(Sender: TObject);
    procedure SaveClick(Sender: TObject);
    procedure GenerateClick(Sender: TObject);
    procedure CloseResult;
    procedure AddGridRow(const AExpr, AAlias: string);
    procedure ClearRow(ARow: Integer);
    function RowEmpty(ARow: Integer): Boolean;
    function CollectDesign(AFallbackStar: Boolean): TaQbeDesign;
    procedure ApplyDesign(D: TaQbeDesign);
    procedure RegenSql;
    function GridHasColumns: Boolean;
  public
    constructor CreateDesigner(AOwner: TComponent; ADb: TAppDb; const AName: string);
    destructor Destroy; override;
    procedure RunQuery;
    procedure CheckTable(const AName: string);
    function GenerateSql: string;
    property Sql: TaEditor read FSql;
    function FieldListItems: TStrings;
    function FieldKeyAt(AIndex: Integer): string;
    procedure GridResizeForTest;
  end;

implementation

uses
  ta_i18n;


const
  TotalNames: array[0..8] of string = ('', 'Grupiraj', 'Zbroj', 'Prosjek', 'Broj', 'Min', 'Max', 'Izraz', 'Gdje');
  TotalCodes: array[0..8] of string = ('', 'group', 'sum', 'avg', 'count', 'min', 'max', 'expr', 'where');
  SortNames: array[0..2] of string = ('', 'Uzlazno', 'Silazno');
  SortCodes: array[0..2] of string = ('', 'asc', 'desc');
  StartRows = 10;

function NameToCode(const AName: string; const Names, Codes: array of string): string;
var
  I: Integer;
begin
  for I := 0 to High(Names) do
    if SameText(Names[I], AName) or SameText(Codes[I], AName) then Exit(Codes[I]);
  Result := '';
end;

function CodeToName(const ACode: string; const Names, Codes: array of string): string;
var
  I: Integer;
begin
  for I := 0 to High(Codes) do
    if SameText(Codes[I], ACode) then Exit(Names[I]);
  Result := '';
end;

constructor TaQueryDesigner.CreateDesigner(AOwner: TComponent; ADb: TAppDb; const AName: string);
var
  Saved: string;
  D: TaQbeDesign;
  P: Integer;
begin
  inherited CreateNew(AOwner);
  FDb := ADb;
  FName := AName;
  FFieldKeys := TStringList.Create;
  Caption := Tr('Query: ') + AName;
  SetBounds(0, 0, 1180, 760);
  Position := poScreenCenter;
  BuildUi;
  Saved := FDb.LoadObject('_sys_queries', AName);
  D := QbeDesignFromSql(Saved);
  FLoading := True;
  try
    if D <> nil then
    begin
      try
        ApplyDesign(D);
      finally
        D.Free;
      end;
      P := Pos('/*QBE', Saved);
      FSql.Text := Trim(Copy(Saved, 1, P - 1));
    end
    else if Trim(Saved) <> '' then
    begin
      { a query written as plain SQL stays plain until the grid is used }
      FManual.Checked := True;
      FSql.ReadOnly := False;
      FSql.Text := Saved;
    end;
  finally
    FLoading := False;
  end;
end;

destructor TaQueryDesigner.Destroy;
begin
  CloseResult;
  FFieldKeys.Free;
  inherited Destroy;
end;

procedure TaQueryDesigner.CloseResult;
begin
  if FSource <> nil then FSource.DataSet := nil;
  FreeAndNil(FResult);
end;

procedure TaQueryDesigner.BuildUi;
var
  Lf, Tp, Mid, Rt: TPanel;
  T: TStringList;
  Sp: TSplitter;
  I, X: Integer;

  procedure Btn(const ACap: string; AW: Integer; AH: TNotifyEvent);
  begin
    with TButton.Create(Self) do
    begin
      Parent := Tp;
      Caption := ACap;
      SetBounds(X, 6, AW, 26);
      OnClick := AH;
    end;
    Inc(X, AW + 4);
  end;

begin
  { left: tables and their fields }
  Lf := TPanel.Create(Self);
  Lf.Parent := Self;
  Lf.Align := alLeft;
  Lf.Width := 300;
  Lf.BevelOuter := bvNone;
  FFieldList := TListBox.Create(Self);
  FFieldList.Parent := Lf;
  FFieldList.Align := alClient;
  FFieldList.Style := lbOwnerDrawFixed;
  FFieldList.ItemHeight := 20;
  FFieldList.OnDrawItem := @FieldDrawItem;
  FFieldList.OnDblClick := @FieldDblClick;
  FFieldList.Hint := Tr('Double-clicking a field adds it to the query, double-clicking a table name adds all its fields.');
  FFieldList.ShowHint := True;
  FFieldFilter := TEdit.Create(Self);
  FFieldFilter.Parent := Lf;
  FFieldFilter.Align := alTop;
  FFieldFilter.Top := 160;
  FFieldFilter.TextHint := Tr('search field...');
  FFieldFilter.OnChange := @FieldFilterChange;
  FTables := TCheckListBox.Create(Self);
  FTables.Parent := Lf;
  FTables.Align := alTop;
  FTables.Top := 0;
  FTables.Height := 150;
  FTables.OnClickCheck := @TablesCheck;
  Sp := TSplitter.Create(Self);
  Sp.Parent := Lf;
  Sp.Align := alTop;
  Sp.Top := FTables.Height;
  T := FDb.UserTables;
  try
    for I := 0 to T.Count - 1 do FTables.Items.Add(T[I]);
  finally
    T.Free;
  end;
  T := FDb.ListObjects('_sys_queries');
  try
    for I := 0 to T.Count - 1 do
      if T[I] <> FName then FTables.Items.Add(T[I]);
  finally
    T.Free;
  end;
  Sp := TSplitter.Create(Self);
  Sp.Parent := Self;
  Sp.Align := alLeft;
  Sp.Left := Lf.Width;

  { desno: alatna traka, mreza upita, SQL i rezultat jedno ispod drugog }
  Rt := TPanel.Create(Self);
  Rt.Parent := Self;
  Rt.Align := alClient;
  Rt.BevelOuter := bvNone;

  { toolbar }
  Tp := TPanel.Create(Self);
  Tp.Parent := Rt;
  Tp.Align := alTop;
  Tp.Top := 0;
  Tp.Height := 70;
  Tp.BevelOuter := bvNone;
  X := 6;
  Btn(Tr('Run'), 80, @RunClick);
  Btn(Tr('Save'), 70, @SaveClick);
  Btn(Tr('Calculated field...'), 150, @CalcClick);
  Btn(Tr('Every field'), 80, @AllFieldsClick);
  Btn(Tr('+ row'), 70, @AddRowClick);
  Btn(Tr('Remove row'), 90, @DelRowClick);
  Btn(Tr('Up'), 56, @UpClick);
  Btn(Tr('Down'), 56, @DownClick);
  with TLabel.Create(Self) do begin Parent := Tp; Caption := Tr('Join:'); SetBounds(6, 44, 40, 18); end;
  FJoin := TComboBox.Create(Self);
  FJoin.Parent := Tp;
  FJoin.SetBounds(46, 40, 190, 26);
  FJoin.Style := csDropDownList;
  FJoin.Items.CommaText := TrCsv('"Samo povezani (INNER)","Svi iz prve tablice (LEFT)"');
  FJoin.ItemIndex := 0;
  FJoin.OnChange := @OptionChanged;
  FDistinct := TCheckBox.Create(Self);
  FDistinct.Parent := Tp;
  FDistinct.Caption := Tr('No duplicates');
  FDistinct.SetBounds(250, 42, 130, 22);
  FDistinct.OnChange := @OptionChanged;
  with TLabel.Create(Self) do begin Parent := Tp; Caption := Tr('Top n:'); SetBounds(392, 44, 60, 18); end;
  FTop := TEdit.Create(Self);
  FTop.Parent := Tp;
  FTop.SetBounds(454, 40, 60, 26);
  FTop.OnChange := @OptionChanged;
  FManual := TCheckBox.Create(Self);
  FManual.Parent := Tp;
  FManual.Caption := Tr('Edit SQL by hand');
  FManual.SetBounds(530, 42, 150, 22);
  FManual.OnChange := @ManualToggle;
  FStatus := TLabel.Create(Self);
  FStatus.Parent := Tp;
  FStatus.SetBounds(690, 44, 480, 18);
  FStatus.Font.Color := clMaroon;

  { design grid }
  FGrid := TStringGrid.Create(Self);
  FGrid.Parent := Rt;
  FGrid.Align := alTop;
  FGrid.Top := Tp.Height;
  FGrid.Height := 250;
  FGrid.DefaultRowHeight := 24;
  ConfigureGrid;
  FGrid.OnResize := @GridResize;
  Sp := TSplitter.Create(Self);
  Sp.Parent := Rt;
  Sp.Align := alTop;
  Sp.Top := Tp.Height + FGrid.Height;

  FSql := TaEditor.Create(Self);
  FSql.Parent := Rt;
  FSql.Variant := ewSql;
  FSql.Align := alTop;
  FSql.Top := Tp.Height + FGrid.Height + 6;
  FSql.Height := 110;
  FSql.ReadOnly := True;
  Sp := TSplitter.Create(Self);
  Sp.Parent := Rt;
  Sp.Align := alTop;
  Sp.Top := Tp.Height + FGrid.Height + FSql.Height + 12;

  FSource := TDataSource.Create(Self);
  FResultGrid := TaGridView.Create(Self, Rt, gkMain, PreferredProvider = 'own', False, FSource);
  Mid := nil;
end;

procedure TaQueryDesigner.ConfigureGrid;
var
  C: TGridColumn;
  I: Integer;
begin
  FGrid.FixedCols := 0;
  FGrid.FixedRows := 1;
  FGrid.Options := FGrid.Options + [goEditing, goRowSelect] - [goRowSelect];
  FGrid.Columns.Clear;
  C := FGrid.Columns.Add; C.Title.Caption := Tr('Field / expression'); C.Width := 330; C.ButtonStyle := cbsAuto;
  C := FGrid.Columns.Add; C.Title.Caption := Tr('Name'); C.Width := 140;
  C := FGrid.Columns.Add; C.Title.Caption := Tr('Show'); C.Width := 60; C.ButtonStyle := cbsCheckboxColumn;
  C.ValueChecked := '1'; C.ValueUnchecked := '0';
  C := FGrid.Columns.Add; C.Title.Caption := Tr('Sum'); C.Width := 90; C.ButtonStyle := cbsPickList;
  for I := 0 to High(TotalNames) do C.PickList.Add(TotalNames[I]);
  C := FGrid.Columns.Add; C.Title.Caption := Tr('Order'); C.Width := 90; C.ButtonStyle := cbsPickList;
  for I := 0 to High(SortNames) do C.PickList.Add(SortNames[I]);
  C := FGrid.Columns.Add; C.Title.Caption := Tr('Criteria'); C.Width := 140;
  C := FGrid.Columns.Add; C.Title.Caption := Tr('Or'); C.Width := 140;
  FGrid.RowCount := 1 + StartRows;
  for I := 1 to StartRows do ClearRow(I);
  FGrid.OnEditingDone := @GridEdited;
  FGrid.OnPickListSelect := @GridPicked;
  FGrid.OnCheckboxToggled := @GridChecked;
end;

procedure TaQueryDesigner.ClearRow(ARow: Integer);
var
  C: Integer;
begin
  for C := 0 to FGrid.ColCount - 1 do FGrid.Cells[C, ARow] := '';
  FGrid.Cells[2, ARow] := '1';
end;

function TaQueryDesigner.RowEmpty(ARow: Integer): Boolean;
begin
  Result := Trim(FGrid.Cells[0, ARow]) = '';
end;

function TaQueryDesigner.GridHasColumns: Boolean;
var
  I: Integer;
begin
  for I := 1 to FGrid.RowCount - 1 do
    if not RowEmpty(I) then Exit(True);
  Result := False;
end;

procedure TaQueryDesigner.AddGridRow(const AExpr, AAlias: string);
var
  I: Integer;
begin
  I := 1;
  while (I < FGrid.RowCount) and not RowEmpty(I) do Inc(I);
  if I >= FGrid.RowCount then
  begin
    FGrid.RowCount := FGrid.RowCount + 1;
    I := FGrid.RowCount - 1;
    ClearRow(I);
  end;
  FGrid.Cells[0, I] := AExpr;
  FGrid.Cells[1, I] := AAlias;
  FGrid.Cells[2, I] := '1';
end;

procedure TaQueryDesigner.CheckedTables(AList: TStrings);
var
  I: Integer;
begin
  AList.Clear;
  for I := 0 to FTables.Count - 1 do
    if FTables.Checked[I] then AList.Add(FTables.Items[I]);
end;

{ Popis polja: naslov svake tablice, pa samo nazivi polja (puno ime tablica.polje je u FFieldKeys). }
procedure TaQueryDesigner.FillFieldList(AChoices: TStrings);
var
  I, P: Integer;
  Cur, T, F, Needle: string;
begin
  Needle := LowerCase(Trim(FFieldFilter.Text));
  FFieldList.Items.BeginUpdate;
  try
    FFieldList.Items.Clear;
    FFieldKeys.Clear;
    Cur := '';
    for I := 0 to AChoices.Count - 1 do
    begin
      P := Pos('.', AChoices[I]);
      T := Copy(AChoices[I], 1, P - 1);
      F := Copy(AChoices[I], P + 1, MaxInt);
      if (Needle <> '') and (Pos(Needle, LowerCase(F)) = 0) then Continue;
      if T <> Cur then
      begin
        FFieldList.Items.Add(T);
        FFieldKeys.Add('');
        Cur := T;
      end;
      FFieldList.Items.Add(F);
      FFieldKeys.Add(AChoices[I]);
    end;
  finally
    FFieldList.Items.EndUpdate;
  end;
end;

procedure TaQueryDesigner.FieldDrawItem(Control: TWinControl; Index: Integer; ARect: TRect; State: TOwnerDrawState);
var
  Lb: TListBox;
  Hdr: Boolean;
begin
  Lb := TListBox(Control);
  Hdr := (Index < FFieldKeys.Count) and (FFieldKeys[Index] = '');
  with Lb.Canvas do
  begin
    if odSelected in State then
    begin
      Brush.Color := clHighlight;
      Font.Color := clHighlightText;
    end
    else if Hdr then
    begin
      Brush.Color := $F0E6D8;
      Font.Color := clNavy;
    end
    else
    begin
      Brush.Color := clWindow;
      Font.Color := clWindowText;
    end;
    if Hdr then Font.Style := [fsBold] else Font.Style := [];
    FillRect(ARect);
    if Hdr then TextOut(ARect.Left + 4, ARect.Top + 2, Lb.Items[Index])
    else TextOut(ARect.Left + 22, ARect.Top + 2, Lb.Items[Index]);
  end;
end;

{ Prvi stupac (polje / izraz) dobiva sav preostali prostor, da se nazivi polja vide. }
procedure TaQueryDesigner.GridResize(Sender: TObject);
var
  I, Sum: Integer;
begin
  if FGrid.Columns.Count < 7 then Exit;
  Sum := 0;
  for I := 1 to FGrid.Columns.Count - 1 do Inc(Sum, FGrid.Columns[I].Width);
  I := FGrid.ClientWidth - Sum - 40;
  if I < 260 then I := 260;
  FGrid.Columns[0].Width := I;
end;

procedure TaQueryDesigner.FieldFilterChange(Sender: TObject);
begin
  RefreshChoices;
end;

function TaQueryDesigner.FieldListItems: TStrings;
begin
  Result := FFieldList.Items;
end;

procedure TaQueryDesigner.GridResizeForTest;
begin
  GridResize(nil);
end;

function TaQueryDesigner.FieldKeyAt(AIndex: Integer): string;
begin
  if (AIndex >= 0) and (AIndex < FFieldKeys.Count) then Result := FFieldKeys[AIndex] else Result := '';
end;

procedure TaQueryDesigner.RefreshChoices;
var
  T, F: TStringList;
begin
  T := TStringList.Create;
  try
    CheckedTables(T);
    F := QbeFieldChoices(FDb, T);
    try
      FillFieldList(F);
      FGrid.Columns[0].PickList.Assign(F);
    finally
      F.Free;
    end;
  finally
    T.Free;
  end;
end;

procedure TaQueryDesigner.TablesCheck(Sender: TObject);
begin
  RefreshChoices;
  RegenSql;
end;

procedure TaQueryDesigner.OptionChanged(Sender: TObject);
begin
  RegenSql;
end;

procedure TaQueryDesigner.GridEdited(Sender: TObject);
begin
  RegenSql;
end;

procedure TaQueryDesigner.GridPicked(Sender: TObject);
begin
  RegenSql;
end;

procedure TaQueryDesigner.GridChecked(Sender: TObject; ACol, ARow: Integer; aState: TCheckboxState);
begin
  RegenSql;
end;

procedure TaQueryDesigner.AddKeyedItem(AIndex: Integer);
var
  J: Integer;
begin
  if (AIndex < 0) or (AIndex >= FFieldKeys.Count) then Exit;
  if FFieldKeys[AIndex] <> '' then
    AddGridRow(FFieldKeys[AIndex], '')
  else
  begin
    { naslov tablice: sva njezina polja }
    J := AIndex + 1;
    while (J < FFieldKeys.Count) and (FFieldKeys[J] <> '') do
    begin
      AddGridRow(FFieldKeys[J], '');
      Inc(J);
    end;
  end;
end;

procedure TaQueryDesigner.FieldDblClick(Sender: TObject);
begin
  AddKeyedItem(FFieldList.ItemIndex);
  RegenSql;
end;

procedure TaQueryDesigner.AllFieldsClick(Sender: TObject);
var
  I: Integer;
begin
  for I := 0 to FFieldKeys.Count - 1 do
    if FFieldKeys[I] <> '' then AddGridRow(FFieldKeys[I], '');
  RegenSql;
end;

procedure TaQueryDesigner.AddRowClick(Sender: TObject);
begin
  FGrid.RowCount := FGrid.RowCount + 1;
  ClearRow(FGrid.RowCount - 1);
end;

procedure TaQueryDesigner.DelRowClick(Sender: TObject);
var
  R, I, C: Integer;
begin
  R := FGrid.Row;
  if R < 1 then Exit;
  for I := R to FGrid.RowCount - 2 do
    for C := 0 to FGrid.ColCount - 1 do FGrid.Cells[C, I] := FGrid.Cells[C, I + 1];
  if FGrid.RowCount > 2 then FGrid.RowCount := FGrid.RowCount - 1 else ClearRow(1);
  RegenSql;
end;

procedure TaQueryDesigner.UpClick(Sender: TObject);
var
  R, C: Integer;
  T: string;
begin
  R := FGrid.Row;
  if R < 2 then Exit;
  for C := 0 to FGrid.ColCount - 1 do
  begin
    T := FGrid.Cells[C, R];
    FGrid.Cells[C, R] := FGrid.Cells[C, R - 1];
    FGrid.Cells[C, R - 1] := T;
  end;
  FGrid.Row := R - 1;
  RegenSql;
end;

procedure TaQueryDesigner.DownClick(Sender: TObject);
var
  R, C: Integer;
  T: string;
begin
  R := FGrid.Row;
  if (R < 1) or (R >= FGrid.RowCount - 1) then Exit;
  for C := 0 to FGrid.ColCount - 1 do
  begin
    T := FGrid.Cells[C, R];
    FGrid.Cells[C, R] := FGrid.Cells[C, R + 1];
    FGrid.Cells[C, R + 1] := T;
  end;
  FGrid.Row := R + 1;
  RegenSql;
end;

procedure TaQueryDesigner.CalcClick(Sender: TObject);
var
  T: TStringList;
  Alias, Expr: string;
begin
  T := TStringList.Create;
  try
    CheckedTables(T);
    if T.Count = 0 then begin ShowMessage(Tr('First select at least one table.')); Exit; end;
    if RunCalcWizard(Self, FDb, T, True, Alias, Expr) then
    begin
      AddGridRow(Expr, Alias);
      RegenSql;
    end;
  finally
    T.Free;
  end;
end;

{ ---------------- grid <-> design ---------------- }

function TaQueryDesigner.CollectDesign(AFallbackStar: Boolean): TaQbeDesign;
var
  I: Integer;
  C: Integer;
begin
  Result := TaQbeDesign.Create;
  CheckedTables(Result.Tables);
  if FJoin.ItemIndex = 1 then Result.JoinType := 'left' else Result.JoinType := 'inner';
  Result.Distinct := FDistinct.Checked;
  Result.Top := StrToIntDef(Trim(FTop.Text), 0);
  for I := 1 to FGrid.RowCount - 1 do
  begin
    if RowEmpty(I) then Continue;
    Result.AddColumn(Trim(FGrid.Cells[0, I]), Trim(FGrid.Cells[1, I]), FGrid.Cells[2, I] <> '0',
      NameToCode(FGrid.Cells[3, I], TotalNames, TotalCodes), NameToCode(FGrid.Cells[4, I], SortNames, SortCodes));
    C := High(Result.Cols);
    Result.Cols[C].Crit := Trim(FGrid.Cells[5, I]);
    Result.Cols[C].OrCrit := Trim(FGrid.Cells[6, I]);
  end;
  if AFallbackStar and (Length(Result.Cols) = 0) then Result.AddColumn('*', '');
end;

procedure TaQueryDesigner.ApplyDesign(D: TaQbeDesign);
var
  I, R, K: Integer;
begin
  FLoading := True;
  try
    for I := 0 to FTables.Count - 1 do FTables.Checked[I] := D.Tables.IndexOf(FTables.Items[I]) >= 0;
    if SameText(D.JoinType, 'left') then FJoin.ItemIndex := 1 else FJoin.ItemIndex := 0;
    FDistinct.Checked := D.Distinct;
    if D.Top > 0 then FTop.Text := IntToStr(D.Top) else FTop.Text := '';
    RefreshChoices;
    FGrid.RowCount := 1 + Length(D.Cols) + 3;
    for R := 1 to FGrid.RowCount - 1 do ClearRow(R);
    for K := 0 to High(D.Cols) do
    begin
      R := K + 1;
      FGrid.Cells[0, R] := D.Cols[K].Expr;
      FGrid.Cells[1, R] := D.Cols[K].Alias;
      if D.Cols[K].Show then FGrid.Cells[2, R] := '1' else FGrid.Cells[2, R] := '0';
      FGrid.Cells[3, R] := CodeToName(D.Cols[K].Total, TotalNames, TotalCodes);
      FGrid.Cells[4, R] := CodeToName(D.Cols[K].Sort, SortNames, SortCodes);
      FGrid.Cells[5, R] := D.Cols[K].Crit;
      FGrid.Cells[6, R] := D.Cols[K].OrCrit;
    end;
  finally
    FLoading := False;
  end;
end;

procedure TaQueryDesigner.RegenSql;
var
  D: TaQbeDesign;
  S, E: string;
begin
  if FLoading or FManual.Checked then Exit;
  if not GridHasColumns then
  begin
    FSql.Text := '';
    FStatus.Caption := '';
    Exit;
  end;
  D := CollectDesign(False);
  try
    if BuildQbeSql(FDb, D, S, E) then
    begin
      FSql.Text := S;
      FStatus.Caption := '';
    end
    else FStatus.Caption := E;
  finally
    D.Free;
  end;
end;

function TaQueryDesigner.GenerateSql: string;
var
  D: TaQbeDesign;
  E: string;
begin
  D := CollectDesign(True);
  try
    if not BuildQbeSql(FDb, D, Result, E) then
    begin
      FStatus.Caption := E;
      Result := '';
    end;
  finally
    D.Free;
  end;
end;

procedure TaQueryDesigner.GenerateClick(Sender: TObject);
begin
  FManual.Checked := False;
  RegenSql;
end;

procedure TaQueryDesigner.ManualToggle(Sender: TObject);
begin
  if FLoading then Exit;
  FSql.ReadOnly := not FManual.Checked;
  if not FManual.Checked then
  begin
    if GridHasColumns and (Trim(FSql.Text) <> '') then
      if MessageDlg(Tr('Returning to the grid design overwrites the SQL edited by hand. Continue?'),
        mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
      begin
        FLoading := True;
        FManual.Checked := True;
        FLoading := False;
        FSql.ReadOnly := False;
        Exit;
      end;
    RegenSql;
  end;
end;

procedure TaQueryDesigner.CheckTable(const AName: string);
var
  I: Integer;
begin
  I := FTables.Items.IndexOf(AName);
  if I >= 0 then FTables.Checked[I] := True;
  RefreshChoices;
end;

{ ---------------- run and save ---------------- }

procedure TaQueryDesigner.RunQuery;
var
  S: string;
begin
  CloseResult;
  if (not FManual.Checked) and GridHasColumns then RegenSql;
  S := Trim(FSql.Text);
  if S = '' then Exit;
  try
    if Pos('SELECT', UpperCase(S)) = 1 then
    begin
      FDb.ClearParams;
      FResult := FDb.NewQuery(FDb.ExpandParams(S));
      FResult.Open;
      FSource.DataSet := FResult;
    end
    else
    begin
      FDb.Conn.ExecuteDirect(S);
      ShowMessage(Tr('The query was run.'));
    end;
  except
    on E: Exception do
    begin
      CloseResult;
      ShowMessage(Tr('Error in the query: ') + E.Message);
    end;
  end;
end;

procedure TaQueryDesigner.RunClick(Sender: TObject);
begin
  RunQuery;
end;

procedure TaQueryDesigner.SaveClick(Sender: TObject);
var
  D: TaQbeDesign;
  Def: string;
begin
  if (not FManual.Checked) and GridHasColumns then
  begin
    RegenSql;
    D := CollectDesign(False);
    try
      Def := QbeSqlWithDesign(FSql.Text, D);
    finally
      D.Free;
    end;
  end
  else Def := Trim(FSql.Text);
  FDb.SaveObject('_sys_queries', FName, Def);
  Caption := Tr('Query: ') + FName + Tr(' (saved)');
end;

end.
