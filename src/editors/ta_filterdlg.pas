unit ta_filterdlg;
{ Filteri po stupcima: za svaki stupac mreze jedno polje (>100, 5..10, ra*, ...). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, StdCtrls, ExtCtrls, ta_meta, ta_gridtools;

{ ANames/ACaptions/AKinds opisuju stupce; AFilters (Naziv=Tekst) se mijenja. False = odustao. }
function RunColumnFilters(AOwner: TComponent; ANames, ACaptions: TStrings; const AKinds: array of TFilterKind;
  AFilters: TStrings; ADb: TAppDb = nil; const AFormName: string = ''): Boolean;

implementation

uses
  ta_i18n;


type
  TFilterHelper = class
  public
    Edits: array of TEdit;
    Names: TStrings;
    Db: TAppDb;
    FormName: string;
    SetsBox: TComboBox;
    procedure ClearAll(Sender: TObject);
    procedure RefreshSets(const ASelect: string);
    procedure LoadClick(Sender: TObject);
    procedure SaveClick(Sender: TObject);
    procedure DeleteClick(Sender: TObject);
  end;

procedure TFilterHelper.ClearAll(Sender: TObject);
var
  J: Integer;
begin
  for J := 0 to High(Edits) do Edits[J].Text := '';
end;

procedure TFilterHelper.RefreshSets(const ASelect: string);
var
  L: TStringList;
begin
  SetsBox.Items.Clear;
  if Db = nil then Exit;
  L := ListFilterSets(Db, FormName);
  try
    SetsBox.Items.Assign(L);
  finally
    L.Free;
  end;
  SetsBox.ItemIndex := SetsBox.Items.IndexOf(ASelect);
end;

procedure TFilterHelper.LoadClick(Sender: TObject);
var
  L: TStringList;
  J: Integer;
begin
  if (Db = nil) or (SetsBox.Text = '') then Exit;
  L := TStringList.Create;
  try
    if not LoadFilterSet(Db, FormName, SetsBox.Text, L) then Exit;
    for J := 0 to High(Edits) do Edits[J].Text := L.Values[Names[J]];
  finally
    L.Free;
  end;
end;

procedure TFilterHelper.SaveClick(Sender: TObject);
var
  L: TStringList;
  J: Integer;
  N: string;
begin
  if Db = nil then Exit;
  N := SetsBox.Text;
  if not InputQuery(Tr('Save filters'), Tr('Filter set name:'), N) then Exit;
  N := Trim(N);
  if N = '' then Exit;
  L := TStringList.Create;
  try
    for J := 0 to High(Edits) do
      if Trim(Edits[J].Text) <> '' then L.Values[Names[J]] := Trim(Edits[J].Text);
    SaveFilterSet(Db, FormName, N, L);
  finally
    L.Free;
  end;
  RefreshSets(N);
end;

procedure TFilterHelper.DeleteClick(Sender: TObject);
begin
  if (Db = nil) or (SetsBox.Text = '') then Exit;
  if MessageDlg(Tr('Delete saved filters "') + SetsBox.Text + '"?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  DeleteFilterSet(Db, FormName, SetsBox.Text);
  RefreshSets('');
end;

function RunColumnFilters(AOwner: TComponent; ANames, ACaptions: TStrings; const AKinds: array of TFilterKind;
  AFilters: TStrings; ADb: TAppDb; const AFormName: string): Boolean;
var
  F: TForm;
  Box: TScrollBox;
  Hp: TFilterHelper;
  I, Y: Integer;
  Lb: TLabel;
  Ok, Cancel, Clear: TButton;
  H: Integer;
begin
  Result := False;
  if ANames.Count = 0 then Exit;
  Hp := TFilterHelper.Create;
  F := TForm.CreateNew(AOwner);
  try
    F.Caption := Tr('Column filters');
    F.Position := poOwnerFormCenter;
    F.SetBounds(0, 0, 560, 480);
    Box := TScrollBox.Create(F);
    Box.Parent := F;
    Box.SetBounds(0, 0, 560, 384);
    Box.Anchors := [akLeft, akTop, akRight, akBottom];
    SetLength(Hp.Edits, ANames.Count);
    Y := 8;
    for I := 0 to ANames.Count - 1 do
    begin
      Lb := TLabel.Create(F);
      Lb.Parent := Box;
      Lb.Caption := ACaptions[I];
      Lb.SetBounds(10, Y, 220, 18);
      Hp.Edits[I] := TEdit.Create(F);
      Hp.Edits[I].Parent := Box;
      Hp.Edits[I].SetBounds(10, Y + 18, 230, 24);
      Hp.Edits[I].Text := AFilters.Values[ANames[I]];
      Lb := TLabel.Create(F);
      Lb.Parent := Box;
      Lb.Caption := FilterHelp(AKinds[I]);
      Lb.SetBounds(250, Y + 22, 290, 18);
      Lb.Font.Color := $808080;
      Inc(Y, 52);
    end;
    Hp.Names := ANames;
    Hp.Db := ADb;
    Hp.FormName := AFormName;
    if ADb <> nil then
    begin
      Lb := TLabel.Create(F);
      Lb.Parent := F; Lb.Caption := Tr('Saved filters:'); Lb.SetBounds(10, 392, 120, 18);
      Hp.SetsBox := TComboBox.Create(F);
      Hp.SetsBox.Parent := F;
      Hp.SetsBox.Style := csDropDown;
      Hp.SetsBox.SetBounds(134, 388, 190, 26);
      with TButton.Create(F) do begin Parent := F; Caption := Tr('Load'); SetBounds(330, 388, 70, 26); OnClick := @Hp.LoadClick; end;
      with TButton.Create(F) do begin Parent := F; Caption := Tr('Save as...'); SetBounds(404, 388, 100, 26); OnClick := @Hp.SaveClick; end;
      with TButton.Create(F) do begin Parent := F; Caption := Tr('Remove'); SetBounds(508, 388, 44, 26); OnClick := @Hp.DeleteClick; end;
      Hp.RefreshSets('');
    end;
    H := 430;
    Clear := TButton.Create(F);
    Clear.Parent := F; Clear.Caption := Tr('Clear all'); Clear.SetBounds(10, H, 110, 30);
    Clear.OnClick := @Hp.ClearAll;
    Ok := TButton.Create(F);
    Ok.Parent := F; Ok.Caption := Tr('Apply'); Ok.ModalResult := mrOk; Ok.Default := True;
    Ok.SetBounds(340, H, 100, 30);
    Cancel := TButton.Create(F);
    Cancel.Parent := F; Cancel.Caption := Tr('Cancel'); Cancel.ModalResult := mrCancel; Cancel.Cancel := True;
    Cancel.SetBounds(448, H, 100, 30);
    if F.ShowModal = mrOk then
    begin
      for I := 0 to ANames.Count - 1 do
        AFilters.Values[ANames[I]] := Trim(Hp.Edits[I].Text);
      Result := True;
    end;
  finally
    F.Free;
    Hp.Free;
  end;
end;

end.
