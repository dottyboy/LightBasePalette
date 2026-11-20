unit ta_skelwizard;
{ Cirobnjak "Novi program iz kostura" (poglavlje 11 plana): dva ulaza u jednom prozoru.
    Od kostura:   lijevo popis kostura po kategorijama.
    Od podataka:  odaberes tablicu; kosturi su poredani po prikladnosti (postotak).
  Desno su pitanja (utori) s popisima iz baze, ispod je pregled generiranog 4GL-a (uredjivac s bojenjem i oznakama
  gresaka), pa spremanje u bazu i/ili datoteku. Logika je u ta_skelflow, pa ovo je tanka ljuska. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, CheckLst, Dialogs, contnrs,
  ta_meta, ta_skeleton, ta_skelflow, ta_editor;

type
  TfrmSkelWizard = class(TForm)
  private
    FDb: TAppDb;
    FLib: TaSkeletonLibrary;
    FFlow: TaSkelFlow;
    FFromData: Boolean;
    FUpdating: Boolean;
    FSavedName: string;
    FMode: TRadioGroup;
    FTableLbl: TLabel;
    FTable: TComboBox;
    FList: TListBox;
    FDesc: TLabel;
    FSlotsBox: TScrollBox;
    FPreview: TaEditor;
    FStatus: TLabel;
    FSlotCtrls: TStringList;     { naziv utora -> kontrola (Objects) }
    FListKeys: TStringList;      { naziv kostura po retku popisa ('' za naslov kategorije) }
    procedure ModeChanged(Sender: TObject);
    procedure TableChanged(Sender: TObject);
    procedure ListClick(Sender: TObject);
    procedure SlotChanged(Sender: TObject);
    procedure SaveDbClick(Sender: TObject);
    procedure SaveFileClick(Sender: TObject);
    procedure FillList;
    procedure BuildSlots;
    procedure SyncSlots;
    procedure ShowPreview;
    procedure UpdateFlowValue(AControl: TControl);
  public
    constructor CreateWizard(AOwner: TComponent; ADb: TAppDb; const AStartTable: string);
    destructor Destroy; override;
    { za testove i skripte: isto sto korisnik napravi misem }
    procedure UseData(const ATable: string);
    procedure SelectSkeleton(const AName: string);
    procedure SetSlotValue(const ASlot, AValue: string);
    function SlotControl(const ASlot: string): TControl;
    property Flow: TaSkelFlow read FFlow;
    property Preview: TaEditor read FPreview;
    property SavedName: string read FSavedName;
    property SkeletonList: TListBox read FList;
  end;

{ otvara cirobnjak; vraca naziv spremljenog programa ('' ako nista nije spremljeno).
  AStartTable <> '' otvara ulaz "od podataka" za tu tablicu. }
function RunSkeletonWizard(AOwner: TComponent; ADb: TAppDb; const AStartTable: string = ''): string;

implementation

uses
  ta_i18n;


type
  { za TStringList.Objects: kontrola utora }
  TCtl = TControl;

function RunSkeletonWizard(AOwner: TComponent; ADb: TAppDb; const AStartTable: string): string;
var
  D: TfrmSkelWizard;
begin
  Result := '';
  D := TfrmSkelWizard.CreateWizard(AOwner, ADb, AStartTable);
  try
    D.ShowModal;
    Result := D.SavedName;
  finally
    D.Free;
  end;
end;

constructor TfrmSkelWizard.CreateWizard(AOwner: TComponent; ADb: TAppDb; const AStartTable: string);
var
  LeftP, RightP, TopP, Bottom: TPanel;
  B: TButton;
  Tables: TStringList;
  Log: TStringList;
begin
  inherited CreateNew(AOwner);
  FDb := ADb;
  FLib := TaSkeletonLibrary.Create;
  Log := TStringList.Create;
  try
    FLib.LoadFolder(FindSkeletonFolder, Log);
  finally
    Log.Free;
  end;
  FFlow := TaSkelFlow.Create(ADb, FLib);
  FSlotCtrls := TStringList.Create;
  FListKeys := TStringList.Create;
  Caption := Tr('New program from a skeleton');
  SetBounds(0, 0, 1040, 700);
  Position := poScreenCenter;

  LeftP := TPanel.Create(Self);
  LeftP.Parent := Self;
  LeftP.Align := alLeft;
  LeftP.Width := 290;
  LeftP.BevelOuter := bvNone;
  TopP := TPanel.Create(Self);
  TopP.Parent := LeftP;
  TopP.Align := alTop;
  TopP.Height := 136;
  TopP.BevelOuter := bvNone;
  FMode := TRadioGroup.Create(Self);
  FMode.Parent := TopP;
  FMode.Align := alTop;
  FMode.Caption := Tr('Where do you start?');
  FMode.Items.Add(Tr('From a skeleton'));
  FMode.Items.Add(Tr('From data (tables)'));
  FMode.Height := 74;
  FMode.ItemIndex := 0;
  FMode.OnClick := @ModeChanged;
  FTableLbl := TLabel.Create(Self);
  FTableLbl.Parent := TopP;
  FTableLbl.Caption := Tr('Table:');
  FTableLbl.SetBounds(8, 82, 100, 18);
  FTable := TComboBox.Create(Self);
  FTable.Parent := TopP;
  FTable.Style := csDropDownList;
  FTable.SetBounds(8, 100, 270, 28);
  FTable.OnChange := @TableChanged;
  Tables := FDb.UserTables;
  try
    FTable.Items.Assign(Tables);
  finally
    Tables.Free;
  end;
  FList := TListBox.Create(Self);
  FList.Parent := LeftP;
  FList.Align := alClient;
  FList.BorderSpacing.Around := 6;
  FList.OnClick := @ListClick;

  Bottom := TPanel.Create(Self);
  Bottom.Parent := Self;
  Bottom.Align := alBottom;
  Bottom.Height := 44;
  Bottom.BevelOuter := bvNone;
  B := TButton.Create(Self);
  B.Parent := Bottom;
  B.Caption := Tr('Save to the database...');
  B.SetBounds(12, 8, 150, 30);
  B.OnClick := @SaveDbClick;
  B := TButton.Create(Self);
  B.Parent := Bottom;
  B.Caption := Tr('Save to a file...');
  B.SetBounds(172, 8, 170, 30);
  B.OnClick := @SaveFileClick;
  B := TButton.Create(Self);
  B.Parent := Bottom;
  B.Caption := Tr('Close');
  B.ModalResult := mrCancel;
  B.SetBounds(352, 8, 100, 30);
  FStatus := TLabel.Create(Self);
  FStatus.Parent := Bottom;
  FStatus.SetBounds(470, 14, 540, 20);
  FStatus.Caption := '';

  RightP := TPanel.Create(Self);
  RightP.Parent := Self;
  RightP.Align := alClient;
  RightP.BevelOuter := bvNone;
  FDesc := TLabel.Create(Self);
  FDesc.Parent := RightP;
  FDesc.Align := alTop;
  FDesc.AutoSize := False;
  FDesc.Height := 48;
  FDesc.BorderSpacing.Around := 8;
  FDesc.WordWrap := True;
  FDesc.Top := 0;
  FSlotsBox := TScrollBox.Create(Self);
  FSlotsBox.Parent := RightP;
  FSlotsBox.Align := alTop;
  FSlotsBox.Height := 290;
  FSlotsBox.BorderSpacing.Around := 6;
  FPreview := TaEditor.Create(Self);
  FPreview.Parent := RightP;
  FPreview.Align := alClient;
  FPreview.BorderSpacing.Around := 6;
  FPreview.Variant := ewFgl;
  FPreview.LoadWordsFromDb(FDb);

  ModeChanged(nil);
  if AStartTable = '*' then begin FMode.ItemIndex := 1; ModeChanged(nil); end
  else if AStartTable <> '' then UseData(AStartTable);
end;

destructor TfrmSkelWizard.Destroy;
begin
  FFlow.Free;
  FLib.Free;
  FSlotCtrls.Free;
  FListKeys.Free;
  inherited Destroy;
end;

procedure TfrmSkelWizard.ModeChanged(Sender: TObject);
begin
  FFromData := FMode.ItemIndex = 1;
  FTableLbl.Visible := FFromData;
  FTable.Visible := FFromData;
  FillList;
end;

procedure TfrmSkelWizard.TableChanged(Sender: TObject);
begin
  FillList;
end;

procedure TfrmSkelWizard.FillList;
var
  L: TStringList;
  I, P: Integer;
  Cat, Prev: string;
begin
  FList.Items.Clear;
  FListKeys.Clear;
  L := TStringList.Create;
  try
    if FFromData then
    begin
      if FTable.Text = '' then Exit;
      FFlow.StartFromData(FTable.Text, L);
      for I := 0 to L.Count - 1 do
      begin
        P := Pos('|', L[I]);
        FList.Items.Add(Copy(L[I], 1, P - 1) + '%  ' + Tr(Copy(L[I], P + 1, MaxInt)));
        FListKeys.Add(Copy(L[I], P + 1, MaxInt));
      end;
    end
    else
    begin
      FFlow.ListAll(L);
      Prev := '';
      for I := 0 to L.Count - 1 do
      begin
        P := Pos('|', L[I]);
        Cat := Copy(L[I], 1, P - 1);
        if Cat <> Prev then
        begin
          FList.Items.Add('— ' + Tr(Cat) + ' —');
          FListKeys.Add('');
          Prev := Cat;
        end;
        FList.Items.Add('   ' + Tr(Copy(L[I], P + 1, MaxInt)));
        FListKeys.Add(Copy(L[I], P + 1, MaxInt));
      end;
    end;
  finally
    L.Free;
  end;
end;

procedure TfrmSkelWizard.ListClick(Sender: TObject);
var
  K: string;
begin
  if (FList.ItemIndex < 0) or (FList.ItemIndex >= FListKeys.Count) then Exit;
  K := FListKeys[FList.ItemIndex];
  if K <> '' then SelectSkeleton(K);
end;

procedure TfrmSkelWizard.UseData(const ATable: string);
begin
  FMode.ItemIndex := 1;
  ModeChanged(nil);
  FTable.ItemIndex := FTable.Items.IndexOf(ATable);
  FTable.Text := ATable;
  FillList;
end;

procedure TfrmSkelWizard.SelectSkeleton(const AName: string);
var
  Sk: TaSkeleton;
  I: Integer;
begin
  Sk := FLib.Find(AName);
  if Sk = nil then Exit;
  for I := 0 to FListKeys.Count - 1 do
    if SameText(FListKeys[I], AName) then FList.ItemIndex := I;
  FFlow.Choose(Sk);
  FDesc.Caption := Tr(Sk.Name) + ': ' + Tr(Sk.Description);
  BuildSlots;
  ShowPreview;
end;

procedure TfrmSkelWizard.BuildSlots;
var
  I, Y: Integer;
  Sl: TaSkeletonSlot;
  Lbl: TLabel;
  C: TControl;
  Combo: TComboBox;
  Chk: TCheckBox;
  Edt: TEdit;
  Clb: TCheckListBox;
  Cap: string;
begin
  for I := FSlotsBox.ControlCount - 1 downto 0 do FSlotsBox.Controls[I].Free;
  FSlotCtrls.Clear;
  if FFlow.Skeleton = nil then Exit;
  Y := 4;
  for I := 0 to High(FFlow.Skeleton.Slots) do
  begin
    Sl := FFlow.Skeleton.Slots[I];
    Cap := Tr(Sl.Prompt);
    if Cap = '' then Cap := Sl.Name;
    Lbl := TLabel.Create(FSlotsBox);
    Lbl.Parent := FSlotsBox;
    Lbl.Caption := Cap;
    Lbl.SetBounds(8, Y, 700, 18);
    Inc(Y, 20);
    case Sl.Kind of
      tuTekst, tuBroj:
        begin
          Edt := TEdit.Create(FSlotsBox);
          Edt.Parent := FSlotsBox;
          Edt.SetBounds(12, Y, 560, 26);
          Edt.OnExit := @SlotChanged;
          C := Edt;
          Inc(Y, 32);
        end;
      tuDaNe:
        begin
          Chk := TCheckBox.Create(FSlotsBox);
          Chk.Parent := FSlotsBox;
          Chk.Caption := '';
          Chk.SetBounds(12, Y, 24, 22);
          Chk.OnClick := @SlotChanged;
          C := Chk;
          Inc(Y, 32);
        end;
      tuStupci:
        begin
          Clb := TCheckListBox.Create(FSlotsBox);
          Clb.Parent := FSlotsBox;
          Clb.SetBounds(12, Y, 560, 84);
          Clb.OnClickCheck := @SlotChanged;
          C := Clb;
          Inc(Y, 92);
        end;
    else
      begin
        Combo := TComboBox.Create(FSlotsBox);
        Combo.Parent := FSlotsBox;
        Combo.Style := csDropDownList;
        Combo.SetBounds(12, Y, 560, 28);
        Combo.OnChange := @SlotChanged;
        C := Combo;
        Inc(Y, 34);
      end;
    end;
    C.Name := 'slot_' + Sl.Name;
    FSlotCtrls.AddObject(Sl.Name, C);
  end;
  SyncSlots;
end;

{ postavlja kontrole prema vrijednostima toka (bez poticanja promjena) }
procedure TfrmSkelWizard.SyncSlots;
var
  I, K, J: Integer;
  Sl: TaSkeletonSlot;
  C: TControl;
  Choices, Cur: TStringList;
  V: string;
begin
  if FFlow.Skeleton = nil then Exit;
  FUpdating := True;
  Choices := TStringList.Create;
  Cur := TStringList.Create;
  try
    for I := 0 to FSlotCtrls.Count - 1 do
    begin
      K := FFlow.Skeleton.SlotIndex(FSlotCtrls[I]);
      Sl := FFlow.Skeleton.Slots[K];
      C := TCtl(FSlotCtrls.Objects[I]);
      V := FFlow.Values.Values[Sl.Name];
      if C is TEdit then TEdit(C).Text := V
      else if C is TCheckBox then TCheckBox(C).Checked := SameText(V, 'da')
      else if C is TCheckListBox then
      begin
        SkeletonSlotChoices(FDb, FFlow.Skeleton, Sl.Name, FFlow.Values, Choices);
        TCheckListBox(C).Items.Assign(Choices);
        Cur.CommaText := V;
        for J := 0 to Choices.Count - 1 do TCheckListBox(C).Checked[J] := Cur.IndexOf(Choices[J]) >= 0;
      end
      else if C is TComboBox then
      begin
        SkeletonSlotChoices(FDb, FFlow.Skeleton, Sl.Name, FFlow.Values, Choices);
        TComboBox(C).Items.Assign(Choices);
        TComboBox(C).ItemIndex := Choices.IndexOf(V);
      end;
    end;
  finally
    Choices.Free;
    Cur.Free;
    FUpdating := False;
  end;
end;

procedure TfrmSkelWizard.UpdateFlowValue(AControl: TControl);
var
  J: Integer;
  S: string;
begin
  if AControl is TEdit then S := TEdit(AControl).Text
  else if AControl is TCheckBox then
  begin
    if TCheckBox(AControl).Checked then S := 'da' else S := 'ne';
  end
  else if AControl is TCheckListBox then
  begin
    S := '';
    with TCheckListBox(AControl) do
      for J := 0 to Items.Count - 1 do
        if Checked[J] then
        begin
          if S <> '' then S := S + ',';
          S := S + Items[J];
        end;
  end
  else if AControl is TComboBox then S := TComboBox(AControl).Text
  else Exit;
  for J := 0 to FSlotCtrls.Count - 1 do
    if TCtl(FSlotCtrls.Objects[J]) = AControl then
    begin
      SetSlotValue(FSlotCtrls[J], S);
      Break;
    end;
end;

procedure TfrmSkelWizard.SlotChanged(Sender: TObject);
begin
  if FUpdating then Exit;
  if Sender is TControl then UpdateFlowValue(TControl(Sender));
end;

procedure TfrmSkelWizard.ShowPreview;
var
  Log: TStringList;
  N: Integer;
begin
  if FFlow.Text <> '' then FPreview.Text := FFlow.Text else FPreview.Text := '-- ' + FFlow.Error;
  Log := TStringList.Create;
  try
    N := FFlow.Check(Log);
    FPreview.SetErrorsFromLog(Log);
    if (N = 0) and (FFlow.Text <> '') then FStatus.Caption := Tr('The program is valid. Save it to the database or to a file.')
    else FStatus.Caption := Trim(Log.Text);
  finally
    Log.Free;
  end;
end;

procedure TfrmSkelWizard.SaveDbClick(Sender: TObject);
var
  N, Err: string;
begin
  if FFlow.Text = '' then begin ShowMessage(Tr('First choose a skeleton and fill in the questions.')); Exit; end;
  N := FFlow.SuggestName;
  if not InputQuery(Tr('Save to the database'), Tr('Program name:'), N) then Exit;
  if FDb.LoadObject('_sys_programs', Trim(N)) <> '' then
    if MessageDlg(Tr('Program "') + N + Tr('" already exists. Overwrite?'), mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  if FFlow.Save(Trim(N), True, '', Err) then
  begin
    FSavedName := Trim(N);
    FStatus.Caption := Tr('Saved to the database as "') + FSavedName + '".';
  end
  else ShowMessage(Tr('Saving failed: ') + Err);
end;

procedure TfrmSkelWizard.SaveFileClick(Sender: TObject);
var
  D: TSaveDialog;
  Err: string;
begin
  if FFlow.Text = '' then begin ShowMessage(Tr('First choose a skeleton and fill in the questions.')); Exit; end;
  D := TSaveDialog.Create(Self);
  try
    D.Filter := Tr('4GL program (*.4gl)|*.4gl|All files|*.*');
    D.DefaultExt := '4gl';
    D.FileName := FFlow.SuggestName + '.4gl';
    if D.Execute then
      if FFlow.Save('', False, D.FileName, Err) then FStatus.Caption := Tr('Saved to ') + D.FileName
      else ShowMessage(Tr('Saving failed: ') + Err);
  finally
    D.Free;
  end;
end;

procedure TfrmSkelWizard.SetSlotValue(const ASlot, AValue: string);
begin
  FFlow.SetValue(ASlot, AValue);
  SyncSlots;
  ShowPreview;
end;

function TfrmSkelWizard.SlotControl(const ASlot: string): TControl;
var
  I: Integer;
begin
  Result := nil;
  I := FSlotCtrls.IndexOf(ASlot);
  if I >= 0 then Result := TCtl(FSlotCtrls.Objects[I]);
end;

end.
