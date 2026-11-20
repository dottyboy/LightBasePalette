unit ta_owncombo;
{ Vlastiti padajuci popis i combo (pruzatelj 'own'): polje je TaOwnEdit s rezerviranim mjestom za strelicu, a popis je
  vlastita kontrola koja se crta preko forme (ne izvorni prozor), pa radi isto na Qt-u, GTK-u i drugdje.

  Combo: tekst se moze tipkati, uz izbor iz popisa i dopunjavanje (AutoComplete); Search suzuje popis na stavke koje sadrze tekst.
  Droplist: samo izbor (tipka slova skace na stavku, razmaknica otvara popis).
  Tipke: F4 ili Alt+Strelica dolje otvara, strelice i PgUp/PgDn kreću se, Enter bira, Esc zatvara. Kotacic pomice popis. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, Forms, LCLType, LMessages, LazUTF8, ta_family, ta_edit, ta_ownedit, ta_ownpopup;

type
  TaPickEvent = procedure(AIndex: Integer) of object;

  TaOwnDropList = class(TCustomControl)
  private
    FItems: TStrings;
    FShown: array of Integer;     { stavke koje se vide (indeksi u FItems), nakon suzenja }
    FHigh, FTopRow, FRows, FCurrent: Integer;
    FOnPick: TaPickEvent;
    FDragThumb: Boolean;
    function RowAt(Y: Integer): Integer;
    procedure EnsureVisible;
    procedure ThumbTo(Y: Integer);
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Setup(AItems: TStrings; ACurrent, ARows: Integer);
    procedure Refilter(const AFilter: string);
    procedure MoveHigh(ADelta: Integer);
    procedure HighTo(ARow: Integer);
    function HighItem: Integer;
    function ShownCount: Integer;
    function PreferredHeight: Integer;
    property OnPick: TaPickEvent read FOnPick write FOnPick;
  end;

  TaOwnCombo = class(TaOwnPopupEdit)
  private
    FItems: TStringList;
    FItemIndex: Integer;
    FDroplist, FSearch, FAutoComplete, FLocked: Boolean;
    FDropCount: Integer;
    FPop: TaOwnDropList;
    FOnSelect: TNotifyEvent;
    FTypeBuf: string;
    FTypeTick: QWord;
    procedure ItemsChanged(Sender: TObject);
    procedure SetDroplist(AValue: Boolean);
    procedure SetLocked(AValue: Boolean);
    procedure UpdateReadOnly;
    function GetItemIndex: Integer;
    procedure SetItemIndex(AValue: Integer);
    procedure Pick(AIndex: Integer);
    procedure PopPicked(AIndex: Integer);
    procedure CompleteTyped;
    procedure TypeAhead(const AChar: string);
  protected
    procedure PaintExtras(ARect: TRect); override;
    procedure TextTyped; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure UTF8KeyPress(var UTF8Key: TUTF8Char); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure DoExit; override;
    procedure RealSetText(const AValue: TCaption); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure OpenPopup;
    procedure ClosePopup; override;
    property Popup: TaOwnDropList read FPop;
    property Items: TStringList read FItems;
    property ItemIndex: Integer read GetItemIndex write SetItemIndex;
    property Droplist: Boolean read FDroplist write SetDroplist;
    property Search: Boolean read FSearch write FSearch;
    property AutoComplete: Boolean read FAutoComplete write FAutoComplete;
    property DropDownCount: Integer read FDropCount write FDropCount;
    property Locked: Boolean read FLocked write SetLocked;
    property OnSelect: TNotifyEvent read FOnSelect write FOnSelect;
  end;

  { ---------------- pokretaci pruzatelja 'own' ---------------- }

  TaOwnComboEngine = class(TaEngine)
  private
    FCombo: TaOwnCombo;
    FForceDroplist, FKeyed, FSearch: Boolean;
    FKeys: TStringList;
    FLast: TStringList;
  public
    constructor Create(AHost: TaFamilyHost); override;
    destructor Destroy; override;
    class function Provider: string; override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
    procedure SetItems(AItems: TStrings); override;
    procedure SetReadOnly(AValue: Boolean); override;
    procedure ApplyOptions(AOptions: TPersistent); override;
  end;

  TaOwnDroplistEngine = class(TaOwnComboEngine)
  public
    constructor Create(AHost: TaFamilyHost); override;
  end;

implementation

uses
  Math, ta_tokens;

const
  ItemH = 24;
  ArrowW = 24;
  ThumbW = 8;

{ ---------------- popis ---------------- }

constructor TaOwnDropList.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ApplyThemeFont(Font);
  ControlStyle := ControlStyle + [csNoFocus, csOpaque];
  TabStop := False;
  Visible := False;
  FHigh := -1;
  FCurrent := -1;
end;

procedure TaOwnDropList.Setup(AItems: TStrings; ACurrent, ARows: Integer);
var
  I: Integer;
begin
  FItems := AItems;
  FCurrent := ACurrent;
  FRows := Max(1, ARows);
  SetLength(FShown, AItems.Count);
  for I := 0 to AItems.Count - 1 do FShown[I] := I;
  FHigh := -1;
  if ACurrent >= 0 then FHigh := ACurrent;
  FTopRow := 0;
  EnsureVisible;
  Invalidate;
end;

procedure TaOwnDropList.Refilter(const AFilter: string);
var
  I, N: Integer;
  F: string;
begin
  F := UTF8LowerCase(AFilter);
  N := 0;
  SetLength(FShown, FItems.Count);
  for I := 0 to FItems.Count - 1 do
    if (F = '') or (Pos(F, UTF8LowerCase(FItems[I])) > 0) then
    begin
      FShown[N] := I;
      Inc(N);
    end;
  SetLength(FShown, N);
  FTopRow := 0;
  if N > 0 then FHigh := 0 else FHigh := -1;
  Height := PreferredHeight;
  Invalidate;
end;

function TaOwnDropList.ShownCount: Integer;
begin
  Result := Length(FShown);
end;

function TaOwnDropList.PreferredHeight: Integer;
begin
  Result := Max(1, Min(FRows, Max(1, Length(FShown)))) * ItemH + 2;
end;

function TaOwnDropList.HighItem: Integer;
begin
  if (FHigh >= 0) and (FHigh < Length(FShown)) then Result := FShown[FHigh] else Result := -1;
end;

procedure TaOwnDropList.EnsureVisible;
begin
  if FHigh < 0 then Exit;
  if FHigh < FTopRow then FTopRow := FHigh;
  if FHigh >= FTopRow + FRows then FTopRow := FHigh - FRows + 1;
  if FTopRow < 0 then FTopRow := 0;
end;

procedure TaOwnDropList.MoveHigh(ADelta: Integer);
begin
  if Length(FShown) = 0 then Exit;
  if FHigh < 0 then FHigh := 0 else FHigh := Max(0, Min(Length(FShown) - 1, FHigh + ADelta));
  EnsureVisible;
  Invalidate;
end;

procedure TaOwnDropList.HighTo(ARow: Integer);
begin
  if Length(FShown) = 0 then Exit;
  FHigh := Max(0, Min(Length(FShown) - 1, ARow));
  EnsureVisible;
  Invalidate;
end;

function TaOwnDropList.RowAt(Y: Integer): Integer;
begin
  Result := FTopRow + (Y - 1) div ItemH;
  if (Result < 0) or (Result >= Length(FShown)) then Result := -1;
end;

procedure TaOwnDropList.Paint;
var
  T: TaThemeTokens;
  I, Y, Vis, R, ThH, ThY: Integer;
  Idx: Integer;
  TextW: Integer;
begin
  T := ActiveTokens;
  Canvas.Font.Assign(Font);
  Canvas.Brush.Color := TokenColor(T.Surface);
  Canvas.Pen.Color := TokenColor(T.Border);
  R := Min(T.RadiusField, 6);
  if R > 0 then Canvas.RoundRect(0, 0, Width, Height, R * 2, R * 2) else Canvas.Rectangle(0, 0, Width, Height);
  Vis := Min(FRows, Length(FShown) - FTopRow);
  TextW := Width - 2;
  if Length(FShown) > FRows then Dec(TextW, ThumbW);
  Canvas.ClipRect := Rect(1, 1, Width - 1, Height - 1);
  Canvas.Clipping := True;
  Y := 1;
  for I := FTopRow to FTopRow + Vis - 1 do
  begin
    Idx := FShown[I];
    if I = FHigh then
    begin
      Canvas.Brush.Color := TokenColor(T.AccentSoft);
      Canvas.FillRect(1, Y, 1 + TextW, Y + ItemH);
    end;
    Canvas.Brush.Style := bsClear;
    if Idx = FCurrent then Canvas.Font.Color := TokenColor(T.Accent) else Canvas.Font.Color := TokenColor(T.Text);
    if Idx = FCurrent then Canvas.Font.Style := [fsBold] else Canvas.Font.Style := [];
    Canvas.TextRect(Rect(1, Y, 1 + TextW, Y + ItemH), 8, Y + (ItemH - Canvas.TextHeight('Ag')) div 2, FItems[Idx]);
    Canvas.Brush.Style := bsSolid;
    Inc(Y, ItemH);
  end;
  if Length(FShown) > FRows then
  begin
    ThH := Max(16, (Height - 4) * FRows div Length(FShown));
    ThY := 2 + (Height - 4 - ThH) * FTopRow div Max(1, Length(FShown) - FRows);
    Canvas.Brush.Color := TokenColor(T.Border);
    Canvas.Pen.Style := psClear;
    Canvas.RoundRect(Width - ThumbW, ThY, Width - 2, ThY + ThH, 4, 4);
    Canvas.Pen.Style := psSolid;
  end;
  Canvas.Clipping := False;
end;

procedure TaOwnDropList.ThumbTo(Y: Integer);
var
  Span: Integer;
begin
  Span := Length(FShown) - FRows;
  if Span <= 0 then Exit;
  FTopRow := Max(0, Min(Span, Round((Y - 2) / Max(1, Height - 4) * Length(FShown) - FRows / 2)));
  Invalidate;
end;

procedure TaOwnDropList.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  R: Integer;
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then Exit;
  if (Length(FShown) > FRows) and (X >= Width - ThumbW - 2) then
  begin
    FDragThumb := True;
    ThumbTo(Y);
    Exit;
  end;
  R := RowAt(Y);
  if (R >= 0) and Assigned(FOnPick) then FOnPick(FShown[R]);
end;

procedure TaOwnDropList.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  R: Integer;
begin
  inherited MouseMove(Shift, X, Y);
  if FDragThumb then begin ThumbTo(Y); Exit; end;
  R := RowAt(Y);
  if (R >= 0) and (R <> FHigh) then
  begin
    FHigh := R;
    Invalidate;
  end;
end;

procedure TaOwnDropList.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  FDragThumb := False;
end;

function TaOwnDropList.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
var
  Span: Integer;
begin
  Span := Length(FShown) - FRows;
  if Span > 0 then
  begin
    if WheelDelta > 0 then Dec(FTopRow, 3) else Inc(FTopRow, 3);
    FTopRow := Max(0, Min(Span, FTopRow));
    Invalidate;
  end;
  Result := True;
end;

{ ---------------- combo ---------------- }

constructor TaOwnCombo.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FRightPad := ArrowW;
  FItems := TStringList.Create;
  FItems.OnChange := @ItemsChanged;
  FItemIndex := -1;
  FDropCount := 8;
  FAutoComplete := True;
end;

destructor TaOwnCombo.Destroy;
begin
  FItems.OnChange := nil;
  FItems.Free;
  inherited Destroy;
end;

procedure TaOwnCombo.ItemsChanged(Sender: TObject);
begin
  if FItemIndex >= FItems.Count then FItemIndex := -1;
  if IsOpen then ClosePopup;
end;

procedure TaOwnCombo.UpdateReadOnly;
begin
  ReadOnly := FDroplist or FLocked;
end;

procedure TaOwnCombo.SetDroplist(AValue: Boolean);
begin
  FDroplist := AValue;
  FPlain := AValue;
  UpdateReadOnly;
  Invalidate;
end;

procedure TaOwnCombo.SetLocked(AValue: Boolean);
begin
  FLocked := AValue;
  UpdateReadOnly;
  if FLocked then ClosePopup;
end;

function TaOwnCombo.GetItemIndex: Integer;
begin
  if FDroplist or FSearch then Result := FItemIndex
  else Result := FItems.IndexOf(FText);
end;

procedure TaOwnCombo.SetItemIndex(AValue: Integer);
begin
  if (AValue < 0) or (AValue >= FItems.Count) then
  begin
    FItemIndex := -1;
    SetShownText('');
  end
  else
  begin
    FItemIndex := AValue;
    SetShownText(FItems[AValue]);
  end;
end;

procedure TaOwnCombo.RealSetText(const AValue: TCaption);
begin
  inherited RealSetText(AValue);
  if not (FDroplist or FSearch) then FItemIndex := FItems.IndexOf(FText);
end;

procedure TaOwnCombo.PaintExtras(ARect: TRect);
var
  T: TaThemeTokens;
  Cx, Cy: Integer;
begin
  T := ActiveTokens;
  Cx := (ARect.Left + ARect.Right) div 2;
  Cy := Height div 2;
  if FLocked or not Enabled then Canvas.Pen.Color := TokenColor(T.TextSoft) else Canvas.Pen.Color := TokenColor(T.Text);
  Canvas.Pen.Width := 2;
  Canvas.MoveTo(Cx - 4, Cy - 2);
  Canvas.LineTo(Cx, Cy + 2);
  Canvas.LineTo(Cx + 5, Cy - 3);
  Canvas.Pen.Width := 1;
end;

procedure TaOwnCombo.OpenPopup;
var
  H: Integer;
begin
  if IsOpen or FLocked or (FItems.Count = 0) or (Parent = nil) then Exit;
  if not (TopLevel is TWinControl) then Exit;
  if FPop = nil then
  begin
    FPop := TaOwnDropList.Create(Self);
    FPop.Parent := TWinControl(TopLevel);
    FPop.OnPick := @PopPicked;
    SetPopupControl(FPop);
  end;
  FPop.Setup(FItems, GetItemIndex, FDropCount);
  FPop.Font.Assign(Font);
  if FSearch then FPop.Refilter(FText);
  H := FPop.PreferredHeight;
  ShowPopupAt(Max(Width, 80), H);
end;

procedure TaOwnCombo.ClosePopup;
begin
  inherited ClosePopup;
end;

procedure TaOwnCombo.PopPicked(AIndex: Integer);
begin
  Pick(AIndex);
end;

procedure TaOwnCombo.Pick(AIndex: Integer);
begin
  ClosePopup;
  if (AIndex < 0) or (AIndex >= FItems.Count) then Exit;
  FItemIndex := AIndex;
  SetShownText(FItems[AIndex]);
  Changed;
  if Assigned(FOnSelect) then FOnSelect(Self);
  if CanFocus and not Focused then SetFocus;
end;

procedure TaOwnCombo.CompleteTyped;
var
  I, N: Integer;
  F: string;
begin
  if (FCaret <> FLen) or (FLen = 0) then Exit;
  F := UTF8LowerCase(FText);
  N := FLen;
  for I := 0 to FItems.Count - 1 do
    if (UTF8Length(FItems[I]) > N) and (UTF8LowerCase(UTF8Copy(FItems[I], 1, N)) = F) then
    begin
      SetShownText(FItems[I]);
      FAnchor := N;
      FCaret := FLen;
      KeepCaretVisible;
      Changed;
      Exit;
    end;
end;

procedure TaOwnCombo.TextTyped;
begin
  if FSearch then
  begin
    if not IsOpen then OpenPopup;
    if IsOpen then FPop.Refilter(FText);
  end
  else if FAutoComplete and not FDroplist then CompleteTyped;
end;

procedure TaOwnCombo.TypeAhead(const AChar: string);
var
  I, Start, N: Integer;
  F: string;
begin
  if FItems.Count = 0 then Exit;
  if GetTickCount64 - FTypeTick > 900 then FTypeBuf := '';
  FTypeTick := GetTickCount64;
  FTypeBuf := FTypeBuf + AChar;
  F := UTF8LowerCase(FTypeBuf);
  N := UTF8Length(F);
  Start := Max(0, FItemIndex);
  if Length(FTypeBuf) = UTF8Length(AChar) then Inc(Start);   { ista slova ponovljeno: sljedeca stavka }
  for I := 0 to FItems.Count - 1 do
    if UTF8LowerCase(UTF8Copy(FItems[(Start + I) mod FItems.Count], 1, N)) = F then
    begin
      Pick((Start + I) mod FItems.Count);
      Exit;
    end;
end;

procedure TaOwnCombo.UTF8KeyPress(var UTF8Key: TUTF8Char);
begin
  if FDroplist and not FLocked then
  begin
    if UTF8Key = ' ' then begin OpenPopup; UTF8Key := ''; Exit; end;
    if (UTF8Key <> '') and ((Length(UTF8Key) > 1) or (Ord(UTF8Key[1]) >= 32)) then
    begin
      TypeAhead(UTF8Key);
      UTF8Key := '';
      Exit;
    end;
  end;
  inherited UTF8KeyPress(UTF8Key);
end;

procedure TaOwnCombo.KeyDown(var Key: Word; Shift: TShiftState);
var
  K0: Word;
  I: Integer;
begin
  K0 := Key;
  if IsOpen then
  begin
    case Key of
      VK_UP: begin FPop.MoveHigh(-1); Key := 0; Exit; end;
      VK_DOWN: begin FPop.MoveHigh(1); Key := 0; Exit; end;
      VK_PRIOR: begin FPop.MoveHigh(-FDropCount); Key := 0; Exit; end;
      VK_NEXT: begin FPop.MoveHigh(FDropCount); Key := 0; Exit; end;
      VK_RETURN: begin Pick(FPop.HighItem); Key := 0; Exit; end;
      VK_ESCAPE: begin ClosePopup; Key := 0; Exit; end;
      VK_TAB: ClosePopup;
      VK_F4: begin ClosePopup; Key := 0; Exit; end;
      VK_HOME: if FDroplist then begin FPop.HighTo(0); Key := 0; Exit; end;
      VK_END: if FDroplist then begin FPop.HighTo(MaxInt div 2); Key := 0; Exit; end;
    end;
  end
  else if not FLocked then
  begin
    if (Key = VK_F4) or ((Key = VK_DOWN) and (ssAlt in Shift)) then begin OpenPopup; Key := 0; Exit; end;
    if (Key = VK_DOWN) or (Key = VK_UP) then
    begin
      if Shift = [] then
      begin
        I := GetItemIndex;
        if Key = VK_DOWN then Inc(I) else Dec(I);
        if (I >= 0) and (I < FItems.Count) then Pick(I);
        Key := 0;
        Exit;
      end;
    end;
  end;
  inherited KeyDown(Key, Shift);
  if FSearch and IsOpen and ((K0 = VK_BACK) or (K0 = VK_DELETE)) then FPop.Refilter(FText);
end;

procedure TaOwnCombo.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if (Button = mbLeft) and (FDroplist or PtInRightPad(X)) and not FLocked then
  begin
    if CanFocus and not Focused then SetFocus;
    if IsOpen then ClosePopup else OpenPopup;
    Exit;
  end;
  inherited MouseDown(Button, Shift, X, Y);
  if (Button = mbLeft) and FSearch and not FLocked and not IsOpen then OpenPopup;
end;

procedure TaOwnCombo.DoExit;
begin
  ClosePopup;
  if FSearch then
  begin
    if (FItemIndex >= 0) and (FItemIndex < FItems.Count) then SetShownText(FItems[FItemIndex]) else SetShownText('');
  end;
  inherited DoExit;
end;

{ ---------------- pokretaci ---------------- }

constructor TaOwnComboEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FCombo := TaOwnCombo.Create(nil);
  FCombo.OnChange := @InnerChanged;
  AttachInner(FCombo);
end;

destructor TaOwnComboEngine.Destroy;
begin
  FKeys.Free;
  FLast.Free;
  inherited Destroy;
end;

class function TaOwnComboEngine.Provider: string;
begin
  Result := 'own';
end;

constructor TaOwnDroplistEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FForceDroplist := True;
  FCombo.Droplist := True;
end;

function TaOwnComboEngine.GetText: string;
var
  I: Integer;
begin
  I := FCombo.ItemIndex;
  if FKeyed and (FKeys <> nil) then
  begin
    if (I >= 0) and (I < FKeys.Count) then Result := FKeys[I] else Result := '';
    Exit;
  end;
  if FCombo.Droplist then
  begin
    if (I >= 0) and (I < FCombo.Items.Count) then Result := FCombo.Items[I] else Result := '';
  end
  else Result := FCombo.Text;
end;

procedure TaOwnComboEngine.SetText(const AValue: string);
begin
  if FKeyed and (FKeys <> nil) then
  begin
    FCombo.ItemIndex := FKeys.IndexOf(AValue);
    Exit;
  end;
  if FCombo.Droplist then FCombo.ItemIndex := FCombo.Items.IndexOf(AValue)
  else if FCombo.Text <> AValue then FCombo.Text := AValue;
end;

procedure TaOwnComboEngine.SetItems(AItems: TStrings);
var
  Keep, S: string;
  Labels, Keys: TStringList;
  I, P: Integer;
begin
  Keep := GetText;
  if FLast = nil then FLast := TStringList.Create;
  if AItems <> FLast then FLast.Assign(AItems);
  if FKeyed then
  begin
    Labels := TStringList.Create;
    Keys := TStringList.Create;
    for I := 0 to AItems.Count - 1 do
    begin
      S := AItems[I];
      P := Pos('=', S);
      if P > 0 then begin Keys.Add(Trim(Copy(S, 1, P - 1))); Labels.Add(Trim(Copy(S, P + 1, MaxInt))); end
      else begin Keys.Add(Trim(S)); Labels.Add(Trim(S)); end;
    end;
    FCombo.Items.Assign(Labels);
    Labels.Free;
    FKeys.Free;
    FKeys := Keys;
    FCombo.Search := FSearch;
    FCombo.Droplist := not FSearch;
  end
  else
  begin
    FKeys.Free;
    FKeys := nil;
    FCombo.Search := False;
    FCombo.Items.Assign(AItems);
    FCombo.Droplist := FForceDroplist;
  end;
  SetText(Keep);
end;

procedure TaOwnComboEngine.SetReadOnly(AValue: Boolean);
begin
  FCombo.Locked := AValue;
end;

procedure TaOwnComboEngine.ApplyOptions(AOptions: TPersistent);
var
  Changed: Boolean;
begin
  if AOptions is TaComboOptions then
  begin
    FCombo.DropDownCount := TaComboOptions(AOptions).DropDownCount;
    FCombo.AutoComplete := TaComboOptions(AOptions).AutoComplete;
    Changed := (FKeyed <> TaComboOptions(AOptions).Keyed) or (FSearch <> TaComboOptions(AOptions).Search);
    FKeyed := TaComboOptions(AOptions).Keyed;
    FSearch := TaComboOptions(AOptions).Search;
    if Changed and (FLast <> nil) then SetItems(FLast);
  end;
end;

initialization
  RegisterEngine(EditFamily, 'combo', TaOwnComboEngine);
  RegisterEngine(EditFamily, 'droplist', TaOwnDroplistEngine);

end.
