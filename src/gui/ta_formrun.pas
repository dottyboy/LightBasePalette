unit ta_formrun;
{ Form runtime: builds a live form from a TaFormDef and binds the controls to
  a record source. Handles calculated controls (=expressions), visibility and
  enabled conditions, validation rules, filter/order/search, lookups, tabs,
  subforms (datasheet or another saved form), charts, images and hyperlinks.
  The navigation bar at the bottom works like Access. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, contnrs, Variants, Forms, Controls, StdCtrls, ExtCtrls, ComCtrls, Dialogs,
  DB, DBGrids, Grids, Menus, ZDataset, Calendar, LCLIntf, Graphics, ta_meta, ta_formdef, ta_controls,
  ta_types, ta_expr, ta_exprdb, ta_parse, ta_script, ta_app, ta_qbe, ta_wizardgen, ta_auditdlg, ta_gridtools, ta_filterdlg, ta_lovdlg, ta_condfmt, ta_datatools, ta_importexport, ta_filestore, ta_richedit, ta_richbase, ta_icons, ta_sidemenu, ta_doctypes, ta_source, ta_contform, ta_rowsource, ta_bindengine, ta_keymap, ta_propclass, ta_family, ta_famctl, ta_gridview, ta_owngrid, ta_dict, ta_i18n, ta_autoenter, ta_mask, ta_savedfinds, ta_formboard, ta_formdash, ta_formtimeline, ta_esphome;

type
  TaFormRunner = class;

  { TaSubInfo: one embedded subform. Either a datasheet filtered by the master
    record, or another saved form running inside the panel. }

  { copies values from the row a foreign key points at, when that field changes }
  TaAutoFill = class
  public
    Db: TAppDb;
    Query: TZQuery;
    Def: TaAutoFillDef;
    Busy: Boolean;
    procedure Changed(Sender: TField);
  end;

  { host izraza nad trenutnim retkom upita (pravila izracuna u mrezi i podformi) }
  TaCalcHost = class(TaExprHost)
  public
    Query: TZQuery;
    function FieldValue(const AName: string): Variant; override;
    function Aggregate(const AFunc, AField: string): Variant; override;
    function Variable(const AName: string): Variant; override;
  end;

  TaCalcRule = class
  public
    Triggers: TStringList;       { mala slova }
    Target, Expr: string;
    constructor Create;
    destructor Destroy; override;
  end;

  TaCalcSet = class;

  { po jedno polje-okidac: poziva prethodni OnChange (npr. AutoFill), pa pravila }
  TaCalcHook = class
  public
    Owner: TaCalcSet;
    Prev: TFieldNotifyEvent;
    procedure Changed(Sender: TField);
  end;

  { pravila izracuna: "cijena,kolicina -> iznos = Zaokruzi([cijena]*[kolicina], 2) ;; iznos -> cijena = ..." }
  TaCalcSet = class
  public
    Query: TZQuery;
    Host: TaCalcHost;
    Rules, Hooks: TObjectList;
    Busy: Boolean;
    constructor Create;
    destructor Destroy; override;
  end;

  { potkartica u tablici (Access): jedan otvoreni redak roditelja }
  TaSubSheet = class
  public
    Query: TZQuery;
    Source: TDataSource;
    View: TaGridView;
    Formatter: TaDatasetFormatter;
    Holder: TFPObjectList;
    LinkCol, Key: string;
    destructor Destroy; override;
    procedure NewRecord(DataSet: TDataSet);
  end;

  TaSubInfo = class
  public
    Holder: TFPObjectList;
    Panel: TaSubform;
    Grid: TDBGrid;
    View: TaGridView;
    Source: TDataSource;
    Query: TZQuery;
    Embedded: TaFormRunner;
    Formatter: TaDatasetFormatter;
    Toolbar: TPanel;
    HasCalc: Boolean;
    OnChanged: TNotifyEvent;
    Def: TaControlDef;
    MasterValue: string;
    destructor Destroy; override;
    procedure NewRecord(DataSet: TDataSet);
    procedure AddClick(Sender: TObject);
    procedure DelClick(Sender: TObject);
    procedure PostClick(Sender: TObject);
    procedure AfterPostRefresh(DataSet: TDataSet);
  end;

  { TaFormHost: lets expressions see the form's controls and fields. }

  TaFormHost = class(TaExprHost)
  public
    Runner: TaFormRunner;
    function FieldValue(const AName: string): Variant; override;
    function Aggregate(const AFunc, AField: string): Variant; override;
    function Variable(const AName: string): Variant; override;
    function Domain(const AFunc, AExpr, ADomain, ACriteria: string): Variant; override;
    function SubAggregate(const AFunc, ASub, AField: string): Variant; override;
  end;

  { stanje zapisa/forme (19.3 plana): spremljen, novi, promijenjen, upit }
  TaRecordState = (rsSaved, rsNew, rsChanged, rsQuery);

  { TaFormRunner }

  TaFormRunner = class(TForm)
  private
    FDb: TAppDb;
    FDef: TaFormDef;
    FQuery: TZQuery;
    FBound, FCalc, FAll, FCharts, FDisplay, FDynamic: TList;
    FCalcVals: array of Variant;
    FSubs: TFPObjectList;
    FMetas: TFPObjectList;
    FDirty, FLoading, FBuilding: Boolean;
    FPos: TLabel;
    FSearchEdit: TEdit;
    FSearch, FMasterField, FMasterValue: string;
    FColFilters: TStringList;          { Polje=filter, za mrezu }
    FGridRules: TCondRules;
    FRowHost: TaRowHost;
    FKindCache: TStringList;           { Polje=vrsta filtera, iz zadnjeg otvaranja upita }
    FSortField, FFilterErr: string;
    FSortDesc: Boolean;
    FFooter: TLabel;
    FFooterPn: TPanel;
    FFieldNames: TStringList;
    FHost: TaFormHost;
    FRuleColored: TList;          { kontrole obojane zbog prekrsenog pravila }
    FEngine: TaBindingEngine;     { zajednicki stroj ponasanja (uvjeti, stil, pravila) }
    FFormRules: TObjectList;     { CalcRules forme s jednim zapisom }
    FFormAutoFill: TStringList;  { AutoFill pravila forme s jednim zapisom (samo oznaka da ih ima) }
    FFormAutoDefs: TaAutoFillDefs;
    FRulesBusy: Boolean;
    FValidating: TControl;
    FContext: TaScriptContext;
    FInCurrent, FOpening: Boolean;
    FNavButtons: array[0..8] of TCustomButton;
    FQueryMode: Boolean;
    FPrevFilters: TStringList;
    FQueryBar: TPanel;          { upit po formi u tablici: po jedno polje za uzorak po stupcu }
    FQueryEdits: TStringList;   { Polje -> TEdit }
    FKeyMap: TaKeyMap;
    FGrid: TDBGrid;
    FView: TaGridView;
    FSubSheets: TStringList;
    FSubChild, FSubLink: string;
    FCont: TaContinuousBody;     { ViewMode = continuous }
    FBoard: TaBoardBody;         { ViewMode = board (kanban) }
    FDashBody: TaDashBody;       { ViewMode = dash (nadzorna ploca) }
    FTimeBody: TaTimelineBody;   { ViewMode = timeline (raspored) }
    FOnDataChanged: TNotifyEvent;
    FGridHolder: TFPObjectList;
    FGridSource: TDataSource;
    FFormatter: TaDatasetFormatter;
    procedure BuildGrid;
    procedure ApplyWindowFlags;
    procedure GridTitleClick(Sender: TObject; const AFieldName: string);
    procedure ConfigureSubDatasheet;
    procedure SubSheetOpen(Sender: TObject; const AKey: string; AChild: TaOwnGrid);
    procedure SubSheetClose(Sender: TObject; const AKey: string; AChild: TaOwnGrid);
    procedure DuplicateRecord;
    procedure ExportView(const AFile: string);
    procedure ExportClick(Sender: TObject);
    procedure GridRowStyle(Sender: TObject; ASelected: Boolean; var AFore, ABack: TColor; var ABold: Boolean);
    procedure ApplyCondFormat(C: TControl; D: TaControlDef);
    procedure ApplyRuleColor(C: TControl; D: TaControlDef);
    procedure FiltersClick(Sender: TObject);
    procedure BuildQueryBar;
    procedure ShowQueryBar(AShow: Boolean);
    procedure QueryBarKey(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure QueryClick(Sender: TObject);
    function LovValidate(C: TControl; const AValue: string): string;
    function FilterKindOf(const AField: string): TFilterKind;
    function ColumnFiltersSql: string;
    function FilterControlsSql: string;
    procedure ClearFilterControls;
    procedure BindParams(Q: TZQuery);
    procedure UpdateFooter;
    procedure UpdateSortMarks;
    procedure AttachGridExtras(AQuery: TZQuery; AView: TaGridView; const ATable, AHideField, AAutoFill, ACalc: string; AHolder: TFPObjectList; const ARules: string = '');
    procedure BuildControls;
    procedure SetupControl(C: TControl; D: TaControlDef);
    procedure BuildNav;
    procedure MarkDirty;
    procedure RunnerKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure BuildSub(APanel: TaSubform);
    procedure BuildContinuous;
    procedure BuildBoard;
    procedure ExportEspHome;
    procedure BuildDash;
    procedure BuildTimeline;
    procedure BoardOpen(Sender: TObject; const AId, AColumnField, AColumnKey: string);
    procedure ContDataChanged(Sender: TObject);
    procedure FillList(C: TControl);
    procedure RefreshCharts;
    procedure RefreshSubs;
    procedure SubChanged(Sender: TObject);
    procedure RefreshDynamic;
    procedure RecalcAll;
    procedure UpdateNav;
    procedure Scrolled(DataSet: TDataSet);
    procedure LoadRecord;
    procedure LoadDisplayOnly;
    function MetaFor(const AField: string): TaFieldMeta;
    function IsCalcName(const AName: string): Boolean;
    function FireControlEvent(C: TControl; const AKey: string): Boolean;
    procedure AttachControlEvents(C: TControl; D: TaControlDef);
    procedure ControlEnter(Sender: TObject);
    procedure ControlExit(Sender: TObject);
    procedure ControlKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure RefocusAsync(Data: PtrInt);
    function ErrorText(const AMessage: string; out ASilent: Boolean): string;
    procedure ApplyDefaults;
    procedure ApplyAutoPreview;
    procedure AddDictCopyRules;
    procedure SaveFind(const AName: string);
    procedure LoadFind(const AName: string);
    procedure ApplyAutoEnter(AInsert: Boolean);
    procedure OpenQuery;
    function BuildSql: string;
    function ExpandPlaceholders(const ASql: string): string;
    function FglParamEval(const AExpr: string; out AValue: Variant): Boolean;
    function OpenPrefixedSource(const ASource: string; out AErr: string): TDataSet;
    function ControlVariant(C: TControl): Variant;
    function FieldVariant(F: TField): Variant;
    function HasKeys(C: TControl): Boolean;
    function FindControl(const AName: string): TControl;
    procedure ControlChanged(Sender: TObject);
    procedure ApplyFormRules(C: TControl);
    procedure ButtonClick(Sender: TObject);
    procedure SideAction(const AAction: string);
    procedure HyperClick(Sender: TObject);
    procedure ImageDblClick(Sender: TObject);
    procedure ImageClearClick(Sender: TObject);
    procedure AttachImageMenu(Img: TControl);
    procedure PickImage(Img: TControl);
    procedure DateButtonClick(Sender: TObject);
    procedure LovButtonClick(Sender: TObject);
    procedure LovHostClick(Sender: TObject);
    procedure FillFamilyList(C: TControl);
    function GridLovFor(const AField: string; out ASource, AMap: string): Boolean;
    procedure NavClick(Sender: TObject);
    procedure SearchClick(Sender: TObject);
    procedure SearchKey(Sender: TObject; var Key: Char);
    procedure RunnerCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure LockControl(C: TControl);
    function FireEvent(const AKey: string): Boolean;
    procedure RunProcName(const AProc: string);
    procedure ControlDblClick(Sender: TObject);
    function ValueText(const AName: string): string;
    procedure ScriptSet(const AName, AValue: string);
    procedure EmbeddedClose(Sender: TObject; var CloseAction: TCloseAction);
  private
    FEmbedded: Boolean;
    FOnCloseRequest: TNotifyEvent;
    FDesignW, FDesignH: Integer;
    FDocCode: string;
    FAutoTx: Boolean;
    FRefocus: TControl;
    procedure ApplyDocNew;
    procedure CommitDocNumber;
  public
    { neprekidna forma: zbroj/broj/... redaka (SQL nad cijelim izvorom uz filtar i vezu); '' ako forma nije neprekidna }
    function ContAggregate(const AFunc, AField: string): string;
    function SubAggregateOf(const AFunc, ASub, AField: string): Variant;
    { ugradena forma podforme (nil ako je podforma mreza) }
    function SubRunner(const ASub: string): TaFormRunner;
    property ContinuousForm: TaContinuousBody read FCont;
    property BoardBody: TaBoardBody read FBoard;
    property DashBody: TaDashBody read FDashBody;
    property TimelineBody: TaTimelineBody read FTimeBody;
    procedure Navigate(const AId: string);
    procedure NewWith(const AField, AValue: string);
    { zapis neprekidne forme je spremljen ili obrisan }
    property OnDataChanged: TNotifyEvent read FOnDataChanged write FOnDataChanged;
    { forma u kartici radnog prostora: bez okvira prozora, ispunjava roditelja; zatvaranje javlja radnom prostoru }
    procedure Embed(AParent: TWinControl; AOnCloseRequest: TNotifyEvent);
    { otvaranje s parametrima ("vrsta=otp"): objedinjena forma dokumenta prikazuje samo tu vrstu, nove zapise oznacava vrstom i brojem }
    procedure OpenWith(const AArgs: string);
    property DocCode: string read FDocCode;
    property Embedded: Boolean read FEmbedded;
    { velicina u kartici: forma ispunjava prostor, ali nikad nije manja od dizajnirane (tada se pojavljuju klizne trake) }
    procedure FitTo(AWidth, AHeight: Integer);
    property Def: TaFormDef read FDef;
    constructor CreateRunner(AOwner: TComponent; ADb: TAppDb; ADef: TaFormDef);
    destructor Destroy; override;
    function SaveRecord: Boolean;
    procedure DoAction(const AAction: string);
    { upit po formi (19.4): polja se isprazne, upisuju se uzorci (Ma*, >100, 01.01.2026..31.01.2026, prazno), F8 izvrsava }
    procedure EnterQuery;
    function ExecuteQuery: Boolean;
    procedure CancelQuery;
    function RecordState: TaRecordState;
    function StateText: string;
    property QueryMode: Boolean read FQueryMode;
    function QueryEdit(const AField: string): TEdit;
    { popis vrijednosti (19.5): X lov = izvor, lovmap = polje_izvora=kontrola;..., lovvalidate = 1 }
    function ShowLov(C: TControl): Boolean;
    { LOV po celiji tablice: polje s popisom u GridLov; True = obradjeno }
    function ShowGridLov: Boolean;
    property KeyMap: TaKeyMap read FKeyMap write FKeyMap;
    function ControlByName(const AName: string): TControl;
    procedure SetColumnFilter(const AField, AText: string);
    procedure ClearColumnFilters;
    procedure SortBy(const AField: string; ADesc: Boolean);
    function FooterText: string;
    function FilterError: string;
    procedure AttachCalcRules(AQuery: TZQuery; const ARules: string; AHolder: TFPObjectList);
    function HasGrid: Boolean;
    function SubCount(const AName: string): Integer;
    function SubQuery(const AName: string): TZQuery;
    function SubGrid(const AName: string): TDBGrid;
    function MainGrid: TDBGrid;
    { prikaz tablice (TDBGrid ili vlastita), za ispitivanje }
    function GridView: TaGridView;
    function SubView(const AName: string): TaGridView;
    function AggregateOf(const AFunc, AField: string): Variant;
    function ValueOf(const AName: string): Variant;
    procedure SetMaster(const AField, AValue: string);
    property Context: TaScriptContext read FContext;
    procedure Requery;
    procedure Search(const AText: string);
    property Query: TZQuery read FQuery;
  end;

function PickDate(AOwner: TComponent; var ADate: TDateTime): Boolean;

type
  TRunnerMessageProc = procedure(const AMsg: string);
  TRunnerConfirmFunc = function(const AMsg: string): Boolean;
  { LOV: skup podataka mora ostati na odabranom retku; False = odustao }
  TRunnerLovFunc = function(ADs: TaDataSet; const ATitle, AInitial: string): Boolean;
  { radni prostor moze preuzeti otvaranje forme (kartica umjesto prozora); True = preuzeo }
  TOpenFormHook = function(const AName: string): Boolean of object;

var
  OpenFormHook: TOpenFormHook = nil;
  { When set, runtime messages go here instead of a dialog (tests, scripting). }
  OnRunnerMessage: TRunnerMessageProc = nil;
  { When set, the 'delete?' confirmation is answered by this function instead of a dialog (tests, scripting). }
  OnRunnerConfirm: TRunnerConfirmFunc = nil;
  { When set, the LOV picker is this function instead of the dialog (tests, scripting). }
  OnRunnerLov: TRunnerLovFunc = nil;

implementation

uses
  ta_reportdef, ta_reportdesign, ta_letterdlg, ta_owndate;

procedure ParseCalcRules(const ARules: string; AOut: TObjectList); forward;

const
  NavActions: array[0..8] of string = ('first', 'prior', 'next', 'last', 'new', 'delete', 'save', 'query', 'execquery');
  NavCaptions: array[0..8] of string = ('|<', '<', '>', '>|', '+', 'Briši', 'Spremi', 'Upit', 'Izvrši');

type
  { Memo polja (SQLite TEXT) mreza prikazuje kao sirovi tekst i zaobilazi OnGetText; ovdje se prikaz s formatom (datum, iznos) iscrtava preko. }
  TaGridFmtDraw = class
  public
    procedure Draw(Sender: TObject; const Rect: TRect; DataCol: Integer; Column: TColumn; State: TGridDrawState);
  end;

  { What scripts and macros see while a form is running. }
  TFormContext = class(TaScriptContext)
  public
    Runner: TaFormRunner;
    function GetValue(const AName: string): string; override;
    procedure SetValue(const AName, AValue: string); override;
    function EvalV(const AExpr: string): Variant; override;
    procedure DoAction(const AAction: string); override;
    procedure SetVisible(const AName: string; AValue: Boolean); override;
    procedure SetEnabled(const AName: string; AValue: Boolean); override;
    procedure SetCaption(const AName, AValue: string); override;
    procedure FocusControl(const AName: string); override;
  end;

function TFormContext.GetValue(const AName: string): string;
begin
  Result := Runner.ValueText(AName);
end;

procedure TFormContext.SetValue(const AName, AValue: string);
begin
  Runner.ScriptSet(AName, AValue);
end;

function TFormContext.EvalV(const AExpr: string): Variant;
begin
  Result := EvalExpr(AExpr, Runner.FHost);
end;

procedure TFormContext.DoAction(const AAction: string);
begin
  Runner.DoAction(AAction);
end;

procedure TFormContext.SetVisible(const AName: string; AValue: Boolean);
var
  C: TControl;
begin
  C := Runner.FindControl(AName);
  if C <> nil then C.Visible := AValue;
end;

procedure TFormContext.SetEnabled(const AName: string; AValue: Boolean);
var
  C: TControl;
begin
  C := Runner.FindControl(AName);
  if C <> nil then C.Enabled := AValue;
end;

procedure TFormContext.SetCaption(const AName, AValue: string);
var
  C: TControl;
begin
  C := Runner.FindControl(AName);
  if C <> nil then C.Caption := AValue;
end;

procedure TFormContext.FocusControl(const AName: string);
var
  C: TControl;
begin
  C := Runner.FindControl(AName);
  if (C <> nil) and (C is TWinControl) and TWinControl(C).CanFocus then TWinControl(C).SetFocus;
end;

function AskRunner(const AMsg: string): Boolean;
begin
  if Assigned(OnRunnerConfirm) then Result := OnRunnerConfirm(AMsg)
  else Result := MessageDlg(AMsg, mtConfirmation, [mbYes, mbNo], 0) = mrYes;
end;

procedure Notify(const AMsg: string);
begin
  if Assigned(OnRunnerMessage) then OnRunnerMessage(AMsg) else ScriptNotify(AMsg);
end;

{ ---------------- date picker ---------------- }

{ Izbor datuma u dijalogu: vlastiti kalendar (ta_owndate) umjesto izvornog TCalendar, pa izgleda isto na svakom sucelju. }
type
  TCalHelper = class
  public
    Form: TForm;
    procedure Picked(ADate: TDateTime);
  end;

procedure TCalHelper.Picked(ADate: TDateTime);
begin
  Form.ModalResult := mrOk;
end;

function PickDate(AOwner: TComponent; var ADate: TDateTime): Boolean;
var
  F: TForm;
  Cal: TaOwnCalendar;
  H: TCalHelper;
begin
  F := TForm.CreateNew(AOwner);
  H := TCalHelper.Create;
  try
    H.Form := F;
    F.Caption := Tr('Choose a date');
    F.Position := poOwnerFormCenter;
    Cal := TaOwnCalendar.Create(F);
    Cal.Parent := F;
    Cal.Left := 8;
    Cal.Top := 8;
    Cal.Visible := True;
    Cal.SetDate(ADate);
    Cal.OnPick := @H.Picked;
    F.ClientWidth := Cal.Width + 16;
    F.ClientHeight := Cal.Height + 60;
    with TButton.Create(F) do begin Parent := F; Caption := Tr('OK'); ModalResult := mrOk; SetBounds(F.ClientWidth - 176, Cal.Height + 20, 80, 28); end;
    with TButton.Create(F) do begin Parent := F; Caption := Tr('Cancel'); ModalResult := mrCancel; SetBounds(F.ClientWidth - 88, Cal.Height + 20, 80, 28); end;
    Result := F.ShowModal = mrOk;
    if Result then ADate := Cal.Selected;
  finally
    H.Free;
    F.Free;
  end;
end;

{ ---------------- sub info ---------------- }

function TaCalcHost.FieldValue(const AName: string): Variant;
var
  F: TField;
begin
  Result := Null;
  F := Query.FindField(AName);
  if (F = nil) or F.IsNull then Exit;
  if F.DataType in [ftSmallint, ftInteger, ftLargeint, ftWord, ftAutoInc] then Result := F.AsLargeInt
  else if F.DataType in [ftFloat, ftCurrency, ftBCD, ftFMTBcd, ftSingle] then Result := F.AsFloat
  else if F.DataType = ftBoolean then Result := F.AsBoolean
  else Result := F.AsString;
end;

function TaCalcHost.Aggregate(const AFunc, AField: string): Variant;
begin
  Result := Null;
end;

function TaCalcHost.Variable(const AName: string): Variant;
begin
  Result := Null;
end;

constructor TaCalcRule.Create;
begin
  Triggers := TStringList.Create;
end;

destructor TaCalcRule.Destroy;
begin
  Triggers.Free;
  inherited Destroy;
end;

constructor TaCalcSet.Create;
begin
  Host := TaCalcHost.Create;
  Rules := TObjectList.Create(True);
  Hooks := TObjectList.Create(True);
end;

destructor TaCalcSet.Destroy;
begin
  Hooks.Free;
  Rules.Free;
  Host.Free;
  inherited Destroy;
end;

procedure TaCalcHook.Changed(Sender: TField);
var
  I: Integer;
  R: TaCalcRule;
  V: Variant;
  Err: string;
  T: TField;
  D: Double;
begin
  if Assigned(Prev) then Prev(Sender);
  if Owner.Busy then Exit;
  if not (Owner.Query.State in [dsEdit, dsInsert]) then Exit;
  Owner.Busy := True;
  try
    for I := 0 to Owner.Rules.Count - 1 do
    begin
      R := TaCalcRule(Owner.Rules[I]);
      if R.Triggers.IndexOf(LowerCase(Sender.FieldName)) < 0 then Continue;
      T := Owner.Query.FindField(R.Target);
      if T = nil then Continue;
      try
        V := EvalExprEx(R.Expr, Owner.Host, Err);
        if (Err <> '') or VarIsNull(V) or VarIsEmpty(V) then Continue;
        if VarIsNumeric(V) then
        begin
          D := V;
          if IsNan(D) or IsInfinite(D) then Continue;
          if T.DataType in [ftSmallint, ftInteger, ftLargeint, ftWord, ftAutoInc] then SetFieldStored(T, IntToStr(Round(D)))
          else SetFieldStored(T, FloatToStr(D, InvariantFS));
        end
        else SetFieldStored(T, VarToStr(V));
      except
      end;
    end;
  finally
    Owner.Busy := False;
  end;
end;

procedure TaAutoFill.Changed(Sender: TField);
var
  St: TStringList;
  I: Integer;
  F: TField;
begin
  if Busy or Sender.IsNull then Exit;
  if not (Query.State in [dsEdit, dsInsert]) then Exit;
  Busy := True;
  St := TStringList.Create;
  try
    if AutoFillLookup(Db, Def, FieldStored(Sender), St) then
      for I := 0 to High(Def.Targets) do
      begin
        F := Query.FindField(Def.Targets[I]);
        if F <> nil then SetFieldStored(F, St.ValueFromIndex[I]);
      end;
  finally
    St.Free;
    Busy := False;
  end;
end;

destructor TaSubInfo.Destroy;
var
  I: Integer;
begin
  Holder.Free;
  FreeAndNil(Formatter);
  { mreza i izvor podataka zive duze od upita: odvoji ih i oslobodi polja stupaca, inace stupci drze pokazivace na oslobodena polja }
  if (Source <> nil) and (Query <> nil) and (Source.DataSet = Query) then Source.DataSet := nil;
  if View <> nil then View.ReleaseFields;
  if Query <> nil then
  begin
    Query.OnNewRecord := nil;
    Query.Free;
  end;
  View.Free;
  inherited Destroy;
end;

procedure TaSubInfo.AddClick(Sender: TObject);
begin
  if (Query = nil) or not Query.Active then Exit;
  if (Def.LinkChild <> '') and (MasterValue = '') then
  begin
    Notify(Tr('First save the main record, then add items.'));
    Exit;
  end;
  try
    if Query.State in [dsEdit, dsInsert] then Query.Post;
    Query.Append;
  except
    on E: Exception do Notify(Tr('A new row is not possible: ') + E.Message);
  end;
  if Grid.CanFocus then Grid.SetFocus;
end;

procedure TaSubInfo.DelClick(Sender: TObject);
begin
  if (Query = nil) or not Query.Active or Query.IsEmpty then Exit;
  if not AskRunner(Tr('Delete the row?')) then Exit;
  try
    if Query.State = dsInsert then Query.Cancel else Query.Delete;
  except
    on E: Exception do Notify(Tr('Deleting failed: ') + E.Message);
  end;
end;

procedure TaSubInfo.PostClick(Sender: TObject);
begin
  if (Query <> nil) and (Query.State in [dsEdit, dsInsert]) then
    try
      Query.Post;
    except
      on E: Exception do Notify(Tr('Saving failed: ') + E.Message);
    end;
end;

{ calculated columns are computed by the query, so they are refreshed after an edit }
procedure TaSubInfo.AfterPostRefresh(DataSet: TDataSet);
begin
  if HasCalc then
    try
      Query.Refresh;
    except
    end;
  { totals on the master form (DSum over these rows) follow the edit }
  if Assigned(OnChanged) then OnChanged(Self);
end;

destructor TaSubSheet.Destroy;
begin
  if View <> nil then View.ReleaseFields;
  Holder.Free;
  FreeAndNil(Formatter);
  if Source <> nil then Source.DataSet := nil;
  if Query <> nil then
  begin
    Query.OnNewRecord := nil;
    Query.Free;
  end;
  Source.Free;
  View.Free;
  inherited Destroy;
end;

procedure TaSubSheet.NewRecord(DataSet: TDataSet);
begin
  if Formatter <> nil then Formatter.NewRecord(DataSet);
  if (LinkCol <> '') and (Key <> '') and (DataSet.FindField(LinkCol) <> nil) then DataSet.FieldByName(LinkCol).AsString := Key;
end;

procedure TaSubInfo.NewRecord(DataSet: TDataSet);
begin
  if Formatter <> nil then Formatter.NewRecord(DataSet);
  if (Def.LinkChild <> '') and (MasterValue <> '') then
    DataSet.FieldByName(Def.LinkChild).AsString := MasterValue;
end;

{ ---------------- host ---------------- }

function TaFormHost.FieldValue(const AName: string): Variant;
begin
  Result := Runner.ValueOf(AName);
end;

function TaFormHost.Aggregate(const AFunc, AField: string): Variant;
begin
  Result := Runner.AggregateOf(AFunc, AField);
end;

function TaFormHost.Variable(const AName: string): Variant;
begin
  Result := Runner.ValueOf(AName);
end;

function TaFormHost.Domain(const AFunc, AExpr, ADomain, ACriteria: string): Variant;
begin
  Result := DbDomain(Runner.FDb, AFunc, AExpr, ADomain, ACriteria);
end;

function TaFormHost.SubAggregate(const AFunc, ASub, AField: string): Variant;
begin
  Result := Runner.SubAggregateOf(AFunc, ASub, AField);
end;

{ ---------------- construction ---------------- }

constructor TaFormRunner.CreateRunner(AOwner: TComponent; ADb: TAppDb; ADef: TaFormDef);
var
  NavH: Integer;
begin
  inherited CreateNew(AOwner);
  FDb := ADb;
  FDef := ADef;
  { klase svojstava (19.7): kontrola uzima ono sto sama nema }
  ApplyPropClasses(FDef, ADb);
  { izrazi u formi mogu zvati funkcije iz modula: skripta mora biti ucitana prije prvog izracuna }
  if ADb.Connected then Scripts(ADb).HasProc('');
  if not (AOwner is TaFormRunner) then ADb.ClearParams;   { upit s parametrima pita ponovo }
  if SessionRole = arViewer then
  begin
    FDef.AllowEdits := False;
    FDef.AllowAdds := False;
    FDef.AllowDeletes := False;
  end;
  FGridHolder := TFPObjectList.Create(True);
  FColFilters := TStringList.Create;
  FQueryEdits := TStringList.Create;
  FKindCache := TStringList.Create;
  FBound := TList.Create;
  FCalc := TList.Create;
  FAll := TList.Create;
  FCharts := TList.Create;
  FDisplay := TList.Create;
  FDynamic := TList.Create;
  FSubs := TFPObjectList.Create(True);
  FMetas := TFPObjectList.Create(True);
  FFieldNames := TStringList.Create;
  { pravila za formu s jednim zapisom }
  if Trim(FDef.CalcRules) <> '' then
  begin
    FFormRules := TObjectList.Create(True);
    ParseCalcRules(FDef.CalcRules, FFormRules);
  end;
  if Trim(FDef.AutoFill) <> '' then
  begin
    FFormAutoDefs := ParseAutoFillDefs(FDef.AutoFill);
    FFormAutoFill := TStringList.Create;
  end;
  ActiveDb := FDb;
  DefaultDomainHook := @ActiveDomain;
  FHost := TaFormHost.Create;
  FHost.Runner := Self;
  FEngine := TaBindingEngine.Create(FHost);
  FRuleColored := TList.Create;
  FPrevFilters := TStringList.Create;
  FKeyMap := GlobalKeyMap;
  KeyPreview := True;
  OnKeyDown := @RunnerKeyDown;
  FContext := TFormContext.Create(ADb);
  TFormContext(FContext).Runner := Self;
  FOpening := True;
  Caption := FDef.Caption;
  if Caption = '' then Caption := FDef.Name;
  Position := poScreenCenter;
  OnCloseQuery := @RunnerCloseQuery;
  FBuilding := True;
  if FDef.NavButtons and (FDef.ViewMode <> 'continuous') and (FDef.ViewMode <> 'board') and (FDef.ViewMode <> 'dash') and (FDef.ViewMode <> 'timeline') then begin BuildNav; NavH := 34; end else NavH := 0;
  ClientWidth := FDef.Width;
  if FDef.ViewMode = 'datasheet' then ClientHeight := Max(FDef.Height, 360) + NavH
  else if FDef.ViewMode = 'split' then ClientHeight := FDef.Height + 220 + NavH
  else ClientHeight := FDef.Height + NavH;
  if (FDef.RecordSource <> '') and (FDb.LoadObject('_sys_queries', FDef.RecordSource) = '') then
  begin
    FMetas.Free;
    FMetas := FDb.LoadFieldMetas(FDef.RecordSource);
    AddDictCopyRules;
  end;
  if FDef.ViewMode = 'continuous' then BuildContinuous
  else if FDef.ViewMode = 'board' then BuildBoard
  else if FDef.ViewMode = 'dash' then BuildDash
  else if FDef.ViewMode = 'timeline' then BuildTimeline
  else
  begin
    if (FDef.ViewMode <> 'datasheet') or (FDef.Count > 0) then BuildControls;
    BuildGrid;
  end;
  FBuilding := False;
  ApplyWindowFlags;
  if (FDef.RecordSource <> '') and (FCont = nil) and (FBoard = nil) and (FDashBody = nil) and (FTimeBody = nil) then
  begin
    OpenQuery;
    FQuery.AfterScroll := @Scrolled;
  end;
  if (FCont = nil) and (FBoard = nil) and (FDashBody = nil) and (FTimeBody = nil) then LoadRecord;
  FOpening := False;
  FireEvent('OnOpen');
  FInCurrent := True;
  try
    FireEvent('OnCurrent');
  finally
    FInCurrent := False;
  end;
end;

destructor TaFormRunner.Destroy;
var
  I: Integer;
begin
  if FQuery <> nil then FQuery.AfterScroll := nil;
  FGridHolder.Free;
  FFormRules.Free;
  FFormAutoFill.Free;
  FColFilters.Free;
  FQueryEdits.Free;
  FRowHost.Free;
  FKindCache.Free;
  FreeAndNil(FFormatter);
  { mreza prezivi upit do kraja destruktora forme; bez odvajanja drzi pokazivace na oslobodena polja (pristupno krsenje pri fokusu) }
  if (FGridSource <> nil) and (FQuery <> nil) and (FGridSource.DataSet = FQuery) then FGridSource.DataSet := nil;
  if (FView <> nil) and (FView.Own <> nil) then
  begin
    FView.Own.OnSubOpen := nil;
    FView.Own.CollapseAll;
    FView.Own.OnSubClose := nil;
  end;
  FreeAndNil(FSubSheets);
  if FView <> nil then FView.ReleaseFields;
  if FQuery <> nil then FreeAndNil(FQuery);
  FreeAndNil(FView);
  FSubs.Free;
  FMetas.Free;
  FPrevFilters.Free;
  FRuleColored.Free;
  FEngine.Free;
  FHost.Free;
  FContext.Free;
  FFieldNames.Free;
  FDynamic.Free;
  FDisplay.Free;
  FCharts.Free;
  FAll.Free;
  FCalc.Free;
  FBound.Free;
  FDef.Free;
  inherited Destroy;
end;

{ velicina prozora, minimize/maximize i sidra kontrola (razmak od ruba ostaje pri promjeni velicine) }
procedure TaFormRunner.ApplyWindowFlags;
var
  I: Integer;
  Ic: TBorderIcons;
begin
  if FDef.Resizable then BorderStyle := bsSizeable else BorderStyle := bsSingle;
  Ic := [biSystemMenu];
  if FDef.CanMinimize then Include(Ic, biMinimize);
  if FDef.CanMaximize and FDef.Resizable then Include(Ic, biMaximize);
  BorderIcons := Ic;
  { sidra se postavljaju kad su sve kontrole na mjestu }
  for I := 0 to FAll.Count - 1 do
    ApplyControlLayout(TControl(FAll[I]), DefOf(TControl(FAll[I])));
  if FDef.StartMaximized and FDef.Resizable then WindowState := wsMaximized;
end;

function GridKindFor(const AViewMode: string): TaGridKind;
begin
  if AViewMode = 'split' then Result := gkSplit else Result := gkMain;
end;

procedure TaFormRunner.BuildGrid;
begin
  if (FDef.ViewMode <> 'datasheet') and (FDef.ViewMode <> 'split') then Exit;
  FGridSource := TDataSource.Create(Self);
  FFooterPn := TPanel.Create(Self);
  FFooterPn.Parent := Self;
  FFooterPn.Align := alBottom;
  FFooterPn.Height := 24;
  FFooterPn.BevelOuter := bvNone;
  FFooter := TLabel.Create(FFooterPn);
  FFooter.Parent := FFooterPn;
  FFooter.SetBounds(6, 4, 900, 18);
  FView := TaGridView.Create(Self, Self, GridKindFor(FDef.ViewMode), PreferredProvider = 'own', not FDef.AllowEdits, FGridSource);
  FGrid := FView.DBGrid;
  FView.OnTitleClick := @GridTitleClick;
  FGridRules := ParseCondFormat(FDef.GridFormat);
  if Length(FGridRules) > 0 then
  begin
    FRowHost := TaRowHost.Create;
    FRowHost.Db := FDb;
    FRowHost.Metas := FMetas;
    FView.OnRowStyle := @GridRowStyle;
  end;
  ConfigureSubDatasheet;
end;

procedure TaGridFmtDraw.Draw(Sender: TObject; const Rect: TRect; DataCol: Integer; Column: TColumn; State: TGridDrawState);
var
  F: TField;
  G: TDBGrid;
  St: TTextStyle;
begin
  G := TDBGrid(Sender);
  F := Column.Field;
  if (F = nil) or (F.DataType <> ftMemo) or not Assigned(F.OnGetText) then Exit;
  G.Canvas.FillRect(Rect);
  FillChar(St, SizeOf(St), 0);
  St.SingleLine := True;
  St.Clipping := True;
  St.Layout := tlCenter;
  St.Alignment := Column.Alignment;
  G.Canvas.TextRect(Rect, Rect.Left + 3, Rect.Top, F.DisplayText, St);
end;

{ Grid columns for a table: foreign keys become drop-down lists of names, the link
  column is hidden, calculated columns are read-only, and AutoFill rules are armed. }
procedure TaFormRunner.AttachGridExtras(AQuery: TZQuery; AView: TaGridView; const ATable, AHideField,
  AAutoFill, ACalc: string; AHolder: TFPObjectList; const ARules: string = '');
var
  Fks, Calc, Rules, Pairs: TStringList;
  Parts: TStringList;
  AfDefs: TaAutoFillDefs;
  I, J, P, Q2: Integer;
  F: TField;
  Fmt: TaLookupFmt;
  Lk: TZQuery;
  Ci: Integer;
  Af: TaAutoFill;
  Rule, Head, Pair: string;
  LookupFields: TStringList;
  Dict: TFPObjectList;
  Dm: TaFieldMeta;
  K2: Integer;
  FmtDraw: TaGridFmtDraw;
begin
  if (AQuery = nil) or not AQuery.Active or (AView = nil) then Exit;
  AHolder.Clear;
  LookupFields := TStringList.Create;
  Dict := TFPObjectList.Create(True);
  if (ATable <> '') and (FDb.LoadObject('_sys_queries', ATable) = '') then
  begin
    Dict.Free;
    Dict := FDb.LoadFieldMetas(ATable);
  end;
  try
    if (ATable <> '') and (FDb.LoadObject('_sys_queries', ATable) = '') then
    begin
      Fks := FDb.ForeignKeys(ATable);
      Parts := TStringList.Create;
      Parts.Delimiter := '|';
      Parts.StrictDelimiter := True;
      try
        for I := 0 to Fks.Count - 1 do
        begin
          Parts.DelimitedText := Fks[I];
          if Parts.Count < 3 then Continue;
          F := AQuery.FindField(Parts[0]);
          if F = nil then Continue;
          Fmt := TaLookupFmt.Create;
          Lk := FDb.NewQuery(LookupQuerySql(FDb, Parts[1], Parts[2]));
          try
            try
              Lk.Open;
              while not Lk.EOF do
              begin
                Fmt.Keys.Add(FieldStored(Lk.Fields[0]));
                Fmt.Labels.Add(Lk.Fields[1].AsString);
                Lk.Next;
              end;
            except
            end;
          finally
            Lk.Free;
          end;
          F.OnGetText := @Fmt.GetText;
          F.OnSetText := @Fmt.SetText;
          AHolder.Add(Fmt);
          LookupFields.AddObject(Parts[0], Fmt);
        end;
      finally
        Parts.Free;
        Fks.Free;
      end;
    end;
    { columns }
    Calc := CalcFieldNames(ACalc);
    try
      AView.ClearColumns;
      for I := 0 to AQuery.FieldCount - 1 do
      begin
        F := AQuery.Fields[I];
        Ci := AView.AddColumn(F.FieldName, PrettyName(F.FieldName));
        { rjecnik podataka: oznaka i sirina stupca }
        for K2 := 0 to Dict.Count - 1 do
        begin
          Dm := TaFieldMeta(Dict[K2]);
          if SameText(Dm.FieldName, F.FieldName) then
          begin
            if Trim(Dm.Caption) <> '' then AView.SetColTitle(Ci, Trim(Dm.Caption));
            if Dm.ColWidth > 0 then AView.SetColWidth(Ci, Dm.ColWidth);
          end;
        end;
        J := LookupFields.IndexOf(F.FieldName);
        if J >= 0 then AView.SetColPick(Ci, TaLookupFmt(LookupFields.Objects[J]).Labels);
        if Calc.IndexOf(F.FieldName) >= 0 then AView.SetColReadOnly(Ci);
        if (AHideField <> '') and SameText(F.FieldName, AHideField) then AView.SetColVisible(Ci, False);
      end;
    finally
      Calc.Free;
    end;
    { auto-fill rules: field>table.keycol:target=source,target2=source2 ;; ... (parser u ta_bindengine) }
    AfDefs := ParseAutoFillDefs(AAutoFill);
    for I := 0 to High(AfDefs) do
    begin
      F := AQuery.FindField(AfDefs[I].Field);
      if F = nil then Continue;
      Af := TaAutoFill.Create;
      Af.Db := FDb;
      Af.Query := AQuery;
      Af.Def := AfDefs[I];
      F.OnChange := @Af.Changed;
      AHolder.Add(Af);
    end;
    if (AView.DBGrid <> nil) and not Assigned(AView.DBGrid.OnDrawColumnCell) then
    begin
      FmtDraw := TaGridFmtDraw.Create;
      AView.DBGrid.OnDrawColumnCell := @FmtDraw.Draw;
      AHolder.Add(FmtDraw);
    end;
    AttachCalcRules(AQuery, ARules, AHolder);
  finally
    LookupFields.Free;
    Dict.Free;
  end;
end;

{ razbija "a,b -> cilj = izraz ;; ..." u pravila (parser je u ta_bindengine, isti za sve prikaze) }
procedure ParseCalcRules(const ARules: string; AOut: TObjectList);
var
  Defs: TaCalcRuleDefs;
  R: TaCalcRule;
  I, J: Integer;
begin
  Defs := ParseCalcRuleDefs(ARules);
  for I := 0 to High(Defs) do
  begin
    R := TaCalcRule.Create;
    for J := 0 to High(Defs[I].Triggers) do R.Triggers.Add(Defs[I].Triggers[J]);
    R.Target := Defs[I].Target;
    R.Expr := Defs[I].Expr;
    AOut.Add(R);
  end;
end;

{ pravila izracuna: "a,b -> cilj = izraz ;; ..." }
procedure TaFormRunner.AttachCalcRules(AQuery: TZQuery; const ARules: string; AHolder: TFPObjectList);
var
  Cs: TaCalcSet;
  Hk: TaCalcHook;
  I, J: Integer;
  Names: TStringList;
  F: TField;
begin
  if Trim(ARules) = '' then Exit;
  Cs := TaCalcSet.Create;
  Cs.Query := AQuery;
  Cs.Host.Query := AQuery;
  Names := TStringList.Create;
  try
    ParseCalcRules(ARules, Cs.Rules);
  { jedan hook po polju-okidacu }
    Names.Clear;
    for I := 0 to Cs.Rules.Count - 1 do
      for J := 0 to TaCalcRule(Cs.Rules[I]).Triggers.Count - 1 do
        if Names.IndexOf(TaCalcRule(Cs.Rules[I]).Triggers[J]) < 0 then Names.Add(TaCalcRule(Cs.Rules[I]).Triggers[J]);
    for I := 0 to Names.Count - 1 do
    begin
      F := AQuery.FindField(Names[I]);
      if F = nil then Continue;
      Hk := TaCalcHook.Create;
      Hk.Owner := Cs;
      Hk.Prev := F.OnChange;
      F.OnChange := @Hk.Changed;
      Cs.Hooks.Add(Hk);
    end;
  finally
    Names.Free;
  end;
  if Cs.Hooks.Count = 0 then Cs.Free else AHolder.Add(Cs);
end;

function TaFormRunner.HasGrid: Boolean;
begin
  Result := FView <> nil;
end;

procedure TaFormRunner.BuildNav;
var
  Pn: TPanel;
  I, X, W: Integer;
  B: TCustomButton;
const
  NavIcons: array[0..8] of string = ('first', 'prev', 'next', 'last', 'add', 'delete', 'save', 'search', 'check');
  NavHints: array[0..8] of string = ('Prvi zapis', 'Prethodni zapis', 'Sljedeći zapis', 'Zadnji zapis', 'Novi zapis', 'Briši zapis', 'Spremi zapis', 'Upit po formi (F7)', 'Izvrši upit (F8)');
begin
  Pn := TPanel.Create(Self);
  Pn.Parent := Self;
  Pn.Align := alBottom;
  Pn.Height := 34;
  Pn.BevelOuter := bvNone;
  X := 4;
  for I := 0 to 6 do
  begin
    { strelice i plus su samo ikone, Briši i Spremi imaju i natpis }
    if I < 5 then W := 36 else W := 86;
    if I < 5 then B := MakeToolBtn(Pn, '', NavIcons[I], X, 4, W, 26, @NavClick, Tr(NavHints[I]))
    else B := MakeToolBtn(Pn, Tr(NavCaptions[I]), NavIcons[I], X, 4, W, 26, @NavClick, Tr(NavHints[I]));
    B.Tag := I;
    FNavButtons[I] := B;
    Inc(X, W + 4);
  end;
  FPos := TLabel.Create(Pn);
  FPos.Parent := Pn;
  FPos.Left := X + 8;
  FPos.Top := 10;
  Inc(X, 150);
  { upit po formi (F7) i izvrsi upit (F8) iza oznake zapisa, da ona ostane vidljiva i u uskim formama }
  for I := 7 to 8 do
  begin
    B := MakeToolBtn(Pn, '', NavIcons[I], X, 4, 36, 26, @NavClick, Tr(NavHints[I]));
    B.Tag := I;
    FNavButtons[I] := B;
    Inc(X, 40);
  end;
  FSearchEdit := TEdit.Create(Pn);
  FSearchEdit.Parent := Pn;
  FSearchEdit.SetBounds(X, 5, 150, 24);
  FSearchEdit.TextHint := Tr('search...');
  FSearchEdit.OnKeyPress := @SearchKey;
  B := TButton.Create(Pn);
  B.Parent := Pn;
  B.Caption := Tr('Find');
  B.Tag := 1;
  B.OnClick := @SearchClick;
  B.SetBounds(X + 156, 4, 56, 26);
  B := TButton.Create(Pn);
  B.Parent := Pn;
  B.Caption := Tr('All');
  B.Tag := 0;
  B.OnClick := @SearchClick;
  B.SetBounds(X + 216, 4, 46, 26);
  if (FDef.ViewMode = 'datasheet') or (FDef.ViewMode = 'split') then
  begin
    B := TButton.Create(Pn);
    B.Parent := Pn;
    B.Caption := Tr('Filters...');
    B.OnClick := @FiltersClick;
    B.SetBounds(X + 270, 4, 70, 26);
    B := TButton.Create(Pn);
    B.Parent := Pn;
    B.Caption := Tr('Query');
    B.OnClick := @QueryClick;
    B.SetBounds(X + 408, 4, 56, 26);
    B := TButton.Create(Pn);
    B.Parent := Pn;
    B.Caption := Tr('Export');
    B.OnClick := @ExportClick;
    B.SetBounds(X + 344, 4, 60, 26);
  end;
end;

function TaFormRunner.FindControl(const AName: string): TControl;
var
  I: Integer;
begin
  for I := 0 to FAll.Count - 1 do
    if SameText(DefOf(TControl(FAll[I])).Name, AName) then Exit(TControl(FAll[I]));
  Result := nil;
end;

function TaFormRunner.ControlByName(const AName: string): TControl;
begin
  Result := FindControl(AName);
  if Result = nil then Result := TControl(FindComponent(AName));
end;

function TaFormRunner.HasKeys(C: TControl): Boolean;
begin
  Result := FamilyHasKeys(C) or ((C is TaComboBox) and (TaComboBox(C).Keys <> nil)) or
            ((C is TaListBox) and (TaListBox(C).Keys <> nil)) or
            ((C is TaOptionGroup) and (TaOptionGroup(C).Keys <> nil));
end;

procedure TaFormRunner.LockControl(C: TControl);
begin
  if C is TEdit then TEdit(C).ReadOnly := True
  else if C is TMemo then TMemo(C).ReadOnly := True
  else if C is TaRichBase then TaRichBase(C).ReadOnly := True
  else if FamilyLock(C) then
  else C.Enabled := False;
end;

procedure TaFormRunner.BuildControls;
var
  I, Pass, Created: Integer;
  D: TaControlDef;
  Done: array of Boolean;
  C, Par: TControl;
  ParentCtl: TWinControl;
  Pg: Integer;
  Cont: string;
begin
  SetLength(Done, FDef.Count);
  for Pass := 1 to 4 do
  begin
    Created := 0;
    for I := 0 to FDef.Count - 1 do
    begin
      if Done[I] then Continue;
      D := FDef[I];
      { rjecnik podataka popunjava samo ono sto kontrola (i njezina klasa svojstava) nema }
      if (D.ControlSource <> '') and (D.ControlSource[1] <> '=') then ApplyDictionaryDefaults(D, MetaFor(D.ControlSource));
      ParentCtl := Self;
      Cont := D.GetX('container');
      if Cont <> '' then
      begin
        Par := FindControl(Cont);
        if (Par <> nil) and FamilyIsContainer(Par) then ParentCtl := TWinControl(Par)   { Panel i Pages obitelji }
        else
        begin
          if (Par = nil) or not (Par is TPageControl) then Continue;   { container not built yet }
          Pg := StrToIntDef(D.GetX('page'), 0);
          if Pg < 0 then Pg := 0;
          if Pg >= TPageControl(Par).PageCount then Pg := TPageControl(Par).PageCount - 1;
          ParentCtl := TPageControl(Par).Pages[Pg];
        end;
      end;
      C := FamilyControlFor(Self, ParentCtl, D);
      if C = nil then C := CreateAccessControl(Self, ParentCtl, D);
      Done[I] := True;
      Inc(Created);
      SetupControl(C, D);
    end;
    if Created = 0 then Break;
  end;
  for I := 0 to FAll.Count - 1 do FamilyShowPages(TControl(FAll[I]));
end;

procedure TaFormRunner.SetupControl(C: TControl; D: TaControlDef);
var
  M: TaFieldMeta;
  Btn: TButton;
begin
  FAll.Add(C);
  { rjecnik podataka: opis polja je savjet kontroli koja nema vlastiti }
  if (D.ControlSource <> '') and (D.ControlSource[1] <> '=') and (D.GetX('tip') = '') then
  begin
    M := MetaFor(D.ControlSource);
    if (M <> nil) and (Trim(M.Description) <> '') then
    begin
      C.Hint := Trim(M.Description);
      C.ShowHint := True;
    end;
  end;
  if C is TaFamilyHost then
  begin
    case FamilyWire(C, @ControlChanged, @ButtonClick, @HyperClick, @LovHostClick) of
      fwHyperlink: if D.ControlSource <> '' then FDisplay.Add(C);
      fwKeyed: FillFamilyList(C);
    end;
    if FamilyKindOf(C) = 'Chart' then FCharts.Add(C)
    else if FamilyKindOf(C) = 'Barcode' then
    begin
      if D.ControlSource <> '' then FDisplay.Add(C);
    end
    else if FamilyKindOf(C) = 'Image' then
    begin
      if D.ControlSource <> '' then
      begin
        FDisplay.Add(C);
        FamilySetDblClick(C, @ImageDblClick);
        AttachImageMenu(C);
      end;
    end;
  end
  else if C is TaHyperlink then
  begin
    TaHyperlink(C).OnClick := @HyperClick;
    if D.ControlSource <> '' then FDisplay.Add(C);
  end
  else if (C is TCustomButton) then TCustomButton(C).OnClick := @ButtonClick
  else if C is TaSideMenu then
  begin
    TaSideMenu(C).OnAction := @SideAction;
    TaSideMenu(C).StateKey := FDef.Name + '/' + D.Name;
    TaSideMenu(C).RestoreState;
  end
  else if C is TToggleBox then
  begin
    TToggleBox(C).OnClick := @ButtonClick;
    TToggleBox(C).OnChange := @ControlChanged;
  end
  else if C is TCheckBox then TCheckBox(C).OnChange := @ControlChanged
  else if C is TComboBox then
  begin
    FillList(C);
    TComboBox(C).OnChange := @ControlChanged;
  end
  else if C is TListBox then
  begin
    FillList(C);
    TListBox(C).OnClick := @ControlChanged;
  end
  else if C is TRadioGroup then
  begin
    FillList(C);
    TRadioGroup(C).OnClick := @ControlChanged;
  end
  else if C is TEdit then TEdit(C).OnChange := @ControlChanged
  else if C is TMemo then TMemo(C).OnChange := @ControlChanged
  else if C is TaRichBase then TaRichBase(C).OnChanged := @ControlChanged
  else if C is TaSubform then BuildSub(TaSubform(C))
  else if C is TaChart then FCharts.Add(C)
  else if C is TaBarcode then
  begin
    if D.ControlSource <> '' then FDisplay.Add(C);
  end
  else if C is TaImage then
  begin
    if D.ControlSource <> '' then
    begin
      FDisplay.Add(C);
      TaImage(C).OnDblClick := @ImageDblClick;
      AttachImageMenu(C);
    end;
  end;
  if (C is TaTabControl) then
  begin
    { pages exist after ApplyDef; nothing else to wire }
  end;
  if IsCalculated(C) then
  begin
    FCalc.Add(C);
    SetLength(FCalcVals, FCalc.Count);
    FCalcVals[FCalc.Count - 1] := Null;
    if C is TEdit then TEdit(C).ReadOnly := True
    else if IsPlainEdit(C) then FamilyLock(C);
  end
  else if IsBoundControl(C) then FBound.Add(C);
  if (D.GetX('onDblClick') <> '') and not (((C is TaImage) or (FamilyKindOf(C) = 'Image')) and (D.ControlSource <> '')) then
    C.OnDblClick := @ControlDblClick;
  if (D.OnClick <> '') and not ((C is TCustomButton) or (C is TToggleBox) or (C is TaHyperlink) or FamilyOwnsClick(C)) then
    C.OnClick := @ButtonClick;
  AttachControlEvents(C, D);
  if D.GetX('locked') = '1' then LockControl(C);
  if (not FDef.AllowEdits) and (IsBoundControl(C)) then LockControl(C);
  { calendar button next to date fields }
  if IsPlainEdit(C) and IsBoundControl(C) and (C.Parent <> nil) then
  begin
    M := MetaFor(D.ControlSource);
    if (M <> nil) and (M.LType in [ltDate, ltDateTime]) and (D.GetX('locked') <> '1') then
    begin
      Btn := TButton.Create(Self);
      Btn.Parent := C.Parent;
      Btn.Caption := '...';
      Btn.Tag := PtrInt(C);
      Btn.SetBounds(D.Left + D.Width + 2, D.Top, 26, D.Height);
      Btn.OnClick := @DateButtonClick;
      Btn.TabStop := False;
    end;
  end;
  if (C is TEdit) and IsBoundControl(C) and (C.Parent <> nil) and (D.GetX('lov') <> '') and (D.GetX('locked') <> '1') then
  begin
    Btn := TButton.Create(Self);
    Btn.Parent := C.Parent;
    Btn.Caption := '...';
    Btn.Hint := Tr('List of values (F9)');
    Btn.ShowHint := True;
    Btn.Tag := PtrInt(C);
    Btn.SetBounds(D.Left + D.Width + 2, D.Top, 26, D.Height);
    Btn.OnClick := @LovButtonClick;
    Btn.TabStop := False;
  end;
  if (D.RowSource <> '') and (Pos('[', D.RowSource) > 0) and
     ((C is TComboBox) or (C is TListBox) or (C is TRadioGroup) or (C is TaChart) or (FamilyKindOf(C) = 'Chart') or IsKeyedFamily(C)) then
    FDynamic.Add(C);
end;

{ ---------------- lists, charts ---------------- }

function TaFormRunner.ExpandPlaceholders(const ASql: string): string;
var
  I, J: Integer;
  Nm, Lit: string;
  V: Variant;
begin
  Result := '';
  I := 1;
  while I <= Length(ASql) do
  begin
    if ASql[I] = '[' then
    begin
      J := I + 1;
      while (J <= Length(ASql)) and (ASql[J] <> ']') do Inc(J);
      Nm := Copy(ASql, I + 1, J - I - 1);
      V := ValueOf(Nm);
      if VarIsNull(V) or VarIsEmpty(V) then Lit := 'NULL'
      else if VarIsNumeric(V) and (VarType(V) <> varBoolean) then Lit := FloatToStr(Double(V), InvariantFS)
      else if VarType(V) = varBoolean then
      begin
        if Boolean(V) then Lit := '1' else Lit := '0';
      end
      else Lit := '''' + StringReplace(VarToStr(V), '''', '''''', [rfReplaceAll]) + '''';
      Result := Result + Lit;
      I := J + 1;
    end
    else
    begin
      Result := Result + ASql[I];
      Inc(I);
    end;
  end;
end;

{ izracun parametra 4GL izvora nad zapisom forme: [polje], izrazi, doslovne vrijednosti }
function TaFormRunner.FglParamEval(const AExpr: string; out AValue: Variant): Boolean;
var
  Err: string;
begin
  AValue := EvalExprEx(AExpr, FHost, Err);
  Result := Err = '';
end;

{ izvor s prefiksom (fgl:, list:, sql:) kao skup podataka; nil + AErr kad ne uspije }
function TaFormRunner.OpenPrefixedSource(const ASource: string; out AErr: string): TDataSet;
var
  D: TaSourceDef;
begin
  D := ParseSource(ASource);
  if D.Kind = skSql then Result := OpenSource(FDb, 'sql:' + ExpandPlaceholders(D.Body), nil, nil, AErr)
  else Result := OpenSource(FDb, ASource, @FglParamEval, nil, AErr);
end;

function SourceHasPrefix(const ASource: string): Boolean;
var
  T: string;
begin
  T := LowerCase(TrimLeft(ASource));
  Result := (Copy(T, 1, 4) = 'fgl:') or (Copy(T, 1, 5) = 'list:') or (Copy(T, 1, 4) = 'sql:');
end;

{ stavke izbora i popisa obitelji: isti izvori kao FillList, ali kao retci "kljuc=natpis" }
procedure TaFormRunner.FillFamilyList(C: TControl);
var
  D: TaControlDef;
  Src, PErr, Keep: string;
  Items: TStringList;
  Ds: TDataSet;
  Q: TZQuery;
  Keys, Lbls: TStringList;
  I: Integer;
  Keyed: Boolean;

  procedure FromDataSet(ADs: TDataSet);
  begin
    Keyed := ADs.FieldCount >= 2;
    while not ADs.EOF do
    begin
      if ADs.FieldCount >= 2 then Items.Add(ADs.Fields[0].AsString + '=' + ADs.Fields[1].AsString)
      else Items.Add(ADs.Fields[0].AsString);
      ADs.Next;
    end;
  end;

begin
  D := DefOf(C);
  Src := Trim(D.RowSource);
  Keep := ReadControlValue(C);
  Keyed := False;
  Items := TStringList.Create;
  try
    if Src = '' then
    begin
      { stavke ostaju kakve su (npr. zadane u definiciji) }
      FreeAndNil(Items);
      Exit;
    end;
    if SourceHasPrefix(Src) then
    begin
      Ds := OpenPrefixedSource(Src, PErr);
      if Ds = nil then Items.Add(Tr('error: ') + PErr)
      else
        try
          FromDataSet(Ds);
        finally
          Ds.Free;
        end;
    end
    else if Pos('SELECT', UpperCase(TrimLeft(Src))) = 1 then
    begin
      Q := FDb.NewQuery(ExpandPlaceholders(Src));
      try
        try
          Q.Open;
          FromDataSet(Q);
        except
        end;
      finally
        Q.Free;
      end;
    end
    else
    begin
      Keys := TStringList.Create;
      Lbls := TStringList.Create;
      try
        if Pos('=', Src) > 0 then
        begin
          ParsePairs(Src, Keys, Lbls);
          for I := 0 to Keys.Count - 1 do Items.Add(Keys[I] + '=' + Lbls[I]);
          Keyed := True;
        end
        else
        begin
          Lbls.Delimiter := ';';
          Lbls.StrictDelimiter := True;
          Lbls.DelimitedText := Src;
          Items.AddStrings(Lbls);
        end;
      finally
        Keys.Free;
        Lbls.Free;
      end;
    end;
    FamilySetItems(C, Items, Keyed);
  finally
    Items.Free;
  end;
  if (Keep <> '') and not FBuilding then
  begin
    FLoading := True;
    try
      WriteControlValue(C, Keep);
    finally
      FLoading := False;
    end;
  end;
end;

procedure TaFormRunner.FillList(C: TControl);
var
  D: TaControlDef;
  Src: string;
  Q: TZQuery;
  Keys: TStringList;
  Labels: TStrings;
  Keep: string;
  IsSql: Boolean;
  Lbls: TStringList;
  Ds: TDataSet;
  PErr: string;

  procedure UseKeys(AList: TStringList);
  begin
    if C is TaComboBox then begin TaComboBox(C).Keys.Free; TaComboBox(C).Keys := AList; end
    else if C is TaListBox then begin TaListBox(C).Keys.Free; TaListBox(C).Keys := AList; end
    else begin TaOptionGroup(C).Keys.Free; TaOptionGroup(C).Keys := AList; end;
  end;

begin
  if IsKeyedFamily(C) then begin FillFamilyList(C); Exit; end;
  D := DefOf(C);
  Src := Trim(D.RowSource);
  if C is TComboBox then Labels := TComboBox(C).Items
  else if C is TListBox then Labels := TListBox(C).Items
  else Labels := TRadioGroup(C).Items;
  Keep := ReadControlValue(C);
  Labels.BeginUpdate;
  try
    Labels.Clear;
    if Src = '' then
    begin
      UseKeys(nil);
      Exit;
    end;
    IsSql := Pos('SELECT', UpperCase(TrimLeft(Src))) = 1;
    if SourceHasPrefix(Src) then
    begin
      { fgl:, list: i sql: izvori daju skup podataka; jedan stupac = oznake, dva = kljuc i oznaka }
      Keys := nil;
      Ds := OpenPrefixedSource(Src, PErr);
      if Ds = nil then
      begin
        UseKeys(nil);
        Labels.Add(Tr('error: ') + PErr);
        Exit;
      end;
      try
        if (Ds.FieldCount >= 2) or (C is TRadioGroup) then
        begin
          Keys := TStringList.Create;
          if C is TComboBox then TComboBox(C).Style := csDropDownList;
        end;
        while not Ds.EOF do
        begin
          if Keys <> nil then
          begin
            Keys.Add(Ds.Fields[0].AsString);
            if Ds.FieldCount >= 2 then Labels.Add(Ds.Fields[1].AsString) else Labels.Add(Ds.Fields[0].AsString);
          end
          else Labels.Add(Ds.Fields[0].AsString);
          Ds.Next;
        end;
      finally
        Ds.Free;
      end;
      UseKeys(Keys);
    end
    else if IsSql then
    begin
      Keys := nil;
      Q := FDb.NewQuery(ExpandPlaceholders(Src));
      try
        try
          Q.Open;
        except
          UseKeys(nil);
          Exit;
        end;
        if (Q.FieldCount >= 2) or (C is TRadioGroup) then
        begin
          Keys := TStringList.Create;
          if C is TComboBox then TComboBox(C).Style := csDropDownList;
        end;
        while not Q.EOF do
        begin
          if Keys <> nil then
          begin
            Keys.Add(Q.Fields[0].AsString);
            if Q.FieldCount >= 2 then Labels.Add(Q.Fields[1].AsString) else Labels.Add(Q.Fields[0].AsString);
          end
          else Labels.Add(Q.Fields[0].AsString);
          Q.Next;
        end;
      finally
        Q.Free;
      end;
      UseKeys(Keys);
    end
    else
    begin
      if (Pos('=', Src) > 0) or (C is TRadioGroup) then
      begin
        Keys := TStringList.Create;
        Lbls := TStringList.Create;
        try
          ParsePairs(Src, Keys, Lbls);
          Labels.Assign(Lbls);
        finally
          Lbls.Free;
        end;
        UseKeys(Keys);
        if C is TComboBox then TComboBox(C).Style := csDropDownList;
      end
      else
      begin
        UseKeys(nil);
        Lbls := TStringList.Create;
        try
          Lbls.Delimiter := ';';
          Lbls.StrictDelimiter := True;
          Lbls.DelimitedText := Src;
          Labels.Assign(Lbls);
        finally
          Lbls.Free;
        end;
      end;
    end;
  finally
    Labels.EndUpdate;
  end;
  if C is TaComboBox then TaComboBox(C).EnableSearch(D.GetX('search') = '1');
  if (Keep <> '') and not FBuilding then
  begin
    FLoading := True;
    try
      WriteControlValue(C, Keep);
    finally
      FLoading := False;
    end;
  end;
end;

procedure TaFormRunner.RefreshCharts;
var
  I, N: Integer;
  C: TControl;
  Lb: TStringList;
  Vals: array of Double;
  Src: string;
  Q: TDataSet;
  CErr: string;
begin
  for I := 0 to FCharts.Count - 1 do
  begin
    C := TControl(FCharts[I]);
    Lb := TStringList.Create;
    SetLength(Vals, 0);
    Src := DefOf(C).RowSource;
    if Src = '' then begin Lb.Free; if C is TaChart then C.Invalidate; Continue; end;
    Q := nil;
    try
      try
        if SourceHasPrefix(Src) then
        begin
          Q := OpenPrefixedSource(Src, CErr);
          if Q = nil then raise Exception.Create(CErr);
        end
        else
        begin
          Q := FDb.NewQuery(ExpandPlaceholders(Src));
          Q.Open;
        end;
        N := 0;
        while (not Q.EOF) and (N < 60) do
        begin
          SetLength(Vals, N + 1);
          if Q.FieldCount >= 2 then
          begin
            Lb.Add(Q.Fields[0].AsString);
            Vals[N] := Q.Fields[1].AsFloat;
          end
          else
          begin
            Lb.Add(IntToStr(N + 1));
            Vals[N] := Q.Fields[0].AsFloat;
          end;
          Inc(N);
          Q.Next;
        end;
      except
        on E: Exception do Lb.Text := Tr('error: ') + E.Message;
      end;
    finally
      Q.Free;
    end;
    if C is TaChart then
    begin
      TaChart(C).Labels.Assign(Lb);
      SetLength(TaChart(C).Values, Length(Vals));
      for N := 0 to High(Vals) do TaChart(C).Values[N] := Vals[N];
      C.Invalidate;
    end
    else FamilySetChartData(C, Lb, Vals);
    Lb.Free;
  end;
end;

procedure TaFormRunner.RefreshDynamic;
var
  I: Integer;
  C: TControl;
begin
  for I := 0 to FDynamic.Count - 1 do
  begin
    C := TControl(FDynamic[I]);
    if (C is TaChart) or (FamilyKindOf(C) = 'Chart') then Continue;   { charts are refreshed by RefreshCharts }
    FillList(C);
  end;
end;

{ ---------------- sub forms ---------------- }

procedure TaFormRunner.BuildSub(APanel: TaSubform);
var
  Info: TaSubInfo;
  Sub: TaFormDef;
  Js: string;
begin
  Info := TaSubInfo.Create;
  Info.Holder := TFPObjectList.Create(True);
  Info.Panel := APanel;
  Info.Def := APanel.Def;
  FSubs.Add(Info);
  Js := '';
  if (APanel.Def.RowSource <> '') and not SameText(APanel.Def.RowSource, FDef.Name) then
    Js := FDb.LoadObject('_sys_forms', APanel.Def.RowSource);
  if Js <> '' then
  begin
    { another saved form, running inside the panel }
    Sub := TaFormDef.Create;
    Sub.FromJson(Js);
    Sub.Name := APanel.Def.RowSource;
    Info.Embedded := TaFormRunner.CreateRunner(Self, FDb, Sub);
    Info.Embedded.BorderStyle := bsNone;
    Info.Embedded.Parent := APanel;
    Info.Embedded.Align := alClient;
    Info.Embedded.Visible := True;
    Info.Embedded.OnDataChanged := @SubChanged;
    Exit;
  end;
  Info.Source := TDataSource.Create(Self);
  Info.Query := FDb.NewQuery('');
  Info.Query.OnNewRecord := @Info.NewRecord;
  Info.Source.DataSet := Info.Query;
  { rows are typed straight into the grid: Down on the last row or "+" adds one }
  Info.View := TaGridView.Create(Self, APanel, gkSub, PreferredProvider = 'own', not FDef.AllowEdits, Info.Source);
  Info.Grid := Info.View.DBGrid;
  Info.Toolbar := TPanel.Create(Self);
  Info.Toolbar.Parent := APanel;
  Info.Toolbar.Align := alTop;
  Info.Toolbar.Height := 28;
  Info.Toolbar.BevelOuter := bvNone;
  with TButton.Create(Info.Toolbar) do
  begin
    Parent := Info.Toolbar; Caption := Tr('+ New row'); SetBounds(2, 2, 90, 24);
    OnClick := @Info.AddClick; Enabled := FDef.AllowAdds and FDef.AllowEdits;
  end;
  with TButton.Create(Info.Toolbar) do
  begin
    Parent := Info.Toolbar; Caption := Tr('- Delete row'); SetBounds(96, 2, 90, 24);
    OnClick := @Info.DelClick; Enabled := FDef.AllowDeletes and FDef.AllowEdits;
  end;
  with TButton.Create(Info.Toolbar) do
  begin
    Parent := Info.Toolbar; Caption := Tr('Save'); SetBounds(190, 2, 80, 24);
    OnClick := @Info.PostClick; Enabled := FDef.AllowEdits;
  end;
end;

procedure TaFormRunner.BuildTimeline;
var
  Err: string;
begin
  FTimeBody := TaTimelineBody.Create(Self);
  FTimeBody.Parent := Self;
  FTimeBody.Align := alClient;
  Err := CheckTimelineSetting(FDef.Timeline);
  if Err <> '' then Notify(Err) else FTimeBody.Setup(FDb, FDef);
end;

{ ESPHome konfiguracije za sve pogone s MQTT temom }
procedure TaFormRunner.ExportEspHome;
var
  D: TSelectDirectoryDialog;
  Log: TStringList;
  N: Integer;
begin
  D := TSelectDirectoryDialog.Create(nil);
  Log := TStringList.Create;
  try
    D.Title := Tr('Folder for the ESPHome configurations');
    if not D.Execute then Exit;
    N := EspHomeExportAll(FDb, D.FileName, Log);
    if N = 0 then Notify(Tr('No unit has an MQTT topic.') + LineEnding + Log.Text)
    else Notify(Format(Tr('%d ESPHome configurations were written to %s.'), [N, D.FileName]) + LineEnding + LineEnding + Log.Text);
  finally
    Log.Free;
    D.Free;
  end;
end;

procedure TaFormRunner.BuildDash;
var
  Err: string;
begin
  FDashBody := TaDashBody.Create(Self);
  FDashBody.Parent := Self;
  FDashBody.Align := alClient;
  Err := CheckDashSetting(FDef.Dash);
  if Err <> '' then Notify(Err) else FDashBody.Setup(FDb, FDef);
end;

procedure TaFormRunner.BuildBoard;
var
  Err: string;
begin
  FBoard := TaBoardBody.Create(Self);
  FBoard.Parent := Self;
  FBoard.Align := alClient;
  FBoard.OnOpenRequest := @BoardOpen;
  FBoard.OnNewRequest := @BoardOpen;
  Err := CheckBoardSetting(FDb, FDef.RecordSource, FDef.Board);
  if Err <> '' then Notify(Err) else FBoard.Setup(FDb, FDef);
end;

{ otvara karticu (ili novi zapis u stupcu) u formi za uredjivanje }
procedure TaFormRunner.BoardOpen(Sender: TObject; const AId, AColumnField, AColumnKey: string);
var
  Js, Nm: string;
  Sub: TaFormDef;
  R: TaFormRunner;
begin
  Nm := FBoard.EditForm;
  Js := FDb.LoadObject('_sys_forms', Nm);
  if Js = '' then begin Notify(Tr('There is no form: ') + Nm); Exit; end;
  if not CanRun(FDb, '_sys_forms', Nm) then begin Notify(Tr('You do not have the right to open the form ') + Nm); Exit; end;
  Sub := TaFormDef.Create;
  Sub.FromJson(Js);
  Sub.Name := Nm;
  R := TaFormRunner.CreateRunner(Self, FDb, Sub);
  try
    if AId <> '' then R.Navigate(AId) else R.NewWith(AColumnField, AColumnKey);
    R.ShowModal;
  finally
    R.Free;
  end;
  FBoard.Reload;
end;

{ postavi se na zapis s tim id-om }
procedure TaFormRunner.Navigate(const AId: string);
begin
  if (FQuery <> nil) and FQuery.Active and (FQuery.FindField('id') <> nil) then FQuery.Locate('id', AId, []);
end;

{ novi zapis s unaprijed upisanom vrijednoscu polja }
procedure TaFormRunner.NewWith(const AField, AValue: string);
var
  F: TField;
begin
  DoAction('new');
  if (FQuery <> nil) and FQuery.Active and (FQuery.State = dsInsert) and (AField <> '') and (AValue <> '') then
  begin
    F := FQuery.FindField(AField);
    if F <> nil then F.AsString := AValue;
  end;
end;

procedure TaFormRunner.BuildContinuous;
begin
  FCont := TaContinuousBody.Create(Self);
  FCont.Parent := Self;
  FCont.Align := alClient;
  FCont.Setup(FDb, FDef);
  FCont.Host.OnDataChange := @ContDataChanged;
end;

procedure TaFormRunner.ContDataChanged(Sender: TObject);
begin
  if FCont <> nil then FCont.RefreshFooter;
  if Assigned(FOnDataChanged) then FOnDataChanged(Self);
end;

function TaFormRunner.ContAggregate(const AFunc, AField: string): string;
begin
  Result := '';
  if FCont <> nil then Result := FCont.Source.Aggregate(AFunc, AField);
end;

function TaFormRunner.SubRunner(const ASub: string): TaFormRunner;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to FSubs.Count - 1 do
    if SameText(TaSubInfo(FSubs[I]).Def.Name, ASub) then Exit(TaSubInfo(FSubs[I]).Embedded);
end;

{ SubSum('Stavke', 'iznos'): podforma se trazi po nazivu kontrole }
function TaFormRunner.SubAggregateOf(const AFunc, ASub, AField: string): Variant;
var
  I: Integer;
  Info: TaSubInfo;
  S, Fn: string;
  Cnt: Integer;
  Sum, V, Mn, Mx: Double;
  Bm: TBookmark;
  F: TField;
begin
  Result := Null;
  Fn := UpperCase(AFunc);
  for I := 0 to FSubs.Count - 1 do
  begin
    Info := TaSubInfo(FSubs[I]);
    if not SameText(Info.Def.Name, ASub) then Continue;
    if Info.Embedded <> nil then
    begin
      S := Info.Embedded.ContAggregate(Fn, AField);
      if S = '' then
      begin
        if Fn = 'COUNT' then Exit(0);
        Exit(Null);
      end;
      Exit(StrToFloat(StringReplace(S, ',', '.', []), DefaultFormatSettings));
    end;
    { mreza: prolaz kroz retke upita podforme }
    if (Info.Query = nil) or not Info.Query.Active then
    begin
      if Fn = 'COUNT' then Exit(0);
      Exit(Null);
    end;
    F := nil;
    if AField <> '*' then F := Info.Query.FindField(AField);
    Cnt := 0; Sum := 0; Mn := 0; Mx := 0;
    Info.Query.DisableControls;
    Bm := Info.Query.GetBookmark;
    try
      Info.Query.First;
      while not Info.Query.EOF do
      begin
        if (F = nil) or not F.IsNull then
        begin
          if F <> nil then
          begin
            V := F.AsFloat;
            if Cnt = 0 then begin Mn := V; Mx := V; end;
            if V < Mn then Mn := V;
            if V > Mx then Mx := V;
            Sum := Sum + V;
          end;
          Inc(Cnt);
        end;
        Info.Query.Next;
      end;
      if Info.Query.BookmarkValid(Bm) then Info.Query.GotoBookmark(Bm);
    finally
      Info.Query.FreeBookmark(Bm);
      Info.Query.EnableControls;
    end;
    if Fn = 'COUNT' then Exit(Cnt);
    if Cnt = 0 then Exit(Null);
    if Fn = 'SUM' then Exit(Sum);
    if Fn = 'AVG' then Exit(Sum / Cnt);
    if Fn = 'MIN' then Exit(Mn);
    if Fn = 'MAX' then Exit(Mx);
  end;
end;

procedure TaFormRunner.SubChanged(Sender: TObject);
begin
  if not (FBuilding or FOpening) then RecalcAll;
end;

procedure TaFormRunner.RefreshSubs;
var
  I: Integer;
  Info: TaSubInfo;
  F: TField;
  CalcCols, CalcErr, BaseSql: string;
begin
  for I := 0 to FSubs.Count - 1 do
  begin
    Info := TaSubInfo(FSubs[I]);
    Info.MasterValue := '';
    if Info.Def.LinkChild <> '' then
    begin
      F := nil;
      if (FQuery <> nil) and FQuery.Active and not FQuery.IsEmpty and (FQuery.State <> dsInsert) then
        F := FQuery.FindField(Info.Def.LinkMaster);
      if (F <> nil) and not F.IsNull then Info.MasterValue := FieldStored(F);
    end;
    if Info.Embedded <> nil then
    begin
      if Info.Def.LinkChild <> '' then Info.Embedded.SetMaster(Info.Def.LinkChild, Info.MasterValue)
      else Info.Embedded.Requery;
      Continue;
    end;
    if Info.Query.State in [dsEdit, dsInsert] then
      try Info.Query.Post; except Info.Query.Cancel; end;
    FreeAndNil(Info.Formatter);
    Info.Query.OnNewRecord := @Info.NewRecord;
    Info.Query.Close;
    if Info.Def.RowSource = '' then Continue;
    CalcCols := '';
    Info.HasCalc := False;
    if Trim(Info.Def.GetX('calc')) <> '' then
    begin
      if CalcFieldsSql(FDb, Info.Def.GetX('calc'), CalcCols, CalcErr) then Info.HasCalc := CalcCols <> ''
      else Notify(Tr('Calculated fields of the subform: ') + CalcErr);
    end;
    BaseSql := 'SELECT *' + CalcCols + ' FROM ' + FDb.SourceFrom(Info.Def.RowSource);
    if Info.Def.LinkChild <> '' then
    begin
      if Info.MasterValue = '' then Continue;
      Info.Query.SQL.Text := BaseSql + ' WHERE ' + FDb.QuoteId(Info.Def.LinkChild) + ' = :v';
      Info.Query.ParamByName('v').AsString := Info.MasterValue;
    end
    else
      Info.Query.SQL.Text := BaseSql;
    Info.Query.AfterPost := @Info.AfterPostRefresh;
    Info.Query.AfterDelete := @Info.AfterPostRefresh;
    Info.OnChanged := @SubChanged;
    Info.Query.Open;
    Info.Holder.Clear;
    AttachGridExtras(Info.Query, Info.View, Info.Def.RowSource, Info.Def.LinkChild, Info.Def.GetX('autofill'), Info.Def.GetX('calc'), Info.Holder, Info.Def.GetX('calcrules'));
    { show dates, currency and Yes/No the way the table's fields are formatted }
    if FDb.LoadObject('_sys_queries', Info.Def.RowSource) = '' then
    begin
      Info.Formatter := TaDatasetFormatter.Create(Info.Query, FDb.LoadFieldMetas(Info.Def.RowSource));
      Info.Query.OnNewRecord := @Info.NewRecord;
    end;
  end;
end;

function TaFormRunner.SubGrid(const AName: string): TDBGrid;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to FSubs.Count - 1 do
    if TaSubInfo(FSubs[I]).Def.Name = AName then Exit(TaSubInfo(FSubs[I]).Grid);
end;

function TaFormRunner.MainGrid: TDBGrid;
begin
  Result := FGrid;
end;

function TaFormRunner.GridView: TaGridView;
begin
  Result := FView;
end;

function TaFormRunner.SubView(const AName: string): TaGridView;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to FSubs.Count - 1 do
    if TaSubInfo(FSubs[I]).Def.Name = AName then Exit(TaSubInfo(FSubs[I]).View);
end;

function TaFormRunner.SubQuery(const AName: string): TZQuery;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to FSubs.Count - 1 do
    if TaSubInfo(FSubs[I]).Def.Name = AName then
    begin
      if TaSubInfo(FSubs[I]).Embedded <> nil then Exit(TaSubInfo(FSubs[I]).Embedded.Query);
      Exit(TaSubInfo(FSubs[I]).Query);
    end;
end;

function TaFormRunner.SubCount(const AName: string): Integer;
var
  I: Integer;
  Info: TaSubInfo;
begin
  Result := -1;
  for I := 0 to FSubs.Count - 1 do
  begin
    Info := TaSubInfo(FSubs[I]);
    if Info.Def.Name <> AName then Continue;
    if Info.Embedded <> nil then
    begin
      if (Info.Embedded.Query <> nil) and Info.Embedded.Query.Active then Exit(Info.Embedded.Query.RecordCount);
      Exit(-1);
    end;
    if Info.Query.Active then Exit(Info.Query.RecordCount);
    Exit(-1);
  end;
end;

{ ---------------- query ---------------- }

function TaFormRunner.BuildSql: string;
var
  Conds: TStringList;
  I: Integer;
  Orx, CalcCols, CalcErr: string;
begin
  Result := FDb.SourceSql(FDef.RecordSource);
  if Trim(FDef.CalcFields) <> '' then
  begin
    if CalcFieldsSql(FDb, FDef.CalcFields, CalcCols, CalcErr) then
      Result := 'SELECT *' + CalcCols + ' FROM ' + FDb.SourceFrom(FDef.RecordSource)
    else
      Notify(Tr('Calculated fields of the form: ') + CalcErr);
  end;
  Conds := TStringList.Create;
  try
    if Trim(FDef.Filter) <> '' then Conds.Add('(' + Trim(FDef.Filter) + ')');
    if FMasterField <> '' then
    begin
      if FMasterValue = '' then Conds.Add('0 = 1')
      else Conds.Add(FDb.QuoteId(FMasterField) + ' = :m');
    end;
    if (FSearch <> '') and (FFieldNames.Count > 0) then
    begin
      Orx := '';
      for I := 0 to FFieldNames.Count - 1 do
      begin
        if Orx <> '' then Orx := Orx + ' OR ';
        Orx := Orx + 'CAST(' + FDb.QuoteId(FFieldNames[I]) + ' AS TEXT) LIKE :q';
      end;
      Conds.Add('(' + Orx + ')');
    end;
    Orx := ColumnFiltersSql;
    if Orx <> '' then Conds.Add(Orx);
    Orx := FilterControlsSql;
    if Orx <> '' then Conds.Add(Orx);
    for I := 0 to Conds.Count - 1 do
    begin
      if I = 0 then Result := Result + ' WHERE ' else Result := Result + ' AND ';
      Result := Result + Conds[I];
    end;
  finally
    Conds.Free;
  end;
  if FSortField <> '' then
  begin
    Result := Result + ' ORDER BY ' + FDb.QuoteId(FSortField);
    if FSortDesc then Result := Result + ' DESC';
  end
  else if Trim(FDef.OrderBy) <> '' then Result := Result + ' ORDER BY ' + Trim(FDef.OrderBy);
end;

procedure TaFormRunner.BindParams(Q: TZQuery);
var
  I: Integer;
  N: string;
begin
  for I := 0 to Q.Params.Count - 1 do
  begin
    N := LowerCase(Q.Params[I].Name);
    if N = 'm' then Q.Params[I].AsString := FMasterValue
    else if N = 'q' then Q.Params[I].AsString := '%' + FSearch + '%';
  end;
end;

function TaFormRunner.FilterKindOf(const AField: string): TFilterKind;
var
  M: TaFieldMeta;
  F: TField;
begin
  Result := fkText;
  M := MetaFor(AField);
  if M <> nil then
  begin
    case M.LType of
      ltInteger, ltDecimal, ltCurrency, ltAutoNumber: Result := fkNumber;
      ltDate, ltDateTime: Result := fkDate;
      ltYesNo: Result := fkBool;
    end;
    Exit;
  end;
  if (FQuery <> nil) and FQuery.Active then
  begin
    F := FQuery.FindField(AField);
    if F <> nil then
      case F.DataType of
        ftSmallint, ftInteger, ftLargeint, ftWord, ftFloat, ftCurrency, ftBCD, ftFMTBcd: Result := fkNumber;
        ftDate, ftDateTime, ftTimeStamp: Result := fkDate;
        ftBoolean: Result := fkBool;
      end;
  end
  else if FKindCache.IndexOfName(AField) >= 0 then
    Result := TFilterKind(StrToIntDef(FKindCache.Values[AField], 0));
end;

function TaFormRunner.ColumnFiltersSql: string;
var
  I: Integer;
  N, Sql, Err: string;
begin
  Result := '';
  FFilterErr := '';
  for I := 0 to FColFilters.Count - 1 do
  begin
    N := FColFilters.Names[I];
    if ColumnFilterSql(FDb.QuoteId(N), FilterKindOf(N), FColFilters.ValueFromIndex[I], Sql, Err) then
    begin
      if Sql <> '' then
      begin
        if Result <> '' then Result := Result + ' AND ';
        Result := Result + '(' + Sql + ')';
      end;
    end
    else FFilterErr := N + ': ' + Err;
  end;
end;

function TaFormRunner.FilterControlsSql: string;
var
  I: Integer;
  C: TControl;
  D: TaControlDef;
  TargetField, CleanField, Val, SqlPart, Err: string;
  Conds: TStringList;
  Kind: TFilterKind;
begin
  Result := '';
  if (FAll = nil) or (FAll.Count = 0) then Exit;
  Conds := TStringList.Create;
  try
    for I := 0 to FAll.Count - 1 do
    begin
      C := TControl(FAll[I]);
      D := DefOf(C);
      if D = nil then Continue;
      TargetField := D.GetX('filterFor');
      if TargetField = '' then
      begin
        if SameText(Copy(D.Name, 1, 4), 'flt_') then
          TargetField := Copy(D.Name, 5, MaxInt);
      end;
      if TargetField = '' then Continue;

      Val := Trim(ReadControlValue(C));
      if Val = '' then Continue;

      CleanField := TargetField;
      if (Length(CleanField) > 3) and SameText(Copy(CleanField, Length(CleanField) - 2, 3), '_od') then
      begin
        CleanField := Copy(CleanField, 1, Length(CleanField) - 3);
        Kind := FilterKindOf(CleanField);
        if ColumnFilterSql(FDb.QuoteId(CleanField), Kind, '>= ' + Val, SqlPart, Err) and (SqlPart <> '') then
          Conds.Add(SqlPart);
      end
      else if (Length(CleanField) > 3) and SameText(Copy(CleanField, Length(CleanField) - 2, 3), '_do') then
      begin
        CleanField := Copy(CleanField, 1, Length(CleanField) - 3);
        Kind := FilterKindOf(CleanField);
        if ColumnFilterSql(FDb.QuoteId(CleanField), Kind, '<= ' + Val, SqlPart, Err) and (SqlPart <> '') then
          Conds.Add(SqlPart);
      end
      else
      begin
        Kind := FilterKindOf(CleanField);
        if (Kind = fkText) and (Pos('*', Val) = 0) and (Pos('?', Val) = 0) and
           (Pos('=', Val) <> 1) and (Pos('>', Val) <> 1) and (Pos('<', Val) <> 1) then
          Val := '*' + Val + '*';

        if ColumnFilterSql(FDb.QuoteId(CleanField), Kind, Val, SqlPart, Err) and (SqlPart <> '') then
          Conds.Add(SqlPart);
      end;
    end;

    for I := 0 to Conds.Count - 1 do
    begin
      if I > 0 then Result := Result + ' AND ';
      Result := Result + '(' + Conds[I] + ')';
    end;
  finally
    Conds.Free;
  end;
end;

procedure TaFormRunner.ClearFilterControls;
var
  I: Integer;
  C: TControl;
  D: TaControlDef;
begin
  if FAll = nil then Exit;
  for I := 0 to FAll.Count - 1 do
  begin
    C := TControl(FAll[I]);
    D := DefOf(C);
    if (D <> nil) and (SameText(Copy(D.Name, 1, 4), 'flt_') or (D.GetX('filterFor') <> '')) then
      WriteControlValue(C, '');
  end;
end;

procedure TaFormRunner.SetColumnFilter(const AField, AText: string);
var
  I: Integer;
begin
  I := FColFilters.IndexOfName(AField);
  if Trim(AText) = '' then
  begin
    if I >= 0 then FColFilters.Delete(I);
  end
  else FColFilters.Values[AField] := Trim(AText);
  Requery;
end;

procedure TaFormRunner.ClearColumnFilters;
begin
  FColFilters.Clear;
  Requery;
end;

procedure TaFormRunner.SortBy(const AField: string; ADesc: Boolean);
begin
  FSortField := AField;
  FSortDesc := ADesc;
  Requery;
end;

function TaFormRunner.FilterError: string;
begin
  Result := FFilterErr;
end;

function TaFormRunner.FooterText: string;
begin
  if FFooter = nil then Result := '' else Result := FFooter.Caption;
end;

type
  TControlHack = class(TControl);

{ prekrseno pravilo provjere (metapodaci polja) oboja kontrolu odmah, kao u binderu; ima prednost nad uvjetnim oblikovanjem }
procedure TaFormRunner.ApplyRuleColor(C: TControl; D: TaControlDef);
var
  M: TaFieldMeta;
  Bad: Boolean;
begin
  if (D.ControlSource = '') or (D.ControlSource[1] = '=') then Exit;
  M := MetaFor(D.ControlSource);
  if (M = nil) or (Trim(M.Validation) = '') then Exit;
  FValidating := C;
  try
    Bad := FEngine.RuleFailed(M.Validation);
  finally
    FValidating := nil;
  end;
  if Bad then
  begin
    TControlHack(StyleTarget(C)).Color := RuleBadColor;
    if FRuleColored.IndexOf(C) < 0 then FRuleColored.Add(C);
  end
  else if FRuleColored.IndexOf(C) >= 0 then
  begin
    FRuleColored.Remove(C);
    TControlHack(StyleTarget(C)).Color := HexToColor(D.GetX('backColor'), clDefault);
    if D.GetX('condFormat') <> '' then ApplyCondFormat(C, D);
  end;
end;

procedure TaFormRunner.ApplyCondFormat(C: TControl; D: TaControlDef);
var
  St: TaBindStyle;
  Fc, Bc: TColor;
  Bold: Boolean;
begin
  St := FEngine.Style(D.GetX('condFormat'));
  Fc := HexToColor(D.GetX('foreColor'), clDefault);
  Bc := HexToColor(D.GetX('backColor'), clDefault);
  Bold := D.Bold;
  if St.Matched then
  begin
    if St.Fore <> '' then Fc := HexToColor(St.Fore, Fc);
    if St.Back <> '' then Bc := HexToColor(St.Back, Bc);
    if St.Bold then Bold := True;
  end;
  with TControlHack(StyleTarget(C)) do
  begin
    Font.Color := Fc;
    Color := Bc;
    if Bold then Font.Style := Font.Style + [fsBold] else Font.Style := Font.Style - [fsBold];
  end;
end;

procedure TaFormRunner.GridRowStyle(Sender: TObject; ASelected: Boolean; var AFore, ABack: TColor; var ABold: Boolean);
var
  Rule: TCondRule;
begin
  if (FRowHost = nil) or (FQuery = nil) or not FQuery.Active or FQuery.IsEmpty then Exit;
  if ASelected then Exit;
  FRowHost.Q := FQuery;
  if MatchCondFormat(FGridRules, FRowHost, Rule) then
  begin
    if Rule.Fore <> '' then AFore := HexToColor(Rule.Fore, AFore);
    if Rule.Back <> '' then ABack := HexToColor(Rule.Back, ABack);
    if Rule.Bold then ABold := True;
  end;
end;

procedure TaFormRunner.ExportClick(Sender: TObject);
begin
  DoAction('export');
end;

procedure TaFormRunner.ExportView(const AFile: string);
var
  Q: TZQuery;
  F: string;
begin
  if FDef.RecordSource = '' then Exit;
  F := Trim(AFile);
  if F = '' then
    with TSaveDialog.Create(Self) do
    try
      Title := Tr('Export view to CSV');
      Filter := 'CSV (*.csv)|*.csv';
      DefaultExt := 'csv';
      FileName := FDef.RecordSource + '.csv';
      Options := Options + [ofOverwritePrompt];
      if Execute then F := FileName;
    finally
      Free;
    end;
  if F = '' then Exit;
  Q := FDb.NewQuery(BuildSql);
  try
    BindParams(Q);
    try
      ExportQueryCsv(FDb, Q, FDef.RecordSource, F, ';');
      Notify(Tr('Exported to ') + F + ' (' + IntToStr(Q.RecordCount) + Tr(' rows)'));
    except
      on E: Exception do Notify(Tr('Export failed: ') + E.Message);
    end;
  finally
    Q.Free;
  end;
end;

procedure TaFormRunner.DuplicateRecord;
var
  Info: TZQuery;
  Names, Vals: TStringList;
  I: Integer;
  F: TField;
  M: TaFieldMeta;
begin
  if (not FDef.AllowAdds) or (FQuery = nil) or (not FQuery.Active) or FQuery.IsEmpty then Exit;
  if FDb.LoadObject('_sys_queries', FDef.RecordSource) <> '' then
  begin
    Notify(Tr('Copying a record works only over a table, not over a query.'));
    Exit;
  end;
  Names := TStringList.Create;
  Vals := TStringList.Create;
  try
    { stupci tablice koji nisu primarni kljuc, izracunati ni zadani izrazom }
    Info := FDb.TableInfo(FDef.RecordSource);
    try
      while not Info.EOF do
      begin
        F := FQuery.FindField(Info.FieldByName('name').AsString);
        M := MetaFor(Info.FieldByName('name').AsString);
        if (F <> nil) and (Info.FieldByName('pk').AsInteger = 0) and (not F.IsNull) and
           ((M = nil) or ((M.DefaultExpr = '') and (M.LType <> ltAutoNumber))) then
        begin
          Names.Add(F.FieldName);
          Vals.Add(FieldStored(F));
        end;
        Info.Next;
      end;
    finally
      Info.Free;
    end;
    FQuery.Append;
    for I := 0 to Names.Count - 1 do
    begin
      F := FQuery.FieldByName(Names[I]);
      if F.DataType in [ftFloat, ftCurrency, ftBCD, ftFMTBcd, ftSingle] then F.AsFloat := StrToFloatDef(Vals[I], 0, InvariantFS)
      else if F.DataType in [ftSmallint, ftInteger, ftLargeint, ftWord] then F.AsLargeInt := StrToInt64Def(Vals[I], 0)
      else F.AsString := Vals[I];
    end;
    LoadRecord;
    ApplyDefaults;
    MarkDirty;
  finally
    Names.Free;
    Vals.Free;
  end;
end;

procedure TaFormRunner.ConfigureSubDatasheet;
var
  Spec, ParentCol: string;
  P: TStringList;
  Rels: TaRelations;
  I: Integer;
begin
  FSubChild := '';
  FSubLink := '';
  if (FView = nil) or (FView.Own = nil) or (Trim(FDef.SubDatasheet) = '') then Exit;
  Spec := Trim(FDef.SubDatasheet);
  ParentCol := '';
  if SameText(Spec, 'auto') then
  begin
    Rels := FDb.AllRelations;
    for I := 0 to High(Rels) do
      if SameText(Rels[I].Parent, FDef.RecordSource) then
      begin
        FSubChild := Rels[I].Child;
        FSubLink := Rels[I].ChildCol;
        ParentCol := Rels[I].ParentCol;
        Break;
      end;
  end
  else
  begin
    P := TStringList.Create;
    try
      P.Delimiter := '|';
      P.StrictDelimiter := True;
      P.DelimitedText := Spec;
      if P.Count >= 1 then FSubChild := Trim(P[0]);
      if P.Count >= 2 then FSubLink := Trim(P[1]);
      if P.Count >= 3 then ParentCol := Trim(P[2]);
    finally
      P.Free;
    end;
  end;
  if (FSubChild = '') or (FSubLink = '') then Exit;
  if ParentCol = '' then ParentCol := 'id';
  FSubSheets := TStringList.Create;
  FView.Own.SubKeyField := ParentCol;
  FView.Own.OnSubOpen := @SubSheetOpen;
  FView.Own.OnSubClose := @SubSheetClose;
end;

procedure TaFormRunner.SubSheetOpen(Sender: TObject; const AKey: string; AChild: TaOwnGrid);
var
  SH: TaSubSheet;
begin
  SH := TaSubSheet.Create;
  SH.Key := AKey;
  SH.LinkCol := FSubLink;
  SH.Holder := TFPObjectList.Create(True);
  SH.Query := FDb.NewQuery('SELECT * FROM ' + FDb.SourceFrom(FSubChild) + ' WHERE ' + FDb.QuoteId(FSubLink) + ' = :v');
  SH.Query.ParamByName('v').AsString := AKey;
  SH.Query.Open;
  SH.Source := TDataSource.Create(nil);
  SH.Source.DataSet := SH.Query;
  SH.View := TaGridView.Wrap(AChild);
  AChild.DataSource := SH.Source;
  AChild.AllowEdit := FDef.AllowEdits;
  AChild.ReadOnly := not FDef.AllowEdits;
  AttachGridExtras(SH.Query, SH.View, FSubChild, FSubLink, '', '', SH.Holder);
  if FDb.LoadObject('_sys_queries', FSubChild) = '' then
    SH.Formatter := TaDatasetFormatter.Create(SH.Query, FDb.LoadFieldMetas(FSubChild));
  SH.Query.OnNewRecord := @SH.NewRecord;
  FSubSheets.AddObject(AKey, SH);
end;

procedure TaFormRunner.SubSheetClose(Sender: TObject; const AKey: string; AChild: TaOwnGrid);
var
  I: Integer;
begin
  if FSubSheets = nil then Exit;
  I := FSubSheets.IndexOf(AKey);
  if I < 0 then Exit;
  AChild.DataSource := nil;
  TaSubSheet(FSubSheets.Objects[I]).Free;
  FSubSheets.Delete(I);
end;

procedure TaFormRunner.GridTitleClick(Sender: TObject; const AFieldName: string);
begin
  if AFieldName = '' then Exit;
  if SameText(FSortField, AFieldName) then
  begin
    if not FSortDesc then FSortDesc := True
    else begin FSortField := ''; FSortDesc := False; end;
  end
  else
  begin
    FSortField := AFieldName;
    FSortDesc := False;
  end;
  Requery;
end;

procedure TaFormRunner.UpdateSortMarks;
begin
  if FView = nil then Exit;
  FView.ApplySort(FSortField, FSortDesc);
end;

procedure TaFormRunner.UpdateFooter;
var
  Sums: TStringList;
  I: Integer;
  F: TField;
  M: TaFieldMeta;
  Q: TZQuery;
  Sel, Txt: string;
  Num: Boolean;
begin
  if FFooter = nil then Exit;
  Sums := TStringList.Create;
  try
    if (FQuery <> nil) and FQuery.Active then
      for I := 0 to FQuery.FieldCount - 1 do
      begin
        F := FQuery.Fields[I];
        M := MetaFor(F.FieldName);
        if M <> nil then
          Num := (M.LType in [ltDecimal, ltCurrency]) or
                 ((M.LType = ltInteger) and (LowerCase(F.FieldName) <> 'id') and (Copy(LowerCase(F.FieldName), Length(F.FieldName) - 2, 3) <> '_id'))
        else
          Num := F.DataType in [ftFloat, ftCurrency, ftBCD, ftFMTBcd];
        if Num and (Sums.Count < 4) then Sums.Add(F.FieldName);
      end;
    Sel := 'COUNT(*)';
    for I := 0 to Sums.Count - 1 do Sel := Sel + ', SUM(' + FDb.QuoteId(Sums[I]) + ')';
    Txt := '';
    try
      Q := FDb.NewQuery('SELECT ' + Sel + ' FROM (' + BuildSql + ') AS _q');
      try
        BindParams(Q);
        Q.Open;
        Txt := 'Zapisa: ' + Q.Fields[0].AsString;
        for I := 0 to Sums.Count - 1 do
          if not Q.Fields[I + 1].IsNull then
            Txt := Txt + Tr('   |   Sum ') + Sums[I] + ': ' + FormatFloat('#,##0.00', Q.Fields[I + 1].AsFloat);
      finally
        Q.Free;
      end;
    except
      on E: Exception do Txt := 'Zapisa: ?';
    end;
    if FColFilters.Count > 0 then
    begin
      Txt := Txt + '   |   Filtri: ';
      for I := 0 to FColFilters.Count - 1 do
      begin
        if I > 0 then Txt := Txt + ', ';
        Txt := Txt + FColFilters.Names[I] + ' ' + FColFilters.ValueFromIndex[I];
      end;
    end;
    if FFilterErr <> '' then Txt := Txt + Tr('   |   Filter error: ') + FFilterErr;
    FFooter.Caption := Txt;
  finally
    Sums.Free;
  end;
end;

procedure TaFormRunner.FiltersClick(Sender: TObject);
var
  Names, Caps: TStringList;
  Kinds: array of TFilterKind;
  I, N: Integer;
  Work: TStringList;
  C: string;
begin
  if (FView = nil) or (FQuery = nil) or not FQuery.Active then Exit;
  Names := TStringList.Create;
  Caps := TStringList.Create;
  Work := TStringList.Create;
  try
    N := 0;
    for I := 0 to FView.ColCount - 1 do
      if FView.ColVisible(I) and (FView.ColFieldName(I) <> '') then
      begin
        C := StripSortMark(FView.ColTitle(I));
        Names.Add(FView.ColFieldName(I));
        Caps.Add(C);
        SetLength(Kinds, N + 1);
        Kinds[N] := FilterKindOf(FView.ColFieldName(I));
        Inc(N);
      end;
    Work.Assign(FColFilters);
    if RunColumnFilters(Self, Names, Caps, Kinds, Work, FDb, FDef.Name) then
    begin
      FColFilters.Clear;
      for I := 0 to Names.Count - 1 do
        if Work.Values[Names[I]] <> '' then FColFilters.Values[Names[I]] := Work.Values[Names[I]];
      Requery;
      if FFilterErr <> '' then Notify(Tr('Filter: ') + FFilterErr);
    end;
  finally
    Names.Free; Caps.Free; Work.Free;
  end;
end;

procedure TaFormRunner.OpenQuery;
var
  I: Integer;
  N: string;
begin
  if FQuery = nil then FQuery := FDb.NewQuery('');
  FQuery.Close;
  FQuery.SQL.Text := BuildSql;
  BindParams(FQuery);
  FreeAndNil(FFormatter);
  FQuery.Open;
  if (FView <> nil) and (FDb.LoadObject('_sys_queries', FDef.RecordSource) = '') then
    FFormatter := TaDatasetFormatter.Create(FQuery, FDb.LoadFieldMetas(FDef.RecordSource));
  if FGridSource <> nil then
  begin
    FGridSource.DataSet := FQuery;
    AttachGridExtras(FQuery, FView, FDef.RecordSource, FMasterField, FDef.AutoFill, FDef.CalcFields, FGridHolder, FDef.CalcRules);
  end;
  if FFieldNames.Count = 0 then
    for I := 0 to FQuery.FieldCount - 1 do FFieldNames.Add(FQuery.Fields[I].FieldName);
  FKindCache.Clear;
  for I := 0 to FQuery.FieldCount - 1 do
    FKindCache.Values[FQuery.Fields[I].FieldName] := IntToStr(Ord(FilterKindOf(FQuery.Fields[I].FieldName)));
  UpdateSortMarks;
  UpdateFooter;
end;

procedure TaFormRunner.Requery;
begin
  if FTimeBody <> nil then begin FTimeBody.Reload; Exit; end;
  if FDashBody <> nil then begin FDashBody.Reload; Exit; end;
  if FBoard <> nil then begin FBoard.Reload; Exit; end;
  if FCont <> nil then begin FCont.Host.Reload; FCont.RefreshFooter; Exit; end;
  if FDef.RecordSource = '' then Exit;
  SaveRecord;
  OpenQuery;
  LoadRecord;
  FireEvent('AfterQuery');
end;

procedure TaFormRunner.Search(const AText: string);
begin
  FSearch := Trim(AText);
  if FSearchEdit <> nil then FSearchEdit.Text := FSearch;
  Requery;
end;

procedure TaFormRunner.SetMaster(const AField, AValue: string);
begin
  if FCont <> nil then
  begin
    FMasterField := AField;
    FMasterValue := AValue;
    FCont.SetMaster(AField, AValue);
    Exit;
  end;
  if (FMasterField = AField) and (FMasterValue = AValue) and (FQuery <> nil) and FQuery.Active then Exit;
  if FQuery <> nil then SaveRecord;
  FMasterField := AField;
  FMasterValue := AValue;
  if FDef.RecordSource <> '' then
  begin
    OpenQuery;
    LoadRecord;
  end;
end;

procedure TaFormRunner.SearchClick(Sender: TObject);
begin
  if TButton(Sender).Tag = 1 then FSearch := Trim(FSearchEdit.Text)
  else
  begin
    FSearch := '';
    FSearchEdit.Text := '';
  end;
  Requery;
end;

procedure TaFormRunner.SearchKey(Sender: TObject; var Key: Char);
begin
  if Key = #13 then
  begin
    Key := #0;
    FSearch := Trim(FSearchEdit.Text);
    Requery;
  end;
end;

{ ---------------- values ---------------- }

function TaFormRunner.IsCalcName(const AName: string): Boolean;
var
  L: TStringList;
begin
  Result := False;
  if Trim(FDef.CalcFields) = '' then Exit;
  L := CalcFieldNames(FDef.CalcFields);
  try
    Result := L.IndexOf(AName) >= 0;
  finally
    L.Free;
  end;
end;

function TaFormRunner.MetaFor(const AField: string): TaFieldMeta;
var
  I: Integer;
begin
  for I := 0 to FMetas.Count - 1 do
    if SameText(TaFieldMeta(FMetas[I]).FieldName, AField) then Exit(TaFieldMeta(FMetas[I]));
  Result := nil;
end;

function TaFormRunner.FieldVariant(F: TField): Variant;
var
  M: TaFieldMeta;
begin
  if F.IsNull then Exit(Null);
  M := MetaFor(F.FieldName);
  if F.DataType in [ftSmallint, ftInteger, ftLargeint, ftWord, ftAutoInc] then
  begin
    if (M <> nil) and (M.LType = ltYesNo) then Exit(F.AsInteger <> 0);
    Exit(F.AsLargeInt);
  end;
  if F.DataType in [ftFloat, ftCurrency, ftBCD, ftFMTBcd, ftSingle] then Exit(F.AsFloat);
  if F.DataType = ftBoolean then Exit(F.AsBoolean);
  Result := F.AsString;
end;

function TaFormRunner.ControlVariant(C: TControl): Variant;
var
  S, Stored: string;
  M: TaFieldMeta;
  V: Double;
  I: Integer;
begin
  if IsCalculated(C) then
  begin
    I := FCalc.IndexOf(C);
    if I >= 0 then Exit(FCalcVals[I]);
    Exit(Null);
  end;
  S := ReadControlValue(C);
  if IsCheckLike(C) then Exit(S = '1');
  if S = '' then Exit(Null);
  if HasKeys(C) then
  begin
    if ParseNumber(S, V) then Exit(V);
    Exit(S);
  end;
  M := nil;
  if DefOf(C).ControlSource <> '' then M := MetaFor(DefOf(C).ControlSource);
  if M <> nil then
  begin
    if not DisplayToStored(M, S, Stored) then Exit(S);
    case M.LType of
      ltInteger, ltAutoNumber, ltDecimal, ltCurrency:
        if ParseNumber(Stored, V) then Exit(V);
      ltYesNo: Exit(Stored = '1');
    end;
    Exit(Stored);
  end;
  if ParseNumber(S, V) then Exit(V);
  Result := S;
end;

function TaFormRunner.ValueOf(const AName: string): Variant;
var
  C: TControl;
  F: TField;
  I: Integer;
begin
  Result := Null;
  if SameText(AName, 'value') and (FValidating <> nil) then Exit(ControlVariant(FValidating));
  C := FindControl(AName);
  if C <> nil then Exit(ControlVariant(C));
  { [field] means the control bound to that field, so unsaved edits are visible }
  for I := 0 to FBound.Count - 1 do
    if SameText(DefOf(TControl(FBound[I])).ControlSource, AName) then Exit(ControlVariant(TControl(FBound[I])));
  if (FQuery <> nil) and FQuery.Active and not FQuery.IsEmpty then
  begin
    F := FQuery.FindField(AName);
    if F <> nil then Exit(FieldVariant(F));
  end;
end;

function TaFormRunner.AggregateOf(const AFunc, AField: string): Variant;
var
  Fn: string;
begin
  { over the whole record source, ignoring the form's filter }
  Fn := UpperCase(AFunc);
  if AField = '*' then Result := DbDomain(FDb, 'dcount', '*', FDef.RecordSource, '')
  else Result := DbDomain(FDb, 'd' + LowerCase(Fn), FDb.QuoteId(AField), FDef.RecordSource, '');
end;

{ ---------------- loading and saving ---------------- }

procedure TaFormRunner.LoadDisplayOnly;
var
  I: Integer;
  C: TControl;
  F: TField;
  D: TaControlDef;
  Raw: string;
  Pic: TPicture;
begin
  for I := 0 to FDisplay.Count - 1 do
  begin
    C := TControl(FDisplay[I]);
    D := DefOf(C);
    F := nil;
    if (FQuery <> nil) and FQuery.Active and not FQuery.IsEmpty then F := FQuery.FindField(D.ControlSource);
    if FamilyKindOf(C) = 'Barcode' then
    begin
      Raw := '';
      if (D.ControlSource <> '') and (D.ControlSource[1] = '=') then
        Raw := FormatValue(EvalExpr(Copy(D.ControlSource, 2, MaxInt), FHost), '')
      else if F <> nil then Raw := F.AsString;
      if Raw <> FamilyBarcodeValue(C) then FamilySetBarcode(C, Raw);
    end
    else if FamilyKindOf(C) = 'Image' then
    begin
      Pic := TPicture.Create;
      try
        if (F <> nil) and not F.IsNull then
        begin
          if F.DataType in [ftBlob, ftGraphic, ftVarBytes, ftBytes] then LoadPictureFromBytes(Pic, F.AsString)
          else
          begin
            Raw := ResolveFileLink(FDb, F.AsString);
            if (Raw <> '') and FileExists(Raw) then
              try Pic.LoadFromFile(Raw); except end;
          end;
        end;
        if (Pic.Graphic <> nil) and not Pic.Graphic.Empty then FamilySetPicture(C, Pic) else FamilySetPicture(C, nil);
      finally
        Pic.Free;
      end;
    end
    else if C is TaBarcode then
    begin
      Raw := '';
      if (D.ControlSource <> '') and (D.ControlSource[1] = '=') then
        Raw := FormatValue(EvalExpr(Copy(D.ControlSource, 2, MaxInt), FHost), '')
      else if F <> nil then Raw := F.AsString;
      if Raw <> TaBarcode(C).Value then begin TaBarcode(C).Value := Raw; C.Invalidate; end;
    end
    else if C is TaFamilyHost then
    begin
      { poveznica obitelji Label: natpis i adresa iz polja }
      if F = nil then Raw := '' else Raw := F.AsString;
      if (D.Caption = '') or (D.Caption = D.Name) then FamilySetCaption(C, Raw);
      if D.RowSource = '' then FamilySetAddress(C, Raw);
    end
    else if C is TaHyperlink then
    begin
      if F = nil then Raw := '' else Raw := F.AsString;
      if (D.Caption = '') or (D.Caption = D.Name) then C.Caption := Raw;
      if D.RowSource = '' then TaHyperlink(C).Address := Raw;
    end
    else if C is TaImage then
    begin
      TaImage(C).Picture.Clear;
      if F = nil then Continue;
      Pic := TPicture.Create;
      try
        if F.IsNull then Continue;
        if F.DataType in [ftBlob, ftGraphic, ftVarBytes, ftBytes] then
        begin
          if LoadPictureFromBytes(Pic, F.AsString) then TaImage(C).Picture.Assign(Pic);
        end
        else
        begin
          Raw := ResolveFileLink(FDb, F.AsString);
          if (Raw <> '') and FileExists(Raw) then
            try
              Pic.LoadFromFile(Raw);
              TaImage(C).Picture.Assign(Pic);
            except
            end;
        end;
      finally
        Pic.Free;
      end;
    end;
  end;
end;

procedure TaFormRunner.LoadRecord;
var
  I: Integer;
  C: TControl;
  F: TField;
  S: string;
begin
  FLoading := True;
  try
    for I := 0 to FBound.Count - 1 do
    begin
      C := TControl(FBound[I]);
      F := nil;
      if (FQuery <> nil) and FQuery.Active and not FQuery.IsEmpty then
        F := FQuery.FindField(DefOf(C).ControlSource);
      if F = nil then S := ''
      else
      begin
        S := FieldStored(F);
        if not (IsCheckLike(C) or HasKeys(C)) then
          S := StoredToDisplay(MetaFor(F.FieldName), S);
      end;
      WriteControlValue(C, S);
    end;
  finally
    FLoading := False;
  end;
  FDirty := False;
  LoadDisplayOnly;
  if (FQuery <> nil) and FQuery.Active then RefreshSubs;
  RefreshDynamic;
  RefreshCharts;
  RecalcAll;
  UpdateNav;
  if not (FBuilding or FOpening) then
  begin
    FInCurrent := True;
    try
      FireEvent('OnCurrent');
    finally
      FInCurrent := False;
    end;
  end;
end;

procedure TaFormRunner.MarkDirty;
begin
  FDirty := True;
  UpdateNav;
end;

function TaFormRunner.RecordState: TaRecordState;
begin
  if FQueryMode then Exit(rsQuery);
  if (FQuery <> nil) and FQuery.Active and (FQuery.State = dsInsert) then Exit(rsNew);
  if FDirty then Exit(rsChanged);
  Result := rsSaved;
end;

function TaFormRunner.StateText: string;
begin
  case RecordState of
    rsQuery: Result := 'upit';
    rsNew: Result := 'novi';
    rsChanged: Result := 'promijenjen';
  else
    Result := 'spremljen';
  end;
end;

procedure TaFormRunner.UpdateNav;
begin
  if FPos = nil then Exit;
  if (FQuery = nil) or not FQuery.Active then begin FPos.Caption := ''; Exit; end;
  if FQueryMode then FPos.Caption := Tr('Query: enter patterns, F8 runs, Esc cancels')
  else if FQuery.State = dsInsert then FPos.Caption := Tr('New record')
  else
  begin
    FPos.Caption := Format(Tr('Record %d / %d'), [FQuery.RecNo, FQuery.RecordCount]);
    if FDirty then FPos.Caption := FPos.Caption + Tr(' - changed');
  end;
  FNavButtons[4].Enabled := FDef.AllowAdds and not FQueryMode;
  FNavButtons[5].Enabled := FDef.AllowDeletes and not FQueryMode;
  FNavButtons[6].Enabled := (FDef.AllowEdits or (FQuery.State = dsInsert)) and not FQueryMode;
  FNavButtons[7].Enabled := not FQueryMode;
  FNavButtons[8].Enabled := FQueryMode;
end;

procedure TaFormRunner.RecalcAll;
var
  Pass, I: Integer;
  Ok, Vb: Boolean;
  CalcText: string;
  C: TControl;
  D: TaControlDef;
  V: Variant;
  Err, Cond: string;
begin
  if FBuilding or (FHost = nil) then Exit;
  FLoading := True;
  try
    for Pass := 1 to 2 do
      for I := 0 to FCalc.Count - 1 do
      begin
        C := TControl(FCalc[I]);
        D := DefOf(C);
        CalcText := FEngine.Display(Copy(D.ControlSource, 2, MaxInt), D.Format, V);
        FCalcVals[I] := V;
        if C is TEdit then TEdit(C).Text := CalcText
        else if C is TLabel then C.Caption := CalcText
        else if C is TCheckBox then TCheckBox(C).Checked := ExprIsTrue(V)
        else if C is TaFamilyHost then
        begin
          if IsCheckLike(C) then begin if ExprIsTrue(V) then WriteControlValue(C, '1') else WriteControlValue(C, '0'); end
          else FamilySetText(C, CalcText);
        end;
      end;
    for I := 0 to FAll.Count - 1 do
    begin
      C := TControl(FAll[I]);
      D := DefOf(C);
      Cond := D.GetX('visibleIf');
      if Cond <> '' then
      begin
        Vb := FEngine.Condition(Cond, Ok);
        if Ok then C.Visible := Vb and not FamilyPageHidden(C);
      end;
      Cond := D.GetX('enabledIf');
      if Cond <> '' then
      begin
        Vb := FEngine.Condition(Cond, Ok);
        if Ok then C.Enabled := Vb;
      end;
      if D.GetX('condFormat') <> '' then ApplyCondFormat(C, D);
      ApplyRuleColor(C, D);
    end;
  finally
    FLoading := False;
  end;
end;

{ AutoFill i CalcRules u formi s jednim zapisom: pokrece ih promjena kontrole vezane uz polje-okidac }
procedure TaFormRunner.ApplyFormRules(C: TControl);
var
  D: TaControlDef;
  Fld, Stored: string;
  I, J: Integer;
  R: TaCalcRule;
  V: Variant;
  St: TStringList;
  RDef: TaCalcRuleDef;
  RIsNum: Boolean;
begin
  if FRulesBusy or (FView <> nil) then Exit;
  if (FFormRules = nil) and (FFormAutoFill = nil) then Exit;
  D := DefOf(C);
  if D = nil then Exit;
  Fld := LowerCase(D.ControlSource);
  if (Fld = '') or (Fld[1] = '=') then Exit;
  FRulesBusy := True;
  try
    { AutoFill: field>table.key:target=source,... (parser i upit u ta_bindengine) }
    if FFormAutoFill <> nil then
      for I := 0 to High(FFormAutoDefs) do
      begin
        if LowerCase(FFormAutoDefs[I].Field) <> Fld then Continue;
        V := ValueOf(Fld);
        if VarIsNull(V) or VarIsEmpty(V) or (VarToStr(V) = '') then Continue;
        St := TStringList.Create;
        try
          if AutoFillLookup(FDb, FFormAutoDefs[I], VarToStr(V), St) then
            for J := 0 to High(FFormAutoDefs[I].Targets) do
              ScriptSet(FFormAutoDefs[I].Targets[J], StoredToDisplay(MetaFor(FFormAutoDefs[I].Targets[J]), St.ValueFromIndex[J]));
        finally
          St.Free;
        end;
      end;
    { CalcRules }
    if FFormRules <> nil then
      for I := 0 to FFormRules.Count - 1 do
      begin
        R := TaCalcRule(FFormRules[I]);
        if R.Triggers.IndexOf(Fld) < 0 then Continue;
        try
          RDef.Target := R.Target;
          RDef.Expr := R.Expr;
          if not FEngine.CalcRuleStored(RDef, Stored, RIsNum) then Continue;
          if RIsNum then ScriptSet(R.Target, StoredToDisplay(MetaFor(R.Target), Stored))
          else ScriptSet(R.Target, Stored);
        except
        end;
      end;
  finally
    FRulesBusy := False;
  end;
end;

procedure TaFormRunner.ControlChanged(Sender: TObject);
begin
  if FLoading or FBuilding then Exit;
  { u nacinu upita polja primaju uzorke: nista se ne racuna, ne pokrecu se pravila i forma nije "promijenjena" }
  if FQueryMode then Exit;
  MarkDirty;
  if FDynamic.Count > 0 then RefreshDynamic;
  RecalcAll;
  if Sender is TControl then ApplyFormRules(TControl(Sender));
  if (Sender is TControl) and (DefOf(TControl(Sender)) <> nil) then
    RunProcName(DefOf(TControl(Sender)).GetX('onChange'));
end;

procedure TaFormRunner.RunProcName(const AProc: string);
var
  R: Variant;
begin
  if Trim(AProc) = '' then Exit;
  if LowerCase(Copy(Trim(AProc), 1, 6)) = 'macro:' then
    RunMacroByName(FContext, Trim(Copy(Trim(AProc), 7, MaxInt)))
  else
    Scripts(FDb).CallProc(FContext, Trim(AProc), [], R);
end;

{ okidaci kontrole (OnEnter, OnExit, OnValidate, OnKey): izvrsava makro ili proceduru; True kad je pozvan CancelEvent.
  Skripta vidi varijable eventControl (naziv kontrole), eventValue (trenutna vrijednost) i eventKey (naziv tipke za OnKey). }
function TaFormRunner.FireControlEvent(C: TControl; const AKey: string): Boolean;
var
  D: TaControlDef;
  Proc: string;
begin
  Result := False;
  D := DefOf(C);
  if D = nil then Exit;
  Proc := EffectiveEvent(D, FDef, AKey);
  if Proc = '' then Exit;
  FContext.SetVar('eventControl', D.Name);
  FContext.SetVar('eventValue', ReadControlValue(C));
  FContext.Cancelled := False;
  RunProcName(Proc);
  Result := FContext.Cancelled;
  FContext.Cancelled := False;
end;

type
  TWinCrack = class(TWinControl)
  public
    property OnEnter;
    property OnExit;
    property OnKeyDown;
  end;

procedure TaFormRunner.AttachControlEvents(C: TControl; D: TaControlDef);
begin
  if not (C is TWinControl) then Exit;
  if (EffectiveEvent(D, FDef, 'onEnter') <> '') then TWinCrack(C).OnEnter := @ControlEnter;
  if (EffectiveEvent(D, FDef, 'onExit') <> '') or (EffectiveEvent(D, FDef, 'onValidate') <> '') then TWinCrack(C).OnExit := @ControlExit;
  if EffectiveEvent(D, FDef, 'onKey') <> '' then
  begin
    if C is TaFamilyHost then TaFamilyHost(C).OnInnerKeyDown := @ControlKeyDown
    else TWinCrack(C).OnKeyDown := @ControlKeyDown;
  end;
end;

procedure TaFormRunner.ControlEnter(Sender: TObject);
begin
  if FLoading or FBuilding then Exit;
  FireControlEvent(HostOf(TControl(Sender)), 'onEnter');
end;

procedure TaFormRunner.ControlExit(Sender: TObject);
var
  C: TControl;
begin
  if FLoading or FBuilding then Exit;
  C := HostOf(TControl(Sender));
  { odbijena vrijednost ili izlaz zadrzava fokus na kontroli }
  if FireControlEvent(C, 'onValidate') or FireControlEvent(C, 'onExit') then
  begin
    FRefocus := C;
    Application.QueueAsyncCall(@RefocusAsync, 0);
  end;
end;

procedure TaFormRunner.RefocusAsync(Data: PtrInt);
var
  C: TControl;
begin
  C := FRefocus;
  FRefocus := nil;
  if (C <> nil) and (FAll.IndexOf(C) >= 0) and (C is TWinControl) and TWinControl(C).CanFocus then
    try TWinControl(C).SetFocus; except end;
end;

procedure TaFormRunner.ControlKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  C: TControl;
begin
  C := HostOf(TControl(Sender));
  FContext.SetVar('eventKey', IntToStr(Key));
  if FireControlEvent(C, 'onKey') then Key := 0;
end;

{ OnError (forma): skripta dobiva eventMessage; CancelEvent = poruku je vec prikazala sama, pa nema standardne;
  inace se prikazuje eventMessage koji skripta smije promijeniti }
function TaFormRunner.ErrorText(const AMessage: string; out ASilent: Boolean): string;
begin
  Result := AMessage;
  ASilent := False;
  if FDef.GetEv('OnError') = '' then Exit;
  FContext.SetVar('eventMessage', AMessage);
  if FireEvent('OnError') then ASilent := True
  else if FContext.HasVar('eventMessage') then Result := VarToStr(FContext.GetVar('eventMessage'));
end;

{ Fires a form event; returns True when the script called CancelEvent. }
function TaFormRunner.FireEvent(const AKey: string): Boolean;
var
  Proc: string;
begin
  Result := False;
  Proc := FDef.GetEv(AKey);
  if Proc = '' then Exit;
  FContext.Cancelled := False;
  RunProcName(Proc);
  Result := FContext.Cancelled;
  FContext.Cancelled := False;
end;

procedure TaFormRunner.ControlDblClick(Sender: TObject);
var
  D: TaControlDef;
begin
  D := DefOf(TControl(Sender));
  if D <> nil then RunProcName(D.GetX('onDblClick'));
end;

function TaFormRunner.ValueText(const AName: string): string;
var
  C: TControl;
  F: TField;
  I: Integer;
begin
  Result := '';
  C := FindControl(AName);
  if C = nil then
    for I := 0 to FBound.Count - 1 do
      if SameText(DefOf(TControl(FBound[I])).ControlSource, AName) then C := TControl(FBound[I]);
  if C <> nil then
  begin
    if IsCalculated(C) then
    begin
      if C is TEdit then Exit(TEdit(C).Text);
      if IsPlainEdit(C) then Exit(ReadControlValue(C));
      Exit(C.Caption);
    end;
    if (C is TEdit) or IsPlainEdit(C) or IsBoundControl(C) then Exit(ReadControlValue(C));
    Exit(C.Caption);
  end;
  if (FQuery <> nil) and FQuery.Active and not FQuery.IsEmpty then
  begin
    F := FQuery.FindField(AName);
    if F <> nil then Result := StoredToDisplay(MetaFor(F.FieldName), FieldStored(F));
  end;
end;

procedure TaFormRunner.ScriptSet(const AName, AValue: string);
var
  C: TControl;
  F: TField;
  I: Integer;
  Conv: string;
begin
  C := FindControl(AName);
  if C = nil then
    for I := 0 to FBound.Count - 1 do
      if SameText(DefOf(TControl(FBound[I])).ControlSource, AName) then C := TControl(FBound[I]);
  if (C <> nil) and not IsCalculated(C) then
  begin
    FLoading := True;
    try
      if (C is TEdit) or IsPlainEdit(C) or IsBoundControl(C) then WriteControlValue(C, AValue)
      else C.Caption := AValue;
    finally
      FLoading := False;
    end;
    if IsBoundControl(C) and not FInCurrent then MarkDirty;
    RecalcAll;
    Exit;
  end;
  if (FQuery <> nil) and FQuery.Active then
  begin
    F := FQuery.FindField(AName);
    if F = nil then Exit;
    if not DisplayToStored(MetaFor(F.FieldName), AValue, Conv) then Conv := AValue;
    if not (FQuery.State in [dsEdit, dsInsert]) then FQuery.Edit;
    SetFieldStored(F, Conv);
    if not FInCurrent then MarkDirty;
  end;
end;

function TaFormRunner.SaveRecord: Boolean;
var
  I: Integer;
  C: TControl;
  F: TField;
  S: string;
  Vals: TStringList;
  Conv: string;
  M: TaFieldMeta;
  VFailed: Boolean;
  Msg: string;
  Ins, Silent: Boolean;
begin
  Result := True;
  { embedded forms first }
  for I := 0 to FSubs.Count - 1 do
    if TaSubInfo(FSubs[I]).Embedded <> nil then
      if not TaSubInfo(FSubs[I]).Embedded.SaveRecord then Exit(False);
  if (FQuery = nil) or not FQuery.Active then Exit;
  if FDef.ViewMode = 'datasheet' then
  begin
    { the grid edits the dataset itself; leaving a row just posts it }
    if FQuery.State in [dsEdit, dsInsert] then
      try
        FQuery.Post;
      except
        on E: Exception do begin Notify(Tr('Saving failed: ') + E.Message); Result := False; end;
      end;
    Exit;
  end;
  try
    if FQuery.State in [dsEdit, dsInsert] then
    begin
      if not FDirty then begin FQuery.Cancel; Exit; end;
    end
    else
    begin
      if not FDirty then Exit;
      if not FDef.AllowEdits then Exit;
    end;
    { convert and validate everything first, so a bad value leaves the record untouched }
    Vals := TStringList.Create;
    try
      for I := 0 to FBound.Count - 1 do
      begin
        C := TControl(FBound[I]);
        F := FQuery.FindField(DefOf(C).ControlSource);
        S := ReadControlValue(C);
        if (F <> nil) and not (IsCheckLike(C) or HasKeys(C)) then
        begin
          M := MetaFor(F.FieldName);
          if not DisplayToStored(M, S, Conv) then
            raise Exception.Create(Tr('Invalid value in field ') + F.FieldName);
          S := Conv;
        end;
        Vals.Add(S);
        if (S <> '') and (DefOf(C).GetX('lovvalidate') = '1') then
        begin
          Msg := LovValidate(C, S);
          if Msg <> '' then raise Exception.Create(Msg);
        end;
        { obavezno polje (rjecnik podataka) blokira spremanje }
        if F <> nil then
        begin
          M := MetaFor(F.FieldName);
          if DictRequired(M) and (Trim(S) = '') and not IsCheckLike(C) then
            raise Exception.Create(RequiredMessage(F.FieldName, M.Caption));
        end;
        { maska unosa: nepotpun unos (npr. OIB s 9 znamenki) ne moze se spremiti }
        if (DefOf(C).GetX('mask') <> '') and (Trim(S) <> '') and not MaskComplete(DefOf(C).GetX('mask'), S) then
          raise Exception.Create(Tr('%s: the value does not match the format %s', [DefOf(C).Name, DefOf(C).GetX('mask')]));
        { OnValidate kontrole (okidac): CancelEvent odbija zapis }
        if (EffectiveEvent(DefOf(C), FDef, 'onValidate') <> '') and FireControlEvent(C, 'onValidate') then
          raise Exception.Create(Tr('%s: value rejected', [DefOf(C).Name]));
        { validation rule }
        if F <> nil then
        begin
          M := MetaFor(F.FieldName);
          if (M <> nil) and (Trim(M.Validation) <> '') and (S <> '') then
          begin
            FValidating := C;
            try
              VFailed := FEngine.RuleFailed(M.Validation);
            finally
              FValidating := nil;
            end;
            if VFailed then
            begin
              Msg := M.ValidationMsg;
              if Msg = '' then Msg := 'Vrijednost ne zadovoljava pravilo: ' + M.Validation;
              raise Exception.Create(F.FieldName + ': ' + Msg);
            end;
          end;
        end;
      end;
      Ins := FQuery.State = dsInsert;
      if Ins and FireEvent('BeforeInsert') then
      begin
        Result := False;
        Exit;
      end;
      if FireEvent('BeforeUpdate') then
      begin
        { cancelled by the script: nothing is written and the record stays as typed }
        Result := False;
        Exit;
      end;
      if not (FQuery.State in [dsEdit, dsInsert]) then FQuery.Edit;
      for I := 0 to FBound.Count - 1 do
      begin
        F := FQuery.FindField(DefOf(TControl(FBound[I])).ControlSource);
        if (F = nil) or F.ReadOnly or IsCalcName(DefOf(TControl(FBound[I])).ControlSource) then Continue;
        SetFieldStored(F, Vals[I]);
      end;
    finally
      Vals.Free;
    end;
    if (FDocCode <> '') and (FQuery.State = dsInsert) then CommitDocNumber;
    ApplyAutoEnter(FQuery.State = dsInsert);
    FQuery.Post;
    if FAutoTx then begin FDb.Conn.Commit; FAutoTx := False; end;
    FDirty := False;
    if Ins then FireEvent('AfterInsert');
    FireEvent('AfterUpdate');
  except
    on E: Exception do
    begin
      { neuspjelo spremanje ne trosi broj racuna: brojac se vraca zajedno sa zapisom }
      if FAutoTx then
      begin
        try FDb.Conn.Rollback; except end;
        FAutoTx := False;
      end;
      Msg := ErrorText(E.Message, Silent);
      if not Silent then Notify(Tr('Saving failed: ') + Msg);
      Result := False;
    end;
  end;
end;

procedure TaFormRunner.Scrolled(DataSet: TDataSet);
begin
  LoadRecord;
end;

{ New record: fill controls from the fields' default expressions (Today(), Now() ...). }
procedure TaFormRunner.ApplyDefaults;
var
  I: Integer;
  C: TControl;
  M: TaFieldMeta;
begin
  FLoading := True;
  try
    for I := 0 to FBound.Count - 1 do
    begin
      C := TControl(FBound[I]);
      M := MetaFor(DefOf(C).ControlSource);
      if (M = nil) or (M.DefaultExpr = '') then Continue;
      if IsCheckLike(C) or HasKeys(C) then WriteControlValue(C, EvalDefault(M))
      else WriteControlValue(C, StoredToDisplay(M, EvalDefault(M)));
    end;
  finally
    FLoading := False;
  end;
  FDirty := False;
  ApplyAutoPreview;
  RecalcAll;
end;

{ sprema trenutni upit pod imenom; u upitnom nacinu uzima uzorke upisane u kontrole }
procedure TaFormRunner.SaveFind(const AName: string);
var
  I: Integer;
  C: TControl;
  Fld, Txt: string;
  L: TStringList;
begin
  if AName = '' then begin Notify(Tr('Enter a name for the saved query.')); Exit; end;
  L := TStringList.Create;
  try
    if FQueryMode and (FView = nil) then
    begin
      for I := 0 to FBound.Count - 1 do
      begin
        C := TControl(FBound[I]);
        if IsCheckLike(C) then Continue;
        Fld := DefOf(C).ControlSource;
        Txt := Trim(ReadControlValue(C));
        if (Fld <> '') and (Fld[1] <> '=') and (Txt <> '') then L.Values[Fld] := Txt;
      end;
    end
    else L.Assign(FColFilters);
    if L.Count = 0 then begin Notify(Tr('There is no query to save: run a query first (F7, F8).')); Exit; end;
    FindsSave(FDb, FDef.Name, AName, L);
  finally
    L.Free;
  end;
end;

procedure TaFormRunner.LoadFind(const AName: string);
var
  L: TStringList;
begin
  L := TStringList.Create;
  try
    if not FindsLoad(FDb, FDef.Name, AName, L) then begin Notify(Tr('There is no saved query: ') + AName); Exit; end;
    if FQueryMode then CancelQuery;
    FColFilters.Assign(L);
    Requery;
  finally
    L.Free;
  end;
end;

{ rjecnik (vrsta copy) dodaje pravila AutoFill forme: kad se promijeni polje s kljucem, popunjava se polje iz povezane tablice }
procedure TaFormRunner.AddDictCopyRules;
var
  I, N: Integer;
  R: TaAutoFillDef;
begin
  for I := 0 to FMetas.Count - 1 do
    if CopyRuleFor(TaFieldMeta(FMetas[I]), R) then
    begin
      N := Length(FFormAutoDefs);
      SetLength(FFormAutoDefs, N + 1);
      FFormAutoDefs[N] := R;
      if FFormAutoFill = nil then FFormAutoFill := TStringList.Create;
    end;
end;

{ sljedeci broj prikazan u polju prije spremanja (nista se ne upisuje u brojac) }
procedure TaFormRunner.ApplyAutoPreview;
var
  I: Integer;
  C: TControl;
  M: TaFieldMeta;
begin
  FLoading := True;
  try
    for I := 0 to FBound.Count - 1 do
    begin
      C := TControl(FBound[I]);
      M := MetaFor(DefOf(C).ControlSource);
      if AutoKindOf(M) <> akSerial then Continue;
      try
        WriteControlValue(C, SerialPreview(FDb, M, Now));
      except
      end;
    end;
  finally
    FLoading := False;
  end;
  FDirty := False;
end;

{ upisuje automatske vrijednosti u zapis tik prije spremanja; broj racuna se dodjeljuje u istoj transakciji kao zapis }
procedure TaFormRunner.ApplyAutoEnter(AInsert: Boolean);
var
  I: Integer;
  M: TaFieldMeta;
  F: TField;
  K: TaAutoKind;
  V: Variant;
  Err: string;
  Empty: Boolean;
  CopyR: TaAutoFillDef;
  Kf: TField;
  CopySt: TStringList;

  procedure PutNow;
  begin
    if F.DataType in [ftDate, ftDateTime, ftTime, ftTimeStamp] then F.AsDateTime := Now
    else if M.LType = ltDate then F.AsString := FormatDateTime('yyyy-mm-dd', Now)
    else F.AsString := FormatDateTime('yyyy-mm-dd hh:nn:ss', Now);
  end;

begin
  for I := 0 to FMetas.Count - 1 do
  begin
    M := TaFieldMeta(FMetas[I]);
    K := AutoKindOf(M);
    if K = akNone then Continue;
    if (not AInsert) and not AutoAlways(M) then Continue;
    if (K = akSerial) and not AInsert then Continue;
    F := FQuery.FindField(M.FieldName);
    if (F = nil) or F.ReadOnly then Continue;
    if not (FQuery.State in [dsEdit, dsInsert]) then FQuery.Edit;
    Empty := F.IsNull or (Trim(F.AsString) = '');
    { vrijednost koju je korisnik sam upisao ostaje, osim kad se polje uvijek ispunjava }
    if (not AutoAlways(M)) and (K <> akSerial) and not Empty then Continue;
    case K of
      akSerial:
        begin
          if not FAutoTx then begin FDb.Conn.StartTransaction; FAutoTx := True; end;
          F.AsString := SerialCommit(FDb, M, Now);
        end;
      akCopy:
        if Empty and CopyRuleFor(M, CopyR) then
        begin
          Kf := FQuery.FindField(CopyR.Field);
          if (Kf <> nil) and not Kf.IsNull then
          begin
            CopySt := TStringList.Create;
            try
              if AutoFillLookup(FDb, CopyR, Kf.AsString, CopySt) and (CopySt.Count > 0) then SetFieldStored(F, CopySt.ValueFromIndex[0]);
            finally
              CopySt.Free;
            end;
          end;
        end;
      akCreated, akModified: PutNow;
      akUser: F.AsString := CurrentUserName;
      akConst: F.AsString := M.GetX('autoconst');
      akExpr:
        begin
          V := EvalExprEx(M.GetX('autoexpr'), FHost, Err);
          if (Err = '') and not (VarIsNull(V) or VarIsEmpty(V)) then
          begin
            if VarIsNumeric(V) and not VarIsStr(V) then
            begin
              if F.DataType in [ftSmallint, ftInteger, ftLargeint, ftWord, ftAutoInc] then SetFieldStored(F, IntToStr(Round(Double(V))))
              else SetFieldStored(F, FloatToStr(Double(V), InvariantFS));
            end
            else SetFieldStored(F, VarToStr(V));
          end;
        end;
    end;
  end;
end;

{ ---------------- actions ---------------- }

{ ---------------- upit po formi (19.4) ---------------- }

procedure TaFormRunner.EnterQuery;
var
  I: Integer;
  C: TControl;
begin
  if FQueryMode then Exit;
  if FCont <> nil then
  begin
    Notify(Tr('In a continuous form filter with the fields in the header.'));
    Exit;
  end;
  if (FQuery = nil) or not FQuery.Active then Exit;
  if not SaveRecord then Exit;
  FPrevFilters.Assign(FColFilters);
  FQueryMode := True;
  if FView <> nil then
  begin
    ShowQueryBar(True);
    Exit;
  end;
  FLoading := True;
  try
    for I := 0 to FBound.Count - 1 do
    begin
      C := TControl(FBound[I]);
      if IsCheckLike(C) then Continue;   { kvacica nema stanje "svejedno" }
      WriteControlValue(C, '');
    end;
  finally
    FLoading := False;
  end;
  FDirty := False;
  UpdateNav;
end;

function TaFormRunner.ExecuteQuery: Boolean;
var
  I: Integer;
  C: TControl;
  Fld, Txt, Sql, Err: string;
  Work: TStringList;
begin
  Result := False;
  if not FQueryMode then Exit;
  Work := TStringList.Create;
  try
    if FView <> nil then
      for I := 0 to FQueryEdits.Count - 1 do
      begin
        Fld := FQueryEdits[I];
        Txt := Trim(TEdit(FQueryEdits.Objects[I]).Text);
        if Txt = '' then Continue;
        if not ColumnFilterSql(FDb.QuoteId(Fld), FilterKindOf(Fld), Txt, Sql, Err) then
        begin
          Notify(Fld + ': ' + Err);
          Exit;
        end;
        Work.Values[Fld] := Txt;
      end;
    if FView = nil then
    for I := 0 to FBound.Count - 1 do
    begin
      C := TControl(FBound[I]);
      if IsCheckLike(C) then Continue;
      Fld := DefOf(C).ControlSource;
      if (Fld = '') or (Fld[1] = '=') then Continue;
      Txt := Trim(ReadControlValue(C));
      if Txt = '' then Continue;
      if not ColumnFilterSql(FDb.QuoteId(Fld), FilterKindOf(Fld), Txt, Sql, Err) then
      begin
        Notify(Fld + ': ' + Err);
        Exit;
      end;
      Work.Values[Fld] := Txt;
    end;
    FColFilters.Assign(Work);
  finally
    Work.Free;
  end;
  FQueryMode := False;
  ShowQueryBar(False);
  Requery;
  if (FQuery <> nil) and FQuery.Active and FQuery.IsEmpty then
  begin
    Notify(Tr('The query returned no records.'));
    FColFilters.Assign(FPrevFilters);
    Requery;
    Exit;
  end;
  Result := True;
end;

procedure TaFormRunner.CancelQuery;
begin
  if not FQueryMode then Exit;
  FQueryMode := False;
  if FView <> nil then begin ShowQueryBar(False); UpdateNav; Exit; end;
  LoadRecord;
end;

function TaFormRunner.QueryEdit(const AField: string): TEdit;
var
  I: Integer;
begin
  I := FQueryEdits.IndexOf(AField);
  if I >= 0 then Result := TEdit(FQueryEdits.Objects[I]) else Result := nil;
end;

{ traka upita u tablici: naziv stupca i polje za uzorak, predpunjeno trenutnim filtrima }
procedure TaFormRunner.BuildQueryBar;
const
  W = 150; H = 46;
var
  I, N, Per: Integer;
  L: TLabel;
  E: TEdit;
  F: string;
begin
  FreeAndNil(FQueryBar);
  FQueryEdits.Clear;
  FQueryBar := TPanel.Create(Self);
  FQueryBar.Parent := Self;
  FQueryBar.Align := alTop;
  FQueryBar.BevelOuter := bvNone;
  FQueryBar.Visible := False;
  Per := Self.ClientWidth div W;
  if Per < 1 then Per := 1;
  N := 0;
  for I := 0 to FView.ColCount - 1 do
  begin
    F := FView.ColFieldName(I);
    if (F = '') or not FView.ColVisible(I) then Continue;
    L := TLabel.Create(FQueryBar);
    L.Parent := FQueryBar;
    L.Caption := StripSortMark(FView.ColTitle(I));
    L.SetBounds(6 + (N mod Per) * W, 4 + (N div Per) * H, W - 8, 16);
    E := TEdit.Create(FQueryBar);
    E.Parent := FQueryBar;
    E.SetBounds(6 + (N mod Per) * W, 20 + (N div Per) * H, W - 12, 24);
    E.Text := FColFilters.Values[F];
    E.OnKeyDown := @QueryBarKey;
    FQueryEdits.AddObject(F, E);
    Inc(N);
  end;
  FQueryBar.Height := ((N + Per - 1) div Per) * H + 4;
end;

procedure TaFormRunner.ShowQueryBar(AShow: Boolean);
begin
  if FView = nil then Exit;
  if AShow then
  begin
    BuildQueryBar;
    FQueryBar.Visible := True;
    if FQueryEdits.Count > 0 then
      try TEdit(FQueryEdits.Objects[0]).SetFocus; except end;
  end
  else if FQueryBar <> nil then
    FQueryBar.Visible := False;
end;

procedure TaFormRunner.QueryBarKey(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if FKeyMap = nil then Exit;
  case FKeyMap.Resolve(Key, Shift) of
    kaSaveRow, kaExecuteQuery: begin ExecuteQuery; Key := 0; end;
    kaCancelRow, kaCancelOrClose: begin CancelQuery; Key := 0; end;
  end;
end;

procedure TaFormRunner.QueryClick(Sender: TObject);
begin
  if FQueryMode then ExecuteQuery else EnterQuery;
end;

{ polje izvora koje popunjava ova kontrola: iz lovmap, inace njezin ControlSource }
function LovSourceField(ADef: TaControlDef; const ACtlName: string): string;
var
  Parts, KV: TStringList;
  I: Integer;
begin
  Result := ADef.ControlSource;
  Parts := TStringList.Create;
  try
    Parts.Delimiter := ';'; Parts.StrictDelimiter := True;
    Parts.DelimitedText := ADef.GetX('lovmap');
    for I := 0 to Parts.Count - 1 do
      if SameText(Trim(Parts.ValueFromIndex[I]), ACtlName) then Exit(Trim(Parts.Names[I]));
  finally
    Parts.Free;
  end;
end;

function TaFormRunner.LovValidate(C: TControl; const AValue: string): string;
var
  Ds: TDataSet;
  Err, Fld: string;
begin
  Result := '';
  Ds := OpenPrefixedSource(DefOf(C).GetX('lov'), Err);
  if Ds = nil then Exit('Popis vrijednosti: ' + Err);
  try
    Fld := LovSourceField(DefOf(C), DefOf(C).Name);
    if Ds.FindField(Fld) = nil then Exit('Popis vrijednosti nema polje ' + Fld);
    if not Ds.Locate(Fld, AValue, [loCaseInsensitive]) then
      Result := DefOf(C).ControlSource + ': vrijednosti "' + AValue + '" nema u popisu';
  finally
    Ds.Free;
  end;
end;

function TaFormRunner.ShowLov(C: TControl): Boolean;
var
  Ds: TDataSet;
  D: TaControlDef;
  Err, Fld, Cur, Title: string;
  Parts: TStringList;
  I: Integer;
  Tgt: TControl;
  Picked: Boolean;
  F: TField;
begin
  Result := False;
  if (C = nil) or FQueryMode or (FBound.IndexOf(C) < 0) then Exit;
  D := DefOf(C);
  if D.GetX('lov') = '' then Exit;
  Ds := OpenPrefixedSource(D.GetX('lov'), Err);
  if Ds = nil then begin Notify(Tr('List of values: ') + Err); Exit(True); end;
  Parts := TStringList.Create;
  try
    Result := True;
    Cur := Trim(ReadControlValue(C));
    Title := D.Caption;
    if Title = '' then Title := D.ControlSource;
    if Assigned(OnRunnerLov) then Picked := OnRunnerLov(Ds, Title, Cur)
    else Picked := RunLov(Self, Ds, Title, Cur);
    if not Picked then Exit;
    Parts.Delimiter := ';'; Parts.StrictDelimiter := True;
    Parts.DelimitedText := D.GetX('lovmap');
    if Parts.Count = 0 then Parts.Add(D.ControlSource + '=' + D.Name);
    for I := 0 to Parts.Count - 1 do
    begin
      Fld := Trim(Parts.Names[I]);
      Tgt := FindControl(Trim(Parts.ValueFromIndex[I]));
      F := Ds.FindField(Fld);
      if (Tgt = nil) or (F = nil) then Continue;
      if (DefOf(Tgt) <> nil) and (DefOf(Tgt).ControlSource <> '') then
        WriteControlValue(Tgt, StoredToDisplay(MetaFor(DefOf(Tgt).ControlSource), F.AsString))
      else
        WriteControlValue(Tgt, F.AsString);
    end;
  finally
    Parts.Free;
    Ds.Free;
  end;
end;

{ tipkovnicki standard forme (19.8): isti ta_keymap kao neprekidna forma, postavka aplikacije }
procedure TaFormRunner.RunnerKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  A: TaKeyAction;
  AC: TWinControl;
begin
  if (FKeyMap = nil) or (FCont <> nil) then Exit;
  A := FKeyMap.Resolve(Key, Shift);
  if A = kaNone then Exit;
  if FView <> nil then
  begin
    { u tablici samo upit po formi; ostalo ostaje mrezi }
    if A = kaLov then begin if ShowGridLov then Key := 0; end
    else if A = kaQuery then begin EnterQuery; Key := 0; end
    else if (A = kaExecuteQuery) and FQueryMode then begin ExecuteQuery; Key := 0; end
    else if (A in [kaCancelRow, kaCancelOrClose]) and FQueryMode then begin CancelQuery; Key := 0; end;
    Exit;
  end;
  AC := ActiveControl;
  { stranice, Enter i strelice pripadaju viseretkovnim poljima i otvorenim popisima }
  if (AC is TCustomMemo) and (A in [kaPageDown, kaPageUp, kaNextField, kaPrevField]) then Exit;
  case A of
    kaPageDown: DoAction('next');
    kaPageUp: DoAction('prior');
    kaFirstRecord: DoAction('first');
    kaLastRecord: DoAction('last');
    kaNewRecord: DoAction('new');
    kaSaveRow: if FQueryMode then ExecuteQuery else DoAction('save');
    kaDeleteRow: DoAction('delete');
    kaQuery: DoAction('query');
    kaExecuteQuery: DoAction('execquery');
    kaLov: if not ShowLov(HostOf(AC)) then Exit;
    kaCancelRow, kaCancelOrClose:
      if FQueryMode then CancelQuery
      else if FDirty or ((FQuery <> nil) and (FQuery.State in [dsEdit, dsInsert])) then DoAction('undo')
      else if A = kaCancelOrClose then Close
      else Exit;
    kaCloseForm: Close;
    kaNextField:
      if (Key = 13) and ((AC is TCustomEdit) or (AC is TCustomComboBox)) and not (AC is TCustomMemo) then
        SelectNext(AC, True, True)
      else Exit;
  else
    Exit;
  end;
  Key := 0;
end;

procedure TaFormRunner.DoAction(const AAction: string);
var
  SortOpt: string;
  A, Verb, Arg, Crit, FormPart: string;
  P, N: Integer;
  Js: string;
  Sub: TaFormDef;
  R: TaFormRunner;
  Rep: TaReportDef;
  C: TControl;
begin
  A := Trim(AAction);
  P := Pos(':', A);
  if P > 0 then
  begin
    Verb := LowerCase(Trim(Copy(A, 1, P - 1)));
    Arg := Trim(Copy(A, P + 1, MaxInt));
  end
  else
  begin
    Verb := LowerCase(A);
    Arg := '';
  end;
  if Verb = 'close' then begin Close; Exit; end;
  if (Verb = 'openform') and Assigned(OpenFormHook) and OpenFormHook(Arg) then Exit;
  if Verb = 'run' then
  begin
    FContext.Cancelled := False;
    RunProcName(Arg);
    Exit;
  end;
  if Verb = 'fgl' then
  begin
    { 4GL program iz baze (izbornik: "program Naziv") }
    if FDb.LoadObject('_sys_programs', Arg) = '' then Notify(Tr('There is no 4GL program: ') + Arg)
    else if not Assigned(OnRunFglText) then Notify(Tr('4GL cannot be run from this environment.'))
    else OnRunFglText(FDb, FDb.LoadObject('_sys_programs', Arg));
    Exit;
  end;
  if Verb = 'macro' then
  begin
    if not CanRun(FDb, '_sys_macros', Arg) then begin Notify(Tr('You do not have the right to run the macro ') + Arg); Exit; end;
    RunMacroByName(FContext, Arg);
    Exit;
  end;
  if Verb = 'msg' then begin Notify(Arg); Exit; end;
  if Verb = 'goto' then
  begin
    C := FindControl(Arg);
    if (C <> nil) and (C is TWinControl) and TWinControl(C).CanFocus then TWinControl(C).SetFocus;
    Exit;
  end;
  if Verb = 'sql' then
  begin
    try
      FDb.Conn.ExecuteDirect(Arg);
    except
      on E: Exception do Notify(Tr('SQL failed: ') + E.Message);
    end;
    Requery;
    Exit;
  end;
  if Verb = 'audit' then
  begin
    { povijest promjena trenutnog zapisa (po polju id) }
    if SessionRole < arAdmin then begin Notify(Tr('Only an administrator may open the change history.')); Exit; end;
    Crit := '';
    if (FQuery <> nil) and FQuery.Active and (not FQuery.IsEmpty) and (FQuery.FindField('id') <> nil) then
      Crit := FQuery.FieldByName('id').AsString;
    RunAuditViewer(Self, FDb, FDef.RecordSource, Crit);
    Exit;
  end;
  if Verb = 'openform' then
  begin
    { ne smije biti isti niz kao ulaz i izlaz: izlazni parametar ga prvo isprazni }
    FormPart := Arg;
    SplitFormAction(FormPart, Arg, Crit);
    Js := FDb.LoadObject('_sys_forms', Arg);
    if Js = '' then begin Notify(Tr('There is no form: ') + Arg); Exit; end;
    if not CanRun(FDb, '_sys_forms', Arg) then begin Notify(Tr('You do not have the right to open the form ') + Arg); Exit; end;
    Sub := TaFormDef.Create;
    Sub.FromJson(Js);
    Sub.Name := Arg;
    R := TaFormRunner.CreateRunner(Self, FDb, Sub);
    try
      if Crit <> '' then R.OpenWith(Crit);
      R.ShowModal;
    finally
      R.Free;
    end;
    Requery;
    Exit;
  end;
  if Verb = 'esphome' then
  begin
    ExportEspHome;
    Exit;
  end;
  if Verb = 'exportpdf' then
  begin
    if not ExportReportPdfNamed(FDb, Arg, Crit) then Notify(Tr('The PDF was not created: ') + Crit);
    Exit;
  end;
  if Verb = 'exportletter' then
  begin
    if not ExportLetterNamed(FDb, Arg, Crit) then Notify(Tr('The letter was not exported: ') + Crit);
    Exit;
  end;
  if Verb = 'openletter' then
  begin
    if Pos('@', Arg) > 0 then PreviewLetter(Self, FDb, Trim(Copy(Arg, 1, Pos('@', Arg) - 1)), Trim(Copy(Arg, Pos('@', Arg) + 1, MaxInt)))
    else PreviewLetter(Self, FDb, Trim(Arg));
    Exit;
  end;
  if Verb = 'exporthtml' then
  begin
    if not ExportReportHtmlNamed(FDb, Arg, Crit) then Notify(Tr('The HTML was not created: ') + Crit);
    Exit;
  end;
  if Verb = 'openreport' then
  begin
    { openreport:Name  or  openreport:Name@"id = " & [id]  (the part after @ is an expression giving a SQL condition) }
    Crit := '';
    if Pos('@', Arg) > 0 then
    begin
      Crit := FormatValue(EvalExpr(Trim(Copy(Arg, Pos('@', Arg) + 1, MaxInt)), FHost), '');
      Arg := Trim(Copy(Arg, 1, Pos('@', Arg) - 1));
    end;
    { openreport:Name#poredak=Po cijeni : otvara izvjesce vec u tom ponudenom poretku }
    SplitReportArg(Arg, Arg, SortOpt);
    Js := FDb.LoadObject('_sys_reports', Arg);
    if Js = '' then begin Notify(Tr('There is no report: ') + Arg); Exit; end;
    if not CanRun(FDb, '_sys_reports', Arg) then begin Notify(Tr('You do not have the right to open the report ') + Arg); Exit; end;
    Rep := TaReportDef.Create;
    try
      Rep.FromJson(Js);
      Rep.Name := Arg;
      if Crit <> '' then Rep.Filter := Crit;
      ShowReportPreview(Self, FDb, Rep, SortOpt);
    finally
      Rep.Free;
    end;
    Exit;
  end;
  if Verb = 'export' then begin ExportView(Arg); Exit; end;
  if Verb = 'filter' then begin FDef.Filter := Arg; Requery; Exit; end;
  if (Verb = 'nofilter') or (Verb = 'clearfilter') or (Verb = 'clearfilters') then
  begin
    FDef.Filter := '';
    FSearch := '';
    if FSearchEdit <> nil then FSearchEdit.Text := '';
    ClearFilterControls;
    Requery;
    Exit;
  end;
  if (FQuery = nil) or not FQuery.Active then Exit;
  if Verb = 'sort' then
  begin
    { sort: polje   |   sort: polje DESC   |   sort: polje1, polje2 DESC   (prazno = prirodni poredak) }
    FDef.OrderBy := Arg;
    Requery;
    Exit;
  end;
  if Verb = 'gotorecord' then
  begin
    { gotorecord: n  (izraz; 1 = prvi); izvan raspona ide na najblizi }
    N := Round(Double(EvalExpr(Arg, FHost)));
    if N < 1 then N := 1;
    if N > FQuery.RecordCount then N := FQuery.RecordCount;
    if N >= 1 then FQuery.RecNo := N;
    Exit;
  end;
  if Verb = 'find' then
  begin
    { find: polje = izraz  - postavlja se na prvi redak s tom vrijednoscu }
    P := Pos('=', Arg);
    if P = 0 then begin Notify(Tr('The find command needs the form: field = expression')); Exit; end;
    if not FQuery.Locate(Trim(Copy(Arg, 1, P - 1)), FormatValue(EvalExpr(Trim(Copy(Arg, P + 1, MaxInt)), FHost), ''), [loCaseInsensitive]) then
      Notify(Tr('There is no record: ') + Arg);
    Exit;
  end;
  if Verb = 'undo' then
  begin
    if FQuery.State in [dsEdit, dsInsert] then FQuery.Cancel;
    LoadRecord;
    Exit;
  end;
  if (Verb = 'refresh') or (Verb = 'requery') then begin Requery; Exit; end;
  if Verb = 'query' then begin EnterQuery; Exit; end;
  if Verb = 'execquery' then begin ExecuteQuery; Exit; end;
  if Verb = 'cancelquery' then begin CancelQuery; Exit; end;
  if Verb = 'clearquery' then begin FColFilters.Clear; Requery; Exit; end;
  { spremljena trazenja: savequery:Ime sprema izvedeni upit (ili uzorke upisane u upitnom nacinu), loadquery:Ime ga primjenjuje }
  if Verb = 'savequery' then begin SaveFind(Trim(Arg)); Exit; end;
  if Verb = 'loadquery' then begin LoadFind(Trim(Arg)); Exit; end;
  if Verb = 'deletequery' then
  begin
    if not FindsDelete(FDb, FDef.Name, Trim(Arg)) then Notify(Tr('There is no saved query: ') + Arg);
    Exit;
  end;
  if FQueryMode then
  begin
    Notify(Tr('The form is in query mode: F8 runs the query, Esc cancels it.'));
    Exit;
  end;
  if not SaveRecord then Exit;
  if Verb = 'save' then LoadRecord
  else if Verb = 'first' then FQuery.First
  else if (Verb = 'prior') or (Verb = 'prev') then FQuery.Prior
  else if Verb = 'next' then FQuery.Next
  else if Verb = 'last' then FQuery.Last
  else if Verb = 'new' then
  begin
    if not FDef.AllowAdds then Exit;
    FQuery.Append;
    if (FMasterField <> '') and (FMasterValue <> '') and (FQuery.FindField(FMasterField) <> nil) then
      FQuery.FindField(FMasterField).AsString := FMasterValue;
    ApplyDefaults;
    ApplyDocNew;
  end
  else if Verb = 'duplicate' then DuplicateRecord
  else if Verb = 'delete' then
  begin
    if not FDef.AllowDeletes then Exit;
    if FQuery.IsEmpty then Exit;
    if FireEvent('BeforeDelete') then Exit;
    if AskRunner(Tr('Delete the record?')) then
    begin
      FQuery.Delete;
      FireEvent('AfterDelete');
    end;
  end;
end;

procedure TaFormRunner.SideAction(const AAction: string);
begin
  DoAction(AAction);
end;

procedure TaFormRunner.ButtonClick(Sender: TObject);
var
  D: TaControlDef;
begin
  D := DefOf(TControl(Sender));
  if (D <> nil) and (D.OnClick <> '') then DoAction(D.OnClick);
end;

procedure TaFormRunner.NavClick(Sender: TObject);
begin
  DoAction(NavActions[TButton(Sender).Tag]);
end;

procedure TaFormRunner.HyperClick(Sender: TObject);
var
  Addr: string;
begin
  if Sender is TaHyperlink then Addr := TaHyperlink(Sender).Address
  else Addr := FamilyAddress(TControl(Sender));
  if Addr = '' then Exit;
  if (Pos('://', Addr) = 0) and (Pos('mailto:', LowerCase(Addr)) <> 1) and not FileExists(Addr) then
    Addr := 'https://' + Addr;
  if Pos('://', Addr) > 0 then OpenURL(Addr) else OpenDocument(Addr);
end;

procedure TaFormRunner.AttachImageMenu(Img: TControl);
var
  Mi: TMenuItem;
  Pm: TPopupMenu;
begin
  Pm := TPopupMenu.Create(Img);
  FamilySetPopup(Img, Pm);
  Mi := TMenuItem.Create(Pm);
  Mi.Caption := Tr('Choose a picture...');
  Mi.Tag := PtrInt(Img);
  Mi.OnClick := @ImageDblClick;
  Pm.Items.Add(Mi);
  Mi := TMenuItem.Create(Pm);
  Mi.Caption := Tr('Remove picture');
  Mi.Tag := PtrInt(Img);
  Mi.OnClick := @ImageClearClick;
  Pm.Items.Add(Mi);
end;

function ImageOf(Sender: TObject): TControl;
begin
  if Sender is TMenuItem then Result := TControl(TMenuItem(Sender).Tag) else Result := HostOf(TControl(Sender));
end;

{ Slika se kopira u pohranu datoteka, a u polje ide samo veza. }
procedure TaFormRunner.PickImage(Img: TControl);
var
  D: TOpenDialog;
  F: TField;
  Link: string;
begin
  if (FQuery = nil) or FQuery.IsEmpty or not FDef.AllowEdits or (DefOf(Img).GetX('locked') = '1') then Exit;
  F := FQuery.FindField(DefOf(Img).ControlSource);
  if F = nil then Exit;
  if F is TBlobField then
  begin
    Notify(Tr('This field stores a picture in the database. Pictures are kept as files: ') +
      'u izborniku Baza > Pohrana datoteka pretvori stare slike u veze.');
    Exit;
  end;
  D := TOpenDialog.Create(nil);
  try
    D.Filter := Tr('Pictures|*.png;*.jpg;*.jpeg;*.bmp;*.gif|All files|*');
    if not D.Execute then Exit;
    if not SaveRecord then Exit;
    try
      Link := StoreFile(FDb, D.FileName, PictureSubDir(FDef.Name));
      FQuery.Edit;
      F.AsString := Link;
      FQuery.Post;
    except
      on E: Exception do begin
        Notify(Tr('The picture was not saved: ') + E.Message);
        if FQuery.State in [dsEdit, dsInsert] then FQuery.Cancel;
      end;
    end;
    LoadRecord;
  finally
    D.Free;
  end;
end;

procedure TaFormRunner.ImageDblClick(Sender: TObject);
begin
  PickImage(ImageOf(Sender));
end;

procedure TaFormRunner.ImageClearClick(Sender: TObject);
var
  Img: TControl;
  F: TField;
begin
  Img := ImageOf(Sender);
  if (FQuery = nil) or FQuery.IsEmpty or not FDef.AllowEdits or (DefOf(Img).GetX('locked') = '1') then Exit;
  F := FQuery.FindField(DefOf(Img).ControlSource);
  if F = nil then Exit;
  if not SaveRecord then Exit;
  try
    FQuery.Edit;
    F.Clear;
    FQuery.Post;
  except
    on E: Exception do begin
      Notify(Tr('The picture was not removed: ') + E.Message);
      if FQuery.State in [dsEdit, dsInsert] then FQuery.Cancel;
    end;
  end;
  LoadRecord;
end;

procedure TaFormRunner.LovHostClick(Sender: TObject);
begin
  ShowLov(TControl(Sender));
end;

procedure TaFormRunner.LovButtonClick(Sender: TObject);
var
  C: TControl;
begin
  C := TControl(TButton(Sender).Tag);
  if C is TWinControl then
    try TWinControl(C).SetFocus; except end;
  ShowLov(C);
end;

{ GridLov: "polje | izvor | izvor_polje=polje_tablice;... ;; ..." }
function TaFormRunner.GridLovFor(const AField: string; out ASource, AMap: string): Boolean;
var
  Items, P: TStringList;
  I: Integer;
  S: string;
begin
  Result := False;
  ASource := ''; AMap := '';
  if Trim(FDef.GridLov) = '' then Exit;
  Items := TStringList.Create;
  P := TStringList.Create;
  try
    S := StringReplace(FDef.GridLov, ';;', #10, [rfReplaceAll]);
    Items.Text := S;
    for I := 0 to Items.Count - 1 do
    begin
      P.Delimiter := '|'; P.StrictDelimiter := True;
      P.DelimitedText := Items[I];
      if (P.Count >= 2) and SameText(Trim(P[0]), AField) then
      begin
        ASource := Trim(P[1]);
        if P.Count >= 3 then AMap := Trim(P[2]);
        Exit(True);
      end;
    end;
  finally
    Items.Free; P.Free;
  end;
end;

function TaFormRunner.ShowGridLov: Boolean;
var
  Ds: TDataSet;
  Fld, Src, Map, Err, Cur, Sf: string;
  Parts: TStringList;
  I: Integer;
  Picked: Boolean;
  F, Tf: TField;
begin
  Result := False;
  if (FView = nil) or (FQuery = nil) or not FQuery.Active or FQueryMode then Exit;
  if FView.SelectedField = nil then Exit;
  Fld := FView.SelectedField.FieldName;
  if not GridLovFor(Fld, Src, Map) then Exit;
  Result := True;
  if FView.ReadOnly or not FDef.AllowEdits then Exit;
  Ds := OpenPrefixedSource(Src, Err);
  if Ds = nil then begin Notify(Tr('List of values: ') + Err); Exit; end;
  Parts := TStringList.Create;
  try
    Cur := FView.SelectedField.AsString;
    if Assigned(OnRunnerLov) then Picked := OnRunnerLov(Ds, Fld, Cur)
    else Picked := RunLov(Self, Ds, Fld, Cur);
    if not Picked then Exit;
    Parts.Delimiter := ';'; Parts.StrictDelimiter := True;
    Parts.DelimitedText := Map;
    if Parts.Count = 0 then Parts.Add(Fld + '=' + Fld);
    if not (FQuery.State in [dsEdit, dsInsert]) then FQuery.Edit;
    for I := 0 to Parts.Count - 1 do
    begin
      Sf := Trim(Parts.Names[I]);
      F := Ds.FindField(Sf);
      Tf := FQuery.FindField(Trim(Parts.ValueFromIndex[I]));
      if (F = nil) or (Tf = nil) or Tf.ReadOnly then Continue;
      SetFieldStored(Tf, F.AsString);
    end;
  finally
    Parts.Free;
    Ds.Free;
  end;
end;

procedure TaFormRunner.DateButtonClick(Sender: TObject);
var
  C: TControl;
  M: TaFieldMeta;
  Stored: string;
  Dt: TDateTime;
  Fmt: string;
begin
  C := TControl(TButton(Sender).Tag);
  if not IsPlainEdit(C) then Exit;
  M := MetaFor(DefOf(C).ControlSource);
  Dt := Date;
  if (M <> nil) and DisplayToStored(M, ReadControlValue(C), Stored) and (Stored <> '') then
    if not ParseAnyDateTime(Stored, Dt) then Dt := Date;
  if not PickDate(Self, Dt) then Exit;
  if M <> nil then Fmt := M.Format;
  if Fmt = '' then Fmt := 'dd.mm.yyyy';
  if (M <> nil) and (M.LType = ltDateTime) then
    WriteControlValue(C, FormatDateTime(Fmt, Int(Dt) + Frac(Now)))
  else
    WriteControlValue(C, FormatDateTime(Fmt, Dt));
  { upis iz koda ne javlja promjenu: javi je kao da je korisnik upisao }
  if (C is TaFamilyHost) and (not FLoading) then ControlChanged(C);
end;

procedure TaFormRunner.Embed(AParent: TWinControl; AOnCloseRequest: TNotifyEvent);
begin
  FEmbedded := True;
  FOnCloseRequest := AOnCloseRequest;
  BorderStyle := bsNone;
  Position := poDesigned;
  FDesignW := ClientWidth;
  FDesignH := ClientHeight;
  Parent := AParent;
  Align := alNone;
  SetBounds(0, 0, FDesignW, FDesignH);
  OnClose := @EmbeddedClose;
  Visible := True;
end;

procedure TaFormRunner.OpenWith(const AArgs: string);
var
  L: TStringList;
  T: TaDocType;
begin
  if (FDef.DocTypeField = '') or (Trim(AArgs) = '') then Exit;
  L := TStringList.Create;
  try
    ParseOpenArgs(AArgs, L);
    FDocCode := L.Values['vrsta'];
  finally
    L.Free;
  end;
  if FDocCode = '' then Exit;
  if DocTypeLoad(FDb, FDocCode, T) then Caption := T.Name;
  { prikaz samo te vrste; novi zapis dobiva vrstu preko veze (isto kao detalj uz glavni zapis) }
  SetMaster(FDef.DocTypeField, FDocCode);
  if (FQuery <> nil) and FQuery.Active and FQuery.IsEmpty and FDef.AllowAdds then DoAction('new')
  else ApplyDocNew;
end;

{ novi zapis objedinjene forme: predlozi broj iz zadnje upisane vrijednosti }
procedure TaFormRunner.ApplyDocNew;
var
  I: Integer;
  C: TControl;
  N: string;
begin
  if (FDocCode = '') or (FDef.DocNumberField = '') or (FQuery = nil) or not FQuery.Active then Exit;
  if not (FQuery.State in [dsInsert]) then Exit;
  N := DocPreviewNumber(FDb, FDocCode);
  if N = '' then Exit;
  FLoading := True;
  try
    for I := 0 to FBound.Count - 1 do
    begin
      C := TControl(FBound[I]);
      if SameText(DefOf(C).ControlSource, FDef.DocNumberField) then WriteControlValue(C, N);
    end;
  finally
    FLoading := False;
  end;
  if FQuery.FindField(FDef.DocNumberField) <> nil then FQuery.FindField(FDef.DocNumberField).AsString := N;
end;

{ pri spremanju novog zapisa broj se stvarno dodjeljuje i upisuje u tablicu vrsta }
procedure TaFormRunner.CommitDocNumber;
var
  I: Integer;
  C: TControl;
  N: string;
begin
  if (FDocCode = '') or (FDef.DocNumberField = '') then Exit;
  N := DocCommitNumber(FDb, FDocCode);
  if N = '' then Exit;
  if FQuery.FindField(FDef.DocNumberField) <> nil then FQuery.FindField(FDef.DocNumberField).AsString := N;
  FLoading := True;
  try
    for I := 0 to FBound.Count - 1 do
    begin
      C := TControl(FBound[I]);
      if SameText(DefOf(C).ControlSource, FDef.DocNumberField) then WriteControlValue(C, N);
    end;
  finally
    FLoading := False;
  end;
end;

procedure TaFormRunner.FitTo(AWidth, AHeight: Integer);
begin
  if not FEmbedded then Exit;
  SetBounds(0, 0, Max(AWidth, FDesignW), Max(AHeight, FDesignH));
end;

procedure TaFormRunner.EmbeddedClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  { zatvaranje kartice: CloseQuery je vec proveden; uklanja je radni prostor }
  CloseAction := caNone;
  if Assigned(FOnCloseRequest) then FOnCloseRequest(Self);
end;

procedure TaFormRunner.RunnerCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if FCont <> nil then
  begin
    CanClose := FCont.Host.CommitRow;
    if CanClose and FireEvent('OnClose') then CanClose := False;
    Exit;
  end;
  { zatvaranje forme s nespremljenim izmjenama pita "Spremiti promjene?" (19.3) }
  if FDirty and (FQuery <> nil) and FQuery.Active and not FQueryMode then
    if not AskRunner(Tr('Save the changes?')) then
    begin
      if FQuery.State in [dsEdit, dsInsert] then FQuery.Cancel;
      FDirty := False;
    end;
  if FQueryMode then FQueryMode := False;
  CanClose := SaveRecord;
  if CanClose and FireEvent('OnClose') then CanClose := False;
end;

end.
