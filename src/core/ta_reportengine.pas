unit ta_reportengine;
{ Report engine: runs the record source, walks groups and details and lays the
  bands out onto A4 pages (96 dpi units). Output is a device independent list
  of text/line items that the preview, HTML and PDF exporters all draw. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, contnrs, Variants, DB, ZDataset, ta_meta, ta_formdef,
  ta_reportdef, ta_expr, ta_source, ta_types, ta_exprdb, ta_controls, ta_barcode, ta_condfmt, ta_filestore, ta_richtext, ta_svg, base64, Math, Graphics;

const
  DefPageW = 794;
  DefPageH = 1123;
  DefPageMargin = 40;

type
  { One drawable thing on a page. Kind: Text, Line (filled bar), Frame
    (rectangle, optional fill), Image. Colours are LCL TColor values. }
  TaRItem = class
  public
    Kind, Text, Align, Src, Fmt, Address: string;
    FontName: string;      { prazno = zadani font; dopisi traze 'DejaVu Sans' radi jednake sirine u pregledu i PDF-u }
    PicBytes: string;
    Bold, Italic, Underline, Deferred, Mono: Boolean;
    X, Y, W, H, PageNo, Border, FontPx: Integer;
    Color, Fill: Integer;
    constructor Create;
  end;

  TaRPage = class
  public
    Items: TFPObjectList;
    constructor Create;
    destructor Destroy; override;
  end;

  TaRenderedReport = class
  public
    Pages: TFPObjectList;
    PageW, PageH: Integer;      { velicina stranice u pikselima; zadano A4 }
    constructor Create;
    destructor Destroy; override;
    function PageCount: Integer;
    function Page(I: Integer): TaRPage;
  end;

  { TaReportEngine }

  { prikaz jednog podizvjesca za jednu vrijednost veze: stavke i potrebna visina }
  TaSubResult = class
  public
    Items: TFPObjectList;
    Height: Integer;
    Truncated: Boolean;
    constructor Create;
    destructor Destroy; override;
  end;

  TaReportEngine = class(TaExprHost)
  private
    FSubCache: TStringList;
    FDb: TAppDb;
    FDef: TaReportDef;
    FNames: TStringList;
    FMetas: TFPObjectList;
    FRows: array of array of Variant;
    FRowCount: Integer;
    FCur, FScopeA, FScopeB, FGroupStart, FGroupEnd: Integer;
    FPageNo, FPageCount: Integer;
    FGroupPageV, FGroupPagesV, FPageGroup: Integer;     { stranica unutar grupe i broj stranica grupe (drugi prolaz) }
    FPageGroups: array of Integer;          { za svaku stranicu: pocetni redak grupe koja je na njoj }
    FResult: TaRenderedReport;
    FPage: TaRPage;
    FY, FContentTop, FContentBottom: Integer;
    FPendingBreak: Boolean;
    FXOff, FDetailIdx: Integer;
    procedure LoadRows;
    procedure SetScope(ACur, AFrom, ATo: Integer);
    function Resolve(const ASrc: string; AIsField: Boolean; const AFmt: string): string;
    procedure EmitItems(ASec, ATop: Integer);
    procedure EmitChart(D: TaControlDef; ATop: Integer);
    procedure EmitBarcode(D: TaControlDef; ATop: Integer);
    function SubResult(D: TaControlDef): TaSubResult;
    function RichResult(D: TaControlDef): TaSubResult;
    function IsGrowText(D: TaControlDef): Boolean;
    function GrowResult(D: TaControlDef): TaSubResult;
    function ExtraOf(D: TaControlDef): Integer;
    function SubExtra(ASec: Integer): Integer;
    function ShiftFor(D: TaControlDef): Integer;
    procedure EmitSubreport(D: TaControlDef; ATop: Integer);
    function NewItem(D: TaControlDef; ATop: Integer): TaRItem;
    function SectionBreak(ASec: Integer; AAtTop: Boolean): Boolean;
    function ImageBytes(D: TaControlDef): string;
    procedure PlaceSection(ASec, ACur, AFrom, ATo: Integer);
    procedure PlaceDetail(ARow: Integer);
    procedure StartPage(AFirst: Boolean);
    procedure FinishPage;
    function GroupEnd(AStart: Integer; const AGroupIdx: Integer): Integer;
  public
    { ako je postavljeno, zamjenjuje SortBy izvjesca (odabir ponudenog poretka pri ispisu) }
    SortOverride: string;
    constructor Create(ADb: TAppDb; ADef: TaReportDef);
    destructor Destroy; override;
    function Render: TaRenderedReport;
    function FieldValue(const AName: string): Variant; override;
    function Aggregate(const AFunc, AField: string): Variant; override;
    function Variable(const AName: string): Variant; override;
    function Domain(const AFunc, AExpr, ADomain, ACriteria: string): Variant; override;
  end;

implementation

uses
  ta_i18n;


constructor TaRItem.Create;
begin
  Color := 0;
  Fill := -1;
  Border := 1;
end;

{ TaRPage / TaRenderedReport }

constructor TaRPage.Create;
begin
  Items := TFPObjectList.Create(True);
end;

destructor TaRPage.Destroy;
begin
  Items.Free;
  inherited Destroy;
end;

constructor TaRenderedReport.Create;
begin
  Pages := TFPObjectList.Create(True);
  PageW := DefPageW;
  PageH := DefPageH;
end;

destructor TaRenderedReport.Destroy;
begin
  Pages.Free;
  inherited Destroy;
end;

function TaRenderedReport.PageCount: Integer;
begin
  Result := Pages.Count;
end;

function TaRenderedReport.Page(I: Integer): TaRPage;
begin
  Result := TaRPage(Pages[I]);
end;

{ TaReportEngine }

constructor TaReportEngine.Create(ADb: TAppDb; ADef: TaReportDef);
begin
  FDb := ADb;
  ActiveDb := ADb;
  FDef := ADef;
  FNames := TStringList.Create;
  FMetas := TFPObjectList.Create(True);
  FCur := -1;
end;

constructor TaSubResult.Create;
begin
  Items := TFPObjectList.Create(True);
end;

destructor TaSubResult.Destroy;
begin
  Items.Free;
  inherited Destroy;
end;

destructor TaReportEngine.Destroy;
var
  I: Integer;
begin
  if FSubCache <> nil then
  begin
    for I := 0 to FSubCache.Count - 1 do FSubCache.Objects[I].Free;
    FSubCache.Free;
  end;
  FMetas.Free;
  FNames.Free;
  inherited Destroy;
end;

procedure TaReportEngine.LoadRows;
var
  Q: TDataSet;
  Order, Sql, SrcErr: string;
  Prefixed: Boolean;
  I, N: Integer;
begin
  FRowCount := 0;
  SetLength(FRows, 0);
  FNames.Clear;
  if FDef.RecordSource = '' then Exit;
  Order := '';
  if FDef.GroupField <> '' then Order := FDb.QuoteId(FDef.GroupField);
  if Trim(SortOverride) <> '' then
  begin
    if Order <> '' then Order := Order + ', ';
    Order := Order + Trim(SortOverride);
  end
  else if Trim(FDef.SortBy) <> '' then
  begin
    if Order <> '' then Order := Order + ', ';
    Order := Order + Trim(FDef.SortBy);
  end;
  { izvor s prefiksom (fgl:, list:, sql:): retke daje izvor; filter i poredak izvora su stvar programa }
  Prefixed := (Copy(LowerCase(TrimLeft(FDef.RecordSource)), 1, 4) = 'fgl:') or
    (Copy(LowerCase(TrimLeft(FDef.RecordSource)), 1, 5) = 'list:') or
    (Copy(LowerCase(TrimLeft(FDef.RecordSource)), 1, 4) = 'sql:');
  if (not Prefixed) and (FDb.LoadObject('_sys_queries', FDef.RecordSource) = '') then
  begin
    FMetas.Free;
    FMetas := FDb.LoadFieldMetas(FDef.RecordSource);
  end;
  if Prefixed then
  begin
    Q := OpenSource(FDb, FDef.RecordSource, nil, nil, SrcErr);
    if Q = nil then raise Exception.Create(Tr('Report source: ') + SrcErr);
  end
  else
  begin
    Sql := 'SELECT * FROM ' + FDb.SourceFrom(FDef.RecordSource);
    if Trim(FDef.Filter) <> '' then Sql := Sql + ' WHERE (' + Trim(FDef.Filter) + ')';
    if Order <> '' then Sql := Sql + ' ORDER BY ' + Order;
    Q := FDb.NewQuery(Sql);
    Q.Open;
  end;
  try
    for I := 0 to Q.FieldCount - 1 do FNames.Add(LowerCase(Q.Fields[I].FieldName));
    N := 0;
    while not Q.EOF do
    begin
      SetLength(FRows, N + 1);
      SetLength(FRows[N], Q.FieldCount);
      for I := 0 to Q.FieldCount - 1 do
        if Q.Fields[I].IsNull then FRows[N][I] := Null
        else if Q.Fields[I].DataType in [ftBCD, ftFMTBcd, ftCurrency] then
          FRows[N][I] := Q.Fields[I].AsFloat   { numeric iz Postgresa: kao broj, ne kao BCD }
        else FRows[N][I] := Q.Fields[I].AsVariant;
      Inc(N);
      Q.Next;
    end;
    FRowCount := N;
  finally
    Q.Free;
  end;
end;

procedure TaReportEngine.SetScope(ACur, AFrom, ATo: Integer);
begin
  FCur := ACur;
  FScopeA := AFrom;
  FScopeB := ATo;
end;

function TaReportEngine.FieldValue(const AName: string): Variant;
var
  Idx: Integer;
begin
  Idx := FNames.IndexOf(LowerCase(AName));
  if (Idx < 0) or (FCur < 0) or (FCur >= FRowCount) then Result := Null
  else Result := FRows[FCur][Idx];
end;

function TaReportEngine.Aggregate(const AFunc, AField: string): Variant;
var
  Idx, R, A, B, Cnt, I, J: Integer;
  Fn: string;
  Vals: array of Double;
  Sum, Mean, Acc, T: Double;
  FirstV, LastV, Cur: Variant;
  IsExpr: Boolean;
  SavedCur: Integer;
  ExprErr: string;
begin
  Fn := LowerCase(AFunc);
  A := FScopeA; B := FScopeB;
  { scope variants }
  if (Fn = 'sumall') or (Fn = 'countall') or (Fn = 'avgall') then
  begin
    A := 0; B := FRowCount - 1;
    Fn := Copy(Fn, 1, Length(Fn) - 3);
  end
  else if (Fn = 'runsum') or (Fn = 'runcount') then
  begin
    A := 0; B := FCur;
    Fn := Copy(Fn, 4, MaxInt);
  end
  else if Fn = 'rungsum' then
  begin
    A := FGroupStart; B := FCur;
    Fn := 'sum';
  end
  else if Fn = 'rungcount' then
  begin
    { redni broj retka unutar grupe: RunGCount(*) }
    A := FGroupStart; B := FCur;
    Fn := 'count';
  end;
  if A < 0 then A := 0;
  if B > FRowCount - 1 then B := FRowCount - 1;
  Cnt := 0;
  SetLength(Vals, 0);
  FirstV := Null; LastV := Null;
  Idx := FNames.IndexOf(LowerCase(AField));
  IsExpr := (AField <> '') and (AField[1] = '=');
  SavedCur := FCur;
  try
    for R := A to B do
    begin
      if AField = '*' then begin Inc(Cnt); Continue; end;
      if IsExpr then
      begin
        { izraz po retku, npr. Sum(Iif([placeno] = 1, [iznos], 0)) }
        FCur := R;
        try
          Cur := EvalExprEx(Copy(AField, 2, MaxInt), Self, ExprErr);
          if ExprErr <> '' then Cur := Null;
        except
          Cur := Null;
        end;
      end
      else
      begin
        if Idx < 0 then Continue;
        Cur := FRows[R][Idx];
      end;
      if VarIsNull(Cur) then Continue;
      if VarIsNull(FirstV) then FirstV := Cur;
      LastV := Cur;
      Inc(Cnt);
      if VarIsNumeric(Cur) then
      begin
        SetLength(Vals, Length(Vals) + 1);
        Vals[High(Vals)] := Double(Cur);
      end;
    end;
  finally
    FCur := SavedCur;
  end;
  if Fn = 'count' then Exit(Cnt);
  if Fn = 'first' then Exit(FirstV);
  if Fn = 'last' then Exit(LastV);
  if Length(Vals) = 0 then Exit(Null);
  Sum := 0;
  for I := 0 to High(Vals) do Sum := Sum + Vals[I];
  Mean := Sum / Length(Vals);
  if Fn = 'sum' then Exit(Sum);
  if Fn = 'avg' then Exit(Mean);
  if Fn = 'min' then
  begin
    T := Vals[0];
    for I := 1 to High(Vals) do if Vals[I] < T then T := Vals[I];
    Exit(T);
  end;
  if Fn = 'max' then
  begin
    T := Vals[0];
    for I := 1 to High(Vals) do if Vals[I] > T then T := Vals[I];
    Exit(T);
  end;
  if (Fn = 'stdev') or (Fn = 'var') then
  begin
    if Length(Vals) < 2 then Exit(Null);
    Acc := 0;
    for I := 0 to High(Vals) do Acc := Acc + Sqr(Vals[I] - Mean);
    Acc := Acc / (Length(Vals) - 1);
    if Fn = 'var' then Exit(Acc);
    Exit(Sqrt(Acc));
  end;
  if Fn = 'median' then
  begin
    for I := 0 to High(Vals) - 1 do
      for J := I + 1 to High(Vals) do
        if Vals[J] < Vals[I] then begin T := Vals[I]; Vals[I] := Vals[J]; Vals[J] := T; end;
    if Odd(Length(Vals)) then Exit(Vals[Length(Vals) div 2]);
    Exit((Vals[Length(Vals) div 2 - 1] + Vals[Length(Vals) div 2]) / 2);
  end;
  Result := Null;
end;

function TaReportEngine.Domain(const AFunc, AExpr, ADomain, ACriteria: string): Variant;
begin
  Result := DbDomain(FDb, AFunc, AExpr, ADomain, ACriteria);
end;

function TaReportEngine.Variable(const AName: string): Variant;
var
  N: string;
begin
  N := LowerCase(AName);
  if N = 'page' then Result := FPageNo
  else if N = 'pages' then Result := FPageCount
  else if N = 'grouppage' then Result := FGroupPageV
  else if N = 'grouppages' then Result := FGroupPagesV
  else if N = 'rownum' then begin if FCur >= 0 then Result := FCur + 1 else Result := Null; end
  else if N = 'grouprow' then begin if FCur >= 0 then Result := FCur - FGroupStart + 1 else Result := Null; end
  else if N = 'rowcount' then Result := FRowCount
  else if N = 'grouprows' then Result := FGroupEnd - FGroupStart + 1
  else if N = 'date' then Result := VarFromDateTime(Date)
  else if N = 'now' then Result := VarFromDateTime(Now)
  else Result := Null;
end;

function LooksIsoDate(const S: string): Boolean;
var
  I: Integer;
begin
  Result := (Length(S) >= 10) and (S[5] = '-') and (S[8] = '-') and ((Length(S) = 10) or (S[11] in [' ', 'T']));
  if not Result then Exit;
  for I := 1 to 10 do
    if not (I in [5, 8]) and not (S[I] in ['0'..'9']) then Exit(False);
  if Length(S) > 10 then
    for I := 12 to Length(S) do
      if not (S[I] in ['0'..'9', ':', '.']) then Exit(False);
end;

function IsoToDisplayDate(const S: string): string;
begin
  Result := Copy(S, 9, 2) + '.' + Copy(S, 6, 2) + '.' + Copy(S, 1, 4);
  if Length(S) >= 16 then Result := Result + ' ' + Copy(S, 12, 5);
end;

function TaReportEngine.Resolve(const ASrc: string; AIsField: Boolean; const AFmt: string): string;
var
  V: Variant;
  I: Integer;
  M: TaFieldMeta;
begin
  if ASrc = '' then Exit('');
  if ASrc[1] = '=' then Exit(FormatValue(EvalExpr(Copy(ASrc, 2, MaxInt), Self), AFmt));
  if not AIsField then Exit(ASrc);
  V := FieldValue(ASrc);
  { typed fields show in their display format unless the item overrides it }
  if (AFmt = '') and not VarIsNull(V) then
    for I := 0 to FMetas.Count - 1 do
    begin
      M := TaFieldMeta(FMetas[I]);
      if SameText(M.FieldName, ASrc) then
      begin
        if VarIsFloat(V) then Exit(StoredToDisplay(M, FloatToStr(Double(V), InvariantFS)));
        Exit(StoredToDisplay(M, VarToStr(V)));
      end;
    end;
  { upit nema metapodataka: datum u ISO zapisu (yyyy-mm-dd) prikazuje se kao dd.mm.yyyy }
  if (AFmt = '') and VarIsStr(V) and LooksIsoDate(VarToStr(V)) then
    Exit(IsoToDisplayDate(VarToStr(V)));
  Result := FormatValue(V, AFmt);
end;

function TaReportEngine.NewItem(D: TaControlDef; ATop: Integer): TaRItem;
var
  Fc, Bc: TColor;
  Pt: Integer;
begin
  Result := TaRItem.Create;
  Result.X := FDef.MarginLeft + D.Left + FXOff;
  Result.Y := ATop + D.Top;
  Result.W := D.Width;
  Result.H := D.Height;
  Result.PageNo := FPageNo;
  Result.Bold := D.Bold;
  Result.Italic := D.GetX('italic') = '1';
  Result.Align := D.Align;
  Result.Fmt := D.Format;
  Fc := HexToColor(D.GetX('foreColor'), clBlack);
  Bc := HexToColor(D.GetX('backColor'), clDefault);
  Result.Color := ColorToRGB(Fc);
  if Bc <> clDefault then Result.Fill := ColorToRGB(Bc);
  Pt := StrToIntDef(D.GetX('fontSize'), 0);
  if Pt > 0 then Result.FontPx := Round(Pt * 96 / 72);
  Result.Border := StrToIntDef(D.GetX('borderWidth'), 1);
  FPage.Items.Add(Result);
end;

{ Raw bytes of a picture: embedded, or taken from the current row (BLOB or file path). }
function TaReportEngine.ImageBytes(D: TaControlDef): string;
var
  V: Variant;
  S, Path: string;
  Fs: TFileStream;
begin
  Result := '';
  if D.GetX('picture') <> '' then
  begin
    if Copy(D.GetX('picture'), 1, 5) = 'file:' then
    begin
      { statična slika: veza na datoteku u pohrani }
      Path := ResolveFileLink(FDb, Copy(D.GetX('picture'), 6, MaxInt));
      if (Path = '') or not FileExists(Path) then Exit;
      Fs := TFileStream.Create(Path, fmOpenRead or fmShareDenyNone);
      try
        SetLength(Result, Fs.Size);
        if Fs.Size > 0 then Fs.ReadBuffer(Result[1], Fs.Size);
      finally
        Fs.Free;
      end;
      Exit;
    end;
    try
      Exit(DecodeStringBase64(D.GetX('picture')));
    except
      Exit('');
    end;
  end;
  if D.ControlSource = '' then Exit;
  V := FieldValue(D.ControlSource);
  if VarIsNull(V) or VarIsEmpty(V) then Exit;
  S := VarToStr(V);
  if (Length(S) > 4) and ((Copy(S, 1, 4) = #137'PNG') or (Copy(S, 1, 2) = #255#216) or
     (Copy(S, 1, 3) = 'GIF') or (Copy(S, 1, 2) = 'BM') or IsSvgBytes(S)) then Exit(S);
  Path := ResolveFileLink(FDb, S);
  if (Path <> '') and FileExists(Path) then
  begin
    Fs := TFileStream.Create(Path, fmOpenRead or fmShareDenyNone);
    try
      SetLength(Result, Fs.Size);
      if Fs.Size > 0 then Fs.ReadBuffer(Result[1], Fs.Size);
    finally
      Fs.Free;
    end;
  end;
end;

{ A chart is drawn from primitives so it looks the same in preview, HTML, PDF
  and on paper: bars (or stems for "line", a stacked band for "pie") plus text. }
var
  SubDepth: Integer = 0;

function CloneItem(Src: TaRItem): TaRItem;
begin
  Result := TaRItem.Create;
  Result.Kind := Src.Kind; Result.Text := Src.Text; Result.Align := Src.Align; Result.Src := Src.Src;
  Result.Fmt := Src.Fmt; Result.Address := Src.Address; Result.PicBytes := Src.PicBytes;
  Result.Bold := Src.Bold; Result.Italic := Src.Italic; Result.Underline := Src.Underline;
  Result.Deferred := False;
  Result.X := Src.X; Result.Y := Src.Y; Result.W := Src.W; Result.H := Src.H;
  Result.PageNo := Src.PageNo; Result.Border := Src.Border; Result.FontPx := Src.FontPx;
  Result.Color := Src.Color; Result.Fill := Src.Fill;
end;

{ Izvjesce iz D.RowSource, ograniceno na zapise ciji je LinkChild jednak trenutnoj
  vrijednosti LinkMaster; stavke prve stranice, pomaknute na (0, 0). }
function TaReportEngine.SubResult(D: TaControlDef): TaSubResult;
var
  V: Variant;
  Key, Js, Lit, Cond: string;
  Idx, I: Integer;
  Cd: TaReportDef;
  Eng: TaReportEngine;
  Rr: TaRenderedReport;
  It: TaRItem;
  MinY, MaxB, MinX: Integer;
begin
  V := FieldValue(D.LinkMaster);
  if VarIsNull(V) then Key := D.Name + '|<null>' else Key := D.Name + '|' + VarToStr(V);
  if FSubCache = nil then
  begin
    FSubCache := TStringList.Create;
    FSubCache.CaseSensitive := True;
  end;
  Idx := FSubCache.IndexOf(Key);
  if Idx >= 0 then Exit(TaSubResult(FSubCache.Objects[Idx]));
  Result := TaSubResult.Create;
  FSubCache.AddObject(Key, Result);
  Js := FDb.LoadObject('_sys_reports', D.RowSource);
  if (Js = '') or (SubDepth >= 3) then Exit;
  if VarIsNull(V) then Cond := FDb.QuoteId(D.LinkChild) + ' IS NULL'
  else
  begin
    if VarIsNumeric(V) then Lit := FloatToStr(Double(V), InvariantFS) else Lit := FDb.QuoteLit(VarToStr(V));
    Cond := FDb.QuoteId(D.LinkChild) + ' = ' + Lit;
  end;
  Cd := TaReportDef.Create;
  try
    Cd.FromJson(Js);
    Cd.Name := D.RowSource;
    if Trim(Cd.Filter) <> '' then Cd.Filter := '(' + Cd.Filter + ') AND ' + Cond else Cd.Filter := Cond;
    { naslov, podnozje stranice i podnozje izvjesca ne ulaze u podizvjesce }
    for I := Cd.Count - 1 downto 0 do
      if SectionIndex(Cd[I].Section) in [SecReportHeader, SecPageFooter, SecReportFooter] then Cd.Delete(Cd[I]);
    Cd.Heights[SecReportHeader] := 0;
    Cd.Heights[SecPageFooter] := 0;
    Cd.Heights[SecReportFooter] := 0;
    Inc(SubDepth);
    try
      Eng := TaReportEngine.Create(FDb, Cd);
      try
        Rr := Eng.Render;
        try
          if Rr.PageCount > 1 then Result.Truncated := True;
          MinY := MaxInt; MaxB := 0; MinX := MaxInt;
          if Rr.PageCount > 0 then
            for I := 0 to Rr.Page(0).Items.Count - 1 do
            begin
              It := TaRItem(Rr.Page(0).Items[I]);
              if It.Y < MinY then MinY := It.Y;
              if It.X < MinX then MinX := It.X;
              if It.Y + It.H > MaxB then MaxB := It.Y + It.H;
            end;
          if MinY = MaxInt then Exit;
          for I := 0 to Rr.Page(0).Items.Count - 1 do
          begin
            It := CloneItem(TaRItem(Rr.Page(0).Items[I]));
            Dec(It.Y, MinY);
            Dec(It.X, Cd.MarginLeft);
            Result.Items.Add(It);
          end;
          Result.Height := MaxB - MinY + 4;
        finally
          Rr.Free;
        end;
      finally
        Eng.Free;
      end;
    finally
      Dec(SubDepth);
    end;
  finally
    Cd.Free;
  end;
end;

{ koliko stavka (podizvjesce ili formatirani tekst) treba vise od svoje visine }
function TaReportEngine.ExtraOf(D: TaControlDef): Integer;
begin
  if D.Kind = 'RichText' then Result := RichResult(D).Height - D.Height
  else if IsGrowText(D) then Result := GrowResult(D).Height - D.Height
  else Result := SubResult(D).Height - D.Height;
end;

{ Tekstualno polje koje se moze prosiriti na vise redaka (svojstvo GrowLines = najveci broj redaka, od 2 nadalje). }
function TaReportEngine.IsGrowText(D: TaControlDef): Boolean;
begin
  Result := (D.Kind = 'TextBox') and (StrToIntDef(D.GetX('growLines'), 0) > 1);
end;

{ Tekst polja složen u širinu polja; bez stavki kad staje u jedan redak (tada vrijedi obični prikaz). }
function TaReportEngine.GrowResult(D: TaControlDef): TaSubResult;
var
  Txt, Key: string;
  Idx, I, J, Px, Pt, MaxL, Nl, X0, X1, Shift: Integer;
  Doc: TRtDoc;
  Lay: TRtLayout;
  It: TaRItem;
  Fc: TColor;
begin
  Txt := Resolve(D.ControlSource, (D.ControlSource <> '') and (D.ControlSource[1] <> '='), D.Format);
  Key := 'gt|' + D.Name + '|' + IntToStr(D.Width) + '|' + D.GetX('growLines') + '|' + Txt;
  if FSubCache = nil then
  begin
    FSubCache := TStringList.Create;
    FSubCache.CaseSensitive := True;
  end;
  Idx := FSubCache.IndexOf(Key);
  if Idx >= 0 then Exit(TaSubResult(FSubCache.Objects[Idx]));
  Result := TaSubResult.Create;
  FSubCache.AddObject(Key, Result);
  Result.Height := D.Height;
  if Trim(Txt) = '' then Exit;
  Pt := StrToIntDef(D.GetX('fontSize'), 0);
  if Pt > 0 then Px := Round(Pt * 96 / 72) else Px := 13;
  MaxL := StrToIntDef(D.GetX('growLines'), 1);
  Doc := TRtDoc.Create;
  try
    Doc.LoadHtml(RtFromPlain(Txt));
    Lay := RtLayoutDoc(Doc, D.Width, Px, 0);
  finally
    Doc.Free;
  end;
  if Length(Lay.Lines) <= 1 then Exit;
  Nl := Length(Lay.Lines);
  if Nl > MaxL then Nl := MaxL;
  Fc := ColorToRGB(HexToColor(D.GetX('foreColor'), clBlack));
  for I := 0 to Nl - 1 do
  begin
    X0 := 0; X1 := 0;
    if Length(Lay.Lines[I].Segs) > 0 then
    begin
      X0 := Lay.Lines[I].Segs[0].X;
      X1 := Lay.Lines[I].Segs[High(Lay.Lines[I].Segs)].X + Lay.Lines[I].Segs[High(Lay.Lines[I].Segs)].W;
    end;
    Shift := 0;
    if SameText(D.Align, 'right') then Shift := Max(0, D.Width - (X1 - X0)) - X0
    else if SameText(D.Align, 'center') then Shift := Max(0, (D.Width - (X1 - X0)) div 2) - X0;
    for J := 0 to High(Lay.Lines[I].Segs) do
    begin
      It := TaRItem.Create;
      It.Kind := 'Text';
      It.FontName := RtFontName;
      It.X := Lay.Lines[I].Segs[J].X + Shift;
      It.Y := Lay.Lines[I].Y;
      It.W := Lay.Lines[I].Segs[J].W + 6;
      It.H := Lay.Lines[I].H;
      It.Text := Lay.Lines[I].Segs[J].Text;
      It.Bold := D.Bold or Lay.Lines[I].Segs[J].Bold;
      It.Italic := Lay.Lines[I].Segs[J].Italic or (D.GetX('italic') = '1');
      It.Color := Fc;
      It.FontPx := Lay.Lines[I].Segs[J].Px;
      Result.Items.Add(It);
    end;
  end;
  if Lay.Lines[Nl - 1].Y + Lay.Lines[Nl - 1].H + 3 > Result.Height then Result.Height := Lay.Lines[Nl - 1].Y + Lay.Lines[Nl - 1].H + 3;
end;

{ Formatirani tekst: slozen u sirinu stavke, stavke su relativne prema (0, 0) stavke. }
function TaReportEngine.RichResult(D: TaControlDef): TaSubResult;
var
  Html, Key: string;
  Idx, I, J: Integer;
  Doc: TRtDoc;
  Lay: TRtLayout;
  It: TaRItem;
  Px: Integer;
  Pt: Integer;
begin
  Html := Resolve(D.ControlSource, (D.ControlSource <> '') and (D.ControlSource[1] <> '='), '');
  Key := 'rt|' + D.Name + '|' + IntToStr(D.Width) + '|' + Html;
  if FSubCache = nil then
  begin
    FSubCache := TStringList.Create;
    FSubCache.CaseSensitive := True;
  end;
  Idx := FSubCache.IndexOf(Key);
  if Idx >= 0 then Exit(TaSubResult(FSubCache.Objects[Idx]));
  Result := TaSubResult.Create;
  FSubCache.AddObject(Key, Result);
  Result.Height := D.Height;
  if Trim(Html) = '' then Exit;
  Pt := StrToIntDef(D.GetX('fontSize'), 0);
  if Pt > 0 then Px := Round(Pt * 96 / 72) else Px := 13;
  Doc := TRtDoc.Create;
  try
    Doc.LoadHtml(Html);
    Lay := RtLayoutDoc(Doc, D.Width, Px, 0);
  finally
    Doc.Free;
  end;
  for I := 0 to High(Lay.Lines) do
    for J := 0 to High(Lay.Lines[I].Segs) do
    begin
      It := TaRItem.Create;
      It.Kind := 'Text';
      It.FontName := RtFontName;
      It.X := Lay.Lines[I].Segs[J].X;
      It.Y := Lay.Lines[I].Y;
      It.W := Lay.Lines[I].Segs[J].W + 6;
      It.H := Lay.Lines[I].H;
      It.Text := Lay.Lines[I].Segs[J].Text;
      It.Bold := Lay.Lines[I].Segs[J].Bold;
      It.Italic := Lay.Lines[I].Segs[J].Italic;
      It.Underline := Lay.Lines[I].Segs[J].Underline;
      { Color u stavkama je LCL TColor ($BBGGRR), a tekst nosi $RRGGBB }
      It.Color := ((Lay.Lines[I].Segs[J].Color and $FF) shl 16) or (Lay.Lines[I].Segs[J].Color and $FF00) or ((Lay.Lines[I].Segs[J].Color shr 16) and $FF);
      It.FontPx := Lay.Lines[I].Segs[J].Px;
      Result.Items.Add(It);
    end;
  if Lay.Height + 2 > Result.Height then Result.Height := Lay.Height + 2;
end;

{ Koliko sekciju treba produljiti da stane sve podizvjesce. }
function TaReportEngine.SubExtra(ASec: Integer): Integer;
var
  I, E, MaxGrow: Integer;
  D: TaControlDef;
begin
  Result := 0;
  MaxGrow := 0;
  for I := 0 to FDef.Count - 1 do
  begin
    D := FDef[I];
    if SectionIndex(D.Section) <> ASec then Continue;
    if IsGrowText(D) then
    begin
      { polja jedno uz drugo rastu zajedno: vrijedi najvece prosirenje }
      E := ExtraOf(D);
      if E > MaxGrow then MaxGrow := E;
      Continue;
    end;
    if (D.Kind <> 'Subreport') and (D.Kind <> 'RichText') then Continue;
    E := ExtraOf(D);
    if E > 0 then Inc(Result, E);
  end;
  Inc(Result, MaxGrow);
end;

{ Elementi ispod podizvjesca (po dizajnu) pomicu se za njegovo prosirenje. }
function TaReportEngine.ShiftFor(D: TaControlDef): Integer;
var
  I, E: Integer;
  S: TaControlDef;
begin
  Result := 0;
  for I := 0 to FDef.Count - 1 do
  begin
    S := FDef[I];
    if (S = D) or ((S.Kind <> 'Subreport') and (S.Kind <> 'RichText')) or (SectionIndex(S.Section) <> SectionIndex(D.Section)) then Continue;
    if S.Top + S.Height <= D.Top then
    begin
      E := ExtraOf(S);
      if E > 0 then Inc(Result, E);
    end;
  end;
end;

procedure TaReportEngine.EmitSubreport(D: TaControlDef; ATop: Integer);
var
  R: TaSubResult;
  I: Integer;
  It: TaRItem;
begin
  if D.Kind = 'RichText' then R := RichResult(D)
  else if IsGrowText(D) then R := GrowResult(D)
  else R := SubResult(D);
  for I := 0 to R.Items.Count - 1 do
  begin
    It := CloneItem(TaRItem(R.Items[I]));
    Inc(It.X, FDef.MarginLeft + D.Left + FXOff);
    Inc(It.Y, ATop + D.Top);
    It.PageNo := FPageNo;
    FPage.Items.Add(It);
  end;
end;

procedure TaReportEngine.EmitBarcode(D: TaControlDef; ATop: Integer);
var
  B: TBarcode;
  Err, Val, Typ: string;
  L: TBarLayout;
  I: Integer;
  It: TaRItem;
begin
  Val := Resolve(D.ControlSource, (D.ControlSource <> '') and (D.ControlSource[1] <> '='), '');
  if Val = '' then Exit;
  Typ := D.GetX('barType');
  if not BarcodeEncode(BarSymbologyOf(Typ), Val, B, Err) then Exit;
  L := BarcodeLayout(B, D.Width, D.Height, D.GetX('showText') <> '0', 14);
  for I := 0 to High(L.Rects) do
  begin
    It := TaRItem.Create;
    It.Kind := 'Frame';
    It.X := FDef.MarginLeft + D.Left + FXOff + L.Rects[I].Left;
    It.Y := ATop + D.Top + L.Rects[I].Top;
    It.W := L.Rects[I].Right - L.Rects[I].Left;
    It.H := L.Rects[I].Bottom - L.Rects[I].Top;
    It.Fill := 0;
    It.Color := 0;
    It.Border := 0;
    It.PageNo := FPageNo;
    FPage.Items.Add(It);
  end;
  if L.HasText then
  begin
    It := TaRItem.Create;
    It.Kind := 'Text';
    It.X := FDef.MarginLeft + D.Left + FXOff + L.TextRect.Left;
    It.Y := ATop + D.Top + L.TextRect.Top;
    It.W := L.TextRect.Right - L.TextRect.Left;
    It.H := L.TextRect.Bottom - L.TextRect.Top;
    It.Text := B.Caption;
    It.Align := 'center';
    It.FontPx := 11;
    It.PageNo := FPageNo;
    FPage.Items.Add(It);
  end;
end;

procedure TaReportEngine.EmitChart(D: TaControlDef; ATop: Integer);
var
  Q: TZQuery;
  Labels: TStringList;
  Vals: array of Double;
  N, I, X0, Y0, PW, PH, BarW, Slot, Hh, Zero: Integer;
  MaxV, MinV, Sum, V: Double;
  Typ: string;
  It: TaRItem;
  Cx: Integer;

  function Rect2(AX, AY, AW, AH, AFill: Integer): TaRItem;
  begin
    Result := TaRItem.Create;
    Result.Kind := 'Frame';
    Result.X := AX; Result.Y := AY; Result.W := AW; Result.H := AH;
    Result.Fill := AFill;
    Result.Color := AFill;
    Result.Border := 0;
    Result.PageNo := FPageNo;
    FPage.Items.Add(Result);
  end;

  procedure Txt(AX, AY, AW, AH: Integer; const S: string; ABold: Boolean; AAlign: string);
  begin
    It := TaRItem.Create;
    It.Kind := 'Text';
    It.X := AX; It.Y := AY; It.W := AW; It.H := AH;
    It.Text := S;
    It.Bold := ABold;
    It.Align := AAlign;
    It.FontPx := 11;
    It.PageNo := FPageNo;
    FPage.Items.Add(It);
  end;

begin
  if D.RowSource = '' then Exit;
  Typ := LowerCase(D.GetX('chartType'));
  Labels := TStringList.Create;
  Q := FDb.NewQuery(ExpandPlaceholders(Self, D.RowSource));
  try
    try
      Q.Open;
      N := 0;
      while (not Q.EOF) and (N < 40) do
      begin
        SetLength(Vals, N + 1);
        if Q.FieldCount >= 2 then begin Labels.Add(Q.Fields[0].AsString); Vals[N] := Q.Fields[1].AsFloat; end
        else begin Labels.Add(IntToStr(N + 1)); Vals[N] := Q.Fields[0].AsFloat; end;
        Inc(N);
        Q.Next;
      end;
    except
      Exit;
    end;
  finally
    Q.Free;
  end;
  try
    X0 := FDef.MarginLeft + D.Left + FXOff;
    Y0 := ATop + D.Top;
    if D.Caption <> '' then
    begin
      Txt(X0 + 4, Y0, D.Width - 8, 18, D.Caption, True, '');
      Inc(Y0, 20);
    end;
    PW := D.Width - 48;
    PH := D.Height - 20 - 26 - Ord(D.Caption <> '') * 20;
    if (N = 0) or (PW < 20) or (PH < 20) then Exit;
    if Typ = 'pie' then
    begin
      Sum := 0;
      for I := 0 to N - 1 do if Vals[I] > 0 then Sum := Sum + Vals[I];
      if Sum <= 0 then Exit;
      Cx := X0 + 8;
      for I := 0 to N - 1 do
      begin
        if Vals[I] <= 0 then Continue;
        Hh := Max(1, Round(Vals[I] / Sum * (D.Width - 16)));
        Rect2(Cx, Y0, Hh, 18, ColorToRGB(ChartColors[I mod 8]));
        Inc(Cx, Hh);
      end;
      for I := 0 to N - 1 do
      begin
        if Y0 + 26 + I * 16 + 14 > ATop + D.Top + D.Height then Break;
        Rect2(X0 + 8, Y0 + 26 + I * 16 + 2, 10, 10, ColorToRGB(ChartColors[I mod 8]));
        Txt(X0 + 24, Y0 + 26 + I * 16, D.Width - 30, 14,
          Labels[I] + ': ' + FormatFloat('#,##0.##', Vals[I]) + ' (' + FormatFloat('0.#', Vals[I] / Sum * 100) + '%)', False, '');
      end;
      Exit;
    end;
    MaxV := 0; MinV := 0;
    for I := 0 to N - 1 do
    begin
      if Vals[I] > MaxV then MaxV := Vals[I];
      if Vals[I] < MinV then MinV := Vals[I];
    end;
    if MaxV = MinV then MaxV := MinV + 1;
    Slot := PW div N;
    if Slot < 4 then Slot := 4;
    BarW := Max(3, Slot - 6);
    Zero := Y0 + 14 + Round(MaxV / (MaxV - MinV) * PH);
    Rect2(X0 + 40, Y0 + 14, 1, PH, ColorToRGB(clGray));
    Rect2(X0 + 40, Zero, PW, 1, ColorToRGB(clGray));
    Txt(X0, Y0 + 8, 38, 14, FormatFloat('#,##0.##', MaxV), False, 'right');
    Txt(X0, Y0 + 14 + PH - 8, 38, 14, FormatFloat('#,##0.##', MinV), False, 'right');
    for I := 0 to N - 1 do
    begin
      V := Vals[I];
      Hh := Round(Abs(V) / (MaxV - MinV) * PH);
      if Typ = 'line' then
      begin
        Rect2(X0 + 44 + I * Slot + BarW div 2, Min(Zero, Zero - Round(V / (MaxV - MinV) * PH)),
          2, Abs(Round(V / (MaxV - MinV) * PH)) + 1, ColorToRGB(ChartColors[0]));
        Rect2(X0 + 41 + I * Slot + BarW div 2, Zero - Round(V / (MaxV - MinV) * PH) - 3, 8, 8, ColorToRGB(ChartColors[0]));
      end
      else if V >= 0 then Rect2(X0 + 44 + I * Slot, Zero - Hh, BarW, Max(Hh, 1), ColorToRGB(ChartColors[I mod 8]))
      else Rect2(X0 + 44 + I * Slot, Zero, BarW, Max(Hh, 1), ColorToRGB(ChartColors[I mod 8]));
      if BarW >= 26 then
        Txt(X0 + 40 + I * Slot - 4, Zero - Max(Hh, 0) - 16, BarW + 8, 14, FormatFloat('#,##0.##', V), False, 'center');
      Txt(X0 + 40 + I * Slot - 2, Y0 + 14 + PH + 6, Slot + 2, 14, Labels[I], False, 'center');
    end;
  finally
    Labels.Free;
  end;
end;

function TaReportEngine.SectionBreak(ASec: Integer; AAtTop: Boolean): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to FDef.Count - 1 do
    if (FDef[I].Kind = 'PageBreak') and (SectionIndex(FDef[I].Section) = ASec) and
       ((FDef[I].Top = 0) = AAtTop) then Exit(True);
end;

procedure TaReportEngine.EmitItems(ASec, ATop: Integer);
var
  CfRule: TCondRule;
  I, Sh: Integer;
  D: TaControlDef;
  It: TaRItem;
  Src: string;
begin
  for I := 0 to FDef.Count - 1 do
  begin
    D := FDef[I];
    if SectionIndex(D.Section) <> ASec then Continue;
    if D.Kind = 'PageBreak' then Continue;
    Sh := ShiftFor(D);
    if D.Kind = 'Chart' then begin EmitChart(D, ATop + Sh); Continue; end;
    if D.Kind = 'Barcode' then begin EmitBarcode(D, ATop + Sh); Continue; end;
    if (D.Kind = 'Subreport') or (D.Kind = 'RichText') then begin EmitSubreport(D, ATop + Sh); Continue; end;
    if IsGrowText(D) and (GrowResult(D).Items.Count > 0) then begin EmitSubreport(D, ATop + Sh); Continue; end;
    It := NewItem(D, ATop + Sh);
    if D.Kind = 'Line' then
    begin
      It.Kind := 'Line';
      It.Fill := It.Color;
    end
    else if D.Kind = 'Rectangle' then
      It.Kind := 'Frame'
    else if D.Kind = 'Image' then
    begin
      It.Kind := 'Image';
      It.PicBytes := ImageBytes(D);
      It.Fmt := LowerCase(D.GetX('sizeMode'));
    end
    else
    begin
      It.Kind := 'Text';
      if (D.Kind = 'Label') or (D.Kind = 'Hyperlink') then Src := D.Caption else Src := D.ControlSource;
      It.Src := Src;
      It.Text := Resolve(Src, (D.Kind <> 'Label') and not ((D.Kind = 'Hyperlink') and (D.ControlSource = '')), D.Format);
      if (D.Kind = 'Hyperlink') then
      begin
        It.Underline := True;
        It.Color := ColorToRGB(clBlue);
        It.Address := D.RowSource;
        if It.Address = '' then It.Address := It.Text;
        if (D.Caption <> '') and (D.ControlSource <> '') then It.Text := Resolve(D.Caption, False, '');
      end;
      It.Deferred := (It.Src <> '') and (It.Src[1] = '=') and ((Pos('pages', LowerCase(It.Src)) > 0) or (Pos('grouppage', LowerCase(It.Src)) > 0));
      if D.GetX('condFormat') <> '' then
        if MatchCondFormat(ParseCondFormat(D.GetX('condFormat')), Self, CfRule) then
        begin
          if CfRule.Fore <> '' then It.Color := ColorToRGB(HexToColor(CfRule.Fore, clBlack));
          if CfRule.Back <> '' then It.Fill := ColorToRGB(HexToColor(CfRule.Back, clWhite));
          if CfRule.Bold then It.Bold := True;
        end;
    end;
  end;
end;

procedure TaReportEngine.PlaceSection(ASec, ACur, AFrom, ATo: Integer);
var
  H: Integer;
begin
  H := FDef.Heights[ASec];
  if H <= 0 then Exit;
  SetScope(ACur, AFrom, ATo);
  Inc(H, SubExtra(ASec));
  if (FPendingBreak or SectionBreak(ASec, True)) and (FY > FContentTop) then
  begin
    FinishPage;
    StartPage(False);
  end;
  FPendingBreak := False;
  if (FY + H > FContentBottom) and (FY > FContentTop) then
  begin
    FinishPage;
    StartPage(False);
  end;
  SetScope(ACur, AFrom, ATo);
  EmitItems(ASec, FY);
  Inc(FY, H);
  if SectionBreak(ASec, False) then FPendingBreak := True;
end;

{ Detail rows in columns: the first of each row flows like any section, the
  others are drawn beside it at the same height. }
procedure TaReportEngine.PlaceDetail(ARow: Integer);
var
  Cols, Col, ColW, H: Integer;
begin
  Cols := FDef.Columns;
  if Cols < 2 then
  begin
    PlaceSection(SecDetail, ARow, ARow, ARow);
    Exit;
  end;
  H := FDef.Heights[SecDetail];
  Col := FDetailIdx mod Cols;
  if (Col = 0) and (FDetailIdx > 0) and (FDef.RowGap > 0) and (FY + FDef.RowGap + H <= FContentBottom) then
    Inc(FY, FDef.RowGap);
  ColW := (FDef.PageWidth - FDef.MarginLeft - FDef.MarginRight - FDef.ColumnGap * (Cols - 1)) div Cols;
  if Col = 0 then
  begin
    FXOff := 0;
    PlaceSection(SecDetail, ARow, ARow, ARow);
  end
  else
  begin
    FXOff := Col * (ColW + FDef.ColumnGap);
    SetScope(ARow, ARow, ARow);
    EmitItems(SecDetail, FY - H);
    FXOff := 0;
  end;
  Inc(FDetailIdx);
end;

procedure TaReportEngine.StartPage(AFirst: Boolean);
var
  H: Integer;
begin
  FPage := TaRPage.Create;
  FResult.Pages.Add(FPage);
  Inc(FPageNo);
  FY := FDef.MarginTop;
  FContentBottom := FDef.PageHeight - FDef.MarginBottom - FDef.Heights[SecPageFooter];
  FContentTop := FY;
  if AFirst then
  begin
    if FRowCount > 0 then SetScope(0, 0, FRowCount - 1) else SetScope(-1, 0, -1);
    EmitItems(SecReportHeader, FY);
    Inc(FY, FDef.Heights[SecReportHeader]);
  end;
  H := FDef.Heights[SecPageHeader];
  SetScope(-1, 0, FRowCount - 1);
  EmitItems(SecPageHeader, FY);
  Inc(FY, H);
  FContentTop := FY;
end;

procedure TaReportEngine.FinishPage;
begin
  { koja grupa je na ovoj stranici: za GroupPage / GroupPages }
  SetLength(FPageGroups, Length(FPageGroups) + 1);
  FPageGroups[High(FPageGroups)] := FPageGroup;
  SetScope(-1, 0, FRowCount - 1);
  EmitItems(SecPageFooter, FDef.PageHeight - FDef.MarginBottom - FDef.Heights[SecPageFooter]);
end;

function TaReportEngine.GroupEnd(AStart: Integer; const AGroupIdx: Integer): Integer;
var
  Key: string;
begin
  Key := VarToStr(FRows[AStart][AGroupIdx]);
  Result := AStart;
  while (Result + 1 < FRowCount) and (VarToStr(FRows[Result + 1][AGroupIdx]) = Key) do
    Inc(Result);
end;

function TaReportEngine.Render: TaRenderedReport;
var
  GIdx, I, GEnd, R, P, K, FirstP, LastP: Integer;
  Pg: TaRPage;
  It: TaRItem;
begin
  LoadRows;
  FResult := TaRenderedReport.Create;
  FResult.PageW := FDef.PageWidth;
  FResult.PageH := FDef.PageHeight;
  FPageNo := 0;
  FPageCount := 0;
  FGroupPageV := 1;
  FGroupPagesV := 1;
  FPageGroup := 0;
  SetLength(FPageGroups, 0);
  GIdx := -1;
  if FDef.GroupField <> '' then GIdx := FNames.IndexOf(LowerCase(FDef.GroupField));
  StartPage(True);
  I := 0;
  while I < FRowCount do
  begin
    if GIdx >= 0 then GEnd := GroupEnd(I, GIdx) else GEnd := FRowCount - 1;
    FGroupStart := I;
    FGroupEnd := GEnd;
    if GIdx >= 0 then
    begin
      if (FY + FDef.Heights[SecGroupHeader] + FDef.Heights[SecDetail] > FContentBottom) and
         (FY > FContentTop) then
      begin
        FinishPage;
        StartPage(False);
      end;
      PlaceSection(SecGroupHeader, I, I, GEnd);
      { od ovog trenutka stranica pripada ovoj grupi (prijelom prije zaglavlja je vec zavrsio staru stranicu) }
      FPageGroup := I;
    end;
    FDetailIdx := 0;
    for R := I to GEnd do
      PlaceDetail(R);
    if GIdx >= 0 then PlaceSection(SecGroupFooter, GEnd, I, GEnd);
    I := GEnd + 1;
  end;
  PlaceSection(SecReportFooter, FRowCount - 1, 0, FRowCount - 1);
  FinishPage;

  { second pass: items that need the total page count }
  FPageCount := FResult.PageCount;
  for P := 0 to FResult.PageCount - 1 do
  begin
    Pg := FResult.Page(P);
    FPageNo := P + 1;
    { stranica unutar svoje grupe: prva i zadnja stranica na kojoj je ista grupa }
    if (P <= High(FPageGroups)) then
    begin
      FirstP := P; LastP := P;
      for K := 0 to High(FPageGroups) do
        if FPageGroups[K] = FPageGroups[P] then
        begin
          if K < FirstP then FirstP := K;
          if K > LastP then LastP := K;
        end;
      FGroupPageV := P - FirstP + 1;
      FGroupPagesV := LastP - FirstP + 1;
    end;
    SetScope(-1, 0, FRowCount - 1);
    for K := 0 to Pg.Items.Count - 1 do
    begin
      It := TaRItem(Pg.Items[K]);
      if It.Deferred then
        It.Text := FormatValue(EvalExpr(Copy(It.Src, 2, MaxInt), Self), It.Fmt);
    end;
  end;
  Result := FResult;
  FResult := nil;
end;

end.
