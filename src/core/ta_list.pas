unit ta_list;
{ Obitelj List: popis stavki. Varijante: list (TListBox), checklist (TCheckListBox: vise oznacenih, kljucevi odvojeni
  zarezom), iconlist (TListView, ikone) i tree (TTreeView: razina stavke je uvlaka od po dva razmaka).
  Stavke su retci "kljuc=natpis" ili samo "natpis". Vrijednost je kljuc oznacene stavke. Isti nacin kao Edit/Choice. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, StdCtrls, CheckLst, ComCtrls, Graphics, Variants, DB, DBCtrls, ta_family, ta_formdef;

type
  TaListVariant = (lsList, lsChecklist, lsIconlist, lsTree);

const
  ListVariantNames: array[TaListVariant] of string = ('list', 'checklist', 'iconlist', 'tree');
  ListFamily = 'List';

type
  TaListOptions = class(TPersistent)
  private
    FSorted, FMultiSelect: Boolean;
  public
    procedure Assign(ASource: TPersistent); override;
  published
    property Sorted: Boolean read FSorted write FSorted default False;
    { list i iconlist: vise oznacenih stavki, vrijednost su kljucevi odvojeni zarezom }
    property MultiSelect: Boolean read FMultiSelect write FMultiSelect default False;
  end;

  TaListEngine = class(TaEngine)
  private
    FKeys: TStringList;
    FSetting, FReadOnly: Boolean;
  protected
    function KeyAt(AIndex: Integer): string;
    function IndexOfKey(const AKey: string): Integer;
    procedure ParseItems(AItems: TStrings; ALabels: TStrings; ALevels: TList);
  public
    constructor Create(AHost: TaFamilyHost); override;
    destructor Destroy; override;
    procedure SetReadOnly(AValue: Boolean); override;
  end;

  TaListBoxEngine = class(TaListEngine)
  private
    FBox: TListBox;
    FPrev: Integer;
    FPrevMulti: string;
    procedure BoxSelect(Sender: TObject; User: Boolean);
    function Joined: string;
  public
    constructor Create(AHost: TaFamilyHost); override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
    procedure SetItems(AItems: TStrings); override;
    procedure ApplyOptions(AOptions: TPersistent); override;
  end;

  TaCheckListEngine = class(TaListEngine)
  private
    FBox: TCheckListBox;
    FPrev: string;
    procedure ItemClick(Sender: TObject; Index: Integer);
    function Joined: string;
  public
    constructor Create(AHost: TaFamilyHost); override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
    procedure SetItems(AItems: TStrings); override;
  end;

  TaIconListEngine = class(TaListEngine)
  private
    FView: TListView;
    FPrev: Integer;
    FPrevMulti: string;
    procedure ViewSelect(Sender: TObject; Item: TListItem; Selected: Boolean);
    function Joined: string;
  public
    constructor Create(AHost: TaFamilyHost); override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
    procedure SetItems(AItems: TStrings); override;
    procedure ApplyOptions(AOptions: TPersistent); override;
  end;

  TaTreeEngine = class(TaListEngine)
  private
    FTree: TTreeView;
    FPrev: Integer;
    procedure TreeChange(Sender: TObject; Node: TTreeNode);
  public
    constructor Create(AHost: TaFamilyHost); override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
    procedure SetItems(AItems: TStrings); override;
  end;

  TaList = class(TaFamilyHost)
  private
    FVariant: TaListVariant;
    FOptions: TaListOptions;
    FItems: TStringList;
    FText: string;
    FReadOnly: Boolean;
    FControlSource, FVisibleIf, FEnabledIf, FCondFormat, FExtra: string;
    FDataLink: TFieldDataLink;
    FUpdating, FSelfEdit: Boolean;
    function GetVariant: TaListVariant;
    procedure SetVariant(AValue: TaListVariant);
    function GetOptions: TaListOptions;
    procedure SetOptions(AValue: TaListOptions);
    procedure SetItemsList(AValue: TStrings);
    function GetItemsList: TStrings;
    procedure ItemsChanged(Sender: TObject);
    procedure SetReadOnly(AValue: Boolean);
    function GetDataSource: TDataSource;
    procedure SetDataSource(AValue: TDataSource);
    function GetDataField: string;
    procedure SetDataField(const AValue: string);
    procedure DataChange(Sender: TObject);
    procedure UpdateData(Sender: TObject);
    procedure PushToEngine;
  protected
    function CreateEngine: TaEngine; override;
    procedure EngineChanged; override;
    function RealGetText: TCaption; override;
    procedure RealSetText(const AValue: TCaption); override;
    procedure Notification(AComponent: TComponent; AOperation: TOperation); override;
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function VariantName: string;
    { oznaceni kljuc (kod checklist: kljucevi odvojeni zarezom) }
    function Selected: string;
    procedure Select(const AKeys: string);
  published
    property Variant: TaListVariant read GetVariant write SetVariant default lsList;
    property Items: TStrings read GetItemsList write SetItemsList;
    property Options: TaListOptions read GetOptions write SetOptions;
    property ReadOnly: Boolean read FReadOnly write SetReadOnly default False;
    property ControlSource: string read FControlSource write FControlSource;
    property VisibleIf: string read FVisibleIf write FVisibleIf;
    property EnabledIf: string read FEnabledIf write FEnabledIf;
    property CondFormat: string read FCondFormat write FCondFormat;
    property Extra: string read FExtra write FExtra;
    property DataSource: TDataSource read GetDataSource write SetDataSource;
    property DataField: string read GetDataField write SetDataField;
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

function IsListKind(const AKind: string): Boolean;
function ListVariantFromName(const AName: string; ADefault: TaListVariant = lsList): TaListVariant;
function ListFromDef(D: TaControlDef; AOwner: TComponent): TaList;
procedure ListToDef(L: TaList; D: TaControlDef);
function ListToLfm(L: TaList): string;
function ListFromLfm(const ALfm: string; AOwner: TComponent): TaList;

implementation

uses
  StrUtils, LResources;

function IsListKind(const AKind: string): Boolean;
begin
  Result := SameText(AKind, 'List') or SameText(AKind, 'ListBox');
end;

function ListVariantFromName(const AName: string; ADefault: TaListVariant): TaListVariant;
var
  V: TaListVariant;
begin
  for V := Low(TaListVariant) to High(TaListVariant) do
    if SameText(ListVariantNames[V], AName) then Exit(V);
  Result := ADefault;
end;

function KeyOf(const AItem: string): string;
var
  P: Integer;
begin
  P := Pos('=', AItem);
  if P > 0 then Result := Trim(Copy(AItem, 1, P - 1)) else Result := Trim(AItem);
end;

function LabelOf(const AItem: string): string;
var
  P: Integer;
begin
  P := Pos('=', AItem);
  if P > 0 then Result := Trim(Copy(AItem, P + 1, MaxInt)) else Result := Trim(AItem);
end;

procedure TaListOptions.Assign(ASource: TPersistent);
begin
  if ASource is TaListOptions then
  begin
    FSorted := TaListOptions(ASource).FSorted;
    FMultiSelect := TaListOptions(ASource).FMultiSelect;
  end
  else inherited Assign(ASource);
end;

{ ---------------- pokretaci ---------------- }

constructor TaListEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FKeys := TStringList.Create;
end;

destructor TaListEngine.Destroy;
begin
  FKeys.Free;
  inherited Destroy;
end;

function TaListEngine.KeyAt(AIndex: Integer): string;
begin
  if (AIndex >= 0) and (AIndex < FKeys.Count) then Result := FKeys[AIndex] else Result := '';
end;

function TaListEngine.IndexOfKey(const AKey: string): Integer;
var
  I: Integer;
begin
  for I := 0 to FKeys.Count - 1 do
    if SameText(FKeys[I], AKey) then Exit(I);
  Result := -1;
end;

{ razina = broj uvlaka od po dva razmaka; kljuc i natpis iz "kljuc=natpis" }
procedure TaListEngine.ParseItems(AItems: TStrings; ALabels: TStrings; ALevels: TList);
var
  I, Lv, N: Integer;
  S: string;
begin
  FKeys.Clear;
  ALabels.Clear;
  if ALevels <> nil then ALevels.Clear;
  for I := 0 to AItems.Count - 1 do
  begin
    S := AItems[I];
    N := 0;
    while (N < Length(S)) and (S[N + 1] = ' ') do Inc(N);
    Lv := N div 2;
    FKeys.Add(KeyOf(S));
    ALabels.Add(LabelOf(S));
    if ALevels <> nil then ALevels.Add(Pointer(PtrInt(Lv)));
  end;
end;

procedure TaListEngine.SetReadOnly(AValue: Boolean);
begin
  FReadOnly := AValue;
end;

constructor TaListBoxEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FBox := TListBox.Create(nil);
  FBox.OnSelectionChange := @BoxSelect;
  FPrev := -1;
  AttachInner(FBox);
end;

function TaListBoxEngine.Joined: string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to FBox.Items.Count - 1 do
    if FBox.Selected[I] then
    begin
      if Result <> '' then Result := Result + ',';
      Result := Result + KeyAt(I);
    end;
end;

procedure TaListBoxEngine.BoxSelect(Sender: TObject; User: Boolean);
var
  L: TStringList;
  I: Integer;
begin
  if FSetting then Exit;
  if FReadOnly then
  begin
    FSetting := True;
    try
      if FBox.MultiSelect then
      begin
        L := TStringList.Create;
        try
          L.CommaText := FPrevMulti;
          for I := 0 to FBox.Items.Count - 1 do FBox.Selected[I] := L.IndexOf(KeyAt(I)) >= 0;
        finally
          L.Free;
        end;
      end
      else FBox.ItemIndex := FPrev;
    finally
      FSetting := False;
    end;
    Exit;
  end;
  FPrev := FBox.ItemIndex;
  FPrevMulti := Joined;
  InnerChanged(Sender);
end;

function TaListBoxEngine.GetText: string;
begin
  if FBox.MultiSelect then Result := Joined else Result := KeyAt(FBox.ItemIndex);
end;

procedure TaListBoxEngine.SetText(const AValue: string);
var
  L: TStringList;
  I: Integer;
begin
  FSetting := True;
  try
    if FBox.MultiSelect then
    begin
      L := TStringList.Create;
      try
        L.CommaText := AValue;
        for I := 0 to FBox.Items.Count - 1 do FBox.Selected[I] := L.IndexOf(KeyAt(I)) >= 0;
      finally
        L.Free;
      end;
      FPrevMulti := Joined;
    end
    else
    begin
      FBox.ItemIndex := IndexOfKey(AValue);
      FPrev := FBox.ItemIndex;
    end;
  finally
    FSetting := False;
  end;
end;

procedure TaListBoxEngine.SetItems(AItems: TStrings);
var
  Lb: TStringList;
  Keep: string;
begin
  Keep := GetText;
  Lb := TStringList.Create;
  try
    ParseItems(AItems, Lb, nil);
    FSetting := True;
    try
      FBox.Items.Assign(Lb);
    finally
      FSetting := False;
    end;
  finally
    Lb.Free;
  end;
  SetText(Keep);
end;

procedure TaListBoxEngine.ApplyOptions(AOptions: TPersistent);
var
  Keep: string;
begin
  if AOptions is TaListOptions then
  begin
    FBox.Sorted := False;   { poredak stavki je poredak kljuceva }
    if FBox.MultiSelect <> TaListOptions(AOptions).MultiSelect then
    begin
      Keep := GetText;
      FSetting := True;
      try
        FBox.MultiSelect := TaListOptions(AOptions).MultiSelect;
      finally
        FSetting := False;
      end;
      SetText(Keep);
    end;
  end;
end;

constructor TaCheckListEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FBox := TCheckListBox.Create(nil);
  FBox.OnItemClick := @ItemClick;
  AttachInner(FBox);
end;

function TaCheckListEngine.Joined: string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to FBox.Items.Count - 1 do
    if FBox.Checked[I] then
    begin
      if Result <> '' then Result := Result + ',';
      Result := Result + KeyAt(I);
    end;
end;

procedure TaCheckListEngine.ItemClick(Sender: TObject; Index: Integer);
var
  Back: TStringList;
  I: Integer;
begin
  if FSetting then Exit;
  if FReadOnly then
  begin
    FSetting := True;
    Back := TStringList.Create;
    try
      Back.CommaText := FPrev;
      for I := 0 to FBox.Items.Count - 1 do FBox.Checked[I] := Back.IndexOf(KeyAt(I)) >= 0;
    finally
      Back.Free;
      FSetting := False;
    end;
    Exit;
  end;
  FPrev := Joined;
  InnerChanged(Sender);
end;

function TaCheckListEngine.GetText: string;
begin
  Result := Joined;
end;

procedure TaCheckListEngine.SetText(const AValue: string);
var
  L: TStringList;
  I: Integer;
begin
  L := TStringList.Create;
  try
    L.CommaText := AValue;
    FSetting := True;
    try
      for I := 0 to FBox.Items.Count - 1 do FBox.Checked[I] := L.IndexOf(KeyAt(I)) >= 0;
    finally
      FSetting := False;
    end;
    FPrev := Joined;
  finally
    L.Free;
  end;
end;

procedure TaCheckListEngine.SetItems(AItems: TStrings);
var
  Lb: TStringList;
  Keep: string;
begin
  Keep := Joined;
  Lb := TStringList.Create;
  try
    ParseItems(AItems, Lb, nil);
    FSetting := True;
    try
      FBox.Items.Assign(Lb);
    finally
      FSetting := False;
    end;
  finally
    Lb.Free;
  end;
  SetText(Keep);
end;

constructor TaIconListEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FView := TListView.Create(nil);
  FView.ViewStyle := vsIcon;
  FView.ReadOnly := True;
  FView.OnSelectItem := @ViewSelect;
  FPrev := -1;
  AttachInner(FView);
end;

function TaIconListEngine.Joined: string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to FView.Items.Count - 1 do
    if FView.Items[I].Selected then
    begin
      if Result <> '' then Result := Result + ',';
      Result := Result + KeyAt(I);
    end;
end;

procedure TaIconListEngine.ViewSelect(Sender: TObject; Item: TListItem; Selected: Boolean);
var
  L: TStringList;
  I: Integer;
begin
  if FSetting then Exit;
  if FReadOnly then
  begin
    FSetting := True;
    try
      if FView.MultiSelect then
      begin
        L := TStringList.Create;
        try
          L.CommaText := FPrevMulti;
          for I := 0 to FView.Items.Count - 1 do FView.Items[I].Selected := L.IndexOf(KeyAt(I)) >= 0;
        finally
          L.Free;
        end;
      end
      else if (FPrev >= 0) and (FPrev < FView.Items.Count) then FView.Selected := FView.Items[FPrev] else FView.Selected := nil;
    finally
      FSetting := False;
    end;
    Exit;
  end;
  if (not FView.MultiSelect) and not Selected then Exit;
  FPrev := Item.Index;
  FPrevMulti := Joined;
  InnerChanged(Sender);
end;

function TaIconListEngine.GetText: string;
begin
  if FView.MultiSelect then Result := Joined
  else if FView.Selected <> nil then Result := KeyAt(FView.Selected.Index)
  else Result := '';
end;

procedure TaIconListEngine.SetText(const AValue: string);
var
  I: Integer;
  L: TStringList;
begin
  FSetting := True;
  try
    if FView.MultiSelect then
    begin
      L := TStringList.Create;
      try
        L.CommaText := AValue;
        for I := 0 to FView.Items.Count - 1 do FView.Items[I].Selected := L.IndexOf(KeyAt(I)) >= 0;
      finally
        L.Free;
      end;
      FPrevMulti := Joined;
    end
    else
    begin
      I := IndexOfKey(AValue);
      if (I >= 0) and (I < FView.Items.Count) then FView.Selected := FView.Items[I] else FView.Selected := nil;
      FPrev := I;
    end;
  finally
    FSetting := False;
  end;
end;

procedure TaIconListEngine.ApplyOptions(AOptions: TPersistent);
var
  Keep: string;
begin
  if (AOptions is TaListOptions) and (FView.MultiSelect <> TaListOptions(AOptions).MultiSelect) then
  begin
    Keep := GetText;
    FView.MultiSelect := TaListOptions(AOptions).MultiSelect;
    SetText(Keep);
  end;
end;

procedure TaIconListEngine.SetItems(AItems: TStrings);
var
  Lb: TStringList;
  Keep: string;
  I: Integer;
begin
  Keep := GetText;
  Lb := TStringList.Create;
  try
    ParseItems(AItems, Lb, nil);
    FSetting := True;
    try
      FView.Items.Clear;
      for I := 0 to Lb.Count - 1 do FView.Items.Add.Caption := Lb[I];
    finally
      FSetting := False;
    end;
  finally
    Lb.Free;
  end;
  SetText(Keep);
end;

constructor TaTreeEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FTree := TTreeView.Create(nil);
  FTree.ReadOnly := True;
  FTree.OnChange := @TreeChange;
  FPrev := -1;
  AttachInner(FTree);
end;

procedure TaTreeEngine.TreeChange(Sender: TObject; Node: TTreeNode);
begin
  if FSetting or (Node = nil) then Exit;
  if FReadOnly then
  begin
    FSetting := True;
    try
      if (FPrev >= 0) and (FPrev < FTree.Items.Count) then FTree.Selected := FTree.Items[FPrev] else FTree.Selected := nil;
    finally
      FSetting := False;
    end;
    Exit;
  end;
  FPrev := Node.AbsoluteIndex;
  InnerChanged(Sender);
end;

function TaTreeEngine.GetText: string;
begin
  if FTree.Selected <> nil then Result := KeyAt(FTree.Selected.AbsoluteIndex) else Result := '';
end;

procedure TaTreeEngine.SetText(const AValue: string);
var
  I: Integer;
begin
  I := IndexOfKey(AValue);
  FSetting := True;
  try
    if (I >= 0) and (I < FTree.Items.Count) then FTree.Selected := FTree.Items[I] else FTree.Selected := nil;
    FPrev := I;
  finally
    FSetting := False;
  end;
end;

procedure TaTreeEngine.SetItems(AItems: TStrings);
var
  Lb: TStringList;
  Lv: TList;
  Keep: string;
  I, Level: Integer;
  Last: array of TTreeNode;
  Parent: TTreeNode;
begin
  Keep := GetText;
  Lb := TStringList.Create;
  Lv := TList.Create;
  try
    ParseItems(AItems, Lb, Lv);
    FSetting := True;
    try
      FTree.Items.Clear;
      SetLength(Last, Lb.Count + 1);
      for I := 0 to Lb.Count - 1 do
      begin
        Level := PtrInt(Lv[I]);
        if Level > I then Level := I;
        if Level > 0 then Parent := Last[Level - 1] else Parent := nil;
        if (Level > 0) and (Parent = nil) then Level := 0;
        Last[Level] := FTree.Items.AddChild(Parent, Lb[I]);
      end;
      FTree.FullExpand;
    finally
      FSetting := False;
    end;
  finally
    Lv.Free;
    Lb.Free;
  end;
  SetText(Keep);
end;

{ ---------------- TaList ---------------- }

constructor TaList.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FItems := TStringList.Create;
  FItems.OnChange := @ItemsChanged;
  FDataLink := TFieldDataLink.Create;
  FDataLink.Control := Self;
  FDataLink.OnDataChange := @DataChange;
  FDataLink.OnUpdateData := @UpdateData;
  FOptions := TaListOptions.Create;
  FVariant := lsList;
  Width := 180;
  Height := 120;
  ReplaceEngine;
  PushToEngine;
end;

destructor TaList.Destroy;
begin
  FDataLink.OnDataChange := nil;
  FDataLink.OnUpdateData := nil;
  FDataLink.Free;
  FOptions.Free;
  FItems.Free;
  inherited Destroy;
end;

function TaList.CreateEngine: TaEngine;
var
  C: TaEngineClass;
begin
  C := FindEngine(ListFamily, ListVariantNames[FVariant]);
  if C = nil then C := FindEngine(ListFamily, 'list');
  Result := C.Create(Self);
end;

function TaList.VariantName: string;
begin
  Result := ListVariantNames[FVariant];
end;

function TaList.GetVariant: TaListVariant;
begin
  Result := FVariant;
end;

procedure TaList.SetVariant(AValue: TaListVariant);
begin
  if AValue = FVariant then Exit;
  FText := RealGetText;
  FVariant := AValue;
  ReplaceEngine;
  PushToEngine;
end;

function TaList.GetOptions: TaListOptions;
begin
  Result := FOptions;
end;

procedure TaList.SetOptions(AValue: TaListOptions);
begin
  FOptions.Assign(AValue);
  if Engine <> nil then Engine.ApplyOptions(FOptions);
end;

procedure TaList.SetItemsList(AValue: TStrings);
begin
  FItems.Assign(AValue);
end;

function TaList.GetItemsList: TStrings;
begin
  Result := FItems;
end;

procedure TaList.ItemsChanged(Sender: TObject);
begin
  if (Engine <> nil) and not (csLoading in ComponentState) then
  begin
    FUpdating := True;
    try
      Engine.SetItems(FItems);
    finally
      FUpdating := False;
    end;
  end;
end;

procedure TaList.PushToEngine;
begin
  if Engine = nil then Exit;
  FUpdating := True;
  try
    Engine.ApplyOptions(FOptions);
    Engine.SetItems(FItems);
    Engine.SetText(FText);
    Engine.SetReadOnly(FReadOnly);
  finally
    FUpdating := False;
  end;
end;

procedure TaList.SetReadOnly(AValue: Boolean);
begin
  if FReadOnly = AValue then Exit;
  FReadOnly := AValue;
  if Engine <> nil then Engine.SetReadOnly(AValue);
end;

function TaList.RealGetText: TCaption;
begin
  if Engine <> nil then Result := Engine.GetText else Result := FText;
end;

procedure TaList.RealSetText(const AValue: TCaption);
begin
  FText := AValue;
  if Engine <> nil then
  begin
    FUpdating := True;
    try
      Engine.SetText(AValue);
    finally
      FUpdating := False;
    end;
  end;
end;

function TaList.Selected: string;
begin
  Result := RealGetText;
end;

procedure TaList.Select(const AKeys: string);
begin
  RealSetText(AKeys);
end;

procedure TaList.EngineChanged;
begin
  if FUpdating then Exit;
  if FDataLink.Active and not FReadOnly then
  begin
    FSelfEdit := True;
    try
      if FDataLink.Edit then FDataLink.Modified;
    finally
      FSelfEdit := False;
    end;
    try
      FDataLink.UpdateRecord;
    except
      FDataLink.Reset;
      raise;
    end;
  end;
  inherited EngineChanged;
end;

function TaList.GetDataSource: TDataSource;
begin
  Result := FDataLink.DataSource;
end;

procedure TaList.SetDataSource(AValue: TDataSource);
begin
  FDataLink.DataSource := AValue;
  if AValue <> nil then AValue.FreeNotification(Self);
end;

function TaList.GetDataField: string;
begin
  Result := FDataLink.FieldName;
end;

procedure TaList.SetDataField(const AValue: string);
begin
  FDataLink.FieldName := AValue;
end;

procedure TaList.Notification(AComponent: TComponent; AOperation: TOperation);
begin
  inherited Notification(AComponent, AOperation);
  if (AOperation = opRemove) and (FDataLink <> nil) and (AComponent = FDataLink.DataSource) then
    FDataLink.DataSource := nil;
end;

procedure TaList.Loaded;
begin
  inherited Loaded;
  PushToEngine;
end;

procedure TaList.DataChange(Sender: TObject);
var
  F: TField;
begin
  if FSelfEdit then Exit;
  F := FDataLink.Field;
  FUpdating := True;
  try
    if (F = nil) or F.IsNull then Engine.SetText('')
    else Engine.SetText(F.AsString);
  finally
    FUpdating := False;
  end;
end;

procedure TaList.UpdateData(Sender: TObject);
var
  F: TField;
  S: string;
begin
  F := FDataLink.Field;
  if F = nil then Exit;
  S := Engine.GetText;
  if S = '' then F.Clear
  else
    case F.DataType of
      ftSmallint, ftInteger, ftLargeint, ftWord, ftAutoInc: F.AsInteger := StrToIntDef(S, 0);
      ftFloat, ftCurrency, ftBCD, ftFMTBcd: F.AsFloat := StrToFloatDef(S, 0);
    else
      F.AsString := S;
    end;
end;

{ ---------------- definicija kontrole <-> komponenta ---------------- }

const
  OwnKeys = ',variant,tip,locked,visibleIf,enabledIf,condFormat,sorted,items,multiSelect,';

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

function ListFromDef(D: TaControlDef; AOwner: TComponent): TaList;
var
  L: TStringList;
  S: string;
begin
  Result := TaList.Create(AOwner);
  try
    Result.Name := D.Name;
    Result.SetBounds(D.Left, D.Top, D.Width, D.Height);
    Result.Variant := ListVariantFromName(D.GetX('variant'), lsList);
    Result.ControlSource := D.ControlSource;
    Result.ReadOnly := D.GetX('locked') = '1';
    Result.Hint := D.GetX('tip');
    Result.VisibleIf := D.GetX('visibleIf');
    Result.EnabledIf := D.GetX('enabledIf');
    Result.CondFormat := D.GetX('condFormat');
    Result.Options.MultiSelect := D.GetX('multiSelect') = '1';
    Result.Options := Result.Options;
    L := TStringList.Create;
    try
      S := D.GetX('items');
      if S = '' then
      begin
        S := Trim(D.RowSource);
        if LowerCase(Copy(S, 1, 5)) = 'list:' then S := Copy(S, 6, MaxInt) else S := '';
      end;
      if S <> '' then
      begin
        L.Delimiter := ';';
        L.StrictDelimiter := True;
        L.DelimitedText := S;
      end;
      Result.Items.Assign(L);
    finally
      L.Free;
    end;
    Result.Extra := ExtraWithout(D.Extra);
  except
    Result.Free;
    raise;
  end;
end;

procedure ListToDef(L: TaList; D: TaControlDef);
var
  I: Integer;
  S: string;
begin
  D.Kind := 'ListBox';
  D.Name := L.Name;
  D.Left := L.Left; D.Top := L.Top; D.Width := L.Width; D.Height := L.Height;
  D.ControlSource := L.ControlSource;
  D.Extra := L.Extra;
  D.SetX('variant', IfThen(L.Variant = lsList, '', L.VariantName));
  D.SetX('locked', IfThen(L.ReadOnly, '1', ''));
  D.SetX('tip', L.Hint);
  D.SetX('visibleIf', L.VisibleIf);
  D.SetX('enabledIf', L.EnabledIf);
  D.SetX('condFormat', L.CondFormat);
  D.SetX('multiSelect', IfThen(L.Options.MultiSelect, '1', ''));
  S := '';
  for I := 0 to L.Items.Count - 1 do
  begin
    if S <> '' then S := S + ';';
    S := S + L.Items[I];
  end;
  D.SetX('items', S);
end;

function ListToLfm(L: TaList): string;
var
  M: TMemoryStream;
  S: TStringList;
begin
  M := TMemoryStream.Create;
  S := TStringList.Create;
  try
    WriteComponentAsTextToStream(M, L);
    M.Position := 0;
    S.LoadFromStream(M);
    Result := S.Text;
  finally
    S.Free;
    M.Free;
  end;
end;

type
  TListLfmFinder = class
    procedure Find(Reader: TReader; const AClassName: string; var AClass: TComponentClass);
  end;

procedure TListLfmFinder.Find(Reader: TReader; const AClassName: string; var AClass: TComponentClass);
begin
  if SameText(AClassName, 'TaList') then AClass := TaList;
end;

function ListFromLfm(const ALfm: string; AOwner: TComponent): TaList;
var
  M: TMemoryStream;
  C: TComponent;
  F: TListLfmFinder;
begin
  M := TMemoryStream.Create;
  try
    if ALfm <> '' then M.WriteBuffer(ALfm[1], Length(ALfm));
    M.Position := 0;
    C := nil;
    F := TListLfmFinder.Create;
    try
      ReadComponentFromTextStream(M, C, @F.Find, AOwner);
    finally
      F.Free;
    end;
    Result := C as TaList;
  finally
    M.Free;
  end;
end;

initialization
  RegisterClass(TaList);
  RegisterEngine(ListFamily, 'list', TaListBoxEngine);
  RegisterEngine(ListFamily, 'checklist', TaCheckListEngine);
  RegisterEngine(ListFamily, 'iconlist', TaIconListEngine);
  RegisterEngine(ListFamily, 'tree', TaTreeEngine);

end.
