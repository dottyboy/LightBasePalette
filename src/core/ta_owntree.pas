unit ta_owntree;
{ Vlastito stablo (pruzatelj 'own', varijanta tree obitelji List): crta se samo, pa izgleda i radi isto na svakom sucelju.
  Stavke su cvorovi s razinom; roditelj s djecom ima trokut za otvaranje i zatvaranje. Na pocetku je sve otvoreno.
  Tipke: Gore/Dolje, Lijevo (zatvori ili na roditelja), Desno (otvori ili na prvo dijete), Home/End, + i -, * otvara sve, PgUp/PgDn.
  Mis: klik na trokut otvara/zatvara, klik na redak oznacuje, dvoklik otvara/zatvara. Kotacic i klizac pomicu stablo. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, LCLType, ta_family, ta_list;

type
  TaOwnTree = class(TCustomControl)
  private
    FCap: TStringList;
    FParent: array of Integer;
    FLevel: array of Integer;
    FOpen: array of Boolean;
    FKids: array of Integer;
    FVis: array of Integer;       { indeksi vidljivih cvorova po redu }
    FCur, FTop: Integer;          { FCur je indeks cvora, ne retka }
    FReadOnly, FSetting: Boolean;
    FOnChange: TNotifyEvent;
    function RowH: Integer;
    function Rows: Integer;
    function GetCount: Integer;
    function GetOpen(AIndex: Integer): Boolean;
    procedure SetOpen(AIndex: Integer; AValue: Boolean);
    function GetLevel(AIndex: Integer): Integer;
    function GetHasKids(AIndex: Integer): Boolean;
    procedure SetCur(AValue: Integer);
    procedure Rebuild;
    function RowOf(ANode: Integer): Integer;
    procedure EnsureVisible;
    procedure Notify;
    procedure GoRow(ARow: Integer);
    procedure ThumbTo(Y: Integer);
  protected
    procedure Paint; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure DblClick; override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
    procedure DoEnter; override;
    procedure DoExit; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Clear;
    { dodaje cvor; AParent je indeks ranije dodanog cvora ili -1 }
    function AddNode(const ACaption: string; AParent: Integer): Integer;
    procedure ExpandAll;
    procedure CollapseAll;
    function Caption(AIndex: Integer): string;
    function VisibleCount: Integer;
    property Count: Integer read GetCount;
    property ItemIndex: Integer read FCur write SetCur;
    property Expanded[AIndex: Integer]: Boolean read GetOpen write SetOpen;
    property Level[AIndex: Integer]: Integer read GetLevel;
    property HasKids[AIndex: Integer]: Boolean read GetHasKids;
    property ReadOnly: Boolean read FReadOnly write FReadOnly;
    { tihe promjene (bez OnChange) pri postavljanju iz pokretaca }
    property Quiet: Boolean read FSetting write FSetting;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

  TaOwnTreeEngine = class(TaListEngine)
  private
    FTree: TaOwnTree;
  public
    constructor Create(AHost: TaFamilyHost); override;
    class function Provider: string; override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
    procedure SetItems(AItems: TStrings); override;
    procedure SetReadOnly(AValue: Boolean); override;
  end;

implementation

uses
  Math, ta_tokens;

const
  PadX = 6;
  BarW = 10;
  Indent = 18;

constructor TaOwnTree.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ApplyThemeFont(Font);
  ControlStyle := ControlStyle + [csOpaque, csCaptureMouse, csClickEvents, csDoubleClicks];
  TabStop := True;
  Width := 180;
  Height := 140;
  FCap := TStringList.Create;
  FCur := -1;
end;

destructor TaOwnTree.Destroy;
begin
  FCap.Free;
  inherited Destroy;
end;

function TaOwnTree.RowH: Integer;
begin
  Canvas.Font.Assign(Font);
  Result := Canvas.TextHeight('Ag') + 8;
end;

function TaOwnTree.Rows: Integer;
begin
  Result := Max(1, (Height - 4) div RowH);
end;

function TaOwnTree.GetCount: Integer;
begin
  Result := FCap.Count;
end;

function TaOwnTree.VisibleCount: Integer;
begin
  Result := Length(FVis);
end;

function TaOwnTree.Caption(AIndex: Integer): string;
begin
  Result := FCap[AIndex];
end;

function TaOwnTree.GetOpen(AIndex: Integer): Boolean;
begin
  Result := (AIndex >= 0) and (AIndex < Length(FOpen)) and FOpen[AIndex];
end;

function TaOwnTree.GetLevel(AIndex: Integer): Integer;
begin
  Result := FLevel[AIndex];
end;

function TaOwnTree.GetHasKids(AIndex: Integer): Boolean;
begin
  Result := FKids[AIndex] > 0;
end;

procedure TaOwnTree.Clear;
begin
  FCap.Clear;
  SetLength(FParent, 0);
  SetLength(FLevel, 0);
  SetLength(FOpen, 0);
  SetLength(FKids, 0);
  SetLength(FVis, 0);
  FCur := -1;
  FTop := 0;
  Invalidate;
end;

function TaOwnTree.AddNode(const ACaption: string; AParent: Integer): Integer;
var
  N: Integer;
begin
  N := FCap.Add(ACaption);
  SetLength(FParent, N + 1);
  SetLength(FLevel, N + 1);
  SetLength(FOpen, N + 1);
  SetLength(FKids, N + 1);
  if (AParent < 0) or (AParent >= N) then AParent := -1;
  FParent[N] := AParent;
  if AParent >= 0 then
  begin
    FLevel[N] := FLevel[AParent] + 1;
    Inc(FKids[AParent]);
  end
  else FLevel[N] := 0;
  FOpen[N] := True;
  FKids[N] := 0;
  Rebuild;
  Result := N;
end;

procedure TaOwnTree.Rebuild;
var
  I, N: Integer;
  Shown: array of Boolean;
begin
  SetLength(Shown, FCap.Count);
  SetLength(FVis, 0);
  N := 0;
  for I := 0 to FCap.Count - 1 do
  begin
    Shown[I] := (FParent[I] < 0) or (Shown[FParent[I]] and FOpen[FParent[I]]);
    if Shown[I] then
    begin
      SetLength(FVis, N + 1);
      FVis[N] := I;
      Inc(N);
    end;
  end;
  Invalidate;
end;

function TaOwnTree.RowOf(ANode: Integer): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(FVis) do if FVis[I] = ANode then Exit(I);
end;

procedure TaOwnTree.SetOpen(AIndex: Integer; AValue: Boolean);
var
  A: Integer;
begin
  if (AIndex < 0) or (AIndex >= FCap.Count) or (FOpen[AIndex] = AValue) then Exit;
  FOpen[AIndex] := AValue;
  { zatvaranjem se oznaceni potomak vraca na zatvoreni cvor }
  if (not AValue) and (FCur >= 0) then
  begin
    A := FParent[FCur];
    while A >= 0 do
    begin
      if A = AIndex then begin SetCur(AIndex); Break; end;
      A := FParent[A];
    end;
  end;
  Rebuild;
  EnsureVisible;
end;

procedure TaOwnTree.ExpandAll;
var
  I: Integer;
begin
  for I := 0 to High(FOpen) do FOpen[I] := True;
  Rebuild;
end;

procedure TaOwnTree.CollapseAll;
var
  I: Integer;
begin
  for I := 0 to High(FOpen) do FOpen[I] := False;
  if (FCur >= 0) and (FParent[FCur] >= 0) then
  begin
    while FParent[FCur] >= 0 do FCur := FParent[FCur];
  end;
  Rebuild;
end;

procedure TaOwnTree.Notify;
begin
  if (not FSetting) and Assigned(FOnChange) then FOnChange(Self);
end;

procedure TaOwnTree.SetCur(AValue: Integer);
var
  A: Integer;
begin
  if (AValue < -1) or (AValue >= FCap.Count) then AValue := -1;
  { oznaceni cvor mora biti vidljiv: otvori roditelje }
  if AValue >= 0 then
  begin
    A := FParent[AValue];
    while A >= 0 do
    begin
      FOpen[A] := True;
      A := FParent[A];
    end;
    Rebuild;
  end;
  if FCur = AValue then Exit;
  FCur := AValue;
  EnsureVisible;
  Invalidate;
  Notify;
end;

procedure TaOwnTree.EnsureVisible;
var
  R: Integer;
begin
  R := RowOf(FCur);
  if R < 0 then Exit;
  if R < FTop then FTop := R
  else if R >= FTop + Rows then FTop := R - Rows + 1;
  FTop := Max(0, Min(FTop, Max(0, Length(FVis) - Rows)));
end;

procedure TaOwnTree.GoRow(ARow: Integer);
begin
  if Length(FVis) = 0 then Exit;
  ARow := Max(0, Min(High(FVis), ARow));
  if FReadOnly then Exit;
  SetCur(FVis[ARow]);
end;

procedure TaOwnTree.Paint;
var
  T: TaThemeTokens;
  I, Y, Rh, R, X, Node, ThH, ThY, Cx, Cy: Integer;
  Bg, Br, Tx: TColor;
  Foc, Over, Sel: Boolean;
begin
  T := ActiveTokens;
  Foc := Focused;
  if Enabled and not FReadOnly then Bg := TokenColor(T.Surface) else Bg := TokenColor(T.Soft);
  if Foc then Br := TokenColor(T.Accent) else Br := TokenColor(T.Border);
  R := Min(T.RadiusField, Height div 2);
  if Parent <> nil then Canvas.Brush.Color := Parent.Color else Canvas.Brush.Color := Bg;
  Canvas.Pen.Style := psClear;
  Canvas.FillRect(0, 0, Width, Height);
  Canvas.Pen.Style := psSolid;
  Canvas.Brush.Color := Bg;
  Canvas.Pen.Color := Br;
  if Foc then Canvas.Pen.Width := 2 else Canvas.Pen.Width := 1;
  if R > 0 then Canvas.RoundRect(0, 0, Width, Height, R * 2, R * 2) else Canvas.Rectangle(0, 0, Width, Height);
  Canvas.Pen.Width := 1;
  Canvas.Font.Assign(Font);
  Rh := RowH;
  Over := Length(FVis) > Rows;
  Canvas.ClipRect := Rect(2, 2, Width - 2, Height - 2);
  Canvas.Clipping := True;
  for I := FTop to Min(High(FVis), FTop + Rows) do
  begin
    Node := FVis[I];
    Y := 2 + (I - FTop) * Rh;
    X := PadX + FLevel[Node] * Indent;
    Sel := Node = FCur;
    if Sel then
    begin
      if Foc then Canvas.Brush.Color := TokenColor(T.Accent) else Canvas.Brush.Color := TokenColor(T.AccentSoft);
      Canvas.Pen.Style := psClear;
      Canvas.FillRect(3, Y, Width - 3 - Ord(Over) * BarW, Y + Rh);
      Canvas.Pen.Style := psSolid;
      if Foc then Tx := TokenColor(T.OnAccent) else Tx := TokenColor(T.Text);
    end
    else Tx := TokenColor(T.Text);
    if not Enabled then Tx := TokenColor(T.TextSoft);
    { trokut }
    if FKids[Node] > 0 then
    begin
      Cx := X + 6;
      Cy := Y + Rh div 2;
      Canvas.Brush.Style := bsSolid;
      if Sel and Foc then Canvas.Brush.Color := TokenColor(T.OnAccent) else Canvas.Brush.Color := TokenColor(T.TextSoft);
      Canvas.Pen.Color := Canvas.Brush.Color;
      if FOpen[Node] then Canvas.Polygon([Point(Cx - 4, Cy - 2), Point(Cx + 4, Cy - 2), Point(Cx, Cy + 3)])
      else Canvas.Polygon([Point(Cx - 2, Cy - 4), Point(Cx - 2, Cy + 4), Point(Cx + 3, Cy)]);
    end;
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Color := Tx;
    Canvas.TextOut(X + 16, Y + (Rh - Canvas.TextHeight('Ag')) div 2, FCap[Node]);
    Canvas.Brush.Style := bsSolid;
  end;
  Canvas.Clipping := False;
  if Over then
  begin
    ThH := Max(18, (Height - 6) * Rows div Length(FVis));
    ThY := 3 + (Height - 6 - ThH) * FTop div Max(1, Length(FVis) - Rows);
    Canvas.Brush.Color := TokenColor(T.Border);
    Canvas.Pen.Style := psClear;
    Canvas.RoundRect(Width - BarW - 1, ThY, Width - 3, ThY + ThH, 4, 4);
    Canvas.Pen.Style := psSolid;
  end;
end;

procedure TaOwnTree.KeyDown(var Key: Word; Shift: TShiftState);
var
  R, I: Integer;
begin
  inherited KeyDown(Key, Shift);
  if Key = 0 then Exit;
  R := RowOf(FCur);
  case Key of
    VK_UP: begin GoRow(R - 1); Key := 0; end;
    VK_DOWN: begin if R < 0 then GoRow(0) else GoRow(R + 1); Key := 0; end;
    VK_PRIOR: begin GoRow(R - Rows); Key := 0; end;
    VK_NEXT: begin GoRow(R + Rows); Key := 0; end;
    VK_HOME: begin GoRow(0); Key := 0; end;
    VK_END: begin GoRow(High(FVis)); Key := 0; end;
    VK_LEFT:
      begin
        if FCur >= 0 then
          if (FKids[FCur] > 0) and FOpen[FCur] then SetOpen(FCur, False)
          else if (FParent[FCur] >= 0) and not FReadOnly then SetCur(FParent[FCur]);
        Key := 0;
      end;
    VK_RIGHT:
      begin
        if FCur >= 0 then
          if (FKids[FCur] > 0) and not FOpen[FCur] then SetOpen(FCur, True)
          else if (FKids[FCur] > 0) and not FReadOnly then SetCur(FCur + 1);
        Key := 0;
      end;
    VK_ADD: begin SetOpen(FCur, True); Key := 0; end;
    VK_SUBTRACT: begin SetOpen(FCur, False); Key := 0; end;
    VK_MULTIPLY: begin ExpandAll; Key := 0; end;
    VK_SPACE, VK_RETURN:
      begin
        if (FCur >= 0) and (FKids[FCur] > 0) then SetOpen(FCur, not FOpen[FCur]);
        Key := 0;
      end;
  end;
  I := 0;
  if I = 1 then Exit;
end;

procedure TaOwnTree.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Row, Node, Tx: Integer;
begin
  inherited MouseDown(Button, Shift, X, Y);
  if not Focused then SetFocus;
  if Button <> mbLeft then Exit;
  if (X >= Width - BarW - 2) and (Length(FVis) > Rows) then
  begin
    ThumbTo(Y);
    Exit;
  end;
  Row := FTop + (Y - 2) div RowH;
  if (Row < 0) or (Row > High(FVis)) then Exit;
  Node := FVis[Row];
  Tx := PadX + FLevel[Node] * Indent;
  if (FKids[Node] > 0) and (X >= Tx) and (X < Tx + 14) then
  begin
    SetOpen(Node, not FOpen[Node]);
    Exit;
  end;
  if not FReadOnly then SetCur(Node);
end;

procedure TaOwnTree.DblClick;
var
  M: TPoint;
  Row: Integer;
begin
  inherited DblClick;
  M := ScreenToClient(Mouse.CursorPos);
  Row := FTop + (M.Y - 2) div RowH;
  if (Row >= 0) and (Row <= High(FVis)) and (FKids[FVis[Row]] > 0) then SetOpen(FVis[Row], not FOpen[FVis[Row]]);
end;

procedure TaOwnTree.ThumbTo(Y: Integer);
var
  Span: Integer;
begin
  Span := Length(FVis) - Rows;
  if Span <= 0 then Exit;
  FTop := Max(0, Min(Span, Round((Y - 3) / Max(1, Height - 6) * Length(FVis) - Rows / 2)));
  Invalidate;
end;

function TaOwnTree.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
var
  Span: Integer;
begin
  Span := Length(FVis) - Rows;
  Result := Span > 0;
  if Result then
  begin
    if WheelDelta > 0 then Dec(FTop, 3) else Inc(FTop, 3);
    FTop := Max(0, Min(Span, FTop));
    Invalidate;
  end;
end;

procedure TaOwnTree.DoEnter;
begin
  inherited DoEnter;
  Invalidate;
end;

procedure TaOwnTree.DoExit;
begin
  inherited DoExit;
  Invalidate;
end;

procedure TaOwnTree.Resize;
begin
  inherited Resize;
  if Parent <> nil then EnsureVisible;
end;

{ ---------------- pokretac ---------------- }

constructor TaOwnTreeEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FTree := TaOwnTree.Create(nil);
  FTree.OnChange := @InnerChanged;
  AttachInner(FTree);
end;

class function TaOwnTreeEngine.Provider: string;
begin
  Result := 'own';
end;

function TaOwnTreeEngine.GetText: string;
begin
  Result := KeyAt(FTree.ItemIndex);
end;

procedure TaOwnTreeEngine.SetText(const AValue: string);
begin
  FTree.Quiet := True;
  try
    FTree.ItemIndex := IndexOfKey(AValue);
  finally
    FTree.Quiet := False;
  end;
end;

procedure TaOwnTreeEngine.SetItems(AItems: TStrings);
var
  Lb: TStringList;
  Lv: TList;
  Keep: string;
  I, Level: Integer;
  Last: array of Integer;
  Par: Integer;
begin
  Keep := GetText;
  Lb := TStringList.Create;
  Lv := TList.Create;
  try
    ParseItems(AItems, Lb, Lv);
    FTree.Quiet := True;
    try
      FTree.Clear;
      SetLength(Last, Lb.Count + 1);
      for I := 0 to Lb.Count - 1 do
      begin
        Level := PtrInt(Lv[I]);
        if Level > I then Level := I;
        if Level > 0 then Par := Last[Level - 1] else Par := -1;
        if (Level > 0) and (Par < 0) then Level := 0;
        Last[Level] := FTree.AddNode(Lb[I], Par);
      end;
    finally
      FTree.Quiet := False;
    end;
  finally
    Lv.Free;
    Lb.Free;
  end;
  SetText(Keep);
end;

procedure TaOwnTreeEngine.SetReadOnly(AValue: Boolean);
begin
  inherited SetReadOnly(AValue);
  FTree.ReadOnly := AValue;
end;

initialization
  RegisterEngine(ListFamily, 'tree', TaOwnTreeEngine);

end.
