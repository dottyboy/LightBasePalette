unit ta_bizgen;
{ Business templates: one call creates a working set for a common case -
  tables with typed fields, foreign keys, defaults and validation rules; forms
  (split lists, master-detail with an editable item grid and totals); reports
  (lists, labels, printed documents); saved queries; optional sample rows and a
  switchboard. Existing tables are reused, so templates can be combined. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ZDataset, ta_meta, ta_types, ta_formdef, ta_reportdef, ta_wizardgen,
  ta_qbe, ta_iconmap, ta_doctypes, ta_switchgen, ta_app, ta_params;

{ lines "id|title|description|needs document type (0/1)" }
type
  { predlosci koji se grade u vlastitim jedinicama (ta_offers) javljaju se ovdje }
  TBizHook = function(ADb: TAppDb; ASample: Boolean; ALog: TStrings): Boolean;

var
  BizOffersHook: TBizHook = nil;

function BizTemplates: TStringList;
function DocumentTypes: TStringList;

{ ALog receives what was created / reused. False when something failed. }
function ApplyBizTemplate(ADb: TAppDb; const AId, ADocType: string; ASample: Boolean;
  ALog: TStrings): Boolean;
{ a form of buttons for every form and report in the database }
function BuildAppSwitchboard(ADb: TAppDb; ALog: TStrings): Boolean;

{ pomocne funkcije za generatore primjera (Northwind) }
function EnsureTable(ADb: TAppDb; ALog: TStrings; const AName: string; const ASpecs: array of string): Boolean;
procedure SetRule(ADb: TAppDb; const ATable, AField, ARule, AMsg: string);
{ izracunata (samo za citanje) kontrola s natpisom na formi; visina donjeg ruba forme }
function AddCalc(ADef: TaFormDef; const ALabel, AName, AExpr, AFormat: string; X, Y, W: Integer;
  ABold: Boolean): TaControlDef;
function BottomOf(ADef: TaFormDef): Integer;
{ skupina iskljucivosti za dokumentne forme (u radnom prostoru iz skupine moze biti otvorena samo jedna): '' ako forma nije dokument }
function ExclusiveGroupFor(const AFormName: string): string;
procedure SaveForm(ADb: TAppDb; ALog: TStrings; ADef: TaFormDef);
procedure SaveReport(ADb: TAppDb; ALog: TStrings; ADef: TaReportDef);
procedure SaveQuery(ADb: TAppDb; ALog: TStrings; const AName, ASql: string);
procedure Exec(ADb: TAppDb; const ASql: string);

implementation

uses
  ta_i18n;

function BizTemplates: TStringList;
begin
  Result := TStringList.Create;
  Result.Add('partneri|Partneri (kupci i dobavljači)|Adresar s OIB-om i IBAN-om (provjera ispravnosti), popis i naljepnice.|0');
  Result.Add('artikli|Artikli i usluge|Šifrarnik s cijenom, PDV stopom i jedinicom mjere, cjenik.|0');
  Result.Add('dokument|Dokument sa stavkama|Račun, ponuda, narudžbenica, otpremnica ili predračun: zaglavlje, stavke (odabir artikla upisuje cijenu), ukupno s PDV-om i ispis.|1');
  Result.Add('skladiste|Skladišni promet|Primke i izdatnice sa stavkama i izvješće o stanju zaliha.|0');
  Result.Add('blagajna|Blagajna|Uplate i isplate s blagajničkim dnevnikom i tekućim saldom.|0');
  Result.Add('zaposlenici|Zaposlenici|Popis s godinama i stažem (izračunato), plaće po odjelima.|0');
  Result.Add('putni|Putni nalozi|Putni nalog s izračunom troškova (km, dnevnice) i ispisom.|0');
  Result.Add('ponude_ugovori|Ponude i ugovori|Ponuda za posao (usluge i materijal po fazama, avans, dopušteno prekoračenje, rokovi), ugovor izveden iz ponude, dodatna ponuda i aneks ugovora s dopisima za Word.|0');
  Result.Add('dokumenti_obj|Objedinjeni dokumenti|Jedna forma za više vrsta dokumenata (račun, ponuda, otpremnica, revers...): izbornik otvara formu s vrstom, broj se uzima iz tablice dokumenti, a srodne vrste ne mogu biti otvorene istodobno.|0');
end;

function DocumentTypes: TStringList;
begin
  Result := TStringList.Create;
  Result.CommaText := 'Račun,Ponuda,Narudžbenica,Otpremnica,Predračun';
end;

{ ---------------- helpers ---------------- }

function TableExists(ADb: TAppDb; const AName: string): Boolean;
var
  L: TStringList;
begin
  L := ADb.UserTables;
  try
    Result := L.IndexOf(AName) >= 0;
  finally
    L.Free;
  end;
end;

{ Spec per field: name|Type[/decimals]|default|table.column|flags   (R = required, C = cascade delete) }
function EnsureTable(ADb: TAppDb; ALog: TStrings; const AName: string; const ASpecs: array of string): Boolean;
var
  Fl: TFieldDefs2;
  I, Dec, P: Integer;
  Pr: TStringList;
  M: TaFieldMeta;
  Typ: string;
begin
  Result := False;
  if TableExists(ADb, AName) then
  begin
    ALog.Add('već postoji: tablica ' + AName);
    Exit;
  end;
  SetLength(Fl, Length(ASpecs));
  Pr := TStringList.Create;
  try
    Pr.Delimiter := '|';
    Pr.StrictDelimiter := True;
    Pr.QuoteChar := #0;
    for I := 0 to High(ASpecs) do
    begin
      Pr.DelimitedText := ASpecs[I];
      while Pr.Count < 5 do Pr.Add('');
      Fl[I].Name := Pr[0];
      Typ := Pr[1];
      Dec := 2;
      P := Pos('/', Typ);
      if P > 0 then
      begin
        Dec := StrToIntDef(Copy(Typ, P + 1, MaxInt), 2);
        Typ := Copy(Typ, 1, P - 1);
      end;
      M := TaFieldMeta.Create;
      M.LType := LogicalFromName(Typ);
      if not (M.LType in [ltDecimal, ltCurrency]) then Dec := 0;
      M.Decimals := Dec;
      M.Format := DefaultFormat(M.LType, Dec);
      M.DefaultExpr := Pr[2];
      Fl[I].Meta := M;
      Fl[I].SqlType := PhysicalType(M.LType);
      Fl[I].PrimaryKey := M.LType = ltAutoNumber;
      Fl[I].NotNull := Pos('R', Pr[4]) > 0;
      if Pr[3] <> '' then
      begin
        Fl[I].RefTable := Copy(Pr[3], 1, Pos('.', Pr[3]) - 1);
        Fl[I].RefField := Copy(Pr[3], Pos('.', Pr[3]) + 1, MaxInt);
        if Pos('C', Pr[4]) > 0 then Fl[I].OnDelete := 'CASCADE';
      end;
    end;
    try
      ADb.CreateTable(AName, Fl);
      Result := True;
      ALog.Add('izrađena tablica ' + AName);
    finally
      for I := 0 to High(Fl) do Fl[I].Meta.Free;
    end;
  finally
    Pr.Free;
  end;
end;

procedure SetRule(ADb: TAppDb; const ATable, AField, ARule, AMsg: string);
var
  M: TaFieldMeta;
begin
  M := ADb.FindFieldMeta(ATable, AField);
  if M = nil then Exit;
  try
    M.Validation := ARule;
    M.ValidationMsg := AMsg;
    ADb.SaveFieldMeta(M);
  finally
    M.Free;
  end;
end;

function ExclusiveGroupFor(const AFormName: string): string;
var
  N: string;
begin
  N := IconFold(AFormName);
  Result := '';
  if (Pos('kupac', N) = 1) or (Pos('partner', N) > 0) or (Pos('artik', N) > 0) or (Pos('izbornik', N) > 0) then Exit;
  if (Pos('otpremn', N) > 0) or (Pos('narudzb', N) > 0) or (Pos('skladis', N) > 0) or (Pos('skl_', N) > 0) or
     (Pos('revers', N) > 0) or (Pos('primk', N) > 0) then Result := 'Skladišni dokumenti'
  else if (Pos('racun', N) > 0) or (Pos('ponud', N) > 0) or (Pos('ugovor', N) > 0) or (Pos('aneks', N) > 0) or
     (Pos('putni', N) > 0) or (Pos('blagajn', N) > 0) then Result := 'Financijski dokumenti';
end;

procedure SaveForm(ADb: TAppDb; ALog: TStrings; ADef: TaFormDef);
begin
  try
    if ADef.ExclusiveGroup = '' then ADef.ExclusiveGroup := ExclusiveGroupFor(ADef.Name);
    ADb.SaveObject('_sys_forms', ADef.Name, ADef.ToJson);
    ALog.Add('izrađena forma ' + ADef.Name);
  finally
    ADef.Free;
  end;
end;

procedure SaveReport(ADb: TAppDb; ALog: TStrings; ADef: TaReportDef);
begin
  try
    ADb.SaveObject('_sys_reports', ADef.Name, ADef.ToJson);
    ALog.Add('izrađeno izvješće ' + ADef.Name);
  finally
    ADef.Free;
  end;
end;

procedure SaveQuery(ADb: TAppDb; ALog: TStrings; const AName, ASql: string);
begin
  ADb.SaveObject('_sys_queries', AName, PortableSql(ASql));
  ALog.Add('izrađen upit ' + AName);
end;

procedure Exec(ADb: TAppDb; const ASql: string);
begin
  ADb.Conn.ExecuteDirect(ASql);
end;

function Names(const A: array of string): TStringList;
var
  I: Integer;
begin
  Result := TStringList.Create;
  for I := 0 to High(A) do Result.Add(A[I]);
end;

function SplitForm(ADb: TAppDb; const AName, ATitle, ASource: string; const AFields: array of string;
  const ACalc: string = ''): TaFormDef;
var
  Fl: TStringList;
  O: TaFormOptions;
begin
  Fl := Names(AFields);
  try
    O.Source := ASource;
    O.Name := AName;
    O.Title := ATitle;
    O.Fields := Fl;
    O.Layout := flSplit;
    O.SubTables := nil;
    Result := BuildFormEx(ADb, O);
    Result.CalcFields := ACalc;
  finally
    Fl.Free;
  end;
end;

{ A calculated TextBox (read-only) with its label. }
function AddCalc(ADef: TaFormDef; const ALabel, AName, AExpr, AFormat: string; X, Y, W: Integer;
  ABold: Boolean): TaControlDef;
var
  L: TaControlDef;
begin
  L := TaControlDef.Create;
  L.Kind := 'Label';
  L.Name := ADef.UniqueName('lbl' + AName);
  L.Caption := ALabel;
  L.Bold := ABold;
  L.Align := 'right';
  L.Left := X; L.Top := Y + 2; L.Width := 130; L.Height := 22;
  ADef.Add(L);
  Result := TaControlDef.Create;
  Result.Kind := 'TextBox';
  Result.Name := AName;
  Result.ControlSource := AExpr;
  Result.Format := AFormat;
  Result.Bold := ABold;
  Result.Align := 'right';
  Result.Left := X + 136; Result.Top := Y; Result.Width := W; Result.Height := 24;
  Result.SetX('locked', '1');
  ADef.Add(Result);
end;

function AddButton(ADef: TaFormDef; const ACaption, AAction: string; X, Y, W: Integer): TaControlDef;
begin
  Result := TaControlDef.Create;
  Result.Kind := 'Button';
  Result.Name := ADef.UniqueName('btn');
  Result.Caption := ACaption;
  Result.OnClick := AAction;
  AutoButtonIcon(Result);
  Result.Left := X; Result.Top := Y; Result.Width := W; Result.Height := 30;
  ADef.Add(Result);
end;

{ drops footer sums of columns that are meaningless to add up (price, discount ...) }
procedure DropSums(ARep: TaReportDef; const AFields: array of string);
var
  I, K: Integer;
begin
  for I := ARep.Count - 1 downto 0 do
    if SectionIndex(ARep[I].Section) in [SecGroupFooter, SecReportFooter] then
      for K := 0 to High(AFields) do
        if Pos('[' + LowerCase(AFields[K]) + ']', LowerCase(ARep[I].ControlSource)) > 0 then
        begin
          ARep.Delete(ARep[I]);
          Break;
        end;
end;

function BottomOf(ADef: TaFormDef): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to ADef.Count - 1 do
    if ADef[I].Top + ADef[I].Height > Result then Result := ADef[I].Top + ADef[I].Height;
end;

{ ---------------- partners ---------------- }

procedure DoPartneri(ADb: TAppDb; ALog: TStrings; ASample: Boolean);
var
  Fl: TStringList;
  Rd: TaReportDef;
  Ro: TaReportOptions;
  Lines: TStringList;
  New: Boolean;
begin
  New := EnsureTable(ADb, ALog, 'partneri', [
    'id|AutoNumber', 'naziv|Text|||R', 'tip|Text|''Kupac''', 'oib|Text', 'adresa|Text', 'postanski|Text',
    'grad|Text', 'drzava|Text|''Hrvatska''', 'telefon|Text', 'email|Text', 'iban|Text', 'napomena|Memo',
    'aktivan|YesNo|1']);
  if New then
  begin
    SetRule(ADb, 'partneri', 'oib', 'ValidOIB([oib])', 'Neispravan OIB.');
    SetRule(ADb, 'partneri', 'iban', 'ValidIBAN([iban])', 'Neispravan IBAN.');
    if ASample then
    begin
      Exec(ADb, 'INSERT INTO partneri (naziv, tip, oib, adresa, postanski, grad, drzava, telefon, email, aktivan) VALUES ' +
        '(''Ivo Horvat d.o.o.'', ''Kupac'', ''69435151530'', ''Ilica 10'', ''10000'', ''Zagreb'', ''Hrvatska'', ''01 234 5678'', ''ivo@primjer.hr'', 1), ' +
        '(''Ana Kovač obrt'', ''Kupac'', NULL, ''Riva 5'', ''21000'', ''Split'', ''Hrvatska'', ''021 345 678'', ''ana@primjer.hr'', 1), ' +
        '(''Dobavljač Plus d.d.'', ''Dobavljač'', NULL, ''Savska 120'', ''10000'', ''Zagreb'', ''Hrvatska'', ''01 111 2222'', ''info@dobavljac.hr'', 1)');
      ALog.Add('upisani primjeri partnera');
    end;
  end;
  SaveForm(ADb, ALog, SplitForm(ADb, 'Partneri', 'Partneri', 'partneri',
    ['naziv', 'tip', 'oib', 'adresa', 'postanski', 'grad', 'drzava', 'telefon', 'email', 'iban', 'napomena', 'aktivan']));
  Fl := Names(['naziv', 'oib', 'grad', 'telefon', 'email']);
  try
    Ro.Source := 'partneri'; Ro.Name := 'Popis partnera'; Ro.Title := 'Popis partnera';
    Ro.GroupField := ''; Ro.SortField := 'naziv'; Ro.Fields := Fl; Ro.Kind := rkTabular;
    Ro.Descending := False; Ro.Sums := False; Ro.PageBreakPerRecord := False; Ro.LabelColumns := 3; Ro.LabelLines := nil;
    Rd := BuildReportEx(ADb, Ro);
    SaveReport(ADb, ALog, Rd);
  finally
    Fl.Free;
  end;
  Fl := Names(['naziv']);
  Lines := Names(['[naziv]', '[adresa]', '[postanski] & " " & [grad]']);
  try
    Ro.Name := 'Naljepnice partnera'; Ro.Title := ''; Ro.Fields := Fl; Ro.Kind := rkLabels;
    Ro.LabelColumns := 3; Ro.LabelLines := Lines;
    Rd := BuildReportEx(ADb, Ro);
    SaveReport(ADb, ALog, Rd);
  finally
    Lines.Free;
    Fl.Free;
  end;
end;

{ ---------------- articles ---------------- }

procedure DoArtikli(ADb: TAppDb; ALog: TStrings; ASample: Boolean);
var
  Fl, Lines: TStringList;
  Ro: TaReportOptions;
  New: Boolean;
begin
  New := EnsureTable(ADb, ALog, 'artikli', [
    'id|AutoNumber', 'sifra|Text|||R', 'naziv|Text|||R', 'jmj|Text|''kom''', 'cijena|Currency|0',
    'pdv_stopa|Decimal/0|25', 'min_zaliha|Decimal/0|0', 'aktivan|YesNo|1']);
  if New then
  begin
    SetRule(ADb, 'artikli', 'cijena', '[cijena] >= 0', 'Cijena ne može biti negativna.');
    if ASample then
    begin
      Exec(ADb, 'INSERT INTO artikli (sifra, naziv, jmj, cijena, pdv_stopa, min_zaliha, aktivan) VALUES ' +
        '(''A001'', ''Vijak M8'', ''kom'', 0.35, 25, 100, 1), (''A002'', ''Matica M8'', ''kom'', 0.20, 25, 100, 1), ' +
        '(''U001'', ''Usluga montaže'', ''sat'', 30, 25, 0, 1)');
      ALog.Add('upisani primjeri artikala');
    end;
  end;
  SaveForm(ADb, ALog, SplitForm(ADb, 'Artikli', 'Artikli i usluge', 'artikli',
    ['sifra', 'naziv', 'jmj', 'cijena', 'pdv_stopa', 'min_zaliha', 'aktivan'],
    'SCijenom=[cijena] * (1 + [pdv_stopa] / 100)'));
  Fl := Names(['sifra', 'naziv', 'jmj', 'cijena', 'pdv_stopa']);
  try
    Ro.Source := 'artikli'; Ro.Name := 'Cjenik'; Ro.Title := 'Cjenik';
    Ro.GroupField := ''; Ro.SortField := 'naziv'; Ro.Fields := Fl; Ro.Kind := rkTabular;
    Ro.Descending := False; Ro.Sums := False; Ro.PageBreakPerRecord := False; Ro.LabelColumns := 3; Ro.LabelLines := nil;
    SaveReport(ADb, ALog, BuildReportEx(ADb, Ro));
    Lines := Names(['[naziv]', 'barcode:code128:[sifra]', 'Format([cijena], "0.00") & " EUR"']);
    try
      Ro.Name := 'Naljepnice artikala'; Ro.Title := ''; Ro.Kind := rkLabels;
      Ro.LabelColumns := 3; Ro.LabelLines := Lines;
      SaveReport(ADb, ALog, BuildReportEx(ADb, Ro));
    finally
      Lines.Free;
    end;
  finally
    Fl.Free;
  end;
end;

{ ---------------- documents with items ---------------- }

procedure DocInfo(const AType: string; out ATable, ASingular, APlural, AStatus, AStatusCaption: string);
begin
  if AType = 'Ponuda' then begin ATable := 'ponude'; ASingular := 'Ponuda'; APlural := 'Ponude'; AStatus := 'prihvacena'; AStatusCaption := 'Prihvaćena'; end
  else if AType = 'Narudžbenica' then begin ATable := 'narudzbenice'; ASingular := 'Narudžbenica'; APlural := 'Narudžbenice'; AStatus := 'isporucena'; AStatusCaption := 'Isporučena'; end
  else if AType = 'Otpremnica' then begin ATable := 'otpremnice'; ASingular := 'Otpremnica'; APlural := 'Otpremnice'; AStatus := 'potpisana'; AStatusCaption := 'Potpisana'; end
  else if AType = 'Predračun' then begin ATable := 'predracuni'; ASingular := 'Predračun'; APlural := 'Predračuni'; AStatus := 'placeno'; AStatusCaption := 'Plaćeno'; end
  else begin ATable := 'racuni'; ASingular := 'Račun'; APlural := 'Računi'; AStatus := 'placeno'; AStatusCaption := 'Plaćeno'; end;
end;

function NumberDefault(const ATable: string): string;
begin
  Result := 'Format(Year(Today()), "0000") & "-" & Format(Nz(DMax("id", "' + ATable + '", ""), 0) + 1, "000")';
end;

procedure DoDokument(ADb: TAppDb; ALog: TStrings; ASample: Boolean; const ADocType: string);
var
  Tbl, Sing, Plural, Status, StatusCap, Items, Q, ReportName, FormName: string;
  New: Boolean;
  MM: TaMDMulti;
  MR: TaMDMultiResult;
  Mf: TaFormDef;
  Master: TStringList;
  I, Y, W: Integer;
  Sub, C: TaControlDef;
  Fl: TStringList;
  Ro: TaReportOptions;
  Rd: TaReportDef;
  Amount, Pdv: string;
begin
  DoPartneri(ADb, ALog, ASample);
  DoArtikli(ADb, ALog, ASample);
  DocInfo(ADocType, Tbl, Sing, Plural, Status, StatusCap);
  Items := Tbl + '_stavke';
  FormName := Plural;
  ReportName := Sing + ' - ispis';
  New := EnsureTable(ADb, ALog, Tbl, [
    'id|AutoNumber', 'broj|Text|' + NumberDefault(Tbl) + '||R', 'datum|Date|Today()||R',
    'dospijece|Date|DateAdd("d", 15, Today())', 'partner_id|Integer||partneri.id|R', Status + '|YesNo|0', 'napomena|Memo']);
  EnsureTable(ADb, ALog, Items, [
    'id|AutoNumber', 'dokument_id|Integer||' + Tbl + '.id|RC', 'artikl_id|Integer||artikli.id|R', 'opis|Text',
    'kolicina|Decimal|1|', 'jmj|Text', 'cijena|Decimal/4|0', 'rabat|Decimal/0|0', 'pdv_stopa|Decimal/0|25', 'iznos|Currency|0']);
  SetRule(ADb, Items, 'kolicina', '[kolicina] > 0', 'Količina mora biti veća od nule.');
  SetRule(ADb, Items, 'rabat', '[rabat] >= 0 And [rabat] <= 100', 'Rabat je između 0 i 100 %.');
  if New and ASample then
  begin
    Exec(ADb, 'INSERT INTO ' + Tbl + ' (broj, datum, dospijece, partner_id, ' + Status + ', napomena) VALUES ' +
      '(''' + FormatDateTime('yyyy', Date) + '-001'', date(''now''), date(''now'', ''+15 days''), 1, 0, ''Primjer'')');
    Exec(ADb, 'INSERT INTO ' + Items + ' (dokument_id, artikl_id, opis, kolicina, jmj, cijena, rabat, pdv_stopa, iznos) VALUES ' +
      '(1, 1, ''Vijak M8'', 200, ''kom'', 0.35, 0, 25, 70), (1, 3, ''Usluga montaže'', 2, ''sat'', 30, 10, 25, 54)');
    ALog.Add('upisan primjer dokumenta');
  end;

  { the form: header, editable item grid, totals, print }
  Master := Names(['broj', 'datum', 'dospijece', 'partner_id', Status, 'napomena']);
  try
    MM.Master := Tbl; MM.Name := FormName; MM.Title := Sing; MM.MasterFields := Master;
    MM.DetailAsForm := False; MM.UseTabs := False;
    SetLength(MM.Details, 1);
    MM.Details[0].Table := Items; MM.Details[0].Fields := nil; MM.Details[0].SumField := '';
    MM.Details[0].ShowCount := False; MM.Details[0].FkCol := 'dokument_id'; MM.Details[0].ParentCol := 'id';
    MR := BuildMasterDetailMulti(ADb, MM);
    if MR.Error <> '' then raise Exception.Create(MR.Error);
    Mf := MR.MasterForm;
  finally
    Master.Free;
  end;
  Sub := nil;
  for I := 0 to Mf.Count - 1 do
    if Mf[I].Kind = 'Subform' then Sub := Mf[I];
  if Sub <> nil then
  begin
    { iznos stavke je mjerodavan: pohranjen, zaokruzen na 2 decimale; promjena iznosa preracunava cijenu }
    Sub.SetX('calcrules', 'kolicina,cijena,rabat -> iznos = Zaokruzi([kolicina] * [cijena] * (1 - [rabat] / 100), 2) ;; ' +
      'iznos -> cijena = Zaokruzi([iznos] / ([kolicina] * (1 - [rabat] / 100)), 4)');
    Sub.SetX('autofill', 'artikl_id>artikli.id:opis=naziv,cijena=cijena,jmj=jmj,pdv_stopa=pdv_stopa');
    Sub.Width := Mf.Width - 32;
    Sub.Height := 220;
  end;
  Y := BottomOf(Mf) + 10;
  W := Mf.Width;
  AddCalc(Mf, 'Osnovica:', 'txtOsnovica', '=Nz(DSum("iznos", "' + Items + '", "dokument_id = " & [id]), 0)',
    '#,##0.00 "€"', W - 16 - 130 - 6 - 130, Y, 130, False);
  AddCalc(Mf, 'PDV:', 'txtPdv', '=Nz(PdvPoStopama("' + Items + '", "iznos", "pdv_stopa", "dokument_id = " & [id]), 0)',
    '#,##0.00 "€"', W - 16 - 130 - 6 - 130, Y + 28, 130, False);
  AddCalc(Mf, 'UKUPNO:', 'txtUkupno', '=[txtOsnovica] + [txtPdv]', '#,##0.00 "€"', W - 16 - 130 - 6 - 130, Y + 56, 130, True);
  AddButton(Mf, 'Ispis', 'openreport:' + ReportName + '@"dok_id = " & [id]', 16, Y + 26, 110);
  AddButton(Mf, 'Pregled po razdoblju', 'openreport:' + Plural + ' po razdoblju', 16, Y + 62, 196);
  Mf.Height := Y + 100;
  SaveForm(ADb, ALog, Mf);
  Mf := nil;
  for I := 0 to High(MR.Items) do MR.Items[I].Form.Free;

  { the printed document }
  Q := Tbl + ' - ispis podaci';
  SaveQuery(ADb, ALog, Q,
    'SELECT d.id AS dok_id, d.broj, d.datum, d.dospijece, p.naziv AS partner, p.adresa AS adresa,' + LineEnding +
    '       trim(COALESCE(p.postanski, '''') || '' '' || COALESCE(p.grad, '''')) AS mjesto, p.oib AS oib,' + LineEnding +
    '       s.opis, s.kolicina, s.jmj, s.cijena, s.rabat, s.pdv_stopa,' + LineEnding +
    '       s.iznos AS osnovica' + LineEnding +
    'FROM ' + ADb.QuoteId(Tbl) + ' d' + LineEnding +
    'JOIN partneri p ON p.id = d.partner_id' + LineEnding +
    'JOIN ' + ADb.QuoteId(Items) + ' s ON s.dokument_id = d.id' + LineEnding +
    'ORDER BY d.id, s.id');
  Fl := Names(['opis', 'kolicina', 'jmj', 'cijena', 'rabat', 'osnovica']);
  try
    Ro.Source := Q; Ro.Name := ReportName; Ro.Title := Sing;
    Ro.GroupField := 'dok_id'; Ro.SortField := ''; Ro.Fields := Fl; Ro.Kind := rkTabular;
    Ro.Descending := False; Ro.Sums := True; Ro.PageBreakPerRecord := False; Ro.LabelColumns := 3; Ro.LabelLines := nil;
    Rd := BuildReportEx(ADb, Ro);
  finally
    Fl.Free;
  end;
  { the group header carries the number, date and customer }
  Rd.Heights[SecGroupHeader] := 56;
  for I := 0 to Rd.Count - 1 do
    if (SectionIndex(Rd[I].Section) = SecGroupHeader) and (Rd[I].ControlSource = 'dok_id') then
    begin
      Rd[I].ControlSource := '="Broj: " & [broj] & "      Datum: " & Format([datum], "dd.mm.yyyy") & "      Dospijeće: " & Format([dospijece], "dd.mm.yyyy")';
      Rd[I].Height := 22;
      C := Rd[I];
    end;
  C := TaControlDef.Create;
  C.Kind := 'TextBox';
  C.Name := Rd.UniqueName('txtKupac');
  C.Section := 'GroupHeader';
  C.ControlSource := '="Kupac: " & [partner] & ", " & [adresa] & ", " & [mjesto] & "   OIB: " & Nz([oib], "-")';
  C.Left := 0; C.Top := 30; C.Width := 714; C.Height := 20;
  Rd.Add(C);
  DropSums(Rd, ['kolicina', 'cijena', 'rabat']);
  { PDV po stopama (svaka stopa zaokruzena posebno) i ukupno: ukupno = zbroj stavki + PDV }
  Pdv := 'PdvPoStopama("' + Items + '", "iznos", "pdv_stopa", "dokument_id = " & [dok_id])';
  C := TaControlDef.Create;
  C.Kind := 'TextBox';
  C.Name := Rd.UniqueName('txtPdvZbroj');
  C.Section := 'GroupFooter';
  C.ControlSource := '="PDV: " & Format(' + Pdv + ', "#,##0.00")';
  C.Left := 0; C.Top := Rd.Heights[SecGroupFooter] + 4; C.Width := 714; C.Height := 20;
  Rd.Add(C);
  C := TaControlDef.Create;
  C.Kind := 'TextBox';
  C.Name := Rd.UniqueName('txtUkupnoZbroj');
  C.Section := 'GroupFooter';
  C.ControlSource := '="UKUPNO: " & Format(Sum([osnovica]) + ' + Pdv + ', "#,##0.00")';
  C.Left := 0; C.Top := Rd.Heights[SecGroupFooter] + 26; C.Width := 714; C.Height := 20;
  Rd.Add(C);
  Rd.Heights[SecGroupFooter] := Rd.Heights[SecGroupFooter] + 52;
  { ukupan iznos slovima ispod zbrojeva grupe }
  C := TaControlDef.Create;
  C.Kind := 'TextBox';
  C.Name := Rd.UniqueName('txtSlovima');
  C.Section := 'GroupFooter';
  C.ControlSource := '="Slovima: " & IznosSlovima(Sum([osnovica]) + ' + Pdv + ')';
  C.Left := 0; C.Top := Rd.Heights[SecGroupFooter] + 4; C.Width := 714; C.Height := 20;
  Rd.Add(C);
  Rd.Heights[SecGroupFooter] := Rd.Heights[SecGroupFooter] + 28;
  { podaci primatelja i HUB3 barkod za placanje (iz Aplikacija > Podaci o tvrtki) }
  C := TaControlDef.Create;
  C.Kind := 'TextBox';
  C.Name := Rd.UniqueName('txtPrimatelj');
  C.Section := 'GroupFooter';
  C.ControlSource := '=Iif(Postavka("firma.iban") = "", "", "Primatelj: " & Postavka("firma.naziv") & ", " & Postavka("firma.adresa") & ", " & Postavka("firma.mjesto") & "   IBAN: " & Postavka("firma.iban") & "   Poziv na broj: " & [broj])';
  C.Left := 0; C.Top := Rd.Heights[SecGroupFooter] + 4; C.Width := 714; C.Height := 20;
  Rd.Add(C);
  C := TaControlDef.Create;
  C.Kind := 'Barcode';
  C.Name := Rd.UniqueName('bcUplata');
  C.Section := 'GroupFooter';
  C.ControlSource := '=Iif(Postavka("firma.iban") = "", "", Hub3Uplata(Sum([osnovica]) + ' + Pdv + ', [partner], [adresa], [mjesto], Postavka("firma.naziv"), Postavka("firma.adresa"), Postavka("firma.mjesto"), Postavka("firma.iban"), "HR99", [broj], "", "Racun " & [broj]))';
  C.SetX('barType', 'hub3');
  C.Left := 0; C.Top := Rd.Heights[SecGroupFooter] + 30; C.Width := 330; C.Height := 100;
  Rd.Add(C);
  Rd.Heights[SecGroupFooter] := Rd.Heights[SecGroupFooter] + 140;
  SaveReport(ADb, ALog, Rd);

  { pregled po razdoblju: od-do se pita pri otvaranju, prazno = bez ogranicenja; PDV po stopama kao na formi }
  Q := Plural + ' po razdoblju';
  SaveQuery(ADb, ALog, Q,
    'SELECT d.id, d.broj, d.datum, d.dospijece, p.naziv AS partner,' + LineEnding +
    '       ROUND(COALESCE(t.osn, 0), 2) AS osnovica, ROUND(COALESCE(t.pdv, 0), 2) AS pdv,' + LineEnding +
    '       ROUND(COALESCE(t.osn, 0) + COALESCE(t.pdv, 0), 2) AS ukupno,' + LineEnding +
    '       CASE WHEN d.' + Status + ' = 1 THEN ''' + StatusCap + ''' ELSE ''Nije ' + LowerCase(StatusCap) + ''' END AS status' + LineEnding +
    'FROM ' + Tbl + ' d' + LineEnding +
    'JOIN partneri p ON p.id = d.partner_id' + LineEnding +
    'LEFT JOIN (SELECT dokument_id, SUM(osn) AS osn, SUM(ROUND(osn * stopa / 100.0, 2)) AS pdv' + LineEnding +
    '           FROM (SELECT dokument_id, pdv_stopa AS stopa, SUM(iznos) AS osn FROM ' + Items + ' GROUP BY dokument_id, pdv_stopa)' + LineEnding +
    '           GROUP BY dokument_id) t ON t.dokument_id = d.id' + LineEnding +
    'WHERE (d.datum >= [?Od] OR [?Od] IS NULL) AND (d.datum <= [?Do] OR [?Do] IS NULL)' + LineEnding +
    'ORDER BY d.datum, d.broj');
  Fl := Names(['broj', 'datum', 'partner', 'osnovica', 'pdv', 'ukupno', 'status']);
  try
    Ro.Source := Q; Ro.Name := Q; Ro.Title := Plural + ' po razdoblju';
    Ro.GroupField := ''; Ro.SortField := ''; Ro.Fields := Fl; Ro.Kind := rkTabular;
    Ro.Descending := False; Ro.Sums := True; Ro.PageBreakPerRecord := False; Ro.LabelColumns := 3; Ro.LabelLines := nil;
    SaveReport(ADb, ALog, BuildReportEx(ADb, Ro));
  finally
    Fl.Free;
  end;
end;

{ ---------------- objedinjeni dokumenti: jedna forma za vise vrsta ---------------- }

procedure DoObjedinjeniDokumenti(ADb: TAppDb; ALog: TStrings; ASample: Boolean);
const
  Tbl = 'dokument';
  Items = 'dokument_stavke';
var
  MM: TaMDMulti;
  MR: TaMDMultiResult;
  Mf: TaFormDef;
  Master, Fl: TStringList;
  I, Y, W: Integer;
  Sub, C: TaControlDef;
  Ro: TaReportOptions;
  Rd: TaReportDef;
  New: Boolean;
  Pdv: string;

  procedure SeedType(const ACode, AName, ARelated: string);
  var
    T: TaDocType;
  begin
    if DocTypeExists(ADb, ACode) then Exit;
    T.Code := ACode; T.Name := AName; T.Prefix := ACode; T.Format := DefaultDocFormat;
    T.Related := ARelated; T.Last := 0; T.Year := 0;
    DocTypeSave(ADb, T);
  end;
begin
  DoPartneri(ADb, ALog, ASample);
  DoArtikli(ADb, ALog, ASample);
  New := EnsureTable(ADb, ALog, Tbl, [
    'id|AutoNumber', 'vrsta|Text', 'broj|Text', 'datum|Date|Today()||R',
    'dospijece|Date|DateAdd("d", 15, Today())', 'partner_id|Integer||partneri.id', 'napomena|Memo']);
  EnsureTable(ADb, ALog, Items, [
    'id|AutoNumber', 'dokument_id|Integer||' + Tbl + '.id|RC', 'artikl_id|Integer||artikli.id|R', 'opis|Text',
    'kolicina|Decimal|1|', 'jmj|Text', 'cijena|Decimal/4|0', 'rabat|Decimal/0|0', 'pdv_stopa|Decimal/0|25', 'iznos|Currency|0']);
  SetRule(ADb, Items, 'kolicina', '[kolicina] > 0', 'Količina mora biti veća od nule.');
  { vrste dokumenata: otpremnica i revers se medjusobno iskljucuju }
  EnsureDocTypes(ADb);
  SeedType('rac', 'Račun', '');
  SeedType('pon', 'Ponuda', '');
  SeedType('pred', 'Predračun', '');
  SeedType('nar', 'Narudžbenica', '');
  SeedType('otp', 'Otpremnica', 'rv');
  SeedType('rv', 'Revers', 'otp');
  ALog.Add('vrste dokumenata upisane u tablicu ' + DocTypesTable + ' (rac, pon, pred, nar, otp, rv)');

  Master := Names(['broj', 'datum', 'dospijece', 'partner_id', 'napomena']);
  try
    MM.Master := Tbl; MM.Name := 'Dokument'; MM.Title := 'Dokument'; MM.MasterFields := Master;
    MM.DetailAsForm := False; MM.UseTabs := False;
    SetLength(MM.Details, 1);
    MM.Details[0].Table := Items; MM.Details[0].Fields := nil; MM.Details[0].SumField := '';
    MM.Details[0].ShowCount := False; MM.Details[0].FkCol := 'dokument_id'; MM.Details[0].ParentCol := 'id';
    MR := BuildMasterDetailMulti(ADb, MM);
    if MR.Error <> '' then raise Exception.Create(MR.Error);
    Mf := MR.MasterForm;
  finally
    Master.Free;
  end;
  Sub := nil;
  for I := 0 to Mf.Count - 1 do
    if Mf[I].Kind = 'Subform' then Sub := Mf[I];
  if Sub <> nil then
  begin
    Sub.SetX('calcrules', 'kolicina,cijena,rabat -> iznos = Zaokruzi([kolicina] * [cijena] * (1 - [rabat] / 100), 2) ;; ' +
      'iznos -> cijena = Zaokruzi([iznos] / ([kolicina] * (1 - [rabat] / 100)), 4)');
    Sub.SetX('autofill', 'artikl_id>artikli.id:opis=naziv,cijena=cijena,jmj=jmj,pdv_stopa=pdv_stopa');
    Sub.Width := Mf.Width - 32;
    Sub.Height := 220;
  end;
  Y := BottomOf(Mf) + 10;
  W := Mf.Width;
  AddCalc(Mf, 'Osnovica:', 'txtOsnovica', '=Nz(DSum("iznos", "' + Items + '", "dokument_id = " & [id]), 0)',
    '#,##0.00 "€"', W - 16 - 130 - 6 - 130, Y, 130, False);
  AddCalc(Mf, 'PDV:', 'txtPdv', '=Nz(PdvPoStopama("' + Items + '", "iznos", "pdv_stopa", "dokument_id = " & [id]), 0)',
    '#,##0.00 "€"', W - 16 - 130 - 6 - 130, Y + 28, 130, False);
  AddCalc(Mf, 'UKUPNO:', 'txtUkupno', '=[txtOsnovica] + [txtPdv]', '#,##0.00 "€"', W - 16 - 130 - 6 - 130, Y + 56, 130, True);
  AddButton(Mf, 'Ispis', 'openreport:Dokument - ispis@"dok_id = " & [id]', 16, Y + 26, 110);
  AddButton(Mf, 'Pregled po razdoblju', 'openreport:Dokumenti po razdoblju', 16, Y + 62, 196);
  Mf.Height := Y + 100;
  { jedna forma za sve vrste: vrsta se bira parametrom iz izbornika (openform:Dokument#vrsta=otp), broj se racuna iz tablice dokumenti }
  Mf.DocTypeField := 'vrsta';
  Mf.DocNumberField := 'broj';
  SaveForm(ADb, ALog, Mf);
  Mf := nil;
  for I := 0 to High(MR.Items) do MR.Items[I].Form.Free;

  SaveQuery(ADb, ALog, 'Dokument - ispis podaci',
    'SELECT d.id AS dok_id, d.vrsta, COALESCE(v.naziv, d.vrsta) AS vrsta_naziv, d.broj, d.datum, d.dospijece, p.naziv AS partner,' + LineEnding +
    '       p.adresa AS adresa, trim(COALESCE(p.postanski, '''') || '' '' || COALESCE(p.grad, '''')) AS mjesto, p.oib AS oib,' + LineEnding +
    '       s.opis, s.kolicina, s.jmj, s.cijena, s.rabat, s.pdv_stopa, s.iznos AS osnovica' + LineEnding +
    'FROM ' + ADb.QuoteId(Tbl) + ' d' + LineEnding +
    'LEFT JOIN ' + DocTypesTable + ' v ON v.vrsta = d.vrsta' + LineEnding +
    'JOIN partneri p ON p.id = d.partner_id' + LineEnding +
    'JOIN ' + ADb.QuoteId(Items) + ' s ON s.dokument_id = d.id' + LineEnding +
    'ORDER BY d.id, s.id');
  Fl := Names(['opis', 'kolicina', 'jmj', 'cijena', 'rabat', 'osnovica']);
  try
    Ro.Source := 'Dokument - ispis podaci'; Ro.Name := 'Dokument - ispis'; Ro.Title := 'Dokument';
    Ro.GroupField := 'dok_id'; Ro.SortField := ''; Ro.Fields := Fl; Ro.Kind := rkTabular;
    Ro.Descending := False; Ro.Sums := True; Ro.PageBreakPerRecord := False; Ro.LabelColumns := 3; Ro.LabelLines := nil;
    Rd := BuildReportEx(ADb, Ro);
  finally
    Fl.Free;
  end;
  Rd.Heights[SecGroupHeader] := 56;
  for I := 0 to Rd.Count - 1 do
    if (SectionIndex(Rd[I].Section) = SecGroupHeader) and (Rd[I].ControlSource = 'dok_id') then
    begin
      Rd[I].ControlSource := '=[vrsta_naziv] & " " & [broj] & "      Datum: " & Format([datum], "dd.mm.yyyy")';
      Rd[I].Height := 22;
    end;
  C := TaControlDef.Create;
  C.Kind := 'TextBox';
  C.Name := Rd.UniqueName('txtKupac');
  C.Section := 'GroupHeader';
  C.ControlSource := '="Kupac: " & [partner] & ", " & [adresa] & ", " & [mjesto] & "   OIB: " & Nz([oib], "-")';
  C.Left := 0; C.Top := 30; C.Width := 714; C.Height := 20;
  Rd.Add(C);
  DropSums(Rd, ['kolicina', 'cijena', 'rabat']);
  Pdv := 'PdvPoStopama("' + Items + '", "iznos", "pdv_stopa", "dokument_id = " & [dok_id])';
  C := TaControlDef.Create;
  C.Kind := 'TextBox';
  C.Name := Rd.UniqueName('txtUkupnoZbroj');
  C.Section := 'GroupFooter';
  C.ControlSource := '="UKUPNO: " & Format(Sum([osnovica]) + ' + Pdv + ', "#,##0.00")';
  C.Left := 0; C.Top := Rd.Heights[SecGroupFooter] + 4; C.Width := 714; C.Height := 20;
  Rd.Add(C);
  Rd.Heights[SecGroupFooter] := Rd.Heights[SecGroupFooter] + 30;
  SaveReport(ADb, ALog, Rd);
  { pregled po razdoblju i vrsti: od-do i vrsta se pitaju pri otvaranju, prazno = sve }
  SaveQuery(ADb, ALog, 'Dokumenti po razdoblju',
    'SELECT d.id, COALESCE(v.naziv, d.vrsta) AS vrsta, d.broj, d.datum, p.naziv AS partner,' + LineEnding +
    '       ROUND(COALESCE(t.osn, 0), 2) AS osnovica, ROUND(COALESCE(t.pdv, 0), 2) AS pdv,' + LineEnding +
    '       ROUND(COALESCE(t.osn, 0) + COALESCE(t.pdv, 0), 2) AS ukupno' + LineEnding +
    'FROM dokument d' + LineEnding +
    'LEFT JOIN ' + DocTypesTable + ' v ON v.vrsta = d.vrsta' + LineEnding +
    'LEFT JOIN partneri p ON p.id = d.partner_id' + LineEnding +
    'LEFT JOIN (SELECT dokument_id, SUM(osn) AS osn, SUM(ROUND(osn * stopa / 100.0, 2)) AS pdv' + LineEnding +
    '           FROM (SELECT dokument_id, pdv_stopa AS stopa, SUM(iznos) AS osn FROM dokument_stavke GROUP BY dokument_id, pdv_stopa)' + LineEnding +
    '           GROUP BY dokument_id) t ON t.dokument_id = d.id' + LineEnding +
    'WHERE (d.datum >= [?Od] OR [?Od] IS NULL) AND (d.datum <= [?Do] OR [?Do] IS NULL) AND (d.vrsta = [?Vrsta] OR [?Vrsta] IS NULL)' + LineEnding +
    'ORDER BY d.datum, d.broj');
  Fl := Names(['vrsta', 'broj', 'datum', 'partner', 'osnovica', 'pdv', 'ukupno']);
  try
    Ro.Source := 'Dokumenti po razdoblju'; Ro.Name := 'Dokumenti po razdoblju'; Ro.Title := 'Dokumenti po razdoblju';
    Ro.GroupField := ''; Ro.SortField := ''; Ro.Fields := Fl; Ro.Kind := rkTabular;
    Ro.Descending := False; Ro.Sums := True; Ro.PageBreakPerRecord := False; Ro.LabelColumns := 3; Ro.LabelLines := nil;
    SaveReport(ADb, ALog, BuildReportEx(ADb, Ro));
  finally
    Fl.Free;
  end;
  if New and ASample then ALog.Add('(bez primjera: novi dokumenti dobivaju brojeve iz tablice ' + DocTypesTable + ')');
end;

{ ---------------- warehouse ---------------- }

procedure DoSkladiste(ADb: TAppDb; ALog: TStrings; ASample: Boolean);
var
  MM: TaMDMulti;
  MR: TaMDMultiResult;
  Mf: TaFormDef;
  Master, Fl: TStringList;
  I: Integer;
  Sub: TaControlDef;
  Ro: TaReportOptions;
  New: Boolean;
begin
  DoPartneri(ADb, ALog, ASample);
  DoArtikli(ADb, ALog, ASample);
  New := EnsureTable(ADb, ALog, 'skl_dokumenti', [
    'id|AutoNumber', 'tip|Text|''Primka''|', 'broj|Text|' + NumberDefault('skl_dokumenti') + '||R', 'datum|Date|Today()||R',
    'partner_id|Integer||partneri.id', 'napomena|Memo']);
  EnsureTable(ADb, ALog, 'skl_stavke', [
    'id|AutoNumber', 'dokument_id|Integer||skl_dokumenti.id|RC', 'artikl_id|Integer||artikli.id|R',
    'kolicina|Decimal|1|', 'cijena|Currency|0']);
  SetRule(ADb, 'skl_stavke', 'kolicina', '[kolicina] > 0', 'Količina mora biti veća od nule.');
  SetRule(ADb, 'skl_dokumenti', 'tip', '[tip] In ("Primka", "Izdatnica")', 'Tip je Primka ili Izdatnica.');
  if New and ASample then
  begin
    Exec(ADb, 'INSERT INTO skl_dokumenti (tip, broj, datum, partner_id) VALUES (''Primka'', ''P-001'', date(''now'', ''-10 days''), 3), (''Izdatnica'', ''I-001'', date(''now''), 1)');
    Exec(ADb, 'INSERT INTO skl_stavke (dokument_id, artikl_id, kolicina, cijena) VALUES (1, 1, 500, 0.30), (1, 2, 500, 0.15), (2, 1, 200, 0.35)');
    ALog.Add('upisani primjeri skladišnih dokumenata');
  end;
  Master := Names(['tip', 'broj', 'datum', 'partner_id', 'napomena']);
  try
    MM.Master := 'skl_dokumenti'; MM.Name := 'Skladišni dokumenti'; MM.Title := 'Primka / izdatnica'; MM.MasterFields := Master;
    MM.DetailAsForm := False; MM.UseTabs := False;
    SetLength(MM.Details, 1);
    MM.Details[0].Table := 'skl_stavke'; MM.Details[0].Fields := nil; MM.Details[0].SumField := 'cijena';
    MM.Details[0].ShowCount := True; MM.Details[0].FkCol := 'dokument_id'; MM.Details[0].ParentCol := 'id';
    MR := BuildMasterDetailMulti(ADb, MM);
    if MR.Error <> '' then raise Exception.Create(MR.Error);
    Mf := MR.MasterForm;
  finally
    Master.Free;
  end;
  for I := 0 to Mf.Count - 1 do
  begin
    if (Mf[I].Kind = 'TextBox') and (Mf[I].ControlSource = 'tip') then
    begin
      Mf[I].Kind := 'ComboBox';
      Mf[I].RowSource := 'Primka;Izdatnica';
    end;
    if Mf[I].Kind = 'Subform' then
    begin
      Sub := Mf[I];
      Sub.SetX('autofill', 'artikl_id>artikli.id:cijena=cijena');
      Sub.SetX('calc', 'Iznos=[kolicina] * [cijena]');
    end;
  end;
  SaveForm(ADb, ALog, Mf);
  for I := 0 to High(MR.Items) do MR.Items[I].Form.Free;
  SaveQuery(ADb, ALog, 'Stanje zaliha',
    'SELECT a.sifra, a.naziv, a.jmj,' + LineEnding +
    '       COALESCE(SUM(CASE WHEN d.tip = ''Primka'' THEN s.kolicina ELSE -s.kolicina END), 0) AS stanje,' + LineEnding +
    '       a.min_zaliha' + LineEnding +
    'FROM artikli a' + LineEnding +
    'LEFT JOIN skl_stavke s ON s.artikl_id = a.id' + LineEnding +
    'LEFT JOIN skl_dokumenti d ON d.id = s.dokument_id' + LineEnding +
    'GROUP BY a.id' + LineEnding +
    'ORDER BY a.naziv');
  Fl := Names(['sifra', 'naziv', 'jmj', 'stanje', 'min_zaliha']);
  try
    Ro.Source := 'Stanje zaliha'; Ro.Name := 'Stanje zaliha'; Ro.Title := 'Stanje zaliha';
    Ro.GroupField := ''; Ro.SortField := ''; Ro.Fields := Fl; Ro.Kind := rkTabular;
    Ro.Descending := False; Ro.Sums := False; Ro.PageBreakPerRecord := False; Ro.LabelColumns := 3; Ro.LabelLines := nil;
    SaveReport(ADb, ALog, BuildReportEx(ADb, Ro));
  finally
    Fl.Free;
  end;
end;

{ ---------------- cash book ---------------- }

procedure DoBlagajna(ADb: TAppDb; ALog: TStrings; ASample: Boolean);
var
  Fl: TStringList;
  Ro: TaReportOptions;
  Rd: TaReportDef;
  I: Integer;
  New: Boolean;
begin
  DoPartneri(ADb, ALog, ASample);
  New := EnsureTable(ADb, ALog, 'blagajna', [
    'id|AutoNumber', 'broj|Text|' + NumberDefault('blagajna') + '||R', 'datum|Date|Today()||R', 'opis|Text|||R',
    'partner_id|Integer||partneri.id', 'uplata|Currency|0', 'isplata|Currency|0']);
  SetRule(ADb, 'blagajna', 'uplata', '[uplata] >= 0', 'Iznos ne može biti negativan.');
  SetRule(ADb, 'blagajna', 'isplata', '[isplata] >= 0', 'Iznos ne može biti negativan.');
  if New and ASample then
  begin
    Exec(ADb, 'INSERT INTO blagajna (broj, datum, opis, uplata, isplata) VALUES ' +
      '(''B-001'', date(''now'', ''-3 days''), ''Početno stanje'', 500, 0), (''B-002'', date(''now'', ''-2 days''), ''Kupnja uredskog materijala'', 0, 45.50), ' +
      '(''B-003'', date(''now'', ''-1 days''), ''Uplata gotovine'', 120, 0)');
    ALog.Add('upisani primjeri blagajne');
  end;
  SaveForm(ADb, ALog, SplitForm(ADb, 'Blagajna', 'Blagajna', 'blagajna',
    ['broj', 'datum', 'opis', 'partner_id', 'uplata', 'isplata']));
  SaveQuery(ADb, ALog, 'Blagajnicki dnevnik podaci',
    'SELECT datum, broj, opis, uplata, isplata,' + LineEnding +
    '       SUM(uplata - isplata) OVER (ORDER BY datum, id) AS saldo' + LineEnding +
    'FROM blagajna' + LineEnding +
    'ORDER BY datum, id');
  Fl := Names(['datum', 'broj', 'opis', 'uplata', 'isplata', 'saldo']);
  try
    Ro.Source := 'Blagajnicki dnevnik podaci'; Ro.Name := 'Blagajnički dnevnik'; Ro.Title := 'Blagajnički dnevnik';
    Ro.GroupField := ''; Ro.SortField := ''; Ro.Fields := Fl; Ro.Kind := rkTabular;
    Ro.Descending := False; Ro.Sums := True; Ro.PageBreakPerRecord := False; Ro.LabelColumns := 3; Ro.LabelLines := nil;
    Rd := BuildReportEx(ADb, Ro);
  finally
    Fl.Free;
  end;
  { the running balance is not summed }
  for I := Rd.Count - 1 downto 0 do
    if (SectionIndex(Rd[I].Section) = SecReportFooter) and (Pos('saldo', LowerCase(Rd[I].ControlSource)) > 0) then
      Rd.Delete(Rd[I]);
  SaveReport(ADb, ALog, Rd);
end;

{ ---------------- employees ---------------- }

procedure DoZaposlenici(ADb: TAppDb; ALog: TStrings; ASample: Boolean);
var
  Fl: TStringList;
  Rd: TaReportDef;
  Ro: TaReportOptions;
  D: TaQbeDesign;
  Sql, Err: string;
  New: Boolean;
begin
  New := EnsureTable(ADb, ALog, 'zaposlenici', [
    'id|AutoNumber', 'ime|Text|||R', 'prezime|Text|||R', 'oib|Text', 'datum_rodjenja|Date', 'datum_zaposlenja|Date|Today()',
    'radno_mjesto|Text', 'odjel|Text', 'placa|Currency|0', 'email|Text', 'telefon|Text', 'napomena|Memo', 'aktivan|YesNo|1']);
  if New then
  begin
    SetRule(ADb, 'zaposlenici', 'oib', 'ValidOIB([oib])', 'Neispravan OIB.');
    if ASample then
    begin
      Exec(ADb, 'INSERT INTO zaposlenici (ime, prezime, datum_rodjenja, datum_zaposlenja, radno_mjesto, odjel, placa, aktivan) VALUES ' +
        '(''Marko'', ''Marić'', ''1985-04-12'', ''2015-03-01'', ''Voditelj prodaje'', ''Prodaja'', 1800, 1), ' +
        '(''Petra'', ''Perić'', ''1992-09-30'', ''2019-06-15'', ''Računovođa'', ''Financije'', 1500, 1), ' +
        '(''Luka'', ''Lukić'', ''1990-01-20'', ''2021-09-01'', ''Komercijalist'', ''Prodaja'', 1350, 1)');
      ALog.Add('upisani primjeri zaposlenika');
    end;
  end;
  SaveForm(ADb, ALog, SplitForm(ADb, 'Zaposlenici', 'Zaposlenici', 'zaposlenici',
    ['ime', 'prezime', 'oib', 'datum_rodjenja', 'datum_zaposlenja', 'radno_mjesto', 'odjel', 'placa', 'email', 'telefon', 'napomena', 'aktivan'],
    'Starost=Age([datum_rodjenja]) ;; Staz=DateDiff("yyyy", [datum_zaposlenja], Date())'));
  Fl := Names(['ime', 'prezime', 'radno_mjesto', 'odjel', 'datum_zaposlenja', 'placa']);
  try
    Ro.Source := 'zaposlenici'; Ro.Name := 'Popis zaposlenika'; Ro.Title := 'Popis zaposlenika';
    Ro.GroupField := ''; Ro.SortField := 'prezime'; Ro.Fields := Fl; Ro.Kind := rkTabular;
    Ro.Descending := False; Ro.Sums := True; Ro.PageBreakPerRecord := False; Ro.LabelColumns := 3; Ro.LabelLines := nil;
    SaveReport(ADb, ALog, BuildReportEx(ADb, Ro));
  finally
    Fl.Free;
  end;
  { plaće po odjelima: a QBE design, so it reopens as a grid }
  D := TaQbeDesign.Create;
  try
    D.Tables.Add('zaposlenici');
    D.AddColumn('odjel', 'Odjel', True, 'group', 'asc');
    D.AddColumn('id', 'Broj_zaposlenih', True, 'count');
    D.AddColumn('placa', 'Ukupna_placa', True, 'sum');
    D.AddColumn('placa', 'Prosjecna_placa', True, 'avg');
    if not BuildQbeSql(ADb, D, Sql, Err) then raise Exception.Create(Err);
    SaveQuery(ADb, ALog, 'Place po odjelima', QbeSqlWithDesign(Sql, D));
  finally
    D.Free;
  end;
  Fl := Names(['Odjel', 'Broj_zaposlenih', 'Ukupna_placa', 'Prosjecna_placa']);
  try
    Ro.Source := 'Place po odjelima'; Ro.Name := 'Plaće po odjelima'; Ro.Title := 'Plaće po odjelima';
    Ro.GroupField := ''; Ro.SortField := ''; Ro.Fields := Fl; Ro.Kind := rkTabular;
    Ro.Sums := True;
    Rd := BuildReportEx(ADb, Ro);
    DropSums(Rd, ['Prosjecna_placa']);
    SaveReport(ADb, ALog, Rd);
  finally
    Fl.Free;
  end;
end;

{ ---------------- travel orders ---------------- }

procedure DoPutni(ADb: TAppDb; ALog: TStrings; ASample: Boolean);
var
  Fl: TStringList;
  O: TaFormOptions;
  Fm: TaFormDef;
  Ro: TaReportOptions;
  Y, I, Idx: Integer;
  New: Boolean;
begin
  DoZaposlenici(ADb, ALog, ASample);
  New := EnsureTable(ADb, ALog, 'putni_nalozi', [
    'id|AutoNumber', 'broj|Text|' + NumberDefault('putni_nalozi') + '||R', 'zaposlenik_id|Integer||zaposlenici.id|R',
    'relacija|Text|||R', 'svrha|Text', 'datum_od|Date|Today()||R', 'datum_do|Date|Today()', 'km|Decimal/0|0',
    'cijena_km|Currency|0.40', 'dnevnice_broj|Decimal/1|0', 'dnevnica_iznos|Currency|26.55', 'ostali_troskovi|Currency|0',
    'isplaceno|YesNo|0']);
  SetRule(ADb, 'putni_nalozi', 'datum_do', '[datum_do] >= [datum_od]', 'Datum povratka ne može biti prije polaska.');
  if New and ASample then
  begin
    Exec(ADb, 'INSERT INTO putni_nalozi (broj, zaposlenik_id, relacija, svrha, datum_od, datum_do, km, cijena_km, dnevnice_broj, dnevnica_iznos, ostali_troskovi) VALUES ' +
      '(''' + FormatDateTime('yyyy', Date) + '-001'', 1, ''Zagreb - Split - Zagreb'', ''Sastanak s kupcem'', date(''now'', ''-5 days''), date(''now'', ''-4 days''), 880, 0.40, 2, 26.55, 15)');
    ALog.Add('upisan primjer putnog naloga');
  end;
  Fl := Names(['broj', 'zaposlenik_id', 'relacija', 'svrha', 'datum_od', 'datum_do', 'km', 'cijena_km',
    'dnevnice_broj', 'dnevnica_iznos', 'ostali_troskovi', 'isplaceno']);
  try
    O.Source := 'putni_nalozi'; O.Name := 'Putni nalozi'; O.Title := 'Putni nalog'; O.Fields := Fl;
    O.Layout := flOneColumn; O.SubTables := nil;
    Fm := BuildFormEx(ADb, O);
  finally
    Fl.Free;
  end;
  Y := BottomOf(Fm) + 12;
  AddCalc(Fm, 'Trošak vožnje:', 'txtVoznja', '=[km] * [cijena_km]', '#,##0.00 "€"', 16, Y, 130, False);
  AddCalc(Fm, 'Dnevnice:', 'txtDnevnice', '=[dnevnice_broj] * [dnevnica_iznos]', '#,##0.00 "€"', 16, Y + 28, 130, False);
  AddCalc(Fm, 'UKUPNO:', 'txtPutniUkupno', '=[txtVoznja] + [txtDnevnice] + Nz([ostali_troskovi], 0)', '#,##0.00 "€"', 16, Y + 56, 130, True);
  AddButton(Fm, 'Ispis', 'openreport:Putni nalog@"id = " & [id]', 330, Y + 26, 110);
  Fm.Height := Y + 96;
  SaveForm(ADb, ALog, Fm);
  SaveQuery(ADb, ALog, 'Putni nalozi - ispis podaci',
    'SELECT n.id, n.broj, z.ime || '' '' || z.prezime AS zaposlenik, n.relacija, n.svrha,' + LineEnding +
    '       n.datum_od, n.datum_do, n.km, n.cijena_km,' + LineEnding +
    '       ROUND(n.km * n.cijena_km, 2) AS trosak_voznje,' + LineEnding +
    '       ROUND(n.dnevnice_broj * n.dnevnica_iznos, 2) AS dnevnice,' + LineEnding +
    '       n.ostali_troskovi,' + LineEnding +
    '       ROUND(n.km * n.cijena_km + n.dnevnice_broj * n.dnevnica_iznos + n.ostali_troskovi, 2) AS ukupno' + LineEnding +
    'FROM putni_nalozi n JOIN zaposlenici z ON z.id = n.zaposlenik_id');
  Fl := Names(['broj', 'zaposlenik', 'relacija', 'svrha', 'datum_od', 'datum_do', 'km', 'trosak_voznje', 'dnevnice',
    'ostali_troskovi', 'ukupno']);
  try
    Ro.Source := 'Putni nalozi - ispis podaci'; Ro.Name := 'Putni nalog'; Ro.Title := 'Putni nalog';
    Ro.GroupField := ''; Ro.SortField := ''; Ro.Fields := Fl; Ro.Kind := rkColumnar;
    Ro.Descending := False; Ro.Sums := False; Ro.PageBreakPerRecord := True; Ro.LabelColumns := 3; Ro.LabelLines := nil;
    SaveReport(ADb, ALog, BuildReportEx(ADb, Ro));
  finally
    Fl.Free;
  end;
  Idx := 0;
  I := Idx;
end;

{ ---------------- switchboard ---------------- }

{ Izbornik po skupinama: ako forme imaju pripadajuci popis ("X popis") ili izvjesce ("X izvjesce"), svaka skupina ima naslov
  i gumbe Forma / Popis / Izvjesce; sto nema para ide u skupinu "Ostalo". Inace izbornik ostaje ravan. }
procedure GroupSwitchItems(ADb: TAppDb; AForms, AReports, AItems: TStringList);
var
  LS, RS, Base, Rest: string;
  I, Paired: Integer;
  Main, Lists, Reps, Used: TStringList;
  Grouped: TStringList;
  HasList, HasRep: Boolean;
begin
  LS := Tr(' list');
  RS := Tr(' report');
  Main := TStringList.Create;
  Used := TStringList.Create;
  Grouped := TStringList.Create;
  try
    for I := 0 to AForms.Count - 1 do
      if (AForms[I] <> 'Izbornik') and (Copy(AForms[I], Length(AForms[I]) - 7, 8) <> '_detalji') and
         (Copy(AForms[I], Length(AForms[I]) - Length(LS) + 1, Length(LS)) <> LS) then Main.Add(AForms[I]);
    for I := 0 to AItems.Count - 1 do
      if Pos('#vrsta=', AItems[I]) > 0 then Exit;     { objedinjeni dokumenti: izbornik ostaje ravan }
    Paired := 0;
    for I := 0 to Main.Count - 1 do
      if (AForms.IndexOf(Main[I] + LS) >= 0) or (AReports.IndexOf(Main[I] + RS) >= 0) then Inc(Paired);
    if Paired * 2 < Main.Count then Exit;      { nema pravila imenovanja: ostaje ravan izbornik }
    Rest := '';
    for I := 0 to Main.Count - 1 do
    begin
      Base := Main[I];
      HasList := AForms.IndexOf(Base + LS) >= 0;
      HasRep := AReports.IndexOf(Base + RS) >= 0;
      if not (HasList or HasRep) then Continue;
      Grouped.Add('# ' + Base);
      Grouped.Add(Tr('Form') + '|openform:' + Base);
      Used.Add(Base);
      if HasList then begin Grouped.Add(Tr('List') + '|openform:' + Base + LS); Used.Add(Base + LS); end;
      if HasRep then begin Grouped.Add(Tr('Report') + '|openreport:' + Base + RS); Used.Add('r:' + Base + RS); end;
    end;
    { ostalo: forme bez para i izvjesca bez forme }
    Rest := '';
    Lists := TStringList.Create;
    try
      for I := 0 to Main.Count - 1 do
        if Used.IndexOf(Main[I]) < 0 then Lists.Add(Main[I] + '|openform:' + Main[I]);
      for I := 0 to AReports.Count - 1 do
        if (Pos(' - ispis', AReports[I]) = 0) and (Used.IndexOf('r:' + AReports[I]) < 0) then Lists.Add(Tr('Report: ') + AReports[I] + '|openreport:' + AReports[I]);
      { objedinjene dokumentne forme (vise stavki iz jedne forme) vec su u AItems: zadrzi ih ravno }
      if Lists.Count > 0 then
      begin
        Grouped.Add('# ' + Tr('Other'));
        Grouped.AddStrings(Lists);
      end;
    finally
      Lists.Free;
    end;
    AItems.Assign(Grouped);
  finally
    Grouped.Free;
    Used.Free;
    Main.Free;
  end;
end;

function BuildAppSwitchboard(ADb: TAppDb; ALog: TStrings): Boolean;
var
  Items, F, R, Codes: TStringList;
  I, K: Integer;
  Def, Fd: TaFormDef;
  S: TaAppSettings;
  DT: TaDocType;
begin
  Result := False;
  Items := TStringList.Create;
  F := ADb.ListObjects('_sys_forms');
  R := ADb.ListObjects('_sys_reports');
  try
    for I := 0 to F.Count - 1 do
      if (F[I] <> 'Izbornik') and (Copy(F[I], Length(F[I]) - 7, 8) <> '_detalji') then
      begin
        { objedinjena forma dokumenta: jedna stavka po vrsti (openform:Dokument#vrsta=otp) }
        Fd := TaFormDef.Create;
        try
          Fd.FromJson(ADb.LoadObject('_sys_forms', F[I]));
          if Fd.DocTypeField <> '' then
          begin
            Codes := DocTypeCodes(ADb);
            try
              for K := 0 to Codes.Count - 1 do
                if DocTypeLoad(ADb, Codes[K], DT) then Items.Add(DT.Name + '|openform:' + F[I] + '#vrsta=' + Codes[K]);
            finally
              Codes.Free;
            end;
          end
          else Items.Add(F[I] + '|openform:' + F[I]);
        finally
          Fd.Free;
        end;
      end;
    for I := 0 to R.Count - 1 do
      if Pos(' - ispis', R[I]) = 0 then Items.Add('Izvješće: ' + R[I] + '|openreport:' + R[I]);
    GroupSwitchItems(ADb, F, R, Items);
    Items.Add('Zatvori|close');
    if Items.Count = 1 then Exit;
    Def := BuildSwitchboard('Izbornik', 'Glavni izbornik', Items);
    SaveForm(ADb, ALog, Def);
    S := LoadAppSettings(ADb);
    if S.StartupForm = '' then
    begin
      S.StartupForm := 'Izbornik';
      SaveAppSettings(ADb, S);
      ALog.Add('Izbornik je postavljen kao početna forma');
    end;
    Result := True;
  finally
    R.Free;
    F.Free;
    Items.Free;
  end;
end;

function ApplyBizTemplate(ADb: TAppDb; const AId, ADocType: string; ASample: Boolean; ALog: TStrings): Boolean;
begin
  Result := True;
  try
    if ASample and (AId = 'dokument') and (ADb.LoadSetting('firma.naziv') = '') then
    begin
      ADb.SaveSetting('firma.naziv', 'Moja tvrtka d.o.o.');
      ADb.SaveSetting('firma.adresa', 'Ilica 1');
      ADb.SaveSetting('firma.mjesto', '10000 Zagreb');
      ADb.SaveSetting('firma.iban', 'HR1210010051863000160');
      ALog.Add('upisani primjeri podataka o tvrtki (Aplikacija > Podaci o tvrtki)');
    end;
    if AId = 'partneri' then DoPartneri(ADb, ALog, ASample)
    else if AId = 'artikli' then DoArtikli(ADb, ALog, ASample)
    else if AId = 'dokument' then DoDokument(ADb, ALog, ASample, ADocType)
    else if AId = 'dokumenti_obj' then DoObjedinjeniDokumenti(ADb, ALog, ASample)
    else if AId = 'skladiste' then DoSkladiste(ADb, ALog, ASample)
    else if AId = 'blagajna' then DoBlagajna(ADb, ALog, ASample)
    else if AId = 'zaposlenici' then DoZaposlenici(ADb, ALog, ASample)
    else if AId = 'putni' then DoPutni(ADb, ALog, ASample)
    else if AId = 'ponude_ugovori' then
    begin
      if Assigned(BizOffersHook) then Result := BizOffersHook(ADb, ASample, ALog)
      else begin ALog.Add('predložak ponude nije dostupan'); Result := False; end;
    end
    else
    begin
      ALog.Add('nepoznat predložak: ' + AId);
      Result := False;
    end;
  except
    on E: Exception do
    begin
      ALog.Add('GREŠKA: ' + E.Message);
      Result := False;
    end;
  end;
end;

end.
