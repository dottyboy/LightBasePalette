unit ta_wizardfgl_dlg;
{ Embedded panel for configuring 4GL script generation options in TfrmSmartWizard.
  Lets the user pick block type (INPUT, CONSTRUCT, DISPLAY, MENU/MAIN) and preview
  the resulting 4GL script. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls,
  ta_meta, ta_wizardframework, ta_wizardgen;

type
  TaWizardFglPanel = class(TPanel)
  private
    FLblType: TLabel;
    FRadioType: TRadioGroup;
    FLblPreview: TLabel;
    FMemoPreview: TMemo;
    FDb: TAppDb;
    FSource, FTitle: string;
    FFields: TStrings;
    procedure TypeChange(Sender: TObject);
    procedure UpdatePreview;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure LoadFromContext(const ACtx: TaWizardContext);
    procedure SaveToContext(var ACtx: TaWizardContext);
  end;

implementation

uses
  ta_i18n;


{ TaWizardFglPanel }

constructor TaWizardFglPanel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  Caption := '';
  FFields := TStringList.Create;

  FLblType := TLabel.Create(Self);
  FLblType.Parent := Self;
  FLblType.SetBounds(12, 10, 480, 20);
  FLblType.Caption := Tr('Choose the type of the 4GL program block:');

  FRadioType := TRadioGroup.Create(Self);
  FRadioType.Parent := Self;
  FRadioType.SetBounds(12, 32, 480, 80);
  FRadioType.Items.Add('INPUT — unos i spremanje sloga u tablicu');
  FRadioType.Items.Add('CONSTRUCT — prozor za unos kriterija pretrage (WHERE uvjet)');
  FRadioType.Items.Add(Tr('DISPLAY - view records in a grid (DISPLAY ARRAY)'));
  FRadioType.Items.Add('MAIN / MENU — glavni izbornik s akcijama');
  FRadioType.ItemIndex := 0;
  FRadioType.OnClick := @TypeChange;

  FLblPreview := TLabel.Create(Self);
  FLblPreview.Parent := Self;
  FLblPreview.SetBounds(12, 120, 480, 20);
  FLblPreview.Caption := Tr('Preview of the generated 4GL code:');

  FMemoPreview := TMemo.Create(Self);
  FMemoPreview.Parent := Self;
  FMemoPreview.SetBounds(12, 142, 480, 180);
  FMemoPreview.ReadOnly := True;
  FMemoPreview.ScrollBars := ssBoth;
  FMemoPreview.Font.Name := 'Courier New';
  FMemoPreview.Font.Size := 9;
end;

destructor TaWizardFglPanel.Destroy;
begin
  FFields.Free;
  inherited Destroy;
end;

procedure TaWizardFglPanel.TypeChange(Sender: TObject);
begin
  UpdatePreview;
end;

procedure TaWizardFglPanel.UpdatePreview;
var
  ST: string;
begin
  case FRadioType.ItemIndex of
    0: ST := 'INPUT';
    1: ST := 'CONSTRUCT';
    2: ST := 'DISPLAY';
    3: ST := 'MAIN';
  else
    ST := 'INPUT';
  end;
  FMemoPreview.Text := BuildFglScript(FDb, FSource, FTitle, ST, FFields);
end;

procedure TaWizardFglPanel.LoadFromContext(const ACtx: TaWizardContext);
begin
  FDb := ACtx.Db;
  FSource := ACtx.DataSource;
  FTitle := ACtx.Title;
  FFields.Assign(ACtx.Fields);

  if SameText(ACtx.FglScriptType, 'CONSTRUCT') then
    FRadioType.ItemIndex := 1
  else if SameText(ACtx.FglScriptType, 'DISPLAY') then
    FRadioType.ItemIndex := 2
  else if SameText(ACtx.FglScriptType, 'MAIN') then
    FRadioType.ItemIndex := 3
  else
    FRadioType.ItemIndex := 0;

  UpdatePreview;
end;

procedure TaWizardFglPanel.SaveToContext(var ACtx: TaWizardContext);
begin
  case FRadioType.ItemIndex of
    0: ACtx.FglScriptType := 'INPUT';
    1: ACtx.FglScriptType := 'CONSTRUCT';
    2: ACtx.FglScriptType := 'DISPLAY';
    3: ACtx.FglScriptType := 'MAIN';
  else
    ACtx.FglScriptType := 'INPUT';
  end;
end;

end.
