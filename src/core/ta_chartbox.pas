unit ta_chartbox;
{ Obitelj Chart: grafikon iz niza "natpis=vrijednost". Varijante: bar, line, pie (crta DrawChart iz ta_controls, kao u
  izvjescima) i gauge (mjerac, vlastito crtanje). Podaci su stavke (Items) ili skup podataka (DataSource uz
  LabelField i ValueField u Options). Plan: TAChart; zadano je vlastito crtanje, bez dodatnog paketa. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, Graphics, Variants, DB, ta_family, ta_formdef;

type
  TaChartVariant = (cvBar, cvLine, cvPie, cvGauge);
  TaChartValues = array of Double;

const
  ChartVariantNames: array[TaChartVariant] of string = ('bar', 'line', 'pie', 'gauge');
  ChartFamily = 'Chart';

type
  TaChartOptions = class(TPersistent)
  private
    FTitle, FLabelField, FValueField: string;
    FMax: Double;
  public
    procedure Assign(ASource: TPersistent); override;
  published
    property Title: string read FTitle write FTitle;
    { skup podataka: polje s natpisima i polje s vrijednostima }
    property LabelField: string read FLabelField write FLabelField;
    property ValueField: string read FValueField write FValueField;
    { gauge: najveca vrijednost (0 = 100) }
    property Max: Double read FMax write FMax;
  end;

  TaChartLink = class(TDataLink)
  private
    FOnRefresh: TNotifyEvent;
  protected
    procedure DataSetChanged; override;
    procedure ActiveChanged; override;
  public
    property OnRefresh: TNotifyEvent read FOnRefresh write FOnRefresh;
  end;

  TaChartPaint = class(TCustomControl)
  private
    FMode: TaChartVariant;
    FLabels: TStringList;
    FValues: array of Double;
    FTitle: string;
    FMaxV: Double;
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure RenderTo(C: TCanvas);
    procedure SetData(ALabels: TStrings; const AValues: array of Double);
    property Mode: TaChartVariant read FMode write FMode;
    property Title: string read FTitle write FTitle;
    property MaxValue: Double read FMaxV write FMaxV;
  end;

  { zajednicki dio pokretaca grafikona (LCL i neobavezni, npr. TAChart u paketu typhaccess_ext) }
  TaChartDataEngine = class(TaEngine)
  public
    procedure SetData(ALabels: TStrings; const AValues: array of Double); virtual; abstract;
  end;

  TaChartEngine = class(TaChartDataEngine)
  private
    FPaint: TaChartPaint;
    FItems: TStringList;
  protected
    function Mode: TaChartVariant; virtual;
  public
    constructor Create(AHost: TaFamilyHost); override;
    destructor Destroy; override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
    procedure SetItems(AItems: TStrings); override;
    procedure ApplyOptions(AOptions: TPersistent); override;
    procedure SetData(ALabels: TStrings; const AValues: array of Double); override;
    property Painter: TaChartPaint read FPaint;
  end;

  TaChartLineEngine = class(TaChartEngine)
  protected
    function Mode: TaChartVariant; override;
  end;

  TaChartPieEngine = class(TaChartEngine)
  protected
    function Mode: TaChartVariant; override;
  end;

  TaChartGaugeEngine = class(TaChartEngine)
  protected
    function Mode: TaChartVariant; override;
  end;

  TaChart = class(TaFamilyHost)
  private
    FVariant: TaChartVariant;
    FOptions: TaChartOptions;
    FItems: TStringList;
    FLink: TaChartLink;
    FVisibleIf, FEnabledIf, FExtra: string;
    FRefreshing: Boolean;
    function GetVariant: TaChartVariant;
    procedure SetVariant(AValue: TaChartVariant);
    function GetOptions: TaChartOptions;
    procedure SetOptions(AValue: TaChartOptions);
    procedure SetItemsList(AValue: TStrings);
    function GetItemsList: TStrings;
    procedure ItemsChanged(Sender: TObject);
    function GetDataSource: TDataSource;
    procedure SetDataSource(AValue: TDataSource);
    procedure Refresh(Sender: TObject);
    procedure RefreshData;
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
    function Painter: TaChartPaint;
  published
    property Variant: TaChartVariant read GetVariant write SetVariant default cvBar;
    { retci "natpis=vrijednost" }
    property Items: TStrings read GetItemsList write SetItemsList;
    property Options: TaChartOptions read GetOptions write SetOptions;
    property DataSource: TDataSource read GetDataSource write SetDataSource;
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
  end;

{ retci "natpis=vrijednost" -> natpisi i vrijednosti (koriste ga svi pokretaci grafikona) }
procedure ParseChartItems(AItems: TStrings; ALabels: TStrings; out AValues: TaChartValues);
function IsChartKind(const AKind: string): Boolean;
function ChartVariantFromName(const AName: string; ADefault: TaChartVariant = cvBar): TaChartVariant;
function ChartFromDef(D: TaControlDef; AOwner: TComponent): TaChart;
procedure ChartToDef(C: TaChart; D: TaControlDef);
function ChartToLfm(C: TaChart): string;
function ChartFromLfm(const ALfm: string; AOwner: TComponent): TaChart;

implementation

uses
  StrUtils, Math, LResources, ta_tokens, ta_controls;

function IsChartKind(const AKind: string): Boolean;
begin
  Result := SameText(AKind, 'Chart');
end;

function ChartVariantFromName(const AName: string; ADefault: TaChartVariant): TaChartVariant;
var
  V: TaChartVariant;
begin
  for V := Low(TaChartVariant) to High(TaChartVariant) do
    if SameText(ChartVariantNames[V], AName) then Exit(V);
  { stari nazivi vrsta grafikona }
  if SameText(AName, 'pita') then Exit(cvPie);
  if SameText(AName, 'linija') then Exit(cvLine);
  Result := ADefault;
end;

procedure TaChartOptions.Assign(ASource: TPersistent);
begin
  if ASource is TaChartOptions then
  begin
    FTitle := TaChartOptions(ASource).FTitle;
    FLabelField := TaChartOptions(ASource).FLabelField;
    FValueField := TaChartOptions(ASource).FValueField;
    FMax := TaChartOptions(ASource).FMax;
  end
  else inherited Assign(ASource);
end;

procedure TaChartLink.DataSetChanged;
begin
  inherited DataSetChanged;
  if Assigned(FOnRefresh) then FOnRefresh(Self);
end;

procedure TaChartLink.ActiveChanged;
begin
  inherited ActiveChanged;
  if Assigned(FOnRefresh) then FOnRefresh(Self);
end;

{ ---------------- crtanje ---------------- }

constructor TaChartPaint.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BorderStyle := bsNone;      { Qt: bez okvira QAbstractScrollArea koji tema crta kao polje }
  FLabels := TStringList.Create;
  Width := 240;
  Height := 160;
end;

destructor TaChartPaint.Destroy;
begin
  FLabels.Free;
  inherited Destroy;
end;

procedure TaChartPaint.SetData(ALabels: TStrings; const AValues: array of Double);
var
  I: Integer;
begin
  FLabels.Assign(ALabels);
  SetLength(FValues, Length(AValues));
  for I := 0 to High(AValues) do FValues[I] := AValues[I];
  Invalidate;
end;

procedure TaChartPaint.Paint;
begin
  RenderTo(Canvas);
end;

procedure TaChartPaint.RenderTo(C: TCanvas);
var
  T: TaThemeTokens;
  Cx, Cy, Rad, Th, Tw: Integer;
  Mx, F, V: Double;
  S: string;
begin
  T := ActiveTokens;
  C.Brush.Color := TokenColor(T.Surface);
  C.FillRect(0, 0, Width, Height);
  case FMode of
    cvGauge:
      begin
        V := 0;
        if Length(FValues) > 0 then V := FValues[0];
        Mx := FMaxV;
        if Mx <= 0 then Mx := 100;
        F := V / Mx;
        if F < 0 then F := 0;
        if F > 1 then F := 1;
        Rad := Min(Width div 2, Height) - 8;
        Cx := Width div 2;
        Cy := Height - 12;
        C.Pen.Width := Max(6, Rad div 5);
        C.Pen.Color := TokenColor(T.Soft);
        C.Brush.Style := bsClear;
        C.Arc(Cx - Rad, Cy - Rad, Cx + Rad, Cy + Rad, Cx + Rad, Cy, Cx - Rad, Cy);
        if F > 0 then
        begin
          C.Pen.Color := TokenColor(T.Accent);
          C.Arc(Cx - Rad, Cy - Rad, Cx + Rad, Cy + Rad,
            Cx - Round(Rad * Cos(Pi * F)), Cy - Round(Rad * Sin(Pi * F)), Cx - Rad, Cy);
        end;
        C.Pen.Width := 1;
        S := FloatToStrF(V, ffGeneral, 6, 0);
        C.Font.Size := 14;
        C.Font.Style := [fsBold];
        C.Font.Color := TokenColor(T.Text);
        Tw := C.TextWidth(S);
        Th := C.TextHeight(S);
        C.TextOut(Cx - Tw div 2, Cy - Th - 4, S);
        C.Font.Size := 0;
        C.Font.Style := [];
        if FTitle <> '' then C.TextOut(4, 2, FTitle);
      end;
  else
    begin
      C.Font.Color := TokenColor(T.Text);
      DrawChart(C, Rect(0, 0, Width, Height), FLabels, FValues, ChartVariantNames[FMode], FTitle);
    end;
  end;
  C.Brush.Style := bsSolid;
end;

{ ---------------- pokretaci ---------------- }

constructor TaChartEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FItems := TStringList.Create;
  FPaint := TaChartPaint.Create(nil);
  FPaint.Mode := Mode;
  AttachInner(FPaint);
end;

destructor TaChartEngine.Destroy;
begin
  FItems.Free;
  inherited Destroy;
end;

function TaChartEngine.Mode: TaChartVariant;
begin
  Result := cvBar;
end;

function TaChartLineEngine.Mode: TaChartVariant;
begin
  Result := cvLine;
end;

function TaChartPieEngine.Mode: TaChartVariant;
begin
  Result := cvPie;
end;

function TaChartGaugeEngine.Mode: TaChartVariant;
begin
  Result := cvGauge;
end;

function TaChartEngine.GetText: string;
begin
  Result := FPaint.Title;
end;

procedure TaChartEngine.SetText(const AValue: string);
begin
  FPaint.Title := AValue;
  FPaint.Invalidate;
end;

procedure ParseChartItems(AItems: TStrings; ALabels: TStrings; out AValues: TaChartValues);
var
  I, P: Integer;
  S: string;
begin
  ALabels.Clear;
  SetLength(AValues, AItems.Count);
  for I := 0 to AItems.Count - 1 do
  begin
    S := AItems[I];
    P := LastDelimiter('=', S);
    if P > 0 then
    begin
      ALabels.Add(Trim(Copy(S, 1, P - 1)));
      AValues[I] := StrToFloatDef(Trim(Copy(S, P + 1, MaxInt)), 0, DefaultFormatSettings);
    end
    else
    begin
      ALabels.Add(Trim(S));
      AValues[I] := 0;
    end;
  end;
end;

procedure TaChartEngine.SetItems(AItems: TStrings);
var
  Lb: TStringList;
  Vals: TaChartValues;
begin
  Lb := TStringList.Create;
  try
    ParseChartItems(AItems, Lb, Vals);
    FPaint.SetData(Lb, Vals);
  finally
    Lb.Free;
  end;
end;

procedure TaChartEngine.SetData(ALabels: TStrings; const AValues: array of Double);
begin
  FPaint.SetData(ALabels, AValues);
end;

procedure TaChartEngine.ApplyOptions(AOptions: TPersistent);
begin
  if AOptions is TaChartOptions then
  begin
    FPaint.Title := TaChartOptions(AOptions).Title;
    FPaint.MaxValue := TaChartOptions(AOptions).Max;
    FPaint.Invalidate;
  end;
end;

{ ---------------- TaChart ---------------- }

constructor TaChart.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FItems := TStringList.Create;
  FItems.OnChange := @ItemsChanged;
  FLink := TaChartLink.Create;
  FLink.OnRefresh := @Refresh;
  FOptions := TaChartOptions.Create;
  FVariant := cvBar;
  Width := 240;
  Height := 160;
  ReplaceEngine;
  PushToEngine;
end;

destructor TaChart.Destroy;
begin
  FLink.OnRefresh := nil;
  FLink.Free;
  FOptions.Free;
  FItems.Free;
  inherited Destroy;
end;

function TaChart.CreateEngine: TaEngine;
var
  C: TaEngineClass;
begin
  C := FindEngine(ChartFamily, ChartVariantNames[FVariant]);
  if C = nil then C := FindEngine(ChartFamily, 'bar');
  Result := C.Create(Self);
end;

function TaChart.VariantName: string;
begin
  Result := ChartVariantNames[FVariant];
end;

function TaChart.Painter: TaChartPaint;
begin
  if Engine is TaChartEngine then Result := TaChartEngine(Engine).Painter else Result := nil;
end;

function TaChart.GetVariant: TaChartVariant;
begin
  Result := FVariant;
end;

procedure TaChart.SetVariant(AValue: TaChartVariant);
begin
  if AValue = FVariant then Exit;
  FVariant := AValue;
  ReplaceEngine;
  PushToEngine;
end;

function TaChart.GetOptions: TaChartOptions;
begin
  Result := FOptions;
end;

procedure TaChart.SetOptions(AValue: TaChartOptions);
begin
  FOptions.Assign(AValue);
  if Engine <> nil then Engine.ApplyOptions(FOptions);
  Refresh(nil);
end;

procedure TaChart.SetItemsList(AValue: TStrings);
begin
  FItems.Assign(AValue);
end;

function TaChart.GetItemsList: TStrings;
begin
  Result := FItems;
end;

procedure TaChart.ItemsChanged(Sender: TObject);
begin
  if (Engine <> nil) and not (csLoading in ComponentState) then Refresh(nil);
end;

procedure TaChart.PushToEngine;
begin
  if Engine = nil then Exit;
  Engine.ApplyOptions(FOptions);
  Refresh(nil);
end;

{ podaci iz skupa podataka ako je izvor i oba polja zadani, inace stavke }
procedure TaChart.Refresh(Sender: TObject);
var
  Ds: TDataSet;
  Lb: TStringList;
  Vals: array of Double;
  N: Integer;
  Fl, Fv: TField;
  Bm: TBookmark;
begin
  if (Engine = nil) or FRefreshing then Exit;
  FRefreshing := True;
  try
    RefreshData;
  finally
    FRefreshing := False;
  end;
end;

procedure TaChart.RefreshData;
var
  Ds: TDataSet;
  Lb: TStringList;
  Vals: array of Double;
  N: Integer;
  Fl, Fv: TField;
  Bm: TBookmark;
begin
  Ds := nil;
  if FLink.Active then Ds := FLink.DataSet;
  if (Ds <> nil) and (FOptions.LabelField <> '') and (FOptions.ValueField <> '') then
  begin
    Fl := Ds.FindField(FOptions.LabelField);
    Fv := Ds.FindField(FOptions.ValueField);
    if (Fl <> nil) and (Fv <> nil) then
    begin
      Lb := TStringList.Create;
      try
        N := 0;
        Ds.DisableControls;
        Bm := Ds.GetBookmark;
        try
          Ds.First;
          while not Ds.EOF do
          begin
            Lb.Add(Fl.AsString);
            SetLength(Vals, N + 1);
            Vals[N] := Fv.AsFloat;
            Inc(N);
            Ds.Next;
          end;
          try Ds.GotoBookmark(Bm); except end;
        finally
          Ds.FreeBookmark(Bm);
          Ds.EnableControls;
        end;
        if Engine is TaChartDataEngine then TaChartDataEngine(Engine).SetData(Lb, Vals);
      finally
        Lb.Free;
      end;
      Exit;
    end;
  end;
  Engine.SetItems(FItems);
end;

function TaChart.GetDataSource: TDataSource;
begin
  Result := FLink.DataSource;
end;

procedure TaChart.SetDataSource(AValue: TDataSource);
begin
  FLink.DataSource := AValue;
  if AValue <> nil then AValue.FreeNotification(Self);
  Refresh(nil);
end;

function TaChart.RealGetText: TCaption;
begin
  Result := FOptions.Title;
end;

procedure TaChart.RealSetText(const AValue: TCaption);
begin
  FOptions.Title := AValue;
  if Engine <> nil then Engine.SetText(AValue);
end;

procedure TaChart.Notification(AComponent: TComponent; AOperation: TOperation);
begin
  inherited Notification(AComponent, AOperation);
  if (AOperation = opRemove) and (FLink <> nil) and (AComponent = FLink.DataSource) then
    FLink.DataSource := nil;
end;

procedure TaChart.Loaded;
begin
  inherited Loaded;
  PushToEngine;
end;

{ ---------------- definicija kontrole <-> komponenta ---------------- }

const
  OwnKeys = ',variant,visibleIf,enabledIf,labelField,valueField,max,chartType,items,';

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

function ChartFromDef(D: TaControlDef; AOwner: TComponent): TaChart;
var
  L: TStringList;
  S: string;
begin
  Result := TaChart.Create(AOwner);
  try
    Result.Name := D.Name;
    Result.SetBounds(D.Left, D.Top, D.Width, D.Height);
    S := D.GetX('variant');
    if S = '' then S := D.GetX('chartType');
    Result.Variant := ChartVariantFromName(S, cvBar);
    Result.VisibleIf := D.GetX('visibleIf');
    Result.EnabledIf := D.GetX('enabledIf');
    Result.Options.Title := D.Caption;
    Result.Options.LabelField := D.GetX('labelField');
    Result.Options.ValueField := D.GetX('valueField');
    Result.Options.Max := StrToFloatDef(D.GetX('max'), 0, DefaultFormatSettings);
    Result.Options := Result.Options;
    L := TStringList.Create;
    try
      S := D.GetX('items');
      if S <> '' then
      begin
        L.Delimiter := ';';
        L.StrictDelimiter := True;
        L.DelimitedText := S;
      end;
      Result.Items.Assign(L);
    finally
      L.Free;
    end;
    Result.Extra := ExtraWithout(D.Extra);
  except
    Result.Free;
    raise;
  end;
end;

procedure ChartToDef(C: TaChart; D: TaControlDef);
var
  I: Integer;
  S: string;
begin
  D.Kind := 'Chart';
  D.Name := C.Name;
  D.Left := C.Left; D.Top := C.Top; D.Width := C.Width; D.Height := C.Height;
  D.Caption := C.Options.Title;
  D.Extra := C.Extra;
  D.SetX('variant', IfThen(C.Variant = cvBar, '', C.VariantName));
  D.SetX('visibleIf', C.VisibleIf);
  D.SetX('enabledIf', C.EnabledIf);
  D.SetX('labelField', C.Options.LabelField);
  D.SetX('valueField', C.Options.ValueField);
  D.SetX('max', IfThen(C.Options.Max > 0, FloatToStr(C.Options.Max, DefaultFormatSettings), ''));
  S := '';
  for I := 0 to C.Items.Count - 1 do
  begin
    if S <> '' then S := S + ';';
    S := S + C.Items[I];
  end;
  D.SetX('items', S);
end;

function ChartToLfm(C: TaChart): string;
var
  M: TMemoryStream;
  L: TStringList;
begin
  M := TMemoryStream.Create;
  L := TStringList.Create;
  try
    WriteComponentAsTextToStream(M, C);
    M.Position := 0;
    L.LoadFromStream(M);
    Result := L.Text;
  finally
    L.Free;
    M.Free;
  end;
end;

type
  TChartLfmFinder = class
    procedure Find(Reader: TReader; const AClassName: string; var AClass: TComponentClass);
  end;

procedure TChartLfmFinder.Find(Reader: TReader; const AClassName: string; var AClass: TComponentClass);
begin
  if SameText(AClassName, 'TaChart') then AClass := ta_chartbox.TaChart;
end;

function ChartFromLfm(const ALfm: string; AOwner: TComponent): TaChart;
var
  M: TMemoryStream;
  C: TComponent;
  F: TChartLfmFinder;
begin
  M := TMemoryStream.Create;
  try
    if ALfm <> '' then M.WriteBuffer(ALfm[1], Length(ALfm));
    M.Position := 0;
    C := nil;
    F := TChartLfmFinder.Create;
    try
      ReadComponentFromTextStream(M, C, @F.Find, AOwner);
    finally
      F.Free;
    end;
    Result := C as ta_chartbox.TaChart;
  finally
    M.Free;
  end;
end;

initialization
  RegisterClass(ta_chartbox.TaChart);
  RegisterEngine(ChartFamily, 'bar', TaChartEngine);
  RegisterEngine(ChartFamily, 'line', TaChartLineEngine);
  RegisterEngine(ChartFamily, 'pie', TaChartPieEngine);
  RegisterEngine(ChartFamily, 'gauge', TaChartGaugeEngine);

end.
