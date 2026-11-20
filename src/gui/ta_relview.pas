unit ta_relview;
{ Relationships view: tables as movable boxes, foreign keys as lines.
  Drag a field onto a field of another table to create a relation, click a
  line to select it (Delete removes it, double click edits cascade rules).
  Box positions are remembered in _sys_settings. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, ExtCtrls, StdCtrls, Graphics, contnrs,
  ZDataset, ta_meta;

type
  TRelBox = class
  public
    Name: string;
    X, Y, W, H: Integer;
    Fields: TStringList;       { Objects: 1 = primary key, 2 = foreign key }
    constructor Create;
    destructor Destroy; override;
  end;

  { TaRelationsView }

  TaRelationsView = class(TForm)
  private
    FDb: TAppDb;
    FBoxes: TFPObjectList;
    FRels: TaRelations;
    FPaint: TPaintBox;
    FDragBox: TRelBox;
    FDragDX, FDragDY: Integer;
    FLinking: Boolean;
    FLinkBox: TRelBox;
    FLinkField: Integer;
    FMouse: TPoint;
    FSel: Integer;
    procedure BuildUi;
    procedure LoadAll;
    procedure AutoLayout;
    procedure LoadLayout;
    procedure SaveLayout;
    function BoxByName(const AName: string): TRelBox;
    function FieldRowY(ABox: TRelBox; AField: Integer): Integer;
    function FieldIndex(ABox: TRelBox; const AField: string): Integer;
    function HitField(X, Y: Integer; out ABox: TRelBox; out AField: Integer): Boolean;
    function HitHeader(X, Y: Integer): TRelBox;
    function HitRelation(X, Y: Integer): Integer;
    procedure RelPoints(const R: TaRelation; out P: array of TPoint);
    procedure PaintAll(Sender: TObject);
    procedure MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure MouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure MouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure DblClick(Sender: TObject);
    procedure KeyDownEv(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure RefreshClick(Sender: TObject);
    procedure AutoClick(Sender: TObject);
    procedure DeleteClick(Sender: TObject);
    procedure CloseEv(Sender: TObject; var CloseAction: TCloseAction);
    procedure CreateRelation(AFrom: TRelBox; AFromField: Integer; ATo: TRelBox; AToField: Integer);
    procedure RemoveRelation(AIndex: Integer);
    function AskCascade(const ADescription: string; var AOnDelete: string): Boolean;
  public
    constructor CreateView(AOwner: TComponent; ADb: TAppDb);
    destructor Destroy; override;
  end;

procedure ShowRelationsView(AOwner: TComponent; ADb: TAppDb);

implementation

uses
  ta_i18n;


const
  HeaderH = 22;
  RowH = 18;
  MinW = 130;

procedure ShowRelationsView(AOwner: TComponent; ADb: TAppDb);
var
  V: TaRelationsView;
begin
  V := TaRelationsView.CreateView(AOwner, ADb);
  try
    V.ShowModal;
  finally
    V.Free;
  end;
end;

constructor TRelBox.Create;
begin
  Fields := TStringList.Create;
end;

destructor TRelBox.Destroy;
begin
  Fields.Free;
  inherited Destroy;
end;

constructor TaRelationsView.CreateView(AOwner: TComponent; ADb: TAppDb);
begin
  inherited CreateNew(AOwner);
  FDb := ADb;
  FBoxes := TFPObjectList.Create(True);
  FSel := -1;
  Caption := Tr('Relations');
  SetBounds(0, 0, 1100, 720);
  Position := poScreenCenter;
  KeyPreview := True;
  OnKeyDown := @KeyDownEv;
  OnClose := @CloseEv;
  BuildUi;
  LoadAll;
end;

destructor TaRelationsView.Destroy;
begin
  FBoxes.Free;
  inherited Destroy;
end;

procedure TaRelationsView.BuildUi;
var
  Tb: TPanel;
  procedure Btn(const ACap: string; AX, AW: Integer; AH: TNotifyEvent);
  begin
    with TButton.Create(Self) do
    begin
      Parent := Tb;
      Caption := ACap;
      SetBounds(AX, 6, AW, 26);
      OnClick := AH;
    end;
  end;
begin
  Tb := TPanel.Create(Self);
  Tb.Parent := Self;
  Tb.Align := alTop;
  Tb.Height := 38;
  Tb.BevelOuter := bvNone;
  Btn(Tr('Refresh'), 6, 80, @RefreshClick);
  Btn(Tr('Auto layout'), 92, 150, @AutoClick);
  Btn(Tr('Delete link'), 248, 100, @DeleteClick);
  with TLabel.Create(Self) do
  begin
    Parent := Tb;
    Caption := Tr('Drag a field onto a field of another table for a new link.');
    SetBounds(370, 12, 500, 18);
  end;
  FPaint := TPaintBox.Create(Self);
  FPaint.Parent := Self;
  FPaint.Align := alClient;
  FPaint.OnPaint := @PaintAll;
  FPaint.OnMouseDown := @MouseDown;
  FPaint.OnMouseMove := @MouseMove;
  FPaint.OnMouseUp := @MouseUp;
  FPaint.OnDblClick := @DblClick;
end;

function TaRelationsView.BoxByName(const AName: string): TRelBox;
var
  I: Integer;
begin
  for I := 0 to FBoxes.Count - 1 do
    if SameText(TRelBox(FBoxes[I]).Name, AName) then Exit(TRelBox(FBoxes[I]));
  Result := nil;
end;

function TaRelationsView.FieldIndex(ABox: TRelBox; const AField: string): Integer;
var
  I: Integer;
begin
  for I := 0 to ABox.Fields.Count - 1 do
    if SameText(ABox.Fields[I], AField) then Exit(I);
  Result := -1;
end;

procedure TaRelationsView.LoadAll;
var
  T: TStringList;
  I, J: Integer;
  B: TRelBox;
  Q: TZQuery;
  Fks: TaFkDefs;
  Idx, MaxW: Integer;
begin
  FBoxes.Clear;
  FRels := FDb.AllRelations;
  T := FDb.UserTables;
  try
    for I := 0 to T.Count - 1 do
    begin
      B := TRelBox.Create;
      B.Name := T[I];
      Q := FDb.TableInfo(T[I]);
      try
        while not Q.EOF do
        begin
          if Q.FieldByName('pk').AsInteger > 0 then Idx := 1 else Idx := 0;
          B.Fields.AddObject(Q.FieldByName('name').AsString, TObject(PtrInt(Idx)));
          Q.Next;
        end;
      finally
        Q.Free;
      end;
      Fks := FDb.GetFks(T[I]);
      for J := 0 to High(Fks) do
      begin
        Idx := FieldIndex(B, Fks[J].FromCol);
        if Idx >= 0 then B.Fields.Objects[Idx] := TObject(PtrInt(PtrInt(B.Fields.Objects[Idx]) or 2));
      end;
      FBoxes.Add(B);
    end;
  finally
    T.Free;
  end;
  { size from text }
  FPaint.Canvas.Font.Style := [fsBold];
  for I := 0 to FBoxes.Count - 1 do
  begin
    B := TRelBox(FBoxes[I]);
    MaxW := FPaint.Canvas.TextWidth(B.Name) + 24;
    for J := 0 to B.Fields.Count - 1 do
      if FPaint.Canvas.TextWidth(B.Fields[J]) + 28 > MaxW then MaxW := FPaint.Canvas.TextWidth(B.Fields[J]) + 28;
    if MaxW < MinW then MaxW := MinW;
    B.W := MaxW;
    B.H := HeaderH + RowH * B.Fields.Count;
  end;
  FPaint.Canvas.Font.Style := [];
  AutoLayout;
  LoadLayout;
  FPaint.Invalidate;
end;

procedure TaRelationsView.AutoLayout;
var
  I, X, Y, RowH2: Integer;
  B: TRelBox;
begin
  X := 20; Y := 20; RowH2 := 0;
  for I := 0 to FBoxes.Count - 1 do
  begin
    B := TRelBox(FBoxes[I]);
    if (X + B.W > 1000) and (X > 20) then
    begin
      X := 20;
      Inc(Y, RowH2 + 40);
      RowH2 := 0;
    end;
    B.X := X; B.Y := Y;
    Inc(X, B.W + 60);
    if B.H > RowH2 then RowH2 := B.H;
  end;
end;

procedure TaRelationsView.LoadLayout;
var
  L: TStringList;
  I: Integer;
  P: TStringList;
  B: TRelBox;
begin
  L := TStringList.Create;
  P := TStringList.Create;
  try
    L.Text := FDb.LoadSetting('relations_layout');
    P.Delimiter := '|';
    P.StrictDelimiter := True;
    for I := 0 to L.Count - 1 do
    begin
      P.DelimitedText := L[I];
      if P.Count < 3 then Continue;
      B := BoxByName(P[0]);
      if B = nil then Continue;
      B.X := StrToIntDef(P[1], B.X);
      B.Y := StrToIntDef(P[2], B.Y);
    end;
  finally
    P.Free;
    L.Free;
  end;
end;

procedure TaRelationsView.SaveLayout;
var
  L: TStringList;
  I: Integer;
  B: TRelBox;
begin
  L := TStringList.Create;
  try
    for I := 0 to FBoxes.Count - 1 do
    begin
      B := TRelBox(FBoxes[I]);
      L.Add(B.Name + '|' + IntToStr(B.X) + '|' + IntToStr(B.Y));
    end;
    FDb.SaveSetting('relations_layout', L.Text);
  finally
    L.Free;
  end;
end;

procedure TaRelationsView.CloseEv(Sender: TObject; var CloseAction: TCloseAction);
begin
  SaveLayout;
end;

function TaRelationsView.FieldRowY(ABox: TRelBox; AField: Integer): Integer;
begin
  Result := ABox.Y + HeaderH + AField * RowH + RowH div 2;
end;

procedure TaRelationsView.RelPoints(const R: TaRelation; out P: array of TPoint);
var
  C, Pa: TRelBox;
  CI, PI, Y1, Y2, X1, X2, Xm: Integer;
begin
  C := BoxByName(R.Child);
  Pa := BoxByName(R.Parent);
  FillChar(P, SizeOf(P), 0);
  if (C = nil) or (Pa = nil) then Exit;
  CI := FieldIndex(C, R.ChildCol);
  PI := FieldIndex(Pa, R.ParentCol);
  if CI < 0 then CI := 0;
  if PI < 0 then PI := 0;
  Y1 := FieldRowY(C, CI);
  Y2 := FieldRowY(Pa, PI);
  if C.X + C.W + 20 <= Pa.X then
  begin
    X1 := C.X + C.W; X2 := Pa.X; Xm := (X1 + X2) div 2;
  end
  else if Pa.X + Pa.W + 20 <= C.X then
  begin
    X1 := C.X; X2 := Pa.X + Pa.W; Xm := (X1 + X2) div 2;
  end
  else
  begin
    X1 := C.X + C.W; X2 := Pa.X + Pa.W;
    if X1 > X2 then Xm := X1 + 24 else Xm := X2 + 24;
  end;
  P[0] := Point(X1, Y1);
  P[1] := Point(Xm, Y1);
  P[2] := Point(Xm, Y2);
  P[3] := Point(X2, Y2);
end;

function SegDist(const A, B: TPoint; X, Y: Integer): Double;
var
  Dx, Dy, T: Double;
begin
  Dx := B.X - A.X; Dy := B.Y - A.Y;
  if (Dx = 0) and (Dy = 0) then Exit(Sqrt(Sqr(X - A.X) + Sqr(Y - A.Y)));
  T := ((X - A.X) * Dx + (Y - A.Y) * Dy) / (Dx * Dx + Dy * Dy);
  if T < 0 then T := 0;
  if T > 1 then T := 1;
  Result := Sqrt(Sqr(X - (A.X + T * Dx)) + Sqr(Y - (A.Y + T * Dy)));
end;

function TaRelationsView.HitRelation(X, Y: Integer): Integer;
var
  I, K: Integer;
  P: array[0..3] of TPoint;
begin
  Result := -1;
  for I := 0 to High(FRels) do
  begin
    RelPoints(FRels[I], P);
    for K := 0 to 2 do
      if SegDist(P[K], P[K + 1], X, Y) < 5 then Exit(I);
  end;
end;

function TaRelationsView.HitField(X, Y: Integer; out ABox: TRelBox; out AField: Integer): Boolean;
var
  I: Integer;
  B: TRelBox;
begin
  Result := False;
  for I := FBoxes.Count - 1 downto 0 do
  begin
    B := TRelBox(FBoxes[I]);
    if (X >= B.X) and (X <= B.X + B.W) and (Y >= B.Y + HeaderH) and (Y < B.Y + B.H) then
    begin
      ABox := B;
      AField := (Y - B.Y - HeaderH) div RowH;
      Exit(True);
    end;
  end;
end;

function TaRelationsView.HitHeader(X, Y: Integer): TRelBox;
var
  I: Integer;
  B: TRelBox;
begin
  Result := nil;
  for I := FBoxes.Count - 1 downto 0 do
  begin
    B := TRelBox(FBoxes[I]);
    if (X >= B.X) and (X <= B.X + B.W) and (Y >= B.Y) and (Y < B.Y + HeaderH) then Exit(B);
  end;
end;

procedure TaRelationsView.PaintAll(Sender: TObject);
var
  C: TCanvas;
  I, J, Flag: Integer;
  B: TRelBox;
  P: array[0..3] of TPoint;
  Ty: Integer;
begin
  C := FPaint.Canvas;
  C.Brush.Color := clWhite;
  C.FillRect(0, 0, FPaint.Width, FPaint.Height);
  { relations first, boxes on top }
  for I := 0 to High(FRels) do
  begin
    RelPoints(FRels[I], P);
    if I = FSel then begin C.Pen.Color := clBlue; C.Pen.Width := 3; end
    else begin C.Pen.Color := clGray; C.Pen.Width := 1; end;
    C.MoveTo(P[0].X, P[0].Y);
    for J := 1 to 3 do C.LineTo(P[J].X, P[J].Y);
    C.Pen.Width := 1;
    C.Brush.Style := bsClear;
    C.Font.Color := clBlack;
    C.Font.Style := [fsBold];
    if P[3].X >= P[2].X then C.TextOut(P[3].X - 12, P[3].Y - 16, '1')
    else C.TextOut(P[3].X + 4, P[3].Y - 16, '1');
    if P[0].X >= P[1].X then C.TextOut(P[0].X - 14, P[0].Y - 16, 'N')
    else C.TextOut(P[0].X + 4, P[0].Y - 16, 'N');
    C.Font.Style := [];
  end;
  for I := 0 to FBoxes.Count - 1 do
  begin
    B := TRelBox(FBoxes[I]);
    C.Pen.Color := clBlack;
    C.Brush.Color := clWhite;
    C.Brush.Style := bsSolid;
    C.Rectangle(B.X, B.Y, B.X + B.W, B.Y + B.H);
    C.Brush.Color := clNavy;
    C.FillRect(B.X + 1, B.Y + 1, B.X + B.W, B.Y + HeaderH);
    C.Font.Color := clWhite;
    C.Font.Style := [fsBold];
    C.TextOut(B.X + 8, B.Y + 3, B.Name);
    C.Brush.Color := clWhite;
    C.Font.Color := clBlack;
    for J := 0 to B.Fields.Count - 1 do
    begin
      Flag := PtrInt(B.Fields.Objects[J]);
      Ty := B.Y + HeaderH + J * RowH + 1;
      if (Flag and 1) <> 0 then C.Font.Style := [fsBold] else C.Font.Style := [];
      if (Flag and 2) <> 0 then C.Font.Style := C.Font.Style + [fsItalic];
      if (Flag and 1) <> 0 then C.TextOut(B.X + 4, Ty, '*');
      C.TextOut(B.X + 16, Ty, B.Fields[J]);
    end;
    C.Font.Style := [];
  end;
  if FLinking and (FLinkBox <> nil) then
  begin
    C.Pen.Color := clRed;
    C.Pen.Width := 2;
    C.MoveTo(FLinkBox.X + FLinkBox.W, FieldRowY(FLinkBox, FLinkField));
    C.LineTo(FMouse.X, FMouse.Y);
    C.Pen.Width := 1;
  end;
end;

procedure TaRelationsView.MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
var
  B: TRelBox;
  F: Integer;
begin
  if Button <> mbLeft then Exit;
  if HitField(X, Y, B, F) then
  begin
    FLinking := True;
    FLinkBox := B;
    FLinkField := F;
    FMouse := Point(X, Y);
    Exit;
  end;
  B := HitHeader(X, Y);
  if B <> nil then
  begin
    FDragBox := B;
    FDragDX := X - B.X;
    FDragDY := Y - B.Y;
    { bring to front }
    FBoxes.Extract(B);
    FBoxes.Add(B);
    Exit;
  end;
  FSel := HitRelation(X, Y);
  FPaint.Invalidate;
end;

procedure TaRelationsView.MouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  FMouse := Point(X, Y);
  if FDragBox <> nil then
  begin
    FDragBox.X := X - FDragDX;
    FDragBox.Y := Y - FDragDY;
    if FDragBox.X < 0 then FDragBox.X := 0;
    if FDragBox.Y < 0 then FDragBox.Y := 0;
    FPaint.Invalidate;
  end
  else if FLinking then FPaint.Invalidate;
end;

procedure TaRelationsView.MouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
var
  B: TRelBox;
  F: Integer;
begin
  FDragBox := nil;
  if FLinking then
  begin
    FLinking := False;
    if HitField(X, Y, B, F) and not ((B = FLinkBox) and (F = FLinkField)) then
      CreateRelation(FLinkBox, FLinkField, B, F);
    FLinkBox := nil;
    FPaint.Invalidate;
  end;
end;

function TaRelationsView.AskCascade(const ADescription: string; var AOnDelete: string): Boolean;
var
  F: TForm;
  Cb: TComboBox;
begin
  Result := False;
  F := TForm.CreateNew(Self);
  try
    F.Caption := Tr('Link');
    F.SetBounds(0, 0, 480, 190);
    F.Position := poOwnerFormCenter;
    with TLabel.Create(F) do begin Parent := F; Caption := ADescription; SetBounds(14, 14, 450, 36); WordWrap := True; end;
    with TLabel.Create(F) do begin Parent := F; Caption := Tr('On delete:'); SetBounds(14, 68, 90, 18); end;
    Cb := TComboBox.Create(F); Cb.Parent := F; Cb.SetBounds(110, 64, 200, 26); Cb.Style := csDropDownList;
    Cb.Items.CommaText := 'NO ACTION,CASCADE,SET NULL,RESTRICT';
    Cb.ItemIndex := Cb.Items.IndexOf(AOnDelete);
    if Cb.ItemIndex < 0 then Cb.ItemIndex := 0;
    with TButton.Create(F) do begin Parent := F; Caption := Tr('OK'); ModalResult := mrOk; SetBounds(290, 120, 90, 28); end;
    with TButton.Create(F) do begin Parent := F; Caption := Tr('Cancel'); ModalResult := mrCancel; SetBounds(386, 120, 80, 28); end;
    if F.ShowModal = mrOk then
    begin
      AOnDelete := Cb.Text;
      Result := True;
    end;
  finally
    F.Free;
  end;
end;

procedure TaRelationsView.CreateRelation(AFrom: TRelBox; AFromField: Integer; ATo: TRelBox;
  AToField: Integer);
var
  Child, Par: TRelBox;
  ChildCol, ParentCol, OnDel: string;
  FromPk, ToPk: Boolean;
  Fks: TaFkDefs;
  I: Integer;
begin
  FromPk := (PtrInt(AFrom.Fields.Objects[AFromField]) and 1) <> 0;
  ToPk := (PtrInt(ATo.Fields.Objects[AToField]) and 1) <> 0;
  if ToPk and not FromPk then
  begin
    Child := AFrom; ChildCol := AFrom.Fields[AFromField];
    Par := ATo; ParentCol := ATo.Fields[AToField];
  end
  else if FromPk and not ToPk then
  begin
    Child := ATo; ChildCol := ATo.Fields[AToField];
    Par := AFrom; ParentCol := AFrom.Fields[AFromField];
  end
  else
  begin
    Child := AFrom; ChildCol := AFrom.Fields[AFromField];
    Par := ATo; ParentCol := ATo.Fields[AToField];
  end;
  OnDel := 'NO ACTION';
  if not AskCascade(Format(Tr('%s.%s  ->  %s.%s (one to many)'), [Child.Name, ChildCol, Par.Name, ParentCol]), OnDel) then
    Exit;
  Fks := FDb.GetFks(Child.Name);
  for I := High(Fks) downto 0 do
    if SameText(Fks[I].FromCol, ChildCol) then
    begin
      Fks[I] := Fks[High(Fks)];
      SetLength(Fks, Length(Fks) - 1);
    end;
  SetLength(Fks, Length(Fks) + 1);
  Fks[High(Fks)].FromCol := ChildCol;
  Fks[High(Fks)].RefTable := Par.Name;
  Fks[High(Fks)].RefCol := ParentCol;
  Fks[High(Fks)].OnDelete := OnDel;
  Fks[High(Fks)].OnUpdate := '';
  try
    FDb.SetFks(Child.Name, Fks);
  except
    on E: Exception do begin ShowMessage(E.Message); Exit; end;
  end;
  SaveLayout;
  LoadAll;
end;

procedure TaRelationsView.RemoveRelation(AIndex: Integer);
var
  R: TaRelation;
  Fks: TaFkDefs;
  I: Integer;
begin
  if (AIndex < 0) or (AIndex > High(FRels)) then Exit;
  R := FRels[AIndex];
  if MessageDlg(Format(Tr('Delete the link %s.%s -> %s.%s?'), [R.Child, R.ChildCol, R.Parent, R.ParentCol]),
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  Fks := FDb.GetFks(R.Child);
  for I := High(Fks) downto 0 do
    if SameText(Fks[I].FromCol, R.ChildCol) then
    begin
      Fks[I] := Fks[High(Fks)];
      SetLength(Fks, Length(Fks) - 1);
    end;
  try
    FDb.SetFks(R.Child, Fks);
  except
    on E: Exception do begin ShowMessage(E.Message); Exit; end;
  end;
  FSel := -1;
  SaveLayout;
  LoadAll;
end;

procedure TaRelationsView.DblClick(Sender: TObject);
var
  I: Integer;
  R: TaRelation;
  OnDel: string;
  Fks: TaFkDefs;
begin
  I := HitRelation(FMouse.X, FMouse.Y);
  if I < 0 then Exit;
  R := FRels[I];
  OnDel := R.OnDelete;
  if not AskCascade(Format('%s.%s  →  %s.%s', [R.Child, R.ChildCol, R.Parent, R.ParentCol]), OnDel) then Exit;
  Fks := FDb.GetFks(R.Child);
  for I := 0 to High(Fks) do
    if SameText(Fks[I].FromCol, R.ChildCol) then Fks[I].OnDelete := OnDel;
  try
    FDb.SetFks(R.Child, Fks);
  except
    on E: Exception do begin ShowMessage(E.Message); Exit; end;
  end;
  SaveLayout;
  LoadAll;
end;

procedure TaRelationsView.KeyDownEv(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = 46) and (FSel >= 0) then RemoveRelation(FSel);   { Delete }
end;

procedure TaRelationsView.RefreshClick(Sender: TObject);
begin
  SaveLayout;
  LoadAll;
end;

procedure TaRelationsView.AutoClick(Sender: TObject);
begin
  AutoLayout;
  FPaint.Invalidate;
end;

procedure TaRelationsView.DeleteClick(Sender: TObject);
begin
  if FSel < 0 then ShowMessage(Tr('Click the link line to select it.'))
  else RemoveRelation(FSel);
end;

end.
