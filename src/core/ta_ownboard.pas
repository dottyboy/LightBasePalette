unit ta_ownboard;
{ Kanban ploca (vlastita kontrola): stupci s karticama. Stupac je jedna vrijednost polja (faza, status...), kartica je jedan redak.
  Povlacenje kartice u drugi stupac javlja OnMoveCard (korisnik tada mijenja polje u bazi); dvoklik ili Enter otvaraju karticu,
  gumb + u zaglavlju stupca trazi novu karticu u tom stupcu. Tipke: strelice biraju karticu, Alt+Lijevo/Desno premjesta je u susjedni stupac.
  Kotacic pomice stupac ispod pokazivaca, Shift+kotacic pomice plocu vodoravno kad se stupci ne mogu svi vidjeti.
  Ne zna podatke: puni se pozivima Clear, AddColumn i AddCard (vidi ta_formboard). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, LCLType, LazUTF8;

type
  TaBoardMoveEvent = procedure(Sender: TObject; const ACardId, ANewColKey: string; var AAllow: Boolean) of object;
  TaBoardCardEvent = procedure(Sender: TObject; const ACardId: string) of object;
  TaBoardColEvent = procedure(Sender: TObject; const AColKey: string) of object;

  TaBoardCard = class
  public
    Id, ColKey, Title: string;
    Lines: TStringList;
    Col: Integer;
    constructor Create;
    destructor Destroy; override;
  end;

  TaBoardColumn = class
  public
    Key, Caption: string;
    Cards: TList;            { TaBoardCard po redu }
    Top: Integer;            { pomak okomito }
    constructor Create;
    destructor Destroy; override;
  end;

  TaOwnBoard = class(TCustomControl)
  private
    FCols: TList;
    FCards: TList;
    FSelId: string;
    FScrollX, FHoverCol: Integer;
    FDownId: string;
    FDownX, FDownY, FDragX, FDragY, FDropCol: Integer;
    FDragging, FReadOnly, FAllowAdd: Boolean;
    FOnMove: TaBoardMoveEvent;
    FOnOpen: TaBoardCardEvent;
    FOnSelect: TaBoardCardEvent;
    FOnAdd: TaBoardColEvent;
    FLineH: Integer;
    function GetColCount: Integer;
    function GetCardCount: Integer;
    function ColW: Integer;
    function ColX(AIndex: Integer): Integer;
    function ContentW: Integer;
    function HeaderH: Integer;
    function CardH(ACard: TaBoardCard): Integer;
    function CardRect(ACol: TaBoardColumn; AIndex: Integer): TRect;
    function ColAt(X: Integer): Integer;
    function CardAt(X, Y: Integer; out ACol, AIdx: Integer): TaBoardCard;
    function PlusRect(AIndex: Integer): TRect;
    function FindCard(const AId: string): TaBoardCard;
    function ColIndexOfKey(const AKey: string): Integer;
    procedure Distribute;
    procedure SelectCard(const AId: string);
    procedure EnsureVisible(ACard: TaBoardCard);
    procedure MoveSel(ADCol, ADRow: Integer);
    procedure ClampScroll;
    procedure DoMove(ACard: TaBoardCard; ANewCol: Integer);
    function MaxTop(ACol: TaBoardColumn): Integer;
  protected
    procedure Paint; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure DblClick; override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
    procedure DoEnter; override;
    procedure DoExit; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Clear;
    function AddColumn(const AKey, ACaption: string): Integer;
    { ALines: retci odvojeni novim retkom }
    procedure AddCard(const AId, AColKey, ATitle, ALines: string);
    procedure EndUpdate;
    function ColumnOfCard(const AId: string): string;
    function CardsIn(const AColKey: string): Integer;
    function ColumnKey(AIndex: Integer): string;
    property ColumnCount: Integer read GetColCount;
    property CardCount: Integer read GetCardCount;
    property SelectedId: string read FSelId write SelectCard;
    property ReadOnly: Boolean read FReadOnly write FReadOnly;
    property AllowAdd: Boolean read FAllowAdd write FAllowAdd;
    property OnMoveCard: TaBoardMoveEvent read FOnMove write FOnMove;
    property OnOpenCard: TaBoardCardEvent read FOnOpen write FOnOpen;
    property OnSelectCard: TaBoardCardEvent read FOnSelect write FOnSelect;
    property OnAddCard: TaBoardColEvent read FOnAdd write FOnAdd;
  end;

implementation

uses
  Math, ta_tokens;

const
  Gap = 8;
  PadX = 10;
  CardPad = 8;
  MinColW = 160;
  MaxColW = 280;

constructor TaBoardCard.Create;
begin
  Lines := TStringList.Create;
end;

destructor TaBoardCard.Destroy;
begin
  Lines.Free;
  inherited Destroy;
end;

constructor TaBoardColumn.Create;
begin
  Cards := TList.Create;
end;

destructor TaBoardColumn.Destroy;
begin
  Cards.Free;
  inherited Destroy;
end;

constructor TaOwnBoard.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ApplyThemeFont(Font);
  ControlStyle := ControlStyle + [csOpaque, csCaptureMouse, csClickEvents, csDoubleClicks];
  TabStop := True;
  Width := 600;
  Height := 360;
  FCols := TList.Create;
  FCards := TList.Create;
  FDropCol := -1;
  FHoverCol := -1;
  FAllowAdd := True;
end;

destructor TaOwnBoard.Destroy;
begin
  Clear;
  FCols.Free;
  FCards.Free;
  inherited Destroy;
end;

procedure TaOwnBoard.Clear;
var
  I: Integer;
begin
  for I := 0 to FCols.Count - 1 do TaBoardColumn(FCols[I]).Free;
  for I := 0 to FCards.Count - 1 do TaBoardCard(FCards[I]).Free;
  FCols.Clear;
  FCards.Clear;
  FScrollX := 0;
  Invalidate;
end;

function TaOwnBoard.GetColCount: Integer;
begin
  Result := FCols.Count;
end;

function TaOwnBoard.GetCardCount: Integer;
begin
  Result := FCards.Count;
end;

function TaOwnBoard.ColumnKey(AIndex: Integer): string;
begin
  Result := TaBoardColumn(FCols[AIndex]).Key;
end;

function TaOwnBoard.AddColumn(const AKey, ACaption: string): Integer;
var
  C: TaBoardColumn;
begin
  C := TaBoardColumn.Create;
  C.Key := AKey;
  C.Caption := ACaption;
  Result := FCols.Add(C);
end;

procedure TaOwnBoard.AddCard(const AId, AColKey, ATitle, ALines: string);
var
  C: TaBoardCard;
begin
  C := TaBoardCard.Create;
  C.Id := AId;
  C.ColKey := AColKey;
  C.Title := ATitle;
  C.Lines.Text := ALines;
  FCards.Add(C);
end;

function TaOwnBoard.ColIndexOfKey(const AKey: string): Integer;
var
  I: Integer;
begin
  for I := 0 to FCols.Count - 1 do
    if TaBoardColumn(FCols[I]).Key = AKey then Exit(I);
  Result := -1;
end;

procedure TaOwnBoard.Distribute;
var
  I, K: Integer;
  C: TaBoardCard;
begin
  for I := 0 to FCols.Count - 1 do TaBoardColumn(FCols[I]).Cards.Clear;
  for I := 0 to FCards.Count - 1 do
  begin
    C := TaBoardCard(FCards[I]);
    K := ColIndexOfKey(C.ColKey);
    C.Col := K;
    if K >= 0 then TaBoardColumn(FCols[K]).Cards.Add(C);
  end;
end;

procedure TaOwnBoard.EndUpdate;
begin
  Distribute;
  if (FSelId <> '') and (FindCard(FSelId) = nil) then FSelId := '';
  ClampScroll;
  Invalidate;
end;

function TaOwnBoard.FindCard(const AId: string): TaBoardCard;
var
  I: Integer;
begin
  for I := 0 to FCards.Count - 1 do
    if TaBoardCard(FCards[I]).Id = AId then Exit(TaBoardCard(FCards[I]));
  Result := nil;
end;

function TaOwnBoard.ColumnOfCard(const AId: string): string;
var
  C: TaBoardCard;
begin
  C := FindCard(AId);
  if C = nil then Result := '' else Result := C.ColKey;
end;

function TaOwnBoard.CardsIn(const AColKey: string): Integer;
var
  K: Integer;
begin
  K := ColIndexOfKey(AColKey);
  if K < 0 then Result := 0 else Result := TaBoardColumn(FCols[K]).Cards.Count;
end;

{ ---------------- geometrija ---------------- }

function TaOwnBoard.ColW: Integer;
var
  N: Integer;
begin
  N := Max(1, FCols.Count);
  Result := (Width - 2 * PadX - (N - 1) * Gap) div N;
  Result := Max(MinColW, Min(MaxColW, Result));
end;

function TaOwnBoard.ContentW: Integer;
begin
  Result := 2 * PadX + FCols.Count * ColW + Max(0, FCols.Count - 1) * Gap;
end;

function TaOwnBoard.ColX(AIndex: Integer): Integer;
begin
  Result := PadX + AIndex * (ColW + Gap) - FScrollX;
end;

function TaOwnBoard.HeaderH: Integer;
begin
  Canvas.Font.Assign(Font);
  Result := Canvas.TextHeight('Ag') + 16;
end;

function TaOwnBoard.CardH(ACard: TaBoardCard): Integer;
begin
  Canvas.Font.Assign(Font);
  FLineH := Canvas.TextHeight('Ag') + 2;
  Result := 2 * CardPad + FLineH + 2 + ACard.Lines.Count * FLineH;
end;

function TaOwnBoard.CardRect(ACol: TaBoardColumn; AIndex: Integer): TRect;
var
  I, Y: Integer;
  X0: Integer;
begin
  X0 := ColX(FCols.IndexOf(ACol));
  Y := HeaderH + 6 - ACol.Top;
  for I := 0 to AIndex - 1 do Inc(Y, CardH(TaBoardCard(ACol.Cards[I])) + 6);
  Result := Rect(X0 + 6, Y, X0 + ColW - 6, Y + CardH(TaBoardCard(ACol.Cards[AIndex])));
end;

function TaOwnBoard.PlusRect(AIndex: Integer): TRect;
var
  X: Integer;
begin
  X := ColX(AIndex) + ColW - 28;
  Result := Rect(X, 5, X + 22, HeaderH - 5);
end;

function TaOwnBoard.ColAt(X: Integer): Integer;
var
  I: Integer;
begin
  for I := 0 to FCols.Count - 1 do
    if (X >= ColX(I)) and (X < ColX(I) + ColW) then Exit(I);
  Result := -1;
end;

function TaOwnBoard.CardAt(X, Y: Integer; out ACol, AIdx: Integer): TaBoardCard;
var
  I: Integer;
  Col: TaBoardColumn;
  R: TRect;
begin
  Result := nil;
  ACol := ColAt(X);
  AIdx := -1;
  if ACol < 0 then Exit;
  Col := TaBoardColumn(FCols[ACol]);
  if Y < HeaderH then Exit;
  for I := 0 to Col.Cards.Count - 1 do
  begin
    R := CardRect(Col, I);
    if (Y >= R.Top) and (Y < R.Bottom) and (X >= R.Left) and (X < R.Right) then
    begin
      AIdx := I;
      Exit(TaBoardCard(Col.Cards[I]));
    end;
  end;
end;

function TaOwnBoard.MaxTop(ACol: TaBoardColumn): Integer;
var
  I, H: Integer;
begin
  H := 6;
  for I := 0 to ACol.Cards.Count - 1 do Inc(H, CardH(TaBoardCard(ACol.Cards[I])) + 6);
  Result := Max(0, H - (Height - HeaderH - 8));
end;

procedure TaOwnBoard.ClampScroll;
var
  I: Integer;
begin
  FScrollX := Max(0, Min(FScrollX, Max(0, ContentW - Width)));
  for I := 0 to FCols.Count - 1 do
    TaBoardColumn(FCols[I]).Top := Max(0, Min(TaBoardColumn(FCols[I]).Top, MaxTop(TaBoardColumn(FCols[I]))));
end;

procedure TaOwnBoard.Resize;
begin
  inherited Resize;
  if (Parent <> nil) and (FCols <> nil) then
  begin
    ClampScroll;
    Invalidate;
  end;
end;

{ ---------------- odabir ---------------- }

procedure TaOwnBoard.SelectCard(const AId: string);
var
  C: TaBoardCard;
begin
  if FSelId = AId then Exit;
  FSelId := AId;
  C := FindCard(AId);
  if C <> nil then EnsureVisible(C);
  Invalidate;
  if Assigned(FOnSelect) then FOnSelect(Self, AId);
end;

procedure TaOwnBoard.EnsureVisible(ACard: TaBoardCard);
var
  Col: TaBoardColumn;
  R: TRect;
  I: Integer;
begin
  if (ACard = nil) or (ACard.Col < 0) then Exit;
  Col := TaBoardColumn(FCols[ACard.Col]);
  I := Col.Cards.IndexOf(ACard);
  R := CardRect(Col, I);
  if R.Top < HeaderH + 4 then Dec(Col.Top, HeaderH + 4 - R.Top)
  else if R.Bottom > Height - 4 then Inc(Col.Top, R.Bottom - Height + 4);
  if ColX(ACard.Col) < 0 then FScrollX := Max(0, FScrollX + ColX(ACard.Col) - PadX)
  else if ColX(ACard.Col) + ColW > Width then FScrollX := FScrollX + ColX(ACard.Col) + ColW - Width + PadX;
  ClampScroll;
end;

procedure TaOwnBoard.MoveSel(ADCol, ADRow: Integer);
var
  C: TaBoardCard;
  K, I, J: Integer;
  Col: TaBoardColumn;
begin
  C := FindCard(FSelId);
  if C = nil then
  begin
    for I := 0 to FCols.Count - 1 do
      if TaBoardColumn(FCols[I]).Cards.Count > 0 then
      begin
        SelectCard(TaBoardCard(TaBoardColumn(FCols[I]).Cards[0]).Id);
        Exit;
      end;
    Exit;
  end;
  K := C.Col;
  Col := TaBoardColumn(FCols[K]);
  I := Col.Cards.IndexOf(C);
  if ADRow <> 0 then
  begin
    I := I + ADRow;
    if (I >= 0) and (I < Col.Cards.Count) then SelectCard(TaBoardCard(Col.Cards[I]).Id);
    Exit;
  end;
  { u susjedni stupac koji ima kartice, na isti redak ili zadnji }
  J := K + ADCol;
  while (J >= 0) and (J < FCols.Count) and (TaBoardColumn(FCols[J]).Cards.Count = 0) do Inc(J, ADCol);
  if (J >= 0) and (J < FCols.Count) then
  begin
    Col := TaBoardColumn(FCols[J]);
    SelectCard(TaBoardCard(Col.Cards[Min(I, Col.Cards.Count - 1)]).Id);
  end;
end;

procedure TaOwnBoard.DoMove(ACard: TaBoardCard; ANewCol: Integer);
var
  Allow: Boolean;
  NewKey: string;
begin
  if (ACard = nil) or (ANewCol < 0) or (ANewCol >= FCols.Count) or (ANewCol = ACard.Col) or FReadOnly then Exit;
  NewKey := TaBoardColumn(FCols[ANewCol]).Key;
  Allow := True;
  if Assigned(FOnMove) then FOnMove(Self, ACard.Id, NewKey, Allow);
  if Allow then
  begin
    ACard.ColKey := NewKey;
    Distribute;
    EnsureVisible(ACard);
  end;
  Invalidate;
end;

{ ---------------- crtanje ---------------- }

procedure TaOwnBoard.Paint;
var
  T: TaThemeTokens;
  I, K, Y, Lw: Integer;
  Col: TaBoardColumn;
  Card: TaBoardCard;
  R, Pr: TRect;
  Bg, Tx, Soft, Br, Acc: TColor;
  Sel, Foc: Boolean;
  S: string;
  Hh: Integer;

  function Fit(const AText: string; AW: Integer): string;
  begin
    Result := AText;
    while (UTF8Length(Result) > 1) and (Canvas.TextWidth(Result) > AW) do
      Result := UTF8Copy(Result, 1, UTF8Length(Result) - 2) + '…';
  end;

begin
  T := ActiveTokens;
  Foc := Focused;
  Bg := TokenColor(T.Surface);
  Soft := TokenColor(T.Soft);
  Br := TokenColor(T.Border);
  Tx := TokenColor(T.Text);
  Acc := TokenColor(T.Accent);
  Canvas.Brush.Color := TokenColor(T.Bg);
  Canvas.Pen.Style := psClear;
  Canvas.FillRect(0, 0, Width, Height);
  Canvas.Pen.Style := psSolid;
  Canvas.Font.Assign(Font);
  Hh := HeaderH;
  for I := 0 to FCols.Count - 1 do
  begin
    Col := TaBoardColumn(FCols[I]);
    R := Rect(ColX(I), 4, ColX(I) + ColW, Height - 4);
    if (R.Right < 0) or (R.Left > Width) then Continue;
    { stupac }
    Canvas.Brush.Color := Soft;
    if (FDragging) and (FDropCol = I) then Canvas.Pen.Color := Acc else Canvas.Pen.Color := Br;
    if (FDragging) and (FDropCol = I) then Canvas.Pen.Width := 2 else Canvas.Pen.Width := 1;
    Canvas.RoundRect(R.Left, R.Top, R.Right, R.Bottom, 10, 10);
    Canvas.Pen.Width := 1;
    { zaglavlje }
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Style := [fsBold];
    Canvas.Font.Color := Tx;
    Canvas.TextOut(R.Left + 10, R.Top + (Hh - 4 - Canvas.TextHeight('Ag')) div 2 + 2, Fit(Col.Caption, ColW - 70));
    Lw := Canvas.TextWidth(Fit(Col.Caption, ColW - 70));
    Canvas.Font.Style := [];
    Canvas.Font.Color := TokenColor(T.TextSoft);
    Canvas.TextOut(R.Left + 10 + Lw + 8, R.Top + (Hh - 4 - Canvas.TextHeight('Ag')) div 2 + 2, IntToStr(Col.Cards.Count));
    if FAllowAdd and not FReadOnly and (Col.Key <> '') then
    begin
      Pr := PlusRect(I);
      Canvas.Font.Style := [fsBold];
      Canvas.Font.Color := Acc;
      Canvas.TextOut(Pr.Left + (Pr.Right - Pr.Left - Canvas.TextWidth('+')) div 2, Pr.Top + 1, '+');
      Canvas.Font.Style := [];
    end;
    Canvas.Brush.Style := bsSolid;
    { kartice }
    Canvas.ClipRect := Rect(R.Left + 1, R.Top + Hh, R.Right - 1, R.Bottom - 1);
    Canvas.Clipping := True;
    for K := 0 to Col.Cards.Count - 1 do
    begin
      Card := TaBoardCard(Col.Cards[K]);
      Pr := CardRect(Col, K);
      if (Pr.Bottom < 0) or (Pr.Top > Height) then Continue;
      Sel := Card.Id = FSelId;
      if FDragging and (Card.Id = FDownId) then Canvas.Brush.Color := Soft
      else if Sel then Canvas.Brush.Color := TokenColor(T.AccentSoft)
      else Canvas.Brush.Color := Bg;
      if Sel and Foc then Canvas.Pen.Color := Acc else Canvas.Pen.Color := Br;
      if Sel then Canvas.Pen.Width := 2;
      Canvas.RoundRect(Pr.Left, Pr.Top, Pr.Right, Pr.Bottom, 8, 8);
      Canvas.Pen.Width := 1;
      if FDragging and (Card.Id = FDownId) then Continue;
      Canvas.Brush.Style := bsClear;
      Canvas.Font.Style := [fsBold];
      Canvas.Font.Color := Tx;
      Canvas.TextOut(Pr.Left + CardPad, Pr.Top + CardPad, Fit(Card.Title, Pr.Right - Pr.Left - 2 * CardPad));
      Canvas.Font.Style := [];
      Canvas.Font.Color := TokenColor(T.TextSoft);
      Y := Pr.Top + CardPad + FLineH + 2;
      for S in Card.Lines do
      begin
        Canvas.TextOut(Pr.Left + CardPad, Y, Fit(S, Pr.Right - Pr.Left - 2 * CardPad));
        Inc(Y, FLineH);
      end;
      Canvas.Brush.Style := bsSolid;
    end;
    Canvas.Clipping := False;
    { klizac stupca }
    if MaxTop(Col) > 0 then
    begin
      K := Max(18, (R.Bottom - R.Top - Hh) * (Height - Hh) div (MaxTop(Col) + Height - Hh));
      Y := R.Top + Hh + (R.Bottom - R.Top - Hh - K - 4) * Col.Top div MaxTop(Col);
      Canvas.Brush.Color := Br;
      Canvas.Pen.Style := psClear;
      Canvas.RoundRect(R.Right - 7, Y, R.Right - 3, Y + K, 3, 3);
      Canvas.Pen.Style := psSolid;
    end;
  end;
  { kartica koja se vuce }
  if FDragging then
  begin
    Card := FindCard(FDownId);
    if Card <> nil then
    begin
      Canvas.Brush.Color := TokenColor(T.AccentSoft);
      Canvas.Pen.Color := Acc;
      Canvas.Pen.Width := 2;
      Canvas.RoundRect(FDragX - ColW div 2 + 6, FDragY - 14, FDragX + ColW div 2 - 6, FDragY - 14 + CardH(Card), 8, 8);
      Canvas.Pen.Width := 1;
      Canvas.Brush.Style := bsClear;
      Canvas.Font.Style := [fsBold];
      Canvas.Font.Color := Tx;
      Canvas.TextOut(FDragX - ColW div 2 + 6 + CardPad, FDragY - 14 + CardPad, Fit(Card.Title, ColW - 12 - 2 * CardPad));
      Canvas.Font.Style := [];
      Canvas.Brush.Style := bsSolid;
    end;
  end;
  { vodoravni klizac kad se stupci ne mogu svi vidjeti }
  if ContentW > Width then
  begin
    Lw := Max(24, Width * Width div ContentW);
    Y := (Width - Lw) * FScrollX div Max(1, ContentW - Width);
    Canvas.Brush.Color := Br;
    Canvas.Pen.Style := psClear;
    Canvas.RoundRect(Y, Height - 7, Y + Lw, Height - 3, 3, 3);
    Canvas.Pen.Style := psSolid;
  end;
  if Foc then
  begin
    Canvas.Brush.Style := bsClear;
    Canvas.Pen.Color := Acc;
    Canvas.Rectangle(0, 0, Width, Height);
    Canvas.Brush.Style := bsSolid;
  end;
end;

{ ---------------- tipkovnica ---------------- }

procedure TaOwnBoard.KeyDown(var Key: Word; Shift: TShiftState);
var
  C: TaBoardCard;
begin
  inherited KeyDown(Key, Shift);
  if Key = 0 then Exit;
  case Key of
    VK_UP: begin MoveSel(0, -1); Key := 0; end;
    VK_DOWN: begin MoveSel(0, 1); Key := 0; end;
    VK_LEFT:
      begin
        if ssAlt in Shift then
        begin
          C := FindCard(FSelId);
          if C <> nil then DoMove(C, C.Col - 1);
        end
        else MoveSel(-1, 0);
        Key := 0;
      end;
    VK_RIGHT:
      begin
        if ssAlt in Shift then
        begin
          C := FindCard(FSelId);
          if C <> nil then DoMove(C, C.Col + 1);
        end
        else MoveSel(1, 0);
        Key := 0;
      end;
    VK_RETURN:
      begin
        if (FSelId <> '') and Assigned(FOnOpen) then FOnOpen(Self, FSelId);
        Key := 0;
      end;
  end;
end;

{ ---------------- mis ---------------- }

procedure TaOwnBoard.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  C: TaBoardCard;
  K, I, J: Integer;
  Pr: TRect;
begin
  inherited MouseDown(Button, Shift, X, Y);
  if not Focused then SetFocus;
  if Button <> mbLeft then Exit;
  { gumb + u zaglavlju }
  K := ColAt(X);
  if (K >= 0) and (Y < HeaderH) and FAllowAdd and not FReadOnly and (TaBoardColumn(FCols[K]).Key <> '') then
  begin
    Pr := PlusRect(K);
    if (X >= Pr.Left) and (X < Pr.Right) and Assigned(FOnAdd) then
    begin
      FOnAdd(Self, TaBoardColumn(FCols[K]).Key);
      Exit;
    end;
  end;
  C := CardAt(X, Y, I, J);
  if C <> nil then
  begin
    SelectCard(C.Id);
    FDownId := C.Id;
    FDownX := X;
    FDownY := Y;
  end
  else FDownId := '';
end;

procedure TaOwnBoard.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  if (FDownId <> '') and (ssLeft in Shift) and not FReadOnly then
  begin
    if (not FDragging) and ((Abs(X - FDownX) > 5) or (Abs(Y - FDownY) > 5)) then
    begin
      FDragging := True;
      Cursor := crDrag;
    end;
    if FDragging then
    begin
      FDragX := X;
      FDragY := Y;
      FDropCol := ColAt(X);
      { rub ploce: vodoravno pomicanje tijekom povlacenja }
      if (X < 24) and (FScrollX > 0) then begin Dec(FScrollX, 12); ClampScroll; end
      else if (X > Width - 24) and (FScrollX < ContentW - Width) then begin Inc(FScrollX, 12); ClampScroll; end;
      Invalidate;
    end;
  end;
end;

procedure TaOwnBoard.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  C: TaBoardCard;
begin
  inherited MouseUp(Button, Shift, X, Y);
  if FDragging then
  begin
    FDragging := False;
    Cursor := crDefault;
    C := FindCard(FDownId);
    DoMove(C, FDropCol);
  end;
  FDownId := '';
  FDropCol := -1;
  Invalidate;
end;

procedure TaOwnBoard.DblClick;
var
  M: TPoint;
  C: TaBoardCard;
  I, J: Integer;
begin
  inherited DblClick;
  M := ScreenToClient(Mouse.CursorPos);
  C := CardAt(M.X, M.Y, I, J);
  if (C <> nil) and Assigned(FOnOpen) then FOnOpen(Self, C.Id);
end;

function TaOwnBoard.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
var
  K: Integer;
begin
  Result := True;
  if ssShift in Shift then
  begin
    FScrollX := FScrollX - WheelDelta div 2;
    ClampScroll;
    Invalidate;
    Exit;
  end;
  K := ColAt(MousePos.X);
  if K < 0 then Exit;
  with TaBoardColumn(FCols[K]) do Top := Max(0, Min(MaxTop(TaBoardColumn(FCols[K])), Top - WheelDelta div 2));
  Invalidate;
end;

procedure TaOwnBoard.DoEnter;
begin
  inherited DoEnter;
  Invalidate;
end;

procedure TaOwnBoard.DoExit;
begin
  inherited DoExit;
  Invalidate;
end;

end.
