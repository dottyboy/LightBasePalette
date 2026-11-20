unit ta_ownspin;
{ Vlastito polje s brojem i strelicama (pruzatelj 'own'): upisuju se samo znamenke, predznak i decimalni znak; strelice uz polje, tipke
  Gore/Dolje (PgUp/PgDn deset koraka) i kotacic mijenjaju vrijednost za korak, a drzanje tipke na strelici ponavlja. Granice i broj
  decimala kao kod TFloatSpinEdit; pri izlasku vrijednost se ogranici i zapise u punom obliku. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, ExtCtrls, LCLType, Variants, ta_family, ta_edit, ta_ownedit;

type
  TaOwnSpin = class(TaOwnEdit)
  private
    FMin, FMax, FStep: Double;
    FDecimals: Integer;
    FRepeat: TTimer;
    FRepeatDir: Integer;
    function GetValue: Double;
    procedure SetValue(AValue: Double);
    procedure SetDecimals(AValue: Integer);
    procedure Bump(ADir: Integer; AMult: Integer = 1);
    procedure RepeatTick(Sender: TObject);
    function Clamp(AValue: Double): Double;
    function Format(AValue: Double): string;
  protected
    procedure PaintExtras(ARect: TRect); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure UTF8KeyPress(var UTF8Key: TUTF8Char); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
    procedure DoExit; override;
  public
    constructor Create(AOwner: TComponent); override;
    function TryParse(const AText: string; out AValue: Double): Boolean;
    property Value: Double read GetValue write SetValue;
    property MinValue: Double read FMin write FMin;
    property MaxValue: Double read FMax write FMax;
    property Increment: Double read FStep write FStep;
    property DecimalPlaces: Integer read FDecimals write SetDecimals;
  end;

  TaOwnSpinEngine = class(TaEngine)
  private
    FSpin: TaOwnSpin;
  public
    constructor Create(AHost: TaFamilyHost); override;
    class function Provider: string; override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
    function GetValue: Variant; override;
    procedure SetValue(const AValue: Variant); override;
    procedure SetReadOnly(AValue: Boolean); override;
    procedure SetAlignment(AValue: TAlignment); override;
    procedure ApplyOptions(AOptions: TPersistent); override;
  end;

implementation

uses
  Math, ta_tokens;

constructor TaOwnSpin.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FRightPad := 22;
  FMin := -1e9;
  FMax := 1e9;
  FStep := 1;
  FRepeat := TTimer.Create(Self);
  FRepeat.Enabled := False;
  FRepeat.OnTimer := @RepeatTick;
  SetShownText(Format(0));
end;

function TaOwnSpin.Clamp(AValue: Double): Double;
begin
  Result := AValue;
  if Result < FMin then Result := FMin;
  if Result > FMax then Result := FMax;
end;

function TaOwnSpin.Format(AValue: Double): string;
begin
  if FDecimals <= 0 then Result := FormatFloat('0', AValue, DefaultFormatSettings)
  else Result := FormatFloat('0.' + StringOfChar('0', FDecimals), AValue, DefaultFormatSettings);
end;

function TaOwnSpin.TryParse(const AText: string; out AValue: Double): Boolean;
var
  S: string;
begin
  S := StringReplace(Trim(AText), ' ', '', [rfReplaceAll]);
  S := StringReplace(S, ',', DefaultFormatSettings.DecimalSeparator, [rfReplaceAll]);
  S := StringReplace(S, '.', DefaultFormatSettings.DecimalSeparator, [rfReplaceAll]);
  Result := (S <> '') and TryStrToFloat(S, AValue, DefaultFormatSettings);
end;

function TaOwnSpin.GetValue: Double;
begin
  if not TryParse(FText, Result) then Result := 0;
  Result := Clamp(Result);
end;

procedure TaOwnSpin.SetValue(AValue: Double);
begin
  Text := Format(Clamp(AValue));
end;

procedure TaOwnSpin.SetDecimals(AValue: Integer);
var
  V: Double;
begin
  if FDecimals = AValue then Exit;
  V := GetValue;
  FDecimals := AValue;
  SetShownText(Format(V));
end;

procedure TaOwnSpin.Bump(ADir: Integer; AMult: Integer);
var
  V: Double;
begin
  if ReadOnly then Exit;
  V := GetValue + ADir * FStep * AMult;
  SetValue(RoundTo(V, -Max(FDecimals, 6)));
end;

procedure TaOwnSpin.RepeatTick(Sender: TObject);
begin
  FRepeat.Interval := 70;
  Bump(FRepeatDir);
end;

procedure TaOwnSpin.PaintExtras(ARect: TRect);
var
  T: TaThemeTokens;
  Cx, Mid: Integer;
begin
  T := ActiveTokens;
  if Enabled and not ReadOnly then Canvas.Brush.Color := TokenColor(T.Text) else Canvas.Brush.Color := TokenColor(T.TextSoft);
  Canvas.Pen.Color := Canvas.Brush.Color;
  Cx := (ARect.Left + ARect.Right) div 2;
  Mid := Height div 2;
  Canvas.Polygon([Point(Cx - 4, Mid - 3), Point(Cx + 4, Mid - 3), Point(Cx, Mid - 8)]);
  Canvas.Polygon([Point(Cx - 4, Mid + 3), Point(Cx + 4, Mid + 3), Point(Cx, Mid + 8)]);
end;

procedure TaOwnSpin.UTF8KeyPress(var UTF8Key: TUTF8Char);
begin
  if (UTF8Key <> '') and (Length(UTF8Key) = 1) and (Ord(UTF8Key[1]) >= 32) then
  begin
    if UTF8Key[1] in ['0'..'9', '-', '+'] then
    else if (UTF8Key[1] = ',') or (UTF8Key[1] = '.') then
    begin
      if FDecimals <= 0 then begin UTF8Key := ''; Exit; end;
      UTF8Key := DefaultFormatSettings.DecimalSeparator;
    end
    else begin UTF8Key := ''; Exit; end;
  end;
  inherited UTF8KeyPress(UTF8Key);
end;

procedure TaOwnSpin.KeyDown(var Key: Word; Shift: TShiftState);
begin
  case Key of
    VK_UP: begin Bump(1); Key := 0; Exit; end;
    VK_DOWN: begin Bump(-1); Key := 0; Exit; end;
    VK_PRIOR: begin Bump(1, 10); Key := 0; Exit; end;
    VK_NEXT: begin Bump(-1, 10); Key := 0; Exit; end;
  end;
  inherited KeyDown(Key, Shift);
end;

procedure TaOwnSpin.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if (Button = mbLeft) and PtInRightPad(X) and not ReadOnly then
  begin
    if CanFocus and not Focused then SetFocus;
    if Y < Height div 2 then FRepeatDir := 1 else FRepeatDir := -1;
    Bump(FRepeatDir);
    FRepeat.Interval := 400;
    FRepeat.Enabled := True;
    Exit;
  end;
  inherited MouseDown(Button, Shift, X, Y);
end;

procedure TaOwnSpin.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  FRepeat.Enabled := False;
  inherited MouseUp(Button, Shift, X, Y);
end;

function TaOwnSpin.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
begin
  Result := Focused and not ReadOnly;
  if Result then
    if WheelDelta > 0 then Bump(1) else Bump(-1);
end;

procedure TaOwnSpin.DoExit;
var
  V: Double;
begin
  FRepeat.Enabled := False;
  if TryParse(FText, V) then SetShownText(Format(Clamp(V))) else SetShownText(Format(0));
  inherited DoExit;
end;

{ ---------------- pokretac ---------------- }

constructor TaOwnSpinEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FSpin := TaOwnSpin.Create(nil);
  FSpin.OnChange := @InnerChanged;
  AttachInner(FSpin);
end;

class function TaOwnSpinEngine.Provider: string;
begin
  Result := 'own';
end;

function TaOwnSpinEngine.GetText: string;
begin
  Result := FSpin.Text;
end;

procedure TaOwnSpinEngine.SetText(const AValue: string);
var
  D: Double;
begin
  if FSpin.TryParse(AValue, D) then FSpin.Value := D;
end;

function TaOwnSpinEngine.GetValue: Variant;
begin
  Result := FSpin.Value;
end;

procedure TaOwnSpinEngine.SetValue(const AValue: Variant);
begin
  if VarIsNull(AValue) or VarIsEmpty(AValue) then FSpin.Value := 0 else FSpin.Value := AValue;
end;

procedure TaOwnSpinEngine.SetReadOnly(AValue: Boolean);
begin
  FSpin.ReadOnly := AValue;
end;

procedure TaOwnSpinEngine.SetAlignment(AValue: TAlignment);
begin
  FSpin.Alignment := AValue;
end;

procedure TaOwnSpinEngine.ApplyOptions(AOptions: TPersistent);
var
  O: TaSpinOptions;
begin
  if not (AOptions is TaSpinOptions) then Exit;
  O := TaSpinOptions(AOptions);
  FSpin.DecimalPlaces := O.DecimalPlaces;
  if (O.MinValue = 0) and (O.MaxValue = 0) then
  begin
    FSpin.MinValue := -1e9;
    FSpin.MaxValue := 1e9;
  end
  else
  begin
    FSpin.MinValue := O.MinValue;
    FSpin.MaxValue := O.MaxValue;
  end;
  if O.Increment > 0 then FSpin.Increment := O.Increment;
end;

initialization
  RegisterEngine(EditFamily, 'spin', TaOwnSpinEngine);

end.
