unit ta_catalog;
{ Katalog shema: opisi cestih domena (racuni, recepti, budzet...) kao JSON.
  Iz njih se (1) gradi primjer-baza s tablicama, vezama, podacima i formama,
  (2) nudi biblioteka polja za carobnjake (isti "koncept" polja u vise domena
  dobiva isti tip, format, provjeru i opis), (3) pise HTML dokumentacija:
  polje, tip, uloga i gdje se sve pojavljuje. Format je opisan u catalog/README.md. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, contnrs, fpjson, jsonparser, ta_meta, ta_types;

const
  { dopustene uloge polja }
  CatRoles: array[0..21] of string = (
    'kljuc', 'sifra', 'naziv', 'opis', 'biljeska', 'kategorija', 'veza', 'status',
    'oznaka', 'kolicina', 'cijena', 'iznos', 'postotak', 'datum', 'vrijeme',
    'kontakt', 'adresa', 'identifikator', 'mjera', 'slika', 'redoslijed', 'rezultat');

type
  TCatField = class
  public
    Name, Concept, Caption, TypeName, Role, Descr, Format, DefaultExpr: string;
    Validation, ValidationMsg, RefTable, RefField, OnDelete, Choices: string;
    Decimals, ColWidth: Integer;
    PK, Required: Boolean;
    function LType: TaLogicalType;
    function Key: string;
  end;

  TCatTable = class
  public
    Name, Caption, Descr: string;
    Fields: TObjectList;
    Rows: TObjectList;          { TStringList po retku, vrijednosti po poljima }
    WithReport: Boolean;
    ReportGroup, ReportSort: string;
    constructor Create;
    destructor Destroy; override;
    function FieldIndex(const AName: string): Integer;
  end;

  TCatDomain = class
  public
    Id, Title, Descr, Tags, Source: string;
    Tables: TObjectList;
    constructor Create;
    destructor Destroy; override;
    function FindTable(const AName: string): TCatTable;
  end;

  { Polje iz biblioteke: definicija + sva mjesta na kojima se pojavljuje. }
  TCatConcept = class
  public
    Key: string;
    Def: TCatField;
    Where: TStringList;         { domena.tablica.polje }
    constructor Create;
    destructor Destroy; override;
  end;

  TaCatalog = class
  public
    Domains: TObjectList;
    Concepts: TObjectList;
    constructor Create;
    destructor Destroy; override;
    { baca Exception s porukom o mjestu greske }
    procedure AddJson(const AText, ASource: string);
    procedure LoadEmbedded;
    procedure LoadDir(const ADir: string);
    procedure BuildIndex;
    function FindDomain(const AId: string): TCatDomain;
    function FindConcept(const AKey: string): TCatConcept;
    { biblioteka polja po tekstu (naziv, oznaka, opis) i ulozi; prazno = sve }
    procedure SearchConcepts(const AText, ARole: string; AOut: TList);
  end;

{ Katalog ucitan jednom: ugradjeni + mapa catalog/ pokraj programa ili TYPHACCESS_CATALOG. }
function Catalog: TaCatalog;

{ Definicija polja za tablicu (TFieldDef) iz kataloga; Meta je nova i pripada pozivatelju. }
procedure CatalogFieldDef(AField: TCatField; out ADef: TFieldDef);

{ Gradi domenu u otvorenoj bazi. Tablice koje vec postoje se preskacu. }
function BuildCatalogDomain(ADb: TAppDb; ADomain: TCatDomain; ASamples, AForms: Boolean;
  ALog: TStrings): Boolean;

{ Provjera cijelog kataloga; vraca broj problema, poruke u ALog. }
function ValidateCatalog(ACat: TaCatalog; ALog: TStrings): Integer;

{ HTML dokumentacija: domene, tablice, polja (tip, uloga, opis) i biblioteka polja. }
function CatalogHtml(ACat: TaCatalog): string;

{ Snimka sheme: iz otvorene baze pravi JSON domene kataloga (tablice, tipovi, veze, rjecnik polja,
  neobavezno prvih ASampleRows redaka kao primjer). Uloge se pogadaju iz tipa i naziva polja.
  Veze na tablice izvan snimke se izostavljaju; veze u primjerima koje ne pogadaju uzorak postaju prazne. }
function SnapshotToCatalogJson(ADb: TAppDb; const AId, ATitle, ADescr: string;
  ATables: TStrings; ASampleRows: Integer; ALog: TStrings): string;
{ Dopunjuje rjecnik polja postojece tablice iz kataloga: polja ciji se naziv podudara s konceptom
  dobivaju oznaku, opis, format, provjeru i sirinu - samo ako su ta svojstva jos prazna. Tip se ne mijenja;
  polja cije se vrste ne slazu s katalogom preskacu se. Vraca broj dopunjenih polja. }
function ApplyCatalogToTable(ADb: TAppDb; const ATable: string; ALog: TStrings): Integer;
{ naziv u obliku dopustenom u katalogu: mala slova, bez dijakritika, [a-z0-9_] }
function SnapIdent(const S: string): string;

implementation

uses
  ta_i18n,
  StrUtils, Variants, DB, ZDataset, ZDatasetParam, ta_expr, ta_formdef, ta_reportdef, ta_wizardgen, ta_migrate,
  ta_catalogdata;

{ ============================ model ============================ }

function TCatField.LType: TaLogicalType;
begin
  Result := LogicalFromName(TypeName);
end;

function TCatField.Key: string;
begin
  if Concept <> '' then Result := Concept else Result := Name;
end;

constructor TCatTable.Create;
begin
  Fields := TObjectList.Create(True);
  Rows := TObjectList.Create(True);
end;

destructor TCatTable.Destroy;
begin
  Fields.Free;
  Rows.Free;
  inherited Destroy;
end;

function TCatTable.FieldIndex(const AName: string): Integer;
var
  I: Integer;
begin
  for I := 0 to Fields.Count - 1 do
    if SameText(TCatField(Fields[I]).Name, AName) then Exit(I);
  Result := -1;
end;

constructor TCatDomain.Create;
begin
  Tables := TObjectList.Create(True);
end;

destructor TCatDomain.Destroy;
begin
  Tables.Free;
  inherited Destroy;
end;

function TCatDomain.FindTable(const AName: string): TCatTable;
var
  I: Integer;
begin
  for I := 0 to Tables.Count - 1 do
    if SameText(TCatTable(Tables[I]).Name, AName) then Exit(TCatTable(Tables[I]));
  Result := nil;
end;

constructor TCatConcept.Create;
begin
  Where := TStringList.Create;
end;

destructor TCatConcept.Destroy;
begin
  Where.Free;
  inherited Destroy;
end;

constructor TaCatalog.Create;
begin
  Domains := TObjectList.Create(True);
  Concepts := TObjectList.Create(True);
end;

destructor TaCatalog.Destroy;
begin
  Domains.Free;
  Concepts.Free;
  inherited Destroy;
end;

{ ============================ JSON ============================ }

function JStr(O: TJSONObject; const AKey: string): string;
var
  D: TJSONData;
begin
  D := O.Find(AKey);
  if (D = nil) or (D.JSONType = jtNull) then Exit('');
  Result := D.AsString;
end;

function JInt(O: TJSONObject; const AKey: string; ADef: Integer): Integer;
var
  D: TJSONData;
begin
  D := O.Find(AKey);
  if (D = nil) or (D.JSONType = jtNull) then Exit(ADef);
  Result := D.AsInteger;
end;

function JBool(O: TJSONObject; const AKey: string): Boolean;
var
  D: TJSONData;
begin
  D := O.Find(AKey);
  Result := (D <> nil) and (D.JSONType = jtBoolean) and D.AsBoolean;
end;

function CellText(D: TJSONData): string;
begin
  case D.JSONType of
    jtNull: Result := '';
    jtBoolean: if D.AsBoolean then Result := '1' else Result := '0';
    jtNumber:
      if D is TJSONFloatNumber then Result := FloatToStr(D.AsFloat, InvariantFS)
      else Result := D.AsString;
  else
    Result := D.AsString;
  end;
end;

procedure TaCatalog.AddJson(const AText, ASource: string);
var
  Root: TJSONData;
  O, TO_, FO: TJSONObject;
  Dom: TCatDomain;
  Tb: TCatTable;
  F: TCatField;
  Ts, Fs, Rs, Row: TJSONArray;
  I, J, K: Integer;
  Row2: TStringList;
  Old: Integer;
begin
  try
    Root := GetJSON(AText);
  except
    on E: Exception do raise Exception.Create(ASource + Tr(': invalid JSON: ') + E.Message);
  end;
  try
    if not (Root is TJSONObject) then raise Exception.Create(ASource + Tr(': the root must be an object'));
    O := TJSONObject(Root);
    Dom := TCatDomain.Create;
    Dom.Source := ASource;
    Dom.Id := JStr(O, 'id');
    Dom.Title := JStr(O, 'title');
    Dom.Descr := JStr(O, 'descr');
    Dom.Tags := JStr(O, 'tags');
    if Dom.Id = '' then begin Dom.Free; raise Exception.Create(ASource + Tr(': missing "id"')); end;
    Ts := O.Find('tables') as TJSONArray;
    if Ts = nil then begin Dom.Free; raise Exception.Create(ASource + Tr(': missing "tables"')); end;
    for I := 0 to Ts.Count - 1 do
    begin
      TO_ := Ts.Objects[I];
      Tb := TCatTable.Create;
      Dom.Tables.Add(Tb);
      Tb.Name := JStr(TO_, 'name');
      Tb.Caption := JStr(TO_, 'caption');
      if Tb.Caption = '' then Tb.Caption := Tb.Name;
      Tb.Descr := JStr(TO_, 'descr');
      Tb.WithReport := JBool(TO_, 'report');
      Tb.ReportGroup := JStr(TO_, 'report_group');
      Tb.ReportSort := JStr(TO_, 'report_sort');
      Fs := TO_.Find('fields') as TJSONArray;
      if Fs = nil then raise Exception.Create(ASource + Tr(': table ') + Tb.Name + Tr(' has no "fields"'));
      for J := 0 to Fs.Count - 1 do
      begin
        FO := Fs.Objects[J];
        F := TCatField.Create;
        Tb.Fields.Add(F);
        F.Name := JStr(FO, 'name');
        F.Concept := JStr(FO, 'concept');
        F.Caption := JStr(FO, 'caption');
        if F.Caption = '' then F.Caption := F.Name;
        F.TypeName := JStr(FO, 'type');
        if F.TypeName = '' then F.TypeName := 'text';
        F.Role := JStr(FO, 'role');
        F.Descr := JStr(FO, 'descr');
        F.Format := JStr(FO, 'format');
        F.DefaultExpr := JStr(FO, 'default');
        F.Validation := JStr(FO, 'validation');
        F.ValidationMsg := JStr(FO, 'validation_msg');
        F.Choices := JStr(FO, 'choices');
        F.Decimals := JInt(FO, 'decimals', -1);
        F.ColWidth := JInt(FO, 'width', 0);
        F.PK := JBool(FO, 'pk');
        F.Required := JBool(FO, 'required');
        F.OnDelete := JStr(FO, 'on_delete');
        K := Pos('.', JStr(FO, 'ref'));
        if K > 0 then
        begin
          F.RefTable := Copy(JStr(FO, 'ref'), 1, K - 1);
          F.RefField := Copy(JStr(FO, 'ref'), K + 1, MaxInt);
        end;
      end;
      Rs := TO_.Find('sample') as TJSONArray;
      if Rs <> nil then
        for J := 0 to Rs.Count - 1 do
        begin
          Row := Rs.Arrays[J];
          Row2 := TStringList.Create;
          for K := 0 to Row.Count - 1 do Row2.Add(CellText(Row.Items[K]));
          Tb.Rows.Add(Row2);
        end;
    end;
    { ista domena se zamjenjuje (mapa na disku nadjacava ugradjenu) }
    Old := -1;
    for I := 0 to Domains.Count - 1 do
      if SameText(TCatDomain(Domains[I]).Id, Dom.Id) then Old := I;
    if Old >= 0 then Domains.Delete(Old);
    Domains.Add(Dom);
  finally
    Root.Free;
  end;
end;

procedure TaCatalog.LoadEmbedded;
var
  I: Integer;
begin
  for I := 0 to CatalogDataCount - 1 do AddJson(CatalogData(I), 'ugrađeni katalog #' + IntToStr(I + 1));
  BuildIndex;
end;

procedure TaCatalog.LoadDir(const ADir: string);
var
  SR: TSearchRec;
  L: TStringList;
begin
  if not DirectoryExists(ADir) then Exit;
  if FindFirst(IncludeTrailingPathDelimiter(ADir) + '*.json', faAnyFile, SR) = 0 then
  begin
    try
      repeat
        L := TStringList.Create;
        try
          L.LoadFromFile(IncludeTrailingPathDelimiter(ADir) + SR.Name);
          AddJson(L.Text, SR.Name);
        finally
          L.Free;
        end;
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
  end;
  BuildIndex;
end;

procedure TaCatalog.BuildIndex;
var
  I, J, K: Integer;
  D: TCatDomain;
  T: TCatTable;
  F: TCatField;
  C: TCatConcept;
begin
  Concepts.Clear;
  for I := 0 to Domains.Count - 1 do
  begin
    D := TCatDomain(Domains[I]);
    for J := 0 to D.Tables.Count - 1 do
    begin
      T := TCatTable(D.Tables[J]);
      for K := 0 to T.Fields.Count - 1 do
      begin
        F := TCatField(T.Fields[K]);
        { kljucevi i veze su specificni za tablicu, ne ulaze u biblioteku }
        if F.PK or (F.RefTable <> '') then Continue;
        C := FindConcept(F.Key);
        if C = nil then
        begin
          C := TCatConcept.Create;
          C.Key := F.Key;
          C.Def := F;
          Concepts.Add(C);
        end;
        C.Where.Add(D.Title + ' › ' + T.Caption + ' › ' + F.Name);
      end;
    end;
  end;
end;

function TaCatalog.FindDomain(const AId: string): TCatDomain;
var
  I: Integer;
begin
  for I := 0 to Domains.Count - 1 do
    if SameText(TCatDomain(Domains[I]).Id, AId) then Exit(TCatDomain(Domains[I]));
  Result := nil;
end;

function TaCatalog.FindConcept(const AKey: string): TCatConcept;
var
  I: Integer;
begin
  for I := 0 to Concepts.Count - 1 do
    if SameText(TCatConcept(Concepts[I]).Key, AKey) then Exit(TCatConcept(Concepts[I]));
  Result := nil;
end;

procedure TaCatalog.SearchConcepts(const AText, ARole: string; AOut: TList);
var
  I: Integer;
  C: TCatConcept;
  Q, Hay: string;
begin
  Q := LowerCase(Trim(AText));
  for I := 0 to Concepts.Count - 1 do
  begin
    C := TCatConcept(Concepts[I]);
    if (ARole <> '') and not SameText(C.Def.Role, ARole) then Continue;
    Hay := LowerCase(C.Key + ' ' + C.Def.Caption + ' ' + C.Def.Descr + ' ' + C.Def.Role);
    if (Q = '') or (Pos(Q, Hay) > 0) then AOut.Add(C);
  end;
end;

var
  GCatalog: TaCatalog = nil;

function Catalog: TaCatalog;
var
  Dir: string;
begin
  if GCatalog = nil then
  begin
    GCatalog := TaCatalog.Create;
    GCatalog.LoadEmbedded;
    Dir := GetEnvironmentVariable('TYPHACCESS_CATALOG');
    if Dir = '' then Dir := ExtractFilePath(ParamStr(0)) + 'catalog';
    try
      GCatalog.LoadDir(Dir);
    except
      { neispravna datoteka korisnika ne smije srusiti program: ugradjeni katalog ostaje }
    end;
  end;
  Result := GCatalog;
end;

{ ============================ definicije polja ============================ }

function ChoiceList(const AChoices: string): TStringList;
begin
  Result := TStringList.Create;
  Result.Delimiter := ',';
  Result.StrictDelimiter := True;
  Result.DelimitedText := AChoices;
end;

function EffectiveValidation(F: TCatField; out AMsg: string): string;
var
  L: TStringList;
  I: Integer;
begin
  Result := F.Validation;
  AMsg := F.ValidationMsg;
  if (Result = '') and (F.Choices <> '') then
  begin
    L := ChoiceList(F.Choices);
    try
      Result := '[value] In (';
      for I := 0 to L.Count - 1 do
      begin
        if I > 0 then Result := Result + ', ';
        Result := Result + '"' + Trim(L[I]) + '"';
      end;
      Result := Result + ')';
      if AMsg = '' then AMsg := 'Dozvoljeno: ' + StringReplace(F.Choices, ',', ', ', [rfReplaceAll]);
    finally
      L.Free;
    end;
  end;
end;

procedure CatalogFieldDef(AField: TCatField; out ADef: ta_meta.TFieldDef);
var
  M: TaFieldMeta;
  Msg: string;
begin
  M := TaFieldMeta.Create;
  M.LType := AField.LType;
  if AField.Decimals >= 0 then M.Decimals := AField.Decimals
  else if M.LType in [ltDecimal, ltCurrency] then M.Decimals := 2
  else M.Decimals := 0;
  M.Format := AField.Format;
  M.DefaultExpr := AField.DefaultExpr;
  M.Validation := EffectiveValidation(AField, Msg);
  M.ValidationMsg := Msg;
  M.Caption := AField.Caption;
  M.Description := AField.Descr;
  M.ColWidth := AField.ColWidth;
  ADef.Name := AField.Name;
  ADef.Meta := M;
  ADef.PrimaryKey := AField.PK;
  ADef.NotNull := AField.Required or AField.PK;
  ADef.SqlType := PhysicalType(M.LType);
  ADef.RefTable := '';
  ADef.RefField := '';
  ADef.OnDelete := '';
end;

{ ============================ gradnja baze ============================ }

procedure BindCell(P: TZParam; AType: TaLogicalType; const AText: string);
var
  D: Double;
  I64: Int64;
begin
  if AText = '' then
  begin
    case AType of
      ltInteger, ltYesNo, ltAutoNumber: P.DataType := ftLargeint;
      ltDecimal, ltCurrency: P.DataType := ftFloat;
      ltPicture: P.DataType := ftBlob;
    else
      P.DataType := ftString;
    end;
    P.Clear;
    Exit;
  end;
  case AType of
    ltInteger, ltYesNo, ltAutoNumber:
      if TryStrToInt64(AText, I64) then P.AsLargeInt := I64
      else if TryStrToFloat(AText, D, InvariantFS) then P.AsLargeInt := Round(D)
      else P.AsString := AText;
    ltDecimal, ltCurrency:
      if TryStrToFloat(AText, D, InvariantFS) then P.AsFloat := D else P.AsString := AText;
  else
    P.AsString := AText;
  end;
end;

function BuildCatalogDomain(ADb: TAppDb; ADomain: TCatDomain; ASamples, AForms: Boolean;
  ALog: TStrings): Boolean;
var
  Existing: TStringList;
  Made: TStringList;
  I, J, K, N: Integer;
  T, RT: TCatTable;
  F: TCatField;
  Fd: TFieldDefs2;
  Fks: TaFkDefs;
  Q: TZQuery;
  Cols, Ph, Auto: string;
  Def: TaFormDef;
  Rdef: TaReportDef;
  Names: TStringList;
  Failed: Integer;
begin
  Result := False;
  Failed := 0;
  if not ADb.Connected then begin ALog.Add('GREŠKA: baza nije otvorena'); Exit; end;
  Existing := ADb.UserTables;
  Made := TStringList.Create;
  try
    for I := 0 to Existing.Count - 1 do Existing[I] := LowerCase(Existing[I]);
    { 1. tablice }
    for I := 0 to ADomain.Tables.Count - 1 do
    begin
      T := TCatTable(ADomain.Tables[I]);
      if Existing.IndexOf(LowerCase(T.Name)) >= 0 then
      begin
        ALog.Add('preskočeno (već postoji): ' + T.Name);
        Continue;
      end;
      SetLength(Fd, T.Fields.Count);
      for J := 0 to T.Fields.Count - 1 do CatalogFieldDef(TCatField(T.Fields[J]), Fd[J]);
      try
        ADb.CreateTable(T.Name, Fd);
        Made.Add(T.Name);
        ALog.Add('tablica ' + T.Name + ': ' + IntToStr(T.Fields.Count) + ' polja');
      except
        on E: Exception do
        begin
          Inc(Failed);
          ALog.Add('GREŠKA tablica ' + T.Name + ': ' + E.Message);
        end;
      end;
      for J := 0 to High(Fd) do Fd[J].Meta.Free;
    end;
    { 2. primjeri redaka }
    if ASamples then
      for I := 0 to ADomain.Tables.Count - 1 do
      begin
        T := TCatTable(ADomain.Tables[I]);
        if (Made.IndexOf(T.Name) < 0) or (T.Rows.Count = 0) then Continue;
        Cols := ''; Ph := ''; Auto := '';
        for J := 0 to T.Fields.Count - 1 do
        begin
          if J > 0 then begin Cols := Cols + ', '; Ph := Ph + ', '; end;
          Cols := Cols + ADb.QuoteId(TCatField(T.Fields[J]).Name);
          Ph := Ph + ':p' + IntToStr(J);
          if TCatField(T.Fields[J]).LType = ltAutoNumber then Auto := TCatField(T.Fields[J]).Name;
        end;
        Q := ADb.NewQuery('INSERT INTO ' + ADb.QuoteId(T.Name) + ' (' + Cols + ') VALUES (' + Ph + ')');
        try
          N := 0;
          try
            for K := 0 to T.Rows.Count - 1 do
            begin
              for J := 0 to T.Fields.Count - 1 do
                if J < TStringList(T.Rows[K]).Count then
                  BindCell(Q.Params.ParamByName('p' + IntToStr(J)), TCatField(T.Fields[J]).LType, TStringList(T.Rows[K])[J])
                else
                  BindCell(Q.Params.ParamByName('p' + IntToStr(J)), TCatField(T.Fields[J]).LType, '');
              Q.ExecSQL;
              Inc(N);
            end;
            if Auto <> '' then FixSequence(ADb, T.Name, Auto);
            ALog.Add('podaci ' + T.Name + ': ' + IntToStr(N) + ' redaka');
          except
            on E: Exception do
            begin
              Inc(Failed);
              ALog.Add('GREŠKA podaci ' + T.Name + ': ' + E.Message);
            end;
          end;
        finally
          Q.Free;
        end;
      end;
    { 3. veze }
    for I := 0 to ADomain.Tables.Count - 1 do
    begin
      T := TCatTable(ADomain.Tables[I]);
      if Made.IndexOf(T.Name) < 0 then Continue;
      SetLength(Fks, 0);
      for J := 0 to T.Fields.Count - 1 do
      begin
        F := TCatField(T.Fields[J]);
        if F.RefTable = '' then Continue;
        RT := ADomain.FindTable(F.RefTable);
        if (RT = nil) or ((Made.IndexOf(RT.Name) < 0) and (Existing.IndexOf(LowerCase(RT.Name)) < 0)) then
        begin
          ALog.Add('UPOZORENJE veza ' + T.Name + '.' + F.Name + ' → ' + F.RefTable + ': tablica ne postoji');
          Continue;
        end;
        SetLength(Fks, Length(Fks) + 1);
        Fks[High(Fks)].FromCol := F.Name;
        Fks[High(Fks)].RefTable := F.RefTable;
        Fks[High(Fks)].RefCol := F.RefField;
        Fks[High(Fks)].OnDelete := UpperCase(F.OnDelete);
        Fks[High(Fks)].OnUpdate := '';
      end;
      if Length(Fks) = 0 then Continue;
      try
        ADb.SetFks(T.Name, Fks);
        ALog.Add('veze ' + T.Name + ': ' + IntToStr(Length(Fks)));
      except
        on E: Exception do
        begin
          Inc(Failed);
          ALog.Add('UPOZORENJE veze ' + T.Name + ' nisu postavljene: ' + E.Message);
        end;
      end;
    end;
    { 4. forme i izvjesca }
    if AForms then
      for I := 0 to ADomain.Tables.Count - 1 do
      begin
        T := TCatTable(ADomain.Tables[I]);
        if Made.IndexOf(T.Name) < 0 then Continue;
        Names := TStringList.Create;
        try
          for J := 0 to T.Fields.Count - 1 do Names.Add(TCatField(T.Fields[J]).Name);
          try
            Def := BuildFormDef(ADb, T.Name, T.Caption, Names, Names.Count > 7);
            try
              Def.Name := T.Caption;
              ADb.SaveObject('_sys_forms', T.Caption, Def.ToJson);
            finally
              Def.Free;
            end;
            if T.WithReport then
            begin
              Rdef := BuildReportDef(ADb, T.Name, 'Popis: ' + T.Caption, T.Caption, Names,
                T.ReportGroup, T.ReportSort, False, True);
              try
                Rdef.Name := 'Popis: ' + T.Caption;
                ADb.SaveObject('_sys_reports', 'Popis: ' + T.Caption, Rdef.ToJson);
              finally
                Rdef.Free;
              end;
            end;
          except
            on E: Exception do
            begin
              Inc(Failed);
              ALog.Add('GREŠKA forma ' + T.Name + ': ' + E.Message);
            end;
          end;
        finally
          Names.Free;
        end;
      end;
    Result := Failed = 0;
  finally
    Made.Free;
    Existing.Free;
  end;
end;

{ ============================ provjera ============================ }

function ValidateCatalog(ACat: TaCatalog; ALog: TStrings): Integer;
var
  I, J, K, R: Integer;
  D: TCatDomain;
  T: TCatTable;
  F: TCatField;
  RT: TCatTable;
  Seen: TStringList;
  Cn: TCatConcept;
  Msg, Where, Expr, Dummy: string;

  procedure Bad(const AText: string);
  begin
    ALog.Add(Where + ': ' + AText);
    Inc(Result);
  end;

  function IsIdent(const S: string): Boolean;
  var
    C: Char;
  begin
    Result := S <> '';
    for C in S do
      if not (C in ['a'..'z', '0'..'9', '_']) then Result := False;
    if Result and (S[1] in ['0'..'9']) then Result := False;
  end;

  function RoleOk(const S: string): Boolean;
  var
    X: Integer;
  begin
    Result := False;
    for X := 0 to High(CatRoles) do
      if CatRoles[X] = S then Exit(True);
  end;

begin
  Result := 0;
  Seen := TStringList.Create;
  try
    for I := 0 to ACat.Domains.Count - 1 do
    begin
      D := TCatDomain(ACat.Domains[I]);
      Where := D.Id;
      if D.Title = '' then Bad('nema naslova');
      if D.Descr = '' then Bad('nema opisa');
      if D.Tables.Count = 0 then Bad('nema tablica');
      for J := 0 to D.Tables.Count - 1 do
      begin
        T := TCatTable(D.Tables[J]);
        Where := D.Id + '.' + T.Name;
        if not IsIdent(T.Name) then Bad('naziv tablice nije [a-z0-9_]');
        if T.Descr = '' then Bad('tablica nema opisa');
        if T.Fields.Count = 0 then Bad('tablica nema polja');
        Seen.Clear;
        R := 0;
        for K := 0 to T.Fields.Count - 1 do
        begin
          F := TCatField(T.Fields[K]);
          Where := D.Id + '.' + T.Name + '.' + F.Name;
          if not IsIdent(F.Name) then Bad('naziv polja nije [a-z0-9_]');
          if Seen.IndexOf(F.Name) >= 0 then Bad('naziv polja se ponavlja');
          Seen.Add(F.Name);
          if F.PK then Inc(R);
          if (F.TypeName <> '') and (LogicalNames[F.LType] <> '') and
            not SameText(LogicalNames[F.LType], F.TypeName) then Bad('nepoznat tip "' + F.TypeName + '"');
          if not RoleOk(F.Role) then Bad('uloga "' + F.Role + '" nije dopuštena');
          if F.Descr = '' then Bad('nema opisa');
          if F.Caption = '' then Bad('nema oznake');
          if F.RefTable <> '' then
          begin
            RT := D.FindTable(F.RefTable);
            if RT = nil then Bad('veza na nepostojeću tablicu ' + F.RefTable)
            else if RT.FieldIndex(F.RefField) < 0 then Bad('veza na nepostojeće polje ' + F.RefTable + '.' + F.RefField);
          end;
          Expr := EffectiveValidation(F, Msg);
          if Expr <> '' then
          begin
            Dummy := CheckExpr(Expr);
            if Dummy <> '' then Bad('provjera "' + Expr + '": ' + Dummy);
            if Msg = '' then Bad('provjera nema poruke');
          end;
          if F.DefaultExpr <> '' then
          begin
            Dummy := CheckExpr(F.DefaultExpr);
            if Dummy <> '' then Bad('zadana vrijednost "' + F.DefaultExpr + '": ' + Dummy);
          end;
        end;
        Where := D.Id + '.' + T.Name;
        if R = 0 then Bad('nema primarnog ključa');
        for K := 0 to T.Rows.Count - 1 do
          if TStringList(T.Rows[K]).Count <> T.Fields.Count then
            Bad('redak primjera #' + IntToStr(K + 1) + ' ima ' + IntToStr(TStringList(T.Rows[K]).Count) +
              ' vrijednosti, a tablica ' + IntToStr(T.Fields.Count) + ' polja');
      end;
    end;
    { isti koncept mora imati isti tip i ulogu u svim domenama }
    for I := 0 to ACat.Domains.Count - 1 do
      for J := 0 to TCatDomain(ACat.Domains[I]).Tables.Count - 1 do
      begin
        T := TCatTable(TCatDomain(ACat.Domains[I]).Tables[J]);
        for K := 0 to T.Fields.Count - 1 do
        begin
          F := TCatField(T.Fields[K]);
          if F.PK or (F.RefTable <> '') then Continue;
          Cn := ACat.FindConcept(F.Key);
          if (Cn <> nil) and (Cn.Def <> F) and
            (not SameText(Cn.Def.TypeName, F.TypeName) or (Cn.Def.Role <> F.Role)) then
          begin
            Where := TCatDomain(ACat.Domains[I]).Id + '.' + T.Name + '.' + F.Name;
            Bad('koncept "' + F.Key + '" se razlikuje po tipu ili ulozi od prve definicije (' + Cn.Def.Name + ')');
          end;
        end;
      end;
  finally
    Seen.Free;
  end;
end;

{ ============================ HTML ============================ }

function H(const S: string): string;
begin
  Result := StringReplace(StringReplace(StringReplace(S, '&', '&amp;', [rfReplaceAll]), '<', '&lt;', [rfReplaceAll]), '>', '&gt;', [rfReplaceAll]);
end;

function CatalogHtml(ACat: TaCatalog): string;
var
  B: TStringList;
  I, J, K: Integer;
  D: TCatDomain;
  T: TCatTable;
  F: TCatField;
  C: TCatConcept;
  Flags, Used, Msg: string;
  Sorted: TStringList;
begin
  B := TStringList.Create;
  try
    B.Add('<!DOCTYPE html><html lang="hr"><head><meta charset="utf-8"><title>Katalog shema</title>');
    B.Add('<style>body{font-family:sans-serif;max-width:1100px;margin:2em auto;padding:0 1em;color:#222}');
    B.Add('table{border-collapse:collapse;width:100%;margin:.5em 0 1.5em}th,td{border:1px solid #ccc;padding:4px 8px;text-align:left;vertical-align:top;font-size:.92em}');
    B.Add('th{background:#f0f0f0}.pk{font-weight:bold}.mut{color:#666}code{background:#f4f4f4;padding:0 3px}</style></head><body>');
    B.Add('<h1>Katalog shema</h1><p>' + IntToStr(ACat.Domains.Count) + ' domena, ' + IntToStr(ACat.Concepts.Count) + ' polja u biblioteci.</p><ul>');
    for I := 0 to ACat.Domains.Count - 1 do
    begin
      D := TCatDomain(ACat.Domains[I]);
      B.Add('<li><a href="#d_' + H(D.Id) + '">' + H(D.Title) + '</a> <span class="mut">— ' + H(D.Descr) + '</span></li>');
    end;
    B.Add('<li><a href="#biblioteka">Biblioteka polja</a></li></ul>');
    for I := 0 to ACat.Domains.Count - 1 do
    begin
      D := TCatDomain(ACat.Domains[I]);
      B.Add('<h2 id="d_' + H(D.Id) + '">' + H(D.Title) + '</h2><p>' + H(D.Descr) + '</p>');
      for J := 0 to D.Tables.Count - 1 do
      begin
        T := TCatTable(D.Tables[J]);
        B.Add('<h3>' + H(T.Caption) + ' <code>' + H(T.Name) + '</code></h3><p>' + H(T.Descr) + '</p>');
        B.Add('<table><tr><th>Polje</th><th>Oznaka</th><th>Tip</th><th>Uloga</th><th>Opis</th><th>Pravila</th><th>Pojavljuje se i u</th></tr>');
        for K := 0 to T.Fields.Count - 1 do
        begin
          F := TCatField(T.Fields[K]);
          Flags := '';
          if F.PK then Flags := Flags + 'ključ; ';
          if F.Required then Flags := Flags + 'obavezno; ';
          if F.RefTable <> '' then Flags := Flags + 'veza → ' + F.RefTable + '.' + F.RefField + '; ';
          if F.DefaultExpr <> '' then Flags := Flags + 'zadano ' + F.DefaultExpr + '; ';
          Msg := '';
          if (F.Validation <> '') or (F.Choices <> '') then Flags := Flags + 'provjera: ' + EffectiveValidation(F, Msg) + '; ';
          Used := '';
          if not (F.PK or (F.RefTable <> '')) then
          begin
            C := ACat.FindConcept(F.Key);
            if (C <> nil) and (C.Where.Count > 1) then
              Used := IntToStr(C.Where.Count - 1) + ' drugih mjesta (vidi biblioteku)';
          end;
          B.Add('<tr><td class="' + IfThen(F.PK, 'pk', '') + '"><code>' + H(F.Name) + '</code></td><td>' + H(F.Caption) + '</td><td>' +
            H(F.TypeName) + '</td><td>' + H(F.Role) + '</td><td>' + H(F.Descr) + '</td><td>' + H(Flags) + '</td><td>' + H(Used) + '</td></tr>');
        end;
        B.Add('</table>');
      end;
    end;
    B.Add('<h2 id="biblioteka">Biblioteka polja</h2><p>Polja koja se mogu birati u čarobnjaku za novu tablicu. Isto polje u više domena dobiva isti tip, format i provjeru.</p>');
    B.Add('<table><tr><th>Polje</th><th>Oznaka</th><th>Tip</th><th>Uloga</th><th>Opis</th><th>Pojavljuje se u</th></tr>');
    Sorted := TStringList.Create;
    try
      Sorted.Sorted := True;
      Sorted.Duplicates := dupAccept;
      for I := 0 to ACat.Concepts.Count - 1 do
        Sorted.AddObject(LowerCase(TCatConcept(ACat.Concepts[I]).Key), ACat.Concepts[I]);
      for I := 0 to Sorted.Count - 1 do
      begin
        C := TCatConcept(Sorted.Objects[I]);
        Used := '';
        for K := 0 to C.Where.Count - 1 do Used := Used + H(C.Where[K]) + '<br>';
        B.Add('<tr><td><code>' + H(C.Key) + '</code></td><td>' + H(C.Def.Caption) + '</td><td>' + H(C.Def.TypeName) + '</td><td>' +
          H(C.Def.Role) + '</td><td>' + H(C.Def.Descr) + '</td><td>' + Used + '</td></tr>');
      end;
    finally
      Sorted.Free;
    end;
    B.Add('</table></body></html>');
    Result := B.Text;
  finally
    B.Free;
  end;
end;


{ ============================ snimka sheme ============================ }

function SnapIdent(const S: string): string;
var
  U, R: string;
  I: Integer;
  C: string;
begin
  U := LowerCase(S);
  R := '';
  I := 1;
  while I <= Length(U) do
  begin
    if (U[I] = #$C4) and (I < Length(U)) then
    begin
      C := Copy(U, I, 2);
      if (C = #$C4#$8D) or (C = #$C4#$87) then R := R + 'c'
      else if C = #$C4#$91 then R := R + 'd'
      else R := R + '_';
      Inc(I, 2);
    end
    else if (U[I] = #$C5) and (I < Length(U)) then
    begin
      C := Copy(U, I, 2);
      if C = #$C5#$A1 then R := R + 's'
      else if C = #$C5#$BE then R := R + 'z'
      else R := R + '_';
      Inc(I, 2);
    end
    else
    begin
      if U[I] in ['a'..'z', '0'..'9', '_'] then R := R + U[I] else R := R + '_';
      Inc(I);
    end;
  end;
  if (R <> '') and (R[1] in ['0'..'9']) then R := 'p_' + R;
  if R = '' then R := 'polje';
  Result := R;
end;

function SnapCaption(const S: string): string;
begin
  Result := StringReplace(S, '_', ' ', [rfReplaceAll]);
  if Result <> '' then Result := UpperCase(Copy(Result, 1, 1)) + Copy(Result, 2, MaxInt);
end;

function SnapLType(const ASqlType: string): TaLogicalType;
var
  U: string;
begin
  U := UpperCase(ASqlType);
  if Pos('BOOL', U) > 0 then Result := ltYesNo
  else if (Pos('INT', U) > 0) then Result := ltInteger
  else if (Pos('REAL', U) > 0) or (Pos('FLOA', U) > 0) or (Pos('DOUB', U) > 0) or (Pos('NUMERIC', U) > 0) or (Pos('DECIMAL', U) > 0) then Result := ltDecimal
  else if Pos('TIMESTAMP', U) > 0 then Result := ltDateTime
  else if Pos('DATETIME', U) > 0 then Result := ltDateTime
  else if Pos('DATE', U) > 0 then Result := ltDate
  else if Pos('TIME', U) > 0 then Result := ltTime
  else if (Pos('BLOB', U) > 0) or (Pos('BYTEA', U) > 0) then Result := ltPicture
  else if (Pos('TEXT', U) > 0) and (Pos('TINY', U) = 0) then Result := ltText
  else Result := ltText;
end;

function SnapRole(const AName: string; AType: TaLogicalType; AIsPk, AIsRef: Boolean): string;
var
  N: string;

  function Has(const AList: string): Boolean;
  var
    L: TStringList;
    I: Integer;
  begin
    Result := False;
    L := TStringList.Create;
    try
      L.CommaText := AList;
      for I := 0 to L.Count - 1 do
        if Pos(L[I], N) > 0 then Exit(True);
    finally
      L.Free;
    end;
  end;

begin
  N := SnapIdent(AName);
  if AIsPk then Exit('kljuc');
  if AIsRef then Exit('veza');
  case AType of
    ltDate, ltDateTime: Exit('datum');
    ltTime: Exit('vrijeme');
    ltYesNo: Exit('oznaka');
    ltPicture: Exit('slika');
    ltAutoNumber: Exit('kljuc');
    ltMemo: if Has('napomen,biljesk') then Exit('biljeska') else Exit('opis');
    ltCurrency: if Has('cijen') then Exit('cijena') else Exit('iznos');
    ltInteger, ltDecimal:
      begin
        if Has('postot,posto,_pct,stopa') then Exit('postotak');
        if Has('cijen') then Exit('cijena');
        if Has('iznos,ukupno,total,osnovic') then Exit('iznos');
        if Has('redni,redosl,poredak') then Exit('redoslijed');
        Exit('kolicina');
      end;
  end;
  if Has('email,mail,telefon,mobitel,tel,fax,web,url') then Exit('kontakt');
  if Has('adres,mjesto,grad,postan,drzava,ulica') then Exit('adresa');
  if Has('oib,iban,sifra,kod,broj,barkod,serijski,id') then Exit('identifikator');
  if Has('status,stanje') then Exit('status');
  if Has('vrsta,kategorij,tip,grupa,razred') then Exit('kategorija');
  if Has('napomen,biljesk') then Exit('biljeska');
  if Has('opis') then Exit('opis');
  if Has('jedinica,mjera') then Exit('mjera');
  Result := 'naziv';
end;

function SnapshotToCatalogJson(ADb: TAppDb; const AId, ATitle, ADescr: string;
  ATables: TStrings; ASampleRows: Integer; ALog: TStrings): string;
type
  TTblInfo = record
    Src, Name: string;
    Cols: TStringList;      { izvorni nazivi stupaca }
    Types: array of TaLogicalType;
    SqlTypes: TStringList;
    PkCol: string;
    Fks: TaFkDefs;
    Metas: TFPObjectList;
    Rows: array of array of Variant;
  end;
var
  Info: array of TTblInfo;
  Root, TO_, FO: TJSONObject;
  TA, FA, RA, RowA: TJSONArray;
  Q: TZQuery;
  I, J, K, R, FkIdx, Warn: Integer;
  M: TaFieldMeta;
  SqlT, Nm, Cap, Descr, Role: string;
  Typ: TaLogicalType;
  IsPk, IsRef, KeepRef: Boolean;
  RefOk: Boolean;
  V: Variant;
  RefTblIdx: Integer;

  function FindMeta(const AT: Integer; const ACol: string): TaFieldMeta;
  var
    X: Integer;
  begin
    Result := nil;
    if Info[AT].Metas = nil then Exit;
    for X := 0 to Info[AT].Metas.Count - 1 do
      if SameText(TaFieldMeta(Info[AT].Metas[X]).FieldName, ACol) then Exit(TaFieldMeta(Info[AT].Metas[X]));
  end;

  function FkFor(const AT: Integer; const ACol: string): Integer;
  var
    X: Integer;
  begin
    Result := -1;
    for X := 0 to High(Info[AT].Fks) do
      if SameText(Info[AT].Fks[X].FromCol, ACol) then Exit(X);
  end;

  function TableIdx(const ASrc: string): Integer;
  var
    X: Integer;
  begin
    Result := -1;
    for X := 0 to High(Info) do
      if SameText(Info[X].Src, ASrc) then Exit(X);
  end;

  function SampleHas(const AT: Integer; const ACol: string; const AVal: Variant): Boolean;
  var
    C, X: Integer;
  begin
    Result := False;
    C := Info[AT].Cols.IndexOf(ACol);
    if C < 0 then
      for X := 0 to Info[AT].Cols.Count - 1 do
        if SameText(Info[AT].Cols[X], ACol) then C := X;
    if C < 0 then Exit;
    for X := 0 to High(Info[AT].Rows) do
      if (not VarIsNull(Info[AT].Rows[X][C])) and (VarToStr(Info[AT].Rows[X][C]) = VarToStr(AVal)) then Exit(True);
  end;

begin
  Warn := 0;
  SetLength(Info, ATables.Count);
  for I := 0 to High(Info) do
  begin
    Info[I].Src := ATables[I];
    Info[I].Name := SnapIdent(ATables[I]);
    Info[I].Cols := TStringList.Create;
    Info[I].SqlTypes := TStringList.Create;
    Info[I].Metas := ADb.LoadFieldMetas(ATables[I]);
    Info[I].Fks := ADb.GetFks(ATables[I]);
    Info[I].PkCol := '';
    Q := ADb.TableInfo(ATables[I]);
    try
      while not Q.EOF do
      begin
        Info[I].Cols.Add(Q.FieldByName('name').AsString);
        Info[I].SqlTypes.Add(Q.FieldByName('type').AsString);
        if (Info[I].PkCol = '') and (Q.FieldByName('pk').AsInteger = 1) then Info[I].PkCol := Q.FieldByName('name').AsString;
        Q.Next;
      end;
    finally
      Q.Free;
    end;
    if Info[I].PkCol = '' then
    begin
      Info[I].PkCol := Info[I].Cols[0];
      if ALog <> nil then ALog.Add('UPOZORENJE ' + ATables[I] + ': nema primarnog ključa, uzet je prvi stupac (' + Info[I].PkCol + ')');
      Inc(Warn);
    end;
    SetLength(Info[I].Types, Info[I].Cols.Count);
    for J := 0 to Info[I].Cols.Count - 1 do
    begin
      M := FindMeta(I, Info[I].Cols[J]);
      if M <> nil then Info[I].Types[J] := M.LType
      else Info[I].Types[J] := SnapLType(Info[I].SqlTypes[J]);
      if (Info[I].Cols[J] = Info[I].PkCol) and (Info[I].Types[J] = ltInteger) then Info[I].Types[J] := ltAutoNumber;
    end;
    { primjeri }
    SetLength(Info[I].Rows, 0);
    if ASampleRows > 0 then
    begin
      Q := ADb.NewQuery('SELECT * FROM ' + ADb.QuoteId(ATables[I]));
      try
        Q.Open;
        while (not Q.EOF) and (Length(Info[I].Rows) < ASampleRows) do
        begin
          SetLength(Info[I].Rows, Length(Info[I].Rows) + 1);
          SetLength(Info[I].Rows[High(Info[I].Rows)], Info[I].Cols.Count);
          for J := 0 to Info[I].Cols.Count - 1 do
          begin
            if Q.FieldByName(Info[I].Cols[J]).IsNull then V := Null
            else if Info[I].Types[J] in [ltInteger, ltAutoNumber, ltYesNo] then V := Q.FieldByName(Info[I].Cols[J]).AsLargeInt
            else if Info[I].Types[J] in [ltDecimal, ltCurrency] then V := Q.FieldByName(Info[I].Cols[J]).AsFloat
            else if Info[I].Types[J] = ltPicture then V := Null
            else V := Q.FieldByName(Info[I].Cols[J]).AsString;
            Info[I].Rows[High(Info[I].Rows)][J] := V;
          end;
          Q.Next;
        end;
      finally
        Q.Free;
      end;
    end;
  end;

  Root := TJSONObject.Create;
  try
    Root.Add('id', SnapIdent(AId));
    Root.Add('title', ATitle);
    Root.Add('descr', ADescr);
    Root.Add('tags', 'snimka');
    TA := TJSONArray.Create;
    Root.Add('tables', TA);
    for I := 0 to High(Info) do
    begin
      TO_ := TJSONObject.Create;
      TA.Add(TO_);
      TO_.Add('name', Info[I].Name);
      TO_.Add('caption', SnapCaption(Info[I].Src));
      TO_.Add('descr', 'Tablica ' + Info[I].Src + ' iz snimke baze; dopuni opis.');
      FA := TJSONArray.Create;
      TO_.Add('fields', FA);
      for J := 0 to Info[I].Cols.Count - 1 do
      begin
        M := FindMeta(I, Info[I].Cols[J]);
        Typ := Info[I].Types[J];
        IsPk := Info[I].Cols[J] = Info[I].PkCol;
        FkIdx := FkFor(I, Info[I].Cols[J]);
        IsRef := False;
        RefTblIdx := -1;
        if (FkIdx >= 0) and not IsPk then
        begin
          RefTblIdx := TableIdx(Info[I].Fks[FkIdx].RefTable);
          IsRef := RefTblIdx >= 0;
          if not IsRef then
          begin
            if ALog <> nil then ALog.Add('veza ' + Info[I].Src + '.' + Info[I].Cols[J] + ' → ' + Info[I].Fks[FkIdx].RefTable +
              ' izostavljena (ciljna tablica nije u snimci)');
            Inc(Warn);
          end;
        end;
        Nm := SnapIdent(Info[I].Cols[J]);
        FO := TJSONObject.Create;
        FA.Add(FO);
        FO.Add('name', Nm);
        if (M <> nil) and (M.Caption <> '') then Cap := M.Caption else Cap := SnapCaption(Info[I].Cols[J]);
        FO.Add('caption', Cap);
        FO.Add('type', LowerCase(LogicalNames[Typ]));
        if IsPk or IsRef then Role := SnapRole(Nm, Typ, IsPk, IsRef) else Role := SnapRole(Nm, Typ, False, False);
        FO.Add('role', Role);
        if (M <> nil) and (M.Description <> '') then Descr := M.Description
        else Descr := Cap + '.';
        FO.Add('descr', Descr);
        if IsPk then FO.Add('pk', True);
        if IsRef then
        begin
          FO.Add('ref', Info[RefTblIdx].Name + '.' + SnapIdent(Info[I].Fks[FkIdx].RefCol));
          if Info[I].Fks[FkIdx].OnDelete <> '' then
            case UpperCase(Info[I].Fks[FkIdx].OnDelete) of
              'CASCADE': FO.Add('on_delete', 'cascade');
              'SET NULL': FO.Add('on_delete', 'set null');
              'RESTRICT': FO.Add('on_delete', 'restrict');
            end;
        end;
        if M <> nil then
        begin
          if (M.Format <> '') and not IsPk then FO.Add('format', M.Format);
          if M.DefaultExpr <> '' then FO.Add('default', M.DefaultExpr);
          if M.Decimals > 0 then FO.Add('decimals', M.Decimals);
          if M.ColWidth > 0 then FO.Add('width', M.ColWidth);
          if M.Validation <> '' then
          begin
            FO.Add('validation', M.Validation);
            if M.ValidationMsg <> '' then FO.Add('validation_msg', M.ValidationMsg)
            else FO.Add('validation_msg', 'Vrijednost nije dopuštena.');
          end;
        end;
      end;
      if Length(Info[I].Rows) > 0 then
      begin
        RA := TJSONArray.Create;
        TO_.Add('sample', RA);
        for R := 0 to High(Info[I].Rows) do
        begin
          RowA := TJSONArray.Create;
          RA.Add(RowA);
          for J := 0 to Info[I].Cols.Count - 1 do
          begin
            V := Info[I].Rows[R][J];
            FkIdx := FkFor(I, Info[I].Cols[J]);
            KeepRef := True;
            if (FkIdx >= 0) and (Info[I].Cols[J] <> Info[I].PkCol) and not VarIsNull(V) then
            begin
              RefTblIdx := TableIdx(Info[I].Fks[FkIdx].RefTable);
              if RefTblIdx >= 0 then
                KeepRef := SampleHas(RefTblIdx, Info[I].Fks[FkIdx].RefCol, V);
            end;
            if VarIsNull(V) or not KeepRef then RowA.Add(TJSONNull.Create)
            else if Info[I].Types[J] in [ltInteger, ltAutoNumber, ltYesNo] then RowA.Add(Int64(V))
            else if Info[I].Types[J] in [ltDecimal, ltCurrency] then RowA.Add(Double(V))
            else RowA.Add(VarToStr(V));
          end;
        end;
      end;
    end;
    Result := Root.FormatJSON;
  finally
    Root.Free;
    for I := 0 to High(Info) do
    begin
      Info[I].Cols.Free;
      Info[I].SqlTypes.Free;
      Info[I].Metas.Free;
    end;
  end;
  if (ALog <> nil) and (Warn = 0) then ALog.Add('snimka bez upozorenja');
  RefOk := True;
  if RefOk then ;
end;

{ ============================ rjecnik iz kataloga ============================ }

function CompatTypes(A, B: TaLogicalType): Boolean;
  function Fam(T: TaLogicalType): Integer;
  begin
    case T of
      ltText, ltMemo: Result := 1;
      ltInteger, ltDecimal, ltCurrency, ltAutoNumber: Result := 2;
      ltYesNo: Result := 3;
      ltDate, ltTime, ltDateTime: Result := 4;
    else Result := 5;
    end;
  end;
begin
  Result := Fam(A) = Fam(B);
end;

function ApplyCatalogToTable(ADb: TAppDb; const ATable: string; ALog: TStrings): Integer;
var
  Cat: TaCatalog;
  Q: TZQuery;
  Metas: TFPObjectList;
  Cols, SqlTypes: TStringList;
  I, J: Integer;
  Cn: TCatConcept;
  Def: TCatField;
  M: TaFieldMeta;
  Found, Changed: Boolean;
  Expr, Msg: string;
  Typ: TaLogicalType;
begin
  Result := 0;
  Cat := Catalog;
  Cols := TStringList.Create;
  SqlTypes := TStringList.Create;
  Metas := ADb.LoadFieldMetas(ATable);
  try
    Q := ADb.TableInfo(ATable);
    try
      while not Q.EOF do
      begin
        Cols.Add(Q.FieldByName('name').AsString);
        SqlTypes.Add(Q.FieldByName('type').AsString);
        Q.Next;
      end;
    finally
      Q.Free;
    end;
    for I := 0 to Cols.Count - 1 do
    begin
      Cn := Cat.FindConcept(SnapIdent(Cols[I]));
      if (Cn = nil) then Continue;
      Def := Cn.Def;
      M := nil;
      for J := 0 to Metas.Count - 1 do
        if SameText(TaFieldMeta(Metas[J]).FieldName, Cols[I]) then M := TaFieldMeta(Metas[J]);
      Found := M <> nil;
      if Found then Typ := M.LType else Typ := SnapLType(SqlTypes[I]);
      if not CompatTypes(Typ, Def.LType) then
      begin
        if ALog <> nil then ALog.Add(Cols[I] + ': preskočeno (tip ' + LogicalNames[Typ] + ' se ne slaže s tipom iz kataloga ' + LogicalNames[Def.LType] + ')');
        Continue;
      end;
      if not Found then
      begin
        M := TaFieldMeta.Create;
        M.TableName := ATable;
        M.FieldName := Cols[I];
        M.LType := Typ;
      end;
      Changed := False;
      try
        if M.Caption = '' then begin M.Caption := Def.Caption; Changed := True; end;
        if M.Description = '' then begin M.Description := Def.Descr; Changed := True; end;
        if (M.ColWidth = 0) and (Def.ColWidth > 0) then begin M.ColWidth := Def.ColWidth; Changed := True; end;
        if M.LType = Def.LType then
        begin
          if (M.Format = '') and (Def.Format <> '') then begin M.Format := Def.Format; Changed := True; end;
          if (M.Decimals = 0) and (Def.Decimals > 0) then begin M.Decimals := Def.Decimals; Changed := True; end;
        end;
        if M.Validation = '' then
        begin
          Expr := EffectiveValidation(Def, Msg);
          if Expr <> '' then
          begin
            M.Validation := Expr;
            M.ValidationMsg := Msg;
            Changed := True;
          end;
        end;
        if Changed then
        begin
          ADb.SaveFieldMeta(M);
          Inc(Result);
          if ALog <> nil then ALog.Add(Cols[I] + ': dopunjeno iz kataloga (' + Def.Caption + ')');
        end;
      finally
        if not Found then M.Free;
      end;
    end;
  finally
    Metas.Free;
    SqlTypes.Free;
    Cols.Free;
  end;
end;

finalization
  GCatalog.Free;

end.
