unit ta_barcodebox;
{ Obitelj Barcode: crtni i 2D kodovi (code128, ean13, ean8, code39, itf, qr, pdf417) po kodiranju iz ta_barcode.
  Varijanta je vrsta koda. Vrijednost je tekst koji se kodira (iz polja ili upisan). Isti nacin kao Edit: domacin
  TaBarcode, pokretac (crtanje), Options, definicija <-> komponenta, .lfm. HUB-3 se slaze kao PDF417 s HUB-3 tekstom. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, Graphics, Variants, DB, DBCtrls, ta_family, ta_formdef, ta_barcode;

type
  TaBarcodeVariant = (bvCode128, bvEan13, bvEan8, bvCode39, bvItf, bvQr, bvPdf417);

const
  BarcodeVariantNames: array[TaBarcodeVariant] of string = ('code128', 'ean13', 'ean8', 'code39', 'itf', 'qr', 'pdf417');
  BarcodeFamily = 'Barcode';

type
  TaBarcodeOptions = class(TPersistent)
  private
    FShowText: Boolean;
  public
    constructor Create;
    procedure Assign(ASource: TPersistent); override;
  published
    property ShowText: Boolean read FShowText write FShowText default True;
  end;

  TaBarcodePaint = class(TCustomControl)
  private
    FSym: TBarSymbology;
    FValue: string;
    FShowText: Boolean;
    FError: string;
    procedure SetValue(const AValue: string);
    procedure SetSym(AValue: TBarSymbology);
    procedure SetShowText(AValue: Boolean);
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure RenderTo(C: TCanvas);
    property Sym: TBarSymbology read FSym write SetSym;
    property Value: string read FValue write SetValue;
    property ShowText: Boolean read FShowText write SetShowText;
    { poruka kodiranja ('' = uspjelo) }
    property Error: string read FError;
  end;

  TaBarcodeEngine = class(TaEngine)
  private
    FPaint: TaBarcodePaint;
  protected
    function Sym: TBarSymbology; virtual;
  public
    constructor Create(AHost: TaFamilyHost); override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
    procedure ApplyOptions(AOptions: TPersistent); override;
    property Painter: TaBarcodePaint read FPaint;
  end;

  TaBarcodeEan13Engine = class(TaBarcodeEngine)
  protected
    function Sym: TBarSymbology; override;
  end;

  TaBarcodeEan8Engine = class(TaBarcodeEngine)
  protected
    function Sym: TBarSymbology; override;
  end;

  TaBarcodeCode39Engine = class(TaBarcodeEngine)
  protected
    function Sym: TBarSymbology; override;
  end;

  TaBarcodeItfEngine = class(TaBarcodeEngine)
  protected
    function Sym: TBarSymbology; override;
  end;

  TaBarcodeQrEngine = class(TaBarcodeEngine)
  protected
    function Sym: TBarSymbology; override;
  end;

  TaBarcodePdf417Engine = class(TaBarcodeEngine)
  protected
    function Sym: TBarSymbology; override;
  end;

  TaBarcode = class(TaFamilyHost)
  private
    FVariant: TaBarcodeVariant;
    FOptions: TaBarcodeOptions;
    FText: string;
    FControlSource, FVisibleIf, FEnabledIf, FExtra: string;
    FDataLink: TFieldDataLink;
    function GetVariant: TaBarcodeVariant;
    procedure SetVariant(AValue: TaBarcodeVariant);
    function GetOptions: TaBarcodeOptions;
    procedure SetOptions(AValue: TaBarcodeOptions);
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
    function Painter: TaBarcodePaint;
  published
    property Variant: TaBarcodeVariant read GetVariant write SetVariant default bvCode128;
    { vrijednost koja se kodira }
    property Text;
    property Options: TaBarcodeOptions read GetOptions write SetOptions;
    property ControlSource: string read FControlSource write FControlSource;
    property VisibleIf: string read FVisibleIf write FVisibleIf;
    property EnabledIf: string read FEnabledIf write FEnabledIf;
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

function IsBarcodeKind(const AKind: string): Boolean;
function BarcodeVariantFromName(const AName: string; ADefault: TaBarcodeVariant = bvCode128): TaBarcodeVariant;
function BarcodeFromDef(D: TaControlDef; AOwner: TComponent): TaBarcode;
procedure BarcodeToDef(B: TaBarcode; D: TaControlDef);
function BarcodeToLfm(B: TaBarcode): string;
function BarcodeFromLfm(const ALfm: string; AOwner: TComponent): TaBarcode;

implementation

uses
  StrUtils, LResources;

function IsBarcodeKind(const AKind: string): Boolean;
begin
  Result := SameText(AKind, 'Barcode');
end;

function BarcodeVariantFromName(const AName: string; ADefault: TaBarcodeVariant): TaBarcodeVariant;
var
  V: TaBarcodeVariant;
begin
  for V := Low(TaBarcodeVariant) to High(TaBarcodeVariant) do
    if SameText(BarcodeVariantNames[V], AName) then Exit(V);
  Result := ADefault;
end;

constructor TaBarcodeOptions.Create;
begin
  inherited Create;
  FShowText := True;
end;

procedure TaBarcodeOptions.Assign(ASource: TPersistent);
begin
  if ASource is TaBarcodeOptions then FShowText := TaBarcodeOptions(ASource).FShowText
  else inherited Assign(ASource);
end;

constructor TaBarcodePaint.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BorderStyle := bsNone;      { Qt: bez okvira QAbstractScrollArea koji tema crta kao polje }
  FShowText := True;
  Width := 160;
  Height := 60;
end;

procedure TaBarcodePaint.SetValue(const AValue: string);
begin
  FValue := AValue;
  Invalidate;
end;

procedure TaBarcodePaint.SetSym(AValue: TBarSymbology);
begin
  FSym := AValue;
  Invalidate;
end;

procedure TaBarcodePaint.SetShowText(AValue: Boolean);
begin
  FShowText := AValue;
  Invalidate;
end;

procedure TaBarcodePaint.Paint;
begin
  RenderTo(Canvas);
end;

procedure TaBarcodePaint.RenderTo(C: TCanvas);
var
  B: TBarcode;
  L: TBarLayout;
  I, Th: Integer;
begin
  C.Brush.Color := clWhite;
  C.FillRect(0, 0, Width, Height);
  FError := '';
  Th := C.TextHeight('0') + 2;
  if (FValue = '') then
  begin
    C.Font.Color := clGray;
    C.Brush.Style := bsClear;
    C.TextOut(2, 2, '(' + BarSymbologyName(FSym) + ')');
    C.Pen.Color := clSilver;
    C.Frame(0, 0, Width, Height);
    C.Brush.Style := bsSolid;
    Exit;
  end;
  if not BarcodeEncode(FSym, FValue, B, FError) then
  begin
    C.Font.Color := clMaroon;
    C.Brush.Style := bsClear;
    C.TextOut(2, 2, FError);
    C.Brush.Style := bsSolid;
    Exit;
  end;
  L := BarcodeLayout(B, Width, Height, FShowText, Th);
  C.Brush.Color := clBlack;
  for I := 0 to High(L.Rects) do C.FillRect(L.Rects[I]);
  if L.HasText then
  begin
    C.Brush.Style := bsClear;
    C.Font.Color := clBlack;
    C.TextOut(L.TextRect.Left + (Width - C.TextWidth(B.Caption)) div 2, L.TextRect.Top + 1, B.Caption);
    C.Brush.Style := bsSolid;
  end;
end;

constructor TaBarcodeEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FPaint := TaBarcodePaint.Create(nil);
  FPaint.Sym := Sym;
  AttachInner(FPaint);
end;

function TaBarcodeEngine.Sym: TBarSymbology;
begin
  Result := bsCode128;
end;

function TaBarcodeEan13Engine.Sym: TBarSymbology;
begin
  Result := bsEan13;
end;

function TaBarcodeEan8Engine.Sym: TBarSymbology;
begin
  Result := bsEan8;
end;

function TaBarcodeCode39Engine.Sym: TBarSymbology;
begin
  Result := bsCode39;
end;

function TaBarcodeItfEngine.Sym: TBarSymbology;
begin
  Result := bsItf;
end;

function TaBarcodeQrEngine.Sym: TBarSymbology;
begin
  Result := bsQr;
end;

function TaBarcodePdf417Engine.Sym: TBarSymbology;
begin
  Result := bsPdf417;
end;

function TaBarcodeEngine.GetText: string;
begin
  Result := FPaint.Value;
end;

procedure TaBarcodeEngine.SetText(const AValue: string);
begin
  FPaint.Value := AValue;
end;

procedure TaBarcodeEngine.ApplyOptions(AOptions: TPersistent);
begin
  if AOptions is TaBarcodeOptions then FPaint.ShowText := TaBarcodeOptions(AOptions).ShowText;
end;

constructor TaBarcode.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FDataLink := TFieldDataLink.Create;
  FDataLink.Control := Self;
  FDataLink.OnDataChange := @DataChange;
  FOptions := TaBarcodeOptions.Create;
  FVariant := bvCode128;
  Width := 160;
  Height := 60;
  ReplaceEngine;
  PushToEngine;
end;

destructor TaBarcode.Destroy;
begin
  FDataLink.OnDataChange := nil;
  FDataLink.Free;
  FOptions.Free;
  inherited Destroy;
end;

function TaBarcode.CreateEngine: TaEngine;
var
  C: TaEngineClass;
begin
  C := FindEngine(BarcodeFamily, BarcodeVariantNames[FVariant]);
  if C = nil then C := FindEngine(BarcodeFamily, 'code128');
  Result := C.Create(Self);
end;

function TaBarcode.VariantName: string;
begin
  Result := BarcodeVariantNames[FVariant];
end;

function TaBarcode.Painter: TaBarcodePaint;
begin
  if Engine is TaBarcodeEngine then Result := TaBarcodeEngine(Engine).Painter else Result := nil;
end;

function TaBarcode.GetVariant: TaBarcodeVariant;
begin
  Result := FVariant;
end;

procedure TaBarcode.SetVariant(AValue: TaBarcodeVariant);
begin
  if AValue = FVariant then Exit;
  FText := RealGetText;
  FVariant := AValue;
  ReplaceEngine;
  PushToEngine;
end;

function TaBarcode.GetOptions: TaBarcodeOptions;
begin
  Result := FOptions;
end;

procedure TaBarcode.SetOptions(AValue: TaBarcodeOptions);
begin
  FOptions.Assign(AValue);
  if Engine <> nil then Engine.ApplyOptions(FOptions);
end;

procedure TaBarcode.PushToEngine;
begin
  if Engine = nil then Exit;
  Engine.ApplyOptions(FOptions);
  Engine.SetText(FText);
end;

function TaBarcode.RealGetText: TCaption;
begin
  if Engine <> nil then Result := Engine.GetText else Result := FText;
end;

procedure TaBarcode.RealSetText(const AValue: TCaption);
begin
  FText := AValue;
  if Engine <> nil then Engine.SetText(AValue);
end;

function TaBarcode.GetDataSource: TDataSource;
begin
  Result := FDataLink.DataSource;
end;

procedure TaBarcode.SetDataSource(AValue: TDataSource);
begin
  FDataLink.DataSource := AValue;
  if AValue <> nil then AValue.FreeNotification(Self);
end;

function TaBarcode.GetDataField: string;
begin
  Result := FDataLink.FieldName;
end;

procedure TaBarcode.SetDataField(const AValue: string);
begin
  FDataLink.FieldName := AValue;
end;

procedure TaBarcode.Notification(AComponent: TComponent; AOperation: TOperation);
begin
  inherited Notification(AComponent, AOperation);
  if (AOperation = opRemove) and (FDataLink <> nil) and (AComponent = FDataLink.DataSource) then
    FDataLink.DataSource := nil;
end;

procedure TaBarcode.Loaded;
begin
  inherited Loaded;
  PushToEngine;
end;

procedure TaBarcode.DataChange(Sender: TObject);
var
  F: TField;
begin
  F := FDataLink.Field;
  if (F = nil) or F.IsNull then Engine.SetText('') else Engine.SetText(F.AsString);
end;

const
  OwnKeys = ',variant,tip,visibleIf,enabledIf,showText,barType,';

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

function BarcodeFromDef(D: TaControlDef; AOwner: TComponent): TaBarcode;
var
  Nm: string;
begin
  Result := TaBarcode.Create(AOwner);
  try
    Result.Name := D.Name;
    Result.SetBounds(D.Left, D.Top, D.Width, D.Height);
    Nm := D.GetX('variant');
    if Nm = '' then Nm := D.GetX('barType');
    Result.Variant := BarcodeVariantFromName(BarSymbologyName(BarSymbologyOf(Nm)), bvCode128);
    if Nm = '' then Result.Variant := bvCode128;
    Result.ControlSource := D.ControlSource;
    Result.Hint := D.GetX('tip');
    Result.VisibleIf := D.GetX('visibleIf');
    Result.EnabledIf := D.GetX('enabledIf');
    Result.Options.ShowText := D.GetX('showText') <> '0';
    Result.Options := Result.Options;
    Result.Extra := ExtraWithout(D.Extra);
  except
    Result.Free;
    raise;
  end;
end;

procedure BarcodeToDef(B: TaBarcode; D: TaControlDef);
begin
  D.Kind := 'Barcode';
  D.Name := B.Name;
  D.Left := B.Left; D.Top := B.Top; D.Width := B.Width; D.Height := B.Height;
  D.ControlSource := B.ControlSource;
  D.Extra := B.Extra;
  D.SetX('variant', '');
  D.SetX('barType', B.VariantName);
  D.SetX('tip', B.Hint);
  D.SetX('visibleIf', B.VisibleIf);
  D.SetX('enabledIf', B.EnabledIf);
  D.SetX('showText', IfThen(B.Options.ShowText, '', '0'));
end;

function BarcodeToLfm(B: TaBarcode): string;
var
  M: TMemoryStream;
  L: TStringList;
begin
  M := TMemoryStream.Create;
  L := TStringList.Create;
  try
    WriteComponentAsTextToStream(M, B);
    M.Position := 0;
    L.LoadFromStream(M);
    Result := L.Text;
  finally
    L.Free;
    M.Free;
  end;
end;

type
  TBarcodeLfmFinder = class
    procedure Find(Reader: TReader; const AClassName: string; var AClass: TComponentClass);
  end;

procedure TBarcodeLfmFinder.Find(Reader: TReader; const AClassName: string; var AClass: TComponentClass);
begin
  if SameText(AClassName, 'TaBarcode') then AClass := TaBarcode;
end;

function BarcodeFromLfm(const ALfm: string; AOwner: TComponent): TaBarcode;
var
  M: TMemoryStream;
  C: TComponent;
  F: TBarcodeLfmFinder;
begin
  M := TMemoryStream.Create;
  try
    if ALfm <> '' then M.WriteBuffer(ALfm[1], Length(ALfm));
    M.Position := 0;
    C := nil;
    F := TBarcodeLfmFinder.Create;
    try
      ReadComponentFromTextStream(M, C, @F.Find, AOwner);
    finally
      F.Free;
    end;
    Result := C as TaBarcode;
  finally
    M.Free;
  end;
end;

initialization
  RegisterClass(TaBarcode);
  RegisterEngine(BarcodeFamily, 'code128', TaBarcodeEngine);
  RegisterEngine(BarcodeFamily, 'ean13', TaBarcodeEan13Engine);
  RegisterEngine(BarcodeFamily, 'ean8', TaBarcodeEan8Engine);
  RegisterEngine(BarcodeFamily, 'code39', TaBarcodeCode39Engine);
  RegisterEngine(BarcodeFamily, 'itf', TaBarcodeItfEngine);
  RegisterEngine(BarcodeFamily, 'qr', TaBarcodeQrEngine);
  RegisterEngine(BarcodeFamily, 'pdf417', TaBarcodePdf417Engine);

end.
