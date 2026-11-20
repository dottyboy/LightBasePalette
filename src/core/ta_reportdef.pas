unit ta_reportdef;
{ Report definition: seven bands (Access layout) and the items placed in them.
  Items reuse TaControlDef; Section names the band. Stored in _sys_reports. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, contnrs, fpjson, jsonparser, ta_formdef;

const
  SecReportHeader = 0;
  SecPageHeader = 1;
  SecGroupHeader = 2;
  SecDetail = 3;
  SecGroupFooter = 4;
  SecPageFooter = 5;
  SecReportFooter = 6;
  SectionNames: array[0..6] of string = (
    'ReportHeader', 'PageHeader', 'GroupHeader', 'Detail', 'GroupFooter', 'PageFooter', 'ReportFooter');
  DefaultHeights: array[0..6] of Integer = (44, 28, 28, 24, 28, 24, 44);

type

  { TaReportDef }

  TaReportDef = class
  private
    FItems: TFPObjectList;
    function GetCount: Integer;
    function GetItem(I: Integer): TaControlDef;
  public
    Name, Title, RecordSource, GroupField, SortBy: string;
    { ponudeni poredci za ispis: "Po unosu=id ;; Po sifri=sifra ;; Po cijeni=cijena DESC" }
    SortOptions: string;
    { Detail rows laid out side by side: 3 columns = address labels }
    Columns, ColumnGap: Integer;
    { stranica u pikselima (96 dpi): A4 = 794 x 1123; margine i razmak redova naljepnica }
    PageWidth, PageHeight, MarginLeft, MarginTop, MarginRight, MarginBottom, RowGap: Integer;
    { SQL condition applied to the record source (e.g. "dok_id = 5") }
    Filter: string;
    Heights: array[0..6] of Integer;
    constructor Create;
    destructor Destroy; override;
    function Add(ADef: TaControlDef): TaControlDef;
    procedure Delete(ADef: TaControlDef);
    { redoslijed = z-redoslijed: kasnije je iznad }
    procedure MoveItem(ADef: TaControlDef; ANewIndex: Integer);
    function IndexOfName(const AName: string): Integer;
    function SortOptionCount: Integer;
    function SortOptionName(I: Integer): string;
    function SortOptionOrder(I: Integer): string;
    { poredak (ORDER BY) za naziv ponudenog poretka; prazno -> zadani SortBy; nepoznat tekst se uzima kao sam poredak }
    function SortFor(const AOption: string): string;
    function UniqueName(const AKind: string): string;
    function ToJson: string;
    procedure FromJson(const S: string);
    property Count: Integer read GetCount;
    property Items[I: Integer]: TaControlDef read GetItem; default;
  end;

function SectionIndex(const AName: string): Integer;
{ "Naziv#poredak=Po cijeni" -> naziv izvjesca i naziv ponudenog poretka (za naredbu openreport) }
procedure SplitReportArg(const AArg: string; out AName, ASort: string);

implementation

procedure SplitReportArg(const AArg: string; out AName, ASort: string);
var
  P: Integer;
begin
  AName := Trim(AArg);
  ASort := '';
  P := Pos('#poredak=', LowerCase(AName));
  if P > 0 then
  begin
    ASort := Trim(Copy(AName, P + 9, MaxInt));
    AName := Trim(Copy(AName, 1, P - 1));
  end;
end;

function SortOptPart(const AText: string; AIndex: Integer; out AName, AOrder: string): Boolean;
var
  Txt, One: string;
  P, K: Integer;
begin
  Result := False;
  Txt := AText;
  K := 0;
  while Trim(Txt) <> '' do
  begin
    P := Pos(';;', Txt);
    if P = 0 then begin One := Txt; Txt := ''; end
    else begin One := Copy(Txt, 1, P - 1); Txt := Copy(Txt, P + 2, MaxInt); end;
    P := Pos('=', One);
    if (P < 2) or (Trim(Copy(One, P + 1, MaxInt)) = '') then Continue;
    if K = AIndex then
    begin
      AName := Trim(Copy(One, 1, P - 1));
      AOrder := Trim(Copy(One, P + 1, MaxInt));
      Exit(True);
    end;
    Inc(K);
  end;
end;


function SectionIndex(const AName: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(SectionNames) do
    if SameText(SectionNames[I], AName) then Exit(I);
  Result := -1;
end;

constructor TaReportDef.Create;
var
  I: Integer;
begin
  FItems := TFPObjectList.Create(True);
  Columns := 1;
  ColumnGap := 12;
  PageWidth := 794; PageHeight := 1123;
  MarginLeft := 40; MarginTop := 40; MarginRight := 40; MarginBottom := 40;
  RowGap := 0;
  for I := 0 to 6 do Heights[I] := DefaultHeights[I];
end;

destructor TaReportDef.Destroy;
begin
  FItems.Free;
  inherited Destroy;
end;

function TaReportDef.GetCount: Integer;
begin
  Result := FItems.Count;
end;

function TaReportDef.GetItem(I: Integer): TaControlDef;
begin
  Result := TaControlDef(FItems[I]);
end;

function TaReportDef.Add(ADef: TaControlDef): TaControlDef;
begin
  FItems.Add(ADef);
  Result := ADef;
end;

procedure TaReportDef.MoveItem(ADef: TaControlDef; ANewIndex: Integer);
var
  I: Integer;
begin
  I := FItems.IndexOf(ADef);
  if I < 0 then Exit;
  if ANewIndex < 0 then ANewIndex := 0;
  if ANewIndex > FItems.Count - 1 then ANewIndex := FItems.Count - 1;
  FItems.Move(I, ANewIndex);
end;

procedure TaReportDef.Delete(ADef: TaControlDef);
begin
  FItems.Remove(ADef);
end;

function TaReportDef.SortOptionCount: Integer;
var
  N, O: string;
begin
  Result := 0;
  while SortOptPart(SortOptions, Result, N, O) do Inc(Result);
end;

function TaReportDef.SortOptionName(I: Integer): string;
var
  O: string;
begin
  if not SortOptPart(SortOptions, I, Result, O) then Result := '';
end;

function TaReportDef.SortOptionOrder(I: Integer): string;
var
  N: string;
begin
  if not SortOptPart(SortOptions, I, N, Result) then Result := '';
end;

function TaReportDef.SortFor(const AOption: string): string;
var
  I: Integer;
begin
  Result := Trim(SortBy);
  if Trim(AOption) = '' then Exit;
  for I := 0 to SortOptionCount - 1 do
    if SameText(SortOptionName(I), Trim(AOption)) then Exit(SortOptionOrder(I));
  Result := Trim(AOption);
end;

function TaReportDef.IndexOfName(const AName: string): Integer;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    if SameText(Items[I].Name, AName) then Exit(I);
  Result := -1;
end;

function TaReportDef.UniqueName(const AKind: string): string;
var
  N: Integer;
begin
  N := 1;
  repeat
    Result := AKind + IntToStr(N);
    Inc(N);
  until IndexOfName(Result) < 0;
end;

function TaReportDef.ToJson: string;
var
  O, H, CO: TJSONObject;
  A: TJSONArray;
  I: Integer;
  D: TaControlDef;
begin
  O := TJSONObject.Create;
  try
    O.Add('name', Name);
    O.Add('title', Title);
    O.Add('recordSource', RecordSource);
    O.Add('groupField', GroupField);
    O.Add('sortBy', SortBy);
    O.Add('sortOptions', SortOptions);
    O.Add('columns', Columns);
    O.Add('filter', Filter);
    O.Add('columnGap', ColumnGap);
    O.Add('pageWidth', PageWidth);
    O.Add('pageHeight', PageHeight);
    O.Add('marginLeft', MarginLeft);
    O.Add('marginTop', MarginTop);
    O.Add('marginRight', MarginRight);
    O.Add('marginBottom', MarginBottom);
    O.Add('rowGap', RowGap);
    H := TJSONObject.Create;
    for I := 0 to 6 do H.Add(SectionNames[I], Heights[I]);
    O.Add('heights', H);
    A := TJSONArray.Create;
    for I := 0 to Count - 1 do
    begin
      D := Items[I];
      CO := TJSONObject.Create;
      CO.Add('kind', D.Kind);
      CO.Add('name', D.Name);
      CO.Add('section', D.Section);
      CO.Add('caption', D.Caption);
      CO.Add('controlSource', D.ControlSource);
      CO.Add('format', D.Format);
      CO.Add('align', D.Align);
      CO.Add('bold', D.Bold);
      CO.Add('extra', D.Extra);
      if D.RowSource <> '' then CO.Add('rowSource', D.RowSource);
      if D.OnClick <> '' then CO.Add('onClick', D.OnClick);
      if D.LinkMaster <> '' then CO.Add('linkMaster', D.LinkMaster);
      if D.LinkChild <> '' then CO.Add('linkChild', D.LinkChild);
      CO.Add('left', D.Left);
      CO.Add('top', D.Top);
      CO.Add('width', D.Width);
      CO.Add('height', D.Height);
      A.Add(CO);
    end;
    O.Add('items', A);
    Result := O.FormatJSON;
  finally
    O.Free;
  end;
end;

procedure TaReportDef.FromJson(const S: string);
var
  J: TJSONData;
  O, CO: TJSONObject;
  A, H: TJSONData;
  I: Integer;
  D: TaControlDef;
begin
  FItems.Clear;
  if Trim(S) = '' then Exit;
  J := GetJSON(S);
  try
    O := J as TJSONObject;
    Name := O.Get('name', '');
    Title := O.Get('title', '');
    RecordSource := O.Get('recordSource', '');
    GroupField := O.Get('groupField', '');
    SortBy := O.Get('sortBy', '');
    SortOptions := O.Get('sortOptions', '');
    Columns := O.Get('columns', 1);
    Filter := O.Get('filter', '');
    ColumnGap := O.Get('columnGap', 12);
    if Columns < 1 then Columns := 1;
    PageWidth := O.Get('pageWidth', 794);
    PageHeight := O.Get('pageHeight', 1123);
    MarginLeft := O.Get('marginLeft', 40);
    MarginTop := O.Get('marginTop', 40);
    MarginRight := O.Get('marginRight', 40);
    MarginBottom := O.Get('marginBottom', 40);
    RowGap := O.Get('rowGap', 0);
    if PageWidth < 200 then PageWidth := 200;
    if PageHeight < 200 then PageHeight := 200;
    if MarginLeft < 0 then MarginLeft := 0;
    if MarginRight < 0 then MarginRight := 0;
    if MarginTop < 0 then MarginTop := 0;
    if MarginBottom < 0 then MarginBottom := 0;
    if RowGap < 0 then RowGap := 0;
    H := O.Find('heights');
    if H is TJSONObject then
      for I := 0 to 6 do Heights[I] := TJSONObject(H).Get(SectionNames[I], DefaultHeights[I]);
    A := O.Find('items');
    if A is TJSONArray then
      for I := 0 to TJSONArray(A).Count - 1 do
      begin
        CO := TJSONArray(A).Objects[I];
        D := TaControlDef.Create;
        D.Kind := CO.Get('kind', '');
        D.Name := CO.Get('name', '');
        D.Section := CO.Get('section', 'Detail');
        D.Caption := CO.Get('caption', '');
        D.ControlSource := CO.Get('controlSource', '');
        D.Format := CO.Get('format', '');
        D.Align := CO.Get('align', '');
        D.Bold := CO.Get('bold', False);
        D.Extra := CO.Get('extra', '');
        D.RowSource := CO.Get('rowSource', '');
        D.OnClick := CO.Get('onClick', '');
        D.LinkMaster := CO.Get('linkMaster', '');
        D.LinkChild := CO.Get('linkChild', '');
        D.Left := CO.Get('left', 0);
        D.Top := CO.Get('top', 0);
        D.Width := CO.Get('width', 100);
        D.Height := CO.Get('height', 20);
        FItems.Add(D);
      end;
  finally
    J.Free;
  end;
end;

end.
