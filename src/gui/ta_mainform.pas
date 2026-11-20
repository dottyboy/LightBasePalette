unit ta_mainform;
{ Main window: object navigator (tables) + Datasheet / Design views.
  Built in code so the form has no .frm resource. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, ExtCtrls, StdCtrls, ComCtrls,
  Grids, DBGrids, DB, Menus, Graphics, Buttons, ZDataset, ta_meta, ta_controls, ta_formdef, ta_formrun, ta_formdesign, ta_querydesign, ta_reportdef, ta_reportengine, ta_reportview, ta_reportdesign, ta_types, ta_fielddlg, ta_importexport, ta_wizards, ta_importdlg, ta_relview, ta_script, ta_modeditor, ta_app, ta_appdlg, ta_switchgen, ta_exprsql, ta_qbe, ta_calcgen, ta_calcdlg, ta_querywiz, ta_bizgen, ta_bizdlg, ta_gendlg, ta_gridview, ta_family, ta_fiscalhook, ta_paramdlg, ta_auditdlg, ta_taskdlg, ta_crosstabdlg, ta_maint, ta_datatoolsdlg, ta_companydlg, ta_northwind, ta_showcase, ta_showcase2, ta_appspec, ta_mdbimport, ta_icons, ta_iconmap, ta_iconsdata, ta_doctypes, ta_shell, ta_sidemenu, ta_theme, ta_tokens, ta_migrate, ta_fgl, ta_fglgui, ta_catalog, ta_catalogdlg, ta_filestore, ta_filestoredlg, ta_manualdata, ta_blocksdemo, ta_letterdlg, ta_offers, ta_fgledit, ta_screens, ta_predict, ta_newton, ta_marketfit, ta_pairs, ta_validation, ta_league, ta_components, ta_binder, ta_slipgen, ta_backtest, ta_enginebt, ta_datarefresh, ta_dataimport, ta_datascrape, ta_analytics, ta_reliability, ta_skelwizard, ta_blockdlg, ta_editdlg, ta_keymap, LCLType, LCLIntf, contnrs, StrUtils;

type

  { TMainForm }

  TMainForm = class(TForm)
  private
    FDb: TAppDb;
    FList, FForms, FQueries, FReports, FModules, FMacros, FLetters, FPrograms: TListBox;
    FMainCtx: TaScriptContext;
    FShell: TaShell;
    FMainMenu: TMainMenu;
    FSplit: TSplitter;
    FRuntime, FLaunchRuntime, FLaunchDesign, FShown, FRunTasksOnly, FMakeNorthwind, FMakeBlocksDemo, FMakeShowcase, FMakeShowcase2: Boolean;
    FSpecArg, FMdbArg: string;
    FTaskTimer: TTimer;
    FNav: TPageControl;
    FRail: TPanel;                      { traka s ikonama umjesto kartica popisa objekata }
    FRailBtn: array[0..7] of TSpeedButton;
    FPages: TPageControl;
    FSheetTab, FDesignTab: TTabSheet;
    FGridView: TaGridView;
    FSource: TDataSource;
    FSheet: TZQuery;
    FFormatter: TaDatasetFormatter;
    FDesign: TStringGrid;
    FStatus: TStatusBar;
    procedure BuildUi;
    procedure ActNewDb(Sender: TObject);
    procedure ActNorthwind(Sender: TObject);
    procedure ActShowcase(Sender: TObject);
    function MakeShowcaseFile(const AFile: string; ALog: TStrings; AUnified: Boolean = False): Boolean;
    procedure ActShowcase2(Sender: TObject);
    procedure ActAppFromSpec(Sender: TObject);
    procedure ActImportMdb(Sender: TObject);
    function ImportMdbFile(const AMdb, ADbFile: string; ALog: TStrings): Boolean;
    function MakeAppFromSpecFile(const ASpecFile, ADbFile: string; ALog: TStrings; AReplace: Boolean = True): Boolean;
    procedure ActBlocksDemo(Sender: TObject);
    function MakeBlocksDemoFile(const AFile: string; ALog: TStrings): Boolean;
    function MakeNorthwindFile(const AFile: string; ALog: TStrings): Boolean;
    procedure ActOpenDb(Sender: TObject);
    procedure ActNewTable(Sender: TObject);
    procedure ActDropTable(Sender: TObject);
    procedure ListClick(Sender: TObject);
    procedure ActRelations(Sender: TObject);
    procedure ActNewModule(Sender: TObject);
    procedure ActEditModule(Sender: TObject);
    procedure ActRunProc(Sender: TObject);
    procedure ActDeleteModule(Sender: TObject);
    procedure ActNewMacro(Sender: TObject);
    procedure ActEditMacro(Sender: TObject);
    procedure ActFglEditor(Sender: TObject);
    procedure ActSkelWizard(Sender: TObject);
    procedure ActKeyMap(Sender: TObject);
    procedure ActBlockWizard(Sender: TObject);
    procedure ActSkelWizardData(Sender: TObject);
    procedure StartShell;
    procedure StopShell;
    procedure ShellAction(const AAction: string);
    procedure ShellLogout(Sender: TObject);
    function ShellOpenForm(const AName: string): Boolean;
    procedure ShellCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure DecorateNav;
    procedure InitIconLists;
    procedure ListDraw(Control: TWinControl; Index: Integer; ARect: TRect; State: TOwnerDrawState);
    procedure DesignDrawCell(Sender: TObject; aCol, aRow: Integer; aRect: TRect; aState: TGridDrawState);
    procedure RailClick(Sender: TObject);
    procedure ActNewProgram(Sender: TObject);
    procedure ActEditProgram(Sender: TObject);
    procedure ActRunProgram(Sender: TObject);
    procedure ActDeleteProgram(Sender: TObject);
    procedure ActRunMacro(Sender: TObject);
    procedure ActDeleteMacro(Sender: TObject);
    procedure RunAutoExec;
    procedure ApplyMode;
    procedure AfterOpen;
    procedure OpenStartupForm;
    procedure ActAppSettings(Sender: TObject);
    procedure ActSwitchboard(Sender: TObject);
    procedure ActDocTypes(Sender: TObject);
    procedure ActBusiness(Sender: TObject);
    procedure ActGenerateApp(Sender: TObject);
    procedure ActFiscal(Sender: TObject);
    procedure ActCompany(Sender: TObject);
    procedure ActAudit(Sender: TObject);
    procedure ActTasks(Sender: TObject);
    procedure TaskTimer(Sender: TObject);
    procedure ActUsers(Sender: TObject);
    procedure ActRights(Sender: TObject);
    procedure ActStartup(Sender: TObject);
    procedure ActTheme(Sender: TObject);
    procedure ActToggleMode(Sender: TObject);
    procedure MainShow(Sender: TObject);
    procedure MainKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    function Allowed(const AKind, AName: string): Boolean;
    procedure ActImport(Sender: TObject);
    procedure ActExport(Sender: TObject);
    procedure ActFormWizard(Sender: TObject);
    procedure ActMasterDetail(Sender: TObject);
    procedure ActReportWizard(Sender: TObject);
    procedure ActNewLetter(Sender: TObject);
    procedure ActEditLetter(Sender: TObject);
    procedure ActPreviewLetter(Sender: TObject);
    procedure ActLetterFile(Sender: TObject);
    procedure ActDeleteLetter(Sender: TObject);
    function SelectedLetter: string;
    procedure ActNewReport(Sender: TObject);
    procedure ActDesignReport(Sender: TObject);
    procedure ActPreviewReport(Sender: TObject);
    procedure ActDeleteReport(Sender: TObject);
    function SelectedReport: string;
    function LoadReportDef(const AName: string): TaReportDef;
    procedure ActNewQuery(Sender: TObject);
    procedure ActQueryWizard(Sender: TObject);
    procedure ActCrosstab(Sender: TObject);
    procedure ActDataTools(Sender: TObject);
    procedure ActBackup(Sender: TObject);
    procedure ActCompact(Sender: TObject);
    procedure ActDocument(Sender: TObject);
    procedure ActDesignQuery(Sender: TObject);
    procedure ActRunQuery(Sender: TObject);
    procedure ActDeleteQuery(Sender: TObject);
    procedure ActAddField(Sender: TObject);
    procedure ActDropField(Sender: TObject);
    procedure ActRenameField(Sender: TObject);
    procedure ActFieldProps(Sender: TObject);
    function SelectedQuery: string;
    function CurrentTable: string;
    procedure ActNewForm(Sender: TObject);
    procedure ActDesignForm(Sender: TObject);
    procedure ActRunForm(Sender: TObject);
    procedure ActDeleteForm(Sender: TObject);
    function SelectedForm: string;
    function LoadFormDef(const AName: string): TaFormDef;
    procedure RefreshTables;
    procedure ShowTable(const AName: string);
    procedure CloseSheet;
    procedure OpenFile(const AFile: string);
    procedure OpenServerSpec(const ASpec: string; AKind: TDbKind);
    procedure OpenServer(AKind: TDbKind; const AHost: string; APort: Integer; const ADb, AUser, APwd: string);
    procedure ActConnect(Sender: TObject);
    procedure ActCopyToServer(Sender: TObject);
    procedure ActCatalog(Sender: TObject);
    procedure ActFileStore(Sender: TObject);
    procedure ActManual(Sender: TObject);
    procedure ActManualAt(Sender: TObject);
    procedure ActCatalogDoc(Sender: TObject);
    procedure ActCatalogSnap(Sender: TObject);
    procedure ActCatalogApply(Sender: TObject);
    procedure ShotPrepare(const ATable: string);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  MainForm: TMainForm;

implementation

uses
  ta_i18n, ta_esphome;


constructor TMainForm.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  Caption := 'TyphAccess';
  SetBounds(0, 0, 1100, 700);
  Position := poScreenCenter;
  FDb := TAppDb.Create;
  ActiveStoreDb := FDb;
  BuildUi;
  KeyPreview := True;
  OnKeyDown := @MainKeyDown;
  OnShow := @MainShow;
end;

destructor TMainForm.Destroy;
begin
  OpenFormHook := nil;
  CloseSheet;
  FMainCtx.Free;
  FDb.Free;
  inherited Destroy;
end;

procedure TMainForm.BuildUi;
var
  MM: TMainMenu;
  M, It, Sub, Sub2: TMenuItem;
  Sp: TSplitter;
  Tb: TPanel;
  I: Integer;
  B: TButton;
begin
  MM := TMainMenu.Create(Self);
  M := TMenuItem.Create(MM); M.Caption := Tr('&Database'); MM.Items.Add(M);
  It := TMenuItem.Create(M); It.Caption := Tr('&New...'); It.OnClick := @ActNewDb; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('New: &Northwind Traders example...'); It.OnClick := @ActNorthwind; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('New: large &Trgovina Jadran example (thousands of records)...'); It.OnClick := @ActShowcase; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('New: Trgovina Jadran &2 (combined documents, cards)...'); It.OnClick := @ActShowcase2; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('New: application from a &description (text file)...'); It.OnClick := @ActAppFromSpec; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('New: import from &Access (.mdb, .accdb)...'); It.OnClick := @ActImportMdb; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('New: example with &blocks (small business)...'); It.OnClick := @ActBlocksDemo; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('New: sample database from the &catalog...'); It.OnClick := @ActCatalog; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('&Open...'); It.OnClick := @ActOpenDb; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('Connect to a &server (Postgres, MariaDB)...'); It.OnClick := @ActConnect; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('&Copy this database to a server...'); It.OnClick := @ActCopyToServer; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := '-'; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('File &store (pictures)...'); It.OnClick := @ActFileStore; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('Schema catalog: &snapshot of this database into a domain...'); It.OnClick := @ActCatalogSnap; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('Schema catalog: documentation (&HTML)...'); It.OnClick := @ActCatalogDoc; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('&Relations...'); It.OnClick := @ActRelations; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('&Backup...'); It.OnClick := @ActBackup; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('Check and &compact the database...'); It.OnClick := @ActCompact; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('Database &documentation (HTML)...'); It.OnClick := @ActDocument; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('&Import (CSV, Excel)...'); It.OnClick := @ActImport; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('&Export (CSV, Excel, JSON)...'); It.OnClick := @ActExport; M.Add(It);
  M := TMenuItem.Create(MM); M.Caption := Tr('&Table'); MM.Items.Add(M);
  It := TMenuItem.Create(M); It.Caption := Tr('&New table...'); It.OnClick := @ActNewTable; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('&Delete table'); It.OnClick := @ActDropTable; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('&Complete the field dictionary from the catalog'); It.OnClick := @ActCatalogApply; M.Add(It);
  M := TMenuItem.Create(MM); M.Caption := Tr('&Form'); MM.Items.Add(M);
  It := TMenuItem.Create(M); It.Caption := Tr('&New form...'); It.OnClick := @ActNewForm; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('Form &wizard...'); It.OnClick := @ActFormWizard; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('&Master-detail wizard...'); It.OnClick := @ActMasterDetail; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('&Design'); It.OnClick := @ActDesignForm; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('&Open'); It.OnClick := @ActRunForm; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('&Delete form'); It.OnClick := @ActDeleteForm; M.Add(It);
  M := TMenuItem.Create(MM); M.Caption := Tr('&Query'); MM.Items.Add(M);
  It := TMenuItem.Create(M); It.Caption := Tr('&New query...'); It.OnClick := @ActNewQuery; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('Query &wizard...'); It.OnClick := @ActQueryWizard; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('&Crosstab query and union...'); It.OnClick := @ActCrosstab; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('Data &tools (find/replace, duplicates...)...'); It.OnClick := @ActDataTools; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('&Design'); It.OnClick := @ActDesignQuery; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('&Run'); It.OnClick := @ActRunQuery; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('&Delete query'); It.OnClick := @ActDeleteQuery; M.Add(It);
  M := TMenuItem.Create(MM); M.Caption := Tr('&Report'); MM.Items.Add(M);
  It := TMenuItem.Create(M); It.Caption := Tr('&New report...'); It.OnClick := @ActNewReport; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('Report &wizard...'); It.OnClick := @ActReportWizard; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('&Design'); It.OnClick := @ActDesignReport; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('&Preview'); It.OnClick := @ActPreviewReport; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('&Delete report'); It.OnClick := @ActDeleteReport; M.Add(It);
  M := TMenuItem.Create(MM); M.Caption := Tr('&Letter'); MM.Items.Add(M);
  It := TMenuItem.Create(M); It.Caption := Tr('&New letter...'); It.OnClick := @ActNewLetter; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('&Edit letter'); It.OnClick := @ActEditLetter; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('&Preview'); It.OnClick := @ActPreviewLetter; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('Save as &Word (.docx)...'); It.Tag := 0; It.OnClick := @ActLetterFile; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('Save as &PDF...'); It.Tag := 1; It.OnClick := @ActLetterFile; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('&Delete letter'); It.OnClick := @ActDeleteLetter; M.Add(It);
  M := TMenuItem.Create(MM); M.Caption := Tr('&Script'); MM.Items.Add(M);
  It := TMenuItem.Create(M); It.Caption := Tr('New &module...'); It.OnClick := @ActNewModule; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('&Edit module'); It.OnClick := @ActEditModule; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('&Run procedure...'); It.OnClick := @ActRunProc; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('&Delete module'); It.OnClick := @ActDeleteModule; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := '-'; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('4&GL program (blocks)...'); It.OnClick := @ActFglEditor; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('New form over a table (&block)...'); It.OnClick := @ActBlockWizard; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('Continuous form &keys...'); It.OnClick := @ActKeyMap; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('New program from a &skeleton...'); It.OnClick := @ActSkelWizard; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('Suggest programs for a &table...'); It.OnClick := @ActSkelWizardData; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('New 4GL program in the &database...'); It.OnClick := @ActNewProgram; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('Edit 4GL program from the database'); It.OnClick := @ActEditProgram; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('Run 4GL program from the database'); It.OnClick := @ActRunProgram; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('Delete 4GL program from the database'); It.OnClick := @ActDeleteProgram; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := '-'; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('New ma&cro...'); It.OnClick := @ActNewMacro; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('E&dit macro'); It.OnClick := @ActEditMacro; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('&Run macro'); It.OnClick := @ActRunMacro; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('Delete mac&ro'); It.OnClick := @ActDeleteMacro; M.Add(It);
  M := TMenuItem.Create(MM); M.Caption := Tr('&Application'); MM.Items.Add(M);
  It := TMenuItem.Create(M); It.Caption := Tr('Create application from &database...'); It.OnClick := @ActGenerateApp; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('Run the &start form'); It.OnClick := @ActStartup; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('&Settings and export of the application...'); It.OnClick := @ActAppSettings; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := '-'; M.Add(It);
  Sub := TMenuItem.Create(M); Sub.Caption := Tr('&Business'); M.Add(Sub);
  It := TMenuItem.Create(Sub); It.Caption := Tr('&Business templates (invoices, warehouse, cash book...)...'); It.OnClick := @ActBusiness; Sub.Add(It);
  It := TMenuItem.Create(Sub); It.Caption := Tr('Company &data (for invoices and payment slips)...'); It.OnClick := @ActCompany; Sub.Add(It);
  It := TMenuItem.Create(Sub); It.Caption := Tr('Document &types...'); It.OnClick := @ActDocTypes; Sub.Add(It);
  if FiscalAvailable then begin It := TMenuItem.Create(Sub); It.Caption := Tr('&Fiscalization - settings...'); It.OnClick := @ActFiscal; Sub.Add(It); end;
  Sub := TMenuItem.Create(M); Sub.Caption := Tr('&Users and rights'); M.Add(Sub);
  It := TMenuItem.Create(Sub); It.Caption := Tr('&Users...'); It.OnClick := @ActUsers; Sub.Add(It);
  It := TMenuItem.Create(Sub); It.Caption := Tr('Object &rights...'); It.OnClick := @ActRights; Sub.Add(It);
  It := TMenuItem.Create(Sub); It.Caption := Tr('&Audit trail (who changed what)...'); It.OnClick := @ActAudit; Sub.Add(It);
  Sub := TMenuItem.Create(M); Sub.Caption := Tr('&Tools'); M.Add(Sub);
  It := TMenuItem.Create(Sub); It.Caption := Tr('&Menu wizard...'); It.OnClick := @ActSwitchboard; Sub.Add(It);
  It := TMenuItem.Create(Sub); It.Caption := Tr('&Task scheduler (copies, exports)...'); It.OnClick := @ActTasks; Sub.Add(It);
  Sub := TMenuItem.Create(M); Sub.Caption := Tr('&Look'); M.Add(Sub);
  It := TMenuItem.Create(Sub); It.Caption := Tr('&Light'); It.Tag := 1; It.OnClick := @ActTheme; Sub.Add(It);
  It := TMenuItem.Create(Sub); It.Caption := Tr('&Dark'); It.Tag := 2; It.OnClick := @ActTheme; Sub.Add(It);
  It := TMenuItem.Create(Sub); It.Caption := Tr('&System'); It.Tag := 0; It.OnClick := @ActTheme; Sub.Add(It);
  It := TMenuItem.Create(Sub); It.Caption := '-'; Sub.Add(It);
  Sub2 := TMenuItem.Create(Sub); Sub2.Caption := Tr('&Colour'); Sub.Add(Sub2);
  for I := 0 to BuiltinThemeCount - 1 do
  begin
    It := TMenuItem.Create(Sub2); It.Caption := Tr(BuiltinThemeName(I)); It.Tag := 100 + I; It.OnClick := @ActTheme; Sub2.Add(It);
  end;
  It := TMenuItem.Create(Sub); It.Caption := Tr('Shape: rounded'); It.Tag := 200; It.OnClick := @ActTheme; Sub.Add(It);
  It := TMenuItem.Create(Sub); It.Caption := Tr('Shape: sharp'); It.Tag := 201; It.OnClick := @ActTheme; Sub.Add(It);
  It := TMenuItem.Create(Sub); It.Caption := '-'; Sub.Add(It);
  It := TMenuItem.Create(Sub); It.Caption := Tr('Load theme from a file...'); It.Tag := 300; It.OnClick := @ActTheme; Sub.Add(It);
  It := TMenuItem.Create(Sub); It.Caption := Tr('Save the current theme into the application'); It.Tag := 301; It.OnClick := @ActTheme; Sub.Add(It);
  It := TMenuItem.Create(Sub); It.Caption := Tr('Remove the theme from the application'); It.Tag := 302; It.OnClick := @ActTheme; Sub.Add(It);
  It := TMenuItem.Create(M); It.Caption := '-'; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('Runtime / design (Ctrl+Shift+D)'); It.OnClick := @ActToggleMode; M.Add(It);
  M := TMenuItem.Create(MM); M.Caption := Tr('&Help'); MM.Items.Add(M);
  It := TMenuItem.Create(M); It.Caption := Tr('&Manual (tutorial and reference)'); It.ShortCut := ShortCut(VK_F1, []); It.OnClick := @ActManual; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('&How to... (recipes)'); It.Tag := 0; It.OnClick := @ActManualAt; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('4GL &recipes'); It.Tag := 1; It.OnClick := @ActManualAt; M.Add(It);
  It := TMenuItem.Create(M); It.Caption := Tr('Messages and &errors (FAQ)'); It.Tag := 2; It.OnClick := @ActManualAt; M.Add(It);
  FMainMenu := MM;
  Menu := MM;
  ApplyMenuIcons(MM);
  ApplyAppIcon;
  ApplySavedTheme;

  FStatus := TStatusBar.Create(Self);
  FStatus.Parent := Self;
  FStatus.SimplePanel := True;
  FStatus.SimpleText := Tr('No database is open');

  FNav := TPageControl.Create(Self);
  FNav.Parent := Self;
  FNav.Align := alLeft;
  FNav.Width := 250;
  FList := TListBox.Create(Self);
  FList.Parent := FNav.AddTabSheet;
  FList.Parent.Caption := Tr('Tables');
  FList.Align := alClient;
  FList.OnClick := @ListClick;
  FForms := TListBox.Create(Self);
  FForms.Parent := FNav.AddTabSheet;
  FForms.Parent.Caption := Tr('Forms');
  FForms.Align := alClient;
  FForms.OnDblClick := @ActRunForm;
  FQueries := TListBox.Create(Self);
  FQueries.Parent := FNav.AddTabSheet;
  FQueries.Parent.Caption := Tr('Queries');
  FQueries.Align := alClient;
  FQueries.OnDblClick := @ActRunQuery;
  FReports := TListBox.Create(Self);
  FReports.Parent := FNav.AddTabSheet;
  FReports.Parent.Caption := Tr('Reports');
  FReports.Align := alClient;
  FReports.OnDblClick := @ActPreviewReport;
  FLetters := TListBox.Create(Self);
  FLetters.Parent := FNav.AddTabSheet;
  FLetters.Parent.Caption := Tr('Letters');
  FLetters.Align := alClient;
  FLetters.OnDblClick := @ActPreviewLetter;
  FModules := TListBox.Create(Self);
  FModules.Parent := FNav.AddTabSheet;
  FModules.Parent.Caption := Tr('Modules');
  FModules.Align := alClient;
  FModules.OnDblClick := @ActEditModule;
  FMacros := TListBox.Create(Self);
  FMacros.Parent := FNav.AddTabSheet;
  FMacros.Parent.Caption := Tr('Macros');
  FMacros.Align := alClient;
  FMacros.OnDblClick := @ActRunMacro;
  FPrograms := TListBox.Create(Self);
  FPrograms.Parent := FNav.AddTabSheet;
  FPrograms.Parent.Caption := '4GL';
  FPrograms.Align := alClient;
  FPrograms.OnDblClick := @ActRunProgram;
  InitIconLists;
  DecorateNav;
  Sp := TSplitter.Create(Self);
  Sp.Parent := Self;
  Sp.Align := alLeft;
  Sp.Left := FNav.Width;
  FSplit := Sp;

  FPages := TPageControl.Create(Self);
  FPages.Parent := Self;
  FPages.Align := alClient;
  FPages.Images := IconList(16);
  FSheetTab := FPages.AddTabSheet; FSheetTab.Caption := Tr('Datasheet'); FSheetTab.ImageIndex := IconIndex('table');
  FDesignTab := FPages.AddTabSheet; FDesignTab.Caption := Tr('Design'); FDesignTab.ImageIndex := IconIndex('design');

  FSource := TDataSource.Create(Self);
  FGridView := TaGridView.Create(Self, FSheetTab, gkMain, PreferredProvider = 'own', False, FSource);

  Tb := TPanel.Create(Self);
  Tb.Parent := FDesignTab;
  Tb.Align := alTop;
  Tb.Height := 36;
  Tb.BevelOuter := bvNone;
  B := TButton.Create(Self); B.Parent := Tb; B.Caption := Tr('Add field'); B.SetBounds(4, 5, 110, 26); B.OnClick := @ActAddField;
  B := TButton.Create(Self); B.Parent := Tb; B.Caption := Tr('Delete field'); B.SetBounds(118, 5, 110, 26); B.OnClick := @ActDropField;
  B := TButton.Create(Self); B.Parent := Tb; B.Caption := Tr('Rename'); B.SetBounds(232, 5, 110, 26); B.OnClick := @ActRenameField;
  B := TButton.Create(Self); B.Parent := Tb; B.Caption := Tr('Field properties'); B.SetBounds(346, 5, 130, 26); B.OnClick := @ActFieldProps;

  FDesign := TStringGrid.Create(Self);
  FDesign.Parent := FDesignTab;
  FDesign.Align := alClient;
  FDesign.FixedRows := 1;
  FDesign.ColCount := 6;
  FDesign.Options := FDesign.Options - [goEditing] + [goRowSelect];
  FDesign.OnDrawCell := @DesignDrawCell;
  FDesign.Cells[0, 0] := Tr('Field');
  FDesign.Cells[1, 0] := Tr('Data type');
  FDesign.Cells[2, 0] := 'Format';
  FDesign.Cells[3, 0] := Tr('Default');
  FDesign.Cells[4, 0] := 'PK';
  FDesign.Cells[5, 0] := 'NOT NULL';
  FDesign.ColWidths[0] := 160;
  FDesign.ColWidths[2] := 160;
  FDesign.ColWidths[3] := 160;
end;

procedure TMainForm.CloseSheet;
begin
  FSource.DataSet := nil;
  FreeAndNil(FFormatter);
  FreeAndNil(FSheet);
end;

procedure TMainForm.OpenFile(const AFile: string);
begin
  CloseSheet;
  FDb.Open(AFile);
  FStatus.SimpleText := AFile;
  RefreshTables;
  ResetScripts;
  AfterOpen;
end;

{ ASpec: host:port/baza/korisnik; lozinka iz okolisne varijable PGPASSWORD. }
procedure TMainForm.OpenServerSpec(const ASpec: string; AKind: TDbKind);
var
  P: TStringList;
  HP, Host: string;
  Port: Integer;
begin
  P := TStringList.Create;
  try
    P.Delimiter := '/';
    P.StrictDelimiter := True;
    P.DelimitedText := ASpec;
    if P.Count < 3 then
      raise Exception.Create(Tr('Expecting host[:port]/database/user'));
    HP := P[0];
    if AKind = dkMaria then Port := 3306 else Port := 5432;
    Host := HP;
    if Pos(':', HP) > 0 then
    begin
      Host := Copy(HP, 1, Pos(':', HP) - 1);
      Port := StrToIntDef(Copy(HP, Pos(':', HP) + 1, MaxInt), Port);
    end;
    OpenServer(AKind, Host, Port, P[1], P[2],
      GetEnvironmentVariable(IfThen(AKind = dkMaria, 'MYSQL_PWD', 'PGPASSWORD')));
  finally
    P.Free;
  end;
end;

procedure TMainForm.OpenServer(AKind: TDbKind; const AHost: string; APort: Integer;
  const ADb, AUser, APwd: string);
begin
  CloseSheet;
  if AKind = dkMaria then
  begin
    FDb.OpenMaria(AHost, APort, ADb, AUser, APwd);
    FStatus.SimpleText := 'mariadb://' + AUser + '@' + AHost + ':' + IntToStr(APort) + '/' + ADb;
  end
  else
  begin
    FDb.OpenPostgres(AHost, APort, ADb, AUser, APwd);
    FStatus.SimpleText := 'postgres://' + AUser + '@' + AHost + ':' + IntToStr(APort) + '/' + ADb;
  end;
  RefreshTables;
  ResetScripts;
  AfterOpen;
end;

procedure TMainForm.ActConnect(Sender: TObject);
var
  Maria: Boolean;
  Host, Db, User, Pwd: string;
  Port: Integer;
begin
  Maria := False; Host := 'localhost'; Port := 5432; Db := ''; User := '';
  if not ConnectServerDialog(Self, Maria, Host, Port, Db, User, Pwd) then Exit;
  try
    if Maria then OpenServer(dkMaria, Host, Port, Db, User, Pwd)
    else OpenServer(dkPostgres, Host, Port, Db, User, Pwd);
  except
    on E: Exception do ShowMessage(Tr('Connection failed: ') + E.Message);
  end;
end;

procedure TMainForm.ActCopyToServer(Sender: TObject);
var
  Maria: Boolean;
  Host, Db, User, Pwd, Msg: string;
  Port: Integer;
  Dst: TAppDb;
  Log: TStringList;
  Ok: Boolean;
  I: Integer;
begin
  if not FDb.Connected then begin ShowMessage(Tr('First open the database you want to copy.')); Exit; end;
  Maria := False; Host := 'localhost'; Port := 5432; Db := ''; User := '';
  if not ConnectServerDialog(Self, Maria, Host, Port, Db, User, Pwd) then Exit;
  Dst := TAppDb.Create;
  Log := TStringList.Create;
  try
    try
      if Maria then Dst.OpenMaria(Host, Port, Db, User, Pwd)
      else Dst.OpenPostgres(Host, Port, Db, User, Pwd);
      Screen.Cursor := crHourGlass;
      try
        Ok := MigrateDb(FDb, Dst, Log);
      finally
        Screen.Cursor := crDefault;
      end;
    except
      on E: Exception do begin ShowMessage(Tr('Copying failed: ') + E.Message); Exit; end;
    end;
    Msg := '';
    for I := 0 to Log.Count - 1 do
      if (Pos('GREŠKA', Log[I]) > 0) or (Pos('UPOZORENJE', Log[I]) > 0) then Msg := Msg + Log[I] + LineEnding;
    if Ok then ShowMessage(Tr('The database was copied to the server (') + IntToStr(Log.Count) + Tr(' steps).') + LineEnding +
      Tr('Open it via Database > Connect to a server.'))
    else ShowMessage(Tr('Copying finished with problems:') + LineEnding + Msg);
  finally
    Log.Free;
    Dst.Free;
  end;
end;

procedure TMainForm.RefreshTables;
var
  L: TStringList;
begin
  L := FDb.UserTables;
  try
    FList.Items.Assign(L);
  finally
    L.Free;
  end;
  L := FDb.ListObjects('_sys_forms');
  try
    FForms.Items.Assign(L);
  finally
    L.Free;
  end;
  L := FDb.ListObjects('_sys_queries');
  try
    FQueries.Items.Assign(L);
  finally
    L.Free;
  end;
  L := FDb.ListObjects('_sys_reports');
  try
    FReports.Items.Assign(L);
  finally
    L.Free;
  end;
  L := FDb.ListObjects('_sys_letters');
  try
    FLetters.Items.Assign(L);
  finally
    L.Free;
  end;
  L := FDb.ListObjects('_sys_modules');
  try
    FModules.Items.Assign(L);
  finally
    L.Free;
  end;
  L := FDb.ListObjects('_sys_macros');
  try
    FMacros.Items.Assign(L);
  finally
    L.Free;
  end;
  L := FDb.ListObjects('_sys_programs');
  try
    FPrograms.Items.Assign(L);
  finally
    L.Free;
  end;
end;

procedure TMainForm.ShowTable(const AName: string);
var
  Info: TZQuery;
  R: Integer;
  Metas: TFPObjectList;
  I: Integer;
  M: TaFieldMeta;
  Typ, Fmt, Def: string;
begin
  CloseSheet;
  FSheet := FDb.NewQuery('SELECT * FROM ' + FDb.QuoteId(AName));
  FSheet.Open;
  FFormatter := TaDatasetFormatter.Create(FSheet, FDb.LoadFieldMetas(AName));
  FSource.DataSet := FSheet;

  Metas := FDb.LoadFieldMetas(AName);
  Info := FDb.TableInfo(AName);
  try
    FDesign.RowCount := 1;
    R := 1;
    while not Info.EOF do
    begin
      FDesign.RowCount := R + 1;
      Typ := Info.FieldByName('type').AsString;
      Fmt := '';
      Def := '';
      for I := 0 to Metas.Count - 1 do
      begin
        M := TaFieldMeta(Metas[I]);
        if SameText(M.FieldName, Info.FieldByName('name').AsString) then
        begin
          Typ := LogicalNames[M.LType];
          Fmt := M.Format;
          Def := M.DefaultExpr;
          Break;
        end;
      end;
      FDesign.Cells[0, R] := Info.FieldByName('name').AsString;
      FDesign.Cells[1, R] := Typ;
      FDesign.Cells[2, R] := Fmt;
      FDesign.Cells[3, R] := Def;
      if Info.FieldByName('pk').AsInteger > 0 then FDesign.Cells[4, R] := 'X' else FDesign.Cells[4, R] := '';
      if Info.FieldByName('notnull').AsInteger > 0 then FDesign.Cells[5, R] := 'X' else FDesign.Cells[5, R] := '';
      Inc(R);
      Info.Next;
    end;
  finally
    Info.Free;
    Metas.Free;
  end;
end;

procedure TMainForm.ListClick(Sender: TObject);
begin
  if FList.ItemIndex >= 0 then ShowTable(FList.Items[FList.ItemIndex]);
end;

function TMainForm.MakeNorthwindFile(const AFile: string; ALog: TStrings): Boolean;
begin
  CloseSheet;
  if FileExists(AFile) then DeleteFile(AFile);
  FDb.Open(AFile);
  Result := BuildNorthwind(FDb, ALog);
  FStatus.SimpleText := AFile;
  RefreshTables;
  ResetScripts;
end;

function TMainForm.MakeShowcaseFile(const AFile: string; ALog: TStrings; AUnified: Boolean): Boolean;
begin
  CloseSheet;
  if FileExists(AFile) then DeleteFile(AFile);
  FDb.Open(AFile);
  if AUnified then Result := BuildShowcaseUnified(FDb, ALog) else Result := BuildShowcase(FDb, ALog);
  FStatus.SimpleText := AFile;
  RefreshTables;
  ResetScripts;
end;

function TMainForm.MakeAppFromSpecFile(const ASpecFile, ADbFile: string; ALog: TStrings; AReplace: Boolean): Boolean;
var
  Txt: TStringList;
begin
  CloseSheet;
  Txt := TStringList.Create;
  try
    Txt.LoadFromFile(ASpecFile);
    { grafika pita za prepisivanje; naredbena linija primjenjuje opis na postojecu bazu }
    if AReplace and FileExists(ADbFile) then DeleteFile(ADbFile);
    FDb.Open(ADbFile);
    Result := BuildAppFromSpecText(FDb, Txt.Text, ALog, ExtractFilePath(ASpecFile));
  finally
    Txt.Free;
  end;
  FStatus.SimpleText := ADbFile;
  RefreshTables;
  ResetScripts;
end;

function TMainForm.ImportMdbFile(const AMdb, ADbFile: string; ALog: TStrings): Boolean;
var
  Report: TStringList;
  Spec: string;
begin
  CloseSheet;
  Report := TStringList.Create;
  try
    if FileExists(ADbFile) then DeleteFile(ADbFile);
    FDb.Open(ADbFile);
    try
      Result := ImportMdb(FDb, AMdb, ALog, Report, Spec);
    except
      on E: Exception do begin ALog.Add(Tr('ERROR: ') + Copy(E.Message, 1, 400)); Result := False; end;
    end;
    if Result then
    begin
      { forme, popisi i izbornik slazu se iz uvezenih tablica }
      ALog.Add('--- aplikacija iz uvezenih tablica ---');
      BuildAppFromSpecText(FDb, Spec, ALog);
      with TStringList.Create do
      try
        Text := Spec;
        SaveToFile(ChangeFileExt(ADbFile, '.opis'));
      finally
        Free;
      end;
    end;
    if Report.Count > 0 then
    begin
      Report.Insert(0, 'Neuvezeno iz ' + ExtractFileName(AMdb) + Tr(' (complete by hand or with an application description):'));
      Report.SaveToFile(ChangeFileExt(ADbFile, '.uvoz.txt'));
      ALog.Add(Tr('Report on what was not imported (') + IntToStr(Report.Count - 1) + ' stavki): ' + ChangeFileExt(ADbFile, '.uvoz.txt'));
    end;
  finally
    Report.Free;
  end;
  FStatus.SimpleText := ADbFile;
  RefreshTables;
  ResetScripts;
end;

procedure TMainForm.ActImportMdb(Sender: TObject);
var
  O: TOpenDialog;
  D: TSaveDialog;
  Log: TStringList;
begin
  if not MdbToolsAvailable then
  begin
    ShowMessage(Tr('Import from Access needs the mdbtools program (mdb-tables, mdb-export...).') + LineEnding +
      'Instaliraj paket mdbtools ili postavi MDBTOOLS_DIR na mapu s tim programima.');
    Exit;
  end;
  O := TOpenDialog.Create(nil);
  D := TSaveDialog.Create(nil);
  Log := TStringList.Create;
  try
    O.Title := Tr('Access database');
    O.Filter := Tr('Access (*.mdb;*.accdb)|*.mdb;*.accdb|All files|*');
    if not O.Execute then Exit;
    D.Title := Tr('Database of the new application');
    D.Filter := 'Baza (*.db)|*.db';
    D.DefaultExt := 'db';
    D.FileName := ChangeFileExt(ExtractFileName(O.FileName), '.db');
    D.Options := D.Options + [ofOverwritePrompt];
    if not D.Execute then Exit;
    Screen.Cursor := crHourGlass;
    try
      if ImportMdbFile(O.FileName, D.FileName, Log) then
        ShowMessage(Tr('The import is finished.') + LineEnding + LineEnding + Log.Text)
      else
        ShowMessage(Tr('The import failed:') + LineEnding + LineEnding + Log.Text);
    finally
      Screen.Cursor := crDefault;
    end;
  finally
    Log.Free;
    D.Free;
    O.Free;
  end;
end;

procedure TMainForm.ActAppFromSpec(Sender: TObject);
var
  O: TOpenDialog;
  D: TSaveDialog;
  Log: TStringList;
begin
  O := TOpenDialog.Create(nil);
  D := TSaveDialog.Create(nil);
  Log := TStringList.Create;
  try
    O.Title := Tr('Application description');
    O.Filter := Tr('Application description (*.opis;*.txt)|*.opis;*.txt|All files|*');
    if not O.Execute then Exit;
    D.Title := Tr('Database of the new application');
    D.Filter := 'Baza (*.db)|*.db';
    D.DefaultExt := 'db';
    D.FileName := ChangeFileExt(ExtractFileName(O.FileName), '.db');
    D.Options := D.Options + [ofOverwritePrompt];
    if not D.Execute then Exit;
    Screen.Cursor := crHourGlass;
    try
      if MakeAppFromSpecFile(O.FileName, D.FileName, Log) then
        ShowMessage(Tr('The application was created.') + LineEnding + LineEnding + Log.Text)
      else
        ShowMessage(Tr('The description was not accepted:') + LineEnding + LineEnding + Log.Text);
    finally
      Screen.Cursor := crDefault;
    end;
  finally
    Log.Free;
    D.Free;
    O.Free;
  end;
end;

procedure TMainForm.ActShowcase2(Sender: TObject);
var
  D: TSaveDialog;
  Log: TStringList;
begin
  D := TSaveDialog.Create(nil);
  Log := TStringList.Create;
  try
    D.Filter := 'Baza (*.db)|*.db';
    D.DefaultExt := 'db';
    D.FileName := 'TrgovinaJadran2.db';
    D.Options := D.Options + [ofOverwritePrompt];
    if not D.Execute then Exit;
    Screen.Cursor := crHourGlass;
    try
      if MakeShowcaseFile(D.FileName, Log, True) then
        ShowMessage(Tr('Trgovina Jadran 2 was created.') + LineEnding + LineEnding + Tr('Run it as an application (--runtime) or Application -> Run the start form.'))
      else
        ShowMessage(Tr('Something failed:') + LineEnding + Log.Text);
    finally
      Screen.Cursor := crDefault;
    end;
  finally
    Log.Free;
    D.Free;
  end;
end;

procedure TMainForm.ActShowcase(Sender: TObject);
var
  D: TSaveDialog;
  Log: TStringList;
begin
  D := TSaveDialog.Create(nil);
  Log := TStringList.Create;
  try
    D.Filter := 'Baza (*.db)|*.db';
    D.DefaultExt := 'db';
    D.FileName := 'TrgovinaJadran.db';
    D.Options := D.Options + [ofOverwritePrompt];
    if not D.Execute then Exit;
    Screen.Cursor := crHourGlass;
    try
      if MakeShowcaseFile(D.FileName, Log) then
        ShowMessage(Tr('Trgovina Jadran was created.') + LineEnding + LineEnding + Tr('Run the form "Izbornik" (Forms tab).'))
      else
        ShowMessage(Tr('Something failed:') + LineEnding + Log.Text);
    finally
      Screen.Cursor := crDefault;
    end;
  finally
    Log.Free;
    D.Free;
  end;
end;

function TMainForm.MakeBlocksDemoFile(const AFile: string; ALog: TStrings): Boolean;
begin
  CloseSheet;
  if FileExists(AFile) then DeleteFile(AFile);
  FDb.Open(AFile);
  Result := BuildBlocksDemo(FDb, ALog);
  FStatus.SimpleText := AFile;
  RefreshTables;
  ResetScripts;
end;

procedure TMainForm.ActBlocksDemo(Sender: TObject);
var
  D: TSaveDialog;
  Log: TStringList;
begin
  D := TSaveDialog.Create(nil);
  Log := TStringList.Create;
  try
    D.Title := Tr('Where to save the example with blocks');
    D.Filter := 'TyphAccess baza (*.db)|*.db';
    D.DefaultExt := 'db';
    D.FileName := 'MaliObrt.db';
    D.Options := D.Options + [ofOverwritePrompt];
    if not D.Execute then Exit;
    if MakeBlocksDemoFile(D.FileName, Log) then
      ShowMessage(Tr('The example was created.') + LineEnding + LineEnding + Tr('Open the Macros tab, choose a macro and "Edit macro", then the "Blocks" button.'))
    else
      ShowMessage(Tr('Something failed:') + LineEnding + Log.Text);
  finally
    Log.Free;
    D.Free;
  end;
end;

procedure TMainForm.ActNorthwind(Sender: TObject);
var
  D: TSaveDialog;
  Log: TStringList;
begin
  D := TSaveDialog.Create(nil);
  Log := TStringList.Create;
  try
    D.Title := Tr('Where to save Northwind');
    D.Filter := 'TyphAccess baza (*.db)|*.db';
    D.DefaultExt := 'db';
    D.FileName := 'Northwind.db';
    D.Options := D.Options + [ofOverwritePrompt];
    if not D.Execute then Exit;
    if MakeNorthwindFile(D.FileName, Log) then
      ShowMessage(Tr('Northwind was created.') + LineEnding + LineEnding + Tr('Open the Forms tab and run "Izbornik".'))
    else
      ShowMessage(Tr('Something failed:') + LineEnding + Log.Text);
  finally
    Log.Free;
    D.Free;
  end;
end;

procedure TMainForm.ActManualAt(Sender: TObject);
const
  ManualAnchors: array[0..2] of string = ('kako-da-recepti', 'gl-recepti', 'poruke-i-pogreške-najčešća-pitanja');
var
  L: TStringList;
  F: string;
begin
  F := IncludeTrailingPathDelimiter(GetTempDir(False)) + 'typhaccess-prirucnik.html';
  L := TStringList.Create;
  try
    L.Text := ManualHtml;
    L.SaveToFile(F);
  finally
    L.Free;
  end;
  { otvara priručnik na odabranom poglavlju (sidro u adresi) }
  OpenURL('file://' + F + '#' + ManualAnchors[TMenuItem(Sender).Tag]);
end;

procedure TMainForm.ActManual(Sender: TObject);
var
  L: TStringList;
  F: string;
begin
  F := IncludeTrailingPathDelimiter(GetTempDir(False)) + 'typhaccess-prirucnik.html';
  L := TStringList.Create;
  try
    L.Text := ManualHtml;
    L.SaveToFile(F);
  finally
    L.Free;
  end;
  OpenDocument(F);
end;

procedure TMainForm.ActFileStore(Sender: TObject);
begin
  if not FDb.Connected then begin ShowMessage(Tr('First open or create a database.')); Exit; end;
  RunFileStoreDialog(Self, FDb);
end;

procedure TMainForm.ActCatalog(Sender: TObject);
var
  Dom: TCatDomain;
  Act: Integer;
  D: TSaveDialog;
  Log: TStringList;
  Ok: Boolean;
begin
  Act := ChooseCatalogDomain(Self, FDb.Connected, Dom);
  if (Act = 0) or (Dom = nil) then Exit;
  Log := TStringList.Create;
  try
    if Act = 1 then
    begin
      D := TSaveDialog.Create(nil);
      try
        D.Title := Tr('Where to save the database "') + Dom.Title + '"';
        D.Filter := 'TyphAccess baza (*.db)|*.db';
        D.DefaultExt := 'db';
        D.FileName := Dom.Id + '.db';
        D.Options := D.Options + [ofOverwritePrompt];
        if not D.Execute then Exit;
        CloseSheet;
        if FileExists(D.FileName) then DeleteFile(D.FileName);
        FDb.Open(D.FileName);
        FStatus.SimpleText := D.FileName;
      finally
        D.Free;
      end;
    end;
    CloseSheet;
    Ok := BuildCatalogDomain(FDb, Dom, Act = 1, True, Log);
    RefreshTables;
    ResetScripts;
    AfterOpen;
    if Ok then ShowMessage(Tr('Database "') + Dom.Title + Tr('" was created (') + IntToStr(Dom.Tables.Count) + Tr(' tables, forms and sample data).'))
    else ShowMessage(Tr('Finished with problems:') + LineEnding + Log.Text);
  finally
    Log.Free;
  end;
end;

procedure TMainForm.ShotPrepare(const ATable: string);
var
  I: Integer;
begin
  I := FList.Items.IndexOf(ATable);
  if I < 0 then Exit;
  FList.ItemIndex := I;
  ShowTable(ATable);
end;

procedure TMainForm.ActCatalogApply(Sender: TObject);
var
  N: string;
  Log: TStringList;
  C: Integer;
begin
  if FList.ItemIndex < 0 then begin ShowMessage(Tr('Choose a table on the Tables tab.')); Exit; end;
  N := FList.Items[FList.ItemIndex];
  Log := TStringList.Create;
  try
    C := ApplyCatalogToTable(FDb, N, Log);
    if C = 0 then ShowMessage(Tr('No field of the table ') + N + Tr(' needed to be completed from the catalog.') + LineEnding + Log.Text)
    else ShowMessage(Tr('Fields completed: ') + IntToStr(C) + LineEnding + Log.Text);
  finally
    Log.Free;
  end;
end;

procedure TMainForm.ActCatalogSnap(Sender: TObject);
begin
  if not FDb.Connected then begin ShowMessage(Tr('First open a database.')); Exit; end;
  RunCatalogSnapshot(Self, FDb);
end;

procedure TMainForm.ActCatalogDoc(Sender: TObject);
var
  D: TSaveDialog;
  L: TStringList;
begin
  D := TSaveDialog.Create(nil);
  L := TStringList.Create;
  try
    D.Title := Tr('Schema catalog documentation');
    D.Filter := 'HTML (*.html)|*.html';
    D.DefaultExt := 'html';
    D.FileName := 'katalog-shema.html';
    D.Options := D.Options + [ofOverwritePrompt];
    if not D.Execute then Exit;
    L.Text := CatalogHtml(Catalog);
    L.SaveToFile(D.FileName);
    ShowMessage(Tr('Saved: ') + D.FileName);
  finally
    L.Free;
    D.Free;
  end;
end;

procedure TMainForm.ActNewDb(Sender: TObject);
var
  D: TSaveDialog;
begin
  D := TSaveDialog.Create(nil);
  try
    D.Filter := 'TyphAccess baza (*.db)|*.db';
    D.DefaultExt := 'db';
    if D.Execute then OpenFile(D.FileName);
  finally
    D.Free;
  end;
end;

procedure TMainForm.ActOpenDb(Sender: TObject);
var
  D: TOpenDialog;
begin
  D := TOpenDialog.Create(nil);
  try
    D.Filter := Tr('SQLite database (*.db;*.sqlite)|*.db;*.sqlite|All files|*');
    if D.Execute then OpenFile(D.FileName);
  finally
    D.Free;
  end;
end;

procedure TMainForm.ActNewTable(Sender: TObject);
var
  N: string;
  Fl: TFieldDefs2;
  I: Integer;
begin
  if not FDb.Connected then begin ShowMessage(Tr('First open or create a database.')); Exit; end;
  if not DesignTableDialog(Self, FDb, N, Fl) then Exit;
  try
    try
      FDb.CreateTable(N, Fl);
    except
      on E: Exception do begin ShowMessage(E.Message); Exit; end;
    end;
  finally
    for I := 0 to High(Fl) do Fl[I].Meta.Free;
  end;
  RefreshTables;
  FList.ItemIndex := FList.Items.IndexOf(N);
  ListClick(nil);
end;

procedure TMainForm.ActDropTable(Sender: TObject);
var
  N: string;
begin
  if FList.ItemIndex < 0 then Exit;
  N := FList.Items[FList.ItemIndex];
  if MessageDlg(Tr('Delete table ') + N + '?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  CloseSheet;
  FDb.DropTable(N);
  RefreshTables;
end;

function TMainForm.SelectedForm: string;
begin
  Result := '';
  if FForms.ItemIndex >= 0 then Result := FForms.Items[FForms.ItemIndex]
  else ShowMessage(Tr('Choose a form on the Forms tab.'));
end;

function TMainForm.LoadFormDef(const AName: string): TaFormDef;
begin
  Result := TaFormDef.Create;
  Result.FromJson(FDb.LoadObject('_sys_forms', AName));
  Result.Name := AName;
end;

procedure TMainForm.ActNewForm(Sender: TObject);
var
  N: string;
  D: TaFormDef;
  Ds: TaFormDesigner;
begin
  if not FDb.Connected then begin ShowMessage(Tr('First open or create a database.')); Exit; end;
  N := '';
  if not InputQuery(Tr('New form'), Tr('Form name:'), N) then Exit;
  N := Trim(N);
  if N = '' then Exit;
  if FDb.LoadObject('_sys_forms', N) <> '' then begin ShowMessage(Tr('The form already exists.')); Exit; end;
  D := TaFormDef.Create;
  D.Name := N;
  D.Caption := N;
  Ds := TaFormDesigner.CreateDesigner(Self, FDb, D);
  try
    Ds.ShowModal;
  finally
    Ds.Free;
  end;
  RefreshTables;
end;

procedure TMainForm.ActDesignForm(Sender: TObject);
var
  N: string;
  Ds: TaFormDesigner;
begin
  N := SelectedForm;
  if N = '' then Exit;
  Ds := TaFormDesigner.CreateDesigner(Self, FDb, LoadFormDef(N));
  try
    Ds.ShowModal;
  finally
    Ds.Free;
  end;
end;

procedure TMainForm.ActRunForm(Sender: TObject);
var
  N: string;
  R: TaFormRunner;
begin
  N := SelectedForm;
  if (N = '') or not Allowed('_sys_forms', N) then Exit;
  CloseSheet;
  R := TaFormRunner.CreateRunner(Self, FDb, LoadFormDef(N));
  try
    R.ShowModal;
  finally
    R.Free;
  end;
end;

procedure TMainForm.ActDeleteForm(Sender: TObject);
var
  N: string;
begin
  N := SelectedForm;
  if N = '' then Exit;
  if MessageDlg(Tr('Delete form ') + N + '?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  FDb.DeleteObject('_sys_forms', N);
  RefreshTables;
end;

function TMainForm.SelectedQuery: string;
begin
  Result := '';
  if FQueries.ItemIndex >= 0 then Result := FQueries.Items[FQueries.ItemIndex]
  else ShowMessage(Tr('Choose a query on the Queries tab.'));
end;

function TMainForm.CurrentTable: string;
begin
  Result := '';
  if FList.ItemIndex >= 0 then Result := FList.Items[FList.ItemIndex]
  else ShowMessage(Tr('Choose a table on the Tables tab.'));
end;

procedure TMainForm.ActNewQuery(Sender: TObject);
var
  N: string;
  Q: TaQueryDesigner;
begin
  if not FDb.Connected then begin ShowMessage(Tr('First open or create a database.')); Exit; end;
  N := '';
  if not InputQuery(Tr('New query'), Tr('Query name:'), N) then Exit;
  N := Trim(N);
  if N = '' then Exit;
  if FDb.LoadObject('_sys_queries', N) <> '' then begin ShowMessage(Tr('The query already exists.')); Exit; end;
  CloseSheet;
  Q := TaQueryDesigner.CreateDesigner(Self, FDb, N);
  try
    Q.ShowModal;
  finally
    Q.Free;
  end;
  RefreshTables;
end;

procedure TMainForm.ActDesignQuery(Sender: TObject);
var
  N: string;
  Q: TaQueryDesigner;
begin
  N := SelectedQuery;
  if N = '' then Exit;
  CloseSheet;
  Q := TaQueryDesigner.CreateDesigner(Self, FDb, N);
  try
    Q.ShowModal;
  finally
    Q.Free;
  end;
end;

procedure TMainForm.ActRunQuery(Sender: TObject);
var
  N: string;
  Q: TaQueryDesigner;
begin
  N := SelectedQuery;
  if N = '' then Exit;
  CloseSheet;
  Q := TaQueryDesigner.CreateDesigner(Self, FDb, N);
  try
    Q.RunQuery;
    Q.ShowModal;
  finally
    Q.Free;
  end;
end;

procedure TMainForm.ActDeleteQuery(Sender: TObject);
var
  N: string;
begin
  N := SelectedQuery;
  if N = '' then Exit;
  if MessageDlg(Tr('Delete query ') + N + '?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  FDb.DeleteObject('_sys_queries', N);
  RefreshTables;
end;

procedure TMainForm.ActAddField(Sender: TObject);
var
  T, N: string;
  D: TFieldDef;
  M: TaFieldMeta;
  Pk, Nn: Boolean;
  RT, RF, RD: string;
begin
  T := CurrentTable;
  if T = '' then Exit;
  N := '';
  Pk := False;
  Nn := False;
  RT := ''; RF := ''; RD := '';
  M := TaFieldMeta.Create;
  try
    if not EditField(Self, FDb, N, M, Pk, Nn, RT, RF, RD, True) then Exit;
    D.Name := N;
    D.SqlType := PhysicalType(M.LType);
    D.PrimaryKey := False;
    D.NotNull := False;
    D.Meta := M;
    D.RefTable := RT;
    D.RefField := RF;
    D.OnDelete := RD;
    try
      FDb.AddColumn(T, D);
    except
      on E: Exception do begin ShowMessage(E.Message); Exit; end;
    end;
  finally
    M.Free;
  end;
  ShowTable(T);
end;

procedure TMainForm.ActFieldProps(Sender: TObject);
var
  T, N: string;
  M: TaFieldMeta;
  Pk, Nn: Boolean;
  RT, RF, RD, OldRT, OldRF, OldRD: string;
  Fks, New: TaFkDefs;
  I: Integer;
begin
  T := CurrentTable;
  if (T = '') or (FDesign.Row < 1) then Exit;
  N := FDesign.Cells[0, FDesign.Row];
  M := FDb.FindFieldMeta(T, N);
  if M = nil then
  begin
    M := TaFieldMeta.Create;
    M.LType := ltText;
    if SameText(FDesign.Cells[1, FDesign.Row], 'INTEGER') then M.LType := ltInteger
    else if SameText(FDesign.Cells[1, FDesign.Row], 'REAL') then M.LType := ltDecimal;
    M.Decimals := 2;
  end;
  Fks := FDb.GetFks(T);
  OldRT := ''; OldRF := ''; OldRD := '';
  for I := 0 to High(Fks) do
    if SameText(Fks[I].FromCol, N) then
    begin
      OldRT := Fks[I].RefTable; OldRF := Fks[I].RefCol; OldRD := Fks[I].OnDelete;
    end;
  RT := OldRT; RF := OldRF; RD := OldRD;
  try
    Pk := False;
    Nn := False;
    if not EditField(Self, FDb, N, M, Pk, Nn, RT, RF, RD, False) then Exit;
    M.TableName := T;
    M.FieldName := N;
    FDb.SaveFieldMeta(M);
    if (RT <> OldRT) or (RF <> OldRF) or (not SameText(RD, OldRD) and (RT <> '')) then
    begin
      SetLength(New, 0);
      for I := 0 to High(Fks) do
        if not SameText(Fks[I].FromCol, N) then
        begin
          SetLength(New, Length(New) + 1);
          New[High(New)] := Fks[I];
        end;
      if RT <> '' then
      begin
        SetLength(New, Length(New) + 1);
        New[High(New)].FromCol := N;
        New[High(New)].RefTable := RT;
        New[High(New)].RefCol := RF;
        New[High(New)].OnDelete := RD;
        New[High(New)].OnUpdate := '';
      end;
      CloseSheet;
      try
        FDb.SetFks(T, New);
      except
        on E: Exception do ShowMessage(E.Message);
      end;
    end;
  finally
    M.Free;
  end;
  ShowTable(T);
end;

procedure TMainForm.ActDropField(Sender: TObject);
var
  T, N: string;
begin
  T := CurrentTable;
  if T = '' then Exit;
  if FDesign.Row < 1 then Exit;
  N := FDesign.Cells[0, FDesign.Row];
  if MessageDlg(Tr('Delete field ') + N + '?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  CloseSheet;
  try
    FDb.DropColumn(T, N);
  except
    on E: Exception do ShowMessage(E.Message);
  end;
  ShowTable(T);
end;

procedure TMainForm.ActRenameField(Sender: TObject);
var
  T, N, NewName: string;
begin
  T := CurrentTable;
  if T = '' then Exit;
  if FDesign.Row < 1 then Exit;
  N := FDesign.Cells[0, FDesign.Row];
  NewName := N;
  if not InputQuery(Tr('Rename field'), Tr('New name:'), NewName) then Exit;
  CloseSheet;
  try
    FDb.RenameColumn(T, N, Trim(NewName));
  except
    on E: Exception do ShowMessage(E.Message);
  end;
  ShowTable(T);
end;

function TMainForm.SelectedReport: string;
begin
  Result := '';
  if FReports.ItemIndex >= 0 then Result := FReports.Items[FReports.ItemIndex]
  else ShowMessage(Tr('Choose a report on the Reports tab.'));
end;

function TMainForm.LoadReportDef(const AName: string): TaReportDef;
begin
  Result := TaReportDef.Create;
  Result.FromJson(FDb.LoadObject('_sys_reports', AName));
  Result.Name := AName;
end;

function TMainForm.SelectedLetter: string;
begin
  Result := '';
  if FLetters.ItemIndex >= 0 then Result := FLetters.Items[FLetters.ItemIndex]
  else ShowMessage(Tr('Choose a letter on the Letters tab.'));
end;

procedure TMainForm.ActNewLetter(Sender: TObject);
var
  N: string;
begin
  if not FDb.Connected then begin ShowMessage(Tr('First open or create a database.')); Exit; end;
  N := '';
  if not InputQuery(Tr('New letter'), Tr('Letter name:'), N) then Exit;
  N := Trim(N);
  if N = '' then Exit;
  if FDb.LoadObject('_sys_letters', N) <> '' then begin ShowMessage(Tr('The letter already exists.')); Exit; end;
  EditLetter(Self, FDb, N, True);
  RefreshTables;
end;

procedure TMainForm.ActEditLetter(Sender: TObject);
var
  N: string;
begin
  N := SelectedLetter;
  if N = '' then Exit;
  EditLetter(Self, FDb, N, False);
  RefreshTables;
end;

procedure TMainForm.ActPreviewLetter(Sender: TObject);
var
  N: string;
begin
  N := SelectedLetter;
  if N = '' then Exit;
  CloseSheet;
  PreviewLetter(Self, FDb, N);
end;

{ Tag 0 = Word, 1 = PDF }
procedure TMainForm.ActLetterFile(Sender: TObject);
var
  N, Err: string;
  Dlg: TSaveDialog;
  Pdf: Boolean;
begin
  N := SelectedLetter;
  if N = '' then Exit;
  Pdf := TMenuItem(Sender).Tag = 1;
  Dlg := TSaveDialog.Create(nil);
  try
    if Pdf then begin Dlg.Filter := 'PDF (*.pdf)|*.pdf'; Dlg.DefaultExt := 'pdf'; Dlg.FileName := N + '.pdf'; end
    else begin Dlg.Filter := 'Word dokument (*.docx)|*.docx'; Dlg.DefaultExt := 'docx'; Dlg.FileName := N + '.docx'; end;
    Dlg.Options := Dlg.Options + [ofOverwritePrompt];
    if not Dlg.Execute then Exit;
    if ExportLetterNamed(FDb, N + ' > ' + Dlg.FileName, Err) then ShowMessage(Tr('Saved: ') + Dlg.FileName)
    else ShowMessage(Tr('Export failed: ') + Err);
  finally
    Dlg.Free;
  end;
end;

procedure TMainForm.ActDeleteLetter(Sender: TObject);
var
  N: string;
begin
  N := SelectedLetter;
  if N = '' then Exit;
  if MessageDlg(Tr('Delete letter ') + N + '?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  FDb.DeleteObject('_sys_letters', N);
  RefreshTables;
end;

procedure TMainForm.ActNewReport(Sender: TObject);
var
  N: string;
  D: TaReportDef;
  Ds: TaReportDesigner;
begin
  if not FDb.Connected then begin ShowMessage(Tr('First open or create a database.')); Exit; end;
  N := '';
  if not InputQuery(Tr('New report'), Tr('Report name:'), N) then Exit;
  N := Trim(N);
  if N = '' then Exit;
  if FDb.LoadObject('_sys_reports', N) <> '' then begin ShowMessage(Tr('The report already exists.')); Exit; end;
  D := TaReportDef.Create;
  D.Name := N;
  D.Title := N;
  Ds := TaReportDesigner.CreateDesigner(Self, FDb, D);
  try
    Ds.ShowModal;
  finally
    Ds.Free;
  end;
  RefreshTables;
end;

procedure TMainForm.ActDesignReport(Sender: TObject);
var
  N: string;
  Ds: TaReportDesigner;
begin
  N := SelectedReport;
  if N = '' then Exit;
  Ds := TaReportDesigner.CreateDesigner(Self, FDb, LoadReportDef(N));
  try
    Ds.ShowModal;
  finally
    Ds.Free;
  end;
end;

procedure TMainForm.ActPreviewReport(Sender: TObject);
var
  N: string;
  D: TaReportDef;
begin
  N := SelectedReport;
  if (N = '') or not Allowed('_sys_reports', N) then Exit;
  CloseSheet;
  FDb.ClearParams;
  D := LoadReportDef(N);
  try
    ShowReportPreview(Self, FDb, D);
  finally
    D.Free;
  end;
end;

procedure TMainForm.ActDeleteReport(Sender: TObject);
var
  N: string;
begin
  N := SelectedReport;
  if N = '' then Exit;
  if MessageDlg(Tr('Delete report ') + N + '?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  FDb.DeleteObject('_sys_reports', N);
  RefreshTables;
end;

procedure TMainForm.ActImport(Sender: TObject);
begin
  if not FDb.Connected then begin ShowMessage(Tr('First open or create a database.')); Exit; end;
  CloseSheet;
  if RunImportDialog(Self, FDb) then RefreshTables;
end;

procedure TMainForm.ActExport(Sender: TObject);
var
  Def: string;
begin
  if not FDb.Connected then begin ShowMessage(Tr('First open or create a database.')); Exit; end;
  Def := '';
  if FList.ItemIndex >= 0 then Def := FList.Items[FList.ItemIndex];
  RunExportDialog(Self, FDb, Def);
end;

procedure TMainForm.ActFormWizard(Sender: TObject);
var
  N: string;
  Ds: TaFormDesigner;
begin
  if not FDb.Connected then begin ShowMessage(Tr('First open or create a database.')); Exit; end;
  N := RunFormWizard(Self, FDb);
  if N = '' then Exit;
  RefreshTables;
  Ds := TaFormDesigner.CreateDesigner(Self, FDb, LoadFormDef(N));
  try
    Ds.ShowModal;
  finally
    Ds.Free;
  end;
end;

procedure TMainForm.ActReportWizard(Sender: TObject);
var
  N: string;
  Ds: TaReportDesigner;
begin
  if not FDb.Connected then begin ShowMessage(Tr('First open or create a database.')); Exit; end;
  N := RunReportWizard(Self, FDb);
  if N = '' then Exit;
  RefreshTables;
  Ds := TaReportDesigner.CreateDesigner(Self, FDb, LoadReportDef(N));
  try
    Ds.ShowModal;
  finally
    Ds.Free;
  end;
end;

procedure TMainForm.ActRelations(Sender: TObject);
begin
  if not FDb.Connected then begin ShowMessage(Tr('First open or create a database.')); Exit; end;
  CloseSheet;
  ShowRelationsView(Self, FDb);
  RefreshTables;
end;

type
  { Context for macros and scripts started from the main window: the verbs
    that open things, since there is no current form. }
  TMainContext = class(TaScriptContext)
  public
    Main: TMainForm;
    procedure DoOther(const AVerb, AArg: string); override;
  end;

procedure TMainContext.DoOther(const AVerb, AArg: string);
var
  RepName, SortOpt, FormName, FormArgs: string;
  Js: string;
  Fd: TaFormDef;
  Rd: TaReportDef;
  R: TaFormRunner;
begin
  if (AVerb = 'openform') and Main.ShellOpenForm(AArg) then Exit;
  if AVerb = 'openform' then
  begin
    SplitFormAction(AArg, FormName, FormArgs);
    Js := Db.LoadObject('_sys_forms', FormName);
    if Js = '' then begin ScriptNotify(Tr('There is no form: ') + FormName); Exit; end;
    if not CanRun(Db, '_sys_forms', FormName) then begin ScriptNotify(Tr('You do not have the right to open the form ') + FormName); Exit; end;
    Fd := TaFormDef.Create;
    Fd.FromJson(Js);
    Fd.Name := FormName;
    R := TaFormRunner.CreateRunner(Main, Db, Fd);
    try
      if FormArgs <> '' then R.OpenWith(FormArgs);
      R.ShowModal;
    finally
      R.Free;
    end;
  end
  else if AVerb = 'openreport' then
  begin
    SplitReportArg(AArg, RepName, SortOpt);
    Js := Db.LoadObject('_sys_reports', RepName);
    if Js = '' then begin ScriptNotify(Tr('There is no report: ') + RepName); Exit; end;
    if not CanRun(Db, '_sys_reports', RepName) then begin ScriptNotify(Tr('You do not have the right to open the report ') + RepName); Exit; end;
    Rd := TaReportDef.Create;
    try
      Rd.FromJson(Js);
      Rd.Name := RepName;
      Db.ClearParams;
      ShowReportPreview(Main, Db, Rd, SortOpt);
    finally
      Rd.Free;
    end;
  end
  else if AVerb = 'exportpdf' then
  begin
    if not ExportReportPdfNamed(Db, AArg, RepName) then ScriptNotify(Tr('The PDF was not created: ') + RepName);
  end
  else if AVerb = 'exporthtml' then
  begin
    if not ExportReportHtmlNamed(Db, AArg, RepName) then ScriptNotify(Tr('The HTML was not created: ') + RepName);
  end
  else if AVerb = 'exportletter' then
  begin
    if not ExportLetterNamed(Db, AArg, RepName) then ScriptNotify(Tr('The letter was not exported: ') + RepName);
  end
  else if AVerb = 'openletter' then
  begin
    SplitReportArg(AArg, RepName, SortOpt);     { naziv; za jedan primatelj: Naziv@kljuc }
    if Pos('@', AArg) > 0 then PreviewLetter(Main, Db, Trim(Copy(AArg, 1, Pos('@', AArg) - 1)), Trim(Copy(AArg, Pos('@', AArg) + 1, MaxInt)))
    else PreviewLetter(Main, Db, Trim(AArg));
  end
  else inherited DoOther(AVerb, AArg);
end;

function MainCtx(AMain: TMainForm; ADb: TAppDb; var ACtx: TaScriptContext): TaScriptContext;
begin
  if ACtx = nil then
  begin
    ACtx := TMainContext.Create(ADb);
    TMainContext(ACtx).Main := AMain;
  end;
  Result := ACtx;
end;

procedure TMainForm.RunAutoExec;
begin
  if FDb.LoadObject('_sys_macros', 'AutoExec') = '' then Exit;
  RunMacroByName(MainCtx(Self, FDb, FMainCtx), 'AutoExec');
end;

procedure TMainForm.ActNewModule(Sender: TObject);
var
  N: string;
begin
  if not FDb.Connected then begin ShowMessage(Tr('First open or create a database.')); Exit; end;
  N := '';
  if not InputQuery(Tr('New module'), Tr('Module name:'), N) then Exit;
  N := Trim(N);
  if N = '' then Exit;
  if FDb.LoadObject('_sys_modules', N) <> '' then begin ShowMessage(Tr('The module already exists.')); Exit; end;
  EditModule(Self, FDb, N);
  RefreshTables;
end;

procedure TMainForm.ActEditModule(Sender: TObject);
begin
  if FModules.ItemIndex < 0 then begin ShowMessage(Tr('Choose a module on the Modules tab.')); Exit; end;
  EditModule(Self, FDb, FModules.Items[FModules.ItemIndex]);
end;

procedure TMainForm.ActRunProc(Sender: TObject);
var
  N: string;
  R: Variant;
begin
  if not FDb.Connected then Exit;
  N := '';
  if not InputQuery(Tr('Run procedure'), Tr('Procedure name (without parameters):'), N) then Exit;
  if not Scripts(FDb).CallProc(MainCtx(Self, FDb, FMainCtx), Trim(N), [], R) then
    if Scripts(FDb).LastError = '' then ShowMessage(Tr('There is no procedure ') + N + '.');
end;

procedure TMainForm.ActDeleteModule(Sender: TObject);
begin
  if FModules.ItemIndex < 0 then Exit;
  if MessageDlg(Tr('Delete the module?'), mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  FDb.DeleteObject('_sys_modules', FModules.Items[FModules.ItemIndex]);
  RefreshTables;
end;

procedure TMainForm.ActNewMacro(Sender: TObject);
var
  N: string;
begin
  if not FDb.Connected then begin ShowMessage(Tr('First open or create a database.')); Exit; end;
  N := '';
  if not InputQuery(Tr('New macro'), Tr('Macro name (AutoExec runs when the database is opened):'), N) then Exit;
  N := Trim(N);
  if N = '' then Exit;
  if FDb.LoadObject('_sys_macros', N) <> '' then begin ShowMessage(Tr('The macro already exists.')); Exit; end;
  EditMacro(Self, FDb, N, True);
  RefreshTables;
end;

procedure TMainForm.ActFglEditor(Sender: TObject);
begin
  EditFglProgram(Self, FDb, '');
end;

procedure TMainForm.ActSkelWizard(Sender: TObject);
begin
  if RunSkeletonWizard(Self, FDb) <> '' then RefreshTables;
end;

procedure TMainForm.ActBlockWizard(Sender: TObject);
begin
  if RunBlockWizard(Self, FDb) <> '' then RefreshTables;
end;

procedure TMainForm.ActKeyMap(Sender: TObject);
var
  Ctx: TaEditContext;
  J, Err: string;
begin
  Ctx := TaEditContext.Create(FDb, Self);
  try
    J := FDb.LoadSetting('tipke.json');
    if J = '' then J := GlobalKeyMap.ToJson;
    if EditKeyMap(Ctx, J) then
    begin
      FDb.SaveSetting('tipke.json', J);
      GlobalKeyMap.FromJson(J, Err);
    end;
  finally
    Ctx.Free;
  end;
end;

procedure TMainForm.ActSkelWizardData(Sender: TObject);
begin
  if RunSkeletonWizard(Self, FDb, '*') <> '' then RefreshTables;
end;

{ popis objekata ima traku s ikonama (kao bocna traka u razvojnim okruzenjima); kartice su skrivene,
  a naziv odabrane skupine je u naslovu iznad popisa }
procedure TMainForm.InitIconLists;
var
  L: array[0..7] of TListBox;
  I: Integer;
begin
  L[0] := FList; L[1] := FForms; L[2] := FQueries; L[3] := FReports;
  L[4] := FLetters; L[5] := FModules; L[6] := FMacros; L[7] := FPrograms;
  for I := 0 to 7 do
  begin
    L[I].Style := lbOwnerDrawFixed;
    L[I].ItemHeight := 22;
    L[I].OnDrawItem := @ListDraw;
  end;
end;

procedure TMainForm.ListDraw(Control: TWinControl; Index: Integer; ARect: TRect; State: TOwnerDrawState);
var
  K: string;
begin
  if Control = FList then K := 'table'
  else if Control = FForms then K := 'form'
  else if Control = FQueries then K := 'query'
  else if Control = FReports then K := 'report'
  else if Control = FLetters then K := 'letter'
  else if Control = FModules then K := 'module'
  else if Control = FMacros then K := 'macro'
  else K := 'program';
  if (Index < 0) or (Index >= TListBox(Control).Items.Count) then Exit;
  DrawIconItem(TListBox(Control), Index, ARect, State, ObjectIconName(K, TListBox(Control).Items[Index]));
end;

procedure TMainForm.DesignDrawCell(Sender: TObject; aCol, aRow: Integer; aRect: TRect; aState: TGridDrawState);
var
  G: TStringGrid;
  P: TPortableNetworkGraphic;
  Y: Integer;
begin
  if (aCol <> 0) or (aRow < 1) then Exit;
  G := TStringGrid(Sender);
  with G.Canvas do
  begin
    if gdSelected in aState then begin if IconDarkMode then begin Brush.Color := $5F3A1E; Font.Color := $F0E8E2; end else begin Brush.Color := $F3DCC4; Font.Color := clBlack; end; end
    else begin Brush.Color := G.Color; Font.Color := G.Font.Color; end;
    FillRect(aRect);
    P := IconPng(FieldIconName(G.Cells[0, aRow], G.Cells[1, aRow]), 16);
    if P <> nil then Draw(aRect.Left + 4, aRect.Top + (aRect.Bottom - aRect.Top - 16) div 2, P);
    Y := aRect.Top + (aRect.Bottom - aRect.Top - TextHeight('Ag')) div 2;
    TextOut(aRect.Left + 26, Y, G.Cells[0, aRow]);
  end;
end;

procedure TMainForm.DecorateNav;
const
  Icons: array[0..7] of string = ('table', 'form', 'query', 'report', 'letter', 'module', 'macro', 'program');
var
  I: Integer;
  Pg: TTabSheet;
  H: TLabel;
  Title: string;
  P: TPortableNetworkGraphic;
begin
  FRail := TPanel.Create(Self);
  FRail.Parent := Self;
  FRail.Align := alLeft;
  FRail.Left := 0;
  FRail.Width := 44;
  FRail.BevelOuter := bvNone;
  FRail.Caption := '';
  FNav.Left := 60;
  for I := 0 to FNav.PageCount - 1 do
  begin
    Pg := FNav.Pages[I];
    Title := Pg.Caption;
    H := TLabel.Create(Pg);
    H.Parent := Pg;
    H.Align := alTop;
    H.Caption := '  ' + Title;
    H.Font.Style := [fsBold];
    H.Height := 24;
    H.Layout := tlCenter;
    H.Color := $F5F0EA;
    H.Transparent := False;
    FRailBtn[I] := TSpeedButton.Create(FRail);
    FRailBtn[I].Parent := FRail;
    FRailBtn[I].SetBounds(2, 4 + I * 42, 40, 40);
    FRailBtn[I].Flat := True;
    FRailBtn[I].GroupIndex := 1;
    FRailBtn[I].AllowAllUp := False;
    FRailBtn[I].Tag := I;
    FRailBtn[I].Hint := Title;
    FRailBtn[I].ShowHint := True;
    P := IconPng(Icons[I], 24);
    if P <> nil then FRailBtn[I].Glyph.Assign(P);
    FRailBtn[I].OnClick := @RailClick;
    Pg.Caption := '';
  end;
  FRailBtn[0].Down := True;
  FNav.ShowTabs := False;
end;

procedure TMainForm.RailClick(Sender: TObject);
begin
  FNav.ActivePageIndex := TSpeedButton(Sender).Tag;
end;

procedure TMainForm.ActNewProgram(Sender: TObject);
var
  N: string;
begin
  N := '';
  if not InputQuery(Tr('New 4GL program'), Tr('Program name:'), N) then Exit;
  N := Trim(N);
  if N = '' then Exit;
  if FDb.LoadObject('_sys_programs', N) <> '' then begin ShowMessage(Tr('A program with that name already exists.')); Exit; end;
  FDb.SaveObject('_sys_programs', N, 'MAIN' + LineEnding + '  DISPLAY "Pozdrav"' + LineEnding + 'END MAIN' + LineEnding);
  EditFglProgram(Self, FDb, 'db:' + N);
  RefreshTables;
end;

procedure TMainForm.ActEditProgram(Sender: TObject);
begin
  if FPrograms.ItemIndex < 0 then begin ShowMessage(Tr('Choose a program on the 4GL tab.')); Exit; end;
  EditFglProgram(Self, FDb, 'db:' + FPrograms.Items[FPrograms.ItemIndex]);
  RefreshTables;
end;

procedure TMainForm.ActRunProgram(Sender: TObject);
var
  T: string;
begin
  if FPrograms.ItemIndex < 0 then begin ShowMessage(Tr('Choose a program on the 4GL tab.')); Exit; end;
  T := FDb.LoadObject('_sys_programs', FPrograms.Items[FPrograms.ItemIndex]);
  RunFglText(FDb, T, False);
end;

procedure TMainForm.ActDeleteProgram(Sender: TObject);
begin
  if FPrograms.ItemIndex < 0 then Exit;
  if MessageDlg(Tr('Delete 4GL program "') + FPrograms.Items[FPrograms.ItemIndex] + '"?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  FDb.DeleteObject('_sys_programs', FPrograms.Items[FPrograms.ItemIndex]);
  RefreshTables;
end;

procedure TMainForm.ActEditMacro(Sender: TObject);
begin
  if FMacros.ItemIndex < 0 then begin ShowMessage(Tr('Choose a macro on the Macros tab.')); Exit; end;
  EditMacro(Self, FDb, FMacros.Items[FMacros.ItemIndex]);
end;

procedure TMainForm.ActRunMacro(Sender: TObject);
begin
  if FMacros.ItemIndex < 0 then begin ShowMessage(Tr('Choose a macro on the Macros tab.')); Exit; end;
  if not Allowed('_sys_macros', FMacros.Items[FMacros.ItemIndex]) then Exit;
  CloseSheet;
  RunMacroByName(MainCtx(Self, FDb, FMainCtx), FMacros.Items[FMacros.ItemIndex]);
  RefreshTables;
end;

procedure TMainForm.ActDeleteMacro(Sender: TObject);
begin
  if FMacros.ItemIndex < 0 then Exit;
  if MessageDlg(Tr('Delete the macro?'), mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  FDb.DeleteObject('_sys_macros', FMacros.Items[FMacros.ItemIndex]);
  RefreshTables;
end;

function TMainForm.Allowed(const AKind, AName: string): Boolean;
begin
  Result := CanRun(FDb, AKind, AName);
  if not Result then
    ShowMessage(Tr('You do not have the right to open "') + AName + Tr('" (required role: ') +
      RoleNames[GetObjectRight(FDb, AKind, AName)] + ').');
end;

{ Runtime mode hides everything that edits the application: menu, tables,
  queries, modules and the datasheet. Only forms, reports and macros remain. }
procedure TMainForm.ApplyMode;
var
  S: TaAppSettings;
begin
  S := LoadAppSettings(FDb);
  if FRuntime then
  begin
    Menu := nil;
    FNav.Pages[0].TabVisible := False;
    FNav.Pages[2].TabVisible := False;
    FNav.Pages[4].TabVisible := False;
    FNav.ActivePageIndex := 1;
    FRailBtn[0].Visible := False; FRailBtn[2].Visible := False; FRailBtn[4].Visible := False;
    FRailBtn[1].Down := True;
    FPages.Visible := False;
    FSplit.Visible := False;
    FNav.Align := alClient;
    if S.Title <> '' then Caption := S.Title else Caption := 'TyphAccess';
  end
  else
  begin
    Menu := FMainMenu;
    FNav.Pages[0].TabVisible := True;
    FNav.Pages[2].TabVisible := True;
    FNav.Pages[4].TabVisible := True;
    FRailBtn[0].Visible := True; FRailBtn[2].Visible := True; FRailBtn[4].Visible := True;
    FNav.Align := alLeft;
    FNav.Width := 250;
    StopShell;
    FRail.Visible := True;
    FNav.Visible := True;
    FSplit.Visible := True;
    FPages.Visible := True;
    Caption := 'TyphAccess';
  end;
end;

procedure TMainForm.AfterOpen;
var
  S: TaAppSettings;
begin
  if not RunLogin(Self, FDb) then
  begin
    FDb.Close;
    RefreshTables;
    if FLaunchRuntime then Close;
    Exit;
  end;
  ApplyThemeFromApp(FDb);
  S := LoadAppSettings(FDb);
  FRuntime := (SessionRole < arAdmin) or FLaunchRuntime or (S.RuntimeOnly and not FLaunchDesign);
  ApplyMode;
  RunAutoExec;
  if FRuntime then StartShell;
end;

{ Radni prostor aplikacije u radu: zaglavlje, bocni izbornik i kartice (svaka forma je jedna kartica). }
procedure TMainForm.StartShell;
var
  S: TaAppSettings;
  Js, Txt: string;
  Fd: TaFormDef;
  I, MW: Integer;
  MR: Boolean;
  HC, HF: TColor;
  C: TaControlDef;
begin
  S := LoadAppSettings(FDb);
  if FShell = nil then
  begin
    FShell := TaShell.CreateShell(Self, FDb);
    FShell.Parent := Self;
    FShell.OnAction := @ShellAction;
    FShell.OnLogout := @ShellLogout;
    OnCloseQuery := @ShellCloseQuery;
  end;
  FShell.Visible := True;
  FRail.Visible := False;
  FNav.Visible := False;
  FPages.Visible := False;
  FSplit.Visible := False;
  if S.Title <> '' then FShell.SetTitle(S.Title) else FShell.SetTitle('TyphAccess');
  if SessionUser <> '' then FShell.SetUserText(SessionUser + ' (' + RoleNames[SessionRole] + ')') else FShell.SetUserText('');
  OpenFormHook := @ShellOpenForm;
  { izbornik: pocetna forma moze biti izbornik (kontrola SideMenu ili gumbi) ili obicna forma }
  Txt := '';
  Fd := nil;
  if S.StartupForm <> '' then
  begin
    Js := FDb.LoadObject('_sys_forms', S.StartupForm);
    if Js <> '' then
    begin
      Fd := TaFormDef.Create;
      Fd.FromJson(Js);
      for I := 0 to Fd.Count - 1 do
      begin
        C := Fd[I];
        if C.Kind = 'SideMenu' then begin Txt := C.RowSource; Break; end;
        if (C.Kind = 'Label') and (Pos('lblGrupa', C.Name) = 1) then Txt := Txt + '# ' + C.Caption + LineEnding
        else if (C.Kind = 'Button') and (C.OnClick <> '') then Txt := Txt + C.Caption + '|' + C.OnClick + LineEnding;
      end;
    end;
  end;
  { predlozak glavne forme odreduje izgled ljuske: boja zaglavlja i naslova, sirina i strana izbornika }
  MW := 250; MR := False; HC := clNone; HF := clNone;
  if Fd <> nil then
    for I := 0 to Fd.Count - 1 do
    begin
      C := Fd[I];
      if (C.Kind = 'SideMenu') and (DockOfDef(C) in [alLeft, alRight]) then
      begin
        if C.Width > 0 then MW := C.Width;
        MR := DockOfDef(C) = alRight;
      end
      else if (C.Kind = 'Rectangle') and (C.Name = 'pnlZaglavlje') and (C.GetX('backColor') <> '') then HC := HexToColor(C.GetX('backColor'), clNone)
      else if (C.Kind = 'Label') and (C.Name = 'lblNaslov') and (C.GetX('foreColor') <> '') then HF := HexToColor(C.GetX('foreColor'), clNone);
    end;
  FShell.SetLook(MW, MR, HC, HF);
  if Txt <> '' then FShell.SetMenuText(Txt) else FShell.BuildDefaultMenu;
  if (Txt = '') and (S.StartupForm <> '') and (Fd <> nil) then FShell.OpenForm(S.StartupForm);
  Fd.Free;
end;

procedure TMainForm.StopShell;
begin
  OpenFormHook := nil;
  if FShell <> nil then FShell.Visible := False;
end;

function TMainForm.ShellOpenForm(const AName: string): Boolean;
begin
  Result := (FShell <> nil) and FShell.Visible;
  if Result then FShell.OpenForm(AName);
end;

procedure TMainForm.ShellAction(const AAction: string);
var
  P: Integer;
  Verb, Arg: string;
  R: Variant;
begin
  P := Pos(':', AAction);
  if P > 0 then begin Verb := LowerCase(Trim(Copy(AAction, 1, P - 1))); Arg := Trim(Copy(AAction, P + 1, MaxInt)); end
  else begin Verb := LowerCase(Trim(AAction)); Arg := ''; end;
  if Verb = 'close' then Close
  else if Verb = 'macro' then
  begin
    if CanRun(FDb, '_sys_macros', Arg) then RunMacroByName(MainCtx(Self, FDb, FMainCtx), Arg)
    else ShowMessage(Tr('You do not have the right to run the macro ') + Arg);
  end
  else if Verb = 'fgl' then
  begin
    if FDb.LoadObject('_sys_programs', Arg) = '' then ShowMessage(Tr('There is no 4GL program: ') + Arg)
    else RunFglText(FDb, FDb.LoadObject('_sys_programs', Arg), False);
  end
  else if Verb = 'run' then
  begin
    if not Scripts(FDb).CallProc(MainCtx(Self, FDb, FMainCtx), Arg, [], R) then
      if Scripts(FDb).LastError = '' then ShowMessage(Tr('There is no procedure ') + Arg + '.');
  end
  else MainCtx(Self, FDb, FMainCtx).DoOther(Verb, Arg);
end;

procedure TMainForm.ShellLogout(Sender: TObject);
begin
  if (FShell = nil) or not FShell.CloseAll then Exit;
  if not RunLogin(Self, FDb) then begin Close; Exit; end;
  StartShell;
end;

procedure TMainForm.ShellCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if (FShell <> nil) and FShell.Visible then CanClose := FShell.CloseAll;
end;

procedure TMainForm.OpenStartupForm;
var
  S: TaAppSettings;
  Js: string;
  Fd: TaFormDef;
  R: TaFormRunner;
begin
  S := LoadAppSettings(FDb);
  if S.StartupForm = '' then Exit;
  Js := FDb.LoadObject('_sys_forms', S.StartupForm);
  if Js = '' then begin ShowMessage(Tr('The start form does not exist: ') + S.StartupForm); Exit; end;
  if not Allowed('_sys_forms', S.StartupForm) then Exit;
  CloseSheet;
  Fd := TaFormDef.Create;
  Fd.FromJson(Js);
  Fd.Name := S.StartupForm;
  R := TaFormRunner.CreateRunner(Self, FDb, Fd);
  try
    Hide;
    R.ShowModal;
  finally
    R.Free;
  end;
  { closing the start form ends a finished application }
  if FRuntime then Close else Show;
end;

procedure TMainForm.MainShow(Sender: TObject);
var
  I: Integer;
  A: string;
  ExpLog: TStringList;
  FileArg, PgSpec, MariaSpec, RunSpec, CheckSpec, DocSpec, ShotSpec, DomSpec, PredSpec, RefSpec, SlipSpec, BtSpec, DepthSpec, StakeSpec, ParseSpec, DivSpec, ModelSpec, EngineSpec, SeasonSpec, ThrSpec, ValSpec, ExportSpec, ExpErr, EspSpec: string;
  ConsoleRun: Boolean;
  Log: TStringList;
begin
  if FShown then Exit;
  PgSpec := '';
  MariaSpec := '';
  FShown := True;
  FileArg := '';
  RunSpec := '';
  PredSpec := '';
  SlipSpec := '';
  BtSpec := '';
  ModelSpec := ''; EngineSpec := ''; SeasonSpec := ''; ThrSpec := ''; ValSpec := ''; ExportSpec := ''; EspSpec := '';
  ParseSpec := '';
  DivSpec := '';
  StakeSpec := '';
  DepthSpec := '';
  RefSpec := '';
  CheckSpec := '';
  DocSpec := '';
  ShotSpec := '';
  DomSpec := '';
  ConsoleRun := False;
  for I := 1 to ParamCount do
  begin
    A := ParamStr(I);
    if A = '--runtime' then FLaunchRuntime := True
    else if A = '--design' then FLaunchDesign := True
    else if A = '--run-tasks' then FRunTasksOnly := True
    else if A = '--make-northwind' then FMakeNorthwind := True
    else if A = '--make-blocks-demo' then FMakeBlocksDemo := True
    else if A = '--make-showcase' then FMakeShowcase := True
    else if A = '--make-showcase2' then FMakeShowcase2 := True
    else if Copy(A, 1, 11) = '--make-app=' then FSpecArg := Copy(A, 12, MaxInt)
    else if Copy(A, 1, 13) = '--import-mdb=' then FMdbArg := Copy(A, 14, MaxInt)
    else if Copy(A, 1, 5) = '--pg=' then PgSpec := Copy(A, 6, MaxInt)
    else if Copy(A, 1, 8) = '--maria=' then MariaSpec := Copy(A, 9, MaxInt)
    else if Copy(A, 1, 6) = '--run=' then RunSpec := Copy(A, 7, MaxInt)
    else if Copy(A, 1, 10) = '--predict=' then PredSpec := Copy(A, 11, MaxInt)
    else if Copy(A, 1, 11) = '--backtest=' then BtSpec := Copy(A, 12, MaxInt)
    else if Copy(A, 1, 8) = '--parse=' then ParseSpec := Copy(A, 9, MaxInt)
    else if Copy(A, 1, 6) = '--div=' then DivSpec := Copy(A, 7, MaxInt)
    else if Copy(A, 1, 8) = '--stake=' then StakeSpec := Copy(A, 9, MaxInt)
    else if Copy(A, 1, 8) = '--depth=' then DepthSpec := Copy(A, 9, MaxInt)
    else if Copy(A, 1, 8) = '--slips=' then SlipSpec := Copy(A, 9, MaxInt)
    else if Copy(A, 1, 6) = '--ref=' then RefSpec := Copy(A, 7, MaxInt)
    else if Copy(A, 1, 9) = '--export=' then ExportSpec := Copy(A, 10, MaxInt)
    else if Copy(A, 1, 10) = '--esphome=' then EspSpec := Copy(A, 11, MaxInt)
    else if Copy(A, 1, 11) = '--validate=' then ValSpec := Copy(A, 12, MaxInt)
    else if Copy(A, 1, 9) = '--engine=' then EngineSpec := Copy(A, 10, MaxInt)
    else if Copy(A, 1, 9) = '--season=' then SeasonSpec := Copy(A, 10, MaxInt)
    else if Copy(A, 1, 12) = '--threshold=' then ThrSpec := Copy(A, 13, MaxInt)
    else if Copy(A, 1, 8) = '--model=' then ModelSpec := Copy(A, 9, MaxInt)
    else if Copy(A, 1, 8) = '--check=' then CheckSpec := Copy(A, 9, MaxInt)
    else if Copy(A, 1, 14) = '--screenshots=' then ShotSpec := Copy(A, 15, MaxInt)
    else if Copy(A, 1, 14) = '--make-domain=' then DomSpec := Copy(A, 15, MaxInt)
    else if A = '--console' then ConsoleRun := True
    else if Copy(A, 1, 14) = '--catalog-doc=' then DocSpec := Copy(A, 15, MaxInt)
    else if (Copy(A, 1, 2) <> '--') and (FileArg = '') then FileArg := A;
  end;
  if DocSpec <> '' then
  begin
    Log := TStringList.Create;
    try
      Log.Text := CatalogHtml(Catalog);
      Log.SaveToFile(ExpandFileName(DocSpec));
      WriteLn('Spremljeno: ', ExpandFileName(DocSpec));
    finally
      Log.Free;
    end;
    Application.Terminate;
    Exit;
  end;
  if CheckSpec <> '' then
  begin
    Log := TStringList.Create;
    try
      if FglCheckFile(ExpandFileName(CheckSpec), Log) = 0 then WriteLn('U redu: ', CheckSpec)
      else
      begin
        WriteLn(Log.Text);
        ExitCode := 1;
      end;
    finally
      Log.Free;
    end;
    Application.Terminate;
    Exit;
  end;
  if DomSpec <> '' then
  begin
    { izradi bazu iz domene kataloga: --make-domain=budzet izlaz.db }
    Log := TStringList.Create;
    try
      if Catalog.FindDomain(DomSpec) = nil then WriteLn(Tr('There is no domain: '), DomSpec)
      else
      begin
        if FileArg = '' then FileArg := DomSpec + '.db';
        FileArg := ExpandFileName(FileArg);
        if FileExists(FileArg) then DeleteFile(FileArg);
        FDb.Open(FileArg);
        if BuildCatalogDomain(FDb, Catalog.FindDomain(DomSpec), True, True, Log) then WriteLn(Tr('Created: '), FileArg)
        else WriteLn('GREŠKA');
        WriteLn(Log.Text);
      end;
    finally
      Log.Free;
    end;
    Application.Terminate;
    Exit;
  end;
  if FMakeShowcase then
  begin
    Log := TStringList.Create;
    try
      if FileArg = '' then FileArg := 'TrgovinaJadran.db';
      if MakeShowcaseFile(ExpandFileName(FileArg), Log) then WriteLn(Tr('Created: '), ExpandFileName(FileArg))
      else WriteLn('GREŠKA');
      WriteLn(Log.Text);
    finally
      Log.Free;
    end;
    Application.Terminate;
    Exit;
  end;
  if FMdbArg <> '' then
  begin
    Log := TStringList.Create;
    try
      if FileArg = '' then FileArg := ChangeFileExt(ExtractFileName(FMdbArg), '.db');
      if ImportMdbFile(ExpandFileName(FMdbArg), ExpandFileName(FileArg), Log) then WriteLn(Tr('Created: '), ExpandFileName(FileArg))
      else WriteLn('GREŠKA');
      WriteLn(Log.Text);
    finally
      Log.Free;
    end;
    Application.Terminate;
    Exit;
  end;
  if FSpecArg <> '' then
  begin
    Log := TStringList.Create;
    try
      if FileArg = '' then FileArg := 'Aplikacija.db';
      if MakeAppFromSpecFile(ExpandFileName(FSpecArg), ExpandFileName(FileArg), Log, False) then WriteLn(Tr('Created: '), ExpandFileName(FileArg))
      else WriteLn('GREŠKA');
      WriteLn(Log.Text);
    finally
      Log.Free;
    end;
    Application.Terminate;
    Exit;
  end;
  if FMakeShowcase2 then
  begin
    Log := TStringList.Create;
    try
      if FileArg = '' then FileArg := 'TrgovinaJadran2.db';
      if MakeShowcaseFile(ExpandFileName(FileArg), Log, True) then WriteLn(Tr('Created: '), ExpandFileName(FileArg))
      else WriteLn('GREŠKA');
      WriteLn(Log.Text);
    finally
      Log.Free;
    end;
    Application.Terminate;
    Exit;
  end;
  if FMakeBlocksDemo then
  begin
    Log := TStringList.Create;
    try
      if FileArg = '' then FileArg := 'MaliObrt.db';
      if MakeBlocksDemoFile(ExpandFileName(FileArg), Log) then WriteLn(Tr('Created: '), ExpandFileName(FileArg))
      else WriteLn('GREŠKA');
      WriteLn(Log.Text);
    finally
      Log.Free;
    end;
    Application.Terminate;
    Exit;
  end;
  if FMakeNorthwind then
  begin
    Log := TStringList.Create;
    try
      if FileArg = '' then FileArg := 'Northwind.db';
      if MakeNorthwindFile(ExpandFileName(FileArg), Log) then WriteLn(Tr('Created: '), ExpandFileName(FileArg))
      else WriteLn('GREŠKA'); 
      WriteLn(Log.Text);
    finally
      Log.Free;
    end;
    Application.Terminate;
    Exit;
  end;
  if PgSpec <> '' then OpenServerSpec(PgSpec, dkPostgres)
  else if MariaSpec <> '' then OpenServerSpec(MariaSpec, dkMaria)
  else if (FileArg <> '') and FileExists(FileArg) then OpenFile(ExpandFileName(FileArg));
  if ShotSpec <> '' then
  begin
    { snimke zaslona za priručnik: pokreće se iz petlje poruka kad se prozor iscrta }
    ScheduleScreenshots(Self, FDb, ExpandFileName(ShotSpec), @ShotPrepare);
    Exit;
  end;
  if ParseSpec <> '' then
  begin
    { provjera citanja HNS stranice ili UEFA teksta: --parse=hnl:datoteka ili --parse=uefa:datoteka, uz --div= i (UEFA) --depth=godina pocetka }
    WriteParsed(Copy(ParseSpec, 1, Pos(':', ParseSpec) - 1), Copy(ParseSpec, Pos(':', ParseSpec) + 1, MaxInt), DivSpec, StrToIntDef(DepthSpec, 0));
    Application.Terminate;
    Exit;
  end;
  if EspSpec <> '' then
  begin
    { ESPHome konfiguracije svih pogona u mapu, bez prozora: --esphome=mapa }
    ExpLog := TStringList.Create;
    try
      WriteLn('OK;', EspHomeExportAll(FDb, EspSpec, ExpLog));
      Write(ExpLog.Text);
    finally
      ExpLog.Free;
    end;
    Application.Terminate;
    Exit;
  end;
  if ExportSpec <> '' then
  begin
    { izvjesce u datoteku bez prozora: --export="Naziv>datoteka.pdf" ili ".html" }
    if LowerCase(ExtractFileExt(ExportSpec)) = '.html' then
    begin
      if ExportReportHtmlNamed(FDb, ExportSpec, ExpErr) then WriteLn('OK;', ExportSpec) else WriteLn('ERR;', ExpErr);
    end
    else if ExportReportPdfNamed(FDb, ExportSpec, ExpErr) then WriteLn('OK;', ExportSpec) else WriteLn('ERR;', ExpErr);
    Application.Terminate;
    Exit;
  end;
  if ValSpec <> '' then
  begin
    try
      ValidateSeasonWrite(FDb, ValSpec, SeasonSpec);
    except
      on E: Exception do WriteLn('ERR;', E.Message);
    end;
    Application.Terminate;
    Exit;
  end;
  if EngineSpec <> '' then
  begin
    EngineBacktestWriteReport(FDb, EngineSpec, SeasonSpec, ParseDot(ThrSpec, 0.75), 3, 1.0);
    Application.Terminate;
    Exit;
  end;
  if BtSpec <> '' then
  begin
    { backtest (provjera pariteta s Pythonom): lige odvojene zarezom, --depth=N zadnjih sezona }
    BtWriteReport(FDb, BtSpec.Split([',']), StrToIntDef(DepthSpec, 0), 1, BtStartingBankroll, StrToFloatDef(StakeSpec, 1.0, DefaultFormatSettings), ModelSpec);
    Application.Terminate;
    Exit;
  end;
  if SlipSpec <> '' then
  begin
    { listici za kolo (bez spremanja): sustav je prijelazi|poluvrijeme|elita|miks|top; provjera pariteta s Pythonom }
    WriteGeneratedSlips(FDb, SlipSpec, RefSpec, TransitionDefaultMin);
    Application.Terminate;
    Exit;
  end;
  if PredSpec <> '' then
  begin
    { predvidanja: svaki redak datoteke je "liga;domaci;gosti"; ispis redak po utakmici (provjera pariteta s Pythonom) }
    Log := TStringList.Create;
    try
      Log.LoadFromFile(ExpandFileName(PredSpec));
      WritePredictions(FDb, Log, RefSpec, ModelSpec);
    finally
      Log.Free;
    end;
    Application.Terminate;
    Exit;
  end;
  if RunSpec <> '' then
  begin
    { 4GL program: bez glavnog prozora }
    ExitCode := RunFglFile(FDb, ExpandFileName(RunSpec), ConsoleRun);
    Application.Terminate;
    Exit;
  end;
  if FRunTasksOnly then
  begin
    { bez prozora: izvrsi zadatke koji su na redu, ispisi rezultat i izadi }
    Log := TStringList.Create;
    try
      if FDb.Connected then
      begin
        RunDueTasksNow(FDb, Log);
        if Log.Count = 0 then WriteLn(Tr('There are no tasks in the queue.')) else WriteLn(Log.Text);
      end
      else WriteLn('Navedi datoteku baze: TyphAccess --run-tasks baza.db');
    finally
      Log.Free;
    end;
    Application.Terminate;
    Exit;
  end;
  FTaskTimer := TTimer.Create(Self);
  FTaskTimer.Interval := 60000;
  FTaskTimer.OnTimer := @TaskTimer;
  FTaskTimer.Enabled := True;
end;

procedure TMainForm.MainKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = Ord('D')) and (ssCtrl in Shift) and (ssShift in Shift) then
  begin
    ActToggleMode(nil);
    Key := 0;
  end;
end;

procedure TMainForm.ActTheme(Sender: TObject);
var
  Tg: Integer;
  T: TaThemeTokens;
  Dlg: TOpenDialog;
  W: string;
begin
  Tg := TMenuItem(Sender).Tag;
  if Tg < 100 then SetTheme(TaTheme(Tg))
  else if Tg < 200 then SetBuiltinTheme(Tg - 100, CurrentTokens.Dark, CurrentTokens.Shape)
  else if Tg < 300 then
  begin
    T := CurrentTokens;
    if Tg = 200 then ApplyShape(T, shRounded) else ApplyShape(T, shSquare);
    SetThemeTokens(T);
  end
  else if Tg = 301 then
  begin
    if not FDb.Connected then ShowMessage(Tr('No database is open.'))
    else if SessionRole < arAdmin then ShowMessage(Tr('Only an administrator can save the theme into the application.'))
    else if SaveThemeToApp(FDb) then ShowMessage(Tr('The theme was saved into the application; it applies to everyone who has not chosen a theme themselves.'));
  end
  else if Tg = 302 then
  begin
    if FDb.Connected and (SessionRole >= arAdmin) then ClearAppTheme(FDb);
  end
  else
  begin
    Dlg := TOpenDialog.Create(Self);
    try
      Dlg.Filter := Tr('Theme (*.json)|*.json|All files|*.*');
      if Dlg.Execute then
        if not LoadThemeFromFile(Dlg.FileName, W) then ShowMessage(Tr('The theme cannot be loaded: ') + W)
        else if W <> '' then ShowMessage(Tr('The theme was loaded with warnings: ') + W);
    finally
      Dlg.Free;
    end;
  end;
end;

procedure TMainForm.ActToggleMode(Sender: TObject);
begin
  if not FDb.Connected then Exit;
  if SessionRole < arAdmin then begin ShowMessage(Tr('Only an administrator can open the design.')); Exit; end;
  if FRuntime and (FShell <> nil) and not FShell.CloseAll then Exit;
  FRuntime := not FRuntime;
  ApplyMode;
  if FRuntime then StartShell;
end;

procedure TMainForm.ActAppSettings(Sender: TObject);
begin
  if not FDb.Connected then begin ShowMessage(Tr('First open or create a database.')); Exit; end;
  RunAppSettings(Self, FDb);
end;

procedure TMainForm.ActDocTypes(Sender: TObject);
begin
  if not FDb.Connected then begin ShowMessage(Tr('First open or create a database.')); Exit; end;
  RunDocTypes(Self, FDb);
  RefreshTables;
end;

procedure TMainForm.ActSwitchboard(Sender: TObject);
var
  N: string;
begin
  if not FDb.Connected then begin ShowMessage(Tr('First open or create a database.')); Exit; end;
  N := RunSwitchboard(Self, FDb);
  if N <> '' then RefreshTables;
end;

procedure TMainForm.ActUsers(Sender: TObject);
begin
  if not FDb.Connected then begin ShowMessage(Tr('First open or create a database.')); Exit; end;
  RunUsers(Self, FDb);
end;

procedure TMainForm.ActRights(Sender: TObject);
begin
  if not FDb.Connected then begin ShowMessage(Tr('First open or create a database.')); Exit; end;
  RunRights(Self, FDb);
end;

procedure TMainForm.ActStartup(Sender: TObject);
begin
  if not FDb.Connected then Exit;
  if LoadAppSettings(FDb).StartupForm = '' then begin ShowMessage(Tr('The start form is not set (Application -> Settings).')); Exit; end;
  OpenStartupForm;
end;

procedure TMainForm.ActMasterDetail(Sender: TObject);
var
  N, RepName: string;
  Ds: TaFormDesigner;
  Rs: TaReportDesigner;
begin
  if not FDb.Connected then begin ShowMessage(Tr('First open or create a database.')); Exit; end;
  N := RunMasterDetailWizard(Self, FDb, RepName);
  if (N = '') and (RepName = '') then Exit;
  RefreshTables;
  if N <> '' then
  begin
    Ds := TaFormDesigner.CreateDesigner(Self, FDb, LoadFormDef(N));
    try
      Ds.ShowModal;
    finally
      Ds.Free;
    end;
  end;
  if RepName <> '' then
  begin
    Rs := TaReportDesigner.CreateDesigner(Self, FDb, LoadReportDef(RepName));
    try
      Rs.ShowModal;
    finally
      Rs.Free;
    end;
  end;
end;

procedure TMainForm.ActBackup(Sender: TObject);
var
  Err: string;
  Nfiles: Integer;
begin
  if not FDb.Connected then begin ShowMessage(Tr('First open or create a database.')); Exit; end;
  with TSaveDialog.Create(Self) do
  try
    Title := Tr('Database backup');
    Filter := Tr('Database (*.db)|*.db|All files|*');
    DefaultExt := 'db';
    FileName := ChangeFileExt(ExtractFileName(FDb.Conn.Database), '') + '_' + FormatDateTime('yyyymmdd', Now) + '.db';
    Options := Options + [ofOverwritePrompt];
    if Execute then
    begin
      if BackupDatabase(FDb, FileName, Err) then
      begin
        Nfiles := CopyStoreToFolder(FDb, ChangeFileExt(FileName, '') + '_datoteke');
        ShowMessage(Tr('The copy was saved:') + LineEnding + FileName +
          IfThen(Nfiles > 0, LineEnding + 'Datoteke (' + IntToStr(Nfiles) + '): ' + ChangeFileExt(FileName, '') + '_datoteke', ''));
      end
      else ShowMessage(Tr('The copy failed: ') + Err);
    end;
  finally
    Free;
  end;
end;

procedure TMainForm.ActCompact(Sender: TObject);
var
  Rep: string;
  Ok: Boolean;
begin
  if not FDb.Connected then begin ShowMessage(Tr('First open or create a database.')); Exit; end;
  if MessageDlg(Tr('Check integrity and compact the database? It is recommended to make a backup first.'),
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  CloseSheet;
  Ok := CheckAndCompact(FDb, True, Rep);
  if Ok then ShowMessage(Rep) else ShowMessage(Tr('PROBLEM:') + LineEnding + Rep);
end;

procedure TMainForm.ActDocument(Sender: TObject);
var
  L: TStringList;
begin
  if not FDb.Connected then begin ShowMessage(Tr('First open or create a database.')); Exit; end;
  with TSaveDialog.Create(Self) do
  try
    Title := 'Dokumentacija baze';
    Filter := 'HTML (*.html)|*.html';
    DefaultExt := 'html';
    FileName := ChangeFileExt(ExtractFileName(FDb.Conn.Database), '') + '_dokumentacija.html';
    Options := Options + [ofOverwritePrompt];
    if Execute then
    begin
      L := TStringList.Create;
      try
        L.Text := DocumentDatabase(FDb);
        L.SaveToFile(FileName);
        ShowMessage(Tr('The documentation was saved:') + LineEnding + FileName);
      finally
        L.Free;
      end;
    end;
  finally
    Free;
  end;
end;

procedure TMainForm.ActDataTools(Sender: TObject);
var
  N: string;
  Q: TaQueryDesigner;
begin
  if not FDb.Connected then begin ShowMessage(Tr('First open or create a database.')); Exit; end;
  if SessionRole <> arAdmin then begin ShowMessage(Tr('Only an administrator may use the data tools.')); Exit; end;
  CloseSheet;
  N := RunDataTools(Self, FDb);
  RefreshTables;
  if N = '' then Exit;
  Q := TaQueryDesigner.CreateDesigner(Self, FDb, N);
  try
    Q.RunQuery;
    Q.ShowModal;
  finally
    Q.Free;
  end;
end;

procedure TMainForm.ActCrosstab(Sender: TObject);
var
  N: string;
  Q: TaQueryDesigner;
begin
  if not FDb.Connected then begin ShowMessage(Tr('First open or create a database.')); Exit; end;
  N := RunCrosstabWizard(Self, FDb);
  if N = '' then Exit;
  RefreshTables;
  CloseSheet;
  Q := TaQueryDesigner.CreateDesigner(Self, FDb, N);
  try
    Q.RunQuery;
    Q.ShowModal;
  finally
    Q.Free;
  end;
end;

procedure TMainForm.ActQueryWizard(Sender: TObject);
var
  N: string;
  Q: TaQueryDesigner;
begin
  if not FDb.Connected then begin ShowMessage(Tr('First open or create a database.')); Exit; end;
  N := RunQueryWizard(Self, FDb);
  if N = '' then Exit;
  RefreshTables;
  CloseSheet;
  Q := TaQueryDesigner.CreateDesigner(Self, FDb, N);
  try
    Q.RunQuery;
    Q.ShowModal;
  finally
    Q.Free;
  end;
end;

procedure TMainForm.ActTasks(Sender: TObject);
begin
  if not FDb.Connected then begin ShowMessage(Tr('First open or create a database.')); Exit; end;
  if SessionRole <> arAdmin then begin ShowMessage(Tr('Only an administrator may open the task scheduler.')); Exit; end;
  RunTaskPlanner(Self, FDb);
end;

procedure TMainForm.TaskTimer(Sender: TObject);
var
  Log: TStringList;
begin
  if (not FDb.Connected) or (FDb.LoadSetting('tasks.auto') = '0') then Exit;
  Log := TStringList.Create;
  try
    try
      if RunDueTasksNow(FDb, Log) > 0 then FStatus.SimpleText := 'Planer: ' + Log.Text;
    except
      { zadatak ne smije srusiti aplikaciju }
    end;
  finally
    Log.Free;
  end;
end;

procedure TMainForm.ActAudit(Sender: TObject);
begin
  if not FDb.Connected then begin ShowMessage(Tr('First open or create a database.')); Exit; end;
  if SessionRole <> arAdmin then begin ShowMessage(Tr('Only an administrator may open the audit trail.')); Exit; end;
  RunAuditViewer(Self, FDb);
end;

procedure TMainForm.ActCompany(Sender: TObject);
begin
  if not FDb.Connected then begin ShowMessage(Tr('First open or create a database.')); Exit; end;
  RunCompanyProfile(Self, FDb);
end;

procedure TMainForm.ActFiscal(Sender: TObject);
begin
  if not FDb.Connected then begin ShowMessage(Tr('First open or create a database.')); Exit; end;
  if Assigned(FiscalSetupHook) then FiscalSetupHook(Self, FDb);
  if Assigned(FiscalUseDbHook) then FiscalUseDbHook(FDb);
end;

procedure TMainForm.ActGenerateApp(Sender: TObject);
begin
  if not FDb.Connected then begin ShowMessage(Tr('First open or create a database.')); Exit; end;
  CloseSheet;
  RunApplicationWizard(Self, FDb);
  RefreshTables;
end;

procedure TMainForm.ActBusiness(Sender: TObject);
begin
  if not FDb.Connected then begin ShowMessage(Tr('First open or create a database.')); Exit; end;
  CloseSheet;
  RunBusinessTemplates(Self, FDb);
  RefreshTables;
end;

end.
