unit ta_ownmemo;
{ Vlastito visenjredno polje (pruzatelj 'own', varijanta plain obitelji Memo): crta se samo, pa izgleda i radi isto na svakom sucelju.
  Zna: unos i brisanje preko redaka (Enter, Backspace, Delete spajaju retke), prijelom redaka po rijecima (ili vodoravno pomicanje),
  kursor i oznacavanje tipkama (strelice, Home/End, PgUp/PgDn, Ctrl uz rijeci i pocetak/kraj teksta) i mišem (klik, povlacenje,
  dvoklik), Ctrl+A/C/X/V/Z/Y, kotacic i klizac, najvecu duljinu, samo citanje, boje iz teme.
  Ne zna (zasad): unos preko IME-a, kontekstni izbornik, povlacenje teksta, trostruki klik. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, ExtCtrls, LCLType, Clipbrd, LazUTF8, ta_family, ta_memo;

type
  TaMemoPos = record
    Row, Col: Integer;      { Col u znakovima (ne bajtovima) }
  end;

  TaVisLine = record
    Row, C0, C1: Integer;   { dio retka [C0, C1) koji se vidi u jednom prikazanom retku }
  end;

  TaOwnMemo = class(TCustomControl)
  private
    FLines: TStringList;
    FVis: array of TaVisLine;
    FCaret, FAnchor: TaMemoPos;
    FGoalX: Integer;
    FTopVis, FScrollX: Integer;
    FWrap, FReadOnly, FCaretOn, FDragging, FDragThumb: Boolean;
    FMaxLength: Integer;
    FOnChange: TNotifyEvent;
    FTimer: TTimer;
    FUndo, FRedo: TStringList;
    FLayoutW: Integer;
    FLayoutDirty: Boolean;
    function GetText: string;
    procedure SetTextValue(const AValue: string);
    procedure SetWrap(AValue: Boolean);
    procedure SetReadOnly(AValue: Boolean);
    procedure TimerTick(Sender: TObject);
    function LineH: Integer;
    function TextW: Integer;
    function VisRows: Integer;
    procedure Relayout;
    procedure EnsureLayout;
    function VisOf(const P: TaMemoPos): Integer;
    function XOf(const P: TaMemoPos): Integer;
    function PosInVis(AVis, AX: Integer): TaMemoPos;
    function PosAt(X, Y: Integer): TaMemoPos;
    procedure EnsureCaretVisible;
    function Cmp(const A, B: TaMemoPos): Integer;
    function SelA: TaMemoPos;
    function SelB: TaMemoPos;
    function HasSel: Boolean;
    function RangeText(const A, B: TaMemoPos): string;
    function TotalLen: Integer;
    procedure ReplaceRange(A, B: TaMemoPos; const S0: string);
    procedure PushUndo;
    procedure RestoreFrom(AFrom, ATo: TStringList);
    procedure MoveTo(const P: TaMemoPos; AExtend: Boolean; AKeepGoal: Boolean = False);
    function PrevPos(const P: TaMemoPos): TaMemoPos;
    function NextPos(const P: TaMemoPos): TaMemoPos;
    function WordLeft(const P: TaMemoPos): TaMemoPos;
    function WordRight(const P: TaMemoPos): TaMemoPos;
    procedure MoveVert(ADelta: Integer; AExtend: Boolean);
    procedure ThumbTo(Y: Integer);
    procedure Changed;
  protected
    function RealGetText: TCaption; override;
    procedure RealSetText(const AValue: TCaption); override;
    procedure Paint; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure UTF8KeyPress(var UTF8Key: TUTF8Char); override;
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
    procedure InsertText(const AText: string);
    procedure SelectAll;
    procedure CopyToClipboard;
    procedure CutToClipboard;
    procedure PasteFromClipboard;
    function LineCount: Integer;
    function VisualLineCount: Integer;
    function CaretRow: Integer;
    function CaretCol: Integer;
    function SelectedText: string;
    property WordWrap: Boolean read FWrap write SetWrap;
    property ReadOnly: Boolean read FReadOnly write SetReadOnly;
    property MaxLength: Integer read FMaxLength write FMaxLength;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

  { markdown: izvorni tekst u vlastitom polju, pregled na vlastitom rich uredjivaču }
  TaOwnMarkdownEngine = class(TaMemoMarkdownEngine)
  protected
    function MakeEdit(AParent: TWinControl): TWinControl; override;
    function EdText: string; override;
    procedure EdSetText(const AValue: string); override;
    procedure EdReadOnly(AValue: Boolean); override;
    procedure EdMaxLength(AValue: Integer); override;
    procedure EdWrap(AValue: Boolean); override;
  public
    class function Provider: string; override;
  end;

  TaOwnMemoEngine = class(TaEngine)
  private
    FMemo: TaOwnMemo;
  public
    constructor Create(AHost: TaFamilyHost); override;
    class function Provider: string; override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
    procedure SetReadOnly(AValue: Boolean); override;
    procedure SetMaxLength(AValue: Integer); override;
    procedure ApplyOptions(AOptions: TPersistent); override;
  end;

implementation

uses
  Math, ta_tokens;

const
  PadX = 8;
  PadY = 5;
  BarW = 10;

function Pos2(ARow, ACol: Integer): TaMemoPos;
begin
  Result.Row := ARow;
  Result.Col := ACol;
end;

function IsWordCh(const S: string): Boolean;
begin
  if S = '' then Exit(False);
  Result := (Ord(S[1]) >= 128) or (S[1] in ['0'..'9', 'a'..'z', 'A'..'Z', '_']);
end;

{ ---------------- osnova ---------------- }

constructor TaOwnMemo.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ApplyThemeFont(Font);
  ControlStyle := ControlStyle + [csOpaque, csCaptureMouse, csClickEvents, csDoubleClicks];
  TabStop := True;
  Cursor := crIBeam;
  FLines := TStringList.Create;
  FLines.Add('');
  Width := 200;
  Height := 100;
  FUndo := TStringList.Create;
  FRedo := TStringList.Create;
  FWrap := True;
  FGoalX := -1;
  FLayoutDirty := True;
  FTimer := TTimer.Create(Self);
  FTimer.Enabled := False;
  FTimer.Interval := 530;
  FTimer.OnTimer := @TimerTick;
end;

destructor TaOwnMemo.Destroy;
begin
  FTimer.Enabled := False;
  FLines.Free;
  FUndo.Free;
  FRedo.Free;
  inherited Destroy;
end;

procedure TaOwnMemo.TimerTick(Sender: TObject);
begin
  FCaretOn := not FCaretOn;
  Invalidate;
end;

procedure TaOwnMemo.Changed;
begin
  FLayoutDirty := True;
  if Assigned(FOnChange) then FOnChange(Self);
end;

function TaOwnMemo.LineH: Integer;
begin
  Canvas.Font.Assign(Font);
  Result := Canvas.TextHeight('Ag') + 3;
end;

function TaOwnMemo.TextW: Integer;
begin
  Result := Max(20, Width - 2 * PadX - BarW);
end;

function TaOwnMemo.VisRows: Integer;
begin
  Result := Max(1, (Height - 2 * PadY) div LineH);
end;

function TaOwnMemo.LineCount: Integer;
begin
  Result := FLines.Count;
end;

function TaOwnMemo.VisualLineCount: Integer;
begin
  EnsureLayout;
  Result := Length(FVis);
end;

function TaOwnMemo.CaretRow: Integer;
begin
  Result := FCaret.Row;
end;

function TaOwnMemo.CaretCol: Integer;
begin
  Result := FCaret.Col;
end;

{ ---------------- tekst ---------------- }

function TaOwnMemo.GetText: string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to FLines.Count - 1 do
  begin
    if I > 0 then Result := Result + LineEnding;
    Result := Result + FLines[I];
  end;
end;

procedure TaOwnMemo.SetTextValue(const AValue: string);
var
  S: string;
  P: Integer;
begin
  S := StringReplace(StringReplace(AValue, #13#10, #10, [rfReplaceAll]), #13, #10, [rfReplaceAll]);
  if (FMaxLength > 0) and (UTF8Length(S) > FMaxLength) then S := UTF8Copy(S, 1, FMaxLength);
  FLines.Clear;
  repeat
    P := Pos(#10, S);
    if P = 0 then begin FLines.Add(S); Break; end;
    FLines.Add(Copy(S, 1, P - 1));
    Delete(S, 1, P);
  until False;
end;

function TaOwnMemo.RealGetText: TCaption;
begin
  Result := GetText;
end;

procedure TaOwnMemo.RealSetText(const AValue: TCaption);
begin
  if GetText = AValue then Exit;
  SetTextValue(AValue);
  FCaret := Pos2(0, 0);
  FAnchor := FCaret;
  FTopVis := 0;
  FScrollX := 0;
  FUndo.Clear;
  FRedo.Clear;
  Invalidate;
  Changed;
end;

procedure TaOwnMemo.SetWrap(AValue: Boolean);
begin
  if FWrap = AValue then Exit;
  FWrap := AValue;
  FLayoutDirty := True;
  FScrollX := 0;
  Invalidate;
end;

procedure TaOwnMemo.SetReadOnly(AValue: Boolean);
begin
  if FReadOnly = AValue then Exit;
  FReadOnly := AValue;
  Invalidate;
end;

{ ---------------- raspored (prijelom redaka) ---------------- }

procedure TaOwnMemo.Relayout;
var
  R, C, Lo, Hi, Mid, K, Len, N: Integer;
  S: string;
  AW: Integer;

  procedure Add(ARow, A, B: Integer);
  begin
    SetLength(FVis, N + 1);
    FVis[N].Row := ARow;
    FVis[N].C0 := A;
    FVis[N].C1 := B;
    Inc(N);
  end;

begin
  Canvas.Font.Assign(Font);
  AW := TextW;
  N := 0;
  SetLength(FVis, 0);
  for R := 0 to FLines.Count - 1 do
  begin
    S := FLines[R];
    Len := UTF8Length(S);
    if (not FWrap) or (Len = 0) or (Canvas.TextWidth(S) <= AW) then
    begin
      Add(R, 0, Len);
      Continue;
    end;
    C := 0;
    while C < Len do
    begin
      if Canvas.TextWidth(UTF8Copy(S, C + 1, Len - C)) <= AW then Mid := Len
      else
      begin
        Lo := C + 1;
        Hi := Len;
        while Lo < Hi do
        begin
          Mid := (Lo + Hi + 1) div 2;
          if Canvas.TextWidth(UTF8Copy(S, C + 1, Mid - C)) <= AW then Lo := Mid else Hi := Mid - 1;
        end;
        Mid := Lo;
        if (Mid < Len) and (UTF8Copy(S, Mid + 1, 1) <> ' ') then
        begin
          K := Mid;
          while (K > C + 1) and (UTF8Copy(S, K, 1) <> ' ') do Dec(K);
          if K > C + 1 then Mid := K;
        end;
      end;
      Add(R, C, Mid);
      C := Mid;
    end;
  end;
  FLayoutW := Width;
  FLayoutDirty := False;
end;

procedure TaOwnMemo.EnsureLayout;
begin
  if FLayoutDirty or (FLayoutW <> Width) then Relayout;
end;

function TaOwnMemo.VisOf(const P: TaMemoPos): Integer;
var
  I: Integer;
  Last: Boolean;
begin
  EnsureLayout;
  for I := 0 to High(FVis) do
    if FVis[I].Row = P.Row then
    begin
      Last := (I = High(FVis)) or (FVis[I + 1].Row <> P.Row);
      if (P.Col >= FVis[I].C0) and ((P.Col < FVis[I].C1) or (Last and (P.Col <= FVis[I].C1))) then Exit(I);
    end;
  Result := Max(0, High(FVis));
end;

function TaOwnMemo.XOf(const P: TaMemoPos): Integer;
var
  V: Integer;
begin
  V := VisOf(P);
  Canvas.Font.Assign(Font);
  if V < 0 then Exit(0);
  Result := Canvas.TextWidth(UTF8Copy(FLines[P.Row], FVis[V].C0 + 1, P.Col - FVis[V].C0));
end;

function TaOwnMemo.PosInVis(AVis, AX: Integer): TaMemoPos;
var
  V: TaVisLine;
  I, A, B, MaxCol: Integer;
  S: string;
  Last: Boolean;
begin
  EnsureLayout;
  AVis := Max(0, Min(High(FVis), AVis));
  V := FVis[AVis];
  S := FLines[V.Row];
  Canvas.Font.Assign(Font);
  Last := (AVis = High(FVis)) or (FVis[AVis + 1].Row <> V.Row);
  MaxCol := V.C1;
  if (not Last) and (MaxCol > V.C0) then Dec(MaxCol);
  Result := Pos2(V.Row, MaxCol);
  for I := V.C0 to MaxCol - 1 do
  begin
    A := Canvas.TextWidth(UTF8Copy(S, V.C0 + 1, I - V.C0));
    B := Canvas.TextWidth(UTF8Copy(S, V.C0 + 1, I + 1 - V.C0));
    if AX < (A + B) div 2 then Exit(Pos2(V.Row, I));
  end;
end;

function TaOwnMemo.PosAt(X, Y: Integer): TaMemoPos;
var
  V: Integer;
begin
  EnsureLayout;
  V := FTopVis + (Y - PadY) div LineH;
  if Y < PadY then V := FTopVis - 1;
  V := Max(0, Min(High(FVis), V));
  Result := PosInVis(V, X - PadX + FScrollX);
end;

procedure TaOwnMemo.EnsureCaretVisible;
var
  V, Cx, Rows: Integer;
begin
  EnsureLayout;
  V := VisOf(FCaret);
  Rows := VisRows;
  if V < FTopVis then FTopVis := V;
  if V >= FTopVis + Rows then FTopVis := V - Rows + 1;
  FTopVis := Max(0, Min(FTopVis, Max(0, Length(FVis) - Rows)));
  if not FWrap then
  begin
    Cx := XOf(FCaret);
    if Cx - FScrollX > TextW - 4 then FScrollX := Cx - TextW + 4;
    if Cx - FScrollX < 0 then FScrollX := Cx;
    if FScrollX < 0 then FScrollX := 0;
  end;
end;

{ ---------------- polozaji i oznaka ---------------- }

function TaOwnMemo.Cmp(const A, B: TaMemoPos): Integer;
begin
  if A.Row <> B.Row then Result := A.Row - B.Row else Result := A.Col - B.Col;
end;

function TaOwnMemo.SelA: TaMemoPos;
begin
  if Cmp(FCaret, FAnchor) <= 0 then Result := FCaret else Result := FAnchor;
end;

function TaOwnMemo.SelB: TaMemoPos;
begin
  if Cmp(FCaret, FAnchor) <= 0 then Result := FAnchor else Result := FCaret;
end;

function TaOwnMemo.HasSel: Boolean;
begin
  Result := Cmp(FCaret, FAnchor) <> 0;
end;

function TaOwnMemo.RangeText(const A, B: TaMemoPos): string;
var
  I: Integer;
begin
  if A.Row = B.Row then Exit(UTF8Copy(FLines[A.Row], A.Col + 1, B.Col - A.Col));
  Result := UTF8Copy(FLines[A.Row], A.Col + 1, MaxInt);
  for I := A.Row + 1 to B.Row - 1 do Result := Result + LineEnding + FLines[I];
  Result := Result + LineEnding + UTF8Copy(FLines[B.Row], 1, B.Col);
end;

function TaOwnMemo.SelectedText: string;
begin
  Result := RangeText(SelA, SelB);
end;

function TaOwnMemo.TotalLen: Integer;
var
  I: Integer;
begin
  Result := Max(0, FLines.Count - 1);
  for I := 0 to FLines.Count - 1 do Inc(Result, UTF8Length(FLines[I]));
end;

function TaOwnMemo.PrevPos(const P: TaMemoPos): TaMemoPos;
begin
  if P.Col > 0 then Result := Pos2(P.Row, P.Col - 1)
  else if P.Row > 0 then Result := Pos2(P.Row - 1, UTF8Length(FLines[P.Row - 1]))
  else Result := P;
end;

function TaOwnMemo.NextPos(const P: TaMemoPos): TaMemoPos;
begin
  if P.Col < UTF8Length(FLines[P.Row]) then Result := Pos2(P.Row, P.Col + 1)
  else if P.Row < FLines.Count - 1 then Result := Pos2(P.Row + 1, 0)
  else Result := P;
end;

function TaOwnMemo.WordLeft(const P: TaMemoPos): TaMemoPos;
var
  S: string;
begin
  Result := P;
  if (Result.Col = 0) and (Result.Row > 0) then Exit(PrevPos(Result));
  S := FLines[Result.Row];
  while (Result.Col > 0) and not IsWordCh(UTF8Copy(S, Result.Col, 1)) do Dec(Result.Col);
  while (Result.Col > 0) and IsWordCh(UTF8Copy(S, Result.Col, 1)) do Dec(Result.Col);
end;

function TaOwnMemo.WordRight(const P: TaMemoPos): TaMemoPos;
var
  S: string;
  L: Integer;
begin
  Result := P;
  S := FLines[Result.Row];
  L := UTF8Length(S);
  if (Result.Col >= L) and (Result.Row < FLines.Count - 1) then Exit(NextPos(Result));
  while (Result.Col < L) and IsWordCh(UTF8Copy(S, Result.Col + 1, 1)) do Inc(Result.Col);
  while (Result.Col < L) and not IsWordCh(UTF8Copy(S, Result.Col + 1, 1)) do Inc(Result.Col);
end;

procedure TaOwnMemo.MoveTo(const P: TaMemoPos; AExtend: Boolean; AKeepGoal: Boolean);
begin
  FCaret := P;
  if not AExtend then FAnchor := P;
  if not AKeepGoal then FGoalX := -1;
  FCaretOn := True;
  EnsureCaretVisible;
  Invalidate;
end;

procedure TaOwnMemo.MoveVert(ADelta: Integer; AExtend: Boolean);
var
  V, T: Integer;
begin
  EnsureLayout;
  V := VisOf(FCaret);
  T := V + ADelta;
  if T < 0 then begin MoveTo(Pos2(0, 0), AExtend); Exit; end;
  if T > High(FVis) then begin MoveTo(Pos2(FLines.Count - 1, UTF8Length(FLines[FLines.Count - 1])), AExtend); Exit; end;
  if FGoalX < 0 then FGoalX := XOf(FCaret);
  MoveTo(PosInVis(T, FGoalX), AExtend, True);
end;

{ ---------------- izmjene ---------------- }

procedure TaOwnMemo.PushUndo;
begin
  FUndo.AddObject(GetText, TObject(PtrInt(FCaret.Row * 100000 + FCaret.Col)));
  if FUndo.Count > 100 then FUndo.Delete(0);
  FRedo.Clear;
end;

procedure TaOwnMemo.RestoreFrom(AFrom, ATo: TStringList);
var
  I, Code: Integer;
begin
  if AFrom.Count = 0 then Exit;
  I := AFrom.Count - 1;
  ATo.AddObject(GetText, TObject(PtrInt(FCaret.Row * 100000 + FCaret.Col)));
  Code := PtrInt(AFrom.Objects[I]);
  SetTextValue(AFrom[I]);
  AFrom.Delete(I);
  FCaret := Pos2(Min(Code div 100000, FLines.Count - 1), 0);
  FCaret.Col := Min(Code mod 100000, UTF8Length(FLines[FCaret.Row]));
  FAnchor := FCaret;
  FLayoutDirty := True;
  EnsureCaretVisible;
  Invalidate;
  Changed;
end;

procedure TaOwnMemo.ReplaceRange(A, B: TaMemoPos; const S0: string);
var
  S, LeftS, RightS: string;
  Room, N, K: Integer;
  Parts: TStringList;
  P: Integer;
begin
  if FReadOnly then Exit;
  S := StringReplace(StringReplace(S0, #13#10, #10, [rfReplaceAll]), #13, #10, [rfReplaceAll]);
  PushUndo;
  { brisanje [A, B) }
  if A.Row = B.Row then
  begin
    LeftS := FLines[A.Row];
    UTF8Delete(LeftS, A.Col + 1, B.Col - A.Col);
    FLines[A.Row] := LeftS;
  end
  else
  begin
    LeftS := UTF8Copy(FLines[A.Row], 1, A.Col);
    RightS := UTF8Copy(FLines[B.Row], B.Col + 1, MaxInt);
    FLines[A.Row] := LeftS + RightS;
    for K := B.Row downto A.Row + 1 do FLines.Delete(K);
  end;
  { najveca duljina }
  if FMaxLength > 0 then
  begin
    Room := FMaxLength - TotalLen;
    if Room <= 0 then S := ''
    else if UTF8Length(S) > Room then S := UTF8Copy(S, 1, Room);
  end;
  { umetanje na A }
  Parts := TStringList.Create;
  try
    repeat
      P := Pos(#10, S);
      if P = 0 then begin Parts.Add(S); Break; end;
      Parts.Add(Copy(S, 1, P - 1));
      Delete(S, 1, P);
    until False;
    LeftS := UTF8Copy(FLines[A.Row], 1, A.Col);
    RightS := UTF8Copy(FLines[A.Row], A.Col + 1, MaxInt);
    N := Parts.Count;
    if N = 1 then
    begin
      FLines[A.Row] := LeftS + Parts[0] + RightS;
      FCaret := Pos2(A.Row, A.Col + UTF8Length(Parts[0]));
    end
    else
    begin
      FLines[A.Row] := LeftS + Parts[0];
      for K := 1 to N - 2 do FLines.Insert(A.Row + K, Parts[K]);
      FLines.Insert(A.Row + N - 1, Parts[N - 1] + RightS);
      FCaret := Pos2(A.Row + N - 1, UTF8Length(Parts[N - 1]));
    end;
  finally
    Parts.Free;
  end;
  FAnchor := FCaret;
  FGoalX := -1;
  FLayoutDirty := True;
  FCaretOn := True;
  EnsureCaretVisible;
  Invalidate;
  Changed;
end;

procedure TaOwnMemo.InsertText(const AText: string);
begin
  ReplaceRange(SelA, SelB, AText);
end;

procedure TaOwnMemo.SelectAll;
begin
  FAnchor := Pos2(0, 0);
  FCaret := Pos2(FLines.Count - 1, UTF8Length(FLines[FLines.Count - 1]));
  EnsureCaretVisible;
  Invalidate;
end;

procedure TaOwnMemo.CopyToClipboard;
begin
  if HasSel then Clipboard.AsText := SelectedText;
end;

procedure TaOwnMemo.CutToClipboard;
begin
  if FReadOnly or not HasSel then Exit;
  CopyToClipboard;
  ReplaceRange(SelA, SelB, '');
end;

procedure TaOwnMemo.PasteFromClipboard;
begin
  if FReadOnly then Exit;
  if Clipboard.HasFormat(CF_TEXT) then InsertText(Clipboard.AsText);
end;

procedure TaOwnMemo.ThumbTo(Y: Integer);
var
  Span: Integer;
begin
  EnsureLayout;
  Span := Length(FVis) - VisRows;
  if Span <= 0 then Exit;
  FTopVis := Max(0, Min(Span, Round((Y - PadY) / Max(1, Height - 2 * PadY) * Length(FVis) - VisRows / 2)));
  Invalidate;
end;

procedure TaOwnMemo.Paint;
var
  T: TaThemeTokens;
  Bg, Br, Tx, SelBg, SelTx: TColor;
  R, I, Y, Lh, X0, Rows, Fin, ThH, ThY, S0, S1, Ra, Rb: Integer;
  V: TaVisLine;
  A, B: TaMemoPos;
  Foc: Boolean;
  Seg: string;
  Cx: Integer;
  Cpos: Integer;
begin
  EnsureLayout;
  T := ActiveTokens;
  Foc := Focused;
  if Enabled and not FReadOnly then Bg := TokenColor(T.Surface) else Bg := TokenColor(T.Soft);
  if Foc then Br := TokenColor(T.Accent) else Br := TokenColor(T.Border);
  if Enabled then Tx := TokenColor(T.Text) else Tx := TokenColor(T.TextSoft);
  if Enabled and (Font.Color <> clWindowText) and (Font.Color <> clDefault) then Tx := Font.Color;
  SelBg := TokenColor(T.Accent);
  SelTx := TokenColor(T.OnAccent);
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
  Canvas.Font.Color := Tx;
  Lh := LineH;
  Rows := VisRows;
  A := SelA;
  B := SelB;
  X0 := PadX - FScrollX;
  Canvas.ClipRect := Rect(PadX - 2, PadY - 1, Width - PadX - BarW + 2, Height - PadY + 1);
  Canvas.Clipping := True;
  Fin := Min(High(FVis), FTopVis + Rows);
  for I := FTopVis to Fin do
  begin
    V := FVis[I];
    Y := PadY + (I - FTopVis) * Lh;
    Seg := UTF8Copy(FLines[V.Row], V.C0 + 1, V.C1 - V.C0);
    { oznaka na ovom prikazanom retku }
    Ra := -1;
    Rb := -1;
    if HasSel and (V.Row >= A.Row) and (V.Row <= B.Row) then
    begin
      if V.Row = A.Row then Ra := Max(A.Col, V.C0) else Ra := V.C0;
      if V.Row = B.Row then Rb := Min(B.Col, V.C1) else Rb := V.C1;
      if (V.Row < B.Row) and (V.C1 = UTF8Length(FLines[V.Row])) then Rb := V.C1 + 0;
    end;
    if Foc and (Ra >= 0) and ((Rb > Ra) or ((V.Row < B.Row) and (Rb >= Ra))) then
    begin
      S0 := Canvas.TextWidth(UTF8Copy(Seg, 1, Ra - V.C0));
      S1 := Canvas.TextWidth(UTF8Copy(Seg, 1, Rb - V.C0));
      if (V.Row < B.Row) and (V.C1 = UTF8Length(FLines[V.Row])) then Inc(S1, 6);
      Canvas.Brush.Color := SelBg;
      Canvas.FillRect(X0 + S0, Y, X0 + S1, Y + Lh);
      Canvas.Brush.Style := bsClear;
      Canvas.Font.Color := Tx;
      Canvas.TextOut(X0, Y + 1, UTF8Copy(Seg, 1, Ra - V.C0));
      Canvas.Font.Color := SelTx;
      Canvas.TextOut(X0 + S0, Y + 1, UTF8Copy(Seg, Ra - V.C0 + 1, Max(0, Rb - Ra)));
      Canvas.Font.Color := Tx;
      Canvas.TextOut(X0 + Canvas.TextWidth(UTF8Copy(Seg, 1, Rb - V.C0)), Y + 1, UTF8Copy(Seg, Rb - V.C0 + 1, MaxInt));
      Canvas.Brush.Style := bsSolid;
    end
    else
    begin
      Canvas.Brush.Style := bsClear;
      Canvas.TextOut(X0, Y + 1, Seg);
      Canvas.Brush.Style := bsSolid;
    end;
  end;
  { kursor }
  if Foc and FCaretOn and not HasSel and not FReadOnly then
  begin
    Cpos := VisOf(FCaret);
    if (Cpos >= FTopVis) and (Cpos <= FTopVis + Rows) then
    begin
      Cx := X0 + XOf(FCaret);
      Y := PadY + (Cpos - FTopVis) * Lh;
      Canvas.Pen.Color := Tx;
      Canvas.Line(Cx, Y + 1, Cx, Y + Lh - 1);
    end;
  end;
  Canvas.Clipping := False;
  { klizac }
  if Length(FVis) > Rows then
  begin
    ThH := Max(18, (Height - 2 * PadY) * Rows div Length(FVis));
    ThY := PadY + (Height - 2 * PadY - ThH) * FTopVis div Max(1, Length(FVis) - Rows);
    Canvas.Brush.Color := TokenColor(T.Border);
    Canvas.Pen.Style := psClear;
    Canvas.RoundRect(Width - BarW - 1, ThY, Width - 3, ThY + ThH, 4, 4);
    Canvas.Pen.Style := psSolid;
  end;
end;

procedure TaOwnMemo.KeyDown(var Key: Word; Shift: TShiftState);
var
  Ext, Ctl: Boolean;
  P, Q: TaMemoPos;
  V: TaVisLine;
begin
  inherited KeyDown(Key, Shift);
  if Key = 0 then Exit;
  Ext := ssShift in Shift;
  Ctl := ssCtrl in Shift;
  case Key of
    VK_LEFT:
      begin
        if HasSel and not Ext then MoveTo(SelA, False)
        else if Ctl then MoveTo(WordLeft(FCaret), Ext)
        else MoveTo(PrevPos(FCaret), Ext);
        Key := 0;
      end;
    VK_RIGHT:
      begin
        if HasSel and not Ext then MoveTo(SelB, False)
        else if Ctl then MoveTo(WordRight(FCaret), Ext)
        else MoveTo(NextPos(FCaret), Ext);
        Key := 0;
      end;
    VK_UP: begin MoveVert(-1, Ext); Key := 0; end;
    VK_DOWN: begin MoveVert(1, Ext); Key := 0; end;
    VK_PRIOR: begin MoveVert(-VisRows, Ext); Key := 0; end;
    VK_NEXT: begin MoveVert(VisRows, Ext); Key := 0; end;
    VK_HOME:
      begin
        if Ctl then MoveTo(Pos2(0, 0), Ext)
        else
        begin
          EnsureLayout;
          V := FVis[VisOf(FCaret)];
          MoveTo(Pos2(V.Row, V.C0), Ext);
        end;
        Key := 0;
      end;
    VK_END:
      begin
        if Ctl then MoveTo(Pos2(FLines.Count - 1, UTF8Length(FLines[FLines.Count - 1])), Ext)
        else
        begin
          EnsureLayout;
          P := FCaret;
          V := FVis[VisOf(P)];
          Q := Pos2(V.Row, V.C1);
          if (V.C1 < UTF8Length(FLines[V.Row])) and (V.C1 > V.C0) then Q.Col := V.C1 - 1;
          MoveTo(Q, Ext);
        end;
        Key := 0;
      end;
    VK_RETURN:
      begin
        if not FReadOnly then ReplaceRange(SelA, SelB, #10);
        Key := 0;
      end;
    VK_BACK:
      begin
        if not FReadOnly then
        begin
          if HasSel then ReplaceRange(SelA, SelB, '')
          else if Ctl then ReplaceRange(WordLeft(FCaret), FCaret, '')
          else if Cmp(FCaret, Pos2(0, 0)) > 0 then ReplaceRange(PrevPos(FCaret), FCaret, '');
        end;
        Key := 0;
      end;
    VK_DELETE:
      begin
        if Ext and not Ctl then begin CutToClipboard; Key := 0; Exit; end;
        if not FReadOnly then
        begin
          if HasSel then ReplaceRange(SelA, SelB, '')
          else if Ctl then ReplaceRange(FCaret, WordRight(FCaret), '')
          else ReplaceRange(FCaret, NextPos(FCaret), '');
        end;
        Key := 0;
      end;
    VK_INSERT:
      begin
        if Ext then PasteFromClipboard else if Ctl then CopyToClipboard;
        Key := 0;
      end;
    VK_A: if Shift = [ssCtrl] then begin SelectAll; Key := 0; end;
    VK_C: if Shift = [ssCtrl] then begin CopyToClipboard; Key := 0; end;
    VK_X: if Shift = [ssCtrl] then begin CutToClipboard; Key := 0; end;
    VK_V: if Shift = [ssCtrl] then begin PasteFromClipboard; Key := 0; end;
    VK_Z:
      if Shift = [ssCtrl] then begin if not FReadOnly then RestoreFrom(FUndo, FRedo); Key := 0; end
      else if Shift = [ssCtrl, ssShift] then begin if not FReadOnly then RestoreFrom(FRedo, FUndo); Key := 0; end;
    VK_Y: if Shift = [ssCtrl] then begin if not FReadOnly then RestoreFrom(FRedo, FUndo); Key := 0; end;
  end;
end;

procedure TaOwnMemo.UTF8KeyPress(var UTF8Key: TUTF8Char);
begin
  inherited UTF8KeyPress(UTF8Key);
  if UTF8Key = '' then Exit;
  if (Length(UTF8Key) = 1) and ((Ord(UTF8Key[1]) < 32) or (Ord(UTF8Key[1]) = 127)) then Exit;
  if FReadOnly then begin UTF8Key := ''; Exit; end;
  InsertText(UTF8Key);
  UTF8Key := '';
end;

procedure TaOwnMemo.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then Exit;
  if CanFocus and not Focused then SetFocus;
  EnsureLayout;
  if (Length(FVis) > VisRows) and (X >= Width - BarW - 3) then
  begin
    FDragThumb := True;
    ThumbTo(Y);
    Exit;
  end;
  MoveTo(PosAt(X, Y), ssShift in Shift);
  FDragging := True;
end;

procedure TaOwnMemo.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  if FDragThumb then begin ThumbTo(Y); Exit; end;
  if FDragging and (ssLeft in Shift) then MoveTo(PosAt(X, Y), True);
end;

procedure TaOwnMemo.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  FDragging := False;
  FDragThumb := False;
end;

procedure TaOwnMemo.DblClick;
var
  S: string;
  A, B: Integer;
  P: TaMemoPos;
begin
  inherited DblClick;
  P := FCaret;
  S := FLines[P.Row];
  A := P.Col;
  B := P.Col;
  while (A > 0) and IsWordCh(UTF8Copy(S, A, 1)) do Dec(A);
  while (B < UTF8Length(S)) and IsWordCh(UTF8Copy(S, B + 1, 1)) do Inc(B);
  FAnchor := Pos2(P.Row, A);
  FCaret := Pos2(P.Row, B);
  Invalidate;
end;

function TaOwnMemo.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
var
  Span: Integer;
begin
  EnsureLayout;
  Span := Length(FVis) - VisRows;
  Result := Span > 0;
  if Result then
  begin
    if WheelDelta > 0 then Dec(FTopVis, 3) else Inc(FTopVis, 3);
    FTopVis := Max(0, Min(Span, FTopVis));
    Invalidate;
  end;
end;

procedure TaOwnMemo.DoEnter;
begin
  inherited DoEnter;
  FCaretOn := True;
  FTimer.Enabled := True;
  Invalidate;
end;

procedure TaOwnMemo.DoExit;
begin
  FTimer.Enabled := False;
  FCaretOn := False;
  FDragging := False;
  inherited DoExit;
  Invalidate;
end;

procedure TaOwnMemo.Resize;
begin
  inherited Resize;
  FLayoutDirty := True;
  if (FLines = nil) or (Parent = nil) then Exit;
  EnsureCaretVisible;
end;

{ ---------------- pokretac ---------------- }

constructor TaOwnMemoEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FMemo := TaOwnMemo.Create(nil);
  FMemo.OnChange := @InnerChanged;
  AttachInner(FMemo);
end;

class function TaOwnMemoEngine.Provider: string;
begin
  Result := 'own';
end;

function TaOwnMemoEngine.GetText: string;
begin
  Result := FMemo.Text;
end;

procedure TaOwnMemoEngine.SetText(const AValue: string);
begin
  if FMemo.Text <> AValue then FMemo.Text := AValue;
end;

procedure TaOwnMemoEngine.SetReadOnly(AValue: Boolean);
begin
  FMemo.ReadOnly := AValue;
end;

procedure TaOwnMemoEngine.SetMaxLength(AValue: Integer);
begin
  FMemo.MaxLength := AValue;
end;

procedure TaOwnMemoEngine.ApplyOptions(AOptions: TPersistent);
begin
  if AOptions is TaMemoOptions then FMemo.WordWrap := TaMemoOptions(AOptions).WordWrap;
end;

function TaOwnMarkdownEngine.MakeEdit(AParent: TWinControl): TWinControl;
var
  M: TaOwnMemo;
begin
  M := TaOwnMemo.Create(AParent);
  M.Parent := AParent;
  M.Font.Name := 'JetBrains Mono';
  M.OnChange := @MemoChange;
  Result := M;
end;

class function TaOwnMarkdownEngine.Provider: string;
begin
  Result := 'own';
end;

function TaOwnMarkdownEngine.EdText: string;
begin
  Result := TaOwnMemo(FEdit).Text;
end;

procedure TaOwnMarkdownEngine.EdSetText(const AValue: string);
begin
  TaOwnMemo(FEdit).Text := AValue;
end;

procedure TaOwnMarkdownEngine.EdReadOnly(AValue: Boolean);
begin
  TaOwnMemo(FEdit).ReadOnly := AValue;
end;

procedure TaOwnMarkdownEngine.EdMaxLength(AValue: Integer);
begin
  TaOwnMemo(FEdit).MaxLength := AValue;
end;

procedure TaOwnMarkdownEngine.EdWrap(AValue: Boolean);
begin
  TaOwnMemo(FEdit).WordWrap := AValue;
end;

initialization
  RegisterEngine(MemoFamily, 'plain', TaOwnMemoEngine);
  RegisterEngine(MemoFamily, 'markdown', TaOwnMarkdownEngine);

end.
