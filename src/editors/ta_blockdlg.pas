unit ta_blockdlg;
{ Dijalog Blok-carobnjaka: tablica, raspored, podforme; popis onoga sto ce nastati; spremanje forme u bazu. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, Dialogs, ta_meta, ta_blockwiz;

type
  TfrmBlockWizard = class(TForm)
  private
    FDb: TAppDb;
    FWiz: TaBlockWizard;
    FTable: TComboBox;
    FLayout: TRadioGroup;
    FDetails: TCheckBox;
    FName: TEdit;
    FInfo: TListBox;
    FStatus: TLabel;
    FSaved: string;
    procedure Changed(Sender: TObject);
    procedure SaveClick(Sender: TObject);
    procedure Refresh;
  public
    constructor CreateWizard(AOwner: TComponent; ADb: TAppDb; const ATable: string);
    destructor Destroy; override;
    procedure Configure(const ATable: string; ALayout: TaBlockLayout; AWithDetails: Boolean);
    function DoSave: Boolean;
    property Wiz: TaBlockWizard read FWiz;
    property Info: TListBox read FInfo;
    property SavedName: string read FSaved;
    property NameEdit: TEdit read FName;
  end;

function RunBlockWizard(AOwner: TComponent; ADb: TAppDb; const ATable: string = ''): string;

implementation

uses
  ta_i18n;


function RunBlockWizard(AOwner: TComponent; ADb: TAppDb; const ATable: string): string;
var
  D: TfrmBlockWizard;
begin
  D := TfrmBlockWizard.CreateWizard(AOwner, ADb, ATable);
  try
    D.ShowModal;
    Result := D.SavedName;
  finally
    D.Free;
  end;
end;

constructor TfrmBlockWizard.CreateWizard(AOwner: TComponent; ADb: TAppDb; const ATable: string);
var
  L: TLabel;
  B: TButton;
  T: TStringList;
begin
  inherited CreateNew(AOwner);
  FDb := ADb;
  FWiz := TaBlockWizard.Create(ADb);
  Caption := Tr('New form over a table (block)');
  SetBounds(0, 0, 640, 520);
  Position := poScreenCenter;
  L := TLabel.Create(Self); L.Parent := Self; L.Caption := Tr('Table:'); L.SetBounds(12, 14, 80, 18);
  FTable := TComboBox.Create(Self); FTable.Parent := Self; FTable.Style := csDropDownList;
  FTable.SetBounds(100, 10, 300, 28);
  T := FDb.UserTables;
  try FTable.Items.Assign(T); finally T.Free; end;
  FTable.OnChange := @Changed;
  FLayout := TRadioGroup.Create(Self); FLayout.Parent := Self; FLayout.Caption := Tr('Layout');
  FLayout.SetBounds(12, 46, 600, 160);
  FLayout.Items.Add('Obrazac (jedan stupac)');
  FLayout.Items.Add('Obrazac u dva stupca');
  FLayout.Items.Add('Tablica');
  FLayout.Items.Add('Obrazac i tablica');
  FLayout.Items.Add(Tr('Continuous form (header, rows, footer)'));
  FLayout.Items.Add(Tr('Form + continuous subforms (e.g. an invoice with items)'));
  FLayout.ItemIndex := 0;
  FLayout.OnClick := @Changed;
  FDetails := TCheckBox.Create(Self); FDetails.Parent := Self;
  FDetails.Caption := Tr('Add subforms for related tables (master-detail)');
  FDetails.Checked := True; FDetails.SetBounds(12, 212, 560, 22); FDetails.OnClick := @Changed;
  L := TLabel.Create(Self); L.Parent := Self; L.Caption := Tr('What will be created:'); L.SetBounds(12, 240, 200, 18);
  FInfo := TListBox.Create(Self); FInfo.Parent := Self; FInfo.SetBounds(12, 260, 610, 192);
  FInfo.Anchors := [akLeft, akTop, akRight, akBottom];
  L := TLabel.Create(Self); L.Parent := Self; L.Caption := Tr('Form name:'); L.SetBounds(12, 466, 90, 18);
  L.Anchors := [akLeft, akBottom];
  FName := TEdit.Create(Self); FName.Parent := Self; FName.SetBounds(104, 462, 260, 28);
  FName.Anchors := [akLeft, akBottom];
  B := TButton.Create(Self); B.Parent := Self; B.Caption := Tr('Save form'); B.SetBounds(380, 460, 120, 30);
  B.Anchors := [akRight, akBottom]; B.OnClick := @SaveClick;
  B := TButton.Create(Self); B.Parent := Self; B.Caption := Tr('Close'); B.ModalResult := mrCancel;
  B.SetBounds(510, 460, 112, 30); B.Anchors := [akRight, akBottom];
  FStatus := TLabel.Create(Self); FStatus.Parent := Self; FStatus.SetBounds(420, 14, 200, 18);
  if ATable <> '' then Configure(ATable, blForm, True);
end;

destructor TfrmBlockWizard.Destroy;
begin
  FWiz.Free;
  inherited Destroy;
end;

procedure TfrmBlockWizard.Configure(const ATable: string; ALayout: TaBlockLayout; AWithDetails: Boolean);
begin
  FTable.Text := ATable;
  FTable.ItemIndex := FTable.Items.IndexOf(ATable);
  FLayout.ItemIndex := Ord(ALayout);
  FDetails.Checked := AWithDetails;
  Refresh;
end;

procedure TfrmBlockWizard.Changed(Sender: TObject);
begin
  Refresh;
end;

procedure TfrmBlockWizard.Refresh;
var
  Old: string;
begin
  Old := FWiz.Table;
  if (FTable.Text <> '') and (FTable.Text <> Old) then
  begin
    FWiz.Table := FTable.Text;
    FName.Text := FWiz.SuggestName;
  end;
  if FLayout.ItemIndex >= 0 then FWiz.Layout := TaBlockLayout(FLayout.ItemIndex);
  FWiz.WithDetails := FDetails.Checked;
  FDetails.Enabled := not (FWiz.Layout in [blTable, blContinuous]);
  FWiz.Describe(FInfo.Items);
end;

function TfrmBlockWizard.DoSave: Boolean;
var
  Err: string;
begin
  Result := FWiz.Save(FName.Text, Err);
  if Result then
  begin
    FSaved := Trim(FName.Text);
    FStatus.Caption := Tr('Saved: ') + FSaved;
  end
  else FStatus.Caption := Err;
end;

procedure TfrmBlockWizard.SaveClick(Sender: TObject);
begin
  if (FDb.LoadObject('_sys_forms', Trim(FName.Text)) <> '') and
     (MessageDlg(Tr('Form "') + FName.Text + Tr('" already exists. Overwrite?'), mtConfirmation, [mbYes, mbNo], 0) <> mrYes) then Exit;
  if not DoSave then ShowMessage(FStatus.Caption);
end;

end.
