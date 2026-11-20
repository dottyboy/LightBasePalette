unit ta_components;
{ Nevizualne komponente TyphAccessa za paletu (CodeTyphon / Lazarus). Baca ih se na formu i koriste bez pisanja
  veze s bibliotekom:
    TaDatabase    baza (SQLite, PostgreSQL, MariaDB), upiti, objekti aplikacije i postavke
    TaExpression  racunanje izraza (jezik izraza TyphAccessa), s varijablama i dogadjajem za nepoznate
    TaReport      izvjesce iz baze: pregled, PDF, HTML ili gotova stranicna slika
    TaProgram     4GL program iz baze ili iz teksta; ispis ide u dogadjaj i popis redaka
  Sve rade nad bazom koju zadas svojstvom Database. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Variants, contnrs, ZDataset, ta_meta, ta_expr, ta_exprdb, ta_reportdef, ta_reportengine,
  ta_reportview, ta_reportdesign, ta_fgl;

type
  TaDbEngine = (deSQLite, dePostgres, deMaria);

  { ---------------- TaDatabase ---------------- }

  TaDatabase = class(TComponent)
  private
    FDb: TAppDb;
    FEngine: TaDbEngine;
    FFileName, FHost, FDatabaseName, FUser, FPassword: string;
    FPort: Integer;
    FActive, FDefault: Boolean;
    FAfterOpen, FBeforeClose: TNotifyEvent;
    procedure SetActive(AValue: Boolean);
    procedure SetDefault(AValue: Boolean);
    function GetDb: TAppDb;
  protected
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Open;
    procedure Close;
    function Connected: Boolean;
    { upit koji pozivatelj oslobadja; upit se otvara s .Open }
    function NewQuery(const ASql: string): TZQuery;
    { naredba bez rezultata (INSERT, UPDATE, DDL) }
    procedure ExecSQL(const ASql: string);
    { prva celija prvog retka kao tekst ('' ako nema redaka) }
    function Scalar(const ASql: string): string;
    { nazivi korisnickih tablica (pozivatelj oslobadja) }
    function Tables: TStringList;
    { objekti aplikacije: _sys_forms, _sys_reports, _sys_queries, _sys_programs ... }
    function ObjectNames(const AKind: string): TStringList;
    function LoadObject(const AKind, AName: string): string;
    procedure SaveObject(const AKind, AName, ADefinition: string);
    function Setting(const AKey: string): string;
    procedure SaveSetting(const AKey, AValue: string);
    { sama biblioteka za tekuci izraz, izvjesce i 4GL (Postavka(), DLookup...) }
    property Db: TAppDb read GetDb;
  published
    property Engine: TaDbEngine read FEngine write FEngine default deSQLite;
    { SQLite: datoteka baze; ostalo: ime baze na poslužitelju }
    property FileName: string read FFileName write FFileName;
    property Host: string read FHost write FHost;
    property Port: Integer read FPort write FPort default 0;
    property DatabaseName: string read FDatabaseName write FDatabaseName;
    property User: string read FUser write FUser;
    property Password: string read FPassword write FPassword;
    property Active: Boolean read FActive write SetActive default False;
    { postavi tu bazu kao zadanu za jezik izraza (tvrtka, DLookup, Predict...); zadano da }
    property MakeDefault: Boolean read FDefault write SetDefault default True;
    property AfterOpen: TNotifyEvent read FAfterOpen write FAfterOpen;
    property BeforeClose: TNotifyEvent read FBeforeClose write FBeforeClose;
  end;

  { ---------------- TaExpression ---------------- }

  TaGetVariableEvent = procedure(Sender: TObject; const AName: string; var AValue: Variant; var AHandled: Boolean) of object;
  TaExprErrorEvent = procedure(Sender: TObject; const AMessage: string) of object;

  TaExpression = class(TComponent)
  private
    FDatabase: TaDatabase;
    FExpression: string;
    FVariables: TStrings;
    FLastError: string;
    FRaiseErrors: Boolean;
    FOnGetVariable: TaGetVariableEvent;
    FOnError: TaExprErrorEvent;
    procedure SetDatabase(AValue: TaDatabase);
    procedure SetVariables(AValue: TStrings);
  protected
    procedure Notification(AComponent: TComponent; AOperation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { izracuna svojstvo Expression }
    function Evaluate: Variant; overload;
    { izracuna zadani izraz; pri gresci Null (ili EExpr ako je RaiseErrors) i LastError }
    function Evaluate(const AExpression: string): Variant; overload;
    { prazno kad je izraz sintaksno ispravan, inace poruka }
    function Check(const AExpression: string): string;
    property LastError: string read FLastError;
  published
    property Database: TaDatabase read FDatabase write SetDatabase;
    property Expression: string read FExpression write FExpression;
    { name=value; u izrazu se koriste kao [name] }
    property Variables: TStrings read FVariables write SetVariables;
    property RaiseErrors: Boolean read FRaiseErrors write FRaiseErrors default False;
    property OnGetVariable: TaGetVariableEvent read FOnGetVariable write FOnGetVariable;
    property OnError: TaExprErrorEvent read FOnError write FOnError;
  end;

  { ---------------- TaReport ---------------- }

  TaReport = class(TComponent)
  private
    FDatabase: TaDatabase;
    FReportName: string;
    FParameters: TStrings;
    FLastError: string;
    procedure SetDatabase(AValue: TaDatabase);
    procedure SetParameters(AValue: TStrings);
    function LoadDef: TaReportDef;
    procedure ApplyParameters;
  protected
    procedure Notification(AComponent: TComponent; AOperation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { izvjesce posloženo u stranice (pozivatelj oslobadja); nil uz LastError kad izvjesca nema }
    function Render: TaRenderedReport;
    function ExportPdf(const AFile: string): Boolean;
    function ExportHtml(const AFile: string): Boolean;
    { prozor s pregledom (isti kao u TyphAccessu) }
    procedure Preview;
    { nazivi izvjesca u bazi (pozivatelj oslobadja) }
    function ReportNames: TStringList;
    property LastError: string read FLastError;
  published
    property Database: TaDatabase read FDatabase write SetDatabase;
    property ReportName: string read FReportName write FReportName;
    { name=value za parametre upita [?Naziv]; prazno = nepoznati parametri su NULL }
    property Parameters: TStrings read FParameters write SetParameters;
  end;

  { ---------------- TaProgram ---------------- }

  TaOutputEvent = procedure(Sender: TObject; const AText: string) of object;
  TaPromptEvent = procedure(Sender: TObject; const AQuestion: string; var AAnswer: string; var AOk: Boolean) of object;

  TaProgram = class(TComponent)
  private
    FDatabase: TaDatabase;
    FProgramName: string;
    FSource: TStrings;
    FOutput: TStrings;
    FExitCode: Integer;
    FLastError: string;
    FOnDisplay, FOnMessage, FOnError: TaOutputEvent;
    FOnPrompt: TaPromptEvent;
    procedure SetDatabase(AValue: TaDatabase);
    procedure SetSource(AValue: TStrings);
    function ProgramText: string;
  protected
    procedure Notification(AComponent: TComponent; AOperation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { pokrene program (Source ako je pun, inace program ProgramName iz baze); vraca izlazni kod, 0 = uredu }
    function Run: Integer;
    { provjera bez izvrsavanja: popis problema ("naziv:redak: poruka"), prazan = uredu }
    function Check: TStringList;
    function ProgramNames: TStringList;
    property Output: TStrings read FOutput;
    property ExitCode: Integer read FExitCode;
    property LastError: string read FLastError;
  published
    property Database: TaDatabase read FDatabase write SetDatabase;
    property ProgramName: string read FProgramName write FProgramName;
    property Source: TStrings read FSource write SetSource;
    property OnDisplay: TaOutputEvent read FOnDisplay write FOnDisplay;
    property OnMessage: TaOutputEvent read FOnMessage write FOnMessage;
    property OnError: TaOutputEvent read FOnError write FOnError;
    { odgovor na PROMPT; bez dogadjaja PROMPT je odustajanje }
    property OnPrompt: TaPromptEvent read FOnPrompt write FOnPrompt;
  end;

implementation

uses
  ta_i18n;


{ ---------------- TaDatabase ---------------- }

constructor TaDatabase.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FDb := TAppDb.Create;
  FDefault := True;
end;

destructor TaDatabase.Destroy;
begin
  if (ActiveDb = FDb) then ActiveDb := nil;
  FDb.Free;
  inherited Destroy;
end;

procedure TaDatabase.Loaded;
begin
  inherited Loaded;
  { u vrijeme dizajna se baza ne otvara sama }
  if FActive and not (csDesigning in ComponentState) then
  begin
    FActive := False;
    SetActive(True);
  end;
end;

function TaDatabase.GetDb: TAppDb;
begin
  Result := FDb;
end;

procedure TaDatabase.SetActive(AValue: Boolean);
begin
  if csLoading in ComponentState then begin FActive := AValue; Exit; end;
  if AValue then Open else Close;
end;

procedure TaDatabase.SetDefault(AValue: Boolean);
begin
  FDefault := AValue;
  if FDb.Connected then
    if FDefault then ActiveDb := FDb
    else if ActiveDb = FDb then ActiveDb := nil;
end;

procedure TaDatabase.Open;
begin
  if FDb.Connected then Exit;
  case FEngine of
    dePostgres: FDb.OpenPostgres(FHost, FPort, FDatabaseName, FUser, FPassword);
    deMaria: FDb.OpenMaria(FHost, FPort, FDatabaseName, FUser, FPassword);
  else
    if FFileName = '' then raise Exception.Create(Tr('TaDatabase: FileName is not set'));
    FDb.Open(FFileName);
  end;
  FActive := True;
  if FDefault then ActiveDb := FDb;
  if Assigned(FAfterOpen) then FAfterOpen(Self);
end;

procedure TaDatabase.Close;
begin
  if not FDb.Connected then begin FActive := False; Exit; end;
  if Assigned(FBeforeClose) then FBeforeClose(Self);
  if ActiveDb = FDb then ActiveDb := nil;
  FDb.Close;
  FActive := False;
end;

function TaDatabase.Connected: Boolean;
begin
  Result := FDb.Connected;
end;

function TaDatabase.NewQuery(const ASql: string): TZQuery;
begin
  Result := FDb.NewQuery(ASql);
end;

procedure TaDatabase.ExecSQL(const ASql: string);
begin
  FDb.Conn.ExecuteDirect(ASql);
end;

function TaDatabase.Scalar(const ASql: string): string;
var
  Q: TZQuery;
begin
  Result := '';
  Q := FDb.NewQuery(ASql);
  try
    Q.Open;
    if not Q.Eof then Result := Q.Fields[0].AsString;
  finally
    Q.Free;
  end;
end;

function TaDatabase.Tables: TStringList;
begin
  Result := FDb.UserTables;
end;

function TaDatabase.ObjectNames(const AKind: string): TStringList;
begin
  Result := FDb.ListObjects(AKind);
end;

function TaDatabase.LoadObject(const AKind, AName: string): string;
begin
  Result := FDb.LoadObject(AKind, AName);
end;

procedure TaDatabase.SaveObject(const AKind, AName, ADefinition: string);
begin
  FDb.SaveObject(AKind, AName, ADefinition);
end;

function TaDatabase.Setting(const AKey: string): string;
begin
  Result := FDb.LoadSetting(AKey);
end;

procedure TaDatabase.SaveSetting(const AKey, AValue: string);
begin
  FDb.SaveSetting(AKey, AValue);
end;

{ ---------------- TaExpression ---------------- }

type
  TCompHost = class(TaExprHost)
  public
    Owner: TaExpression;
    Vars: TStrings;
    function FieldValue(const AName: string): Variant; override;
    function Aggregate(const AFunc, AField: string): Variant; override;
    function Variable(const AName: string): Variant; override;
    function Domain(const AFunc, AExpr, ADomain, ACriteria: string): Variant; override;
  end;

function TCompHost.FieldValue(const AName: string): Variant;
begin
  Result := Variable(AName);
end;

function TCompHost.Domain(const AFunc, AExpr, ADomain, ACriteria: string): Variant;
begin
  if (Owner.FDatabase <> nil) and Owner.FDatabase.Connected then
    Result := DbDomain(Owner.FDatabase.Db, AFunc, AExpr, ADomain, ACriteria)
  else Result := Null;
end;

function TCompHost.Aggregate(const AFunc, AField: string): Variant;
begin
  Result := Null;
end;

function TCompHost.Variable(const AName: string): Variant;
var
  I: Integer;
  Handled: Boolean;
begin
  for I := 0 to Vars.Count - 1 do
    if SameText(Vars.Names[I], AName) then Exit(Vars.ValueFromIndex[I]);
  Result := Null;
  Handled := False;
  if Assigned(Owner.FOnGetVariable) then Owner.FOnGetVariable(Owner, AName, Result, Handled);
  if not Handled then Result := Null;
end;

constructor TaExpression.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FVariables := TStringList.Create;
end;

destructor TaExpression.Destroy;
begin
  FVariables.Free;
  inherited Destroy;
end;

procedure TaExpression.SetDatabase(AValue: TaDatabase);
begin
  if FDatabase = AValue then Exit;
  FDatabase := AValue;
  if FDatabase <> nil then FDatabase.FreeNotification(Self);
end;

procedure TaExpression.SetVariables(AValue: TStrings);
begin
  FVariables.Assign(AValue);
end;

procedure TaExpression.Notification(AComponent: TComponent; AOperation: TOperation);
begin
  inherited Notification(AComponent, AOperation);
  if (AOperation = opRemove) and (AComponent = FDatabase) then FDatabase := nil;
end;

function TaExpression.Evaluate: Variant;
begin
  Result := Evaluate(FExpression);
end;

function TaExpression.Evaluate(const AExpression: string): Variant;
var
  H: TCompHost;
  Err: string;
  Saved: TAppDb;
begin
  FLastError := '';
  H := TCompHost.Create;
  Saved := ActiveDb;
  try
    H.Owner := Self;
    H.Vars := FVariables;
    if (FDatabase <> nil) and FDatabase.Connected then ActiveDb := FDatabase.Db;
    Result := EvalExprEx(AExpression, H, Err);
  finally
    ActiveDb := Saved;
    H.Free;
  end;
  if Err <> '' then
  begin
    FLastError := Err;
    Result := Null;
    if Assigned(FOnError) then FOnError(Self, Err);
    if FRaiseErrors then raise EExpr.Create(Err);
  end;
end;

function TaExpression.Check(const AExpression: string): string;
begin
  Result := CheckExpr(AExpression);
end;

{ ---------------- TaReport ---------------- }

constructor TaReport.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FParameters := TStringList.Create;
end;

destructor TaReport.Destroy;
begin
  FParameters.Free;
  inherited Destroy;
end;

procedure TaReport.SetDatabase(AValue: TaDatabase);
begin
  if FDatabase = AValue then Exit;
  FDatabase := AValue;
  if FDatabase <> nil then FDatabase.FreeNotification(Self);
end;

procedure TaReport.SetParameters(AValue: TStrings);
begin
  FParameters.Assign(AValue);
end;

procedure TaReport.Notification(AComponent: TComponent; AOperation: TOperation);
begin
  inherited Notification(AComponent, AOperation);
  if (AOperation = opRemove) and (AComponent = FDatabase) then FDatabase := nil;
end;

function TaReport.LoadDef: TaReportDef;
var
  Js: string;
begin
  Result := nil;
  FLastError := '';
  if (FDatabase = nil) or not FDatabase.Connected then begin FLastError := Tr('The database is not open'); Exit; end;
  Js := FDatabase.Db.LoadObject('_sys_reports', FReportName);
  if Js = '' then begin FLastError := Tr('There is no report: ') + FReportName; Exit; end;
  Result := TaReportDef.Create;
  Result.FromJson(Js);
  Result.Name := FReportName;
end;

procedure TaReport.ApplyParameters;
var
  I: Integer;
begin
  FDatabase.Db.ClearParams;
  for I := 0 to FParameters.Count - 1 do
    FDatabase.Db.ParamValues.Values[FParameters.Names[I]] := FParameters.ValueFromIndex[I];
  if FParameters.Count > 0 then Inc(FDatabase.Db.QuietParams);
end;

function TaReport.Render: TaRenderedReport;
var
  Def: TaReportDef;
  Eng: TaReportEngine;
begin
  Result := nil;
  Def := LoadDef;
  if Def = nil then Exit;
  try
    ApplyParameters;
    try
      Eng := TaReportEngine.Create(FDatabase.Db, Def);
      try
        Result := Eng.Render;
      finally
        Eng.Free;
      end;
    finally
      if FParameters.Count > 0 then Dec(FDatabase.Db.QuietParams);
    end;
  finally
    Def.Free;
  end;
end;

function TaReport.ExportPdf(const AFile: string): Boolean;
var
  Rep: TaRenderedReport;
begin
  Result := False;
  Rep := Render;
  if Rep = nil then Exit;
  try
    ForceDirectories(ExtractFilePath(ExpandFileName(AFile)));
    Result := ta_reportview.ExportPdf(Rep, AFile, FLastError);
  finally
    Rep.Free;
  end;
end;

function TaReport.ExportHtml(const AFile: string): Boolean;
var
  Rep: TaRenderedReport;
begin
  Result := False;
  Rep := Render;
  if Rep = nil then Exit;
  try
    ForceDirectories(ExtractFilePath(ExpandFileName(AFile)));
    Result := ta_reportview.ExportHtml(Rep, AFile);
    if not Result then FLastError := Tr('The file was not saved.');
  finally
    Rep.Free;
  end;
end;

procedure TaReport.Preview;
var
  Def: TaReportDef;
begin
  Def := LoadDef;
  if Def = nil then Exit;
  try
    ApplyParameters;
    try
      ShowReportPreview(Owner, FDatabase.Db, Def, '');
    finally
      if FParameters.Count > 0 then Dec(FDatabase.Db.QuietParams);
    end;
  finally
    Def.Free;
  end;
end;

function TaReport.ReportNames: TStringList;
begin
  if (FDatabase <> nil) and FDatabase.Connected then Result := FDatabase.Db.ListObjects('_sys_reports')
  else Result := TStringList.Create;
end;

{ ---------------- TaProgram ---------------- }

type
  TCompFglIO = class(TaFglIO)
  public
    Owner: TaProgram;
    procedure Display(const S: string); override;
    procedure Message(const S: string); override;
    procedure Error(const S: string); override;
    function Ask(const AText: string): Boolean; override;
    function Prompt(const AText: string; var AValue: string): Boolean; override;
  end;

procedure TCompFglIO.Display(const S: string);
begin
  Owner.FOutput.Add(S);
  if Assigned(Owner.FOnDisplay) then Owner.FOnDisplay(Owner, S);
end;

procedure TCompFglIO.Message(const S: string);
begin
  Owner.FOutput.Add(S);
  if Assigned(Owner.FOnMessage) then Owner.FOnMessage(Owner, S)
  else if Assigned(Owner.FOnDisplay) then Owner.FOnDisplay(Owner, S);
end;

procedure TCompFglIO.Error(const S: string);
begin
  Owner.FOutput.Add('! ' + S);
  Owner.FLastError := S;
  if Assigned(Owner.FOnError) then Owner.FOnError(Owner, S)
  else if Assigned(Owner.FOnDisplay) then Owner.FOnDisplay(Owner, '! ' + S);
end;

function TCompFglIO.Ask(const AText: string): Boolean;
var
  A: string;
  Ok: Boolean;
begin
  Result := True;
  if Assigned(Owner.FOnPrompt) then
  begin
    A := ''; Ok := True;
    Owner.FOnPrompt(Owner, AText, A, Ok);
    Result := Ok;
  end;
end;

function TCompFglIO.Prompt(const AText: string; var AValue: string): Boolean;
var
  Ok: Boolean;
begin
  Result := False;
  if Assigned(Owner.FOnPrompt) then
  begin
    Ok := True;
    Owner.FOnPrompt(Owner, AText, AValue, Ok);
    Result := Ok;
  end;
end;

constructor TaProgram.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FSource := TStringList.Create;
  FOutput := TStringList.Create;
end;

destructor TaProgram.Destroy;
begin
  FSource.Free;
  FOutput.Free;
  inherited Destroy;
end;

procedure TaProgram.SetDatabase(AValue: TaDatabase);
begin
  if FDatabase = AValue then Exit;
  FDatabase := AValue;
  if FDatabase <> nil then FDatabase.FreeNotification(Self);
end;

procedure TaProgram.SetSource(AValue: TStrings);
begin
  FSource.Assign(AValue);
end;

procedure TaProgram.Notification(AComponent: TComponent; AOperation: TOperation);
begin
  inherited Notification(AComponent, AOperation);
  if (AOperation = opRemove) and (AComponent = FDatabase) then FDatabase := nil;
end;

function TaProgram.ProgramText: string;
begin
  if Trim(FSource.Text) <> '' then Result := FSource.Text
  else if (FDatabase <> nil) and FDatabase.Connected then Result := FDatabase.Db.LoadObject('_sys_programs', FProgramName)
  else Result := '';
end;

function TaProgram.ProgramNames: TStringList;
begin
  if (FDatabase <> nil) and FDatabase.Connected then Result := FDatabase.Db.ListObjects('_sys_programs')
  else Result := TStringList.Create;
end;

function TaProgram.Check: TStringList;
var
  P: TaFglProgram;
  Txt: string;
begin
  Result := TStringList.Create;
  Txt := ProgramText;
  if Txt = '' then begin Result.Add(Tr('There is no program')); Exit; end;
  P := TaFglProgram.Create;
  try
    try
      P.LoadText(Txt, 'program');
      P.CheckProgram(Result);
    except
      on E: Exception do Result.Add(E.Message);
    end;
  finally
    P.Free;
  end;
end;

function TaProgram.Run: Integer;
var
  P: TaFglProgram;
  Lg: TStringList;
  IO: TCompFglIO;
  R: TaFglRunner;
  Txt: string;
  Saved: TAppDb;
begin
  FOutput.Clear;
  FLastError := '';
  FExitCode := 1;
  Result := 1;
  if (FDatabase = nil) or not FDatabase.Connected then begin FLastError := Tr('The database is not open'); Exit; end;
  Txt := ProgramText;
  if Txt = '' then begin FLastError := Tr('There is no 4GL program: ') + FProgramName; Exit; end;
  P := TaFglProgram.Create;
  Lg := TStringList.Create;
  Saved := ActiveDb;
  try
    try
      P.LoadText(Txt, 'program');
    except
      on E: Exception do begin FLastError := E.Message; FOutput.Add('! ' + E.Message); Exit; end;
    end;
    if P.CheckProgram(Lg) > 0 then
    begin
      FLastError := Trim(Lg.Text);
      FOutput.AddStrings(Lg);
      Exit;
    end;
    IO := TCompFglIO.Create;
    try
      IO.Owner := Self;
      ActiveDb := FDatabase.Db;
      R := TaFglRunner.Create(P, FDatabase.Db, IO);
      try
        Result := R.Run;
      finally
        R.Free;
      end;
    finally
      IO.Free;
    end;
  finally
    ActiveDb := Saved;
    Lg.Free;
    P.Free;
  end;
  FExitCode := Result;
end;

end.
