unit ta_reportdesign;
{ Report designer: seven stacked bands, items dragged and resized inside them,
  property editor, preview through the real engine. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, ExtCtrls, StdCtrls, Grids, ValEdit,
  Graphics, Math, LCLType, LCLIntf, Menus, contnrs, ZDataset, ta_layout, ta_meta, ta_formdef, ta_controls, ta_reportdef,
  ta_reportengine, ta_reportview, ta_expr, ta_exprbuilder, ta_propedit, ta_propdlgs, ta_editdlg, ta_pagesetup, ta_icons;

type

  { TaReportDesigner }

  TaReportDesigner = class(TForm)
  private
    FDb: TAppDb;
    FDef: TaReportDef;
    FScroll: TScrollBox;
    FStrips, FBands: array[0..6] of TPanel;
    FSelected: TControl;
    FSelBand: Integer;
    FMulti: TList;                 { dodatno odabrane stavke (Ctrl+klik) }
    FDragGroup: TList;             { ostale odabrane pri povlacenju }
    FGroupOrig: array of TPoint;
    FLayoutMenu: TPopupMenu;
    FUndo: TStringList;
    FDragUndoPushed: Boolean;
    FPalette: TListBox;
    FProps: TValueListEditor;
    FSource, FGroup: TComboBox;
    FTitle, FSort: TEdit;
    FDragging, FResizing, FLoadingProps: Boolean;
    FResizeMode: Integer;
    FResizeTimer: TTimer;          { prati pokazivac dok se vuce rub }
    FDragStart: TPoint;
    FOrig: TRect;
    FDragCtl: TControl;            { kontrola koju se hvata misem (ostale odabrane idu za njom) }
    FLasso, FLassoAdd: Boolean;    { povlacenje okvira za odabir }
    FLassoShape: TShape;
    FLassoTo: TPoint;
    FLassoUseTo: Boolean;
    FLassoPrev: TList;             { odabir prije okvira (uz Ctrl se zadrzava) }
    procedure BuildUi;
    procedure DragTo(Dx, Dy: Integer);
    procedure LassoTick;
    procedure LassoEnd;
    function ScreenRectOf(C: TControl): TRect;
    procedure PageSetupClick(Sender: TObject);
    procedure PaletteDraw(Control: TWinControl; Index: Integer; ARect: TRect; State: TOwnerDrawState);
    function BandWidth: Integer;
    procedure CopySelection(ATo: TList);
    procedure BuildBands;
    procedure Relayout;
    procedure BuildItems;
    function BandIndex(APanel: TObject): Integer;
    function PlaceItem(const AKind: string; ABand, X, Y: Integer): TControl;
    procedure HookControl(C: TControl);
    procedure Select(C: TControl);
    procedure SelectBand(ABand: Integer);
    procedure ShowProps;
    procedure StripClick(Sender: TObject);
    procedure BandMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure BandPaint(Sender: TObject);
    procedure CtlMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure CtlMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure CtlMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure PropValidate(Sender: TObject; ACol, ARow: Longint; const KeyName, KeyValue: string);
    procedure ResizeBy(Dw, Dh: Integer);
    procedure ResizeTo(Dx, Dy: Integer);
    procedure ResizeTick(Sender: TObject);
    procedure PropValidateEntry(Sender: TObject; aCol, aRow: Integer; const OldValue: string; var NewValue: string);
    procedure ApplyProp(const AKey, AValue: string);
    procedure ExprClick(Sender: TObject);
    procedure PropButton(Sender: TObject);
    procedure ConfigureFor;
    procedure ClearMulti;
    procedure ToggleMulti(C: TControl);
    function SelectionList: TList;
    procedure SelectAll;
    procedure DoLayout(AOp: TLayoutOp);
    procedure ZOrder(AToFront: Boolean);
    procedure LayoutMenuClick(Sender: TObject);
    procedure LayoutButtonClick(Sender: TObject);
    procedure PushUndo;
    procedure DoUndo;
    procedure UndoClick(Sender: TObject);
    procedure ClearItems;
    procedure Nudge(Dx, Dy: Integer);
    procedure DeleteSelected;
    procedure ReportKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure SourceChange(Sender: TObject);
    procedure SortClick(Sender: TObject);
    function SourceFields(const ASource: string): TStringList;
    function Save: Boolean;
    procedure SaveClick(Sender: TObject);
    procedure DeleteClick(Sender: TObject);
    procedure AddFieldsClick(Sender: TObject);
    procedure PreviewClick(Sender: TObject);
    function Snap(V: Integer): Integer;
  public
    constructor CreateDesigner(AOwner: TComponent; ADb: TAppDb; ADef: TaReportDef);
    destructor Destroy; override;
    { za testove }
    function AddForTest(const AKind: string; ABand, X, Y: Integer): TControl;
    procedure ToggleMultiForTest(C: TControl);
    procedure LayoutForTest(AOp: TLayoutOp);
    procedure ZOrderForTest(AToFront: Boolean);
    procedure DeleteForTest;
    procedure UndoForTest;
    procedure NudgeForTest(Dx, Dy: Integer);
    procedure TypeInGridForTest(const AKey, AValue: string);
    function EdgeDragForTest(X, Y, Dx, Dy: Integer): Boolean;
    { povlacenje okvira za odabir izmedu dvije tocke u ekranskim koordinatama }
    procedure LassoForTest(const AFrom, ATo: TPoint; AAdd: Boolean);
    { povlacenje odabranih za Dx, Dy kao da se hvata kontrola C }
    procedure GroupDragForTest(C: TControl; Dx, Dy: Integer);
    function SelectedCountForTest: Integer;
    function ReportDef: TaReportDef;
    function PropsGridForTest: TValueListEditor;
    function ControlOfForTest(AIndex: Integer): TControl;
  end;

procedure ShowReportPreview(AOwner: TComponent; ADb: TAppDb; ADef: TaReportDef; const ASortOption: string = '');
{ makro exportpdf: "Naziv > datoteka.pdf" (Naziv smije imati #poredak=Opcija i @uvjet nije podrzan) }
function ExportReportPdfNamed(ADb: TAppDb; const AArg: string; out AErr: string): Boolean;
{ isto za HTML (makro exporthtml) }
function ExportReportHtmlNamed(ADb: TAppDb; const AArg: string; out AErr: string): Boolean;

implementation

uses
  ta_i18n;


type
  TRGridHack = class(TValueListEditor)
  public
    property Editor;
  end;

const
  GridStep = 4;
  HandleSize = 8;
  EdgeBand = 6;                  { debljina ruba u kojem se vuce velicina (rucke su unutar kontrole) }

type
  { ponovno slaganje izvjesca u odabranom poretku iz pregleda }
  TSortRenderer = class
  public
    Db: TAppDb;
    Def: TaReportDef;
    function Render(const AOption: string): TaRenderedReport;
  end;

function TSortRenderer.Render(const AOption: string): TaRenderedReport;
var
  Eng: TaReportEngine;
begin
  Eng := TaReportEngine.Create(Db, Def);
  try
    Eng.SortOverride := Def.SortFor(AOption);
    Result := Eng.Render;
  finally
    Eng.Free;
  end;
end;

function ExportReportNamed(ADb: TAppDb; const AArg: string; AHtml: Boolean; out AErr: string): Boolean;
var
  P: Integer;
  Nm, Opt, Dest, Js: string;
  Def: TaReportDef;
  Eng: TaReportEngine;
  Rep: TaRenderedReport;
begin
  Result := False;
  AErr := '';
  P := Pos('>', AArg);
  if P = 0 then begin AErr := Tr('The form is: report > file.pdf'); Exit; end;
  SplitReportArg(Trim(Copy(AArg, 1, P - 1)), Nm, Opt);
  Dest := Trim(Copy(AArg, P + 1, MaxInt));
  Js := ADb.LoadObject('_sys_reports', Nm);
  if Js = '' then begin AErr := Tr('There is no report: ') + Nm; Exit; end;
  Def := TaReportDef.Create;
  try
    Def.FromJson(Js);
    Def.Name := Nm;
    ADb.ClearParams;
    Eng := TaReportEngine.Create(ADb, Def);
    try
      Eng.SortOverride := Def.SortFor(Opt);
      Rep := Eng.Render;
      try
        ForceDirectories(ExtractFilePath(ExpandFileName(Dest)));
        if AHtml then Result := ExportHtml(Rep, Dest)
        else Result := ExportPdf(Rep, Dest, AErr);
        if (not Result) and (AErr = '') then AErr := Tr('The file was not saved.');
      finally
        Rep.Free;
      end;
    finally
      Eng.Free;
    end;
  finally
    Def.Free;
  end;
end;

function ExportReportPdfNamed(ADb: TAppDb; const AArg: string; out AErr: string): Boolean;
begin
  Result := ExportReportNamed(ADb, AArg, False, AErr);
end;

function ExportReportHtmlNamed(ADb: TAppDb; const AArg: string; out AErr: string): Boolean;
begin
  Result := ExportReportNamed(ADb, AArg, True, AErr);
end;

procedure ShowReportPreview(AOwner: TComponent; ADb: TAppDb; ADef: TaReportDef; const ASortOption: string);
var
  Eng: TaReportEngine;
  Rep: TaRenderedReport;
  Pv: TaReportPreview;
  Rn: TSortRenderer;
  Ch: TStringList;
  I, Sel: Integer;
  Opt: string;
begin
  Opt := Trim(ASortOption);
  { bez SortBy-a i bez odabira vrijedi prvi ponudeni poredak }
  if (Opt = '') and (ADef.SortOptionCount > 0) and (Trim(ADef.SortBy) = '') then Opt := ADef.SortOptionName(0);
  Eng := TaReportEngine.Create(ADb, ADef);
  try
    Eng.SortOverride := ADef.SortFor(Opt);
    Rep := Eng.Render;
  finally
    Eng.Free;
  end;
  Pv := TaReportPreview.CreatePreview(AOwner, Rep, ADef.Name);
  Rn := TSortRenderer.Create;
  Ch := TStringList.Create;
  try
    Rn.Db := ADb;
    Rn.Def := ADef;
    Sel := -1;   { -1: vrijedi SortBy izvjesca, popis nema odabir }
    for I := 0 to ADef.SortOptionCount - 1 do
    begin
      Ch.Add(ADef.SortOptionName(I));
      if SameText(ADef.SortOptionName(I), Opt) then Sel := I;
    end;
    Pv.SetSortChoices(Ch, Sel, @Rn.Render);
    Pv.ShowModal;
  finally
    Ch.Free;
    Pv.Free;
    Rn.Free;
  end;
end;

constructor TaReportDesigner.CreateDesigner(AOwner: TComponent; ADb: TAppDb; ADef: TaReportDef);
begin
  inherited CreateNew(AOwner);
  FDb := ADb;
  FDef := ADef;
  FSelBand := -1;
  FMulti := TList.Create;
  FLassoPrev := TList.Create;
  FDragGroup := TList.Create;
  FUndo := TStringList.Create;
  KeyPreview := True;
  OnKeyDown := @ReportKeyDown;
  Caption := Tr('Report design: ') + FDef.Name;
  SetBounds(0, 0, 1240, 760);
  Position := poScreenCenter;
  BuildUi;
  BuildBands;
  BuildItems;
  Relayout;
end;

destructor TaReportDesigner.Destroy;
begin
  FMulti.Free;
  FLassoPrev.Free;
  FDragGroup.Free;
  FUndo.Free;
  FDef.Free;
  inherited Destroy;
end;

function TaReportDesigner.Snap(V: Integer): Integer;
begin
  Result := (V + GridStep div 2) div GridStep * GridStep;
  if Result < 0 then Result := 0;
end;

procedure TaReportDesigner.BuildUi;
var
  Tb, Tb2, Rt: TPanel;
  L: TLabel;
  B: TButton;
  I, BX, XO: Integer;
  T: TStringList;

  procedure Btn(const ACaption: string; AX, AW: Integer; AHandler: TNotifyEvent);
  var
    W: Integer;
  begin
    W := Canvas.TextWidth(ACaption) + 44;
    MakeToolBtn(Tb, ACaption, ToolIconFor(ACaption), BX, 6, W, 26, AHandler);
    Inc(BX, W + 4);
  end;

  procedure Lbl(const ACaption: string; AX: Integer);
  begin
    L := TLabel.Create(Self);
    L.Parent := Tb;
    L.Caption := ACaption;
    L.SetBounds(AX, 12, 60, 18);
  end;

begin
  Tb := TPanel.Create(Self);
  Tb.Parent := Self;
  Tb.Align := alTop;
  Tb.Height := 38;
  Tb.BevelOuter := bvNone;
  BX := 6;
  Btn(Tr('Save'), 6, 64, @SaveClick);
  Btn(Tr('Preview'), 98, 64, @PreviewClick);
  Btn(Tr('Delete item'), 190, 92, @DeleteClick);
  Btn(Tr('Add fields'), 308, 92, @AddFieldsClick);
  Btn(Tr('Expression...'), 426, 70, @ExprClick);
  XO := BX + 8;
  Lbl(Tr('Source:'), XO);
  FSource := TComboBox.Create(Self);
  FSource.Parent := Tb;
  FSource.SetBounds(XO + 42, 6, 150, 26);
  T := FDb.UserTables;
  try
    for I := 0 to T.Count - 1 do FSource.Items.Add(T[I]);
  finally
    T.Free;
  end;
  T := FDb.ListObjects('_sys_queries');
  try
    for I := 0 to T.Count - 1 do FSource.Items.Add(T[I]);
  finally
    T.Free;
  end;
  FSource.Text := FDef.RecordSource;
  FSource.OnChange := @SourceChange;
  Lbl(Tr('Group:'), XO + 200);
  FGroup := TComboBox.Create(Self);
  FGroup.Parent := Tb;
  FGroup.SetBounds(XO + 244, 6, 110, 26);
  FGroup.Text := FDef.GroupField;
  Lbl(Tr('Sort:'), XO + 360);
  FSort := TEdit.Create(Self);
  FSort.Parent := Tb;
  FSort.SetBounds(XO + 396, 6, 100, 26);
  FSort.Text := FDef.SortBy;
  Lbl(Tr('Title:'), XO + 504);
  FTitle := TEdit.Create(Self);
  FTitle.Parent := Tb;
  FTitle.SetBounds(XO + 558, 6, 150, 26);
  FTitle.Text := FDef.Title;
  SourceChange(nil);

  Tb2 := TPanel.Create(Self);
  Tb2.Parent := Self;
  Tb2.Align := alTop;
  Tb2.Height := 36;
  Tb2.BevelOuter := bvNone;
  Tb2.Top := 40;
  MakeToolBtn(Tb2, Tr('Undo'), 'undo', 6, 5, 110, 26, @UndoClick);
  MakeToolBtn(Tb2, Tr('Align') + ' ▾', 'align_al', 120, 5, 130, 26, @LayoutButtonClick);
  MakeToolBtn(Tb2, Tr('Order…'), 'filter', 254, 5, 124, 26, @SortClick);
  MakeToolBtn(Tb2, Tr('Page and labels…'), 'pagesetup', 382, 5, 244, 26, @PageSetupClick);
  L := TLabel.Create(Self); L.Parent := Tb2; L.Caption := Tr('Drag a frame = select several items, Ctrl+click adds, Ctrl+A = all, arrows move, Ctrl+Z undoes');
  L.SetBounds(636, 10, 700, 18); L.Font.Color := clGray;

  FPalette := TListBox.Create(Self);
  FPalette.Parent := Self;
  FPalette.Align := alLeft;
  FPalette.Width := 132;
  FPalette.Style := lbOwnerDrawFixed;
  FPalette.ItemHeight := 24;
  FPalette.OnDrawItem := @PaletteDraw;
  for I := 0 to High(ReportKindNames) do FPalette.Items.Add(ReportKindNames[I]);
  FPalette.ItemIndex := -1;

  Rt := TPanel.Create(Self);
  Rt.Parent := Self;
  Rt.Align := alRight;
  Rt.Width := 280;
  Rt.BevelOuter := bvNone;
  FResizeTimer := TTimer.Create(Self);
  FResizeTimer.Enabled := False;
  FResizeTimer.Interval := 20;
  FResizeTimer.OnTimer := @ResizeTick;
  FProps := TValueListEditor.Create(Self);
  FProps.Parent := Rt;
  FProps.Align := alClient;
  FProps.OnValidateEntry := @PropValidateEntry;
  FProps.OnEditButtonClick := @PropButton;

  FScroll := TScrollBox.Create(Self);
  FScroll.Parent := Self;
  FLassoShape := TShape.Create(Self);
  FLassoShape.Parent := FScroll;
  FLassoShape.Brush.Style := bsClear;
  FLassoShape.Pen.Color := clBlue;
  FLassoShape.Pen.Style := psDash;
  FLassoShape.Visible := False;
  FLassoShape.Enabled := False;
  FScroll.Align := alClient;
  FScroll.Color := clGray;
end;

function TaReportDesigner.SourceFields(const ASource: string): TStringList;
var
  Q: TZQuery;
  I: Integer;
begin
  Result := TStringList.Create;
  if Trim(ASource) = '' then Exit;
  try
    Inc(FDb.QuietParams);
    try
      Q := FDb.NewQuery('SELECT * FROM ' + FDb.SourceFrom(Trim(ASource)) + ' LIMIT 1');
    finally
      Dec(FDb.QuietParams);
    end;
    try
      Q.Open;
      for I := 0 to Q.FieldCount - 1 do Result.Add(Q.Fields[I].FieldName);
    finally
      Q.Free;
    end;
  except
  end;
end;

procedure TaReportDesigner.SortClick(Sender: TObject);
var
  Fl: TStringList;
  V: string;
begin
  Fl := SourceFields(Trim(FSource.Text));
  try
    V := Trim(FSort.Text);
    if RunSortBuilder(Self, Fl, V) then FSort.Text := V;
  finally
    Fl.Free;
  end;
end;

procedure TaReportDesigner.SourceChange(Sender: TObject);
var
  F: TStringList;
begin
  F := SourceFields(FSource.Text);
  try
    FGroup.Items.Assign(F);
  finally
    F.Free;
  end;
end;

procedure TaReportDesigner.BuildBands;
var
  I: Integer;
begin
  for I := 0 to 6 do
  begin
    FStrips[I] := TPanel.Create(Self);
    FStrips[I].Parent := FScroll;
    FStrips[I].Caption := SectionNames[I];
    FStrips[I].Tag := I;
    FStrips[I].Color := clSilver;
    FStrips[I].BevelOuter := bvNone;
    FStrips[I].Alignment := taLeftJustify;
    FStrips[I].OnClick := @StripClick;
    FBands[I] := TPanel.Create(Self);
    FBands[I].Parent := FScroll;
    FBands[I].Tag := I;
    FBands[I].Color := clWhite;
    FBands[I].BevelOuter := bvNone;
    FBands[I].OnMouseDown := @BandMouseDown;
    FBands[I].OnPaint := @BandPaint;
  end;
end;

procedure TaReportDesigner.CopySelection(ATo: TList);
var
  L: TList;
begin
  L := SelectionList;
  try
    ATo.Assign(L, laCopy);
  finally
    L.Free;
  end;
end;

procedure TaReportDesigner.PaletteDraw(Control: TWinControl; Index: Integer; ARect: TRect; State: TOwnerDrawState);
begin
  DrawIconItem(FPalette, Index, ARect, State, ControlIconName(FPalette.Items[Index]));
end;

function TaReportDesigner.BandWidth: Integer;
begin
  Result := Max(40, FDef.PageWidth - FDef.MarginLeft - FDef.MarginRight);
end;

procedure TaReportDesigner.PageSetupClick(Sender: TObject);
var
  Snapshot: string;
  I: Integer;
begin
  Snapshot := FDef.ToJson;
  if RunPageSetup(Self, FDef) then
  begin
    { stanje prije promjene za Poništi }
    FUndo.Add(Snapshot);
    while FUndo.Count > 50 do FUndo.Delete(0);
    Relayout;
    for I := 0 to 6 do FBands[I].Invalidate;
    ShowProps;
  end;
end;

procedure TaReportDesigner.Relayout;
var
  I, Y: Integer;
begin
  Y := 8;
  for I := 0 to 6 do
  begin
    FStrips[I].SetBounds(8, Y, BandWidth, 18);
    Inc(Y, 18);
    FBands[I].SetBounds(8, Y, BandWidth, FDef.Heights[I]);
    Inc(Y, FDef.Heights[I] + 2);
    FStrips[I].Font.Style := [];
  end;
  if FSelBand >= 0 then FStrips[FSelBand].Font.Style := [fsBold];
end;

function TaReportDesigner.BandIndex(APanel: TObject): Integer;
begin
  Result := TPanel(APanel).Tag;
end;

procedure TaReportDesigner.HookControl(C: TControl);
begin
  C.OnMouseDown := @CtlMouseDown;
  C.OnMouseMove := @CtlMouseMove;
  C.OnMouseUp := @CtlMouseUp;
end;

procedure TaReportDesigner.BuildItems;
var
  I, S: Integer;
  C: TControl;
begin
  for I := 0 to FDef.Count - 1 do
  begin
    S := SectionIndex(FDef[I].Section);
    if S < 0 then S := SecDetail;
    C := CreateAccessControl(FBands[S], FBands[S], FDef[I]);
    ApplyDef(C, True);
    HookControl(C);
  end;
end;

function TaReportDesigner.PlaceItem(const AKind: string; ABand, X, Y: Integer): TControl;
var
  D: TaControlDef;
begin
  D := TaControlDef.Create;
  D.Kind := AKind;
  D.Name := FDef.UniqueName(AKind);
  D.Section := SectionNames[ABand];
  D.Left := X;
  D.Top := Y;
  DefaultSize(AKind, D.Width, D.Height);
  if (AKind = 'Label') or (AKind = 'Hyperlink') then D.Caption := D.Name;
  FDef.Add(D);
  Result := CreateAccessControl(FBands[ABand], FBands[ABand], D);
  ApplyDef(Result, True);
  HookControl(Result);
  Select(Result);
end;

procedure TaReportDesigner.Select(C: TControl);
begin
  ClearMulti;
  FSelected := C;
  FSelBand := -1;
  ShowProps;
  Relayout;
  FScroll.Invalidate;
  if C <> nil then C.Parent.Invalidate;
end;

procedure TaReportDesigner.SelectBand(ABand: Integer);
begin
  ClearMulti;
  FSelected := nil;
  FSelBand := ABand;
  ShowProps;
  Relayout;
end;

procedure TaReportDesigner.ShowProps;
var
  D: TaControlDef;
  I: Integer;
  Names: TStringList;
begin
  FLoadingProps := True;
  try
    FProps.Strings.Clear;
    if FSelBand >= 0 then
    begin
      FProps.Strings.Add('Section=' + SectionNames[FSelBand]);
      FProps.Strings.Add('Height=' + IntToStr(FDef.Heights[FSelBand]));
      Exit;
    end;
    D := nil;
    if FSelected <> nil then D := DefOf(FSelected);
    if D = nil then
    begin
      { nothing selected: the report itself }
      FProps.Strings.Add('Columns=' + IntToStr(FDef.Columns));
      FProps.Strings.Add('ColumnGap=' + IntToStr(FDef.ColumnGap));
      FProps.Strings.Add('SortOptions=' + FDef.SortOptions);
      FProps.ItemProps['SortOptions'].EditStyle := esEllipsis;
      Exit;
    end;
    FProps.Strings.Add('Kind=' + D.Kind);
    Names := PropertyNamesFor(D.Kind, True);
    try
      for I := 0 to Names.Count - 1 do
      begin
        if Names[I] = 'FontName' then FProps.Strings.Add('Font=' + FontSummary(D));
        FProps.Strings.Add(Names[I] + '=' + DefGet(D, Names[I]));
      end;
    finally
      Names.Free;
    end;
    ConfigureFor;
  finally
    FLoadingProps := False;
  end;
end;

procedure TaReportDesigner.ConfigureFor;
var
  Ctx: TPropContext;
  K, Rs: string;
  D: TaControlDef;
begin
  K := '';
  Rs := '';
  if FSelected <> nil then
  begin
    D := DefOf(FSelected);
    if D <> nil then begin K := D.Kind; Rs := D.RowSource; end;
  end;
  FillContext(FDb, Ctx, K, Trim(FSource.Text), Rs, nil);
  try
    ConfigureProps(FProps, Ctx);
  finally
    FreeContext(Ctx);
  end;
end;

{ Gumb ... u retku svojstva: font, boja, slika, pravila ili izraz. }
procedure TaReportDesigner.PropButton(Sender: TObject);
var
  Key, Cur, Hex: string;
  D: TaControlDef;
  Vals, Fld: TStringList;
  I: Integer;
begin
  if (FProps.Row >= 1) and (FSelected = nil) and (FSelBand < 0) and (FProps.Cells[0, FProps.Row] = 'SortOptions') then
  begin
    Fld := SourceFields(Trim(FSource.Text));
    try
      Cur := FDef.SortOptions;
      if RunSortOptionsBuilder(Self, Fld, Cur) then begin FDef.SortOptions := Cur; ShowProps; end;
    finally
      Fld.Free;
    end;
    Exit;
  end;
  if (FProps.Row < 1) or (FSelected = nil) then Exit;
  Key := FProps.Cells[0, FProps.Row];
  D := DefOf(FSelected);
  if D = nil then Exit;
  case PropKindOf(Key) of
    pkFont:
      begin
        Vals := TStringList.Create;
        try
          if RunFontDialog(Self, D, Vals) then
          begin
            for I := 0 to Vals.Count - 1 do ApplyProp(Vals.Names[I], Vals.ValueFromIndex[I]);
            ShowProps;
          end;
        finally
          Vals.Free;
        end;
      end;
    pkColor:
      if RunColorDialog(Self, DefGet(D, Key), Hex) then begin ApplyProp(Key, Hex); ShowProps; end;
    pkPicture:
      if RunPictureDialog(Self, Cur) then begin ApplyProp('Picture', Cur); ShowProps; end;
  else
    if (Key = 'RowSource') and (D.Kind = 'Chart') then
    begin
      Cur := DefGet(D, Key);
      if DesignEditSource(Self, FDb, D.Kind, Cur) then begin ApplyProp(Key, Cur); ShowProps; end;
    end
    else if Key = 'CondFormat' then
    begin
      Cur := DefGet(D, Key);
      Fld := FieldNamesOf(FDb, Trim(FSource.Text));
      try
        if DesignEditCondFormat(Self, FDb, Fld, Cur) then begin ApplyProp(Key, Cur); ShowProps; end;
      finally
        Fld.Free;
      end;
    end
    else ExprClick(Sender);
  end;
end;

{ LCL-ov OnValidate se u ovoj verziji nikad ne poziva; vrijednost se prima kad se uredjivanje celije zavrsi }
procedure TaReportDesigner.PropValidateEntry(Sender: TObject; aCol, aRow: Integer; const OldValue: string; var NewValue: string);
begin
  if (aCol <> 1) or (aRow < 1) or FLoadingProps then Exit;
  if NewValue = OldValue then Exit;
  PropValidate(Sender, aCol, aRow, TValueListEditor(Sender).Cells[0, aRow], NewValue);
end;

procedure TaReportDesigner.PropValidate(Sender: TObject; ACol, ARow: Longint;
  const KeyName, KeyValue: string);
begin
  if FLoadingProps or (KeyName = 'Font') then Exit;
  ApplyProp(KeyName, KeyValue);
end;

procedure TaReportDesigner.ApplyProp(const AKey, AValue: string);
var
  D: TaControlDef;
  Idx: Integer;
begin
  if FSelBand >= 0 then
  begin
    if AKey = 'Height' then
    begin
      FDef.Heights[FSelBand] := StrToIntDef(AValue, FDef.Heights[FSelBand]);
      if FDef.Heights[FSelBand] < 0 then FDef.Heights[FSelBand] := 0;
      Relayout;
    end;
    Exit;
  end;
  if FSelected = nil then
  begin
    if AKey = 'Columns' then FDef.Columns := Max(1, StrToIntDef(AValue, FDef.Columns))
    else if AKey = 'ColumnGap' then FDef.ColumnGap := Max(0, StrToIntDef(AValue, FDef.ColumnGap))
    else if AKey = 'SortOptions' then FDef.SortOptions := AValue;
    Exit;
  end;
  D := DefOf(FSelected);
  if (D = nil) or (AKey = 'Kind') then Exit;
  if AKey = 'Name' then
  begin
    Idx := FDef.IndexOfName(AValue);
    if (not IsValidIdent(AValue)) or ((Idx >= 0) and (FDef[Idx] <> D)) then
    begin
      ShowMessage(Tr('Invalid or already used name.'));
      Exit;
    end;
  end;
  DefSet(D, AKey, AValue);
  if (AKey = 'ControlSource') and (AValue <> '') and (AValue[1] = '=') and (CheckExpr(Copy(AValue, 2, MaxInt)) <> '') then
    ShowMessage(Tr('The expression is not valid: ') + CheckExpr(Copy(AValue, 2, MaxInt)));
  ApplyDef(FSelected, True);
  FSelected.Parent.Invalidate;
end;

procedure TaReportDesigner.ExprClick(Sender: TObject);
var
  Key, Cur: string;
  D: TaControlDef;
begin
  if (FProps.Row < 1) or (FSelected = nil) then begin ShowMessage(Tr('Choose an item and the row ControlSource.')); Exit; end;
  Key := FProps.Cells[0, FProps.Row];
  D := DefOf(FSelected);
  if (Key <> 'ControlSource') and (Key <> 'RowSource') and (Key <> 'Caption') then
  begin
    ShowMessage(Tr('Choose the row ControlSource, RowSource or Caption.'));
    Exit;
  end;
  Cur := DefGet(D, Key);
  if EditExpression(Self, FDb, Trim(FSource.Text), D.Name + '.' + Key, Cur) then
  begin
    ApplyProp(Key, Cur);
    ShowProps;
  end;
end;

procedure TaReportDesigner.StripClick(Sender: TObject);
begin
  SelectBand(TPanel(Sender).Tag);
end;

procedure TaReportDesigner.BandMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if FPalette.ItemIndex >= 0 then
  begin
    PlaceItem(FPalette.Items[FPalette.ItemIndex], BandIndex(Sender), Snap(X), Snap(Y));
    FPalette.ItemIndex := -1;
  end
  else if Button = mbLeft then
  begin
    { okvir za odabir: bez povlacenja ostaje obicni klik u prazno (ponistava odabir) }
    FLassoPrev.Clear;
    FLassoAdd := ssCtrl in Shift;
    if FLassoAdd then CopySelection(FLassoPrev)
    else Select(nil);
    FDragStart := Mouse.CursorPos;
    FLasso := True;
    FLassoUseTo := False;
    FResizeTimer.Enabled := True;
  end;
end;

procedure TaReportDesigner.BandPaint(Sender: TObject);
var
  C: TControl;
  P: TPanel;
  I, Hx, Hy: Integer;
begin
  P := TPanel(Sender);
  { naljepnice: okomita crta kazuje gdje zavrsava jedna naljepnica }
  if (P.Tag = SecDetail) and (FDef.Columns > 1) then
    with P.Canvas do
    begin
      Pen.Color := clRed;
      Pen.Style := psDot;
      Hx := (BandWidth - FDef.ColumnGap * (FDef.Columns - 1)) div FDef.Columns;
      MoveTo(Hx, 0);
      LineTo(Hx, P.Height);
      Pen.Style := psSolid;
    end;
  for I := 0 to FMulti.Count - 1 do
    if TControl(FMulti[I]).Parent = P then
      with P.Canvas do
      begin
        C := TControl(FMulti[I]);
        Pen.Color := clBlue;
        Pen.Style := psDot;
        Brush.Style := bsClear;
        Rectangle(C.Left - 2, C.Top - 2, C.Left + C.Width + 2, C.Top + C.Height + 2);
        Pen.Style := psSolid;
      end;
  C := FSelected;
  if (C = nil) or (C.Parent <> P) then Exit;
  with P.Canvas do
  begin
    Pen.Color := clBlue;
    Pen.Style := psDot;
    Brush.Style := bsClear;
    Rectangle(C.Left - 2, C.Top - 2, C.Left + C.Width + 2, C.Top + C.Height + 2);
    Pen.Style := psSolid;
    Brush.Style := bsSolid;
    Brush.Color := clNavy;
    { osam rucki (uglovi i sredine stranica) uz rub kontrole }
    for I := 0 to 7 do
    begin
      case I of
        0, 6: Hx := C.Left - 1;
        1, 5: Hx := C.Left + C.Width div 2 - 3;
        2, 4: Hx := C.Left + C.Width - 5;
      else
        if I = 3 then Hx := C.Left + C.Width - 5 else Hx := C.Left - 1;
      end;
      case I of
        0, 1, 2: Hy := C.Top - 1;
        3, 7: Hy := C.Top + C.Height div 2 - 3;
      else
        Hy := C.Top + C.Height - 5;
      end;
      FillRect(Hx, Hy, Hx + 6, Hy + 6);
    end;
  end;
end;

procedure TaReportDesigner.CtlMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  C: TControl;
  Sel: TList;
  I: Integer;
begin
  if Button <> mbLeft then Exit;
  if FPalette.ItemIndex >= 0 then Exit;
  C := TControl(Sender);
  FDragCtl := C;
  if ssCtrl in Shift then
  begin
    ToggleMulti(C);
    FDragging := False;
    FResizing := False;
    Exit;
  end;
  if (FMulti.IndexOf(C) < 0) and (C <> FSelected) then Select(C);
  FResizeMode := EdgeMode(X, Y, C.Width, C.Height, EdgeBand);
  FResizing := FResizeMode <> 0;
  FDragging := not FResizing;
  C.MouseCapture := True;
  FDragUndoPushed := False;
  FDragStart := Mouse.CursorPos;
  FOrig := Rect(C.Left, C.Top, C.Width, C.Height);
  FResizeTimer.Enabled := True;
  FDragGroup.Clear;
  SetLength(FGroupOrig, 0);
  if FDragging then
  begin
    Sel := SelectionList;
    try
      for I := 0 to Sel.Count - 1 do
        if TControl(Sel[I]) <> C then
        begin
          FDragGroup.Add(Sel[I]);
          SetLength(FGroupOrig, Length(FGroupOrig) + 1);
          FGroupOrig[High(FGroupOrig)] := Point(TControl(Sel[I]).Left, TControl(Sel[I]).Top);
        end;
    finally
      Sel.Free;
    end;
  end;
end;

{ jedini ulaz za promjenu velicine misem: Dx, Dy = pomak od pocetka povlacenja }
procedure TaReportDesigner.ResizeTo(Dx, Dy: Integer);
var
  D: TaControlDef;
  Box: TLBox;
  MinW, MinH: Integer;
begin
  if FSelected = nil then Exit;
  D := DefOf(FSelected);
  if D = nil then Exit;
  if ((Dx <> 0) or (Dy <> 0)) and not FDragUndoPushed then
  begin
    D.Left := FOrig.Left; D.Top := FOrig.Top; D.Width := FOrig.Right; D.Height := FOrig.Bottom;
    PushUndo;
    FDragUndoPushed := True;
  end;
  MinW := 8; MinH := 8;
  if (D.Kind = 'Line') or (D.Kind = 'PageBreak') or (D.Kind = 'Rectangle') then begin MinW := 1; MinH := 1; end;
  Box.L := FOrig.Left; Box.T := FOrig.Top; Box.W := FOrig.Right; Box.H := FOrig.Bottom;
  Box := ResizeBox(Box, FResizeMode, Dx, Dy, MinW, MinH, GridStep);
  D.Left := Box.L; D.Top := Box.T; D.Width := Box.W; D.Height := Box.H;
  FSelected.SetBounds(D.Left, D.Top, D.Width, D.Height);
  FSelected.Parent.Invalidate;
end;

{ Qt ne salje pomake misa kontroli cim pokazivac iziđe iz nje, pa se pokazivac cita periodički }
procedure TaReportDesigner.ResizeTick(Sender: TObject);
begin
  if FLasso then
  begin
    if (GetKeyState(VK_LBUTTON) and $8000) = 0 then LassoEnd else LassoTick;
    Exit;
  end;
  if not (FResizing or FDragging) then begin FResizeTimer.Enabled := False; Exit; end;
  if (GetKeyState(VK_LBUTTON) and $8000) = 0 then
  begin
    FResizeTimer.Enabled := False;
    if FDragCtl <> nil then FDragCtl.MouseCapture := False;
    FResizing := False;
    FDragging := False;
    ShowProps;
    Exit;
  end;
  if FResizing then ResizeTo(Mouse.CursorPos.X - FDragStart.X, Mouse.CursorPos.Y - FDragStart.Y)
  else DragTo(Mouse.CursorPos.X - FDragStart.X, Mouse.CursorPos.Y - FDragStart.Y);
end;

{ pomak svih odabranih: Dx, Dy od pocetka povlacenja; jedini ulaz za pomicanje misem }
procedure TaReportDesigner.DragTo(Dx, Dy: Integer);
var
  D, D2: TaControlDef;
  I: Integer;
begin
  if FDragCtl = nil then Exit;
  D := DefOf(FDragCtl);
  if D = nil then Exit;
  if ((Dx <> 0) or (Dy <> 0)) and not FDragUndoPushed then
  begin
    D.Left := FOrig.Left; D.Top := FOrig.Top; D.Width := FOrig.Right; D.Height := FOrig.Bottom;
    PushUndo;
    FDragUndoPushed := True;
  end;
  D.Left := Snap(FOrig.Left + Dx);
  D.Top := Snap(FOrig.Top + Dy);
  if D.Left < 0 then D.Left := 0;
  if D.Top < 0 then D.Top := 0;
  for I := 0 to FDragGroup.Count - 1 do
  begin
    D2 := DefOf(TControl(FDragGroup[I]));
    D2.Left := Max(0, FGroupOrig[I].X + (D.Left - FOrig.Left));
    D2.Top := Max(0, FGroupOrig[I].Y + (D.Top - FOrig.Top));
    TControl(FDragGroup[I]).SetBounds(D2.Left, D2.Top, D2.Width, D2.Height);
    TControl(FDragGroup[I]).Parent.Invalidate;
  end;
  FDragCtl.SetBounds(D.Left, D.Top, D.Width, D.Height);
  FDragCtl.Parent.Invalidate;
end;

function TaReportDesigner.ScreenRectOf(C: TControl): TRect;
var
  P: TPoint;
begin
  P := C.Parent.ClientToScreen(Point(C.Left, C.Top));
  Result := Rect(P.X, P.Y, P.X + C.Width, P.Y + C.Height);
end;

procedure TaReportDesigner.LassoTick;
var
  A, B: TPoint;
  R, Cr, Ix: TRect;
  I, J: Integer;
  C: TControl;
  First: Boolean;
begin
  if FLassoUseTo then B := FLassoTo else B := Mouse.CursorPos;
  A := FDragStart;
  R := Rect(Min(A.X, B.X), Min(A.Y, B.Y), Max(A.X, B.X), Max(A.Y, B.Y));
  A := FScroll.ScreenToClient(Point(R.Left, R.Top));
  B := FScroll.ScreenToClient(Point(R.Right, R.Bottom));
  FLassoShape.SetBounds(A.X, A.Y, Max(1, B.X - A.X), Max(1, B.Y - A.Y));
  FLassoShape.Visible := True;
  FLassoShape.BringToFront;
  { odabir = ranije odabrano (uz Ctrl) + sve sto okvir dotice }
  FSelected := nil;
  FMulti.Clear;
  First := True;
  if FLassoAdd then
    for I := 0 to FLassoPrev.Count - 1 do
      if First then begin FSelected := TControl(FLassoPrev[I]); First := False; end
      else FMulti.Add(FLassoPrev[I]);
  for I := 0 to 6 do
    for J := 0 to FBands[I].ControlCount - 1 do
    begin
      C := FBands[I].Controls[J];
      if (DefOf(C) = nil) or (FLassoAdd and (FLassoPrev.IndexOf(C) >= 0)) then Continue;
      Cr := ScreenRectOf(C);
      if IntersectRect(Ix, R, Cr) then
        if FSelected = nil then FSelected := C else FMulti.Add(C);
    end;
  FSelBand := -1;
  for I := 0 to 6 do FBands[I].Invalidate;
end;

procedure TaReportDesigner.LassoEnd;
begin
  FResizeTimer.Enabled := False;
  FLasso := False;
  FLassoShape.Visible := False;
  ShowProps;
  Relayout;
  FScroll.Invalidate;
end;

procedure TaReportDesigner.LassoForTest(const AFrom, ATo: TPoint; AAdd: Boolean);
begin
  { isto sto i misem: pocetak, pomak, otpustanje (pokazivac se ne cita iz sustava) }
  FLassoPrev.Clear;
  if AAdd then CopySelection(FLassoPrev);
  FLassoAdd := AAdd;
  if not AAdd then begin FSelected := nil; FMulti.Clear; end;
  FLasso := True;
  FDragStart := AFrom;
  FLassoTo := ATo;
  FLassoUseTo := True;
  LassoTick;
  FLassoUseTo := False;
  LassoEnd;
end;

procedure TaReportDesigner.GroupDragForTest(C: TControl; Dx, Dy: Integer);
var
  Sel: TList;
  I: Integer;
begin
  { stanje kao nakon pritiska misa na C }
  FDragCtl := C;
  FResizing := False;
  FDragging := True;
  FDragUndoPushed := False;
  FOrig := Rect(C.Left, C.Top, C.Width, C.Height);
  FDragGroup.Clear;
  SetLength(FGroupOrig, 0);
  Sel := SelectionList;
  try
    for I := 0 to Sel.Count - 1 do
      if TControl(Sel[I]) <> C then
      begin
        FDragGroup.Add(Sel[I]);
        SetLength(FGroupOrig, Length(FGroupOrig) + 1);
        FGroupOrig[High(FGroupOrig)] := Point(TControl(Sel[I]).Left, TControl(Sel[I]).Top);
      end;
  finally
    Sel.Free;
  end;
  DragTo(Dx, Dy);
  FDragging := False;
end;

function TaReportDesigner.SelectedCountForTest: Integer;
begin
  Result := FMulti.Count;
  if FSelected <> nil then Inc(Result);
end;

procedure TaReportDesigner.CtlMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  C: TControl;
  Dx, Dy: Integer;
begin
  C := TControl(Sender);
  if not (FDragging or FResizing) then
  begin
    case EdgeMode(X, Y, C.Width, C.Height, EdgeBand) of
      gmLeft or gmTop, gmRight or gmBottom: C.Cursor := crSizeNWSE;
      gmRight or gmTop, gmLeft or gmBottom: C.Cursor := crSizeNESW;
      gmLeft, gmRight: C.Cursor := crSizeWE;
      gmTop, gmBottom: C.Cursor := crSizeNS;
    else
      C.Cursor := crDefault;
    end;
    Exit;
  end;
  Dx := Mouse.CursorPos.X - FDragStart.X;
  Dy := Mouse.CursorPos.Y - FDragStart.Y;
  if FDragging then DragTo(Dx, Dy) else ResizeTo(Dx, Dy);
end;

procedure TaReportDesigner.CtlMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if FDragging or FResizing then
  begin
    TControl(Sender).MouseCapture := False;
    FResizeTimer.Enabled := False;
    FDragging := False;
    FResizing := False;
    ShowProps;
  end;
end;

function TaReportDesigner.Save: Boolean;
begin
  FDef.Title := FTitle.Text;
  FDef.RecordSource := Trim(FSource.Text);
  FDef.GroupField := Trim(FGroup.Text);
  FDef.SortBy := Trim(FSort.Text);
  try
    FDb.SaveObject('_sys_reports', FDef.Name, FDef.ToJson);
    Result := True;
  except
    on E: Exception do
    begin
      ShowMessage(Tr('Saving failed: ') + E.Message);
      Result := False;
    end;
  end;
end;

procedure TaReportDesigner.SaveClick(Sender: TObject);
begin
  if Save then Caption := Tr('Report design: ') + FDef.Name + Tr(' (saved)');
end;

procedure TaReportDesigner.DeleteClick(Sender: TObject);
begin
  DeleteSelected;
end;

procedure TaReportDesigner.DeleteSelected;
var
  C: TControl;
  Sel: TList;
  I: Integer;
  Bands: TList;
begin
  if FSelected = nil then Exit;
  Sel := SelectionList;
  Bands := TList.Create;
  try
    PushUndo;
    Select(nil);
    for I := 0 to Sel.Count - 1 do
    begin
      C := TControl(Sel[I]);
      FDef.Delete(DefOf(C));
      Bands.Add(C.Parent);
      C.Free;
    end;
    for I := 0 to Bands.Count - 1 do TPanel(Bands[I]).Invalidate;
  finally
    Bands.Free;
    Sel.Free;
  end;
end;

procedure TaReportDesigner.ClearMulti;
var
  I: Integer;
begin
  if FMulti = nil then Exit;
  for I := 0 to FMulti.Count - 1 do
    if TControl(FMulti[I]).Parent <> nil then TControl(FMulti[I]).Parent.Invalidate;
  FMulti.Clear;
end;

procedure TaReportDesigner.ToggleMulti(C: TControl);
var
  I: Integer;
begin
  if C = nil then Exit;
  if FSelected = nil then
  begin
    FSelected := C;
    FSelBand := -1;
  end
  else if C = FSelected then
  begin
    if FMulti.Count > 0 then
    begin
      FSelected := TControl(FMulti[0]);
      FMulti.Delete(0);
    end;
  end
  else
  begin
    I := FMulti.IndexOf(C);
    if I >= 0 then FMulti.Delete(I) else FMulti.Add(C);
  end;
  ShowProps;
  FScroll.Invalidate;
  for I := 0 to 6 do FBands[I].Invalidate;
end;

function TaReportDesigner.SelectionList: TList;
begin
  Result := TList.Create;
  if FSelected <> nil then Result.Add(FSelected);
  Result.AddList(FMulti);
end;

procedure TaReportDesigner.SelectAll;
var
  I, J: Integer;
  C: TControl;
begin
  Select(nil);
  for I := 0 to 6 do
    for J := 0 to FBands[I].ControlCount - 1 do
    begin
      C := FBands[I].Controls[J];
      if DefOf(C) = nil then Continue;
      if FSelected = nil then FSelected := C else FMulti.Add(C);
    end;
  ShowProps;
  for I := 0 to 6 do FBands[I].Invalidate;
end;

procedure TaReportDesigner.DoLayout(AOp: TLayoutOp);
var
  L: TList;
  Boxes: TLBoxes;
  I: Integer;
  D: TaControlDef;
begin
  L := SelectionList;
  try
    if L.Count < 2 then Exit;
    SetLength(Boxes, L.Count);
    for I := 0 to L.Count - 1 do
    begin
      D := DefOf(TControl(L[I]));
      Boxes[I].L := D.Left; Boxes[I].T := D.Top; Boxes[I].W := D.Width; Boxes[I].H := D.Height;
    end;
    if not ApplyLayout(AOp, Boxes, 0) then Exit;
    PushUndo;
    for I := 0 to L.Count - 1 do
    begin
      D := DefOf(TControl(L[I]));
      D.Left := Boxes[I].L; D.Top := Boxes[I].T; D.Width := Boxes[I].W; D.Height := Boxes[I].H;
      TControl(L[I]).SetBounds(D.Left, D.Top, D.Width, D.Height);
    end;
    ShowProps;
    for I := 0 to 6 do FBands[I].Invalidate;
  finally
    L.Free;
  end;
end;

procedure TaReportDesigner.ZOrder(AToFront: Boolean);
var
  L: TList;
  I: Integer;
  D: TaControlDef;
begin
  L := SelectionList;
  try
    if L.Count = 0 then Exit;
    PushUndo;
    for I := 0 to L.Count - 1 do
    begin
      D := DefOf(TControl(L[I]));
      if AToFront then
      begin
        FDef.MoveItem(D, FDef.Count - 1);
        TControl(L[I]).BringToFront;
      end
      else
      begin
        FDef.MoveItem(D, 0);
        TControl(L[I]).SendToBack;
      end;
    end;
  finally
    L.Free;
  end;
end;

procedure TaReportDesigner.LayoutMenuClick(Sender: TObject);
var
  T: Integer;
begin
  T := TMenuItem(Sender).Tag;
  if T = 100 then ZOrder(True)
  else if T = 101 then ZOrder(False)
  else if T = 102 then SelectAll
  else DoLayout(TLayoutOp(T));
end;

procedure TaReportDesigner.LayoutButtonClick(Sender: TObject);
var
  I: Integer;
  It: TMenuItem;
  P: TPoint;
begin
  if FLayoutMenu = nil then
  begin
    FLayoutMenu := TPopupMenu.Create(Self);
    for I := Ord(Low(TLayoutOp)) to Ord(High(TLayoutOp)) do
    begin
      It := TMenuItem.Create(FLayoutMenu);
      It.Caption := Tr(LayoutOpNames[TLayoutOp(I)]);
      It.Tag := I;
      It.OnClick := @LayoutMenuClick;
      FLayoutMenu.Items.Add(It);
    end;
    It := TMenuItem.Create(FLayoutMenu); It.Caption := '-'; FLayoutMenu.Items.Add(It);
    It := TMenuItem.Create(FLayoutMenu); It.Caption := Tr('To the top'); It.Tag := 100; It.OnClick := @LayoutMenuClick; FLayoutMenu.Items.Add(It);
    It := TMenuItem.Create(FLayoutMenu); It.Caption := Tr('To the bottom'); It.Tag := 101; It.OnClick := @LayoutMenuClick; FLayoutMenu.Items.Add(It);
    It := TMenuItem.Create(FLayoutMenu); It.Caption := '-'; FLayoutMenu.Items.Add(It);
    It := TMenuItem.Create(FLayoutMenu); It.Caption := Tr('Select all (Ctrl+A)'); It.Tag := 102; It.OnClick := @LayoutMenuClick; FLayoutMenu.Items.Add(It);
  end;
  P := TControl(Sender).ClientToScreen(Point(0, TControl(Sender).Height));
  FLayoutMenu.PopUp(P.X, P.Y);
end;

procedure TaReportDesigner.PushUndo;
begin
  FUndo.Add(FDef.ToJson);
  while FUndo.Count > 60 do FUndo.Delete(0);
end;

{ Uklanja sve stavke s traka (definicija se ponovno gradi iz JSON-a). }
procedure TaReportDesigner.ClearItems;
var
  I, J: Integer;
begin
  FSelected := nil;
  FMulti.Clear;
  FDragGroup.Clear;
  for I := 0 to 6 do
    for J := FBands[I].ControlCount - 1 downto 0 do
      if DefOf(FBands[I].Controls[J]) <> nil then FBands[I].Controls[J].Free;
end;

procedure TaReportDesigner.DoUndo;
var
  Js: string;
begin
  if FUndo.Count = 0 then Exit;
  Js := FUndo[FUndo.Count - 1];
  FUndo.Delete(FUndo.Count - 1);
  ClearItems;
  FDef.FromJson(Js);
  BuildItems;
  Relayout;
  ShowProps;
end;

procedure TaReportDesigner.UndoClick(Sender: TObject);
begin
  DoUndo;
end;

procedure TaReportDesigner.ResizeBy(Dw, Dh: Integer);
var
  Sel: TList;
  I, MinW, MinH: Integer;
  D: TaControlDef;
begin
  if FSelected = nil then Exit;
  Sel := SelectionList;
  try
    PushUndo;
    for I := 0 to Sel.Count - 1 do
    begin
      D := DefOf(TControl(Sel[I]));
      MinW := 8; MinH := 8;
      if (D.Kind = 'Line') or (D.Kind = 'PageBreak') or (D.Kind = 'Rectangle') then begin MinW := 1; MinH := 1; end;
      D.Width := Max(MinW, D.Width + Dw);
      D.Height := Max(MinH, D.Height + Dh);
      TControl(Sel[I]).SetBounds(D.Left, D.Top, D.Width, D.Height);
      TControl(Sel[I]).Parent.Invalidate;
    end;
  finally
    Sel.Free;
  end;
  ShowProps;
end;

procedure TaReportDesigner.Nudge(Dx, Dy: Integer);
var
  Sel: TList;
  I: Integer;
  D: TaControlDef;
begin
  if FSelected = nil then Exit;
  Sel := SelectionList;
  try
    PushUndo;
    for I := 0 to Sel.Count - 1 do
    begin
      D := DefOf(TControl(Sel[I]));
      D.Left := D.Left + Dx;
      D.Top := D.Top + Dy;
      if D.Left < 0 then D.Left := 0;
      if D.Top < 0 then D.Top := 0;
      TControl(Sel[I]).SetBounds(D.Left, D.Top, D.Width, D.Height);
      TControl(Sel[I]).Parent.Invalidate;
    end;
  finally
    Sel.Free;
  end;
  ShowProps;
end;

procedure TaReportDesigner.ReportKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  Step: Integer;
begin
  if (ActiveControl = FProps) or (ActiveControl is TCustomEdit) or (ActiveControl is TCustomComboBox) then Exit;
  { strelice pomicu za 4, Ctrl+strelice za 1 piksel; Shift+strelice mijenjaju velicinu (Ctrl+Shift za 1 piksel) }
  if ssCtrl in Shift then Step := 1 else Step := 4;
  case Key of
    VK_DELETE: begin DeleteSelected; Key := 0; end;
    VK_LEFT: begin if ssShift in Shift then ResizeBy(-Step, 0) else Nudge(-Step, 0); Key := 0; end;
    VK_RIGHT: begin if ssShift in Shift then ResizeBy(Step, 0) else Nudge(Step, 0); Key := 0; end;
    VK_UP: begin if ssShift in Shift then ResizeBy(0, -Step) else Nudge(0, -Step); Key := 0; end;
    VK_DOWN: begin if ssShift in Shift then ResizeBy(0, Step) else Nudge(0, Step); Key := 0; end;
    VK_Z: if ssCtrl in Shift then begin DoUndo; Key := 0; end;
    VK_A: if ssCtrl in Shift then begin SelectAll; Key := 0; end;
  end;
end;

procedure TaReportDesigner.ToggleMultiForTest(C: TControl);
begin
  ToggleMulti(C);
end;

procedure TaReportDesigner.LayoutForTest(AOp: TLayoutOp);
begin
  DoLayout(AOp);
end;

procedure TaReportDesigner.ZOrderForTest(AToFront: Boolean);
begin
  ZOrder(AToFront);
end;

procedure TaReportDesigner.DeleteForTest;
begin
  DeleteSelected;
end;

procedure TaReportDesigner.UndoForTest;
begin
  DoUndo;
end;

procedure TaReportDesigner.TypeInGridForTest(const AKey, AValue: string);
var
  R: Integer;
begin
  for R := 1 to FProps.RowCount - 1 do
    if FProps.Cells[0, R] = AKey then
    begin
      if not Visible then Show;
      Application.ProcessMessages;
      FProps.SetFocus;
      FProps.Row := R;
      FProps.Col := 1;
      FProps.EditorMode := True;
      Application.ProcessMessages;
      if TRGridHack(FProps).Editor is TCustomEdit then TCustomEdit(TRGridHack(FProps).Editor).Text := AValue;
      if R < FProps.RowCount - 1 then FProps.Row := R + 1 else FProps.Row := R - 1;
      Application.ProcessMessages;
      Exit;
    end;
end;

{ povlacenje ruba odabrane kontrole (X, Y unutar kontrole) }
function TaReportDesigner.EdgeDragForTest(X, Y, Dx, Dy: Integer): Boolean;
var
  M, MinW, MinH: Integer;
  D: TaControlDef;
  Box: TLBox;
begin
  Result := False;
  if FSelected = nil then Exit;
  M := EdgeMode(X, Y, FSelected.Width, FSelected.Height, EdgeBand);
  if M = 0 then Exit;
  D := DefOf(FSelected);
  PushUndo;
  MinW := 8; MinH := 8;
  Box.L := D.Left; Box.T := D.Top; Box.W := D.Width; Box.H := D.Height;
  Box := ResizeBox(Box, M, Dx, Dy, MinW, MinH, GridStep);
  D.Left := Box.L; D.Top := Box.T; D.Width := Box.W; D.Height := Box.H;
  FSelected.SetBounds(D.Left, D.Top, D.Width, D.Height);
  ShowProps;
  Result := True;
end;

procedure TaReportDesigner.NudgeForTest(Dx, Dy: Integer);
begin
  Nudge(Dx, Dy);
end;

function TaReportDesigner.PropsGridForTest: TValueListEditor;
begin
  Result := FProps;
end;

function TaReportDesigner.ReportDef: TaReportDef;
begin
  Result := FDef;
end;

function TaReportDesigner.AddForTest(const AKind: string; ABand, X, Y: Integer): TControl;
begin
  Result := PlaceItem(AKind, ABand, X, Y);
end;

function TaReportDesigner.ControlOfForTest(AIndex: Integer): TControl;
var
  I, J: Integer;
begin
  Result := nil;
  if AIndex >= FDef.Count then Exit;
  for I := 0 to 6 do
    for J := 0 to FBands[I].ControlCount - 1 do
      if DefOf(FBands[I].Controls[J]) = FDef[AIndex] then Exit(FBands[I].Controls[J]);
end;

procedure TaReportDesigner.AddFieldsClick(Sender: TObject);
var
  F: TStringList;
  I, W: Integer;
  C: TControl;
begin
  F := SourceFields(FSource.Text);
  try
    if F.Count = 0 then begin ShowMessage(Tr('Choose a source (table or query).')); Exit; end;
    W := BandWidth div F.Count;
    if W > 160 then W := 160;
    for I := 0 to F.Count - 1 do
    begin
      C := PlaceItem('Label', SecPageHeader, I * W, 4);
      DefOf(C).Caption := F[I];
      DefOf(C).Bold := True;
      DefOf(C).Width := W - 6;
      ApplyDef(C, True);
      C := PlaceItem('TextBox', SecDetail, I * W, 2);
      DefOf(C).ControlSource := F[I];
      DefOf(C).Width := W - 6;
      ApplyDef(C, True);
    end;
  finally
    F.Free;
  end;
  Select(nil);
end;

procedure TaReportDesigner.PreviewClick(Sender: TObject);
var
  D2: TaReportDef;
begin
  if not Save then Exit;
  D2 := TaReportDef.Create;
  try
    D2.FromJson(FDef.ToJson);
    ShowReportPreview(Self, FDb, D2);
  finally
    D2.Free;
  end;
end;

end.
