unit ta_wizardformgrid_dlg;
{ Dialog / embedded panel for configuring the Form-with-Filter wizard solution.
  Allows fine-tuning which fields become filter controls and toggling
  Refresh and Clear filter buttons. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, CheckLst, ExtCtrls,
  ta_meta, ta_wizardframework, ta_wizardgen;

type
  { TaWizardFormGridPanel - panel displayed inside TfrmSmartWizard }
  TaWizardFormGridPanel = class(TPanel)
  private
    FLblInfo: TLabel;
    FFieldsList: TCheckListBox;
    FCkRefresh: TCheckBox;
    FCkClear: TCheckBox;
    FCkDateRanges: TCheckBox;
    procedure AllClick(Sender: TObject);
    procedure NoneClick(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    procedure LoadFromContext(const ACtx: TaWizardContext);
    procedure SaveToContext(var ACtx: TaWizardContext);
    property FieldsList: TCheckListBox read FFieldsList;
    property CkRefresh: TCheckBox read FCkRefresh;
    property CkClear: TCheckBox read FCkClear;
    property CkDateRanges: TCheckBox read FCkDateRanges;
  end;

implementation

uses
  ta_i18n;


{ TaWizardFormGridPanel }

constructor TaWizardFormGridPanel.Create(AOwner: TComponent);
var
  BtnAll, BtnNone: TButton;
  PnlBottom: TPanel;
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  Caption := '';

  FLblInfo := TLabel.Create(Self);
  FLblInfo.Parent := Self;
  FLblInfo.SetBounds(12, 10, 480, 20);
  FLblInfo.Caption := Tr('Select the fields you want as a quick filter above the table:');

  FFieldsList := TCheckListBox.Create(Self);
  FFieldsList.Parent := Self;
  FFieldsList.SetBounds(12, 34, 480, 180);

  BtnAll := TButton.Create(Self);
  BtnAll.Parent := Self;
  BtnAll.SetBounds(12, 220, 90, 26);
  BtnAll.Caption := Tr('Select all');
  BtnAll.OnClick := @AllClick;

  BtnNone := TButton.Create(Self);
  BtnNone.Parent := Self;
  BtnNone.SetBounds(110, 220, 90, 26);
  BtnNone.Caption := Tr('Deselect all');
  BtnNone.OnClick := @NoneClick;

  PnlBottom := TPanel.Create(Self);
  PnlBottom.Parent := Self;
  PnlBottom.BevelOuter := bvNone;
  PnlBottom.SetBounds(12, 255, 480, 70);

  FCkRefresh := TCheckBox.Create(PnlBottom);
  FCkRefresh.Parent := PnlBottom;
  FCkRefresh.SetBounds(0, 4, 300, 20);
  FCkRefresh.Caption := Tr('Add a "Refresh" button with automatic binding');
  FCkRefresh.Checked := True;

  FCkClear := TCheckBox.Create(PnlBottom);
  FCkClear.Parent := PnlBottom;
  FCkClear.SetBounds(0, 26, 300, 20);
  FCkClear.Caption := Tr('Add a "Clear filters" button');
  FCkClear.Checked := True;

  FCkDateRanges := TCheckBox.Create(PnlBottom);
  FCkDateRanges.Parent := PnlBottom;
  FCkDateRanges.SetBounds(0, 48, 300, 20);
  FCkDateRanges.Caption := Tr('For date fields offer a range (From - To)');
  FCkDateRanges.Checked := True;
end;

procedure TaWizardFormGridPanel.AllClick(Sender: TObject);
var
  I: Integer;
begin
  for I := 0 to FFieldsList.Count - 1 do
    FFieldsList.Checked[I] := True;
end;

procedure TaWizardFormGridPanel.NoneClick(Sender: TObject);
var
  I: Integer;
begin
  for I := 0 to FFieldsList.Count - 1 do
    FFieldsList.Checked[I] := False;
end;

procedure TaWizardFormGridPanel.LoadFromContext(const ACtx: TaWizardContext);
var
  I, Idx: Integer;
begin
  FFieldsList.Items.Clear;
  if ACtx.Fields <> nil then
  begin
    for I := 0 to ACtx.Fields.Count - 1 do
    begin
      Idx := FFieldsList.Items.Add(ACtx.Fields[I]);
      { Provjeri je li polje već u FilterFields ili predloženo }
      if (ACtx.FilterFields <> nil) and (ACtx.FilterFields.IndexOf(ACtx.Fields[I]) >= 0) then
        FFieldsList.Checked[Idx] := True
      else
      begin
        { Provjeri heuristički prijedlog }
        for Idx := 0 to High(ACtx.FieldSuggestions) do
          if SameText(ACtx.FieldSuggestions[Idx].FieldName, ACtx.Fields[I]) and
             ACtx.FieldSuggestions[Idx].IsFilter then
          begin
            FFieldsList.Checked[FFieldsList.Items.Count - 1] := True;
            Break;
          end;
      end;
    end;
  end;
end;

procedure TaWizardFormGridPanel.SaveToContext(var ACtx: TaWizardContext);
var
  I: Integer;
begin
  if ACtx.FilterFields = nil then
    ACtx.FilterFields := TStringList.Create
  else
    ACtx.FilterFields.Clear;

  for I := 0 to FFieldsList.Count - 1 do
    if FFieldsList.Checked[I] then
      ACtx.FilterFields.Add(FFieldsList.Items[I]);
end;

end.
