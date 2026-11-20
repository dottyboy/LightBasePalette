unit ta_label;
{ Obitelj Label: text, hyperlink, html (podskup iz ta_richtext) i badge (znacka u boji). Sve varijante crta isti
  pokretac TaLabelPaint (boje iz tokena teme), a domacin TaLabel daje svojstva, vezu na polje (samo prikaz),
  definiciju kontrole <-> komponentu i .lfm. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, StdCtrls, Graphics, Variants, DB, DBCtrls, LCLType, ta_family, ta_formdef, ta_richtext;

type
  TaLabelVariant = (lvText, lvHyperlink, lvHtml, lvBadge);
  TaBadgeTone = (btNeutral, btAccent, btSuccess, btWarning, btDanger);

const
  LabelVariantNames: array[TaLabelVariant] of string = ('text', 'hyperlink', 'html', 'badge');
  BadgeToneNames: array[TaBadgeTone] of string = ('neutral', 'accent', 'success', 'warning', 'danger');
  LabelFamily = 'Label';

type
  TaLabelOptions = class(TPersistent)
  public
    procedure Assign(ASource: TPersistent); override;
  end;

  TaLabelOptionsClass = class of TaLabelOptions;

  { poveznica: adresa koja se otvara klikom (http..., mailto:..., datoteka) }
  TaHyperlinkOptions = class(TaLabelOptions)
  private
    FAddress: string;
  public
    procedure Assign(ASource: TPersistent); override;
  published
    property Address: string read FAddress write FAddress;
  end;

  TaBadgeOptions = class(TaLabelOptions)
  private
    FTone: TaBadgeTone;
  public
    procedure Assign(ASource: TPersistent); override;
  published
    property Tone: TaBadgeTone read FTone write FTone default btNeutral;
  end;

  TaLabelPaint = class(TCustomControl)
  private
    FMode: TaLabelVariant;
    FCaption: string;
    FAlignment: TAlignment;
    FTone: TaBadgeTone;
    FHot: Boolean;
    FDoc: TRtDoc;
    procedure SetMode(AValue: TaLabelVariant);
    procedure SetCaptionText(const AValue: string);
    procedure SetAlignment(AValue: TAlignment);
    procedure SetTone(AValue: TaBadgeTone);
  protected
    procedure Paint; override;
    procedure MouseEnter; override;
    procedure MouseLeave; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Click; override;
    { crta na zadano platno (crtanje i ispitivanje) }
    procedure RenderTo(C: TCanvas);
    property Mode: TaLabelVariant read FMode write SetMode;
    property CaptionText: string read FCaption write SetCaptionText;
    property Alignment: TAlignment read FAlignment write SetAlignment;
    property Tone: TaBadgeTone read FTone write SetTone;
  end;

  TaLabelEngine = class(TaEngine)
  private
    FPaint: TaLabelPaint;
    procedure PaintClick(Sender: TObject);
  protected
    function Mode: TaLabelVariant; virtual;
  public
    constructor Create(AHost: TaFamilyHost); override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
    procedure SetAlignment(AValue: TAlignment); override;
    procedure ApplyOptions(AOptions: TPersistent); override;
  end;

  TaLabelLinkEngine = class(TaLabelEngine)
  protected
    function Mode: TaLabelVariant; override;
  end;

  TaLabelHtmlEngine = class(TaLabelEngine)
  protected
    function Mode: TaLabelVariant; override;
  end;

  TaLabelBadgeEngine = class(TaLabelEngine)
  protected
    function Mode: TaLabelVariant; override;
  end;

  TaLabel = class(TaFamilyHost)
  private
    FVariant: TaLabelVariant;
    FOptions: array[TaLabelVariant] of TaLabelOptions;
    FText: string;
    FAlignment: TAlignment;
    FControlSource, FVisibleIf, FEnabledIf, FCondFormat, FExtra: string;
    FDataLink: TFieldDataLink;
    FUpdating: Boolean;
    FOpenOnClick: Boolean;
    function GetVariant: TaLabelVariant;
    procedure SetVariant(AValue: TaLabelVariant);
    function GetOptions: TaLabelOptions;
    procedure SetOptions(AValue: TaLabelOptions);
    function OptionsClassFor(AVariant: TaLabelVariant): TaLabelOptionsClass;
    function OptionsStored: Boolean;
    procedure SetAlignment(AValue: TAlignment);
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
    { za testove i skripte: isto sto korisnik napravi klikom }
    procedure PerformClick;
    { klik ili tipka na poveznici: otvara adresu pa javlja OnClick }
    procedure Activate;
    { false: poveznicu ne otvara sam domacin, nego dogadaj OnClick (izvrsitelj formi sam odlucuje sto je adresa) }
    property OpenOnClick: Boolean read FOpenOnClick write FOpenOnClick;
  published
    property Variant: TaLabelVariant read GetVariant write SetVariant default lvText;
    property Caption;
    property Options: TaLabelOptions read GetOptions write SetOptions stored OptionsStored;
    property Alignment: TAlignment read FAlignment write SetAlignment default taLeftJustify;
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
    property Font;
    property ParentFont;
    property Hint;
    property ShowHint;
    property PopupMenu;
    property OnClick;
  end;

  TOpenAddressProc = procedure(const AAddress: string);

var
  { zamjenjuje otvaranje adrese u pregledniku (ispitivanje, skriptiranje) }
  LabelOpenHook: TOpenAddressProc = nil;

function IsLabelKind(const AKind: string): Boolean;
function LabelVariantFromName(const AName: string; ADefault: TaLabelVariant = lvText): TaLabelVariant;
function LabelFromDef(D: TaControlDef; AOwner: TComponent): TaLabel;
procedure LabelToDef(L: TaLabel; D: TaControlDef);
function LabelToLfm(L: TaLabel): string;
function LabelFromLfm(const ALfm: string; AOwner: TComponent): TaLabel;

implementation

uses
  StrUtils, LResources, LCLIntf, ta_tokens;

function IsLabelKind(const AKind: string): Boolean;
begin
  Result := SameText(AKind, 'Label') or SameText(AKind, 'Hyperlink');
end;

function LabelVariantFromName(const AName: string; ADefault: TaLabelVariant): TaLabelVariant;
var
  V: TaLabelVariant;
begin
  for V := Low(TaLabelVariant) to High(TaLabelVariant) do
    if SameText(LabelVariantNames[V], AName) then Exit(V);
  Result := ADefault;
end;

function BadgeToneFromName(const AName: string): TaBadgeTone;
var
  T: TaBadgeTone;
begin
  for T := Low(TaBadgeTone) to High(TaBadgeTone) do
    if SameText(BadgeToneNames[T], AName) then Exit(T);
  Result := btNeutral;
end;

{ ---------------- opcije ---------------- }

procedure TaLabelOptions.Assign(ASource: TPersistent);
begin
  if not (ASource is TaLabelOptions) then inherited Assign(ASource);
end;

procedure TaHyperlinkOptions.Assign(ASource: TPersistent);
begin
  if ASource is TaHyperlinkOptions then FAddress := TaHyperlinkOptions(ASource).FAddress
  else inherited Assign(ASource);
end;

procedure TaBadgeOptions.Assign(ASource: TPersistent);
begin
  if ASource is TaBadgeOptions then FTone := TaBadgeOptions(ASource).FTone
  else inherited Assign(ASource);
end;

{ ---------------- crtanje ---------------- }

constructor TaLabelPaint.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BorderStyle := bsNone;      { Qt: bez okvira QAbstractScrollArea koji tema crta kao polje }
  ParentColor := True;
  Width := 100;
  Height := 22;
  ParentFont := True;
  ControlStyle := ControlStyle + [csClickEvents];
  FDoc := TRtDoc.Create;
end;

destructor TaLabelPaint.Destroy;
begin
  FDoc.Free;
  inherited Destroy;
end;

procedure TaLabelPaint.SetMode(AValue: TaLabelVariant);
begin
  FMode := AValue;
  TabStop := AValue = lvHyperlink;
  if AValue = lvHyperlink then Cursor := crHandPoint else Cursor := crDefault;
  SetCaptionText(FCaption);
end;

procedure TaLabelPaint.SetCaptionText(const AValue: string);
begin
  FCaption := AValue;
  if FMode = lvHtml then
  begin
    if RtLooksRich(AValue) then FDoc.LoadHtml(AValue) else FDoc.LoadHtml(RtFromPlain(AValue));
  end;
  Invalidate;
end;

procedure TaLabelPaint.SetAlignment(AValue: TAlignment);
begin
  FAlignment := AValue;
  Invalidate;
end;

procedure TaLabelPaint.SetTone(AValue: TaBadgeTone);
begin
  FTone := AValue;
  Invalidate;
end;

procedure TaLabelPaint.MouseEnter;
begin
  inherited MouseEnter;
  FHot := True;
  if FMode = lvHyperlink then Invalidate;
end;

procedure TaLabelPaint.MouseLeave;
begin
  inherited MouseLeave;
  FHot := False;
  if FMode = lvHyperlink then Invalidate;
end;

procedure TaLabelPaint.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  if (FMode = lvHyperlink) and ((Key = VK_RETURN) or (Key = VK_SPACE)) and (Shift = []) then
  begin
    Click;
    Key := 0;
  end;
end;

procedure TaLabelPaint.Click;
begin
  inherited Click;
end;

procedure TaLabelPaint.Paint;
begin
  RenderTo(Canvas);
end;

procedure TaLabelPaint.RenderTo(C: TCanvas);
var
  T: TaThemeTokens;
  Tw, Th, X, I, J, R, Tx: Integer;
  Fg, Bg: TColor;
  Lay: TRtLayout;
  Sg: TRtSeg;
  Fs: TFontStyles;
begin
  T := ActiveTokens;
  C.Brush.Color := Color;
  C.FillRect(0, 0, Width, Height);
  C.Font.Assign(Font);
  if (Font.Color = clDefault) or (Font.Color = clWindowText) or (Font.Color = clBlack) then
    Fg := TokenColor(T.Text)
  else
    Fg := Font.Color;
  if not Enabled then Fg := TokenColor(T.TextSoft);
  C.Brush.Style := bsClear;
  case FMode of
    lvHyperlink:
      begin
        C.Font.Color := TokenColor(T.Accent);
        if not Enabled then C.Font.Color := TokenColor(T.TextSoft);
        if FHot then C.Font.Style := C.Font.Style + [fsUnderline];
        C.Font.Style := C.Font.Style + [fsUnderline];
        Tw := C.TextWidth(FCaption);
        Th := C.TextHeight('Ag');
        case FAlignment of
          taRightJustify: X := Width - Tw - 2;
          taCenter: X := (Width - Tw) div 2;
        else
          X := 2;
        end;
        C.TextOut(X, (Height - Th) div 2, FCaption);
        if Focused then
        begin
          C.Pen.Color := TokenColor(T.Accent);
          C.Pen.Style := psDot;
          C.Rectangle(0, 0, Width, Height);
          C.Pen.Style := psSolid;
        end;
      end;
    lvBadge:
      begin
        case FTone of
          btAccent: begin Bg := TokenColor(T.AccentSoft); Fg := TokenColor(T.Accent); end;
          btSuccess: begin Bg := TokenColor(MixHex(T.Success, T.Surface, 0.82)); Fg := TokenColor(T.Success); end;
          btWarning: begin Bg := TokenColor(MixHex(T.Warning, T.Surface, 0.82)); Fg := TokenColor(T.Warning); end;
          btDanger: begin Bg := TokenColor(T.DangerSoft); Fg := TokenColor(T.Danger); end;
        else
          begin Bg := TokenColor(T.Soft); Fg := TokenColor(T.TextSoft); end;
        end;
        C.Font.Style := C.Font.Style + [fsBold];
        C.Font.Color := Fg;
        Tw := C.TextWidth(FCaption);
        Th := C.TextHeight('Ag');
        R := Th + 8;
        if R > Height then R := Height;
        case FAlignment of
          taRightJustify: X := Width - Tw - 16;
          taCenter: X := (Width - Tw - 14) div 2;
        else
          X := 1;
        end;
        if X < 0 then X := 0;
        C.Brush.Style := bsSolid;
        C.Brush.Color := Bg;
        C.Pen.Color := Bg;
        C.RoundRect(X, (Height - R) div 2, X + Tw + 14, (Height - R) div 2 + R, R, R);
        C.Brush.Style := bsClear;
        C.TextOut(X + 7, (Height - Th) div 2, FCaption);
      end;
    lvHtml:
      begin
        Lay := RtLayoutDoc(FDoc, Width, C.Font.Height * -1, Integer(Fg));
        for I := 0 to High(Lay.Lines) do
          for J := 0 to High(Lay.Lines[I].Segs) do
          begin
            Sg := Lay.Lines[I].Segs[J];
            Fs := [];
            if Sg.Bold then Include(Fs, fsBold);
            if Sg.Italic then Include(Fs, fsItalic);
            if Sg.Underline then Include(Fs, fsUnderline);
            C.Font.Style := Fs;
            if Sg.Color >= 0 then C.Font.Color := TColor(((Sg.Color and $FF) shl 16) or (Sg.Color and $FF00) or ((Sg.Color shr 16) and $FF))
            else C.Font.Color := Fg;
            Tx := Sg.X;
            C.TextOut(Tx, Lay.Lines[I].Y, Sg.Text);
          end;
      end;
  else
    begin
      C.Font.Color := Fg;
      Tw := C.TextWidth(FCaption);
      Th := C.TextHeight('Ag');
      case FAlignment of
        taRightJustify: X := Width - Tw - 1;
        taCenter: X := (Width - Tw) div 2;
      else
        X := 1;
      end;
      C.TextOut(X, (Height - Th) div 2, FCaption);
    end;
  end;
  C.Brush.Style := bsSolid;
end;

{ ---------------- pokretaci ---------------- }

constructor TaLabelEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FPaint := TaLabelPaint.Create(nil);
  FPaint.Mode := Mode;
  FPaint.OnClick := @PaintClick;
  AttachInner(FPaint);
end;

procedure TaLabelEngine.PaintClick(Sender: TObject);
begin
  if Host is TaLabel then TaLabel(Host).Activate;
end;

function TaLabelEngine.Mode: TaLabelVariant;
begin
  Result := lvText;
end;

function TaLabelLinkEngine.Mode: TaLabelVariant;
begin
  Result := lvHyperlink;
end;

function TaLabelHtmlEngine.Mode: TaLabelVariant;
begin
  Result := lvHtml;
end;

function TaLabelBadgeEngine.Mode: TaLabelVariant;
begin
  Result := lvBadge;
end;

function TaLabelEngine.GetText: string;
begin
  Result := FPaint.CaptionText;
end;

procedure TaLabelEngine.SetText(const AValue: string);
begin
  FPaint.CaptionText := AValue;
end;

procedure TaLabelEngine.SetAlignment(AValue: TAlignment);
begin
  FPaint.Alignment := AValue;
end;

procedure TaLabelEngine.ApplyOptions(AOptions: TPersistent);
begin
  if AOptions is TaBadgeOptions then FPaint.Tone := TaBadgeOptions(AOptions).Tone;
end;

{ ---------------- TaLabel ---------------- }

constructor TaLabel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FDataLink := TFieldDataLink.Create;
  FDataLink.Control := Self;
  FDataLink.OnDataChange := @DataChange;
  FVariant := lvText;
  FOpenOnClick := True;
  FAlignment := taLeftJustify;
  Width := 120;
  Height := 22;
  ReplaceEngine;
  PushToEngine;
end;

destructor TaLabel.Destroy;
var
  V: TaLabelVariant;
begin
  FDataLink.OnDataChange := nil;
  FDataLink.Free;
  for V := Low(TaLabelVariant) to High(TaLabelVariant) do FOptions[V].Free;
  inherited Destroy;
end;

function TaLabel.OptionsClassFor(AVariant: TaLabelVariant): TaLabelOptionsClass;
begin
  case AVariant of
    lvHyperlink: Result := TaHyperlinkOptions;
    lvBadge: Result := TaBadgeOptions;
  else
    Result := TaLabelOptions;
  end;
end;

function TaLabel.CreateEngine: TaEngine;
var
  C: TaEngineClass;
begin
  C := FindEngine(LabelFamily, LabelVariantNames[FVariant]);
  if C = nil then C := FindEngine(LabelFamily, 'text');
  Result := C.Create(Self);
end;

function TaLabel.VariantName: string;
begin
  Result := LabelVariantNames[FVariant];
end;

function TaLabel.GetVariant: TaLabelVariant;
begin
  Result := FVariant;
end;

procedure TaLabel.SetVariant(AValue: TaLabelVariant);
begin
  if AValue = FVariant then Exit;
  FText := RealGetText;
  FVariant := AValue;
  ReplaceEngine;
  PushToEngine;
end;

function TaLabel.GetOptions: TaLabelOptions;
begin
  if FOptions[FVariant] = nil then FOptions[FVariant] := OptionsClassFor(FVariant).Create;
  Result := FOptions[FVariant];
end;

procedure TaLabel.SetOptions(AValue: TaLabelOptions);
begin
  GetOptions.Assign(AValue);
  if Engine <> nil then Engine.ApplyOptions(GetOptions);
end;

function TaLabel.OptionsStored: Boolean;
begin
  Result := FVariant in [lvHyperlink, lvBadge];
end;

procedure TaLabel.PushToEngine;
begin
  if Engine = nil then Exit;
  FUpdating := True;
  try
    Engine.ApplyOptions(GetOptions);
    Engine.SetAlignment(FAlignment);
    Engine.SetText(FText);
  finally
    FUpdating := False;
  end;
end;

procedure TaLabel.SetAlignment(AValue: TAlignment);
begin
  FAlignment := AValue;
  if Engine <> nil then Engine.SetAlignment(AValue);
end;

function TaLabel.RealGetText: TCaption;
begin
  if Engine <> nil then Result := Engine.GetText else Result := FText;
end;

procedure TaLabel.RealSetText(const AValue: TCaption);
begin
  FText := AValue;
  if Engine <> nil then Engine.SetText(AValue);
end;

procedure TaLabel.Activate;
begin
  if (FVariant = lvHyperlink) and FOpenOnClick then
    if Options is TaHyperlinkOptions then
      if TaHyperlinkOptions(Options).Address <> '' then
      begin
        if Assigned(LabelOpenHook) then LabelOpenHook(TaHyperlinkOptions(Options).Address)
        else OpenURL(TaHyperlinkOptions(Options).Address);
      end;
  Click;
end;

procedure TaLabel.PerformClick;
begin
  Engine.Inner.Click;
end;

function TaLabel.GetDataSource: TDataSource;
begin
  Result := FDataLink.DataSource;
end;

procedure TaLabel.SetDataSource(AValue: TDataSource);
begin
  FDataLink.DataSource := AValue;
  if AValue <> nil then AValue.FreeNotification(Self);
end;

function TaLabel.GetDataField: string;
begin
  Result := FDataLink.FieldName;
end;

procedure TaLabel.SetDataField(const AValue: string);
begin
  FDataLink.FieldName := AValue;
end;

procedure TaLabel.Notification(AComponent: TComponent; AOperation: TOperation);
begin
  inherited Notification(AComponent, AOperation);
  if (AOperation = opRemove) and (FDataLink <> nil) and (AComponent = FDataLink.DataSource) then
    FDataLink.DataSource := nil;
end;

procedure TaLabel.Loaded;
begin
  inherited Loaded;
  PushToEngine;
end;

procedure TaLabel.DataChange(Sender: TObject);
var
  F: TField;
begin
  F := FDataLink.Field;
  if F = nil then
  begin
    if not (csDesigning in ComponentState) then Engine.SetText('');
  end
  else Engine.SetText(F.DisplayText);
end;

{ ---------------- definicija kontrole <-> komponenta ---------------- }

const
  OwnKeys = ',variant,tip,locked,visibleIf,enabledIf,condFormat,align,tone,';

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

function LabelFromDef(D: TaControlDef; AOwner: TComponent): TaLabel;
var
  V: TaLabelVariant;
begin
  Result := TaLabel.Create(AOwner);
  try
    Result.Name := D.Name;
    Result.SetBounds(D.Left, D.Top, D.Width, D.Height);
    V := LabelVariantFromName(D.GetX('variant'), lvText);
    if SameText(D.Kind, 'Hyperlink') and (D.GetX('variant') = '') then V := lvHyperlink;
    Result.Variant := V;
    Result.Caption := D.Caption;
    Result.ControlSource := D.ControlSource;
    if SameText(D.Align, 'right') then Result.Alignment := taRightJustify
    else if SameText(D.Align, 'center') then Result.Alignment := taCenter;
    Result.Hint := D.GetX('tip');
    Result.VisibleIf := D.GetX('visibleIf');
    Result.EnabledIf := D.GetX('enabledIf');
    Result.CondFormat := D.GetX('condFormat');
    if D.Bold then Result.Font.Style := [fsBold];
    case V of
      lvHyperlink:
        begin
          TaHyperlinkOptions(Result.Options).Address := D.RowSource;
          Result.Options := Result.Options;
        end;
      lvBadge:
        begin
          TaBadgeOptions(Result.Options).Tone := BadgeToneFromName(D.GetX('tone'));
          Result.Options := Result.Options;
        end;
    end;
    Result.Extra := ExtraWithout(D.Extra);
  except
    Result.Free;
    raise;
  end;
end;

procedure LabelToDef(L: TaLabel; D: TaControlDef);
begin
  if L.Variant = lvHyperlink then D.Kind := 'Hyperlink' else D.Kind := 'Label';
  D.Name := L.Name;
  D.Left := L.Left; D.Top := L.Top; D.Width := L.Width; D.Height := L.Height;
  D.Caption := L.Caption;
  D.ControlSource := L.ControlSource;
  D.Bold := fsBold in L.Font.Style;
  case L.Alignment of
    taRightJustify: D.Align := 'right';
    taCenter: D.Align := 'center';
  else
    D.Align := '';
  end;
  D.Extra := L.Extra;
  D.SetX('variant', IfThen(L.Variant in [lvText, lvHyperlink], '', L.VariantName));
  D.SetX('tip', L.Hint);
  D.SetX('visibleIf', L.VisibleIf);
  D.SetX('enabledIf', L.EnabledIf);
  D.SetX('condFormat', L.CondFormat);
  D.SetX('tone', '');
  case L.Variant of
    lvHyperlink: D.RowSource := TaHyperlinkOptions(L.Options).Address;
    lvBadge: D.SetX('tone', IfThen(TaBadgeOptions(L.Options).Tone = btNeutral, '', BadgeToneNames[TaBadgeOptions(L.Options).Tone]));
  end;
end;

function LabelToLfm(L: TaLabel): string;
var
  M: TMemoryStream;
  S: TStringList;
begin
  M := TMemoryStream.Create;
  S := TStringList.Create;
  try
    WriteComponentAsTextToStream(M, L);
    M.Position := 0;
    S.LoadFromStream(M);
    Result := S.Text;
  finally
    S.Free;
    M.Free;
  end;
end;

type
  TLabelLfmFinder = class
    procedure Find(Reader: TReader; const AClassName: string; var AClass: TComponentClass);
  end;

procedure TLabelLfmFinder.Find(Reader: TReader; const AClassName: string; var AClass: TComponentClass);
begin
  if SameText(AClassName, 'TaLabel') then AClass := TaLabel;
end;

function LabelFromLfm(const ALfm: string; AOwner: TComponent): TaLabel;
var
  M: TMemoryStream;
  C: TComponent;
  F: TLabelLfmFinder;
begin
  M := TMemoryStream.Create;
  try
    if ALfm <> '' then M.WriteBuffer(ALfm[1], Length(ALfm));
    M.Position := 0;
    C := nil;
    F := TLabelLfmFinder.Create;
    try
      ReadComponentFromTextStream(M, C, @F.Find, AOwner);
    finally
      F.Free;
    end;
    Result := C as TaLabel;
  finally
    M.Free;
  end;
end;

initialization
  RegisterClass(TaLabel);
  RegisterEngine(LabelFamily, 'text', TaLabelEngine);
  RegisterEngine(LabelFamily, 'hyperlink', TaLabelLinkEngine);
  RegisterEngine(LabelFamily, 'html', TaLabelHtmlEngine);
  RegisterEngine(LabelFamily, 'badge', TaLabelBadgeEngine);

end.
