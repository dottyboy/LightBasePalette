unit ta_wizards;
{ Form wizard and report wizard dialogs. They collect the choices and hand
  them to the generators in ta_wizardgen; the result is saved and the caller
  usually opens it in the designer for fine tuning. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, ExtCtrls, StdCtrls, CheckLst,
  ta_meta, ta_formdef, ta_reportdef, ta_types, ta_wizardgen,
  ta_wizardframework, ta_wizardformgrid_dlg, ta_wizardfgl_dlg;

{ Returns the name of the saved object, or '' when cancelled. }
function RunFormWizard(AOwner: TComponent; ADb: TAppDb): string;
function RunReportWizard(AOwner: TComponent; ADb: TAppDb): string;
function RunMasterDetailWizard(AOwner: TComponent; ADb: TAppDb; out AReportName: string): string;

{ Universal Smart Wizard (Stage E7 / Block Wizard) }
function RunSmartWizard(AOwner: TComponent; ADb: TAppDb; const AInitialSource: string = ''): TaWizardResult;

implementation

uses
  ta_i18n;


type
  TWizard = class
  public
    Db: TAppDb;
    IsReport: Boolean;
    Form: TForm;
    Source, GroupBox, SortBox: TComboBox;
    Fields: TCheckListBox;
    NameEdit, TitleEdit: TEdit;
    TwoCols, Desc, Sums: TCheckBox;
    LayoutBox: TComboBox;
    SubList: TCheckListBox;
    ColsEdit: TEdit;
    PageCk: TCheckBox;
    LinesMemo: TMemo;
    InsertBox: TComboBox;
    procedure SourceChange(Sender: TObject);
    procedure AllClick(Sender: TObject);
    procedure NoneClick(Sender: TObject);
    procedure SetAll(AValue: Boolean);
    procedure InsertField(Sender: TObject);
    procedure LinesFromFields(Sender: TObject);
    function Checked: TStringList;
  end;

procedure TWizard.SetAll(AValue: Boolean);
var
  I: Integer;
begin
  for I := 0 to Fields.Count - 1 do Fields.Checked[I] := AValue;
end;

procedure TWizard.InsertField(Sender: TObject);
begin
  if (InsertBox <> nil) and (InsertBox.ItemIndex >= 0) then
  begin
    LinesMemo.SelText := '[' + InsertBox.Items[InsertBox.ItemIndex] + ']';
    LinesMemo.SetFocus;
  end;
end;

{ label lines start as one field per line; the user then joins them: [zip] & " " & [city] }
procedure TWizard.LinesFromFields(Sender: TObject);
var
  I, N: Integer;
begin
  LinesMemo.Lines.Clear;
  N := 0;
  for I := 0 to Fields.Count - 1 do
    if Fields.Checked[I] and (N < 5) then
    begin
      LinesMemo.Lines.Add('[' + Fields.Items[I] + ']');
      Inc(N);
    end;
end;

procedure TWizard.AllClick(Sender: TObject);
begin
  SetAll(True);
end;

procedure TWizard.NoneClick(Sender: TObject);
begin
  SetAll(False);
end;

function TWizard.Checked: TStringList;
var
  I: Integer;
begin
  Result := TStringList.Create;
  for I := 0 to Fields.Count - 1 do
    if Fields.Checked[I] then Result.Add(Fields.Items[I]);
end;

procedure TWizard.SourceChange(Sender: TObject);
var
  L: TaSourceFields;
  I: Integer;
  Rel: TStringList;
begin
  Fields.Items.Clear;
  if IsReport then
  begin
    GroupBox.Items.Clear;
    GroupBox.Items.Add('');
    SortBox.Items.Clear;
    SortBox.Items.Add('');
    InsertBox.Items.Clear;
  end;
  if Trim(Source.Text) = '' then Exit;
  try
    L := SourceFieldList(Db, Trim(Source.Text));
  except
    on E: Exception do begin ShowMessage(Tr('The source cannot be opened: ') + E.Message); Exit; end;
  end;
  for I := 0 to High(L) do
  begin
    Fields.Checked[Fields.Items.Add(L[I].Name)] := True;
    if IsReport then
    begin
      GroupBox.Items.Add(L[I].Name);
      SortBox.Items.Add(L[I].Name);
      InsertBox.Items.Add(L[I].Name);
    end;
  end;
  if (not IsReport) and (SubList <> nil) then
  begin
    SubList.Items.Clear;
    Rel := ChildRelations(Db, Trim(Source.Text));
    try
      for I := 0 to Rel.Count - 1 do
        SubList.Items.Add(Copy(Rel[I], 1, Pos('|', Rel[I]) - 1));
    finally
      Rel.Free;
    end;
  end;
  if NameEdit.Text = '' then NameEdit.Text := Trim(Source.Text);
  if IsReport and (TitleEdit.Text = '') then TitleEdit.Text := PrettyName(Trim(Source.Text));
  if IsReport and (LinesMemo <> nil) then LinesFromFields(nil);
end;

function Run(AOwner: TComponent; ADb: TAppDb; AIsReport: Boolean): string;
var
  W: TWizard;
  T: TStringList;
  I, Y: Integer;
  Sel: TStringList;
  Kind, N: string;
  FD: TaFormDef;
  RD: TaReportDef;
  FO: TaFormOptions;
  RO: TaReportOptions;
  Subs: TStringList;

  procedure Lbl(const ACap: string; X, Yy: Integer);
  var
    L: TLabel;
  begin
    L := TLabel.Create(W.Form);
    L.Parent := W.Form;
    L.Caption := ACap;
    L.SetBounds(X, Yy + 4, 100, 18);
  end;

begin
  Result := '';
  W := TWizard.Create;
  W.Db := ADb;
  W.IsReport := AIsReport;
  W.Form := TForm.CreateNew(AOwner);
  try
    if AIsReport then begin W.Form.Caption := Tr('Report wizard'); Kind := '_sys_reports'; end
    else begin W.Form.Caption := Tr('Form wizard'); Kind := '_sys_forms'; end;
    if AIsReport then W.Form.SetBounds(0, 0, 640, 760) else W.Form.SetBounds(0, 0, 640, 700);
    W.Form.Position := poOwnerFormCenter;
    Y := 12;
    Lbl(Tr('Source:'), 12, Y);
    W.Source := TComboBox.Create(W.Form);
    W.Source.Parent := W.Form;
    W.Source.SetBounds(120, Y, 300, 26);
    W.Source.Style := csDropDownList;
    T := ADb.UserTables;
    try
      for I := 0 to T.Count - 1 do W.Source.Items.Add(T[I]);
    finally
      T.Free;
    end;
    T := ADb.ListObjects('_sys_queries');
    try
      for I := 0 to T.Count - 1 do W.Source.Items.Add(T[I]);
    finally
      T.Free;
    end;
    Inc(Y, 38);
    Lbl(Tr('Fields:'), 12, Y);
    W.Fields := TCheckListBox.Create(W.Form);
    W.Fields.Parent := W.Form;
    W.Fields.SetBounds(120, Y, 300, 180);
    with TButton.Create(W.Form) do begin Parent := W.Form; Caption := Tr('All'); SetBounds(430, Y, 80, 26); OnClick := @W.AllClick; end;
    with TButton.Create(W.Form) do begin Parent := W.Form; Caption := Tr('None'); SetBounds(430, Y + 32, 80, 26); OnClick := @W.NoneClick; end;
    Inc(Y, 192);
    if AIsReport then
    begin
      Lbl(Tr('Kind:'), 12, Y);
      W.LayoutBox := TComboBox.Create(W.Form); W.LayoutBox.Parent := W.Form; W.LayoutBox.SetBounds(120, Y, 200, 26);
      W.LayoutBox.Style := csDropDownList;
      W.LayoutBox.Items.CommaText := TrCsv('"Tablično","Stupčasto (kartica)","Naljepnice","Sažetak (samo zbrojevi)"');
      W.LayoutBox.ItemIndex := 0;
      Lbl(Tr('labels per row:'), 330, Y);
      W.ColsEdit := TEdit.Create(W.Form); W.ColsEdit.Parent := W.Form; W.ColsEdit.SetBounds(460, Y - 4, 40, 26);
      W.ColsEdit.Text := '3';
      Inc(Y, 34);
      W.PageCk := TCheckBox.Create(W.Form); W.PageCk.Parent := W.Form;
      W.PageCk.Caption := Tr('One record per page (columns)'); W.PageCk.SetBounds(120, Y, 300, 22);
      Inc(Y, 30);
      Lbl(Tr('Label rows:'), 12, Y);
      W.LinesMemo := TMemo.Create(W.Form); W.LinesMemo.Parent := W.Form; W.LinesMemo.SetBounds(120, Y, 300, 96);
      W.InsertBox := TComboBox.Create(W.Form); W.InsertBox.Parent := W.Form; W.InsertBox.SetBounds(430, Y, 170, 26);
      W.InsertBox.Style := csDropDownList;
      with TButton.Create(W.Form) do begin Parent := W.Form; Caption := Tr('Insert field'); SetBounds(430, Y + 30, 170, 26); OnClick := @W.InsertField; end;
      with TButton.Create(W.Form) do begin Parent := W.Form; Caption := Tr('From the selected fields'); SetBounds(430, Y + 60, 230, 26); OnClick := @W.LinesFromFields; end;
      Inc(Y, 104);
      Lbl(Tr('Group by:'), 12, Y);
      W.GroupBox := TComboBox.Create(W.Form); W.GroupBox.Parent := W.Form; W.GroupBox.SetBounds(120, Y, 200, 26);
      W.GroupBox.Style := csDropDownList;
      Inc(Y, 34);
      Lbl(Tr('Sort by:'), 12, Y);
      W.SortBox := TComboBox.Create(W.Form); W.SortBox.Parent := W.Form; W.SortBox.SetBounds(120, Y, 200, 26);
      W.SortBox.Style := csDropDownList;
      W.Desc := TCheckBox.Create(W.Form); W.Desc.Parent := W.Form; W.Desc.Caption := Tr('descending');
      W.Desc.SetBounds(330, Y + 2, 100, 22);
      Inc(Y, 34);
      W.Sums := TCheckBox.Create(W.Form); W.Sums.Parent := W.Form; W.Sums.Caption := Tr('Totals for numeric fields');
      W.Sums.SetBounds(120, Y, 260, 22); W.Sums.Checked := True;
      Inc(Y, 30);
      Lbl(Tr('Title:'), 12, Y);
      W.TitleEdit := TEdit.Create(W.Form); W.TitleEdit.Parent := W.Form; W.TitleEdit.SetBounds(120, Y, 300, 26);
      Inc(Y, 34);
    end
    else
    begin
      Lbl(Tr('Layout:'), 12, Y);
      W.LayoutBox := TComboBox.Create(W.Form); W.LayoutBox.Parent := W.Form; W.LayoutBox.SetBounds(120, Y, 300, 26);
      W.LayoutBox.Style := csDropDownList;
      W.LayoutBox.Items.CommaText := TrCsv('"Jedan stupac","Dva stupca","Datasheet (tablica)","Split (zapis + tablica)"');
      W.LayoutBox.ItemIndex := 0;
      Inc(Y, 34);
      Lbl(Tr('Subforms:'), 12, Y);
      W.SubList := TCheckListBox.Create(W.Form); W.SubList.Parent := W.Form; W.SubList.SetBounds(120, Y, 300, 70);
      with TLabel.Create(W.Form) do begin Parent := W.Form; Caption := Tr('related tables'); SetBounds(430, Y + 4, 110, 18); end;
      Inc(Y, 80);
      Lbl(Tr('Title:'), 12, Y);
      W.TitleEdit := TEdit.Create(W.Form); W.TitleEdit.Parent := W.Form; W.TitleEdit.SetBounds(120, Y, 300, 26);
      Inc(Y, 34);
    end;
    Lbl(Tr('Name:'), 12, Y);
    W.NameEdit := TEdit.Create(W.Form); W.NameEdit.Parent := W.Form; W.NameEdit.SetBounds(120, Y, 300, 26);
    Inc(Y, 44);
    with TButton.Create(W.Form) do begin Parent := W.Form; Caption := Tr('Create'); ModalResult := mrOk; SetBounds(430, Y, 90, 28); end;
    with TButton.Create(W.Form) do begin Parent := W.Form; Caption := Tr('Cancel'); ModalResult := mrCancel; SetBounds(526, Y, 90, 28); end;
    W.Form.ClientHeight := Y + 44;
    W.Source.OnChange := @W.SourceChange;

    repeat
      if W.Form.ShowModal <> mrOk then Exit;
      N := Trim(W.NameEdit.Text);
      if (Trim(W.Source.Text) = '') or (N = '') then begin ShowMessage(Tr('Choose a source and enter a name.')); Continue; end;
      Sel := W.Checked;
      try
        if Sel.Count = 0 then begin ShowMessage(Tr('Select at least one field.')); Continue; end;
        if ADb.LoadObject(Kind, N) <> '' then
          if MessageDlg(Tr('It already exists. Overwrite?'), mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Continue;
        if AIsReport then
        begin
          FillChar(RO, SizeOf(RO), 0);
          RO.LabelLines := W.LinesMemo.Lines;
          RO.Source := Trim(W.Source.Text);
          RO.Name := N;
          RO.Title := Trim(W.TitleEdit.Text);
          RO.Fields := Sel;
          RO.GroupField := W.GroupBox.Text;
          RO.SortField := W.SortBox.Text;
          RO.Descending := W.Desc.Checked;
          RO.Sums := W.Sums.Checked;
          RO.Kind := TaReportKind(W.LayoutBox.ItemIndex);
          RO.PageBreakPerRecord := W.PageCk.Checked;
          RO.LabelColumns := StrToIntDef(W.ColsEdit.Text, 3);
          RD := BuildReportEx(ADb, RO);
          try
            ADb.SaveObject(Kind, N, RD.ToJson);
          finally
            RD.Free;
          end;
        end
        else
        begin
          FO.Source := Trim(W.Source.Text);
          FO.Name := N;
          FO.Title := Trim(W.TitleEdit.Text);
          FO.Fields := Sel;
          FO.Layout := TaFormLayout(W.LayoutBox.ItemIndex);
          Subs := TStringList.Create;
          try
            for I := 0 to W.SubList.Count - 1 do
              if W.SubList.Checked[I] then Subs.Add(W.SubList.Items[I]);
            FO.SubTables := Subs;
            FD := BuildFormEx(ADb, FO);
          finally
            Subs.Free;
          end;
          try
            ADb.SaveObject(Kind, N, FD.ToJson);
          finally
            FD.Free;
          end;
        end;
        Result := N;
      finally
        Sel.Free;
      end;
      Break;
    until False;
  finally
    W.Form.Free;
    W.Free;
  end;
end;

function RunFormWizard(AOwner: TComponent; ADb: TAppDb): string;
begin
  Result := Run(AOwner, ADb, False);
end;

function RunReportWizard(AOwner: TComponent; ADb: TAppDb): string;
begin
  Result := Run(AOwner, ADb, True);
end;

{ ---------------- master-detail wizard ---------------- }

type
  { what has been chosen for one detail table }
  TDetState = class
  public
    Columns, Checked: TStringList;
    SumField: string;
    constructor Create;
    destructor Destroy; override;
  end;

  TMDDlg = class
  public
    Db: TAppDb;
    Form: TForm;
    MasterBox, SumBox, LayoutBox, MakeBox: TComboBox;
    DetList: TCheckListBox;
    MFields, DFields: TCheckListBox;
    AsForm, CountCk: TCheckBox;
    NameEdit, TitleEdit: TEdit;
    States: TStringList;
    Cur: string;
    Loading: Boolean;
    destructor Destroy; override;
    procedure MasterChange(Sender: TObject);
    procedure DetClick(Sender: TObject);
    procedure FillChecks(AList: TCheckListBox; const ASource: string);
    procedure SaveCurrent;
    procedure ShowDetail(const AName: string);
    function StateOf(const AName: string): TDetState;
  end;

constructor TDetState.Create;
begin
  Columns := TStringList.Create;
  Checked := TStringList.Create;
end;

destructor TDetState.Destroy;
begin
  Columns.Free;
  Checked.Free;
  inherited Destroy;
end;

destructor TMDDlg.Destroy;
var
  I: Integer;
begin
  for I := 0 to States.Count - 1 do States.Objects[I].Free;
  States.Free;
  inherited Destroy;
end;

procedure TMDDlg.FillChecks(AList: TCheckListBox; const ASource: string);
var
  L: TaSourceFields;
  I: Integer;
begin
  AList.Items.Clear;
  if ASource = '' then Exit;
  try
    L := SourceFieldList(Db, ASource);
  except
    Exit;
  end;
  for I := 0 to High(L) do AList.Checked[AList.Items.Add(L[I].Name)] := True;
end;

function TMDDlg.StateOf(const AName: string): TDetState;
var
  I: Integer;
  L: TaSourceFields;
  K: Integer;
begin
  I := States.IndexOf(AName);
  if I >= 0 then Exit(TDetState(States.Objects[I]));
  Result := TDetState.Create;
  try
    L := SourceFieldList(Db, AName);
    for K := 0 to High(L) do
    begin
      Result.Columns.Add(L[K].Name);
      Result.Checked.Add(L[K].Name);
      if (Result.SumField = '') and (L[K].LType in [ltDecimal, ltCurrency]) then Result.SumField := L[K].Name;
    end;
  except
  end;
  States.AddObject(AName, Result);
end;

{ remember what is ticked for the detail that was on screen }
procedure TMDDlg.SaveCurrent;
var
  S: TDetState;
  I: Integer;
begin
  if Cur = '' then Exit;
  S := StateOf(Cur);
  S.Checked.Clear;
  for I := 0 to DFields.Count - 1 do
    if DFields.Checked[I] then S.Checked.Add(DFields.Items[I]);
  S.SumField := SumBox.Text;
end;

procedure TMDDlg.ShowDetail(const AName: string);
var
  S: TDetState;
  I: Integer;
  L: TaSourceFields;
begin
  Loading := True;
  try
    Cur := AName;
    DFields.Items.Clear;
    SumBox.Items.Clear;
    SumBox.Items.Add('');
    if AName = '' then Exit;
    S := StateOf(AName);
    for I := 0 to S.Columns.Count - 1 do
      DFields.Checked[DFields.Items.Add(S.Columns[I])] := S.Checked.IndexOf(S.Columns[I]) >= 0;
    try
      L := SourceFieldList(Db, AName);
      for I := 0 to High(L) do
        if L[I].LType in [ltInteger, ltDecimal, ltCurrency] then SumBox.Items.Add(L[I].Name);
    except
    end;
    SumBox.ItemIndex := SumBox.Items.IndexOf(S.SumField);
    if SumBox.ItemIndex < 0 then SumBox.ItemIndex := 0;
  finally
    Loading := False;
  end;
end;

procedure TMDDlg.DetClick(Sender: TObject);
begin
  if Loading then Exit;
  SaveCurrent;
  if DetList.ItemIndex >= 0 then ShowDetail(DetList.Items[DetList.ItemIndex]) else ShowDetail('');
end;

procedure TMDDlg.MasterChange(Sender: TObject);
var
  Rel: TStringList;
  I: Integer;
begin
  FillChecks(MFields, MasterBox.Text);
  { only tables that point at the master can be details }
  DetList.Items.Clear;
  Cur := '';
  Rel := ChildRelations(Db, MasterBox.Text);
  try
    for I := 0 to Rel.Count - 1 do
      DetList.Checked[DetList.Items.Add(Copy(Rel[I], 1, Pos('|', Rel[I]) - 1))] := I = 0;
  finally
    Rel.Free;
  end;
  if DetList.Items.Count > 0 then
  begin
    DetList.ItemIndex := 0;
    ShowDetail(DetList.Items[0]);
  end
  else ShowDetail('');
  if NameEdit.Text = '' then NameEdit.Text := MasterBox.Text + '_detalji_forma';
  if TitleEdit.Text = '' then TitleEdit.Text := PrettyName(MasterBox.Text);
end;

function RunMasterDetailWizard(AOwner: TComponent; ADb: TAppDb; out AReportName: string): string;
var
  D: TMDDlg;
  T: TStringList;
  I, N: Integer;
  M: TaMDMulti;
  MR: TaMDMultiResult;
  O: TaMDOptions;
  RR: TaMDReportResult;
  MF: TStringList;
  Name: string;
  DoForm, DoReport: Boolean;
  St: TDetState;
  Keep: TList;
  Children: TStringList;
  RepDef: TaReportDef;
  RepErr: string;

  procedure Lbl(const ACap: string; X, Y: Integer);
  begin
    with TLabel.Create(D.Form) do begin Parent := D.Form; Caption := ACap; SetBounds(X, Y, 260, 18); end;
  end;

begin
  Result := '';
  AReportName := '';
  D := TMDDlg.Create;
  D.Db := ADb;
  D.States := TStringList.Create;
  D.Form := TForm.CreateNew(AOwner);
  Keep := TList.Create;
  try
    D.Form.Caption := Tr('Master-detail wizard');
    D.Form.SetBounds(0, 0, 900, 700);
    D.Form.Position := poOwnerFormCenter;
    Lbl(Tr('Master (parent table):'), 14, 10);
    D.MasterBox := TComboBox.Create(D.Form); D.MasterBox.Parent := D.Form; D.MasterBox.SetBounds(14, 30, 250, 26);
    D.MasterBox.Style := csDropDownList;
    T := ADb.UserTables;
    try
      for I := 0 to T.Count - 1 do D.MasterBox.Items.Add(T[I]);
    finally
      T.Free;
    end;
    Lbl(Tr('Fields of the master record:'), 14, 66);
    D.MFields := TCheckListBox.Create(D.Form); D.MFields.Parent := D.Form; D.MFields.SetBounds(14, 86, 250, 200);
    Lbl(Tr('Detail tables (select which)'), 284, 10);
    D.DetList := TCheckListBox.Create(D.Form); D.DetList.Parent := D.Form; D.DetList.SetBounds(284, 30, 250, 256);
    D.DetList.OnClick := @D.DetClick;
    Lbl(Tr('Columns in the subform for the selected table'), 554, 10);
    D.DFields := TCheckListBox.Create(D.Form); D.DFields.Parent := D.Form; D.DFields.SetBounds(554, 30, 330, 200);
    Lbl(Tr('Sum field:'), 554, 240);
    D.SumBox := TComboBox.Create(D.Form); D.SumBox.Parent := D.Form; D.SumBox.SetBounds(640, 236, 244, 26);
    D.SumBox.Style := csDropDownList;
    D.CountCk := TCheckBox.Create(D.Form); D.CountCk.Parent := D.Form;
    D.CountCk.Caption := Tr('Show the number of items'); D.CountCk.SetBounds(554, 266, 250, 22); D.CountCk.Checked := True;
    Lbl(Tr('Details layout:'), 14, 306);
    D.LayoutBox := TComboBox.Create(D.Form); D.LayoutBox.Parent := D.Form; D.LayoutBox.SetBounds(140, 302, 250, 26);
    D.LayoutBox.Style := csDropDownList;
    D.LayoutBox.Items.CommaText := TrCsv('"Jedna ispod druge","Kartice (tabovi)"');
    D.LayoutBox.ItemIndex := 0;
    D.AsForm := TCheckBox.Create(D.Form); D.AsForm.Parent := D.Form;
    D.AsForm.Caption := Tr('Details as a separate form (datasheet with field formats)');
    D.AsForm.SetBounds(14, 340, 500, 22); D.AsForm.Checked := True;
    Lbl(Tr('Create:'), 14, 384);
    D.MakeBox := TComboBox.Create(D.Form); D.MakeBox.Parent := D.Form; D.MakeBox.SetBounds(70, 380, 220, 26);
    D.MakeBox.Style := csDropDownList;
    D.MakeBox.Items.CommaText := TrCsv('"Formu","Izvješće (prva označena tablica)","Formu i izvješće"');
    D.MakeBox.ItemIndex := 0;
    Lbl(Tr('Name:'), 14, 424);
    D.NameEdit := TEdit.Create(D.Form); D.NameEdit.Parent := D.Form; D.NameEdit.SetBounds(14, 444, 330, 26);
    Lbl(Tr('Title:'), 364, 424);
    D.TitleEdit := TEdit.Create(D.Form); D.TitleEdit.Parent := D.Form; D.TitleEdit.SetBounds(364, 444, 330, 26);
    with TLabel.Create(D.Form) do
    begin
      Parent := D.Form;
      Caption := Tr('The link is taken from the foreign key (Application -> Relations). For each selected table ') +
        Tr('you can choose the columns and the field that is summed; the sum and the item count follow the current master record.');
      WordWrap := True;
      SetBounds(14, 490, 860, 44);
    end;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Create'); ModalResult := mrOk; SetBounds(690, 620, 90, 30); end;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Cancel'); ModalResult := mrCancel; SetBounds(786, 620, 90, 30); end;
    D.MasterBox.OnChange := @D.MasterChange;
    repeat
      if D.Form.ShowModal <> mrOk then Exit;
      D.SaveCurrent;
      Name := Trim(D.NameEdit.Text);
      N := 0;
      for I := 0 to D.DetList.Count - 1 do if D.DetList.Checked[I] then Inc(N);
      if (D.MasterBox.Text = '') or (N = 0) or (Name = '') then
      begin
        ShowMessage(Tr('Choose a master, select at least one detail table and enter a name.'));
        Continue;
      end;
      MF := TStringList.Create;
      Keep.Add(MF);
      try
        for I := 0 to D.MFields.Count - 1 do if D.MFields.Checked[I] then MF.Add(D.MFields.Items[I]);
        M.Master := D.MasterBox.Text;
        M.Name := Name;
        M.Title := Trim(D.TitleEdit.Text);
        M.MasterFields := MF;
        M.DetailAsForm := D.AsForm.Checked;
        M.UseTabs := D.LayoutBox.ItemIndex = 1;
        SetLength(M.Details, 0);
        for I := 0 to D.DetList.Count - 1 do
          if D.DetList.Checked[I] then
          begin
            St := D.StateOf(D.DetList.Items[I]);
            SetLength(M.Details, Length(M.Details) + 1);
            M.Details[High(M.Details)].Table := D.DetList.Items[I];
            M.Details[High(M.Details)].Fields := St.Checked;
            M.Details[High(M.Details)].SumField := St.SumField;
            M.Details[High(M.Details)].ShowCount := D.CountCk.Checked;
            M.Details[High(M.Details)].FkCol := '';
            M.Details[High(M.Details)].ParentCol := '';
          end;
        DoForm := D.MakeBox.ItemIndex in [0, 2];
        DoReport := D.MakeBox.ItemIndex in [1, 2];
        if DoForm then
        begin
          MR := BuildMasterDetailMulti(ADb, M);
          if MR.Error <> '' then begin ShowMessage(MR.Error); Continue; end;
          try
            for I := 0 to High(MR.Items) do
            begin
              if MR.Items[I].QueryName <> '' then ADb.SaveObject('_sys_queries', MR.Items[I].QueryName, MR.Items[I].QuerySql);
              if MR.Items[I].Form <> nil then ADb.SaveObject('_sys_forms', MR.Items[I].FormName, MR.Items[I].Form.ToJson);
            end;
            ADb.SaveObject('_sys_forms', Name, MR.MasterForm.ToJson);
          finally
            MR.MasterForm.Free;
            for I := 0 to High(MR.Items) do MR.Items[I].Form.Free;
          end;
          Result := Name;
        end;
        if DoReport and (Length(M.Details) > 1) then
        begin
          { vise detail tablica: svaka je podizvjesce ispod zapisa mastera }
          Children := TStringList.Create;
          try
            RepDef := BuildMasterDetailReportMulti(ADb, M, False, Children, RepErr);
            if RepErr <> '' then begin ShowMessage(RepErr); Continue; end;
            for I := 0 to Children.Count - 1 do
              ADb.SaveObject('_sys_reports', Children[I], TaReportDef(Children.Objects[I]).ToJson);
            if DoForm then RepDef.Name := Name + '_izvjesce' else RepDef.Name := Name;
            ADb.SaveObject('_sys_reports', RepDef.Name, RepDef.ToJson);
            AReportName := RepDef.Name;
          finally
            for I := 0 to Children.Count - 1 do Children.Objects[I].Free;
            Children.Free;
            RepDef.Free;
          end;
        end
        else if DoReport then
        begin
          { the report covers the master and its first ticked detail }
          O.Master := M.Master;
          O.Detail := M.Details[0].Table;
          O.Name := M.Name;
          if DoForm then O.Name := Name + '_izvjesce';
          O.Title := M.Title;
          O.MasterFields := MF;
          O.DetailFields := M.Details[0].Fields;
          O.DetailAsForm := False;
          O.SumField := M.Details[0].SumField;
          O.ShowCount := True;
          O.FkCol := '';
          O.ParentCol := '';
          RR := BuildMasterDetailReport(ADb, O);
          if RR.Error <> '' then begin ShowMessage(RR.Error); Continue; end;
          try
            ADb.SaveObject('_sys_queries', RR.QueryName, RR.QuerySql);
            ADb.SaveObject('_sys_reports', O.Name, RR.Def.ToJson);
          finally
            RR.Def.Free;
          end;
          AReportName := O.Name;
        end;
      finally
        { lists referenced by M are no longer needed }
      end;
      Break;
    until False;
  finally
    for I := 0 to Keep.Count - 1 do TObject(Keep[I]).Free;
    Keep.Free;
    D.Form.Free;
    D.Free;
  end;
end;

{ --------------------------------------------------------------------------- }
{ TfrmSmartWizard                                                             }
{ --------------------------------------------------------------------------- }

type
  TfrmSmartWizard = class(TForm)
  private
    FEngine: TaSmartWizardEngine;
    FDb: TAppDb;
    FPnlHeader: TPanel;
    FLblStepTitle: TLabel;
    FLblStepDesc: TLabel;
    FPnlContent: TPanel;
    FPnlNav: TPanel;
    FBtnBack, FBtnNext, FBtnFinish, FBtnCancel: TButton;

    { Step 0: Source }
    FPnlSource: TPanel;
    FCbSource: TComboBox;
    FLbFields: TListBox;

    { Step 1: Title }
    FPnlTitle: TPanel;
    FEdTitle: TEdit;

    { Step 2: Solution }
    FPnlSolutions: TPanel;
    FLbSolutions: TListBox;
    FMemoSolDesc: TMemo;

    { Step 3: Fields / Customization }
    FPnlFieldsHolder: TPanel;
    FFilterPanel: TaWizardFormGridPanel;
    FFglPanel: TaWizardFglPanel;
    FFieldsCheckList: TCheckListBox;

    { Step 4: Result }
    FPnlResult: TPanel;
    FEdSaveName: TEdit;
    FMemoResult: TMemo;
    FCkSaveDb: TCheckBox;

    procedure SourceChange(Sender: TObject);
    procedure TitleChange(Sender: TObject);
    procedure SolutionSelect(Sender: TObject);
    procedure QuickTitleClick(Sender: TObject);
    procedure BtnBackClick(Sender: TObject);
    procedure BtnNextClick(Sender: TObject);
    procedure BtnFinishClick(Sender: TObject);
    procedure UpdateStepUI;
    procedure PopulateFieldsList;
  public
    property Engine: TaSmartWizardEngine read FEngine;
    constructor CreateWizard(AOwner: TComponent; ADb: TAppDb; const AInitialSource: string);
    destructor Destroy; override;
  end;

constructor TfrmSmartWizard.CreateWizard(AOwner: TComponent; ADb: TAppDb; const AInitialSource: string);
var
  Tbls, Qrys: TStringList;
  I: Integer;
  BtnQ: TButton;
  Lb1, Lb2: TLabel;
begin
  inherited CreateNew(AOwner);
  Caption := Tr('Smart wizard (forms / reports / 4GL)');
  SetBounds(0, 0, 640, 480);
  Position := poScreenCenter;
  BorderIcons := [biSystemMenu];

  FDb := ADb;
  FEngine := TaSmartWizardEngine.Create(ADb, AInitialSource);
  FEngine.AddStep(TaDataSourceStep.Create);
  FEngine.AddStep(TaTitleStep.Create);
  FEngine.AddStep(TaSolutionStep.Create);
  FEngine.AddStep(TaFieldStep.Create);
  FEngine.AddStep(TaResultStep.Create);

  { Header panel }
  FPnlHeader := TPanel.Create(Self);
  FPnlHeader.Parent := Self;
  FPnlHeader.Align := alTop;
  FPnlHeader.Height := 54;
  FPnlHeader.BevelOuter := bvNone;

  FLblStepTitle := TLabel.Create(FPnlHeader);
  FLblStepTitle.Parent := FPnlHeader;
  FLblStepTitle.SetBounds(16, 8, 600, 20);
  FLblStepTitle.Font.Bold := True;
  FLblStepTitle.Font.Size := 11;

  FLblStepDesc := TLabel.Create(FPnlHeader);
  FLblStepDesc.Parent := FPnlHeader;
  FLblStepDesc.SetBounds(16, 30, 600, 18);

  { Nav panel }
  FPnlNav := TPanel.Create(Self);
  FPnlNav.Parent := Self;
  FPnlNav.Align := alBottom;
  FPnlNav.Height := 48;
  FPnlNav.BevelOuter := bvNone;

  FBtnCancel := TButton.Create(FPnlNav);
  FBtnCancel.Parent := FPnlNav;
  FBtnCancel.SetBounds(16, 10, 85, 28);
  FBtnCancel.Caption := Tr('Cancel');
  FBtnCancel.ModalResult := mrCancel;

  FBtnBack := TButton.Create(FPnlNav);
  FBtnBack.Parent := FPnlNav;
  FBtnBack.SetBounds(340, 10, 85, 28);
  FBtnBack.Caption := Tr('< Back');
  FBtnBack.OnClick := @BtnBackClick;

  FBtnNext := TButton.Create(FPnlNav);
  FBtnNext.Parent := FPnlNav;
  FBtnNext.SetBounds(435, 10, 85, 28);
  FBtnNext.Caption := Tr('Next >');
  FBtnNext.OnClick := @BtnNextClick;

  FBtnFinish := TButton.Create(FPnlNav);
  FBtnFinish.Parent := FPnlNav;
  FBtnFinish.SetBounds(530, 10, 90, 28);
  FBtnFinish.Caption := Tr('Finish');
  FBtnFinish.OnClick := @BtnFinishClick;

  { Content panel }
  FPnlContent := TPanel.Create(Self);
  FPnlContent.Parent := Self;
  FPnlContent.Align := alClient;
  FPnlContent.BevelOuter := bvNone;

  { Page 0: Source }
  FPnlSource := TPanel.Create(FPnlContent);
  FPnlSource.Parent := FPnlContent;
  FPnlSource.Align := alClient;
  FPnlSource.BevelOuter := bvNone;

  Lb1 := TLabel.Create(FPnlSource);
  Lb1.Parent := FPnlSource;
  Lb1.SetBounds(16, 12, 400, 18);
  Lb1.Caption := Tr('Choose a table or a query as the data source:');

  FCbSource := TComboBox.Create(FPnlSource);
  FCbSource.Parent := FPnlSource;
  FCbSource.SetBounds(16, 32, 590, 24);
  FCbSource.Style := csDropDownList;
  FCbSource.OnChange := @SourceChange;

  Lb2 := TLabel.Create(FPnlSource);
  Lb2.Parent := FPnlSource;
  Lb2.SetBounds(16, 70, 400, 18);
  Lb2.Caption := Tr('Fields and types in the selected source:');

  FLbFields := TListBox.Create(FPnlSource);
  FLbFields.Parent := FPnlSource;
  FLbFields.SetBounds(16, 92, 590, 270);

  if FDb <> nil then
  begin
    Tbls := FDb.UserTables;
    try
      for I := 0 to Tbls.Count - 1 do FCbSource.Items.Add(Tbls[I]);
    finally
      Tbls.Free;
    end;
    Qrys := FDb.ListObjects('_sys_queries');
    try
      for I := 0 to Qrys.Count - 1 do FCbSource.Items.Add('query:' + Qrys[I]);
    finally
      Qrys.Free;
    end;
  end;

  { Page 1: Title & Intent }
  FPnlTitle := TPanel.Create(FPnlContent);
  FPnlTitle.Parent := FPnlContent;
  FPnlTitle.Align := alClient;
  FPnlTitle.BevelOuter := bvNone;

  Lb1 := TLabel.Create(FPnlTitle);
  Lb1.Parent := FPnlTitle;
  Lb1.SetBounds(16, 12, 500, 18);
  Lb1.Caption := Tr('Enter a title or describe what you want to create:');

  FEdTitle := TEdit.Create(FPnlTitle);
  FEdTitle.Parent := FPnlTitle;
  FEdTitle.SetBounds(16, 34, 590, 26);
  FEdTitle.OnChange := @TitleChange;

  Lb2 := TLabel.Create(FPnlTitle);
  Lb2.Parent := FPnlTitle;
  Lb2.SetBounds(16, 80, 500, 18);
  Lb2.Caption := Tr('Or choose one of the usual templates:');

  BtnQ := TButton.Create(FPnlTitle);
  BtnQ.Parent := FPnlTitle;
  BtnQ.SetBounds(16, 105, 180, 28);
  BtnQ.Caption := Tr('List with a quick filter');
  BtnQ.Tag := 1;
  BtnQ.OnClick := @QuickTitleClick;

  BtnQ := TButton.Create(FPnlTitle);
  BtnQ.Parent := FPnlTitle;
  BtnQ.SetBounds(206, 105, 180, 28);
  BtnQ.Caption := Tr('Record entry form');
  BtnQ.Tag := 2;
  BtnQ.OnClick := @QuickTitleClick;

  BtnQ := TButton.Create(FPnlTitle);
  BtnQ.Parent := FPnlTitle;
  BtnQ.SetBounds(396, 105, 180, 28);
  BtnQ.Caption := Tr('Monthly report');
  BtnQ.Tag := 3;
  BtnQ.OnClick := @QuickTitleClick;

  { Page 2: Solutions }
  FPnlSolutions := TPanel.Create(FPnlContent);
  FPnlSolutions.Parent := FPnlContent;
  FPnlSolutions.Align := alClient;
  FPnlSolutions.BevelOuter := bvNone;

  Lb1 := TLabel.Create(FPnlSolutions);
  Lb1.Parent := FPnlSolutions;
  Lb1.SetBounds(16, 12, 500, 18);
  Lb1.Caption := Tr('Suggested solutions ranked by confidence (Confidence 0-100):');

  FLbSolutions := TListBox.Create(FPnlSolutions);
  FLbSolutions.Parent := FPnlSolutions;
  FLbSolutions.SetBounds(16, 34, 590, 160);
  FLbSolutions.OnClick := @SolutionSelect;

  Lb2 := TLabel.Create(FPnlSolutions);
  Lb2.Parent := FPnlSolutions;
  Lb2.SetBounds(16, 204, 500, 18);
  Lb2.Caption := Tr('Description of the selected solution:');

  FMemoSolDesc := TMemo.Create(FPnlSolutions);
  FMemoSolDesc.Parent := FPnlSolutions;
  FMemoSolDesc.SetBounds(16, 224, 590, 130);
  FMemoSolDesc.ReadOnly := True;

  { Page 3: Customization }
  FPnlFieldsHolder := TPanel.Create(FPnlContent);
  FPnlFieldsHolder.Parent := FPnlContent;
  FPnlFieldsHolder.Align := alClient;
  FPnlFieldsHolder.BevelOuter := bvNone;

  FFilterPanel := TaWizardFormGridPanel.Create(FPnlFieldsHolder);
  FFilterPanel.Parent := FPnlFieldsHolder;
  FFilterPanel.Align := alClient;

  FFglPanel := TaWizardFglPanel.Create(FPnlFieldsHolder);
  FFglPanel.Parent := FPnlFieldsHolder;
  FFglPanel.Align := alClient;

  FFieldsCheckList := TCheckListBox.Create(FPnlFieldsHolder);
  FFieldsCheckList.Parent := FPnlFieldsHolder;
  FFieldsCheckList.Align := alClient;

  { Page 4: Result }
  FPnlResult := TPanel.Create(FPnlContent);
  FPnlResult.Parent := FPnlContent;
  FPnlResult.Align := alClient;
  FPnlResult.BevelOuter := bvNone;

  Lb1 := TLabel.Create(FPnlResult);
  Lb1.Parent := FPnlResult;
  Lb1.SetBounds(16, 12, 100, 18);
  Lb1.Caption := Tr('Object name:');

  FEdSaveName := TEdit.Create(FPnlResult);
  FEdSaveName.Parent := FPnlResult;
  FEdSaveName.SetBounds(120, 8, 300, 24);

  FCkSaveDb := TCheckBox.Create(FPnlResult);
  FCkSaveDb.Parent := FPnlResult;
  FCkSaveDb.SetBounds(435, 10, 170, 20);
  FCkSaveDb.Caption := Tr('Save into the database');
  FCkSaveDb.Checked := True;

  FMemoResult := TMemo.Create(FPnlResult);
  FMemoResult.Parent := FPnlResult;
  FMemoResult.SetBounds(16, 40, 590, 320);
  FMemoResult.ReadOnly := True;
  FMemoResult.ScrollBars := ssBoth;
  FMemoResult.Font.Name := 'Courier New';
  FMemoResult.Font.Size := 9;

  if AInitialSource <> '' then
  begin
    FCbSource.Text := AInitialSource;
    SourceChange(nil);
  end;

  UpdateStepUI;
end;

destructor TfrmSmartWizard.Destroy;
begin
  FEngine.Free;
  inherited Destroy;
end;

procedure TfrmSmartWizard.SourceChange(Sender: TObject);
var
  Src: string;
  All: TaSourceFields;
  I: Integer;
begin
  Src := Trim(FCbSource.Text);
  FEngine.Ctx^.DataSource := Src;
  FLbFields.Items.Clear;
  if (FDb <> nil) and (Src <> '') then
  begin
    All := SourceFieldList(FDb, Src);
    for I := 0 to High(All) do
      FLbFields.Items.Add(Format('%s (%s)', [All[I].Name, CaptionOf(All[I])]));
  end;
  if FEdTitle.Text = '' then
    FEdTitle.Text := 'Pregled ' + PrettyName(Src);
  UpdateStepUI;
end;

procedure TfrmSmartWizard.TitleChange(Sender: TObject);
begin
  FEngine.Ctx^.Title := Trim(FEdTitle.Text);
  UpdateStepUI;
end;

procedure TfrmSmartWizard.QuickTitleClick(Sender: TObject);
var
  Src: string;
begin
  Src := PrettyName(FCbSource.Text);
  if Src = '' then Src := 'podataka';
  case TButton(Sender).Tag of
    1: FEdTitle.Text := 'Popis ' + Src + ' s filterom';
    2: FEdTitle.Text := 'Unos novog ' + Src;
    3: FEdTitle.Text := Tr('Monthly report ') + Src;
  end;
end;

procedure TfrmSmartWizard.PopulateFieldsList;
var
  All: TaSourceFields;
  I: Integer;
begin
  FFieldsCheckList.Items.Clear;
  if (FDb <> nil) and (FEngine.Ctx^.DataSource <> '') then
  begin
    All := SourceFieldList(FDb, FEngine.Ctx^.DataSource);
    for I := 0 to High(All) do
    begin
      FFieldsCheckList.Items.Add(All[I].Name);
      FFieldsCheckList.Checked[I] := True;
    end;
  end;
end;

procedure TfrmSmartWizard.SolutionSelect(Sender: TObject);
var
  Idx: Integer;
begin
  Idx := FLbSolutions.ItemIndex;
  if (Idx >= 0) and (Idx < Length(FEngine.Ctx^.Solutions)) then
  begin
    FEngine.Ctx^.SelectedSolution := FEngine.Ctx^.Solutions[Idx].SolutionId;
    FMemoSolDesc.Text := FEngine.Ctx^.Solutions[Idx].Description;
  end;
  UpdateStepUI;
end;

procedure TfrmSmartWizard.UpdateStepUI;
var
  Idx: Integer;
  Sols: TaWizardSolutions;
  I: Integer;
  FieldsCtx: TaSourceFields;
begin
  Idx := FEngine.CurrentIndex;
  FLblStepTitle.Caption := Format(Tr('Step %d of %d: %s'), [Idx + 1, FEngine.StepCount, FEngine.CurrentStep.Title]);
  FLblStepDesc.Caption := FEngine.CurrentStep.Description;

  FPnlSource.Visible := (Idx = 0);
  FPnlTitle.Visible := (Idx = 1);
  FPnlSolutions.Visible := (Idx = 2);
  FPnlFieldsHolder.Visible := (Idx = 3);
  FPnlResult.Visible := (Idx = 4);

  if Idx = 2 then
  begin
    FieldsCtx := SourceFieldList(FDb, FEngine.Ctx^.DataSource);
    Sols := SuggestSolutions(FDb, FEngine.Ctx^.DataSource, FEngine.Ctx^.Title, FieldsCtx);
    FEngine.Ctx^.Solutions := Sols;
    FLbSolutions.Items.Clear;
    for I := 0 to High(Sols) do
      FLbSolutions.Items.Add(Format('[%d%%] %s', [Sols[I].Confidence, Sols[I].Title]));

    if (FLbSolutions.Count > 0) and (FLbSolutions.ItemIndex < 0) then
    begin
      FLbSolutions.ItemIndex := 0;
      SolutionSelect(nil);
    end;
  end
  else if Idx = 3 then
  begin
    FFilterPanel.Visible := False;
    FFglPanel.Visible := False;
    FFieldsCheckList.Visible := False;

    if FEngine.Ctx^.SelectedSolution = 'formgrid-filter' then
    begin
      FFilterPanel.Visible := True;
      FFilterPanel.LoadFromContext(FEngine.Ctx^);
    end
    else if Pos('fgl-', FEngine.Ctx^.SelectedSolution) = 1 then
    begin
      FFglPanel.Visible := True;
      FFglPanel.LoadFromContext(FEngine.Ctx^);
    end
    else
    begin
      FFieldsCheckList.Visible := True;
    end;
  end
  else if Idx = 4 then
  begin
    FEngine.ExecuteCurrent;
    case FEngine.Ctx^.Result.Kind of
      wrkForm:
        if FEngine.Ctx^.Result.FormDef <> nil then
          FMemoResult.Text := FEngine.Ctx^.Result.FormDef.ToJson;
      wrkReport:
        if FEngine.Ctx^.Result.ReportDef <> nil then
          FMemoResult.Text := FEngine.Ctx^.Result.ReportDef.ToJson;
      wrkFgl:
        FMemoResult.Text := FEngine.Ctx^.Result.FglSource;
    end;
    FEdSaveName.Text := FEngine.Ctx^.Result.SavedName;
  end;

  FBtnBack.Enabled := FEngine.CanBack;
  FBtnNext.Enabled := (Idx < FEngine.StepCount - 1) and FEngine.CurrentStep.CanNext(FEngine.Ctx^);
  FBtnFinish.Enabled := (Idx = FEngine.StepCount - 1) and (FEngine.Ctx^.Result.Kind <> wrkNone);
end;

procedure TfrmSmartWizard.BtnBackClick(Sender: TObject);
begin
  if FEngine.Back then UpdateStepUI;
end;

procedure TfrmSmartWizard.BtnNextClick(Sender: TObject);
var
  I: Integer;
begin
  case FEngine.CurrentIndex of
    0:
      begin
        FEngine.Ctx^.DataSource := Trim(FCbSource.Text);
        PopulateFieldsList;
        if FEngine.Ctx^.Fields = nil then FEngine.Ctx^.Fields := TStringList.Create;
        FEngine.Ctx^.Fields.Clear;
        for I := 0 to FFieldsCheckList.Count - 1 do
          if FFieldsCheckList.Checked[I] then
            FEngine.Ctx^.Fields.Add(FFieldsCheckList.Items[I]);
      end;
    1:
      begin
        FEngine.Ctx^.Title := Trim(FEdTitle.Text);
      end;
    2:
      begin
        SolutionSelect(nil);
      end;
    3:
      begin
        if FEngine.Ctx^.SelectedSolution = 'formgrid-filter' then
          FFilterPanel.SaveToContext(FEngine.Ctx^)
        else if Pos('fgl-', FEngine.Ctx^.SelectedSolution) = 1 then
          FFglPanel.SaveToContext(FEngine.Ctx^)
        else
        begin
          if FEngine.Ctx^.Fields = nil then FEngine.Ctx^.Fields := TStringList.Create;
          FEngine.Ctx^.Fields.Clear;
          for I := 0 to FFieldsCheckList.Count - 1 do
            if FFieldsCheckList.Checked[I] then
              FEngine.Ctx^.Fields.Add(FFieldsCheckList.Items[I]);
        end;
      end;
  end;
  if FEngine.Next then UpdateStepUI;
end;

procedure TfrmSmartWizard.BtnFinishClick(Sender: TObject);
var
  SaveName: string;
begin
  SaveName := Trim(FEdSaveName.Text);
  if SaveName = '' then SaveName := FEngine.Ctx^.Result.SavedName;

  if FCkSaveDb.Checked and (FDb <> nil) then
  begin
    case FEngine.Ctx^.Result.Kind of
      wrkForm:
        if FEngine.Ctx^.Result.FormDef <> nil then
        begin
          FEngine.Ctx^.Result.FormDef.Name := SaveName;
          FDb.SaveObject('_sys_forms', SaveName, FEngine.Ctx^.Result.FormDef.ToJson);
        end;
      wrkReport:
        if FEngine.Ctx^.Result.ReportDef <> nil then
        begin
          FEngine.Ctx^.Result.ReportDef.Name := SaveName;
          FDb.SaveObject('_sys_reports', SaveName, FEngine.Ctx^.Result.ReportDef.ToJson);
        end;
      wrkFgl:
        if FEngine.Ctx^.Result.FglSource <> '' then
          FDb.SaveObject('_sys_programs', SaveName, FEngine.Ctx^.Result.FglSource);
    end;
  end;

  FEngine.Ctx^.Result.SavedName := SaveName;
  ModalResult := mrOk;
end;

function RunSmartWizard(AOwner: TComponent; ADb: TAppDb; const AInitialSource: string): TaWizardResult;
var
  Dlg: TfrmSmartWizard;
begin
  FillChar(Result, SizeOf(Result), 0);
  Dlg := TfrmSmartWizard.CreateWizard(AOwner, ADb, AInitialSource);
  try
    if Dlg.ShowModal = mrOk then
    begin
      Result := Dlg.Engine.Ctx^.Result;
      { Prenosimo vlasništvo kako se ne bi oslobodilo s engineom }
      Dlg.Engine.Ctx^.Result.FormDef := nil;
      Dlg.Engine.Ctx^.Result.ReportDef := nil;
    end
    else
      FreeWizardResult(Result);
  finally
    Dlg.Free;
  end;
end;

end.
