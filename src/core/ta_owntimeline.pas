unit ta_owntimeline;
{ Vremenska crta rasporeda (vlastita kontrola): tjedan u sedam redaka, 24 sata po retku. Svaki zapis rasporeda je traka koja vrijedi za
  odabrane dane; ponavljanje ("svakih N minuta po M sekundi") crta se kao tanke crtice.
  Mis: povuci po praznom retku = nova traka; povuci traku = pomakni; povuci rub = promijeni pocetak ili kraj; klik na traku = odabir.
  Ispod crte su oznake dana (Pon..Ned) odabrane trake: klik ukljucuje/iskljucuje dan. Delete brise traku. Strelice pomicu odabranu traku
  za korak (15 min), Shift+strelice mijenjaju kraj. Traka koja prelazi ponoc (npr. 22:00-06:00) crta se na dva retka; nju se uredjuje
  u tablici, ne misem.
  Ne zna podatke: puni se s Clear/AddItem/EndUpdate, a promjene javlja dogadjajima (vidi ta_formtimeline). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, LCLType;

type
  TaTimeItem = class
  public
    Id: string;
    Days: string;            { '1'..'7', 1 = ponedjeljak }
    StartMin, EndMin: Integer;
    EveryMin, DurSec: Integer;
    function Wraps: Boolean;
    function HasDay(ADay: Integer): Boolean;
  end;

  TaTimeCreateEvent = procedure(Sender: TObject; ADay, AStartMin, AEndMin: Integer; out AId: string) of object;
  TaTimeChangeEvent = procedure(Sender: TObject; AItem: TaTimeItem) of object;

  TaOwnTimeline = class(TCustomControl)
  private
    FItems: TList;
    FSel: TaTimeItem;
    FDrag: Integer;            { 0 nista, 1 nova, 2 pomak, 3 lijevi rub, 4 desni rub }
    FDragItem: TaTimeItem;
    FDownMin, FDownDay, FOrigStart, FOrigEnd: Integer;
    FMoved, FReadOnly: Boolean;
    FOnCreate: TaTimeCreateEvent;
    FOnChange: TaTimeChangeEvent;
    FOnDelete: TaTimeChangeEvent;
    FOnSelect: TaTimeChangeEvent;
    function LabelW: Integer;
    function HeadH: Integer;
    function RowH: Integer;
    function ChipsY: Integer;
    function ChipsX: Integer;
    function MinToX(AMin: Integer): Integer;
    function XToMin(X: Integer): Integer;
    function DayAt(Y: Integer): Integer;
    function ItemAt(X, Y: Integer; out AZone: Integer): TaTimeItem;
    function ChipAt(X, Y: Integer): Integer;
    procedure Select(AItem: TaTimeItem);
    procedure Commit(AItem: TaTimeItem);
    function GetCount: Integer;
    function GetItem(AIndex: Integer): TaTimeItem;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure DoEnter; override;
    procedure DoExit; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Clear;
    function AddItem(const AId, ADays: string; AStartMin, AEndMin, AEveryMin, ADurSec: Integer): TaTimeItem;
    procedure EndUpdate;
    function Find(const AId: string): TaTimeItem;
    procedure ToggleDay(AItem: TaTimeItem; ADay: Integer);
    procedure DeleteSelected;
    property Count: Integer read GetCount;
    property Items[AIndex: Integer]: TaTimeItem read GetItem; default;
    property Selected: TaTimeItem read FSel write Select;
    property ReadOnly: Boolean read FReadOnly write FReadOnly;
    property OnCreateItem: TaTimeCreateEvent read FOnCreate write FOnCreate;
    property OnItemChange: TaTimeChangeEvent read FOnChange write FOnChange;
    property OnItemDelete: TaTimeChangeEvent read FOnDelete write FOnDelete;
    property OnItemSelect: TaTimeChangeEvent read FOnSelect write FOnSelect;
  end;

function MinToText(AMin: Integer): string;
function TextToMin(const S: string; ADefault: Integer): Integer;

implementation

uses
  Math, ta_tokens;

const
  DayNames: array[1..7] of string = ('Pon', 'Uto', 'Sri', 'Čet', 'Pet', 'Sub', 'Ned');
  Snap = 15;
  Edge = 6;

function MinToText(AMin: Integer): string;
begin
  AMin := AMin mod 1440;
  if AMin < 0 then Inc(AMin, 1440);
  Result := Format('%.2d:%.2d', [AMin div 60, AMin mod 60]);
end;

function TextToMin(const S: string; ADefault: Integer): Integer;
var
  P: Integer;
  H, M: Integer;
begin
  Result := ADefault;
  P := Pos(':', S);
  if P = 0 then Exit;
  H := StrToIntDef(Trim(Copy(S, 1, P - 1)), -1);
  M := StrToIntDef(Trim(Copy(S, P + 1, 2)), -1);
  if (H >= 0) and (H <= 24) and (M >= 0) and (M < 60) then Result := H * 60 + M;
end;

function TaTimeItem.Wraps: Boolean;
begin
  Result := (EveryMin = 0) and (EndMin < StartMin);
end;

function TaTimeItem.HasDay(ADay: Integer): Boolean;
begin
  Result := Pos(IntToStr(ADay), Days) > 0;
end;

constructor TaOwnTimeline.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ApplyThemeFont(Font);
  ControlStyle := ControlStyle + [csOpaque, csCaptureMouse];
  TabStop := True;
  Width := 640;
  Height := 280;
  FItems := TList.Create;
end;

destructor TaOwnTimeline.Destroy;
begin
  Clear;
  FItems.Free;
  inherited Destroy;
end;

procedure TaOwnTimeline.Clear;
var
  I: Integer;
begin
  for I := 0 to FItems.Count - 1 do TaTimeItem(FItems[I]).Free;
  FItems.Clear;
  FSel := nil;
  FDragItem := nil;
  FDrag := 0;
  Invalidate;
end;

function TaOwnTimeline.AddItem(const AId, ADays: string; AStartMin, AEndMin, AEveryMin, ADurSec: Integer): TaTimeItem;
begin
  Result := TaTimeItem.Create;
  Result.Id := AId;
  Result.Days := ADays;
  Result.StartMin := AStartMin;
  Result.EndMin := AEndMin;
  Result.EveryMin := AEveryMin;
  Result.DurSec := ADurSec;
  FItems.Add(Result);
end;

procedure TaOwnTimeline.EndUpdate;
begin
  if (FSel <> nil) and (FItems.IndexOf(FSel) < 0) then FSel := nil;
  Invalidate;
end;

function TaOwnTimeline.GetCount: Integer;
begin
  Result := FItems.Count;
end;

function TaOwnTimeline.GetItem(AIndex: Integer): TaTimeItem;
begin
  Result := TaTimeItem(FItems[AIndex]);
end;

function TaOwnTimeline.Find(const AId: string): TaTimeItem;
var
  I: Integer;
begin
  for I := 0 to FItems.Count - 1 do
    if TaTimeItem(FItems[I]).Id = AId then Exit(TaTimeItem(FItems[I]));
  Result := nil;
end;

{ ---------------- geometrija ---------------- }

function TaOwnTimeline.LabelW: Integer;
begin
  Result := 44;
end;

function TaOwnTimeline.HeadH: Integer;
begin
  Canvas.Font.Assign(Font);
  Result := Canvas.TextHeight('Ag') + 10;
end;

function TaOwnTimeline.RowH: Integer;
begin
  Result := Max(22, (Height - HeadH - 44) div 7);
end;

function TaOwnTimeline.ChipsY: Integer;
begin
  Result := HeadH + 7 * RowH + 10;
end;

function TaOwnTimeline.ChipsX: Integer;
begin
  Result := 110;
end;

function TaOwnTimeline.MinToX(AMin: Integer): Integer;
begin
  Result := LabelW + AMin * (Width - LabelW - 10) div 1440;
end;

function TaOwnTimeline.XToMin(X: Integer): Integer;
begin
  Result := (X - LabelW) * 1440 div Max(1, Width - LabelW - 10);
  Result := Max(0, Min(1440, Result));
  Result := (Result + Snap div 2) div Snap * Snap;
  Result := Max(0, Min(1440, Result));
end;

function TaOwnTimeline.DayAt(Y: Integer): Integer;
begin
  Result := (Y - HeadH) div RowH + 1;
  if (Y < HeadH) or (Result < 1) or (Result > 7) then Result := 0;
end;

{ AZone: 1 tijelo, 3 lijevi rub, 4 desni rub }
function TaOwnTimeline.ItemAt(X, Y: Integer; out AZone: Integer): TaTimeItem;
var
  D, I: Integer;
  It: TaTimeItem;
  X1, X2: Integer;
begin
  Result := nil;
  AZone := 0;
  D := DayAt(Y);
  if D = 0 then Exit;
  for I := FItems.Count - 1 downto 0 do
  begin
    It := TaTimeItem(FItems[I]);
    if not It.HasDay(D) then Continue;
    if It.EveryMin > 0 then Continue;
    if It.Wraps then begin X1 := MinToX(It.StartMin); X2 := MinToX(1440); end
    else begin X1 := MinToX(It.StartMin); X2 := MinToX(It.EndMin); end;
    if (X >= X1 - 2) and (X <= X2 + 2) then
    begin
      Result := It;
      if It.Wraps then AZone := 1
      else if X <= X1 + Edge then AZone := 3
      else if X >= X2 - Edge then AZone := 4
      else AZone := 1;
      Exit;
    end;
  end;
  { traka koja se nastavlja iz prethodnog dana (od ponoci) }
  for I := FItems.Count - 1 downto 0 do
  begin
    It := TaTimeItem(FItems[I]);
    if It.Wraps and It.HasDay(IfThen(D = 1, 7, D - 1)) and (X >= MinToX(0)) and (X <= MinToX(It.EndMin) + 2) then
    begin
      Result := It;
      AZone := 1;
      Exit;
    end;
  end;
end;

function TaOwnTimeline.ChipAt(X, Y: Integer): Integer;
var
  D, X0: Integer;
begin
  Result := 0;
  if (FSel = nil) or (Y < ChipsY) or (Y > ChipsY + 24) then Exit;
  X0 := ChipsX;
  for D := 1 to 7 do
    if (X >= X0 + (D - 1) * 48) and (X < X0 + (D - 1) * 48 + 44) then Exit(D);
end;

{ ---------------- promjene ---------------- }

procedure TaOwnTimeline.Select(AItem: TaTimeItem);
begin
  if FSel = AItem then Exit;
  FSel := AItem;
  Invalidate;
  if Assigned(FOnSelect) then FOnSelect(Self, AItem);
end;

procedure TaOwnTimeline.Commit(AItem: TaTimeItem);
begin
  if (AItem <> nil) and Assigned(FOnChange) then FOnChange(Self, AItem);
  Invalidate;
end;

procedure TaOwnTimeline.ToggleDay(AItem: TaTimeItem; ADay: Integer);
var
  S: string;
  D: Integer;
begin
  if (AItem = nil) or FReadOnly then Exit;
  S := '';
  for D := 1 to 7 do
    if (D = ADay) xor AItem.HasDay(D) then S := S + IntToStr(D);
  if S = '' then Exit;   { traka mora vrijediti barem jedan dan }
  AItem.Days := S;
  Commit(AItem);
end;

procedure TaOwnTimeline.DeleteSelected;
var
  It: TaTimeItem;
begin
  if (FSel = nil) or FReadOnly then Exit;
  It := FSel;
  if Assigned(FOnDelete) then FOnDelete(Self, It);
  FItems.Remove(It);
  FSel := nil;
  It.Free;
  Invalidate;
end;

{ ---------------- crtanje ---------------- }

procedure TaOwnTimeline.Paint;
var
  T: TaThemeTokens;
  I, D, H, X1, X2, Y, Rh, Hh, K, X0: Integer;
  It: TaTimeItem;
  Br, Tx, Acc, Soft: TColor;
  Foc: Boolean;

  procedure Bar(AFrom, ATo, ARow: Integer; ASel: Boolean);
  var
    Ya: Integer;
  begin
    Ya := Hh + (ARow - 1) * Rh + 4;
    if ASel then Canvas.Brush.Color := Acc else Canvas.Brush.Color := TokenColor(T.AccentSoft);
    Canvas.Pen.Color := Acc;
    if ASel then Canvas.Pen.Width := 2 else Canvas.Pen.Width := 1;
    Canvas.RoundRect(MinToX(AFrom), Ya, Max(MinToX(AFrom) + 4, MinToX(ATo)), Ya + Rh - 8, 6, 6);
    Canvas.Pen.Width := 1;
  end;

begin
  T := ActiveTokens;
  Foc := Focused;
  Br := TokenColor(T.Border);
  Tx := TokenColor(T.Text);
  Acc := TokenColor(T.Accent);
  Soft := TokenColor(T.Soft);
  Canvas.Brush.Color := TokenColor(T.Surface);
  Canvas.Pen.Color := Br;
  Canvas.Rectangle(0, 0, Width, Height);
  Canvas.Font.Assign(Font);
  Hh := HeadH;
  Rh := RowH;
  { redci i mreza }
  for D := 1 to 7 do
  begin
    Y := Hh + (D - 1) * Rh;
    if D mod 2 = 0 then
    begin
      Canvas.Brush.Color := Soft;
      Canvas.Pen.Style := psClear;
      Canvas.FillRect(1, Y, Width - 1, Y + Rh);
      Canvas.Pen.Style := psSolid;
    end;
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Color := Tx;
    Canvas.TextOut(8, Y + (Rh - Canvas.TextHeight('Ag')) div 2, DayNames[D]);
    Canvas.Brush.Style := bsSolid;
  end;
  Canvas.Pen.Color := Br;
  for H := 0 to 24 do
  begin
    X1 := MinToX(H * 60);
    if H mod 2 = 0 then
    begin
      Canvas.Line(X1, Hh - 4, X1, Hh + 7 * Rh);
      Canvas.Brush.Style := bsClear;
      Canvas.Font.Color := TokenColor(T.TextSoft);
      if H < 24 then Canvas.TextOut(X1 + 2, 4, IntToStr(H));
      Canvas.Brush.Style := bsSolid;
    end
    else
    begin
      Canvas.Pen.Color := Soft;
      Canvas.Line(X1, Hh, X1, Hh + 7 * Rh);
      Canvas.Pen.Color := Br;
    end;
  end;
  Canvas.Line(LabelW, Hh, Width - 6, Hh);
  { trake }
  for I := 0 to FItems.Count - 1 do
  begin
    It := TaTimeItem(FItems[I]);
    for D := 1 to 7 do
    begin
      if not It.HasDay(D) then Continue;
      if It.EveryMin > 0 then
      begin
        { ponavljanje: crtice na svaki N-ti minut unutar od-do (ili cijeli dan) }
        Canvas.Pen.Color := Acc;
        Canvas.Pen.Width := 2;
        if It.EndMin > It.StartMin then X2 := It.EndMin else X2 := 1440;
        K := It.StartMin;
        while K < X2 do
        begin
          Canvas.Line(MinToX(K), Hh + (D - 1) * Rh + 6, MinToX(K), Hh + D * Rh - 6);
          Inc(K, Max(5, It.EveryMin));
        end;
        Canvas.Pen.Width := 1;
      end
      else if It.Wraps then
      begin
        Bar(It.StartMin, 1440, D, It = FSel);
        Bar(0, It.EndMin, IfThen(D = 7, 1, D + 1), It = FSel);
      end
      else Bar(It.StartMin, It.EndMin, D, It = FSel);
    end;
  end;
  { oznake dana odabrane trake }
  if FSel <> nil then
  begin
    Y := ChipsY;
    X0 := ChipsX;
    Canvas.Font.Color := TokenColor(T.TextSoft);
    Canvas.Brush.Style := bsClear;
    Canvas.TextOut(8, Y + 3, Format('%s - %s', [MinToText(FSel.StartMin), MinToText(FSel.EndMin)]));
    Canvas.Brush.Style := bsSolid;
    for D := 1 to 7 do
    begin
      if FSel.HasDay(D) then Canvas.Brush.Color := Acc else Canvas.Brush.Color := TokenColor(T.Surface);
      Canvas.Pen.Color := Br;
      Canvas.RoundRect(X0 + (D - 1) * 48, Y, X0 + (D - 1) * 48 + 44, Y + 24, 8, 8);
      if FSel.HasDay(D) then Canvas.Font.Color := TokenColor(T.OnAccent) else Canvas.Font.Color := Tx;
      Canvas.Brush.Style := bsClear;
      Canvas.TextOut(X0 + (D - 1) * 48 + (44 - Canvas.TextWidth(DayNames[D])) div 2, Y + 3, DayNames[D]);
      Canvas.Brush.Style := bsSolid;
    end;
  end
  else
  begin
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Color := TokenColor(T.TextSoft);
    Canvas.TextOut(8, ChipsY + 3, 'Povuci po retku dana za novu traku');
    Canvas.Brush.Style := bsSolid;
  end;
  if Foc then
  begin
    Canvas.Brush.Style := bsClear;
    Canvas.Pen.Color := Acc;
    Canvas.Rectangle(0, 0, Width, Height);
    Canvas.Brush.Style := bsSolid;
  end;
end;

{ ---------------- mis ---------------- }

procedure TaOwnTimeline.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  It: TaTimeItem;
  Z, D: Integer;
  Id: string;
begin
  inherited MouseDown(Button, Shift, X, Y);
  if not Focused then SetFocus;
  if Button <> mbLeft then Exit;
  D := ChipAt(X, Y);
  if D > 0 then begin ToggleDay(FSel, D); Exit; end;
  It := ItemAt(X, Y, Z);
  FMoved := False;
  if It <> nil then
  begin
    Select(It);
    if FReadOnly or It.Wraps then Exit;
    FDragItem := It;
    FDrag := Z + Ord(Z = 1);          { 1 tijelo -> 2 pomak }
    FDownMin := XToMin(X);
    FOrigStart := It.StartMin;
    FOrigEnd := It.EndMin;
    Exit;
  end;
  D := DayAt(Y);
  if (D = 0) or FReadOnly then begin Select(nil); Exit; end;
  { nova traka }
  if not Assigned(FOnCreate) then Exit;
  Id := '';
  FDownMin := XToMin(X);
  FOnCreate(Self, D, FDownMin, Min(1440, FDownMin + 60), Id);
  if Id = '' then Exit;
  It := AddItem(Id, IntToStr(D), FDownMin, Min(1440, FDownMin + 60), 0, 0);
  Select(It);
  FDragItem := It;
  FDrag := 1;
  FOrigStart := It.StartMin;
  FOrigEnd := It.EndMin;
  Invalidate;
end;

procedure TaOwnTimeline.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  M, Delta, Len: Integer;
  It: TaTimeItem;
  Z: Integer;
begin
  inherited MouseMove(Shift, X, Y);
  if (FDrag = 0) or (FDragItem = nil) then
  begin
    It := ItemAt(X, Y, Z);
    if (It <> nil) and not It.Wraps and not FReadOnly and (Z in [3, 4]) then Cursor := crSizeWE
    else if (It <> nil) and not It.Wraps and not FReadOnly then Cursor := crSizeAll
    else Cursor := crDefault;
    Exit;
  end;
  M := XToMin(X);
  case FDrag of
    1, 4: FDragItem.EndMin := Max(FDragItem.StartMin + Snap, M);
    3: FDragItem.StartMin := Min(FDragItem.EndMin - Snap, M);
    2:
      begin
        Delta := M - FDownMin;
        Len := FOrigEnd - FOrigStart;
        FDragItem.StartMin := Max(0, Min(1440 - Len, FOrigStart + Delta));
        FDragItem.EndMin := FDragItem.StartMin + Len;
      end;
  end;
  FMoved := True;
  Invalidate;
end;

procedure TaOwnTimeline.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if (FDrag <> 0) and (FDragItem <> nil) and (FMoved or (FDrag = 1)) then Commit(FDragItem);
  FDrag := 0;
  FDragItem := nil;
end;

procedure TaOwnTimeline.KeyDown(var Key: Word; Shift: TShiftState);
var
  Step, Len: Integer;
begin
  inherited KeyDown(Key, Shift);
  if Key = 0 then Exit;
  if (Key = VK_DELETE) then begin DeleteSelected; Key := 0; Exit; end;
  if (FSel = nil) or FReadOnly or FSel.Wraps or (FSel.EveryMin > 0) then Exit;
  Step := 0;
  if Key = VK_LEFT then Step := -Snap else if Key = VK_RIGHT then Step := Snap else Exit;
  if ssShift in Shift then
    FSel.EndMin := Max(FSel.StartMin + Snap, Min(1440, FSel.EndMin + Step))
  else
  begin
    Len := FSel.EndMin - FSel.StartMin;
    FSel.StartMin := Max(0, Min(1440 - Len, FSel.StartMin + Step));
    FSel.EndMin := FSel.StartMin + Len;
  end;
  Commit(FSel);
  Key := 0;
end;

procedure TaOwnTimeline.DoEnter;
begin
  inherited DoEnter;
  Invalidate;
end;

procedure TaOwnTimeline.DoExit;
begin
  inherited DoExit;
  Invalidate;
end;

end.
