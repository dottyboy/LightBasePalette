unit ta_progress;
{ Obitelj Progress: prikaz napretka ili stanja. Varijante: bar (TProgressBar), ring (prsten, vlastito crtanje),
  led (svjetlo koje mijenja boju po pragovima) i busy (traka bez odredenog kraja). Vrijednost je broj od Min do Max.
  Veza na polje je samo za prikaz. Isti nacin kao Edit: domacin TaProgress, pokretaci, Options, definicija, .lfm. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, ComCtrls, ExtCtrls, StdCtrls, Graphics, Variants, DB, DBCtrls, ta_family, ta_formdef;

type
  TaProgressVariant = (prBar, prRing, prLed, prBusy);

const
  ProgressVariantNames: array[TaProgressVariant] of string = ('bar', 'ring', 'led', 'busy');
  ProgressFamily = 'Progress';

type
  TaProgressOptions = class(TPersistent)
  private
    FMin, FMax: Double;
    FWarnAt, FDangerAt: Double;
    FShowText: Boolean;
  public
    constructor Create;
    procedure Assign(ASource: TPersistent); override;
  published
    property Min: Double read FMin write FMin;
    property Max: Double read FMax write FMax;
    { led: iznad ovog praga je upozorenje, iznad drugog opasnost (0 = bez praga) }
    property WarnAt: Double read FWarnAt write FWarnAt;
    property DangerAt: Double read FDangerAt write FDangerAt;
    property ShowText: Boolean read FShowText write FShowText default True;
  end;

  TaProgressPaint = class(TCustomControl)
  private
    FMode: TaProgressVariant;
    FValue: Double;
    FOpt: TaProgressOptions;
    FPhase: Integer;
    FTimer: TTimer;
    procedure SetValue(AValue: Double);
    procedure SetMode(AValue: TaProgressVariant);
    procedure TimerTick(Sender: TObject);
    function Fraction: Double;
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure RenderTo(C: TCanvas);
    procedure SetOptions(AOptions: TaProgressOptions);
    property Mode: TaProgressVariant read FMode write SetMode;
    property Value: Double read FValue write SetValue;
    { boja koju led trenutno pokazuje (ispitivanje) }
    function LedColor: TColor;
  end;

  TaProgressEngine = class(TaEngine)
  private
    FPaint: TaProgressPaint;
  protected
    function Mode: TaProgressVariant; virtual;
  public
    constructor Create(AHost: TaFamilyHost); override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
    function GetValue: Variant; override;
    procedure SetValue(const AValue: Variant); override;
    procedure ApplyOptions(AOptions: TPersistent); override;
    property Painter: TaProgressPaint read FPaint;
  end;

  TaProgressRingEngine = class(TaProgressEngine)
  protected
    function Mode: TaProgressVariant; override;
  end;

  TaProgressLedEngine = class(TaProgressEngine)
  protected
    function Mode: TaProgressVariant; override;
  end;

  TaProgressBusyEngine = class(TaProgressEngine)
  protected
    function Mode: TaProgressVariant; override;
  end;

  TaProgress = class(TaFamilyHost)
  private
    FVariant: TaProgressVariant;
    FOptions: TaProgressOptions;
    FValue: Double;
    FControlSource, FVisibleIf, FEnabledIf, FCondFormat, FExtra: string;
    FDataLink: TFieldDataLink;
    function GetVariant: TaProgressVariant;
    procedure SetVariant(AValue: TaProgressVariant);
    function GetOptions: TaProgressOptions;
    procedure SetOptions(AValue: TaProgressOptions);
    function GetValueProp: Double;
    procedure SetValueProp(AValue: Double);
    function GetDataSource: TDataSource;
    procedure SetDataSource(AValue: TDataSource);
    function GetDataField: string;
    procedure SetDataField(const AValue: string);
    procedure DataChange(Sender: TObject);
    procedure PushToEngine;
  protected
    function CreateEngine: TaEngine; override;
    function RealGetText: TCaption; override;
    procedure RealSetText(const AValue: TCaption); override;
    procedure Notification(AComponent: TComponent; AOperation: TOperation); override;
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function VariantName: string;
    function Painter: TaProgressPaint;
  published
    property Variant: TaProgressVariant read GetVariant write SetVariant default prBar;
    property Value: Double read GetValueProp write SetValueProp;
    property Options: TaProgressOptions read GetOptions write SetOptions;
    property ControlSource: string read FControlSource write FControlSource;
    property VisibleIf: string read FVisibleIf write FVisibleIf;
    property EnabledIf: string read FEnabledIf write FEnabledIf;
    property CondFormat: string read FCondFormat write FCondFormat;
    property Extra: string read FExtra write FExtra;
    property DataSource: TDataSource read GetDataSource write SetDataSource;
    property DataField: string read GetDataField write SetDataField;
    property Align;
    property Anchors;
    property Enabled;
    property Visible;
    property Hint;
    property ShowHint;
    property PopupMenu;
  end;

function IsProgressKind(const AKind: string): Boolean;
function ProgressVariantFromName(const AName: string; ADefault: TaProgressVariant = prBar): TaProgressVariant;
function ProgressFromDef(D: TaControlDef; AOwner: TComponent): TaProgress;
procedure ProgressToDef(P: TaProgress; D: TaControlDef);
function ProgressToLfm(P: TaProgress): string;
function ProgressFromLfm(const ALfm: string; AOwner: TComponent): TaProgress;

implementation

uses
  StrUtils, Math, LResources, ta_tokens;

function IsProgressKind(const AKind: string): Boolean;
begin
  Result := SameText(AKind, 'Progress');
end;

function ProgressVariantFromName(const AName: string; ADefault: TaProgressVariant): TaProgressVariant;
var
  V: TaProgressVariant;
begin
  for V := Low(TaProgressVariant) to High(TaProgressVariant) do
    if SameText(ProgressVariantNames[V], AName) then Exit(V);
  Result := ADefault;
end;

constructor TaProgressOptions.Create;
begin
  inherited Create;
  FMax := 100;
  FShowText := True;
end;

procedure TaProgressOptions.Assign(ASource: TPersistent);
begin
  if ASource is TaProgressOptions then
  begin
    FMin := TaProgressOptions(ASource).FMin;
    FMax := TaProgressOptions(ASource).FMax;
    FWarnAt := TaProgressOptions(ASource).FWarnAt;
    FDangerAt := TaProgressOptions(ASource).FDangerAt;
    FShowText := TaProgressOptions(ASource).FShowText;
  end
  else inherited Assign(ASource);
end;

{ ---------------- crtanje ---------------- }

constructor TaProgressPaint.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BorderStyle := bsNone;      { Qt: bez okvira QAbstractScrollArea koji tema crta kao polje }
  FOpt := TaProgressOptions.Create;
  Width := 160;
  Height := 22;
end;

destructor TaProgressPaint.Destroy;
begin
  FTimer.Free;
  FOpt.Free;
  inherited Destroy;
end;

procedure TaProgressPaint.SetOptions(AOptions: TaProgressOptions);
begin
  FOpt.Assign(AOptions);
  Invalidate;
end;

procedure TaProgressPaint.SetMode(AValue: TaProgressVariant);
begin
  FMode := AValue;
  if AValue = prBusy then
  begin
    if FTimer = nil then
    begin
      FTimer := TTimer.Create(nil);
      FTimer.Interval := 60;
      FTimer.OnTimer := @TimerTick;
    end;
    FTimer.Enabled := not (csDesigning in ComponentState);
  end
  else if FTimer <> nil then FTimer.Enabled := False;
  Invalidate;
end;

procedure TaProgressPaint.TimerTick(Sender: TObject);
begin
  Inc(FPhase, 6);
  Invalidate;
end;

procedure TaProgressPaint.SetValue(AValue: Double);
begin
  FValue := AValue;
  Invalidate;
end;

function TaProgressPaint.Fraction: Double;
begin
  if FOpt.Max <= FOpt.Min then Exit(0);
  Result := (FValue - FOpt.Min) / (FOpt.Max - FOpt.Min);
  if Result < 0 then Result := 0;
  if Result > 1 then Result := 1;
end;

function TaProgressPaint.LedColor: TColor;
var
  T: TaThemeTokens;
begin
  T := ActiveTokens;
  if (FOpt.DangerAt > 0) and (FValue >= FOpt.DangerAt) then Result := TokenColor(T.Danger)
  else if (FOpt.WarnAt > 0) and (FValue >= FOpt.WarnAt) then Result := TokenColor(T.Warning)
  else Result := TokenColor(T.Success);
end;

procedure TaProgressPaint.Paint;
begin
  RenderTo(Canvas);
end;

procedure TaProgressPaint.RenderTo(C: TCanvas);
var
  T: TaThemeTokens;
  F: Double;
  W, X, Rad, Cx, Cy, Th, Tw: Integer;
  S: string;
  Ang: Double;
begin
  T := ActiveTokens;
  C.Brush.Color := Color;
  C.FillRect(0, 0, Width, Height);
  F := Fraction;
  S := IntToStr(Round(F * 100)) + ' %';
  case FMode of
    prBar:
      begin
        C.Brush.Color := TokenColor(T.Soft);
        C.Pen.Color := TokenColor(T.Border);
        C.RoundRect(0, 0, Width, Height, Height, Height);
        W := Round((Width - 2) * F);
        if W > 0 then
        begin
          C.Brush.Color := TokenColor(T.Accent);
          C.Pen.Color := TokenColor(T.Accent);
          C.RoundRect(1, 1, 1 + Max(W, Height - 2), Height - 1, Height - 2, Height - 2);
        end;
        if FOpt.ShowText then
        begin
          C.Brush.Style := bsClear;
          C.Font.Color := TokenColor(T.Text);
          Tw := C.TextWidth(S);
          Th := C.TextHeight(S);
          C.TextOut((Width - Tw) div 2, (Height - Th) div 2, S);
        end;
      end;
    prRing:
      begin
        Rad := Min(Width, Height) div 2 - 2;
        Cx := Width div 2;
        Cy := Height div 2;
        C.Pen.Width := Max(3, Rad div 4);
        C.Pen.Color := TokenColor(T.Soft);
        C.Brush.Style := bsClear;
        C.Ellipse(Cx - Rad, Cy - Rad, Cx + Rad, Cy + Rad);
        if F > 0 then
        begin
          C.Pen.Color := TokenColor(T.Accent);
          if F >= 1 then C.Ellipse(Cx - Rad, Cy - Rad, Cx + Rad, Cy + Rad)
          else C.Arc(Cx - Rad, Cy - Rad, Cx + Rad, Cy + Rad, Cx, Cy - Rad,
                 Cx + Round(Rad * Sin(2 * Pi * F)), Cy - Round(Rad * Cos(2 * Pi * F)));
        end;
        C.Pen.Width := 1;
        if FOpt.ShowText then
        begin
          C.Font.Color := TokenColor(T.Text);
          Tw := C.TextWidth(S);
          Th := C.TextHeight(S);
          C.TextOut(Cx - Tw div 2, Cy - Th div 2, S);
        end;
      end;
    prLed:
      begin
        Rad := Min(Width, Height) div 2 - 2;
        Cx := Width div 2;
        Cy := Height div 2;
        C.Brush.Color := LedColor;
        C.Pen.Color := TokenColor(T.Border);
        C.Ellipse(Cx - Rad, Cy - Rad, Cx + Rad, Cy + Rad);
      end;
    prBusy:
      begin
        C.Brush.Color := TokenColor(T.Soft);
        C.Pen.Color := TokenColor(T.Border);
        C.RoundRect(0, 0, Width, Height, Height, Height);
        W := Width div 3;
        X := (FPhase mod (Width + W)) - W;
        C.Brush.Color := TokenColor(T.Accent);
        C.Pen.Color := TokenColor(T.Accent);
        C.RoundRect(Max(1, X), 1, Min(Width - 1, X + W), Height - 1, Height - 2, Height - 2);
      end;
  end;
  C.Brush.Style := bsSolid;
  if Ang = 0 then;
end;

{ ---------------- pokretaci ---------------- }

constructor TaProgressEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FPaint := TaProgressPaint.Create(nil);
  FPaint.Mode := Mode;
  AttachInner(FPaint);
end;

function TaProgressEngine.Mode: TaProgressVariant;
begin
  Result := prBar;
end;

function TaProgressRingEngine.Mode: TaProgressVariant;
begin
  Result := prRing;
end;

function TaProgressLedEngine.Mode: TaProgressVariant;
begin
  Result := prLed;
end;

function TaProgressBusyEngine.Mode: TaProgressVariant;
begin
  Result := prBusy;
end;

function TaProgressEngine.GetText: string;
begin
  Result := FloatToStr(FPaint.Value);
end;

procedure TaProgressEngine.SetText(const AValue: string);
begin
  FPaint.Value := StrToFloatDef(AValue, 0);
end;

function TaProgressEngine.GetValue: Variant;
begin
  Result := FPaint.Value;
end;

procedure TaProgressEngine.SetValue(const AValue: Variant);
begin
  if VarIsNull(AValue) or VarIsEmpty(AValue) then FPaint.Value := 0
  else if VarIsNumeric(AValue) then FPaint.Value := Double(AValue)
  else FPaint.Value := StrToFloatDef(VarToStr(AValue), 0);
end;

procedure TaProgressEngine.ApplyOptions(AOptions: TPersistent);
begin
  if AOptions is TaProgressOptions then FPaint.SetOptions(TaProgressOptions(AOptions));
end;

{ ---------------- TaProgress ---------------- }

constructor TaProgress.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FDataLink := TFieldDataLink.Create;
  FDataLink.Control := Self;
  FDataLink.OnDataChange := @DataChange;
  FOptions := TaProgressOptions.Create;
  FVariant := prBar;
  Width := 160;
  Height := 22;
  ReplaceEngine;
  PushToEngine;
end;

destructor TaProgress.Destroy;
begin
  FDataLink.OnDataChange := nil;
  FDataLink.Free;
  FOptions.Free;
  inherited Destroy;
end;

function TaProgress.CreateEngine: TaEngine;
var
  C: TaEngineClass;
begin
  C := FindEngine(ProgressFamily, ProgressVariantNames[FVariant]);
  if C = nil then C := FindEngine(ProgressFamily, 'bar');
  Result := C.Create(Self);
end;

function TaProgress.VariantName: string;
begin
  Result := ProgressVariantNames[FVariant];
end;

function TaProgress.Painter: TaProgressPaint;
begin
  if Engine is TaProgressEngine then Result := TaProgressEngine(Engine).Painter else Result := nil;
end;

function TaProgress.GetVariant: TaProgressVariant;
begin
  Result := FVariant;
end;

procedure TaProgress.SetVariant(AValue: TaProgressVariant);
begin
  if AValue = FVariant then Exit;
  FValue := GetValueProp;
  FVariant := AValue;
  ReplaceEngine;
  PushToEngine;
end;

function TaProgress.GetOptions: TaProgressOptions;
begin
  Result := FOptions;
end;

procedure TaProgress.SetOptions(AValue: TaProgressOptions);
begin
  FOptions.Assign(AValue);
  if Engine <> nil then Engine.ApplyOptions(FOptions);
end;

procedure TaProgress.PushToEngine;
begin
  if Engine = nil then Exit;
  Engine.ApplyOptions(FOptions);
  Engine.SetValue(FValue);
end;

function TaProgress.GetValueProp: Double;
begin
  if Engine <> nil then Result := Double(Engine.GetValue) else Result := FValue;
end;

procedure TaProgress.SetValueProp(AValue: Double);
begin
  FValue := AValue;
  if Engine <> nil then Engine.SetValue(AValue);
end;

function TaProgress.RealGetText: TCaption;
begin
  Result := FloatToStr(GetValueProp);
end;

procedure TaProgress.RealSetText(const AValue: TCaption);
begin
  SetValueProp(StrToFloatDef(AValue, 0));
end;

function TaProgress.GetDataSource: TDataSource;
begin
  Result := FDataLink.DataSource;
end;

procedure TaProgress.SetDataSource(AValue: TDataSource);
begin
  FDataLink.DataSource := AValue;
  if AValue <> nil then AValue.FreeNotification(Self);
end;

function TaProgress.GetDataField: string;
begin
  Result := FDataLink.FieldName;
end;

procedure TaProgress.SetDataField(const AValue: string);
begin
  FDataLink.FieldName := AValue;
end;

procedure TaProgress.Notification(AComponent: TComponent; AOperation: TOperation);
begin
  inherited Notification(AComponent, AOperation);
  if (AOperation = opRemove) and (FDataLink <> nil) and (AComponent = FDataLink.DataSource) then
    FDataLink.DataSource := nil;
end;

procedure TaProgress.Loaded;
begin
  inherited Loaded;
  PushToEngine;
end;

procedure TaProgress.DataChange(Sender: TObject);
var
  F: TField;
begin
  F := FDataLink.Field;
  if (F = nil) or F.IsNull then Engine.SetValue(0)
  else Engine.SetValue(F.AsFloat);
end;

{ ---------------- definicija kontrole <-> komponenta ---------------- }

const
  OwnKeys = ',variant,tip,visibleIf,enabledIf,condFormat,min,max,warnAt,dangerAt,showText,';

function ExtraWithout(const AExtra: string): string;
var
  L: TStringList;
  I: Integer;
  K: string;
begin
  L := TStringList.Create;
  try
    L.Text := AExtra;
    for I := L.Count - 1 downto 0 do
    begin
      K := L.Names[I];
      if (K <> '') and (Pos(',' + K + ',', OwnKeys) > 0) then L.Delete(I);
    end;
    Result := Trim(L.Text);
  finally
    L.Free;
  end;
end;

function ProgressFromDef(D: TaControlDef; AOwner: TComponent): TaProgress;
begin
  Result := TaProgress.Create(AOwner);
  try
    Result.Name := D.Name;
    Result.SetBounds(D.Left, D.Top, D.Width, D.Height);
    Result.Variant := ProgressVariantFromName(D.GetX('variant'), prBar);
    Result.ControlSource := D.ControlSource;
    Result.Hint := D.GetX('tip');
    Result.VisibleIf := D.GetX('visibleIf');
    Result.EnabledIf := D.GetX('enabledIf');
    Result.CondFormat := D.GetX('condFormat');
    Result.Options.Min := StrToFloatDef(D.GetX('min'), 0, DefaultFormatSettings);
    Result.Options.Max := StrToFloatDef(D.GetX('max'), 100, DefaultFormatSettings);
    Result.Options.WarnAt := StrToFloatDef(D.GetX('warnAt'), 0, DefaultFormatSettings);
    Result.Options.DangerAt := StrToFloatDef(D.GetX('dangerAt'), 0, DefaultFormatSettings);
    Result.Options.ShowText := D.GetX('showText') <> '0';
    Result.Options := Result.Options;
    Result.Extra := ExtraWithout(D.Extra);
  except
    Result.Free;
    raise;
  end;
end;

procedure ProgressToDef(P: TaProgress; D: TaControlDef);
begin
  D.Kind := 'Progress';
  D.Name := P.Name;
  D.Left := P.Left; D.Top := P.Top; D.Width := P.Width; D.Height := P.Height;
  D.ControlSource := P.ControlSource;
  D.Extra := P.Extra;
  D.SetX('variant', IfThen(P.Variant = prBar, '', P.VariantName));
  D.SetX('tip', P.Hint);
  D.SetX('visibleIf', P.VisibleIf);
  D.SetX('enabledIf', P.EnabledIf);
  D.SetX('condFormat', P.CondFormat);
  D.SetX('min', IfThen(P.Options.Min <> 0, FloatToStr(P.Options.Min, DefaultFormatSettings), ''));
  D.SetX('max', IfThen(P.Options.Max <> 100, FloatToStr(P.Options.Max, DefaultFormatSettings), ''));
  D.SetX('warnAt', IfThen(P.Options.WarnAt <> 0, FloatToStr(P.Options.WarnAt, DefaultFormatSettings), ''));
  D.SetX('dangerAt', IfThen(P.Options.DangerAt <> 0, FloatToStr(P.Options.DangerAt, DefaultFormatSettings), ''));
  D.SetX('showText', IfThen(P.Options.ShowText, '', '0'));
end;

function ProgressToLfm(P: TaProgress): string;
var
  M: TMemoryStream;
  L: TStringList;
begin
  M := TMemoryStream.Create;
  L := TStringList.Create;
  try
    WriteComponentAsTextToStream(M, P);
    M.Position := 0;
    L.LoadFromStream(M);
    Result := L.Text;
  finally
    L.Free;
    M.Free;
  end;
end;

type
  TProgressLfmFinder = class
    procedure Find(Reader: TReader; const AClassName: string; var AClass: TComponentClass);
  end;

procedure TProgressLfmFinder.Find(Reader: TReader; const AClassName: string; var AClass: TComponentClass);
begin
  if SameText(AClassName, 'TaProgress') then AClass := TaProgress;
end;

function ProgressFromLfm(const ALfm: string; AOwner: TComponent): TaProgress;
var
  M: TMemoryStream;
  C: TComponent;
  F: TProgressLfmFinder;
begin
  M := TMemoryStream.Create;
  try
    if ALfm <> '' then M.WriteBuffer(ALfm[1], Length(ALfm));
    M.Position := 0;
    C := nil;
    F := TProgressLfmFinder.Create;
    try
      ReadComponentFromTextStream(M, C, @F.Find, AOwner);
    finally
      F.Free;
    end;
    Result := C as TaProgress;
  finally
    M.Free;
  end;
end;

initialization
  RegisterClass(TaProgress);
  RegisterEngine(ProgressFamily, 'bar', TaProgressEngine);
  RegisterEngine(ProgressFamily, 'ring', TaProgressRingEngine);
  RegisterEngine(ProgressFamily, 'led', TaProgressLedEngine);
  RegisterEngine(ProgressFamily, 'busy', TaProgressBusyEngine);

end.
