unit ta_image;
{ Obitelj Image: slika, oblik, prijelaz boja i ikona/SVG. Jedan pokretac crta sve varijante (picture iz datoteke,
  shape: pravokutnik, zaobljeni, elipsa, crta; gradient: dvije boje; icon: ikona iz biblioteke ili SVG tekst).
  Boje su '#RRGGBB'; prazno uzima boju teme. Isti nacin kao Edit: domacin TaImage, Options, definicija, .lfm. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, Graphics, ExtCtrls, Variants, ta_family, ta_formdef;

type
  TaImageVariant = (imPicture, imShape, imGradient, imIcon);
  TaImageShape = (ishRectangle, ishRounded, ishEllipse, ishLine);
  TaImageSizeMode = (ismFit, ismStretch, ismCenter);

const
  ImageVariantNames: array[TaImageVariant] of string = ('picture', 'shape', 'gradient', 'icon');
  ImageShapeNames: array[TaImageShape] of string = ('rectangle', 'rounded', 'ellipse', 'line');
  ImageFamily = 'Image';

type
  TaImageOptions = class(TPersistent)
  private
    FFileName, FFillColor, FLineColor, FColorTo, FIcon, FSvg: string;
    FSizeMode: TaImageSizeMode;
    FShape: TaImageShape;
    FVertical: Boolean;
    FLineWidth: Integer;
  public
    constructor Create;
    procedure Assign(ASource: TPersistent); override;
  published
    { picture: datoteka slike }
    property FileName: string read FFileName write FFileName;
    property SizeMode: TaImageSizeMode read FSizeMode write FSizeMode default ismFit;
    { shape }
    property Shape: TaImageShape read FShape write FShape default ishRectangle;
    { shape: ispuna; gradient: pocetna boja }
    property FillColor: string read FFillColor write FFillColor;
    property LineColor: string read FLineColor write FLineColor;
    property LineWidth: Integer read FLineWidth write FLineWidth default 1;
    { gradient: zavrsna boja }
    property ColorTo: string read FColorTo write FColorTo;
    property Vertical: Boolean read FVertical write FVertical default True;
    { icon: naziv iz biblioteke ikona, ili SVG tekst u Svg }
    property Icon: string read FIcon write FIcon;
    property Svg: string read FSvg write FSvg;
  end;

  TaImagePaint = class(TCustomControl)
  private
    FMode: TaImageVariant;
    FOpt: TaImageOptions;
    FPic: TPicture;
    FPicKey: string;
    FExtPic: Boolean;
    procedure LoadPicture;
    function Backdrop: TColor;
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure RenderTo(C: TCanvas);
    procedure SetOptions(AOptions: TaImageOptions);
    { je li slika/ikona uspjesno ucitana }
    function HasPicture: Boolean;
    { slika koju postavlja izvrsitelj (iz polja zapisa); nil je brise }
    procedure SetPicture(APic: TPicture);
    property Mode: TaImageVariant read FMode write FMode;
  end;

  TaImageEngine = class(TaEngine)
  private
    FPaint: TaImagePaint;
  protected
    function Mode: TaImageVariant; virtual;
  public
    constructor Create(AHost: TaFamilyHost); override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
    procedure ApplyOptions(AOptions: TPersistent); override;
    property Painter: TaImagePaint read FPaint;
  end;

  TaImageShapeEngine = class(TaImageEngine)
  protected
    function Mode: TaImageVariant; override;
  end;

  TaImageGradientEngine = class(TaImageEngine)
  protected
    function Mode: TaImageVariant; override;
  end;

  TaImageIconEngine = class(TaImageEngine)
  protected
    function Mode: TaImageVariant; override;
  end;

  TaImage = class(TaFamilyHost)
  private
    FVariant: TaImageVariant;
    FOptions: TaImageOptions;
    FVisibleIf, FEnabledIf, FExtra: string;
    function GetVariant: TaImageVariant;
    procedure SetVariant(AValue: TaImageVariant);
    function GetOptions: TaImageOptions;
    procedure SetOptions(AValue: TaImageOptions);
    procedure PushToEngine;
  protected
    function CreateEngine: TaEngine; override;
    function RealGetText: TCaption; override;
    procedure RealSetText(const AValue: TCaption); override;
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function VariantName: string;
    function Painter: TaImagePaint;
    procedure SetPicture(APic: TPicture);
  published
    property Variant: TaImageVariant read GetVariant write SetVariant default imPicture;
    property Options: TaImageOptions read GetOptions write SetOptions;
    property VisibleIf: string read FVisibleIf write FVisibleIf;
    property EnabledIf: string read FEnabledIf write FEnabledIf;
    property Extra: string read FExtra write FExtra;
    property Align;
    property Anchors;
    property Enabled;
    property Visible;
    property Hint;
    property ShowHint;
    property PopupMenu;
    property OnClick;
  end;

function IsImageKind(const AKind: string): Boolean;
function ImageVariantFromName(const AName: string; ADefault: TaImageVariant = imPicture): TaImageVariant;
function ImageFromDef(D: TaControlDef; AOwner: TComponent): TaImage;
procedure ImageToDef(I: TaImage; D: TaControlDef);
function ImageToLfm(I: TaImage): string;
function ImageFromLfm(const ALfm: string; AOwner: TComponent): TaImage;

implementation

uses
  StrUtils, LResources, Math, GraphType, IntfGraphics, ta_tokens, ta_svg, ta_icons;

function IsImageKind(const AKind: string): Boolean;
begin
  Result := SameText(AKind, 'Image') or SameText(AKind, 'Rectangle') or SameText(AKind, 'Line');
end;

function ImageVariantFromName(const AName: string; ADefault: TaImageVariant): TaImageVariant;
var
  V: TaImageVariant;
begin
  for V := Low(TaImageVariant) to High(TaImageVariant) do
    if SameText(ImageVariantNames[V], AName) then Exit(V);
  Result := ADefault;
end;

function ShapeFromName(const AName: string): TaImageShape;
var
  S: TaImageShape;
begin
  for S := Low(TaImageShape) to High(TaImageShape) do
    if SameText(ImageShapeNames[S], AName) then Exit(S);
  Result := ishRectangle;
end;

function ColorOr(const AHex: string; ADefault: TColor): TColor;
begin
  if IsHexColor(AHex) then Result := TokenColor(AHex) else Result := ADefault;
end;

constructor TaImageOptions.Create;
begin
  inherited Create;
  FVertical := True;
  FLineWidth := 1;
end;

procedure TaImageOptions.Assign(ASource: TPersistent);
var
  O: TaImageOptions;
begin
  if ASource is TaImageOptions then
  begin
    O := TaImageOptions(ASource);
    FFileName := O.FFileName; FFillColor := O.FFillColor; FLineColor := O.FLineColor; FColorTo := O.FColorTo;
    FIcon := O.FIcon; FSvg := O.FSvg; FSizeMode := O.FSizeMode; FShape := O.FShape; FVertical := O.FVertical;
    FLineWidth := O.FLineWidth;
  end
  else inherited Assign(ASource);
end;

{ ---------------- crtanje ---------------- }

constructor TaImagePaint.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BorderStyle := bsNone;      { Qt: bez okvira QAbstractScrollArea koji tema crta kao polje }
  FOpt := TaImageOptions.Create;
  FPic := TPicture.Create;
  Width := 80;
  Height := 60;
end;

destructor TaImagePaint.Destroy;
begin
  FPic.Free;
  FOpt.Free;
  inherited Destroy;
end;

procedure TaImagePaint.SetOptions(AOptions: TaImageOptions);
begin
  FOpt.Assign(AOptions);
  FPicKey := '';
  Invalidate;
end;

function TaImagePaint.HasPicture: Boolean;
begin
  LoadPicture;
  Result := (FPic.Graphic <> nil) and not FPic.Graphic.Empty;
end;

procedure TaImagePaint.SetPicture(APic: TPicture);
begin
  FPic.Clear;
  if (APic <> nil) and (APic.Graphic <> nil) and not APic.Graphic.Empty then
  begin
    FPic.Assign(APic);
    FExtPic := True;
    FPicKey := 'ext';
  end
  else
  begin
    FPicKey := 'ext';       { prazno ostaje prazno, ne vraca se staticka slika }
    FExtPic := True;
  end;
  Invalidate;
end;

procedure TaImagePaint.LoadPicture;
var
  Key, Bytes: string;
  Ms: TStringStream;
  Png: TPortableNetworkGraphic;
begin
  if FExtPic then Exit;
  case FMode of
    imPicture: Key := 'f:' + FOpt.FileName;
    imIcon: Key := 'i:' + FOpt.Icon + '|' + FOpt.Svg + '|' + IntToStr(Width);
  else
    Exit;
  end;
  if Key = FPicKey then Exit;
  FPicKey := Key;
  FPic.Clear;
  try
    if FMode = imPicture then
    begin
      if (FOpt.FileName <> '') and FileExists(FOpt.FileName) then FPic.LoadFromFile(FOpt.FileName);
    end
    else if Trim(FOpt.Svg) <> '' then
    begin
      Bytes := SvgTextToPng(FOpt.Svg, Max(16, Width));
      if Bytes <> '' then
      begin
        Ms := TStringStream.Create(Bytes);
        try
          Png := TPortableNetworkGraphic.Create;
          try
            Png.LoadFromStream(Ms);
            FPic.Bitmap.Assign(Png);
          finally
            Png.Free;
          end;
        finally
          Ms.Free;
        end;
      end;
    end
    else if FOpt.Icon <> '' then
    begin
      { velicina ikone: trazena, pa najbliza manja koju biblioteka ima }
      Png := IconPng(FOpt.Icon, Max(16, Min(Width, Height)));
      if Png = nil then Png := IconPng(FOpt.Icon, 24);
      if Png = nil then Png := IconPng(FOpt.Icon, 16);
      if Png <> nil then FPic.Bitmap.Assign(Png);
    end;
  except
    FPic.Clear;
  end;
end;

procedure TaImagePaint.Paint;
begin
  RenderTo(Canvas);
end;

{ boja pozadine za oblik bez ispune: prvi predak s vlastitom bojom }
function TaImagePaint.Backdrop: TColor;
var
  P: TWinControl;
begin
  P := Parent;
  while P <> nil do
  begin
    if P.Color <> clDefault then Exit(ColorToRGB(P.Color));
    P := P.Parent;
  end;
  Result := ColorToRGB(clBtnFace);
end;

procedure TaImagePaint.RenderTo(C: TCanvas);
var
  T: TaThemeTokens;
  Fill, Line, Fill2: TColor;
  R, I, N, W, H: Integer;
  Dst: TRect;
  Sc: Double;
  R1, G1, B1, R2, G2, B2: Integer;
  K: TColor;
begin
  T := ActiveTokens;
  C.Brush.Color := Color;
  if (FMode = imShape) and SameText(FOpt.FillColor, 'none') then C.Brush.Color := Backdrop;
  C.FillRect(0, 0, Width, Height);
  case FMode of
    imPicture, imIcon:
      begin
        LoadPicture;
        if (FPic.Graphic = nil) or FPic.Graphic.Empty then
        begin
          C.Pen.Color := TokenColor(T.Border);
          C.Brush.Style := bsClear;
          C.Rectangle(0, 0, Width, Height);
          C.MoveTo(0, 0); C.LineTo(Width, Height);
          C.MoveTo(Width, 0); C.LineTo(0, Height);
          C.Brush.Style := bsSolid;
          Exit;
        end;
        W := FPic.Width; H := FPic.Height;
        if (FMode = imIcon) or (FOpt.SizeMode = ismCenter) then
          Dst := Bounds((Width - W) div 2, (Height - H) div 2, W, H)
        else if FOpt.SizeMode = ismStretch then
          Dst := Rect(0, 0, Width, Height)
        else
        begin
          Sc := Min(Width / Max(1, W), Height / Max(1, H));
          Dst := Bounds((Width - Round(W * Sc)) div 2, (Height - Round(H * Sc)) div 2, Round(W * Sc), Round(H * Sc));
        end;
        C.StretchDraw(Dst, FPic.Graphic);
      end;
    imShape:
      begin
        Fill := ColorOr(FOpt.FillColor, TokenColor(T.Soft));
        Line := ColorOr(FOpt.LineColor, TokenColor(T.Border));
        C.Brush.Color := Fill;
        if SameText(FOpt.FillColor, 'none') then C.Brush.Style := bsClear else C.Brush.Style := bsSolid;
        C.Pen.Color := Line;
        C.Pen.Width := Max(1, FOpt.LineWidth);
        case FOpt.Shape of
          ishRectangle: C.Rectangle(0, 0, Width, Height);
          ishRounded:
            begin
              R := T.RadiusCard;
              C.RoundRect(0, 0, Width, Height, R * 2, R * 2);
            end;
          ishEllipse: C.Ellipse(0, 0, Width, Height);
          ishLine:
            begin
              C.Pen.Color := Line;
              C.MoveTo(0, Height div 2);
              C.LineTo(Width, Height div 2);
            end;
        end;
        C.Pen.Width := 1;
        C.Brush.Style := bsSolid;
      end;
    imGradient:
      begin
        Fill := ColorOr(FOpt.FillColor, TokenColor(T.Accent));
        Fill2 := ColorOr(FOpt.ColorTo, TokenColor(T.AccentSoft));
        R1 := Red(Fill); G1 := Green(Fill); B1 := Blue(Fill);
        R2 := Red(Fill2); G2 := Green(Fill2); B2 := Blue(Fill2);
        if FOpt.Vertical then N := Height else N := Width;
        for I := 0 to N - 1 do
        begin
          if N > 1 then Sc := I / (N - 1) else Sc := 0;
          K := RGBToColor(Round(R1 + (R2 - R1) * Sc), Round(G1 + (G2 - G1) * Sc), Round(B1 + (B2 - B1) * Sc));
          C.Brush.Color := K;
          if FOpt.Vertical then C.FillRect(0, I, Width, I + 1) else C.FillRect(I, 0, I + 1, Height);
        end;
      end;
  end;
  C.Brush.Style := bsSolid;
end;

{ ---------------- pokretaci ---------------- }

constructor TaImageEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FPaint := TaImagePaint.Create(nil);
  FPaint.Mode := Mode;
  AttachInner(FPaint);
end;

function TaImageEngine.Mode: TaImageVariant;
begin
  Result := imPicture;
end;

function TaImageShapeEngine.Mode: TaImageVariant;
begin
  Result := imShape;
end;

function TaImageGradientEngine.Mode: TaImageVariant;
begin
  Result := imGradient;
end;

function TaImageIconEngine.Mode: TaImageVariant;
begin
  Result := imIcon;
end;

function TaImageEngine.GetText: string;
begin
  Result := '';
end;

procedure TaImageEngine.SetText(const AValue: string);
begin
end;

procedure TaImageEngine.ApplyOptions(AOptions: TPersistent);
begin
  if AOptions is TaImageOptions then FPaint.SetOptions(TaImageOptions(AOptions));
end;

{ ---------------- TaImage ---------------- }

constructor TaImage.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FOptions := TaImageOptions.Create;
  FVariant := imPicture;
  Width := 80;
  Height := 60;
  ReplaceEngine;
  PushToEngine;
end;

destructor TaImage.Destroy;
begin
  FOptions.Free;
  inherited Destroy;
end;

function TaImage.CreateEngine: TaEngine;
var
  C: TaEngineClass;
begin
  C := FindEngine(ImageFamily, ImageVariantNames[FVariant]);
  if C = nil then C := FindEngine(ImageFamily, 'picture');
  Result := C.Create(Self);
end;

function TaImage.VariantName: string;
begin
  Result := ImageVariantNames[FVariant];
end;

function TaImage.Painter: TaImagePaint;
begin
  if Engine is TaImageEngine then Result := TaImageEngine(Engine).Painter else Result := nil;
end;

procedure TaImage.SetPicture(APic: TPicture);
begin
  if Painter <> nil then Painter.SetPicture(APic);
end;

function TaImage.GetVariant: TaImageVariant;
begin
  Result := FVariant;
end;

procedure TaImage.SetVariant(AValue: TaImageVariant);
begin
  if AValue = FVariant then Exit;
  FVariant := AValue;
  ReplaceEngine;
  PushToEngine;
end;

function TaImage.GetOptions: TaImageOptions;
begin
  Result := FOptions;
end;

procedure TaImage.SetOptions(AValue: TaImageOptions);
begin
  FOptions.Assign(AValue);
  if Engine <> nil then Engine.ApplyOptions(FOptions);
end;

procedure TaImage.PushToEngine;
begin
  if Engine <> nil then Engine.ApplyOptions(FOptions);
end;

function TaImage.RealGetText: TCaption;
begin
  Result := '';
end;

procedure TaImage.RealSetText(const AValue: TCaption);
begin
end;

procedure TaImage.Loaded;
begin
  inherited Loaded;
  PushToEngine;
end;

{ ---------------- definicija kontrole <-> komponenta ---------------- }

const
  OwnKeys = ',variant,visibleIf,enabledIf,sizeMode,shape,fillColor,lineColor,lineWidth,colorTo,vertical,icon,svg,file,';

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

function ImageFromDef(D: TaControlDef; AOwner: TComponent): TaImage;
var
  V: TaImageVariant;
begin
  Result := TaImage.Create(AOwner);
  try
    Result.Name := D.Name;
    Result.SetBounds(D.Left, D.Top, D.Width, D.Height);
    V := ImageVariantFromName(D.GetX('variant'), imPicture);
    if SameText(D.Kind, 'Rectangle') or SameText(D.Kind, 'Line') then V := imShape;
    Result.Variant := V;
    Result.VisibleIf := D.GetX('visibleIf');
    Result.EnabledIf := D.GetX('enabledIf');
    with Result.Options do
    begin
      FileName := D.GetX('file');
      if SameText(D.GetX('sizeMode'), 'stretch') then SizeMode := ismStretch
      else if SameText(D.GetX('sizeMode'), 'center') or SameText(D.GetX('sizeMode'), 'clip') then SizeMode := ismCenter;
      if SameText(D.Kind, 'Line') then Shape := ishLine
      else if D.GetX('shape') <> '' then Shape := ShapeFromName(D.GetX('shape'));
      FillColor := D.GetX('fillColor');
      LineColor := D.GetX('lineColor');
      LineWidth := StrToIntDef(D.GetX('lineWidth'), 1);
      ColorTo := D.GetX('colorTo');
      Vertical := D.GetX('vertical') <> '0';
      Icon := D.GetX('icon');
      Svg := D.GetX('svg');
    end;
    Result.Options := Result.Options;
    Result.Extra := ExtraWithout(D.Extra);
  except
    Result.Free;
    raise;
  end;
end;

procedure ImageToDef(I: TaImage; D: TaControlDef);
var
  O: TaImageOptions;
begin
  O := I.Options;
  D.Kind := 'Image';
  D.Name := I.Name;
  D.Left := I.Left; D.Top := I.Top; D.Width := I.Width; D.Height := I.Height;
  D.Extra := I.Extra;
  D.SetX('variant', IfThen(I.Variant = imPicture, '', I.VariantName));
  D.SetX('visibleIf', I.VisibleIf);
  D.SetX('enabledIf', I.EnabledIf);
  D.SetX('file', O.FileName);
  case O.SizeMode of
    ismStretch: D.SetX('sizeMode', 'stretch');
    ismCenter: D.SetX('sizeMode', 'center');
  else
    D.SetX('sizeMode', '');
  end;
  D.SetX('shape', IfThen(O.Shape = ishRectangle, '', ImageShapeNames[O.Shape]));
  D.SetX('fillColor', O.FillColor);
  D.SetX('lineColor', O.LineColor);
  D.SetX('lineWidth', IfThen(O.LineWidth <> 1, IntToStr(O.LineWidth), ''));
  D.SetX('colorTo', O.ColorTo);
  D.SetX('vertical', IfThen(O.Vertical, '', '0'));
  D.SetX('icon', O.Icon);
  D.SetX('svg', O.Svg);
end;

function ImageToLfm(I: TaImage): string;
var
  M: TMemoryStream;
  L: TStringList;
begin
  M := TMemoryStream.Create;
  L := TStringList.Create;
  try
    WriteComponentAsTextToStream(M, I);
    M.Position := 0;
    L.LoadFromStream(M);
    Result := L.Text;
  finally
    L.Free;
    M.Free;
  end;
end;

type
  TImageLfmFinder = class
    procedure Find(Reader: TReader; const AClassName: string; var AClass: TComponentClass);
  end;

procedure TImageLfmFinder.Find(Reader: TReader; const AClassName: string; var AClass: TComponentClass);
begin
  if SameText(AClassName, 'TaImage') then AClass := TaImage;
end;

function ImageFromLfm(const ALfm: string; AOwner: TComponent): TaImage;
var
  M: TMemoryStream;
  C: TComponent;
  F: TImageLfmFinder;
begin
  M := TMemoryStream.Create;
  try
    if ALfm <> '' then M.WriteBuffer(ALfm[1], Length(ALfm));
    M.Position := 0;
    C := nil;
    F := TImageLfmFinder.Create;
    try
      ReadComponentFromTextStream(M, C, @F.Find, AOwner);
    finally
      F.Free;
    end;
    Result := C as TaImage;
  finally
    M.Free;
  end;
end;

initialization
  RegisterClass(TaImage);
  RegisterEngine(ImageFamily, 'picture', TaImageEngine);
  RegisterEngine(ImageFamily, 'shape', TaImageShapeEngine);
  RegisterEngine(ImageFamily, 'gradient', TaImageGradientEngine);
  RegisterEngine(ImageFamily, 'icon', TaImageIconEngine);

end.
