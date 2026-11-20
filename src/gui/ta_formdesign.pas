unit ta_formdesign;
{ Form designer: palette, drag/resize surface, property editor, undo.
  PageControl (TabControl) acts as a container: click a page with a palette
  item selected to drop the control onto that page. Works on the same TaFormDef
  the runtime uses. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, ExtCtrls, StdCtrls, ComCtrls, Grids, ValEdit,
  Graphics, LCLType, LCLIntf, Math, Menus, contnrs, ZDataset, ta_layout, ta_meta, ta_types, ta_dict, ta_formdef, ta_controls, ta_expr,
  ta_formrun, ta_wizardgen, ta_exprbuilder, ta_propedit, ta_propdlgs, ta_editdlg, ta_calcdlg, ta_modeditor, ta_icons, ta_anchoreditor, ta_propclass, ta_family, ta_famctl;

type

  { TaFormDesigner }

  TaFormDesigner = class(TForm)
  private
    FDb: TAppDb;
    FDef: TaFormDef;
    FSurface: TPanel;
    FBands: array[0..2] of TShape;   { zaglavlje, detalj, podnozje neprekidne forme (graficke kontrole, da ih ne prekrivaju) }
    FBandCaps: array[0..2] of TLabel;
    FShifted: Boolean;               { kontrole su u prostoru odjeljaka (Top od vrha forme) }
    FSelected: TControl;
    FMulti: TList;                 { dodatno odabrane kontrole (Ctrl+klik) }
    FMultiRings: TList;            { okviri oko njih }
    FLayoutMenu: TPopupMenu;
    FGroup: TList;                 { ostale odabrane kontrole pri povlacenju }
    FGroupOrig: array of TPoint;
    FDictMeta: TaFieldMeta;
    FRing: TShape;
    FGrips: array[0..7] of TShape;   { osam rucki oko odabrane kontrole, kao u Lazarusu }
    FResizeMode: Integer;            { koji rubovi se vuku (gmLeft...) }
    FResizeTimer: TTimer;            { prati pokazivac dok se vuce rub (dogadaji pomaka ne stizu izvan kontrole) }
    FPalette: TListBox;
    FProps: TValueListEditor;
    FSource: TComboBox;
    FCaption: TEdit;
    FStatus: TLabel;
    FUndo: TStringList;
    FDragging, FResizing, FLoadingProps: Boolean;
    FDragStart: TPoint;
    FOrig: TRect;
    FDragUndoPushed: Boolean;
    FDragCtl: TControl;            { kontrola koju se hvata misem }
    FLasso, FLassoAdd, FLassoUseTo: Boolean;   { povlacenje okvira za odabir }
    FLassoShape: TShape;
    FLassoPrev: TList;
    FLassoTo: TPoint;
    FWEdit, FHEdit: TEdit;
    FFormGrips: array[0..2] of TShape;   { desni rub, donji rub, kut: povlacenjem se mijenja velicina forme }
    FFormResizing: Boolean;
    FRelayouting: Boolean;
    FFormMode: Integer;                  { 1 = sirina, 2 = visina, 3 = oboje }
    FFormOrigW, FFormOrigH: Integer;
    FFormUndoPushed: Boolean;
    procedure FormGripDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure PlaceFormGrips;
    procedure ApplySurfaceSize;
    procedure CollectLayoutControls(AParent: TWinControl; AList: TList);
    procedure RelayoutAll;
    procedure DesignerShown(Sender: TObject);
    procedure FormResizeTo(Dx, Dy: Integer);
    procedure DragTo(Dx, Dy: Integer);
    procedure MoveToContainer(C: TControl; ATarget: TWinControl);
    procedure FinishDragDrop;
    procedure LassoTick;
    procedure LassoEnd;
    procedure CopySelection(ATo: TList);
    procedure SizeEdited(Sender: TObject);
    procedure SyncSizeEdits;
    procedure HideGrips;
    procedure PlaceGrips(C: TControl);
    function IsGrip(C: TObject): Boolean;
    procedure GripDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure GripMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure GripUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure BeginResize(AMode: Integer);
    procedure EndResize;
    procedure ResizeTick(Sender: TObject);
    procedure ResizeTo(Dx, Dy: Integer);
    procedure ResizeBy(Dw, Dh: Integer);
    procedure BuildUi;
    procedure BuildFromDef;
    procedure ShiftToBands(AForward: Boolean);
    procedure EnterContinuous;
    procedure UpdateBands;
    procedure ClearSurface;
    function PlaceControl(const AKind: string; X, Y: Integer; AParent: TWinControl;
      const AContainer: string; APage: Integer): TControl;
    function MakeControl(D: TaControlDef): TControl;
    procedure HookControl(C: TControl);
    procedure HookTabs(T: TaTabControl);
    procedure Select(C: TControl);
    procedure UpdateRing;
    procedure ShowProps;
    procedure ApplyProp(const AKey, AValue: string);
    procedure NewEventMacro(const AKey: string);
    procedure AsyncNewMacro(Data: PtrInt);
    procedure Reparent(C: TControl);
    function ContainerOf(C: TControl): TaTabControl;
    function ContainerParent(const AName: string; APage: Integer): TWinControl;
    procedure SurfaceMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure ContainerDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure CtlMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure CtlMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure CtlMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure PropValidate(Sender: TObject; ACol, ARow: Longint; const KeyName, KeyValue: string);
    procedure PropValidateEntry(Sender: TObject; aCol, aRow: Integer; const OldValue: string; var NewValue: string);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    function Save: Boolean;
    procedure SaveClick(Sender: TObject);
    procedure DeleteClick(Sender: TObject);
    procedure AddFieldsClick(Sender: TObject);
    procedure PreviewClick(Sender: TObject);
    procedure UndoClick(Sender: TObject);
    procedure DuplicateClick(Sender: TObject);
    procedure AsyncNewPropClass(Data: PtrInt);
    procedure RebuildFamily;
    procedure SaveGroup;
    procedure InsertGroup;
    procedure ExprClick(Sender: TObject);
    procedure PropButton(Sender: TObject);
    procedure PaletteDraw(Control: TWinControl; Index: Integer; ARect: TRect; State: TOwnerDrawState);
    procedure LayoutMenuClick(Sender: TObject);
    procedure LayoutButtonClick(Sender: TObject);
    procedure DoLayout(AOp: TLayoutOp);
    procedure ZOrder(AToFront: Boolean);
    procedure SelectAll;
    procedure ClearMulti;
    procedure ToggleMulti(C: TControl);
    function SelectionList: TList;
    procedure ConfigureFor(D: TaControlDef);
    procedure AddCalcField;
    procedure SourceEdited(Sender: TObject);
    procedure PushUndo;
    procedure DoUndo;
    procedure DeleteSelected;
    procedure Duplicate;
    procedure Nudge(Dx, Dy: Integer);
    function Snap(V: Integer): Integer;
    function TypingInEditor: Boolean;
  public
    constructor CreateDesigner(AOwner: TComponent; ADb: TAppDb; ADef: TaFormDef);
    destructor Destroy; override;
    { for tests }
    function AddForTest(const AKind: string; X, Y: Integer): TControl;
    procedure ToggleMultiForTest(C: TControl);
    procedure LayoutForTest(AOp: TLayoutOp);
    procedure ZOrderForTest(AToFront: Boolean);
    function FormDef: TaFormDef;
    { JSON za spremanje i pregled: u neprekidnoj formi kontrole dobivaju Section i Top unutar odjeljka }
    function NormalizedJson: string;
    function SaveForTest: Boolean;
    function ControlOfForTest(AIndex: Integer): TControl;
    function PropsGrid: TValueListEditor;
    procedure SetPropForTest(const AKey, AValue: string);
    procedure TypeInGridForTest(const AKey, AValue: string);
    { vuce rucku AGrip (0..7) za (Dx, Dy) piksela odabrane kontrole, kao misem }
    procedure GripDragForTest(AGrip, Dx, Dy: Integer);
    function GripForTest(AGrip: Integer): TControl;
    function EdgeDragForTest(X, Y, Dx, Dy: Integer): Boolean;
    procedure LassoForTest(const AFrom, ATo: TPoint; AAdd: Boolean);
    procedure GroupDragForTest(C: TControl; Dx, Dy: Integer);
    function SelectedCountForTest: Integer;
    procedure SetFormSizeForTest(W, H: Integer);
    { povlacenje hvatista forme: 1 = sirina, 2 = visina, 3 = oboje; Dx, Dy u pikselima }
    procedure FormResizeDragForTest(AMode, Dx, Dy: Integer);
    function FormGripForTest(AIndex: Integer): TShape;
    procedure ResizeByForTest(Dw, Dh: Integer);
    procedure UndoForTest;
    function AddInContainerForTest(const AKind, AContainer: string; APage: Integer): TControl;
    procedure SelectForTest(C: TControl);
    procedure MoveToContainerForTest(C: TControl; const AContainer: string);
    procedure DeleteForTest;
    property Def: TaFormDef read FDef;
  end;

implementation

uses
  ta_i18n;




function MakeBox(L, T, W, H: Integer): TLBox;
begin
  Result.L := L; Result.T := T; Result.W := W; Result.H := H;
end;

{ najmanja velicina: crte i prijelomi mogu biti tanki, ostalo ne manje od 8 x 8 }
procedure MinSizeFor(D: TaControlDef; out AMinW, AMinH: Integer);
begin
  AMinW := 8; AMinH := 8;
  if (D <> nil) and ((D.Kind = 'Line') or (D.Kind = 'PageBreak') or (D.Kind = 'Rectangle')) then
  begin
    AMinW := 1; AMinH := 1;
  end;
end;

type
  { pristup zasticenom uredjivacu celije (za testove) }
  TGridHack = class(TValueListEditor)
  public
    property Editor;
  end;

  { publishes the protected mouse events so they can be hooked on any control }
  TControlHack = class(TControl)
  public
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
  end;

const
  FormProps: array[0..43] of string = (
    'Source', 'View', 'Title', 'Filter', 'OrderBy', 'Width', 'Height', 'AllowEdits', 'AllowAdds', 'AllowDeletes',
    'CalcFields', 'AutoFill', 'GridFormat', 'CalcRules', 'OnOpen', 'OnCurrent', 'BeforeUpdate', 'AfterUpdate', 'BeforeDelete', 'OnClose',
    'Resizable', 'CanMinimize', 'CanMaximize', 'StartMaximized', 'ExclusiveGroup', 'DocTypeField', 'DocNumberField',
    'HeaderHeight', 'RowHeight', 'FooterHeight', 'GridLov',
    'BeforeInsert', 'AfterInsert', 'AfterDelete', 'OnError', 'AfterQuery',
    'FieldOnEnter', 'FieldOnExit', 'FieldOnValidate', 'FieldOnKey', 'SubDatasheet', 'Board', 'Dash', 'Timeline');
  GridStep = 4;
  HandleSize = 8;
  EdgeBand = 4;                   { debljina ruba kontrole u kojem se vuce velicina }
  MaxUndo = 60;

constructor TaFormDesigner.CreateDesigner(AOwner: TComponent; ADb: TAppDb; ADef: TaFormDef);
begin
  inherited CreateNew(AOwner);
  FDb := ADb;
  FDef := ADef;
  FUndo := TStringList.Create;
  FMulti := TList.Create;
  FLassoPrev := TList.Create;
  FGroup := TList.Create;
  FMultiRings := TList.Create;
  Caption := Tr('Form design: ') + FDef.Name;
  SetBounds(0, 0, 1260, 760);
  Position := poScreenCenter;
  KeyPreview := True;
  OnKeyDown := @FormKeyDown;
  OnShow := @DesignerShown;
  BuildUi;
  BuildFromDef;
  ShowProps;
end;

destructor TaFormDesigner.Destroy;
begin
  FDictMeta.Free;
  FMulti.Free;
  FLassoPrev.Free;
  FGroup.Free;
  FMultiRings.Free;
  FUndo.Free;
  FDef.Free;
  inherited Destroy;
end;

function TaFormDesigner.Snap(V: Integer): Integer;
begin
  Result := (V + GridStep div 2) div GridStep * GridStep;
  if Result < 0 then Result := 0;
end;

function TaFormDesigner.TypingInEditor: Boolean;
begin
  Result := (ActiveControl is TCustomEdit) or (ActiveControl is TCustomComboBox) or
            (ActiveControl = FProps) or (ActiveControl is TCustomGrid);
end;

procedure TaFormDesigner.BuildUi;
var
  Tb, Rt: TPanel;
  L: TLabel;
  Sb: TScrollBox;
  Tables: TStringList;
  I, X: Integer;

  procedure Btn(const ACap: string; AW: Integer; AH: TNotifyEvent);
  var
    Ic: string;
  begin
    Ic := ToolIconFor(ACap);
    AW := Canvas.TextWidth(ACap) + 22 + Ord(Ic <> '') * 22;
    MakeToolBtn(Tb, ACap, Ic, X, 6, AW, 26, AH);
    Inc(X, AW + 4);
  end;

begin
  Tb := TPanel.Create(Self);
  Tb.Parent := Self;
  Tb.Align := alTop;
  Tb.Height := 38;
  Tb.BevelOuter := bvNone;
  X := 6;
  Btn(Tr('Save'), 62, @SaveClick);
  Btn(Tr('Preview'), 66, @PreviewClick);
  Btn(Tr('Undo'), 62, @UndoClick);
  Btn(Tr('Duplicate'), 78, @DuplicateClick);
  Btn(Tr('Delete'), 54, @DeleteClick);
  Btn(Tr('Align') + ' ▾', 84, @LayoutButtonClick);
  Btn(Tr('Expression...'), 66, @ExprClick);
  Btn(Tr('Add all fields'), 108, @AddFieldsClick);
  L := TLabel.Create(Self); L.Parent := Tb; L.Caption := Tr('Source:'); L.SetBounds(X + 6, 12, 40, 18);
  FSource := TComboBox.Create(Self);
  FSource.Parent := Tb;
  FSource.SetBounds(X + 48, 6, 170, 26);
  Tables := FDb.UserTables;
  try
    for I := 0 to Tables.Count - 1 do FSource.Items.Add(Tables[I]);
  finally
    Tables.Free;
  end;
  Tables := FDb.ListObjects('_sys_queries');
  try
    for I := 0 to Tables.Count - 1 do FSource.Items.Add(Tables[I]);
  finally
    Tables.Free;
  end;
  FSource.Text := FDef.RecordSource;
  FSource.OnEditingDone := @SourceEdited;
  FSource.OnChange := @SourceEdited;
  Inc(X, 230);
  L := TLabel.Create(Self); L.Parent := Tb; L.Caption := Tr('Title:'); L.SetBounds(X, 12, 50, 18);
  FCaption := TEdit.Create(Self);
  FCaption.Parent := Tb;
  FCaption.SetBounds(X + 52, 6, 200, 26);
  FCaption.Text := FDef.Caption;
  FCaption.OnChange := @SourceEdited;

  Tb := TPanel.Create(Self);
  Tb.Parent := Self;
  Tb.Align := alTop;
  Tb.Height := 36;
  Tb.BevelOuter := bvNone;
  Tb.Top := 40;
  L := TLabel.Create(Self); L.Parent := Tb; L.Caption := Tr('Form size (px):'); L.SetBounds(8, 10, 190, 18);
  FWEdit := TEdit.Create(Self); FWEdit.Parent := Tb; FWEdit.SetBounds(204, 5, 64, 26);
  L := TLabel.Create(Self); L.Parent := Tb; L.Caption := '×'; L.SetBounds(274, 10, 14, 18);
  FHEdit := TEdit.Create(Self); FHEdit.Parent := Tb; FHEdit.SetBounds(290, 5, 64, 26);
  FWEdit.Text := IntToStr(FDef.Width); FHEdit.Text := IntToStr(FDef.Height);
  FWEdit.OnEditingDone := @SizeEdited; FHEdit.OnEditingDone := @SizeEdited;
  L := TLabel.Create(Self); L.Parent := Tb;
  L.Caption := Tr('Drag a frame over an empty area = select several controls, Ctrl+click adds, Ctrl+A = all, arrows move, Shift+arrows resize');
  L.SetBounds(372, 10, 900, 18); L.Font.Color := clGray;

  FPalette := TListBox.Create(Self);
  FPalette.Parent := Self;
  FPalette.Align := alLeft;
  FPalette.Width := 140;
  FPalette.Style := lbOwnerDrawFixed;
  FPalette.ItemHeight := 24;
  FPalette.OnDrawItem := @PaletteDraw;
  for I := 0 to High(KindNames) do FPalette.Items.Add(KindNames[I]);
  FPalette.ItemIndex := -1;

  Rt := TPanel.Create(Self);
  Rt.Parent := Self;
  Rt.Align := alRight;
  Rt.Width := 300;
  Rt.BevelOuter := bvNone;
  FStatus := TLabel.Create(Self);
  FStatus.Parent := Rt;
  FStatus.Align := alBottom;
  FStatus.WordWrap := True;
  FStatus.Height := 44;
  FStatus.Font.Color := clMaroon;
  FProps := TValueListEditor.Create(Self);
  FProps.Parent := Rt;
  FProps.Align := alClient;
  FProps.OnValidateEntry := @PropValidateEntry;
  FProps.OnEditButtonClick := @PropButton;

  Sb := TScrollBox.Create(Self);
  Sb.Parent := Self;
  Sb.Align := alClient;
  FSurface := TPanel.Create(Self);
  FSurface.Parent := Sb;
  ApplySurfaceSize;
  FSurface.BevelOuter := bvNone;
  FSurface.Color := clWhite;
  FSurface.OnMouseDown := @SurfaceMouseDown;
  FLassoShape := TShape.Create(Self);
  FLassoShape.Parent := FSurface;
  FLassoShape.Brush.Style := bsClear;
  FLassoShape.Pen.Color := clBlue;
  FLassoShape.Pen.Style := psDash;
  FLassoShape.Visible := False;
  FLassoShape.Enabled := False;
  for I := 0 to 2 do
  begin
    FFormGrips[I] := TShape.Create(Self);
    FFormGrips[I].Parent := Sb;
    FFormGrips[I].Shape := stRectangle;
    FFormGrips[I].Brush.Color := $B07030;
    FFormGrips[I].Pen.Color := clWhite;
    FFormGrips[I].Tag := I + 1;
    FFormGrips[I].Hint := Tr('Drag to resize the form');
    FFormGrips[I].ShowHint := True;
    case I of
      0: FFormGrips[I].Cursor := crSizeWE;
      1: FFormGrips[I].Cursor := crSizeNS;
    else FFormGrips[I].Cursor := crSizeNWSE;
    end;
    FFormGrips[I].OnMouseDown := @FormGripDown;
  end;
  PlaceFormGrips;

  FRing := TShape.Create(Self);
  FRing.Shape := stRectangle;
  FRing.Brush.Color := clBlue;
  FRing.Pen.Color := clBlue;
  FRing.Visible := False;
  for I := 0 to 7 do
  begin
    FGrips[I] := TShape.Create(Self);
    FGrips[I].Shape := stRectangle;
    FGrips[I].Brush.Color := clNavy;
    FGrips[I].Pen.Color := clWhite;
    FGrips[I].Visible := False;
    FGrips[I].Tag := I;
    FGrips[I].Name := 'grip' + IntToStr(I);
    case I of
      0, 4: FGrips[I].Cursor := crSizeNWSE;
      2, 6: FGrips[I].Cursor := crSizeNESW;
      1, 5: FGrips[I].Cursor := crSizeNS;
    else
      FGrips[I].Cursor := crSizeWE;
    end;
    FGrips[I].OnMouseDown := @GripDown;
    FGrips[I].OnMouseMove := @GripMove;
    FGrips[I].OnMouseUp := @GripUp;
  end;
  FResizeTimer := TTimer.Create(Self);
  FResizeTimer.Enabled := False;
  FResizeTimer.Interval := 20;
  FResizeTimer.OnTimer := @ResizeTick;
end;

procedure TaFormDesigner.SourceEdited(Sender: TObject);
begin
  FDef.RecordSource := Trim(FSource.Text);
  FDef.Caption := FCaption.Text;
end;

{ ---------------- building the surface ---------------- }

procedure TaFormDesigner.HookControl(C: TControl);
begin
  if C is TaFamilyHost then
  begin
    FamilyHookMouse(C, @CtlMouseDown, @CtlMouseMove, @CtlMouseUp);
    Exit;
  end;
  TControlHack(C).OnMouseDown := @CtlMouseDown;
  TControlHack(C).OnMouseMove := @CtlMouseMove;
  TControlHack(C).OnMouseUp := @CtlMouseUp;
end;

procedure TaFormDesigner.HookTabs(T: TaTabControl);
var
  I: Integer;
begin
  for I := 0 to T.PageCount - 1 do
    TControlHack(T.Pages[I]).OnMouseDown := @ContainerDown;
end;

function TaFormDesigner.ContainerParent(const AName: string; APage: Integer): TWinControl;
var
  I, Pg: Integer;
  Cmp: TComponent;
begin
  Result := nil;
  for I := 0 to FSurface.ComponentCount - 1 do
  begin
    Cmp := FSurface.Components[I];
    if (Cmp is TaTabControl) and SameText(TaTabControl(Cmp).Def.Name, AName) then
    begin
      Pg := APage;
      if Pg < 0 then Pg := 0;
      if Pg >= TaTabControl(Cmp).PageCount then Pg := TaTabControl(Cmp).PageCount - 1;
      Exit(TaTabControl(Cmp).Pages[Pg]);
    end;
    if (Cmp is TControl) and FamilyIsContainer(TControl(Cmp)) and (DefOf(TControl(Cmp)) <> nil) and
       SameText(DefOf(TControl(Cmp)).Name, AName) then
      Exit(TWinControl(Cmp));
  end;
end;

function TaFormDesigner.MakeControl(D: TaControlDef): TControl;
var
  Par: TWinControl;
begin
  Par := FSurface;
  if D.GetX('container') <> '' then
  begin
    { the container must already exist }
    Par := ContainerParent(D.GetX('container'), StrToIntDef(D.GetX('page'), 0));
    if Par = nil then Exit(nil);
  end;
  Result := nil;
  { obitelji kontrola (kao u izvrsitelju); stare kontrole za ostalo }
  Result := FamilyControlFor(FSurface, Par, D, True);
  if Result = nil then
  begin
    Result := CreateAccessControl(FSurface, Par, D);
    ApplyDef(Result, True);
  end;
  HookControl(Result);
  if Result is TaTabControl then HookTabs(TaTabControl(Result));
  if Par is TaFamilyHost then FamilyShowPages(Par);
end;

procedure TaFormDesigner.BuildFromDef;
var
  I, Pass, Made: Integer;
  Done: array of Boolean;
begin
  if (FDef.ViewMode = 'continuous') and not FShifted then
  begin
    if FDef.HeaderHeight <= 0 then FDef.HeaderHeight := 56;
    if FDef.RowHeight <= 0 then FDef.RowHeight := 34;
    if FDef.FooterHeight <= 0 then FDef.FooterHeight := 40;
    ShiftToBands(True);
  end;
  SetLength(Done, FDef.Count);
  for Pass := 1 to 4 do
  begin
    Made := 0;
    for I := 0 to FDef.Count - 1 do
    begin
      if Done[I] then Continue;
      if MakeControl(FDef[I]) <> nil then
      begin
        Done[I] := True;
        Inc(Made);
      end;
    end;
    if Made = 0 then Break;
  end;
  UpdateBands;
  ApplySurfaceSize;
end;

{ neprekidna forma: u definiciji Top je unutar svog odjeljka, a na povrsini dizajna odjeljci su jedan ispod drugog }
procedure TaFormDesigner.ShiftToBands(AForward: Boolean);
var
  I: Integer;
  D: TaControlDef;
  Off: Integer;
begin
  for I := 0 to FDef.Count - 1 do
  begin
    D := FDef[I];
    if SameText(D.Section, 'detail') then Off := FDef.HeaderHeight
    else if SameText(D.Section, 'footer') then Off := FDef.HeaderHeight + FDef.RowHeight
    else Off := 0;
    if AForward then D.Top := D.Top + Off;
  end;
  FShifted := AForward;
end;

procedure TaFormDesigner.EnterContinuous;
begin
  if FDef.ViewMode = 'continuous' then
  begin
    if FDef.HeaderHeight <= 0 then FDef.HeaderHeight := 56;
    if FDef.RowHeight <= 0 then FDef.RowHeight := 34;
    if FDef.FooterHeight <= 0 then FDef.FooterHeight := 40;
    { kontrole koje su vec na povrsini ostaju gdje jesu: korisnik ih rasporedi po odjeljcima }
    FShifted := True;
  end
  else FShifted := False;
  UpdateBands;
end;

procedure TaFormDesigner.UpdateBands;
const
  Caps: array[0..2] of string = ('Zaglavlje forme', 'Detalj (jedan zapis, ponavlja se)', 'Podnožje forme');
var
  I, Y, H: Integer;
begin
  for I := 0 to 2 do
    if FBands[I] <> nil then begin FBands[I].Visible := False; FBandCaps[I].Visible := False; end;
  if FDef.ViewMode <> 'continuous' then Exit;
  if FDef.Height < FDef.HeaderHeight + FDef.RowHeight + FDef.FooterHeight then
    FDef.Height := FDef.HeaderHeight + FDef.RowHeight + FDef.FooterHeight;
  Y := 0;
  for I := 0 to 2 do
  begin
    case I of
      0: H := FDef.HeaderHeight;
      1: H := FDef.RowHeight;
    else
      H := FDef.FooterHeight;
    end;
    if FBands[I] = nil then
    begin
      FBands[I] := TShape.Create(Self);
      FBands[I].Parent := FSurface;
      FBands[I].Shape := stRectangle;
      FBands[I].Pen.Style := psClear;
      FBands[I].OnMouseDown := @SurfaceMouseDown;
      FBandCaps[I] := TLabel.Create(Self);
      FBandCaps[I].Parent := FSurface;
      FBandCaps[I].Caption := Tr(Caps[I]);
      FBandCaps[I].Font.Color := clGray;
      FBandCaps[I].Font.Size := 7;
      FBandCaps[I].OnMouseDown := @SurfaceMouseDown;
    end;
    case I of
      0: FBands[I].Brush.Color := RGBToColor(235, 240, 250);
      1: FBands[I].Brush.Color := RGBToColor(255, 255, 255);
    else
      FBands[I].Brush.Color := RGBToColor(240, 245, 235);
    end;
    FBands[I].SetBounds(0, Y, FSurface.Width, H);
    FBandCaps[I].SetBounds(FSurface.Width - 190, Y + H - 14, 188, 12);
    FBandCaps[I].SendToBack;
    FBands[I].SendToBack;
    FBandCaps[I].Visible := True;
    FBands[I].Visible := True;
    Inc(Y, H);
  end;
end;

function TaFormDesigner.SaveForTest: Boolean;
begin
  Result := Save;
end;

function TaFormDesigner.NormalizedJson: string;
var
  C: TaFormDef;
  I, H, R, Mid: Integer;
  D: TaControlDef;
begin
  if FDef.ViewMode <> 'continuous' then Exit(FDef.ToJson);
  C := TaFormDef.Create;
  try
    C.FromJson(FDef.ToJson);
    H := C.HeaderHeight;
    R := C.RowHeight;
    for I := 0 to C.Count - 1 do
    begin
      D := C[I];
      Mid := D.Top + D.Height div 2;
      if Mid < H then
        D.Section := 'header'
      else if Mid < H + R then
      begin
        D.Section := 'detail';
        D.Top := D.Top - H;
      end
      else
      begin
        D.Section := 'footer';
        D.Top := D.Top - H - R;
      end;
      if D.Top < 0 then D.Top := 0;
    end;
    Result := C.ToJson;
  finally
    C.Free;
  end;
end;

procedure TaFormDesigner.ClearSurface;
var
  I: Integer;
begin
  FSelected := nil;
  FMulti.Clear;
  for I := 0 to FMultiRings.Count - 1 do
  begin
    TShape(FMultiRings[I]).Visible := False;
    TShape(FMultiRings[I]).Parent := nil;
  end;
  FRing.Visible := False;
  HideGrips;
  FRing.Parent := nil;
  for I := 0 to 7 do FGrips[I].Parent := nil;
  for I := FSurface.ComponentCount - 1 downto 0 do FSurface.Components[I].Free;
end;

function TaFormDesigner.PlaceControl(const AKind: string; X, Y: Integer; AParent: TWinControl;
  const AContainer: string; APage: Integer): TControl;
var
  D: TaControlDef;
begin
  PushUndo;
  D := TaControlDef.Create;
  D.Kind := AKind;
  D.Name := FDef.UniqueName(AKind);
  D.Left := X;
  D.Top := Y;
  DefaultSize(AKind, D.Width, D.Height);
  if (AKind = 'Label') or (AKind = 'Button') or (AKind = 'CheckBox') or (AKind = 'ToggleButton') or
     (AKind = 'Hyperlink') or (AKind = 'OptionGroup') then D.Caption := D.Name;
  if (AKind = 'TabControl') or (AKind = 'Pages') then D.RowSource := 'Stranica 1;Stranica 2';
  if AKind = 'OptionGroup' then D.RowSource := '1=Opcija 1;2=Opcija 2';
  if AContainer <> '' then
  begin
    D.SetX('container', AContainer);
    D.SetX('page', IntToStr(APage));
  end;
  FDef.Add(D);
  Result := MakeControl(D);
  if Result = nil then
  begin
    FDef.Delete(D);
    Exit;
  end;
  Select(Result);
end;

function TaFormDesigner.PropsGrid: TValueListEditor;
begin
  Result := FProps;
end;

procedure TaFormDesigner.TypeInGridForTest(const AKey, AValue: string);
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
      if TGridHack(FProps).Editor is TCustomEdit then TCustomEdit(TGridHack(FProps).Editor).Text := AValue;
      { odlazak u drugi redak zavrsava uredjivanje kao Enter ili klik }
      if R < FProps.RowCount - 1 then FProps.Row := R + 1 else FProps.Row := R - 1;
      Application.ProcessMessages;
      Exit;
    end;
end;

procedure TaFormDesigner.GripDragForTest(AGrip, Dx, Dy: Integer);
begin
  if FSelected = nil then Exit;
  BeginResize(GripMode(AGrip));
  ResizeTo(Dx, Dy);
  FResizing := False;
  ShowProps;
end;

function TaFormDesigner.GripForTest(AGrip: Integer): TControl;
begin
  Result := FGrips[AGrip];
end;

{ povlacenje samog ruba kontrole (X, Y unutar kontrole) }
function TaFormDesigner.EdgeDragForTest(X, Y, Dx, Dy: Integer): Boolean;
var
  M: Integer;
begin
  Result := False;
  if FSelected = nil then Exit;
  M := EdgeMode(X, Y, FSelected.Width, FSelected.Height, EdgeBand);
  if M = 0 then Exit;
  BeginResize(M);
  ResizeTo(Dx, Dy);
  FResizing := False;
  ShowProps;
  Result := True;
end;

procedure TaFormDesigner.ResizeByForTest(Dw, Dh: Integer);
begin
  ResizeBy(Dw, Dh);
end;

procedure TaFormDesigner.SetPropForTest(const AKey, AValue: string);
begin
  ApplyProp(AKey, AValue);
  ShowProps;
end;

function TaFormDesigner.AddForTest(const AKind: string; X, Y: Integer): TControl;
begin
  Result := PlaceControl(AKind, X, Y, FSurface, '', 0);
end;

function TaFormDesigner.AddInContainerForTest(const AKind, AContainer: string; APage: Integer): TControl;
var
  Par: TWinControl;
begin
  Result := nil;
  Par := ContainerParent(AContainer, APage);
  if Par <> nil then Result := PlaceControl(AKind, 8, 8, Par, AContainer, APage);
end;

procedure TaFormDesigner.MoveToContainerForTest(C: TControl; const AContainer: string);
begin
  if AContainer = '' then MoveToContainer(C, nil) else MoveToContainer(C, ContainerParent(AContainer, 0));
end;

procedure TaFormDesigner.SelectForTest(C: TControl);
begin
  Select(C);
end;

procedure TaFormDesigner.DeleteForTest;
begin
  DeleteSelected;
end;

procedure TaFormDesigner.UndoForTest;
begin
  DoUndo;
end;

{ ---------------- selection ---------------- }

procedure TaFormDesigner.HideGrips;
var
  I: Integer;
begin
  for I := 0 to 7 do FGrips[I].Visible := False;
end;

function TaFormDesigner.IsGrip(C: TObject): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to 7 do
    if C = FGrips[I] then Exit(True);
end;

{ osam rucki: uglovi i sredine stranica, malo izvan kontrole }
procedure TaFormDesigner.PlaceGrips(C: TControl);
const
  Sz = 7;
var
  I, X, Y, Mx, My: Integer;
begin
  Mx := C.Left + C.Width div 2 - Sz div 2;
  My := C.Top + C.Height div 2 - Sz div 2;
  for I := 0 to 7 do
  begin
    case I of
      0: begin X := C.Left - Sz - 1; Y := C.Top - Sz - 1; end;
      1: begin X := Mx; Y := C.Top - Sz - 1; end;
      2: begin X := C.Left + C.Width + 1; Y := C.Top - Sz - 1; end;
      3: begin X := C.Left + C.Width + 1; Y := My; end;
      4: begin X := C.Left + C.Width + 1; Y := C.Top + C.Height + 1; end;
      5: begin X := Mx; Y := C.Top + C.Height + 1; end;
      6: begin X := C.Left - Sz - 1; Y := C.Top + C.Height + 1; end;
    else
      begin X := C.Left - Sz - 1; Y := My; end;
    end;
    FGrips[I].Parent := C.Parent;
    FGrips[I].SetBounds(X, Y, Sz, Sz);
    FGrips[I].Visible := True;
    FGrips[I].BringToFront;
  end;
end;

procedure TaFormDesigner.UpdateRing;
var
  C: TControl;
  I: Integer;
  Sh: TShape;
begin
  { okviri oko dodatno odabranih kontrola }
  while FMultiRings.Count < FMulti.Count do
  begin
    Sh := TShape.Create(Self);
    Sh.Brush.Style := bsClear;
    Sh.Pen.Color := clBlue;
    Sh.Pen.Style := psDot;
    Sh.Visible := False;
    FMultiRings.Add(Sh);
  end;
  for I := 0 to FMultiRings.Count - 1 do
  begin
    Sh := TShape(FMultiRings[I]);
    if I < FMulti.Count then
    begin
      C := TControl(FMulti[I]);
      Sh.Parent := C.Parent;
      Sh.SetBounds(C.Left - 2, C.Top - 2, C.Width + 4, C.Height + 4);
      Sh.Visible := True;
      Sh.SendToBack;
    end
    else Sh.Visible := False;
  end;
  C := FSelected;
  if (C = nil) or (C.Parent = nil) then
  begin
    FRing.Visible := False;
    HideGrips;
    Exit;
  end;
  FRing.Parent := C.Parent;
  FRing.SetBounds(C.Left - 2, C.Top - 2, C.Width + 4, C.Height + 4);
  FRing.Visible := True;
  FRing.SendToBack;
  PlaceGrips(C);
end;

procedure TaFormDesigner.Select(C: TControl);
begin
  ClearMulti;
  FSelected := C;
  UpdateRing;
  ShowProps;
end;

function TaFormDesigner.ContainerOf(C: TControl): TaTabControl;
begin
  Result := nil;
  if (C.Parent is TTabSheet) and (TTabSheet(C.Parent).Parent is TaTabControl) then
    Result := TaTabControl(TTabSheet(C.Parent).Parent);
end;

procedure TaFormDesigner.ShowProps;
var
  D: TaControlDef;
  I: Integer;
  Names: TStringList;
  V: string;
begin
  FLoadingProps := True;
  try
    FProps.Strings.Clear;
    FStatus.Caption := '';
    if FSelected = nil then
    begin
      for I := 0 to High(FormProps) do
      begin
        case I of
          0: V := FDef.RecordSource;
          1: V := FDef.ViewMode;
          2: V := FDef.Caption;
          3: V := FDef.Filter;
          4: V := FDef.OrderBy;
          5: V := IntToStr(FDef.Width);
          6: V := IntToStr(FDef.Height);
          7: V := BoolToStr(FDef.AllowEdits, 'True', 'False');
          8: V := BoolToStr(FDef.AllowAdds, 'True', 'False');
          9: V := BoolToStr(FDef.AllowDeletes, 'True', 'False');
          10: V := FDef.CalcFields;
          11: V := FDef.AutoFill;
          12: V := FDef.GridFormat;
          13: V := FDef.CalcRules;
          20: V := BoolToStr(FDef.Resizable, 'True', 'False');
          21: V := BoolToStr(FDef.CanMinimize, 'True', 'False');
          22: V := BoolToStr(FDef.CanMaximize, 'True', 'False');
          23: V := BoolToStr(FDef.StartMaximized, 'True', 'False');
          24: V := FDef.ExclusiveGroup;
          25: V := FDef.DocTypeField;
          26: V := FDef.DocNumberField;
          27: V := IntToStr(FDef.HeaderHeight);
          28: V := IntToStr(FDef.RowHeight);
          29: V := IntToStr(FDef.FooterHeight);
          30: V := FDef.GridLov;
          40: V := FDef.SubDatasheet;
          41: V := FDef.Board;
          42: V := FDef.Dash;
          43: V := FDef.Timeline;
        else V := FDef.GetEv(FormProps[I]);
        end;
        FProps.Strings.Add(FormProps[I] + '=' + V);
      end;
      ConfigureFor(nil);
      Exit;
    end;
    D := DefOf(FSelected);
    if D = nil then Exit;
    FreeAndNil(FDictMeta);
    FProps.Strings.Add('Kind=' + D.Kind);
    Names := PropertyNamesFor(D.Kind, False);
    try
      for I := 0 to Names.Count - 1 do
      begin
        if Names[I] = 'FontName' then FProps.Strings.Add('Font=' + FontSummary(D));
        V := DefGet(D, Names[I]);
        { vrijednost koju kontrola nema, a daje je rjecnik podataka: pokazuje se s oznakom "(rjecnik)" i ne upisuje se }
        if (V = '') or (V = 'False') then
        begin
          if FDictMeta = nil then
            if (D.ControlSource <> '') and (D.ControlSource[1] <> '=') and (FDef.RecordSource <> '') then
              FDictMeta := FDb.FindFieldMeta(FDef.RecordSource, D.ControlSource);
          if (FDictMeta <> nil) and (DictValueFor(FDictMeta, Names[I]) <> '') then V := DictInheritedMarker + DictValueFor(FDictMeta, Names[I]);
        end;
        FProps.Strings.Add(Names[I] + '=' + V);
      end;
    finally
      Names.Free;
    end;
    ConfigureFor(D);
  finally
    FLoadingProps := False;
  end;
end;

procedure TaFormDesigner.ConfigureFor(D: TaControlDef);
var
  Ctx: TPropContext;
  Tabs, Sib: TStringList;
  I: Integer;
  K, Rs: string;
begin
  Tabs := TStringList.Create;
  Sib := TStringList.Create;
  try
    for I := 0 to FDef.Count - 1 do
    begin
      if FDef[I].Kind = 'TabControl' then Tabs.Add(FDef[I].Name);
      if FDef[I] <> D then Sib.Add(FDef[I].Name);
    end;
    K := '';
    Rs := '';
    if D <> nil then begin K := D.Kind; Rs := D.RowSource; end;
    FillContext(FDb, Ctx, K, Trim(FSource.Text), Rs, Tabs, Sib);
    try
      ConfigureProps(FProps, Ctx);
    finally
      FreeContext(Ctx);
    end;
  finally
    Tabs.Free;
    Sib.Free;
  end;
end;

{ Gumb ... u retku svojstva: font, boja, slika, pravila ili izraz. }
procedure TaFormDesigner.PaletteDraw(Control: TWinControl; Index: Integer; ARect: TRect; State: TOwnerDrawState);
begin
  DrawIconItem(FPalette, Index, ARect, State, ControlIconName(FPalette.Items[Index]));
end;

procedure TaFormDesigner.PropButton(Sender: TObject);
var
  Key, Cur, Hex: string;
  D: TaControlDef;
  Vals, Names2, Fld: TStringList;
  I: Integer;
  LovVal: Boolean;
begin
  if FProps.Row < 1 then Exit;
  Key := FProps.Cells[0, FProps.Row];
  LovVal := (FSelected <> nil) and (DefOf(FSelected) <> nil) and (DefOf(FSelected).GetX('lovvalidate') = '1');
  D := nil;
  if FSelected <> nil then D := DefOf(FSelected);
  case PropKindOf(Key) of
    pkFont:
      if D <> nil then
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
      if D <> nil then
        if RunColorDialog(Self, DefGet(D, Key), Hex) then begin ApplyProp(Key, Hex); ShowProps; end;
    pkPicture:
      if D <> nil then
        if RunPictureDialog(Self, Cur) then begin ApplyProp('Picture', Cur); ShowProps; end;
    pkItems:
      if D <> nil then
      begin
        Cur := D.RowSource;
        if RunItemsDialog(Self, Cur) then begin ApplyProp('Items', Cur); ShowProps; end;
      end;
    pkIcon:
      if D <> nil then
      begin
        Cur := D.GetX('icon');
        if RunIconDialog(Self, Cur) then begin ApplyProp('Icon', Cur); ShowProps; end;
      end;
    pkAnchors:
      if D <> nil then
      begin
        { jedan uredjivac za Anchors, Dock, BorderSpacing i sidra uz susjede (kao Lazarusov Anchor Editor) }
        Vals := TStringList.Create;
        try
          if RunLayoutDialog(Self, FDef, D, Vals) then
          begin
            for I := 0 to Vals.Count - 1 do ApplyProp(Vals.Names[I], Vals.ValueFromIndex[I]);
            ShowProps;
          end;
        finally
          Vals.Free;
        end;
      end;
  else
    if (Key = 'RowSource') and (D <> nil) and ((D.Kind = 'ComboBox') or (D.Kind = 'ListBox') or (D.Kind = 'OptionGroup') or (D.Kind = 'Chart')) then
    begin
      Cur := DefGet(D, Key);
      if DesignEditSource(Self, FDb, D.Kind, Cur) then begin ApplyProp(Key, Cur); ShowProps; end;
    end
    else if Key = 'OnClick' then
    begin
      if D <> nil then Cur := DefGet(D, Key) else Cur := '';
      { makro blokovima ili graditelj akcija }
      case QuestionDlg('Akcija gumba', Tr('How do you want to compose the button action?'), mtConfirmation,
        [mrYes, 'Makro blokovima', mrNo, 'Graditelj akcija (jedna naredba)', mrCancel, 'Odustani'], 0) of
        mrYes:
          begin
            if Copy(Cur, 1, 6) = 'macro:' then
              EditMacro(Self, FDb, Trim(Copy(Cur, 7, MaxInt)), True)
            else
              NewEventMacro(Key);
            Exit;
          end;
        mrCancel: Exit;
      end;
      Names2 := TStringList.Create;
      try
        for I := 0 to FDef.Count - 1 do Names2.Add(FDef[I].Name);
        if DesignEditAction(Self, FDb, Names2, Cur) then begin ApplyProp(Key, Cur); ShowProps; end;
      finally
        Names2.Free;
      end;
    end
    else if (Key = 'Lov') or (Key = 'LovMap') then
    begin
      if D = nil then Exit;
      Names2 := TStringList.Create;
      try
        for I := 0 to FDef.Count - 1 do
          if (FDef[I].Kind = 'TextBox') or (FDef[I].Kind = 'MemoBox') or (FDef[I].Kind = 'ComboBox') then Names2.Add(FDef[I].Name);
        Cur := DefGet(D, 'Lov');
        Hex := DefGet(D, 'LovMap');
        if RunLovBuilder(Self, FDb, Names2, Cur, Hex, LovVal) then
        begin
          ApplyProp('Lov', Cur);
          ApplyProp('LovMap', Hex);
          if LovVal then ApplyProp('LovValidate', 'True') else ApplyProp('LovValidate', 'False');
          ShowProps;
        end;
      finally
        Names2.Free;
      end;
    end
    else if Key = 'GridLov' then
    begin
      Cur := FDef.GridLov;
      Fld := FieldNamesOf(FDb, Trim(FSource.Text));
      try
        if RunGridLovBuilder(Self, FDb, Fld, Cur) then begin ApplyProp(Key, Cur); ShowProps; end;
      finally
        Fld.Free;
      end;
    end
    else if Key = 'AutoFill' then
    begin
      if D <> nil then Cur := DefGet(D, Key) else Cur := FProps.Cells[1, FProps.Row];
      Names2 := TStringList.Create;
      try
        if (D <> nil) and (D.Kind = 'Subform') then
        begin
          Fld := FieldNamesOf(FDb, D.RowSource);
          try Names2.AddStrings(Fld); finally Fld.Free; end;
        end
        else
        begin
          Fld := FieldNamesOf(FDb, Trim(FSource.Text));
          try Names2.AddStrings(Fld); finally Fld.Free; end;
        end;
        if RunAutoFillBuilder(Self, FDb, Names2, Cur) then begin ApplyProp(Key, Cur); ShowProps; end;
      finally
        Names2.Free;
      end;
    end
    else if Key = 'CalcRules' then
    begin
      if D <> nil then Cur := DefGet(D, Key) else Cur := FProps.Cells[1, FProps.Row];
      Names2 := TStringList.Create;
      try
        if (D <> nil) and (D.Kind = 'Subform') then
        begin
          Fld := FieldNamesOf(FDb, D.RowSource);
          try Names2.AddStrings(Fld); finally Fld.Free; end;
        end
        else
        begin
          Fld := FieldNamesOf(FDb, Trim(FSource.Text));
          try Names2.AddStrings(Fld); finally Fld.Free; end;
        end;
        if DesignEditRule(Self, FDb, Names2, Cur) then begin ApplyProp(Key, Cur); ShowProps; end;
      finally
        Names2.Free;
      end;
    end
    else if (Key = 'CondFormat') or (Key = 'GridFormat') then
    begin
      if D <> nil then Cur := DefGet(D, Key) else Cur := FProps.Cells[1, FProps.Row];
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

procedure TaFormDesigner.Reparent(C: TControl);
var
  D: TaControlDef;
  I, Pg: Integer;
  T: TaTabControl;
  NewParent: TWinControl;
begin
  D := DefOf(C);
  NewParent := FSurface;
  if D.GetX('container') <> '' then
  begin
    NewParent := ContainerParent(D.GetX('container'), StrToIntDef(D.GetX('page'), 0));
    if (NewParent = nil) or (NewParent = C) then
    begin
      NewParent := FSurface;
      D.SetX('container', '');
    end;
  end;
  if C.Parent <> NewParent then C.Parent := NewParent;
  if NewParent is TaFamilyHost then FamilyShowPages(NewParent);
end;

{ dogadaj -> novi makro blokovima: makro se napravi, postavi kao vrijednost i otvori u uredjivacu }
procedure TaFormDesigner.NewEventMacro(const AKey: string);
var
  Nm: string;
begin
  Nm := CreateEventMacro(FDb, FDef.Name, AKey);
  ApplyProp(AKey, 'macro:' + Nm);
  ShowProps;
  EditMacro(Self, FDb, Nm, True);
end;

procedure TaFormDesigner.AsyncNewMacro(Data: PtrInt);
begin
  { Data = indeks retka u mrezi svojstava u trenutku odabira }
  if (Data >= 1) and (Data < FProps.RowCount) then NewEventMacro(FProps.Cells[0, Data]);
end;

procedure TaFormDesigner.ApplyProp(const AKey, AValue: string);
var
  D: TaControlDef;
  Idx: Integer;
  Msg: string;
begin
  { naslijedena vrijednost iz rjecnika nije promjena }
  if (AValue <> '') and (Copy(AValue, 1, Length(DictInheritedMarker)) = DictInheritedMarker) then Exit;
  if AValue = NewPropClassItem then
  begin
    Application.QueueAsyncCall(@AsyncNewPropClass, FProps.Row);
    Exit;
  end;
  if AValue = NewMacroBlocksItem then
  begin
    { odgodi: dijalog se ne smije otvoriti usred uredjivanja celije mreze }
    Application.QueueAsyncCall(@AsyncNewMacro, FProps.Row);
    Exit;
  end;
  if FSelected = nil then
  begin
    PushUndo;
    if AKey = 'Source' then begin FDef.RecordSource := AValue; FSource.Text := AValue; end
    else if AKey = 'View' then
    begin
      FDef.ViewMode := LowerCase(AValue);
      EnterContinuous;
    end
    else if AKey = 'HeaderHeight' then begin FDef.HeaderHeight := StrToIntDef(AValue, FDef.HeaderHeight); UpdateBands; end
    else if AKey = 'RowHeight' then begin FDef.RowHeight := StrToIntDef(AValue, FDef.RowHeight); UpdateBands; end
    else if AKey = 'FooterHeight' then begin FDef.FooterHeight := StrToIntDef(AValue, FDef.FooterHeight); UpdateBands; end
    else if AKey = 'Title' then begin FDef.Caption := AValue; FCaption.Text := AValue; end
    else if AKey = 'Filter' then FDef.Filter := AValue
    else if AKey = 'OrderBy' then FDef.OrderBy := AValue
    else if AKey = 'Width' then FDef.Width := StrToIntDef(AValue, FDef.Width)
    else if AKey = 'Height' then FDef.Height := StrToIntDef(AValue, FDef.Height)
    else if AKey = 'AllowEdits' then FDef.AllowEdits := StrToBoolDef(AValue, True)
    else if AKey = 'AllowAdds' then FDef.AllowAdds := StrToBoolDef(AValue, True)
    else if AKey = 'AllowDeletes' then FDef.AllowDeletes := StrToBoolDef(AValue, True)
    else if AKey = 'Resizable' then FDef.Resizable := StrToBoolDef(AValue, True)
    else if AKey = 'CanMinimize' then FDef.CanMinimize := StrToBoolDef(AValue, True)
    else if AKey = 'CanMaximize' then FDef.CanMaximize := StrToBoolDef(AValue, True)
    else if AKey = 'StartMaximized' then FDef.StartMaximized := StrToBoolDef(AValue, False)
    else if AKey = 'ExclusiveGroup' then FDef.ExclusiveGroup := Trim(AValue)
    else if AKey = 'DocTypeField' then FDef.DocTypeField := Trim(AValue)
    else if AKey = 'DocNumberField' then FDef.DocNumberField := Trim(AValue)
    else if AKey = 'CalcFields' then FDef.CalcFields := AValue
    else if AKey = 'AutoFill' then FDef.AutoFill := AValue
    else if AKey = 'GridFormat' then FDef.GridFormat := AValue
    else if AKey = 'CalcRules' then FDef.CalcRules := AValue
    else if AKey = 'GridLov' then FDef.GridLov := AValue
    else if AKey = 'SubDatasheet' then FDef.SubDatasheet := Trim(AValue)
    else if AKey = 'Board' then FDef.Board := Trim(AValue)
    else if AKey = 'Dash' then FDef.Dash := Trim(AValue)
    else if AKey = 'Timeline' then FDef.Timeline := Trim(AValue)
    else if (AKey = 'OnOpen') or (AKey = 'OnCurrent') or (AKey = 'BeforeUpdate') or (AKey = 'AfterUpdate') or
            (AKey = 'BeforeDelete') or (AKey = 'OnClose') or (AKey = 'BeforeInsert') or (AKey = 'AfterInsert') or
            (AKey = 'AfterDelete') or (AKey = 'OnError') or (AKey = 'AfterQuery') or (AKey = 'FieldOnEnter') or
            (AKey = 'FieldOnExit') or (AKey = 'FieldOnValidate') or (AKey = 'FieldOnKey') then FDef.SetEv(AKey, AValue);
    ApplySurfaceSize;
    SyncSizeEdits;
    Exit;
  end;
  D := DefOf(FSelected);
  if D = nil then Exit;
  if AKey = 'Kind' then Exit;
  if AKey = 'Name' then
  begin
    Idx := FDef.IndexOfName(AValue);
    if (not IsValidIdent(AValue)) or ((Idx >= 0) and (FDef[Idx] <> D)) then
    begin
      ShowMessage(Tr('Invalid or already used name.'));
      Exit;
    end;
  end;
  PushUndo;
  DefSet(D, AKey, AValue);
  Msg := '';
  if IsExprProp(AKey) and (AValue <> '') then Msg := CheckExpr(AValue)
  else if (AKey = 'ControlSource') and (AValue <> '') and (AValue[1] = '=') then Msg := CheckExpr(Copy(AValue, 2, MaxInt));
  FStatus.Caption := Msg;
  if FSelected is TaFamilyHost then RebuildFamily else ApplyDef(FSelected, True);
  if FSelected is TaTabControl then HookTabs(TaTabControl(FSelected));
  if (AKey = 'Container') or (AKey = 'Page') then Reparent(FSelected);
  RelayoutAll;
  UpdateRing;
end;

{ LCL-ov OnValidate se u ovoj verziji nikad ne poziva; vrijednost se prima kad se uredjivanje celije zavrsi }
procedure TaFormDesigner.PropValidateEntry(Sender: TObject; aCol, aRow: Integer; const OldValue: string; var NewValue: string);
begin
  if (aCol <> 1) or (aRow < 1) or FLoadingProps then Exit;
  if NewValue = OldValue then Exit;
  PropValidate(Sender, aCol, aRow, TValueListEditor(Sender).Cells[0, aRow], NewValue);
end;

procedure TaFormDesigner.PropValidate(Sender: TObject; ACol, ARow: Longint;
  const KeyName, KeyValue: string);
begin
  if FLoadingProps or (KeyName = 'Font') then Exit;
  ApplyProp(KeyName, KeyValue);
end;

{ opens the calculated field wizard for the form's own source, or for the selected subform's }
procedure TaFormDesigner.AddCalcField;
var
  T: TStringList;
  Alias, Expr, Cur, Src: string;
  D: TaControlDef;
begin
  D := nil;
  if FSelected <> nil then D := DefOf(FSelected);
  if D <> nil then Src := D.RowSource else Src := Trim(FSource.Text);
  if Src = '' then begin ShowMessage(Tr('First choose a data source.')); Exit; end;
  T := TStringList.Create;
  try
    T.Add(Src);
    if not RunCalcWizard(Self, FDb, T, True, Alias, Expr) then Exit;
  finally
    T.Free;
  end;
  if D <> nil then Cur := DefGet(D, 'CalcFields') else Cur := FDef.CalcFields;
  if Trim(Cur) <> '' then Cur := Cur + ' ;; ';
  ApplyProp('CalcFields', Cur + Alias + '=' + Expr);
  ShowProps;
end;

procedure TaFormDesigner.ExprClick(Sender: TObject);
var
  Key, Cur: string;
  D: TaControlDef;
begin
  if FProps.Row < 1 then Exit;
  Key := FProps.Cells[0, FProps.Row];
  if Key = 'CalcFields' then
  begin
    AddCalcField;
    Exit;
  end;
  if FSelected = nil then
  begin
    if (Key <> 'Filter') and (Key <> 'OrderBy') then begin ShowMessage(Tr('Choose the row ControlSource, VisibleIf, EnabledIf, Filter or OrderBy.')); Exit; end;
    Cur := FProps.Cells[1, FProps.Row];
    if EditExpression(Self, FDb, Trim(FSource.Text), Key, Cur) then
    begin
      ApplyProp(Key, Cur);
      ShowProps;
    end;
    Exit;
  end;
  D := DefOf(FSelected);
  if (Key <> 'ControlSource') and (Key <> 'VisibleIf') and (Key <> 'EnabledIf') and (Key <> 'RowSource') then
  begin
    ShowMessage(Tr('Choose the row ControlSource, VisibleIf, EnabledIf or RowSource.'));
    Exit;
  end;
  Cur := DefGet(D, Key);
  if EditExpression(Self, FDb, Trim(FSource.Text), D.Name + '.' + Key, Cur) then
  begin
    ApplyProp(Key, Cur);
    ShowProps;
  end;
end;

{ ---------------- mouse ---------------- }

procedure TaFormDesigner.SurfaceMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if FPalette.ItemIndex >= 0 then
  begin
    PlaceControl(FPalette.Items[FPalette.ItemIndex], Snap(X), Snap(Y), FSurface, '', 0);
    FPalette.ItemIndex := -1;
  end
  else if Button = mbLeft then
  begin
    { okvir za odabir: bez povlacenja ostaje obicni klik u prazno }
    FLassoPrev.Clear;
    FLassoAdd := ssCtrl in Shift;
    if FLassoAdd then CopySelection(FLassoPrev) else Select(nil);
    FDragStart := Mouse.CursorPos;
    FLasso := True;
    FLassoUseTo := False;
    FResizeTimer.Enabled := True;
  end;
end;

procedure TaFormDesigner.ContainerDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  Sh: TTabSheet;
  T: TaTabControl;
begin
  if not (Sender is TTabSheet) then Exit;
  Sh := TTabSheet(Sender);
  if not (Sh.Parent is TaTabControl) then Exit;
  T := TaTabControl(Sh.Parent);
  if FPalette.ItemIndex >= 0 then
  begin
    PlaceControl(FPalette.Items[FPalette.ItemIndex], Snap(X), Snap(Y), Sh, T.Def.Name, Sh.PageIndex);
    FPalette.ItemIndex := -1;
  end
  else Select(T);
end;

procedure TaFormDesigner.CtlMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  C: TControl;
  Sel: TList;
  I: Integer;
begin
  if Button <> mbLeft then Exit;
  if FPalette.ItemIndex >= 0 then
  begin
    { panel prima kontrole iz palete (kao stranica kontrole s karticama) }
    if (Sender is TControl) and FamilyIsContainer(TControl(Sender)) then
    begin
      PlaceControl(FPalette.Items[FPalette.ItemIndex], Snap(X), Snap(Y), TWinControl(Sender), DefOf(TControl(Sender)).Name,
        FamilyActivePage(TControl(Sender)));
      FPalette.ItemIndex := -1;
    end;
    Exit;
  end;
  C := TControl(Sender);
  FDragCtl := C;
  if ssCtrl in Shift then
  begin
    ToggleMulti(C);
    FDragging := False;
    FResizing := False;
    Exit;
  end;
  { klik na vec odabranu kontrolu ne smije ponistiti ostatak odabira }
  if (FMulti.IndexOf(C) < 0) and (C <> FSelected) then Select(C);
  FResizeMode := EdgeMode(X, Y, C.Width, C.Height, EdgeBand);
  FResizing := FResizeMode <> 0;
  FDragging := not FResizing;
  { bez hvatanja misa dogadaji staju cim pokazivac napusti kontrolu, pa bi povlacenje ruba stalo nakon par piksela }
  C.MouseCapture := True;
  FDragUndoPushed := False;
  FDragStart := Mouse.CursorPos;
  FOrig := Rect(C.Left, C.Top, C.Width, C.Height);
  FResizeTimer.Enabled := True;
  { povlacenje vise odabranih odjednom }
  FGroup.Clear;
  SetLength(FGroupOrig, 0);
  if FDragging then
  begin
    Sel := SelectionList;
    try
      for I := 0 to Sel.Count - 1 do
        if TControl(Sel[I]) <> C then
        begin
          FGroup.Add(Sel[I]);
          SetLength(FGroupOrig, Length(FGroupOrig) + 1);
          FGroupOrig[High(FGroupOrig)] := Point(TControl(Sel[I]).Left, TControl(Sel[I]).Top);
        end;
    finally
      Sel.Free;
    end;
  end;
end;

procedure TaFormDesigner.CtlMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
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

procedure TaFormDesigner.CtlMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if FDragging or FResizing then
  begin
    if FDragging then FinishDragDrop;
    TControl(Sender).MouseCapture := False;
    FResizeTimer.Enabled := False;
    FDragging := False;
    FResizing := False;
    RelayoutAll;
    UpdateRing;
    ShowProps;
  end;
end;

procedure TaFormDesigner.BeginResize(AMode: Integer);
begin
  FResizeMode := AMode;
  FResizing := True;
  FDragging := False;
  FDragUndoPushed := False;
  FGroup.Clear;
  SetLength(FGroupOrig, 0);
  FDragStart := Mouse.CursorPos;
  FOrig := Rect(FSelected.Left, FSelected.Top, FSelected.Width, FSelected.Height);
  FResizeTimer.Enabled := True;
end;

procedure TaFormDesigner.EndResize;
begin
  FResizeTimer.Enabled := False;
  if FResizing then
  begin
    FResizing := False;
    RelayoutAll;
    UpdateRing;
    ShowProps;
  end;
end;

{ Qt ne salje pomake misa kontroli cim pokazivac iziđe iz nje, pa se pokazivac cita periodički }
procedure TaFormDesigner.ResizeTick(Sender: TObject);
begin
  if FFormResizing then
  begin
    if (GetKeyState(VK_LBUTTON) and $8000) = 0 then
    begin
      FFormResizing := False;
      FResizeTimer.Enabled := False;
      ShowProps;
    end
    else FormResizeTo(Mouse.CursorPos.X - FDragStart.X, Mouse.CursorPos.Y - FDragStart.Y);
    Exit;
  end;
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
    if FDragging then FinishDragDrop;
    if FResizing then EndResize;
    FDragging := False;
    ShowProps;
    Exit;
  end;
  if FResizing then ResizeTo(Mouse.CursorPos.X - FDragStart.X, Mouse.CursorPos.Y - FDragStart.Y)
  else DragTo(Mouse.CursorPos.X - FDragStart.X, Mouse.CursorPos.Y - FDragStart.Y);
end;

{ prebacuje kontrolu u Panel ili Pages (ili natrag na formu kad je ATarget nil); polozaj ostaje na istom mjestu na zaslonu }
procedure TaFormDesigner.MoveToContainer(C: TControl; ATarget: TWinControl);
var
  D: TaControlDef;
  S, P: TPoint;
  NewName: string;
  NewPage: Integer;
begin
  D := DefOf(C);
  if D = nil then Exit;
  if ATarget = nil then
  begin
    NewName := '';
    NewPage := 0;
  end
  else if (ATarget is TTabSheet) and (ATarget.Parent is TaTabControl) then
  begin
    { stari TabControl: kontrola ide na odabranu stranicu }
    NewName := TaTabControl(ATarget.Parent).Def.Name;
    NewPage := TTabSheet(ATarget).PageIndex;
  end
  else
  begin
    if DefOf(ATarget) = nil then Exit;
    NewName := DefOf(ATarget).Name;
    NewPage := FamilyActivePage(ATarget);
  end;
  if SameText(D.GetX('container'), NewName) and
     ((NewName = '') or (StrToIntDef(D.GetX('page'), 0) = NewPage)) then Exit;
  S := C.ClientToScreen(Point(0, 0));
  D.SetX('container', NewName);
  if NewName = '' then D.SetX('page', '') else D.SetX('page', IntToStr(NewPage));
  Reparent(C);
  P := C.Parent.ScreenToClient(S);
  D.Left := Max(0, Snap(P.X));
  D.Top := Max(0, Snap(P.Y));
  C.SetBounds(D.Left, D.Top, D.Width, D.Height);
end;

{ kad se povlacenje zavrsi iznad Panela ili Pages-a, kontrola (i odabrana skupina) prelazi u njega; izvan njih vraca se na formu }
procedure TaFormDesigner.FinishDragDrop;
var
  P, Tl: TPoint;
  Target: TWinControl;
  Dragged: TList;
  I: Integer;
  Cmp: TComponent;
  A, Best: Int64;
  R: TRect;
  Anc: TWinControl;
  Skip: Boolean;
  Sheet: TTabSheet;
begin
  if (FDragCtl = nil) or not FDragUndoPushed then Exit;
  P := Mouse.CursorPos;
  Dragged := TList.Create;
  try
    Dragged.Add(FDragCtl);
    for I := 0 to FGroup.Count - 1 do Dragged.Add(FGroup[I]);
    Target := nil;
    Best := High(Int64);
    for I := 0 to FSurface.ComponentCount - 1 do
    begin
      Cmp := FSurface.Components[I];
      if Cmp is TaTabControl then
      begin
        { stari TabControl: odrediste je aktivna stranica }
        if (Dragged.IndexOf(Cmp) >= 0) or (TaTabControl(Cmp).PageCount = 0) then Continue;
        Anc := TaTabControl(Cmp).Parent;
        Skip := False;
        while Anc <> nil do
        begin
          if Dragged.IndexOf(Anc) >= 0 then Skip := True;
          Anc := Anc.Parent;
        end;
        if Skip then Continue;
        Sheet := TaTabControl(Cmp).ActivePage;
        if Sheet = nil then Continue;
        Tl := Sheet.ClientToScreen(Point(0, 0));
        R := Bounds(Tl.X, Tl.Y, Sheet.Width, Sheet.Height);
        if PtInRect(R, P) then
        begin
          A := Int64(R.Right - R.Left) * (R.Bottom - R.Top);
          if A < Best then begin Best := A; Target := Sheet; end;
        end;
        Continue;
      end;
      if not (Cmp is TControl) or not FamilyIsContainer(TControl(Cmp)) or (Dragged.IndexOf(Cmp) >= 0) then Continue;
      { pogon koji je sam unutar povucene kontrole ne smije biti odrediste }
      Skip := False;
      Anc := TControl(Cmp).Parent;
      while Anc <> nil do
      begin
        if Dragged.IndexOf(Anc) >= 0 then Skip := True;
        Anc := Anc.Parent;
      end;
      if Skip then Continue;
      Tl := TControl(Cmp).ClientToScreen(Point(0, 0));
      R := Bounds(Tl.X, Tl.Y, TControl(Cmp).Width, TControl(Cmp).Height);
      if PtInRect(R, P) then
      begin
        A := Int64(R.Right - R.Left) * (R.Bottom - R.Top);
        if A < Best then begin Best := A; Target := TWinControl(Cmp); end;
      end;
    end;
    for I := 0 to Dragged.Count - 1 do MoveToContainer(TControl(Dragged[I]), Target);
  finally
    Dragged.Free;
  end;
end;

procedure TaFormDesigner.DragTo(Dx, Dy: Integer);
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
  D.Left := Max(0, Snap(FOrig.Left + Dx));
  D.Top := Max(0, Snap(FOrig.Top + Dy));
  for I := 0 to FGroup.Count - 1 do
  begin
    D2 := DefOf(TControl(FGroup[I]));
    D2.Left := Max(0, FGroupOrig[I].X + (D.Left - FOrig.Left));
    D2.Top := Max(0, FGroupOrig[I].Y + (D.Top - FOrig.Top));
    TControl(FGroup[I]).SetBounds(D2.Left, D2.Top, D2.Width, D2.Height);
  end;
  FDragCtl.SetBounds(D.Left, D.Top, D.Width, D.Height);
  UpdateRing;
end;

procedure TaFormDesigner.CopySelection(ATo: TList);
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

procedure TaFormDesigner.LassoTick;
var
  A, B: TPoint;
  R, Cr, Ix: TRect;
  I: Integer;
  C: TControl;
begin
  if FLassoUseTo then B := FLassoTo else B := Mouse.CursorPos;
  A := FDragStart;
  R := Rect(Min(A.X, B.X), Min(A.Y, B.Y), Max(A.X, B.X), Max(A.Y, B.Y));
  A := FSurface.ScreenToClient(Point(R.Left, R.Top));
  B := FSurface.ScreenToClient(Point(R.Right, R.Bottom));
  FLassoShape.SetBounds(A.X, A.Y, Max(1, B.X - A.X), Max(1, B.Y - A.Y));
  FLassoShape.Visible := True;
  FLassoShape.BringToFront;
  FSelected := nil;
  FMulti.Clear;
  if FLassoAdd then
    for I := 0 to FLassoPrev.Count - 1 do
      if FSelected = nil then FSelected := TControl(FLassoPrev[I]) else FMulti.Add(FLassoPrev[I]);
  for I := 0 to FSurface.ControlCount - 1 do
  begin
    C := FSurface.Controls[I];
    if (DefOf(C) = nil) or (C = FRing) or IsGrip(C) or (C = FLassoShape) then Continue;
    if FLassoAdd and (FLassoPrev.IndexOf(C) >= 0) then Continue;
    A := FSurface.ClientToScreen(Point(C.Left, C.Top));
    Cr := Rect(A.X, A.Y, A.X + C.Width, A.Y + C.Height);
    if IntersectRect(Ix, R, Cr) then
      if FSelected = nil then FSelected := C else FMulti.Add(C);
  end;
  UpdateRing;
end;

procedure TaFormDesigner.LassoEnd;
begin
  FResizeTimer.Enabled := False;
  FLasso := False;
  FLassoUseTo := False;
  FLassoShape.Visible := False;
  UpdateRing;
  ShowProps;
end;

procedure TaFormDesigner.SizeEdited(Sender: TObject);
var
  W, H: Integer;
begin
  W := StrToIntDef(Trim(FWEdit.Text), FDef.Width);
  H := StrToIntDef(Trim(FHEdit.Text), FDef.Height);
  W := Max(120, Min(W, 4000));
  H := Max(80, Min(H, 3000));
  if (W <> FDef.Width) or (H <> FDef.Height) then
  begin
    PushUndo;
    FDef.Width := W;
    FDef.Height := H;
    FSurface.SetBounds(8, 8, W, H);
    if FSelected = nil then ShowProps;
  end;
  SyncSizeEdits;
end;

procedure TaFormDesigner.ApplySurfaceSize;
begin
  RelayoutAll;
  PlaceFormGrips;
end;

{ prvi raspored kad je prozor prikazan: prije toga LCL ne rasporedi kontrole }
procedure TaFormDesigner.DesignerShown(Sender: TObject);
begin
  RelayoutAll;
  UpdateRing;
end;

procedure TaFormDesigner.CollectLayoutControls(AParent: TWinControl; AList: TList);
var
  I: Integer;
  C: TControl;
begin
  for I := 0 to AParent.ControlCount - 1 do
  begin
    C := AParent.Controls[I];
    if DefOf(C) <> nil then AList.Add(C);
    if C is TWinControl then CollectLayoutControls(TWinControl(C), AList);
  end;
end;

{ Dock, sidra i razmaci djeluju u dizajneru kao u Lazarusu: povecas formu pa se kontrole prilagode, pomaknes susjeda pa ga
  sljedbenici prate. Svojstva se privremeno postave na kontrole, LCL ih rasporedi, zatim se polozaji upisu natrag u definiciju
  i svojstva skinu, da se kontrole dalje slobodno povlace. }
procedure TaFormDesigner.RelayoutAll;
var
  L: TList;
  I: Integer;
  C: TControl;
  D: TaControlDef;
  Any: Boolean;
begin
  if FSurface = nil then Exit;
  if FRelayouting then Exit;
  L := TList.Create;
  try
    CollectLayoutControls(FSurface, L);
    Any := False;
    for I := 0 to L.Count - 1 do
      if HasLayoutProps(DefOf(TControl(L[I]))) then Any := True;
    if not Any then
    begin
      FSurface.SetBounds(8, 8, FDef.Width, FDef.Height);
      Exit;
    end;
    FRelayouting := True;
    try
      for I := 0 to L.Count - 1 do
      begin
        C := TControl(L[I]);
        D := DefOf(C);
        C.SetBounds(D.Left, D.Top, D.Width, D.Height);
        if HasLayoutProps(D) then ApplyControlLayout(C, D);
      end;
      FSurface.SetBounds(8, 8, FDef.Width, FDef.Height);
      FSurface.ReAlign;
      for I := 0 to L.Count - 1 do
        if (TControl(L[I]) is TWinControl) then TWinControl(L[I]).ReAlign;
      Application.ProcessMessages;
      for I := 0 to L.Count - 1 do
      begin
        C := TControl(L[I]);
        D := DefOf(C);
        if not HasLayoutProps(D) then Continue;
        D.Left := C.Left; D.Top := C.Top; D.Width := C.Width; D.Height := C.Height;
        ClearLayout(C);
        C.SetBounds(D.Left, D.Top, D.Width, D.Height);
      end;
    finally
      FRelayouting := False;
    end;
  finally
    L.Free;
  end;
end;

{ tri hvatista uz desni, donji rub i kut forme }
procedure TaFormDesigner.PlaceFormGrips;
var
  L, T, W, H: Integer;
begin
  if (FFormGrips[0] = nil) or (FSurface = nil) then Exit;
  L := FSurface.Left; T := FSurface.Top; W := FSurface.Width; H := FSurface.Height;
  FFormGrips[0].SetBounds(L + W + 1, T + H div 2 - 5, 9, 10);
  FFormGrips[1].SetBounds(L + W div 2 - 5, T + H + 1, 10, 9);
  FFormGrips[2].SetBounds(L + W + 1, T + H + 1, 10, 10);
  FFormGrips[0].BringToFront;
  FFormGrips[1].BringToFront;
  FFormGrips[2].BringToFront;
end;

procedure TaFormDesigner.FormGripDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button <> mbLeft then Exit;
  FFormMode := TShape(Sender).Tag;
  FFormOrigW := FDef.Width;
  FFormOrigH := FDef.Height;
  FFormUndoPushed := False;
  FDragStart := Mouse.CursorPos;
  FFormResizing := True;
  FResizeTimer.Enabled := True;
end;

{ Dx, Dy = pomak od pocetka povlacenja (mis ili test) }
procedure TaFormDesigner.FormResizeTo(Dx, Dy: Integer);
var
  W, H: Integer;
begin
  W := FFormOrigW;
  H := FFormOrigH;
  if (FFormMode and 1) <> 0 then W := Max(120, Min(4000, Snap(FFormOrigW + Dx)));
  if (FFormMode and 2) <> 0 then H := Max(80, Min(3000, Snap(FFormOrigH + Dy)));
  if (W = FDef.Width) and (H = FDef.Height) then Exit;
  if not FFormUndoPushed then
  begin
    FDef.Width := FFormOrigW; FDef.Height := FFormOrigH;
    PushUndo;
    FFormUndoPushed := True;
  end;
  FDef.Width := W;
  FDef.Height := H;
  ApplySurfaceSize;
  SyncSizeEdits;
end;

procedure TaFormDesigner.FormResizeDragForTest(AMode, Dx, Dy: Integer);
begin
  FFormMode := AMode;
  FFormOrigW := FDef.Width;
  FFormOrigH := FDef.Height;
  FFormUndoPushed := False;
  FormResizeTo(Dx, Dy);
  if FSelected = nil then ShowProps;
end;

procedure TaFormDesigner.SyncSizeEdits;
begin
  if FWEdit = nil then Exit;
  FWEdit.Text := IntToStr(FDef.Width);
  FHEdit.Text := IntToStr(FDef.Height);
end;

{ Dx, Dy = pomak od pocetka povlacenja; jedini ulaz za promjenu velicine (mis, rucke, testovi) }
procedure TaFormDesigner.ResizeTo(Dx, Dy: Integer);
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
  MinSizeFor(D, MinW, MinH);
  Box := ResizeBox(MakeBox(FOrig.Left, FOrig.Top, FOrig.Right, FOrig.Bottom), FResizeMode, Dx, Dy, MinW, MinH, GridStep);
  D.Left := Box.L; D.Top := Box.T; D.Width := Box.W; D.Height := Box.H;
  FSelected.SetBounds(D.Left, D.Top, D.Width, D.Height);
  UpdateRing;
end;

procedure TaFormDesigner.GripDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if (Button <> mbLeft) or (FSelected = nil) then Exit;
  BeginResize(GripMode(TControl(Sender).Tag));
  TControl(Sender).MouseCapture := True;
end;

procedure TaFormDesigner.GripMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  if not FResizing then Exit;
  ResizeTo(Mouse.CursorPos.X - FDragStart.X, Mouse.CursorPos.Y - FDragStart.Y);
end;

procedure TaFormDesigner.GripUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if FResizing then
  begin
    TControl(Sender).MouseCapture := False;
    EndResize;
  end;
end;

{ tipkovnica: Shift + strelice mijenja velicinu odabrane kontrole }
procedure TaFormDesigner.ResizeBy(Dw, Dh: Integer);
var
  D: TaControlDef;
  Sel: TList;
  I, MinW, MinH: Integer;
begin
  if FSelected = nil then Exit;
  Sel := SelectionList;
  try
    PushUndo;
    for I := 0 to Sel.Count - 1 do
    begin
      D := DefOf(TControl(Sel[I]));
      MinSizeFor(D, MinW, MinH);
      D.Width := Max(MinW, D.Width + Dw);
      D.Height := Max(MinH, D.Height + Dh);
      TControl(Sel[I]).SetBounds(D.Left, D.Top, D.Width, D.Height);
    end;
  finally
    Sel.Free;
  end;
  UpdateRing;
  ShowProps;
end;

{ ---------------- undo, duplicate, delete, keys ---------------- }

procedure TaFormDesigner.PushUndo;
begin
  FUndo.Add(FDef.ToJson);
  while FUndo.Count > MaxUndo do FUndo.Delete(0);
end;

procedure TaFormDesigner.DoUndo;
begin
  if FUndo.Count = 0 then Exit;
  FDef.FromJson(FUndo[FUndo.Count - 1]);
  FUndo.Delete(FUndo.Count - 1);
  ClearSurface;
  BuildFromDef;
  FSource.Text := FDef.RecordSource;
  FCaption.Text := FDef.Caption;
  SyncSizeEdits;
  ApplySurfaceSize;
  ShowProps;
end;

procedure TaFormDesigner.UndoClick(Sender: TObject);
begin
  DoUndo;
end;

procedure TaFormDesigner.DeleteSelected;
var
  C: TControl;
  D: TaControlDef;
  I, J: Integer;
  Doomed, Sel: TList;
begin
  if FSelected = nil then Exit;
  Sel := SelectionList;
  try
    PushUndo;
    Select(nil);
    for J := 0 to Sel.Count - 1 do
    begin
      C := TControl(Sel[J]);
      D := DefOf(C);
      Doomed := TList.Create;
      try
        Doomed.Add(D);
        if (C is TaTabControl) or FamilyIsContainer(C) then
          for I := 0 to FDef.Count - 1 do
            if SameText(FDef[I].GetX('container'), D.Name) then Doomed.Add(FDef[I]);
        C.Free;       { children live on the pages and go with it }
        for I := 0 to Doomed.Count - 1 do FDef.Delete(TaControlDef(Doomed[I]));
      finally
        Doomed.Free;
      end;
    end;
  finally
    Sel.Free;
  end;
end;

procedure TaFormDesigner.DeleteClick(Sender: TObject);
begin
  DeleteSelected;
end;

procedure TaFormDesigner.Duplicate;
var
  Src, D: TaControlDef;
  C: TControl;
begin
  if FSelected = nil then Exit;
  Src := DefOf(FSelected);
  if Src.Kind = 'TabControl' then begin ShowMessage(Tr('Tabs cannot be duplicated.')); Exit; end;
  PushUndo;
  D := TaControlDef.Create;
  D.Kind := Src.Kind;
  D.Name := FDef.UniqueName(Src.Kind);
  D.Caption := Src.Caption;
  D.ControlSource := Src.ControlSource;
  D.RowSource := Src.RowSource;
  D.OnClick := Src.OnClick;
  D.LinkMaster := Src.LinkMaster;
  D.LinkChild := Src.LinkChild;
  D.Format := Src.Format;
  D.Align := Src.Align;
  D.Bold := Src.Bold;
  D.Extra := Src.Extra;
  D.Left := Src.Left + 12;
  D.Top := Src.Top + 12;
  D.Width := Src.Width;
  D.Height := Src.Height;
  FDef.Add(D);
  C := MakeControl(D);
  if C <> nil then Select(C);
end;

procedure TaFormDesigner.DuplicateClick(Sender: TObject);
begin
  Duplicate;
end;

procedure TaFormDesigner.ClearMulti;
begin
  if FMulti <> nil then FMulti.Clear;
  if FMultiRings <> nil then UpdateRing;
end;

procedure TaFormDesigner.ToggleMulti(C: TControl);
var
  I: Integer;
begin
  if C = nil then Exit;
  if FSelected = nil then begin FSelected := C; UpdateRing; ShowProps; Exit; end;
  if C = FSelected then
  begin
    { odustajanje od glavne: sljedeca postaje glavna }
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
  UpdateRing;
  ShowProps;
end;

function TaFormDesigner.SelectionList: TList;
begin
  Result := TList.Create;
  if FSelected <> nil then Result.Add(FSelected);
  Result.AddList(FMulti);
end;

procedure TaFormDesigner.SelectAll;
var
  I: Integer;
  C: TControl;
begin
  Select(nil);
  for I := 0 to FSurface.ControlCount - 1 do
  begin
    C := FSurface.Controls[I];
    if (DefOf(C) = nil) or (C = FRing) or IsGrip(C) then Continue;
    if FSelected = nil then FSelected := C else FMulti.Add(C);
  end;
  UpdateRing;
  ShowProps;
end;

procedure TaFormDesigner.DoLayout(AOp: TLayoutOp);
var
  L: TList;
  Boxes: TLBoxes;
  I: Integer;
  D: TaControlDef;
begin
  L := SelectionList;
  try
    if L.Count < 2 then begin FStatus.Caption := Tr('Select at least two controls (Ctrl+click).'); Exit; end;
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
    UpdateRing;
    ShowProps;
  finally
    L.Free;
  end;
end;

procedure TaFormDesigner.ZOrder(AToFront: Boolean);
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
    UpdateRing;
  finally
    L.Free;
  end;
end;

procedure TaFormDesigner.LayoutMenuClick(Sender: TObject);
var
  T: Integer;
begin
  T := TMenuItem(Sender).Tag;
  if T = 100 then ZOrder(True)
  else if T = 101 then ZOrder(False)
  else if T = 102 then SelectAll
  else if T = 103 then SaveGroup
  else if T = 104 then InsertGroup
  else DoLayout(TLayoutOp(T));
end;

procedure TaFormDesigner.LayoutButtonClick(Sender: TObject);
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
    It := TMenuItem.Create(FLayoutMenu); It.Caption := '-'; FLayoutMenu.Items.Add(It);
    It := TMenuItem.Create(FLayoutMenu); It.Caption := Tr('Save the selected controls as a group...'); It.Tag := 103; It.OnClick := @LayoutMenuClick; FLayoutMenu.Items.Add(It);
    It := TMenuItem.Create(FLayoutMenu); It.Caption := Tr('Insert a group of controls...'); It.Tag := 104; It.OnClick := @LayoutMenuClick; FLayoutMenu.Items.Add(It);
  end;
  P := TControl(Sender).ClientToScreen(Point(0, TControl(Sender).Height));
  FLayoutMenu.PopUp(P.X, P.Y);
end;

{ klasa svojstava iz oznacene kontrole: dijalog, pa se klasa postavlja kontroli }
procedure TaFormDesigner.AsyncNewPropClass(Data: PtrInt);
var
  D: TaControlDef;
  Nm: string;
begin
  if FSelected = nil then Exit;
  D := DefOf(FSelected);
  if D = nil then Exit;
  Nm := D.GetX('class');
  if RunPropClassDialog(Self, FDb, D, Nm) then ApplyProp('PropertyClass', Nm);
  ShowProps;
end;

{ odabrane kontrole -> grupa u biblioteci objekata }
procedure TaFormDesigner.SaveGroup;
var
  L, Defs: TList;
  I: Integer;
  Nm: string;
begin
  L := SelectionList;
  Defs := TList.Create;
  try
    for I := 0 to L.Count - 1 do
      if DefOf(TControl(L[I])) <> nil then Defs.Add(DefOf(TControl(L[I])));
    if Defs.Count = 0 then begin ShowMessage(Tr('Select the controls that make up the group.')); Exit; end;
    Nm := '';
    if not InputQuery(Tr('Group of controls'), Tr('Group name (e.g. AddressBlock)'), Nm) then Exit;
    Nm := Trim(Nm);
    if Nm = '' then Exit;
    ControlGroupSave(FDb, Nm, Defs);
  finally
    Defs.Free;
    L.Free;
  end;
end;

procedure TaFormDesigner.InsertGroup;
var
  Names: TStringList;
  Nm: string;
  First, I: Integer;
  C: TControl;
begin
  Names := ControlGroupList(FDb);
  try
    if Names.Count = 0 then begin ShowMessage(Tr('The library has no control groups.')); Exit; end;
    if not RunPickDialog(Self, 'Umetni grupu', 'Grupa kontrola', Names, Nm) then Exit;
  finally
    Names.Free;
  end;
  PushUndo;
  First := FDef.Count;
  ControlGroupInsert(FDb, Nm, FDef, 20, 20);
  C := nil;
  for I := First to FDef.Count - 1 do C := MakeControl(FDef[I]);
  if C <> nil then Select(C);
end;

{ obitelj kontrola nema ApplyDef: nakon promjene svojstva domacin se gradi iznova iz definicije, na istom mjestu i s istim odabirom }
procedure TaFormDesigner.RebuildFamily;
var
  Old, New: TControl;
  Idx, I: Integer;
  D: TaControlDef;
  Par: TWinControl;
begin
  Old := FSelected;
  D := DefOf(Old);
  if (Old = nil) or (D = nil) then Exit;
  Par := Old.Parent;
  Idx := Par.GetControlIndex(Old);
  { naziv se oslobada prije nego sto ga preuzme nova kontrola }
  Old.Name := '';
  New := MakeControl(D);
  if New = nil then begin Old.Name := D.Name; Exit; end;
  if (New.Parent = Par) and (Idx >= 0) then Par.SetControlIndex(New, Idx);
  { djeca panela prelaze na novog domacina }
  if FamilyIsContainer(Old) then
    for I := TWinControl(Old).ControlCount - 1 downto 0 do
      if (DefOf(TWinControl(Old).Controls[I]) <> nil) and SameText(DefOf(TWinControl(Old).Controls[I]).GetX('container'), D.Name) then
        TWinControl(Old).Controls[I].Parent := TWinControl(New);
  FamilyShowPages(New);
  I := FMulti.IndexOf(Old);
  if I >= 0 then FMulti[I] := New;
  if FDragCtl = Old then FDragCtl := New;
  FSelected := New;
  Old.Free;
end;

procedure TaFormDesigner.ToggleMultiForTest(C: TControl);
begin
  ToggleMulti(C);
end;

procedure TaFormDesigner.LayoutForTest(AOp: TLayoutOp);
begin
  DoLayout(AOp);
end;

procedure TaFormDesigner.ZOrderForTest(AToFront: Boolean);
begin
  ZOrder(AToFront);
end;

function TaFormDesigner.FormDef: TaFormDef;
begin
  Result := FDef;
end;

procedure TaFormDesigner.LassoForTest(const AFrom, ATo: TPoint; AAdd: Boolean);
begin
  FLassoPrev.Clear;
  if AAdd then CopySelection(FLassoPrev) else begin FSelected := nil; FMulti.Clear; end;
  FLassoAdd := AAdd;
  FLasso := True;
  FDragStart := AFrom;
  FLassoTo := ATo;
  FLassoUseTo := True;
  LassoTick;
  LassoEnd;
end;

procedure TaFormDesigner.GroupDragForTest(C: TControl; Dx, Dy: Integer);
var
  Sel: TList;
  I: Integer;
begin
  FDragCtl := C;
  FResizing := False;
  FDragging := True;
  FDragUndoPushed := False;
  FOrig := Rect(C.Left, C.Top, C.Width, C.Height);
  FGroup.Clear;
  SetLength(FGroupOrig, 0);
  Sel := SelectionList;
  try
    for I := 0 to Sel.Count - 1 do
      if TControl(Sel[I]) <> C then
      begin
        FGroup.Add(Sel[I]);
        SetLength(FGroupOrig, Length(FGroupOrig) + 1);
        FGroupOrig[High(FGroupOrig)] := Point(TControl(Sel[I]).Left, TControl(Sel[I]).Top);
      end;
  finally
    Sel.Free;
  end;
  DragTo(Dx, Dy);
  FDragging := False;
end;

procedure TaFormDesigner.SetFormSizeForTest(W, H: Integer);
begin
  FWEdit.Text := IntToStr(W);
  FHEdit.Text := IntToStr(H);
  SizeEdited(nil);
end;

function TaFormDesigner.FormGripForTest(AIndex: Integer): TShape;
begin
  Result := FFormGrips[AIndex];
end;

function TaFormDesigner.SelectedCountForTest: Integer;
begin
  Result := FMulti.Count;
  if FSelected <> nil then Inc(Result);
end;

function TaFormDesigner.ControlOfForTest(AIndex: Integer): TControl;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to FSurface.ControlCount - 1 do
    if (AIndex < FDef.Count) and (DefOf(FSurface.Controls[I]) = FDef[AIndex]) then Exit(FSurface.Controls[I]);
end;

procedure TaFormDesigner.Nudge(Dx, Dy: Integer);
var
  D: TaControlDef;
  Sel: TList;
  I: Integer;
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
    end;
  finally
    Sel.Free;
  end;
  RelayoutAll;
  UpdateRing;
  ShowProps;
end;

procedure TaFormDesigner.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  Step: Integer;
begin
  if TypingInEditor then Exit;
  { strelice pomicu za korak mreze, Ctrl+strelice za 1 piksel; Shift+strelice mijenjaju velicinu (Ctrl+Shift za 1 piksel) }
  if ssCtrl in Shift then Step := 1 else Step := GridStep;
  case Key of
    VK_DELETE: begin DeleteSelected; Key := 0; end;
    VK_LEFT: begin if ssShift in Shift then ResizeBy(-Step, 0) else Nudge(-Step, 0); Key := 0; end;
    VK_RIGHT: begin if ssShift in Shift then ResizeBy(Step, 0) else Nudge(Step, 0); Key := 0; end;
    VK_UP: begin if ssShift in Shift then ResizeBy(0, -Step) else Nudge(0, -Step); Key := 0; end;
    VK_DOWN: begin if ssShift in Shift then ResizeBy(0, Step) else Nudge(0, Step); Key := 0; end;
    VK_Z: if ssCtrl in Shift then begin DoUndo; Key := 0; end;
    VK_D: if ssCtrl in Shift then begin Duplicate; Key := 0; end;
    VK_A: if ssCtrl in Shift then begin SelectAll; Key := 0; end;
  end;
end;

{ ---------------- save, fields, preview ---------------- }

function TaFormDesigner.Save: Boolean;
begin
  FDef.Caption := FCaption.Text;
  FDef.RecordSource := Trim(FSource.Text);
  try
    FDb.SaveObject('_sys_forms', FDef.Name, NormalizedJson);
    Result := True;
  except
    on E: Exception do
    begin
      ShowMessage(Tr('Saving failed: ') + E.Message);
      Result := False;
    end;
  end;
end;

procedure TaFormDesigner.SaveClick(Sender: TObject);
begin
  if Save then Caption := Tr('Form design: ') + FDef.Name + Tr(' (saved)');
end;

{ The wizard's generator lays the fields out; they are appended below what exists. }
procedure TaFormDesigner.AddFieldsClick(Sender: TObject);
var
  Fl: TaSourceFields;
  Names: TStringList;
  Gen: TaFormDef;
  I, Y0, Bottom: Integer;
  D, N: TaControlDef;
begin
  if Trim(FSource.Text) = '' then begin ShowMessage(Tr('Choose a source (table or query).')); Exit; end;
  Names := TStringList.Create;
  try
    Fl := SourceFieldList(FDb, Trim(FSource.Text));
    for I := 0 to High(Fl) do Names.Add(Fl[I].Name);
    Gen := BuildFormDef(FDb, Trim(FSource.Text), FDef.Name, Names, False);
  finally
    Names.Free;
  end;
  try
    PushUndo;
    Bottom := 0;
    for I := 0 to FDef.Count - 1 do
      if FDef[I].Top + FDef[I].Height > Bottom then Bottom := FDef[I].Top + FDef[I].Height;
    if Bottom > 0 then Y0 := Snap(Bottom + 12) else Y0 := 0;
    for I := 0 to Gen.Count - 1 do
    begin
      D := Gen[I];
      N := TaControlDef.Create;
      N.Kind := D.Kind;
      N.Name := FDef.UniqueName(D.Kind);
      N.Caption := D.Caption;
      N.ControlSource := D.ControlSource;
      N.RowSource := D.RowSource;
      N.Left := D.Left;
      N.Top := D.Top + Y0;
      N.Width := D.Width;
      N.Height := D.Height;
      FDef.Add(N);
      MakeControl(N);
    end;
    if FDef.Height < Y0 + Gen.Height then
    begin
      FDef.Height := Y0 + Gen.Height;
      ApplySurfaceSize;
    end;
  finally
    Gen.Free;
  end;
  Select(nil);
end;

procedure TaFormDesigner.PreviewClick(Sender: TObject);
var
  D2: TaFormDef;
  R: TaFormRunner;
begin
  if not Save then Exit;
  D2 := TaFormDef.Create;
  D2.FromJson(NormalizedJson);
  D2.Name := FDef.Name;
  R := TaFormRunner.CreateRunner(Self, FDb, D2);
  try
    R.ShowModal;
  finally
    R.Free;
  end;
end;

end.
