unit ta_controls;
{ The Access-style control palette. Thin wrappers over LCL controls: each one
  carries its TaControlDef, which holds the Access properties (ControlSource,
  RowSource, OnClick ...) plus an Extra key=value list for the rarer ones
  (VisibleIf, EnabledIf, Tip, colours, fonts, chart type, embedded picture ...).
  The same definition drives the form runtime, the designers and the reports. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, StdCtrls, Buttons, ExtCtrls, ComCtrls, Graphics, base64, Math,
  ta_formdef, ta_barcode, ta_filestore, ta_richtext, ta_richedit, ta_richbase, ta_sidemenu;

const
  { palette order as shown in the form designer }
  { redom: unos podataka, prikaz, radnje, razmjestaj i navigacija, oblici }
  KindNames: array[0..22] of string = (
    'TextBox', 'MemoBox', 'RichText', 'ComboBox', 'CheckBox', 'OptionGroup', 'ListBox', 'Calendar',
    'Label', 'Hyperlink', 'Image', 'Chart', 'Barcode', 'Progress',
    'Button', 'ToggleButton',
    'Panel', 'Pages', 'Subform', 'TabControl', 'SideMenu',
    'Rectangle', 'Line');
  ReportKindNames: array[0..10] of string = (
    'Label', 'TextBox', 'RichText', 'Line', 'Rectangle', 'Image', 'Chart', 'Barcode', 'Subreport', 'Hyperlink', 'PageBreak');
  ChartColors: array[0..7] of TColor = (
    $B4741F, $0E7FFF, $2CA02C, $2828D6, $BD6794, $4B568C, $C277E3, $22BDBC);

type
  TaTextBox = class(TEdit)
  public
    Def: TaControlDef;
  end;

  TaMemo = class(TMemo)
  public
    Def: TaControlDef;
  end;

  { formatirani tekst (HTML podskup u polju baze) }

  TaLabel = class(TLabel)
  public
    Def: TaControlDef;
  end;

  TaHyperlink = class(TLabel)
  public
    Def: TaControlDef;
    Address: string;
  end;

  TaButton = class(TBitBtn)
  public
    Def: TaControlDef;
  end;

  TaCheckBox = class(TCheckBox)
  public
    Def: TaControlDef;
  end;

  TaToggle = class(TToggleBox)
  public
    Def: TaControlDef;
  end;

  { Keys holds the bound column when RowSource returns key + display columns (Lookup). }
  TaComboBox = class(TComboBox)
  private
    FFiltering: Boolean;
    function SearchTextChanged: Boolean;
  protected
    procedure Change; override;
    procedure Select; override;
    procedure DoExit; override;
  public
    Def: TaControlDef;
    Keys: TStringList;
    { pretrazivi padajuci popis: tipkanje suzuje stavke na one koje sadrze tekst }
    Search: Boolean;
    AllLabels, AllKeys: TStringList;
    LastKey: string;
    destructor Destroy; override;
    procedure EnableSearch(AOn: Boolean);
    { vraca cijeli popis i odabire stavku s tim kljucem }
    procedure SelectKey(const AKey: string);
    procedure ApplyFilter(const AText: string);
    function CurrentKey: string;
  end;

  TaListBox = class(TListBox)
  public
    Def: TaControlDef;
    Keys: TStringList;
    destructor Destroy; override;
  end;

  { RowSource is "1=Muški;2=Ženski": value=label pairs }
  TaOptionGroup = class(TRadioGroup)
  public
    Def: TaControlDef;
    Keys: TStringList;
    destructor Destroy; override;
  end;

  TaSubform = class(TPanel)
  public
    Def: TaControlDef;
  end;

  { RowSource lists the tab captions: "Podaci;Povijest" }
  TaTabControl = class(TPageControl)
  public
    Def: TaControlDef;
  end;

  TaImage = class(TImage)
  public
    Def: TaControlDef;
    LoadedKey: string;
  end;

  TaChart = class(TPaintBox)
  public
    Def: TaControlDef;
    Labels: TStringList;
    Values: array of Double;
    ChartType, Title: string;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Paint; override;
  end;

  { Barkod / QR kod: vrijednost dolazi iz polja ili izraza (ControlSource) }
  TaBarcode = class(TPaintBox)
  public
    Def: TaControlDef;
    Value: string;
    BarType: string;
    ShowText: Boolean;
    procedure Paint; override;
  end;

  { Podizvjesce: u izvjescu ispisuje drugo izvjesce za zapise vezane uz trenutni zapis. }
  TaSubreportBox = class(TPaintBox)
  public
    Def: TaControlDef;
    Info: string;
    procedure Paint; override;
  end;

  TaRect = class(TShape)
  public
    Def: TaControlDef;
  end;

  TaLine = class(TShape)
  public
    Def: TaControlDef;
  end;

  TaPageBreak = class(TShape)
  public
    Def: TaControlDef;
  end;

function CreateAccessControl(AOwner: TComponent; AParent: TWinControl; ADef: TaControlDef): TControl;
{ obitelji kontrola (ta_famctl) se prikljucuju kukama, da ta_controls ne ovisi o njima }
type
  TFamilyDefHook = function(C: TControl): TaControlDef;
  TFamilyReadHook = function(C: TControl; out AValue: string): Boolean;
  TFamilyWriteHook = function(C: TControl; const AValue: string): Boolean;
  TFamilyBoundHook = function(C: TControl): Boolean;

var
  FamilyDefHook: TFamilyDefHook = nil;
  FamilyReadHook: TFamilyReadHook = nil;
  FamilyWriteHook: TFamilyWriteHook = nil;
  FamilyBoundHook: TFamilyBoundHook = nil;

procedure ApplyDef(C: TControl; ADesign: Boolean);
function DefOf(C: TControl): TaControlDef;
function IsBoundControl(C: TControl): Boolean;
function IsCalculated(C: TControl): Boolean;
function ReadControlValue(C: TControl): string;
procedure WriteControlValue(C: TControl; const S: string);
procedure DefaultSize(const AKind: string; out W, H: Integer);

{ Property table shared by both designers. }
function PropertyNamesFor(const AKind: string; AReport: Boolean): TStringList;
function DefGet(D: TaControlDef; const AProp: string): string;
procedure DefSet(D: TaControlDef; const AProp, AValue: string);
function IsExprProp(const AProp: string): Boolean;
function VariantsForKind(const AKind: string): string;

{ sidrenje kontrole uz rub prozora: pohranjuje se kao slova L, T, R, B (lijevo, gore, desno, dolje) }
function AnchorLetters(const AText: string): string;
function AnchorsDisplay(const ALetters: string): string;
function AnchorsOf(const ALetters: string): TAnchors;
procedure ApplyAnchors(C: TControl; D: TaControlDef);

{ raspored kao u Lazarusu: Dock (Align), BorderSpacing i sidra uz druge kontrole (AnchorSide) }
function DockOfDef(D: TaControlDef): TAlign;
function ParseSpacing(const AText: string; out L, T, R, B: Integer): Boolean;
function NormalizeSpacing(const AText: string): string;
function HasLayoutProps(D: TaControlDef): Boolean;
function SiblingByName(AParent: TWinControl; const AName: string): TControl;
procedure ApplyControlLayout(C: TControl; D: TaControlDef);
procedure ClearLayout(C: TControl);

{ Helpers used by the runtime and the report engine. }
function HexToColor(const S: string; ADefault: TColor): TColor;
function ColorToHex(C: TColor): string;
function LoadPictureFromBase64(APic: TPicture; const AB64: string): Boolean;
function LoadPictureFromBytes(APic: TPicture; const ABytes: string): Boolean;
{ kao gore, ali SVG crta u zadanoj sirini u tockama (oštro na zaslonu, pisacu i u PDF-u) }
function LoadPictureSized(APic: TPicture; const ABytes: string; AWidth: Integer): Boolean;
function PictureFileToBase64(const AFile: string): string;
procedure ParsePairs(const ASrc: string; AKeys, ALabels: TStrings);
procedure DrawChart(ACanvas: TCanvas; const R: TRect; ALabels: TStrings;
  const AValues: array of Double; const AType, ATitle: string);

implementation

uses
  ta_i18n,
  ta_icons, ta_iconsdata, ta_svg, ta_tokens;

{ ---------------- small classes ---------------- }

destructor TaComboBox.Destroy;
begin
  Keys.Free;
  AllLabels.Free;
  AllKeys.Free;
  inherited Destroy;
end;

procedure TaComboBox.EnableSearch(AOn: Boolean);
begin
  Search := AOn and (Keys <> nil);
  if not Search then Exit;
  if AllLabels = nil then AllLabels := TStringList.Create;
  if AllKeys = nil then AllKeys := TStringList.Create;
  AllLabels.Assign(Items);
  AllKeys.Assign(Keys);
  Style := csDropDown;
  AutoComplete := False;
end;

function TaComboBox.CurrentKey: string;
begin
  if Search and (ItemIndex < 0) then Exit(LastKey);
  if (Keys <> nil) and (ItemIndex >= 0) and (ItemIndex < Keys.Count) then Result := Keys[ItemIndex]
  else Result := '';
end;

procedure TaComboBox.SelectKey(const AKey: string);
var
  I: Integer;
begin
  FFiltering := True;
  try
    Items.BeginUpdate;
    try
      Items.Assign(AllLabels);
      Keys.Assign(AllKeys);
    finally
      Items.EndUpdate;
    end;
    I := AllKeys.IndexOf(AKey);
    ItemIndex := I;
    if I < 0 then Text := '';
    if I >= 0 then LastKey := AKey else LastKey := '';
  finally
    FFiltering := False;
  end;
end;

procedure TaComboBox.ApplyFilter(const AText: string);
var
  I: Integer;
  T, Needle: string;
begin
  FFiltering := True;
  try
    T := AText;
    Needle := LowerCase(Trim(AText));
    Items.BeginUpdate;
    try
      Items.Clear;
      Keys.Clear;
      for I := 0 to AllLabels.Count - 1 do
        if (Needle = '') or (Pos(Needle, LowerCase(AllLabels[I])) > 0) then
        begin
          Items.Add(AllLabels[I]);
          Keys.Add(AllKeys[I]);
        end;
    finally
      Items.EndUpdate;
    end;
    Text := T;
    SelStart := Length(T);
  finally
    FFiltering := False;
  end;
end;

{ True kad je tekst tocno jedna stavka popisa (odabir), inace se samo suzuje popis. }
function TaComboBox.SearchTextChanged: Boolean;
var
  I: Integer;
begin
  Result := False;
  I := AllLabels.IndexOf(Text);
  if I >= 0 then
  begin
    SelectKey(AllKeys[I]);
    Exit(True);
  end;
  ApplyFilter(Text);
  if (Items.Count > 0) and Focused then DroppedDown := True;
end;

procedure TaComboBox.Change;
begin
  if Search and (not FFiltering) then
    if not SearchTextChanged then Exit;
  inherited Change;
end;

procedure TaComboBox.Select;
begin
  if Search and (ItemIndex >= 0) and (ItemIndex < Keys.Count) then LastKey := Keys[ItemIndex];
  inherited Select;
end;

procedure TaComboBox.DoExit;
begin
  if Search then
  begin
    if Trim(Text) = '' then
    begin
      if LastKey <> '' then
      begin
        SelectKey('');
        inherited Change;      { prazno polje = nema veze }
      end;
    end
    else if ItemIndex < 0 then SelectKey(LastKey);   { nedovrseno tipkanje se ponistava }
  end;
  inherited DoExit;
end;

destructor TaListBox.Destroy;
begin
  Keys.Free;
  inherited Destroy;
end;

destructor TaOptionGroup.Destroy;
begin
  Keys.Free;
  inherited Destroy;
end;

constructor TaChart.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Labels := TStringList.Create;
end;

destructor TaChart.Destroy;
begin
  Labels.Free;
  inherited Destroy;
end;

procedure TaChart.Paint;
begin
  Canvas.Brush.Color := clWhite;
  Canvas.FillRect(0, 0, Width, Height);
  DrawChart(Canvas, Rect(0, 0, Width, Height), Labels, Values, ChartType, Title);
end;

procedure TaSubreportBox.Paint;
begin
  Canvas.Brush.Color := $F7F7F7;
  Canvas.Pen.Color := clGray;
  Canvas.Pen.Style := psDash;
  Canvas.Rectangle(0, 0, Width, Height);
  Canvas.Font.Color := clGray;
  Canvas.Brush.Style := bsClear;
  Canvas.TextOut(6, 4, Info);
end;

procedure TaBarcode.Paint;
var
  B: TBarcode;
  Err: string;
  L: TBarLayout;
  I, Th: Integer;
begin
  Canvas.Brush.Color := clWhite;
  Canvas.FillRect(0, 0, Width, Height);
  Th := Canvas.TextHeight('0') + 2;
  if (Value = '') or not BarcodeEncode(BarSymbologyOf(BarType), Value, B, Err) then
  begin
    Canvas.Font.Color := clGray;
    Canvas.Brush.Style := bsClear;
    if Value = '' then Err := '(' + BarType + ')';
    Canvas.TextOut(2, 2, Err);
    Canvas.Pen.Color := clSilver;
    Canvas.Frame(0, 0, Width, Height);
    Exit;
  end;
  L := BarcodeLayout(B, Width, Height, ShowText, Th);
  Canvas.Brush.Color := clBlack;
  for I := 0 to High(L.Rects) do
    Canvas.FillRect(L.Rects[I]);
  if L.HasText then
  begin
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Color := clBlack;
    Canvas.TextOut(L.TextRect.Left + (Width - Canvas.TextWidth(B.Caption)) div 2, L.TextRect.Top + 1, B.Caption);
  end;
end;

{ ---------------- colours, pictures, pairs ---------------- }

function HexToColor(const S: string; ADefault: TColor): TColor;
var
  T: string;
  V: LongInt;
begin
  T := Trim(S);
  if (T = '') then Exit(ADefault);
  if T[1] = '#' then Delete(T, 1, 1);
  if (Length(T) <> 6) or not TryStrToInt('$' + T, V) then Exit(ADefault);
  Result := RGBToColor((V shr 16) and $FF, (V shr 8) and $FF, V and $FF);
end;

function ColorToHex(C: TColor): string;
var
  R, G, B: Byte;
begin
  RedGreenBlue(ColorToRGB(C), R, G, B);
  Result := '#' + IntToHex(R, 2) + IntToHex(G, 2) + IntToHex(B, 2);
end;

function LoadPictureFromBytes(APic: TPicture; const ABytes: string): Boolean;
begin
  Result := LoadPictureSized(APic, ABytes, 512);
end;

function LoadPictureSized(APic: TPicture; const ABytes: string; AWidth: Integer): Boolean;
var
  Ms: TMemoryStream;
  Raw: string;
begin
  Result := False;
  if ABytes = '' then Exit;
  Raw := ABytes;
  if IsSvgBytes(Raw) then
  begin
    Raw := SvgTextToPng(Raw, AWidth);
    if Raw = '' then Exit;
  end;
  Ms := TMemoryStream.Create;
  try
    Ms.WriteBuffer(Raw[1], Length(Raw));
    Ms.Position := 0;
    try
      APic.LoadFromStream(Ms);
      Result := True;
    except
      Result := False;
    end;
  finally
    Ms.Free;
  end;
end;

function LoadPictureFromBase64(APic: TPicture; const AB64: string): Boolean;
begin
  Result := False;
  if AB64 = '' then Exit;
  try
    Result := LoadPictureFromBytes(APic, DecodeStringBase64(AB64));
  except
    Result := False;
  end;
end;

function PictureFileToBase64(const AFile: string): string;
var
  Fs: TFileStream;
  Raw: string;
begin
  Result := '';
  if not FileExists(AFile) then Exit;
  Fs := TFileStream.Create(AFile, fmOpenRead or fmShareDenyNone);
  try
    SetLength(Raw, Fs.Size);
    if Fs.Size > 0 then Fs.ReadBuffer(Raw[1], Fs.Size);
  finally
    Fs.Free;
  end;
  Result := EncodeStringBase64(Raw);
end;

procedure ParsePairs(const ASrc: string; AKeys, ALabels: TStrings);
var
  L: TStringList;
  I, P: Integer;
  S: string;
begin
  AKeys.Clear;
  ALabels.Clear;
  L := TStringList.Create;
  try
    L.Delimiter := ';';
    L.StrictDelimiter := True;
    L.DelimitedText := ASrc;
    for I := 0 to L.Count - 1 do
    begin
      S := Trim(L[I]);
      if S = '' then Continue;
      P := Pos('=', S);
      if P > 0 then
      begin
        AKeys.Add(Trim(Copy(S, 1, P - 1)));
        ALabels.Add(Trim(Copy(S, P + 1, MaxInt)));
      end
      else
      begin
        AKeys.Add(IntToStr(ALabels.Count + 1));
        ALabels.Add(S);
      end;
    end;
  finally
    L.Free;
  end;
end;

{ ---------------- chart drawing ---------------- }

procedure DrawChart(ACanvas: TCanvas; const R: TRect; ALabels: TStrings;
  const AValues: array of Double; const AType, ATitle: string);
var
  N, I, X0, Y0, X1, Y1, BarW, Gap, H, K: Integer;
  MaxV, MinV, Sum, A1, A2, Cx, Cy, Rad, V: Double;
  Cap: string;
  PtPrev: TPoint;
  Pt: TPoint;
  TitleH, LegendW, Ly: Integer;
begin
  N := Length(AValues);
  ACanvas.Brush.Style := bsClear;
  ACanvas.Font.Color := clBlack;
  ACanvas.Font.Size := 8;
  ACanvas.Font.Style := [];
  TitleH := 0;
  if ATitle <> '' then
  begin
    ACanvas.Font.Style := [fsBold];
    ACanvas.TextOut(R.Left + 8, R.Top + 4, ATitle);
    ACanvas.Font.Style := [];
    TitleH := ACanvas.TextHeight(ATitle) + 8;
  end;
  if N = 0 then
  begin
    ACanvas.TextOut(R.Left + 8, R.Top + TitleH + 8, '(nema podataka)');
    Exit;
  end;
  if SameText(AType, 'pie') then
  begin
    Sum := 0;
    for I := 0 to N - 1 do if AValues[I] > 0 then Sum := Sum + AValues[I];
    LegendW := 110;
    X0 := R.Left + 10; Y0 := R.Top + TitleH + 6;
    X1 := R.Right - LegendW - 10; Y1 := R.Bottom - 10;
    H := Min(X1 - X0, Y1 - Y0);
    if (H < 20) or (Sum <= 0) then Exit;
    Cx := X0 + H / 2; Cy := Y0 + H / 2; Rad := H / 2;
    A1 := 0;
    for I := 0 to N - 1 do
    begin
      if AValues[I] <= 0 then Continue;
      A2 := A1 + AValues[I] / Sum * 2 * Pi;
      ACanvas.Brush.Style := bsSolid;
      ACanvas.Brush.Color := ActiveChartColor(I mod 8);
      ACanvas.Pen.Color := clWhite;
      if AValues[I] >= Sum then
        ACanvas.Ellipse(Round(Cx - Rad), Round(Cy - Rad), Round(Cx + Rad), Round(Cy + Rad))
      else
        ACanvas.Pie(Round(Cx - Rad), Round(Cy - Rad), Round(Cx + Rad), Round(Cy + Rad),
          Round(Cx + Rad * Sin(A2)), Round(Cy - Rad * Cos(A2)),
          Round(Cx + Rad * Sin(A1)), Round(Cy - Rad * Cos(A1)));
      A1 := A2;
    end;
    ACanvas.Brush.Style := bsClear;
    Ly := Y0;
    for I := 0 to N - 1 do
    begin
      if I < ALabels.Count then Cap := ALabels[I] else Cap := '';
      ACanvas.Brush.Style := bsSolid;
      ACanvas.Brush.Color := ActiveChartColor(I mod 8);
      ACanvas.FillRect(R.Right - LegendW, Ly, R.Right - LegendW + 10, Ly + 10);
      ACanvas.Brush.Style := bsClear;
      ACanvas.TextOut(R.Right - LegendW + 14, Ly - 2, Cap);
      Inc(Ly, 16);
    end;
    Exit;
  end;
  { bar / line: common axes }
  MaxV := 0; MinV := 0;
  for I := 0 to N - 1 do
  begin
    if AValues[I] > MaxV then MaxV := AValues[I];
    if AValues[I] < MinV then MinV := AValues[I];
  end;
  if MaxV = MinV then MaxV := MinV + 1;
  X0 := R.Left + 36; X1 := R.Right - 10;
  Y0 := R.Top + TitleH + 14; Y1 := R.Bottom - 26;
  if (X1 - X0 < 20) or (Y1 - Y0 < 20) then Exit;
  ACanvas.Pen.Color := clGray;
  ACanvas.Line(X0, Y0, X0, Y1);
  { zero line }
  K := Y1 - Round((0 - MinV) / (MaxV - MinV) * (Y1 - Y0));
  ACanvas.Line(X0, K, X1, K);
  ACanvas.Brush.Style := bsClear;
  ACanvas.TextOut(R.Left + 2, Y0 - 6, FloatToStrF(MaxV, ffGeneral, 4, 0));
  ACanvas.TextOut(R.Left + 2, Y1 - 6, FloatToStrF(MinV, ffGeneral, 4, 0));
  Gap := 6;
  BarW := (X1 - X0 - Gap) div N - Gap;
  if BarW < 3 then BarW := 3;
  PtPrev := Point(-1, -1);
  for I := 0 to N - 1 do
  begin
    V := AValues[I];
    H := Y1 - Round((V - MinV) / (MaxV - MinV) * (Y1 - Y0));
    if I < ALabels.Count then Cap := ALabels[I] else Cap := '';
    if SameText(AType, 'line') then
    begin
      Pt := Point(X0 + Gap + I * (BarW + Gap) + BarW div 2, H);
      ACanvas.Pen.Color := ActiveChartColor(0);
      ACanvas.Pen.Width := 2;
      if PtPrev.X >= 0 then ACanvas.Line(PtPrev.X, PtPrev.Y, Pt.X, Pt.Y);
      ACanvas.Pen.Width := 1;
      ACanvas.Brush.Style := bsSolid;
      ACanvas.Brush.Color := ActiveChartColor(0);
      ACanvas.Ellipse(Pt.X - 3, Pt.Y - 3, Pt.X + 4, Pt.Y + 4);
      PtPrev := Pt;
    end
    else
    begin
      ACanvas.Brush.Style := bsSolid;
      ACanvas.Brush.Color := ActiveChartColor(I mod 8);
      ACanvas.Pen.Color := ActiveChartColor(I mod 8);
      ACanvas.Rectangle(X0 + Gap + I * (BarW + Gap), Min(H, K), X0 + Gap + I * (BarW + Gap) + BarW, Max(H, K) + 1);
    end;
    ACanvas.Brush.Style := bsClear;
    ACanvas.Font.Color := clBlack;
    if BarW >= 28 then
      ACanvas.TextOut(X0 + Gap + I * (BarW + Gap), Min(H, K) - 13, FloatToStrF(V, ffGeneral, 4, 0));
    ACanvas.TextRect(Rect(X0 + Gap + I * (BarW + Gap) - 2, Y1 + 4, X0 + Gap + I * (BarW + Gap) + BarW + Gap, Y1 + 20),
      X0 + Gap + I * (BarW + Gap) - 2, Y1 + 4, Cap);
  end;
end;

{ ---------------- def lookup ---------------- }

function DefOf(C: TControl): TaControlDef;
begin
  if Assigned(FamilyDefHook) then
  begin
    Result := FamilyDefHook(C);
    if Result <> nil then Exit;
  end;
  if C is TaTextBox then Result := TaTextBox(C).Def
  else if C is TaMemo then Result := TaMemo(C).Def
  else if (C is TaRichBase) and (TaRichBase(C).DefObj is TaControlDef) then Result := TaControlDef(TaRichBase(C).DefObj)
  else if C is TaLabel then Result := TaLabel(C).Def
  else if C is TaHyperlink then Result := TaHyperlink(C).Def
  else if C is TaButton then Result := TaButton(C).Def
  else if C is TaCheckBox then Result := TaCheckBox(C).Def
  else if C is TaToggle then Result := TaToggle(C).Def
  else if C is TaComboBox then Result := TaComboBox(C).Def
  else if C is TaListBox then Result := TaListBox(C).Def
  else if C is TaOptionGroup then Result := TaOptionGroup(C).Def
  else if C is TaSubform then Result := TaSubform(C).Def
  else if C is TaTabControl then Result := TaTabControl(C).Def
  else if C is TaSideMenu then Result := TaControlDef(TaSideMenu(C).Def)
  else if C is TaImage then Result := TaImage(C).Def
  else if C is TaChart then Result := TaChart(C).Def
  else if C is TaBarcode then Result := TaBarcode(C).Def
  else if C is TaSubreportBox then Result := TaSubreportBox(C).Def
  else if C is TaRect then Result := TaRect(C).Def
  else if C is TaLine then Result := TaLine(C).Def
  else if C is TaPageBreak then Result := TaPageBreak(C).Def
  else Result := nil;
end;

procedure DefaultSize(const AKind: string; out W, H: Integer);
begin
  W := 160; H := 24;
  if AKind = 'Line' then begin W := 200; H := 2; end
  else if AKind = 'PageBreak' then begin W := 200; H := 2; end
  else if AKind = 'Label' then begin W := 100; H := 20; end
  else if AKind = 'Hyperlink' then begin W := 160; H := 20; end
  else if AKind = 'Button' then begin W := 100; H := 28; end
  else if AKind = 'ToggleButton' then begin W := 110; H := 28; end
  else if AKind = 'CheckBox' then begin W := 120; H := 22; end
  else if AKind = 'ListBox' then begin W := 200; H := 100; end
  else if AKind = 'OptionGroup' then begin W := 180; H := 80; end
  else if AKind = 'Panel' then begin W := 300; H := 160; end
  else if AKind = 'Pages' then begin W := 360; H := 200; end
  else if AKind = 'Subform' then begin W := 360; H := 160; end
  else if AKind = 'TabControl' then begin W := 360; H := 200; end
  else if AKind = 'SideMenu' then begin W := 220; H := 320; end
  else if AKind = 'Image' then begin W := 120; H := 100; end
  else if AKind = 'Calendar' then begin W := 230; H := 170; end
  else if AKind = 'Progress' then begin W := 200; H := 24; end
  else if AKind = 'Chart' then begin W := 320; H := 200; end
  else if AKind = 'Barcode' then begin W := 140; H := 140; end
  else if AKind = 'Subreport' then begin W := 500; H := 90; end
  else if AKind = 'MemoBox' then begin W := 240; H := 80; end
  else if AKind = 'RichText' then begin W := 360; H := 160; end
  else if AKind = 'Rectangle' then begin W := 200; H := 80; end;
end;

function CreateAccessControl(AOwner: TComponent; AParent: TWinControl; ADef: TaControlDef): TControl;
var
  K: string;
begin
  K := ADef.Kind;
  if K = 'TextBox' then begin Result := TaTextBox.Create(AOwner); TaTextBox(Result).Def := ADef; end
  else if K = 'MemoBox' then begin Result := TaMemo.Create(AOwner); TaMemo(Result).Def := ADef; end
  else if K = 'RichText' then begin Result := NewRichEditor(AOwner); TaRichBase(Result).DefObj := ADef; end
  else if K = 'Label' then begin Result := TaLabel.Create(AOwner); TaLabel(Result).Def := ADef; end
  else if K = 'Hyperlink' then begin Result := TaHyperlink.Create(AOwner); TaHyperlink(Result).Def := ADef; end
  else if K = 'Button' then begin Result := TaButton.Create(AOwner); TaButton(Result).Def := ADef; end
  else if K = 'CheckBox' then begin Result := TaCheckBox.Create(AOwner); TaCheckBox(Result).Def := ADef; end
  else if K = 'ToggleButton' then begin Result := TaToggle.Create(AOwner); TaToggle(Result).Def := ADef; end
  else if K = 'ComboBox' then begin Result := TaComboBox.Create(AOwner); TaComboBox(Result).Def := ADef; end
  else if K = 'ListBox' then begin Result := TaListBox.Create(AOwner); TaListBox(Result).Def := ADef; end
  else if K = 'OptionGroup' then begin Result := TaOptionGroup.Create(AOwner); TaOptionGroup(Result).Def := ADef; end
  else if K = 'Subform' then begin Result := TaSubform.Create(AOwner); TaSubform(Result).Def := ADef; end
  else if K = 'TabControl' then begin Result := TaTabControl.Create(AOwner); TaTabControl(Result).Def := ADef; end
  else if K = 'SideMenu' then begin Result := TaSideMenu.Create(AOwner); TaSideMenu(Result).Def := ADef; end
  else if K = 'Image' then begin Result := TaImage.Create(AOwner); TaImage(Result).Def := ADef; end
  else if K = 'Chart' then begin Result := TaChart.Create(AOwner); TaChart(Result).Def := ADef; end
  else if K = 'Barcode' then begin Result := TaBarcode.Create(AOwner); TaBarcode(Result).Def := ADef; end
  else if K = 'Subreport' then begin Result := TaSubreportBox.Create(AOwner); TaSubreportBox(Result).Def := ADef; end
  else if K = 'Rectangle' then begin Result := TaRect.Create(AOwner); TaRect(Result).Def := ADef; end
  else if K = 'Line' then begin Result := TaLine.Create(AOwner); TaLine(Result).Def := ADef; end
  else if K = 'PageBreak' then begin Result := TaPageBreak.Create(AOwner); TaPageBreak(Result).Def := ADef; end
  else raise Exception.Create(Tr('Unknown control kind: ') + K);
  Result.Parent := AParent;
  ApplyDef(Result, False);
end;

{ ---------------- applying a definition to the live control ---------------- }

procedure ApplyTabs(T: TaTabControl; const ACaptions: string);
var
  L: TStringList;
  I: Integer;
  Sh: TTabSheet;
begin
  L := TStringList.Create;
  try
    L.Delimiter := ';';
    L.StrictDelimiter := True;
    L.DelimitedText := ACaptions;
    for I := L.Count - 1 downto 0 do
      if Trim(L[I]) = '' then L.Delete(I);
    if L.Count = 0 then L.Add('Stranica 1');
    while T.PageCount < L.Count do
    begin
      Sh := T.AddTabSheet;
      Sh.Caption := L[T.PageCount - 1];
    end;
    { drop empty surplus pages only, so controls are never destroyed by an edit }
    while (T.PageCount > L.Count) and (T.Pages[T.PageCount - 1].ControlCount = 0) do
      T.Pages[T.PageCount - 1].Free;
    for I := 0 to Min(L.Count, T.PageCount) - 1 do T.Pages[I].Caption := Trim(L[I]);
  finally
    L.Free;
  end;
end;

procedure ApplyDef(C: TControl; ADesign: Boolean);
var
  D: TaControlDef;
  Shown, Al, Fn, IconN: string;
  Sz, Bw: Integer;
  Fc, Bc: TColor;
  Pic: TPicture;
  K, Mode: string;
begin
  D := DefOf(C);
  if D = nil then Exit;
  if (D.Name <> '') and (C.Name <> D.Name) and IsValidIdent(D.Name) then
    try C.Name := D.Name; except end;
  if D.ControlSource <> '' then Shown := '[' + D.ControlSource + ']' else Shown := '';
  Al := LowerCase(D.Align);
  if C is TLabel then
  begin
    TLabel(C).AutoSize := False;
    if Al = 'right' then TLabel(C).Alignment := taRightJustify
    else if Al = 'center' then TLabel(C).Alignment := taCenter
    else TLabel(C).Alignment := taLeftJustify;
    if (C is TaHyperlink) then
    begin
      if ADesign and (D.Caption = '') then C.Caption := Shown else C.Caption := D.Caption;
      TaHyperlink(C).Address := D.RowSource;
      TLabel(C).Font.Color := clBlue;
      TLabel(C).Font.Style := TLabel(C).Font.Style + [fsUnderline];
      TLabel(C).Cursor := crHandPoint;
    end
    else C.Caption := D.Caption;
  end
  else if C is TToggleBox then C.Caption := D.Caption
  else if C is TCustomButton then
  begin
    C.Caption := D.Caption;
    if C is TBitBtn then
    begin
      IconN := D.GetX('icon');
      if IconN <> '' then SetGlyph(TBitBtn(C), IconN, IfThen(D.Height >= 40, 24, 16))
      else TBitBtn(C).Glyph.Clear;
    end;
  end
  else if C is TCheckBox then C.Caption := D.Caption
  else if C is TRadioGroup then C.Caption := D.Caption
  else if C is TEdit then
  begin
    TEdit(C).AutoSize := False;
    if Al = 'right' then TEdit(C).Alignment := taRightJustify
    else if Al = 'center' then TEdit(C).Alignment := taCenter
    else TEdit(C).Alignment := taLeftJustify;
    if ADesign then
    begin
      TEdit(C).Text := Shown;
      TEdit(C).ReadOnly := True;
    end
    else TEdit(C).ReadOnly := D.GetX('locked') = '1';
  end
  else if C is TaRichBase then
  begin
    if ADesign then
    begin
      TaRichBase(C).Html := RtFromPlain('[' + D.ControlSource + ']');
      TaRichBase(C).ReadOnly := True;
    end
    else TaRichBase(C).ReadOnly := D.GetX('locked') = '1';
  end
  else if C is TMemo then
  begin
    TMemo(C).ScrollBars := ssAutoVertical;
    if ADesign then
    begin
      TMemo(C).Text := Shown;
      TMemo(C).ReadOnly := True;
    end
    else TMemo(C).ReadOnly := D.GetX('locked') = '1';
  end
  else if (C is TComboBox) and ADesign then TComboBox(C).Text := Shown
  else if C is TaTabControl then ApplyTabs(TaTabControl(C), D.RowSource)
  else if C is TaSideMenu then
  begin
    TaSideMenu(C).Accordion := D.GetX('accordion') <> '0';
    TaSideMenu(C).Items := D.RowSource;
  end
  else if C is TPanel then
  begin
    TPanel(C).BevelOuter := bvLowered;
    if ADesign then C.Caption := 'Subform: ' + D.RowSource else C.Caption := '';
  end
  else if C is TaImage then
  begin
    Mode := LowerCase(D.GetX('sizeMode'));
    TaImage(C).Center := True;
    TaImage(C).Stretch := Mode <> 'clip';
    TaImage(C).Proportional := (Mode = '') or (Mode = 'zoom');
    K := D.GetX('picture');
    if K <> '' then
    begin
      if TaImage(C).LoadedKey <> IntToStr(Length(K)) + Copy(K, 1, 24) then
      begin
        Pic := TPicture.Create;
        try
          if Copy(K, 1, 5) = 'file:' then
          begin
            { nova slika: veza na datoteku u pohrani; stara: base64 u definiciji }
            Fn := ResolveFileLink(ActiveStoreDb, Copy(K, 6, MaxInt));
            if (Fn <> '') and FileExists(Fn) then
              try
                Pic.LoadFromFile(Fn);
                TaImage(C).Picture.Assign(Pic);
              except
              end;
          end
          else if LoadPictureFromBase64(Pic, K) then TaImage(C).Picture.Assign(Pic);
        finally
          Pic.Free;
        end;
        TaImage(C).LoadedKey := IntToStr(Length(K)) + Copy(K, 1, 24);
      end;
    end
    else
    begin
      TaImage(C).LoadedKey := '';
      TaImage(C).Picture.Clear;
    end;
  end
  else if C is TaSubreportBox then
  begin
    TaSubreportBox(C).Info := 'Podizvješće: ' + D.RowSource + '   veza: ' + D.LinkMaster + ' = ' + D.LinkChild;
    C.Invalidate;
  end
  else if C is TaBarcode then
  begin
    TaBarcode(C).BarType := LowerCase(D.GetX('barType'));
    if TaBarcode(C).BarType = '' then TaBarcode(C).BarType := 'qr';
    TaBarcode(C).ShowText := D.GetX('showText') <> '0';
    if ADesign then
    begin
      if BarSymbologyOf(TaBarcode(C).BarType) in [bsEan13, bsEan8, bsItf] then TaBarcode(C).Value := '4006381333931'
      else TaBarcode(C).Value := 'TyphAccess';
    end;
    C.Invalidate;
  end
  else if C is TaChart then
  begin
    TaChart(C).ChartType := LowerCase(D.GetX('chartType'));
    TaChart(C).Title := D.Caption;
    if ADesign and (TaChart(C).Labels.Count = 0) then
    begin
      TaChart(C).Labels.CommaText := 'A,B,C,D';
      SetLength(TaChart(C).Values, 4);
      TaChart(C).Values[0] := 4; TaChart(C).Values[1] := 7; TaChart(C).Values[2] := 3; TaChart(C).Values[3] := 6;
    end;
    C.Invalidate;
  end;

  { colours and fonts }
  Fc := HexToColor(D.GetX('foreColor'), clDefault);
  Bc := HexToColor(D.GetX('backColor'), clDefault);
  Fn := D.GetX('fontName');
  Sz := StrToIntDef(D.GetX('fontSize'), 0);
  if (C is TLabel) or (C is TEdit) or (C is TMemo) or (C is TCustomButton) or (C is TCheckBox) or (C is TToggleBox) or
     (C is TComboBox) or (C is TListBox) or (C is TRadioGroup) or (C is TPageControl) then
  begin
    if Fn <> '' then C.Font.Name := Fn;
    if Sz > 0 then C.Font.Size := Sz;
    if D.Bold then C.Font.Style := C.Font.Style + [fsBold] else C.Font.Style := C.Font.Style - [fsBold];
    if D.GetX('italic') = '1' then C.Font.Style := C.Font.Style + [fsItalic]
    else C.Font.Style := C.Font.Style - [fsItalic];
    if (Fc <> clDefault) and not (C is TaHyperlink) then C.Font.Color := Fc;
    if (Bc <> clDefault) and not (C is TCustomButton) and not (C is TPageControl) then
    begin
      C.Color := Bc;
      if C is TLabel then TLabel(C).Transparent := False;
    end;
  end;
  if C is TShape then
  begin
    Bw := StrToIntDef(D.GetX('borderWidth'), 1);
    if C is TaRect then
    begin
      TShape(C).Shape := stRectangle;
      if Fc = clDefault then Fc := clBlack;
      TShape(C).Pen.Color := Fc;
      TShape(C).Pen.Width := Bw;
      if Bc = clDefault then TShape(C).Brush.Style := bsClear
      else begin TShape(C).Brush.Style := bsSolid; TShape(C).Brush.Color := Bc; end;
    end
    else
    begin
      TShape(C).Shape := stRectangle;
      if Fc = clDefault then Fc := clBlack;
      TShape(C).Brush.Color := Fc;
      TShape(C).Pen.Color := Fc;
      if C is TaPageBreak then
      begin
        TShape(C).Brush.Style := bsClear;
        TShape(C).Pen.Style := psDash;
        TShape(C).Pen.Color := clGray;
      end;
    end;
  end;
  if D.GetX('tip') <> '' then
  begin
    C.Hint := D.GetX('tip');
    C.ShowHint := True;
  end
  else C.ShowHint := False;
  C.SetBounds(D.Left, D.Top, D.Width, D.Height);
end;

{ ---------------- binding ---------------- }

function IsCalculated(C: TControl): Boolean;
var
  D: TaControlDef;
begin
  D := DefOf(C);
  Result := (D <> nil) and (D.ControlSource <> '') and (D.ControlSource[1] = '=');
end;

function IsBoundControl(C: TControl): Boolean;
var
  D: TaControlDef;
begin
  D := DefOf(C);
  Result := (D <> nil) and (D.ControlSource <> '') and (D.ControlSource[1] <> '=') and
    ((C is TEdit) or (C is TMemo) or (C is TaRichBase) or (C is TCheckBox) or (C is TToggleBox) or (C is TComboBox) or
     (C is TListBox) or (C is TRadioGroup) or (Assigned(FamilyBoundHook) and FamilyBoundHook(C)));
end;

function KeysOf(C: TControl): TStringList;
begin
  Result := nil;
  if C is TaComboBox then Result := TaComboBox(C).Keys
  else if C is TaListBox then Result := TaListBox(C).Keys
  else if C is TaOptionGroup then Result := TaOptionGroup(C).Keys;
end;

function ReadControlValue(C: TControl): string;
var
  K: TStringList;
  Idx: Integer;
begin
  Result := '';
  if Assigned(FamilyReadHook) and FamilyReadHook(C, Result) then Exit;
  if C is TCheckBox then
  begin
    if TCheckBox(C).Checked then Result := '1' else Result := '0';
  end
  else if C is TToggleBox then
  begin
    if TToggleBox(C).Checked then Result := '1' else Result := '0';
  end
  else if C is TEdit then Result := TEdit(C).Text
  else if C is TMemo then Result := TMemo(C).Text
  else if C is TaRichBase then Result := TaRichBase(C).Html
  else if (C is TComboBox) or (C is TListBox) or (C is TRadioGroup) then
  begin
    if (C is TaComboBox) and TaComboBox(C).Search then Exit(TaComboBox(C).CurrentKey);
    K := KeysOf(C);
    if C is TComboBox then Idx := TComboBox(C).ItemIndex
    else if C is TListBox then Idx := TListBox(C).ItemIndex
    else Idx := TRadioGroup(C).ItemIndex;
    if K <> nil then
    begin
      if (Idx >= 0) and (Idx < K.Count) then Result := K[Idx] else Result := '';
    end
    else if C is TComboBox then Result := TComboBox(C).Text
    else if (C is TListBox) and (Idx >= 0) then Result := TListBox(C).Items[Idx];
  end;
end;

procedure WriteControlValue(C: TControl; const S: string);
var
  K: TStringList;
  Idx: Integer;
begin
  if Assigned(FamilyWriteHook) and FamilyWriteHook(C, S) then Exit;
  if C is TCheckBox then
    TCheckBox(C).Checked := (S = '1') or SameText(S, 'true')
  else if C is TToggleBox then
    TToggleBox(C).Checked := (S = '1') or SameText(S, 'true')
  else if C is TEdit then TEdit(C).Text := S
  else if C is TMemo then TMemo(C).Text := S
  else if C is TaRichBase then TaRichBase(C).Html := S
  else if (C is TComboBox) or (C is TListBox) or (C is TRadioGroup) then
  begin
    if (C is TaComboBox) and TaComboBox(C).Search then
    begin
      TaComboBox(C).SelectKey(S);
      Exit;
    end;
    K := KeysOf(C);
    if K <> nil then Idx := K.IndexOf(S)
    else if C is TComboBox then Idx := TComboBox(C).Items.IndexOf(S)
    else if C is TListBox then Idx := TListBox(C).Items.IndexOf(S)
    else Idx := -1;
    if C is TComboBox then
    begin
      TComboBox(C).ItemIndex := Idx;
      if (Idx < 0) and (K = nil) then TComboBox(C).Text := S;
    end
    else if C is TListBox then TListBox(C).ItemIndex := Idx
    else TRadioGroup(C).ItemIndex := Idx;
  end;
end;

{ ---------------- property table ---------------- }

const
  Common: array[0..9] of string = (
    'Name', 'Tip', 'VisibleIf', 'EnabledIf', 'Locked', 'Container', 'Page',
    'Left', 'Top', 'Width');

{ varijante obitelji (izvrsitelj ih stvara kao komponente obitelji); prazno = vrsta nema varijanti }
function VariantsForKind(const AKind: string): string;
begin
  if AKind = 'TextBox' then Result := ',text,password,spin,date,currency'
  else if AKind = 'CheckBox' then Result := 'checkbox,switch,radio,tristate'
  else if AKind = 'Button' then Result := 'standard,default,cancel,flat,link,image,menu,split'
  else if AKind = 'Label' then Result := 'text,hyperlink,html,badge'
  else if AKind = 'MemoBox' then Result := 'plain,rich,markdown'
  else if AKind = 'OptionGroup' then Result := 'radio,check,segmented,multisegment'
  else if AKind = 'ListBox' then Result := 'list,checklist,iconlist,tree'
  else if AKind = 'ComboBox' then Result := 'combo,droplist'
  else if AKind = 'Calendar' then Result := 'month,range,agenda'
  else if AKind = 'Progress' then Result := 'bar,ring,led,busy'
  else if AKind = 'Pages' then Result := 'tabs,list,steps,accordion'
  else if AKind = 'Panel' then Result := 'plain,group,card,expander,scroll,splitter'
  else if AKind = 'Image' then Result := 'picture,shape,gradient,icon'
  else if AKind = 'Chart' then Result := 'bar,line,pie,gauge'
  else if AKind = 'Barcode' then Result := 'code128,ean13,ean8,code39,itf,qr,pdf417'
  else Result := '';
  if Copy(Result, 1, 1) = ',' then Result := Copy(Result, 2, MaxInt);
end;

function PropertyNamesFor(const AKind: string; AReport: Boolean): TStringList;
var
  I: Integer;
  Fonts, Geom: string;
begin
  Result := TStringList.Create;
  Result.Add('Name');
  if AKind = 'TextBox' then Result.CommaText := 'Name,ControlSource,Format,Align,Mask,Lov,LovMap,LovValidate'
  else if AKind = 'MemoBox' then Result.CommaText := 'Name,ControlSource,Preview'
  else if AKind = 'RichText' then Result.CommaText := 'Name,ControlSource'
  else if AKind = 'Label' then Result.CommaText := 'Name,Caption,Align'
  else if AKind = 'Hyperlink' then Result.CommaText := 'Name,Caption,ControlSource,RowSource,Align'
  else if AKind = 'SideMenu' then Result.CommaText := 'Name,Items,Accordion'
  else if AKind = 'Button' then Result.CommaText := 'Name,Caption,Icon,OnClick,MenuItems'
  else if AKind = 'CheckBox' then Result.CommaText := 'Name,Caption,ControlSource'
  else if AKind = 'ToggleButton' then Result.CommaText := 'Name,Caption,Icon,ControlSource,OnClick'
  else if AKind = 'ComboBox' then Result.CommaText := 'Name,ControlSource,RowSource,Search'
  else if AKind = 'ListBox' then Result.CommaText := 'Name,ControlSource,RowSource,MultiSelect'
  else if AKind = 'OptionGroup' then Result.CommaText := 'Name,Caption,ControlSource,RowSource,Columns,MinSelected,MaxSelected'
  else if AKind = 'Calendar' then Result.CommaText := 'Name,ControlSource,Days'
  else if AKind = 'Progress' then Result.CommaText := 'Name,ControlSource,Min,Max,WarnAt,DangerAt'
  else if AKind = 'Subform' then Result.CommaText := 'Name,RowSource,LinkMaster,LinkChild,CalcFields,AutoFill,CalcRules'
  else if AKind = 'TabControl' then Result.CommaText := 'Name,RowSource'
  else if AKind = 'Panel' then Result.CommaText := 'Name,Caption,Expanded,MinSize'
  else if AKind = 'Pages' then Result.CommaText := 'Name,RowSource,ActivePage'
  else if AKind = 'Image' then Result.CommaText := 'Name,ControlSource,Picture,SizeMode'
  else if AKind = 'Chart' then Result.CommaText := 'Name,Caption,RowSource,ChartType'
  else if AKind = 'Barcode' then Result.CommaText := 'Name,ControlSource,BarType,ShowText'
  else if AKind = 'Subreport' then Result.CommaText := 'Name,RowSource,LinkMaster,LinkChild'
  else if AKind = 'Rectangle' then Result.CommaText := 'Name,BorderWidth'
  else if (AKind = 'Line') or (AKind = 'PageBreak') then Result.CommaText := 'Name';
  { look }
  if (AKind <> 'Line') and (AKind <> 'PageBreak') and (AKind <> 'Image') and (AKind <> 'Chart') and (AKind <> 'Barcode') and (AKind <> 'Subreport') and
     (AKind <> 'Subform') and (AKind <> 'TabControl') and (AKind <> 'RichText') then
    Result.CommaText := Result.CommaText + ',FontName,FontSize,Bold,Italic';
  if (AKind <> 'Image') and (AKind <> 'RichText') then Result.CommaText := Result.CommaText + ',ForeColor,BackColor';
  if (AKind = 'TextBox') or (AKind = 'Label') or (AKind = 'MemoBox') or (AKind = 'ComboBox') then
    Result.CommaText := Result.CommaText + ',CondFormat';
  if AReport and (AKind = 'TextBox') then Result.CommaText := Result.CommaText + ',GrowLines';
  if not AReport then
  begin
    Result.CommaText := Result.CommaText + ',Tip,VisibleIf,EnabledIf,Locked,PropertyClass';
    if VariantsForKind(AKind) <> '' then Result.CommaText := Result.CommaText + ',Variant';
    if (AKind = 'TextBox') or (AKind = 'MemoBox') or (AKind = 'RichText') or (AKind = 'ComboBox') or (AKind = 'ListBox') or (AKind = 'OptionGroup') or
       (AKind = 'CheckBox') or (AKind = 'ToggleButton') then
      Result.CommaText := Result.CommaText + ',OnChange,OnEnter,OnExit,OnValidate,OnKey';
    if (AKind = 'TextBox') or (AKind = 'ListBox') or (AKind = 'Label') or (AKind = 'Image') then
      Result.CommaText := Result.CommaText + ',OnDblClick';
    if (AKind = 'Label') or (AKind = 'Image') or (AKind = 'Rectangle') then
      Result.CommaText := Result.CommaText + ',OnClick';
    if AKind <> 'TabControl' then Result.CommaText := Result.CommaText + ',Container,Page';
    if (AKind <> 'PageBreak') then Result.CommaText := Result.CommaText + ',Anchors,Dock,BorderSpacing,AnchorLeft,AnchorTop,AnchorRight,AnchorBottom';
  end;
  Result.CommaText := Result.CommaText + ',Left,Top,Width,Height';
  { a duplicate Name from the first Add }
  for I := Result.Count - 1 downto 1 do
    if Result.IndexOf(Result[I]) < I then Result.Delete(I);
  Fonts := ''; Geom := '';
end;

function IsExprProp(const AProp: string): Boolean;
begin
  Result := SameText(AProp, 'VisibleIf') or SameText(AProp, 'EnabledIf');
end;

function BoolStr(B: Boolean): string;
begin
  if B then Result := 'True' else Result := 'False';
end;

{ prihvaca slova (LTRB) ili rijeci (lijevo, gore, desno, dolje, left, top, right, bottom) }
function AnchorLetters(const AText: string): string;
var
  T: string;
  L, Tp, R, B: Boolean;
begin
  T := LowerCase(AText);
  L := (Pos('lijevo', T) > 0) or (Pos('left', T) > 0);
  Tp := (Pos('gore', T) > 0) or (Pos('top', T) > 0);
  R := (Pos('desno', T) > 0) or (Pos('right', T) > 0);
  B := (Pos('dolje', T) > 0) or (Pos('bottom', T) > 0);
  if not (L or Tp or R or B) then
  begin
    { slova }
    L := Pos('l', T) > 0; Tp := Pos('t', T) > 0; R := Pos('r', T) > 0; B := Pos('b', T) > 0;
  end;
  Result := '';
  if L then Result := Result + 'L';
  if Tp then Result := Result + 'T';
  if R then Result := Result + 'R';
  if B then Result := Result + 'B';
end;

function AnchorsDisplay(const ALetters: string): string;
var
  A: string;
begin
  A := ALetters;
  if A = '' then A := 'LT';
  Result := '';
  if Pos('L', A) > 0 then Result := Result + ', Lijevo';
  if Pos('T', A) > 0 then Result := Result + ', Gore';
  if Pos('R', A) > 0 then Result := Result + ', Desno';
  if Pos('B', A) > 0 then Result := Result + ', Dolje';
  if Result = '' then Result := '(nijedno)' else Delete(Result, 1, 2);
end;

function AnchorsOf(const ALetters: string): TAnchors;
begin
  Result := [];
  if Pos('L', ALetters) > 0 then Include(Result, akLeft);
  if Pos('T', ALetters) > 0 then Include(Result, akTop);
  if Pos('R', ALetters) > 0 then Include(Result, akRight);
  if Pos('B', ALetters) > 0 then Include(Result, akBottom);
end;

{ primjenjuje se tek kad je kontrola na svojem mjestu, da LCL zapamti razmak od ruba }
procedure ApplyAnchors(C: TControl; D: TaControlDef);
var
  A: string;
begin
  if (C = nil) or (D = nil) then Exit;
  A := D.GetX('anchors');
  if A = '' then Exit;
  C.Anchors := AnchorsOf(A);
end;

{ ---------------- raspored kontrola: Dock (Align), razmaci i sidra uz druge kontrole ---------------- }

const
  DockNames = 'none,top,bottom,left,right,client';

function DockOfDef(D: TaControlDef): TAlign;
var
  S: string;
begin
  S := LowerCase(Trim(D.GetX('dock')));
  if S = 'top' then Result := alTop
  else if S = 'bottom' then Result := alBottom
  else if S = 'left' then Result := alLeft
  else if S = 'right' then Result := alRight
  else if S = 'client' then Result := alClient
  else Result := alNone;
end;

{ "8" ili "8,4,8,4" (lijevo, gore, desno, dolje) u cetiri broja }
function ParseSpacing(const AText: string; out L, T, R, B: Integer): Boolean;
var
  P: TStringList;
begin
  L := 0; T := 0; R := 0; B := 0;
  Result := False;
  if Trim(AText) = '' then Exit;
  P := TStringList.Create;
  try
    P.Delimiter := ',';
    P.StrictDelimiter := True;
    P.DelimitedText := StringReplace(AText, ';', ',', [rfReplaceAll]);
    if P.Count = 1 then
    begin
      L := StrToIntDef(Trim(P[0]), 0); T := L; R := L; B := L;
    end
    else if P.Count >= 4 then
    begin
      L := StrToIntDef(Trim(P[0]), 0); T := StrToIntDef(Trim(P[1]), 0);
      R := StrToIntDef(Trim(P[2]), 0); B := StrToIntDef(Trim(P[3]), 0);
    end
    else Exit;
    Result := True;
  finally
    P.Free;
  end;
end;

function NormalizeSpacing(const AText: string): string;
var
  L, T, R, B: Integer;
begin
  if not ParseSpacing(AText, L, T, R, B) then Exit('');
  if (L = 0) and (T = 0) and (R = 0) and (B = 0) then Exit('');
  Result := Format('%d,%d,%d,%d', [L, T, R, B]);
end;

{ "Naziv:strana"; strana je left|center|right (vodoravno) ili top|center|bottom (okomito); '' = zadana }
procedure SplitAnchorSide(const AText: string; ADefaultSide: string; out AName: string; out ASide: TAnchorSideReference);
var
  P: Integer;
  S: string;
begin
  AName := Trim(AText);
  S := ADefaultSide;
  P := Pos(':', AName);
  if P > 0 then
  begin
    S := LowerCase(Trim(Copy(AName, P + 1, MaxInt)));
    AName := Trim(Copy(AName, 1, P - 1));
  end;
  if (S = 'left') or (S = 'top') then ASide := asrTop
  else if (S = 'right') or (S = 'bottom') then ASide := asrBottom
  else ASide := asrCenter;
end;

function IsParentName(const AName: string): Boolean;
begin
  Result := SameText(AName, 'forma') or SameText(AName, 'roditelj') or SameText(AName, 'parent') or SameText(AName, 'form');
end;

{ kontrola istog roditelja po nazivu iz definicije (za sidra uz susjeda) }
function SiblingByName(AParent: TWinControl; const AName: string): TControl;
var
  I: Integer;
  D: TaControlDef;
begin
  Result := nil;
  if AParent = nil then Exit;
  for I := 0 to AParent.ControlCount - 1 do
  begin
    D := DefOf(AParent.Controls[I]);
    if (D <> nil) and SameText(D.Name, AName) then Exit(AParent.Controls[I]);
  end;
end;

function HasLayoutProps(D: TaControlDef): Boolean;
begin
  Result := (D <> nil) and ((D.GetX('dock') <> '') or (D.GetX('space') <> '') or (D.GetX('asl') <> '') or
    (D.GetX('ast') <> '') or (D.GetX('asr') <> '') or (D.GetX('asb') <> '') or (D.GetX('anchors') <> ''));
end;

procedure ApplyControlLayout(C: TControl; D: TaControlDef);
var
  Sp: array[0..3] of Integer;
  An: TAnchors;
  Nm: string;
  Sd: TAnchorSideReference;
  Ref: TControl;

  { jedno sidro: Anchor je akLeft..akBottom, Spec tekst iz definicije }
  procedure OneSide(ASide: TAnchorKind; const ASpec, ADefaultSide: string);
  begin
    if ASpec = '' then Exit;
    SplitAnchorSide(ASpec, ADefaultSide, Nm, Sd);
    if IsParentName(Nm) then Ref := C.Parent
    else Ref := SiblingByName(C.Parent, Nm);
    if (Ref = nil) or (Ref = C) then Exit;
    Include(An, ASide);
    C.AnchorSide[ASide].Control := Ref;
    C.AnchorSide[ASide].Side := Sd;
  end;
begin
  if (C = nil) or (D = nil) then Exit;
  if ParseSpacing(D.GetX('space'), Sp[0], Sp[1], Sp[2], Sp[3]) then
  begin
    C.BorderSpacing.Left := Sp[0]; C.BorderSpacing.Top := Sp[1];
    C.BorderSpacing.Right := Sp[2]; C.BorderSpacing.Bottom := Sp[3];
  end;
  if DockOfDef(D) <> alNone then
  begin
    C.Align := DockOfDef(D);
    Exit;
  end;
  An := AnchorsOf(D.GetX('anchors'));
  if D.GetX('anchors') = '' then An := [akLeft, akTop];
  OneSide(akLeft, D.GetX('asl'), 'right');
  OneSide(akTop, D.GetX('ast'), 'bottom');
  OneSide(akRight, D.GetX('asr'), 'left');
  OneSide(akBottom, D.GetX('asb'), 'top');
  C.Anchors := An;
end;

procedure ClearLayout(C: TControl);
var
  K: TAnchorKind;
begin
  if C = nil then Exit;
  C.Align := alNone;
  C.Anchors := [akLeft, akTop];
  for K := Low(TAnchorKind) to High(TAnchorKind) do C.AnchorSide[K].Control := nil;
  C.BorderSpacing.Left := 0; C.BorderSpacing.Top := 0; C.BorderSpacing.Right := 0; C.BorderSpacing.Bottom := 0;
end;

function DefGet(D: TaControlDef; const AProp: string): string;
begin
  Result := '';
  if AProp = 'Anchors' then Exit(AnchorsDisplay(D.GetX('anchors')));
  if AProp = 'Dock' then begin Result := D.GetX('dock'); if Result = '' then Result := 'none'; Exit; end;
  if AProp = 'BorderSpacing' then Exit(D.GetX('space'));
  if AProp = 'AnchorLeft' then Exit(D.GetX('asl'));
  if AProp = 'AnchorTop' then Exit(D.GetX('ast'));
  if AProp = 'AnchorRight' then Exit(D.GetX('asr'));
  if AProp = 'AnchorBottom' then Exit(D.GetX('asb'));
  if AProp = 'Icon' then Exit(D.GetX('icon'));
  if AProp = 'Items' then Exit(StringReplace(StringReplace(D.RowSource, #13, '', [rfReplaceAll]), #10, ' / ', [rfReplaceAll]));
  if AProp = 'Name' then Result := D.Name
  else if AProp = 'Caption' then Result := D.Caption
  else if AProp = 'ControlSource' then Result := D.ControlSource
  else if AProp = 'RowSource' then Result := D.RowSource
  else if AProp = 'LinkMaster' then Result := D.LinkMaster
  else if AProp = 'LinkChild' then Result := D.LinkChild
  else if AProp = 'OnClick' then Result := D.OnClick
  else if AProp = 'Format' then Result := D.Format
  else if AProp = 'Align' then Result := D.Align
  else if AProp = 'Bold' then Result := BoolStr(D.Bold)
  else if AProp = 'Italic' then Result := BoolStr(D.GetX('italic') = '1')
  else if AProp = 'Locked' then Result := BoolStr(D.GetX('locked') = '1')
  else if AProp = 'Left' then Result := IntToStr(D.Left)
  else if AProp = 'Top' then Result := IntToStr(D.Top)
  else if AProp = 'Width' then Result := IntToStr(D.Width)
  else if AProp = 'Height' then Result := IntToStr(D.Height)
  else if AProp = 'Tip' then Result := D.GetX('tip')
  else if AProp = 'VisibleIf' then Result := D.GetX('visibleIf')
  else if AProp = 'EnabledIf' then Result := D.GetX('enabledIf')
  else if AProp = 'FontName' then Result := D.GetX('fontName')
  else if AProp = 'FontSize' then Result := D.GetX('fontSize')
  else if AProp = 'ForeColor' then Result := D.GetX('foreColor')
  else if AProp = 'BackColor' then Result := D.GetX('backColor')
  else if AProp = 'BorderWidth' then Result := D.GetX('borderWidth')
  else if AProp = 'CondFormat' then Result := D.GetX('condFormat')
  else if AProp = 'GrowLines' then Result := D.GetX('growLines')
  else if AProp = 'ChartType' then Result := D.GetX('chartType')
  else if AProp = 'Accordion' then Result := BoolStr(D.GetX('accordion') <> '0')
  else if AProp = 'Expanded' then Result := BoolStr(D.GetX('expanded') <> '0')
  else if AProp = 'MinSize' then Result := D.GetX('minSize')
  else if AProp = 'ActivePage' then Result := D.GetX('active')
  else if AProp = 'Mask' then Result := D.GetX('mask')
  else if AProp = 'Search' then Result := BoolStr(D.GetX('search') = '1')
  else if AProp = 'BarType' then Result := D.GetX('barType')
  else if AProp = 'ShowText' then Result := BoolStr(D.GetX('showText') <> '0')
  else if AProp = 'SizeMode' then Result := D.GetX('sizeMode')
  else if AProp = 'CalcFields' then Result := D.GetX('calc')
  else if AProp = 'AutoFill' then Result := D.GetX('autofill')
  else if AProp = 'CalcRules' then Result := D.GetX('calcrules')
  else if AProp = 'Variant' then Result := D.GetX('variant')
  else if AProp = 'Min' then Result := D.GetX('min')
  else if AProp = 'Max' then Result := D.GetX('max')
  else if AProp = 'WarnAt' then Result := D.GetX('warnAt')
  else if AProp = 'DangerAt' then Result := D.GetX('dangerAt')
  else if AProp = 'Days' then Result := D.GetX('days')
  else if AProp = 'MenuItems' then Result := D.GetX('menuItems')
  else if AProp = 'Columns' then Result := D.GetX('columns')
  else if AProp = 'MinSelected' then Result := D.GetX('minSelected')
  else if AProp = 'MaxSelected' then Result := D.GetX('maxSelected')
  else if AProp = 'MultiSelect' then Result := BoolStr(D.GetX('multiSelect') = '1')
  else if AProp = 'Preview' then Result := BoolStr(D.GetX('preview') = '1')
  else if AProp = 'PropertyClass' then Result := D.GetX('class')
  else if AProp = 'Lov' then Result := D.GetX('lov')
  else if AProp = 'LovMap' then Result := D.GetX('lovmap')
  else if AProp = 'LovValidate' then Result := BoolStr(D.GetX('lovvalidate') = '1')
  else if AProp = 'OnChange' then Result := D.GetX('onChange')
  else if AProp = 'OnEnter' then Result := D.GetX('onEnter')
  else if AProp = 'OnExit' then Result := D.GetX('onExit')
  else if AProp = 'OnValidate' then Result := D.GetX('onValidate')
  else if AProp = 'OnKey' then Result := D.GetX('onKey')
  else if AProp = 'OnDblClick' then Result := D.GetX('onDblClick')
  else if AProp = 'Container' then Result := D.GetX('container')
  else if AProp = 'Page' then Result := D.GetX('page')
  else if AProp = 'Picture' then
  begin
    if D.GetX('picture') <> '' then Result := '(umetnuta slika)';
  end;
end;

procedure DefSet(D: TaControlDef; const AProp, AValue: string);
var
  B64, An: string;
begin
  if AProp = 'Anchors' then
  begin
    An := AnchorLetters(AValue);
    if An = 'LT' then An := '';      { zadano: ne pamti se }
    D.SetX('anchors', An);
  end
  else if AProp = 'Dock' then
  begin
    An := LowerCase(Trim(AValue));
    if Pos(',' + An + ',', ',' + DockNames + ',') = 0 then An := '';
    if An = 'none' then An := '';
    D.SetX('dock', An);
  end
  else if AProp = 'BorderSpacing' then D.SetX('space', NormalizeSpacing(AValue))
  else if AProp = 'AnchorLeft' then D.SetX('asl', Trim(AValue))
  else if AProp = 'AnchorTop' then D.SetX('ast', Trim(AValue))
  else if AProp = 'AnchorRight' then D.SetX('asr', Trim(AValue))
  else if AProp = 'AnchorBottom' then D.SetX('asb', Trim(AValue))
  else if AProp = 'Icon' then D.SetX('icon', Trim(AValue))
  else if AProp = 'Items' then D.RowSource := AValue
  else if AProp = 'Name' then D.Name := AValue
  else if AProp = 'Caption' then D.Caption := AValue
  else if AProp = 'ControlSource' then D.ControlSource := AValue
  else if AProp = 'RowSource' then D.RowSource := AValue
  else if AProp = 'LinkMaster' then D.LinkMaster := AValue
  else if AProp = 'LinkChild' then D.LinkChild := AValue
  else if AProp = 'OnClick' then D.OnClick := AValue
  else if AProp = 'Format' then D.Format := AValue
  else if AProp = 'Align' then D.Align := LowerCase(AValue)
  else if AProp = 'Bold' then D.Bold := StrToBoolDef(AValue, D.Bold)
  else if AProp = 'Italic' then begin if StrToBoolDef(AValue, False) then D.SetX('italic', '1') else D.SetX('italic', ''); end
  else if AProp = 'GrowLines' then begin if StrToIntDef(Trim(AValue), 0) > 1 then D.SetX('growLines', IntToStr(StrToIntDef(Trim(AValue), 0))) else D.SetX('growLines', ''); end
  else if AProp = 'Locked' then begin if StrToBoolDef(AValue, False) then D.SetX('locked', '1') else D.SetX('locked', ''); end
  else if AProp = 'Left' then D.Left := StrToIntDef(AValue, D.Left)
  else if AProp = 'Top' then D.Top := StrToIntDef(AValue, D.Top)
  else if AProp = 'Width' then D.Width := StrToIntDef(AValue, D.Width)
  else if AProp = 'Height' then D.Height := StrToIntDef(AValue, D.Height)
  else if AProp = 'Tip' then D.SetX('tip', AValue)
  else if AProp = 'VisibleIf' then D.SetX('visibleIf', AValue)
  else if AProp = 'EnabledIf' then D.SetX('enabledIf', AValue)
  else if AProp = 'FontName' then D.SetX('fontName', AValue)
  else if AProp = 'FontSize' then D.SetX('fontSize', AValue)
  else if AProp = 'ForeColor' then D.SetX('foreColor', AValue)
  else if AProp = 'BackColor' then D.SetX('backColor', AValue)
  else if AProp = 'BorderWidth' then D.SetX('borderWidth', AValue)
  else if AProp = 'CondFormat' then D.SetX('condFormat', AValue)
  else if AProp = 'ChartType' then begin D.SetX('chartType', LowerCase(AValue)); D.SetX('variant', ''); end
  else if AProp = 'Accordion' then begin if StrToBoolDef(AValue, True) then D.SetX('accordion', '') else D.SetX('accordion', '0'); end
  else if AProp = 'Expanded' then begin if StrToBoolDef(AValue, True) then D.SetX('expanded', '') else D.SetX('expanded', '0'); end
  else if AProp = 'MinSize' then D.SetX('minSize', Trim(AValue))
  else if AProp = 'ActivePage' then D.SetX('active', Trim(AValue))
  else if AProp = 'Mask' then D.SetX('mask', AValue)
  else if AProp = 'Search' then begin if StrToBoolDef(AValue, False) then D.SetX('search', '1') else D.SetX('search', ''); end
  else if AProp = 'BarType' then begin D.SetX('barType', LowerCase(Trim(AValue))); D.SetX('variant', ''); end
  else if AProp = 'ShowText' then begin if StrToBoolDef(AValue, True) then D.SetX('showText', '1') else D.SetX('showText', '0'); end
  else if AProp = 'SizeMode' then D.SetX('sizeMode', LowerCase(AValue))
  else if AProp = 'CalcFields' then D.SetX('calc', AValue)
  else if AProp = 'AutoFill' then D.SetX('autofill', AValue)
  else if AProp = 'CalcRules' then D.SetX('calcrules', AValue)
  else if AProp = 'Variant' then
  begin
    D.SetX('variant', LowerCase(Trim(AValue)));
    { stari kljucevi vrste ostaju u skladu s varijantom (stare kontrole ih citaju) }
    if D.Kind = 'Chart' then D.SetX('chartType', LowerCase(Trim(AValue)))
    else if D.Kind = 'Barcode' then D.SetX('barType', LowerCase(Trim(AValue)));
  end
  else if AProp = 'Min' then D.SetX('min', Trim(AValue))
  else if AProp = 'Max' then D.SetX('max', Trim(AValue))
  else if AProp = 'WarnAt' then D.SetX('warnAt', Trim(AValue))
  else if AProp = 'DangerAt' then D.SetX('dangerAt', Trim(AValue))
  else if AProp = 'Days' then D.SetX('days', Trim(AValue))
  else if AProp = 'MenuItems' then D.SetX('menuItems', Trim(AValue))
  else if AProp = 'Columns' then D.SetX('columns', Trim(AValue))
  else if AProp = 'MinSelected' then D.SetX('minSelected', Trim(AValue))
  else if AProp = 'MaxSelected' then D.SetX('maxSelected', Trim(AValue))
  else if AProp = 'MultiSelect' then begin if StrToBoolDef(AValue, False) then D.SetX('multiSelect', '1') else D.SetX('multiSelect', ''); end
  else if AProp = 'Preview' then begin if StrToBoolDef(AValue, False) then D.SetX('preview', '1') else D.SetX('preview', ''); end
  else if AProp = 'PropertyClass' then D.SetX('class', Trim(AValue))
  else if AProp = 'Lov' then D.SetX('lov', AValue)
  else if AProp = 'LovMap' then D.SetX('lovmap', AValue)
  else if AProp = 'LovValidate' then begin if StrToBoolDef(AValue, False) then D.SetX('lovvalidate', '1') else D.SetX('lovvalidate', ''); end
  else if AProp = 'OnChange' then D.SetX('onChange', AValue)
  else if AProp = 'OnEnter' then D.SetX('onEnter', AValue)
  else if AProp = 'OnExit' then D.SetX('onExit', AValue)
  else if AProp = 'OnValidate' then D.SetX('onValidate', AValue)
  else if AProp = 'OnKey' then D.SetX('onKey', AValue)
  else if AProp = 'OnDblClick' then D.SetX('onDblClick', AValue)
  else if AProp = 'Container' then D.SetX('container', AValue)
  else if AProp = 'Page' then D.SetX('page', AValue)
  else if AProp = 'Picture' then
  begin
    if AValue = '' then D.SetX('picture', '')
    else if Copy(AValue, 1, 5) = 'icon:' then
    begin
      { ikona iz zalihe kao velika slika (128 tocaka); ":tamna" za tamnu izvedbu }
      B64 := Copy(AValue, 6, MaxInt);
      if Copy(B64, Length(B64) - 5, 6) = ':tamna' then
        D.SetX('picture', EncodeStringBase64(IconDataSvg(Copy(B64, 1, Length(B64) - 6), True)))
      else
        D.SetX('picture', EncodeStringBase64(IconDataSvg(B64, False)));
    end
    else if (LowerCase(ExtractFileExt(AValue)) = '.svg') and FileExists(AValue) then
    begin
      { vektor se pamti kao SVG tekst (malen); u PNG se crta tek pri prikazu }
      B64 := SvgFileToText(AValue);
      if B64 <> '' then D.SetX('picture', EncodeStringBase64(B64));
    end
    else if Copy(AValue, 1, 5) = 'file:' then D.SetX('picture', AValue)
    else if AValue[1] <> '(' then
    begin
      { slika ide u pohranu datoteka, u definiciji ostaje samo veza }
      if (ActiveStoreDb <> nil) and ActiveStoreDb.Connected and FileExists(AValue) then
        try
          D.SetX('picture', 'file:' + StoreFile(ActiveStoreDb, AValue, 'slike/_forme'));
          Exit;
        except
        end;
      B64 := PictureFileToBase64(AValue);
      if B64 <> '' then D.SetX('picture', B64);
    end;
  end;
end;

end.
