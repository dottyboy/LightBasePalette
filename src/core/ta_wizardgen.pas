unit ta_wizardgen;
{ Generators behind the form and report wizards. They turn a record source and
  a list of fields into a ready definition, using the field types (so dates,
  currency and Yes/No get matching controls, formats and alignment) and
  foreign keys (which become lookup combo boxes). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, DB, contnrs, ZDataset, LazUTF8, ta_meta, ta_types, ta_formdef, ta_reportdef,
  ta_reportengine, ta_wizardframework;

type
  TaSourceField = record
    Name: string;
    LType: TaLogicalType;
    Format: string;
    Decimals: Integer;
    Caption, Descr: string;      { iz rjecnika podataka }
    ColWidth: Integer;
  end;
  TaSourceFields = array of TaSourceField;

function SourceFieldList(ADb: TAppDb; const ASource: string): TaSourceFields;
{ oznaka iz rjecnika podataka, inace ljepsi naziv polja }
function CaptionOf(const AField: TaSourceField): string;
type
  TaFormLayout = (flOneColumn, flTwoColumns, flDatasheet, flSplit);

  TaFormOptions = record
    Source, Name, Title: string;
    Fields: TStrings;
    Layout: TaFormLayout;
    SubTables: TStrings;     { child tables to embed as subforms (may be nil) }
    FilterFields: TStrings;  { polja za filter iznad grida }
    AddRefreshButton: Boolean; { dodaj gumb Osvježi }
    AddClearButton: Boolean;   { dodaj gumb Očisti filtere }
  end;

  { master record on top, detail rows in a subform, totals under it }
  TaMDOptions = record
    Master, Detail, Name, Title: string;
    MasterFields, DetailFields: TStrings;
    DetailAsForm: Boolean;   { detail rows live in a saved datasheet form instead of a plain grid }
    SumField: string;        { '' = no total }
    ShowCount: Boolean;
    FkCol, ParentCol: string;   { '' = taken from the foreign key }
  end;

  TaMDResult = record
    MasterForm, DetailForm: TaFormDef;   { DetailForm is nil unless DetailAsForm }
    DetailFormName, QueryName, QuerySql, Error: string;
  end;

type
  TaReportKind = (rkTabular, rkColumnar, rkLabels, rkSummary);

  TaReportOptions = record
    Source, Name, Title, GroupField, SortField: string;
    Fields: TStrings;
    Kind: TaReportKind;
    Descending, Sums: Boolean;
    PageBreakPerRecord: Boolean;   { columnar: one record per page }
    LabelColumns: Integer;         { labels: 2..4 across }
    { labels: one expression per line, e.g. [ime] & " " & [prezime]; nil = the fields as they are }
    LabelLines: TStrings;
    { tablicni izvjestaj: izricite sirine stupaca, 'polje=tocke,polje=tocke'; ostali stupci dobivaju sirinu prema sadrzaju }
    Widths: string;
  end;

  TaMDReportResult = record
    Def: TaReportDef;
    QueryName, QuerySql, Error: string;
  end;

type
  TaMDDetail = record
    Table: string;
    Fields: TStrings;          { subset of columns; nil or empty = all }
    SumField: string;
    ShowCount: Boolean;
    FkCol, ParentCol: string;  { '' = taken from the foreign key }
  end;

  { one master and any number of detail tables }
  TaMDMulti = record
    Master, Name, Title: string;
    MasterFields: TStrings;
    Details: array of TaMDDetail;
    DetailAsForm: Boolean;
    UseTabs: Boolean;          { details on tab pages instead of one under the other }
  end;

  TaMDItem = record
    Table, FormName, QueryName, QuerySql: string;
    Form: TaFormDef;           { detail datasheet form, nil unless DetailAsForm }
  end;

  TaMDMultiResult = record
    MasterForm: TaFormDef;
    Items: array of TaMDItem;
    Error: string;
  end;

function BuildMasterDetailMulti(ADb: TAppDb; const AOpt: TaMDMulti): TaMDMultiResult;
{ SELECT key, name FROM referenced table - what a lookup shows for a foreign key }
function LookupQuerySql(ADb: TAppDb; const ARefTable, ARefCol: string): string;
function BuildFormEx(ADb: TAppDb; const AOpt: TaFormOptions): TaFormDef;
function BuildReportEx(ADb: TAppDb; const AOpt: TaReportOptions): TaReportDef;
{ report over master JOIN detail (a saved query is made for it), grouped by the master }
function BuildMasterDetailReport(ADb: TAppDb; const AOpt: TaMDOptions): TaMDReportResult;
{ Izvjesce master sa vise detail tablica: svaki detail je podizvjesce ispod zapisa mastera.
  AChildren dobiva nazive podizvjesca, Objects[i] = TaReportDef (pozivatelj sprema i oslobada). }
function BuildMasterDetailReportMulti(ADb: TAppDb; const AOpt: TaMDMulti; APageBreak: Boolean;
  AChildren: TStringList; out AError: string): TaReportDef;
function BuildMasterDetail(ADb: TAppDb; const AOpt: TaMDOptions): TaMDResult;
{ tables that hold a foreign key to AMaster: AChild|fkCol|parentCol }
function ChildRelations(ADb: TAppDb; const AMaster: string): TStringList;
function BuildFormDef(ADb: TAppDb; const ASource, AName: string; AFields: TStrings;
  ATwoColumns: Boolean): TaFormDef;
function BuildReportDef(ADb: TAppDb; const ASource, AName, ATitle: string; AFields: TStrings;
  const AGroupField, ASortField: string; ADescending, ASums: Boolean; const AWidths: string = ''; AGrowLines: Integer = 1): TaReportDef;
function PrettyName(const AField: string): string;
{ stupac po kojem se redak druge tablice prepoznaje (naziv, ime, prvi tekst) }
function DisplayColumn(ADb: TAppDb; const ATable, AKey: string): string;

function SuggestSolutions(ADb: TAppDb; const ASource, ATitle: string; const AFields: TaSourceFields): TaWizardSolutions;
function BuildFormWithFilters(ADb: TAppDb; const AOpt: TaFormOptions): TaFormDef;
function BuildFglScript(ADb: TAppDb; const ASource, ATitle, AScriptType: string; AFields: TStrings): string;
procedure RegisterStandardWizardSolutions;

implementation

uses
  ta_i18n;


{ rijeci koje se u hrvatskim bazama pisu bez dijakritika (nazivi tablica i stupaca): natpis dobiva ispravno pisanje }
const
  HrWords: array[0..44, 0..1] of string = (
    ('racun', 'račun'), ('racuni', 'računi'), ('predracun', 'predračun'), ('predracuni', 'predračuni'), ('nacin', 'način'),
    ('placanja', 'plaćanja'), ('placeno', 'plaćeno'), ('placa', 'plaća'), ('postanski', 'poštanski'), ('drzava', 'država'),
    ('dospijece', 'dospijeće'), ('kolicina', 'količina'), ('kolicine', 'količine'), ('narudzbenica', 'narudžbenica'),
    ('narudzbenice', 'narudžbenice'), ('dobavljac', 'dobavljač'), ('isporucena', 'isporučena'), ('prihvacena', 'prihvaćena'),
    ('zavrsetka', 'završetka'), ('pocetka', 'početka'), ('troskovi', 'troškovi'), ('sifra', 'šifra'), ('prekoracenje', 'prekoračenje'),
    ('rodjenja', 'rođenja'), ('postotak', 'postotak'), ('oib', 'OIB'), ('iban', 'IBAN'), ('pdv', 'PDV'), ('jmj', 'JMJ'),
    ('ugovor', 'ugovor'), ('izvjesce', 'izvješće'), ('izvjesca', 'izvješća'), ('uplate', 'uplate'), ('cjenik', 'cjenik'),
    ('skladiste', 'skladište'), ('dostavnica', 'dostavnica'), ('dnevnica', 'dnevnica'), ('isplaceno', 'isplaćeno'),
    ('zaposlenik', 'zaposlenik'), ('dokument', 'dokument'), ('mjesto', 'mjesto'), ('ocekivano', 'očekivano'), ('cijena', 'cijena'), ('povrsina', 'površina'), ('prosjecna', 'prosječna'));

function PrettyName(const AField: string): string;
var
  Words: TStringList;
  I, J: Integer;
begin
  Words := TStringList.Create;
  try
    Words.Delimiter := ' ';
    Words.StrictDelimiter := True;
    { veza na drugu tablicu: "dobavljac_id" je u natpisu samo "Dobavljač" }
    if (Length(AField) > 3) and (LowerCase(Copy(AField, Length(AField) - 2, 3)) = '_id') then
      Words.DelimitedText := StringReplace(Copy(AField, 1, Length(AField) - 3), '_', ' ', [rfReplaceAll])
    else
      Words.DelimitedText := StringReplace(AField, '_', ' ', [rfReplaceAll]);
    for I := 0 to Words.Count - 1 do
      for J := 0 to High(HrWords) do
        if SameText(Words[I], HrWords[J, 0]) then begin Words[I] := HrWords[J, 1]; Break; end;
    Result := Words.DelimitedText;
  finally
    Words.Free;
  end;
  if Result <> '' then Result := UpperCase(Copy(Result, 1, 1)) + Copy(Result, 2, MaxInt);
end;

function Ident(const S: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(S) do
    if S[I] in ['A'..'Z', 'a'..'z', '0'..'9', '_'] then Result := Result + S[I]
    else Result := Result + '_';
  if (Result = '') or (Result[1] in ['0'..'9']) then Result := 'f' + Result;
end;

function TypeFromDataType(T: TFieldType): TaLogicalType;
begin
  case T of
    ftSmallint, ftInteger, ftLargeint, ftWord, ftAutoInc: Result := ltInteger;
    ftFloat, ftCurrency, ftBCD, ftFMTBcd, ftSingle: Result := ltDecimal;
    ftBoolean: Result := ltYesNo;
    ftDate, ftDateTime, ftTimeStamp: Result := ltDate;
    ftMemo, ftWideMemo: Result := ltText;   { SQLite TEXT arrives as memo; only the field type says Memo }
  else
    Result := ltText;
  end;
end;

function SourceFieldList(ADb: TAppDb; const ASource: string): TaSourceFields;
var
  Q: TZQuery;
  Metas: TFPObjectList;
  I, J: Integer;
  M: TaFieldMeta;
begin
  SetLength(Result, 0);
  if ADb.LoadObject('_sys_queries', ASource) = '' then Metas := ADb.LoadFieldMetas(ASource)
  else Metas := TFPObjectList.Create(True);
  Inc(ADb.QuietParams);
  Q := ADb.NewQuery('SELECT * FROM ' + ADb.SourceFrom(ASource) + ' LIMIT 1');
  Dec(ADb.QuietParams);
  try
    Q.Open;
    SetLength(Result, Q.FieldCount);
    for I := 0 to Q.FieldCount - 1 do
    begin
      Result[I].Name := Q.Fields[I].FieldName;
      Result[I].LType := TypeFromDataType(Q.Fields[I].DataType);
      Result[I].Decimals := 2;
      Result[I].Format := '';
      Result[I].Caption := '';
      Result[I].Descr := '';
      Result[I].ColWidth := 0;
      for J := 0 to Metas.Count - 1 do
      begin
        M := TaFieldMeta(Metas[J]);
        if SameText(M.FieldName, Result[I].Name) then
        begin
          Result[I].LType := M.LType;
          Result[I].Format := M.Format;
          Result[I].Decimals := M.Decimals;
          Result[I].Caption := M.Caption;
          Result[I].Descr := M.Description;
          Result[I].ColWidth := M.ColWidth;
        end;
      end;
    end;
  finally
    Q.Free;
    Metas.Free;
  end;
end;

function CaptionOf(const AField: TaSourceField): string;
begin
  if Trim(AField.Caption) <> '' then Result := Trim(AField.Caption)
  else Result := PrettyName(AField.Name);
end;

function FindField(const AList: TaSourceFields; const AName: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(AList) do
    if SameText(AList[I].Name, AName) then Exit(I);
  Result := -1;
end;

{ First text column of the referenced table: what a person recognises a row by. }
function DisplayColumn(ADb: TAppDb; const ATable, AKey: string): string;
var
  L: TaSourceFields;
  I: Integer;
begin
  Result := AKey;
  try
    L := SourceFieldList(ADb, ATable);
  except
    Exit;
  end;
  { a column that is obviously the name wins over the first text column (e.g. a code); then columns
    that contain a name (CompanyName, LastName, ProductName), then a title }
  for I := 0 to High(L) do
    if SameText(L[I].Name, 'naziv') or SameText(L[I].Name, 'name') or SameText(L[I].Name, 'ime') then Exit(L[I].Name);
  for I := 0 to High(L) do
    if (L[I].LType in [ltText, ltMemo]) and not SameText(L[I].Name, AKey) and
       ((Pos('name', LowerCase(L[I].Name)) > 0) or (Pos('naziv', LowerCase(L[I].Name)) > 0) or (Pos('prezime', LowerCase(L[I].Name)) > 0)) then Exit(L[I].Name);
  for I := 0 to High(L) do
    if SameText(L[I].Name, 'title') then Exit(L[I].Name);
  for I := 0 to High(L) do
    if (L[I].LType in [ltText, ltMemo]) and not SameText(L[I].Name, AKey) then Exit(L[I].Name);
end;

function LookupSql(ADb: TAppDb; const AFkTable, AFkTo: string): string;
var
  D: string;
begin
  D := DisplayColumn(ADb, AFkTable, AFkTo);
  Result := 'SELECT ' + ADb.QuoteId(AFkTo) + ', ' + ADb.QuoteId(D) + ' FROM ' +
    ADb.QuoteId(AFkTable) + ' ORDER BY ' + ADb.QuoteId(D);
end;

function SumFormat(const F: TaSourceField): string; forward;

function ChildRelations(ADb: TAppDb; const AMaster: string): TStringList;
var
  R: TaRelations;
  I: Integer;
begin
  Result := TStringList.Create;
  R := ADb.AllRelations;
  for I := 0 to High(R) do
    if SameText(R[I].Parent, AMaster) then
      Result.Add(R[I].Child + '|' + R[I].ChildCol + '|' + R[I].ParentCol);
end;

function IsNumericLike(AType: TaLogicalType): Boolean;
begin
  Result := AType in [ltInteger, ltDecimal, ltCurrency, ltAutoNumber, ltYesNo];
end;

function LookupQuerySql(ADb: TAppDb; const ARefTable, ARefCol: string): string;
begin
  Result := LookupSql(ADb, ARefTable, ARefCol);
end;

function BuildFormEx(ADb: TAppDb; const AOpt: TaFormOptions): TaFormDef;
var
  All: TaSourceFields;
  Fks, Parts: TStringList;
  I, Idx, W, H, Y, X, X0, ColW, ColX, LabelW, MaxRight, RowH, Col, K, Fk, J: Integer;
  Lbl, Ctl: TaControlDef;
  Kind, RowSrc, Capt: string;
  Two, Span: Boolean;
  Rels: TStringList;
  Pn: TStringList;
begin
  Result := TaFormDef.Create;
  Result.Name := AOpt.Name;
  Result.Caption := AOpt.Title;
  if Result.Caption = '' then Result.Caption := AOpt.Name;
  Result.RecordSource := AOpt.Source;
  case AOpt.Layout of
    flDatasheet:
      begin
        Result.ViewMode := 'datasheet';
        { sirina prema broju stupaca (oko 110 px po stupcu, najvise 1100) }
        Result.Width := 640;
        if AOpt.Fields <> nil then K := AOpt.Fields.Count else K := Length(SourceFieldList(ADb, AOpt.Source));
        if K * 110 + 40 > Result.Width then Result.Width := K * 110 + 40;
        if Result.Width > 1100 then Result.Width := 1100;
        Result.Height := 360;
        Exit;
      end;
    flSplit: Result.ViewMode := 'split';
  end;
  All := SourceFieldList(ADb, AOpt.Source);
  if ADb.LoadObject('_sys_queries', AOpt.Source) = '' then Fks := ADb.ForeignKeys(AOpt.Source)
  else Fks := TStringList.Create;
  Parts := TStringList.Create;
  Parts.Delimiter := '|';
  Parts.StrictDelimiter := True;
  Two := AOpt.Layout = flTwoColumns;
  try
    { label column width from the longest caption }
    LabelW := 90;
    for I := 0 to AOpt.Fields.Count - 1 do
    begin
      Idx := FindField(All, AOpt.Fields[I]);
      if Idx >= 0 then Capt := CaptionOf(All[Idx]) else Capt := PrettyName(AOpt.Fields[I]);
      if Length(Capt) * 7 + 16 > LabelW then LabelW := Length(Capt) * 7 + 16;
    end;
    if LabelW > 220 then LabelW := 220;
    ColW := LabelW + 8 + 270;
    MaxRight := 0;
    Y := 14;
    if AOpt.Title <> '' then
    begin
      Lbl := TaControlDef.Create;
      Lbl.Kind := 'Label';
      Lbl.Name := 'lblNaslov';
      Lbl.Caption := Result.Caption;
      Lbl.Bold := True;
      Lbl.SetX('fontSize', '14');
      Lbl.Left := 16; Lbl.Top := 10; Lbl.Width := 480; Lbl.Height := 28;
      Result.Add(Lbl);
      Lbl := TaControlDef.Create;
      Lbl.Kind := 'Line';
      Lbl.Name := 'lnNaslov';
      Lbl.Left := 16; Lbl.Top := 42; Lbl.Width := 480; Lbl.Height := 2;
      Result.Add(Lbl);
      Y := 56;
    end;
    Col := 0;
    RowH := 0;
    for I := 0 to AOpt.Fields.Count - 1 do
    begin
      Idx := -1;
      for J := 0 to High(All) do
        if SameText(All[J].Name, AOpt.Fields[I]) then Idx := J;
      if Idx < 0 then Continue;
      Kind := 'TextBox';
      H := 24;
      W := 260;
      RowSrc := '';
      Span := False;
      for Fk := 0 to Fks.Count - 1 do
      begin
        Parts.DelimitedText := Fks[Fk];
        if (Parts.Count = 3) and SameText(Parts[0], All[Idx].Name) then
        begin
          Kind := 'ComboBox';
          RowSrc := LookupSql(ADb, Parts[1], Parts[2]);
        end;
      end;
      if Kind = 'TextBox' then
        case All[Idx].LType of
          ltYesNo: begin Kind := 'CheckBox'; W := 48; end;
          ltDate: W := 120;
          ltTime: W := 90;
          ltDateTime: W := 170;
          ltInteger, ltAutoNumber: W := 110;
          ltDecimal, ltCurrency: W := 130;
          ltMemo: begin Kind := 'MemoBox'; H := 72; Span := True; end;
          ltPicture: begin Kind := 'Image'; W := 130; H := 130; end;
        end;
      { two-column layout: memo fields get a row of their own }
      if Two and Span and (Col = 1) then begin Inc(Y, RowH + 10); Col := 0; RowH := 0; end;
      if Two and not Span then X0 := 16 + Col * (ColW + 24) else X0 := 16;
      if Two and Span then W := 2 * ColW + 24 - LabelW - 8;
      if (not Two) and (W > 260) then W := 260;
      if (not Two) and Span then W := 340;
      Lbl := TaControlDef.Create;
      Lbl.Kind := 'Label';
      Lbl.Name := Result.UniqueName('lbl' + Ident(All[Idx].Name) + '_');
      Lbl.Caption := CaptionOf(All[Idx]);
      Lbl.Left := X0; Lbl.Top := Y + 2; Lbl.Width := LabelW; Lbl.Height := 22;
      Result.Add(Lbl);
      Ctl := TaControlDef.Create;
      Ctl.Kind := Kind;
      Ctl.Left := X0 + LabelW + 8;
      Ctl.Top := Y;
      Ctl.Width := W;
      Ctl.Height := H;
      Ctl.ControlSource := All[Idx].Name;
      Ctl.RowSource := RowSrc;
      Ctl.Name := Result.UniqueName(Copy(Kind, 1, 3) + Ident(All[Idx].Name) + '_');
      { the key is shown but not edited }
      if All[Idx].LType = ltAutoNumber then Ctl.SetX('locked', '1');
      if Trim(All[Idx].Descr) <> '' then Ctl.SetX('tip', Trim(All[Idx].Descr));
      Result.Add(Ctl);
      if Ctl.Left + Ctl.Width > MaxRight then MaxRight := Ctl.Left + Ctl.Width;
      if H > RowH then RowH := H;
      if Two and not Span then
      begin
        Inc(Col);
        if Col = 2 then begin Inc(Y, RowH + 10); Col := 0; RowH := 0; end;
      end
      else begin Inc(Y, H + 10); Col := 0; RowH := 0; end;
    end;
    if Two and (Col = 1) then Inc(Y, RowH + 10);
    if MaxRight < 480 then MaxRight := 480;
    { subforms for the related tables }
    if (AOpt.SubTables <> nil) and (AOpt.SubTables.Count > 0) then
    begin
      Rels := ChildRelations(ADb, AOpt.Source);
      try
        for K := 0 to AOpt.SubTables.Count - 1 do
          for J := 0 to Rels.Count - 1 do
          begin
            Parts.DelimitedText := Rels[J];
            if (Parts.Count = 3) and SameText(Parts[0], AOpt.SubTables[K]) then
            begin
              Inc(Y, 6);
              Lbl := TaControlDef.Create;
              Lbl.Kind := 'Label';
              Lbl.Name := Result.UniqueName('lblPod');
              Lbl.Caption := PrettyName(Parts[0]);
              Lbl.Bold := True;
              Lbl.Left := 16; Lbl.Top := Y; Lbl.Width := 300; Lbl.Height := 20;
              Result.Add(Lbl);
              Ctl := TaControlDef.Create;
              Ctl.Kind := 'Subform';
              Ctl.Name := Result.UniqueName('sub' + Ident(Parts[0]) + '_');
              Ctl.RowSource := Parts[0];
              Ctl.LinkMaster := Parts[2];
              Ctl.LinkChild := Parts[1];
              Ctl.Left := 16; Ctl.Top := Y + 22; Ctl.Width := MaxRight - 16; Ctl.Height := 170;
              Result.Add(Ctl);
              Inc(Y, 22 + 170 + 8);
              Break;
            end;
          end;
      finally
        Rels.Free;
      end;
    end;
    Result.Width := MaxRight + 20;
    Result.Height := Y + 12;
    if Result.Height < 120 then Result.Height := 120;
    Pn := nil;
  finally
    Parts.Free;
    Fks.Free;
  end;
end;

function BuildFormDef(ADb: TAppDb; const ASource, AName: string; AFields: TStrings;
  ATwoColumns: Boolean): TaFormDef;
var
  O: TaFormOptions;
begin
  O.Source := ASource;
  O.Name := AName;
  O.Title := '';
  O.Fields := AFields;
  O.SubTables := nil;
  if ATwoColumns then O.Layout := flTwoColumns else O.Layout := flOneColumn;
  Result := BuildFormEx(ADb, O);
end;

function QuoteCrit(const AFk, AParentCol: string; ANumeric: Boolean): string;
begin
  { an expression that yields a SQL criteria text: "kupac_id = " & [id] }
  if ANumeric then Result := '"' + AFk + ' = " & [' + AParentCol + ']'
  else Result := '"' + AFk + ' = ''" & [' + AParentCol + '] & "''"';
end;

function FindRel(ADb: TAppDb; const AMaster, ADetail: string; out AFk, APc: string): Boolean;
var
  Rels, Parts: TStringList;
  I: Integer;
begin
  Result := False;
  Rels := ChildRelations(ADb, AMaster);
  Parts := TStringList.Create;
  Parts.Delimiter := '|';
  Parts.StrictDelimiter := True;
  try
    for I := 0 to Rels.Count - 1 do
    begin
      Parts.DelimitedText := Rels[I];
      if (Parts.Count = 3) and SameText(Parts[0], ADetail) then
      begin
        AFk := Parts[1];
        APc := Parts[2];
        Exit(True);
      end;
    end;
  finally
    Parts.Free;
    Rels.Free;
  end;
end;

procedure FreeMulti(var R: TaMDMultiResult);
var
  I: Integer;
begin
  R.MasterForm.Free;
  R.MasterForm := nil;
  for I := 0 to High(R.Items) do R.Items[I].Form.Free;
  SetLength(R.Items, 0);
end;

function BuildMasterDetailMulti(ADb: TAppDb; const AOpt: TaMDMulti): TaMDMultiResult;
var
  Mf: TaFormDef;
  O: TaFormOptions;
  I, J, Y, Bottom, W, X0, Y0, PW, SubH, Sf, N, TabH: Integer;
  Dt: TaMDDetail;
  Fk, Pc, DetailSrc, Fname, Qname, Qsql, Caps, Cont, Sql, TabName: string;
  Det, MasterAll: TaSourceFields;
  Numeric, AllFields, Tabbed, Single: Boolean;
  Tab, Sub, C, Lbl: TaControlDef;
  Item: TaMDItem;

  procedure InContainer(ADef: TaControlDef; APage: Integer);
  begin
    if Tabbed then
    begin
      ADef.SetX('container', TabName);
      ADef.SetX('page', IntToStr(APage));
    end;
  end;

begin
  Result.MasterForm := nil;
  SetLength(Result.Items, 0);
  Result.Error := '';
  if Length(AOpt.Details) = 0 then begin Result.Error := 'Odaberi barem jednu detail tablicu.'; Exit; end;
  O.Source := AOpt.Master;
  O.Name := AOpt.Name;
  O.Title := AOpt.Title;
  O.Fields := AOpt.MasterFields;
  O.Layout := flOneColumn;
  O.SubTables := nil;
  Mf := BuildFormEx(ADb, O);
  if Mf.Width < 820 then Mf.Width := 820;   { stavke trebaju mjesta za stupce }
  Result.MasterForm := Mf;
  Single := Length(AOpt.Details) = 1;
  Tabbed := AOpt.UseTabs and not Single;
  MasterAll := SourceFieldList(ADb, AOpt.Master);
  Bottom := 0;
  for I := 0 to Mf.Count - 1 do
    if Mf[I].Top + Mf[I].Height > Bottom then Bottom := Mf[I].Top + Mf[I].Height;
  Y := Bottom + 14;
  W := Mf.Width - 32;
  SubH := 200;
  TabName := '';
  if Tabbed then
  begin
    Caps := '';
    for I := 0 to High(AOpt.Details) do
    begin
      if Caps <> '' then Caps := Caps + ';';
      Caps := Caps + PrettyName(AOpt.Details[I].Table);
    end;
    Tab := TaControlDef.Create;
    Tab.Kind := 'TabControl';
    Tab.Name := Mf.UniqueName('tabDetalji');
    Tab.RowSource := Caps;
    Tab.Left := 16; Tab.Top := Y; Tab.Width := W; Tab.Height := SubH + 90;
    Mf.Add(Tab);
    TabName := Tab.Name;
    TabH := Tab.Height;
  end
  else TabH := 0;

  for I := 0 to High(AOpt.Details) do
  begin
    Dt := AOpt.Details[I];
    Fk := Dt.FkCol;
    Pc := Dt.ParentCol;
    if ((Fk = '') or (Pc = '')) and not FindRel(ADb, AOpt.Master, Dt.Table, Fk, Pc) then
    begin
      Result.Error := 'Između ' + AOpt.Master + ' i ' + Dt.Table + ' nema veze (stranog ključa). Dodaj je u Relacije.';
      FreeMulti(Result);
      Exit;
    end;
    Det := SourceFieldList(ADb, Dt.Table);
    AllFields := (Dt.Fields = nil) or (Dt.Fields.Count = 0) or (Dt.Fields.Count >= Length(Det));
    DetailSrc := Dt.Table;
    if Single then begin Fname := AOpt.Name + '_detalji'; Qname := AOpt.Name + '_detalji_q'; end
    else begin Fname := AOpt.Name + '_' + Ident(Dt.Table) + '_detalji'; Qname := Fname + '_q'; end;
    Item.Table := Dt.Table;
    Item.FormName := '';
    Item.QueryName := '';
    Item.QuerySql := '';
    Item.Form := nil;
    if not AllFields then
    begin
      Sql := '';
      for J := 0 to Dt.Fields.Count - 1 do
      begin
        if Sql <> '' then Sql := Sql + ', ';
        Sql := Sql + ADb.QuoteId(Dt.Fields[J]);
      end;
      { the link column must stay in the query or the subform cannot filter }
      if Dt.Fields.IndexOf(Fk) < 0 then Sql := Sql + ', ' + ADb.QuoteId(Fk);
      Item.QueryName := Qname;
      Item.QuerySql := 'SELECT ' + Sql + ' FROM ' + ADb.QuoteId(Dt.Table);
      DetailSrc := Qname;
    end;
    if AOpt.DetailAsForm then
    begin
      Item.FormName := Fname;
      Item.Form := TaFormDef.Create;
      Item.Form.Name := Fname;
      Item.Form.Caption := PrettyName(Dt.Table);
      Item.Form.RecordSource := DetailSrc;
      Item.Form.ViewMode := 'datasheet';
      Item.Form.NavButtons := False;
      Item.Form.Width := Mf.Width;
      Item.Form.Height := SubH;
    end;
    N := Length(Result.Items);
    SetLength(Result.Items, N + 1);
    Result.Items[N] := Item;

    { where this detail goes }
    if Tabbed then begin X0 := 8; Y0 := 8; PW := W - 24; end
    else begin X0 := 16; Y0 := Y; PW := W; end;
    if not Tabbed then
    begin
      Lbl := TaControlDef.Create;
      Lbl.Kind := 'Label';
      Lbl.Name := Mf.UniqueName('lblDetalji');
      Lbl.Caption := PrettyName(Dt.Table);
      Lbl.Bold := True;
      Lbl.Left := X0; Lbl.Top := Y0; Lbl.Width := 300; Lbl.Height := 20;
      Mf.Add(Lbl);
      Inc(Y0, 22);
    end;
    Sub := TaControlDef.Create;
    Sub.Kind := 'Subform';
    Sub.Name := Mf.UniqueName('subDetalji');
    if AOpt.DetailAsForm then Sub.RowSource := Fname else Sub.RowSource := DetailSrc;
    Sub.LinkMaster := Pc;
    Sub.LinkChild := Fk;
    Sub.Left := X0; Sub.Top := Y0; Sub.Width := PW; Sub.Height := SubH - 24 * Ord(Tabbed);
    InContainer(Sub, I);
    Mf.Add(Sub);
    Inc(Y0, Sub.Height + 8);

    { totals follow the current master record }
    Numeric := True;
    for J := 0 to High(MasterAll) do
      if SameText(MasterAll[J].Name, Pc) then Numeric := IsNumericLike(MasterAll[J].LType);
    if Dt.ShowCount then
    begin
      Lbl := TaControlDef.Create;
      Lbl.Kind := 'Label';
      Lbl.Name := Mf.UniqueName('lblBroj');
      Lbl.Caption := Tr('Item count:');
      Lbl.Left := X0; Lbl.Top := Y0 + 2; Lbl.Width := 100; Lbl.Height := 22;
      InContainer(Lbl, I);
      Mf.Add(Lbl);
      C := TaControlDef.Create;
      C.Kind := 'TextBox';
      C.Name := Mf.UniqueName('calcBroj');
      C.ControlSource := '=DCount("*", "' + Dt.Table + '", ' + QuoteCrit(Fk, Pc, Numeric) + ')';
      C.Left := X0 + 104; C.Top := Y0; C.Width := 80; C.Height := 24;
      C.Align := 'right';
      C.SetX('locked', '1');
      InContainer(C, I);
      Mf.Add(C);
    end;
    if Dt.SumField <> '' then
    begin
      Sf := -1;
      for J := 0 to High(Det) do
        if SameText(Det[J].Name, Dt.SumField) then Sf := J;
      Lbl := TaControlDef.Create;
      Lbl.Kind := 'Label';
      Lbl.Name := Mf.UniqueName('lblZbroj');
      Lbl.Caption := Tr('Total ') + LowerCase(PrettyName(Dt.SumField)) + ':';
      Lbl.Bold := True;
      Lbl.Align := 'right';
      Lbl.Left := X0 + PW - 330; Lbl.Top := Y0 + 2; Lbl.Width := 200; Lbl.Height := 22;
      InContainer(Lbl, I);
      Mf.Add(Lbl);
      C := TaControlDef.Create;
      C.Kind := 'TextBox';
      C.Name := Mf.UniqueName('calcZbroj');
      C.ControlSource := '=DSum("[' + Dt.SumField + ']", "' + Dt.Table + '", ' + QuoteCrit(Fk, Pc, Numeric) + ')';
      if (Sf >= 0) and (Det[Sf].LType = ltCurrency) then C.Format := SumFormat(Det[Sf]) else C.Format := '#,##0.00';
      C.Bold := True;
      C.Align := 'right';
      C.Left := X0 + PW - 120; C.Top := Y0; C.Width := 120; C.Height := 24;
      C.SetX('locked', '1');
      InContainer(C, I);
      Mf.Add(C);
    end;
    if Dt.ShowCount or (Dt.SumField <> '') then Inc(Y0, 34);
    if not Tabbed then Y := Y0 + 6;
  end;
  if Tabbed then Y := Y + TabH + 10;
  Mf.Height := Y + 8;
end;

function BuildMasterDetail(ADb: TAppDb; const AOpt: TaMDOptions): TaMDResult;
var
  M: TaMDMulti;
  R: TaMDMultiResult;
begin
  M.Master := AOpt.Master;
  M.Name := AOpt.Name;
  M.Title := AOpt.Title;
  M.MasterFields := AOpt.MasterFields;
  M.DetailAsForm := AOpt.DetailAsForm;
  M.UseTabs := False;
  SetLength(M.Details, 1);
  M.Details[0].Table := AOpt.Detail;
  M.Details[0].Fields := AOpt.DetailFields;
  M.Details[0].SumField := AOpt.SumField;
  M.Details[0].ShowCount := AOpt.ShowCount;
  M.Details[0].FkCol := AOpt.FkCol;
  M.Details[0].ParentCol := AOpt.ParentCol;
  R := BuildMasterDetailMulti(ADb, M);
  Result.MasterForm := R.MasterForm;
  Result.DetailForm := nil;
  Result.DetailFormName := '';
  Result.QueryName := '';
  Result.QuerySql := '';
  Result.Error := R.Error;
  if Length(R.Items) > 0 then
  begin
    Result.DetailForm := R.Items[0].Form;
    Result.DetailFormName := R.Items[0].FormName;
    Result.QueryName := R.Items[0].QueryName;
    Result.QuerySql := R.Items[0].QuerySql;
  end;
end;

function Put(ADef: TaReportDef; const AKind, ASec, APrefix: string; L, T, W, H: Integer): TaControlDef;
begin
  Result := TaControlDef.Create;
  Result.Kind := AKind;
  Result.Section := ASec;
  Result.Left := L; Result.Top := T; Result.Width := W; Result.Height := H;
  Result.Name := ADef.UniqueName(Ident(APrefix));
  ADef.Add(Result);
end;

function SumFormat(const F: TaSourceField): string;
begin
  case F.LType of
    ltCurrency: if F.Format <> '' then Result := F.Format else Result := DefaultFormat(ltCurrency, F.Decimals);
    ltDecimal: Result := '#,##0.' + StringOfChar('0', F.Decimals);
  else
    Result := '#,##0';
  end;
end;

{ Sirine stupaca tablicnog izvjesca prema sadrzaju: znakovi u zaglavlju i najduza vrijednost u uzorku od 200 redaka
  (tekst), a brojevi i datumi po svojoj tipicnoj duljini. Ukupno se prilagodi sirini stranice, ali se stupac ne suzuje
  ispod 40 tocaka. Prije su svi stupci dobivali istu sirinu (najmanje 70), pa je siroka tablica izlazila izvan stranice. }
{ 'polje=tocke,polje=tocke' (razmak i veliko/malo slovo nisu bitni): izricite sirine pregazuju izracunate }
procedure ApplyExplicitWidths(const AWidths: string; ACols: TStrings; var AW: array of Integer);
var
  L: TStringList;
  I, J, V: Integer;
  Nm: string;
begin
  if Trim(AWidths) = '' then Exit;
  L := TStringList.Create;
  try
    L.Delimiter := ','; L.StrictDelimiter := True; L.DelimitedText := AWidths;
    for I := 0 to L.Count - 1 do
    begin
      Nm := Trim(L.Names[I]);
      V := StrToIntDef(Trim(L.ValueFromIndex[I]), 0);
      if (Nm = '') or (V < 10) then Continue;
      for J := 0 to ACols.Count - 1 do
        if SameText(ACols[J], Nm) then begin AW[J] := V; Break; end;
    end;
  finally
    L.Free;
  end;
end;

procedure ContentWidths(ADb: TAppDb; const ASource: string; ACols: TStrings; const AAll: TaSourceFields; AAvail: Integer; var AWidths: array of Integer);
var
  I, J, N, Idx, Longest, Total, Cap, NumW, TextW, NText: Integer;
  Chars: array of Integer;
  Q: TZQuery;
  Scale: Double;
  Sql: string;
  Rows: Integer;
begin
  N := ACols.Count;
  SetLength(Chars, N);
  for I := 0 to N - 1 do
  begin
    Idx := FindField(AAll, ACols[I]);
    Chars[I] := UTF8Length(CaptionOf(AAll[Idx])) + 1;   { zaglavlje je podebljano }
    case AAll[Idx].LType of
      ltInteger, ltAutoNumber: Chars[I] := Max(Chars[I], 4);
      ltDecimal, ltCurrency: Chars[I] := Max(Chars[I], 6);
      ltDate: Chars[I] := Max(Chars[I], 10);
      ltDateTime: Chars[I] := Max(Chars[I], 16);
      ltYesNo: Chars[I] := Max(Chars[I], 4);
    end;
  end;
  { uzorak podataka za tekstualna polja }
  Sql := '';
  for I := 0 to N - 1 do
  begin
    if Sql <> '' then Sql := Sql + ', ';
    Sql := Sql + ADb.QuoteId(ACols[I]);
  end;
  try
    Q := ADb.NewQuery('SELECT ' + Sql + ' FROM ' + ADb.SourceFrom(ASource) + ' LIMIT 200');
    try
      Q.Open;
      Rows := 0;
      while not Q.Eof do
      begin
        Inc(Rows);
        for I := 0 to N - 1 do
        begin
          Idx := FindField(AAll, ACols[I]);
          if AAll[Idx].LType in [ltText, ltMemo] then
          begin
            Longest := UTF8Length(Q.Fields[I].AsString);
            if Longest > Chars[I] then Chars[I] := Longest;
          end;
        end;
        Q.Next;
      end;
      { bez uzorka (tablica je jos prazna) tekst dobiva razumnu zadanu sirinu }
      if Rows = 0 then
        for I := 0 to N - 1 do
          if AAll[FindField(AAll, ACols[I])].LType = ltText then Chars[I] := Max(Chars[I], 16);
    finally
      Q.Free;
    end;
  except
    { izvor koji se ne moze procitati ostaje na zaglavljima }
  end;
  Cap := 28;
  NumW := 0; TextW := 0; NText := 0;
  for I := 0 to N - 1 do
  begin
    Chars[I] := Min(Chars[I], Cap);
    AWidths[I] := Chars[I] * 9 + 14;       { znak je oko 9 tocaka }
    if AAll[FindField(AAll, ACols[I])].LType in [ltText, ltMemo] then begin Inc(TextW, AWidths[I]); Inc(NText); end
    else Inc(NumW, AWidths[I]);
  end;
  Total := NumW + TextW;
  if Total > AAvail then
  begin
    { brojevi i datumi zadrzavaju svoju sirinu, tekst dobiva ostatak }
    if (NText > 0) and (AAvail - NumW >= NText * 60) then
    begin
      Scale := (AAvail - NumW) / TextW;
      for I := 0 to N - 1 do
        if AAll[FindField(AAll, ACols[I])].LType in [ltText, ltMemo] then AWidths[I] := Max(60, Trunc(AWidths[I] * Scale));
    end
    else
    begin
      Scale := AAvail / Total;
      for I := 0 to N - 1 do AWidths[I] := Max(40, Trunc(AWidths[I] * Scale));
    end;
  end
  else if Total < AAvail then
  begin
    { ostatak se dijeli razmjerno, ali najvise do 1,5 puta }
    Scale := Min(AAvail / Total, 1.5);
    for I := 0 to N - 1 do AWidths[I] := Trunc(AWidths[I] * Scale);
  end;
  J := 0;
  if J = 1 then Exit;
end;

function BuildReportDef(ADb: TAppDb; const ASource, AName, ATitle: string; AFields: TStrings;
  const AGroupField, ASortField: string; ADescending, ASums: Boolean; const AWidths: string; AGrowLines: Integer): TaReportDef;
var
  Avail: Integer;
  All: TaSourceFields;
  Cols: TStringList;
  I, Idx, N, ColW, X: Integer;
  Wd, Xs: array of Integer;
  D: TaControlDef;
  GroupOn, AnyNumeric: Boolean;
  Al: string;
begin
  Result := TaReportDef.Create;
  Result.Name := AName;
  Result.Title := ATitle;
  Result.RecordSource := ASource;
  Avail := DefPageW - 2 * DefPageMargin;
  { puno stupaca: polozena stranica }
  if AFields.Count > 6 then
  begin
    Result.PageWidth := DefPageH;
    Result.PageHeight := DefPageW;
    Avail := DefPageH - 2 * DefPageMargin;
  end;
  All := SourceFieldList(ADb, ASource);
  GroupOn := (AGroupField <> '') and (FindField(All, AGroupField) >= 0);
  if GroupOn then Result.GroupField := AGroupField;
  if (ASortField <> '') and (FindField(All, ASortField) >= 0) then
  begin
    Result.SortBy := ADb.QuoteId(ASortField);
    if ADescending then Result.SortBy := Result.SortBy + ' DESC';
  end;
  Cols := TStringList.Create;
  try
    AnyNumeric := False;
    for I := 0 to AFields.Count - 1 do
    begin
      Idx := FindField(All, AFields[I]);
      if (Idx < 0) or (GroupOn and SameText(AFields[I], AGroupField)) then Continue;
      Cols.Add(All[Idx].Name);
      if IsNumericType(All[Idx].LType) or (All[Idx].LType in [ltDecimal, ltCurrency]) then AnyNumeric := True;
    end;
    N := Cols.Count;
    if N = 0 then Exit;
    { sirina stupca prema sadrzaju (zaglavlje i uzorak podataka), pa se cijeli red prilagodi sirini stranice }
    SetLength(Wd, N); SetLength(Xs, N);
    ContentWidths(ADb, ASource, Cols, All, Avail, Wd);
    ApplyExplicitWidths(AWidths, Cols, Wd);
    X := 0;
    for I := 0 to N - 1 do begin Xs[I] := X; Inc(X, Wd[I]); end;
    ColW := Wd[0];

    { report header: title and date }
    D := Put(Result, 'Label', 'ReportHeader', 'lblNaslov', 0, 8, 440, 26);
    D.Caption := ATitle;
    D.Bold := True;
    D := Put(Result, 'TextBox', 'ReportHeader', 'txtDatum', Avail - 160, 10, 160, 22);
    D.ControlSource := '=Date()';
    D.Align := 'right';

    { page header: column titles and a rule }
    for I := 0 to N - 1 do
    begin
      Idx := FindField(All, Cols[I]);
      D := Put(Result, 'Label', 'PageHeader', 'lbl' + Cols[I], Xs[I], 4, Wd[I] - 8, 20);
      D.Caption := CaptionOf(All[Idx]);
      D.Bold := True;
      if All[Idx].LType in [ltInteger, ltDecimal, ltCurrency, ltAutoNumber] then D.Align := 'right';
    end;
    D := Put(Result, 'Line', 'PageHeader', 'lnZaglavlje', 0, 25, Avail, 1);

    { group header }
    if GroupOn then
    begin
      D := Put(Result, 'TextBox', 'GroupHeader', 'txtGrupa', 0, 4, Avail, 22);
      D.ControlSource := AGroupField;
      D.Bold := True;
    end
    else Result.Heights[SecGroupHeader] := 0;

    { detail }
    for I := 0 to N - 1 do
    begin
      Idx := FindField(All, Cols[I]);
      D := Put(Result, 'TextBox', 'Detail', 'txt' + Cols[I], Xs[I], 1, Wd[I] - 8, 20);
      D.ControlSource := Cols[I];
      if All[Idx].LType in [ltDecimal, ltCurrency] then D.Format := SumFormat(All[Idx]);
      if All[Idx].LType in [ltInteger, ltDecimal, ltCurrency, ltAutoNumber] then D.Align := 'right';
      if (AGrowLines > 1) and (All[Idx].LType in [ltText, ltMemo]) then D.SetX('growLines', IntToStr(AGrowLines));
    end;
    Result.Heights[SecDetail] := 22;

    { group footer: totals under numeric columns }
    if GroupOn and ASums and AnyNumeric then
    begin
      D := Put(Result, 'Label', 'GroupFooter', 'lblUkupno', 0, 4, ColW - 8, 20);
      D.Caption := Tr('Total');
      D.Bold := True;
      for I := 0 to N - 1 do
      begin
        Idx := FindField(All, Cols[I]);
        if not (All[Idx].LType in [ltInteger, ltDecimal, ltCurrency]) then Continue;
        D := Put(Result, 'TextBox', 'GroupFooter', 'sum' + Cols[I], Xs[I], 4, Wd[I] - 8, 20);
        D.ControlSource := '=Sum([' + Cols[I] + '])';
        D.Format := SumFormat(All[Idx]);
        D.Align := 'right';
        D.Bold := True;
      end;
      Result.Heights[SecGroupFooter] := 30;
    end
    else if GroupOn then Result.Heights[SecGroupFooter] := 10
    else Result.Heights[SecGroupFooter] := 0;

    { report footer: grand totals and row count }
    D := Put(Result, 'Line', 'ReportFooter', 'lnKraj', 0, 4, Avail, 1);
    D := Put(Result, 'Label', 'ReportFooter', 'lblSveukupno', 0, 10, ColW - 8, 20);
    if ASums and AnyNumeric then D.Caption := Tr('Grand total') else D.Caption := Tr('Rows:');
    D.Bold := True;
    if ASums and AnyNumeric then
      for I := 0 to N - 1 do
      begin
        Idx := FindField(All, Cols[I]);
        if not (All[Idx].LType in [ltInteger, ltDecimal, ltCurrency]) then Continue;
        D := Put(Result, 'TextBox', 'ReportFooter', 'tot' + Cols[I], Xs[I], 10, Wd[I] - 8, 20);
        D.ControlSource := '=Sum([' + Cols[I] + '])';
        D.Format := SumFormat(All[Idx]);
        D.Align := 'right';
        D.Bold := True;
      end
    else
    begin
      D := Put(Result, 'TextBox', 'ReportFooter', 'cnt', Wd[0], 10, 120, 20);
      D.ControlSource := '=Count(*)';
    end;
    Result.Heights[SecReportFooter] := 40;

    { page footer }
    D := Put(Result, 'TextBox', 'PageFooter', 'txtIspis', 0, 2, 240, 20);
    D.ControlSource := '=Now()';
    D.Format := 'dd.mm.yyyy hh:nn';
    D := Put(Result, 'TextBox', 'PageFooter', 'txtStranica', Avail - 240, 2, 240, 20);
    D.ControlSource := '="Stranica " & Page & " / " & Pages';
    D.Align := 'right';
  finally
    Cols.Free;
  end;
end;


{ ---------------- more report kinds ---------------- }

procedure AddPageFooter(ADef: TaReportDef);
const
  Avail = DefPageW - 2 * DefPageMargin;
var
  D: TaControlDef;
begin
  D := Put(ADef, 'TextBox', 'PageFooter', 'txtIspis', 0, 2, 240, 20);
  D.ControlSource := '=Now()';
  D.Format := 'dd.mm.yyyy hh:nn';
  D := Put(ADef, 'TextBox', 'PageFooter', 'txtStranica', Avail - 240, 2, 240, 20);
  D.ControlSource := '="Stranica " & Page & " / " & Pages';
  D.Align := 'right';
end;

procedure AddTitle(ADef: TaReportDef; const ATitle: string);
const
  Avail = DefPageW - 2 * DefPageMargin;
var
  D: TaControlDef;
begin
  D := Put(ADef, 'Label', 'ReportHeader', 'lblNaslov', 0, 8, 440, 26);
  D.Caption := ATitle;
  D.Bold := True;
  D.SetX('fontSize', '16');
  D := Put(ADef, 'TextBox', 'ReportHeader', 'txtDatum', Avail - 160, 10, 160, 22);
  D.ControlSource := '=Date()';
  D.Align := 'right';
end;

function BuildReportEx(ADb: TAppDb; const AOpt: TaReportOptions): TaReportDef;
const
  Avail = DefPageW - 2 * DefPageMargin;
var
  All: TaSourceFields;
  Names: TStringList;
  I, Idx, N, Cols, Gap, ColW, Lines, H, Y: Integer;
  D: TaControlDef;
  Clr, Bt, Bx: string;
begin
  case AOpt.Kind of
    rkTabular, rkSummary:
      begin
        Result := BuildReportDef(ADb, AOpt.Source, AOpt.Name, AOpt.Title, AOpt.Fields,
          AOpt.GroupField, AOpt.SortField, AOpt.Descending, AOpt.Sums, AOpt.Widths);
        { summary: the groups and totals without the rows themselves }
        if AOpt.Kind = rkSummary then Result.Heights[SecDetail] := 0;
        Exit;
      end;
  end;
  Result := TaReportDef.Create;
  Result.Name := AOpt.Name;
  Result.Title := AOpt.Title;
  Result.RecordSource := AOpt.Source;
  if AOpt.SortField <> '' then Result.SortBy := ADb.QuoteId(AOpt.SortField);
  All := SourceFieldList(ADb, AOpt.Source);
  Names := TStringList.Create;
  try
    for I := 0 to AOpt.Fields.Count - 1 do
      if FindField(All, AOpt.Fields[I]) >= 0 then Names.Add(All[FindField(All, AOpt.Fields[I])].Name);
    N := Names.Count;
    { labels can be built from composite lines instead of single fields }
    if (AOpt.Kind = rkLabels) and (AOpt.LabelLines <> nil) and (AOpt.LabelLines.Count > 0) then
    begin
      Names.Clear;
      for I := 0 to AOpt.LabelLines.Count - 1 do
        if Trim(AOpt.LabelLines[I]) <> '' then Names.Add(Trim(AOpt.LabelLines[I]));
      N := Names.Count;
    end;
    if N = 0 then Exit;
    Result.Heights[SecPageHeader] := 0;
    Result.Heights[SecGroupHeader] := 0;
    Result.Heights[SecGroupFooter] := 0;
    Result.Heights[SecReportFooter] := 0;
    if AOpt.Kind = rkColumnar then
    begin
      Result.Heights[SecReportHeader] := 44;
      Result.Heights[SecPageFooter] := 26;
      AddTitle(Result, AOpt.Title);
      for I := 0 to N - 1 do
      begin
        D := Put(Result, 'Label', 'Detail', 'lbl' + Names[I], 0, 4 + I * 24, 190, 20);
        D.Caption := CaptionOf(All[FindField(All, Names[I])]);
        D.Bold := True;
        D := Put(Result, 'TextBox', 'Detail', 'txt' + Names[I], 200, 2 + I * 24, Avail - 200, 20);
        D.ControlSource := Names[I];
      end;
      H := N * 24 + 22;
      Result.Heights[SecDetail] := H;
      D := Put(Result, 'Line', 'Detail', 'lnZapis', 0, N * 24 + 10, Avail, 1);
      D.SetX('foreColor', '#BBBBBB');
      if AOpt.PageBreakPerRecord then Put(Result, 'PageBreak', 'Detail', 'pbZapis', 0, H - 2, 200, 2);
      AddPageFooter(Result);
    end
    else
    begin
      { labels: N across, a few lines each, no headers or footers }
      Cols := AOpt.LabelColumns;
      if Cols < 2 then Cols := 2;
      if Cols > 4 then Cols := 4;
      Gap := 12;
      ColW := (Avail - Gap * (Cols - 1)) div Cols;
      Lines := N;
      if Lines > 8 then Lines := 8;
      { a line "barcode:<vrsta>:<izraz>" is a barcode / QR code instead of text }
      H := 18;
      for I := 0 to Lines - 1 do
        if Pos('barcode:', LowerCase(Names[I])) = 1 then Inc(H, 52) else Inc(H, 18);
      Result.Columns := Cols;
      Result.ColumnGap := Gap;
      Result.Heights[SecReportHeader] := 0;
      Result.Heights[SecPageFooter] := 0;
      Result.Heights[SecDetail] := H;
      D := Put(Result, 'Rectangle', 'Detail', 'rctNaljepnica', 0, 0, ColW, H - 6);
      D.SetX('foreColor', '#CCCCCC');
      Y := 4;
      for I := 0 to Lines - 1 do
      begin
        if Pos('barcode:', LowerCase(Names[I])) = 1 then
        begin
          Bt := Copy(Names[I], 9, MaxInt);
          Bx := Copy(Bt, Pos(':', Bt) + 1, MaxInt);
          Bt := Trim(Copy(Bt, 1, Pos(':', Bt) - 1));
          D := Put(Result, 'Barcode', 'Detail', 'bcRedak' + IntToStr(I + 1), 6, Y, ColW - 12, 48);
          if (Pos('[', Bx) > 0) or (Pos('(', Bx) > 0) or (Pos('"', Bx) > 0) or (Pos('&', Bx) > 0) then
            D.ControlSource := '=' + Trim(Bx)
          else
            D.ControlSource := Trim(Bx);
          D.SetX('barType', LowerCase(Bt));
          Inc(Y, 52);
          Continue;
        end;
        D := Put(Result, 'TextBox', 'Detail', 'txtRedak' + IntToStr(I + 1), 6, Y, ColW - 12, 18);
        { a line with brackets, quotes or operators is an expression; a bare name is a field }
        if (Pos('[', Names[I]) > 0) or (Pos('(', Names[I]) > 0) or (Pos('"', Names[I]) > 0) or (Pos('&', Names[I]) > 0) then
          D.ControlSource := '=' + Names[I]
        else
          D.ControlSource := Names[I];
        if I = 0 then D.Bold := True;
        Inc(Y, 18);
      end;
    end;
  finally
    Names.Free;
  end;
end;

function FindRelation(ADb: TAppDb; const AMaster, ADetail: string; out AFk, APc: string): Boolean;
var
  Rels, Parts: TStringList;
  I: Integer;
begin
  Result := False;
  Rels := ChildRelations(ADb, AMaster);
  Parts := TStringList.Create;
  Parts.Delimiter := '|';
  Parts.StrictDelimiter := True;
  try
    for I := 0 to Rels.Count - 1 do
    begin
      Parts.DelimitedText := Rels[I];
      if (Parts.Count = 3) and SameText(Parts[0], ADetail) then
      begin
        AFk := Parts[1];
        APc := Parts[2];
        Exit(True);
      end;
    end;
  finally
    Parts.Free;
    Rels.Free;
  end;
end;

function BuildMasterDetailReportMulti(ADb: TAppDb; const AOpt: TaMDMulti; APageBreak: Boolean;
  AChildren: TStringList; out AError: string): TaReportDef;
const
  Avail = DefPageW - 2 * DefPageMargin;
var
  MAll: TaSourceFields;
  MF: TStringList;
  I, J, Idx, Y, Lines: Integer;
  Fk, Pc, ChildName: string;
  D: TaControlDef;
  Ro: TaReportOptions;
  Child: TaReportDef;
  Fl: TStringList;
begin
  Result := nil;
  AError := '';
  if Length(AOpt.Details) = 0 then begin AError := 'Odaberi barem jednu detail tablicu.'; Exit; end;
  MAll := SourceFieldList(ADb, AOpt.Master);
  MF := TStringList.Create;
  try
    for I := 0 to AOpt.MasterFields.Count - 1 do
      if FindField(MAll, AOpt.MasterFields[I]) >= 0 then MF.Add(AOpt.MasterFields[I]);
    if MF.Count = 0 then
      for I := 0 to High(MAll) do MF.Add(MAll[I].Name);
    { prvo podizvjesca, da se zna jesu li sve veze ispravne }
    for J := 0 to High(AOpt.Details) do
    begin
      Fk := ''; Pc := '';
      if not FindRelation(ADb, AOpt.Master, AOpt.Details[J].Table, Fk, Pc) then
      begin
        AError := 'Između ' + AOpt.Master + ' i ' + AOpt.Details[J].Table + ' nema veze (stranog ključa). Dodaj je u Relacije.';
        Exit;
      end;
    end;
    Result := TaReportDef.Create;
    Result.Name := AOpt.Name;
    Result.Title := AOpt.Title;
    if Result.Title = '' then Result.Title := PrettyName(AOpt.Master);
    Result.RecordSource := AOpt.Master;
    Result.Heights[SecPageHeader] := 0;
    Result.Heights[SecGroupHeader] := 0;
    Result.Heights[SecGroupFooter] := 0;
    Result.Heights[SecReportFooter] := 0;
    Result.Heights[SecReportHeader] := 44;
    Result.Heights[SecPageFooter] := 26;
    AddTitle(Result, Result.Title);
    Y := 4;
    for I := 0 to MF.Count - 1 do
    begin
      Idx := FindField(MAll, MF[I]);
      D := Put(Result, 'Label', 'Detail', 'lblm' + MF[I], 0, Y, 190, 20);
      if Idx >= 0 then D.Caption := CaptionOf(MAll[Idx]) else D.Caption := PrettyName(MF[I]);
      D.Bold := True;
      D := Put(Result, 'TextBox', 'Detail', 'txtm' + MF[I], 200, Y - 2, Avail - 200, 20);
      D.ControlSource := MF[I];
      Inc(Y, 22);
    end;
    Inc(Y, 6);
    for J := 0 to High(AOpt.Details) do
    begin
      FindRelation(ADb, AOpt.Master, AOpt.Details[J].Table, Fk, Pc);
      ChildName := AOpt.Name + ' - ' + AOpt.Details[J].Table;
      Fl := TStringList.Create;
      try
        if AOpt.Details[J].Fields <> nil then Fl.AddStrings(AOpt.Details[J].Fields);
        if Fl.Count = 0 then
          for I := 0 to High(SourceFieldList(ADb, AOpt.Details[J].Table)) do
            Fl.Add(SourceFieldList(ADb, AOpt.Details[J].Table)[I].Name);
        { u detail ne treba kljuc veze }
        Idx := Fl.IndexOf(Fk);
        if (Idx >= 0) and (Fl.Count > 1) then Fl.Delete(Idx);
        Ro.Source := AOpt.Details[J].Table; Ro.Name := ChildName; Ro.Title := '';
        Ro.GroupField := ''; Ro.SortField := ''; Ro.Fields := Fl; Ro.Kind := rkTabular;
        Ro.Descending := False; Ro.Sums := AOpt.Details[J].SumField <> '';
        Ro.PageBreakPerRecord := False; Ro.LabelColumns := 3; Ro.LabelLines := nil;
        Child := BuildReportEx(ADb, Ro);
      finally
        Fl.Free;
      end;
      if Child = nil then begin AError := 'Podizvješće za ' + AOpt.Details[J].Table + ' nije izrađeno.'; FreeAndNil(Result); Exit; end;
      AChildren.AddObject(ChildName, Child);
      D := Put(Result, 'Label', 'Detail', 'lblp' + AOpt.Details[J].Table, 0, Y, Avail, 20);
      D.Caption := PrettyName(AOpt.Details[J].Table);
      D.Bold := True;
      D.SetX('foreColor', '#1F4E9C');
      Inc(Y, 22);
      D := Put(Result, 'Subreport', 'Detail', 'sub' + AOpt.Details[J].Table, 0, Y, Avail, 50);
      D.RowSource := ChildName;
      D.LinkMaster := Pc;
      D.LinkChild := Fk;
      Inc(Y, 58);
    end;
    Result.Heights[SecDetail] := Y + 8;
    if APageBreak then Put(Result, 'PageBreak', 'Detail', 'pbZapis', 0, Y + 6, 200, 2)
    else
    begin
      D := Put(Result, 'Line', 'Detail', 'lnZapis', 0, Y + 2, Avail, 1);
      D.SetX('foreColor', '#BBBBBB');
    end;
    AddPageFooter(Result);
    Lines := 0;
    if Lines = 0 then;
  finally
    MF.Free;
  end;
end;

function BuildMasterDetailReport(ADb: TAppDb; const AOpt: TaMDOptions): TaMDReportResult;
const
  Avail = DefPageW - 2 * DefPageMargin;
var
  Fk, Pc, Sel, Alias, Clash: string;
  MAll, DAll: TaSourceFields;
  MF, DF, DAlias: TStringList;
  I, J, Idx, ColW, Y: Integer;
  D: TaControlDef;
  Def: TaReportDef;
  Rc: TaControlDef;
begin
  Result.Def := nil;
  Result.QueryName := '';
  Result.QuerySql := '';
  Result.Error := '';
  Fk := AOpt.FkCol;
  Pc := AOpt.ParentCol;
  if ((Fk = '') or (Pc = '')) and not FindRelation(ADb, AOpt.Master, AOpt.Detail, Fk, Pc) then
  begin
    Result.Error := 'Između ' + AOpt.Master + ' i ' + AOpt.Detail + ' nema veze (stranog ključa). Dodaj je u Relacije.';
    Exit;
  end;
  MAll := SourceFieldList(ADb, AOpt.Master);
  DAll := SourceFieldList(ADb, AOpt.Detail);
  MF := TStringList.Create;
  DF := TStringList.Create;
  DAlias := TStringList.Create;
  try
    if (AOpt.MasterFields <> nil) and (AOpt.MasterFields.Count > 0) then MF.Assign(AOpt.MasterFields)
    else for I := 0 to High(MAll) do MF.Add(MAll[I].Name);
    if (AOpt.DetailFields <> nil) and (AOpt.DetailFields.Count > 0) then DF.Assign(AOpt.DetailFields)
    else for I := 0 to High(DAll) do if not SameText(DAll[I].Name, Fk) then DF.Add(DAll[I].Name);
    { one flat query: master columns, then detail columns (renamed when they clash) }
    Sel := '';
    for I := 0 to MF.Count - 1 do
    begin
      if Sel <> '' then Sel := Sel + ', ';
      Sel := Sel + 'm.' + ADb.QuoteId(MF[I]) + ' AS ' + ADb.QuoteId(MF[I]);
    end;
    if MF.IndexOf(Pc) < 0 then
    begin
      if Sel <> '' then Sel := Sel + ', ';
      Sel := Sel + 'm.' + ADb.QuoteId(Pc) + ' AS ' + ADb.QuoteId(Pc);
    end;
    for I := 0 to DF.Count - 1 do
    begin
      Alias := DF[I];
      Clash := '';
      for J := 0 to MF.Count - 1 do if SameText(MF[J], Alias) then Clash := 'x';
      if SameText(Pc, Alias) then Clash := 'x';
      if Clash <> '' then Alias := AOpt.Detail + '_' + DF[I];
      DAlias.Add(Alias);
      Sel := Sel + ', d.' + ADb.QuoteId(DF[I]) + ' AS ' + ADb.QuoteId(Alias);
    end;
    Result.QueryName := AOpt.Name + '_q';
    Result.QuerySql := 'SELECT ' + Sel + ' FROM ' + ADb.SourceFromRaw(AOpt.Master) + ' m INNER JOIN ' +
      ADb.SourceFromRaw(AOpt.Detail) + ' d ON d.' + ADb.QuoteId(Fk) + ' = m.' + ADb.QuoteId(Pc) +
      ' ORDER BY m.' + ADb.QuoteId(Pc);

    Def := TaReportDef.Create;
    Result.Def := Def;
    Def.Name := AOpt.Name;
    Def.Title := AOpt.Title;
    Def.RecordSource := Result.QueryName;
    Def.GroupField := Pc;
    Def.Heights[SecReportHeader] := 44;
    Def.Heights[SecPageFooter] := 26;
    Def.Heights[SecReportFooter] := 40;
    AddTitle(Def, AOpt.Title);

    { column titles of the detail rows }
    ColW := Avail div Max(1, DAlias.Count);
    for I := 0 to DAlias.Count - 1 do
    begin
      Idx := -1;
      for J := 0 to High(DAll) do if SameText(DAll[J].Name, DF[I]) then Idx := J;
      D := Put(Def, 'Label', 'PageHeader', 'lblh' + DAlias[I], I * ColW, 4, ColW - 8, 20);
      if Idx >= 0 then D.Caption := CaptionOf(DAll[Idx]) else D.Caption := PrettyName(DF[I]);
      D.Bold := True;
      if (Idx >= 0) and (DAll[Idx].LType in [ltInteger, ltDecimal, ltCurrency, ltAutoNumber]) then D.Align := 'right';
    end;
    D := Put(Def, 'Line', 'PageHeader', 'lnZaglavlje', 0, 25, Avail, 1);

    { the master block, shaded, above each group of detail rows }
    Def.Heights[SecGroupHeader] := MF.Count * 20 + 14;
    Rc := Put(Def, 'Rectangle', 'GroupHeader', 'rctMaster', 0, 2, Avail, MF.Count * 20 + 8);
    Rc.SetX('backColor', '#EEF3FA');
    Rc.SetX('foreColor', '#B9C7DE');
    for I := 0 to MF.Count - 1 do
    begin
      D := Put(Def, 'Label', 'GroupHeader', 'lblm' + MF[I], 8, 6 + I * 20, 150, 18);
      D.Caption := PrettyName(MF[I]) + ':';
      D.Bold := True;
      D := Put(Def, 'TextBox', 'GroupHeader', 'txtm' + MF[I], 164, 6 + I * 20, Avail - 180, 18);
      D.ControlSource := MF[I];
    end;

    { detail rows }
    Def.Heights[SecDetail] := 22;
    for I := 0 to DAlias.Count - 1 do
    begin
      Idx := -1;
      for J := 0 to High(DAll) do if SameText(DAll[J].Name, DF[I]) then Idx := J;
      D := Put(Def, 'TextBox', 'Detail', 'txtd' + DAlias[I], I * ColW, 1, ColW - 8, 20);
      D.ControlSource := DAlias[I];
      if (Idx >= 0) and (DAll[Idx].LType in [ltDecimal, ltCurrency]) then D.Format := SumFormat(DAll[Idx]);
      if (Idx >= 0) and (DAll[Idx].LType in [ltInteger, ltDecimal, ltCurrency, ltAutoNumber]) then D.Align := 'right';
    end;

    { totals per master and for everything }
    Def.Heights[SecGroupFooter] := 30;
    D := Put(Def, 'TextBox', 'GroupFooter', 'cntGrupa', 0, 6, ColW * 2 - 8, 20);
    D.ControlSource := '="Stavki: " & Count(*)';
    D.Bold := True;
    D := Put(Def, 'TextBox', 'ReportFooter', 'cntSve', 0, 12, ColW * 2 - 8, 20);
    D.ControlSource := '="Ukupno stavki: " & CountAll(*)';
    D.Bold := True;
    D := Put(Def, 'Line', 'ReportFooter', 'lnKraj', 0, 4, Avail, 1);
    for I := 0 to DAlias.Count - 1 do
    begin
      Idx := -1;
      for J := 0 to High(DAll) do if SameText(DAll[J].Name, DF[I]) then Idx := J;
      if Idx < 0 then Continue;
      if not (DAll[Idx].LType in [ltInteger, ltDecimal, ltCurrency]) then Continue;
      if (AOpt.SumField <> '') and not SameText(AOpt.SumField, DF[I]) then Continue;
      D := Put(Def, 'TextBox', 'GroupFooter', 'sumg' + DAlias[I], I * ColW, 6, ColW - 8, 20);
      D.ControlSource := '=Sum([' + DAlias[I] + '])';
      D.Format := SumFormat(DAll[Idx]);
      D.Align := 'right';
      D.Bold := True;
      D := Put(Def, 'TextBox', 'ReportFooter', 'sumr' + DAlias[I], I * ColW, 12, ColW - 8, 20);
      D.ControlSource := '=SumAll([' + DAlias[I] + '])';
      D.Format := SumFormat(DAll[Idx]);
      D.Align := 'right';
      D.Bold := True;
    end;
    AddPageFooter(Def);
  finally
    DAlias.Free;
    DF.Free;
    MF.Free;
  end;
end;

function BuildFormWithFilters(ADb: TAppDb; const AOpt: TaFormOptions): TaFormDef;
var
  Opt: TaFormOptions;
  Pnl: TaControlDef;
  Lbl, Ctl: TaControlDef;
  I, Idx, CurX, CurY, ItemW: Integer;
  All: TaSourceFields;
  FldName, Cap: string;
begin
  Opt := AOpt;
  Opt.Layout := flDatasheet;
  Result := BuildFormEx(ADb, Opt);
  if Result = nil then Exit;

  if ((AOpt.FilterFields <> nil) and (AOpt.FilterFields.Count > 0)) or AOpt.AddRefreshButton or AOpt.AddClearButton then
  begin
    All := SourceFieldList(ADb, AOpt.Source);
    Pnl := TaControlDef.Create;
    Pnl.Kind := 'Panel';
    Pnl.Name := 'pnlFilteri';
    Pnl.Caption := '';
    Pnl.Align := 'top';
    Pnl.Left := 0;
    Pnl.Top := 0;
    Pnl.Width := Result.Width;
    Pnl.Height := 58;
    Pnl.SetX('bevelOuter', 'none');
    Result.Add(Pnl);

    CurX := 12;
    CurY := 8;

    if AOpt.FilterFields <> nil then
    begin
      for I := 0 to AOpt.FilterFields.Count - 1 do
      begin
        FldName := AOpt.FilterFields[I];
        Idx := FindField(All, FldName);
        if Idx >= 0 then Cap := CaptionOf(All[Idx]) else Cap := PrettyName(FldName);
        ItemW := 130;

        if (Idx >= 0) and (All[Idx].LType = ltDate) then
        begin
          Lbl := TaControlDef.Create;
          Lbl.Kind := 'Label';
          Lbl.Name := Result.UniqueName('lbl_' + Ident(FldName) + '_od_');
          Lbl.Caption := Cap + Tr(' from:');
          Lbl.Left := CurX; Lbl.Top := CurY; Lbl.Width := 90; Lbl.Height := 18;
          Lbl.SetX('container', 'pnlFilteri');
          Result.Add(Lbl);

          Ctl := TaControlDef.Create;
          Ctl.Kind := 'TextBox';
          Ctl.Name := Result.UniqueName('flt_' + Ident(FldName) + '_od');
          Ctl.SetX('filterFor', FldName + '_od');
          Ctl.Left := CurX; Ctl.Top := CurY + 18; Ctl.Width := 95; Ctl.Height := 24;
          Ctl.SetX('container', 'pnlFilteri');
          Result.Add(Ctl);
          Inc(CurX, 102);

          Lbl := TaControlDef.Create;
          Lbl.Kind := 'Label';
          Lbl.Name := Result.UniqueName('lbl_' + Ident(FldName) + '_do_');
          Lbl.Caption := Tr('to:');
          Lbl.Left := CurX; Lbl.Top := CurY; Lbl.Width := 30; Lbl.Height := 18;
          Lbl.SetX('container', 'pnlFilteri');
          Result.Add(Lbl);

          Ctl := TaControlDef.Create;
          Ctl.Kind := 'TextBox';
          Ctl.Name := Result.UniqueName('flt_' + Ident(FldName) + '_do');
          Ctl.SetX('filterFor', FldName + '_do');
          Ctl.Left := CurX; Ctl.Top := CurY + 18; Ctl.Width := 95; Ctl.Height := 24;
          Ctl.SetX('container', 'pnlFilteri');
          Result.Add(Ctl);
          Inc(CurX, 106);
        end
        else
        begin
          Lbl := TaControlDef.Create;
          Lbl.Kind := 'Label';
          Lbl.Name := Result.UniqueName('lbl_' + Ident(FldName) + '_');
          Lbl.Caption := Cap + ':';
          Lbl.Left := CurX; Lbl.Top := CurY; Lbl.Width := ItemW; Lbl.Height := 18;
          Lbl.SetX('container', 'pnlFilteri');
          Result.Add(Lbl);

          Ctl := TaControlDef.Create;
          Ctl.Kind := 'TextBox';
          Ctl.Name := Result.UniqueName('flt_' + Ident(FldName));
          Ctl.SetX('filterFor', FldName);
          Ctl.Left := CurX; Ctl.Top := CurY + 18; Ctl.Width := ItemW; Ctl.Height := 24;
          Ctl.SetX('container', 'pnlFilteri');
          Result.Add(Ctl);
          Inc(CurX, ItemW + 10);
        end;
      end;
    end;

    if AOpt.AddRefreshButton then
    begin
      Ctl := TaControlDef.Create;
      Ctl.Kind := 'Button';
      Ctl.Name := 'btnOsvjezi';
      Ctl.Caption := Tr('Refresh');
      Ctl.OnClick := 'refresh:';
      Ctl.Left := CurX; Ctl.Top := CurY + 16; Ctl.Width := 80; Ctl.Height := 26;
      Ctl.SetX('container', 'pnlFilteri');
      Result.Add(Ctl);
      Inc(CurX, 86);
    end;

    if AOpt.AddClearButton then
    begin
      Ctl := TaControlDef.Create;
      Ctl.Kind := 'Button';
      Ctl.Name := 'btnOcistiFiltere';
      Ctl.Caption := Tr('Clear filters');
      Ctl.OnClick := 'clearfilters:';
      Ctl.Left := CurX; Ctl.Top := CurY + 16; Ctl.Width := 95; Ctl.Height := 26;
      Ctl.SetX('container', 'pnlFilteri');
      Result.Add(Ctl);
    end;
  end;
end;

function BuildFglScript(ADb: TAppDb; const ASource, ATitle, AScriptType: string; AFields: TStrings): string;
var
  ST, FL, Src, Ttl: string;
  I: Integer;
begin
  Src := LowerCase(Trim(ASource));
  if Src = '' then Src := 'tablica';
  Ttl := Trim(ATitle);
  if Ttl = '' then Ttl := 'Program ' + PrettyName(Src);
  ST := UpperCase(Trim(AScriptType));
  if ST = '' then ST := 'INPUT';

  FL := '';
  if (AFields <> nil) and (AFields.Count > 0) then
  begin
    for I := 0 to AFields.Count - 1 do
    begin
      if I > 0 then FL := FL + ', ';
      FL := FL + 'r_' + Src + '.' + AFields[I];
    end;
  end
  else
    FL := 'r_' + Src + '.*';

  if ST = 'INPUT' then
  begin
    Result :=
      '-- 4GL skripta za unos u ' + Src + LineEnding +
      'MAIN' + LineEnding +
      '  DEFINE r_' + Src + ' RECORD LIKE ' + Src + '.*' + LineEnding +
      LineEnding +
      '  CLEAR SCREEN' + LineEnding +
      '  DISPLAY "' + Ttl + '" AT 2, 2' + LineEnding +
      '  INPUT BY NAME ' + FL + ' WITHOUT DEFAULTS' + LineEnding +
      '    ON ACTION spremi' + LineEnding +
      '      INSERT INTO ' + Src + ' VALUES (r_' + Src + '.*)' + LineEnding +
      '      MESSAGE "Zapis je uspješno spremljen."' + LineEnding +
      '      EXIT INPUT' + LineEnding +
      '    ON ACTION odustani' + LineEnding +
      '      MESSAGE "Unos prekinut."' + LineEnding +
      '      EXIT INPUT' + LineEnding +
      '  END INPUT' + LineEnding +
      'END MAIN' + LineEnding;
  end
  else if ST = 'CONSTRUCT' then
  begin
    Result :=
      '-- 4GL skripta za filtriranje i pretragu ' + Src + LineEnding +
      'MAIN' + LineEnding +
      '  DEFINE where_clause TEXT' + LineEnding +
      '  CLEAR SCREEN' + LineEnding +
      '  DISPLAY "' + Ttl + ' - Kriterij pretrage" AT 2, 2' + LineEnding +
      '  CONSTRUCT BY NAME where_clause ON ' + FL + LineEnding +
      '    ON ACTION trazi' + LineEnding +
      '      EXIT CONSTRUCT' + LineEnding +
      '    ON ACTION odustani' + LineEnding +
      '      LET where_clause = ""' + LineEnding +
      '      EXIT CONSTRUCT' + LineEnding +
      '  END CONSTRUCT' + LineEnding +
      '  IF where_clause <> "" THEN' + LineEnding +
      '    DISPLAY "WHERE: ", where_clause AT 10, 2' + LineEnding +
      '  END IF' + LineEnding +
      'END MAIN' + LineEnding;
  end
  else if ST = 'DISPLAY' then
  begin
    Result :=
      '-- 4GL skripta za pregled tablice ' + Src + LineEnding +
      'MAIN' + LineEnding +
      '  DEFINE r_' + Src + ' RECORD LIKE ' + Src + '.*' + LineEnding +
      '  CLEAR SCREEN' + LineEnding +
      '  DISPLAY "' + Ttl + '" AT 2, 2' + LineEnding +
      '  DISPLAY ARRAY r_' + Src + '.* TO s_' + Src + '.*' + LineEnding +
      '    ON ACTION izlaz' + LineEnding +
      '      EXIT DISPLAY' + LineEnding +
      '  END DISPLAY' + LineEnding +
      'END MAIN' + LineEnding;
  end
  else
  begin
    Result :=
      '-- 4GL glavni izbornik za ' + Src + LineEnding +
      'MAIN' + LineEnding +
      '  MENU "' + Ttl + '"' + LineEnding +
      '    COMMAND "Pregled" "Pregled svih zapisa"' + LineEnding +
      '      CALL pregled_' + Src + '()' + LineEnding +
      '    COMMAND "Unos" "Unos novog zapisa"' + LineEnding +
      '      CALL unos_' + Src + '()' + LineEnding +
      '    COMMAND "Izlaz" "Povratak"' + LineEnding +
      '      EXIT MENU' + LineEnding +
      '  END MENU' + LineEnding +
      'END MAIN' + LineEnding;
  end;
end;

function GenerateFormWithFilters(ADb: TAppDb; ACtx: PTaWizardContext): Boolean;
var
  Opt: TaFormOptions;
begin
  Result := False;
  FillChar(Opt, SizeOf(Opt), 0);
  Opt.Source := ACtx^.DataSource;
  Opt.Title := ACtx^.Title;
  Opt.Name := 'frm_' + Ident(ACtx^.DataSource);
  Opt.Fields := ACtx^.Fields;
  Opt.FilterFields := ACtx^.FilterFields;
  Opt.AddRefreshButton := True;
  Opt.AddClearButton := True;
  Opt.Layout := flDatasheet;

  FreeWizardResult(ACtx^.Result);
  ACtx^.Result.FormDef := BuildFormWithFilters(ADb, Opt);
  if ACtx^.Result.FormDef <> nil then
  begin
    ACtx^.Result.Kind := wrkForm;
    ACtx^.Result.SavedName := Opt.Name;
    Result := True;
  end
  else
    ACtx^.Result.Error := 'Neuspjelo generiranje forme s filterom.';
end;

function GenerateFormCard(ADb: TAppDb; ACtx: PTaWizardContext): Boolean;
var
  Opt: TaFormOptions;
begin
  Result := False;
  FillChar(Opt, SizeOf(Opt), 0);
  Opt.Source := ACtx^.DataSource;
  Opt.Title := ACtx^.Title;
  Opt.Name := 'frm_' + Ident(ACtx^.DataSource);
  Opt.Fields := ACtx^.Fields;
  Opt.Layout := flOneColumn;

  FreeWizardResult(ACtx^.Result);
  ACtx^.Result.FormDef := BuildFormEx(ADb, Opt);
  if ACtx^.Result.FormDef <> nil then
  begin
    ACtx^.Result.Kind := wrkForm;
    ACtx^.Result.SavedName := Opt.Name;
    Result := True;
  end
  else
    ACtx^.Result.Error := 'Neuspjelo generiranje standardne forme.';
end;

function GenerateReportGroup(ADb: TAppDb; ACtx: PTaWizardContext): Boolean;
var
  Opt: TaReportOptions;
begin
  Result := False;
  FillChar(Opt, SizeOf(Opt), 0);
  Opt.Source := ACtx^.DataSource;
  Opt.Title := ACtx^.Title;
  Opt.Name := 'rep_' + Ident(ACtx^.DataSource);
  Opt.Fields := ACtx^.Fields;
  Opt.Kind := rkTabular;
  Opt.Sums := True;

  FreeWizardResult(ACtx^.Result);
  ACtx^.Result.ReportDef := BuildReportEx(ADb, Opt);
  if ACtx^.Result.ReportDef <> nil then
  begin
    ACtx^.Result.Kind := wrkReport;
    ACtx^.Result.SavedName := Opt.Name;
    Result := True;
  end
  else
    ACtx^.Result.Error := 'Neuspjelo generiranje izvještaja.';
end;

function GenerateFglScript(ADb: TAppDb; ACtx: PTaWizardContext): Boolean;
begin
  Result := False;
  FreeWizardResult(ACtx^.Result);
  ACtx^.Result.FglSource := BuildFglScript(ADb, ACtx^.DataSource, ACtx^.Title, ACtx^.FglScriptType, ACtx^.Fields);
  if ACtx^.Result.FglSource <> '' then
  begin
    ACtx^.Result.Kind := wrkFgl;
    ACtx^.Result.SavedName := 'fgl_' + Ident(ACtx^.DataSource);
    Result := True;
  end
  else
    ACtx^.Result.Error := 'Neuspjelo generiranje 4GL skripte.';
end;

function SuggestSolutions(ADb: TAppDb; const ASource, ATitle: string; const AFields: TaSourceFields): TaWizardSolutions;
var
  Ttl: string;
  HasFilterKw, HasReportKw, HasInputKw: Boolean;
  CFilter, CCard, CReport, CFgl: Integer;

  procedure AddSol(const AId, ATitle, ADesc: string; AConf: Integer; AGen: TWizardGenerateProc);
  var
    N: Integer;
  begin
    N := Length(Result);
    SetLength(Result, N + 1);
    Result[N].SolutionId := AId;
    Result[N].Title := ATitle;
    Result[N].Description := ADesc;
    Result[N].Confidence := AConf;
    Result[N].Generate := AGen;
  end;

  procedure SortSolutions;
  var
    I, J: Integer;
    Tmp: TaWizardSolution;
  begin
    for I := 0 to High(Result) - 1 do
      for J := I + 1 to High(Result) do
        if Result[J].Confidence > Result[I].Confidence then
        begin
          Tmp := Result[I];
          Result[I] := Result[J];
          Result[J] := Tmp;
        end;
  end;

begin
  SetLength(Result, 0);
  Ttl := LowerCase(ATitle);

  HasFilterKw := (Pos('filter', Ttl) > 0) or (Pos('pretrag', Ttl) > 0) or (Pos('traz', Ttl) > 0) or
                 (Pos('traž', Ttl) > 0) or (Pos('popis', Ttl) > 0) or (Pos('stanj', Ttl) > 0) or
                 (Pos('grid', Ttl) > 0) or (Pos('mrez', Ttl) > 0) or (Pos('mrež', Ttl) > 0);

  HasReportKw := (Pos('izvjest', Ttl) > 0) or (Pos('izvješt', Ttl) > 0) or (Pos('ispis', Ttl) > 0) or
                 (Pos('pregled', Ttl) > 0) or (Pos('sumarn', Ttl) > 0) or (Pos('rekapit', Ttl) > 0) or
                 (Pos('statist', Ttl) > 0) or (Pos('promet', Ttl) > 0);

  HasInputKw := (Pos('unos', Ttl) > 0) or (Pos('novi', Ttl) > 0) or (Pos('nova', Ttl) > 0) or
                (Pos('evident', Ttl) > 0) or (Pos('azurir', Ttl) > 0) or (Pos('ažurir', Ttl) > 0) or
                (Pos('skript', Ttl) > 0) or (Pos('4gl', Ttl) > 0);

  if HasFilterKw then
  begin
    CFilter := 92;
    CCard := 68;
    CReport := 65;
    CFgl := 50;
  end
  else if HasReportKw then
  begin
    CReport := 90;
    CFilter := 70;
    CCard := 60;
    CFgl := 45;
  end
  else if HasInputKw then
  begin
    CFgl := 88;
    CCard := 82;
    CFilter := 65;
    CReport := 45;
  end
  else
  begin
    CCard := 85;
    CFilter := 80;
    CReport := 65;
    CFgl := 55;
  end;

  AddSol('formgrid-filter', 'Forma s filterom i mrežom',
    'Tablični pregled s brzim filter poljima iznad mreže i gumbima Osvježi / Očisti',
    CFilter, @GenerateFormWithFilters);

  AddSol('form-card', 'Standardna forma (kartica)',
    'Forma za pregled i uređivanje pojedinačnog zapisa s kontrolama prilagođenim tipovima polja',
    CCard, @GenerateFormCard);

  AddSol('report-group', 'Tablični izvještaj sa zbrojevima',
    'Izvještaj za ispis ili PDF s automatskim formatiranjem stupaca i sumama',
    CReport, @GenerateReportGroup);

  AddSol('fgl-input', '4GL programski predložak',
    'Tekstualna 4GL skripta s blokovima za unos (INPUT), filtriranje (CONSTRUCT) ili pregled',
    CFgl, @GenerateFglScript);

  SortSolutions;
end;

procedure RegisterStandardWizardSolutions;
var
  Sol: TaWizardSolution;
begin
  Sol.SolutionId := 'formgrid-filter';
  Sol.Title := Tr('Form with a filter and a grid');
  Sol.Description := 'Tablični pregled s brzim filter poljima iznad mreže i gumbima Osvježi / Očisti';
  Sol.Confidence := 90;
  Sol.Generate := @GenerateFormWithFilters;
  RegisterWizardSolution(Sol);

  Sol.SolutionId := 'form-card';
  Sol.Title := Tr('Standard form (card)');
  Sol.Description := 'Forma za unos i pregled pojedinačnog zapisa';
  Sol.Confidence := 85;
  Sol.Generate := @GenerateFormCard;
  RegisterWizardSolution(Sol);

  Sol.SolutionId := 'report-group';
  Sol.Title := Tr('Tabular report with totals');
  Sol.Description := 'Izvještaj sa zbrojevima i formatiranjem za ispis';
  Sol.Confidence := 80;
  Sol.Generate := @GenerateReportGroup;
  RegisterWizardSolution(Sol);

  Sol.SolutionId := 'fgl-input';
  Sol.Title := Tr('4GL program template');
  Sol.Description := 'Tekstualna 4GL skripta s blokovima za unos/pretragu';
  Sol.Confidence := 75;
  Sol.Generate := @GenerateFglScript;
  RegisterWizardSolution(Sol);
end;

initialization
  RegisterStandardWizardSolutions;

end.
