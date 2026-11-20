unit ta_ownrich;
{ Vlastiti uredjivac formatiranog teksta (pruzatelj 'own'): crta se sam, bez RichMema, pa izgleda i radi isto na svakom sucelju.
  Isti model i isti zapis (mali HTML iz ta_richtext) kao uredjivac na RichMemu.
  Zna: tekst s podebljano / kurziv / podcrtano / boja / velicina po znaku, odlomke s poravnanjem i natuknicama, prijelom po rijecima,
  kursor i oznacavanje tipkama i misem, brisanje i spajanje odlomaka, Ctrl+A/C/X/V/Z/Y/B/I/U, kotacic i klizac, traku s gumbima
  (B I U, boja iz palete, velicina, poravnanje, natuknica, ocisti oblikovanje), samo citanje (traka se skriva).
  Ne zna (zasad): slike, tablice, hiperveze, unos preko IME-a, lijepljenje s oblikovanjem iz drugih programa. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, ExtCtrls, Forms, LCLType, LMessages, Clipbrd, LazUTF8,
  ta_richtext, ta_richbase;

type
  TRStyle = record
    Bold, Italic, Underline: Boolean;
    Color: Integer;       { $RRGGBB, -1 = zadana }
    Pt: Integer;          { 0 = zadana }
  end;

  TRCell = record
    Ch: string;           { jedan UTF-8 znak }
    St: TRStyle;
    W: Integer;
  end;

  TRPara = class
  public
    Align: TRtAlign;
    Bullet: Boolean;
    Cells: array of TRCell;
  end;

  TRPos = record
    Para, Off: Integer;
  end;

  TRLine = record
    Para, C0, C1, Y, H, X0: Integer;
  end;

  TRichCmd = (rcBold, rcItalic, rcUnderline, rcColor, rcLeft, rcCenter, rcRight, rcBullet, rcClear);

  TaRichSurface = class(TCustomControl)
  private
    FParas: TList;
    FLines: array of TRLine;
    FCaret, FAnchor: TRPos;
    FTyping: TRStyle;
    FTop, FContentH, FLayoutW, FGoalX: Integer;
    FReadOnly, FCaretOn, FDragging, FDirty, FLoading: Boolean;
    FUndo, FRedo: TStringList;
    FTimer: TTimer;
    FOnChange, FOnState: TNotifyEvent;
    FDefPx: Integer;
    function P(I: Integer): TRPara;
    function Cmp(const A, B: TRPos): Integer;
    function SelA: TRPos;
    function SelB: TRPos;
    function ParaLen(I: Integer): Integer;
    procedure TimerTick(Sender: TObject);
    procedure SetReadOnly(AValue: Boolean);
    procedure SetFont(const St: TRStyle; AColor: TColor);
    function PxOf(const St: TRStyle): Integer;
    procedure Layout;
    procedure EnsureLayout;
    function LineOf(const Q: TRPos): Integer;
    function XOf(const Q: TRPos): Integer;
    function PosAt(X, Y: Integer): TRPos;
    procedure EnsureCaretVisible;
    function FlatOf(const Q: TRPos): Integer;
    function PosOfFlat(N: Integer): TRPos;
    procedure Snapshot(ATo: TStringList);
    procedure PushUndo;
    procedure RestoreFrom(AFrom, ATo: TStringList);
    procedure Changed;
    procedure StateChanged;
    procedure SyncTyping;
    procedure MoveTo(const Q: TRPos; AExtend: Boolean; AKeepGoal: Boolean = False);
    function PrevPos(const Q: TRPos): TRPos;
    function NextPos(const Q: TRPos): TRPos;
    function WordLeft(const Q: TRPos): TRPos;
    function WordRight(const Q: TRPos): TRPos;
    procedure MoveVert(ADelta: Integer; AExtend: Boolean);
    procedure DeleteRange(A, B: TRPos);
    procedure DeleteSel;
    procedure InsertCell(const ACh: string);
    procedure SplitPara;
    function RangeText(const A, B: TRPos): string;
    procedure AllCells(const A, B: TRPos; AWhat: Integer; var AAll: Boolean);
    procedure SetAttr(const A, B: TRPos; AWhat: Integer; AOn: Boolean; AColor, APt: Integer);
    procedure ClearParas;
    procedure ThumbTo(Y: Integer);
  protected
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
    function GetHtml: string;
    procedure SetHtml(const AHtml: string);
    procedure InsertText(const AText: string);
    procedure SelectAll;
    procedure SelectFlat(AStart, ALen: Integer);
    procedure CopyToClipboard;
    procedure CutToClipboard;
    procedure PasteFromClipboard;
    procedure Undo;
    procedure Redo;
    procedure Toggle(ACmd: TRichCmd);
    procedure SetTextColor(ARgb: Integer);
    procedure SetSizePt(APt: Integer);
    function HasSel: Boolean;
    function SelectedText: string;
    function ParaCount: Integer;
    function CurrentStyle: TRStyle;
    function CurrentAlign: TRtAlign;
    function CurrentBullet: Boolean;
    function DefaultPt: Integer;
    function LineCount: Integer;
    property ReadOnly: Boolean read FReadOnly write SetReadOnly;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnState: TNotifyEvent read FOnState write FOnState;
  end;

  { traka s gumbima, iscrtana sama }
  TaRichBar = class(TCustomControl)
  private
    FSurface: TaRichSurface;
    FSwatch: TCustomControl;
    FHot: Integer;
    FSizeBox: TWinControl;
    FSyncing: Boolean;
    procedure SizePicked(Sender: TObject);
    procedure SwatchPicked(ARgb: Integer);
    procedure OpenSwatch;
    procedure CloseSwatch;
    procedure AppInput(Sender: TObject; var Msg: TLMessage);
    function ButtonAt(X: Integer): Integer;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure SyncFromSurface;
    procedure Attach(ASurface: TaRichSurface);
  end;

  TaOwnRichEdit = class(TaRichBase)
  private
    FBar: TaRichBar;
    FSurf: TaRichSurface;
    procedure SurfChanged(Sender: TObject);
    procedure SurfState(Sender: TObject);
  protected
    function GetHtml: string; override;
    procedure SetHtml(const AValue: string); override;
    procedure SetReadOnly(AValue: Boolean); override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure SelectRange(AStart, ALen: Integer); override;
    procedure ApplyBold; override;
    procedure ApplyItalic; override;
    procedure ApplyUnderline; override;
    procedure ApplyColorRgb(ARgb: Integer); override;
    procedure ApplySizePt(APt: Integer); override;
    procedure ApplyAlign(AAlign: TRtAlign); override;
    procedure ApplyBullet; override;
    property Surface: TaRichSurface read FSurf;
    property Bar: TaRichBar read FBar;
  end;

implementation

uses
  Math, ta_tokens, ta_owncombo, ta_i18n;

const
  PadX = 8;
  PadY = 5;
  BarW = 10;
  BulletIndent = 22;
  SizesList: array[0..8] of Integer = (8, 9, 10, 11, 12, 14, 16, 18, 24);
  SwatchCols: array[0..15] of Integer = (
    $000000, $7F7F7F, $C00000, $FF0000, $ED7D31, $FFC000, $FFFF00, $92D050,
    $00B050, $00B0F0, $0070C0, $002060, $7030A0, $FF66CC, $996633, $FFFFFF);

function NoStyle: TRStyle;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Color := -1;
end;

function SameStyle(const A, B: TRStyle): Boolean;
begin
  Result := (A.Bold = B.Bold) and (A.Italic = B.Italic) and (A.Underline = B.Underline) and (A.Color = B.Color) and (A.Pt = B.Pt);
end;

function RgbToColor(ARgb: Integer): TColor;
begin
  Result := TColor(((ARgb and $FF) shl 16) or (ARgb and $FF00) or ((ARgb shr 16) and $FF));
end;

function IsWordCh(const S: string): Boolean;
begin
  if S = '' then Exit(False);
  Result := (Ord(S[1]) >= 128) or (S[1] in ['0'..'9', 'a'..'z', 'A'..'Z', '_']);
end;

function PosR(APara, AOff: Integer): TRPos;
begin
  Result.Para := APara;
  Result.Off := AOff;
end;

{ ================= povrsina za uredjivanje ================= }

constructor TaRichSurface.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ApplyThemeFont(Font);
  ControlStyle := ControlStyle + [csOpaque, csCaptureMouse, csClickEvents, csDoubleClicks];
  TabStop := True;
  Cursor := crIBeam;
  FParas := TList.Create;
  FUndo := TStringList.Create;
  FRedo := TStringList.Create;
  FTyping := NoStyle;
  FGoalX := -1;
  FDirty := True;
  Width := 300;
  Height := 120;
  FTimer := TTimer.Create(Self);
  FTimer.Enabled := False;
  FTimer.Interval := 530;
  FTimer.OnTimer := @TimerTick;
  FParas.Add(TRPara.Create);
end;

destructor TaRichSurface.Destroy;
begin
  FTimer.Enabled := False;
  ClearParas;
  FParas.Free;
  FUndo.Free;
  FRedo.Free;
  inherited Destroy;
end;

procedure TaRichSurface.ClearParas;
var
  I: Integer;
begin
  for I := 0 to FParas.Count - 1 do TRPara(FParas[I]).Free;
  FParas.Clear;
end;

function TaRichSurface.P(I: Integer): TRPara;
begin
  Result := TRPara(FParas[I]);
end;

function TaRichSurface.ParaCount: Integer;
begin
  Result := FParas.Count;
end;

function TaRichSurface.LineCount: Integer;
begin
  EnsureLayout;
  Result := Length(FLines);
end;

function TaRichSurface.ParaLen(I: Integer): Integer;
begin
  Result := Length(P(I).Cells);
end;

function TaRichSurface.Cmp(const A, B: TRPos): Integer;
begin
  if A.Para <> B.Para then Result := A.Para - B.Para else Result := A.Off - B.Off;
end;

function TaRichSurface.SelA: TRPos;
begin
  if Cmp(FCaret, FAnchor) <= 0 then Result := FCaret else Result := FAnchor;
end;

function TaRichSurface.SelB: TRPos;
begin
  if Cmp(FCaret, FAnchor) <= 0 then Result := FAnchor else Result := FCaret;
end;

function TaRichSurface.HasSel: Boolean;
begin
  Result := Cmp(FCaret, FAnchor) <> 0;
end;

procedure TaRichSurface.TimerTick(Sender: TObject);
begin
  FCaretOn := not FCaretOn;
  Invalidate;
end;

procedure TaRichSurface.Changed;
begin
  FDirty := True;
  if (not FLoading) and Assigned(FOnChange) then FOnChange(Self);
  StateChanged;
end;

procedure TaRichSurface.StateChanged;
begin
  if Assigned(FOnState) then FOnState(Self);
end;

procedure TaRichSurface.SetReadOnly(AValue: Boolean);
begin
  if FReadOnly = AValue then Exit;
  FReadOnly := AValue;
  Invalidate;
end;

{ ---------------- model <-> HTML ---------------- }

function TaRichSurface.GetHtml: string;
var
  Doc: TRtDoc;
  I, K: Integer;
  Pa: TRtPara;
  Cur: TRtRun;
  Buf: string;
  C: TRCell;
begin
  Doc := TRtDoc.Create;
  try
    for I := 0 to FParas.Count - 1 do
    begin
      Pa := Doc.AddPara;
      Pa.Align := P(I).Align;
      Pa.Bullet := P(I).Bullet;
      Buf := '';
      FillChar(Cur, SizeOf(Cur), 0);
      Cur.Color := -1;
      for K := 0 to High(P(I).Cells) do
      begin
        C := P(I).Cells[K];
        if (K > 0) and not ((Cur.Bold = C.St.Bold) and (Cur.Italic = C.St.Italic) and (Cur.Underline = C.St.Underline) and
           (Cur.Color = C.St.Color) and (Cur.SizePt = C.St.Pt)) then
        begin
          Cur.Text := Buf;
          Pa.AddRun(Cur);
          Buf := '';
        end;
        Cur.Bold := C.St.Bold; Cur.Italic := C.St.Italic; Cur.Underline := C.St.Underline;
        Cur.Color := C.St.Color; Cur.SizePt := C.St.Pt;
        Buf := Buf + C.Ch;
      end;
      if Buf <> '' then
      begin
        Cur.Text := Buf;
        Pa.AddRun(Cur);
      end;
    end;
    Result := Doc.ToHtml;
  finally
    Doc.Free;
  end;
end;

procedure TaRichSurface.SetHtml(const AHtml: string);
var
  Doc: TRtDoc;
  I, J, K, N, Len: Integer;
  Pa: TRPara;
  R: TRtRun;
  St: TRStyle;
begin
  FLoading := True;
  Doc := TRtDoc.Create;
  try
    Doc.LoadHtml(AHtml);
    ClearParas;
    for I := 0 to Doc.Count - 1 do
    begin
      Pa := TRPara.Create;
      Pa.Align := Doc[I].Align;
      Pa.Bullet := Doc[I].Bullet;
      N := 0;
      for J := 0 to High(Doc[I].Runs) do
      begin
        R := Doc[I].Runs[J];
        St.Bold := R.Bold; St.Italic := R.Italic; St.Underline := R.Underline; St.Color := R.Color; St.Pt := R.SizePt;
        Len := UTF8Length(R.Text);
        SetLength(Pa.Cells, N + Len);
        for K := 1 to Len do
        begin
          Pa.Cells[N + K - 1].Ch := UTF8Copy(R.Text, K, 1);
          Pa.Cells[N + K - 1].St := St;
        end;
        Inc(N, Len);
      end;
      FParas.Add(Pa);
    end;
    if FParas.Count = 0 then FParas.Add(TRPara.Create);
  finally
    Doc.Free;
    FLoading := False;
  end;
  FCaret := PosR(0, 0);
  FAnchor := FCaret;
  FTop := 0;
  FTyping := NoStyle;
  FUndo.Clear;
  FRedo.Clear;
  FDirty := True;
  Invalidate;
  StateChanged;
end;

{ ---------------- raspored ---------------- }

function TaRichSurface.DefaultPt: Integer;
begin
  if (FDefPx = 0) and (Parent <> nil) then EnsureLayout;
  Result := Max(1, Round(FDefPx * 72 / 96));
end;

function TaRichSurface.PxOf(const St: TRStyle): Integer;
begin
  if St.Pt > 0 then Result := Round(St.Pt * 96 / 72) else Result := FDefPx;
end;

procedure TaRichSurface.SetFont(const St: TRStyle; AColor: TColor);
begin
  Canvas.Font.Name := Font.Name;
  Canvas.Font.Height := -PxOf(St);
  Canvas.Font.Style := [];
  if St.Bold then Canvas.Font.Style := Canvas.Font.Style + [fsBold];
  if St.Italic then Canvas.Font.Style := Canvas.Font.Style + [fsItalic];
  if St.Underline then Canvas.Font.Style := Canvas.Font.Style + [fsUnderline];
  if St.Color >= 0 then Canvas.Font.Color := RgbToColor(St.Color) else Canvas.Font.Color := AColor;
end;

procedure TaRichSurface.Layout;
var
  I, K, N, W, LastBrk, LineStart, Avail, Y, H, Indent, Lw, Ci, Cw: Integer;
  Pa: TRPara;
  Last: TRStyle;
  Have: Boolean;
  Def: TRStyle;

  procedure Emit(A, B: Integer);
  var
    J, Hh, Tw: Integer;
    X0: Integer;
  begin
    Hh := Max(FDefPx, 1) * 13 div 10;
    if B > A then Hh := 0;
    Tw := 0;
    for J := A to B - 1 do
    begin
      Hh := Max(Hh, PxOf(Pa.Cells[J].St) * 13 div 10);
      Tw := Tw + Pa.Cells[J].W;
    end;
    { zavrsni razmaci se ne racunaju u poravnanje }
    J := B - 1;
    while (J >= A) and (Pa.Cells[J].Ch = ' ') and (B < Length(Pa.Cells)) do
    begin
      Dec(Tw, Pa.Cells[J].W);
      Dec(J);
    end;
    X0 := PadX + Indent;
    case Pa.Align of
      raCenter: X0 := X0 + Max(0, (Avail - Tw) div 2);
      raRight: X0 := X0 + Max(0, Avail - Tw);
    end;
    SetLength(FLines, N + 1);
    FLines[N].Para := I;
    FLines[N].C0 := A;
    FLines[N].C1 := B;
    FLines[N].Y := Y;
    FLines[N].H := Hh;
    FLines[N].X0 := X0;
    Inc(N);
    Inc(Y, Hh);
  end;

begin
  Canvas.Font.Assign(Font);
  FDefPx := Abs(Canvas.Font.Height);
  if FDefPx = 0 then FDefPx := Round(Canvas.Font.Size * 96 / 72);
  if FDefPx = 0 then FDefPx := 13;
  Def := NoStyle;
  N := 0;
  Y := 0;
  SetLength(FLines, 0);
  FLayoutW := Width;
  for I := 0 to FParas.Count - 1 do
  begin
    Pa := P(I);
    if Pa.Bullet then Indent := BulletIndent else Indent := 0;
    Avail := Max(30, Width - 2 * PadX - BarW - Indent);
    { sirine znakova }
    Have := False;
    Last := Def;
    for K := 0 to High(Pa.Cells) do
    begin
      if (not Have) or not SameStyle(Last, Pa.Cells[K].St) then
      begin
        SetFont(Pa.Cells[K].St, clBlack);
        Last := Pa.Cells[K].St;
        Have := True;
      end;
      Pa.Cells[K].W := Canvas.TextWidth(Pa.Cells[K].Ch);
    end;
    if Length(Pa.Cells) = 0 then
    begin
      Emit(0, 0);
      Continue;
    end;
    Ci := 0;
    LineStart := 0;
    W := 0;
    LastBrk := -1;
    while Ci < Length(Pa.Cells) do
    begin
      Cw := Pa.Cells[Ci].W;
      if (W + Cw > Avail) and (Ci > LineStart) and (Pa.Cells[Ci].Ch <> ' ') then
      begin
        if LastBrk > LineStart then K := LastBrk else K := Ci;
        Emit(LineStart, K);
        LineStart := K;
        Ci := K;
        W := 0;
        LastBrk := -1;
        Continue;
      end;
      Inc(W, Cw);
      if Pa.Cells[Ci].Ch = ' ' then LastBrk := Ci + 1;
      Inc(Ci);
    end;
    Emit(LineStart, Length(Pa.Cells));
  end;
  FContentH := Y;
  H := Height - 2 * PadY;
  Lw := Max(0, FContentH - H);
  if FTop > Lw then FTop := Lw;
  if FTop < 0 then FTop := 0;
  FDirty := False;
end;

procedure TaRichSurface.EnsureLayout;
begin
  if FDirty or (FLayoutW <> Width) then Layout;
end;

procedure TaRichSurface.Resize;
begin
  inherited Resize;
  if (Parent <> nil) and (FParas <> nil) then
  begin
    FDirty := True;
    Invalidate;
  end;
end;

function TaRichSurface.LineOf(const Q: TRPos): Integer;
var
  I, Last: Integer;
begin
  EnsureLayout;
  Last := 0;
  for I := 0 to High(FLines) do
    if FLines[I].Para = Q.Para then
    begin
      Last := I;
      if Q.Off < FLines[I].C1 then Exit(I);
    end
    else if FLines[I].Para > Q.Para then Break;
  Result := Last;
end;

function TaRichSurface.XOf(const Q: TRPos): Integer;
var
  L, K, X: Integer;
begin
  L := LineOf(Q);
  X := FLines[L].X0;
  for K := FLines[L].C0 to Min(Q.Off, FLines[L].C1) - 1 do Inc(X, P(Q.Para).Cells[K].W);
  Result := X;
end;

function TaRichSurface.PosAt(X, Y: Integer): TRPos;
var
  I, L, K, Cx: Integer;
  Dy: Integer;
begin
  EnsureLayout;
  Dy := Y - PadY + FTop;
  L := High(FLines);
  for I := 0 to High(FLines) do
    if Dy < FLines[I].Y + FLines[I].H then begin L := I; Break; end;
  if L < 0 then Exit(PosR(0, 0));
  Cx := FLines[L].X0;
  K := FLines[L].C0;
  while K < FLines[L].C1 do
  begin
    if X < Cx + P(FLines[L].Para).Cells[K].W div 2 then Break;
    Inc(Cx, P(FLines[L].Para).Cells[K].W);
    Inc(K);
  end;
  { na kraju prelomljenog retka kursor ostaje ispred razmaka/ruba }
  Result := PosR(FLines[L].Para, K);
end;

procedure TaRichSurface.EnsureCaretVisible;
var
  L, Vh: Integer;
begin
  EnsureLayout;
  L := LineOf(FCaret);
  Vh := Height - 2 * PadY;
  if FLines[L].Y < FTop then FTop := FLines[L].Y
  else if FLines[L].Y + FLines[L].H > FTop + Vh then FTop := FLines[L].Y + FLines[L].H - Vh;
  if FTop < 0 then FTop := 0;
end;

{ ---------------- plosnati polozaj (za testove i ostecenje) ---------------- }

function TaRichSurface.FlatOf(const Q: TRPos): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to Q.Para - 1 do Inc(Result, ParaLen(I) + 1);
  Inc(Result, Q.Off);
end;

function TaRichSurface.PosOfFlat(N: Integer): TRPos;
var
  I: Integer;
begin
  if N < 0 then N := 0;
  for I := 0 to FParas.Count - 1 do
  begin
    if N <= ParaLen(I) then Exit(PosR(I, N));
    Dec(N, ParaLen(I) + 1);
  end;
  Result := PosR(FParas.Count - 1, ParaLen(FParas.Count - 1));
end;

{ ---------------- ponisti / ponovi ---------------- }

procedure TaRichSurface.Snapshot(ATo: TStringList);
begin
  ATo.Add(IntToStr(FlatOf(FCaret)) + #1 + IntToStr(FlatOf(FAnchor)) + #1 + GetHtml);
end;

procedure TaRichSurface.PushUndo;
begin
  Snapshot(FUndo);
  while FUndo.Count > 100 do FUndo.Delete(0);
  FRedo.Clear;
end;

procedure TaRichSurface.RestoreFrom(AFrom, ATo: TStringList);
var
  S, A, B, H: string;
  K: Integer;
begin
  if AFrom.Count = 0 then Exit;
  Snapshot(ATo);
  S := AFrom[AFrom.Count - 1];
  AFrom.Delete(AFrom.Count - 1);
  K := Pos(#1, S);
  A := Copy(S, 1, K - 1);
  Delete(S, 1, K);
  K := Pos(#1, S);
  B := Copy(S, 1, K - 1);
  H := Copy(S, K + 1, MaxInt);
  FLoading := True;
  try
    SetHtml(H);
  finally
    FLoading := False;
  end;
  { SetHtml brise povijest; vrati ono sto je trebalo ostati }
  FCaret := PosOfFlat(StrToIntDef(A, 0));
  FAnchor := PosOfFlat(StrToIntDef(B, 0));
  Changed;
  EnsureCaretVisible;
  Invalidate;
end;

procedure TaRichSurface.Undo;
var
  Rd: TStringList;
  Keep: TStringList;
begin
  if FUndo.Count = 0 then Exit;
  Keep := TStringList.Create;
  Rd := TStringList.Create;
  try
    Keep.Assign(FUndo);
    Rd.Assign(FRedo);
    RestoreFrom(Keep, Rd);
    FUndo.Assign(Keep);
    FRedo.Assign(Rd);
  finally
    Keep.Free;
    Rd.Free;
  end;
end;

procedure TaRichSurface.Redo;
var
  Un, Rd: TStringList;
begin
  if FRedo.Count = 0 then Exit;
  Un := TStringList.Create;
  Rd := TStringList.Create;
  try
    Un.Assign(FUndo);
    Rd.Assign(FRedo);
    RestoreFrom(Rd, Un);
    FUndo.Assign(Un);
    FRedo.Assign(Rd);
  finally
    Un.Free;
    Rd.Free;
  end;
end;

{ ---------------- uredjivanje ---------------- }

function TaRichSurface.RangeText(const A, B: TRPos): string;
var
  I, K, K0, K1: Integer;
begin
  Result := '';
  for I := A.Para to B.Para do
  begin
    if I > A.Para then Result := Result + LineEnding;
    if I = A.Para then K0 := A.Off else K0 := 0;
    if I = B.Para then K1 := B.Off else K1 := ParaLen(I);
    for K := K0 to K1 - 1 do Result := Result + P(I).Cells[K].Ch;
  end;
end;

function TaRichSurface.SelectedText: string;
begin
  if not HasSel then Exit('');
  Result := RangeText(SelA, SelB);
end;

procedure TaRichSurface.DeleteRange(A, B: TRPos);
var
  I, K, N, M: Integer;
  Pa, Pb: TRPara;
begin
  if Cmp(A, B) >= 0 then Exit;
  Pa := P(A.Para);
  if A.Para = B.Para then
  begin
    N := Length(Pa.Cells);
    for K := B.Off to N - 1 do Pa.Cells[K - (B.Off - A.Off)] := Pa.Cells[K];
    SetLength(Pa.Cells, N - (B.Off - A.Off));
  end
  else
  begin
    Pb := P(B.Para);
    SetLength(Pa.Cells, A.Off);
    M := Length(Pb.Cells) - B.Off;
    N := Length(Pa.Cells);
    SetLength(Pa.Cells, N + M);
    for K := 0 to M - 1 do Pa.Cells[N + K] := Pb.Cells[B.Off + K];
    for I := B.Para downto A.Para + 1 do
    begin
      P(I).Free;
      FParas.Delete(I);
    end;
  end;
  FCaret := A;
  FAnchor := A;
end;

procedure TaRichSurface.DeleteSel;
var
  A, B: TRPos;
begin
  if not HasSel then Exit;
  A := SelA;
  B := SelB;
  DeleteRange(A, B);
end;

procedure TaRichSurface.InsertCell(const ACh: string);
var
  Pa: TRPara;
  K, N: Integer;
begin
  Pa := P(FCaret.Para);
  N := Length(Pa.Cells);
  SetLength(Pa.Cells, N + 1);
  for K := N downto FCaret.Off + 1 do Pa.Cells[K] := Pa.Cells[K - 1];
  Pa.Cells[FCaret.Off].Ch := ACh;
  Pa.Cells[FCaret.Off].St := FTyping;
  Pa.Cells[FCaret.Off].W := 0;
  Inc(FCaret.Off);
  FAnchor := FCaret;
end;

procedure TaRichSurface.SplitPara;
var
  Pa, Pn: TRPara;
  K, M: Integer;
begin
  Pa := P(FCaret.Para);
  { Enter u praznoj natuknici zavrsava popis }
  if Pa.Bullet and (Length(Pa.Cells) = 0) then
  begin
    Pa.Bullet := False;
    Exit;
  end;
  Pn := TRPara.Create;
  Pn.Align := Pa.Align;
  Pn.Bullet := Pa.Bullet;
  M := Length(Pa.Cells) - FCaret.Off;
  SetLength(Pn.Cells, M);
  for K := 0 to M - 1 do Pn.Cells[K] := Pa.Cells[FCaret.Off + K];
  SetLength(Pa.Cells, FCaret.Off);
  FParas.Insert(FCaret.Para + 1, Pn);
  FCaret := PosR(FCaret.Para + 1, 0);
  FAnchor := FCaret;
end;

procedure TaRichSurface.InsertText(const AText: string);
var
  S, Ch: string;
  I, Len: Integer;
begin
  if FReadOnly then Exit;
  S := StringReplace(StringReplace(AText, #13#10, #10, [rfReplaceAll]), #13, #10, [rfReplaceAll]);
  if S = '' then Exit;
  PushUndo;
  DeleteSel;
  Len := UTF8Length(S);
  for I := 1 to Len do
  begin
    Ch := UTF8Copy(S, I, 1);
    if Ch = #10 then SplitPara
    else if Ch >= ' ' then InsertCell(Ch);
  end;
  FGoalX := -1;
  Changed;
  EnsureCaretVisible;
  FCaretOn := True;
  Invalidate;
end;

procedure TaRichSurface.SyncTyping;
begin
  if FCaret.Off > 0 then FTyping := P(FCaret.Para).Cells[FCaret.Off - 1].St
  else if ParaLen(FCaret.Para) > 0 then FTyping := P(FCaret.Para).Cells[0].St
  else if (FCaret.Para > 0) and (ParaLen(FCaret.Para) = 0) then { prazan odlomak zadrzava zadano }
    FTyping := NoStyle;
end;

procedure TaRichSurface.MoveTo(const Q: TRPos; AExtend: Boolean; AKeepGoal: Boolean);
begin
  FCaret := Q;
  if not AExtend then FAnchor := Q;
  if not AKeepGoal then FGoalX := -1;
  if not HasSel then SyncTyping;
  EnsureCaretVisible;
  FCaretOn := True;
  Invalidate;
  StateChanged;
end;

function TaRichSurface.PrevPos(const Q: TRPos): TRPos;
begin
  if Q.Off > 0 then Result := PosR(Q.Para, Q.Off - 1)
  else if Q.Para > 0 then Result := PosR(Q.Para - 1, ParaLen(Q.Para - 1))
  else Result := Q;
end;

function TaRichSurface.NextPos(const Q: TRPos): TRPos;
begin
  if Q.Off < ParaLen(Q.Para) then Result := PosR(Q.Para, Q.Off + 1)
  else if Q.Para < FParas.Count - 1 then Result := PosR(Q.Para + 1, 0)
  else Result := Q;
end;

function TaRichSurface.WordLeft(const Q: TRPos): TRPos;
var
  R: TRPos;
begin
  R := PrevPos(Q);
  while (Cmp(R, PosR(0, 0)) > 0) and (R.Off < ParaLen(R.Para)) and not IsWordCh(P(R.Para).Cells[R.Off].Ch) do R := PrevPos(R);
  while (R.Off > 0) and IsWordCh(P(R.Para).Cells[R.Off - 1].Ch) do Dec(R.Off);
  Result := R;
end;

function TaRichSurface.WordRight(const Q: TRPos): TRPos;
var
  R: TRPos;
begin
  R := Q;
  while (R.Off < ParaLen(R.Para)) and IsWordCh(P(R.Para).Cells[R.Off].Ch) do Inc(R.Off);
  while (R.Off < ParaLen(R.Para)) and not IsWordCh(P(R.Para).Cells[R.Off].Ch) do Inc(R.Off);
  if (R.Off = Q.Off) and (R.Para = Q.Para) then R := NextPos(Q);
  Result := R;
end;

procedure TaRichSurface.MoveVert(ADelta: Integer; AExtend: Boolean);
var
  L, N: Integer;
  Q: TRPos;
begin
  EnsureLayout;
  if FGoalX < 0 then FGoalX := XOf(FCaret);
  L := LineOf(FCaret) + ADelta;
  if L < 0 then begin MoveTo(PosR(0, 0), AExtend); Exit; end;
  if L > High(FLines) then begin MoveTo(PosR(FParas.Count - 1, ParaLen(FParas.Count - 1)), AExtend); Exit; end;
  Q := PosAt(FGoalX, FLines[L].Y - FTop + PadY + 1);
  N := Q.Off;
  { ne na pocetak sljedeceg retka istog odlomka }
  if (N >= FLines[L].C1) and (FLines[L].C1 < ParaLen(FLines[L].Para)) then N := FLines[L].C1 - 1;
  MoveTo(PosR(FLines[L].Para, Max(N, FLines[L].C0)), AExtend, True);
end;

{ ---------------- oblikovanje ---------------- }

function TaRichSurface.CurrentStyle: TRStyle;
begin
  if HasSel then
  begin
    if SelA.Off < ParaLen(SelA.Para) then Result := P(SelA.Para).Cells[SelA.Off].St else Result := FTyping;
  end
  else Result := FTyping;
end;

function TaRichSurface.CurrentAlign: TRtAlign;
begin
  Result := P(FCaret.Para).Align;
end;

function TaRichSurface.CurrentBullet: Boolean;
begin
  Result := P(FCaret.Para).Bullet;
end;

{ AWhat: 1 podebljano, 2 kurziv, 3 podcrtano; provjerava imaju li SVI znakovi u rasponu to svojstvo }
procedure TaRichSurface.AllCells(const A, B: TRPos; AWhat: Integer; var AAll: Boolean);
var
  I, K, K0, K1: Integer;
  St: TRStyle;
begin
  AAll := True;
  for I := A.Para to B.Para do
  begin
    if I = A.Para then K0 := A.Off else K0 := 0;
    if I = B.Para then K1 := B.Off else K1 := ParaLen(I);
    for K := K0 to K1 - 1 do
    begin
      St := P(I).Cells[K].St;
      case AWhat of
        1: if not St.Bold then AAll := False;
        2: if not St.Italic then AAll := False;
        3: if not St.Underline then AAll := False;
      end;
    end;
  end;
end;

{ AWhat: 1..3 kao gore, 4 boja, 5 velicina, 6 ocisti sve }
procedure TaRichSurface.SetAttr(const A, B: TRPos; AWhat: Integer; AOn: Boolean; AColor, APt: Integer);
var
  I, K, K0, K1: Integer;
begin
  for I := A.Para to B.Para do
  begin
    if I = A.Para then K0 := A.Off else K0 := 0;
    if I = B.Para then K1 := B.Off else K1 := ParaLen(I);
    for K := K0 to K1 - 1 do
      with P(I).Cells[K].St do
        case AWhat of
          1: Bold := AOn;
          2: Italic := AOn;
          3: Underline := AOn;
          4: Color := AColor;
          5: Pt := APt;
          6: begin Bold := False; Italic := False; Underline := False; Color := -1; Pt := 0; end;
        end;
  end;
end;

procedure TaRichSurface.Toggle(ACmd: TRichCmd);
var
  A, B: TRPos;
  All: Boolean;
  W, I: Integer;
begin
  if FReadOnly then Exit;
  case ACmd of
    rcBold, rcItalic, rcUnderline:
      begin
        W := Ord(ACmd) + 1;
        if HasSel then
        begin
          PushUndo;
          A := SelA;
          B := SelB;
          AllCells(A, B, W, All);
          SetAttr(A, B, W, not All, 0, 0);
          Changed;
        end
        else
          case W of
            1: FTyping.Bold := not FTyping.Bold;
            2: FTyping.Italic := not FTyping.Italic;
            3: FTyping.Underline := not FTyping.Underline;
          end;
      end;
    rcLeft, rcCenter, rcRight:
      begin
        PushUndo;
        A := SelA;
        B := SelB;
        for I := A.Para to B.Para do
          case ACmd of
            rcLeft: P(I).Align := raLeft;
            rcCenter: P(I).Align := raCenter;
            rcRight: P(I).Align := raRight;
          end;
        Changed;
      end;
    rcBullet:
      begin
        PushUndo;
        A := SelA;
        B := SelB;
        All := True;
        for I := A.Para to B.Para do if not P(I).Bullet then All := False;
        for I := A.Para to B.Para do P(I).Bullet := not All;
        Changed;
      end;
    rcClear:
      begin
        PushUndo;
        if HasSel then SetAttr(SelA, SelB, 6, False, 0, 0)
        else FTyping := NoStyle;
        A := SelA;
        B := SelB;
        for I := A.Para to B.Para do
        begin
          P(I).Align := raLeft;
          P(I).Bullet := False;
        end;
        Changed;
      end;
    rcColor: ;
  end;
  Invalidate;
  StateChanged;
end;

procedure TaRichSurface.SetTextColor(ARgb: Integer);
begin
  if FReadOnly then Exit;
  if HasSel then
  begin
    PushUndo;
    SetAttr(SelA, SelB, 4, False, ARgb, 0);
    Changed;
  end
  else FTyping.Color := ARgb;
  Invalidate;
  StateChanged;
end;

procedure TaRichSurface.SetSizePt(APt: Integer);
begin
  if FReadOnly then Exit;
  if (APt > 0) and (APt = DefaultPt) then APt := 0;
  if HasSel then
  begin
    PushUndo;
    SetAttr(SelA, SelB, 5, False, 0, APt);
    Changed;
  end
  else FTyping.Pt := APt;
  Invalidate;
  StateChanged;
end;

procedure TaRichSurface.SelectAll;
begin
  FAnchor := PosR(0, 0);
  FCaret := PosR(FParas.Count - 1, ParaLen(FParas.Count - 1));
  Invalidate;
  StateChanged;
end;

procedure TaRichSurface.SelectFlat(AStart, ALen: Integer);
begin
  FAnchor := PosOfFlat(AStart);
  FCaret := PosOfFlat(AStart + ALen);
  if not HasSel then SyncTyping;
  Invalidate;
  StateChanged;
end;

{ ---------------- spremnik ---------------- }

procedure TaRichSurface.CopyToClipboard;
begin
  if HasSel then Clipboard.AsText := SelectedText;
end;

procedure TaRichSurface.CutToClipboard;
begin
  if (not HasSel) or FReadOnly then Exit;
  CopyToClipboard;
  PushUndo;
  DeleteSel;
  Changed;
  EnsureCaretVisible;
  Invalidate;
end;

procedure TaRichSurface.PasteFromClipboard;
begin
  if (not FReadOnly) and Clipboard.HasFormat(CF_TEXT) then InsertText(Clipboard.AsText);
end;

{ ---------------- crtanje ---------------- }

procedure TaRichSurface.Paint;
var
  T: TaThemeTokens;
  Bg, Br, Tx, SelBg, SelTx: TColor;
  R, I, K, Y, X, ThH, ThY, Vh, Cx, A0, A1, Run0, Rows: Integer;
  Foc: Boolean;
  A, B: TRPos;
  Pa: TRPara;
  Ln: TRLine;
  S: string;
  Sel, IsS: Boolean;
  Lh: Integer;

  procedure FlushRun(AFrom, ATo: Integer; AX: Integer; AIsSel: Boolean);
  var
    J, Ww: Integer;
    Txt: string;
  begin
    if ATo <= AFrom then Exit;
    Txt := '';
    Ww := 0;
    for J := AFrom to ATo - 1 do
    begin
      Txt := Txt + Pa.Cells[J].Ch;
      Inc(Ww, Pa.Cells[J].W);
    end;
    if AIsSel then
    begin
      Canvas.Brush.Color := SelBg;
      Canvas.FillRect(AX, Y, AX + Ww, Y + Ln.H);
      SetFont(Pa.Cells[AFrom].St, SelTx);
      Canvas.Font.Color := SelTx;
    end
    else SetFont(Pa.Cells[AFrom].St, Tx);
    Canvas.Brush.Style := bsClear;
    Canvas.TextOut(AX, Y + Ln.H - PxOf(Pa.Cells[AFrom].St) * 12 div 10 + 1, Txt);
    Canvas.Brush.Style := bsSolid;
  end;

begin
  EnsureLayout;
  T := ActiveTokens;
  Foc := Focused;
  if Enabled and not FReadOnly then Bg := TokenColor(T.Surface) else Bg := TokenColor(T.Soft);
  if Foc then Br := TokenColor(T.Accent) else Br := TokenColor(T.Border);
  if Enabled then Tx := TokenColor(T.Text) else Tx := TokenColor(T.TextSoft);
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
  Canvas.ClipRect := Rect(PadX - 2, PadY - 1, Width - PadX - BarW + 2, Height - PadY + 1);
  Canvas.Clipping := True;
  Vh := Height - 2 * PadY;
  A := SelA;
  B := SelB;
  for I := 0 to High(FLines) do
  begin
    Ln := FLines[I];
    Y := PadY + Ln.Y - FTop;
    if (Y + Ln.H < 0) or (Y > Height) then Continue;
    Pa := P(Ln.Para);
    { natuknica }
    if Pa.Bullet and (Ln.C0 = 0) then
    begin
      SetFont(NoStyle, Tx);
      Canvas.Brush.Style := bsClear;
      Canvas.TextOut(PadX + 6, Y + Ln.H - FDefPx * 12 div 10 + 1, #$E2#$80#$A2);
      Canvas.Brush.Style := bsSolid;
    end;
    { crtanje po istim stilovima, s odvojenim oznacenim dijelom }
    X := Ln.X0;
    Run0 := Ln.C0;
    K := Ln.C0;
    Sel := False;
    while K <= Ln.C1 do
    begin
      A0 := 0;
      if K < Ln.C1 then
      begin
        { je li znak K oznacen }
        IsS := Foc and HasSel and (Cmp(PosR(Ln.Para, K), A) >= 0) and (Cmp(PosR(Ln.Para, K), B) < 0);
        if (K > Run0) and ((IsS <> Sel) or not SameStyle(Pa.Cells[K].St, Pa.Cells[Run0].St)) then
        begin
          FlushRun(Run0, K, X, Sel);
          for A0 := Run0 to K - 1 do Inc(X, Pa.Cells[A0].W);
          Run0 := K;
        end;
        Sel := IsS;
      end
      else FlushRun(Run0, K, X, Sel);
      Inc(K);
    end;
    { oznaceni kraj retka (novi redak u oznaci) }
    if Foc and HasSel and (Ln.C1 >= ParaLen(Ln.Para)) and (Cmp(PosR(Ln.Para, ParaLen(Ln.Para)), A) >= 0) and
       (Cmp(PosR(Ln.Para, ParaLen(Ln.Para)), B) < 0) then
    begin
      Cx := XOf(PosR(Ln.Para, ParaLen(Ln.Para)));
      Canvas.Brush.Color := SelBg;
      Canvas.FillRect(Cx, Y, Cx + 5, Y + Ln.H);
    end;
  end;
  { kursor }
  if Foc and FCaretOn and (not HasSel) and (not FReadOnly) then
  begin
    I := LineOf(FCaret);
    Ln := FLines[I];
    Y := PadY + Ln.Y - FTop;
    Cx := XOf(FCaret);
    Canvas.Pen.Color := Tx;
    Canvas.Line(Cx, Y + 1, Cx, Y + Ln.H - 1);
  end;
  Canvas.Clipping := False;
  { klizac }
  Rows := FContentH;
  if Rows > Vh then
  begin
    ThH := Max(18, Vh * Vh div Rows);
    ThY := PadY + (Vh - ThH) * FTop div Max(1, Rows - Vh);
    Canvas.Brush.Color := TokenColor(T.Border);
    Canvas.Pen.Style := psClear;
    Canvas.RoundRect(Width - BarW - 1, ThY, Width - 3, ThY + ThH, 4, 4);
    Canvas.Pen.Style := psSolid;
  end;
  Lh := 0;
  S := '';
end;

{ ---------------- tipkovnica ---------------- }

procedure TaRichSurface.KeyDown(var Key: Word; Shift: TShiftState);
var
  Ext, Ctl: Boolean;
  Q: TRPos;
  Vh: Integer;
begin
  inherited KeyDown(Key, Shift);
  if Key = 0 then Exit;
  Ext := ssShift in Shift;
  Ctl := ssCtrl in Shift;
  Vh := Height - 2 * PadY;
  case Key of
    VK_LEFT:
      begin
        if Ctl then Q := WordLeft(FCaret) else if HasSel and not Ext then Q := SelA else Q := PrevPos(FCaret);
        MoveTo(Q, Ext);
        Key := 0;
      end;
    VK_RIGHT:
      begin
        if Ctl then Q := WordRight(FCaret) else if HasSel and not Ext then Q := SelB else Q := NextPos(FCaret);
        MoveTo(Q, Ext);
        Key := 0;
      end;
    VK_UP: begin MoveVert(-1, Ext); Key := 0; end;
    VK_DOWN: begin MoveVert(1, Ext); Key := 0; end;
    VK_PRIOR: begin MoveVert(-Max(1, Vh div Max(1, FDefPx * 13 div 10)), Ext); Key := 0; end;
    VK_NEXT: begin MoveVert(Max(1, Vh div Max(1, FDefPx * 13 div 10)), Ext); Key := 0; end;
    VK_HOME:
      begin
        EnsureLayout;
        if Ctl then Q := PosR(0, 0) else Q := PosR(FCaret.Para, FLines[LineOf(FCaret)].C0);
        MoveTo(Q, Ext);
        Key := 0;
      end;
    VK_END:
      begin
        EnsureLayout;
        if Ctl then Q := PosR(FParas.Count - 1, ParaLen(FParas.Count - 1))
        else
        begin
          Q := PosR(FCaret.Para, FLines[LineOf(FCaret)].C1);
          { na prelomljenom retku kursor ostaje ispred prijeloma }
          if (Q.Off < ParaLen(Q.Para)) and (Q.Off > 0) and (P(Q.Para).Cells[Q.Off - 1].Ch = ' ') then Dec(Q.Off);
        end;
        MoveTo(Q, Ext);
        Key := 0;
      end;
    VK_BACK:
      begin
        if not FReadOnly then
        begin
          PushUndo;
          if HasSel then DeleteSel
          else if (FCaret.Off = 0) and P(FCaret.Para).Bullet then P(FCaret.Para).Bullet := False
          else if Cmp(FCaret, PosR(0, 0)) > 0 then DeleteRange(PrevPos(FCaret), FCaret);
          Changed;
          SyncTyping;
          EnsureCaretVisible;
          Invalidate;
        end;
        Key := 0;
      end;
    VK_DELETE:
      begin
        if not FReadOnly then
        begin
          if Shift = [ssShift] then CutToClipboard
          else
          begin
            PushUndo;
            if HasSel then DeleteSel else DeleteRange(FCaret, NextPos(FCaret));
            Changed;
            EnsureCaretVisible;
            Invalidate;
          end;
        end;
        Key := 0;
      end;
    VK_RETURN:
      begin
        InsertText(#10);
        Key := 0;
      end;
    VK_INSERT:
      begin
        if Ctl then CopyToClipboard else if Ext then PasteFromClipboard;
        Key := 0;
      end;
    VK_A: if Ctl then begin SelectAll; Key := 0; end;
    VK_C: if Ctl then begin CopyToClipboard; Key := 0; end;
    VK_X: if Ctl then begin CutToClipboard; Key := 0; end;
    VK_V: if Ctl then begin PasteFromClipboard; Key := 0; end;
    VK_Z: if Ctl then begin if Ext then Redo else Undo; Key := 0; end;
    VK_Y: if Ctl then begin Redo; Key := 0; end;
    VK_B: if Ctl then begin Toggle(rcBold); Key := 0; end;
    VK_I: if Ctl then begin Toggle(rcItalic); Key := 0; end;
    VK_U: if Ctl then begin Toggle(rcUnderline); Key := 0; end;
  end;
end;

procedure TaRichSurface.UTF8KeyPress(var UTF8Key: TUTF8Char);
begin
  inherited UTF8KeyPress(UTF8Key);
  if (UTF8Key = '') or (UTF8Key[1] < ' ') or (UTF8Key = #127) then Exit;
  InsertText(UTF8Key);
  UTF8Key := '';
end;

{ ---------------- mis ---------------- }

procedure TaRichSurface.ThumbTo(Y: Integer);
var
  Vh: Integer;
begin
  Vh := Height - 2 * PadY;
  if FContentH <= Vh then Exit;
  FTop := EnsureRange((Y - PadY) * (FContentH - Vh) div Max(1, Vh), 0, FContentH - Vh);
  Invalidate;
end;

procedure TaRichSurface.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if not Focused then SetFocus;
  if Button <> mbLeft then Exit;
  EnsureLayout;
  if (X >= Width - BarW - 2) and (FContentH > Height - 2 * PadY) then
  begin
    ThumbTo(Y);
    FDragging := False;
    Exit;
  end;
  MoveTo(PosAt(X, Y), ssShift in Shift);
  FDragging := True;
end;

procedure TaRichSurface.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  if FDragging and (ssLeft in Shift) then
  begin
    MoveTo(PosAt(X, Y), True);
    if Y < 0 then FTop := Max(0, FTop - 10) else if Y > Height then Inc(FTop, 10);
    EnsureLayout;
  end;
end;

procedure TaRichSurface.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  FDragging := False;
end;

procedure TaRichSurface.DblClick;
var
  M: TPoint;
  Q, A, B: TRPos;
begin
  inherited DblClick;
  M := ScreenToClient(Mouse.CursorPos);
  Q := PosAt(M.X, M.Y);
  A := Q;
  B := Q;
  while (A.Off > 0) and IsWordCh(P(A.Para).Cells[A.Off - 1].Ch) do Dec(A.Off);
  while (B.Off < ParaLen(B.Para)) and IsWordCh(P(B.Para).Cells[B.Off].Ch) do Inc(B.Off);
  FAnchor := A;
  FCaret := B;
  Invalidate;
  StateChanged;
end;

function TaRichSurface.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
var
  Vh: Integer;
begin
  EnsureLayout;
  Vh := Height - 2 * PadY;
  if FContentH > Vh then
  begin
    FTop := EnsureRange(FTop - WheelDelta div 120 * FDefPx * 13 div 10 * 3, 0, FContentH - Vh);
    Invalidate;
  end;
  Result := True;
end;

procedure TaRichSurface.DoEnter;
begin
  inherited DoEnter;
  FCaretOn := True;
  FTimer.Enabled := True;
  Invalidate;
end;

procedure TaRichSurface.DoExit;
begin
  FTimer.Enabled := False;
  FCaretOn := False;
  inherited DoExit;
  Invalidate;
end;

{ ================= traka ================= }

type
  TaSwatch = class(TCustomControl)
  private
    FOnPick: procedure(ARgb: Integer) of object;
    FHot: Integer;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

const
  SwCell = 22;
  SwCols = 8;
  BtnB = 1; BtnI = 2; BtnU = 3; BtnColor = 4; BtnLeft = 5; BtnCenter = 6; BtnRight = 7; BtnBullet = 8; BtnClear = 9;

type
  TBtnDef = record
    Id, X, W: Integer;
    Cap: string;
  end;

const
  Btns: array[0..8] of TBtnDef = (
    (Id: BtnB; X: 4; W: 28; Cap: 'B'),
    (Id: BtnI; X: 34; W: 28; Cap: 'I'),
    (Id: BtnU; X: 64; W: 28; Cap: 'U'),
    (Id: BtnColor; X: 98; W: 28; Cap: 'A'),
    (Id: BtnLeft; X: 196; W: 28; Cap: '◀'),
    (Id: BtnCenter; X: 226; W: 28; Cap: '≡'),
    (Id: BtnRight; X: 256; W: 28; Cap: '▶'),
    (Id: BtnBullet; X: 290; W: 28; Cap: '•'),
    (Id: BtnClear; X: 324; W: 28; Cap: '✕'));

constructor TaSwatch.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Width := SwCols * SwCell + 8;
  Height := 2 * SwCell + 8 + 24;
  FHot := -1;
  Visible := False;
end;

procedure TaSwatch.Paint;
var
  T: TaThemeTokens;
  I, X, Y: Integer;
begin
  T := ActiveTokens;
  Canvas.Brush.Color := TokenColor(T.Surface);
  Canvas.Pen.Color := TokenColor(T.Border);
  Canvas.Rectangle(0, 0, Width, Height);
  for I := 0 to 15 do
  begin
    X := 4 + (I mod SwCols) * SwCell;
    Y := 4 + (I div SwCols) * SwCell;
    Canvas.Brush.Color := RgbToColor(SwatchCols[I]);
    if I = FHot then Canvas.Pen.Color := TokenColor(T.Accent) else Canvas.Pen.Color := TokenColor(T.Border);
    Canvas.Rectangle(X + 2, Y + 2, X + SwCell - 2, Y + SwCell - 2);
  end;
  { zadana boja }
  Canvas.Brush.Color := TokenColor(T.Soft);
  Canvas.Pen.Color := TokenColor(T.Border);
  Canvas.Rectangle(4, 2 * SwCell + 8, Width - 4, Height - 4);
  Canvas.Font.Color := TokenColor(T.Text);
  Canvas.Brush.Style := bsClear;
  Canvas.TextOut(10, 2 * SwCell + 10, Tr('Automatic colour'));
  Canvas.Brush.Style := bsSolid;
end;

procedure TaSwatch.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  H: Integer;
begin
  inherited MouseMove(Shift, X, Y);
  H := -1;
  if (X >= 4) and (Y >= 4) and (Y < 4 + 2 * SwCell) and (X < 4 + SwCols * SwCell) then H := ((Y - 4) div SwCell) * SwCols + (X - 4) div SwCell;
  if H <> FHot then begin FHot := H; Invalidate; end;
end;

procedure TaSwatch.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  I: Integer;
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Y >= 2 * SwCell + 8 then I := -1
  else if (X >= 4) and (Y >= 4) and (X < 4 + SwCols * SwCell) then I := ((Y - 4) div SwCell) * SwCols + (X - 4) div SwCell
  else Exit;
  if Assigned(FOnPick) then
    if I < 0 then FOnPick(-1) else FOnPick(SwatchCols[I]);
end;

constructor TaRichBar.Create(AOwner: TComponent);
var
  I: Integer;
  C: TaOwnCombo;
begin
  inherited Create(AOwner);
  ApplyThemeFont(Font);
  ControlStyle := ControlStyle + [csOpaque];
  Height := 30;
  FHot := -1;
  C := TaOwnCombo.Create(Self);
  C.Parent := Self;
  C.SetBounds(130, 2, 60, 26);
  C.TabStop := False;
  for I := 0 to High(SizesList) do C.Items.Add(IntToStr(SizesList[I]));
  C.OnSelect := @SizePicked;
  FSizeBox := C;
end;

destructor TaRichBar.Destroy;
begin
  Application.RemoveOnUserInputHandler(@AppInput);
  inherited Destroy;
end;

procedure TaRichBar.Attach(ASurface: TaRichSurface);
begin
  FSurface := ASurface;
end;

procedure TaRichBar.Resize;
begin
  inherited Resize;
  Invalidate;
end;

function TaRichBar.ButtonAt(X: Integer): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(Btns) do
    if (X >= Btns[I].X) and (X < Btns[I].X + Btns[I].W) then Exit(Btns[I].Id);
end;

procedure TaRichBar.SyncFromSurface;
var
  Pt: Integer;
begin
  if FSurface = nil then Exit;
  Pt := FSurface.CurrentStyle.Pt;
  if Pt = 0 then Pt := FSurface.DefaultPt;
  FSyncing := True;
  try
    TaOwnCombo(FSizeBox).Text := IntToStr(Pt);
  finally
    FSyncing := False;
  end;
  Invalidate;
end;

procedure TaRichBar.SizePicked(Sender: TObject);
begin
  if FSyncing or (FSurface = nil) then Exit;
  FSurface.SetSizePt(StrToIntDef(TaOwnCombo(FSizeBox).Text, 0));
  FSurface.SetFocus;
end;

procedure TaRichBar.Paint;
var
  T: TaThemeTokens;
  I, Id: Integer;
  On: Boolean;
  St: TRStyle;
  Rc: TRect;
begin
  T := ActiveTokens;
  Canvas.Brush.Color := TokenColor(T.Soft);
  Canvas.Pen.Style := psClear;
  Canvas.FillRect(0, 0, Width, Height);
  Canvas.Pen.Style := psSolid;
  Canvas.Pen.Color := TokenColor(T.Border);
  Canvas.Line(0, Height - 1, Width, Height - 1);
  St := NoStyle;
  if FSurface <> nil then St := FSurface.CurrentStyle;
  for I := 0 to High(Btns) do
  begin
    Id := Btns[I].Id;
    On := False;
    if FSurface <> nil then
      case Id of
        BtnB: On := St.Bold;
        BtnI: On := St.Italic;
        BtnU: On := St.Underline;
        BtnLeft: On := FSurface.CurrentAlign = raLeft;
        BtnCenter: On := FSurface.CurrentAlign = raCenter;
        BtnRight: On := FSurface.CurrentAlign = raRight;
        BtnBullet: On := FSurface.CurrentBullet;
      end;
    Rc := Rect(Btns[I].X, 3, Btns[I].X + Btns[I].W, Height - 4);
    if On then Canvas.Brush.Color := TokenColor(T.Accent)
    else if FHot = Id then Canvas.Brush.Color := TokenColor(MixHex(T.Soft, T.Border, 0.5))
    else Canvas.Brush.Color := TokenColor(T.Surface);
    Canvas.Pen.Color := TokenColor(T.Border);
    Canvas.RoundRect(Rc.Left, Rc.Top, Rc.Right, Rc.Bottom, 6, 6);
    Canvas.Font.Name := Font.Name;
    Canvas.Font.Height := Font.Height;
    Canvas.Font.Style := [];
    case Id of
      BtnB: Canvas.Font.Style := [fsBold];
      BtnI: Canvas.Font.Style := [fsItalic];
      BtnU: Canvas.Font.Style := [fsUnderline];
    end;
    if On then Canvas.Font.Color := TokenColor(T.OnAccent) else Canvas.Font.Color := TokenColor(T.Text);
    if Id = BtnColor then
    begin
      if St.Color >= 0 then Canvas.Font.Color := RgbToColor(St.Color);
    end;
    Canvas.Brush.Style := bsClear;
    Canvas.TextOut(Rc.Left + (Btns[I].W - Canvas.TextWidth(Btns[I].Cap)) div 2, Rc.Top + (Rc.Bottom - Rc.Top - Canvas.TextHeight(Btns[I].Cap)) div 2, Btns[I].Cap);
    Canvas.Brush.Style := bsSolid;
  end;
end;

procedure TaRichBar.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  H: Integer;
begin
  inherited MouseMove(Shift, X, Y);
  H := ButtonAt(X);
  if H <> FHot then begin FHot := H; Invalidate; end;
end;

procedure TaRichBar.MouseLeave;
begin
  inherited MouseLeave;
  if FHot <> -1 then begin FHot := -1; Invalidate; end;
end;

procedure TaRichBar.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Id: Integer;
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (FSurface = nil) or (Button <> mbLeft) then Exit;
  Id := ButtonAt(X);
  case Id of
    BtnB: FSurface.Toggle(rcBold);
    BtnI: FSurface.Toggle(rcItalic);
    BtnU: FSurface.Toggle(rcUnderline);
    BtnColor: begin OpenSwatch; Exit; end;
    BtnLeft: FSurface.Toggle(rcLeft);
    BtnCenter: FSurface.Toggle(rcCenter);
    BtnRight: FSurface.Toggle(rcRight);
    BtnBullet: FSurface.Toggle(rcBullet);
    BtnClear: FSurface.Toggle(rcClear);
  else Exit;
  end;
  FSurface.SetFocus;
  SyncFromSurface;
end;

procedure TaRichBar.OpenSwatch;
var
  TopC: TControl;
  Sp: TPoint;
begin
  if FSwatch = nil then
  begin
    FSwatch := TaSwatch.Create(Self);
    TaSwatch(FSwatch).FOnPick := @SwatchPicked;
    TopC := Self;
    while TopC.Parent <> nil do TopC := TopC.Parent;
    FSwatch.Parent := TWinControl(TopC);
  end;
  if FSwatch.Visible then begin CloseSwatch; Exit; end;
  TopC := FSwatch.Parent;
  Sp := TopC.ScreenToClient(ClientToScreen(Point(Btns[3].X, Height)));
  FSwatch.SetBounds(Sp.X, Sp.Y, FSwatch.Width, FSwatch.Height);
  FSwatch.BringToFront;
  FSwatch.Visible := True;
  Application.AddOnUserInputHandler(@AppInput);
end;

procedure TaRichBar.CloseSwatch;
begin
  if FSwatch <> nil then FSwatch.Visible := False;
  Application.RemoveOnUserInputHandler(@AppInput);
end;

procedure TaRichBar.AppInput(Sender: TObject; var Msg: TLMessage);
var
  P: TPoint;
  Rs: TRect;
begin
  if (FSwatch = nil) or (not FSwatch.Visible) then Exit;
  if (Msg.Msg <> LM_LBUTTONDOWN) and (Msg.Msg <> LM_RBUTTONDOWN) then Exit;
  P := Mouse.CursorPos;
  Rs := Rect(FSwatch.ClientToScreen(Point(0, 0)).X, FSwatch.ClientToScreen(Point(0, 0)).Y,
    FSwatch.ClientToScreen(Point(FSwatch.Width, FSwatch.Height)).X, FSwatch.ClientToScreen(Point(FSwatch.Width, FSwatch.Height)).Y);
  if not Types.PtInRect(Rs, P) then CloseSwatch;
end;

procedure TaRichBar.SwatchPicked(ARgb: Integer);
begin
  CloseSwatch;
  if FSurface = nil then Exit;
  FSurface.SetTextColor(ARgb);
  FSurface.SetFocus;
  SyncFromSurface;
end;

{ ================= cijeli uredjivac ================= }

constructor TaOwnRichEdit.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  Caption := '';
  FBar := TaRichBar.Create(Self);
  FBar.Parent := Self;
  FBar.Align := alTop;
  FSurf := TaRichSurface.Create(Self);
  FSurf.Parent := Self;
  FSurf.Align := alClient;
  FSurf.OnChange := @SurfChanged;
  FSurf.OnState := @SurfState;
  FBar.Attach(FSurf);
  Height := 160;
  Width := 360;
end;

procedure TaOwnRichEdit.SurfChanged(Sender: TObject);
begin
  if Assigned(FOnChanged) then FOnChanged(Self);
end;

procedure TaOwnRichEdit.SurfState(Sender: TObject);
begin
  FBar.SyncFromSurface;
end;

function TaOwnRichEdit.GetHtml: string;
begin
  Result := FSurf.GetHtml;
end;

procedure TaOwnRichEdit.SetHtml(const AValue: string);
begin
  FSurf.SetHtml(AValue);
  FBar.SyncFromSurface;
end;

procedure TaOwnRichEdit.SetReadOnly(AValue: Boolean);
begin
  inherited SetReadOnly(AValue);
  FSurf.ReadOnly := AValue;
  FBar.Visible := not AValue;
end;

procedure TaOwnRichEdit.SelectRange(AStart, ALen: Integer);
begin
  FSurf.SelectFlat(AStart, ALen);
end;

procedure TaOwnRichEdit.ApplyBold; begin FSurf.Toggle(rcBold); end;
procedure TaOwnRichEdit.ApplyItalic; begin FSurf.Toggle(rcItalic); end;
procedure TaOwnRichEdit.ApplyUnderline; begin FSurf.Toggle(rcUnderline); end;
procedure TaOwnRichEdit.ApplyColorRgb(ARgb: Integer); begin FSurf.SetTextColor(ARgb); end;
procedure TaOwnRichEdit.ApplySizePt(APt: Integer); begin FSurf.SetSizePt(APt); end;

procedure TaOwnRichEdit.ApplyAlign(AAlign: TRtAlign);
begin
  case AAlign of
    raLeft: FSurf.Toggle(rcLeft);
    raCenter: FSurf.Toggle(rcCenter);
    raRight: FSurf.Toggle(rcRight);
  end;
end;

procedure TaOwnRichEdit.ApplyBullet; begin FSurf.Toggle(rcBullet); end;

function MakeOwn(AOwner: TComponent): TaRichBase;
begin
  Result := TaOwnRichEdit.Create(AOwner);
end;

initialization
  RichOwnFactory := @MakeOwn;

end.
