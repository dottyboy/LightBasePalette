program wizard_smoke_test;
{ Automated Smoke Test for Smart Wizard Framework (LightPalette Stage E7 / Block Wizard).
  Tests heuristics, form generation with filters, 4GL generation, report generation,
  and engine state progression headlessly with an in-memory SQLite database. }

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, DB, ta_types, ta_meta, ta_formdef, ta_reportdef,
  ta_wizardframework, ta_wizardgen;

var
  Fails: Integer = 0;

procedure Check(C: Boolean; const M: string);
begin
  if C then
    WriteLn('OK   ', M)
  else
  begin
    WriteLn('FAIL ', M);
    Inc(Fails);
  end;
end;

procedure TestHeuristics(ADb: TAppDb);
var
  Sols: TaWizardSolutions;
  Fields: TaSourceFields;
begin
  WriteLn('--- Test 1: Heuristika i rangiranje rješenja (SuggestSolutions) ---');
  Fields := SourceFieldList(ADb, 'partneri');

  { Scenarij A: Filter u naslovu }
  Sols := SuggestSolutions(ADb, 'partneri', 'Popis partnera s filterom po gradu i datumu', Fields);
  Check(Length(Sols) >= 4, 'Vraćen je puni skup rješenja (>= 4)');
  Check(Sols[0].SolutionId = 'formgrid-filter', 'Za "filter" prvo rješenje je formgrid-filter');
  Check(Sols[0].Confidence >= 90, 'Pouzdanost za formgrid-filter >= 90% (dobiveno: ' + IntToStr(Sols[0].Confidence) + ')');

  { Scenarij B: Izvještaj u naslovu }
  Sols := SuggestSolutions(ADb, 'racuni', 'Mjesečni izvještaj računa po partneru', SourceFieldList(ADb, 'racuni'));
  Check(Sols[0].SolutionId = 'report-group', 'Za "izvještaj" prvo rješenje je report-group');
  Check(Sols[0].Confidence >= 85, 'Pouzdanost za report-group >= 85% (dobiveno: ' + IntToStr(Sols[0].Confidence) + ')');

  { Scenarij C: Unos u naslovu }
  Sols := SuggestSolutions(ADb, 'stavke', 'Unos stavki računa', SourceFieldList(ADb, 'stavke'));
  Check(Sols[0].SolutionId = 'fgl-input', 'Za "unos" prvo rješenje je fgl-input');
  Check(Sols[0].Confidence >= 85, 'Pouzdanost za fgl-input >= 85% (dobiveno: ' + IntToStr(Sols[0].Confidence) + ')');

  { Scenarij D: Običan naslov bez ključnih riječi }
  Sols := SuggestSolutions(ADb, 'partneri', 'Partneri', Fields);
  Check(Sols[0].SolutionId = 'form-card', 'Zadano rješenje bez ključnih riječi je form-card');
end;

procedure TestFormWithFilters(ADb: TAppDb);
var
  Opt: TaFormOptions;
  FormDef: TaFormDef;
  C, Pnl, BtnRef, BtnClr, FltGrad, FltDatOd, FltDatDo: TaControlDef;
  I: Integer;
  JsonText: string;
  OutF: TStringList;
begin
  WriteLn('--- Test 2: Generiranje forme s filterima i gumbima (BuildFormWithFilters) ---');
  FillChar(Opt, SizeOf(Opt), 0);
  Opt.Source := 'partneri';
  Opt.Name := 'frm_partneri_filter';
  Opt.Title := 'Popis partnera s filterom';
  Opt.Fields := TStringList.Create;
  Opt.Fields.Add('id');
  Opt.Fields.Add('naziv');
  Opt.Fields.Add('grad');
  Opt.Fields.Add('datum_rodjenja');
  Opt.Fields.Add('aktivan');

  Opt.FilterFields := TStringList.Create;
  Opt.FilterFields.Add('grad');
  Opt.FilterFields.Add('datum_rodjenja');
  Opt.AddRefreshButton := True;
  Opt.AddClearButton := True;
  Opt.Layout := flDatasheet;

  try
    FormDef := BuildFormWithFilters(ADb, Opt);
    Check(FormDef <> nil, 'FormDef uspješno kreiran');
    if FormDef = nil then Exit;

    try
      Check(FormDef.ViewMode = 'datasheet', 'ViewMode forme je datasheet');
      Check(FormDef.RecordSource = 'partneri', 'RecordSource je partneri');

      Pnl := nil;
      BtnRef := nil;
      BtnClr := nil;
      FltGrad := nil;
      FltDatOd := nil;
      FltDatDo := nil;

      for I := 0 to FormDef.Count - 1 do
      begin
        C := FormDef.Controls[I];
        if (C.Kind = 'Panel') and (C.Name = 'pnlFilteri') then Pnl := C;
        if (C.Kind = 'Button') and (C.OnClick = 'refresh:') then BtnRef := C;
        if (C.Kind = 'Button') and (C.OnClick = 'clearfilters:') then BtnClr := C;
        if C.GetX('filterFor') = 'grad' then FltGrad := C;
        if C.GetX('filterFor') = 'datum_rodjenja_od' then FltDatOd := C;
        if C.GetX('filterFor') = 'datum_rodjenja_do' then FltDatDo := C;
      end;

      Check(Pnl <> nil, 'Pronađen pnlFilteri panel na vrhu forme');
      Check((Pnl <> nil) and (Pnl.Align = 'top'), 'pnlFilteri ima Align = top');
      Check(BtnRef <> nil, 'Pronađen gumb Osvježi s OnClick = refresh:');
      Check(BtnClr <> nil, 'Pronađen gumb Očisti filtere s OnClick = clearfilters:');
      Check(FltGrad <> nil, 'Pronađeno tekstualno filter polje flt_grad (filterFor = grad)');
      Check(FltDatOd <> nil, 'Pronađeno datumsko filter polje Od (filterFor = datum_rodjenja_od)');
      Check(FltDatDo <> nil, 'Pronađeno datumsko filter polje Do (filterFor = datum_rodjenja_do)');

      JsonText := FormDef.ToJson;
      Check(Length(JsonText) > 200, 'JSON definicija forme uspješno serijalizirana');

      { Spremi za golden-master referencu }
      OutF := TStringList.Create;
      try
        OutF.Text := JsonText;
        OutF.SaveToFile(ExtractFilePath(ParamStr(0)) + 'wizard_expected_outputs/partneri_filter.json');
      finally
        OutF.Free;
      end;
    finally
      FormDef.Free;
    end;
  finally
    Opt.Fields.Free;
    Opt.FilterFields.Free;
  end;
end;

procedure TestReport(ADb: TAppDb);
var
  RepOpt: TaReportOptions;
  RepDef: TaReportDef;
  OutF: TStringList;
begin
  WriteLn('--- Test 3: Generiranje tabličnog izvještaja (BuildReportEx) ---');
  FillChar(RepOpt, SizeOf(RepOpt), 0);
  RepOpt.Source := 'racuni';
  RepOpt.Name := 'rep_racuni_mjesecni';
  RepOpt.Title := 'Mjesečni izvještaj računa po partneru';
  RepOpt.Fields := TStringList.Create;
  RepOpt.Fields.Add('id');
  RepOpt.Fields.Add('partner_id');
  RepOpt.Fields.Add('broj');
  RepOpt.Fields.Add('datum');
  RepOpt.Fields.Add('iznos');
  RepOpt.GroupField := 'partner_id';
  RepOpt.Kind := rkTabular;
  RepOpt.Sums := True;

  try
    RepDef := BuildReportEx(ADb, RepOpt);
    Check(RepDef <> nil, 'ReportDef uspješno kreiran');
    if RepDef = nil then Exit;

    try
      Check(RepDef.GroupField = 'partner_id', 'Izvještaj je grupiran po partner_id');
      Check(RepDef.RecordSource = 'racuni', 'RecordSource izvještaja je racuni');
      Check(RepDef.Count >= 5, 'Izvještaj sadrži generirane stupce i zaglavlja');

      OutF := TStringList.Create;
      try
        OutF.Text := RepDef.ToJson;
        OutF.SaveToFile(ExtractFilePath(ParamStr(0)) + 'wizard_expected_outputs/racuni_izvjestaj.json');
      finally
        OutF.Free;
      end;
    finally
      RepDef.Free;
    end;
  finally
    RepOpt.Fields.Free;
  end;
end;

procedure TestFglScript(ADb: TAppDb);
var
  SrcCode: string;
  Flds: TStringList;
  OutF: TStringList;
begin
  WriteLn('--- Test 4: Generiranje 4GL skripte (BuildFglScript) ---');
  Flds := TStringList.Create;
  try
    Flds.Add('artikal');
    Flds.Add('kolicina');
    Flds.Add('cijena');

    { INPUT skripta }
    SrcCode := BuildFglScript(ADb, 'stavke', 'Unos stavki računa', 'INPUT', Flds);
    Check(Pos('MAIN', SrcCode) > 0, '4GL sadrži blok MAIN');
    Check(Pos('DEFINE r_stavke RECORD LIKE stavke.*', SrcCode) > 0, '4GL sadrži DEFINE RECORD');
    Check(Pos('INPUT BY NAME', SrcCode) > 0, '4GL sadrži INPUT BY NAME');
    Check(Pos('INSERT INTO stavke', SrcCode) > 0, '4GL sadrži INSERT INTO stavke');
    Check(Pos('ON ACTION spremi', SrcCode) > 0, '4GL sadrži akciju spremi');

    OutF := TStringList.Create;
    try
      OutF.Text := SrcCode;
      OutF.SaveToFile(ExtractFilePath(ParamStr(0)) + 'wizard_expected_outputs/stavke_unos.4gl');
    finally
      OutF.Free;
    end;

    { CONSTRUCT skripta }
    SrcCode := BuildFglScript(ADb, 'stavke', 'Pretraga stavki', 'CONSTRUCT', Flds);
    Check(Pos('CONSTRUCT BY NAME where_clause', SrcCode) > 0, '4GL CONSTRUCT sadrži where_clause');

    { DISPLAY skripta }
    SrcCode := BuildFglScript(ADb, 'stavke', 'Pregled stavki', 'DISPLAY', Flds);
    Check(Pos('DISPLAY ARRAY', SrcCode) > 0, '4GL DISPLAY sadrži DISPLAY ARRAY');
  finally
    Flds.Free;
  end;
end;

procedure TestEngineLifecycle(ADb: TAppDb);
var
  Engine: TaSmartWizardEngine;
begin
  WriteLn('--- Test 5: Životni ciklus okvira čarobnjaka (TaSmartWizardEngine) ---');
  Engine := TaSmartWizardEngine.Create(ADb, 'partneri');
  try
    Engine.AddStep(TaDataSourceStep.Create);
    Engine.AddStep(TaTitleStep.Create);
    Engine.AddStep(TaSolutionStep.Create);
    Engine.AddStep(TaFieldStep.Create);
    Engine.AddStep(TaResultStep.Create);

    Check(Engine.StepCount = 5, 'Engine sadrži točno 5 koraka');
    Check(Engine.CurrentIndex = 0, 'Početni korak je 0');
    Check(Engine.CanBack = False, 'Na koraku 0 CanBack je False');
    Check(Engine.CanNext = True, 'Za partneri izvor CanNext je True');

    Engine.Next;
    Check(Engine.CurrentIndex = 1, 'Nakon Next korak je 1 (Title)');
    Check(Engine.CanBack = True, 'Na koraku 1 CanBack je True');

    Engine.Ctx^.Title := 'Popis partnera s filterom';
    Check(Engine.CanNext = True, 'Nakon unosa naslova CanNext je True');

    Engine.Next;
    Check(Engine.CurrentIndex = 2, 'Nakon Next korak je 2 (Solution)');

    Engine.Back;
    Check(Engine.CurrentIndex = 1, 'Nakon Back korak je ponovno 1');
  finally
    Engine.Free;
  end;
end;

var
  TestDb: TAppDb;
  OutDir: string;
begin
  WriteLn('===========================================================');
  WriteLn('POKRETANJE SMOKE TESTOVA: Pametni okvir čarobnjaka (E7)');
  WriteLn('===========================================================');

  OutDir := ExtractFilePath(ParamStr(0)) + 'wizard_expected_outputs';
  if not DirectoryExists(OutDir) then
    ForceDirectories(OutDir);

  TestDb := TAppDb.Create;
  try
    TestDb.Open(':memory:');

    { Kreiranje testnih tablica u SQLite in-memory bazi }
    TestDb.Conn.ExecuteDirect('CREATE TABLE partneri (' +
      'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
      'naziv VARCHAR(100), ' +
      'grad VARCHAR(50), ' +
      'datum_rodjenja DATE, ' +
      'aktivan INTEGER)');

    TestDb.Conn.ExecuteDirect('CREATE TABLE racuni (' +
      'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
      'partner_id INTEGER, ' +
      'broj VARCHAR(30), ' +
      'datum DATE, ' +
      'iznos DECIMAL(12,2))');

    TestDb.Conn.ExecuteDirect('CREATE TABLE stavke (' +
      'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
      'racun_id INTEGER, ' +
      'artikal VARCHAR(100), ' +
      'kolicina DECIMAL(10,2), ' +
      'cijena DECIMAL(10,2))');

    TestDb.Conn.ExecuteDirect('INSERT INTO partneri (naziv, grad, datum_rodjenja, aktivan) VALUES (''A'', ''Zagreb'', ''2000-01-01'', 1)');
    TestDb.Conn.ExecuteDirect('INSERT INTO racuni (partner_id, broj, datum, iznos) VALUES (1, ''R1'', ''2026-01-01'', 10.5)');
    TestHeuristics(TestDb);
    TestFormWithFilters(TestDb);
    TestReport(TestDb);
    TestFglScript(TestDb);
    TestEngineLifecycle(TestDb);

  finally
    TestDb.Close;
    TestDb.Free;
  end;

  WriteLn('===========================================================');
  if Fails = 0 then
  begin
    WriteLn('REZULTAT: SVI TESTOVI USPJEŠNI! (Grešaka: 0)');
    Halt(0);
  end
  else
  begin
    WriteLn('REZULTAT: PRONAĐENE GREŠKE: ', Fails);
    Halt(1);
  end;
end.
