unit ta_letter;
{ Dopisi: tekst s poljima i tablicom (npr. opomena firmi s popisom neplacenih racuna).
  Jedan dopis po zapisu izvora (primatelju); stavke tablice dolaze iz SQL-a koji smije
  upotrijebiti polja primatelja kao {polje}. Rezultat je isti TaRenderedReport kao kod izvjesca,
  pa pregled, PDF, HTML i ispis rade bez izmjena.

  Tekst dopisa:
    [polje]            vrijednost polja primatelja     [polje|0.00]  s oblikom
    {izraz}            izraz, npr. {Zaokruzi([dug] * 1.1, 2)}
    [tablica]          (sama u retku) tablica stavki
    [ukupno]           zbroj stupca ukupno (oblik 0.00)      [stavki]  broj stavki
    [datum] [vrijeme] [korisnik] [firma_naziv] [firma_adresa] [firma_mjesto] [firma_iban]
  Pocetak retka: > desno, ^ sredina, # podebljano; prazan redak je razmak. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Variants, fpjson, jsonparser, zipper, ZDataset, DB, Graphics, ta_meta, ta_expr, ta_exprdb,
  ta_reportengine;

type
  TaLetterDef = class
  public
    Name: string;
    Source: string;        { tablica ili upit: jedan dopis po retku }
    Filter: string;        { SQL uvjet za Source (prazno = svi) }
    DetailSql: string;     { SQL stavki; {polje} = polje primatelja kao SQL vrijednost }
    Body: string;          { tekst s poljima }
    Columns: string;       { redci "polje|Naslov|oblik|poravnanje|udio" }
    TotalField: string;    { stupac cija se suma ispisuje kao [ukupno] i u zadnjem retku }
    TotalLabel: string;
    FontPx: Integer;
    constructor Create;
    function ToJson: string;
    procedure FromJson(const S: string);
  end;

{ Svi dopisi (AKey = '' ) ili samo onaj cije je prvo polje primatelja jednako AKey. Nil + AErr kod greske. }
function RenderLetters(ADb: TAppDb; ADef: TaLetterDef; out AErr: string; const AKey: string = ''): TaRenderedReport;
{ Word dokument (.docx): isti dopisi kao uredljiv tekst i tablice, svaki primatelj na novoj stranici }
function ExportLettersDocx(ADb: TAppDb; ADef: TaLetterDef; const AFile: string; out AErr: string; const AKey: string = ''): Boolean;
{ prosti tekst dopisa za provjere i izvoz bez oblikovanja: po jedan blok po primatelju, odvojeni retkom '---' }
function LetterPlainText(ADb: TAppDb; ADef: TaLetterDef; out AErr: string): string;

implementation

const
  Margin = 64;
  TopMargin = 64;
  BottomMargin = 64;

constructor TaLetterDef.Create;
begin
  FontPx := 15;
  TotalLabel := 'Ukupno';
end;

function TaLetterDef.ToJson: string;
var
  O: TJSONObject;
begin
  O := TJSONObject.Create;
  try
    O.Add('name', Name);
    O.Add('source', Source);
    O.Add('filter', Filter);
    O.Add('detailSql', DetailSql);
    O.Add('body', Body);
    O.Add('columns', Columns);
    O.Add('totalField', TotalField);
    O.Add('totalLabel', TotalLabel);
    O.Add('fontPx', FontPx);
    Result := O.AsJSON;
  finally
    O.Free;
  end;
end;

procedure TaLetterDef.FromJson(const S: string);
var
  J: TJSONData;
  O: TJSONObject;
begin
  if Trim(S) = '' then Exit;
  J := GetJSON(S);
  try
    O := J as TJSONObject;
    Name := O.Get('name', Name);
    Source := O.Get('source', '');
    Filter := O.Get('filter', '');
    DetailSql := O.Get('detailSql', '');
    Body := O.Get('body', '');
    Columns := O.Get('columns', '');
    TotalField := O.Get('totalField', '');
    TotalLabel := O.Get('totalLabel', 'Ukupno');
    FontPx := O.Get('fontPx', 15);
    if FontPx < 8 then FontPx := 15;
  finally
    J.Free;
  end;
end;

{ ---------------- kontekst jednog primatelja ---------------- }

type
  TLetterHost = class(TaExprHost)
  public
    Db: TAppDb;
    Names: TStringList;
    Vals: array of Variant;
    function FieldValue(const AName: string): Variant; override;
    function Aggregate(const AFunc, AField: string): Variant; override;
    function Variable(const AName: string): Variant; override;
    function Domain(const AFunc, AExpr, ADomain, ACriteria: string): Variant; override;
  end;

function TLetterHost.FieldValue(const AName: string): Variant;
var
  I: Integer;
begin
  I := Names.IndexOf(LowerCase(AName));
  if I < 0 then Result := Null else Result := Vals[I];
end;

function TLetterHost.Aggregate(const AFunc, AField: string): Variant;
begin
  Result := Null;
end;

function TLetterHost.Variable(const AName: string): Variant;
begin
  Result := FieldValue(AName);
end;

function TLetterHost.Domain(const AFunc, AExpr, ADomain, ACriteria: string): Variant;
begin
  Result := DbDomain(Db, AFunc, AExpr, ADomain, ACriteria);
end;

function IsIsoDate(const S: string): Boolean;
begin
  Result := (Length(S) = 10) and (S[5] = '-') and (S[8] = '-') and
    (S[1] in ['0'..'9']) and (S[2] in ['0'..'9']) and (S[3] in ['0'..'9']) and (S[4] in ['0'..'9']) and
    (S[6] in ['0'..'9']) and (S[7] in ['0'..'9']) and (S[9] in ['0'..'9']) and (S[10] in ['0'..'9']);
end;

{ vrijednost za ispis: datumi kao dd.mm.gggg, ostalo kroz FormatValue s oblikom (ili bez) }
function ShowValue(const V: Variant; const AFmt: string): string;
begin
  if VarIsNull(V) or VarIsEmpty(V) then Exit('');
  if VarIsStr(V) and (AFmt = '') and IsIsoDate(VarToStr(V)) then
    Exit(Copy(VarToStr(V), 9, 2) + '.' + Copy(VarToStr(V), 6, 2) + '.' + Copy(VarToStr(V), 1, 4));
  Result := FormatValue(V, AFmt);
end;

{ SQL vrijednost iz varijante: broj bez navodnika, tekst u navodnicima }
function SqlLiteral(const V: Variant): string;
var
  FS: TFormatSettings;
begin
  if VarIsNull(V) or VarIsEmpty(V) then Exit('NULL');
  if VarIsStr(V) then Exit('''' + StringReplace(VarToStr(V), '''', '''''', [rfReplaceAll]) + '''');
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  Result := FloatToStr(Double(V), FS);
end;

function ExpandSql(AHost: TLetterHost; const ASql: string): string;
var
  I, J: Integer;
  Nm: string;
  K: Integer;
begin
  Result := '';
  I := 1;
  while I <= Length(ASql) do
  begin
    if ASql[I] = '{' then
    begin
      J := I + 1;
      while (J <= Length(ASql)) and (ASql[J] <> '}') do Inc(J);
      Nm := LowerCase(Trim(Copy(ASql, I + 1, J - I - 1)));
      K := AHost.Names.IndexOf(Nm);
      if (J <= Length(ASql)) and (K >= 0) then
      begin
        Result := Result + SqlLiteral(AHost.Vals[K]);
        I := J + 1;
        Continue;
      end;
    end;
    Result := Result + ASql[I];
    Inc(I);
  end;
end;

{ ---------------- izrada ---------------- }

type
  TLCol = record
    Field, Title, Fmt, Align: string;
    Weight: Double;
    X, W: Integer;
  end;

  TLetterBuilder = class
  public
    Db: TAppDb;
    Def: TaLetterDef;
    Rep: TaRenderedReport;
    Page: TaRPage;
    PageNo, Y: Integer;
    LineH: Integer;
    Host: TLetterHost;
    Cols: array of TLCol;
    Rows: array of array of Variant;
    RowCount: Integer;
    Total: Double;
    HasTotal: Boolean;
    Bmp: TObject;
    Xml: TStrings;         { ako je zadan, dopis se pise kao WordprocessingML umjesto stranica }
    FirstLetter: Boolean;
    procedure NewPage;
    procedure DocxPara(const AText, AAlign: string; ABold: Boolean);
    procedure DocxTable;
    procedure BuildDocx;
    function Item(const AText: string; AX, AY, AW: Integer; const AAlign: string; ABold: Boolean): TaRItem;
    procedure Bar(AX, AY, AW: Integer);
    function TextWidth(const S: string; ABold: Boolean): Integer;
    procedure Wrap(const AText: string; AWidth: Integer; ABold: Boolean; AOut: TStrings);
    function Expand(const ALine: string): string;
    procedure EmitLine(const ARaw: string);
    procedure EmitTable;
    procedure LoadDetail;
    procedure ParseColumns;
    procedure BuildLetter;
  end;

function TLetterBuilder.TextWidth(const S: string; ABold: Boolean): Integer;
begin
  with TBitmap(Bmp).Canvas do
  begin
    Font.Name := 'DejaVu Sans';
    Font.Height := -Def.FontPx;
    if ABold then Font.Style := [fsBold] else Font.Style := [];
    Result := TextWidth(S);
  end;
end;

procedure TLetterBuilder.NewPage;
begin
  Inc(PageNo);
  Page := TaRPage.Create;
  Rep.Pages.Add(Page);
  Y := TopMargin;
end;

function TLetterBuilder.Item(const AText: string; AX, AY, AW: Integer; const AAlign: string; ABold: Boolean): TaRItem;
begin
  Result := TaRItem.Create;
  Result.Kind := 'Text';
  Result.Text := AText;
  Result.X := AX; Result.Y := AY; Result.W := AW; Result.H := LineH;
  Result.Align := AAlign;
  Result.Bold := ABold;
  Result.FontPx := Def.FontPx;
  Result.FontName := 'DejaVu Sans';
  Result.PageNo := PageNo;
  Page.Items.Add(Result);
end;

procedure TLetterBuilder.Bar(AX, AY, AW: Integer);
var
  It: TaRItem;
begin
  It := TaRItem.Create;
  It.Kind := 'Line';
  It.X := AX; It.Y := AY; It.W := AW; It.H := 1;
  It.PageNo := PageNo;
  It.Color := 0;
  Page.Items.Add(It);
end;

procedure TLetterBuilder.Wrap(const AText: string; AWidth: Integer; ABold: Boolean; AOut: TStrings);
var
  Words: TStringList;
  Cur, Try_: string;
  I: Integer;
begin
  Words := TStringList.Create;
  try
    Words.Delimiter := ' ';
    Words.StrictDelimiter := True;
    Words.DelimitedText := AText;
    Cur := '';
    for I := 0 to Words.Count - 1 do
    begin
      if Cur = '' then Try_ := Words[I] else Try_ := Cur + ' ' + Words[I];
      if (Cur <> '') and (TextWidth(Try_, ABold) > AWidth) then
      begin
        AOut.Add(Cur);
        Cur := Words[I];
      end
      else Cur := Try_;
    end;
    AOut.Add(Cur);
  finally
    Words.Free;
  end;
end;

function TLetterBuilder.Expand(const ALine: string): string;
var
  I, J, K: Integer;
  Tok, Nm, Fmt, Setting: string;
  V: Variant;
  Done: Boolean;
begin
  Result := '';
  I := 1;
  while I <= Length(ALine) do
  begin
    if ALine[I] = '[' then
    begin
      J := I + 1;
      while (J <= Length(ALine)) and (ALine[J] <> ']') do Inc(J);
      if J <= Length(ALine) then
      begin
        Tok := Copy(ALine, I + 1, J - I - 1);
        K := Pos('|', Tok);
        if K > 0 then begin Nm := LowerCase(Trim(Copy(Tok, 1, K - 1))); Fmt := Copy(Tok, K + 1, MaxInt); end
        else begin Nm := LowerCase(Trim(Tok)); Fmt := ''; end;
        Done := True;
        if Nm = 'ukupno' then
        begin
          if Fmt = '' then Fmt := '0.00';
          Result := Result + FormatValue(Total, Fmt);
        end
        else if Nm = 'stavki' then Result := Result + IntToStr(RowCount)
        else if Nm = 'datum' then Result := Result + FormatDateTime('dd.mm.yyyy', Date)
        else if Nm = 'vrijeme' then Result := Result + FormatDateTime('hh:nn', Time)
        else if Nm = 'korisnik' then Result := Result + CurrentUserName
        else if (Copy(Nm, 1, 6) = 'firma_') then
        begin
          Setting := Db.LoadSetting('firma.' + Copy(Nm, 7, MaxInt));
          Result := Result + Setting;
        end
        else if Host.Names.IndexOf(Nm) >= 0 then
          Result := Result + ShowValue(Host.Vals[Host.Names.IndexOf(Nm)], Fmt)
        else Done := False;
        if Done then
        begin
          I := J + 1;
          Continue;
        end;
      end;
    end
    else if ALine[I] = '{' then
    begin
      J := I + 1;
      while (J <= Length(ALine)) and (ALine[J] <> '}') do Inc(J);
      if J <= Length(ALine) then
      begin
        try
          V := EvalExpr(Copy(ALine, I + 1, J - I - 1), Host);
          Result := Result + ShowValue(V, '');
        except
          Result := Result + '#Err';
        end;
        I := J + 1;
        Continue;
      end;
    end;
    Result := Result + ALine[I];
    Inc(I);
  end;
end;

procedure TLetterBuilder.EmitLine(const ARaw: string);
var
  P: Integer;
  Rest, Al: string;
  Bold: Boolean;
  Lines: TStringList;
  I: Integer;
begin
  if Trim(ARaw) = '' then begin Inc(Y, LineH div 2); Exit; end;
  if Trim(ARaw) = '[tablica]' then begin EmitTable; Exit; end;
  P := 1;
  Al := 'left';
  Bold := False;
  while (P <= Length(ARaw)) and (ARaw[P] in ['>', '^', '#']) do
  begin
    case ARaw[P] of
      '>': Al := 'right';
      '^': Al := 'center';
      '#': Bold := True;
    end;
    Inc(P);
  end;
  Rest := Expand(Copy(ARaw, P, MaxInt));
  Lines := TStringList.Create;
  try
    Wrap(Rest, DefPageW - 2 * Margin, Bold, Lines);
    for I := 0 to Lines.Count - 1 do
    begin
      if Y + LineH > DefPageH - BottomMargin then NewPage;
      Item(Lines[I], Margin, Y, DefPageW - 2 * Margin, Al, Bold);
      Inc(Y, LineH);
    end;
  finally
    Lines.Free;
  end;
end;

procedure TLetterBuilder.ParseColumns;
var
  L, Parts: TStringList;
  I, N: Integer;
  S: string;
begin
  SetLength(Cols, 0);
  L := TStringList.Create;
  Parts := TStringList.Create;
  try
    L.Text := Def.Columns;
    for I := 0 to L.Count - 1 do
    begin
      S := Trim(L[I]);
      if (S = '') or (S[1] = '#') then Continue;
      Parts.Clear;
      Parts.Delimiter := '|';
      Parts.StrictDelimiter := True;
      Parts.QuoteChar := #0;
      Parts.DelimitedText := S;
      N := Length(Cols);
      SetLength(Cols, N + 1);
      Cols[N].Field := LowerCase(Trim(Parts[0]));
      if Parts.Count > 1 then Cols[N].Title := Trim(Parts[1]) else Cols[N].Title := Trim(Parts[0]);
      if Parts.Count > 2 then Cols[N].Fmt := Trim(Parts[2]) else Cols[N].Fmt := '';
      if Parts.Count > 3 then Cols[N].Align := LowerCase(Trim(Parts[3])) else Cols[N].Align := '';
      if Parts.Count > 4 then Cols[N].Weight := StrToFloatDef(Trim(Parts[4]), 1, DefaultFormatSettings) else Cols[N].Weight := 1;
      if Cols[N].Weight <= 0 then Cols[N].Weight := 1;
    end;
  finally
    Parts.Free;
    L.Free;
  end;
end;

procedure TLetterBuilder.LoadDetail;
var
  Q: TZQuery;
  I, J, K, Cw: Integer;
  SumW: Double;
  X: Integer;
begin
  RowCount := 0;
  SetLength(Rows, 0);
  Total := 0;
  HasTotal := False;
  if Trim(Def.DetailSql) = '' then Exit;
  Q := Db.NewQuery(ExpandSql(Host, Def.DetailSql));
  try
    Q.Open;
    { bez zadanih stupaca: svi stupci upita }
    if Length(Cols) = 0 then
    begin
      SetLength(Cols, Q.FieldCount);
      for I := 0 to Q.FieldCount - 1 do
      begin
        Cols[I].Field := LowerCase(Q.Fields[I].FieldName);
        Cols[I].Title := Q.Fields[I].FieldName;
        Cols[I].Weight := 1;
      end;
    end;
    while not Q.EOF do
    begin
      SetLength(Rows, RowCount + 1);
      SetLength(Rows[RowCount], Length(Cols));
      for J := 0 to High(Cols) do
      begin
        K := -1;
        for I := 0 to Q.FieldCount - 1 do
          if SameText(Q.Fields[I].FieldName, Cols[J].Field) then K := I;
        if (K < 0) or Q.Fields[K].IsNull then Rows[RowCount][J] := Null
        else if Q.Fields[K].DataType in [ftSmallint, ftInteger, ftLargeint, ftWord, ftAutoInc] then Rows[RowCount][J] := Q.Fields[K].AsLargeInt
        else if Q.Fields[K].DataType in [ftFloat, ftCurrency, ftBCD, ftFMTBcd, ftSingle] then Rows[RowCount][J] := Q.Fields[K].AsFloat
        else Rows[RowCount][J] := Q.Fields[K].AsString;
        if SameText(Def.TotalField, Cols[J].Field) and not VarIsNull(Rows[RowCount][J]) and not VarIsStr(Rows[RowCount][J]) then
        begin
          Total := Total + Double(Rows[RowCount][J]);
          HasTotal := True;
        end;
      end;
      Inc(RowCount);
      Q.Next;
    end;
  finally
    Q.Free;
  end;
  { sirine stupaca prema udjelima }
  SumW := 0;
  for J := 0 to High(Cols) do SumW := SumW + Cols[J].Weight;
  X := Margin;
  for J := 0 to High(Cols) do
  begin
    Cw := Round((DefPageW - 2 * Margin) * Cols[J].Weight / SumW);
    Cols[J].X := X;
    Cols[J].W := Cw;
    Inc(X, Cw);
  end;
end;

procedure TLetterBuilder.EmitTable;
var
  J, R: Integer;
  S, Fmt, Al: string;
  V: Variant;
  TotCol: Integer;

  procedure Header;
  var
    C: Integer;
  begin
    for C := 0 to High(Cols) do
    begin
      Al := Cols[C].Align;
      if Al = '' then Al := 'left';
      Item(Cols[C].Title, Cols[C].X + 3, Y, Cols[C].W - 6, Al, True);
    end;
    Inc(Y, LineH);
    Bar(Margin, Y - 2, DefPageW - 2 * Margin);
    Inc(Y, 3);
  end;

begin
  if Length(Cols) = 0 then Exit;
  if Y + 3 * LineH > DefPageH - BottomMargin then NewPage;
  Header;
  TotCol := -1;
  for J := 0 to High(Cols) do
    if SameText(Def.TotalField, Cols[J].Field) then TotCol := J;
  for R := 0 to RowCount - 1 do
  begin
    if Y + LineH > DefPageH - BottomMargin then begin NewPage; Header; end;
    for J := 0 to High(Cols) do
    begin
      V := Rows[R][J];
      Fmt := Cols[J].Fmt;
      if (Fmt = '') and (VarType(V) in [varDouble, varSingle, varCurrency]) then Fmt := '0.00';
      S := ShowValue(V, Fmt);
      Al := Cols[J].Align;
      if Al = '' then
        if (not VarIsStr(V)) and not VarIsNull(V) then Al := 'right' else Al := 'left';
      Item(S, Cols[J].X + 3, Y, Cols[J].W - 6, Al, False);
    end;
    Inc(Y, LineH);
  end;
  if HasTotal and (TotCol >= 0) then
  begin
    if Y + 2 * LineH > DefPageH - BottomMargin then begin NewPage; Header; end;
    Bar(Margin, Y, DefPageW - 2 * Margin);
    Inc(Y, 3);
    Item(Def.TotalLabel, Cols[0].X + 3, Y, Cols[0].W - 6, 'left', True);
    Fmt := Cols[TotCol].Fmt;
    if Fmt = '' then Fmt := '0.00';
    Al := Cols[TotCol].Align;
    if Al = '' then Al := 'right';
    Item(FormatValue(Total, Fmt), Cols[TotCol].X + 3, Y, Cols[TotCol].W - 6, Al, True);
    Inc(Y, LineH + 10);
  end
  else Inc(Y, 4);
end;

function XmlEsc(const S: string): string;
begin
  Result := StringReplace(S, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
end;

procedure TLetterBuilder.DocxPara(const AText, AAlign: string; ABold: Boolean);
var
  Sz: Integer;
  Pp, Rp: string;
begin
  Sz := Round(Def.FontPx * 0.75 * 2);
  Pp := '';
  if AAlign = 'right' then Pp := '<w:pPr><w:jc w:val="right"/></w:pPr>'
  else if AAlign = 'center' then Pp := '<w:pPr><w:jc w:val="center"/></w:pPr>';
  Rp := '<w:rPr>';
  if ABold then Rp := Rp + '<w:b/>';
  Rp := Rp + '<w:sz w:val="' + IntToStr(Sz) + '"/></w:rPr>';
  Xml.Add('<w:p>' + Pp + '<w:r>' + Rp + '<w:t xml:space="preserve">' + XmlEsc(AText) + '</w:t></w:r></w:p>');
end;

procedure TLetterBuilder.DocxTable;
const
  TotalW = 9638;      { sirina teksta A4 s marginama 2 cm u dvadesetinkama tocke }
var
  J, R, TotCol, Sz: Integer;
  SumW: Double;
  S, Fmt, Al, Cell, Jc: string;
  V: Variant;

  function CellXml(AW: Integer; const AText, AAlign: string; ABold: Boolean): string;
  var
    Pp, Rp: string;
  begin
    Pp := '';
    if AAlign = 'right' then Pp := '<w:pPr><w:jc w:val="right"/></w:pPr>'
    else if AAlign = 'center' then Pp := '<w:pPr><w:jc w:val="center"/></w:pPr>';
    Rp := '<w:rPr>';
    if ABold then Rp := Rp + '<w:b/>';
    Rp := Rp + '<w:sz w:val="' + IntToStr(Sz) + '"/></w:rPr>';
    Result := '<w:tc><w:tcPr><w:tcW w:w="' + IntToStr(AW) + '" w:type="dxa"/></w:tcPr><w:p>' + Pp + '<w:r>' + Rp +
      '<w:t xml:space="preserve">' + XmlEsc(AText) + '</w:t></w:r></w:p></w:tc>';
  end;

begin
  if Length(Cols) = 0 then Exit;
  Sz := Round(Def.FontPx * 0.75 * 2);
  SumW := 0;
  for J := 0 to High(Cols) do SumW := SumW + Cols[J].Weight;
  TotCol := -1;
  for J := 0 to High(Cols) do
    if SameText(Def.TotalField, Cols[J].Field) then TotCol := J;
  Xml.Add('<w:tbl><w:tblPr><w:tblW w:w="' + IntToStr(TotalW) + '" w:type="dxa"/><w:tblBorders>' +
    '<w:top w:val="single" w:sz="4" w:space="0" w:color="808080"/><w:bottom w:val="single" w:sz="4" w:space="0" w:color="808080"/>' +
    '<w:insideH w:val="single" w:sz="4" w:space="0" w:color="C0C0C0"/></w:tblBorders></w:tblPr><w:tblGrid>');
  for J := 0 to High(Cols) do Xml.Add('<w:gridCol w:w="' + IntToStr(Round(TotalW * Cols[J].Weight / SumW)) + '"/>');
  Xml.Add('</w:tblGrid>');
  { zaglavlje }
  Xml.Add('<w:tr>');
  for J := 0 to High(Cols) do
  begin
    Al := Cols[J].Align;
    Xml.Add(CellXml(Round(TotalW * Cols[J].Weight / SumW), Cols[J].Title, Al, True));
  end;
  Xml.Add('</w:tr>');
  for R := 0 to RowCount - 1 do
  begin
    Xml.Add('<w:tr>');
    for J := 0 to High(Cols) do
    begin
      V := Rows[R][J];
      Fmt := Cols[J].Fmt;
      if (Fmt = '') and (VarType(V) in [varDouble, varSingle, varCurrency]) then Fmt := '0.00';
      S := ShowValue(V, Fmt);
      Al := Cols[J].Align;
      if Al = '' then
        if (not VarIsStr(V)) and not VarIsNull(V) then Al := 'right' else Al := 'left';
      Xml.Add(CellXml(Round(TotalW * Cols[J].Weight / SumW), S, Al, False));
    end;
    Xml.Add('</w:tr>');
  end;
  if HasTotal and (TotCol >= 0) then
  begin
    Xml.Add('<w:tr>');
    for J := 0 to High(Cols) do
    begin
      Cell := '';
      Jc := 'left';
      if J = 0 then Cell := Def.TotalLabel;
      if J = TotCol then
      begin
        Fmt := Cols[J].Fmt;
        if Fmt = '' then Fmt := '0.00';
        Cell := FormatValue(Total, Fmt);
        Jc := 'right';
      end;
      Xml.Add(CellXml(Round(TotalW * Cols[J].Weight / SumW), Cell, Jc, True));
    end;
    Xml.Add('</w:tr>');
  end;
  Xml.Add('</w:tbl>');
  Xml.Add('<w:p/>');
end;

procedure TLetterBuilder.BuildDocx;
var
  L: TStringList;
  I, P: Integer;
  Raw, Al: string;
  Bold: Boolean;
begin
  ParseColumns;
  LoadDetail;
  if not FirstLetter then Xml.Add('<w:p><w:r><w:br w:type="page"/></w:r></w:p>');
  FirstLetter := False;
  L := TStringList.Create;
  try
    L.Text := Def.Body;
    for I := 0 to L.Count - 1 do
    begin
      Raw := L[I];
      if Trim(Raw) = '' then begin Xml.Add('<w:p/>'); Continue; end;
      if Trim(Raw) = '[tablica]' then begin DocxTable; Continue; end;
      P := 1;
      Al := 'left';
      Bold := False;
      while (P <= Length(Raw)) and (Raw[P] in ['>', '^', '#']) do
      begin
        case Raw[P] of
          '>': Al := 'right';
          '^': Al := 'center';
          '#': Bold := True;
        end;
        Inc(P);
      end;
      DocxPara(Expand(Copy(Raw, P, MaxInt)), Al, Bold);
    end;
  finally
    L.Free;
  end;
end;

procedure TLetterBuilder.BuildLetter;
var
  L: TStringList;
  I: Integer;
begin
  ParseColumns;
  LoadDetail;
  NewPage;
  L := TStringList.Create;
  try
    L.Text := Def.Body;
    for I := 0 to L.Count - 1 do EmitLine(L[I]);
  finally
    L.Free;
  end;
end;

function RenderLetters(ADb: TAppDb; ADef: TaLetterDef; out AErr: string; const AKey: string): TaRenderedReport;
var
  Q: TZQuery;
  B: TLetterBuilder;
  Sql: string;
  I: Integer;
  Fn: TStringList;
begin
  Result := nil;
  AErr := '';
  if Trim(ADef.Source) = '' then begin AErr := 'Nije zadan izvor primatelja.'; Exit; end;
  Sql := 'SELECT * FROM ' + ADb.SourceFrom(Trim(ADef.Source));
  if Trim(ADef.Filter) <> '' then Sql := Sql + ' WHERE ' + ADef.Filter;
  B := TLetterBuilder.Create;
  B.Db := ADb;
  B.Def := ADef;
  B.LineH := Round(ADef.FontPx * 1.55);
  B.Bmp := TBitmap.Create;
  B.Rep := TaRenderedReport.Create;
  B.Host := TLetterHost.Create;
  B.Host.Db := ADb;
  B.Host.Names := TStringList.Create;
  Fn := B.Host.Names;
  try
    try
      Q := ADb.NewQuery(Sql);
      try
        Q.Open;
        SetLength(B.Host.Vals, Q.FieldCount);
        for I := 0 to Q.FieldCount - 1 do Fn.Add(LowerCase(Q.Fields[I].FieldName));
        while not Q.EOF do
        begin
          if (AKey = '') or ((Q.FieldCount > 0) and (Q.Fields[0].AsString = AKey)) then
          begin
            for I := 0 to Q.FieldCount - 1 do
              if Q.Fields[I].IsNull then B.Host.Vals[I] := Null
              else if Q.Fields[I].DataType in [ftSmallint, ftInteger, ftLargeint, ftWord, ftAutoInc] then B.Host.Vals[I] := Q.Fields[I].AsLargeInt
              else if Q.Fields[I].DataType in [ftFloat, ftCurrency, ftBCD, ftFMTBcd, ftSingle] then B.Host.Vals[I] := Q.Fields[I].AsFloat
              else B.Host.Vals[I] := Q.Fields[I].AsString;
            B.BuildLetter;
          end;
          Q.Next;
        end;
      finally
        Q.Free;
      end;
      Result := B.Rep;
      B.Rep := nil;
    except
      on E: Exception do
      begin
        AErr := E.Message;
        FreeAndNil(Result);
      end;
    end;
  finally
    B.Rep.Free;
    B.Host.Names.Free;
    B.Host.Free;
    B.Bmp.Free;
    B.Free;
  end;
end;

function ExportLettersDocx(ADb: TAppDb; ADef: TaLetterDef; const AFile: string; out AErr: string; const AKey: string): Boolean;
var
  Q: TZQuery;
  B: TLetterBuilder;
  Sql, Doc: string;
  I: Integer;
  Z: TZipper;
  Ms: array[0..2] of TStringStream;
  Xml: TStringList;
begin
  Result := False;
  AErr := '';
  if Trim(ADef.Source) = '' then begin AErr := 'Nije zadan izvor primatelja.'; Exit; end;
  Sql := 'SELECT * FROM ' + ADb.SourceFrom(Trim(ADef.Source));
  if Trim(ADef.Filter) <> '' then Sql := Sql + ' WHERE ' + ADef.Filter;
  Xml := TStringList.Create;
  B := TLetterBuilder.Create;
  B.Db := ADb;
  B.Def := ADef;
  B.LineH := Round(ADef.FontPx * 1.55);
  B.Bmp := TBitmap.Create;
  B.Xml := Xml;
  B.FirstLetter := True;
  B.Host := TLetterHost.Create;
  B.Host.Db := ADb;
  B.Host.Names := TStringList.Create;
  try
    try
      Q := ADb.NewQuery(Sql);
      try
        Q.Open;
        SetLength(B.Host.Vals, Q.FieldCount);
        for I := 0 to Q.FieldCount - 1 do B.Host.Names.Add(LowerCase(Q.Fields[I].FieldName));
        while not Q.EOF do
        begin
          if (AKey = '') or ((Q.FieldCount > 0) and (Q.Fields[0].AsString = AKey)) then
          begin
            for I := 0 to Q.FieldCount - 1 do
              if Q.Fields[I].IsNull then B.Host.Vals[I] := Null
              else if Q.Fields[I].DataType in [ftSmallint, ftInteger, ftLargeint, ftWord, ftAutoInc] then B.Host.Vals[I] := Q.Fields[I].AsLargeInt
              else if Q.Fields[I].DataType in [ftFloat, ftCurrency, ftBCD, ftFMTBcd, ftSingle] then B.Host.Vals[I] := Q.Fields[I].AsFloat
              else B.Host.Vals[I] := Q.Fields[I].AsString;
            B.BuildDocx;
          end;
          Q.Next;
        end;
      finally
        Q.Free;
      end;
      if Xml.Count = 0 then begin AErr := 'Nema dopisa za ispis (izvor je prazan).'; Exit; end;
      Doc := '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>' + Xml.Text +
        '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1134" w:header="708" w:footer="708" w:gutter="0"/></w:sectPr></w:body></w:document>';
      Ms[0] := TStringStream.Create('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">' +
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>' +
        '<Default Extension="xml" ContentType="application/xml"/>' +
        '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>');
      Ms[1] := TStringStream.Create('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>');
      Ms[2] := TStringStream.Create(Doc);
      Z := TZipper.Create;
      try
        Z.FileName := AFile;
        Z.Entries.AddFileEntry(Ms[0], '[Content_Types].xml');
        Z.Entries.AddFileEntry(Ms[1], '_rels/.rels');
        Z.Entries.AddFileEntry(Ms[2], 'word/document.xml');
        ForceDirectories(ExtractFilePath(ExpandFileName(AFile)));
        Z.SaveToFile(AFile);
        Result := True;
      finally
        Z.Free;
        for I := 0 to 2 do Ms[I].Free;
      end;
    except
      on E: Exception do AErr := E.Message;
    end;
  finally
    B.Host.Names.Free;
    B.Host.Free;
    B.Bmp.Free;
    B.Free;
    Xml.Free;
  end;
end;

function LetterPlainText(ADb: TAppDb; ADef: TaLetterDef; out AErr: string): string;
var
  Rep: TaRenderedReport;
  P, I, LastY: Integer;
  It: TaRItem;
  Line: string;

  procedure Flush;
  begin
    if Line <> '' then Result := Result + Line + LineEnding;
    Line := '';
  end;

begin
  Result := '';
  Rep := RenderLetters(ADb, ADef, AErr);
  if Rep = nil then Exit;
  try
    for P := 0 to Rep.PageCount - 1 do
    begin
      if P > 0 then Result := Result + '---' + LineEnding;
      LastY := -1;
      Line := '';
      for I := 0 to Rep.Page(P).Items.Count - 1 do
      begin
        It := TaRItem(Rep.Page(P).Items[I]);
        if It.Kind <> 'Text' then Continue;
        if It.Y <> LastY then begin Flush; LastY := It.Y; end;
        if Line <> '' then Line := Line + ' | ';
        Line := Line + It.Text;
      end;
      Flush;
    end;
  finally
    Rep.Free;
  end;
end;

end.
