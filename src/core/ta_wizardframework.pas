unit ta_wizardframework;
{ Smart Wizard Framework for LightPalette (Stage E7 / Block Wizard).
  Provides the architecture for intention-based wizards, confidence-scored
  solutions, pluggable steps, and cross-platform UI integration (Sloj B). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ta_meta, ta_types, ta_formdef, ta_reportdef;

type
  TaWizardResultKind = (wrkNone, wrkForm, wrkReport, wrkFgl);

  TaWizardResult = record
    Kind: TaWizardResultKind;
    FormDef: TaFormDef;        { owned by result, freed by FreeWizardResult }
    ReportDef: TaReportDef;    { owned by result, freed by FreeWizardResult }
    FglSource: string;         { generated 4GL source text }
    SavedName: string;         { name under which object was saved in db/file }
    Error: string;             { empty if generation succeeded }
  end;

  TaFieldSuggestion = record
    FieldName: string;
    Caption: string;
    LType: TaLogicalType;
    IsFilter: Boolean;         { suggested as a filter control }
    Confidence: Integer;       { 0-100 score }
  end;
  TaFieldSuggestions = array of TaFieldSuggestion;

type
  PTaWizardContext = ^TaWizardContext;

  { Generator callback signature: fills ACtx^.Result and returns True on success }
  TWizardGenerateProc = function(ADb: TAppDb; ACtx: PTaWizardContext): Boolean;

  TaWizardSolution = record
    SolutionId: string;           { 'formgrid-filter', 'form-card', 'report-group', 'fgl-input', etc. }
    Title: string;                { e.g. 'Standardna forma s filterom' }
    Description: string;          { human readable explanation }
    Confidence: Integer;          { 0-100 }
    Generate: TWizardGenerateProc; { generation procedure }
  end;
  TaWizardSolutions = array of TaWizardSolution;

  TaWizardContext = record
    Db: TAppDb;
    DataSource: string;           { table, query or fgl function }
    Title: string;                { user-supplied title or intent description }
    Fields: TStrings;             { chosen fields to display/process }
    FilterFields: TStrings;       { chosen fields to act as header filters }
    FieldSuggestions: TaFieldSuggestions; { evaluated fields from data source }
    Solutions: TaWizardSolutions; { suggested solutions sorted by confidence DESC }
    SelectedSolution: string;     { SolutionId chosen by user }
    FglScriptType: string;        { 'INPUT' | 'CONSTRUCT' | 'DISPLAY' | 'MAIN' }
    Result: TaWizardResult;
  end;

procedure InitWizardContext(out ACtx: TaWizardContext; ADb: TAppDb; const ASource: string = '');
procedure FreeWizardContext(var ACtx: TaWizardContext);
procedure FreeWizardResult(var R: TaWizardResult);

{ Global registration of wizard solutions }
procedure RegisterWizardSolution(const ASolution: TaWizardSolution);
function GetRegisteredSolutions: TaWizardSolutions;
procedure ClearRegisteredSolutions;
function FindRegisteredSolution(const ASolutionId: string; out ASolution: TaWizardSolution): Boolean;

type
  { Abstract wizard step }
  TaWizardStep = class
  protected
    FStepId: string;
    FTitle: string;
    FDescription: string;
  public
    constructor Create(const AId, ATitle, ADesc: string); virtual;
    function CanNext(const ACtx: TaWizardContext): Boolean; virtual;
    function CanBack(const ACtx: TaWizardContext): Boolean; virtual;
    function EnterStep(var ACtx: TaWizardContext): Boolean; virtual;
    function ExitStep(var ACtx: TaWizardContext): Boolean; virtual;
    property StepId: string read FStepId;
    property Title: string read FTitle;
    property Description: string read FDescription;
  end;

  { Standard wizard steps }
  TaDataSourceStep = class(TaWizardStep)
  public
    constructor Create; reintroduce;
    function CanNext(const ACtx: TaWizardContext): Boolean; override;
  end;

  TaTitleStep = class(TaWizardStep)
  public
    constructor Create; reintroduce;
    function CanNext(const ACtx: TaWizardContext): Boolean; override;
  end;

  TaSolutionStep = class(TaWizardStep)
  public
    constructor Create; reintroduce;
    function CanNext(const ACtx: TaWizardContext): Boolean; override;
  end;

  TaFieldStep = class(TaWizardStep)
  public
    constructor Create; reintroduce;
    function CanNext(const ACtx: TaWizardContext): Boolean; override;
  end;

  TaResultStep = class(TaWizardStep)
  public
    constructor Create; reintroduce;
    function EnterStep(var ACtx: TaWizardContext): Boolean; override;
  end;

  { Engine that orchestrates steps and coordinates execution }
  TaSmartWizardEngine = class
  private
    FSteps: TFPList;
    FCurrentIndex: Integer;
    FCtx: TaWizardContext;
  public
    constructor Create(ADb: TAppDb; const AInitialSource: string = '');
    destructor Destroy; override;
    procedure AddStep(AStep: TaWizardStep);
    function CurrentStep: TaWizardStep;
    function CurrentIndex: Integer;
    function StepCount: Integer;
    function CanNext: Boolean;
    function CanBack: Boolean;
    function Next: Boolean;
    function Back: Boolean;
    function ExecuteCurrent: Boolean;
    function Ctx: PTaWizardContext;
    property Context: TaWizardContext read FCtx write FCtx;
  end;

implementation

var
  GRegisteredSolutions: TaWizardSolutions;

procedure InitWizardContext(out ACtx: TaWizardContext; ADb: TAppDb; const ASource: string = '');
begin
  FillChar(ACtx, SizeOf(ACtx), 0);
  ACtx.Db := ADb;
  ACtx.DataSource := ASource;
  ACtx.Fields := TStringList.Create;
  ACtx.FilterFields := TStringList.Create;
  ACtx.FglScriptType := 'INPUT';
  ACtx.Result.Kind := wrkNone;
end;

procedure FreeWizardResult(var R: TaWizardResult);
begin
  if R.FormDef <> nil then
  begin
    R.FormDef.Free;
    R.FormDef := nil;
  end;
  if R.ReportDef <> nil then
  begin
    R.ReportDef.Free;
    R.ReportDef := nil;
  end;
  R.FglSource := '';
  R.SavedName := '';
  R.Error := '';
  R.Kind := wrkNone;
end;

procedure FreeWizardContext(var ACtx: TaWizardContext);
begin
  FreeWizardResult(ACtx.Result);
  if ACtx.Fields <> nil then
  begin
    ACtx.Fields.Free;
    ACtx.Fields := nil;
  end;
  if ACtx.FilterFields <> nil then
  begin
    ACtx.FilterFields.Free;
    ACtx.FilterFields := nil;
  end;
  SetLength(ACtx.FieldSuggestions, 0);
  SetLength(ACtx.Solutions, 0);
end;

procedure RegisterWizardSolution(const ASolution: TaWizardSolution);
var
  I, N: Integer;
begin
  for I := 0 to High(GRegisteredSolutions) do
    if SameText(GRegisteredSolutions[I].SolutionId, ASolution.SolutionId) then
    begin
      GRegisteredSolutions[I] := ASolution;
      Exit;
    end;
  N := Length(GRegisteredSolutions);
  SetLength(GRegisteredSolutions, N + 1);
  GRegisteredSolutions[N] := ASolution;
end;

function GetRegisteredSolutions: TaWizardSolutions;
begin
  Result := Copy(GRegisteredSolutions);
end;

procedure ClearRegisteredSolutions;
begin
  SetLength(GRegisteredSolutions, 0);
end;

function FindRegisteredSolution(const ASolutionId: string; out ASolution: TaWizardSolution): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(GRegisteredSolutions) do
    if SameText(GRegisteredSolutions[I].SolutionId, ASolutionId) then
    begin
      ASolution := GRegisteredSolutions[I];
      Exit(True);
    end;
end;

{ TaWizardStep }

constructor TaWizardStep.Create(const AId, ATitle, ADesc: string);
begin
  inherited Create;
  FStepId := AId;
  FTitle := ATitle;
  FDescription := ADesc;
end;

function TaWizardStep.CanNext(const ACtx: TaWizardContext): Boolean;
begin
  Result := True;
end;

function TaWizardStep.CanBack(const ACtx: TaWizardContext): Boolean;
begin
  Result := True;
end;

function TaWizardStep.EnterStep(var ACtx: TaWizardContext): Boolean;
begin
  Result := True;
end;

function TaWizardStep.ExitStep(var ACtx: TaWizardContext): Boolean;
begin
  Result := True;
end;

{ TaDataSourceStep }

constructor TaDataSourceStep.Create;
begin
  inherited Create('datasource', 'Izvor podataka', 'Odaberite tablicu ili upit kao temelj za izradu.');
end;

function TaDataSourceStep.CanNext(const ACtx: TaWizardContext): Boolean;
begin
  Result := Trim(ACtx.DataSource) <> '';
end;

{ TaTitleStep }

constructor TaTitleStep.Create;
begin
  inherited Create('title', 'Namjera i naslov', 'Unesite naslov ili kratki opis onoga što želite (npr. popis s filterom, unos, izvještaj).');
end;

function TaTitleStep.CanNext(const ACtx: TaWizardContext): Boolean;
begin
  Result := Trim(ACtx.Title) <> '';
end;

{ TaSolutionStep }

constructor TaSolutionStep.Create;
begin
  inherited Create('solution', 'Predložena rješenja', 'Odaberite jedno od ponuđenih rješenja rangiranih prema pouzdanosti.');
end;

function TaSolutionStep.CanNext(const ACtx: TaWizardContext): Boolean;
begin
  Result := Trim(ACtx.SelectedSolution) <> '';
end;

{ TaFieldStep }

constructor TaFieldStep.Create;
begin
  inherited Create('fields', 'Polja i filteri', 'Potvrdite polja za prikaz i označite polja za brzi filter.');
end;

function TaFieldStep.CanNext(const ACtx: TaWizardContext): Boolean;
begin
  Result := (ACtx.Fields <> nil) and (ACtx.Fields.Count > 0);
end;

{ TaResultStep }

constructor TaResultStep.Create;
begin
  inherited Create('result', 'Pregled i spremanje', 'Pregledajte generirani objekt i potvrdite spremanje.');
end;

function TaResultStep.EnterStep(var ACtx: TaWizardContext): Boolean;
var
  Sol: TaWizardSolution;
begin
  Result := False;
  if FindRegisteredSolution(ACtx.SelectedSolution, Sol) then
  begin
    if Assigned(Sol.Generate) then
      Result := Sol.Generate(ACtx.Db, @ACtx);
  end
  else
    ACtx.Result.Error := 'Nepoznato rješenje: ' + ACtx.SelectedSolution;
end;

{ TaSmartWizardEngine }

function TaSmartWizardEngine.Ctx: PTaWizardContext;
begin
  Result := @FCtx;
end;


constructor TaSmartWizardEngine.Create(ADb: TAppDb; const AInitialSource: string);
begin
  inherited Create;
  FSteps := TFPList.Create;
  FCurrentIndex := 0;
  InitWizardContext(FCtx, ADb, AInitialSource);
end;

destructor TaSmartWizardEngine.Destroy;
var
  I: Integer;
begin
  for I := 0 to FSteps.Count - 1 do
    TObject(FSteps[I]).Free;
  FSteps.Free;
  FreeWizardContext(FCtx);
  inherited Destroy;
end;

procedure TaSmartWizardEngine.AddStep(AStep: TaWizardStep);
begin
  if AStep <> nil then FSteps.Add(AStep);
end;

function TaSmartWizardEngine.CurrentStep: TaWizardStep;
begin
  if (FCurrentIndex >= 0) and (FCurrentIndex < FSteps.Count) then
    Result := TaWizardStep(FSteps[FCurrentIndex])
  else
    Result := nil;
end;

function TaSmartWizardEngine.CurrentIndex: Integer;
begin
  Result := FCurrentIndex;
end;

function TaSmartWizardEngine.StepCount: Integer;
begin
  Result := FSteps.Count;
end;

function TaSmartWizardEngine.CanNext: Boolean;
var
  St: TaWizardStep;
begin
  St := CurrentStep;
  if St = nil then Exit(False);
  Result := (FCurrentIndex < FSteps.Count - 1) and St.CanNext(FCtx);
end;

function TaSmartWizardEngine.CanBack: Boolean;
var
  St: TaWizardStep;
begin
  St := CurrentStep;
  if St = nil then Exit(False);
  Result := (FCurrentIndex > 0) and St.CanBack(FCtx);
end;

function TaSmartWizardEngine.ExecuteCurrent: Boolean;
var
  St: TaWizardStep;
begin
  St := CurrentStep;
  if St <> nil then Result := St.EnterStep(FCtx) else Result := False;
end;

function TaSmartWizardEngine.Next: Boolean;
var
  St: TaWizardStep;
begin
  if not CanNext then Exit(False);
  St := CurrentStep;
  if St <> nil then St.ExitStep(FCtx);
  Inc(FCurrentIndex);
  St := CurrentStep;
  if St <> nil then St.EnterStep(FCtx);
  Result := True;
end;

function TaSmartWizardEngine.Back: Boolean;
var
  St: TaWizardStep;
begin
  if not CanBack then Exit(False);
  St := CurrentStep;
  if St <> nil then St.ExitStep(FCtx);
  Dec(FCurrentIndex);
  St := CurrentStep;
  if St <> nil then St.EnterStep(FCtx);
  Result := True;
end;

end.
