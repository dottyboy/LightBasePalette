unit ta_fgl;
{ TyphAccess 4GL: jezik u duhu Informix-4GL-a (vidi docs/4GL-SPEC.md).
  Ovdje su lexer, parser i tumac nad stablom. Sve sto korisnik vidi ili unosi
  ide kroz TaFglIO, pa isti program radi u prozoru, u konzoli i u testu. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Variants, Math, DB, ZDataset, ZDatasetParam, contnrs, LazUTF8, FileUtil,
  ta_meta, ta_params, ta_expr, ta_exprdb, ta_parse, ta_script;

type
  EFglError = class(Exception)
  public
    FileName: string;
    Line, Col: Integer;
  end;

  { ---------- ulaz/izlaz ---------- }
  { Polje zaslona onako kako ga vidi I/O sloj. }
  TaFglField = class
  public
    Name, Caption, Hint: string;
    ReadOnly, Required, Upshift: Boolean;
    LookupKeys, LookupLabels: TStringList;   { nil kad nema LOOKUP }
    constructor Create;
    destructor Destroy; override;
  end;

  TaFglIO = class
  public
    { polja zaslona; AValues[i] pripada AFields[i] }
    function InputFields(const ATitle: string; AFields: TObjectList; AValues: TStrings;
      const AFocus: string; AReadOnly: Boolean): Boolean; virtual;
    { mreza: ARows je popis TStringList (vrijednosti po poljima); ACurrent je 1-based }
    function Grid(const ATitle: string; AFields: TObjectList; ARows: TObjectList;
      AEditable: Boolean; var ACurrent: Integer): Boolean; virtual;
    procedure Display(const S: string); virtual; abstract;
    procedure Message(const S: string); virtual;
    procedure Error(const S: string); virtual;
    function Ask(const AText: string): Boolean; virtual;
    function Prompt(const AText: string; var AValue: string): Boolean; virtual;
    { vraca indeks naredbe ili -1 kad je izbornik zatvoren }
    function Menu(const ATitle: string; ANames, AHelps: TStrings): Integer; virtual;
    { AValues[i] pripada ANames[i]; False = odustao }
    function Input(const ATitle: string; ANames, AValues: TStrings; const AFocus: string;
      AReadOnly: Boolean): Boolean; virtual;
    function Construct(const ATitle: string; AColumns, AValues: TStrings): Boolean; virtual;
    { stranice izvješća: TStringList redaka po stranici }
    procedure ShowReport(const ATitle: string; APages: TObjectList); virtual;
    procedure RunForm(ADb: TAppDb; const AFormName, AFilter: string); virtual;
    procedure Finish; virtual;
  end;

  { Konzola: ispis na stdout, odgovori sa stdin. }
  TaFglConsoleIO = class(TaFglIO)
  public
    procedure Display(const S: string); override;
    procedure Message(const S: string); override;
    procedure Error(const S: string); override;
    function Ask(const AText: string): Boolean; override;
    function Prompt(const AText: string; var AValue: string): Boolean; override;
    function Menu(const ATitle: string; ANames, AHelps: TStrings): Integer; override;
    function Input(const ATitle: string; ANames, AValues: TStrings; const AFocus: string;
      AReadOnly: Boolean): Boolean; override;
    function Construct(const ATitle: string; AColumns, AValues: TStrings): Boolean; override;
    function Grid(const ATitle: string; AFields: TObjectList; ARows: TObjectList;
      AEditable: Boolean; var ACurrent: Integer): Boolean; override;
    function InputFields(const ATitle: string; AFields: TObjectList; AValues: TStrings;
      const AFocus: string; AReadOnly: Boolean): Boolean; override;
  end;

  { Za testove: odgovori iz redova, ispis u Out. Redovi odgovora:
      MenuAnswers: nazivi naredbi; PromptAnswers: tekst ili <cancel>;
      InputAnswers/ConstructAnswers: "polje=vrijednost|polje=vrijednost" ili <cancel>;
      AskAnswers: da/ne. Kad je red prazan, izbornik se zatvori, a ostalo odustane. }
  TaFglScriptIO = class(TaFglIO)
  public
    Out: TStringList;
    MenuAnswers, PromptAnswers, InputAnswers, ConstructAnswers, AskAnswers, GridAnswers: TStringList;
    FormsRun: TStringList;
    constructor Create;
    destructor Destroy; override;
    procedure Display(const S: string); override;
    procedure Message(const S: string); override;
    procedure Error(const S: string); override;
    function Ask(const AText: string): Boolean; override;
    function Prompt(const AText: string; var AValue: string): Boolean; override;
    function Menu(const ATitle: string; ANames, AHelps: TStrings): Integer; override;
    function Input(const ATitle: string; ANames, AValues: TStrings; const AFocus: string;
      AReadOnly: Boolean): Boolean; override;
    function Construct(const ATitle: string; AColumns, AValues: TStrings): Boolean; override;
    function Grid(const ATitle: string; AFields: TObjectList; ARows: TObjectList;
      AEditable: Boolean; var ACurrent: Integer): Boolean; override;
    function InputFields(const ATitle: string; AFields: TObjectList; AValues: TStrings;
      const AFocus: string; AReadOnly: Boolean): Boolean; override;
    procedure RunForm(ADb: TAppDb; const AFormName, AFilter: string); override;
  end;

  { Rezultat programa koji se koristi kao izvor podataka (naredbe COLUMNS i EMIT). }
  TaFglResult = class
  public
    ColNames, ColTypes: TStringList;     { tip: int, float, text, date, datetime, bool }
    Rows: array of array of Variant;
    RowCount: Integer;
    MaxRows: Integer;
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure AddColumn(const AName, AType: string);
    procedure AddRow(const AValues: array of Variant);
  end;

  { I/O izvora: bez dijaloga. Svaki pokusaj unosa je greska s jasnom porukom; ispis se skuplja u Log. }
  TaFglSourceIO = class(TaFglIO)
  public
    Log: TStringList;
    constructor Create;
    destructor Destroy; override;
    procedure Display(const S: string); override;
    function Ask(const AText: string): Boolean; override;
    function Prompt(const AText: string; var AValue: string): Boolean; override;
    function Menu(const ATitle: string; ANames, AHelps: TStrings): Integer; override;
    function Input(const ATitle: string; ANames, AValues: TStrings; const AFocus: string;
      AReadOnly: Boolean): Boolean; override;
    function Construct(const ATitle: string; AColumns, AValues: TStrings): Boolean; override;
    function Grid(const ATitle: string; AFields: TObjectList; ARows: TObjectList;
      AEditable: Boolean; var ACurrent: Integer): Boolean; override;
    function InputFields(const ATitle: string; AFields: TObjectList; AValues: TStrings;
      const AFocus: string; AReadOnly: Boolean): Boolean; override;
    procedure RunForm(ADb: TAppDb; const AFormName, AFilter: string); override;
  end;

  { ---------- tipovi i stablo ---------- }
  TFglTypeKind = (tyAny, tyInt, tyFloat, tyText, tyDate, tyDateTime, tyBool, tyRecord, tyArray);

  TFglType = class
  public
    Kind: TFglTypeKind;
    FieldNames: TStringList;     { RECORD ... END RECORD }
    FieldTypes: TObjectList;     { TFglType, ne vlasnik }
    LikeTable, LikeCol: string;  { LIKE tablica.* ili tablica.stupac }
    Elem: TFglType;
    Size: Integer;               { ARRAY[n]; 0 = dinamicko }
    constructor Create(AKind: TFglTypeKind);
    destructor Destroy; override;
  end;

  TNodeKind = (
    nkLit, nkVar, nkField, nkIndex, nkCall, nkBin, nkUn, nkIsNull, nkBetween, nkInList, nkUsing,
    nkLet, nkIf, nkWhile, nkFor, nkForeach, nkCase, nkWhen, nkMenu, nkCommand, nkReturn,
    nkExit, nkContinue, nkNextField, nkDefine, nkSql, nkDeclare, nkOpen, nkFetch, nkClose,
    nkFree, nkPrepare, nkExecute, nkTrans, nkDisplay, nkDisplayName, nkDisplayForm, nkOpenForm,
    nkMessage, nkError, nkPrompt, nkInput, nkClause, nkConstruct, nkWhenever, nkInitialize,
    nkSleep, nkExitProgram, nkCallStmt, nkDisplayArray, nkInputArray, nkAggregate, nkPrint,
    nkColumn, nkSkip, nkNeed, nkStartReport, nkOutputReport, nkFinishReport, nkColumns, nkEmit);

  TNode = class
  public
    Kind: TNodeKind;
    Text, Text2: string;
    V: Variant;
    A, B, C, D: TNode;
    L1, L2, L3: TFPList;
    Names: TStringList;
    Typ: TFglType;
    Flag: Boolean;
    Line, Col, Src, Idx: Integer;
    destructor Destroy; override;
  end;

  TFglFunc = class
  public
    Name: string;
    Params: TStringList;
    ParamTypes: TList;
    Body: TFPList;
    Declared, Used: TStringList;   { Used: naziv=redak }
    Line, Src: Integer;
    constructor Create;
    destructor Destroy; override;
  end;

  TFglGroupBlock = class
  public
    KeyIdx: Integer;
    Before: Boolean;
    Body: TFPList;
    destructor Destroy; override;
  end;

  TFglReport = class
  public
    Name: string;
    Params: TStringList;
    Defines: TFPList;
    Keys: TFPList;               { izrazi ključeva }
    KeyTexts: TStringList;
    KeyDesc: TList;              { Pointer(1) = silazno }
    External: Boolean;
    PageLength, LeftMargin, TopMargin, BottomMargin: Integer;
    FirstHeader, PageHeader, PageTrailer, OnEveryRow, OnLastRow: TFPList;
    Groups: TObjectList;
    Aggs: TFPList;
    Func: TFglFunc;
    Line, Src: Integer;
    constructor Create;
    destructor Destroy; override;
    function KeyIndex(const AText: string): Integer;
  end;

  TFglScreenField = class
  public
    Name, Caption, Hint: string;
    ReadOnly, Required, Upshift: Boolean;
    Default: TNode;
    LookupTable, LookupKey, LookupLabel: string;
  end;

  TFglScreen = class
  public
    Name, Title: string;
    Fields: TObjectList;
    Line, Src: Integer;
    constructor Create;
    destructor Destroy; override;
  end;


  TaFglProgram = class
  private
    FOwned: TObjectList;
    procedure ParseSource(const ASource, AFile: string);
    procedure Check(ALog: TStrings; var AErrors: Integer);
  public
    Files: TStringList;
    Funcs: TStringList;          { mala slova -> TFglFunc }
    Main: TFglFunc;
    GlobalStmts: TFPList;
    GlobalNames: TStringList;
    DeclCursors, UsedCursors: TStringList;
    Screens: TStringList;        { mala slova -> TFglScreen }
    UsedScreens: TStringList;
    Reports: TStringList;        { mala slova -> TFglReport }
    UsedReports: TStringList;
    DatabaseName: string;
    constructor Create;
    destructor Destroy; override;
    function NewNode(AKind: TNodeKind): TNode;
    function NewType(AKind: TFglTypeKind): TFglType;
    { baca EFglError kod prve greske }
    procedure LoadFile(const AFile: string);
    procedure LoadText(const AText, AName: string);
    { staticka provjera; vraca broj gresaka }
    function CheckProgram(ALog: TStrings): Integer;
  end;

  { ---------- tumac ---------- }
  TFglCellKind = (ckScalar, ckRecord, ckArray);

  TFglCell = class
  public
    Kind: TFglCellKind;
    V: Variant;
    Ty: TFglTypeKind;
    Names: TStringList;
    Items: TObjectList;     { polja zapisa ili elementi polja }
    ElemType: TFglType;
    Size: Integer;
    constructor Create(AKind: TFglCellKind);
    destructor Destroy; override;
  end;

  TVariantArray = array of Variant;

  TFglFlow = (flNone, flExit, flContinue, flReturn, flExitProgram);


  TFglFrame = class
  public
    Vars: TStringList;      { naziv (mala slova) -> TFglCell, vlasnik }
    Ret: array of Variant;
    constructor Create;
    destructor Destroy; override;
  end;

  TFglAcc = record
    Count: Integer;
    Sum: Double;
    Min, Max: Variant;
  end;

  TFglReportRun = class
  public
    Rep: TFglReport;
    Kind, Path: string;
    Rows: array of TVariantArray;
    RowCount: Integer;
    Pages: TObjectList;
    CurLines: TStringList;
    CurText: string;
    PageNo, Level, TrailerLines: Integer;
    InBreak: Boolean;
    Acc: array of array of TFglAcc;     { [agg][razina 0..K] }
    Cells: TList;                      { spljošteni parametri }
    Frame: TFglFrame;                  { okvir s parametrima izvješća }
    Prepared, PageStarted, HasPrev, Stream: Boolean;
    PrevKeys, PrevRow: TVariantArray;
    TotalRows: Integer;
    constructor Create;
    destructor Destroy; override;
  end;

  TFglCursor = class
  public
    Name: string;
    Decl: TNode;            { nkSql ili prepared }
    PreparedName: string;
    Q: TZQuery;
    Open: Boolean;
    destructor Destroy; override;
  end;

  TaFglRunner = class
  private
    FProg: TaFglProgram;
    FDb: TAppDb;
    FSavedActiveDb: TAppDb;
    FIO: TaFglIO;
    FGlobals: TFglFrame;
    FFrames: TObjectList;
    FCursors: TStringList;
    FPrepared: TStringList;      { naziv -> sql sa :pN }
    FFlow: TFglFlow;
    FFlowKind: string;
    FNextField: string;
    FContinueOnError: Boolean;
    FScripts: TaScripts;
    FScriptCtx: TaScriptContext;
    FForms: TStringList;         { varijabla forme -> naziv forme }
    FExitCode: Integer;
    FDepth: Integer;
    FCollector: TaFglResult;
    FDeadlineAt: Int64;
    FTimeLimitMs: Integer;
    FExiting: Boolean;
    FPreparedSql: TStringList;
    FLikeCache: TStringList;
    FReports: TStringList;       { naziv -> TFglReportRun (pokrenuta izvješća) }
    FRun: TFglReportRun;         { izvješće koje se trenutno ispisuje }
    function Frame: TFglFrame;
    function FindCell(const AName: string): TFglCell;
    procedure Fail(N: TNode; const AMsg: string);
    function NewCell(ATy: TFglType; AAt: TNode): TFglCell;
    function LikeRecordType(const ATable: string; AAt: TNode): TFglType;
    procedure FlattenNamed(ACell: TFglCell; const AName: string; AOut: TList; ANames: TStrings);
    procedure SetIntFlag(AValue: Boolean);
    function ExecStmt(N: TNode): TFglFlow;
    procedure ExecInitializeCell(ACell: TFglCell);
    function EvalListToArray(L: TFPList): TVariantArray;
    function ResolveVar(N: TNode; AAutoGrow: Boolean): TFglCell;
    procedure Flatten(ACell: TFglCell; AOut: TList);
    procedure FlattenNodes(AList: TFPList; AOut: TList; ANames: TStrings);
    procedure SetCell(ACell: TFglCell; const V: Variant);
    procedure CopyRecord(ADst, ASrc: TFglCell);
    function Eval(N: TNode): Variant;
    function EvalBin(N: TNode): Variant;
    function CallFunction(N: TNode; const AName: string; const AArgs: array of Variant;
      out AResult: Variant): Boolean;
    function CallUser(F: TFglFunc; const AArgs: array of Variant; AAt: TNode): TFglFrame;
    function BuiltinFunc(const AName: string; const AArgs: array of Variant; out AResult: Variant): Boolean;
    function AccessFunc(N: TNode; const AName: string; const AArgs: array of Variant): Variant;
    function Exec(N: TNode): TFglFlow;
    function ExecList(L: TFPList): TFglFlow;
    procedure ExecDefine(N: TNode);
    procedure ExecLet(N: TNode);
    function ExecIf(N: TNode): TFglFlow;
    function ExecWhile(N: TNode): TFglFlow;
    function ExecFor(N: TNode): TFglFlow;
    function ExecForeach(N: TNode): TFglFlow;
    function ExecCase(N: TNode): TFglFlow;
    function ExecMenu(N: TNode): TFglFlow;
    function ExecInput(N: TNode): TFglFlow;
    procedure ExecConstruct(N: TNode);
    procedure ExecArray(N: TNode; AEdit: Boolean);
    procedure ExecStartReport(N: TNode);
    procedure ExecOutputReport(N: TNode);
    procedure ExecFinishReport(N: TNode);
    procedure ExecPrint(N: TNode);
    procedure ExecSkip(N: TNode);
    procedure ExecNeed(N: TNode);
    procedure ReportPrepare(R: TFglReportRun; AAt: TNode);
    procedure ReportFeed(R: TFglReportRun; const Row: TVariantArray; AAt: TNode);
    procedure ReportEnd(R: TFglReportRun);
    procedure LoadRowCells(R: TFglReportRun; const Row: TVariantArray; AAt: TNode);
    function ReportKeys(R: TFglReportRun): TVariantArray;
    procedure GroupBlocks(R: TFglReportRun; AKey: Integer; ABefore: Boolean);
    function ReportCapacity(R: TFglReportRun): Integer;
    procedure ReportNewPage(R: TFglReportRun);
    procedure ReportText(const S: string);
    procedure ReportColumn(ACol: Integer);
    procedure ReportNewline;
    procedure ReportPageBreak;
    procedure ReportStartPage;
    procedure ReportBlock(L: TFPList; ALevel: Integer);
    function AggValue(N: TNode): Variant;
    function BuildFields(const AScreen: string; ANames: TStrings; ACells: TList;
      AUse: TList; AAt: TNode): TObjectList;
    function FindScreen(const AName: string; AAt: TNode): TFglScreen;
    procedure ExecPrompt(N: TNode);
    procedure ExecDisplay(N: TNode);
    procedure ExecCall(N: TNode);
    procedure ExecSql(N: TNode);
    procedure ExecTrans(N: TNode);
    procedure ExecDeclare(N: TNode);
    procedure ExecPrepare(N: TNode);
    procedure ExecExecute(N: TNode);
    procedure ExecOpen(N: TNode);
    procedure ExecFetch(N: TNode);
    procedure ExecClose(N: TNode; AFree: Boolean);
    procedure ExecInitialize(N: TNode);
    function BindQuery(const ASql: string; AParams: TFPList; const AExtra: array of Variant; AAt: TNode): TZQuery;
    procedure BindValue(P: TZParam; const V: Variant);
    function FieldValue(F: TField): Variant;
    procedure AssignRow(Q: TZQuery; ATargets: TList; AAt: TNode);
    procedure SetSqlStatus(ACode, ARows: Integer; const AMsg: string);
    function FindCursor(const AName: string; AAt: TNode): TFglCursor;
    procedure OpenCursor(C: TFglCursor; const AExtra: array of Variant; AAt: TNode);
  public
    constructor Create(AProg: TaFglProgram; ADb: TAppDb; AIO: TaFglIO);
    destructor Destroy; override;
    { izvrsi GLOBALS pa MAIN; vraca izlazni kod (0 = u redu, 1 = greska) }
    function Run: Integer;
    { izvrsi jednu funkciju (ili MAIN kad je AName prazno) i vrati vrijednosti iz RETURN; GLOBALS se izvrse prije;
      greske se vracaju u AErr, ne dize se izuzetak }
    function CallFunc(const AName: string; const AArgs: array of Variant; out ARet: TVariantArray;
      out AErr: string): Boolean;
    property ExitCode: Integer read FExitCode;
    { kad je postavljen, COLUMNS i EMIT pune rezultat (program kao izvor podataka) }
    property Collector: TaFglResult read FCollector write FCollector;
    { najdulje trajanje izvrsavanja u ms (0 = bez ogranicenja) }
    property TimeLimitMs: Integer read FTimeLimitMs write FTimeLimitMs;
  end;

var
  { PDF iz tekstualnih stranica izvješća (postavlja ta_fglgui) }
  FglPdfHook: function(APages: TObjectList; const AFile: string; out AErr: string): Boolean = nil;
  { ispis na pisač: APrinter prazno = zadani pisač (postavlja ta_fglgui) }
  FglPrintHook: function(APages: TObjectList; const APrinter: string; out AErr: string): Boolean = nil;

function FglAsText(const V: Variant): string;
function FglUsingNumber(D: Double; const AFmt: string): string;
{ Ucita i provjeri program; poruke u ALog. Vraca broj gresaka (parser: 1). }
function FglCheckFile(const AFile: string; ALog: TStrings): Integer;
function FglConstructToSql(const AColumns, AValues: TStrings): string;

implementation

uses
  ta_i18n,
  StrUtils, Process;

const
  Q_ = '''';

{ ============================ IO ============================ }

procedure TaFglIO.Message(const S: string);
begin
  Display(S);
end;

procedure TaFglIO.Error(const S: string);
begin
  Display('GREŠKA: ' + S);
end;

function TaFglIO.Ask(const AText: string): Boolean;
begin
  Result := False;
end;

function TaFglIO.Prompt(const AText: string; var AValue: string): Boolean;
begin
  Result := False;
end;

function TaFglIO.Menu(const ATitle: string; ANames, AHelps: TStrings): Integer;
begin
  Result := -1;
end;

function TaFglIO.Input(const ATitle: string; ANames, AValues: TStrings; const AFocus: string;
  AReadOnly: Boolean): Boolean;
begin
  Result := False;
end;

function TaFglIO.Construct(const ATitle: string; AColumns, AValues: TStrings): Boolean;
begin
  Result := False;
end;

constructor TaFglField.Create;
begin
end;

destructor TaFglField.Destroy;
begin
  LookupKeys.Free;
  LookupLabels.Free;
  inherited Destroy;
end;

function TaFglIO.InputFields(const ATitle: string; AFields: TObjectList; AValues: TStrings;
  const AFocus: string; AReadOnly: Boolean): Boolean;
var
  Names, Vals: TStringList;
  I: Integer;
begin
  Names := TStringList.Create;
  Vals := TStringList.Create;
  try
    for I := 0 to AFields.Count - 1 do
    begin
      Names.Add(TaFglField(AFields[I]).Name);
      Vals.Add(AValues[I]);
    end;
    Result := Input(ATitle, Names, Vals, AFocus, AReadOnly);
    if Result and not AReadOnly then
      for I := 0 to AFields.Count - 1 do
        if not TaFglField(AFields[I]).ReadOnly then AValues[I] := Vals[I];
  finally
    Names.Free;
    Vals.Free;
  end;
end;

function TaFglIO.Grid(const ATitle: string; AFields: TObjectList; ARows: TObjectList;
  AEditable: Boolean; var ACurrent: Integer): Boolean;
begin
  Result := False;
end;

procedure TaFglIO.ShowReport(const ATitle: string; APages: TObjectList);
var
  I, J: Integer;
begin
  for I := 0 to APages.Count - 1 do
  begin
    Display('=== ' + ATitle + ', stranica ' + IntToStr(I + 1) + ' ===');
    for J := 0 to TStringList(APages[I]).Count - 1 do Display(TStringList(APages[I])[J]);
  end;
end;

procedure TaFglIO.RunForm(ADb: TAppDb; const AFormName, AFilter: string);
begin
  Error('Forme se mogu otvoriti samo u grafičkom načinu: ' + AFormName);
end;

procedure TaFglIO.Finish;
begin
end;

{ ---------------- izvor podataka: rezultat i I/O ---------------- }

constructor TaFglResult.Create;
begin
  ColNames := TStringList.Create;
  ColTypes := TStringList.Create;
  MaxRows := 100000;
end;

destructor TaFglResult.Destroy;
begin
  ColNames.Free;
  ColTypes.Free;
  inherited Destroy;
end;

procedure TaFglResult.Clear;
begin
  ColNames.Clear;
  ColTypes.Clear;
  SetLength(Rows, 0);
  RowCount := 0;
end;

procedure TaFglResult.AddColumn(const AName, AType: string);
begin
  ColNames.Add(AName);
  ColTypes.Add(AType);
end;

procedure TaFglResult.AddRow(const AValues: array of Variant);
var
  I: Integer;
begin
  if RowCount >= MaxRows then
    raise EFglError.Create('Izvor je prekoracio najveci broj redaka (' + IntToStr(MaxRows) + ')');
  if RowCount >= Length(Rows) then SetLength(Rows, Length(Rows) * 2 + 16);
  SetLength(Rows[RowCount], Length(AValues));
  for I := 0 to High(AValues) do Rows[RowCount][I] := AValues[I];
  Inc(RowCount);
end;

constructor TaFglSourceIO.Create;
begin
  inherited Create;
  Log := TStringList.Create;
end;

destructor TaFglSourceIO.Destroy;
begin
  Log.Free;
  inherited Destroy;
end;

procedure TaFglSourceIO.Display(const S: string);
begin
  Log.Add(S);
end;

function TaFglSourceIO.Ask(const AText: string): Boolean;
begin
  raise EFglError.Create('Pitanje korisniku nije dopusteno unutar izvora podataka');
end;

function TaFglSourceIO.Prompt(const AText: string; var AValue: string): Boolean;
begin
  raise EFglError.Create('PROMPT nije dopusten unutar izvora podataka');
end;

function TaFglSourceIO.Menu(const ATitle: string; ANames, AHelps: TStrings): Integer;
begin
  raise EFglError.Create('MENU nije dopusten unutar izvora podataka');
end;

function TaFglSourceIO.Input(const ATitle: string; ANames, AValues: TStrings; const AFocus: string;
  AReadOnly: Boolean): Boolean;
begin
  raise EFglError.Create('INPUT nije dopusten unutar izvora podataka');
end;

function TaFglSourceIO.Construct(const ATitle: string; AColumns, AValues: TStrings): Boolean;
begin
  raise EFglError.Create('CONSTRUCT nije dopusten unutar izvora podataka');
end;

function TaFglSourceIO.Grid(const ATitle: string; AFields: TObjectList; ARows: TObjectList;
  AEditable: Boolean; var ACurrent: Integer): Boolean;
begin
  raise EFglError.Create('DISPLAY ARRAY / INPUT ARRAY nisu dopusteni unutar izvora podataka');
end;

function TaFglSourceIO.InputFields(const ATitle: string; AFields: TObjectList; AValues: TStrings;
  const AFocus: string; AReadOnly: Boolean): Boolean;
begin
  raise EFglError.Create('INPUT nije dopusten unutar izvora podataka');
end;

procedure TaFglSourceIO.RunForm(ADb: TAppDb; const AFormName, AFilter: string);
begin
  raise EFglError.Create('Forma se ne moze otvoriti unutar izvora podataka');
end;


function JoinBar(L: TStrings): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to L.Count - 1 do
  begin
    if I > 0 then Result := Result + '|';
    Result := Result + L[I];
  end;
end;

{ ---- konzola ---- }

procedure TaFglConsoleIO.Display(const S: string);
begin
  WriteLn(S);
end;

procedure TaFglConsoleIO.Message(const S: string);
begin
  WriteLn('* ', S);
end;

procedure TaFglConsoleIO.Error(const S: string);
begin
  WriteLn('! ', S);
end;

function TaFglConsoleIO.Ask(const AText: string): Boolean;
var
  L: string;
begin
  Write(AText, ' (d/n): ');
  ReadLn(L);
  Result := (L <> '') and (LowerCase(L[1]) in ['d', 'y']);
end;

function TaFglConsoleIO.Prompt(const AText: string; var AValue: string): Boolean;
begin
  Write(AText);
  if EOF(System.Input) then Exit(False);
  ReadLn(AValue);
  Result := True;
end;

function TaFglConsoleIO.Menu(const ATitle: string; ANames, AHelps: TStrings): Integer;
var
  I, N: Integer;
  L: string;
begin
  Result := -1;
  WriteLn;
  WriteLn('== ', ATitle, ' ==');
  for I := 0 to ANames.Count - 1 do
    WriteLn(I + 1, ') ', ANames[I], '   ', AHelps[I]);
  Write('Izbor (prazno = izlaz): ');
  if EOF(System.Input) then Exit;
  ReadLn(L);
  N := StrToIntDef(Trim(L), 0);
  if (N >= 1) and (N <= ANames.Count) then Result := N - 1;
end;

function TaFglConsoleIO.Input(const ATitle: string; ANames, AValues: TStrings;
  const AFocus: string; AReadOnly: Boolean): Boolean;
var
  I: Integer;
  L: string;
begin
  WriteLn('-- ', ATitle);
  for I := 0 to ANames.Count - 1 do
  begin
    if AReadOnly then begin WriteLn(ANames[I], ': ', AValues[I]); Continue; end;
    Write(ANames[I], ' [', AValues[I], ']: ');
    if EOF(System.Input) then Exit(False);
    ReadLn(L);
    if L = '-' then Exit(False);
    if L <> '' then AValues[I] := L;
  end;
  Result := True;
end;

function TaFglConsoleIO.Construct(const ATitle: string; AColumns, AValues: TStrings): Boolean;
var
  I: Integer;
  L: string;
begin
  WriteLn('-- ', ATitle, ' (uvjeti; prazno = bez uvjeta, - = odustani)');
  for I := 0 to AColumns.Count - 1 do
  begin
    Write(AColumns[I], ': ');
    if EOF(System.Input) then Exit(False);
    ReadLn(L);
    if L = '-' then Exit(False);
    AValues[I] := L;
  end;
  Result := True;
end;

function TaFglConsoleIO.InputFields(const ATitle: string; AFields: TObjectList; AValues: TStrings;
  const AFocus: string; AReadOnly: Boolean): Boolean;
var
  I, J: Integer;
  F: TaFglField;
  L: string;
begin
  WriteLn('-- ', ATitle);
  for I := 0 to AFields.Count - 1 do
  begin
    F := TaFglField(AFields[I]);
    if F.LookupKeys <> nil then
    begin
      L := '';
      for J := 0 to F.LookupKeys.Count - 1 do L := L + ' ' + F.LookupKeys[J] + '=' + F.LookupLabels[J];
      WriteLn('   ', F.Caption, ':', L);
    end;
    if AReadOnly or F.ReadOnly then
    begin
      WriteLn(F.Caption, ': ', AValues[I]);
      Continue;
    end;
    Write(F.Caption, ' [', AValues[I], ']: ');
    if EOF(System.Input) then Exit(False);
    ReadLn(L);
    if L = '-' then Exit(False);
    if L <> '' then AValues[I] := L;
  end;
  Result := True;
end;

function TaFglConsoleIO.Grid(const ATitle: string; AFields: TObjectList; ARows: TObjectList;
  AEditable: Boolean; var ACurrent: Integer): Boolean;
var
  I, J: Integer;
  L, Hdr: string;
  Parts: TStringList;
  Row: TStringList;
begin
  WriteLn('== ', ATitle, ' ==');
  Hdr := '';
  for I := 0 to AFields.Count - 1 do
  begin
    if I > 0 then Hdr := Hdr + ' | ';
    Hdr := Hdr + TaFglField(AFields[I]).Caption;
  end;
  WriteLn('   ', Hdr);
  for I := 0 to ARows.Count - 1 do
  begin
    L := '';
    Row := TStringList(ARows[I]);
    for J := 0 to Row.Count - 1 do
    begin
      if J > 0 then L := L + ' | ';
      L := L + Row[J];
    end;
    WriteLn(I + 1, ') ', L);
  end;
  ACurrent := 0;
  if not AEditable then
  begin
    Write('Redak (prazno = bez odabira): ');
    if not EOF(System.Input) then
    begin
      ReadLn(L);
      ACurrent := StrToIntDef(Trim(L), 0);
    end;
    Exit(True);
  end;
  WriteLn('Novi redci (polja odvojena |, prazan redak = kraj, - = odustani):');
  while not EOF(System.Input) do
  begin
    ReadLn(L);
    if L = '-' then Exit(False);
    if Trim(L) = '' then Break;
    Parts := TStringList.Create;
    Parts.Delimiter := '|';
    Parts.StrictDelimiter := True;
    Parts.DelimitedText := L;
    while Parts.Count < AFields.Count do Parts.Add('');
    ARows.Add(Parts);
  end;
  Result := True;
end;

{ ---- test ---- }

constructor TaFglScriptIO.Create;
begin
  Out := TStringList.Create;
  MenuAnswers := TStringList.Create;
  PromptAnswers := TStringList.Create;
  InputAnswers := TStringList.Create;
  ConstructAnswers := TStringList.Create;
  AskAnswers := TStringList.Create;
  GridAnswers := TStringList.Create;
  FormsRun := TStringList.Create;
end;

destructor TaFglScriptIO.Destroy;
begin
  Out.Free; MenuAnswers.Free; PromptAnswers.Free; InputAnswers.Free;
  ConstructAnswers.Free; AskAnswers.Free; GridAnswers.Free; FormsRun.Free;
  inherited Destroy;
end;

function PopFirst(L: TStrings; out S: string): Boolean;
begin
  Result := L.Count > 0;
  if Result then begin S := L[0]; L.Delete(0); end else S := '';
end;

procedure TaFglScriptIO.Display(const S: string);
begin
  Out.Add(S);
end;

procedure TaFglScriptIO.Message(const S: string);
begin
  Out.Add('MSG: ' + S);
end;

procedure TaFglScriptIO.Error(const S: string);
begin
  Out.Add('ERR: ' + S);
end;

function TaFglScriptIO.Ask(const AText: string): Boolean;
var
  S: string;
begin
  Out.Add('ASK: ' + AText);
  Result := PopFirst(AskAnswers, S) and (LowerCase(S) = 'da');
end;

function TaFglScriptIO.Prompt(const AText: string; var AValue: string): Boolean;
var
  S: string;
begin
  Out.Add('PROMPT: ' + AText);
  Result := PopFirst(PromptAnswers, S) and (S <> '<cancel>');
  if Result then AValue := S;
end;

function TaFglScriptIO.Menu(const ATitle: string; ANames, AHelps: TStrings): Integer;
var
  S: string;
begin
  Out.Add('MENU: ' + ATitle + ' [' + JoinBar(ANames) + ']');
  Result := -1;
  if PopFirst(MenuAnswers, S) then Result := ANames.IndexOf(S);
end;

function ApplyAnswer(const AAnswer: string; ANames, AValues: TStrings): Boolean;
var
  Parts: TStringList;
  I, K: Integer;
begin
  Result := AAnswer <> '<cancel>';
  if not Result then Exit;
  Parts := TStringList.Create;
  try
    Parts.Delimiter := '|';
    Parts.StrictDelimiter := True;
    Parts.DelimitedText := AAnswer;
    for I := 0 to Parts.Count - 1 do
    begin
      K := ANames.IndexOf(Parts.Names[I]);
      if K >= 0 then AValues[K] := Parts.ValueFromIndex[I];
    end;
  finally
    Parts.Free;
  end;
end;

function TaFglScriptIO.Input(const ATitle: string; ANames, AValues: TStrings;
  const AFocus: string; AReadOnly: Boolean): Boolean;
var
  S: string;
begin
  Out.Add('INPUT: ' + ATitle + ' [' + JoinBar(ANames) + ']');
  if AFocus <> '' then Out.Add('FOCUS: ' + AFocus);
  if AReadOnly then Exit(True);
  Result := PopFirst(InputAnswers, S) and ApplyAnswer(S, ANames, AValues);
end;

function TaFglScriptIO.Construct(const ATitle: string; AColumns, AValues: TStrings): Boolean;
var
  S: string;
begin
  Out.Add('CONSTRUCT: ' + ATitle);
  Result := PopFirst(ConstructAnswers, S) and ApplyAnswer(S, AColumns, AValues);
end;

function TaFglScriptIO.Grid(const ATitle: string; AFields: TObjectList; ARows: TObjectList;
  AEditable: Boolean; var ACurrent: Integer): Boolean;
var
  Caps: TStringList;
  I, J: Integer;
  S: string;
  RowsTxt, Cells: TStringList;
  Row: TStringList;
begin
  Caps := TStringList.Create;
  try
    for I := 0 to AFields.Count - 1 do Caps.Add(TaFglField(AFields[I]).Caption);
    Out.Add('GRID: ' + ATitle + ' [' + JoinBar(Caps) + ']');
  finally
    Caps.Free;
  end;
  for I := 0 to ARows.Count - 1 do Out.Add('ROW: ' + JoinBar(TStringList(ARows[I])));
  Result := True;
  if not PopFirst(GridAnswers, S) then Exit;
  if S = '<cancel>' then Exit(False);
  if Copy(S, 1, 7) = 'select=' then
  begin
    ACurrent := StrToIntDef(Copy(S, 8, MaxInt), 0);
    Exit;
  end;
  if not AEditable then Exit;
  { odgovor zamjenjuje sve redke: red1;red2 s poljima odvojenim | }
  ARows.Clear;
  RowsTxt := TStringList.Create;
  try
    RowsTxt.Delimiter := ';';
    RowsTxt.StrictDelimiter := True;
    RowsTxt.DelimitedText := S;
    for I := 0 to RowsTxt.Count - 1 do
    begin
      Cells := TStringList.Create;
      Cells.Delimiter := '|';
      Cells.StrictDelimiter := True;
      Cells.DelimitedText := RowsTxt[I];
      Row := Cells;
      for J := Row.Count to AFields.Count - 1 do Row.Add('');
      ARows.Add(Row);
    end;
  finally
    RowsTxt.Free;
  end;
end;

function TaFglScriptIO.InputFields(const ATitle: string; AFields: TObjectList; AValues: TStrings;
  const AFocus: string; AReadOnly: Boolean): Boolean;
var
  I, J: Integer;
  F: TaFglField;
  L: string;
begin
  for I := 0 to AFields.Count - 1 do
  begin
    F := TaFglField(AFields[I]);
    if F.LookupKeys = nil then Continue;
    L := '';
    for J := 0 to F.LookupKeys.Count - 1 do
    begin
      if J > 0 then L := L + ',';
      L := L + F.LookupKeys[J] + ':' + F.LookupLabels[J];
    end;
    Out.Add('LOOKUP: ' + F.Name + '=' + L);
  end;
  Result := inherited InputFields(ATitle, AFields, AValues, AFocus, AReadOnly);
end;

procedure TaFglScriptIO.RunForm(ADb: TAppDb; const AFormName, AFilter: string);
begin
  FormsRun.Add(AFormName + '|' + AFilter);
end;

{ ============================ pomocno ============================ }

function IsNullV(const V: Variant): Boolean;
begin
  Result := VarIsNull(V) or VarIsEmpty(V);
end;

function IsBoolV(const V: Variant): Boolean;
begin
  Result := VarType(V) = varBoolean;
end;

function IsNumV(const V: Variant): Boolean;
begin
  Result := VarIsNumeric(V) and not IsBoolV(V);
end;

function IsIntV(const V: Variant): Boolean;
begin
  Result := VarType(V) in [varSmallint, varInteger, varShortInt, varByte, varWord, varLongWord, varInt64, varQWord];
end;

function FglAsText(const V: Variant): string;
var
  D: Double;
begin
  if IsNullV(V) then Exit('');
  if IsBoolV(V) then
  begin
    if Boolean(V) then Exit('TRUE') else Exit('FALSE');
  end;
  if VarType(V) = varDate then Exit(FormatDateTime('yyyy-mm-dd', V));
  if IsIntV(V) then Exit(IntToStr(Int64(V)));
  if VarIsFloat(V) then
  begin
    D := RoundTo(Double(V), -10);
    if (Frac(D) = 0) and (Abs(D) < 1e15) then Exit(IntToStr(Round(D)));
    Exit(FloatToStr(D, ParseFS));
  end;
  Result := VarToStr(V);
end;

function ToNum(const V: Variant; AAt: string): Double;
var
  D: Double;
begin
  if IsBoolV(V) then
  begin
    if Boolean(V) then Exit(1) else Exit(0);
  end;
  if VarIsNumeric(V) then Exit(Double(V));
  if ParseNumber(Trim(VarToStr(V)), D) then Exit(D);
  raise Exception.Create(Tr('Not a number: "') + VarToStr(V) + '"');
end;

function Truth(const V: Variant): Boolean;
begin
  if IsNullV(V) then Exit(False);
  if IsBoolV(V) then Exit(Boolean(V));
  if VarIsNumeric(V) then Exit(Double(V) <> 0);
  raise Exception.Create(Tr('The condition is not a logical value: "') + VarToStr(V) + '"');
end;

{ -2 = nepoznato (NULL) }
function CompareV(const A, B: Variant): Integer;
var
  X, Y: Double;
  S, T: string;
begin
  if IsNullV(A) or IsNullV(B) then Exit(-2);
  if (IsNumV(A) or IsBoolV(A)) and (IsNumV(B) or IsBoolV(B)) then
  begin
    X := ToNum(A, ''); Y := ToNum(B, '');
    Exit(CompareValue(X, Y));
  end;
  if IsNumV(A) and ParseNumber(Trim(VarToStr(B)), Y) then Exit(CompareValue(Double(A), Y));
  if IsNumV(B) and ParseNumber(Trim(VarToStr(A)), X) then Exit(CompareValue(X, Double(B)));
  S := FglAsText(A); T := FglAsText(B);
  Result := CompareStr(S, T);
  if Result < 0 then Result := -1 else if Result > 0 then Result := 1;
end;

{ SQL LIKE (%, _) ili MATCHES (*, ?); bez obzira na velika/mala slova }
function WildMatch(const S, P: string; AMany, AOne: Char): Boolean;

  function M(I, J: Integer): Boolean;
  begin
    while J <= Length(P) do
    begin
      if P[J] = AMany then
      begin
        Inc(J);
        if J > Length(P) then Exit(True);
        while I <= Length(S) + 1 do
        begin
          if M(I, J) then Exit(True);
          Inc(I);
        end;
        Exit(False);
      end;
      if I > Length(S) then Exit(False);
      if (P[J] <> AOne) and (UpCase(P[J]) <> UpCase(S[I])) then Exit(False);
      Inc(I); Inc(J);
    end;
    Result := I > Length(S);
  end;

begin
  Result := M(1, 1);
end;

function LooksNumeric(const S: string): Boolean;
var
  D: Double;
begin
  Result := (S <> '') and TryStrToFloat(S, D, ParseFS);
end;

function SqlLit(const S: string): string;
begin
  if LooksNumeric(S) then Result := S
  else Result := Q_ + StringReplace(S, Q_, Q_ + Q_, [rfReplaceAll]) + Q_;
end;

{ Jedan uvjet po primjeru: abc*, >5, 3:7, a|b, =x, <>y }
function ConstructOne(const ACol, AText: string): string;
var
  Alt: TStringList;
  I, P: Integer;
  T, Op, Part: string;
begin
  Result := '';
  Alt := TStringList.Create;
  try
    Alt.Delimiter := '|';
    Alt.StrictDelimiter := True;
    Alt.DelimitedText := AText;
    for I := 0 to Alt.Count - 1 do
    begin
      T := Trim(Alt[I]);
      if T = '' then Continue;
      Op := '';
      if Copy(T, 1, 2) = '>=' then Op := '>='
      else if Copy(T, 1, 2) = '<=' then Op := '<='
      else if Copy(T, 1, 2) = '<>' then Op := '<>'
      else if T[1] in ['>', '<', '='] then Op := T[1];
      if Op <> '' then
        Part := ACol + ' ' + Op + ' ' + SqlLit(Trim(Copy(T, Length(Op) + 1, MaxInt)))
      else if (Pos('*', T) > 0) or (Pos('?', T) > 0) then
        Part := ACol + ' LIKE ' + SqlLit(StringReplace(StringReplace(T, '*', '%', [rfReplaceAll]), '?', '_', [rfReplaceAll]))
      else
      begin
        P := Pos(':', T);
        if P > 1 then
          Part := ACol + ' BETWEEN ' + SqlLit(Trim(Copy(T, 1, P - 1))) + ' AND ' + SqlLit(Trim(Copy(T, P + 1, MaxInt)))
        else
          Part := ACol + ' = ' + SqlLit(T);
      end;
      if Result <> '' then Result := Result + ' OR ';
      Result := Result + Part;
    end;
  finally
    Alt.Free;
  end;
  if (Result <> '') and (Pos(' OR ', Result) > 0) then Result := '(' + Result + ')';
end;

function FglConstructToSql(const AColumns, AValues: TStrings): string;
var
  I: Integer;
  One: string;
begin
  Result := '';
  for I := 0 to AColumns.Count - 1 do
  begin
    One := ConstructOne(AColumns[I], AValues[I]);
    if One = '' then Continue;
    if Result <> '' then Result := Result + ' AND ';
    Result := Result + One;
  end;
  if Result = '' then Result := '1=1';
end;

{ ============================ tipovi i cvorovi ============================ }

constructor TFglType.Create(AKind: TFglTypeKind);
begin
  Kind := AKind;
  FieldNames := TStringList.Create;
  FieldTypes := TObjectList.Create(False);
end;

destructor TFglType.Destroy;
begin
  FieldNames.Free;
  FieldTypes.Free;
  inherited Destroy;
end;

destructor TNode.Destroy;
begin
  L1.Free; L2.Free; L3.Free; Names.Free;
  inherited Destroy;
end;

constructor TFglScreen.Create;
begin
  Fields := TObjectList.Create(True);
end;

destructor TFglScreen.Destroy;
begin
  Fields.Free;
  inherited Destroy;
end;

destructor TFglGroupBlock.Destroy;
begin
  Body.Free;
  inherited Destroy;
end;

constructor TFglReport.Create;
begin
  Params := TStringList.Create;
  Defines := TFPList.Create;
  Keys := TFPList.Create;
  KeyTexts := TStringList.Create;
  KeyDesc := TList.Create;
  Groups := TObjectList.Create(True);
  Aggs := TFPList.Create;
  PageLength := 60;
end;

destructor TFglReport.Destroy;
begin
  Params.Free; Defines.Free; Keys.Free; KeyTexts.Free; KeyDesc.Free;
  FirstHeader.Free; PageHeader.Free; PageTrailer.Free; OnEveryRow.Free; OnLastRow.Free;
  Groups.Free; Aggs.Free; Func.Free;
  inherited Destroy;
end;

function TFglReport.KeyIndex(const AText: string): Integer;
begin
  Result := KeyTexts.IndexOf(AText);
end;

constructor TFglReportRun.Create;
begin
  Pages := TObjectList.Create(True);
  Cells := TList.Create;
end;

destructor TFglReportRun.Destroy;
begin
  Pages.Free;
  Cells.Free;
  Frame.Free;
  inherited Destroy;
end;

constructor TFglFunc.Create;
begin
  Params := TStringList.Create;
  ParamTypes := TList.Create;
  Body := TFPList.Create;
  Declared := TStringList.Create;
  Used := TStringList.Create;
  Declared.CaseSensitive := False;
end;

destructor TFglFunc.Destroy;
begin
  Params.Free; ParamTypes.Free; Body.Free; Declared.Free; Used.Free;
  inherited Destroy;
end;

{ ============================ lexer ============================ }

type
  TTokKind = (tkEOF, tkIdent, tkNum, tkStr, tkParam, tkSym);

  TFglToken = record
    Kind: TTokKind;
    Text, Up: string;
    Line, Col, Start, Stop: Integer;   { Stop = indeks iza zadnjeg znaka }
    First: Boolean;                    { prvi token u retku }
  end;

  TFglTokens = array of TFglToken;

procedure Lex(const S, AFile: string; out T: TFglTokens);
var
  P, N, Line, LineStart, Cnt: Integer;
  FirstOnLine: Boolean;

  procedure Err(const AMsg: string);
  var
    E: EFglError;
  begin
    E := EFglError.Create(AFile + ':' + IntToStr(Line) + ':' + IntToStr(P - LineStart + 1) + ': ' + AMsg);
    E.FileName := AFile; E.Line := Line; E.Col := P - LineStart + 1;
    raise E;
  end;

  procedure Add(AKind: TTokKind; const AText: string; AStart, AStop: Integer);
  begin
    if Cnt >= Length(T) then SetLength(T, Length(T) * 2 + 64);
    T[Cnt].Kind := AKind;
    T[Cnt].Text := AText;
    T[Cnt].Up := UpperCase(AText);
    T[Cnt].Line := Line;
    T[Cnt].Col := AStart - LineStart + 1;
    T[Cnt].Start := AStart;
    T[Cnt].Stop := AStop;
    T[Cnt].First := FirstOnLine;
    FirstOnLine := False;
    Inc(Cnt);
  end;

var
  C, Q: Char;
  St: Integer;
  Txt: string;
begin
  N := Length(S);
  P := 1; Line := 1; LineStart := 1; Cnt := 0; FirstOnLine := True;
  SetLength(T, 256);
  while P <= N do
  begin
    C := S[P];
    if C = #10 then begin Inc(Line); Inc(P); LineStart := P; FirstOnLine := True; Continue; end;
    if C in [#9, #13, ' '] then begin Inc(P); Continue; end;
    if (C = '-') and (P < N) and (S[P + 1] = '-') then
    begin
      while (P <= N) and (S[P] <> #10) do Inc(P);
      Continue;
    end;
    if C = '{' then
    begin
      while (P <= N) and (S[P] <> '}') do
      begin
        if S[P] = #10 then begin Inc(Line); LineStart := P + 1; end;
        Inc(P);
      end;
      if P > N then Err('Komentar { nije zatvoren');
      Inc(P);
      Continue;
    end;
    St := P;
    if C in ['A'..'Z', 'a'..'z', '_'] then
    begin
      while (P <= N) and (S[P] in ['A'..'Z', 'a'..'z', '_', '0'..'9']) do Inc(P);
      Add(tkIdent, Copy(S, St, P - St), St, P);
    end
    else if C in ['0'..'9'] then
    begin
      while (P <= N) and (S[P] in ['0'..'9']) do Inc(P);
      if (P < N) and (S[P] = '.') and (S[P + 1] in ['0'..'9']) then
      begin
        Inc(P);
        while (P <= N) and (S[P] in ['0'..'9']) do Inc(P);
      end;
      Add(tkNum, Copy(S, St, P - St), St, P);
    end
    else if C in ['"', ''''] then
    begin
      Q := C;
      Inc(P);
      Txt := '';
      while True do
      begin
        if P > N then Err('Tekst nije zatvoren');
        if S[P] = #10 then Err('Tekst ide preko kraja retka');
        if S[P] = Q then
        begin
          if (P < N) and (S[P + 1] = Q) then begin Txt := Txt + Q; Inc(P, 2); Continue; end;
          Break;
        end;
        Txt := Txt + S[P];
        Inc(P);
      end;
      Inc(P);
      Add(tkStr, Txt, St, P);
      T[Cnt - 1].Up := Q;   { koji je navodnik: za SQL se tekst vraca sa zadanim navodnicima }
    end
    else if C = '$' then
    begin
      Inc(P);
      if (P > N) or not (S[P] in ['A'..'Z', 'a'..'z', '_']) then Err('Iza $ ocekujem naziv varijable');
      while (P <= N) and (S[P] in ['A'..'Z', 'a'..'z', '_', '0'..'9']) do Inc(P);
      while (P < N) and (S[P] = '.') and (S[P + 1] in ['A'..'Z', 'a'..'z', '_']) do
      begin
        Inc(P);
        while (P <= N) and (S[P] in ['A'..'Z', 'a'..'z', '_', '0'..'9']) do Inc(P);
      end;
      Add(tkParam, Copy(S, St + 1, P - St - 1), St, P);
    end
    else
    begin
      if (P < N) and (Copy(S, P, 2) = '||') then begin Add(tkSym, '||', St, P + 2); Inc(P, 2); end
      else if (P < N) and ((Copy(S, P, 2) = '<>') or (Copy(S, P, 2) = '!=') or (Copy(S, P, 2) = '<=') or (Copy(S, P, 2) = '>=')) then
      begin
        Txt := Copy(S, P, 2);
        if Txt = '!=' then Txt := '<>';
        Add(tkSym, Txt, St, P + 2);
        Inc(P, 2);
      end
      else if C in ['+', '-', '*', '/', '^', '(', ')', '[', ']', ',', '.', ';', '=', '<', '>', ':', '?', '%', '!', '~', '&', '|', '@', '#', '\', '`'] then
      begin
        Add(tkSym, C, St, P + 1);
        Inc(P);
      end
      else Err('Neocekivani znak "' + C + '"');
    end;
  end;
  Add(tkEOF, '', P, P);
  SetLength(T, Cnt);
end;

{ ============================ parser ============================ }

type
  TFglParser = class
  private
    FProg: TaFglProgram;
    FT: TFglTokens;
    FP: Integer;
    FSrc: string;
    FFile: string;
    FFileIdx: Integer;
    FFunc: TFglFunc;           { funkcija koja se parsira }
    FCurReport: TFglReport;    { izvješće koje se parsira }
    FBaseDir: string;
    function Tok: TFglToken;
    function PeekTok(AOff: Integer): TFglToken;
    procedure Next;
    procedure Fail(const AMsg: string);
    function IsKw(const K: string): Boolean;
    function IsKwAt(AOff: Integer; const K: string): Boolean;
    function IsSym(const S: string): Boolean;
    function AcceptKw(const K: string): Boolean;
    function AcceptSym(const S: string): Boolean;
    procedure ExpectKw(const K: string);
    procedure ExpectSym(const S: string);
    function ExpectIdent: string;
    function NewNode(AKind: TNodeKind): TNode;
    function List(var L: TFPList): TFPList;
    procedure NoteUse(const AName: string; ALine: Integer);
    procedure NoteDecl(const AName: string);
    { izrazi }
    function ParseExpr: TNode;
    function ParseOr: TNode;
    function ParseAnd: TNode;
    function ParseNot: TNode;
    function ParseCompare: TNode;
    function ParseConcat: TNode;
    function ParseAdd: TNode;
    function ParseMul: TNode;
    function ParseUnary: TNode;
    function ParsePow: TNode;
    function ParsePrimary: TNode;
    function ParseDesignator: TNode;
    function ParseArgs: TFPList;
    function ParseExprFromText(const AText: string; AAt: TFglToken): TNode;
    { naredbe }
    function ParseBlock(const AStops: array of string): TFPList;
    function ParseStatement: TNode;
    function ParseType: TFglType;
    function ParseDefine: TNode;
    function ParseColumns: TNode;
    function ParseLet: TNode;
    function ParseIf: TNode;
    function ParseWhile: TNode;
    function ParseFor: TNode;
    function ParseForeach: TNode;
    function ParseCase: TNode;
    function ParseMenu: TNode;
    function ParseCall: TNode;
    function ParseSql: TNode;
    function ParseDeclare: TNode;
    function ParseInput: TNode;
    function ParseConstruct: TNode;
    procedure ParseScreen;
    procedure ParseReport;
    procedure UseReport(const AName: string; ALine: Integer);
    function ParsePrint: TNode;
    procedure UseScreen(const AName: string; ALine: Integer);
    function ParseTargets: TFPList;
    function ParseExprList: TFPList;
    function IsStmtStart(AIdx: Integer): Boolean;
    function AtStmtEnd: Boolean;
    procedure ParseFunction(AIsMain: Boolean);
    procedure ParseGlobals;
    procedure ParseInclude;
  public
    constructor Create(AProg: TaFglProgram; const ASource, AFile: string);
    procedure ParseAll;
  end;

const
  StmtWords: array[0..51] of string = (
    'LET', 'CALL', 'IF', 'ELSE', 'END', 'WHILE', 'FOR', 'FOREACH', 'CASE', 'WHEN', 'OTHERWISE',
    'RETURN', 'DISPLAY', 'MESSAGE', 'ERROR', 'PROMPT', 'INPUT', 'CONSTRUCT', 'BEGIN', 'COMMIT',
    'ROLLBACK', 'DECLARE', 'OPEN', 'FETCH', 'CLOSE', 'FREE', 'PREPARE', 'EXECUTE', 'WHENEVER',
    'EXIT', 'CONTINUE', 'MENU', 'COMMAND', 'DEFINE', 'INITIALIZE', 'NEXT', 'SLEEP', 'SELECT',
    'INSERT', 'UPDATE', 'DELETE', 'CREATE', 'DROP', 'ALTER', 'BEFORE', 'AFTER',
    'START', 'OUTPUT', 'FINISH', 'PRINT', 'SKIP', 'NEED');

function InArr(const S: string; const A: array of string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(A) do
    if A[I] = S then Exit(True);
end;

constructor TFglParser.Create(AProg: TaFglProgram; const ASource, AFile: string);
begin
  FProg := AProg;
  FSrc := ASource;
  FFile := AFile;
  FFileIdx := AProg.Files.Add(AFile);
  FBaseDir := ExtractFilePath(ExpandFileName(AFile));
  Lex(ASource, AFile, FT);
  FP := 0;
end;

function TFglParser.Tok: TFglToken;
begin
  Result := FT[FP];
end;

function TFglParser.PeekTok(AOff: Integer): TFglToken;
begin
  if FP + AOff < Length(FT) then Result := FT[FP + AOff] else Result := FT[High(FT)];
end;

procedure TFglParser.Next;
begin
  if FP < High(FT) then Inc(FP);
end;

procedure TFglParser.Fail(const AMsg: string);
var
  E: EFglError;
begin
  E := EFglError.Create(FFile + ':' + IntToStr(Tok.Line) + ':' + IntToStr(Tok.Col) + ': ' + AMsg);
  E.FileName := FFile; E.Line := Tok.Line; E.Col := Tok.Col;
  raise E;
end;

function TFglParser.IsKw(const K: string): Boolean;
begin
  Result := (Tok.Kind = tkIdent) and (Tok.Up = K);
end;

function TFglParser.IsKwAt(AOff: Integer; const K: string): Boolean;
var
  T: TFglToken;
begin
  T := PeekTok(AOff);
  Result := (T.Kind = tkIdent) and (T.Up = K);
end;

function TFglParser.IsSym(const S: string): Boolean;
begin
  Result := (Tok.Kind = tkSym) and (Tok.Text = S);
end;

function TFglParser.AcceptKw(const K: string): Boolean;
begin
  Result := IsKw(K);
  if Result then Next;
end;

function TFglParser.AcceptSym(const S: string): Boolean;
begin
  Result := IsSym(S);
  if Result then Next;
end;

procedure TFglParser.ExpectKw(const K: string);
begin
  if not AcceptKw(K) then Fail('Ocekujem ' + K + ', a nasao sam "' + Tok.Text + '"');
end;

procedure TFglParser.ExpectSym(const S: string);
begin
  if not AcceptSym(S) then Fail('Ocekujem "' + S + '", a nasao sam "' + Tok.Text + '"');
end;

function TFglParser.ExpectIdent: string;
begin
  if Tok.Kind <> tkIdent then Fail('Ocekujem naziv, a nasao sam "' + Tok.Text + '"');
  Result := Tok.Text;
  Next;
end;

function TFglParser.NewNode(AKind: TNodeKind): TNode;
begin
  Result := FProg.NewNode(AKind);
  Result.Line := Tok.Line;
  Result.Col := Tok.Col;
  Result.Src := FFileIdx;
end;

function TFglParser.List(var L: TFPList): TFPList;
begin
  if L = nil then L := TFPList.Create;
  Result := L;
end;

procedure TFglParser.NoteUse(const AName: string; ALine: Integer);
begin
  if FFunc <> nil then FFunc.Used.Add(LowerCase(AName) + '=' + IntToStr(ALine) + '@' + IntToStr(FFileIdx));
end;

procedure TFglParser.NoteDecl(const AName: string);
begin
  if FFunc <> nil then FFunc.Declared.Add(LowerCase(AName))
  else FProg.GlobalNames.Add(LowerCase(AName));
end;

{ ---- izrazi ---- }

function TFglParser.ParseExpr: TNode;
begin
  Result := ParseOr;
end;

function TFglParser.ParseOr: TNode;
var
  N: TNode;
begin
  Result := ParseAnd;
  while IsKw('OR') do
  begin
    N := NewNode(nkBin); Next;
    N.Text := 'OR'; N.A := Result; N.B := ParseAnd;
    Result := N;
  end;
end;

function TFglParser.ParseAnd: TNode;
var
  N: TNode;
begin
  Result := ParseNot;
  while IsKw('AND') do
  begin
    N := NewNode(nkBin); Next;
    N.Text := 'AND'; N.A := Result; N.B := ParseNot;
    Result := N;
  end;
end;

function TFglParser.ParseNot: TNode;
var
  N: TNode;
begin
  if IsKw('NOT') then
  begin
    N := NewNode(nkUn); Next;
    N.Text := 'NOT'; N.A := Self.ParseNot;
    Exit(N);
  end;
  Result := ParseCompare;
end;

function TFglParser.ParseCompare: TNode;
var
  N: TNode;
  Neg: Boolean;
begin
  Result := ParseConcat;
  while True do
  begin
    if (Tok.Kind = tkSym) and InArr(Tok.Text, ['=', '<>', '<', '>', '<=', '>=']) then
    begin
      N := NewNode(nkBin); N.Text := Tok.Text; Next;
      N.A := Result; N.B := ParseConcat;
      Result := N;
    end
    else if IsKw('IS') then
    begin
      N := NewNode(nkIsNull); Next;
      if AcceptKw('NOT') then N.Flag := True;
      ExpectKw('NULL');
      N.A := Result;
      Result := N;
    end
    else
    begin
      Neg := IsKw('NOT') and (IsKwAt(1, 'LIKE') or IsKwAt(1, 'MATCHES') or IsKwAt(1, 'BETWEEN') or IsKwAt(1, 'IN'));
      if Neg then Next;
      if IsKw('LIKE') or IsKw('MATCHES') then
      begin
        N := NewNode(nkBin); N.Text := Tok.Up; Next;
        N.A := Result; N.B := ParseConcat; N.Flag := Neg;
        Result := N;
      end
      else if IsKw('BETWEEN') then
      begin
        N := NewNode(nkBetween); Next;
        N.A := Result; N.B := ParseConcat; ExpectKw('AND'); N.C := ParseConcat; N.Flag := Neg;
        Result := N;
      end
      else if IsKw('IN') then
      begin
        N := NewNode(nkInList); Next;
        N.A := Result; N.Flag := Neg;
        ExpectSym('(');
        N.L1 := ParseExprList;
        ExpectSym(')');
        Result := N;
      end
      else Break;
    end;
  end;
end;

function TFglParser.ParseConcat: TNode;
var
  N: TNode;
begin
  Result := ParseAdd;
  while IsSym('||') do
  begin
    N := NewNode(nkBin); Next;
    N.Text := '||'; N.A := Result; N.B := ParseAdd;
    Result := N;
  end;
end;

function TFglParser.ParseAdd: TNode;
var
  N: TNode;
begin
  Result := ParseMul;
  while IsSym('+') or IsSym('-') do
  begin
    N := NewNode(nkBin); N.Text := Tok.Text; Next;
    N.A := Result; N.B := ParseMul;
    Result := N;
  end;
end;

function TFglParser.ParseMul: TNode;
var
  N: TNode;
begin
  Result := ParseUnary;
  while IsSym('*') or IsSym('/') or IsKw('MOD') do
  begin
    N := NewNode(nkBin); N.Text := Tok.Up; Next;
    N.A := Result; N.B := ParseUnary;
    Result := N;
  end;
end;

function TFglParser.ParseUnary: TNode;
var
  N: TNode;
begin
  if IsSym('-') then
  begin
    N := NewNode(nkUn); Next;
    N.Text := '-'; N.A := Self.ParseUnary;
    Exit(N);
  end;
  if IsSym('+') then begin Next; Exit(Self.ParseUnary); end;
  Result := ParsePow;
end;

function TFglParser.ParsePow: TNode;
var
  N: TNode;
begin
  Result := ParsePrimary;
  while IsSym('^') do
  begin
    N := NewNode(nkBin); Next;
    N.Text := '^'; N.A := Result; N.B := ParsePrimary;
    Result := N;
  end;
end;

function TFglParser.ParseExprList: TFPList;
begin
  Result := TFPList.Create;
  Result.Add(ParseExpr);
  while AcceptSym(',') do Result.Add(ParseExpr);
end;

function TFglParser.ParseArgs: TFPList;
begin
  Result := TFPList.Create;
  ExpectSym('(');
  if not IsSym(')') then
  begin
    Result.Add(ParseExpr);
    while AcceptSym(',') do Result.Add(ParseExpr);
  end;
  ExpectSym(')');
end;

function TFglParser.ParseDesignator: TNode;
var
  N, S: TNode;
begin
  N := NewNode(nkVar);
  N.Text := ExpectIdent;
  NoteUse(N.Text, N.Line);
  while True do
  begin
    if IsSym('.') then
    begin
      Next;
      S := NewNode(nkField);
      if AcceptSym('*') then S.Text := '*' else S.Text := ExpectIdent;
      List(N.L1).Add(S);
    end
    else if IsSym('[') then
    begin
      Next;
      S := NewNode(nkIndex);
      S.A := ParseExpr;
      ExpectSym(']');
      List(N.L1).Add(S);
    end
    else Break;
  end;
  Result := N;
end;

function TFglParser.ParseExprFromText(const AText: string; AAt: TFglToken): TNode;
var
  Sub: TFglParser;
begin
  Sub := TFglParser.Create(FProg, AText, FFile);
  try
    Sub.FFunc := FFunc;
    Sub.FFileIdx := FFileIdx;
    Result := Sub.ParseDesignator;
    if Sub.Tok.Kind <> tkEOF then Fail('Neispravan parametar $' + AText);
    Result.Line := AAt.Line;
  finally
    Sub.Free;
  end;
end;

function TFglParser.ParsePrimary: TNode;
var
  N: TNode;
  D: Double;
  I64: Int64;
begin
  case Tok.Kind of
    tkNum:
      begin
        N := NewNode(nkLit);
        if Pos('.', Tok.Text) > 0 then
        begin
          D := StrToFloat(Tok.Text, ParseFS);
          N.V := D;
        end
        else if TryStrToInt64(Tok.Text, I64) then N.V := I64
        else N.V := StrToFloat(Tok.Text, ParseFS);
        Next;
        Result := N;
      end;
    tkStr:
      begin
        N := NewNode(nkLit);
        N.V := Tok.Text;
        Next;
        Result := N;
      end;
    tkSym:
      begin
        if not IsSym('(') then Fail('Neocekivano "' + Tok.Text + '" u izrazu');
        Next;
        Result := ParseExpr;
        ExpectSym(')');
      end;
    tkIdent:
      begin
        if IsKw('TRUE') or IsKw('FALSE') then
        begin
          N := NewNode(nkLit); N.V := IsKw('TRUE'); Next; Result := N;
        end
        else if IsKw('NULL') then
        begin
          N := NewNode(nkLit); N.V := Null; Next; Result := N;
        end
        else if IsKw('TODAY') then
        begin
          N := NewNode(nkCall); N.Text := 'today'; Next; Result := N;
        end
        else if IsKw('PAGENO') or IsKw('LINENO') then
        begin
          N := NewNode(nkCall); N.Text := LowerCase(Tok.Text); Next; Result := N;
        end
        else if (FCurReport <> nil) and (InArr(Tok.Up, ['SUM', 'COUNT', 'AVG', 'MIN', 'MAX', 'PERCENT']) or
          (IsKw('GROUP') and (PeekTok(1).Kind = tkIdent) and InArr(PeekTok(1).Up, ['SUM', 'COUNT', 'AVG', 'MIN', 'MAX', 'PERCENT']))) then
        begin
          N := NewNode(nkAggregate);
          if IsKw('GROUP') then begin N.Flag := True; Next; end;
          N.Text := Tok.Up;
          Next;
          ExpectSym('(');
          if IsSym('*') then Next else N.A := ParseExpr;
          ExpectSym(')');
          N.Idx := FCurReport.Aggs.Count;
          FCurReport.Aggs.Add(N);
          Result := N;
        end
        else if IsKw('CURRENT') then
        begin
          N := NewNode(nkCall); N.Text := 'current'; Next; Result := N;
        end
        else if IsKw('PAS') and (PeekTok(1).Text = '.') and (PeekTok(2).Kind = tkIdent) then
        begin
          N := NewNode(nkCall); Next; Next;
          N.Text := 'pas.' + Tok.Text; Next;
          N.L1 := ParseArgs;
          Result := N;
        end
        else if (PeekTok(1).Kind = tkSym) and (PeekTok(1).Text = '(') then
        begin
          N := NewNode(nkCall); N.Text := Tok.Text; Next;
          N.L1 := ParseArgs;
          Result := N;
        end
        else Result := ParseDesignator;
      end;
  else
    Fail('Neocekivani kraj izraza');
    Result := nil;
  end;
  while IsKw('USING') or IsKw('CLIPPED') do
  begin
    if IsKw('CLIPPED') then
    begin
      N := NewNode(nkCall); Next;
      N.Text := 'trimright';
      N.L1 := TFPList.Create;
      N.L1.Add(Result);
      Result := N;
      Continue;
    end;
    N := NewNode(nkUsing); Next;
    N.A := Result; N.B := Self.ParsePrimary;
    Result := N;
  end;
end;

{ ---- naredbe ---- }

function TFglParser.IsStmtStart(AIdx: Integer): Boolean;
var
  T: TFglToken;
begin
  T := FT[AIdx];
  Result := (T.Kind = tkIdent) and InArr(T.Up, StmtWords);
  if Result and (T.Up = 'FOR') then Result := (AIdx + 2 < Length(FT)) and (FT[AIdx + 2].Text = '=');
end;

function TFglParser.ParseBlock(const AStops: array of string): TFPList;
begin
  Result := TFPList.Create;
  while True do
  begin
    if Tok.Kind = tkEOF then Fail('Neocekivani kraj datoteke (nedostaje END?)');
    if (Tok.Kind = tkIdent) and InArr(Tok.Up, AStops) then Break;
    Result.Add(ParseStatement);
    while AcceptSym(';') do ;
  end;
end;

function TFglParser.ParseTargets: TFPList;
begin
  Result := TFPList.Create;
  Result.Add(ParseDesignator);
  while AcceptSym(',') do Result.Add(ParseDesignator);
end;

function TFglParser.ParseType: TFglType;
var
  U: string;
  T, E: TFglType;
  Idents: TStringList;
begin
  if Tok.Kind <> tkIdent then Fail('Ocekujem tip podatka');
  U := Tok.Up;
  if (U = 'INTEGER') or (U = 'INT') or (U = 'SMALLINT') or (U = 'BIGINT') then
  begin Next; Exit(FProg.NewType(tyInt)); end;
  if (U = 'DECIMAL') or (U = 'NUMERIC') or (U = 'FLOAT') or (U = 'SMALLFLOAT') then
  begin
    Next;
    if AcceptSym('(') then
    begin
      while not IsSym(')') and (Tok.Kind <> tkEOF) do Next;
      ExpectSym(')');
    end;
    Exit(FProg.NewType(tyFloat));
  end;
  Result := nil;
  if (U = 'CHAR') or (U = 'VARCHAR') or (U = 'TEXT') then
  begin
    Next;
    Result := FProg.NewType(tyText);
  end
  else if U = 'DATE' then begin Next; Result := FProg.NewType(tyDate); end
  else if U = 'DATETIME' then begin Next; Result := FProg.NewType(tyDateTime); end
  else if U = 'BOOLEAN' then begin Next; Result := FProg.NewType(tyBool); end
  else if U = 'LIKE' then
  begin
    Next;
    T := FProg.NewType(tyRecord);
    T.LikeTable := ExpectIdent;
    ExpectSym('.');
    if AcceptSym('*') then Result := T
    else
    begin
      T.LikeCol := ExpectIdent;
      T.Kind := tyAny;
      Result := T;
    end;
  end
  else if U = 'RECORD' then
  begin
    Next;
    if AcceptKw('LIKE') then
    begin
      T := FProg.NewType(tyRecord);
      T.LikeTable := ExpectIdent;
      ExpectSym('.');
      ExpectSym('*');
      Exit(T);
    end;
    T := FProg.NewType(tyRecord);
    Idents := TStringList.Create;
    try
      while not IsKw('END') do
      begin
        Idents.Clear;
        Idents.Add(ExpectIdent);
        while AcceptSym(',') do Idents.Add(ExpectIdent);
        E := Self.ParseType;
        while Idents.Count > 0 do
        begin
          T.FieldNames.Add(Idents[0]);
          T.FieldTypes.Add(E);
          Idents.Delete(0);
        end;
        if not AcceptSym(',') then Break;
      end;
    finally
      Idents.Free;
    end;
    ExpectKw('END');
    ExpectKw('RECORD');
    Exit(T);
  end
  else if U = 'ARRAY' then
  begin
    Next;
    T := FProg.NewType(tyArray);
    ExpectSym('[');
    if Tok.Kind = tkNum then begin T.Size := StrToInt(Tok.Text); Next; end;
    ExpectSym(']');
    ExpectKw('OF');
    T.Elem := Self.ParseType;
    Exit(T);
  end
  else Fail('Nepoznat tip "' + Tok.Text + '"');
  { CHAR(20) / VARCHAR(20) }
  if (Result.Kind = tyText) and IsSym('(') then
  begin
    Next;
    while not IsSym(')') and (Tok.Kind <> tkEOF) do Next;
    ExpectSym(')');
  end;
end;

function FglTypeKey(AKind: TFglTypeKind): string;
begin
  case AKind of
    tyInt: Result := 'int';
    tyFloat: Result := 'float';
    tyDate: Result := 'date';
    tyDateTime: Result := 'datetime';
    tyBool: Result := 'bool';
  else
    Result := 'text';
  end;
end;

{ COLUMNS naziv tip [, naziv tip ...] }
function TFglParser.ParseColumns: TNode;
var
  Nm: string;
  T: TFglType;
begin
  Result := NewNode(nkColumns);
  Next;
  Result.Names := TStringList.Create;
  repeat
    Nm := LowerCase(ExpectIdent);
    T := ParseType;
    Result.Names.Add(Nm + '=' + FglTypeKey(T.Kind));
  until not AcceptSym(',');
end;

function TFglParser.ParseDefine: TNode;
var
  N: TNode;
  I: Integer;
begin
  N := NewNode(nkDefine);
  Next;   { DEFINE }
  N.Names := TStringList.Create;
  N.Names.Add(ExpectIdent);
  while AcceptSym(',') do N.Names.Add(ExpectIdent);
  N.Typ := ParseType;
  for I := 0 to N.Names.Count - 1 do NoteDecl(N.Names[I]);
  Result := N;
end;

function TFglParser.ParseLet: TNode;
var
  N: TNode;
begin
  N := NewNode(nkLet);
  Next;
  N.A := ParseDesignator;
  ExpectSym('=');
  N.B := ParseExpr;
  Result := N;
end;

function TFglParser.ParseIf: TNode;
var
  N: TNode;
begin
  N := NewNode(nkIf);
  Next;
  N.A := ParseExpr;
  AcceptKw('THEN');
  N.L1 := ParseBlock(['ELSE', 'END']);
  if AcceptKw('ELSE') then N.L2 := ParseBlock(['END']);
  ExpectKw('END');
  ExpectKw('IF');
  Result := N;
end;

function TFglParser.ParseWhile: TNode;
var
  N: TNode;
begin
  N := NewNode(nkWhile);
  Next;
  N.A := ParseExpr;
  AcceptKw('DO');
  N.L1 := ParseBlock(['END']);
  ExpectKw('END');
  ExpectKw('WHILE');
  Result := N;
end;

function TFglParser.ParseFor: TNode;
var
  N: TNode;
begin
  N := NewNode(nkFor);
  Next;
  N.A := ParseDesignator;
  NoteDecl(N.A.Text);
  ExpectSym('=');
  N.B := ParseExpr;
  ExpectKw('TO');
  N.C := ParseExpr;
  if AcceptKw('STEP') then N.D := ParseExpr;
  AcceptKw('DO');
  N.L1 := ParseBlock(['END']);
  ExpectKw('END');
  ExpectKw('FOR');
  Result := N;
end;

function TFglParser.ParseForeach: TNode;
var
  N: TNode;
begin
  N := NewNode(nkForeach);
  Next;
  N.Text := LowerCase(ExpectIdent);
  FProg.UsedCursors.Add(N.Text + '=' + IntToStr(N.Line) + '@' + IntToStr(FFileIdx));
  if AcceptKw('USING') then N.L3 := ParseExprList;
  if AcceptKw('INTO') then N.L2 := ParseTargets;
  N.L1 := ParseBlock(['END']);
  ExpectKw('END');
  ExpectKw('FOREACH');
  Result := N;
end;

function TFglParser.ParseCase: TNode;
var
  N, W: TNode;
begin
  N := NewNode(nkCase);
  Next;
  if not IsKw('WHEN') then N.A := ParseExpr;
  while IsKw('WHEN') do
  begin
    W := NewNode(nkWhen); Next;
    W.A := ParseExpr;
    AcceptKw('THEN');
    W.L1 := ParseBlock(['WHEN', 'OTHERWISE', 'END']);
    List(N.L1).Add(W);
  end;
  if AcceptKw('OTHERWISE') then N.L2 := ParseBlock(['END']);
  ExpectKw('END');
  ExpectKw('CASE');
  Result := N;
end;

function TFglParser.ParseMenu: TNode;
var
  N, C: TNode;
begin
  N := NewNode(nkMenu);
  Next;
  N.A := ParseExpr;
  while IsKw('COMMAND') do
  begin
    C := NewNode(nkCommand); Next;
    C.A := ParseExpr;
    if Tok.Kind = tkStr then C.B := ParseExpr;
    C.L1 := ParseBlock(['COMMAND', 'END']);
    List(N.L1).Add(C);
  end;
  ExpectKw('END');
  ExpectKw('MENU');
  Result := N;
end;

function TFglParser.ParseCall: TNode;
var
  N: TNode;
begin
  N := NewNode(nkCallStmt);
  Next;
  N.A := NewNode(nkCall);
  if IsKw('PAS') and (PeekTok(1).Text = '.') then
  begin
    Next; Next;
    N.A.Text := 'pas.' + ExpectIdent;
  end
  else N.A.Text := ExpectIdent;
  N.A.L1 := ParseArgs;
  if AcceptKw('RETURNING') then N.L2 := ParseTargets;
  Result := N;
end;

{ Cijela SQL naredba: tekst izmedju tokena, $varijable postaju :pN, INTO ide u ciljeve. }
function TFglParser.ParseSql: TNode;
var
  N: TNode;
  First, J, Depth, CaseDepth, K, TS: Integer;
  Verb, Sql: string;
  Skip: array of Boolean;
  SeenSel, IsSelect, InInto, SeenFrom: Boolean;
  Seg: string;
  T: TFglToken;
  PN: Integer;
begin
  N := NewNode(nkSql);
  First := FP;
  Verb := Tok.Up;
  IsSelect := Verb = 'SELECT';
  Depth := 0; CaseDepth := 0; SeenSel := False;
  J := FP;
  while True do
  begin
    T := FT[J];
    if T.Kind = tkEOF then Break;
    if (T.Kind = tkSym) and (T.Text = ';') and (Depth = 0) then Break;
    if J > First then
    begin
      if (Depth = 0) and (CaseDepth = 0) and T.First and IsStmtStart(J) then
      begin
        { SELECT na novom retku nastavlja UNION / INSERT ... SELECT }
        if not ((T.Up = 'SELECT') and
          ((FT[J - 1].Up = 'UNION') or (FT[J - 1].Up = 'ALL') or (FT[J - 1].Up = 'INTERSECT') or
           (FT[J - 1].Up = 'EXCEPT') or ((Verb = 'INSERT') and not SeenSel))) then
          Break;
      end;
    end;
    if T.Kind = tkSym then
    begin
      if T.Text = '(' then Inc(Depth)
      else if T.Text = ')' then Dec(Depth);
    end
    else if T.Kind = tkIdent then
    begin
      if T.Up = 'CASE' then Inc(CaseDepth)
      else if (T.Up = 'END') and (CaseDepth > 0) then Dec(CaseDepth)
      else if T.Up = 'SELECT' then SeenSel := True
      else if (T.Up = 'VALUES') then SeenSel := True;
    end;
    Inc(J);
  end;
  { J = prvi token iza naredbe }
  SetLength(Skip, J - First);
  InInto := False; SeenFrom := False;
  if IsSelect then
  begin
    Depth := 0;
    for K := First to J - 1 do
    begin
      T := FT[K];
      if T.Kind = tkSym then
      begin
        if T.Text = '(' then Inc(Depth) else if T.Text = ')' then Dec(Depth);
      end;
      if Depth <> 0 then Continue;
      if (T.Kind = tkIdent) and (T.Up = 'INTO') and not InInto and not SeenFrom then
      begin
        InInto := True;
        Skip[K - First] := True;
        Continue;
      end;
      if InInto then
      begin
        if (T.Kind = tkIdent) and (T.Up = 'FROM') then InInto := False
        else Skip[K - First] := True;
      end;
      if (T.Kind = tkIdent) and (T.Up = 'FROM') then SeenFrom := True;
    end;
  end;
  { ciljevi: ponovo parsiraj tokene INTO dijela }
  K := First;
  while K < J do
  begin
    if Skip[K - First] and (FT[K].Up <> 'INTO') then
    begin
      FP := K;
      N.L2 := ParseTargets;
      K := FP;
      Continue;
    end;
    Inc(K);
  end;
  { sastavi SQL tekst }
  Sql := '';
  PN := 0;
  TS := -1;
  for K := First to J - 1 do
  begin
    if Skip[K - First] then Continue;
    T := FT[K];
    if TS >= 0 then
    begin
      { razmak izvornog teksta izmedju tokena }
      if TS = K - 1 then Seg := Copy(FSrc, FT[TS].Stop, T.Start - FT[TS].Stop) else Seg := ' ';
      if (Pos('--', Seg) > 0) or (Pos('{', Seg) > 0) then Seg := ' ';
      Sql := Sql + Seg;
    end;
    if T.Kind = tkParam then
    begin
      Sql := Sql + ':p' + IntToStr(PN);
      Inc(PN);
      List(N.L1).Add(ParseExprFromText(T.Text, T));
    end
    else if T.Kind = tkStr then
      Sql := Sql + T.Up + StringReplace(T.Text, T.Up, T.Up + T.Up, [rfReplaceAll]) + T.Up
    else
      Sql := Sql + Copy(FSrc, T.Start, T.Stop - T.Start);
    TS := K;
  end;
  N.Text := Trim(Sql);
  N.Flag := IsSelect;
  FP := J;
  if (FP < High(FT)) and IsSym(';') then Next;
  Result := N;
end;

function TFglParser.ParseDeclare: TNode;
var
  N: TNode;
begin
  N := NewNode(nkDeclare);
  Next;
  N.Text := LowerCase(ExpectIdent);
  FProg.DeclCursors.Add(N.Text);
  ExpectKw('CURSOR');
  ExpectKw('FOR');
  if IsKw('SELECT') then N.A := ParseSql
  else N.Text2 := LowerCase(ExpectIdent);
  Result := N;
end;

procedure TFglParser.UseScreen(const AName: string; ALine: Integer);
begin
  FProg.UsedScreens.Add(LowerCase(AName) + '=' + IntToStr(ALine) + '@' + IntToStr(FFileIdx));
end;

procedure TFglParser.ParseScreen;
var
  S: TFglScreen;
  F: TFglScreenField;
  Cap: string;
begin
  Next;   { SCREEN }
  S := TFglScreen.Create;
  S.Line := Tok.Line;
  S.Src := FFileIdx;
  S.Name := ExpectIdent;
  if FProg.Screens.IndexOf(LowerCase(S.Name)) >= 0 then Fail('Zaslon ' + S.Name + ' je vec definiran');
  FProg.Screens.AddObject(LowerCase(S.Name), S);
  while not IsKw('END') do
  begin
    if Tok.Kind = tkEOF then Fail('SCREEN nije zatvoren (END SCREEN)');
    if AcceptKw('TITLE') then
    begin
      if Tok.Kind <> tkStr then Fail('TITLE ocekuje tekst u navodnicima');
      S.Title := Tok.Text;
      Next;
      Continue;
    end;
    Cap := '';
    if AcceptKw('LABEL') then
    begin
      if Tok.Kind <> tkStr then Fail('LABEL ocekuje tekst u navodnicima');
      Cap := Tok.Text;
      Next;
    end;
    ExpectKw('FIELD');
    F := TFglScreenField.Create;
    S.Fields.Add(F);
    F.Name := ExpectIdent;
    if Cap <> '' then F.Caption := Cap else F.Caption := F.Name;
    while True do
    begin
      if AcceptKw('READONLY') then F.ReadOnly := True
      else if AcceptKw('REQUIRED') then F.Required := True
      else if AcceptKw('UPSHIFT') then F.Upshift := True
      else if AcceptKw('DEFAULT') then F.Default := ParseExpr
      else if AcceptKw('COMMENT') then
      begin
        if Tok.Kind <> tkStr then Fail('COMMENT ocekuje tekst u navodnicima');
        F.Hint := Tok.Text;
        Next;
      end
      else if AcceptKw('LOOKUP') then
      begin
        F.LookupTable := ExpectIdent;
        ExpectSym('(');
        F.LookupKey := ExpectIdent;
        ExpectSym(',');
        F.LookupLabel := ExpectIdent;
        ExpectSym(')');
      end
      else Break;
    end;
  end;
  ExpectKw('END');
  ExpectKw('SCREEN');
end;

procedure TFglParser.UseReport(const AName: string; ALine: Integer);
begin
  FProg.UsedReports.Add(LowerCase(AName) + '=' + IntToStr(ALine) + '@' + IntToStr(FFileIdx));
end;

function TFglParser.ParsePrint: TNode;
var
  N, It: TNode;
begin
  N := NewNode(nkPrint);
  Next;
  N.L1 := TFPList.Create;
  while not (AtStmtEnd or IsKw('ON') or IsKw('FIRST') or IsKw('PAGE')) do
  begin
    if IsKw('COLUMN') then
    begin
      It := NewNode(nkColumn); Next;
      It.A := ParseExpr;
      N.L1.Add(It);
    end
    else if IsKw('SPACES') then
    begin
      It := NewNode(nkColumn); Next;
      It.Text := 'SPACES';
      It.A := ParseExpr;
      N.L1.Add(It);
    end
    else if IsKw('FILE') then
    begin
      It := NewNode(nkColumn); Next;
      It.Text := 'FILE';
      It.A := ParseExpr;
      N.L1.Add(It);
    end
    else N.L1.Add(ParseExpr);
    if not AcceptSym(',') then Break;
  end;
  if IsSym(';') then begin N.Flag := True; Next; end;
  Result := N;
end;

procedure TFglParser.ParseReport;
var
  R: TFglReport;
  F: TFglFunc;
  G: TFglGroupBlock;
  K: TNode;
  Nm, KT: string;
  Desc: Boolean;
  I: Integer;

  function KeyText(N: TNode): string;
  var
    J: Integer;
    S: TNode;
  begin
    Result := LowerCase(N.Text);
    if N.L1 <> nil then
      for J := 0 to N.L1.Count - 1 do
      begin
        S := TNode(N.L1[J]);
        if S.Kind = nkField then Result := Result + '.' + LowerCase(S.Text) else Result := Result + '[]';
      end;
  end;

  function KeyFor(N: TNode): Integer;
  begin
    KT := KeyText(N);
    Result := R.KeyIndex(KT);
    if Result < 0 then
    begin
      R.Keys.Add(N);
      R.KeyTexts.Add(KT);
      R.KeyDesc.Add(nil);
      Result := R.Keys.Count - 1;
    end;
  end;

  procedure AddAll(L: TFPList);
  var
    X: Integer;
  begin
    if L = nil then Exit;
    for X := 0 to L.Count - 1 do F.Body.Add(L[X]);
  end;

  function Blk: TFPList;
  begin
    Result := ParseBlock(['FIRST', 'PAGE', 'BEFORE', 'AFTER', 'ON', 'END']);
  end;

begin
  Next;   { REPORT }
  R := TFglReport.Create;
  R.Line := Tok.Line;
  R.Src := FFileIdx;
  R.Name := ExpectIdent;
  if FProg.Reports.IndexOf(LowerCase(R.Name)) >= 0 then Fail('Izvješće ' + R.Name + ' je već definirano');
  FProg.Reports.AddObject(LowerCase(R.Name), R);
  F := TFglFunc.Create;
  F.Name := 'REPORT ' + R.Name;
  F.Line := R.Line;
  F.Src := FFileIdx;
  R.Func := F;
  ExpectSym('(');
  while not IsSym(')') do
  begin
    Nm := ExpectIdent;
    R.Params.Add(Nm);
    F.Declared.Add(LowerCase(Nm));
    if not AcceptSym(',') then Break;
  end;
  ExpectSym(')');
  FFunc := F;
  FCurReport := R;
  try
    while not IsKw('FORMAT') do
    begin
      if Tok.Kind = tkEOF then Fail('REPORT nema FORMAT');
      if IsKw('DEFINE') then R.Defines.Add(ParseDefine)
      else if IsKw('OUTPUT') then
      begin
        Next;
        while True do
        begin
          if AcceptKw('LEFT') then begin ExpectKw('MARGIN'); R.LeftMargin := StrToIntDef(Tok.Text, 0); Next; end
          else if AcceptKw('TOP') then begin ExpectKw('MARGIN'); R.TopMargin := StrToIntDef(Tok.Text, 0); Next; end
          else if AcceptKw('BOTTOM') then begin ExpectKw('MARGIN'); R.BottomMargin := StrToIntDef(Tok.Text, 0); Next; end
          else if AcceptKw('PAGE') then begin ExpectKw('LENGTH'); R.PageLength := StrToIntDef(Tok.Text, 60); Next; end
          else Break;
        end;
      end
      else if IsKw('ORDER') then
      begin
        Next;
        if AcceptKw('EXTERNAL') then R.External := True;
        ExpectKw('BY');
        repeat
          K := ParseDesignator;
          Desc := False;
          if AcceptKw('DESC') then Desc := True else AcceptKw('ASC');
          I := KeyFor(K);
          if Desc then R.KeyDesc[I] := Pointer(1);
        until not AcceptSym(',');
      end
      else Fail('U REPORT ocekujem DEFINE, OUTPUT, ORDER ili FORMAT, a nasao sam "' + Tok.Text + '"');
    end;
    ExpectKw('FORMAT');
    while not IsKw('END') do
    begin
      if Tok.Kind = tkEOF then Fail('REPORT nije zatvoren (END REPORT)');
      if IsKw('FIRST') then begin Next; ExpectKw('PAGE'); ExpectKw('HEADER'); R.FirstHeader := Blk; end
      else if IsKw('PAGE') then
      begin
        Next;
        if AcceptKw('HEADER') then R.PageHeader := Blk
        else if AcceptKw('TRAILER') then R.PageTrailer := Blk
        else Fail('Ocekujem PAGE HEADER ili PAGE TRAILER');
      end
      else if IsKw('BEFORE') or IsKw('AFTER') then
      begin
        G := TFglGroupBlock.Create;
        G.Before := IsKw('BEFORE');
        Next;
        ExpectKw('GROUP');
        ExpectKw('OF');
        G.KeyIdx := KeyFor(ParseDesignator);
        G.Body := Blk;
        R.Groups.Add(G);
      end
      else if IsKw('ON') then
      begin
        Next;
        if AcceptKw('EVERY') then begin ExpectKw('ROW'); R.OnEveryRow := Blk; end
        else if AcceptKw('LAST') then begin ExpectKw('ROW'); R.OnLastRow := Blk; end
        else Fail('Ocekujem ON EVERY ROW ili ON LAST ROW');
      end
      else Fail('U FORMAT ocekujem blok (PAGE HEADER, ON EVERY ROW...), a nasao sam "' + Tok.Text + '"');
    end;
    ExpectKw('END');
    ExpectKw('REPORT');
  finally
    FFunc := nil;
    FCurReport := nil;
  end;
  { za staticku provjeru: sve naredbe izvjesca u jednom popisu }
  for I := 0 to R.Defines.Count - 1 do F.Body.Add(R.Defines[I]);
  AddAll(R.FirstHeader); AddAll(R.PageHeader); AddAll(R.PageTrailer); AddAll(R.OnEveryRow); AddAll(R.OnLastRow);
  for I := 0 to R.Groups.Count - 1 do AddAll(TFglGroupBlock(R.Groups[I]).Body);
end;

function TFglParser.ParseInput: TNode;
var
  N, C: TNode;
begin
  N := NewNode(nkInput);
  Next;
  if IsKw('ARRAY') then
  begin
    Next;
    N.Kind := nkInputArray;
    N.A := ParseDesignator;
    if AcceptKw('WITHOUT') then ExpectKw('DEFAULTS');
    if AcceptKw('FROM') then begin N.Text2 := LowerCase(ExpectIdent); UseScreen(N.Text2, N.Line); end;
    if AcceptKw('TITLE') then N.B := ParseExpr;
    Exit(N);
  end;
  ExpectKw('BY');
  ExpectKw('NAME');
  N.L2 := ParseTargets;
  if AcceptKw('WITHOUT') then begin ExpectKw('DEFAULTS'); N.Flag := True; end;
  if AcceptKw('FROM') then begin N.Text2 := LowerCase(ExpectIdent); UseScreen(N.Text2, N.Line); end;
  if AcceptKw('TITLE') then N.A := ParseExpr;
  if IsKw('BEFORE') or IsKw('AFTER') then
  begin
    while IsKw('BEFORE') or IsKw('AFTER') do
    begin
      C := NewNode(nkClause);
      C.Text := Tok.Up;
      Next;
      if IsKw('FIELD') then
      begin
        Next;
        C.Text := C.Text + ' FIELD';
        C.Text2 := LowerCase(ExpectIdent);
      end
      else if IsKw('INPUT') then
      begin
        Next;
        C.Text := C.Text + ' INPUT';
      end
      else Fail('Ocekujem FIELD ili INPUT');
      C.L1 := ParseBlock(['BEFORE', 'AFTER', 'END', 'ON']);
      List(N.L1).Add(C);
    end;
    if IsKw('ON') then Fail('ON KEY jos nije podrzano');
    ExpectKw('END');
    ExpectKw('INPUT');
  end
  else if IsKw('END') and IsKwAt(1, 'INPUT') then
  begin
    Next; Next;
  end;
  Result := N;
end;

function TFglParser.ParseConstruct: TNode;
var
  N: TNode;
  Col: string;
begin
  N := NewNode(nkConstruct);
  Next;
  ExpectKw('BY');
  ExpectKw('NAME');
  N.B := ParseDesignator;
  ExpectKw('ON');
  N.Names := TStringList.Create;
  repeat
    Col := ExpectIdent;
    if AcceptSym('.') then Col := Col + '.' + ExpectIdent;
    N.Names.Add(Col);
  until not AcceptSym(',');
  if AcceptKw('FROM') then begin N.Text2 := LowerCase(ExpectIdent); UseScreen(N.Text2, N.Line); end;
  if AcceptKw('TITLE') then N.A := ParseExpr;
  Result := N;
end;

function TFglParser.AtStmtEnd: Boolean;
begin
  Result := (Tok.Kind = tkEOF) or IsStmtStart(FP) or ((Tok.Kind = tkSym) and (Tok.Text = ';'));
end;

function TFglParser.ParseStatement: TNode;
var
  U: string;
  N: TNode;
begin
  if Tok.Kind <> tkIdent then Fail('Ocekujem naredbu, a nasao sam "' + Tok.Text + '"');
  U := Tok.Up;
  if U = 'LET' then Exit(ParseLet);
  if U = 'CALL' then Exit(ParseCall);
  if U = 'IF' then Exit(ParseIf);
  if U = 'WHILE' then Exit(ParseWhile);
  if U = 'FOR' then Exit(ParseFor);
  if U = 'FOREACH' then Exit(ParseForeach);
  if U = 'CASE' then Exit(ParseCase);
  if U = 'MENU' then Exit(ParseMenu);
  if U = 'DEFINE' then Exit(ParseDefine);
  if U = 'INPUT' then Exit(ParseInput);
  if U = 'CONSTRUCT' then Exit(ParseConstruct);
  if U = 'DECLARE' then Exit(ParseDeclare);
  if (U = 'SELECT') or (U = 'INSERT') or (U = 'UPDATE') or (U = 'DELETE') or (U = 'CREATE') or
    (U = 'DROP') or (U = 'ALTER') then Exit(ParseSql);
  N := NewNode(nkReturn);
  if U = 'RETURN' then
  begin
    Next;
    if not AtStmtEnd then N.L1 := ParseExprList;
    Exit(N);
  end;
  if U = 'EXIT' then
  begin
    Next;
    if IsKw('PROGRAM') then
    begin
      Next;
      N.Kind := nkExitProgram;
      if (Tok.Kind = tkNum) or IsSym('-') then N.A := ParseExpr;
      Exit(N);
    end;
    N.Kind := nkExit;
    if not (IsKw('WHILE') or IsKw('FOR') or IsKw('FOREACH') or IsKw('MENU')) then
      Fail('EXIT mora imati WHILE, FOR, FOREACH, MENU ili PROGRAM');
    N.Text := Tok.Up;
    Next;
    Exit(N);
  end;
  if U = 'CONTINUE' then
  begin
    Next;
    N.Kind := nkContinue;
    if not (IsKw('WHILE') or IsKw('FOR') or IsKw('FOREACH') or IsKw('MENU')) then
      Fail('CONTINUE mora imati WHILE, FOR, FOREACH ili MENU');
    N.Text := Tok.Up;
    Next;
    Exit(N);
  end;
  if U = 'NEXT' then
  begin
    Next;
    ExpectKw('FIELD');
    N.Kind := nkNextField;
    N.Text := LowerCase(ExpectIdent);
    Exit(N);
  end;
  if U = 'DISPLAY' then
  begin
    Next;
    if IsKw('BY') then
    begin
      Next;
      ExpectKw('NAME');
      N.Kind := nkDisplayName;
      N.L2 := ParseTargets;
      if AcceptKw('TO') then begin N.Text2 := LowerCase(ExpectIdent); UseScreen(N.Text2, N.Line); end;
    end
    else if IsKw('ARRAY') then
    begin
      Next;
      N.Kind := nkDisplayArray;
      N.A := ParseDesignator;
      if AcceptKw('TO') then begin N.Text2 := LowerCase(ExpectIdent); UseScreen(N.Text2, N.Line); end;
      if AcceptKw('TITLE') then N.B := ParseExpr;
    end
    else if IsKw('FORM') then
    begin
      Next;
      N.Kind := nkDisplayForm;
      N.Text := LowerCase(ExpectIdent);
      if AcceptKw('WHERE') then N.A := ParseExpr;
    end
    else
    begin
      N.Kind := nkDisplay;
      N.L1 := ParseExprList;
    end;
    Exit(N);
  end;
  if U = 'OPEN' then
  begin
    Next;
    if IsKw('FORM') then
    begin
      Next;
      N.Kind := nkOpenForm;
      N.Text := LowerCase(ExpectIdent);
      ExpectKw('FROM');
      N.A := ParseExpr;
    end
    else
    begin
      N.Kind := nkOpen;
      N.Text := LowerCase(ExpectIdent);
      FProg.UsedCursors.Add(N.Text + '=' + IntToStr(N.Line) + '@' + IntToStr(FFileIdx));
      if AcceptKw('USING') then N.L1 := ParseExprList;
    end;
    Exit(N);
  end;
  if U = 'FETCH' then
  begin
    Next;
    N.Kind := nkFetch;
    N.Text := LowerCase(ExpectIdent);
    FProg.UsedCursors.Add(N.Text + '=' + IntToStr(N.Line) + '@' + IntToStr(FFileIdx));
    ExpectKw('INTO');
    N.L2 := ParseTargets;
    Exit(N);
  end;
  if U = 'CLOSE' then
  begin
    Next;
    N.Kind := nkClose;
    N.Text := LowerCase(ExpectIdent);
    FProg.UsedCursors.Add(N.Text + '=' + IntToStr(N.Line) + '@' + IntToStr(FFileIdx));
    Exit(N);
  end;
  if U = 'FREE' then
  begin
    Next;
    N.Kind := nkFree;
    N.Text := LowerCase(ExpectIdent);
    Exit(N);
  end;
  if U = 'PREPARE' then
  begin
    Next;
    N.Kind := nkPrepare;
    N.Text := LowerCase(ExpectIdent);
    ExpectKw('FROM');
    N.A := ParseExpr;
    Exit(N);
  end;
  if U = 'EXECUTE' then
  begin
    Next;
    N.Kind := nkExecute;
    N.Text := LowerCase(ExpectIdent);
    if AcceptKw('USING') then N.L1 := ParseExprList;
    Exit(N);
  end;
  if (U = 'BEGIN') or (U = 'COMMIT') or (U = 'ROLLBACK') then
  begin
    Next;
    AcceptKw('WORK');
    N.Kind := nkTrans;
    N.Text := U;
    Exit(N);
  end;
  if (U = 'MESSAGE') or (U = 'ERROR') then
  begin
    Next;
    if U = 'MESSAGE' then N.Kind := nkMessage else N.Kind := nkError;
    N.L1 := ParseExprList;
    Exit(N);
  end;
  if U = 'PROMPT' then
  begin
    Next;
    N.Kind := nkPrompt;
    N.A := ParseExpr;
    ExpectKw('FOR');
    N.B := ParseDesignator;
    Exit(N);
  end;
  if U = 'WHENEVER' then
  begin
    Next;
    ExpectKw('ERROR');
    N.Kind := nkWhenever;
    if not (IsKw('CONTINUE') or IsKw('STOP')) then Fail('Ocekujem CONTINUE ili STOP');
    N.Text := Tok.Up;
    Next;
    Exit(N);
  end;
  if U = 'INITIALIZE' then
  begin
    Next;
    N.Kind := nkInitialize;
    N.L2 := ParseTargets;
    ExpectKw('TO');
    ExpectKw('NULL');
    Exit(N);
  end;
  if U = 'PRINT' then Exit(ParsePrint);
  if U = 'SKIP' then
  begin
    Next;
    N.Kind := nkSkip;
    if AcceptKw('TO') then
    begin
      ExpectKw('TOP'); ExpectKw('OF'); ExpectKw('PAGE');
      N.Text := 'TOP';
    end
    else
    begin
      N.A := ParseExpr;
      if not AcceptKw('LINES') then AcceptKw('LINE');
    end;
    Exit(N);
  end;
  if U = 'NEED' then
  begin
    Next;
    N.Kind := nkNeed;
    N.A := ParseExpr;
    if not AcceptKw('LINES') then AcceptKw('LINE');
    Exit(N);
  end;
  if U = 'START' then
  begin
    Next;
    ExpectKw('REPORT');
    N.Kind := nkStartReport;
    N.Text := LowerCase(ExpectIdent);
    UseReport(N.Text, N.Line);
    N.Text2 := 'SCREEN';
    if AcceptKw('TO') then
    begin
      if AcceptKw('SCREEN') then N.Text2 := 'SCREEN'
      else if IsKw('FILE') or IsKw('PDF') or IsKw('PIPE') then
      begin
        N.Text2 := Tok.Up;
        Next;
        N.A := ParseExpr;
      end
      else if IsKw('PRINTER') then
      begin
        N.Text2 := 'PRINTER';
        Next;
        if not AtStmtEnd then N.A := ParseExpr;
      end
      else Fail('START REPORT ... TO podrzava SCREEN, PRINTER ["ime"], FILE "x", PDF "x" ili PIPE "naredba"');
    end;
    Exit(N);
  end;
  if U = 'OUTPUT' then
  begin
    Next;
    ExpectKw('TO');
    ExpectKw('REPORT');
    N.Kind := nkOutputReport;
    N.Text := LowerCase(ExpectIdent);
    UseReport(N.Text, N.Line);
    N.L1 := ParseArgs;
    Exit(N);
  end;
  if U = 'FINISH' then
  begin
    Next;
    ExpectKw('REPORT');
    N.Kind := nkFinishReport;
    N.Text := LowerCase(ExpectIdent);
    UseReport(N.Text, N.Line);
    Exit(N);
  end;
  if U = 'COLUMNS' then Exit(ParseColumns);
  if U = 'EMIT' then
  begin
    Next;
    N.Kind := nkEmit;
    N.L1 := ParseExprList;
    Exit(N);
  end;
  if U = 'SLEEP' then
  begin
    Next;
    N.Kind := nkSleep;
    N.A := ParseExpr;
    Exit(N);
  end;
  if (U = 'REPORT') or (U = 'START') or (U = 'OUTPUT') or (U = 'FINISH') then
    Fail(U + ' jos nije podrzan u ovoj verziji jezika (faza 2/3)');
  Fail('Nepoznata naredba "' + Tok.Text + '"');
  Result := nil;
end;

procedure TFglParser.ParseFunction(AIsMain: Boolean);
var
  F: TFglFunc;
  T: TFglType;
  Nm: string;
begin
  F := TFglFunc.Create;
  F.Line := Tok.Line;
  F.Src := FFileIdx;
  Next;   { FUNCTION / MAIN }
  if AIsMain then
  begin
    F.Name := 'main';
    if FProg.Main <> nil then Fail('MAIN je vec definiran');
  end
  else
  begin
    F.Name := ExpectIdent;
    if FProg.Funcs.IndexOf(LowerCase(F.Name)) >= 0 then Fail('Funkcija ' + F.Name + ' je vec definirana');
    ExpectSym('(');
    while not IsSym(')') do
    begin
      Nm := ExpectIdent;
      F.Params.Add(Nm);
      F.Declared.Add(LowerCase(Nm));
      T := nil;
      if Tok.Kind = tkIdent then T := ParseType;
      F.ParamTypes.Add(T);
      if not AcceptSym(',') then Break;
    end;
    ExpectSym(')');
    if AcceptKw('RETURNING') then
    begin
      ParseType;
      while AcceptSym(',') do ParseType;
    end;
  end;
  if AIsMain then FProg.Main := F else FProg.Funcs.AddObject(LowerCase(F.Name), F);
  FFunc := F;
  F.Body.Free;
  F.Body := ParseBlock(['END']);
  ExpectKw('END');
  if AIsMain then ExpectKw('MAIN') else ExpectKw('FUNCTION');
  FFunc := nil;
end;

procedure TFglParser.ParseGlobals;
begin
  Next;
  while not IsKw('END') do
  begin
    if Tok.Kind = tkEOF then Fail('GLOBALS nije zatvoren (END GLOBALS)');
    if not IsKw('DEFINE') then Fail('U GLOBALS su dopusteni samo DEFINE');
    FProg.GlobalStmts.Add(ParseDefine);
  end;
  ExpectKw('END');
  ExpectKw('GLOBALS');
end;

procedure TFglParser.ParseInclude;
var
  Path, Full: string;
  L: TStringList;
  Sub: TFglParser;
  I: Integer;
begin
  Next;
  if Tok.Kind <> tkStr then Fail('INCLUDE ocekuje naziv datoteke u navodnicima');
  Path := Tok.Text;
  Next;
  if ExtractFilePath(Path) = '' then Full := FBaseDir + Path else Full := Path;
  Full := ExpandFileName(Full);
  for I := 0 to FProg.Files.Count - 1 do
    if SameFileName(ExpandFileName(FProg.Files[I]), Full) then Exit;
  if not FileExists(Full) then Fail('Nema datoteke ' + Path);
  L := TStringList.Create;
  try
    L.LoadFromFile(Full);
    Sub := TFglParser.Create(FProg, L.Text, Full);
    try
      Sub.ParseAll;
    finally
      Sub.Free;
    end;
  finally
    L.Free;
  end;
end;

procedure TFglParser.ParseAll;
begin
  while Tok.Kind <> tkEOF do
  begin
    if AcceptSym(';') then Continue;
    if IsKw('DATABASE') then begin Next; FProg.DatabaseName := ExpectIdent; end
    else if IsKw('INCLUDE') then ParseInclude
    else if IsKw('GLOBALS') then ParseGlobals
    else if IsKw('DEFINE') then FProg.GlobalStmts.Add(ParseDefine)
    else if IsKw('MAIN') then ParseFunction(True)
    else if IsKw('FUNCTION') then ParseFunction(False)
    else if IsKw('SCREEN') then ParseScreen
    else if IsKw('REPORT') then ParseReport
    else Fail('Ocekujem MAIN, FUNCTION, GLOBALS ili DEFINE, a nasao sam "' + Tok.Text + '"');
  end;
end;

{ ============================ program ============================ }

constructor TaFglProgram.Create;
begin
  FOwned := TObjectList.Create(True);
  Files := TStringList.Create;
  Funcs := TStringList.Create;
  GlobalStmts := TFPList.Create;
  GlobalNames := TStringList.Create;
  DeclCursors := TStringList.Create;
  UsedCursors := TStringList.Create;
  Screens := TStringList.Create;
  Screens.OwnsObjects := True;
  UsedScreens := TStringList.Create;
  Reports := TStringList.Create;
  Reports.OwnsObjects := True;
  UsedReports := TStringList.Create;
end;

destructor TaFglProgram.Destroy;
var
  I: Integer;
begin
  for I := 0 to Funcs.Count - 1 do Funcs.Objects[I].Free;
  Main.Free;
  Files.Free; Funcs.Free; GlobalStmts.Free; GlobalNames.Free; DeclCursors.Free; UsedCursors.Free;
  Screens.Free; UsedScreens.Free; Reports.Free; UsedReports.Free;
  FOwned.Free;
  inherited Destroy;
end;

function TaFglProgram.NewNode(AKind: TNodeKind): TNode;
begin
  Result := TNode.Create;
  Result.Kind := AKind;
  Result.V := Null;
  FOwned.Add(Result);
end;

function TaFglProgram.NewType(AKind: TFglTypeKind): TFglType;
begin
  Result := TFglType.Create(AKind);
  FOwned.Add(Result);
end;

procedure TaFglProgram.ParseSource(const ASource, AFile: string);
var
  P: TFglParser;
begin
  P := TFglParser.Create(Self, ASource, AFile);
  try
    P.ParseAll;
  finally
    P.Free;
  end;
end;

procedure TaFglProgram.LoadFile(const AFile: string);
var
  L: TStringList;
begin
  L := TStringList.Create;
  try
    L.LoadFromFile(AFile);
    ParseSource(L.Text, AFile);
  finally
    L.Free;
  end;
end;

procedure TaFglProgram.LoadText(const AText, AName: string);
begin
  ParseSource(AText, AName);
end;

const
  BuiltinNames: array[0..11] of string = (
    'length', 'upper', 'lower', 'trim', 'substr', 'nvl', 'ask', 'today', 'current',
    'round', 'abs', 'format');

procedure TaFglProgram.Check(ALog: TStrings; var AErrors: Integer);
var
  Ctx: array[0..3] of Integer;   { WHILE, FOR, FOREACH, MENU }

  procedure Err(ASrc, ALine: Integer; const AMsg: string);
  begin
    ALog.Add(Files[ASrc] + ':' + IntToStr(ALine) + ': ' + AMsg);
    Inc(AErrors);
  end;

  function CtxIndex(const K: string): Integer;
  begin
    if K = 'WHILE' then Result := 0
    else if K = 'FOR' then Result := 1
    else if K = 'FOREACH' then Result := 2
    else Result := 3;
  end;

  procedure WalkList(L: TFPList); forward;

  procedure Walk(N: TNode);
  var
    F: TFglFunc;
    K: Integer;
  begin
    if N = nil then Exit;
    case N.Kind of
      nkCall, nkCallStmt:
        ;
      nkExit, nkContinue:
        if Ctx[CtxIndex(N.Text)] = 0 then
          Err(N.Src, N.Line, N.Text + ' izvan odgovarajuce naredbe ' + N.Text);
    end;
    if N.Kind = nkCallStmt then
    begin
      if Copy(N.A.Text, 1, 4) <> 'pas.' then
      begin
        K := Funcs.IndexOf(LowerCase(N.A.Text));
        if K >= 0 then
        begin
          F := TFglFunc(Funcs.Objects[K]);
          if (N.A.L1 <> nil) and (N.A.L1.Count <> F.Params.Count) or ((N.A.L1 = nil) and (F.Params.Count <> 0)) then
            Err(N.Src, N.Line, 'Funkcija ' + F.Name + ' ocekuje ' + IntToStr(F.Params.Count) + ' argumenata');
        end
        else if not InArr(LowerCase(N.A.Text), BuiltinNames) then
          Err(N.Src, N.Line, 'Nepoznata funkcija ' + N.A.Text);
      end;
    end;
    case N.Kind of
      nkWhile: Inc(Ctx[0]);
      nkFor: Inc(Ctx[1]);
      nkForeach: Inc(Ctx[2]);
      nkMenu: Inc(Ctx[3]);
    end;
    Walk(N.A); Walk(N.B); Walk(N.C); Walk(N.D);
    WalkList(N.L1); WalkList(N.L2); WalkList(N.L3);
    case N.Kind of
      nkWhile: Dec(Ctx[0]);
      nkFor: Dec(Ctx[1]);
      nkForeach: Dec(Ctx[2]);
      nkMenu: Dec(Ctx[3]);
    end;
  end;

  procedure WalkList(L: TFPList);
  var
    I: Integer;
  begin
    if L = nil then Exit;
    for I := 0 to L.Count - 1 do Walk(TNode(L[I]));
  end;

  procedure CheckFunc(F: TFglFunc);
  var
    I, P, At: Integer;
    Nm, Ln: string;
  begin
    FillChar(Ctx, SizeOf(Ctx), 0);
    WalkList(F.Body);
    for I := 0 to F.Used.Count - 1 do
    begin
      Nm := F.Used.Names[I];
      Ln := F.Used.ValueFromIndex[I];
      P := Pos('@', Ln);
      At := StrToIntDef(Copy(Ln, P + 1, MaxInt), 0);
      if (F.Declared.IndexOf(Nm) < 0) and (GlobalNames.IndexOf(Nm) < 0) and
        not InArr(Nm, ['sqlca', 'status', 'int_flag', 'arr_count', 'arr_curr']) then
        Err(At, StrToIntDef(Copy(Ln, 1, P - 1), 0), 'Nedefinirana varijabla ' + Nm);
    end;
  end;

var
  I, P: Integer;
  S, Nm: string;
begin
  { program samo s funkcijama je knjiznica ili izvor podataka (fgl:): MAIN nije obavezan }
  if (Main = nil) and (Funcs.Count = 0) and (Reports.Count = 0) then
  begin
    ALog.Add('Nema MAIN bloka');
    Inc(AErrors);
  end
  else if Main <> nil then CheckFunc(Main);
  for I := 0 to Funcs.Count - 1 do CheckFunc(TFglFunc(Funcs.Objects[I]));
  for I := 0 to Reports.Count - 1 do CheckFunc(TFglReport(Reports.Objects[I]).Func);
  for I := 0 to UsedReports.Count - 1 do
  begin
    Nm := UsedReports.Names[I];
    S := UsedReports.ValueFromIndex[I];
    P := Pos('@', S);
    if Reports.IndexOf(Nm) < 0 then
      Err(StrToIntDef(Copy(S, P + 1, MaxInt), 0), StrToIntDef(Copy(S, 1, P - 1), 0), 'Izvješće ' + Nm + ' nije definirano (REPORT)');
  end;
  for I := 0 to UsedScreens.Count - 1 do
  begin
    Nm := UsedScreens.Names[I];
    S := UsedScreens.ValueFromIndex[I];
    P := Pos('@', S);
    if Screens.IndexOf(Nm) < 0 then
      Err(StrToIntDef(Copy(S, P + 1, MaxInt), 0), StrToIntDef(Copy(S, 1, P - 1), 0), 'Zaslon ' + Nm + ' nije definiran (SCREEN)');
  end;
  for I := 0 to UsedCursors.Count - 1 do
  begin
    Nm := UsedCursors.Names[I];
    S := UsedCursors.ValueFromIndex[I];
    P := Pos('@', S);
    if DeclCursors.IndexOf(Nm) < 0 then
      Err(StrToIntDef(Copy(S, P + 1, MaxInt), 0), StrToIntDef(Copy(S, 1, P - 1), 0), 'Kursor ' + Nm + ' nije deklariran');
  end;
end;

function TaFglProgram.CheckProgram(ALog: TStrings): Integer;
begin
  Result := 0;
  Check(ALog, Result);
end;

{ ============================ tumac ============================ }

type
  TFglHost = class(TaExprHost)
  public
    function FieldValue(const AName: string): Variant; override;
    function Aggregate(const AFunc, AField: string): Variant; override;
    function Variable(const AName: string): Variant; override;
  end;

function TFglHost.FieldValue(const AName: string): Variant;
begin
  Result := Null;
end;

function TFglHost.Aggregate(const AFunc, AField: string): Variant;
begin
  Result := Null;
end;

function TFglHost.Variable(const AName: string): Variant;
begin
  Result := Null;
end;

constructor TFglCell.Create(AKind: TFglCellKind);
begin
  Kind := AKind;
  V := Null;
  Ty := tyAny;
  if AKind <> ckScalar then
  begin
    Names := TStringList.Create;
    Items := TObjectList.Create(True);
  end;
end;

destructor TFglCell.Destroy;
begin
  Names.Free;
  Items.Free;
  inherited Destroy;
end;

constructor TFglFrame.Create;
begin
  Vars := TStringList.Create;
  Vars.OwnsObjects := True;
end;

destructor TFglFrame.Destroy;
begin
  Vars.Free;
  inherited Destroy;
end;

destructor TFglCursor.Destroy;
begin
  Q.Free;
  inherited Destroy;
end;

function SqlKindToTy(const ASqlType: string): TFglTypeKind;
var
  U: string;
begin
  U := UpperCase(ASqlType);
  if (Pos('DATETIME', U) > 0) or (Pos('TIMESTAMP', U) > 0) then Result := tyDateTime
  else if Pos('DATE', U) > 0 then Result := tyDate
  else if Pos('BOOL', U) > 0 then Result := tyBool
  else if Pos('INT', U) > 0 then Result := tyInt
  else if (Pos('REAL', U) > 0) or (Pos('FLOA', U) > 0) or (Pos('DOUB', U) > 0) or
    (Pos('DEC', U) > 0) or (Pos('NUM', U) > 0) then Result := tyFloat
  else Result := tyText;
end;

function CoerceV(ATy: TFglTypeKind; const V: Variant): Variant;
var
  S: string;
  Dt: TDateTime;
begin
  if IsNullV(V) then Exit(Null);
  case ATy of
    tyInt:
      begin
        if IsIntV(V) then Exit(Int64(V));
        Result := Int64(Round(ToNum(V, '')));
      end;
    tyFloat:
      Result := ToNum(V, '');
    tyText:
      Result := FglAsText(V);
    tyDate, tyDateTime:
      begin
        S := Trim(FglAsText(V));
        if S = '' then Exit(Null);
        if VarType(V) = varDate then Dt := V
        else if not ParseAnyDateTime(S, Dt) then raise Exception.Create(Tr('Not a date: "') + S + '"');
        if ATy = tyDate then Result := FormatDateTime('yyyy-mm-dd', Dt)
        else Result := FormatDateTime('yyyy-mm-dd hh:nn:ss', Dt);
      end;
    tyBool:
      begin
        if IsBoolV(V) then Exit(V);
        if VarIsNumeric(V) then Exit(Double(V) <> 0);
        S := UpperCase(Trim(VarToStr(V)));
        if (S = 'TRUE') or (S = '1') or (S = 'DA') or (S = 'T') then Result := True
        else if (S = 'FALSE') or (S = '0') or (S = 'NE') or (S = 'F') then Result := False
        else raise Exception.Create(Tr('Not a logical value: "') + S + '"');
      end;
  else
    Result := V;
  end;
end;

constructor TaFglRunner.Create(AProg: TaFglProgram; ADb: TAppDb; AIO: TaFglIO);
var
  C, E: TFglCell;
  I: Integer;
begin
  FProg := AProg;
  FDb := ADb;
  { funkcije izraza koje trebaju bazu (Predict, DLookup...) rade nad bazom programa }
  FSavedActiveDb := ActiveDb;
  if ADb <> nil then ActiveDb := ADb;
  FIO := AIO;
  FGlobals := TFglFrame.Create;
  FFrames := TObjectList.Create(False);
  FCursors := TStringList.Create;
  FCursors.OwnsObjects := True;
  FPrepared := TStringList.Create;
  FPreparedSql := TStringList.Create;
  FForms := TStringList.Create;
  FLikeCache := TStringList.Create;
  FReports := TStringList.Create;
  FReports.OwnsObjects := True;
  { SQLCA, STATUS, INT_FLAG }
  C := TFglCell.Create(ckRecord);
  C.Names.Add('sqlcode'); E := TFglCell.Create(ckScalar); E.Ty := tyInt; E.V := 0; C.Items.Add(E);
  C.Names.Add('sqlerrm'); E := TFglCell.Create(ckScalar); E.Ty := tyText; C.Items.Add(E);
  C.Names.Add('sqlerrd'); E := TFglCell.Create(ckArray); E.Size := 6;
  for I := 1 to 6 do
  begin
    E.Items.Add(TFglCell.Create(ckScalar));
    TFglCell(E.Items[I - 1]).Ty := tyInt;
    TFglCell(E.Items[I - 1]).V := 0;
  end;
  C.Items.Add(E);
  FGlobals.Vars.AddObject('sqlca', C);
  C := TFglCell.Create(ckScalar); C.Ty := tyInt; C.V := 0;
  FGlobals.Vars.AddObject('status', C);
  C := TFglCell.Create(ckScalar); C.Ty := tyBool; C.V := False;
  FGlobals.Vars.AddObject('int_flag', C);
  C := TFglCell.Create(ckScalar); C.Ty := tyInt; C.V := 0;
  FGlobals.Vars.AddObject('arr_count', C);
  C := TFglCell.Create(ckScalar); C.Ty := tyInt; C.V := 0;
  FGlobals.Vars.AddObject('arr_curr', C);
end;

destructor TaFglRunner.Destroy;
begin
  ActiveDb := FSavedActiveDb;
  FScripts.Free;
  FScriptCtx.Free;
  FCursors.Free;
  FPrepared.Free;
  FPreparedSql.Free;
  FForms.Free;
  FLikeCache.Free;
  FReports.Free;
  FFrames.Free;
  FGlobals.Free;
  inherited Destroy;
end;

function TaFglRunner.Frame: TFglFrame;
begin
  if FFrames.Count > 0 then Result := TFglFrame(FFrames[FFrames.Count - 1]) else Result := FGlobals;
end;

function TaFglRunner.FindCell(const AName: string): TFglCell;
var
  K: Integer;
  L: string;
begin
  L := LowerCase(AName);
  K := Frame.Vars.IndexOf(L);
  if K >= 0 then Exit(TFglCell(Frame.Vars.Objects[K]));
  K := FGlobals.Vars.IndexOf(L);
  if K >= 0 then Exit(TFglCell(FGlobals.Vars.Objects[K]));
  Result := nil;
end;

procedure TaFglRunner.Fail(N: TNode; const AMsg: string);
var
  E: EFglError;
  F: string;
begin
  if N <> nil then
  begin
    F := FProg.Files[N.Src];
    E := EFglError.Create(F + ':' + IntToStr(N.Line) + ': ' + AMsg);
    E.FileName := F; E.Line := N.Line;
  end
  else E := EFglError.Create(AMsg);
  raise E;
end;

function TaFglRunner.LikeRecordType(const ATable: string; AAt: TNode): TFglType;
var
  K: Integer;
  Q: TZQuery;
begin
  K := FLikeCache.IndexOf(LowerCase(ATable));
  if K >= 0 then Exit(TFglType(FLikeCache.Objects[K]));
  Result := FProg.NewType(tyRecord);
  Q := nil;
  try
    Q := FDb.TableInfo(ATable);
    while not Q.EOF do
    begin
      Result.FieldNames.Add(Q.FieldByName('name').AsString);
      Result.FieldTypes.Add(FProg.NewType(SqlKindToTy(Q.FieldByName('type').AsString)));
      Q.Next;
    end;
  finally
    Q.Free;
  end;
  if Result.FieldNames.Count = 0 then Fail(AAt, 'Nema tablice ' + ATable);
  FLikeCache.AddObject(LowerCase(ATable), Result);
end;

function TaFglRunner.NewCell(ATy: TFglType; AAt: TNode): TFglCell;
var
  T, R: TFglType;
  I, K: Integer;
begin
  T := ATy;
  if (T.Kind = tyAny) and (T.LikeCol <> '') then
  begin
    R := LikeRecordType(T.LikeTable, AAt);
    K := R.FieldNames.IndexOf(T.LikeCol);
    if K < 0 then Fail(AAt, 'Nema stupca ' + T.LikeTable + '.' + T.LikeCol);
    Exit(NewCell(TFglType(R.FieldTypes[K]), AAt));
  end;
  if T.Kind = tyRecord then
  begin
    if T.LikeTable <> '' then T := LikeRecordType(T.LikeTable, AAt);
    Result := TFglCell.Create(ckRecord);
    for I := 0 to T.FieldNames.Count - 1 do
    begin
      Result.Names.Add(T.FieldNames[I]);
      Result.Items.Add(NewCell(TFglType(T.FieldTypes[I]), AAt));
    end;
  end
  else if T.Kind = tyArray then
  begin
    Result := TFglCell.Create(ckArray);
    Result.ElemType := T.Elem;
    Result.Size := T.Size;
    for I := 1 to T.Size do Result.Items.Add(NewCell(T.Elem, AAt));
  end
  else
  begin
    Result := TFglCell.Create(ckScalar);
    Result.Ty := T.Kind;
  end;
end;

function TaFglRunner.ResolveVar(N: TNode; AAutoGrow: Boolean): TFglCell;
var
  I, K: Integer;
  S: TNode;
  Idx: Int64;
  V: Variant;
begin
  Result := FindCell(N.Text);
  if Result = nil then Fail(N, 'Nedefinirana varijabla ' + N.Text);
  if N.L1 = nil then Exit;
  for I := 0 to N.L1.Count - 1 do
  begin
    S := TNode(N.L1[I]);
    if S.Kind = nkField then
    begin
      if Result.Kind <> ckRecord then Fail(N, N.Text + ' nije zapis');
      if S.Text = '*' then Continue;
      K := Result.Names.IndexOf(S.Text);
      if K < 0 then Fail(N, 'Zapis nema polje ' + S.Text);
      Result := TFglCell(Result.Items[K]);
    end
    else
    begin
      if Result.Kind <> ckArray then Fail(N, N.Text + ' nije polje (array)');
      V := Eval(S.A);
      if IsNullV(V) then Fail(N, 'Indeks polja je NULL');
      Idx := Round(ToNum(V, ''));
      if Idx < 1 then Fail(N, 'Indeks polja mora biti >= 1');
      if Idx > Result.Items.Count then
      begin
        if (Result.Size = 0) and AAutoGrow then
          while Result.Items.Count < Idx do Result.Items.Add(NewCell(Result.ElemType, N))
        else Fail(N, 'Indeks ' + IntToStr(Idx) + ' izvan polja (' + IntToStr(Result.Items.Count) + ')');
      end;
      Result := TFglCell(Result.Items[Idx - 1]);
    end;
  end;
end;

procedure TaFglRunner.Flatten(ACell: TFglCell; AOut: TList);
var
  I: Integer;
begin
  if ACell.Kind = ckScalar then AOut.Add(ACell)
  else for I := 0 to ACell.Items.Count - 1 do Flatten(TFglCell(ACell.Items[I]), AOut);
end;

procedure TaFglRunner.FlattenNamed(ACell: TFglCell; const AName: string; AOut: TList; ANames: TStrings);
var
  I: Integer;
begin
  if ACell.Kind = ckScalar then
  begin
    AOut.Add(ACell);
    ANames.Add(AName);
  end
  else if ACell.Kind = ckRecord then
    for I := 0 to ACell.Items.Count - 1 do
      FlattenNamed(TFglCell(ACell.Items[I]), ACell.Names[I], AOut, ANames)
  else
    for I := 0 to ACell.Items.Count - 1 do
      FlattenNamed(TFglCell(ACell.Items[I]), AName + '[' + IntToStr(I + 1) + ']', AOut, ANames);
end;

procedure TaFglRunner.FlattenNodes(AList: TFPList; AOut: TList; ANames: TStrings);
var
  I: Integer;
  N, Last: TNode;
  C: TFglCell;
  Nm: string;
begin
  if AList = nil then Exit;
  for I := 0 to AList.Count - 1 do
  begin
    N := TNode(AList[I]);
    C := ResolveVar(N, True);
    Nm := N.Text;
    if N.L1 <> nil then
    begin
      Last := TNode(N.L1[N.L1.Count - 1]);
      if (Last.Kind = nkField) and (Last.Text <> '*') then Nm := Last.Text;
    end;
    if ANames <> nil then FlattenNamed(C, Nm, AOut, ANames) else Flatten(C, AOut);
  end;
end;

procedure TaFglRunner.SetCell(ACell: TFglCell; const V: Variant);
begin
  if ACell.Kind <> ckScalar then raise Exception.Create(Tr('The record or field cannot take a single value'));
  ACell.V := CoerceV(ACell.Ty, V);
end;

procedure TaFglRunner.CopyRecord(ADst, ASrc: TFglCell);
var
  D, S: TList;
  I: Integer;
begin
  D := TList.Create;
  S := TList.Create;
  try
    Flatten(ADst, D);
    Flatten(ASrc, S);
    for I := 0 to Min(D.Count, S.Count) - 1 do SetCell(TFglCell(D[I]), TFglCell(S[I]).V);
  finally
    D.Free;
    S.Free;
  end;
end;

procedure TaFglRunner.SetIntFlag(AValue: Boolean);
begin
  TFglCell(FGlobals.Vars.Objects[FGlobals.Vars.IndexOf('int_flag')]).V := AValue;
end;

procedure TaFglRunner.SetSqlStatus(ACode, ARows: Integer; const AMsg: string);
var
  C: TFglCell;
begin
  C := TFglCell(FGlobals.Vars.Objects[FGlobals.Vars.IndexOf('sqlca')]);
  TFglCell(C.Items[0]).V := ACode;
  TFglCell(C.Items[1]).V := AMsg;
  if ARows >= 0 then TFglCell(TFglCell(C.Items[2]).Items[2]).V := ARows;
  TFglCell(FGlobals.Vars.Objects[FGlobals.Vars.IndexOf('status')]).V := ACode;
end;

{ ---- izrazi ---- }

function FormatLiteral(const V: Variant): string;
begin
  if IsNullV(V) then Exit('Null');
  if IsBoolV(V) then
  begin
    if Boolean(V) then Exit('True') else Exit('False');
  end;
  if IsIntV(V) then Exit(IntToStr(Int64(V)));
  if VarIsFloat(V) then Exit(FloatToStr(Double(V), ParseFS));
  Result := '"' + StringReplace(VarToStr(V), '"', '""', [rfReplaceAll]) + '"';
end;

{ Informix USING: # znamenka ili razmak, & znamenka ili nula, , tisućice, . decimale, - predznak, < ulijevo }
function InformixPicture(const AFmt: string): Boolean;
var
  I: Integer;
begin
  Result := (Pos('#', AFmt) > 0) or (Pos('&', AFmt) > 0);
  if not Result then Exit;
  for I := 1 to Length(AFmt) do
    if (AFmt[I] = '0') or (UpCase(AFmt[I]) in ['A'..'Z']) then Exit(False);
end;

function FglUsingNumber(D: Double; const AFmt: string): string;
var
  DotPos, I, DecN, Di, F, P, K: Integer;
  Neg, SignSlot: Boolean;
  S, IntPart, FracPart, LeftPic, RightPic, Res, FracRes: string;
  C: Char;
begin
  DotPos := Pos('.', AFmt);
  if DotPos = 0 then begin LeftPic := AFmt; RightPic := ''; end
  else begin LeftPic := Copy(AFmt, 1, DotPos - 1); RightPic := Copy(AFmt, DotPos + 1, MaxInt); end;
  DecN := 0;
  for I := 1 to Length(RightPic) do
    if RightPic[I] in ['#', '&'] then Inc(DecN);
  Neg := D < 0;
  S := FloatToStrF(Abs(D), ffFixed, 18, DecN, ParseFS);
  P := Pos('.', S);
  if P = 0 then begin IntPart := S; FracPart := ''; end
  else begin IntPart := Copy(S, 1, P - 1); FracPart := Copy(S, P + 1, MaxInt); end;
  Di := Length(IntPart);
  Res := '';
  SignSlot := False;
  for I := Length(LeftPic) downto 1 do
  begin
    C := LeftPic[I];
    case C of
      '#': if Di > 0 then begin Res := IntPart[Di] + Res; Dec(Di); end else Res := ' ' + Res;
      '&': if Di > 0 then begin Res := IntPart[Di] + Res; Dec(Di); end else Res := '0' + Res;
      ',': if Di > 0 then Res := ',' + Res else Res := ' ' + Res;
      '-': begin
             if Neg and not SignSlot then Res := '-' + Res else Res := ' ' + Res;
             SignSlot := True;
           end;
      '<': ;
    else
      Res := C + Res;
    end;
  end;
  if Di > 0 then Exit(StringOfChar('*', Length(Res) + Di));
  if Neg and not SignSlot then
  begin
    K := 1;
    while (K <= Length(Res)) and (Res[K] = ' ') do Inc(K);
    if K > 1 then Res[K - 1] := '-' else Res := '-' + Res;
  end;
  if Pos('<', LeftPic) > 0 then Res := TrimLeft(Res);
  Result := Res;
  if DotPos > 0 then
  begin
    FracRes := '';
    F := 1;
    for I := 1 to Length(RightPic) do
    begin
      C := RightPic[I];
      if C in ['#', '&'] then
      begin
        if F <= Length(FracPart) then FracRes := FracRes + FracPart[F] else FracRes := FracRes + '0';
        Inc(F);
      end
      else if C <> '<' then FracRes := FracRes + C;
    end;
    Result := Result + '.' + FracRes;
  end;
end;

function TaFglRunner.Eval(N: TNode): Variant;
var
  C: TFglCell;
  A, B, X: Variant;
  I: Integer;
  Args: array of Variant;
  F: string;
  Dt: TDateTime;
  Dt2: Double;
begin
  case N.Kind of
    nkLit: Result := N.V;
    nkVar:
      begin
        C := ResolveVar(N, False);
        if C.Kind <> ckScalar then Fail(N, N.Text + ' je zapis ili polje, a ocekujem jednu vrijednost');
        Result := C.V;
      end;
    nkBin: Result := EvalBin(N);
    nkUn:
      begin
        A := Eval(N.A);
        if IsNullV(A) then Exit(Null);
        if N.Text = 'NOT' then Result := not Truth(A)
        else if IsIntV(A) then Result := -Int64(A)
        else Result := -ToNum(A, '');
      end;
    nkIsNull:
      Result := IsNullV(Eval(N.A)) xor N.Flag;
    nkBetween:
      begin
        A := Eval(N.A); B := Eval(N.B); X := Eval(N.C);
        if IsNullV(A) or IsNullV(B) or IsNullV(X) then Exit(False);
        Result := (CompareV(A, B) >= 0) and (CompareV(A, X) <= 0);
        if N.Flag then Result := not Boolean(Result);
      end;
    nkInList:
      begin
        A := Eval(N.A);
        if IsNullV(A) then Exit(False);
        Result := False;
        for I := 0 to N.L1.Count - 1 do
          if CompareV(A, Eval(TNode(N.L1[I]))) = 0 then begin Result := True; Break; end;
        if N.Flag then Result := not Boolean(Result);
      end;
    nkUsing:
      begin
        A := Eval(N.A);
        F := FglAsText(Eval(N.B));
        if IsNullV(A) then Exit('');
        if InformixPicture(F) and (IsNumV(A) or IsBoolV(A) or ParseNumber(Trim(VarToStr(A)), Dt2)) then
        begin
          if IsNumV(A) or IsBoolV(A) then Dt2 := ToNum(A, '');
          Exit(FglUsingNumber(Dt2, F));
        end;
        if (not IsNumV(A)) and (not IsBoolV(A)) and ParseAnyDateTime(VarToStr(A), Dt) and
          (Pos('-', VarToStr(A)) > 0) then
          Result := FormatValue(Dt, F)
        else if IsNumV(A) then Result := FormatValue(Double(A), F)
        else Result := FormatValue(A, F);
      end;
    nkAggregate: Result := AggValue(N);
    nkCall:
      begin
        SetLength(Args, 0);
        if N.L1 <> nil then
        begin
          SetLength(Args, N.L1.Count);
          for I := 0 to N.L1.Count - 1 do Args[I] := Eval(TNode(N.L1[I]));
        end;
        if not CallFunction(N, N.Text, Args, Result) then
          Fail(N, 'Nepoznata funkcija ' + N.Text);
      end;
  else
    Fail(N, 'Nepodrzan izraz');
  end;
end;

function TaFglRunner.EvalBin(N: TNode): Variant;
var
  A, B: Variant;
  C: Integer;
  X, Y: Double;
begin
  if N.Text = 'AND' then
  begin
    A := Eval(N.A);
    if (not IsNullV(A)) and (not Truth(A)) then Exit(False);
    B := Eval(N.B);
    Exit(Truth(A) and Truth(B));
  end;
  if N.Text = 'OR' then
  begin
    A := Eval(N.A);
    if Truth(A) then Exit(True);
    Exit(Truth(Eval(N.B)));
  end;
  A := Eval(N.A);
  B := Eval(N.B);
  if N.Text = '||' then Exit(FglAsText(A) + FglAsText(B));
  if (N.Text = 'LIKE') or (N.Text = 'MATCHES') then
  begin
    if IsNullV(A) or IsNullV(B) then Exit(False);
    if N.Text = 'LIKE' then Result := WildMatch(FglAsText(A), FglAsText(B), '%', '_')
    else Result := WildMatch(FglAsText(A), FglAsText(B), '*', '?');
    if N.Flag then Result := not Boolean(Result);
    Exit;
  end;
  if InArr(N.Text, ['=', '<>', '<', '>', '<=', '>=']) then
  begin
    C := CompareV(A, B);
    if C = -2 then Exit(False);
    if N.Text = '=' then Result := C = 0
    else if N.Text = '<>' then Result := C <> 0
    else if N.Text = '<' then Result := C < 0
    else if N.Text = '>' then Result := C > 0
    else if N.Text = '<=' then Result := C <= 0
    else Result := C >= 0;
    Exit;
  end;
  { aritmetika }
  if IsNullV(A) or IsNullV(B) then Exit(Null);
  if IsIntV(A) and IsIntV(B) and ((N.Text = '+') or (N.Text = '-') or (N.Text = '*')) then
  begin
    if N.Text = '+' then Exit(Int64(A) + Int64(B));
    if N.Text = '-' then Exit(Int64(A) - Int64(B));
    Exit(Int64(A) * Int64(B));
  end;
  X := ToNum(A, ''); Y := ToNum(B, '');
  if N.Text = '+' then Result := X + Y
  else if N.Text = '-' then Result := X - Y
  else if N.Text = '*' then Result := X * Y
  else if N.Text = '/' then
  begin
    if Y = 0 then Fail(N, 'Dijeljenje s nulom');
    Result := X / Y;
  end
  else if N.Text = 'MOD' then
  begin
    if Round(Y) = 0 then Fail(N, 'Dijeljenje s nulom');
    Result := Int64(Round(X)) mod Int64(Round(Y));
  end
  else if N.Text = '^' then Result := Power(X, Y)
  else Fail(N, 'Nepoznat operator ' + N.Text);
end;

function TaFglRunner.AccessFunc(N: TNode; const AName: string; const AArgs: array of Variant): Variant;
var
  Expr, Err: string;
  I: Integer;
  Host: TFglHost;
begin
  Expr := AName + '(';
  for I := 0 to High(AArgs) do
  begin
    if I > 0 then Expr := Expr + ', ';
    Expr := Expr + FormatLiteral(AArgs[I]);
  end;
  Expr := Expr + ')';
  Host := TFglHost.Create;
  try
    Result := EvalExprEx(Expr, Host, Err);
  finally
    Host.Free;
  end;
  if Err <> '' then Fail(N, 'Funkcija ' + AName + ': ' + Err);
  if VarType(Result) = varDate then Result := FormatDateTime('yyyy-mm-dd', Result);
end;

function TaFglRunner.BuiltinFunc(const AName: string; const AArgs: array of Variant;
  out AResult: Variant): Boolean;
var
  S, Ch: string;
  St, Ln: Integer;
begin
  Result := True;
  if AName = 'today' then AResult := FormatDateTime('yyyy-mm-dd', Date)
  else if AName = 'current' then AResult := FormatDateTime('yyyy-mm-dd hh:nn:ss', Now)
  else if AName = 'pageno' then
  begin
    if FRun <> nil then AResult := Int64(FRun.PageNo) else AResult := Int64(0);
  end
  else if AName = 'lineno' then
  begin
    if (FRun <> nil) and (FRun.CurLines <> nil) then AResult := Int64(FRun.CurLines.Count + 1) else AResult := Int64(0);
  end
  else if (AName = 'length') and (Length(AArgs) = 1) then
  begin
    if IsNullV(AArgs[0]) then AResult := Null else AResult := Int64(UTF8Length(FglAsText(AArgs[0])));
  end
  else if ((AName = 'lpad') or (AName = 'rpad') or (AName = 'center')) and (Length(AArgs) in [2, 3]) then
  begin
    S := FglAsText(AArgs[0]);
    St := Round(ToNum(AArgs[1], ''));
    Ch := ' ';
    if Length(AArgs) = 3 then Ch := FglAsText(AArgs[2]);
    if Ch = '' then Ch := ' ';
    Ln := St - UTF8Length(S);
    if Ln <= 0 then AResult := UTF8Copy(S, 1, St)
    else if AName = 'lpad' then AResult := StringOfChar(Ch[1], Ln) + S
    else if AName = 'rpad' then AResult := S + StringOfChar(Ch[1], Ln)
    else AResult := StringOfChar(Ch[1], Ln div 2) + S + StringOfChar(Ch[1], Ln - Ln div 2);
  end
  else if (AName = 'trimright') and (Length(AArgs) = 1) then AResult := TrimRight(FglAsText(AArgs[0]))
  else if (AName = 'upper') and (Length(AArgs) = 1) then AResult := UTF8UpperCase(FglAsText(AArgs[0]))
  else if (AName = 'lower') and (Length(AArgs) = 1) then AResult := UTF8LowerCase(FglAsText(AArgs[0]))
  else if (AName = 'trim') and (Length(AArgs) = 1) then AResult := Trim(FglAsText(AArgs[0]))
  else if (AName = 'nvl') and (Length(AArgs) = 2) then
  begin
    if IsNullV(AArgs[0]) then AResult := AArgs[1] else AResult := AArgs[0];
  end
  else if (AName = 'substr') and (Length(AArgs) in [2, 3]) then
  begin
    S := FglAsText(AArgs[0]);
    St := Round(ToNum(AArgs[1], ''));
    if Length(AArgs) = 3 then Ln := Round(ToNum(AArgs[2], '')) else Ln := MaxInt;
    AResult := UTF8Copy(S, St, Ln);
  end
  else if (AName = 'ask') and (Length(AArgs) = 1) then AResult := FIO.Ask(FglAsText(AArgs[0]))
  else Result := False;
end;

function TaFglRunner.CallFunction(N: TNode; const AName: string; const AArgs: array of Variant;
  out AResult: Variant): Boolean;
var
  L: string;
  K: Integer;
  Fr: TFglFrame;
begin
  Result := True;
  AResult := Null;
  L := LowerCase(AName);
  if Copy(L, 1, 4) = 'pas.' then
  begin
    if FScripts = nil then
    begin
      FScripts := TaScripts.Create(FDb);
      FScriptCtx := TaScriptContext.Create(FDb);
    end;
    if not FScripts.CallProc(FScriptCtx, Copy(AName, 5, MaxInt), AArgs, AResult) then
      Fail(N, 'Nema PascalScript funkcije ' + Copy(AName, 5, MaxInt));
    Exit;
  end;
  K := FProg.Funcs.IndexOf(L);
  if K >= 0 then
  begin
    Fr := CallUser(TFglFunc(FProg.Funcs.Objects[K]), AArgs, N);
    try
      if Length(Fr.Ret) > 0 then AResult := Fr.Ret[0];
    finally
      Fr.Free;
    end;
    Exit;
  end;
  if BuiltinFunc(L, AArgs, AResult) then Exit;
  AResult := AccessFunc(N, AName, AArgs);
end;

function TaFglRunner.CallUser(F: TFglFunc; const AArgs: array of Variant; AAt: TNode): TFglFrame;
var
  I: Integer;
  C: TFglCell;
  T: TFglType;
  R: TFglFlow;
begin
  if Length(AArgs) <> F.Params.Count then
    Fail(AAt, 'Funkcija ' + F.Name + ' ocekuje ' + IntToStr(F.Params.Count) + ' argumenata, a dobila je ' + IntToStr(Length(AArgs)));
  if FDepth > 200 then Fail(AAt, 'Predubok poziv funkcija (rekurzija?)');
  Result := TFglFrame.Create;
  for I := 0 to F.Params.Count - 1 do
  begin
    C := TFglCell.Create(ckScalar);
    T := TFglType(F.ParamTypes[I]);
    if (T <> nil) and (T.Kind in [tyInt, tyFloat, tyText, tyDate, tyDateTime, tyBool]) then C.Ty := T.Kind;
    C.V := CoerceV(C.Ty, AArgs[I]);
    Result.Vars.AddObject(LowerCase(F.Params[I]), C);
  end;
  FFrames.Add(Result);
  Inc(FDepth);
  try
    R := ExecList(F.Body);
    if R = flExitProgram then FExiting := True;
  finally
    Dec(FDepth);
    FFrames.Delete(FFrames.Count - 1);
  end;
end;

{ ---- naredbe ---- }

function TaFglRunner.ExecList(L: TFPList): TFglFlow;
var
  I: Integer;
begin
  Result := flNone;
  if L = nil then Exit;
  for I := 0 to L.Count - 1 do
  begin
    Result := Exec(TNode(L[I]));
    if FExiting then Exit(flExitProgram);
    if Result <> flNone then Exit;
  end;
end;

function TaFglRunner.Exec(N: TNode): TFglFlow;
begin
  if (FDeadlineAt > 0) and (GetTickCount64 > FDeadlineAt) then
    Fail(N, 'Izvrsavanje je prekoraceno (najvise ' + IntToStr(FTimeLimitMs) + ' ms)');
  try
    Result := ExecStmt(N);
  except
    on E: EFglError do raise;
    on E: Exception do
    begin
      if FContinueOnError and (N.Kind in [nkSql, nkOpen, nkFetch, nkForeach, nkExecute, nkTrans, nkDeclare, nkPrepare]) then
      begin
        SetSqlStatus(-1, 0, E.Message);
        Result := flNone;
      end
      else Fail(N, E.Message);
    end;
  end;
end;

function TaFglRunner.ExecStmt(N: TNode): TFglFlow;
var
  V: Variant;
  I: Integer;
  Args: TVariantArray;
  S: string;
begin
  Result := flNone;
  case N.Kind of
    nkDefine: ExecDefine(N);
    nkLet: ExecLet(N);
    nkIf: Result := ExecIf(N);
    nkWhile: Result := ExecWhile(N);
    nkFor: Result := ExecFor(N);
    nkForeach: Result := ExecForeach(N);
    nkCase: Result := ExecCase(N);
    nkMenu: Result := ExecMenu(N);
    nkInput: Result := ExecInput(N);
    nkConstruct: ExecConstruct(N);
    nkPrint: ExecPrint(N);
    nkSkip: ExecSkip(N);
    nkNeed: ExecNeed(N);
    nkStartReport: ExecStartReport(N);
    nkOutputReport: ExecOutputReport(N);
    nkFinishReport: ExecFinishReport(N);
    nkDisplayArray: ExecArray(N, False);
    nkInputArray: ExecArray(N, True);
    nkPrompt: ExecPrompt(N);
    nkCallStmt: ExecCall(N);
    nkSql: ExecSql(N);
    nkTrans: ExecTrans(N);
    nkDeclare: ExecDeclare(N);
    nkPrepare: ExecPrepare(N);
    nkExecute: ExecExecute(N);
    nkOpen: ExecOpen(N);
    nkFetch: ExecFetch(N);
    nkClose: ExecClose(N, False);
    nkFree: ExecClose(N, True);
    nkInitialize: ExecInitialize(N);
    nkDisplay, nkDisplayName, nkMessage, nkError: ExecDisplay(N);
    nkOpenForm:
      begin
        S := FglAsText(Eval(N.A));
        if FDb.LoadObject('_sys_forms', S) = '' then Fail(N, 'Nema forme "' + S + '"');
        if FForms.IndexOfName(N.Text) >= 0 then FForms.Values[N.Text] := S else FForms.Add(N.Text + '=' + S);
      end;
    nkDisplayForm:
      begin
        if FForms.IndexOfName(N.Text) < 0 then Fail(N, 'Forma ' + N.Text + ' nije otvorena (OPEN FORM)');
        S := '';
        if N.A <> nil then S := FglAsText(Eval(N.A));
        FIO.RunForm(FDb, FForms.Values[N.Text], S);
      end;
    nkReturn:
      begin
        with Frame do
        begin
          SetLength(Ret, 0);
          if N.L1 <> nil then
          begin
            SetLength(Ret, N.L1.Count);
            for I := 0 to N.L1.Count - 1 do Ret[I] := Eval(TNode(N.L1[I]));
          end;
        end;
        Result := flReturn;
      end;
    nkExit:
      begin
        FFlowKind := N.Text;
        Result := flExit;
      end;
    nkContinue:
      begin
        FFlowKind := N.Text;
        Result := flContinue;
      end;
    nkNextField: FNextField := N.Text;
    nkWhenever: FContinueOnError := N.Text = 'CONTINUE';
    nkColumns:
      if FCollector <> nil then
      begin
        if FCollector.RowCount > 0 then Fail(N, 'COLUMNS mora prethoditi prvom EMIT-u');
        FCollector.ColNames.Clear;
        FCollector.ColTypes.Clear;
        for I := 0 to N.Names.Count - 1 do
          FCollector.AddColumn(N.Names.Names[I], N.Names.ValueFromIndex[I]);
      end;
    nkEmit:
      begin
        if FCollector = nil then Fail(N, 'EMIT je dopusten samo kad se program koristi kao izvor podataka');
        Args := EvalListToArray(N.L1);
        if FCollector.ColNames.Count = 0 then
          for I := 0 to High(Args) do FCollector.AddColumn('c' + IntToStr(I + 1), 'text');
        if Length(Args) <> FCollector.ColNames.Count then
          Fail(N, 'EMIT ima ' + IntToStr(Length(Args)) + ' vrijednosti, a COLUMNS ' + IntToStr(FCollector.ColNames.Count) + ' stupaca');
        try
          FCollector.AddRow(Args);
        except
          on E: EFglError do Fail(N, E.Message);
        end;
      end;
    nkSleep:
      begin
        V := Eval(N.A);
        if not IsNullV(V) then Sleep(Round(ToNum(V, '') * 1000));
      end;
    nkExitProgram:
      begin
        FExitCode := 0;
        if N.A <> nil then FExitCode := Round(ToNum(Eval(N.A), ''));
        FExiting := True;
        Result := flExitProgram;
      end;
  else
    Fail(N, 'Nepodrzana naredba');
  end;
end;

procedure TaFglRunner.ExecDefine(N: TNode);
var
  I, K: Integer;
  Fr: TFglFrame;
  C: TFglCell;
  Nm: string;
begin
  Fr := Frame;
  for I := 0 to N.Names.Count - 1 do
  begin
    Nm := LowerCase(N.Names[I]);
    K := Fr.Vars.IndexOf(Nm);
    if (K >= 0) and (N.Typ.Kind in [tyInt, tyFloat, tyText, tyDate, tyDateTime, tyBool]) and
      (TFglCell(Fr.Vars.Objects[K]).Kind = ckScalar) then
    begin
      { tip za vec postojeci parametar }
      C := TFglCell(Fr.Vars.Objects[K]);
      C.Ty := N.Typ.Kind;
      C.V := CoerceV(C.Ty, C.V);
      Continue;
    end;
    C := NewCell(N.Typ, N);
    if K >= 0 then Fr.Vars.Delete(K);
    Fr.Vars.AddObject(Nm, C);
  end;
end;

procedure TaFglRunner.ExecLet(N: TNode);
var
  Target, Src: TFglCell;
begin
  Target := ResolveVar(N.A, True);
  if Target.Kind <> ckScalar then
  begin
    if (N.B.Kind = nkLit) and IsNullV(N.B.V) then
      ExecInitializeCell(Target)
    else if N.B.Kind = nkVar then
    begin
      Src := ResolveVar(N.B, False);
      if Src.Kind = ckScalar then Fail(N, 'Zapisu se ne moze dodijeliti jedna vrijednost');
      CopyRecord(Target, Src);
    end
    else Fail(N, 'Zapisu se moze dodijeliti drugi zapis ili NULL');
    Exit;
  end;
  SetCell(Target, Eval(N.B));
end;

procedure TaFglRunner.ExecInitializeCell(ACell: TFglCell);
var
  L: TList;
  I: Integer;
begin
  L := TList.Create;
  try
    Flatten(ACell, L);
    for I := 0 to L.Count - 1 do TFglCell(L[I]).V := Null;
  finally
    L.Free;
  end;
end;

procedure TaFglRunner.ExecInitialize(N: TNode);
var
  I: Integer;
begin
  for I := 0 to N.L2.Count - 1 do ExecInitializeCell(ResolveVar(TNode(N.L2[I]), True));
end;

function TaFglRunner.ExecIf(N: TNode): TFglFlow;
begin
  if Truth(Eval(N.A)) then Result := ExecList(N.L1)
  else Result := ExecList(N.L2);
end;

function TaFglRunner.ExecWhile(N: TNode): TFglFlow;
var
  R: TFglFlow;
begin
  Result := flNone;
  while Truth(Eval(N.A)) do
  begin
    R := ExecList(N.L1);
    if R = flExit then
    begin
      if FFlowKind = 'WHILE' then Break else Exit(R);
    end
    else if R = flContinue then
    begin
      if FFlowKind <> 'WHILE' then Exit(R);
    end
    else if R <> flNone then Exit(R);
  end;
end;

function TaFglRunner.ExecFor(N: TNode): TFglFlow;
var
  C: TFglCell;
  From, ToV, Step, I: Double;
  R: TFglFlow;
begin
  Result := flNone;
  C := FindCell(N.A.Text);
  if C = nil then
  begin
    C := TFglCell.Create(ckScalar);
    C.Ty := tyInt;
    Frame.Vars.AddObject(LowerCase(N.A.Text), C);
  end;
  From := ToNum(Eval(N.B), '');
  ToV := ToNum(Eval(N.C), '');
  Step := 1;
  if N.D <> nil then Step := ToNum(Eval(N.D), '');
  if Step = 0 then Fail(N, 'STEP ne smije biti 0');
  I := From;
  while ((Step > 0) and (I <= ToV)) or ((Step < 0) and (I >= ToV)) do
  begin
    if Frac(I) = 0 then SetCell(C, Int64(Round(I))) else SetCell(C, I);
    R := ExecList(N.L1);
    if R = flExit then
    begin
      if FFlowKind = 'FOR' then Break else Exit(R);
    end
    else if R = flContinue then
    begin
      if FFlowKind <> 'FOR' then Exit(R);
    end
    else if R <> flNone then Exit(R);
    I := I + Step;
  end;
end;

function TaFglRunner.ExecCase(N: TNode): TFglFlow;
var
  I: Integer;
  W: TNode;
  V: Variant;
  Hit: Boolean;
begin
  if N.A <> nil then V := Eval(N.A);
  if N.L1 <> nil then
    for I := 0 to N.L1.Count - 1 do
    begin
      W := TNode(N.L1[I]);
      if N.A <> nil then Hit := CompareV(V, Eval(W.A)) = 0 else Hit := Truth(Eval(W.A));
      if Hit then Exit(ExecList(W.L1));
    end;
  Result := ExecList(N.L2);
end;

function TaFglRunner.ExecMenu(N: TNode): TFglFlow;
var
  Names, Helps: TStringList;
  I, K: Integer;
  C: TNode;
  R: TFglFlow;
  Title: string;
begin
  Result := flNone;
  Names := TStringList.Create;
  Helps := TStringList.Create;
  try
    Title := FglAsText(Eval(N.A));
    if N.L1 <> nil then
      for I := 0 to N.L1.Count - 1 do
      begin
        C := TNode(N.L1[I]);
        Names.Add(FglAsText(Eval(C.A)));
        if C.B <> nil then Helps.Add(FglAsText(Eval(C.B))) else Helps.Add('');
      end;
    while True do
    begin
      K := FIO.Menu(Title, Names, Helps);
      if K < 0 then Break;
      R := ExecList(TNode(N.L1[K]).L1);
      if FExiting then Exit(flExitProgram);
      if R = flExit then
      begin
        if FFlowKind = 'MENU' then Break else Exit(R);
      end
      else if R = flContinue then
      begin
        if FFlowKind <> 'MENU' then Exit(R);
      end
      else if R <> flNone then Exit(R);
    end;
  finally
    Names.Free;
    Helps.Free;
  end;
end;

procedure TaFglRunner.ExecCall(N: TNode);
var
  Args: array of Variant;
  I, K: Integer;
  Res: Variant;
  Fr: TFglFrame;
  Targets: TList;
  Call: TNode;
begin
  Call := N.A;
  SetLength(Args, 0);
  if Call.L1 <> nil then
  begin
    SetLength(Args, Call.L1.Count);
    for I := 0 to Call.L1.Count - 1 do Args[I] := Eval(TNode(Call.L1[I]));
  end;
  Targets := TList.Create;
  try
    FlattenNodes(N.L2, Targets, nil);
    K := FProg.Funcs.IndexOf(LowerCase(Call.Text));
    if (K >= 0) and (Copy(LowerCase(Call.Text), 1, 4) <> 'pas.') then
    begin
      Fr := CallUser(TFglFunc(FProg.Funcs.Objects[K]), Args, N);
      try
        if Targets.Count > Length(Fr.Ret) then
          Fail(N, 'Funkcija ' + Call.Text + ' vraca ' + IntToStr(Length(Fr.Ret)) + ' vrijednosti, a trazi se ' + IntToStr(Targets.Count));
        for I := 0 to Targets.Count - 1 do SetCell(TFglCell(Targets[I]), Fr.Ret[I]);
      finally
        Fr.Free;
      end;
    end
    else
    begin
      if not CallFunction(Call, Call.Text, Args, Res) then Fail(N, 'Nepoznata funkcija ' + Call.Text);
      if Targets.Count > 0 then SetCell(TFglCell(Targets[0]), Res);
    end;
  finally
    Targets.Free;
  end;
end;

procedure TaFglRunner.ExecDisplay(N: TNode);
var
  S: string;
  I, J: Integer;
  Nd: TNode;
  C: TFglCell;
  Cells, Use: TList;
  Names, Vals: TStringList;
  Fields: TObjectList;
  Title: string;
begin
  if N.Kind = nkDisplayName then
  begin
    Cells := TList.Create;
    Names := TStringList.Create;
    Vals := TStringList.Create;
    try
      FlattenNodes(N.L2, Cells, Names);
      Use := TList.Create;
      Fields := BuildFields(N.Text2, Names, Cells, Use, N);
      try
        for I := 0 to Use.Count - 1 do Vals.Add(FglAsText(TFglCell(Use[I]).V));
        if N.Text2 <> '' then Title := FindScreen(N.Text2, N).Title else Title := '';
        if Title = '' then Title := 'Prikaz';
        FIO.InputFields(Title, Fields, Vals, '', True);
      finally
        Fields.Free;
        Use.Free;
      end;
    finally
      Cells.Free; Names.Free; Vals.Free;
    end;
    Exit;
  end;
  S := '';
  for I := 0 to N.L1.Count - 1 do
  begin
    Nd := TNode(N.L1[I]);
    if Nd.Kind = nkVar then
    begin
      C := ResolveVar(Nd, False);
      if C.Kind <> ckScalar then
      begin
        Cells := TList.Create;
        try
          Flatten(C, Cells);
          for J := 0 to Cells.Count - 1 do S := S + FglAsText(TFglCell(Cells[J]).V);
        finally
          Cells.Free;
        end;
        Continue;
      end;
    end;
    S := S + FglAsText(Eval(Nd));
  end;
  case N.Kind of
    nkMessage: FIO.Message(S);
    nkError: FIO.Error(S);
  else
    FIO.Display(S);
  end;
end;

procedure TaFglRunner.ExecPrompt(N: TNode);
var
  Cell: TFglCell;
  Txt, Val: string;
begin
  Txt := FglAsText(Eval(N.A));
  Cell := ResolveVar(N.B, True);
  Val := FglAsText(Cell.V);
  while True do
  begin
    if not FIO.Prompt(Txt, Val) then begin SetIntFlag(True); Exit; end;
    try
      if (Val = '') or ((Cell.Ty in [tyInt, tyFloat, tyDate, tyDateTime, tyBool]) and (Trim(Val) = '')) then
        Cell.V := Null
      else SetCell(Cell, Val);
      Break;
    except
      on E: Exception do FIO.Error(E.Message);
    end;
  end;
  SetIntFlag(False);
end;

procedure TaFglRunner.ExecConstruct(N: TNode);
var
  Cols, Vals: TStringList;
  I: Integer;
  Title: string;
begin
  Cols := TStringList.Create;
  Vals := TStringList.Create;
  try
    Cols.AddStrings(N.Names);
    for I := 0 to Cols.Count - 1 do Vals.Add('');
    if N.A <> nil then Title := FglAsText(Eval(N.A))
    else if (N.Text2 <> '') and (FindScreen(N.Text2, N).Title <> '') then Title := FindScreen(N.Text2, N).Title
    else Title := 'Pretraživanje';
    if FIO.Construct(Title, Cols, Vals) then
    begin
      SetCell(ResolveVar(N.B, True), FglConstructToSql(Cols, Vals));
      SetIntFlag(False);
    end
    else SetIntFlag(True);
  finally
    Cols.Free;
    Vals.Free;
  end;
end;

function TaFglRunner.FindScreen(const AName: string; AAt: TNode): TFglScreen;
var
  K: Integer;
begin
  K := FProg.Screens.IndexOf(LowerCase(AName));
  if K < 0 then Fail(AAt, 'Zaslon ' + AName + ' nije definiran (SCREEN)');
  Result := TFglScreen(FProg.Screens.Objects[K]);
end;

{ Polja za I/O: iz zaslona (redoslijed, oznake, LOOKUP) ili po nazivima ciljeva.
  AUse dobiva celije u istom redoslijedu kao polja. }
function TaFglRunner.BuildFields(const AScreen: string; ANames: TStrings; ACells: TList;
  AUse: TList; AAt: TNode): TObjectList;
var
  I, K: Integer;
  F: TaFglField;
  Scr: TFglScreen;
  SF: TFglScreenField;
  Q: TZQuery;
begin
  Result := TObjectList.Create(True);
  if AScreen = '' then
  begin
    for I := 0 to ANames.Count - 1 do
    begin
      F := TaFglField.Create;
      F.Name := ANames[I];
      F.Caption := ANames[I];
      Result.Add(F);
      AUse.Add(ACells[I]);
    end;
    Exit;
  end;
  Scr := FindScreen(AScreen, AAt);
  for I := 0 to Scr.Fields.Count - 1 do
  begin
    SF := TFglScreenField(Scr.Fields[I]);
    K := ANames.IndexOf(SF.Name);
    if K < 0 then
    begin
      FreeAndNil(Result);
      Fail(AAt, 'Zaslon ' + Scr.Name + ' ima polje ' + SF.Name + ' kojeg nema medju varijablama');
    end;
    F := TaFglField.Create;
    F.Name := SF.Name;
    F.Caption := SF.Caption;
    F.Hint := SF.Hint;
    F.ReadOnly := SF.ReadOnly;
    F.Required := SF.Required;
    F.Upshift := SF.Upshift;
    if SF.LookupTable <> '' then
    begin
      F.LookupKeys := TStringList.Create;
      F.LookupLabels := TStringList.Create;
      Q := FDb.NewQuery('SELECT ' + FDb.QuoteId(SF.LookupKey) + ', ' + FDb.QuoteId(SF.LookupLabel) +
        ' FROM ' + FDb.QuoteId(SF.LookupTable) + ' ORDER BY 2');
      try
        Q.Open;
        while not Q.EOF do
        begin
          F.LookupKeys.Add(Q.Fields[0].AsString);
          F.LookupLabels.Add(Q.Fields[1].AsString);
          Q.Next;
        end;
      finally
        Q.Free;
      end;
    end;
    Result.Add(F);
    AUse.Add(ACells[K]);
  end;
end;

function TaFglRunner.ExecInput(N: TNode): TFglFlow;
var
  Cells, Use: TList;
  Names, Vals: TStringList;
  Fields: TObjectList;
  I: Integer;
  Focus, Title, Txt: string;
  Cell: TFglCell;
  Fld: TaFglField;
  First, Redo: Boolean;
  R: TFglFlow;
  Scr: TFglScreen;

  function RunClauses(const AKind, AField: string): TFglFlow;
  var
    K: Integer;
    Cl: TNode;
  begin
    Result := flNone;
    if N.L1 = nil then Exit;
    for K := 0 to N.L1.Count - 1 do
    begin
      Cl := TNode(N.L1[K]);
      if (Cl.Text = AKind) and ((AField = '') or (Cl.Text2 = LowerCase(AField))) then
      begin
        Result := ExecList(Cl.L1);
        if Result <> flNone then Exit;
      end;
    end;
  end;

begin
  Result := flNone;
  Cells := TList.Create;
  Use := TList.Create;
  Names := TStringList.Create;
  Vals := TStringList.Create;
  Fields := nil;
  try
    FlattenNodes(N.L2, Cells, Names);
    Fields := BuildFields(N.Text2, Names, Cells, Use, N);
    Scr := nil;
    if N.A <> nil then Title := FglAsText(Eval(N.A))
    else
    begin
      Title := 'Unos';
      if N.Text2 <> '' then
      begin
        Scr := FindScreen(N.Text2, N);
        if Scr.Title <> '' then Title := Scr.Title;
      end;
    end;
    { zadane vrijednosti iz zaslona (DEFAULT), osim kod WITHOUT DEFAULTS }
    if (N.Text2 <> '') and not N.Flag then
    begin
      Scr := FindScreen(N.Text2, N);
      for I := 0 to Scr.Fields.Count - 1 do
        if (TFglScreenField(Scr.Fields[I]).Default <> nil) and IsNullV(TFglCell(Use[I]).V) then
          SetCell(TFglCell(Use[I]), Eval(TFglScreenField(Scr.Fields[I]).Default));
    end;
    First := True;
    Focus := '';
    while True do
    begin
      if First then
      begin
        R := RunClauses('BEFORE INPUT', '');
        if R <> flNone then Exit(R);
        for I := 0 to Fields.Count - 1 do
        begin
          R := RunClauses('BEFORE FIELD', TaFglField(Fields[I]).Name);
          if R <> flNone then Exit(R);
        end;
        First := False;
      end;
      Vals.Clear;
      for I := 0 to Use.Count - 1 do Vals.Add(FglAsText(TFglCell(Use[I]).V));
      if FNextField <> '' then begin Focus := FNextField; FNextField := ''; end;
      if not FIO.InputFields(Title, Fields, Vals, Focus, False) then
      begin
        SetIntFlag(True);
        Exit(flNone);
      end;
      Focus := '';
      Redo := False;
      for I := 0 to Use.Count - 1 do
      begin
        Cell := TFglCell(Use[I]);
        Fld := TaFglField(Fields[I]);
        if Fld.ReadOnly then Continue;
        Txt := Vals[I];
        try
          if (Txt = '') or ((Cell.Ty in [tyInt, tyFloat, tyDate, tyDateTime, tyBool]) and (Trim(Txt) = '')) then Cell.V := Null
          else
          begin
            if Fld.Upshift then Txt := UTF8UpperCase(Txt);
            SetCell(Cell, Txt);
          end;
          if Fld.Required and IsNullV(Cell.V) then
            raise Exception.Create(Tr('the field is required'));
        except
          on E: Exception do
          begin
            FIO.Error(Fld.Caption + ': ' + E.Message);
            Focus := Fld.Name;
            Redo := True;
            Break;
          end;
        end;
      end;
      if Redo then Continue;
      for I := 0 to Fields.Count - 1 do
      begin
        R := RunClauses('AFTER FIELD', TaFglField(Fields[I]).Name);
        if R <> flNone then Exit(R);
        if FNextField <> '' then Break;
      end;
      if FNextField <> '' then Continue;
      R := RunClauses('AFTER INPUT', '');
      if R <> flNone then Exit(R);
      if FNextField <> '' then Continue;
      Break;
    end;
    SetIntFlag(False);
  finally
    Fields.Free;
    Cells.Free;
    Use.Free;
    Names.Free;
    Vals.Free;
  end;
end;

{ DISPLAY ARRAY / INPUT ARRAY: mreza nad poljem zapisa (ili skalara). }
procedure TaFglRunner.ExecArray(N: TNode; AEdit: Boolean);
var
  Arr, Tmpl, Item: TFglCell;
  TmplCells, ItemCells, Use: TList;
  Names: TStringList;
  Fields: TObjectList;
  Rows: TObjectList;
  Row: TStringList;
  I, J, Cur, Cnt: Integer;
  Title, Base: string;
  Empty: Boolean;
  Scr: TFglScreen;
  Used: TList;

  function ItemEmpty(AItem: TFglCell): Boolean;
  var
    L: TList;
    K: Integer;
  begin
    L := TList.Create;
    try
      Flatten(AItem, L);
      Result := True;
      for K := 0 to L.Count - 1 do
        if not IsNullV(TFglCell(L[K]).V) then Exit(False);
    finally
      L.Free;
    end;
  end;

begin
  Arr := ResolveVar(N.A, True);
  if Arr.Kind <> ckArray then Fail(N, N.A.Text + ' nije polje (ARRAY)');
  Base := N.A.Text;
  Tmpl := NewCell(Arr.ElemType, N);
  TmplCells := TList.Create;
  Names := TStringList.Create;
  Use := TList.Create;
  Rows := TObjectList.Create(True);
  Fields := nil;
  try
    FlattenNamed(Tmpl, Base, TmplCells, Names);
    Fields := BuildFields(N.Text2, Names, TmplCells, Use, N);
    { mapiranje: za svaki stupac indeks u spljostenom retku }
    Used := TList.Create;
    try
      for J := 0 to Use.Count - 1 do Used.Add(Pointer(PtrInt(TmplCells.IndexOf(Use[J]))));
      for I := 0 to Arr.Items.Count - 1 do
      begin
        Item := TFglCell(Arr.Items[I]);
        if ItemEmpty(Item) then Continue;
        ItemCells := TList.Create;
        try
          Flatten(Item, ItemCells);
          Row := TStringList.Create;
          for J := 0 to Used.Count - 1 do Row.Add(FglAsText(TFglCell(ItemCells[PtrInt(Used[J])]).V));
          Rows.Add(Row);
        finally
          ItemCells.Free;
        end;
      end;
      if N.B <> nil then Title := FglAsText(Eval(N.B))
      else
      begin
        Title := Base;
        if N.Text2 <> '' then
        begin
          Scr := FindScreen(N.Text2, N);
          if Scr.Title <> '' then Title := Scr.Title;
        end;
      end;
      Cur := 0;
      if not FIO.Grid(Title, Fields, Rows, AEdit, Cur) then
      begin
        SetIntFlag(True);
        Exit;
      end;
      if AEdit then
      begin
        Cnt := 0;
        for I := 0 to Rows.Count - 1 do
        begin
          Row := TStringList(Rows[I]);
          Empty := True;
          for J := 0 to Row.Count - 1 do
            if Trim(Row[J]) <> '' then Empty := False;
          if not Empty then Inc(Cnt);
        end;
        if (Arr.Size > 0) and (Cnt > Arr.Size) then
        begin
          FIO.Error('Najvise ' + IntToStr(Arr.Size) + ' redaka');
          SetIntFlag(True);
          Exit;
        end;
        { prvo sve izprazni, pa upisi }
        for I := 0 to Arr.Items.Count - 1 do ExecInitializeCell(TFglCell(Arr.Items[I]));
        Cnt := 0;
        for I := 0 to Rows.Count - 1 do
        begin
          Row := TStringList(Rows[I]);
          Empty := True;
          for J := 0 to Row.Count - 1 do
            if Trim(Row[J]) <> '' then Empty := False;
          if Empty then Continue;
          Inc(Cnt);
          while Arr.Items.Count < Cnt do Arr.Items.Add(NewCell(Arr.ElemType, N));
          ItemCells := TList.Create;
          try
            Flatten(TFglCell(Arr.Items[Cnt - 1]), ItemCells);
            for J := 0 to Used.Count - 1 do
              if Trim(Row[J]) = '' then TFglCell(ItemCells[PtrInt(Used[J])]).V := Null
              else SetCell(TFglCell(ItemCells[PtrInt(Used[J])]), Row[J]);
          finally
            ItemCells.Free;
          end;
        end;
        if Arr.Size = 0 then
          while Arr.Items.Count > Cnt do Arr.Items.Delete(Arr.Items.Count - 1);
        Cur := Cnt;
      end
      else Cnt := Rows.Count;
    finally
      Used.Free;
    end;
    TFglCell(FGlobals.Vars.Objects[FGlobals.Vars.IndexOf('arr_count')]).V := Cnt;
    TFglCell(FGlobals.Vars.Objects[FGlobals.Vars.IndexOf('arr_curr')]).V := Cur;
    SetIntFlag(False);
  finally
    Fields.Free;
    Rows.Free;
    Use.Free;
    Names.Free;
    TmplCells.Free;
    Tmpl.Free;
  end;
end;

{ ---- SQL ---- }

function TaFglRunner.FieldValue(F: TField): Variant;
begin
  if F.IsNull then Exit(Null);
  case F.DataType of
    ftSmallint, ftInteger, ftLargeint, ftWord, ftAutoInc: Result := F.AsLargeInt;
    ftFloat, ftCurrency, ftBCD, ftFMTBcd: Result := F.AsFloat;
    ftBoolean: Result := F.AsBoolean;
    ftDate: Result := FormatDateTime('yyyy-mm-dd', F.AsDateTime);
    ftDateTime, ftTimeStamp: Result := FormatDateTime('yyyy-mm-dd hh:nn:ss', F.AsDateTime);
  else
    Result := F.AsString;
  end;
end;

procedure TaFglRunner.BindValue(P: TZParam; const V: Variant);
begin
  if IsNullV(V) then
  begin
    P.DataType := ftString;
    P.Clear;
  end
  else if IsBoolV(V) then P.AsBoolean := Boolean(V)
  else if IsIntV(V) then P.AsLargeInt := Int64(V)
  else if VarIsFloat(V) then P.AsFloat := Double(V)
  else P.AsString := VarToStr(V);
end;

function TaFglRunner.BindQuery(const ASql: string; AParams: TFPList; const AExtra: array of Variant;
  AAt: TNode): TZQuery;
var
  Vals: array of Variant;
  I, N0: Integer;
  Sql: string;
  P: TZParam;
begin
  N0 := 0;
  if AParams <> nil then N0 := AParams.Count;
  SetLength(Vals, N0 + Length(AExtra));
  for I := 0 to N0 - 1 do Vals[I] := Eval(TNode(AParams[I]));
  for I := 0 to High(AExtra) do Vals[N0 + I] := AExtra[I];
  Sql := ASql;
  if SqlPostgres or SqlMaria then Sql := PortableSql(Sql);
  Result := FDb.NewQuery(Sql);
  try
    for I := 0 to High(Vals) do
    begin
      P := Result.Params.FindParam('p' + IntToStr(I));
      if P = nil then Fail(AAt, 'SQL nema mjesta za parametar ' + IntToStr(I + 1));
      BindValue(P, Vals[I]);
    end;
  except
    Result.Free;
    raise;
  end;
end;

procedure TaFglRunner.AssignRow(Q: TZQuery; ATargets: TList; AAt: TNode);
var
  I: Integer;
begin
  if ATargets.Count <> Q.FieldCount then
    Fail(AAt, 'Broj ciljeva (' + IntToStr(ATargets.Count) + ') ne odgovara broju stupaca (' + IntToStr(Q.FieldCount) + ')');
  for I := 0 to ATargets.Count - 1 do SetCell(TFglCell(ATargets[I]), FieldValue(Q.Fields[I]));
end;

procedure TaFglRunner.ExecSql(N: TNode);
var
  Q: TZQuery;
  Targets: TList;
begin
  Q := BindQuery(N.Text, N.L1, [], N);
  try
    if N.Flag then
    begin
      if N.L2 = nil then Fail(N, 'SELECT mora imati INTO ili ide kroz kursor (DECLARE / FOREACH)');
      Targets := TList.Create;
      try
        FlattenNodes(N.L2, Targets, nil);
        Q.Open;
        if Q.EOF then SetSqlStatus(100, 0, 'NOTFOUND')
        else
        begin
          AssignRow(Q, Targets, N);
          SetSqlStatus(0, 1, '');
        end;
      finally
        Targets.Free;
      end;
    end
    else
    begin
      Q.ExecSQL;
      SetSqlStatus(0, Q.RowsAffected, '');
    end;
  finally
    Q.Free;
  end;
end;

procedure TaFglRunner.ExecTrans(N: TNode);
begin
  if N.Text = 'BEGIN' then FDb.Conn.StartTransaction
  else if N.Text = 'COMMIT' then FDb.Conn.Commit
  else FDb.Conn.Rollback;
  SetSqlStatus(0, -1, '');
end;

procedure TaFglRunner.ExecDeclare(N: TNode);
var
  C: TFglCursor;
  K: Integer;
begin
  K := FCursors.IndexOf(N.Text);
  if K >= 0 then FCursors.Delete(K);
  C := TFglCursor.Create;
  C.Name := N.Text;
  C.Decl := N.A;
  C.PreparedName := N.Text2;
  FCursors.AddObject(N.Text, C);
end;

function TaFglRunner.FindCursor(const AName: string; AAt: TNode): TFglCursor;
var
  K: Integer;
begin
  K := FCursors.IndexOf(AName);
  if K < 0 then Fail(AAt, 'Kursor ' + AName + ' nije deklariran (DECLARE)');
  Result := TFglCursor(FCursors.Objects[K]);
end;

procedure TaFglRunner.OpenCursor(C: TFglCursor; const AExtra: array of Variant; AAt: TNode);
var
  K: Integer;
begin
  FreeAndNil(C.Q);
  C.Open := False;
  if C.Decl <> nil then C.Q := BindQuery(C.Decl.Text, C.Decl.L1, AExtra, AAt)
  else
  begin
    K := FPrepared.IndexOf(C.PreparedName);
    if K < 0 then Fail(AAt, 'Nije pripremljeno (PREPARE): ' + C.PreparedName);
    C.Q := BindQuery(FPreparedSql[K], nil, AExtra, AAt);
  end;
  C.Q.Open;
  C.Open := True;
end;

function TaFglRunner.EvalListToArray(L: TFPList): TVariantArray;
var
  I: Integer;
begin
  SetLength(Result, 0);
  if L = nil then Exit;
  SetLength(Result, L.Count);
  for I := 0 to L.Count - 1 do Result[I] := Eval(TNode(L[I]));
end;

procedure TaFglRunner.ExecPrepare(N: TNode);
var
  S, Out: string;
  I, P: Integer;
  InQ: Char;
  K: Integer;
begin
  S := FglAsText(Eval(N.A));
  Out := '';
  P := 0;
  InQ := #0;
  for I := 1 to Length(S) do
  begin
    if InQ <> #0 then
    begin
      if S[I] = InQ then InQ := #0;
      Out := Out + S[I];
    end
    else if S[I] in ['''', '"'] then begin InQ := S[I]; Out := Out + S[I]; end
    else if S[I] = '?' then begin Out := Out + ':p' + IntToStr(P); Inc(P); end
    else Out := Out + S[I];
  end;
  K := FPrepared.IndexOf(N.Text);
  if K >= 0 then FPreparedSql[K] := Out
  else
  begin
    FPrepared.Add(N.Text);
    FPreparedSql.Add(Out);
  end;
  SetSqlStatus(0, 0, '');
end;

procedure TaFglRunner.ExecExecute(N: TNode);
var
  K: Integer;
  Q: TZQuery;
begin
  K := FPrepared.IndexOf(N.Text);
  if K < 0 then Fail(N, 'Nije pripremljeno (PREPARE): ' + N.Text);
  Q := BindQuery(FPreparedSql[K], nil, EvalListToArray(N.L1), N);
  try
    Q.ExecSQL;
    SetSqlStatus(0, Q.RowsAffected, '');
  finally
    Q.Free;
  end;
end;

procedure TaFglRunner.ExecOpen(N: TNode);
begin
  OpenCursor(FindCursor(N.Text, N), EvalListToArray(N.L1), N);
  SetSqlStatus(0, 0, '');
end;

procedure TaFglRunner.ExecFetch(N: TNode);
var
  C: TFglCursor;
  Targets: TList;
begin
  C := FindCursor(N.Text, N);
  if not C.Open then Fail(N, 'Kursor ' + N.Text + ' nije otvoren (OPEN)');
  if C.Q.EOF then begin SetSqlStatus(100, 0, 'NOTFOUND'); Exit; end;
  Targets := TList.Create;
  try
    FlattenNodes(N.L2, Targets, nil);
    AssignRow(C.Q, Targets, N);
  finally
    Targets.Free;
  end;
  C.Q.Next;
  SetSqlStatus(0, 1, '');
end;

procedure TaFglRunner.ExecClose(N: TNode; AFree: Boolean);
var
  K: Integer;
begin
  K := FCursors.IndexOf(N.Text);
  if K >= 0 then
  begin
    if AFree then FCursors.Delete(K)
    else
    begin
      FreeAndNil(TFglCursor(FCursors.Objects[K]).Q);
      TFglCursor(FCursors.Objects[K]).Open := False;
    end;
    Exit;
  end;
  K := FPrepared.IndexOf(N.Text);
  if AFree and (K >= 0) then
  begin
    FPrepared.Delete(K);
    FPreparedSql.Delete(K);
  end
  else Fail(N, 'Nema kursora ni pripremljene naredbe ' + N.Text);
end;

function TaFglRunner.ExecForeach(N: TNode): TFglFlow;
var
  C: TFglCursor;
  Targets: TList;
  R: TFglFlow;
begin
  Result := flNone;
  C := FindCursor(N.Text, N);
  if N.L2 = nil then Fail(N, 'FOREACH ocekuje INTO');
  OpenCursor(C, EvalListToArray(N.L3), N);
  Targets := TList.Create;
  try
    FlattenNodes(N.L2, Targets, nil);
    while (C.Q <> nil) and not C.Q.EOF do
    begin
      AssignRow(C.Q, Targets, N);
      C.Q.Next;
      R := ExecList(N.L1);
      if R = flExit then
      begin
        if FFlowKind = 'FOREACH' then Break else begin Result := R; Break; end;
      end
      else if R = flContinue then
      begin
        if FFlowKind <> 'FOREACH' then begin Result := R; Break; end;
      end
      else if R <> flNone then begin Result := R; Break; end;
    end;
  finally
    Targets.Free;
    FreeAndNil(C.Q);
    C.Open := False;
  end;
end;

{ ================= izvješća ================= }

type
  TSortItem = class
  public
    Idx: Integer;
    Keys: TVariantArray;
  end;

var
  GSortDesc: TList = nil;

function SortCompare(A, B: Pointer): Integer;
var
  X, Y: TSortItem;
  I, C: Integer;
begin
  X := TSortItem(A);
  Y := TSortItem(B);
  for I := 0 to High(X.Keys) do
  begin
    if IsNullV(X.Keys[I]) and IsNullV(Y.Keys[I]) then C := 0
    else if IsNullV(X.Keys[I]) then C := -1
    else if IsNullV(Y.Keys[I]) then C := 1
    else C := CompareV(X.Keys[I], Y.Keys[I]);
    if C = -2 then C := 0;
    if (GSortDesc <> nil) and (I < GSortDesc.Count) and (GSortDesc[I] <> nil) then C := -C;
    if C <> 0 then Exit(C);
  end;
  Result := X.Idx - Y.Idx;
end;

function TaFglRunner.AggValue(N: TNode): Variant;
var
  Lev: Integer;
  A: TFglAcc;
begin
  if FRun = nil then Fail(N, 'Zbrojevi (SUM, COUNT...) vrijede samo unutar REPORT bloka');
  if N.Flag then Lev := FRun.Level else Lev := 0;
  if Lev > High(FRun.Acc[N.Idx]) then Lev := High(FRun.Acc[N.Idx]);
  A := FRun.Acc[N.Idx][Lev];
  if N.Text = 'COUNT' then Result := Int64(A.Count)
  else if N.Text = 'SUM' then Result := A.Sum
  else if N.Text = 'AVG' then
  begin
    if A.Count = 0 then Result := Null else Result := A.Sum / A.Count;
  end
  else if N.Text = 'MIN' then Result := A.Min
  else if N.Text = 'PERCENT' then
  begin
    if FRun.TotalRows = 0 then Result := Null else Result := 100.0 * A.Count / FRun.TotalRows;
  end
  else Result := A.Max;
end;

function TaFglRunner.ReportCapacity(R: TFglReportRun): Integer;
begin
  Result := R.Rep.PageLength - R.TrailerLines - R.Rep.BottomMargin;
end;

procedure TaFglRunner.ReportNewPage(R: TFglReportRun);
var
  X: Integer;
begin
  R.CurLines := TStringList.Create;
  R.Pages.Add(R.CurLines);
  for X := 1 to R.Rep.TopMargin do R.CurLines.Add('');
end;

procedure TaFglRunner.ReportText(const S: string);
begin
  FRun.CurText := FRun.CurText + S;
end;

procedure TaFglRunner.ReportColumn(ACol: Integer);
var
  Cur: Integer;
begin
  Cur := UTF8Length(FRun.CurText);
  if Cur < ACol - 1 then FRun.CurText := FRun.CurText + StringOfChar(' ', ACol - 1 - Cur);
end;

procedure TaFglRunner.ReportNewline;
begin
  FRun.CurLines.Add(StringOfChar(' ', FRun.Rep.LeftMargin) + FRun.CurText);
  FRun.CurText := '';
  if (not FRun.InBreak) and (FRun.CurLines.Count >= ReportCapacity(FRun)) then ReportPageBreak;
end;

procedure TaFglRunner.ReportBlock(L: TFPList; ALevel: Integer);
var
  Old: Integer;
begin
  if L = nil then Exit;
  Old := FRun.Level;
  FRun.Level := ALevel;
  try
    ExecList(L);
  finally
    FRun.Level := Old;
  end;
end;

procedure TaFglRunner.ReportStartPage;
var
  Rep: TFglReport;
begin
  Rep := FRun.Rep;
  if (FRun.PageNo = 1) and (Rep.FirstHeader <> nil) then ReportBlock(Rep.FirstHeader, FRun.Level)
  else ReportBlock(Rep.PageHeader, FRun.Level);
end;

procedure TaFglRunner.ReportPageBreak;
var
  R: TFglReportRun;
begin
  R := FRun;
  R.InBreak := True;
  try
    if R.CurText <> '' then
    begin
      R.CurLines.Add(StringOfChar(' ', R.Rep.LeftMargin) + R.CurText);
      R.CurText := '';
    end;
    while R.CurLines.Count < ReportCapacity(R) do R.CurLines.Add('');
    ReportBlock(R.Rep.PageTrailer, R.Level);
    ReportNewPage(R);
    Inc(R.PageNo);
    ReportStartPage;
  finally
    R.InBreak := False;
  end;
end;

procedure TaFglRunner.ExecPrint(N: TNode);
var
  I, K: Integer;
  It: TNode;
  Fl: TStringList;
  Nm: string;
begin
  if FRun = nil then Fail(N, 'PRINT je dopusten samo unutar REPORT bloka');
  for I := 0 to N.L1.Count - 1 do
  begin
    It := TNode(N.L1[I]);
    if It.Kind = nkColumn then
    begin
      if It.Text = 'SPACES' then ReportText(StringOfChar(' ', Round(ToNum(Eval(It.A), ''))))
      else if It.Text = 'FILE' then
      begin
        Fl := TStringList.Create;
        try
          Nm := FglAsText(Eval(It.A));
          if not FileExists(Nm) then Fail(N, 'PRINT FILE: nema datoteke ' + Nm);
          Fl.LoadFromFile(Nm);
          for K := 0 to Fl.Count - 1 do
          begin
            ReportText(Fl[K]);
            ReportNewline;
          end;
        finally
          Fl.Free;
        end;
      end
      else ReportColumn(Round(ToNum(Eval(It.A), '')));
    end
    else ReportText(FglAsText(Eval(It)));
  end;
  if not N.Flag then ReportNewline;
end;

procedure TaFglRunner.ExecSkip(N: TNode);
var
  I, K: Integer;
begin
  if FRun = nil then Fail(N, 'SKIP je dopusten samo unutar REPORT bloka');
  if N.Text = 'TOP' then
  begin
    if (FRun.CurLines.Count > 0) or (FRun.CurText <> '') then ReportPageBreak;
    Exit;
  end;
  K := Round(ToNum(Eval(N.A), ''));
  for I := 1 to K do ReportNewline;
end;

procedure TaFglRunner.ExecNeed(N: TNode);
var
  Left: Integer;
begin
  if FRun = nil then Fail(N, 'NEED je dopusten samo unutar REPORT bloka');
  Left := ReportCapacity(FRun) - FRun.CurLines.Count;
  if Left < Round(ToNum(Eval(N.A), '')) then ReportPageBreak;
end;

procedure TaFglRunner.ExecStartReport(N: TNode);
var
  K, J: Integer;
  R: TFglReportRun;
begin
  K := FProg.Reports.IndexOf(N.Text);
  if K < 0 then Fail(N, 'Izvješće ' + N.Text + ' nije definirano (REPORT)');
  if FReports.IndexOf(N.Text) >= 0 then Fail(N, 'Izvješće ' + N.Text + ' je već pokrenuto (FINISH REPORT ga zatvara)');
  R := TFglReportRun.Create;
  R.Rep := TFglReport(FProg.Reports.Objects[K]);
  R.Kind := N.Text2;
  if N.A <> nil then R.Path := FglAsText(Eval(N.A));
  { redak po redak (bez držanja u memoriji) kad nema sortiranja i nema PERCENT }
  R.Stream := (R.Rep.Keys.Count = 0) or R.Rep.External;
  for J := 0 to R.Rep.Aggs.Count - 1 do
    if TNode(R.Rep.Aggs[J]).Text = 'PERCENT' then R.Stream := False;
  FReports.AddObject(N.Text, R);
end;

procedure TaFglRunner.ExecOutputReport(N: TNode);
var
  K, I, J, Base: Integer;
  R: TFglReportRun;
  Nd: TNode;
  C: TFglCell;
  L: TList;
  Row: TVariantArray;
begin
  K := FReports.IndexOf(N.Text);
  if K < 0 then Fail(N, 'OUTPUT TO REPORT bez START REPORT ' + N.Text);
  R := TFglReportRun(FReports.Objects[K]);
  SetLength(Row, 0);
  for I := 0 to N.L1.Count - 1 do
  begin
    Nd := TNode(N.L1[I]);
    if Nd.Kind = nkVar then
    begin
      C := ResolveVar(Nd, False);
      if C.Kind <> ckScalar then
      begin
        L := TList.Create;
        try
          Flatten(C, L);
          Base := Length(Row);
          SetLength(Row, Base + L.Count);
          for J := 0 to L.Count - 1 do Row[Base + J] := TFglCell(L[J]).V;
        finally
          L.Free;
        end;
        Continue;
      end;
    end;
    SetLength(Row, Length(Row) + 1);
    Row[High(Row)] := Eval(Nd);
  end;
  if R.Stream then ReportFeed(R, Row, N)
  else
  begin
    if R.RowCount >= Length(R.Rows) then SetLength(R.Rows, Length(R.Rows) * 2 + 64);
    R.Rows[R.RowCount] := Row;
    Inc(R.RowCount);
  end;
end;

procedure TaFglRunner.LoadRowCells(R: TFglReportRun; const Row: TVariantArray; AAt: TNode);
var
  X: Integer;
begin
  if Length(Row) <> R.Cells.Count then
    Fail(AAt, 'Izvješće ' + R.Rep.Name + ' ima ' + IntToStr(R.Cells.Count) + ' vrijednosti po retku, a OUTPUT TO REPORT šalje ' + IntToStr(Length(Row)));
  for X := 0 to R.Cells.Count - 1 do SetCell(TFglCell(R.Cells[X]), Row[X]);
end;

function TaFglRunner.ReportKeys(R: TFglReportRun): TVariantArray;
var
  X: Integer;
begin
  SetLength(Result, R.Rep.Keys.Count);
  for X := 0 to High(Result) do Result[X] := Eval(TNode(R.Rep.Keys[X]));
end;

procedure TaFglRunner.GroupBlocks(R: TFglReportRun; AKey: Integer; ABefore: Boolean);
var
  X: Integer;
  G: TFglGroupBlock;
begin
  for X := 0 to R.Rep.Groups.Count - 1 do
  begin
    G := TFglGroupBlock(R.Rep.Groups[X]);
    if (G.KeyIdx = AKey) and (G.Before = ABefore) then ReportBlock(G.Body, AKey + 1);
  end;
end;

procedure TaFglRunner.ReportPrepare(R: TFglReportRun; AAt: TNode);
var
  Rep: TFglReport;
  C: TFglCell;
  I, J, Keys: Integer;
  AN: TNode;
begin
  Rep := R.Rep;
  Keys := Rep.Keys.Count;
  R.Frame := TFglFrame.Create;
  for I := 0 to Rep.Params.Count - 1 do
  begin
    C := TFglCell.Create(ckScalar);
    R.Frame.Vars.AddObject(LowerCase(Rep.Params[I]), C);
  end;
  FFrames.Add(R.Frame);
  try
    ExecList(Rep.Defines);
    R.Cells.Clear;
    for I := 0 to Rep.Params.Count - 1 do
      Flatten(TFglCell(R.Frame.Vars.Objects[R.Frame.Vars.IndexOf(LowerCase(Rep.Params[I]))]), R.Cells);
  finally
    FFrames.Delete(FFrames.Count - 1);
  end;
  SetLength(R.Acc, Rep.Aggs.Count);
  for I := 0 to High(R.Acc) do
  begin
    SetLength(R.Acc[I], Keys + 1);
    for J := 0 to Keys do
    begin
      R.Acc[I][J].Count := 0; R.Acc[I][J].Sum := 0; R.Acc[I][J].Min := Null; R.Acc[I][J].Max := Null;
    end;
  end;
  R.TrailerLines := 0;
  if Rep.PageTrailer <> nil then
    for I := 0 to Rep.PageTrailer.Count - 1 do
    begin
      AN := TNode(Rep.PageTrailer[I]);
      if (AN.Kind = nkPrint) and not AN.Flag then Inc(R.TrailerLines)
      else if (AN.Kind = nkSkip) and (AN.A <> nil) and (AN.A.Kind = nkLit) then Inc(R.TrailerLines, Round(ToNum(AN.A.V, '')));
    end;
  ReportNewPage(R);
  R.PageNo := 1;
  R.Level := Keys;
  R.Prepared := True;
end;

procedure TaFglRunner.ReportFeed(R: TFglReportRun; const Row: TVariantArray; AAt: TNode);
var
  Rep: TFglReport;
  Old: TFglReportRun;
  CurKeys: TVariantArray;
  Changed, K, J, Lv, Lev, Keys: Integer;
  AN: TNode;
  V: Variant;
begin
  if not R.Prepared then ReportPrepare(R, AAt);
  Rep := R.Rep;
  Keys := Rep.Keys.Count;
  Old := FRun;
  FFrames.Add(R.Frame);
  FRun := R;
  try
    LoadRowCells(R, Row, AAt);
    if not R.PageStarted then
    begin
      R.InBreak := True;
      ReportStartPage;
      R.InBreak := False;
      R.PageStarted := True;
    end;
    CurKeys := ReportKeys(R);
    if not R.HasPrev then Changed := 0
    else
    begin
      Changed := -1;
      for K := 0 to Keys - 1 do
      begin
        if IsNullV(CurKeys[K]) and IsNullV(R.PrevKeys[K]) then Continue;
        if IsNullV(CurKeys[K]) or IsNullV(R.PrevKeys[K]) or (CompareV(CurKeys[K], R.PrevKeys[K]) <> 0) then
        begin
          Changed := K;
          Break;
        end;
      end;
      if Changed >= 0 then
      begin
        LoadRowCells(R, R.PrevRow, AAt);
        for Lev := Keys - 1 downto Changed do GroupBlocks(R, Lev, False);
        LoadRowCells(R, Row, AAt);
      end;
    end;
    if Changed >= 0 then
    begin
      for J := 0 to High(R.Acc) do
        for Lv := Changed + 1 to Keys do
        begin
          R.Acc[J][Lv].Count := 0; R.Acc[J][Lv].Sum := 0; R.Acc[J][Lv].Min := Null; R.Acc[J][Lv].Max := Null;
        end;
      for Lev := Changed to Keys - 1 do GroupBlocks(R, Lev, True);
    end;
    { zbrojevi uključuju tekući redak }
    for J := 0 to High(R.Acc) do
    begin
      AN := TNode(Rep.Aggs[J]);
      if AN.A = nil then V := Int64(1)
      else
      begin
        V := Eval(AN.A);
        if IsNullV(V) then Continue;
      end;
      for Lv := 0 to Keys do
      begin
        Inc(R.Acc[J][Lv].Count);
        if (AN.Text = 'SUM') or (AN.Text = 'AVG') then R.Acc[J][Lv].Sum := R.Acc[J][Lv].Sum + ToNum(V, '');
        if (AN.Text = 'MIN') and (IsNullV(R.Acc[J][Lv].Min) or (CompareV(V, R.Acc[J][Lv].Min) < 0)) then R.Acc[J][Lv].Min := V;
        if (AN.Text = 'MAX') and (IsNullV(R.Acc[J][Lv].Max) or (CompareV(V, R.Acc[J][Lv].Max) > 0)) then R.Acc[J][Lv].Max := V;
      end;
    end;
    ReportBlock(Rep.OnEveryRow, Keys);
    R.PrevKeys := Copy(CurKeys, 0, Keys);
    R.PrevRow := Row;
    R.HasPrev := True;
  finally
    FFrames.Delete(FFrames.Count - 1);
    FRun := Old;
  end;
end;

procedure TaFglRunner.ReportEnd(R: TFglReportRun);
var
  Rep: TFglReport;
  Old: TFglReportRun;
  Lev, Keys: Integer;
begin
  if (not R.Prepared) or (not R.HasPrev) then Exit;
  Rep := R.Rep;
  Keys := Rep.Keys.Count;
  Old := FRun;
  FFrames.Add(R.Frame);
  FRun := R;
  try
    LoadRowCells(R, R.PrevRow, nil);
    for Lev := Keys - 1 downto 0 do GroupBlocks(R, Lev, False);
    ReportBlock(Rep.OnLastRow, 0);
    { zadnja stranica: ostatak retka, popuna do podnožja, podnožje }
    R.InBreak := True;
    if R.CurText <> '' then
    begin
      R.CurLines.Add(StringOfChar(' ', Rep.LeftMargin) + R.CurText);
      R.CurText := '';
    end;
    if Rep.PageTrailer <> nil then
    begin
      while R.CurLines.Count < ReportCapacity(R) do R.CurLines.Add('');
      ReportBlock(Rep.PageTrailer, 0);
    end;
  finally
    FFrames.Delete(FFrames.Count - 1);
    FRun := Old;
  end;
end;

function PipeText(const ACmd, AText: string; out AErr: string): Boolean;
var
  P: TProcess;
  InF, OutF: string;
  L: TStringList;
begin
  Result := False;
  AErr := '';
  { tekst ide kroz privremenu datoteku: stdin cijevi se ne zatvara pouzdano }
  InF := GetTempFileName('', 'tafgl');
  OutF := InF + '.out';
  L := TStringList.Create;
  try
    L.Text := AText;
    L.SaveToFile(InF);
  finally
    L.Free;
  end;
  P := TProcess.Create(nil);
  try
    P.Executable := '/bin/sh';
    P.Parameters.Add('-c');
    P.Parameters.Add('(' + ACmd + ') < "' + InF + '" > "' + OutF + '" 2>&1');
    P.Options := [poWaitOnExit];
    try
      P.Execute;
    except
      on E: Exception do begin AErr := E.Message; Exit; end;
    end;
    Result := P.ExitStatus = 0;
    if not Result then
    begin
      AErr := 'naredba je vratila ' + IntToStr(P.ExitStatus);
      if FileExists(OutF) then
      begin
        L := TStringList.Create;
        try
          L.LoadFromFile(OutF);
          if Trim(L.Text) <> '' then AErr := AErr + ': ' + Trim(L.Text);
        finally
          L.Free;
        end;
      end;
    end;
  finally
    P.Free;
    DeleteFile(InF);
    DeleteFile(OutF);
  end;
end;

procedure TaFglRunner.ExecFinishReport(N: TNode);
var
  K, I, J, Keys: Integer;
  R: TFglReportRun;
  L: TStringList;
  Err, Txt: string;
  Sorted: TObjectList;
  Si: TSortItem;
  Old: TFglReportRun;
begin
  K := FReports.IndexOf(N.Text);
  if K < 0 then Fail(N, 'FINISH REPORT bez START REPORT ' + N.Text);
  R := TFglReportRun(FReports.Objects[K]);
  Sorted := nil;
  try
    if (not R.Stream) and (R.RowCount > 0) then
    begin
      Keys := R.Rep.Keys.Count;
      R.TotalRows := R.RowCount;
      ReportPrepare(R, N);
      if (Keys > 0) and not R.Rep.External then
      begin
        Sorted := TObjectList.Create(True);
        Old := FRun;
        FFrames.Add(R.Frame);
        FRun := R;
        try
          for I := 0 to R.RowCount - 1 do
          begin
            LoadRowCells(R, R.Rows[I], N);
            Si := TSortItem.Create;
            Si.Idx := I;
            Si.Keys := ReportKeys(R);
            Sorted.Add(Si);
          end;
        finally
          FFrames.Delete(FFrames.Count - 1);
          FRun := Old;
        end;
        GSortDesc := R.Rep.KeyDesc;
        try
          TList(Sorted).Sort(@SortCompare);
        finally
          GSortDesc := nil;
        end;
        for I := 0 to Sorted.Count - 1 do ReportFeed(R, R.Rows[TSortItem(Sorted[I]).Idx], N);
      end
      else
        for I := 0 to R.RowCount - 1 do ReportFeed(R, R.Rows[I], N);
    end;
    ReportEnd(R);
    if R.Pages.Count = 0 then Exit;
    if (R.Kind = 'FILE') or (R.Kind = 'PIPE') then
    begin
      L := TStringList.Create;
      try
        for I := 0 to R.Pages.Count - 1 do
        begin
          if I > 0 then L.Add(#12);
          L.AddStrings(TStringList(R.Pages[I]));
        end;
        if R.Kind = 'FILE' then L.SaveToFile(R.Path)
        else
        begin
          Txt := L.Text;
          if not PipeText(R.Path, Txt, Err) then Fail(N, 'PIPE "' + R.Path + '": ' + Err);
        end;
      finally
        L.Free;
      end;
    end
    else if R.Kind = 'PDF' then
    begin
      if not Assigned(FglPdfHook) then Fail(N, 'PDF izvoz nije dostupan u ovom načinu rada');
      if not FglPdfHook(R.Pages, R.Path, Err) then Fail(N, 'PDF: ' + Err);
    end
    else if R.Kind = 'PRINTER' then
    begin
      if not Assigned(FglPrintHook) then Fail(N, 'Ispis na pisač nije dostupan u ovom načinu rada');
      if not FglPrintHook(R.Pages, R.Path, Err) then Fail(N, 'Pisač: ' + Err);
    end
    else FIO.ShowReport(R.Rep.Name, R.Pages);
  finally
    Sorted.Free;
    J := FReports.IndexOf(N.Text);
    if J >= 0 then FReports.Delete(J);
  end;
end;

function TaFglRunner.Run: Integer;
var
  Fr: TFglFrame;
begin
  Result := 0;
  try
    try
      ExecList(FProg.GlobalStmts);
      if FProg.Main = nil then raise EFglError.Create('Program nema MAIN');
      Fr := TFglFrame.Create;
      FFrames.Add(Fr);
      try
        if not FExiting then ExecList(FProg.Main.Body);
      finally
        FFrames.Delete(FFrames.Count - 1);
        Fr.Free;
      end;
    except
      on E: Exception do
      begin
        FIO.Error(E.Message);
        Result := 1;
      end;
    end;
  finally
    FIO.Finish;
  end;
  if (Result = 0) and FExiting then Result := FExitCode;
end;

function TaFglRunner.CallFunc(const AName: string; const AArgs: array of Variant; out ARet: TVariantArray;
  out AErr: string): Boolean;
var
  K, I: Integer;
  F: TFglFunc;
  Fr: TFglFrame;
begin
  Result := False;
  AErr := '';
  SetLength(ARet, 0);
  if FTimeLimitMs > 0 then FDeadlineAt := Int64(GetTickCount64) + FTimeLimitMs else FDeadlineAt := 0;
  try
    try
      ExecList(FProg.GlobalStmts);
      if AName = '' then
      begin
        if FProg.Main = nil then raise EFglError.Create('Program nema MAIN');
        Fr := TFglFrame.Create;
        FFrames.Add(Fr);
        try
          ExecList(FProg.Main.Body);
        finally
          FFrames.Delete(FFrames.Count - 1);
          Fr.Free;
        end;
      end
      else
      begin
        K := FProg.Funcs.IndexOf(LowerCase(AName));
        if K < 0 then raise EFglError.Create('Program nema funkciju ' + AName);
        F := TFglFunc(FProg.Funcs.Objects[K]);
        Fr := CallUser(F, AArgs, nil);
        try
          SetLength(ARet, Length(Fr.Ret));
          for I := 0 to High(Fr.Ret) do ARet[I] := Fr.Ret[I];
        finally
          Fr.Free;
        end;
      end;
      Result := True;
    except
      on E: Exception do AErr := E.Message;
    end;
  finally
    FDeadlineAt := 0;
  end;
end;

function FglCheckFile(const AFile: string; ALog: TStrings): Integer;
var
  P: TaFglProgram;
begin
  Result := 0;
  P := TaFglProgram.Create;
  try
    try
      P.LoadFile(AFile);
      Result := P.CheckProgram(ALog);
    except
      on E: Exception do
      begin
        ALog.Add(E.Message);
        Result := 1;
      end;
    end;
  finally
    P.Free;
  end;
end;

end.
