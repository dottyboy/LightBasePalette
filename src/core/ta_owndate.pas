unit ta_owndate;
{ Vlastito polje za datum (pruzatelj 'own'): tekst se tipka u zadanom obliku (dd.mm.yyyy), a gumb ili F4 otvara mjesecni kalendar
  koji se crta preko forme. Kalendar: strelice u zaglavlju mijenjaju mjesec i godinu, klik na dan bira, "Danas" bira danasnji datum.
  Tipke u otvorenom kalendaru: strelice dan/tjedan, PgUp/PgDn mjesec (uz Ctrl godina), Enter bira, Esc zatvara. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, LCLType, LazUTF8, Variants, ta_family, ta_edit, ta_ownedit, ta_ownpopup;

type
  TaDatePickEvent = procedure(ADate: TDateTime) of object;

  TaOwnCalendar = class(TCustomControl)
  private
    FSel: TDateTime;
    FViewY, FViewM: Word;
    FOnPick: TaDatePickEvent;
    FInline: Boolean;
    FRangeFrom, FRangeTo: TDateTime;
    procedure SetView(AY, AM: Integer);
    procedure SetInline(AValue: Boolean);
    function CW: Integer;
    function RH: Integer;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
    procedure DoEnter; override;
    procedure DoExit; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure SetDate(ADate: TDateTime);
    procedure MoveDays(ADays: Integer);
    procedure MoveMonths(AMonths: Integer);
    procedure SetRange(AFrom, ATo: TDateTime);
    property Selected: TDateTime read FSel;
    { samostalni kalendar na formi: prima fokus i tipke, a ne iskace }
    property Inline: Boolean read FInline write SetInline;
    property OnPick: TaDatePickEvent read FOnPick write FOnPick;
  end;

  TaOwnDateEdit = class(TaOwnPopupEdit)
  private
    FFormat: string;
    FCal: TaOwnCalendar;
    function Settings: TFormatSettings;
    procedure CalPicked(ADate: TDateTime);
  protected
    procedure PaintExtras(ARect: TRect); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure DoExit; override;
  public
    constructor Create(AOwner: TComponent); override;
    function TryParseDate(const AText: string; out ADate: TDateTime): Boolean;
    function TryGetDate(out ADate: TDateTime): Boolean;
    procedure SetDate(ADate: TDateTime);
    function FormatDate(ADate: TDateTime): string;
    procedure OpenPopup;
    property DateFormat: string read FFormat write FFormat;
    property Calendar: TaOwnCalendar read FCal;
  end;

  TaOwnDateEngine = class(TaEngine)
  private
    FDate: TaOwnDateEdit;
  public
    constructor Create(AHost: TaFamilyHost); override;
    class function Provider: string; override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
    function GetValue: Variant; override;
    procedure SetValue(const AValue: Variant); override;
    procedure SetReadOnly(AValue: Boolean); override;
    procedure ApplyOptions(AOptions: TPersistent); override;
  end;

implementation

uses
  Math, DateUtils, ta_tokens, ta_i18n;

const
  Cell = 34;
  HeadH = 34;
  WdH = 24;
  RowH = 28;
  FootH = 30;
  CalW = 7 * Cell + 2;
  CalH = HeadH + WdH + 6 * RowH + FootH + 2;

function MonthName(AMonth: Integer): string;
const
  Names: array[1..12] of string = ('January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September',
    'October', 'November', 'December');
begin
  Result := Tr(Names[AMonth]);
end;

function WeekdayName(ACol: Integer): string;
const
  Names: array[0..6] of string = ('Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun');
begin
  Result := Tr(Names[ACol]);
end;

{ ---------------- kalendar ---------------- }

constructor TaOwnCalendar.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ApplyThemeFont(Font);
  ControlStyle := ControlStyle + [csNoFocus, csOpaque];
  TabStop := False;
  Visible := False;
  Width := CalW;
  Height := CalH;
  SetDate(Date);
end;

function TaOwnCalendar.CW: Integer;
begin
  Result := Max(20, (Width - 2) div 7);
end;

function TaOwnCalendar.RH: Integer;
begin
  Result := Max(18, (Height - HeadH - WdH - FootH - 2) div 6);
end;

procedure TaOwnCalendar.SetInline(AValue: Boolean);
begin
  FInline := AValue;
  if AValue then
  begin
    ControlStyle := ControlStyle - [csNoFocus];
    TabStop := True;
    Visible := True;
  end
  else
  begin
    ControlStyle := ControlStyle + [csNoFocus];
    TabStop := False;
  end;
  Invalidate;
end;

procedure TaOwnCalendar.SetRange(AFrom, ATo: TDateTime);
begin
  FRangeFrom := Int(AFrom);
  FRangeTo := Int(ATo);
  Invalidate;
end;

procedure TaOwnCalendar.KeyDown(var Key: Word; Shift: TShiftState);
var
  Moved: Boolean;
begin
  inherited KeyDown(Key, Shift);
  if (not FInline) or (Key = 0) then Exit;
  Moved := True;
  case Key of
    VK_LEFT: MoveDays(-1);
    VK_RIGHT: MoveDays(1);
    VK_UP: MoveDays(-7);
    VK_DOWN: MoveDays(7);
    VK_PRIOR: if ssCtrl in Shift then MoveMonths(-12) else MoveMonths(-1);
    VK_NEXT: if ssCtrl in Shift then MoveMonths(12) else MoveMonths(1);
    VK_RETURN, VK_SPACE: ;
  else
    Moved := False;
  end;
  if Moved then
  begin
    Key := 0;
    if Assigned(FOnPick) then FOnPick(FSel);
  end;
end;

function TaOwnCalendar.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
begin
  Result := FInline;
  if FInline then
  begin
    if WheelDelta > 0 then SetView(FViewY, FViewM - 1) else SetView(FViewY, FViewM + 1);
  end;
end;

procedure TaOwnCalendar.DoEnter;
begin
  inherited DoEnter;
  Invalidate;
end;

procedure TaOwnCalendar.DoExit;
begin
  inherited DoExit;
  Invalidate;
end;

procedure TaOwnCalendar.SetView(AY, AM: Integer);
begin
  while AM < 1 do begin Dec(AY); Inc(AM, 12); end;
  while AM > 12 do begin Inc(AY); Dec(AM, 12); end;
  if AY < 1 then AY := 1;
  if AY > 9999 then AY := 9999;
  FViewY := AY;
  FViewM := AM;
  Invalidate;
end;

procedure TaOwnCalendar.SetDate(ADate: TDateTime);
var
  Y, M, D: Word;
begin
  FSel := Int(ADate);
  DecodeDate(FSel, Y, M, D);
  SetView(Y, M);
end;

procedure TaOwnCalendar.MoveDays(ADays: Integer);
begin
  SetDate(FSel + ADays);
end;

procedure TaOwnCalendar.MoveMonths(AMonths: Integer);
var
  Y, M, D: Word;
  Ny, Nm: Integer;
begin
  DecodeDate(FSel, Y, M, D);
  Nm := M - 1 + AMonths;
  Ny := Y + Nm div 12;
  Nm := Nm mod 12;
  if Nm < 0 then begin Inc(Nm, 12); Dec(Ny); end;
  Inc(Nm);
  if D > DaysInAMonth(Ny, Nm) then D := DaysInAMonth(Ny, Nm);
  SetDate(EncodeDate(Ny, Nm, D));
end;

procedure TaOwnCalendar.Paint;
var
  T: TaThemeTokens;
  I, Col, Row, X, Y, Offs, Days: Integer;
  First, D: TDateTime;
  Txt: string;
  R: Integer;
  Y0, M0, D0: Word;
begin
  T := ActiveTokens;
  Canvas.Font.Assign(Font);
  Canvas.Brush.Color := TokenColor(T.Surface);
  if FInline and Focused then Canvas.Pen.Color := TokenColor(T.Accent) else Canvas.Pen.Color := TokenColor(T.Border);
  R := Min(T.RadiusField, 6);
  if R > 0 then Canvas.RoundRect(0, 0, Width, Height, R * 2, R * 2) else Canvas.Rectangle(0, 0, Width, Height);
  Canvas.Brush.Style := bsClear;
  { zaglavlje: « ‹ mjesec godina › » }
  Canvas.Font.Style := [fsBold];
  Canvas.Font.Color := TokenColor(T.Text);
  Txt := MonthName(FViewM) + ' ' + IntToStr(FViewY);
  Canvas.TextOut((Width - Canvas.TextWidth(Txt)) div 2, (HeadH - Canvas.TextHeight(Txt)) div 2 + 1, Txt);
  Canvas.Font.Style := [];
  Canvas.Font.Color := TokenColor(T.TextSoft);
  Canvas.TextOut(8, (HeadH - Canvas.TextHeight('«')) div 2 + 1, '«');
  Canvas.TextOut(32, (HeadH - Canvas.TextHeight('‹')) div 2 + 1, '‹');
  Canvas.TextOut(Width - 32 - Canvas.TextWidth('›'), (HeadH - Canvas.TextHeight('›')) div 2 + 1, '›');
  Canvas.TextOut(Width - 8 - Canvas.TextWidth('»'), (HeadH - Canvas.TextHeight('»')) div 2 + 1, '»');
  { dani u tjednu }
  for I := 0 to 6 do
  begin
    Txt := WeekdayName(I);
    Canvas.TextOut(1 + I * CW + (CW - Canvas.TextWidth(Txt)) div 2, HeadH + (WdH - Canvas.TextHeight(Txt)) div 2, Txt);
  end;
  { dani: tjedan pocinje ponedjeljkom }
  First := EncodeDate(FViewY, FViewM, 1);
  Offs := (DayOfWeek(First) + 5) mod 7;
  Days := DaysInAMonth(FViewY, FViewM);
  DecodeDate(Date, Y0, M0, D0);
  for I := 0 to 41 do
  begin
    Col := I mod 7;
    Row := I div 7;
    D := First + (I - Offs);
    X := 1 + Col * CW;
    Y := HeadH + WdH + Row * RH;
    if (FRangeFrom <> 0) and (Int(D) >= FRangeFrom) and (Int(D) <= FRangeTo) then
    begin
      Canvas.Brush.Style := bsSolid;
      Canvas.Brush.Color := TokenColor(T.AccentSoft);
      Canvas.Pen.Style := psClear;
      Canvas.FillRect(X, Y + 1, X + CW, Y + RH - 1);
      Canvas.Pen.Style := psSolid;
      Canvas.Brush.Style := bsClear;
    end;
    if (Int(D) = FSel) or ((FRangeFrom <> 0) and ((Int(D) = FRangeFrom) or (Int(D) = FRangeTo))) then
    begin
      Canvas.Brush.Style := bsSolid;
      Canvas.Brush.Color := TokenColor(T.Accent);
      Canvas.Pen.Style := psClear;
      Canvas.RoundRect(X + 2, Y + 1, X + CW - 2, Y + RH - 1, 8, 8);
      Canvas.Pen.Style := psSolid;
      Canvas.Brush.Style := bsClear;
      Canvas.Font.Color := TokenColor(T.OnAccent);
    end
    else
    begin
      if (I < Offs) or (I >= Offs + Days) then Canvas.Font.Color := TokenColor(T.TextSoft)
      else Canvas.Font.Color := TokenColor(T.Text);
      if Int(D) = Int(Date) then
      begin
        Canvas.Brush.Style := bsClear;
        Canvas.Pen.Color := TokenColor(T.Accent);
        Canvas.RoundRect(X + 2, Y + 1, X + CW - 2, Y + RH - 1, 8, 8);
        Canvas.Pen.Color := TokenColor(T.Border);
      end;
    end;
    Txt := IntToStr(DayOf(D));
    Canvas.TextOut(X + (CW - Canvas.TextWidth(Txt)) div 2, Y + (RH - Canvas.TextHeight(Txt)) div 2, Txt);
  end;
  { podnozje }
  Canvas.Font.Color := TokenColor(T.Accent);
  Txt := Tr('Today');
  Canvas.TextOut((Width - Canvas.TextWidth(Txt)) div 2, HeadH + WdH + 6 * RH + (FootH - Canvas.TextHeight(Txt)) div 2, Txt);
end;

procedure TaOwnCalendar.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Col, Row, Offs, I: Integer;
  First: TDateTime;
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then Exit;
  if Y < HeadH then
  begin
    if X < 26 then SetView(FViewY - 1, FViewM)
    else if X < 52 then SetView(FViewY, FViewM - 1)
    else if X > Width - 26 then SetView(FViewY + 1, FViewM)
    else if X > Width - 52 then SetView(FViewY, FViewM + 1);
    Exit;
  end;
  if Y >= HeadH + WdH + 6 * RH then
  begin
    if Assigned(FOnPick) then FOnPick(Date);
    Exit;
  end;
  if Y < HeadH + WdH then Exit;
  Col := (X - 1) div CW;
  Row := (Y - HeadH - WdH) div RH;
  if (Col < 0) or (Col > 6) or (Row < 0) or (Row > 5) then Exit;
  First := EncodeDate(FViewY, FViewM, 1);
  Offs := (DayOfWeek(First) + 5) mod 7;
  I := Row * 7 + Col;
  FSel := Int(First + (I - Offs));
  if Assigned(FOnPick) then FOnPick(FSel);
end;

{ ---------------- polje datuma ---------------- }

constructor TaOwnDateEdit.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FRightPad := 28;
end;

function TaOwnDateEdit.Settings: TFormatSettings;
var
  F: string;
begin
  Result := DefaultFormatSettings;
  F := FFormat;
  if F = '' then F := 'dd.mm.yyyy';
  Result.ShortDateFormat := F;
  if Pos('.', F) > 0 then Result.DateSeparator := '.'
  else if Pos('/', F) > 0 then Result.DateSeparator := '/'
  else if Pos('-', F) > 0 then Result.DateSeparator := '-';
end;

function TaOwnDateEdit.FormatDate(ADate: TDateTime): string;
var
  F: string;
begin
  F := FFormat;
  if F = '' then F := 'dd.mm.yyyy';
  Result := FormatDateTime(F, ADate);
end;

function TaOwnDateEdit.TryGetDate(out ADate: TDateTime): Boolean;
begin
  Result := TryParseDate(FText, ADate);
end;

{ zadani oblik, pa ISO (iz baze), pa sustavni }
function TaOwnDateEdit.TryParseDate(const AText: string; out ADate: TDateTime): Boolean;
var
  S: string;
  F: TFormatSettings;
begin
  S := Trim(AText);
  Result := False;
  if S = '' then Exit;
  if TryStrToDate(S, ADate, Settings) then Exit(True);
  F := DefaultFormatSettings;
  F.ShortDateFormat := 'yyyy-mm-dd';
  F.DateSeparator := '-';
  if TryStrToDate(Copy(S, 1, 10), ADate, F) then Exit(True);
  Result := TryStrToDate(S, ADate, DefaultFormatSettings);
end;

procedure TaOwnDateEdit.SetDate(ADate: TDateTime);
begin
  Text := FormatDate(ADate);
end;

procedure TaOwnDateEdit.PaintExtras(ARect: TRect);
var
  T: TaThemeTokens;
  C: TColor;
  L, Tp: Integer;
begin
  T := ActiveTokens;
  if Enabled and not ReadOnly then C := TokenColor(T.Text) else C := TokenColor(T.TextSoft);
  Canvas.Pen.Color := C;
  Canvas.Pen.Width := 1;
  Canvas.Brush.Style := bsClear;
  L := ARect.Left + 6;
  Tp := Height div 2 - 7;
  Canvas.RoundRect(L, Tp, L + 15, Tp + 14, 3, 3);
  Canvas.MoveTo(L, Tp + 4);
  Canvas.LineTo(L + 15, Tp + 4);
  Canvas.MoveTo(L + 4, Tp - 2);
  Canvas.LineTo(L + 4, Tp + 2);
  Canvas.MoveTo(L + 11, Tp - 2);
  Canvas.LineTo(L + 11, Tp + 2);
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := C;
  Canvas.FillRect(L + 3, Tp + 7, L + 5, Tp + 9);
  Canvas.FillRect(L + 7, Tp + 7, L + 9, Tp + 9);
  Canvas.FillRect(L + 11, Tp + 7, L + 13, Tp + 9);
  Canvas.FillRect(L + 3, Tp + 10, L + 5, Tp + 12);
  Canvas.FillRect(L + 7, Tp + 10, L + 9, Tp + 12);
end;

procedure TaOwnDateEdit.OpenPopup;
var
  D: TDateTime;
begin
  if IsOpen or ReadOnly or (Parent = nil) then Exit;
  if not (TopLevel is TWinControl) then Exit;
  if FCal = nil then
  begin
    FCal := TaOwnCalendar.Create(Self);
    FCal.Parent := TWinControl(TopLevel);
    FCal.OnPick := @CalPicked;
    SetPopupControl(FCal);
  end;
  FCal.Font.Assign(Font);
  if TryGetDate(D) then FCal.SetDate(D) else FCal.SetDate(Date);
  ShowPopupAt(CalW, CalH);
end;

procedure TaOwnDateEdit.CalPicked(ADate: TDateTime);
begin
  ClosePopup;
  SetDate(ADate);
  if CanFocus and not Focused then SetFocus;
end;

procedure TaOwnDateEdit.KeyDown(var Key: Word; Shift: TShiftState);
var
  Big: Boolean;
begin
  if IsOpen then
  begin
    Big := ssCtrl in Shift;
    case Key of
      VK_LEFT: begin FCal.MoveDays(-1); Key := 0; Exit; end;
      VK_RIGHT: begin FCal.MoveDays(1); Key := 0; Exit; end;
      VK_UP: begin FCal.MoveDays(-7); Key := 0; Exit; end;
      VK_DOWN: begin FCal.MoveDays(7); Key := 0; Exit; end;
      VK_PRIOR: begin if Big then FCal.MoveMonths(-12) else FCal.MoveMonths(-1); Key := 0; Exit; end;
      VK_NEXT: begin if Big then FCal.MoveMonths(12) else FCal.MoveMonths(1); Key := 0; Exit; end;
      VK_RETURN: begin CalPicked(FCal.Selected); Key := 0; Exit; end;
      VK_ESCAPE, VK_F4: begin ClosePopup; Key := 0; Exit; end;
      VK_TAB: ClosePopup;
    end;
  end
  else if (not ReadOnly) and ((Key = VK_F4) or ((Key = VK_DOWN) and (ssAlt in Shift))) then
  begin
    OpenPopup;
    Key := 0;
    Exit;
  end;
  inherited KeyDown(Key, Shift);
end;

procedure TaOwnDateEdit.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if (Button = mbLeft) and PtInRightPad(X) and not ReadOnly then
  begin
    if CanFocus and not Focused then SetFocus;
    if IsOpen then ClosePopup else OpenPopup;
    Exit;
  end;
  inherited MouseDown(Button, Shift, X, Y);
end;

procedure TaOwnDateEdit.DoExit;
var
  D: TDateTime;
begin
  { pri izlasku datum se zapise u zadanom obliku }
  if TryGetDate(D) and (FormatDate(D) <> FText) then SetShownText(FormatDate(D));
  inherited DoExit;
end;

{ ---------------- pokretac ---------------- }

constructor TaOwnDateEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FDate := TaOwnDateEdit.Create(nil);
  FDate.OnChange := @InnerChanged;
  AttachInner(FDate);
end;

class function TaOwnDateEngine.Provider: string;
begin
  Result := 'own';
end;

function TaOwnDateEngine.GetText: string;
begin
  Result := FDate.Text;
end;

procedure TaOwnDateEngine.SetText(const AValue: string);
var
  D: TDateTime;
begin
  if Trim(AValue) = '' then begin if FDate.Text <> '' then FDate.Text := ''; end
  else if FDate.TryParseDate(AValue, D) then
  begin
    if FDate.FormatDate(D) <> FDate.Text then FDate.SetDate(D);
  end
  else if FDate.Text <> AValue then FDate.Text := AValue;
end;

function TaOwnDateEngine.GetValue: Variant;
var
  D: TDateTime;
begin
  if FDate.TryGetDate(D) then Result := D else Result := Null;
end;

procedure TaOwnDateEngine.SetValue(const AValue: Variant);
begin
  if VarIsNull(AValue) or VarIsEmpty(AValue) then FDate.Text := ''
  else FDate.SetDate(VarToDateTime(AValue));
end;

procedure TaOwnDateEngine.SetReadOnly(AValue: Boolean);
begin
  FDate.ReadOnly := AValue;
end;

procedure TaOwnDateEngine.ApplyOptions(AOptions: TPersistent);
begin
  if (AOptions is TaDateOptions) and (TaDateOptions(AOptions).DateFormat <> '') then
    FDate.DateFormat := TaDateOptions(AOptions).DateFormat;
end;

initialization
  RegisterEngine(EditFamily, 'date', TaOwnDateEngine);

end.
