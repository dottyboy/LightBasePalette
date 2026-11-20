unit ta_ownlist;
{ Vlastiti popis stavki (pruzatelj 'own', varijante list i checklist obitelji List): crta se sam, pa izgleda i radi isto na svakom sucelju.
  list: jedna oznacena stavka ili vise (Ctrl+klik, Shift+klik, Shift+strelice, Ctrl+A); checklist: kvacica uz svaku stavku
  (klik na kvadratic ili razmaknica). Tipke: strelice, PgUp/PgDn, Home/End, slovo skace na stavku. Kotacic i klizac pomicu popis. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, LCLType, LazUTF8, ta_family, ta_list;

type
  TaOwnList = class(TCustomControl)
  private
    FItems: TStringList;
    FSel, FChk: array of Boolean;
    FCur, FAnchorRow, FTop: Integer;
    FMulti, FChecks, FReadOnly, FDragThumb, FTiles: Boolean;
    FOnChange: TNotifyEvent;
    FTypeBuf: string;
    FTypeTick: QWord;
    procedure ItemsChanged(Sender: TObject);
    function RowH: Integer;
    function Rows: Integer;
    function GetSelected(AIndex: Integer): Boolean;
    procedure SetSelected(AIndex: Integer; AValue: Boolean);
    function GetChecked(AIndex: Integer): Boolean;
    procedure SetChecked(AIndex: Integer; AValue: Boolean);
    function GetItemIndex: Integer;
    procedure SetItemIndex(AValue: Integer);
    procedure EnsureVisible;
    procedure ThumbTo(Y: Integer);
    procedure Notify;
    procedure ClearSel;
    procedure Go(ARow: Integer; AShift: TShiftState);
    procedure SelectRange(A, B: Integer);
    procedure ToggleCheck(ARow: Integer);
    function RowAt(X, Y: Integer): Integer;
    function Cols: Integer;
    function TotalRows: Integer;
    procedure PaintTiles;
  protected
    procedure Paint; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure UTF8KeyPress(var UTF8Key: TUTF8Char); override;
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
    procedure SelectAll;
    procedure ClearSelection;
    function SelectedCount: Integer;
    property Items: TStringList read FItems;
    property Selected[AIndex: Integer]: Boolean read GetSelected write SetSelected;
    property Checked[AIndex: Integer]: Boolean read GetChecked write SetChecked;
    property ItemIndex: Integer read GetItemIndex write SetItemIndex;
    property MultiSelect: Boolean read FMulti write FMulti;
    property ShowChecks: Boolean read FChecks write FChecks;
    { ikone: stavke su pločice u mrezi (varijanta iconlist) }
    property Tiles: Boolean read FTiles write FTiles;
    property ReadOnly: Boolean read FReadOnly write FReadOnly;
    { promjena koju je izazvao korisnik (oznaka ili kvacica) }
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

  TaOwnListEngine = class(TaListEngine)
  private
    FList: TaOwnList;
    function JoinedSel: string;
  protected
    function Checks: Boolean; virtual;
  public
    constructor Create(AHost: TaFamilyHost); override;
    class function Provider: string; override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
    procedure SetItems(AItems: TStrings); override;
    procedure SetReadOnly(AValue: Boolean); override;
    procedure ApplyOptions(AOptions: TPersistent); override;
  end;

  TaOwnIconListEngine = class(TaOwnListEngine)
  public
    constructor Create(AHost: TaFamilyHost); override;
  end;

  TaOwnCheckListEngine = class(TaOwnListEngine)
  protected
    function Checks: Boolean; override;
  public
    constructor Create(AHost: TaFamilyHost); override;
  end;

implementation

uses
  Math, ta_tokens;

const
  PadX = 6;
  BarW = 10;
  TileW = 88;
  TileH = 44;

constructor TaOwnList.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ApplyThemeFont(Font);
  ControlStyle := ControlStyle + [csOpaque, csCaptureMouse, csClickEvents];
  TabStop := True;
  Width := 160;
  Height := 120;
  FItems := TStringList.Create;
  FItems.OnChange := @ItemsChanged;
  FCur := -1;
  FAnchorRow := -1;
end;

destructor TaOwnList.Destroy;
begin
  FItems.OnChange := nil;
  FItems.Free;
  inherited Destroy;
end;

procedure TaOwnList.ItemsChanged(Sender: TObject);
begin
  SetLength(FSel, FItems.Count);
  SetLength(FChk, FItems.Count);
  if FCur >= FItems.Count then FCur := -1;
  if FTop >= TotalRows then FTop := 0;
  Invalidate;
end;

function TaOwnList.RowH: Integer;
begin
  Canvas.Font.Assign(Font);
  if FTiles then Result := TileH + Canvas.TextHeight('Ag') + 12
  else Result := Max(22, Canvas.TextHeight('Ag') + 8);
end;

function TaOwnList.Cols: Integer;
begin
  if FTiles then Result := Max(1, (Width - BarW - 6) div TileW) else Result := 1;
end;

function TaOwnList.TotalRows: Integer;
begin
  Result := (FItems.Count + Cols - 1) div Cols;
end;

function TaOwnList.Rows: Integer;
begin
  Result := Max(1, (Height - 4) div RowH);
end;

function TaOwnList.GetSelected(AIndex: Integer): Boolean;
begin
  Result := (AIndex >= 0) and (AIndex < Length(FSel)) and FSel[AIndex];
end;

procedure TaOwnList.SetSelected(AIndex: Integer; AValue: Boolean);
begin
  if (AIndex >= 0) and (AIndex < Length(FSel)) then
  begin
    FSel[AIndex] := AValue;
    Invalidate;
  end;
end;

function TaOwnList.GetChecked(AIndex: Integer): Boolean;
begin
  Result := (AIndex >= 0) and (AIndex < Length(FChk)) and FChk[AIndex];
end;

procedure TaOwnList.SetChecked(AIndex: Integer; AValue: Boolean);
begin
  if (AIndex >= 0) and (AIndex < Length(FChk)) then
  begin
    FChk[AIndex] := AValue;
    Invalidate;
  end;
end;

function TaOwnList.GetItemIndex: Integer;
var
  I: Integer;
begin
  Result := -1;
  if FMulti then
  begin
    if (FCur >= 0) and GetSelected(FCur) then Exit(FCur);
    for I := 0 to High(FSel) do
      if FSel[I] then Exit(I);
    Exit;
  end;
  if (FCur >= 0) and GetSelected(FCur) then Result := FCur;
end;

procedure TaOwnList.SetItemIndex(AValue: Integer);
begin
  ClearSel;
  if (AValue >= 0) and (AValue < Length(FSel)) then
  begin
    FSel[AValue] := True;
    FCur := AValue;
    FAnchorRow := AValue;
    EnsureVisible;
  end
  else FCur := -1;
  Invalidate;
end;

procedure TaOwnList.ClearSel;
var
  I: Integer;
begin
  for I := 0 to High(FSel) do FSel[I] := False;
end;

procedure TaOwnList.ClearSelection;
begin
  ClearSel;
  Invalidate;
end;

procedure TaOwnList.SelectAll;
var
  I: Integer;
begin
  for I := 0 to High(FSel) do FSel[I] := True;
  Invalidate;
end;

function TaOwnList.SelectedCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(FSel) do
    if FSel[I] then Inc(Result);
end;

procedure TaOwnList.Notify;
begin
  if Assigned(FOnChange) then FOnChange(Self);
end;

procedure TaOwnList.EnsureVisible;
var
  R: Integer;
begin
  if FCur < 0 then Exit;
  R := Rows;
  if FCur div Cols < FTop then FTop := FCur div Cols;
  if FCur div Cols >= FTop + R then FTop := FCur div Cols - R + 1;
  FTop := Max(0, Min(FTop, Max(0, TotalRows - R)));
end;

procedure TaOwnList.SelectRange(A, B: Integer);
var
  I: Integer;
begin
  if A > B then begin I := A; A := B; B := I; end;
  for I := A to B do
    if (I >= 0) and (I < Length(FSel)) then FSel[I] := True;
end;

{ premjesti kursor na redak; Shift prosiruje oznaku, Ctrl samo pomice (razmaknica oznacuje) }
procedure TaOwnList.Go(ARow: Integer; AShift: TShiftState);
begin
  if FItems.Count = 0 then Exit;
  ARow := Max(0, Min(FItems.Count - 1, ARow));
  if FChecks then
  begin
    FCur := ARow;
    ClearSel;
    FSel[ARow] := True;
  end
  else if FMulti and (ssShift in AShift) then
  begin
    if FAnchorRow < 0 then FAnchorRow := Max(0, FCur);
    ClearSel;
    SelectRange(FAnchorRow, ARow);
    FCur := ARow;
  end
  else if FMulti and (ssCtrl in AShift) then FCur := ARow
  else
  begin
    ClearSel;
    FSel[ARow] := True;
    FCur := ARow;
    FAnchorRow := ARow;
  end;
  EnsureVisible;
  Invalidate;
  if not FChecks then Notify;
end;

procedure TaOwnList.ToggleCheck(ARow: Integer);
begin
  if (ARow < 0) or (ARow >= Length(FChk)) then Exit;
  FChk[ARow] := not FChk[ARow];
  Invalidate;
  Notify;
end;

function TaOwnList.RowAt(X, Y: Integer): Integer;
var
  C: Integer;
begin
  if (Y < 2) or (X < 3) then Exit(-1);
  C := (X - 3) div TileW;
  if (not FTiles) then C := 0;
  if C >= Cols then Exit(-1);
  Result := (FTop + (Y - 2) div RowH) * Cols + C;
  if (Result < 0) or (Result >= FItems.Count) then Result := -1;
end;

procedure TaOwnList.Paint;
var
  T: TaThemeTokens;
  I, Y, Rh, R, Fin, ThH, ThY, TextX, Bx, By: Integer;
  Bg, Br, Tx: TColor;
  Foc, Over: Boolean;
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
  Over := TotalRows > Rows;
  if FTiles then begin PaintTiles; Exit; end;
  Canvas.ClipRect := Rect(2, 2, Width - 2, Height - 2);
  Canvas.Clipping := True;
  Fin := Min(FItems.Count - 1, FTop + Rows);
  for I := FTop to Fin do
  begin
    Y := 2 + (I - FTop) * Rh;
    if GetSelected(I) then
    begin
      if Foc and not FChecks then Canvas.Brush.Color := TokenColor(T.Accent) else Canvas.Brush.Color := TokenColor(T.AccentSoft);
      Canvas.Pen.Style := psClear;
      Canvas.FillRect(3, Y, Width - 3 - Ord(Over) * BarW, Y + Rh);
      Canvas.Pen.Style := psSolid;
      if Foc and not FChecks then Tx := TokenColor(T.OnAccent) else Tx := TokenColor(T.Text);
    end
    else Tx := TokenColor(T.Text);
    if not Enabled then Tx := TokenColor(T.TextSoft);
    TextX := PadX + 3;
    if FChecks then
    begin
      Bx := PadX + 3;
      By := Y + (Rh - 14) div 2;
      Canvas.Brush.Style := bsSolid;
      if FChk[I] then Canvas.Brush.Color := TokenColor(T.Accent) else Canvas.Brush.Color := TokenColor(T.Surface);
      Canvas.Pen.Color := TokenColor(T.Border);
      if FChk[I] then Canvas.Pen.Color := TokenColor(T.Accent);
      Canvas.RoundRect(Bx, By, Bx + 14, By + 14, 4, 4);
      if FChk[I] then
      begin
        Canvas.Pen.Color := TokenColor(T.OnAccent);
        Canvas.Pen.Width := 2;
        Canvas.MoveTo(Bx + 3, By + 7);
        Canvas.LineTo(Bx + 6, By + 10);
        Canvas.LineTo(Bx + 11, By + 4);
        Canvas.Pen.Width := 1;
      end;
      TextX := Bx + 14 + 8;
    end;
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Color := Tx;
    Canvas.TextOut(TextX, Y + (Rh - Canvas.TextHeight('Ag')) div 2, FItems[I]);
    Canvas.Brush.Style := bsSolid;
    if Foc and (I = FCur) then
    begin
      Canvas.Pen.Color := TokenColor(T.Accent);
      Canvas.Brush.Style := bsClear;
      Canvas.Rectangle(4, Y, Width - 4 - Ord(Over) * BarW, Y + Rh);
      Canvas.Brush.Style := bsSolid;
    end;
  end;
  Canvas.Clipping := False;
  if Over then
  begin
    ThH := Max(18, (Height - 6) * Rows div TotalRows);
    ThY := 3 + (Height - 6 - ThH) * FTop div Max(1, TotalRows - Rows);
    Canvas.Brush.Color := TokenColor(T.Border);
    Canvas.Pen.Style := psClear;
    Canvas.RoundRect(Width - BarW - 1, ThY, Width - 3, ThY + ThH, 4, 4);
    Canvas.Pen.Style := psSolid;
  end;
end;

procedure TaOwnList.PaintTiles;
var
  T: TaThemeTokens;
  I, Rw, Cl, X, Y, Rh, Cn, Ix, ThH, ThY, Tw: Integer;
  Foc, Over: Boolean;
  Cap, Ltr: string;
  Tx: TColor;
begin
  T := ActiveTokens;
  Foc := Focused;
  Rh := RowH;
  Cn := Cols;
  Over := TotalRows > Rows;
  Canvas.ClipRect := Rect(2, 2, Width - 2, Height - 2);
  Canvas.Clipping := True;
  for I := FTop * Cn to Min(FItems.Count - 1, (FTop + Rows + 1) * Cn - 1) do
  begin
    Rw := I div Cn - FTop;
    Cl := I mod Cn;
    X := 3 + Cl * TileW;
    Y := 2 + Rw * Rh;
    if GetSelected(I) then
    begin
      if Foc then Canvas.Brush.Color := TokenColor(T.Accent) else Canvas.Brush.Color := TokenColor(T.AccentSoft);
      Canvas.Pen.Style := psClear;
      Canvas.RoundRect(X + 3, Y + 2, X + TileW - 3, Y + Rh - 2, 8, 8);
      Canvas.Pen.Style := psSolid;
      if Foc then Tx := TokenColor(T.OnAccent) else Tx := TokenColor(T.Text);
    end
    else Tx := TokenColor(T.Text);
    { ikona: zaobljeni kvadrat s prvim slovom }
    Ix := X + (TileW - TileH + 8) div 2;
    if GetSelected(I) and Foc then Canvas.Brush.Color := TokenColor(T.OnAccent) else Canvas.Brush.Color := TokenColor(T.AccentSoft);
    Canvas.Pen.Color := TokenColor(T.Border);
    Canvas.RoundRect(Ix, Y + 6, Ix + TileH - 8, Y + 6 + TileH - 8, 10, 10);
    Ltr := UTF8UpperCase(UTF8Copy(FItems[I], 1, 1));
    Canvas.Font.Assign(Font);
    Canvas.Font.Style := [fsBold];
    Canvas.Font.Color := TokenColor(T.Accent);
    Canvas.Brush.Style := bsClear;
    Canvas.TextOut(Ix + (TileH - 8 - Canvas.TextWidth(Ltr)) div 2, Y + 6 + (TileH - 8 - Canvas.TextHeight(Ltr)) div 2, Ltr);
    { natpis, skracen ako ne stane }
    Canvas.Font.Style := [];
    Canvas.Font.Color := Tx;
    if not Enabled then Canvas.Font.Color := TokenColor(T.TextSoft);
    Cap := FItems[I];
    Tw := TileW - 10;
    while (UTF8Length(Cap) > 1) and (Canvas.TextWidth(Cap) > Tw) do
      Cap := UTF8Copy(Cap, 1, UTF8Length(Cap) - 2) + '…';
    Canvas.TextOut(X + (TileW - Canvas.TextWidth(Cap)) div 2, Y + TileH + 4, Cap);
    Canvas.Brush.Style := bsSolid;
    if Foc and (I = FCur) then
    begin
      Canvas.Pen.Color := TokenColor(T.Accent);
      Canvas.Brush.Style := bsClear;
      Canvas.RoundRect(X + 3, Y + 2, X + TileW - 3, Y + Rh - 2, 8, 8);
      Canvas.Brush.Style := bsSolid;
    end;
  end;
  Canvas.Clipping := False;
  if Over then
  begin
    ThH := Max(18, (Height - 6) * Rows div TotalRows);
    ThY := 3 + (Height - 6 - ThH) * FTop div Max(1, TotalRows - Rows);
    Canvas.Brush.Color := TokenColor(T.Border);
    Canvas.Pen.Style := psClear;
    Canvas.RoundRect(Width - BarW - 1, ThY, Width - 3, ThY + ThH, 4, 4);
    Canvas.Pen.Style := psSolid;
  end;
end;

procedure TaOwnList.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  if Key = 0 then Exit;
  case Key of
    VK_UP: begin if not FReadOnly then Go(Max(0, FCur - Cols), Shift); Key := 0; end;
    VK_DOWN: begin if not FReadOnly then Go(FCur + Cols, Shift); Key := 0; end;
    VK_LEFT: if FTiles then begin if not FReadOnly then Go(Max(0, FCur - 1), Shift); Key := 0; end;
    VK_RIGHT: if FTiles then begin if not FReadOnly then Go(FCur + 1, Shift); Key := 0; end;
    VK_PRIOR: begin if not FReadOnly then Go(Max(0, FCur - Rows * Cols), Shift); Key := 0; end;
    VK_NEXT: begin if not FReadOnly then Go(FCur + Rows * Cols, Shift); Key := 0; end;
    VK_HOME: begin if not FReadOnly then Go(0, Shift); Key := 0; end;
    VK_END: begin if not FReadOnly then Go(FItems.Count - 1, Shift); Key := 0; end;
    VK_SPACE:
      begin
        if not FReadOnly then
        begin
          if FChecks then ToggleCheck(FCur)
          else if FMulti and (FCur >= 0) then begin FSel[FCur] := not FSel[FCur]; Invalidate; Notify; end;
        end;
        Key := 0;
      end;
    VK_A:
      if (Shift = [ssCtrl]) and FMulti and not FChecks then
      begin
        if not FReadOnly then begin SelectAll; Notify; end;
        Key := 0;
      end;
  end;
end;

procedure TaOwnList.UTF8KeyPress(var UTF8Key: TUTF8Char);
var
  I, N, Start: Integer;
  F: string;
begin
  inherited UTF8KeyPress(UTF8Key);
  if (UTF8Key = '') or FReadOnly or (FItems.Count = 0) then Exit;
  if (Length(UTF8Key) = 1) and (Ord(UTF8Key[1]) <= 32) then Exit;
  if GetTickCount64 - FTypeTick > 900 then FTypeBuf := '';
  FTypeTick := GetTickCount64;
  FTypeBuf := FTypeBuf + UTF8Key;
  F := UTF8LowerCase(FTypeBuf);
  N := UTF8Length(F);
  Start := Max(0, FCur);
  if N = 1 then Inc(Start);
  for I := 0 to FItems.Count - 1 do
    if UTF8LowerCase(UTF8Copy(FItems[(Start + I) mod FItems.Count], 1, N)) = F then
    begin
      Go((Start + I) mod FItems.Count, []);
      Break;
    end;
  UTF8Key := '';
end;

procedure TaOwnList.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  R: Integer;
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then Exit;
  if CanFocus and not Focused then SetFocus;
  if (TotalRows > Rows) and (X >= Width - BarW - 3) then
  begin
    FDragThumb := True;
    ThumbTo(Y);
    Exit;
  end;
  R := RowAt(X, Y);
  if (R < 0) or FReadOnly then Exit;
  if FChecks then
  begin
    Go(R, []);
    if X < PadX + 3 + 14 + 4 then ToggleCheck(R);
    Exit;
  end;
  if FMulti and (ssCtrl in Shift) then
  begin
    FSel[R] := not FSel[R];
    FCur := R;
    FAnchorRow := R;
    Invalidate;
    Notify;
  end
  else Go(R, Shift * [ssShift]);
end;

procedure TaOwnList.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  if FDragThumb then ThumbTo(Y);
end;

procedure TaOwnList.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  FDragThumb := False;
end;

procedure TaOwnList.ThumbTo(Y: Integer);
var
  Span: Integer;
begin
  Span := TotalRows - Rows;
  if Span <= 0 then Exit;
  FTop := Max(0, Min(Span, Round((Y - 3) / Max(1, Height - 6) * TotalRows - Rows / 2)));
  Invalidate;
end;

function TaOwnList.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
var
  Span: Integer;
begin
  Span := TotalRows - Rows;
  Result := Span > 0;
  if Result then
  begin
    if WheelDelta > 0 then Dec(FTop, 3) else Inc(FTop, 3);
    FTop := Max(0, Min(Span, FTop));
    Invalidate;
  end;
end;

procedure TaOwnList.DoEnter;
begin
  inherited DoEnter;
  if (FCur < 0) and (FItems.Count > 0) then FCur := 0;
  Invalidate;
end;

procedure TaOwnList.DoExit;
begin
  inherited DoExit;
  Invalidate;
end;

procedure TaOwnList.Resize;
begin
  inherited Resize;
  if Parent <> nil then EnsureVisible;
end;

{ ---------------- pokretac ---------------- }

constructor TaOwnListEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FList := TaOwnList.Create(nil);
  FList.ShowChecks := Checks;
  FList.OnChange := @InnerChanged;
  AttachInner(FList);
end;

class function TaOwnListEngine.Provider: string;
begin
  Result := 'own';
end;

function TaOwnListEngine.Checks: Boolean;
begin
  Result := False;
end;

function TaOwnListEngine.JoinedSel: string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to FList.Items.Count - 1 do
    if (FList.ShowChecks and FList.Checked[I]) or ((not FList.ShowChecks) and FList.Selected[I]) then
    begin
      if Result <> '' then Result := Result + ',';
      Result := Result + KeyAt(I);
    end;
end;

function TaOwnListEngine.GetText: string;
begin
  if FList.ShowChecks or FList.MultiSelect then Result := JoinedSel else Result := KeyAt(FList.ItemIndex);
end;

procedure TaOwnListEngine.SetText(const AValue: string);
var
  L: TStringList;
  I: Integer;
begin
  if FList.ShowChecks or FList.MultiSelect then
  begin
    L := TStringList.Create;
    try
      L.CommaText := AValue;
      for I := 0 to FList.Items.Count - 1 do
        if FList.ShowChecks then FList.Checked[I] := L.IndexOf(KeyAt(I)) >= 0
        else FList.Selected[I] := L.IndexOf(KeyAt(I)) >= 0;
    finally
      L.Free;
    end;
  end
  else FList.ItemIndex := IndexOfKey(AValue);
end;

procedure TaOwnListEngine.SetItems(AItems: TStrings);
var
  Lb: TStringList;
  Keep: string;
begin
  Keep := GetText;
  Lb := TStringList.Create;
  try
    ParseItems(AItems, Lb, nil);
    FList.Items.Assign(Lb);
  finally
    Lb.Free;
  end;
  SetText(Keep);
end;

procedure TaOwnListEngine.SetReadOnly(AValue: Boolean);
begin
  inherited SetReadOnly(AValue);
  FList.ReadOnly := AValue;
end;

procedure TaOwnListEngine.ApplyOptions(AOptions: TPersistent);
var
  Keep: string;
begin
  if (AOptions is TaListOptions) and (FList.MultiSelect <> TaListOptions(AOptions).MultiSelect) then
  begin
    Keep := GetText;
    FList.MultiSelect := TaListOptions(AOptions).MultiSelect;
    SetText(Keep);
  end;
end;

constructor TaOwnCheckListEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
end;

function TaOwnCheckListEngine.Checks: Boolean;
begin
  Result := True;
end;

constructor TaOwnIconListEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FList.Tiles := True;
end;

initialization
  RegisterEngine(ListFamily, 'list', TaOwnListEngine);
  RegisterEngine(ListFamily, 'checklist', TaOwnCheckListEngine);
  RegisterEngine(ListFamily, 'iconlist', TaOwnIconListEngine);

end.
