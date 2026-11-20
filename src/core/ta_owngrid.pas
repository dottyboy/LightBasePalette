unit ta_owngrid;
{ Vlastita tablica nad skupom podataka (pruzatelj 'own', obitelj Grid, varijante readonly i datasheet): crta se sama, pa izgleda i
  radi isto na svakom sucelju. Etapa 1-2 plana (docs/PLAN-vlastiti-grid.md): pregled bez uredjivanja.

  Redci dolaze kao kod TDBGrid-a: TDataLink s BufferCount = broj vidljivih redaka, tekuci redak je ActiveRecord, a pomicanje (tipke,
  kotacic, klizac, klik) pomice kursor skupa. Zna: zaglavlje s klikom (sortiranje javlja domacin) i povlacenjem ruba stupca, zebru,
  uvjetno bojanje (OnPrepareCell), poravnanje, formate iz polja (DisplayText), logicka polja kao kvacicu, memo polja kao tekst,
  indikator tekuceg retka, okomiti i vodoravni klizac, zbrojeve u podnozju, boje iz teme. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, Forms, Dialogs, Clipbrd, DB, DBGrids, LCLType, ta_family, ta_grid, ta_ownedit, ta_owncombo;

type
  { za ispitivanja i domacine koji ne uvoze DB }
  TaGridSource = TDataSource;

  TaOwnGrid = class;

  TaGridColumn = class(TCollectionItem)
  private
    FFieldName, FTitle: string;
    FWidth: Integer;
    FAlign: TAlignment;
    FAlignSet: Boolean;
    FVisible, FReadOnly: Boolean;
    FField: TField;
    FPick: TStringList;
    procedure SetFieldName(const AValue: string);
    procedure SetTitle(const AValue: string);
    procedure SetWidth(AValue: Integer);
    procedure SetVisible(AValue: Boolean);
    function GetAlign: TAlignment;
    procedure SetAlign(AValue: TAlignment);
  public
    constructor Create(ACollection: TCollection); override;
    destructor Destroy; override;
    property Field: TField read FField;
    { natpisi za padajuci popis pri uredjivanju (strani kljuc); prazno = obicno polje }
    property PickList: TStringList read FPick;
  published
    property FieldName: string read FFieldName write SetFieldName;
    property Title: string read FTitle write SetTitle;
    property Width: Integer read FWidth write SetWidth;
    property Alignment: TAlignment read GetAlign write SetAlign;
    property Visible: Boolean read FVisible write SetVisible;
    property ReadOnly: Boolean read FReadOnly write FReadOnly;
  end;

  TaGridColumns = class(TCollection)
  private
    FGrid: TaOwnGrid;
    function GetItem(AIndex: Integer): TaGridColumn;
  protected
    procedure Update(AItem: TCollectionItem); override;
  public
    constructor Create(AGrid: TaOwnGrid);
    function Add: TaGridColumn;
    function ByField(const AName: string): TaGridColumn;
    property Items[AIndex: Integer]: TaGridColumn read GetItem; default;
  end;

  { stil ćelije koji domacin moze promijeniti (uvjetno oblikovanje); clNone = zadano }
  TaGridCellStyle = record
    Fore, Back: TColor;
    Bold: Boolean;
  end;

  TaGridPrepareEvent = procedure(Sender: TObject; AColumn: TaGridColumn; ASelectedRow: Boolean; var AStyle: TaGridCellStyle) of object;
  TaGridTitleEvent = procedure(Sender: TObject; AColumn: TaGridColumn) of object;
  { greska pri upisu u polje (provjera, pretvorba); domacin je pokazuje poruku }
  { potkartica (poput Accessa): domacin postavlja izvor podataka podtablice za redak s kljucem AKey }
  TaGridSubEvent = procedure(Sender: TObject; const AKey: string; AChild: TaOwnGrid) of object;
  TaGridCellEvent = procedure(Sender: TObject; AColumn: TaGridColumn; ARecNo: Integer) of object;
  TaGridErrorEvent = procedure(Sender: TObject; const AMessage: string) of object;
  { potvrda brisanja zapisa }
  TaGridConfirmEvent = function(Sender: TObject; const AMessage: string): Boolean of object;

  TaOwnGridLink = class(TDataLink)
  private
    FGrid: TaOwnGrid;
  protected
    procedure ActiveChanged; override;
    procedure DataSetChanged; override;
    procedure DataSetScrolled(Distance: Integer); override;
    procedure LayoutChanged; override;
    procedure RecordChanged(AField: TField); override;
  public
    constructor Create(AGrid: TaOwnGrid);
  end;

  TaOwnGrid = class(TCustomControl)
  private
    FLink: TaOwnGridLink;
    FColumns: TaGridColumns;
    FAutoColumns, FAutoMade, FIndicator, FZebra, FReadOnly: Boolean;
    FRowH, FScrollX, FCol, FResizeCol, FResizeX0, FResizeW0: Integer;
    FDragBar: Integer;               { 0 nista, 1 okomiti, 2 vodoravni klizac }
    FEditor: TaOwnEdit;
    FCombo: TaOwnCombo;
    FCur: TaOwnEdit;                 { uredjivac koji je sada otvoren }
    FEditing, FAllowEdit, FAllowInsert, FAllowDelete, FAutoAppend, FAlways: Boolean;
    FOrig: string;
    FSubKey: string;
    FExpanded: TStringList;
    FChildren: TStringList;           { kljuc -> potkartica (Objects) }
    FRowExtra: array of Integer;      { dodatna visina retka (potkartica) po retku medjuspremnika }
    FRowKey: array of string;
    FSubMax: Integer;
    FAdjusting, FInGeometry: Boolean;
    FLastW, FLastH: Integer;
    FSelMap: array of Boolean;        { oznaceni zapisi po RecNo - 1 }
    FSelCount, FAnchorRec, FHot, FHeadDown, FHeadX0, FDragCol, FDropAt, FLastX, FLastY: Integer;
    FMulti: Boolean;
    FFrozen: Integer;
    FHintKey: string;
    FOnSel: TNotifyEvent;
    FOnCell: TaGridCellEvent;
    FOnSubOpen, FOnSubClose: TaGridSubEvent;
    FOnError: TaGridErrorEvent;
    FOnConfirm: TaGridConfirmEvent;
    FSortField, FFooter: string;
    FSortDesc: Boolean;
    FOnPrepare: TaGridPrepareEvent;
    FOnTitle: TaGridTitleEvent;
    function GetDataSource: TDataSource;
    procedure SetDataSource(AValue: TDataSource);
    procedure SetRowH(AValue: Integer);
    procedure SetIndicator(AValue: Boolean);
    procedure SetZebra(AValue: Boolean);
    procedure SetFooter(const AValue: string);
    function HeaderH: Integer;
    function FooterH: Integer;
    function IndW: Integer;
    function TotalW: Integer;
    function ViewW: Integer;
    function NeedHBar: Boolean;
    function VisRows: Integer;
    function BodyTop: Integer;
    procedure FixBuffer;
    procedure ResolveFields;
    procedure BuildAuto;
    function ColLeft(AIndex: Integer): Integer;
    function ColAtX(X: Integer): Integer;
    function EdgeAtX(X: Integer): Integer;
    function CellText(AColumn: TaGridColumn): string;
    function IsCheck(AColumn: TaGridColumn): Boolean;
    procedure EnsureColVisible;
    procedure MoveRows(ADelta: Integer);
    procedure VThumbTo(Y: Integer);
    procedure HThumbTo(X: Integer);
    procedure LinkChanged;
    function NextVisible(AFrom, ADir: Integer): Integer;
    procedure EnsureSelMap;
    function IsSelRec(ARec: Integer): Boolean;
    procedure SetSelRec(ARec: Integer; AValue: Boolean);
    procedure SelectRecRange(A, B: Integer);
    procedure SelChanged;
    function CurRec: Integer;
    procedure ExtendTo(ARec: Integer);
    procedure MoveColumn(AFrom, ATo: Integer);
    procedure UpdateHint(X, ARow: Integer);
    function FrozenCount: Integer;
    function IsFrozenCol(AIndex: Integer): Boolean;
    function FrozenW: Integer;
    procedure SetFrozen(AValue: Integer);
    function ExpW: Integer;
    function ExtraOf(ARow: Integer): Integer;
    procedure RecalcExtra;
    function RowTopOf(ARow: Integer): Integer;
    function RowAtY(Y: Integer; out InExtra: Boolean): Integer;
    procedure Geometry;
    procedure AdjustBuffer;
    procedure PlaceChildren;
    procedure ToggleRow(ARow: Integer);
    procedure SetSubKey(const AValue: string);
    function CanEditCol(AIndex: Integer): Boolean;
    procedure StartEdit(const AInitial: string; AReplace: Boolean);
    procedure EndEditUI;
    procedure ApplyText(const AText: string);
    procedure ReportError(const AMessage: string);
    procedure EditorKey(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure EditorExit(Sender: TObject);
    procedure Advance(ADir: Integer);
    procedure ToggleBool;
    procedure InsertRecord;
    procedure DeleteRecord;
  protected
    procedure UTF8KeyPress(var UTF8Key: TUTF8Char); override;
    procedure DblClick; override;
    procedure MouseLeave; override;
    procedure Paint; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
    procedure DoEnter; override;
    procedure DoExit; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ClearColumns;
    { oznacavanje vise zapisa, kopiranje, sirina stupca prema sadrzaju }
    procedure ClearSelection;
    procedure SelectAllRecords;
    function SelectedCount: Integer;
    function SelectionText(AHeader: Boolean): string;
    procedure CopyToClipboard;
    procedure AutoFitColumn(AIndex: Integer);
    procedure AutoFitAll;
    { potkartice: kljuc retka je vrijednost polja SubKeyField; domacin u OnSubOpen postavlja izvor podataka potkartice }
    procedure ExpandKey(const AKey: string);
    procedure CollapseKey(const AKey: string);
    procedure CollapseAll;
    function IsExpanded(const AKey: string): Boolean;
    function ChildOf(const AKey: string): TaOwnGrid;
    { visina koju mreza treba za najvise AMaxRows redaka podataka (zaglavlje, redci, klizac) }
    function PreferredHeight(AMaxRows: Integer): Integer;
    { zavrsi uredjivanje: upisi tekst u polje (CommitEdit) ili ga odbaci (CancelEdit) }
    procedure CommitEdit;
    procedure CancelEdit;
    function Editing: Boolean;
    property EditorControl: TaOwnEdit read FCur;
    function CurrentColumn: TaGridColumn;
    { stupac za polje skupa: naslov i zadana sirina prema vrsti polja (ne gradi se sam, AutoColumns se gasi) }
    function AddFieldColumn(const AFieldName: string): TaGridColumn;
    function SelectedField: TField;
    function RowCount: Integer;
    function ActiveRow: Integer;
    property DataSource: TDataSource read GetDataSource write SetDataSource;
    property Columns: TaGridColumns read FColumns;
    property AutoColumns: Boolean read FAutoColumns write FAutoColumns;
    property ShowIndicator: Boolean read FIndicator write SetIndicator;
    property Zebra: Boolean read FZebra write SetZebra;
    property RowHeight: Integer read FRowH write SetRowH;
    property ReadOnly: Boolean read FReadOnly write FReadOnly;
    { uredjivanje u celiji (Enter, F2, tipkanje, drugi klik); novi i brisanje zapisa (Insert, Ctrl+Delete) }
    property AllowEdit: Boolean read FAllowEdit write FAllowEdit;
    property AllowInsert: Boolean read FAllowInsert write FAllowInsert;
    property AllowDelete: Boolean read FAllowDelete write FAllowDelete;
    { Tab iz zadnje celije zadnjeg retka otvara novi prazan redak (unos) }
    property AutoAppend: Boolean read FAutoAppend write FAutoAppend;
    { uredjivac ostaje otvoren dok se krecemo po celijama (unos) }
    property AlwaysEdit: Boolean read FAlways write FAlways;
    property MultiSelect: Boolean read FMulti write FMulti;
    { prvih N vidljivih stupaca ne pomice se vodoravnim klizanjem (zamrznuti stupci) }
    property FrozenColumns: Integer read FFrozen write SetFrozen;
    property OnSelectionChange: TNotifyEvent read FOnSel write FOnSel;
    property OnCellClick: TaGridCellEvent read FOnCell write FOnCell;
    property SubKeyField: string read FSubKey write SetSubKey;
    property SubMaxRows: Integer read FSubMax write FSubMax;
    property OnSubOpen: TaGridSubEvent read FOnSubOpen write FOnSubOpen;
    property OnSubClose: TaGridSubEvent read FOnSubClose write FOnSubClose;
    property SortField: string read FSortField write FSortField;
    property SortDescending: Boolean read FSortDesc write FSortDesc;
    property FooterText: string read FFooter write SetFooter;
    property OnPrepareCell: TaGridPrepareEvent read FOnPrepare write FOnPrepare;
    property OnTitleClick: TaGridTitleEvent read FOnTitle write FOnTitle;
    property OnEditError: TaGridErrorEvent read FOnError write FOnError;
    property OnConfirmDelete: TaGridConfirmEvent read FOnConfirm write FOnConfirm;
  end;

  { pokretac pruzatelja 'own' za varijante readonly i datasheet }
  TaOwnGridEngine = class(TaGridDataEngine)
  private
    FGrid: TaOwnGrid;
    FLink: TaGridFooterLink;
    FSumFields: string;
    FRefreshing: Boolean;
    procedure RefreshFooter(Sender: TObject);
  protected
    function VariantOf: TaGridVariant; virtual;
    function DatasheetStyle: Boolean;
  public
    constructor Create(AHost: TaFamilyHost); override;
    destructor Destroy; override;
    class function Provider: string; override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
    procedure SetReadOnly(AValue: Boolean); override;
    procedure ApplyOptions(AOptions: TPersistent); override;
    procedure SetSource(ASource: TDataSource); override;
    function InnerDBGrid: TDBGrid; override;
    function FooterText: string; override;
    property Grid: TaOwnGrid read FGrid;
  end;

  TaOwnGridDatasheetEngine = class(TaOwnGridEngine)
  protected
    function VariantOf: TaGridVariant; override;
  end;

  TaOwnGridEditableEngine = class(TaOwnGridEngine)
  protected
    function VariantOf: TaGridVariant; override;
  end;

  TaOwnGridEntryEngine = class(TaOwnGridEngine)
  protected
    function VariantOf: TaGridVariant; override;
  end;

implementation

uses
  Math, ta_tokens, ta_i18n;

const
  DefHeaderH = 30;
  BarW = 10;
  MinColW = 30;

{ ---------------- stupci ---------------- }

constructor TaGridColumn.Create(ACollection: TCollection);
begin
  inherited Create(ACollection);
  FWidth := 100;
  FVisible := True;
  FPick := TStringList.Create;
end;

destructor TaGridColumn.Destroy;
begin
  FPick.Free;
  inherited Destroy;
end;

procedure TaGridColumn.SetFieldName(const AValue: string);
begin
  if FFieldName = AValue then Exit;
  FFieldName := AValue;
  Changed(False);
end;

procedure TaGridColumn.SetTitle(const AValue: string);
begin
  FTitle := AValue;
  Changed(False);
end;

procedure TaGridColumn.SetWidth(AValue: Integer);
begin
  if AValue < MinColW then AValue := MinColW;
  if FWidth = AValue then Exit;
  FWidth := AValue;
  Changed(False);
end;

procedure TaGridColumn.SetVisible(AValue: Boolean);
begin
  if FVisible = AValue then Exit;
  FVisible := AValue;
  Changed(False);
end;

function TaGridColumn.GetAlign: TAlignment;
begin
  if FAlignSet or (FField = nil) then Exit(FAlign);
  if FField.DataType in [ftSmallint, ftInteger, ftLargeint, ftWord, ftAutoInc, ftFloat, ftCurrency, ftBCD, ftFMTBcd, ftSingle] then Result := taRightJustify
  else Result := taLeftJustify;
end;

procedure TaGridColumn.SetAlign(AValue: TAlignment);
begin
  FAlign := AValue;
  FAlignSet := True;
  Changed(False);
end;

constructor TaGridColumns.Create(AGrid: TaOwnGrid);
begin
  inherited Create(TaGridColumn);
  FGrid := AGrid;
end;

function TaGridColumns.GetItem(AIndex: Integer): TaGridColumn;
begin
  Result := TaGridColumn(inherited Items[AIndex]);
end;

function TaGridColumns.Add: TaGridColumn;
begin
  Result := TaGridColumn(inherited Add);
end;

function TaGridColumns.ByField(const AName: string): TaGridColumn;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    if SameText(Items[I].FieldName, AName) then Exit(Items[I]);
  Result := nil;
end;

procedure TaGridColumns.Update(AItem: TCollectionItem);
begin
  inherited Update(AItem);
  if FGrid <> nil then
  begin
    FGrid.ResolveFields;
    FGrid.Invalidate;
  end;
end;

{ ---------------- veza na podatke ---------------- }

constructor TaOwnGridLink.Create(AGrid: TaOwnGrid);
begin
  inherited Create;
  FGrid := AGrid;
  VisualControl := True;
end;

procedure TaOwnGridLink.ActiveChanged;
begin
  inherited ActiveChanged;
  FGrid.EndEditUI;
  FGrid.LinkChanged;
end;

procedure TaOwnGridLink.DataSetChanged;
begin
  inherited DataSetChanged;
  FGrid.Geometry;
end;

procedure TaOwnGridLink.DataSetScrolled(Distance: Integer);
begin
  inherited DataSetScrolled(Distance);
  FGrid.EndEditUI;
  FGrid.Geometry;
end;

procedure TaOwnGridLink.LayoutChanged;
begin
  inherited LayoutChanged;
  FGrid.LinkChanged;
end;

procedure TaOwnGridLink.RecordChanged(AField: TField);
begin
  inherited RecordChanged(AField);
  FGrid.Invalidate;
end;

{ ---------------- tablica ---------------- }

constructor TaOwnGrid.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ApplyThemeFont(Font);
  ControlStyle := ControlStyle + [csOpaque, csCaptureMouse, csClickEvents];
  TabStop := True;
  Width := 320;
  Height := 160;
  FColumns := TaGridColumns.Create(Self);
  FLink := TaOwnGridLink.Create(Self);
  FAutoColumns := True;
  FIndicator := True;
  FRowH := 26;
  FAllowInsert := True;
  FAllowDelete := True;
  FSubMax := 8;
  FMulti := True;
  FHot := -1;
  FHeadDown := -1;
  FDragCol := -1;
  FExpanded := TStringList.Create;
  FExpanded.Sorted := True;
  FExpanded.Duplicates := dupIgnore;
  FChildren := TStringList.Create;
  FResizeCol := -1;
  FCol := 0;
end;

destructor TaOwnGrid.Destroy;
begin
  FLink.DataSource := nil;
  CollapseAll;
  FreeAndNil(FChildren);
  FreeAndNil(FExpanded);
  FLink.Free;
  FColumns.Free;
  inherited Destroy;
end;

function TaOwnGrid.GetDataSource: TDataSource;
begin
  Result := FLink.DataSource;
end;

procedure TaOwnGrid.SetDataSource(AValue: TDataSource);
begin
  FLink.DataSource := AValue;
  LinkChanged;
end;

procedure TaOwnGrid.SetRowH(AValue: Integer);
begin
  if AValue < 16 then AValue := 16;
  FRowH := AValue;
  FixBuffer;
  Invalidate;
end;

procedure TaOwnGrid.SetIndicator(AValue: Boolean);
begin
  FIndicator := AValue;
  Invalidate;
end;

procedure TaOwnGrid.SetZebra(AValue: Boolean);
begin
  FZebra := AValue;
  Invalidate;
end;

procedure TaOwnGrid.SetFooter(const AValue: string);
begin
  if FFooter = AValue then Exit;
  FFooter := AValue;
  FixBuffer;
  Invalidate;
end;

function TaOwnGrid.HeaderH: Integer;
begin
  Result := Max(DefHeaderH, FRowH + 2);
end;

function TaOwnGrid.FooterH: Integer;
begin
  if FFooter <> '' then Result := 28 else Result := 0;
end;

function TaOwnGrid.ExpW: Integer;
begin
  if FSubKey <> '' then Result := 18 else Result := 0;
end;

function TaOwnGrid.IndW: Integer;
begin
  Result := ExpW;
  if FIndicator then Inc(Result, 18);
end;

function TaOwnGrid.TotalW: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to FColumns.Count - 1 do
    if FColumns[I].Visible then Inc(Result, FColumns[I].Width);
end;

function TaOwnGrid.ViewW: Integer;
begin
  Result := Width - IndW - BarW - 2;
end;

function TaOwnGrid.NeedHBar: Boolean;
begin
  Result := TotalW > ViewW;
end;

function TaOwnGrid.BodyTop: Integer;
begin
  Result := HeaderH;
end;

function TaOwnGrid.VisRows: Integer;
var
  H: Integer;
begin
  H := Height - HeaderH - FooterH - 2;
  if NeedHBar then Dec(H, BarW);
  Result := Max(1, H div FRowH);
end;

procedure TaOwnGrid.FixBuffer;
begin
  if FLink.BufferCount <> VisRows then FLink.BufferCount := VisRows;
end;

procedure TaOwnGrid.LinkChanged;
begin
  CollapseAll;
  if FAutoMade or (FColumns.Count = 0) then BuildAuto;
  ResolveFields;
  FixBuffer;
  Geometry;
end;

procedure TaOwnGrid.ResolveFields;
var
  I: Integer;
  Ds: TDataSet;
begin
  Ds := nil;
  if FLink.Active then Ds := FLink.DataSet;
  for I := 0 to FColumns.Count - 1 do
    if Ds <> nil then FColumns[I].FField := Ds.FindField(FColumns[I].FFieldName)
    else FColumns[I].FField := nil;
end;

procedure TaOwnGrid.ClearColumns;
begin
  FColumns.Clear;
  FAutoMade := False;
end;

function DefaultWidthFor(F: TField): Integer;
begin
  case F.DataType of
    ftString, ftWideString, ftFixedChar: Result := Min(Max(F.Size, 6), 30) * 9 + 18;
    ftMemo, ftWideMemo, ftFmtMemo: Result := 200;
    ftDate, ftTime, ftDateTime, ftTimeStamp: Result := 110;
    ftBoolean: Result := 64;
  else
    Result := 90;
  end;
  Result := Max(MinColW, Result);
end;

function TaOwnGrid.AddFieldColumn(const AFieldName: string): TaGridColumn;
var
  F: TField;
begin
  FAutoColumns := False;
  FAutoMade := False;
  Result := FColumns.Add;
  Result.FFieldName := AFieldName;
  Result.FTitle := AFieldName;
  F := nil;
  if FLink.Active then F := FLink.DataSet.FindField(AFieldName);
  if F <> nil then
  begin
    Result.FTitle := F.DisplayLabel;
    Result.FWidth := DefaultWidthFor(F);
    Result.FField := F;
  end;
end;

function TaOwnGrid.SelectedField: TField;
begin
  Result := nil;
  if (FCol >= 0) and (FCol < FColumns.Count) then Result := FColumns[FCol].Field;
end;

procedure TaOwnGrid.BuildAuto;
var
  I: Integer;
  F: TField;
  C: TaGridColumn;
begin
  if not FAutoColumns then Exit;
  FColumns.BeginUpdate;
  try
    FColumns.Clear;
    FAutoMade := False;
    if not FLink.Active then Exit;
    for I := 0 to FLink.DataSet.FieldCount - 1 do
    begin
      F := FLink.DataSet.Fields[I];
      if not F.Visible then Continue;
      C := FColumns.Add;
      C.FFieldName := F.FieldName;
      C.FTitle := F.DisplayLabel;
      C.FWidth := DefaultWidthFor(F);
    end;
    FAutoMade := True;
  finally
    FColumns.EndUpdate;
  end;
end;

function TaOwnGrid.NextVisible(AFrom, ADir: Integer): Integer;
var
  I: Integer;
begin
  I := AFrom + ADir;
  while (I >= 0) and (I < FColumns.Count) do
  begin
    if FColumns[I].Visible then Exit(I);
    Inc(I, ADir);
  end;
  Result := AFrom;
end;

function TaOwnGrid.FrozenCount: Integer;
var
  I, N: Integer;
begin
  Result := 0;
  N := 0;
  for I := 0 to FColumns.Count - 1 do
    if FColumns[I].Visible then
    begin
      if N >= FFrozen then Break;
      Inc(N);
      Result := I + 1;
    end;
  if FFrozen <= 0 then Result := 0;
end;

function TaOwnGrid.IsFrozenCol(AIndex: Integer): Boolean;
begin
  Result := AIndex < FrozenCount;
end;

function TaOwnGrid.FrozenW: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to FrozenCount - 1 do
    if FColumns[I].Visible then Inc(Result, FColumns[I].Width);
end;

procedure TaOwnGrid.SetFrozen(AValue: Integer);
begin
  if AValue < 0 then AValue := 0;
  if FFrozen = AValue then Exit;
  FFrozen := AValue;
  FScrollX := 0;
  Invalidate;
end;

function TaOwnGrid.ColLeft(AIndex: Integer): Integer;
var
  I: Integer;
begin
  Result := IndW;
  if not IsFrozenCol(AIndex) then Dec(Result, FScrollX);
  for I := 0 to AIndex - 1 do
    if FColumns[I].Visible then Inc(Result, FColumns[I].Width);
end;

function TaOwnGrid.ColAtX(X: Integer): Integer;
var
  I, L, Lo: Integer;
begin
  Result := -1;
  for I := 0 to FColumns.Count - 1 do
    if FColumns[I].Visible then
    begin
      L := ColLeft(I);
      Lo := L;
      if not IsFrozenCol(I) then Lo := Max(L, IndW + FrozenW);
      if (X >= Lo) and (X < L + FColumns[I].Width) then Exit(I);
    end;
end;

{ stupac ciji se desni rub nalazi uz X (za povlacenje sirine), ili -1 }
function TaOwnGrid.EdgeAtX(X: Integer): Integer;
var
  I, R: Integer;
begin
  Result := -1;
  for I := 0 to FColumns.Count - 1 do
    if FColumns[I].Visible then
    begin
      R := ColLeft(I) + FColumns[I].Width;
      if (Abs(X - R) <= 4) and (IsFrozenCol(I) or (R > IndW + FrozenW)) then Exit(I);
    end;
end;

function TaOwnGrid.IsCheck(AColumn: TaGridColumn): Boolean;
begin
  Result := (AColumn.Field <> nil) and (AColumn.Field.DataType = ftBoolean) and not Assigned(AColumn.Field.OnGetText);
end;

function TaOwnGrid.CellText(AColumn: TaGridColumn): string;
var
  F: TField;
begin
  F := AColumn.Field;
  if F = nil then Exit('');
  case F.DataType of
    ftMemo, ftWideMemo, ftFmtMemo:
      if Assigned(F.OnGetText) then Result := F.DisplayText else Result := F.AsString;
    ftBlob, ftGraphic, ftBytes, ftVarBytes: Result := '(BLOB)';
  else
    Result := F.DisplayText;
  end;
  if Pos(#10, Result) > 0 then Result := StringReplace(StringReplace(Result, #13, '', [rfReplaceAll]), #10, ' ', [rfReplaceAll]);
end;

function TaOwnGrid.RowCount: Integer;
begin
  if FLink.Active then Result := FLink.RecordCount else Result := 0;
end;

function TaOwnGrid.ActiveRow: Integer;
begin
  if FLink.Active then Result := FLink.ActiveRecord else Result := -1;
end;

function TaOwnGrid.CurrentColumn: TaGridColumn;
begin
  if (FCol >= 0) and (FCol < FColumns.Count) then Result := FColumns[FCol] else Result := nil;
end;

procedure TaOwnGrid.EnsureColVisible;
var
  L, W: Integer;
begin
  if (FCol < 0) or (FCol >= FColumns.Count) then Exit;
  if IsFrozenCol(FCol) then Exit;
  L := ColLeft(FCol);
  W := FColumns[FCol].Width;
  if L < IndW + FrozenW then Dec(FScrollX, IndW + FrozenW - L)
  else if L + W > IndW + ViewW then Inc(FScrollX, L + W - IndW - ViewW);
  if FScrollX < 0 then FScrollX := 0;
  if FScrollX > Max(0, TotalW - ViewW) then FScrollX := Max(0, TotalW - ViewW);
end;

procedure TaOwnGrid.MoveRows(ADelta: Integer);
begin
  if not FLink.Active then Exit;
  if FEditing then CommitEdit;
  try
    { zapis se sprema pri napustanju retka }
    if FLink.DataSet.State in dsEditModes then FLink.DataSet.Post;
    FLink.DataSet.MoveBy(ADelta);
  except
    on E: Exception do ReportError(E.Message);
  end;
end;

procedure TaOwnGrid.VThumbTo(Y: Integer);
var
  N, R: Integer;
begin
  if not FLink.Active then Exit;
  N := FLink.DataSet.RecordCount;
  if N <= 1 then Exit;
  R := Round((Y - HeaderH) / Max(1, Height - HeaderH - FooterH - BarW) * N);
  R := Max(1, Min(N, R));
  try
    FLink.DataSet.RecNo := R;
  except
  end;
end;

procedure TaOwnGrid.HThumbTo(X: Integer);
var
  Span: Integer;
begin
  Span := TotalW - ViewW;
  if Span <= 0 then Exit;
  FScrollX := Max(0, Min(Span, Round((X - IndW) / Max(1, ViewW) * TotalW - ViewW / 2)));
  Invalidate;
end;

{ ---------------- crtanje ---------------- }

procedure TaOwnGrid.Paint;
var
  T: TaThemeTokens;
  Bg, Br, Grid, Tx, TxSoft, HeadBg: TColor;
  I, R, X, Y, W, Rh, Hh, Saved, N, Base, ColI, Cx, Cy, ThH, ThY, Fh: Integer;
  C: TaGridColumn;
  Foc, SelRow, Odd_: Boolean;
  Style: TaGridCellStyle;
  Txt: string;
  Ts: TTextStyle;
  RowRect: TRect;
  Ds: TDataSet;
begin
  T := ActiveTokens;
  Foc := Focused;
  Bg := TokenColor(T.Surface);
  Br := TokenColor(T.Border);
  Grid := TokenColor(MixHex(T.Border, T.Surface, 0.55));
  Tx := TokenColor(T.Text);
  TxSoft := TokenColor(T.TextSoft);
  HeadBg := TokenColor(T.Soft);
  Rh := FRowH;
  Hh := HeaderH;
  Fh := FooterH;
  Canvas.Font.Assign(Font);
  FillChar(Ts, SizeOf(Ts), 0);
  Ts.SingleLine := True;
  Ts.Clipping := True;
  Ts.Layout := tlCenter;
  { podloga i okvir }
  Canvas.Brush.Color := Bg;
  Canvas.Pen.Color := Br;
  Canvas.Rectangle(0, 0, Width, Height);
  { zaglavlje }
  Canvas.ClipRect := Rect(1, 1, Width - 1, Height - 1);
  Canvas.Clipping := True;
  Canvas.Brush.Color := HeadBg;
  Canvas.Pen.Style := psClear;
  Canvas.FillRect(1, 1, Width - 1, Hh);
  Canvas.Pen.Style := psSolid;
  Canvas.Pen.Color := Br;
  Canvas.Line(1, Hh - 1, Width - 1, Hh - 1);
  Canvas.Font.Style := [fsBold];
  for I := 0 to FColumns.Count - 1 do
  begin
    C := FColumns[I];
    if not C.Visible then Continue;
    W := C.Width;
    X := ColLeft(I);
    if IsFrozenCol(I) then Canvas.ClipRect := Rect(1, 1, Width - 1, Height - 1)
    else Canvas.ClipRect := Rect(Max(1, IndW + FrozenW), 1, Width - 1, Height - 1);
    if (X + W > 0) and (X < Width) then
    begin
      Canvas.Brush.Style := bsClear;
      Canvas.Font.Color := Tx;
      Txt := C.Title;
      if Txt = '' then Txt := C.FieldName;
      Ts.Alignment := C.Alignment;
      Canvas.TextRect(Rect(X + 6, 1, X + W - 18 + 12 * Ord(not SameText(C.FieldName, FSortField)), Hh - 1), X + 6, 1, Txt, Ts);
      if (FSortField <> '') and SameText(C.FieldName, FSortField) then
      begin
        Canvas.Brush.Style := bsSolid;
        Canvas.Brush.Color := TxSoft;
        Canvas.Pen.Style := psClear;
        Cx := X + W - 11;
        Cy := Hh div 2;
        if FSortDesc then Canvas.Polygon([Point(Cx - 4, Cy - 2), Point(Cx + 4, Cy - 2), Point(Cx, Cy + 3)])
        else Canvas.Polygon([Point(Cx - 4, Cy + 2), Point(Cx + 4, Cy + 2), Point(Cx, Cy - 3)]);
        Canvas.Pen.Style := psSolid;
      end;
      Canvas.Pen.Color := Grid;
      Canvas.Line(X + W - 1, 3, X + W - 1, Hh - 4);
    end;
  end;
  Canvas.ClipRect := Rect(1, 1, Width - 1, Height - 1);
  Canvas.Font.Style := [];
  { povlacenje stupca: oznaka mjesta }
  if FDragCol >= 0 then
  begin
    Canvas.Pen.Color := TokenColor(T.Accent);
    Canvas.Pen.Width := 3;
    if FDropAt > FDragCol then X := ColLeft(FDropAt) + FColumns[FDropAt].Width else X := ColLeft(FDropAt);
    Canvas.Line(X, 2, X, Hh - 2);
    Canvas.Pen.Width := 1;
  end;
  { redci }
  Ds := nil;
  if FLink.Active then Ds := FLink.DataSet;
  if Ds <> nil then
  begin
    N := FLink.RecordCount;
    Saved := FLink.ActiveRecord;
    Base := 0;
    try
      Base := Ds.RecNo - Saved;
    except
      Base := 0;
    end;
    for R := 0 to N - 1 do
    begin
      Y := RowTopOf(R);
      if Y >= Height - Fh then Break;
      FLink.ActiveRecord := R;
      SelRow := R = Saved;
      Odd_ := Odd(Base + R + 1);
      RowRect := Rect(1, Y, Width - 1 - BarW, Y + Rh);
      Canvas.Pen.Style := psClear;
      if SelRow then
      begin
        if Foc then Canvas.Brush.Color := TokenColor(T.AccentSoft) else Canvas.Brush.Color := TokenColor(MixHex(T.AccentSoft, T.Surface, 0.5));
      end
      else if (FSelCount > 0) and IsSelRec(Base + R) then Canvas.Brush.Color := TokenColor(MixHex(T.AccentSoft, T.Surface, 0.8))
      else if R = FHot then Canvas.Brush.Color := TokenColor(MixHex(T.Soft, T.Surface, 0.55))
      else if FZebra and not Odd_ then Canvas.Brush.Color := TokenColor(MixHex(T.Soft, T.Surface, 0.45))
      else Canvas.Brush.Color := Bg;
      Canvas.FillRect(RowRect.Left, RowRect.Top, RowRect.Right, RowRect.Bottom);
      Canvas.Pen.Style := psSolid;
      Canvas.Pen.Color := Grid;
      Canvas.Line(1, Y + Rh - 1, Width - 1 - BarW, Y + Rh - 1);
      { potkartica: kvadratic + / - }
      if FSubKey <> '' then
      begin
        Canvas.Pen.Color := TxSoft;
        Canvas.Brush.Style := bsClear;
        Canvas.Rectangle(4, Y + (Rh - 11) div 2, 15, Y + (Rh - 11) div 2 + 11);
        Canvas.Line(7, Y + Rh div 2, 12, Y + Rh div 2);
        if not ((R < Length(FRowKey)) and (FExpanded.IndexOf(FRowKey[R]) >= 0)) then Canvas.Line(9, Y + Rh div 2 - 3, 9, Y + Rh div 2 + 3);
        Canvas.Brush.Style := bsSolid;
      end;
      { indikator }
      if FIndicator then
      begin
        if SelRow then
        begin
          Canvas.Brush.Color := TokenColor(T.Accent);
          Canvas.Pen.Color := TokenColor(T.Accent);
          if Ds.State = dsInsert then
          begin
            Canvas.Pen.Width := 2;
            Canvas.Line(ExpW + 6, Y + Rh div 2, ExpW + 13, Y + Rh div 2);
            Canvas.Line(ExpW + 9, Y + Rh div 2 - 4, ExpW + 9, Y + Rh div 2 + 4);
            Canvas.Pen.Width := 1;
          end
          else if Ds.State = dsEdit then
          begin
            Canvas.Pen.Width := 2;
            Canvas.Line(ExpW + 5, Y + Rh div 2 + 4, ExpW + 12, Y + Rh div 2 - 4);
            Canvas.Pen.Width := 1;
            Canvas.Line(ExpW + 5, Y + Rh div 2 + 5, ExpW + 8, Y + Rh div 2 + 5);
          end
          else
          begin
            Canvas.Pen.Style := psClear;
            Canvas.Polygon([Point(ExpW + 5, Y + Rh div 2 - 5), Point(ExpW + 5, Y + Rh div 2 + 5), Point(ExpW + 12, Y + Rh div 2)]);
            Canvas.Pen.Style := psSolid;
          end;
        end;
      end;
      { celije }
      for ColI := 0 to FColumns.Count - 1 do
      begin
        C := FColumns[ColI];
        if not C.Visible then Continue;
        W := C.Width;
        X := ColLeft(ColI);
        if IsFrozenCol(ColI) then Canvas.ClipRect := Rect(1, 1, Width - 1 - BarW, Height - 1)
        else Canvas.ClipRect := Rect(Max(1, IndW + FrozenW), 1, Width - 1 - BarW, Height - 1);
        if (X + W > IndW) and (X < Width - BarW) then
        begin
          Style.Fore := clNone;
          Style.Back := clNone;
          Style.Bold := False;
          if Assigned(FOnPrepare) then FOnPrepare(Self, C, SelRow, Style);
          if Style.Back <> clNone then
          begin
            Canvas.Brush.Color := Style.Back;
            Canvas.Pen.Style := psClear;
            Canvas.FillRect(X, Y, X + W, Y + Rh - 1);
            Canvas.Pen.Style := psSolid;
          end;
          Canvas.Brush.Style := bsClear;
          if Style.Fore <> clNone then Canvas.Font.Color := Style.Fore else Canvas.Font.Color := Tx;
          if Style.Bold then Canvas.Font.Style := [fsBold] else Canvas.Font.Style := [];
          Ts.Alignment := C.Alignment;
          if IsCheck(C) then
          begin
            if C.Field.AsBoolean then
            begin
              Canvas.Pen.Color := TokenColor(T.Accent);
              Canvas.Pen.Width := 2;
              Cx := X + W div 2;
              Cy := Y + Rh div 2;
              Canvas.MoveTo(Cx - 5, Cy);
              Canvas.LineTo(Cx - 2, Cy + 4);
              Canvas.LineTo(Cx + 5, Cy - 4);
              Canvas.Pen.Width := 1;
            end;
          end
          else
          begin
            Txt := CellText(C);
            Canvas.TextRect(Rect(X + 6, Y, X + W - 5, Y + Rh - 1), X + 6, Y, Txt, Ts);
          end;
          Canvas.Font.Style := [];
          Canvas.Pen.Color := Grid;
          Canvas.Line(X + W - 1, Y, X + W - 1, Y + Rh - 1);
          { tekuca celija }
          if SelRow and Foc and (ColI = FCol) then
          begin
            Canvas.Pen.Color := TokenColor(T.Accent);
            Canvas.Brush.Style := bsClear;
            Canvas.Rectangle(X, Y, X + W, Y + Rh - 1);
          end;
          Canvas.Brush.Style := bsSolid;
        end;
      end;
      Canvas.ClipRect := Rect(1, 1, Width - 1, Height - 1);
      { podrucje potkartice }
      if ExtraOf(R) > 0 then
      begin
        Canvas.Brush.Color := TokenColor(MixHex(T.Soft, T.Surface, 0.6));
        Canvas.Pen.Style := psClear;
        Canvas.FillRect(1, Y + Rh, Width - 1 - BarW, Y + Rh + ExtraOf(R));
        Canvas.Pen.Style := psSolid;
        Canvas.Pen.Color := Grid;
        Canvas.Line(1, Y + Rh + ExtraOf(R) - 1, Width - 1 - BarW, Y + Rh + ExtraOf(R) - 1);
        Canvas.Pen.Color := TokenColor(T.Accent);
        Canvas.Line(ExpW div 2 + 1, Y + Rh, ExpW div 2 + 1, Y + Rh + ExtraOf(R) - 1);
      end;
    end;
    FLink.ActiveRecord := Saved;
  end;
  if FrozenCount > 0 then
  begin
    Canvas.Pen.Color := Br;
    Canvas.Pen.Width := 2;
    Canvas.Line(IndW + FrozenW, 1, IndW + FrozenW, Height - Fh - 1);
    Canvas.Pen.Width := 1;
  end;
  Canvas.Clipping := False;
  { podnozje }
  if Fh > 0 then
  begin
    Canvas.Brush.Color := HeadBg;
    Canvas.Pen.Style := psClear;
    Canvas.FillRect(1, Height - Fh - 1, Width - 1, Height - 1);
    Canvas.Pen.Style := psSolid;
    Canvas.Pen.Color := Br;
    Canvas.Line(1, Height - Fh - 1, Width - 1, Height - Fh - 1);
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Style := [fsBold];
    Canvas.Font.Color := Tx;
    Canvas.TextOut(8, Height - Fh + (Fh - Canvas.TextHeight('Ag')) div 2 - 1, FFooter);
    Canvas.Font.Style := [];
    Canvas.Brush.Style := bsSolid;
  end;
  { okomiti klizac }
  if (Ds <> nil) and (Ds.RecordCount > VisRows) then
  begin
    N := Ds.RecordCount;
    ThH := Max(20, (Height - Hh - Fh - BarW) * VisRows div N);
    ThY := Hh + (Height - Hh - Fh - BarW - ThH) * Max(0, Ds.RecNo - 1) div Max(1, N - 1);
    Canvas.Brush.Color := TokenColor(T.Border);
    Canvas.Pen.Style := psClear;
    Canvas.RoundRect(Width - BarW - 1, ThY, Width - 3, ThY + ThH, 4, 4);
    Canvas.Pen.Style := psSolid;
  end;
  { vodoravni klizac }
  if NeedHBar then
  begin
    ThH := Max(24, ViewW * ViewW div TotalW);
    ThY := IndW + (ViewW - ThH) * FScrollX div Max(1, TotalW - ViewW);
    Canvas.Brush.Color := TokenColor(T.Border);
    Canvas.Pen.Style := psClear;
    Canvas.RoundRect(ThY, Height - Fh - BarW - 1, ThY + ThH, Height - Fh - 3, 4, 4);
    Canvas.Pen.Style := psSolid;
  end;
  if Foc then
  begin
    Canvas.Brush.Style := bsClear;
    Canvas.Pen.Color := TokenColor(T.Accent);
    Canvas.Pen.Width := 2;
    Canvas.Rectangle(1, 1, Width - 1, Height - 1);
    Canvas.Pen.Width := 1;
    Canvas.Brush.Style := bsSolid;
  end;
end;

{ ---------------- tipke i mis ---------------- }

procedure TaOwnGrid.KeyDown(var Key: Word; Shift: TShiftState);
var
  Nav, Ext: Boolean;
  Hot: Integer;
begin
  inherited KeyDown(Key, Shift);
  if Key = 0 then Exit;
  case Key of
    VK_F2: begin StartEdit('', False); Key := 0; Exit; end;
    VK_DOWN, VK_UP:
      if (ssAlt in Shift) and (FSubKey <> '') then
      begin
        if (FLink.ActiveRecord >= 0) and (FLink.ActiveRecord < Length(FRowKey)) then
        begin
          if Key = VK_DOWN then ExpandKey(FRowKey[FLink.ActiveRecord]) else CollapseKey(FRowKey[FLink.ActiveRecord]);
        end;
        Key := 0;
        Exit;
      end;
    VK_RETURN: if FAllowEdit and not FReadOnly then begin StartEdit('', False); Key := 0; Exit; end;
    VK_ESCAPE:
      begin
        if FLink.Active and (FLink.DataSet.State in dsEditModes) then
        begin
          FLink.DataSet.Cancel;
          Key := 0;
          Exit;
        end;
        if FSelCount > 0 then begin ClearSelection; Key := 0; Exit; end;
      end;
    VK_SPACE:
      if CanEditCol(FCol) and IsCheck(FColumns[FCol]) then begin ToggleBool; Key := 0; Exit; end;
    VK_INSERT:
      begin
        if ssCtrl in Shift then begin CopyToClipboard; Key := 0; Exit; end;
        if FAllowInsert and not FReadOnly then begin InsertRecord; Key := 0; Exit; end;
      end;
    VK_DELETE: if (ssCtrl in Shift) and FAllowDelete and not FReadOnly then begin DeleteRecord; Key := 0; Exit; end;
    VK_A: if (Shift = [ssCtrl]) and FMulti then begin SelectAllRecords; Key := 0; Exit; end;
    VK_C: if Shift = [ssCtrl] then begin CopyToClipboard; Key := 0; Exit; end;
    VK_TAB:
      if FAllowEdit and not FReadOnly then
      begin
        if ssShift in Shift then Hot := NextVisible(FCol, -1) else Hot := NextVisible(FCol, 1);
        if Hot <> FCol then
        begin
          FCol := Hot;
          EnsureColVisible;
          Invalidate;
          Key := 0;
          Exit;
        end;
      end;
  end;
  Nav := Key in [VK_UP, VK_DOWN, VK_PRIOR, VK_NEXT];
  Ext := (ssShift in Shift) and FMulti;
  if Nav and Ext and FLink.Active and ((FAnchorRec <= 0) or (FSelCount = 0)) then FAnchorRec := CurRec;
  case Key of
    VK_UP: begin MoveRows(-1); Key := 0; end;
    VK_DOWN:
      begin
        if FAllowEdit and FAllowInsert and not FReadOnly and FLink.Active and FLink.DataSet.CanModify and
           (FLink.DataSet.State = dsBrowse) and (FLink.DataSet.RecNo >= FLink.DataSet.RecordCount) and (FLink.DataSet.RecordCount > 0) then
        begin
          try FLink.DataSet.Append; except end;
        end
        else MoveRows(1);
        Key := 0;
      end;
    VK_PRIOR: begin MoveRows(-Max(1, VisRows - 1)); Key := 0; end;
    VK_NEXT: begin MoveRows(Max(1, VisRows - 1)); Key := 0; end;
    VK_HOME:
      begin
        if ssCtrl in Shift then
        begin
          Nav := True;
          if FLink.Active and Ext and ((FAnchorRec <= 0) or (FSelCount = 0)) then FAnchorRec := CurRec;
          if FLink.Active then FLink.DataSet.First;
        end
        else begin FCol := NextVisible(-1, 1); EnsureColVisible; Invalidate; end;
        Key := 0;
      end;
    VK_END:
      begin
        if ssCtrl in Shift then
        begin
          Nav := True;
          if FLink.Active and Ext and ((FAnchorRec <= 0) or (FSelCount = 0)) then FAnchorRec := CurRec;
          if FLink.Active then FLink.DataSet.Last;
        end
        else begin FCol := NextVisible(FColumns.Count, -1); EnsureColVisible; Invalidate; end;
        Key := 0;
      end;
    VK_LEFT: begin FCol := NextVisible(FCol, -1); EnsureColVisible; Invalidate; Key := 0; end;
    VK_RIGHT: begin FCol := NextVisible(FCol, 1); EnsureColVisible; Invalidate; Key := 0; end;
  end;
  if Nav and (Key = 0) then
  begin
    if Ext then ExtendTo(CurRec)
    else
    begin
      if FSelCount > 0 then ClearSelection;
      FAnchorRec := CurRec;
    end;
  end;
end;

procedure TaOwnGrid.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Col, Row, Over, Rec, Base: Integer;
  Again, InExtra, Plain: Boolean;
begin
  inherited MouseDown(Button, Shift, X, Y);
  FLastX := X;
  FLastY := Y;
  if Button <> mbLeft then Exit;
  if CanFocus and not Focused then SetFocus;
  { klizaci }
  if (X >= Width - BarW - 2) and (Y > HeaderH) and (Y < Height - FooterH) then
  begin
    FDragBar := 1;
    VThumbTo(Y);
    Exit;
  end;
  if NeedHBar and (Y >= Height - FooterH - BarW - 2) and (Y < Height - FooterH) then
  begin
    FDragBar := 2;
    HThumbTo(X);
    Exit;
  end;
  if Y < HeaderH then
  begin
    Over := EdgeAtX(X);
    if Over >= 0 then
    begin
      FResizeCol := Over;
      FResizeX0 := X;
      FResizeW0 := FColumns[Over].Width;
      Exit;
    end;
    FHeadDown := ColAtX(X);
    FHeadX0 := X;
    Exit;
  end;
  Row := RowAtY(Y, InExtra);
  if InExtra then Exit;
  if (FSubKey <> '') and (X < ExpW) and (Row >= 0) then
  begin
    ToggleRow(Row);
    Exit;
  end;
  Col := ColAtX(X);
  if FEditing then CommitEdit;
  Again := FLink.Active and (Row = FLink.ActiveRecord) and (Col >= 0) and (Col = FCol);
  Plain := not (ssShift in Shift) and not (ssCtrl in Shift);
  if Col >= 0 then FCol := Col;
  Base := 0;
  if FLink.Active then Base := CurRec - FLink.ActiveRecord;
  Rec := Base + Row;
  if FLink.Active and (Row >= 0) and (Row < FLink.RecordCount) then
  begin
    if FMulti and (ssCtrl in Shift) then
    begin
      EnsureSelMap;
      if FSelCount = 0 then SetSelRec(CurRec, True);
      SetSelRec(Rec, not IsSelRec(Rec));
      FAnchorRec := Rec;
      MoveRows(Row - FLink.ActiveRecord);
    end
    else if FMulti and (ssShift in Shift) then
    begin
      if FAnchorRec <= 0 then FAnchorRec := CurRec;
      MoveRows(Row - FLink.ActiveRecord);
      ExtendTo(Rec);
    end
    else
    begin
      MoveRows(Row - FLink.ActiveRecord);
      if FSelCount > 0 then ClearSelection;
      FAnchorRec := CurRec;
    end;
  end;
  Invalidate;
  if Assigned(FOnCell) and (Col >= 0) then FOnCell(Self, FColumns[Col], CurRec);
  if Again and Plain and CanEditCol(FCol) then
  begin
    if IsCheck(FColumns[FCol]) then ToggleBool else StartEdit('', False);
  end;
end;

procedure TaOwnGrid.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  R: Integer;
  InExtra: Boolean;
  Was: Integer;
begin
  inherited MouseMove(Shift, X, Y);
  FLastX := X;
  FLastY := Y;
  if FResizeCol >= 0 then
  begin
    FColumns[FResizeCol].Width := FResizeW0 + X - FResizeX0;
    Exit;
  end;
  if FDragBar = 1 then begin VThumbTo(Y); Exit; end;
  if FDragBar = 2 then begin HThumbTo(X); Exit; end;
  if (FHeadDown >= 0) and (ssLeft in Shift) then
  begin
    if (FDragCol < 0) and (Abs(X - FHeadX0) > 6) then FDragCol := FHeadDown;
    if FDragCol >= 0 then
    begin
      FDropAt := ColAtX(X);
      if FDropAt < 0 then
      begin
        if X < IndW then FDropAt := NextVisible(-1, 1) else FDropAt := NextVisible(FColumns.Count, -1);
      end;
      Cursor := crDrag;
      Invalidate;
    end;
    Exit;
  end;
  if (Y < HeaderH) and (EdgeAtX(X) >= 0) then Cursor := crHSplit else Cursor := crDefault;
  Was := FHot;
  R := RowAtY(Y, InExtra);
  if InExtra or (Y < HeaderH) or (X >= Width - BarW - 2) then R := -1;
  FHot := R;
  if Was <> FHot then Invalidate;
  UpdateHint(X, R);
end;

procedure TaOwnGrid.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  FResizeCol := -1;
  FDragBar := 0;
  if FHeadDown >= 0 then
  begin
    if FDragCol >= 0 then
    begin
      if (FDropAt >= 0) and (FDropAt <> FDragCol) then MoveColumn(FDragCol, FDropAt);
    end
    else if Assigned(FOnTitle) and (FHeadDown < FColumns.Count) then FOnTitle(Self, FColumns[FHeadDown]);
  end;
  FHeadDown := -1;
  FDragCol := -1;
  Cursor := crDefault;
  Invalidate;
end;

procedure TaOwnGrid.MouseLeave;
begin
  inherited MouseLeave;
  if FHot <> -1 then
  begin
    FHot := -1;
    Invalidate;
  end;
end;

function TaOwnGrid.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
begin
  Result := True;
  if ssShift in Shift then
  begin
    if WheelDelta > 0 then Dec(FScrollX, 60) else Inc(FScrollX, 60);
    FScrollX := Max(0, Min(Max(0, TotalW - ViewW), FScrollX));
    Invalidate;
  end
  else if WheelDelta > 0 then MoveRows(-3) else MoveRows(3);
end;

procedure TaOwnGrid.DoEnter;
begin
  inherited DoEnter;
  Invalidate;
end;

procedure TaOwnGrid.DoExit;
begin
  inherited DoExit;
  Invalidate;
end;

procedure TaOwnGrid.Resize;
begin
  inherited Resize;
  if (FColumns = nil) or (FLink = nil) then Exit;
  if (Parent <> nil) and ((Width <> FLastW) or (Height <> FLastH)) then
  begin
    FLastW := Width;
    FLastH := Height;
    FixBuffer;
    Geometry;
  end;
  if FScrollX > Max(0, TotalW - ViewW) then FScrollX := Max(0, TotalW - ViewW);
end;

{ ---------------- oznacavanje, kopiranje, sirina ---------------- }

{ pokazi cijeli tekst celije ispod misa kad ne stane }
procedure TaOwnGrid.UpdateHint(X, ARow: Integer);
var
  Col: Integer;
  Saved: Integer;
  Txt, Key: string;
begin
  Txt := '';
  Col := ColAtX(X);
  if (ARow >= 0) and (Col >= 0) and FLink.Active and (ARow < FLink.RecordCount) and not IsCheck(FColumns[Col]) then
  begin
    Saved := FLink.ActiveRecord;
    try
      FLink.ActiveRecord := ARow;
      Txt := CellText(FColumns[Col]);
    finally
      FLink.ActiveRecord := Saved;
    end;
    Canvas.Font.Assign(Font);
    if Canvas.TextWidth(Txt) <= FColumns[Col].Width - 12 then Txt := '';
  end;
  Key := IntToStr(ARow) + '/' + IntToStr(Col) + '/' + Txt;
  if Key = FHintKey then Exit;
  FHintKey := Key;
  Hint := Txt;
  ShowHint := Txt <> '';
  if Txt <> '' then Application.CancelHint;
end;

function TaOwnGrid.CurRec: Integer;
begin
  Result := 0;
  if not FLink.Active then Exit;
  try
    Result := FLink.DataSet.RecNo;
  except
    Result := 0;
  end;
end;

procedure TaOwnGrid.EnsureSelMap;
var
  N: Integer;
begin
  N := 0;
  if FLink.Active then N := FLink.DataSet.RecordCount;
  if Length(FSelMap) <> N then
  begin
    SetLength(FSelMap, 0);
    SetLength(FSelMap, N);
    FSelCount := 0;
  end;
end;

function TaOwnGrid.IsSelRec(ARec: Integer): Boolean;
begin
  Result := (ARec >= 1) and (ARec <= Length(FSelMap)) and FSelMap[ARec - 1];
end;

procedure TaOwnGrid.SetSelRec(ARec: Integer; AValue: Boolean);
begin
  EnsureSelMap;
  if (ARec < 1) or (ARec > Length(FSelMap)) then Exit;
  if FSelMap[ARec - 1] = AValue then Exit;
  FSelMap[ARec - 1] := AValue;
  if AValue then Inc(FSelCount) else Dec(FSelCount);
  SelChanged;
end;

procedure TaOwnGrid.SelChanged;
begin
  Invalidate;
  if Assigned(FOnSel) then FOnSel(Self);
end;

procedure TaOwnGrid.SelectRecRange(A, B: Integer);
var
  I: Integer;
begin
  EnsureSelMap;
  if A > B then begin I := A; A := B; B := I; end;
  A := Max(1, A);
  B := Min(Length(FSelMap), B);
  for I := A to B do
    if not FSelMap[I - 1] then
    begin
      FSelMap[I - 1] := True;
      Inc(FSelCount);
    end;
  SelChanged;
end;

{ raspon od sidra do zapisa; sve ostalo se odznaci }
procedure TaOwnGrid.ExtendTo(ARec: Integer);
begin
  EnsureSelMap;
  if FAnchorRec <= 0 then FAnchorRec := ARec;
  if FSelCount > 0 then
  begin
    SetLength(FSelMap, 0);
    SetLength(FSelMap, FLink.DataSet.RecordCount);
    FSelCount := 0;
  end;
  SelectRecRange(FAnchorRec, ARec);
end;

procedure TaOwnGrid.ClearSelection;
begin
  if FSelCount = 0 then Exit;
  SetLength(FSelMap, 0);
  FSelCount := 0;
  SelChanged;
end;

procedure TaOwnGrid.SelectAllRecords;
begin
  if not FLink.Active then Exit;
  EnsureSelMap;
  if Length(FSelMap) = 0 then Exit;
  SelectRecRange(1, Length(FSelMap));
end;

function TaOwnGrid.SelectedCount: Integer;
begin
  Result := FSelCount;
end;

function TaOwnGrid.SelectionText(AHeader: Boolean): string;
var
  Ds: TDataSet;
  Bm: TBookmark;
  I, N, K: Integer;
  Line: string;
  C: TaGridColumn;
begin
  Result := '';
  if not FLink.Active then Exit;
  Ds := FLink.DataSet;
  if AHeader then
  begin
    Line := '';
    for K := 0 to FColumns.Count - 1 do
      if FColumns[K].Visible then
      begin
        if Line <> '' then Line := Line + #9;
        Line := Line + FColumns[K].Title;
      end;
    Result := Line + LineEnding;
  end;
  EnsureSelMap;
  Ds.DisableControls;
  Bm := Ds.GetBookmark;
  try
    for I := 1 to Ds.RecordCount do
    begin
      if (FSelCount > 0) and not IsSelRec(I) then Continue;
      if (FSelCount = 0) and (I <> CurRec) then Continue;
      Ds.RecNo := I;
      Line := '';
      for K := 0 to FColumns.Count - 1 do
      begin
        C := FColumns[K];
        if not C.Visible then Continue;
        if Line <> '' then Line := Line + #9;
        Line := Line + CellText(C);
      end;
      Result := Result + Line + LineEnding;
    end;
  finally
    try Ds.GotoBookmark(Bm); except end;
    Ds.FreeBookmark(Bm);
    Ds.EnableControls;
  end;
  N := Length(Result);
  if (N >= Length(LineEnding)) and (Copy(Result, N - Length(LineEnding) + 1, Length(LineEnding)) = LineEnding) then
    Result := Copy(Result, 1, N - Length(LineEnding));
end;

procedure TaOwnGrid.CopyToClipboard;
var
  C: TaGridColumn;
begin
  if FSelCount > 0 then
  begin
    Clipboard.AsText := SelectionText(False);
    Exit;
  end;
  C := CurrentColumn;
  if (C <> nil) and FLink.Active then Clipboard.AsText := CellText(C);
end;

procedure TaOwnGrid.AutoFitColumn(AIndex: Integer);
var
  W, Cnt: Integer;
  C: TaGridColumn;
  Ds: TDataSet;
  Bm: TBookmark;
begin
  if (AIndex < 0) or (AIndex >= FColumns.Count) then Exit;
  C := FColumns[AIndex];
  Canvas.Font.Assign(Font);
  Canvas.Font.Style := [fsBold];
  W := Canvas.TextWidth(C.Title) + 28;
  Canvas.Font.Style := [];
  if IsCheck(C) then W := Max(W, 64)
  else if FLink.Active then
  begin
    Ds := FLink.DataSet;
    Ds.DisableControls;
    Bm := Ds.GetBookmark;
    try
      Ds.First;
      Cnt := 0;
      while (not Ds.EOF) and (Cnt < 300) do
      begin
        W := Max(W, Canvas.TextWidth(CellText(C)) + 18);
        Ds.Next;
        Inc(Cnt);
      end;
    finally
      try Ds.GotoBookmark(Bm); except end;
      Ds.FreeBookmark(Bm);
      Ds.EnableControls;
    end;
  end;
  C.Width := Max(MinColW, Min(500, W));
end;

procedure TaOwnGrid.AutoFitAll;
var
  I: Integer;
begin
  for I := 0 to FColumns.Count - 1 do
    if FColumns[I].Visible then AutoFitColumn(I);
end;

procedure TaOwnGrid.MoveColumn(AFrom, ATo: Integer);
var
  Cur: TaGridColumn;
begin
  if (AFrom < 0) or (ATo < 0) or (AFrom >= FColumns.Count) or (ATo >= FColumns.Count) or (AFrom = ATo) then Exit;
  Cur := CurrentColumn;
  FColumns[AFrom].Index := ATo;
  if Cur <> nil then FCol := Cur.Index;
  ResolveFields;
  Invalidate;
end;

{ ---------------- raspored redaka i potkartice ---------------- }

function TaOwnGrid.ExtraOf(ARow: Integer): Integer;
begin
  if (ARow >= 0) and (ARow < Length(FRowExtra)) then Result := FRowExtra[ARow] else Result := 0;
end;

function TaOwnGrid.PreferredHeight(AMaxRows: Integer): Integer;
var
  N: Integer;
begin
  N := 1;
  if FLink.Active then N := Max(1, Min(AMaxRows, FLink.DataSet.RecordCount));
  Result := HeaderH + N * FRowH + 3 + FooterH;
  if TotalW > Width - IndW - BarW - 2 then Inc(Result, BarW);
end;

{ visina potkartice po retku medjuspremnika; kljuc retka }
procedure TaOwnGrid.RecalcExtra;
var
  R, N, Saved, I: Integer;
  F: TField;
  K: string;
begin
  N := 0;
  if FLink.Active then N := FLink.RecordCount;
  SetLength(FRowExtra, N);
  SetLength(FRowKey, N);
  if (N = 0) or (FSubKey = '') then
  begin
    for R := 0 to N - 1 do begin FRowExtra[R] := 0; FRowKey[R] := ''; end;
    Exit;
  end;
  F := FLink.DataSet.FindField(FSubKey);
  Saved := FLink.ActiveRecord;
  try
    for R := 0 to N - 1 do
    begin
      FRowExtra[R] := 0;
      FRowKey[R] := '';
      if F = nil then Continue;
      FLink.ActiveRecord := R;
      K := F.AsString;
      FRowKey[R] := K;
      if FExpanded.IndexOf(K) >= 0 then
      begin
        I := FChildren.IndexOf(K);
        if I >= 0 then FRowExtra[R] := TaOwnGrid(FChildren.Objects[I]).PreferredHeight(FSubMax) + 10;
      end;
    end;
  finally
    FLink.ActiveRecord := Saved;
  end;
end;

function TaOwnGrid.RowTopOf(ARow: Integer): Integer;
var
  R: Integer;
begin
  Result := HeaderH;
  for R := 0 to ARow - 1 do Inc(Result, FRowH + ExtraOf(R));
end;

function TaOwnGrid.RowAtY(Y: Integer; out InExtra: Boolean): Integer;
var
  R, T, N: Integer;
begin
  InExtra := False;
  Result := -1;
  N := RowCount;
  T := HeaderH;
  for R := 0 to N - 1 do
  begin
    if (Y >= T) and (Y < T + FRowH) then Exit(R);
    if (Y >= T + FRowH) and (Y < T + FRowH + ExtraOf(R)) then
    begin
      InExtra := True;
      Exit(R);
    end;
    Inc(T, FRowH + ExtraOf(R));
  end;
end;

{ tekuci redak mora ostati u vidljivom dijelu kad potkartice zauzmu mjesto: smanji medjuspremnik }
procedure TaOwnGrid.AdjustBuffer;
var
  Guard, ViewH, Bottom, Act: Integer;
begin
  if FAdjusting or not FLink.Active or (Parent = nil) then Exit;
  FAdjusting := True;
  try
    if FLink.BufferCount <> VisRows then FLink.BufferCount := VisRows;
    RecalcExtra;
    if FExpanded.Count = 0 then Exit;
    ViewH := Height - FooterH - 2;
    if NeedHBar then Dec(ViewH, BarW);
    Guard := 0;
    repeat
      Act := FLink.ActiveRecord;
      Bottom := RowTopOf(Act) + FRowH + ExtraOf(Act);
      if (Bottom <= ViewH) or (FLink.BufferCount <= 1) or (Guard > 40) then Break;
      FLink.BufferCount := FLink.BufferCount - 1;
      RecalcExtra;
      Inc(Guard);
    until False;
  finally
    FAdjusting := False;
  end;
end;

procedure TaOwnGrid.PlaceChildren;
var
  I, R: Integer;
  Ch: TaOwnGrid;
begin
  for I := 0 to FChildren.Count - 1 do TaOwnGrid(FChildren.Objects[I]).Visible := False;
  for R := 0 to Length(FRowExtra) - 1 do
    if FRowExtra[R] > 0 then
    begin
      I := FChildren.IndexOf(FRowKey[R]);
      if I < 0 then Continue;
      Ch := TaOwnGrid(FChildren.Objects[I]);
      Ch.SetBounds(ExpW + 12, RowTopOf(R) + FRowH + 4, Max(60, Width - ExpW - 12 - BarW - 12), FRowExtra[R] - 10);
      Ch.Visible := RowTopOf(R) < Height - FooterH;
    end;
end;

procedure TaOwnGrid.Geometry;
begin
  if FInGeometry then Exit;
  FInGeometry := True;
  try
    if FSubKey <> '' then
    begin
      AdjustBuffer;
      RecalcExtra;
      PlaceChildren;
    end;
  finally
    FInGeometry := False;
  end;
  Invalidate;
end;

procedure TaOwnGrid.SetSubKey(const AValue: string);
begin
  if FSubKey = AValue then Exit;
  CollapseAll;
  FSubKey := AValue;
  Geometry;
end;

function TaOwnGrid.IsExpanded(const AKey: string): Boolean;
begin
  Result := (FExpanded <> nil) and (FExpanded.IndexOf(AKey) >= 0);
end;

function TaOwnGrid.ChildOf(const AKey: string): TaOwnGrid;
var
  I: Integer;
begin
  I := FChildren.IndexOf(AKey);
  if I >= 0 then Result := TaOwnGrid(FChildren.Objects[I]) else Result := nil;
end;

procedure TaOwnGrid.ExpandKey(const AKey: string);
var
  Ch: TaOwnGrid;
begin
  if (FExpanded = nil) or (FSubKey = '') or (AKey = '') or IsExpanded(AKey) or not Assigned(FOnSubOpen) then Exit;
  Ch := TaOwnGrid.Create(Self);
  Ch.Visible := False;
  Ch.Parent := Self;
  Ch.ShowIndicator := False;
  Ch.RowHeight := Max(20, FRowH - 4);
  FExpanded.Add(AKey);
  FChildren.AddObject(AKey, Ch);
  FOnSubOpen(Self, AKey, Ch);
  Geometry;
end;

procedure TaOwnGrid.CollapseKey(const AKey: string);
var
  I: Integer;
  Ch: TaOwnGrid;
begin
  I := FChildren.IndexOf(AKey);
  if I >= 0 then
  begin
    Ch := TaOwnGrid(FChildren.Objects[I]);
    FChildren.Delete(I);
    if Assigned(FOnSubClose) then FOnSubClose(Self, AKey, Ch);
    Ch.DataSource := nil;
    Ch.Free;
  end;
  I := FExpanded.IndexOf(AKey);
  if I >= 0 then FExpanded.Delete(I);
  if not (csDestroying in ComponentState) then Geometry;
end;

procedure TaOwnGrid.CollapseAll;
var
  I: Integer;
  Ch: TaOwnGrid;
  K: string;
begin
  if (FChildren = nil) or (FExpanded = nil) then Exit;
  for I := FChildren.Count - 1 downto 0 do
  begin
    K := FChildren[I];
    Ch := TaOwnGrid(FChildren.Objects[I]);
    FChildren.Delete(I);
    if Assigned(FOnSubClose) then FOnSubClose(Self, K, Ch);
    Ch.DataSource := nil;
    Ch.Free;
  end;
  FExpanded.Clear;
end;

procedure TaOwnGrid.ToggleRow(ARow: Integer);
var
  K: string;
begin
  if (ARow < 0) or (ARow >= Length(FRowKey)) then Exit;
  K := FRowKey[ARow];
  if K = '' then Exit;
  if IsExpanded(K) then CollapseKey(K) else ExpandKey(K);
end;

{ ---------------- uredjivanje ---------------- }

function TaOwnGrid.Editing: Boolean;
begin
  Result := FEditing;
end;

function TaOwnGrid.CanEditCol(AIndex: Integer): Boolean;
var
  C: TaGridColumn;
begin
  Result := False;
  if FReadOnly or not FAllowEdit or not FLink.Active then Exit;
  if (AIndex < 0) or (AIndex >= FColumns.Count) then Exit;
  C := FColumns[AIndex];
  if C.ReadOnly or (C.Field = nil) or C.Field.ReadOnly or (C.Field.FieldKind <> fkData) then Exit;
  if not FLink.DataSet.CanModify then Exit;
  Result := True;
end;

procedure TaOwnGrid.ReportError(const AMessage: string);
begin
  if Assigned(FOnError) then FOnError(Self, AMessage) else MessageDlg(AMessage, mtError, [mbOK], 0);
end;

procedure TaOwnGrid.StartEdit(const AInitial: string; AReplace: Boolean);
var
  C: TaGridColumn;
  Ctl: TaOwnEdit;
  Txt: string;
  X, Y: Integer;
begin
  if FEditing or not CanEditCol(FCol) then Exit;
  C := FColumns[FCol];
  if IsCheck(C) then Exit;
  EnsureColVisible;
  if C.PickList.Count > 0 then
  begin
    if FCombo = nil then
    begin
      FCombo := TaOwnCombo.Create(Self);
      FCombo.Visible := False;
      FCombo.Parent := Self;
    end;
    FCombo.Droplist := True;
    FCombo.Items.Assign(C.PickList);
    Ctl := FCombo;
  end
  else
  begin
    if FEditor = nil then
    begin
      FEditor := TaOwnEdit.Create(Self);
      FEditor.Visible := False;
      FEditor.Parent := Self;
    end;
    Ctl := FEditor;
  end;
  Txt := CellText(C);
  X := ColLeft(FCol);
  Y := RowTopOf(FLink.ActiveRecord);
  Ctl.SetBounds(X, Y, C.Width, FRowH);
  Ctl.Alignment := C.Alignment;
  if Ctl = FCombo then FCombo.ItemIndex := FCombo.Items.IndexOf(Txt) else Ctl.Text := Txt;
  FOrig := Txt;
  FCur := Ctl;
  FEditing := True;
  Ctl.OnExit := @EditorExit;
  TWinControl(Ctl).OnKeyDown := @EditorKey;
  Ctl.Visible := True;
  Ctl.BringToFront;
  if Ctl.CanFocus then Ctl.SetFocus;
  if AReplace and (Ctl <> FCombo) then Ctl.Text := AInitial;
end;

{ sakrij uredjivac bez upisa (zapis se mijenja pod nama ili se odustaje) }
procedure TaOwnGrid.EndEditUI;
var
  Was: TaOwnEdit;
begin
  if not FEditing then Exit;
  Was := FCur;
  FEditing := False;
  FCur := nil;
  if Was <> nil then
  begin
    if (Was = FCombo) and FCombo.IsOpen then FCombo.ClosePopup;
    Was.Visible := False;
  end;
  if CanFocus and Visible and not Focused then
    try SetFocus; except end;
  Invalidate;
end;

procedure TaOwnGrid.CancelEdit;
begin
  EndEditUI;
end;

procedure TaOwnGrid.ApplyText(const AText: string);
var
  Ds: TDataSet;
  F: TField;
  Started: Boolean;
begin
  if not FLink.Active then Exit;
  Ds := FLink.DataSet;
  F := FColumns[FCol].Field;
  if F = nil then Exit;
  Started := False;
  try
    if not (Ds.State in dsEditModes) then
    begin
      Ds.Edit;
      Started := True;
    end;
    if (F.DataType in [ftMemo, ftWideMemo, ftFmtMemo]) and not Assigned(F.OnSetText) then F.AsString := AText
    else F.Text := AText;
  except
    on E: Exception do
    begin
      if Started and (Ds.State = dsEdit) then Ds.Cancel;
      ReportError(E.Message);
    end;
  end;
  Invalidate;
end;

procedure TaOwnGrid.CommitEdit;
var
  Txt: string;
begin
  if not FEditing then Exit;
  Txt := FCur.Text;
  if (FCur = FCombo) and (FCombo.ItemIndex >= 0) then Txt := FCombo.Items[FCombo.ItemIndex];
  EndEditUI;
  if Txt <> FOrig then ApplyText(Txt);
end;

procedure TaOwnGrid.EditorExit(Sender: TObject);
begin
  if FEditing then CommitEdit;
end;

{ ADir: 1 desno, -1 lijevo, 2 dolje; nakon uredjivanja }
procedure TaOwnGrid.Advance(ADir: Integer);
var
  Ds: TDataSet;
  N: Integer;
  AtEnd: Boolean;
begin
  if not FLink.Active then Exit;
  Ds := FLink.DataSet;
  case ADir of
    1:
      begin
        N := NextVisible(FCol, 1);
        if N <> FCol then FCol := N
        else
        begin
          { zadnja celija: sljedeci redak ili novi }
          AtEnd := False;
          if FAutoAppend then
          begin
            Ds.DisableControls;
            try
              N := Ds.RecNo;
              Ds.Next;
              AtEnd := Ds.RecNo = N;
              if not AtEnd then Ds.Prior;
            finally
              Ds.EnableControls;
            end;
          end;
          if AtEnd and (Ds.State <> dsInsert) then
          begin
            try Ds.Append; except end;
          end
          else MoveRows(1);
          FCol := NextVisible(-1, 1);
        end;
      end;
    -1:
      begin
        N := NextVisible(FCol, -1);
        if N <> FCol then FCol := N;
      end;
    2: MoveRows(1);
  end;
  EnsureColVisible;
  Invalidate;
  if FAlways then StartEdit('', False);
end;

procedure TaOwnGrid.EditorKey(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  case Key of
    VK_RETURN:
      begin
        Key := 0;
        CommitEdit;
        Advance(2);
      end;
    VK_TAB:
      begin
        Key := 0;
        CommitEdit;
        if ssShift in Shift then Advance(-1) else Advance(1);
      end;
    VK_ESCAPE:
      begin
        Key := 0;
        CancelEdit;
      end;
    VK_UP:
      if not ((FCur = FCombo) and FCombo.IsOpen) and (FCur <> FCombo) then
      begin
        Key := 0;
        CommitEdit;
        MoveRows(-1);
        if FAlways then StartEdit('', False);
      end;
    VK_DOWN:
      if not ((FCur = FCombo) and FCombo.IsOpen) and (FCur <> FCombo) then
      begin
        Key := 0;
        CommitEdit;
        MoveRows(1);
        if FAlways then StartEdit('', False);
      end;
  end;
end;

procedure TaOwnGrid.ToggleBool;
var
  Ds: TDataSet;
  F: TField;
  Started: Boolean;
begin
  if not CanEditCol(FCol) then Exit;
  Ds := FLink.DataSet;
  F := FColumns[FCol].Field;
  Started := False;
  try
    if not (Ds.State in dsEditModes) then begin Ds.Edit; Started := True; end;
    F.AsBoolean := not F.AsBoolean;
  except
    on E: Exception do
    begin
      if Started and (Ds.State = dsEdit) then Ds.Cancel;
      ReportError(E.Message);
    end;
  end;
  Invalidate;
end;

procedure TaOwnGrid.InsertRecord;
begin
  if not FLink.Active or not FLink.DataSet.CanModify then Exit;
  if FEditing then CommitEdit;
  try
    FLink.DataSet.Insert;
  except
    on E: Exception do ReportError(E.Message);
  end;
  Invalidate;
end;

procedure TaOwnGrid.DeleteRecord;
var
  Ok: Boolean;
  Ds: TDataSet;
  N, I: Integer;
  Recs: array of Integer;
begin
  if not FLink.Active or not FLink.DataSet.CanModify or FLink.DataSet.IsEmpty then Exit;
  Ds := FLink.DataSet;
  if FEditing then CancelEdit;
  EnsureSelMap;
  if FSelCount > 1 then
  begin
    if Assigned(FOnConfirm) then Ok := FOnConfirm(Self, Tr('Delete the selected records?'))
    else Ok := MessageDlg(Tr('Delete the selected records?'), mtConfirmation, [mbYes, mbNo], 0) = mrYes;
    if not Ok then Exit;
    SetLength(Recs, 0);
    for I := Length(FSelMap) downto 1 do
      if FSelMap[I - 1] then
      begin
        SetLength(Recs, Length(Recs) + 1);
        Recs[High(Recs)] := I;
      end;
    Ds.DisableControls;
    try
      for N := 0 to High(Recs) do
      begin
        try
          Ds.RecNo := Recs[N];
          Ds.Delete;
        except
          on E: Exception do begin ReportError(E.Message); Break; end;
        end;
      end;
    finally
      Ds.EnableControls;
    end;
    ClearSelection;
    Invalidate;
    Exit;
  end;
  if Assigned(FOnConfirm) then Ok := FOnConfirm(Self, Tr('Delete the record?'))
  else Ok := MessageDlg(Tr('Delete the record?'), mtConfirmation, [mbYes, mbNo], 0) = mrYes;
  if not Ok then Exit;
  try
    Ds.Delete;
  except
    on E: Exception do ReportError(E.Message);
  end;
  Invalidate;
end;

procedure TaOwnGrid.UTF8KeyPress(var UTF8Key: TUTF8Char);
begin
  inherited UTF8KeyPress(UTF8Key);
  if (UTF8Key = '') or FEditing or not FAllowEdit or FReadOnly then Exit;
  if (Length(UTF8Key) = 1) and (Ord(UTF8Key[1]) < 32) then Exit;
  if CanEditCol(FCol) and not IsCheck(FColumns[FCol]) then
  begin
    StartEdit(UTF8Key, True);
    UTF8Key := '';
  end;
end;

procedure TaOwnGrid.DblClick;
var
  E: Integer;
begin
  inherited DblClick;
  if FLastY < HeaderH then
  begin
    E := EdgeAtX(FLastX);
    if E >= 0 then AutoFitColumn(E);
    Exit;
  end;
  if CanEditCol(FCol) and not IsCheck(FColumns[FCol]) then StartEdit('', False);
end;

{ ---------------- pokretac ---------------- }

constructor TaOwnGridEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FGrid := TaOwnGrid.Create(nil);
  FGrid.ShowIndicator := not DatasheetStyle;
  if DatasheetStyle then FGrid.RowHeight := 22;
  FGrid.AllowEdit := VariantOf <> gvReadOnly;
  FGrid.AutoAppend := VariantOf = gvEntry;
  FGrid.AlwaysEdit := VariantOf = gvEntry;
  FLink := TaGridFooterLink.Create;
  FLink.OnRefresh := @RefreshFooter;
  AttachInner(FGrid);
end;

destructor TaOwnGridEngine.Destroy;
begin
  if FLink <> nil then
  begin
    FLink.OnRefresh := nil;
    FLink.DataSource := nil;
    FLink.Free;
  end;
  inherited Destroy;
end;

class function TaOwnGridEngine.Provider: string;
begin
  Result := 'own';
end;

function TaOwnGridEngine.VariantOf: TaGridVariant;
begin
  Result := gvReadOnly;
end;

function TaOwnGridEngine.DatasheetStyle: Boolean;
begin
  Result := VariantOf = gvDatasheet;
end;

function TaOwnGridDatasheetEngine.VariantOf: TaGridVariant;
begin
  Result := gvDatasheet;
end;

function TaOwnGridEditableEngine.VariantOf: TaGridVariant;
begin
  Result := gvEditable;
end;

function TaOwnGridEntryEngine.VariantOf: TaGridVariant;
begin
  Result := gvEntry;
end;

function TaOwnGridEngine.GetText: string;
begin
  Result := '';
end;

procedure TaOwnGridEngine.SetText(const AValue: string);
begin
end;

procedure TaOwnGridEngine.SetReadOnly(AValue: Boolean);
begin
  FGrid.ReadOnly := AValue;
end;

procedure TaOwnGridEngine.ApplyOptions(AOptions: TPersistent);
begin
  if AOptions is TaGridOptions then
  begin
    if TaGridOptions(AOptions).RowHeight > 0 then FGrid.RowHeight := TaGridOptions(AOptions).RowHeight;
    FGrid.Zebra := TaGridOptions(AOptions).Zebra;
    FGrid.FrozenColumns := TaGridOptions(AOptions).FrozenColumns;
    FSumFields := TaGridOptions(AOptions).SumFields;
    RefreshFooter(nil);
  end;
end;

procedure TaOwnGridEngine.SetSource(ASource: TDataSource);
begin
  FGrid.DataSource := ASource;
  FLink.DataSource := ASource;
  RefreshFooter(nil);
end;

function TaOwnGridEngine.InnerDBGrid: TDBGrid;
begin
  Result := nil;
end;

function TaOwnGridEngine.FooterText: string;
begin
  Result := '';
  if FLink.Active then Result := GridFooterSums(FLink.DataSet, FSumFields);
end;

procedure TaOwnGridEngine.RefreshFooter(Sender: TObject);
begin
  if FRefreshing then Exit;
  FRefreshing := True;
  try
    FGrid.FooterText := FooterText;
  finally
    FRefreshing := False;
  end;
end;

initialization
  RegisterEngine(GridFamily, 'readonly', TaOwnGridEngine);
  RegisterEngine(GridFamily, 'datasheet', TaOwnGridDatasheetEngine);
  RegisterEngine(GridFamily, 'editable', TaOwnGridEditableEngine);
  RegisterEngine(GridFamily, 'entry', TaOwnGridEntryEngine);

end.
