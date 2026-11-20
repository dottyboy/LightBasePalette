unit ta_grid;
{ Obitelj Grid: tablica nad izvorom podataka. Varijante: readonly (samo pregled, odabir retka), editable (izmjena u
  ćeliji) i datasheet (sazeto, bez indikatora). Pokretac je TDBGrid (plan: TRxDBGrid, nije u paketima, pa je TDBGrid
  zadani); DataSource se prosljeduje pokretacu. Nije jos: footer-sum, red filtara i varijanta entry. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, Grids, DBGrids, DB, Graphics, Variants, ExtCtrls, StdCtrls, LCLType, ta_family, ta_formdef;

{ zbrojevi stupaca (polja odvojena zarezom) kao tekst podnozja "iznos: 123,45"; prazno bez zbrojeva }
function GridFooterSums(ADs: TDataSet; const ASumFields: string): string;

type
  TaGridVariant = (gvReadOnly, gvEditable, gvDatasheet, gvEntry);

const
  GridVariantNames: array[TaGridVariant] of string = ('readonly', 'editable', 'datasheet', 'entry');
  GridFamily = 'Grid';

type
  TaGridOptions = class(TPersistent)
  private
    FRowHeight: Integer;
    FZebra: Boolean;
    FSumFields: string;
    FFrozen: Integer;
  public
    procedure Assign(ASource: TPersistent); override;
  published
    { 0 = zadano }
    property RowHeight: Integer read FRowHeight write FRowHeight default 0;
    { naizmjenicno obojani redci }
    property Zebra: Boolean read FZebra write FZebra default False;
    { zbrojevi stupaca u podnozju, polja odvojena zarezom (npr. iznos,kolicina) }
    property SumFields: string read FSumFields write FSumFields;
    { zamrznuti stupci: prvih N vidljivih ne klize vodoravno (samo vlastita tablica) }
    property FrozenColumns: Integer read FFrozen write FFrozen default 0;
  end;

  TaGridFooterLink = class(TDataLink)
  private
    FOnRefresh: TNotifyEvent;
  protected
    procedure DataSetChanged; override;
    procedure ActiveChanged; override;
  public
    property OnRefresh: TNotifyEvent read FOnRefresh write FOnRefresh;
  end;

  { zajednicki dio pokretaca mreze (LCL i neobavezni, npr. TRxDBGrid u paketu typhaccess_ext) }
  TaGridDataEngine = class(TaEngine)
  public
    procedure SetSource(ASource: TDataSource); virtual; abstract;
    function FooterText: string; virtual;
    function InnerDBGrid: TDBGrid; virtual; abstract;
  end;

  TaGridEngine = class(TaGridDataEngine)
  private
    FRoot: TPanel;
    FGrid: TDBGrid;
    FFooter: TPanel;
    FFooterLabel: TLabel;
    FLink: TaGridFooterLink;
    FSumFields: string;
    FRefreshing: Boolean;
    FZebra: Boolean;
    procedure GridPrepare(Sender: TObject; DataCol: Integer; Column: TColumn; AState: TGridDrawState);
    procedure GridKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure RefreshFooter(Sender: TObject);
  protected
    function Variant: TaGridVariant; virtual;
  public
    destructor Destroy; override;
    { tekst podnozja ("iznos: 123,45") ili prazno }
    function FooterText: string; override;
    constructor Create(AHost: TaFamilyHost); override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
    procedure SetReadOnly(AValue: Boolean); override;
    procedure ApplyOptions(AOptions: TPersistent); override;
    procedure SetSource(ASource: TDataSource); override;
    function InnerDBGrid: TDBGrid; override;
    property Grid: TDBGrid read FGrid;
  end;

  TaGridEditableEngine = class(TaGridEngine)
  protected
    function Variant: TaGridVariant; override;
  end;

  TaGridDatasheetEngine = class(TaGridEngine)
  protected
    function Variant: TaGridVariant; override;
  end;

  TaGridEntryEngine = class(TaGridEngine)
  protected
    function Variant: TaGridVariant; override;
  end;

  TaGrid = class(TaFamilyHost)
  private
    FVariant: TaGridVariant;
    FOptions: TaGridOptions;
    FReadOnly: Boolean;
    FDataSource: TDataSource;
    FVisibleIf, FEnabledIf, FCondFormat, FExtra: string;
    function GetVariant: TaGridVariant;
    procedure SetVariant(AValue: TaGridVariant);
    function GetOptions: TaGridOptions;
    procedure SetOptions(AValue: TaGridOptions);
    procedure SetReadOnly(AValue: Boolean);
    procedure SetDataSource(AValue: TDataSource);
    procedure PushToEngine;
  protected
    function CreateEngine: TaEngine; override;
    function RealGetText: TCaption; override;
    procedure RealSetText(const AValue: TCaption); override;
    procedure Notification(AComponent: TComponent; AOperation: TOperation); override;
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function VariantName: string;
    { stvarna mreza, za zadavanje stupaca i ispitivanje }
    function InnerGrid: TDBGrid;
    { podnozje sa zbrojevima (Options.SumFields) }
    function FooterText: string;
  published
    property Variant: TaGridVariant read GetVariant write SetVariant default gvReadOnly;
    property Options: TaGridOptions read GetOptions write SetOptions;
    property ReadOnly: Boolean read FReadOnly write SetReadOnly default False;
    property DataSource: TDataSource read FDataSource write SetDataSource;
    property VisibleIf: string read FVisibleIf write FVisibleIf;
    property EnabledIf: string read FEnabledIf write FEnabledIf;
    property CondFormat: string read FCondFormat write FCondFormat;
    property Extra: string read FExtra write FExtra;
    property Align;
    property Anchors;
    property Enabled;
    property Visible;
    property Hint;
    property ShowHint;
    property TabOrder;
    property PopupMenu;
    property OnEnter;
    property OnExit;
  end;

function IsGridKind(const AKind: string): Boolean;
function GridVariantFromName(const AName: string; ADefault: TaGridVariant = gvReadOnly): TaGridVariant;
function GridFromDef(D: TaControlDef; AOwner: TComponent): TaGrid;
procedure GridToDef(G: TaGrid; D: TaControlDef);
function GridToLfm(G: TaGrid): string;
function GridFromLfm(const ALfm: string; AOwner: TComponent): TaGrid;

implementation

uses
  StrUtils, LResources, ta_tokens;

function IsGridKind(const AKind: string): Boolean;
begin
  Result := SameText(AKind, 'Grid') or SameText(AKind, 'Subform');
end;

function GridVariantFromName(const AName: string; ADefault: TaGridVariant): TaGridVariant;
var
  V: TaGridVariant;
begin
  for V := Low(TaGridVariant) to High(TaGridVariant) do
    if SameText(GridVariantNames[V], AName) then Exit(V);
  Result := ADefault;
end;

procedure TaGridOptions.Assign(ASource: TPersistent);
begin
  if ASource is TaGridOptions then
  begin
    FRowHeight := TaGridOptions(ASource).FRowHeight;
    FZebra := TaGridOptions(ASource).FZebra;
    FSumFields := TaGridOptions(ASource).FSumFields;
    FFrozen := TaGridOptions(ASource).FFrozen;
  end
  else inherited Assign(ASource);
end;

{ ---------------- pokretaci ---------------- }

procedure TaGridFooterLink.DataSetChanged;
begin
  inherited DataSetChanged;
  if Assigned(FOnRefresh) then FOnRefresh(Self);
end;

procedure TaGridFooterLink.ActiveChanged;
begin
  inherited ActiveChanged;
  if Assigned(FOnRefresh) then FOnRefresh(Self);
end;

constructor TaGridEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FRoot := TPanel.Create(nil);
  FRoot.BevelOuter := bvNone;
  FRoot.Caption := '';
  FFooter := TPanel.Create(FRoot);
  FFooter.Parent := FRoot;
  FFooter.Align := alBottom;
  FFooter.Height := 0;
  FFooter.BevelOuter := bvNone;
  FFooter.Caption := '';
  FFooter.Visible := False;
  FFooterLabel := TLabel.Create(FFooter);
  FFooterLabel.Parent := FFooter;
  FFooterLabel.SetBounds(6, 4, 600, 18);
  FFooterLabel.Font.Style := [fsBold];
  FGrid := TDBGrid.Create(FRoot);
  FGrid.Parent := FRoot;
  FGrid.Align := alClient;
  FGrid.OnPrepareCanvas := @GridPrepare;
  FGrid.OnKeyDown := @GridKeyDown;
  FLink := TaGridFooterLink.Create;
  FLink.OnRefresh := @RefreshFooter;
  case Variant of
    gvReadOnly:
      begin
        FGrid.ReadOnly := True;
        FGrid.Options := FGrid.Options - [dgEditing] + [dgRowSelect];
      end;
    gvEditable:
      begin
        FGrid.ReadOnly := False;
        FGrid.Options := FGrid.Options + [dgEditing, dgTabs, dgCancelOnExit];
      end;
    gvDatasheet:
      begin
        FGrid.ReadOnly := False;
        FGrid.Options := FGrid.Options + [dgEditing, dgTabs] - [dgIndicator];
        FGrid.DefaultRowHeight := 22;
      end;
    gvEntry:
      begin
        { unos: Tab ili Enter iz zadnje celije zadnjeg retka otvara novi prazan red }
        FGrid.ReadOnly := False;
        FGrid.Options := FGrid.Options + [dgEditing, dgTabs, dgCancelOnExit, dgAlwaysShowEditor];
      end;
  end;
  AttachInner(FRoot);
end;

destructor TaGridEngine.Destroy;
begin
  if FLink <> nil then
  begin
    FLink.OnRefresh := nil;
    FLink.DataSource := nil;
    FLink.Free;
  end;
  inherited Destroy;
end;

procedure TaGridEngine.GridKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  Ds: TDataSet;
  Last: Integer;
begin
  if Variant <> gvEntry then Exit;
  if (Key <> VK_TAB) and (Key <> VK_RETURN) then Exit;
  if (ssShift in Shift) or FGrid.ReadOnly then Exit;
  Ds := nil;
  if FGrid.DataSource <> nil then Ds := FGrid.DataSource.DataSet;
  if (Ds = nil) or not Ds.Active then Exit;
  if FGrid.SelectedIndex < FGrid.Columns.Count - 1 then Exit;
  { zadnji stupac zadnjeg retka }
  if Ds.State = dsInsert then Exit;
  if Ds.State = dsEdit then Ds.Post;
  Ds.DisableControls;
  try
    Last := Ds.RecNo;
    Ds.Next;
    if Ds.RecNo = Last then
    begin
      { nije se pomaknuo: zadnji je redak }
      Ds.Append;
      Key := 0;
    end
    else Ds.Prior;
  finally
    Ds.EnableControls;
  end;
end;

function GridFooterSums(ADs: TDataSet; const ASumFields: string): string;
var
  Names: TStringList;
  Sums: array of Double;
  I: Integer;
  F: TField;
  Bm: TBookmark;
  S: string;
begin
  Result := '';
  if (Trim(ASumFields) = '') or (ADs = nil) or not ADs.Active then Exit;
  Names := TStringList.Create;
  try
    Names.CommaText := StringReplace(ASumFields, ' ', '', [rfReplaceAll]);
    SetLength(Sums, Names.Count);
    for I := 0 to High(Sums) do Sums[I] := 0;
    Bm := ADs.GetBookmark;
    ADs.DisableControls;
    try
      ADs.First;
      while not ADs.EOF do
      begin
        for I := 0 to Names.Count - 1 do
        begin
          F := ADs.FindField(Names[I]);
          if (F <> nil) and not F.IsNull then Sums[I] := Sums[I] + F.AsFloat;
        end;
        ADs.Next;
      end;
      try ADs.GotoBookmark(Bm); except end;
    finally
      ADs.FreeBookmark(Bm);
      ADs.EnableControls;
    end;
    S := '';
    for I := 0 to Names.Count - 1 do
    begin
      if S <> '' then S := S + '   |   ';
      S := S + Names[I] + ': ' + FormatFloat('#,##0.00', Sums[I]);
    end;
    Result := S;
  finally
    Names.Free;
  end;
end;

function TaGridEngine.FooterText: string;
begin
  Result := '';
  if FLink.Active then Result := GridFooterSums(FLink.DataSet, FSumFields);
end;

procedure TaGridEngine.RefreshFooter(Sender: TObject);
var
  S: string;
begin
  if FRefreshing then Exit;
  FRefreshing := True;
  try
    S := FooterText;
    FFooterLabel.Caption := S;
    FFooter.Visible := Trim(FSumFields) <> '';
    if FFooter.Visible then FFooter.Height := 26 else FFooter.Height := 0;
  finally
    FRefreshing := False;
  end;
end;

function TaGridEngine.Variant: TaGridVariant;
begin
  Result := gvReadOnly;
end;

function TaGridEditableEngine.Variant: TaGridVariant;
begin
  Result := gvEditable;
end;

function TaGridDatasheetEngine.Variant: TaGridVariant;
begin
  Result := gvDatasheet;
end;

function TaGridEntryEngine.Variant: TaGridVariant;
begin
  Result := gvEntry;
end;

procedure TaGridEngine.GridPrepare(Sender: TObject; DataCol: Integer; Column: TColumn; AState: TGridDrawState);
var
  T: TaThemeTokens;
begin
  if not FZebra then Exit;
  if gdSelected in AState then Exit;
  if (FGrid.DataSource <> nil) and (FGrid.DataSource.DataSet <> nil) and Odd(FGrid.DataSource.DataSet.RecNo) then
  begin
    T := ActiveTokens;
    FGrid.Canvas.Brush.Color := TokenColor(T.Soft);
  end;
end;

function TaGridEngine.GetText: string;
begin
  Result := '';
end;

procedure TaGridEngine.SetText(const AValue: string);
begin
end;

procedure TaGridEngine.SetReadOnly(AValue: Boolean);
begin
  if AValue then FGrid.ReadOnly := True
  else FGrid.ReadOnly := Variant = gvReadOnly;
end;

procedure TaGridEngine.ApplyOptions(AOptions: TPersistent);
begin
  if AOptions is TaGridOptions then
  begin
    if TaGridOptions(AOptions).RowHeight > 0 then FGrid.DefaultRowHeight := TaGridOptions(AOptions).RowHeight;
    FZebra := TaGridOptions(AOptions).Zebra;
    FSumFields := TaGridOptions(AOptions).SumFields;
    RefreshFooter(nil);
    FGrid.Invalidate;
  end;
end;

function TaGridDataEngine.FooterText: string;
begin
  Result := '';
end;

function TaGridEngine.InnerDBGrid: TDBGrid;
begin
  Result := FGrid;
end;

procedure TaGridEngine.SetSource(ASource: TDataSource);
begin
  FGrid.DataSource := ASource;
  FLink.DataSource := ASource;
  RefreshFooter(nil);
end;

{ ---------------- TaGrid ---------------- }

constructor TaGrid.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FOptions := TaGridOptions.Create;
  FVariant := gvReadOnly;
  Width := 320;
  Height := 160;
  ReplaceEngine;
  PushToEngine;
end;

destructor TaGrid.Destroy;
begin
  if Engine <> nil then TaGridDataEngine(Engine).SetSource(nil);
  FOptions.Free;
  inherited Destroy;
end;

function TaGrid.CreateEngine: TaEngine;
var
  C: TaEngineClass;
begin
  C := FindEngine(GridFamily, GridVariantNames[FVariant]);
  if C = nil then C := FindEngine(GridFamily, 'readonly');
  Result := C.Create(Self);
end;

function TaGrid.VariantName: string;
begin
  Result := GridVariantNames[FVariant];
end;

function TaGrid.FooterText: string;
begin
  if Engine is TaGridDataEngine then Result := TaGridDataEngine(Engine).FooterText else Result := '';
end;

function TaGrid.InnerGrid: TDBGrid;
begin
  if Engine is TaGridDataEngine then Result := TaGridDataEngine(Engine).InnerDBGrid else Result := nil;
end;

function TaGrid.GetVariant: TaGridVariant;
begin
  Result := FVariant;
end;

procedure TaGrid.SetVariant(AValue: TaGridVariant);
begin
  if AValue = FVariant then Exit;
  if Engine <> nil then TaGridDataEngine(Engine).SetSource(nil);
  FVariant := AValue;
  ReplaceEngine;
  PushToEngine;
end;

function TaGrid.GetOptions: TaGridOptions;
begin
  Result := FOptions;
end;

procedure TaGrid.SetOptions(AValue: TaGridOptions);
begin
  FOptions.Assign(AValue);
  if Engine <> nil then Engine.ApplyOptions(FOptions);
end;

procedure TaGrid.PushToEngine;
begin
  if Engine = nil then Exit;
  Engine.ApplyOptions(FOptions);
  Engine.SetReadOnly(FReadOnly);
  TaGridDataEngine(Engine).SetSource(FDataSource);
end;

procedure TaGrid.SetReadOnly(AValue: Boolean);
begin
  if FReadOnly = AValue then Exit;
  FReadOnly := AValue;
  if Engine <> nil then Engine.SetReadOnly(AValue);
end;

procedure TaGrid.SetDataSource(AValue: TDataSource);
begin
  FDataSource := AValue;
  if AValue <> nil then AValue.FreeNotification(Self);
  if Engine <> nil then TaGridDataEngine(Engine).SetSource(AValue);
end;

function TaGrid.RealGetText: TCaption;
begin
  Result := '';
end;

procedure TaGrid.RealSetText(const AValue: TCaption);
begin
end;

procedure TaGrid.Notification(AComponent: TComponent; AOperation: TOperation);
begin
  inherited Notification(AComponent, AOperation);
  if (AOperation = opRemove) and (AComponent = FDataSource) then
  begin
    FDataSource := nil;
    if Engine <> nil then TaGridDataEngine(Engine).SetSource(nil);
  end;
end;

procedure TaGrid.Loaded;
begin
  inherited Loaded;
  PushToEngine;
end;

{ ---------------- definicija kontrole <-> komponenta ---------------- }

const
  OwnKeys = ',variant,locked,visibleIf,enabledIf,condFormat,rowHeight,zebra,sumFields,';

function ExtraWithout(const AExtra: string): string;
var
  L: TStringList;
  I: Integer;
  K: string;
begin
  L := TStringList.Create;
  try
    L.Text := AExtra;
    for I := L.Count - 1 downto 0 do
    begin
      K := L.Names[I];
      if (K <> '') and (Pos(',' + K + ',', OwnKeys) > 0) then L.Delete(I);
    end;
    Result := Trim(L.Text);
  finally
    L.Free;
  end;
end;

function GridFromDef(D: TaControlDef; AOwner: TComponent): TaGrid;
begin
  Result := TaGrid.Create(AOwner);
  try
    Result.Name := D.Name;
    Result.SetBounds(D.Left, D.Top, D.Width, D.Height);
    Result.Variant := GridVariantFromName(D.GetX('variant'), gvReadOnly);
    Result.ReadOnly := D.GetX('locked') = '1';
    Result.VisibleIf := D.GetX('visibleIf');
    Result.EnabledIf := D.GetX('enabledIf');
    Result.CondFormat := D.GetX('condFormat');
    Result.Options.RowHeight := StrToIntDef(D.GetX('rowHeight'), 0);
    Result.Options.Zebra := D.GetX('zebra') = '1';
    Result.Options.SumFields := D.GetX('sumFields');
    Result.Options := Result.Options;
    Result.Extra := ExtraWithout(D.Extra);
  except
    Result.Free;
    raise;
  end;
end;

procedure GridToDef(G: TaGrid; D: TaControlDef);
begin
  D.Kind := 'Grid';
  D.Name := G.Name;
  D.Left := G.Left; D.Top := G.Top; D.Width := G.Width; D.Height := G.Height;
  D.Extra := G.Extra;
  D.SetX('variant', IfThen(G.Variant = gvReadOnly, '', G.VariantName));
  D.SetX('locked', IfThen(G.ReadOnly, '1', ''));
  D.SetX('visibleIf', G.VisibleIf);
  D.SetX('enabledIf', G.EnabledIf);
  D.SetX('condFormat', G.CondFormat);
  D.SetX('rowHeight', IfThen(G.Options.RowHeight > 0, IntToStr(G.Options.RowHeight), ''));
  D.SetX('zebra', IfThen(G.Options.Zebra, '1', ''));
  D.SetX('sumFields', G.Options.SumFields);
end;

function GridToLfm(G: TaGrid): string;
var
  M: TMemoryStream;
  L: TStringList;
begin
  M := TMemoryStream.Create;
  L := TStringList.Create;
  try
    WriteComponentAsTextToStream(M, G);
    M.Position := 0;
    L.LoadFromStream(M);
    Result := L.Text;
  finally
    L.Free;
    M.Free;
  end;
end;

type
  TGridLfmFinder = class
    procedure Find(Reader: TReader; const AClassName: string; var AClass: TComponentClass);
  end;

procedure TGridLfmFinder.Find(Reader: TReader; const AClassName: string; var AClass: TComponentClass);
begin
  if SameText(AClassName, 'TaGrid') then AClass := TaGrid;
end;

function GridFromLfm(const ALfm: string; AOwner: TComponent): TaGrid;
var
  M: TMemoryStream;
  C: TComponent;
  F: TGridLfmFinder;
begin
  M := TMemoryStream.Create;
  try
    if ALfm <> '' then M.WriteBuffer(ALfm[1], Length(ALfm));
    M.Position := 0;
    C := nil;
    F := TGridLfmFinder.Create;
    try
      ReadComponentFromTextStream(M, C, @F.Find, AOwner);
    finally
      F.Free;
    end;
    Result := C as TaGrid;
  finally
    M.Free;
  end;
end;

initialization
  RegisterClass(TaGrid);
  RegisterEngine(GridFamily, 'readonly', TaGridEngine);
  RegisterEngine(GridFamily, 'editable', TaGridEditableEngine);
  RegisterEngine(GridFamily, 'datasheet', TaGridDatasheetEngine);
  RegisterEngine(GridFamily, 'entry', TaGridEntryEngine);

end.
