unit ta_appgen;
{ Generator aplikacije iz baze (etapa 2 plana PLAN-generator-aplikacije.md). Iz plana sheme (ta_schemaplan) izradi:
    glavne tablice  -> forma za unos (jedan/dva stupca); s stavkama: master-detail (stavke ispod ili na karticama),
                       popis (mreza s filterima) i tablicno izvjesce (s master-detail izvjescem za tablice sa stavkama)
    sifrarnici      -> jednostavna mreza za uredjivanje
    veze i preskoceno -> nista
    izbornik        -> glavni izbornik iz svih formi i izvjesca
  Postojeci objekti se ne prepisuju (osim kad je Overwrite), pa se generiranje moze ponavljati. }
{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ta_types, ta_meta, ta_wizardgen, ta_schemaplan;

type
  TaGenOptions = record
    Layout: TaFormLayout;      { raspored forme za unos: flOneColumn ili flTwoColumns }
    DetailTabs: Boolean;       { stavke na karticama umjesto ispod }
    Lists: Boolean;            { popis (mreza s filterima) za svaku glavnu tablicu }
    Reports: Boolean;          { tablicno izvjesce za svaku glavnu tablicu }
    Codebooks: Boolean;        { mreza za uredjivanje sifrarnika }
    Menu: Boolean;             { glavni izbornik }
    Overwrite: Boolean;        { prepisati vec postojece forme i izvjesca }
    Dictionary: Boolean;       { prije generiranja popuni rjecnik iz sheme }
    DictOptions: TaDictOptions;
  end;

  TaGenResult = record
    Forms, Lists, Reports, Codebooks, Skipped: Integer;
  end;

function DefaultGenOptions: TaGenOptions;
function GenerateApplication(ADb: TAppDb; APlan: TaSchemaPlan; const AOpt: TaGenOptions; ALog: TStrings): TaGenResult;
{ pregled bez zapisivanja: koje bi forme, popisi i izvjesca nastali (ADb moze biti nil; s bazom se oznacuju vec postojeci) }
function PreviewApplication(ADb: TAppDb; APlan: TaSchemaPlan; const AOpt: TaGenOptions; ALog: TStrings): TaGenResult;

implementation

uses
  ta_formdef, ta_reportdef, ta_bizgen, ta_i18n, sha1;

function DefaultGenOptions: TaGenOptions;
begin
  Result.Layout := flTwoColumns;
  Result.DetailTabs := False;
  Result.Lists := True;
  Result.Reports := True;
  Result.Codebooks := True;
  Result.Menu := True;
  Result.Overwrite := False;
  Result.Dictionary := True;
  Result.DictOptions.Numbering := False;
  Result.DictOptions.Stamps := True;
end;

{ stupci koji se pokazuju: svi osim jedinog automatskog kljuca }
function VisibleCols(T: TaTablePlan): TStringList;
var
  I: Integer;
begin
  Result := TStringList.Create;
  for I := 0 to High(T.Cols) do
    if not ((T.Cols[I].IsKey) and (T.KeyCount = 1) and (T.Cols[I].FkTable = '')) then Result.Add(T.Cols[I].Name);
  if Result.Count = 0 then
    for I := 0 to High(T.Cols) do Result.Add(T.Cols[I].Name);
end;

function FilterCols(T: TaTablePlan): TStringList;
var
  I: Integer;
begin
  Result := TStringList.Create;
  for I := 0 to High(T.Cols) do
    if (T.Cols[I].LType = ltText) and (T.Cols[I].FkTable = '') and not T.Cols[I].IsKey and (Result.Count < 3) then Result.Add(T.Cols[I].Name);
end;

function SumColOf(T: TaTablePlan): string;
const
  Hints: array[0..5] of string = ('iznos', 'amount', 'total', 'ukupno', 'cijena', 'price');
var
  I, J: Integer;
begin
  Result := '';
  for J := 0 to High(Hints) do
    for I := 0 to High(T.Cols) do
      if (T.Cols[I].LType in [ltDecimal, ltCurrency]) and (Pos(Hints[J], LowerCase(T.Cols[I].Name)) > 0) then Exit(T.Cols[I].Name);
end;

function Exists(ADb: TAppDb; const AKind, AName: string): Boolean;
begin
  Result := ADb.LoadObject(AKind, AName) <> '';
end;

{ Oznaka generiranog objekta: otisak sadrzaja u postavkama (gen:vrsta:naziv). Objekt je "neizmijenjen" dok mu sadrzaj odgovara otisku. }
function GenKey(const AKind, AName: string): string;
begin
  Result := 'gen:' + AKind + ':' + AName;
end;

function ContentHash(const AContent: string): string;
begin
  Result := SHA1Print(SHA1String(AContent));
end;

type
  TGenState = (gsNone, gsUntouched, gsModified, gsForeign);

function StateOf(ADb: TAppDb; const AKind, AName: string): TGenState;
var
  Cur, Mark: string;
begin
  Cur := ADb.LoadObject(AKind, AName);
  if Cur = '' then Exit(gsNone);
  Mark := ADb.LoadSetting(GenKey(AKind, AName));
  if Mark = '' then Exit(gsForeign);
  if Mark = ContentHash(Cur) then Result := gsUntouched else Result := gsModified;
end;

{ smije li se objekt (ponovno) zapisati: nov, neizmijenjen generirani ili uz Overwrite }
function MayWrite(ADb: TAppDb; const AKind, AName: string; AOverwrite: Boolean): Boolean;
begin
  Result := AOverwrite or (StateOf(ADb, AKind, AName) in [gsNone, gsUntouched]);
end;

procedure SaveGen(ADb: TAppDb; const AKind, AName, AContent: string);
begin
  ADb.SaveObject(AKind, AName, AContent);
  ADb.SaveSetting(GenKey(AKind, AName), ContentHash(ADb.LoadObject(AKind, AName)));
end;

function PreviewApplication(ADb: TAppDb; APlan: TaSchemaPlan; const AOpt: TaGenOptions; ALog: TStrings): TaGenResult;
var
  I, J: Integer;
  T, C: TaTablePlan;
  Items: string;

  procedure Line(const AKind, AKindName, AName: string);
  var
    Mark: string;
  begin
    Mark := '';
    if ADb <> nil then
      case StateOf(ADb, AKind, AName) of
        gsUntouched: if AOpt.Overwrite then Mark := '  [' + Tr('will be overwritten') + ']' else Mark := '  [' + Tr('generated earlier, will be refreshed') + ']';
        gsModified, gsForeign:
          if AOpt.Overwrite then Mark := '  [' + Tr('will be overwritten') + ']'
          else begin
            if StateOf(ADb, AKind, AName) = gsModified then Mark := '  [' + Tr('changed by hand, kept') + ']' else Mark := '  [' + Tr('exists, skipped') + ']';
            Inc(Result.Skipped);
          end;
      end;
    if ALog <> nil then ALog.Add(AKindName + AName + Mark);
  end;

begin
  FillChar(Result, SizeOf(Result), 0);
  for I := 0 to APlan.Count - 1 do
  begin
    T := APlan.Items2(I);
    if T.Role in [trJunction, trSkip, trDetail] then Continue;
    if T.Role = trCodebook then
    begin
      if AOpt.Codebooks then begin Inc(Result.Codebooks); Line('_sys_forms', Tr('Codebook: '), T.Caption); end;
      Continue;
    end;
    Items := '';
    for J := 0 to APlan.Count - 1 do
    begin
      C := APlan.Items2(J);
      if (C.Role = trDetail) and SameText(C.Parent, T.Name) then
        if Items = '' then Items := C.Caption else Items := Items + ', ' + C.Caption;
    end;
    Inc(Result.Forms);
    if Items <> '' then Line('_sys_forms', Tr('Form with items: '), T.Caption + '  (' + Items + ')')
    else Line('_sys_forms', Tr('Form: '), T.Caption);
    if AOpt.Lists then begin Inc(Result.Lists); Line('_sys_forms', Tr('List: '), T.Caption + Tr(' list')); end;
    if AOpt.Reports then begin Inc(Result.Reports); Line('_sys_reports', Tr('Report: '), T.Caption + Tr(' report')); end;
  end;
  if AOpt.Menu and (ALog <> nil) then ALog.Add(Tr('Main menu') + ': ' + Tr('all forms and reports'));
end;

{ stupci izvjesca: najvise 10; prvo otpadaju dugi opisni stupci, zatim zadnji }
function ReportCols(ACols: TStrings): TStringList;
const
  LongNames: array[0..8] of string = ('napomena', 'uvjeti', 'opis', 'tekst', 'note', 'notes', 'comment', 'komentar', 'memo');
var
  I, J: Integer;
begin
  Result := TStringList.Create;
  Result.Assign(ACols);
  for J := 0 to High(LongNames) do
    for I := Result.Count - 1 downto 0 do
      if (Result.Count > 10) and SameText(Result[I], LongNames[J]) then Result.Delete(I);
  while Result.Count > 10 do Result.Delete(Result.Count - 1);
end;

{ stupac sa nazivom umjesto sifre: partner_id -> partner }
function LabelAlias(const AName: string): string;
begin
  Result := AName;
  if (Length(Result) > 3) and SameText(Copy(Result, Length(Result) - 2, 3), '_id') then Delete(Result, Length(Result) - 2, 3);
end;

{ izvor izvjesca: tablica; ako ima strane kljuceve, spremljeni upit koji umjesto sifre pokazuje naziv iz povezane tablice }
function ReportSource(ADb: TAppDb; APlan: TaSchemaPlan; T: TaTablePlan; ACols, AOut: TStrings; const AName: string): string;
var
  I, K: Integer;
  Sel, Lbl: string;
  C: TaColPlan;
  AnyFk: Boolean;
begin
  Result := T.Name;
  Sel := '';
  AnyFk := False;
  AOut.Assign(ACols);
  for I := 0 to ACols.Count - 1 do
  begin
    K := T.ColIndex(ACols[I]);
    if K < 0 then Continue;
    C := T.Cols[K];
    if Sel <> '' then Sel := Sel + ', ';
    Lbl := '';
    if (C.FkTable <> '') and (APlan.Table(C.FkTable) <> nil) then
    begin
      Lbl := DisplayColumn(ADb, C.FkTable, C.FkCol);
      if SameText(Lbl, C.FkCol) then Lbl := '';
    end;
    if Lbl <> '' then
    begin
      Sel := Sel + '(SELECT r.' + ADb.QuoteId(Lbl) + ' FROM ' + ADb.QuoteId(C.FkTable) + ' r WHERE r.' + ADb.QuoteId(C.FkCol) +
        ' = t.' + ADb.QuoteId(C.Name) + ') AS ' + ADb.QuoteId(LabelAlias(C.Name));
      AOut[I] := LabelAlias(C.Name);
      AnyFk := True;
    end
    else if C.LType = ltYesNo then
    begin
      Sel := Sel + 'CASE WHEN t.' + ADb.QuoteId(C.Name) + ' <> 0 THEN ' + ADb.QuoteLit(Tr('Yes')) + ' ELSE ' + ADb.QuoteLit(Tr('No')) +
        ' END AS ' + ADb.QuoteId(C.Name);
      AnyFk := True;
    end
    else Sel := Sel + 't.' + ADb.QuoteId(C.Name);
  end;
  if not AnyFk then begin AOut.Assign(ACols); Exit; end;
  SaveGen(ADb, '_sys_queries', AName, 'SELECT ' + Sel + ' FROM ' + ADb.QuoteId(T.Name) + ' t');
  Result := AName;
end;

function GenerateApplication(ADb: TAppDb; APlan: TaSchemaPlan; const AOpt: TaGenOptions; ALog: TStrings): TaGenResult;
var
  I, J: Integer;
  T, C: TaTablePlan;
  Cols, Flt: TStringList;
  Opt: TaFormOptions;
  Fm: TaFormDef;
  Rp: TaReportDef;
  Md: TaMDMulti;
  Mr: TaMDMultiResult;
  FormName, ListName, RepName: string;
  Sum, RSrc: string;
  RCols, RBase, MenuLog: TStringList;

  procedure Say(const S: string);
  begin
    if ALog <> nil then ALog.Add(S);
  end;

  procedure SaveForm(const AName: string; ADef: TaFormDef);
  begin
    SaveGen(ADb, '_sys_forms', AName, ADef.ToJson);
  end;

begin
  FillChar(Result, SizeOf(Result), 0);
  if AOpt.Dictionary then
    Say(Format(Tr('Dictionary: %d fields completed'), [ApplyDictionaryFromSchema(ADb, APlan, AOpt.DictOptions, nil)]));
  for I := 0 to APlan.Count - 1 do
  begin
    T := APlan.Items2(I);
    if T.Role in [trJunction, trSkip, trDetail] then Continue;
    FormName := T.Caption;
    ListName := T.Caption + Tr(' list');
    RepName := T.Caption + Tr(' report');
    Cols := VisibleCols(T);
    Flt := FilterCols(T);
    try
      if T.Role = trCodebook then
      begin
        if not AOpt.Codebooks then Continue;
        if not MayWrite(ADb, '_sys_forms', FormName, AOpt.Overwrite) then begin Inc(Result.Skipped); Say(Tr('Exists, skipped: ') + FormName); Continue; end;
        FillChar(Opt, SizeOf(Opt), 0);
        Opt.Source := T.Name; Opt.Name := FormName; Opt.Title := T.Caption; Opt.Fields := Cols; Opt.Layout := flDatasheet;
        Fm := BuildFormEx(ADb, Opt);
        try
          SaveForm(FormName, Fm);
        finally
          Fm.Free;
        end;
        Inc(Result.Codebooks);
        Say(Tr('Codebook: ') + FormName);
        Continue;
      end;
      { glavna tablica: forma za unos (s stavkama kao master-detail) }
      Md.Master := T.Name;
      Md.Name := FormName;
      Md.Title := T.Caption;
      Md.MasterFields := Cols;
      Md.DetailAsForm := False;
      Md.UseTabs := AOpt.DetailTabs;
      SetLength(Md.Details, 0);
      for J := 0 to APlan.Count - 1 do
      begin
        C := APlan.Items2(J);
        if (C.Role = trDetail) and SameText(C.Parent, T.Name) then
        begin
          SetLength(Md.Details, Length(Md.Details) + 1);
          Md.Details[High(Md.Details)].Table := C.Name;
          Md.Details[High(Md.Details)].Fields := nil;
          Md.Details[High(Md.Details)].SumField := SumColOf(C);
          Md.Details[High(Md.Details)].ShowCount := True;
          Md.Details[High(Md.Details)].FkCol := C.FkToParent;
          Md.Details[High(Md.Details)].ParentCol := C.ParentCol;
        end;
      end;
      if not MayWrite(ADb, '_sys_forms', FormName, AOpt.Overwrite) then
      begin
        Inc(Result.Skipped);
        Say(Tr('Exists, skipped: ') + FormName);
      end
      else if Length(Md.Details) > 0 then
      begin
        Mr := BuildMasterDetailMulti(ADb, Md);
        if Mr.Error <> '' then Say(FormName + ': ' + Mr.Error)
        else
        try
          for J := 0 to High(Mr.Items) do
          begin
            if Mr.Items[J].QueryName <> '' then SaveGen(ADb, '_sys_queries', Mr.Items[J].QueryName, Mr.Items[J].QuerySql);
            if Mr.Items[J].Form <> nil then SaveForm(Mr.Items[J].FormName, Mr.Items[J].Form);
          end;
          SaveForm(FormName, Mr.MasterForm);
          Inc(Result.Forms);
          Say(Tr('Form with items: ') + FormName);
        finally
          Mr.MasterForm.Free;
          for J := 0 to High(Mr.Items) do Mr.Items[J].Form.Free;
        end;
      end
      else
      begin
        FillChar(Opt, SizeOf(Opt), 0);
        Opt.Source := T.Name; Opt.Name := FormName; Opt.Title := T.Caption; Opt.Fields := Cols; Opt.Layout := AOpt.Layout;
        Fm := BuildFormEx(ADb, Opt);
        try
          SaveForm(FormName, Fm);
        finally
          Fm.Free;
        end;
        Inc(Result.Forms);
        Say(Tr('Form: ') + FormName);
      end;
      { popis }
      if AOpt.Lists then
        if not MayWrite(ADb, '_sys_forms', ListName, AOpt.Overwrite) then Inc(Result.Skipped)
        else
        begin
          FillChar(Opt, SizeOf(Opt), 0);
          Opt.Source := T.Name; Opt.Name := ListName; Opt.Title := T.Caption; Opt.Fields := Cols; Opt.Layout := flDatasheet;
          Opt.FilterFields := Flt;
          Opt.AddRefreshButton := True;
          Opt.AddClearButton := True;
          if Flt.Count > 0 then Fm := BuildFormWithFilters(ADb, Opt) else Fm := BuildFormEx(ADb, Opt);
          { potkartica: prva stavkovna tablica otvara se plusom uz redak }
          for J := 0 to APlan.Count - 1 do
          begin
            C := APlan.Items2(J);
            if (C.Role = trDetail) and SameText(C.Parent, T.Name) then
            begin
              Fm.SubDatasheet := C.Name + '|' + C.FkToParent + '|' + C.ParentCol;
              Break;
            end;
          end;
          try
            SaveForm(ListName, Fm);
          finally
            Fm.Free;
          end;
          Inc(Result.Lists);
          Say(Tr('List: ') + ListName);
        end;
      { izvjesce }
      if AOpt.Reports then
        if not MayWrite(ADb, '_sys_reports', RepName, AOpt.Overwrite) then Inc(Result.Skipped)
        else
        begin
          Sum := SumColOf(T);
          RCols := TStringList.Create;
          RBase := ReportCols(Cols);
          try
            RSrc := ReportSource(ADb, APlan, T, RBase, RCols, RepName + Tr(' data'));
            Rp := BuildReportDef(ADb, RSrc, RepName, T.Caption, RCols, '', '', False, Sum <> '', '', 3);
          finally
            RBase.Free;
            RCols.Free;
          end;
          try
            SaveGen(ADb, '_sys_reports', RepName, Rp.ToJson);
          finally
            Rp.Free;
          end;
          Inc(Result.Reports);
          Say(Tr('Report: ') + RepName);
        end;
    finally
      Flt.Free;
      Cols.Free;
    end;
  end;
  if AOpt.Menu then
  begin
    MenuLog := TStringList.Create;
    try
      if BuildAppSwitchboard(ADb, MenuLog) then Say(Tr('Main menu created')) else Say(Tr('Main menu not created'));
      if ALog <> nil then ALog.AddStrings(MenuLog);
    finally
      MenuLog.Free;
    end;
  end;
end;

end.
